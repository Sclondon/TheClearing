extends SceneTree
## Pictures of the giant boar (creatures/boar): close up on a plain floor under
## the game's kind of light (each view, the head and tusks, beside the boy for
## scale, and each move: rooting, sniffing, the snort, a stamp, the wind-up, a
## strip of frames across one stride of the charge from the side, the skid,
## the slam, stunned, the toss), and in a passage of a real round (rooting in
## a hall, winding up at the boy, charging, slamming into the wall). Says how
## many draws a frame takes. Needs a real window (the engine draws nothing
## headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/boar_shots.gd -- <folder> [studio|maze|all]

const SIZE := 2.7

var folder := "boar_shots"
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
	if mode in ["maze", "all"]:
		await _maze()
	quit()


## Whatever is moving the boar along, called every frame while a picture is
## taken too (so that it is still going when it is).
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


## Looks at `target` from `offset` away (in the boar's own space, if `boar` is given).
func look(target: Vector3, offset: Vector3, boar: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if boar:
		from = Basis(Vector3.UP, boar.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


# --- On a plain floor ---

func _studio() -> void:
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

	var boar := Boar.new()
	boar.scale = Vector3.ONE * SIZE
	stage_root.add_child(boar)
	await frames(30)
	var middle := Vector3(0.0, 1.5, 0.3)
	var head := Vector3(0.0, 1.85, 2.2)
	look(middle, Vector3(0.0, 0.6, 11.0), boar)
	await shot("s01_front")
	look(middle, Vector3(10.0, 0.4, 0.0), boar)
	await shot("s02_side")
	look(middle, Vector3(8.5, 2.0, 7.5), boar)
	await shot("s03_three_quarter")
	look(middle, Vector3(-7.5, 3.0, -7.5), boar)
	await shot("s04_back_quarter")
	look(head, Vector3(2.6, 0.4, 2.4), boar)
	await shot("s05_head")
	look(head, Vector3(-2.4, 0.3, 2.8), boar)
	await shot("s06_head_other")
	look(head + Vector3(0.0, -0.2, 0.0), Vector3(0.2, 0.2, 3.6), boar)
	await shot("s07_head_front")

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
	boy.global_position = Vector3(2.6, 0.05, 3.2)
	boy.rotation.y = PI * 0.8
	await frames(20)
	look(Vector3(1.0, 1.4, 1.2), Vector3(10.0, 1.0, 6.5))
	await shot("s08_beside_the_boy")
	look(Vector3(1.0, 1.4, 1.2), Vector3(-3.0, 0.2, 11.0))
	await shot("s09_beside_the_boy_front")
	boy.queue_free()

	# Walking, rooting, sniffing
	await _moving(boar, 1.4, 1.6, "s10_walk")
	boar.rooting = true
	await _moving(boar, 0.5, 3.0, "s11_rooting")
	look(boar.snout_tip() + Vector3(0.0, 0.5, 0.0), Vector3(4.5, 0.8, 2.5), boar)
	await shot("s12_rooting_close")
	await frames(20)
	await shot("s12_rooting_close_2")
	boar.rooting = false
	boar.sniffing = true
	await _moving(boar, 0.0, 1.5, "")
	look(boar.global_position + Vector3(0.0, 1.9, 1.5) , Vector3(5.5, 0.5, 4.0), boar)
	await shot("s13_sniffing")
	boar.sniffing = false
	# The wind-up: hackles up, a snort (its breath), stamping, head lowered
	boar.look_at_point = boar.global_position + boar.global_basis.z.normalized() * 20.0 + Vector3.UP * 1.0
	boar.bristling = true
	await frames(30)
	boar.snort()
	await frames(5)
	look(boar.global_position + Vector3(0.0, 1.8, 1.4), Vector3(6.0, 0.6, 5.0), boar)
	await shot("s14_snort")
	await frames(40)
	boar.stamp()
	for k in 4:
		await frames(5)
		look(boar.global_position + Vector3(0.0, 1.1, 1.0), Vector3(7.5, 0.3, 2.5), boar)
		await shot("s15_stamp_%d" % k)
	await frames(30)
	boar.lowered = true
	await frames(45)
	look(boar.global_position + Vector3(0.0, 1.4, 1.0), Vector3(8.0, 0.8, 7.0), boar)
	await shot("s16_wind_up")
	look(boar.global_position + Vector3(0.0, 1.4, 1.0), Vector3(1.0, 0.4, 11.0), boar)
	await shot("s17_wind_up_front")
	look(boar.global_position + Vector3(0.0, 1.4, 1.0), Vector3(12.0, 0.4, 0.0), boar)
	await shot("s18_wind_up_side")

	# The charge: a strip of frames across a stride, from the side
	boar.squeal()
	await _moving(boar, 10.5, 2.0, "s20_charge")
	await _strip(boar, 10.5, "s21_charge_strip", 8)
	look(boar.global_position + Vector3(0.0, 1.4, 1.0), Vector3(7.0, 1.2, 9.0), boar)
	await shot("s22_charge_quarter")
	# The skid: slowing hard
	var speed := 10.5
	while speed > 0.0:
		var step := root.get_process_delta_time()
		speed = maxf(speed - 14.0 * step, 0.0)
		boar.global_position += boar.global_basis.z.normalized() * speed * step
		look(boar.global_position + Vector3(0.0, 1.4, 0.5), Vector3(12.0, 0.6, 1.0), boar)
		if speed < 5.0 and speed > 4.6:
			await shot("s23_skid")
		await process_frame
	boar.lowered = false
	boar.bristling = false
	await frames(40)
	# The slam: stopped dead against a wall
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 10.0, 2.0)
	wall.mesh = box
	stage_root.add_child(wall)
	wall.global_position = boar.global_position + boar.global_basis.z.normalized() * (SIZE * 1.25 + 1.0) + Vector3.UP * 5.0
	wall.rotation.y = boar.rotation.y
	boar.slam()
	await frames(4)
	look(boar.global_position + Vector3(0.0, 1.6, 1.2), Vector3(9.0, 1.0, -3.0), boar)
	await shot("s24_slam")
	await frames(20)
	boar.stunned = true
	await frames(70)
	look(boar.global_position + Vector3(0.0, 1.5, 1.0), Vector3(8.0, 1.5, -5.0), boar)
	await shot("s25_stunned")
	await frames(25)
	await shot("s26_stunned_2")
	boar.stunned = false
	wall.queue_free()
	await frames(40)
	# The toss
	boar.toss(1.0)
	await frames(int(BoarRig.TOSS_HOOK * 60.0) + 6)
	look(boar.global_position + Vector3(0.0, 1.8, 1.4), Vector3(4.0, 0.6, 8.0), boar)
	await shot("s27_toss")
	await frames(60)
	stage_root.queue_free()
	await frames(4)


## Moves the boar straight ahead at `speed` for `seconds`, the camera beside it,
## and (if named) takes a picture at the end.
func _moving(boar: Boar, speed: float, seconds: float, name: String) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		boar.global_position += boar.global_basis.z.normalized() * speed * step
		if Vector2(boar.global_position.x, boar.global_position.z).length() > 120.0:
			boar.global_position = Vector3.ZERO
			boar.settle()
		look(boar.global_position + Vector3(0.0, 1.5, 0.3), Vector3(13.0, 0.4, 0.5), boar)
		await process_frame
	if name != "":
		await shot(name)


## A strip of `count` frames, side on, across one stride at `speed`, put side by side in one picture.
func _strip(boar: Boar, speed: float, name: String, count: int) -> void:
	var tiles: Array[Image] = []
	var model_speed := speed / SIZE
	var period := BoarRig._keyed(BoarRig.STRIDE, model_speed) / model_speed
	var every := period / count
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		var step := root.get_process_delta_time()
		clock += step
		boar.global_position += boar.global_basis.z.normalized() * speed * step
		look(boar.global_position + Vector3(0.0, 1.5, 0.3), Vector3(9.0, 0.5, 0.0), boar)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.22), int(h * 0.1), int(w * 0.56), int(h * 0.8))))
	var tile := tiles[0]
	var across := 4
	var sheet := Image.create(tile.get_width() * across, tile.get_height() * ((count + across - 1) / across), false, tile.get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % across) * tile.get_width(), (i / across) * tile.get_height()))
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
	# A long straight hall to put it in
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run and maze.blocked(at, step):
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := maze.world(best)
	var yaw := atan2(way.x, way.z)
	var boar := Boar.new()
	boar.scale = Vector3.ONE * SIZE
	world.add_child(boar)
	boar.global_position = start + way * 4.0
	boar.rotation.y = yaw
	boy.global_position = start + way * 26.0 + side * 2.0
	await frames(30)

	# Rooting about in the mud of the hall
	boar.rooting = true
	mover = func(step: float) -> void:
		boar.global_position += way * 0.5 * step
	await frames(150)
	look(boar.global_position + up * 1.4, way * 9.0 + side * 6.0 + up * 2.5)
	await shot("m01_rooting")
	# It smells him: snout up, a snort, stamping, hackles, head down
	mover = Callable()
	boar.rooting = false
	boar.sniffing = true
	boar.look_at_point = boy.global_position + up * 1.0
	await frames(70)
	look(boar.global_position + up * 1.8, way * 7.0 - side * 5.0 + up * 1.0)
	await shot("m02_sniffing")
	boar.sniffing = false
	boar.bristling = true
	boar.snort()
	await frames(8)
	var over := boy.global_position + up * 1.5 - way * 2.0 + side * 0.8
	look(boar.global_position + up * 1.6, over - boar.global_position - up * 1.6)
	await shot("m03_snort_from_the_boy")
	boar.stamp()
	await frames(25)
	boar.lowered = true
	await frames(40)
	look(boar.global_position + up * 1.4, over - boar.global_position - up * 1.4)
	await shot("m04_wind_up_from_the_boy")
	# The charge
	boar.squeal()
	var target := boy.global_position
	mover = func(step: float) -> void:
		boar.global_position += way * 10.5 * step
	await frames(55)
	look(boar.global_position + up * 1.4, way * 10.0 + side * 5.0 + up * 1.0)
	await shot("m05_charging")
	boy.global_position = target - way * 4.0 + side * 6.0
	await frames(20)
	look(boar.global_position + up * 1.4, side * 14.0 + up * 1.5)
	await shot("m06_charging_side")
	# On to the end of the hall, and into its wall
	mover = func(step: float) -> void:
		boar.global_position += way * 10.5 * step
	for i in 600:
		await frames(1)
		if not nav.line_free(boar.global_position, boar.global_position + way * SIZE * 1.3, 0.0):
			break
	mover = Callable()
	boar.slam()
	await frames(5)
	look(boar.global_position + way * 3.0 + up * 2.0, side * 12.0 - way * 1.0 + up * 1.5)
	await shot("m07_slam")
	boar.lowered = false
	boar.bristling = false
	boar.stunned = true
	await frames(80)
	boy.global_position = boar.global_position - way * 6.0 + side * 5.0
	await frames(5)
	look(boar.global_position + up * 2.0, -way * 10.0 + side * 9.0 + up * 3.0)
	await shot("m08_stunned_by_the_wall")
