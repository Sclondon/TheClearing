extends SceneTree
## The weaver (scripts/enemies/maze_weaver.gd, creatures/weaver/), headless, in
## a round played alone with the round's own hunters taken out: it lays a strand
## across a hall; he walks into it and is stuck; it comes for him and reaches
## down; tearing at it (presses) frees him and snaps it; stuck again and left,
## it takes him (caught). Ducking, he passes under one.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/weaver_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await wait(0.1)
	main.start_solo()
	await wait(0.5)
	var world = main.world
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy = world.player
	boy.takes_input = false
	if world.dev:
		world.dev.god = true
	for one in world.enemies.enemies:
		one.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	var cell: Vector2i = nav.lairs(3)[0]
	var weaver := MazeWeaver.new()
	world.enemies.add(weaver, cell, 0.0, 5)
	var caught := []
	weaver.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await wait(0.3)
	weaver._lay(weaver.global_position, 0.0)
	check("it lays a strand of three threads", weaver._strands.size() == 1 and weaver.threads.threads.size() == 3)
	var s: Dictionary = weaver._strands[0]
	var mid: Vector3 = (s["a"] as Vector3).lerp(s["b"], 0.5)
	check("wall to wall across the hall", (s["a"] as Vector3).distance_to(s["b"]) > 1.5, "(%.1f m)" % (s["a"] as Vector3).distance_to(s["b"]))
	# Ducking, he passes under.
	boy.global_position = mid + Vector3(0, 0.1, 0) + Vector3.FORWARD * 0.1
	boy.is_ducking = true
	weaver._local(0.016)
	check("ducking, he passes under", weaver._stuck_in < 0)
	boy.is_ducking = false
	weaver.global_position = mid + Vector3(10.0, 0.0, 0.0) if nav.allowed(maze.cell_at(mid + Vector3(10, 0, 0))) else mid + Vector3.BACK * 8.0
	await wait(1.5, func() -> bool: return weaver._stuck_in >= 0)
	check("upright, he walks into it and is stuck", weaver._stuck_in >= 0 and not boy.takes_input)
	check("and it comes for him", weaver.mode in [MazeWeaver.Mode.COME, MazeWeaver.Mode.REACH], "(%s)" % MazeWeaver.Mode.keys()[weaver.mode])
	for k in weaver.struggle:
		weaver._pressed()
	check("tearing at it frees him and snaps it", weaver._stuck_in < 0 and weaver._strands.is_empty())
	await wait(0.5)
	check("and it lets him be", weaver.mode == MazeWeaver.Mode.REST, "(%s)" % MazeWeaver.Mode.keys()[weaver.mode])
	# Stuck again and left: it takes him.
	weaver._lay(weaver.global_position, 0.0)
	s = weaver._strands[0]
	mid = (s["a"] as Vector3).lerp(s["b"], 0.5)
	boy.global_position = mid + Vector3.UP * 0.1
	await wait(0.2, func() -> bool: return weaver._stuck_in >= 0)
	var took := await wait(20.0, func() -> bool: return not caught.is_empty())
	check("stuck and left, it reaches down and takes him", took, "(%s)" % MazeWeaver.Mode.keys()[weaver.mode])
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
