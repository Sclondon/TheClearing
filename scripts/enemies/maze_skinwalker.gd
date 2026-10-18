class_name MazeSkinwalker
extends MazeEnemy
## A skinwalker hidden among a pack of coyotes. It is drawn and moved by
## Skinwalker (creatures/skinwalker/skinwalker.gd); this is what it thinks.
##
## HIDING. It goes about with its pack (`pack_id`, MazeCoyote) on all fours as
## one of them, a little behind its leader. Look closely: it is bigger than
## they are, its joints bend the wrong ways, its eyes shine too much, it never
## joins their chorus, and when someone comes near and the coyotes run, it
## does not: it stands and stares.
## ITS CALL. While someone is near by the passages (`call_range`) but out of its
## sight, now and then it calls out (Skinwalker.call_out: a made-up voice, a
## "hey?", a "hel-lo" or a coyote's yip turned human, nobody's real voice), to
## draw them round the corner to it.
## THE RISE (the tell, and the wind-up). Look straight at it from close
## (`reveal_range`) for a moment, or come right up to it, and it stops being a
## coyote: it freezes, its head turns to you, and it rises (RISE_TIME, nearly
## two seconds) onto its long legs, its eyes shining; its pack scatters. Then
## it stands and stares a moment.
## THE HUNT. It runs you down on all fours in bursts: down flat and a jerk of
## the head (the wind-up, `windup` seconds), then a burst far faster than a
## sprint (`burst_speed`, for up to `burst_time`), then it stops dead, half
## up, twitching (`pause`). Bursts need a straight line to you: out of its
## sight it crawls after you by the passages at `crawl_speed`, slower than a run.
## Caught in a burst within reach, it grabs (`caught`).
## GETTING AWAY. Run, and turn corners: its bursts end at walls and it has to
## find you again. It will not go into the clearing, and it cannot climb: get up
## high (a terrace, the ivy, a ledge) and it stands under you, then gives up.
## Lost, it drops back onto all fours and goes back to its pack.
##
## As a puppet it follows the host's news; its calls, rises and grabs come as
## counts in its flag.

enum Mode { HIDING, NOTICED, RISING, STARING, HUNT, WINDUP, BURST, PAUSE, GRAB, UNDER, RETURN }

const SCALE := 1.25

@export var trot_speed := 1.9
@export var crawl_speed := 3.2
@export var burst_speed := 8.5
@export var burst_time := 1.1
@export var windup := 0.45
@export var pause := Vector2(0.9, 1.4)
@export var reveal_range := 9.0
## Looked at straight on for this long, near enough, and it rises.
@export var reveal_time := 0.6
## Come this near and it rises whatever.
@export var touch_range := 3.5
@export var call_range := 50.0
@export var call_every := Vector2(14.0, 26.0)
## How far up someone must be for it not to reach them (m above the floor).
@export var reach_up := 1.9
@export var acceleration := 30.0
@export var gravity := 24.0
@export var pose_range := 80.0
@export var size := SCALE
@export var pack_id := 0

var mode := Mode.HIDING
var facing_yaw := 0.0
var walker: Skinwalker

var _radius := 0.35
var _timer := 0.0
var _seen_for := 0.0
var _call_in := 12.0
var _point := Vector3.INF
var _burst_way := Vector3.ZERO
var _grabbed := false
var _calls := 0
var _rises := 0
var _grabs := 0
var _lost := 0.0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 46.0
	hear_range = 12.0
	memory = 9.0
	pack = &"skinwalkers"
	look_every = 0.2


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 0.9 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	walker = Skinwalker.new()
	walker.scale = Vector3.ONE * size
	add_child(walker)
	walker.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	walker.put(global_position, facing_yaw)
	_call_in = _rng.randf_range(call_every.x * 0.5, call_every.y)


## Its pack: the coyotes it hides among.
func coyotes() -> Array[MazeCoyote]:
	var found: Array[MazeCoyote] = []
	if is_inside_tree():
		for other: Node in get_tree().get_nodes_in_group(&"coyotes"):
			if other is MazeCoyote and (other as MazeCoyote).pack_id == pack_id:
				found.append(other)
	return found


