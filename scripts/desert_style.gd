@tool
class_name DesertStyle
extends Resource
## How the desert is made (Maze.desert_style; set in the editor through
## MazeLayout.desert): the dunes between the square sections and the round ones,
## the great walls across it from the square's corners, and the wall on its far
## side, round the inside of the first circle.

## What each quarter is: they are walled apart (the great walls from the square's
## corners have no gates), each entered from the square maze on its own side, each
## with its own gate on into the first circle.
enum Biome { DESERT, FOREST, SWAMP, PLAINS }
## Each quarter is what the clearing's entrance on its side is in front of
## (ClearingStyle.entrances): the woods lead to forest, the marsh to swamp, the
## tall grass and the plain field to plains, a clear entrance to desert. A
## quarter with no entrance on its side (and every one, with this off) is as set
## here below.
@export var match_entrances := true
@export var north_quarter := Biome.DESERT
@export var east_quarter := Biome.FOREST
@export var south_quarter := Biome.SWAMP
@export var west_quarter := Biome.PLAINS

## How far the ring reaches past the square sections' corners, metres (the first
## circle stands there).
@export_range(30.0, 1000.0) var desert_width := 320.0
## How high the dunes are in a desert quarter, metres, and about how far apart.
@export_range(0.0, 40.0) var dune_height := 9.0
@export_range(20.0, 400.0) var dune_spacing := 110.0
## How high the great walls are that run from each corner of the square out to
## the circle, across the desert (each with a gate through it).
@export_range(20.0, 200.0) var diagonal_wall_height := 80.0
## How high the wall on its far side is (round the inside of the first circle).
@export_range(20.0, 300.0) var far_wall_height := 46.0
## Nothing that stands in the way (trees, rocks, logs) this near a quarter's way
## in from the square maze or its gate on through the first circle, metres.
@export_range(0.0, 80.0) var keep_clear_radius := 22.0

@export_group("Forest")
## A forest quarter's woods (WildLands, Wilds): about how far apart its pines
## are, metres; how many of the spots have one (0 none, 1 all); how much of it
## is open glades; and how tall the pines are on average, metres.
@export_range(3.0, 20.0) var forest_tree_spacing := 6.0
@export_range(0.0, 1.0) var forest_density := 0.8
@export_range(0.0, 1.0) var forest_glades := 0.25
@export_range(6.0, 40.0) var forest_tree_height := 17.0
## Ferns round the foot of each pine, on average, and the chance of a cushion of
## moss at its foot.
@export_range(0.0, 10.0) var forest_ferns_per_tree := 1.6
@export_range(0.0, 1.0) var forest_moss_chance := 0.5
## Bushes, fallen logs and mossy boulders, about how many to a hectare (100 m
## across).
@export_range(0.0, 200.0) var forest_bushes := 20.0
@export_range(0.0, 40.0) var forest_logs := 5.0
@export_range(0.0, 40.0) var forest_boulders := 2.0

@export_group("Swamp")
## A swamp quarter: one sheet of still water over the middle of it, this deep
## over the lowest ground, metres, that hummocks of wet ground stand up through;
## how much of it is open water (the rest hummocks), and about how far apart the
## hummocks are, metres. Its edges, round the walls, are dry boggy ground.
@export_range(0.1, 1.0) var swamp_water_depth := 0.4
@export_range(0.0, 1.0) var swamp_water := 0.5
@export_range(2.0, 30.0) var swamp_hummock_size := 7.0
## Sedges all over it, this tall, metres; reeds and bulrushes in clumps along the
## water's edge (0 none, 1 many); lily pads on the open water.
@export_range(0.3, 2.5) var swamp_sedge_height := 0.75
@export_range(0.0, 1.0) var swamp_reeds := 0.5
@export_range(0.0, 1.0) var swamp_lily_pads := 0.4
## Dead and drowned trees, about how many to a hectare.
@export_range(0.0, 60.0) var swamp_dead_trees := 7.0
## Banks of mist lying low over it (0 none, 1 thick).
@export_range(0.0, 1.0) var swamp_mist := 0.5

@export_group("Plains")
## A plains quarter: wide grass over low hills, this high at most and about this
## far apart, metres; the grass this tall and this thick (1 a full meadow).
@export_range(0.0, 30.0) var plains_hill_height := 10.0
@export_range(30.0, 600.0) var plains_hill_spacing := 170.0
@export_range(0.1, 2.0) var plains_grass_height := 0.5
@export_range(0.0, 2.0) var plains_grass_density := 0.8
## Boulders lying about, and outcrops of rock (a clump of great rocks, some as
## big as a house), about how many of each to a hectare.
@export_range(0.0, 40.0) var plains_boulders := 4.0
@export_range(0.0, 10.0) var plains_outcrops := 0.6


## The quarter (x, z) is in: north (-z), east (+x), south (+z) or west (-x), as the
## diagonal walls part them; and what it is.
static func quarter_at(x: float, z: float) -> Vector2i:
	if absf(x) > absf(z):
		return Vector2i(1, 0) if x > 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if z > 0.0 else Vector2i(0, -1)


## What each clearing entrance leads to (`match_entrances`).
const FROM_ENTRANCE := {
	ClearingStyle.Entrance.WOODS: Biome.FOREST, ClearingStyle.Entrance.MARSH: Biome.SWAMP,
	ClearingStyle.Entrance.TALL_GRASS: Biome.PLAINS, ClearingStyle.Entrance.PLAIN: Biome.PLAINS,
	ClearingStyle.Entrance.CLEAR: Biome.DESERT,
}

## The quarters' biomes from the clearing's entrances (by quarter), once the
## maze knows where they are (`match_to`).
var _from_entrances := {}


## Takes each quarter's biome from the clearing's entrance on its side (the
## first, if there are more): call once the maze has put its entrances.
func match_to(clearing: ClearingStyle) -> void:
	_from_entrances.clear()
	for i in mini(clearing.entrances.size(), clearing.entrance_spots.size()):
		var inward: Vector2 = clearing.entrance_spots[i][1]
		var quarter := quarter_at(-inward.x, -inward.y)
		if not _from_entrances.has(quarter):
			_from_entrances[quarter] = FROM_ENTRANCE[clearing.entrances[i]]


func biome_of(quarter: Vector2i) -> Biome:
	if match_entrances and _from_entrances.has(quarter):
		return _from_entrances[quarter]
	match quarter:
		Vector2i(0, -1):
			return north_quarter
		Vector2i(1, 0):
			return east_quarter
		Vector2i(0, 1):
			return south_quarter
	return west_quarter


func biome_at(x: float, z: float) -> Biome:
	return biome_of(quarter_at(x, z))
