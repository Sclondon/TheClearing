extends SceneTree
## The carnivorous plants, mushrooms and mushroom zombies in a real round
## (World), put in as MazeEnemies.add_hunters would (MazePlants.populate, with
## the counts given): what was put in and where, a few seconds run with the boy
## among them (no errors), and what they cost: the frame time with them and
## with them all taken away, the time their scripts take, and pictures of a
## few of them. Needs a real window:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/fungi_round.gd -- <folder> [flytraps sundews pitchers patches hordes]

var folder := "fungi_round"


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s.png  (%d draws)" % [name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frame_ms(frames: int, world: Node3D) -> float:
	var started := Time.get_ticks_usec()
	for i in frames:
		world.camera._yaw += 0.0
		await process_frame
	return (Time.get_ticks_usec() - started) / 1000.0 / frames


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var counts := [3, 2, 2, 4, 2]
	for k in mini(args.size() - 1, 5):
		counts[k] = int(args[k + 1])
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var enemies: MazeEnemies = world.enemies
	var nav := MazeNav.new(maze)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var lairs := nav.lairs(5)
	var ends: Array[Vector2i] = []
	var halls: Array[Vector2i] = []
	for cell in lairs:
		if nav.dead_end(cell):
			ends.append(cell)
		elif enemies._straight(cell) != Vector2i.ZERO:
			halls.append(cell)
	var taken: Array[Vector2i] = []
	for enemy in enemies.enemies:
		taken.append(maze.cell_at(enemy.global_position))
	var before := enemies.enemies.size()
	var started := Time.get_ticks_usec()
	MazePlants.populate(enemies, nav, rng, taken, halls, ends, lairs, counts[0], counts[1], counts[2], counts[3], counts[4])
	var mine: Array = enemies.enemies.slice(before)
	print("put in %d (%.1f ms): %s" % [mine.size(), (Time.get_ticks_usec() - started) / 1000.0, ", ".join(mine.map(func(e: MazeEnemy) -> String: return "%s@%s" % [e.get_script().get_global_name(), maze.cell_at(e.global_position)]))])
	var boy: Node3D = world.player
	boy.takes_input = false
	# Among them: by the first zombie
	var zombie: Node3D = null
	for one in mine:
		if one is MazeMushroomZombie and not (one as MazeMushroomZombie).sleeper:
			zombie = one
			break
	var target: Node3D = zombie if zombie else mine[0]
	boy.global_position = target.global_position + Vector3(3.0, 0.3, 0.0)
	world.camera.snap()
	for i in 240:
		await process_frame
	await shot("r1_among_them")
	for one: MazeEnemy in mine:
		print("  %s %.0f m off, %s" % [one.get_script().get_global_name(), one.global_position.distance_to(boy.global_position), "awake" if one.can_process() else "asleep"])
	# What each kind costs: the frame with it, and with it taken away, three times over (the camera still)
	var kinds := {
		"all of them": mine,
		"zombies": mine.filter(func(e: MazeEnemy) -> bool: return e is MazeMushroomZombie),
		"mushrooms": mine.filter(func(e: MazeEnemy) -> bool: return e is MazeMushrooms),
		"plants": mine.filter(func(e: MazeEnemy) -> bool: return e is MazeFlytrap or e is MazeSundew or e is MazePitcher),
	}
	for kind: String in kinds:
		var with_ms := 0.0
		var without_ms := 0.0
		for round_number in 3:
			with_ms += await frame_ms(120, world)
			var was := {}
			for one: MazeEnemy in kinds[kind]:
				was[one] = [one.process_mode, one.visible]
				one.process_mode = Node.PROCESS_MODE_DISABLED
				one.visible = false
			for i in 10:
				await process_frame
			without_ms += await frame_ms(120, world)
			for one: MazeEnemy in kinds[kind]:
				one.process_mode = was[one][0]
				one.visible = was[one][1]
			for i in 10:
				await process_frame
		print("%s: frame %.2f ms with, %.2f without (%+.2f)" % [kind, with_ms / 3.0, without_ms / 3.0, (with_ms - without_ms) / 3.0])
	quit()
