extends SceneTree
## The runners (MazeRunner), alone: each built ring has as many as its style
## says, in shirts of their own, and hunted like players; one jogs a route about
## his section; one climbs some ivy and comes down; one waves a mummy off the boy
## and onto himself; one sees the Griever coming, sprints off, and is caught when held
## still, struck down and put back in the clearing, and goes home; one greets the
## boy, beckons and leads him to his section's gate, waiting when he falls behind.
## And their news makes a puppet copy follow them.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/runner_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("RUNR", 1))
	await frames(20)
	var world = main.world
	var maze: Maze = world.maze
	var player = world.player
	# (nothing else hunts, so that what happens is what is tried; the Griever waits)
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(2)

	var expected := 0
	for ring in range(1, maze.rings + 1):
		expected += maze.styles[ring - 1].runners
	var runners: Array = world.runners.runners
	check("runners as the styles say", runners.size() == expected and expected > 0, "(%d of %d)" % [runners.size(), expected])
	var own_section := true
	var shirts_apart := true
	for runner: MazeRunner in runners:
		own_section = own_section and maze.ring_of(maze.cell_at(runner.global_position)) == runner.ring
		var shirt: Color = (runner.get_node("Rig") as CharacterRig).look["colours"]["shirt"]
		for seat_shirt: Color in Looks.SHIRTS:
			if Vector3(shirt.r - seat_shirt.r, shirt.g - seat_shirt.g, shirt.b - seat_shirt.b).length() < 0.12:
				shirts_apart = false
	check("each in his own section", own_section)
	check("shirts unlike the players'", shirts_apart)
	check("hunted like players", runners[0].is_in_group(&"maze_players") and runners[0].is_in_group(&"runners"))
	check("the same boy (a Player, on a GestureRig)", runners[0] is Player and runners[0].get_node("Rig") is GestureRig)

	# A route: he jogs from place to place in his section.
	var jogger: MazeRunner = runners[0]
	var start := jogger.global_position
	var furthest := 0.0
	var cells := {}
	var left_section := false
	for i in 60 * 12:
		await physics_frame
		furthest = maxf(furthest, jogger.global_position.distance_to(start))
		cells[maze.cell_at(jogger.global_position)] = true
		if maze.ring_of(maze.cell_at(jogger.global_position)) != jogger.ring:
			left_section = true
	check("jogs a route", furthest > 18.0 and cells.size() >= 3, "(%.0f m out, %d cells, mode %s)" % [furthest, cells.size(), MazeRunner.Mode.keys()[jogger.mode]])
	check("and keeps to his section", not left_section)
	var pace := Vector2(jogger.velocity.x, jogger.velocity.z).length()
	check("at a jog", jogger.mode != MazeRunner.Mode.JOG or (pace > 1.8 and pace < 4.5) or jogger.stuck_time > 0.0, "(%.1f m/s)" % pace)

	# A way up: sent up some ivy, he takes hold and climbs, looks about, and comes down.
	var climber: MazeRunner = runners[runners.size() - 1]
	var ivy: IvyClimb = null
	for one: IvyClimb in world.maze_features().climbs:
		climber.ring = clampi(maze.ring_of(maze.cell_at(MazeRunner._ivy_foot(one))), 1, maze.rings)
		if one.bottom_y() < 0.3 and climber._ivy_clear(one):
			ivy = one
			break
	check("ivy he can climb", ivy != null)
	if ivy:
		climber.global_position = MazeRunner._ivy_foot(ivy) + ivy.global_basis.z * 2.0
		climber.velocity = Vector3.ZERO
		climber._reset_visuals()
		climber._go_up(ivy, false)
		climber._ivy_high = 4.0
		var highest := 0.0
		var held_on := false
		for i in 60 * 20:
			await physics_frame
			highest = maxf(highest, climber.global_position.y)
			held_on = held_on or climber.state == Player.State.LADDER
			if highest > 3.5 and climber.mode != MazeRunner.Mode.CLIMB:
				break
		check("he climbs some ivy", held_on and highest > 3.5, "(up to %.1f m)" % highest)
		check("and comes down again", climber.mode != MazeRunner.Mode.CLIMB and climber.global_position.y < 0.5, "(mode %s, at %.1f m)" % [MazeRunner.Mode.keys()[climber.mode], climber.global_position.y])

	# Hunted: the Griever comes for him; he runs; held still, he is caught.
	var hunted: MazeRunner = runners[1] if runners.size() > 1 else runners[0]
	var cell := maze.cell_at(hunted.global_position)
	var open := Vector3.FORWARD
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			open = Vector3(step.x, 0.0, step.y)
			break
	var griever = world.griever
	griever.process_mode = Node.PROCESS_MODE_INHERIT
	griever.visible = true
	var near := maze.world(cell) + open * 8.0
	hunted.global_position = maze.world(cell) + Vector3.UP * 0.05
	hunted.velocity = Vector3.ZERO
	hunted._reset_visuals()
	griever.place(near, atan2(-open.x, -open.z))
	var fled := false
	var top_speed := 0.0
	for i in 60 * 6:
		await physics_frame
		if hunted.mode == MazeRunner.Mode.FLEE or hunted.mode == MazeRunner.Mode.CLIMB:
			fled = true
		top_speed = maxf(top_speed, Vector2(hunted.velocity.x, hunted.velocity.z).length())
		if fled and top_speed > 5.0:
			break
	check("hunted, he runs", fled, "(mode %s)" % MazeRunner.Mode.keys()[hunted.mode])
	check("at a sprint", top_speed > 5.0, "(%.1f m/s)" % top_speed)
	var was_taken := [false]
	hunted.taken.connect(func() -> void: was_taken[0] = true)
	# (held where he is, the Griever brought to him)
	hunted.hold(30.0)
	if hunted.state == Player.State.LADDER:
		hunted._leave_ladder()
	griever.place(hunted.global_position + open * 3.0, atan2(-open.x, -open.z))
	for i in 60 * 15:
		await physics_frame
		if was_taken[0]:
			break
	check("a hunter catches him", was_taken[0])
	check("he is struck down", hunted.is_limp and hunted.mode == MazeRunner.Mode.TAKEN)
	hunted._held = 0.0
	griever.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(int(60 * (MazeRunner.DOWN_TIME + 0.6)))
	check("and put back in the clearing", maze.in_clearing(maze.cell_at(hunted.global_position)) and not hunted.is_limp, str(hunted.global_position))
	await frames(int(60 * (MazeRunner.SIT_TIME + 2.0)))
	check("then goes home to his section", hunted.mode == MazeRunner.Mode.HOME or hunted.mode == MazeRunner.Mode.JOG, MazeRunner.Mode.keys()[hunted.mode])

	# Leading: a runner a few cells from his section's gate, the boy comes up to him.
	var leader: MazeRunner = jogger
	var gate: Array = leader._gate()
	var nav := MazeNav.new(maze, false)
	var from: Vector2i = gate[0]
	for i in maze.size * maze.size:
		var c := Vector2i(i % maze.size, i / maze.size)
		var d := nav.distance(c, gate[0])
		if maze.ring_of(c) == leader.ring and d >= 5 and d <= 6:
			from = c
			break
	leader.halt()
	leader.global_position = maze.world(from) + Vector3.UP * 0.05
	leader.velocity = Vector3.ZERO
	leader._reset_visuals()
	leader._lead_rest = 0.0
	leader._set_mode(MazeRunner.Mode.JOG)
	var toward := nav.next_cell(from, gate[0])
	var aside := Vector3(toward.x - from.x, 0.0, toward.y - from.y)
	world.put_player(maze.world(from) - aside * 3.5 + Vector3.UP * 0.05, atan2(aside.x, aside.z))
	var greeted := false
	var beckoned := false
	for i in 60 * 3:
		await physics_frame
		if leader.mode == MazeRunner.Mode.GREET:
			greeted = true
			beckoned = beckoned or leader.gesturing() == GestureRig.Gesture.BECKON
		if leader.mode == MazeRunner.Mode.LEAD:
			break
	check("he greets the boy, beckoning", greeted and beckoned, "(mode %s)" % MazeRunner.Mode.keys()[leader.mode])
	check("and leads", leader.mode == MazeRunner.Mode.LEAD)
	# The boy follows (kept a few metres behind him), but stops a while partway.
	var waited := false
	var at_gate := false
	var steps_before := nav.distance(maze.cell_at(leader.global_position), gate[0])
	var phase := 0
	var phase_time := 0.0
	for i in 60 * 45:
		await physics_frame
		phase_time += 1.0 / 60.0
		if phase == 0 and phase_time > 2.0:
			phase = 1
			phase_time = 0.0
		elif phase == 1 and (leader.mode == MazeRunner.Mode.WAIT or phase_time > 10.0):
			waited = leader.mode == MazeRunner.Mode.WAIT
			phase = 2
		if phase != 1:
			_tag_along(player, leader)
		if leader.mode == MazeRunner.Mode.AT_GATE:
			at_gate = true
			break
	check("left behind, he waits for him", waited)
	check("he leads him to the gate", at_gate, "(from %d steps, now %d, mode %s)" % [steps_before, nav.distance(maze.cell_at(leader.global_position), gate[0]), MazeRunner.Mode.keys()[leader.mode]])
	await frames(90)
	check("and points through it", leader.gesturing() == GestureRig.Gesture.POINT)

	# Drawing a hunter off: a mummy after the boy down a hall, a runner further
	# back sees it, waves it over, and it takes after him instead.
	var drawer: MazeRunner = runners[runners.size() - 1]
	var hall := _straight_run(maze, 4)
	var start_cell: Vector2i = hall[0]
	var along: Vector2i = hall[1]
	var down := Vector3(along.x, 0.0, along.y)
	var boy_at: Vector3 = drawer._middle_of(start_cell + along)
	world.put_player(boy_at + Vector3.UP * 0.05, atan2(-down.x, -down.z))
	drawer.ring = 1
	drawer.global_position = boy_at - down * 10.0 + Vector3.UP * 0.05
	drawer.velocity = Vector3.ZERO
	drawer._reset_visuals()
	drawer._draw_rest = 0.0
	drawer._lead_rest = 100.0
	drawer.threat = null
	drawer._set_mode(MazeRunner.Mode.JOG)
	var mummy := Mummy.new()
	world.enemies.add(mummy, maze.cell_at(boy_at + down * 14.0), atan2(-down.x, -down.z), 7, boy_at + down * 14.0 - maze.world(maze.cell_at(boy_at + down * 14.0)))
	await frames(2)
	mummy.notice(player)
	var drew := false
	var turned := false
	for i in 60 * 4:
		await physics_frame
		drew = drew or drawer.mode == MazeRunner.Mode.DRAW and drawer.gesturing() == GestureRig.Gesture.WAVE
		if mummy.quarry == drawer:
			turned = true
			break
	check("a runner waves to draw a hunter off the boy", drew, "(mode %s)" % MazeRunner.Mode.keys()[drawer.mode])
	check("and it goes after him instead", turned)
	mummy.queue_free()
	world.enemies.enemies.erase(mummy)

	# A puppet copy follows the news of one jogging.
	var source: MazeRunner = runners[runners.size() - 1]
	var copy := MazeRunners.new()
	world.add_child(copy)
	copy.maze = maze
	copy.puppet = true
	var twin: MazeRunner = copy.add(source.ring, source.global_position + Vector3(2.0, 0.0, 0.0), 0.0)
	var worst := 0.0
	var moved := 0.0
	var was := source.global_position
	for i in 60 * 5:
		await physics_frame
		if i % 6 == 0:
			var news := PackedByteArray([1])
			news.append_array(source.state_bytes())
			copy.unpack(news)
		if i > 30:
			worst = maxf(worst, twin.global_position.distance_to(source.global_position))
	moved = was.distance_to(source.global_position)
	check("a puppet copy keeps up with him", worst < 2.0 and moved > 4.0, "(at worst %.2f m off; he went %.0f m)" % [worst, moved])
	check("and is not hunted itself", not twin.is_in_group(&"maze_players"))

	print("RUNNER TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


## Puts the boy a few metres behind `leader`, where he could see him, as if following.
func _tag_along(player: Player, leader: MazeRunner) -> void:
	var going := Vector3(leader.velocity.x, 0.0, leader.velocity.z)
	if going.length() < 0.5:
		going = -Vector3(sin(leader.facing_yaw), 0.0, cos(leader.facing_yaw))
	var behind := leader.global_position - going.normalized() * 4.0
	if leader.nav.sees(behind + Vector3.UP, leader.global_position + Vector3.UP) and leader.nav.clear_of_walls(behind, 0.4):
		player.global_position = Vector3(behind.x, leader.global_position.y + 0.05, behind.z)
		player.velocity = Vector3.ZERO


## A straight run of `length` cells in the first ring, well in: [first cell, step].
func _straight_run(maze: Maze, length: int) -> Array:
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
				return [cell, step]
	return [maze.cell_at(Vector3.ZERO), Vector2i(1, 0)]
