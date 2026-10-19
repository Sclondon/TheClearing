extends SceneTree
## Pictures of a sewer pipe through a wall in the first ring: its mouth (a bell on
## a lip: SewerMouth) from the hall floor, from beside it level with its lip, from
## level with its mouth, and from inside it; and the boy standing on its lip.
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/pipe_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	# (the Avenues, which has sewer pipes: the rules set in the editor may have none)
	MazeStyle.chosen = [MazeStyle.avenues()]
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
	world.dev = null
	var player = world.player
	player.visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	world.add_child(camera)
	camera.make_current()
	var pipes: Array = world.maze_features().pipes
	print("%d sewer pipes" % pipes.size())
	for n in mini(2, pipes.size()):
		var pipe: SewerPipe = pipes[n * 3 % pipes.size()]
		var along := pipe.global_basis.z
		var side := along.cross(Vector3.UP)
		var mouth := pipe.global_position - along * pipe.length * 0.5
		camera.position = Vector3(mouth.x, 1.6, mouth.z) - along * 14.0 + side * 3.0
		camera.look_at(mouth + Vector3.UP * 0.5)
		await _shot("%s/pipe%d_floor.png" % [folder, n])
		camera.position = mouth - along * 1.4 + side * 4.5 + Vector3.UP * 0.4
		camera.look_at(mouth - along * 0.9 + Vector3.UP * 0.2)
		await _shot("%s/pipe%d_side.png" % [folder, n])
		camera.position = mouth - along * 6.0 + side * 2.5 + Vector3.UP * 1.5
		camera.look_at(mouth + Vector3.UP * 0.5)
		await _shot("%s/pipe%d_mouth.png" % [folder, n])
		camera.position = mouth + along * 1.5 + Vector3.UP * 0.6
		camera.look_at(mouth + along * 10.0 + Vector3.UP * 0.6)
		await _shot("%s/pipe%d_inside.png" % [folder, n])
	# The boy standing on the lip of the first, in front of its mouth.
	if not pipes.is_empty():
		var pipe: SewerPipe = pipes[0]
		var along := pipe.global_basis.z
		var side := along.cross(Vector3.UP)
		var mouth := pipe.global_position - along * pipe.length * 0.5
		player.visible = true
		player.global_position = mouth - along * 1.2 + Vector3.UP * 0.2
		player.velocity = Vector3.ZERO
		for i in 40:
			await physics_frame
		print("the boy at %.2f, the lip's top %.2f, on the floor: %s" % [player.global_position.y, mouth.y, player.is_on_floor()])
		camera.position = mouth - along * 4.5 + side * 2.6 + Vector3.UP * 1.3
		camera.look_at(mouth - along * 0.8 + Vector3.UP * 0.7)
		await _shot("%s/boy_on_lip.png" % folder)
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
