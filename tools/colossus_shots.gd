extends SceneTree
## Pictures of the colossus (creatures/colossus/, and MazeColossus, its hunter
## in the maze), in a real round. Needs a real window (the engine draws nothing
## headless):
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/colossus_shots.gd -- <folder> [maze|clearing|all]
##
## maze: the whole of it crawling over the maze (the mist thinned, from far and
## high); from the boy's height in a hall under it as it crawls over (the money
## shot); a hand coming down on a wall top; its eye peering down between the
## walls with its finger over him; the fingertip coming down at him; the finger
## pressing where he was, and him in a slot; and how many draws it costs.
## clearing: from the middle of the clearing as it rears up to look over the
## great wall, and the same from over the maze.

var folder := "colossus_shots"
var what := "all"
var camera: Camera3D
var world: Node3D
var maze: Maze
var boy: Player
var hunter: MazeColossus
var environment: Environment


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
	print("saved %s/%s.png  (%d draws, %d primitives)" % [folder, name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
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
	await _round()
	if what in ["maze", "all"]:
		await _maze()
	if what in ["clearing", "all"]:
		await _from_the_clearing()
	quit()


## A round of the game, with nothing hunting in it, and a camera of our own.
func _round() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 2), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	boy = world.player
	boy.takes_input = false
	for child in world.get_children():
		if child is MazeEnemy or child is Griever or child is MazeEnemies:
			child.queue_free()
		if child is WorldEnvironment:
			environment = (child as WorldEnvironment).environment
	camera = Camera3D.new()
	camera.far = 4000.0
	world.add_child(camera)
	camera.make_current()
	await wait(0.5)


## A cell in the first ring with a long straight run of hall on from it (`run`
## cells open each way along), and that way.
func _long_hall(run: int) -> Array:
	for c: Vector2i in MazeNav.new(maze).lairs(3):
		# (out in the ring, away from the great wall round the clearing)
		if maze.ring_of(c) != 1 or maze.depth_in_ring(c) < maze.rampart(1) + 3:
			continue
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in range(-run, run):
				if maze.blocked(c + step * k, step) or maze.ring_of(c + step * (k + 1)) != 1:
					ok = false
					break
			if ok:
				return [c, step]
	return []


func _spawn_at(at: Vector3, yaw: float) -> MazeColossus:
	if hunter:
		hunter.queue_free()
		await process_frame
	hunter = MazeColossus.new()
	hunter.maze = maze
	hunter.seed_choices(3)
	hunter.position = at
	hunter.rotation.y = yaw
	# (held still until it is told where to go)
	hunter._pause = 1e9
	world.add_child(hunter)
	await process_frame
	return hunter


## The middle of the hall through `cell` (between it and its neighbour across, if the hall is two wide).
func _hall_middle(cell: Vector2i, across: Vector3) -> Vector3:
	for side: float in [1.0, -1.0]:
		var step := Vector2i(int(across.x * side), int(across.z * side))
		if not maze.blocked(cell, step) and maze.ring_of(cell + step) == 1:
			return (maze.world(cell) + maze.world(cell + step)) * 0.5
	return maze.world(cell)


func _maze() -> void:
	var found := _long_hall(3)
	if found.is_empty():
		print("no long hall")
		return
	var cell: Vector2i = found[0]
	var step: Vector2i = found[1]
	var along := Vector3(step.x, 0, step.y)
	var across := Vector3(step.y, 0, step.x)
	var middle := _hall_middle(cell, across)
	world.put_player(middle + Vector3.UP * 0.05, atan2(along.x, along.z))
	await wait(0.5)

	# It crawls over him: from well up the hall, on over him and beyond.
	var giant := await _spawn_at(middle + along * 18.0, atan2(-along.x, -along.z))
	giant.sense_range = 0.0
	giant._goal = middle - along * 400.0
	giant._pause = 0.0
	await wait(20.0, func() -> bool: return giant.figure.stepping() >= 0 and giant.figure.step_progress() > 0.4)
	print("  its middle is %.0f m from him, %.0f m up" % [Vector2(giant.figure.pelvis().x - middle.x, giant.figure.pelvis().z - middle.z).length(), giant.figure.pelvis().y])
	# (from his height, straight up at its underside: its body, its limbs arching over the walls)
	look(middle + across * 2.0 + Vector3.UP * 1.5, giant.figure.pelvis() + Vector3.UP * 5.0, 90.0)
	await shot("a1_money_underneath")
	look(middle - along * 6.0 - across * 2.5 + Vector3.UP * 1.3, giant.figure.pelvis() + along * 30.0 + Vector3.UP * 40.0, 85.0)
	await shot("a2_money_looking_up_the_hall")
	# A hand coming down on a wall top (dust and stones raining into the hall).
	await wait(20.0, func() -> bool: return giant.figure.stepping() == Colossus.HAND_L or giant.figure.stepping() == Colossus.HAND_R)
	var limb := giant.figure.stepping()
	var landing := giant.figure.landing(limb)
	await wait(10.0, func() -> bool: return giant.figure.step_progress() > 0.8)
	var below := Vector3(landing.x, 0.0, landing.z)
	var spot := below
	for r: float in [12.0, 16.0, 20.0, 26.0]:
		for k in 8:
			var p := below + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * r
			if giant.clear_of_walls(p, 2.0):
				spot = p
				break
		if spot != below:
			break
	look(spot + Vector3.UP * 1.6, landing + Vector3.UP * 4.0, 75.0)
	await shot("b1_hand_coming_down")
	await wait(3.0, func() -> bool: return giant.figure.stepping() < 0)
	await wait(0.5)
	await shot("b2_hand_down_dust")
	# The whole of it over the maze, far and high (the mist thinned).
	var fog := environment.fog_density if environment else 0.0
	if environment:
		environment.fog_density = 0.0016
	var centre := giant.figure.pelvis()
	# (from outside the ring, where no great wall is in the way)
	var outward := Vector3(signf(centre.x), 0, 0) if absf(centre.x) > absf(centre.z) else Vector3(0, 0, signf(centre.z))
	var sideways := Vector3(outward.z, 0, outward.x)
	look(centre + outward * 230.0 + sideways * 140.0 + Vector3.UP * 190.0, centre + Vector3.UP * 40.0, 50.0)
	await shot("f1_whole_over_the_maze")
	look(centre + outward * 330.0 - sideways * 60.0 + Vector3.UP * 55.0, centre + Vector3.UP * 70.0, 45.0)
	await shot("f2_whole_from_the_side")
	if environment:
		environment.fog_density = fog

	# The finger: it sees him out in the open, peers down, presses.
	giant.queue_free()
	hunter = null
	await wait(0.3)
	world.put_player(middle + Vector3.UP * 0.05, atan2(along.x, along.z))
	var presser := await _spawn_at(middle + along * 75.0, atan2(-along.x, -along.z))
	presser.sense_range = 0.0
	await wait(0.5)
	# (somewhere out in the open that its eyes can see, ahead of it, along a straight hall)
	var target := Vector3.INF
	var hall := Vector3.ZERO
	var facing := Basis(Vector3.UP, presser.figure.body_yaw()).z
	for d: float in [70.0, 60.0, 80.0, 50.0, 90.0, 100.0]:
		for spread: float in [0.0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75]:
			var p := presser.figure.pelvis() + Basis(Vector3.UP, spread) * facing * d
			p.y = 0.0
			if maze.ring_of(maze.cell_at(p)) != 1 or not presser.clear_of_walls(p, 4.0):
				continue
			var way := presser.hall_along(p)
			if not presser.clear_of_walls(p + way * 14.0, 2.0) or not presser.clear_of_walls(p - way * 14.0, 2.0):
				continue
			world.put_player(p + Vector3.UP * 0.05, 0.0)
			await wait(0.1)
			if not presser.hidden(boy, presser.figure.eye()):
				target = p
				hall = way
				break
		if target.is_finite():
			break
	if not target.is_finite():
		print("  nowhere it can see him")
		return
	var side := hall.cross(Vector3.UP)
	# (behind him in his hall: the camera, at a boy's height)
	var behind := target - hall * 13.0 if (target - hall * 13.0).distance_to(presser.figure.pelvis()) > (target + hall * 13.0).distance_to(presser.figure.pelvis()) else target + hall * 13.0
	presser.sense_range = 200.0
	presser._press_in = 0.0
	boy.add_to_group(&"maze_players")
	await wait(25.0, func() -> bool: return presser.figure.press_stage() == Colossus.Press.HOVER)
	await wait(1.2)
	print("  pressing: stage %s, tip %s, boy %s" % [Colossus.Press.keys()[presser.figure.press_stage()], presser.figure.fingertip(), boy.global_position])
	# (up past him at its head peering down between the walls, its finger over him)
	look(behind + side * 1.5 + Vector3.UP * 1.3, presser.figure.eye() * 0.4 + presser.figure.fingertip() * 0.6, 85.0)
	await shot("c1_eye_peering_down")
	await wait(10.0, func() -> bool: return presser.figure.press_stage() == Colossus.Press.DESCEND and presser.figure._press_t > presser.figure.descend_time * 0.55)
	var tip := presser.figure.fingertip()
	look(behind - side * 1.5 + Vector3.UP * 1.4, Vector3(tip.x, tip.y * 0.6, tip.z), 80.0)
	await shot("c2_fingertip_coming_down")
	# He runs for the foot of the wall: the finger presses where he was.
	var safe := Vector3.INF
	for r in range(2, 40):
		for k in 16:
			var p := target + Vector3(cos(TAU * k / 16.0), 0.0, sin(TAU * k / 16.0)) * r * 0.5
			if presser.clear_of_walls(p, 0.35) and not presser.clear_of_walls(p, 0.9):
				safe = p
				break
		if safe.is_finite():
			break
	if safe.is_finite():
		world.put_player(safe + Vector3.UP * 0.05, atan2(side.x, side.z))
	await wait(8.0, func() -> bool: return presser.figure.press_stage() == Colossus.Press.PRESS)
	var under := presser.figure.fingertip()
	under.y = 0.0
	look(behind + side * 2.0 + Vector3.UP * 1.6, under + Vector3.UP * 7.0, 80.0)
	await shot("c3_finger_pressing_he_got_away")
	print("  he is %.1f m from the fingertip (caught: %s)" % [Vector2(boy.global_position.x - under.x, boy.global_position.z - under.z).length(), not presser._spared.is_empty()])
	boy.remove_from_group(&"maze_players")
	presser.queue_free()
	hunter = null


func _from_the_clearing() -> void:
	# In the first hall beyond the great wall, near the middle of a side.
	var wall_cell := Vector2i(-1, -1)
	var best := INF
	for c: Vector2i in MazeNav.new(maze).lairs(1):
		if maze.ring_of(c) == 1 and maze.depth_in_ring(c) == maze.rampart(1) + 1:
			var at := maze.world(c)
			var across_side := minf(absf(at.x), absf(at.z))
			if across_side > 60.0 and across_side < best:
				best = across_side
				wall_cell = c
	if wall_cell.x < 0:
		return
	var spot := maze.world(wall_cell)
	var out := spot.normalized()
	var square := Vector3(signf(out.x), 0, 0) if absf(out.x) > absf(out.z) else Vector3(0, 0, signf(out.z))
	var giant := await _spawn_at(spot + square * 30.0, atan2(-square.x, -square.z))
	giant.sense_range = 0.0
	giant._pause = 1e9
	await wait(1.0)
	print("  peering: %s" % giant._start_peering())
	await wait(10.0)
	var standing := Vector3(spot.x, 0.0, spot.z) - square * spot.dot(square)
	world.put_player(standing + Vector3.UP * (maze.ground_height(standing) + 0.1), atan2(square.x, square.z))
	await wait(1.0)
	var eyes := standing - square * 5.0 + Vector3(square.z, 0, square.x) * 2.0
	eyes.y = maze.ground_height(eyes) + 1.6
	look(eyes, Vector3(spot.x, 95.0, spot.z), 45.0)
	await shot("d1_from_the_clearing")
	look(spot - square * 200.0 + Vector3.UP * 100.0 + Vector3(square.z, 0, square.x) * 150.0, giant.figure.pelvis() + Vector3.UP * 30.0, 50.0)
	await shot("d2_over_the_great_wall")
