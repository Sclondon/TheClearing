extends SceneTree
## The spider monkeys (MazeSpiderMonkey driving SpiderMonkey), headless, in a
## real maze (MazeBuilder in a bare scene):
##
## - a troop put in a hall strings its vines along the walls over it (on plain
##   wall, nothing to land on under them, their stems down to the ground) and
##   hangs from them, spread out, `VINE_HIGH` up, still while nobody is near;
## - the boy walks down the hall under them: they notice him, stir (rustling),
##   swing along the vine after him, one winds up (the warning) and drops on him;
## - he sprints down the hall under them: drops miss him, and the ones that
##   land chase him on the ground but he outruns them;
## - one that misses chases a little, then goes home: to a stem of its vine, up
##   it, along the vine to its hold, and hangs again;
## - he walks by out of their reach (at the far end of the hall): nobody drops;
## - a puppet fed the host's `state_bytes` finds the same vines and follows it,
##   and catches nobody;
## - the component's example runs, and the models have every bone.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/spider_monkey_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy
var failures := 0
var caught: Array = []
var trace := OS.get_cmdline_user_args().has("trace")


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
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("MONKEYS", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	boy.position = Vector3(0.0, 0.1, 0.0)
	_run.call_deferred()


## A cell of a hall with a long straight run of wall beside it, well out in the ring.
func hall_cell() -> Array:
	var lairs := nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 3 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and (maze.blocked(cell, across) or maze.blocked(cell, -across)) \
					and not maze.blocked(cell + s, s) and not maze.blocked(cell - s, -s):
				return [cell, s]
	return [lairs[0], Vector2i(1, 0)]


func put_boy(at: Vector3) -> void:
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z)
	boy.velocity = Vector3.ZERO


func make_troop(cell: Vector2i, count: int, seed_value: int, puppets := false) -> Array:
	var troop := MazeSpiderMonkey.troop(count)
	for k in troop.size():
		var one: MazeSpiderMonkey = troop[k]
		one.maze = maze
		one.puppet = puppets
		one.seed_choices(seed_value + k)
		one.position = maze.world(cell) + Vector3.UP * 0.05
		stage.add_child(one)
		if not puppets:
			one.caught.connect(func(who: Node3D) -> void: caught.append([who, one]))
	return troop


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught.clear()
	# (and he is put out of the way, in the clearing, before the next lot are put in)
	put_boy(Vector3(0.0, 0.1, 0.0))


## Walks (or runs) the boy from `from` to `to` at `speed`, until `until` (or he is there).
func walk(from: Vector3, to: Vector3, speed: float, until := Callable(), seconds := 12.0) -> bool:
	put_boy(from)
	var state := {"at": Vector3(from.x, 0.0, from.z)}
	return await wait(seconds, func() -> bool:
		var at: Vector3 = state["at"]
		var way := Vector3(to.x - at.x, 0.0, to.z - at.z)
		if way.length() > 0.05:
			var step := way.normalized() * minf(speed / 60.0, way.length())
			at += step
			state["at"] = at
			boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.05, at.z)
			boy.velocity = step * 60.0
		else:
			boy.velocity = Vector3.ZERO
		if trace and Engine.get_physics_frames() % 20 == 0:
			print("  boy %s" % at.snappedf(0.1))
		if until.is_valid():
			return until.call()
		return way.length() <= 0.05)


func modes(troop: Array) -> String:
	var names := []
	for one: MazeSpiderMonkey in troop:
		names.append(MazeSpiderMonkey.Mode.keys()[one.mode])
	return ", ".join(names)


