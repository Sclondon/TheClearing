extends SceneTree
## Pictures of the fish person (creatures/fish_person/, and MazeFishPerson in
## scripts/enemies/). First on the component's own floor
## (creatures/fish_person/example.gd): the model close to, from the front, the
## side, three quarters and behind, and its face; then each of the things it
## does, caught partway through: down in its pool to the eyes, rising out of
## it, a shamble step, the lope, the croak at its height, the lunge, the hands
## clamping, holding. Then in a passage of a real round (World): lurking in its
## pool, risen and croaking at the boy, lunging at him. Says how many draws a
## frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/fish_person_shots.gd -- <folder> [model|maze|sound|low]
##
## (sound only writes the croak to <folder>/croak.wav, to listen to or look at;
## low takes the model pictures of the low-poly model.)

var folder := "fish_person_shots"
var only := ""
var example: Node3D
var fish: FishPerson
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


## Looks at the fish person from `direction` (in its own frame: +Z its front), `distance` off, at `height`.
func look(direction: Vector3, distance: float, height: float, fov := 30.0) -> void:
	var at := fish.global_position + Vector3.UP * height
	camera.fov = fov
	camera.global_position = at + (fish.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


## Looks at its face from `direction` (in its own frame), `distance` off.
func look_head(direction: Vector3, distance: float) -> void:
	var head: Node3D = fish._rig._head
	var at := head.global_transform * Vector3(0.0, 0.06, 0.07)
	camera.fov = 30.0
	camera.global_position = at + (fish.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		FishPerson.croak_sound().save_to_wav("%s/croak.wav" % folder)
		print("saved %s/croak.wav" % folder)
		quit()
		return
	if only != "maze":
		await _model()
	if only != "model" and only != "low" and only != "face":
		await _maze()
	quit()


func _model() -> void:
	if only == "low":
		Settings.low_poly = true
	example = (load("res://creatures/fish_person/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still_camera = true
	example.set_process(false)
	fish = example.fish
	camera = example.camera
	example.post.visible = false
	camera.make_current()
	fish.put(Vector3.ZERO, 0.0)
	fish.awake = true
	await wait(1.2)
	look(Vector3(0, 0.05, 1), 7.0, 1.05)
	await shot("m01_front")
	look(Vector3(1, 0.05, 0), 7.0, 1.05)
	await shot("m02_side")
	look(Vector3(0.8, 0.15, 1), 7.0, 1.05)
	await shot("m03_quarter")
	look(Vector3(-0.6, 0.2, -1), 7.0, 1.05)
	await shot("m04_back")
	# The face, looking at the camera
	fish.reaching = 0.0
	look_head(Vector3(0.12, -0.05, 1), 1.6)
	fish.aim = camera.global_position
	await wait(1.0)
	look_head(Vector3(0.12, -0.05, 1), 1.6)
	await shot("m05_face")
	look_head(Vector3(0.9, 0.05, 0.7), 1.6)
	fish.aim = camera.global_position
	await wait(0.9)
	look_head(Vector3(0.9, 0.05, 0.7), 1.6)
	await shot("m06_face_quarter")
	look_head(Vector3(1, 0.02, 0.0), 1.7)
	fish.aim = fish.global_position + fish.global_basis.z * 4.0 + Vector3.UP * 2.0
	await wait(0.9)
	look_head(Vector3(1, 0.02, 0.0), 1.7)
	await shot("m07_face_side")
	if only == "face":
		return
	# The croak, at its height
	fish.croak()
	await wait(FishPersonRig.SWELL + 0.35)
	look(Vector3(0.6, 0.1, 1), 5.5, 1.2)
	await shot("m08_croak")
	await wait(0.1)
	look_head(Vector3(0.7, 0.0, 1), 1.8)
	await shot("m09_croak_face")
	await wait(2.0)
	# Shambling (it is walked along under a camera that keeps with it)
	fish.aim = Vector3.INF
	fish.reaching = 1.0
	await _walk(1.2, 3, "m1%d_shamble", Vector3(0.9, 0.1, 0.5))
	await _walk(4.6, 3, "m1%d_lope", Vector3(1.0, 0.1, 0.3), 3)
	fish.velocity = Vector3.ZERO
	await wait(1.5)
	# The grab: the lunge, the hands clamping, holding (on a stand-in for a player)
	example.post.visible = true
	example.post.global_position = fish.global_position + fish.global_basis.z.normalized() * 1.5 + Vector3.UP * 0.8
	fish.aim = example.post.global_position + Vector3.UP * 0.3
	await wait(0.5)
	fish.grab()
	await wait(FishPersonRig.WIND + FishPersonRig.LUNGE * 0.7)
	look(Vector3(1, 0.12, 0.35), 6.0, 1.1)
	await shot("m20_lunge_side")
	fish.held = true
	await wait(FishPersonRig.LUNGE * 0.3 + FishPersonRig.CLOSE * 0.8)
	await shot("m21_clamp")
	await wait(0.5)
	look(Vector3(0.5, 0.12, 1), 6.0, 1.1)
	await shot("m22_holding")
	example.post.visible = false
	await wait(1.5)
	fish.grab()
	await wait(FishPersonRig.WIND + FishPersonRig.LUNGE * 0.7)
	look(Vector3(0.35, 0.05, 1), 5.5, 1.0)
	await shot("m23_lunge_front")
	await wait(2.0)
	# Squatting, and down in its pool
	fish.awake = false
	fish.global_position = example.pool.global_position
	await wait(1.6)
	look(Vector3(0.8, 0.12, 1), 6.0, 0.7)
	await shot("m24_squat")
	fish.put(example.pool.global_position, 0.0, true)
	await wait(1.0)
	look(Vector3(0.3, 0.12, 1), 5.0, 0.3)
	await shot("m25_lurking")
	look(Vector3(0.3, 0.05, 1), 2.2, 0.3)
	await shot("m26_lurking_close")
	fish.emerge()
	await wait(FishPerson.RISE_TIME * 0.55)
	look(Vector3(0.6, 0.12, 1), 6.0, 0.8)
	await shot("m27_rising")
	await wait(FishPerson.RISE_TIME * 0.5)
	await shot("m28_risen")
	example.queue_free()
	await wait(0.2)


## Walks it along under a camera that keeps with it, taking `count` pictures.
func _walk(speed: float, count: int, name: String, from: Vector3, first := 0) -> void:
	var t := 0.0
	var taken := 0
	while taken < count:
		fish.velocity = Vector3(0, 0, speed)
		var step := root.get_process_delta_time()
		fish.global_position += fish.velocity * step
		look(from, 7.5, 1.0)
		await process_frame
		t += step
		if t > 1.6 + taken * 0.13:
			await shot(name % (first + taken))
			taken += 1
	fish.velocity = Vector3.ZERO


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Node3D = world.player
	boy.takes_input = false
	# (the round's own enemies are taken away: only the fish person is wanted here)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# A hall running straight for a few cells
	var lair := nav.lairs(3)[0]
	var out := Vector2i(0, 1)
	var found := false
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step) and not maze.blocked(cell + step, step) and nav.allowed(cell + step * 2) and not maze.blocked(cell, -step):
				lair = cell
				out = step
				found = true
				break
		if found:
			break
	var along := Vector3(out.x, 0, out.y)
	boy.remove_from_group(&"maze_players")
	boy.global_position = maze.world(lair) + along * 13.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(-along.x, -along.z)
	var keeper := MazeFishPerson.new()
	keeper.maze = maze
	keeper.position = maze.world(lair) + Vector3.UP * 0.05
	keeper.rotation.y = atan2(along.x, along.z)
	world.add_child(keeper)
	# (a camera of our own, behind the boy, looking down the hall at it)
	var behind := Camera3D.new()
	world.add_child(behind)
	behind.fov = 50.0
	behind.global_position = boy.global_position + along * 4.0 + Vector3.UP * 2.6
	behind.look_at(keeper.global_position + Vector3.UP * 0.4)
	behind.make_current()
	await wait(1.5)
	await shot("z1_pool_in_the_hall")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = false
	keeper.pool.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = true
	keeper.pool.visible = true
	print("draws: %d with the fish person in sight in its pool, %d with them hidden (+%d)" % [with_it, bare, with_it - bare])
	behind.global_position = keeper.global_position + along * 3.0 + Vector3(along.z, 0, -along.x) * 1.0 + Vector3.UP * 1.2
	behind.look_at(keeper.global_position + Vector3.UP * 0.2)
	await wait(0.3)
	await shot("z2_eyes_in_the_water")
	# He runs up: it rises, and croaks
	boy.add_to_group(&"maze_players")
	boy.global_position = maze.world(lair) + along * 8.0 + Vector3.UP * 0.1
	behind.global_position = boy.global_position + along * 4.0 + Vector3.UP * 2.4
	behind.look_at(keeper.global_position + Vector3.UP * 1.3)
	keeper.notice(boy)
	await wait(FishPerson.RISE_TIME * 0.5)
	await shot("z3_rising")
	await wait(6.0, func() -> bool: return keeper.figure.stage() == FishPersonRig.Stage.CROAKING)
	await wait(0.35)
	await shot("z4_croaking_at_the_boy")
	var standing := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var without := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.figure.visible = true
	print("draws: %d with the fish person up in sight, %d with it hidden (+%d)" % [standing, without, standing - without])
	var side := Camera3D.new()
	world.add_child(side)
	var across := Vector3(along.z, 0, -along.x)
	side.fov = 50.0
	side.make_current()
	side.global_position = keeper.global_position + along * 2.5 + across * 3.5 + Vector3.UP * 1.8
	side.look_at(keeper.global_position + along * 2.0 + Vector3.UP * 1.2)
	await wait(0.2)
	await shot("z5_croak_side")
	await wait(12.0, func() -> bool: return keeper.figure.stage() == FishPersonRig.Stage.LUNGE)
	var middle := keeper.global_position.lerp(boy.global_position, 0.5)
	side.global_position = middle + across * 3.5 + Vector3.UP * 1.6
	side.look_at(middle + Vector3.UP * 1.1)
	await wait(0.12)
	await shot("z6_lunge_at_the_boy")
	side.queue_free()
	behind.queue_free()
	world.camera.make_current()
