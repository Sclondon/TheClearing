class_name MazeRatSwarm
extends MazeEnemy
## A swarm of rats in the maze: a few hundred of them pouring out of drains at
## the foot of a wall like a river when someone comes by, flooding along the
## hall after them over each other, streaming up anything low, and climbing
## whoever they reach. Stand in them a moment and they are all over you.
##
## What they look like and how they move is RatSwarm (creatures/rats/, a
## component that knows nothing of the maze); this is only what they think.
## This node is the swarm as the game sees it: its front (the rat nearest who
## it is after), what it is doing (`mode`), and who it is after (`quarry`).
##
## - DORMANT. Put in a cell, it finds the wall faces nearest the middle of it
##   (the back wall first, in a dead end) and opens two drains at their feet;
##   or, with no wall near, a hole in the floor. It waits there unseen until it
##   notices someone (MazeEnemy's senses: down the hall, `sight_range`, or close
##   by round a corner, `hear_range`). For `rest_time` after it has gone home
##   it does not come out again.
## - HUNT. A squealing roar comes out of the drains (the warning, about a
##   second), then out they pour after the nearest player they can get at, by
##   the passages, a little faster than a run and slower than a sprint: a
##   sprint gets away. They go up anything lower than about a metre and up the
##   feet of walls to `RatSwarm.wall_climb`; and whoever stands up at the edge of
##   a ledge over them, they pour up its front after, a river of rats up the wall
##   (`CLIMB_AFTER`; the user, 2026-10-18: "more creatures should be able to climb
##   things"). Back from the edge, on a terrace, a vine or a wall top is safe
##   (they do not run along the tops). Those that reach someone climb
##   them; sprinting or jumping shakes them off; `RatSwarm.catch_count` on at
##   once for `catch_time` and they are caught.
## - HOME. When they get no nearer for `give_up_after` seconds, or whoever they
##   were after is caught, goes into the clearing, out of the maze or further
##   than `chase_range` from the drains, they stream back in.
## - FIRE keeps them off (`fears_fire`, FireWard: a lit torch, a campfire), as
##   it does the beetles: nobody within its reach is gone after.
## - CALLED. A rat king's shriek (MazeRatKing) calls every swarm within its
##   reach: out they come (if they were in) after whoever the king is after,
##   wherever that is within `called_range` of the drains, and for `bold_time`
##   they are BOLD: faster (`bold_speed`, still short of a sprint), slower to
##   give up, and fire does not keep them off.
##
## As a puppet (online, not the host) it follows the host's news: where the
## front is, what it is doing (`net_state`), whether it is bold (`net_flag`),
## and the point the rats are making for (`net_point`: the feet of who it is
## after). The rats themselves are run here, after that point, so they look the
## same without each being sent. The drains are found from the cell it was put
## in, the same on every machine, and so are the rats (seeded by `seed_choices`).

enum Mode { DORMANT, HUNT, HOME }

## How far up a wall's face they pour after whoever is over them (RatSwarm.climb_after), m.
const CLIMB_AFTER := 26.0

## How many rats.
@export var rat_count := 240
## How many on a phone (`Settings.low_poly`, or the grass at its lowest).
@export var low_count := 140
## How far from its drains (in a straight line) it will follow someone, and, called by a king, how far.
@export var chase_range := 40.0
@export var called_range := 60.0
@export var give_up_after := 6.0
@export var rest_time := 8.0
## How long a king's call makes them bold, and how much faster they are then.
@export var bold_time := 14.0
@export var bold_speed := 1.07

var mode := Mode.DORMANT
## The rats (made the frame after it goes in, once the walls are found).
var swarm: RatSwarm
## Seconds left of being bold (a king's call).
var bold := 0.0

var _nest := Vector3.ZERO
var _swarm_seed := 0
var _rest := 0.0
var _repick := 0.0
var _prev := Vector3.ZERO
var _speed := 0.0
var _rally: Node3D
var _ways := {}
var _ways_for := Vector2i(-99999, -99999)


func _init() -> void:
	sight_range = 24.0
	hear_range = 10.0
	memory = 4.0
	pack = &"rat_swarms"
	fears_fire = true
	look_every = 0.25
	# (each rat runs up the face by itself: RatSwarm.climb_after; this is so it sees someone up on a ledge)
	climbs = Climbs.SCRAMBLE


func seed_choices(value: int) -> void:
	super(value)
	_swarm_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a flood of small bodies.
	collision_layer = 0
	collision_mask = 0
	_nest = global_position
	_prev = global_position
	_find_drains.call_deferred()


