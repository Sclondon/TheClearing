extends SceneTree
## Pictures of the first ring's mezzanine, from the hall floor looking up along a
## wall, and from on the ledge.
##
##     godot --path . --resolution 720x1280 -s res://tools/ledge_shots.gd -- <folder> [ring]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://ledge_shots"
	var ring: int = int(args[1]) if args.size() > 1 else 1
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
	var maze = world.maze
	var high: float = maze.styles[ring - 1].mezzanine_height
	var shots := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != ring or maze.solid.has(cell) or maze.entrances.has(cell) or i % 61 != 0:
			continue
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step) and shots < 3:
				var s := Vector3(step.x, 0.0, step.y)
				var side := Vector3(-s.z, 0.0, s.x)
				camera.position = maze.world(cell) - s * 9.0 - side * 8.0 + Vector3.UP * 1.6
				camera.look_at(maze.world(cell) + s * 4.0 + side * 6.0 + Vector3.UP * high)
				await _shot("%s/up%d.png" % [folder, shots])
				camera.position = maze.world(cell) - s * 6.0 + Vector3.UP * (high + 6.0)
				camera.look_at(maze.world(cell) + s * 4.0 + Vector3.UP * high)
				await _shot("%s/above%d.png" % [folder, shots])
				shots += 1
				break
		if shots >= 3:
			break
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
