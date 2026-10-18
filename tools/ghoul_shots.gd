extends SceneTree
## Pictures of the ghoul (creatures/ghoul/, and MazeGhoul in scripts/enemies/).
## First on the component's own floor (creatures/ghoul/example.gd): the model
## close to, from the front, the side and three quarters, and its face; then
## each of the things it does, caught partway through: standing as a statue, a
## shuffle step, the scream at its height, the arms thrown wide for a grab, the
## hug closing, clinging. Then in a passage of a real round (World): one
## standing in a dead end, one screaming at the boy, one taking him. Says how
## many draws a frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 720x1280 -s res://tools/ghoul_shots.gd -- <folder> [model|maze|sound]
##
## (sound only writes the shriek to <folder>/shriek.wav, to listen to or look at.)

var folder := "ghoul_shots"
var only := ""
var example: Node3D
var ghoul: Ghoul
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


## Looks at the ghoul from `direction` (in its own frame: +Z its front), `distance` off, at `height`.
func look(direction: Vector3, distance: float, height: float, fov := 30.0) -> void:
	var at := ghoul.global_position + Vector3.UP * height
	camera.fov = fov
	camera.global_position = at + (ghoul.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


## Looks at its face from `direction` (in its own frame), `distance` off.
func look_head(direction: Vector3, distance: float) -> void:
	var head: Node3D = ghoul._rig._head
	var at := head.global_transform * Vector3(0.0, 0.07, 0.03)
	camera.fov = 30.0
	camera.global_position = at + (ghoul.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		Ghoul.shriek_sound().save_to_wav("%s/shriek.wav" % folder)
		print("saved %s/shriek.wav" % folder)
		quit()
		return
	if only != "maze":
		await _model()
	if only != "model":
		await _maze()
	quit()


func _model() -> void:
	example = (load("res://creatures/ghoul/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still_camera = true
	example.set_process(false)
	ghoul = example.ghoul
	camera = example.camera
	example.post.visible = false
	camera.make_current()
	ghoul.put(Vector3.ZERO, 0.0)
	ghoul.awake = false
	await wait(0.6)
	look(Vector3(0, 0.05, 1), 6.5, 1.15)
	await shot("m01_statue_front")
	look(Vector3(1, 0.05, 0), 6.5, 1.15)
	await shot("m02_statue_side")
	look(Vector3(0.8, 0.15, 1), 6.5, 1.15)
	await shot("m03_statue_quarter")
	look(Vector3(-0.6, 0.2, -1), 6.5, 1.15)
	await shot("m04_statue_back")
	# Awake, looking at the camera: the face
	ghoul.awake = true
	await wait(1.2)
	ghoul.reaching = 0.0
	look_head(Vector3(0.15, -0.1, 1), 1.5)
	ghoul.aim = camera.global_position
	await wait(1.0)
	look_head(Vector3(0.15, -0.1, 1), 1.5)
	await shot("m05_face")
	look_head(Vector3(0.9, 0.0, 0.6), 1.5)
	ghoul.aim = camera.global_position
	await wait(0.8)
	look_head(Vector3(0.9, 0.0, 0.6), 1.5)
	await wait(0.6)
	await shot("m06_face_quarter")
	# Shuffling (it is walked along under a camera that keeps with it)
	ghoul.aim = Vector3.INF
	var speed := 0.9
	var t := 0.0
	var taken := 0
	while taken < 3:
		ghoul.velocity = Vector3(0, 0, speed)
		var step := root.get_process_delta_time()
		ghoul.global_position += ghoul.velocity * step
		look(Vector3(0.9, 0.1, 0.5), 6.5, 1.15)
		await process_frame
		t += step
		if t > 2.0 + taken * 0.17:
			await shot("m%02d_shuffle_%d" % [7 + taken, taken])
			taken += 1
	ghoul.velocity = Vector3.ZERO
	# The scream
	ghoul.aim = ghoul.global_position + Vector3(0, 1.5, 3)
	await wait(0.8)
	ghoul.scream()
	await wait(0.45)
	look(Vector3(0.7, 0.1, 1), 6.0, 1.2)
	await shot("m10_scream_front")
	await wait(0.15)
	look(Vector3(1, 0.05, 0.1), 6.0, 1.2)
	await shot("m11_scream_side")
	await wait(2.0)
	# The grab: wide, closing, clinging (on a stand-in for a player)
	example.post.visible = true
	example.post.global_position = ghoul.global_position + ghoul.global_basis.z.normalized() * 1.25 + Vector3.UP * 0.8
	ghoul.aim = example.post.global_position + Vector3.UP * 0.4
	await wait(0.5)
	ghoul.grab()
	await wait(GhoulRig.REACH * 0.85)
	look(Vector3(0.6, 0.15, 1), 6.0, 1.2)
	await shot("m12_grab_wide")
	ghoul.held = true
	await wait(GhoulRig.REACH * 0.15 + GhoulRig.CLOSE * 0.9)
	look(Vector3(1, 0.15, 0.6), 6.0, 1.2)
	await shot("m13_grab_closing")
	await wait(0.5)
	await shot("m14_grab_clinging")
	# The same again with nothing in its arms, from the side and in front
	example.post.visible = false
	await wait(1.5)
	ghoul.grab()
	ghoul.held = true
	await wait(GhoulRig.REACH * 0.85)
	look(Vector3(1, 0.05, 0.05), 6.0, 1.2)
	await shot("m15_grab_wide_side")
	await wait(GhoulRig.REACH * 0.15 + GhoulRig.CLOSE + 0.3)
	await shot("m16_hug_side")
	look(Vector3(0.3, 0.1, 1), 6.0, 1.2)
	await wait(0.1)
	await shot("m17_hug_front")
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
	# (the round's own enemies are taken away: only the ghoul is wanted here)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# A dead end with a straight passage out of it
	var lair := nav.lairs(3)[0]
	var out := Vector2i(0, 1)
	var found := false
	for cell: Vector2i in nav.lairs(3):
		if not nav.dead_end(cell):
			continue
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step) and not maze.blocked(cell + step, step) and nav.allowed(cell + step * 2):
				lair = cell
				out = step
				found = true
				break
		if found:
			break
	var along := Vector3(out.x, 0, out.y)
	var bare := 0
	boy.global_position = maze.world(lair) + along * 16.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(-along.x, -along.z)
	world.camera._yaw = atan2(along.x, along.z)
	world.camera.snap()
	await wait(1.0)
	bare = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	boy.remove_from_group(&"maze_players")
	var keeper := MazeGhoul.new()
	keeper.maze = maze
	keeper.position = maze.world(lair) + Vector3.UP * 0.05
	keeper.rotation.y = atan2(along.x, along.z)
	world.add_child(keeper)
	# (a camera of our own, behind the boy, looking down the passage at it)
	var behind := Camera3D.new()
	world.add_child(behind)
	behind.fov = 50.0
	behind.global_position = boy.global_position + along * 5.0 + Vector3.UP * 3.0
	behind.look_at(keeper.global_position + Vector3.UP * 1.8)
	behind.make_current()
	await wait(1.0)
	await shot("z1_statue_in_its_dead_end")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	bare = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = true
	print("draws: %d with the ghoul in sight, %d with it hidden (+%d)" % [with_it, bare, with_it - bare])
	boy.add_to_group(&"maze_players")
	boy.global_position = maze.world(lair) + along * 9.0 + Vector3.UP * 0.1
	behind.global_position = boy.global_position + along * 4.5 + Vector3.UP * 2.6
	behind.look_at(keeper.global_position + Vector3.UP * 1.6)
	keeper.notice(boy)
	await wait(12.0, func() -> bool: return keeper.figure.stage() == GhoulRig.Stage.SCREAMING)
	await wait(0.2)
	await shot("z2_scream_at_the_boy")
	var side := Camera3D.new()
	world.add_child(side)
	var across := Vector3(along.z, 0, -along.x)
	side.global_position = boy.global_position + along * 3.0 + across * 2.5 + Vector3.UP * 2.2
	side.fov = 50.0
	side.look_at(keeper.global_position + Vector3.UP * 1.6)
	side.make_current()
	await wait(0.25)
	await shot("z3_scream_side")
	await wait(12.0, func() -> bool: return keeper.figure.stage() == GhoulRig.Stage.CLOSE)
	var middle := keeper.global_position.lerp(boy.global_position, 0.5)
	side.global_position = middle + across * 3.0 + along * 2.5 + Vector3.UP * 1.6
	side.look_at(middle + Vector3.UP * 1.2)
	await wait(0.1)
	await shot("z4_grab_side")
	side.queue_free()
	behind.queue_free()
	world.camera.make_current()
