@tool
class_name ClearingStyle
extends Resource
## How the clearing is made (Maze.clearing_style; set in the editor through
## MazeLayout.clearing_style): a level middle with no trees in it, very gentle
## hills over the rest of the field, level again at the foot of its walls, stands
## of pines along the walls, and something different before each entrance (see
## entrances): dense woods round one, grass up to his chest round another, a
## marsh in front of another, and nothing at all near the last.

@export_group("Ground")
## No trees nearer the middle than this, metres.
@export_range(0.0, 250.0) var treeless_radius := 95.0
## The ground is level out to this far from the middle, metres, and rises into
## the hills over the hill rise distance past that.
@export_range(0.0, 250.0) var flat_radius := 70.0
@export_range(1.0, 200.0) var hill_rise_distance := 60.0
## How high the hills are at most, metres (0: the whole field level).
@export_range(0.0, 12.0) var hill_height := 4.0
## About how far apart the hills are, metres.
@export_range(20.0, 400.0) var hill_spacing := 150.0
## The ground is level this far out from the foot of the clearing's wall, and
## rises into the hills over the hill rise distance in from that.
@export_range(0.0, 80.0) var flat_border_width := 18.0

## What is in front of one of the clearing's entrances.
enum Entrance {
	## Nothing in particular: the field as anywhere else.
	PLAIN,
	## The woods, round it (woods density, woods size).
	WOODS,
	## Grass up to his chest round it (tall grass radius and height).
	TALL_GRASS,
	## Flooded: a marsh in front of it, pools and channels of standing water
	## between hummocks of wet ground, sedges growing up out of it (the marsh
	## settings).
	MARSH,
	## Clear: nothing near it at all, no trees nor bushes (clear radius).
	CLEAR,
}

@export_group("Entrances")
## What is in front of each of the clearing's entrances, in turn round them.
@export var entrances: Array[Entrance] = [Entrance.WOODS, Entrance.TALL_GRASS, Entrance.MARSH, Entrance.CLEAR]
## The tall grass in front of its entrance: a meadow of its own, this wide (its
## radius, metres), its middle this far in from the door, as high as this, in a
## hollow this deep (level again at the foot of the wall).
@export_range(5.0, 200.0) var tall_grass_radius := 75.0
@export_range(0.0, 200.0) var tall_grass_distance := 55.0
@export_range(0.5, 3.0) var tall_grass_height := 1.5
@export_range(0.0, 4.0) var tall_grass_hollow := 1.2
## How far round a clear entrance nothing grows but grass, metres.
@export_range(5.0, 200.0) var clear_radius := 75.0

@export_group("Marsh")
## The marsh in front of a flooded entrance: how wide it is along the wall, how
## far out into the clearing it reaches, and how far out from the wall it
## begins, metres. Its edge wanders in and out by up to 0.7 of the marsh ragged
## share of that.
@export_range(20.0, 400.0) var marsh_width := 190.0
@export_range(20.0, 250.0) var marsh_reach := 125.0
@export_range(0.0, 40.0) var marsh_distance := 3.0
@export_range(0.0, 1.0) var marsh_ragged := 0.5
## How much of it is open water (the rest wet ground standing up out of it, in
## hummocks and tussocks), and about how far apart the hummocks are, metres.
@export_range(0.0, 1.0) var marsh_water := 0.5
@export_range(2.0, 30.0) var marsh_hummock_size := 6.5
## How much of it is channels of water winding between the hummocks.
@export_range(0.0, 1.0) var marsh_channels := 0.6
## How deep its shallow water is at most, and its deep dark pools (over his
## head: he swims), metres; and how much of it is deep pools.
@export_range(0.05, 1.0) var marsh_shallow_depth := 0.45
@export_range(0.3, 4.0) var marsh_pool_depth := 1.6
@export_range(0.0, 0.4) var marsh_deep_pools := 0.08
## The sedges growing over it, up out of the water: how tall, and how deep the
## water may be that they still grow up out of, metres (none in deeper pools).
@export_range(0.3, 2.5) var marsh_grass_height := 0.95
@export_range(0.05, 1.5) var marsh_grass_depth := 0.55
## Reeds and bulrushes, in clumps along the edges of the pools (0 none, 1
## many); and lily pads on the open water.
@export_range(0.0, 1.0) var marsh_reeds := 0.5
@export_range(0.0, 1.0) var marsh_lily_pads := 0.5

