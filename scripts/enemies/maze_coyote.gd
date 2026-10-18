class_name MazeCoyote
extends MazeEnemy
## A coyote, one of a small pack (or alone): wildlife more than a hunter. It is
## drawn and moved by Coyote (creatures/coyote/coyote.gd); this is what it thinks.
##
## MOSTLY SKITTISH. The pack trots about its stretch of the maze, its leader
## choosing where, the rest loping after it; now and then one stops to sniff.
## Seeing a player it stops and stares, then SHADOWS them: it keeps its
## distance (`keep_range`), following them along the halls, stopping to stare
## whenever they look round. Now and then the pack breaks into its yip-howl
## chorus (one starts, the rest join). Come close (`flee_range`), or run at it,
## and it gallops off a way and slinks back. A coyote alone, or a pair, does no
## more than that, ever.
##
## A LITTLE DANGEROUS IN A GROUP. If three or more of a pack are shadowing one
## player who is alone (nobody else within `lone_range`), they grow bold
## (`boldness` fills over about `bold_time` seconds, and drains when the player
## has company, runs at them, or there are fewer of them). Bold, they CIRCLE:
## a ring of them closing in round the player, low, stiff, hackles up, snarling
## and yipping (the warning: a couple of seconds of it before any of them goes
## in). Then the one behind the player (out of the way they face) darts in and
## snaps (the dog's lunge: `caught` only if its jaws close on them). Turn on one
## and it backs off; run at one and it flees and the pack loses its nerve;
## running away gets away (they close in at `circle_speed`, slower than a run);
## a friend coming near ends it. After a snap, hit or miss, the pack scatters
## and will not be bold again for a while.
##
## TAME (`tame`): the coyotes of the clearing (ClearingStyle "Wildlife"). They
## keep to their part of the meadow (`home`, `home_range`), stare, shadow,
## chorus and run off, and are never bold. They are put in by
## MazeEnemies.add_wildlife and are run (and sent to guests) like the rest.
##
## `MazeCoyote.pack_of(count, seed)` makes a pack (each a little different: which
## model, its colour, its size); the pack is told apart by `pack_id`.

enum Mode { ROAM, SNIFF, STARE, SHADOW, CHORUS, SLINK, FLEE, CIRCLE, DART }

## How much bigger than the model it is drawn (the model is a big dog's size).
const SCALE := 0.82

@export var trot_speed := 1.9
@export var shadow_speed := 2.6
@export var flee_speed := 6.5
@export var slink_speed := 1.2
## Closing in, bold: slower than a run, so running away gets away.
@export var circle_speed := 3.6
@export var acceleration := 12.0
@export var turn_rate := 8.0
## How far off it likes to keep from a player, and how near sends it running.
@export var keep_range := 15.0
@export var flee_range := 6.0
## Nobody else this near the player: they are alone.
@export var lone_range := 12.0
## About how long it takes a pack of three shadowing someone alone to grow bold.
@export var bold_time := 7.0
## How far it springs from, when it darts in.
@export var lunge_range := 2.0
@export var tame := false
## Its patch, for a tame one: the middle and how far it goes from it.
@export var home := Vector3.INF
@export var home_range := 45.0
@export var pose_range := 80.0
@export var gravity := 24.0
@export var variant := 0
@export var coat_tint := Color.WHITE
@export var size := SCALE
## Which pack it is in (the same for all of a pack, on every machine).
@export var pack_id := 0

var mode := Mode.ROAM
var facing_yaw := 0.0
var coyote: Coyote
## How bold it is, 0..1 (its pack's, as each of them reckons it).
var boldness := 0.0

var _radius := 0.25
var _timer := 0.0
var _point := Vector3.INF
var _goal := Vector3.INF
var _flee_from := Vector3.ZERO
var _shy := 0.0
var _circle_time := 0.0
var _slot := 0.0
var _chorus_in := 0.0
var _bit := false
var _lunges := 0
var _choruses := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


