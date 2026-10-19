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
const CLEARING := 41

var size := CLEARING
## Cells along a side of the clearing.
var clearing := CLEARING
## How each ring is made, from the clearing out (MazeStyle), and cells across
## the clearing and then across the outside of each ring (all odd).
var styles: Array[MazeStyle] = []
var ring_sizes: Array[int] = []
## How the clearing is made: its hills and its woods (see ground_height).
var clearing_style: ClearingStyle
## How the desert between the square sections and the round ones is made (DesertStyle).
var desert_style: DesertStyle
## The round sections outside the square ones, if any were built (RoundMaze).
var round_rings: RoundMaze
## Only the clearing (Maze.generate with no rings): a test mode, its gates kept shut (World).
var clearing_only := false
## How many rings are built.
var rings := 1
var maze_seed := 0
var east := PackedByteArray()
var south := PackedByteArray()
## For each ring built (ring 1 is gates[0]), the ways into it from the ring inside
## it, as [cell inside it, the step into it]; and the way out of it into the next.
var gates: Array = []
var exits: Array = []
## The cell on the outer edge that leads out, and which way out is from it (the
## first of `ways_out`).
var exit := Vector2i.ZERO
var exit_side := Vector2i.ZERO
## Every way out through the outer edge, as [cell, step]: one, or with the desert
## built past the square maze (`sides_out`), one into each of its quarters.
var ways_out: Array = []
var sides_out := false
## Steps from the clearing to every cell (-1 inside the clearing).
var distance := PackedInt32Array()
## The cells of the narrow entrances into each ring (see MazeStyle.entrance_corridor_cells),
## as {cell: the way out along it}.
var entrances := {}
## The cells of solid stone in the ramparts round the inside of rings (see
## `rampart`): no way into them, walls all round.
var solid := {}
## The standing water in the halls (Ponds: each {rect, level, depth, round, fish,
## seed}), as the layout's pond pieces have it; the ground is lower under it.
var ponds: Array = []:
	set(value):
		ponds = value
		_pond_cells = Ponds.index(value)
## [cell] -> the ponds over it.
var _pond_cells := {}


## A seed for a room's maze on a given round: the same on every copy of the game.
static func seed_for(code: String, round_number: int) -> int:
	return hash("%s/%d" % [code, round_number]) & 0x7fffffff


## Makes the maze for `seed_value`, with `built` rings round the clearing (the square
## sections, then the desert, then the round ones), each made as its style says
## (MazeStyle.defaults() if none are given). With none (0), only the clearing: `clearing_only`.
static func generate(seed_value: int, built := 1, ring_styles: Array[MazeStyle] = [], clearing_look: ClearingStyle = null, desert_look: DesertStyle = null) -> Maze:
	var maze := Maze.new()
	maze.styles = ring_styles if not ring_styles.is_empty() else MazeStyle.defaults()
	# (none: the clearing alone, for testing in, its first section only a narrow way
	# round behind its gates, with nothing in it: MazeStyle.bare)
	if built <= 0:
		maze.clearing_only = true
		maze.styles = maze.styles.duplicate()
		maze.styles[0] = maze.styles[0].bare()
	maze.clearing_style = clearing_look if clearing_look else ClearingStyle.new()
	maze.desert_style = desert_look if desert_look else DesertStyle.new()
	maze.ring_sizes = sizes_for(maze.styles, maze.clearing_style)
	# (the square sections are the first, up to the first round one; the round ones
	# are RoundMaze's, outside them)
	var square := 0
	while square < maze.styles.size() and not maze.styles[square].round_section:
		square += 1
	maze.rings = clampi(built, 1, maxi(square, 1))
	# (with the desert past it, the square maze has a way out into each of its quarters)
	maze.sides_out = built > square and maze.rings == square
	maze.size = maze.ring_sizes[maze.rings]
	maze.clearing = CLEARING
	maze.maze_seed = seed_value
	maze._carve()
	# (where the entrances are, for what is in front of each)
	maze.clearing_style.entrance_spots = []
	for way: Array in maze.gates[0]:
		var step: Vector2i = way[1]
		var out := Vector2(step.x, step.y)
		var at := maze.world(way[0])
		var face := Vector2(at.x, at.z) + out * (CELL * 0.5 - maze.wall_thick(way[0], step) * 0.5)
		maze.clearing_style.entrance_spots.append([face, -out])
	# (each quarter of the desert what the entrance on its side is in front of)
	maze.desert_style.match_to(maze.clearing_style)
	# (the desert counts as a ring, after the square ones: built one past them, it is
	# there with no circles beyond it, its far wall the way out; more, the circles)
	if built > square and maze.rings == square:
		var round_count := clampi(built - square - 1, 0, maze.styles.size() - square)
		maze.round_rings = RoundMaze.generate(maze, round_count)
	return maze


