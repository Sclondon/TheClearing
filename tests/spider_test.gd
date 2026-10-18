extends SceneTree
## The giant spider (MazeSpider driving GiantSpider), headless, in a real maze
## (MazeBuilder in a bare scene):
##
## - put in a passage, it goes up the nearest high wall and waits there, head
##   down, its feet on the wall;
## - the boy comes under it: it drops on its thread, lands, comes at him, rears
##   and bites (`caught`), with its feet on the ground as it runs;
## - with nobody about, it goes back up a wall and waits again;
## - someone sprinting away down a straight gets away from it; someone running or
##   walking does not;
## - a puppet fed its `state_bytes` follows it: on the wall, hanging, running.
##
##     godot --headless --path . -s res://tests/spider_test.gd
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
	maze = Maze.generate(Maze.seed_for("SPIDER", 1))
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


## Of the feet that are down, how many are within a hand of something.
func feet_on(spider: MazeSpider) -> Vector2i:
	var space := spider.get_world_3d().direct_space_state
	var down := 0
	var on := 0
	var legs := spider.look.legs
	for i in GiantSpiderLegs.COUNT:
		if legs.stepping[i] or legs.free[i]:
			continue
		down += 1
		var foot: Vector3 = legs.feet[i]
		var normal: Vector3 = legs.normals[i]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + normal * 0.3, foot - normal * 0.3, 1))
		if not hit.is_empty() and foot.distance_to(hit["position"]) < 0.1:
			on += 1
	return Vector2i(on, down)


