class_name MazeSpider
extends MazeEnemy
## The giant spider (creatures/giant_spider: GiantSpider), set to hunt the maze
## as an ambusher. This is only its thinking; how it looks and moves is the
## creature's.
##
## - IT WAITS high on a wall over a passage (`PERCH_HIGH`), head down, its legs
##   spread on the face. It is put in a cell and finds the nearest wall high
##   enough itself (rays, four ways), the first moment it is in the world.
## - IT DROPS when someone it has noticed (MazeEnemy's senses) comes within
##   `DROP_RANGE` of the foot of its wall: down on its thread, swinging out a
##   little from the face, and lands on its feet. The thread hangs a while.
## - IT CHARGES in bursts: a dash faster than a sprint (`BURST_SPEED`), a dead
##   stop (facing them, feelers up), another dash. Taken together it is a
##   little quicker than a run and slower than a sprint: whoever sprints gets
##   away, whoever only runs is caught up with.
## - IT STRIKES when they are within `STRIKE_RANGE` in front of it: it rears up
##   with its front legs raised and fangs spread (the warning, GiantSpider's
##   REAR_TIME), then lunges and bites; `caught(player)` only if a fang finds
##   them. A step aside, or running on, and it misses.
## - IT GOES BACK UP when it has lost them (`memory` runs out): to the nearest
##   wall, up it, and waits again, head down.
##
## Online, the host's thinks; a puppet follows its news (MazeEnemy), and is
## posed from what it is doing (on a wall, which wall, hanging, striking).
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeSpider.new()`, `maze` set,
## put in a passage cell beside a high wall, added to the scene.

## What it is doing, as sent (`net_state`).
enum Mode { PERCH, DROP, HUNT, STRIKE, RETURN, CLIMB }

## How high up its wall it waits.
const PERCH_HIGH := 10.0
## How near the foot of its wall someone it has noticed must come for it to drop.
const DROP_RANGE := 14.0
## Seconds from letting go to landing.
const DROP_TIME := 1.3
## How far out from the face it lands.
const LAND_OUT := 2.4
## Its dash, and how long dashes and stops last (seconds, least and most).
const BURST_SPEED := 8.0
const BURST := Vector2(0.7, 1.2)
const PAUSE := Vector2(0.3, 0.55)
const WALK_SPEED := 2.8
const CLIMB_SPEED := 3.2
const ACCELERATION := 40.0
## How near (and how square in front) they must be for it to rear and strike.
const STRIKE_RANGE := 3.6
## Its lunge, a pounce of up to five metres (how fast, over GiantSpider.STRIKE_TIME), and how far
## short of them it stops: someone walking or running from it when it rears is reached; a
## sprint is not.
const LUNGE_SPEED := 22.0
const LUNGE_TO := 1.0
## How near a fang must pass to have them.
const BITE_RADIUS := 0.85
## Its body, kept off the walls and the others.
const RADIUS := 1.2
## The walls it may climb face one of these (the maze's are square to the axes).
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

@export var gravity := 24.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 80.0

var mode := Mode.PERCH
## The creature.
var look: GiantSpider
## The wall it is on or making for: its normal (ZERO for none), the place it
## waits on it, and the foot of it on the ground.
var wall := Vector3.ZERO
var perch := Vector3.INF
var wall_foot := Vector3.INF

var _mode_time := 0.0
var _burst_left := 0.0
var _pausing := false
var _heading := Vector3.FORWARD
var _strikes := 0
var _bitten := false
var _anchor := Vector3.INF
var _anchor_left := 0.0
var _drop_from := Vector3.ZERO
var _climb_from := Vector3.ZERO
var _placed := false
var _looking_for_wall := 0.0
var _stuck := 0.0
var _far := false
var _far_check := 0.0
var _heard_count := -1


func _init() -> void:
	# (an ambusher: it sees a long way down the passages from up its wall, and
	# forgets them soon, and goes back up)
	sight_range = 40.0
	hear_range = 10.0
	memory = 9.0
	alert_range = 0.0
	pack = &"spiders"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = RADIUS
	add_child(collider)
	look = GiantSpider.new()
	look.name = "Look"
	look.size = 1.25
	look.top_level = true
	add_child(look)
	look.global_position = global_position
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	look.heading = _heading
	look.settle()


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		_follow_heard(delta)
		_pose()
		return
	if maze == null:
		return
	if not _placed:
		_placed = true
		_go_up_nearest_wall(true)
	_mode_time += delta
	_sense(delta)
	_anchor_left -= delta
	if _anchor_left <= 0.0 and mode != Mode.DROP:
		_anchor = Vector3.INF
	var before := global_position
	match mode:
		Mode.PERCH:
			velocity = Vector3.ZERO
			if _should_drop():
				_drop()
		Mode.CLIMB:
			_climb(delta)
		Mode.DROP:
			_falling()
		Mode.HUNT:
			_hunt(delta)
		Mode.STRIKE:
			_strike(delta)
		Mode.RETURN:
			_return(delta)
	chasing = mode in [Mode.DROP, Mode.HUNT, Mode.STRIKE]
	if mode in [Mode.PERCH, Mode.CLIMB, Mode.DROP]:
		# (moved by hand there: its speed, for the others to follow)
		velocity = (global_position - before) / delta
	_pose()


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Whether someone it has noticed is near enough under it to drop on. (Up on
## its wall it also watches the passage below for itself: from up there,
## MazeEnemy's line of sight starts in the face of the wall.)
func _should_drop() -> bool:
	if wall_foot.is_finite() and not hunting():
		var eye := wall_foot + Vector3.UP * 1.5
		for player: Node3D in players():
			if not huntable(player):
				continue
			var at := player.global_position
			if Vector2(at.x - wall_foot.x, at.z - wall_foot.z).length() < DROP_RANGE and absf(at.y - wall_foot.y) < 4.0 \
					and _clear_line(eye, at + Vector3.UP * 1.4):
				notice(player)
				break
	if not hunting() or not wall_foot.is_finite():
		return false
	var at := quarry.global_position
	return Vector2(at.x - wall_foot.x, at.z - wall_foot.z).length() < DROP_RANGE and absf(at.y - wall_foot.y) < 4.0


func _drop() -> void:
	# (the thread is fixed to the wall where the tip of its back body was)
	var tail := look.spinnerets()
	_anchor = tail - wall * (tail - global_position).dot(wall) + wall * 0.05
	_anchor_left = 999.0
	_drop_from = global_position
	_enter(Mode.DROP)


func _falling() -> void:
	# Out off the face, then down the thread, slowing at the end.
	var t := clampf(_mode_time / DROP_TIME, 0.0, 1.0)
	var out := smoothstep(0.0, 0.4, t)
	var down := t * t * (3.0 - 2.0 * t)
	var to := Vector3(wall_foot.x, _drop_from.y, wall_foot.z)
	var at := _drop_from.lerp(to, out)
	at.y = lerpf(_drop_from.y, wall_foot.y + 1.0, down)
	global_position = at
	velocity = Vector3.ZERO
	if t >= 1.0:
		global_position = Vector3(at.x, wall_foot.y, at.z)
		_anchor_left = 3.0
		wall = Vector3.ZERO
		if quarry:
			var to_them := quarry.global_position - global_position
			to_them.y = 0.0
			if to_them.length() > 0.1:
				_heading = to_them.normalized()
		_pausing = true
		_burst_left = 0.4
		_enter(Mode.HUNT)


func _hunt(delta: float) -> void:
	if not hunting():
		_go_up_nearest_wall()
		return
	_burst_left -= delta
	if _burst_left <= 0.0:
		_pausing = not _pausing
		var span := PAUSE if _pausing else BURST
		_burst_left = _rng.randf_range(span.x, span.y)
	var to := quarry.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < STRIKE_RANGE and absf(to.y) < 1.6 and is_on_floor() and _heading.dot(flat.normalized()) > 0.6:
		_strikes += 1
		_bitten = false
		look.rear()
		_enter(Mode.STRIKE)
		return
	var wish := Vector3.ZERO
	if not _pausing:
		var way_to := way(RADIUS)
		wish = way_to.normalized() if way_to.length() > 0.05 else Vector3.ZERO
		var push := _apart(RADIUS)
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_move(delta, wish * BURST_SPEED)
	var face := Vector3(velocity.x, 0.0, velocity.z)
	if _pausing or face.length() < 0.5:
		face = flat
	_turn(face, delta, 10.0)


func _strike(delta: float) -> void:
	if _far:
		# (nobody to see it, and the creature's clock is stopped: the strike is over)
		look.settle()
		_enter(Mode.HUNT)
		return
	var stage := look.stage()
	var wish := Vector3.ZERO
	if stage == GiantSpider.Stage.REAR and quarry:
		var flat := quarry.global_position - global_position
		flat.y = 0.0
		if look.stage_left() > 0.25:
			_turn(flat, delta, 4.0)
	elif stage == GiantSpider.Stage.STRIKE:
		var gap := LUNGE_SPEED
		if quarry:
			# (flat out, but no further than brings its fangs to them)
			gap = clampf(((quarry.global_position - global_position).dot(_heading) - LUNGE_TO) / delta, 0.0, LUNGE_SPEED)
		velocity.x = _heading.x * gap
		velocity.z = _heading.z * gap
		wish = Vector3(velocity.x, 0.0, velocity.z)
		if not _bitten:
			for player: Node3D in players():
				if not huntable(player):
					continue
				var feet := player.global_position
				if look.bites(feet + Vector3.UP * 0.1, feet + Vector3.UP * 1.3, BITE_RADIUS):
					_bitten = true
					_catch(player)
					break
	elif stage == GiantSpider.Stage.NONE:
		_pausing = true
		_burst_left = 0.3
		_enter(Mode.HUNT)
	if stage == GiantSpider.Stage.STRIKE:
		velocity.y -= gravity * delta
		move_and_slide()
	else:
		_move(delta, wish)


## Makes for the nearest wall that will do (or, at `now`, goes straight onto it, for the start).
func _go_up_nearest_wall(now := false) -> void:
	var found := _find_wall(global_position)
	if found.is_empty():
		wall = Vector3.ZERO
		wall_foot = Vector3.INF
		_looking_for_wall = 2.5
		_enter(Mode.RETURN)
		return
	perch = found[0]
	wall = found[1]
	wall_foot = found[2]
	_stuck = 0.0
	if now:
		global_position = perch
		_heading = Vector3.DOWN
		look.surface = wall
		look.heading = Vector3.DOWN
		look.global_position = perch
		look.settle()
		_enter(Mode.PERCH)
		return
	wall = Vector3.ZERO
	_enter(Mode.RETURN)


func _return(delta: float) -> void:
	if hunting():
		_pausing = false
		_burst_left = 0.2
		_enter(Mode.HUNT)
		return
	if not wall_foot.is_finite():
		# Nowhere to climb from here: wander a while and look again.
		_looking_for_wall -= delta
		var to := way(RADIUS)
		_move(delta, to.normalized() * WALK_SPEED if to.length() > 0.05 else Vector3.ZERO)
		_turn(Vector3(velocity.x, 0.0, velocity.z), delta, 6.0)
		if _looking_for_wall <= 0.0:
			_go_up_nearest_wall()
		return
	var to := wall_foot - global_position
	to.y = 0.0
	if to.length() < 0.35:
		var found := _find_wall(global_position)
		if found.is_empty():
			wall_foot = Vector3.INF
			return
		perch = found[0]
		wall = found[1]
		_climb_from = global_position
		_enter(Mode.CLIMB)
		return
	var before := global_position
	_move(delta, to.normalized() * minf(WALK_SPEED, to.length() * 3.0))
	_turn(to, delta, 6.0)
	_stuck = _stuck + delta if before.distance_to(global_position) < WALK_SPEED * delta * 0.25 else 0.0
	if _stuck > 2.0:
		_go_up_nearest_wall()


func _climb(delta: float) -> void:
	velocity = Vector3.ZERO
	if global_position.y - wall_foot.y > 3.0 and _should_drop():
		_drop()
		return
	# Onto the face (over its footing), then straight up it.
	var onto := Vector3(perch.x, wall_foot.y + 2.2, perch.z)
	if _mode_time < 0.6:
		var t := smoothstep(0.0, 0.6, _mode_time)
		global_position = _climb_from.lerp(onto, t)
	else:
		global_position = Vector3(perch.x, minf(global_position.y + CLIMB_SPEED * delta, perch.y), perch.z)
	_heading = Vector3.UP
	if global_position.y >= perch.y - 0.01:
		_heading = Vector3.DOWN
		_enter(Mode.PERCH)


func _move(delta: float, wish: Vector3) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, ACCELERATION * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _turn(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	var flat := Vector3(_heading.x, 0.0, _heading.z)
	if flat.length_squared() < 0.0001:
		flat = toward
	_heading = flat.normalized().slerp(toward.normalized(), 1.0 - exp(-rate * delta)).normalized() if flat.normalized().dot(toward.normalized()) < 0.9999 else toward.normalized()


## The nearest wall face round `from` that rises to PERCH_HIGH: [where it waits
## on it, the face's normal, the foot of it on the ground], or [].
func _find_wall(from: Vector3, reach := 30.0) -> Array:
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = [get_rid()]
	var best: Array = []
	var nearest := INF
	var ground := from.y
	for face in FACES:
		var low := Vector3(from.x, ground + 3.0, from.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + face * reach, 1, skip))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var high := Vector3(from.x, ground + PERCH_HIGH, from.z)
		var up_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(high, high + face * reach, 1, skip))
		if up_hit.is_empty() or (up_hit["position"] as Vector3).distance_to(hit["position"] as Vector3) > PERCH_HIGH:
			continue
		var d := low.distance_to(hit["position"])
		if d < nearest:
			nearest = d
			var normal := -face
			var spot: Vector3 = up_hit["position"]
			var foot: Vector3 = hit["position"]
			foot = Vector3(foot.x, ground, foot.z) + normal * LAND_OUT
			best = [spot + normal * 0.02, normal, foot]
	return best


# --- How it looks ---

## Gives the creature what it is doing.
func _pose() -> void:
	if look == null or _far:
		return
	look.global_position = global_position
	look.exclude = _skip_players()
	var on_wall := mode in [Mode.PERCH, Mode.CLIMB, Mode.DROP]
	look.surface = wall if on_wall and wall != Vector3.ZERO else Vector3.UP
	look.hanging = mode == Mode.DROP
	match mode:
		Mode.PERCH, Mode.DROP:
			look.heading = Vector3.DOWN
		Mode.CLIMB:
			look.heading = Vector3.UP
		_:
			look.heading = _heading
	look.anchor = _anchor
	look.aim = quarry.global_position + Vector3.UP if quarry and chasing else Vector3.INF


func _skip_players() -> Array[RID]:
	var skip: Array[RID] = []
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


## Out of everyone's way, it is not posed or drawn (the walls hide it).
func _cull(delta: float) -> void:
	_far_check -= delta
	if _far_check > 0.0 or look == null:
		return
	_far_check = 0.5
	var near := nearest_player(global_position)
	var far := near == null or near.global_position.distance_to(global_position) > pose_range
	if far != _far:
		_far = far
		look.visible = not far
		look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		if not far:
			_pose()
			look.settle()


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## Strikes made (low five bits), and which wall it is on (top three: 0 none, 1.. FACES).
func net_flag() -> int:
	return (_strikes & 0x1f) | ((FACES.find(wall) + 1) << 5)


func net_point() -> Vector3:
	return _anchor


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.DROP, Mode.HUNT, Mode.STRIKE]
	var face := (flag >> 5) & 7
	wall = FACES[face - 1] if face > 0 and face <= FACES.size() else Vector3.ZERO
	_anchor = point
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	var count := flag & 0x1f
	if _heard_count >= 0 and count != _heard_count and look:
		look.rear()
	_heard_count = count


## As a puppet: on the walls and in the air it is put where it is heard to be
## (gravity has no say); on the ground it walks there as MazeEnemy follows.
func _follow_heard(delta: float) -> void:
	if not _heard:
		return
	if mode in [Mode.PERCH, Mode.CLIMB, Mode.DROP]:
		_heard_at += _heard_moving * delta
		global_position = global_position.lerp(_heard_at, 1.0 - exp(-12.0 * delta))
		velocity = Vector3.ZERO
	else:
		_follow(delta)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		_pose()
		look.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4


## Whether nothing of the world stands between two points (a ray: the maze's
## plan does not know how thick each ring's walls are, the world does).
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
