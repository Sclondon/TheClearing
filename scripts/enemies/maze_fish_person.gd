class_name MazeFishPerson
extends MazeEnemy
## A fish person (creatures/fish_person/: a deep one, out of Innsmouth) set to
## keep a stretch of passage. This is only its thinking; how it looks and moves
## is the `FishPerson` component, which this drives.
##
## - IT LURKS. Put somewhere (best in the middle of a hall), it lies in a pool
##   of black water of its own (`FishPool`), sunk to its eyes: a puddle with
##   two eyes and the crown of a head in it, if you look. Down there it sees
##   little and hears only what is loud: anyone who comes within `wake_range`,
##   steps into its pool, or runs within `loud_range` (faster than
##   `loud_speed`) brings it up. Walk softly past along the far wall and it
##   stays down.
## - IT RISES AND CROAKS. It comes up out of the water (FishPerson.RISE_TIME)
##   and croaks, a gurgling croak that breaks into a screech, and every other
##   fish person within `call_range` takes up the hunt for whoever woke it,
##   rising out of its own pool. It croaks again, calling, whenever it sees
##   them far off (every `croak_every` seconds at most).
## - IT SHAMBLES, AND LOPES. It goes after them slowly (`shamble_speed`, below
##   a walk) by the passages; but whenever it sees them within `lope_range` it
##   lopes at them, faster than a run (`lope_speed`), for `lope_time`, and then
##   must stand and gulp for breath (`winded_time`). A sprint, or a corner,
##   loses it.
## - IT GRABS. Within `grab_distance`, facing them, it lunges with both hands;
##   `caught(player)` is emitted only if they close on someone (FishPerson.grab_hits).
## - IT DRIES. It cannot be long out of the water: after `dry_time` seconds out
##   of its pool, or when it has forgotten them, it shambles back to its pool
##   and sinks into it again, and lurks.
##
## Online, the host thinks for it and the others' copies are puppets: each
## croak and grab is sent with its state (`net_flag`) and played out here too,
## as is rising out of the water and sinking back into it. Catching is the
## host's alone.
##
## Spawn (as MazeEnemies.add does): `MazeFishPerson.new()`, set `maze`, place it
## and turn it (rotation.y, 0 faces +Z), add it to the tree. Where it is put is
## its pool.

enum Mode { LURKING, RISING, HUNTING, RETURNING, SINKING }

## How much bigger than it is modelled it is drawn (and goes).
const SIZE := 1.5

## Its shamble, and how fast it lopes and for how long, then how long it must stand to get its breath.
@export var shamble_speed := 1.2
@export var lope_speed := 4.8
@export var lope_time := 1.7
@export var winded_time := 2.8
## It lopes at whoever it is after when it sees them this near.
@export var lope_range := 13.0
## Down in its pool: how near anyone wakes it, and how near someone running does (faster than `loud_speed`).
@export var wake_range := 4.5
@export var loud_range := 13.0
@export var loud_speed := 3.0
## Its croak calls others of its kind this near; it croaks again at most this often.
@export var call_range := 42.0
@export var croak_every := 14.0
## How near it must be to lunge.
@export var grab_distance := 2.1
## Seconds out of its pool before it must go back.
@export var dry_time := 30.0
@export var turn_rate := 3.0
@export var gravity := 24.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0
## How far its pool reaches, metres.
@export var pool_radius := 1.8

var mode := Mode.LURKING
## Which way it faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## The figure it drives, and the water it lurks in.
var figure: FishPerson
var pool: FishPool

var _home := Vector3.ZERO
var _home_yaw := 0.0
var _lope_left := 0.0
var _winded_left := 0.0
var _croak_in := 0.0
var _dry := 0.0
var _listen_in := 0.0
var _croaks := 0
var _grabs := 0
var _radius := 0.4
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_acts := false
var _winded := 0.0


func _init() -> void:
	sight_range = 26.0
	hear_range = 7.0
	memory = 9.0
	alert_range = 0.0
	pack = &"fish_people"


func _ready() -> void:
	add_to_group(&"pursuers")
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.27 * SIZE
	shape.radius = _radius
	shape.height = 1.3 * SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)

	_home = _clear_of_walls(global_position)
	global_position = _home
	_home_yaw = rotation.y
	facing_yaw = _home_yaw
	pool = FishPool.new()
	pool.radius = pool_radius
	pool.shape_seed = int(absf(_home.x * 7.0 + _home.z * 13.0)) % 1000
	pool.visibility_range_end = pose_range + 20.0
	add_child(pool)
	pool.top_level = true
	pool.global_position = _home - Vector3.UP * 0.05

	figure = FishPerson.new()
	figure.scale = Vector3.ONE * SIZE
	add_child(figure)
	figure.top_level = true
	figure.pool = pool
	figure.croaked.connect(_on_croaked)
	figure.risen.connect(_on_risen)
	figure.sank.connect(_on_sank)
	reset()


