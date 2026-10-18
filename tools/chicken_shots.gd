extends SceneTree
## Pictures of the chickens (creatures/chicken/, scripts/enemies/chickens.gd).
## First on a patch of ground in a plain grey studio, each framed to fill most
## of the picture: a hen and the rooster from the side, the front and three
## quarters, from behind, their heads close, and every colour; then the moves
## (a walk's head-lock, pecking, scratching, preening, the crow, flapping, a
## flight, landing, puffed up angry). Then in a real round's passage (World,
## the game's light and mist): the flock foraging, from the boy's height; the
## panic as he runs at them; and the mob round him. Says how many draws a frame
## takes. Needs a real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/chicken_shots.gd -- <folder> [studio|moves|maze|clearing]

var folder := "chicken_shots"
var only := ""
var camera: Camera3D
var world
var maze
var nav
var boy
var frame_aspect := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
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
	if only == "" or only == "studio" or only == "moves":
		await _studio()
	if only == "" or only == "maze":
		await _maze()
	if only == "" or only == "clearing":
		await _clearing()
	quit()


# --- The studio ---

var stage: Node3D


func _set_studio() -> void:
	stage = Node3D.new()
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
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(2.0, 4, 3), Vector3.ZERO)
	var back := DirectionalLight3D.new()
	back.light_energy = 0.5
	stage.add_child(back)
	back.look_at_from_position(Vector3(-1, 2.5, -4), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.3, 0.27, 0.23)
	ground.material_override = mud
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()


func _studio() -> void:
	_set_studio()
	var flock := ChickenFlock.new()
	flock.count = 2
	flock.roosters = 1
	flock.frozen = true
	flock.molt = 0.0
	flock.colours = Vector4(1, 0, 0, 0)
	stage.add_child(flock)
	var far := Vector3(50, 0, 0)
	if only != "moves":
		# The hen alone, then the rooster alone.
		for who in 2:
			var name := "rooster" if who == 0 else "hen"
			var size := 1.2 if who == 0 else 1.0
			flock.pose_bird(who, Vector3.ZERO, 0.0)
			flock.pose_bird(1 - who, far, 0.0)
			var mid := Vector3(0, 0.3 * size, -0.02)
			_frame(mid, 0.7 * size, 0.62 * size, Vector3(1, 0.12, 0))
			await shot("0%d_%s_side" % [who * 4 + 1, name])
			_frame(mid, 0.6 * size, 0.62 * size, Vector3(0, 0.15, 1))
			await shot("0%d_%s_front" % [who * 4 + 2, name])
			_frame(mid, 0.7 * size, 0.62 * size, Vector3(0.9, 0.35, 0.8))
			await shot("0%d_%s_three_quarter" % [who * 4 + 3, name])
			_frame(mid, 0.7 * size, 0.62 * size, Vector3(-0.6, 0.45, -1))
			await shot("0%d_%s_back" % [who * 4 + 4, name])
			var head := ChickenBody.HEAD * size
			_frame(head + Vector3(0, 0.0, 0.0), 0.16 * size, 0.16 * size, Vector3(0.8, 0.15, 0.6))
			await shot("0%d_%s_head" % [who * 4 + 4, name] + "_b")
		flock.queue_free()
		# Every colour: a hen and a rooster of each.
		var colours := ChickenFlock.new()
		colours.count = 8
		colours.roosters = 0
		colours.frozen = true
		colours.molt = 0.5
		stage.add_child(colours)
		await process_frame
		for i in 8:
			colours._birds[i].variant = i % 4
			colours._birds[i].rooster = i >= 4
			colours._birds[i].scale = 1.2 if i >= 4 else 1.0
			colours._looks[i] = Vector4(i % 4, 1.0 if i >= 4 else 0.0, i * 0.13, 0.5)
		colours._material.set_shader_parameter(&"looks", colours._looks)
		for i in 8:
			colours.pose_bird(i, Vector3((i % 4) * 0.75 - 1.1, 0, (i / 4) * -0.9), 0.9)
		_frame(Vector3(0.0, 0.3, -0.45), 3.2, 1.3, Vector3(0.7, 0.4, 1))
		await shot("10_colours")
		colours.queue_free()
		if only == "studio":
			stage.queue_free()
			return
	else:
		flock.queue_free()
	await _moves()
	stage.queue_free()


