class_name Mummy
extends MazeEnemy
## A mummy, from Outside (its scripts/mummy.gd), let loose in the maze. It goes
## about the passages at a lurching, dragging walk, never hurrying and never
## stopping, and when it has noticed someone it comes after them by the
## passages (MazeEnemy, MazeNav) for a long time; and it calls the others near
## it (`alert_range`), so that they come in numbers.
##
## It does not catch anyone by being near them. When one is within reach it
## stops, rears back with an arm raised (they have that long to get away), and
## throws the arm down and across where they stand; `caught(player)` is emitted
## only if the arm finds them. Then it hangs there a moment, overbalanced,
## before it comes on.
##
## `Mummy.new()` is a whole one: set `kind` and `maze` first. It is animated by
## MummyRig (scripts/enemies/mummy_rig.gd, Outside's, unchanged) or the rig of
## its kind, and drawn `SCALE` times as big as in Outside (`scale_up`), as the
## maze is built big.
##
## - SHAMBLER: as above.
## - PRIEST: tall and gaunt, stiff and upright on straight legs, arms crossed.
##   It bows from the hips to bring both hands down from a long way off, only
##   straight in front of it, and it is slow to turn.
## - BRUTE: squat and very heavy, knuckles at the ground. It waddles, slowly,
##   and sweeps one long arm round level at chest height (duck, and it passes
##   over); every third time both from over its head.
## - CRAWLER: from the thighs up. It hauls itself along on its arms, fast, in
##   surges, and throws itself at the ankles (jump, and it goes under).
## - CHILD: small. It scuttles in quick bursts with stops between, turns in an
##   instant and springs from close to.
## - ROYAL: masked in gold, crook and flail crossed on its chest. It glides at a
##   slow even walk and strikes as it comes, with the crook, further than any.
##
## Cut from Outside's: its niche (`reset` puts it back where it was put), burning
## oil, the target being only the boy (it is any player: MazeEnemy), and the
## models' `res://models/` path (here models/enemies/).

enum Kind { SHAMBLER, PRIEST, BRUTE, CRAWLER, CHILD, ROYAL }
## What it is doing, as sent (`net_state`).
enum Mode { DORMANT, WAKING, ABOUT, HUNTING }

## How much bigger than Outside's it is drawn and goes.
const SCALE := 1.25
## How much bigger than it is modelled Outside's first kind stands.
const SIZE := 1.3
## What each kind has of its own, as Outside has it (sizes and distances before `scale_up`).
const KINDS := {
	Kind.SHAMBLER: {"model": "mummy", "size": SIZE, "radius": 0.26, "height": 1.7, "walk_speed": 1.3, "acceleration": 9.0, "turn_rate": 3.2, "wake_time": 1.8,
		"reach_distance": 1.4, "catch_distance": 0.4, "lunge_speed": 2.4, "lunge_to": 0.8, "step_up": 0.3, "drop": 1.0, "stand_off": 0.5, "presses_on": false},
	Kind.PRIEST: {"model": "mummy_priest", "size": 1.4, "radius": 0.24, "height": 2.0, "walk_speed": 1.35, "acceleration": 6.0, "turn_rate": 1.5, "wake_time": 2.4,
		"reach_distance": 1.8, "catch_distance": 0.4, "lunge_speed": 3.2, "lunge_to": 1.15, "step_up": 0.0, "drop": 0.5, "stand_off": 0.5, "presses_on": false},
	Kind.BRUTE: {"model": "mummy_brute", "size": 1.45, "radius": 0.42, "height": 1.6, "walk_speed": 0.95, "acceleration": 5.0, "turn_rate": 2.2, "wake_time": 2.6,
		"reach_distance": 1.75, "catch_distance": 0.34, "lunge_speed": 3.0, "lunge_to": 0.85, "step_up": 0.3, "drop": 1.0, "stand_off": 0.6, "presses_on": false},
	Kind.CRAWLER: {"model": "mummy_crawler", "size": 1.3, "radius": 0.3, "height": 0.7, "walk_speed": 2.3, "acceleration": 14.0, "turn_rate": 4.5, "wake_time": 1.2,
		"reach_distance": 1.6, "catch_distance": 0.34, "lunge_speed": 4.5, "lunge_to": 0.75, "step_up": 0.0, "drop": 100.0, "stand_off": 0.6, "presses_on": false},
	Kind.CHILD: {"model": "mummy_child", "size": 1.0, "radius": 0.2, "height": 0.95, "walk_speed": 2.9, "acceleration": 40.0, "turn_rate": 9.0, "wake_time": 1.0,
		"reach_distance": 1.0, "catch_distance": 0.34, "lunge_speed": 3.2, "lunge_to": 0.35, "step_up": 0.5, "drop": 2.0, "stand_off": 0.4, "presses_on": false},
	Kind.ROYAL: {"model": "mummy_royal", "size": 1.4, "radius": 0.26, "height": 1.95, "walk_speed": 0.8, "acceleration": 4.0, "turn_rate": 1.3, "wake_time": 3.0,
		"reach_distance": 2.3, "catch_distance": 0.4, "lunge_speed": 0.0, "lunge_to": 0.8, "step_up": 0.3, "drop": 0.6, "stand_off": 1.2, "presses_on": true},
}
## Use the low-poly models (`_lo`) for every mummy, as Settings.low_poly does.
static var low_poly := false

