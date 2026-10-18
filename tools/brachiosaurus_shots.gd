extends SceneTree
## Pictures of the brachiosaurus (creatures/brachiosaurus): on a plain floor
## under the game's kind of light (each view, the head and the crest, the feet,
## beside the boy for scale, browsing, looking down, the bellow), strips of
## frames across a stride of its walk (the foot shadows warning where its feet
## will come down), its low model far off; and in a real round, out in the
## desert past the square maze and in a round section (the hunter,
## MazeBrachiosaurus, left to itself, seen from the boy's place far off and
## close under it). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/brachiosaurus_shots.gd -- <folder> [studio|strips|maze|all]

var folder := "brachiosaurus_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D
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
	if mode in ["strips", "all"]:
		await _strips()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


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


## Looks at `target` from `offset` away (in the creature's own space, if `brach` is given).
func look(target: Vector3, offset: Vector3, brach: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if brach:
		from = Basis(Vector3.UP, brach.rotation.y) * offset
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
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 1200.0


# --- On a plain floor ---

func _studio() -> void:
	_stage()
	var brach := Brachiosaurus.new()
	brach.lod_range = 0.0
	stage_root.add_child(brach)
	await frames(30)
	var middle := Vector3(0.0, 6.0, 0.0)
	look(middle, Vector3(38.0, 1.0, 0.0), brach)
	await shot("s01_side")
	look(middle, Vector3(26.0, 6.0, 24.0), brach)
	await shot("s02_three_quarter")
	look(middle, Vector3(3.0, 2.0, 34.0), brach)
	await shot("s03_front")
	look(middle, Vector3(-24.0, 9.0, -24.0), brach)
	await shot("s04_back_quarter")
	look(middle, Vector3(6.0, 40.0, 4.0), brach)
	await shot("s05_above")
	var head := brach.rig.head().global_position + Vector3(0.0, -0.1, 0.4)
	look(head, Vector3(2.6, 0.5, 2.0), brach)
	await shot("s06_head")
	look(head, Vector3(-0.4, 0.3, 3.2), brach)
	await shot("s07_head_front")
	look(Vector3(0.0, 1.0, 0.3), Vector3(7.0, 1.2, 7.0), brach)
	await shot("s08_feet")

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
	boy.global_position = Vector3(4.0, 0.05, 5.5)
	boy.rotation.y = -PI * 0.7
	await frames(20)
	look(Vector3(1.0, 5.5, 1.0), Vector3(30.0, 0.0, 16.0))
	await shot("s09_beside_the_boy")
	# It looks down at him
	brach.look_at_point = boy.global_position + Vector3.UP * 1.2
	await frames(240)
	look(Vector3(1.0, 5.5, 2.0), Vector3(26.0, 0.5, 14.0))
	await shot("s10_looking_down_at_him")
	look(boy.global_position + Vector3.UP * 1.0, Vector3(1.5, 0.6, -3.0))
	await shot("s11_from_his_feet")
	brach.look_at_point = Vector3.INF
	boy.queue_free()

	# Browsing high up, to its left
	brach.browse_point = brach.global_position + Vector3(4.0, 13.5, 9.0)
	await frames(240)
	look(Vector3(0.0, 8.0, 2.0), Vector3(30.0, 2.0, 10.0), brach)
	await shot("s12_browsing")
	look(brach.snout_tip(), Vector3(3.5, 0.4, 2.5), brach)
	await shot("s13_browsing_close")
	brach.browse_point = Vector3.INF
	await frames(120)
	brach.bellow()
	await frames(50)
	look(brach.rig.head().global_position, Vector3(5.0, 0.6, 4.0), brach)
	await shot("s14_bellow")
	await frames(120)
	# Far off, its low model
	brach.queue_free()
	var far := Brachiosaurus.new()
	stage_root.add_child(far)
	await frames(20)
	look(Vector3(0.0, 6.0, 0.0), Vector3(110.0, 4.0, 40.0))
	await frames(10)
	print("far off: low model %s" % far.rig.low_now())
	await shot("s15_far_off_low_model")
	stage_root.queue_free()
	await frames(4)


# --- Strips: a stride of the walk ---

func _strips() -> void:
	_stage()
	var brach := Brachiosaurus.new()
	brach.lod_range = 0.0
	brach.foot_shadows = true
	stage_root.add_child(brach)
	await frames(20)
	mover = func(step: float) -> void: brach.global_position += brach.global_basis.z.normalized() * 1.2 * step
	await frames(200)
	await _strip(brach, 1.2, "t01_walk_strip", 8, Vector3(40.0, 1.0, 0.0))
	look(brach.global_position + Vector3(0.0, 5.0, 0.0), Vector3(28.0, 7.0, 22.0), brach)
	await shot("t02_walking_quarter")
	# The foot shadows, from where someone under it would be
	var lifted := -1
	for k in 400:
		await frames(1)
		for i in 4:
			if brach.landing(i).w > 0.55 and brach.landing(i).w < 0.7:
				lifted = i
		if lifted >= 0:
			break
	var land := brach.landing(maxi(lifted, 0))
	look(Vector3(land.x, 0.3, land.z), Vector3(5.0, 3.5, 6.0), brach)
	await shot("t03_where_the_foot_comes_down")
	look(brach.global_position + Vector3(0.0, 1.0, 0.0), Vector3(14.0, 12.0, 8.0), brach)
	await shot("t04_foot_shadows_from_above")
	mover = func(step: float) -> void: brach.global_position += brach.global_basis.z.normalized() * 2.4 * step
	await frames(150)
	await _strip(brach, 2.4, "t05_fast_strip", 8, Vector3(40.0, 1.0, 0.0))
	mover = func(step: float) -> void: brach.rotation.y += 0.3 * step
	await frames(150)
	look(brach.global_position + Vector3(0.0, 5.0, 0.0), Vector3(28.0, 14.0, 24.0))
	await shot("t06_turning")
	mover = Callable()
	await frames(60)
	stage_root.queue_free()
	await frames(4)


## A strip of `count` frames across one stride at `speed`, from `offset`, put side by side in one picture.
func _strip(brach: Brachiosaurus, speed: float, name: String, count: int, offset: Vector3) -> void:
	var tiles: Array[Image] = []
	var period := BrachiosaurusRig._keyed(BrachiosaurusRig.STRIDE, speed) / speed
	var every := period / count
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		var step := root.get_process_delta_time()
		clock += step
		if mover.is_valid():
			mover.call(step)
		look(brach.global_position + Vector3(0.0, 5.5, 0.0), offset, brach)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.1), int(h * 0.05), int(w * 0.8), int(h * 0.9))))
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