## Cells across the clearing and then across the outside of each ring of `ring_styles`.
static func sizes_for(ring_styles: Array[MazeStyle], clearing_look: ClearingStyle = null) -> Array[int]:
	var sizes: Array[int] = [CLEARING]
	for k in ring_styles.size():
		# (the rampart round its inside is on top of its width: a thicker wall moves the ring out)
		sizes.append(sizes.back() + (ring_styles[k].section_width_cells + rampart_cells(k + 1, ring_styles, clearing_look)) * 2)
	return sizes


## How many cells of solid wall thicken the wall round the inside of `ring`: the
## clearing's own (ClearingStyle.clearing_wall_thickness_cells) round the first,
## and round any other the section inside it's (MazeStyle.border_wall_thickness_cells,
## that section's outer wall).
static func rampart_cells(ring: int, ring_styles: Array[MazeStyle], clearing_look: ClearingStyle = null) -> int:
	if ring == 1:
		return (clearing_look if clearing_look else ClearingStyle.new()).clearing_wall_thickness_cells
	if ring >= 2 and ring - 2 < ring_styles.size() and not ring_styles[ring - 2].round_section:
		return ring_styles[ring - 2].border_wall_thickness_cells
	return 0


## The rampart round the inside of `ring` (see rampart_cells), in cells.
func rampart(ring: int) -> int:
	return rampart_cells(ring, styles, clearing_style)


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


## How many cells out from the inside of its ring a cell is (0 next to the wall
## round what the ring is round).
func depth_in_ring(cell: Vector2i) -> int:
	var middle := size / 2
	var out := maxi(absi(cell.x - middle), absi(cell.y - middle))
	var ring := ring_of(cell)
	if ring == 0:
		return out
	return out - (ring_sizes[ring - 1] - 1) / 2 - 1


func in_clearing(cell: Vector2i) -> bool:
	return ring_of(cell) == 0


## Whether the wall between `cell` and its neighbour the `step` way divides one
## ring from another (the clearing's wall included). These are the great walls.
func ring_wall(cell: Vector2i, step: Vector2i) -> bool:
	return ring_of(cell) != ring_of(cell + step)


## Whether the face of the wall on the `step` side of `cell` has a step of ledge
## along its foot (MazeStyle.mezzanine_height, by the style of the ring `cell` is
## in): every wall of a ring that has them, the great walls round it and the
## clearing's wall included, on the ring's side only (none in the clearing: the
## user, 2026-10-18).
func has_ledge(cell: Vector2i, step: Vector2i) -> bool:
	var ring := ring_of(cell)
	if ring < 1 or ring > styles.size() or solid.has(cell) or not blocked(cell, step):
		return false
	return styles[ring - 1].mezzanine_height > 0.0


## The style the ledges along `cell`'s walls are made by (see has_ledge): its ring's.
func ledge_style(cell: Vector2i) -> MazeStyle:
	return styles[clampi(ring_of(cell), 1, styles.size()) - 1]


## How thick the wall on the `step` side of `cell` is: as its ring's style says
## (MazeStyle.maze_wall_diameter), and a wall between rings as the thicker of the two,
## and no thinner than MazeBuilder.RING_THICK.
func wall_thick(cell: Vector2i, step: Vector2i) -> float:
	var here := _thick_in(ring_of(cell))
	var there := _thick_in(ring_of(cell + step))
	if ring_wall(cell, step):
		return maxf(MazeBuilder.RING_THICK, maxf(here, there))
	return here


## How thick the walls in a ring are (the clearing's none).
func _thick_in(ring: int) -> float:
	if ring < 1 or ring > styles.size():
		return 0.0
	return styles[ring - 1].maze_wall_diameter


## How high the ground is at a point (its x and z): the clearing's gentle hills
## (ClearingStyle.height_at); 0 everywhere else.
func ground_height(point: Vector3) -> float:
	# (the dunes, hummocks and hills of the desert ring outside the square sections, if there are round ones)
	if round_rings and maxf(absf(point.x), absf(point.z)) > extent() * 0.5:
		return round_rings.ground_at(point.x, point.z)
	var height := clearing_style.height_at(point.x, point.z, maze_seed)
	# (lower under standing water: Ponds)
	if not _pond_cells.is_empty():
		height = minf(height, pond_ground(point))
	return height


