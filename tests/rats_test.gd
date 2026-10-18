extends SceneTree
## The rats (scripts/enemies/maze_rat.gd, maze_rat_swarm.gd, maze_rat_king.gd;
## creatures/rats/), headless, in a bare scene: a maze from MazeBuilder and
## stand-in players that the test moves by hand (CharacterBody3Ds with no
## shape, so their `velocity` is whatever the test says). In turn:
##
## - A group of rats keeps to the feet of the walls, goes about, flees from
##   someone coming near (and from someone running further off), squeaks off
##   together, catches nobody, and goes to a carcass and gnaws at it.
## - A swarm opens its drains at the foot of a wall and waits there unseen;
##   someone coming down the hall wakes it, it roars a moment before any come
##   out, and out they pour and flood after them, piling up over each other;
##   standing still they climb them and catch them; a sprint gets away from
##   them and a run does not; up out of reach they give up and go home; fire
##   keeps them off.
## - A rat king drags itself slowly; noticing someone it shrieks, and the swarms
##   within reach come out bold after them (fire no longer keeps them off),
##   and those out of reach do not; it creeps after them slower than a walk, and
##   touching it catches.
## - Puppet copies follow the host's news; MazeEnemies packs and unpacks all
##   three; what they draw; and what a frame of each costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/rats_test.gd
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


func away() -> void:
	put(runner, Vector3(0, -500, 0))
	put(other, Vector3(0, -500, 0))


## Moves `who` towards `goal` by the passages at `pace` for `seconds` (stopping if `until` says so).
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


## The nearest a point is to a wall face (a ray each way, level, 4 m out at most).
func wall_gap(at: Vector3) -> float:
	var space := stage.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 0.12
	var near := INF
	for k in 8:
		var way := Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 4.0, 1))
		if not hit.is_empty():
			near = minf(near, from.distance_to(hit["position"]))
	return near


func _hall_cells() -> Array[Vector2i]:
	var halls: Array[Vector2i] = []
	for c: Vector2i in nav.lairs(3):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(c, s) and not maze.blocked(c, -s) and maze.blocked(c, across) and maze.blocked(c, -across):
				halls.append(c)
				break
	return halls


func _run() -> void:
	await frames(10)
	await _rats()
	await _swarm()
	await _king()
	await _network()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


# --- A group of rats ---

