extends SceneTree
## What runners (MazeRunner) cost: the frame they are put in by the dev panel's
## + RUNNERS, then, over five seconds, the worst frame and each runner's thinking,
## driving and the rest of its physics step timed by hand. Run with -- dev.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/runner_costs.gd -- dev

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
	var before: Array = world.runners.get_children()
	var t := Time.get_ticks_usec()
	world.dev.spawn_runners()
	print("+ RUNNERS took %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var started := Time.get_ticks_msec()
	var last := started
	var worst := 0
	var frames := 0
	while Time.get_ticks_msec() - started < 5000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
	print("next 5 s: %.0f fps, worst frame %d ms" % [frames / 5.0, worst])
	print("physics %.1f ms a step" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0))
	await _scripts()
	var fresh: Array = world.runners.get_children().filter(func(r: Node) -> bool: return not before.has(r) and r is MazeRunner)
	var think := 0
	var drive := 0
	var whole := 0
	const FRAMES := 120
	for r: MazeRunner in fresh:
		r.set_physics_process(false)
	for f in FRAMES:
		await physics_frame
		for r: MazeRunner in fresh:
			var a := Time.get_ticks_usec()
			r._think(1.0 / 60.0)
			var b := Time.get_ticks_usec()
			r._drive()
			var c := Time.get_ticks_usec()
			# (the rest of the step: DrivenBoy's, the controller's)
			r.call(&"_physics_process", 1.0 / 60.0)
			var d := Time.get_ticks_usec()
			think += b - a
			drive += c - b
			whole += d - c
	for r: MazeRunner in fresh:
		r.set_physics_process(true)
	var n := maxf(fresh.size(), 1) * FRAMES * 1000.0
	print("each runner a frame: think %.2f ms, drive %.2f ms, whole step (think+drive again+controller) %.2f ms  (%d runners, modes %s)" % [think / n, drive / n, whole / n, fresh.size(), str(fresh.map(func(r: MazeRunner) -> String: return MazeRunner.Mode.keys()[r.mode]))])
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


