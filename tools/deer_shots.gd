extends SceneTree
## Pictures of the deer and the elk (creatures/deer, creatures/elk): close up
## on a plain floor under the game's kind of light (each view, the head, every
## gait and move, and frame strips of a gallop stride and a pronk from the
## side, with time stepped by hand), and in a passage of a real round (the herd
## watching in the mist from the boy's height, the stampede, the elk bugling,
## pawing and charging). Says how many draws a frame takes. Needs a real window
## (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/deer_shots.gd -- <folder> [studio|strips|maze|all]

const STEP := 1.0 / 60.0

var folder := "deer_shots"
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
	if mode in ["clearing", "all"]:
		await _clearing()
	quit()


## The peaceful herds (Wildlife) out in the clearing: grazing, seen from the
## boy's height; watching him come; and running off.
func _clearing() -> void:
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
	var life: Wildlife = world.wildlife
	var up := Vector3.UP
	var n := 0
	for herd: Wildlife.Herd in life.herds:
		if not herd.clearing:
			continue
		n += 1
		var middle := herd.middle()
		var toward := Vector3(-middle.x, 0.0, -middle.z).normalized().rotated(Vector3.UP, 0.4)
		var stand := middle + toward * 42.0
		stand.y = maze.ground_height(stand)
		boy.global_position = stand + up * 0.2
		await frames(120)
		var eye := boy.global_position + up * 1.15 - toward * 1.0
		var target := herd.middle() + up * 0.8
		look(target, eye - target, null, 34.0)
		await shot("c%d1_%s_grazing_from_the_boy" % [n, "deer" if herd.kind == Wildlife.Kind.DEER else "elk"])
		stand = middle + toward * 26.0
		stand.y = maze.ground_height(stand)
		boy.global_position = stand + up * 0.2
		await frames(90)
		eye = boy.global_position + up * 1.15 - toward * 1.0
		target = herd.middle() + up * 0.9
		look(target, eye - target, null, 34.0)
		await shot("c%d2_%s_watching_him" % [n, "deer" if herd.kind == Wildlife.Kind.DEER else "elk"])
		stand = middle + toward * 10.0
		stand.y = maze.ground_height(stand)
		boy.global_position = stand + up * 0.2
		await frames(50)
		eye = boy.global_position + up * 1.15 - toward * 1.0
		target = herd.middle() + up * 0.9
		look(target, eye - target, null, 44.0)
		await shot("c%d3_%s_running_off" % [n, "deer" if herd.kind == Wildlife.Kind.DEER else "elk"])
		await frames(60)
		target = herd.middle() + up * 0.9
		var aside := toward.cross(up).normalized()
		look(target, aside * 22.0 + up * 1.0, null, 36.0)
		await shot("c%d4_%s_running_side" % [n, "deer" if herd.kind == Wildlife.Kind.DEER else "elk"])


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


