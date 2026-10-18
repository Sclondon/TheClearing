class_name MazeDeer
extends MazeEnemy
## A white-tailed deer, one of a herd (`herd_of`) that stands in the halls. It
## is drawn and moved by Deer (creatures/deer/deer.gd); this is what it thinks.
## It does not hunt anyone. It watches, and it runs.
##
## GRAZING, the herd drifts about its patch, heads down.
## WATCHING. When one of them sees or hears a player, every head in the herd
## comes up and turns to them, and they freeze, staring, for as long as the
## player is in sight; their eyes give back the light.
## CREEPING. While a player who is being watched looks away (the camera, for
## the player on this machine; the way they face, for others), the herd walks
## towards them, slowly, and stops dead the moment they look back. It comes no
## nearer than `near_range`. Look away, look back: they are a little closer.
## THE BOLT. Too near (`startle_range`), or running at them (`rush_range`), or
## heard close by, and one snorts and stamps, every tail goes up white
## (ALARM, `alarm_time`); they stot off on stiff legs for a few bounds
## (PRONK), then break into a full gallop (STAMPEDE) down the passages, as far
## as they can get from whoever frightened them. Where the only way out is
## past the player (the herd in a dead end, the player in its mouth), the
## stampede comes straight back down the hall at them.
## KNOCKED DOWN. Anyone a running deer runs into (within `trample_radius`) is
## knocked flat: `caught`. The alarm and the stotting are the warning (nearly
## two seconds); stand aside, against a wall, in a slot, up the ivy.
## After a stampede the herd stands, blowing, then settles to watching again.
##
## THE WRONG ONE. A herd of four or more has one in it that is not a deer
## (`wrong`): legs a little too long, a head that turns round further than a
## neck should. Watching a player, now and then it stands up on its hind legs
## and takes a step towards them. When the herd bolts it does not go with
## them. It stays where it was, watching the player, and walks after them on
## its own. It never runs and it catches nobody.
##
## As a puppet it follows the host's news like the others; snorts, stamps and
## standing up come in its flag.

enum Mode { GRAZE, WATCH, CREEP, ALARM, PRONK, STAMPEDE, SETTLE }

## How fast it goes about its patch, creeps up, stots, and stampedes (m/s).
@export var graze_speed := 0.6
@export var creep_speed := 1.1
@export var pronk_speed := 2.6
@export var stampede_speed := 8.5
@export var acceleration := 9.0
@export var turn_rate := 6.0
## How near a player may come before it bolts, how near one running at it, and the nearest it creeps up.
@export var startle_range := 9.0
@export var rush_range := 18.0
@export var near_range := 12.0
## How far it runs, at most (m by the passages).
@export var flee_range := 60.0
## How near a running deer must pass a player to knock them down (m, at a scale of 1).
@export var trample_radius := 0.8
## Seconds of alarm before the bolt, and of stotting before the gallop.
@export var alarm_time := 0.75
@export var pronk_time := 1.1
## Further than this from every player it is not posed.
@export var pose_range := 75.0
@export var gravity := 24.0
## How it looks (set before it goes in; `herd_of` sets them).
@export var variant := Deer.Variant.DOE
@export var coat_tint := Color.WHITE
@export var size := 1.0
@export var wrong := 0.0
## Which herd it is in (those of one herd go together).
@export var herd_id := 0

var mode := Mode.GRAZE
var facing_yaw := 0.0
var deer: Deer

var _radius := 0.35
var _home := Vector3.ZERO
var _mode_left := 0.0
var _flee_to := Vector3.INF
var _fled := 0.0
var _point := Vector3.INF
var _graze_goal := Vector3.INF
var _graze_left := 0.0
var _rise_in := 10.0
var _upright_left := 0.0
var _knocked := {}
var _snorts := 0
var _stamps := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false

static var _herds := 0


