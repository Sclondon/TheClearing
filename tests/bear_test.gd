extends SceneTree
## The screaming bear (scripts/enemies/maze_bear.gd on creatures/bear),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In
## turn: alone, it prowls slowly and calls out in its stolen voice; it sees
## him down a hall and stalks him, slower than a run; in a line, it rears and
## screams (the warning), then charges faster than a sprint, but briefly;
## standing there he is swiped, flung down and caught, and it mauls him and
## takes his voice; stepping back out of a swipe's reach as it winds up, he is
## missed; up out of its reach it rears and screams under him and gives up;
## killing a creature it takes an animal's voice; its cries are made a little
## at a time; a puppet follows what the host sends, and plays its cries.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/bear_test.gd
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


func put_boy(at: Vector3) -> void:
	if boy.is_limp:
		boy.recover()
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func bear_at(at: Vector3, yaw := 0.0, puppet := false) -> MazeBear:
	var bear := MazeBear.new()
	bear.maze = maze
	bear.puppet = puppet
	bear.position = at + Vector3.UP * 0.05
	bear.rotation.y = yaw
	stage.add_child(bear)
	bear.caught.connect(func(player: Node3D) -> void: caught_by.append([player, bear]))
	return bear


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


func mode_name(bear: MazeBear) -> String:
	return MazeBear.Mode.keys()[bear.mode]


