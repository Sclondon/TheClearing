extends SceneTree
## Pictures of the flesh mounds (creatures/flesh_mound/, and MazeFleshMound,
## their hunter in the maze), landscape. Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/flesh_mound_shots.gd -- <folder> [sizes|pair|small|strider|big|grow|maze|all] [low]
##
## sizes: one of each size side by side, with the boy. pair: a pair close,
## scuttling, crouching and rushing. strider: one close, walking, one of six,
## and a grab. small: an amalgam
## close, shambling, and cartwheeling frame by frame (side on). big: a mound
## close (front, side, three quarters, its faces, its hands), creeping, and a
## grab frame by frame (from beside the boy). grow: an amalgam absorbing a body, and two merging,
## each mid-way. maze: in a real round (and from the boy's height), and what it costs (draws, posing time).

var folder := "flesh_mound_shots"
var what := "all"
var camera: Camera3D
var stage: Node3D
var boy: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		what = args[1]
	if args.size() > 2 and args[2] == "low":
		FleshMound.low_poly = true
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at)


func _run() -> void:
	for part: String in ["sizes", "pair", "small", "strider", "big", "grow"]:
		if what in [part, "all"]:
			_set_stage()
			await wait(0.3)
			await call("_" + part)
			stage.queue_free()
			await wait(0.2)
	if what in ["maze", "all"]:
		await _maze()
	quit()


func _set_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	MazeLight.put(stage)
	var floor_box := MeshInstance3D.new()
	floor_box.mesh = BoxMesh.new()
	(floor_box.mesh as BoxMesh).size = Vector3(400, 1, 400)
	floor_box.position.y = -0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.31, 0.28)
	floor_box.material_override = material
	stage.add_child(floor_box)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)


func _mound(count: int, at: Vector3, yaw := 0.0) -> FleshMound:
	var mound := FleshMound.new()
	mound.bodies = count
	mound.measure_room = false
	stage.add_child(mound)
	mound.global_position = at
	mound.rotation.y = yaw
	mound.settle()
	return mound


func _sizes() -> void:
	var xs := [-14.0, -11.0, -7.0, -2.0, 3.0, 12.0]
	var counts := [2, 3, 4, 5, 7, 10]
	for i in counts.size():
		_mound(counts[i], Vector3(xs[i], 0, 0), 0.0)
	boy.global_position = Vector3(-4.0, 0.05, 6.0)
	await wait(1.5)
	look(Vector3(18, 6, 14), Vector3(0, 1.5, 0), 45)
	await shot("s1_sizes")
	look(Vector3(-2, 2.5, 0.5), Vector3(-9, 1.2, 0), 45)
	await shot("s2_small_ones")


func _small() -> void:
	var star := _mound(3, Vector3.ZERO)
	boy.global_position = Vector3(2.5, 0.05, 1.0)
	await wait(1.2)
	look(Vector3(3.6, 1.4, 0.2), Vector3(0, 1.0, 0), 45)
	await shot("a1_side")
	look(Vector3(2.2, 1.6, -2.6), Vector3(0, 1.0, 0), 45)
	await shot("a2_three_quarter")
	look(Vector3(0.9, 1.7, -1.6), Vector3(0, 1.4, 0), 45)
	await shot("a3_faces")
	# Shambling along.
	var t := 0.0
	for k in 3:
		var left := 0.35
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			star.global_position = Vector3(0, 0, -t * 1.6)
		look(star.global_position + Vector3(4.0, 1.3, 0.0), star.global_position + Vector3(0, 1.0, 0), 45)
		await shot("b%d_shamble" % k)
	# The cartwheel: wind-up, then frames of it rolling side on.
	star.start_roll()
	var from := star.global_position
	while star.roll_stage() == FleshMound.Roll.WIND_UP:
		await process_frame
		if star._roll_time > 0.4 and not FileAccess.file_exists("%s/c0_roll_wind_up.png" % folder):
			look(star.global_position + Vector3(4.0, 1.4, 0.0), star.global_position + Vector3(0, 1.1, 0), 45)
			await shot("c0_roll_wind_up")
	t = 0.0
	for k in 8:
		var left := 0.11
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			star.global_position = from + Vector3(0, 0, -t * 5.0)
		look(star.global_position + Vector3(4.5, 1.2, 0.0), star.global_position + Vector3(0, 1.0, 0), 45)
		await shot("c%d_roll" % (k + 1))


