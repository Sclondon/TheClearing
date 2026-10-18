extends SceneTree
## Pictures of the imps (creatures/imp/, scripts/enemies/maze_imp.gd): first in
## a plain grey studio (front, side, three-quarters, the face close, and each
## thing it does: walking, scuttling, bounding, clinging to a wall, the leap,
## the cackle, the tantrum, and riding the boy); then in a passage of a real
## round (World: the game's light and mist): a gang on the wall, coming down
## it, at him, and on him. Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/imp_shots.gd -- <folder> [studio|maze]
##
## (landscape: every picture is framed for 1280x720)

var folder := "imp_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves an imp along at `speed` (m/s) the way it faces, every frame.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0

	func _process(delta: float) -> void:
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
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.49)
	floor.material_override = mat
	stage.add_child(floor)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(60.0, 1.0, 60.0)
	ground_shape.shape = slab
	ground_shape.position.y = -0.5
	ground.add_child(ground_shape)
	stage.add_child(ground)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 5.0, 0.5)
	wall.mesh = box
	wall.material_override = mat
	wall.position = Vector3(0.0, 2.5, -4.25)
	stage.add_child(wall)
	camera = Camera3D.new()
	camera.fov = 35.0
	stage.add_child(camera)
	camera.make_current()

	var imp := Imp.new()
	imp.voice = false
	stage.add_child(imp)
	await wait(0.5)
	var mid := imp.global_position + Vector3.UP * 0.2
	_look_from(mid + Vector3(0.0, 0.05, 1.6), mid)
	await shot("01_front")
	_look_from(mid + Vector3(1.7, 0.05, 0.0), mid)
	await shot("02_side")
	_look_from(mid + Vector3(1.15, 0.35, 1.15), mid)
	await shot("03_three_quarter")
	_look_from(mid + Vector3(-1.0, 0.4, -1.3), mid)
	await shot("04_back")
	imp.look_at_point = Vector3(0.3, 0.4, 2.0)
	await wait(0.4)
	var face := imp.head_position()
	_look_from(face + Vector3(0.0, 0.0, 0.55), face)
	await shot("05_face_front")
	_look_from(face + Vector3(0.38, 0.05, 0.4), face)
	await shot("06_face_three_quarter")
	_look_from(face + Vector3(0.55, 0.0, 0.0), face)
	await shot("07_face_side")
	_look_from(face + Vector3(0.15, -0.2, 0.45), face)
	await shot("08_face_below")
	imp.cackle()
	await wait(0.4)
	face = imp.head_position()
	_look_from(face + Vector3(0.25, 0.0, 0.5), face + Vector3.DOWN * 0.08)
	await shot("09_cackle")
	await wait(1.0)
	imp.look_at_point = Vector3.INF

	# Going: walking upright, scuttling, bounding.
	var drive := Driver.new()
	drive.body = imp
	stage.add_child(drive)
	drive.speed = 0.35
	await wait(1.0)
	for k in 2:
		_side_of(imp, 1.8)
		await shot("10_walk_%d" % k)
		await wait(0.17)
	drive.speed = 1.2
	await wait(0.8)
	for k in 2:
		_side_of(imp, 1.8)
		await shot("11_scuttle_%d" % k)
		await wait(0.09)
	_look_from(imp.global_position + imp.global_basis.z * 1.6 + imp.global_basis.x * 0.6 + Vector3.UP * 0.5, imp.global_position + Vector3.UP * 0.12)
	await shot("12_scuttle_coming")
	drive.speed = 3.0
	await wait(0.7)
	for k in 3:
		_side_of(imp, 2.2)
		await shot("13_bound_%d" % k)
		await wait(0.06)
	drive.speed = 0.0
	await wait(0.6)
	imp.tantrum(3.0)
	await wait(0.55)
	_three_quarter(imp, 1.8)
	await shot("14_tantrum_a")
	await wait(0.23)
	_three_quarter(imp, 1.8)
	await shot("15_tantrum_b")
	await wait(2.4)
	imp.leap(0.5, 0.5)
	await wait(0.15)
	_side_of(imp, 1.8)
	await shot("16_leap_crouch")
	drive.speed = 3.0
	await wait(0.5, func() -> bool: return imp.leap_stage() == Imp.Leap.FLIGHT and imp.leap_progress() > 0.45)
	var air := imp.head_position()
	_look_from(air + imp.global_basis.x * 1.5 + imp.global_basis.z * 0.9, air)
	await shot("17_leap_flight")
	_look_from(air + imp.global_basis.z * 1.6 + Vector3.UP * 0.1, air)
	await shot("18_leap_flight_front")
	await wait(0.6, func() -> bool: return imp.leap_stage() == Imp.Leap.LAND)
	drive.speed = 0.0
	await wait(0.5)

	# Clinging to the wall, head up, looking round; then scurrying up it.
	imp.clinging = true
	imp.global_transform = Transform3D(Basis(Vector3.BACK.cross(Vector3.UP), Vector3.BACK, Vector3.UP), Vector3(0.0, 1.2, -4.0))
	imp.settle()
	imp.look_at_point = Vector3(1.0, 0.6, 1.0)
	await wait(0.6)
	_look_from(Vector3(1.0, 1.4, -2.2), Vector3(0.0, 1.3, -4.0))
	await shot("19_cling_wall")
	_look_from(Vector3(1.6, 1.2, -3.6), Vector3(0.0, 1.3, -4.0))
	await shot("20_cling_wall_side")
	imp.look_at_point = Vector3.INF
	drive.speed = 0.9
	await wait(0.6)
	_look_from(Vector3(0.8, imp.global_position.y + 0.3, -2.4), imp.global_position + Vector3(0.0, 0.2, 0.1))
	await shot("21_climb_wall")
	drive.speed = 0.0
	imp.clinging = false
	drive.queue_free()
	imp.queue_free()

	# Riding the boy: one on his back, one on his leg, one on his shoulder.
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.global_position = Vector3(0.0, 0.05, 1.5)
	await wait(0.6)
	var riders: Array[Imp] = []
	for k in 3:
		var rider := Imp.new()
		rider.voice = false
		rider.seed_value = 10 + k
		rider.riding = true
		stage.add_child(rider)
		riders.append(rider)
	var skeleton: Skeleton3D = boy.find_children("*", "Skeleton3D", true, false)[0]
	for t in 30:
		for k in 3:
			var where := ImpRide.slot(skeleton, boy, k)
			riders[k].global_transform = where
			if t == 0:
				riders[k].settle()
		await process_frame
	var chest := boy.global_position + Vector3.UP * 0.8
	_look_from(chest + Vector3(-1.4, 0.3, -1.6), chest)
	await shot("22_riding_back")
	_look_from(chest + Vector3(1.6, 0.2, 1.3), chest)
	await shot("23_riding_front")
	_look_from(chest + Vector3(-2.0, 0.1, 0.4), chest)
	await shot("24_riding_side")
	stage.queue_free()
	await process_frame


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at)


