extends SceneTree
## The chickens (scripts/enemies/chickens.gd, creatures/chicken/), headless, in a
## bare scene: a maze from MazeBuilder and a stand-in player that the test moves
## by hand (a CharacterBody3D with no shape, so its `velocity` is whatever the
## test says). In turn: the flock is made (a rooster and his hens, one draw);
## left alone they forage about their cell (walking, pecking, scratching), out
## of the walls; standing quietly a little way off, or creeping by crouched,
## does not startle them; running past does: they explode (running and flying,
## feathers loose) and the racket calls a dormant mummy to the hunt; they settle
## and go back to foraging; running into one sets the flock mobbing (round the
## head, some in the air), and getting well away ends it; they never catch
## anyone; a puppet flock follows the host's news; MazeEnemies' packing carries
## it; and what a flock costs a frame. Then tame chickens (wildlife): placed in the
## clearing, scattered by a runner but calling nobody and never mobbing; the
## low-detail bird; the sounds.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/chicken_test.gd
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
	runner = CharacterBody3D.new()
	var body := GDScript.new()
	body.source_code = "extends CharacterBody3D
var is_ducking := false
"
	body.reload()
	runner.set_script(body)
	runner.name = "Runner"
	runner.collision_layer = 0
	runner.collision_mask = 0
	stage.add_child(runner)
	runner.add_to_group(&"maze_players")
	_run.call_deferred()


## A passage cell with `run` open cells straight on from it, out of the clearing, and that way.
func straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(4):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return []


func put(at: Vector3, moving := Vector3.ZERO) -> void:
	runner.global_position = at
	runner.velocity = moving


