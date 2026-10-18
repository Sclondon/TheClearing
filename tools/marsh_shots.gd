extends SceneTree
## Pictures of the marsh in front of the flooded entrance (Marsh), landscape, the
## boy in them: standing at its edge, wading in it with the sedges round him, by
## a deep pool, at the gate looking in along the lane, low across the whole of
## it at his eye height, and from above at an angle to see all of it. Needs a
## real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/marsh_shots.gd -- <folder> [seed]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://marsh_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	if args.size() > 1:
		main._begin([{"slot": 0, "look": main.look}], 0, false, int(args[1]))
	for i in 30:
		await physics_frame
	var world = main.world
	var maze: Maze = world.maze
	var look: ClearingStyle = maze.clearing_style
	var marsh: Marsh = null
	for found: Node in world.find_children("Marsh", "Node3D", true, false):
		marsh = found as Marsh
	if marsh == null:
		push_error("no marsh in this maze")
		quit(1)
		return
	var way := look.entrance(ClearingStyle.Entrance.MARSH)
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	print("marsh %s, %d bulrushes, %d lily pads" % [marsh.area, marsh.bulrush_count, marsh.lily_pad_count])
	var player: Node3D = world.player
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 62.0
	camera.far = 3000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# At its edge: just in from where it begins, out along the marsh's middle line
	# a little to one side, looking in.
	var edge := _find(marsh, look, maze, rng, func(p: Vector2) -> bool:
		var wet := look.marsh_wet_at(p, maze.maze_seed)
		return wet > 0.12 and wet < 0.3 and (p - gate).dot(inward) > look.marsh_reach * 0.8 and marsh.depth_at(p) < -0.05)
	if edge.is_finite():
		var middle := gate + inward * (look.marsh_distance + look.marsh_reach * 0.5)
		var toward := (middle - edge).normalized()
		await _with_him(world, camera, maze, edge, toward, 4.2, 1.7, folder + "/1_edge.png")

	# Wading in shallow water, sedges round him.
	var wade := _find(marsh, look, maze, rng, func(p: Vector2) -> bool:
		var depth := marsh.depth_at(p)
		return look.marsh_wet_at(p, maze.maze_seed) > 0.8 and depth > 0.2 and depth < 0.38 and marsh.sedge_at(p) > 0.2)
	if wade.is_finite():
		await _with_him(world, camera, maze, wade, side, 3.6, 1.6, folder + "/2_wading.png")
		await _with_him(world, camera, maze, wade, -inward, 2.6, 1.9, folder + "/3_wading_close.png")

	# By a deep pool: the deepest point well inside it, him on the shore of it.
	var deepest := Vector2.INF
	var most := 0.0
	for i in 6000:
		var p := marsh.area.position + Vector2(rng.randf(), rng.randf()) * marsh.area.size
		if marsh.depth_at(p) > most:
			most = marsh.depth_at(p)
			deepest = p
	print("deepest %.2f m at %s" % [most, deepest])
	if deepest.is_finite():
		var shore := deepest
		for step in 40:
			var p := deepest + side * step * 0.5
			if marsh.depth_at(p) < 0.25:
				shore = p
				break
		await _with_him(world, camera, maze, shore, (deepest - shore).normalized() if shore != deepest else inward, 4.0, 1.8, folder + "/4_deep_pool.png")

	# In the gateway, looking in along the lane.
	await _with_him(world, camera, maze, gate + inward * 4.0, inward, 4.0, 1.7, folder + "/5_from_gate.png")

	# Low across the whole of it, at his eye height, from out in the field.
	player.visible = false
	var far := gate + inward * (look.marsh_distance + look.marsh_reach * 0.95) + side * 20.0
	camera.position = Vector3(far.x, maze.ground_height(Vector3(far.x, 0.0, far.y)) + 1.5, far.y)
	camera.look_at(Vector3(gate.x, 0.0, gate.y) + Vector3(inward.x, 0.0, inward.y) * 40.0)
	await _shot(folder + "/6_across.png")

	# From above at an angle: the whole of it, the mist thinned.
	var env: Environment = null
	for found: Node in world.find_children("*", "WorldEnvironment", true, false):
		env = (found as WorldEnvironment).environment
	var fog := env.fog_density
	env.fog_density = fog * 0.35
	var centre := gate + inward * (look.marsh_distance + look.marsh_reach * 0.5)
	var from := centre + inward * 120.0 + side * 30.0
	camera.position = Vector3(from.x, 60.0, from.y)
	camera.look_at(Vector3(centre.x, -2.0, centre.y))
	await _shot(folder + "/7_above.png")
	from = centre + inward * 45.0 + side * 15.0
	camera.position = Vector3(from.x, 22.0, from.y)
	camera.look_at(Vector3(centre.x, 0.0, centre.y) - Vector3(inward.x, 0.0, inward.y) * 15.0)
	await _shot(folder + "/8_above_close.png")
	# (straight down over the whole of it, no mist: the lie of its water)
	env.fog_density = 0.0
	camera.position = Vector3(centre.x, 150.0, centre.y)
	camera.look_at(Vector3(centre.x, 0.0, centre.y), Vector3(-inward.x, 0.0, -inward.y))
	await _shot(folder + "/9_plan.png")
	env.fog_density = fog
	quit()


# A point in the marsh that `wanted` says yes to, tried at random; INF if none.
func _find(marsh: Marsh, _look: ClearingStyle, _maze: Maze, rng: RandomNumberGenerator, wanted: Callable) -> Vector2:
	for i in 20000:
		var p := marsh.area.position + Vector2(rng.randf(), rng.randf()) * marsh.area.size
		if wanted.call(p):
			return p
	return Vector2.INF


# Him standing at `at` facing `toward`, the camera `back` metres behind him and
# `high` up.
func _with_him(world: Node, camera: Camera3D, maze: Maze, at: Vector2, toward: Vector2, back: float, high: float, path: String) -> void:
	var player: Node3D = world.player
	player.visible = true
	var ground := maze.ground_height(Vector3(at.x, 0.0, at.y))
	world.put_player(Vector3(at.x, ground + 0.05, at.y), atan2(toward.x, toward.y))
	for i in 30:
		await physics_frame
	var foot := player.global_position
	print("%s: him at %s (asked %s), water %.2f deep" % [path.get_file(), foot, at, ClearingStyle.MARSH_LEVEL - maze.ground_height(foot)])
	var eye := foot - Vector3(toward.x, 0.0, toward.y) * back
	camera.position = Vector3(eye.x, maxf(foot.y, ClearingStyle.MARSH_LEVEL) + high, eye.z)
	camera.look_at(foot + Vector3(toward.x, 0.0, toward.y) * 6.0 + Vector3.UP * 0.6)
	await _shot(path)


func _shot(path: String) -> void:
	# (the grass round where the camera now is, filled at once)
	var camera := root.get_viewport().get_camera_3d()
	for field: Grass in get_nodes_in_group(Grass.FIELDS):
		field.fill_near(camera.global_position, 70.0)
	for i in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
