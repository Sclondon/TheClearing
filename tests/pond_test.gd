extends SceneTree
## Standing water (Ponds) and fish (FishSchool), headless: ponds are laid out in
## the halls as each section's style says (none with no pond share, more with
## more; their depths in its range, some flooded halls, a few to swim; clear of
## what stands on the ground; the same for the same seed); the ground goes down
## under them; the flooded way in to the marsh gate is wading-deep the whole
## way, in front of the gate and through its slot into the hall beyond, with no
## dry way across it; the boy wades in a flooded hall and all the way through
## the marsh gate on foot, never swimming; there are fish in the ponds and the
## marsh, they dart off from him, and those far off do nothing.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/pond_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	# (the game's own rules, not the maze editor's)
	MazeStyle.chosen = fresh()
	for seed_value: int in [Maze.seed_for("POND", 1), 1234, 77]:
		_plan(seed_value)
	_rules()
	await _played()
	MazeStyle.chosen = []
	print("POND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


## The game's own styles, new (MazeStyle.defaults(), as tests use it, but never
## the ones chosen before, which would be changed with them).
func fresh() -> Array[MazeStyle]:
	MazeStyle.chosen = []
	return MazeStyle.defaults()


func _laid(seed_value: int) -> Array:
	var maze := Maze.generate(seed_value, 1)
	var layout := MazeLayout.new()
	layout.lay_out(maze)
	return [maze, layout]


## The hall ponds of a maze (not the flooded way through the marsh gate, which
## stands at the marsh's level).
func _hall_ponds(maze: Maze) -> Array:
	return maze.ponds.filter(func(pond: Dictionary) -> bool: return is_equal_approx(pond.level, Ponds.LEVEL))


func _plan(seed_value: int) -> void:
	print("-- seed %d" % seed_value)
	var started := Time.get_ticks_usec()
	var laid := _laid(seed_value)
	var maze: Maze = laid[0]
	var layout: MazeLayout = laid[1]
	print("laid out in %.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	var style: MazeStyle = maze.styles[0]
	var halls := _hall_ponds(maze)
	var cells := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) == 1 and not maze.solid.has(cell) and not maze.entrances.has(cell):
			cells += 1
	check("ponds in the halls, about as many as the style says", halls.size() >= cells * style.pond_share * 0.4 and halls.size() <= cells * style.pond_share * 1.2, "(%d for %d cells at %.2f)" % [halls.size(), cells, style.pond_share])
	var in_range := true
	var flooded := 0
	var swim := 0
	var fish := 0
	for pond: Dictionary in halls:
		var depth: float = pond.depth
		if depth > style.pond_depth_range.y + 0.01:
			swim += 1
			in_range = in_range and absf(depth - style.swim_pond_depth) < style.swim_pond_depth * 0.11
		else:
			in_range = in_range and depth >= style.pond_depth_range.x - 0.01
		if maxf(pond.rect.size.x, pond.rect.size.y) > Maze.CELL * 1.2:
			flooded += 1
		if pond.fish > 0:
			fish += 1
	check("their depths as the style says", in_range)
	check("some flood a stretch of hall", flooded > 0, "(%d)" % flooded)
	check("some have fish", fish > 0, "(%d)" % fish)
	print("ponds %d: flooded halls %d, to swim %d, with fish %d" % [halls.size(), flooded, swim, fish])
	# Clear of what stands on the ground.
	var blocks := Ponds._footprints(layout)
	var clashes := 0
	for pond: Dictionary in halls:
		for footprint: Rect2 in Ponds._near(blocks, pond.rect):
			if footprint.grow(0.3).intersects(pond.rect):
				clashes += 1
	check("clear of the walls, ledges and terraces", clashes == 0, "(%d)" % clashes)
	# The ground lower under them, level at their edges.
	var sunk := 0
	var edges := 0.0
	for pond: Dictionary in halls:
		var middle: Vector2 = pond.rect.get_center()
		if maze.ground_height(Vector3(middle.x, 0.0, middle.y)) < pond.level - 0.05:
			sunk += 1
		var edge := absf(Ponds.ground_of(pond, Vector2(pond.rect.position.x, middle.y)))
		if edge > edges:
			edges = edge
			print("  edge of %s: %.3f" % [pond.rect, edge])
	check("the ground goes down under them", sunk >= halls.size() * 0.9, "(%d of %d)" % [sunk, halls.size()])
	check("level with the ground round them at their edges", edges < 0.01, "(%.3f)" % edges)
	var again := _laid(seed_value)
	check("the same seed, the same ponds", str((again[0] as Maze).ponds) == str(maze.ponds))
	(again[1] as Node).free()

	# The flooded way through the marsh gate.
	var look := maze.clearing_style
	var way := look.entrance(ClearingStyle.Entrance.MARSH)
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	var shallowest := INF
	var deepest := -INF
	var through := _through(maze, gate, inward)
	for k in range(-int(look.marsh_flood_reach * 0.8), int(through) + 1):
		var p := gate - inward * k
		var depth := ClearingStyle.MARSH_LEVEL - maze.ground_height(Vector3(p.x, 0.0, p.y))
		shallowest = minf(shallowest, depth)
		deepest = maxf(deepest, depth)
	check("wading deep the whole way in to the marsh gate and through it", shallowest > 0.38 and deepest < 0.97, "(%.2f to %.2f m, %.0f m through the wall)" % [shallowest, deepest, through])
	var dry := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 2000:
		var p := gate + inward * rng.randf_range(0.2, look.marsh_flood_reach * 0.6) + side * rng.randf_range(-look.marsh_flood_width * 0.3, look.marsh_flood_width * 0.3)
		if ClearingStyle.MARSH_LEVEL - maze.ground_height(Vector3(p.x, 0.0, p.y)) < 0.3:
			dry += 1
	check("no dry way across in front of the gate", dry == 0, "(%d of 2000 points shallower than 0.3 m)" % dry)
	layout.free()


## How far the flooded way goes on out from the gate through the wall, metres
## (to where the hall beyond is).
func _through(maze: Maze, gate: Vector2, inward: Vector2) -> float:
	for pond: Dictionary in maze.ponds:
		if is_equal_approx(pond.level, ClearingStyle.MARSH_LEVEL) and pond.round == 0.0:
			var rect: Rect2 = pond.rect
			var far := maxf(absf((rect.position - gate).dot(inward)), absf((rect.end - gate).dot(inward)))
			return far - 3.0
	return 0.0


func _rules() -> void:
	print("-- the rules")
	var seed_value := Maze.seed_for("POND", 1)
	var none := fresh()
	none[0].pond_share = 0.0
	MazeStyle.chosen = none
	var laid := _laid(seed_value)
	check("no ponds with no pond share", _hall_ponds(laid[0]).is_empty())
	(laid[1] as Node).free()
	var many := fresh()
	many[0].pond_share = 0.12
	many[0].flooded_hall_share = 1.0
	MazeStyle.chosen = many
	var more := _laid(seed_value)
	MazeStyle.chosen = fresh()
	var usual := _laid(seed_value)
	var long := 0
	for pond: Dictionary in _hall_ponds(more[0]):
		if maxf(pond.rect.size.x, pond.rect.size.y) > Maze.CELL * 1.2:
			long += 1
	check("more with more", _hall_ponds(more[0]).size() > _hall_ponds(usual[0]).size() * 2, "(%d, %d)" % [_hall_ponds(more[0]).size(), _hall_ponds(usual[0]).size()])
	check("all flooded halls when asked", long >= _hall_ponds(more[0]).size() * 0.6, "(%d of %d)" % [long, _hall_ponds(more[0]).size()])
	(more[1] as Node).free()
	(usual[1] as Node).free()
	var dry := fresh()
	MazeStyle.chosen = dry
	var look := ClearingStyle.new()
	look.marsh_flood_depth = 0.0
	var maze := Maze.generate(seed_value, 1, dry, look)
	var layout := MazeLayout.new()
	layout.lay_out(maze)
	check("no flooded way with no flood depth", maze.ponds.filter(func(p: Dictionary) -> bool: return is_equal_approx(p.level, ClearingStyle.MARSH_LEVEL)).is_empty())
	layout.free()


func _played() -> void:
	print("-- played")
	MazeStyle.chosen = fresh()
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	await frames(5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("POND", 1))
	await frames(20)
	var world = main.world
	# (nothing hunting him while he wades about)
	for holder in [world.enemies, world.runners, world.get("griever")]:
		if holder is Node:
			(holder as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var maze: Maze = world.maze
	var builder = world.get_node("Maze")
	var ponds: Ponds = builder.ponds
	var player = world.player
	check("ponds built", ponds.count == maze.ponds.size() and ponds.pools.size() > 0, "(%d ponds, %d sheets of water)" % [ponds.count, ponds.pools.size()])

	# He wades in a flooded hall.
	var hall := {}
	for pond: Dictionary in _hall_ponds(maze):
		if pond.depth > 0.45 and pond.depth < 1.0 and maxf(pond.rect.size.x, pond.rect.size.y) > Maze.CELL:
			hall = pond
			break
	check("a flooded hall to wade in", not hall.is_empty())
	if not hall.is_empty():
		var middle: Vector2 = hall.rect.get_center()
		player.global_position = Vector3(middle.x, 0.5, middle.y)
		player.velocity = Vector3.ZERO
		await frames(40)
		var deep: float = hall.level - maze.ground_height(player.global_position)
		check("he wades in the flooded hall", player.wade > 0.2 and player.state != Player.State.SWIM, "(wade %.2f, %.2f m deep there, %.2f m up)" % [player.wade, deep, player.global_position.y])
		var awake := 0
		var asleep := 0
		for pool in ponds.pools:
			if pool.process_mode == Node.PROCESS_MODE_DISABLED:
				asleep += 1
			else:
				awake += 1
		check("only the water near him is awake", awake >= 1 and asleep > awake, "(%d awake, %d asleep)" % [awake, asleep])

	# On foot through the flooded marsh gate: from out in the flood, in through
	# the gate's slot, into the hall beyond.
	var look := maze.clearing_style
	var way := look.entrance(ClearingStyle.Entrance.MARSH)
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var out := Vector3(-inward.x, 0.0, -inward.y)
	var from := gate + inward * 30.0
	player.global_position = Vector3(from.x, 0.3, from.y)
	player.velocity = Vector3.ZERO
	await frames(20)
	var through := _through(maze, gate, inward)
	var least := INF
	var swam := false
	var steps := 0
	var went := 0.0
	while steps < 3600:
		steer(out)
		await physics_frame
		steps += 1
		var at := Vector2(player.global_position.x, player.global_position.z)
		went = (at - gate).dot(-inward)
		# (his feet in it: 0.25 is about his shin; on dry ground it is 0)
		if player.is_on_floor():
			least = minf(least, player.wade)
		swam = swam or player.state == Player.State.SWIM
		if went > through:
			break
	let_go()
	check("he walks in through the flooded marsh gate", went > through, "(%.0f m of %.0f, in %.1f s)" % [went + 30.0, through + 30.0, steps / 60.0])
	check("wading the whole way", least > 0.3, "(%.2f at the shallowest)" % least)
	check("never swimming", not swam)

	# Fish: in the marsh and the ponds, darting off from him.
	var schools: Array[FishSchool] = []
	schools.assign(get_nodes_in_group(FishSchool.GROUP))
	var in_marsh := 0
	for school in schools:
		if school.get_parent() is Marsh:
			in_marsh += 1
	check("schools of fish in the marsh and the ponds", in_marsh > 2 and schools.size() > in_marsh, "(%d in the marsh, %d in the ponds)" % [in_marsh, schools.size() - in_marsh])
	var processing := 0
	for school in schools:
		if school.is_processing():
			processing += 1
	check("only those near swim", processing < schools.size() * 0.5, "(%d of %d)" % [processing, schools.size()])
	# (one in the marsh: stand off from it, then wade at it)
	var school: FishSchool = null
	for each in schools:
		if each.get_parent() is Marsh:
			school = each
			break
	if school:
		var at := school.centre()
		player.global_position = at + Vector3(9.0, 1.0, 0.0)
		player.velocity = Vector3.ZERO
		await frames(70)
		check("woken when he is near", school.is_processing())
		var calm := school.alarm()
		var before := school.centre()
		player.global_position = before + Vector3(1.6, 0.4, 0.0)
		player.velocity = Vector3.ZERO
		await frames(10)
		var startled := school.alarm()
		await frames(70)
		var after := school.centre()
		var off := Vector2(after.x - player.global_position.x, after.z - player.global_position.z).length()
		check("they dart off from him", calm < 0.2 and startled > 0.8 and off > 3.0, "(alarm %.2f then %.2f; %.1f m off him after a second)" % [calm, startled, off])
		var fish := school.fish_positions()
		var spread := 0.0
		for p in fish:
			spread = maxf(spread, p.distance_to(after))
		check("the school keeps together", spread < 4.0, "(%.1f m)" % spread)
		var under := true
		for p in fish:
			under = under and p.y < ClearingStyle.MARSH_LEVEL
		check("under the water", under)
	main.queue_free()
	await frames(3)


## Pushes the stick so that he goes the world way `towards` (level).
func steer(towards: Vector3) -> void:
	var basis: Basis = main.world.camera.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var stick := Vector2(towards.dot(right), towards.dot(forward))
	press(&"move_right", stick.x)
	press(&"move_left", -stick.x)
	press(&"move_up", stick.y)
	press(&"move_down", -stick.y)


func press(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func let_go() -> void:
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down", &"jump"]:
		Input.action_release(action)
