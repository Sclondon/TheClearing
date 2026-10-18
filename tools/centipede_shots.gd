extends SceneTree
## Pictures of the giant centipede (creatures/centipede, CentipedeBody), first
## on a bare grey stage with a wall and a corner (close-ups of the model from
## the front, side and three-quarters, and frames from the middle of each of
## its movements: running, rearing to look about, the strike's wind-up, pounce
## and hold, coiled at rest, and going round a corner up the wall), then in a
## passage of a real round (World, the game's light and mist), hunting the
## boy. Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 720x1280 -s res://tools/centipede_shots.gd -- <folder> [stage|maze]

var folder := "centipede_shots"
var camera: Camera3D
var stage: Node3D
var centipede: CentipedeBody


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred(args)


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func _run(args: PackedStringArray) -> void:
	if not args.has("maze"):
		await _stage_shots()
	if not args.has("stage"):
		await _maze_shots()
	quit()


# --- On the stage ---

func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	mesh.material_override = material
	body.add_child(mesh)
	body.position = at
	stage.add_child(body)


func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	_box(Vector3(120.0, 1.0, 120.0), Vector3(0.0, -0.5, 0.0), Color(0.42, 0.41, 0.39))
	# A wall along x = -8 (its face at -7.5), and another meeting it at z = -14: a corner.
	_box(Vector3(1.0, 9.0, 40.0), Vector3(-8.0, 4.5, 6.0), Color(0.55, 0.55, 0.53))
	_box(Vector3(30.0, 9.0, 1.0), Vector3(7.0, 4.5, -14.0), Color(0.55, 0.55, 0.53))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.74, 0.76, 0.77)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.64, 0.67)
	environment.ambient_light_energy = 0.7
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.74, 0.76, 0.77)
	environment.fog_density = 0.006
	world.environment = environment
	stage.add_child(world)
	camera = Camera3D.new()
	camera.fov = 50.0
	stage.add_child(camera)
	camera.make_current()


