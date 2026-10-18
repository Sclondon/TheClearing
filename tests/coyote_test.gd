extends SceneTree
## The coyotes (scripts/enemies/maze_coyote.gd on creatures/coyote), headless,
## in a bare scene: a maze from MazeBuilder and the boy in it. In turn: one
## alone that sees him stares and shadows him at a distance, and runs when he
## walks at it; a pair never grows bold; a pack of four round him while he is
## alone grows bold, circles and darts in, and catches him; with a friend by
## him the pack never does; a tame one in the clearing keeps to its patch and
## lets anyone in the maze alone; a puppet follows what the host sends.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/coyote_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Node3D
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
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3, facing := 0.0) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = facing


## A long straight run of open cells in the maze: (first cell, the step along it, how many).
func long_hall() -> Array:
	var best := [Vector2i.ZERO, Vector2i(1, 0), 0]
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 8 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best[2]:
				best = [cell, step, run]
	return best


func pack_at(at: Vector3, count: int, seed_value := 7) -> Array[MazeCoyote]:
	var made := MazeCoyote.pack_of(count, seed_value)
	for k in made.size():
		var one := made[k]
		one.maze = maze
		one.seed_choices(k + 3)
		one.position = at + Vector3(k * 1.2 - count * 0.6, 0.05, 0.0)
		stage.add_child(one)
		one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return made


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(3)


func _run() -> void:
	await frames(10)
	var hall := long_hall()
	var first: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var start := nav.point(first)
	print("a hall of %d cells" % hall[2])

	# --- One alone: stares, shadows, runs when walked at ---
	var lone := pack_at(start, 1)[0]
	put_boy(start + way * 26.0, atan2(-way.x, -way.z))
	var shadowing := await wait(6.0, func() -> bool: return lone.mode in [MazeCoyote.Mode.STARE, MazeCoyote.Mode.SHADOW])
	check("a coyote that sees him stares and shadows him", shadowing, "(mode %d)" % lone.mode)
	# He runs straight at it.
	var fled := false
	for i in 240:
		var to: Vector3 = lone.global_position - boy.global_position
		to.y = 0.0
		var move := to.normalized() * 4.4 / 60.0
		boy.global_position += move
		boy.velocity = move * 60.0
		boy.facing_yaw = atan2(to.x, to.z)
		await physics_frame
		if lone.mode == MazeCoyote.Mode.FLEE:
			fled = true
			break
	check("run at, it runs off", fled, "(mode %d, %.1f m off)" % [lone.mode, lone.global_position.distance_to(boy.global_position)])
	check("one alone never grows bold", lone.boldness < 0.5 and caught_by.is_empty())
	await clear()

	# --- A pair: never bold ---
	var pair := pack_at(start, 2, 11)
	put_boy(start + way * 14.0, atan2(way.x, way.z))
	await wait(14.0)
	var bold_pair := false
	for one in pair:
		bold_pair = bold_pair or one.mode in [MazeCoyote.Mode.CIRCLE, MazeCoyote.Mode.DART]
	check("a pair never closes in", not bold_pair and caught_by.is_empty())
	await clear()

	# --- A pack of four round him alone: bold, circling, a dart ---
	var four := pack_at(start, 4, 23)
	# (he stands looking away down the hall)
	put_boy(start + way * 14.0, atan2(way.x, way.z))
	var circled := await wait(25.0, func() -> bool: return four.any(func(c: MazeCoyote) -> bool: return c.mode == MazeCoyote.Mode.CIRCLE))
	check("four round him alone grow bold and circle", circled, "(boldness %.2f)" % four[0].boldness)
	var bitten := await wait(15.0, func() -> bool: return not caught_by.is_empty())
	check("one darts in and catches him", bitten)
	check("then they scatter", await wait(3.0, func() -> bool: return four.all(func(c: MazeCoyote) -> bool: return c.mode in [MazeCoyote.Mode.FLEE, MazeCoyote.Mode.SLINK, MazeCoyote.Mode.ROAM, MazeCoyote.Mode.STARE, MazeCoyote.Mode.SHADOW]) and four.all(func(c: MazeCoyote) -> bool: return c.boldness <= 0.0)))
	await clear()

	# --- With a friend by him: never ---
	var friend: Node3D = load("res://player.tscn").instantiate()
	friend.takes_input = false
	stage.add_child(friend)
	friend.add_to_group(&"maze_players")
	friend.global_position = start + way * 15.5 + Vector3.UP * 0.1
	var guarded := pack_at(start, 4, 31)
	put_boy(start + way * 14.0, atan2(way.x, way.z))
	await wait(18.0)
	var bold_now := false
	for one in guarded:
		bold_now = bold_now or one.mode in [MazeCoyote.Mode.CIRCLE, MazeCoyote.Mode.DART]
	check("with a friend near him the pack keeps off", not bold_now and caught_by.is_empty())
	friend.queue_free()
	await clear()

	# --- Tame, in the clearing ---
	var home := Vector3(150.0, 0.0, 150.0)
	home.y = maze.ground_height(home)
	var tame := MazeCoyote.pack_of(3, 41)
	for k in tame.size():
		var one := tame[k]
		one.tame = true
		one.keep_out_of_clearing = false
		one.home = home
		one.maze = maze
		one.position = home + Vector3(k * 1.5, 0.3, 0.0)
		stage.add_child(one)
	put_boy(start, 0.0)
	await wait(15.0)
	var kept := true
	for one in tame:
		kept = kept and one.global_position.distance_to(home) < one.home_range * 1.6
	check("tame coyotes keep to their patch of the meadow", kept)
	check("and let anyone in the maze alone", tame.all(func(c: MazeCoyote) -> bool: return c.quarry == null))
	put_boy(home + Vector3(0.0, 0.0, 30.0), PI)
	var stared := await wait(5.0, func() -> bool: return tame.any(func(c: MazeCoyote) -> bool: return c.mode in [MazeCoyote.Mode.STARE, MazeCoyote.Mode.SHADOW]))
	check("but stare at someone in the clearing", stared)
	await wait(10.0)
	check("and are never bold", tame.all(func(c: MazeCoyote) -> bool: return c.mode not in [MazeCoyote.Mode.CIRCLE, MazeCoyote.Mode.DART]))
	await clear()

	# --- A puppet ---
	var host := pack_at(start, 1, 51)[0]
	var copy := MazeCoyote.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = start
	stage.add_child(copy)
	put_boy(start + way * 20.0, atan2(-way.x, -way.z))
	var furthest := 0.0
	for i in 300:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", furthest < 1.5, "(at most %.2f m off)" % furthest)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
