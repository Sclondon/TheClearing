extends SceneTree
## How long each kind of enemy's physics takes per tick over the first seconds
## of a round: their processing is stopped and each is run by hand, timed.
##
##     godot --path . --resolution 720x1280 -s res://tools/enemy_times.gd

var main: Node
var enemies: Array = []
var spent := {}
var ticks := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	print(shapes_report(self))
	var found := {}
	for node: Node in get_nodes_in_group(&"maze_enemies") + get_nodes_in_group(&"pursuers") + get_nodes_in_group(&"grievers"):
		found[node] = true
	enemies = found.keys()
	for node: Node in enemies:
		node.set_physics_process(false)
	physics_frame.connect(_tick)
	for second in 6:
		await create_timer(1.0).timeout
		var line := "second %d (%d ticks):" % [second, ticks]
		var keys := spent.keys()
		keys.sort_custom(func(a, b): return spent[a] > spent[b])
		for key: String in keys:
			line += " %s %.1f" % [key.get_basename(), spent[key] / 1000.0 / maxi(ticks, 1)]
		print(line)
		spent.clear()
		ticks = 0
	quit()


func _tick() -> void:
	ticks += 1
	var delta := 1.0 / Engine.physics_ticks_per_second
	for node: Node in enemies:
		if not is_instance_valid(node):
			continue
		var key: String = node.get_script().resource_path.get_file()
		var t := Time.get_ticks_usec()
		node._physics_process(delta)
		spent[key] = spent.get(key, 0) + Time.get_ticks_usec() - t


static func shapes_report(tree: SceneTree) -> String:
	var out := ""
	for body: CollisionObject3D in tree.root.find_children("*", "CollisionObject3D", true, false):
		var n := body.get_shape_owners().size()
		if n > 50:
			out += "%s %d shapes; " % [body.get_path(), n]
	return out
