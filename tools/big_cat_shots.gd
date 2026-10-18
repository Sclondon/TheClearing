extends SceneTree
## Pictures of the big cats (creatures/big_cat: the lynx and the panther): close
## up on a plain floor under the game's kind of light (each view, the head, the
## stalk, the crouch, the hiss, the swipe, the pounce, sitting, feeding, on a
## wall, at night), strips of frames from the side through a stride of the walk
## and of the gallop, and in a hall of a real round (the lynx watching from the
## ledge, the panther on it over the hall, from the boy's height). Says how many
## draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/big_cat_shots.gd -- <folder> [studio|poses|strips|maze|night|all] [lynx|panther|both]

var folder := "big_cat_shots"
var mode := "all"
var which := "both"
var camera: Camera3D
var stage_root: Node3D
var sun: DirectionalLight3D
var environment: Environment
var mover := Callable()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	if args.size() > 2:
		which = args[2]
	DirAccess.make_dir_recursive_absolute(folder)
	Engine.max_fps = 60
	_run.call_deferred()


func _kinds() -> Array:
	var kinds := []
	if which in ["lynx", "both"]:
		kinds.append(BigCat.Kind.LYNX)
	if which in ["panther", "both"]:
		kinds.append(BigCat.Kind.PANTHER)
	return kinds


func _name(kind: int) -> String:
	return "lynx" if kind == BigCat.Kind.LYNX else "panther"


func _run() -> void:
	if mode in ["studio", "all"]:
		for kind: int in _kinds():
			await _studio(kind)
	if mode in ["poses", "all"]:
		for kind: int in _kinds():
			await _poses(kind)
	if mode in ["strips", "all"]:
		for kind: int in _kinds():
			await _strips(kind)
	if mode in ["night", "all"]:
		for kind: int in _kinds():
			await _night(kind)
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
			mover.call(1.0 / 60.0)
		await process_frame


