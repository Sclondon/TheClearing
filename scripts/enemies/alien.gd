class_name Alien
extends MazeEnemy
## A grey (creatures/alien/: AlienBody is how it looks and moves; this is how
## it hunts the maze). They go about in twos and threes.
##
## - It never hurries. It walks the passages slowly and calmly (`walk_speed`,
##   well under a boy's walk) after whoever it has noticed (MazeEnemy's senses),
##   and calls the others of its kind near it (`alert_range`).
## - IT BLINKS. While nobody is looking at it (see `watched`), and it has not
##   for `blink_every` seconds, it can go from where it is to the passage ahead
##   of whoever it is after: one or two cells on from them the way they are
##   going (`_ahead`). First a column of pale light wavers there for
##   `warning` seconds (the tell: that is where it is coming); then it goes out
##   in a flash where it stands and comes out of the light there, facing them,
##   and walks at them. Anyone turning to look at it while the light wavers
##   stops it: it stays where it is.
## - It catches by abducting. Within `reach_distance` it stops and raises a long
##   hand at them (AlienBody's RAISE: the time to get out of the way), and then
##   pale light shines from its palm; anyone in that light then is `caught`.
## - Players pass through it; the world, and the others hunting here, stop it.
##
## Online it is run where MazeEnemies is run (the host); a puppet follows the
## host's news and shows the warning, the blinks and the reaching hand as they
## are sent (its state, and the place they are aimed at, as `net_point`).
##
## `Alien.new()`, then MazeEnemies.add (which sets `maze`); it is drawn
## `size` times AlienBody's 2.3 m.

## What it is doing (`net_state`).
enum Mode { ABOUT, HUNTING, REACHING, WARNING, GONE, ARRIVING }

## How big it is drawn, against AlienBody's 2.3 m.
@export var size := 1.0
## Metres a second: it never goes faster.
@export var walk_speed := 1.25
@export var acceleration := 4.0
@export var turn_rate := 2.5
## How near (on the flat) someone must be for it to raise its hand at them.
@export var reach_distance := 2.4
## Seconds between blinks, at least; and how long the warning light shows first.
@export var blink_every := 7.0
@export var warning := 1.1
## It only blinks to someone at least this far off (metres, by the passages
## more or less: a straight line is not enough, see `_blink_to`).
@export var blink_from := 12.0
## How square on someone must be facing it to count as looking at it (the
## cosine of the angle off their facing), and how far they see it from.
@export var watch_cone := 0.55
@export var watch_range := 60.0
@export var gravity := 24.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0

var mode := Mode.ABOUT
## Which way it faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## Where it is going to blink to (INF: nowhere).
var blink_target := Vector3.INF

var _body: AlienBody
var _radius := 0.3
var _blink_wait := 0.0
var _warning_left := 0.0
var _reaches := 0
var _blinks := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0


func _init() -> void:
	sight_range = 46.0
	hear_range = 8.0
	memory = 25.0
	alert_range = 40.0
	pack = &"aliens"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 2.2 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	facing_yaw = rotation.y
	rotation.y = 0.0
	_body = AlienBody.new()
	_body.name = "Body"
	add_child(_body)
	_body.top_level = true
	_body.scale = Vector3.ONE * size
	_body.global_position = global_position
	_body.rotation.y = facing_yaw
	_body.settle()
	_prev_pos = global_position
	_curr_pos = global_position
	_blink_wait = blink_every * 0.5


func body() -> AlienBody:
	return _body


