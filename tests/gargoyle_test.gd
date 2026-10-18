extends SceneTree
## The gargoyle (MazeGargoyle driving Gargoyle), headless, in a real maze
## (MazeBuilder in a bare scene):
##
## - put in a hall, it finds a ledge over it (a terrace's edge or the wall's
##   top) and crouches there as a statue: stone, and not posed at all;
## - the boy stands under it: it stirs (alive, looking at him) for a while
##   before it drops, its shadow is on the ground where it will land, and it has
##   him when it lands; then it is stone again for a while;
## - he comes under it again and runs on aside as it drops: it misses, and is
##   stone where it landed, and does not catch him then even if he walks by;
## - it hunts in bounds slower than a run, turning slowly; standing in front of
##   it he is leapt on after a wind-up;
## - with nobody about it goes back to its wall and beats up to its ledge;
## - a puppet fed its `state_bytes` follows it; on the ground with
##   `seek_perch` off it is a statue there that wakes as he comes near;
## - MazeEnemies puts in as many as the first ring's style asks for.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/gargoyle_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy
var failures := 0
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
	maze = Maze.generate(Maze.seed_for("GARGOYLE", 1))
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


## A hall cell (straight, walls both sides) well out in the ring.
func hall_cell() -> Vector2i:
	var lairs := nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 3 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
				return cell
	return lairs[0]


## Puts the boy at `at` on the ground, still.
func put_boy(at: Vector3) -> void:
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z)
	boy.velocity = Vector3.ZERO


func bone_pose(g: MazeGargoyle, bone: String) -> Transform3D:
	var sk: Skeleton3D = g.look._skeleton
	return sk.get_bone_global_pose(sk.find_bone(bone))