## A pack of `count`, ready to be placed: each its own model, colour and size.
static func pack_of(count: int, seed_value := 0) -> Array[MazeCoyote]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color.WHITE, Color(1.05, 0.98, 0.9), Color(0.92, 0.92, 0.94), Color(1.08, 0.96, 0.86), Color(0.96, 0.94, 0.92)]
	var made: Array[MazeCoyote] = []
	var id := absi(seed_value) % 1000000 + 1
	for i in count:
		var one := MazeCoyote.new()
		one.variant = (i + rng.randi_range(0, 1)) % 2
		one.coat_tint = tints[(i + rng.randi_range(0, 4)) % tints.size()]
		one.size = SCALE * rng.randf_range(0.92, 1.06)
		one.pack_id = id
		made.append(one)
	return made


func _init() -> void:
	sight_range = 46.0
	hear_range = 14.0
	memory = 10.0
	alert_range = 0.0
	pack = &"coyotes"
	look_every = 0.25


func _ready() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 0.8 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	coyote = Coyote.new()
	coyote.variant = variant
	coyote.coat_tint = coat_tint
	coyote.low_poly = Settings.low_poly
	coyote.scale = Vector3.ONE * size
	coyote.lunge_reach = Vector2(1.0, 3.4)
	add_child(coyote)
	coyote.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	coyote.global_position = global_position
	coyote.rotation = Vector3(0.0, facing_yaw, 0.0)
	coyote.settle()
	if not home.is_finite():
		home = global_position
	_chorus_in = _rng.randf_range(8.0, 30.0)
	if not tame:
		add_to_group(&"pursuers")


## The others of its pack (not itself).
func pack_mates() -> Array[MazeCoyote]:
	var mates: Array[MazeCoyote] = []
	if not is_inside_tree():
		return mates
	for other: Node in get_tree().get_nodes_in_group(&"coyotes"):
		if other != self and other is MazeCoyote and (other as MazeCoyote).pack_id == pack_id:
			mates.append(other)
	return mates


## Its leader: the first of the pack in the scene (who chooses where they go).
func leader() -> MazeCoyote:
	var first: MazeCoyote = self
	for mate in pack_mates():
		if mate.get_index() < first.get_index():
			first = mate
	return first