## Lets it blink as soon as it may (it waits half of `blink_every` at first).
func blink_wait_now() -> void:
	_blink_wait = 0.0


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	_blink_wait -= delta
	var after := quarry if hunting() and quarry and quarry.get(&"is_limp") != true else null
	var wish := Vector3.ZERO
	match mode:
		Mode.ABOUT, Mode.HUNTING:
			mode = Mode.HUNTING if hunting() else Mode.ABOUT
			chasing = mode == Mode.HUNTING
			if after:
				var to := after.global_position - global_position
				var flat := Vector3(to.x, 0.0, to.z)
				if is_on_floor() and flat.length() < reach_distance * size and absf(to.y) < 1.6 * size:
					mode = Mode.REACHING
					_reaches += 1
					_body.reach(_chest(after))
				elif _blink_wait <= 0.0 and not _watched():
					var there := _blink_to(after)
					_blink_wait = 1.0
					if there.is_finite():
						blink_target = there
						mode = Mode.WARNING
						_warning_left = warning
						_body.shimmer(there, warning)
			if mode == Mode.ABOUT or mode == Mode.HUNTING:
				var to_go := way(_radius)
				wish = to_go.normalized() if to_go.length() > 0.05 else Vector3.ZERO
				var push := _apart(_radius)
				if push != Vector3.ZERO:
					wish = (wish + push * 0.8).normalized()
		Mode.REACHING:
			# (it follows them round as it raises its hand, but not to the last)
			if _body.reach_stage() == AlienBody.Reach.RAISE and after and _body.reach_in() > 0.3:
				_body.reach_aim = _chest(after)
			elif _body.reach_stage() == AlienBody.Reach.GRAB:
				for player: Node3D in players():
					if huntable(player) and _body.in_beam(_chest(player), 0.25):
						_catch(player)
			elif _body.reach_stage() == AlienBody.Reach.NONE:
				mode = Mode.HUNTING if hunting() else Mode.ABOUT
		Mode.WARNING:
			_warning_left -= delta
			if _watched():
				# (seen, it thinks better of it)
				_body.stop_shimmer()
				blink_target = Vector3.INF
				mode = Mode.HUNTING if hunting() else Mode.ABOUT
				_blink_wait = 2.0
			elif _warning_left <= 0.0:
				_blinks += 1
				_body.blink_out()
				mode = Mode.GONE
		Mode.GONE:
			if _body.blink_stage() == AlienBody.Blink.GONE:
				var yaw_to := facing_yaw
				if after:
					var look := after.global_position - blink_target
					yaw_to = atan2(look.x, look.z)
				global_position = blink_target
				velocity = Vector3.ZERO
				facing_yaw = yaw_to
				_prev_pos = global_position
				_curr_pos = global_position
				_body.blink_in(blink_target, yaw_to)
				mode = Mode.ARRIVING
		Mode.ARRIVING:
			if _body.blink_stage() == AlienBody.Blink.NONE:
				blink_target = Vector3.INF
				_blink_wait = blink_every
				mode = Mode.HUNTING if hunting() else Mode.ABOUT
	chasing = mode != Mode.ABOUT
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * walk_speed * size, acceleration * delta)
	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	if mode != Mode.GONE:
		move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Someone's chest, which is what it reaches for.
func _chest(player: Node3D) -> Vector3:
	var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
	return player.global_position + Vector3.UP * (0.5 if low else 0.95)


## Whether any player there is to hunt is looking at it: facing it near enough
## square on, with nothing in the way.
func _watched() -> bool:
	var chest := global_position + Vector3.UP * 1.4 * size
	for player: Node3D in players():
		if not huntable(player):
			continue
		var eye := player.global_position + Vector3.UP * 1.4
		var to := chest - eye
		if to.length() > watch_range:
			continue
		var facing: Variant = player.get(&"facing_yaw")
		var forward := Vector3(sin(facing), 0.0, cos(facing)) if facing != null else Vector3.ZERO
		if facing == null and player.get(&"velocity") is Vector3:
			forward = (player.get(&"velocity") as Vector3) * Vector3(1, 0, 1)
		if forward.length_squared() < 0.0001:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		if forward.normalized().dot(flat) > watch_cone and nav.sees(eye, chest, watch_range):
			return true
	return false


