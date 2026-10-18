extends SceneTree
## Pictures of the clown (creatures/clown/, and MazeClown in scripts/enemies/).
## First on the component's own floor (creatures/clown/example.gd): the model
## close to, from the front, the side, three quarters and behind, and his face;
## then each of the things he does, caught partway through: the creep, frozen
## with his head tilted over, the giggle, the flailing sprint, winded. Then in a
## passage of a real round (World): frozen in a hall when the boy turns round,
## his balloon over the walls from far off, sprinting at the boy. Says how many
## draws a frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/clown_shots.gd -- <folder> [model|maze|sound]
##
## (sound only writes his sounds to <folder>/*.wav, to listen to or look at.)

var folder := "clown_shots"
var only := ""
var example: Node3D
var clown: Clown
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


## Looks at the clown from `direction` (in his own frame: +Z his front), `distance` off, at `height`.
func look(direction: Vector3, distance: float, height: float, fov := 30.0) -> void:
	var at := clown.global_position + Vector3.UP * height
	camera.fov = fov
	camera.global_position = at + (Basis(Vector3.UP, clown.rotation.y) * direction.normalized()) * distance
	camera.look_at(at)


func look_head(direction: Vector3, distance: float) -> void:
	var at := clown.face()
	camera.fov = 30.0
	camera.global_position = at + (Basis(Vector3.UP, clown.rotation.y) * direction.normalized()) * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		Clown.tine_sound().save_to_wav("%s/tine.wav" % folder)
		Clown.giggle_sound().save_to_wav("%s/giggle.wav" % folder)
		Clown.slap_sound().save_to_wav("%s/slap.wav" % folder)
		print("saved %s/tine.wav, giggle.wav, slap.wav" % folder)
		quit()
		return
	if only != "maze":
		await _model()
	if only != "model":
		await _maze()
	quit()


## Walks him along at `speed` under a camera that keeps with him, taking `count` shots.
func walk(speed: float, count: int, name: String, first: int, direction: Vector3, gap := 0.13) -> void:
	var t := 0.0
	var taken := 0
	while taken < count:
		clown.velocity = Vector3(0, 0, speed)
		var step := root.get_process_delta_time()
		clown.global_position += clown.velocity * step
		look(direction, 8.5, 1.4, 32.0)
		await process_frame
		t += step
		if t > 1.6 + taken * gap:
			await shot("m%02d_%s_%d" % [first + taken, name, taken])
			taken += 1


