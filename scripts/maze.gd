class_name Maze
extends RefCounted
## A maze on a square grid of cells, with an open clearing in the middle and one
## way out through the outer wall. It is only the plan: walls, the clearing, the
## exit. MazeBuilder (scripts/maze_builder.gd) puts it up in the world.
##
## The same seed always gives the same maze, which is how everyone in a room gets
## the same one without it being sent: the seed comes from the room's code and
## the round (see seed_for).
##
## Cells are (x, y), 0 to size - 1, y running south (+Z in the world). Walls sit
## on the edges between cells: `east[i]` is the wall on cell i's east side and
## `south[i]` on its south side, with i = x + y * size. The outer wall on the west
## and north is implied, and is solid except at `exit`.

## Metres across one cell, from wall to wall.
const CELL := 4.0

var size := 25
## Cells along a side of the clearing (odd, so it has a middle).
var clearing := 5
var maze_seed := 0
var east := PackedByteArray()
var south := PackedByteArray()
## The cell on the outer edge that leads out, and which way out is from it.
var exit := Vector2i.ZERO
var exit_side := Vector2i.ZERO
## Steps from the clearing to every cell (-1 inside the clearing).
var distance := PackedInt32Array()


## A seed for a room's maze on a given round: the same on every copy of the game.
static func seed_for(code: String, round_number: int) -> int:
	return hash("%s/%d" % [code, round_number]) & 0x7fffffff


## Makes the maze for `seed_value`. `loops` is the share of dead walls knocked
## through afterwards, so that there is more than one way round.
static func generate(seed_value: int, grid := 25, clearing_cells := 5, loops := 0.06) -> Maze:
	var maze := Maze.new()
	maze.size = grid
	maze.clearing = clearing_cells
	maze.maze_seed = seed_value
	maze._carve(loops)
	return maze


func index(cell: Vector2i) -> int:
	return cell.x + cell.y * size


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


func in_clearing(cell: Vector2i) -> bool:
	var low := (size - clearing) / 2
	return cell.x >= low and cell.y >= low and cell.x < low + clearing and cell.y < low + clearing


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


## How far across the whole maze is, wall to wall.
func extent() -> float:
	return size * CELL


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
	if step.x == 1:
		east[index(cell)] = 0
	elif step.x == -1:
		east[index(other)] = 0
	elif step.y == 1:
		south[index(cell)] = 0
	else:
		south[index(other)] = 0


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
	var low := (size - clearing) / 2
	var high := low + clearing - 1
	for y in range(low, high + 1):
		for x in range(low, high + 1):
			visited[index(Vector2i(x, y))] = 1
			if x < high:
				east[index(Vector2i(x, y))] = 0
			if y < high:
				south[index(Vector2i(x, y))] = 0

	# A gap in the middle of each side of the clearing, and the maze grown from
	# behind each one in turn (a depth-first walk, which makes long winding
	# passages). The first walk reaches everywhere; the others only open their gap,
	# which gives four ways in and out of the clearing.
	var mid := size / 2
	var gaps: Array = [
		[Vector2i(mid, low), Vector2i(0, -1)],
		[Vector2i(high, mid), Vector2i(1, 0)],
		[Vector2i(mid, high), Vector2i(0, 1)],
		[Vector2i(low, mid), Vector2i(-1, 0)],
	]
	for gap: Array in gaps:
		var from: Vector2i = gap[0]
		var step: Vector2i = gap[1]
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
				if inside(next) and visited[index(next)] == 0:
					choices.append(s)
			if choices.is_empty():
				stack.pop_back()
				continue
			var pick := choices[rng.randi_range(0, choices.size() - 1)]
			_open(cell, pick)
			visited[index(cell + pick)] = 1
			stack.push_back(cell + pick)

	# Knock through some walls, away from the clearing, for loops.
	var walls := int(count * loops)
	for i in walls:
		var cell := Vector2i(rng.randi_range(0, size - 2), rng.randi_range(0, size - 2))
		if in_clearing(cell):
			continue
		_open(cell, Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1))

	_measure()
	# The way out: the edge cell furthest from the clearing.
	var best := -1
	for i in count:
		var cell := Vector2i(i % size, i / size)
		var edge := cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1
		# (a tie goes to the seed, not to the first cell found)
		var score := distance[i] * 4 + rng.randi_range(0, 3)
		if edge and score > best:
			best = score
			exit = cell
	if exit.x == 0:
		exit_side = Vector2i(-1, 0)
	elif exit.x == size - 1:
		exit_side = Vector2i(1, 0)
	elif exit.y == 0:
		exit_side = Vector2i(0, -1)
	else:
		exit_side = Vector2i(0, 1)


## Steps from the clearing to each cell, round the walls.
func _measure() -> void:
	distance.resize(size * size)
	distance.fill(-1)
	var queue: Array[Vector2i] = []
	var low := (size - clearing) / 2
	var mid := size / 2
	for gap: Vector2i in [Vector2i(mid, low - 1), Vector2i(low + clearing, mid), Vector2i(mid, low + clearing), Vector2i(low - 1, mid)]:
		distance[index(gap)] = 1
		queue.append(gap)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in STEPS:
			var next := cell + step
			if inside(next) and not in_clearing(next) and distance[index(next)] == -1 and not blocked(cell, step):
				distance[index(next)] = distance[index(cell)] + 1
				queue.push_back(next)
