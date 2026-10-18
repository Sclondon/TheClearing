class_name MazeElk
extends MazeEnemy
## A bull elk holding a stretch of the maze as his own. He is drawn and moved
## by Elk (creatures/elk/elk.gd); this is what he thinks.
##
## HIS GROUND. He keeps to within `territory_range` of where he was put,
## grazing, walking heavily about it. Nobody outside it interests him.
## THE WARNING. A player on his ground and in his sight: he turns to face
## them, raises his head and BUGLES (the first time: a long rising scream,
## steam pouring from his mouth), then PAWS the ground with a forefoot and
## lowers his antlers (`windup_time`). That is the warning, and it is long.
## THE CHARGE. He comes at where they are, head down, accelerating to a gallop
## faster than anyone can run (`charge_speed`). For the first moment he can
## still swing towards them; after that his line is set and he can hardly turn
## (`charge_turn`). Anyone his antlers or his chest reach is `caught`. He runs
## on past where they were until he has to stop, skids to a halt and stands
## blowing (RECOVER), then turns, slowly, and does it all again, without the
## bugle.
## ESCAPING HIM: step aside out of his line once his line is set (a side
## passage, a slot, behind a buttress), get up off the ground (he will not
## charge anyone he cannot reach: he paws and bugles below them), or get off
## his ground. A sprint does not outrun him.
##
## As a puppet he follows the host's news like the others; bugles and charges
## come as counts in his flag.

enum Mode { GRAZE, WARN, PAW, CHARGE, RECOVER, RETURN, GLARE }

@export var walk_speed := 1.2
@export var return_speed := 1.8
@export var charge_speed := 10.0
@export var charge_acceleration := 7.0
@export var acceleration := 5.0
## How fast he can turn (rad/s): about, in the first moment of a charge, and once his line is set.
@export var turn_rate := 1.6
@export var aim_turn := 1.2
@export var charge_turn := 0.12
## Seconds of the charge in which he can still swing at them.
@export var aim_time := 0.45
## How far his ground runs from where he was put, and the furthest he charges from.
@export var territory_range := 32.0
@export var charge_range := 28.0
## Seconds he paws before he comes (after the bugle, the first time), and stands after.
@export var windup_time := 1.7
@export var recover_time := 2.2
## How far past where they were he runs on, at most (m).
@export var overrun := 10.0
## How near his antlers or his chest must come (m, at a scale of 1).
@export var gore_radius := 1.0
## Further than this from every player he is not posed.
@export var pose_range := 85.0
@export var gravity := 24.0
@export var size := 1.0

var mode := Mode.GRAZE
var facing_yaw := 0.0
var elk: Elk

var _radius := 0.7
var _home := Vector3.ZERO
var _mode_left := 0.0
var _bugled := false
var _charge_way := Vector3.FORWARD
var _charge_from := Vector3.ZERO
var _charge_length := 0.0
var _charge_time := 0.0
var _point := Vector3.INF
var _graze_goal := Vector3.INF
var _graze_left := 0.0
var _glare_bugle := 0.0
var _gored := {}
var _bugles := 0
var _charges := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 40.0
	hear_range = 10.0
	memory = 5.0
	alert_range = 0.0
	pack = &"elk"
	look_every = 0.2
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.62 * size
	shape.radius = _radius
	shape.height = 2.2 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	elk = Elk.new()
	elk.low_poly = Settings.low_poly
	elk.fur_shells = 0 if Settings.low_poly else 1
	elk.scale = Vector3.ONE * size
	add_child(elk)
	elk.top_level = true
	facing_yaw = rotation.y
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	elk.global_position = global_position
	elk.rotation = Vector3(0.0, facing_yaw, 0.0)
	elk.settle()