func _model() -> void:
	example = (load("res://creatures/clown/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still_camera = true
	example.set_process(false)
	clown = example.clown
	camera = example.camera
	example.post.visible = false
	camera.make_current()
	clown.music = false
	clown.put(Vector3.ZERO, 0.0)
	clown.aim = Vector3(0, 1.8, 6)
	await wait(0.8)
	look(Vector3(0, 0.05, 1), 8.0, 1.25)
	await shot("m01_front")
	look(Vector3(1, 0.05, 0), 8.0, 1.25)
	await shot("m02_side")
	look(Vector3(0.8, 0.15, 1), 8.0, 1.25)
	await shot("m03_quarter")
	look(Vector3(-0.6, 0.2, -1), 8.0, 1.25)
	await shot("m04_back")
	look_head(Vector3(0.0, -0.05, 1), 1.6)
	clown.aim = camera.global_position
	await wait(0.8)
	await shot("m05_face")
	look_head(Vector3(0.8, 0.0, 0.7), 1.6)
	clown.aim = camera.global_position
	await wait(0.6)
	await shot("m06_face_quarter")
	look_head(Vector3(0.3, -0.35, 1), 1.4)
	await wait(0.2)
	await shot("m07_face_below")
	# The creep
	clown.aim = Vector3.INF
	await walk(2.6, 3, "creep", 8, Vector3(1, 0.1, 0.25))
	# Frozen mid-step, the head tilting over
	clown.frozen = true
	await wait(2.0)
	look(Vector3(0.6, 0.05, 1), 7.0, 1.4)
	await shot("m11_frozen")
	clown.frozen = false
	clown.velocity = Vector3.ZERO
	await wait(0.6)
	# The giggle
	clown.aim = clown.global_position + Vector3(0, 1.8, 6)
	await wait(0.4)
	clown.giggle()
	await wait(0.3)
	look(Vector3(0.6, 0.05, 1), 7.0, 1.4)
	await shot("m12_giggle")
	await wait(0.6)
	# The sprint
	await walk(7.5, 4, "sprint", 13, Vector3(1, 0.05, 0.15), 0.09)
	await walk(7.5, 2, "sprint_quarter", 17, Vector3(0.7, 0.1, 1.0), 0.15)
	# Winded
	clown.velocity = Vector3.ZERO
	clown.winded = true
	await wait(1.5)
	look(Vector3(0.9, 0.1, 0.6), 7.0, 1.2)
	await shot("m19_winded")
	clown.winded = false
	# All of him, and his balloon over him
	await wait(1.0)
	look(Vector3(0.7, 0.25, 1), 22.0, 5.0, 40.0)
	await shot("m20_with_balloon")
	example.queue_free()
	await wait(0.2)


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Node3D = world.player
	boy.takes_input = false
	# (the round's own enemies are taken away: only the clown is wanted here)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# A straight hall: a cell with open passages on two opposite sides, three long
	var hall := nav.lairs(3)[0]
	var along := Vector2i(0, 1)
	var found := false
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not maze.blocked(cell, step) and not maze.blocked(cell + step, step) and not maze.blocked(cell, -step) and nav.allowed(cell + step * 2) and nav.allowed(cell - step):
				hall = cell
				along = step
				found = true
				break
		if found:
			break
	var way := Vector3(along.x, 0, along.y)
	var start: Vector3 = maze.world(hall)
	boy.global_position = start + way * 18.0 + Vector3.UP * 0.1
	world.camera._yaw = atan2(-way.x, -way.z)
	world.camera.snap()
	boy.remove_from_group(&"maze_players")
	var stalker := MazeClown.new()
	stalker.maze = maze
	stalker.position = start + Vector3.UP * 0.05
	stalker.rotation.y = atan2(way.x, way.z)
	world.add_child(stalker)
	await wait(1.0)
	# He stalks the boy down the hall while the camera looks the other way; then it turns round
	stalker.figure.music = false
	var behind := Camera3D.new()
	world.add_child(behind)
	behind.fov = 55.0
	behind.global_position = boy.global_position + way * 4.0 + Vector3.UP * 2.4
	behind.look_at(behind.global_position + way * 10.0)
	behind.make_current()
	boy.add_to_group(&"maze_players")
	stalker.notice(boy)
	await wait(1.6)
	behind.look_at(stalker.global_position + Vector3.UP * 2.0)
	await wait(2.2)
	await shot("z1_still_in_the_hall")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	stalker.figure.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	stalker.figure.visible = true
	print("draws: %d with the clown in sight, %d with him hidden (+%d); mode %s" % [with_it, bare, with_it - bare, MazeClown.Mode.keys()[stalker.mode]])
	# Close to, the face in the hall
	behind.global_position = stalker.global_position + Basis(Vector3.UP, stalker.facing_yaw) * Vector3(0.8, 0.0, 3.6) + Vector3.UP * 2.4
	behind.fov = 40.0
	behind.look_at(stalker.figure.face() + Vector3.DOWN * 0.3)
	await wait(0.3)
	await shot("z2_close_in_the_hall")
	# From far off down the hall: the balloon high over him in the strip of sky
	var run := 1
	while run < 5 and not maze.blocked(hall + along * run, along) and nav.allowed(hall + along * (run + 1)):
		run += 1
	var far_cam := Camera3D.new()
	world.add_child(far_cam)
	far_cam.fov = 62.0
	far_cam.global_position = start + way * (Maze.CELL * run + 4.0) + Vector3.UP * 1.6
	far_cam.look_at(start + Vector3.UP * (stalker.figure.balloon_height * 0.55))
	far_cam.make_current()
	await wait(0.5)
	await shot("z3_balloon_over_the_walls")
	# He bursts at the boy: the camera on the boy's shoulder, the boy's back to him
	behind.make_current()
	stalker.global_position = start + way * 9.0
	stalker._curr_pos = stalker.global_position
	stalker._prev_pos = stalker.global_position
	stalker.mode = MazeClown.Mode.STALKING
	stalker._burst_in = 0.0
	# (nobody looks at him: the boy is taken out of the looking, but he is still after him)
	stalker.camera_cone = 2.0
	stalker.watch_cone = 2.0
	var side := Vector3(along.y, 0, along.x)
	behind.fov = 50.0
	behind.global_position = boy.global_position + way * 2.5 + side * 2.0 + Vector3.UP * 2.6
	behind.look_at(stalker.global_position + Vector3.UP * 1.8)
	await wait(6.0, func() -> bool: return stalker.mode == MazeClown.Mode.GRINNING)
	behind.global_position = stalker.global_position + way * 3.2 + side * 1.2 + Vector3.UP * 2.3
	behind.look_at(stalker.figure.face() + Vector3.DOWN * 0.4)
	await wait(0.3)
	await shot("z4_giggle")
	behind.global_position = boy.global_position + way * 2.5 + side * 2.0 + Vector3.UP * 2.6
	behind.look_at(stalker.global_position + Vector3.UP * 1.8)
	await wait(6.0, func() -> bool: return stalker.mode == MazeClown.Mode.SPRINTING)
	await wait(0.25)
	behind.look_at(stalker.global_position + Vector3.UP * 1.8)
	await shot("z5_sprint_at_the_boy")
	await wait(0.15)
	behind.global_position = boy.global_position + Vector3.UP * 1.9 - way * 1.0
	behind.look_at(stalker.global_position + Vector3.UP * 1.8)
	await shot("z6_sprint_from_the_boy")
	behind.queue_free()
	far_cam.queue_free()
	world.camera.make_current()
