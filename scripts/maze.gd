@tool
class_name Maze
extends RefCounted
## The maze: a great open clearing in the middle, and round it rings of maze, one
## outside the other, each walled off from the next but for one gate. The first
## ring has four ways in from the clearing; each ring after it is entered by the
## gate out of the ring inside it. It is only the plan: walls, the clearing, the
## gates. MazeBuilder (scripts/maze_builder.gd) puts it up in the world.
##
## RINGS says how big the clearing and every ring will be. `rings` is how many of
## them are built: the grid only runs to the outside of the last one built, and
## the way out of that one is `exit`. (For now only the first ring is built.)
##
## The same seed always gives the same maze, which is how everyone in a room gets
## the same one without it being sent: the seed comes from the room's code and
## the round (see seed_for).
##
## Cells are (x, y), 0 to size - 1, y running south (+Z in the world). Walls sit
## on the edges between cells: `east[i]` is the wall on cell i's east side and
## `south[i]` on its south side, with i = x + y * size. The outer wall on the west
## and north is implied, and is solid except at `exit`.

## Metres across one cell, from the middle of one wall to the middle of the next.
const CELL := 14.0
## Cells across the clearing, and then across the outside of each ring, from the
## middle out. All odd, so each has a middle cell.
const RINGS: Array[int] = [7, 15, 23, 31]

var size := 15
## Cells along a side of the clearing.
var clearing := 7
## How many rings are built.
var rings := 1
var maze_seed := 0
var east := PackedByteArray()
var south := PackedByteArray()
## For each ring built (ring 1 is gates[0]), the ways into it from the ring inside
## it, as [cell inside it, the step into it]; and the way out of it into the next.
var gates: Array = []
var exits: Array = []
## The cell on the outer edge that leads out, and which way out is from it.
var exit := Vector2i.ZERO
var exit_side := Vector2i.ZERO
## Steps from the clearing to every cell (-1 inside the clearing).
var distance := PackedInt32Array()


## A seed for a room's maze on a given round: the same on every copy of the game.
static func seed_for(code: String, round_number: int) -> int:
	return hash("%s/%d" % [code, round_number]) & 0x7fffffff


## Makes the maze for `seed_value`, with `built` rings round the clearing.
## `loops` is the share of dead walls in each ring knocked through afterwards, so
## that there is more than one way round.
static func generate(seed_value: int, built := 1, loops := 0.06) -> Maze:
	var maze := Maze.new()
	maze.rings = clampi(built, 1, RINGS.size() - 1)
	maze.size = RINGS[maze.rings]
	maze.clearing = RINGS[0]
	maze.maze_seed = seed_value
	maze._carve(loops)
	return maze


func index(cell: Vector2i) -> int:
	return cell.x + cell.y * size


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


## Which ring a cell is in: 0 for the clearing, 1 for the first ring round it, and
## so on (past the last of RINGS, RINGS.size()). Cells outside the grid are in the
## rings that are not built yet.
func ring_of(cell: Vector2i) -> int:
	var middle := size / 2
	var across := maxi(absi(cell.x - middle), absi(cell.y - middle)) * 2 + 1
	for ring in RINGS.size():
		if across <= RINGS[ring]:
			return ring
	return RINGS.size()


func in_clearing(cell: Vector2i) -> bool:
	return ring_of(cell) == 0


## Whether the wall between `cell` and its neighbour the `step` way divides one
## ring from another (the clearing's wall included). These are the great walls.
func ring_wall(cell: Vector2i, step: Vector2i) -> bool:
	return ring_of(cell) != ring_of(cell + step)


## Whether there is a wall between `cell` and its neighbour the `step` way
## (a unit step). The outer edge is a wall, except at the exit.
func blocked(cell: Vector2i, step: Vector2i) -> bool:
	var other := cell + step
	if not inside(other):
		return not (cell == exit and step == exit_side)
	if step.x == 1:
		return east[index(cell)] == 1
	if step.x == -1:
		return east[index(other)] == 1
	if step.y == 1:
		return south[index(cell)] == 1
	return south[index(other)] == 1


## The middle of a cell in the world, on the ground. The clearing's middle is the origin.
func world(cell: Vector2i) -> Vector3:
	var middle := (size - 1) * 0.5
	return Vector3((cell.x - middle) * CELL, 0.0, (cell.y - middle) * CELL)


## The cell a point in the world is in (it may be outside the maze).
func cell_at(point: Vector3) -> Vector2i:
	var middle := (size - 1) * 0.5
	return Vector2i(roundi(point.x / CELL + middle), roundi(point.z / CELL + middle))


## How far across the maze that is built is, wall to wall.
func extent() -> float:
	return size * CELL


## How far across a ring is (0, the clearing), built or not.
static func ring_extent(ring: int) -> float:
	return RINGS[clampi(ring, 0, RINGS.size() - 1)] * CELL


## Whether a point in the world is out past the exit.
func escaped(point: Vector3) -> bool:
	return absf(point.x) > extent() * 0.5 + 1.0 or absf(point.z) > extent() * 0.5 + 1.0


## A path of cells from `from` to the exit, or [] if there is none.
func path_out(from: Vector2i) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == exit:
			var path: Array[Vector2i] = [cell]
			while cell != from:
				cell = came[cell]
				path.push_front(cell)
			return path
		for step: Vector2i in STEPS:
			var next := cell + step
			if inside(next) and not came.has(next) and not blocked(cell, step):
				came[next] = cell
				queue.push_back(next)
	return []


