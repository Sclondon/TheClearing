extends SceneTree
## The griffinfly (scripts/enemies/maze_griffinfly.gd, creatures/griffinfly/),
## headless, in a bare scene: a maze from MazeBuilder and a stand-in player that
## the test moves by hand (a CharacterBody3D with no shape, with `velocity` and
## `is_ducking`). In turn: it flies its halls, high and low, darting and
## hovering, never into a wall and never far from home; someone in its hall is
## seen and buzzed: it hangs in front of them, winds up (basket out, wings loud)
## for about a second, then strikes through where they were; someone who stands
## still is hit (knocked, not caught), someone who ducks or steps aside once its
## line is set is missed; it comes again; nobody in the clearing is gone after;
## someone who leaves its halls is let go, and it goes home; two of them harrying
## someone alone catch them; a strike that hits a guest's own boy knocks him down
## there (a puppet, with a real Player); MazeEnemies' packing carries it; and it
## is one draw, cheap. With Ecology's KINDS line in, it also flies from a bigger
## hungry meat-eater.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/griffinfly_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var runner: CharacterBody3D
var failures := 0
var caught := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


## Physics frames until `done` is true (or `seconds` run out); true if it came true.
func until(seconds: float, done: Callable) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if done.call():
			return true
	return false


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
	var body := GDScript.new()
	body.source_code = "extends CharacterBody3D\nvar is_ducking := false\n"
	body.reload()
	runner = CharacterBody3D.new()
	runner.set_script(body)
	runner.name = "Runner"
	runner.collision_layer = 0
	runner.collision_mask = 0
	stage.add_child(runner)
	runner.add_to_group(&"maze_players")
	_run.call_deferred()


func put(at: Vector3, moving := Vector3.ZERO) -> void:
	runner.global_position = at
	runner.velocity = moving


## A straight hall of the first ring: [a cell, the way along it] with at least `run` open cells that way.
func a_hall(run := 3, skip := 0) -> Array:
	var found := 0
	for cell: Vector2i in nav.lairs(4):
		if maze.ring_of(cell) != 1:
			continue
		for step: Vector2i in Maze.STEPS:
			var c: Vector2i = cell
			var n := 0
			while n < run and not maze.blocked(c, step):
				c += step
				n += 1
			if n >= run:
				if found == skip:
					return [cell, step]
				found += 1
	return []


func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, maze.ground_height(at) + 0.05, at.z)


func make(cell: Vector2i, seed_value := 5) -> MazeGriffinfly:
	var fly := MazeGriffinfly.new()
	fly.name = "Griffinfly%d" % seed_value
	fly.maze = maze
	fly.seed_choices(seed_value)
	fly.position = nav.point(cell) + Vector3.UP * 0.05
	stage.add_child(fly)
	fly.caught.connect(func(_who: Node3D) -> void: caught += 1)
	return fly