## Which kind of mummy it is. Setting it gives every number below that kind's
## own value; set it before the mummy goes into the scene.
@export var kind := Kind.SHAMBLER:
	set(value):
		kind = value
		for key: String in KINDS[kind]:
			if key not in ["model", "size", "radius", "height"]:
				set(key, KINDS[kind][key])

## How much bigger than Outside's (it scales the body, its reach and its stride).
@export var scale_up := SCALE
## Its speed taken over a whole step (times `scale_up`, and `pace_up`).
@export var walk_speed := 1.3
## How much faster than Outside's it goes, beyond being bigger.
@export var pace_up := 1.0
@export var acceleration := 9.0
@export var turn_rate := 3.2
## Seconds between being disturbed and starting to walk (when it starts dormant).
@export var wake_time := 1.8
## How near they must be for it to swipe at them (times `scale_up`).
@export var reach_distance := 1.4
## How near the sweeping arm must pass to have them (times `scale_up`).
@export var catch_distance := 0.4
## How fast it throws itself forward as the arm comes down, and how near that may bring it.
@export var lunge_speed := 2.4
@export var lunge_to := 0.8
## The highest thing it can step up onto, and the furthest it will step down.
@export var step_up := 0.3
@export var drop := 1.0
## How near it comes before it stands and waits to strike.
@export var stand_off := 0.5
## Whether it goes on walking while it strikes.
@export var presses_on := false
@export var gravity := 24.0
## Stands dead, arms crossed, until it notices someone (else it is about from the start).
@export var start_dormant := false
## Further than this from every player it stops posing itself (it is out of sight behind the walls anyway).
@export var pose_range := 70.0

## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
var visual_position := Vector3.ZERO
## Only here so the shared rig can tell a walk from a run; it never runs.
var run_speed := 5.0
var is_pushing := false
var mode := Mode.ABOUT

var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _waking := 0.0
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _rig: MummyRig
var _swipes := 0
var _has_him := false
var _turning := true
var _radius := 0.3
var _far := false
var _far_check := 0.0


func _init() -> void:
	# (the senses of a mummy: it notices nearer than the snake, but never lets go)
	sight_range = 50.0
	hear_range = 7.0
	memory = 40.0
	alert_range = 36.0
	pack = &"mummies"


