extends SceneTree
## Pictures of the tripod (creatures/tripod, scripts/enemies/maze_tripod.gd):
## on open ground under the game's light (the whole machine from about, the
## hood and its eye, a knee, a foot, a strip of frames across its gait from
## the side, its beam, the heat ray burning and the scorch it leaves, the
## grasper reaching), and in a round of the real maze (from the boy's height
## in a hall looking up as it strides over, its searchlight sweeping a hall
## in the mist, the heat ray burning down a hall at him, the tentacle reaching
## down into a hall). Says how many draws a frame takes. Needs a real window
## (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/tripod_shots.gd -- <folder> [studio|maze|all]

var folder := "tripod_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D
## Called every physics frame while pictures are taken (what is moving the tripod along).
var mover := Callable()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		if mover.is_valid():
			mover.call(1.0 / 60.0)


func look(target: Vector3, from: Vector3, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = from
	camera.look_at(target, Vector3.UP)


## Puts the game's sky, mist and sun up under `parent`, the mist `thick` times as thick.
func light(parent: Node, thick := 1.0) -> void:
	MazeLight.put(parent)
	for node in parent.get_children():
		if node is WorldEnvironment:
			var environment := (node as WorldEnvironment).environment
			environment.fog_density *= thick
			environment.fog_height_density *= thick


# --- On open ground ---

func _studio() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	light(stage_root, 0.35)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	floor.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.36, 0.35, 0.32)
	floor.material_override = dirt
	ground.add_child(floor)
	stage_root.add_child(ground)
	# A wall to throw the light on and burn, and to stand the scale by.
	var wall := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 34.0, 60.0)
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = box
	wall.add_child(wall_shape)
	var wall_mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	wall_mesh.mesh = cube
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.48)
	wall_mesh.material_override = stone
	wall.add_child(wall_mesh)
	wall.position = Vector3(-34.0, 17.0, 10.0)
	stage_root.add_child(wall)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 2000.0

	var tripod := Tripod.new()
	stage_root.add_child(tripod)
	tripod.beam_target = Vector3(0.0, 0.0, 40.0)
	await frames(90)
	var middle := Vector3(0.0, 34.0, 0.0)
	look(middle, Vector3(0.0, 30.0, 130.0))
	await shot("s01_front")
	look(middle, Vector3(130.0, 26.0, 0.0))
	await shot("s02_side")
	look(middle, Vector3(95.0, 40.0, 95.0))
	await shot("s03_quarter")
	look(middle, Vector3(-80.0, 70.0, -90.0))
	await shot("s04_back_high")
	var hood := tripod.body_point() + Vector3(0.0, 4.0, 0.0)
	look(hood, hood + Vector3(22.0, 6.0, 30.0))
	await shot("s05_hood")
	look(hood + Vector3(0.0, -3.0, 6.0), hood + Vector3(4.0, -12.0, 34.0))
	await shot("s06_eye")
	look(hood, hood + Vector3(10.0, -30.0, 12.0), 50.0)
	await shot("s07_under")
	var knee: Vector3 = tripod.rig.skeleton.global_transform * tripod.rig.bone_pose("leg_0_4").origin
	look(knee, knee + Vector3(14.0, 4.0, 12.0))
	await shot("s08_knee")
	var foot: Vector3 = tripod.feet[0]
	look(foot + Vector3.UP * 3.0, foot + Vector3(9.0, 3.0, 9.0))
	await shot("s09_foot")
	# The boy beside a foot, for scale
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = foot + Vector3(4.0, 0.05, 3.0)
	await frames(20)
	look(foot + Vector3.UP * 20.0, boy.global_position + Vector3(-2.0, 1.2, 9.0), 70.0)
	await shot("s10_beside_the_boy")

	# A strip across its gait, from the side, walking along +Z
	tripod.beam_target = Vector3.INF
	var strip := Image.create(1280 * 3, 720 * 2, false, Image.FORMAT_RGBA8)
	mover = func(step: float) -> void:
		tripod.global_position += Vector3(0.0, 0.0, 2.2) * step
	await frames(200)
	for k in 6:
		var at := tripod.global_position
		look(at + Vector3(0.0, 30.0, 0.0), at + Vector3(150.0, 30.0, 0.0))
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(image, Rect2i(0, 0, 1280, 720), Vector2i((k % 3) * 1280, (k / 3) * 720))
		await frames(70)
	strip.resize(1920, 720)
	strip.save_png("%s/s11_gait_strip.png" % folder)
	print("saved %s/s11_gait_strip.png" % folder)
	mover = Callable()
	await frames(30)

	# The searchlight on the wall and the ground
	var at := tripod.global_position
	tripod.beam_target = at + Vector3(-28.0, 10.0, 18.0)
	await frames(120)
	look(at + Vector3(-20.0, 20.0, 15.0), at + Vector3(30.0, 8.0, 90.0), 55.0)
	await shot("s12_beam")
	# The heat ray: charging, then burning a line across the ground
	tripod.beam_target = at + Vector3(10.0, 0.0, 40.0)
	tripod.arm_target = at + Vector3(-10.0, 0.0, 30.0)
	for k in 120:
		tripod.charge = k / 120.0
		await frames(1)
	look(tripod.emitter_tip(), tripod.emitter_tip() + Vector3(-14.0, -4.0, 20.0), 50.0)
	await shot("s13_charging")
	tripod.firing = true
	for k in 150:
		tripod.arm_target = at + Vector3(-10.0 + k * 0.15, 0.0, 30.0)
		await frames(1)
	look(at + Vector3(0.0, 15.0, 25.0), at + Vector3(20.0, 12.0, 80.0), 60.0)
	await shot("s14_burning")
	tripod.firing = false
	tripod.charge = 0.0
	tripod.arm_target = Vector3.INF
	await frames(120)
	look(at + Vector3(0.0, 0.0, 30.0), at + Vector3(6.0, 9.0, 52.0), 60.0)
	await shot("s15_scorch")
	# The grasper reaching down
	tripod.reach_target = at + Vector3(4.0, 1.0, 14.0)
	await frames(360)
	look(at + Vector3(0.0, 20.0, 10.0), at + Vector3(40.0, 10.0, 60.0), 60.0)
	await shot("s16_reach")
	tripod.reach_target = Vector3.INF
	stage_root.queue_free()
	await frames(5)


