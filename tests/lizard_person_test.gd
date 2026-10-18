extends SceneTree
## The lizard people (MazeLizardPerson driving LizardPerson), headless, in a
## real maze (MazeBuilder in a bare scene):
##
## - put in a hall, one goes up the nearest wall at once and waits there, head
##   down, flat to the face (its hands on it);
## - a puppet fed its `state_bytes` is on the same wall;
## - the boy stands under it: it hisses first, then leaps down on him (`caught`);
## - someone running past under it: it leaps where they were, and misses;
## - with nobody about, it goes back up a wall;
## - it stalks: someone along the hall beyond a leap, it skitters along its wall
##   towards them;
## - climbing does not save you: someone up a wall's face is gone after up it;
## - on the ground by day a run is caught and a sprint gets away; at night (cold)
##   a run gets away too;
## - cold, it stays on its wall for someone across the hall, and still leaps on
##   someone right under it;
## - a band alerts its own: one noticing someone sets the others after them.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/lizard_person_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy
var failures := 0
var trace := OS.get_cmdline_user_args().has("trace")


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("LIZARD", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	# (far off to start with: in the clearing, where nothing hunts)
	boy.position = Vector3(0.0, 0.1, 0.0)
	_run.call_deferred()


## A lizard person, warm unless said, put in `cell` (`offset` from its middle).
func lizard(cell: Vector2i, warm := 1.0, offset := Vector3.ZERO) -> MazeLizardPerson:
	var one := MazeLizardPerson.new()
	one.maze = maze
	one.seed_choices(7)
	one.warmth_override = warm
	one.position = maze.world(cell) + offset + Vector3.UP * 0.05
	stage.add_child(one)
	return one


## How far its fingertips are from the face of its wall (the worse hand).
func hands_off_wall(one: MazeLizardPerson) -> float:
	var worst := 0.0
	var points := one.look.grabbers()
	for i in 2:
		worst = maxf(worst, absf((points[i] - one.global_position).dot(one.wall)))
	return worst


func _run() -> void:
	await wait(0.2)
	var hall := _hall()
	var cell: Vector2i = hall[0]
	var along: Vector3 = hall[1]
	var one := lizard(cell)
	var caught: Array = []
	one.caught.connect(func(who: Node3D) -> void: caught.append(who))

	# Up a wall, head down, flat to it.
	await wait(1.0)
	var ground := maze.ground_height(one.global_position)
	check("goes up a wall at once", one.mode == MazeLizardPerson.Mode.CLING and one.wall != Vector3.ZERO,
		"(mode %d, wall %s)" % [one.mode, one.wall.snappedf(0.01)])
	check("waits high", one.global_position.y - ground > MazeLizardPerson.CLING_HIGH - 0.5, "(%.1f m up)" % (one.global_position.y - ground))
	# (the boy comes near, so that it is posed: across the hall and along it, out of its sight line? no: in it, but far)
	boy.global_position = one.wall_foot + along * 40.0 + Vector3.UP * 0.1
	if not maze.inside(maze.cell_at(boy.global_position)) or not nav.allowed(maze.cell_at(boy.global_position)):
		boy.global_position = Vector3(0.0, 0.1, 0.0)
	one.pose_range = 2000.0
	await wait(0.8)
	check("it lies on the face of the wall", one.look.surface.dot(one.wall) > 0.99)
	check("head down", one.look.heading.dot(Vector3.DOWN) > 0.9, "(%s)" % one.look.heading.snappedf(0.01))
	check("its hands are on the wall", hands_off_wall(one) < 0.25, "(%.2f m off it)" % hands_off_wall(one))

	# The puppet, fed its news ten times a second from here on.
	var copy := MazeLizardPerson.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = one.position
	stage.add_child(copy)
	var feed := func() -> void:
		copy.from_bytes(one.state_bytes())
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(feed)
	stage.add_child(timer)
	timer.start()
	await wait(0.5)
	check("the puppet is on the wall too", copy.mode == MazeLizardPerson.Mode.CLING and copy.wall.dot(one.wall) > 0.99 and copy.global_position.distance_to(one.global_position) < 1.0)

	# The boy stands under it: the warning, then the leap.
	boy.global_position = one.wall_foot + one.wall * 1.5 + Vector3.UP * 0.1
	var seen := {"hissed": false, "leapt": false, "puppet_hissed": false, "puppet_air": false}
	var got := await wait(6.0, func() -> bool:
		seen["hissed"] = seen["hissed"] or (one.look.hissing() and one.mode == MazeLizardPerson.Mode.HISS)
		seen["leapt"] = seen["leapt"] or one.mode == MazeLizardPerson.Mode.POUNCE
		seen["puppet_hissed"] = seen["puppet_hissed"] or copy.look.hissing()
		seen["puppet_air"] = seen["puppet_air"] or copy.look.airborne
		return not caught.is_empty())
	check("hisses before it leaps", seen["hissed"])
	check("leaps down on him and catches him", got and caught.has(boy) and seen["leapt"], "(mode %d)" % one.mode)
	check("the puppet hisses and leaps too", seen["puppet_hissed"] and seen["puppet_air"])

	# He goes away (to the clearing): back up a wall.
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	var back := await wait(40.0, func() -> bool: return one.mode == MazeLizardPerson.Mode.CLING and one.wall != Vector3.ZERO)
	check("goes back up a wall with nobody about", back, "(mode %d)" % one.mode)
	await wait(0.5)
	check("the puppet is back up too", copy.mode == MazeLizardPerson.Mode.CLING and copy.global_position.distance_to(one.global_position) < 1.0)
	timer.stop()
	copy.queue_free()

	# Someone running past under it: it leaps where they were, and misses.
	var side := Vector3.UP.cross(one.wall).normalized()
	var runs := Vector2(_face_run(one.global_position, one.wall, side), _face_run(one.global_position, one.wall, -side))
	var way := side if runs.x >= runs.y else -side
	var reach := minf(maxf(runs.x, runs.y) - 1.0, 13.0)
	var runner := Node3D.new()
	stage.add_child(runner)
	one.targets = [runner]
	runner.global_position = one.wall_foot + one.wall * 1.0 - way * 6.0
	runner.global_position.y = maze.ground_height(runner.global_position)
	caught.clear()
	var missed := {"leapt": false, "landed_empty": false}
	await wait(6.0, func() -> bool:
		runner.global_position += way * 4.4 / 60.0
		if one.mode == MazeLizardPerson.Mode.POUNCE:
			missed["leapt"] = true
		elif missed["leapt"] and not missed["landed_empty"]:
			missed["landed_empty"] = caught.is_empty()
			return true
		return false)
	check("leaps at someone running past under it, and misses", missed["leapt"] and missed["landed_empty"])
	runner.global_position = Vector3(0.0, 0.1, 0.0)
	one._spared.erase(runner)
	await wait(40.0, func() -> bool: return one.mode == MazeLizardPerson.Mode.CLING and one.wall != Vector3.ZERO)

	# It stalks: a stand-in along the hall beyond a leap, on the ground, beside the
	# same wall (the way its face goes on furthest); it comes along its wall.
	side = Vector3.UP.cross(one.wall).normalized()
	runs = Vector2(_face_run(one.global_position, one.wall, side), _face_run(one.global_position, one.wall, -side))
	way = side if runs.x >= runs.y else -side
	reach = minf(maxf(runs.x, runs.y) - 1.0, 13.0)
	runner.global_position = one.wall_foot + one.wall * 2.5 + way * reach
	runner.global_position.y = maze.ground_height(runner.global_position)
	one.targets = [runner]
	var start := Vector2(one.global_position.x - runner.global_position.x, one.global_position.z - runner.global_position.z).length()
	var stalked := await wait(4.0, func() -> bool:
		if trace and Engine.get_physics_frames() % 10 == 0:
			print("  stalk: mode %d at %s wall %s stopped %s" % [one.mode, one.global_position.snappedf(0.1), one.wall.snappedf(0.1), one._stopped])
		return one.mode == MazeLizardPerson.Mode.CRAWL and one.wall != Vector3.ZERO \
			and Vector2(one.global_position.x - runner.global_position.x, one.global_position.z - runner.global_position.z).length() < start - 2.5)
	check("stalks along its wall towards someone beyond a leap", stalked and reach > MazeLizardPerson.POUNCE_RANGE,
		"(mode %d, %.1f m from %.1f)" % [one.mode, Vector2(one.global_position.x - runner.global_position.x, one.global_position.z - runner.global_position.z).length(), start])
	caught.clear()
	got = await wait(8.0, func() -> bool: return not caught.is_empty())
	check("and gets them in the end, standing there", got)

	# Climbing does not save you: a stand-in up a wall's face, the lizard on the ground near.
	runner.global_position = Vector3(0.0, 0.1, 0.0)
	await wait(0.2)
	var face_at := one.wall_foot + way * 6.0
	var climber := Node3D.new()
	stage.add_child(climber)
	climber.global_position = Vector3(face_at.x, maze.ground_height(face_at), face_at.z) - one.wall * 0.3 + Vector3.UP * 4.0
	one.targets = [climber]
	one._spared.clear()
	one.global_position = face_at + one.wall * 4.0 + Vector3.UP * 0.1
	one.wall = Vector3.ZERO
	one._enter(MazeLizardPerson.Mode.HUNT)
	one.notice(climber)
	one.look.surface = Vector3.UP
	one.look.settle()
	caught.clear()
	var climbed := {"up": false}
	got = await wait(10.0, func() -> bool:
		climbed["up"] = climbed["up"] or (one.wall != Vector3.ZERO and one.global_position.y > maze.ground_height(one.global_position) + 1.5)
		if trace and Engine.get_physics_frames() % 30 == 0:
			print("  climb: mode %d at %s wall %s" % [one.mode, one.global_position.snappedf(0.1), one.wall.snappedf(0.1)])
		return not caught.is_empty())
	check("goes up the wall after someone up it, and has them", got and climbed["up"], "(climbed %s, mode %d)" % [climbed["up"], one.mode])
	one._spared.erase(climber)
	climber.queue_free()

	# Day and night, on the ground: a stand-in moved by hand down the longest straight,
	# from the lizard on the ground behind it.
	for run: Array in [[5.6, 1.0, false], [4.4, 1.0, true], [4.4, 0.12, false], [1.6, 0.12, true]]:
		var pace: float = run[0]
		var warm: float = run[1]
		var expect_caught: bool = run[2]
		var straight := _straight()
		var a: Vector2i = straight[0]
		var b: Vector2i = straight[1]
		var dir := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
		runner.global_position = maze.world(a) + dir * 7.0
		one.warmth_override = warm
		one._warm_up()
		one.targets = [runner]
		one._spared.clear()
		one.global_position = maze.world(a) + Vector3.UP * 0.1
		one.wall = Vector3.ZERO
		one.velocity = Vector3.ZERO
		one._heading = dir
		one._warned = 99.0
		one._enter(MazeLizardPerson.Mode.HUNT)
		one._mode_time = 1.0
		one.notice(runner)
		one.look.surface = Vector3.UP
		one.look.settle()
		caught.clear()
		var begin := one.global_position.distance_to(runner.global_position)
		var end := maze.world(b)
		var gap := [0.0]
		await wait(12.0, func() -> bool:
			runner.global_position = runner.global_position.move_toward(end, pace / 60.0)
			gap[0] = one.global_position.distance_to(runner.global_position)
			if trace and Engine.get_physics_frames() % 20 == 0:
				print("  pace %.1f warm %.2f mode %d gap %.1f" % [pace, warm, one.mode, gap[0]])
			return not caught.is_empty() or runner.global_position.distance_to(end) < 0.1)
		var what := "%s %s" % ["by day" if warm > 0.5 else "at night", "a sprint" if pace > 5.0 else ("a run" if pace > 4.0 else "a walk")]
		if expect_caught:
			check("%s is caught" % what, not caught.is_empty(), "(%.1f m apart at the end, from %.1f)" % [gap[0], begin])
		else:
			check("%s gets away" % what, caught.is_empty() and gap[0] > begin, "(%.1f m apart, from %.1f)" % [gap[0], begin])
		one._spared.erase(runner)

	# Cold, on its wall: someone across the hall is let be; someone under it is not.
	one.targets = [runner]
	runner.global_position = Vector3(0.0, 0.1, 0.0)
	one.quarry = null
	one._forget = 0.0
	one._last_seen = Vector3.INF
	one.warmth_override = 0.12
	one._warm_up()
	one._go_up_nearest_wall(true)
	await wait(0.5)
	var foot := one.wall_foot
	runner.global_position = foot + one.wall * 6.5 + side * 4.0
	runner.global_position.y = maze.ground_height(runner.global_position)
	caught.clear()
	var came_down := await wait(5.0, func() -> bool: return one.wall == Vector3.ZERO)
	check("cold, it stays on its wall for someone across the hall", not came_down and caught.is_empty(), "(mode %d)" % one.mode)
	runner.global_position = foot + one.wall * 0.8
	runner.global_position.y = maze.ground_height(runner.global_position)
	got = await wait(6.0, func() -> bool: return not caught.is_empty())
	check("cold, it still leaps on someone right under it", got)

	# A band: one notices, the others take up the hunt.
	one.queue_free()
	var mates: Array[MazeLizardPerson] = []
	for k in 3:
		var mate := lizard(cell, 1.0, along * (k - 1) * 3.0)
		mate.targets = [runner]
		mates.append(mate)
	runner.global_position = Vector3(0.0, 0.1, 0.0)
	await wait(1.0)
	mates[0].notice(runner)
	await wait(0.2)
	check("a band takes up the hunt together", mates[1].quarry == runner and mates[2].quarry == runner)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)


## A cell in a straight hall well out in the ring (open along it, walls both
## sides), and the way along it.
func _hall() -> Array:
	var lairs := nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 2 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
				return [cell, Vector3(s.x, 0.0, s.y)]
	return [lairs[lairs.size() / 2], Vector3(1, 0, 0)]


## The ends of the longest straight run of open cells (outside the clearing).
func _straight() -> Array:
	var best: Array = [Vector2i.ZERO, Vector2i.ZERO]
	var best_length := 0
	for y in maze.size:
		for x in maze.size:
			var cell := Vector2i(x, y)
			if maze.in_clearing(cell) or not nav.allowed(cell):
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var end := cell
				while maze.inside(end + step) and not maze.blocked(end, step) and nav.allowed(end + step):
					end += step
				var length := (end - cell).length()
				if length > best_length:
					best_length = int(length)
					best = [cell, end]
	return best


## How far the face of a wall (its `normal`) goes on from `from` along `dir`, at that height.
func _face_run(from: Vector3, normal: Vector3, dir: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	var d := 0.0
	while d < 30.0:
		var at := from + dir * (d + 0.5)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + normal * 0.6, at - normal * 0.6, 1))
		if hit.is_empty():
			break
		d += 0.5
	return d