func _run() -> void:
	await wait(0.2)
	var cell := hall_cell()
	var g := MazeGargoyle.new()
	g.maze = maze
	g.seed_choices(5)
	g.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(g)
	var caught: Array = []
	g.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await wait(0.5)
	var ground := maze.ground_height(g.perch)
	check("finds a ledge over the hall", g.mode == MazeGargoyle.Mode.PERCH and not g._on_ground_perch and g.perch.y - ground > 3.0,
		"(%.1f m up at %s, facing %s)" % [g.perch.y - ground, g.perch.snappedf(0.1), g.perch_out])
	check("sits on it", g.global_position.distance_to(g.perch) < 0.05)
	var below := g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g.perch + Vector3.UP * 0.5, g.perch + Vector3.DOWN * 0.6, 1))
	check("there is stone under it", not below.is_empty())
	var out_there := g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g.perch + g.perch_out * 1.5 + Vector3.UP * 0.5, g.perch + g.perch_out * 1.5 + Vector3.DOWN * 2.5, 1))
	check("facing out over the drop", out_there.is_empty())
	check("a statue: stone and perched", g.look.life() == 0.0 and g.look.perched and not g.look.alive)
	# (the boy near, so that it is drawn, but not under it)
	put_boy(g.perch_foot + g.perch_out * 40.0)
	if not maze.inside(maze.cell_at(boy.global_position)):
		put_boy(g.perch_foot + g.perch_out * 20.0)
	await wait(0.3)
	var still := bone_pose(g, "head")
	var tail := bone_pose(g, "tail_5")
	await wait(1.0)
	check("a statue does not move", bone_pose(g, "head").is_equal_approx(still) and bone_pose(g, "tail_5").is_equal_approx(tail))

	# The puppet.
	var copy := MazeGargoyle.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = g.position
	stage.add_child(copy)
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(func() -> void: copy.from_bytes(g.state_bytes()))
	stage.add_child(timer)
	timer.start()
	await wait(0.5)
	check("the puppet sits there too", copy.mode == MazeGargoyle.Mode.PERCH and copy.global_position.distance_to(g.global_position) < 0.5)

	# He stands under it.
	put_boy(g.perch_foot)
	var stirred := await wait(1.0, func() -> bool: return g.mode == MazeGargoyle.Mode.STIR)
	check("stirs when he is under it", stirred)
	await wait(0.6)
	check("alive, looking at him, before it drops", g.mode == MazeGargoyle.Mode.STIR and g.look.life() > 0.5 and g.look.aim.is_finite())
	var dove := await wait(2.0, func() -> bool: return g.mode == MazeGargoyle.Mode.DIVE)
	check("then drops", dove)
	await wait(0.3)
	check("its shadow on the ground where it will land", g.look._shadow != null and g.look._shadow.visible and g.landing.distance_to(boy.global_position) < 2.5)
	check("in the air, wings out", g.look.airborne)
	var landed := await wait(4.0, func() -> bool: return not caught.is_empty())
	check("has him when it lands", landed and caught.has(boy), "(%s)" % [MazeGargoyle.Mode.keys()[g.mode]])
	check("the puppet came down too", copy.global_position.distance_to(g.global_position) < 2.0, "(%.1f m apart)" % copy.global_position.distance_to(g.global_position))
	await wait(0.2)
	check("stone where it landed", g.mode == MazeGargoyle.Mode.STONE and not g.look.alive)

	# Again, and he runs on aside as it drops: it misses.
	g._settle_on_perch()
	caught.clear()
	await wait(3.2)
	put_boy(g.perch_foot)
	await wait(4.0, func() -> bool: return g.mode == MazeGargoyle.Mode.DIVE)
	var aside: Vector3 = g.perch_out.cross(Vector3.UP).normalized()
	if not nav.allowed(maze.cell_at(boy.global_position + aside * 8.0)):
		aside = -aside
	var run := func() -> bool:
		if true:
			var step: Vector3 = (aside if nav.allowed(maze.cell_at(boy.global_position + aside * 2.0)) else -g.perch_out) * 4.4 / 60.0
			boy.global_position += step
			boy.velocity = step * 60.0
		return g.mode == MazeGargoyle.Mode.STONE
	var down := await wait(4.0, run)
	check("misses him running aside", down and caught.is_empty(), "(%.1f m from where it landed)" % boy.global_position.distance_to(g.global_position))
	await wait(0.8)
	check("stone after the miss", g.mode == MazeGargoyle.Mode.STONE and g.look.life() < 0.05)
	# (he walks right by it while it is stone)
	put_boy(g.global_position + aside * 1.0)
	boy.velocity = Vector3.ZERO
	await wait(1.0)
	check("stone, it catches nobody", caught.is_empty() and g.mode == MazeGargoyle.Mode.STONE)

	# It hunts: he stands well off down the hall behind it.
	# (down the hall, clear of the walls, a little to one side so that it must turn)
	var far := g.global_position + aside * 13.0
	if not nav.allowed(maze.cell_at(far)) or not nav.clear_of_walls(far, 1.5):
		far = g.global_position - aside * 13.0
	put_boy(far)
	g.notice(boy)
	var hunting := await wait(4.0, func() -> bool: return g.mode == MazeGargoyle.Mode.HUNT)
	check("hunts after its time as stone", hunting)
	var from: Vector3 = g.global_position
	# (lambdas take copies of locals: what they learn goes in here)
	var seen := {"leapt": false, "gathered": false, "turned": 0.0, "fastest": 0.0, "heading": g._heading}
	var got := await wait(14.0, func() -> bool:
		if g.mode == MazeGargoyle.Mode.HUNT:
			seen["turned"] = maxf(seen["turned"], (seen["heading"] as Vector3).angle_to(g._heading) * 60.0)
			seen["fastest"] = maxf(seen["fastest"], Vector2(g.velocity.x, g.velocity.z).length())
		seen["heading"] = g._heading
		seen["gathered"] = seen["gathered"] or g.mode == MazeGargoyle.Mode.GATHER
		seen["leapt"] = seen["leapt"] or g.mode == MazeGargoyle.Mode.LEAP
		if trace and Engine.get_physics_frames() % 30 == 0:
			print("  %s at %s, %.1f m from him" % [MazeGargoyle.Mode.keys()[g.mode], g.global_position.snappedf(0.1), g.global_position.distance_to(boy.global_position)])
		return not caught.is_empty())
	check("bounds slower than a run", seen["fastest"] > 2.0 and seen["fastest"] < 4.4, "(%.1f m/s at most)" % seen["fastest"])
	check("turns slowly", seen["turned"] > 0.0 and seen["turned"] <= MazeGargoyle.TURN_RATE * 1.2, "(%.2f rad/s at most)" % seen["turned"])
	check("winds up, then leaps on him", seen["gathered"] and seen["leapt"] and got and caught.has(boy), "(moved %.1f m)" % from.distance_to(g.global_position))

	# Nobody about: back up to its ledge.
	put_boy(Vector3(0.0, 0.1, 0.0))
	await wait(0.2)
	g.quarry = null
	g._forget = 0.0
	g._last_seen = Vector3.INF
	var home := await wait(40.0, func() -> bool:
		if trace and Engine.get_physics_frames() % 60 == 0:
			print("  %s at %s" % [MazeGargoyle.Mode.keys()[g.mode], g.global_position.snappedf(0.1)])
		return g.mode == MazeGargoyle.Mode.PERCH)
	check("goes back up to its ledge", home and g.global_position.distance_to(g.perch) < 0.1)
	put_boy(g.perch_foot + g.perch_out * 40.0)
	if not maze.inside(maze.cell_at(boy.global_position)):
		put_boy(g.perch_foot + g.perch_out * 20.0)
	await wait(1.5)
	check("a statue again", g.look.life() == 0.0 and g.look.perched)
	check("the puppet is back up too", copy.mode == MazeGargoyle.Mode.PERCH and copy.global_position.distance_to(g.global_position) < 0.5)

	# On the ground, put where it is seen (as the dev tools do).
	var lairs := nav.lairs(3)
	var spot := maze.world(lairs[lairs.size() - 1]) + Vector3.UP * 0.05
	var statue := MazeGargoyle.new()
	statue.maze = maze
	statue.seek_perch = false
	statue.position = spot
	stage.add_child(statue)
	put_boy(spot + Vector3(30.0, 0.0, 0.0) if nav.allowed(maze.cell_at(spot + Vector3(30.0, 0.0, 0.0))) else Vector3(0.0, 0.1, 0.0))
	await wait(0.5)
	check("on the ground a statue where it is put", statue.mode == MazeGargoyle.Mode.PERCH and statue._on_ground_perch and statue.global_position.distance_to(spot) < 0.2)
	put_boy(spot + (Vector3.FORWARD if nav.allowed(maze.cell_at(spot + Vector3.FORWARD * 5.0)) else Vector3.BACK) * 5.0)
	var woke := await wait(4.0, func() -> bool: return statue.mode == MazeGargoyle.Mode.HUNT or statue.mode == MazeGargoyle.Mode.GATHER)
	check("wakes as he comes near, and comes at him", woke)
	statue.queue_free()

	# As many as a style asks for, from MazeEnemies.
	var enemies := MazeEnemies.new()
	stage.add_child(enemies)
	enemies.maze = maze
	var style := MazeStyle.new()
	for key: String in ["snakes", "mummy_packs", "ghouls", "centipedes", "spiders", "abominations", "slime_walls", "bat_colonies", "baboon_troops", "alien_packs", "dog_packs"]:
		style.set(key, 0)
	style.gargoyles = 2
	enemies.add_hunters(style, 11)
	var count := 0
	for e in enemies.enemies:
		if e is MazeGargoyle:
			count += 1
	check("MazeEnemies puts in the style's gargoyles", count == 2, "(%d)" % count)
	await wait(0.5)
	var perched := 0
	for e in enemies.enemies:
		if e is MazeGargoyle and not (e as MazeGargoyle)._on_ground_perch:
			perched += 1
	check("each up on a ledge", perched == 2, "(%d of 2)" % perched)
	check("the default first ring has one or two", MazeStyle.new().gargoyles >= 1 and MazeStyle.new().gargoyles <= 2)

	print("GARGOYLE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
