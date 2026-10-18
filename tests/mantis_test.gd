extends SceneTree
## The giant mantis (scripts/enemies/maze_mantis.gd, creatures/mantis/),
## headless, in a bare scene: a maze from MazeBuilder and a stand-in player
## that the test moves by hand (a CharacterBody3D with no shape). In turn: the
## mantis on its own strikes in a blur and its forelegs reach a point in front
## of it and not one further off, and its head turns to what it looks at; in the
## maze it takes its post against a hall wall among plants it brings; someone
## far down the hall is watched (its head on them) and not struck; someone
## passing by out of its reach is let alone; someone facing it from near
## makes it rear in its display; someone who steps into its reach is struck
## and caught at once; one who is out of reach again before the forelegs come
## out is missed, and it stands a moment; hungry, it kills a creature that comes
## into reach (Ecology); a puppet strikes and displays when the host does;
## MazeEnemies' packing carries it; and what a frame of it costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/mantis_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var runner: CharacterBody3D
var failures := 0
var caught: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait(seconds: float, test := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if test.is_valid() and test.call():
			return true
	return not test.is_valid()


func _initialize() -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	runner = CharacterBody3D.new()
	runner.name = "Runner"
	runner.collision_layer = 0
	runner.collision_mask = 0
	stage.add_child(runner)
	runner.add_to_group(&"maze_players")
	_run.call_deferred()


func put_runner(at: Vector3, facing := 0.0) -> void:
	runner.global_position = at
	runner.velocity = Vector3.ZERO
	runner.rotation.y = facing


func mantis_at(cell: Vector2i, puppet := false) -> MazeMantis:
	var one := MazeMantis.new()
	one.sound = false
	one.maze = maze
	one.puppet = puppet
	one.seed_choices(23)
	one.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught.clear()
	await frames(3)


## A straight run of `count` cells from `from`: [the step, the cell at the end], or [].
func straight_from(from: Vector2i, count: int) -> Array:
	for step: Vector2i in Maze.STEPS:
		var at := from
		var run := 0
		while run < count and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
			at += step
			run += 1
		if run == count:
			return [step, at]
	return []


func _run() -> void:
	await frames(5)

	# --- On its own: the strike, its reach, its head ---
	var far_off := Vector3(0.0, 400.0, 0.0)
	var alone := GiantMantis.new()
	alone.sound = false
	stage.add_child(alone)
	alone.global_position = far_off
	alone.settle()
	await process_frame
	var near_point := far_off + Vector3(0.0, 1.25, 2.8)
	var far_point := far_off + Vector3(0.0, 1.25, 4.4)
	alone.strike(near_point)
	var to_shoot := 0.0
	var reached := false
	var reached_far := false
	var t := 0.0
	for i in 120:
		await process_frame
		var step := get_root().get_process_delta_time()
		t += step
		if alone.strike_stage() in [GiantMantis.Strike.COCK, GiantMantis.Strike.SHOOT]:
			to_shoot = t
		reached = reached or alone.strikes(near_point, 0.3)
		reached_far = reached_far or alone.strikes(far_point, 0.3)
		if alone.strike_stage() == GiantMantis.Strike.NONE and i > 3:
			break
	check("the strike is a blur (cocked and out in under a fifth of a second)", to_shoot < 0.21, "(%.2f s)" % to_shoot)
	check("its forelegs reach a chest 2.8 m in front", reached)
	check("and not one 4.4 m off", not reached_far)
	check("and draw back in", alone.strike_stage() == GiantMantis.Strike.NONE)
	alone.look_at_point = far_off + Vector3(4.0, 2.5, 1.0)
	await wait(1.5)
	var head := alone.skeleton.get_bone_pose_rotation(alone.bone("head")).get_euler()
	check("its head turns to what it looks at", head.y > 0.6, "(%.2f rad round)" % head.y)
	alone.queue_free()
	await frames(2)

	# --- In the maze: its post among its plants ---
	var hall := Vector2i(-1, -1)
	var along := Vector2i.ZERO
	for cell in nav.lairs(3):
		var run := straight_from(cell, 3)
		if not run.is_empty() and not nav.dead_end(cell):
			hall = cell
			along = run[0]
			break
	check("a straight hall to put it in", hall.x >= 0)
	put_runner(Vector3.ZERO)
	var one := mantis_at(hall + along)
	await frames(5)
	var post := one.global_position
	var out := Vector3(sin(one.facing_yaw), 0.0, cos(one.facing_yaw))
	var wall := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(post + Vector3.UP * 1.5, post + Vector3.UP * 1.5 - out * 5.0, 1))
	var gap := (post + Vector3.UP * 1.5).distance_to(wall["position"]) if not wall.is_empty() else INF
	check("it stands against a wall, facing out across the hall", nav.clear_of_walls(post, 0.8) and gap < 4.0, "(%.1f m from it)" % gap)
	check("among plants it brings", one._plants != null and one._plants.count > 12, "(%d)" % (one._plants.count if one._plants else 0))
	check("it is solid", one.collision_layer == 4)

	# --- Far down the hall: watched, not struck ---
	var way := Vector3(along.x, 0.0, along.y)
	var down_hall := post + way * 16.0 + out * 2.0
	if not nav.line_free(post + Vector3.UP, down_hall + Vector3.UP, 0.0):
		down_hall = post - way * 16.0 + out * 2.0
	put_runner(down_hall)
	var watched := await wait(2.0, func() -> bool: return one.mode == MazeMantis.Mode.TRACK and one.mantis.look_at_point.is_finite())
	check("seen from down the hall, its head follows him", watched, "(mode %s)" % MazeMantis.Mode.keys()[one.mode])
	await wait(1.0)
	check("and nothing more", caught.is_empty() and one.mode == MazeMantis.Mode.TRACK)

	# --- Passing by out of reach ---
	var lane := post + out * 4.6
	var dir := way
	var from := lane - dir * 7.0
	put_runner(from, atan2(dir.x, dir.z))
	var passed := true
	for i in 300:
		await physics_frame
		runner.velocity = dir * 4.4
		runner.global_position += runner.velocity / 60.0
		if not caught.is_empty():
			passed = false
			break
		if (runner.global_position - from).length() > 14.0:
			break
	check("running past out of its reach, he is let alone", passed and caught.is_empty())
	runner.velocity = Vector3.ZERO
	await clear()

	# --- Facing it from near: the display ---
	one = mantis_at(hall + along)
	await frames(5)
	post = one.global_position
	out = Vector3(sin(one.facing_yaw), 0.0, cos(one.facing_yaw))
	var front := post + out * 6.5
	put_runner(front, atan2(-out.x, -out.z))
	var shown := await wait(3.0, func() -> bool: return one.mode == MazeMantis.Mode.DISPLAY)
	check("faced from near, it rears in its threat display", shown, "(mode %s)" % MazeMantis.Mode.keys()[one.mode])
	await wait(0.6)
	check("wings up and spread", one.mantis._shown > 0.5)
	check("and has struck at nobody yet", one.strikes == 0 and caught.is_empty())

	# --- Into its reach: struck and caught ---
	await wait(3.0, func() -> bool: return one.mode != MazeMantis.Mode.DISPLAY)
	put_runner(post + out * 2.3, atan2(-out.x, -out.z))
	# (lambdas see a copy of a local: what they count goes in a dictionary)
	var counted := {"frames": 0}
	var got := await wait(1.0, func() -> bool:
		counted["frames"] += 1
		return not caught.is_empty())
	check("stepping into its reach, he is struck and caught at once", got and caught[0][0] == runner, "(within %.2f s)" % (counted["frames"] / 60.0))
	await wait(1.5)
	await clear()

	# --- Out again before the forelegs come: missed ---
	one = mantis_at(hall + along)
	await frames(5)
	post = one.global_position
	out = Vector3(sin(one.facing_yaw), 0.0, cos(one.facing_yaw))
	put_runner(post + out * 2.6)
	var started := await wait(1.0, func() -> bool: return one.mode == MazeMantis.Mode.STRIKE)
	put_runner(post + out * 6.0 + way * 3.0)
	var missed := await wait(1.5, func() -> bool: return one.mode == MazeMantis.Mode.RECOVER)
	check("out of reach again as it strikes, he is missed", started and missed and caught.is_empty())
	check("and it stands a moment after", one.mode == MazeMantis.Mode.RECOVER)
	await clear()

	# --- Ecology: hungry, it kills a creature in reach ---
	# (only once Ecology.KINDS has it as a meat-eater: "MazeMantis": [3, Diet.MEAT])
	var in_kinds := Ecology.KINDS.has("MazeMantis")
	put_runner(Vector3.ZERO)
	var life := Ecology.put(stage, 5, null)
	await frames(2)
	one = mantis_at(hall + along)
	await frames(5)
	one.hunger = 1.0
	post = one.global_position
	out = Vector3(sin(one.facing_yaw), 0.0, cos(one.facing_yaw))
	var ghoul := MazeGhoul.new()
	ghoul.maze = maze
	ghoul.position = post + out * 2.6
	stage.add_child(ghoul)
	await frames(2)
	ghoul.hunger = 0.0
	if not in_kinds:
		# (as Ecology would once it knows it for a meat-eater: it is after the ghoul)
		one.quarry = ghoul
		one._forget = 6.0
	var killed := await wait(4.0, func() -> bool: return ghoul.dead)
	check("hungry, it kills a ghoul that comes into its reach%s" % ("" if in_kinds else " (set after it by hand: Ecology.KINDS has no MazeMantis yet)"), killed and life.kills > 0)
	var eats := await wait(2.0, func() -> bool: return one.mode == MazeMantis.Mode.EAT)
	check("and eats it", eats)
	life.queue_free()
	await clear()

	# --- A puppet strikes and displays as the host does ---
	var host := mantis_at(hall + along)
	var copy := mantis_at(hall + along, true)
	await frames(5)
	post = host.global_position
	out = Vector3(sin(host.facing_yaw), 0.0, cos(host.facing_yaw))
	put_runner(post + out * 6.5, atan2(-out.x, -out.z))
	var copied_display := false
	var copied_strike := false
	for i in 400:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i == 200:
			put_runner(post + out * 2.4, atan2(-out.x, -out.z))
		copied_display = copied_display or (copy.mode == MazeMantis.Mode.DISPLAY and copy.mantis.display)
		copied_strike = copied_strike or copy.mantis.striking()
	check("the puppet displays when the host does", copied_display)
	check("the puppet strikes when the host does", copied_strike)
	check("the puppet catches nobody", caught.all(func(c: Array) -> bool: return c[1] != copy))
	check("and stands where the host does", copy.global_position.distance_to(host.global_position) < 1.0)
	var holder := MazeEnemies.new()
	holder.maze = maze
	stage.add_child(holder)
	holder.add(MazeMantis.new(), hall + along, 0.0, 23)
	await frames(3)
	check("MazeEnemies packs it", holder.pack().size() == 1 + MazeEnemy.STATE_SIZE)
	holder.queue_free()

	# --- What a frame of it costs ---
	put_runner(post + out * 8.0)
	await frames(10)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		host._physics_process(1.0 / 60.0)
	var think := (Time.get_ticks_usec() - t0) / 200.0
	t0 = Time.get_ticks_usec()
	for i in 200:
		host.mantis._process(1.0 / 60.0)
	var pose := (Time.get_ticks_usec() - t0) / 200.0
	check("its thinking costs little", think < 200.0, "(%.0f us)" % think)
	check("and its posing", pose < 500.0, "(%.0f us)" % pose)

	await clear()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

