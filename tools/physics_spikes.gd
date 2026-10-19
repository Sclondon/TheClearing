extends SceneTree
## What makes a slow physics frame: a solo round, the boy in the clearing (or a
## ring, ring=<n>), every script's _physics_process run by hand each physics frame
## and timed, and for each frame whose scripts took over 8 ms, the nodes that took
## the most (and the total by kind).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/physics_spikes.gd -- [ring=<n>] [seconds=<s>]

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
	for i in 180:
		await process_frame
	var ring := _arg("ring", 0)
	if ring > 0:
		if main.world.dev == null:
			main.world.dev = load("res://scripts/dev_tools.gd").new(main.world)
		main.world.dev.to_ring(ring)
		for i in 120:
			await process_frame
	var seconds := _arg("seconds", 4)
	var start := Time.get_ticks_msec()
	var shown := 0
	while Time.get_ticks_msec() - start < seconds * 1000 and shown < 12:
		# (taken over afresh each frame: what wakes up starts processing again)
		var nodes: Array = root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() != null and n != main and n.is_physics_processing() and n.can_process())
		for n: Node in nodes:
			n.set_physics_process(false)
		await physics_frame
		var spent := []
		var total := 0
		var by_kind := {}
		for n: Node in nodes:
			if not is_instance_valid(n) or not n.is_inside_tree():
				continue
			var t := Time.get_ticks_usec()
			n._physics_process(1.0 / Engine.physics_ticks_per_second)
			var us := Time.get_ticks_usec() - t
			total += us
			spent.append([us, n])
			var k: String = n.get_script().resource_path.get_file()
			by_kind[k] = by_kind.get(k, 0) + us
		for n: Node in nodes:
			if is_instance_valid(n):
				n.set_physics_process(true)
		if total > 8000:
			shown += 1
			spent.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var kinds := by_kind.keys()
			kinds.sort_custom(func(a, b) -> bool: return by_kind[a] > by_kind[b])
			print("at %.2f s: scripts %.1f ms (%d nodes)" % [(Time.get_ticks_msec() - start) / 1000.0, total / 1000.0, nodes.size()])
			for one in spent.slice(0, 5):
				print("    %6.2f ms  %s (%s)" % [one[0] / 1000.0, one[1].name, one[1].get_script().resource_path.get_file()])
			for k in kinds.slice(0, 5):
				print("    by kind %6.2f ms  %s" % [by_kind[k] / 1000.0, k])
	quit()
