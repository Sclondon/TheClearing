extends SceneTree
## The frame rate round the maze: the boy put in each ring in turn (DevTools.to_ring)
## and the desert, standing there a few seconds while the camera looks round, and
## the frames a second, the time in scripts and physics, and what is drawn,
## printed for each. Run with -- dev (the dev tools put him there).
##
##     godot --path . --resolution 1280x720 -s res://tools/fps_tour.gd -- dev

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 120:
		await process_frame
	var world = main.world
	var places: Array = []
	places.append(["clearing", func() -> void: world.dev.to_middle()])
	for ring in range(1, world.ring_count() + 1):
		places.append(["desert" if world.maze.round_rings and ring == world.maze.rings + 1 else "ring %d" % ring, world.dev.to_ring.bind(ring)])
	for place: Array in places:
		(place[1] as Callable).call()
		# (settled, then measured over three seconds as the camera turns)
		for i in 60:
			await process_frame
		var frames := 0
		var proc := 0.0
		var phys := 0.0
		var started := Time.get_ticks_msec()
		var worst := 0
		var last := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 3000:
			world.camera._yaw += 0.02
			await process_frame
			var now := Time.get_ticks_msec()
			worst = maxi(worst, now - last)
			last = now
			frames += 1
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		print("%-9s %4.0f fps (worst frame %3d ms)  scripts %5.1f ms  physics %5.1f ms  draws %5d  triangles %7d  nodes %d" % [place[0], frames / 3.0, worst, proc / frames * 1000.0, phys / frames * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit()