## It will not go into the clearing after anyone.
func huntable(player: Node3D) -> bool:
	return super(player) and (maze == null or not keep_out_of_clearing or not maze.in_clearing(maze.cell_at(player.global_position)))


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	_timer -= delta
	var grounded := is_on_floor()
	var who := quarry if hunting() else null
	chasing = mode in [Mode.HUNT, Mode.WINDUP, Mode.BURST, Mode.PAUSE, Mode.GRAB]
	var wish := Vector3.ZERO
	var speed := 0.0
	_point = who.global_position + Vector3.UP * 1.0 if who else Vector3.INF
	match mode:
		Mode.HIDING, Mode.RETURN:
			_hide_step(who, delta)
			wish = _with_pack()
			speed = trot_speed if mode == Mode.HIDING else crawl_speed
			if mode == Mode.RETURN and wish.length() < 2.0:
				mode = Mode.HIDING
		Mode.NOTICED:
			if _timer <= 0.0:
				_rise()
		Mode.RISING:
			if _timer <= 0.0:
				mode = Mode.STARING
				_timer = 0.8
		Mode.STARING:
			if _timer <= 0.0:
				_hunt()
		Mode.HUNT:
			if who == null:
				_lose(delta)
			else:
				_lost = 0.0
				if _out_of_reach(who):
					mode = Mode.UNDER
					_timer = 6.0
				elif _clear_shot(who):
					mode = Mode.WINDUP
					_timer = windup
				else:
					wish = way(_radius)
					speed = crawl_speed
		Mode.WINDUP:
			if _timer <= 0.0:
				if who and _clear_shot(who):
					mode = Mode.BURST
					_timer = burst_time
					var to := who.global_position - global_position
					to.y = 0.0
					_burst_way = to.normalized()
				else:
					mode = Mode.HUNT
		Mode.BURST:
			# Straight at where they are, a little steering: it is going too fast to turn much.
			if who:
				var to := who.global_position - global_position
				to.y = 0.0
				_burst_way = _burst_way.slerp(to.normalized(), clampf(delta * 2.0, 0.0, 1.0)).normalized()
				if to.length() < 1.6 * size / SCALE and absf(who.global_position.y - global_position.y) < 1.5:
					mode = Mode.GRAB
					_timer = SkinwalkerRig.GRAB_TIME
					_grabbed = false
					_grabs += 1
					walker.grab()
					velocity.x *= 0.3
					velocity.z *= 0.3
			wish = _burst_way
			speed = burst_speed
			if _timer <= 0.0 or (_timer < burst_time - 0.25 and is_on_wall() and get_real_velocity().length() < burst_speed * 0.3):
				mode = Mode.PAUSE
				_timer = _rng.randf_range(pause.x, pause.y)
		Mode.GRAB:
			wish = _burst_way
			speed = 2.0
			if not _grabbed and _timer > SkinwalkerRig.GRAB_TIME * 0.3:
				for player: Node3D in players():
					if huntable(player) and (walker.grab_hits(player.global_position + Vector3.UP * 0.8, 0.45) or _within_arms(player)):
						_grabbed = true
						_catch(player)
						break
			if _timer <= 0.0:
				if _grabbed:
					_go_back()
				else:
					mode = Mode.PAUSE
					_timer = pause.x
		Mode.PAUSE:
			if _timer <= 0.0:
				mode = Mode.HUNT
		Mode.UNDER:
			# Up out of its reach: it stands under them, and gives up.
			if who == null or not _out_of_reach(who):
				mode = Mode.HUNT
			elif _timer <= 0.0:
				_go_back()
	if wish.length() > 0.01:
		wish = wish.normalized()
	# (a burst is snatched into: no build-up)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * (2.5 if mode == Mode.BURST else 1.0) * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Hiding among its pack: watches for someone looking at it, and calls to those out of sight.
func _hide_step(who: Node3D, delta: float) -> void:
	_call_in -= delta
	var looked_at := false
	for player: Node3D in players():
		if not huntable(player):
			continue
		var gap := player.global_position.distance_to(global_position)
		if gap < touch_range:
			_noticed(player)
			return
		if gap < reveal_range and _looking_at_me(player):
			looked_at = true
	_seen_for = _seen_for + delta if looked_at else maxf(_seen_for - delta * 0.5, 0.0)
	if _seen_for >= reveal_time:
		_noticed(nearest_player(global_position))
		return
	# A call to someone near by the passages but out of its sight.
	if _call_in <= 0.0:
		_call_in = _rng.randf_range(call_every.x, call_every.y)
		for player: Node3D in players():
			if not huntable(player):
				continue
			var steps := nav.distance(maze.cell_at(global_position), maze.cell_at(player.global_position))
			if steps >= 0 and steps * Maze.CELL < call_range and not nav.sees(global_position + Vector3.UP, player.global_position + Vector3.UP, sight_range):
				_call()
				break


func _call() -> void:
	_calls += 1
	walker.call_out(_calls % Skinwalker.CALLS)


func _noticed(player: Node3D) -> void:
	if player == null:
		return
	notice(player)
	mode = Mode.NOTICED
	_timer = 0.45
	_seen_for = 0.0


