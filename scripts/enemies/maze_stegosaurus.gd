class_name MazeStegosaurus
extends MazeEnemy
## A stegosaurus grazing in the maze: peaceful, until someone comes too near.
## It is drawn and moved by Stegosaurus (creatures/stegosaurus/stegosaurus.gd);
## this is what it thinks.
##
## GRAZING. It keeps to within `territory_range` of where it was put, cropping
## the ferns and moss of a wide hall, walking slowly from one patch to the
## next and turning as it goes, so that it often stands across the hall. It
## does not hunt anyone, and does not chase.
## NOTICING. It sees and hears poorly. Someone creeping (ducking, crawling, or
## walking no faster than a walk) it notices only very near (`notice_range.x`,
## measured from its body); someone running from much further off, and
## sprinting further still. Noticed, out of its way, it lifts its head to watch
## them (WATCH), and lets them go.
## THE WARNING. Anyone it has noticed who comes within `space_range` of its
## body (or of its calf) is too near: it turns side on to them, its tail
## towards them, and rumbles, its weight back, its tail raised and cocked away
## from them, the spikes waving (`warn_time`: a long, clear wind-up). Get back
## out of its space, or past its head, and it lets them be.
## THE SWING. At the end of the warning, whoever is still behind its flank and
## within the reach of its tail (`strike_range` of its hips) has the tail swung
## at them: the thagomizer comes round low across behind it in a wide arc, and
## whoever the spikes pass through is thrown through the air (limp) and
## `caught`. It stands a moment (RECOVER), and then, if they are still too
## near, warns again (shorter) and swings again.
## So creep past, far from its body, by its head rather than its tail; or go
## round. Anyone up off the ground out of its reach (`reach_up`) it ignores.
##
## A calf (`calf`, put in with `family`) keeps near its `mother`, grazing, and
## hurries round behind her when anyone comes near; anyone near the calf is too
## near her. A calf catches nobody.
##
## As a puppet it follows the host's news like the others; its swings (with
## the side) and rumbles come as counts in its flag and are played here too.

enum Mode { GRAZE, WATCH, WARN, SWING, RECOVER, RETURN }

## How much smaller a calf is drawn than its mother.
const CALF_SIZE := 0.38
## Where it stands, from its middle (where it is moved) to the front of its shoulders and back to its hips, m.
const BODY := Vector2(2.0, -0.4)
## The bearing it turns someone it is warning to (from its nose, rad): behind its flank.
const SIDE_ON := 1.95

@export var walk_speed := 0.6
@export var return_speed := 1.2
## How fast it turns (rad/s): grazing, and warning (turning side on).
@export var turn_rate := 0.45
@export var warn_turn := 0.85
@export var acceleration := 1.5
## How near (m, from its body) someone must come for it to notice them:
## creeping (ducking, crawling, or no faster than a walk), running, sprinting.
@export var notice_range := Vector3(4.5, 13.0, 20.0)
## How fast is creeping, at most (m/s).
@export var creep_speed := 2.0
## Too near: within this of its body (or `calf_range` of its calf), someone it has noticed is warned.
@export var space_range := 7.0
@export var calf_range := 6.0
## Seconds it warns before it swings, the first time and again.
@export var warn_time := 2.6
@export var rewarn_time := 1.5
## It swings at someone this near its hips (the reach of its tail), behind its flank.
@export var strike_range := 4.9
## It warns on at most this long at someone who stays near but out of reach, then gives up.
@export var warn_hold := 7.0
@export var recover_time := 1.5
## How near the end of its tail or a spike must pass someone to catch them (m).
@export var hit_radius := 0.55
## How far from where it was put it grazes.
@export var territory_range := 9.0
## Higher than this above its feet, it cannot reach them (and pays them no heed).
@export var reach_up := 3.0
## Seconds after it last noticed anyone that it goes back to grazing.
@export var calm_time := 3.5
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 95.0
@export var gravity := 24.0
## A calf: small, harmless, keeping near `mother`. Set before it enters the tree.
@export var calf := false

var mode := Mode.GRAZE
var facing_yaw := 0.0
var steg: Stegosaurus
## A calf's mother (set before it enters the tree), and a mother's calves.
var mother: MazeStegosaurus
var calves: Array[MazeStegosaurus] = []
## Which side of it the one it is warning is (1: its left).
var side := 1.0

