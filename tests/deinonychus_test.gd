extends SceneTree
## The deinonychus pack (scripts/enemies/maze_deinonychus.gd on
## creatures/deinonychus), headless, in a bare scene: a maze from MazeBuilder
## and the boy in it. In turn: a pack from `pack_of`; its speeds; one alone
## that sees him hoots, holds off, bursts, winds up (the crouch), leaps and
## pins him; a pounce he steps out of misses and it stumbles; a burst tires
## it; a pack at a junction splits, one drawing him and the others going
## round by other passages to cut him off; a puppet follows the host and
## pounces with it; and up out of its reach it is baffled, cannot catch him,
## and gives up.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/deinonychus_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0
var caught_by: Array = []
## Stops a walk_boy that is still going.
var stop_walking := false


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
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func dino_at(cell: Vector2i, yaw := 0.0, made: MazeDeinonychus = null) -> MazeDeinonychus:
	var dino := made if made else MazeDeinonychus.new()
	dino.maze = maze
	dino.position = maze.world(cell) + Vector3.UP * 0.05
	dino.rotation.y = yaw
	stage.add_child(dino)
	dino.caught.connect(func(player: Node3D) -> void: caught_by.append([player, dino]))
	return dino


func clear_dinos() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


## A cell `run` straight steps from `from` with nothing in the way (or (-1, -1)).
func straight_from(from: Vector2i, run_for: int) -> Vector2i:
	for step: Vector2i in Maze.STEPS:
		var at: Vector2i = from
		var run := 0
		while run < run_for and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
			at += step
			run += 1
		if run == run_for:
			return at
	return Vector2i(-1, -1)


func open_ways(cell: Vector2i) -> int:
	var count := 0
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step) and maze.inside(cell + step) and not maze.in_clearing(cell + step):
			count += 1
	return count


