@tool
class_name DesertStyle
extends Resource
## How the desert is made (Maze.desert_style; set in the editor through
## MazeLayout.desert): the dunes between the square sections and the round ones,
## the great walls across it from the square's corners, and the wall on its far
## side, round the inside of the first circle.

## How far the desert reaches past the square sections' corners, metres (the first
## circle stands there).
@export_range(30.0, 1000.0) var desert_width := 320.0
## How high its dunes are, metres, and about how far apart.
@export_range(0.0, 40.0) var dune_height := 9.0
@export_range(20.0, 400.0) var dune_spacing := 110.0
## How high the great walls are that run from each corner of the square out to
## the circle, across the desert (each with a gate through it).
@export_range(20.0, 200.0) var diagonal_wall_height := 80.0
## How high the wall on its far side is (round the inside of the first circle).
@export_range(20.0, 300.0) var far_wall_height := 46.0