## Whether `player` can be bothered now. Wild ones keep out of the clearing,
## tame ones keep to it.
func huntable(player: Node3D) -> bool:
	if not super(player):
		return false
	if maze == null:
		return true
	var inside := maze.in_clearing(maze.cell_at(player.global_position))
	# (put in by hand where it may go into the clearing, it goes after people there too)
	return inside if tame else not (inside and keep_out_of_clearing)


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
	_timer -= delta
	_shy -= delta
	_chorus_in -= delta
	var who := quarry if hunting() else null
	if who == null and mode in [Mode.STARE, Mode.SHADOW, Mode.CIRCLE]:
		mode = Mode.ROAM
	_reckon_boldness(who, delta)
	chasing = mode in [Mode.CIRCLE, Mode.DART]
	var wish := Vector3.ZERO
	var speed := 0.0
	_point = who.global_position + Vector3.UP * 0.9 if who else Vector3.INF
	# Run at, or come too near: off it goes.
	if who and mode not in [Mode.FLEE, Mode.DART]:
		var to_me := global_position - who.global_position
		to_me.y = 0.0
		var them := _velocity_of(who)
		var charging := them.length() > 3.0 and them.normalized().dot(to_me.normalized()) > 0.8 and to_me.length() < 12.0
		# (in the ring it holds its ground, unless it is run at, or faced down close)
		var too_near := to_me.length() < flee_range if mode != Mode.CIRCLE else (to_me.length() < 2.4 and _facing(who) > 0.85)
		if too_near or charging:
			if mode == Mode.CIRCLE:
				# (in the ring, facing it down sends only that one off, and shakes the rest)
				_shake_pack(0.5)
			_flee(who.global_position)
	match mode:
		Mode.DART:
			var push := coyote.lunge_push()
			velocity.x = push.x
			velocity.z = push.z
			if not _bit:
				for player: Node3D in players():
					if huntable(player) and coyote.bite_hits(player.global_position + Vector3.UP * 0.6, 0.6):
						_bit = true
						_catch(player)
						break
			if coyote.lunge_stage() == Dog.Lunge.NONE:
				# Hit or miss, the pack scatters and loses its nerve for a while.
				_shake_pack(2.0)
				_flee(who.global_position if who else global_position - global_basis.z)
			_move(delta, grounded)
			return
		Mode.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			wish = _way_toward(global_position + away.normalized() * 10.0)
			speed = flee_speed
			if _timer <= 0.0:
				mode = Mode.SLINK
				_timer = _rng.randf_range(2.0, 4.0)
		Mode.SLINK:
			if who:
				var away := global_position - who.global_position
				away.y = 0.0
				wish = _way_toward(global_position + away.normalized() * 6.0)
			else:
				wish = _wander_way()
			speed = slink_speed
			if _timer <= 0.0:
				mode = Mode.SHADOW if who else Mode.ROAM
		Mode.STARE:
			if _timer <= 0.0:
				mode = Mode.SHADOW
		Mode.CHORUS:
			if _timer <= 0.0 or not coyote.chorusing():
				mode = Mode.SHADOW if who else Mode.ROAM
		Mode.SHADOW:
			var to := who.global_position - global_position
			to.y = 0.0
			var gap := to.length()
			if gap > keep_range + 3.0:
				wish = way(_radius)
				speed = shadow_speed
			elif gap < keep_range - 3.0:
				wish = _way_toward(global_position - to.normalized() * 4.0)
				speed = trot_speed * 0.8
			# (they looked round at it: it stops and stares back)
			if _facing(who) > 0.85 and gap < keep_range + 6.0:
				wish = Vector3.ZERO
			if _chorus_in <= 0.0 and leader() == self:
				_start_chorus()
			if boldness >= 1.0:
				_begin_circling()
		Mode.CIRCLE:
			_circle_time += delta
			var to := who.global_position - global_position
			to.y = 0.0
			var gap := to.length()
			# Round them, closing in: from about 8 m down to 3.5 over a few seconds.
			var radius := lerpf(8.0, 2.4, clampf(_circle_time / 4.0, 0.0, 1.0))
			var their_way := _forward_of(who)
			var spot := who.global_position + Basis(Vector3.UP, _slot) * their_way * radius
			var at := spot - global_position
			at.y = 0.0
			wish = at if at.length() > 0.3 else Vector3.ZERO
			speed = circle_speed if at.length() > 1.5 else 1.2
			# (turned on, it backs off a little)
			if _facing(who) > 0.92 and gap < 6.0:
				wish = -to
				speed = 1.8
			if gap > 30.0:
				mode = Mode.SHADOW
				_circle_time = 0.0
				boldness = minf(boldness, 0.5)
			elif _circle_time > 2.4 and gap < lunge_range * 1.3 and _facing(who) < 0.3 and grounded:
				_dart(who)
				return
		Mode.SNIFF:
			if _timer <= 0.0:
				mode = Mode.ROAM
		Mode.ROAM:
			wish = _wander_way()
			speed = trot_speed
			if _timer <= 0.0:
				_timer = _rng.randf_range(4.0, 9.0)
				if _rng.randf() < 0.35:
					mode = Mode.SNIFF
					_timer = _rng.randf_range(1.5, 3.5)
			if who and _shy <= 0.0:
				mode = Mode.STARE
				_timer = _rng.randf_range(1.0, 2.5)
			if _chorus_in <= 0.0 and leader() == self and _rng.randf() < 0.3:
				_start_chorus()
	var push := _apart(_radius * 1.6)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	elif push != Vector3.ZERO and mode != Mode.CHORUS:
		wish = push
		speed = maxf(speed, 1.0)
	_steer(wish, speed, delta, grounded)


