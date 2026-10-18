extends SceneTree
## Pictures of the giant ants (creatures/giant_ant): close up on a plain floor
## under the game's kind of light (a worker from each side, the soldier, the
## low model, a line of them on the trail, one carrying, the alarm taken up,
## the boy seized), and a colony in a real round (MazeAnts: the nest in its
## dead end, the trail down the halls, the alarm, a swarm on the boy, a
## carcass hauled home). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/ants_shots.gd -- <folder> [studio|maze|all]

var folder := "ants_shots"
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


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func until(test: Callable, most := 900) -> void:
	for i in most:
		if test.call():
			return
		await process_frame


func look(target: Vector3, from: Vector3, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func studio_stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.66)
	environment.fog_density = 0.012
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
	plane.size = Vector2(300.0, 300.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.36, 0.34, 0.31)
	floor.material_override = ground
	stage_root.add_child(floor)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300.0, 1.0, 300.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	stage_root.add_child(body)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _studio() -> void:
	studio_stage()
	# One of each, standing still, to look at.
	var lone := AntColony.new()
	lone.workers = 1
	lone.soldiers = 1
	lone.sound = false
	lone.show_trail = false
	lone.show_nest = false
	lone.set_trail(PackedVector3Array([Vector3(0.0, 0.0, -40.0), Vector3(0.0, 0.0, -20.0)]))
	stage_root.add_child(lone)
	await frames(3)
	var worker: AntColony.Ant = lone.ants[0]
	var soldier: AntColony.Ant = lone.ants[1]
	lone.set_process(false)
	for ant: AntColony.Ant in [worker, soldier]:
		ant.state = AntColony.State.GUARD
		ant.timer = 1000.0
		ant.speed = 0.0
	worker.pos = Vector3.ZERO
	worker.yaw = 0.0
	soldier.pos = Vector3(2.4, 0.0, 0.0)
	soldier.yaw = 0.0
	lone._draw_ants()
	var middle := Vector3(0.0, 0.25, 0.0)
	look(middle, Vector3(2.4, 0.5, 0.2))
	await shot("a01_worker_side")
	look(middle, Vector3(1.6, 0.9, 1.7))
	await shot("a02_worker_three_quarter")
	look(middle + Vector3(0.0, 0.0, 0.4), Vector3(0.3, 0.35, 1.3))
	await shot("a03_worker_face")
	look(middle, Vector3(-1.4, 1.2, -1.8))
	await shot("a04_worker_back_quarter")
	look(Vector3(2.4, 0.3, 0.1), Vector3(1.5, 0.8, 1.8))
	await shot("a05_soldier")
	look(Vector3(1.2, 0.3, 0.0), Vector3(0.0, 4.0, 0.01))
	await shot("a06_both_from_above")
	# Striding, the alarm, biting, carrying: poses held
	worker.speed = 1.6
	worker.phase = 0.25
	worker.loaded = true
	soldier.alarm = 1.0
	soldier.pitch = -0.18
	lone._draw_ants()
	look(Vector3(1.2, 0.3, 0.0), Vector3(1.0, 1.2, 3.4))
	await shot("a07_striding_loaded_and_alarmed")
	lone.low_poly = true
	lone._draw_ants()
	look(middle, Vector3(1.6, 0.9, 1.7))
	await shot("a08_low_model")
	lone.queue_free()
	await frames(2)

	# A colony going about: the nest, the trail, lines of them
	var colony := AntColony.new()
	colony.colony_seed = 5
	colony.sound = false
	colony.set_trail(PackedVector3Array([Vector3.ZERO, Vector3(3.0, 0.0, 12.0), Vector3(-2.0, 0.0, 24.0), Vector3(1.0, 0.0, 38.0)]))
	stage_root.add_child(colony)
	await frames(240)
	look(Vector3(0.0, 0.2, 2.0), Vector3(4.0, 3.0, -5.0))
	await shot("a09_nest")
	look(colony.trail_point(14.0), Vector3(6.0, 2.2, 3.0))
	await shot("a10_on_the_trail")
	look(colony.trail_point(16.0), Vector3(14.0, 18.0, -6.0), 50.0)
	await shot("a11_trail_from_above")
	# The boy for scale, then on the trail: the alarm
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	var at := colony.trail_point(15.0, 0.0)
	boy.global_position = at + Vector3(3.0, 0.1, 0.0)
	await frames(30)
	look(at + Vector3(1.5, 0.8, 0.0), Vector3(-2.0, 1.6, 6.0))
	await shot("a12_boy_beside_the_trail")
	boy.global_position = at + Vector3(0.0, 0.1, 0.0)
	colony.alarm(at)
	colony.target = boy.global_position
	await until(func() -> bool: return colony.counted(AntColony.State.ALERT) >= 3)
	look(at + Vector3.UP * 0.6, Vector3(5.0, 2.0, 3.0))
	await shot("a13_alarm_taken_up")
	await until(func() -> bool: return colony.on_target >= 4, 400)
	look(boy.global_position + Vector3.UP * 0.7, Vector3(2.8, 1.5, 3.2))
	await shot("a14_seized")
	look(boy.global_position + Vector3.UP * 0.5, Vector3(-6.0, 4.0, -5.0))
	await shot("a15_swarmed_from_further")
	colony.calm()
	await frames(200)
	look(at + Vector3.UP * 0.5, Vector3(5.0, 3.0, 5.0))
	await shot("a16_calmed")
	stage_root.queue_free()
	await frames(2)


