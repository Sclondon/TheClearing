extends SceneTree
## Pictures of the pterodactyl (creatures/pterodactyl/, scripts/enemies/maze_pterodactyl.gd).
## First in a plain grey studio, each framed to fill most of the picture:
## standing on all fours (front quarter, side, from behind), the head close,
## the croak, the launch in eight steps, the wingbeat in eight steps from the
## side, the front and above, gliding from below and above, the dive (wings
## tucked), the snatch (feet forward), braking to land, the hand on the ground,
## its shadow. Then in a real round (World, the game's light and mist): roosting
## on a wall top, soaring over the maze seen from a hall, its shadow passing
## over the boy, the croak and the dive seen from behind him at about the game
## camera's height, the swoop, the snatch, carrying him off; and the game's
## camera. Every picture of the round is checked for it (drawn again without it
## and compared), and where it is on it printed; it ends saying whether it is in
## all of them. Says how many draws a frame takes. Needs a real window (the
## engine draws nothing headless); landscape by default:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/pterodactyl_shots.gd -- <folder> [studio|maze]

var folder := "pterodactyl_shots"
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

var ptero: Pterodactyl
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
	plane.size = Vector2(30, 30)
	ground_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.5, 0.48)
	ground_mesh.material_override = stone
	stage.add_child(ground_mesh)

	ptero = Pterodactyl.new()
	ptero.sound = false
	ptero.frozen = true
	stage.add_child(ptero)
	var middle := Vector3(0, ptero.stand_height(), 0)
	ptero.global_position = middle
	ptero.rotation.y = 0.0
	var standing := {"ground": 1.0, "effort": 0.0, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}
	ptero.hold(standing)
	_frame(middle + Vector3(0, 0.1, 0), 2.6, 2.2, Vector3(0.7, 0.2, 1))
	await shot("01_standing_quarter")
	_frame(middle + Vector3(0, 0.1, 0), 2.6, 2.2, Vector3(1, 0.05, 0.0))
	await shot("02_standing_side")
	_frame(middle + Vector3(0, 0.1, 0), 2.6, 2.2, Vector3(-0.6, 0.35, -1))
	await shot("03_standing_back")
	_frame(middle + Vector3(0, 0.1, 0), 2.6, 2.2, Vector3(0.0, 0.1, 1))
	await shot("03b_standing_front")
	var head := ptero.head_point()
	_frame(head + Vector3(0, 0.0, 0.4), 1.6, 0.8, Vector3(1, 0.1, 0.15))
	await shot("04_head")
	ptero.hold(standing, 0.0, 0.6)
	head = ptero.head_point()
	_frame(head + Vector3(0, 0.0, 0.3), 2.0, 1.2, Vector3(1, 0.05, 0.4))
	await shot("05_croak")
	# The launch, in eight steps.
	await _launch_strip("06_launch_side", Vector3(1, 0.1, 0.25), 5.5, 4.0)
	# Flying: no floor.
	ground_mesh.visible = false
	var level := Vector3(0, 2.0, 0)
	ptero.global_position = level
	var flying := {"ground": 0.0, "effort": 0.7, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0, "velocity": Vector3(0, 0, 9)}
	await _strip("07_wingbeat_side", flying, Vector3(1, 0.05, 0.0), 3.4, 3.6)
	await _strip("08_wingbeat_front", flying, Vector3(0, 0.1, 1), 7.0, 3.6)
	await _strip("08b_wingbeat_above", flying, Vector3(0.0, 1, -0.3), 7.0, 4.0)
	var gliding := flying.duplicate()
	gliding["effort"] = 0.0
	ptero.hold(gliding)
	_frame(level, 7.0, 3.0, Vector3(0.2, -1, 0.4))
	await shot("09_glide_below")
	_frame(level, 7.0, 3.0, Vector3(-0.3, 1, -0.5))
	await shot("10_glide_above")
	_frame(level, 7.0, 2.4, Vector3(0.5, 0.15, 1))
	await shot("10b_glide_front_quarter")
	var diving := flying.duplicate()
	diving["tuck"] = 1.0
	diving["velocity"] = Vector3(0, -14, 12)
	ptero.hold(diving)
	_frame(level, 3.0, 2.0, Vector3(1, 0.2, 0.2))
	await shot("11_dive_side")
	_frame(level, 3.5, 2.0, Vector3(0.3, 0.8, 1))
	await shot("11b_dive_above")
	var snatch := flying.duplicate()
	snatch["talons"] = 1.0
	snatch["effort"] = 0.2
	ptero.hold(snatch, 0.1)
	_frame(level, 7.0, 3.0, Vector3(0.5, -0.1, 1))
	await shot("12_snatch_front")
	_frame(level, 3.5, 2.6, Vector3(1, -0.05, 0.1))
	await shot("12b_snatch_side")
	snatch["grip"] = 1.0
	ptero.hold(snatch, 0.3)
	_frame(level, 3.5, 2.6, Vector3(1, -0.05, 0.1))
	await shot("12c_snatch_gripped")
	var landing := flying.duplicate()
	landing["brake"] = 1.0
	landing["talons"] = 0.6
	landing["velocity"] = Vector3(0, -1, 3)
	await _strip("13_landing_side", landing, Vector3(1, 0.05, 0.2), 5.0, 4.0)
	# The hand on the ground, close.
	ground_mesh.visible = true
	ptero.global_position = middle
	ptero.hold(standing)
	var hand := ptero.to_global(Vector3(Pterodactyl.HAND_HOME.x, -Pterodactyl.STAND_HEIGHT, Pterodactyl.HAND_HOME.y))
	_frame(hand + Vector3(0, 0.2, 0), 0.7, 0.5, Vector3(0.8, 0.4, 0.7))
	await shot("14_hand_on_ground")
	# Its shadow on the ground under it, gliding and diving.
	ptero.global_position = Vector3(0, 6.0, 0)
	ptero.hold(gliding)
	ptero.show_shadow(Vector3.ZERO, 1.0, 0.2)
	_frame(Vector3(0, 1.5, 0), 9.0, 8.0, Vector3(0.4, 1, 0.8))
	await shot("15_shadow")
	ptero.show_shadow(Vector3.INF)
	ptero.queue_free()
	stage.queue_free()
	await process_frame


