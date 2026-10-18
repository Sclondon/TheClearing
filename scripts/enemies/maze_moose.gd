class_name MazeMoose
extends MazeEnemy
## A moose in the maze: a bull, or a cow with her calf (MazeMooseCalf), each
## at a wallow of its own (a black pool in a hall, `FishPool`) where it wades
## and browses the ivy and the undergrowth along the walls. It is drawn and
## moved by Moose (creatures/moose/moose.gd); this is what it thinks.
##
## NOT TERRITORIAL BUT UNPREDICTABLE. It wanders slowly about its wallow,
## browsing, head up in the leaves, or feeding in the water. Most of the time
## anyone it sees it only watches (WATCH: head up, ears on them), and lets go.
## What sets it off:
## - a cow: anyone near her calf (`calf_range` of it), or the calf being hunted;
## - a bull in the rut (some of the time: `rut` is the share of it, and he
##   grunts now and then while he is): anyone he sees within `rut_range`;
## - any of them: anyone coming right up to it (`space_range`).
## THE WARNING (WARN, `warn_time`, a little different each time): it turns to
## face them, its ears go flat back, the hackles stand up along its hump and
## neck, it lowers its head and stares out from under its brows, licking its
## lips; it stamps; a bull grunts. Back off out of reach (or out of the calf's
## way) and it settles again.
## THE CHARGE: it comes at them in its long fast trot, faster than anyone can
## run, head down, and it can turn (a step aside does not shake it off). It
## KNOCKS DOWN whoever it reaches, swings round, comes back over them and
## rears to STRIKE with its forehooves: whoever is still within `stamp_reach`
## when they come down is `caught`. Get up and get away at once and it misses.
## ESCAPING IT: get behind something (out of its line for a moment: a pier, a
## buttress, round a corner) or up off the ground (`reach_up`), and it pulls up
## and stands blowing; or outlast its charge (it never goes far from its
## wallow: `chase_range`).
## OTHERS: a hunter bigger than it after it, it trots off (`threat`); a cow
## charges a hunter after her calf instead, and knocks it back (Stagger).
##
## As a puppet it follows the host's news like the others; its calls, strikes
## and knock-downs come as counts in its flag (a knock-down knocks the guest's
## own boy down where it happened, on the guest's machine).

enum Mode { BROWSE, WATCH, WARN, CHARGE, KNOCK, STRIKE, BLOW, RETURN, FLEE, FOLLOW }

## Seconds a knocked-down boy lies before he gets up.
const KNOCK_TIME := 1.0
## How long out of its line someone must be for it to give up a charge, seconds.
const LOST_LINE := 0.45

@export var walk_speed := 1.1
@export var trot_speed := 4.0
@export var charge_speed := 6.8
@export var charge_acceleration := 8.0
@export var acceleration := 4.0
## How fast it turns (rad/s): about, and charging (it can follow a dodge).
@export var turn_rate := 1.4
@export var charge_turn := 1.9
## It browses within this of its wallow, and never charges further than `chase_range` from it.
@export var home_range := 11.0
@export var chase_range := 34.0
## What sets it off: a bull in rut, anyone within this; a cow, anyone this near her calf; anyone this near it.
@export var rut_range := 24.0
@export var calf_range := 11.0
@export var space_range := 5.5
## Seconds it warns (picked between these each time).
@export var warn_time := Vector2(1.6, 2.6)
## Seconds at most of a charge; standing blowing after.
@export var charge_time := 4.5
@export var blow_time := 2.4
## How near its chest must come to knock someone down, and its hooves to catch them, m.
@export var knock_radius := 1.15
@export var stamp_reach := 1.7
## Higher than this above its feet it cannot reach them.
@export var reach_up := 1.4
@export var pool_radius := 3.2
## Further than this from every player it is not posed.
@export var pose_range := 85.0
@export var gravity := 24.0
## A cow (her calf is `calf`). Set before it enters the tree.
@export var cow := false
## A bull: the share of the time he is in the rut (0 never, 1 always).
@export_range(0.0, 1.0) var rut := 0.4

var mode := Mode.BROWSE
var facing_yaw := 0.0
var moose: Moose
var pool: FishPool
## A cow's calf; a calf's mother.
var calf: MazeMoose
var mother: MazeMoose
## Whether a bull is in the rut now.
var in_rut := false