func _run() -> void:
	await wait(0.2)
	# A passage cell well out in the ring.
	var lairs := nav.lairs(4)
	var cell: Vector2i = lairs[lairs.size() / 2]
	var spider := MazeSpider.new()
	spider.maze = maze
	spider.seed_choices(7)
	spider.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(spider)
	var caught: Array = []
	spider.caught.connect(func(who: Node3D) -> void: caught.append(who))

	# Up a wall.
	await wait(1.0)
	check("goes up a wall at once", spider.mode == MazeSpider.Mode.PERCH and spider.wall != Vector3.ZERO,
		"(mode %d, wall %s, at %s)" % [spider.mode, spider.wall, spider.global_position.snappedf(0.1)])
	check("waits high", spider.global_position.y > MazeSpider.PERCH_HIGH - 0.5, "(%.1f m up)" % spider.global_position.y)
	# (the boy comes near, so that it is posed)
	boy.global_position = spider.wall_foot + spider.wall * 30.0 + Vector3.UP * 0.1
	if not maze.inside(maze.cell_at(boy.global_position)) or not nav.allowed(maze.cell_at(boy.global_position)):
		boy.global_position = spider.wall_foot + spider.wall * 18.0 + Vector3.UP * 0.1
	await wait(1.5)
	var feet := feet_on(spider)
	check("its feet are on the wall", feet.x >= 6 and feet.x == feet.y, "(%d of %d down feet on something)" % [feet.x, feet.y])
	check("it faces down the wall", spider.look.body.basis.z.dot(Vector3.UP) > 0.7, "(%s)" % spider.look.body.basis.z.snappedf(0.01))

	# The puppet, fed its news ten times a second from here on.
	var copy := MazeSpider.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = spider.position
	stage.add_child(copy)
	var feed := func() -> void:
		copy.from_bytes(spider.state_bytes())
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(feed)
	stage.add_child(timer)
	timer.start()
	await wait(0.5)
	check("the puppet is on the wall too", copy.mode == MazeSpider.Mode.PERCH and copy.wall == spider.wall and copy.global_position.distance_to(spider.global_position) < 1.0)

	# The boy walks in under it.
	var under := spider.wall_foot + spider.wall * 4.0 + Vector3.UP * 0.1
	boy.global_position = under
	var dropped := await wait(4.0, func() -> bool: return spider.mode == MazeSpider.Mode.DROP)
	check("drops when he comes under it", dropped)
	await wait(0.6)
	check("hangs on its thread", spider.look.hanging and spider.look.anchor.is_finite())
	check("the puppet hangs too", copy.look.hanging and copy.look.anchor.is_finite())
	var landed := await wait(3.0, func() -> bool: return spider.mode == MazeSpider.Mode.HUNT)
	check("lands and hunts", landed and spider.is_on_floor() or spider.global_position.y < 1.0, "(%.2f m up)" % spider.global_position.y)
	# Running at him: feet on the ground.
	var seen := {"feet": Vector2i.ZERO, "reared": false}

	var got := await wait(12.0, func() -> bool:
		if spider.mode == MazeSpider.Mode.HUNT and Engine.get_physics_frames() % 6 == 0:
			seen["feet"] += feet_on(spider)
		seen["reared"] = seen["reared"] or spider.look.stage() == GiantSpider.Stage.REAR
		if trace and Engine.get_physics_frames() % 30 == 0:
			print("  mode %d at %s boy %.1f m" % [spider.mode, spider.global_position.snappedf(0.1), spider.global_position.distance_to(boy.global_position)])
		return not caught.is_empty())
	check("rears before it bites", seen["reared"])
	var tally: Vector2i = seen["feet"]
	check("bites him", got and caught.has(boy))
	check("its running feet are on the ground", tally.y > 0 and tally.x >= tally.y * 0.9, "(%d of %d)" % [tally.x, tally.y])
	check("the puppet keeps up", copy.global_position.distance_to(spider.global_position) < 3.0, "(%.1f m apart)" % copy.global_position.distance_to(spider.global_position))

	# He goes away (to the clearing): back up a wall.
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	var back := await wait(40.0, func() -> bool: return spider.mode == MazeSpider.Mode.PERCH)
	check("goes back up a wall with nobody about", back, "(mode %d)" % spider.mode)
	await wait(0.5)
	check("the puppet is back up too", copy.mode == MazeSpider.Mode.PERCH and copy.global_position.distance_to(spider.global_position) < 1.0)
	timer.stop()
	copy.queue_free()

	# Sprinting gets away; walking does not. (A stand-in moved by hand down the
	# longest straight, from the spider freshly landed at one end of it.)
	for pace: float in [5.6, 4.4, 3.0]:
		var run := _straight()
		var a: Vector2i = run[0]
		var b: Vector2i = run[1]
		var along := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
		var runner := Node3D.new()
		stage.add_child(runner)
		runner.global_position = maze.world(a) + along * 8.0
		boy.global_position = Vector3(0.0, 0.1, 0.0)
		spider.targets = [runner]
		spider.global_position = maze.world(a) + Vector3.UP * 0.1
		spider.wall = Vector3.ZERO
		spider._anchor = Vector3.INF
		spider._enter(MazeSpider.Mode.HUNT)
		spider.notice(runner)
		spider.look.settle()
		caught.clear()
		var start := spider.global_position.distance_to(runner.global_position)
		var end := maze.world(b)
		var gap := [0.0]
		await wait(7.0, func() -> bool:
			runner.global_position = runner.global_position.move_toward(end, pace / 60.0)
			if trace and Engine.get_physics_frames() % 20 == 0:
				print("  pace %.1f mode %d stage %d gap %.1f quarry %s floor %s" % [pace, spider.mode, spider.look.stage(), spider.global_position.distance_to(runner.global_position), spider.quarry == runner, spider.is_on_floor()])
			gap[0] = spider.global_position.distance_to(runner.global_position)
			return not caught.is_empty())
		if pace > 5.0:
			check("a sprint gets away", caught.is_empty() and gap[0] > start, "(%.1f m apart, from %.1f)" % [gap[0], start])
		else:
			check("a %s is caught" % ("run" if pace > 4.0 else "walk"), not caught.is_empty(), "(%.1f m apart at the end)" % gap[0])
		spider.targets = [boy]
		spider.quarry = null
		# (MazeEnemy._sense types the keys of _spared, so a freed one there is an error)
		spider._spared.erase(runner)
		runner.queue_free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)


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