var _size := 1.0
var _home := Vector3.ZERO
var _mode_left := 0.0
var _warned_for := 0.0
var _calm_left := 0.0
var _graze_goal := Vector3.INF
var _graze_left := 0.0
var _rumble_in := 0.0
var _point := Vector3.INF
var _thrown: Array = []
var _hit := {}
var _swings := 0
var _rumbles := 0
var _colliders: Array[CollisionShape3D] = []
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	# (its senses are its own: see `_watch`)
	sight_range = 0.0
	hear_range = 0.0
	memory = 2.0
	alert_range = 0.0
	pack = &"stegosaurs"
	look_every = 0.2
	spare_time = 4.0


## A mother and `count` calves (the calves keep by her): put them in together, mother first.
static func family(count: int) -> Array:
	var made: Array = [MazeStegosaurus.new()]
	for i in count:
		var young := MazeStegosaurus.new()
		young.calf = true
		young.mother = made[0]
		(made[0] as MazeStegosaurus).calves.append(young)
		made.append(young)
	return made


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.5
	_size = CALF_SIZE if calf else 1.0
	# (two upright capsules, one over its hips and one over its shoulders, turned with it)
	for at: float in [BODY.y + 0.3, BODY.x - 0.3]:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.85 * _size
		shape.height = 2.4 * _size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
		_colliders.append(collider)
	steg = Stegosaurus.new()
	steg.low_poly = Settings.low_poly
	steg.scale = Vector3.ONE * _size
	if calf:
		steg.scales = 11.0 / CALF_SIZE * 0.7
		steg.volume_db = -4.0
	add_child(steg)
	steg.top_level = true
	facing_yaw = rotation.y
	rotation = Vector3.ZERO
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	_turn_colliders()
	steg.global_position = global_position
	steg.rotation = Vector3(0.0, facing_yaw, 0.0)
	steg.settle()
	_graze_left = _rng.randf_range(1.0, 5.0)
	_rumble_in = 0.0


# --- Its senses ---

## Where its body is: the line from the front of its shoulders to its hips, in the world (flat).
func _body_line() -> Array[Vector3]:
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	return [global_position + forward * BODY.x * _size, global_position + forward * BODY.y * _size]


## How far `at` is from its body, flat (m).
func body_gap(at: Vector3) -> float:
	var line := _body_line()
	var a := Vector2(line[0].x, line[0].z)
	var b := Vector2(line[1].x, line[1].z)
	var p := Vector2(at.x, at.z)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## How near someone moving as `player` is must come to be noticed.
func _notice_reach(player: Node3D) -> float:
	var moving := Vector3.ZERO
	if player is CharacterBody3D:
		moving = (player as CharacterBody3D).velocity
	var speed := Vector2(moving.x, moving.z).length()
	if player.get(&"is_sprinting") == true:
		return notice_range.z
	if player.get(&"is_ducking") == true or player.get(&"is_crawling") == true or speed <= creep_speed:
		return notice_range.x
	return lerpf(notice_range.y, notice_range.z, smoothstep(4.4, 5.6, speed))


## Notices whoever comes near enough, as they move (see the class's notes).
func _watch() -> void:
	if _look_in < look_every - 0.001:
		return
	var eye := global_position + Vector3.UP * 1.4 * _size
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		if at.y - global_position.y > reach_up:
			continue
		var gap := body_gap(at)
		var reach := _notice_reach(player)
		var near_calf := false
		for young in calves:
			if is_instance_valid(young) and young.global_position.distance_to(at) < notice_range.x:
				near_calf = true
		if (gap < reach or near_calf) and (gap < 3.0 or nav.sees(eye, at + Vector3.UP, reach + 4.0)):
			notice(player)


## Whether `who` is too near: within its space (`margin` times it), or near its calf.
func _too_near(who: Node3D, margin := 1.0) -> bool:
	var at := who.global_position
	if at.y - global_position.y > reach_up:
		return false
	if body_gap(at) < space_range * _size * margin:
		return true
	for young in calves:
		if is_instance_valid(young) and young.global_position.distance_to(at) < calf_range * margin:
			return true
	return false


## Which side of it `at` is (1: its left), and how far round from its nose (rad, 0..PI).
func _bearing(at: Vector3) -> Vector2:
	var to := at - hips_at()
	var off := angle_difference(facing_yaw, atan2(to.x, to.z))
	return Vector2(1.0 if off >= 0.0 else -1.0, absf(off))


