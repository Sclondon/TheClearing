extends SceneTree
## Pictures of the luck dragon (creatures/luck_dragon/, scripts/enemies/maze_luck_dragon.gd).
## First in a plain grey studio: laid along a long S, from the side, above and
## below, a coil, the head close (front, quarter, side, calling), and a strip
## of it swimming. Then in a real round (World, the game's light and mist): high
## over the outer halls seen from a wall top, coming down to circle someone
## standing in the open, its head down to look at him, him on its back over the
## walls, and set down further out; and the game's camera. Every picture of the
## round is checked for it (drawn again without it and compared). Says how many
## draws a frame takes. Needs a real window; landscape by default:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/luck_dragon_shots.gd -- <folder> [studio|maze]

var folder := "luck_dragon_shots"
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

var dragon: LuckDragon


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
	camera.far = 2000.0
	stage.add_child(camera)
	camera.make_current()

	dragon = LuckDragon.new()
	dragon.sound = false
	dragon.lod_distance = 10000.0
	stage.add_child(dragon)
	dragon.frozen = true
	# A long S along the X axis, its head at +X, rising a little.
	var s := PackedVector3Array()
	for k in 80:
		var x := -k * 0.5
		s.append(Vector3(x, sin(k * 0.04) * 1.2, sin(x / 7.0) * 3.5))
	dragon.lay_along(s)
	dragon.pose_now()
	_frame(Vector3(-16, 0, 0), 40.0, 10.0, Vector3(0.15, 0.25, 1))
	await shot("01_s_side")
	_frame(Vector3(-16, 0, 0), 40.0, 12.0, Vector3(0.0, 1, 0.05))
	await shot("02_s_above")
	_frame(Vector3(-16, 0, 0), 40.0, 12.0, Vector3(0.2, -0.6, 1))
	await shot("03_s_below")
	_frame(Vector3(-3, 0, 0), 10.0, 6.0, Vector3(0.6, 0.25, 1))
	await shot("04_front_quarter")
	# A coil, rising.
	var coil := PackedVector3Array()
	for k in 100:
		var a := -k * 0.07
		var r := 7.0 - k * 0.02
		coil.append(Vector3(cos(a) * r, k * 0.05, sin(a) * r))
	dragon.lay_along(coil)
	dragon.pose_now()
	_frame(Vector3(0, 2, 0), 18.0, 10.0, Vector3(0.6, 0.6, 1))
	await shot("05_coil")
	# The head, close.
	dragon.lay_along(s)
	dragon.aim = Vector3.INF
	dragon.pose_now()
	var head := dragon.head_point()
	_frame(head + Vector3(0.6, -0.2, 0), 3.6, 3.0, Vector3(1, 0.1, 0.05))
	await shot("06_head_front")
	_frame(head + Vector3(0.0, -0.2, 0), 4.2, 3.2, Vector3(0.7, 0.15, 0.7))
	await shot("07_head_quarter")
	_frame(head + Vector3(-0.6, -0.2, 0), 5.0, 3.2, Vector3(0.0, 0.1, 1))
	await shot("08_head_side")
	dragon.mouth = 1.0
	dragon.frozen = false
	await process_frame
	dragon.frozen = true
	dragon.pose_now()
	_frame(head + Vector3(0.0, -0.3, 0), 4.2, 3.2, Vector3(0.7, 0.0, 0.7))
	await shot("09_head_mouth_open")
	dragon.mouth = 0.0
	# Swimming: it flies a weaving path and is pictured every so often from the side.
	dragon.frozen = false
	dragon.global_position = Vector3(0, 0, 0)
	dragon.settle()
	var t := 0.0
	for frame in 60 * 6:
		t += 1.0 / 60.0
		dragon.global_position = Vector3(t * 9.0, sin(t * 0.9) * 2.0, sin(t * 0.7) * 5.0)
		await process_frame
	_frame(dragon.global_position + Vector3(-15, 0, 0), 40.0, 12.0, Vector3(0.1, 0.4, 1))
	await shot("10_swimming")
	_frame(dragon.global_position + Vector3(-15, 0, 0), 40.0, 12.0, Vector3(0.0, 1, 0.1))
	await shot("11_swimming_above")
	dragon.queue_free()
	stage.queue_free()
	await process_frame


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
var hunter: MazeLuckDragon
var eye: Camera3D
var missing: Array[String] = []


func until(seconds: float, done: Callable) -> bool:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame
		if done.call():
			return true
	return false


