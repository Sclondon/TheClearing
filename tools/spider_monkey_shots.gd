extends SceneTree
## Pictures of the spider monkeys (creatures/spider_monkey/,
## scripts/enemies/maze_spider_monkey.gd): first in a plain grey studio, by a
## wall with a vine strung along it (hanging by tail and hand, by the tail alone
## upside down, swinging along the vine, winding up to drop, in the air,
## walking and bounding on all fours, climbing, the threat display, the face);
## then in a hall of a real round (World: the game's light and mist), a troop
## hanging over it, one dropping on the boy, and the draws a frame takes. Needs
## a real window, landscape:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/spider_monkey_shots.gd -- <folder> [studio|maze]

var folder := "spider_monkey_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves a monkey along at `speed` (m/s) the way it faces, or along `along` (world), every frame.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0
	var along := Vector3.ZERO

	func _process(delta: float) -> void:
		if along != Vector3.ZERO:
			body.global_position += along * speed * delta
		else:
			body.global_position += body.global_basis.z * speed * delta


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
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	if only == "" or only == "studio":
		await _studio()
	if only == "" or only == "maze":
		await _maze()
	quit()


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


# --- The studio ---

func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.61, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.61, 0.62)
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.49)
	floor.material_override = mat
	stage.add_child(floor)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 5.0, 0.6)
	wall.mesh = box
	wall.position = Vector3(0.0, 2.5, -0.35)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.55, 0.53)
	wall.material_override = wall_mat
	stage.add_child(wall)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()
	# The vine along the wall, 2.4 m up, its stems down to the floor.
	var vine := SpiderMonkeyVine.new()
	vine.anchors = PackedVector3Array([Vector3(-6.0, 2.5, 0.12), Vector3(-2.0, 2.45, 0.12), Vector3(2.0, 2.5, 0.12), Vector3(6.0, 2.4, 0.12)])
	vine.ground = 0.0
	vine.away = Vector3.BACK
	stage.add_child(vine)
	vine.build()

	# Hanging by tail and hand, and by the tail alone, side by side.
	var hand := _hanger(vine, 0.38, SpiderMonkey.Hang.HAND, 1)
	var tail := _hanger(vine, 0.62, SpiderMonkey.Hang.TAIL, 2)
	await wait(1.0)
	_look_from(Vector3(0.0, 1.9, 5.2), Vector3(0.0, 1.6, 0.2))
	await shot("01_hanging_pair")
	_look_from(Vector3(-1.0 + 0.5, 2.0, 2.2), hand.global_position + Vector3(0, 0.95, 0.1))
	await shot("02_hang_hand_close")
	_look_from(hand.global_position + Vector3(2.0, 0.9, 0.9), hand.global_position + Vector3(0, 0.9, 0.0))
	await shot("03_hang_hand_side")
	_look_from(tail.global_position + Vector3(-0.4, 0.8, 2.2), tail.global_position + Vector3(0, 0.75, 0.1))
	await shot("04_hang_tail_close")
	_look_from(tail.global_position + Vector3(1.9, 0.9, 1.0), tail.global_position + Vector3(0, 0.8, 0.0))
	await shot("05_hang_tail_side")
	# The face, looking at the camera.
	hand.look_at_point = hand.global_position + Vector3(0.6, 0.5, 3.0)
	await wait(0.8)
	var face := hand.head_position()
	_look_from(face + Vector3(0.12, 0.05, 0.6), face)
	await shot("06_face")
	_look_from(face + Vector3(0.45, 0.02, 0.35), face)
	await shot("07_face_three_quarter")
	hand.look_at_point = Vector3.INF
	# Rustling, and winding up to drop.
	hand.rustle(1.2)
	await wait(0.4)
	_look_from(Vector3(-1.0, 1.8, 3.6), hand.global_position + Vector3(0, 0.8, 0.0))
	await shot("08_rustle")
	hand.wind_up(1.5)
	hand.look_at_point = hand.global_position + Vector3(0.0, 0.0, 4.0)
	await wait(0.5)
	_look_from(hand.global_position + Vector3(2.4, 0.9, 1.6), hand.global_position + Vector3(0, 1.0, 0.0))
	await shot("09_wind_up")
	await wait(1.2)
	hand.look_at_point = Vector3.INF
	# Swinging along the vine, hand over hand.
	tail.visible = false
	var drive := Driver.new()
	drive.body = hand
	drive.along = Vector3.RIGHT
	drive.speed = 1.6
	stage.add_child(drive)
	await wait(1.0)
	for k in 3:
		_look_from(hand.global_position + Vector3(0.0, 1.1, 3.2), hand.global_position + Vector3(0, 0.85, 0.0))
		await shot("10_swing_%d" % k)
		await wait(0.18)
	drive.speed = 0.0
	# In the air, flung off at something below and ahead.
	hand.hanging = false
	hand.airborne = true
	var from := hand.global_position
	var t := 0.0
	while t < 0.3:
		await process_frame
		t += 1.0 / 60.0
		hand.global_position = from + Vector3(0.0, -2.0 * t, 3.0 * t)
	_look_from(hand.global_position + Vector3(2.6, 0.4, 0.4), hand.global_position + Vector3(0, 0.4, 0.0))
	await shot("11_air")
	hand.airborne = false
	hand.global_position = Vector3(hand.global_position.x, 0.0, 2.0)
	hand.rotation.y = 0.0
	# On all fours: walking, bounding, the display, climbing.
	await wait(0.6)
	drive.along = Vector3.ZERO
	drive.speed = 0.8
	await wait(1.0)
	_look_from(hand.global_position + Vector3(2.4, 0.7, 0.6), hand.global_position + Vector3(0, 0.35, 0.2))
	await shot("12_walk_a")
	await wait(0.2)
	_look_from(hand.global_position + Vector3(2.4, 0.7, 0.6), hand.global_position + Vector3(0, 0.35, 0.2))
	await shot("13_walk_b")
	drive.speed = 3.6
	await wait(1.0)
	for k in 3:
		_look_from(hand.global_position + Vector3(2.8, 0.6, 0.4), hand.global_position + Vector3(0, 0.35, 0.3))
		await shot("14_bound_%d" % k)
		await wait(0.07)
	drive.speed = 0.0
	hand.display(3.0)
	hand.look_at_point = hand.global_position + Vector3(0.0, 1.2, 4.0)
	await wait(0.8)
	_look_from(hand.global_position + Vector3(1.0, 0.8, 2.6), hand.global_position + Vector3(0, 0.6, 0.0))
	await shot("15_display")
	await wait(2.4)
	hand.look_at_point = Vector3.INF
	# Climbing the wall: its Y the wall's normal, its Z up.
	hand.clinging = true
	hand.global_transform = Transform3D(Basis(Vector3.BACK.cross(Vector3.UP), Vector3.BACK, Vector3.UP), Vector3(1.0, 0.8, 0.0))
	var climb := Driver.new()
	climb.body = hand
	climb.along = Vector3.UP
	climb.speed = 0.9
	drive.queue_free()
	stage.add_child(climb)
	await wait(1.0)
	_look_from(hand.global_position + Vector3(1.6, 0.3, 2.6), hand.global_position + Vector3(0, 0.2, 0.0))
	await shot("16_climb")
	climb.queue_free()
	hand.visible = false
	# The low-detail model (phones) beside the full one.
	var low := SpiderMonkey.new()
	low.force_low = true
	low.voice = false
	low.seed_value = 1
	low.hanging = true
	low.hold_axis = vine.axis_at(0.5)
	stage.add_child(low)
	low.global_position = vine.to_global(vine.point_at(0.5)) + Vector3.DOWN * SpiderMonkey.HANG_HIGH
	var full := _hanger(vine, 0.56, SpiderMonkey.Hang.HAND, 1)
	await wait(0.8)
	_look_from(Vector3((low.global_position.x + full.global_position.x) * 0.5, 1.8, 2.6), Vector3((low.global_position.x + full.global_position.x) * 0.5, 1.6, 0.0))
	await shot("17_low_left_full_right")
	stage.queue_free()
	await process_frame


