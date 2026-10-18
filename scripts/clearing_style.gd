@tool
class_name ClearingStyle
extends Resource
## How the clearing is made (Maze.clearing_style; set in the editor through
## MazeLayout.clearing_style): a level middle with no trees in it, very gentle
## hills over the rest of the field, level again at the foot of its walls, stands
## of pines along the walls, and dense woods in one corner.

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

@export_group("Woods")
## How thick the woods in their corner are: 0 none, 1 a tree every woods tree spacing
## metres or so.
@export_range(0.0, 1.0) var woods_density := 0.85
## How far the woods reach out of their corner, metres.
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