## Looks at `target` from the first of `offsets` with nothing solid between (by a ray), or as far out along the first as is clear.
func look_clear(_nav: MazeNav, target: Vector3, offsets: Array, fov := 45.0) -> void:
	var space := camera.get_world_3d().direct_space_state
	for offset: Vector3 in offsets:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, target + offset * 1.1, 1))
		if hit.is_empty():
			look(target, offset, fov)
			return
	var first: Vector3 = offsets[0]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, target + first, 1))
	var clear: float = target.distance_to(hit["position"]) - 0.6 if not hit.is_empty() else first.length()
	look(target, first.normalized() * maxf(clear, 1.0), fov)


## Offsets round about, `far` off and `high` up, starting from `first_way`.
func round_about(first_way: Vector3, far: float, high: float) -> Array:
	var made := []
	var start := atan2(first_way.x, first_way.z)
	for k in 12:
		var a := start + TAU * k / 12.0
		made.append(Vector3(sin(a) * far, high, cos(a) * far))
	for k in 12:
		var a := start + TAU * k / 12.0
		made.append(Vector3(sin(a) * far * 0.5, high * 0.7, cos(a) * far * 0.5))
	return made


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
	var ends: Array[Vector2i] = []
	for cell in nav.lairs(4):
		if nav.dead_end(cell):
			ends.append(cell)
	var holder := MazeEnemies.new()
	holder.maze = maze
	world.add_child(holder)
	var ants := MazeAnts.new()
	ants.sound = false
	holder.add(ants, ends[ends.size() / 2], 0.0, 99)
	await frames(30)
	var colony := ants.colony
	var nest := colony.nest()
	var out := colony.trail_way(0.0)
	boy.global_position = colony.trail_point(colony.trail_length() * 0.35, 4.5) + Vector3.UP * 0.1
	await frames(200)
	look_clear(nav, nest + Vector3.UP * 0.4, round_about(out + Vector3(0.3, 0.0, 0.0), 8.0, 3.5))
	await shot("m01_nest_in_its_dead_end")
	var mid := colony.trail_point(colony.trail_length() * 0.4)
	var side := (boy.global_position - mid)
	side.y = 0.0
	look_clear(nav, mid + Vector3.UP * 0.4, [side.normalized() * 7.0 + Vector3.UP * 2.0] + round_about(side, 8.0, 2.5))
	await shot("m02_trail_from_beside_it")
	look(mid, Vector3(0.01, 30.0, 0.0), 60.0)
	await shot("m03_trail_from_above")
	# He steps onto it: the alarm, the swarm
	var on := colony.trail_point(colony.trail_length() * 0.35)
	boy.global_position = on + Vector3.UP * 0.1
	await until(func() -> bool: return ants.mode == MazeAnts.Mode.ALARM and colony.counted(AntColony.State.ALERT) >= 2, 300)
	look_clear(nav, on + Vector3.UP * 0.8, round_about(side, 7.0, 2.5))
	await shot("m04_alarm")
	await until(func() -> bool: return colony.on_target >= 3, 400)
	look_clear(nav, boy.global_position + Vector3.UP * 0.8, round_about(side, 4.5, 1.8))
	await shot("m05_on_him")
	await frames(40)
	look_clear(nav, boy.global_position + Vector3.UP * 0.5, round_about(-side, 11.0, 6.0))
	await shot("m06_the_swarm")
	# A carcass by the trail: they haul it home
	ants._calm()
	boy.global_position = nest + Vector3(0.0, 0.1, 0.0) + out * 30.0 + Vector3(0.0, 0.0, 0.0)
	boy.global_position = colony.trail_point(colony.trail_length() * 0.6, 5.0) + Vector3.UP * 0.1
	var dead := InsectLook.carcass()
	world.add_child(dead)
	dead.global_position = colony.trail_point(colony.trail_length() * 0.5, 3.0)
	await frames(30)
	colony.carry(dead)
	await until(func() -> bool: return colony.counted(AntColony.State.HAUL) >= 3, 900)
	await frames(240)
	look_clear(nav, dead.global_position + Vector3.UP * 0.3, round_about(side, 5.0, 2.0))
	await shot("m07_hauling_a_carcass")
	await until(func() -> bool: return colony.carrying() == null, 3000)
	look_clear(nav, nest + Vector3.UP * 0.3, round_about(out, 6.0, 2.5))
	await shot("m08_carried_home")
	world.queue_free()
	await frames(2)
