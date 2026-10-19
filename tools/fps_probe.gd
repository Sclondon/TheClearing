extends SceneTree
## Frame time where the boy stands: the clearing, then rings 1 to 3 (dev to_ring), each held 4 s.

var main: Node

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()

func _sample(label: String) -> void:
	for i in 60:
		await process_frame
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var proc := 0.0
	var phys := 0.0
	while Time.get_ticks_usec() - t0 < 4000000:
		await process_frame
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var secs := (Time.get_ticks_usec() - t0) / 1e6
	print("%-10s %5.1f fps  frame %5.1f ms  process %5.1f ms  physics %5.1f ms  draws %d  prims %dk  objects %d  nodes %d  bodies %d" % [label, frames / secs, secs * 1000.0 / frames, proc / frames * 1000.0, phys / frames * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])

func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 120:
		await physics_frame
	var world = main.world
	await _sample("clearing")
	if world.dev == null:
		world.dev = load("res://scripts/dev_tools.gd").new(world)
	for ring in [1, 2, 3]:
		world.dev.to_ring(ring)
		await _sample("ring %d" % ring)
	quit()
