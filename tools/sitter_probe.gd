extends SceneTree
## Which kinds of hunter go about and which sit where they are: every one in the
## first section woken and left for a while with nobody near (the boy put out of
## the way in the clearing, behind its shut gates), then how far each has gone,
## by kind. (The user, 2026-10-19: "most monsters should wander rather than sit".)
##
##     godot --headless --path . --audio-driver Dummy -s res://tools/sitter_probe.gd -- dev [seconds=<s>]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _arg(key: String, default: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return int(a.split("=")[1])
	return default


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 120:
		await process_frame
	var world = main.world
	world.dev.god = true
	world.dev.to_middle()
	var maze: Maze = world.maze
	var at := {}
	for one: MazeEnemy in world.enemies.enemies:
		if is_instance_valid(one) and not one.dead and maze.ring_of(maze.cell_at(one.global_position)) <= 1:
			one.process_mode = Node.PROCESS_MODE_INHERIT
			one.visible = true
			at[one] = one.global_position
	# (and kept awake: nobody put to sleep for the while)
	world._sleep_in = 1.0e9
	var seconds := _arg("seconds", 20)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000:
		await physics_frame
	var kinds := {}
	for one: MazeEnemy in at:
		if not is_instance_valid(one) or one.dead:
			continue
		var kind := Ecology.kind_of(one)
		if not kinds.has(kind):
			kinds[kind] = [0, 0, 0.0]
		var went: float = Vector2(one.global_position.x - at[one].x, one.global_position.z - at[one].z).length()
		kinds[kind][0 if went > 3.0 else 1] += 1
		kinds[kind][2] += went
	var names := kinds.keys()
	names.sort_custom(func(a, b) -> bool: return kinds[a][1] > kinds[b][1])
	print("kind                   went  sat   average m")
	for kind in names:
		print("%-22s %4d  %4d   %6.1f" % [kind, kinds[kind][0], kinds[kind][1], kinds[kind][2] / (kinds[kind][0] + kinds[kind][1])])
	quit()
