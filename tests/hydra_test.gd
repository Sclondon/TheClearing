extends SceneTree
## The hydra (MazeHydra, driving creatures/hydra's Hydra), headless, in a bare
## maze from MazeBuilder: it lies asleep in its pool with nobody about;
## someone walking past well off does not wake it, but someone running does,
## and so does someone coming near; awake, it strikes at someone in reach,
## several heads at once, with a wind-up first, and catches someone standing;
## someone walking past it through its reach is caught, someone sprinting past
## it, swerving as each head coils back to strike, mostly gets through, and someone out of its reach
## behind it is never struck at; it never strikes round a corner; with nobody
## near it lies down again; a head cut off grows back as two; a puppet copy
## follows the host's news, striking when it does; its hiss is made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/hydra_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO
	var is_ducking := false


var stage: Node3D
var maze
var nav
var failures := 0
var caught: Array = []
var lair := Vector2i.ZERO
var out := Vector3.ZERO
var across := Vector3.ZERO
var home := Vector3.ZERO
## How far the walls are to either side of its lair (along `across`, and against it).
var wall_left := 8.0
var wall_right := 8.0


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
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	_run.call_deferred()


## A cell with a straight passage of at least `run` cells either way through it.
func find_hall(run: int) -> void:
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in range(-run, run):
				if maze.blocked(cell + step * k, step) or not nav.allowed(cell + step * (k + 1)) or not nav.allowed(cell + step * k):
					ok = false
			if ok:
				lair = cell
				out = Vector3(step.x, 0.0, step.y)
				across = Vector3(step.y, 0.0, -step.x)
				return