func _run() -> void:
	await frames(10)
	put(Vector3(0, 0.05, 0))
	var hall := a_hall(3)
	var cell: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var along := Vector3(step.x, 0.0, step.y)
	var fly := make(cell)
	await frames(5)

	# --- On patrol, nobody near ---
	var lowest := INF
	var highest := -INF
	var fastest := 0.0
	var hovered := 0
	var walls := true
	var strayed := 0
	put(Vector3(0, 0.05, 0))
	for i in 60 * 14:
		await physics_frame
		var above: float = fly.global_position.y - maze.ground_height(fly.global_position)
		lowest = minf(lowest, above)
		highest = maxf(highest, above)
		var speed := Vector2(fly.velocity.x, fly.velocity.z).length()
		fastest = maxf(fastest, speed)
		if speed < 0.6 and fly.mode == MazeGriffinfly.Mode.PATROL:
			hovered += 1
		walls = walls and (fly.mode == MazeGriffinfly.Mode.PERCH or nav.clear_of_walls(fly.global_position, 0.5))
		strayed = maxi(strayed, nav.distance(cell, maze.cell_at(fly.global_position)))
	check("on the wing over its halls, high and low", lowest > 0.5 and highest > 3.0 and highest < 8.0, "(%.1f to %.1f m up)" % [lowest, highest])
	check("darting and hovering", fastest > 6.0 and hovered > 30, "(fastest %.1f m/s, %d frames hovering)" % [fastest, hovered])
	check("never in a wall", walls)
	check("keeps to its halls", strayed <= fly.territory + 1, "(%d cells from home)" % strayed)

	# --- Someone in its hall: buzzed ---
	var spot := ground(nav.point(cell + step))
	put(spot)
	var stalked := await until(8.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.STALK)
	check("seen, and closed in on", stalked, "(mode %s)" % MazeGriffinfly.Mode.keys()[fly.mode])
	var wound := await until(10.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.WIND)
	check("hangs in front of him, then winds up", wound)
	check("drawn when someone is near (one mesh at a time, posed in its shader)", fly.look.visible and fly.look.find_children("*", "MeshInstance3D", true, false).size() <= 2)
	var front: float = Vector2(fly.global_position.x - spot.x, fly.global_position.z - spot.z).length()
	check("the wind-up a few metres off", front > 3.5 and front < 9.0, "(%.1f m)" % front)
	await frames(10)
	check("basket out, jaws open, wings loud in the wind-up", fly.look.basket == 1.0 and fly.look.jaws == 1.0 and fly.look.rattle == 1.0)
	var started := Engine.get_physics_frames()
	await until(3.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.STRIKE)
	var warned := (Engine.get_physics_frames() - started) / 60.0 + 10.0 / 60.0
	check("the warning lasts about a second", warned > 0.8 and warned < 1.4, "(%.2f s)" % warned)
	await until(2.0, func() -> bool: return fly.mode != MazeGriffinfly.Mode.STRIKE)
	check("standing still, he is hit", fly.struck and fly.strikes == 1, "(%d)" % fly.strikes)
	check("hit, not caught", caught == 0)

	# --- Ducking: missed ---
	var again := await until(14.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.WIND)
	check("it comes again", again)
	runner.is_ducking = true
	await until(3.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.STRIKE)
	await until(2.0, func() -> bool: return fly.mode != MazeGriffinfly.Mode.STRIKE)
	check("ducking, it passes over", not fly.struck and fly.strikes == 1)
	runner.is_ducking = false

	# --- Stepping aside once its line is set: missed ---
	await until(14.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.WIND)
	await until(3.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.STRIKE)
	var way: Vector3 = (fly.strike_to - fly.strike_from)
	var aside := Vector3(way.z, 0.0, -way.x).normalized()
	var from := runner.global_position
	for i in 20:
		await physics_frame
		put(ground(from + aside * 1.4 * (i + 1) / 20.0), aside * 4.2)
	await until(2.0, func() -> bool: return fly.mode != MazeGriffinfly.Mode.STRIKE)
	check("stepping aside once its line is set, it misses", not fly.struck and fly.strikes == 1)

	# --- The clearing: nobody is gone after there (one in the hall by a gate, him just inside it) ---
	var gate := Vector2i(-1, -1)
	var inward := Vector2i.ZERO
	for c: Vector2i in nav.lairs(1):
		if maze.ring_of(c) != 1:
			continue
		for s: Vector2i in Maze.STEPS:
			if maze.in_clearing(c + s) and not maze.blocked(c, s):
				gate = c
				inward = s
	var by_gate := make(gate, 51)
	put(ground(nav.point(gate + inward) + Vector3(inward.x, 0.0, inward.y) * 2.0))
	var gone_after := false
	for i in 60 * 8:
		await physics_frame
		gone_after = gone_after or by_gate.mode in [MazeGriffinfly.Mode.WIND, MazeGriffinfly.Mode.STRIKE]
	check("nobody in the clearing is gone after", gate.x >= 0 and not gone_after, "(mode %s)" % MazeGriffinfly.Mode.keys()[by_gate.mode])
	by_gate.queue_free()

	# --- Leaving its halls: let go, and home ---
	var far_cell: Vector2i = cell
	for c: Vector2i in nav.lairs(4):
		var d: int = nav.distance(cell, c)
		if d > fly.leash + 3 and d < fly.leash + 8 and maze.ring_of(c) == 1:
			far_cell = c
			break
	put(ground(nav.point(cell + step)))
	await until(6.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.STALK)
	put(ground(nav.point(far_cell)))
	var home := await until(20.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.PATROL and nav.distance(cell, maze.cell_at(fly.global_position)) <= fly.territory + 1)
	check("someone who leaves its halls is let go; it goes home", home, "(mode %s, %d cells from home)" % [MazeGriffinfly.Mode.keys()[fly.mode], nav.distance(cell, maze.cell_at(fly.global_position))])
	fly.queue_free()
	await frames(5)

	# --- Two of them, someone alone: harried, and caught ---
	MazeGriffinfly._hits.clear()
	MazeGriffinfly._knocked.clear()
	var pair_hall := a_hall(3, 3)
	var a := make(pair_hall[0], 11)
	var b := make(pair_hall[0] + pair_hall[1], 12)
	caught = 0
	put(ground(nav.point(pair_hall[0] + pair_hall[1])))
	var taken := await until(60.0, func() -> bool: return caught > 0)
	check("two of them harry someone alone and catch him", taken, "(hits %d + %d)" % [a.strikes, b.strikes])
	check("only after hits by both", a.strikes >= 1 and b.strikes >= 1 and a.strikes + b.strikes >= MazeGriffinfly.HARRY_HITS)
	a.queue_free()
	b.queue_free()
	await frames(5)

	await _puppet()
	await _ecology()
	await _cost()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)


