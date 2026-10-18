extends SceneTree
## Pictures of the corvids (creatures/crow/, creatures/blue_jay/): crows,
## ravens and blue jays. First in a plain grey studio: each kind from the side,
## the front, three quarters and behind, their heads close; the wingbeat in
## eight steps, from the side and from the front; a glide, the flare to land, a
## take-off, a caw, a raven's croak with its hackles out, a jay's crest up.
## Then in a real round (World, the game's light and mist): crows lined along a
## wall top seen from a hall at the boy's height; the murder erupting and
## wheeling; a raven close; then the clearing: blue jays in a pine and on the
## ground at the edge of the woods. Says how many draws a frame takes. Needs a
## real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/crow_shots.gd -- <folder> [studio|beat|maze|clearing]

var folder := "crow_shots"
var only := ""
var camera: Camera3D
var world
var maze: Maze
var nav: MazeNav
var boy


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


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


func _run() -> void:
	if only == "" or only == "studio":
		await _studio()
	if only == "" or only == "beat":
		await _beat()
	if only == "" or only == "maze":
		await _maze()
	if only == "" or only == "clearing":
		await _clearing()
	quit()


# --- The studio ---

var stage: Node3D


func _set_studio() -> void:
	if stage:
		stage.queue_free()
		await process_frame
	stage = Node3D.new()
	stage.name = "Studio"
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.5
	var surround := WorldEnvironment.new()
	surround.environment = env
	stage.add_child(surround)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(2.0, 4, 3), Vector3.ZERO)
	var back := DirectionalLight3D.new()
	back.light_energy = 0.5
	stage.add_child(back)
	back.look_at_from_position(Vector3(-1, 2.5, -4), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.3, 0.29, 0.27)
	ground.material_override = mud
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()


## Points the camera at `at` from `way` so that `across` metres fill the picture's height.
func _frame(at: Vector3, across: float, way: Vector3) -> void:
	var far := across * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	camera.look_at_from_position(at + way.normalized() * far, at)


func _flock(kind: int, many := 1) -> CorvidFlock:
	var flock: CorvidFlock = BlueJays.new() if kind == CorvidBody.Kind.BLUE_JAY else CorvidFlock.new()
	flock.kind = kind
	flock.count = many
	flock.frozen = true
	stage.add_child(flock)
	return flock


func _studio() -> void:
	await _set_studio()
	var names := ["crow", "raven", "blue_jay"]
	var heights := [0.3, 0.4, 0.19]
	for k in 3:
		var flock := _flock(k)
		var s: float = [1.0, 1.32, 0.62][k]
		flock.pose_bird(0, Vector3.ZERO, 0.0, {})
		var mid := Vector3(0, 0.15 * s, -0.04 * s)
		var span: float = heights[k] * 1.7
		_frame(mid, span, Vector3(1, 0.1, 0))
		await shot("%02d_%s_side" % [k * 10, names[k]])
		_frame(mid, span, Vector3(0, 0.15, 1))
		await shot("%02d_%s_front" % [k * 10 + 1, names[k]])
		_frame(mid, span, Vector3(0.9, 0.35, 0.8))
		await shot("%02d_%s_three_quarter" % [k * 10 + 2, names[k]])
		_frame(mid, span, Vector3(-0.6, 0.6, -1))
		await shot("%02d_%s_back" % [k * 10 + 3, names[k]])
		var head: Vector3 = CorvidBody.joints(k)["head"]
		_frame(head + Vector3(0, -0.005, 0.02) * s, 0.12 * s, Vector3(0.8, 0.15, 0.6))
		await shot("%02d_%s_head" % [k * 10 + 4, names[k]])
		# A call: the crow's caw, the raven's croak (hackles out), the jay's "jay!" (crest up).
		flock.pose_bird(0, Vector3.ZERO, 0.0, {"beak": 1.0, "pitch": 0.3, "tail_lift": 0.4, "fluff": 1.0 if k == 1 else 0.25, "crest": 1.0, "crouch": 0.5, "head": Vector3(0, -0.006, 0.018) * s})
		_frame(mid + Vector3(0, 0.02, 0.02) * s, span, Vector3(1, 0.15, 0.3))
		await shot("%02d_%s_call" % [k * 10 + 5, names[k]])
		# Spread and gliding, from above and below.
		flock.pose_bird(0, Vector3(0, 0.5, 0), 0.0, {"fold": 0.0, "strength": 0.0, "tuck": 1.0})
		_frame(Vector3(0, 0.5, -0.05 * s), 1.2 * s, Vector3(0.0, 1.0, -0.15))
		await shot("%02d_%s_glide_above" % [k * 10 + 6, names[k]])
		_frame(Vector3(0, 0.5, -0.05 * s), 1.2 * s, Vector3(0.3, -0.5, 1.0))
		await shot("%02d_%s_glide_below_front" % [k * 10 + 7, names[k]])
		flock.queue_free()
		await process_frame


