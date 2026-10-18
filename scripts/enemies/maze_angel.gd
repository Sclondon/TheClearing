class_name MazeAngel
extends MazeEnemy
## A "biblically accurate" angel (creatures/angel/: Ophan is how it looks and
## moves; this is how it hunts the maze): wheels within wheels full of eyes,
## a burning heart behind six wings, hanging `hover` metres over the floor.
##
## - IT DRIFTS. Silent and slow (`drift_speed` after someone, `wander_speed`
##   otherwise, both under a boy's walk), it goes along the halls well off the
##   floor; everyone passes under it. It never hurries and never reaches.
## - IT SEES EVERY WAY. Its eyes are all round it: there is no creeping past
##   behind it. It notices anyone in a straight line down the passages within
##   `gaze_range` (MazeEnemy's senses), and the one it is after it GAZES at.
## - ITS GAZE IS WHAT TAKES YOU. While someone is in its gaze (in its sight and
##   in the open) the gaze builds on them, over `gaze_time` seconds (sooner
##   near it, later far off: `gaze_near`, `gaze_far`). Everyone can see and
##   hear it build: every eye turns on them, the wheels slow and stand still,
##   the wings before its face part and its heart burns brighter, a cone of
##   pale light reaches down to them and pools round their feet, and its choir
##   swells and rises. While it gazes it stops where it is. If it reaches the
##   full, they are TAKEN: drawn up off the ground in a flood of light for
##   `take_time` seconds, and then `caught`.
## - BREAKING ITS SIGHT ENDS IT. Round a corner, into a slot, or onto the ivy
##   (pressed into the leaves, on a ladder: `in_cover`), the gaze falls away
##   (over `fade_time` seconds from the full) and it drifts on towards where it
##   saw them last. After taking someone it rests for `rest_time`.
##
## Online it is run where MazeEnemies is run (the host); a puppet shows what it
## hears: its state, how far its gaze has built (`net_flag`, 0..255) and where
## it looks (`net_point`). Being taken is played out on every machine for
## whoever plays there (`lift`); the catch is the host's alone.
##
## `MazeAngel.new()`, then MazeEnemies.add (which sets `maze`); it is drawn
## `size` times Ophan's size (6.6 m across the outer wheel).

## What it is doing (`net_state`).
enum Mode { DRIFTING, GAZING, TAKING, RESTING }

## How big it is drawn, against Ophan's own size.
@export var size := 1.0
## How high its heart hangs over the floor (metres, at size 1).
@export var hover := 6.2
## Metres a second, after someone and wandering.
@export var drift_speed := 0.9
@export var wander_speed := 0.55
@export var turn_rate := 0.6
## How far its gaze reaches (straight down the passages).
@export var gaze_range := 42.0
## Seconds in its gaze before someone is taken, at middle range; quicker near
## it and slower far off (`gaze_near` times as fast within 6 m, `gaze_far` at
## the end of its range).
@export var gaze_time := 3.8
@export var gaze_near := 1.6
@export var gaze_far := 0.6
## Seconds for a full gaze to fall away once they are out of it.
@export var fade_time := 1.4
## How long being taken takes, and how long it rests after.
@export var take_time := 1.7
@export var rest_time := 5.0
## Further than this from every player it is not drawn (the walls hide it; its
## light is seen a long way in the mist, so further than the others).
@export var pose_range := 90.0

var mode := Mode.DRIFTING
## Which way it faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## Who it is gazing at, and how far its gaze on them has built (0..1).
var gazed: Node3D
var gaze := 0.0

var _body: Ophan
var _keep_off := 4.6
var _taking := 0.0
var _rest := 0.0
var _takes := 0
var _time := 0.0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _taken_here: Node


func _init() -> void:
	sight_range = 42.0
	hear_range = 6.0
	memory = 14.0
	alert_range = 0.0
	spare_time = 5.0
	pack = &"angels"


func _ready() -> void:
	add_to_group(&"pursuers")
	sight_range = gaze_range
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_keep_off = 4.3 * size
	# (it bumps the walls only at its heart's height: everyone goes under it)
	var shape := SphereShape3D.new()
	shape.radius = 1.4 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = hover * size
	add_child(collider)
	facing_yaw = rotation.y
	if maze:
		# (put in the middle of a cell, it moves out from a wall that is too near)
		global_position += wall_push(global_position, _keep_off)
	rotation.y = 0.0
	_body = Ophan.new()
	_body.name = "Body"
	_body.eye_seed = _rng.randi()
	add_child(_body)
	_body.top_level = true
	_body.scale = Vector3.ONE * size
	_body.global_position = heart()
	_body.rotation.y = facing_yaw
	_prev_pos = global_position
	_curr_pos = global_position