func _run() -> void:
	await wait(0.3)
	var found := hall_cell()
	var cell: Vector2i = found[0]
	var step: Vector2i = found[1]
	var along := Vector3(step.x, 0.0, step.y)
	put_boy(maze.world(cell) + along * 60.0 if maze.inside(maze.cell_at(maze.world(cell) + along * 60.0)) else Vector3(0.0, 0.1, 0.0))

	# --- A troop strings its vines and hangs ---
	var troop := make_troop(cell, 6, 11)
	await wait(1.0)
	var shared: MazeSpiderMonkey.Troop = troop[0].troop_of
	check("the troop strings a vine along the wall", shared.vines.size() >= 1, "(%d vines, %.1f m long)" % [shared.vines.size(), shared.vines[0].length() if not shared.vines.is_empty() else 0.0])
	if shared.vines.is_empty():
		print("SPIDER MONKEY TEST FAILED (no vines)")
		quit(1)
		return
	var ground := maze.ground_height(maze.world(cell))
	var hanging := true
	var lowest := INF
	for one: MazeSpiderMonkey in troop:
		hanging = hanging and one.mode == MazeSpiderMonkey.Mode.HANG and one.global_position.distance_to(one._line().point_at(one.at_t) + Vector3.DOWN * SpiderMonkey.HANG_HIGH * one.body.size) < 0.05
		lowest = minf(lowest, one.global_position.y - ground)
	check("every one hangs from a vine", hanging, "(%s)" % modes(troop))
	check("high over the hall", lowest > MazeSpiderMonkey.VINE_HIGH - 2.0, "(the lowest %.1f m up)" % lowest)
	var space: PhysicsDirectSpaceState3D = troop[0].get_world_3d().direct_space_state
	var clear_below := true
	for one: MazeSpiderMonkey in troop:
		var foot := one._hold_foot()
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(one.global_position + Vector3.UP * 0.5, foot + Vector3.DOWN * 0.5, 1))
		if not down.is_empty() and (down["position"] as Vector3).y > ground + 1.0:
			clear_below = false
	check("nothing to land on under them", clear_below)
	var apart := INF
	for a: MazeSpiderMonkey in troop:
		for b: MazeSpiderMonkey in troop:
			if a != b and a.vine == b.vine:
				apart = minf(apart, a.global_position.distance_to(b.global_position))
	check("spread along the vines", apart > 0.8, "(nearest two %.1f m apart)" % apart)
	var line: SpiderMonkeyVine = shared.vines[0]
	check("the vine's stems go down to the ground", absf(line.foot(0).y - ground) < 0.5 and absf(line.foot(1).y - ground) < 0.5)
	var was: Array = []
	for one: MazeSpiderMonkey in troop:
		was.append(one.global_position)
	await wait(2.0)
	var still := true
	for k in troop.size():
		still = still and troop[k].global_position.distance_to(was[k]) < 0.05 and troop[k].mode == MazeSpiderMonkey.Mode.HANG
	check("still while nobody is near", still, "(%s)" % modes(troop))

	# --- He walks down the hall under them: they stir, and one drops on him ---
	# (down the middle of the hall: between its two vines, or well out from the one)
	var hall: Vector3 = line.point_at(0.5) + shared.outs[0] * 4.0
	if shared.vines.size() > 1:
		hall = (line.point_at(0.5) + shared.vines[1].point_at(0.5)) * 0.5
	hall.y = ground
	along = line.axis_at(0.5)
	along.y = 0.0
	along = along.normalized()
	var from := hall - along * 26.0
	var to := hall + along * 26.0
	var seen := {"stir": false, "rustles": 0, "wind": false, "moved": 0.0}
	var start_t: float = troop[0].at_t
	var got := await walk(from, to, 1.6, func() -> bool:
		for one: MazeSpiderMonkey in troop:
			seen["stir"] = seen["stir"] or one.mode == MazeSpiderMonkey.Mode.STIR
			seen["wind"] = seen["wind"] or one.mode == MazeSpiderMonkey.Mode.WIND
			seen["rustles"] = maxi(seen["rustles"], one._rustles)
		seen["moved"] = maxf(seen["moved"], absf(troop[0].at_t - start_t) * shared.vines[troop[0].vine].length())
		if trace and Engine.get_physics_frames() % 30 == 0:
			var line_out := "  %s | boy %s" % [modes(troop), boy.global_position.snappedf(0.1)]
			for m: MazeSpiderMonkey in troop:
				var foot: Vector3 = m._hold_foot()
				line_out += " | v%d d %.1f out %.1f %s" % [m.vine, Vector2(boy.global_position.x - foot.x, boy.global_position.z - foot.z).length(), (boy.global_position - foot).dot(m._out()), "clear" if m._clear_line(m.body.head_position(), boy.global_position + Vector3.UP) else "BLOCK"]
			print(line_out)
		return not caught.is_empty(), 40.0)
	check("they notice him and stir", seen["stir"])
	check("the vines rustle (the warning)", seen["rustles"] > 0)
	check("they swing along after him", seen["moved"] > 0.5, "(%.1f m)" % seen["moved"])
	check("one winds up before it drops", seen["wind"])
	check("a drop catches him walking under them", got and caught[0][0] == boy, "(%s)" % modes(troop))
	if got:
		var by: MazeSpiderMonkey = caught[0][1]
		check("caught by a drop, and it shrieks", by._drops > 0 and by._shrieks > 0, "(%s)" % MazeSpiderMonkey.Mode.keys()[by.mode])

	# --- One that missed goes home: chases a little, back to its vine, up, along, hangs ---
	put_boy(Vector3(0.0, 0.1, 0.0))
	var homed := await wait(30.0, func() -> bool:
		for one: MazeSpiderMonkey in troop:
			if one.mode != MazeSpiderMonkey.Mode.HANG:
				return false
		return true)
	check("they all go home and hang again", homed, "(%s)" % modes(troop))
	var on_holds := true
	for one: MazeSpiderMonkey in troop:
		on_holds = on_holds and absf(one.at_t - one.hold_t) < 0.01
	check("each at its own hold", on_holds)
	clear()

	# --- He sprints under them: the drops miss, and he outruns them ---
	troop = make_troop(cell, 6, 31)
	await wait(1.0)
	var drops := {"count": 0, "chased": false}
	await walk(from, to + along * 30.0, 5.6, func() -> bool:
		var total := 0
		for one: MazeSpiderMonkey in troop:
			total += one._drops
			drops["chased"] = drops["chased"] or one.mode == MazeSpiderMonkey.Mode.CHASE
		drops["count"] = total
		return not caught.is_empty(), 22.0)
	check("they drop at him sprinting", drops["count"] > 0, "(%d drops)" % drops["count"])
	check("and chase him on the ground", drops["chased"])
	check("but a sprint gets him away", caught.is_empty(), "(%s)" % modes(troop))
	clear()

	# --- He only runs under them: caught (by a drop, or the chase after one) ---
	troop = make_troop(cell, 6, 41)
	await wait(1.0)
	var ran := await walk(from, to + along * 30.0, 4.4, func() -> bool: return not caught.is_empty(), 22.0)
	check("running is not enough: they have him", ran, "(%s)" % modes(troop))
	clear()

	# --- He walks by out of their reach: nobody drops ---
	troop = make_troop(cell, 5, 51)
	await wait(1.0)
	var out: Vector3 = troop[0]._out()
	var far_side := hall + out * 40.0
	var dropped := false
	if nav.allowed(maze.cell_at(far_side)) and nav.clear_of_walls(far_side, 1.0):
		put_boy(far_side)
		await wait(4.0)
		for one: MazeSpiderMonkey in troop:
			dropped = dropped or one._drops > 0
		check("nobody drops on him out of reach", not dropped and caught.is_empty(), "(%s)" % modes(troop))
	else:
		# (along the hall instead, well beyond the end of their vines)
		put_boy(hall + along * 40.0)
		await wait(4.0)
		for one: MazeSpiderMonkey in troop:
			dropped = dropped or one._drops > 0
		check("nobody drops on him out of reach", not dropped and caught.is_empty(), "(%s)" % modes(troop))
	clear()

	# --- Puppets ---
	troop = make_troop(cell, 4, 71)
	var copies := make_troop(cell, 4, 71, true)
	await wait(1.0)
	check("puppets string the same vines", copies[0].troop_of.vines.size() == troop[0].troop_of.vines.size() \
		and copies[0].troop_of.vines[0].point_at(0.5).distance_to(troop[0].troop_of.vines[0].point_at(0.5)) < 0.01)
	var worst := 0.0
	var any_dropped := false
	var state := {"worst": 0.0}
	await walk(from, to, 1.6, func() -> bool:
		if Engine.get_physics_frames() % 6 == 0:
			for k in troop.size():
				copies[k].from_bytes(troop[k].state_bytes())
		if Engine.get_physics_frames() % 6 == 3:
			for k in troop.size():
				state["worst"] = maxf(state["worst"], copies[k].global_position.distance_to(troop[k].global_position))
		return not caught.is_empty(), 40.0)
	worst = state["worst"]
	for one: MazeSpiderMonkey in troop:
		any_dropped = any_dropped or one._drops > 0
	check("a puppet follows the host", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("and the host's drop caught him", any_dropped and not caught.is_empty())
	var copy_caught := false
	for c: Array in caught:
		copy_caught = copy_caught or copies.has(c[1])
	check("a puppet catches nobody", not copy_caught)
	clear()

	# --- The component's example runs on its own ---
	var example: Node3D = load("res://creatures/spider_monkey/example.gd").new()
	stage.add_child(example)
	await wait(0.3)
	var monkeys: Array = example.monkeys
	var found_bones := true
	for one: SpiderMonkey in monkeys:
		for b in SpiderMonkey.BONES.size():
			if one._index[b] < 0:
				found_bones = false
	check("the models have every bone", found_bones)
	var at_was: Vector3 = monkeys[0].global_position
	await wait(3.0)
	check("the example runs them", monkeys[0].global_position.distance_to(at_was) > 0.5, "(vertices: %d)" % monkeys[0]._body.mesh.surface_get_array_len(0))
	example.free()

	print("SPIDER MONKEY TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)
