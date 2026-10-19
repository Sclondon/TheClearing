extends SceneTree
## Pictures of the woodsman and the beast (creatures/woodsman, creatures/beast) in a
## real round: each close to by day (the woodsman holding his lantern up at you, the
## beast with its lantern held out, humming), and each in a hall at night (the
## woodsman walking down it towards you, his lantern lighting the walls; the beast
## standing at the far end in the dark, its eyes and its lantern). Says how many
## draws each frame takes. Needs a real window, landscape:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/woods_shots.gd -- <folder> [woodsman|beast|sound]
##
## (sound only writes their sounds to <folder>/*.wav.)

var main: Node
var folder := "woods_shots"
var only := ""
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	if only == "sound":
		_sounds()
		return
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _sounds() -> void:
	Woodsman.chop_sound().save_to_wav("%s/chop.wav" % folder)
	Woodsman.step_sound().save_to_wav("%s/step.wav" % folder)
	Woodsman.grunt_sound().save_to_wav("%s/grunt.wav" % folder)
	Woodsman.swish_sound().save_to_wav("%s/swish.wav" % folder)
	OilLantern.creak_sound().save_to_wav("%s/creak.wav" % folder)
	Beast.hum_sound().save_to_wav("%s/hum.wav" % folder)
	Beast.reach_sound().save_to_wav("%s/reach.wav" % folder)
	print("saved the sounds in ", folder)
	quit()


func shot(name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, _draws()])


func _draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _run() -> void:
	for i in 5:
		await process_frame
	# (the same maze every time)
	seed(11)
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var maze: Maze = world.maze
	world.player.visible = false
	world.player.set_physics_process(false)
	world.weather.forced = Weather.Kind.OVERCAST
	# (the round's own hunters are put away: only these two are wanted)
	for enemy: MazeEnemy in world.enemies.enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = false
	if world.griever:
		world.griever.process_mode = Node.PROCESS_MODE_DISABLED
		world.griever.visible = false
	camera = Camera3D.new()
	camera.fov = 50.0
	world.add_child(camera)
	camera.make_current()
	# A long straight hall in the first section: four cells along it.
	var nav := MazeNav.new(maze)
	var start := Vector2i(-1, -1)
	var out := Vector2i(0, 1)
	for cell: Vector2i in nav.lairs(3):
		if maze.ring_of(cell) != 1:
			continue
		for s: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, s) and not maze.blocked(cell + s, s) and not maze.blocked(cell + s * 2, s) and not maze.blocked(cell + s * 3, s) and nav.allowed(cell + s * 4):
				start = cell
				out = s
				break
		if start.x >= 0:
			break
	var along := Vector3(out.x, 0, out.y)
	var across := Vector3(along.z, 0, -along.x)
	var base := nav.point(start)
	base.y = maze.ground_height(base)
	world.player.global_position = base + Vector3.UP * 0.2
	await wait(0.5)
	if only != "beast":
		await _woodsman(world, base, along, across)
	if only != "woodsman":
		await _beast(world, base, along, across)
	quit()