const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _open(cell: Vector2i, step: Vector2i) -> void:
	var other := cell + step
	if not inside(other):
		return
	if step.x == 1:
		east[index(cell)] = 0
	elif step.x == -1:
		east[index(other)] = 0
	elif step.y == 1:
		south[index(cell)] = 0
	else:
		south[index(other)] = 0


## The way out of a cell on the outside of its ring: the side it is on (a corner
## takes the side its ring's gate would be furthest along).
func _outward(cell: Vector2i) -> Vector2i:
	var middle := size / 2
	var off := cell - Vector2i(middle, middle)
	if absi(off.x) >= absi(off.y):
		return Vector2i(signi(off.x), 0)
	return Vector2i(0, signi(off.y))


func _carve(loops: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze_seed
	var count := size * size
	east.resize(count)
	east.fill(1)
	south.resize(count)
	south.fill(1)
	var visited := PackedByteArray()
	visited.resize(count)
	visited.fill(0)

	# The clearing is open ground, and visited from the start.
	for i in count:
		var cell := Vector2i(i % size, i / size)
		if in_clearing(cell):
			visited[i] = 1
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if in_clearing(cell + step):
					_open(cell, step)

	# Into the first ring: a gate in the middle of each side of the clearing.
	var middle := size / 2
	var low := (size - clearing) / 2
	var high := low + clearing - 1
	var ways_in: Array = [
		[Vector2i(middle, low), Vector2i(0, -1)],
		[Vector2i(high, middle), Vector2i(1, 0)],
		[Vector2i(middle, high), Vector2i(0, 1)],
		[Vector2i(low, middle), Vector2i(-1, 0)],
	]
	for ring in range(1, rings + 1):
		gates.append(ways_in)
		_carve_ring(ring, ways_in, visited, rng, loops)
		_measure()
		# The way on: the cell on the ring's outside furthest round the walls
		# from the way in.
		var best := -1
		var out := Vector2i.ZERO
		for i in count:
			var cell := Vector2i(i % size, i / size)
			if ring_of(cell) != ring or ring_of(cell + _outward(cell)) == ring:
				continue
			# (a tie goes to the seed, not to the first cell found)
			var score := distance[i] * 4 + rng.randi_range(0, 3)
			if score > best:
				best = score
				out = cell
		exits.append([out, _outward(out)])
		_open(out, _outward(out))
		ways_in = [[out, _outward(out)]]
	exit = exits.back()[0]
	exit_side = exits.back()[1]


## Grows one ring's passages from behind its ways in (a depth-first walk, which
## makes long winding passages), then knocks a few walls through for loops. The
## walk stays in its ring: the walls between rings stand but for the gates.
func _carve_ring(ring: int, ways_in: Array, visited: PackedByteArray, rng: RandomNumberGenerator, loops: float) -> void:
	for way: Array in ways_in:
		var from: Vector2i = way[0]
		var step: Vector2i = way[1]
		_open(from, step)
		var start: Vector2i = from + step
		if visited[index(start)] == 1:
			continue
		visited[index(start)] = 1
		var stack: Array[Vector2i] = [start]
		while not stack.is_empty():
			var cell: Vector2i = stack.back()
			var choices: Array[Vector2i] = []
			for s: Vector2i in STEPS:
				var next := cell + s
				if inside(next) and ring_of(next) == ring and visited[index(next)] == 0:
					choices.append(s)
			if choices.is_empty():
				stack.pop_back()
				continue
			var pick := choices[rng.randi_range(0, choices.size() - 1)]
			_open(cell, pick)
			visited[index(cell + pick)] = 1
			stack.push_back(cell + pick)

	var cells := 0
	for i in size * size:
		if ring_of(Vector2i(i % size, i / size)) == ring:
			cells += 1
	for i in int(cells * loops):
		var cell := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var step := Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		if ring_of(cell) == ring and ring_of(cell + step) == ring:
			_open(cell, step)


## Steps from the clearing to each cell, round the walls.
func _measure() -> void:
	distance.resize(size * size)
	distance.fill(-1)
	var queue: Array[Vector2i] = []
	for way: Array in gates[0]:
		var gap: Vector2i = way[0] + way[1]
		distance[index(gap)] = 1
		queue.append(gap)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in STEPS:
			var next := cell + step
			if inside(next) and not in_clearing(next) and distance[index(next)] == -1 and not blocked(cell, step):
				distance[index(next)] = distance[index(cell)] + 1
				queue.push_back(next)


## Sets the walls from `is_wall(cell, step)` (whether the line on that side of the
## cell has a wall on it): what MazeLayout does when its walls have been moved by
## hand. The way out is kept if it is still open; otherwise it is the first gap
## found in the outer wall. The steps from the clearing are counted again.
func set_walls(is_wall: Callable) -> void:
	for i in size * size:
		var cell := Vector2i(i % size, i / size)
		east[i] = 1 if cell.x < size - 1 and is_wall.call(cell, Vector2i(1, 0)) else (1 if cell.x == size - 1 else 0)
		south[i] = 1 if cell.y < size - 1 and is_wall.call(cell, Vector2i(0, 1)) else (1 if cell.y == size - 1 else 0)
	if is_wall.call(exit, exit_side):
		for i in size * size:
			var cell := Vector2i(i % size, i / size)
			for step: Vector2i in STEPS:
				if not inside(cell + step) and not is_wall.call(cell, step):
					exit = cell
					exit_side = step
					break
	_measure()
