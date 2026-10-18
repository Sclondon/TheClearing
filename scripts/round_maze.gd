@tool
class_name RoundMaze
extends RefCounted
## The round sections of the maze, outside the square ones (Maze): rings of
## passages between great circular walls, each made as its RoundStyle says (the
## round sections of MazeLayout). Between the square maze's outer wall and the first
## circle is the desert ring (Maze.desert_style), cut into quarters by unbroken great walls
## from the square's corners, each its own biome, entered by its own way out of the square maze
## and left by its own gate in the first circle; each circle has a few gates, and the last one way out.
##
## Each section is rows of cells, one hall wide (hallway diameter cells x
## Maze.CELL) from wall to wall; a row has as many cells round it as fit at
## that width, so rows further out have more. The passages are grown over
## them as in a square section (straight on chance, side branch chance, loop
## share), from the gates.

## How many gates each circle has through it into the section outside it.
const GATES := 3
## How wide the gap of a gate through a great wall is, metres.
const GATE_WIDE := 8.0
## (spreads the doors' turns evenly, however many there are)
const GOLDEN := 0.6180339887

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
	## What it is (RoundStyle.Layout): a maze, circles of rotating doors, or a tunnel.
	var layout := 0
	## Its rotating doors (ROTATING_DOORS): the radius of each circle of them (the
	## middle of its wall, between two rows), how wide each doorway is and how
	## thick and long its door, and each door: [circle, angle round, its turn at
	## time 0, which way it turns (1 or -1)].
	var door_radii: Array[float] = []
	var doorway := 0.0
	var door_thick := 0.0
	var door_long := 0.0
	var doors: Array = []

## The middle of the great wall the moor ends at (the first circle).
var inner_radius := 0.0
## The desert ring inside it: half the square maze's width, how it is made
## (Maze.desert_style), the square maze's ways out into it (a door into each
## quarter) and which way each goes, and the gates out of it through the first
## circle (one out of each quarter). `door` and `way_in` are the first.
var square_half := 0.0
var desert: DesertStyle
var doors: Array[Vector2] = []
var ways_in: Array[Vector2] = []
var door := Vector2.ZERO
var way_in := Vector2.RIGHT
var desert_gates: Array[float] = []
var noise_seed := 0
var _noise: FastNoiseLite
# Where the dunes are level: round the doors and the gates.
var _level: Array[Vector2] = []
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
	made.square_half = half
	made.desert = maze.desert_style if maze.desert_style else DesertStyle.new()
	made.inner_radius = half * sqrt(2.0) + made.desert.desert_width
	made.noise_seed = maze.maze_seed
	# (the square maze's ways out, one into each quarter, and which way each goes;
	# `door` and `way_in` are the first)
	for way: Array in (maze.ways_out if not maze.ways_out.is_empty() else [[maze.exit, maze.exit_side]]):
		var step: Vector2i = way[1]
		var at := maze.world(way[0])
		made.doors.append(Vector2(at.x, at.z) + Vector2(step.x, step.y) * Maze.CELL * 0.5)
		made.ways_in.append(Vector2(step.x, step.y))
	made.door = made.doors[0]
	made.way_in = made.ways_in[0]
	var radius := made.inner_radius
	for k in count:
		var style: MazeStyle = maze.styles[maze.rings + k]
		var ring := Ring.new()
		ring.style = style
		ring.inner = radius
		ring.layout = (style as RoundStyle).layout if style is RoundStyle else RoundStyle.Layout.MAZE
		var wide := Maze.CELL * style.hallway_diameter_cells
		var row_count := maxi(style.section_width_cells / style.hallway_diameter_cells, 1)
		match ring.layout:
			RoundStyle.Layout.ROTATING_DOORS:
				# (a row for each hall round between the circles of doors)
				row_count = (style as RoundStyle).door_circles + 1
				wide = Maze.CELL * style.section_width_cells / row_count
			RoundStyle.Layout.TUNNEL:
				# (one row: the tunnel, wall middle to wall middle)
				row_count = 1
				wide = (style as RoundStyle).tunnel_width + MazeBuilder.RING_THICK
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
	# (the first circle's gates: one out of each quarter of the desert ring, about
	# the middle of it, well clear of the diagonal walls that part them)
	for side: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		gates.append(fposmod(side.angle() + made._rng.randf_range(-0.3, 0.3), TAU))
	made.desert_gates = gates.duplicate()
	for k in made.rings.size():
		gates = made._carve(made.rings[k], gates, k == made.rings.size() - 1)
	made.exit_angle = gates[0]
	return made