func _rise() -> void:
	mode = Mode.RISING
	_timer = SkinwalkerRig.RISE_TIME
	_rises += 1
	walker.rise()
	# Its pack scatters from it.
	for one in coyotes():
		if one.mode != MazeCoyote.Mode.DART:
			one._flee(global_position)


func _hunt() -> void:
	mode = Mode.HUNT
	walker.drop()


func _lose(delta: float) -> void:
	_lost += delta
	if _lost > 2.0:
		_go_back()


## Back to its pack, on all fours, as one of them.
func _go_back() -> void:
	mode = Mode.RETURN
	quarry = null
	_forget = 0.0
	_lost = 0.0
	walker.drop()


## Where to go to keep with its pack: a little behind and to one side of its leader.
func _with_pack() -> Vector3:
	var pack_now := coyotes()
	if pack_now.is_empty():
		return way(_radius) * 0.5 if mode == Mode.RETURN else Vector3.ZERO
	var lead := pack_now[0].leader()
	var spot := lead.global_position - Basis(Vector3.UP, lead.facing_yaw) * Vector3(-1.8, 0.0, 3.2)
	var to := spot - global_position
	to.y = 0.0
	if to.length() < 1.0:
		return Vector3.ZERO
	var step := nav.waypoint(global_position, spot, MazeNav.clearance_for(_radius)) - global_position
	step.y = 0.0
	return step.normalized() * to.length()


## Whether `player` is looking straight at it, with nothing in the way.
func _looking_at_me(player: Node3D) -> bool:
	var to := global_position - player.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return true
	var forward := MazeCoyote._forward_of(player)
	return forward.dot(to.normalized()) > 0.93 and nav.sees(player.global_position + Vector3.UP, global_position + Vector3.UP * 0.6, reveal_range + 1.0)


func _clear_shot(who: Node3D) -> bool:
	return nav.line_free(global_position, who.global_position, _radius) and global_position.distance_to(who.global_position) < sight_range


func _out_of_reach(who: Node3D) -> bool:
	return who.global_position.y - maze.ground_height(who.global_position) > reach_up


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			walker.visible = not far
			walker.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode in [Mode.NOTICED, Mode.RISING, Mode.STARING, Mode.UNDER, Mode.PAUSE, Mode.WINDUP] and _point.is_finite():
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-(3.0 if mode == Mode.RISING else 10.0) * delta))
	elif heading.length_squared() > 0.09:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-(4.0 if mode == Mode.BURST else 8.0) * delta))
	walker.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	walker.rotation = Vector3(0.0, facing_yaw, 0.0)
	walker.grounded = is_on_floor() or puppet
	walker.aim = _point if mode != Mode.HIDING or _seen_for > 0.0 else Vector3.INF
	walker.crouch = 1.0 if mode == Mode.WINDUP else 0.0
	walker.glare = 0.25 if mode in [Mode.HIDING, Mode.RETURN] else 1.0
	# (risen it stands while it stares, pauses half up, and stands under someone it cannot reach)
	if mode in [Mode.STARING, Mode.UNDER] and not walker.is_upright():
		walker.rise()
	elif mode not in [Mode.NOTICED, Mode.RISING, Mode.STARING, Mode.UNDER] and walker.is_upright() and not walker.rising():
		walker.drop()


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Calls (low four bits), rises (two) and grabs (two), as counts.
func net_flag() -> int:
	return (_calls & 0x0f) | ((_rises & 0x03) << 4) | ((_grabs & 0x03) << 6)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode in [Mode.HUNT, Mode.WINDUP, Mode.BURST, Mode.PAUSE, Mode.GRAB]
	_point = point
	var calls := flag & 0x0f
	var rises := (flag >> 4) & 0x03
	var grabs := (flag >> 6) & 0x03
	if not _heard_flagged:
		_heard_flagged = true
	elif walker:
		if calls != (_calls & 0x0f):
			walker.call_out(calls % Skinwalker.CALLS)
		if rises != (_rises & 0x03):
			walker.rise()
		if grabs != (_grabs & 0x03):
			walker.grab()
	_calls = calls
	_rises = rises
	_grabs = grabs


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if walker:
		walker.put(at, facing)


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4


## Whether `player` is within its arms' reach as it grabs: close, and ahead of the way it was going.
func _within_arms(player: Node3D) -> bool:
	var to := player.global_position - global_position
	var up := to.y
	to.y = 0.0
	return to.length() < 1.7 * size / SCALE and absf(up) < 1.5 and (to.length() < 0.6 or to.normalized().dot(_burst_way) > 0.2)
