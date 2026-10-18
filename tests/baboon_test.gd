extends SceneTree
## The baboons (scripts/enemies/maze_baboon.gd, creatures/baboon/), headless,
## in a bare scene: a maze from MazeBuilder and the boy standing in it. A troop
## that notices him and comes; one that leaps and catches him; a burst that
## wears one out; the alpha holding back; a flanker making for where he is
## going; wandering and sitting with nobody about; and puppets following what
## the host sends, leaps and all.
##
##     godot --headless --path . -s res://tests/baboon_test.gd
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


func put_boy(cell: Vector2i) -> void:
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


## A passage cell `steps` from `from` by the passages.
func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


func spawn(one: MazeBaboon, cell: Vector2i, offset := Vector3.ZERO) -> MazeBaboon:
	one.maze = maze
	one.position = maze.world(cell) + offset + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught_by.clear()


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	put_boy(home)
	await frames(20)

	# --- A troop notices him and comes ---
	var troop := MazeBaboon.troop(5)
	check("a troop is an alpha and four baboons", troop.size() == 5 and troop[0].alpha and not troop[1].alpha and troop[2].flank > 0)
	var from := cell_from(home, 3)
	for k in troop.size():
		spawn(troop[k], from, Vector3(k - 2, 0, 0) * 1.2)
	troop[1].notice(boy)
	var hunted := await wait(2.0, func() -> bool:
		for one in troop:
			if not one.chasing:
				return false
		return true)
	check("one notices him and the troop takes up the hunt", hunted)
	var barked := troop[1]._barks > 0
	check("the one that saw him barked", barked)
	var start := troop[1].global_position.distance_to(boy.global_position)
	var caught := await wait(20.0, func() -> bool: return not caught_by.is_empty())
	check("a baboon catches him, standing still", caught and caught_by[0][0] == boy, "(from %.1f m)" % start)
	if caught:
		var by: MazeBaboon = caught_by[0][1]
		check("caught by a leap", by._leaps > 0 and not by.alpha, "(leaps %d, alpha %s)" % [by._leaps, by.alpha])
	var held := false
	for one in troop:
		if one.alpha and (one.mode == MazeBaboon.Mode.HOLDING or one._displays > 0):
			held = true
	check("the alpha held back and threatened", held, "(alpha mode %s, displays %d)" % [MazeBaboon.Mode.keys()[troop[0].mode], troop[0]._displays])
	clear()

	# --- A burst wears one out ---
	put_boy(home)
	await frames(5)
	var runner := spawn(MazeBaboon.new(), cell_from(home, 1))
	runner.leap_range = 0.0
	runner.notice(boy)
	var spent := await wait(8.0, func() -> bool: return runner.mode == MazeBaboon.Mode.SPENT)
	check("bursting, it runs out of wind and stops to display", spent and runner._displays > 0, "(stamina %.2f)" % runner.stamina)
	var stood := runner.velocity.length() < 0.5
	await frames(10)
	check("spent, it stands", stood or runner.velocity.length() < 0.5)
	var going := await wait(5.0, func() -> bool: return runner.mode == MazeBaboon.Mode.HUNTING)
	check("with its wind back it comes on", going)
	clear()

	# --- A flanker makes for where he is going ---
	put_boy(home)
	await frames(5)
	var flanker := MazeBaboon.new()
	flanker.flank = 2
	spawn(flanker, cell_from(home, 3))
	flanker.notice(boy)
	await frames(2)
	var heading := Vector3.ZERO
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(home, step) and nav.allowed(home + step):
			heading = Vector3(step.x, 0, step.y)
	boy.velocity = heading * 4.4
	var aim: Vector3 = flanker.goal()
	check("a flanker aims ahead of him", aim.distance_to(boy.global_position) > 4.0, "(%.1f m ahead)" % aim.distance_to(boy.global_position))
	boy.velocity = Vector3.ZERO
	clear()

	# --- Nobody about: they wander, and sit ---
	boy.remove_from_group(&"maze_players")
	var idle := spawn(MazeBaboon.new(), lairs[0])
	idle.seed_choices(5)
	idle._sit_in = 1.0
	var was: Vector3 = idle.global_position
	var sat := await wait(4.0, func() -> bool: return idle.mode == MazeBaboon.Mode.SITTING)
	check("with nobody about it sits up now and then", sat)
	await wait(14.0)
	var moved: float = idle.global_position.distance_to(was)
	check("and wanders the passages", moved > 4.0 and not maze.in_clearing(maze.cell_at(idle.global_position)), "(%.1f m)" % moved)
	boy.add_to_group(&"maze_players")
	clear()

	# --- Puppets follow the host ---
	put_boy(home)
	await frames(5)
	var host := spawn(MazeBaboon.new(), cell_from(home, 2))
	host.seed_choices(3)
	var copy := MazeBaboon.new()
	copy.seed_choices(3)
	copy.puppet = true
	spawn(copy, cell_from(home, 2))
	host.notice(boy)
	var worst := 0.0
	var copy_leapt := false
	for i in 360:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(host.global_position))
		if copy.body.leap_stage() != Baboon.Leap.NONE:
			copy_leapt = true
	check("a puppet follows the host's news", worst < 2.0, "(at worst %.2f m behind)" % worst)
	check("and leaps when the host leaps", copy_leapt == (host._leaps > 0), "(host leaps %d)" % host._leaps)
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	clear()

	# --- The component's example runs on its own ---
	var example: Node3D = load("res://creatures/baboon/example.gd").new()
	stage.add_child(example)
	await wait(0.2)
	var was_at: Vector3 = example.alpha.global_position
	var sizes := []
	for kind in [Baboon.Kind.BABOON, Baboon.Kind.ALPHA]:
		var mesh: ArrayMesh = BaboonLook._meshes[kind]
		sizes.append(mesh.surface_get_array_len(0))
	await wait(3.0)
	check("the example runs them round", example.alpha.global_position.distance_to(was_at) > 1.0, "(vertices: baboon %d, alpha %d)" % sizes)
	example.free()

	print("BABOON TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)