## A herd of `count`, ready to be placed: does, a buck now and then, each its
## own colour and size; one of four or more is wrong.
static func herd_of(count: int, seed_value := 0) -> Array[MazeDeer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_herds += 1
	var tints := [Color.WHITE, Color(1.05, 1.0, 0.95), Color(0.92, 0.92, 0.92), Color(0.97, 0.94, 0.9), Color(1.04, 0.98, 0.92)]
	var odd := rng.randi_range(1, count - 1) if count >= 4 else -1
	var made: Array[MazeDeer] = []
	for i in count:
		var one := MazeDeer.new()
		one.herd_id = _herds * 1000 + (seed_value & 0xff)
		one.variant = Deer.Variant.BUCK if i == 0 and rng.randf() < 0.6 else Deer.Variant.DOE
		one.coat_tint = tints[(i + rng.randi_range(0, 4)) % tints.size()]
		one.size = rng.randf_range(0.92, 1.05) * (1.05 if one.variant == Deer.Variant.BUCK else 1.0)
		one.wrong = 1.0 if i == odd else 0.0
		made.append(one)
	return made


func _init() -> void:
	sight_range = 46.0
	hear_range = 8.0
	memory = 8.0
	alert_range = 30.0
	pack = &"deer"
	look_every = 0.2
	spare_time = 4.0


func _ready() -> void:
	collision_layer = 0 if puppet else 4
	# (a herd runs through itself: only the walls stop it)
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.32 * size
	shape.radius = _radius
	shape.height = 1.1 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	deer = Deer.new()
	deer.variant = variant
	deer.coat_tint = coat_tint
	deer.wrong = wrong
	deer.low_poly = Settings.low_poly
	deer.fur_shells = 0 if Settings.low_poly else 1
	deer.scale = Vector3.ONE * size
	add_child(deer)
	deer.top_level = true
	facing_yaw = rotation.y
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	deer.global_position = global_position
	deer.rotation = Vector3(0.0, facing_yaw, 0.0)
	deer.settle()
	_rise_in = _rng.randf_range(8.0, 16.0)
	spotted.connect(_on_spotted)


## The others of its herd.
func herd() -> Array[MazeDeer]:
	var mates: Array[MazeDeer] = []
	if not is_inside_tree():
		return mates
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other != self and other is MazeDeer and (other as MazeDeer).herd_id == herd_id:
			mates.append(other)
	return mates


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
	var wish := Vector3.ZERO
	var speed := 0.0
	var who := quarry if hunting() else null
	_mode_left -= delta
	_upright_left -= delta
	if who and mode in [Mode.GRAZE, Mode.SETTLE] and _mode_left <= 0.0:
		mode = Mode.WATCH
	match mode:
		Mode.GRAZE:
			_point = Vector3.INF
			_graze_left -= delta
			if _graze_left <= 0.0:
				_graze_left = _rng.randf_range(4.0, 9.0)
				var round_about := _rng.randf_range(0.0, TAU)
				var goal := _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, 3.5)
				_graze_goal = goal if nav.line_free(global_position, goal, _radius) and _rng.randf() < 0.6 else Vector3.INF
			if _graze_goal.is_finite() and Vector2(_graze_goal.x - global_position.x, _graze_goal.z - global_position.z).length() > 0.5:
				wish = _graze_goal - global_position
				speed = graze_speed
		Mode.WATCH, Mode.CREEP:
			if who == null:
				mode = Mode.GRAZE
			else:
				_point = who.global_position + Vector3.UP * 1.0
				if _startled_by(who):
					_raise_alarm(who)
				elif wrong > 0.0:
					wish = _wrong_one(who, delta)
					speed = creep_speed * 0.5
				else:
					var far := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
					mode = Mode.CREEP if not _watched_by(who) and far > near_range else Mode.WATCH
					if mode == Mode.CREEP:
						wish = way(_radius)
						speed = creep_speed
		Mode.ALARM:
			if _mode_left <= 0.0:
				mode = Mode.PRONK
				_mode_left = pronk_time
		Mode.PRONK:
			wish = _way_on()
			speed = pronk_speed
			if _mode_left <= 0.0:
				mode = Mode.STAMPEDE
		Mode.STAMPEDE:
			wish = _way_on()
			speed = stampede_speed
			_fled += Vector2(velocity.x, velocity.z).length() * delta
			if _fled > flee_range or not _flee_to.is_finite() or Vector2(_flee_to.x - global_position.x, _flee_to.z - global_position.z).length() < 2.5:
				mode = Mode.SETTLE
				_mode_left = 4.0
				_home = global_position
		Mode.SETTLE:
			_point = Vector3.INF
			if _mode_left <= 0.0:
				mode = Mode.GRAZE
	if mode in [Mode.PRONK, Mode.STAMPEDE]:
		_trample()
	var push := _apart(_radius) * (0.4 if mode == Mode.STAMPEDE else 1.0)
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	elif push != Vector3.ZERO and mode in [Mode.GRAZE, Mode.SETTLE]:
		wish = push
		speed = graze_speed
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta * (1.6 if mode == Mode.WATCH else 1.0))
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whether `who` frightens it: too near, running at it, or heard.
func _startled_by(who: Node3D) -> bool:
	var to := who.global_position - global_position
	var far := Vector2(to.x, to.z).length()
	if far < startle_range * size:
		return true
	var them: Vector3 = who.get(&"velocity") if who.get(&"velocity") != null else Vector3.ZERO
	var running := Vector2(them.x, them.z).length() > 3.6
	var at_it := Vector2(them.x, them.z).normalized().dot(Vector2(-to.x, -to.z).normalized()) > 0.5
	return running and at_it and far < rush_range


## Whether `who` is looking its way: the camera, for the player on this
## machine; the way they face, for anyone else.
func _watched_by(who: Node3D) -> bool:
	var to := global_position + Vector3.UP * 0.9 - who.global_position - Vector3.UP * 1.2
	var forward := Vector3.ZERO
	if who == local_player() and is_inside_tree() and get_viewport().get_camera_3d():
		forward = -get_viewport().get_camera_3d().global_basis.z
	else:
		var facing: Variant = who.get(&"facing_yaw")
		var yaw_now: float = facing if facing != null else who.global_rotation.y
		forward = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
	forward.y = 0.0
	to.y = 0.0
	return forward.normalized().dot(to.normalized()) > 0.55