# The wingbeat in eight steps, from the side and the front; then a flare and a take-off.
func _beat() -> void:
	await _set_studio()
	for k in [0, 2]:
		var name: String = ["crow", "raven", "blue_jay"][k]
		var s: float = [1.0, 1.32, 0.62][k]
		var flock := _flock(k, 8)
		# (eight in two rows of four, left to right, top row first; from the side
		# they face left, from the front they face the camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.1 * s
		for side_on in [true, false]:
			for i in 8:
				var col := float(i % 4) - 1.5
				var row := 0.5 - float(i / 4)
				var at := Vector3(0.0, 1.0 + row * 1.0 * s, 0.0)
				if side_on:
					at += Vector3(0.0, 0.0, -col * 1.0 * s)
				else:
					at += Vector3(col * 1.05 * s, 0.0, 0.0)
				flock.pose_bird(i, at, 0.0, {"fold": 0.0, "beat": i / 8.0, "strength": 1.0, "tuck": 1.0})
			if side_on:
				camera.look_at_from_position(Vector3(6.0, 1.0, 0.0), Vector3(0, 1.0, 0.0))
				await shot("%s_beat_side" % name)
			else:
				camera.look_at_from_position(Vector3(0.0, 1.0, 6.0), Vector3(0.0, 1.0, 0))
				await shot("%s_beat_front" % name)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		# The flare to land, a take-off, banked in a turn.
		for i in 8:
			flock.pose_bird(i, Vector3(50, 0, 0), 0.0, {})
		flock.pose_bird(0, Vector3(0, 0.15, 0), 0.0, {"fold": 0.0, "flare": 1.0, "beat": 0.1, "strength": 0.6, "reach": 1.0, "tail_fan": 1.0, "tail_lift": -0.25, "pitch": -0.75, "tuck": 0.0})
		_frame(Vector3(0, 0.3 * s, 0), 1.1 * s, Vector3(1, 0.2, 0.35))
		await shot("%s_flare" % name)
		flock.pose_bird(0, Vector3(0, 0.05, 0), 0.0, {"fold": 0.0, "beat": 0.05, "strength": 1.0, "crouch": 0.6, "pitch": -0.2, "tuck": 0.2})
		await shot("%s_take_off" % name)
		flock.pose_bird(0, Vector3(0, 0.4, 0), 0.0, {"fold": 0.0, "strength": 0.0, "bank": 0.6, "tuck": 1.0, "tail_fan": 0.6})
		_frame(Vector3(0, 0.45, 0), 1.2 * s, Vector3(0.2, 0.25, 1.0))
		await shot("%s_banked" % name)
		flock.queue_free()
		await process_frame


# --- In the maze ---

