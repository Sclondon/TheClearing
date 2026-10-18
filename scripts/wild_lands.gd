@tool
class_name WildLands
extends RefCounted
## What is in the desert ring's quarters that are not desert (DesertStyle.Biome),
## worked out from the maze's seed and the DesertStyle settings: the same for
## every copy of the game in a room. Wilds builds it near the camera.
##
## - FOREST: dense woods of pines on dark ground, with ferns, bushes and moss
##   under them, fallen logs and a few mossy boulders, and open glades.
## - SWAMP: one sheet of still water over the middle of the quarter (`pools`),
##   that hummocks of wet ground stand up through, cut by winding channels, its
##   edges dry boggy ground; sedges all over it, reeds and bulrushes along the
##   water's edge, lily pads on it, dead and drowned trees, and banks of mist.
## - PLAINS: wide grass over low hills, boulders and outcrops of great rocks.
##
## Everything stands inside its quarter's wedge (between the square maze's outer
## wall, the diagonal walls from its corners and the first circle), and nothing
## that is in the way stands near a quarter's way in (RoundMaze.doors) or out
## (RoundMaze.desert_gates). The ground's heights (`height_at`) are the plan's:
## Maze.ground_height asks them.
##
## The quarters are worked out in squares of SQUARE metres (`contents`), each
## from its own seed, so any square can be had on its own, in any order.

const SQUARE := 64.0
## Nothing stands nearer the walls round its quarter than this, metres (from the
## walls' middles), past its own size.
const WALL_MARGIN := 4.0
## The swamp's water keeps this far in from the walls round its quarter, metres.
const POOL_MARGIN := 18.0
## Metres between the points of the ground over a swamp square, and a plains one.
const SWAMP_STEP := 2.0
const PLAINS_STEP := 4.0
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var plan: RoundMaze
var look: DesertStyle
var seed_value := 0
## The swamp quarters' water: quarter -> Rect2 (x, z) it covers.
var pools := {}
## The doors and gates (x, z), which nothing stands near.
var ways: Array[Vector2] = []

var _hills: FastNoiseLite
var _hummocks: FastNoiseLite
var _tussocks: FastNoiseLite
var _channels: FastNoiseLite
var _glades: FastNoiseLite
var _clumps: FastNoiseLite
var _cache := {}
var _trees_cache := {}
var _grids := {}
var _steps := {}


static func make(round_plan: RoundMaze, seed_number: int) -> WildLands:
	var made := WildLands.new()
	made.plan = round_plan
	made.look = round_plan.desert
	made.seed_value = seed_number
	made.ways = round_plan.doors.duplicate()
	for g: float in round_plan.desert_gates:
		made.ways.append(Vector2.from_angle(g) * round_plan.inner_radius)
	var noise := func(salt: int, frequency: float, octaves: int) -> FastNoiseLite:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = seed_number * 31 + salt
		n.frequency = frequency
		n.fractal_octaves = octaves
		if octaves <= 1:
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
		return n
	made._hills = noise.call(1, 1.0 / made.look.plains_hill_spacing, 3)
	made._hummocks = noise.call(2, 1.0 / made.look.swamp_hummock_size, 2)
	made._tussocks = noise.call(3, 0.45, 1)
	made._channels = noise.call(4, 1.0 / 70.0, 2)
	made._glades = noise.call(5, 1.0 / 60.0, 2)
	made._clumps = noise.call(6, 1.0 / 9.0, 1)
	for side in SIDES:
		if made.look.biome_of(side) == DesertStyle.Biome.SWAMP:
			made.pools[side] = made._pool_rect(Vector2(side))
	return made


## The rectangle of water over a swamp quarter (on side `side`): as wide as the
## square maze, from a little out from it to a little in from the first circle.
func _pool_rect(side: Vector2) -> Rect2:
	var half := plan.square_half - POOL_MARGIN
	var near := plan.square_half + POOL_MARGIN
	var far := sqrt(pow(plan.inner_radius - POOL_MARGIN, 2.0) - half * half)
	var across := Vector2(-side.y, side.x)
	var a := side * near + across * half
	var b := side * far - across * half
	return Rect2(a, Vector2.ZERO).expand(b)