## Where its hips are (what its tail swings round), in the world.
func hips_at() -> Vector3:
	return global_position + Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * BODY.y * _size


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_turn_colliders()
		return
	if maze == null:
		return
	_sense(delta)
	_watch()
	var grounded := is_on_floor()
	var who := quarry if hunting() and quarry.get(&"is_limp") != true else null
	if who:
		_calm_left = calm_time
	else:
		_calm_left -= delta
	_mode_left -= delta
	var wish := Vector3.ZERO
	var speed := 0.0
	var turn := turn_rate
	var want_yaw := INF
	if calf:
		_calf(delta, who)
		return
	match mode:
		Mode.GRAZE, Mode.RETURN:
			_point = Vector3.INF
			if who and _too_near(who):
				_start_warning(who, warn_time)
			elif who:
				mode = Mode.WATCH
				steg.huff()
			elif mode == Mode.RETURN:
				var to := _home - global_position
				if Vector2(to.x, to.z).length() < 2.5:
					mode = Mode.GRAZE
				else:
					wish = nav.waypoint(global_position, _home, MazeNav.clearance_for(1.2)) - global_position
					speed = return_speed
			else:
				_graze_left -= delta
				if _graze_left <= 0.0:
					_graze_left = _rng.randf_range(6.0, 14.0)
					var round_about := _rng.randf_range(0.0, TAU)
					var goal := _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, territory_range * 0.6)
					_graze_goal = goal if nav.line_free(global_position, goal, 1.5) and _rng.randf() < 0.6 else Vector3.INF
				if _graze_goal.is_finite() and Vector2(_graze_goal.x - global_position.x, _graze_goal.z - global_position.z).length() > 1.0:
					wish = _graze_goal - global_position
					speed = walk_speed
				if Vector2(global_position.x - _home.x, global_position.z - _home.z).length() > territory_range:
					mode = Mode.RETURN
		Mode.WATCH:
			if who == null:
				if _calm_left <= 0.0:
					mode = Mode.GRAZE
			else:
				_point = who.global_position + Vector3.UP * 1.0
				if _too_near(who):
					_start_warning(who, warn_time)
		Mode.WARN:
			_warned_for += delta
			if who == null or not _too_near(who, 1.15):
				# (they have backed off out of its space, or gone)
				mode = Mode.WATCH if who else Mode.GRAZE
				_point = Vector3.INF
			else:
				_point = who.global_position + Vector3.UP * 1.0
				var bearing := _bearing(who.global_position)
				# (they cross behind it, or round its head: it turns the other way)
				if bearing.x != side and (bearing.y > 2.6 or bearing.y < 0.6):
					side = bearing.x
				var to := who.global_position - hips_at()
				want_yaw = atan2(to.x, to.z) - side * SIDE_ON
				turn = warn_turn
				_rumble_in -= delta
				if _rumble_in <= 0.0:
					_rumble_in = _rng.randf_range(2.6, 3.6)
					_rumbles += 1
					steg.rumble()
				if _mode_left <= 0.0:
					var reach := Vector2(to.x, to.z).length()
					if reach < strike_range and bearing.x == side and bearing.y > 1.0:
						_start_swing()
					elif _warned_for > warn_hold:
						# (they keep near but out of its reach: it gives up on them)
						mode = Mode.WATCH
						_point = Vector3.INF
		Mode.SWING:
			_strike()
			if not steg.swinging():
				mode = Mode.RECOVER
				_mode_left = recover_time
		Mode.RECOVER:
			_point = who.global_position + Vector3.UP * 1.0 if who else Vector3.INF
			if _mode_left <= 0.0:
				if who and _too_near(who):
					_start_warning(who, rewarn_time)
				else:
					mode = Mode.WATCH if who else Mode.GRAZE
	chasing = mode in [Mode.WARN, Mode.SWING]
	_move(wish, speed, turn, want_yaw, delta, grounded)


## A calf: grazing by its mother; anyone near, it hurries round behind her.
func _calf(delta: float, who: Node3D) -> void:
	var wish := Vector3.ZERO
	var speed := 0.0
	_point = Vector3.INF
	if not is_instance_valid(mother):
		mother = null
	var at_home := mother.global_position if mother else _home
	var mother_yaw := mother.facing_yaw if mother else facing_yaw
	var forward := Vector3(sin(mother_yaw), 0.0, cos(mother_yaw))
	var left := Vector3(cos(mother_yaw), 0.0, -sin(mother_yaw))
	var spot: Vector3
	if who or (mother and mother.mode in [Mode.WARN, Mode.SWING, Mode.RECOVER]):
		# Behind her, on her far side from whoever it is, by her shoulder (out of her tail's way).
		mode = Mode.WATCH
		var threat := who.global_position if who else mother._point
		var away := 1.0
		if threat.is_finite():
			away = -signf((threat - at_home).dot(left))
		spot = at_home + left * away * 2.6 + forward * 1.4
		_point = threat if threat.is_finite() else Vector3.INF
		speed = 1.8
	else:
		mode = Mode.GRAZE
		_graze_left -= delta
		if _graze_left <= 0.0 or not _graze_goal.is_finite():
			_graze_left = _rng.randf_range(5.0, 10.0)
			var round_about := _rng.randf_range(0.0, TAU)
			_graze_goal = Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(2.6, 4.0)
		spot = at_home + _graze_goal
		speed = 0.9
	var to := spot - global_position
	to.y = 0.0
	if to.length() > 0.6:
		wish = to
	else:
		speed = 0.0
	chasing = false
	_move(wish, speed, turn_rate * 2.5, INF, delta, is_on_floor())