func _side_of(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.18
	_look_from(at + body.global_basis.x * far + Vector3.UP * 0.1, at)


func _three_quarter(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.2
	_look_from(at + (body.global_basis.z + body.global_basis.x * 0.8).normalized() * far + Vector3.UP * 0.35, at)


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
	# (only these imps: the round's own enemies are put away)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	var found := _straight_run(4)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	_stand(cell, way)
	await wait(1.0)
	var bare := await _draws()
	print("draws with nobody about: %d" % bare)

	# A gang perched on the wall a little way down the hall, nobody noticed yet.
	boy.remove_from_group(&"maze_players")
	var gang := MazeImp.gang(4)
	for k in gang.size():
		var one := gang[k]
		one.maze = maze
		one.seed_choices(k * 7 + 3)
		one.position = maze.world(cell) + along * (8.0 + k * 0.9) + Vector3.UP * 0.05
		world.add_child(one)
	await wait(1.5)
	var wall_spot: Vector3 = gang[1].global_position
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50.0
	var out: Vector3 = gang[1]._wall_normal
	cam.position = wall_spot + out * 4.5 - along * 3.0 + Vector3.DOWN * 2.6
	cam.look_at(wall_spot + Vector3.DOWN * 0.4)
	cam.make_current()
	await shot("30_gang_perched")
	cam.position = wall_spot + out * 1.3 + along * 0.6 + Vector3.DOWN * 0.15
	cam.look_at(wall_spot + Vector3.UP * 0.15)
	await shot("31_perched_close")
	print("draws with a gang of four: +%d" % ((await _draws()) - bare))
	# They notice him: cackling, coming down the wall head first.
	boy.add_to_group(&"maze_players")
	_stand(cell, way, 0.0)
	gang[0].notice(boy)
	await wait(0.55)
	cam.position = wall_spot + out * 3.5 - along * 2.5 + Vector3.DOWN * 2.0
	cam.look_at(wall_spot + Vector3.DOWN * 1.8)
	await shot("32_coming_down")
	await wait(0.9)
	# Scuttling at him, low by his feet.
	cam.position = boy.global_position + along * 1.0 + Vector3.UP * 1.5 - Vector3(along.z, 0, -along.x) * 1.2
	var lead: MazeImp = gang[0]
	cam.look_at(lead.global_position + Vector3.UP * 0.15)
	await shot("33_scuttling_at_him")
	world.camera.make_current()
	await shot("34_scuttling_game_camera")
	await wait(3.0, func() -> bool:
		for one in gang:
			if one.body.leap_stage() == Imp.Leap.FLIGHT:
				return true
		return false)
	await shot("35_leap_at_him")
	await wait(4.0, func() -> bool: return MazeImp.riding(boy) >= 2)
	await wait(0.3)
	await shot("36_riding_game_camera")
	cam.make_current()
	var chest: Vector3 = boy.global_position + Vector3.UP * 0.8
	cam.position = chest - along * 1.8 - Vector3(along.z, 0, -along.x) * 0.9 + Vector3.UP * 0.5
	cam.look_at(chest)
	await shot("37_riding_close")
	# He jumps: shaken off, tumbling, and in a tantrum.
	boy.velocity.y = 4.5
	for one in gang:
		if one.mode == MazeImp.Mode.RIDING:
			one._grip = 0.2
	await wait(0.35)
	cam.position = chest + along * 2.4 - Vector3(along.z, 0, -along.x) * 1.5 + Vector3.UP * 0.6
	cam.look_at(chest + Vector3.DOWN * 0.3)
	await shot("38_shaken_off")
	await wait(0.6, func() -> bool:
		for one in gang:
			if one.mode == MazeImp.Mode.TANTRUM:
				return true
		return false)
	await wait(0.4)
	for one in gang:
		if one.mode == MazeImp.Mode.TANTRUM:
			var at: Vector3 = one.global_position
			cam.position = at + along * 1.6 - Vector3(along.z, 0, -along.x) * 0.9 + Vector3.UP * 1.1
			cam.look_at(at + Vector3.UP * 0.15)
			break
	await shot("39_tantrum")
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
