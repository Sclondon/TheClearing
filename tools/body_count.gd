extends SceneTree
## How many physics bodies a solo round makes, by kind (Jolt stops making them
## past jolt_physics_3d/limits/max_bodies, and what comes after has none).
## `defaults`: with the game's own section styles, not the maze editor's (catwalks
## in the second and third); `nocatwalks` too: those without their catwalks.
##
##     godot --headless --path . --audio-driver Dummy -s res://tools/body_count.gd [-- defaults [nocatwalks]]
var main: Node
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("defaults"):
		var styles := MazeStyle.defaults()
		if args.has("nocatwalks"):
			for style in styles:
				style.catwalk_share = 0.0
		MazeStyle.chosen = styles
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()
func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 90:
		await process_frame
	var by := {}
	var total := 0
	for n in root.find_children("*", "CollisionObject3D", true, false):
		total += 1
		var key: String = n.get_class() + " / " + (n.get_parent().get_script().resource_path.get_file() if n.get_parent() and n.get_parent().get_script() else n.get_parent().get_class() if n.get_parent() else "")
		if n.get_script():
			key = n.get_class() + " " + n.get_script().resource_path.get_file()
		by[key] = by.get(key, 0) + 1
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	print("bodies %d" % total)
	for k in keys.slice(0, 25):
		print("  %6d %s" % [by[k], k])
	quit()
