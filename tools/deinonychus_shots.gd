extends SceneTree
## Pictures of the deinonychus (creatures/deinonychus): close up on a plain
## floor under the game's kind of light (each view, the head, the foot and its
## sickle claw, beside the boy for scale, each call and mood: the head cocked,
## crouched, tired, a hoot, a hiss; the pounce from the wind-up through the
## leap to the pin), strips of frames across a stride of the walk and of the
## run from the side, and in the maze (a pack in a hall, one coming round a
## corner, the pounce at the boy, one baffled under him up a terrace). Says
## how many draws a frame takes. Needs a real window (the engine draws nothing
## headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/deinonychus_shots.gd -- <folder> [studio|strips|maze|all]

var folder := "deinonychus_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D


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
	if mode in ["strips", "all"]:
		await _strips()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


## Whatever is moving things along, called every frame while a picture is taken too.
var mover := Callable()


func shot(name: String) -> void:
	for i in 2:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame


## Looks at `target` from `offset` away (in `thing`'s own space, if it is given).
func look(target: Vector3, offset: Vector3, thing: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if thing:
		from = Basis(Vector3.UP, thing.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _floor_stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 600.0


# --- On a plain floor ---

func _studio() -> void:
	_floor_stage()
	var dino := Deinonychus.new()
	dino.sound = false
	stage_root.add_child(dino)
	await frames(30)
	var middle := Vector3(0.0, 0.8, -0.3)
	var head := Vector3(0.0, 1.22, 1.05)
	look(middle, Vector3(4.4, 0.3, 0.0), dino)
	await shot("s01_side")
	look(middle, Vector3(3.0, 0.9, 3.0), dino)
	await shot("s02_three_quarter")
	look(middle + Vector3(0.0, 0.1, 0.6), Vector3(0.3, 0.3, 3.6), dino)
	await shot("s03_front")
	look(middle, Vector3(-3.0, 1.2, -2.8), dino)
	await shot("s04_back_quarter")
	look(middle, Vector3(0.3, 4.6, 0.2), dino)
	await shot("s05_top")
	dino.look_at_point = Vector3.INF
	look(head, Vector3(1.3, 0.25, 0.9), dino)
	await shot("s06_head")
	look(head, Vector3(-1.0, 0.1, 1.2), dino)
	await shot("s07_head_other")
	look(Vector3(0.11, 0.15, 0.1), Vector3(0.9, 0.25, 0.6), dino)
	await shot("s08_foot")
	look(Vector3(0.18, 0.78, 0.45), Vector3(1.3, 0.2, 0.2), dino)
	await shot("s09_wing")

	# Beside the boy, for scale
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	stage_root.add_child(ground_body)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = Vector3(-0.9, 0.05, 1.6)
	boy.rotation.y = PI * 0.6
	await frames(20)
	look(Vector3(-0.3, 0.9, 0.3), Vector3(5.5, 0.5, 3.0))
	await shot("s10_beside_the_boy")
	dino.look_at_point = boy.global_position + Vector3.UP * 1.3
	dino.cocking = true
	await frames(40)
	look(head + Vector3(0.0, 0.0, -0.1), Vector3(1.4, 0.2, 1.4), dino)
	await shot("s11_head_cocked")
	await frames(25)
	await shot("s11_head_cocked_2")
	boy.queue_free()
	dino.cocking = false
	dino.look_at_point = Vector3.INF

	# Moods and calls
	dino.crouching = true
	await frames(50)
	look(middle, Vector3(5.0, 0.6, 2.5), dino)
	await shot("s12_crouching")
	dino.crouching = false
	dino.tired = true
	await frames(50)
	look(head, Vector3(1.8, 0.2, 1.5), dino)
	await shot("s13_tired")
	dino.tired = false
	await frames(30)
	dino.hoot()
	await frames(30)
	look(head + Vector3(0.0, -0.1, -0.2), Vector3(1.8, 0.2, 1.2), dino)
	await shot("s14_hoot")
	await frames(40)
	dino.hiss()
	await frames(14)
	await shot("s15_hiss")
	await frames(40)

	# The pounce: the wind-up, the leap (moved through the air by hand, as a game would), the pin
	dino.look_at_point = dino.global_position + Vector3(0.0, 0.8, 5.0)
	dino.pounce()
	await frames(int(Deinonychus.WIND_UP * 60.0 * 0.7))
	look(middle, Vector3(4.5, 0.4, 2.0), dino)
	await shot("s16_wind_up")
	look(middle + Vector3(0.0, 0.0, 1.0), Vector3(0.6, 0.4, 4.5), dino)
	await shot("s17_wind_up_front")
	await frames(int(Deinonychus.WIND_UP * 60.0 * 0.3) + 1)
	var start := dino.global_position
	var flight := 0.0
	dino.grounded = false
	mover = func(step: float) -> void:
		flight = minf(flight + step, Deinonychus.LEAP_TIME)
		var u := flight / Deinonychus.LEAP_TIME
		dino.global_position = start + Vector3(0.0, sin(PI * u) * 0.7, u * 4.0)
		look(dino.global_position + Vector3(0.0, 0.8, 0.0), Vector3(4.0, 0.4, 0.5), dino)
	await frames(int(Deinonychus.LEAP_TIME * 60.0 * 0.45))
	await shot("s18_leap")
	await frames(int(Deinonychus.LEAP_TIME * 60.0 * 0.3))
	await shot("s19_leap_late")
	mover = Callable()
	dino.grounded = true
	dino.global_position = start + Vector3(0.0, 0.0, 4.0)
	dino.pin()
	await frames(30)
	look(dino.global_position + Vector3(0.0, 0.6, 0.3), Vector3(3.5, 0.9, 2.5), dino)
	await shot("s20_pin")
	await frames(9)
	await shot("s21_pin_2")
	await frames(90)
	dino.queue_free()
	# The low-detail one (for phones and far off), and one alone for its cost
	var low := Deinonychus.new()
	low.sound = false
	low.low_poly = true
	stage_root.add_child(low)
	await frames(30)
	look(middle, Vector3(3.0, 0.9, 3.0), low)
	await shot("s22_low_poly")
	low.queue_free()
	var alone := Deinonychus.new()
	alone.sound = false
	stage_root.add_child(alone)
	await frames(30)
	look(middle, Vector3(3.0, 0.9, 3.0), alone)
	await shot("s23_full_again")
	stage_root.queue_free()
	await frames(4)


# --- Strips across a stride ---

func _strips() -> void:
	_floor_stage()
	var dino := Deinonychus.new()
	dino.sound = false
	stage_root.add_child(dino)
	await frames(20)
	await _moving(dino, 1.4, 2.5, "t01_walk")
	await _strip(dino, 1.4, "t02_walk_strip", 8)
	await _moving(dino, 6.2, 2.0, "t03_run")
	await _strip(dino, 6.2, "t04_run_strip", 8)
	look(dino.global_position + Vector3(0.0, 0.8, 0.5), Vector3(3.5, 1.0, 4.0), dino)
	await shot("t05_run_quarter")
	# A quick stop
	var speed := 6.2
	while speed > 0.0:
		var step := root.get_process_delta_time()
		speed = maxf(speed - 18.0 * step, 0.0)
		dino.global_position += dino.global_basis.z.normalized() * speed * step
		look(dino.global_position + Vector3(0.0, 0.8, 0.0), Vector3(6.0, 0.5, 0.5), dino)
		await process_frame
		if speed < 3.0 and speed > 2.6:
			await shot("t06_braking")
	# A hard turn, running
	var yaw := dino.rotation.y
	for i in 70:
		var step := root.get_process_delta_time()
		yaw += 2.2 * step
		dino.rotation.y = yaw
		dino.global_position += dino.global_basis.z.normalized() * 5.5 * step
		look(dino.global_position + Vector3(0.0, 0.8, 0.0), Vector3(0.0, 2.5, -6.0), dino)
		await process_frame
	await shot("t07_turning")
	stage_root.queue_free()
	await frames(4)


## Moves it straight ahead at `speed` for `seconds`, the camera beside it, and (if named) takes a picture.
func _moving(dino: Deinonychus, speed: float, seconds: float, name: String) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		dino.global_position += dino.global_basis.z.normalized() * speed * step
		if Vector2(dino.global_position.x, dino.global_position.z).length() > 120.0:
			dino.global_position = Vector3.ZERO
			dino.settle()
		look(dino.global_position + Vector3(0.0, 0.8, -0.3), Vector3(4.4, 0.4, 0.3), dino)
		await process_frame
	if name != "":
		await shot(name)


## A strip of `count` frames, side on, across one stride at `speed`, put side by side in one picture.
func _strip(dino: Deinonychus, speed: float, name: String, count: int) -> void:
	var tiles: Array[Image] = []
	var period := DeinonychusRig._keyed(DeinonychusRig.STRIDE, speed) / speed
	var every := period / count
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		var step := root.get_process_delta_time()
		clock += step
		dino.global_position += dino.global_basis.z.normalized() * speed * step
		look(dino.global_position + Vector3(0.0, 0.75, -0.3), Vector3(4.4, 0.3, 0.0), dino)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.02), int(h * 0.3), int(w * 0.62), int(h * 0.55))))
	var tile := tiles[0]
	var across := 4
	var sheet := Image.create(tile.get_width() * across, tile.get_height() * ((count + across - 1) / across), false, tile.get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % across) * tile.get_width(), (i / across) * tile.get_height()))
	sheet.resize(sheet.get_width() * 2 / 3, sheet.get_height() * 2 / 3)
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (a stride: %.2f s, a frame every %.3f s)" % [folder, name, period, every])


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	# Everything else that hunts is put away, for clear pictures.
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	# A long straight hall to put them in
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 5 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run:
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := maze.world(best)
	# (the boy out of the way to begin with: far down the hall, round the end)
	boy.global_position = start - way * 200.0
	var pack := MazeDeinonychus.pack_of(3, 5)
	for k in pack.size():
		var one := pack[k]
		one.maze = maze
		one.position = start + way * (2.0 + k * 2.5) + side * (k - 1) * 1.5
		one.rotation.y = atan2(way.x, way.z)
		one.hear_range = 0.0
		one.sight_range = 0.0
		one.pose_range = 1000.0
		world.add_child(one)
	await frames(200)
	var lead: MazeDeinonychus = pack[0]
	look(lead.global_position + up * 0.8, way * 6.0 + side * 4.0 + up * 1.6)
	await shot("m01_pack_in_a_hall")
	look(lead.global_position + up * 0.9, -way * 4.0 - side * 2.5 + up * 0.6)
	await shot("m02_pack_close")
	# The boy comes into the hall: they see him.
	var them := lead.global_position
	boy.global_position = start + way * minf(30.0, best_run * Maze.CELL - 3.0)
	print("the hall is %d cells; the boy %.1f m from them" % [best_run, boy.global_position.distance_to(them)])
	for one in pack:
		one.hear_range = 10.0
		one.sight_range = 44.0
	var taken := {}
	for i in 1200:
		await physics_frame
		if i % 60 == 0:
			print("  %s" % ", ".join(pack.map(func(d: MazeDeinonychus) -> String: return "%s %.1fm" % [MazeDeinonychus.Mode.keys()[d.mode], d.global_position.distance_to(boy.global_position)])))
		var drawer: MazeDeinonychus = null
		for one in pack:
			if one.mode == MazeDeinonychus.Mode.STALK:
				drawer = one
		if drawer and not taken.has("stalk") and drawer.global_position.distance_to(boy.global_position) < 12.0:
			taken["stalk"] = true
			var at := boy.global_position + up * 1.5 + (boy.global_position - drawer.global_position).normalized() * 2.0
			look(drawer.global_position + up * 0.8, at - drawer.global_position - up * 0.8)
			await shot("m03_the_drawer_from_the_boy")
		for one in pack:
			if one.mode == MazeDeinonychus.Mode.FLANK and not taken.has("flank") and i > 60:
				taken["flank"] = true
				look(one.global_position + up * 0.8, -Vector3(one.velocity.x, 0.0, one.velocity.z).normalized() * 3.5 + side * 2.0 + up * 1.2)
				await shot("m04_going_round")
			if one.mode == MazeDeinonychus.Mode.WIND_UP and not taken.has("wind"):
				taken["wind"] = true
				var to := (boy.global_position - one.global_position).normalized()
				look(one.global_position + up * 0.6, to * 5.5 + up * 1.0 + to.cross(up) * 1.5)
				await shot("m05_wind_up")
			if one.mode == MazeDeinonychus.Mode.LEAP and not taken.has("leap"):
				taken["leap"] = true
				# (from over the boy's shoulder: what he sees coming)
				var to := (boy.global_position - one.global_position).normalized()
				var eye := boy.global_position + to * 1.8 + up * 1.5 + to.cross(up) * 0.6
				look(one.global_position + up * 0.7, eye - one.global_position - up * 0.7, null, 55.0)
				await shot("m06_leap")
			if one.mode == MazeDeinonychus.Mode.PIN and not taken.has("pin"):
				taken["pin"] = true
				await frames(10)
				look(one.global_position + up * 0.6, side * 3.5 + way * 1.5 + up * 1.6)
				await shot("m07_pin")
		if taken.has("pin"):
			break
	# Up on a block as high as a terrace, out of its reach: baffled under him.
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3.0, MazeFeatures.LOWER.x, 3.0)
	block.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = (shape.shape as BoxShape3D).size
	mesh.mesh = box
	mesh.material_override = Wall.material_for(Wall.Look.ROUGH, true, MazeBuilder.LEDGE_TINT)
	block.add_child(mesh)
	world.add_child(block)
	var pillar := start + way * 20.0
	block.global_position = pillar + up * MazeFeatures.LOWER.x * 0.5
	boy.global_position = pillar + up * (MazeFeatures.LOWER.x + 0.1)
	boy.velocity = Vector3.ZERO
	var under: MazeDeinonychus = pack[1]
	under.global_position = pillar - way * 6.0
	under.sight_range = 44.0
	for k in 600:
		await physics_frame
		under.notice(boy)
		if under.mode == MazeDeinonychus.Mode.BAFFLED and k > 240:
			break
	print("  under him: %s, %.1f m off" % [MazeDeinonychus.Mode.keys()[under.mode], Vector2(under.global_position.x - pillar.x, under.global_position.z - pillar.z).length()])
	var between := pillar.lerp(under.global_position, 0.5) + up * 3.0
	look(between, -way * 11.0 + side * 2.5 + up * 0.5, null, 50.0)
	await shot("m08_baffled_under_the_block")
	look(under.global_position + up * 0.6, boy.global_position + up * 1.4 - under.global_position - up * 0.6 + side * 0.5)
	await shot("m09_from_up_there")
