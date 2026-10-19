extends SceneTree
## Where a round's hitches come from: a solo round, the boy in the clearing (or a
## ring, ring=<n>), the slow frames (over 25 ms) counted over three seconds as it
## is, then with each thing stopped in turn: every script's _physics_process,
## every _process, and each kind of script that processes.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/spike_split.gd -- [ring=<n>]

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


## [slow frames, worst ms, median ms] over `seconds`.
func _spikes(seconds := 3.0) -> Array:
	for i in 10:
		await process_frame
	var times: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < seconds * 1e6:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var slow := times.filter(func(t: float) -> bool: return t > 25.0).size()
	times.sort()
	return [slow, times[-1], times[times.size() / 2]]


func _key(n: Node) -> String:
	return n.get_script().resource_path.get_file() if n.get_script() else n.get_class()


func _without(label: String, nodes: Array, process: bool, physics: bool) -> void:
	var was := {}
	for n: Node in nodes:
		if is_instance_valid(n):
			was[n] = [n.is_processing(), n.is_physics_processing()]
			if process:
				n.set_process(false)
			if physics:
				n.set_physics_process(false)
	var r: Array = await _spikes()
	for n: Node in was:
		if is_instance_valid(n):
			n.set_process(was[n][0])
			n.set_physics_process(was[n][1])
	print("  without %-40s slow %3d  worst %5.1f  median %5.1f  [%d]" % [label, r[0], r[1], r[2], nodes.size()])


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 180:
		await process_frame
	var world = main.world
	var ring := _arg("ring", 0)
	if ring > 0:
		if world.dev == null:
			world.dev = load("res://scripts/dev_tools.gd").new(world)
		world.dev.to_ring(ring)
		for i in 120:
			await process_frame
	var r: Array = await _spikes()
	print("as it is: slow %d  worst %.1f  median %.1f" % r)
	var all: Array = root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n != main)
	var phys := all.filter(func(n: Node) -> bool: return n.is_physics_processing())
	var procs := all.filter(func(n: Node) -> bool: return n.is_processing())
	await _without("every _physics_process", phys, false, true)
	await _without("every _process", procs, true, false)
	var kinds := {}
	for n: Node in phys + procs:
		if not kinds.has(_key(n)):
			kinds[_key(n)] = {}
		kinds[_key(n)][n] = true
	var keys := kinds.keys()
	keys.sort_custom(func(a, b) -> bool: return kinds[a].size() > kinds[b].size())
	var only: Array = Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return a.begins_with("only="))
	for k in keys:
		if only.is_empty() or k in only[0].substr(5).split(","):
			await _without(k, kinds[k].keys(), true, true)
	quit()
