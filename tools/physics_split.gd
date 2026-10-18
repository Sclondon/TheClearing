extends SceneTree
## What the physics time of a round goes on at the start: the physics time over
## the first seconds, with one kind of thing stopped from the start
## (-- enemies | vines | bridges | none), or only the enemies of one script left
## going (-- only:mummy.gd).
##
##     godot --path . --resolution 720x1280 -s res://tools/physics_split.gd -- vines

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _enemies() -> Array:
	var found := {}
	for node: Node in get_nodes_in_group(&"maze_enemies") + get_nodes_in_group(&"pursuers") + get_nodes_in_group(&"grievers"):
		found[node] = true
	return found.keys()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var stopped: String = args[0] if args.size() > 0 else "none"
	var seconds: int = int(args[1]) if args.size() > 1 else 12
	for i in 5:
		await process_frame
	var started := Time.get_ticks_msec()
	main.start_solo()
	var start_ms := Time.get_ticks_msec() - started
	var nodes: Array = []
	match stopped:
		"enemies":
			nodes = _enemies()
		"vines":
			nodes = root.find_children("*", "Vine", true, false)
		"bridges":
			nodes = root.find_children("*", "RopeBridge", true, false)
	if stopped.begins_with("only:"):
		for node: Node in _enemies():
			if node.get_script() == null or node.get_script().resource_path.get_file() != stopped.substr(5):
				nodes.append(node)
	for node: Node in nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	var line := ""
	for second in seconds:
		var phys := 0.0
		var frames := 0
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 1000:
			await process_frame
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			frames += 1
		line += "%d/%.0f " % [frames, phys / frames * 1000.0]
	print("%-22s start %d ms  fps/phys-ms: %s" % [stopped, start_ms, line])
	quit()
