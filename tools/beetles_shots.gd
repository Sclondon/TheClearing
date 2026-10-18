extends SceneTree
## Pictures of the beetles (creatures/beetle_swarm/, scripts/enemies/beetles.gd).
## First in a plain grey studio, each framed to fill most of the picture: a
## ground beetle close from in front and above, side on, and from below; a dor
## beetle; the two together from above; a stride in four steps; a crowd of them
## on a slab. Then in a real round's passage (World, the game's light and mist,
## everything else that hunts taken out): the cracks at the foot of the wall,
## the beetles pouring out of them, flooding the hall after the boy, up the
## foot of the wall, and up the boy. Says how many draws a frame takes, and
## what a frame of the swarm costs. Needs a real window (the engine draws
## nothing headless). Landscape, as the user looks at them:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/beetles_shots.gd -- <folder> [studio|maze]

var folder := "beetle_shots"
var only := ""
## Which of the halls found to put them in (the third argument), to try another.
var hall_pick := 0
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	if args.size() > 2 and args[2].is_valid_int():
		hall_pick = int(args[2])
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


# --- The studio ---

var _posed: MultiMeshInstance3D


## Beetles posed by hand: each [kind, transform, stride, hue].
func pose(beetles: Array) -> void:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = BeetleLook.mesh()
	many.instance_count = beetles.size()
	for i in beetles.size():
		var one: Array = beetles[i]
		many.set_instance_transform(i, one[1])
		many.set_instance_custom_data(i, Color(one[2], one[0], one[3], 0.0))
	_posed.multimesh = many


func _studio() -> void:
	var stage := Node3D.new()
	stage.name = "Studio"
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.5
	var surround := WorldEnvironment.new()
	surround.environment = env
	stage.add_child(surround)
	# (high and soft, as the maze's sun)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.9
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(1.2, 4, 2.0), Vector3.ZERO)
	var floor_slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_slab.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.46, 0.46, 0.44)
	concrete.roughness = 0.9
	floor_slab.material_override = concrete
	stage.add_child(floor_slab)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()
	_posed = MultiMeshInstance3D.new()
	stage.add_child(_posed)

	var long := 0.17
	var one := Basis.IDENTITY.scaled(Vector3.ONE * long)
	pose([[0, Transform3D(one, Vector3.ZERO), 0.0, 0.1]])
	_frame(Vector3(0, 0.02, 0.02), 0.16, 0.12, Vector3(0.55, 0.6, 1))
	await shot("01_ground_beetle")
	_frame(Vector3(0, 0.02, 0.02), 0.2, 0.06, Vector3(1, 0.12, 0.05))
	await shot("02_ground_beetle_side")
	_frame(Vector3(0, 0.02, 0.0), 0.14, 0.2, Vector3(0.0, 1, 0.02))
	await shot("03_ground_beetle_above")
	pose([[1, Transform3D(one, Vector3.ZERO), 0.0, 0.6]])
	_frame(Vector3(0, 0.02, 0.0), 0.14, 0.1, Vector3(-0.6, 0.55, 1))
	await shot("04_dor_beetle")
	# The two side by side, from above; then four steps of a stride, side on.
	pose([[0, Transform3D(one, Vector3(-0.07, 0, 0)), 0.0, 0.3], [1, Transform3D(one * 0.82, Vector3(0.08, 0, 0)), 0.0, 0.8]])
	_frame(Vector3(0, 0.0, 0.0), 0.3, 0.2, Vector3(0.0, 1, 0.5))
	await shot("05_both")
	var steps: Array = []
	for k in 4:
		steps.append([0, Transform3D(one, Vector3(0, 0, -0.3 + k * 0.2)), k * 0.25, 0.2])
	pose(steps)
	_frame(Vector3(0, 0.02, 0.0), 0.75, 0.15, Vector3(1, 0.25, 0.0))
	await shot("06_stride")
	# A crowd of them on the slab, every way, both kinds, a mix of sizes.
	var crowd: Array = []
	var chance := RandomNumberGenerator.new()
	chance.seed = 5
	for k in 70:
		var big := long * chance.randf_range(0.8, 1.2)
		var kind := 1 if chance.randf() < 0.3 else 0
		var at := Vector3(chance.randf_range(-0.7, 0.7), 0.0, chance.randf_range(-0.5, 0.5))
		crowd.append([kind, Transform3D(Basis(Vector3.UP, chance.randf() * TAU).scaled(Vector3.ONE * big * (0.82 if kind == 1 else 1.0)), at), chance.randf() * 4.0, chance.randf()])
	pose(crowd)
	_frame(Vector3(0, 0, 0), 1.3, 0.6, Vector3(0.2, 0.7, 1))
	await shot("07_crowd")
	_frame(Vector3(0.1, 0, 0.1), 0.45, 0.25, Vector3(0.4, 0.35, 1))
	await shot("08_crowd_close")
	stage.queue_free()
	await process_frame