func _rats() -> void:
	away()
	var halls := _hall_cells()
	var home: Vector2i = halls[0]
	var group := MazeRat.mischief(5, 99)
	for k in group.size():
		var one := group[k]
		one.name = "Rat%d" % k
		one.maze = maze
		one.seed_choices(500 + k)
		one.position = maze.world(home) + Vector3(k * 0.5 - 1.0, 0.05, 0.3 * k)
		one.appetite = 0.0
		stage.add_child(one)
		one.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await frames(5)
	var start := group[0].global_position
	var gaps: Array[float] = []
	var travelled := 0.0
	var stops := 0
	var rears := 0
	var was_still := false
	for i in 60 * 20:
		await physics_frame
		if i % 15 == 0:
			for one in group:
				gaps.append(wall_gap(one.global_position))
		var lead: MazeRat = group[0]
		var still: bool = lead.mode == MazeRat.Mode.PAUSE
		if still and not was_still:
			stops += 1
		was_still = still
		if lead.rat.rear > 0.5:
			rears += 1
		travelled = maxf(travelled, lead.global_position.distance_to(start))
	gaps.sort()
	var median: float = gaps[gaps.size() / 2]
	check("a group of rats keeps to the feet of the walls", median < 1.0, "(the middle of their distances from a wall %.2f m; %d looked at)" % [median, gaps.size()])
	check("they go about, in dashes and stops", travelled > 6.0 and stops >= 3, "(the leader %.1f m from where it began; stopped %d times in 20 s)" % [travelled, stops])
	check("now and then one rears up to sniff", rears > 0)
	var apart := 0.0
	for one in group:
		apart = maxf(apart, one.global_position.distance_to(group[0].global_position))
	check("they keep together", apart < 9.0, "(furthest %.1f m from the leader)" % apart)

	# Someone walking up to them: they bolt, all of them, and get away from them.
	var middle := Vector3.ZERO
	for one in group:
		middle += one.global_position / group.size()
	var dir := (middle - nav.point(maze.cell_at(middle))).normalized()
	if dir.length() < 0.5:
		dir = Vector3.RIGHT
	put(runner, middle + Vector3(8.0, 0, 0))
	var fled := 0
	var near_at_flee := INF
	for i in 60 * 6:
		var to := middle - runner.global_position
		to.y = 0.0
		var moving := to.normalized() * 1.6 if to.length() > 0.3 else Vector3.ZERO
		put(runner, runner.global_position + moving / 60.0, moving)
		await physics_frame
		var now := 0
		for one in group:
			if one.mode == MazeRat.Mode.FLEE:
				now += 1
				near_at_flee = minf(near_at_flee, one.global_position.distance_to(runner.global_position))
		fled = maxi(fled, now)
	var nearest := INF
	for one in group:
		nearest = minf(nearest, one.global_position.distance_to(runner.global_position))
	check("someone walking up to them sends them all running", fled == group.size(), "(%d of %d fled)" % [fled, group.size()])
	for one in group if trace else []:
		print("      rat %s: mode %s, %.1f m off, at %s" % [one.name, MazeRat.Mode.keys()[one.mode], one.global_position.distance_to(runner.global_position), one.global_position])
	check("they keep away from them", nearest > 2.5, "(the nearest %.1f m off at the end)" % nearest)
	check("rats catch nobody", caught.is_empty())
	away()
	await frames(60 * 4)
	var calm := 0
	for one in group:
		if one.mode != MazeRat.Mode.FLEE:
			calm += 1
	check("with nobody near they settle again", calm == group.size(), "(%d of %d)" % [calm, group.size()])

	# Someone running, further off, in sight: they bolt too.
	var lead_at: Vector3 = group[0].global_position
	var seen_from := Vector3.INF
	for k in 16:
		var way := Vector3(cos(k * TAU / 16.0), 0.0, sin(k * TAU / 16.0))
		var at := lead_at + way * 9.0
		if nav.sees(lead_at + Vector3.UP * 0.3, at + Vector3.UP, 12.0):
			seen_from = at
			break
	if seen_from.is_finite():
		put(runner, seen_from, (lead_at - seen_from).normalized() * 4.4)
		var bolted := false
		for i in 30:
			await physics_frame
			put(runner, runner.global_position, (lead_at - seen_from).normalized() * 4.4)
			if group[0].mode == MazeRat.Mode.FLEE:
				bolted = true
		check("someone running 9 m off sends them running", bolted)
	away()
	await frames(60 * 4)

	# A carcass near, and hungry: they go to it and gnaw.
	var dead := Node3D.new()
	dead.name = "Carcass"
	var lead_now: MazeRat = group[0]
	var spot := lead_now.global_position + Vector3(2.0, 0, 0)
	for k in 8:
		var way := Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0))
		var eye := lead_now.global_position + Vector3.UP * 0.12
		if stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + way * 3.4, 1)).is_empty():
			spot = lead_now.global_position + way * 2.2
			break
	stage.add_child(dead)
	dead.global_position = spot
	dead.set_meta(&"carrion_radius", 0.9)
	dead.add_to_group(&"fly_carrion")
	for one in group:
		one.appetite = 1.0
		one._look_carrion = 0.0
	var feeding := 0
	var t0 := Time.get_ticks_msec()
	for i in 60 * 30:
		await physics_frame
		feeding = 0
		for one in group:
			if one.mode == MazeRat.Mode.FEED and one.rat.feeding and one.global_position.distance_to(spot) < 1.8:
				feeding += 1
		if feeding >= group.size() - 1:
			break
	check("hungry, they go to a carcass near and gnaw at it", feeding >= group.size() - 1, "(%d of %d at it, after %.1f s)" % [feeding, group.size(), (Time.get_ticks_msec() - t0) / 1000.0])

	# What a frame of a rat costs.
	var t1 := Time.get_ticks_usec()
	for k in 60:
		for one in group:
			one._physics_process(1.0 / 60.0)
	var cost := (Time.get_ticks_usec() - t1) / 60.0 / group.size() / 1000.0
	check("a frame of one rat costs little", cost < 0.15, "(%.3f ms here)" % cost)
	var draws := 0
	for child in group[0].rat.get_children():
		if child is MultiMeshInstance3D:
			draws += 1
	check("a rat is one draw", draws == 1)
	for one in group:
		one.queue_free()
	dead.queue_free()
	await frames(2)


