extends SceneTree
## Where each place's frame goes: the boy put in the clearing, each ring and the
## desert in turn, the real frame time measured, then every script that processes
## there timed by hand for thirty frames (its nodes counted), and the frame time
## again with each kind of drawn thing hidden. Run with -- dev.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/frame_split.gd -- dev [only=<place>] [settle=<frames>]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _frame_ms(frames: int) -> float:
	var world = main.world
	var started := Time.get_ticks_usec()
	for i in frames:
		world.camera._yaw += 0.02
		await process_frame
	return (Time.get_ticks_usec() - started) / 1000.0 / frames


func _run() -> void:
	var only := ""
	var settle := 90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("settle="):
			settle = int(arg.substr(7))
		if arg.begins_with("only="):
			only = arg.substr(5)
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
		if only != "" and place[0] != only:
			continue
		(place[1] as Callable).call()
		for i in settle:
			await process_frame
		var frame: float = await _frame_ms(120)
		print("\n=== %s: frame %.1f ms (%.0f fps)  draws %d  triangles %d" % [place[0], frame, 1000.0 / frame, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		await _scripts()
		await _drawn(frame)
	quit()


## Every processing script's _process and _physics_process, run by hand and timed.
func _scripts() -> void:
	var nodes: Array = root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n.can_process() and (n.is_processing() or n.is_physics_processing()))
	var was := {}
	var counts := {}
	for n: Node in nodes:
		was[n] = [n.is_processing(), n.is_physics_processing()]
		n.set_process(false)
		n.set_physics_process(false)
		var key: String = n.get_script().resource_path.get_file()
		counts[key] = counts.get(key, 0) + 1
	var spent := {}
	const FRAMES := 30
	for f in FRAMES:
		await physics_frame
		for n: Node in nodes:
			if not is_instance_valid(n):
				continue
			var key: String = n.get_script().resource_path.get_file()
			var t := Time.get_ticks_usec()
			if was[n][0] and n.has_method("_process"):
				n._process(1.0 / 60.0)
			if was[n][1] and n.has_method("_physics_process"):
				n._physics_process(1.0 / 60.0)
			spent[key] = spent.get(key, 0) + Time.get_ticks_usec() - t
	for n: Node in nodes:
		if is_instance_valid(n):
			n.set_process(was[n][0])
			n.set_physics_process(was[n][1])
	var keys := spent.keys()
	keys.sort_custom(func(a, b): return spent[a] > spent[b])
	var total := 0
	for k in keys:
		total += spent[k]
	print("  scripts %.1f ms a frame in all, %d nodes processing" % [total / 1000.0 / FRAMES, nodes.size()])
	for k in keys.slice(0, 12):
		if spent[k] / 1000.0 / FRAMES < 0.05:
			break
		print("  %6.2f ms  %5d x %s" % [spent[k] / 1000.0 / FRAMES, counts[k], k])


## The frame with each kind of drawn thing hidden in turn (and shown again).
func _drawn(frame: float) -> void:
	for kind in ["GPUParticles3D", "CPUParticles3D", "MultiMeshInstance3D", "MeshInstance3D", "Light3D"]:
		var hid: Array = []
		for n: Node3D in root.find_children("*", kind, true, false):
			if n.is_visible_in_tree():
				n.visible = false
				hid.append(n)
		if hid.is_empty():
			continue
		for i in 20:
			await process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var ms: float = await _frame_ms(60)
		for n: Node3D in hid:
			if is_instance_valid(n):
				n.visible = true
		print("  without %-20s (%5d): %5.1f ms (%+.1f)  draws then %d" % [kind, hid.size(), ms, ms - frame, draws])
	for i in 20:
		await process_frame
