extends SceneTree
## Pictures of the skinwalker (creatures/skinwalker): on all fours among
## coyotes, frames of its rise, upright (front, side, back), close on the face
## under the coyote's head, the all-fours run from the side (a strip of frames),
## and in a hall of a real round. Says how many draws a frame takes. Needs a
## real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/skinwalker_shots.gd -- <folder> [studio|strips|maze|all]

const SIZE := 1.25

var folder := "skinwalker_shots"
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


func look(target: Vector3, offset: Vector3, thing: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if thing:
		from = Basis(Vector3.UP, thing.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.52, 0.55, 0.57)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.6, 0.63, 0.66)
	environment.fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.36, 0.34, 0.31)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _walker() -> Skinwalker:
	var walker := Skinwalker.new()
	walker.sound = false
	walker.scale = Vector3.ONE * SIZE
	stage_root.add_child(walker)
	return walker


func _studio() -> void:
	_stage()
	var walker := _walker()
	var pack: Array[Coyote] = []
	for i in 3:
		var one := Coyote.new()
		one.sound = false
		one.variant = i % 2
		one.scale = Vector3.ONE * 0.82 * [1.0, 0.95, 1.03][i]
		one.position = [Vector3(-1.4, 0.0, 0.6), Vector3(1.5, 0.0, -0.4), Vector3(-0.4, 0.0, -1.8)][i]
		one.rotation.y = [0.3, -0.2, 0.5][i]
		stage_root.add_child(one)
		pack.append(one)
	await frames(30)
	var viewer := Vector3(1.0, 1.2, 7.5)
	for one in pack:
		one.look_at_point = viewer
	walker.aim = viewer
	await frames(40)
	look(Vector3(0.0, 0.5, -0.3), Vector3(1.4, 0.7, 6.5))
	await shot("w01_among_coyotes")
	look(Vector3(0.0, 0.5, 0.0), Vector3(1.4, 0.35, 3.2))
	await shot("w02_among_coyotes_near")
	look(walker.global_position + Vector3(0.0, 0.65, 0.4), Vector3(0.5, 0.15, 1.3), walker)
	await shot("w03_disguise_face")
	look(walker.global_position + Vector3(0.0, 0.5, 0.0), Vector3(3.6, 0.3, 0.0), walker)
	await shot("w04_disguise_side")
	for one in pack:
		one.queue_free()
	# The rise, frame by frame
	walker.glare = 0.8
	walker.rise()
	var times := [0.3, 0.7, 1.0, 1.3, 1.6, 2.2]
	var clock := 0.0
	var taken := 0
	while taken < times.size():
		clock += root.get_process_delta_time()
		if clock >= times[taken]:
			look(walker.global_position + Vector3(0.0, 1.05, 0.0), Vector3(4.4, 0.4, 2.2), walker)
			await shot("w1%d_rise_%d" % [taken, taken])
			taken += 1
		await process_frame
	await frames(30)
	var middle := walker.global_position + Vector3(0.0, 1.1, 0.0)
	look(middle, Vector3(0.0, 0.2, 5.0), walker)
	await shot("w20_upright_front")
	look(middle, Vector3(5.0, 0.2, 0.0), walker)
	await shot("w21_upright_side")
	look(middle, Vector3(-2.0, 0.6, -4.6), walker)
	await shot("w22_upright_back")
	look(middle, Vector3(3.2, 0.5, 3.6), walker)
	await shot("w23_upright_quarter")
	var face := walker.mouth() + Vector3(0.0, 0.05, 0.0)
	look(face, Vector3(0.25, -0.1, 1.0), walker)
	await shot("w24_face")
	look(face, Vector3(0.0, -0.35, 0.8), walker)
	await shot("w25_face_from_below")
	walker.call_out(1)
	await frames(40)
	look(face + Vector3(0.0, -0.1, 0.0), Vector3(0.8, 0.0, 1.6), walker)
	await shot("w26_calling")
	await frames(60)
	# Walking upright
	mover = func(step: float) -> void:
		walker.global_position += walker.global_basis.z.normalized() * 0.9 * step
	await frames(70)
	look(walker.global_position + Vector3(0.0, 1.1, 0.0), Vector3(4.2, 0.4, 1.5), walker)
	await shot("w27_upright_walk")
	mover = Callable()
	walker.grab()
	await frames(14)
	await shot("w28_grab")
	stage_root.queue_free()
	mover = Callable()
	await frames(4)


func _strip(walker: Node3D, speed: float, count: int, every: int, name: String, height := 0.5, away := 4.0) -> void:
	var pictures: Array[Image] = []
	for k in count:
		for f in every:
			walker.global_position += walker.global_basis.z.normalized() * speed * root.get_process_delta_time()
			look(walker.global_position + Vector3(0.0, height, 0.0), Vector3(away, 0.2, 0.0), walker, 34.0)
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
	var walker := _walker()
	await frames(10)
	for i in 90:
		walker.global_position += walker.global_basis.z.normalized() * 1.0 * root.get_process_delta_time()
		await process_frame
	await _strip(walker, 1.0, 8, 6, "t01_crawl_strip")
	walker.glare = 1.0
	for i in 60:
		walker.global_position += walker.global_basis.z.normalized() * 8.0 * root.get_process_delta_time()
		await process_frame
	await _strip(walker, 8.5, 8, 2, "t02_run_strip", 0.55, 5.0)
	stage_root.queue_free()
	await frames(4)


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
	var space := (world as Node3D).get_world_3d().direct_space_state
	var ends: Array[Vector3] = []
	for dir: Vector3 in [side, -side]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start + up, start + up + dir * 30.0))
		ends.append(hit["position"] if hit else start + dir * 8.0)
	start = Vector3((ends[0].x + ends[1].x) * 0.5, start.y, (ends[0].z + ends[1].z) * 0.5)
	var far_end := start + way * 22.0
	var pack: Array[Coyote] = []
	for i in 3:
		var one := Coyote.new()
		one.sound = false
		one.variant = i % 2
		one.scale = Vector3.ONE * 0.82 * [1.0, 0.94, 1.03][i]
		world.add_child(one)
		one.global_position = far_end + side * [1.6, -1.8, 3.0][i] - way * [0.6, 1.2, 2.6][i]
		one.rotation.y = atan2(-way.x, -way.z) + [0.2, -0.3, 0.5][i]
		pack.append(one)
	var walker := Skinwalker.new()
	walker.sound = false
	walker.scale = Vector3.ONE * SIZE
	world.add_child(walker)
	walker.put(far_end - side * 0.2, atan2(-way.x, -way.z))
	boy.global_position = start - way * 3.0
	await frames(30)
	var eye := start + up * 1.2
	for one in pack:
		one.look_at_point = eye
	walker.aim = eye
	walker.glare = 0.35
	await frames(40)
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(far_end + up * 0.5, up)
	await shot("m01_hall_pack_with_it")
	camera.fov = 18.0
	await shot("m02_hall_pack_zoom")
	walker.glare = 1.0
	walker.rise()
	await frames(150)
	camera.fov = 40.0
	await shot("m03_hall_risen")
	camera.fov = 18.0
	await shot("m04_hall_risen_zoom")
	# It drops and comes down the hall at him
	walker.drop()
	await frames(40)
	walker.rotation.y = atan2(-way.x, -way.z)
	mover = func(step: float) -> void:
		walker.global_position -= way * 8.5 * step
	await frames(110)
	mover = Callable()
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(walker.global_position + up * 0.5, up)
	await shot("m05_hall_coming")