# Poses of a hen (and the rooster for his), each framed to fill its cell, in a
# strip: `poses` is an Array of Callables(flock) that pose bird 0.
func _strip(name: String, rooster: bool, from: Vector3, wide: float, high: float, poses: Array, middle := Vector3(0, 0.3, 0)) -> void:
	var flock := ChickenFlock.new()
	flock.count = 2
	flock.roosters = 1 if rooster else 0
	flock.frozen = true
	flock.molt = 0.2
	flock.colours = Vector4(1, 0, 0, 0) if rooster else Vector4(0.5, 0.5, 0, 0)
	stage.add_child(flock)
	await process_frame
	flock.pose_bird(1, Vector3(60, 0, 0), 0.0)
	var size := Vector2i(root.get_visible_rect().size)
	var across := 4 if poses.size() > 4 else poses.size()
	var down := ceili(poses.size() / float(across))
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.62, 0.63, 0.64))
	var cell := Vector2i(size.x / across, size.y / down)
	for k in poses.size():
		(poses[k] as Callable).call(flock)
		frame_aspect = float(cell.x) / cell.y
		_frame(middle * (1.2 if rooster else 1.0), wide, high, from)
		frame_aspect = 0.0
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		# (the middle of the picture, the shape of a cell)
		var crop_w := mini(image.get_width(), int(image.get_height() * float(cell.x) / cell.y))
		image = image.get_region(Rect2i((image.get_width() - crop_w) / 2, 0, crop_w, image.get_height()))
		image.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i((k % across) * cell.x, (k / across) * cell.y))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])
	flock.queue_free()


func _moves() -> void:
	var side := Vector3(1, 0.15, 0)
	# Walking: eight steps of a stride; the head-lock holds the head still as the body passes under it.
	var walk: Array = []
	for k in 8:
		var phase := k / 8.0
		walk.append(func(f: ChickenFlock) -> void:
			var lock := 0.04 - 0.075 * fmod(phase * 2.0, 1.0)
			f.pose_bird(0, Vector3(0, 0, 0), 0.0, Vector4(phase, 0.1, 0, 0), Vector3(0, -0.02, lock), Vector3.ZERO, 0.0, 0.0, Vector3.ZERO, 0.08))
	await _strip("20_walk", false, side, 0.75, 0.62, walk)
	# Pecking: down, stab, up.
	var peck: Array = []
	for k in 4:
		var u := [0.0, 0.5, 1.0, 0.4][k] as float
		peck.append(func(f: ChickenFlock) -> void:
			f.pose_bird(0, Vector3.ZERO, 0.0, Vector4.ZERO, Vector3(0, -0.27, 0.15).lerp(Vector3(0, -0.36, 0.17), u), Vector3(0, lerpf(0.6, 1.25, u), 0.3 * (1.0 - u)), 0.0, 0.0, Vector3.ZERO, 0.7))
	await _strip("21_peck", false, side, 0.75, 0.62, peck)
	# Scratching: one foot reaching forward and raking back, then the other.
	var scratch: Array = []
	for k in 8:
		var phase := k / 8.0
		scratch.append(func(f: ChickenFlock) -> void:
			f.pose_bird(0, Vector3.ZERO, 0.0, Vector4(phase, 0.0, 1.0, 0.0), Vector3(0, -0.17, 0.08), Vector3(0, 0.85, 0.2), 0.0, 0.0, Vector3.ZERO, 0.32))
	await _strip("22_scratch", false, side, 0.75, 0.62, scratch)
	# Preening, the crow, puffed up, shaking.
	await _strip("23_preen_crow_angry", true, Vector3(0.9, 0.3, 0.8), 0.85, 0.8, [
		func(f: ChickenFlock) -> void: f.pose_bird(0, Vector3.ZERO, 0.0, Vector4.ZERO, Vector3(0.055, -0.1, -0.12), Vector3(2.3, 0.7, 0.4), 0.0, 0.35, Vector3(0.08, 0, 0), 0.05),
		func(f: ChickenFlock) -> void: f.pose_bird(0, Vector3.ZERO, 0.0, Vector4.ZERO, Vector3(0, 0.07, 0.05), Vector3(0, -0.75, 0), 1.0, 0.45, Vector3(0.12, 0, 0), -0.35),
		func(f: ChickenFlock) -> void: f.pose_bird(0, Vector3.ZERO, 0.0, Vector4.ZERO, Vector3(0, -0.12, 0.08), Vector3.ZERO, 0.6, 1.0, Vector3(0.2, 0, 0), 0.35),
		func(f: ChickenFlock) -> void: f.pose_bird(0, Vector3.ZERO, 0.0, Vector4.ZERO, Vector3(0, 0.02, 0.0), Vector3.ZERO, 0.0, 0.0, Vector3(1.0, 0.0, 1.0), -0.3),
	])
	# Flapping, front and side, through the beat; flying with the legs tucked.
	var flap: Array = []
	for k in 8:
		var phase := k / 8.0
		flap.append(func(f: ChickenFlock) -> void:
			f.pose_bird(0, Vector3(0, 0.0, 0), PI, Vector4(0, 0, 0, 0.9), Vector3(0, -0.03, 0.05), Vector3(0, -0.15, 0), 0.8, 0.3, Vector3(1.0, phase, 1.0), -0.1))
	await _strip("24_flap_front", false, Vector3(0, 0.1, -1), 1.0, 0.75, flap, Vector3(0, 0.35, 0))
	var fly: Array = []
	for k in 8:
		var phase := k / 8.0
		fly.append(func(f: ChickenFlock) -> void:
			f.pose_bird(0, Vector3(0, 0.0, 0), 0.0, Vector4(0, 0, 0, 0.9), Vector3(0, -0.03, 0.05), Vector3(0, -0.15, 0), 0.8, 0.3, Vector3(1.0, phase, 1.0), -0.1))
	await _strip("25_flap_side", false, Vector3(1, 0.5, 0.3), 1.0, 0.8, fly, Vector3(0, 0.35, 0))
	# Running flat out, wings half open, beating.
	var run: Array = []
	for k in 4:
		var phase := k / 4.0
		run.append(func(f: ChickenFlock) -> void:
			f.pose_bird(0, Vector3.ZERO, 0.0, Vector4(phase, 0.3, 0, 0), Vector3(0, -0.04, 0.06), Vector3(0, -0.1, 0), 0.8, 0.4, Vector3(0.6, phase * 1.7, 0.75), 0.12))
	await _strip("26_run", false, side, 0.85, 0.65, run)


