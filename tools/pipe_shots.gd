extends SceneTree
## Pictures of a sewer pipe through a wall in the first ring: from the hall
## floor, from level with its mouth, and from inside it.
##
##     godot --path . --resolution 1280x720 -s res://tools/pipe_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://pipe_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	world.add_child(camera)
	camera.make_current()
	var pipes: Array = world.maze_features().pipes
	for n in mini(2, pipes.size()):
		var pipe: SewerPipe = pipes[n * 3 % pipes.size()]
		var along := pipe.global_basis.z
		var side := along.cross(Vector3.UP)
		var mouth := pipe.global_position - along * pipe.length * 0.5
		camera.position = Vector3(mouth.x, 1.6, mouth.z) - along * 9.0 + side * 4.0
		camera.look_at(mouth + Vector3.UP * 0.5)
		await _shot("%s/pipe%d_floor.png" % [folder, n])
		camera.position = mouth - along * 6.0 + side * 2.5 + Vector3.UP * 1.5
		camera.look_at(mouth + Vector3.UP * 0.5)
		await _shot("%s/pipe%d_mouth.png" % [folder, n])
		camera.position = mouth + along * 1.5 + Vector3.UP * 0.6
		camera.look_at(mouth + along * 10.0 + Vector3.UP * 0.6)
		await _shot("%s/pipe%d_inside.png" % [folder, n])
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