## How the pack's nerve stands: three or more of them shadowing someone alone
## and it grows; company, fewer of them, or being run at, and it goes.
func _reckon_boldness(who: Node3D, delta: float) -> void:
	if tame or who == null:
		# (back to nothing: quickly from boldness, slowly from a fright)
		boldness = move_toward(boldness, 0.0, delta / (20.0 if boldness < 0.0 else 3.0))
		return
	var near := 1
	for mate in pack_mates():
		if mate.global_position.distance_to(who.global_position) < 24.0 and mate.mode not in [Mode.FLEE, Mode.SLINK]:
			near += 1
	var alone := true
	for player: Node3D in players():
		if player != who and is_instance_valid(player) and player.global_position.distance_to(who.global_position) < lone_range:
			alone = false
	if near >= 3 and alone and mode in [Mode.SHADOW, Mode.STARE, Mode.CIRCLE, Mode.CHORUS]:
		boldness += delta / bold_time * (1.0 + 0.25 * (near - 3))
	else:
		boldness -= delta / 3.0
	boldness = clampf(boldness, -1.0, 1.2)
	if mode == Mode.CIRCLE and boldness < 0.4:
		mode = Mode.SHADOW
		_circle_time = 0.0


func _begin_circling() -> void:
	# (the rest of the pack is in the ring already: it just joins it)
	for mate in pack_mates():
		if mate.mode == Mode.CIRCLE:
			mode = Mode.CIRCLE
			_circle_time = 0.0
			_slot = mate._slot + PI * 0.5
			return
	for one in [self] + pack_mates():
		var mate := one as MazeCoyote
		if mate.mode in [Mode.SHADOW, Mode.STARE, Mode.CHORUS, Mode.ROAM]:
			mate.mode = Mode.CIRCLE
			mate.boldness = maxf(mate.boldness, 1.0)
			mate._circle_time = 0.0
			mate.coyote.hush()
	# (each takes its own place round them, spread from behind them round both sides)
	var ring := [self] + pack_mates()
	for k in ring.size():
		(ring[k] as MazeCoyote)._slot = PI + (k - (ring.size() - 1) * 0.5) * 1.1
	yip_now()


## Everyone in the pack loses some nerve (`amount`; 2: they will not be bold again for a while).
func _shake_pack(amount: float) -> void:
	for one in [self] + pack_mates():
		var mate := one as MazeCoyote
		mate.boldness = minf(mate.boldness - amount, 0.3) if amount < 1.0 else -1.0
		if amount >= 1.0 and mate.mode == Mode.CIRCLE and mate != self:
			mate._flee(mate.global_position + (mate.global_position - global_position))


func _flee(from: Vector3) -> void:
	mode = Mode.FLEE
	_flee_from = from
	_timer = _rng.randf_range(1.6, 2.6)
	_shy = _rng.randf_range(4.0, 7.0)
	_circle_time = 0.0
	coyote.hush()


func _dart(who: Node3D) -> void:
	mode = Mode.DART
	_bit = false
	_lunges += 1
	var them := _velocity_of(who)
	_point = who.global_position + Vector3(them.x, 0.0, them.z) * (Dog.GATHER_TIME + Dog.SPRING_TIME * 0.8)
	velocity.x = 0.0
	velocity.z = 0.0
	coyote.lunge(_point)


func _start_chorus() -> void:
	_chorus_in = _rng.randf_range(25.0, 50.0)
	var ring := [self] + pack_mates()
	for k in ring.size():
		var mate := ring[k] as MazeCoyote
		if mate.mode in [Mode.ROAM, Mode.SNIFF, Mode.STARE, Mode.SHADOW]:
			mate._chorus_in = _chorus_in
			mate._join_chorus(k, 0.35 * k + _rng.randf_range(0.0, 0.3))


func _join_chorus(which: int, after: float) -> void:
	mode = Mode.CHORUS
	_timer = after + 3.6
	_choruses += 1
	get_tree().create_timer(after, false).timeout.connect(func() -> void:
		if is_inside_tree() and mode == Mode.CHORUS:
			coyote.chorus(which % Coyote.CHORUSES, which == 1))


