class_name MazeHorse
extends MazeEnemy
## A lonely horse: feral, long in the maze, alone (one or two in the whole of
## it). It is drawn and moved by Horse (creatures/horse/horse.gd); this is what
## it thinks. It hunts nobody. It is something to come across.
##
## ALONE. It wanders slowly about the wide halls, and out to the clearing's
## edge (it may go into the clearing; one put in the clearing keeps to its
## edge, `home`), stopping to graze, standing still a long time looking at
## nothing (dozing, a hind leg rested), now and then rolling in the dust and
## shaking itself off, and calling out (a long whinny that carries across the
## maze and is never answered).
## WARY. Someone it sees, it watches: head up, ears forward. Come at it fast
## (running at it, or sprinting near) and it snorts and canters off. Come slowly
## (walking, ducked) and it lets you nearer the longer you are slow and still
## near it (`ease`); too near too soon, and it walks off a few steps.
## TRUST. Once it lets you near, touch it (the act button, empty-handed, at its
## side: it is in the group `workable`) and it lowers its head and nickers;
## three touches a little apart (`touches_to_trust`) and it trusts you: then it
## follows you about at a walk or trot (`follow_for` seconds after you were last
## near it), stops when you stop, and lets you touch it whenever you like.
## FEAR. A hunter near (one after someone, or the world's meat-eaters that
## would eat it: Ecology, size 3, eats plants) and it spooks: snorts, head and
## tail up, and bolts at a gallop down the passages away from it. A big
## meat-eater can catch it and kill it.
##
## Online, the host decides: a guest's touch is asked of the host
## (K_JSON {"horse": "touch"}), and its trust, whom it follows, its calls and
## its moves come to guests in its state.

enum Mode { GRAZE, WANDER, STAND, WATCH, EDGE_OFF, FLEE, FOLLOW, ROLL }

@export var walk_speed := 1.3
@export var trot_speed := 3.2
@export var canter_speed := 6.0
@export var gallop_speed := 9.5
@export var acceleration := 4.0
@export var turn_rate := 2.2
## How near a player may come before it is wary of them, metres (it lets them
## nearer as it eases to them: `ease`), and how near a hunter frightens it.
@export var wary_range := 9.0
@export var hunter_range := 18.0
## Touches (apart by `touch_gap` seconds) it takes to trust someone.
@export var touches_to_trust := 3
@export var touch_gap := 1.5
## How long it follows a friend after they were last near it, seconds.
@export var follow_for := 120.0
## Its patch (a horse in the clearing keeps to its edge here), and how far it goes from it.
@export var home := Vector3.INF
@export var home_range := 60.0
## How it looks (set before it goes in).
@export var coat := Horse.Coat.DUN
@export var haltered := false
@export var size := 1.0
@export var pose_range := 95.0
@export var gravity := 24.0

var mode := Mode.STAND
var facing_yaw := 0.0
var horse: Horse
## How much it trusts people, 0..1 (1: it trusts its friend), and whom it follows.
var trust := 0.0
var friend: Node3D
var touches := 0

var _radius := 0.5
var _mode_left := 4.0
var _goal := Vector3.INF
var _point := Vector3.INF
var _ease := 0.0
var _last_touch := -100.0
var _clock := 0.0
var _friend_seen := -1000.0
var _call_in := 30.0
var _roll_in := 120.0
var _whinnies := 0
var _snorts := 0
var _nickers := 0
var _handle: Node3D
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
var _net_bound := false


func _init() -> void:
	sight_range = 36.0
	hear_range = 8.0
	memory = 6.0
	alert_range = 0.0
	pack = &"horses"
	look_every = 0.25
	keep_out_of_clearing = false


func _ready() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.48 * size
	shape.radius = _radius
	shape.height = 1.7 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	horse = Horse.new()
	horse.coat = coat
	horse.haltered = haltered
	horse.low_poly = Settings.low_poly
	horse.fur_shells = 0 if Settings.low_poly else 1
	horse.scale = Vector3.ONE * size
	add_child(horse)
	horse.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	horse.global_position = global_position
	horse.rotation = Vector3(0.0, facing_yaw, 0.0)
	horse.settle()
	_call_in = _rng.randf_range(15.0, 50.0)
	_roll_in = _rng.randf_range(80.0, 200.0)
	# What a hand reaches to touch: a point on its side, nearest whoever is by it (Player's `workable`).
	_handle = Touch.new()
	_handle.name = "Touch"
	(_handle as Touch).horse = self
	add_child(_handle)
	_handle.top_level = true
	_bind_net.call_deferred()