## Looks at `target` from `offset` away (in the animal's own space, if `who` is given).
func look(target: Vector3, offset: Vector3, who: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if who:
		from = Basis(Vector3.UP, who.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _floor_stage() -> void:
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


func _studio() -> void:
	_floor_stage()
	var doe := Deer.new()
	doe.sound = false
	stage_root.add_child(doe)
	await frames(20)
	var middle := Vector3(0.0, 0.85, 0.0)
	look(middle, Vector3(0.0, 0.3, 4.6), doe)
	await shot("s01_doe_front")
	look(middle, Vector3(5.6, 0.2, 0.0), doe)
	await shot("s02_doe_side")
	look(middle, Vector3(3.6, 0.6, 3.6), doe)
	await shot("s03_doe_three_quarter")
	look(middle, Vector3(-3.4, 1.2, -3.6), doe)
	await shot("s04_doe_back_quarter")
	var head := doe.nose_position().lerp(doe.global_position + Vector3(0.0, 1.25, 0.45), 0.6)
	look(head, Vector3(0.55, 0.12, 0.75), doe)
	await shot("s05_doe_head")
	look(head, Vector3(0.0, 0.05, 0.95), doe)
	await shot("s06_doe_face")
	doe.queue_free()

	var buck := Deer.new()
	buck.variant = Deer.Variant.BUCK
	buck.sound = false
	stage_root.add_child(buck)
	await frames(20)
	look(Vector3(0.0, 0.95, 0.0), Vector3(3.8, 0.6, 3.4), buck)
	await shot("s07_buck_three_quarter")
	look(buck.nose_position() + Vector3(0.0, 0.12, -0.15), Vector3(0.7, 0.2, 0.9), buck)
	await shot("s08_buck_head")
	buck.queue_free()

	var elk := Elk.new()
	elk.sound = false
	stage_root.add_child(elk)
	var boy := _boy_stand_in()
	boy.position = Vector3(1.6, 0.0, 0.6)
	stage_root.add_child(boy)
	await frames(30)
	look(Vector3(0.0, 1.5, 0.0), Vector3(8.6, 0.4, 0.5), elk)
	await shot("s10_elk_side_with_boy")
	look(Vector3(0.0, 1.6, 0.0), Vector3(5.8, 1.0, 5.4), elk)
	await shot("s11_elk_three_quarter")
	look(Vector3(0.0, 1.7, 0.0), Vector3(0.2, 0.5, 7.5), elk)
	await shot("s12_elk_front")
	look(elk.nose_position() + Vector3(0.0, 0.2, -0.3), Vector3(1.2, 0.3, 1.6), elk)
	await shot("s13_elk_head")
	boy.queue_free()
	# Moves, stepped by hand
	elk.bugle()
	await frames(2)
	elk.rig.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 70:
		elk.rig._process(STEP)
		elk._process(STEP)
	elk.rig.process_mode = Node.PROCESS_MODE_INHERIT
	look(Vector3(0.0, 2.0, 0.6), Vector3(6.0, 0.3, 2.8), elk)
	await shot("s14_elk_bugle")
	await frames(200)
	elk.pawing = true
	elk.lowered = false
	await frames(70)
	look(Vector3(0.0, 1.3, 0.4), Vector3(6.4, 0.4, 1.6), elk)
	await shot("s15_elk_pawing")
	elk.pawing = false
	elk.lowered = true
	await frames(50)
	look(Vector3(0.0, 1.4, 0.6), Vector3(4.0, 0.2, 6.0), elk)
	await shot("s16_elk_lowered")
	look(Vector3(0.0, 1.4, 0.6), Vector3(7.0, 0.3, 0.2), elk)
	await shot("s17_elk_lowered_side")
	drive(elk, 9.0, 1.4)
	elk.rig.process_mode = Node.PROCESS_MODE_INHERIT
	look(elk.global_position + Vector3(0.0, 1.4, 0.4), Vector3(8.0, 0.4, 0.6), elk)
	await shot("s18_elk_charge_side")
	look(elk.global_position + Vector3(0.0, 1.3, 0.4), Vector3(1.5, 0.4, 9.0), elk)
	await shot("s19_elk_charge_front")
	elk.queue_free()

	# The doe's moods
	var deer := Deer.new()
	deer.sound = false
	stage_root.add_child(deer)
	await frames(10)
	deer.grazing = true
	await frames(90)
	look(Vector3(0.0, 0.6, 0.2), Vector3(3.6, 0.3, 2.2), deer)
	await shot("s20_graze")
	deer.grazing = false
	deer.alert = true
	deer.flagging = false
	deer.look_at_point = deer.global_position + Vector3(3.0, 1.2, 4.0)
	await frames(60)
	look(Vector3(0.0, 1.0, 0.2), Vector3(3.0, 0.2, 3.6), deer)
	await shot("s21_alert")
	deer.stamp()
	await frames(9)
	await shot("s22_stamp")
	deer.flagging = true
	await frames(30)
	look(Vector3(0.0, 0.9, -0.2), Vector3(-3.0, 0.4, -3.8), deer)
	await shot("s23_flag")
	deer.alert = false
	deer.queue_free()
	var odd := Deer.new()
	odd.sound = false
	odd.wrong = 1.0
	stage_root.add_child(odd)
	var plain := Deer.new()
	plain.sound = false
	plain.position = Vector3(1.4, 0.0, -0.8)
	stage_root.add_child(plain)
	await frames(10)
	for one: Deer in [odd, plain]:
		one.alert = true
		one.look_at_point = Vector3(0.0, 1.0, -8.0)
	await frames(70)
	look(Vector3(0.7, 0.9, -0.4), Vector3(0.6, 0.3, 5.2))
	await shot("s24_wrong_one_looking_behind")
	odd.upright = true
	odd.look_at_point = Vector3(0.0, 1.2, 6.0)
	await frames(120)
	look(Vector3(0.7, 1.0, -0.4), Vector3(4.6, 0.3, 3.4))
	await shot("s25_wrong_one_upright")
	stage_root.queue_free()
	await frames(4)


## A stand-in for the boy, his size: for scale.
func _boy_stand_in() -> Node3D:
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	return boy


## Frame strips, from the side: a gallop stride, a walk, a trot and a pronk, time stepped by hand.
func _strips() -> void:
	_floor_stage()
	var deer := Deer.new()
	deer.sound = false
	stage_root.add_child(deer)
	await frames(10)
	await _strip(deer, 9.0, "t01_gallop_strip", 0.0)
	await _strip(deer, 1.2, "t02_walk_strip", 0.0)
	await _strip(deer, 2.8, "t03_trot_strip", 0.0)
	deer.pronking = true
	deer.flagging = true
	await _strip(deer, 2.2, "t04_pronk_strip", PRONK_SPAN)
	deer.pronking = false
	deer.flagging = false
	deer.queue_free()
	var elk := Elk.new()
	elk.sound = false
	stage_root.add_child(elk)
	await frames(10)
	elk.lowered = true
	await _strip(elk, 10.0, "t05_elk_charge_strip", 0.0)
	stage_root.queue_free()
	await frames(4)


const PRONK_SPAN := 0.62


## Eight pictures through one stride (or `span` seconds), side on, put together in a grid of 4 by 2.
func _strip(who: Deer, speed: float, name: String, span: float) -> void:
	who.global_position = Vector3.ZERO
	who.settle()
	await frames(2)
	drive(who, speed, 2.5)
	var stride: float = DeerRig._keyed(DeerRig.STRIDE, speed / who.rig._size) * who.rig._size
	var seconds := span if span > 0.0 else stride / speed
	var sheet := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	var size := who.rig._size
	for k in 8:
		drive(who, speed, seconds / 8.0)
		look(who.global_position + Vector3(0.0, 0.75 * size, 0.0), Vector3(5.0 * size, 0.15 * size, 0.0), who, 34.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(160, 0, 320, 360), Vector2i((k % 4) * 320, (k / 4) * 360))
	# (each tile is the middle half of a frame)
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])
	who.rig.process_mode = Node.PROCESS_MODE_INHERIT
	who.measure_velocity = true


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
	# The herd stands at the far end of the hall, all watching him.
	var herd: Array[Deer] = []
	var far := start + way * minf(best_run * Maze.CELL - 8.0, 46.0)
	var spots := [Vector3(0.0, 0.0, 0.0), Vector3(1.6, 0.0, 1.2), Vector3(-1.8, 0.0, 0.9), Vector3(0.8, 0.0, 2.6), Vector3(-0.6, 0.0, -1.4)]
	for i in 5:
		var one := Deer.new()
		one.sound = false
		one.variant = Deer.Variant.BUCK if i == 1 else Deer.Variant.DOE
		one.wrong = 1.0 if i == 3 else 0.0
		one.coat_tint = [Color.WHITE, Color(1.05, 1.0, 0.95), Color(0.92, 0.92, 0.92), Color(0.97, 0.95, 0.93), Color(1.04, 0.98, 0.92)][i]
		world.add_child(one)
		one.global_position = far + side * spots[i].x + way * spots[i].z
		one.global_position.y = maze.ground_height(one.global_position)
		one.rotation.y = atan2(-way.x, -way.z) + [0.5, -0.9, 1.2, 2.6, -0.3][i]
		herd.append(one)
	boy.global_position = start + way * 4.0
	await frames(30)
	var eye := boy.global_position + up * 1.05
	for one in herd:
		one.alert = true
		one.look_at_point = eye
	await frames(80)
	look(far + up * 0.9, eye - (far + up * 0.9), null, 40.0)
	await shot("m01_herd_watching_from_the_boy")
	look(far + up * 0.9, (eye - far).normalized() * 16.0 + up * 0.3, null, 34.0)
	await shot("m02_herd_watching_closer")
	# The wrong one, nearer, standing up
	herd[3].upright = true
	await frames(120)
	look(herd[3].global_position + up * 1.1, (eye - herd[3].global_position).normalized() * 7.0 + up * 0.2, null, 36.0)
	await shot("m03_the_wrong_one")
	herd[3].upright = false
	# They bolt: stamp, flag, pronk, then the stampede down the hall at him
	herd[0].stamp()
	for one in herd:
		one.flagging = true
	await frames(25)
	for one in herd:
		one.alert = false
		one.pronking = true
		one.rotation.y = atan2(-way.x, -way.z)
	for i in 50:
		for one in herd:
			one.global_position -= way * 2.4 / 60.0
		await process_frame
	look(herd[0].global_position + up * 0.9, side * 9.0 + up * 0.5, null, 40.0)
	await shot("m04_pronking")
	for one in herd:
		one.pronking = false
		one.fleeing = true
	for i in 90:
		for k in herd.size():
			herd[k].global_position -= way * (8.0 + k * 0.15) / 60.0
		await process_frame
	var lead := herd[0].global_position
	look(lead + up * 0.8, (boy.global_position + up * 1.2 - lead).normalized() * 9.0 + up * 0.5, null, 46.0)
	await shot("m05_stampede_at_him")
	look(lead + up * 0.8, side * 8.0 + up * 0.6, null, 40.0)
	await shot("m06_stampede_side")
	for one in herd:
		one.queue_free()
	# The elk in the hall: bugling, pawing, charging
	var elk := Elk.new()
	elk.sound = false
	world.add_child(elk)
	elk.global_position = far
	elk.global_position.y = maze.ground_height(far)
	elk.rotation.y = atan2(-way.x, -way.z)
	boy.global_position = far - way * 14.0
	await frames(30)
	elk.look_at_point = boy.global_position + up * 1.0
	elk.bugle()
	await frames(80)
	look(elk.global_position + up * 2.0, (boy.global_position - elk.global_position).normalized() * 13.0 + up * 0.0 + side * 2.0, null, 40.0)
	await shot("m07_elk_bugle_from_the_boy")
	await frames(140)
	elk.pawing = true
	elk.lowered = true
	await frames(60)
	look(elk.global_position + up * 1.5, side * 8.0 + up * 0.4 - way * 2.0, null, 40.0)
	await shot("m08_elk_pawing")
	elk.pawing = false
	for i in 60:
		elk.global_position -= way * 9.5 / 60.0
		await process_frame
	look(elk.global_position + up * 1.4, (boy.global_position + up * 1.1 - elk.global_position).normalized() * 6.0 + up * 0.2, null, 50.0)
	await shot("m09_elk_charge_at_him")
	elk.queue_free()