# --- Where things are ---------------------------------------------------------

## What the quarter `p` is in is (DesertStyle.Biome).
func biome_at(p: Vector2) -> DesertStyle.Biome:
	return look.biome_of(DesertStyle.quarter_at(p.x, p.y))


## How far `p` is in from the nearest wall round its quarter's wedge (the
## diagonal walls, the square maze's outer wall, the first circle), metres;
## less than 0 outside it.
func margin_at(p: Vector2) -> float:
	var side := Vector2(DesertStyle.quarter_at(p.x, p.y))
	var along := p.dot(side)
	var across := absf(p.dot(Vector2(-side.y, side.x)))
	return minf(minf((along - across) * sqrt(0.5), along - plan.square_half), plan.inner_radius - p.length())


## How far `p` is from the nearest door or gate, metres.
func ways_distance(p: Vector2) -> float:
	var nearest := INF
	for way in ways:
		nearest = minf(nearest, p.distance_squared_to(way))
	return sqrt(nearest)


## Whether something `radius` metres across stands at `p` in a quarter of
## `biome`, inside its wedge, and (if it is in the way) clear of the doors and gates.
func fits(p: Vector2, biome: DesertStyle.Biome, radius: float, in_the_way := true) -> bool:
	if biome_at(p) != biome or margin_at(p) < WALL_MARGIN + radius:
		return false
	return not in_the_way or ways_distance(p) >= look.keep_clear_radius + radius


## The biomes a square has ground of (not desert), as an Array.
func biomes_in(square: Vector2i) -> Array:
	var found := []
	var origin := Vector2(square) * SQUARE
	for j in 3:
		for i in 3:
			var p := origin + Vector2(i, j) * SQUARE * 0.5
			var biome := biome_at(p)
			if biome != DesertStyle.Biome.DESERT and margin_at(p) > -SQUARE * 0.75 and not found.has(biome):
				found.append(biome)
	return found


## Every square that has ground of a quarter that is not desert.
func squares() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var reach := ceili(plan.inner_radius / SQUARE)
	for j in range(-reach, reach):
		for i in range(-reach, reach):
			var square := Vector2i(i, j)
			var middle := (Vector2(square) + Vector2(0.5, 0.5)) * SQUARE
			# (near enough the ring: within a square's diagonal of it)
			if maxf(absf(middle.x), absf(middle.y)) < plan.square_half - SQUARE or middle.length() > plan.inner_radius + SQUARE:
				continue
			if not biomes_in(square).is_empty():
				found.append(square)
	return found


# --- The ground ---------------------------------------------------------------

## How high the ground is at (x, z): the swamp's hummocks and the plains' hills
## (0 in a forest or desert quarter, and outside the ring).
func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var biome := biome_at(p)
	if biome != DesertStyle.Biome.SWAMP and biome != DesertStyle.Biome.PLAINS:
		return 0.0
	var margin := margin_at(p)
	if margin <= 0.0:
		return 0.0
	if biome == DesertStyle.Biome.SWAMP:
		return _swamp_height(p, margin)
	return _plains_height(p, margin)


## How high the swamp's water stands (over the level ground under it).
func water_level() -> float:
	return look.swamp_water_depth


## How far into the open water of its swamp `p` is (0 on the dry ground round
## its edges, 1 well in), with ragged edges.
func wet_at(p: Vector2) -> float:
	var pool: Variant = pools.get(DesertStyle.quarter_at(p.x, p.y))
	if pool == null:
		return 0.0
	var rect: Rect2 = pool
	var inside := minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y))
	if inside <= 0.0:
		return 0.0
	if inside >= 40.0:
		return 1.0
	var ragged := _glades.get_noise_2d(p.x * 1.7 + 400.0, p.y * 1.7)
	return smoothstep(0.0, 6.0, inside) * clampf((inside - 10.0 + ragged * 30.0) / 30.0, 0.0, 1.0)


