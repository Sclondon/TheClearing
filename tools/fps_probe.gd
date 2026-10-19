extends SceneTree
## Frame time where the boy stands: the clearing, then rings 1 to 3 (dev to_ring), each held 4 s.
## The same maze every run (seed=<n> for another). With `vines=<x>`, the square
## sections' vines are made heavier: vine_density times x, and the mezzanine
## crossings, hanging vines and random crossings each twice as thick. Prints how
## long the round took to start, its bodies and its vines, then the table.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/fps_probe.gd -- [vines=<x>] [seed=<n>]

var main: Node


func _initialize() -> void:
	HeavyVines.apply(_arg("vines", 0.0))
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _arg(key: String, default: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return float(a.split("=")[1])
	return default


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
	print("%-10s %5.1f fps  frame %5.1f ms  process %5.1f ms  physics %5.1f ms  draws %d  prims %dk  objects %d  nodes %d" % [label, frames / secs, secs * 1000.0 / frames, proc / frames * 1000.0, phys / frames * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


func _run() -> void:
	for i in 5:
		await process_frame
	seed(int(_arg("seed", 1)))
	var started := Time.get_ticks_msec()
	main.start_solo()
	while main.world == null or main.world.player == null or not main.world.player.is_inside_tree():
		await process_frame
	var start_ms := Time.get_ticks_msec() - started
	for i in 120:
		await physics_frame
	var world = main.world
	var vines := root.find_children("*", "Vine", true, false).size()
	var strands := root.find_children("*", "VineStrand", true, false).size()
	var bridges := root.find_children("*", "RopeBridge", true, false).size()
	print("start %d ms  bodies %d  vines %d  strung %d  bridges %d" % [start_ms, root.find_children("*", "CollisionObject3D", true, false).size(), vines, strands, bridges])
	await _sample("clearing")
	if world.dev == null:
		world.dev = load("res://scripts/dev_tools.gd").new(world)
	for ring in [1, 2, 3]:
		world.dev.to_ring(ring)
		await _sample("ring %d" % ring)
	quit()
