extends SceneTree
## Pictures of the mushroom zombie (creatures/mushroom_zombie/, and
## MazeMushroomZombie in scripts/enemies/). First on the component's own floor
## (example.gd): him from the front, the side, three quarters and behind, his
## head close to; a strip of his steps in fits; listening; lunging, and
## clinging; rising out of the ground; by night (the growths glowing faintly).
## Then a horde in a hall of a real round (World), the boy running near them,
## and one lunging at him. Says how many draws a frame takes. Needs a real window:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/mushroom_zombie_shots.gd -- <folder> [studio|strip|maze|sound]

var folder := "zombie_shots"
var only := ""
var camera: Camera3D
var zombie: MushroomZombie


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
	print("saved %s.png  (%d draws)" % [name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


## Looks at him from `direction` (in his own frame: +Z his front), `distance` off, at `height`.
func look(direction: Vector3, distance: float, height: float, fov := 30.0) -> void:
	var at := zombie.global_position + Vector3.UP * height
	camera.fov = fov
	camera.global_position = at + (zombie.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


## Walks him along +Z at `speed` for `seconds`, the camera keeping with him.
func walk(speed: float, seconds: float, direction := Vector3(0.9, 0.15, 0.5), distance := 4.5) -> void:
	var t := 0.0
	while t < seconds:
		var step := root.get_process_delta_time()
		zombie.velocity = Vector3(0, 0, speed)
		zombie.global_position += zombie.velocity * step
		look(direction, distance, 0.75)
		await process_frame
		t += step


func _run() -> void:
	if only == "sound":
		MushroomZombie.clicks_sound().save_to_wav("%s/clicks.wav" % folder)
		quit()
		return
	if only in ["", "studio", "strip"]:
		await _studio()
	if only in ["", "maze"]:
		await _maze()
	quit()


func _studio() -> void:
	var example: Node3D = (load("res://creatures/mushroom_zombie/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still = true
	camera = example.camera
	camera.make_current()
	zombie = example.zombie
	example.post.visible = false
	zombie.put(Vector3.ZERO, 0.0)
	zombie.risen = 1.0
	zombie._rising = 0.0
	await wait(1.0)
	if only != "strip":
		look(Vector3(0, 0.05, 1), 4.0, 0.7)
		await shot("m01_front")
		look(Vector3(1, 0.05, 0), 4.0, 0.7)
		await shot("m02_side")
		look(Vector3(0.8, 0.2, 1), 4.0, 0.7)
		await shot("m03_quarter")
		look(Vector3(-0.6, 0.25, -1), 4.0, 0.7)
		await shot("m04_back")
		look(Vector3(0.5, 0.15, 1), 1.3, 1.0)
		await shot("m05_head")
		look(Vector3(-0.7, 0.3, -0.6), 1.4, 0.95)
		await shot("m06_head_back")
	# A strip of his steps
	for k in 4:
		await walk(0.7, 0.45)
		await shot("m%02d_shamble_%d" % [7 + k, k])
	await walk(2.6, 1.2)
	await shot("m11_lurch")
	await walk(2.6, 0.25)
	await shot("m12_lurch_b")
	if only == "strip":
		example.queue_free()
		return
	zombie.velocity = Vector3.ZERO
	# Listening, to something off to his left
	zombie.aim = zombie.global_position + Vector3(2.5, 1.0, 2.0)
	zombie.listen()
	await wait(0.5)
	look(Vector3(0.3, 0.1, 1), 3.5, 0.75)
	await shot("m13_listening")
	await wait(1.0)
	# The lunge at the post
	example.post.visible = true
	example.post.global_position = zombie.global_position + zombie.global_basis.z.normalized() * 1.0 + Vector3.UP * 0.62
	zombie.aim = example.post.global_position
	zombie.lunge()
	await wait(MushroomZombieRig.REACH * 0.8)
	look(Vector3(1, 0.15, 0.4), 4.0, 0.75)
	await shot("m14_lunge")
	zombie.held = true
	await wait(MushroomZombieRig.REACH * 0.2 + MushroomZombieRig.CLOSE + 0.2)
	await shot("m15_clinging")
	await wait(2.0)
	example.post.visible = false
	# Rising out of the ground
	zombie.rise()
	await wait(MushroomZombie.RISE_TIME * 0.35)
	look(Vector3(0.7, 0.2, 1), 4.0, 0.6)
	await shot("m16_rising")
	await wait(MushroomZombie.RISE_TIME * 0.35)
	await shot("m17_rising_b")
	await wait(MushroomZombie.RISE_TIME * 0.4)
	# By night
	MushroomLook.set_night(1.0)
	var sun: DirectionalLight3D = example.find_children("*", "DirectionalLight3D", false, false)[0]
	sun.light_energy = 0.08
	(example.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment.ambient_light_energy = 0.1
	await wait(0.3)
	look(Vector3(0.6, 0.1, 1), 3.0, 0.8)
	await shot("m18_night")
	MushroomLook.set_night(0.0)
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
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	await wait(0.5)
	var hall := nav.lairs(4)[0]
	var along := Vector2i(1, 0)
	var found := false
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and not maze.blocked(cell + s, s) and nav.allowed(cell + s * 2):
				hall = cell
				along = s
				found = true
				break
		if found:
			break
	var forward := Vector3(along.x, 0, along.y)
	var middle := maze.world(hall)
	var horde := MazeMushroomZombie.horde_of(3, 1)
	for k in horde.size():
		world.enemies.add(horde[k], hall, randf() * TAU, k + 3, Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0)))
	boy.global_position = middle + forward * 14.0 + Vector3.UP * 0.1
	boy.remove_from_group(&"maze_players")
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.global_position = middle + forward * 7.0 + Vector3.UP * 2.0 + Vector3(forward.z, 0, forward.x) * 2.0
	eye.look_at(middle + Vector3.UP * 0.8)
	eye.make_current()
	await wait(2.5)
	await shot("z1_horde_in_a_hall")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	for one in horde:
		(one as Node3D).visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	for one in horde:
		(one as Node3D).visible = true
	print("draws: %d with the horde in sight, %d without (+%d, %d of them)" % [with_it, bare, with_it - bare, horde.size()])
	# The boy runs by: they hear him, listen, and lurch after him
	boy.add_to_group(&"maze_players")
	var from: Vector3 = middle + forward * 9.0
	for i in 60:
		boy.global_position = from - forward * (i / 60.0) * 3.0 + Vector3.UP * 0.1
		boy.velocity = -forward * 4.4
		await physics_frame
	boy.velocity = Vector3.ZERO
	await wait(0.6)
	await shot("z2_they_hear_him")
	await wait(1.5)
	await shot("z3_lurching_at_him")
	var lunged := await wait(8.0, func() -> bool: return horde.any(func(z: MazeMushroomZombie) -> bool: return z.figure.stage() == MushroomZombieRig.Stage.REACH))
	if lunged:
		var near: MazeMushroomZombie = horde[0]
		for z: MazeMushroomZombie in horde:
			if z.figure.stage() == MushroomZombieRig.Stage.REACH:
				near = z
		eye.global_position = near.global_position.lerp(boy.global_position, 0.5) + Vector3(forward.z, 0, forward.x) * 3.0 + Vector3.UP * 1.4
		eye.look_at(near.global_position.lerp(boy.global_position, 0.5) + Vector3.UP * 0.7)
		await shot("z4_lunge")
