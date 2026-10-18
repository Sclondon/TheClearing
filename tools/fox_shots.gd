extends SceneTree
## Pictures of the red foxes (creatures/fox): close up on a plain floor under
## the game's kind of light (each view, the head, sitting with its brush round
## its feet, listening, carrying), strips of frames from the side through a
## stride of the trot and the gallop and through the mousing pounce, and in a
## hall of a real round (a fox sitting watching down the hall, from the boy's
## height). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/fox_shots.gd -- <folder> [studio|strips|maze|all]

const SIZE := 0.72

var folder := "fox_shots"
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


func _fox(variant := 0) -> Fox:
	var fox := Fox.new()
	fox.sound = false
	fox.variant = variant
	fox.scale = Vector3.ONE * SIZE
	stage_root.add_child(fox)
	return fox


# --- On a plain floor ---

func _studio() -> void:
	_stage()
	var fox := _fox()
	await frames(20)
	var middle := Vector3(0.0, 0.3, 0.05)
	var head := Vector3(0.0, 0.46, 0.34)
	look(middle, Vector3(0.0, 0.2, 1.7), fox)
	await shot("f01_front")
	look(middle, Vector3(2.0, 0.15, 0.0), fox)
	await shot("f02_side")
	look(middle, Vector3(1.4, 0.4, 1.3), fox)
	await shot("f03_three_quarter")
	look(middle, Vector3(-1.3, 0.6, -1.3), fox)
	await shot("f04_back_quarter")
	look(head, Vector3(0.4, 0.08, 0.5), fox)
	await shot("f05_head")
	look(head, Vector3(0.03, 0.04, 0.62), fox)
	await shot("f06_head_front")
	look(head, Vector3(0.62, 0.04, 0.0), fox)
	await shot("f07_head_side")

	var other := _fox(1)
	other.position = Vector3(0.9, 0.0, -0.4)
	other.rotation.y = -0.4
	await frames(20)
	look(Vector3(0.45, 0.3, 0.0), Vector3(0.6, 0.4, 2.6))
	await shot("f08_both")
	other.queue_free()

	fox.sitting = true
	await frames(80)
	look(middle + Vector3(0.0, 0.05, -0.1), Vector3(1.3, 0.35, 1.1), fox)
	await shot("f09_sitting")
	look(middle + Vector3(0.0, 0.05, -0.1), Vector3(-0.6, 0.5, 1.5), fox)
	await shot("f10_sitting_brush_round")
	fox.sitting = false
	await frames(40)
	fox.listening = true
	await frames(70)
	look(head, Vector3(0.5, 0.15, 0.7), fox)
	await shot("f11_listening")
	fox.listening = false
	fox.carrying = true
	await frames(30)
	look(head, Vector3(0.55, 0.05, 0.4), fox)
	await shot("f12_carrying")
	fox.carrying = false
	fox.scream()
	await frames(30)
	look(head, Vector3(0.6, 0.05, 0.5), fox)
	await shot("f13_scream")
	await frames(60)
	fox.lying = true
	await frames(200)
	look(middle + Vector3(0.0, -0.12, -0.05), Vector3(1.0, 0.7, 1.0), fox)
	await shot("f14_curled_up")
	fox.lying = false
	await frames(60)
	await _moving(fox, 1.6, 2.0, "f15_trotting")
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
		look(animal.global_position + Vector3(0.0, 0.3, 0.0) + animal.global_basis.z * 0.1, Vector3(2.0, 0.18, 0.15), animal)
		await process_frame
	if name != "":
		await shot(name)


# --- Strips of frames from the side ---

func _sheet(pictures: Array[Image], name: String) -> void:
	var tile := pictures[0].get_width()
	var across := mini(pictures.size(), 4)
	var rows := ceili(float(pictures.size()) / across)
	var sheet := Image.create(tile * across, tile * rows, false, pictures[0].get_format())
	for k in pictures.size():
		sheet.blit_rect(pictures[k], Rect2i(Vector2i.ZERO, Vector2i(tile, tile)), Vector2i((k % across) * tile, (k / across) * tile))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var w := image.get_width()
	var h := image.get_height()
	return image.get_region(Rect2i(w / 2 - h * 3 / 8, h / 8, h * 3 / 4, h * 3 / 4))