func _ready() -> void:
	add_to_group(&"pursuers")
	# Players pass through it; the world stops it, and so do the others (layer 4)
	# where it is thinking for itself, so that a pack does not stand in one place.
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3

	var own: Dictionary = KINDS[kind]
	var shape := CapsuleShape3D.new()
	_radius = own["radius"] * scale_up
	shape.radius = _radius
	shape.height = own["height"] * scale_up
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)

	match kind:
		Kind.PRIEST:
			_rig = MummyPriestRig.new()
		Kind.BRUTE:
			_rig = MummyBruteRig.new()
		Kind.CRAWLER:
			_rig = MummyCrawlerRig.new()
		Kind.CHILD:
			_rig = MummyChildRig.new()
		Kind.ROYAL:
			_rig = MummyRoyalRig.new()
		_:
			_rig = MummyRig.new()
	var low := low_poly or Settings.low_poly
	_rig.model = load("res://models/enemies/%s%s.glb" % [own["model"], "_lo" if low else ""])
	add_child(_rig)
	_rig.top_level = true
	_rig.scale = Vector3.ONE * own["size"] * scale_up

	_spawn = global_transform
	reset()


## Disturbs a dormant one: nothing happens for `wake_time`, then it comes.
func wake() -> void:
	if mode == Mode.DORMANT:
		mode = Mode.WAKING
		_waking = wake_time


func is_awake() -> bool:
	return mode != Mode.DORMANT


## Back where it was put, and as it was at the start.
func reset() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	chasing = false
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	mode = Mode.DORMANT if start_dormant else Mode.ABOUT
	_waking = 0.0
	facing_yaw = _spawn.basis.get_euler().y
	_turning = true
	_prev_pos = global_position
	_curr_pos = global_position
	visual_position = global_position
	_rig.awake = 1.0 if is_awake() else 0.0
	_rig.arms_reach = 0.0
	_rig.aim = Vector3.INF
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)
	_rig.settle()


func _speed() -> float:
	return walk_speed * scale_up * pace_up


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	if mode == Mode.DORMANT:
		if quarry:
			wake()
	if mode == Mode.WAKING:
		_waking -= delta
		if _waking <= 0.0:
			mode = Mode.ABOUT
	var awake := mode == Mode.ABOUT or mode == Mode.HUNTING
	if awake:
		mode = Mode.HUNTING if hunting() else Mode.ABOUT
	chasing = mode == Mode.HUNTING

	var grounded := is_on_floor()
	_detour_time -= delta
	var wish := Vector3.ZERO
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var after := quarry if chasing and quarry and quarry.get(&"is_limp") != true else null
	var lunging := false
	_turning = true
	var reach := reach_distance * scale_up
	match _rig.stage():
		MummyRig.Stage.NONE:
			if awake:
				var to := after.global_position - global_position if after else Vector3.INF
				var flat := Vector3(to.x, 0.0, to.z) if after else Vector3.INF
				if after and grounded and flat.length() < reach and absf(to.y) < 1.2 * scale_up and (forward.dot(flat.normalized()) > 0.8 or flat.length() < 0.6 * scale_up):
					# Left, right, and every third time both.
					_swipes += 1
					_has_him = false
					_rig.swipe(2 if _swipes % 3 == 0 else _swipes % 2)
				elif not after or flat.length() > stand_off * scale_up:
					wish = _route()
					if grounded and wish != Vector3.ZERO:
						wish = _negotiate(wish)
		MummyRig.Stage.WIND_UP:
			# It follows them round as it rears back, but not to the last.
			_turning = _rig.strikes_in() > 0.2
		MummyRig.Stage.STRIKE:
			_turning = false
			lunging = grounded and lunge_speed > 0.0 and _negotiate(forward) != Vector3.ZERO
			if not _has_him:
				var found := _finds_one()
				if found:
					_has_him = true
					_catch(found)
		_:
			_turning = false
	if presses_on and after and grounded and _rig.stage() != MummyRig.Stage.NONE:
		var to_him := after.global_position - global_position
		to_him.y = 0.0
		if to_him.length() > stand_off * scale_up:
			wish = _negotiate(_route())

	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * _speed() * _rig.pace(), acceleration * scale_up * delta)
	if lunging:
		# (as far as will bring its arm to them, and no further)
		var gap := lunge_speed * scale_up * _rig.swipe_strike
		if after:
			gap = clampf((after.global_position - global_position).dot(forward) - lunge_to * scale_up, 0.0, gap)
		current = forward * gap / _rig.swipe_strike
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Which way to go: by the passages to whoever it is after, or wherever it is wandering; and a little apart from the others.
func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