## The world it is in (World, if there is one), for the room.
func _world() -> Node:
	var at := get_parent()
	while at and not (&"remotes" in at):
		at = at.get_parent()
	return at


func _online() -> bool:
	var world := _world()
	return world != null and world.get(&"online") == true


func _bind_net() -> void:
	var net := get_node_or_null(^"/root/Net")
	if net and _online() and not _net_bound:
		_net_bound = true
		net.packet.connect(_on_packet)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_clock += delta
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	var who := quarry if hunting() else null
	var wish := Vector3.ZERO
	var speed := 0.0
	_mode_left -= delta
	_call_in -= delta
	var fright := _fright()
	if fright.is_finite() and mode != Mode.FLEE:
		_bolt(fright, true)
	if friend and is_instance_valid(friend) and friend.global_position.distance_to(global_position) < 30.0:
		_friend_seen = _clock
	var following := trust >= 1.0 and friend != null and is_instance_valid(friend) and _clock - _friend_seen < follow_for
	match mode:
		Mode.GRAZE, Mode.STAND, Mode.WANDER:
			_point = Vector3.INF
			if who and not following:
				mode = Mode.WATCH
			elif following and friend.global_position.distance_to(global_position) > 5.0:
				mode = Mode.FOLLOW
			elif mode == Mode.WANDER:
				if not _goal.is_finite() or _flat(_goal - global_position).length() < 2.0 or _mode_left <= 0.0:
					_next_idle()
				else:
					wish = nav.waypoint(global_position, _goal, MazeNav.clearance_for(_radius)) - global_position
					speed = walk_speed
			elif _mode_left <= 0.0:
				_next_idle()
			if _call_in <= 0.0 and mode in [Mode.STAND, Mode.WANDER, Mode.GRAZE]:
				_call_in = _rng.randf_range(40.0, 95.0)
				_whinny()
		Mode.WATCH:
			if who == null:
				mode = Mode.STAND
				_mode_left = _rng.randf_range(4.0, 9.0)
			else:
				_point = who.global_position + Vector3.UP * 1.2
				var to := _flat(who.global_position - global_position)
				var them: Vector3 = who.get(&"velocity") if who.get(&"velocity") != null else Vector3.ZERO
				var moving := _flat(them).length()
				var at_it := moving > 0.5 and _flat(them).normalized().dot(-to.normalized()) > 0.4
				var sprinting: bool = who.get(&"is_sprinting") == true
				var slow: bool = moving < 2.2 or who.get(&"is_ducking") == true
				# (it eases to them while they are near and slow, and trusts them more the more they touch it)
				if to.length() < 15.0 and slow:
					_ease = minf(_ease + delta / 9.0, 1.0)
				elif not slow:
					_ease = maxf(_ease - delta / 2.0, 0.0)
				if trust >= 1.0 and who == friend:
					mode = Mode.FOLLOW
				elif (at_it and moving > 3.2 and to.length() < 14.0) or (sprinting and to.length() < 10.0):
					if trust < 1.0:
						_snort()
						_bolt(who.global_position, false)
				elif at_it and to.length() < lerpf(wary_range, 0.0, maxf(_ease, trust)) and trust < 1.0:
					mode = Mode.EDGE_OFF
					_mode_left = 2.5
					_goal = _away(who.global_position, 5.0)
		Mode.EDGE_OFF:
			wish = _goal - global_position
			speed = walk_speed * 1.2
			if who:
				_point = who.global_position + Vector3.UP * 1.2
			if _mode_left <= 0.0 or _flat(wish).length() < 0.8:
				mode = Mode.WATCH
		Mode.FLEE:
			wish = way(_radius)
			speed = gallop_speed if threat or _mode_left > 4.0 else canter_speed
			if _mode_left <= 0.0 and not _fright().is_finite():
				mode = Mode.STAND
				_mode_left = _rng.randf_range(5.0, 10.0)
				_call_in = minf(_call_in, _rng.randf_range(3.0, 8.0))
		Mode.FOLLOW:
			if not following:
				mode = Mode.STAND
				_mode_left = 3.0
			else:
				_point = friend.global_position + Vector3.UP * 1.2
				var to := _flat(friend.global_position - global_position)
				if to.length() > 3.5:
					wish = nav.waypoint(global_position, friend.global_position, MazeNav.clearance_for(_radius)) - global_position
					speed = walk_speed if to.length() < 7.0 else (trot_speed if to.length() < 18.0 else canter_speed)
		Mode.ROLL:
			if not horse.rolling():
				horse.shake()
				mode = Mode.STAND
				_mode_left = 4.0
	chasing = false
	var flat := _flat(wish)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if flat.length() > 0.05:
		var want := atan2(flat.x, flat.z)
		var rate := turn_rate * (1.6 if mode == Mode.FLEE else 1.0)
		facing_yaw += clampf(angle_difference(facing_yaw, want), -rate * delta, rate * delta)
		forward = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	elif _point.is_finite() and mode in [Mode.WATCH, Mode.FOLLOW]:
		var to := _point - global_position
		if absf(angle_difference(facing_yaw, atan2(to.x, to.z))) > 1.2:
			facing_yaw += clampf(angle_difference(facing_yaw, atan2(to.x, to.z)), -0.8 * delta, 0.8 * delta)
	var target := forward * speed * clampf(forward.dot(flat.normalized()) if flat.length() > 0.05 else 0.0, 0.0, 1.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta * (2.0 if mode == Mode.FLEE else 1.0))
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Where what frightens it is: something that would eat it (Ecology's `threat`),
## or a hunter after someone near it. INF: nothing.
func _fright() -> Vector3:
	if threat and is_instance_valid(threat) and not threat.dead:
		return threat.global_position
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		var other := node as MazeEnemy
		if other == null or other == self or other.dead or not other.chasing or other.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if other.global_position.distance_to(global_position) < hunter_range:
			return other.global_position
	return Vector3.INF


## Away it goes from `from`: at a gallop from a hunter, a canter from a player.
func _bolt(from: Vector3, hunter: bool) -> void:
	mode = Mode.FLEE
	_mode_left = 7.0 if hunter else 3.5
	_last_seen = Vector3.INF
	quarry = null
	_forget = 0.0
	_wander_goal = Vector2i(-1, -1)
	if hunter:
		_snort()
	_flee_from = from


var _flee_from := Vector3.INF


func goal() -> Vector3:
	if mode == Mode.FLEE and _flee_from.is_finite() and not threat:
		return _away_from(_flee_from)
	return super()


## A spot `far` metres from it, away from `danger`, that it can walk to.
func _away(danger: Vector3, far: float) -> Vector3:
	var off := _flat(global_position - danger).normalized()
	var spot := global_position + off * far
	return spot if nav.line_free(global_position, spot, _radius) else _away_from(danger)


## What it does next on its own: graze, stand (and doze), wander a while, or roll.
func _next_idle() -> void:
	var pick := _rng.randf()
	if _roll_in <= 0.0 and mode != Mode.WANDER:
		_roll_in = _rng.randf_range(150.0, 300.0)
		mode = Mode.ROLL
		horse.roll()
		return
	_roll_in -= _mode_left + 10.0
	if pick < 0.35:
		mode = Mode.GRAZE
		_mode_left = _rng.randf_range(10.0, 25.0)
	elif pick < 0.6:
		mode = Mode.STAND
		_mode_left = _rng.randf_range(12.0, 35.0)
	else:
		mode = Mode.WANDER
		_mode_left = _rng.randf_range(20.0, 45.0)
		if home.is_finite():
			var round_about := _rng.randf_range(0.0, TAU)
			_goal = home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, home_range)
		else:
			_goal = nav.point(nav.wander(maze.cell_at(global_position), _rng, 2, 7))


