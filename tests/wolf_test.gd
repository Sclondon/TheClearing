extends SceneTree
## The grey wolves (scripts/enemies/maze_wolf.gd on creatures/wolf), headless,
## in a bare scene: a maze from MazeBuilder and the boy in it. In turn: the
## voice is made, a little a frame; a pack patrols in file behind its leader;
## seeing him standing in a hall they stare, rally and trot after him, close in
## (the warning) and only then one bursts and grabs him; while he keeps running
## they do not close, until the chase has worn him out; with a friend by him
## they hang back; up out of reach, or by a fire, they hold off and never catch;
## at dusk the pack goes home to its den and howls together, and another pack
## answers; a puppet follows what the host sends.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/wolf_test.gd
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


## A long straight run of open cells: (first cell, the step along it, how many).
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


func pack_at(at: Vector3, count: int, seed_value := 7, parent: Node = null) -> Array[MazeWolf]:
	var made := MazeWolf.pack_of(count, seed_value)
	for k in made.size():
		var one := made[k]
		one.maze = maze
		one.seed_choices(k + 3)
		one.position = at + Vector3(k * 1.3 - count * 0.65, 0.05, 0.0)
		(parent if parent else stage).add_child(one)
		one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one, Time.get_ticks_msec()]))
	return made


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child.name.begins_with("Holder"):
			child.queue_free()
	caught_by.clear()
	MazeWolf.last_chorus = []
	await frames(3)


func any_mode(wolves: Array[MazeWolf], modes: Array) -> bool:
	return wolves.any(func(w: MazeWolf) -> bool: return w.mode in modes)


