class_name MazeBaboon
extends MazeEnemy
## A demonic baboon, or the mandrill that leads a troop of them, hunting the
## maze. What it looks like and how it moves is Baboon (creatures/baboon/, a
## component of its own); this is only what it thinks, and it drives the
## Baboon by moving it and calling on it.
##
## They go in troops (`troop()` makes one: an alpha and three to five
## baboons), and wander the passages at a knuckle-walk, now and then sitting up
## to look about. One that notices someone barks, and the troop near it
## (`alert_range`) takes up the hunt.
##
## THE HUNT. Far off they lope (slower than a run); near, they burst into a
## gallop faster than a run but not a sprint. A burst wears them out
## (`stamina`): spent, one stops dead, rears and bares its fangs at them, pants,
## and goes on when it has its wind. So a boy who sprints gets away, and one who
## only runs is caught in the end. They flank: each baboon has a `flank`, and
## while it is still some way off, one with a flank makes for where its quarry
## is going (where they will be in a few seconds, by the way they are running)
## rather than where they are, so the troop comes at them round different
## corners. The alpha holds back: it keeps a distance, rears and bares its
## fangs and barks, and only comes in if they come near it.
##
## THE CATCH. Close enough and facing them, one crouches (the warning), springs
## at them along the ground and lands on its hands; `caught(player)` is emitted
## only if its hands or jaws find them in the air. A jump or a step aside and
## it misses, and it needs a moment to gather itself.
##
## Online, as every MazeEnemy: the host's copy thinks; a puppet follows what it
## hears, and its leaps, barks and displays are set off by counts in the flag.

## What it is doing, as sent (`net_state`).
enum Mode { ABOUT, SITTING, HUNTING, SPENT, LEAPING, HOLDING }

## The alpha mandrill (else a baboon).
@export var alpha := false
## 0: makes straight for its quarry. 1, 2...: makes for where they are going, this many times further ahead.
@export var flank := 0
@export var wander_speed := 1.5
## Its pace far from its quarry, and its burst when near (the boy runs at 4.4 and sprints at 5.6).
@export var lope_speed := 3.6
@export var burst_speed := 5.15
## Within this of its quarry it bursts.
@export var burst_range := 16.0
## Seconds a full burst lasts, and seconds to get its wind back.
@export var burst_time := 3.4
@export var recover_time := 2.6
@export var acceleration := 14.0
@export var turn_rate := 7.0
## It springs at them from this far, if it is facing them.
@export var leap_range := 3.6
## How near its hands must pass someone to have them.
@export var grab_reach := 0.75
## How far ahead of its quarry a flanker aims, seconds of their running per `flank`.
@export var lead := 1.6
## The alpha keeps this far off while others are at them.
@export var hold_off := 9.0
@export var gravity := 24.0
## Further than this from every player it is not posed.
@export var pose_range := 70.0

var mode := Mode.ABOUT
var stamina := 1.0
## Heading of the body, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
var body: Baboon

var _radius := 0.3
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _sit_in := 4.0
var _sit_left := 0.0
var _bark_in := 3.0
var _leap_from := Vector3.ZERO
var _leap_dir := Vector3.ZERO
var _leap_go := 0.0
var _has_one := false
var _gather := 0.0
var _leaps := 0
var _barks := 0
var _displays := 0
var _far := false
var _far_check := 0.0