func _whinny() -> void:
	_whinnies += 1
	horse.whinny()


func _snort() -> void:
	_snorts += 1
	horse.snort()


# --- Being touched ---

## Someone's hand on it (seat `seat` when that is known, for the room). Here
## (alone, or the host) it counts; a guest asks the host.
func touch(who: Node3D) -> void:
	if puppet:
		if _online():
			var net := get_node_or_null(^"/root/Net")
			if net:
				net.send_json(net.BROADCAST, {"horse": "touch", "name": String(name)})
		horse.twitch(_handle.global_position)
		return
	_touched(who)


func _touched(who: Node3D) -> void:
	if dead or mode in [Mode.FLEE, Mode.ROLL]:
		return
	if trust < 1.0 and _ease < 0.6 and who.global_position.distance_to(global_position) < 3.0:
		# (touched before it is ready: it shies off)
		_snort()
		_bolt(who.global_position, false)
		return
	horse.twitch(_handle.global_position)
	if _clock - _last_touch < touch_gap:
		return
	_last_touch = _clock
	touches += 1
	_nickers += 1
	horse.nicker()
	friend = who
	_friend_seen = _clock
	trust = minf(float(touches) / touches_to_trust, 1.0)
	_ease = 1.0
	if mode not in [Mode.FOLLOW]:
		mode = Mode.WATCH if trust < 1.0 else Mode.FOLLOW


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	var net := get_node_or_null(^"/root/Net")
	if net == null or kind != net.K_JSON or not net.is_host or puppet:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not (message is Dictionary) or str(message.get("horse", "")) != "touch" or str(message.get("name", "")) != String(name):
		return
	var world := _world()
	var remotes: Dictionary = world.get(&"remotes") if world else {}
	if remotes.has(from) and is_instance_valid(remotes[from]):
		_touched(remotes[from])


