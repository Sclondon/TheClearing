extends SceneTree
## Pictures of the masked tribe (creatures/masked_tribe/, and MazeTribesman in
## scripts/enemies/). First on the component's own floor
## (creatures/masked_tribe/example.gd): the five masks side by side, front and
## three quarters, and close to; one stood with his spear, walking, running and
## creeping; the drumming call at a blow; the wind-up and the throw, the spear in
## the air and stuck in the board; the jab; the totem. Then in a passage of a
## real round (World): a party on patrol in single file, one drawing back on the
## boy down a hall, a spear in flight at him, another jabbing, the camp in its
## dead end. Says how many draws a frame takes. Needs a real window (the engine
## draws nothing headless), landscape:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/tribe_shots.gd -- <folder> [model|maze|sound]
##
## (sound only writes the call and the yell to <folder>/chant.wav and yell.wav.)

var folder := "tribe_shots"
var only := ""
var example: Node3D
var camera: Camera3D


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
	# (by the clock: frames come faster than sixty a second here)
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


## Looks at `at` from `direction` (in `basis`), `distance` off.
func look(at: Vector3, basis: Basis, direction: Vector3, distance: float, fov := 30.0) -> void:
	camera.fov = fov
	camera.global_position = at + (basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		Tribesman.chant_sound().save_to_wav("%s/chant.wav" % folder)
		Tribesman.yell_sound().save_to_wav("%s/yell.wav" % folder)
		print("saved %s/chant.wav, yell.wav" % folder)
		quit()
		return
	if only != "maze":
		await _model()
	if only != "model":
		await _maze()
	quit()


func _model() -> void:
	example = (load("res://creatures/masked_tribe/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still_camera = true
	example.set_process(false)
	camera = example.camera
	camera.make_current()
	var men: Array = example.men
	# Five in a row, one in each mask.
	var row: Array[Tribesman] = []
	for k in Tribesman.MASK_COUNT:
		var man: Tribesman
		if k < men.size():
			man = men[k]
		else:
			man = Tribesman.new()
			example.add_child(man)
			men.append(man)
		man.mask = k
		man.put(Vector3((k - 2) * 1.1, 0.0, 0.0), 0.0)
		row.append(man)
	for k in row.size():
		row[k]._mask.mesh = Tribesman.mask_mesh(k)
	example.totem.position = Vector3(0.0, 0.0, -3.0)
	await wait(1.0)
	look(Vector3(0.0, 0.9, 0.0), Basis.IDENTITY, Vector3(0, 0.08, 1), 7.5, 40.0)
	await shot("m01_five_masks")
	look(Vector3(0.0, 0.9, 0.0), Basis.IDENTITY, Vector3(0.7, 0.1, 1), 7.5, 40.0)
	await shot("m02_five_quarter")
	for k in row.size():
		var head: Vector3 = row[k]._rig._head.global_transform * Vector3(0.0, 0.1, 0.05)
		look(head, Basis.IDENTITY, Vector3(0.35, 0.05, 1), 1.3, 30.0)
		await shot("m%02d_mask%d" % [3 + k, k])
	look(row[1]._rig._head.global_transform * Vector3(0.0, 0.1, 0.0), Basis.IDENTITY, Vector3(-0.9, 0.1, -0.5), 1.4, 30.0)
	await shot("m08_mask1_back")
	# One stood with his spear; the others out of the way.
	for k in range(1, row.size()):
		row[k].visible = false
	var man := row[0]
	man.put(Vector3.ZERO, 0.0)
	await wait(0.6)
	look(Vector3(0, 0.75, 0), Basis.IDENTITY, Vector3(0.6, 0.1, 1), 4.5)
	await shot("m09_stood")
	look(Vector3(0, 0.75, 0), Basis.IDENTITY, Vector3(1, 0.1, -0.1), 4.5)
	await shot("m10_stood_side")
	# Walking, running, creeping (walked along under a camera that keeps with him).
	for gait: Array in [["m11_walk", 1.4, false], ["m12_run", 4.2, false], ["m13_creep", 0.9, true]]:
		var t := 0.0
		man.stalking = gait[2]
		man.put(Vector3(-3.0, 0.0, -6.0), 0.0)
		while t < 1.6:
			var step := root.get_process_delta_time()
			man.velocity = Vector3(0, 0, gait[1])
			man.global_position += man.velocity * step
			look(man.global_position + Vector3.UP * 0.7, Basis.IDENTITY, Vector3(1, 0.1, 0.4), 5.0)
			await process_frame
			t += step
		await shot(gait[0])
	man.velocity = Vector3.ZERO
	man.stalking = false
	man.put(Vector3.ZERO, 0.0)
	await wait(0.8)
	# The call.
	man.aim = Vector3(0, 1.0, 6.0)
	man.chant()
	await wait(TribesmanRig.BEATS[1] - 0.12)
	look(Vector3(0, 0.8, 0), Basis.IDENTITY, Vector3(0.7, 0.1, 1), 4.5)
	await shot("m14_chant_lifted")
	await wait(0.1)
	await shot("m15_chant_blow")
	await wait(1.5)
	# The wind-up and the throw at the board.
	man.aim = Vector3(0.0, 1.0, 9.0)
	man.wind_up()
	await wait(0.7)
	look(Vector3(0, 0.9, 0), Basis.IDENTITY, Vector3(1, 0.1, 0.35), 4.5)
	await shot("m16_wind_side")
	look(Vector3(0, 0.9, 0), Basis.IDENTITY, Vector3(0.2, 0.15, 1), 4.5)
	await shot("m17_wind_front")
	man.loose(Tribesman.launch(man.spear_point(), Vector3(0.0, 1.3, 8.85), 15.0, man.spear.gravity))
	await wait(0.12)
	look(Vector3(0, 1.0, 2.5), Basis.IDENTITY, Vector3(1, 0.15, 0.0), 7.0, 45.0)
	await shot("m18_loosed")
	await wait(1.4)
	look(Vector3(0, 1.0, 4.5), Basis.IDENTITY, Vector3(1, 0.3, -0.4), 9.0, 45.0)
	await shot("m19_stuck")
	man.rearm()
	await wait(0.5)
	# The jab.
	man.aim = Vector3(0.0, 0.8, 1.6)
	man.jab()
	await wait(TribesmanRig.GATHER * 0.9)
	look(Vector3(0, 0.8, 0.5), Basis.IDENTITY, Vector3(1, 0.1, 0.2), 4.5)
	await shot("m20_jab_gather")
	await wait(TribesmanRig.GATHER * 0.1 + TribesmanRig.THRUST + 0.03)
	await shot("m21_jab_thrust")
	await wait(1.0)
	# The totem.
	man.visible = false
	look(example.totem.global_position + Vector3.UP * 1.4, Basis.IDENTITY, Vector3(0.3, 0.1, 1), 5.0, 40.0)
	await shot("m22_totem")
	example.queue_free()
	await wait(0.2)


func _draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Node3D = world.player
	boy.takes_input = false
	# (the round's own enemies are taken away: only the tribe is wanted here)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# A long straight hall, three cells, ending in a dead end if there is one.
	var start := Vector2i(-1, -1)
	var out := Vector2i(0, 1)
	for dead_first: bool in [true, false]:
		for cell: Vector2i in nav.lairs(3):
			if dead_first and not nav.dead_end(cell):
				continue
			for s: Vector2i in Maze.STEPS:
				if not maze.blocked(cell, s) and not maze.blocked(cell + s, s) and not maze.blocked(cell + s * 2, s) and nav.allowed(cell + s * 3):
					start = cell
					out = s
					break
			if start.x >= 0:
				break
		if start.x >= 0:
			break
	var along := Vector3(out.x, 0, out.y)
	var across := Vector3(along.z, 0, -along.x)
	var den := maze.world(start)
	boy.remove_from_group(&"maze_players")
	boy.global_position = den + along * 40.0 + Vector3.UP * 0.1
	await wait(0.5)
	var bare := _draws()
	# The party, at home round its totem.
	var party := MazeTribesman.party_of(4, 5, den)
	var spots: Array[Vector3] = [den + along * 1.5 + across * 1.2, den + along * 3.0 - across * 1.5, den + along * 2.0 + across * 2.8, den + along * 4.2 + across * 0.3]
	for k in party.size():
		var man := party[k]
		man.maze = maze
		man.position = spots[k] + Vector3.UP * 0.05
		man.rotation.y = atan2(along.x, along.z) + (k - 1.5) * 0.5
		man.sight_range = 0.0
		man.hear_range = 0.0
		man.patrol_speed = 0.0
		world.add_child(man)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50.0
	cam.make_current()
	await wait(1.5)
	cam.global_position = den + along * 9.0 + across * 2.5 + Vector3.UP * 2.0
	cam.look_at(den + along * 1.0 + Vector3.UP * 1.1)
	await wait(0.8)
	await shot("z1_camp_in_its_dead_end")
	var with_them := _draws()
	for man in party:
		man.tribesman.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := _draws()
	for man in party:
		man.tribesman.visible = true
	print("draws: %d with the party of four in sight, %d with them hidden (+%d, %.1f each)" % [with_them, hidden, with_them - hidden, (with_them - hidden) / 4.0])
	# On patrol, in single file down the hall.
	for man in party:
		man.patrol_speed = 1.5
	party[0].global_position = den + along * 6.0
	for k in range(1, 4):
		party[k].global_position = den + along * (6.0 - 2.4 * k) + across * 0.3 * (k % 2)
	party[0]._wander_goal = start + out * 3
	await wait(4.0)
	var middle := party[1].global_position
	cam.global_position = middle + across * 5.5 + along * 4.0 + Vector3.UP * 1.6
	cam.look_at(middle + Vector3.UP * 0.9)
	await wait(0.05)
	await shot("z2_patrol_in_file")
	# The boy down the hall: they see him, the chief calls.
	for man in party:
		man.sight_range = 38.0
		man.hear_range = 8.0
	var lead_man := party[0]
	boy.global_position = lead_man.global_position + along * 13.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(-along.x, -along.z)
	boy.add_to_group(&"maze_players")
	var behind := boy.global_position + along * 3.5 + Vector3.UP * 1.7 + across * 0.8
	cam.global_position = behind
	cam.look_at(lead_man.global_position + Vector3.UP * 1.0)
	await wait(4.0, func() -> bool: return party.any(func(m: MazeTribesman) -> bool: return m.mode == MazeTribesman.Mode.CALL and m.tribesman.stage() == TribesmanRig.Stage.CHANT and m._mode_time > TribesmanRig.BEATS[0]))
	cam.look_at(lead_man.global_position + Vector3.UP * 1.0)
	await shot("z3_the_call")
	# One draws back on him.
	# (a lambda cannot set a variable outside it, so the one found goes in a list)
	var found: Array = []
	await wait(6.0, func() -> bool:
		for m in party:
			if m.mode == MazeTribesman.Mode.WIND and m._mode_time > 0.5:
				found.append(m)
				return true
		return false)
	var winder: MazeTribesman = found[0] if not found.is_empty() else null
	if winder:
		cam.global_position = boy.global_position + along * 2.5 + Vector3.UP * 1.3 - across * 0.9
		cam.look_at(winder.global_position + Vector3.UP * 1.0)
		await shot("z4_drawn_back_on_him")
		var side := winder.global_position.lerp(boy.global_position, 0.5)
		await wait(2.0, func() -> bool: return winder.tribesman.spear.flying() and winder.tribesman.spear.time > 0.25)
		cam.global_position = side + across * 6.0 + Vector3.UP * 1.4
		cam.look_at(side + Vector3.UP * 1.0)
		await shot("z5_spear_in_flight")
	# Close to: a jab.
	await wait(3.0)
	boy.global_position = party[2].global_position + Vector3(sin(party[2].facing_yaw), 0, cos(party[2].facing_yaw)) * 1.4 + Vector3.UP * 0.1
	var jabber := party[2]
	await wait(5.0, func() -> bool: return jabber.mode == MazeTribesman.Mode.JAB and jabber.tribesman.stage() == TribesmanRig.Stage.THRUST)
	var mid := jabber.global_position.lerp(boy.global_position, 0.5)
	cam.global_position = mid + across * 3.2 + Vector3.UP * 1.3
	cam.look_at(mid + Vector3.UP * 0.8)
	await shot("z6_jab")
	print("draws: %d bare" % bare)
	cam.queue_free()