## A troop: an alpha and `count - 1` baboons, the baboons flanking by turns.
static func troop(count := 5) -> Array[MazeBaboon]:
	var made: Array[MazeBaboon] = []
	for k in count:
		var one := MazeBaboon.new()
		one.alpha = k == 0
		one.flank = 0 if k <= 1 else (k - 1)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 46.0
	hear_range = 10.0
	memory = 14.0
	alert_range = 40.0
	pack = &"baboons"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	if alpha:
		# (heavier, slower to burst, further to spring)
		lope_speed -= 0.3
		burst_speed -= 0.35
		leap_range = 4.4
		grab_reach = 0.95
	body = Baboon.new()
	body.kind = Baboon.Kind.ALPHA if alpha else Baboon.Kind.BABOON
	body.seed_value = _rng.randi()
	add_child(body)
	body.top_level = true
	_radius = 0.42 if alpha else 0.27
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 1.3 if alpha else 0.95
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	facing_yaw = global_rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	body.global_position = global_position
	body.rotation.y = facing_yaw
	body.settle()
	_sit_in = _rng.randf_range(2.0, 8.0)
	spotted.connect(func(_who: Node3D) -> void: _bark())


func _bark() -> void:
	_barks += 1
	body.bark()
	_bark_in = _rng.randf_range(2.5, 5.5)


func _display(seconds: float) -> void:
	_displays += 1
	body.display(seconds)


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	chasing = hunting()
	var after := quarry if chasing and quarry and quarry.get(&"is_limp") != true else null
	var wish := Vector3.ZERO
	var speed := 0.0
	var grounded := is_on_floor()
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	_gather -= delta
	var bursting := false

	if mode == Mode.LEAPING:
		var stage := body.leap_stage()
		if stage == Baboon.Leap.CROUCH:
			# Crouched: still, turning to follow them a little.
			if after:
				_face(after.global_position - global_position, delta, 0.5)
		elif stage == Baboon.Leap.FLIGHT:
			velocity.x = _leap_dir.x * _leap_go
			velocity.z = _leap_dir.z * _leap_go
			if not _has_one:
				for player: Node3D in players():
					if huntable(player) and body.reaches(player.global_position + Vector3.UP * 0.7, grab_reach):
						_has_one = true
						_catch(player)
						break
		elif stage == Baboon.Leap.LAND:
			velocity.x *= maxf(0.0, 1.0 - 10.0 * delta)
			velocity.z *= maxf(0.0, 1.0 - 10.0 * delta)
			if not _has_one:
				for player: Node3D in players():
					if huntable(player) and body.reaches(player.global_position + Vector3.UP * 0.7, grab_reach):
						_has_one = true
						_catch(player)
						break
		else:
			mode = Mode.HUNTING if chasing else Mode.ABOUT
			_gather = 0.9
		if mode == Mode.LEAPING:
			_fall_and_move(delta, grounded)
			return

	if mode == Mode.SPENT:
		stamina = minf(1.0, stamina + delta / recover_time)
		body.panting = 1.0 - stamina
		if stamina >= 0.7 and not body.displaying():
			mode = Mode.HUNTING if chasing else Mode.ABOUT
		elif after:
			_face(after.global_position - global_position, delta)
	elif chasing and after:
		mode = Mode.HUNTING
		var to := after.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var far := flat.length()
		_bark_in -= delta
		if _bark_in <= 0.0:
			_bark()
		if alpha and far > leap_range * 1.3 and _others_hunting(after):
			# The alpha holds back and threatens.
			mode = Mode.HOLDING
			if far > hold_off:
				wish = _route()
				speed = lope_speed * 0.7
			else:
				_face(flat, delta)
				if not body.displaying() and _rng.randf() < delta * 0.5:
					_display(1.8)
		elif grounded and _gather <= 0.0 and far < leap_range and absf(to.y) < 1.5 and forward.dot(flat.normalized()) > 0.85:
			_spring(after)
		else:
			wish = _route()
			bursting = far < burst_range
			speed = burst_speed if bursting else lope_speed
			if far < leap_range * 0.6:
				_face(flat, delta)
	else:
		# About: knuckle-walking the passages, sitting up now and then to look.
		if mode == Mode.HUNTING or mode == Mode.HOLDING:
			mode = Mode.ABOUT
		if mode == Mode.SITTING:
			_sit_left -= delta
			if _sit_left <= 0.0:
				mode = Mode.ABOUT
				_sit_in = _rng.randf_range(5.0, 14.0)
		else:
			_sit_in -= delta
			if _sit_in <= 0.0:
				mode = Mode.SITTING
				_sit_left = _rng.randf_range(2.0, 4.5)
			else:
				wish = _route()
				speed = wander_speed

	if bursting:
		stamina -= delta / burst_time
		if stamina <= 0.0:
			stamina = 0.0
			mode = Mode.SPENT
			_display(1.4)
			wish = Vector3.ZERO
	elif mode != Mode.SPENT:
		stamina = minf(1.0, stamina + delta / (recover_time * 2.0))
		body.panting = maxf(0.0, body.panting - delta)
	if mode == Mode.SPENT or mode == Mode.SITTING or body.displaying():
		wish = Vector3.ZERO
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if current.length() > 0.3:
		_face(current, delta)
	_fall_and_move(delta, grounded)


