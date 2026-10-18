extends SceneTree
## Pictures of the harpy (creatures/harpy/, scripts/enemies/maze_harpy.gd).
## First in a plain grey studio, each framed to fill most of the picture:
## perched on a block (front, side, mantled), the face close (still, and
## screeching), the screech whole, the wingbeat in eight steps from the side
## and from the front, gliding from below and above, the stoop, the strike
## (talons forward), braking to land, the feet gripping, the claws at the
## wrist. Then in a real round (World, the game's light and mist): on a ledge
## up a wall seen from the hall, the screech, circling over the walls, the
## swoop down the hall at the boy, close as it passes, and the game's camera.
## Says how many draws a frame takes. Needs a real window (the engine draws
## nothing headless); landscape by default:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/harpy_shots.gd -- <folder> [studio|maze]

var folder := "harpy_shots"
var only := ""
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	# (landscape, unless the command line says otherwise)
	if not OS.get_cmdline_args().has("--resolution"):
		root.size = Vector2i(1280, 720)
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
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


# --- The studio ---

var harpy: Harpy


func _studio() -> void:
	var stage := Node3D.new()
	stage.name = "Studio"
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.55
	var surround := WorldEnvironment.new()
	surround.environment = env
	stage.add_child(surround)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.shadow_enabled = true
	stage.add_child(key)
	key.look_at_from_position(Vector3(1.5, 4, 3), Vector3.ZERO)
	var back := DirectionalLight3D.new()
	back.light_energy = 0.5
	stage.add_child(back)
	back.look_at_from_position(Vector3(-1, 2.5, -4), Vector3.ZERO)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()
	# A block to perch on.
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 2.0, 1.2)
	block.mesh = box
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.42, 0.4)
	block.material_override = stone
	block.position = Vector3(0, -1.0, -0.2)
	stage.add_child(block)

	harpy = Harpy.new()
	harpy.sound = false
	harpy.frozen = true
	stage.add_child(harpy)
	var middle := Vector3(0, harpy.stand_height(), 0)
	harpy.global_position = middle
	harpy.rotation.y = 0.0
	# (facing us, as we look from +Z)
	harpy.hold({"perched": 1.0, "mantle": 0.0, "grip": 1.0})
	_frame(middle + Vector3(0, -0.1, 0), 1.6, 1.8, Vector3(0.0, 0.15, 1))
	await shot("01_perched_front")
	_frame(middle + Vector3(0, -0.1, 0), 1.6, 1.8, Vector3(1, 0.1, 0.0))
	await shot("02_perched_side")
	_frame(middle + Vector3(0, -0.1, 0), 1.6, 1.8, Vector3(-0.6, 0.4, -1))
	await shot("02b_perched_back")
	harpy.hold({"perched": 1.0, "mantle": 1.0, "grip": 1.0})
	_frame(middle + Vector3(0, 0.0, 0), 2.4, 1.9, Vector3(0.6, 0.2, 1))
	await shot("03_mantled_quarter")
	_frame(middle + Vector3(0, 0.0, 0), 2.4, 1.9, Vector3(0.0, -0.35, 1))
	await shot("03b_mantled_from_below")
	# The face, close: still, and screeching.
	harpy.hold({"perched": 1.0, "mantle": 0.0, "grip": 1.0})
	var head := harpy.head_point()
	_frame(head + Vector3(0, -0.05, 0), 0.4, 0.4, Vector3(0.15, -0.1, 1))
	await shot("04_face")
	_frame(head + Vector3(0, -0.05, 0), 0.45, 0.45, Vector3(0.3, -0.3, 1))
	harpy.aim = camera.global_position
	harpy.hold({"perched": 1.0, "mantle": 0.0, "grip": 1.0}, 0.0, 1.0)
	head = harpy.head_point()
	_frame(head + Vector3(0, -0.02, 0), 0.4, 0.4, Vector3(0.3, -0.3, 1))
	harpy.aim = camera.global_position
	harpy.hold({"perched": 1.0, "mantle": 0.0, "grip": 1.0}, 0.0, 1.0)
	await shot("05_face_screeching")
	harpy.aim = Vector3.INF
	_frame(middle + Vector3(0, 0.4, 0), 3.6, 2.4, Vector3(0.3, 0.05, 1))
	await shot("06_screech_whole")

	# Flying: no block.
	block.visible = false
	var level := Vector3(0, 1.5, 0)
	harpy.global_position = level
	var flying := {"perched": 0.0, "mantle": 0.0, "effort": 0.8, "brake": 0.0, "stoop": 0.0, "talons": 0.0, "grip": 0.0, "velocity": Vector3(0, 0, 6)}
	await _strip("07_wingbeat_side", flying, Vector3(1, 0.05, 0.0), 2.6, 1.9)
	await _strip("08_wingbeat_front", flying, Vector3(0, 0.1, 1), 4.4, 1.9)
	await _strip("08b_wingbeat_above", flying, Vector3(0.0, 1, -0.3), 4.4, 2.4)
	var gliding := flying.duplicate()
	gliding["effort"] = 0.0
	harpy.hold(gliding)
	_frame(level, 4.4, 2.0, Vector3(0.2, -1, 0.4))
	await shot("09_glide_below")
	_frame(level, 4.4, 2.0, Vector3(-0.3, 1, -0.5))
	await shot("10_glide_above")
	var stooping := flying.duplicate()
	stooping["stoop"] = 1.0
	stooping["velocity"] = Vector3(0, -8, 10)
	harpy.hold(stooping)
	_frame(level, 2.4, 1.8, Vector3(1, 0.2, 0.2))
	await shot("11_stoop_side")
	_frame(level, 2.4, 1.8, Vector3(0.3, 0.3, 1))
	await shot("11b_stoop_front")
	var striking := flying.duplicate()
	striking["talons"] = 1.0
	striking["effort"] = 0.3
	harpy.hold(striking, 0.1)
	_frame(level, 3.6, 2.2, Vector3(0.5, 0.1, 1))
	await shot("12_strike_front")
	_frame(level, 3.0, 2.2, Vector3(1, 0.05, 0.1))
	await shot("12b_strike_side")
	var landing := flying.duplicate()
	landing["brake"] = 1.0
	landing["talons"] = 0.6
	landing["velocity"] = Vector3(0, -1, 2)
	await _strip("13_landing_side", landing, Vector3(1, 0.05, 0.2), 3.0, 2.4)
	# The feet, gripping the block; the claws at the wrist.
	block.visible = true
	harpy.global_position = middle
	harpy.hold({"perched": 1.0, "mantle": 0.0, "grip": 1.0, "effort": 0.0, "talons": 0.0, "brake": 0.0, "stoop": 0.0})
	_frame(Vector3(0, 0.12, 0.05), 0.6, 0.35, Vector3(0.5, 0.35, 1))
	await shot("14_feet")
	harpy.global_position = level
	harpy.hold(gliding)
	var wrist := harpy.to_global(Vector3(1.05, 0.0, 0.05))
	_frame(wrist, 0.4, 0.3, Vector3(0.4, 0.5, 1))
	await shot("15_wrist_claws")
	harpy.queue_free()
	stage.queue_free()
	await process_frame