func body() -> Ophan:
	return _body


## Where its heart is (world): `hover` over where it is, bobbing a little.
func heart() -> Vector3:
	return global_position + Vector3.UP * (hover + 0.25 * sin(_time * 0.6)) * size


## How far its gaze on `player` has built (0 if it is not gazing at them).
func gaze_on(player: Node3D) -> float:
	return gaze if player == gazed else 0.0


## Whether `player` is out of its sight however near: on the ivy (a ladder),
## pressed into the leaves.
static func in_cover(player: Node3D) -> bool:
	return player is Player and (player as Player).state == Player.State.LADDER


## Whether `player` is in its gaze now: huntable, in reach, in a straight line
## from its heart down the passages (by the plan, and by a ray against the walls
## and stone themselves, so that a thick wall's corner or a terrace hides them),
## and not in cover.
func in_gaze(player: Node3D) -> bool:
	if player == null or not huntable(player) or in_cover(player):
		return false
	var from := heart()
	var chest := _chest(player)
	if not nav.sees(from, chest, gaze_range):
		return false
	if not is_inside_tree():
		return true
	var ray := PhysicsRayQueryParameters3D.create(from, chest, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


## How far to move `point` to keep it `want` metres off the faces of the walls
## round its cell, as thick as they really are (the walls of the first ring are
## far thicker than MazeNav takes them to be, and the middle of a cell can be a
## metre from one). Between two walls nearer than that it is put midway.
func wall_push(point: Vector3, want: float) -> Vector3:
	var cell := maze.cell_at(point)
	var off := point - maze.world(cell)
	var push := Vector3.ZERO
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			continue
		var out := Vector3(step.x, 0.0, step.y)
		var gap := Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5 - off.dot(out)
		if gap < want:
			push -= out * (want - gap)
	return push


## Which way to drift: through the passages towards `goal()`, by the middle of
## each hall (the next cell's middle, kept off its walls by `wall_push`).
func _route() -> Vector3:
	var here := maze.cell_at(global_position)
	var to := goal()
	var there := maze.cell_at(to)
	var aim := to
	if here != there:
		var next := nav.next_cell(here, there)
		aim = maze.world(next)
	aim += wall_push(aim, _keep_off)
	var way_flat := (aim - global_position) * Vector3(1, 0, 1)
	var wish := way_flat.normalized() if way_flat.length() > 0.6 else Vector3.ZERO
	return wish


func _chest(player: Node3D) -> Vector3:
	return player.global_position + Vector3.UP * 1.0


func _physics_process(delta: float) -> void:
	_time += delta
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	var wish := Vector3.ZERO
	var speed := wander_speed
	match mode:
		Mode.DRIFTING, Mode.GAZING:
			_build_gaze(delta)
			if gaze >= 1.0 and gazed:
				_take(gazed)
			elif gaze > 0.12:
				mode = Mode.GAZING
			else:
				mode = Mode.DRIFTING
				wish = _route()
				speed = drift_speed if hunting() else wander_speed
		Mode.TAKING:
			_taking += delta
			gaze = 1.0
			if _taking >= take_time:
				var who := gazed
				_end_lift(who)
				gazed = null
				gaze = 0.0
				mode = Mode.RESTING
				_rest = rest_time
				if who and is_instance_valid(who):
					_catch(who)
		Mode.RESTING:
			_rest -= delta
			gaze = maxf(gaze - delta / fade_time, 0.0)
			if _rest <= 0.0:
				mode = Mode.DRIFTING
	chasing = mode != Mode.DRIFTING or hunting()
	# (and always edging back off any wall it has come too near)
	var off_wall := wall_push(global_position, _keep_off).limit_length(1.5) * 0.5
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed * size + off_wall, 0.6 * delta)
	velocity = flat
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Builds its gaze on whoever it is after while they are in it, and lets it fall
## away while they are not (it must fall to nothing before it turns on another).
func _build_gaze(delta: float) -> void:
	var target := quarry if quarry and in_gaze(quarry) else null
	if gazed and gazed != target:
		gaze -= delta / fade_time
		if gaze <= 0.0 or not is_instance_valid(gazed) or not huntable(gazed):
			gaze = 0.0
			gazed = null
		return
	if target == null:
		gaze = maxf(gaze - delta / fade_time, 0.0)
		if gaze <= 0.0:
			gazed = null
		return
	gazed = target
	var far := clampf((heart().distance_to(_chest(target)) - 6.0) / maxf(gaze_range - 6.0, 1.0), 0.0, 1.0)
	gaze = minf(gaze + delta / gaze_time * lerpf(gaze_near, gaze_far, far), 1.0)


func _take(player: Node3D) -> void:
	mode = Mode.TAKING
	_taking = 0.0
	_takes += 1
	_body.blaze()
	_start_lift(player)


