extends SceneTree
## Pictures of the clearing: from high over it (mist thinned), then of each
## entrance and what is in front of it (ClearingStyle.entrances), from 60 m in
## at his eye height and from a little above.
##
##     godot --path . --resolution 720x1280 -s res://tools/clearing_shots.gd -- <folder> [seed]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://clearing_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	if args.size() > 1:
		main._begin([{"slot": 0, "look": main.look}], 0, false, int(args[1]))
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	var maze = world.maze
	var look: ClearingStyle = maze.clearing_style
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var env: Environment = null
	for found: Node in world.find_children("*", "WorldEnvironment", true, false):
		env = (found as WorldEnvironment).environment
	var fog := env.fog_density
	var fog_height := env.fog_height_density
	env.fog_density = 0.0012
	env.fog_height_density = 0.0
	camera.fov = 60.0
	camera.far = 3000.0
	camera.position = Vector3(0.0, 480.0, 330.0)
	camera.look_at(Vector3.ZERO)
	await _shot(folder + "/above.png")
	env.fog_density = fog
	env.fog_height_density = fog_height
	camera.fov = 62.0
	for i in look.entrance_spots.size():
		var name: String = ClearingStyle.Entrance.keys()[look.entrances[i]].to_lower() if i < look.entrances.size() else "plain"
		var gate: Vector2 = look.entrance_spots[i][0]
		var inward: Vector2 = look.entrance_spots[i][1]
		var from := gate + inward * 60.0 + inward.orthogonal() * 12.0
		camera.position = Vector3(from.x, maze.ground_height(Vector3(from.x, 0.0, from.y)) + 1.7, from.y)
		camera.look_at(Vector3(gate.x, 4.0, gate.y))
		await _shot("%s/%d_%s.png" % [folder, i, name])
		from = gate + inward * 90.0
		camera.position = Vector3(from.x, 22.0, from.y)
		camera.look_at(Vector3(gate.x, 0.0, gate.y) + Vector3(inward.x, 0.0, inward.y) * 25.0)
		await _shot("%s/%d_%s_above.png" % [folder, i, name])
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