func _strip(animal: Node3D, speed: float, count: int, every: int, name: String) -> void:
	await _moving(animal, speed, 2.0, "")
	var pictures: Array[Image] = []
	for k in count:
		for f in every:
			var step := root.get_process_delta_time()
			animal.global_position += animal.global_basis.z.normalized() * speed * step
			look(animal.global_position + Vector3(0.0, 0.28, 0.0), Vector3(2.4, 0.15, 0.0), animal, 32.0)
			await process_frame
		pictures.append(await _grab())
	_sheet(pictures, name)


## The mousing pounce, from the side: frames every few frames from the crouch to getting up.
func _pounce_strip(fox: Fox, name: String) -> void:
	fox.global_position = Vector3.ZERO
	fox.rotation.y = 0.0
	fox.settle()
	await frames(20)
	var spot := Vector3(0.0, 0.0, 2.6)
	fox.pounce(spot)
	var pictures: Array[Image] = []
	var k := 0
	while fox.pouncing():
		var step := root.get_process_delta_time()
		fox.global_position += fox.pounce_push() * step
		var middle := Vector3(0.0, 0.45, fox.global_position.z)
		camera.fov = 40.0
		camera.global_position = middle + Vector3(4.6, 0.1, 0.0)
		camera.look_at(middle, Vector3.UP)
		await process_frame
		k += 1
		if k % 9 == 0 and pictures.size() < 16:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			pictures.append(image.get_region(Rect2i(w / 2 - h * 3 / 8, h / 8, h * 3 / 4, h * 3 / 4)))
	_sheet(pictures, name)


func _strips() -> void:
	_stage()
	var fox := _fox()
	await frames(10)
	await _strip(fox, 1.7, 8, 3, "t01_trot_strip")
	await _strip(fox, 6.0, 8, 2, "t02_gallop_strip")
	await _strip(fox, 0.7, 8, 5, "t03_walk_strip")
	await _pounce_strip(fox, "t04_pounce_strip")
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
	var start := _hall_middle(world, maze.world(best), side)
	var far_end := start + way * minf(best_run * Maze.CELL - 4.0, 22.0)
	var fox := Fox.new()
	fox.sound = false
	fox.scale = Vector3.ONE * SIZE
	world.add_child(fox)
	fox.global_position = far_end + side * 0.6
	fox.rotation.y = atan2(-way.x, -way.z)
	var other := Fox.new()
	other.sound = false
	other.variant = 1
	other.scale = Vector3.ONE * SIZE * 0.95
	world.add_child(other)
	other.global_position = far_end - side * 1.2 + way * 1.5
	other.rotation.y = atan2(-way.x, -way.z) + 0.6
	boy.global_position = start
	boy.rotation.y = atan2(way.x, way.z)
	await frames(30)
	fox.sitting = true
	fox.look_at_point = boy.global_position + up * 1.1
	other.look_at_point = boy.global_position + up * 1.1
	await frames(80)
	var eye := start + up * 1.2 + way * 1.2
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(far_end + up * 0.3, up)
	await shot("m01_foxes_down_the_hall")
	camera.fov = 18.0
	await shot("m02_foxes_down_the_hall_zoom")
	var near := far_end - way * 6.0
	camera.fov = 45.0
	camera.global_position = near + up * 0.9 + side * 0.7
	camera.look_at(far_end + up * 0.3, up)
	await shot("m03_foxes_near")
	# The vixen listens, and pounces down the hall
	other.look_at_point = Vector3.INF
	other.rotation.y = atan2(way.x, way.z) + PI
	other.listening = true
	await frames(60)
	await shot("m04_listening")
	other.pounce(other.global_position - way * 2.5)
	mover = func(step: float) -> void:
		other.global_position += other.pounce_push() * step
	for i in 30:
		mover.call(root.get_process_delta_time())
		await process_frame
	await shot("m05_pounce")
	mover = Callable()


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