var _radius := 0.7
var _home := Vector3.ZERO
var _mode_left := 0.0
var _mode_time := 0.0
var _point := Vector3.INF
var _target: Node3D
var _goal := Vector3.INF
var _goal_left := 0.0
var _charge_from := Vector3.ZERO
var _lost_line := 0.0
var _down_at := Vector3.INF
var _victim: Node3D
var _stamped_mid := false
var _rut_left := 0.0
var _call_in := 6.0
var _predator_in := 0.0
var _predator: MazeEnemy
var _calls := 0
var _strikes := 0
var _knocks := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
var _wade := 0.0


## A cow and her calf, together (`calf`, `mother`), from `seed_value`.
static func family(seed_value: int) -> Array[MazeMoose]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var her := MazeMoose.new()
	her.cow = true
	var young := MazeMooseCalf.new()
	her.calf = young
	young.mother = her
	return [her, young]


func _init() -> void:
	sight_range = 34.0
	hear_range = 8.0
	memory = 4.0
	alert_range = 0.0
	pack = &"moose"
	look_every = 0.2
	spare_time = 4.0


func is_calf() -> bool:
	return false


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var small := 0.55 if is_calf() else (0.93 if cow else 1.0)
	var shape := CapsuleShape3D.new()
	_radius = 0.7 * small
	shape.radius = _radius
	shape.height = 2.5 * small
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	moose = Moose.new()
	moose.cow = cow
	moose.calf = is_calf()
	moose.low_poly = Settings.low_poly
	moose.fur_shells = 0 if Settings.low_poly else 1
	moose.scale = Vector3.ONE * (0.55 if is_calf() else 1.0)
	add_child(moose)
	moose.top_level = true
	moose.struck.connect(_on_struck)
	facing_yaw = rotation.y
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	moose.global_position = global_position
	moose.rotation = Vector3(0.0, facing_yaw, 0.0)
	moose.settle()
	# Its wallow (a calf shares its mother's)
	if not is_calf():
		pool = FishPool.new()
		pool.radius = pool_radius
		pool.shape_seed = int(absf(_home.x * 5.0 + _home.z * 11.0)) % 1000
		pool.visibility_range_end = pose_range + 20.0
		add_child(pool)
		pool.top_level = true
		pool.global_position = _home - Vector3.UP * 0.05
	_rng_rut()


## Whether a bull's rut comes and goes: in it for `rut` of the time, in spells.
func _rng_rut() -> void:
	if cow or is_calf():
		in_rut = false
		return
	in_rut = _rng.randf() < rut
	_rut_left = _rng.randf_range(25.0, 60.0)