## Being taken, as seen on the machine `player` plays on: drawn up off the
## ground into the light, input gone, for `seconds`.
static func lift(player: Node3D, seconds: float, toward: Vector3) -> Node:
	if not (player is Player):
		return null
	var held := player.get_node_or_null(^"AngelTaken")
	if held:
		return held
	var taken := Taken.new()
	taken.name = "AngelTaken"
	taken.length = seconds
	taken.toward = toward
	player.add_child(taken)
	return taken


func _start_lift(player: Node3D) -> void:
	if player:
		_taken_here = lift(player, take_time + 0.2, heart())


func _end_lift(_player: Node3D) -> void:
	if _taken_here and is_instance_valid(_taken_here):
		_taken_here.queue_free()
	_taken_here = null


## What holds a Player while the angel takes him (see `lift`): no input, his own
## movement stopped, and he is drawn straight up off the ground into the light,
## slowly at first, turning as he goes. If he is not caught (and so put
## somewhere else) by the end, he is set down where he was.
class Taken extends Node:
	var length := 1.8
	var toward := Vector3.ZERO
	var _time := 0.0
	var _from := Vector3.ZERO
	var _had_input := true
	var _yaw := 0.0

	func _ready() -> void:
		var player := get_parent() as Player
		_had_input = player.takes_input
		player.takes_input = false
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		_from = player.global_position
		_yaw = player.rotation.y

	func _process(delta: float) -> void:
		_time += delta
		var player := get_parent() as Player
		var up := smoothstep(0.0, length, _time)
		player.global_position = _from + Vector3.UP * up * up * 3.2
		player.rotation.y = _yaw + up * up * 1.6
		if _time >= length:
			queue_free()

	func _exit_tree() -> void:
		var player := get_parent() as Player
		if player == null:
			return
		player.set_physics_process(true)
		player.takes_input = _had_input
		player.rotation.y = _yaw
		# (still up in the air where it left him: nobody has put him anywhere else)
		var lifted := Vector2(player.global_position.x - _from.x, player.global_position.z - _from.z).length() < 0.5
		if lifted:
			player.global_position = _from


func _process(delta: float) -> void:
	var shown := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	if puppet:
		_time += delta
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			_body.visible = not far
			_body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var look := Vector3.INF
	if puppet:
		look = _heard_extra if _heard_extra.is_finite() else Vector3.INF
		gaze = move_toward(gaze, _heard_flag / 255.0, delta * 2.0)
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-4.0 * delta))
	else:
		var who := gazed if gazed else (quarry if quarry and hunting() and in_gaze(quarry) else null)
		if who:
			look = _chest(who) + Vector3.UP * 0.2
			var to := who.global_position - global_position
			if Vector2(to.x, to.z).length() > 1.0:
				facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-turn_rate * delta))
		else:
			var heading := Vector3(velocity.x, 0.0, velocity.z)
			if heading.length_squared() > 0.01:
				facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * 0.5 * delta))
	_body.look_at_point = look
	_body.gaze = gaze
	_body.gaze_ground = Vector3(look.x, look.y - 1.2, look.z) if look.is_finite() else Vector3.INF
	_body.global_position = shown + Vector3.UP * (hover + 0.25 * sin(_time * 0.6)) * size
	_body.rotation.y = facing_yaw


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## How far its gaze has built, 0..255.
func net_flag() -> int:
	return clampi(int(gaze * 255.0), 0, 255)


func net_point() -> Vector3:
	if gazed and is_instance_valid(gazed):
		return _chest(gazed) + Vector3.UP * 0.2
	if quarry and hunting():
		return _chest(quarry) + Vector3.UP * 0.2
	return Vector3.INF


func _heard_changed(_was: int, now: int, first: bool) -> void:
	mode = now as Mode
	chasing = mode != Mode.DRIFTING
	if first or _body == null:
		return
	if mode == Mode.TAKING:
		_body.blaze()
		# (whoever plays here, if it is them it is taking, is drawn up here too)
		var mine := local_player()
		if mine and _heard_extra.is_finite() and _chest(mine).distance_to(_heard_extra - Vector3.UP * 0.2) < 2.5:
			_taken_here = lift(mine, take_time + 0.2, global_position)
	elif _taken_here and is_instance_valid(_taken_here) and mode != Mode.TAKING:
		_taken_here.queue_free()
		_taken_here = null


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO


func _follow(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	velocity = Vector3(_heard_moving.x, 0.0, _heard_moving.z) + (_heard_at - global_position) * Vector3(4.0, 0.0, 4.0)
	move_and_slide()
	if global_position.distance_to(_heard_at) > 2.5:
		global_position = _heard_at
