extends SceneTree
## The masked tribe (scripts/enemies/maze_tribesman.gd on creatures/masked_tribe),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In turn:
## a party from `party_of`; one patrols with its chief in single file and the
## chief plants its totem; one that sees the boy calls (drums and chants) and the
## party takes up the hunt; the throw (wound up first, where it can be seen) and
## the spear catching him; the thrower going for his spear and taking it up; a
## throw given up when he is out of the line; a spear sticking in a wall and
## going over someone ducked; the jab close to; someone out of reach up high
## waited for below and given up; a puppet throwing as the host does and
## catching nobody; and the speeds.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/tribe_test.gd
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
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func man_at(at: Vector3, yaw := 0.0, one: MazeTribesman = null) -> MazeTribesman:
	var man := one if one else MazeTribesman.new()
	man.maze = maze
	man.position = at + Vector3.UP * 0.05
	man.rotation.y = yaw
	stage.add_child(man)
	man.caught.connect(func(player: Node3D) -> void: caught_by.append([player, man]))
	return man


func clear_men() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child is TribeSpear or String(child.name).begins_with("TribeTotem"):
			child.queue_free()
	caught_by.clear()
	await frames(3)
	MazeTribesman._party_threw.clear()


## A cell from which a passage runs straight on for `run` cells in some direction: [cell, step].
func straight_from(cells: Array, run: int) -> Array:
	for cell: Vector2i in cells:
		for step: Vector2i in Maze.STEPS:
			var at: Vector2i = cell
			var went := 0
			while went < run and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				went += 1
			if went == run:
				return [cell, step]
	return []


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var line := straight_from(lairs, 2)
	check("a straight passage two cells long", not line.is_empty())
	var home: Vector2i = line[0]
	var step: Vector2i = line[1]
	var along := Vector3(step.x, 0.0, step.y)
	var at_home: Vector3 = maze.world(home)
	put_boy(at_home)
	await frames(20)

	# --- A party ---
	var four := MazeTribesman.party_of(4, 7)
	var masks := {}
	for one in four:
		masks[one.mask] = true
	check("a party of four, the chief first, each in his own mask", four.size() == 4 and four[0].chief and not four[1].chief and four[3].rank == 3 and masks.size() == 4)
	var again := MazeTribesman.party_of(4, 7)
	check("the same party from the same seed", again[2].mask == four[2].mask and again[3].point == four[3].point and again[1].clay_tint == four[1].clay_tint)
	for one in four + again:
		one.free()

	# --- Patrol: single file behind the chief; the totem in the den ---
	# (a dead end a long way from the boy, if the maze has one, or anywhere a long way off:
	# he is let alone, and they neither see nor hear)
	var far_cell: Vector2i = lairs[lairs.size() - 1]
	var best := -1
	for dead_only: bool in [true, false]:
		for cell: Vector2i in nav.lairs(1):
			var d: int = nav.distance(home, cell)
			if (nav.dead_end(cell) or not dead_only) and d > best and d <= 24:
				best = d
				far_cell = cell
		if best >= 6:
			break
	check("a place for the camp, well away", best >= 6, "(%d cells%s)" % [best, ", a dead end" if nav.dead_end(far_cell) else ""])
	var party := MazeTribesman.party_of(3, 11, maze.world(far_cell))
	# (one behind another along the way out of it)
	var out_way := Vector3.ZERO
	for s: Vector2i in Maze.STEPS:
		if not maze.blocked(far_cell, s):
			out_way = Vector3(s.x, 0.0, s.y)
	for k in party.size():
		party[k].sight_range = 0.0
		party[k].hear_range = 0.0
		man_at(maze.world(far_cell) + out_way * (k * 1.8), atan2(out_way.x, out_way.z), party[k])
	await frames(5)
	var totem_found := false
	for child in stage.get_children():
		if String(child.name).begins_with("TribeTotem"):
			totem_found = (child as Node3D).global_position.distance_to(maze.world(far_cell)) < Maze.CELL * 0.6
	check("the chief plants the totem in the party's dead end", totem_found)
	var start: Vector3 = party[0].global_position
	var furthest := 0.0
	var worst_gap := 0.0
	for i in 60 * 25:
		await physics_frame
		furthest = maxf(furthest, party[0].global_position.distance_to(start))
		if i > 60 * 6:
			worst_gap = maxf(worst_gap, party[1].global_position.distance_to(party[0].global_position))
			worst_gap = maxf(worst_gap, party[2].global_position.distance_to(party[1].global_position))
	check("the chief patrols out from the den", furthest > 10.0, "(%.1f m)" % furthest)
	check("the rest keep behind him in file", worst_gap < 9.0, "(the widest gap %.1f m)" % worst_gap)
	check("on patrol they walk", party[0].mode == MazeTribesman.Mode.PATROL and Vector2(party[0].velocity.x, party[0].velocity.z).length() < 2.0)
	await clear_men()

	# --- One that sees him calls, and the party hunts ---
	put_boy(at_home)
	await frames(10)
	var near_end: Vector3 = maze.world(home + step)
	party = MazeTribesman.party_of(3, 13)
	var thrower: MazeTribesman = null
	for k in party.size():
		var yaw := atan2(-along.x, -along.z)
		man_at(near_end + along * (k * 2.0) + Vector3(0.0, 0.0, 0.0), yaw, party[k])
	thrower = party[0]
	for k in range(1, 3):
		# (only the first sees him: the others are told)
		party[k].sight_range = 0.0
		party[k].hear_range = 0.0
	var called := await wait(3.0, func() -> bool: return thrower.mode == MazeTribesman.Mode.CALL)
	check("he sees the boy and calls", called)
	await frames(2)
	check("drumming and chanting", thrower.tribesman.doing() == TribesmanRig.Act.CHANT)
	var told := await wait(1.0, func() -> bool: return party[1].hunting() and party[2].hunting())
	check("his party takes up the hunt", told)
	# --- The throw: wound up where it can be seen, then the spear catches him ---
	var wound := await wait(6.0, func() -> bool: return party.any(func(m: MazeTribesman) -> bool: return m.mode == MazeTribesman.Mode.WIND))
	check("one of them winds up to throw", wound)
	var winder: MazeTribesman = null
	for m in party:
		if m.mode == MazeTribesman.Mode.WIND:
			winder = m
	await frames(3)
	check("drawn back where it can be seen", winder != null and winder.tribesman.stage() == TribesmanRig.Stage.WIND)
	var others_wound := 0
	for m in party:
		if m != winder and m.mode == MazeTribesman.Mode.WIND:
			others_wound += 1
	check("only one of the party throws at a time", others_wound == 0)
	var flew := await wait(2.0, func() -> bool: return winder.tribesman.spear.flying())
	check("the spear flies", flew, "(after %.2f s drawn back)" % winder._mode_time)
	var hit := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("it catches him (he stood still)", hit and caught_by[0][0] == boy)
	# (he is let alone a moment: out of their sight while they go for their spears)
	put_boy(maze.world(lairs[0]))
	var fetched := await wait(15.0, func() -> bool: return winder.mode == MazeTribesman.Mode.PICK)
	check("the thrower goes for his spear and stoops to it", fetched, "(mode %s)" % MazeTribesman.Mode.keys()[winder.mode])
	var armed := await wait(4.0, func() -> bool: return winder.tribesman.armed() and winder.mode != MazeTribesman.Mode.PICK)
	check("and has it in his hand again", armed)
	await clear_men()

	# --- Out of his line before he throws: he gives it up ---
	put_boy(at_home)
	await frames(70)
	thrower = man_at(near_end, atan2(-along.x, -along.z))
	wound = await wait(6.0, func() -> bool: return thrower.mode == MazeTribesman.Mode.WIND)
	check("he winds up again", wound)
	put_boy(maze.world(lairs[lairs.size() - 1]))
	var gave_up := await wait(3.0, func() -> bool: return thrower.mode != MazeTribesman.Mode.WIND)
	check("the boy out of his line: he holds, then gives the throw up", gave_up and thrower._throws == 0 and caught_by.is_empty(), "(throws %d, mode %s)" % [thrower._throws, MazeTribesman.Mode.keys()[thrower.mode]])
	check("and still has his spear", thrower.tribesman.armed())
	await clear_men()

	# --- A spear thrown at a wall sticks in it; one goes over someone ducked ---
	var wall_way := Vector3.ZERO
	for s: Vector2i in Maze.STEPS:
		if maze.blocked(home, s):
			wall_way = Vector3(s.x, 0.0, s.y)
			break
	var spear := TribeSpear.new()
	stage.add_child(spear)
	await frames(2)
	var landed_at: Array = []
	spear.landed.connect(func(where: Vector3, stuck: bool) -> void: landed_at.append([where, stuck]))
	spear.hold(Transform3D(Basis.looking_at(wall_way, Vector3.UP), at_home - wall_way * 4.0 + Vector3.UP * 1.2))
	spear.throw(wall_way * 16.0 + Vector3.UP * 1.0)
	var stuck := await wait(3.0, func() -> bool: return not landed_at.is_empty())
	check("a spear thrown at a wall sticks in it", stuck and landed_at[0][1] and spear.state == TribeSpear.State.STUCK)
	var over := TribeSpear.passes(Vector3(-1.0, 1.1, 0.0), Vector3(1.0, 1.05, 0.0), Vector3.ZERO, 0.8, 0.25)
	var through := TribeSpear.passes(Vector3(-1.0, 1.1, 0.0), Vector3(1.0, 1.05, 0.0), Vector3.ZERO, 1.3, 0.25)
	check("it goes over someone ducked, and through someone standing", not over and through)
	spear.queue_free()
	await clear_men()

	# --- The jab close to ---
	put_boy(at_home)
	await frames(70)
	var jabber := man_at(at_home + along * 1.4, atan2(-along.x, -along.z))
	var jabbed := await wait(6.0, func() -> bool: return jabber.mode == MazeTribesman.Mode.JAB)
	check("close to, he jabs", jabbed)
	hit = await wait(2.0, func() -> bool: return not caught_by.is_empty())
	check("the point catches him", hit and caught_by[0][0] == boy)
	await clear_men()

	# --- Out of reach, up high: waited for below, then given up ---
	boy.remove_from_group(&"maze_players")
	var high := Node3D.new()
	stage.add_child(high)
	high.global_position = at_home + Vector3.UP * 4.0
	high.add_to_group(&"maze_players")
	party = MazeTribesman.party_of(2, 17)
	for k in party.size():
		party[k].wait_below = 4.0
		man_at(near_end + along * (k * 2.0), atan2(-along.x, -along.z), party[k])
	var below := await wait(6.0, func() -> bool: return party[0].mode == MazeTribesman.Mode.BELOW)
	check("someone up high: they gather below", below)
	var thrown_up := false
	var home_again := false
	for i in 60 * 7:
		await physics_frame
		thrown_up = thrown_up or party[0]._throws > 0 or party[1]._throws > 0
		if party[0].mode == MazeTribesman.Mode.PATROL and not party[0].hunting():
			home_again = true
			break
	check("and do not throw up at him", not thrown_up and caught_by.is_empty())
	check("and in the end give it up", home_again)
	high.queue_free()
	boy.add_to_group(&"maze_players")
	await clear_men()

	# --- A puppet throws as the host does, and catches nobody ---
	put_boy(at_home)
	await frames(70)
	var host := man_at(near_end, atan2(-along.x, -along.z))
	var copy := MazeTribesman.new()
	copy.puppet = true
	man_at(near_end, atan2(-along.x, -along.z), copy)
	# (here both are on the one machine, on the same spot: the copy is kept from shoving the host)
	copy.collision_layer = 0
	var copied_throw := false
	var off := 0.0
	for i in 60 * 8:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			off = maxf(off, copy.global_position.distance_to(host.global_position))
		if copy.tribesman.spear.flying():
			copied_throw = true
	check("the puppet keeps up with the host", off < 1.5, "(at most %.2f m off)" % off)
	check("the puppet throws when the host does", copied_throw and host._throws > 0)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear_men()

	# --- Speeds ---
	var probe := MazeTribesman.new()
	check("hunting at a run, no faster: a sprint gets away", probe.chase_speed <= 4.4 and probe.chase_speed < 5.6)
	check("the wind-up is long enough to see", probe.wind_time >= 0.6)
	probe.free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