func look(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


## Puts it with its head at `at` facing `way` (flat), its body laid out behind.
func place(at: Vector3, way: Vector3) -> void:
	centipede.global_transform = Transform3D(Basis.looking_at(-way), at)
	centipede.lay_straight()


## Runs it for `seconds` along a straight from where it is, at `speed`, turning by `turn` radians a second.
func run(seconds: float, speed: float, turn := 0.0) -> void:
	var t := 0.0
	var was := Time.get_ticks_usec()
	while t < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := (now - was) / 1000000.0
		was = now
		t += delta
		var basis := centipede.global_basis.rotated(Vector3.UP, turn * delta)
		var forward := basis.z
		forward.y = 0.0
		centipede.global_transform = Transform3D(basis, centipede.global_position + forward.normalized() * speed * delta)


func _stage_shots() -> void:
	_build_stage()
	centipede = CentipedeBody.new()
	stage.add_child(centipede)
	place(Vector3(4.0, 0.0, 8.0), Vector3(0, 0, 1))
	await frames(3)
	var cost := centipede.cost()
	print("centipede: %d triangles in %d draws" % [cost["triangles"], cost["draws"]])
	# Running along the open floor, then close-ups of it standing still mid-stride.
	place(Vector3(4.0, 0.0, -2.0), Vector3(0, 0, 1))
	await run(2.5, 5.0)
	var head := centipede.global_position
	look(head + Vector3(5.0, 2.2, 6.0), head + Vector3(0, 0.6, -1.5))
	await shot("01_threequarter_close")
	look(head + Vector3(0.0, 1.6, 6.5), head + Vector3(0, 0.7, 0))
	await shot("02_front")
	look(head + Vector3(13.0, 4.0, -8.0), head + Vector3(0, 0.6, -8.0))
	await shot("03_side")
	look(head + Vector3(7.0, 14.0, -6.0), head + Vector3(0, 0, -8.0))
	await shot("04_above")
	look(head + Vector3(2.5, 0.8, -15.0), head + Vector3(0, 0.6, -18.0))
	await shot("05_tail")
	# Running: mid-stride, seen from low and to the side as it comes.
	place(Vector3(4.0, 0.0, -12.0), Vector3(0, 0, 1))
	look(Vector3(14.0, 2.5, 10.0), Vector3(4.0, 0.6, 4.0))
	await run(3.6, 5.0)
	await shot("06_running")
	# Rearing to look about, feelers up.
	centipede.rear(0.85)
	centipede.look_about = true
	await run(1.2, 0.0)
	head = centipede.global_position
	look(head + Vector3(8.0, 2.5, 7.0), head + Vector3(0, 2.0, -2.0))
	await shot("07_reared_looking")
	await run(0.8, 0.0)
	await shot("08_reared_looking_b")
	centipede.look_about = false
	centipede.rear(0.0)
	await run(1.0, 0.0)
	# The strike at a target in front of it.
	var target := head + Vector3(0.0, 0.0, 5.0)
	# (a post the size of the boy, to strike at)
	var post := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	post.mesh = capsule
	post.position = target + Vector3.UP * 0.75
	stage.add_child(post)
	centipede.aim = target + Vector3.UP
	centipede.strike(target + Vector3.UP * 0.6)
	look(head + Vector3(14.0, 3.5, 2.0), head + Vector3(0, 1.3, 1.5))
	await run(centipede.wind_up * 0.8, 0.0)
	await shot("09_strike_windup")
	await run(centipede.wind_up * 0.2 + centipede.pounce_time * 0.5, 0.0)
	await shot("10_strike_pounce")
	await run(centipede.pounce_time * 0.5 + centipede.hold_time * 0.4, 0.0)
	await shot("11_strike_hold")
	centipede.aim = Vector3.INF
	await run(1.2, 0.0)
	# Coiled at rest.
	place(Vector3(14.0, 0.0, 10.0), Vector3(0, 0, 1))
	await frames(3)
	look(Vector3(26.0, 16.0, 16.0), Vector3(13.0, 0.4, 6.0))
	centipede.curl(2.8)
	await run(0.8, 0.0)
	await shot("12a_curling")
	await run(1.4, 0.0)
	await shot("12b_coiled")
	# Along the foot of the wall and round the corner, up it.
	place(Vector3(-6.3, 0.0, 14.0), Vector3(0, 0, -1))
	look(Vector3(-2.5, 2.2, 20.0), Vector3(-7.0, 0.8, 2.0))
	await run(3.4, 4.5)
	await shot("13_along_the_wall")
	await run(2.0, 4.5)
	await run(0.56, 4.5, -2.8)
	await run(0.6, 4.5)
	await shot("14_round_the_corner")
	look(Vector3(3.0, 2.5, -4.0), Vector3(-6.5, 1.2, -13.0))
	await shot("15_round_the_corner_close")
	stage.queue_free()
	await frames(2)


# --- In the maze ---

func _maze_shots() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Player = world.player
	boy.takes_input = false
	boy.add_to_group(&"maze_players")
	await frames(30)
	# A straight passage.
	var cell := nav.lairs(2)[0]
	var way := Vector2i(1, 0)
	for c: Vector2i in nav.lairs(2):
		var found := false
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in 4:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				cell = c
				way = step
				found = true
				break
		if found:
			break
	var along := Vector3(way.x, 0, way.y)
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy.rotation.y = atan2(along.x, along.z)
	world.camera._yaw = atan2(-along.x, -along.z)
	world.camera.snap()
	await frames(30)
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("draws with nobody about: %d" % bare)
	var hunter := Centipede.new()
	hunter.maze = maze
	hunter.start_resting = false
	hunter.position = maze.world(cell + way * 4) + Vector3.UP * 0.05
	hunter.rotation.y = atan2(-along.x, -along.z)
	world.add_child(hunter)
	hunter.notice(boy)
	# (a camera of its own: up behind the boy and to one side, looking down the passage at what is coming)
	var eye := Camera3D.new()
	world.add_child(eye)
	var across := Vector3(-along.z, 0.0, along.x)
	eye.position = boy.global_position - along * 7.0 + across * 2.5 + Vector3.UP * 3.2
	eye.fov = 55.0
	eye.look_at(boy.global_position + along * 8.0 + Vector3.UP * 0.8)
	eye.make_current()
	await _wait(1.6)
	print("hunter: %s at %s, %.1f m from the boy, after %s, huntable %s" % [Centipede.State.keys()[hunter.state], hunter.global_position.snappedf(0.1), hunter.global_position.distance_to(boy.global_position), hunter.quarry, hunter.huntable(boy)])
	await shot("20_maze_coming")
	await _wait(40.0, func() -> bool: return hunter.body.stage() == CentipedeBody.Stage.WIND_UP and hunter.body.strikes_in() < 0.15)
	print("hunter: %s at %s, %.1f m from the boy" % [Centipede.State.keys()[hunter.state], hunter.global_position.snappedf(0.1), hunter.global_position.distance_to(boy.global_position)])
	await shot("21_maze_windup")
	await _wait(0.25)
	await shot("22_maze_pounce")
	eye.position = boy.global_position + across * 9.0 + along * 3.0 + Vector3.UP * 2.0
	eye.look_at(boy.global_position + along * 3.0 + Vector3.UP * 1.2)
	await _wait(0.1)
	await shot("22b_maze_pounce_side")
	# From up on the wall: how it lies in the passage.
	await _wait(1.5)
	var above := Camera3D.new()
	world.add_child(above)
	var middle: Vector3 = hunter.body.spine[hunter.body.segments / 2] if hunter.body.spine.size() > 0 else hunter.global_position
	above.position = middle + Vector3(6.0, 40.0, 8.0)
	above.fov = 50.0
	above.look_at(middle)
	above.make_current()
	await _wait(0.2)
	await shot("23_maze_above")
	above.queue_free()
	eye.make_current()
	# Coiled in a dead end, from the boy beside it.
	hunter.queue_free()
	await frames(2)
	# (a dead end, or a corner, with room enough to coil in)
	var end := cell
	var best := -1
	for c: Vector2i in nav.lairs(2):
		var walls := 0
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(c, step):
				walls += 1
		if walls > best and nav.clear_of_walls(maze.world(c), Centipede.ROOMY + 0.9):
			best = walls
			end = c
	var resting := Centipede.new()
	resting.maze = maze
	resting.position = maze.world(end) + Vector3.UP * 0.05
	world.add_child(resting)
	boy.remove_from_group(&"maze_players")
	var open_way := Vector2i(1, 0)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(end, step):
			open_way = step
	boy.global_position = maze.world(end) + Vector3(open_way.x, 0, open_way.y) * 6.0 + Vector3.UP * 0.1
	var to_den := Vector3(-open_way.x, 0, -open_way.y)
	eye.position = boy.global_position - to_den * 4.0 + Vector3.UP * 5.0
	eye.look_at(maze.world(end) + Vector3.UP * 0.5)
	await _wait(1.0)
	await shot("24_maze_coiled")
	print("draws with it: %d" % RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _wait(seconds: float, until := Callable()) -> bool:
	var until_time := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until_time:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false