## Frames something `wide` by `high` round `at`, from the way `from`.
func _frame(at: Vector3, wide: float, high: float, from: Vector3) -> void:
	var size := Vector2(root.get_visible_rect().size)
	var down := tan(deg_to_rad(camera.fov) * 0.5)
	var across := down * (frame_aspect if frame_aspect > 0.0 else size.x / size.y)
	var distance := maxf(wide / 0.7 * 0.5 / across, high / 0.7 * 0.5 / down)
	var up := Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.BACK
	camera.look_at_from_position(at + from.normalized() * distance, at, up)


# --- The maze ---

func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	# (everything else that hunts is stopped, so that nothing catches him)
	for enemy in world.enemies.enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = false
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	await wait(0.5)
	var found := _straight_run(3)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var side := Vector3(-along.z, 0, along.x)
	_stand(cell, way)
	await wait(1.0)
	var chickens := Chickens.new()
	chickens.maze = maze
	chickens.mob_time = 60.0
	chickens.seed_choices(5)
	chickens.position = maze.world(cell + way * 2) + Vector3.UP * 0.05
	world.add_child(chickens)
	await wait(6.0)
	var flock: ChickenFlock = chickens.flock
	var home: Vector3 = maze.world(cell + way * 2)
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	# Foraging in the hall, seen from the boy's height, a little way off.
	var ground: float = maze.ground_height(home)
	var middle := flock.centre()
	# (from the open side of the hall, not the plants along the wall)
	var out := side if nav.clear_of_walls(middle + side * 4.0, 1.0) else -side
	eye.look_at_from_position(middle - along * 5.0 + out * 3.0 + Vector3(0, 1.3, 0), middle + Vector3(0, 0.2, 0))
	eye.make_current()
	await wait(0.3)
	await shot("30_maze_foraging_from_his_height")
	eye.fov = 32.0
	eye.look_at_from_position(home - along * 4.0 + side * 2.0 + Vector3(0, ground + 0.9, 0), flock.centre() + Vector3(0, 0.25, 0))
	await wait(1.5)
	await shot("31_maze_foraging_close")
	eye.fov = 50.0
	# The game's camera, the boy walking up the hall towards them.
	boy.global_position = home - along * 9.0 + Vector3.UP * 0.1
	world.camera.make_current()
	await wait(0.6)
	await shot("32_maze_game_camera_ahead")
	var with := await _draws()
	flock.visible = false
	chickens.flock.get_child(0).visible = false
	var without := await _draws()
	chickens.flock.get_child(0).visible = true
	flock.visible = true
	print("draws, this view, with the flock: %d, without it: %d" % [with, without])
	# He runs at them: the panic.
	var mid := flock.centre()
	var open_side := side if nav.clear_of_walls(mid + side * 4.0, 1.0) else -side
	eye.look_at_from_position(mid - along * 7.0 + open_side * 3.5 + Vector3(0, 1.6, 0), mid + Vector3(0, 0.6, 0))
	eye.make_current()
	boy.global_position = Vector3(mid.x, maze.ground_height(mid) + 0.1, mid.z) - along * 4.0
	chickens.startle(boy)
	await wait(0.55)
	await shot("33_maze_panic_burst")
	await wait(0.4)
	await shot("34_maze_panic_flying")
	await wait(0.8)
	await shot("35_maze_panic_scattered")
	await wait(9.0, func() -> bool: return chickens.mode == Chickens.Mode.FORAGE)
	await wait(3.0)
	# He runs into one: the mob.
	var at: Vector3 = flock.bird_position(1)
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z) - along * 0.4
	boy.rotation.y = atan2(along.x, along.z)
	await wait(0.3)
	chickens.start_mob(boy)
	await wait(2.5)
	var head: Vector3 = boy.global_position + Vector3.UP * 1.5
	eye.look_at_from_position(boy.global_position - along * 4.5 + side * 1.2 + Vector3.UP * 1.9, head - Vector3.UP * 0.4)
	await shot("36_maze_mob_round_the_boy")
	await wait(0.4)
	eye.look_at_from_position(boy.global_position + along * 3.5 + side * 1.0 + Vector3.UP * 1.3, head - Vector3.UP * 0.3)
	await shot("37_maze_mob_facing")
	world.camera.make_current()
	await wait(0.5)
	await shot("38_maze_mob_game_camera")




