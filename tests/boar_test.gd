extends SceneTree
## The giant boar (scripts/enemies/maze_boar.gd on creatures/boar), headless,
## in a bare scene: a maze from MazeBuilder and the boy in it. In turn: alone,
## it roots about; it smells him upwind of it from far off and downwind only
## close; noticing him it winds up (a snort, two stamps, head down, a squeal)
## and charges; standing in its way he is tossed limp and caught; stepping
## aside he is passed, and it slams into the wall at the end of the hall and is
## stunned, then calms down and roots again; up out of its reach it gives up
## on him; a puppet follows what the host sends, and plays its moves.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/boar_test.gd
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


func boar_at(at: Vector3, yaw := 0.0) -> MazeBoar:
	var boar := MazeBoar.new()
	boar.maze = maze
	boar.position = at + Vector3.UP * 0.05
	boar.rotation.y = yaw
	stage.add_child(boar)
	boar.caught.connect(func(player: Node3D) -> void: caught_by.append([player, boar]))
	return boar


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


func mode_name(boar: MazeBoar) -> String:
	return MazeBoar.Mode.keys()[boar.mode]


func _run() -> void:
	await frames(10)
	# A long hall running along x (the way the wind blows), ending in a wall.
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	var length := 0
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run >= 4 and maze.blocked(at, s) and run > length:
				hall = cell
				step = s
				length = run
	check("a long straight hall along the wind, ending in a wall", hall.x >= 0, "(%d cells)" % length)
	var way := Vector3(step.x, 0.0, step.y)
	var start: Vector3 = maze.world(hall)
	var end: Vector3 = maze.world(hall + step * length)
	var downwind: Vector3 = Vector3(MazeBoar.WIND.x, 0.0, MazeBoar.WIND.y).normalized()

	# --- Alone, it roots about ---
	put_boy(maze.world(nav.lairs(4)[0]) + Vector3(0.0, 0.0, 0.0))
	var far_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 8:
			far_cell = cell
			break
	put_boy(maze.world(far_cell))
	var boar := boar_at(start, atan2(way.x, way.z))
	await frames(120)
	check("alone, it roots about", boar.mode in [MazeBoar.Mode.ROOT, MazeBoar.Mode.SNIFF], "(%s)" % mode_name(boar))
	var moved: float = boar.global_position.distance_to(start)
	check("slowly", moved > 0.3 and moved < 4.0, "(%.1f m in 2 s)" % moved)
	await clear()

	# --- Its nose: far upwind, near downwind ---
	var middle: Vector3 = start + way * Maze.CELL * 2.0
	# (downwind of it: 11 m along the wind, past its eyes and its nose that way)
	put_boy(middle + way * 11.0 * signf(way.dot(downwind)))
	boar = boar_at(middle, atan2(-way.x, -way.z))
	boar.root_speed = 0.0
	var smelled := await wait(3.0, func() -> bool: return boar.hunting())
	check("11 m downwind of it, it does not smell him", not smelled, "(%s)" % mode_name(boar))
	await clear()
	put_boy(middle - way * 16.0 * signf(way.dot(downwind)))
	boar = boar_at(middle, atan2(way.x, way.z) if way.dot(downwind) > 0.0 else atan2(-way.x, -way.z))
	boar.root_speed = 0.0
	var snorts := [0]
	var stamps := [0]
	var squeals := [0]
	boar.boar.snorted.connect(func() -> void: snorts[0] += 1)
	boar.boar.stamped.connect(func(_at: Vector3) -> void: stamps[0] += 1)
	boar.boar.squealed.connect(func() -> void: squeals[0] += 1)
	smelled = await wait(3.0, func() -> bool: return boar.hunting())
	check("16 m upwind of it (behind it), it smells him", smelled, "(%s)" % mode_name(boar))

	# --- The wind-up, the charge, the toss ---
	var winding := await wait(2.0, func() -> bool: return boar.mode == MazeBoar.Mode.WIND_UP)
	check("noticing him, it winds up", winding, "(%s)" % mode_name(boar))
	var charging := await wait(4.0, func() -> bool: return boar.mode == MazeBoar.Mode.CHARGE)
	check("then charges", charging, "(%s)" % mode_name(boar))
	check("having snorted, stamped twice and squealed first", snorts[0] >= 1 and stamps[0] >= 2 and squeals[0] >= 1, "(%d snorts, %d stamps, %d squeals)" % [snorts[0], stamps[0], squeals[0]])
	var to_boy: Vector3 = boy.global_position - boar.global_position
	to_boy.y = 0.0
	check("straight at him, head down", boar.charge_way.dot(to_boy.normalized()) > 0.97 and boar.boar.lowered)
	var limp := [false]
	var tossed := await wait(4.0, func() -> bool:
		limp[0] = limp[0] or boy.is_limp
		return not caught_by.is_empty())
	check("he stood in its way: tossed limp and caught", tossed and limp[0] and caught_by[0][0] == boy, "(limp %s, caught %d)" % [limp[0], caught_by.size()])
	check("tossing", boar.mode in [MazeBoar.Mode.TOSS, MazeBoar.Mode.RECOVER], "(%s)" % mode_name(boar))
	var top_speed := boar.charge_speed
	check("far faster than a sprint", top_speed > 8.0)
	await clear()

	# --- Stepping aside: it thunders past into the end wall, and is stunned ---
	put_boy(end - way * 9.0)
	boar = boar_at(end - way * 50.0, atan2(way.x, way.z))
	boar.root_speed = 0.0
	boar.sight_range = 60.0
	charging = await wait(6.0, func() -> bool: return boar.mode == MazeBoar.Mode.CHARGE)
	check("it charges again", charging, "(%s)" % mode_name(boar))
	# (he steps aside, out of its line)
	var aside := Vector3(-way.z, 0.0, way.x)
	var dodge: Vector3 = boy.global_position + aside * 5.5
	if not nav.line_free(boy.global_position, dodge, 0.4):
		dodge = boy.global_position - aside * 5.5
	await frames(20)
	put_boy(dodge)
	var stunned := await wait(8.0, func() -> bool: return boar.mode == MazeBoar.Mode.STUN)
	check("it misses him, slams into the wall and is stunned", stunned and caught_by.is_empty(), "(%s, caught %d, %.1f m from the end)" % [mode_name(boar), caught_by.size(), (end - boar.global_position).dot(way)])
	check("the stun is shown", boar.boar.stunned)
	var calmed := await wait(boar.stun_time + 3.0, func() -> bool: return boar.mode == MazeBoar.Mode.ROOT)
	check("then it calms down and roots again", calmed and not boar.hunting(), "(%s)" % mode_name(boar))
	await clear()

	# --- Up out of its reach, it gives up ---
	var perch := Node3D.new()
	stage.add_child(perch)
	perch.global_position = start + Vector3.UP * 5.0 + way * 6.0
	put_boy(maze.world(far_cell))
	boar = boar_at(start, atan2(way.x, way.z))
	boar.targets = [perch]
	boar.sight_range = 30.0
	var wound := false
	var noticed := false
	for i in 9 * 60:
		await physics_frame
		noticed = noticed or boar.mode == MazeBoar.Mode.SNIFF and boar.hunting()
		wound = wound or boar.mode in [MazeBoar.Mode.WIND_UP, MazeBoar.Mode.CHARGE]
	check("someone up high it notices, but never charges, and gives up", noticed and not wound and not boar.hunting(), "(%s)" % mode_name(boar))
	perch.queue_free()
	await clear()

	# --- A puppet follows the host and plays its moves ---
	put_boy(end - way * 16.0)
	var host := boar_at(end - way * 50.0, atan2(way.x, way.z))
	host.sight_range = 0.0
	host.smell_range = Vector2.ZERO
	var copy := MazeBoar.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	var furthest := 0.0
	var copied := [0]
	copy.boar.snorted.connect(func() -> void: copied[0] += 1)
	copy.boar.squealed.connect(func() -> void: copied[0] += 1)
	for i in 480:
		await physics_frame
		if i == 40:
			host.sight_range = 60.0
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", furthest < 3.0, "(at most %.2f m off)" % furthest)
	check("the puppet snorts and squeals when the host does", copied[0] >= 2, "(%d)" % copied[0])
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	# --- Its sounds are made ---
	check("its sounds are made", Boar.snort_sound().data.size() > 1000 and Boar.squeal_sound().data.size() > 1000 and Boar.slam_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
