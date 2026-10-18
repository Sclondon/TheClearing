class_name LootMap
extends Control
## A scrap of map, read (LootItem's MAP; shown by LootHud): a page torn from an
## exercise book with the halls round where he stands drawn on it in pencil,
## the way from there to the gate out of where he is (the clearing's nearest
## gate, or his ring's way out) marked with a dashed line and a cross, and an
## arrow for him. North is up; it does not turn with him. It is drawn once, when
## it is read (the maze does not change).

const PAPER := Color(0.82, 0.78, 0.67)
const PAPER_EDGE := Color(0.6, 0.55, 0.45)
const PENCIL := Color(0.24, 0.24, 0.27)
const WAY := Color(0.55, 0.12, 0.08)
## How many cells either side of him are drawn.
const AROUND := 7

var loot: Loot
var _here := Vector2i.ZERO
var _at := Vector3.ZERO
var _yaw := 0.0
var _way: Array[Vector2i] = []
var _tears := PackedFloat32Array()


func _init(of: Loot = null) -> void:
	loot = of
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 560)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 24:
		_tears.append(r.randf_range(0.0, 7.0))


## Draws it for where the player is now.
func read() -> void:
	if loot == null or loot.world == null or loot.world.player == null:
		return
	var player := loot.world.player
	_at = player.global_position
	_here = loot.maze.cell_at(_at)
	_yaw = player.facing_yaw
	_way = loot.way_out(_at)
	queue_redraw()


func _draw() -> void:
	var page := Rect2(Vector2.ZERO, size)
	# The page: torn along its top, ruled faintly, a crease down the middle.
	var outline := PackedVector2Array()
	for i in 24:
		outline.append(Vector2(page.size.x * i / 23.0, _tears[i]))
	outline.append(page.size)
	outline.append(Vector2(0.0, page.size.y))
	draw_colored_polygon(outline, PAPER)
	draw_polyline(outline + PackedVector2Array([outline[0]]), PAPER_EDGE, 2.0, true)
	for k in range(1, 12):
		var y := page.size.y * k / 12.0
		draw_line(Vector2(6, y), Vector2(page.size.x - 6, y), Color(0.55, 0.6, 0.72, 0.25), 1.0)
	draw_line(Vector2(page.size.x * 0.5, 8), Vector2(page.size.x * 0.5, page.size.y - 4), Color(0.5, 0.45, 0.36, 0.35), 2.0)
	if loot == null:
		return
	var maze := loot.maze
	var cell := (page.size.x - 40.0) / (AROUND * 2 + 1)
	var origin := page.size * 0.5
	var at_cell := func(c: Vector2i) -> Vector2:
		return origin + Vector2(c.x - _here.x, c.y - _here.y) * cell
	if _way.is_empty() and not maze.in_clearing(_here):
		draw_string(LootHud.FONT, Vector2(30, origin.y), "...the rest is too faded to read", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PENCIL)
		return
	# The walls, as lines between cells (and solid wall hatched).
	for dy in range(-AROUND, AROUND + 1):
		for dx in range(-AROUND, AROUND + 1):
			var c := _here + Vector2i(dx, dy)
			if not maze.inside(c):
				continue
			var middle: Vector2 = at_cell.call(c)
			if maze.solid.has(c):
				for k in 3:
					var a := middle + Vector2(-cell * 0.5, -cell * 0.5 + cell * (k + 0.5) / 3.0)
					draw_line(a, a + Vector2(cell, -cell * 0.33), Color(PENCIL, 0.35), 1.0)
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				if not maze.blocked(c, step):
					continue
				var edge := middle + Vector2(step) * cell * 0.5
				var along := Vector2(-step.y, step.x) * cell * 0.5
				var wobble := Vector2(sin(c.x * 3.1 + c.y), cos(c.y * 2.3 + c.x)) * 0.8
				draw_line(edge - along + wobble, edge + along - wobble, PENCIL, 2.0, true)
	# The way, dashed, and a cross where it ends.
	for i in range(1, _way.size()):
		var a: Vector2 = at_cell.call(_way[i - 1])
		var b: Vector2 = at_cell.call(_way[i])
		if (a - origin).length() > cell * (AROUND + 0.5) or (b - origin).length() > cell * (AROUND + 0.5) * 1.42:
			continue
		var steps := 4
		for s in steps:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), WAY, 3.0, true)
	if not _way.is_empty():
		var end: Vector2 = at_cell.call(_way.back())
		end = origin + (end - origin).limit_length(cell * AROUND)
		draw_line(end - Vector2(8, 8), end + Vector2(8, 8), WAY, 4.0, true)
		draw_line(end + Vector2(-8, 8), end + Vector2(8, -8), WAY, 4.0, true)
	# He is here (where in his cell he stands, and the way he faces).
	var offset := Vector2(_at.x - maze.world(_here).x, _at.z - maze.world(_here).z) / Maze.CELL * cell
	var me := origin + offset
	var facing := Vector2(sin(_yaw), cos(_yaw))
	var side := Vector2(-facing.y, facing.x)
	draw_colored_polygon(PackedVector2Array([me + facing * 11.0, me - facing * 7.0 + side * 7.0, me - facing * 3.0, me - facing * 7.0 - side * 7.0]), WAY.darkened(0.3))
	draw_string(LootHud.FONT, Vector2(14, page.size.y - 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PENCIL)
	draw_line(Vector2(21, page.size.y - 34), Vector2(21, page.size.y - 56), PENCIL, 2.0)
	draw_line(Vector2(21, page.size.y - 56), Vector2(15, page.size.y - 46), PENCIL, 2.0)
	draw_line(Vector2(21, page.size.y - 56), Vector2(27, page.size.y - 46), PENCIL, 2.0)
