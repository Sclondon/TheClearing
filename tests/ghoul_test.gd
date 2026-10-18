extends SceneTree
## The ghoul (MazeGhoul, driving creatures/ghoul's Ghoul), headless, in a bare
## maze from MazeBuilder: it stands still with nobody about; it wakes and comes
## when someone is in sight; it screams at them and the scream holds them (but
## not someone turned away); it grabs and catches someone held; someone who
## keeps going gets away; a puppet copy follows the host's news, screams when
## it does, and its scream holds whoever plays on its own machine; and
## `paralyse` takes a Player's input away and gives it back.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/ghoul_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player: it can be held, and says when it was.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO
	var held_for := 0.0
	var holds := 0

	func hold(seconds: float) -> void:
		held_for = seconds
		holds += 1


var stage: Node3D
var maze
var nav
var failures := 0
var caught: Array = []
var lair := Vector2i.ZERO
var out := Vector3.ZERO


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
	_run.call_deferred()


## A dead end with a straight passage of at least `run` cells out of it, and the way out.
func find_lair(run: int) -> void:
	for pass_index in 2:
		for cell: Vector2i in nav.lairs(3):
			if pass_index == 0 and not nav.dead_end(cell):
				continue
			if _lair_at(cell, run):
				return


func _lair_at(cell: Vector2i, run: int) -> bool:
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			continue
		var ok := true
		for k in run:
			if maze.blocked(cell + step * k, step) or not nav.allowed(cell + step * (k + 1)):
				ok = false
		if ok:
			lair = cell
			out = Vector3(step.x, 0.0, step.y)
			return true
	return false