## Walks the boy along the passages from where he is to `to`, at `speed`.
func walk_boy(to: Vector2i, speed: float) -> void:
	var path: Array = nav.path(maze.cell_at(boy.global_position), to)
	stop_walking = false
	for cell: Vector2i in path:
		var goal: Vector3 = maze.world(cell)
		while Vector2(goal.x - boy.global_position.x, goal.z - boy.global_position.z).length() > 0.3 and not stop_walking:
			var step := get_root().get_physics_process_delta_time()
			var to_goal: Vector3 = goal - boy.global_position
			to_goal.y = 0.0
			var move: Vector3 = to_goal.normalized() * minf(speed * step, to_goal.length())
			boy.global_position += move
			boy.velocity = Vector3(move.x, 0.0, move.z) / step
			await physics_frame
	boy.velocity = Vector3.ZERO


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)

	# --- A pack ---
	var four := MazeDeinonychus.pack_of(4, 7)
	var looks := {}
	for one in four:
		looks["%.3f %s %.3f" % [one.size, one.tint, one.voice]] = true
	check("a pack of four, no two alike, one pack", four.size() == 4 and looks.size() == 4 and four.all(func(d: MazeDeinonychus) -> bool: return d.pack_id == four[0].pack_id))
	check("ranked 0..3", four.map(func(d: MazeDeinonychus) -> int: return d.rank) == [0, 1, 2, 3])
	var again := MazeDeinonychus.pack_of(4, 7)
	check("the same pack from the same seed", again[2].size == four[2].size and again[3].tint == four[3].tint)
	for one in four + again:
		one.free()
	var probe := MazeDeinonychus.new()
	check("speeds: its burst faster than a sprint, its lope and its tired pace slower than a run", probe.burst_speed > 5.6 and probe.flank_speed < 4.4 and probe.tired_speed < 4.4)
	check("it cannot reach a terrace (6.5 m) but can a wall's footing (1.6 m)", probe.reach_up < MazeFeatures.LOWER.x and probe.reach_up > MazeBuilder.FOOT.y)
	probe.free()

	# --- One alone: it sees him, hoots, holds off, bursts, winds up, leaps, pins him ---
	var home: Vector2i = Vector2i(-1, -1)
	var straight := Vector2i(-1, -1)
	for cell: Vector2i in lairs:
		straight = straight_from(cell, 2)
		if straight.x >= 0:
			home = cell
			break
	check("a straight passage from the boy", straight.x >= 0)
	put_boy(maze.world(home))
	await frames(10)
	var to_boy: Vector3 = maze.world(home) - maze.world(straight)
	var dino := dino_at(straight, atan2(to_boy.x, to_boy.z))
	var hoots: Array[int] = [0]
	dino.dino.hooted.connect(func() -> void: hoots[0] += 1)
	var saw := await wait(3.0, func() -> bool: return dino.hunting())
	check("it sees him", saw)
	await frames(2)
	check("and hoots", hoots[0] > 0, "(%d)" % hoots[0])
	var held := await wait(4.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.STALK)
	check("it comes on low and holds off (stalking)", held)
	var burst := await wait(8.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.BURST)
	check("then bursts at him", burst)
	var crouched := await wait(8.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.WIND_UP)
	check("close, it winds up to pounce", crouched)
	await frames(3)
	check("the wind-up is shown (the crouch)", dino.dino.pounce_stage() == DeinonychusRig.Pounce.CROUCH)
	var pinned := await wait(2.0, func() -> bool: return not caught_by.is_empty())
	check("it leaps and pins him (he stood still)", pinned and caught_by[0][0] == boy)
	await frames(2)
	check("the pin is shown", dino.dino.pinning() and dino.mode == MazeDeinonychus.Mode.PIN)
	await clear_dinos()

	# --- A pounce he steps out of misses ---
	put_boy(maze.world(home))
	await frames(70)
	dino = dino_at(straight, atan2(to_boy.x, to_boy.z))
	crouched = await wait(15.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.WIND_UP)
	check("it winds up again", crouched)
	var aside := Vector3(-to_boy.z, 0.0, to_boy.x).normalized()
	var dodge: Vector3 = boy.global_position + aside * 5.0
	if not nav.line_free(boy.global_position, dodge, 0.3):
		dodge = boy.global_position - aside * 5.0
	await wait(1.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.LEAP)
	put_boy(dodge)
	var missed := await wait(2.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.MISS)
	check("he steps aside as it leaps: it misses and stumbles", missed and caught_by.is_empty(), "(mode %s, caught %d)" % [MazeDeinonychus.Mode.keys()[dino.mode], caught_by.size()])
	check("the stumble is shown", dino.dino.busy())
	await clear_dinos()

	# --- A burst tires it ---
	put_boy(maze.world(home))
	await frames(70)
	var far_end: Vector2i = home
	for cell: Vector2i in lairs:
		if nav.distance(home, cell) >= 10:
			far_end = cell
			break
	dino = dino_at(straight, atan2(to_boy.x, to_boy.z))
	dino.pounce_range = 0.0
	burst = await wait(10.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.BURST)
	walk_boy(far_end, 5.6)
	var tired := await wait(dino.burst_time + 2.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.TIRED)
	check("a burst lasts only a couple of seconds: then it is tired", burst and tired, "(stamina %.2f)" % dino.stamina)
	await frames(2)
	check("tired is shown (panting)", dino.dino.tired)
	stop_walking = true
	await frames(2)
	boy.velocity = Vector3.ZERO
	await clear_dinos()

	# --- A pack at a junction: one draws him, the others go round ---
	# (one with a way round to another of its passages that does not pass through it: a loop of the halls)
	var junction := Vector2i(-1, -1)
	var approach := Vector2i(-1, -1)
	for cell: Vector2i in lairs:
		if open_ways(cell) < 3:
			continue
		var from := straight_from(cell, 2)
		if from.x < 0:
			continue
		var loops := false
		for step: Vector2i in Maze.STEPS:
			var next: Vector2i = cell + step
			if maze.blocked(cell, step) or not maze.inside(next) or maze.in_clearing(next) or nav.path(from, cell).has(next):
				continue
			var path: Array = nav.path(from, next)
			if not path.is_empty() and not path.has(cell) and path.size() <= MazeDeinonychus.ROUND_ABOUT - 2:
				loops = true
		if loops:
			junction = cell
			approach = from
			break
	check("a junction with a straight way into it and a way round", junction.x >= 0)
	put_boy(maze.world(junction))
	await frames(30)
	print("     (the boy at %s, %.2f m over the junction's floor)" % [boy.global_position, boy.global_position.y - maze.world(junction).y])
	var three := MazeDeinonychus.pack_of(3, 11)
	var dir: Vector3 = maze.world(junction) - maze.world(approach)
	var members: Array[MazeDeinonychus] = []
	for k in 3:
		var one := dino_at(approach, atan2(dir.x, dir.z), three[k])
		one.position += Vector3(-dir.z, 0.0, dir.x).normalized() * (k - 1) * 1.2
		members.append(one)
	var split := await wait(4.0, func() -> bool:
		var stalking := members.filter(func(d: MazeDeinonychus) -> bool: return d.mode == MazeDeinonychus.Mode.STALK).size()
		var flanking := members.filter(func(d: MazeDeinonychus) -> bool: return d.mode in [MazeDeinonychus.Mode.FLANK, MazeDeinonychus.Mode.WAIT]).size()
		return stalking == 1 and flanking == 2)
	check("one holds off to draw him, two go round", split, "(%s)" % ", ".join(members.map(func(d: MazeDeinonychus) -> String: return MazeDeinonychus.Mode.keys()[d.mode])))
	var ambushes := members.filter(func(d: MazeDeinonychus) -> bool: return d.mode in [MazeDeinonychus.Mode.FLANK, MazeDeinonychus.Mode.WAIT] and d._ambush.x >= 0).map(func(d: MazeDeinonychus) -> Vector2i: return d._ambush)
	var ok := not ambushes.is_empty()
	for cell: Vector2i in ambushes:
		# (not where he is, and got to without passing him)
		var path: Array = nav.path(approach, cell)
		ok = ok and cell != junction and not path.has(junction)
	check("a flanker goes round by other passages to cut him off (no way round: it holds off with the drawer)", ok, "(making for %s, he is at %s)" % [ambushes, junction])
	var went := await wait(12.0, func() -> bool: return members.any(func(d: MazeDeinonychus) -> bool: return d.mode == MazeDeinonychus.Mode.WAIT and d._ambush.x >= 0))
	check("it gets there and waits, and hoots", went)
	var all_go := await wait(14.0, func() -> bool: return members.any(func(d: MazeDeinonychus) -> bool: return d.mode in [MazeDeinonychus.Mode.BURST, MazeDeinonychus.Mode.WIND_UP, MazeDeinonychus.Mode.LEAP, MazeDeinonychus.Mode.PIN]))
	check("then they go for him", all_go)
	await clear_dinos()

	# --- A puppet follows the host, and pounces with it ---
	put_boy(maze.world(home))
	await frames(70)
	var host := dino_at(straight, atan2(to_boy.x, to_boy.z))
	var copy := MazeDeinonychus.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	# (in a game the copy is on another machine: here, out of the host's way)
	copy.collision_layer = 0
	var furthest := 0.0
	var copied := false
	for i in 900:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		furthest = maxf(furthest, copy.global_position.distance_to(host.global_position)) if i > 30 and host.mode != MazeDeinonychus.Mode.LEAP else furthest
		if copy.dino.pounce_stage() != DeinonychusRig.Pounce.NONE:
			copied = true
	check("the puppet keeps up with the host", furthest < 1.5, "(at most %.2f m off)" % furthest)
	check("the puppet pounces when the host does", copied)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear_dinos()

	# --- Up out of its reach: baffled, it cannot catch him, and gives up ---
	var ledge := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(2.0, 0.4, 2.0)
	ledge.add_child(box)
	stage.add_child(ledge)
	ledge.global_position = maze.world(home) + Vector3.UP * 6.3
	put_boy(maze.world(home) + Vector3.UP * 6.6)
	await frames(30)
	dino = dino_at(straight, atan2(to_boy.x, to_boy.z))
	dino.baffle_time = 14.0
	var baffled := await wait(6.0, func() -> bool: return dino.mode == MazeDeinonychus.Mode.BAFFLED)
	check("he is up on a terrace: it is baffled", baffled, "(boy %.1f m up)" % (boy.global_position.y - dino.global_position.y))
	var under := await wait(12.0, func() -> bool: return Vector2(dino.global_position.x - boy.global_position.x, dino.global_position.z - boy.global_position.z).length() < 4.0)
	check("it comes under him, looking up", under, "(%.1f m off, flat)" % Vector2(dino.global_position.x - boy.global_position.x, dino.global_position.z - boy.global_position.z).length())
	var gave_up := await wait(16.0, func() -> bool: return not dino.hunting())
	check("it cannot catch him, and gives up", gave_up and caught_by.is_empty())
	ledge.queue_free()
	await clear_dinos()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
