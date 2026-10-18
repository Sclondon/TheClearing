extends SceneTree
## Pictures of the angel (scripts/enemies/maze_angel.gd, creatures/angel/) in a
## passage of a real round (World, so the light and the mist are the game's):
## the whole of it in a hall from the boy's height, its eyes close to, its wings
## and core, its gaze building on the boy (eyes turned, wheels stopped, the light
## on him) and the moment it takes him. Says how many draws a frame takes with it
## and without. (The round's own enemies are put away first.) Needs a real window (landscape):
##
##     godot --path . --resolution 1280x720 -s res://tools/angel_shots.gd -- <folder>

var folder := "angel_shots"
var world
var maze
var nav
var boy
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _setup() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	boy.add_to_group(&"maze_players")
	for hunter: Node3D in [world.enemies, world.griever]:
		hunter.visible = false
		hunter.process_mode = Node.PROCESS_MODE_DISABLED


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
		if until.is_valid() and until.call():
			return true
	return false


func draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## A passage cell with at least `run` open cells straight on from it, and that way.
func straight_run(run: int) -> Array:
	# (a run with room all along it for the angel's wheels: well clear of the walls)
	for c: Vector2i in nav.lairs(2):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			var a: Vector3 = maze.world(c)
			var b: Vector3 = maze.world(c + step * run)
			if ok and nav.line_free(a, b, 4.5):
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


## The boy at `at`, facing along `along`.
func stand(at: Vector3, along: Vector2i) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = atan2(float(along.x), float(along.y))
	boy.rotation.y = boy.facing_yaw


func look_from(from: Vector3, to: Vector3, fov := 55.0) -> void:
	if camera == null:
		camera = Camera3D.new()
		world.add_child(camera)
	camera.fov = fov
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	camera.make_current()


func spawn(at: Vector3, facing: float) -> MazeAngel:
	var angel := MazeAngel.new()
	angel.maze = maze
	angel.position = at
	angel.rotation.y = facing
	world.add_child(angel)
	return angel


## The Ophan on its own (with `model` after the folder): in the game's light over
## a bare floor, from the front, three-quarters and below, its heart and an eye
## close to, and gazing at a post, with `debug` showing the eyes' own axes.
func _model() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	MazeLight.put(stage)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	for side: float in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 30.0, 60.0)
		wall.mesh = box
		wall.position = Vector3(9.0 * side, 15.0, 0.0)
		stage.add_child(wall)
	var post := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	post.mesh = capsule
	post.position = Vector3(1.5, 0.75, 9.0)
	stage.add_child(post)
	var angel := Ophan.new()
	angel.sound = false
	stage.add_child(angel)
	angel.position = Vector3(0.0, 6.2, 0.0)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	var views := [
		["m1_front", Vector3(0.0, 1.6, 16.0), Vector3(0.0, 5.5, 0.0), 55.0],
		["m2_three_quarter", Vector3(6.5, 2.5, 13.0), Vector3(0.0, 6.0, 0.0), 50.0],
		["m3_heart", Vector3(0.0, 6.4, 6.0), Vector3(0.0, 6.2, 0.0), 45.0],
		["m4_below", Vector3(2.0, 1.4, 4.0), Vector3(0.0, 6.0, 0.0), 70.0],
	]
	await wait(2.0)
	for view: Array in views:
		camera.fov = view[3]
		camera.global_position = view[1]
		camera.look_at(view[2], Vector3.UP)
		await wait(0.2)
		await shot(view[0])
	# An eye close to, facing the camera.
	camera.global_position = Vector3(0.0, 6.2, 9.0)
	camera.look_at(Vector3(0.0, 6.2, 0.0), Vector3.UP)
	var eye := 0
	var best := -1.0
	for i in angel.eye_count():
		var out: Vector3 = (angel.eye_position(i) - angel.global_position).normalized()
		var to_cam: Vector3 = (camera.global_position - angel.eye_position(i)).normalized()
		if out.dot(to_cam) > best:
			best = out.dot(to_cam)
			eye = i
	angel.pace = 0.0
	angel.look_at_point = camera.global_position
	await wait(1.5)
	var at := angel.eye_position(eye)
	var out_of: Vector3 = (at - angel.global_position).normalized()
	camera.fov = 35.0
	camera.global_position = at + out_of * 1.6 + Vector3.UP * 0.2
	camera.look_at(at, Vector3.UP)
	await wait(0.2)
	await shot("m5_eye")
	angel.pace = 1.0
	# Gazing at the post.
	angel.look_at_point = post.global_position + Vector3.UP * 0.3
	angel.gaze_ground = Vector3(post.position.x, 0.0, post.position.z)
	camera.fov = 55.0
	camera.global_position = Vector3(-6.0, 2.0, 15.0)
	camera.look_at(Vector3(0.0, 4.0, 3.0), Vector3.UP)
	for g in [0.4, 0.8]:
		angel.gaze = g
		await wait(1.5)
		await shot("m6_gaze_%d" % int(g * 10))
	angel.blaze()
	await wait(0.6)
	await shot("m7_blaze")
	quit()