func dummy(at: Vector3, facing: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.facing_yaw = atan2(facing.x, facing.z)
	d.add_to_group(&"maze_players")
	return d


func ghoul() -> MazeGhoul:
	var g := MazeGhoul.new()
	g.maze = maze
	g.position = maze.world(lair) + Vector3.UP * 0.05
	g.rotation.y = atan2(out.x, out.z)
	stage.add_child(g)
	g.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return g


func clear() -> void:
	for child in stage.get_children():
		if child is MazeGhoul or child is Dummy:
			child.free()
	caught.clear()


## A stand-in walks up to a ghoul until it screams; held, it stands still for as
## long as it is held and `late` seconds more, then runs off down the passage
## as the boy does (4.4 m/s, a little while to get going). Says whether it was
## caught, and how far apart they ended.
func held_then_run(home: Vector3, late: float) -> Array:
	clear()
	var g := ghoul()
	var who := dummy(home + out * 7.5, -out)
	var free_at := INF
	var speed := 0.0
	var clock := 0.0
	for i in 60 * 14:
		await physics_frame
		clock += 1.0 / 60.0
		if who.holds > 0 and free_at == INF:
			free_at = clock + who.held_for + late
		if caught.has(who):
			break
		if free_at == INF:
			# (walking slowly up to it until it screams)
			who.global_position -= out * 1.0 / 60.0 if (who.global_position - g.global_position).length() > 4.5 else Vector3.ZERO
		elif clock > free_at:
			speed = minf(speed + 4.4 / 0.3 / 60.0, 4.4)
			who.global_position += out * speed / 60.0
			who.facing_yaw = atan2(out.x, out.z)
	var result := [caught.has(who), g.global_position.distance_to(who.global_position)]
	clear()
	return result


func _run() -> void:
	find_lair(2)
	print("lair %s, way out %s" % [lair, out])
	var home: Vector3 = maze.world(lair)

	# Nobody about: a statue.
	var g := ghoul()
	await wait(2.0)
	check("with nobody about it stands still", g.mode == MazeGhoul.Mode.STILL and g.global_position.distance_to(home) < 0.3 and not g.figure.awake, "(%s, %.2f m from home)" % [MazeGhoul.Mode.keys()[g.mode], g.global_position.distance_to(home)])
	check("its figure stays posed with nobody about", g.figure.visible)

	# Someone in sight down the passage: it wakes and comes.
	var far := dummy(home + out * 16.0, -out)
	var woke := await wait(3.0, func() -> bool: return g.mode == MazeGhoul.Mode.HUNTING)
	check("it wakes when someone is in sight 16 m off", woke, "(%s)" % MazeGhoul.Mode.keys()[g.mode])
	await wait(2.0)
	check("and shuffles towards them, slowly", g.global_position.distance_to(home) > 0.6 and g.global_position.distance_to(home) < 4.0, "(%.2f m in 2 s)" % g.global_position.distance_to(home))
	check("its figure is awake and looking", g.figure.awake and g.figure.aim.is_finite())

	# Closer: it screams, and holds them; but not someone turned away.
	far.global_position = g.global_position + out * 4.5
	var turned := dummy(g.global_position + out * 6.5 + Vector3(out.z, 0, -out.x) * 1.5, out)
	var screamed := await wait(3.0, func() -> bool: return g.figure.doing() == GhoulRig.Act.SCREAM)
	check("within scream range it screams", screamed)
	await wait(1.0)
	check("the scream holds whoever faces it", far.holds == 1 and absf(far.held_for - g.freeze_time) < 0.01, "(held %d times, for %.1f s)" % [far.holds, far.held_for])
	check("but not someone turned away from it", turned.holds == 0)
	turned.free()

	# Held, they are grabbed and caught.
	var got := await wait(6.0, func() -> bool: return caught.has(far))
	check("it grabs and catches someone standing still", got, "(%.2f m away, %s)" % [g.global_position.distance_to(far.global_position), GhoulRig.Act.keys()[g.figure.doing()]])
	check("and clings to them", g.figure.held or not got)
	clear()

	# Someone who keeps going gets away.
	g = ghoul()
	var runner := dummy(home + out * 7.0, -out)
	await wait(2.0, func() -> bool: return g.mode == MazeGhoul.Mode.HUNTING)
	var away := 0.0
	for i in 600:
		runner.global_position += out * 2.5 / 60.0 if away < 25.0 else Vector3.ZERO
		away += 2.5 / 60.0
		await physics_frame
	check("someone who keeps going (2.5 m/s) is not caught", caught.is_empty(), "(%.1f m apart at the end)" % g.global_position.distance_to(runner.global_position))
	runner.free()
	await wait(20.0, func() -> bool: return g.mode == MazeGhoul.Mode.STILL)
	check("having forgotten them it goes home and stands", g.mode == MazeGhoul.Mode.STILL and g.global_position.distance_to(home) < 1.0, "(%s, %.2f m from home)" % [MazeGhoul.Mode.keys()[g.mode], g.global_position.distance_to(home)])
	clear()

	# Held by a scream: run the moment you can and you get away; be slow and you are taken.
	var quick := await held_then_run(home, 0.0)
	check("held by its scream, someone who runs as soon as they can gets away", not quick[0], "(%.1f m apart at the end)" % quick[1])
	var slow := await held_then_run(home, 0.8)
	check("but someone who stands there a moment longer is caught", slow[0], "(%.1f m apart at the end)" % slow[1])

	# A puppet copy: follows the host, screams when it does, and holds its own machine's player.
	g = ghoul()
	var target := dummy(home + out * 7.0, -out)
	var copy := MazeGhoul.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = g.position
	copy.rotation.y = g.rotation.y
	stage.add_child(copy)
	var local := Dummy.new()
	stage.add_child(local)
	copy.targets = [local]
	var worst := 0.0
	var copy_screamed := false
	for i in 420:
		if i % 6 == 0:
			copy.from_bytes(g.state_bytes())
		await physics_frame
		local.global_position = copy.global_position + out * 5.0 + Vector3.UP * 0.05
		local.facing_yaw = atan2(-out.x, -out.z)
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(g.global_position))
		copy_screamed = copy_screamed or copy.figure.doing() == GhoulRig.Act.SCREAM
	check("a puppet ghoul follows the host's news", worst < 1.5, "(at worst %.2f m behind)" % worst)
	check("it screams when the host's does", copy_screamed)
	check("and its scream holds whoever plays on its machine", local.holds >= 1, "(held %d times)" % local.holds)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, g.state_bytes().size() == MazeEnemy.STATE_SIZE)
	local.free()
	clear()

	# A Player: its input taken away, and given back.
	var boy: Player = load("res://player.tscn").instantiate()
	stage.add_child(boy)
	boy.global_position = maze.world(lair) + Vector3.UP * 0.1
	MazeGhoul.paralyse(boy, 0.5)
	await wait(0.1)
	check("a held Player takes no input", not boy.takes_input)
	await wait(0.7)
	check("and has it back after", boy.takes_input)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
