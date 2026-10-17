extends SceneTree
## Things hunt the round: alone, a round has an Apophis, mummies and a Griever,
## the same for the same seed; walk into the Griever and it stings him, and he is
## put back in the clearing; once out, nothing hunts him.
##
##     godot --headless --path . -s res://tests/hunt_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("HUNT", 1))
	await frames(20)
	var world = main.world
	var snakes := 0
	var mummies := 0
	for enemy in world.enemies.enemies:
		if enemy is Apophis:
			snakes += 1
		elif enemy is Mummy:
			mummies += 1
	check("an Apophis", snakes == 1, "(%d)" % snakes)
	check("mummies", mummies >= 4, "(%d)" % mummies)
	check("a Griever", world.griever != null and world.griever.is_inside_tree())
	check("they are run here, alone", not world.griever.puppet and not world.enemies.puppet)
	var griever_at: Vector3 = world.griever.global_position
	check("the Griever starts out in the maze, away from the clearing", not world.maze.in_clearing(world.maze.cell_at(griever_at)))

	# Stand in front of the Griever and wait.
	var was_caught := [false]
	world.caught.connect(func(_seat: int) -> void: was_caught[0] = true)
	var player = world.player
	var facing := Vector3(sin(world.griever.yaw), 0.0, cos(world.griever.yaw))
	player.global_position = world.griever.global_position + facing * 3.0 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	for i in 60 * 15:
		await physics_frame
		if was_caught[0]:
			break
	check("the Griever catches him", was_caught[0])
	await frames(5)
	check("and he is back in the clearing", world.maze.in_clearing(world.maze.cell_at(player.global_position)), str(player.global_position))
	check("the news says so", main._toast != null and "Caught" in main._toast.text, main._toast.text if main._toast else "")

	# Out: no longer hunted.
	player.global_position = world.maze.world(world.maze.exit + world.maze.exit_side * 2) + Vector3.UP * 0.2
	await frames(10)
	check("out, and not hunted", not player.is_in_group(&"maze_players"))

	print("HUNT TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
