class_name Beetles
extends MazeEnemy
## A swarm of beetles in the maze: a glossy black carpet of them that pours out
## of cracks at the foot of a wall when someone comes by, floods along the hall
## after them, laps up the feet of the walls, and runs up the legs of whoever
## it reaches. Enough of them on someone for long enough, and they are caught.
##
## What they look like and how they move is BeetleSwarm (creatures/beetle_swarm/,
## a component that knows nothing of the maze); this is only what they think.
## This node is the swarm as the game sees it: its front (the beetle nearest who
## it is after), what it is doing (`mode`), and who it is after (`quarry`).
##
## - DORMANT. Put in a cell, it finds the wall faces nearest the middle of it
##   (the back wall first, in a dead end) and opens two cracks at their feet; or,
##   with no wall near, a hole in the floor. It waits there, out of sight, until
##   it notices someone (MazeEnemy's senses: it feels them coming down the hall,
##   `sight_range`, or close by round a corner, `hear_range`). For `rest_time`
##   after it has gone home it does not come out again.
## - HUNT. Out they pour, after the nearest player it can get at (by the
##   passages from its front, keeping to the one it is after unless another is
##   a good deal nearer), along the passages (MazeNav guides each beetle round
##   the walls). They run a little faster than a run and slower than a sprint:
##   a sprint gets away. They go up the feet of walls but no higher than
##   `BeetleSwarm.wall_climb`, so getting up onto a terrace, the ivy or a vine
##   is safe. Those that reach someone run up them; sprinting or jumping shakes
##   them off; `BeetleSwarm.catch_count` on at once for `catch_time` and they
##   are caught.
## - HOME. When they get no nearer for `give_up_after` seconds, or whoever they
##   were after is caught, or goes into the clearing, out of the maze or further
##   than `chase_range` from the cracks, they stream back and go in.
##
## As a puppet (online, not the host) it follows the host's news: where the
## front of it is, what it is doing (`net_state`), and the point the beetles
## are making for (`net_point`: the feet of who it is after). The beetles
## themselves are run here, on their own, after that point (or after the player
## standing at it, if one does), so they look the same without each being sent.
## The cracks are found from the cell it was put in, the same on every machine,
## and so are the beetles (seeded by `seed_choices`).

enum Mode { DORMANT, HUNT, HOME }

## How many beetles.
@export var beetle_count := 520
## How many on a phone (`Settings.low_poly`, or the grass at its lowest).
@export var low_count := 300
## How far from its cracks (in a straight line) it will follow someone.
@export var chase_range := 38.0
@export var give_up_after := 6.0
@export var rest_time := 8.0

var mode := Mode.DORMANT
## The beetles (made the frame after it goes in, once the walls are found).
var swarm: BeetleSwarm

var _nest := Vector3.ZERO
var _swarm_seed := 0
var _rest := 0.0
var _repick := 0.0
var _prev := Vector3.ZERO
# The way each beetle is told to go, by the cell it is in, for the goal's cell (see `_guide`).
var _ways := {}
var _ways_for := Vector2i(-99999, -99999)


func _init() -> void:
	sight_range = 22.0
	hear_range = 9.0
	memory = 4.0
	pack = &"beetles"
	fears_fire = true
	look_every = 0.25


func seed_choices(value: int) -> void:
	super(value)
	_swarm_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a carpet.
	collision_layer = 0
	collision_mask = 0
	_nest = global_position
	_prev = global_position
	_find_cracks.call_deferred()


## Finds the wall faces nearest the middle of its cell, and opens a crack at the foot of each (two in all).
func _find_cracks() -> void:
	if not is_inside_tree() or swarm:
		return
	var space := get_world_3d().direct_space_state
	var ground := maze.ground_height(global_position) if maze else global_position.y
	var middle := Vector3(global_position.x, ground + 0.4, global_position.z)
	var faces: Array = []
	var back := Vector2i.ZERO
	if maze and nav.dead_end(maze.cell_at(middle)):
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(maze.cell_at(middle), step):
				back = -step
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, middle + way * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var far := middle.distance_to(hit["position"])
		# (in a dead end, the wall across its end first)
		faces.append([far - (100.0 if step == back else 0.0), hit["position"], -way])
	faces.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	swarm = BeetleSwarm.new()
	swarm.name = "Swarm"
	# (fewer on phones, with the low-poly figures or the sparse grass chosen)
	swarm.count = low_count if Settings.low_poly or Grass.quality == Grass.Quality.LOW else beetle_count
	swarm.swarm_seed = _swarm_seed
	swarm.reach = chase_range + 6.0
	swarm.guide = _guide
	swarm.top_level = true
	if faces.is_empty():
		# (no wall near, as in a bare test: a hole in the floor)
		swarm.add_crack(Vector3(middle.x, ground, middle.z))
	else:
		var near: Array = faces[0]
		var along := Vector3(-(near[2] as Vector3).z, 0.0, (near[2] as Vector3).x)
		var first: Vector3 = near[1]
		var shift := 1.4 if _rng.randf() < 0.5 else -1.4
		swarm.add_crack(_foot(space, first + along * shift, near[2]), near[2])
		if faces.size() > 1 and (faces[1][0] as float) < Maze.CELL * 0.6:
			var other: Array = faces[1]
			swarm.add_crack(_foot(space, other[1], other[2]), other[2])
		else:
			swarm.add_crack(_foot(space, first - along * shift, near[2]), near[2])
	add_child(swarm)
	swarm.global_transform = Transform3D.IDENTITY
	swarm.overwhelmed.connect(_on_overwhelmed)
	_nest = swarm.cracks()[0]
	if not puppet:
		global_position = _nest
	_prev = global_position