## How high the ground under the standing water at `point` is (Ponds), or INF
## where there is none.
func pond_ground(point: Vector3) -> float:
	var lowest := INF
	for pond: Dictionary in _pond_cells.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)), []):
		lowest = minf(lowest, Ponds.ground_of(pond, Vector2(point.x, point.z)))
	return lowest


## The pond (Ponds) whose water `point` (x, z) is under, or an empty one.
func pond_at(point: Vector3) -> Dictionary:
	for pond: Dictionary in _pond_cells.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)), []):
		if (pond.rect as Rect2).has_point(Vector2(point.x, point.z)) and Ponds.ground_of(pond, Vector2(point.x, point.z)) < pond.level - 0.02:
			return pond
	return {}


## How high the wall on the `step` side of `cell` is: a wall between rings as
## inner_height of the outer ring, any other as
## high as its ring's maze walls (MazeStyle.maze_wall_height).
func wall_height(cell: Vector2i, step: Vector2i) -> float:
	if ring_wall(cell, step):
		return inner_height(maxi(ring_of(cell), ring_of(cell + step)))
	return maze_wall_height(ring_of(cell))


## How high the maze walls inside `ring` are (MazeBuilder.WALL_HEIGHT for a ring
## that has no style).
func maze_wall_height(ring: int) -> float:
	if ring < 1 or ring > styles.size():
		return MazeBuilder.WALL_HEIGHT
	return styles[ring - 1].maze_wall_height


## How high the wall round the inside of `ring` is: the clearing's own wall
## (ClearingStyle.clearing_wall_height) round the first, and round any other the
## outer wall of the section inside it (MazeStyle.section_border_wall_height);
## MazeBuilder.RING_HEIGHT past the styles.
func inner_height(ring: int) -> float:
	if ring == 1:
		return clearing_style.clearing_wall_height if clearing_style else ClearingStyle.new().clearing_wall_height
	if ring < 2 or ring - 2 >= styles.size():
		return MazeBuilder.RING_HEIGHT
	return styles[ring - 2].section_border_wall_height


## Whether there is a wall between `cell` and its neighbour the `step` way
## (a unit step). The outer edge is a wall, except at the exit.
func blocked(cell: Vector2i, step: Vector2i) -> bool:
	var other := cell + step
	if not inside(other):
		for way: Array in ways_out:
			if way[0] == cell and way[1] == step:
				return false
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
static func ring_extent(ring: int, ring_styles: Array[MazeStyle] = [], clearing_look: ClearingStyle = null) -> float:
	var sizes := sizes_for(ring_styles if not ring_styles.is_empty() else MazeStyle.defaults(), clearing_look)
	return sizes[clampi(ring, 0, sizes.size() - 1)] * CELL


## Whether a point in the world is out past the exit.
func escaped(point: Vector3) -> bool:
	if round_rings:
		return round_rings.escaped(point)
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
		# (each ring its own numbers, so that a change to one ring's rules leaves the
		# rings outside it as they were but for the way into them; the first the seed's own)
		if ring > 1:
			rng = RandomNumberGenerator.new()
			rng.seed = hash("carve/%d/%d" % [maze_seed, ring])
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
		if ring == rings and sides_out:
			# Out of the last into the desert: one way into each of its quarters
			# (they are walled apart), the furthest round from the way in on each side.
			ways_in = _furthest_by_side(ring, ways_in[0], rng)
		elif ring < rings:
			# Into the next, as many gates as its style says, spread apart.
			ways_in = _spread_out(ring, ways_in, styles[ring].entrance_count, rng)
	ways_out = ways_in
	exit = ways_out[0][0]
	exit_side = ways_out[0][1]


## For each side of `ring`'s outside, the cell on it furthest round the walls from
## the way in (`first` on its own side), each opened: the ways into the desert's quarters.
func _furthest_by_side(ring: int, first: Array, rng: RandomNumberGenerator) -> Array:
	var found: Array = []
	for side: Vector2i in STEPS:
		if side == first[1]:
			found.append(first)
			continue
		var best := -1
		var out := Vector2i(-1, -1)
		for i in size * size:
			var cell := Vector2i(i % size, i / size)
			if ring_of(cell) != ring or _outward(cell) != side or ring_of(cell + side) == ring:
				continue
			# (not at a corner: a quarter's way in stands well along its side)
			var along: int = absi(cell.y - size / 2) if side.x != 0 else absi(cell.x - size / 2)
			if along > size / 3:
				continue
			var score := distance[i] * 4 + rng.randi_range(0, 3)
			if score > best:
				best = score
				out = cell
		if out.x >= 0:
			_open(out, side)
			found.append([out, side])
	return found