## How high the marsh's water stands (under the level ground round it), metres.
const MARSH_LEVEL := -0.25
## Nothing deep, and no reeds nor lily pads, in a lane this wide (each way) and
## this long out from the flooded entrance: the way in from its gate is open,
## though wet.
const MARSH_LANE := Vector2(5.0, 30.0)

## Where each entrance is, as Maze.generate found them: [the middle of the
## gateway at the inside face of the wall (x, z), the way into the clearing].
var entrance_spots: Array = []

@export_group("Woods")
## How thick the woods round their entrance are: 0 none, 1 a tree every woods tree spacing
## metres or so.
@export_range(0.0, 1.0) var woods_density := 0.85
## How far the woods reach out from their entrance, metres.
@export_range(20.0, 300.0) var woods_size := 185.0
## About how far apart the trees in the woods are, metres.
@export_range(3.0, 20.0) var woods_tree_spacing := 6.5

@export_group("Plants")
## Ferns round the foot of each pine, on average (more in the woods, where they stand close).
@export_range(0.0, 10.0) var ferns_per_tree := 2.5
## The chance of a cushion of moss at the foot of a pine.
@export_range(0.0, 1.0) var moss_per_tree_chance := 0.5
## Bushes over the field (none within the treeless radius), most of them near the trees.
@export_range(0, 400) var bush_count := 70

var _noise: FastNoiseLite
var _noise_seed := -1
var _marsh: FastNoiseLite
var _marsh_seed := -1

## How far in from the edge of the marsh's square (marsh_rect) the hills' coarse
## ground is sunk out of sight under its own (coarse_height_at), metres: more
## than a step of the hills' mesh.
const MARSH_COARSE_MARGIN := 4.0

## The names these settings had before (as saved in older mazes), and the new ones.
const RENAMED := {
	&"glade": &"treeless_radius", &"flat": &"flat_radius", &"rise": &"hill_rise_distance", &"hills": &"hill_height",
	&"hill_size": &"hill_spacing", &"wall_level": &"flat_border_width", &"woods": &"woods_density",
	&"woods_reach": &"woods_size", &"spacing": &"woods_tree_spacing", &"ferns": &"ferns_per_tree",
	&"moss": &"moss_per_tree_chance", &"bushes": &"bush_count",
}


# A maze saved with the old names still loads.
func _set(property: StringName, value: Variant) -> bool:
	if RENAMED.has(property):
		set(RENAMED[property], value)
		return true
	# (the round pond there was before the marsh: its settings are let go)
	if String(property).begins_with("pond_"):
		return true
	return false


## How high the ground is at (x, z), for a maze made from `seed_value`: 0 at the
## middle, at the foot of the clearing's walls and everywhere past them.
func height_at(x: float, z: float, seed_value: int) -> float:
	var hill := _hill_at(x, z, seed_value)
	# (the marsh: hummocks round its water, blended into the field at its edge)
	var wet := marsh_wet_at(Vector2(x, z), seed_value)
	if wet > 0.0:
		return lerpf(hill, MARSH_LEVEL + _marsh_lie(Vector2(x, z), wet, seed_value), wet)
	# (the tall grass in a hollow of its own, level at the foot of the wall)
	var meadow := tall_grass_middle()
	if meadow.is_finite() and tall_grass_hollow > 0.0:
		var d := Vector2(x, z).distance_to(meadow) / tall_grass_radius
		if d < 1.15:
			var half := Maze.CLEARING * Maze.CELL * 0.5
			var from_wall := half - maxf(absf(x), absf(z))
			var sunk := smoothstep(1.15, 0.85, d) * smoothstep(2.0, 16.0, from_wall)
			return lerpf(hill, -tall_grass_hollow, sunk)
	return hill


## The ground as the hills' mesh and heightmap have it, a point every few
## metres (MazeBuilder.HILL_STEP): as height_at, but sunk out of sight under the
## marsh, which has finer ground of its own over it (Marsh).
func coarse_height_at(x: float, z: float, seed_value: int) -> float:
	var marsh := marsh_rect()
	if marsh.has_area() and marsh.grow(-MARSH_COARSE_MARGIN).has_point(Vector2(x, z)):
		return MARSH_LEVEL - marsh_pool_depth - 1.0
	return height_at(x, z, seed_value)


## Whether the ground is anything but level: hills, a marsh or a hollow.
func shaped() -> bool:
	return hill_height > 0.0 or not entrance(Entrance.MARSH).is_empty() or (tall_grass_hollow > 0.0 and tall_grass_middle().is_finite())


