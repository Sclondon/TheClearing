extends SceneTree
## The rabbits, hares and jackalopes (scripts/enemies/maze_rabbit.gd,
## maze_hare.gd and maze_jackalope.gd on creatures/rabbit), headless, in a bare
## scene: a maze from MazeBuilder and the boy in it. In turn:
## - a colony: the same from the same seed; its warren against a hall's wall,
##   its holes; they graze round it;
## - he comes into sight: they sit up and watch; nearer: one thumps and they
##   all bolt down their holes, out of sight, out of reach, doing nothing;
## - he goes away: they come up, look, and come out to graze; at night they
##   stay down; something that would eat them sends them down too;
## - a puppet rabbit follows its host, down its hole too;
## - a hare in the clearing freezes flat as he comes, is flushed close by and
##   is away, jinking, faster than he can run; a pair box;
## - the jackalope stares, and turns on him close by: grunts, charges, butts
##   him down (he gets up again) without catching him, and is away;
## - out past the square maze a colony keeps to open ground; the sounds.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/rabbit_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var holder
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
	holder = MazeEnemies.new()
	holder.name = "Enemies"
	holder.maze = maze
	stage.add_child(holder)
	holder.caught.connect(func(player: Node3D, enemy: MazeEnemy) -> void: caught_by.append([player, enemy]))
	_run.call_deferred()


func put_boy(at: Vector3, face_to := Vector3.INF) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	if face_to.is_finite():
		var to: Vector3 = face_to - at
		boy.facing_yaw = atan2(to.x, to.z)


func clear() -> void:
	for child in holder.get_children():
		child.queue_free()
	holder.enemies.clear()
	caught_by.clear()
	await frames(3)


## A straight run of passage `length` cells long from a cell well out of the clearing: [start cell, step].
func long_hall(length: int) -> Array:
	for cell: Vector2i in nav.lairs(4):
		for step: Vector2i in Maze.STEPS:
			var at := cell
			var run := 0
			while run < length and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run == length:
				return [cell, step]
	return []


func rabbits() -> Array[MazeRabbit]:
	var found: Array[MazeRabbit] = []
	for one in holder.enemies:
		if one is MazeRabbit:
			found.append(one)
	return found


