extends SceneTree
## Pictures of the clearing: from high over it (mist thinned), and from the
## ground across its hills towards the woods, from the middle and from the field.
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	# (the woods: the corner with the most trees)
	var corner := Vector3.ZERO
	var counts := {}
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TREE):
		var key := Vector2i(signi(int(piece.position.x)), signi(int(piece.position.z)))
		counts[key] = counts.get(key, 0) + 1
	var most := 0
	for key: Vector2i in counts:
		if counts[key] > most:
			most = counts[key]
			corner = Vector3(key.x, 0.0, key.y)
	print("woods in corner ", corner, " (", most, " trees)")

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
	camera.position = corner.rotated(Vector3.UP, PI * 0.25) * -180.0 + Vector3.UP * 140.0
	camera.look_at(corner * 150.0)
	await _shot(folder + "/above_woods.png")
	# (low over the field, without the mist, to see the lie of the ground)
	var low := corner.rotated(Vector3.UP, PI * 0.5) * 230.0
	camera.position = low + Vector3.UP * (world.maze.ground_height(low) + 9.0)
	camera.look_at(corner.rotated(Vector3.UP, -PI * 0.5) * 100.0)
	world.player.visible = false
	await _shot(folder + "/hills.png")
	env.fog_density = fog
	env.fog_height_density = fog_height

	var maze = world.maze
	camera.fov = 62.0
	camera.position = Vector3(0.0, 1.7, 0.0)
	camera.look_at(corner * 200.0 + Vector3.UP * 6.0)
	await _shot(folder + "/middle_to_woods.png")
	var field := corner.rotated(Vector3.UP, PI * 0.5) * 120.0
	camera.position = field + Vector3.UP * (maze.ground_height(field) + 1.7)
	camera.look_at(Vector3(0.0, 8.0, 0.0))
	await _shot(folder + "/field.png")
	var edge := corner * 215.0
	camera.position = edge + Vector3.UP * (maze.ground_height(edge) + 1.7)
	camera.look_at(corner * 260.0 + Vector3.UP * 3.0)
	await _shot(folder + "/in_woods.png")
	quit()


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
