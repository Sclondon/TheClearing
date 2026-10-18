extends SceneTree
## Pictures of the dirt between the walls (MazeStone's ground): down a hall at
## eye level, a puddle close to, the dirt at his feet, and a hall from a wall top.
## Needs a real window:
##
##     godot --path . --resolution 720x1280 -s res://tools/mud_shots.gd -- <folder> [phone]
##
## With "phone", the ground is drawn as on a phone or the web (its `detail` 1).

var main: Node
var folder := "mud_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func shot(name: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func _run() -> void:
	for i in 10:
		await process_frame
	main.start_solo()
	for i in 30:
		await process_frame
	var world = main.world
	var maze: Maze = world.maze
	world.player.visible = false
	if "phone" in OS.get_cmdline_user_args():
		for found: Node in world.find_children("Ground", "StaticBody3D", true, false):
			for look: Node in found.get_children():
				if look is MeshInstance3D:
					((look as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"detail", 1.0)
	world.camera.queue_free()
	var camera := Camera3D.new()
	camera.fov = 65.0
	world.add_child(camera)
	camera.make_current()

	# Down the longest straight run of hall along the way out (not back towards
	# the clearing).
	var path := maze.path_out(maze.cell_at(Vector3.ZERO))
	var outside: Array[Vector2i] = []
	for cell in path:
		if not maze.in_clearing(cell):
			outside.append(cell)
	var start: Vector2i = outside[0]
	var best := Vector2i(1, 0)
	var longest := 0
	for cell in outside:
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > longest:
				longest = run
				best = step
				start = cell
	var from := maze.world(start)
	var towards := Vector3(best.x, 0.0, best.y)
	camera.global_position = from + Vector3.UP * 1.6
	camera.look_at(from + towards * 20.0 + Vector3.UP * 0.4)
	await shot("1_hall")

	# A puddle: the lowest ground in a hall near the start (as the shader finds it).
	var puddle := Vector3.INF
	var deepest := 0.0
	for i in 4000:
		var cell: Vector2i = outside[i % outside.size()]
		# (in the middle of a cell, clear of the walls)
		var p := maze.world(cell) + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		var depth := _brim(p) - _lie(p)
		if depth > deepest:
			deepest = depth
			puddle = p
	print("deepest puddle %.3f at %s" % [deepest, puddle])
	if puddle != Vector3.INF:
		camera.global_position = puddle + Vector3(0.0, 1.5, 3.2)
		camera.look_at(puddle)
		await shot("2_puddle")
		camera.global_position = puddle - towards * 6.0 + Vector3.UP * 1.6
		camera.look_at(puddle)
		await shot("3_puddle_low")

	# The dirt at his feet, on the driest ground near the start.
	var driest := from
	var highest := -1.0
	for i in 400:
		var p := from + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
		if _lie(p) > highest:
			highest = _lie(p)
			driest = p
	camera.global_position = driest + Vector3(0.0, 1.5, 1.2)
	camera.look_at(driest)
	await shot("4_feet")

	# From a wall top, down into the halls.
	camera.global_position = from + Vector3.UP * (MazeBuilder.WALL_HEIGHT + 4.0) - towards * 6.0
	camera.look_at(from + towards * 26.0)
	await shot("5_from_above")
	quit()


# The shader's noise and the lie of the ground (scripts/maze_stone.gd GROUND_SHADER):
# textures/mud_noise.png, drawn smoothly between its pixels, the place in each eased.
var _noise: Image


func _patches(p: Vector2) -> float:
	if _noise == null:
		_noise = Image.load_from_file(ProjectSettings.globalize_path("res://textures/mud_noise.png"))
	var whole := p.floor()
	var part := p - whole
	part = part * part * (Vector2(3.0, 3.0) - 2.0 * part)
	# (as the GPU draws between pixel middles)
	var at := whole + part
	var low := at.floor()
	var t := at - low
	var pick := func(x: float, y: float) -> float: return _noise.get_pixel(posmod(int(x), 256), posmod(int(y), 256)).r
	return lerpf(lerpf(pick.call(low.x, low.y), pick.call(low.x + 1.0, low.y), t.x), lerpf(pick.call(low.x, low.y + 1.0), pick.call(low.x + 1.0, low.y + 1.0), t.x), t.y)


func _lie(p: Vector3) -> float:
	var at := Vector2(p.x, p.z)
	return _patches(at / 11.0 + Vector2(3.1, 3.1)) * 0.5 + _patches(at / 3.7 - Vector2(7.7, 7.7)) * 0.32 + _patches(at * 0.85 + Vector2(1.3, 1.3)) * 0.18


func _brim(p: Vector3) -> float:
	var at := Vector2(p.x, p.z)
	var hollow := _lie(p) * 0.45 + _patches(at / 2.9 + Vector2(11.0, 11.0)) * 0.38 + _patches(at / 1.1 - Vector2(3.0, 3.0)) * 0.17
	# (how deep the water stands over the hollow there: plus the lie, which the caller takes away)
	return 0.2 + 0.45 * 0.12 + (_patches(at / 37.0 + Vector2(2.0, 2.0)) - 0.5) * 0.1 - hollow + _lie(p)
