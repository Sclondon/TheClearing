extends SceneTree
## The dev tools (DevTools), alone: he starts in front of a gate, things are put
## in ahead of him out in the maze, god mode keeps him from being caught, he is
## moved to the middle and the exit, and everything is cleared away. And the
## clearing's wall stands as high as its rules say (ClearingStyle).
## Given a file, a picture from in front of the gate is saved to it.
##
##     godot --headless --path . -s res://tests/dev_test.gd -- --dev
##     godot --path . --resolution 1280x720 -s res://tests/dev_test.gd -- --dev <file.png>

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
	check("the clearing's wall as high as its rules say", is_equal_approx(tallest, maxf(world.maze.inner_height(1), world.maze.inner_height(2))), "(%.0f m, the clearing's %.0f m)" % [tallest, world.maze.inner_height(1)])

	# The clearing: no trees in the middle, gentle hills he stands on, level in the middle.
	var nearest := INF
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TREE):
		nearest = minf(nearest, Vector2(piece.position.x, piece.position.z).length())
	check("no trees in the middle", nearest > maze.clearing_style.treeless_radius - 0.01, "(nearest %.0f m)" % nearest)
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

	# (out in the middle of the clearing, so that nothing is in the way)
	world.dev.to_middle()
	await frames(20)
	var before: int = world.enemies.enemies.size()
	world.dev.spawn_mummy()
	world.dev.spawn_pack()
	world.dev.spawn_snake()
	world.dev.spawn_griever()
	check("things put in", world.enemies.enemies.size() == before + 5 and world.dev._grievers.size() == 1)
	var newest = world.enemies.enemies.back()
	var away: float = newest.global_position.distance_to(player.global_position)
	var look: Vector3 = -world.camera.global_basis.z
	var towards: Vector3 = (newest.global_position - player.global_position).normalized()
	check("put in where he can see it", away > 2.0 and away < 25.0 and Vector2(look.x, look.z).normalized().dot(Vector2(towards.x, towards.z)) > 0.5, "(%.0f m)" % away)
	var mummy = world.enemies.enemies[before]
	for i in 30:
		await physics_frame
	check("and it stays (not sent off the clearing)", mummy.global_position.distance_to(player.global_position) < 30.0, "(%.0f m)" % mummy.global_position.distance_to(player.global_position))
	if picture != "":
		await frames(30)
		root.get_texture().get_image().save_png(picture.replace(".png", "_spawned.png"))
	# Each of the other kinds, from its own button
	for one: Array in world.dev.HUNTERS:
		# (tame chickens are wildlife: they go in beside the hunters, not among them)
		var list: Array = world.tame_chickens if one[1] == "tame_chickens" else world.enemies.enemies
		# (and so are ravens and blue jays)
		if one[1] == "ravens":
			list = world.birds.ravens
		elif one[1] == "blue_jays":
			list = world.birds.jays
		var had: int = list.size()
		world.dev.spawn_hunter(one[1], one[2])
		await frames(2)
		var put: int = list.size() - had
		var last = list.back()
		check("+ %s" % one[0], put >= 1 and is_instance_valid(last) and last.is_inside_tree(), "(%d put in)" % put)
	# Runners ahead: one, then three.
	var had_runners: int = world.runners.runners.size()
	var runner = world.dev.spawn_runner()
	world.dev.spawn_runners()
	await frames(2)
	check("+ RUNNER and + RUNNERS", world.runners.runners.size() == had_runners + 4 and runner.is_inside_tree() and runner.global_position.distance_to(player.global_position) < 25.0)
	# The peaceful animals, from theirs: not among what hunts
	for one: Array in world.dev.WILDLIFE:
		var hunters: int = world.enemies.enemies.size()
		var herds: int = world.wildlife.herds.size()
		world.dev.spawn_wildlife(one[1])
		await frames(2)
		check("+ %s" % one[0], world.wildlife.herds.size() == herds + 1 and world.enemies.enemies.size() == hunters, "(%d animals)" % world.wildlife.herds.back().animals.size())
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
	# Each quarter of the desert ring: put in it, on its ground.
	var outer: RoundMaze = maze.round_rings
	if outer:
		var names: Array = world.dev.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text).filter(func(t: String) -> bool: return t.ends_with("(N)") or t.ends_with("(E)") or t.ends_with("(S)") or t.ends_with("(W)"))
		check("a button to each quarter in the panel", names.size() == 4, str(names))
		for q in outer.doors.size():
			world.dev.to_quarter(q)
			await frames(20)
			var stood: Vector3 = player.global_position
			var quarter := DesertStyle.quarter_at(stood.x, stood.z)
			var out_of_square := maxf(absf(stood.x), absf(stood.z)) > outer.square_half and Vector2(stood.x, stood.z).length() < outer.inner_radius
			check("to the %s quarter" % DesertStyle.Biome.keys()[outer.desert.biome_of(quarter)].to_lower(), quarter == DesertStyle.quarter_at(outer.doors[q].x, outer.doors[q].y) and out_of_square and player.is_on_floor(), str(stood))

	print("DEV TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