## The angles of the great walls across the desert from the square's corners to
## the first circle.
const DIAGONALS: Array[float] = [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
## How far from the doors and gates the dunes keep (level there), metres.
const LEVEL_ROUND := 45.0


## How high the dunes are at (x, z): only in a desert quarter (DesertStyle.Biome),
## nothing in the square maze or past the first circle, little near the walls, and
## level round the doors and gates.
func desert_height(x: float, z: float) -> float:
	if desert == null or desert.dune_height <= 0.0 or desert.biome_at(x, z) != DesertStyle.Biome.DESERT:
		return 0.0
	var p := Vector2(x, z)
	var from_square := maxf(absf(x), absf(z)) - square_half
	var from_circle := inner_radius - p.length()
	if from_square <= 0.0 or from_circle <= 0.0:
		return 0.0
	var shown := smoothstep(0.0, 60.0, from_square) * smoothstep(0.0, 60.0, from_circle)
	# (low by the diagonal walls, and level round the doors and gates)
	for a: float in DIAGONALS:
		var along := Vector2(cos(a), sin(a))
		shown *= smoothstep(8.0, 40.0, absf(p.cross(along)))
	if _level.is_empty():
		_level = doors.duplicate()
		for g: float in desert_gates:
			_level.append(Vector2(cos(g), sin(g)) * inner_radius)
	for spot: Vector2 in _level:
		shown *= smoothstep(LEVEL_ROUND * 0.3, LEVEL_ROUND, p.distance_to(spot))
	if shown <= 0.0:
		return 0.0
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = noise_seed
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0 / desert.dune_spacing
		_noise.fractal_octaves = 3
	# (ridged: sharp crests between broad hollows, as dunes)
	var ridge := 1.0 - absf(_noise.get_noise_2d(x, z * 0.6))
	return desert.dune_height * shown * ridge * ridge


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
	if ring.layout != RoundStyle.Layout.MAZE:
		return _open_up(ring, gates, last)
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
	_ways_out(ring, last)
	_clear_gaps(ring, ring.rows.size() - 1, ring.gates_out)
	return ring.gates_out


# The ways out of `ring`: into the next section, or (the last) out of the maze.
# (each in the middle of a cell of the last row)
func _ways_out(ring: Ring, last: bool) -> void:
	var outside: int = ring.rows.back()[2]
	var out_start := _rng.randi() % outside
	for g in (1 if last else GATES):
		var j := posmod(out_start + g * outside / GATES, outside)
		ring.gates_out.append((angle_of(j, outside) + angle_of(j + 1, outside)) * 0.5)


## A section that is not a maze (rotating doors, or a tunnel): nothing walls its
## cells apart (the doors open, in time, between its halls); its doors placed;
## its ways out picked.
func _open_up(ring: Ring, gates: Array[float], last: bool) -> Array[float]:
	ring.gates_in = gates
	for i in ring.rows.size():
		for j in ring.rows[i][2]:
			for next: Vector2i in _neighbours(ring, Vector2i(i, j)):
				ring.open[_key(Vector2i(i, j), next)] = true
	if ring.layout == RoundStyle.Layout.ROTATING_DOORS:
		var style := ring.style as RoundStyle
		ring.door_thick = clampf(style.maze_wall_diameter * 0.5, 0.8, 2.0)
		ring.doorway = style.door_gap_width * 2.0 + ring.door_thick
		# (a little short of the doorway, so that shut it clears the wall's ends)
		ring.door_long = ring.doorway - 0.3
		for c in ring.rows.size() - 1:
			ring.door_radii.append(ring.rows[c][1])
			# (each circle's doorways evenly round it, from a start of its own; its doors
			# all turning the same way, the next circle's the other, their turns spread
			# evenly over a half turn, so that one of them is always near open)
			var spread := _rng.randf() * PI
			var start := _rng.randf() * TAU
			var way := 1 if c % 2 == 0 else -1
			for n in style.door_count:
				ring.doors.append([c, fposmod(start + TAU * n / style.door_count, TAU), fposmod(spread + n * GOLDEN * PI, PI), way])
	_ways_out(ring, last)
	return ring.gates_out


## How far door `n` of `ring` has turned at `time` (seconds of the round, the
## same on every machine), radians from shut (along its circle): edge on (open)
## at a half turn, and so every half turn.
static func door_turn(ring: Ring, n: int, time: float) -> float:
	var door: Array = ring.doors[n]
	var style := ring.style as RoundStyle
	return fposmod(door[2] + door[3] * PI * time / style.door_turn_seconds, TAU)


## How wide the way through is either side of door `n` of `ring` at `time`,
## metres: from the wall's end to as far across the doorway as the door reaches.
static func door_gap(ring: Ring, n: int, time: float) -> float:
	var turn := door_turn(ring, n, time)
	var reach := ring.door_long * 0.5 * absf(cos(turn)) + ring.door_thick * 0.5 * absf(sin(turn))
	return maxf(ring.doorway * 0.5 - reach, 0.0)


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
