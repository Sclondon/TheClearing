extends SceneTree
## The beetles (scripts/enemies/beetles.gd, creatures/beetle_swarm/), headless,
## in a bare scene: a maze from MazeBuilder and stand-in players that the test
## moves by hand (CharacterBody3Ds with no shape, so their `velocity` is
## whatever the test says). In turn: the swarm opens its cracks at the foot of
## a wall and waits there unseen; someone far off does not wake it; someone
## coming down the hall does, and the beetles pour out; they flood after them
## by the passages and some run up the wall feet, but not far; standing still,
## they run up the legs and catch; a sprint gets away from them and a run does
## not; someone up out of reach (on ivy, a terrace) is given up on, and they
## all go home into the cracks; of two players it goes for the nearer; a
## puppet copy follows the host's news and its beetles go the same way;
## MazeEnemies' packing carries it; one draw; and what a frame of it costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/beetles_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var runner: CharacterBody3D
var other: CharacterBody3D
var failures := 0
var caught: Array = []
var trace := OS.get_cmdline_user_args().has("trace")


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


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
	runner = _stand_in("Runner")
	other = _stand_in("Other")
	_run.call_deferred()


func _stand_in(called: String) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = called
	body.collision_layer = 0
	body.collision_mask = 0
	stage.add_child(body)
	body.add_to_group(&"maze_players")
	body.position = Vector3(0, -500, 0)
	return body


func put(who: CharacterBody3D, at: Vector3, moving := Vector3.ZERO) -> void:
	who.global_position = at
	who.velocity = moving