## `ways` (the first way on, out of `ring`) and more, up to `count`: cells on its
## outside each as far as can be from those already chosen, each opened.
func _spread_out(ring: int, ways: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var found: Array = ways.duplicate()
	while found.size() < count:
		var best := -1
		var out := Vector2i(-1, -1)
		for i in size * size:
			var cell := Vector2i(i % size, i / size)
			if ring_of(cell) != ring or ring_of(cell + _outward(cell)) == ring:
				continue
			var apart := 1 << 30
			for way: Array in found:
				var other: Vector2i = way[0]
				apart = mini(apart, absi(cell.x - other.x) + absi(cell.y - other.y))
			var score := apart * 4 + rng.randi_range(0, 3)
			if apart > 2 and score > best:
				best = score
				out = cell
		if out.x < 0:
			break
		_open(out, _outward(out))
		found.append([out, _outward(out)])
	return found


## Grows one ring's passages from behind its ways in, by the ring's MazeStyle: over
## blocks of `span` x `span` cells, whose inside walls all come down (so a hall is
## `span` cells wide), each new block joined to one already reached. Each way in
## is first a narrow entrance, one cell wide and `entrance` cells long, straight
## out from the gate, that opens into the rest only at its far end. Round the
## inside of the ring, `rampart` rows of cells are solid stone, but for the
## entrances through them. The walk stays in its ring: the walls between rings
## stand but for the gates.
func _carve_ring(ring: int, ways_in: Array, visited: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var style: MazeStyle = styles[ring - 1]
	var blocks := _blocks(ring, style.hallway_diameter_cells, rampart(ring))
	var block_of: Dictionary = blocks[0]
	var cells_of: Dictionary = blocks[1]
	# The entrances: each its own block, a line of cells (taken out of the blocks it
	# runs through), with the cell at its far end and the way on from it.
	var ends := {}
	for g in ways_in.size():
		var step: Vector2i = ways_in[g][1]
		var line: Array = []
		var cell: Vector2i = ways_in[g][0] + step
		# (through the rampart at least)
		while line.size() < maxi(style.entrance_corridor_cells, rampart(ring)) and inside(cell) and ring_of(cell) == ring and block_of.get(cell, Vector2i.ZERO).x >= 0:
			line.append(cell)
			cell += step
		if line.is_empty():
			continue
		for taken: Vector2i in line:
			entrances[taken] = step
		var key := Vector2i(-1 - g, -1)
		for taken: Vector2i in line:
			if block_of.has(taken):
				(cells_of[block_of[taken]] as Array).erase(taken)
			block_of[taken] = key
		cells_of[key] = line
		ends[key] = [line.back(), step]
	_split_apart(block_of, cells_of)
	# The rest of the rampart is stone.
	for i in size * size:
		var cell := Vector2i(i % size, i / size)
		if ring_of(cell) == ring and not block_of.has(cell):
			solid[cell] = true
			visited[i] = 1
	for block: Vector2i in cells_of:
		for cell: Vector2i in cells_of[block]:
			visited[index(cell)] = 1
			for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if block_of.get(cell + s, NO_BLOCK) == block:
					_open(cell, s)
	# Which blocks are next to which, and the way from one to the other.
	var next_to := {}
	for block: Vector2i in cells_of:
		next_to[block] = {}
	for block: Vector2i in cells_of:
		for cell: Vector2i in cells_of[block]:
			for s: Vector2i in STEPS:
				var other: Vector2i = block_of.get(cell + s, NO_BLOCK)
				if other != NO_BLOCK and other != block and _joins(cell, s, block, other, ends):
					(next_to[block] as Dictionary)[other] = s
	# Each way in comes out into a hall across it: the block past the entrance is
	# joined to those either side of it and never to the one straight on.
	for key: Vector2i in ends:
		var step: Vector2i = ends[key][1]
		var past: Vector2i = block_of.get(ends[key][0] + step, NO_BLOCK)
		if not next_to.has(past):
			continue
		for other: Vector2i in (next_to[past] as Dictionary).keys():
			var s: Vector2i = next_to[past][other]
			if s == step:
				(next_to[past] as Dictionary).erase(other)
				(next_to[other] as Dictionary).erase(past)
			elif s != -step:
				_join(past, other, block_of, cells_of, ends)

	var reached := {}
	var heading := {}
	var active: Array[Vector2i] = []
	for way: Array in ways_in:
		var from: Vector2i = way[0]
		var step: Vector2i = way[1]
		_open(from, step)
		# (grown from the first way in only: the walk reaches the blocks behind the
		# others in its time. Grown from each, a later one could find its block
		# already walled round by the rest, a room with only the gate into it.)
		if active.is_empty():
			var block: Vector2i = block_of[from + step]
			reached[block] = true
			heading[block] = step
			active.append(block)
	while not active.is_empty():
		# The newest block mostly (long passages), sometimes an older one (a branch).
		var at := active.size() - 1
		if rng.randf() < style.side_branch_chance:
			at = rng.randi_range(0, active.size() - 1)
		var block: Vector2i = active[at]
		var choices: Array[Vector2i] = []
		for other: Vector2i in next_to[block]:
			if not reached.has(other):
				choices.append(other)
		if choices.is_empty():
			active.remove_at(at)
			continue
		var pick: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
		if rng.randf() < style.straight_on_chance:
			for other in choices:
				if next_to[block][other] == heading[block]:
					pick = other
		_join(block, pick, block_of, cells_of, ends)
		reached[pick] = true
		heading[pick] = next_to[block][pick]
		active.append(pick)

	# A few walls between halls knocked through, for loops.
	var all: Array = cells_of.keys()
	for i in int(all.size() * style.loop_share):
		var block: Vector2i = all[rng.randi_range(0, all.size() - 1)]
		var others: Array = (next_to[block] as Dictionary).keys()
		if not others.is_empty():
			_join(block, others[rng.randi_range(0, others.size() - 1)], block_of, cells_of, ends)


const NO_BLOCK := Vector2i(-1000, -1000)


## The blocks of a ring, as [{cell: block}, {block: [cells]}]. Blocks are counted
## across the square of the ring from its outside corner; across its depth they
## are `span` cells (the last one taking any cells left over), and so along the
## sides of what it is round.
func _blocks(ring: int, span: int, rampart := 0) -> Array:
	var outer: int = ring_sizes[ring]
	# (the rampart's cells are in none: the blocks start outside it)
	var inner: int = ring_sizes[ring - 1] + rampart * 2
	var band := (outer - inner) / 2
	var low := (size - outer) / 2
	var block_of := {}
	var cells_of := {}
	for i in size * size:
		var cell := Vector2i(i % size, i / size)
		if ring_of(cell) != ring or depth_in_ring(cell) < rampart:
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


## Gives what is left of a block in pieces (an entrance cut through it) a block
## for each piece, and drops blocks left empty.
func _split_apart(block_of: Dictionary, cells_of: Dictionary) -> void:
	var fresh := 0
	for block: Vector2i in cells_of.keys():
		var cells: Array = cells_of[block]
		if cells.is_empty():
			cells_of.erase(block)
			continue
		var left := {}
		for cell: Vector2i in cells:
			left[cell] = true
		var first := true
		while not left.is_empty():
			var start: Vector2i = left.keys()[0]
			var piece: Array = [start]
			left.erase(start)
			var i := 0
			while i < piece.size():
				for s: Vector2i in STEPS:
					var next: Vector2i = piece[i] + s
					if left.has(next):
						left.erase(next)
						piece.append(next)
				i += 1
			var key := block if first else Vector2i(-100 - fresh, -100)
			if not first:
				fresh += 1
				for cell: Vector2i in piece:
					block_of[cell] = key
			cells_of[key] = piece
			first = false


## Whether the side of `cell` the `s` way joins block `a` to block `b`: anywhere
## between ordinary blocks, but an entrance only at its far end, going on.
static func _joins(cell: Vector2i, s: Vector2i, a: Vector2i, b: Vector2i, ends: Dictionary) -> bool:
	if ends.has(a) and not (cell == ends[a][0] and s == ends[a][1]):
		return false
	if ends.has(b) and not (cell + s == ends[b][0] and -s == ends[b][1]):
		return false
	return true


## Opens the side between two blocks next to each other (all of it that joins them).
func _join(a: Vector2i, b: Vector2i, block_of: Dictionary, cells_of: Dictionary, ends: Dictionary) -> void:
	for cell: Vector2i in cells_of[a]:
		for s: Vector2i in STEPS:
			if block_of.get(cell + s, NO_BLOCK) == b and _joins(cell, s, a, b, ends):
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
	# (the ways out are the gaps in the outer edge as the walls now stand)
	var gaps: Array = []
	for i in size * size:
		var cell := Vector2i(i % size, i / size)
		for step: Vector2i in STEPS:
			if not inside(cell + step) and not is_wall.call(cell, step):
				gaps.append([cell, step])
	if not gaps.is_empty():
		ways_out = gaps
		if is_wall.call(exit, exit_side):
			exit = gaps[0][0]
			exit_side = gaps[0][1]
	_measure()
