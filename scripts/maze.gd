@tool
class_name Maze
extends RefCounted
## The maze: a great open clearing in the middle, and round it rings of maze, one
## outside the other, each walled off from the next but for one gate. The first
## ring has four ways in from the clearing; each ring after it is entered by the
## gate out of the ring inside it. It is only the plan: walls, the clearing, the
## gates. MazeBuilder (scripts/maze_builder.gd) puts it up in the world.
##
## CLEARING says how big the clearing is, and each ring's MazeStyle (`styles`) how
## deep the ring is and the rules its passages are made by. `rings` is how many
## of them are built: the grid only runs to the outside of the last one built,
## and the way out of that one is `exit`. (For now only the first ring is built.)
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
## Cells across the clearing (odd, so that it has a middle cell).
const CLEARING := 21

var size := CLEARING
## Cells along a side of the clearing.
var clearing := CLEARING
## How each ring is made, from the clearing out (MazeStyle), and cells across
## the clearing and then across the outside of each ring (all odd).
var styles: Array[MazeStyle] = []
var ring_sizes: Array[int] = []
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


## Makes the maze for `seed_value`, with `built` rings round the clearing, each
## made as its style says (MazeStyle.defaults() if none are given).
static func generate(seed_value: int, built := 1, ring_styles: Array[MazeStyle] = []) -> Maze:
	var maze := Maze.new()
	maze.styles = ring_styles if not ring_styles.is_empty() else MazeStyle.defaults()
	maze.ring_sizes = sizes_for(maze.styles)
	maze.rings = clampi(built, 1, maze.styles.size())
	maze.size = maze.ring_sizes[maze.rings]
	maze.clearing = CLEARING
	maze.maze_seed = seed_value
	maze._carve()
	return maze


## Cells across the clearing and then across the outside of each ring of `ring_styles`.
static func sizes_for(ring_styles: Array[MazeStyle]) -> Array[int]:
	var sizes: Array[int] = [CLEARING]
	for style in ring_styles:
		sizes.append(sizes.back() + style.width * 2)
	return sizes


func index(cell: Vector2i) -> int:
	return cell.x + cell.y * size


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size and cell.y < size


## Which ring a cell is in: 0 for the clearing, 1 for the first ring round it, and
## so on (past the last ring, ring_sizes.size()). Cells outside the grid are in the
## rings that are not built yet.
func ring_of(cell: Vector2i) -> int:
	var middle := size / 2
	var across := maxi(absi(cell.x - middle), absi(cell.y - middle)) * 2 + 1
	for ring in ring_sizes.size():
		if across <= ring_sizes[ring]:
			return ring
	return ring_sizes.size()


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


## How far across a ring is (0, the clearing), built or not, with the rings of
## `ring_styles` (MazeStyle.defaults() if none are given).
static func ring_extent(ring: int, ring_styles: Array[MazeStyle] = []) -> float:
	var sizes := sizes_for(ring_styles if not ring_styles.is_empty() else MazeStyle.defaults())
	return sizes[clampi(ring, 0, sizes.size() - 1)] * CELL


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


func _carve() -> void:
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
		_carve_ring(ring, ways_in, visited, rng)
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


## Grows one ring's passages from behind its ways in, by the ring's MazeStyle: over
## blocks of `span` x `span` cells, whose inside walls all come down (so a hall is
## `span` cells wide), each new block joined to one already reached. The walk stays
## in its ring: the walls between rings stand but for the gates.
func _carve_ring(ring: int, ways_in: Array, visited: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var style: MazeStyle = styles[ring - 1]
	var blocks := _blocks(ring, style.span)
	var block_of: Dictionary = blocks[0]
	var cells_of: Dictionary = blocks[1]
	for block: Vector2i in cells_of:
		for cell: Vector2i in cells_of[block]:
			visited[index(cell)] = 1
			for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if block_of.get(cell + s, NO_BLOCK) == block:
					_open(cell, s)
	var reached := {}
	var heading := {}
	var active: Array[Vector2i] = []
	for way: Array in ways_in:
		var from: Vector2i = way[0]
		var step: Vector2i = way[1]
		var block: Vector2i = block_of[from + step]
		# (a gate from the clearing as wide as the hall it opens into; from a ring, one cell)
		if ring == 1:
			for cell: Vector2i in cells_of[block]:
				if in_clearing(cell - step):
					_open(cell, -step)
		else:
			_open(from, step)
		if not reached.has(block):
			reached[block] = true
			heading[block] = step
			active.append(block)
	while not active.is_empty():
		# The newest block mostly (long passages), sometimes an older one (a branch).
		var at := active.size() - 1
		if rng.randf() < style.branching:
			at = rng.randi_range(0, active.size() - 1)
		var block: Vector2i = active[at]
		var choices: Array[Vector2i] = []
		for s: Vector2i in STEPS:
			if cells_of.has(block + s) and not reached.has(block + s):
				choices.append(s)
		if choices.is_empty():
			active.remove_at(at)
			continue
		var pick: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		var was: Vector2i = heading[block]
		if rng.randf() < style.straight and was in choices:
			pick = was
		_join(block, block + pick, block_of, cells_of)
		reached[block + pick] = true
		heading[block + pick] = pick
		active.append(block + pick)

	# A few walls between halls knocked through, for loops.
	var all: Array = cells_of.keys()
	for i in int(all.size() * style.loops):
		var block: Vector2i = all[rng.randi_range(0, all.size() - 1)]
		var s := Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		if cells_of.has(block + s):
			_join(block, block + s, block_of, cells_of)


const NO_BLOCK := Vector2i(-1000, -1000)


## The blocks of a ring, as [{cell: block}, {block: [cells]}]. Blocks are counted
## across the square of the ring from its outside corner; across its depth they
## are `span` cells (the last one taking any cells left over), and so along the
## sides of what it is round.
func _blocks(ring: int, span: int) -> Array:
	var outer: int = ring_sizes[ring]
	var inner: int = ring_sizes[ring - 1]
	var band := (outer - inner) / 2
	var low := (size - outer) / 2
	var block_of := {}
	var cells_of := {}
	for i in size * size:
		var cell := Vector2i(i % size, i / size)
		if ring_of(cell) != ring:
			continue
		var block := Vector2i(_block_on(cell.x - low, band, inner, span), _block_on(cell.y - low, band, inner, span))
		block_of[cell] = block
		if not cells_of.has(block):
			cells_of[block] = []
		(cells_of[block] as Array).append(cell)
	return [block_of, cells_of]


## Which block, counted across a ring's square, the cells `at` in from its outside
## edge are in: `band` cells deep each side of `inner` cells.
static func _block_on(at: int, band: int, inner: int, span: int) -> int:
	var deep := maxi(band / span, 1)
	var along := maxi(inner / span, 1)
	if at < band:
		return mini(at / span, deep - 1)
	if at < band + inner:
		return deep + mini((at - band) / span, along - 1)
	return deep + along + mini((at - band - inner) / span, deep - 1)


## Opens the whole side between two blocks next to each other.
func _join(a: Vector2i, b: Vector2i, block_of: Dictionary, cells_of: Dictionary) -> void:
	var s := b - a
	for cell: Vector2i in cells_of[a]:
		if block_of.get(cell + s, NO_BLOCK) == b:
			_open(cell, s)


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
