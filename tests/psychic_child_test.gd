extends SceneTree
## The psychic child (scripts/enemies/maze_psychic_child.gd on creatures/
## psychic_child), headless, in a bare scene: a maze from MazeBuilder and the
## boy in it. In turn: alone, she drifts slowly and catches nobody; someone who
## walks up to her and stays calm she lets near and then follows; whoever she
## watches over she guards: a dog after him is taken hold of, lifted and
## slammed down, and forgets him; each hold costs her (she stays shaken), and
## several in a row break her; someone sprinting past startles her, the warning
## builds, whoever is right by her is lifted and held, and the burst throws
## everyone near (a catch for the one held, a throw for one further off) and
## flings the creatures; she sits drained and then drifts again; left alone,
## her distress falls, faster when you back slowly off; bumping into her
## startles her at once; a puppet follows the host, holds what it holds, and
## bursts when it does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/psychic_child_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var far_boy
var dummy: CharacterBody3D
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
	far_boy = load("res://player.tscn").instantiate()
	far_boy.name = "Runner"
	far_boy.takes_input = false
	stage.add_child(far_boy)
	far_boy.add_to_group(&"runners")
	# Someone to run about by hand (a body, its speed set by the test)
	dummy = CharacterBody3D.new()
	dummy.name = "Dummy"
	dummy.collision_layer = 0
	dummy.collision_mask = 0
	stage.add_child(dummy)
	_run.call_deferred()


func put(who: Node3D, at: Vector3) -> void:
	if who.get(&"is_limp") == true:
		who.call(&"recover")
	who.global_position = at + Vector3.UP * 0.1
	if who is CharacterBody3D:
		(who as CharacterBody3D).velocity = Vector3.ZERO


func child_at(at: Vector3, targets: Array) -> MazePsychicChild:
	var child := MazePsychicChild.new()
	child.maze = maze
	child.position = at + Vector3.UP * 0.05
	child.targets = targets
	child.seed_choices(5)
	stage.add_child(child)
	child.caught.connect(func(player: Node3D) -> void: caught_by.append([player, child]))
	return child


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	for who: Node3D in [boy, far_boy]:
		var held := who.get_node_or_null(^"PsychicHeld")
		if held:
			held.queue_free()
		if who.is_limp:
			who.recover()
	await frames(3)


func mode_name(child: MazePsychicChild) -> String:
	return MazePsychicChild.Mode.keys()[child.mode]


