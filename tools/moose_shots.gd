extends SceneTree
## Pictures of the moose (creatures/moose): close up on a plain floor under the
## game's kind of light (each view, the head, every move: browsing, the
## warning with its hackles up and a lick of the lips, the charge, the strike,
## the call, a cow and her calf, wading), frame strips of its trot from the
## side (time stepped by hand), and in a hall of a real round (MazeMoose: at its
## wallow, warning the boy, charging, striking him down). Says how many draws a
## frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/moose_shots.gd -- <folder> [studio|strips|maze|all]

const STEP := 1.0 / 60.0

var folder := "moose_shots"
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
func drive(who: Deer, speed: float, seconds: float) -> void:
	who.measure_velocity = false
	who.rig.process_mode = Node.PROCESS_MODE_DISABLED
	var forward := who.global_basis.z.normalized()
	who.velocity = forward * speed
	for i in int(seconds / STEP):
		who.global_position += forward * speed * STEP
		who.rig._process(STEP)
		who._process(STEP)


func _boy() -> Node3D:
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	return boy


func _studio() -> void:
	await _floor_stage()
	var bull := Moose.new()
	bull.sound = false
	stage_root.add_child(bull)
	var boy := _boy()
	boy.global_position = Vector3(1.6, 0.0, 1.8)
	await frames(30)
	var middle := Vector3(0.0, 1.35, 0.0)
	look(middle, Vector3(7.4, 0.3, 0.0), bull)
	await shot("s01_bull_side_with_boy")
	boy.global_position = Vector3(40.0, 0.0, 40.0)
	look(middle, Vector3(5.0, 0.9, 5.2), bull)
	await shot("s02_bull_three_quarter")
	look(middle + Vector3(0.0, 0.3, 0.0), Vector3(0.0, 0.4, 7.0), bull)
	await shot("s03_bull_front")
	look(middle, Vector3(-4.8, 1.8, -5.0), bull)
	await shot("s04_bull_back_quarter")
	var head := bull.nose_position().lerp(bull.global_position + Vector3(0.0, 2.0, 1.0), 0.45)
	look(head, Vector3(1.4, 0.25, 1.6), bull)
	await shot("s05_bull_head")
	look(head, Vector3(-0.2, 0.1, 2.2), bull)
	await shot("s06_bull_face")
	# Browsing: up into the branches
	bull.browsing = true
	await frames(90)
	look(middle + Vector3(0.0, 0.3, 0.0), Vector3(6.0, 0.6, 2.5), bull)
	await shot("s07_browsing")
	bull.browsing = false
	# The warning: ears back, hackles up, head low, staring; a lick of the lips
	bull.look_at_point = Vector3(0.0, 1.2, 8.0)
	bull.bristling = true
	await frames(70)
	look(middle, Vector3(4.6, 0.5, 4.2), bull)
	await shot("s08_bristling")
	bull.lick()
	await frames(int(Moose.LICK_TIME * 0.45 * 60.0))
	look(bull.nose_position() + Vector3(0.0, 0.25, 0.0), Vector3(1.3, 0.2, 1.4), bull)
	await shot("s09_licking_its_lips")
	look(middle + Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.2, 6.0), bull)
	await frames(20)
	await shot("s10_bristling_front_from_the_boy")
	# Its call
	bull.bristling = false
	bull.bugle()
	await frames(25)
	look(middle, Vector3(5.5, 0.4, 2.5), bull)
	await shot("s11_call")
	await frames(60)
	# The strike: up on its hind legs
	bull.look_at_point = Vector3(0.0, 0.5, 6.0)
	bull.strike()
	await frames(int(Moose.STRIKE_TIME * 0.5 * 60.0))
	look(middle + Vector3(0.0, 0.5, 0.0), Vector3(6.8, 0.6, 1.0), bull)
	await shot("s12_strike_reared")
	await frames(int((Moose.STRIKE_LANDS - Moose.STRIKE_TIME * 0.5) * 60.0) + 2)
	await shot("s13_strike_down")
	await frames(60)
	# Lowered, as it charges
	bull.lowered = true
	await frames(50)
	look(middle, Vector3(4.6, 0.4, 4.6), bull)
	await shot("s14_lowered")
	bull.lowered = false
	bull.look_at_point = Vector3.INF
	await frames(30)
	bull.queue_free()

	# A cow and her calf
	var cow := Moose.new()
	cow.cow = true
	cow.sound = false
	stage_root.add_child(cow)
	var calf := Moose.new()
	calf.calf = true
	calf.sound = false
	calf.scale = Vector3.ONE * 0.55
	calf.position = Vector3(1.4, 0.0, 1.2)
	calf.rotation.y = 0.5
	stage_root.add_child(calf)
	await frames(30)
	look(Vector3(0.6, 1.1, 0.4), Vector3(6.5, 0.8, 4.0), cow)
	await shot("s15_cow_and_calf")
	var cow_head := cow.nose_position().lerp(cow.global_position + Vector3(0.0, 1.8, 0.9), 0.45)
	look(cow_head, Vector3(1.3, 0.25, 1.5), cow)
	await shot("s16_cow_head")
	cow.bugle()
	await frames(40)
	look(Vector3(0.6, 1.2, 0.4), Vector3(5.5, 0.8, 3.0), cow)
	await shot("s17_cow_moaning")
	# Wading
	cow.wading = 0.55
	calf.wading = 0.3
	cow.browsing = false
	cow.grazing = true
	await frames(60)
	look(Vector3(0.6, 0.9, 0.4), Vector3(6.0, 0.5, 4.0), cow)
	await shot("s18_wading_feeding")
	cow.queue_free()
	calf.queue_free()
	await frames(5)