# The ground at the foot of a wall, just out from its face (`point`, `out` of it).
func _foot(space: PhysicsDirectSpaceState3D, point: Vector3, out: Vector3) -> Vector3:
	var at := point + out * 0.02
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + out * 0.1 + Vector3.UP * 1.0, at + out * 0.1 + Vector3.DOWN * 3.0, 1))
	if not hit.is_empty():
		at.y = (hit["position"] as Vector3).y
	return at


## Whether it has opened its cracks (the frame after it goes in).
func ready_to_go() -> bool:
	return swarm != null


func _physics_process(delta: float) -> void:
	if swarm == null:
		return
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_rest -= delta
	match mode:
		Mode.DORMANT:
			if _rest <= 0.0:
				_sense(delta)
				if hunting():
					_release()
		Mode.HUNT:
			_hunt(delta)
		Mode.HOME:
			swarm.target = Vector3.INF
			if swarm.mode == BeetleSwarm.Mode.DORMANT:
				mode = Mode.DORMANT
				_rest = rest_time
	chasing = mode == Mode.HUNT
	_place(delta)


func _release() -> void:
	mode = Mode.HUNT
	_repick = 0.0
	swarm.release()


func _hunt(delta: float) -> void:
	_repick -= delta
	if _repick <= 0.0:
		_repick = 0.4
		_pick()
	if quarry == null or not _can_get_at(quarry):
		# (whoever it was after is gone, caught or out of reach: anyone else near?)
		_pick()
	var after := quarry
	if after == null or swarm.stalled > give_up_after:
		_go_home()
		return
	_aim_at(after)


## The nearest player it can get at, by the passages from the front of it.
func _pick() -> void:
	var from := maze.cell_at(swarm.front if swarm.gap < INF else _nest)
	var best: Node3D = null
	var best_steps := 1 << 30
	for player: Node3D in players():
		if not _can_get_at(player):
			continue
		var steps := nav.distance(from, maze.cell_at(player.global_position))
		if steps < 0:
			continue
		if player == quarry:
			steps -= 2
		if steps < best_steps:
			best_steps = steps
			best = player
	if best and best != quarry:
		spotted.emit(best)
		swarm.new_target()
	quarry = best
	_forget = memory if best else 0.0


func _can_get_at(player: Node3D) -> bool:
	if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	var at := player.global_position
	return Vector2(at.x - _nest.x, at.z - _nest.z).length() < chase_range


## Tells the beetles where `player` is.
func _aim_at(player: Node3D) -> void:
	swarm.target = player.global_position
	var moving: Variant = player.get(&"velocity")
	swarm.target_moving = moving if moving is Vector3 else Vector3.ZERO
	# (jumping or falling, or going up or down fast, shakes them off: the same for
	# this machine's player and a friend's copy, whose floor is not known here)
	swarm.target_grounded = absf(swarm.target_moving.y) < 1.2


func _go_home() -> void:
	mode = Mode.HOME
	quarry = null
	_forget = 0.0
	swarm.target = Vector3.INF
	swarm.recall()


## Enough of them on who they are after: caught.
func _on_overwhelmed() -> void:
	if puppet or mode != Mode.HUNT:
		return
	if quarry and huntable(quarry):
		_catch(quarry)
	swarm.shake_off()
	_repick = 0.0


## Anything that would set others hunting someone (the bats' alarm) brings them out too.
func notice(player: Node3D) -> void:
	super(player)
	if not puppet and swarm and mode == Mode.DORMANT and hunting() and _can_get_at(player):
		_release()


# Where a beetle at `from` should make for on its way to `goal`: MazeNav's
# waypoint, worked out once for each cell beetles are in, for the cell the goal
# is in, and kept until the goal goes into another cell. (A waypoint that was
# the goal itself is kept as that, so that they follow it as it moves.)
func _guide(from: Vector3, goal: Vector3) -> Vector3:
	if maze == null:
		return goal
	var here := maze.cell_at(from)
	var there := maze.cell_at(goal)
	if here == there:
		return goal
	if there != _ways_for:
		_ways.clear()
		_ways_for = there
	var known: Variant = _ways.get(here)
	if known == null:
		var way := nav.waypoint(from, goal, MazeNav.clearance_for(0.2), 3)
		known = Vector3.INF if Vector2(way.x - goal.x, way.z - goal.z).length() < 0.1 else way
		_ways[here] = known
	return goal if not (known as Vector3).is_finite() else known


## This node is the front of the swarm (or its first crack, with none out).
func _place(delta: float) -> void:
	var want := swarm.front if swarm.gap < INF else _nest
	global_position = global_position.lerp(want, minf(delta * 10.0, 1.0))
	velocity = (global_position - _prev) / maxf(delta, 0.001)
	_prev = global_position


# --- Being run by someone else ---

func yaw() -> float:
	return 0.0


func net_state() -> int:
	return mode


func net_point() -> Vector3:
	return swarm.target if mode == Mode.HUNT and swarm and swarm.target.is_finite() else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNT


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	if mode == Mode.HUNT and swarm.mode != BeetleSwarm.Mode.OUT:
		swarm.release()
	elif mode != Mode.HUNT and swarm.mode == BeetleSwarm.Mode.OUT:
		swarm.recall()
	var point := _heard_extra
	if mode == Mode.HUNT and point.is_finite():
		# (the player standing there, if one is: theirs is a better place to be than the news's)
		var there := nearest_player(point)
		if there and there.global_position.distance_to(point) < 2.5:
			_aim_at(there)
		else:
			swarm.target = point
			swarm.target_moving = Vector3.ZERO
			swarm.target_grounded = true
	else:
		swarm.target = Vector3.INF
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-6.0 * delta))
	if global_position.distance_to(_heard_at) > 6.0:
		global_position = _heard_at


func _put(at: Vector3, _facing: float) -> void:
	global_position = at


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0
