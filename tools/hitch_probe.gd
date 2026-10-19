extends SceneTree
## Hitches: a solo round played for a while with the boy standing in the
## clearing, every frame timed, and each one much slower than the usual printed
## with when it came and what the engine says went into it (script, physics,
## objects made, draw calls). Run with -- dev to start in a ring instead (ring=<n>).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/hitch_probe.gd -- [ring=<n>] [seconds=<s>]

var main: Node


func _initialize() -> void:
	HeavyVines.apply(_arg("vines", 0))
	seed(_arg("seed", 1))
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
	var ring := _arg("ring", 0)
	var seconds := _arg("seconds", 20)
	for i in 180:
		await process_frame
	if ring > 0:
		if main.world.dev == null:
			main.world.dev = load("res://scripts/dev_tools.gd").new(main.world)
		main.world.dev.to_ring(ring)
		for i in _arg("settle", 120):
			await process_frame
	if OS.get_cmdline_user_args().has("scripts"):
		await _worst_scripts(seconds)
		quit()
		return
	print("hunters %d" % main.world.enemies.enemies.size())
	var times: Array[float] = []
	var rows: Array = []
	var start := Time.get_ticks_usec()
	var last := start
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	while Time.get_ticks_usec() - start < seconds * 1000000:
		var t := (Time.get_ticks_usec() - start) / 1e6
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		times.append(ms)
		var obj := Performance.get_monitor(Performance.OBJECT_COUNT)
		rows.append([t, ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, obj - objects,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		objects = obj
	var sorted := times.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	print("frames %d, median %.1f ms, p99 %.1f ms, worst %.1f ms" % [times.size(), median, sorted[int(sorted.size() * 0.99)], sorted[-1]])
	var prev := -1.0
	for r: Array in rows:
		if r[1] > max(median * 2.5, median + 12.0):
			print("  at %6.2f s (+%.2f): %.1f ms  process %.1f  physics %.1f  objects %+d  draws %d" % [r[0], r[0] - prev if prev >= 0 else 0.0, r[1], r[2], r[3], r[4], r[5]])
			prev = r[0]
	quit()


## With `scripts`: every processing script's _process and _physics_process run by
## hand for `seconds` (at 60 a second) and the slowest single run of each kind
## printed, so what does a lot now and then shows (frame_split's averages hide it).
func _worst_scripts(seconds: int) -> void:
	var nodes: Array = root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n.can_process() and (n.is_processing() or n.is_physics_processing()))
	var was := {}
	for n: Node in nodes:
		was[n] = [n.is_processing(), n.is_physics_processing()]
		n.set_process(false)
		n.set_physics_process(false)
	var worst := {}
	var total := {}
	var count := {}
	for n: Node in nodes:
		var k: String = n.get_script().resource_path.get_file()
		count[k] = count.get(k, 0) + 1
	# (awake hunters by how far from the boy)
	var bands := {}
	var boy: Node3D = main.world.player
	for e: Node in main.world.enemies.enemies:
		if e.can_process():
			var band := int(boy.global_position.distance_to(e.global_position) / 40.0) * 40
			bands[band] = bands.get(band, 0) + 1
	var band_keys := bands.keys()
	band_keys.sort()
	for b in band_keys:
		print("  awake hunters %3d-%3d m: %d" % [b, b + 40, bands[b]])
	var when := {}
	for f in seconds * 60:
		await process_frame
		for n: Node in nodes:
			if not is_instance_valid(n):
				continue
			var key: String = n.get_script().resource_path.get_file()
			var t := Time.get_ticks_usec()
			if was[n][0] and n.has_method("_process"):
				n._process(1.0 / 60.0)
			if was[n][1] and n.has_method("_physics_process"):
				n._physics_process(1.0 / 60.0)
			var us := Time.get_ticks_usec() - t
			total[key] = total.get(key, 0) + us
			if us > worst.get(key, 0):
				worst[key] = us
				when[key] = "%s, frame %d" % [n.name, f]
	var keys := worst.keys()
	keys.sort_custom(func(a, b) -> bool: return worst[a] > worst[b])
	for key in keys.slice(0, 15):
		print("  %-32s worst %7.1f ms  (%s)" % [key, worst[key] / 1000.0, when[key]])
	keys = total.keys()
	keys.sort_custom(func(a, b) -> bool: return total[a] > total[b])
	var all := 0.0
	for key in keys:
		all += total[key]
	print("  scripts in all: %.1f ms a frame" % (all / 1000.0 / (seconds * 60)))
	for key in keys.slice(0, 20):
		print("  %-32s %6.2f ms a frame  (%d of them)" % [key, total[key] / 1000.0 / (seconds * 60), count[key]])