func _run() -> void:
	await frames(10)

	# --- A colony and its warren ---
	var five := MazeRabbit.colony_of(5, 7)
	var again := MazeRabbit.colony_of(5, 7)
	check("a colony of five, the same from the same seed", five.size() == 5 and again[3].size == five[3].size and again[2].coat_tint == five[2].coat_tint)
	for one in five + again:
		one.free()
	var hall := long_hall(4)
	check("a long straight hall", not hall.is_empty())
	var start: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var middle: Vector3 = maze.world(start + step * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var spot: Array = MazeRabbit.bank_in_hall(maze, start + step * 2, rng)
	var warren: RabbitWarren = MazeRabbit.add_colony(holder, spot[0], spot[1], RabbitWarren.Kind.BANK, 5, 11)
	await frames(5)
	var colony := rabbits()
	check("a warren with its holes, and its colony", warren.hole_count() == 4 and colony.size() == 5 and colony.all(func(r: MazeRabbit) -> bool: return r.warren == warren))
	var holes_ok := true
	for i in warren.hole_count():
		holes_ok = holes_ok and warren.mouth(i).is_finite() and warren.deep(i).distance_to(warren.mouth(i)) > 0.2
	check("each hole has a mouth and a tunnel going in", holes_ok)
	check("the bank lies against a wall, clear of the hall's middle", nav.clear_of_walls(warren.mouth(0) + (warren.mouth(0) - warren.deep(0)).normalized() * 1.0, 0.0))
	for one in colony:
		one.hide_time = Vector2(1.0, 1.5)
		one.peek_time = Vector2(0.4, 0.6)
	put_boy(middle + way * 60.0 if maze.inside(maze.cell_at(middle + way * 60.0)) else middle + Vector3(0.0, 0.0, 300.0))
	var acts := {}
	for i in 360:
		await physics_frame
		for one in colony:
			acts[one.act] = true
	var home_ok := colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.GRAZE and r.global_position.distance_to(warren.global_position) < r.graze_range + 2.0)
	check("left alone they graze round the warren", home_ok, "(%s)" % [colony.map(func(r: MazeRabbit) -> String: return "%s %.1f m" % [MazeRabbit.Mode.keys()[r.mode], r.global_position.distance_to(warren.global_position)])])
	check("nibbling, hopping, sitting up, washing...", acts.size() >= 3, "(%d kinds)" % acts.size())

	# --- He comes into sight: they watch ---
	var out := (warren.mouth(0) - warren.deep(0))
	out.y = 0.0
	out = out.normalized()
	var watch_at: Vector3 = warren.global_position + out * 11.0
	if not nav.line_free(warren.global_position + out * 2.0, watch_at, 0.3):
		watch_at = warren.global_position + way * 11.0
	put_boy(watch_at, warren.global_position)
	var watching := await wait(3.0, func() -> bool: return colony.any(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.WATCH))
	await wait(0.6)
	var watcher: MazeRabbit = null
	for one in colony:
		if one.mode == MazeRabbit.Mode.WATCH:
			watcher = one
	check("he comes into sight: they sit up and watch him", watching and watcher != null and watcher.rabbit.upright and watcher.rabbit.look_at_point.is_finite())

	# --- Nearer: a thump, and they bolt down their holes ---
	var thumped := [false]
	for one in colony:
		one.rabbit.thumped.connect(func() -> void: thumped[0] = true)
	put_boy(warren.global_position + out * 3.0, warren.global_position)
	var bolted := await wait(1.0, func() -> bool: return colony.all(func(r: MazeRabbit) -> bool: return r.mode != MazeRabbit.Mode.GRAZE and r.mode != MazeRabbit.Mode.WATCH))
	check("too near: one thumps, and they all bolt", thumped[0] and bolted)
	var top := [0.0]
	var flashed := [false]
	var under := await wait(5.0, func() -> bool:
		for r in colony:
			top[0] = maxf(top[0], Vector2(r.velocity.x, r.velocity.z).length())
			flashed[0] = flashed[0] or r.rabbit.flagging
		return colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.UNDER))
	check("each makes for a hole, scut up, faster than he can sprint", flashed[0] and top[0] > 5.6, "(%.1f m/s)" % top[0])
	check("and vanishes down it", under, "(%s)" % [colony.map(func(r: MazeRabbit) -> String: return MazeRabbit.Mode.keys()[r.mode])])
	var gone := colony.all(func(r: MazeRabbit) -> bool: return not r.visible and r.collision_layer == 0 and r.escaped and not r.is_physics_processing() and not r.is_processing())
	check("down its hole: not drawn, not solid, doing nothing", gone)
	var hunter := MazeEnemy.new()
	hunter.maze = maze
	stage.add_child(hunter)
	check("down its hole nothing can hunt it", colony.all(func(r: MazeRabbit) -> bool: return not hunter.huntable(r)))
	hunter.queue_free()
	await wait(3.0)
	check("he stays near: they stay down", colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.UNDER))

	# --- He goes: they come up, look, and come out ---
	put_boy(middle + Vector3(0.0, 0.0, 400.0))
	var peeked := await wait(12.0, func() -> bool: return colony.any(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.PEEK))
	check("with him gone, one comes up to look out of its hole", peeked)
	var back := await wait(14.0, func() -> bool: return colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.GRAZE))
	check("and they come out to graze again", back and colony.all(func(r: MazeRabbit) -> bool: return r.visible and not r.escaped and r.collision_layer == 4))

	# --- At night they stay down ---
	var day := DayCycle.new()
	day.hour = 23.0
	for one in colony:
		one._day = day
	var night := await wait(8.0, func() -> bool: return colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.UNDER))
	check("an hour after sunset they go down their holes", night)
	await wait(4.0)
	check("and stay down through the night", colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.UNDER))
	day.hour = 9.0
	var morning := await wait(25.0, func() -> bool: return colony.all(func(r: MazeRabbit) -> bool: return r.mode == MazeRabbit.Mode.GRAZE))
	check("in the morning they come out", morning)
	day.free()

	# --- Something that would eat them ---
	if "threat" in colony[0]:
		var wolf := MazeEnemy.new()
		wolf.maze = maze
		stage.add_child(wolf)
		wolf.global_position = colony[0].global_position + Vector3(3.0, 0.0, 0.0)
		colony[0].set(&"threat", wolf)
		var fled := await wait(1.0, func() -> bool: return colony[0].mode in [MazeRabbit.Mode.BOLT, MazeRabbit.Mode.DIVE, MazeRabbit.Mode.UNDER])
		check("something that would eat it near: it bolts for its hole", fled)
		colony[0].set(&"threat", null)
		wolf.queue_free()
	else:
		print("SKIP: no world's life (Ecology) here to send a threat")
	await clear()

	# --- A puppet rabbit follows its host, down its hole too ---
	var bank2: RabbitWarren = MazeRabbit.add_colony(holder, spot[0], spot[1], RabbitWarren.Kind.BANK, 1, 21)
	await frames(3)
	var host: MazeRabbit = rabbits()[0]
	host.hide_time = Vector2(30.0, 30.0)
	var copy := MazeRabbit.new()
	copy.warren = bank2
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	put_boy(middle + Vector3(0.0, 0.0, 400.0))
	var furthest := 0.0
	var hid := false
	for i in 420:
		await physics_frame
		if i == 120:
			put_boy(host.global_position + out * 2.5, host.global_position)
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30 and host.mode != MazeRabbit.Mode.UNDER:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
		if host.mode == MazeRabbit.Mode.UNDER and copy.mode == MazeRabbit.Mode.UNDER and not copy.visible:
			hid = true
	check("the puppet rabbit keeps up with its host", furthest < 1.5, "(at most %.2f m off)" % furthest)
	check("and goes down its hole with it, out of sight", hid)
	copy.queue_free()
	await clear()

	# --- A hare in the clearing: frozen, flushed, away ---
	var meadow := Vector3(150.0, 0.0, 150.0)
	meadow.y = maze.ground_height(meadow)
	var hares: Array[MazeHare] = MazeHare.add_hares(holder, meadow, false, 3, true)
	var hare: MazeHare = hares[0]
	put_boy(meadow + Vector3(0.0, 0.0, -40.0), meadow)
	await wait(1.5)
	put_boy(meadow + Vector3(0.0, 0.0, -16.0), meadow)
	var froze := await wait(2.0, func() -> bool: return hare.mode == MazeHare.Mode.FREEZE)
	await wait(0.2)
	check("a hare: he comes, and it presses itself flat", froze and hare.rabbit.flattened)
	put_boy(hare.global_position + Vector3(0.0, 0.0, -8.0), hare.global_position)
	await wait(1.0)
	check("it lies tight as he comes on", hare.mode == MazeHare.Mode.FREEZE)
	put_boy(hare.global_position + Vector3(0.0, 0.0, -3.5), hare.global_position)
	var flushed := await wait(1.0, func() -> bool: return hare.mode == MazeHare.Mode.BOLT)
	check("nearly on it, it is flushed", flushed)
	var fastest := [0.0]
	var turns := [0, 0.0]
	var last_way := [Vector2.ZERO]
	var started: Vector3 = hare.global_position
	await wait(4.0, func() -> bool:
		var v := Vector2(hare.velocity.x, hare.velocity.z)
		fastest[0] = maxf(fastest[0], v.length())
		if v.length() > 5.0:
			if last_way[0] != Vector2.ZERO:
				var bend: float = (last_way[0] as Vector2).angle_to(v)
				if signf(bend) != signf(turns[1]) and absf(bend) > 0.01:
					turns[0] += 1
					turns[1] = bend
			last_way[0] = v
		return hare.mode != MazeHare.Mode.BOLT)
	check("away flat out, far faster than he can run", fastest[0] > 10.0, "(%.1f m/s)" % fastest[0])
	check("jinking one way and the other", turns[0] >= 3, "(%d turns)" % turns[0])
	check("and far off", hare.global_position.distance_to(started) > 30.0, "(%.0f m)" % hare.global_position.distance_to(started))
	await clear()

	# --- A pair box ---
	var pair: Array[MazeHare] = MazeHare.add_hares(holder, meadow, true, 9, true)
	put_boy(meadow + Vector3(0.0, 0.0, 50.0))
	await wait(1.0)
	pair[0]._box_in = 0.0
	pair[0].mode = MazeHare.Mode.FORM
	pair[1].mode = MazeHare.Mode.FORM
	var boxing := await wait(3.0, func() -> bool: return pair[0].mode == MazeHare.Mode.BOX and pair[1].mode == MazeHare.Mode.BOX)
	await wait(1.5)
	check("a pair left alone box", boxing and pair[0].rabbit.boxing and pair[1].rabbit.boxing and pair[0].global_position.distance_to(pair[1].global_position) < 1.5,
			"(%.2f m apart)" % pair[0].global_position.distance_to(pair[1].global_position))
	await clear()

	# --- The jackalope ---
	var jack := MazeJackalope.new()
	jack.keep_out_of_clearing = false
	var jcell: Vector2i = maze.cell_at(meadow)
	holder.add(jack, jcell, 0.0, 5, meadow - maze.world(jcell) + Vector3.UP * 0.2)
	put_boy(meadow + Vector3(0.0, 0.0, -40.0), meadow)
	await wait(1.0)
	put_boy(meadow + Vector3(0.0, 0.0, -10.0), meadow)
	var stared := await wait(2.0, func() -> bool: return jack.mode == MazeHare.Mode.FREEZE)
	await wait(0.2)
	check("the jackalope does not hide: it sits up and stares", stared and jack.rabbit.upright and not jack.rabbit.flattened and jack.rabbit.look_at_point.is_finite())
	check("drawn with antlers", jack.rabbit.variant == Rabbit.Variant.JACKALOPE and jack.rabbit.model_path().contains("jackalope"))
	put_boy(jack.global_position + Vector3(0.0, 0.0, -6.0), jack.global_position)
	await wait(1.0)
	check("it lets him come", jack.mode == MazeHare.Mode.FREEZE)
	var grunted := [false]
	jack.rabbit.grunted.connect(func() -> void: grunted[0] = true)
	put_boy(jack.global_position + Vector3(0.0, 0.0, -2.6), jack.global_position)
	var lowered := await wait(1.0, func() -> bool: return jack.mode == MazeHare.Mode.GRUNT)
	await wait(0.1)
	check("too near: it grunts and lowers its antlers", lowered and grunted[0] and jack.rabbit.lowered)
	var butted := await wait(2.5, func() -> bool: return boy.is_limp)
	check("it charges and butts him off his feet", butted)
	check("it catches nobody", caught_by.is_empty())
	var up := await wait(3.0, func() -> bool: return not boy.is_limp)
	check("he gets up again", up)
	var off := await wait(2.0, func() -> bool: return jack.mode == MazeHare.Mode.BOLT)
	check("and it is away", off)
	await clear()

	# --- Out past the square maze: open ground ---
	var beyond := Vector3(maze.extent() * 0.5 + 60.0, 0.0, 0.0)
	var floor := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	slab.shape = box
	floor.add_child(slab)
	stage.add_child(floor)
	floor.global_position = beyond + Vector3.DOWN * 0.5
	MazeRabbit.add_colony(holder, beyond, 0.0, RabbitWarren.Kind.MOUND, 3, 31, true)
	await wait(4.0)
	var outside := rabbits()
	check("out past the square maze a colony keeps to open ground", outside.size() == 3 and outside.all(func(r: MazeRabbit) -> bool: return r.maze == null and r.mode == MazeRabbit.Mode.GRAZE and r.global_position.distance_to(beyond) < r.graze_range + 3.0 and r.global_position.y > -0.5))
	await clear()

	# --- The sounds ---
	check("the thump and the grunt are made", Rabbit.thump_sound().data.size() > 1000 and Rabbit.grunt_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
