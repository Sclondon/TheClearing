extends SceneTree
## Plays alone, headless: the title comes up, a maze is built, the boy stands in
## the clearing and can walk, the walls stop him, he gets out past the exit, the
## round ends, and the next maze is a different one. Then the same with touches:
## a finger held on the left of the screen walks him.
##
##     godot --headless --path . -s res://tests/smoke_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	check("title", main.screen == "title")
	main.start_solo()
	await frames(30)
	var world = main.world
	check("playing", main.screen == "play" and world != null)
	var player = world.player
	check("in the clearing", player.global_position.length() < 4.0 and player.is_on_floor(), str(player.global_position))
	check("maze built", world.get_node("Maze/Walls").get_child_count() > 40, "(%d wall runs)" % world.get_node("Maze/Walls").get_child_count())

	# Walk: he goes somewhere.
	var from: Vector3 = player.global_position
	Input.action_press(&"move_up")
	await frames(60)
	Input.action_release(&"move_up")
	check("walks", player.global_position.distance_to(from) > 1.0, "(%.1f m)" % player.global_position.distance_to(from))

	# Run into a wall: he stops at it. (Put him in a cell with a wall to the east.)
	var maze = world.maze
	var cell := Vector2i(-1, -1)
	for y in maze.size:
		for x in maze.size - 1:
			if cell.x < 0 and not maze.in_clearing(Vector2i(x, y)) and maze.blocked(Vector2i(x, y), Vector2i(1, 0)) and not _has_terrace(world, maze.world(Vector2i(x, y))):
				cell = Vector2i(x, y)
	player.global_position = maze.world(cell) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await frames(10)
	var wall_x: float = maze.world(cell).x + Maze.CELL * 0.5
	for i in 120:
		player.velocity.x = 5.0
		await physics_frame
	check("walls stop him", player.global_position.x < wall_x, "(x %.2f, wall at %.2f)" % [player.global_position.x, wall_x])

	# Through a gate from the clearing (a slot through a thick wall): he fits.
	var gate: Array = maze.gates[0][0]
	var into := Vector3(gate[1].x, 0.0, gate[1].y)
	var before_gate: Vector3 = maze.world(gate[0])
	player.global_position = before_gate + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	await frames(10)
	# (out past the far face of the wall: from the middle of the cell before it,
	# through the wall's own cell-line, the rampart's cells and half a wall)
	var deep: float = Maze.CELL * (0.5 + maze.styles[0].rampart) + maze.wall_thick(gate[0], gate[1]) * 0.5 + 1.0
	for i in int(deep / 5.0 * 60.0) + 60:
		player.velocity.x = into.x * 5.0
		player.velocity.z = into.z * 5.0
		await physics_frame
	var through: float = (player.global_position - before_gate).dot(into)
	check("through a gate", through > deep, "(%.1f m on, the wall %.1f thick)" % [through, maze.wall_thick(gate[0], gate[1])])

	# Out past the exit.
	var path: Array = maze.path_out(maze.cell_at(Vector3.ZERO))
	check("a way out", path.size() > 10, "(%d cells)" % path.size())
	player.global_position = maze.world(maze.exit + maze.exit_side * 2) + Vector3.UP * 0.2
	await frames(10)
	check("got out", world.out.has(0))
	check("round over", world.all_out())
	var first_seed: int = maze.maze_seed
	main.next_round()
	await frames(20)
	check("next maze", main.world != null and main.world.maze.maze_seed != first_seed and main.round_number == 2)

	# A finger held on the left of the screen walks him.
	player = main.world.player
	from = player.global_position
	var size := root.get_visible_rect().size
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	# (events arrive in window pixels: map from the stretched view to them)
	var to_window := root.get_final_transform()
	press.position = to_window * Vector2(size.x * 0.2, size.y * 0.75)
	Input.parse_input_event(press)
	await frames(2)
	for i in 60:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = press.position + to_window.basis_xform(Vector2(0.0, -90.0))
		drag.relative = Vector2(0.0, -1.5)
		Input.parse_input_event(drag)
		await physics_frame
	var lift := InputEventScreenTouch.new()
	lift.index = 0
	lift.pressed = false
	lift.position = press.position + to_window.basis_xform(Vector2(0.0, -90.0))
	Input.parse_input_event(lift)
	check("touch walks him", player.global_position.distance_to(from) > 1.0, "(%.1f m)" % player.global_position.distance_to(from))

	main.leave()
	await frames(5)
	check("back to the title", main.screen == "title")
	print("SMOKE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


## Whether a terrace stands anywhere in the cell round `middle` (he would be put inside it).
func _has_terrace(world: Node, middle: Vector3) -> bool:
	var cell := Rect2(middle.x - Maze.CELL * 0.5, middle.z - Maze.CELL * 0.5, Maze.CELL, Maze.CELL)
	for footprint: Rect2 in world.get_node("Maze").features.footprints:
		if footprint.intersects(cell):
			return true
	return false
