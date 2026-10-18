extends SceneTree
## Pictures of the mushrooms (creatures/mushrooms/, and MazeMushrooms in
## scripts/enemies/). First on the component's own floor (example.gd): the wall
## of them by day, close to (a tuft, the shelves, the bonnets, a puffball), by
## night (the bonnets glowing), a puffball puffing and its cloud. Then a patch
## in a hall of a real round (World), by day and by night, and the boy in a
## cloud of its spores (the veil). Says how many draws a frame takes. Needs a
## real window:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/mushrooms_shots.gd -- <folder> [studio|maze|sound]

var folder := "mushroom_shots"
var only := ""
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
	print("saved %s.png  (%d draws)" % [name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func look(at: Vector3, direction: Vector3, distance: float, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = at + direction.normalized() * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		MushroomPatch.cough_sound().save_to_wav("%s/cough.wav" % folder)
		quit()
		return
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


func _studio() -> void:
	var example: Node3D = (load("res://creatures/mushrooms/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still = true
	camera = example.camera
	camera.make_current()
	var patch: MushroomPatch = example.patch
	example.post.position = Vector3(0.0, -5.0, 0.0)
	example.set_daylight(1.0)
	await wait(0.4)
	look(Vector3(0.0, 1.0, -2.5), Vector3(0.1, 0.25, 1.0), 9.0)
	await shot("s01_wall_by_day")
	look(Vector3(-6.0, 0.3, -2.7), Vector3(0.4, 0.5, 1.0), 2.0, 45.0)
	await shot("s02_tuft_close")
	look(Vector3(-4.5, 1.4, -3.0), Vector3(0.6, 0.0, 1.0), 3.5, 45.0)
	await shot("s03_shelves_close")
	look(Vector3(-3.0, 0.6, -2.6), Vector3(0.3, 0.2, 1.0), 2.4, 45.0)
	await shot("s04_bonnets_close")
	look(patch.puffballs[1] + Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 1.0), 1.8, 45.0)
	await shot("s05_puffball_close")
	example.set_daylight(0.0)
	await wait(0.3)
	look(Vector3(0.0, 1.0, -2.5), Vector3(0.1, 0.25, 1.0), 9.0)
	await shot("s06_wall_by_night")
	look(Vector3(-3.0, 0.6, -2.6), Vector3(0.3, 0.2, 1.0), 2.4, 45.0)
	await shot("s07_bonnets_glowing")
	example.set_daylight(0.8)
	look(patch.puffballs[1] + Vector3(0, 0.8, 0), Vector3(0.4, 0.35, 1.0), 6.0)
	patch.puff(1)
	await wait(0.35)
	await shot("s08_puff")
	await wait(1.2)
	await shot("s09_cloud")
	await wait(2.5)
	await shot("s10_cloud_settling")
	# The veil, as if breathing it
	look(Vector3(0.0, 1.0, -2.5), Vector3(0.1, 0.25, 1.0), 6.0)
	for i in 40:
		SporeVeil.report(self, example, 0.85)
		await process_frame
	await shot("s11_veil")
	SporeVeil.report(self, example, 0.0)
	example.queue_free()
	await wait(2.0)


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
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
				hall = cell
				along = s
				break
		if hall != nav.lairs(4)[0]:
			break
	var forward := Vector3(along.x, 0, along.y)
	var middle := maze.world(hall)
	var mushrooms := MazeMushrooms.new()
	world.enemies.add(mushrooms, hall, 0.0, 7)
	boy.global_position = middle - forward * 13.0 + Vector3.UP * 0.1
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.global_position = middle - forward * 8.0 + Vector3.UP * 2.2
	eye.look_at(middle + Vector3.UP * 0.6)
	eye.make_current()
	await wait(1.5)
	await shot("z1_patch_in_a_hall")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	mushrooms.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	mushrooms.visible = true
	print("draws: %d with the patch in sight, %d without (+%d)" % [with_it, bare, with_it - bare])
	var day: Node = world.get(&"day")
	if day:
		day.set(&"seconds", float(day.get(&"day_seconds")) * 0.98 + 60.0)
	await wait(3.0)
	await shot("z2_patch_at_night")
	if day:
		day.set(&"seconds", 0.0)
	await wait(2.5)
	# The boy walks onto a puffball: the cloud, from behind him, and what he sees
	var ball: Vector3 = mushrooms.patch.puffballs[0]
	boy.global_position = ball - forward * 3.0 + Vector3.UP * 0.1
	world.camera._yaw = atan2(-forward.x, -forward.z)
	world.camera.snap()
	world.camera.make_current()
	for i in 80:
		boy.global_position = boy.global_position.move_toward(Vector3(ball.x, boy.global_position.y, ball.z), 1.6 / 60.0)
		await process_frame
		if mushrooms.puffs > 0:
			break
	await wait(1.0)
	await shot("z3_in_the_spores")