## What a hand reaches for: a point on the horse's side nearest whoever is by
## it, in the group `workable` (Player's act button works it).
class Touch extends Node3D:
	var horse: MazeHorse

	func _ready() -> void:
		add_to_group(&"workable")

	func _process(_delta: float) -> void:
		if horse == null or horse.horse == null:
			return
		var near := horse.local_player()
		var middle := horse.global_position + Vector3.UP * 0.95 * horse.size
		var way := Vector3(sin(horse.facing_yaw), 0.0, cos(horse.facing_yaw))
		if near == null:
			global_position = middle
			return
		# (along its body, from its shoulder back to its flank, and out to its side)
		var to := near.global_position - horse.global_position
		var along := clampf(to.dot(way), -0.6 * horse.size, 0.7 * horse.size)
		var across := to - way * to.dot(way)
		across.y = 0.0
		global_position = middle + way * along + across.normalized() * 0.36 * horse.size
		global_position.y = near.global_position.y + 0.9

	func work_point() -> Vector3:
		return global_position

	func work(who: Node3D) -> void:
		if horse and not horse.dead:
			horse.touch(who)


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			horse.visible = not far
			horse.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				horse.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-8.0 * delta))
	var moving := _flat(velocity).length()
	horse.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	horse.rotation = Vector3(0.0, facing_yaw, 0.0)
	horse.grounded = is_on_floor() or puppet
	horse.grazing = mode == Mode.GRAZE and moving < 0.3
	horse.alert = mode in [Mode.WATCH, Mode.EDGE_OFF] and trust < 1.0
	horse.dozing = mode == Mode.STAND and _mode_left > 6.0
	horse.fleeing = mode == Mode.FLEE and moving > 6.5
	horse.spooked = mode == Mode.FLEE and moving < 6.5
	horse.friendly = trust >= 1.0 or (mode == Mode.WATCH and _ease > 0.7)
	horse.look_at_point = _point if mode in [Mode.WATCH, Mode.EDGE_OFF, Mode.FOLLOW] else Vector3.INF
	if mode == Mode.ROLL and puppet and not horse.rolling() and _heard_state == Mode.ROLL and not _rolled_heard:
		_rolled_heard = true
		horse.roll()
	if mode != Mode.ROLL:
		_rolled_heard = false


var _rolled_heard := false


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## How far it trusts (low two bits: 0 to 3, 3 trusting), then whinnies, snorts and nickers (two bits each).
func net_flag() -> int:
	return clampi(int(trust * 3.0), 0, 3) | ((_whinnies & 3) << 2) | ((_snorts & 3) << 4) | ((_nickers & 3) << 6)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	_point = point
	trust = (flag & 3) / 3.0
	var whinnies := (flag >> 2) & 3
	var snorts := (flag >> 4) & 3
	var nickers := (flag >> 6) & 3
	if _heard_flagged and horse:
		if whinnies != (_whinnies & 3):
			horse.whinny()
		if snorts != (_snorts & 3):
			horse.snort()
		if nickers != (_nickers & 3):
			horse.nicker()
	_heard_flagged = true
	_whinnies = whinnies
	_snorts = snorts
	_nickers = nickers


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if horse:
		horse.global_position = at
		horse.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