func _run() -> void:
	await frames(10)
	var hall := long_hall()
	var first: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var start := nav.point(first)
	print("a hall of %d cells" % hall[2])

	# --- The voice ---
	var job := WolfVoice.Job.new("howl0")
	var began := Time.get_ticks_usec()
	job.run(WolfVoice.BUDGET)
	var cost := (Time.get_ticks_usec() - began) / 1000.0
	check("a frame's share of making a howl is small", cost < 6.0, "(%.1f ms for %d samples)" % [cost, WolfVoice.BUDGET])
	var all_made := true
	for key: String in WolfVoice.KEYS:
		var made := WolfVoice.make_now(key)
		all_made = all_made and made != null and made.data.size() > WolfVoice.RATE * 0.3
	check("every howl, woof and growl is made", all_made)

	# --- Patrolling in file ---
	put_boy(start + way * 400.0, 0.0)
	var den := start + way * 20.0
	var file := pack_at(start + way * 20.0, 5, 11)
	for one in file:
		one.den = den
	await wait(14.0)
	var lead := file[0].leader()
	var moved := lead.global_position.distance_to(den) > 3.0 or lead.mode == MazeWolf.Mode.REST
	var strung := 0
	for one in file:
		if one != lead and one.global_position.distance_to(lead.global_position) < 18.0:
			strung += 1
	check("the pack goes about together behind its leader", moved and strung >= 3, "(lead mode %d, %d near it)" % [lead.mode, strung])
	check("the breeding pair are the first two", file[0].rank == 0 and file[1].rank == 0 and file[4].rank == 2)
	await clear()

	# --- The hunt: standing still in the hall, he is closed on and caught ---
	put_boy(start + way * 24.0, atan2(way.x, way.z))
	var pack_now := pack_at(start, 5, 23)
	var stared := await wait(6.0, func() -> bool: return any_mode(pack_now, [MazeWolf.Mode.STARE, MazeWolf.Mode.HUNT]))
	check("seeing him they stare, then hunt", stared)
	var rallied := await wait(4.0, func() -> bool: return pack_now.any(func(w: MazeWolf) -> bool: return w._rallies > 0))
	check("the pair rally (a short howl) at the start of the hunt", rallied)
	var closed_at := -1
	var caught := false
	for i in int(30.0 * 60.0):
		await physics_frame
		if closed_at < 0 and any_mode(pack_now, [MazeWolf.Mode.CLOSE]):
			closed_at = Time.get_ticks_msec()
		if not caught_by.is_empty():
			caught = true
			break
	check("standing still, they close in on him (the warning)", closed_at >= 0)
	check("and then one bursts and grabs him", caught)
	if caught and closed_at >= 0:
		var warned := (int(caught_by[0][2]) - closed_at) / 1000.0
		check("the warning comes well before the grab", warned >= 1.2, "(%.1f s)" % warned)
	await clear()

	# --- Running, he is not closed on; worn out, he is ---
	put_boy(start + way * 30.0, atan2(way.x, way.z))
	var runners := pack_at(start, 4, 31)
	for one in runners:
		one.wear_time = 25.0
	var closed_running := false
	for i in int(16.0 * 60.0):
		# (he runs on the spot, keeping ahead of them: as far as they can tell, he is running)
		var nearest := INF
		for one in runners:
			nearest = minf(nearest, one.global_position.distance_to(boy.global_position))
		if nearest < 9.0:
			boy.global_position += way * 4.4 / 60.0
		boy.velocity = way * 4.4
		await physics_frame
		closed_running = closed_running or any_mode(runners, [MazeWolf.Mode.CLOSE, MazeWolf.Mode.RUSH])
	check("while he keeps running they only trot after him", not closed_running and caught_by.is_empty())
	var worn := false
	for i in int(20.0 * 60.0):
		boy.velocity = way * 4.4
		await physics_frame
		if any_mode(runners, [MazeWolf.Mode.CLOSE, MazeWolf.Mode.RUSH, MazeWolf.Mode.LUNGE]):
			worn = true
			break
	check("but once the chase has worn on, they close on him running", worn)
	await clear()

	# --- With a friend by him ---
	var friend: Node3D = load("res://player.tscn").instantiate()
	friend.takes_input = false
	stage.add_child(friend)
	friend.add_to_group(&"maze_players")
	friend.global_position = start + way * 23.0 + Vector3.UP * 0.1
	put_boy(start + way * 22.0, atan2(way.x, way.z))
	var wary := pack_at(start, 5, 41)
	await wait(18.0)
	check("two together are not closed on", not any_mode(wary, [MazeWolf.Mode.CLOSE, MazeWolf.Mode.RUSH, MazeWolf.Mode.LUNGE]) and caught_by.is_empty())
	friend.queue_free()
	await clear()

	# --- Up out of reach ---
	put_boy(start + way * 16.0, 0.0)
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	boy.global_position = start + way * 16.0 + Vector3.UP * 3.2
	var below := pack_at(start, 4, 51)
	var held := await wait(12.0, func() -> bool: return any_mode(below, [MazeWolf.Mode.HOLD]))
	await wait(8.0)
	check("up out of reach, they wait under him and never catch him", held and caught_by.is_empty())
	boy.process_mode = Node.PROCESS_MODE_INHERIT
	await clear()

	# --- By a fire ---
	put_boy(start + way * 30.0, 0.0)
	var fire := Node3D.new()
	fire.name = "HolderFire"
	fire.set_script(_ward_script())
	stage.add_child(fire)
	var fireside := pack_at(start, 4, 61)
	var hunted_once := await wait(8.0, func() -> bool: return any_mode(fireside, [MazeWolf.Mode.HUNT, MazeWolf.Mode.CLOSE]))
	fire.global_position = boy.global_position
	fire.add_to_group(&"fire_wards")
	await wait(14.0)
	var kept_off := true
	for one in fireside:
		kept_off = kept_off and one.global_position.distance_to(boy.global_position) > 4.0
	check("by a fire they hold off and never catch him", hunted_once and kept_off and caught_by.is_empty(), "(%s)" % str(fireside.map(func(w: MazeWolf) -> int: return w.mode)))
	await clear()

	# --- Dusk: home to the den, the chorus; another pack answers ---
	put_boy(start + way * 600.0, 0.0)
	var holder := Node3D.new()
	holder.name = "HolderWorld"
	holder.set_script(_world_script())
	stage.add_child(holder)
	var day := Node.new()
	day.set_script(_day_script())
	holder.add_child(day)
	holder.set(&"day", day)
	day.set(&"hour", 12.0)
	var home := pack_at(start, 4, 71, holder)
	for one in home:
		one.den = start
	var other_den := start + way * 28.0
	var others := pack_at(other_den, 4, 81, holder)
	for one in others:
		one.den = other_den
	await wait(3.0)
	day.set(&"hour", DayCycle.SUNSET - 0.5)
	var sang := await wait(70.0, func() -> bool: return home.any(func(w: MazeWolf) -> bool: return w.mode == MazeWolf.Mode.HOWL) or others.any(func(w: MazeWolf) -> bool: return w.mode == MazeWolf.Mode.HOWL))
	var singers := home if home.any(func(w: MazeWolf) -> bool: return w.mode == MazeWolf.Mode.HOWL) else others
	var together := 0
	for one in singers:
		if one.mode == MazeWolf.Mode.HOWL:
			together += 1
	check("at dusk a pack howls together", sang and together >= 3, "(%d howling)" % together)
	check("from its den", singers[0].leader().global_position.distance_to(singers[0].leader().den) < 10.0)
	var listeners := others if singers == home else home
	var answered := await wait(30.0, func() -> bool: return listeners.any(func(w: MazeWolf) -> bool: return w.mode == MazeWolf.Mode.HOWL))
	check("and the other pack answers", answered)
	holder.queue_free()
	await clear()

	# --- The others (Ecology) ---
	if Ecology.KINDS.has("MazeWolf"):
		var world := Ecology.put(stage, 5)
		put_boy(start + way * 600.0, 0.0)
		var hunters := pack_at(start, 4, 91)
		for one in hunters:
			one.hunger = 0.9
		var deer := MazeDeer.new()
		deer.maze = maze
		deer.position = start + way * 18.0 + Vector3.UP * 0.05
		stage.add_child(deer)
		await frames(5)
		for one in hunters:
			one.hunger = 0.9
		var killed := await wait(40.0, func() -> bool: return deer.dead)
		check("hungry, the pack runs down a deer and kills it", killed, "(kills %d)" % world.kills)
		world.queue_free()
		await clear()
	else:
		print("SKIP: the ecology (MazeWolf is not in Ecology.KINDS yet)")

	# --- A puppet ---
	put_boy(start + way * 20.0, atan2(-way.x, -way.z))
	var host := pack_at(start, 1, 99)[0]
	var copy := MazeWolf.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = start
	stage.add_child(copy)
	var furthest := 0.0
	for i in 300:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", furthest < 1.5, "(at most %.2f m off)" % furthest)
	check("and is doing what the host is", copy.mode == host.mode, "(%d, %d)" % [copy.mode, host.mode])

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _ward_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar ward_radius := 6.0\n"
	script.reload()
	return script


func _world_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar day: Node\n"
	script.reload()
	return script


func _day_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar hour := 12.0\n"
	script.reload()
	return script