func _woodsman(world, base: Vector3, along: Vector3, across: Vector3) -> void:
	var maze: Maze = world.maze
	var man := Woodsman.new()
	world.add_child(man)
	var at := base + along * 14.0
	at.y = maze.ground_height(at)
	man.put(at, atan2(-along.x, -along.z))
	# Close to, by day: he has stopped and holds his lantern up at you.
	world.day.set_hour(15.0)
	camera.global_position = at - along * 3.3 + across * 1.4 + Vector3.UP * 1.75
	man.aim = camera.global_position
	man.raise = 0.85
	await wait(1.5)
	camera.look_at(at + Vector3.UP * 1.45)
	await shot("w1_woodsman_close_day")
	# His face, under the brim.
	var face: Vector3 = man.eyes()
	var was: Vector3 = camera.global_position
	camera.global_position = face + (was - face).normalized() * 1.1
	camera.look_at(face - Vector3.UP * 0.05)
	await shot("w0_woodsman_face")
	camera.global_position = was
	camera.look_at(at + Vector3.UP * 1.45)
	# The same, from the side, the axe over his shoulder.
	camera.global_position = at + across * 3.6 - along * 0.6 + Vector3.UP * 1.6
	camera.look_at(at + Vector3.UP * 1.3)
	man.raise = 0.0
	man.aim = Vector3.INF
	await wait(1.0)
	await shot("w2_woodsman_side_day")
	# Chopping at the wall.
	var wall := _wall_beside(world, at, across)
	if wall.is_finite():
		var into := wall - at
		into.y = 0.0
		into = into.normalized()
		var stand := wall - into * 1.05
		stand.y = maze.ground_height(stand)
		man.put(stand, atan2(into.x, into.z))
		man.aim = wall + Vector3.UP * 1.3
		man.chop()
		await wait(WoodsmanRig.DRAW * 0.9)
		camera.global_position = stand - into * 2.6 - along * 2.6 + Vector3.UP * 1.7
		camera.look_at(stand + Vector3.UP * 1.3 + into * 0.4)
		await shot("w3_woodsman_chop_drawn")
		await wait(WoodsmanRig.DRAW * 0.1 + WoodsmanRig.STROKE * 0.9)
		await shot("w4_woodsman_chop_stroke")
		await wait(3.0)
	# The swing: the axe up over his head.
	man.put(at, atan2(-along.x, -along.z))
	man.aim = at - along * 1.6 + Vector3.UP * 1.0
	man.swing()
	await wait(0.8)
	camera.global_position = at - along * 3.4 + across * 2.0 + Vector3.UP * 1.5
	camera.look_at(at + Vector3.UP * 1.6)
	await shot("w5_woodsman_axe_raised")
	man.strike()
	await wait(0.14)
	await shot("w6_woodsman_axe_down")
	await wait(1.0)
	# In the hall at night, walking down it towards you, his lantern lighting the walls.
	world.day.set_hour(23.0)
	var from := base + along * 26.0
	from.y = maze.ground_height(from)
	man.put(from, atan2(-along.x, -along.z))
	man.aim = Vector3.INF
	var t := 0.0
	while t < 2.5:
		var step := root.get_process_delta_time()
		man.velocity = -along * 1.05
		man.global_position += man.velocity * step
		man.global_position.y = maze.ground_height(man.global_position)
		await process_frame
		t += step
	camera.global_position = man.global_position - along * 8.0 + across * 1.5 + Vector3.UP * 1.6
	camera.look_at(man.global_position + Vector3.UP * 1.4 - along * 2.0)
	await shot("w7_woodsman_hall_night")
	man.velocity = Vector3.ZERO
	man.queue_free()
	await wait(0.3)


func _beast(world, base: Vector3, along: Vector3, across: Vector3) -> void:
	var maze: Maze = world.maze
	var beast := Beast.new()
	world.add_child(beast)
	var at := base + along * 14.0
	at.y = maze.ground_height(at)
	beast.put(at, atan2(-along.x, -along.z))
	# Close to, by day, low: its lantern held out at you, its eyes on you.
	world.day.set_hour(15.0)
	camera.global_position = at - along * 6.5 + across * 1.8 + Vector3.UP * 1.3
	beast.aim = camera.global_position
	beast.lure = 1.0
	await wait(2.5)
	camera.look_at(at + Vector3.UP * 2.5)
	await shot("b1_beast_close_day")
	# Reaching.
	beast.reach()
	await wait(BeastRig.WIND * 0.85)
	await shot("b2_beast_reach_wind")
	await wait(1.5)
	# At night, at the far end of the hall, luring: its eyes and its lantern in the dark.
	world.day.set_hour(23.0)
	var far := base + along * 34.0
	far.y = maze.ground_height(far)
	beast.put(far, atan2(-along.x, -along.z))
	camera.global_position = base + along * 8.0 + across * 0.8 + Vector3.UP * 1.5
	beast.aim = camera.global_position
	beast.lure = 1.0
	await wait(2.5)
	camera.look_at(far + Vector3.UP * 2.0)
	await shot("b3_beast_hall_night")
	# Nearer in the mist, at dusk, not luring: a silhouette.
	world.day.set_hour(19.3)
	beast.lure = 0.0
	var mid := base + along * 24.0
	mid.y = maze.ground_height(mid)
	beast.put(mid, atan2(-along.x, -along.z))
	await wait(2.0)
	camera.look_at(mid + Vector3.UP * 2.2)
	await shot("b4_beast_hall_dusk")
	beast.queue_free()


## The face of the wall to one side of `at` (along `across`), or INF.
func _wall_beside(world, at: Vector3, across: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.2
	for way: Vector3 in [across, -across]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 12.0, 1, [world.player.get_rid()]))
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.3:
			var p: Vector3 = hit["position"]
			return Vector3(p.x, at.y, p.z)
	return Vector3.INF