## The player a sweeping arm passes through now, if any.
func _finds_one() -> Node3D:
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		if feet.distance_to(global_position) > reach_distance * scale_up + 2.0:
			continue
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var top := feet + Vector3.UP * (0.65 if low else 1.1)
		for arm in _rig.claws():
			var nearest := Geometry3D.get_closest_points_between_segments(arm[0], arm[1], feet + Vector3.UP * 0.1, top)
			if nearest[0].distance_to(nearest[1]) < catch_distance * scale_up:
				return player
	return null


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	# Out of everyone's way, it is not posed (the walls hide it).
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			_rig.visible = not far
			_rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var after: Node3D = null
	var aim := Vector3.INF
	if puppet:
		if _heard_extra.is_finite():
			aim = _heard_extra
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	else:
		after = quarry if chasing else null
		if after and after.get(&"is_limp") != true:
			aim = after.global_position + Vector3.UP * 0.8
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if after and (heading.length_squared() < 0.05 or _rig.stage() != MummyRig.Stage.NONE):
			heading = after.global_position - global_position
			heading.y = 0.0
		if is_awake() and _turning and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	_rig.awake = 1.0 if is_awake() else 0.0
	_rig.arms_reach = lerpf(_rig.arms_reach, 1.0 if aim.is_finite() else 0.0, 1.0 - exp(-2.5 * delta))
	_rig.aim = aim
	_rig.global_position = visual_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


## Deals with what is in the way. Returns the direction to walk.
func _negotiate(wish: Vector3) -> Vector3:
	# It will not step into a drop (unless it is one that goes over anything).
	var ahead := global_position + wish * 0.7 * scale_up
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.6, ahead + Vector3.DOWN * drop * scale_up, 1)
	if drop < 50.0 and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return Vector3.ZERO

	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, wish * 0.25, hit) or hit.get_normal().y > 0.6:
		if _detour_time > 0.0:
			return (wish * 0.5 + _detour).normalized()
		return wish
	# A kerb: step up onto it, if it can step that high.
	var rise := minf(step_up * scale_up, 0.3)
	while rise > 0.0 and rise <= step_up * scale_up + 0.001:
		var raised := global_transform.translated(Vector3.UP * (rise + 0.02))
		if not test_move(global_transform, Vector3.UP * (rise + 0.02)) and not test_move(raised, wish * 0.3):
			global_position += Vector3.UP * rise + wish * 0.12
			return wish
		rise += 0.2
	# Anything taller: slide along it, keeping to one side for a moment.
	if _detour_time <= 0.0:
		var normal := hit.get_normal()
		_detour = Vector3(-normal.z, 0.0, normal.x)
		if _detour.dot(wish) < 0.0:
			_detour = -_detour
	_detour_time = 0.9
	return (wish * 0.3 + _detour).normalized()


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## The swipes it has made (low six bits) and with which arm (top two).
func net_flag() -> int:
	return (_swipes & 0x3f) | ((_rig._swipe_arm & 3) << 6) if _rig else 0


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 0.8
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNTING
	# A new swipe: it is made here too (the catching is not: that is the other machine's).
	var count := flag & 0x3f
	if not _heard_swiped:
		_heard_swiped = true
		_swipes = count
	elif count != (_swipes & 0x3f):
		_swipes = count
		if _rig:
			_rig.swipe(flag >> 6)


var _heard_swiped := false


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if _rig:
		_rig.global_position = at
		_rig.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