func _run() -> void:
	if OS.get_cmdline_user_args().has("model"):
		await _model()
		return
	_setup()
	await wait(0.5)
	var found := straight_run(2)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var side := Vector3(-along.z, 0.0, along.x)
	var start: Vector3 = maze.world(cell)
	# (in the middle of the hall: a cell's own middle can be a metre off a thick wall)
	var probe := MazeAngel.new()
	probe.maze = maze
	start += probe.wall_push(start, 8.0)
	probe.free()
	stand(start + along * 3.0, way)
	look_from(start - along * 1.5 + Vector3.UP * 1.8 + side * 0.4, start + along * 20.0 + Vector3.UP * 4.5)
	await wait(1.0)

	# --- The whole of it, down the hall, from his height ---
	var angel := spawn(start + along * 22.0, atan2(-along.x, -along.z))
	angel.drift_speed = 0.0
	angel.gaze_time = 1000.0
	await wait(3.0)
	var toward: Vector3 = (angel.global_position - boy.global_position) * Vector3(1, 0, 1)
	look_from(boy.global_position - toward.normalized() * 4.5 + Vector3.UP * 1.9, angel.heart() - Vector3.UP * 1.5, 60.0)
	await wait(0.2)
	await shot("1_in_the_hall")
	var with := await draws()
	angel.body().visible = false
	var without := await draws()
	angel.body().visible = true
	print("draws with the angel: %d, hidden: %d (it costs %d)" % [with, without, with - without])
	# Nearer, looking up at it.
	look_from(start + along * 12.0 + Vector3.UP * 1.4 + side * 2.0, angel.heart() + Vector3.UP * 0.2, 60.0)
	await wait(0.5)
	await shot("2_below_it")
	# --- Its eyes close to, and its heart ---
	var body: Ophan = angel.body()
	var eye := 0
	var best := -1.0
	for i in body.eye_count():
		var to_cam := (camera.global_position - body.eye_position(i)).normalized()
		var out := (body.eye_position(i) - angel.heart()).normalized()
		if out.dot(to_cam) > best:
			best = out.dot(to_cam)
			eye = i
	var at: Vector3 = body.eye_position(eye)
	var outward: Vector3 = (at - angel.heart()).normalized()
	look_from(at + outward * 1.3 + Vector3.UP * 0.1, at, 40.0)
	await wait(0.3)
	await shot("3_eyes_close")
	look_from(angel.heart() + along * -5.0 + Vector3.UP * 0.6 + side * 1.0, angel.heart(), 50.0)
	await wait(0.3)
	await shot("4_heart")

	# --- Its gaze building on him ---
	angel.gaze_time = 4.0
	angel.drift_speed = 0.0
	stand(start + along * 8.0, way)
	boy.facing_yaw = atan2(-along.x, -along.z)
	look_from(start + along * 2.0 + Vector3.UP * 2.2 + side * 3.0, start + along * 14.0 + Vector3.UP * 3.0, 60.0)
	angel.notice(boy)
	await wait(2.0)
	await shot("5_gaze_building")
	await wait(6.0, func() -> bool: return angel.gaze_on(boy) > 0.85)
	await shot("6_gaze_full")
	await wait(4.0, func() -> bool: return angel.mode == MazeAngel.Mode.TAKING)
	await wait(1.3)
	await shot("7_taken_up")
	quit()
