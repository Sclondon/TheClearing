extends SceneTree
## Pictures of the wyvern (creatures/wyvern/, scripts/enemies/maze_wyvern.gd).
## First in a plain grey studio, each framed to fill most of the picture:
## standing (front quarter, side, from behind, the front), the head close, the
## scream, the tail lash in eight steps (side and front quarter), the launch in
## eight steps, the wingbeat in eight steps from the side and the front, gliding
## from below and above, the dive (wings drawn in), the snatch (feet forward),
## the hand on the ground, the nest, its shadow. Then in a real round (World,
## the game's light and mist): the pair on their nest on a wall top seen from
## the hall below and close, the launch, over the boy (its shadow on him), the
## dive seen from behind him at about the game camera's height, the snatch;
## landed in a hall, stalking him, the wind-up and the lash seen from behind
## him; and the game's camera. Every picture of the round is checked for it
## (drawn again without it and compared), and where it is on it printed; it ends
## saying whether it is in all of them. Says how many draws a frame takes. Needs
## a real window (the engine draws nothing headless); landscape by default:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/wyvern_shots.gd -- <folder> [studio|maze]

var folder := "wyvern_shots"
var only := ""
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	if not OS.get_cmdline_args().has("--resolution"):
		root.size = Vector2i(1280, 720)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


# --- The studio ---

var wyv: Wyvern
var ground_mesh: MeshInstance3D


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
	ground_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.48)
	ground_mesh.material_override = stone
	stage.add_child(ground_mesh)

	wyv = Wyvern.new()
	wyv.sound = false
	wyv.frozen = true
	stage.add_child(wyv)
	var middle := Vector3(0, wyv.stand_height(), 0)
	wyv.global_position = middle
	wyv.rotation.y = 0.0
	var standing := {"ground": 1.0, "effort": 0.0, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}
	wyv.hold(standing)
	var body := middle + Vector3(0, 0.3, -0.6)
	_frame(body, 5.0, 3.0, Vector3(0.7, 0.2, 1))
	await shot("01_standing_quarter")
	_frame(body, 5.6, 3.0, Vector3(1, 0.05, 0.0))
	await shot("02_standing_side")
	_frame(body, 5.0, 3.0, Vector3(-0.6, 0.35, -1))
	await shot("03_standing_back")
	_frame(body + Vector3(0, 0, 0.6), 3.4, 3.0, Vector3(0.0, 0.1, 1))
	await shot("03b_standing_front")
	var head := wyv.head_point()
	_frame(head + Vector3(0, 0.0, 0.25), 1.3, 0.8, Vector3(1, 0.15, 0.4))
	await shot("04_head")
	wyv.hold(standing, 0.0, 0.7)
	head = wyv.head_point()
	_frame(head + Vector3(0, -0.1, 0.0), 2.4, 1.5, Vector3(1, 0.05, 0.5))
	await shot("05_shriek")
	# The lash, in eight steps.
	await _strike_strip("06_lash_side", Vector3(1, 0.1, 0.1), 6.5, 4.2)
	await _strike_strip("06b_lash_quarter", Vector3(0.6, 0.25, 1), 5.5, 4.2)
	wyv.hold(standing, 0.0, INF, INF, Wyvern.COIL_TIME * 0.95)
	_frame(body + Vector3(0, 0.6, 0), 5.0, 4.0, Vector3(0.8, 0.2, 0.7))
	await shot("06c_coiled")
	# The launch, in eight steps.
	await _launch_strip("07_launch_side", Vector3(1, 0.1, 0.25), 7.5, 5.0)
	# Flying: no floor.
	ground_mesh.visible = false
	var level := Vector3(0, 3.0, 0)
	wyv.global_position = level
	var flying := {"ground": 0.0, "effort": 0.7, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0, "velocity": Vector3(0, 0, 10)}
	await _strip("08_wingbeat_side", flying, Vector3(1, 0.05, 0.0), 6.5, 5.0)
	await _strip("09_wingbeat_front", flying, Vector3(0, 0.1, 1), 9.5, 5.0)
	var gliding := flying.duplicate()
	gliding["effort"] = 0.0
	wyv.hold(gliding)
	_frame(level + Vector3(0, 0, -0.6), 9.5, 5.0, Vector3(0.2, -1, 0.4))
	await shot("10_glide_below")
	_frame(level + Vector3(0, 0, -0.6), 9.5, 5.0, Vector3(-0.3, 1, -0.5))
	await shot("11_glide_above")
	_frame(level, 9.5, 3.5, Vector3(0.5, 0.15, 1))
	await shot("12_glide_front_quarter")
	var diving := flying.duplicate()
	diving["tuck"] = 1.0
	diving["velocity"] = Vector3(0, -14, 12)
	wyv.hold(diving)
	_frame(level + Vector3(0, 0, -0.6), 5.5, 3.0, Vector3(1, 0.3, 0.3))
	await shot("13_dive")
	var snatch := flying.duplicate()
	snatch["talons"] = 1.0
	snatch["effort"] = 0.2
	wyv.hold(snatch, 0.1)
	_frame(level, 9.0, 4.0, Vector3(0.5, -0.1, 1))
	await shot("14_snatch_front")
	_frame(level + Vector3(0, -0.3, -0.5), 6.0, 3.5, Vector3(1, -0.05, 0.1))
	await shot("14b_snatch_side")
	# The hand on the ground, close.
	ground_mesh.visible = true
	wyv.global_position = middle
	wyv.hold(standing)
	var hand := wyv.to_global(Vector3(Wyvern.HAND_HOME.x * Wyvern.MODEL_SCALE, -Wyvern.STAND_HEIGHT, Wyvern.HAND_HOME.y * Wyvern.MODEL_SCALE))
	_frame(hand + Vector3(0, 0.3, 0), 1.2, 0.9, Vector3(0.8, 0.4, 0.7))
	await shot("15_hand_on_ground")
	# The nest, and it stood in it.
	var nest := WyvernNest.new()
	stage.add_child(nest)
	nest.global_position = Vector3(0, 0, -0.5)
	_frame(Vector3(0, 0.6, -0.5), 6.0, 3.0, Vector3(0.6, 0.6, 1))
	await shot("16_nest")
	nest.queue_free()
	# Its shadow on the ground under it, gliding.
	wyv.global_position = Vector3(0, 8.0, 0)
	wyv.hold(gliding)
	wyv.show_shadow(Vector3.ZERO, 1.0, 0.2)
	_frame(Vector3(0, 2.0, 0), 12.0, 10.0, Vector3(0.4, 1, 0.8))
	await shot("17_shadow")
	wyv.show_shadow(Vector3.INF)
	wyv.queue_free()
	stage.queue_free()
	await process_frame


