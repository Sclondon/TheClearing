extends SceneTree
## Pictures of what grows on the first ring's walls: a vine strung across a hall,
## seen from under it, and ivy up a wall with a vine hanging from its top.
##
##     godot --path . --resolution 720x1280 -s res://tools/wall_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://wall_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var layout = world.get_node("Maze").layout
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	world.add_child(camera)
	camera.make_current()
	var strands: Array = layout.pieces(MazePiece.Kind.STRAND)
	var ivies: Array = layout.pieces(MazePiece.Kind.IVY)
	print("strands %d, ivy %d, vines %d" % [strands.size(), ivies.size(), layout.pieces(MazePiece.Kind.VINE).size()])
	for n in mini(2, strands.size()):
		var piece = strands[n * 7 % strands.size()]
		var a: Vector3 = piece.position
		var b: Vector3 = piece.bridge_end()
		var middle := (a + b) * 0.5
		var along := (b - a).normalized()
		var side := along.cross(Vector3.UP).normalized()
		camera.position = Vector3(middle.x, 1.7, middle.z) + side * 14.0
		camera.look_at(middle - Vector3.UP * 3.0)
		await _shot("%s/strand%d.png" % [folder, n])
	for n in mini(2, ivies.size()):
		var piece = ivies[n * 5 % ivies.size()]
		var out: Vector3 = piece.transform.basis.z
		camera.position = piece.position + out * 12.0 + Vector3.UP * 1.7
		camera.look_at(piece.position + Vector3.UP * piece.length * 0.5)
		await _shot("%s/ivy%d.png" % [folder, n])
	# Along the foot of a wall in a hall, at his eye height.
	var maze = world.maze
	var shots := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or maze.solid.has(cell) or maze.entrances.has(cell) or i % 97 != 0:
			continue
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step) and shots < 2:
				var s := Vector3(step.x, 0.0, step.y)
				var side := Vector3(-s.z, 0.0, s.x)
				camera.position = maze.world(cell) - s * 3.0 - side * 6.0 + Vector3.UP * 1.6
				camera.look_at(camera.position + side * 10.0 + s * 3.0 - Vector3.UP * 1.5)
				await _shot("%s/foot%d.png" % [folder, shots])
				shots += 1
				break
		if shots >= 2:
			break
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