func _hanger(vine: SpiderMonkeyVine, t: float, style: SpiderMonkey.Hang, seed_value: int) -> SpiderMonkey:
	var one := SpiderMonkey.new()
	one.hang_style = style
	one.seed_value = seed_value
	one.voice = false
	one.hanging = true
	one.hold_axis = vine.axis_at(t)
	stage.add_child(one)
	one.global_position = vine.to_global(vine.point_at(t)) + Vector3.DOWN * SpiderMonkey.HANG_HIGH * one.size
	one.settle()
	return one


# --- In the maze ---

var world
var maze
var nav
var boy


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	# (only these monkeys: the round's own enemies are put away)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	var cell := _hall_cell()
	_stand(maze.world(cell), Vector3(1, 0, 0))
	await wait(1.0)
	var bare := await _draws()
	print("draws with nobody about: %d" % bare)
	# A troop of six over the hall.
	boy.remove_from_group(&"maze_players")
	var troop := MazeSpiderMonkey.troop(6)
	for k in troop.size():
		var one: MazeSpiderMonkey = troop[k]
		one.maze = maze
		one.seed_choices(k * 13 + 3)
		one.pose_range = 1.0e9
		one.position = maze.world(cell) + Vector3.UP * 0.05
		world.add_child(one)
	await wait(1.5)
	var shared: MazeSpiderMonkey.Troop = troop[0].troop_of
	if shared.vines.is_empty():
		print("no vines strung")
		return
	var line: SpiderMonkeyVine = shared.vines[0]
	var ground: float = shared.grounds[0]
	var out: Vector3 = shared.outs[0]
	var along := line.axis_at(0.5)
	along.y = 0.0
	along = along.normalized()
	var middle: Vector3 = line.point_at(0.5) + out * 4.0
	if shared.vines.size() > 1:
		middle = (line.point_at(0.5) + shared.vines[1].point_at(0.5)) * 0.5
	middle.y = ground
	# Coming down the hall towards them, as he would see it (the game's camera).
	_stand(middle - along * 22.0, along)
	await wait(1.2)
	await shot("30_hall_coming")
	# (the draws a frame takes here with them, and with them put away)
	var with_them := await _draws()
	for one: MazeSpiderMonkey in troop:
		one.visible = false
	var without := await _draws()
	for one: MazeSpiderMonkey in troop:
		one.visible = true
	print("draws looking down the hall at a troop of six (two vines): %d, without them %d (+%d)" % [with_them, without, with_them - without])
	_stand(middle - along * 12.0, along)
	await wait(1.0)
	await shot("31_hall_nearer")
	# Under them, looking up.
	var low := Camera3D.new()
	world.add_child(low)
	low.fov = 60.0
	low.position = middle - along * 3.0 + Vector3.UP * 1.4
	low.look_at(line.point_at(0.5) + Vector3.DOWN * 0.8)
	low.make_current()
	await wait(0.3)
	await shot("32_under_them")
	# Side on, close, one hanging still.
	var one0: MazeSpiderMonkey = troop[0]
	low.position = one0.global_position + out * 3.2 + along * 1.6 + Vector3.UP * 0.4
	low.look_at(one0.global_position + Vector3.UP * 0.6)
	await wait(0.2)
	await shot("33_one_close")
	low.queue_free()
	world.camera.make_current()
	# He comes walking: they stir, and drop.
	boy.add_to_group(&"maze_players")
	var state := {"at": middle - along * 16.0}
	var walking := func() -> bool:
		var at: Vector3 = state["at"]
		at += along * 1.5 / 60.0
		state["at"] = at
		boy.global_position = Vector3(at.x, ground + 0.05, at.z)
		boy.velocity = along * 1.5
		boy.rotation.y = atan2(along.x, along.z)
		return false
	_stand(state["at"], along)
	var stirred := func() -> bool:
		walking.call()
		for one: MazeSpiderMonkey in troop:
			if one.mode == MazeSpiderMonkey.Mode.STIR:
				return true
		return false
	await wait(6.0, stirred)
	await wait(0.6, walking)
	await shot("34_they_stir")
	var winding := func() -> bool:
		walking.call()
		for one: MazeSpiderMonkey in troop:
			if one.mode == MazeSpiderMonkey.Mode.WIND and one._mode_time > 0.35:
				return true
		return false
	await wait(10.0, winding)
	await shot("35_wind_up")
	var in_air := func() -> bool:
		walking.call()
		for one: MazeSpiderMonkey in troop:
			if one.mode == MazeSpiderMonkey.Mode.DROP and one._mode_time > one._flight * 0.45:
				return true
		return false
	await wait(4.0, in_air)
	await shot("36_drop")
	var side := Camera3D.new()
	world.add_child(side)
	side.fov = 55.0
	side.position = boy.global_position + along * 5.0 + out * 2.0 + Vector3.UP * 1.6
	side.look_at(boy.global_position + Vector3.UP * 1.6)
	side.make_current()
	await process_frame
	await shot("37_drop_side")
	side.queue_free()
	world.camera.make_current()
	await wait(1.5)
	await shot("38_after")


## A cell beside a long plain stretch of wall, well out in the ring.
func _hall_cell() -> Vector2i:
	var lairs: Array = nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 3 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and (maze.blocked(cell, across) or maze.blocked(cell, -across)) \
					and not maze.blocked(cell + s, s) and not maze.blocked(cell - s, -s):
				return cell
	return lairs[0]


func _stand(at: Vector3, along: Vector3) -> void:
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z)
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(along.x, along.z)
	world.camera._yaw = atan2(-along.x, -along.z)
	world.camera.snap()


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
