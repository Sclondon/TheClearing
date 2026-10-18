extends SceneTree
## Pictures of the coyotes (creatures/coyote): close up on a plain floor under
## the game's kind of light (each view, the head, a slink, a chorus), strips of
## frames from the side through a stride of the trot and of the gallop, and in
## a hall of a real round (a pack at the end of it in the mist, from the boy's
## height). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/coyote_shots.gd -- <folder> [studio|strips|maze|all]

const SIZE := 0.82

var folder := "coyote_shots"
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
	# (a steady sixty frames a second, so that strips of frames are evenly spaced in time)
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["strips", "all"]:
		await _strips()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


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
		await process_frame


func look(target: Vector3, offset: Vector3, animal: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if animal:
		from = Basis(Vector3.UP, animal.rotation.y) * offset
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
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


# --- On a plain floor ---

func _studio() -> void:
	_stage()
	var coyote := Coyote.new()
	coyote.sound = false
	coyote.scale = Vector3.ONE * SIZE
	stage_root.add_child(coyote)
	await frames(20)
	var middle := Vector3(0.0, 0.5, 0.1)
	var head := Vector3(0.0, 0.72, 0.45)
	look(middle, Vector3(0.0, 0.25, 2.2), coyote)
	await shot("c01_front")
	look(middle, Vector3(2.8, 0.2, 0.0), coyote)
	await shot("c02_side")
	look(middle, Vector3(1.9, 0.5, 1.8), coyote)
	await shot("c03_three_quarter")
	look(middle, Vector3(-1.8, 0.8, -1.8), coyote)
	await shot("c04_back_quarter")
	look(head, Vector3(0.55, 0.1, 0.65), coyote)
	await shot("c05_head")
	look(head, Vector3(0.05, 0.05, 0.85), coyote)
	await shot("c06_head_front")
	look(head, Vector3(0.85, 0.05, 0.0), coyote)
	await shot("c07_head_side")
	coyote.snarling = true
	await frames(30)
	look(head + Vector3(0.0, -0.06, 0.0), Vector3(0.5, 0.0, 0.6), coyote)
	await shot("c08_snarl")
	coyote.snarling = false

	var other := Coyote.new()
	other.sound = false
	other.variant = 1
	other.scale = Vector3.ONE * SIZE * 0.95
	other.position = Vector3(1.1, 0.0, -0.5)
	other.rotation.y = -0.4
	stage_root.add_child(other)
	await frames(20)
	look(Vector3(0.55, 0.5, 0.0), Vector3(0.8, 0.5, 3.4))
	await shot("c09_both")
	other.queue_free()

	coyote.slinking = true
	await _moving(coyote, 1.0, 2.0, "c10_slink")
	look(coyote.global_position + Vector3(0.0, 0.45, 0.0), Vector3(1.7, 0.4, 1.7), coyote)
	await shot("c11_slink_quarter")
	coyote.slinking = false
	coyote.tracking = true
	await _moving(coyote, 1.2, 1.6, "c12_sniffing")
	coyote.tracking = false
	await _moving(coyote, 0.0, 1.2, "")
	coyote.look_at_point = coyote.global_position + coyote.global_basis.z * 6.0 + Vector3(2.0, 0.8, 0.0)
	await frames(40)
	look(coyote.global_position + Vector3(0.0, 0.5, 0.2), Vector3(1.8, 0.3, 1.0), coyote)
	await shot("c13_stare")
	coyote.look_at_point = Vector3.INF
	coyote.chorus(0, false)
	await frames(60)
	look(coyote.global_position + Vector3(0.0, 0.6, 0.3), Vector3(1.6, 0.25, 1.2), coyote)
	await shot("c14_chorus_howl")
	await frames(200)
	coyote.chorus(1, true)
	await frames(60)
	await shot("c15_chorus_sitting")
	stage_root.queue_free()
	await frames(4)


func _moving(animal: Node3D, speed: float, seconds: float, name: String) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		animal.global_position += animal.global_basis.z.normalized() * speed * step
		if animal.global_position.length() > 30.0:
			animal.global_position = Vector3.ZERO
			(animal as Dog).settle()
		look(animal.global_position + Vector3(0.0, 0.5, 0.0) + animal.global_basis.z * 0.1, Vector3(2.8, 0.25, 0.2), animal)
		await process_frame
	if name != "":
		await shot(name)


# --- Strips of frames from the side ---

## Moves it at `speed` for a while, then takes `count` frames `every` frames
## apart from the side, the camera going with it, and lays them in a row.
func _strip(animal: Node3D, speed: float, count: int, every: int, name: String) -> void:
	await _moving(animal, speed, 2.0, "")
	var pictures: Array[Image] = []
	for k in count:
		for f in every:
			var step := root.get_process_delta_time()
			animal.global_position += animal.global_basis.z.normalized() * speed * step
			look(animal.global_position + Vector3(0.0, 0.42, 0.0), Vector3(3.4, 0.2, 0.0), animal, 32.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var w := image.get_width()
		var h := image.get_height()
		pictures.append(image.get_region(Rect2i(w / 2 - h * 3 / 8, h / 8, h * 3 / 4, h * 3 / 4)))
	var tile := pictures[0].get_width()
	var across := mini(count, 4)
	var rows := ceili(float(count) / across)
	var sheet := Image.create(tile * across, tile * rows, false, pictures[0].get_format())
	for k in pictures.size():
		sheet.blit_rect(pictures[k], Rect2i(Vector2i.ZERO, Vector2i(tile, tile)), Vector2i((k % across) * tile, (k / across) * tile))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func _strips() -> void:
	_stage()
	var coyote := Coyote.new()
	coyote.sound = false
	coyote.scale = Vector3.ONE * SIZE
	stage_root.add_child(coyote)
	await frames(10)
	# (a frame is about a sixtieth of a second)
	await _strip(coyote, 1.9, 8, 3, "t01_trot_strip")
	await _strip(coyote, 6.0, 8, 2, "t02_gallop_strip")
	await _strip(coyote, 0.9, 8, 5, "t03_walk_strip")
	stage_root.queue_free()
	await frames(4)


# --- In the maze ---

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
	camera.far = 400.0
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
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
	var up := Vector3.UP
	var start := maze.world(best)
	start = _hall_middle(world, start, side)
	var far_end := start + way * minf(best_run * Maze.CELL - 4.0, 28.0)
	# The pack at the far end of the hall, looking back down it at him
	var pack: Array[Coyote] = []
	for i in 4:
		var one := Coyote.new()
		one.sound = false
		one.variant = i % 2
		one.scale = Vector3.ONE * SIZE * [1.0, 0.94, 1.04, 0.9][i]
		one.coat_tint = [Color.WHITE, Color(1.04, 0.98, 0.92), Color(0.92, 0.92, 0.94), Color(1.06, 0.96, 0.88)][i]
		world.add_child(one)
		one.global_position = far_end + side * [0.0, 1.4, -1.5, 2.6][i] - way * [0.0, 1.0, 1.6, 2.4][i]
		one.rotation.y = atan2(-way.x, -way.z) + [0.0, 0.3, -0.4, 0.7][i]
		pack.append(one)
	boy.global_position = start
	boy.rotation.y = atan2(way.x, way.z)
	await frames(30)
	for one in pack:
		one.look_at_point = boy.global_position + up * 1.1
	await frames(30)
	# From the boy's height, down the hall
	var eye := start + up * 1.2 + way * 1.2
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(far_end + up * 0.4, up)
	await shot("m01_pack_down_the_hall")
	camera.fov = 22.0
	await shot("m02_pack_down_the_hall_zoom")
	# Closer: the pack stares, one sits, one sniffs about
	pack[1].sitting = true
	pack[3].tracking = true
	var near := far_end - way * 12.0
	camera.fov = 45.0
	camera.global_position = near + up * 1.2 + side * 0.8
	camera.look_at(far_end + up * 0.4 - way * 1.0, up)
	await frames(60)
	await shot("m03_pack_near")
	# The chorus
	for i in pack.size():
		pack[i].chorus(i % Coyote.CHORUSES, i == 1)
	await frames(70)
	await shot("m04_chorus")
	# They slink off down the hall
	pack[1].sitting = false
	pack[3].tracking = false
	for one in pack:
		one.look_at_point = Vector3.INF
		one.hush()
		one.slinking = true
		one.rotation.y = atan2(way.x, way.z)
	mover = func(step: float) -> void:
		for one in pack:
			one.global_position += way * 1.4 * step
	for i in 60:
		mover.call(root.get_process_delta_time())
		await process_frame
	await shot("m05_slinking_off")
	mover = Callable()


## The middle of the hall across `side` from `at` (between the walls either side of it).
func _hall_middle(world: Node3D, at: Vector3, side: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	var ends: Array[Vector3] = []
	for way: Vector3 in [side, -side]:
		var query := PhysicsRayQueryParameters3D.create(from, from + way * 30.0)
		var hit := space.intersect_ray(query)
		ends.append(hit["position"] if hit else from + way * 8.0)
	var middle := ends[0].lerp(ends[1], 0.5)
	return Vector3(middle.x, at.y, middle.z)
