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


## The quarter (x, z) is in: north (-z), east (+x), south (+z) or west (-x), as the
## diagonal walls part them; and what it is.
static func quarter_at(x: float, z: float) -> Vector2i:
	if absf(x) > absf(z):
		return Vector2i(1, 0) if x > 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if z > 0.0 else Vector2i(0, -1)


func biome_of(quarter: Vector2i) -> Biome:
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
