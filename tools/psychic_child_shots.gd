extends SceneTree
## Pictures of the psychic child (creatures/psychic_child): close up on a plain
## floor under the game's kind of light (each view, the face, beside the boy for
## scale, and each state: drifting, watching, distress as it builds, the burst
## going out, drained), and in a passage of a real round (drifting down a hall,
## following the boy, distressed with him lifted, the burst, drained). Says how
## many draws a frame takes. Needs a real window (the engine draws nothing
## headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/psychic_child_shots.gd -- <folder> [studio|maze|all]

var folder := "psychic_child_shots"
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


## Whatever is moving her along, called every frame while a picture is taken too.
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
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame


## Looks at `target` from `offset` away (in her own space, if `child` is given).
func look(target: Vector3, offset: Vector3, child: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if child:
		from = Basis(Vector3.UP, child.rotation.y) * offset
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
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	# (something behind her to see the warp of the air against)
	for k in 5:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 2.4, 0.12)
		post.mesh = box
		post.position = Vector3(-1.2 + k * 0.6, 1.2, -1.6)
		stage_root.add_child(post)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 600.0

	var child := PsychicChild.new()
	child.sound = false
	stage_root.add_child(child)
	child.put(Vector3.ZERO, 0.0)
	await frames(40)
	var middle := Vector3(0.0, 0.55, 0.0)
	var face := Vector3(0.0, 0.9, 0.05)
	look(middle, Vector3(0.0, 0.25, 3.4), child)
	await shot("s01_front")
	look(middle, Vector3(3.4, 0.25, 0.0), child)
	await shot("s02_side")
	look(middle, Vector3(2.4, 0.9, 2.4), child)
	await shot("s03_three_quarter")
	look(middle, Vector3(-2.2, 0.8, -2.6), child)
	await shot("s04_back_quarter")
	look(face, Vector3(0.0, 0.0, 0.9), child)
	await shot("s05_face")
	look(face, Vector3(0.6, 0.05, 0.6), child)
	await shot("s06_face_quarter")

	# Beside the boy, for scale; she looks up at him
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	stage_root.add_child(ground_body)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = Vector3(0.7, 0.05, 0.9)
	boy.rotation.y = PI * 1.2
	child.aim = boy.global_position + Vector3.UP * 1.1
	await frames(60)
	look(Vector3(0.35, 0.7, 0.45), Vector3(2.8, 0.4, 2.6))
	await shot("s07_beside_the_boy")
	look(Vector3(0.35, 0.7, 0.45), Vector3(-0.6, 0.3, 3.6))
	await shot("s08_beside_the_boy_front")
	boy.queue_free()
	child.aim = Vector3.INF

	# Drifting along
	mover = func(step: float) -> void:
		child.global_position += child.global_basis.z * 0.55 * step
		child.velocity = child.global_basis.z * 0.55
	await frames(90)
	look(child.global_position + Vector3(0.0, 0.55, 0.0), Vector3(3.0, 0.3, 1.2), child)
	await shot("s09_drifting")
	mover = Callable()
	child.velocity = Vector3.ZERO
	child.put(Vector3.ZERO, 0.0)

	# Distress building
	for level: float in [0.3, 0.6, 0.85, 1.0]:
		child.distress = level
		await frames(50)
		look(Vector3(0.0, 0.65, 0.0), Vector3(0.9, 0.35, 2.6), child)
		await shot("s10_distress_%02d" % int(level * 100.0))
	# (the warp with its bending off: nothing of it should be seen)
	child._haze_material.set_shader_parameter(&"bend_scale", 0.0)
	child._haze_material.set_shader_parameter(&"dim", 0.0)
	await shot("s10_warp_unbent")
	child._haze_material.set_shader_parameter(&"bend_scale", 0.0)
	await shot("s10_warp_unbent_raw")
	child._haze_material.set_shader_parameter(&"bend_scale", 1.0)
	child._haze_material.set_shader_parameter(&"dim", 0.1)
	look(face + Vector3(0.0, 0.1, 0.0), Vector3(0.25, 0.0, 0.8), child)
	await shot("s11_distress_face")
	# The burst going out, frame by frame
	child.burst()
	for k in 4:
		await frames(3 if k == 0 else 5)
		look(Vector3(0.0, 0.8, 0.0), Vector3(0.9, 0.5, 4.2), child)
		await shot("s12_burst_%d" % k)
	child.distress = 0.0
	child.drained = true
	await frames(150)
	look(Vector3(0.0, 0.3, 0.2), Vector3(1.6, 0.6, 1.9), child)
	await shot("s13_drained")
	look(Vector3(0.0, 0.25, 0.0), Vector3(0.0, 4.5, 4.5), child)
	await shot("s14_drained_from_above")
	child.drained = false
	await frames(200)
	look(middle, Vector3(1.5, 0.4, 2.8), child)
	await shot("s15_calm_again")
	stage_root.queue_free()
	await frames(2)


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
			while run < 6 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run and maze.blocked(at, step):
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := maze.world(best)
	var yaw := atan2(way.x, way.z)
	var child := PsychicChild.new()
	child.sound = false
	world.add_child(child)
	child.put(start + way * 4.0, yaw)
	boy.global_position = start + way * 10.0 + side * 1.0
	boy.rotation.y = yaw + PI
	await frames(40)

	# Drifting down the hall
	mover = func(step: float) -> void:
		child.global_position += way * 0.55 * step
		child.velocity = way * 0.55
		child.aim = boy.global_position + up * 1.1
	await frames(120)
	look(child.global_position + up * 0.6, way * 3.2 + side * 1.8 + up * 0.6)
	await shot("m01_drifting_towards_him")
	look(boy.global_position + up * 1.4, -way * 3.0 + side * 0.8 + up * 0.5)
	await shot("m02_over_his_shoulder")
	look(child.global_position + up * 2.0, -way * 9.0 + side * 3.0 + up * 4.0)
	await shot("m03_in_the_hall")
	mover = Callable()
	child.velocity = Vector3.ZERO
	# Distressed
	child.distress = 0.8
	await frames(60)
	look(child.global_position + up * 0.7, way * 3.4 - side * 1.6 + up * 0.4)
	await shot("m04_distressed")
	look(boy.global_position + up * 1.2, -way * 2.6 + side * 1.2 + up * 0.4)
	await shot("m05_distressed_past_him")
	child.burst()
	await frames(6)
	look(child.global_position + up * 0.9, way * 6.0 - side * 3.0 + up * 1.5)
	await shot("m06_burst")
	child.distress = 0.0
	child.drained = true
	await frames(150)
	look(child.global_position + up * 0.4, way * 2.5 + side * 1.6 + up * 0.8)
	await shot("m07_drained")
	child.queue_free()
	await frames(2)

	# She watches over him: a dog after him, taken hold of, lifted, slammed down (MazePsychicChild itself)
	var guard := MazePsychicChild.new()
	guard.maze = maze
	guard.targets = [boy]
	guard.follow_after = 0.3
	guard.position = start + way * 4.0 + up * 0.05
	world.add_child(guard)
	boy.global_position = start + way * 7.0 + side * 0.8
	await frames(60)
	var dog := MazeDog.new()
	dog.maze = maze
	dog.targets = [boy]
	dog.position = boy.global_position + way * 12.0 + up * 0.05
	world.add_child(dog)
	await frames(2)
	dog.notice(boy)
	for i in 400:
		await frames(1)
		if guard.mode == MazePsychicChild.Mode.GUARD and guard._mode_time > 0.7:
			break
	look(guard.global_position + up * 0.9 + way * 2.5, -way * 3.5 + side * 4.5 + up * 1.2)
	await shot("m08_guarding")
	look(dog.global_position + up * 0.4, -way * 3.5 - side * 2.0 + up * 0.3)
	await shot("m09_held_dog")
	look(guard.figure.head(), way * 1.4 + side * 0.9 + up * 0.1)
	await shot("m10_guarding_face")
	await frames(40)
	look(guard.global_position + up * 0.9 + way * 3.0, side * 6.0 + up * 1.5)
	await shot("m11_slammed")