func _run() -> void:
	await frames(10)
	var found := straight_run(4)
	check("a straight passage to test in", not found.is_empty())
	var start: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	put(maze.world(start) - along * 200.0)
	var chickens := Chickens.new()
	chickens.name = "Chickens"
	chickens.maze = maze
	chickens.seed_choices(1234)
	chickens.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(chickens)
	chickens.caught.connect(func(_who: Node3D) -> void: caught += 1)
	await frames(5)
	var flock: ChickenFlock = chickens.flock
	var home: Vector3 = maze.world(start + way * 2)
	var roosters := 0
	for i in flock.count:
		if flock.is_rooster(i):
			roosters += 1
	check("a flock of 8 to 13, one of them a rooster", flock.count >= 8 and flock.count <= 13 and roosters == 1, "(%d birds, %d roosters)" % [flock.count, roosters])
	var meshes := flock.find_children("*", "MultiMeshInstance3D", false, false)
	check("the birds are one MultiMesh (and one for loose feathers)", meshes.size() == 2 and (meshes[0] as MultiMeshInstance3D).multimesh.instance_count == flock.count)

	# A mummy, dormant, some way down the passage, to hear the racket.
	var mummy := Mummy.new()
	mummy.name = "Mummy"
	mummy.start_dormant = true
	mummy.sight_range = 0.0
	mummy.hear_range = 0.0
	mummy.maze = maze
	mummy.position = maze.world(start + way * 4) + Vector3.UP * 0.05
	stage.add_child(mummy)

	# Left alone, they forage about home, out of the walls.
	var seen := {}
	var far := 0.0
	var walls := 0
	var flock_camera := Camera3D.new()
	stage.add_child(flock_camera)
	flock_camera.global_position = home + Vector3(0, 3, 0)
	flock_camera.current = true
	for f in 60 * 12:
		await physics_frame
		for i in flock.count:
			seen[flock.act_of(i)] = true
			var at := flock.bird_position(i)
			far = maxf(far, Vector2(at.x - home.x, at.z - home.z).length())
			if not nav.clear_of_walls(at, 0.0):
				walls += 1
	check("left alone, they walk, peck and scratch", seen.has(ChickenFlock.Act.WALK) and seen.has(ChickenFlock.Act.PECK) and seen.has(ChickenFlock.Act.SCRATCH), "(acts seen: %s)" % [seen.keys().map(func(a: int) -> String: return ChickenFlock.Act.keys()[a])])
	check("they keep about home", far < chickens.roam + 1.5, "(at most %.1f m from it)" % far)
	check("and out of the walls", walls == 0, "(%d bird-frames in a wall)" % walls)
	check("nobody near: foraging", chickens.mode == Chickens.Mode.FORAGE)

	# Standing quietly 7 m off: nothing. Creeping past crouched, 2.5 m off: nothing.
	var centre := flock.centre()
	put(Vector3(centre.x, 0.05, centre.z) - along * 7.0)
	await frames(60)
	check("someone standing quietly 7 m off does not startle them", chickens.mode == Chickens.Mode.FORAGE)
	# (crouched, walking slowly along, 2.5 m from the nearest of them)
	runner.set(&"is_ducking", true)
	var side := Vector3(-along.z, 0.0, along.x)
	var creep_from := Vector3(centre.x, 0.05, centre.z) - along * 6.0 + side * 2.5
	var closest := INF
	for i in 60 * 8:
		put(creep_from + along * 1.2 * i / 60.0, along * 1.2)
		await physics_frame
		closest = minf(closest, chickens._nearest_bird(runner.global_position))
		if chickens.mode != Chickens.Mode.FORAGE:
			break
	check("creeping past crouched does not startle them", chickens.mode == Chickens.Mode.FORAGE, "(as near as %.1f m)" % closest)
	runner.set(&"is_ducking", false)

	# Running past: they explode, and the racket wakes the mummy.
	var spotted := [false]
	chickens.spotted.connect(func(_who: Node3D) -> void: spotted[0] = true)
	var from := flock.centre() - along * 14.0
	from.y = 0.05
	var pace := 4.4
	for i in 180:
		put(from + along * pace * i / 60.0, along * pace)
		await physics_frame
		if chickens.mode == Chickens.Mode.PANIC:
			break
	check("running past startles them", chickens.mode == Chickens.Mode.PANIC and spotted[0], "(%.1f m from the nearest bird)" % chickens._nearest_bird(runner.global_position))
	put(runner.global_position)
	var most_panicked := 0
	var most_flying := 0
	var most_loose := 0
	for i in 90:
		await physics_frame
		most_panicked = maxi(most_panicked, flock.panicking())
		most_flying = maxi(most_flying, flock.flying())
		most_loose = maxi(most_loose, flock.loose_feathers())
	check("the whole flock bolts", most_panicked >= flock.count - 1, "(%d of %d at once)" % [most_panicked, flock.count])
	check("some take to the air", most_flying >= 2, "(%d at once)" % most_flying)
	check("feathers fly", most_loose >= 5, "(%d loose)" % most_loose)
	check("the racket calls the mummy to the hunt", mummy.quarry == runner, "(mummy %s)" % Mummy.Mode.keys()[mummy.mode])
	var settled := false
	for i in 60 * 15:
		await physics_frame
		if chickens.mode == Chickens.Mode.FORAGE and flock.panicking() == 0:
			settled = true
			break
	check("they settle, and forage again", settled)
	mummy.queue_free()

	# Running into one: the rooster's rage, and the flock mobs them.
	put(runner.global_position - along * 30.0)
	await frames(60 * 6)
	var bird: Vector3 = flock.bird_position(2)
	put(Vector3(bird.x, 0.05, bird.z) - along * 0.2, along * 1.5)
	await frames(20)
	check("running into one sets them mobbing", chickens.mode == Chickens.Mode.MOB and flock.mobbing())
	put(runner.global_position)
	var round_head := 0
	var up := 0
	var near_count := 0
	for i in 60 * 3:
		await physics_frame
		var head := runner.global_position + Vector3.UP * 1.5
		near_count = 0
		for b in flock.count:
			if flock.bird_position(b).distance_to(head) < 1.8:
				near_count += 1
		round_head = maxi(round_head, near_count)
		up = maxi(up, flock.flying())
	check("they mob round their head", round_head >= flock.count / 2, "(at most %d of %d within 1.8 m of it)" % [round_head, flock.count])
	check("leaping and beating in the air", up >= 3, "(%d up at once)" % up)
	var puppet_copy := Chickens.new()
	puppet_copy.name = "ChickensCopy"
	puppet_copy.maze = maze
	puppet_copy.puppet = true
	puppet_copy.seed_choices(1234)
	puppet_copy.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(puppet_copy)
	await frames(3)
	for i in 30:
		if i % 6 == 0:
			puppet_copy.from_bytes(chickens.state_bytes())
		await physics_frame
	check("a puppet flock follows: mobbing too", puppet_copy.mode == Chickens.Mode.MOB and puppet_copy.flock.mobbing() and puppet_copy.flock.count == flock.count)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, chickens.state_bytes().size() == MazeEnemy.STATE_SIZE)
	# Getting well away ends it.
	var away := runner.global_position
	var ended := false
	for i in 60 * 10:
		put(away - along * minf(i * 0.15, 60.0), -along * 5.0)
		await physics_frame
		if i % 6 == 0:
			puppet_copy.from_bytes(chickens.state_bytes())
		if chickens.mode != Chickens.Mode.MOB:
			ended = true
			break
	check("getting away ends the mob", ended, "(%.1f m from home)" % runner.global_position.distance_to(home))
	for i in 12:
		if i % 6 == 0:
			puppet_copy.from_bytes(chickens.state_bytes())
		await physics_frame
	check("and the puppet's", not puppet_copy.flock.mobbing())
	check("they catch nobody", caught == 0)

	# Placed by MazeEnemies: packed and unpacked with the rest.
	put(maze.world(start) - along * 200.0)
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(Chickens.new(), start + way, 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(Chickens.new(), start + way, 0.0, 77)
	await frames(3)
	(a as Chickens).startle(runner)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks a flock", (a as Chickens).mode == Chickens.Mode.PANIC and (b as Chickens).mode == Chickens.Mode.PANIC and b.puppet and (b as Chickens).flock.count == (a as Chickens).flock.count, "(modes %d, %d; %d, %d birds)" % [(a as Chickens).mode, (b as Chickens).mode, (a as Chickens).flock.count, (b as Chickens).flock.count])

	# (the hostile flocks out of the way first: their racket would call the mummy)
	for node: Node in [chickens, puppet_copy, set_a, set_b]:
		node.queue_free()
	await frames(2)
	await _tame(start, way)
	# What a flock costs: its frame's work, panicking (the busiest it gets).
	var big := ChickenFlock.new()
	big.count = 15
	big.home = home
	stage.add_child(big)
	await frames(2)
	big.scare(home + Vector3(1, 0, 0))
	var t0 := Time.get_ticks_usec()
	for i in 120:
		big._process(1.0 / 60.0)
	var each := (Time.get_ticks_usec() - t0) / 120.0 / 1000.0
	check("a flock of 15 costs well under a millisecond a frame", each < 1.0, "(%.3f ms)" % each)
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


## Tame chickens (scripts/wildlife/tame_chickens.gd): placed in the clearing away
## from the middle and the gate paths, the same from the same seed; running
## through scatters them but calls nobody, and even running into one, they never
## mob; they are no pursuers. And the low-detail bird, and the sounds.
func _tame(start: Vector2i, way: Vector2i) -> void:
	var along := Vector3(way.x, 0, way.y)
	var holder := Node3D.new()
	stage.add_child(holder)
	var flocks := TameChickens.populate(holder, maze, 99)
	var again := Node3D.new()
	stage.add_child(again)
	var flocks_again := TameChickens.populate(again, maze, 99)
	await frames(3)
	var look: ClearingStyle = maze.clearing_style
	var in_clearing := 0
	var placed_ok := true
	var same := flocks.size() == flocks_again.size()
	for k in flocks.size():
		var at := flocks[k].global_position
		if maze.in_clearing(maze.cell_at(at)):
			in_clearing += 1
		var flat := Vector2(at.x, at.z)
		if flat.length() < 45.0:
			placed_ok = false
		for gate: Array in look.entrance_spots:
			if Geometry2D.get_closest_point_to_segment(flat, Vector2.ZERO, gate[0]).distance_to(flat) < 15.0:
				placed_ok = false
		if same and (flocks_again[k].global_position.distance_to(at) > 0.01 or flocks_again[k].flock.count != flocks[k].flock.count):
			same = false
	check("tame flocks in the clearing, as its style says", in_clearing == look.chicken_flocks, "(%d of %d)" % [in_clearing, look.chicken_flocks])
	check("away from the middle and the paths to the gates", placed_ok)
	check("the same flocks from the same seed", same)
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	if not woods.is_empty() and not flocks.is_empty():
		var d := Vector2(flocks[0].global_position.x, flocks[0].global_position.z).distance_to(woods[0])
		check("the first at the edge of the woods", d > look.woods_size * 0.9 and d < look.woods_size * 1.2, "(%.0f m from the woods' gate; the woods reach %.0f)" % [d, look.woods_size])
	again.queue_free()
	check("tame chickens are not pursuers nor hunters", not flocks[0].is_in_group(&"pursuers") and not flocks[0].is_in_group(&"maze_enemies") and flocks[0].flock.tame)

	# One in the maze, with a dormant mummy near: run through, then into them.
	var tame := TameChickens.new(maze, 4321)
	tame.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(tame)
	var mummy := Mummy.new()
	mummy.start_dormant = true
	mummy.sight_range = 0.0
	mummy.hear_range = 0.0
	mummy.maze = maze
	mummy.position = maze.world(start + way * 4) + Vector3.UP * 0.05
	stage.add_child(mummy)
	await frames(120)
	var middle := tame.flock.centre()
	var from := Vector3(middle.x, 0.05, middle.z) - along * 8.0
	var scattered := 0
	for i in 60 * 4:
		put(from + along * 4.4 * i / 60.0, along * 4.4)
		await physics_frame
		scattered = maxi(scattered, tame.flock.panicking())
	check("running through scatters them", scattered >= 3, "(%d at once)" % scattered)
	var bird: Vector3 = tame.flock.bird_position(0)
	for i in 30:
		put(Vector3(bird.x, 0.05, bird.z), along * 1.5)
		await physics_frame
	check("running into one: no mob", not tame.flock.mobbing())
	put(runner.global_position + along * 200.0)
	var settled := false
	for i in 60 * 15:
		await physics_frame
		if tame.flock.panicking() == 0:
			settled = true
			break
	var acts := []
	for b in tame.flock.count:
		acts.append("%s %.1f m up" % [ChickenFlock.Act.keys()[tame.flock.act_of(b)], tame.flock._birds[b].height])
	check("they settle soon", settled, str(acts))
	check("and they called nobody", mummy.quarry == null and not mummy.is_awake(), "(mummy %s)" % Mummy.Mode.keys()[mummy.mode])
	mummy.queue_free()
	holder.queue_free()
	tame.queue_free()

	# The low-detail bird, and the sounds.
	var full := ChickenBody.mesh(false).get_faces().size() / 3
	var low := ChickenBody.mesh(true).get_faces().size() / 3
	check("a low-detail bird for phones", low > 0 and low * 2 < full, "(%d triangles against %d)" % [low, full])
	ChickenVoice._make_sounds()
	check("clucks, squawks and a crow made in code", ChickenVoice._clucks.size() == 3 and ChickenVoice._squawks.size() == 2 and ChickenVoice._crow != null and ChickenVoice._crow.data.size() > 16000)
