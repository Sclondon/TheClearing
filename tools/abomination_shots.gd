extends SceneTree
## Pictures of the meat abomination (creatures/abomination/, and Abomination,
## its hunter in the maze). Needs a real window (the engine draws nothing headless):
##
##     godot --path . --resolution 720x1280 -s res://tools/abomination_shots.gd -- <folder> [close|maze|all]
##
## close: on a bare floor in the maze's light, from the front, side, three
## quarters, behind and above; creeping (frames through a wave); a lash (frames
## through each stage); squeezing between two walls. maze: in a real round,
## coming down a passage at the boy (from behind him, and from the side), its
## lash at him (winding up, striking, landed), its trail from above; and how
## many draws it costs.

var folder := "abomination_shots"
var what := "all"
var camera: Camera3D
var meat: MeatAbomination
var stage: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		what = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	# (in real seconds: the window may draw faster than 60 a second)
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at)


func _run() -> void:
	if what in ["close", "all"]:
		await _close()
	if what in ["maze", "all"]:
		await _maze()
	quit()


# --- Close ---

func _box(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	body.add_child(mesh)
	stage.add_child(body)
	return body


func _close() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	MazeLight.put(stage)
	_box(Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.33, 0.31, 0.28))
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	# A boy for scale.
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.global_position = Vector3(3.5, 0.05, -9.0)
	boy.rotation.y = PI
	meat = MeatAbomination.new()
	stage.add_child(meat)
	meat.measure_room = false
	await wait(1.0)
	var middle := Vector3(0, 2.6, 0)
	look(Vector3(0, 3.2, -17), middle)
	await shot("c1_front")
	look(Vector3(-17, 3.5, -1), middle)
	await shot("c2_side")
	look(Vector3(-11, 5.5, -13), middle)
	await shot("c3_three_quarter")
	look(Vector3(9, 4.5, 13), middle)
	await shot("c4_behind")
	look(Vector3(-4, 4.5, -8.5), Vector3(0, 2.4, -4.5), 55)
	await shot("c5_face")
	look(Vector3(5, 22, 6), Vector3(0, 0, -1), 50)
	await shot("c6_above")
	boy.queue_free()
	# Feeling for someone.
	meat.aim = Vector3(2, 1, -12)
	await wait(1.5)
	look(Vector3(-12, 4.5, -14), middle)
	await shot("c7_feeling")
	# Creeping: moved along, frames through a wave.
	meat.aim = Vector3.INF
	var t := 0.0
	for k in 4:
		var left := 0.4
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			meat.global_position = Vector3(0, 0, -t * 1.6)
		look(meat.global_position + Vector3(-15, 4, -6), meat.global_position + Vector3(0, 2.4, 0))
		await shot("c8_creep_%d" % k)
	# Turning hard, and stopping (it slops).
	for k in 40:
		await process_frame
		meat.rotation.y += 0.02
		meat.global_position += -meat.global_transform.basis.z * 0.03
	look(meat.global_position + Vector3(-14, 6, -10), meat.global_position + Vector3(0, 2.4, 0))
	await shot("c9_turning")
	# A lash, frames through its stages.
	meat.global_position = Vector3.ZERO
	meat.rotation.y = 0.0
	meat.settle()
	await wait(0.8)
	var target := Vector3(1.5, 0, -12)
	meat.aim = target
	meat.lash(target)
	var marks := [[0.35, "l1_wind_up_early"], [0.85, "l2_wind_up_late"], [0.98, "l3_strike_mid"], [1.25, "l4_landed"], [2.0, "l5_recover"]]
	for mark in marks:
		while meat._lash_time < mark[0]:
			await process_frame
		look(Vector3(-15, 5, -12), Vector3(0, 2.5, -5), 55)
		print("  lash: %s, %.2f s in" % [MeatAbomination.Stage.keys()[meat.lash_stage()], meat._lash_time])
		await shot(mark[1])
	# Squeezing between two walls 5 m apart.
	meat.aim = Vector3.INF
	meat.settle()
	var walls := [_box(Vector3(-6.5, 8, -20), Vector3(8, 16, 6), Color(0.5, 0.5, 0.49)), _box(Vector3(6.5, 8, -20), Vector3(8, 16, 6), Color(0.5, 0.5, 0.49))]
	meat.measure_room = true
	for k in 240:
		await process_frame
		meat.global_position = Vector3(0, 0, -6.0 - k * 0.06)
	look(Vector3(-11, 9, -2), Vector3(0, 3, -18))
	await shot("s1_squeezing")
	for k in 120:
		await process_frame
		meat.global_position = Vector3(0, 0, -20.4 - k * 0.04)
	look(Vector3(0, 12, -2), Vector3(0, 3, -20))
	await shot("s2_through")
	for wall in walls:
		wall.queue_free()
	stage.queue_free()
	await wait(0.2)


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Player = world.player
	boy.takes_input = false
	# The others out of the way.
	for child in world.get_children():
		if child is MazeEnemy or child is Griever or child is MazeEnemies:
			child.queue_free()
	await wait(0.5)
	# A straight run of passage.
	var cell := Vector2i.ZERO
	var way := Vector2i(1, 0)
	var found := false
	for c: Vector2i in nav.lairs(2):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in 5:
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
	var across := Vector3(-along.z, 0, along.x)
	# A camera of our own, behind the boy and up a little, looking past him down the passage.
	camera = Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	look(boy.global_position - along * 9.0 + across * 2.5 + Vector3.UP * 4.0, boy.global_position + along * 14.0 + Vector3.UP * 2.0, 55)
	await wait(3.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var hunter := Abomination.new()
	hunter.maze = maze
	hunter.position = maze.world(cell + way * 2) + Vector3.UP * 0.05
	world.add_child(hunter)
	hunter.facing_yaw = atan2(along.x, along.z)
	hunter.notice(boy)
	await wait(4.0)
	await process_frame
	await RenderingServer.frame_post_draw
	print("draws with nobody about: %d, with the abomination: %d" % [bare, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	await shot("m1_coming")
	look(hunter.global_position + across * 11.0 + along * 4.0 + Vector3.UP * 6.0, hunter.global_position + Vector3.UP * 2.0, 60)
	await wait(0.3)
	await shot("m2_coming_side")
	look(boy.global_position - along * 9.0 + across * 2.5 + Vector3.UP * 4.0, boy.global_position + along * 8.0 + Vector3.UP * 2.0, 60)
	var ticks := [0]
	await wait(20.0, func() -> bool:
		ticks[0] += 1
		if ticks[0] % 240 == 0:
			print("  hunter at %s (%.1f m from him), %s, going %s, sides %s" % [hunter.global_position.snappedf(0.1), hunter.global_position.distance_to(boy.global_position), "hunting" if hunter.chasing else "about", hunter.velocity.snappedf(0.1), hunter.look.sides()])
		return hunter.look.lash_stage() == MeatAbomination.Stage.WIND_UP and hunter.look.strikes_in() < 0.15)
	await shot("m3_lash_wind_up")
	await wait(1.0, func() -> bool: return hunter.look.lash_stage() == MeatAbomination.Stage.STRIKE and hunter.look._lash_time > hunter.look.wind_up + 0.12)
	await shot("m4_lash_striking")
	await wait(1.0, func() -> bool: return hunter.look.lash_stage() == MeatAbomination.Stage.HOLD)
	await shot("m5_lash_landed")
	# Its trail, from up on the wall.
	boy.remove_from_group(&"maze_players")
	await wait(3.0)
	look(hunter.global_position + across * 9.0 - along * 14.0 + Vector3.UP * 26.0, hunter.global_position - along * 6.0, 55)
	await wait(0.3)
	await shot("m6_trail_from_above")
	quit()