## Where to blink to, to cut `player` off: the middle of a cell one or two on
## from theirs (by the passages), as straight ahead of them as there is, well
## clear of the walls and not on top of them. INF when there is none (or they
## are too near to be worth it).
func _blink_to(player: Node3D) -> Vector3:
	var at := player.global_position
	if at.distance_to(global_position) < blink_from * size:
		return Vector3.INF
	var going: Vector3 = player.get(&"velocity") if player.get(&"velocity") is Vector3 else Vector3.ZERO
	going.y = 0.0
	if going.length() < 1.0:
		var facing: Variant = player.get(&"facing_yaw")
		going = Vector3(sin(facing), 0.0, cos(facing)) if facing != null else Vector3.ZERO
	if going.length_squared() < 0.0001:
		return Vector3.INF
	going = going.normalized()
	var from := maze.cell_at(at)
	var steps := nav.field(from)
	var best := Vector3.INF
	var score := 0.3
	for cell in _cells_near(from, 2):
		var d := steps[maze.index(cell)]
		if d < 1 or d > 2 or not nav.allowed(cell) or maze.in_clearing(cell):
			continue
		var spot := maze.world(cell)
		var off := spot - at
		off.y = 0.0
		if off.length() < 8.0 or not nav.clear_of_walls(spot, 1.2 * size) or _taken(spot):
			continue
		var value := going.dot(off.normalized()) - 0.05 * d
		if value > score:
			score = value
			best = spot + Vector3.UP * 0.05
	return best


func _cells_near(centre: Vector2i, steps: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-steps, steps + 1):
		for dy in range(-steps, steps + 1):
			var cell := centre + Vector2i(dx, dy)
			if maze.inside(cell):
				cells.append(cell)
	return cells


## Whether another of its kind is there or going there.
func _taken(spot: Vector3) -> bool:
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other == self or not (other is Alien):
			continue
		var alien := other as Alien
		if alien.global_position.distance_to(spot) < 3.0 or (alien.blink_target.is_finite() and alien.blink_target.distance_to(spot) < 3.0):
			return true
	return false


func _process(delta: float) -> void:
	var shown := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range and near.global_position.distance_to(blink_target if blink_target.is_finite() else global_position) > pose_range
		if far != _far:
			_far = far
			_body.visible = not far
			_body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var look := Vector3.INF
	if puppet:
		if _heard_extra.is_finite() and mode != Mode.WARNING:
			look = _heard_extra
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-8.0 * delta))
	else:
		if chasing and quarry:
			look = quarry.global_position + Vector3.UP * 1.3
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if quarry and chasing and (heading.length_squared() < 0.05 or mode == Mode.REACHING):
			heading = quarry.global_position - global_position
			heading.y = 0.0
		var rate := turn_rate * (0.5 if mode == Mode.REACHING and _body.reach_stage() != AlienBody.Reach.RAISE else 1.0)
		if mode != Mode.GONE and mode != Mode.ARRIVING and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-rate * delta))
	_body.look_at_point = look
	if _body.blink_stage() == AlienBody.Blink.NONE or _body.blink_stage() == AlienBody.Blink.OUT:
		_body.global_position = shown
		_body.rotation.y = facing_yaw


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## How many reaches (low four bits) and blinks (high four) it has made.
func net_flag() -> int:
	return (_reaches & 0xf) | ((_blinks & 0xf) << 4)


func net_point() -> Vector3:
	match mode:
		Mode.WARNING, Mode.GONE, Mode.ARRIVING:
			return blink_target
		Mode.REACHING:
			return _body.reach_aim if _body else Vector3.INF
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 1.3
	return Vector3.INF


func _heard_changed(_was: int, now: int, first: bool) -> void:
	mode = now as Mode
	chasing = mode != Mode.ABOUT
	if first or _body == null:
		return
	match mode:
		Mode.WARNING:
			if _heard_extra.is_finite():
				blink_target = _heard_extra
				_body.shimmer(_heard_extra, warning)
		Mode.GONE:
			_body.blink_out()
		Mode.ARRIVING:
			blink_target = _heard_at
			facing_yaw = _heard_yaw
			_body.blink_in(_heard_at, _heard_yaw)
		Mode.REACHING:
			if _heard_extra.is_finite():
				_body.reach(_heard_extra)
		_:
			_body.stop_shimmer()
			blink_target = Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	if mode == Mode.REACHING and _body and point.is_finite() and _body.reach_stage() == AlienBody.Reach.RAISE:
		_body.reach_aim = point


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if _body and _body.blink_stage() != AlienBody.Blink.GONE:
		_body.global_position = at
		_body.rotation.y = facing
		_body.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