## Where its wallow is.
func home() -> Vector3:
	return mother.home() if is_calf() and mother else _home


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
	if not cow and not is_calf():
		_rut_left -= delta
		if _rut_left <= 0.0:
			_rng_rut()
	_mode_left -= delta
	_mode_time += delta
	var grounded := is_on_floor()
	var who := quarry if hunting() else null
	if cow and calf and is_instance_valid(calf):
		_predator_in -= delta
		if _predator_in <= 0.0:
			_predator_in = 0.5
			_predator = _hunting_calf()
	var wish := Vector3.ZERO
	var speed := 0.0
	var turn := turn_rate
	# (running for its life from a bigger hunter, unless it is a cow standing over her calf)
	if threat and is_instance_valid(threat) and not threat.dead and mode not in [Mode.CHARGE, Mode.KNOCK, Mode.STRIKE] and not (cow and _predator):
		_go(Mode.FLEE)
	match mode:
		Mode.BROWSE:
			_point = Vector3.INF
			var provoker := _provoker(who)
			if provoker:
				_warn(provoker)
			elif who and _flat(who.global_position) < 20.0:
				_go(Mode.WATCH)
				_mode_left = _rng.randf_range(3.0, 6.0)
				_target = who
			else:
				_goal_left -= delta
				if _goal_left <= 0.0:
					_goal_left = _rng.randf_range(6.0, 13.0)
					var round_about := _rng.randf_range(0.0, TAU)
					var spot := home() + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, home_range)
					# (often back into the water)
					if _rng.randf() < 0.35:
						spot = home() + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, pool_radius * 0.6)
					_goal = spot if nav.line_free(global_position, spot, _radius) else Vector3.INF
				if _goal.is_finite() and _flat(_goal) > 0.8:
					wish = _goal - global_position
					speed = walk_speed
				if not cow and in_rut:
					_call_in -= delta
					if _call_in <= 0.0:
						_call_in = _rng.randf_range(9.0, 18.0)
						_call()
		Mode.WATCH:
			var provoker := _provoker(who)
			if provoker:
				_warn(provoker)
			elif who == null or _mode_left <= 0.0:
				_go(Mode.BROWSE)
			else:
				_point = who.global_position + Vector3.UP
		Mode.WARN:
			if _target == null or not is_instance_valid(_target) or not _still_provoking(_target):
				_go(Mode.WATCH)
				_mode_left = _rng.randf_range(2.0, 4.0)
			else:
				_point = _target.global_position + Vector3.UP
				if not _stamped_mid and _mode_time > 0.7:
					_stamped_mid = true
					moose.stamp()
				if _mode_left <= 0.0:
					if _reachable(_target):
						_start_charge()
					else:
						_go(Mode.WATCH)
						_mode_left = 3.0
		Mode.CHARGE:
			var gone := not is_instance_valid(_target) or not _reachable_now(_target)
			if not gone:
				_point = _target.global_position + Vector3.UP
				wish = _target.global_position - global_position
				if not nav.line_free(global_position + Vector3.UP * 0.6, _target.global_position + Vector3.UP * 0.6, 0.3):
					_lost_line += delta
				else:
					_lost_line = 0.0
			speed = charge_speed
			turn = charge_turn
			if gone or _lost_line > LOST_LINE or _mode_time > charge_time or _flat(home()) > chase_range:
				_go(Mode.BLOW)
				_mode_left = blow_time
				moose.snort()
			else:
				_knock_check()
		Mode.KNOCK:
			# Round on them: it swings back and comes over where they went down.
			if _down_at.is_finite():
				_point = _down_at
				var to := _down_at - global_position
				to.y = 0.0
				if to.length() > 1.25 and _mode_time > 0.25:
					wish = to
					speed = 2.6
					turn = 3.2
			if _mode_time > 1.6 or (_mode_time > 0.45 and _flat(_down_at) < 1.35):
				_go(Mode.STRIKE)
				_strikes += 1
				moose.strike()
		Mode.STRIKE:
			if _mode_time > Moose.STRIKE_TIME + 0.2:
				_go(Mode.BLOW)
				_mode_left = blow_time
		Mode.BLOW:
			_point = _target.global_position + Vector3.UP if _target and is_instance_valid(_target) else Vector3.INF
			if _mode_left <= 0.0:
				var provoker := _provoker(who)
				if provoker:
					_warn(provoker, 0.7)
				else:
					_go(Mode.RETURN)
		Mode.RETURN:
			_point = Vector3.INF
			var provoker := _provoker(who)
			if provoker and _mode_time > 2.0:
				_warn(provoker)
			elif _flat(home()) < home_range * 0.6:
				_go(Mode.BROWSE)
			else:
				wish = nav.waypoint(global_position, home(), MazeNav.clearance_for(_radius)) - global_position
				speed = walk_speed * 1.6
		Mode.FLEE:
			if threat == null or not is_instance_valid(threat) or threat.dead:
				_go(Mode.RETURN)
			else:
				wish = way(_radius)
				speed = trot_speed
				# (it wheels round to run)
				turn = charge_turn * 1.5
	chasing = mode in [Mode.WARN, Mode.CHARGE, Mode.KNOCK, Mode.STRIKE]
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
		var push := _apart(_radius)
		if push != Vector3.ZERO and mode != Mode.CHARGE:
			wish = (wish + push * 0.5).normalized()
	_drive(wish, speed, turn, delta, grounded)


