extends SceneTree
## The Griever, headless, in a real maze (Maze + MazeBuilder in a bare scene):
##
## - told of a noise where the boy stands, six cells off round the corners, it
##   finds its way to him, sees him, and stings him (`caught`);
## - all the while its planted feet are on something (the ground, a footing, a
##   wall) and its legs keep stepping;
## - in the open, a boy sprinting away gets away from it; one only running does not;
## - a puppet fed its `state_bytes` follows it.
##
##     godot --headless --path . -s res://tests/griever_test.gd

var failures := 0
var scene: Node3D
var maze: Maze


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	_run()


## How many cells apart two points are, round the walls.
func cells_apart(a: Vector3, b: Vector3) -> int:
	var from := maze.cell_at(a)
	var to := maze.cell_at(b)
	var seen := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == to:
			return seen[cell]
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if maze.inside(next) and not seen.has(next) and not maze.blocked(cell, step):
				seen[next] = seen[cell] + 1
				queue.push_back(next)
	return -1


## Of the feet that are down, how many are on something, and how many of those
## on a wall or a footing rather than the ground.
func feet_check(g: Griever, tally: Dictionary) -> void:
	var space := g.get_world_3d().direct_space_state
	for i in GrieverLegs.COUNT:
		if g.legs.stepping[i]:
			continue
		tally["down"] += 1
		var foot: Vector3 = g.legs.feet[i]
		var normal: Vector3 = g.legs.normals[i]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + normal * 0.3, foot - normal * 0.3, 1))
		if not hit.is_empty() and foot.distance_to(hit["position"]) < 0.08:
			tally["on"] += 1
		else:
			if tally["bad"].size() < 5:
				tally["bad"].append("%d %s n%s" % [i, foot, normal])
		if normal.y < 0.5:
			tally["wall"] += 1
		elif foot.y > 1.0:
			tally["footing"] += 1


