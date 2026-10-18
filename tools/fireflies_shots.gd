extends SceneTree
## Pictures of the fireflies (creatures/fireflies, Insects' fireflies), landscape.
## `studio`: a cloud close up against the dark, the beetles themselves close to
## the camera, and the same cloud scattered by someone running through it.
## `round`: in a round at dusk and at night, as the game puts them: over the tall
## grass, in the woods, over the marsh, at the foot of the ivy in the first ring,
## and a few seconds apart to show their blinking. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/fireflies_shots.gd -- <folder> [studio|round|all]

var folder := "user://fireflies_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0] if args.size() > 0 else folder
	DirAccess.make_dir_recursive_absolute(folder)
	var which: String = args[1] if args.size() > 1 else "all"
	_run(which)


func _run(which: String) -> void:
	if which == "studio" or which == "all":
		await _studio()
	if which == "round" or which == "all":
		await _round()
	quit()


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# --- Studio ---

func _studio() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.07, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.34, 0.42)
	env.environment.ambient_light_energy = 0.4
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.6
	env.environment.glow_hdr_threshold = 0.9
	stage.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.64, 0.82)
	moon.light_energy = 0.3
	stage.add_child(moon)
	moon.look_at_from_position(Vector3(2, 5, 3), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.16, 0.17, 0.14)
	ground.material_override = dirt
	stage.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 50.0
	stage.add_child(camera)
	camera.make_current()
	var field := FireflyField.new()
	field.lights = 1
	stage.add_child(field)
	field.add_patch(Vector3(0.0, 0.0, -6.0), 7.0, 120, Vector2(0.3, 2.0), 3)
	field.add_patch(Vector3(9.0, 0.0, -18.0), 7.0, 90, Vector2(0.3, 2.0), 4)
	field.night = 1.0
	camera.look_at_from_position(Vector3(0.0, 1.3, 4.0), Vector3(0.0, 1.0, -8.0))
	await _wait(1.0)
	for k in 3:
		await _shot("%s/studio_cloud_%d.png" % [folder, k])
		await _wait(0.7)
	# The beetles close: find one near and look at it.
	camera.fov = 10.0
	var close := Vector3(0.0, 1.0, -2.0)
	camera.look_at_from_position(Vector3(0.6, 1.2, 0.5), close)
	field.add_patch(close + Vector3(0.0, -1.0, 0.0), 0.4, 6, Vector2(0.95, 1.05), 9)
	await _wait(0.6)
	await _shot(folder + "/studio_beetles.png")
	await _wait(0.9)
	await _shot(folder + "/studio_beetles_b.png")
	# Someone running through the cloud.
	camera.fov = 50.0
	camera.look_at_from_position(Vector3(0.0, 1.3, 4.0), Vector3(0.0, 1.0, -8.0))
	var runner := Node3D.new()
	stage.add_child(runner)
	field.scarers = [runner]
	for i in 50:
		runner.global_position = Vector3(-6.0 + i * 0.24, 0.0, -6.0)
		await process_frame
	await _shot(folder + "/studio_scattered.png")
	stage.queue_free()
	await process_frame


# --- In a round ---

func _round() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 40:
		await physics_frame
	var world = main.world
	var maze: Maze = world.maze
	var insects: Insects = world.insects
	var field := insects.fireflies
	var player: Node3D = world.player
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 60.0
	camera.far = 2000.0
	world.dev = load("res://scripts/dev_tools.gd").new(world)
	world.dev.god = true
	var look := maze.clearing_style
	var day: DayCycle = world.day
	# The patches, by where they are.
	var meadow := look.tall_grass_middle()
	var places := {}
	for k in field.patch_count():
		var at := field.patch_middle(k)
		var ring := maze.ring_of(maze.cell_at(at))
		var where := "ring" if ring == 1 else ("marsh" if look.marsh_rect().has_point(Vector2(at.x, at.z)) else ("tall_grass" if meadow.is_finite() and look.tall_grass_rect().has_point(Vector2(at.x, at.z)) else "woods_or_meadow"))
		if not places.has(where):
			places[where] = at
	for hour: float in [DayCycle.SUNSET + 0.6, 23.0]:
		day.set_hour(hour)
		var when := "dusk" if hour < 22.0 else "night"
		for where: String in places:
			var at: Vector3 = places[where]
			var back := Vector3(1.0, 0.0, 0.6).normalized() * 9.0
			if where == "ring":
				back = _along_hall(maze, at) * 9.0
			world.put_player(at + back * 0.6 + Vector3.UP * 0.3, atan2(-back.x, -back.z))
			player.visible = where == "tall_grass"
			camera.look_at_from_position(at + back * 1.3 + Vector3.UP * 2.4, at + Vector3.UP * 0.9)
			await _wait(1.2)
			await _shot("%s/round_%s_%s.png" % [folder, when, where])
	# Blinking: the same view a moment apart.
	if places.has("tall_grass"):
		var at: Vector3 = places["tall_grass"]
		camera.look_at_from_position(at + Vector3(8.0, 2.6, 8.0), at + Vector3.UP * 0.8)
		player.visible = false
		for k in 3:
			await _wait(1.1)
			await _shot("%s/round_blink_%d.png" % [folder, k])
	quit()


func _along_hall(maze: Maze, at: Vector3) -> Vector3:
	var cell := maze.cell_at(at)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			return Vector3(step.x, 0.0, step.y)
	return Vector3.BACK
