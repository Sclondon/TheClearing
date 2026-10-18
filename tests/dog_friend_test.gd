extends SceneTree
## Meat and the feral dogs' friendship (Loot's meat, MazeDog's friends), in a
## round played alone, with everything else that hunts put out of the way. In
## turn: meat cut from a carcass; thrown, a hungry dog goes to it and eats it,
## and is his friend (its look changes); it hunts him no more; it follows him
## at heel; a ghoul comes at him and it barks at it and goes for it, staggering
## it; a puppet sees the friendship; left far behind it goes feral again; a dog
## not hungry takes two pieces from his hand; and a ghoul goes to meat lying
## near it and eats it.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/dog_friend_test.gd

var main: Node
var failures := 0
var world
var maze: Maze
var player: Player
var loot
var nav: MazeNav
var caught := []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait(seconds: float, until: Callable) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.call():
			return true
	return false


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(30)
	world = main.world
	maze = world.maze
	player = world.player
	loot = world.loot
	nav = MazeNav.new(maze)
	# Everything else that hunts is put out of the way (dead, and not brought back).
	for enemy: MazeEnemy in world.enemies.enemies:
		enemy.die()
	if world.ecology:
		world.ecology._dead.clear()
	if world.griever:
		world.griever.process_mode = Node.PROCESS_MODE_DISABLED
		world.griever.visible = false
	world.caught.connect(func(_seat: int) -> void: caught.append(_seat))
	var hall := _hall_spot()
	var start: Vector3 = hall[0]
	var along: Vector3 = hall[1]
	world.put_player(start, atan2(along.x, along.z))
	player.takes_input = false
	await frames(10)

	# --- Meat cut from a carcass ---
	var carcass: Node3D = world.insects.add_carcass(start - along * 1.6, 0.4)
	await frames(10)
	check("a carcass in reach: the prompt says so", loot.carcass_near(player) == carcass and loot.prompt == "CUT MEAT FROM IT", "(%s)" % loot.prompt)
	loot.act(player)
	await frames(2)
	loot.act(player)
	await frames(2)
	var meats := []
	for i in loot.slots.size():
		var item: Node3D = loot.in_slot(i)
		if item and item.get(&"kind") == LootItem.Kind.MEAT:
			meats.append(item)
	check("two pieces of meat cut into his slots", meats.size() == 2 and int(carcass.get_meta(&"meat")) == loot.CARCASS_MEAT - 2, "(%d, %d left)" % [meats.size(), int(carcass.get_meta(&"meat", -1))])

	# --- Thrown to a hungry dog: it eats it, and is his friend ---
	world.put_player(start + along * 1.0, atan2(along.x, along.z))
	await frames(5)
	var dog := _dog_at(start + along * 9.0, atan2(-along.x, -along.z))
	dog.hunger = 0.9
	# (it neither sees nor hears him, nor goes anywhere, until it has the meat)
	dog.sight_range = 0.0
	dog.hear_range = 0.0
	dog.roam_speed = 0.0
	dog._rest_left = 999.0
	var made_friends := []
	dog.befriended.connect(func(who: Node3D) -> void: made_friends.append(who))
	await frames(10)
	# (after the world has had its first look at it, Ecology: it starts somewhere between fed and hungry)
	dog.hunger = 0.9
	loot.draw(loot.slots.find(int(meats[0].get(&"loot_id"))))
	await frames(3)
	check("the meat in his hand", player.carried == meats[0] and loot.hand == int(meats[0].get(&"loot_id")))
	player.facing_yaw = atan2(along.x, along.z)
	# (thrown with the act button, once he is free to)
	for i in 120:
		player._act()
		if player.throw_progress < 1.0:
			break
		await physics_frame
	await frames(60)
	check("thrown: out of his hand and slots", player.carried == null and not loot.slots.has(int(meats[0].get(&"loot_id"))), "(state %d, pickup %.2f, landing %.2f)" % [player.state, player.pickup_progress, player.landing_progress])
	var went := await wait(8.0, func() -> bool: return dog.mode == MazeDog.Mode.EAT)
	check("thrown, it lies; the dog smells it and goes to it", went and meats[0].get(&"loot_state") == LootItem.State.LYING, "(lies %.1f m from the dog, state %d, in meat %s, dog mode %s, dead %s, from him %.1f m)" % [meats[0].global_position.distance_to(dog.global_position), meats[0].get(&"loot_state"), str(meats[0].is_in_group(&"meat")), MazeDog.Mode.keys()[dog.mode], str(dog.dead), meats[0].global_position.distance_to(player.global_position)])
	var ate := await wait(12.0, func() -> bool: return dog.friend == player)
	check("it eats it, and is his friend", ate and made_friends == [player] and meats[0].get(&"loot_state") == LootItem.State.SPENT)
	await frames(3)
	check("its look: glad (tail up and wagging, ears up), not snarling", dog.dog.friendly and not dog.dog.snarling)

	# --- It hunts him no more, and follows him ---
	dog.sight_range = 40.0
	dog.hear_range = 11.0
	dog.roam_speed = 1.5
	dog._rest_left = 0.0
	var lunged := [false]
	var watch := func() -> void:
		if dog.mode == MazeDog.Mode.LUNGE:
			lunged[0] = true
	physics_frame.connect(watch)
	await frames(240)
	check("it does not hunt its friend", not dog.huntable(player) and not lunged[0] and caught.is_empty() and dog.mode in MazeDog.FRIEND_MODES, "(mode %s)" % MazeDog.Mode.keys()[dog.mode])
	var goal := _cell_away(maze.cell_at(player.global_position), 6)
	await _walk(goal, 3.2)
	await frames(150)
	var gap: float = dog.global_position.distance_to(player.global_position)
	check("it follows him along the halls, at heel", gap < 6.0 and not lunged[0], "(%.1f m behind)" % gap)
	await frames(300)
	check("and sits by him when he stands a while", dog.dog.sitting, "(mode %s)" % MazeDog.Mode.keys()[dog.mode])

	# --- A ghoul comes at him: the dog barks at it and goes for it ---
	var barks := [0]
	dog.dog.barked.connect(func() -> void: barks[0] += 1)
	var here := player.global_position
	var way_on := Vector3.ZERO
	for step: Vector2i in Maze.STEPS:
		var to := Vector3(step.x, 0.0, step.y)
		if nav.line_free(here, here + to * 14.0, 0.8):
			way_on = to
			break
	if way_on == Vector3.ZERO:
		way_on = along
	var ghoul := MazeGhoul.new()
	ghoul.keep_out_of_clearing = false
	var at := here + way_on * 13.0
	world.enemies.add(ghoul, maze.cell_at(at), atan2(-way_on.x, -way_on.z), 5, at - maze.world(maze.cell_at(at)))
	var warned := await wait(10.0, func() -> bool: return barks[0] > 0 and dog.mode in [MazeDog.Mode.WARN, MazeDog.Mode.GUARD, MazeDog.Mode.LUNGE])
	check("it sees the ghoul near him and barks at it", warned, "(%d barks, mode %s, ghoul chasing %s)" % [barks[0], MazeDog.Mode.keys()[dog.mode], str(ghoul.chasing)])
	var harried := await wait(14.0, func() -> bool: return Stagger.on(ghoul) or ghoul.dead)
	check("it goes for the ghoul and harries it (staggered)", harried, "(mode %s, %.1f m from it)" % [MazeDog.Mode.keys()[dog.mode], dog.global_position.distance_to(ghoul.global_position)])
	check("he was not caught meanwhile", caught.is_empty())
	ghoul.die()

	# --- A puppet sees the friendship ---
	var copy := MazeDog.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = dog.global_position
	world.add_child(copy)
	for i in 10:
		copy.from_bytes(dog.state_bytes())
		await physics_frame
	await frames(3)
	check("a puppet sees whose friend it is, and its look", copy.friend_seat == world.slot and copy.dog.friendly and not copy.chasing and not copy.huntable(player))
	copy.queue_free()

	# --- Left far behind, it goes feral ---
	dog.loyal_time = 3.0
	var feral := [false]
	dog.went_feral.connect(func() -> void: feral[0] = true)
	var far := _far_spot(dog.global_position, 60.0)
	world.put_player(far, 0.0)
	var gone := await wait(10.0, func() -> bool: return feral[0])
	check("left far behind a while, it goes feral", gone and dog.friend == null and dog.huntable(player) and not dog.dog.friendly)
	dog.die()
	physics_frame.disconnect(watch)

	# --- A dog that is not hungry takes two pieces from his hand ---
	world.put_player(start + along * 1.0, atan2(along.x, along.z))
	await frames(10)
	var full := _dog_at(player.global_position + along * 1.9, atan2(-along.x, -along.z))
	full.hunger = 0.0
	full.sight_range = 0.0
	full.hear_range = 0.0
	full.roam_speed = 0.0
	full._rest_left = 999.0
	await frames(20)
	full.hunger = 0.0
	player.facing_yaw = atan2(along.x, along.z)
	loot.draw(loot.slots.find(int(meats[1].get(&"loot_id"))))
	await frames(10)
	check("meat in his hand, a dog in front: the prompt says so", loot.prompt == "FEED THE DOG", "(%s)" % loot.prompt)
	loot.act(player)
	await frames(2)
	check("held out, the dog takes it from his hand", full.mode == MazeDog.Mode.EAT and meats[1].get(&"loot_state") == LootItem.State.SPENT and loot.hand == -1)
	await wait(5.0, func() -> bool: return full.mode != MazeDog.Mode.EAT)
	check("not hungry: one piece is not enough", full.friend == null)
	var more: Node3D = loot._place(LootItem.Kind.MEAT, player.global_position + Vector3(0.0, 0.05, 0.0), 0.0, 990001)
	await frames(10)
	loot.act(player)
	await frames(2)
	loot.draw(loot.slots.find(990001))
	await frames(5)
	player.facing_yaw = atan2(along.x, along.z)
	loot.act(player)
	await wait(5.0, func() -> bool: return full.friend != null)
	check("a second piece, and it is his friend", full.friend == player and more.get(&"loot_state") == LootItem.State.SPENT)
	full.die()

	# --- Other meat-eaters go to meat lying near them, and eat it ---
	var lured := MazeGhoul.new()
	lured.keep_out_of_clearing = false
	lured.sight_range = 0.0
	lured.hear_range = 0.0
	var spot := start + along * 8.0
	world.enemies.add(lured, maze.cell_at(spot), 0.0, 9, spot - maze.world(maze.cell_at(spot)))
	var bait: Node3D = loot._place(LootItem.Kind.MEAT, start + Vector3(0.0, maze.ground_height(start) - start.y + 0.02, 0.0), 0.0, 990002)
	world.put_player(_far_spot(start, 60.0), 0.0)
	var eaten := await wait(30.0, func() -> bool: return bait.get(&"loot_state") == LootItem.State.SPENT)
	check("a ghoul smells meat lying near it, goes to it and eats it", eaten and lured._eating > 0.0, "(%.1f m from it)" % lured.global_position.distance_to(bait.global_position))

	print("%s: %d failed" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _dog_at(at: Vector3, yaw: float) -> MazeDog:
	var dog := MazeDog.new()
	var cell := maze.cell_at(at)
	world.enemies.add(dog, cell, yaw, 3, at - maze.world(cell))
	return dog


## Walks him along the passages to `to`, at `speed`.
func _walk(to: Vector2i, speed: float) -> void:
	var path: Array = nav.path(maze.cell_at(player.global_position), to)
	for cell: Vector2i in path:
		var goal: Vector3 = nav.point(cell)
		var tries := 0
		while Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z).length() > 0.3:
			tries += 1
			if tries > 300:
				print("(stuck on the way: put there)")
				player.global_position = goal + Vector3.UP * 0.05
				break
			var step := get_root().get_physics_process_delta_time()
			var to_goal: Vector3 = goal - player.global_position
			to_goal.y = 0.0
			var move: Vector3 = to_goal.normalized() * minf(speed * step, to_goal.length())
			player.global_position += move
			player.velocity = Vector3(move.x, 0.0, move.z) / step
			await physics_frame
	player.velocity = Vector3.ZERO


## A passage cell `steps` from `from` by the passages, in the same ring.
func _cell_away(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		var cell := Vector2i(i % maze.size, i / maze.size)
		if field[i] == steps and maze.ring_of(cell) == maze.ring_of(from):
			return cell
	return from


## A spot in the maze's halls at least `apart` from `from`.
func _far_spot(from: Vector3, apart: float) -> Vector3:
	for cell: Vector2i in nav.lairs(3):
		var at := nav.point(cell)
		if at.distance_to(from) > apart:
			return at + Vector3.UP * 0.05
	return from + Vector3(apart, 0.0, 0.0)


## Somewhere in the first ring's halls to stand: [where, the way along the hall (open for 12 m)].
func _hall_spot() -> Array:
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or not nav.allowed(cell) or maze.solid.has(cell):
			continue
		for step: Vector2i in Maze.STEPS:
			var way := Vector3(step.x, 0.0, step.y)
			var p := nav.point(cell)
			if nav.line_free(p - way * 2.5, p + way * 12.0, 1.0):
				return [p + Vector3.UP * 0.05, way]
	return [Vector3.ZERO, Vector3.FORWARD]