## A picture of the round, checked for the dragon (drawn again without it, and compared).
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
	print("    %s: it covers %d pixels (%.2f%%), %.1f m from the camera, %s" % [name, seen, 100.0 * seen / (with.get_width() * with.get_height()), cam.global_position.distance_to(hunter.global_position), MazeLuckDragon.Mode.keys()[hunter.mode]])
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
	boy.rest_enabled = false
	await until(0.5, func() -> bool: return false)
	# (nothing else hunts while the pictures are taken)
	for enemy: Node in world.enemies.get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	# An open place in the meadow, near the clearing's wall.
	var dragon := MazeLuckDragon.new()
	dragon.maze = maze
	dragon.targets = [boy]
	dragon.still_time = 1.5
	dragon.pose_range = 2000.0
	hunter = dragon
	# A wall top out in the first ring, with room round it.
	var spot := Vector3.INF
	world.add_child(dragon)
	for x in range(-90, 91, 3):
		for along: float in [340.0, 355.0, 370.0, 385.0, 400.0, 415.0]:
			var at := Vector3(along, 0.0, x * 1.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 150.0, at + Vector3.DOWN * 20.0, 1))
			if hit.is_empty() or (hit["position"] as Vector3).y < 20.0:
				continue
			dragon.global_position = Vector3(at.x, 120.0, at.z)
			if dragon.open_at(hit["position"]):
				spot = hit["position"]
				break
		if spot.is_finite():
			break
	if not spot.is_finite():
		print("NO OPEN PLACE")
		return
	print("open place at %s" % spot)
	eye = Camera3D.new()
	eye.far = 2000.0
	world.add_child(eye)
	eye.make_current()
	# High over the halls first: soaring, seen from the hall below.
	dragon._visit_rest = 9999.0
	var out := Vector3(spot.x, 0.0, spot.z).normalized()
	var hall: Vector3 = spot + out * 120.0
	hall.y = maze.ground_height(hall)
	boy.global_position = spot + Vector3.UP * 0.1
	dragon.global_position = hall + Vector3(0, 75, 0) + out.cross(Vector3.UP) * 40.0
	dragon._heading = -out.cross(Vector3.UP)
	dragon.look.rotation.y = atan2(dragon._heading.x, dragon._heading.z) - dragon.rotation.y
	dragon.look.settle()
	await until(6.0, func() -> bool: return false)
	eye.fov = 60.0
	eye.look_at_from_position(spot + Vector3.UP * 1.6 + out * 4.0, dragon.global_position + Vector3.DOWN * 4.0)
	await still("20_soaring_over_the_walls")
	eye.fov = 22.0
	eye.look_at_from_position(spot + Vector3.UP * 1.6 + out * 4.0, dragon.look.body_point(14.0))
	await still("21_soaring_close")
	# He stands still in the open: it comes.
	dragon._visit_rest = 0.0
	dragon.global_position = spot + Vector3(30, 70, 50)
	dragon.look.settle()
	boy.global_position = spot + Vector3.UP * 0.1
	boy.rotation.y = atan2(out.x, out.z)
	await until(10.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.DESCEND)
	await until(30.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.DESCEND and dragon.global_position.y < spot.y + 30.0)
	eye.fov = 60.0
	eye.look_at_from_position(spot + Vector3.UP * 1.4 - out * 14.0 + Vector3(0, 0, 6), dragon.global_position.lerp(spot, 0.4))
	await still("22_coming_down")
	await until(30.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.CIRCLE and dragon._circled > 0.5)
	eye.look_at_from_position(spot + Vector3.UP * 3.0 - out * 26.0 + out.cross(Vector3.UP) * 8.0, spot + Vector3.UP * 3.0)
	await still("23_circling_him")
	await until(30.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.GREET and dragon._path_at < 0.0)
	await until(1.5, func() -> bool: return false)
	var head: Vector3 = dragon.look.head_point()
	var side := (head - spot).cross(Vector3.UP).normalized()
	eye.fov = 50.0
	eye.look_at_from_position(spot + side * 7.0 + Vector3.UP * 2.2 - (head - spot).normalized() * 2.0, spot.lerp(head, 0.5) + Vector3.UP * 0.8)
	await still("24_face_to_face")
	world.camera.make_current()
	world.camera.snap()
	await until(0.2, func() -> bool: return false)
	await still("25_game_camera_face_to_face")
	eye.make_current()
	eye.fov = 70.0
	eye.look_at_from_position(spot + Vector3.UP * 26.0 + out * 6.0, spot)
	await still("26_coiled_round_him_from_above")
	# He climbs on and rides.
	var seat: Vector3 = dragon.look.back_point(MazeLuckDragon.SADDLE, 0.0).origin
	boy.global_position = Vector3(seat.x, spot.y + 0.1, seat.z) + side * 0.7
	await until(3.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.RIDE)
	await until(1.0, func() -> bool: return false)
	eye.fov = 45.0
	eye.look_at_from_position(boy.global_position + side * 9.0 + Vector3.UP * 3.0, boy.global_position)
	await still("27_on_its_neck")
	await until(40.0, func() -> bool: return dragon.global_position.y > spot.y + 50.0)
	await until(2.0, func() -> bool: return false)
	eye.fov = 55.0
	var fly: Vector3 = dragon._heading
	eye.look_at_from_position(boy.global_position - fly * 14.0 + Vector3.UP * 5.0 + fly.cross(Vector3.UP) * 6.0, boy.global_position + fly * 6.0)
	await still("28_riding_over_the_walls")
	world.camera.make_current()
	await until(0.3, func() -> bool: return false)
	await still("29_game_camera_riding")
	eye.make_current()
	await until(60.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.ALIGHT)
	await until(1.0, func() -> bool: return false)
	var drop: Vector3 = dragon.drop_at
	eye.fov = 55.0
	eye.look_at_from_position(drop - dragon.drop_way * 12.0 + dragon.drop_way.cross(Vector3.UP) * 3.0 + Vector3.UP * 3.0, drop + Vector3.UP * 1.5)
	await still("30_set_down_further_out")
	await until(4.0, func() -> bool: return false)
	eye.fov = 50.0
	eye.look_at_from_position(boy.global_position + Vector3.UP * 1.5 - dragon.drop_way * 3.0, dragon.global_position)
	await still("31_away_up_out_of_the_hall")
	print("set down %.1f m from where it meant, %.0f m further out" % [boy.global_position.distance_to(drop), maxf(absf(drop.x), absf(drop.z)) - maxf(absf(spot.x), absf(spot.z))])
	if missing.is_empty():
		print("IT IS IN EVERY PICTURE OF THE ROUND")
	else:
		print("NOT IN: %s" % ", ".join(missing))