## The launch in eight steps across the picture, read left to right, top to bottom.
func _launch_strip(name: String, from: Vector3, wide: float, high: float) -> void:
	var size := root.get_texture().get_image().get_size()
	var cell := Vector2i(size.x / 4, size.y / 2)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.62, 0.63, 0.64))
	var cut := Vector2i(int(size.y * float(cell.x) / cell.y), size.y)
	var start := Vector3(0, ptero.stand_height(), 0)
	for i in 8:
		var t := i / 7.0 * Pterodactyl.LAUNCH_TIME
		var lift := Pterodactyl.launch_lift(t)
		ptero.global_position = start + Vector3(0, lift.x, lift.y)
		ptero.hold({"ground": 1.0, "effort": 1.0, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}, 0.0, INF, t)
		# (the launch blends itself: what `_process` would have the ground weight at)
		ptero._w["ground"] = 1.0 - smoothstep(0.45, 0.8, t)
		ptero._phase = clampf((t - 0.62) / 0.42, 0.0, 1.0) * Pterodactyl.DOWN
		ptero._planted.clear()
		for limb: String in ["hand_l", "hand_r", "foot_l", "foot_r"]:
			var home: Vector3 = ptero._home(limb)
			ptero._planted[limb] = {"at": home - Vector3(0, 0, lift.y), "t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
		ptero._pose(0.0)
		_frame(start + Vector3(0, 1.0, 1.0), wide * float(size.x) / cut.x, high, from)
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


## Eight steps of the wingbeat, four across and two down (the first the top of the stroke, the downstroke to about the fifth).
func _strip(name: String, state: Dictionary, from: Vector3, wide: float, high: float) -> void:
	var size := root.get_texture().get_image().get_size()
	var cell := Vector2i(size.x / 4, size.y / 2)
	var sheet := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.62, 0.63, 0.64))
	var at := ptero.global_position
	var cut := Vector2i(int(size.y * float(cell.x) / cell.y), size.y)
	for i in 8:
		ptero.hold(state, i / 8.0)
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
var hunter: MazePterodactyl
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
	print("    %s: it covers %d pixels (%.2f%%), its middle at %s on screen, %.1f m from the camera, %s" % [name, seen, 100.0 * seen / (with.get_width() * with.get_height()), where.round(), cam.global_position.distance_to(hunter.global_position), MazePterodactyl.Mode.keys()[hunter.mode]])
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
	# A pterodactyl over an open hall (not hooked up to the round: it catches nobody).
	var nav := MazeNav.new(maze)
	var lairs: Array[Vector2i] = nav.lairs(4)
	var p := MazePterodactyl.new()
	p.maze = maze
	p.targets = [boy]
	p.pose_range = 1000.0
	hunter = p
	# (out of its sight while he is put in place)
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	var home := lairs[lairs.size() / 3]
	p.position = maze.world(home) + Vector3.UP * 0.05
	world.add_child(p)
	p._roost_left = 9999.0
	await until(0.3, func() -> bool: return false)
	# (a hall in the open near its roost, in its sight, for him)
	var stand := Vector3.INF
	for cell in lairs:
		var at: Vector3 = maze.world(cell)
		if at.distance_to(Vector3(p.roost.x, 0.0, p.roost.z)) > 40.0:
			continue
		boy.global_position = at + Vector3.UP * 0.1
		await physics_frame
		if p.exposed(boy) and p._sees(boy):
			stand = at
			break
	boy.global_position = maze.world(nav.lairs(1)[0]) + Vector3.UP * 0.1
	print("roost at %s, facing %s; he stands at %s" % [p.roost, p.roost_facing, stand])
	if not stand.is_finite():
		print("NO OPEN HALL IN ITS SIGHT")
		return
	eye = Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.make_current()
	var roost: Vector3 = p.roost
	var out: Vector3 = p.roost_facing
	var across := out.cross(Vector3.UP)
	# Up at it on its roost from the hall below.
	var floor_at := Vector3(roost.x, 0.0, roost.z) + out * 16.0 + across * 5.0
	eye.look_at_from_position(floor_at + Vector3.UP * 1.6, roost)
	await still("20_maze_roost_from_below")
	eye.fov = 30.0
	eye.look_at_from_position(roost + out * 7.0 + across * 3.0 + Vector3.UP * 1.0, roost + Vector3.DOWN * 0.2)
	await still("21_maze_roost_close")
	# He walks out into the hall: it croaks and launches.
	boy.global_position = stand + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	var to_it := Vector3(roost.x - stand.x, 0.0, roost.z - stand.z).normalized()
	boy.rotation.y = atan2(to_it.x, to_it.z) + PI
	await until(4.0, func() -> bool: return p.mode == MazePterodactyl.Mode.LAUNCH)
	await until(0.55, func() -> bool: return false)
	eye.fov = 34.0
	eye.look_at_from_position(roost + out * 9.0 + across * -3.0 + Vector3.DOWN * 1.0, roost + Vector3.UP * 1.0)
	await still("22_maze_launch")
	# Over him: its shadow on him, the croak.
	await until(12.0, func() -> bool: return p.mode == MazePterodactyl.Mode.PASS and Vector2(p.global_position.x - stand.x, p.global_position.z - stand.z).length() < 9.0)
	eye.fov = 62.0
	eye.look_at_from_position(stand + Vector3.UP * 1.3 + across * 0.6, p.global_position)
	await still("23_maze_over_him")
	eye.fov = 55.0
	eye.look_at_from_position(stand + Vector3.UP * 7.5 - to_it * 6.0 + across * 3.0, stand)
	print("    shadow: %s at %s (it at %s, he at %s)" % [p.look._shadow.visible if p.look._shadow else false, p.look._shadow.global_position if p.look._shadow else Vector3.INF, p.global_position, boy.global_position])
	await still("24_maze_shadow_over_him")
	await until(5.0, func() -> bool: return p.mode == MazePterodactyl.Mode.WHEEL)
	await until(1.5, func() -> bool: return false)
	eye.fov = 40.0
	eye.look_at_from_position(stand + Vector3.UP * 1.3, p.global_position)
	await still("25_maze_wheeling")
	# The dive, seen from behind him at about the game camera's height, looking the way it comes.
	await until(18.0, func() -> bool: return p.mode == MazePterodactyl.Mode.DIVE)
	var way: Vector3 = p.dive_way
	var side := way.cross(Vector3.UP)
	boy.rotation.y = atan2(way.x, way.z)
	var behind: Vector3 = boy.global_position - way * 4.5 + side * 1.0 + Vector3.UP * 2.4
	eye.fov = 34.0
	eye.look_at_from_position(behind, p.global_position)
	await still("26_dive_begins")
	eye.fov = 64.0
	var follow := func() -> void:
		var head: Vector3 = boy.global_position + Vector3.UP * 1.2
		eye.look_at_from_position(behind, head.lerp(p.global_position, 0.6))
	await until(4.0, func() -> bool: return p.mode == MazePterodactyl.Mode.DIVE and p._time_to_target() < 1.3)
	follow.call()
	await still("27_dive_mid")
	await until(2.0, func() -> bool: return p.mode == MazePterodactyl.Mode.DIVE and p._time_to_target() < 0.6)
	follow.call()
	await still("28_dive_feet_out")
	await until(2.0, func() -> bool: return p.mode != MazePterodactyl.Mode.DIVE or p._time_to_target() < 0.05)
	follow.call()
	await still("29_the_snatch")
	await until(1.0, func() -> bool: return p.mode == MazePterodactyl.Mode.CARRY and p._mode_time > 0.7)
	eye.look_at_from_position(behind, p.global_position)
	await still("30_carried_off")
	print("    %s (feet within %.2f m)" % ["snatched him" if p.snatched else "MISSED", p.closest])
	world.camera.make_current()
	await still("31_game_camera_carried")
	# Soaring high over the maze, seen from a hall.
	await until(12.0, func() -> bool: return p.mode == MazePterodactyl.Mode.SOAR)
	await until(3.0, func() -> bool: return false)
	boy.global_position = stand + Vector3.UP * 0.1
	eye.make_current()
	eye.fov = 60.0
	eye.look_at_from_position(stand + Vector3.UP * 1.5, p.global_position)
	await still("32_soaring_over_the_maze")
	if missing.is_empty():
		print("IT IS IN EVERY PICTURE OF THE ROUND")
	else:
		print("NOT IN: %s" % ", ".join(missing))
