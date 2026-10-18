extends SceneTree
## Pictures of the stegosaurus (creatures/stegosaurus): close up on a plain
## floor under the game's kind of light (each view, the head, the plates and
## the spikes, beside the boy for scale, grazing, a calf), strips of frames
## across a stride of its walk and through the swing of its tail, the
## warning; and in a hall of a real round (grazing across it, warning the boy,
## the swing, and the hunter, MazeStegosaurus, left to itself). Says how many
## draws a frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/stegosaurus_shots.gd -- <folder> [studio|strips|maze|all]

var folder := "stegosaurus_shots"
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


## Whatever is moving it along, called every frame while a picture is taken
## too (so that it is still going when it is).
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


## Looks at `target` from `offset` away (in the creature's own space, if `steg` is given).
func look(target: Vector3, offset: Vector3, steg: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if steg:
		from = Basis(Vector3.UP, steg.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.66)
	environment.fog_density = 0.006
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
	plane.size = Vector2(600.0, 600.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 800.0


# --- On a plain floor ---

func _studio() -> void:
	_stage()
	var steg := Stegosaurus.new()
	stage_root.add_child(steg)
	await frames(30)
	var middle := Vector3(0.0, 1.9, -0.3)
	look(middle, Vector3(12.5, 0.6, 0.0), steg)
	await shot("s01_side")
	look(middle, Vector3(9.0, 2.5, 8.0), steg)
	await shot("s02_three_quarter")
	look(middle, Vector3(1.5, 1.0, 12.0), steg)
	await shot("s03_front")
	look(middle, Vector3(-8.5, 3.5, -8.5), steg)
	await shot("s04_back_quarter")
	look(middle + Vector3(0.0, 0.3, 0.0), Vector3(3.0, 14.0, 2.0), steg)
	await shot("s05_above")
	var head := steg.rig.head().global_position + Vector3(0.0, -0.05, 0.25)
	look(head, Vector3(1.6, 0.35, 1.3), steg)
	await shot("s06_head")
	look(head, Vector3(-0.3, 0.1, 2.0), steg)
	await shot("s07_head_front")
	look(Vector3(0.0, 2.6, -3.9), Vector3(3.0, 1.6, -2.5), steg)
	await shot("s08_spikes")
	look(Vector3(0.0, 3.0, 0.3), Vector3(5.0, 1.0, 3.0), steg)
	await shot("s09_plates")
	look(Vector3(0.6, 0.6, 1.0), Vector3(3.0, 0.4, 3.5), steg)
	await shot("s10_feet")

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
	boy.global_position = Vector3(3.2, 0.05, 2.6)
	boy.rotation.y = -PI * 0.6
	await frames(20)
	look(Vector3(1.5, 1.7, 0.5), Vector3(14.0, 1.0, 8.0))
	await shot("s11_beside_the_boy")
	boy.queue_free()

	# Grazing
	steg.grazing = true
	await frames(150)
	look(Vector3(0.0, 1.5, 0.3), Vector3(10.0, 1.5, 5.5), steg)
	await shot("s12_grazing")
	look(steg.beak_tip() + Vector3(0.0, 0.4, -0.3), Vector3(2.6, 0.6, 1.4), steg)
	await shot("s13_grazing_close")
	await frames(40)
	await shot("s13_grazing_close_2")
	steg.grazing = false
	# The warning: someone on its left, behind its flank
	steg.look_at_point = steg.global_position + Vector3(8.0, 1.0, -2.0)
	steg.warning = true
	steg.threat_side = 1.0
	steg.rumble()
	await frames(70)
	look(Vector3(0.0, 1.8, -0.8), Vector3(10.0, 2.0, -4.5), steg)
	await shot("s14_warning")
	look(Vector3(0.0, 1.8, -0.5), Vector3(4.0, 13.0, -1.0), steg)
	await shot("s15_warning_above")
	steg.bellow()
	await frames(30)
	look(steg.rig.head().global_position, Vector3(4.0, 0.6, 3.0), steg)
	await shot("s16_bellow")
	await frames(60)

	# A calf beside its mother
	var calf := Stegosaurus.new()
	calf.scale = Vector3.ONE * 0.38
	calf.scales = 11.0 / 0.38 * 0.7
	stage_root.add_child(calf)
	calf.global_position = Vector3(2.8, 0.0, 2.5)
	calf.rotation.y = 0.4
	steg.warning = false
	steg.look_at_point = Vector3.INF
	await frames(30)
	look(Vector3(1.4, 1.2, 1.0), Vector3(11.0, 1.2, 9.0))
	await shot("s17_calf")
	calf.queue_free()
	stage_root.queue_free()
	await frames(4)


# --- Strips: a stride of the walk, the swing ---

func _strips() -> void:
	_stage()
	var steg := Stegosaurus.new()
	stage_root.add_child(steg)
	await frames(20)
	# Walking: let it get into its stride first
	mover = func(step: float) -> void: steg.global_position += steg.global_basis.z.normalized() * 1.2 * step
	await frames(150)
	await _strip(steg, 1.2, "t01_walk_strip", 8, Vector3(15.0, 0.4, 0.0))
	look(steg.global_position + Vector3(0.0, 1.8, 0.0), Vector3(12.0, 2.5, 10.0), steg)
	await shot("t02_walking_quarter")
	mover = func(step: float) -> void: steg.global_position += steg.global_basis.z.normalized() * 2.5 * step
	await frames(120)
	await _strip(steg, 2.5, "t03_amble_strip", 8, Vector3(15.0, 0.4, 0.0))
	# Turning on the spot
	mover = func(step: float) -> void: steg.rotation.y += 0.6 * step
	await frames(100)
	look(steg.global_position + Vector3(0.0, 1.8, 0.0), Vector3(10.0, 6.0, 10.0))
	await shot("t04_turning")
	mover = Callable()
	await frames(90)
	# The warning, and the swing at someone on its left
	steg.look_at_point = steg.global_position + steg.global_basis * Vector3(6.0, 1.0, -3.0)
	steg.warning = true
	steg.threat_side = 1.0
	await frames(90)
	steg.swing(1.0)
	var tiles: Array[Image] = []
	var count := 8
	var every := StegosaurusRig.SWING_TIME / count
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		clock += root.get_process_delta_time()
		look(steg.global_position + Vector3(0.0, 1.6, -1.5), Vector3(5.0, 14.0, -1.0), steg, 48.0)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.2), 0, int(w * 0.6), h)))
	_sheet(tiles, "t05_swing_from_above")
	await frames(60)
	steg.swing(1.0)
	tiles.clear()
	clock = 0.0
	next = 0.0
	while tiles.size() < count:
		clock += root.get_process_delta_time()
		look(steg.global_position + Vector3(0.0, 1.5, -1.5), Vector3(14.0, 2.0, 2.0), steg, 48.0)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.15), int(h * 0.1), int(w * 0.7), int(h * 0.8))))
	_sheet(tiles, "t06_swing_from_the_side")
	await frames(30)
	# The middle of a swing, big
	steg.swing(1.0)
	await until_swept(steg)
	look(steg.global_position + Vector3(0.0, 1.5, -2.0), Vector3(11.0, 3.0, 6.0), steg)
	await shot("t07_swing")
	await frames(90)
	stage_root.queue_free()
	await frames(4)