## It snorts, stamps, and the herd bolts with it (after a moment each), away from `who`.
func _raise_alarm(who: Node3D) -> void:
	var to := _flee_from(who)
	_bolt(to, 0.0)
	_snorts += 1
	_stamps += 1
	deer.snort()
	deer.stamp()
	for mate in herd():
		if not mate.puppet and mate.mode in [Mode.GRAZE, Mode.WATCH, Mode.CREEP, Mode.SETTLE]:
			mate._bolt(to, _rng.randf_range(0.0, 0.25))


func _bolt(to: Vector3, late: float) -> void:
	if wrong > 0.0:
		# (the wrong one does not run)
		mode = Mode.WATCH
		_upright_left = 2.6
		return
	mode = Mode.ALARM
	_mode_left = alarm_time + late
	_flee_to = to
	_fled = 0.0
	_knocked.clear()


## Where to run from `who`: the passage cell a few cells off that is furthest
## from them by the passages, for how near it is. When the only way out goes
## past them, that is where it is.
func _flee_from(who: Node3D) -> Vector3:
	var here := maze.cell_at(global_position)
	var mine := nav.field(here)
	var theirs := nav.field(maze.cell_at(who.global_position))
	var best := Vector3.INF
	var score := -INF
	for i in mine.size():
		var steps := mine[i]
		if steps < 2 or steps > 5:
			continue
		var cell := Vector2i(i % maze.size, i / maze.size)
		var from_them := theirs[i] if theirs[i] >= 0 else 99
		var value := from_them - steps * 0.3 + _rng.randf_range(0.0, 0.4)
		if value > score:
			score = value
			best = maze.world(cell)
	return best


## The way on to where it is running.
func _way_on() -> Vector3:
	if not _flee_to.is_finite():
		return Vector3.ZERO
	var to := nav.waypoint(global_position, _flee_to, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


## Knocks down anyone it runs into.
func _trample() -> void:
	if Vector2(velocity.x, velocity.z).length() < 2.0:
		return
	for player: Node3D in players():
		if not huntable(player) or _knocked.has(player):
			continue
		var to := player.global_position - global_position
		if absf(to.y) < 1.4 and Vector2(to.x, to.z).length() < trample_radius * size + 0.25:
			_knocked[player] = true
			_catch(player)


## The wrong one, watching: it turns to them, and now and then stands up and
## takes a step their way.
func _wrong_one(who: Node3D, delta: float) -> Vector3:
	_rise_in -= delta
	var far := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
	if _rise_in <= 0.0 and _watched_by(who) and far < 32.0:
		_rise_in = _rng.randf_range(10.0, 18.0)
		_upright_left = 2.8
		_stamps += 1
	if _upright_left > 0.0 and far > 4.0:
		var to := who.global_position - global_position
		return Vector3(to.x, 0.0, to.z)
	# (it follows, slowly, when it is not looked at)
	if not _watched_by(who) and far > near_range * 0.6:
		return way(_radius)
	return Vector3.ZERO


func _on_spotted(player: Node3D) -> void:
	if puppet or mode not in [Mode.GRAZE, Mode.SETTLE]:
		return
	mode = Mode.WATCH
	for mate in herd():
		if not mate.puppet and mate.mode == Mode.GRAZE:
			mate.notice(player)


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			deer.visible = not far
			deer.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				deer.settle()
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif heading.length_squared() > 0.09:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite():
		# (frozen, it turns its body only when its head can turn no further: the head does the watching)
		var to := _point - global_position
		var off := absf(angle_difference(facing_yaw, atan2(to.x, to.z)))
		if (wrong <= 0.0 and (mode != Mode.WATCH or off > 1.3)) or off > 2.9:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-(0.7 if mode == Mode.WATCH else 1.5) * delta))
	deer.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	deer.rotation = Vector3(0.0, facing_yaw, 0.0)
	deer.grounded = is_on_floor() or puppet
	deer.grazing = mode == Mode.GRAZE and heading.length() < 0.3
	deer.alert = mode in [Mode.WATCH, Mode.CREEP, Mode.ALARM]
	deer.flagging = mode in [Mode.ALARM, Mode.PRONK, Mode.STAMPEDE]
	deer.fleeing = mode == Mode.STAMPEDE
	deer.pronking = mode == Mode.PRONK
	deer.upright = _upright_left > 0.0
	deer.look_at_point = _point if mode in [Mode.WATCH, Mode.CREEP, Mode.ALARM] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Snorts (low two bits), stamps (next two), standing up (bit 4).
func net_flag() -> int:
	return (_snorts & 3) | ((_stamps & 3) << 2) | ((1 if _upright_left > 0.0 else 0) << 4)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	_point = point
	var snorts := flag & 3
	var stamps := (flag >> 2) & 3
	_upright_left = 0.5 if (flag >> 4) & 1 else 0.0
	if not _heard_flagged:
		_heard_flagged = true
	elif deer:
		if snorts != (_snorts & 3):
			deer.snort()
		if stamps != (_stamps & 3):
			deer.stamp()
	_snorts = snorts
	_stamps = stamps


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if deer:
		deer.global_position = at
		deer.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
