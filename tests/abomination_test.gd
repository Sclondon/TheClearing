extends SceneTree
## The meat abomination (scripts/enemies/abomination.gd, and its look in
## creatures/abomination/), headless, in a bare scene: a maze from MazeBuilder
## and the boy standing in it. In turn: it creeps about with nobody near;
## it notices the boy down a passage and comes after him; it squeezes to the
## passage; it lashes at him when he is in reach and catches him; a step
## aside in the wind-up and the lash misses; walking into it catches; and a
## puppet follows the host's news, lashes and all.
##
##     godot --headless --path . -s res://tests/abomination_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Player
var failures := 0
var caught_by: Array = []


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


## A passage cell with `run` open cells straight on from it, and that way.
func straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return []


func spawn(at: Vector3, facing_to: Vector3) -> Abomination:
	var meat := Abomination.new()
	meat.maze = maze
	meat.position = at + Vector3.UP * 0.05
	stage.add_child(meat)
	var to := facing_to - at
	meat.facing_yaw = atan2(-to.x, -to.z)
	meat.caught.connect(func(who: Node3D) -> void: caught_by.append([who, meat]))
	return meat


func _run() -> void:
	await wait(0.2)
	var found := straight_run(4)
	check("a straight passage to test in", not found.is_empty())
	if found.is_empty():
		_end()
		return
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var far_off := maze.world(cell) + along * Maze.CELL * 3.0

	# --- Nobody about: it creeps about the passages ---
	boy.remove_from_group(&"maze_players")
	var wanderer := spawn(far_off, maze.world(cell))
	var from := wanderer.global_position
	await wait(6.0)
	check("with nobody about it creeps about", wanderer.global_position.distance_to(from) > 2.0 and not wanderer.chasing,
		"(%.1f m in 6 s)" % wanderer.global_position.distance_to(from))
	check("it measures the passage it is in", wanderer.look.room < 200.0, "(%.1f m across)" % wanderer.look.room)
	wanderer.free()
	boy.add_to_group(&"maze_players")

	# --- It sees him down the passage and comes ---
	put_boy(maze.world(cell))
	var hunter := spawn(far_off, maze.world(cell))
	var start := hunter.global_position.distance_to(boy.global_position)
	var noticed := await wait(3.0, func() -> bool: return hunter.chasing)
	check("it notices him down the passage", noticed, "(%.0f m off)" % start)
	await wait(5.0)
	var now := hunter.global_position.distance_to(boy.global_position)
	check("it comes after him, at no more than a walk", now < start - 4.0 and now > start - 13.0, "(%.1f m nearer in 5 s)" % (start - now))

	# --- The lash ---
	caught_by.clear()
	var lashed := await wait(20.0, func() -> bool: return hunter.look.lash_stage() == MeatAbomination.Stage.WIND_UP)
	check("in reach, it winds up a lash", lashed, "(%.1f m from him)" % hunter.global_position.distance_to(boy.global_position))
	var got := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("standing still, the lash catches him", got and caught_by[0][0] == boy)
	hunter.free()

	# A step aside in the wind-up, and it misses.
	caught_by.clear()
	put_boy(maze.world(cell))
	var dodged := spawn(maze.world(cell) + along * 13.0, maze.world(cell))
	dodged.notice(boy)
	await wait(10.0, func() -> bool: return dodged.look.lash_stage() == MeatAbomination.Stage.WIND_UP)
	var across := Vector3(-along.z, 0, along.x)
	# (back the way he came and to one side, well clear of where it lands)
	put_boy(maze.world(cell) - along * 7.0 + across * 3.0)
	boy.remove_from_group(&"maze_players")
	await wait(dodged.look.wind_up + dodged.look.strike + 0.3)
	check("a step aside in the wind-up and the lash misses", caught_by.is_empty())
	boy.add_to_group(&"maze_players")
	dodged.free()

	# --- Walking into it ---
	caught_by.clear()
	var lump := spawn(maze.world(cell) + along * 6.0, maze.world(cell))
	lump.lash_range = 0.0
	await wait(0.3)
	put_boy(lump.global_position + along * 1.0)
	var touched := await wait(1.0, func() -> bool: return not caught_by.is_empty())
	check("walking into its body catches", touched)
	lump.free()

	# --- A puppet follows its host ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var host := spawn(far_off, maze.world(cell))
	var copy := Abomination.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = far_off
	stage.add_child(copy)
	var worst := 0.0
	var copy_lashed := false
	for i in 1800:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 60:
			worst = maxf(worst, copy.global_position.distance_to(host.global_position))
		if copy.look.lash_stage() != MeatAbomination.Stage.NONE:
			copy_lashed = true
	check("a puppet follows the host's news", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("a puppet lashes when its host does", copy_lashed)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, host.state_bytes().size() == MazeEnemy.STATE_SIZE)
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] == host))
	_end()


func _end() -> void:
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
