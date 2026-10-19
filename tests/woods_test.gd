extends SceneTree
## The woodsman and the beast (MazeWoodsman, MazeBeast), put in by the dev tools
## in a round played alone: they go in and are drawn, the woodsman's lantern
## lights and keeps the hunters back, he warns and then swings at someone who
## crowds him, the beast shows itself, lures someone alone and reaches for them,
## and flees a woodsman; puppets of both follow what the host sends; their boxes
## in MazeStyle turn them off.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/woods_test.gd -- --dev

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
	main.start_solo()
	await frames(30)
	var world = main.world
	var player = world.player
	check("dev tools on", world.dev != null)
	# (nothing else to get in the way)
	for enemy: MazeEnemy in world.enemies.enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = false
	var before: int = world.enemies.enemies.size()

	# The woodsman, from his button.
	world.dev.spawn_hunter("woodsman", world.dev.AHEAD)
	await frames(3)
	var man: MazeWoodsman = world.enemies.enemies.back()
	check("+ WOODSMAN put in", world.enemies.enemies.size() == before + 1 and man is MazeWoodsman and man.is_inside_tree())
	check("drawn: the old man, his lantern", man.figure != null and man.figure.lantern != null and man.figure.lantern.is_inside_tree())
	var light := man.figure.lantern.find_children("*", "OmniLight3D", true, false)
	check("his lantern's one light", light.size() == 1, "(%d)" % light.size())
	await frames(60)
	check("the lantern hangs from his hand", man.figure.lantern.global_position.distance_to(man.global_position + Vector3.UP * 1.0) < 1.2, str(man.figure.lantern.global_position - man.global_position))
	check("his light keeps the hunters back", MazeWoodsman.lit(world.get_tree(), man.global_position + Vector3(2.0, 0.0, 1.0)) and not MazeWoodsman.lit(world.get_tree(), man.global_position + Vector3(20.0, 0.0, 0.0)))
	var mummy: MazeEnemy = null
	for enemy: MazeEnemy in world.enemies.enemies:
		if enemy is Mummy:
			mummy = enemy
			break
	if mummy:
		var was: Vector3 = player.global_position
		player.global_position = man.global_position + Vector3(1.5, 0.0, 1.5)
		var in_light: bool = mummy.huntable(player)
		player.global_position = man.global_position + Vector3(30.0, 0.0, 0.0)
		check("a mummy cannot go after anyone in it", not in_light and mummy._shy_of_lanterns())
		player.global_position = was
	# Near him: he warns.
	var to_him: Vector3 = man.global_position - player.global_position
	to_him.y = 0.0
	player.global_position = man.global_position - to_him.normalized() * 7.0 + Vector3.UP * 0.2
	var warned := false
	for i in 120:
		await physics_frame
		if man.mode == MazeWoodsman.Mode.WARN:
			warned = true
			break
	check("someone near: he warns them off (WARN)", warned, "(mode %d)" % man.mode)
	# Crowd him: he swings.
	var swung := false
	var caught := [0]
	man.caught.connect(func(_p: Node3D) -> void: caught[0] += 1)
	for i in 300:
		await physics_frame
		var front := Vector3(sin(man.facing_yaw), 0.0, cos(man.facing_yaw))
		player.global_position = man.global_position + front * 1.3 + Vector3.UP * 0.1
		player.velocity = Vector3.ZERO
		if man.mode == MazeWoodsman.Mode.SWING:
			swung = true
		if caught[0] > 0:
			break
	check("crowd him and he swings his axe (SWING)", swung, "(mode %d)" % man.mode)
	check("the axe catches whoever stays in front of him", caught[0] > 0)
	player.global_position = man.global_position + Vector3(40.0, 0.2, 0.0)
	man.global_position += Vector3(0.0, 0.0, 0.0)

	# The beast, from its button: shown at once where it is put.
	world.player.global_position = world.gate_spot(1).origin
	await frames(20)
	man.global_position = player.global_position + Vector3(300.0, 0.0, 300.0)
	man.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(2)
	world.dev.spawn_hunter("beast", world.dev.SNAKE_AHEAD)
	await frames(3)
	var beast: MazeBeast = world.enemies.enemies.back()
	check("+ BEAST put in", beast is MazeBeast and beast.is_inside_tree() and beast.shown())
	check("drawn: the shadow, its eyes, its lantern", beast.figure != null and beast.figure.visible and beast.figure.lantern != null)
	# (out in the open, 14 m from him towards the middle, where it sees him and he it)
	var inward: Vector3 = -player.global_position
	inward.y = 0.0
	var spot: Vector3 = player.global_position + inward.normalized() * 14.0
	spot.y = world.maze.ground_height(spot) + 0.05
	beast._put(spot, atan2(-inward.x, -inward.z))
	# (as it was put in: watching, shown)
	beast._set_mode(MazeBeast.Mode.WATCH)
	beast._watch_for = 30.0
	beast.figure.cancel()
	await frames(2)
	var lured := false
	var start: Vector3 = player.global_position
	for i in 240:
		await physics_frame
		if beast.mode == MazeBeast.Mode.LURE:
			lured = true
	check("someone alone in its sight: it lures them (LURE)", lured, "(mode %d)" % beast.mode)
	var drawn: float = (player.global_position - start).dot((beast.global_position - start).normalized())
	check("they are drawn towards it", drawn > 0.3, "(%.1f m)" % drawn)
	# Right up to it: it reaches.
	var reached := false
	for i in 200:
		await physics_frame
		var to: Vector3 = beast.global_position - player.global_position
		to.y = 0.0
		if to.length() > 1.8:
			player.global_position = beast.global_position - to.normalized() * 1.8 + Vector3.UP * 0.1
		if beast.mode == MazeBeast.Mode.REACH:
			reached = true
	check("come to it and it reaches for you (REACH)", reached, "(mode %d)" % beast.mode)
	# A woodsman near it: it flees.
	await frames(200)
	beast.mode = MazeBeast.Mode.WATCH
	beast._show(true)
	man.process_mode = Node.PROCESS_MODE_INHERIT
	man.global_position = beast.global_position + Vector3(4.0, 0.0, 0.0)
	await frames(10)
	check("it flees the woodsman's light (FLEE)", beast.mode in [MazeBeast.Mode.FLEE, MazeBeast.Mode.HIDDEN], "(mode %d)" % beast.mode)

	# Puppets of both follow what is sent.
	var copies: Array[MazeEnemy] = [MazeWoodsman.new(), MazeBeast.new()]
	for k in copies.size():
		var copy := copies[k]
		copy.maze = world.maze
		copy.puppet = true
		copy.position = player.global_position + Vector3(4.0 * k, 0.0, 6.0)
		world.add_child(copy)
	await frames(2)
	var hosts: Array[MazeEnemy] = [man, beast]
	for i in 60:
		for k in 2:
			copies[k].from_bytes(hosts[k].state_bytes())
		await physics_frame
	check("a guest's woodsman follows the host's", copies[0].global_position.distance_to(man.global_position) < 3.0 and copies[0].mode == man.mode, "(%.1f m)" % copies[0].global_position.distance_to(man.global_position))
	check("a guest's beast follows the host's", copies[1].mode == beast.mode and copies[1].shown() == beast.shown())

	# Their boxes.
	var style := MazeStyle.avenues()
	check("on by default: one woodsman, one beast a section", style.woodsmen_on and style.beasts_on and style.amount(&"woodsmen") == 1.0 and style.amount(&"beasts") == 1.0)
	style.woodsmen_on = false
	style.beasts_on = false
	check("their boxes off: none", style.amount(&"woodsmen") == 0.0 and style.amount(&"beasts") == 0.0)
	print("woods_test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
