extends SceneTree
## Pictures of the dimetrodon (creatures/dimetrodon): on a plain floor under the
## game's kind of light (each view, the head and its teeth, the sail, beside the
## boy, basking, the threat), strips of frames across a stride of its walk
## (from the side and from above, for the swing of its spine), its rush and its
## lunge; and in a real round (the hunter, MazeDimetrodon, basking in a wide
## hall, then rising at the boy and lunging). Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/dimetrodon_shots.gd -- <folder> [studio|strips|maze|all]

var folder := "dimetrodon_shots"
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


func look(target: Vector3, offset: Vector3, dim: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if dim:
		from = Basis(Vector3.UP, dim.rotation.y) * offset
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
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.45, 0.45, 0.45)
	floor.material_override = ground
	stage_root.add_child(floor)
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	stage_root.add_child(ground_body)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _studio() -> void:
	_stage()
	var dim := Dimetrodon.new()
	stage_root.add_child(dim)
	await frames(30)
	var middle := Vector3(0.0, 0.6, -0.3)
	look(middle, Vector3(6.5, 0.4, 0.0), dim)
	await shot("s01_side")
	look(middle, Vector3(4.5, 1.6, 4.2), dim)
	await shot("s02_three_quarter")
	look(middle + Vector3(0, 0, 0.6), Vector3(0.6, 0.5, 5.0), dim)
	await shot("s03_front")
	look(middle, Vector3(-4.0, 2.0, -4.5), dim)
	await shot("s04_back_quarter")
	look(middle, Vector3(0.5, 6.5, 0.3), dim)
	await shot("s05_above")
	var head := dim.rig.head().global_position + Vector3(0.0, -0.02, 0.22)
	look(head, Vector3(0.9, 0.12, 0.55), dim)
	await shot("s06_head")
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = Vector3(1.6, 0.05, 1.8)
	boy.rotation.y = -PI * 0.75
	await frames(20)
	look(Vector3(0.6, 0.7, 0.3), Vector3(5.5, 0.8, 3.0))
	await shot("s07_beside_the_boy")
	boy.queue_free()
	dim.basking = true
	await frames(150)
	look(middle, Vector3(4.5, 1.4, 4.2), dim)
	await shot("s08_basking")
	dim.basking = false
	dim.threatening = true
	dim.look_at_point = dim.global_position + dim.global_basis * Vector3(1.0, 1.2, 4.0)
	dim.hiss()
	await frames(50)
	look(middle + Vector3(0, 0.1, 0.4), Vector3(3.0, 0.6, 3.4), dim)
	await shot("s09_threat")
	look(dim.rig.head().global_position, Vector3(0.6, 0.15, 1.1), dim)
	await shot("s10_threat_jaws")
	stage_root.queue_free()
	await frames(4)


func _strips() -> void:
	_stage()
	var dim := Dimetrodon.new()
	stage_root.add_child(dim)
	await frames(20)
	mover = func(step: float) -> void: dim.global_position += dim.global_basis.z.normalized() * 0.7 * step
	await frames(120)
	await _strip(dim, 0.7, "t01_walk_strip", Vector3(6.0, 0.6, 0.0))
	await _strip(dim, 0.7, "t02_walk_from_above", Vector3(0.3, 7.0, 0.0))
	mover = func(step: float) -> void: dim.global_position += dim.global_basis.z.normalized() * 3.2 * step
	await frames(90)
	await _strip(dim, 3.2, "t03_rush_from_above", Vector3(0.3, 7.0, 0.0))
	mover = Callable()
	await frames(60)
	var tiles: Array[Image] = []
	dim.lunge()
	var clock := 0.0
	var next := 0.0
	while tiles.size() < 8:
		var step := root.get_process_delta_time()
		clock += step
		dim.global_position += dim.global_basis.z.normalized() * (6.0 if clock < 0.45 else 0.0) * step
		look(dim.global_position + Vector3(0, 0.5, 0.3), Vector3(5.0, 0.8, 0.5), dim)
		await process_frame
		if clock >= next:
			next += DimetrodonRig.LUNGE_TIME / 8.0
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			tiles.append(image.get_region(Rect2i(int(image.get_width() * 0.15), int(image.get_height() * 0.1), int(image.get_width() * 0.7), int(image.get_height() * 0.8))))
	_sheet(tiles, "t04_lunge")
	stage_root.queue_free()
	await frames(4)


func _strip(dim: Dimetrodon, speed: float, name: String, offset: Vector3) -> void:
	var tiles: Array[Image] = []
	var period := DimetrodonRig._keyed(DimetrodonRig.STRIDE, speed) / speed
	var every := period / 8.0
	var clock := 0.0
	var next := 0.0
	while tiles.size() < 8:
		var step := root.get_process_delta_time()
		clock += step
		if mover.is_valid():
			mover.call(step)
		look(dim.global_position + Vector3(0.0, 0.5, -0.3), offset, dim)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			tiles.append(image.get_region(Rect2i(int(image.get_width() * 0.15), int(image.get_height() * 0.1), int(image.get_width() * 0.7), int(image.get_height() * 0.8))))
	_sheet(tiles, name)


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
	camera.far = 500.0
	var nav := MazeNav.new(maze)
	var cell: Vector2i = nav.lairs(3)[0]
	var step := Vector2i(1, 0)
	for c: Vector2i in nav.lairs(3):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not maze.blocked(c, s) and not maze.blocked(c, -s) and not maze.blocked(c + s, s):
				cell = c
				step = s
				break
	var way := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var at: Vector3 = maze.world(cell)
	at.y = maze.ground_height(at)
	var dim := MazeDimetrodon.new()
	dim.maze = maze
	dim.position = at + Vector3.UP * 0.05
	dim.rotation.y = atan2(way.x, way.z)
	world.add_child(dim)
	boy.global_position = at - way * 25.0
	await frames(400)
	look(dim.global_position + Vector3.UP * 0.6, -way * 6.0 + side * 3.0 + Vector3.UP * 2.0)
	await shot("m01_basking_in_the_hall")
	print("warmth %.2f mode %s" % [dim.warmth, MazeDimetrodon.Mode.keys()[dim.mode]])
	boy.global_position = dim.global_position + dim.global_basis_forward() * 4.5
	await frames(30)
	look(dim.global_position + Vector3.UP * 0.6, (boy.global_position - dim.global_position).normalized() * 3.0 + side * 3.5 + Vector3.UP * 1.5)
	await shot("m02_rising_at_him")
	print("mode %s" % MazeDimetrodon.Mode.keys()[dim.mode])
	for i in 60:
		await process_frame
		if dim.mode == MazeDimetrodon.Mode.LUNGE:
			break
	await frames(8)
	look(dim.global_position + Vector3.UP * 0.6, side * 4.5 + Vector3.UP * 1.2)
	await shot("m03_lunge")
	print("mode %s" % MazeDimetrodon.Mode.keys()[dim.mode])