# --- In the maze ---

## A place on open floor in a long hall `near`..`far` metres (flat) from under
## the tripod, that its eye and its emitter can see.
func open_floor(tripod: MazeTripod, maze: Maze, near: float, far: float) -> Vector3:
	var body := tripod.look.body_point()
	var space := tripod.get_world_3d().direct_space_state
	for k in 600:
		var a := TAU * k / 37.0
		var d := lerpf(near, far, fmod(k * 0.618, 1.0))
		var at := Vector3(body.x, 0.0, body.z) + Vector3(cos(a), 0.0, sin(a)) * d
		var cell := maze.cell_at(at)
		if not maze.inside(cell) or maze.in_clearing(cell):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 150.0, at.z), Vector3(at.x, -10.0, at.z), 1))
		if hit.is_empty() or (hit["position"] as Vector3).y > 0.5:
			continue
		var spot: Vector3 = hit["position"]
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(tripod.look.eye_point(), spot + Vector3.UP, 1)).is_empty():
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(tripod.look.emitter_tip(), spot + Vector3.UP * 0.5, 1)).is_empty():
			continue
		if float(tripod._hall_at(spot)[1]) < 40.0:
			continue
		return spot
	return body * Vector3(1, 0, 1)


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	# Everything else that hunts is put away, for clear pictures; and being caught does nothing.
	var tripod: MazeTripod = null
	for enemy: MazeEnemy in world.enemies.enemies:
		if enemy is MazeTripod:
			tripod = enemy
		else:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.visible = false
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	for connection: Dictionary in world.enemies.caught.get_connections():
		world.enemies.caught.disconnect(connection["callable"])
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 900.0
	# A long straight hall in the first ring
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		if maze.ring_of(cell) != 1:
			continue
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 8 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run:
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var start := maze.world(best)
	await frames(2)
	var space := world.get_world_3d().direct_space_state
	# (the middle of the hall across from a point: the halls are two cells wide)
	var centre := func(at: Vector3) -> Vector3:
		var waist := Vector3(at.x, 1.0, at.z)
		var left := space.intersect_ray(PhysicsRayQueryParameters3D.create(waist, waist + side * 30.0, 1))
		var right := space.intersect_ray(PhysicsRayQueryParameters3D.create(waist, waist - side * 30.0, 1))
		if left.is_empty() or right.is_empty():
			return at
		return at + side * ((waist.distance_to(left["position"]) - waist.distance_to(right["position"])) * 0.5)
	start = centre.call(start)
	var up := Vector3.UP
	boy.global_position = start + way * 6.0 + up * 0.05
	boy.rotation.y = atan2(-way.x, -way.z)
	# The tripod: first walked over him by hand (its own thinking stopped).
	tripod.set_physics_process(false)
	var machine := tripod.look
	tripod.global_position = boy.global_position + way * 70.0
	tripod.rotation.y = atan2(-way.x, -way.z)
	machine.settle()
	mover = func(step: float) -> void:
		tripod.global_position -= way * 2.2 * step
		machine.beam_target = tripod.global_position - way * 30.0
	await frames(60 * 12)
	var eye := boy.global_position + up * 1.5
	look(machine.body_point() + up * 2.0, eye, 75.0)
	await shot("m01_from_the_hall_it_comes")
	await frames(60 * 12)
	look(machine.body_point(), eye, 80.0)
	await shot("m02_from_the_hall_overhead")
	await frames(60 * 6)
	look(machine.body_point() + up * 4.0, eye + way * 2.0, 75.0)
	await shot("m03_from_the_hall_striding_on")
	# Over a hall, its light sweeping down it, seen in the mist from along the hall
	mover = Callable()
	tripod.global_position = start + way * 14.0
	tripod.rotation.y = atan2(way.x, way.z)
	machine.settle()
	boy.global_position = start + way * 78.0 + up * 0.05
	var sweep := 0.0
	mover = func(step: float) -> void:
		sweep += step
		machine.beam_target = start + way * (34.0 + 26.0 * (0.5 + 0.5 * sin(sweep * 0.4))) + side * 2.0 * sin(sweep * 0.9)
	await frames(240)
	look(machine.body_point() - up * 18.0, boy.global_position + up * 1.6 - side * 2.0, 70.0)
	await shot("m04_searchlight_down_the_hall")
	await frames(90)
	look(machine.body_point() - up * 22.0, boy.global_position + up * 1.6 + side * 2.0, 70.0)
	await shot("m05_searchlight_sweeping_closer")
	# Its own thinking: it finds him, horns, charges and burns down the hall at him
	mover = Callable()
	tripod.global_position = centre.call(start + way * 12.0)
	tripod.rotation.y = atan2(way.x, way.z)
	machine.settle()
	await frames(30)
	# (somewhere in the open a way off down a long hall, where its ray can reach him)
	var spot := open_floor(tripod, maze, 34.0, 60.0)
	boy.global_position = spot + up * 0.05
	var hall: Array = tripod._hall_at(spot)
	way = hall[0]
	if way.dot(machine.body_point() - spot) > 0.0:
		way = -way
	side = Vector3(-way.z, 0.0, way.x)
	tripod.set_physics_process(true)
	await frames(30)
	tripod._spot(boy)
	await frames(int(60 * (tripod.horn_time + 0.3)))
	look(machine.body_point(), boy.global_position + up * 1.6 + way * 4.0 + side * 2.0, 70.0)
	await shot("m06_horn_light_on_him")
	await frames(int(60 * (tripod.charge_time * 0.8)))
	look(machine.emitter_tip(), boy.global_position + up * 1.6 + way * 3.0 - side * 2.0, 70.0)
	await shot("m07_charging_from_the_boy")
	for i in 600:
		await frames(1)
		if tripod.mode == MazeTripod.Mode.BURN and tripod.burn_at.distance_to(tripod.burn_from) > 6.0:
			break
	look(tripod.burn_at + up * 4.0, boy.global_position + up * 1.7 + way * 10.0 + side * 4.0, 75.0)
	await shot("m08_ray_burning_down_the_hall")
	look(tripod.burn_at, tripod.burn_at + side * 22.0 + up * 14.0 - way * 6.0, 60.0)
	await shot("m09_ray_from_the_side")
	await frames(60 * 4)
	look(tripod.burn_from.lerp(tripod.burn_to, 0.5), boy.global_position + up * 2.5 + way * 8.0, 70.0)
	await shot("m10_scorch_and_steam")
	# The grasper reaching down into the hall for him
	await frames(60 * 6)
	tripod._enter(MazeTripod.Mode.PATROL)
	tripod._spared.clear()
	boy.global_position = machine.body_point() * Vector3(1, 0, 1) + way * 6.0 + up * 0.05
	tripod._spot(boy)
	for i in 900:
		await frames(1)
		if tripod.mode == MazeTripod.Mode.REACH and machine.grasper_tip().y < 14.0:
			break
	var toward := (machine.grasper_tip() - boy.global_position) * Vector3(1, 0, 1)
	look(machine.grasper_tip() + up * 6.0, boy.global_position + up * 1.6 - toward.normalized() * 4.0, 80.0)
	await shot("m11_grasper_reaching_down")
	# Far off over the maze, in the mist
	tripod._enter(MazeTripod.Mode.PATROL)
	await frames(60 * 4)
	var high := machine.body_point() + way * 170.0 + side * 60.0
	high.y = 62.0
	look(machine.body_point() - up * 20.0, high, 50.0)
	await shot("m12_over_the_maze_in_the_mist")
	print("draws in a hall with it near: see the numbers above")