## Where to lie, put in the middle of a cell: moved off any side of it that is
## walled (the walls are thick, and their faces near), so that its pool is out
## in the hall. Anywhere else it is left where it is put.
func _clear_of_walls(at: Vector3) -> Vector3:
	if maze == null:
		return at
	var cell := maze.cell_at(at)
	var middle := maze.world(cell)
	if Vector2(at.x - middle.x, at.z - middle.z).length() > 1.0:
		return at
	var push := Vector3.ZERO
	for s: Vector2i in Maze.STEPS:
		if maze.blocked(cell, s) and not maze.blocked(cell, -s):
			push -= Vector3(s.x, 0.0, s.y) * 3.2
	return at + push


## Back in its pool, sunk to the eyes.
func reset() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	chasing = false
	_set_mode(Mode.LURKING)
	facing_yaw = _home_yaw
	_prev_pos = _home
	_curr_pos = _home
	_dry = 0.0
	figure.awake = false
	figure.aim = Vector3.INF
	figure.put(_home, facing_yaw, true)


func _set_mode(next: Mode) -> void:
	mode = next
	# (down in the water there is nothing to bump into)
	var solid := not puppet and next in [Mode.HUNTING, Mode.RETURNING]
	collision_layer = 4 if solid else 0
	collision_mask = 1 if puppet else (1 | 4 if solid else 1)


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_croak_in -= delta
	var wish := Vector3.ZERO
	var speed := shamble_speed
	match mode:
		Mode.LURKING:
			_lurk(delta)
		Mode.RISING:
			_sense(delta)
		Mode.HUNTING:
			_sense(delta)
			_dry += delta
			if (not hunting() or _dry > dry_time) and not figure.busy():
				_set_mode(Mode.RETURNING)
			else:
				var act := _hunt(delta)
				wish = act[0]
				speed = act[1]
		Mode.RETURNING:
			_sense(delta)
			if hunting() and _dry < dry_time * 0.6:
				_set_mode(Mode.HUNTING)
			else:
				var to := _home - global_position
				to.y = 0.0
				if to.length() < 0.35:
					_set_mode(Mode.SINKING)
					figure.awake = false
					figure.submerge()
				else:
					var step := nav.waypoint(global_position, _home, MazeNav.clearance_for(_radius)) - global_position
					step.y = 0.0
					wish = step.normalized() if step.length() > 0.05 else to.normalized()
					speed = shamble_speed * (0.6 if to.length() < 1.5 else 1.0)
		Mode.SINKING:
			pass
	if mode != Mode.HUNTING:
		_lope_left = 0.0
	chasing = mode == Mode.HUNTING and hunting()
	if mode in [Mode.HUNTING, Mode.RETURNING] and _dry > 0.0 and _distance_home() < pool_radius:
		# (back in the wet, it soaks again)
		_dry = maxf(_dry - delta * 4.0, 0.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, (14.0 if speed > shamble_speed * 1.5 else 6.0) * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _distance_home() -> float:
	return Vector2(global_position.x - _home.x, global_position.z - _home.z).length()


## Down in its pool: listens, a few times a second, for anyone near, in the
## water, or running; and rises if it hears them, or is called (`alerted`).
func _lurk(delta: float) -> void:
	# (whoever it caught is let alone a while, down here too)
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_listen_in -= delta
	if _listen_in <= 0.0:
		_listen_in = look_every
		for player: Node3D in players():
			if not huntable(player):
				continue
			var far := player.global_position.distance_to(global_position)
			var moving: Variant = player.get(&"velocity")
			var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
			var loud := pace > loud_speed and far < loud_range and (nav.sees(global_position + Vector3.UP * 0.4, player.global_position + Vector3.UP, loud_range) or far < loud_range * 0.6)
			if far < wake_range or loud:
				notice(player)
				break
	if quarry:
		_rise()


func _rise() -> void:
	_set_mode(Mode.RISING)
	_dry = 0.0
	figure.awake = true
	figure.emerge()


## Up out of the water: it croaks, and the hunt is on.
func _on_risen() -> void:
	if puppet:
		return
	_set_mode(Mode.HUNTING)
	_croak()


func _on_sank() -> void:
	if puppet:
		return
	_set_mode(Mode.LURKING)
	global_position = _home
	_prev_pos = _home
	_curr_pos = _home
	figure.put(_home, facing_yaw, true)


func _croak() -> void:
	_croaks += 1
	_croak_in = croak_every
	figure.croak()


## Told by one of its kind (its croak) that `player` is about: it rises, if it was down.
func alerted(player: Node3D, from: Vector3) -> void:
	super(player, from)
	if mode == Mode.LURKING and quarry:
		_rise()


## The croak goes out: every other fish person in reach takes up the hunt.
func _on_croaked() -> void:
	if puppet or quarry == null:
		return
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other != self and other is MazeFishPerson and not other.puppet and (other as Node3D).global_position.distance_to(global_position) < call_range:
			(other as MazeFishPerson).alerted(quarry, global_position)


## While after someone: what it does, and which way and how fast it goes.
func _hunt(delta: float) -> Array:
	_lope_left -= delta
	_winded_left -= delta
	var after := quarry if quarry and quarry.get(&"is_limp") != true else null
	if after == null:
		return [_route(), shamble_speed]
	var to := after.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	match figure.doing():
		FishPersonRig.Act.CROAK:
			return [Vector3.ZERO, 0.0]
		FishPersonRig.Act.GRAB:
			if figure.stage() == FishPersonRig.Stage.CLOSE and not figure.held:
				for player: Node3D in players():
					if huntable(player) and figure.grab_hits(player.global_position + Vector3.UP * 0.9, 0.35):
						figure.held = true
						_catch(player)
						break
			# (it throws itself at them as it lunges)
			var lunging := figure.stage() in [FishPersonRig.Stage.WIND, FishPersonRig.Stage.LUNGE]
			return [flat.normalized() if lunging else Vector3.ZERO, 3.2]
	var seen := nav.sees(figure.eyes(), after.global_position + Vector3.UP * 1.0, sight_range)
	if flat.length() < grab_distance and absf(to.y) < 1.5 and facing.dot(flat.normalized()) > 0.5:
		_grabs += 1
		_lope_left = 0.0
		figure.grab()
		return [Vector3.ZERO, shamble_speed]
	if seen and _croak_in <= 0.0 and flat.length() > lope_range:
		_croak()
		return [Vector3.ZERO, 0.0]
	if seen and _lope_left <= 0.0 and _winded_left <= 0.0 and flat.length() < lope_range:
		_lope_left = lope_time
		_winded_left = lope_time + winded_time
	if _lope_left > 0.0:
		return [_route(), lope_speed]
	if _winded_left > 0.0:
		return [_route(), shamble_speed * 0.6]
	return [_route(), shamble_speed]


func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


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
	var pace := Vector2(velocity.x, velocity.z).length()
	# (it breathes hard after a lope, and gets its breath back slowly)
	_winded = clampf(_winded + (delta * 0.8 if pace > lope_speed * 0.7 else -delta * 0.25), 0.0, 1.0)
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
		if mode in [Mode.LURKING, Mode.SINKING] and heading.length_squared() < 0.01:
			heading = Vector3(sin(_home_yaw), 0.0, cos(_home_yaw))
		var turning := figure.stage() not in [FishPersonRig.Stage.CLOSE, FishPersonRig.Stage.HOLD, FishPersonRig.Stage.LET_GO]
		if turning and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	figure.awake = mode in [Mode.RISING, Mode.HUNTING, Mode.RETURNING]
	figure.winded = _winded
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


## Its croaks (low four bits), its grabs (the next three), and whether it has hold of someone (the top bit).
func net_flag() -> int:
	return (_croaks & 0x0f) | ((_grabs & 0x07) << 4) | (0x80 if figure and figure.held else 0)


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 1.0
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var croaks := flag & 0x0f
	var grabs := (flag >> 4) & 0x07
	if not _heard_acts:
		_heard_acts = true
	else:
		if croaks != _croaks & 0x0f:
			figure.croak()
		if grabs != _grabs & 0x07:
			figure.grab()
	_croaks = croaks
	_grabs = grabs
	if flag & 0x80 and not figure.held and figure.doing() == FishPersonRig.Act.GRAB:
		figure.held = true


## As a puppet: rises out of the water and sinks into it as the host's does.
func _heard_changed(_was: int, now: int, first: bool) -> void:
	var next := now as Mode
	_set_mode(next)
	match next:
		Mode.LURKING:
			if first or figure.sunk < 0.99:
				figure.awake = false
				figure.put(_home if first else global_position, facing_yaw, true)
		Mode.RISING:
			figure.emerge()
		Mode.SINKING:
			figure.submerge()
		_:
			if figure.sunk > 0.0 and not figure.moving_in_water():
				figure.emerge()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing, mode in [Mode.LURKING])


func _puppet_changed() -> void:
	_set_mode(mode)
