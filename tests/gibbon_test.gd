extends SceneTree
## The gibbons (scripts/enemies/maze_gibbon.gd, gibbon_ways.gd, creatures/gibbon/),
## headless, in a bare scene: a maze from MazeBuilder and the boy standing in
## it. Their ways (along the ledges, linked round corners and in leaps, where
## the ledges really are); a troop finding them; calling at the boy down in the
## hall and fetching another hunter, but never catching him there; coming for
## him up on a ledge and knocking him off; missing him if he gets down in time;
## going about their ways with nobody near; and puppets following the host.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/gibbon_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var ways
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


func spawn(one: MazeEnemy, cell: Vector2i, offset := Vector3.ZERO) -> MazeEnemy:
	one.maze = maze
	one.position = maze.world(cell) + offset + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught_by.clear()


func put_boy(at: Vector3) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO


## A hall cell of the first section, away from the clearing, with a face of the ways beside it.
func hall_cell() -> Vector2i:
	for cell: Vector2i in nav.lairs(4):
		if maze.ring_of(cell) == 1 and ways.nearest(maze.world(cell) + Vector3.UP * 11.0, 9.0, -1, 30) >= 0:
			return cell
	return nav.lairs(4)[0]


func _run() -> void:
	await frames(10)

	# --- The ways ---
	ways = GibbonWays.of(maze, 1)
	var high: float = maze.styles[0].mezzanine_height
	check("the first section has its ways", ways.size() > 200, "(%d faces)" % ways.size())
	var on_ledge := 0
	for f in ways.size():
		if absf(ways.point(f).y - high) < 0.5:
			on_ledge += 1
	check("nearly all along the ledges, %.1f m up (the rest on wall tops low enough)" % high, on_ledge > ways.size() * 0.75, "(%d of %d)" % [on_ledge, ways.size()])
	var linked := 0
	var leaps := 0
	var rounds := 0
	for f in ways.size():
		if not ways.links[f].is_empty():
			linked += 1
		for l: Array in ways.links[f]:
			for leg: Array in l[2]:
				if leg[1] == GibbonWays.Kind.LEAP:
					leaps += 1
				elif leg[1] == GibbonWays.Kind.SWING:
					rounds += 1
	check("nearly every face leads on", linked > ways.size() * 0.95, "(%d of %d)" % [linked, ways.size()])
	check("with leaps across halls and gaps, and swings round corners", leaps > 20 and rounds > 20, "(%d leaps, %d round)" % [leaps, rounds])
	# (the ledges are where the ways say: solid under the edge's inside, and a drop just outside it)
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	var real := 0
	var looked := 0
	for f in range(0, ways.size(), maxi(ways.size() / 120, 1)):
		if absf(ways.point(f).y - high) > 0.5:
			continue
		var p: Vector3 = ways.point(f)
		var out: Vector3 = ways.outs[f]
		var inside := space.intersect_ray(PhysicsRayQueryParameters3D.create(p - out * 0.35 + Vector3.UP * 1.5, p - out * 0.35 + Vector3.DOWN * 1.0))
		var outside := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + out * 0.35 + Vector3.UP * 1.5, p + out * 0.35 + Vector3.DOWN * 3.0))
		looked += 1
		# (outside it, a drop, or (across a slot) the ledge on the other side)
		if not inside.is_empty() and absf((inside["position"] as Vector3).y - p.y) < 0.3 and (outside.is_empty() or absf((outside["position"] as Vector3).y - p.y) < 0.3):
			real += 1
	check("the edges are the ledges' real edges", real > looked * 0.9, "(%d of %d)" % [real, looked])
	var biggest := 0
	for g in ways.group_sizes.size():
		if ways.group_sizes[g] > ways.group_sizes[biggest]:
			biggest = g
	var a: int = ways.groups.find(biggest)
	var reached: Array = ways.around(a, 1000)
	var b: int = reached[reached.size() - 1]
	var route: Array = ways.route(a, b, 2000.0)
	check("a way from one face to another far off", route.size() > 3, "(%d faces; the biggest stretch of joined-up ways %d faces, %d stretches)" % [route.size(), ways.group_sizes[biggest], ways.group_sizes.size()])

	# --- A troop finds its ways ---
	var cell := hall_cell()
	put_boy(maze.world(nav.lairs(4)[nav.lairs(4).size() - 1]) + Vector3.UP * 0.1)
	boy.remove_from_group(&"maze_players")
	var troop := MazeGibbon.troop(4)
	for k in troop.size():
		spawn(troop[k], cell, Vector3(k - 1.5, 0, 0))
	await frames(5)
	var all_up := true
	for one in troop:
		if not one.placed or absf(one.global_position.y - high) > 0.8:
			all_up = false
	check("a troop goes up onto the ledges", all_up, "(at %.1f m)" % troop[0].global_position.y)
	var was: Vector3 = troop[0].global_position
	troop[0]._sit_left = 0.5
	await wait(30.0, func() -> bool: return troop[0].global_position.distance_to(was) > 3.0)
	var moved: float = troop[0].global_position.distance_to(was)
	var stayed_up := absf(troop[0].global_position.y - high) < 1.5
	check("with nobody about they go along their ways", moved > 3.0 and stayed_up, "(%.1f m, at %.1f m)" % [moved, troop[0].global_position.y])
	boy.add_to_group(&"maze_players")
	clear()

	# --- On the ground: they call, and fetch another hunter, but do not catch him ---
	troop = MazeGibbon.troop(3)
	for k in troop.size():
		spawn(troop[k], cell, Vector3(k - 1.0, 0, 0))
	var baboon := MazeBaboon.new()
	var far_cell: Vector2i = cell
	for c: Vector2i in nav.lairs(2):
		var steps: int = nav.distance(cell, c)
		if steps >= 2 and steps <= 3:
			far_cell = c
			break
	spawn(baboon, far_cell)
	baboon.sight_range = 0.0
	baboon.hear_range = 0.0
	await frames(5)
	put_boy(maze.world(cell) + Vector3.UP * 0.1)
	var called := await wait(3.0, func() -> bool:
		for one in troop:
			if one._calls > 0:
				return true
		return false)
	check("seeing him down in the hall, one gives the great call", called)
	var fetched := await wait(4.0, func() -> bool: return baboon.quarry == boy)
	check("and its call fetches another hunter", fetched, "(baboon %.0f m off)" % baboon.global_position.distance_to(troop[0].global_position))
	var duet := 0
	await wait(1.5)
	for one in troop:
		if one._calls > 0:
			duet += 1
	check("the troop joins in (a duet)", duet >= 2, "(%d calling)" % duet)
	baboon.free()
	await wait(6.0)
	check("on the ground he is safe from them", caught_by.is_empty())
	clear()

	# --- Up on a ledge: they come for him and knock him off ---
	troop = MazeGibbon.troop(3)
	for k in troop.size():
		spawn(troop[k], cell, Vector3(k - 1.0, 0, 0))
	await frames(5)
	var start: int = troop[0].home
	var further: Array = ways.around(start, 4)
	var spot_face: int = further[further.size() - 1]
	var ledge_at: Vector3 = ways.point(spot_face) - ways.outs[spot_face] * 0.6 + Vector3.UP * 0.1
	put_boy(ledge_at)
	await frames(3)
	check("standing up on a ledge he is a climber", troop[0].climbing(boy) and troop[0].reachable(boy) >= 0)
	for one in troop:
		one.notice(boy)
	var from_far: float = troop[0].global_position.distance_to(boy.global_position)
	var lunged := await wait(14.0, func() -> bool:
		for one in troop:
			if one._lunges > 0:
				return true
		return false)
	check("they come swinging and one winds up at him", lunged, "(from %.1f m)" % from_far)
	var closest := INF
	var how := ""
	var caught := await wait(2.0, func() -> bool:
		for g in troop:
			if g.body.lunge_stage() == Gibbon.Lunge.STRIKE:
				how = "gait %s" % Gibbon.Gait.keys()[g._gait]
				for p: Vector3 in g.body.grabbers():
					closest = minf(closest, p.distance_to(g.chest_of(boy)))
		return not caught_by.is_empty())
	check("and knocks him off", caught and caught_by[0][0] == boy, "(%s, nearest %.2f m)" % [how, closest])
	clear()

	# --- He gets down in time: it misses ---
	put_boy(ledge_at)
	await frames(3)
	var one := MazeGibbon.new()
	spawn(one, cell)
	await frames(5)
	one.notice(boy)
	# (it calls first, the warning, then comes)
	var winding := await wait(24.0, func() -> bool: return one.mode == MazeGibbon.Mode.LUNGE)
	check("one winds up at him", winding, "(he is %.1f m up, it is %s %.1f m from him, his edge %d, its home %d)" % [boy.global_position.y, MazeGibbon.Mode.keys()[one.mode], one.global_position.distance_to(boy.global_position), one.reachable(boy), one.home])
	put_boy(Vector3(ledge_at.x, 0.1, ledge_at.z) + ways.outs[spot_face] * 2.0)
	await wait(2.0)
	check("he drops to the ground as it winds up, and it misses", caught_by.is_empty(), "(lunges %d)" % one._lunges)
	await wait(3.0)
	check("and it does not come after him on the ground", caught_by.is_empty() and one.mode != MazeGibbon.Mode.HUNTING, "(mode %s)" % MazeGibbon.Mode.keys()[one.mode])
	clear()

	# --- Puppets follow the host ---
	put_boy(ledge_at)
	await frames(3)
	var host := MazeGibbon.new()
	host.seed_choices(3)
	spawn(host, cell)
	var copy := MazeGibbon.new()
	copy.seed_choices(3)
	copy.puppet = true
	spawn(copy, cell)
	await frames(3)
	host.notice(boy)
	var worst := 0.0
	var copy_lunged := false
	for i in 1500:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(host.global_position))
		if copy.body.lunge_stage() != Gibbon.Lunge.NONE:
			copy_lunged = true
	check("a puppet follows the host's news", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("and lunges when the host lunges", copy_lunged == (host._lunges > 0), "(host lunges %d)" % host._lunges)
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	clear()

	# --- A section of terraces (a close one of single halls, no ledges): their edges are ways too ---
	var close := MazeStyle.made(4, 1, 0.0, 0.0, 0.06)
	var terraced = Maze.generate(Maze.seed_for("TERR", 1), 1, [close] as Array[MazeStyle])
	var other := MazeBuilder.new()
	other.name = "Terraced"
	stage.add_child(other)
	other.build(terraced)
	var plain_ways := GibbonWays.of(terraced, 1)
	var with_terraces := GibbonWays.of(terraced, 1, other.layout)
	var on_terraces := 0
	for f in with_terraces.size():
		if absf(with_terraces.point(f).y - 13.0) < 0.3 or absf(with_terraces.point(f).y - 6.5) < 0.3:
			on_terraces += 1
	var linked_up := 0
	for f in range(plain_ways.size(), with_terraces.size()):
		if not with_terraces.links[f].is_empty():
			linked_up += 1
	check("terraces' edges are ways too, linked by leaps", on_terraces > 30 and linked_up > on_terraces * 0.6, "(%d terrace edges, %d linked; biggest stretch %d)" % [on_terraces, linked_up, Array(with_terraces.group_sizes).max()])
	other.free()

	# --- The component's example runs on its own ---
	var example: Node3D = load("res://creatures/gibbon/example.gd").new()
	stage.add_child(example)
	await wait(0.2)
	var found := true
	for g: Gibbon in [example.swinger, example.walker]:
		for k in Gibbon.BONES.size():
			if g._index[k] < 0:
				found = false
	check("the model has every bone", found, "(vertices %d)" % example.swinger._body.mesh.surface_get_array_len(0))
	var swung_from: Vector3 = example.swinger.global_position
	await wait(2.0)
	check("the example swings one along its bar", example.swinger.global_position.distance_to(swung_from) > 2.0)
	example.free()

	print("GIBBON TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)
