extends SceneTree
## The deer and the bull elk (scripts/enemies/maze_deer.gd and maze_elk.gd on
## creatures/deer and creatures/elk), headless, in a bare scene: a maze from
## MazeBuilder and the boy in it. In turn:
## - a herd: one of them wrong, the same herd from the same seed;
## - it sees him down a hall, every head comes up and turns to him, frozen;
## - looked away from, it creeps closer; looked at, it stops dead;
## - he comes near: it snorts, flags, stots and stampedes, but the wrong one
##   stays, watching him;
## - a stampeding deer knocks down anyone in its way;
## - the elk on his ground bugles, paws and charges; standing still he is
##   caught; stepping aside once the elk's line is set he is missed, and the
##   elk stands blowing; up off the ground he is only glared at;
## - puppets follow their hosts; the sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/deer_test.gd
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


func put_boy(at: Vector3, face_to := Vector3.INF) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	if face_to.is_finite():
		var to: Vector3 = face_to - at
		boy.facing_yaw = atan2(to.x, to.z)


func enemy_in(one: MazeEnemy, at: Vector3, yaw := 0.0) -> MazeEnemy:
	one.maze = maze
	one.position = at + Vector3.UP * 0.05
	one.rotation.y = yaw
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
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


func _run() -> void:
	await frames(10)

	# --- A herd ---
	var five := MazeDeer.herd_of(5, 7)
	var wrong := five.filter(func(d: MazeDeer) -> bool: return d.wrong > 0.0)
	check("a herd of five, one of them wrong", five.size() == 5 and wrong.size() == 1)
	var again := MazeDeer.herd_of(5, 7)
	check("the same herd from the same seed", again[2].size == five[2].size and again[3].coat_tint == five[3].coat_tint and again[1].wrong == five[1].wrong)
	for one in again:
		one.free()

	# --- It sees him down a hall: heads up, frozen, watching ---
	var hall := long_hall(4)
	check("a long straight hall", not hall.is_empty())
	var start: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var far_end: Vector3 = maze.world(start + step * 3)
	var near_end: Vector3 = maze.world(start)
	var herd: Array[MazeDeer] = []
	for k in five.size():
		var one: MazeDeer = five[k]
		one.creep_speed = 1.6
		herd.append(enemy_in(one, far_end + Vector3(way.z, 0.0, -way.x) * (k - 2) * 1.6, randf() * TAU) as MazeDeer)
	put_boy(near_end, far_end)
	var watching := await wait(4.0, func() -> bool: return herd.all(func(d: MazeDeer) -> bool: return d.mode in [MazeDeer.Mode.WATCH, MazeDeer.Mode.CREEP]))
	check("every one of them comes to watch him", watching, "(%s)" % [herd.map(func(d: MazeDeer) -> String: return MazeDeer.Mode.keys()[d.mode])])
	await process_frame
	var plain: MazeDeer = herd.filter(func(d: MazeDeer) -> bool: return d.wrong <= 0.0)[0]
	await wait(1.0, func() -> bool: return plain.deer.alert and plain.deer.look_at_point.is_finite())
	check("heads up, eyes on him", plain.deer.alert and plain.deer.look_at_point.distance_to(boy.global_position) < 2.0, "(%s %s %s)" % [plain.deer.alert, plain.deer.look_at_point, boy.global_position])

	# --- Looked away from, it creeps; looked at, it stops ---
	var gap_before: float = plain.global_position.distance_to(boy.global_position)
	boy.facing_yaw = atan2(-way.x, -way.z)
	await wait(3.0)
	var gap_after: float = plain.global_position.distance_to(boy.global_position)
	check("looked away from, it comes closer", gap_after < gap_before - 1.0, "(%.1f m to %.1f m)" % [gap_before, gap_after])
	boy.facing_yaw = atan2(way.x, way.z)
	await wait(0.8)
	var moving := Vector2(plain.velocity.x, plain.velocity.z).length()
	check("looked at, it stops dead", moving < 0.2 and plain.mode == MazeDeer.Mode.WATCH, "(%.2f m/s, %s)" % [moving, MazeDeer.Mode.keys()[plain.mode]])

	# --- He comes near: snort, flag, stot, stampede; the wrong one stays ---
	var odd: MazeDeer = herd.filter(func(d: MazeDeer) -> bool: return d.wrong > 0.0)[0]
	var snorted := [false]
	for one in herd:
		one.deer.snorted.connect(func() -> void: snorted[0] = true)
	put_boy(plain.global_position - way * 6.0, plain.global_position)
	var alarmed := await wait(2.0, func() -> bool: return plain.mode == MazeDeer.Mode.ALARM)
	check("too near: it takes alarm", alarmed)
	await process_frame
	check("a snort, and the tails go up", snorted[0] and plain.deer.flagging)
	var pronked := await wait(2.0, func() -> bool: return plain.mode == MazeDeer.Mode.PRONK)
	await process_frame
	check("it stots off on stiff legs", pronked and plain.deer.pronking)
	var ran := await wait(3.0, func() -> bool: return plain.mode == MazeDeer.Mode.STAMPEDE)
	await wait(0.8)
	var pace := Vector2(plain.velocity.x, plain.velocity.z).length()
	check("then a stampede, faster than he can sprint", ran and pace > 5.6, "(%.1f m/s)" % pace)
	check("the wrong one does not run: it stays, watching him", odd.mode in [MazeDeer.Mode.WATCH, MazeDeer.Mode.CREEP] and odd.deer.look_at_point.is_finite())
	# A stampeding deer knocks down anyone in its way.
	caught_by.clear()
	var runner: MazeDeer = null
	for one in herd:
		if one.mode == MazeDeer.Mode.STAMPEDE and Vector2(one.velocity.x, one.velocity.z).length() > 4.0:
			runner = one
	check("one still in full flight", runner != null)
	if runner:
		var ahead: Vector3 = runner.global_position + Vector3(runner.velocity.x, 0.0, runner.velocity.z).normalized() * 2.0
		put_boy(ahead)
		var knocked := await wait(1.0, func() -> bool: return not caught_by.is_empty())
		check("he is in its way: knocked down", knocked and caught_by[0][0] == boy)
	await clear()

	# --- A puppet deer follows its host ---
	var host := enemy_in(MazeDeer.herd_of(1, 3)[0], far_end) as MazeDeer
	var copy := MazeDeer.herd_of(1, 3)[0]
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	put_boy(near_end, far_end)
	var furthest := 0.0
	for i in 400:
		await physics_frame
		if i == 120:
			put_boy(host.global_position - way * 5.0, host.global_position)
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet deer keeps up with its host", furthest < 2.0, "(at most %.2f m off)" % furthest)
	check("and is in the same state", copy.mode == host.mode)
	await clear()

	# --- The elk: bugle, paw, charge; caught standing still ---
	var elk := enemy_in(MazeElk.new(), far_end, atan2(-way.x, -way.z)) as MazeElk
	await frames(10)
	put_boy(far_end - way * 18.0, far_end)
	var bugled := await wait(3.0, func() -> bool: return elk.mode == MazeElk.Mode.WARN)
	await process_frame
	check("on his ground: he faces him and bugles", bugled and elk.elk.bugling())
	var pawed := await wait(5.0, func() -> bool: return elk.mode == MazeElk.Mode.PAW)
	await process_frame
	check("then paws the ground", pawed and elk.elk.pawing)
	var charged := await wait(3.0, func() -> bool: return elk.mode == MazeElk.Mode.CHARGE)
	check("then charges", charged)
	var gored := await wait(4.0, func() -> bool: return not caught_by.is_empty())
	check("standing still, he is caught", gored and caught_by[0][0] == boy)
	var top := [0.0]
	var stood := await wait(4.0, func() -> bool:
		top[0] = maxf(top[0], Vector2(elk.velocity.x, elk.velocity.z).length())
		return elk.mode == MazeElk.Mode.RECOVER)
	check("he runs on, and stands blowing", stood)
	await clear()

	# --- Stepping aside once his line is set ---
	elk = enemy_in(MazeElk.new(), far_end, atan2(-way.x, -way.z)) as MazeElk
	elk._bugled = true
	await frames(10)
	var spot: Vector3 = far_end - way * 18.0
	put_boy(spot, far_end)
	charged = await wait(6.0, func() -> bool: return elk.mode == MazeElk.Mode.CHARGE)
	check("he charges again (no bugle the second time)", charged)
	await wait(elk.aim_time + 0.1)
	var aside := Vector3(-way.z, 0.0, way.x)
	var dodge: Vector3 = spot + aside * 5.0
	if not nav.line_free(spot, dodge, 0.4):
		dodge = spot - aside * 5.0
	put_boy(dodge)
	var top_speed := [0.0]
	var passed := await wait(5.0, func() -> bool:
		top_speed[0] = maxf(top_speed[0], Vector2(elk.velocity.x, elk.velocity.z).length())
		return elk.mode == MazeElk.Mode.RECOVER)
	check("he cannot turn: stepping aside, he misses", passed and caught_by.is_empty(), "(caught %d)" % caught_by.size())
	check("his charge is faster than a sprint", top_speed[0] > 5.6, "(%.1f m/s)" % top_speed[0])
	await clear()

	# --- Up off the ground, only glared at ---
	elk = enemy_in(MazeElk.new(), far_end, atan2(-way.x, -way.z)) as MazeElk
	elk._bugled = true
	await frames(10)
	put_boy(far_end - way * 14.0 + Vector3.UP * 6.0, far_end)
	boy.velocity = Vector3.ZERO
	var never := true
	for i in 240:
		boy.global_position = far_end - way * 14.0 + Vector3.UP * 6.0
		boy.velocity = Vector3.ZERO
		await physics_frame
		if elk.mode == MazeElk.Mode.CHARGE:
			never = false
	check("up off the ground he is only glared at", never and elk.mode == MazeElk.Mode.GLARE, "(%s)" % MazeElk.Mode.keys()[elk.mode])
	await clear()

	# --- A puppet elk bugles with its host ---
	var bull := enemy_in(MazeElk.new(), far_end, atan2(-way.x, -way.z)) as MazeElk
	var double := MazeElk.new()
	double.maze = maze
	double.puppet = true
	double.position = bull.position
	stage.add_child(double)
	put_boy(far_end - way * 16.0, far_end)
	var copied := false
	furthest = 0.0
	for i in 300:
		await physics_frame
		if i % 6 == 0:
			double.from_bytes(bull.state_bytes())
		if i > 30:
			furthest = maxf(furthest, double.global_position.distance_to(bull.global_position))
		if double.elk.bugling():
			copied = true
	check("the puppet elk bugles when its host does", copied)
	check("and keeps up with it", furthest < 2.5, "(at most %.2f m off)" % furthest)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != double))
	await clear()

	# --- The sounds ---
	var bugle := Elk.bugle_sound()
	check("the bugle is made", bugle.data.size() > 22050 * 2 * 3)
	check("the snort and the stamp are made", Deer.snort_sound().data.size() > 1000 and Deer.stamp_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