## Eight steps of the wingbeat, four across and two down (read left to right,
## top to bottom; the first is the top of the stroke, the downstroke to the fifth).
func _strip(name: String, state: Dictionary, from: Vector3, wide: float, high: float) -> void:
	var view := Vector2(root.get_visible_rect().size)
	var size := root.get_texture().get_image().get_size()
	var cell := Vector2i(size.x / 4, size.y / 2)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.62, 0.63, 0.64))
	var at := harpy.global_position
	# (each cell is the middle of the picture, as wide as the cell's shape lets it be)
	var cut := Vector2i(int(size.y * float(cell.x) / cell.y), size.y)
	for i in 8:
		harpy.hold(state, i / 8.0)
		_frame(at, wide * float(size.x) / cut.x, high, from)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var piece := picture.get_region(Rect2i((size.x - cut.x) / 2, 0, cut.x, cut.y))
		piece.convert(Image.FORMAT_RGBA8)
		piece.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(piece, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 4) * cell.x, (i / 4) * cell.y))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


## Puts the camera looking at `at` from the way `from` points (out from it),
## near enough that something `wide` by `high` fills about 70% of the frame.
func _frame(at: Vector3, wide: float, high: float, from: Vector3) -> void:
	var size := Vector2(root.get_visible_rect().size)
	var down := tan(deg_to_rad(camera.fov) * 0.5)
	var across := down * size.x / size.y
	var distance := maxf(wide / 0.7 * 0.5 / across, high / 0.7 * 0.5 / down)
	var up := Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.BACK
	camera.look_at_from_position(at + from.normalized() * distance, at, up)