func _swamp_height(p: Vector2, margin: float) -> float:
	var level := look.swamp_water_depth
	var lump := _hummocks.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	var tussock := _tussocks.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	# (dry boggy ground round the edges, standing a hand or two over the water)
	var bank := level + 0.1 + 0.25 * lump + 0.1 * tussock
	var ground := bank
	var wet := wet_at(p)
	if wet > 0.0:
		# Over the water by as much as the hummocks rise over the share of open
		# water, cut by winding channels.
		var over := (lump - look.swamp_water) * 1.4 + (tussock - 0.5) * 0.18
		var channel := 1.0 - smoothstep(0.025, 0.07, absf(_channels.get_noise_2d(p.x, p.y)))
		over -= channel * 0.7
		ground = lerpf(bank, clampf(level + over, 0.0, level + 0.6), wet)
	# (down to the level ground under the walls round it)
	return ground * smoothstep(1.0, 4.0, margin)


func _plains_height(p: Vector2, margin: float) -> float:
	var hill := _hills.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	var shown := smoothstep(0.0, 60.0, margin - 2.0) * smoothstep(look.keep_clear_radius, look.keep_clear_radius + 50.0, ways_distance(p))
	return look.plains_hill_height * pow(hill, 1.6) * shown


## Metres between the points of a square's ground: fine where it has swamp.
func step_of(square: Vector2i) -> float:
	if not _steps.has(square):
		_steps[square] = SWAMP_STEP if biomes_in(square).has(DesertStyle.Biome.SWAMP) else PLAINS_STEP
	return _steps[square]


## The heights of a square's ground (height_at), on a grid of step_of(square)
## metres, (SQUARE / step + 1) points each way, row by row from its corner
## (made once, and kept).
func grid(square: Vector2i) -> PackedFloat32Array:
	if _grids.has(square):
		return _grids[square]
	var step := step_of(square)
	var across := roundi(SQUARE / step) + 1
	var origin := Vector2(square) * SQUARE
	var heights := PackedFloat32Array()
	heights.resize(across * across)
	# (a square wholly in a swamp, well in from its walls, as most are: the
	# swamp's heights straight, without asking where each point is)
	var inner := interior(square)
	for j in across:
		for i in across:
			var p := Vector2(origin.x + i * step, origin.y + j * step)
			heights[i + j * across] = _swamp_height(p, 10.0) if inner == DesertStyle.Biome.SWAMP else height_at(p.x, p.y)
	_grids[square] = heights
	return heights


## The biome a square is wholly in, at least 6 m in from the walls round it
## (the least is at one of its corners: the wedge is the meeting of halves and a
## disc), or -1.
func interior(square: Vector2i) -> int:
	var origin := Vector2(square) * SQUARE
	var biome := -1
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := origin + corner * SQUARE
		var here := biome_at(p)
		if (biome != -1 and here != biome) or margin_at(p) < 6.0:
			return -1
		biome = here
	return biome


## The ground's height at `p`, from its square's grid if it has been made (as
## the ground is drawn and walked on), else worked out.
func ground_at(p: Vector2) -> float:
	var square := Vector2i((p / SQUARE).floor())
	if not _grids.has(square):
		return height_at(p.x, p.y)
	var heights: PackedFloat32Array = _grids[square]
	var step := step_of(square)
	var across := roundi(SQUARE / step) + 1
	var f := (p - Vector2(square) * SQUARE) / step
	var i := clampi(floori(f.x), 0, across - 2)
	var j := clampi(floori(f.y), 0, across - 2)
	var u := clampf(f.x - i, 0.0, 1.0)
	var v := clampf(f.y - j, 0.0, 1.0)
	var at := i + j * across
	return lerpf(lerpf(heights[at], heights[at + 1], u), lerpf(heights[at + across], heights[at + across + 1], u), v)


# --- What stands on it ----------------------------------------------------------

## The chance of a tuft of sedge at `p` in a swamp: thick on the hummocks and the
## dry ground, thinner standing up out of the water, none where it is deep.
func sedge_at(p: Vector2) -> float:
	if biome_at(p) != DesertStyle.Biome.SWAMP or margin_at(p) < 2.5:
		return 0.0
	var depth := water_level() - ground_at(p)
	var gaps := smoothstep(0.3, 0.6, _clumps.get_noise_2d(p.x * 0.8 - 200.0, p.y * 0.8 + 90.0) * 0.5 + 0.5)
	var in_water := lerpf(0.4, 0.08, smoothstep(0.06, 0.3, depth)) * lerpf(1.0, 0.25, gaps)
	var bank := 0.5
	return lerpf(bank, in_water, smoothstep(-0.06, 0.06, depth))