## The first entrance with `kind` in front of it, as [where (x, z), the way in],
## or [] if none has.
func entrance(kind: Entrance) -> Array:
	for i in mini(entrances.size(), entrance_spots.size()):
		if entrances[i] == kind:
			return entrance_spots[i]
	return []


## The square (x, z) the marsh lies in, its ragged edge and all, or an empty one
## if there is none.
func marsh_rect() -> Rect2:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return Rect2()
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	var grown := 1.0 + marsh_ragged * 0.7
	var middle := gate + inward * (marsh_distance + marsh_reach * 0.5)
	var rect := Rect2(gate, Vector2.ZERO)
	for across: Vector2 in [side, -side]:
		rect = rect.expand(gate + across * marsh_width * 0.5 * grown)
		rect = rect.expand(middle + inward * marsh_reach * 0.5 * grown + across * marsh_width * 0.5 * grown)
	var half := Maze.CLEARING * Maze.CELL * 0.5
	return rect.grow(2.0).intersection(Rect2(-half, -half, half * 2.0, half * 2.0))


## How far into the marsh `point` (x, z) is: 1 well inside it, falling to 0 at
## its ragged edge and just out from the foot of the wall.
func marsh_wet_at(point: Vector2, seed_value: int) -> float:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return 0.0
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var out := (point - gate).dot(inward)
	if out <= marsh_distance:
		return 0.0
	var oval := _marsh_oval(point, way)
	if oval >= 1.0 + marsh_ragged * 0.7:
		return 0.0
	var noise := _marsh_noise(seed_value)
	var edge := clampf((noise.get_noise_2d(point.x / 55.0, point.y / 55.0) * 0.75 + noise.get_noise_2d(point.x / 17.0 + 50.0, point.y / 17.0) * 0.25) * 1.3, -1.0, 1.0)
	oval /= 1.0 + marsh_ragged * 0.7 * edge
	return smoothstep(1.0, 0.7, oval) * smoothstep(marsh_distance, marsh_distance + 7.0, out)


## How deep the marsh's water is over the ground at `point` (x, z), metres
## (less than 0 where the ground stands up out of it, or there is no marsh).
func marsh_depth_at(point: Vector2, seed_value: int) -> float:
	if marsh_wet_at(point, seed_value) <= 0.0:
		return -1.0
	return MARSH_LEVEL - height_at(point.x, point.y, seed_value)


## 1 in the lane out from the flooded entrance's gate (MARSH_LANE), where
## nothing deep is and nothing stands in the way, 0 out of it.
func marsh_lane_at(point: Vector2) -> float:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return 0.0
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(way[1])
	var along := absf(from_gate.dot((way[1] as Vector2).orthogonal()))
	if out < -2.0:
		return 0.0
	return (1.0 - smoothstep(MARSH_LANE.x, MARSH_LANE.x * 2.0, along)) * (1.0 - smoothstep(MARSH_LANE.y, MARSH_LANE.y * 1.5, out))


## Whether the clearing's knee high grass gives way at `point` (x, z) to the
## marsh's own sedges (Marsh): more and more of it towards the marsh, none
## well inside it.
func marsh_keeps_grass_out(point: Vector2, seed_value: int) -> bool:
	var wet := marsh_wet_at(point, seed_value)
	if wet <= 0.05:
		return false
	# (dithered, so that there is no line where the one gives way to the other)
	return wet > 0.08 + float(hash(point) & 1023) / 1023.0 * 0.35


## Whether `point` (x, z) is where no tree or bush may be: near a clear entrance,
## in the tall grass, or in or at the edge of the marsh.
func kept_clear(point: Vector2) -> bool:
	var clear := entrance(Entrance.CLEAR)
	if not clear.is_empty() and point.distance_to(clear[0]) < clear_radius:
		return true
	var meadow := tall_grass_middle()
	if meadow.is_finite() and point.distance_to(meadow) < tall_grass_radius * 1.05:
		return true
	var marsh := entrance(Entrance.MARSH)
	return not marsh.is_empty() and _marsh_oval(point, marsh) < 1.0 + marsh_ragged * 0.7 + 0.1