# --- Tame chickens in the clearing ---

func _clearing() -> void:
	if world:
		# (the maze's round, if it was pictured first)
		world.queue_free()
		await process_frame
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	boy = world.player
	boy.takes_input = false
	for enemy in world.enemies.enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = false
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	print("tame flocks: %d" % world.wildlife.size())
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 45.0
	for k in world.wildlife.size():
		var tame: TameChickens = world.wildlife[k]
		var home: Vector3 = tame.flock.home
		# He stands a little way off, between them and the middle of the clearing.
		var toward := Vector3(-home.x, 0.0, -home.z).normalized()
		var stand := home + toward * 9.0
		stand.y = maze.ground_height(stand) + 0.1
		boy.global_position = stand
		boy.velocity = Vector3.ZERO
		boy.rotation.y = atan2(-toward.x, -toward.z)
		world.camera._yaw = atan2(toward.x, toward.z)
		world.camera.snap()
		await wait(4.0)
		var middle := tame.flock.centre()
		var side := Vector3(-toward.z, 0, toward.x)
		eye.look_at_from_position(middle + toward * 6.0 + side * 1.5 + Vector3.UP * 1.3, middle + Vector3.UP * 0.25)
		eye.make_current()
		await wait(0.3)
		await shot("40_clearing_flock%d_from_his_height" % k)
		eye.fov = 28.0
		eye.look_at_from_position(middle + toward * 4.0 - side * 1.5 + Vector3.UP * 0.8, middle + Vector3.UP * 0.25)
		await wait(1.0)
		await shot("41_clearing_flock%d_close" % k)
		eye.fov = 45.0
		world.camera.make_current()
		await wait(0.5)
		await shot("42_clearing_flock%d_game_camera" % k)
	# He runs through the first: they scatter, squawking, and settle again.
	var first: TameChickens = world.wildlife[0]
	var mid := first.flock.centre()
	var into := Vector3(-mid.x, 0, -mid.z).normalized()
	eye.look_at_from_position(mid + into * 7.0 + Vector3(-into.z, 0, into.x) * 3.0 + Vector3.UP * 1.4, mid + Vector3.UP * 0.4)
	eye.make_current()
	boy.global_position = Vector3(mid.x, maze.ground_height(mid) + 0.1, mid.z) + into * 1.5
	boy.velocity = -into * 4.4
	first.flock.scare(boy.global_position)
	await wait(0.6)
	await shot("43_clearing_scatter")
	await wait(3.0)
	await shot("44_clearing_settled")

func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


func _stand(at: Vector2i, along: Vector2i) -> void:
	boy.global_position = maze.world(at) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(float(along.x), float(along.y))
	world.camera._yaw = atan2(float(-along.x), float(-along.y))
	world.camera.snap()
