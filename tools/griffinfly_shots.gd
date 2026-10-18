extends SceneTree
## Pictures of the griffinfly (creatures/griffinfly, scripts/enemies/maze_griffinfly.gd),
## landscape. `studio`: big against grey, from the side, above, in front and
## close on the head, hovering, gliding, its basket of legs thrown forward and its
## jaws open, and resting on a wall. `strip`: one wingbeat, frame by frame, from
## the side and from in front (the four wings each on its own stroke). `maze`: in
## a round: hunting over a hall, over the marsh, coming at the boy (the wind-up
## and the strike) and resting on a wall. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/griffinfly_shots.gd -- <folder> [studio|strip|maze|all]

var folder := "user://griffinfly_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0] if args.size() > 0 else folder
	DirAccess.make_dir_recursive_absolute(folder)
	var which: String = args[1] if args.size() > 1 else "all"
	_run(which)


func _run(which: String) -> void:
	if which == "studio" or which == "all":
		await _studio()
	if which == "strip" or which == "all":
		await _strip()
	if which == "maze" or which == "all":
		await _maze()
	quit()


func _shot(path: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _stage() -> Array:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	stage.add_child(sun)
	sun.look_at_from_position(Vector3(2, 5, 3), Vector3.ZERO)
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()
	return [stage, camera]


func _hold(fly: Griffinfly, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await process_frame


# --- Studio ---

func _studio() -> void:
	var made := _stage()
	var stage: Node3D = made[0]
	var camera: Camera3D = made[1]
	var fly := Griffinfly.new()
	fly.sound = false
	stage.add_child(fly)
	fly.position = Vector3(0.0, 1.0, 0.0)
	print("griffinfly: %d triangles, low %d" % [GriffinflyLook.triangles(false), GriffinflyLook.triangles(true)])
	# Hovering: from the side, above, in front, three quarters, the head close.
	fly.effort = 1.0
	await _hold(fly, 0.5)
	var views := {
		"side": [Vector3(2.4, 1.1, 0.0), Vector3(0.0, 1.0, 0.0), 30.0],
		"above": [Vector3(0.0, 3.6, 0.2), Vector3(0.0, 1.0, 0.0), 30.0],
		"front": [Vector3(0.3, 1.3, 2.6), Vector3(0.0, 1.0, 0.0), 30.0],
		"three_quarter": [Vector3(1.8, 1.7, 1.8), Vector3(0.0, 0.95, 0.0), 30.0],
		"head": [Vector3(0.45, 1.12, 0.75), Vector3(0.0, 0.98, 0.24), 22.0],
	}
	for view: String in views:
		camera.fov = views[view][2]
		camera.look_at_from_position(views[view][0], views[view][1])
		await _shot("%s/studio_hover_%s.png" % [folder, view])
	# Gliding on still wings.
	fly.effort = 0.0
	await _hold(fly, 0.6)
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(1.8, 1.7, 1.8), Vector3(0.0, 0.95, 0.0))
	await _shot(folder + "/studio_glide.png")
	camera.look_at_from_position(Vector3(0.0, 3.6, 0.2), Vector3(0.0, 1.0, 0.0))
	await _shot(folder + "/studio_glide_above.png")
	# The strike: basket thrown forward, jaws open.
	fly.effort = 1.0
	fly.basket = 1.0
	fly.jaws = 1.0
	await _hold(fly, 0.5)
	camera.fov = 26.0
	camera.look_at_from_position(Vector3(1.6, 0.9, 1.4), Vector3(0.0, 0.95, 0.15))
	await _shot(folder + "/studio_basket.png")
	camera.look_at_from_position(Vector3(2.3, 1.0, 0.1), Vector3(0.0, 0.95, 0.1))
	await _shot(folder + "/studio_basket_side.png")
	fly.basket = 0.0
	fly.jaws = 0.0
	# Resting on a wall, head up.
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 3.0, 0.3)
	wall.mesh = box
	wall.position = Vector3(0.0, 1.0, -0.2)
	stage.add_child(wall)
	fly.perched = true
	fly.surface = Vector3.BACK
	fly.position = Vector3(0.0, 1.0, -0.2 + 0.15 + 0.04)
	await _hold(fly, 1.0)
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(1.4, 1.3, 2.4), Vector3(0.0, 1.0, -0.1))
	await _shot(folder + "/studio_perched_wall.png")
	camera.look_at_from_position(Vector3(2.4, 1.0, 0.4), Vector3(0.0, 1.0, -0.1))
	await _shot(folder + "/studio_perched_wall_side.png")
	stage.queue_free()
	await process_frame


# --- One wingbeat ---

func _strip() -> void:
	var made := _stage()
	var stage: Node3D = made[0]
	var camera: Camera3D = made[1]
	var fly := Griffinfly.new()
	fly.sound = false
	# (slowed right down: one beat over the frames)
	fly.flap_rate = 1.0
	stage.add_child(fly)
	fly.position = Vector3(0.0, 1.0, 0.0)
	fly.effort = 1.0
	await _hold(fly, 0.4)
	for view: String in ["side", "front"]:
		for k in 8:
			fly.set(&"_phase", k / 8.0 - 1.0 / 60.0)
			if view == "side":
				camera.look_at_from_position(Vector3(2.4, 1.1, 0.0), Vector3(0.0, 1.0, 0.0))
			else:
				camera.look_at_from_position(Vector3(0.0, 1.15, 2.6), Vector3(0.0, 1.0, 0.0))
			await process_frame
			await _shot("%s/strip_%s_%d.png" % [folder, view, k])
	stage.queue_free()
	await process_frame


# --- In a round ---

