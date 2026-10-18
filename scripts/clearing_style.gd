@tool
class_name ClearingStyle
extends Resource
## How the clearing is made (Maze.clearing_style; set in the editor through
## MazeLayout.clearing_style): a level middle with no trees in it, very gentle
## hills over the rest of the field, level again at the foot of its walls, stands
## of pines along the walls, and dense woods in one corner.

## No trees nearer the middle than this, metres.
@export_range(0.0, 250.0) var glade := 95.0
## The ground is level out to this far from the middle, metres, and rises into
## the hills over `rise` metres past that.
@export_range(0.0, 250.0) var flat := 70.0
@export_range(1.0, 200.0) var rise := 60.0
## How high the hills are at most, metres (0: the whole field level).
@export_range(0.0, 12.0) var hills := 4.0
## About how far apart the hills are, metres.
@export_range(20.0, 400.0) var hill_size := 150.0
## The ground is level this far out from the foot of the clearing's wall, and
## rises into the hills over `rise` metres in from that.
@export_range(0.0, 80.0) var wall_level := 18.0

@export_group("Woods")
## How thick the woods in their corner are: 0 none, 1 a tree every `spacing`
## metres or so.
@export_range(0.0, 1.0) var woods := 0.85
## How far the woods reach out of their corner, metres.
@export_range(20.0, 300.0) var woods_reach := 185.0
## About how far apart the trees in the woods are, metres.
@export_range(3.0, 20.0) var spacing := 6.5

@export_group("Undergrowth")
## Ferns round the foot of each pine, on average (more in the woods, where they stand close).
@export_range(0.0, 10.0) var ferns := 2.5
## The chance of a cushion of moss at the foot of a pine.
@export_range(0.0, 1.0) var moss := 0.5
## Bushes over the field (none in the glade), most of them near the trees.
@export_range(0, 400) var bushes := 70

var _noise: FastNoiseLite
var _noise_seed := -1


## How high the ground is at (x, z), for a maze made from `seed_value`: 0 at the
## middle, at the foot of the clearing's walls and everywhere past them.
func height_at(x: float, z: float, seed_value: int) -> float:
	if hills <= 0.0:
		return 0.0
	var half := Maze.CLEARING * Maze.CELL * 0.5
	var from_wall := half - maxf(absf(x), absf(z))
	if from_wall <= wall_level:
		return 0.0
	var from_middle := Vector2(x, z).length()
	if from_middle <= flat:
		return 0.0
	var shown := smoothstep(flat, flat + rise, from_middle) * smoothstep(wall_level, wall_level + rise, from_wall)
	return hills * shown * (_hill_noise(seed_value).get_noise_2d(x, z) * 0.5 + 0.5)


func _hill_noise(seed_value: int) -> FastNoiseLite:
	if _noise == null or _noise_seed != seed_value:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = seed_value
		_noise.frequency = 1.0 / hill_size
		_noise.fractal_octaves = 2
		_noise_seed = seed_value
	return _noise
