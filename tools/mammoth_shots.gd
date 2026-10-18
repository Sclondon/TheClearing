extends SceneTree
## Pictures of the woolly mammoth (creatures/mammoth): close up on a plain floor
## under the game's kind of light (each view with the boy for size, the head,
## the trunk grazing, feeling the air, the trumpet, the ears spread, the charge,
## the calf), frame strips of its walk and amble from the side (time stepped by
## hand), and a herd in a hall of a real round (MazeMammoth: grazing seen from
## the boy's height, the alarm, the ring round the calf, the matriarch's
## display, her mock charge and her charge). Says how many draws a frame takes.
## And a herd out on the open plains of the desert ring. Needs a real window (the
## engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/mammoth_shots.gd -- <folder> [studio|strips|maze|plains|all]

const STEP := 1.0 / 60.0

var folder := "mammoth_shots"
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
	if mode in ["plains", "all"]:
		await _plains()
	quit()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


## Waits `count` frames of the physics clock (sixty a second, whatever the drawing does).
func frames(count: int) -> void:
	for i in count:
		await physics_frame


## Looks at `target` from `offset` away (in the animal's own space, if `who` is given).
func look(target: Vector3, offset: Vector3, who: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if who:
		from = Basis(Vector3.UP, who.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _floor_stage() -> void:
	if stage_root:
		stage_root.queue_free()
		await frames(2)
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
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	var body := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(400.0, 1.0, 400.0)
	box.position.y = -0.5
	body.add_child(box)
	stage_root.add_child(body)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


## Drives `who` by hand: `seconds` of going straight ahead at `speed`, its rig stepped at 60 a second.
func drive(who: Mammoth, speed: float, seconds: float) -> void:
	who.measure_velocity = false
	who.rig.process_mode = Node.PROCESS_MODE_DISABLED
	var forward := who.global_basis.z.normalized()
	who.velocity = forward * speed
	for i in int(seconds / STEP):
		who.global_position += forward * speed * STEP
		who.rig._process(STEP)
		who._process(STEP)


func _studio() -> void:
	await _floor_stage()
	var cow := Mammoth.new()
	cow.sound = false
	stage_root.add_child(cow)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	boy.global_position = Vector3(2.6, 0.0, 3.2)
	await frames(40)
	var middle := Vector3(0.0, 1.9, 0.3)
	look(middle, Vector3(11.0, 0.4, 1.0), cow)
	await shot("s01_side_with_boy")
	boy.global_position = Vector3(60.0, 0.0, 60.0)
	look(middle, Vector3(7.5, 1.4, 8.0), cow)
	await shot("s02_three_quarter")
	look(middle + Vector3(0.0, 0.3, 0.0), Vector3(0.6, 0.6, 10.5), cow)
	await shot("s03_front")
	look(middle, Vector3(-7.5, 3.0, -7.5), cow)
	await shot("s04_back_quarter")
	var head := cow.head_position() + Vector3(0.0, -0.5, 0.6)
	look(head, Vector3(2.6, 0.4, 3.2), cow)
	await shot("s05_head")
	# The trunk grazing: down to the grass, the tip curled round it, up to the mouth
	cow.grazing = true
	for k in 4:
		await frames(int(MammothRig.GRAZE_TIME * 60.0 * 0.25))
		look(middle + Vector3(0.0, -0.4, 1.0), Vector3(7.5, 0.5, 4.5), cow)
		await shot("s06_grazing_%d" % k)
	cow.grazing = false
	# Feeling the air towards something
	cow.look_at_point = Vector3(4.0, 2.5, 14.0)
	cow.feeling = true
	cow.alert = true
	await frames(90)
	look(middle + Vector3(0.0, 0.4, 0.5), Vector3(8.0, 0.8, 5.5), cow)
	await shot("s07_feeling_the_air")
	cow.feeling = false
	# The display: ears out, trumpeting
	cow.ears_out = true
	cow.trumpet()
	await frames(40)
	look(middle + Vector3(0.0, 0.6, 0.0), Vector3(4.0, 0.2, 9.0), cow)
	await shot("s08_trumpeting_ears_out")
	await frames(120)
	cow.alert = false
	cow.ears_out = false
	# Lowered, as it charges
	cow.lowered = true
	await frames(70)
	look(middle, Vector3(7.0, 0.3, 6.5), cow)
	await shot("s09_lowered")
	cow.lowered = false
	cow.stamp()
	await frames(20)
	look(middle, Vector3(8.0, 0.3, 4.0), cow)
	await shot("s10_stamp")
	cow.queue_free()
	# The calf beside its mother
	var mother := Mammoth.new()
	mother.sound = false
	stage_root.add_child(mother)
	var calf := Mammoth.new()
	calf.calf = true
	calf.sound = false
	calf.position = Vector3(2.4, 0.0, 0.6)
	calf.rotation.y = 0.3
	stage_root.add_child(calf)
	await frames(40)
	look(Vector3(1.0, 1.4, 0.4), Vector3(9.5, 0.6, 6.0), mother)
	await shot("s11_mother_and_calf")
	look(calf.global_position + Vector3(0.0, 0.9, 0.3), Vector3(2.6, 0.3, 3.0), calf)
	await shot("s12_calf")
	mother.queue_free()
	calf.queue_free()
	await frames(5)


## Its walk and amble from the side, as strips of frames.
func _strips() -> void:
	await _floor_stage()
	for gait: Array in [["walk", 1.3], ["fast_walk", 2.4], ["amble", 6.0]]:
		var cow := Mammoth.new()
		cow.sound = false
		cow.rotation.y = PI * 0.5
		stage_root.add_child(cow)
		await frames(5)
		cow.lowered = gait[0] == "amble"
		drive(cow, gait[1], 3.0)
		for k in 6:
			drive(cow, gait[1], 0.12 if gait[0] != "walk" else 0.22)
			camera.fov = 40.0
			camera.global_position = cow.global_position + Vector3(0.0, 1.8, -12.0)
			camera.look_at(cow.global_position + Vector3(0.0, 1.6, 0.0), Vector3.UP)
			await shot("t_%s_%d" % [gait[0], k])
		cow.queue_free()
		await frames(3)


func _maze() -> void:
	if stage_root:
		stage_root.queue_free()
		stage_root = null
		await frames(2)
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
	camera.far = 600.0
	var nav := MazeNav.new(maze)
	var start := Vector2i(-1, -1)
	var step := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in Maze.STEPS:
			var at := cell
			var run := 0
			while run < 5 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run == 5:
				start = cell
				step = s
				break
		if step != Vector2i.ZERO:
			break
	var way := Vector3(step.x, 0.0, step.y)
	var far_end := maze.world(start + step * 3)
	var holder := Node3D.new()
	world.add_child(holder)
	var herd := MazeMammoth.herd_of(4, 3)
	for k in herd.size():
		var one: MazeMammoth = herd[k]
		one.maze = maze
		one.targets = [boy]
		var round_about := TAU * k / herd.size()
		one.position = far_end + Vector3(cos(round_about), 0.0, sin(round_about)) * (3.5 if k > 0 else 0.0) + Vector3.UP * 0.05
		one.rotation.y = atan2(-way.x, -way.z) + randf_range(-0.6, 0.6)
		holder.add_child(one)
	var matriarch: MazeMammoth = herd[0]
	boy.global_position = far_end - way * 34.0 + Vector3.UP * 0.2
	await frames(150)
	var up := Vector3.UP
	var aside := way.cross(up).normalized()
	var eye: Vector3 = boy.global_position + up * 1.9 - way * 2.6 + aside * 0.7
	look(far_end + up * 1.6, eye - far_end - up * 1.6, null, 38.0)
	await shot("m01_herd_grazing_from_the_boy")
	look(far_end + up * 1.5, aside * 4.5 + up * 4.0 - way * 17.0, null, 42.0)
	await shot("m02_herd_grazing_side")
	boy.global_position = far_end - way * 22.0 + up * 0.2
	await frames(90)
	eye = boy.global_position + up * 1.9 - way * 2.6 + aside * 0.7
	look(far_end + up * 1.8, eye - far_end - up * 1.8, null, 40.0)
	await shot("m03_alarm_trunks_up")
	boy.global_position = far_end - way * 14.0 + up * 0.2
	for i in 200:
		await physics_frame
		if matriarch.mode == MazeMammoth.Mode.DISPLAY and matriarch.mammoth.trumpeting():
			break
	await frames(30)
	eye = boy.global_position + up * 1.9 - way * 2.6 + aside * 0.7
	look(matriarch.global_position + up * 2.2, eye - matriarch.global_position - up * 2.2, null, 46.0)
	await shot("m04_ring_and_display_from_the_boy")
	look(far_end + up * 1.6, aside * 2.0 + up * 16.0 - way * 14.0, null, 44.0)
	await shot("m05_ring_round_the_calf")
	for i in 300:
		await physics_frame
		if matriarch.mode == MazeMammoth.Mode.MOCK and matriarch._mode_time > 0.8:
			break
	look(matriarch.global_position + up * 1.8, aside * 4.5 + up * 3.0 - way * 15.0, null, 44.0)
	await shot("m06_mock_charge")
	# Stay on, nearer: the charge
	boy.global_position = far_end - way * 8.0 + up * 0.2
	for i in 600:
		await physics_frame
		if matriarch.mode == MazeMammoth.Mode.CHARGE and matriarch._mode_time > 0.6:
			break
	look(matriarch.global_position + up * 1.8, aside * 4.5 + up * 3.0 - way * 15.0, null, 46.0)
	await shot("m07_charge")
	print("matriarch: %s" % MazeMammoth.Mode.keys()[matriarch.mode])
	world.queue_free()
	await frames(3)


## A herd out on the desert ring's plains (a quarter that is plains: off the
## maze's grid, by sight and the ground alone), grazing; the boy coming up.
func _plains() -> void:
	if stage_root:
		stage_root.queue_free()
		stage_root = null
		await frames(2)
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 800.0
	var plan: RoundMaze = maze.round_rings
	if plan == null:
		print("no desert ring")
		return
	var side := Vector2.ZERO
	for way: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		if plan.desert.biome_of(Vector2i(way)) == DesertStyle.Biome.PLAINS:
			side = way
	if side == Vector2.ZERO:
		side = Vector2(-1, 0)
		print("no plains quarter: the west one")
	var middle2 := side * lerpf(plan.square_half, plan.inner_radius, 0.5)
	var middle := Vector3(middle2.x, 0.0, middle2.y)
	middle.y = maze.ground_height(middle)
	var holder := Node3D.new()
	world.add_child(holder)
	var herd := MazeMammoth.herd_of(5, 9)
	for k in herd.size():
		var one: MazeMammoth = herd[k]
		one.maze = maze
		one.targets = [boy]
		var round_about := TAU * k / herd.size()
		one.position = middle + Vector3(cos(round_about), 0.0, sin(round_about)) * (5.0 if k > 0 else 0.0) + Vector3.UP * 0.5
		one.rotation.y = randf_range(-PI, PI)
		holder.add_child(one)
	var toward := -Vector3(side.x, 0.0, side.y)
	boy.global_position = middle + toward * 45.0 + Vector3.UP * 1.0
	await frames(180)
	var up := Vector3.UP
	var aside := toward.cross(up).normalized()
	look(middle + up * 2.0, toward * 40.0 + up * 2.2 + aside * 6.0, null, 40.0)
	await shot("p01_plains_herd_grazing")
	look(middle + up * 1.5, -toward * 20.0 + up * 6.0 + aside * 18.0, null, 46.0)
	await shot("p02_plains_herd_close")
	boy.global_position = middle + toward * 20.0 + up * 0.5
	await frames(240)
	look(middle + up * 2.0, toward * 26.0 + up * 2.2 + aside * 4.0, null, 44.0)
	await shot("p03_plains_alarm")
	print("plains herd: %s, in the open %s" % [MazeMammoth.Mode.keys()[herd[0].herd_mode], herd[0].in_open])
	world.queue_free()
	await frames(3)
