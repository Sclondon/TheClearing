extends SceneTree
## Pictures of the feral dogs (creatures/dog): close up on a plain floor under
## the game's kind of light (each view, the head snarling, and frames from the
## middle of every gait and move), and in a passage of a real round (the pack
## tracking, and charging the boy). Says how many draws a frame takes. Needs a
## real window (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 720x1280 -s res://tools/dog_shots.gd -- <folder> [studio|maze|all]

var folder := "dog_shots"
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


## Whatever is moving the dogs along, called every frame while a picture is
## taken too (so that they are still going when it is).
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


## Looks at `target` from `offset` away (in the dog's own space, if `dog` is given).
func look(target: Vector3, offset: Vector3, dog: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if dog:
		from = Basis(Vector3.UP, dog.rotation.y) * offset
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
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true

	var dog := Dog.new()
	dog.scale = Vector3.ONE * 1.35
	stage_root.add_child(dog)
	await frames(20)
	var head := Vector3(0.0, 1.05, 0.68)
	var middle := Vector3(0.0, 0.72, 0.12)
	look(middle, Vector3(0.0, 0.35, 4.0), dog)
	await shot("s01_front")
	look(middle, Vector3(6.2, 0.3, 0.0), dog)
	await shot("s02_side")
	look(middle, Vector3(3.6, 0.8, 3.4), dog)
	await shot("s03_three_quarter")
	look(middle, Vector3(-3.4, 1.4, -3.4), dog)
	await shot("s04_back_quarter")
	look(head, Vector3(0.75, 0.15, 0.85), dog)
	await shot("s05_head")
	dog.snarling = true
	await frames(30)
	look(head + Vector3(0.0, -0.08, 0.0), Vector3(0.55, 0.02, 0.75), dog)
	await shot("s06_snarl")
	look(head + Vector3(0.0, -0.08, 0.0), Vector3(-0.15, 0.05, 0.95), dog)
	await shot("s07_snarl_front")
	dog.snarling = false

	# The other dog, side by side
	var other := Dog.new()
	other.variant = 1
	other.coat_tint = Color(1.08, 0.98, 0.9)
	other.scale = Vector3.ONE * 1.3
	other.position = Vector3(1.4, 0.0, -0.6)
	other.rotation.y = -0.4
	stage_root.add_child(other)
	await frames(20)
	look(Vector3(0.7, 0.7, 0.0), Vector3(1.0, 0.6, 4.2))
	await shot("s08_both")
	other.queue_free()

	# Moves, on the spot or along a line
	await _moving(dog, 1.2, 1.4, "s10_walk", false)
	await _moving(dog, 2.6, 1.0, "s11_trot", false)
	dog.tracking = true
	await _moving(dog, 1.3, 1.6, "s12_tracking", false)
	look(dog.global_position + Vector3(0.0, 0.4, 0.0) + dog.global_basis.z * 0.6, Vector3(1.9, 0.5, 1.2), dog)
	await shot("s13_tracking_close")
	dog.tracking = false
	dog.stalking = true
	await _moving(dog, 0.8, 2.0, "s14_stalk", false)
	look(dog.global_position + Vector3(0.0, 0.6, 0.0) + dog.global_basis.z * 0.15, Vector3(3.4, 0.6, 3.2), dog)
	await shot("s15_stalk_quarter")
	dog.stalking = false
	for k in 3:
		await _moving(dog, 5.4, 0.55 + 0.11 * k, "s16_gallop_%d" % k, false)
	await _moving(dog, 0.0, 1.0, "", false)
	dog.bark()
	await frames(4)
	look(dog.global_position + Vector3(0.0, 0.9, 0.3), Vector3(1.6, 0.3, 1.6), dog)
	await shot("s17_bark")
	dog.howl(4.0)
	await frames(80)
	look(dog.global_position + Vector3(0.0, 0.9, 0.2), Vector3(3.6, 0.5, 2.0), dog)
	await shot("s18_howl")
	await frames(140)
	# The lunge, frame by frame (time held still between them)
	dog.settle()
	var target := dog.global_position + dog.global_basis.z.normalized() * 3.4
	var post := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.4
	post.mesh = capsule
	post.position = target + Vector3(0.0, 0.7, 0.0)
	stage_root.add_child(post)
	dog.lunge(target)
	var watch := dog.global_position + dog.global_basis.z.normalized() * 1.7 + Vector3(0.0, 0.6, 0.0)
	var taken := 0
	var times := [0.18, 0.36, 0.5, 0.64, 0.72, 0.9]
	var clock := 0.0
	while dog.lunge_stage() != Dog.Lunge.NONE and taken < times.size():
		var step := root.get_process_delta_time()
		dog.global_position += dog.lunge_push() * step
		clock += step
		if clock >= times[taken]:
			look(watch, Vector3(7.0, 0.5, 0.0), dog)
			await shot("s2%d_lunge_%s" % [taken, ["gather", "spring", "flight", "reach", "snap", "land"][taken]])
			taken += 1
		await process_frame
	post.queue_free()
	await frames(20)
	dog.shake()
	await frames(14)
	look(dog.global_position + Vector3(0.0, 0.7, 0.0), Vector3(0.6, 0.5, 4.2), dog)
	await shot("s27_shake")
	await frames(8)
	await shot("s28_shake_2")
	await frames(60)
	dog.sitting = true
	await frames(70)
	look(dog.global_position + Vector3(0.0, 0.6, 0.0), Vector3(3.4, 0.6, 2.8), dog)
	await shot("s29_sit")
	dog.lying = true
	await frames(100)
	await shot("s30_lie")
	stage_root.queue_free()
	await frames(4)


## Moves the dog straight ahead at `speed` for `seconds`, the camera beside it,
## and (if named) takes a picture at the end.
func _moving(dog: Dog, speed: float, seconds: float, name: String, _unused: bool) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		dog.global_position += dog.global_basis.z.normalized() * speed * step
		# (keep it near the middle of the floor)
		if dog.global_position.length() > 30.0:
			dog.global_position = Vector3.ZERO
			dog.settle()
		look(dog.global_position + Vector3(0.0, 0.7, 0.0) + dog.global_basis.z * 0.12, Vector3(6.0, 0.4, 0.3), dog)
		await process_frame
	if name != "":
		await shot(name)


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
	var yaw := atan2(way.x, way.z)
	var dogs: Array[Dog] = []
	for i in 4:
		var dog := Dog.new()
		dog.variant = i % 2
		dog.scale = Vector3.ONE * [1.35, 1.28, 1.4, 1.25][i]
		dog.coat_tint = [Color.WHITE, Color(1.08, 0.97, 0.88), Color(0.85, 0.85, 0.85), Color(1.0, 0.93, 0.85)][i]
		world.add_child(dog)
		dog.global_position = start + way * (2.0 + i * 1.8) + side * [0.0, 1.6, -1.6, 0.8][i]
		dog.rotation.y = yaw
		dogs.append(dog)
	boy.global_position = start + way * minf(best_run * Maze.CELL - 6.0, 40.0)
	await frames(20)
	var centre := func() -> Vector3:
		var sum := Vector3.ZERO
		for dog in dogs:
			sum += dog.global_position
		return sum / dogs.size()
	var run_for := func(count: int) -> void:
		for i in count:
			mover.call(root.get_process_delta_time())
			await process_frame

	# Noses down, coming along the hall on his trail
	for dog in dogs:
		dog.tracking = true
	mover = func(step: float) -> void:
		for dog in dogs:
			dog.global_position += way * 1.8 * step
	await run_for.call(90)
	var middle: Vector3 = centre.call()
	look(middle + up * 0.5, way * 7.5 + up * 2.0 + side * 1.6)
	await shot("m01_tracking")
	look(dogs[0].global_position + up * 0.45, side * 3.0 + way * 1.6 + up * 0.4)
	await shot("m02_tracking_close")

	# They see him (he is put a little way ahead of them): the first bays, and they come on stiff and low
	boy.global_position = dogs[2].global_position + way * 12.0 - side * dogs[2].global_position.dot(side) + side * start.dot(side)
	mover = Callable()
	for dog in dogs:
		dog.tracking = false
		dog.look_at_point = boy.global_position + up * 1.0
	dogs[0].sit_to_howl = false
	dogs[0].howl(1.6)
	await frames(40)
	look(dogs[0].global_position + up * 1.0, way * 3.0 + side * 2.2 + up * 0.2)
	await shot("m03_bay")
	for dog in dogs:
		dog.stalking = true
		dog.snarling = true
	mover = func(step: float) -> void:
		for dog in dogs:
			dog.global_position += way * 1.1 * step
	await run_for.call(80)
	middle = centre.call()
	var over := boy.global_position + way * 4.5 + up * 1.55 + side * 1.3
	look(middle + up * 0.5, over - middle - up * 0.5)
	await shot("m04_stalking_from_the_boy")

	# Then they charge
	for dog in dogs:
		dog.stalking = false
	mover = func(step: float) -> void:
		for k in dogs.size():
			dogs[k].global_position += way * (5.4 - k * 0.2) * step
	await run_for.call(70)
	middle = centre.call()
	look(middle + up * 0.5, over - middle - up * 0.5)
	await shot("m05_charging")
	look(dogs[0].global_position + up * 0.7 - way * 0.4, side * 7.0 + up * 0.6)
	await shot("m06_charging_side")

	# The first springs at him
	boy.global_position = dogs[0].global_position + way * 3.4
	dogs[0].look_at_point = boy.global_position + up * 1.0
	dogs[0].lunge(boy.global_position)
	mover = func(step: float) -> void:
		dogs[0].global_position += dogs[0].lunge_push() * step
		for k in range(1, dogs.size()):
			dogs[k].global_position += way * 4.0 * step
	for i in 60:
		mover.call(root.get_process_delta_time())
		await process_frame
		if dogs[0].lunge_stage() == Dog.Lunge.SPRING and dogs[0].lunge_progress() > 0.5:
			break
	var between := dogs[0].global_position.lerp(boy.global_position, 0.5)
	look(between + up * 0.8, side * 6.5 + up * 0.6)
	await shot("m07_lunge_at_the_boy")
	mover = Callable()
