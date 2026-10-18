extends SceneTree
## What each kind of script costs a frame, a second into a round: what is processing,
## by script, then each run by hand and timed.
##
##     godot --path . --resolution 1280x720 -s res://tools/script_costs.gd -- [rings=<n>]
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
	for i in 60:
		await process_frame
	var counts := {}
	for node in root.find_children("*", "", true, false):
		if node.is_processing() or node.is_physics_processing():
			var key: String = node.get_script().resource_path.get_file() if node.get_script() else node.get_class()
			counts[key] = counts.get(key, 0) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 25):
		print("%5d %s" % [counts[k], k])
	# time each script's _process + _physics_process for a few frames
	var spent := {}
	var nodes := root.find_children("*", "", true, false).filter(func(n): return n.get_script() and (n.is_processing() or n.is_physics_processing()))
	for n in nodes:
		n.set_process(false)
		n.set_physics_process(false)
	for f in 30:
		await physics_frame
		for n in nodes:
			if not is_instance_valid(n):
				continue
			var key: String = n.get_script().resource_path.get_file()
			var t := Time.get_ticks_usec()
			if n.has_method("_process"):
				n._process(1.0 / 60.0)
			if n.has_method("_physics_process"):
				n._physics_process(1.0 / 60.0)
			spent[key] = spent.get(key, 0) + Time.get_ticks_usec() - t
	keys = spent.keys()
	keys.sort_custom(func(a, b): return spent[a] > spent[b])
	for k in keys.slice(0, 15):
		print("%8.2f ms/frame %s" % [spent[k] / 30000.0, k])
	quit()
