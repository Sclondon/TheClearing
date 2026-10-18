extends SceneTree
## The slime wall (creatures/slime_wall/, scripts/enemies/maze_slime_wall.gd),
## headless. First the creature on its own between walls of its own: it fills
## the room it has, squeezes into a gap, keeps its width past a turning off,
## says what is inside it, and holds and lets go. Then in a maze: it fills a
## hall so that nobody gets past, comes after the boy, holds him (stopped)
## and only then catches him; and a puppet of it follows the host's news and
## holds this machine's player without catching anybody.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/slime_wall_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


## Lets up to `seconds` of physics go by, or fewer if `until` comes true. Says whether it did.
func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	_run.call_deferred()


func _block(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _run() -> void:
	await _alone()
	await _no_way_past()
	await _in_the_maze()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _alone() -> void:
	var yard := Node3D.new()
	root.add_child(yard)
	_block(yard, Vector3(0, -0.5, 0), Vector3(60, 1, 200))
	# A passage 8 m wide (walls at x = +-4.5, a metre thick), a 3 m gap at z = -40, and a turning off on the left at z = 20.
	for side in [-1.0, 1.0]:
		_block(yard, Vector3(side * 4.5, 3, -5), Vector3(1, 6, 40))
		_block(yard, Vector3(side * 2.0, 3, -40), Vector3(1, 6, 10))
	_block(yard, Vector3(4.5, 3, 20), Vector3(1, 6, 10))
	await frames(2)
	var slime := SlimeWall.new()
	yard.add_child(slime)
	slime.global_position = Vector3(0, 0, 0)
	slime.settle()
	await frames(30)
	check("it fills the passage it is in", absf(slime.fitted_width - 7.85) < 0.2, "(%.2f m wide, %.2f m off the middle)" % [slime.fitted_width, slime.fitted_offset])
	check("it sits in the middle of it", absf(slime.fitted_offset) < 0.1)
	check("something in it is inside it", slime.contains(Vector3(3.5, 1.0, 0.0)))
	check("something past its front is not", not slime.contains(Vector3(0.0, 1.0, slime.depth * 0.5 + 1.5)))
	check("over its top is not", not slime.contains(Vector3(0.0, slime.fitted_height() + 1.0, 0.0)))
	# Into the gap: it squeezes, and rises.
	var tall := slime.fitted_height()
	slime.global_position = Vector3(0, 0, -40)
	await frames(90)
	check("it squeezes into a gap", absf(slime.fitted_width - 2.85) < 0.2, "(%.2f m wide)" % slime.fitted_width)
	check("squeezed, it rises", slime.fitted_height() > tall + 0.5, "(%.2f m high, was %.2f)" % [slime.fitted_height(), tall])
	# Back in the passage, then past its end to the turning off: it keeps its width along the wall it has.
	slime.global_position = Vector3(0, 0, 0)
	await frames(90)
	slime.global_position = Vector3(0, 0, 20)
	await frames(90)
	check("past a turning off it keeps the width it had", absf(slime.fitted_width - 7.85) < 0.3, "(%.2f m wide)" % slime.fitted_width)
	check("against the wall it still has", absf((slime.fitted_offset - slime.fitted_width * 0.5) - (-4.0)) < 0.3 or absf((slime.fitted_offset + slime.fitted_width * 0.5) - 4.0) < 0.3, "(offset %.2f)" % slime.fitted_offset)
	# Holding something: drawn in, and let go upright.
	var thing := Node3D.new()
	yard.add_child(thing)
	thing.global_position = slime.global_position + Vector3(0.5, 0.0, slime.depth * 0.5 + 0.5)
	var let_go := []
	slime.released.connect(func(node: Node3D) -> void: let_go.append(node))
	slime.hold(thing, 0.6)
	await frames(20)
	check("what it holds is drawn into it", slime.contains(thing.global_position), "(at %s)" % thing.global_position)
	check("and lifted", thing.global_position.y > 0.5)
	await frames(30)
	check("it lets go when the time is up", let_go == [thing] and not slime.holding(thing))
	check("let go upright", thing.global_transform.basis.y.is_equal_approx(Vector3.UP))
	yard.queue_free()
	await frames(2)


func _in_the_maze() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var maze := Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	var nav := MazeNav.new(maze)
	var boy: Player = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	await frames(5)
	# A long straight hall: the boy at one end, the slime three cells on.
	var found := _straight_run(maze, nav, 5)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy._reset_visuals()
	var slime := MazeSlimeWall.new()
	slime.maze = maze
	slime.seed_choices(7)
	slime.position = maze.world(cell + way * 3) + Vector3.UP * 0.05
	slime.rotation.y = atan2(-along.x, -along.z)
	slime.targets = [boy]
	stage.add_child(slime)
	var caught := []
	slime.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await frames(30)
	# Nobody gets past it: every point across the hall, wall to wall, is in it.
	var across := Vector3(-along.z, 0, along.x)
	var middle := slime.creature.global_position
	var through := 0
	var inside := 0
	# (out from its middle each way, as far as the walls)
	for side: float in [-1.0, 1.0]:
		for k in 80:
			var point := middle + across * side * (0.2 + k * 0.4) + Vector3.UP
			if not stage.get_world_3d().direct_space_state.intersect_point(_point_query(point)).is_empty():
				break
			through += 1
			if slime.creature.contains(point, 0.05):
				inside += 1
	check("it fills the hall from wall to wall", inside == through and through > 10, "(%d of %d points across the hall in it; %.1f m wide)" % [inside, through, slime.creature.fitted_width])
	# It comes after him, slowly.
	slime.notice(boy)
	var from := slime.global_position
	await wait(3.0)
	var speed := from.distance_to(slime.global_position) / 3.0
	check("it comes after him, slower than a walk", speed > 0.6 and speed < 2.0, "(%.2f m/s)" % speed)
	# It reaches him: he is held, stopped, and caught only after HOLD.
	var held := await wait(60.0, func() -> bool: return slime.creature.holding())
	check("it takes him in", held)
	check("while it holds him he is stopped", boy.process_mode == Node.PROCESS_MODE_DISABLED)
	check("and not yet caught", caught.is_empty())
	var got := await wait(MazeSlimeWall.HOLD + 0.5, func() -> bool: return not caught.is_empty())
	check("then he is caught", got and caught[0] == boy)
	check("and let go (moving again)", boy.process_mode != Node.PROCESS_MODE_DISABLED)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, slime.state_bytes().size() == MazeEnemy.STATE_SIZE)

	# A puppet of it follows the host's news, and holds this machine's player without catching him.
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy._reset_visuals()
	var host := MazeSlimeWall.new()
	host.maze = maze
	host.position = maze.world(cell + way) + Vector3.UP * 0.05
	host.rotation.y = atan2(-along.x, -along.z)
	var dummy := Node3D.new()
	stage.add_child(dummy)
	dummy.global_position = maze.world(cell) + Vector3.UP * 0.1
	host.targets = [dummy]
	stage.add_child(host)
	var copy := MazeSlimeWall.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	copy.targets = [boy]
	stage.add_child(copy)
	var copy_caught := []
	copy.caught.connect(func(who: Node3D) -> void: copy_caught.append(who))
	host.notice(dummy)
	slime.queue_free()
	var worst := 0.0
	var copy_held := false
	for i in 1500:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(host.global_position))
		if copy.creature.holding():
			copy_held = true
	check("a puppet follows the host's news", worst < 1.5, "(at worst %.2f m behind)" % worst)
	check("a puppet holds this machine's player when it reaches him", copy_held)
	check("a puppet catches nobody", copy_caught.is_empty())
	await wait(MazeSlimeWall.HOLD + 0.3)
	check("and lets him go again", boy.process_mode != Node.PROCESS_MODE_DISABLED)
	stage.queue_free()
	await frames(2)


