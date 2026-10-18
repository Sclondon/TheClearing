@tool
class_name ClearingStyle
extends Resource
## How the clearing is made (Maze.clearing_style; set in the editor through
## MazeLayout.clearing_style): a level middle with no trees in it, very gentle
## hills over the rest of the field, level again at the foot of its walls, stands
## of pines along the walls, and something different before each entrance (see
## entrances): dense woods round one, grass up to his chest round another, a pond
## in front of another, and nothing at all near the last.

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
	## Flooded: a pond in front of it (pond radius, depth and distance).
	POND,
	## Clear: nothing near it at all, no trees nor bushes (clear radius).
	CLEAR,
}

@export_group("Entrances")
## What is in front of each of the clearing's entrances, in turn round them.
@export var entrances: Array[Entrance] = [Entrance.WOODS, Entrance.TALL_GRASS, Entrance.POND, Entrance.CLEAR]
## How far round a tall grass entrance the tall grass grows, metres, and how high it is.
@export_range(5.0, 150.0) var tall_grass_radius := 48.0
@export_range(0.5, 3.0) var tall_grass_height := 1.5
## How wide the pond in front of a flooded entrance is (its radius), how deep at
## the middle, and how far out from the wall its near shore is, metres.
@export_range(4.0, 80.0) var pond_radius := 24.0
@export_range(0.3, 4.0) var pond_depth := 1.6
@export_range(0.0, 60.0) var pond_distance := 5.0
## How far round a clear entrance nothing grows but grass, metres.
@export_range(5.0, 200.0) var clear_radius := 75.0

## How high the pond's water stands (under the level ground round it), metres.
const POND_LEVEL := -0.3

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

@export_group("Wildlife")
## Herds of deer grazing out in the meadow (Wildlife: peaceful, they run from you).
@export_range(0, 4) var deer_herds := 2
## Herds of elk (a bull, cows and calves) grazing out in the meadow.
@export_range(0, 4) var elk_herds := 1

var _noise: FastNoiseLite
var _noise_seed := -1

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
	return false


## How high the ground is at (x, z), for a maze made from `seed_value`: 0 at the
## middle, at the foot of the clearing's walls and everywhere past them.
func height_at(x: float, z: float, seed_value: int) -> float:
	var hill := _hill_at(x, z, seed_value)
	var pond := pond_middle()
	if pond.is_finite():
		# (a bowl, its rim a little wider than the water)
		var d := Vector2(x, z).distance_to(pond) / (pond_radius * 1.25)
		if d < 1.0:
			return lerpf(hill, 0.0, smoothstep(1.0, 0.8, d)) - pond_depth * (1.0 - d * d) * 1.2
	return hill


## Whether the ground is anything but level: hills or a pond.
func shaped() -> bool:
	return hill_height > 0.0 or pond_middle().is_finite()


## The first entrance with `kind` in front of it, as [where (x, z), the way in],
## or [] if none has.
func entrance(kind: Entrance) -> Array:
	for i in mini(entrances.size(), entrance_spots.size()):
		if entrances[i] == kind:
			return entrance_spots[i]
	return []


## The middle of the pond (x, z), or not finite if there is none.
func pond_middle() -> Vector2:
	var way := entrance(Entrance.POND)
	if way.is_empty():
		return Vector2.INF
	return way[0] + way[1] * (pond_distance + pond_radius)


## Whether `point` (x, z) is where no tree or bush may be: near a clear entrance,
## or in or at the edge of the pond.
func kept_clear(point: Vector2) -> bool:
	var clear := entrance(Entrance.CLEAR)
	if not clear.is_empty() and point.distance_to(clear[0]) < clear_radius:
		return true
	var pond := pond_middle()
	return pond.is_finite() and point.distance_to(pond) < pond_radius * 1.3


## How much tall grass there is at `point` (x, z): 1 round a tall grass entrance,
## thinning out to nothing at the tall grass radius.
func tall_grass_at(point: Vector2) -> float:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return 0.0
	return smoothstep(1.0, 0.7, point.distance_to(way[0]) / tall_grass_radius)


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
