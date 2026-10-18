class_name MazeDog
extends MazeEnemy
## A feral dog loose in the maze, one of a pack: a tracker. It is drawn and
## moved by Dog (creatures/dog/dog.gd); this is what it thinks.
##
## THE TRAIL. Every player leaves a trail of scent on the ground behind them
## (`trails`: a crumb every couple of metres they go on foot, kept for
## `scent_life` seconds). A dog that comes across a trail (a crumb within
## `scent_range` of it) puts its nose down and follows it, crumb by crumb, the
## way the player went, at a trot (`track_speed`, slower than a run), even
## with the player long out of sight. Where the trail stops (they climbed: on
## ivy, a vine, a terrace or a wall top no scent is left on the ground, and
## the next of it may be far off) it casts about, and gives up.
## THE CHASE. When it sees or hears a player (MazeEnemy's senses), it stops
## and bays, and the pack within `alert_range` takes up the hunt; then it runs
## them down at a gallop (`chase_speed`: faster than a run, slower than a
## sprint, so sprinting gets away, and when it has lost them it goes back to
## the trail, which is fresh). Someone who stands, walks or creeps near it it
## stalks instead: stiff, low and slow, snarling.
## THE BITE. Within `lunge_range` in front of it, it gathers itself and
## springs where they are going; `caught` only if its jaws close on them (a
## jump or a dodge to one side as it springs, and it misses). A miss, and it
## stands and shakes itself before it comes on.
##
## `MazeDog.pack_of(count)` makes a pack (each a little different: which
## model, its colour, its size). Placed by MazeEnemies like the mummies.
##
## As a puppet it follows the host's news like the others; its bays, lunges
## and shakes come as counts in its flag, and are played here too.

enum Mode { ROAM, TRACK, CAST, BAY, CHASE, STALK, LUNGE, SHAKE }

## How much bigger than the model it is drawn.
const SCALE := 1.35
## How far apart the crumbs of a trail are (m), and a gap in a trail that it cannot cross by scent.
const CRUMB := 2.0
const GAP := 9.0
## The highest a crumb is laid (m above the maze's floor): anyone higher is off the ground.
const GROUND := 1.6

## Every player's trail: player -> PackedVector4Array of (where, when), oldest first.
static var trails := {}
static var _laid_frame := -1
static var _clock := 0.0

@export var roam_speed := 1.5
@export var track_speed := 3.0
@export var chase_speed := 5.2
@export var stalk_speed := 1.3
@export var acceleration := 14.0
@export var turn_rate := 9.0
@export var lunge_range := 3.2
## How near a trail must pass to be picked up, and how old it may be.
@export var scent_range := 6.0
@export var scent_life := 50.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0
@export var gravity := 24.0
## How it looks (set before it goes in; `pack_of` sets them).
@export var variant := 0
@export var coat_tint := Color.WHITE
@export var size := SCALE

var mode := Mode.ROAM
var facing_yaw := 0.0
var dog: Dog

var _radius := 0.38
var _trail_of: Node3D
## How far along each player's trail it has gone and lost it (player -> the time of the last crumb it reached).
var _spent := {}
var _crumb_time := 0.0
var _cast_left := 0.0
var _bay_left := 0.0
var _shake_left := 0.0
var _rest_left := 0.0
var _lunge_cool := 0.0
var _bit := false
var _lunges := 0
var _bays := 0
var _shakes := 0
var _point := Vector3.INF
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


## A pack of `count`, ready to be placed: each its own model, colour and size.
static func pack_of(count: int, seed_value := 0) -> Array[MazeDog]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color.WHITE, Color(1.08, 0.97, 0.88), Color(0.82, 0.82, 0.84), Color(1.02, 0.92, 0.82), Color(0.92, 0.88, 0.86)]
	var made: Array[MazeDog] = []
	for i in count:
		var one := MazeDog.new()
		one.variant = (i + rng.randi_range(0, 1)) % 2
		one.coat_tint = tints[(i + rng.randi_range(0, 4)) % tints.size()]
		one.size = SCALE * rng.randf_range(0.92, 1.06)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 40.0
	hear_range = 11.0
	memory = 6.0
	alert_range = 40.0
	pack = &"dogs"
	look_every = 0.2


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 0.8 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	dog = Dog.new()
	dog.variant = variant
	dog.coat_tint = coat_tint
	dog.low_poly = Settings.low_poly
	dog.sit_to_howl = false
	dog.scale = Vector3.ONE * size
	add_child(dog)
	dog.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	dog.global_position = global_position
	dog.rotation = Vector3(0.0, facing_yaw, 0.0)
	dog.settle()
	spotted.connect(_on_spotted)


# --- Trails ---

