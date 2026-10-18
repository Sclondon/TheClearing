extends SceneTree
## The skinwalker (scripts/enemies/maze_skinwalker.gd on creatures/skinwalker),
## headless, in a bare scene: a maze from MazeBuilder, the boy, and a pack of
## coyotes it hides among. In turn: it keeps with its pack as one of them; it
## calls to him when he is near round a corner and out of its sight; looked at
## straight on from close, it rises (and its pack scatters), stares, and
## hunts: a wind-up, a burst far faster than a sprint, and a grab that catches
## him; someone up out of its reach it stands under and gives up on, and goes
## back to its pack; nobody in the clearing is hunted; its calls are made in
## code; a puppet follows what the host sends.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/skinwalker_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Node3D
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


## A pack of three and the skinwalker hidden among them, at `at`.
func hidden_at(at: Vector3, seed_value := 5) -> Array:
	var pack_now := MazeCoyote.pack_of(3, seed_value)
	for k in pack_now.size():
		pack_now[k].maze = maze
		pack_now[k].position = at + Vector3(k * 1.4 - 1.4, 0.05, 1.5)
		stage.add_child(pack_now[k])
	var walker := MazeSkinwalker.new()
	walker.maze = maze
	walker.pack_id = pack_now[0].pack_id
	walker.position = at + Vector3(0.0, 0.05, -1.0)
	stage.add_child(walker)
	walker.caught.connect(func(player: Node3D) -> void: caught_by.append(player))
	return [walker, pack_now]


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(3)


func _run() -> void:
	await frames(10)
	var hall := long_hall()
	var first: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var start := nav.point(first)

	# --- Its calls are made in code ---
	for k in Skinwalker.CALLS:
		var sound := Skinwalker.call_sound(k)
		check("call %d is made (%.2f s)" % [k, sound.get_length()], sound.get_length() > 0.4 and sound.get_length() < 3.0)
	check("and its rise has a sound", Skinwalker.rise_sound().get_length() > 1.0)

	# --- Hidden: it keeps with its pack ---
	var made := hidden_at(start)
	var walker: MazeSkinwalker = made[0]
	var pack_now: Array = made[1]
	# (the boy far off, out of the way)
	put_boy(maze.world(nav.lairs(5)[0]))
	await wait(12.0)
	var lead: MazeCoyote = (pack_now[0] as MazeCoyote).leader()
	check("hidden, it keeps with its pack", walker.mode == MazeSkinwalker.Mode.HIDING and walker.global_position.distance_to(lead.global_position) < 12.0,
			"(mode %d, %.1f m from its leader)" % [walker.mode, walker.global_position.distance_to(lead.global_position)])
	check("on all fours", not walker.walker.is_upright())

	# --- It calls to him round a corner ---
	# (within its call range, for this test, wherever that is)
	walker.call_range = 80.0
	var around := Vector2i(-1, -1)
	var field := nav.field(maze.cell_at(walker.global_position))
	for i in field.size():
		var cell := Vector2i(i % maze.size, i / maze.size)
		if field[i] >= 1 and field[i] <= 5 and not nav.sees(walker.global_position + Vector3.UP, maze.world(cell) + Vector3.UP, 99.0):
			around = cell
			break
	if around.x >= 0:
		var away: Vector3 = nav.point(around) - walker.global_position
		put_boy(nav.point(around), atan2(away.x, away.z))
		var called := await wait(2.0, func() -> bool:
			walker._call_in = 0.0
			return walker._calls > 0)
		check("it calls to him when he is near and out of its sight", called)
	else:
		check("(found a cell round a corner to call to)", false)

	# --- Looked at, it rises ---
	# (somewhere in the open 7 m from it, in a straight line)
	var at_it: Vector3 = walker.global_position + way * 7.0
	for dir: Vector3 in [way, -way, Vector3(way.z, 0.0, -way.x), Vector3(-way.z, 0.0, way.x)]:
		if nav.line_free(walker.global_position, walker.global_position + dir * 8.0, 0.6):
			at_it = walker.global_position + dir * 7.0
			break
	put_boy(at_it)
	var noticed := false
	for i in 120:
		var to: Vector3 = walker.global_position - boy.global_position
		boy.facing_yaw = atan2(to.x, to.z)
		await physics_frame
		if walker.mode != MazeSkinwalker.Mode.HIDING:
			noticed = true
			break
	check("looked at straight on from close, it is noticed", noticed, "(mode %d)" % walker.mode)
	var risen := await wait(3.5, func() -> bool: return walker.walker.is_upright() and walker.mode == MazeSkinwalker.Mode.STARING)
	check("it rises onto its legs and stares", risen)
	check("its pack scatters", pack_now.all(func(c: MazeCoyote) -> bool: return c.mode in [MazeCoyote.Mode.FLEE, MazeCoyote.Mode.SLINK]))

	# --- The hunt: a wind-up, a burst, a grab ---
	var wound := await wait(4.0, func() -> bool: return walker.mode == MazeSkinwalker.Mode.WINDUP)
	check("then it winds up for a burst", wound)
	var fastest := 0.0
	var grabbed := false
	for i in 300:
		await physics_frame
		fastest = maxf(fastest, Vector2(walker.velocity.x, walker.velocity.z).length())
		if not caught_by.is_empty():
			grabbed = true
			break
	check("its burst is far faster than a sprint", fastest > 7.0, "(%.1f m/s)" % fastest)
	check("and it grabs him", grabbed)
	var back := await wait(4.0, func() -> bool: return walker.mode in [MazeSkinwalker.Mode.RETURN, MazeSkinwalker.Mode.HIDING])
	check("having him, it goes back to its pack", back)
	await clear()

	# --- Up out of its reach ---
	made = hidden_at(start, 9)
	walker = made[0]
	await frames(30)
	walker.notice(boy)
	walker._rise()
	put_boy(walker.global_position + way * 5.0 + Vector3.UP * 3.0)
	# (held up there: a terrace, the ivy)
	var under := false
	for i in 600:
		boy.global_position.y = 3.1
		boy.velocity = Vector3.ZERO
		await physics_frame
		if walker.mode == MazeSkinwalker.Mode.UNDER:
			under = true
		if under and walker.mode == MazeSkinwalker.Mode.RETURN:
			break
	check("someone up out of its reach it stands under", under)
	check("and gives up on, going back to its pack", walker.mode in [MazeSkinwalker.Mode.RETURN, MazeSkinwalker.Mode.HIDING], "(mode %d)" % walker.mode)
	check("without catching them", caught_by.is_empty())
	await clear()

	# --- The clearing ---
	made = hidden_at(start, 13)
	walker = made[0]
	walker.keep_out_of_clearing = true
	var middle := Vector3.ZERO
	put_boy(middle)
	await frames(10)
	check("nobody in the clearing is hunted", not walker.huntable(boy))
	await clear()

	# --- A puppet ---
	made = hidden_at(start, 17)
	var host: MazeSkinwalker = made[0]
	var copy := MazeSkinwalker.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = start
	stage.add_child(copy)
	put_boy(host.global_position + way * 6.0)
	var furthest := 0.0
	var copied_rise := false
	for i in 400:
		var to: Vector3 = host.global_position - boy.global_position
		boy.facing_yaw = atan2(to.x, to.z)
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
		copied_rise = copied_rise or copy.walker.is_upright()
	check("the puppet keeps up with the host", furthest < 2.5, "(at most %.2f m off)" % furthest)
	check("and rises when the host does", copied_rise)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
