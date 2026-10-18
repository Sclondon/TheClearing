extends SceneTree
## The red foxes (scripts/enemies/maze_fox.gd on creatures/fox), headless, in a
## bare scene: a maze from MazeBuilder and the boy in it. In turn: one that
## sees him looks and follows him at a distance, sits and watches when he turns
## to it, and runs when he runs at it, and never catches him; one takes a map
## lying a few metres from him, carries it off and drops it well away; a
## hungry one (with the world's life, Ecology) stalks a colony of frogs,
## pounces and eats one; the mousing pounce goes up and comes down where it
## was aimed; a puppet follows what the host sends (its mode, its pounce, its
## barks, what it carries).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/fox_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Node3D
var failures := 0
var caught := 0


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


func fox_at(at: Vector3, seed_value := 5, puppet := false) -> MazeFox:
	var one := MazeFox.pair_of(1, seed_value)[0]
	one.maze = maze
	one.puppet = puppet
	one.seed_choices(seed_value)
	one.position = at + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(_who: Node3D) -> void: caught += 1)
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child is MazePondFrogs.Keeper or child is LootItem or child is Ecology:
			child.queue_free()
	await frames(3)


func _run() -> void:
	await frames(10)
	var hall := long_hall()
	var first: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var start := nav.point(first)
	print("a hall of %d cells" % hall[2])

	# --- Curious: looks, follows, sits and watches, runs when run at ---
	var fox := fox_at(start)
	put_boy(start + way * 24.0, atan2(way.x, way.z))
	var following := await wait(8.0, func() -> bool: return fox.mode in [MazeFox.Mode.LOOK, MazeFox.Mode.FOLLOW])
	check("a fox that sees him looks and follows", following, "(mode %d)" % fox.mode)
	# He walks on down the hall, away from it: it follows, keeping its distance.
	var nearest := INF
	for i in 300:
		boy.global_position += way * 1.5 / 60.0
		boy.velocity = way * 1.5
		await physics_frame
		nearest = minf(nearest, fox.global_position.distance_to(boy.global_position))
	var gap := fox.global_position.distance_to(boy.global_position)
	check("it follows at a distance", gap < 30.0 and nearest > fox.flee_range, "(%.1f m now, nearest %.1f m)" % [gap, nearest])
	# He turns and looks at it: it sits and watches.
	boy.velocity = Vector3.ZERO
	var to_fox := fox.global_position - boy.global_position
	boy.facing_yaw = atan2(to_fox.x, to_fox.z)
	var watching := await wait(5.0, func() -> bool: return fox.mode == MazeFox.Mode.WATCH)
	check("looked at, it sits and watches", watching and fox.fox.sitting, "(mode %d)" % fox.mode)
	# He runs at it.
	var fled := false
	for i in 240:
		var to: Vector3 = fox.global_position - boy.global_position
		to.y = 0.0
		boy.global_position += to.normalized() * 4.6 / 60.0
		boy.velocity = to.normalized() * 4.6
		boy.facing_yaw = atan2(to.x, to.z)
		await physics_frame
		if fox.mode in [MazeFox.Mode.FLEE, MazeFox.Mode.SLIP]:
			fled = true
			break
	check("run at, it runs", fled, "(mode %d)" % fox.mode)
	await frames(60)
	check("it never catches anyone, and is no pursuer", caught == 0 and not fox.is_in_group(&"pursuers"))
	await clear()

	# --- A thief ---
	fox = fox_at(start)
	put_boy(start + way * 16.0, atan2(-way.x, -way.z))
	var map := LootItem.make(LootItem.Kind.MAP)
	stage.add_child(map)
	var lay := start + way * 11.0
	map.call(&"lay_at", lay, 0.0)
	await frames(30)
	fox._steal_in = 0.0
	fox.mode = MazeFox.Mode.FOLLOW
	var took := await wait(10.0, func() -> bool: return fox.mode == MazeFox.Mode.CARRY)
	check("it goes for the map lying near him, and takes it", took, "(mode %d)" % fox.mode)
	await frames(30)
	check("it carries it in its jaws", fox.fox.carrying and map.global_position.distance_to(fox.fox.jaw_position()) < 0.2)
	# A puppet of it carries the same thing.
	var copy := fox_at(fox.global_position, 5, true)
	for i in 20:
		copy.from_bytes(fox.state_bytes())
		await physics_frame
	check("a puppet knows what it carries", copy.loot_item == map, "(%s)" % copy.loot_item)
	copy.queue_free()
	var dropped := await wait(25.0, func() -> bool: return fox.mode != MazeFox.Mode.CARRY)
	await frames(5)
	check("it drops it well away from where it lay", dropped and map.global_position.distance_to(lay) > 8.0 and int(map.get(&"loot_state")) == 0, "(%.1f m off)" % map.global_position.distance_to(lay))
	await clear()

	# --- The mousing pounce ---
	boy.global_position = start + way * 60.0 + Vector3.UP * 40.0
	fox = fox_at(start)
	await frames(20)
	var aim := fox.global_position + way * 3.0
	fox._pounce(aim)
	var high := 0.0
	for i in 150:
		await physics_frame
		high = maxf(high, fox.fox.pounce_lift())
	var landed := Vector2(fox.global_position.x - aim.x, fox.global_position.z - aim.z).length()
	check("the pounce goes up high and comes down where it was aimed", high > 0.5 and landed < 1.0, "(%.2f m up, %.2f m off)" % [high, landed])
	await clear()

	# --- A hunter of small things (the world's life) ---
	if Ecology.KINDS.has("MazeFox") and Ecology.KINDS.has("MazePondFrogs"):
		# (nobody about: only the fox and the frogs)
		boy.remove_from_group(&"maze_players")
		var world := Ecology.put(stage, 11)
		var frogs := MazePondFrogs.new()
		frogs.maze = maze
		frogs.position = start + way * 14.0
		stage.add_child(frogs)
		fox = fox_at(start)
		await frames(5)
		var ate := false
		var seen := {"stalked": false, "pounced": false}
		for attempt in 4:
			fox.hunger = 1.0
			var end := await wait(25.0, func() -> bool:
				seen["stalked"] = seen["stalked"] or fox.mode == MazeFox.Mode.STALK
				seen["pounced"] = seen["pounced"] or fox.mode == MazeFox.Mode.POUNCE
				return frogs.dead)
			print("  attempt %d: mode %d, after %s, hunger %.2f, frogs out %d, escaped %s" % [attempt, fox.mode, fox.quarry, fox.hunger, frogs.colony.out(), frogs.escaped])
			if end:
				ate = true
				break
			# (they all went in: wait for them to come out again)
			fox.global_position = start
			await wait(20.0)
		check("hungry, it stalks and pounces on the frogs", seen["stalked"] and seen["pounced"])
		check("and eats one", ate and world.kills > 0, "(kills %d)" % world.kills)
		var gone := 0
		for i in frogs.colony.count:
			if frogs.colony.frog_state(i) == PondFrogs.GONE:
				gone += 1
		check("the one it ate is gone from the pond", gone == 1, "(%d gone)" % gone)
		boy.add_to_group(&"maze_players")
		await clear()
	else:
		print("SKIP: the fox and the frogs hunted and eaten (Ecology.KINDS has no MazeFox or MazePondFrogs yet)")

	# --- A puppet ---
	fox = fox_at(start)
	var puppet := fox_at(start + Vector3.RIGHT * 0.5, 5, true)
	await frames(10)
	puppet.from_bytes(fox.state_bytes())
	await physics_frame
	fox._pounce(fox.global_position + way * 3.0)
	fox._barks += 1
	var pounced_too := false
	var heard := {"barked": false}
	puppet.fox.barked.connect(func() -> void: heard["barked"] = true)
	for i in 90:
		puppet.from_bytes(fox.state_bytes())
		await physics_frame
		pounced_too = pounced_too or puppet.fox.pouncing()
	check("a puppet pounces when its host does", pounced_too)
	check("and barks when it does", heard["barked"])
	await clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
