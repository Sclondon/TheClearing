extends SceneTree
## The tripod (scripts/enemies/maze_tripod.gd, creatures/tripod/), headless,
## in a bare scene: a maze from MazeBuilder and a stand-in player that the test
## moves by hand (a CharacterBody3D with no shape). In turn: it stands with its
## feet on open floor in the maze, not on the walls; it patrols round its ring,
## its legs stepping one at a time with planted feet that do not slide, and
## its light sweeping; someone in the clearing is never found; someone lit in
## the open is found and it sounds its horn; out of its sight it loses them and
## searches; the heat ray charges and burns down the hall, catching someone who
## stands in its line and missing someone who steps out of it; the grasper
## reaches down and lifts someone who stays under it; a puppet follows the
## host's news; MazeEnemies' packing carries it; its horn is made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/tripod_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
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


func put(at: Vector3) -> void:
	runner.global_position = at


## A place on open floor in a long hall within `near`..`far` metres (flat) of the tripod's body.
func open_floor(tripod: MazeTripod, near: float, far: float) -> Vector3:
	var body := tripod.look.body_point()
	var space := tripod.get_world_3d().direct_space_state
	for k in 400:
		var a := TAU * k / 37.0
		var d := lerpf(near, far, fmod(k * 0.618, 1.0))
		var at := Vector3(body.x, 0.0, body.z) + Vector3(cos(a), 0.0, sin(a)) * d
		var cell := maze.cell_at(at)
		if not maze.inside(cell) or maze.in_clearing(cell):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 150.0, at.z), Vector3(at.x, -10.0, at.z), 1))
		if hit.is_empty() or (hit["position"] as Vector3).y > 0.5:
			continue
		var spot: Vector3 = hit["position"]
		# (seen from its eye and its emitter, and a hall that runs a good way)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(tripod.look.eye_point(), spot + Vector3.UP, 1)).is_empty():
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(tripod.look.emitter_tip(), spot + Vector3.UP * 0.5, 1)).is_empty():
			continue
		var hall: Array = tripod._hall_at(spot)
		if float(hall[1]) < 30.0:
			continue
		return spot + Vector3.UP * 0.05
	return Vector3.INF


