class_name DevMap
extends Control
## The dev panel's map of the whole maze (DevTools, Travel): the square maze's
## walls as they stand, the desert ring's quarters tinted by what they are, the
## round sections' great circles, and the boy, an arrow the way he faces. Tap or
## click anywhere on it and he is put there (DevTools.travel_to); the mouse wheel
## zooms in on the boy and out again.

## How many pixels of the baked picture a cell of the square maze is.
const CELL_PIXELS := 3
const PAPER := Color(0.08, 0.09, 0.08)
const WALL := Color(0.78, 0.76, 0.68)
const SOLID := Color(0.42, 0.41, 0.37)
const CLEARING := Color(0.2, 0.3, 0.16)
const BIOME_TINTS := [Color(0.62, 0.52, 0.3, 0.55), Color(0.16, 0.32, 0.14, 0.6), Color(0.22, 0.27, 0.16, 0.6), Color(0.42, 0.45, 0.3, 0.55)]
const HIM := Color(0.86, 0.22, 0.17)

var dev: DevTools
## Metres from the middle of the maze to the map's edge (the whole maze, zoomed out).
var reach := 1000.0
var zoom := 1.0
var _square: ImageTexture
var _redraw_in := 0.0


func _init(tools: DevTools) -> void:
	dev = tools
	name = "Map"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(0, 560)
	tooltip_text = "Tap to go there. Wheel: zoom on him."


func _ready() -> void:
	_bake()


## The square maze's walls, as a picture, once (they do not move).
func _bake() -> void:
	var maze: Maze = dev.world.maze
	var outer: RoundMaze = maze.round_rings
	reach = (outer.outermost() + 60.0) if outer else maze.extent() * 0.5 + 40.0
	var across := maze.size * CELL_PIXELS + 1
	var image := Image.create(across, across, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		var at := cell * CELL_PIXELS
		if maze.in_clearing(cell):
			image.fill_rect(Rect2i(at, Vector2i.ONE * CELL_PIXELS), CLEARING)
			continue
		if maze.solid.has(cell):
			image.fill_rect(Rect2i(at, Vector2i.ONE * (CELL_PIXELS + 1)), SOLID)
			continue
		# (each cell draws the walls on its east and south, and the edge's on its west and north)
		if maze.blocked(cell, Vector2i(1, 0)):
			image.fill_rect(Rect2i(at + Vector2i(CELL_PIXELS, 0), Vector2i(1, CELL_PIXELS + 1)), WALL)
		if maze.blocked(cell, Vector2i(0, 1)):
			image.fill_rect(Rect2i(at + Vector2i(0, CELL_PIXELS), Vector2i(CELL_PIXELS + 1, 1)), WALL)
		if cell.x == 0 and maze.blocked(cell, Vector2i(-1, 0)):
			image.fill_rect(Rect2i(at, Vector2i(1, CELL_PIXELS + 1)), WALL)
		if cell.y == 0 and maze.blocked(cell, Vector2i(0, -1)):
			image.fill_rect(Rect2i(at, Vector2i(CELL_PIXELS + 1, 1)), WALL)
	_square = ImageTexture.create_from_image(image)


func _process(delta: float) -> void:
	# (the boy moves: drawn again a few times a second while it is shown)
	_redraw_in -= delta
	if _redraw_in <= 0.0 and is_visible_in_tree():
		_redraw_in = 0.1
		queue_redraw()


## Where a place in the world (x, z) is on the map, and back.
func to_map(at: Vector2) -> Vector2:
	var side := minf(size.x, size.y)
	var middle := size * 0.5
	return middle + (at - _centre()) / (reach / zoom) * side * 0.5


func to_world(point: Vector2) -> Vector2:
	var side := minf(size.x, size.y)
	return _centre() + (point - size * 0.5) / (side * 0.5) * (reach / zoom)


# Zoomed out, the middle of the maze; zoomed in, him.
func _centre() -> Vector2:
	if zoom <= 1.0 or dev.world.player == null:
		return Vector2.ZERO
	var at: Vector3 = dev.world.player.global_position
	return Vector2(at.x, at.z)


func _draw() -> void:
	var maze: Maze = dev.world.maze
	var outer: RoundMaze = maze.round_rings
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var scale := minf(size.x, size.y) * 0.5 / (reach / zoom)
	if outer:
		# The desert ring's quarters, each tinted by what it is, between the square's
		# corners and the first circle; the diagonal walls; the round sections' circles.
		var half := outer.square_half
		for side: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var across := side.orthogonal()
			var points := PackedVector2Array([to_map((side - across) * half), to_map((side + across) * half)])
			var from := (side + across).angle()
			for k in 17:
				points.append(to_map(Vector2.from_angle(from - k * PI * 0.5 / 16.0) * outer.inner_radius))
			draw_colored_polygon(points, BIOME_TINTS[outer.desert.biome_of(Vector2i(side))])
		for a: float in RoundMaze.DIAGONALS:
			draw_line(to_map(Vector2.from_angle(a) * half * sqrt(2.0)), to_map(Vector2.from_angle(a) * outer.inner_radius), WALL, 2.5)
		var middle := to_map(Vector2.ZERO)
		draw_arc(middle, outer.inner_radius * scale, 0.0, TAU, 96, WALL, 2.5)
		for ring: RoundMaze.Ring in outer.rings:
			draw_arc(middle, ring.outer * scale, 0.0, TAU, 96, WALL, 2.5)
			for row: Array in ring.rows.slice(1):
				draw_arc(middle, row[0] * scale, 0.0, TAU, 96, WALL.darkened(0.55), 1.5)
	var square := maze.extent() * 0.5
	var corner := to_map(Vector2(-square, -square))
	draw_texture_rect(_square, Rect2(corner, to_map(Vector2(square, square)) - corner), false)
	# Him: an arrow the way he faces.
	var player = dev.world.player
	if player:
		var at := to_map(Vector2(player.global_position.x, player.global_position.z))
		var facing := Vector2(sin(player.facing_yaw), cos(player.facing_yaw))
		var side := facing.orthogonal()
		draw_colored_polygon(PackedVector2Array([at + facing * 16.0, at - facing * 9.0 + side * 10.0, at - facing * 3.5, at - facing * 9.0 - side * 10.0]), HIM)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				dev.travel_to(to_world(button.position))
			MOUSE_BUTTON_WHEEL_UP:
				zoom = minf(zoom * 1.5, 12.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = maxf(zoom / 1.5, 1.0)
			_:
				return
		queue_redraw()
		accept_event()
	var touch := event as InputEventScreenTouch
	if touch and touch.pressed:
		dev.travel_to(to_world(touch.position))
		accept_event()