## The chance of a tuft of reeds at `p` in a swamp: in clumps along the water's edge.
func reed_at(p: Vector2) -> float:
	if look.swamp_reeds <= 0.0 or biome_at(p) != DesertStyle.Biome.SWAMP or margin_at(p) < 2.5:
		return 0.0
	var depth := water_level() - ground_at(p)
	var edge := smoothstep(-0.12, 0.0, depth) * (1.0 - smoothstep(0.22, 0.36, depth))
	var start := 0.75 - look.swamp_reeds * 0.45
	return edge * smoothstep(start, start + 0.1, _clumps.get_noise_2d(p.x, p.y) * 0.5 + 0.5)


## The chance of a tuft of grass at `p` on the plains: everywhere in its wedge
## but under the rocks.
func plains_grass_at(p: Vector2) -> float:
	if biome_at(p) != DesertStyle.Biome.PLAINS or margin_at(p) < 2.5:
		return 0.0
	return 0.0 if under_rock(p) else 1.0


## Whether `p` is under one of the rocks (of its square or those next to it).
func under_rock(p: Vector2) -> bool:
	var square := Vector2i((p / SQUARE).floor())
	for j in range(-1, 2):
		for i in range(-1, 2):
			for rock: Array in contents(square + Vector2i(i, j)).rocks:
				var at: Vector3 = (rock[0] as Transform3D).origin
				var r: float = rock[2] * 0.85
				if Vector2(at.x - p.x, at.z - p.y).length_squared() < r * r:
					return true
	return false


## What stands in square `square` (made once, and kept), as Arrays:
## - trees: [Transform3D, variant, trunk radius], pines at their foot;
## - snags: [Transform3D, variant, radius], dead trees (a mesh 1 m tall, scaled);
## - logs: [Transform3D, length, radius], a log along x (a mesh 1 m long, 1 m round);
## - rocks: [Transform3D, variant, radius, mossy];
## - plants: {Undergrowth.Kind: [Transform3D]};
## - rushes: {Marsh.Bulrush: [Transform3D]}; pads: [[Transform3D, Color]];
## - mist: [Transform3D] (its x how wide, y how high), at its foot;
## - blockers: [Vector2, radius], all that stands in the way.
func contents(square: Vector2i) -> Dictionary:
	if _cache.has(square):
		return _cache[square]
	var made := {"trees": [], "snags": [], "logs": [], "rocks": [], "plants": {}, "rushes": {}, "pads": [], "mist": [], "blockers": []}
	_cache[square] = made
	var biomes := biomes_in(square)
	if biomes.has(DesertStyle.Biome.FOREST):
		_forest(square, made)
	if biomes.has(DesertStyle.Biome.SWAMP):
		_swamp(square, made)
	if biomes.has(DesertStyle.Biome.PLAINS):
		_plains(square, made)
	return made


func _rng(salt: int, where: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, salt, where.x, where.y])
	return rng


static func _put(list: Dictionary, kind: int, where: Transform3D) -> void:
	if not list.has(kind):
		list[kind] = []
	(list[kind] as Array).append(where)


static func _standing(at: Vector3, rng: RandomNumberGenerator, big: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * big), at)


## The pines in a square: one in each cell of a grid `forest_tree_spacing`
## apart over the whole forest, put at random in it (so a cell on a square's
## edge is the same tree from either side), fewer in the glades.
func trees_in(square: Vector2i) -> Array:
	if _trees_cache.has(square):
		return _trees_cache[square]
	var found := []
	_trees_cache[square] = found
	var spacing := look.forest_tree_spacing
	var rect := Rect2(Vector2(square) * SQUARE, Vector2.ONE * SQUARE)
	var first := Vector2i((rect.position / spacing).floor())
	var last := Vector2i((rect.end / spacing).ceil())
	var rng := RandomNumberGenerator.new()
	for cy in range(first.y, last.y):
		for cx in range(first.x, last.x):
			rng.seed = hash([seed_value, 11, cx, cy])
			var p := (Vector2(cx, cy) + Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))) * spacing
			if not rect.has_point(p):
				continue
			var chance := look.forest_density * (1.0 - glade_at(p))
			if rng.randf() >= chance:
				continue
			var big := rng.randf_range(0.7, 1.3)
			var trunk := 0.26 * big
			if not fits(p, DesertStyle.Biome.FOREST, trunk + 1.0):
				continue
			var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.05))
			var basis := tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(big, big * rng.randf_range(0.9, 1.15), big))
			found.append([Transform3D(basis, Vector3(p.x, -0.1, p.y)), rng.randi() % 2, trunk])
	return found