## Eight pictures in one sheet, four across and two down, from `pose` (called with each step 0..7).
func _sheet(name: String, from: Vector3, wide: float, high: float, at: Vector3, pose: Callable) -> void:
	var size := root.get_texture().get_image().get_size()
	var cell := Vector2i(size.x / 4, size.y / 2)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.62, 0.63, 0.64))
	var cut := Vector2i(int(size.y * float(cell.x) / cell.y), size.y)
	for i in 8:
		pose.call(i)
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


func _strike_strip(name: String, from: Vector3, wide: float, high: float) -> void:
	var middle := Vector3(0, wyv.stand_height(), 0)
	wyv.global_position = middle
	var times := [0.0, 0.4, 0.8, 1.05, 1.18, 1.28, 1.6, 2.1]
	await _sheet(name, from, wide, high, middle + Vector3(0, 0.6, 0.2), func(i: int) -> void:
		wyv.hold({"ground": 1.0, "effort": 0.0, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}, 0.0, INF, INF, times[i])
		print("    lash at %.2f s: the barb at %s from its middle's foot" % [times[i], (wyv.to_local(wyv.barb_point()) + Vector3.UP * wyv.stand_height()).snapped(Vector3.ONE * 0.01)]))


func _launch_strip(name: String, from: Vector3, wide: float, high: float) -> void:
	var start := Vector3(0, wyv.stand_height(), 0)
	await _sheet(name, from, wide, high, start + Vector3(0, 1.4, 1.4), func(i: int) -> void:
		var t := i / 7.0 * Wyvern.LAUNCH_TIME
		var lift := Wyvern.launch_lift(t)
		wyv.global_position = start + Vector3(0, lift.x, lift.y)
		wyv.hold({"ground": 1.0, "effort": 1.0, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}, 0.0, INF, t)
		# (the launch blends itself: what `_process` would have the ground weight at)
		wyv._w["ground"] = 1.0 - smoothstep(0.45, 0.8, t)
		wyv._phase = clampf((t - 0.64) / 0.45, 0.0, 1.0) * Wyvern.DOWN
		wyv._planted.clear()
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			var home: Vector3 = wyv._home(limb)
			wyv._planted[limb] = {"at": home - Vector3(0, 0, lift.y), "t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
		wyv._pose(0.0))


## Eight steps of the wingbeat (the first the top of the stroke, the downstroke to about the fifth).
func _strip(name: String, state: Dictionary, from: Vector3, wide: float, high: float) -> void:
	await _sheet(name, from, wide, high, wyv.global_position, func(i: int) -> void: wyv.hold(state, i / 8.0))


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
var hunter: MazeWyvern
var eye: Camera3D
## Pictures in the round that did not show it (each one is checked).
var missing: Array[String] = []


## Physics frames until `done` is true (or `seconds` of game time pass).
func until(seconds: float, done: Callable) -> bool:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame
		if done.call():
			return true
	return false


## A picture of the round with it held still for it, checked: drawn again with
## it hidden, and the difference counted. Says where on the picture it is.
func still(name: String) -> void:
	hunter.process_mode = Node.PROCESS_MODE_DISABLED
	hunter.look.frozen = true
	await shot(name)
	var with := root.get_texture().get_image()
	hunter.look.visible = false
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var without := root.get_texture().get_image()
	hunter.look.visible = true
	var cam := root.get_viewport().get_camera_3d()
	var seen := _differ(with, without)
	var where := cam.unproject_position(hunter.global_position) if cam.is_position_in_frustum(hunter.global_position) else Vector2(-1, -1)
	print("    %s: it covers %d pixels (%.2f%%), its middle at %s on screen, %.1f m from the camera, %s" % [name, seen, 100.0 * seen / (with.get_width() * with.get_height()), where.round(), cam.global_position.distance_to(hunter.global_position), MazeWyvern.Mode.keys()[hunter.mode]])
	if seen < 200:
		missing.append(name)
	hunter.process_mode = Node.PROCESS_MODE_INHERIT
	hunter.look.frozen = false


func _differ(a: Image, b: Image) -> int:
	var count := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.06:
				count += 4
	return count


func _wyvern(cell: Vector2i, seed_value: int, landing: float) -> MazeWyvern:
	var w := MazeWyvern.new()
	w.maze = maze
	w.targets = [boy]
	w.pose_range = 1000.0
	w.land_chance = landing
	w.position = maze.world(cell) + Vector3.UP * 0.05
	w.seed_choices(seed_value)
	world.add_child(w)
	w._roost_left = 9999.0
	w._keen_left = 9999.0
	return w


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	boy = world.player
	boy.takes_input = false
	# (the round's own hunters taken out: only it in the pictures)
	if world.enemies:
		for other: Node in world.enemies.get_children():
			other.process_mode = Node.PROCESS_MODE_DISABLED
			(other as Node3D).visible = false
			(other as Node3D).global_position += Vector3.DOWN * 500.0
	await until(0.5, func() -> bool: return false)
	var nav := MazeNav.new(maze)
	var lairs: Array[Vector2i] = nav.lairs(4)
	# (out of its sight while he is put in place)
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	var home := lairs[lairs.size() / 3]
	hunter = _wyvern(home, 11, 0.0)
	var mate := _wyvern(home, 12, 0.0)
	await until(0.3, func() -> bool: return false)
	mate.keen = false
	# (a hall in the open near the nest, in its sight, with room to land, for him)
	var stand := Vector3.INF
	for cell in lairs:
		var at: Vector3 = maze.world(cell)
		if at.distance_to(Vector3(hunter.roost.x, 0.0, hunter.roost.z)) > 45.0:
			continue
		boy.global_position = at + Vector3.UP * 0.1
		await physics_frame
		if hunter.exposed(boy) and hunter._sees(boy) and hunter._landing_spot(boy, hunter._ways_down(boy)[0]).is_finite():
			stand = at
			break
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	print("nest at %s, facing %s; he stands at %s" % [hunter.nest_at, hunter.roost_facing, stand])
	if not stand.is_finite():
		print("NO OPEN HALL IN ITS SIGHT")
		return
	eye = Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.make_current()
	var roost: Vector3 = hunter.nest_at
	var out: Vector3 = hunter.roost_facing
	var across := out.cross(Vector3.UP)
	# Up at the pair on their nest from the hall below.
	var floor_at := Vector3(roost.x, 0.0, roost.z) + out * 18.0 + across * 5.0
	floor_at.y = maze.ground_height(floor_at)
	eye.look_at_from_position(floor_at + Vector3.UP * 1.6, roost + Vector3.UP * 1.5)
	await still("20_maze_nest_from_below")
	eye.fov = 32.0
	eye.look_at_from_position(roost + out * 9.0 + across * 4.0 + Vector3.UP * 3.0, roost + Vector3.UP * 0.8)
	await still("21_maze_nest_close")
	# He walks out into the hall: it screams and launches.
	boy.global_position = stand + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	var to_it := Vector3(roost.x - stand.x, 0.0, roost.z - stand.z).normalized()
	boy.rotation.y = atan2(to_it.x, to_it.z) + PI
	await until(4.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.LAUNCH)
	await until(0.6, func() -> bool: return false)
	eye.fov = 36.0
	eye.look_at_from_position(roost + out * 11.0 + across * -3.0 + Vector3.DOWN * 1.0, roost + Vector3.UP * 2.0)
	await still("22_maze_launch")
	await until(14.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.PASS and Vector2(hunter.global_position.x - stand.x, hunter.global_position.z - stand.z).length() < 9.0)
	eye.fov = 62.0
	eye.look_at_from_position(stand + Vector3.UP * 1.3 + across * 0.6, hunter.global_position)
	await still("23_maze_over_him")
	eye.fov = 55.0
	eye.look_at_from_position(stand + Vector3.UP * 7.5 - to_it * 6.0 + across * 3.0, stand)
	await still("24_maze_shadow_over_him")
	# The dive, seen from behind him at about the game camera's height, looking the way it comes.
	await until(22.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.DIVE)
	var way: Vector3 = hunter.dive_way
	var side := way.cross(Vector3.UP)
	boy.rotation.y = atan2(way.x, way.z)
	var behind: Vector3 = boy.global_position - way * 4.5 + side * 1.0 + Vector3.UP * 2.4
	eye.fov = 34.0
	eye.look_at_from_position(behind, hunter.global_position)
	await still("25_dive_begins")
	eye.fov = 64.0
	await until(4.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.DIVE and hunter._time_to_target() < 0.6)
	var head: Vector3 = boy.global_position + Vector3.UP * 1.2
	eye.look_at_from_position(behind, head.lerp(hunter.global_position, 0.6))
	await still("26_dive_feet_out")
	await until(1.5, func() -> bool: return hunter.mode == MazeWyvern.Mode.CARRY and hunter._mode_time > 0.6)
	eye.look_at_from_position(behind, hunter.global_position)
	await still("27_carried_off")
	print("    %s (feet within %.2f m)" % ["snatched him" if hunter.snatched else "MISSED", hunter.closest])
	# Landed in the hall to stalk him; the coil and the lash.
	await until(3.0, func() -> bool: return false)
	hunter.process_mode = Node.PROCESS_MODE_DISABLED
	hunter.look.visible = false
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	hunter = _wyvern(home, 21, 1.0)
	await until(0.5, func() -> bool: return false)
	boy.global_position = stand + Vector3.UP * 0.1
	await until(40.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.ALIGHT and hunter._mode_time > 1.2)
	var landing: Vector3 = hunter.land_at
	var from_boy := landing - stand
	from_boy.y = 0.0
	from_boy = from_boy.normalized()
	boy.rotation.y = atan2(from_boy.x, from_boy.z)
	var over_shoulder := stand - from_boy * 4.0 + from_boy.cross(Vector3.UP) * 1.2 + Vector3.UP * 2.4
	eye.fov = 50.0
	eye.look_at_from_position(over_shoulder, landing + Vector3.UP * 1.5)
	await still("28_alighting")
	await until(6.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.STALK and hunter._mode_time > 1.0)
	eye.look_at_from_position(over_shoulder, hunter.global_position + Vector3.UP * 0.5)
	await still("29_stalking")
	await until(12.0, func() -> bool: return hunter.mode == MazeWyvern.Mode.LASH and hunter._mode_time > Wyvern.COIL_TIME * 0.85)
	eye.look_at_from_position(over_shoulder, hunter.global_position + Vector3.UP * 1.2)
	await still("30_coiled")
	world.camera.make_current()
	await still("31_game_camera_coiled")
	eye.make_current()
	await until(1.0, func() -> bool: return hunter._mode_time > Wyvern.STRIKE_LAND - 0.02)
	eye.look_at_from_position(over_shoulder, hunter.global_position + Vector3.UP * 0.6)
	await still("32_the_lash")
	if missing.is_empty():
		print("IT IS IN EVERY PICTURE OF THE ROUND")
	else:
		print("NOT IN: %s" % ", ".join(missing))
