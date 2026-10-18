extends SceneTree
## Pictures of the frogs (creatures/frog): the giant toad close up on a plain
## floor under the game's kind of light (each view, the head, mid-leap, the
## tongue's wind-up and shot, a croak), the swarm (sitting, pouring out,
## mid-hop, clinging to a post), and both in a passage of a real round (the
## toad in its dead end, leaping at the boy, its tongue shot at him; the swarm
## pouring down a hall at him). Says how many draws a frame takes. Needs a real
## window (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/frog_shots.gd -- <folder> [toad|swarm|maze|all]

var folder := "frog_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D
## Whatever is moving things along, called every frame while a picture is taken too.
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
	if mode in ["toad", "all"]:
		await _toad()
	if mode in ["swarm", "all"]:
		await _swarm()
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


## Looks at `target` from `offset` away (in `thing`'s own space, if it is given).
func look(target: Vector3, offset: Vector3, thing: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if thing:
		from = Basis(Vector3.UP, thing.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func studio() -> void:
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
	ground.albedo_color = Color(0.42, 0.4, 0.36)
	floor.material_override = ground
	stage_root.add_child(floor)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	stage_root.add_child(body)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


# --- The toad ---

func _toad() -> void:
	studio()
	var toad := GiantToad.new()
	toad.voice = false
	toad.scale = Vector3.ONE * 2.8
	stage_root.add_child(toad)
	await frames(20)
	var middle := Vector3(0.0, 0.75, 0.1)
	var head := Vector3(0.0, 1.05, 0.95)
	look(middle, Vector3(0.0, 0.6, 7.5), toad)
	await shot("t01_front")
	look(middle, Vector3(8.0, 0.5, 0.0), toad)
	await shot("t02_side")
	look(middle, Vector3(5.4, 1.6, 5.2), toad)
	await shot("t03_three_quarter")
	look(middle, Vector3(-5.0, 3.0, -5.0), toad)
	await shot("t04_back_quarter")
	look(head, Vector3(1.6, 0.5, 2.0), toad)
	await shot("t05_head")
	look(head + Vector3(0.0, 0.1, 0.0), Vector3(0.35, 0.2, 2.0), toad)
	await shot("t06_face")
	# A croak
	toad.croak(3)
	await frames(14)
	look(middle, Vector3(4.2, 0.3, 4.6), toad)
	await shot("t07_croak")
	await frames(90)

	# The leap, frame by frame (along +Z)
	toad.settle()
	var start := toad.global_position
	var to := start + Vector3(0.0, 0.0, 6.0)
	toad.leap(to)
	var watch := start + Vector3(0.0, 1.2, 3.0)
	var times := [0.25, 0.42, 0.62, 0.85, 1.05, 1.32]
	var names := ["crouch", "spring", "rising", "top", "coming_down", "landing"]
	var taken := 0
	var clock := 0.0
	while taken < times.size() and clock < 3.0:
		var step := root.get_process_delta_time()
		toad.global_position += toad.leap_push() * step
		toad.global_position.y = maxf(toad.global_position.y, 0.0)
		clock += step
		if clock >= times[taken]:
			look(watch, Vector3(15.0, 0.8, 0.0), null, 45.0)
			await shot("t1%d_leap_%s" % [taken, names[taken]])
			look(toad.global_position + Vector3(0.0, 0.8, 0.0), Vector3(4.5, 1.2, 4.5))
			await shot("t1%d_leap_%s_near" % [taken, names[taken]])
			taken += 1
		await process_frame
	await frames(60)
	toad.global_position = Vector3.ZERO
	toad.settle()
	await frames(10)

	# The tongue: wind-up, and out at a post 7 m off
	var post := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	post.mesh = capsule
	post.position = Vector3(0.0, 0.85, 7.5)
	stage_root.add_child(post)
	toad.strike(Vector3(0.0, 1.25, 7.5))
	await until(func() -> bool: return toad.windup_progress() > 0.45)
	look(head, Vector3(3.2, 0.3, 2.6), toad)
	await shot("t20_windup_throat")
	await until(func() -> bool: return toad.windup_progress() > 0.9)
	look(head, Vector3(3.2, 0.3, 2.6), toad)
	await shot("t21_windup_gape")
	await until(func() -> bool: return toad.tongue_stage() == GiantToad.Tongue.HOLD)
	look(Vector3(0.0, 1.1, 3.6), Vector3(13.0, 1.2, 0.0), null, 40.0)
	await shot("t22_tongue_side")
	look(Vector3(0.0, 1.0, 3.5), Vector3(-3.2, 1.6, -7.5))
	await shot("t23_tongue_quarter")
	look(Vector3(0.0, 1.0, 2.5), Vector3(2.2, 0.8, 8.5))
	await shot("t24_tongue_front")
	await until(func() -> bool: return toad.tongue_stage() == GiantToad.Tongue.BACK and toad._length < 4.0)
	await shot("t25_tongue_back")
	post.queue_free()
	await frames(60)

	# Crawling (turning on the spot, and slowly forward)
	for i in 50:
		toad.rotation.y += 0.02
		await process_frame
	look(middle, Vector3(5.0, 1.2, 5.0), toad)
	await shot("t30_crawl")
	stage_root.queue_free()
	await frames(4)


# --- The swarm ---

func _swarm() -> void:
	studio()
	var swarm := FrogSwarm.new()
	swarm.voice = false
	swarm.count = 70
	stage_root.add_child(swarm)
	# Someone for them to go after: a post that walks slowly away, then stands.
	var post := CharacterBody3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	body.mesh = capsule
	body.position.y = 0.85
	post.add_child(body)
	stage_root.add_child(post)
	post.global_position = Vector3(0.0, 0.0, 9.0)
	swarm.target = post
	await frames(20)
	# The lurkers about the pool, close
	look(Vector3(0.0, 0.1, 0.0), Vector3(1.2, 1.3, 3.2))
	await shot("s01_pool_lurkers")
	look(swarm.frog_position(0) + Vector3(0.0, 0.05, 0.0), Vector3(0.35, 0.18, 0.55), null, 35.0)
	await shot("s02_frog_close")
	look(swarm.frog_position(1) + Vector3(0.0, 0.05, 0.0), Vector3(-0.6, 0.12, 0.1), null, 35.0)
	await shot("s03_frog_side")
	swarm.chasing = true
	await until(func() -> bool: return swarm.out > 30)
	look(Vector3(0.0, 0.2, 2.0), Vector3(5.0, 3.0, -1.0))
	await shot("s04_pouring_out")
	await until(func() -> bool: return swarm.front().z > 4.5)
	look(swarm.front() + Vector3(0.0, 0.2, -1.5), Vector3(4.5, 1.6, 3.0))
	await shot("s05_wave")
	look(swarm.front() + Vector3(0.0, 0.2, -1.0), Vector3(0.0, 0.5, 3.5))
	await shot("s06_wave_from_him")
	# a frog mid-hop, close
	for i in swarm.count:
		if swarm.frog_state(i) == FrogSwarm.HOP:
			look(swarm.frog_position(i), Vector3(1.4, 0.3, 0.2), null, 35.0)
			await shot("s07_mid_hop")
			break
	await until(func() -> bool: return swarm.on_target > 6, 8.0)
	look(post.global_position + Vector3(0.0, 0.8, 0.0), Vector3(2.2, 0.6, 2.6))
	await shot("s08_clinging")
	look(post.global_position + Vector3(0.0, 0.6, 0.0), Vector3(-3.0, 1.6, -5.0))
	await shot("s09_clinging_back")
	print("on him: %d, out: %d" % [swarm.on_target, swarm.out])
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
	# Everything else that hunts is put away, for clear pictures.
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	# A long straight hall
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

	# --- The toad ---
	var toad := GiantToad.new()
	toad.voice = false
	toad.scale = Vector3.ONE * MazeFrog.SIZE
	world.add_child(toad)
	toad.global_position = start + way * 3.0
	toad.rotation.y = yaw
	toad.settle()
	boy.global_position = start + way * 17.0 + side * 0.5
	await frames(30)
	var over := boy.global_position - way * 2.5 + up * 1.7 + side * 1.0
	look(toad.global_position + up * 0.9, over - toad.global_position - up * 0.9)
	await shot("m01_toad_from_the_boy")
	look(toad.global_position + up * 0.8 + way * 1.0, side * 7.0 + way * 4.0 + up * 1.5)
	await shot("m02_toad_in_the_hall")
	toad.croak(2)
	await until(func() -> bool: return toad._croak_t > 0.22)
	look(toad.global_position + up * 0.8 + way * 1.0, side * 5.0 + way * 4.0 + up * 0.6)
	await shot("m03_toad_croak")
	await frames(70)
	# It leaps at him
	toad.leap(toad.global_position + way * 5.5)
	mover = func(step: float) -> void:
		toad.global_position += toad.leap_push() * step
	await until(func() -> bool: return toad.leap_stage() == GiantToad.Leap.FLIGHT and toad.leap_progress() > 0.45)
	look(toad.global_position + way * 0.5, side * 10.0 + up * 0.5 - way * 1.0)
	await shot("m04_toad_leaping_side")
	look(toad.global_position, over - toad.global_position)
	await shot("m05_toad_leaping_at_the_boy")
	await until(func() -> bool: return toad.leap_stage() == GiantToad.Leap.NONE)
	mover = Callable()
	# The tongue at him
	var chest := boy.global_position + up * 1.35
	toad.strike(chest)
	await until(func() -> bool: return toad.windup_progress() > 0.85)
	look(toad.global_position + up * 0.9, over - toad.global_position - up * 0.9)
	await shot("m06_windup_from_the_boy")
	await until(func() -> bool: return toad.tongue_stage() == GiantToad.Tongue.HOLD)
	var mid := toad.global_position.lerp(boy.global_position, 0.5)
	look(mid + up * 1.0, side * 11.0 + up * 1.5)
	await shot("m07_tongue_side")
	look(boy.global_position + up * 1.2, -way * 2.0 + side * 3.0 + up * 0.3)
	await shot("m08_tongue_at_the_boy")
	await until(func() -> bool: return toad.tongue_stage() == GiantToad.Tongue.NONE)
	toad.queue_free()
	await frames(4)

	# --- The swarm, pouring down the hall at him ---
	var swarm := FrogSwarm.new()
	swarm.voice = false
	swarm.count = 70
	world.add_child(swarm)
	swarm.global_position = start + way * 1.0
	boy.global_position = start + way * 16.0
	swarm.target = boy
	await frames(20)
	look(swarm.global_position + up * 0.2, side * 3.5 + way * 3.0 + up * 2.2)
	await shot("m10_frog_pool")
	swarm.chasing = true
	await until(func() -> bool: return swarm.front().distance_to(swarm.global_position) > 6.0)
	look(swarm.front() - way * 2.5, side * 6.0 + way * 3.0 + up * 2.5)
	await shot("m11_swarm_pouring")
	over = boy.global_position + way * 2.5 + up * 1.7 + side * 1.0
	look(swarm.front() - way * 2.0, over - swarm.front() + way * 2.0)
	await shot("m12_swarm_from_the_boy")
	await until(func() -> bool: return swarm.on_target > 8, 8.0)
	look(boy.global_position + up * 0.8, -way * 2.6 + side * 1.8 + up * 0.5)
	await shot("m13_swarm_on_the_boy")
	world.queue_free()
	await frames(4)


## Waits (frame by frame) until `done` says so, or `limit` seconds.
func until(done: Callable, limit := 5.0) -> void:
	var waited := 0.0
	while not done.call() and waited < limit:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame
		waited += root.get_process_delta_time()