func _run() -> void:
	await frames(10)
	var nav := MazeNav.new(maze)
	var lairs: Array[Vector2i] = nav.lairs(4)
	put(Vector3(0, 0.05, 0))
	var tripod := MazeTripod.new()
	tripod.name = "Tripod"
	tripod.maze = maze
	tripod.seed_choices(7)
	tripod.position = maze.world(lairs[lairs.size() / 3]) + Vector3.UP * 0.05
	stage.add_child(tripod)
	tripod.caught.connect(func(_who: Node3D) -> void: caught += 1)
	await frames(5)
	var look := tripod.look
	# (someone near enough that it is awake, but in the clearing, where it never hunts)
	var awake := Vector3(tripod.global_position.x * 0.7, 0.05, tripod.global_position.z * 0.7)
	put(awake)

	# It stands on open floor, its body far over the walls.
	var on_floor := true
	for foot in look.feet:
		on_floor = on_floor and foot.y < 1.0 and not maze.in_clearing(maze.cell_at(foot))
	check("its feet stand on the floor of the maze", on_floor, "(%s)" % [look.feet])
	var body := look.body_point()
	check("its body stands far over the 34 m walls", body.y > 45.0, "(%.0f m up)" % body.y)
	var lens := look.eye_point()
	check("its eye is near the top of it", lens.y > 46.0, "(%.0f m)" % lens.y)

	# Patrolling: it walks round its ring, a leg at a time, feet planted firm.
	tripod.look.searchlight = true
	var from := tripod.global_position
	var steps_before := look.steps
	var two_up := false
	await frames(60 * 30)
	var moved := Vector2(tripod.global_position.x - from.x, tripod.global_position.z - from.z).length()
	check("it patrols (walks on)", moved > 15.0, "(%.1f m in 30 s)" % moved)
	check("its legs step as it goes", look.steps - steps_before >= 4, "(%d steps)" % (look.steps - steps_before))
	var out_of_band := absf(MazeTripod.square_out(tripod.global_position) - tripod._band_mid) > tripod._band_half + 14.0
	check("it keeps to the middle of its ring", not out_of_band, "(%.0f out, band %.0f +- %.0f)" % [MazeTripod.square_out(tripod.global_position), tripod._band_mid, tripod._band_half])
	# planted feet never move
	var planted_moved := 0.0
	var watch: Array = look.feet.duplicate()
	var was_stepping := look.stepping
	for i in 60 * 6:
		await physics_frame
		for k in 3:
			if k == look.stepping or k == was_stepping:
				watch[k] = look.feet[k]
				continue
			planted_moved = maxf(planted_moved, (watch[k] as Vector3).distance_to(look.feet[k]))
		if look.stepping >= 0 and was_stepping >= 0 and look.stepping != was_stepping:
			two_up = true
		was_stepping = look.stepping
	check("a planted foot does not slide", planted_moved < 0.01, "(%.3f m)" % planted_moved)
	var aim_was := tripod.beam_aim
	await frames(60)
	check("its light sweeps", tripod.beam_aim.distance_to(aim_was) > 2.0 and look.beam_hit.is_finite())
	check("one leg steps at a time", not two_up)

	# In the clearing nobody is found.
	put(awake)
	await frames(2)
	check("someone in the clearing is not exposed to it", not tripod.exposed(runner))

	# Lit in the open: found, horn. (They walk into its light where it falls on the floor of the maze.)
	var spot := open_floor(tripod, 30.0, 60.0)
	check("(found a place out in the open in a long hall)", spot.is_finite())
	var found := await until(30.0, func() -> bool:
		var lit := look.beam_hit
		if lit.is_finite() and lit.y < 0.5 and not maze.in_clearing(maze.cell_at(lit)):
			put(lit + Vector3.UP * 0.05)
		return tripod.mode == MazeTripod.Mode.SPOTTED)
	check("lit in the open, they are found and it sounds its horn", found and tripod.horns == 1, "(%s)" % MazeTripod.Mode.keys()[tripod.mode])

	# Out of sight it loses them, and searches.
	put(awake)
	var lost := await until(4.0, func() -> bool: return tripod.mode == MazeTripod.Mode.SEARCH)
	check("out of its sight, it loses them and searches", lost)

	# Found again, far off: it charges the ray and burns down the hall; standing in its line, caught.
	tripod._enter(MazeTripod.Mode.PATROL)
	spot = open_floor(tripod, tripod.reach_range + 14.0, 60.0)
	check("(found a place in the open well off from under it)", spot.is_finite())
	put(spot)
	tripod.notice(runner)
	tripod._spot(runner)
	var charging := await until(tripod.horn_time + 1.0, func() -> bool: return tripod.mode == MazeTripod.Mode.CHARGE)
	check("far from under it, it charges its heat ray", charging)
	await frames(60)
	check("the emitter glows as it charges", look.charge > 0.3, "(%.2f)" % look.charge)
	var burning := await until(tripod.charge_time + 1.0, func() -> bool: return tripod.mode == MazeTripod.Mode.BURN)
	await frames(3)
	check("then it burns", burning and look.firing)
	var start_gap := Vector2(tripod.burn_from.x - spot.x, tripod.burn_from.z - spot.z).length()
	check("the ray starts well up the hall from them", start_gap > 5.0, "(%.1f m)" % start_gap)
	var before := caught
	var closest := [INF, 0.0, false]
	await until(6.0, func() -> bool:
		var hit := look.ray_hit
		if hit.is_finite():
			var d := Vector2(hit.x - spot.x, hit.z - spot.z).length()
			if d < closest[0]:
				closest[0] = d
				closest[1] = hit.y
				closest[2] = tripod._clear(look.emitter_tip(), spot + Vector3.UP)
		return caught > before or tripod.mode != MazeTripod.Mode.BURN)
	check("standing in its line, they are caught", caught == before + 1, "(the ray came within %.1f m, at %.1f m up; open to it: %s)" % closest)
	await until(8.0, func() -> bool: return tripod.mode != MazeTripod.Mode.BURN)
	check("a scorch is left where it burned", look._trails.size() >= 1)

	# Again, but they step out of its line once it is set: missed.
	await until(10.0, func() -> bool: return tripod.mode == MazeTripod.Mode.PATROL or tripod.mode == MazeTripod.Mode.SEARCH)
	tripod._spared.clear()
	tripod._enter(MazeTripod.Mode.PATROL)
	spot = open_floor(tripod, tripod.reach_range + 14.0, 60.0)
	put(spot)
	tripod._spot(runner)
	await until(tripod.horn_time + tripod.charge_time + 2.0, func() -> bool: return tripod.mode == MazeTripod.Mode.BURN)
	var along := (tripod.burn_to - tripod.burn_from).normalized()
	var aside := Vector3.UP.cross(along).normalized()
	# (out of its line: as far across the hall as there is room)
	var room_a := tripod._free(spot + Vector3.UP, aside, 12.0)
	var room_b := tripod._free(spot + Vector3.UP, -aside, 12.0)
	var step := aside * minf(room_a - 1.0, 6.0) if room_a >= room_b else -aside * minf(room_b - 1.0, 6.0)
	put(spot + step)
	before = caught
	await until(6.0, func() -> bool: return tripod.mode != MazeTripod.Mode.BURN)
	check("stepping out of its line, the ray misses", caught == before, "(stepped %.1f m)" % step.length())

	# Near under it: the grasper reaches down and lifts them away.
	await until(10.0, func() -> bool: return tripod.mode in [MazeTripod.Mode.PATROL, MazeTripod.Mode.SEARCH])
	tripod._spared.clear()
	tripod._enter(MazeTripod.Mode.PATROL)
	spot = open_floor(tripod, 4.0, tripod.reach_range - 4.0)
	check("(found a place near under it)", spot.is_finite())
	put(spot)
	tripod._spot(runner)
	var reaching := await until(tripod.horn_time + 1.0, func() -> bool: return tripod.mode == MazeTripod.Mode.REACH)
	check("near under it, its grasper reaches down", reaching)
	before = caught
	var grabbed := await until(20.0, func() -> bool: return tripod.mode == MazeTripod.Mode.GRAB)
	check("the grasper's claws close on them", grabbed, "(tip %.1f m off, %s, reach %s)" % [look.grasper_tip().distance_to(spot + Vector3.UP), MazeTripod.Mode.keys()[tripod.mode], tripod.reach_at])
	await until(4.0, func() -> bool: return caught > before)
	check("and they are lifted away: caught", caught == before + 1)

	# A puppet follows the host's news.
	var copy := MazeTripod.new()
	copy.name = "Copy"
	copy.maze = maze
	copy.puppet = true
	copy.position = tripod.global_position
	stage.add_child(copy)
	await frames(5)
	tripod._enter(MazeTripod.Mode.PATROL)
	for i in 120:
		copy.from_bytes(tripod.state_bytes())
		await physics_frame
	check("a puppet follows where it is", copy.global_position.distance_to(tripod.global_position) < 3.0, "(%.1f m)" % copy.global_position.distance_to(tripod.global_position))
	var blasts := copy._heard_horns
	tripod._spot(runner)
	copy.from_bytes(tripod.state_bytes())
	await frames(2)
	check("a puppet sounds its horn when the host's does", copy._heard_horns != blasts and copy.mode == MazeTripod.Mode.SPOTTED)
	copy.queue_free()

	# Packed and unpacked by MazeEnemies.
	var enemies := MazeEnemies.new()
	stage.add_child(enemies)
	enemies.maze = maze
	var style := MazeStyle.new()
	# (every count of what hunts at nought, whatever kinds there are by now, but the tripods)
	var group := ""
	for property: Dictionary in style.get_property_list():
		if property["usage"] & PROPERTY_USAGE_GROUP:
			group = property["name"]
		elif group == "What hunts it" and property["type"] == TYPE_INT:
			style.set(property["name"], 0)
	style.tripods = 1
	enemies.add_hunters(style, 5)
	check("MazeEnemies puts one in as the style says", enemies.enemies.size() == 1 and enemies.enemies[0] is MazeTripod)
	var data := enemies.pack()
	check("and packs it", data.size() == 1 + MazeEnemy.STATE_SIZE)
	enemies.queue_free()

	var horn := TripodSound.horn()
	check("its horn is made (a long, loud blast)", horn.data.size() > 22050 * 2 * 3, "(%.1f s)" % (horn.data.size() / 2.0 / 22050.0))

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