# --- A swarm ---

var _swarm_den := Vector2i.ZERO


func rouse(swarm: MazeRatSwarm) -> void:
	swarm._rest = 0.0
	swarm._spared.clear()
	put(runner, swarm.swarm.drains()[0] + swarm.swarm.drain_out(0) * 7.0)
	for i in 60 * 10:
		await physics_frame
		if swarm.mode == MazeRatSwarm.Mode.HUNT and swarm.swarm.out > swarm.swarm.count / 2 and swarm.swarm.gap < 3.0:
			return


func home_again(swarm: MazeRatSwarm) -> void:
	away()
	for i in 60 * 20:
		await physics_frame
		if swarm.mode == MazeRatSwarm.Mode.DORMANT:
			break
	caught.clear()
	swarm._rest = 0.0
	swarm._spared.clear()


func _swarm() -> void:
	away()
	caught.clear()
	var lairs: Array = nav.lairs(4)
	var den: Vector2i = lairs[0]
	for c: Vector2i in lairs:
		if nav.dead_end(c):
			den = c
			break
	_swarm_den = den
	var rats := MazeRatSwarm.new()
	rats.name = "Swarm"
	rats.maze = maze
	rats.seed_choices(4321)
	rats.position = maze.world(den) + Vector3.UP * 0.05
	stage.add_child(rats)
	rats.caught.connect(func(who: Node3D) -> void: caught.append(who))
	await frames(5)
	var swarm: RatSwarm = rats.swarm
	check("a swarm opens its drains", rats.ready_to_go() and swarm.drains().size() == 2, "(in a %s)" % ("dead end" if nav.dead_end(den) else "hall"))
	var space := rats.get_world_3d().direct_space_state
	var on_walls := 0
	for k in swarm.drains().size():
		var drain: Vector3 = swarm.drains()[k]
		var out: Vector3 = swarm.drain_out(k)
		var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(drain + Vector3.UP * 0.3 + out * 0.3, drain + Vector3.UP * 0.3 - out * 0.3, 1))
		if not face.is_empty() and absf(drain.y - maze.ground_height(drain)) < 0.1:
			on_walls += 1
	check("each drain is at the foot of a wall, on the ground", on_walls == swarm.drains().size())
	await frames(30)
	check("asleep, nothing out and nothing drawn", rats.mode == MazeRatSwarm.Mode.DORMANT and swarm.out == 0 and not swarm.get_node(^"Rats").visible)
	put(runner, maze.world(far_cell(den, 6)))
	await frames(60)
	check("someone 6 cells off does not wake it", rats.mode == MazeRatSwarm.Mode.DORMANT)

	# Someone coming down the hall: a roar first, then out they pour.
	await run_to(runner, maze.world(den), 3.0, 30.0, func() -> bool: return rats.mode == MazeRatSwarm.Mode.HUNT)
	check("someone coming near wakes it", rats.mode == MazeRatSwarm.Mode.HUNT, "(%.1f m from the drain)" % runner.global_position.distance_to(swarm.drains()[0]))
	put(runner, runner.global_position)
	await frames(20)
	check("it roars in the drains a moment before any come out", swarm.warning() and swarm.out == 0)
	await frames(60)
	var early := swarm.out
	await frames(60)
	check("then the rats pour out", early > 20 and swarm.out > early, "(%d out after a second, %d after two)" % [early, swarm.out])
	var piled := 0.0
	for i in 60 * 2:
		await physics_frame
		piled = maxf(piled, swarm.highest_pile())
	check("they climb over each other where they crowd", piled > 0.04, "(the highest %.2f m up on the others)" % piled)

	# Standing still: they climb them, and catch them.
	var t0 := Time.get_ticks_msec()
	var high := 0.0
	var wall_top := 0.0
	var wall_seen := false
	for i in 60 * 12:
		await physics_frame
		for b in swarm.count:
			var state := swarm.rat_state(b)
			if state == RatSwarm.ON:
				high = maxf(high, swarm.rat_position(b).y - runner.global_position.y)
			elif state == RatSwarm.WALL:
				wall_seen = true
				wall_top = maxf(wall_top, swarm.rat_position(b).y - maze.ground_height(swarm.rat_position(b)))
		if not caught.is_empty():
			break
	check("standing still, they reach them and catch them", caught.size() == 1 and caught[0] == runner, "(after %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	check("they climb them, some past the waist", high > 0.8, "(up to %.2f m)" % high)
	check("some run up the walls, but not far", wall_seen and wall_top <= swarm.wall_climb + 0.3, "(up to %.2f m)" % wall_top)
	var went := false
	for i in 60 * 15:
		await physics_frame
		if rats.mode == MazeRatSwarm.Mode.DORMANT:
			went = true
			break
	check("once they have caught someone they go home, every one", went and swarm.out == 0, "(%d out)" % swarm.out)

	# A sprint gets away; a run does not.
	rats.give_up_after = 30.0
	await rouse(rats)
	var goal := maze.world(far_cell(maze.cell_at(runner.global_position), 8))
	caught.clear()
	rats._spared.clear()
	var gaps: Array[float] = []
	for k in 8:
		await run_to(runner, goal, 5.6, 1.0)
		gaps.append(swarm.gap if rats.mode == MazeRatSwarm.Mode.HUNT else INF)
	check("a sprint gets away from them", caught.is_empty() and gaps[-1] > gaps[0] + 1.5, "(the gap each second %s)" % [gaps.map(func(g: float) -> String: return "%.1f" % g)])
	await home_again(rats)
	await rouse(rats)
	var run_goal := maze.world(far_cell(maze.cell_at(runner.global_position), 8))
	var got := await run_to(runner, run_goal, 4.4, 14.0, func() -> bool: return not caught.is_empty() or rats.mode != MazeRatSwarm.Mode.HUNT)
	check("a run does not get away", got and not caught.is_empty(), "(mode %s, gap %.1f)" % [MazeRatSwarm.Mode.keys()[rats.mode], swarm.gap])
	await home_again(rats)

	# Up out of reach (2.5 m up: a terrace, the ivy): they come, give up and go home.
	rats.give_up_after = 4.0
	var drain: Vector3 = swarm.drains()[0]
	var out_of: Vector3 = swarm.drain_out(0)
	put(runner, drain + out_of * 0.6 + Vector3.UP * 2.5)
	await frames(30)
	var came := rats.mode == MazeRatSwarm.Mode.HUNT
	var home := false
	for i in 60 * 25:
		await physics_frame
		if rats.mode == MazeRatSwarm.Mode.DORMANT:
			home = true
			break
	for b in (swarm.count if trace else 0):
		if swarm.rat_state(b) != RatSwarm.HIDDEN:
			print("      straggler %d: state %d at %s, ground %.2f, drain %s (%.1f m), wait %.2f detour %.2f" % [b, swarm.rat_state(b), swarm.rat_position(b), swarm._ground[b], swarm.drains()[b % 2], swarm.rat_position(b).distance_to(swarm.drains()[b % 2]), swarm._wait[b], swarm._detour[b]])
	check("2.5 m up out of reach, they come, give up and all go back in", came and home and swarm.out == 0 and caught.is_empty(), "(%d out, caught %d)" % [swarm.out, caught.size()])
	rats._rest = 0.0

	# Fire keeps them off.
	var torch := _ward(5.0)
	stage.add_child(torch)
	torch.global_position = drain + out_of * 6.0
	put(runner, drain + out_of * 6.0)
	await frames(60)
	check("fire keeps them off (someone with a torch does not wake them)", rats.mode == MazeRatSwarm.Mode.DORMANT)
	torch.queue_free()
	away()
	await frames(5)

	# Its cost and its draws.
	await rouse(rats)
	swarm.catch_time = 100000.0
	await frames(60)
	var t1 := Time.get_ticks_usec()
	for k in 30:
		swarm._physics_process(1.0 / 60.0)
	var cost := (Time.get_ticks_usec() - t1) / 30.0 / 1000.0
	check("a frame of %d rats costs little" % swarm.out, cost < 4.0, "(%.2f ms here; %d on the ground, %d on walls, %d on him)" % [cost, swarm.counted(RatSwarm.GROUND), swarm.counted(RatSwarm.WALL), swarm.counted(RatSwarm.ON)])
	var draws := 0
	for child in swarm.get_children():
		if child is MultiMeshInstance3D:
			draws += 1
	check("the rats are one draw", draws == 1)
	swarm.catch_time = 0.9
	await home_again(rats)


## A fire's ward (FireWard): a node in `fire_wards` with a `ward_radius`.
func _ward(radius: float) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar ward_radius := %f\nfunc _enter_tree() -> void:\n\tadd_to_group(&\"fire_wards\")\n" % radius
	script.reload()
	var made := Node3D.new()
	made.set_script(script)
	return made


# --- The rat king ---

func _king() -> void:
	away()
	caught.clear()
	var swarm_node: MazeRatSwarm = stage.get_node(^"Swarm")
	var swarm: RatSwarm = swarm_node.swarm
	swarm_node._rest = 0.0
	# (a cell some way from the swarm's drains, within its call)
	var den_at := swarm.drains()[0]
	var cell := maze.cell_at(den_at)
	var field := nav.field(cell)
	var spot := cell
	for c: Vector2i in nav.lairs(2):
		var d := field[maze.index(c)]
		if d >= 2 and d <= 3 and maze.world(c).distance_to(den_at) < 40.0:
			spot = c
			break
	var king := MazeRatKing.new()
	king.name = "King"
	king.maze = maze
	king.seed_choices(777)
	king.position = maze.world(spot) + Vector3.UP * 0.05
	stage.add_child(king)
	king.caught.connect(func(who: Node3D) -> void: caught.append(who))
	# A second swarm far off, out of the king's call.
	var far_swarm := MazeRatSwarm.new()
	far_swarm.name = "FarSwarm"
	far_swarm.maze = maze
	far_swarm.seed_choices(99)
	var far_cell_now := far_cell(spot, 14)
	far_swarm.position = maze.world(far_cell_now) + Vector3.UP * 0.05
	stage.add_child(far_swarm)
	await frames(5)
	var rats := king.king.count
	check("a rat king is %d rats, eight to fourteen" % rats, rats >= 8 and rats <= 14)
	var draws := 0
	for child in king.king.get_children():
		if child is GeometryInstance3D:
			draws += 1
	check("it is two draws (its rats and the knot)", draws == 2)
	# Alone it drags itself about, slowly and unevenly.
	var from := king.global_position
	var top_speed := 0.0
	var speeds: Array[float] = []
	var last := king.global_position
	for i in 60 * 10:
		await physics_frame
		if i % 10 == 9:
			var moved := Vector2(king.global_position.x - last.x, king.global_position.z - last.z).length() * 6.0
			speeds.append(moved)
			top_speed = maxf(top_speed, moved)
			last = king.global_position
	var mean := 0.0
	for s in speeds:
		mean += s / speeds.size()
	var spread := 0.0
	for s in speeds:
		spread += absf(s - mean) / speeds.size()
	check("alone, it drags itself about slowly", king.global_position.distance_to(from) > 0.4 and mean < 0.8, "(%.1f m in 10 s, %.2f m/s on average, at most %.2f)" % [king.global_position.distance_to(from), mean, top_speed])
	check("and unevenly, in lurches", spread > mean * 0.25, "(its speed wanders %.2f m/s about that)" % spread)
	var pulling := 0
	for i in rats:
		if king.king.pulling(i) > 0.1:
			pulling += 1
	check("its rats pull each their own way, a few at once", pulling >= 1 and pulling < rats, "(%d of %d pulling now)" % [pulling, rats])

	# Someone comes into sight: it shrieks, and the swarm near comes out bold after them (and not the far one).
	var torch := _ward(5.0)
	stage.add_child(torch)
	var seen := Vector3.INF
	for k in 24:
		var way := Vector3(cos(k * TAU / 24.0), 0.0, sin(k * TAU / 24.0))
		var at := king.global_position + way * 9.0
		if nav.sees(king.global_position + Vector3.UP, at + Vector3.UP, 12.0) and nav.clear_of_walls(at, 0.5):
			seen = at
			break
	put(runner, seen)
	torch.global_position = seen
	var shrieked := false
	for i in 60 * 2:
		await physics_frame
		if king.shrieking():
			shrieked = true
			break
	check("noticing someone, it shrieks", shrieked, "(%s)" % ("seen from %.1f m" % seen.distance_to(king.global_position) if seen.is_finite() else "nowhere in sight"))
	await frames(5)
	check("its shriek calls the swarm near, bold", swarm_node.bold > 0.0 and swarm_node.mode == MazeRatSwarm.Mode.HUNT and swarm_node.quarry == runner, "(mode %s, after %s)" % [MazeRatSwarm.Mode.keys()[swarm_node.mode], swarm_node.quarry.name if swarm_node.quarry else "nobody"])
	check("and not one out of its reach", far_swarm.mode == MazeRatSwarm.Mode.DORMANT and far_swarm.bold <= 0.0, "(%.0f m off)" % far_swarm.global_position.distance_to(king.global_position))
	check("bold, fire does not keep them off", not swarm_node.fears_fire and swarm_node.huntable(runner))
	var hunting_still := true
	for i in 60 * 3:
		await physics_frame
		if swarm_node.mode != MazeRatSwarm.Mode.HUNT:
			hunting_still = false
	check("the swarm comes on after them through the torch's ward", hunting_still and swarm.out > 50, "(%d out)" % swarm.out)
	torch.queue_free()
	swarm_node._go_home()
	swarm_node._calm()

	# It creeps after them, slower than a walk; touching it catches.
	put(runner, seen)
	var gap0 := king.global_position.distance_to(runner.global_position)
	await frames(60 * 6)
	var gap1 := king.global_position.distance_to(runner.global_position)
	check("it creeps after them, slower than a walk", gap1 < gap0 - 0.3 and (gap0 - gap1) / 6.0 < 1.4, "(%.1f m nearer in 6 s)" % (gap0 - gap1))
	# (a walk gets away from it)
	var walk_goal := maze.world(far_cell(maze.cell_at(runner.global_position), 5))
	var gap_walk0 := king.global_position.distance_to(runner.global_position)
	await run_to(runner, walk_goal, 1.6, 5.0)
	var gap_walk1 := king.global_position.distance_to(runner.global_position)
	check("a walk gets away from it", gap_walk1 > gap_walk0, "(%.1f m to %.1f m)" % [gap_walk0, gap_walk1])
	caught.clear()
	king._spared.clear()
	put(runner, king.global_position + Vector3(king.king.reach() * 0.8, 0, 0))
	await frames(10)
	check("touching it catches", caught.size() == 1 and caught[0] == runner)
	away()

	var t1 := Time.get_ticks_usec()
	for k in 60:
		king._physics_process(1.0 / 60.0)
		king.king._process(1.0 / 60.0)
	var cost := (Time.get_ticks_usec() - t1) / 60.0 / 1000.0
	check("a frame of the king costs little", cost < 0.6, "(%.2f ms here)" % cost)
	far_swarm.queue_free()
	await frames(2)


# --- Online ---

func _network() -> void:
	away()
	caught.clear()
	var king: MazeRatKing = stage.get_node(^"King")
	var swarm_node: MazeRatSwarm = stage.get_node(^"Swarm")
	# A puppet king hears the host's shrieks and follows it.
	var copy := MazeRatKing.new()
	copy.name = "KingCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(777)
	copy.position = king.global_position
	stage.add_child(copy)
	await frames(3)
	copy.from_bytes(king.state_bytes())
	king._call_in = 0.0
	king._spared.clear()
	king.notice(runner)
	put(runner, king.global_position + Vector3(4, 0, 0))
	var apart := 0.0
	var heard := false
	for i in 120:
		if i % 6 == 0:
			copy.from_bytes(king.state_bytes())
		await physics_frame
		apart = maxf(apart, copy.global_position.distance_to(king.global_position))
		if copy.king.squealing():
			heard = true
	check("a puppet king follows the host", apart < 1.0, "(at worst %.2f m apart)" % apart)
	check("and shrieks when it does", heard)
	check("the puppet catches nobody", caught.count(runner) <= 1)
	away()
	copy.queue_free()
	var king_cell := maze.cell_at(king.global_position)
	var king_at := king.global_position
	king.queue_free()
	swarm_node._calm()

	# A puppet swarm, bold with the host.
	await home_again(swarm_node)
	swarm_node._embolden()
	swarm_node._rest = 0.0
	var scopy := MazeRatSwarm.new()
	scopy.name = "SwarmCopy"
	scopy.maze = maze
	scopy.puppet = true
	scopy.seed_choices(4321)
	scopy.position = maze.world(_swarm_den) + Vector3.UP * 0.05
	stage.add_child(scopy)
	await frames(3)
	check("the puppet swarm opens the same drains", scopy.ready_to_go() and scopy.swarm.drains()[0].distance_to(swarm_node.swarm.drains()[0]) < 0.01)
	swarm_node.swarm.catch_time = 100000.0
	put(runner, swarm_node.swarm.drains()[0] + swarm_node.swarm.drain_out(0) * 8.0)
	var agreed := 0
	var fronts := 0.0
	for i in 240:
		if i % 6 == 0:
			scopy.from_bytes(swarm_node.state_bytes())
		await physics_frame
		if scopy.mode == swarm_node.mode:
			agreed += 1
		if i > 170 and scopy.swarm.out > 0:
			fronts = maxf(fronts, scopy.swarm.front.distance_to(swarm_node.swarm.front))
	check("the puppet swarm's mode follows", agreed > 220, "(%d of 240 frames)" % agreed)
	check("its rats are out and go the same way, bold as the host's", scopy.swarm.out > 100 and fronts < 3.5 and scopy.bold > 0.0, "(%d out; fronts at worst %.1f m apart; the host %s with %d out)" % [scopy.swarm.out, fronts, MazeRatSwarm.Mode.keys()[swarm_node.mode], swarm_node.swarm.out])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, swarm_node.state_bytes().size() == MazeEnemy.STATE_SIZE)
	away()
	scopy.queue_free()

	# A puppet rat follows.
	var one := MazeRat.mischief(1, 5)[0]
	one.maze = maze
	one.seed_choices(1)
	one.position = maze.world(_swarm_den) + Vector3(1, 0.05, 1)
	stage.add_child(one)
	var rcopy := MazeRat.mischief(1, 5)[0]
	rcopy.maze = maze
	rcopy.puppet = true
	rcopy.position = one.position
	stage.add_child(rcopy)
	await frames(3)
	var worst := 0.0
	for i in 240:
		if i % 6 == 0:
			rcopy.from_bytes(one.state_bytes())
		await physics_frame
		if i > 20:
			worst = maxf(worst, rcopy.global_position.distance_to(one.global_position))
	check("a puppet rat follows the host's", worst < 0.8, "(at worst %.2f m apart)" % worst)
	one.queue_free()
	rcopy.queue_free()

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var cell := king_cell
	var a_king := set_a.add(MazeRatKing.new(), cell, 0.0, 31)
	var a_swarm := set_a.add(MazeRatSwarm.new(), _swarm_den, 0.0, 32)
	var a_rat := set_a.add(MazeRat.mischief(1, 3)[0], cell, 0.0, 33)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b_king := set_b.add(MazeRatKing.new(), cell, 0.0, 31)
	var b_swarm := set_b.add(MazeRatSwarm.new(), _swarm_den, 0.0, 32)
	var b_rat := set_b.add(MazeRat.mischief(1, 3)[0], cell, 0.0, 33)
	await frames(30)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks all three", (b_swarm as MazeRatSwarm).ready_to_go() and (b_swarm as MazeRatSwarm).swarm.drains()[0] == (a_swarm as MazeRatSwarm).swarm.drains()[0] and b_king.global_position.distance_to(a_king.global_position) < 0.5 and king_at.is_finite() and b_rat.global_position.distance_to(a_rat.global_position) < 0.5 and b_king.puppet)
	print("triangles: the rat %d, the low rat %d, the knot %d" % [RatLook.triangles(RatLook.mesh(false)), RatLook.triangles(RatLook.mesh(true)), RatLook.triangles(RatLook.knot())])
