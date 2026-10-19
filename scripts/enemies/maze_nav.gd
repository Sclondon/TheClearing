class_name MazeNav
extends RefCounted
## Finding the way through a Maze (scripts/maze.gd) for the things that hunt in
## it, from the plan alone: no navmesh and no physics. Everything is on the
## grid of cells and the walls between them (`Maze.blocked`).
##
## - `field(goal)` is how many steps every cell is from `goal` (a breadth-first
##   walk out from it). Fields are kept for the last few goals asked for, so a
##   pack after the same player shares one.
## - `waypoint(from, goal, clearance)` is where to make for next: the furthest
##   cell along the way to `goal` that can be reached in a straight line with
##   `clearance` metres to spare from any wall's face, or `goal` itself when it can.
##   So they cut corners as far as the walls let them, not cell to cell.
## - `sees(a, b)` is a line of sight through the passages (walls are all far
##   taller than anyone), and `clear_of_walls(point, margin)` whether a point is that
##   far from every wall.
## - `wander(from, rng)` picks somewhere a few turns off to go when there is
##   nobody to go after.
##
## `avoid_clearing` (on by default) keeps them out of the clearing: they come
## to the gates of it and no further. A player in there draws them to the
## nearest gate.
##
## The walls stand on the lines between cells, as thick as MazeBuilder makes
## them (WALL_THICK, RING_THICK between rings), with a footing (FOOT.x) further
## out at their base and a pier (PIER) at each turn. Ledges and the like that
## come later do not matter here: only the plan does.

## How far apart the points tested along a line are.
const SAMPLE := 0.6
## How many goals' fields are kept (shared by everything finding its way round
## the same maze, so the field to where a boy is is worked out once for all).
const KEEP := 96

var maze: Maze
var avoid_clearing := true
## Where it wanders is kept to this ring of the square maze, its section (the
## clearing goes with ring 1): it may chase anyone out of it, but wandering it
## stays in, or heads back to `home` once out. Set by MazeEnemies.add for all but
## those that cross zones (MazeEnemy.crosses_zones). -1: anywhere.
var keep_in_ring := -1
var home := Vector2i(-1, -1)

# avoid_clearing -> {goal: field}, and the goals in the order they were worked
# out, for the newest maze only.
static var _shared := {}
static var _shared_order := {}
static var _shared_maze := 0
static var _shared_links := {}
static var _shared_halves := PackedFloat32Array()

## How many ticks a waypoint is kept for, and how far (metres) it may move meanwhile.
const REWAY_TICKS := 6
const REWAY_MOVED := 0.6
var _way := Vector3.ZERO
var _way_direct := false
var _way_key := []
var _way_tick := -100
var _way_from := Vector3.ZERO


func _init(plan: Maze = null, keep_out_of_clearing := true) -> void:
	maze = plan
	avoid_clearing = keep_out_of_clearing


## Whether one of them may be in this cell at all.
func allowed(cell: Vector2i) -> bool:
	return maze.inside(cell) and not (avoid_clearing and maze.in_clearing(cell))


## For each cell (by Maze.index), the index of the cell each of its four ways
## leads to, or -1 where a wall is or the way leads nowhere it may go: worked out
## once for the maze, so that the fields are quick to find.
func _links() -> PackedInt32Array:
	if _shared_links.has(avoid_clearing):
		return _shared_links[avoid_clearing]
	var links := PackedInt32Array()
	links.resize(maze.size * maze.size * 4)
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		for k in 4:
			var step: Vector2i = Maze.STEPS[k]
			var next := cell + step
			links[i * 4 + k] = maze.index(next) if allowed(next) and not maze.blocked(cell, step) else -1
	_shared_links[avoid_clearing] = links
	return links


## Steps from every cell to `goal` (-1 where it cannot be got to from there).
## With `avoid_clearing`, a goal in the clearing is the whole clearing, reached
## at its gates; otherwise no way goes through the clearing.
func field(goal: Vector2i) -> PackedInt32Array:
	if _shared_maze != maze.get_instance_id():
		_shared_maze = maze.get_instance_id()
		_shared = {true: {}, false: {}}
		_shared_order = {true: [], false: []}
		_shared_links = {}
		_shared_halves = PackedFloat32Array()
	var fields: Dictionary = _shared[avoid_clearing]
	if fields.has(goal):
		return fields[goal]
	var total := maze.size * maze.size
	var links := _links()
	var steps := PackedInt32Array()
	steps.resize(total)
	steps.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(total)
	var tail := 0
	if maze.inside(goal):
		if avoid_clearing and maze.in_clearing(goal):
			for i in total:
				if maze.in_clearing(Vector2i(i % maze.size, i / maze.size)):
					steps[i] = 0
					queue[tail] = i
					tail += 1
		else:
			steps[maze.index(goal)] = 0
			queue[tail] = maze.index(goal)
			tail += 1
	var head := 0
	while head < tail:
		var i := queue[head]
		head += 1
		var further := steps[i] + 1
		for k in range(i * 4, i * 4 + 4):
			var j := links[k]
			if j >= 0 and steps[j] == -1:
				steps[j] = further
				queue[tail] = j
				tail += 1
	fields[goal] = steps
	var order: Array = _shared_order[avoid_clearing]
	order.append(goal)
	if order.size() > KEEP:
		fields.erase(order.pop_front())
	return steps


