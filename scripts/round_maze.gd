@tool
class_name RoundMaze
extends RefCounted
## The round sections of the maze, outside the square ones (Maze): rings of
## passages between great circular walls, each made as its MazeStyle says (one
## whose `round` is on). Between the square maze's outer wall and the first
## circle is the moor, open ground that the square maze's way out comes onto;
## each circle has a few gates through it, and the last one way out.
##
## Each section is rows of cells, one hall wide (hallway diameter cells x
## Maze.CELL) from wall to wall; a row has as many cells round it as fit at
## that width, so rows further out have more. The passages are grown over
## them as in a square section (straight on chance, side branch chance, loop
## share), from the gates.

## How far out the first circle stands past the corners of the square maze, metres.
const MOOR_MARGIN := 28.0
## How many gates each circle has through it into the section outside it.
const GATES := 3
## How wide the gap of a gate through a great wall is, metres.
const GATE_WIDE := 8.0

class Ring:
	var style: MazeStyle
	## Its inside and outside radius (the middles of the great walls round it).
	var inner := 0.0
	var outer := 0.0
	## Each row: [inside radius, outside radius, how many cells round it].
	var rows: Array = []
	## Which cells (row, index) are joined to which: [a, b] pairs, as keys.
	var open := {}
	## The angles round of the gates into it and of the ways out of it (the middle
	## of each gap through the great wall).
	var gates_in: Array[float] = []
	var gates_out: Array[float] = []
	## Each cell's neighbours (cell -> Array[Vector2i]), worked out once.
	var links := {}

## The middle of the great wall the moor ends at (the first circle).
var inner_radius := 0.0
var rings: Array[Ring] = []
## The way out: the angle it is at, round the last circle.
var exit_angle := 0.0
var _rng := RandomNumberGenerator.new()


## The round sections of `maze`, for its round styles (after its square ones),
## `count` of them.
static func generate(maze: Maze, count: int) -> RoundMaze:
	var made := RoundMaze.new()
	made._rng.seed = hash("round/%d" % maze.maze_seed)
	var half := maze.extent() * 0.5
	made.inner_radius = half * sqrt(2.0) + MOOR_MARGIN
	var radius := made.inner_radius
	for k in count:
		var style: MazeStyle = maze.styles[maze.rings + k]
		var ring := Ring.new()
		ring.style = style
		ring.inner = radius
		var wide := Maze.CELL * style.hallway_diameter_cells
		var row_count := maxi(style.section_depth_cells / style.hallway_diameter_cells, 1)
		var r := radius
		for i in row_count:
			var cells := maxi(roundi(TAU * (r + wide * 0.5) / wide), 8)
			ring.rows.append([r, r + wide, cells])
			r += wide
		ring.outer = r
		radius = r
		made.rings.append(ring)
	# (each section's gates in where the one inside it has its ways out)
	var gates: Array[float] = []
	var start := made._rng.randf() * TAU
	for g in GATES:
		gates.append(fposmod(start + g * TAU / GATES, TAU))
	for k in made.rings.size():
		gates = made._carve(made.rings[k], gates, k == made.rings.size() - 1)
	made.exit_angle = gates[0]
	return made


## The radius past which one has got out.
func outermost() -> float:
	return rings.back().outer if not rings.is_empty() else inner_radius


## Whether `point` is out past the last circle.
func escaped(point: Vector3) -> bool:
	return Vector2(point.x, point.z).length() > outermost() + 2.0


## The angle round a row of `cells` at which cell `j` starts.
static func angle_of(j: int, cells: int) -> float:
	return TAU * float(j) / cells


## The cells of the next row out that cell `j` of a row of `cells` touches, in
## a row of `next` cells: [index, from angle, to angle] for each (the angles of
## the stretch of wall between them).
static func touching(j: int, cells: int, next: int) -> Array:
	var a0 := angle_of(j, cells)
	var a1 := angle_of(j + 1, cells)
	var found: Array = []
	var first := floori(a0 / TAU * next)
	var last := ceili(a1 / TAU * next) - 1
	for m in range(first, last + 1):
		var b0 := maxf(a0, angle_of(m, next))
		var b1 := minf(a1, angle_of(m + 1, next))
		if b1 - b0 > 0.0001:
			found.append([posmod(m, next), b0, b1])
	return found


static func _key(a: Vector2i, b: Vector2i) -> Array:
	return [a, b] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else [b, a]