func look(target: Vector3, offset: Vector3, animal: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if animal:
		from = Basis(Vector3.UP, animal.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _stage() -> void:
	if stage_root:
		stage_root.queue_free()
		await process_frame
	stage_root = Node3D.new()
	root.add_child(stage_root)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	sun = DirectionalLight3D.new()
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


func _cat(kind: int) -> BigCat:
	var cat := BigCat.new()
	cat.kind = kind
	cat.sound = false
	stage_root.add_child(cat)
	return cat


# --- On a plain floor ---

func _studio(kind: int) -> void:
	await _stage()
	var cat := _cat(kind)
	await frames(20)
	var n := _name(kind)
	var long := 1.0 if kind == BigCat.Kind.LYNX else 1.3
	var middle := Vector3(0.0, 0.42, 0.0)
	var head := (cat.rig as BigCatRig)._head.global_position + Vector3(0.0, 0.02, 0.04)
	look(middle, Vector3(0.0, 0.25, 2.4 * long), cat)
	await shot(n + "_01_front")
	look(middle, Vector3(3.0 * long, 0.25, 0.0), cat)
	await shot(n + "_02_side")
	look(middle, Vector3(2.0 * long, 0.6, 1.9 * long), cat)
	await shot(n + "_03_three_quarter")
	look(middle, Vector3(-2.0 * long, 0.9, -2.0 * long), cat)
	await shot(n + "_04_back_quarter")
	look(head, Vector3(0.45, 0.06, 0.5), cat)
	await shot(n + "_05_head")
	look(head, Vector3(0.02, 0.04, 0.7), cat)
	await shot(n + "_06_head_front")
	look(head, Vector3(0.7, 0.03, 0.0), cat)
	await shot(n + "_07_head_side")


func _poses(kind: int) -> void:
	await _stage()
	var cat := _cat(kind)
	var n := _name(kind)
	var long := 1.0 if kind == BigCat.Kind.LYNX else 1.3
	var middle := Vector3(0.0, 0.35, 0.0)
	var target := Vector3(0.0, 0.4, 4.0)
	await frames(20)
	# The stalk: slow along, eyes on something ahead.
	cat.stalking = true
	cat.look_at_point = target
	var walked := {"t": 0.0}
	mover = func(delta: float) -> void:
		walked["t"] += delta
		cat.position.z = walked["t"] * 0.5
	await frames(80)
	look(cat.position + middle, Vector3(2.3 * long, 0.35, 0.6), cat)
	await shot(n + "_10_stalk")
	look(cat.position + middle, Vector3(1.0, 0.25, 2.2 * long), cat)
	await shot(n + "_11_stalk_front")
	mover = Callable()
	cat.freeze_step = true
	await frames(40)
	look(cat.position + middle, Vector3(2.3 * long, 0.3, 0.3), cat)
	await shot(n + "_12_stalk_frozen")
	cat.freeze_step = false
	cat.stalking = false
	# The crouch, then the wiggle and the pounce.
	cat.crouching = true
	await frames(50)
	look(cat.position + middle, Vector3(2.3 * long, 0.3, 0.8), cat)
	await shot(n + "_13_crouch")
	cat.pounce(cat.position + Vector3(0.0, 0.5, 3.5))
	await frames(25)
	look(cat.position + middle, Vector3(2.3 * long, 0.3, 0.8), cat)
	await shot(n + "_14_wiggle")
	cat.crouching = false
	var wait := 0
	while cat.wiggling() and wait < 120:
		await frames(1)
		wait += 1
	mover = func(delta: float) -> void:
		cat.position += cat.lunge_push() * delta
	await frames(10)
	look(cat.position + middle, Vector3(2.6 * long, 0.4, 0.0), cat)
	await shot(n + "_15_pounce")
	await frames(8)
	look(cat.position + middle, Vector3(2.6 * long, 0.4, 0.0), cat)
	await shot(n + "_16_pounce_late")
	await frames(40)
	mover = Callable()
	cat.position = Vector3.ZERO
	cat.settle()
	# The hiss.
	cat.look_at_point = Vector3(0.6, 0.6, 2.5)
	cat.hiss()
	await frames(14)
	look(cat.position + middle + Vector3(0.0, 0.1, 0.2), Vector3(1.2, 0.3, 1.6 * long), cat)
	await shot(n + "_17_hiss")
	look((cat.rig as BigCatRig)._head.global_position, Vector3(0.2, 0.05, 0.6), cat)
	await shot(n + "_18_hiss_head")
	await frames(60)
	# The swipe.
	cat.swipe(Vector3(0.4, 0.6, 1.6))
	await frames(int(BigCat.SWIPE_TIME * 0.38 * 60.0))
	look(cat.position + middle + Vector3(0.0, 0.1, 0.0), Vector3(1.8, 0.3, 1.5 * long), cat)
	await shot(n + "_19_swipe_up")
	await frames(int(BigCat.SWIPE_TIME * 0.16 * 60.0))
	look(cat.position + middle + Vector3(0.0, 0.1, 0.0), Vector3(1.8, 0.3, 1.5 * long), cat)
	await shot(n + "_20_swipe_strike")
	await frames(50)
	# Sitting, lying, feeding.
	cat.look_at_point = Vector3.INF
	cat.sitting = true
	await frames(90)
	look(cat.position + middle, Vector3(2.2 * long, 0.4, 1.2), cat)
	await shot(n + "_21_sit")
	cat.lying = true
	await frames(120)
	look(cat.position + middle, Vector3(2.2 * long, 0.6, 1.2), cat)
	await shot(n + "_22_lie")
	cat.lying = false
	cat.sitting = false
	cat.feeding = true
	await frames(80)
	look(cat.position + middle, Vector3(2.0 * long, 0.5, 1.4), cat)
	await shot(n + "_23_feed")
	cat.feeding = false
	await frames(40)
	# Climbing: turned up a wall (here, the air), bounding up.
	cat.climbing = true
	cat.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	cat.position = Vector3(0.0, 1.5, 0.0)
	cat.settle()
	var climbed := {"t": 0.0}
	mover = func(delta: float) -> void:
		climbed["t"] += delta
		cat.position.y = 1.5 + climbed["t"] * 2.4
	await frames(40)
	look(cat.position + Vector3(0.0, 0.0, 0.3), Vector3(2.6 * long, -0.3, -0.6), null)
	await shot(n + "_24_climb")
	mover = Callable()
	cat.climbing = false


func _strips(kind: int) -> void:
	await _stage()
	var cat := _cat(kind)
	var n := _name(kind)
	var long := 1.0 if kind == BigCat.Kind.LYNX else 1.3
	await frames(10)
	for gait: Array in [["walk", 1.1], ["stalk", 0.55], ["trot", 2.2], ["gallop", 8.0]]:
		var speed: float = gait[1]
		cat.stalking = gait[0] == "stalk"
		cat.position = Vector3.ZERO
		cat.settle()
		var at := {"t": 0.0}
		mover = func(delta: float) -> void:
			at["t"] += speed * delta
			cat.position = Vector3(0.0, 0.0, at["t"])
		await frames(90)
		for k in 6:
			look(cat.position + Vector3(0.0, 0.38, 0.0), Vector3(2.8 * long, 0.25, 0.0), null)
			camera.global_position = cat.position + Vector3(2.8 * long, 0.63, 0.0)
			await shot("%s_3%s_%s_%d" % [n, "0123"[["walk", "stalk", "trot", "gallop"].find(gait[0])], gait[0], k])
			await frames(3 if gait[0] == "gallop" else 6)
		mover = Callable()
	cat.stalking = false


func _night(kind: int) -> void:
	await _stage()
	var cat := _cat(kind)
	var n := _name(kind)
	environment.background_color = Color(0.03, 0.035, 0.05)
	environment.ambient_light_color = Color(0.2, 0.25, 0.35)
	environment.ambient_light_energy = 0.12
	sun.light_energy = 0.12
	sun.light_color = Color(0.6, 0.7, 0.9)
	cat.set_eyeshine(2.6)
	cat.look_at_point = Vector3(0.0, 0.5, 6.0)
	await frames(30)
	look(Vector3(0.0, 0.45, 0.4), Vector3(0.3, 0.15, 6.0), cat)
	await shot(n + "_40_night")
	look(Vector3(0.0, 0.45, 0.4), Vector3(0.1, 0.1, 14.0), cat, 30.0)
	await shot(n + "_41_night_far")


# --- In a round of the game ---

func _maze() -> void:
	if stage_root:
		stage_root.queue_free()
		stage_root = null
		await process_frame
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("TEST", 1), 0, [{"slot": 0, "look": "p11"}], false)
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
	var up := Vector3.UP
	var start := nav.point(best)
	boy.global_position = start
	boy.rotation.y = atan2(way.x, way.z)
	# A lynx on the ledge over the hall ahead, watching him.
	var lynx := MazeLynx.new()
	lynx.maze = maze
	lynx.targets = [boy]
	lynx.position = start + way * 22.0
	world.add_child(lynx)
	await frames(10)
	lynx.set_physics_process(false)
	lynx.mode = MazeCat.Mode.WATCH
	lynx._point = boy.global_position + up * 1.0
	lynx._prev_pos = lynx.global_position
	lynx._curr_pos = lynx.global_position
	var to_boy := boy.global_position - lynx.global_position
	lynx.facing_yaw = atan2(to_boy.x, to_boy.z)
	await frames(60)
	print("lynx on ledge: %s (%.1f m up)" % [lynx.place == MazeCat.Place.LEDGE, lynx.global_position.y])
	camera.fov = 50.0
	camera.global_position = start + up * 1.3
	camera.look_at(lynx.global_position + up * 0.3, up)
	await shot("m01_lynx_on_the_ledge")
	camera.fov = 16.0
	await shot("m02_lynx_on_the_ledge_zoom")
	lynx.queue_free()
	# A panther on the ledge over him, at night: its eyes.
	world.get(&"day").call(&"set_hour", 23.0)
	var panther := MazePanther.new()
	panther.maze = maze
	panther.targets = [boy]
	panther.position = start + way * 10.0
	world.add_child(panther)
	await frames(10)
	panther.set_physics_process(false)
	panther.mode = MazeCat.Mode.HESITATE
	panther._point = boy.global_position + up * 1.0
	panther._prev_pos = panther.global_position
	panther._curr_pos = panther.global_position
	to_boy = boy.global_position - panther.global_position
	panther.facing_yaw = atan2(to_boy.x, to_boy.z)
	await frames(90)
	camera.fov = 55.0
	camera.global_position = start + up * 1.3
	camera.look_at(panther.global_position + up * 0.3, up)
	await shot("m03_panther_above_at_night")
	camera.fov = 18.0
	await shot("m04_panther_above_at_night_zoom")
	# By day, on the ground behind him, stalking.
	world.get(&"day").call(&"set_hour", 11.0)
	panther.place = MazeCat.Place.GROUND
	boy.global_position = start + way * 12.0
	var behind := start + way * 4.0
	panther.global_position = Vector3(behind.x, maze.ground_height(behind), behind.z)
	panther._prev_pos = panther.global_position
	panther._curr_pos = panther.global_position
	panther.facing_yaw = atan2(way.x, way.z)
	panther.mode = MazeCat.Mode.STALK
	panther.cat.settle()
	var crept := {"t": 0.0}
	mover = func(delta: float) -> void:
		crept["t"] += delta * 0.8
		var at: Vector3 = behind + way * float(crept["t"])
		panther._prev_pos = at
		panther._curr_pos = at
	await frames(90)
	camera.fov = 50.0
	camera.global_position = start + way * 17.0 + up * 1.7 + Vector3(-way.z, 0.0, way.x) * 1.2
	camera.look_at(start + way * 8.0 + up * 0.6, up)
	await shot("m05_panther_stalking_behind_him")
	mover = Callable()
	# Faced: it hesitates, crouched, tail lashing.
	panther.mode = MazeCat.Mode.HESITATE
	await frames(60)
	camera.fov = 40.0
	camera.global_position = panther.global_position + way * 5.0 + up * 1.2
	camera.look_at(panther.global_position + up * 0.4, up)
	await shot("m06_panther_hesitating")
	# The pounce, from the side.
	panther.mode = MazeCat.Mode.POUNCE
	panther.cat.pounce(panther.global_position + way * 4.0 + up * 0.5)
	await frames(int(BigCat.WIGGLE_TIME * 60.0) + 14)
	camera.global_position = panther.global_position + Vector3(-way.z, 0.0, way.x) * 4.5 + up * 1.0 + way * 1.5
	camera.look_at(panther.global_position + way * 1.5 + up * 0.6, up)
	await shot("m07_panther_pounce")
	panther.queue_free()
	await frames(5)
