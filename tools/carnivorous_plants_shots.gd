extends SceneTree
## Pictures of the giant carnivorous plants (creatures/carnivorous_plants/, and
## MazeFlytrap, MazeSundew and MazePitcher in scripts/enemies/). First on the
## component's own floor (example.gd): each close to, from the front, the side
## and above; the flytrap open, shivering, shut and full; the sundew bent over
## the post; the pitcher's lip and its lid down. Then in a hall of a real round
## (World): a clump of them by the wall feet, the boy walking up to a trap, the
## trap shut on him, him stuck on a sundew. Says how many draws a frame takes.
## Needs a real window:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/carnivorous_plants_shots.gd -- <folder> [studio|maze|sound]

var folder := "plant_shots"
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
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


## Looks at `at` from `direction` (world), `distance` off.
func look(at: Vector3, direction: Vector3, distance: float, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = at + direction.normalized() * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		Flytrap.creak_sound().save_to_wav("%s/creak.wav" % folder)
		Flytrap.clap_sound().save_to_wav("%s/clap.wav" % folder)
		Sundew.tear_sound().save_to_wav("%s/tear.wav" % folder)
		Pitcher.gulp_sound().save_to_wav("%s/gulp.wav" % folder)
		quit()
		return
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


func _studio() -> void:
	example = (load("res://creatures/carnivorous_plants/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still = true
	camera = example.camera
	camera.make_current()
	var trap: Flytrap = example.trap
	var dew: Sundew = example.dew
	var pit: Pitcher = example.pit
	var post: Node3D = example.post
	post.position = Vector3(0.0, -5.0, 0.0)
	await wait(0.5)
	var mouth := trap.mouth()
	look(mouth, Vector3(0.9, 0.7, 1.0), 6.0)
	await shot("s01_flytrap_open_quarter")
	look(mouth, Vector3(0.0, 0.5, 1.0), 5.5)
	await shot("s02_flytrap_open_front")
	look(mouth, Vector3(0.05, 1.0, 0.1), 4.5)
	await shot("s03_flytrap_open_above")
	look(trap.global_position + Vector3(0, 1.6, 1.0), Vector3(1.0, 0.35, 0.2), 9.0)
	await shot("s04_flytrap_side_whole")
	look(mouth, Vector3(0.3, 0.45, 1.0), 2.6, 50.0)
	await shot("s05_flytrap_inside_close")
	trap.twitch()
	await wait(0.12)
	look(mouth, Vector3(0.9, 0.7, 1.0), 6.0)
	await shot("s06_flytrap_shiver")
	await wait(0.6)
	post.position = mouth + Vector3(0, 0.1, 0)
	trap.snap()
	await wait(0.1)
	await shot("s07_flytrap_snapping")
	await wait(0.5)
	await shot("s08_flytrap_shut")
	look(mouth, Vector3(0.0, 0.5, 1.0), 5.5)
	await shot("s09_flytrap_shut_front")
	trap.full = true
	await wait(4.0)
	look(mouth, Vector3(0.9, 0.7, 1.0), 6.0)
	await shot("s10_flytrap_full")
	post.position = Vector3(0.0, -5.0, 0.0)
	# The sundew
	look(dew.global_position + Vector3(0, 0.3, 0), Vector3(0.6, 0.55, 1.0), 6.0)
	await shot("s11_sundew_quarter")
	look(dew.global_position + Vector3(0.0, 0.25, 1.2), Vector3(0.4, 0.4, 1.0), 2.0, 50.0)
	await shot("s12_sundew_close")
	look(dew.global_position, Vector3(0.05, 1.0, 0.1), 6.0)
	await shot("s13_sundew_above")
	post.position = dew.global_position + Vector3(0.4, 0.62, 1.1)
	dew.hold(post.position)
	await wait(2.0)
	look(dew.global_position + Vector3(0, 0.4, 0.6), Vector3(0.8, 0.5, 1.0), 4.5)
	await shot("s14_sundew_holding")
	post.position = Vector3(0.0, -5.0, 0.0)
	dew.let_go()
	# The pitcher
	look(pit.global_position + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 1.0), 5.0)
	await shot("s15_pitcher_quarter")
	look(pit.global_position + Vector3(0, 0.2, 0), Vector3(0.0, 1.0, 0.6), 3.2, 50.0)
	await shot("s16_pitcher_mouth")
	look(pit.global_position + Vector3(0, 0.5, 0), Vector3(1.0, 0.3, 0.1), 6.0)
	await shot("s17_pitcher_side")
	pit.swallow()
	await wait(1.0)
	look(pit.global_position + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 1.0), 5.0)
	await shot("s18_pitcher_shut")
	# All three, as a group
	look(Vector3(0, 0.5, 0), Vector3(0.0, 0.5, 1.0), 14.0)
	await shot("s19_all")
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
	# (the round's own hunters are taken away: only the plants are wanted here)
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	await wait(0.5)
	# A straight hall, away from the clearing
	var hall := Vector2i(-1, -1)
	var along := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and not maze.blocked(cell + s, s) and maze.blocked(cell, across):
				hall = cell
				along = s
				break
		if hall.x >= 0:
			break
	var forward := Vector3(along.x, 0, along.y)
	var across := Vector3(along.y, 0, along.x)
	var middle := maze.world(hall)
	var holder: MazeEnemies = world.enemies
	var trap := MazeFlytrap.new()
	holder.add(trap, hall, atan2(-across.x, -across.z), 1, across * 3.0)
	var dew := MazeSundew.new()
	holder.add(dew, hall, 0.0, 2, across * 2.0 + forward * 5.0)
	var pit := MazePitcher.new()
	holder.add(pit, hall, atan2(-across.x, -across.z), 3, across * 3.5 - forward * 4.5)
	boy.global_position = middle - forward * 12.0 - across * 2.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(forward.x, forward.z)
	world.camera._yaw = atan2(-forward.x, -forward.z)
	world.camera.snap()
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	eye.global_position = middle - forward * 9.0 - across * 3.0 + Vector3.UP * 3.0
	eye.look_at(middle + across * 2.0 + Vector3.UP * 0.5)
	eye.make_current()
	await wait(1.5)
	await shot("z1_plants_in_a_hall")
	eye.global_position = trap.global_position + forward * 5.0 - across * 4.0 + Vector3.UP * 2.5
	eye.look_at(trap.figure.mouth())
	await wait(0.3)
	await shot("z2_flytrap_by_the_wall")
	# The boy walks into the trap
	boy.global_position = trap.figure.mouth() - across * 2.5 + Vector3.UP * 0.1
	for i in 90:
		boy.global_position = boy.global_position.move_toward(trap.figure.mouth(), 1.6 / 60.0)
		await process_frame
		if trap.figure.is_snapping() or trap.figure.is_shut():
			break
	await wait(0.3)
	await shot("z3_flytrap_shut_on_him")
	# On the sundew
	await wait(2.0)
	boy.global_position = dew.global_position + forward * 1.0 - across * 0.6 + Vector3.UP * 0.1
	await wait(1.5)
	eye.global_position = dew.global_position - forward * 4.0 - across * 3.0 + Vector3.UP * 2.5
	eye.look_at(dew.global_position + Vector3.UP * 0.4)
	await wait(0.2)
	await shot("z4_stuck_on_a_sundew")
	eye.global_position = pit.global_position - across * 4.0 + forward * 2.0 + Vector3.UP * 2.2
	eye.look_at(pit.global_position + Vector3.UP * 0.3)
	await wait(0.2)
	await shot("z5_pitcher_by_the_wall")