## How much tall grass there is at `point` (x, z): 1 in the meadow in front of a
## tall grass entrance, none past its edge.
func tall_grass_at(point: Vector2) -> float:
	var meadow := tall_grass_middle()
	if not meadow.is_finite():
		return 0.0
	# (a meadow of its own: its edge sharp, where the hollow begins)
	return smoothstep(1.02, 0.95, point.distance_to(meadow) / tall_grass_radius)


## The middle of the tall grass (x, z), or not finite if there is none.
func tall_grass_middle() -> Vector2:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return Vector2.INF
	return way[0] + way[1] * tall_grass_distance


func _hill_at(x: float, z: float, seed_value: int) -> float:
	if hill_height <= 0.0:
		return 0.0
	var half := Maze.CLEARING * Maze.CELL * 0.5
	var from_wall := half - maxf(absf(x), absf(z))
	if from_wall <= flat_border_width:
		return 0.0
	var from_middle := Vector2(x, z).length()
	if from_middle <= flat_radius:
		return 0.0
	var shown := smoothstep(flat_radius, flat_radius + hill_rise_distance, from_middle) * smoothstep(flat_border_width, flat_border_width + hill_rise_distance, from_wall)
	return hill_height * shown * (_hill_noise(seed_value).get_noise_2d(x, z) * 0.5 + 0.5)


func _hill_noise(seed_value: int) -> FastNoiseLite:
	if _noise == null or _noise_seed != seed_value:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = seed_value
		_noise.frequency = 1.0 / hill_spacing
		_noise.fractal_octaves = 2
		_noise_seed = seed_value
	return _noise


# How far out in the marsh's oval `point` is (1 at its edge before it is made
# ragged), for the marsh entrance `way`; INF behind its gate.
func _marsh_oval(point: Vector2, way: Array) -> float:
	var inward: Vector2 = way[1]
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(inward)
	if out < 0.0:
		return INF
	var half_reach := marsh_reach * 0.5
	return Vector2((out - marsh_distance - half_reach) / half_reach, from_gate.dot(inward.orthogonal()) / (marsh_width * 0.5)).length()


# How high the marsh's ground stands over its water at `point` (less than 0
# under it): hummocks and tussocks standing up out of shallow water, channels
# winding between them, and a few deep pools; drier towards its edge, as `wet`
# falls (marsh_wet_at).
func _marsh_lie(point: Vector2, wet: float, seed_value: int) -> float:
	var noise := _marsh_noise(seed_value)
	var p := point / marsh_hummock_size
	var lumps := noise.get_noise_2d(p.x, p.y) * 0.65 + noise.get_noise_2d(p.x * 2.3 + 17.0, p.y * 2.3 - 5.0) * 0.35
	var lie := lumps * 0.5 + 0.5
	# (channels: where a slower noise crosses its middle, in winding lines)
	var wander := absf(noise.get_noise_2d(p.x * 0.26 - 40.0, p.y * 0.26 + 23.0))
	lie -= (1.0 - smoothstep(0.02, 0.15, wander)) * marsh_channels * 0.5
	# (the water standing over about the share of it asked for; less near its
	# edge; and over broad stretches more of it, open meres, or less, flats of
	# tussocks, so that it is not the same all over)
	var broad := noise.get_noise_2d(point.x / 42.0 - 70.0, point.y / 42.0 + 12.0)
	var level := 0.5 + (marsh_water - 0.5) * 0.5 - (1.0 - wet) * 0.35 + broad * 0.2
	var over := lie - level
	var height := 0.42 * (1.0 - exp(-over * 4.0)) if over > 0.0 else -marsh_shallow_depth * (1.0 - exp(over * 5.0))
	# (the deep pools: well inside it, never in the lane in from the gate)
	var deep := noise.get_noise_2d(point.x / 26.0 + 80.0, point.y / 26.0 - 31.0) * 0.5 + 0.5
	var start := 0.84 - marsh_deep_pools * 1.2
	var sunk := smoothstep(start, start + 0.12, deep) * smoothstep(0.55, 0.9, wet) * (1.0 - marsh_lane_at(point))
	return lerpf(height, minf(height, -marsh_pool_depth), sunk)


func _marsh_noise(seed_value: int) -> FastNoiseLite:
	if _marsh == null or _marsh_seed != seed_value:
		_marsh = FastNoiseLite.new()
		_marsh.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_marsh.seed = seed_value + 7
		_marsh.frequency = 1.0
		_marsh.fractal_type = FastNoiseLite.FRACTAL_NONE
		_marsh_seed = seed_value
	return _marsh