## Whether `who` is on his ground, on the ground, where he could reach them.
func _on_his_ground(who: Node3D) -> bool:
	var at := who.global_position
	var from_home := Vector2(at.x - _home.x, at.z - _home.z).length()
	return from_home < territory_range + 4.0 and at.y - global_position.y < 1.5


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	var grounded := is_on_floor()
	var who := quarry if hunting() else null
	_mode_left -= delta
	var wish := Vector3.ZERO
	var speed := 0.0
	var turn := turn_rate
	match mode:
		Mode.GRAZE, Mode.RETURN:
			_point = Vector3.INF
			if who and _on_his_ground(who):
				_start_warning(who)
			elif who and mode == Mode.GRAZE:
				mode = Mode.GLARE
			elif mode == Mode.RETURN:
				var to := _home - global_position
				if Vector2(to.x, to.z).length() < 3.0:
					mode = Mode.GRAZE
				else:
					wish = nav.waypoint(global_position, _home, MazeNav.clearance_for(_radius)) - global_position
					speed = return_speed
			else:
				_graze_left -= delta
				if _graze_left <= 0.0:
					_graze_left = _rng.randf_range(5.0, 11.0)
					var round_about := _rng.randf_range(0.0, TAU)
					var goal := _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, 6.0)
					_graze_goal = goal if nav.line_free(global_position, goal, _radius) and _rng.randf() < 0.5 else Vector3.INF
				if _graze_goal.is_finite() and Vector2(_graze_goal.x - global_position.x, _graze_goal.z - global_position.z).length() > 0.8:
					wish = _graze_goal - global_position
					speed = walk_speed
		Mode.GLARE:
			# Someone he can see but not reach (up off the ground, or off his ground): he faces them, paws, bugles.
			if who == null:
				mode = Mode.RETURN
			else:
				_point = who.global_position + Vector3.UP * 1.0
				if _on_his_ground(who) and _reachable(who):
					_start_warning(who)
				else:
					_glare_bugle -= delta
					if _glare_bugle <= 0.0:
						_glare_bugle = _rng.randf_range(7.0, 12.0)
						_bugle()
		Mode.WARN:
			if who:
				_point = who.global_position + Vector3.UP * 1.0
			if _mode_left <= 0.0:
				mode = Mode.PAW
				_mode_left = windup_time
		Mode.PAW:
			if who:
				_point = who.global_position + Vector3.UP * 1.0
			if who == null or not _on_his_ground(who):
				mode = Mode.RETURN if who == null else Mode.GLARE
			elif not _reachable(who):
				mode = Mode.GLARE
			elif _mode_left <= 0.0:
				_start_charge(who)
		Mode.CHARGE:
			_charge_time += delta
			if who and _charge_time < aim_time:
				# (in the first moment he can still swing at them)
				var to := who.global_position - global_position
				to.y = 0.0
				if to.length() > 1.0:
					_charge_way = _charge_way.slerp(to.normalized(), clampf(aim_turn * delta, 0.0, 1.0)).normalized()
			wish = _charge_way
			speed = charge_speed
			turn = charge_turn
			_gore()
			var gone := Vector2(global_position.x - _charge_from.x, global_position.z - _charge_from.z).length()
			var moving := Vector2(velocity.x, velocity.z).length()
			if gone > _charge_length or (_charge_time > 0.8 and moving < 2.5) or is_on_wall() and _charge_time > 0.4:
				mode = Mode.RECOVER
				_mode_left = recover_time
		Mode.RECOVER:
			_point = who.global_position + Vector3.UP * 1.0 if who else Vector3.INF
			if _mode_left <= 0.0:
				if who and _on_his_ground(who) and _reachable(who):
					mode = Mode.PAW
					_mode_left = windup_time * 0.85
				elif who:
					mode = Mode.GLARE
				else:
					mode = Mode.RETURN
	chasing = mode in [Mode.WARN, Mode.PAW, Mode.CHARGE]
	var rate := charge_acceleration if mode == Mode.CHARGE else acceleration * (3.0 if mode == Mode.RECOVER else 1.0)
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
	# (he goes the way he faces, and turns no faster than he can)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if wish != Vector3.ZERO:
		var want := atan2(wish.x, wish.z)
		facing_yaw = facing_yaw + clampf(angle_difference(facing_yaw, want), -turn * delta, turn * delta)
		forward = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw = facing_yaw + clampf(angle_difference(facing_yaw, atan2(to.x, to.z)), -turn_rate * 0.6 * delta, turn_rate * 0.6 * delta)
	var target := forward * speed * clampf(forward.dot(wish) if wish != Vector3.ZERO else 0.0, 0.0, 1.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whether he could charge `who`: on the ground, in a straight line, near enough.
func _reachable(who: Node3D) -> bool:
	var to := who.global_position - global_position
	return absf(to.y) < 1.5 and Vector2(to.x, to.z).length() < charge_range and nav.line_free(global_position + Vector3.UP * 0.5, who.global_position + Vector3.UP * 0.5, _radius * 0.5)


func _start_warning(who: Node3D) -> void:
	_point = who.global_position + Vector3.UP * 1.0
	if not _bugled:
		_bugled = true
		mode = Mode.WARN
		_mode_left = Elk.BUGLE_TIME + 0.2
		_bugle()
	else:
		mode = Mode.PAW
		_mode_left = windup_time


func _bugle() -> void:
	_bugles += 1
	elk.bugle()


func _start_charge(who: Node3D) -> void:
	mode = Mode.CHARGE
	_charges += 1
	_charge_time = 0.0
	_charge_from = global_position
	var to := who.global_position - global_position
	to.y = 0.0
	_charge_way = to.normalized() if to.length() > 0.1 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	_charge_length = to.length() + overrun
	_gored.clear()


## Catches anyone his antlers or his chest come to while he is charging.
func _gore() -> void:
	if Vector2(velocity.x, velocity.z).length() < 3.0:
		return
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var front := global_position + forward * 1.1 * size
	for player: Node3D in players():
		if not huntable(player) or _gored.has(player):
			continue
		var at := player.global_position
		if absf(at.y - global_position.y) > 1.8 * size:
			continue
		var near := minf(Vector2(at.x - front.x, at.z - front.z).length(), Vector2(at.x - global_position.x, at.z - global_position.z).length())
		if near < gore_radius * size:
			_gored[player] = true
			_catch(player)


# --- What he looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			elk.visible = not far
			elk.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				elk.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elk.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	elk.rotation = Vector3(0.0, facing_yaw, 0.0)
	elk.grounded = is_on_floor() or puppet
	elk.grazing = mode == Mode.GRAZE and Vector2(velocity.x, velocity.z).length() < 0.3
	elk.alert = mode in [Mode.GLARE, Mode.RECOVER]
	elk.pawing = mode == Mode.PAW or (mode == Mode.GLARE and fposmod(Time.get_ticks_msec() * 0.001, 6.0) < 1.6)
	elk.lowered = mode == Mode.CHARGE or (mode == Mode.PAW and _mode_left < windup_time * 0.55)
	elk.look_at_point = _point if mode != Mode.CHARGE else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Bugles (low four bits), charges (high four).
func net_flag() -> int:
	return (_bugles & 0x0f) | ((_charges & 0x0f) << 4)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.PAW, Mode.CHARGE]
	_point = point
	var bugles := flag & 0x0f
	if not _heard_flagged:
		_heard_flagged = true
		# (heard first in the middle of his warning: he is bugling)
		if elk and mode == Mode.WARN:
			elk.bugle()
	elif elk and bugles != (_bugles & 0x0f):
		elk.bugle()
	_bugles = bugles
	_charges = (flag >> 4) & 0x0f
	_mode_left = windup_time if mode == Mode.PAW else 0.0


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if elk:
		elk.global_position = at
		elk.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
