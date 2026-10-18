extends SceneTree
## Pictures of the baboons (creatures/baboon/, scripts/enemies/maze_baboon.gd):
## first in a plain grey studio, close (the alpha and a baboon from the front,
## the side and three-quarters, the mandrill's face) and caught in the middle
## of each thing they do (walk, gallop, sit, bark, the display, the leap); then
## in a passage of a real round (World: the game's light and mist), a pack
## coming, and the draws a frame takes. Needs a real window:
##
##     godot --path . --resolution 720x1280 -s res://tools/baboon_shots.gd -- <folder> [studio|maze]

var folder := "baboon_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves a baboon along at `speed` (m/s) the way it faces, every frame.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0
	var turn := 0.0

	func _process(delta: float) -> void:
		body.rotation.y += turn * delta
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
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


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
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()

	var alpha := Baboon.new()
	alpha.kind = Baboon.Kind.ALPHA
	stage.add_child(alpha)
	var baboon := Baboon.new()
	baboon.kind = Baboon.Kind.BABOON
	baboon.seed_value = 4
	stage.add_child(baboon)
	baboon.position = Vector3(2.4, 0.0, -0.6)
	await wait(0.4)
	# The two side by side, three-quarters, and from the front, the side.
	_look_from(Vector3(6.5, 2.4, 8.5), Vector3(1.2, 0.8, 0.3))
	await shot("01_pair_three_quarter")
	_look_from(Vector3(1.2, 1.3, 9.0), Vector3(1.2, 0.8, 0.0))
	await shot("02_pair_front")
	_look_from(Vector3(-8.5, 1.2, 0.3), Vector3(1.0, 0.75, 0.3))
	await shot("03_pair_side")
	# The mandrill's face.
	alpha.look_at_point = Vector3(0.0, 1.4, 4.0)
	await wait(0.6)
	var face := _face_of(alpha)
	_look_from(face + Vector3(0.25, 0.12, 1.5), face)
	await shot("04_alpha_face")
	_look_from(face + Vector3(1.3, 0.15, 0.8), face)
	await shot("05_alpha_face_three_quarter")
	_look_from(face + Vector3(1.6, 0.05, -0.1), face + Vector3(0.0, -0.05, -0.2))
	await shot("06_alpha_face_side")
	baboon.look_at_point = baboon.global_position + Vector3(0.0, 1.2, 4.0)
	await wait(0.6)
	face = _face_of(baboon)
	_look_from(face + Vector3(0.6, 0.1, 1.1), face)
	await shot("07_baboon_face")
	# Each alone, filling the frame: front, side, three-quarters.
	alpha.look_at_point = Vector3.INF
	baboon.look_at_point = Vector3.INF
	for one: Baboon in [alpha, baboon]:
		var other: Baboon = baboon if one == alpha else alpha
		other.visible = false
		var mid := one.global_position + Vector3.UP * 0.42 * one.size + one.global_basis.z * 0.12 * one.size
		var name := "alpha" if one == alpha else "baboon"
		_look_from(mid + one.global_basis.z * 2.6 * one.size + Vector3.UP * 0.25 * one.size, mid)
		await shot("08_%s_front" % name)
		_look_from(mid - one.global_basis.x * 3.4 * one.size + Vector3.UP * 0.1 * one.size, mid)
		await shot("08_%s_side" % name)
		_look_from(mid + (one.global_basis.z - one.global_basis.x).normalized() * 3.0 * one.size + Vector3.UP * 0.6 * one.size, mid)
		await shot("08_%s_three_quarter" % name)
		other.visible = true
	baboon.queue_free()

	# Each thing it does, caught in the middle.
	alpha.look_at_point = Vector3.INF
	var drive := Driver.new()
	drive.body = alpha
	stage.add_child(drive)
	alpha.position = Vector3.ZERO
	drive.speed = 1.8
	await wait(1.4)
	_side_of(alpha, 6.0)
	await shot("10_walk_a")
	await wait(0.21)
	_side_of(alpha, 6.0)
	await shot("11_walk_b")
	drive.speed = 5.2
	await wait(1.5)
	for k in 4:
		_side_of(alpha, 7.0)
		await shot("12_gallop_%d" % k)
		await wait(0.09)
	_look_from(alpha.global_position + alpha.global_basis.z * 6.0 + alpha.global_basis.x * 3.0 + Vector3.UP * 1.6, alpha.global_position + Vector3.UP * 0.8)
	await shot("13_gallop_coming")
	drive.speed = 0.0
	alpha.sitting = true
	await wait(1.6)
	_three_quarter(alpha, 5.5)
	await shot("14_sit")
	alpha.bark()
	await wait(0.17)
	_three_quarter(alpha, 5.5)
	await shot("15_bark")
	alpha.sitting = false
	alpha.display(3.0)
	alpha.look_at_point = alpha.global_position + alpha.global_basis.z * 5.0 + Vector3.UP * 1.0
	await wait(0.9)
	_three_quarter(alpha, 5.5)
	await shot("16_display")
	await wait(0.33)
	_look_from(alpha.global_position + alpha.global_basis.z * 4.0 + Vector3.UP * 1.3, alpha.global_position + Vector3.UP * 1.1)
	await shot("17_display_front")
	await wait(1.8)
	alpha.look_at_point = Vector3.INF
	alpha.leap(0.6, 1.0)
	await wait(0.2)
	_side_of(alpha, 7.0)
	await shot("18_leap_crouch")
	drive.speed = 6.0
	await wait(0.33, func() -> bool: return alpha.leap_stage() == Baboon.Leap.FLIGHT and alpha.leap_progress() > 0.45)
	var mid_air: Vector3 = (alpha.grabbers()[0] + alpha.grabbers()[2]) * 0.5
	_look_from(mid_air + alpha.global_basis.x * 7.0, mid_air)
	await shot("19_leap_flight")
	await wait(0.6, func() -> bool: return alpha.leap_stage() == Baboon.Leap.LAND)
	drive.speed = 0.0
	_side_of(alpha, 7.0)
	await shot("20_leap_land")
	# The baboon going.
	var lean := Baboon.new()
	lean.kind = Baboon.Kind.BABOON
	lean.seed_value = 9
	stage.add_child(lean)
	lean.position = alpha.position + Vector3(0, 0, 4)
	alpha.queue_free()
	drive.body = lean
	drive.speed = 4.8
	await wait(1.5)
	for k in 3:
		_side_of(lean, 5.0)
		await shot("21_baboon_gallop_%d" % k)
		await wait(0.08)
	drive.speed = 1.2
	await wait(1.2)
	_three_quarter(lean, 4.5)
	await shot("22_baboon_walk")
	stage.queue_free()
	await process_frame


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at)