## Whether cells `a` and `b` (row, index) of `ring` are joined.
static func joined(ring: Ring, a: Vector2i, b: Vector2i) -> bool:
	return ring.open.has(_key(a, b))


func _neighbours(ring: Ring, cell: Vector2i) -> Array[Vector2i]:
	if ring.links.is_empty():
		for i in ring.rows.size():
			var cells: int = ring.rows[i][2]
			for j in cells:
				ring.links[Vector2i(i, j)] = [Vector2i(i, posmod(j - 1, cells)), Vector2i(i, posmod(j + 1, cells))] as Array[Vector2i]
		for i in ring.rows.size() - 1:
			var cells: int = ring.rows[i][2]
			for j in cells:
				for touch: Array in touching(j, cells, ring.rows[i + 1][2]):
					var out := Vector2i(i + 1, touch[0])
					(ring.links[Vector2i(i, j)] as Array[Vector2i]).append(out)
					(ring.links[out] as Array[Vector2i]).append(Vector2i(i, j))
	return ring.links[cell]


## Grows the passages of `ring` (as Maze grows a square section's: mostly from
## the newest cell, going on the way it went), from gates spaced round its
## inside; then knocks through its loop share; then picks its ways out.
func _carve(ring: Ring, gates: Array[float], last: bool) -> Array[float]:
	var style := ring.style
	var inside: int = ring.rows[0][2]
	ring.gates_in = gates
	var seen := {}
	var live: Array[Vector2i] = []
	var heading := {}
	for g: float in ring.gates_in:
		var cell := Vector2i(0, cell_at(g, inside))
		if not seen.has(cell):
			seen[cell] = true
			live.append(cell)
	var all: Array = []
	while not live.is_empty():
		var at := live.size() - 1
		if _rng.randf() < style.side_branch_chance:
			at = _rng.randi() % live.size()
		var cell: Vector2i = live[at]
		var choices: Array[Vector2i] = []
		for next in _neighbours(ring, cell):
			if not seen.has(next):
				choices.append(next)
		if choices.is_empty():
			live.remove_at(at)
			continue
		var pick: Vector2i = choices[_rng.randi() % choices.size()]
		# (on the way it was going, when it can)
		if heading.has(cell) and _rng.randf() < style.straight_on_chance:
			for next in choices:
				if _way(ring, cell, next) == heading[cell]:
					pick = next
		ring.open[_key(cell, pick)] = true
		heading[pick] = _way(ring, cell, pick)
		seen[pick] = true
		live.append(pick)
		all.append(pick)
	# Loops: walls knocked through between cells already joined some other way.
	for cell: Vector2i in all:
		if _rng.randf() < style.loop_share:
			var others := _neighbours(ring, cell)
			var other: Vector2i = others[_rng.randi() % others.size()]
			ring.open[_key(cell, other)] = true
	# (no wall between cells across the gap of a gate: the gap would be shut)
	_clear_gaps(ring, 0, ring.gates_in)
	# The ways out: into the next section, or (the last) out of the maze.
	# (each in the middle of a cell of the last row)
	var outside: int = ring.rows.back()[2]
	var out_start := _rng.randi() % outside
	for g in (1 if last else GATES):
		var j := posmod(out_start + g * outside / GATES, outside)
		ring.gates_out.append((angle_of(j, outside) + angle_of(j + 1, outside)) * 0.5)
	_clear_gaps(ring, ring.rows.size() - 1, ring.gates_out)
	return ring.gates_out


## Joins the cells of row `i` either side of any wall between them that would
## stand in the gap of one of `gates` (angles) through the great wall it is next to.
func _clear_gaps(ring: Ring, i: int, gates: Array[float]) -> void:
	var row: Array = ring.rows[i]
	var cells: int = row[2]
	var r: float = row[0] if i == 0 else row[1]
	var reach := (GATE_WIDE * 0.5 + ring.style.maze_wall_diameter) / r
	for g: float in gates:
		for j in cells:
			var between := angle_of(j + 1, cells)
			if absf(angle_difference(between, g)) < reach:
				ring.open[_key(Vector2i(i, j), Vector2i(i, (j + 1) % cells))] = true


## Which cell of a row of `cells` is at angle `angle`.
static func cell_at(angle: float, cells: int) -> int:
	return posmod(floori(fposmod(angle, TAU) / TAU * cells), cells)


# Which way a step goes: 0 round, 1 out, -1 in (round either way counts as one,
# so that a passage going round goes on going round).
static func _way(_ring: Ring, a: Vector2i, b: Vector2i) -> int:
	return b.x - a.x