## Moves `who` towards `goal` by the passages at `pace` for `seconds` (stopping
## if `until` says so), as a player running away would.
func run_to(who: CharacterBody3D, goal: Vector3, pace: float, seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		var next: Vector3 = nav.waypoint(who.global_position, goal, MazeNav.clearance_for(0.4))
		var to := next - who.global_position
		to.y = 0.0
		var moving := to.normalized() * pace if to.length() > 0.2 else Vector3.ZERO
		put(who, who.global_position + moving / 60.0, moving)
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return false


## A cell far (by the passages) from `from`, at least `steps` away and as near that as can be.
func far_cell(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	var best := from
	var best_d := -1
	for c: Vector2i in nav.lairs(2):
		var d := field[maze.index(c)]
		if d >= steps and (best_d < 0 or d < best_d):
			best_d = d
			best = c
	return best


## Brings them out after the runner, stood a little way out from the crack, and waits until they are close.
func rouse(beetles: Beetles, swarm: BeetleSwarm) -> void:
	beetles._rest = 0.0
	beetles._spared.clear()
	put(runner, swarm.cracks()[0] + swarm.crack_out(0) * 7.0)
	for i in 60 * 10:
		await physics_frame
		if beetles.mode == Beetles.Mode.HUNT and swarm.out > swarm.count / 2 and swarm.gap < 3.0:
			return


## Takes the runner out of the maze, and waits for them all to go home.
func home_again(beetles: Beetles) -> void:
	put(runner, Vector3(0, -500, 0))
	for i in 60 * 20:
		await physics_frame
		if beetles.mode == Beetles.Mode.DORMANT:
			break
	caught.clear()
	beetles._rest = 0.0
	beetles._spared.clear()


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(4)
	var den: Vector2i = lairs[0]
	for c: Vector2i in lairs:
		if nav.dead_end(c):
			den = c
			break
	put(runner, maze.world(den) + Vector3(300, 0, 300))
	var beetles := Beetles.new()
	beetles.name = "Beetles"
	beetles.maze = maze
	beetles.seed_choices(4321)
	beetles.position = maze.world(den) + Vector3.UP * 0.05
	stage.add_child(beetles)
	beetles.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await frames(5)
	var swarm: BeetleSwarm = beetles.swarm
	check("it opens its cracks", beetles.ready_to_go() and swarm.cracks().size() == 2, "(%d cracks, in a %s)" % [swarm.cracks().size() if swarm else 0, "dead end" if nav.dead_end(den) else "hall"])
	var space := beetles.get_world_3d().direct_space_state
	var on_walls := 0
	for k in swarm.cracks().size():
		var crack: Vector3 = swarm.cracks()[k]
		var out: Vector3 = swarm.crack_out(k)
		var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(crack + Vector3.UP * 0.3 + out * 0.3, crack + Vector3.UP * 0.3 - out * 0.3, 1))
		if not face.is_empty() and absf(crack.y - maze.ground_height(crack)) < 0.1:
			on_walls += 1
	check("each crack is at the foot of a wall, on the ground", on_walls == swarm.cracks().size())
	await frames(30)
	check("asleep, nothing out and nothing drawn", beetles.mode == Beetles.Mode.DORMANT and swarm.out == 0 and not swarm.get_node(^"Beetles").visible)

	# Someone far off down the passages does not wake it.
	var away_cell := far_cell(den, 6)
	put(runner, maze.world(away_cell))
	await frames(60)
	check("someone 6 cells off does not wake it", beetles.mode == Beetles.Mode.DORMANT)

	# Someone coming down the hall towards it does.
	var woke := [false]
	beetles.spotted.connect(func(_who: Node3D) -> void: woke[0] = true)
	await run_to(runner, maze.world(den), 3.0, 30.0, func() -> bool: return beetles.mode == Beetles.Mode.HUNT)
	var woke_at: float = runner.global_position.distance_to(swarm.cracks()[0])
	check("someone coming near wakes it", beetles.mode == Beetles.Mode.HUNT and woke[0], "(%.1f m from the crack)" % woke_at)
	put(runner, runner.global_position)
	await frames(30)
	var early := swarm.out
	await frames(60)
	check("the beetles pour out of the cracks", early > 20 and swarm.out > early and swarm.out <= swarm.count, "(%d out after half a second, %d after one and a half)" % [early, swarm.out])

	# What a frame of them costs, flooding along after someone (all out, none on them yet).
	await frames(30)
	var t_flood := Time.get_ticks_usec()
	for k in 20:
		swarm._physics_process(1.0 / 60.0)
	var flood_cost := (Time.get_ticks_usec() - t_flood) / 20.0 / 1000.0
	check("a frame of %d beetles flooding costs little" % swarm.out, flood_cost < 3.0, "(%.2f ms here; %d on the ground, %d on walls)" % [flood_cost, swarm.counted(BeetleSwarm.GROUND), swarm.counted(BeetleSwarm.WALL)])

	# Standing still: they come, run up the legs, and catch.
	var t0 := Time.get_ticks_msec()
	var high := 0.0
	var walls := 0
	var wall_top := 0.0
	var wall_seen := false
	for i in 60 * 12:
		await physics_frame
		for b in swarm.count:
			var state := swarm.beetle_state(b)
			if state == BeetleSwarm.ON:
				high = maxf(high, swarm.beetle_position(b).y - runner.global_position.y)
			elif state == BeetleSwarm.WALL:
				wall_seen = true
				wall_top = maxf(wall_top, swarm.beetle_position(b).y - maze.ground_height(swarm.beetle_position(b)))
		if trace and i % 30 == 0:
			print("      %d: %d out, %d on, gap %.1f, front %s" % [i, swarm.out, swarm.on_target, swarm.gap, swarm.front])
		if not caught.is_empty():
			break
	check("standing still, they reach them and catch them", caught.size() == 1 and caught[0] == runner, "(after %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check("they run up the legs, some as high as the waist and more", high > 0.8, "(up to %.2f m)" % high)
	check("some run up the feet of the walls, but not far", wall_seen and wall_top <= swarm.wall_climb + 0.3, "(up to %.2f m)" % wall_top)

	# Caught, they let go and go home.
	var went := false
	for i in 60 * 15:
		await physics_frame
		if beetles.mode == Beetles.Mode.DORMANT:
			went = true
			break
	check("once they have caught someone they go home, every one", went and swarm.out == 0, "(%d out)" % swarm.out)

	# A sprint gets away. (They have come within a few metres first.)
	beetles.give_up_after = 30.0
	await rouse(beetles, swarm)
	var goal := maze.world(far_cell(maze.cell_at(runner.global_position), 8))
	caught.clear()
	beetles._rest = 0.0
	beetles._spared.clear()
	var gaps: Array[float] = []
	for k in 8:
		await run_to(runner, goal, 5.6, 1.0)
		gaps.append(swarm.gap if beetles.mode == Beetles.Mode.HUNT else INF)
	check("a sprint gets away from them", caught.is_empty() and gaps[-1] > gaps[0] + 1.5, "(the gap each second %s)" % [gaps.map(func(g: float) -> String: return "%.1f" % g)])
	await home_again(beetles)

	# A jog (slower than they are) does not.
	await rouse(beetles, swarm)
	var run_goal := maze.world(far_cell(maze.cell_at(runner.global_position), 8))
	var got := await run_to(runner, run_goal, 4.0, 14.0, func() -> bool: return not caught.is_empty() or beetles.mode != Beetles.Mode.HUNT)
	check("a jog does not get away", got and not caught.is_empty(), "(mode %s, gap %.1f)" % [Beetles.Mode.keys()[beetles.mode], swarm.gap])
	await home_again(beetles)

	# Up out of reach (on ivy, a terrace): they come, give up and go home, every one.
	beetles.give_up_after = 4.0
	var crack: Vector3 = swarm.cracks()[0]
	var out_of: Vector3 = swarm.crack_out(0)
	put(runner, crack + out_of * 0.6 + Vector3.UP * 3.0)
	await frames(30)
	var came := beetles.mode == Beetles.Mode.HUNT
	var home := false
	t0 = Time.get_ticks_msec()
	for i in 60 * 25:
		await physics_frame
		if beetles.mode == Beetles.Mode.DORMANT:
			home = true
			break
	check("up out of reach, they come, give up and all go back in", came and home and swarm.out == 0 and caught.is_empty(), "(home after %.1f s; %d out, caught %d)" % [(Time.get_ticks_msec() - t0) / 1000.0, swarm.out, caught.size()])
	beetles._rest = 0.0

	# Of two players, the nearer one.
	var near_cell := maze.cell_at(swarm.cracks()[0])
	put(runner, maze.world(far_cell(near_cell, 2)))
	put(other, crack + out_of * 6.0)
	await frames(40)
	check("of two players it goes for the nearer", beetles.mode == Beetles.Mode.HUNT and beetles.quarry == other, "(after %s)" % [beetles.quarry.name if beetles.quarry else "nobody"])
	put(other, Vector3(0, -500, 0))
	put(runner, crack + out_of * 8.0)

	# A puppet copy follows the host's news, and its beetles go the same way.
	# (nobody is caught meanwhile, so that it stays out)
	swarm.catch_time = 100000.0
	var copy := Beetles.new()
	copy.name = "BeetlesCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(4321)
	copy.position = maze.world(den) + Vector3.UP * 0.05
	stage.add_child(copy)
	await frames(3)
	var same_cracks: bool = copy.ready_to_go() and copy.swarm.cracks()[0].distance_to(swarm.cracks()[0]) < 0.01
	check("the puppet opens the same cracks", same_cracks)
	put(runner, maze.world(near_cell) + Vector3(0.5, 0, -0.5))
	var agreed := 0
	var apart := 0.0
	for i in 240:
		if i % 6 == 0:
			copy.from_bytes(beetles.state_bytes())
		await physics_frame
		if copy.mode == beetles.mode:
			agreed += 1
		if i > 150 and copy.swarm.out > 0:
			apart = maxf(apart, copy.swarm.front.distance_to(swarm.front))
		if trace and i % 30 == 0:
			print("      %d: host %s %d out (quarry %s), copy %s %d out, target %s" % [i, Beetles.Mode.keys()[beetles.mode], swarm.out, beetles.quarry, Beetles.Mode.keys()[copy.mode], copy.swarm.out, copy.swarm.target])
	check("the puppet's mode follows", agreed > 220, "(%d of 240 frames)" % agreed)
	check("the puppet's beetles are out and go the same way", copy.swarm.out > 100 and apart < 3.0, "(%d out; fronts at worst %.1f m apart)" % [copy.swarm.out, apart])
	check("the puppet catches nobody itself", caught.count(runner) <= 3)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, beetles.state_bytes().size() == MazeEnemy.STATE_SIZE)

	# What a frame of it costs, all out.
	var t1 := Time.get_ticks_usec()
	for k in 30:
		swarm._physics_process(1.0 / 60.0)
	var cost := (Time.get_ticks_usec() - t1) / 30.0 / 1000.0
	check("a frame of %d beetles costs little" % swarm.out, cost < 4.0, "(%.2f ms here)" % cost)

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(Beetles.new(), den, 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(Beetles.new(), den, 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	check("MazeEnemies packs and unpacks a swarm", (b as Beetles).ready_to_go() and (b as Beetles).swarm.cracks()[0] == (a as Beetles).swarm.cracks()[0] and b.puppet)
	var draws := 0
	for child in swarm.get_children():
		if child is MultiMeshInstance3D:
			draws += 1
	check("the beetles are one draw", draws == 1 and swarm.get_node(^"Beetles") is MultiMeshInstance3D)
	print("triangles: the ground beetle %d, the dor beetle %d" % [BeetleLook.triangles(0), BeetleLook.triangles(1)])

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