# --- In a real round ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 900.0
	var spots := MazeBrachiosaurus.spots(maze, 6, 7)
	print("spots: %s" % [spots])
	if spots.is_empty():
		return
	# Out in the desert
	var herd: Array[MazeBrachiosaurus] = []
	for k in mini(spots.size(), 3):
		var one := MazeBrachiosaurus.new()
		one.maze = maze
		one.position = spots[k]
		one.rotation.y = float(k) * 2.0
		world.add_child(one)
		herd.append(one)
	var first := herd[0]
	var out := Vector3(first.global_position.x, 0.0, first.global_position.z).normalized()
	boy.global_position = first.global_position - out * 60.0 + Vector3.UP * 2.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.2
	await frames(240)
	var eye: Vector3 = boy.global_position + Vector3.UP * 1.7
	look(eye, Vector3.ZERO)
	camera.global_position = eye - out * 4.0
	camera.look_at(first.global_position + Vector3.UP * 8.0, Vector3.UP)
	await shot("m01_in_the_desert_far")
	boy.global_position = first.global_position + first.global_basis.x * 9.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.2
	await frames(200)
	eye = boy.global_position + Vector3.UP * 1.6
	camera.global_position = eye + (eye - first.global_position).normalized() * 5.0 + Vector3.UP * 0.5
	camera.look_at(first.global_position + Vector3.UP * 7.0, Vector3.UP)
	await shot("m02_close_under_it")
	camera.global_position = first.global_position + Vector3(30.0, 20.0, 30.0)
	camera.look_at(first.global_position + Vector3.UP * 5.0, Vector3.UP)
	await shot("m03_from_above")
	print("mode: %s" % MazeBrachiosaurus.Mode.keys()[first.mode])