func _drive(wish: Vector3, speed: float, turn: float, delta: float, grounded: bool) -> void:
	var rate := charge_acceleration if mode == Mode.CHARGE else acceleration * (3.0 if mode in [Mode.BLOW, Mode.KNOCK, Mode.STRIKE] else 1.0)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if wish != Vector3.ZERO:
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(wish.x, wish.z)), -turn * delta, turn * delta)
		forward = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(to.x, to.z)), -turn_rate * delta, turn_rate * delta)
	var target := forward * speed * clampf(forward.dot(wish) if wish != Vector3.ZERO else 0.0, 0.0, 1.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _go(next: Mode) -> void:
	if next != mode:
		mode = next
		_mode_time = 0.0


func _flat(at: Vector3) -> float:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length()


## Who, if anyone, has set it off: someone (or, for a cow, a hunter after her calf) it will warn and charge.
func _provoker(who: Node3D) -> Node3D:
	if is_calf():
		return null
	if cow and _predator and is_instance_valid(_predator) and not _predator.dead:
		return _predator
	if who and _provoking(who, 1.0):
		return who
	return null


func _provoking(who: Node3D, margin: float) -> bool:
	if who.global_position.y - global_position.y > reach_up:
		return false
	if _flat(who.global_position) < space_range * margin:
		return true
	if cow and calf and is_instance_valid(calf) and not calf.dead:
		var to_calf := Vector2(who.global_position.x - calf.global_position.x, who.global_position.z - calf.global_position.z).length()
		if to_calf < calf_range * margin:
			return true
	if in_rut and _flat(who.global_position) < rut_range * margin:
		return true
	return false


func _still_provoking(who: Node3D) -> bool:
	if who is MazeEnemy:
		return not (who as MazeEnemy).dead and _flat(who.global_position) < calf_range * 2.0
	return (hunting() and quarry == who or _flat(who.global_position) < space_range * 2.0) and _provoking(who, 1.3)


## A meat-eater near her calf that is after it (or after her), or hungry.
func _hunting_calf() -> MazeEnemy:
	var world := Ecology.current
	if world == null or calf.dead:
		return null
	var best: MazeEnemy = null
	var nearest := calf_range * 1.5
	for one: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if not (one is MazeEnemy) or one is MazeMoose:
			continue
		var hunter := one as MazeEnemy
		if hunter.dead or hunter.puppet or Ecology.diet(hunter) != Ecology.Diet.MEAT:
			continue
		var d := hunter.global_position.distance_to(calf.global_position)
		if d < nearest and (hunter.quarry == calf or hunter.quarry == self or world.hungry(hunter)):
			nearest = d
			best = hunter
	return best


func _warn(who: Node3D, shorter := 1.0) -> void:
	_go(Mode.WARN)
	_target = who
	_stamped_mid = false
	_mode_left = _rng.randf_range(warn_time.x, warn_time.y) * shorter
	_point = who.global_position + Vector3.UP
	if in_rut or _rng.randf() < 0.4:
		_call()
	else:
		moose.snort()


func _call() -> void:
	_calls += 1
	moose.bugle()


## Whether it could charge `who`: on the ground, in a straight line, near enough its wallow.
func _reachable(who: Node3D) -> bool:
	var to := who.global_position - global_position
	return to.y < reach_up and to.y > -2.0 and Vector2(to.x, to.z).length() < 28.0 and nav.line_free(global_position + Vector3.UP * 0.6, who.global_position + Vector3.UP * 0.6, 0.3)


func _reachable_now(who: Node3D) -> bool:
	if who is MazeEnemy:
		return not (who as MazeEnemy).dead
	if not (huntable(who) or who.get(&"is_limp") == true):
		return false
	var up := who.global_position.y - global_position.y
	return up < reach_up and up > -2.5


func _start_charge() -> void:
	_go(Mode.CHARGE)
	_charge_from = global_position
	_lost_line = 0.0
	moose.snort()


## Charging: whoever its chest reaches is knocked down (a hunter knocked back).
func _knock_check() -> void:
	if Vector2(velocity.x, velocity.z).length() < 3.0:
		return
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var front := global_position + forward * 1.0
	var hit: Node3D = null
	if _target is MazeEnemy:
		var other := _target as MazeEnemy
		if Vector2(other.global_position.x - front.x, other.global_position.z - front.z).length() < knock_radius + Ecology.reach(other) * 0.6:
			hit = other
	else:
		for player: Node3D in players():
			if not huntable(player):
				continue
			var at := player.global_position
			if at.y - global_position.y > reach_up:
				continue
			var near := minf(Vector2(at.x - front.x, at.z - front.z).length(), Vector2(at.x - global_position.x, at.z - global_position.z).length() - _radius * 0.5)
			if near < knock_radius:
				hit = player
				break
	if hit == null:
		return
	_knocks += 1
	_victim = hit
	_down_at = hit.global_position
	_go(Mode.KNOCK)
	if hit is MazeEnemy:
		Stagger.hit(hit, forward)
		_go(Mode.BLOW)
		_mode_left = blow_time
		_predator = null
		return
	_knock_down(hit, forward)


## Knocks `who` down: the boy here goes limp, shoved forward, and gets up after KNOCK_TIME;
## a runner is simply caught; a friend's own machine knocks them down (see `hear`).
func _knock_down(who: Node3D, forward: Vector3) -> void:
	if who is Player:
		var boy := who as Player
		if boy.is_limp:
			return
		boy.ragdoll((forward * 1.0 + Vector3.UP * 0.45).normalized() * 34.0)
		get_tree().create_timer(KNOCK_TIME).timeout.connect(_get_up.bind(boy))
	elif who is MazeRunner:
		_catch(who)


## (untyped: he may be gone by then)
static func _get_up(boy: Variant) -> void:
	if is_instance_valid(boy) and boy.is_limp:
		boy.recover()


## The forehooves come down: whoever is within reach of them is caught.
func _on_struck() -> void:
	if puppet:
		return
	var hooves := moose.hooves_position()
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		if not (huntable(player) or player.get(&"is_limp") == true):
			continue
		var at := player.global_position
		if player is Player and (player as Player).is_limp:
			at = (player as Player).visual_position
		if at.y - global_position.y > reach_up:
			continue
		if Vector2(at.x - hooves.x, at.z - hooves.z).length() < stamp_reach:
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
			moose.visible = not far
			moose.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				moose.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	moose.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	moose.rotation = Vector3(0.0, facing_yaw, 0.0)
	moose.grounded = is_on_floor() or puppet
	var slow := Vector2(velocity.x, velocity.z).length() < 0.35
	var in_water := _flat(home()) < pool_radius * 0.85
	moose.browsing = mode == Mode.BROWSE and slow and not in_water
	moose.grazing = mode == Mode.BROWSE and slow and in_water
	moose.alert = mode == Mode.WATCH
	moose.bristling = mode in [Mode.WARN, Mode.BLOW, Mode.KNOCK]
	moose.lowered = mode == Mode.CHARGE
	moose.pawing = mode == Mode.WARN and not cow and in_rut and _mode_time > 0.9
	moose.look_at_point = _point if mode != Mode.CHARGE else Vector3.INF
	# Wading: down into the black water of its wallow, to its knees in the middle
	var from_middle := _flat(home()) / pool_radius
	_wade = DeerRig._approach(_wade, clampf(1.0 - from_middle, 0.0, 1.0) * 0.5 * (0.55 if is_calf() else 1.0), 4.0, delta)
	moose.wading = _wade
	var wallow := pool if pool else (mother.pool if mother else null)
	if wallow and from_middle < 1.0 and not slow and fposmod(Time.get_ticks_msec() * 0.001, 0.6) < delta:
		wallow.stir(global_position, 0.6)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Calls (bits 0-1), strikes (2-3), knock-downs (4-5), in the rut (6).
func net_flag() -> int:
	return (_calls & 3) | ((_strikes & 3) << 2) | ((_knocks & 3) << 4) | ((1 if in_rut else 0) << 6)


func net_point() -> Vector3:
	return _down_at if mode in [Mode.KNOCK, Mode.STRIKE] else _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	if state != mode:
		_mode_time = 0.0
	mode = state as Mode
	chasing = mode in [Mode.WARN, Mode.CHARGE, Mode.KNOCK, Mode.STRIKE]
	_point = point
	in_rut = (flag >> 6) & 1 == 1
	var calls := flag & 3
	var strikes := (flag >> 2) & 3
	var knocks := (flag >> 4) & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif moose:
		if calls != (_calls & 3):
			moose.bugle()
		if strikes != (_strikes & 3):
			moose.strike()
		if knocks != (_knocks & 3):
			_knocked_here(point, Vector3(sin(facing), 0.0, cos(facing)))
	_calls = calls
	_strikes = strikes
	_knocks = knocks
	_down_at = point if mode in [Mode.KNOCK, Mode.STRIKE] else Vector3.INF


## (a guest) The host's moose has knocked someone down at `at`: if it was this
## machine's boy, he goes down here.
func _knocked_here(at: Vector3, forward: Vector3) -> void:
	var me := local_player()
	if me == null or not at.is_finite() or me.global_position.distance_to(at) > 3.0:
		return
	_knock_down(me, forward)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if moose:
		moose.global_position = at
		moose.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