func _run() -> void:
	await frames(10)
	# A long straight hall
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	var length := 0
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 7 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run > length:
				hall = cell
				step = s
				length = run
	check("a long straight hall", hall.x >= 0 and length >= 4, "(%d cells)" % length)
	var way := Vector3(step.x, 0.0, step.y)
	var start: Vector3 = maze.world(hall)
	var middle: Vector3 = start + way * Maze.CELL * 1.0
	var aside := Vector3(-way.z, 0.0, way.x)
	var away_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 10:
			away_cell = cell
			break
	put(far_boy, maze.world(away_cell) + Vector3(3.0, 0.0, 0.0))

	# --- Alone, she drifts ---
	put(boy, maze.world(away_cell))
	var child := child_at(middle, [boy])
	await frames(180)
	var moved: float = child.global_position.distance_to(middle)
	check("alone, she drifts about", child.mode == MazePsychicChild.Mode.DRIFT, "(%s)" % mode_name(child))
	check("slowly", moved > 0.3 and moved < 3.5, "(%.1f m in 3 s)" % moved)
	check("she catches nobody, and nothing troubles her", caught_by.is_empty() and child.distress < 0.05)
	check("she is drawn floating, humming", child.figure.humming and not child.figure.drained)

	# --- Come up to her slowly and stay: she lets you near, and follows you ---
	put(boy, child.global_position + way * 3.0)
	child.follow_after = 3.0
	var follows := await wait(6.0, func() -> bool: return child.followed == boy)
	check("standing calm near her, she takes to him and follows him", follows and child.distress < 0.2, "(followed %s, distress %.2f)" % [child.followed, child.distress])
	check("she watches over him", boy in child.wards)
	put(boy, child.global_position + way * 8.0)
	var from: Vector3 = child.global_position
	await frames(150)
	var came: float = (child.global_position - from).dot(way)
	check("he walks on: she comes after him", came > 1.5, "(%.1f m)" % came)
	check("without hurry, and never right on top of him", child.global_position.distance_to(boy.global_position) > 1.5)

	# --- She guards him: a dog after him is taken hold of ---
	var dog := MazeDog.new()
	dog.maze = maze
	dog.position = boy.global_position + way * 9.0 + Vector3.UP * 0.05
	dog.targets = [boy]
	stage.add_child(dog)
	dog.caught.connect(func(player: Node3D) -> void: caught_by.append([player, dog]))
	await frames(2)
	dog.notice(boy)
	var top := [dog.global_position.y]
	var seized := await wait(4.0, func() -> bool:
		top[0] = maxf(top[0], dog.global_position.y)
		return child.mode == MazePsychicChild.Mode.GUARD)
	check("a dog comes after him: she takes hold of it", seized and child.held_thing == dog, "(%s)" % mode_name(child))
	check("her arm out at it, the air warped round it", child.figure.reaching and child.figure.reach_at.is_finite())
	await wait(1.0, func() -> bool:
		top[0] = maxf(top[0], dog.global_position.y)
		return false)
	var lifted: float = top[0] - boy.global_position.y
	check("it is lifted off the ground, held", lifted > 0.7, "(%.2f m up)" % lifted)
	check("and has forgotten him", dog.quarry == null)
	var done := await wait(4.0, func() -> bool: return child.mode != MazePsychicChild.Mode.GUARD)
	check("then slammed down (no Ecology here: left stunned), and she lets go", done and child.held_thing == null and (child.kills > 0 or dog.get_node_or_null(^"Seized") != null or dog.is_physics_processing()), "(%s, kills %d)" % [mode_name(child), child.kills])
	check("the dog caught nobody", caught_by.all(func(c: Array) -> bool: return c[1] != dog))
	check("it cost her: she is shaken", child.distress > 0.15, "(distress %.2f)" % child.distress)
	await frames(120)
	check("and does not calm for a while", child.distress > 0.15, "(distress %.2f)" % child.distress)
	dog.queue_free()
	await clear()

	# --- Several in a row break her ---
	put(boy, middle + way * 3.0)
	child = child_at(middle, [boy])
	child.follow_after = 0.5
	child.drained_time = 2.0
	await wait(2.0, func() -> bool: return child.followed == boy)
	var dogs: Array = []
	for k in 3:
		var one := MazeDog.new()
		one.maze = maze
		one.position = boy.global_position + way * (8.0 + k * 1.5) + aside * (k - 1) * 0.8 + Vector3.UP * 0.05
		one.targets = [boy]
		stage.add_child(one)
		dogs.append(one)
	await frames(2)
	for one: MazeDog in dogs:
		one.notice(boy)
	var broke := await wait(14.0, func() -> bool: return child.mode in [MazePsychicChild.Mode.DISTRESS, MazePsychicChild.Mode.BURST])
	check("three dogs, one after another: she holds them, and breaks", broke and child.guards >= 2, "(%s, %d holds, distress %.2f)" % [mode_name(child), child.guards, child.distress])
	await wait(4.0, func() -> bool: return child.mode == MazePsychicChild.Mode.DRAINED)
	check("then the burst, and she is drained", child.bursts == 1 and child.mode == MazePsychicChild.Mode.DRAINED, "(%s)" % mode_name(child))
	for one: MazeDog in dogs:
		one.queue_free()
	await clear()

	# --- Startled: sprinting past her ---
	put(boy, middle + way * 1.5)
	put(far_boy, middle + way * 6.0 + aside * 0.5)
	put(dummy, middle - way * 9.0 + aside * 1.0)
	child = child_at(middle, [boy, far_boy, dummy])
	child.drained_time = 2.5
	await frames(30)
	var was_upset := [false]
	var committed := await wait(4.0, func() -> bool:
		dummy.velocity = way * 5.6
		dummy.global_position += way * 5.6 / 60.0
		was_upset[0] = was_upset[0] or child.mode == MazePsychicChild.Mode.UPSET
		return child.mode == MazePsychicChild.Mode.DISTRESS)
	dummy.velocity = Vector3.ZERO
	check("someone sprints past her: she is upset", was_upset[0])
	check("past the point of no return it builds on", committed, "(%s, %.2f)" % [mode_name(child), child.distress])
	var warned := await wait(0.6, func() -> bool: return child.figure.distress > 0.5)
	check("the warning is shown: warp, things racing round her, hands to her head", warned and child.figure._haze.visible)
	var held_up := await wait(1.0, func() -> bool: return boy.get_node_or_null(^"PsychicHeld") != null)
	await frames(30)
	var up_at := -1.0
	if boy.is_limp:
		up_at = (boy.get("_rig").get("_limbs")[1][1] as Node3D).global_position.y - child.global_position.y
	check("the boy right by her is lifted into the air and held", held_up and boy.is_limp and up_at > 1.3, "(limp %s, chest %.2f m up)" % [boy.is_limp, up_at])
	check("the one further off is not", far_boy.get_node_or_null(^"PsychicHeld") == null and not far_boy.is_limp)
	var burst := await wait(2.0, func() -> bool: return child.mode == MazePsychicChild.Mode.BURST)
	check("then the burst", burst and child.bursts == 1)
	await frames(10)
	check("everyone near is thrown", boy.is_limp and far_boy.is_limp, "(boy %s, other %s)" % [boy.is_limp, far_boy.is_limp])
	var landed := await wait(2.5, func() -> bool: return caught_by.any(func(c: Array) -> bool: return c[0] == boy))
	check("the one she held is caught", landed)
	await frames(90)
	check("the one further off is only thrown: not caught, and stood up again", not caught_by.any(func(c: Array) -> bool: return c[0] == far_boy) and not far_boy.is_limp)
	check("drained, she sits", child.mode == MazePsychicChild.Mode.DRAINED and child.figure.drained)
	var again := await wait(4.0, func() -> bool: return child.mode == MazePsychicChild.Mode.DRIFT)
	check("then she drifts again", again, "(%s)" % mode_name(child))
	await clear()

	# --- Calming ---
	put(boy, maze.world(away_cell))
	put(far_boy, maze.world(away_cell) + Vector3(2.0, 0.0, 0.0))
	put(dummy, middle + way * 3.0)
	child = child_at(middle, [dummy])
	await frames(5)
	child.distress = 0.45
	child.mode = MazePsychicChild.Mode.UPSET
	await frames(60)
	var alone_left: float = child.distress
	child.distress = 0.45
	for i in 60:
		dummy.velocity = way * 1.0
		dummy.global_position += way * 1.0 / 60.0
		await physics_frame
	var backed: float = child.distress
	dummy.velocity = Vector3.ZERO
	check("left be, her distress falls", alone_left < 0.45 and child.mode != MazePsychicChild.Mode.DISTRESS, "(%.2f)" % alone_left)
	check("faster when he backs slowly off", backed < alone_left - 0.05, "(%.2f against %.2f)" % [backed, alone_left])
	await clear()

	# --- Bumping into her ---
	put(dummy, middle + way * 3.0)
	child = child_at(middle, [dummy])
	await frames(10)
	var bumped := await wait(3.0, func() -> bool:
		var to: Vector3 = child.global_position - dummy.global_position
		to.y = 0.0
		dummy.velocity = to.normalized() * 1.6
		if to.length() > 0.3:
			dummy.global_position += to.normalized() * 1.6 / 60.0
		return child.mode == MazePsychicChild.Mode.DISTRESS)
	check("walking into her startles her at once", bumped, "(%s, %.2f)" % [mode_name(child), child.distress])
	await clear()

	# --- A puppet follows the host, holds what it holds and bursts when it does ---
	put(boy, middle + way * 3.0)
	var host := child_at(middle, [boy])
	host.follow_after = 0.5
	var copy := MazePsychicChild.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	copy.targets = [boy]
	stage.add_child(copy)
	var furthest := 0.0
	var copy_dog := MazeDog.new()
	copy_dog.maze = maze
	copy_dog.position = boy.global_position + way * 9.0 + Vector3.UP * 0.05
	copy_dog.targets = [boy]
	var gripped := false
	var copied_burst := false
	for i in 600:
		await physics_frame
		if i == 120:
			stage.add_child(copy_dog)
		if i == 125:
			copy_dog.notice(boy)
		if i == 330:
			host.distress = 0.7
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		gripped = gripped or (copy.mode == MazePsychicChild.Mode.GUARD and copy._gripped != null)
		copied_burst = copied_burst or copy.figure.busy()
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", furthest < 2.5, "(at most %.2f m off)" % furthest)
	check("the puppet shows what the host holds, held", gripped, "(host holds %d)" % host.guards)
	check("the puppet bursts when the host does", copied_burst and host.bursts >= 1)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	copy_dog.queue_free()
	await clear()

	# --- With the world's own life (Ecology, if the game has it): she kills ---
	var eco_path := ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == &"Ecology":
			eco_path = entry["path"]
	if eco_path == "":
		print("(no Ecology in this game: its kills are not tried)")
	else:
		var world: Node = load(eco_path).new()
		stage.add_child(world)
		put(boy, middle + way * 3.0)
		child = child_at(middle, [boy])
		child.follow_after = 0.5
		await wait(2.0, func() -> bool: return child.followed == boy)
		var prey := MazeDog.new()
		prey.maze = maze
		prey.position = boy.global_position + way * 9.0 + Vector3.UP * 0.05
		prey.targets = [boy]
		stage.add_child(prey)
		await frames(2)
		prey.notice(boy)
		var killed := await wait(6.0, func() -> bool: return prey.get(&"dead") == true)
		check("a dog after him she slams down, and it is killed (Ecology)", killed and child.kills == 1, "(kills %d)" % child.kills)
		check("she was not hunted by anything: nothing eats her", world.call(&"threat_to", child) == null and not world.call(&"is_prey", child, prey))
		await clear()
		# The burst kills what is near her
		put(dummy, middle + way * 3.0)
		child = child_at(middle, [dummy])
		var near_dog := MazeDog.new()
		near_dog.maze = maze
		near_dog.position = middle + way * 3.0 + aside * 0.5 + Vector3.UP * 0.05
		near_dog.targets = [far_boy]
		stage.add_child(near_dog)
		await frames(5)
		child.distress = 0.7
		var gone := await wait(4.0, func() -> bool: return near_dog.get(&"dead") == true)
		check("her burst kills a creature near her (Ecology)", gone and child.bursts == 1)
		await clear()
		world.queue_free()

	# --- The component's example goes round its loop ---
	var example: Node3D = load("res://creatures/psychic_child/example.gd").new()
	example.position = Vector3(0.0, -200.0, 0.0)
	stage.add_child(example)
	var steps := {}
	while float(example.get(&"_time")) < 22.0:
		await process_frame
		steps[example.get(&"step")] = true
	check("the component's example goes round its loop", steps.has("reach") and steps.has("burst") and steps.has("drained") and steps.has("back"), "(%s)" % ", ".join(steps.keys()))
	example.queue_free()

	# --- In a real round, among everything else that is in the maze ---
	stage.queue_free()
	await frames(3)
	var round_world: Node3D = load("res://scripts/world.gd").new()
	round_world.name = "World"
	root.add_child(round_world)
	round_world.setup(Maze.seed_for("TEST", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var them: Node = round_world.get(&"enemies")
	var plan: Maze = round_world.get(&"maze")
	var round_nav := MazeNav.new(plan)
	var spot: Vector2i = round_nav.lairs(3)[0]
	var in_round: MazePsychicChild = them.call(&"add", MazePsychicChild.new(), spot, 0.0, 7)
	var me: Node3D = round_world.get(&"player")
	me.set(&"takes_input", false)
	me.global_position = plan.world(spot) + Vector3(2.5, 0.1, 0.0)
	var lived := 0.0
	while lived < 8.0:
		await physics_frame
		lived += 1.0 / 60.0
	check("in a real round she goes about among the rest", is_instance_valid(in_round) and in_round.mode in [MazePsychicChild.Mode.DRIFT, MazePsychicChild.Mode.FOLLOW, MazePsychicChild.Mode.GUARD, MazePsychicChild.Mode.UPSET], "(%s)" % mode_name(in_round))
	round_world.queue_free()
	await frames(3)

	# --- Her sounds are made ---
	check("her sounds are made", PsychicChild.hum_sound().data.size() > 1000 and PsychicChild.ring_sound().data.size() > 1000 and PsychicChild.burst_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
