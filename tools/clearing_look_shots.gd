extends SceneTree
## Pictures of how the clearing looks close to, as he sees it: the ground near
## the middle where a round begins (from his camera, and looking down at it),
## the ground out on the hills and at the foot of the wall, a bush up close, and
## the tall grass running up to the wall and the gate of its entrance.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/clearing_look_shots.gd -- <folder> [seed]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://clearing_look_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main._begin([{"slot": 0, "look": main.look}], 0, false, int(args[1]) if args.size() > 1 else 12345)
	for i in 30:
		await physics_frame
	var world = main.world
	var maze = world.maze
	var look: ClearingStyle = maze.clearing_style
	# As he sees it when the round begins (his own camera).
	for i in 60:
		await process_frame
	await _shot(folder + "/start.png")
	world.player.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 62.0
	var ground := func(p: Vector2) -> float: return maze.ground_height(Vector3(p.x, 0.0, p.y))
	# The ground, looked down on, near the middle, out on the hills, by the wall.
	var half: float = maze.clearing * Maze.CELL * 0.5
	for spot: Array in [["middle", Vector2(6.0, 4.0)], ["hills", Vector2(half * 0.55, -half * 0.3)], ["wall_foot", Vector2(-half + 14.0, half * 0.2)]]:
		var at: Vector2 = spot[1]
		camera.position = Vector3(at.x, ground.call(at) + 3.0, at.y)
		camera.look_at(Vector3(at.x + 8.0, ground.call(at + Vector2(8.0, 0.0)), at.y + 2.0))
		await _shot("%s/ground_%s.png" % [folder, spot[0]])
		camera.position = Vector3(at.x, ground.call(at) + 1.7, at.y)
		camera.look_at(Vector3(at.x + 40.0, ground.call(at + Vector2(40.0, 0.0)) + 1.0, at.y + 10.0))
		await _shot("%s/ground_%s_far.png" % [folder, spot[0]])
	# A bush up close (the one nearest the middle).
	var plants: Undergrowth = world.find_children("*", "Undergrowth", true, false)[0]
	var bush := Vector3.INF
	for key: Array in plants._placed:
		if key[0] != Undergrowth.Kind.BUSH:
			continue
		for where: Transform3D in plants._placed[key]:
			if where.origin.length() < bush.length():
				bush = where.origin
	if bush.is_finite():
		var aside := Vector3(1.0, 0.0, 0.4).normalized()
		camera.position = bush + aside * 4.0 + Vector3.UP * 1.6
		camera.look_at(bush + Vector3.UP * 0.6)
		await _shot(folder + "/bush_close.png")
		camera.position = bush + aside * 12.0 + Vector3.UP * 2.0
		camera.look_at(bush + Vector3.UP * 0.6)
		await _shot(folder + "/bush_far.png")
	# The tall grass: from in it, at his eye height, towards its gate; along the
	# foot of the wall beside the gate; and over it from above.
	var way := look.entrance(ClearingStyle.Entrance.TALL_GRASS)
	if not way.is_empty():
		var gate: Vector2 = way[0]
		var inward: Vector2 = way[1]
		var side := inward.orthogonal()
		var from := gate + inward * 18.0 + side * 4.0
		camera.position = Vector3(from.x, ground.call(from) + 1.5, from.y)
		camera.look_at(Vector3(gate.x, 2.0, gate.y))
		await _shot(folder + "/tall_gate.png")
		from = gate + inward * 6.0 + side * 30.0
		camera.position = Vector3(from.x, ground.call(from) + 4.0, from.y)
		camera.look_at(Vector3(gate.x, 0.5, gate.y) + Vector3(inward.x, 0.0, inward.y) * 2.0)
		await _shot(folder + "/tall_wall_foot.png")
		from = gate + inward * 45.0
		camera.position = Vector3(from.x, ground.call(from) + 14.0, from.y)
		camera.look_at(Vector3(gate.x, 0.0, gate.y))
		await _shot(folder + "/tall_above.png")
		from = gate + inward * 3.0 + side * 110.0
		camera.position = Vector3(from.x, ground.call(from) + 1.6, from.y)
		camera.look_at(Vector3(gate.x, 1.2, gate.y) + Vector3(inward.x, 0.0, inward.y) * 8.0)
		await _shot(folder + "/tall_along_wall.png")
		from = gate + inward * 120.0 + side * 40.0
		camera.position = Vector3(from.x, ground.call(from) + 30.0, from.y)
		camera.look_at(Vector3(gate.x, 0.0, gate.y) + Vector3(inward.x, 0.0, inward.y) * 40.0)
		await _shot(folder + "/tall_wide.png")
	quit()


func _shot(path: String) -> void:
	# (the grass filled round the camera at once, not over the next frames as it nears)
	var eye := root.get_viewport().get_camera_3d().global_position
	for field: Grass in main.world.find_children("*", "Grass", true, false):
		field.fill_near(eye, 90.0)
	for i in 25:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