## How open the forest is at `p` (1 in the middle of a glade).
func glade_at(p: Vector2) -> float:
	var open := _glades.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	var start := 1.0 - look.forest_glades
	return smoothstep(start - 0.06, start + 0.06, open)


func _forest(square: Vector2i, made: Dictionary) -> void:
	var rng := _rng(12, square)
	var origin := Vector2(square) * SQUARE
	var hectares := SQUARE * SQUARE / 10000.0
	var trees := trees_in(square)
	for tree: Array in trees:
		var foot: Vector3 = (tree[0] as Transform3D).origin
		made.trees.append(tree)
		made.blockers.append([Vector2(foot.x, foot.z), tree[2]])
		var ferns := int(look.forest_ferns_per_tree) + (1 if rng.randf() < fmod(look.forest_ferns_per_tree, 1.0) else 0)
		for f in ferns:
			var round_about := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 4.0)
			var p := Vector2(foot.x, foot.z) + round_about
			if fits(p, DesertStyle.Biome.FOREST, 0.5, false):
				_put(made.plants, Undergrowth.Kind.FERN, _standing(Vector3(p.x, 0.0, p.y), rng, rng.randf_range(1.0, 1.9)))
		if rng.randf() < look.forest_moss_chance:
			var p := Vector2(foot.x, foot.z) + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			_put(made.plants, Undergrowth.Kind.MOSS, _standing(Vector3(p.x, 0.0, p.y), rng, rng.randf_range(1.2, 2.6)))
	# Bushes, most in the open (glades and between the trees), and tufts of grass in the glades.
	for b in _count(look.forest_bushes * hectares, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		if fits(p, DesertStyle.Biome.FOREST, 1.0, false) and ways_distance(p) > 8.0:
			_put(made.plants, Undergrowth.Kind.BUSH, _standing(Vector3(p.x, 0.0, p.y), rng, rng.randf_range(0.9, 1.8)))
	for t in _count(30.0 * hectares, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		if glade_at(p) > 0.4 and fits(p, DesertStyle.Biome.FOREST, 0.5, false):
			_put(made.plants, Undergrowth.Kind.TUFT, _standing(Vector3(p.x, 0.0, p.y), rng, rng.randf_range(1.0, 1.7)))
	# Fallen logs, lying where no tree stands in their way.
	var near_trees := []
	for j in range(-1, 2):
		for i in range(-1, 2):
			near_trees.append_array(trees_in(square + Vector2i(i, j)))
	for l in _count(look.forest_logs * hectares, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		var length := rng.randf_range(4.0, 11.0)
		var radius := rng.randf_range(0.22, 0.42)
		if not fits(p, DesertStyle.Biome.FOREST, length * 0.5 + 0.5):
			continue
		var way := Vector2.from_angle(rng.randf() * TAU)
		var clear := true
		for tree: Array in near_trees:
			var foot: Vector3 = (tree[0] as Transform3D).origin
			var d := Geometry2D.get_closest_point_to_segment(Vector2(foot.x, foot.z), p - way * length * 0.5, p + way * length * 0.5).distance_to(Vector2(foot.x, foot.z))
			if d < radius + tree[2] + 0.3:
				clear = false
				break
		if not clear:
			continue
		made.logs.append([_log(p, way, length, radius, 0.0), length, radius])
		for k in 3:
			made.blockers.append([p + way * length * (k - 1) * 0.35, radius])
		if rng.randf() < 0.6:
			_put(made.plants, Undergrowth.Kind.MOSS, _standing(Vector3(p.x, 0.0, p.y) + Vector3(way.x, 0.0, way.y) * rng.randf_range(-1.0, 1.0) + Vector3(-way.y, 0.0, way.x) * radius, rng, rng.randf_range(0.8, 1.4)))
	for r in _count(look.forest_boulders * hectares, rng):
		_rock(origin + Vector2(rng.randf(), rng.randf()) * SQUARE, rng.randf_range(0.8, 2.2), DesertStyle.Biome.FOREST, true, rng, made)


## A log `length` long and `radius` round lying along `way` with its middle at `p`.
func _log(p: Vector2, way: Vector2, length: float, radius: float, ground: float) -> Transform3D:
	var along := Vector3(way.x, 0.0, way.y)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP)).scaled(Vector3(length, radius, radius))
	return Transform3D(basis, Vector3(p.x, ground + radius * 0.75, p.y))


## A rock about `size` metres round at `p`, sunk a little into the ground, if it fits there.
func _rock(p: Vector2, size: float, biome: DesertStyle.Biome, mossy: bool, rng: RandomNumberGenerator, made: Dictionary) -> bool:
	if not fits(p, biome, size):
		return false
	var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.25))
	var basis := tilt * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.55, 0.9), size * rng.randf_range(0.75, 1.0)))
	var y := height_at(p.x, p.y) - size * 0.2
	made.rocks.append([Transform3D(basis, Vector3(p.x, y, p.y)), rng.randi() % Wilds.ROCK_VARIANTS, size, mossy])
	made.blockers.append([p, size * 0.8])
	return true