## Goes the way it faces (turning no faster than it can) towards `wish`, or
## turns on the spot to `want_yaw`, or towards what it watches.
func _move(wish: Vector3, speed: float, turn: float, want_yaw: float, delta: float, grounded: bool) -> void:
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if want_yaw != INF:
		facing_yaw += clampf(angle_difference(facing_yaw, want_yaw), -turn * delta, turn * delta)
	elif wish != Vector3.ZERO:
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(wish.x, wish.z)), -turn * delta, turn * delta)
	elif _point.is_finite() and mode == Mode.WATCH and calf:
		var to := _point - global_position
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(to.x, to.z)), -turn * 0.5 * delta, turn * 0.5 * delta)
	forward = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var target := forward * speed * clampf(forward.dot(wish) if wish != Vector3.ZERO else 0.0, 0.0, 1.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta * (2.0 if calf else 1.0))
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	_turn_colliders()
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _turn_colliders() -> void:
	var turned := Basis(Vector3.UP, facing_yaw)
	for k in _colliders.size():
		var along := (BODY.y + 0.3) if k == 0 else (BODY.x - 0.3)
		_colliders[k].position = turned * Vector3(0.0, 1.2, along) * _size


func _start_warning(who: Node3D, seconds: float) -> void:
	mode = Mode.WARN
	_mode_left = seconds
	_warned_for = 0.0
	side = _bearing(who.global_position).x
	_point = who.global_position + Vector3.UP * 1.0
	_rumble_in = 0.0


func _start_swing() -> void:
	mode = Mode.SWING
	_swings += 1
	_hit.clear()
	steg.swing(side)


## Whoever the end of its tail or its spikes pass through, as they come round, is thrown and caught.
func _strike() -> void:
	if not steg.sweeping():
		return
	var pivot := hips_at()
	for player: Node3D in players():
		if not huntable(player) or _hit.has(player) or player in _thrown:
			continue
		var at := player.global_position
		var near := INF
		for up: float in [0.35, 0.85, 1.3]:
			near = minf(near, steg.tail_gap(at + Vector3.UP * up))
		if near < hit_radius:
			_hit[player] = true
			_throw(player, pivot)


func _throw(player: Node3D, pivot: Vector3) -> void:
	_thrown.append(player)
	if player is Player and is_instance_valid(player):
		# Thrown limp through the air the way the tail was going; caught as he lands.
		var out := player.global_position - pivot
		out.y = 0.0
		var going := Vector3.UP.cross(out).normalized() * -side
		(player as Player).ragdoll((going * 0.85 + out.normalized() * 0.35 + Vector3.UP * 0.7).normalized() * 75.0)
		get_tree().create_timer(1.4).timeout.connect(_land.bind(player))
	else:
		_thrown.erase(player)
		_catch(player)


## A thrown player has come down: stood up, and caught.
func _land(player: Node3D) -> void:
	_thrown.erase(player)
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			steg.visible = not far
			steg.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				steg.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-8.0 * delta))
	steg.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	steg.rotation = Vector3(0.0, facing_yaw, 0.0)
	var moving := Vector2(velocity.x, velocity.z).length()
	steg.grazing = mode == Mode.GRAZE and moving < (0.65 if not calf else 0.4)
	steg.warning = mode == Mode.WARN
	steg.threat_side = side
	steg.look_at_point = _point if mode in [Mode.WATCH, Mode.WARN, Mode.RECOVER] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Swings (low three bits), rumbles (two), the side it warns (a bit: its left).
func net_flag() -> int:
	return (_swings & 7) | ((_rumbles & 3) << 3) | ((1 if side > 0.0 else 0) << 5)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.WARN, Mode.SWING]
	_point = point
	side = 1.0 if (flag >> 5) & 1 else -1.0
	var swings := flag & 7
	var rumbles := (flag >> 3) & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif steg:
		if swings != (_swings & 7):
			steg.swing(side)
		if rumbles != (_rumbles & 3):
			steg.rumble()
	_swings = swings
	_rumbles = rumbles


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if steg:
		steg.global_position = at
		steg.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