func _setup_world(code: String) -> void:
	if world:
		world.queue_free()
		await process_frame
	if stage:
		stage.queue_free()
		stage = null
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for(code, 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	for enemy in world.enemies.enemies:
		if not (enemy is Crows):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.visible = false
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false


func _maze() -> void:
	await _setup_world("SHOT")
	var murders: Array = world.enemies.enemies.filter(func(e: Node) -> bool: return e is Crows)
	print("crow murders: %d, ravens: %d" % [murders.size(), world.birds.ravens.size()])
	await wait(1.0)
	var eye := Camera3D.new()
	world.add_child(eye)
	for m in murders.size():
		var crows: Crows = murders[m]
		var flock: CorvidFlock = crows.flock
		var middle := flock.centre()
		# He stands in the hall below them, looking up at the wall top.
		var hall := maze.world(maze.cell_at(crows.global_position))
		var out := Vector3(hall.x - middle.x, 0.0, hall.z - middle.z)
		var stand := Vector3(middle.x, 0.0, middle.z) + (out.normalized() * minf(out.length() + 4.0, 10.0) if out.length() > 0.5 else Vector3(6.0, 0.0, 0.0))
		stand.y = maze.ground_height(stand)
		boy.global_position = stand + Vector3.UP * 0.1
		eye.fov = 55.0
		eye.look_at_from_position(stand + Vector3.UP * 1.5, middle)
		eye.make_current()
		await wait(1.5)
		await shot("4%d_maze_murder%d_on_the_walls" % [m * 2, m])
		eye.fov = 16.0
		eye.look_at_from_position(stand + Vector3.UP * 1.5, middle)
		await wait(0.3)
		await shot("4%d_maze_murder%d_on_the_walls_close" % [m * 2 + 1, m])
	if murders.is_empty():
		return
	var crows: Crows = murders[0]
	var flock: CorvidFlock = crows.flock
	var middle := flock.centre()
	var hall := maze.world(maze.cell_at(crows.global_position))
	var out := Vector3(hall.x - middle.x, 0.0, hall.z - middle.z)
	var stand := Vector3(middle.x, 0.0, middle.z) + (out.normalized() * minf(out.length() + 4.0, 10.0) if out.length() > 0.5 else Vector3(6.0, 0.0, 0.0))
	stand.y = maze.ground_height(stand)
	world.camera.make_current()
	var to_them := Vector3(middle.x - stand.x, 0.0, middle.z - stand.z).normalized()
	boy.global_position = stand - to_them * 3.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(to_them.x, to_them.z)
	world.camera._yaw = atan2(-to_them.x, -to_them.z)
	world.camera.snap()
	await wait(0.5)
	await shot("44_maze_game_camera")
	# He runs: they erupt, cawing, and wheel over him.
	crows.erupt_over(boy)
	eye.make_current()
	eye.fov = 70.0
	await wait(0.9)
	eye.look_at_from_position(stand + Vector3.UP * 1.5, flock.centre())
	await shot("45_maze_murder_erupting")
	await wait(3.0)
	eye.look_at_from_position(boy.global_position + Vector3.UP * 1.5, boy.global_position + Vector3.UP * 30.0 + to_them * 6.0)
	await shot("46_maze_murder_wheeling")
	await wait(2.0)
	await shot("47_maze_murder_wheeling_later")
	# A raven, close, on its wall.
	if not world.birds.ravens.is_empty():
		var pair: Ravens = world.birds.ravens[0]
		await wait(0.5)
		var at: Vector3 = pair.flock.bird_position(0)
		var p: int = pair.flock.perch_of(0)
		var face: Vector3 = pair.flock.perch_faces[p] if p >= 0 else Vector3.FORWARD
		var along := face.cross(Vector3.UP)
		eye.fov = 30.0
		eye.look_at_from_position(at + face * 1.6 + along * 0.9 + Vector3.UP * 0.35, at + Vector3.UP * 0.25)
		await wait(0.3)
		await shot("48_maze_raven_close")
		pair.flock.call_now(0)
		await wait(0.25)
		await shot("49_maze_raven_croaking")


# --- In the clearing ---

func _clearing() -> void:
	await _setup_world("SHOT")
	print("jay families: %d, clearing crows: %d" % [world.birds.jays.size(), world.birds.crows.size()])
	if world.birds.jays.is_empty():
		return
	var eye := Camera3D.new()
	world.add_child(eye)
	await wait(3.0)
	var k := 0
	for jays: BlueJays in world.birds.jays:
		for i in jays.count:
			if jays.perch_of(i) < 0 or jays.act_of(i) == CorvidFlock.Act.FLY:
				continue
			var at := jays.bird_position(i)
			var toward := Vector3(-at.x, 0.0, -at.z).normalized()
			var stand := at + toward * 7.0
			stand.y = maze.ground_height(stand)
			boy.global_position = stand + toward * 30.0
			eye.fov = 45.0
			eye.look_at_from_position(stand + Vector3.UP * 1.5, at + Vector3.UP * 0.5)
			eye.make_current()
			await wait(0.3)
			await shot("5%d_clearing_jays_in_a_pine" % k)
			eye.fov = 14.0
			eye.look_at_from_position(stand + Vector3.UP * 1.5, at + Vector3.UP * 0.1)
			await wait(0.2)
			await shot("5%d_clearing_jay_on_a_branch" % (k + 1))
			k += 2
			break
		if k >= 4:
			break
	for jays: BlueJays in world.birds.jays:
		for i in jays.count:
			if jays.perch_of(i) < 0 and jays.act_of(i) != CorvidFlock.Act.FLY:
				var at := jays.bird_position(i)
				var toward := Vector3(-at.x, 0.0, -at.z).normalized()
				eye.fov = 20.0
				eye.look_at_from_position(at + toward * 2.0 + Vector3(0.4, 0.6, 0.0), at + Vector3.UP * 0.08)
				await wait(0.2)
				await shot("56_clearing_jay_on_the_ground")
				return
