extends SceneTree
## The giant toad (scripts/enemies/maze_frog.gd on creatures/frog), headless,
## in a bare scene: a maze from MazeBuilder and the boy in it. In turn: the
## toad on its own leaps where it is sent and shoots its tongue (a wind-up
## first; a body ducked under it is missed); in the maze, one that sees the boy
## croaks, winds up and catches him with its tongue; a shot he steps aside
## from misses; one far off comes at him in leaps, slower than he runs; a
## puppet follows the host and shoots when it does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/frog_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0
var caught_by: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


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
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func frog_at(at: Vector3, yaw := 0.0) -> MazeFrog:
	var frog := MazeFrog.new()
	frog.maze = maze
	frog.position = at + Vector3.UP * 0.05
	frog.rotation.y = yaw
	stage.add_child(frog)
	frog.caught.connect(func(player: Node3D) -> void: caught_by.append([player, frog]))
	return frog


func clear_frogs() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child is GiantToad:
			child.queue_free()
	caught_by.clear()
	await frames(2)


## A straight run of `count` cells from `from`: the cell at the end, or (-1, -1).
func straight_from(from: Vector2i, count: int) -> Vector2i:
	for step: Vector2i in Maze.STEPS:
		var at: Vector2i = from
		var run := 0
		while run < count and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
			at += step
			run += 1
		if run == count:
			return at
	return Vector2i(-1, -1)