func _run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	# (halls a cell wide, as the rings past the first have: it braces on the walls of those)
	maze = Maze.generate(Maze.seed_for("GRIEVE", 1), 1, [MazeStyle.narrows()])
	var builder := MazeBuilder.new()
	scene.add_child(builder)
	builder.build(maze)
	await frames(3)

	# The boy, somewhere along the way out, and the griever six cells further on.
	var path: Array = maze.path_out(maze.cell_at(Vector3.ZERO))
	var boy_cell: Vector2i = path[8]
	var griever_cell: Vector2i = path[14]
	var player = load("res://player.tscn").instantiate()
	player.takes_input = false
	scene.add_child(player)
	player.global_position = maze.world(boy_cell) + Vector3.UP * 0.1
	var g := Griever.new()
	scene.add_child(g)
	g.setup(maze, griever_cell)
	g.targets = [player]
	var caught_who: Array = []
	g.caught.connect(func(who: Node3D) -> void: caught_who.append(who))
	var spotted := [false]
	g.spotted.connect(func(_who: Node3D) -> void: spotted[0] = true)
	await frames(10)
	var start_apart := cells_apart(g.global_position, player.global_position)
	check("starts apart", start_apart >= 5, "(%d cells round the walls)" % start_apart)

	g.alert(player.global_position)
	var tally := {"down": 0, "on": 0, "wall": 0, "footing": 0, "bad": []}
	var closest := start_apart
	var wound := false
	var steps_before := g.legs.steps
	var time := 0.0
	var max_tilt := 0.0
	while time < 25.0 and caught_who.is_empty():
		await physics_frame
		time += 1.0 / 60.0
		if int(time * 60.0) % 6 == 0:
			feet_check(g, tally)
			closest = mini(closest, cells_apart(g.global_position, player.global_position))
		wound = wound or g.state == Griever.State.WINDUP
		max_tilt = maxf(max_tilt, g.body.basis.y.angle_to(Vector3.UP))
		if OS.has_environment("GRIEVER_TRACE") and int(time * 60.0) % 30 == 0:
			print("  %.1fs %s cell %s path %d/%d apart %d prey %s" % [time, Griever.State.keys()[g.state], maze.cell_at(g.global_position), g._path_at, g._path.size(), cells_apart(g.global_position, player.global_position), g.prey != null], " v %.2f pos %s yaw %.2f" % [g.velocity.length(), g.global_position, g.yaw])
	check("paths to him", closest <= 1, "(from %d cells to %d)" % [start_apart, closest])
	check("sees him", spotted[0])
	check("winds up before striking", wound)
	check("caught fires", caught_who.size() == 1 and caught_who[0] == player, "(after %.1f s)" % time)
	check("legs step", g.legs.steps - steps_before > 20, "(%d steps)" % (g.legs.steps - steps_before))
	var share: float = float(tally["on"]) / maxf(tally["down"], 1.0)
	check("planted feet are on something", share > 0.97, "(%d of %d; %d on walls, %d on footings) %s" % [tally["on"], tally["down"], tally["wall"], tally["footing"], tally["bad"]])
	check("braces on the walls in a passage", tally["wall"] + tally["footing"] > 0)
	check("body stays upright-ish", max_tilt < 0.6, "(%.2f rad)" % max_tilt)
	check("not on the boy's heels again at once", g.chasing == false or g.prey != player)

	# A puppet fed its news follows it.
	var puppet := Griever.new()
	scene.add_child(puppet)
	puppet.puppet = true
	puppet.targets = [player]
	var puppet_caught := [0]
	puppet.caught.connect(func(_who: Node3D) -> void: puppet_caught[0] += 1)
	var bytes := g.state_bytes()
	check("state is small", bytes.size() == Griever.STATE_SIZE, "(%d bytes)" % bytes.size())
	check("from_bytes takes it", puppet.from_bytes(bytes))
	player.global_position = maze.world(path[3]) + Vector3.UP * 0.1
	g.alert(player.global_position)
	var gap_total := 0.0
	var samples := 0
	var puppet_steps := puppet.legs.steps
	for i in 600:
		await physics_frame
		if i % 5 == 0:
			puppet.from_bytes(g.state_bytes())
		if i > 30:
			gap_total += puppet.global_position.distance_to(g.global_position)
			samples += 1
	check("puppet follows", gap_total / samples < 1.0, "(%.2f m behind on average)" % (gap_total / samples))
	check("puppet walks", puppet.legs.steps - puppet_steps > 10, "(%d steps)" % (puppet.legs.steps - puppet_steps))
	check("puppet catches nobody (the host does)", puppet_caught[0] == 0, "(host caught %d)" % caught_who.size())
	puppet.queue_free()
	g.queue_free()
	player.queue_free()
	await frames(2)

	# What a frame of it costs (thinking, legs, tail and placing the parts).
	var timed := Griever.new()
	scene.add_child(timed)
	timed.setup(maze, path[10])
	timed.walk_to(path[2])
	timed.set_physics_process(false)
	await frames(2)
	var started := Time.get_ticks_usec()
	for i in 300:
		timed._physics_process(1.0 / 60.0)
	var each := (Time.get_ticks_usec() - started) / 300.0
	check("a frame of it is cheap", each < 1500.0, "(%.0f us a frame, on this machine)" % each)
	timed.queue_free()

	# In the open: sprinting gets away, running does not.
	check("sprints away", await chase_in_clearing(5.6) > 4.0)
	check("a run is caught up with", await chase_in_clearing(4.4) < 0.0)

	print("GRIEVER TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


## A stand-in for the boy runs straight across the clearing at `speed` with the
## griever after him. How much further ahead he is after eight seconds (less
## than 0 if it got him).
func chase_in_clearing(speed: float) -> float:
	var runner := CharacterBody3D.new()
	runner.collision_layer = 2
	scene.add_child(runner)
	runner.global_position = Vector3(-30.0, 0.0, 6.0)
	var g := Griever.new()
	scene.add_child(g)
	g.setup(maze, maze.cell_at(Vector3(-37.0, 0.0, 6.0)), -PI * 0.5)
	g.global_position = Vector3(-37.0, 0.0, 6.0)
	g.targets = [runner]
	var got := [false]
	g.caught.connect(func(_who: Node3D) -> void: got[0] = true)
	await frames(20)
	var gap_start := (runner.global_position - g.global_position).length()
	for i in 480:
		runner.velocity = Vector3(speed, 0.0, 0.0)
		runner.global_position += runner.velocity / 60.0
		await physics_frame
		if got[0]:
			break
	var gap := (runner.global_position - g.global_position).length() - gap_start
	print("  at %.1f m/s: %s, gap %.1f -> %.1f m (state %s)" % [speed, "caught" if got[0] else "free", gap_start, gap + gap_start, Griever.State.keys()[g.state]])
	g.queue_free()
	runner.queue_free()
	await frames(2)
	return -1.0 if got[0] else gap