## A yip, from the ring closing in: the warning.
func yip_now() -> void:
	if coyote:
		coyote.yip()


func _wander_way() -> Vector3:
	var lead := leader()
	if lead != self:
		# Loping after its leader, a little to one side.
		var behind := lead.global_position - Basis(Vector3.UP, lead.facing_yaw) * Vector3(sin(float(get_index())) * 2.5, 0.0, 2.5)
		var to := behind - global_position
		to.y = 0.0
		return _way_toward(behind) if to.length() > 1.2 else Vector3.ZERO
	if tame:
		if not _goal.is_finite() or Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() < 2.0:
			var round_about := _rng.randf_range(0.0, TAU)
			_goal = home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, home_range)
		var to := _goal - global_position
		to.y = 0.0
		return to
	return way(_radius)


func _way_toward(point: Vector3) -> Vector3:
	if tame:
		var to := point - global_position
		to.y = 0.0
		# (a tame one keeps to its patch)
		if (global_position + to.normalized() * 2.0).distance_to(home) > home_range * 1.5:
			to = (home - global_position).normalized() * 0.5 + to.normalized()
		return to
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	_move(delta, grounded)


func _move(delta: float, grounded: bool) -> void:
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


static func _velocity_of(who: Node3D) -> Vector3:
	var them: Variant = who.get(&"velocity")
	return Vector3(them.x, 0.0, them.z) if them is Vector3 else Vector3.ZERO


## The way a player faces, flat (from how they face, or how they move).
static func _forward_of(who: Node3D) -> Vector3:
	var facing: Variant = who.get(&"facing_yaw")
	if facing != null:
		return Vector3(sin(facing), 0.0, cos(facing))
	var moving := _velocity_of(who)
	if moving.length() > 0.2:
		return moving.normalized()
	return Vector3(sin(who.global_rotation.y), 0.0, cos(who.global_rotation.y))


## How square on `who` faces it: 1 looking straight at it, -1 straight away.
func _facing(who: Node3D) -> float:
	var to := global_position - who.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return 1.0
	return _forward_of(who).dot(to.normalized())


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			coyote.visible = not far
			coyote.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				coyote.settle()
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode == Mode.DART:
		var way_now := coyote.lunge_way()
		facing_yaw = lerp_angle(facing_yaw, atan2(way_now.x, way_now.z), 1.0 - exp(-14.0 * delta))
	elif heading.length_squared() > 0.09 and mode != Mode.SLINK:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif heading.length_squared() > 0.09:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * 0.6 * delta))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	coyote.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	coyote.rotation = Vector3(0.0, facing_yaw, 0.0)
	coyote.grounded = is_on_floor() or puppet
	coyote.tracking = mode == Mode.SNIFF
	coyote.slinking = mode == Mode.SLINK
	coyote.stalking = mode == Mode.CIRCLE
	coyote.snarling = mode in [Mode.CIRCLE, Mode.DART]
	coyote.look_at_point = _point if mode in [Mode.STARE, Mode.SHADOW, Mode.CIRCLE, Mode.CHORUS, Mode.SLINK] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Darts (low four bits) and choruses (the rest), as counts.
func net_flag() -> int:
	return (_lunges & 0x0f) | ((_choruses & 0x0f) << 4)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode in [Mode.CIRCLE, Mode.DART]
	_point = point
	var lunges := flag & 0x0f
	var choruses := (flag >> 4) & 0x0f
	if not _heard_flagged:
		_heard_flagged = true
	elif coyote:
		if lunges != (_lunges & 0x0f) and point.is_finite():
			coyote.lunge(point)
		if choruses != (_choruses & 0x0f):
			coyote.chorus(get_index() % Coyote.CHORUSES)
		if mode == Mode.CIRCLE and was != Mode.CIRCLE:
			coyote.yip()
		if mode == Mode.FLEE and was != Mode.FLEE:
			coyote.hush()
	_lunges = lunges
	_choruses = choruses


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if coyote:
		coyote.global_position = at
		coyote.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