func _run() -> void:
	await frames(10)

	# --- The toad on its own: a leap, and the tongue ---
	var far_off := Vector3(0.0, 300.0, 0.0)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor.add_child(shape)
	stage.add_child(floor)
	floor.global_position = far_off - Vector3(0.0, 0.5, 0.0)
	var toad := GiantToad.new()
	toad.voice = false
	toad.scale = Vector3.ONE * MazeFrog.SIZE
	stage.add_child(toad)
	toad.global_position = far_off
	toad.settle()
	await process_frame
	var to := far_off + Vector3(0.0, 0.0, 5.0)
	toad.leap(to)
	var highest := 0.0
	var stages := {}
	for i in 200:
		await process_frame
		var step := get_root().get_process_delta_time()
		toad.global_position += toad.leap_push() * step
		highest = maxf(highest, toad.global_position.y - far_off.y)
		stages[toad.leap_stage()] = true
		if toad.leap_stage() == GiantToad.Leap.NONE and i > 5:
			break
	check("a leap: crouch, flight, landing", stages.has(GiantToad.Leap.GATHER) and stages.has(GiantToad.Leap.FLIGHT) and stages.has(GiantToad.Leap.LAND))
	check("it comes down where it was sent", Vector2(toad.global_position.x - to.x, toad.global_position.z - to.z).length() < 0.5 and absf(toad.global_position.y - to.y) < 0.5, "(%.2f m off)" % toad.global_position.distance_to(to))
	check("in a high arc", highest > 1.5, "(%.1f m up)" % highest)
	toad.global_position = far_off
	toad.settle()
	var chest := far_off + Vector3(0.0, 1.35, 6.5)
	toad.strike(chest)
	await process_frame
	check("the tongue waits for the wind-up", toad.tongue_stage() == GiantToad.Tongue.WINDUP)
	var fired_after := 0.0
	var reached := 0.0
	var hit_chest := false
	var hit_ducked := false
	for i in 240:
		await process_frame
		if toad.tongue_stage() == GiantToad.Tongue.WINDUP:
			fired_after += get_root().get_process_delta_time()
		var seg := toad.tongue_segment()
		reached = maxf(reached, seg[0].distance_to(seg[1]))
		hit_chest = hit_chest or toad.tongue_hits(chest, 0.28)
		# (a boy ducked where the boy stood: his head no higher than 0.85)
		for h: float in [0.3, 0.55, 0.75]:
			hit_ducked = hit_ducked or toad.tongue_hits(far_off + Vector3(0.0, h, 6.5), 0.28)
		if toad.tongue_stage() == GiantToad.Tongue.NONE and i > 10:
			break
	check("a visible wind-up before it fires", fired_after > 0.8, "(%.2f s)" % fired_after)
	check("the tongue reaches him", reached > 5.5 and hit_chest, "(%.1f m)" % reached)
	check("a body ducked under it is missed", not hit_ducked)
	check("and it is reeled back in", toad.tongue_stage() == GiantToad.Tongue.NONE)
	toad.queue_free()
	floor.queue_free()
	await frames(2)

	# --- In the maze: it sees him, croaks, winds up and catches him with its tongue ---
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	var straight := straight_from(home, 1)
	check("a straight passage from the boy", straight.x >= 0)
	var boy_at: Vector3 = maze.world(home)
	var frog_spot: Vector3 = maze.world(home).lerp(maze.world(straight), 0.5)
	put_boy(boy_at)
	await frames(10)
	var to_boy: Vector3 = boy_at - frog_spot
	var frog := frog_at(frog_spot, atan2(to_boy.x, to_boy.z))
	var alerted := await wait(3.0, func() -> bool: return frog.mode == MazeFrog.Mode.ALERT)
	check("it sees him and croaks", alerted and frog.toad.busy())
	var wound := await wait(6.0, func() -> bool: return frog.mode == MazeFrog.Mode.WINDUP)
	check("it winds up", wound)
	var got := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("its tongue catches him (he stood still)", got and caught_by[0][0] == boy)
	await clear_frogs()

	# --- A shot he steps aside from misses ---
	put_boy(boy_at)
	await frames(10)
	frog = frog_at(frog_spot, atan2(to_boy.x, to_boy.z))
	wound = await wait(8.0, func() -> bool: return frog.mode == MazeFrog.Mode.WINDUP and frog.toad.windup_progress() > frog.aim_lock + 0.05)
	check("it winds up again", wound)
	var aside := Vector3(-to_boy.z, 0.0, to_boy.x).normalized()
	var dodge: Vector3 = boy_at + aside * 1.6
	if not nav.line_free(boy_at, dodge, 0.3):
		dodge = boy_at - aside * 1.6
	put_boy(dodge)
	var done := await wait(3.0, func() -> bool: return frog.mode == MazeFrog.Mode.RECOVER)
	check("he steps aside after it has aimed: it misses", done and caught_by.is_empty(), "(mode %s, caught %d)" % [MazeFrog.Mode.keys()[frog.mode], caught_by.size()])
	await clear_frogs()

	# --- One far off comes at him in leaps ---
	var long_end := straight_from(home, 2)
	if long_end.x < 0:
		long_end = straight_from(home, 1)
	put_boy(boy_at)
	await frames(10)
	var start: Vector3 = maze.world(long_end)
	to_boy = boy_at - start
	frog = frog_at(start, atan2(to_boy.x, to_boy.z))
	var gap0 := Vector2(to_boy.x, to_boy.z).length()
	var leapt := await wait(8.0, func() -> bool: return frog.mode == MazeFrog.Mode.HOP)
	check("it leaps at him", leapt, "(from %.0f m)" % gap0)
	await wait(4.0, func() -> bool: return frog.mode == MazeFrog.Mode.WINDUP or not caught_by.is_empty())
	var gap1 := Vector2(boy.global_position.x - frog.global_position.x, boy.global_position.z - frog.global_position.z).length()
	check("and closes on him", gap1 < gap0 - 4.0, "(%.1f m to %.1f m)" % [gap0, gap1])
	var cycle := GiantToad.GATHER_TIME + frog.toad.flight_time(frog.leap_length) + GiantToad.LAND_TIME + frog.rest_time
	check("slower than a run on the whole", frog.leap_length / cycle < 4.4, "(%.1f m/s)" % (frog.leap_length / cycle))
	await clear_frogs()

	# --- A puppet follows the host, and shoots with it ---
	put_boy(boy_at)
	await frames(10)
	to_boy = boy_at - frog_spot
	var host := frog_at(frog_spot, atan2(to_boy.x, to_boy.z))
	var copy := MazeFrog.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	var furthest := 0.0
	var copied_shot := false
	for i in 400:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		furthest = maxf(furthest, copy.global_position.distance_to(host.global_position)) if i > 30 else furthest
		if copy.toad.tongue_stage() != GiantToad.Tongue.NONE:
			copied_shot = true
	check("the puppet keeps up with the host", furthest < 1.5, "(at most %.2f m off)" % furthest)
	check("the puppet shoots its tongue when the host does", copied_shot)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear_frogs()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