## About where its face is (its jaws, less a little).
func _face_of(body: Baboon) -> Vector3:
	var jaws: Vector3 = body.grabbers()[2]
	return jaws + Vector3.UP * 0.05 * body.size - body.global_basis.z * 0.1 * body.size


func _side_of(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.8 + body.global_basis.z * 0.25 * (body as Baboon).size
	_look_from(at + body.global_basis.x * far + Vector3.UP * 0.2, at)


func _three_quarter(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.8 + body.global_basis.z * 0.2 * (body as Baboon).size
	_look_from(at + (body.global_basis.z + body.global_basis.x * 0.8).normalized() * far + Vector3.UP * 0.6, at)


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
	# (only these baboons: the round's own enemies are put away)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	var found := _straight_run(4)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var across := Vector3(-way.y, 0, way.x)
	_stand(cell, way)
	await wait(1.0)
	var bare := await _draws()
	print("draws with nobody about: %d" % bare)

	# A troop sitting about in the passage, nobody near enough to notice.
	boy.remove_from_group(&"maze_players")
	var troop := MazeBaboon.troop(5)
	for k in troop.size():
		var one := troop[k]
		one.maze = maze
		one.seed_choices(k * 7 + 1)
		one.position = maze.world(cell) + along * (9.0 + (k / 3) * 3.0) + across * ((k % 3) - 1) * 2.6 + Vector3.UP * 0.05
		one.rotation.y = atan2(-along.x, -along.z) + (k - 2) * 0.5
		world.add_child(one)
		one.mode = MazeBaboon.Mode.SITTING
		one._sit_left = 30.0
	await wait(2.0)
	await shot("30_troop_sitting")
	print("draws with a troop of five: %d (+%d)" % [await _draws(), (await _draws()) - bare])
	# They notice him.
	boy.add_to_group(&"maze_players")
	_stand(cell, way, 0.0)
	for one in troop:
		one.notice(boy)
		one.mode = MazeBaboon.Mode.HUNTING
	await wait(0.25)
	await shot("31_troop_barks")
	await wait(0.9)
	await shot("32_troop_coming")
	# Low down by him, looking at them coming.
	var low := Camera3D.new()
	world.add_child(low)
	low.fov = 55.0
	var lead: MazeBaboon = troop[1]
	low.position = boy.global_position + across * 2.5 + Vector3.UP * 0.7 - along * 1.5
	low.look_at(lead.global_position + Vector3.UP * 0.7)
	low.make_current()
	await wait(0.15)
	await shot("32b_troop_coming_low")
	low.queue_free()
	world.camera.make_current()
	# One springs at him.
	await wait(6.0, func() -> bool:
		for one in troop:
			if one.body.leap_stage() == Baboon.Leap.FLIGHT:
				return true
		return false)
	await shot("33_leap_at_him")
	world.camera._yaw += 1.1
	await wait(0.2)
	await shot("34_leap_side")
	# Coming at the camera down the hall, at a gallop.
	_stand(cell, way, 0.0)
	for k in troop.size():
		var one := troop[k]
		one._put(maze.world(cell) + along * (20.0 + k * 1.5) + across * ((k % 3) - 1) * 2.2, atan2(-along.x, -along.z))
		one.notice(boy)
		one.stamina = 1.0
		one._gather = 5.0
		one.mode = MazeBaboon.Mode.HUNTING
	var front := Camera3D.new()
	world.add_child(front)
	front.fov = 50.0
	front.position = maze.world(cell) + along * 6.0 + across * 1.5 + Vector3.UP * 0.9
	front.look_at(maze.world(cell) + along * 16.0 + Vector3.UP * 1.0)
	front.make_current()
	await wait(1.2)
	await shot("35_gallop_at_camera")
	front.queue_free()
	world.camera.make_current()
	# The alpha, holding back and baring its fangs.
	var alpha := troop[0]
	_stand(maze.cell_at(alpha.global_position), way, 0.0)
	boy.global_position = alpha.global_position + Vector3(sin(alpha.facing_yaw), 0, cos(alpha.facing_yaw)) * 7.0 + Vector3.UP * 0.1
	world.camera._yaw = alpha.facing_yaw
	world.camera.snap()
	alpha._display(3.0)
	await wait(0.8)
	await shot("36_alpha_display")
	quit()


func _straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(2):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


func _stand(at: Vector2i, along: Vector2i, back := 0.0) -> void:
	boy.global_position = maze.world(at) - Vector3(along.x, 0, along.y) * back + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(float(along.x), float(along.y))
	world.camera._yaw = atan2(float(-along.x), float(-along.y))
	world.camera.snap()


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