## A host and a puppet of it: the puppet follows, and a hit on this machine's own boy knocks him down here.
func _puppet() -> void:
	var hall := a_hall(3, 1)
	var host := make(hall[0], 21)
	var puppet := MazeGriffinfly.new()
	puppet.name = "Puppet"
	puppet.maze = maze
	puppet.puppet = true
	puppet.position = host.position
	stage.add_child(puppet)
	# (the puppet's machine's own boy, a real Player, where the host's stand-in is)
	var boy: Player = load("res://player.tscn").instantiate()
	boy.name = "Boy"
	stage.add_child(boy)
	var spot := ground(nav.point(hall[0] + hall[1]))
	boy.global_position = spot
	puppet.targets = [boy]
	put(spot)
	var hit_seen := false
	var followed := true
	for i in 60 * 30:
		await physics_frame
		if i % 6 == 0:
			puppet.from_bytes(host.state_bytes())
		boy.global_position = Vector3(spot.x, boy.global_position.y, spot.z) if boy.landing == Player.Landing.SOFT else boy.global_position
		if i > 30 and puppet.global_position.distance_to(host.global_position) > 3.0:
			followed = false
		if boy.landing == Player.Landing.SPRAWL:
			hit_seen = true
			break
	check("a puppet follows its host", followed)
	check("its mode as the host's", puppet.mode == host.mode or hit_seen)
	check("a hit on this machine's own boy knocks him down here", hit_seen and host.strikes >= 1, "(host hits %d)" % host.strikes)
	# MazeEnemies' packing carries it.
	var enemies := MazeEnemies.new()
	enemies.name = "Enemies"
	stage.add_child(enemies)
	enemies.maze = maze
	var packed := MazeGriffinfly.new()
	enemies.add(packed, hall[0], 0.0, 3)
	var copies := MazeEnemies.new()
	copies.name = "Copies"
	stage.add_child(copies)
	copies.maze = maze
	copies.puppet = true
	var copy := MazeGriffinfly.new()
	copies.add(copy, hall[0], 0.0, 3)
	await frames(30)
	copies.unpack(enemies.pack())
	await frames(3)
	check("MazeEnemies' packing carries it", copy.mode == packed.mode and copy.global_position.distance_to(packed.global_position) < 2.0)
	for node: Node in [host, puppet, boy, enemies, copies]:
		node.queue_free()
	await frames(5)


## With Ecology's KINDS line in: a bigger hungry meat-eater near it, it flies off up out of reach.
func _ecology() -> void:
	if not Ecology.KINDS.has("MazeGriffinfly"):
		print("SKIP: flies from a bigger hungry meat-eater (Ecology.KINDS has no MazeGriffinfly line yet)")
		return
	var world := Ecology.put(stage, 7)
	var hall := a_hall(3, 2)
	put(Vector3(0, 0.05, 0))
	var fly := make(hall[0], 31)
	var baboon := MazeBaboon.new()
	baboon.maze = maze
	baboon.position = nav.point(hall[0] + hall[1]) + Vector3.UP * 0.05
	stage.add_child(baboon)
	await frames(5)
	baboon.hunger = 1.0
	fly.hunger = 0.0
	var fled := await until(6.0, func() -> bool: return fly.mode == MazeGriffinfly.Mode.FLEE)
	check("flies from a bigger hungry meat-eater", fled)
	for node: Node in [fly, baboon, world]:
		node.queue_free()
	await frames(5)


## What one costs a frame (thinking and posing).
func _cost() -> void:
	var hall := a_hall(3)
	var fly := make(hall[0], 41)
	put(ground(nav.point(hall[0] + hall[1])))
	await frames(60)
	var total := 0
	var thinking := 0
	for i in 60:
		var started := Time.get_ticks_usec()
		fly._physics_process(1.0 / 60.0)
		var thought := Time.get_ticks_usec()
		thinking += thought - started
		fly.look._process(1.0 / 60.0)
		total += Time.get_ticks_usec() - started
		await physics_frame
	var each := total / 60.0
	check("cheap: thinking and posing", each < 400.0, "(%.0f us a frame, %.0f of it thinking)" % [each, thinking / 60.0])
	print("griffinfly: %d triangles, low %d" % [GriffinflyLook.triangles(false), GriffinflyLook.triangles(true)])
	fly.queue_free()
	await frames(2)
