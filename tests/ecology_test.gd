extends SceneTree
## The world's own life (Ecology), headless, in a bare maze with nobody in it:
## a hungry dog sees a deer down a hall and goes after it, and the deer runs; it
## catches and kills it (a carcass is left, the dog is fed and eats); a puppet of
## the deer dies as its host's does; the dead deer comes back in its den in time;
## what nobody sees goes on its way; and nothing hunts what is bigger than it.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/ecology_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var failures := 0


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


func put(enemy: MazeEnemy, at: Vector3, puppet := false) -> MazeEnemy:
	enemy.maze = maze
	enemy.puppet = puppet
	enemy.position = at + Vector3.UP * 0.05
	stage.add_child(enemy)
	return enemy


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


func _run() -> void:
	await wait(0.2)
	var found := straight_run(3)
	check("a straight hall to test in", not found.is_empty())
	if found.is_empty():
		_end()
		return
	var cell: Vector2i = found[0]
	var along := Vector3(found[1].x, 0, found[1].y)
	var start := maze.world(cell)
	var world := Ecology.put(stage, 1, null)
	await wait(0.1)

	# --- A hungry dog and a deer down the hall ---
	var dog := put(MazeDog.new(), start)
	var deer := put(MazeDeer.new(), start + along * Maze.CELL * 2.0)
	var copy := put(MazeDeer.new(), start + along * Maze.CELL * 2.0, true)
	await wait(0.2)
	dog.hunger = 1.0
	check("a dog may eat a deer, a deer nothing", world.is_prey(deer, dog) and not world.is_prey(dog, deer))
	var after := await wait(3.0, func() -> bool: return dog.quarry == deer)
	check("the hungry dog sees the deer and goes after it", after)
	var ran := await wait(3.0, func() -> bool: return deer.threat == dog)
	check("the deer runs from it", ran)
	var killed := await wait(40.0, func() -> bool: return deer.dead)
	check("the dog catches the deer and kills it", killed, "(%d kills)" % world.kills)
	check("dead, it is hidden and stops nobody", not deer.visible and deer.collision_layer == 0)
	check("the dog is fed, and eats", dog.hunger < 0.05 and dog._eating > 0.0)
	copy.from_bytes(deer.state_bytes())
	check("a puppet of the deer dies as its host does", copy.dead and not copy.visible)

	# --- Back from its den ---
	world.seconds += Ecology.RESPAWN_SECONDS + 1.0
	world._back_from_dens()
	check("in time the dead deer comes back where it began", not deer.dead and deer.visible and deer.global_position.distance_to(start + along * Maze.CELL * 2.0) < 2.0)
	copy.from_bytes(deer.state_bytes())
	check("and its puppet with it", not copy.dead and copy.visible)

	# --- Out of sight ---
	dog.hunger = 0.0
	deer.process_mode = Node.PROCESS_MODE_DISABLED
	var was := deer.global_position
	for i in 3:
		world._out_of_sight(world.creatures())
	check("asleep, out of everyone's sight, it goes on its way", deer.global_position.distance_to(was) > 1.0, "(%.1f m)" % deer.global_position.distance_to(was))
	deer.process_mode = Node.PROCESS_MODE_INHERIT

	# --- Nothing hunts what is bigger than it ---
	var snake := put(Apophis.new(), start + along * Maze.CELL)
	await wait(0.1)
	check("a dog does not hunt the snake", not world.is_prey(snake, dog))
	check("nor anything a mummy", not world.is_prey(put(Mummy.new(), start + along * Maze.CELL * 3.0), dog))
	_end()


func _end() -> void:
	print("ECOLOGY TEST PASSED" if failures == 0 else "ECOLOGY TEST FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