## Puts the camera looking at `at` from the way `from` points (out from it),
## near enough that something `wide` by `high` fills about 70% of the frame.
func _frame(at: Vector3, wide: float, high: float, from: Vector3) -> void:
	var size := Vector2(root.get_visible_rect().size)
	var down := tan(deg_to_rad(camera.fov) * 0.5)
	var across := down * size.x / size.y
	var distance := maxf(wide / 0.7 * 0.5 / across, high / 0.7 * 0.5 / down)
	var up := Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.BACK
	camera.look_at_from_position(at + from.normalized() * distance, at, up)
	camera.near = 0.01


# --- In the maze ---

var world
var maze: Maze
var nav: MazeNav
var boy


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	# (only the beetles: nothing else is to catch him while the pictures are taken)
	for enemy: Node in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	await wait(0.5)
	var lairs := nav.lairs(3)
	# (a cell along the side of a long hall: walled on one side, open on the other and both ways along)
	var den: Vector2i = lairs[0]
	var halls: Array[Vector2i] = []
	for c: Vector2i in lairs:
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(c, s) and not maze.blocked(c, -s) and not maze.blocked(c + s, s) and not maze.blocked(c - s, -s) and maze.blocked(c, across) != maze.blocked(c, -across):
				halls.append(c)
				break
	if not halls.is_empty():
		den = halls[hall_pick % halls.size()]
	var beetles := Beetles.new()
	beetles.name = "Beetles"
	beetles.maze = maze
	beetles.seed_choices(99)
	# (they are not to wake by themselves, nor to catch him)
	beetles.sight_range = 0.0
	beetles.hear_range = 0.0
	beetles.position = maze.world(den) + Vector3.UP * 0.05
	world.add_child(beetles)
	await wait(0.3)
	var swarm: BeetleSwarm = beetles.swarm
	swarm.catch_time = 100000.0
	var crack: Vector3 = swarm.cracks()[0]
	var out: Vector3 = swarm.crack_out(0)
	var along := Vector3(-out.z, 0, out.x)
	print("cracks at %s (the cell %s, a %s)" % [swarm.cracks(), den, "dead end" if nav.dead_end(den) else "hall"])
	# Him a way out from the wall, facing it.
	var stand := crack + out * 7.0 + along * 1.5
	boy.global_position = stand + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(-out.x, -out.z)
	boy.facing_yaw = boy.rotation.y
	world.camera.snap()
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.near = 0.02
	eye.fov = 40.0
	eye.make_current()
	# The cracks, waiting.
	eye.look_at_from_position(crack + out * 2.2 + Vector3.UP * 0.9 + along * 0.8, crack + Vector3.UP * 0.3 - along * 0.3)
	await wait(0.4)
	await shot("20_maze_cracks")
	# Out they come.
	beetles.notice(boy)
	await wait(0.45)
	eye.look_at_from_position(crack + out * 1.6 + Vector3.UP * 0.5 + along * 1.2, crack + out * 0.4 + Vector3.UP * 0.1)
	await shot("21_maze_pouring")
	await wait(0.3)
	eye.fov = 50.0
	eye.look_at_from_position(crack + out * 3.0 + Vector3.UP * 1.4 - along * 2.5, crack + out * 0.8)
	await shot("21b_maze_pouring_wide")
	# Flooding the hall towards him: over his shoulder, and from low in front of them.
	await wait(0.6)
	eye.look_at_from_position(stand + out * 3.5 + Vector3.UP * 2.6 + along * 0.6, swarm.front + Vector3.UP * 0.1)
	await shot("22_maze_flood_over_shoulder")
	eye.look_at_from_position(stand + out * 1.2 + Vector3.UP * 1.45 - along * 0.9, swarm.front + Vector3.UP * 0.2)
	await shot("22c_maze_flood_eye_height")
	eye.look_at_from_position(swarm.front - out * -0.0 + (stand - swarm.front).normalized() * 2.5 + Vector3.UP * 0.35 + along * 0.5, swarm.front)
	await shot("22b_maze_flood_low")
	# On him.
	await wait(4.0, func() -> bool: return swarm.on_target > 40)
	await wait(0.6)
	var him: Vector3 = boy.global_position
	eye.fov = 40.0
	eye.look_at_from_position(him + (crack - him).normalized() * 2.6 + Vector3.UP * 1.2 + along * 0.8, him + Vector3.UP * 0.6)
	await shot("24_maze_up_the_boy")
	eye.look_at_from_position(him - (crack - him).normalized() * 3.2 + Vector3.UP * 1.0 - along * 1.2, him + Vector3.UP * 0.5)
	await shot("24b_maze_up_the_boy_behind")
	# What a frame of it costs, with all of them out and some on him.
	var t0 := Time.get_ticks_usec()
	for k in 30:
		swarm._physics_process(1.0 / 60.0)
	print("a frame of the swarm (%d out, %d on him): %.2f ms" % [swarm.out, swarm.on_target, (Time.get_ticks_usec() - t0) / 30000.0])
	# He backs against the wall: they lap up the foot of it round him.
	swarm.shake_off()
	var by_wall := crack + along * 6.0 + out * 0.45
	boy.global_position = by_wall + Vector3.UP * 0.05
	var most_on_wall := [0]
	await wait(6.0, func() -> bool:
		most_on_wall[0] = maxi(most_on_wall[0], swarm.counted(BeetleSwarm.WALL))
		return swarm.counted(BeetleSwarm.WALL) > 12)
	print("on the wall at most %d at once" % most_on_wall[0])
	var highest := 0.0
	for i in swarm.count:
		if swarm.beetle_state(i) == BeetleSwarm.WALL:
			highest = maxf(highest, swarm.beetle_position(i).y - maze.ground_height(swarm.beetle_position(i)))
	print("%d on the wall, the highest %.2f m up" % [swarm.counted(BeetleSwarm.WALL), highest])
	eye.look_at_from_position(by_wall + out * 3.4 + Vector3.UP * 1.1 + along * 1.6, by_wall + Vector3.UP * 0.5)
	await shot("23_maze_up_the_wall")
	eye.look_at_from_position(by_wall + out * 1.6 + Vector3.UP * 0.4 - along * 2.2, by_wall + Vector3.UP * 0.5 + along * 0.3)
	# (from low down the ferns at the wall foot are in the way: this one without them)
	var ferns: Node = world.find_child("Undergrowth", true, false)
	if ferns:
		ferns.visible = false
	await shot("23b_maze_up_the_wall_low_no_ferns")
	if ferns:
		ferns.visible = true
	# The game's camera, then him running away down the hall (as if sprinting).
	world.camera.make_current()
	await wait(0.4)
	await shot("25_maze_game_camera")
	var with := await _draws()
	swarm.visible = false
	var without := await _draws()
	swarm.visible = true
	print("draws, this view, with the swarm: %d, without it: %d" % [with, without])


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