## Steps from `from` to `goal` round the walls (-1: no way).
func distance(from: Vector2i, goal: Vector2i) -> int:
	if not maze.inside(from):
		return -1
	return field(goal)[maze.index(from)]


## The next cell from `from` on the way to `goal` (`from` itself if it is there, or there is no way).
func next_cell(from: Vector2i, goal: Vector2i) -> Vector2i:
	if not maze.inside(from):
		return from
	var steps := field(goal)
	var best := steps[maze.index(from)]
	var pick := from
	for step: Vector2i in Maze.STEPS:
		var next := from + step
		if not allowed(next) or maze.blocked(from, step):
			continue
		var there := steps[maze.index(next)]
		if there != -1 and (best == -1 or there < best):
			best = there
			pick = next
	return pick


## The cells from `from` to `goal`, both included ([] if there is no way).
func path(from: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var at := from
	for i in maze.size * maze.size:
		var next := next_cell(at, goal)
		if next == at:
			break
		cells.append(next)
		at = next
	if distance(from, goal) != 0 and cells.size() == 1:
		return []
	return cells


## Where to make for next, from `from` on the way to `goal`, keeping `clearance`
## metres off the walls: `goal` itself if it is in a clear straight line (and
## somewhere it may go), else the furthest of the next `look` cells along the
## way that is, else the middle of the cell it is in.
## (Worked out again only now and then, or when it has moved on or the goal has:
## it is most of what those finding their way round cost.)
func waypoint(from: Vector3, goal: Vector3, clearance: float, look := 5) -> Vector3:
	var tick := Engine.get_physics_frames()
	var key := [maze.cell_at(goal), clearance, look]
	if key == _way_key and tick - _way_tick < REWAY_TICKS and Vector2(from.x - _way_from.x, from.z - _way_from.z).length() < REWAY_MOVED:
		# (straight for the goal: for where it is now)
		return Vector3(goal.x, from.y, goal.z) if _way_direct else Vector3(_way.x, from.y, _way.z)
	_way = _waypoint(from, goal, clearance, look)
	_way_direct = Vector2(_way.x - goal.x, _way.z - goal.z).length() < 0.01
	_way_key = key
	_way_tick = tick
	_way_from = from
	return _way


func _waypoint(from: Vector3, goal: Vector3, clearance: float, look: int) -> Vector3:
	var here := maze.cell_at(from)
	var there := maze.cell_at(goal)
	goal.y = from.y
	if allowed(there) and line_free(from, goal, clearance):
		return goal
	var at := here
	var best := point(here)
	best.y = from.y
	for i in look:
		var next := next_cell(at, there)
		if next == at:
			break
		at = next
		var spot := point(at)
		spot.y = from.y
		if not line_free(from, spot, clearance):
			break
		best = spot
	# (stood in its own cell's middle already, with the next not in sight: go for the next anyway)
	if Vector2(best.x - from.x, best.z - from.z).length() < 0.3:
		var next := next_cell(here, there)
		best = point(next)
		best.y = from.y
	return best


## The middle of the open floor of `cell`, between the faces of the walls round
## it (with the walls as thick as they are, the middle of a cell beside one can
## be close to its face, or in the ledge along its foot).
func point(cell: Vector2i) -> Vector3:
	var middle := maze.world(cell)
	if not maze.inside(cell):
		return middle
	var half := Maze.CELL * 0.5
	var shift := Vector2.ZERO
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var low := -half + (_wall_half(cell, -axis) if maze.blocked(cell, -axis) else 0.0)
		var high := half - (_wall_half(cell, axis) if maze.blocked(cell, axis) else 0.0)
		if low < high:
			shift += Vector2(axis) * (low + high) * 0.5
	return middle + Vector3(shift.x, 0.0, shift.y)


## Whether a point is at least `margin` from the face of every wall, by the
## plan (a wall's face: its middle line and half its thickness; the walls
## between rings are thicker). Near a corner where any wall meets, the pier
## that stands there counts.
func clear_of_walls(point: Vector3, margin: float) -> bool:
	var cell := maze.cell_at(point)
	var middle := maze.world(cell)
	var half := Maze.CELL * 0.5
	var off := Vector2(point.x - middle.x, point.z - middle.z)
	for step: Vector2i in Maze.STEPS:
		var along := off.x * step.x + off.y * step.y
		if along > half - _wall_half(cell, step) - margin and maze.blocked(cell, step):
			return false
	# Near a corner: any wall that meets there (a pier stands at every turn).
	var pier := (MazeBuilder.WALL_THICK + MazeBuilder.PIER.x) * 0.5 + margin
	if absf(off.x) > half - pier and absf(off.y) > half - pier:
		var sx := 1 if off.x > 0.0 else -1
		var sy := 1 if off.y > 0.0 else -1
		var side := cell + Vector2i(sx, 0)
		var below := cell + Vector2i(0, sy)
		if maze.blocked(cell, Vector2i(sx, 0)) or maze.blocked(cell, Vector2i(0, sy)) \
				or (maze.inside(side) and maze.blocked(side, Vector2i(0, sy))) or (maze.inside(below) and maze.blocked(below, Vector2i(sx, 0))):
			return false
	return true


## Half the thickness of the wall (if there is one) on a cell's `step` side.
func _wall_half(cell: Vector2i, step: Vector2i) -> float:
	if not maze.inside(cell + step):
		return MazeBuilder.RING_THICK * 0.5
	if _shared_halves.is_empty() or _shared_maze != maze.get_instance_id():
		field(Vector2i.ZERO)
		_shared_halves = PackedFloat32Array()
		_shared_halves.resize(maze.size * maze.size * 4)
		for i in maze.size * maze.size:
			var at := Vector2i(i % maze.size, i / maze.size)
			for k in 4:
				_shared_halves[i * 4 + k] = _half_of(at, Maze.STEPS[k])
	return _shared_halves[maze.index(cell) * 4 + Maze.STEPS.find(step)]


# Half the thickness of that wall as the plan has it (between rings, or in a
# ring; however thick its style makes it, its middle line is what counts), and the
# step of ledge along its foot (MazeStyle.mezzanine_depth) if the ring has one.
func _half_of(cell: Vector2i, step: Vector2i) -> float:
	var great := not maze.inside(cell + step) or maze.ring_wall(cell, step)
	var half := (MazeBuilder.RING_THICK if great else MazeBuilder.WALL_THICK) * 0.5
	if maze.has_ledge(cell, step):
		half += maze.ledge_style(cell).mezzanine_depth
	return half


## Whether a straight line from `a` to `b` stays `margin` off the walls' faces.
func line_free(a: Vector3, b: Vector3, margin: float) -> bool:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var count := maxi(ceili(flat.length() / SAMPLE), 1)
	for k in count + 1:
		var point := a.lerp(b, float(k) / count)
		if not maze.inside(maze.cell_at(point)):
			return false
		if not clear_of_walls(point, margin):
			return false
	return true


## Whether there is a line of sight from `a` to `b` through the passages, no
## more than `reach` metres long (the walls are far taller than anyone).
func sees(a: Vector3, b: Vector3, reach := 1000.0) -> bool:
	if Vector2(b.x - a.x, b.z - a.z).length() > reach:
		return false
	return line_free(a, b, 0.0)


## How far from a wall's face something `radius` round must keep: its footing and `radius` more.
static func clearance_for(radius: float) -> float:
	return MazeBuilder.FOOT.x + radius


## Somewhere to go: a cell between `near` and `far` steps away by the passages
## (or the furthest there is), chosen by `rng`.
func wander(from: Vector2i, rng: RandomNumberGenerator, near := 3, far := 9) -> Vector2i:
	# (a search out to `far` steps only, not over the whole maze)
	var depth := {from: 0}
	var queue: Array[Vector2i] = [from]
	var choices: Array[Vector2i] = []
	var furthest := from
	var most := 0
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = depth[cell]
		if d >= near:
			choices.append(cell)
		if d > most:
			most = d
			furthest = cell
		if d >= far:
			continue
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if not allowed(next) or depth.has(next) or maze.blocked(cell, step):
				continue
			depth[next] = d + 1
			queue.append(next)
	if keep_in_ring >= 0:
		choices = choices.filter(in_own_ring)
		if choices.is_empty():
			# (out of its section, after a chase: back the nearest way in, or home)
			for cell: Vector2i in queue:
				if in_own_ring(cell) and cell != from:
					return cell
			return home if maze.inside(home) else from
	if choices.is_empty():
		return furthest
	return choices[rng.randi_range(0, choices.size() - 1)]


## Cells where something may be put: in a passage (not the clearing), at least
## `away` steps from the clearing, as Maze.distance counts them.
func lairs(away := 6) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if allowed(cell) and maze.distance.size() > i and maze.distance[i] >= away:
			cells.append(cell)
	return cells


## Whether a cell is a dead end (three walls round it).
func dead_end(cell: Vector2i) -> bool:
	var walls := 0
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			walls += 1
	return walls >= 3


## Forgets every field worked out (for tests timing them).
static func forget() -> void:
	_shared = {true: {}, false: {}}
	_shared_order = {true: [], false: []}


## Whether a cell is in the section its wandering is kept to (keep_in_ring).
func in_own_ring(cell: Vector2i) -> bool:
	return keep_in_ring < 0 or maxi(maze.ring_of(cell), 1) == keep_in_ring