## How many of something there are where `amount` are wanted on average.
static func _count(amount: float, rng: RandomNumberGenerator) -> int:
	return int(amount) + (1 if rng.randf() < fmod(amount, 1.0) else 0)


func _swamp(square: Vector2i, made: Dictionary) -> void:
	var rng := _rng(21, square)
	var origin := Vector2(square) * SQUARE
	var hectares := SQUARE * SQUARE / 10000.0
	var level := water_level()
	grid(square)
	# Dead and drowned trees: grey snags, some leant over, some broken off short.
	for s in _count(look.swamp_dead_trees * hectares, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		var broken := rng.randf() < 0.3
		var tall := rng.randf_range(1.5, 3.5) if broken else rng.randf_range(5.0, 13.0)
		var radius := tall * 0.03 if not broken else rng.randf_range(0.25, 0.4)
		if not fits(p, DesertStyle.Biome.SWAMP, radius + 0.5):
			continue
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.22 if rng.randf() < 0.3 else 0.06))
		var basis := lean * Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(radius / 0.03, tall, radius / 0.03) if broken else Vector3.ONE * tall)
		made.snags.append([Transform3D(basis, Vector3(p.x, ground_at(p) - 0.15, p.y)), 2 if broken else rng.randi() % 2, radius])
		made.blockers.append([p, radius])
	# Bulrushes along the water's edge, lily pads on the open water, tufts on the hummocks.
	const SPACING := 1.8
	var steps := roundi(SQUARE / SPACING)
	var inner := interior(square) == DesertStyle.Biome.SWAMP
	var start := 0.75 - look.swamp_reeds * 0.45
	for j in steps:
		for i in steps:
			var p := origin + (Vector2(i, j) + Vector2(rng.randf(), rng.randf())) * SPACING
			var roll := rng.randf()
			if not inner and (biome_at(p) != DesertStyle.Biome.SWAMP or margin_at(p) < 3.0):
				continue
			var y := ground_at(p)
			var depth := level - y
			# (reeds: in clumps along the water's edge, as reed_at)
			var reedy := 0.0
			var edge := smoothstep(-0.12, 0.0, depth) * (1.0 - smoothstep(0.22, 0.36, depth))
			if edge > 0.0 and look.swamp_reeds > 0.0:
				reedy = edge * smoothstep(start, start + 0.1, _clumps.get_noise_2d(p.x, p.y) * 0.5 + 0.5)
			if reedy > 0.0 and roll < reedy * look.swamp_reeds * 0.5:
				var pick := rng.randf()
				var kind := Marsh.Bulrush.UPRIGHT if pick < 0.74 else (Marsh.Bulrush.SEEDING if pick < 0.88 else Marsh.Bulrush.BROKEN)
				var tilt := 0.35 if pick < 0.14 else 0.08
				var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.2, 1.0) * tilt
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				if lean.length() > 0.001:
					basis = Basis(lean.cross(Vector3.UP).normalized(), lean.length()) * basis
				_put(made.rushes, kind, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.75, 1.15)), Vector3(p.x, y - 0.05, p.y)))
				continue
			if depth > 0.2 and look.swamp_lily_pads > 0.0:
				var gather := _clumps.get_noise_2d(p.x * 1.7 + 300.0, p.y * 1.7 - 120.0) * 0.5 + 0.5
				var first := 0.8 - look.swamp_lily_pads * 0.3
				if roll < smoothstep(first, first + 0.12, gather) * 0.8:
					var size := rng.randf_range(0.16, 0.36)
					var tone := rng.randf()
					made.pads.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, 1.0, size)), Vector3(p.x, level + 0.012, p.y)),
						Color(0.15, 0.22, 0.09) if tone < 0.7 else (Color(0.3, 0.29, 0.12) if tone < 0.9 else Color(0.24, 0.15, 0.08))])
				continue
			if depth < -0.08 and roll < 0.035:
				_put(made.plants, Undergrowth.Kind.TUFT if rng.randf() < 0.7 else Undergrowth.Kind.MOSS, _standing(Vector3(p.x, y, p.y), rng, rng.randf_range(1.0, 1.8)))
	# Banks of mist lying low, most of all over the water.
	for m in _count(look.swamp_mist * 6.0, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		if biome_at(p) != DesertStyle.Biome.SWAMP or margin_at(p) < 15.0:
			continue
		if wet_at(p) < 0.2 and rng.randf() < 0.6:
			continue
		var wide := rng.randf_range(30.0, 60.0)
		made.mist.append(Transform3D(Basis.from_scale(Vector3(wide, rng.randf_range(3.0, 7.0), wide)), Vector3(p.x, level - 0.5, p.y)))


func _plains(square: Vector2i, made: Dictionary) -> void:
	var rng := _rng(31, square)
	var origin := Vector2(square) * SQUARE
	var hectares := SQUARE * SQUARE / 10000.0
	for b in _count(look.plains_boulders * hectares, rng):
		var p := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		var size := rng.randf_range(0.6, 2.4) * (2.0 if rng.randf() < 0.15 else 1.0)
		if _rock(p, size, DesertStyle.Biome.PLAINS, false, rng, made) and rng.randf() < 0.5:
			# (a tuft or two of rougher grass round its foot)
			for t in 2:
				var q := p + Vector2.from_angle(rng.randf() * TAU) * size * rng.randf_range(0.9, 1.3)
				if fits(q, DesertStyle.Biome.PLAINS, 0.3, false):
					_put(made.plants, Undergrowth.Kind.TUFT, _standing(Vector3(q.x, height_at(q.x, q.y), q.y), rng, rng.randf_range(1.0, 1.6)))
	# Outcrops: a clump of great rocks, the biggest as high as a house, round a middle.
	for o in _count(look.plains_outcrops * hectares, rng):
		var middle := origin + Vector2(rng.randf(), rng.randf()) * SQUARE
		if not fits(middle, DesertStyle.Biome.PLAINS, 18.0):
			continue
		var count := rng.randi_range(4, 9)
		for k in count:
			var size := rng.randf_range(6.0, 12.0) if k == 0 else rng.randf_range(1.5, 6.5)
			var p := middle if k == 0 else middle + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 13.0)
			_rock(p, size, DesertStyle.Biome.PLAINS, false, rng, made)
		for t in rng.randi_range(2, 6):
			var q := middle + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 13.0)
			if fits(q, DesertStyle.Biome.PLAINS, 0.5, false):
				_put(made.plants, Undergrowth.Kind.BUSH if rng.randf() < 0.4 else Undergrowth.Kind.TUFT, _standing(Vector3(q.x, height_at(q.x, q.y), q.y), rng, rng.randf_range(0.9, 1.5)))