## A strip of `count` frames across one stride at `speed`, from `offset`, put side by side in one picture.
func _strip(steg: Stegosaurus, speed: float, name: String, count: int, offset: Vector3) -> void:
	var tiles: Array[Image] = []
	var period := StegosaurusRig._keyed(StegosaurusRig.STRIDE, speed) / speed
	var every := period / count
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		var step := root.get_process_delta_time()
		clock += step
		if mover.is_valid():
			mover.call(step)
		look(steg.global_position + Vector3(0.0, 1.7, -0.4), offset, steg)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.1), int(h * 0.15), int(w * 0.8), int(h * 0.7))))
	_sheet(tiles, name)
	print("(a stride: %.2f s, a frame every %.3f s)" % [period, every])


func _sheet(tiles: Array[Image], name: String) -> void:
	var tile := tiles[0]
	var across := 4
	var sheet := Image.create(tile.get_width() * across, tile.get_height() * ((tiles.size() + across - 1) / across), false, tile.get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % across) * tile.get_width(), (i / across) * tile.get_height()))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2)
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


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
	var start: Vector3 = maze.world(best) + way * Maze.CELL * 1.0
	start.y = maze.ground_height(start)
	# Grazing, standing across the hall
	var steg := Stegosaurus.new()
	world.add_child(steg)
	steg.global_position = start
	steg.rotation.y = atan2(side.x, side.z) + 0.25
	steg.grazing = true
	boy.global_position = start - way * 20.0 + side * 1.5
	boy.rotation.y = atan2(way.x, way.z)
	await frames(120)
	var over := boy.global_position + up * 1.6 - way * 4.0 + side * 1.0
	look(steg.global_position + up * 1.8, over - steg.global_position - up * 1.8)
	await shot("m01_grazing_across_the_hall")
	look(steg.global_position + up * 1.5, way * 13.0 + side * 9.0 + up * 3.0)
	await shot("m02_grazing_in_the_hall")
	# He comes too near: it turns side on to him, tail up, and warns
	boy.global_position = start - way * 6.5 + side * 3.0
	steg.grazing = false
	steg.warning = true
	var to_boy: Vector3 = boy.global_position - steg.global_position
	var forward := steg.global_basis.z.normalized()
	var left := steg.global_basis.x.normalized()
	steg.threat_side = signf(to_boy.dot(left))
	steg.look_at_point = boy.global_position + up * 1.2
	steg.rumble()
	await frames(100)
	over = boy.global_position + up * 1.7 - (steg.global_position - boy.global_position).normalized() * 4.0 + side * 1.5
	look(steg.global_position + up * 1.6 - forward * 1.5, over - steg.global_position - up * 1.6 + forward * 1.5)
	await shot("m03_warning_the_boy")
	look(steg.global_position + up * 1.5, -way * 14.0 - side * 3.0 + up * 5.0)
	await shot("m04_warning_from_aside")
	# And swings
	steg.swing(steg.threat_side)
	await until_swept(steg)
	look(steg.global_position + up * 1.5, -way * 14.0 - side * 3.0 + up * 5.0)
	await shot("m05_the_swing")
	await frames(120)
	steg.queue_free()
	await frames(4)

	# The hunter left to itself: it grazes in the hall; he walks up the middle
	var hunter := MazeStegosaurus.new()
	hunter.maze = maze
	hunter.position = start + up * 0.05
	hunter.rotation.y = atan2(way.x, way.z)
	world.add_child(hunter)
	boy.global_position = start - way * 30.0
	await frames(200)
	look(hunter.global_position + up * 1.8, way * -14.0 + side * 8.0 + up * 5.0)
	await shot("m06_hunter_grazing")
	boy.global_position = start - way * 2.5 + side * 2.8
	await frames(150)
	look(hunter.global_position + up * 1.8, way * -14.0 + side * 8.0 + up * 5.0)
	await shot("m07_hunter_warning")
	print("hunter: %s" % MazeStegosaurus.Mode.keys()[hunter.mode])


## Waits until the spikes are coming through, late in the whip (the tip lags the base), by its own clock, not by frames.
func until_swept(steg: Stegosaurus) -> void:
	while steg.rig._swung < StegosaurusRig.WHIP.y - 0.13:
		await process_frame