## Finds the wall faces nearest the middle of its cell, and opens a drain at the foot of each (two in all).
func _find_drains() -> void:
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
		faces.append([far - (100.0 if step == back else 0.0), hit["position"], -way])
	faces.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	swarm = RatSwarm.new()
	swarm.name = "Swarm"
	swarm.count = low_count if Settings.low_poly or Grass.quality == Grass.Quality.LOW else rat_count
	swarm.swarm_seed = _swarm_seed
	swarm.reach = called_range + 6.0
	swarm.guide = _guide
	# (up the front of a ledge after whoever stands at its edge: the highest level there is, and a little)
	swarm.climb_after = MazeRatSwarm.CLIMB_AFTER
	swarm.top_level = true
	if faces.is_empty():
		swarm.add_drain(Vector3(middle.x, ground, middle.z))
	else:
		var near: Array = faces[0]
		var along := Vector3(-(near[2] as Vector3).z, 0.0, (near[2] as Vector3).x)
		var first: Vector3 = near[1]
		var shift := 1.6 if _rng.randf() < 0.5 else -1.6
		swarm.add_drain(_foot(space, first + along * shift, near[2]), near[2])
		if faces.size() > 1 and (faces[1][0] as float) < Maze.CELL * 0.6:
			var other: Array = faces[1]
			swarm.add_drain(_foot(space, other[1], other[2]), other[2])
		else:
			swarm.add_drain(_foot(space, first - along * shift, near[2]), near[2])
	add_child(swarm)
	swarm.global_transform = Transform3D.IDENTITY
	swarm.overwhelmed.connect(_on_overwhelmed)
	_speed = swarm.speed
	_nest = swarm.drains()[0]
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


## Whether it has opened its drains (the frame after it goes in).
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
	if bold > 0.0:
		bold -= delta
		if bold <= 0.0:
			_calm()
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
			if swarm.mode == RatSwarm.Mode.DORMANT:
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
		_pick()
	var after := quarry
	if after == null:
		# (called by a king with nobody to go after: they gather round it while they are bold)
		if bold > 0.0 and is_instance_valid(_rally) and _rally.is_inside_tree():
			swarm.target = _rally.global_position
			swarm.target_moving = Vector3.ZERO
			swarm.target_grounded = true
			return
		_go_home()
		return
	if swarm.stalled > give_up_after * (2.0 if bold > 0.0 else 1.0):
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
	return Vector2(at.x - _nest.x, at.z - _nest.z).length() < (called_range if bold > 0.0 else chase_range)


## Tells the rats where `player` is.
func _aim_at(player: Node3D) -> void:
	swarm.target = player.global_position
	var moving: Variant = player.get(&"velocity")
	swarm.target_moving = moving if moving is Vector3 else Vector3.ZERO
	# (jumping or falling, or going up or down fast, shakes them off)
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


## A rat king (`king`) has shrieked: out they come, bold, after `player` (who it
## is after), or to it if it is after nobody they can get at.
func called(king: Node3D, player: Node3D) -> void:
	if puppet or swarm == null:
		return
	_embolden()
	_rally = king
	_rest = 0.0
	if player and _can_get_at(player):
		if player != quarry:
			spotted.emit(player)
			swarm.new_target()
		quarry = player
		_forget = memory
		_last_seen = player.global_position
	if mode != Mode.HUNT:
		_release()


func _embolden() -> void:
	bold = bold_time
	fears_fire = false
	swarm.speed = _speed * bold_speed


func _calm() -> void:
	bold = 0.0
	fears_fire = true
	_rally = null
	if swarm:
		swarm.speed = _speed


# Where a rat at `from` should make for on its way to `goal`: MazeNav's
# waypoint, worked out once for each cell rats are in, for the cell the goal
# is in, and kept until the goal goes into another cell.
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


## This node is the front of the swarm (or its first drain, with none out).
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


func net_flag() -> int:
	return 1 if bold > 0.0 else 0


func net_point() -> Vector3:
	return swarm.target if mode == Mode.HUNT and swarm and swarm.target.is_finite() else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNT
	if swarm:
		var was_bold := bold > 0.0
		if flag & 1 and not was_bold:
			_embolden()
		elif not (flag & 1) and was_bold:
			_calm()


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	if mode == Mode.HUNT and swarm.mode != RatSwarm.Mode.OUT and swarm.mode != RatSwarm.Mode.WARN:
		swarm.release()
	elif mode != Mode.HUNT and (swarm.mode == RatSwarm.Mode.OUT or swarm.mode == RatSwarm.Mode.WARN):
		swarm.recall()
	var point := _heard_extra
	if mode == Mode.HUNT and point.is_finite():
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