func _fall_and_move(delta: float, grounded: bool) -> void:
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _face(toward: Vector3, delta: float, rate := 1.0) -> void:
	if Vector2(toward.x, toward.z).length_squared() < 0.0001:
		return
	facing_yaw = lerp_angle(facing_yaw, atan2(toward.x, toward.z), 1.0 - exp(-turn_rate * rate * delta))


## Springs at `who`: crouches, then flies at them along the ground.
func _spring(who: Node3D) -> void:
	mode = Mode.LEAPING
	_leaps += 1
	_has_one = false
	var to := who.global_position - global_position
	to.y = 0.0
	_leap_dir = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	# (as far as them and a little past; it cannot steer once it is off)
	var flight := 0.5
	_leap_go = clampf(to.length() + 0.8, 1.5, leap_range + 1.2) / flight
	velocity.x = 0.0
	velocity.z = 0.0
	body.leap(flight, 0.9 if alpha else 0.75)


## Whether any other of the troop near is after `who` too.
func _others_hunting(who: Node3D) -> bool:
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other != self and other is MazeBaboon and (other as MazeBaboon).quarry == who and (other as MazeBaboon).chasing:
			return true
	return false


## The way to go: by the passages to its goal, a little apart from the others.
func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


## A flanker, still some way off, makes for where its quarry is going.
func goal() -> Vector3:
	if hunting() and flank > 0:
		var at := quarry.global_position
		var running: Variant = quarry.get(&"velocity")
		if running is Vector3 and global_position.distance_to(at) > 10.0:
			var ahead := at + Vector3((running as Vector3).x, 0.0, (running as Vector3).z) * lead * flank
			var cell := maze.cell_at(ahead)
			if nav.allowed(cell) and maze.inside(cell):
				return ahead
		return at
	return super()


func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			body.visible = not far
			body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))
	body.sitting = mode == Mode.SITTING
	var after: Node3D = quarry if chasing else null
	if puppet:
		body.look_at_point = _heard_extra if _heard_extra.is_finite() else Vector3.INF
	else:
		body.look_at_point = after.global_position + Vector3.UP * 1.0 if after else Vector3.INF
	body.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	body.rotation = Vector3(0.0, facing_yaw, 0.0)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Leaps (low four bits), barks (next three), and displays (the top bit flips with each).
func net_flag() -> int:
	return (_leaps & 0x0f) | ((_barks & 0x07) << 4) | ((_displays & 1) << 7)


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 1.0
	return Vector3.INF


var _heard_flags := -1


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNTING or mode == Mode.HOLDING or mode == Mode.LEAPING
	if body:
		body.panting = 0.8 if mode == Mode.SPENT else 0.0
	if _heard_flags >= 0 and body:
		if (flag & 0x0f) != (_heard_flags & 0x0f):
			body.leap(0.5, 0.9 if alpha else 0.75)
		if ((flag >> 4) & 0x07) != ((_heard_flags >> 4) & 0x07):
			body.bark()
		if (flag >> 7) != (_heard_flags >> 7):
			body.display(1.6)
	_heard_flags = flag


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if body:
		body.global_position = at
		body.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