## Its trot from the side, as a strip of frames; and a walk.
func _strips() -> void:
	await _floor_stage()
	for gait: Array in [["walk", 1.5], ["trot", 4.5], ["charge", 6.6]]:
		var bull := Moose.new()
		bull.sound = false
		bull.rotation.y = PI * 0.5
		stage_root.add_child(bull)
		await frames(5)
		bull.lowered = gait[0] == "charge"
		drive(bull, gait[1], 2.5)
		for k in 6:
			drive(bull, gait[1], 0.1)
			look(bull.global_position + Vector3(0.0, 1.3, 0.0), Vector3(0.0, 0.3, -8.0), null, 34.0)
			camera.global_position = bull.global_position + Vector3(0.0, 1.3, -8.0)
			camera.look_at(bull.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
			await shot("t_%s_%d" % [gait[0], k])
		bull.queue_free()
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
	# A long straight hall
	var start := Vector2i(-1, -1)
	var step := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in Maze.STEPS:
			var at := cell
			var run := 0
			while run < 4 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run == 4:
				start = cell
				step = s
				break
		if step != Vector2i.ZERO:
			break
	var way := Vector3(step.x, 0.0, step.y)
	var far_end := maze.world(start + step * 3)
	var holder := Node3D.new()
	world.add_child(holder)
	var bull := MazeMoose.new()
	bull.maze = maze
	bull.rut = 1.0
	bull.position = far_end + Vector3.UP * 0.05
	bull.rotation.y = atan2(-way.x, -way.z)
	bull.targets = [boy]
	holder.add_child(bull)
	boy.global_position = maze.world(start) - way * 6.0 + Vector3.UP * 0.2
	await frames(120)
	var up := Vector3.UP
	var eye: Vector3 = boy.global_position + up * 1.9 - way * 2.6 + way.cross(up).normalized() * 0.7
	look(bull.global_position + up * 1.4, eye - bull.global_position - up * 1.4, null, 36.0)
	await shot("m01_at_its_wallow_down_the_hall")
	boy.global_position = bull.global_position - way * 15.0 + up * 0.2
	await frames(40)
	eye = boy.global_position + up * 1.9 - way * 2.6 + way.cross(up).normalized() * 0.7
	look(bull.global_position + up * 1.3, eye - bull.global_position - up * 1.3, null, 34.0)
	await shot("m02_warning_from_the_boy")
	var aside := way.cross(up).normalized()
	look(bull.global_position + up * 1.3, aside * 9.0 + up * 1.2 - way * 3.0, null, 40.0)
	await shot("m03_warning_side")
	var charged := false
	for i in 300:
		await physics_frame
		if bull.mode == MazeMoose.Mode.CHARGE:
			charged = true
			break
	await frames(20)
	look(bull.global_position + up * 1.3, aside * 10.0 + up * 1.5, null, 42.0)
	await shot("m04_charge")
	for i in 240:
		await physics_frame
		if bull.mode == MazeMoose.Mode.STRIKE and bull.moose.strike_progress() > 0.35:
			break
	look(bull.global_position + up * 1.4, aside * 8.0 + up * 1.4 - way * 2.0, null, 42.0)
	await shot("m05_strike")
	print("charged: %s, mode %s" % [charged, MazeMoose.Mode.keys()[bull.mode]])
	world.queue_free()
	await frames(3)
