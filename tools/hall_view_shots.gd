extends SceneTree
## Pictures of the maze editor's hall view (MazeLayout.hall_view): the first
## section from above, its walls cut off `cut` metres up, and whole.
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/hall_view_shots.gd -- <folder> [cut m]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://hall_view_shots"
	var cut := float(args[1]) if args.size() > 1 else 3.0
	DirAccess.make_dir_recursive_absolute(folder)
	Wall.cut_away = true
	var styles := MazeStyle.square_defaults()
	styles[0].mezzanine_height = 10.0
	styles[0].mezzanine_depth = 1.0
	var plan := Maze.generate(1, 2, styles)
	var builder := MazeBuilder.new()
	builder.preview = true
	root.add_child(builder)
	await builder.build(plan)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 2000.0
	root.add_child(camera)
	var edge := plan.ring_sizes[0] * Maze.CELL * 0.5
	camera.look_at_from_position(Vector3(edge + 40.0, 160.0, edge + 40.0), Vector3(edge + 40.0, 0.0, edge - 10.0))
	camera.make_current()
	for shot: Array in [[cut, "cut"], [0.0, "whole"]]:
		RenderingServer.global_shader_parameter_set(&"maze_cut", shot[0])
		for node in builder.find_children("*", "", false):
			if node.name in ["Features", "Props"]:
				(node as Node3D).visible = shot[0] <= 0.0
		for i in 30:
			await process_frame
		root.get_texture().get_image().save_png("%s/hall_view_%s.png" % [folder, shot[1]])
		print("saved %s/hall_view_%s.png" % [folder, shot[1]])
	quit()
