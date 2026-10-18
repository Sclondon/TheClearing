extends SceneTree
## Pictures of the runners (MazeRunner), landscape: one jogging a hall ahead of
## the boy, seen from behind him; one sprinting at the camera from the Griever;
## one beckoning the boy on, and again; one waving to draw a hunter; one pointing
## through his section's gate; one up the ivy. A camera of its own is put where
## each picture wants it. Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/runner_shots.gd -- <folder>

var main: Node
var folder := "runner_shots"
var world
var maze: Maze
var eye: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


## A straight run of `length` cells in the first ring: [first cell, step].
func straight_run(length: int, skip := 0) -> Array:
	var found := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or maze.depth_in_ring(cell) < 3:
			continue
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in length:
				var at := cell + step * k
				if maze.ring_of(at) != 1 or maze.blocked(at, step) or maze.entrances.has(at):
					ok = false
					break
			if ok:
				if found == skip:
					return [cell, step]
				found += 1
	return [maze.cell_at(Vector3.ZERO), Vector2i(1, 0)]


## The shot's camera at `from`, looking at `at`.
func frame(from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	eye.make_current()
	# (the runners see where it is now at once, and are posed if near it)
	for runner: MazeRunner in world.runners.runners:
		runner._far_check = 0.0


func put(runner: MazeRunner, at: Vector3, yaw: float) -> void:
	runner.halt()
	# (his section is where he is put)
	runner.ring = clampi(maze.ring_of(maze.cell_at(at)), 1, maze.rings)
	runner.global_position = Vector3(at.x, 0.05, at.z)
	runner.velocity = Vector3.ZERO
	runner.facing_yaw = yaw
	runner._reset_visuals()


func _run() -> void:
	await wait(0.5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("RUNS", 2))
	world = main.world
	maze = world.maze
	eye = Camera3D.new()
	eye.fov = 62.0
	world.add_child(eye)
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	var griever = world.griever
	griever.process_mode = Node.PROCESS_MODE_DISABLED
	griever.visible = false
	var runner: MazeRunner = world.runners.runners[0]
	runner._lead_rest = 1000.0
	runner._draw_rest = 1000.0
	runner._climb_rest = 1000.0
	await wait(0.5)

	# 1. Jogging a hall ahead of the boy, from behind him.
	var run := straight_run(5)
	var cell: Vector2i = run[0]
	var step: Vector2i = run[1]
	var way := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var start: Vector3 = runner._middle_of(cell)
	put(runner, start + way * 4.0, atan2(way.x, way.z))
	runner._goal_cell = cell + step * 5
	runner.goal = runner._middle_of(cell + step * 5)
	runner._set_mode(MazeRunner.Mode.JOG)
	world.put_player(start + side * 1.5, atan2(way.x, way.z))
	for i in 80:
		# (the boy jogs after him, a little to one side)
		var behind: Vector3 = runner.global_position - way * 6.5 + side * 1.6
		world.player.global_position = Vector3(behind.x, world.player.global_position.y, behind.z)
		world.player.velocity = way * 3.0
		await physics_frame
	var boy: Vector3 = world.player.global_position
	frame(boy - way * 3.4 - side * 1.3 + Vector3.UP * 1.7, (boy + runner.global_position) * 0.5 + way * 2.0 + Vector3.UP * 0.8)
	await shot("1_jogging_ahead")

	# 2. Sprinting from the Griever, straight at the camera.
	run = straight_run(6, 3)
	cell = run[0]
	step = run[1]
	way = Vector3(step.x, 0.0, step.y)
	side = Vector3(-way.z, 0.0, way.x)
	start = runner._middle_of(cell)
	world.put_player(start + way * 70.0, 0.0)
	put(runner, start + way * 9.0, atan2(way.x, way.z))
	griever.process_mode = Node.PROCESS_MODE_INHERIT
	griever.visible = true
	griever.targets = [runner]
	griever.place(start, atan2(way.x, way.z))
	runner.threat = griever
	runner._flee()
	for i in 75:
		runner._goal_cell = cell + step * 6
		runner.goal = start + way * 70.0
		await physics_frame
	var him := runner.global_position
	frame(him + way * 7.0 + side * 1.2 + Vector3.UP * 1.1, him - way * 4.0 + Vector3.UP * 1.3)
	await shot("2_sprinting_from_griever")
	griever.process_mode = Node.PROCESS_MODE_DISABLED
	griever.visible = false
	griever.targets = []
	griever.chasing = false
	griever.place(maze.world(maze.exit), 0.0)

	# 3. Beckoning: the boy comes up to him and he waves him on.
	run = straight_run(3, 6)
	cell = run[0]
	step = run[1]
	way = Vector3(step.x, 0.0, step.y)
	side = Vector3(-way.z, 0.0, way.x)
	start = runner._middle_of(cell)
	put(runner, start + way * 5.0, atan2(-way.x, -way.z))
	runner.threat = null
	runner._lead_rest = 0.0
	runner._set_mode(MazeRunner.Mode.JOG)
	world.put_player(start, atan2(way.x, way.z))
	for i in 120:
		runner.halt()
		await physics_frame
		if runner.mode == MazeRunner.Mode.GREET and runner._mode_time > 0.8:
			break
	boy = world.player.global_position
	frame(boy - way * 2.6 + side * 1.4 + Vector3.UP * 1.5, boy + way * 5.0 + Vector3.UP * 0.8)
	await shot("3_beckoning")
	runner._set_mode(MazeRunner.Mode.WAIT)
	runner.follower = world.player
	world.put_player(start - way * 5.0, atan2(way.x, way.z))
	for i in 25:
		runner._mode_time = 0.0
		await physics_frame
	frame(runner.global_position + way * -3.4 + side * 1.6 + Vector3.UP * 1.2, runner.global_position + Vector3.UP * 0.75)
	await shot("3b_beckoning_close")

	# 4. Waving both arms to draw a hunter off.
	runner._set_mode(MazeRunner.Mode.DRAW)
	runner.threat = world.player
	for i in 40:
		runner._mode_time = 0.0
		await physics_frame
	await shot("4_waving")
	runner.threat = null
	runner._set_mode(MazeRunner.Mode.JOG)
	runner._lead_rest = 1000.0

	# 5. At his section's gate, pointing through it.
	var gate: Array = runner._gate()
	var out: Vector2i = gate[1]
	var through := Vector3(out.x, 0.0, out.y)
	runner.ring = clampi(maze.ring_of(gate[0]), 1, maze.rings)
	runner._aside_spot = Vector3.INF
	put(runner, runner._aside_of_gate(), 0.0)
	runner.ring = clampi(maze.ring_of(gate[0]), 1, maze.rings)
	runner.follower = world.player
	runner._set_mode(MazeRunner.Mode.AT_GATE)
	var gate_middle := maze.world(gate[0])
	world.put_player(gate_middle - through * 6.0, atan2(through.x, through.z))
	for i in 100:
		runner._mode_time = minf(runner._mode_time, 3.0)
		await physics_frame
	him = runner.global_position
	var slot := gate_middle + through * 5.0 + Vector3.UP * 1.0
	var other_side := gate_middle - him
	other_side = (other_side - through * other_side.dot(through)).normalized()
	frame(vantage(gate_middle + Vector3.UP * 0.6, -through + other_side * 0.7, 8.0), gate_middle + through * 3.0 + Vector3.UP * 0.9)
	await wait(0.6)
	await shot("5_pointing_through_gate")

	# 6. Up the ivy.
	var ivies: Array[IvyClimb] = []
	runner.ring = 1
	for climb in world.maze_features().climbs:
		if climb.bottom_y() < 0.3 and maze.ring_of(maze.cell_at(climb.global_position)) == 1 and runner._ivy_clear(climb):
			ivies.append(climb)
	if not ivies.is_empty():
		var ivy: IvyClimb = ivies[0]
		var back := ivy.global_basis.z
		put(runner, MazeRunner._ivy_foot(ivy) + back * 0.4, atan2(ivy.facing().x, ivy.facing().z))
		runner._go_up(ivy, true)
		runner._ivy_high = 4.0
		world.put_player(MazeRunner._ivy_foot(ivy) + back * 8.0, 0.0)
		for i in 60 * 8:
			await physics_frame
			# (kept from coming down for the picture)
			runner._calm = 0.0
			if runner.state == Player.State.LADDER and runner.global_position.y > 3.8:
				break
		await wait(1.2)
		var foot := MazeRunner._ivy_foot(ivy)
		frame(vantage(foot + Vector3.UP * 2.5, back + Vector3(-back.z, 0.0, back.x) * 0.4, 6.5) + Vector3.UP * 0.3, foot + Vector3.UP * 3.4)
		await wait(0.6)
		await shot("6_up_the_ivy")
	quit()


## Somewhere for the camera `away` metres from `target`, about `towards` it
## (level), out of every wall and with nothing between: the first of a fan of
## places round that way, nearer if need be.
func vantage(target: Vector3, towards: Vector3, away: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var way := Vector3(towards.x, 0.0, towards.z).normalized()
	for reach: float in [away, away * 0.7, away * 0.45]:
		for turn: float in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6]:
			var at := target + way.rotated(Vector3.UP, turn) * reach + Vector3.UP * 0.8
			var inside := PhysicsPointQueryParameters3D.new()
			inside.position = at
			if not space.intersect_point(inside, 1).is_empty():
				continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, target, 1)).is_empty():
				return at
	return target + way * away * 0.3 + Vector3.UP * 0.8
