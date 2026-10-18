extends SceneTree
## Pictures of the flying insects (creatures/insects, scripts/wildlife/insects.gd),
## landscape. `studio`: each insect big against grey, at rest and mid-beat, from
## above and the side. `maze`: in a round, as the game puts them: moths round
## the angel and round a fire, flies round an abomination from the boy's
## height, dragonflies over the marsh, and one perched on a bulrush close up.
## Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/insects_shots.gd -- <folder> [studio|maze|all]

var folder := "user://insects_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0] if args.size() > 0 else folder
	DirAccess.make_dir_recursive_absolute(folder)
	var which: String = args[1] if args.size() > 1 else "all"
	_run(which)


func _run(which: String) -> void:
	if which == "studio" or which == "all":
		await _studio()
	if which == "maze" or which == "all":
		await _maze()
	quit()


func _shot(path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


# --- Studio ---

func _studio() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.63, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.look_at_from_position(Vector3(2, 5, 3), Vector3.ZERO)
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()
	# Each kind: at rest and mid-beat (two poses), side by side, one unit across.
	var poses := [[0.0, 0.0], [0.25, 1.0], [0.75, 1.0]]
	for kind in 3:
		for variety in (3 if kind == 0 else 1):
			var shown := MultiMeshInstance3D.new()
			shown.material_override = InsectLook.material(kind)
			var many := MultiMesh.new()
			many.transform_format = MultiMesh.TRANSFORM_3D
			many.use_custom_data = true
			many.mesh = InsectLook.mesh(kind)
			many.instance_count = poses.size()
			for p in poses.size():
				many.set_instance_transform(p, Transform3D(Basis.IDENTITY, Vector3((p - 1) * 1.15, 0.0, 0.0)))
				many.set_instance_custom_data(p, Color(poses[p][0], poses[p][1], variety, 0.5))
			shown.multimesh = many
			stage.add_child(shown)
			print("%s %d: %d triangles" % [InsectLook.NAMES[kind], variety, InsectLook.triangles(kind)])
			camera.look_at_from_position(Vector3(0.0, 3.2, 1.6), Vector3(0.0, 0.0, 0.0))
			await _shot("%s/studio_%s%d_above.png" % [folder, InsectLook.NAMES[kind], variety])
			camera.look_at_from_position(Vector3(1.6, 0.5, 2.6), Vector3(0.0, 0.0, 0.0))
			await _shot("%s/studio_%s%d_side.png" % [folder, InsectLook.NAMES[kind], variety])
			shown.queue_free()
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
	var insects: Insects = world.insects
	var player: Node3D = world.player
	world.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 55.0
	camera.far = 2000.0
	# (he cannot be caught, and stands hidden behind the camera at each place: what is
	# there is drawn and goes about as it would with someone near)
	world.dev = load("res://scripts/dev_tools.gd").new(world)
	world.dev.god = true
	player.visible = false
	var hunters: Array = world.enemies.enemies

	# Moths round the angel, from below, as it drifts.
	for enemy: Node in hunters:
		if enemy is MazeAngel:
			var angel := enemy as MazeAngel
			var way := _open_way(maze, angel.global_position)
			world.put_player(angel.global_position + way * 12.0 + Vector3.UP * 0.3, 0.0)
			await _settle(5.0)
			var from := angel.global_position + Vector3(0.0, 1.6, 0.0) + _open_way(maze, angel.global_position) * 8.0
			camera.look_at_from_position(from, angel.heart() - Vector3.UP * 0.5)
			await _shot(folder + "/1_moths_angel.png")
			camera.fov = 28.0
			camera.look_at_from_position(from, angel.heart())
			await _shot(folder + "/1b_moths_angel_close.png")
			camera.fov = 55.0
			break

	# Moths round a lantern in a hall (as round a fire or a torch), some resting on the wall.
	var hall := _a_hall(maze)
	var lamp: Node3D = insects.put(InsectLook.Kind.MOTH, hall)
	var way := _open_way(maze, hall)
	world.put_player(hall + way * 6.0 + Vector3.UP * 0.3, 0.0)
	camera.look_at_from_position(lamp.global_position + way * 3.2 + Vector3(0.0, -0.3, 0.0), lamp.global_position)
	await _settle(5.0)
	await _shot(folder + "/2_moths_lantern.png")
	camera.fov = 25.0
	await _shot(folder + "/2b_moths_lantern_close.png")
	camera.fov = 55.0

	# Flies round a flesh creature, from the boy's height.
	var shot_meat := {}
	for enemy: Node in hunters:
		var which := "meat_beast" if enemy is Abomination else ("flesh_mound" if enemy is MazeFleshMound else "")
		if which == "" or shot_meat.has(which):
			continue
		shot_meat[which] = true
		var meat := enemy as Node3D
		var toward := _open_way(maze, meat.global_position)
		var reach := float(meat.get_meta(&"carrion_radius", 1.5)) * 1.6
		world.put_player(meat.global_position + toward * (reach + 5.0) + Vector3.UP * 0.3, 0.0)
		await _settle(3.0)
		toward = _open_way(maze, meat.global_position)
		camera.look_at_from_position(meat.global_position + toward * (reach + 2.4) + Vector3.UP * 1.5, meat.global_position + Vector3.UP * 0.9)
		await _shot(folder + "/3_flies_%s.png" % which)

	# Flies on a carcass in a dead end, low and close.
	if not insects.carcasses.is_empty():
		var dead: Node3D = insects.carcasses[0]
		var toward := _open_way(maze, dead.global_position)
		world.put_player(dead.global_position + toward * 6.0 + Vector3.UP * 0.3, 0.0)
		camera.look_at_from_position(dead.global_position + toward * 1.9 + Vector3.UP * 1.0, dead.global_position + Vector3.UP * 0.35)
		await _settle(4.0)
		await _shot(folder + "/4_flies_carcass.png")
		var buzzing: InsectSwarm = insects.flies.get(dead.get_instance_id())
		if buzzing:
			print("flies on the carcass: %d, %d resting, running %s" % [buzzing.count, buzzing.resting(), buzzing.running()])
			camera.fov = 30.0
			await _shot(folder + "/4b_flies_carcass_close.png")
			camera.fov = 55.0

	# Big moths on a wall.
	for swarm in insects.wall_moths:
		world.put_player(swarm.centre + Vector3(0.0, -1.0, 0.0), 0.0)
		camera.global_position = swarm.centre + Vector3.UP * 0.5
		await _settle(1.0)
		if not swarm.running() or swarm.perches.is_empty() or swarm.resting() == 0:
			continue
		var i := 0
		while swarm.state_of(i) != InsectSwarm.State.PERCH:
			i += 1
		world.put_player(swarm.centre + swarm.perches[0].basis.y * 8.0, 0.0)
		var spot: Vector3 = swarm.insect_position(i)
		var out: Vector3 = swarm.perches[0].basis.y
		camera.fov = 32.0
		camera.look_at_from_position(spot + out * 2.2 + Vector3.UP * 0.3, spot)
		await _settle(0.3)
		await _shot(folder + "/5_wall_moths.png")
		camera.fov = 55.0
		break

	# Dragonflies over the marsh: the patch, one in flight near, one perched on a bulrush close up.
	if not insects.dragonflies.is_empty():
		var patch: InsectSwarm = insects.dragonflies[0]
		var middle := patch.middle()
		world.put_player(middle + Vector3(patch.radius + 8.0, 0.5, 0.0), 0.0)
		camera.look_at_from_position(middle + Vector3(6.0, 1.5, 4.0), middle + Vector3(0.0, 0.9, 0.0))
		await _settle(4.0)
		await _shot(folder + "/6_dragonflies_marsh.png")
		for i in patch.count:
			if patch.state_of(i) == InsectSwarm.State.FLY:
				var at := patch.insect_position(i)
				patch.frozen = true
				camera.fov = 40.0
				camera.look_at_from_position(at + Vector3(0.7, 0.45, 0.4), at)
				await _shot(folder + "/6b_dragonfly_flying.png")
				patch.frozen = false
				break
		# (wait for one to perch)
		for i in 2400:
			await process_frame
			if patch.resting() > 0:
				break
		for i in patch.count:
			if patch.state_of(i) == InsectSwarm.State.PERCH:
				await _settle(0.5)
				patch.frozen = true
				var at := patch.insect_position(i)
				camera.fov = 35.0
				camera.look_at_from_position(at + Vector3(0.36, 0.08, 0.22), at)
				await _shot(folder + "/7_dragonfly_perched.png")
				camera.look_at_from_position(at + Vector3(-0.2, 0.32, 0.18), at)
				await _shot(folder + "/7b_dragonfly_perched_above.png")
				patch.frozen = false
				break

	# Moths out over the clearing's grass at dusk.
	if not insects.dusk_moths.is_empty():
		world.day.set_hour(DayCycle.SUNSET - 0.3)
		var swarm: InsectSwarm = insects.dusk_moths[0]
		world.put_player(swarm.centre + Vector3(8.0, 0.0, 6.0), 0.0)
		camera.fov = 55.0
		camera.look_at_from_position(swarm.centre + Vector3(4.0, 0.3, 2.5), swarm.centre)
		await _settle(3.5)
		await _shot(folder + "/8_dusk_moths.png")


## Waits `seconds` of play for things to move.
func _settle(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await process_frame


## A way out of the cell at `point` that is open (to stand back along).
func _open_way(maze: Maze, point: Vector3) -> Vector3:
	var cell := maze.cell_at(point)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			return Vector3(step.x, 0.0, step.y)
	return Vector3.BACK


## The middle of a hall in the first ring (not a dead end).
func _a_hall(maze: Maze) -> Vector3:
	var nav := MazeNav.new(maze)
	for cell in nav.lairs(4):
		if not nav.dead_end(cell) and maze.ring_of(cell) == 1:
			return nav.point(cell)
	return maze.world(maze.exit)