func _run() -> void:
	await frames(10)
	# A long straight hall ending in a wall.
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	var length := 0
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run >= 4 and maze.blocked(at, s) and run > length:
				hall = cell
				step = s
				length = run
	check("a long straight hall", hall.x >= 0, "(%d cells)" % length)
	var way := Vector3(step.x, 0.0, step.y)
	var start: Vector3 = maze.world(hall)
	var facing := atan2(way.x, way.z)
	var far_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 10:
			far_cell = cell
			break

	# --- Alone, it prowls slowly and calls out ---
	put_boy(maze.world(far_cell))
	var bear := bear_at(start, facing)
	bear.prowl_calls = Vector2(0.5, 1.0)
	bear._call_in = 0.5
	var calls := [0]
	bear.bear.called.connect(func(_which: int) -> void: calls[0] += 1)
	await frames(150)
	# (its cries are made over its first frames: it calls once they are)
	await wait(12.0, func() -> bool: return calls[0] > 0)
	check("alone, it prowls", bear.mode in [MazeBear.Mode.PROWL, MazeBear.Mode.SNIFF], "(%s)" % mode_name(bear))
	var moved: float = bear.global_position.distance_to(start)
	check("slowly, slower than a walk", moved > 0.3 and moved < 1.6 * 2.5, "(%.1f m in 2.5 s)" % moved)
	check("and calls out in its stolen voice", calls[0] >= 1, "(%d calls)" % calls[0])
	check("its voice is a person's", bear.voice >= 0 and bear.voice < BearVoice.BEAST and bear.bear.voice == bear.voice)
	await clear()

	# --- It sees him down the hall and stalks him ---
	put_boy(start + way * 24.0)
	bear = bear_at(start, facing)
	bear.charge_reach = 0.0
	var stalking := await wait(3.0, func() -> bool: return bear.mode == MazeBear.Mode.STALK)
	check("it sees him down the hall and stalks him", stalking, "(%s, %.0f m)" % [mode_name(bear), bear.global_position.distance_to(boy.global_position)])
	var top := 0.0
	for i in 120:
		await physics_frame
		top = maxf(top, Vector2(bear.velocity.x, bear.velocity.z).length())
	check("slow and heavy: faster than a walk, slower than a run", top > boy.walk_speed and top < boy.run_speed, "(%.1f m/s)" % top)
	await clear()

	# --- In a line: it rears and screams, then charges; standing there he is swiped and caught ---
	put_boy(start + way * 11.0)
	bear = bear_at(start, facing)
	var screams := [0]
	var swipes := [0]
	bear.bear.screamed.connect(func() -> void: screams[0] += 1)
	bear.bear.swiped.connect(func() -> void: swipes[0] += 1)
	var rearing := await wait(3.0, func() -> bool: return bear.mode == MazeBear.Mode.REAR)
	check("with him in a line 11 m off, it winds up", rearing, "(%s)" % mode_name(bear))
	await wait(0.9)
	check("it rears on its hind legs and screams (the warning)", bear.bear.rearing and screams[0] == 1 and caught_by.is_empty(), "(rearing %s, %d screams)" % [bear.bear.rearing, screams[0]])
	var charging := await wait(2.0, func() -> bool: return bear.mode == MazeBear.Mode.CHARGE)
	check("then it charges", charging, "(%s)" % mode_name(bear))
	var fastest := [0.0]
	var limp := [false]
	var caught := await wait(4.0, func() -> bool:
		if OS.has_environment("BEAR_DEBUG"):
			print("%s %.2f %.1f" % [mode_name(bear), Vector2(bear.velocity.x, bear.velocity.z).length(), bear.global_position.distance_to(boy.global_position)])
		fastest[0] = maxf(fastest[0], Vector2(bear.velocity.x, bear.velocity.z).length())
		limp[0] = limp[0] or boy.is_limp
		return not caught_by.is_empty())
	check("faster than a sprint", fastest[0] > boy.sprint_speed, "(%.1f m/s)" % fastest[0])
	check("standing there, he is swiped, flung down and caught", caught and limp[0] and swipes[0] >= 1 and caught_by[0][0] == boy, "(limp %s, %d swipes, caught %d)" % [limp[0], swipes[0], caught_by.size()])
	check("it mauls him", bear.mode == MazeBear.Mode.MAUL, "(%s)" % mode_name(bear))
	check("and takes his voice", bear.voice == MazeBear.voice_of(boy) and bear.bear.voice == bear.voice, "(%d)" % bear.voice)
	await wait(0.8)
	check("the mauling is shown", bear.bear.mauling)
	await clear()

	# --- The charge is short ---
	put_boy(start + way * 12.0)
	bear = bear_at(start, facing)
	bear.swipe_reach = 0.0
	charging = await wait(4.0, func() -> bool: return bear.mode == MazeBear.Mode.CHARGE)
	var from: Vector3 = bear.global_position
	# (he runs off down the hall as it comes)
	put_boy(start + way * Maze.CELL * (length - 0.4))
	var spent := await wait(3.0, func() -> bool: return bear.mode == MazeBear.Mode.RECOVER)
	var went: float = bear.global_position.distance_to(from)
	check("the charge is short, then it stands blowing", charging and spent and went < 14.0, "(%.1f m, %s)" % [went, mode_name(bear)])
	await clear()

	# --- Stepping back out of reach as it winds up its swipe, he is missed ---
	put_boy(start + way * 3.2)
	bear = bear_at(start, facing)
	var winding := await wait(2.0, func() -> bool: return bear.mode == MazeBear.Mode.SWIPE)
	check("close in front of it, it winds up a swipe", winding, "(%s)" % mode_name(bear))
	put_boy(start + way * 9.0)
	await wait(1.2)
	check("he steps back out of reach: missed", caught_by.is_empty(), "(caught %d)" % caught_by.size())
	await clear()

	# --- Up out of its reach, it rears and screams under him, and gives up ---
	var perch := Node3D.new()
	stage.add_child(perch)
	perch.global_position = start + Vector3.UP * 5.0 + way * 5.0
	put_boy(maze.world(far_cell))
	bear = bear_at(start, facing)
	bear.targets = [perch]
	bear.baffled_time = 4.0
	screams[0] = 0
	bear.bear.screamed.connect(func() -> void: screams[0] += 1)
	var baffled := false
	var charged := false
	for i in 9 * 60:
		await physics_frame
		baffled = baffled or bear.mode == MazeBear.Mode.BAFFLED
		charged = charged or bear.mode in [MazeBear.Mode.CHARGE]
	check("someone up high: it rears and screams under them, never charges, and gives up", baffled and screams[0] >= 1 and not charged and not bear.hunting() and caught_by.is_empty(), "(%s, %d screams)" % [mode_name(bear), screams[0]])
	perch.queue_free()
	await clear()

	# --- Killing a creature, it takes an animal's voice ---
	put_boy(maze.world(far_cell))
	bear = bear_at(start, facing)
	await frames(5)
	bear.ate(5.0)
	await frames(3)
	check("having killed a creature it mauls it and takes an animal's voice", bear.mode == MazeBear.Mode.MAUL and bear.voice == BearVoice.BEAST, "(%s, %d)" % [mode_name(bear), bear.voice])
	if Ecology.KINDS.has("MazeBear"):
		check("it is among the world's meat-eaters, the biggest", Ecology.bulk(bear) == 4 and Ecology.diet(bear) == Ecology.Diet.MEAT)
		await clear()
		# (a hungry bear and a deer down the hall: it hunts it, the deer runs, it kills it)
		var world := Ecology.put(stage, 1, null)
		await frames(5)
		bear = bear_at(start, facing)
		var deer := MazeDeer.new()
		deer.maze = maze
		deer.position = start + way * 14.0 + Vector3.UP * 0.05
		stage.add_child(deer)
		await frames(5)
		bear.hunger = 1.0
		var hunted := await wait(3.0, func() -> bool: return bear.quarry == deer)
		check("hungry, it goes after a deer it sees", hunted, "(%s)" % mode_name(bear))
		var ran := await wait(3.0, func() -> bool: return deer.threat == bear)
		check("the deer runs from it", ran)
		var killed := await wait(40.0, func() -> bool: return deer.dead)
		check("it kills the deer", killed, "(%d kills, %s)" % [world.kills, mode_name(bear)])
		await frames(3)
		check("and mauls it, and takes its cry", bear.mode == MazeBear.Mode.MAUL and bear.voice == BearVoice.BEAST, "(%s, %d)" % [mode_name(bear), bear.voice])
		deer.queue_free()
		world.queue_free()
	else:
		print("NOTE: MazeBear is not in Ecology.KINDS yet (add \"MazeBear\": [4, Diet.MEAT])")
	await clear()

	# --- Its cries are made a little at a time ---
	# (a voice none of the bears so far has had)
	var fresh := -1
	for speaker in BearVoice.SPEAKERS:
		if not BearVoice.is_ready(BearVoice.CALL_HELP, speaker) and BearVoice._find(BearVoice._key(BearVoice.CALL_HELP, speaker)) == null:
			fresh = speaker
			break
	if fresh < 0:
		print("SKIP: every voice is made already (the bears so far have had them all)")
	else:
		var slices := 0
		var worst := 0
		while not BearVoice.is_ready(BearVoice.SOB, fresh) and slices < 2000:
			var began := Time.get_ticks_usec()
			BearVoice.work(1500)
			worst = maxi(worst, Time.get_ticks_usec() - began)
			slices += 1
			await process_frame
		check("a new voice's cries are made over many frames, a little each", BearVoice.is_ready(BearVoice.CALL_HELP, fresh) and BearVoice.is_ready(BearVoice.SOB, fresh) and slices > 5 and worst < 12000, "(%d frames, at most %.1f ms)" % [slices, worst / 1000.0])
	var scream := BearVoice.cry(BearVoice.SCREAM, 1)
	check("its cries are made: a long scream", scream.data.size() / 2.0 / BearVoice.RATE > 2.0)
	check("and always the same", BearVoice.cry(BearVoice.SCREAM, 1) == scream)

	# --- A puppet follows the host and plays its cries ---
	put_boy(start + way * 11.0)
	var host := bear_at(start, facing)
	host.sight_range = 0.0
	host.smell_range = 0.0
	host.prowl_calls = Vector2(0.6, 0.8)
	host._call_in = 0.3
	var copy := bear_at(start, facing, true)
	var copied := [0, 0]
	copy.bear.called.connect(func(_which: int) -> void: copied[0] += 1)
	copy.bear.screamed.connect(func() -> void: copied[1] += 1)
	var furthest := 0.0
	for i in 420:
		await physics_frame
		if i == 120:
			host.sight_range = 30.0
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", furthest < 3.0, "(at most %.2f m off)" % furthest)
	check("the puppet calls and screams when the host does", copied[0] >= 1 and copied[1] >= 1, "(%d calls, %d screams)" % [copied[0], copied[1]])
	check("in the host's voice", copy.voice == host.voice and copy.bear.voice == host.voice)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