func dummy(at: Vector3, facing: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.facing_yaw = atan2(facing.x, facing.z)
	d.add_to_group(&"maze_players")
	return d


func hydra_at(at: Vector3, awake := false, seed_value := 1) -> MazeHydra:
	var h := MazeHydra.new()
	h.maze = maze
	h.seed_choices(seed_value)
	h.position = at + Vector3.UP * 0.05
	h.rotation.y = atan2(out.x, out.z)
	stage.add_child(h)
	h.caught.connect(func(who: Node3D) -> void: caught.append(who))
	if awake:
		h._wake()
		h._waking = 0.0
	return h


func clear() -> void:
	for child in stage.get_children():
		if child is MazeHydra or child is Dummy:
			child.free()
	caught.clear()


func striking(h: MazeHydra) -> int:
	var n := 0
	for slot in h.figure.head_slots():
		if h.figure.stage(slot) in [Hydra.Stage.WIND, Hydra.Stage.DART, Hydra.Stage.HOLD]:
			n += 1
	return n


## How far the nearest wall is from `from` going `way` (metres, flat).
func wall_distance(from: Vector3, way: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, from + Vector3.UP * 1.0 + way * 40.0, 1)
	var hit := space.intersect_ray(query)
	return (hit["position"] as Vector3 - (from + Vector3.UP)).length() if hit else 40.0


## Someone goes past it down the hall, `side` metres to one side of its middle, at `speed`, from `start` behind
## to as far ahead. With `dodge`, they watch its heads: when one aimed near them has coiled back and fixed its
## aim, they change their line (swerving the other way, `dodge` m/s across), as a player would on seeing it.
## Whether they were caught.
func pass_by(h: MazeHydra, side: float, speed: float, start: float, dodge := 0.0, seed_value := 0) -> bool:
	caught.clear()
	var at := home - out * start + across * side
	var runner := dummy(at, out)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var swerve := 0.0
	var seen := {}
	var gone := 0.0
	var got := false
	var low := -wall_right + 1.0
	var high := wall_left - 1.0
	while gone < start * 2.0:
		var step := 1.0 / 60.0
		if dodge > 0.0:
			for slot in h.figure.head_slots():
				if h.figure.stage(slot) != Hydra.Stage.WIND:
					seen.erase(slot)
					continue
				# (a moment after its aim is fixed: a person's reaction to seeing it coiled and still)
				var due := h.figure.strikes_in(slot)
				if not seen.has(slot) and due < h.figure.lock - 0.12 and h.figure.aim_of(slot).distance_to(runner.global_position + Vector3.UP) < 4.0:
					seen[slot] = true
					# (away from the head, across the hall, out of the end of its dart)
					var off := (runner.global_position - h.figure.root_of(slot)).dot(across)
					swerve = signf(off) * dodge if absf(off) > 0.3 else dodge * (1.0 if rng.randf() < 0.5 else -1.0)
		var lateral := swerve
		var now_side := (runner.global_position - home).dot(across)
		if now_side + lateral * step < low or now_side + lateral * step > high:
			lateral = -lateral
			swerve = -swerve
		var forward := sqrt(maxf(speed * speed - lateral * lateral, 0.5))
		runner.velocity = out * forward + across * lateral
		runner.global_position += runner.velocity * step
		gone += forward * step
		await physics_frame
		if caught.has(runner):
			got = true
			break
	runner.free()
	return got


func _run() -> void:
	find_hall(2)
	# (it lies in the middle of the hall, which is not always the middle of the cell it is put in)
	var probe := MazeHydra.new()
	probe.maze = maze
	home = probe._middle_of_hall(maze.world(lair))
	probe.free()
	wall_left = wall_distance(home, across)
	wall_right = wall_distance(home, -across)
	print("hall %s, along %s, walls %.1f m and %.1f m to the sides" % [lair, out, wall_left, wall_right])

	# Nobody about: it lies asleep in its pool.
	var h := hydra_at(home)
	await wait(2.0)
	check("with nobody about it lies asleep in its pool", h.mode == MazeHydra.Mode.RESTING and not h.figure.awake and Vector2(h.global_position.x - h._home.x, h.global_position.z - h._home.z).length() < 0.3, "(%s)" % MazeHydra.Mode.keys()[h.mode])
	check("it has its pool", h.pool != null and h.pool.is_inside_tree())
	check("it has %d heads" % h.heads, h.figure.head_count() == h.heads, "(%d)" % h.figure.head_count())
	check("it can reach about 8 m from its necks' roots", h.figure.reach() > 7.5 and h.figure.reach() < 10.5, "(%.1f m)" % h.figure.reach())

	# Someone walking past well off does not wake it; someone running does.
	var walker := dummy(home + out * 19.0, -out)
	walker.velocity = across * 1.4
	await wait(2.0)
	check("someone walking 19 m off does not wake it", h.mode == MazeHydra.Mode.RESTING)
	walker.velocity = across * 4.4
	var woke := await wait(2.0, func() -> bool: return h.mode != MazeHydra.Mode.RESTING)
	check("someone running 19 m off wakes it", woke, "(%s)" % MazeHydra.Mode.keys()[h.mode])
	clear()

	h = hydra_at(home)
	await wait(0.5)
	var creeper := dummy(home + out * 11.0, -out)
	woke = await wait(2.0, func() -> bool: return h.mode != MazeHydra.Mode.RESTING)
	check("someone coming within 11 m wakes it", woke)
	creeper.free()
	clear()

	# Awake, it strikes at someone in reach: a wind-up first (coiled back, hissing), several heads at once, and it catches them.
	h = hydra_at(home, true)
	var hissed := [0]
	h.figure.hissed.connect(func(_slot: int) -> void: hissed[0] += 1)
	await wait(1.6)
	var still := dummy(home + out * 6.5 + across * 1.5, -out)
	var most := 0
	var wound_first := false
	var got := false
	for i in 60 * 5:
		await physics_frame
		most = maxi(most, striking(h))
		for slot in h.figure.head_slots():
			if h.figure.stage(slot) == Hydra.Stage.WIND and h.figure.progress(slot) > 0.5:
				wound_first = true
		if caught.has(still):
			got = true
			break
	check("it winds up (coils back and hisses) before it darts", wound_first and hissed[0] > 0, "(%d hisses)" % hissed[0])
	check("it catches someone standing in its reach", got)
	caught.clear()
	# (spared a moment, they are struck at again, by several at once)
	still.global_position = home + out * 5.0 - across * 2.0
	most = 0
	var slots_seen := {}
	for i in 60 * 4:
		await physics_frame
		var n := striking(h)
		most = maxi(most, n)
		for slot in h.figure.head_slots():
			if h.figure.stage(slot) == Hydra.Stage.WIND:
				slots_seen[slot] = true
	check("several heads strike at once", most >= 2, "(%d at most)" % most)
	check("different heads take their turn", slots_seen.size() >= 3, "(%d heads)" % slots_seen.size())
	check("no more than %d at once" % h.most_at_once, most <= h.most_at_once)
	still.free()
	clear()

	# Out of its reach behind it, by its tail, nobody is struck at.
	h = hydra_at(home, true)
	await wait(1.6)
	var behind := dummy(home - out * 9.5, out)
	var struck_at := [0]
	h.figure.hissed.connect(func(_slot: int) -> void: struck_at[0] += 1)
	# (it turns to face them, slowly, so they are only safe a moment: watch while it is still turned away)
	await wait(1.5)
	check("someone behind it, out of its reach, is not struck at at once", struck_at[0] == 0 and caught.is_empty(), "(%d strikes)" % struck_at[0])
	behind.free()
	clear()

	# Passing it: walking is caught; sprinting past, changing line, mostly gets through.
	var walks := 0
	var sprints := 0
	var straight := 0
	var trials := 8
	for k in trials:
		h = hydra_at(home, true, 10 + k)
		await wait(1.6)
		var side := (wall_left - 1.5) * (0.5 + 0.06 * k) if k % 2 == 0 else -(wall_right - 1.5) * (0.5 + 0.06 * k)
		var walked := await pass_by(h, side, 1.6, 16.0)
		clear()
		h = hydra_at(home, true, 20 + k)
		await wait(1.6)
		var sprinted := not await pass_by(h, side, 5.6, 16.0, 3.0, k)
		clear()
		h = hydra_at(home, true, 30 + k)
		await wait(1.6)
		var ran := not await pass_by(h, side, 4.4, 16.0, 0.0, k)
		clear()
		walks += 1 if walked else 0
		sprints += 1 if sprinted else 0
		straight += 1 if ran else 0
		print("  %.1f m to the side: walking %s, sprinting and swerving %s, running straight %s" % [side, "caught" if walked else "through", "through" if sprinted else "caught", "through" if ran else "caught"])
	check("someone walking past it through its reach is caught", walks >= trials - 1, "(%d of %d)" % [walks, trials])
	check("someone sprinting past, swerving as each head coils, mostly gets through", sprints >= trials / 2, "(%d of %d)" % [sprints, trials])
	check("running straight past is a gamble", straight < trials, "(%d of %d got through)" % [straight, trials])

	# It never strikes round a corner: someone in reach but out of sight behind a wall.
	h = hydra_at(home, true)
	await wait(1.6)
	var hidden_at := Vector3.INF
	for k in range(4, 9):
		for s: Vector3 in [across, -across]:
			var p: Vector3 = home + s * float(k) + out * 1.5
			var wall := wall_distance(home + out * 1.5, s)
			if float(k) > wall + 2.0 and h.figure.can_reach(4, p + Vector3.UP):
				hidden_at = p
	if hidden_at.is_finite():
		var hider := dummy(hidden_at, -across)
		var tries := [0]
		h.figure.hissed.connect(func(_slot: int) -> void: tries[0] += 1)
		await wait(2.5)
		check("it does not strike through a wall", tries[0] == 0 and caught.is_empty(), "(%d strikes)" % tries[0])
		hider.free()
	else:
		print("(no place behind a wall within its reach here: not checked)")
	clear()

	# With nobody near, it lies down again.
	h = hydra_at(home, true)
	h.rest_after = 3.0
	var lay := await wait(6.0, func() -> bool: return h.mode == MazeHydra.Mode.RESTING)
	check("with nobody near it lies down again", lay)
	clear()

	# A head cut off grows back as two.
	h = hydra_at(home, true)
	h.figure.regrow_time = 1.0
	h.figure.grow_time = 0.8
	await wait(2.0)
	var slot: int = h.figure.head_slots()[2]
	var did_cut: bool = h.cut(h.figure.head_of(slot) + Vector3.UP * 0.2)
	await wait(0.2)
	check("a cut near a head takes it off", did_cut and h.figure.head_count() == h.heads - 1 and h.figure.stage(slot) == Hydra.Stage.STUMP, "(%d heads)" % h.figure.head_count())
	check("a cut nowhere near a head does nothing", not h.cut(home - out * 6.0 + Vector3.UP))
	await wait(2.5)
	check("two heads grow back out of the stump", h.figure.head_count() == h.heads + 1, "(%d heads)" % h.figure.head_count())
	clear()

	# A puppet copy follows the host, striking when it does.
	h = hydra_at(home, true)
	var copy := MazeHydra.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = h.position
	copy.rotation.y = h.rotation.y
	stage.add_child(copy)
	await wait(1.2)
	var target := dummy(home + out * 6.0, -out)
	var copy_struck := false
	var copy_awake := false
	var worst := 0.0
	for i in 360:
		if i % 5 == 0:
			copy.from_bytes(h.state_bytes())
		await physics_frame
		copy_awake = copy_awake or copy.figure.awake
		copy_struck = copy_struck or striking(copy) > 0
		worst = maxf(worst, copy.global_position.distance_to(h.global_position))
	check("a puppet hydra follows the host's news", worst < 1.0, "(at worst %.2f m off)" % worst)
	check("it is awake when the host's is", copy_awake)
	check("its heads strike when the host's do", copy_struck)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, h.state_bytes().size() == MazeEnemy.STATE_SIZE)
	target.free()
	clear()

	# What it costs: posing it, awake with all its heads up, every frame (its necks' chains and the shader's spines).
	h = hydra_at(home, true)
	await wait(1.0)
	h.figure.set_process(false)
	var began := Time.get_ticks_usec()
	for i in 200:
		h.figure._process(1.0 / 60.0)
	var each := float(Time.get_ticks_usec() - began) / 200.0 / 1000.0
	check("posing it awake costs little (%.3f ms a frame)" % each, each < 0.6)
	clear()

	# The hiss, made in code.
	var hiss := Hydra.hiss_sound()
	check("its hiss is made (%.1f s)" % hiss.get_length(), hiss.get_length() > 0.8)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