func _pair() -> void:
	var pair := _mound(2, Vector3.ZERO)
	boy.global_position = Vector3(2.0, 0.05, 1.5)
	await wait(1.2)
	look(Vector3(3.2, 1.1, 0.0), Vector3(0, 0.6, 0), 45)
	await shot("p1_side")
	look(Vector3(2.0, 1.4, -2.4), Vector3(0, 0.6, 0), 45)
	await shot("p2_three_quarter")
	look(Vector3(0.4, 2.6, 1.2), Vector3(0, 0.6, 0), 45)
	await shot("p3_above")
	# Scuttling along, then the crouch and the rush.
	var t := 0.0
	for k in 3:
		var left := 0.3
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			pair.global_position = Vector3(0, 0, -t * 3.6)
		look(pair.global_position + Vector3(3.2, 1.0, 0.0), pair.global_position + Vector3(0, 0.6, 0), 45)
		await shot("p%d_scuttle" % (k + 4))
	pair.aim = pair.global_position + Vector3(0, 0.8, -8)
	pair.start_roll()
	await wait(0.5)
	look(pair.global_position + Vector3(2.6, 1.2, -1.5), pair.global_position + Vector3(0, 0.6, 0), 45)
	await shot("p7_crouch")
	var from := pair.global_position
	t = 0.0
	for k in 3:
		var left := 0.15
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			pair.global_position = from + Vector3(0, 0, -t * 6.6)
		look(pair.global_position + Vector3(3.2, 1.1, 0.0), pair.global_position + Vector3(0, 0.6, 0), 45)
		await shot("p%d_rush" % (k + 8))


func _strider() -> void:
	var ring := _mound(5, Vector3.ZERO)
	boy.global_position = Vector3(3.0, 0.05, 2.0)
	await wait(1.2)
	look(Vector3(4.5, 1.8, 0.0), Vector3(0, 0.9, 0), 45)
	await shot("r1_side")
	look(Vector3(3.0, 2.6, -3.5), Vector3(0, 0.9, 0), 45)
	await shot("r2_three_quarter")
	look(Vector3(1.6, 0.7, -1.4), Vector3(0, 1.1, 0), 55)
	await shot("r3_under")
	var t := 0.0
	for k in 3:
		var left := 0.35
		while left > 0.0:
			await process_frame
			t += 1.0 / 60.0
			left -= 1.0 / 60.0
			ring.global_position = Vector3(0, 0, -t * 3.0)
		look(ring.global_position + Vector3(4.5, 1.6, 0.0), ring.global_position + Vector3(0, 0.9, 0), 45)
		await shot("r%d_walk" % (k + 4))
	var six := _mound(6, Vector3(-6, 0, 0))
	await wait(0.6)
	look(Vector3(-6, 2.2, 4.5), Vector3(-6, 0.9, 0), 45)
	await shot("r7_six")
	six.queue_free()
	var target: Vector3 = ring.global_position + Vector3(1.6, 0.0, 0.6)
	ring.aim = target + Vector3.UP
	await wait(1.0)
	ring.grab(target)
	var marks := [[0.5, "r8_grab_wind_up"], [1.1, "r9_grab_strike"], [1.4, "r10_grab_closed"]]
	for mark in marks:
		while ring._grab_time < mark[0]:
			await process_frame
		look(ring.global_position + Vector3(0.6, 1.6, 4.0), ring.global_position + Vector3(0.8, 0.9, 0), 50)
		print("  grab: %s, hits him: %s (target %s, at %s, hands %s)" % [FleshMound.Stage.keys()[ring.grab_stage()], ring.grab_hits(target, target + Vector3.UP * 1.5, 0.3), target, ring.global_position, ring.hands()])
		await shot(mark[1])


func _big() -> void:
	var mound := _mound(10, Vector3.ZERO)
	boy.global_position = Vector3(1.5, 0.05, -6.2)
	boy.rotation.y = PI
	await wait(1.5)
	var middle := Vector3(0, 2.0, 0)
	look(Vector3(0, 3.0, -15), middle)
	await shot("d1_front")
	look(Vector3(-15, 3.5, -1), middle)
	await shot("d2_side")
	look(Vector3(-10, 5.5, -11), middle)
	await shot("d3_three_quarter")
	look(Vector3(8, 4.5, 11), middle)
	await shot("d4_behind")
	look(Vector3(-2.5, 3.5, -8.5), Vector3(0, 2.2, -4.0), 45)
	await shot("d5_faces")
	look(Vector3(-2.5, 1.4, -9.0), Vector3(0, 0.6, -6.0), 45)
	await shot("d6_front_hands")
	look(Vector3(-9.0, 1.6, -3.0), Vector3(-5, 0.8, -1.5), 45)
	await shot("d7_flank_hands")
	mound.aim = boy.global_position + Vector3.UP
	await wait(1.5)
	look(Vector3(-9, 3.5, -14), Vector3(0, 1.8, -6))
	await shot("e1_feeling")
	var target: Vector3 = boy.global_position
	mound.grab(target)
	var marks := [[0.5, "f1_grab_wind_up"], [0.9, "f2_grab_wind_up_late"], [1.08, "f3_grab_strike"], [1.3, "f4_grab_closed"], [2.5, "f5_grab_recover"]]
	for mark in marks:
		while mound._grab_time < mark[0]:
			await process_frame
		look(Vector3(-3.5, 1.5, -10.5), Vector3(0.5, 1.3, -4.5), 55)
		print("  grab: %s, %.2f s in, hits him: %s" % [FleshMound.Stage.keys()[mound.grab_stage()], mound._grab_time, mound.grab_hits(target, target + Vector3.UP * 1.5, 0.3)])
		await shot(mark[1])


