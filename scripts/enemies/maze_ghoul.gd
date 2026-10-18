class_name MazeGhoul
extends MazeEnemy
## A ghoul (creatures/ghoul/: a mummy with nothing left on, after Zelda's
## ReDeads) set to keep a corner of the maze. This is only its thinking; how it
## looks and moves is the `Ghoul` component, which this drives.
##
## - IT STANDS. Put somewhere (best at the end of a dead end, facing out), it
##   stands there like a statue, and nobody can tell it from one until it
##   notices someone (MazeEnemy's senses: it sees a long way down a passage, and
##   hears only close by). Then it wakes.
## - IT SCREAMS. Awake, it shuffles after them, slowly: anyone who keeps moving
##   leaves it behind. But once they are within `scream_range` and in its sight,
##   it throws its head back and shrieks, and everyone within `freeze_range`
##   who can see it and is not facing away is rooted to the spot, shuddering,
##   for `freeze_time` (see `paralyse`). It creeps on as it screams, and then
##   rushes at them for `lurch_time`, faster than a walk (`lurch_speed`): who
##   runs the moment they can move gets away; who is slow to is taken. It
##   cannot scream again for `scream_every` seconds.
## - IT GRABS. Within `grab_distance` it throws its arms wide and hugs them shut;
##   `caught(player)` is emitted only if they close on someone (Ghoul.grab_hits).
##   Turn your back as it screams, or keep out of its sight, and it is easy to get past.
## - When it has forgotten them it shuffles back to where it was put and stands again.
##
## Online, the host thinks for it and the others' copies are puppets: each
## scream and grab is sent with its state (`net_flag`) and played out here too,
## and a scream holds whoever plays on this machine, here, as it would there.
## Catching is the host's alone.
##
## Spawn (as MazeEnemies.add does): `MazeGhoul.new()`, set `maze`, place it and
## turn it (rotation.y, 0 faces +Z), add it to the tree. Where it is put is its home.

enum Mode { STILL, WAKING, HUNTING, GOING_HOME }

## How much bigger than it is modelled it is drawn (and goes).
const SIZE := 1.6

## Its shuffle, and how slowly it creeps on while it screams, world units a second.
@export var shuffle_speed := 1.0
@export var creep_speed := 0.4
## How fast, and for how long, it rushes at them after a scream: quicker than a
## walk, slower than a run, so that whoever runs as soon as they can move gets
## away, and whoever is slow to is taken.
@export var lurch_speed := 3.6
@export var lurch_time := 2.5
## It screams at whoever it is after once they are this near and in its sight;
## the scream holds anyone this near who can see it.
@export var scream_range := 5.5
@export var freeze_range := 9.0
## How long a scream holds them, and how long before it can scream again.
@export var freeze_time := 2.2
@export var scream_every := 7.0
## How near it must be to begin a grab.
@export var grab_distance := 1.8
@export var turn_rate := 2.6
## Seconds between noticing someone and setting off.
@export var wake_time := 0.7
@export var gravity := 24.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0

var mode := Mode.STILL
## Which way it faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## The figure it drives.
var figure: Ghoul

var _home := Vector3.ZERO
var _home_yaw := 0.0
var _waking := 0.0
var _scream_in := 0.0
var _lurching := 0.0
var _screams := 0
var _grabs := 0
var _radius := 0.45
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_acts := false


func _init() -> void:
	sight_range = 34.0
	hear_range = 5.0
	memory = 8.0
	alert_range = 0.0
	pack = &"ghouls"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.28 * SIZE
	shape.radius = _radius
	shape.height = 1.35 * SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)

	figure = Ghoul.new()
	figure.scale = Vector3.ONE * SIZE
	add_child(figure)
	figure.top_level = true
	figure.shrieked.connect(_on_shrieked)
	_home = global_position
	_home_yaw = rotation.y
	facing_yaw = _home_yaw
	reset()


## Back where it was put, standing still.
func reset() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	chasing = false
	mode = Mode.STILL
	facing_yaw = _home_yaw
	_prev_pos = _home
	_curr_pos = _home
	figure.awake = false
	figure.aim = Vector3.INF
	figure.put(_home, facing_yaw)


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	_scream_in -= delta
	_lurching -= delta
	var wish := Vector3.ZERO
	var speed := shuffle_speed
	match mode:
		Mode.STILL:
			if quarry:
				mode = Mode.WAKING
				_waking = wake_time
		Mode.WAKING:
			_waking -= delta
			if _waking <= 0.0:
				mode = Mode.HUNTING
		Mode.HUNTING:
			if not hunting() and not figure.busy():
				mode = Mode.GOING_HOME
			else:
				var act := _hunt()
				wish = act[0]
				speed = act[1]
		Mode.GOING_HOME:
			if hunting():
				mode = Mode.HUNTING
			else:
				var to := _home - global_position
				to.y = 0.0
				if to.length() < 0.6:
					mode = Mode.STILL
				else:
					var step := nav.waypoint(global_position, _home, MazeNav.clearance_for(_radius)) - global_position
					step.y = 0.0
					wish = step.normalized() if step.length() > 0.05 else to.normalized()
	chasing = mode == Mode.HUNTING and hunting()
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, 8.0 * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## While after someone: what it does, and which way and how fast it goes.
func _hunt() -> Array:
	var after := quarry if quarry and quarry.get(&"is_limp") != true else null
	if after == null:
		return [_route(), shuffle_speed]
	var to := after.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	match figure.doing():
		GhoulRig.Act.SCREAM:
			return [_route(), creep_speed]
		GhoulRig.Act.GRAB:
			if figure.stage() == GhoulRig.Stage.CLOSE and not figure.held:
				for player: Node3D in players():
					if huntable(player) and figure.grab_hits(player.global_position + Vector3.UP * 0.9, 0.35):
						figure.held = true
						_catch(player)
						break
			# (it throws itself at them as its arms go wide)
			return [_route() if figure.stage() == GhoulRig.Stage.REACH else Vector3.ZERO, lurch_speed * 0.6]
	var seen := nav.sees(figure.mouth(), after.global_position + Vector3.UP * 1.0, scream_range + 1.0)
	if _scream_in <= 0.0 and flat.length() < scream_range and seen and absf(to.y) < 3.0:
		_screams += 1
		_scream_in = scream_every
		figure.scream()
		_lurching = 0.0
		return [Vector3.ZERO, creep_speed]
	if flat.length() < grab_distance and absf(to.y) < 1.5 and facing.dot(flat.normalized()) > 0.6:
		_grabs += 1
		figure.grab()
		return [Vector3.ZERO, shuffle_speed]
	return [_route(), lurch_speed if _lurching > 0.0 else shuffle_speed]