func _point_query(point: Vector3) -> PhysicsPointQueryParameters3D:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = 1
	return query


func _straight_run(maze: Maze, nav: MazeNav, run: int) -> Array:
	for c: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


## In real halls of a first-ring maze, nobody gets past it: a capsule the size
## of the boy, slid across the hall through its middle, wherever it is clear of
## the walls, always touches it; and what is seen of it reaches into both walls
## (so no floor shows beside it).
func _no_way_past() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var maze := Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	var nav := MazeNav.new(maze)
	await frames(3)
	var space := stage.get_world_3d().direct_space_state
	var boy := CapsuleShape3D.new()
	boy.radius = 0.22
	boy.height = 1.3
	# Halls: places with three open cells straight on, walled to either side within
	# two cells (not where another way crosses), apart from each other, in the first ring.
	var halls: Array = []
	var ring := maze.ring_of(nav.lairs(3)[0])
	var cells := nav.lairs(2)
	# (taken from all round the ring, not one side of it)
	for i in cells.size():
		var c: Vector2i = cells[(i * 37) % cells.size()]
		if halls.size() >= 6 or maze.ring_of(c) != ring:
			continue
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(c, step) or maze.blocked(c + step, step) or maze.blocked(c - step, -step):
				continue
			var walled := true
			for k in 3:
				for side: Vector2i in [Vector2i(-step.y, step.x), Vector2i(step.y, -step.x)]:
					var at: Vector2i = c + step * (k - 1)
					if not (maze.blocked(at, side) or maze.blocked(at + side, side)):
						walled = false
			if not walled:
				continue
			var apart := true
			for other: Array in halls:
				if absi(c.x - other[0].x) + absi(c.y - other[0].y) < 6:
					apart = false
			if apart:
				halls.append([c, step])
			break
	check("found halls to try", halls.size() >= 4, "(%d)" % halls.size())
	var gaps := 0
	var short := 0
	var tried := 0
	for hall: Array in halls:
		var along := Vector3(hall[1].x, 0, hall[1].y)
		var across := Vector3(-along.z, 0, along.x)
		# In the middle of the cell, and put down 3 m towards the middle of the hall (as it wanders).
		var inward := Vector2i(-hall[1].y, hall[1].x)
		var toward := -1.0 if maze.blocked(hall[0], inward) else 1.0
		for aside: float in [0.0, 3.0 * toward]:
			tried += 1
			var slime := SlimeWall.new()
			slime.height = 9.0
			slime.depth = 5.0
			slime.max_width = 34.0
			stage.add_child(slime)
			slime.global_transform = Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)), maze.world(hall[0]) + across * aside)
			slime.settle()
			await frames(40)
			var middle := slime._body.global_position
			var right := slime._body.global_transform.basis.x
			var open := 0
			var walls := Vector2(INF, INF)
			for k in 2:
				var side := -1.0 if k == 0 else 1.0
				for n in 400:
					var at := middle + right * side * n * 0.05 + Vector3.UP * 0.7
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = boy
					query.transform = Transform3D(Basis.IDENTITY, at)
					query.collision_mask = 1
					if not space.intersect_shape(query, 1).is_empty():
						walls[k] = n * 0.05 + boy.radius
						break
					if not slime.contains(at, boy.radius):
						open += 1
			var reach := slime.visual_extents()
			var shows_floor := (walls.x < INF and reach.x < walls.x) or (walls.y < INF and reach.y < walls.y)
			if open > 0:
				gaps += 1
			if shows_floor:
				short += 1
			print("  hall %s %s, %.0f m aside: walls %.2f and %.2f m from its middle, it reaches %.2f and %.2f, %.2f m wide; %d places the boy gets by" % [hall[0], hall[1], aside, walls.x, walls.y, reach.x, reach.y, slime.fitted_width, open])
			slime.queue_free()
			await frames(2)
	check("the boy cannot get past it in any hall", gaps == 0, "(%d of %d places had a way by)" % [gaps, tried])
	check("what is seen of it reaches into both walls", short == 0, "(%d of %d short of a wall)" % [short, tried])
	stage.queue_free()
	await frames(2)
