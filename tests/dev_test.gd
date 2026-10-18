extends SceneTree
## The dev tools (DevTools), alone: he starts in front of a gate, things are put
## in ahead of him out in the maze, god mode keeps him from being caught, he is
## moved to the middle and the exit, and everything is cleared away. And the
## clearing's wall stands twice as high as the other walls between rings.
## Given a file, a picture from in front of the gate is saved to it.
##
##     godot --headless --path . -s res://tests/dev_test.gd -- --dev
##     godot --path . --resolution 720x1280 -s res://tests/dev_test.gd -- --dev <file.png>

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
	main.start_solo()
	await frames(30)
	var world = main.world
	var maze = world.maze
	var player = world.player
	check("dev tools on", world.dev != null)
	var gate: Transform3D = world.gate_spot(0)
	check("starts in front of a gate", player.global_position.distance_to(gate.origin) < 3.0 and maze.in_clearing(maze.cell_at(player.global_position)), str(player.global_position))

	# The clearing's wall, and the next ring's.
	var tallest := 0.0
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.WALL):
		tallest = maxf(tallest, piece.size.y)
	check("the clearing's wall twice as high", is_equal_approx(tallest, MazeBuilder.RING_HEIGHT * 2.0), "(%.0f m)" % tallest)

	# The clearing: no trees in the middle, gentle hills he stands on, level in the middle.
	var nearest := INF
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TREE):
		nearest = minf(nearest, Vector2(piece.position.x, piece.position.z).length())
	check("no trees in the middle", nearest > maze.clearing_style.glade - 0.01, "(nearest %.0f m)" % nearest)
	check("level in the middle", maze.ground_height(Vector3(20.0, 0.0, -30.0)) == 0.0)
	var top := Vector3.ZERO
	for i in 4000:
		var p := Vector3(randf_range(-250.0, 250.0), 0.0, randf_range(-250.0, 250.0))
		if maze.ground_height(p) > maze.ground_height(top):
			top = p
	world.put_player(top + Vector3.UP * (maze.ground_height(top) + 0.5), 0.0)
	await frames(40)
	check("stands on a hill", absf(player.global_position.y - maze.ground_height(top)) < 0.3 and maze.ground_height(top) > 1.0, "(%.2f m, the hill %.2f)" % [player.global_position.y, maze.ground_height(top)])
	world.put_player(world.spawn(0), world.spawn_yaw(0))

	var picture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.ends_with(".png"):
			picture = arg
	if picture != "":
		world.dev.toggle()
		world.camera._pitch = -0.25
		await frames(40)
		await process_frame
		root.get_texture().get_image().save_png(picture)
		world.dev.toggle()

	var before: int = world.enemies.enemies.size()
	world.dev.spawn_mummy()
	world.dev.spawn_pack()
	world.dev.spawn_snake()
	world.dev.spawn_griever()
	check("things put in", world.enemies.enemies.size() == before + 5 and world.dev._grievers.size() == 1)
	var newest = world.enemies.enemies.back()
	var cell: Vector2i = maze.cell_at(newest.global_position)
	check("out in the maze, not the clearing", not maze.in_clearing(cell) and not maze.solid.has(cell), str(cell))
	check("not far from him", newest.global_position.distance_to(player.global_position) < Maze.CELL * 12.0, "(%.0f m)" % newest.global_position.distance_to(player.global_position))
	# Each of the other kinds, from its own button
	for one: Array in world.dev.HUNTERS:
		var had: int = world.enemies.enemies.size()
		world.dev.spawn_hunter(one[1])
		await frames(2)
		var put: int = world.enemies.enemies.size() - had
		var last = world.enemies.enemies.back()
		check("+ %s" % one[0], put >= 1 and is_instance_valid(last) and last.is_inside_tree(), "(%d put in)" % put)
	await frames(30)

	world.dev.toggle_god()
	var at: Vector3 = player.global_position
	world._on_caught(player)
	check("god: not caught", player.global_position.distance_to(at) < 0.5)
	world.dev.toggle_god()

	world.dev.toggle_freeze()
	check("freeze", newest.process_mode == Node.PROCESS_MODE_DISABLED)
	world.dev.toggle_freeze()

	world.dev.to_middle()
	await frames(5)
	check("to the middle", player.global_position.length() < 4.0, str(player.global_position))
	world.dev.to_gate()
	await frames(5)
	check("to a gate", player.global_position.distance_to(world.gate_spot(0).origin) < 1.0)
	world.dev.clear()
	await frames(2)
	check("cleared", world.enemies.enemies.is_empty() and not world.griever.visible)
	world.dev.to_exit()
	await frames(30)
	check("to the exit", player.global_position.distance_to(maze.world(maze.exit)) < Maze.CELL * 0.5, str(player.global_position))

	print("DEV TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