# --- In the maze ---

var world
var maze
var boy
var hunter: MazeHarpy


## A picture of the round with the harpy held still for it (at its speed a frame is a long way).
func still(name: String) -> void:
	hunter.process_mode = Node.PROCESS_MODE_DISABLED
	hunter.look.frozen = true
	await shot(name)
	hunter.process_mode = Node.PROCESS_MODE_INHERIT
	hunter.look.frozen = false


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	boy = world.player
	boy.takes_input = false
	await wait(0.5)
	# A harpy in a hallway, as MazeEnemies would put it (not caught by it: it is not hooked up to the round).
	var nav := MazeNav.new(maze)
	var harpy := MazeHarpy.new()
	harpy.maze = maze
	harpy.targets = [boy]
	harpy.circle_time = Vector2(4.0, 4.0)
	harpy.pose_range = 1000.0
	hunter = harpy
	var cell: Vector2i = nav.lairs(4)[nav.lairs(4).size() / 2]
	harpy.position = maze.world(cell) + Vector3.UP * 0.05
	# (out of his sight while he is put in place)
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	world.add_child(harpy)
	await wait(0.3)
	var perch: Vector3 = harpy.perch
	var out: Vector3 = harpy.perch_out
	var across := out.cross(Vector3.UP)
	print("perch at %s, %.1f m up, out %s" % [perch, perch.y, out])
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.make_current()
	# Up at it on its ledge from down the hall.
	var floor_at := Vector3(perch.x, 0.0, perch.z) + out * 14.0 + across * 6.0
	eye.look_at_from_position(floor_at + Vector3.UP * 1.6, perch)
	await wait(0.5)
	await shot("20_maze_perched_from_below")
	eye.fov = 30.0
	eye.look_at_from_position(perch + out * 5.0 + across * 2.5 + Vector3.DOWN * 1.0, perch + Vector3.DOWN * 0.3)
	await wait(0.3)
	await shot("21_maze_perched_close")
	# He walks out into the hall in front of it: it screeches.
	var stand := Vector3(perch.x, 0.0, perch.z) + out * 9.0
	boy.global_position = stand + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(-out.x, -out.z)
	await wait(4.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.SCREECH)
	await wait(0.7)
	eye.fov = 34.0
	eye.look_at_from_position(perch + out * 4.0 + across * -1.5 + Vector3.DOWN * 0.6, perch)
	await still("22_maze_screech")
	eye.fov = 50.0
	eye.look_at_from_position(stand + Vector3.UP * 1.2 - out * 3.0 + across * 2.0, perch)
	await still("22b_maze_screech_from_him")
	await wait(9.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.CIRCLE)
	await wait(1.0)
	eye.fov = 60.0
	eye.look_at_from_position(stand + Vector3.UP * 1.0 + across * 1.0, harpy.global_position)
	await still("23_maze_circling")
	eye.fov = 14.0
	eye.look_at_from_position(stand + Vector3.UP * 1.0 + across * 1.0, harpy.global_position)
	await still("23b_maze_circling_close")
	eye.fov = 60.0
	await wait(10.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.STOOP)
	await wait(0.4)
	eye.look_at_from_position(stand + Vector3.UP * 1.2 + across * 1.5, harpy.global_position)
	await still("24_maze_stoop")
	await wait(4.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.DIVE and harpy._time_to_target() < 1.3)
	var along: Vector3 = harpy.dive_along
	var side := along.cross(Vector3.UP)
	eye.fov = 55.0
	eye.look_at_from_position(boy.global_position + Vector3.UP * 1.0 + along * 2.5 + side * 2.0, harpy.global_position)
	await still("25_maze_dive")
	await wait(2.0, func() -> bool: return harpy._time_to_target() < 0.3)
	eye.look_at_from_position(boy.global_position + Vector3.UP * 0.9 + along * 3.0 + side * 2.2, boy.global_position + Vector3.UP * 1.2 - along * 1.5)
	await still("26_maze_talons")
	await wait(0.25)
	world.camera.make_current()
	await still("27_maze_game_camera_passing")
	await wait(1.0)
	await still("28_maze_game_camera_after")