func _grow() -> void:
	# Absorbing: a body dragged in.
	var star := _mound(3, Vector3.ZERO)
	boy.global_position = Vector3(30, 0, 30)
	await wait(1.0)
	star.absorb(Vector3(1.6, 0.0, -2.0))
	var marks := [[0.35, "g1_absorb_start"], [0.6, "g2_absorb_mid"], [0.85, "g3_absorb_late"]]
	for mark in marks:
		while star.absorbing() >= 0.0 and star.absorbing() < mark[0]:
			await process_frame
		look(Vector3(5.0, 2.0, -3.0), Vector3(0.6, 1.0, -0.8), 45)
		await shot(mark[1])
	await wait(1.0)
	look(Vector3(5.0, 2.0, -3.0), Vector3(0.6, 1.0, -0.8), 45)
	print("  after absorbing: %d bodies" % star.bodies)
	await shot("g4_absorbed")
	star.queue_free()
	# Two meeting and merging.
	var a := _mound(4, Vector3(-2.2, 0, 0), PI * 0.5)
	var b := _mound(3, Vector3(2.2, 0, 0), -PI * 0.5)
	await wait(1.0)
	look(Vector3(0, 3.5, 9), Vector3(0, 1.0, 0), 45)
	await shot("h1_merge_before")
	b.merge_into(a)
	var done := [false]
	b.merged.connect(func(into: FleshMound) -> void:
		into.grow(b.bodies)
		done[0] = true)
	for mark in [[0.4, "h2_merge_mid"], [0.8, "h3_merge_late"]]:
		while b.merging() >= 0.0 and b.merging() < mark[0]:
			await process_frame
		await shot(mark[1])
	await wait(3.0, func() -> bool: return done[0])
	await wait(0.8)
	print("  after merging: %d bodies" % a.bodies)
	await shot("h4_merged")


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var him: Player = world.player
	him.takes_input = false
	for child in world.get_children():
		if child is MazeEnemy or child is Griever or child is MazeEnemies:
			child.queue_free()
	await wait(0.5)
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
	him.global_position = maze.world(cell) + Vector3.UP * 0.1
	him.rotation.y = atan2(along.x, along.z)
	var across := Vector3(-along.z, 0, along.x)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	look(him.global_position - along * 9.0 + across * 2.5 + Vector3.UP * 4.0, him.global_position + along * 14.0 + Vector3.UP * 2.0, 50)
	await wait(3.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var hunter := MazeFleshMound.new()
	hunter.bodies = 9
	hunter.maze = maze
	hunter.position = maze.world(cell + way * 2) + Vector3.UP * 0.05
	world.add_child(hunter)
	hunter.facing_yaw = atan2(along.x, along.z)
	hunter.notice(him)
	var small := MazeFleshMound.new()
	small.bodies = 3
	small.maze = maze
	small.position = maze.world(cell + way * 4) + Vector3.UP * 0.05
	world.add_child(small)
	await wait(4.0)
	await process_frame
	await RenderingServer.frame_post_draw
	print("draws with nobody about: %d, with a mound and an amalgam: %d" % [bare, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	for who: MazeFleshMound in [hunter, small]:
		var spent := 0
		var frames := 0
		var end := Time.get_ticks_msec() + 1000
		while Time.get_ticks_msec() < end:
			var from := Time.get_ticks_usec()
			who.look._process(1.0 / 60.0)
			spent += Time.get_ticks_usec() - from
			frames += 1
			await process_frame
		print("posing %d bodies takes %.2f ms a frame (on this machine)" % [who.bodies, spent / 1000.0 / maxf(frames, 1)])
	await shot("m1_coming")
	look(hunter.global_position + across * 11.0 + along * 4.0 + Vector3.UP * 6.0, hunter.global_position + Vector3.UP * 2.0, 55)
	await wait(0.3)
	await shot("m2_coming_side")
	# From his height, as he sees it coming.
	look(him.global_position + Vector3.UP * 1.0 + along * 0.5 + across * 0.4, hunter.global_position + Vector3.UP * 1.6, 60)
	await wait(0.3)
	await shot("m3_his_height")
	look(him.global_position + Vector3.UP * 1.0 + along * 0.5 + across * 0.4, small.global_position + Vector3.UP * 1.0, 60)
	await shot("m4_his_height_small")