## Lays the players' trails (once a physics frame, whichever dog comes first).
func _lay_trails(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _laid_frame:
		return
	_laid_frame = frame
	_clock += delta
	for player: Variant in trails.keys():
		if not is_instance_valid(player):
			trails.erase(player)
	for player: Node3D in _live_players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
		# (old scent fades)
		var old := 0
		while old < trail.size() and _clock - trail[old].w > scent_life:
			old += 1
		if old > 0:
			trail = trail.slice(old)
		var at := player.global_position
		var on_foot: bool = player.get(&"state") == null or int(player.get(&"state")) <= 1
		if player.has_method(&"is_on_floor"):
			on_foot = on_foot and player.call(&"is_on_floor")
		var ground := maze.world(maze.cell_at(at)).y if maze else 0.0
		if on_foot and at.y - ground < GROUND and huntable(player):
			var last := Vector3(trail[-1].x, trail[-1].y, trail[-1].z) if not trail.is_empty() else Vector3.INF
			if not last.is_finite() or last.distance_to(at) > CRUMB:
				trail.append(Vector4(at.x, at.y, at.z, _clock))
		trails[player] = trail


## The players still in the game (a list of targets may keep one freed since:
## taken as a Node3D, a freed one is an error).
func _live_players() -> Array:
	return players().filter(func(p: Variant) -> bool: return is_instance_valid(p) and p is Node3D)


## The crumb of `player`'s trail it should make for next (INF: the trail is lost).
func _next_crumb(player: Node3D) -> Vector3:
	var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
	var here := global_position
	# What it has come to of the trail is behind it now, and so is all before it.
	for crumb in trail:
		if crumb.w > _crumb_time and Vector2(crumb.x - here.x, crumb.z - here.z).length() < 1.3:
			_crumb_time = crumb.w
	var found := Vector3.INF
	for crumb in trail:
		if crumb.w <= _crumb_time:
			continue
		var at := Vector3(crumb.x, crumb.y, crumb.z)
		if not found.is_finite():
			found = at
		# (it takes the trail as far along as it can see down it, close by)
		elif at.distance_to(here) < CRUMB * 2.5 and nav.line_free(here, at, _radius):
			found = at
		else:
			break
	if found.is_finite() and found.distance_to(here) > GAP:
		return Vector3.INF
	return found


## A trail it has come across: the player whose crumb is nearest it (fresher
## first). Scent it has followed to its end and given up on is no use to it:
## only what is newer than that (`_spent`).
func _pick_up_scent() -> bool:
	var here := global_position
	var best_score := INF
	for player: Node3D in _live_players():
		if not huntable(player):
			continue
		var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
		for crumb in trail:
			if crumb.w <= _spent.get(player, -1.0):
				continue
			var at := Vector3(crumb.x, crumb.y, crumb.z)
			var d := at.distance_to(here)
			if d > scent_range:
				continue
			var score := d + (_clock - crumb.w) * 0.1
			if score < best_score and nav.line_free(here, at, _radius * 0.5):
				best_score = score
				_trail_of = player
				_crumb_time = crumb.w - 0.001
	return best_score < INF


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_lay_trails(delta)
	_sense(delta)
	_lunge_cool -= delta
	var grounded := is_on_floor()
	var wish := Vector3.ZERO
	var speed := 0.0
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	match mode:
		Mode.LUNGE:
			var push := dog.lunge_push()
			velocity.x = push.x
			velocity.z = push.z
			if not _bit:
				for player: Node3D in _live_players():
					if huntable(player) and dog.bite_hits(player.global_position + Vector3.UP * 0.75, 0.55):
						_bit = true
						_catch(player)
						break
			if dog.lunge_stage() == Dog.Lunge.NONE:
				if _bit:
					mode = Mode.ROAM
					_rest_left = 2.0
				else:
					mode = Mode.SHAKE
					_shake_left = Dog.GATHER_TIME + DogRig.SHAKE_TIME
					_shakes += 1
					dog.shake()
			_move(delta, grounded)
			return
		Mode.SHAKE:
			_shake_left -= delta
			if _shake_left <= 0.0:
				mode = Mode.CHASE if after else Mode.ROAM
		Mode.BAY:
			_bay_left -= delta
			if _bay_left <= 0.0:
				mode = Mode.CHASE
	if mode in [Mode.SHAKE, Mode.BAY]:
		_point = after.global_position + Vector3.UP * 0.9 if after else Vector3.INF
		_steer(Vector3.ZERO, 0.0, delta, grounded)
		return
	_rest_left -= delta
	if after:
		if mode != Mode.CHASE and mode != Mode.STALK:
			mode = Mode.CHASE
		_trail_of = after
		var to := after.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		var them := Vector3(after.get(&"velocity")) if after.get(&"velocity") != null else Vector3.ZERO
		var slow := Vector2(them.x, them.z).length() < 2.0
		var seen := nav.sees(global_position + Vector3.UP, after.global_position + Vector3.UP, sight_range)
		mode = Mode.STALK if slow and seen and flat.length() < 10.0 else Mode.CHASE
		if grounded and _lunge_cool <= 0.0 and flat.length() < lunge_range * size / SCALE and absf(to.y) < 1.2 and forward.dot(flat.normalized()) > 0.75:
			_lunge(after, them)
			return
		wish = way(_radius)
		speed = stalk_speed if mode == Mode.STALK else chase_speed
		# (closing in for the bite, it goes straight at them if nothing is in the way)
		if flat.length() < 8.0 and nav.line_free(global_position, after.global_position, _radius):
			wish = flat
		_point = after.global_position + Vector3.UP * 0.9
	else:
		if mode in [Mode.CHASE, Mode.STALK]:
			# Lost them: back onto their trail, which is fresh.
			mode = Mode.TRACK if _trail_of else Mode.ROAM
		_point = Vector3.INF
		if mode == Mode.TRACK and not (is_instance_valid(_trail_of) and huntable(_trail_of)):
			mode = Mode.ROAM
		if mode == Mode.TRACK:
			var crumb := _next_crumb(_trail_of)
			if crumb.is_finite():
				var to := crumb - global_position
				wish = Vector3(to.x, 0.0, to.z) if nav.line_free(global_position, crumb, _radius) else _way_to(crumb)
				speed = track_speed
			else:
				mode = Mode.CAST
				_cast_left = 4.0
		if mode == Mode.CAST:
			# The trail has stopped: it casts about, nose down, and gives up.
			_cast_left -= delta
			if is_instance_valid(_trail_of):
				_spent[_trail_of] = _crumb_time
			if _pick_up_scent() and _next_crumb(_trail_of).is_finite():
				mode = Mode.TRACK
			elif _cast_left <= 0.0:
				mode = Mode.ROAM
				_trail_of = null
			else:
				wish = Vector3(sin(_cast_left * 1.7), 0.0, cos(_cast_left * 1.3))
				speed = 0.9
		if mode == Mode.ROAM:
			if _rest_left <= 0.0 and _pick_up_scent():
				mode = Mode.TRACK
			else:
				wish = way(_radius)
				speed = roam_speed
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_steer(wish, speed, delta, grounded)


func _way_to(point: Vector3) -> Vector3:
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


## Springs at `who`, where they will be by the time it lands.
func _lunge(who: Node3D, them: Vector3) -> void:
	mode = Mode.LUNGE
	_bit = false
	_lunges += 1
	_lunge_cool = 1.2
	_point = who.global_position + Vector3(them.x, 0.0, them.z) * (Dog.GATHER_TIME + Dog.SPRING_TIME * 0.8)
	velocity.x = 0.0
	velocity.z = 0.0
	dog.lunge(_point)


func _on_spotted(_player: Node3D) -> void:
	if puppet or mode in [Mode.LUNGE, Mode.SHAKE]:
		return
	mode = Mode.BAY
	_bay_left = 0.8
	_bays += 1
	dog.howl(0.8)


## Told by its pack: it joins the hunt without stopping to bay.
func alerted(player: Node3D, from: Vector3) -> void:
	super(player, from)
	if mode in [Mode.ROAM, Mode.TRACK, Mode.CAST]:
		mode = Mode.CHASE


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			dog.visible = not far
			dog.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				dog.settle()
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode == Mode.LUNGE:
		var way_now := dog.lunge_way()
		facing_yaw = lerp_angle(facing_yaw, atan2(way_now.x, way_now.z), 1.0 - exp(-14.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	dog.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	dog.rotation = Vector3(0.0, facing_yaw, 0.0)
	dog.grounded = is_on_floor() or puppet
	dog.tracking = mode == Mode.TRACK or mode == Mode.CAST
	dog.stalking = mode == Mode.STALK
	dog.snarling = mode in [Mode.STALK, Mode.LUNGE] or (mode == Mode.CHASE and _point.is_finite() and _point.distance_to(global_position) < 9.0)
	dog.look_at_point = _point if mode != Mode.TRACK else Vector3.INF




# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Lunges (low four bits), bays (next three) and shakes (top bit, as it changes).
func net_flag() -> int:
	return (_lunges & 0x0f) | ((_bays & 0x07) << 4) | ((_shakes & 1) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.BAY, Mode.CHASE, Mode.STALK, Mode.LUNGE]
	_point = point
	var lunges := flag & 0x0f
	var bays := (flag >> 4) & 0x07
	var shakes := (flag >> 7) & 1
	if not _heard_flagged:
		_heard_flagged = true
	elif dog:
		if lunges != (_lunges & 0x0f) and point.is_finite():
			dog.lunge(point)
		if bays != (_bays & 0x07):
			dog.howl(0.8)
		if shakes != (_shakes & 1):
			dog.shake()
	_lunges = lunges
	_bays = bays
	_shakes = shakes


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if dog:
		dog.global_position = at
		dog.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