func _maze() -> void:
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
	var player: Node3D = world.player
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 55.0
	camera.far = 2000.0
	world.dev = load("res://scripts/dev_tools.gd").new(world)
	world.dev.god = true
	var nav := MazeNav.new(maze)

	# Hunting over a hall: one, in the open, seen from the boy's height.
	var hall := _a_hall(maze, nav)
	var way := _open_way(maze, hall)
	var fly := MazeGriffinfly.new()
	fly.name = "ShotGriffinfly"
	world.enemies.add(fly, maze.cell_at(hall), 0.0, 7)
	world.put_player(hall + way * 30.0 + Vector3.UP * 0.3, 0.0)
	player.visible = false
	await _settle(4.0)
	camera.look_at_from_position(hall + way * 9.0 + Vector3.UP * 1.6, fly.global_position)
	await _shot(folder + "/maze_1_hall.png")
	camera.fov = 22.0
	camera.look_at_from_position(hall + way * 9.0 + Vector3.UP * 1.6, fly.global_position)
	await _shot(folder + "/maze_1b_hall_close.png")
	camera.fov = 55.0

	# Coming at the boy: he stands in the hall, it winds up in front of him, then strikes.
	player.visible = true
	world.dev.god = false
	world.put_player(hall + way * 4.0 + Vector3.UP * 0.3, atan2(-way.x, -way.z))
	var wound := false
	for i in 600:
		await physics_frame
		if fly.mode == MazeGriffinfly.Mode.WIND and fly.mode_time() > 0.5:
			wound = true
			break
	var side := way.cross(Vector3.UP)
	if wound:
		# (over his shoulder, at it hanging there, legs out)
		Engine.time_scale = 0.05
		var to_fly := (fly.global_position - player.global_position)
		to_fly.y = 0.0
		to_fly = to_fly.normalized()
		var across := to_fly.cross(Vector3.UP)
		camera.look_at_from_position(player.global_position - to_fly * 2.4 + across * 0.9 + Vector3.UP * 1.9, fly.global_position)
		await _shot(folder + "/maze_2_wind_up.png")
		camera.fov = 24.0
		camera.look_at_from_position(player.global_position - to_fly * 2.4 + across * 0.9 + Vector3.UP * 1.9, fly.global_position)
		await _shot(folder + "/maze_2b_wind_up_close.png")
		camera.fov = 55.0
		Engine.time_scale = 1.0
		for i in 240:
			await physics_frame
			if fly.mode == MazeGriffinfly.Mode.STRIKE and fly.global_position.distance_to(player.global_position + Vector3.UP) < 3.0:
				break
		Engine.time_scale = 0.05
		var middle := fly.global_position.lerp(player.global_position + Vector3.UP * 1.1, 0.5)
		camera.look_at_from_position(middle + across * 4.0 + Vector3.UP * 0.3, middle)
		await _shot(folder + "/maze_3_strike.png")
		Engine.time_scale = 1.0
		for i in 40:
			await physics_frame
		await _shot(folder + "/maze_3b_knocked.png")
	world.dev.god = true
	world.enemies.enemies.erase(fly)
	fly.queue_free()

	# Resting on a wall, head up, wings out flat.
	var rest := MazeGriffinfly.new()
	rest.name = "ShotRestingGriffinfly"
	world.enemies.add(rest, maze.cell_at(hall), 0.0, 8)
	player.visible = false
	world.put_player(hall + way * 40.0 + Vector3.UP * 0.3, 0.0)
	await _settle(1.0)
	if rest._find_perch():
		rest.global_position = rest.perch_at
		rest._hover = 60.0
		rest._enter(MazeGriffinfly.Mode.PERCH)
		await _settle(2.0)
		var out := rest.perch_out
		camera.fov = 40.0
		camera.look_at_from_position(rest.perch_at + out * 3.2 + out.cross(Vector3.UP) * 1.2 + Vector3.DOWN * 0.6, rest.perch_at)
		await _shot(folder + "/maze_5_resting.png")
		camera.fov = 55.0
	world.enemies.enemies.erase(rest)
	rest.queue_free()

	# Over the marsh.
	var marsh: Marsh = null
	for found: Node in world.find_children("Marsh", "Node3D", true, false):
		marsh = found as Marsh
	if marsh:
		var middle := MazeGriffinfly.marsh_middle(maze)
		var over := MazeGriffinfly.new()
		over.name = "ShotMarshGriffinfly"
		over.keep_out_of_clearing = false
		over.home_radius = 30.0
		world.enemies.add(over, maze.cell_at(middle), 0.0, 9, middle - maze.world(maze.cell_at(middle)))
		world.put_player(middle + Vector3(0.0, 0.0, 40.0), 0.0)
		player.visible = false
		await _settle(4.0)
		camera.look_at_from_position(over.global_position + Vector3(6.0, 0.5, 6.0), over.global_position)
		await _shot(folder + "/maze_4_marsh.png")
		world.enemies.enemies.erase(over)
		over.queue_free()
	quit()


func _settle(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func _a_hall(maze: Maze, nav: MazeNav) -> Vector3:
	for cell: Vector2i in nav.lairs(3):
		if maze.ring_of(cell) == 1 and not nav.dead_end(cell):
			var at := nav.point(cell)
			if _open_way(maze, at).length() > 0.5:
				return Vector3(at.x, maze.ground_height(at), at.z)
	return Vector3.ZERO


# The way along the hall from `at` with the longest run of open cells.
func _open_way(maze: Maze, at: Vector3) -> Vector3:
	var cell := maze.cell_at(at)
	var best := Vector3.ZERO
	var longest := 0
	for step: Vector2i in Maze.STEPS:
		var run := 0
		var c := cell
		while run < 6 and not maze.blocked(c, step):
			c += step
			run += 1
		if run > longest:
			longest = run
			best = Vector3(step.x, 0.0, step.y)
	return best