func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


## The top of a scream (here and on every machine): whoever plays on this
## machine, near enough, in its sight and not turned away, is held.
func _on_shrieked() -> void:
	if not puppet:
		_lurching = lurch_time
	var mouth := figure.mouth()
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		if not (player is Player or player.has_method(&"hold")):
			continue
		if player.get(&"escaped") == true or player.get(&"is_limp") == true:
			continue
		var chest := player.global_position + Vector3.UP * 1.0
		if chest.distance_to(mouth) > freeze_range:
			continue
		if nav and not nav.sees(mouth, chest, freeze_range + 1.0):
			continue
		var yaw: Variant = player.get(&"facing_yaw")
		if yaw != null:
			var away := Vector3(mouth.x - chest.x, 0.0, mouth.z - chest.z).normalized()
			if Vector3(sin(yaw), 0.0, cos(yaw)).dot(away) < -0.25 and chest.distance_to(mouth) > 2.5:
				continue
		paralyse(player, freeze_time)


## Roots a player to the spot for `seconds`, shuddering. One that has a
## `hold(seconds)` of its own is asked to; a Player has its input taken away
## (`takes_input`, given back after) and its figure shaken.
static func paralyse(player: Node3D, seconds: float) -> void:
	if player.has_method(&"hold"):
		player.call(&"hold", seconds)
		return
	var held := player.get_node_or_null(^"GhoulHeld") as Held
	if held:
		held.left = maxf(held.left, seconds)
		return
	if not (player is Player) or not (player as Player).takes_input:
		return
	held = Held.new()
	held.name = "GhoulHeld"
	held.left = seconds
	player.add_child(held)


## What holds a Player still after a scream (see `paralyse`).
class Held extends Node:
	var left := 2.0
	var _time := 0.0
	var _figure: Node3D

	func _ready() -> void:
		var player := get_parent() as Player
		player.takes_input = false
		player.velocity = Vector3(player.velocity.x * 0.2, player.velocity.y, player.velocity.z * 0.2)
		var rig: Variant = player.get(&"_rig")
		if rig is Node:
			_figure = (rig as Node).get(&"_figure") as Node3D

	func _process(delta: float) -> void:
		_time += delta
		left -= delta
		if _figure:
			var shake := 0.035 * smoothstep(0.0, 0.3, left)
			_figure.position.x = sin(_time * 53.0) * shake
			_figure.position.z = sin(_time * 41.0 + 1.0) * shake
		if left <= 0.0:
			queue_free()

	func _exit_tree() -> void:
		var player := get_parent() as Player
		if player:
			player.takes_input = true
		if _figure:
			_figure.position.x = 0.0
			_figure.position.z = 0.0


func _process(delta: float) -> void:
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			figure.visible = not far
			figure.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		figure.global_position = at
		return
	var aim := Vector3.INF
	if puppet:
		if _heard_extra.is_finite():
			aim = _heard_extra
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	else:
		if chasing and quarry:
			aim = quarry.global_position + Vector3.UP * 1.0
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if quarry and chasing and (heading.length_squared() < 0.05 or figure.busy()):
			heading = quarry.global_position - global_position
			heading.y = 0.0
		if mode == Mode.STILL and heading.length_squared() < 0.01:
			heading = Vector3(sin(_home_yaw), 0.0, cos(_home_yaw))
		var turning := figure.stage() not in [GhoulRig.Stage.CLOSE, GhoulRig.Stage.HOLD, GhoulRig.Stage.LET_GO]
		if mode != Mode.WAKING and turning and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	figure.awake = mode != Mode.STILL
	figure.aim = aim
	figure.velocity = velocity
	figure.grounded = is_on_floor() or puppet
	figure.global_position = at
	figure.rotation.y = facing_yaw


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Its screams (low four bits), its grabs (the next three), and whether it has hold of someone (the top bit).
func net_flag() -> int:
	return (_screams & 0x0f) | ((_grabs & 0x07) << 4) | (0x80 if figure and figure.held else 0)


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 1.0
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNTING
	var screams := flag & 0x0f
	var grabs := (flag >> 4) & 0x07
	if not _heard_acts:
		_heard_acts = true
	else:
		if screams != _screams & 0x0f:
			figure.scream()
		if grabs != _grabs & 0x07:
			figure.grab()
	_screams = screams
	_grabs = grabs
	if flag & 0x80 and not figure.held and figure.doing() == GhoulRig.Act.GRAB:
		figure.held = true


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
