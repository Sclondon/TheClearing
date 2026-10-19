extends SceneTree
## The wyverns (scripts/enemies/maze_wyvern.gd, creatures/wyvern/), headless,
## in a bare scene: a maze from MazeBuilder and a stand-in player that the
## test moves by hand (a CharacterBody3D with no shape, with `velocity` and
## `is_ducking`). In turn: a pair put in one hall nest on one nest on a high
## wall top; under a roof or in a narrow passage is out of their reach, a wide
## hall in the open; one that is not keen lets someone in the open be; one that
## is keen sees them, screams and launches, comes over them screaming, wheels
## round and dives, snatches someone standing still and carries them off; one
## that lands to stalk them catches with the lash someone who stands still, and
## misses someone who runs once the tail coils; anyone who climbs up near the
## nest is gone for at once, keen or not; a puppet follows the host's news;
## MazeEnemies' packing carries it; it is one draw (and its shadow); and,
## when Ecology knows the kind, a hungry one takes a deer out in the open home
## to its nest.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/wyvern_test.gd
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


func on_ground(at: Vector3) -> Vector3:
	return Vector3(at.x, maze.ground_height(at) + 0.05, at.z)


## A slab of stone `size` across at `at` (a roof, or a wall).
func slab(at: Vector3, size: Vector3) -> StaticBody3D:
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	block.add_child(shape)
	stage.add_child(block)
	block.global_position = at
	return block


func make(cell: Vector2i, seed_value: int) -> MazeWyvern:
	var w := MazeWyvern.new()
	w.name = "Wyvern%d" % seed_value
	w.maze = maze
	w.seed_choices(seed_value)
	w.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(w)
	w._roost_left = 9999.0
	w._keen_left = 9999.0
	w.caught.connect(func(_who: Node3D) -> void: caught += 1)
	return w


func away() -> void:
	put(Vector3(0, 0.05, 0))


func _run() -> void:
	await frames(10)
	away()
	# A hall out in the open, with room to land in front of whoever stands there.
	var lairs: Array[Vector2i] = nav.lairs(4)
	var probe := make(lairs[0], 1)
	await frames(3)
	var home := Vector2i(-1, -1)
	for cell in lairs:
		put(on_ground(maze.world(cell)))
		await frames(1)
		if probe.exposed(runner) and probe._landing_spot(runner, probe._ways_down(runner)[0]).is_finite():
			home = cell
			break
	probe.queue_free()
	away()
	check("there is a hall out in the open to test in", home.x >= 0)
	if home.x < 0:
		print("FAILED (no open hall)")
		quit(1)
		return
	var spot := on_ground(maze.world(home))

	# The pair, on one nest.
	var w := make(home, 99)
	var mate := make(home, 98)
	await frames(5)
	var feet: Vector3 = w.roost - Vector3.UP * Wyvern.STAND_HEIGHT
	var ground: float = maze.ground_height(feet)
	check("it nests high on a wall top", w.mode == MazeWyvern.Mode.ROOST and feet.y - ground > 8.0 and w.nest != null, "(%.1f m up, nest %s)" % [feet.y - ground, w.nest])
	check("its mate shares the nest", mate.nest == null and mate.nest_at == w.nest_at and mate.roost.distance_to(w.roost) > 0.5 and mate.mode == MazeWyvern.Mode.ROOST, "(%.1f m apart)" % mate.roost.distance_to(w.roost))
	check("it stands there on the ground, solid", w.look.grounded and w.collision_layer == 4)
	mate.process_mode = Node.PROCESS_MODE_DISABLED

	# Out of its reach, in reach.
	var shelter := spot + Vector3(3.0, 0.0, 0.0)
	var roof := slab(shelter + Vector3.UP * 3.0, Vector3(4.0, 0.5, 4.0))
	put(shelter)
	await frames(2)
	check("under a roof is out of its reach", not w.exposed(runner))
	var narrow := spot + Vector3(0.0, 0.0, -4.0)
	var wall_a := slab(narrow + Vector3(2.2, 3.0, 0.0), Vector3(0.6, 6.0, 12.0))
	var wall_b := slab(narrow + Vector3(-2.2, 3.0, 0.0), Vector3(0.6, 6.0, 12.0))
	put(narrow)
	await frames(2)
	check("in a narrow passage is out of its reach", not w.exposed(runner))
	wall_a.queue_free()
	wall_b.queue_free()
	away()
	await frames(2)

	# Not keen, it lets them be.
	w.keen = false
	put(spot)
	var went := await until(3.0, func() -> bool: return w.mode != MazeWyvern.Mode.ROOST)
	check("not keen to hunt, it lets someone in the open be", not went and w.exposed(runner))

	# Keen: the scream and the launch, over them, round, the dive, the snatch.
	w.keen = true
	w.land_chance = 0.0
	var calls_before: int = w._calls
	var launched := await until(3.0, func() -> bool: return w.mode == MazeWyvern.Mode.LAUNCH)
	check("keen, it sees them, screams and launches", launched and w.look.shrieking())
	var nearest_over := [INF]
	var round_again := await until(16.0, func() -> bool:
		nearest_over[0] = minf(nearest_over[0], Vector2(w.global_position.x - spot.x, w.global_position.z - spot.z).length())
		return w.mode == MazeWyvern.Mode.WHEEL)
	check("it comes over them screaming and wheels round", round_again and w._calls >= calls_before + 2 and nearest_over[0] < 5.0, "(within %.1f m; %d screams)" % [nearest_over[0], w._calls - calls_before])
	var dived := await until(20.0, func() -> bool: return w.mode == MazeWyvern.Mode.DIVE)
	check("it dives at them", dived, "(mode %s)" % MazeWyvern.Mode.keys()[w.mode])
	var start_caught := caught
	var inside := [0]
	await until(8.0, func() -> bool:
		if not w.maze_free(w.global_position):
			inside[0] += 1
		return w.mode == MazeWyvern.Mode.CLIMB or caught > start_caught)
	check("standing still, they are snatched and carried off", w.snatched and caught == start_caught + 1, "(its feet within %.2f m)" % w.closest)
	check("it never goes through stone", inside[0] == 0, "(%d frames inside)" % inside[0])
	w.process_mode = Node.PROCESS_MODE_DISABLED
	w.look.visible = false
	away()
	await frames(int(w.spare_time * 60.0) + 10)

	# Landing to stalk: the lash catches whoever stands still, misses whoever runs as it coils.
	var results := {}
	for test: String in ["still", "run"]:
		var other := make(home, 7 + results.size())
		other.land_chance = 1.0
		await frames(3)
		put(spot)
		var landed := await until(40.0, func() -> bool: return other.mode == MazeWyvern.Mode.STALK)
		if not landed:
			results[test] = "never landed (mode %s)" % MazeWyvern.Mode.keys()[other.mode]
			other.queue_free()
			continue
		var land_gap: float = Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length()
		var coiled := await until(12.0, func() -> bool: return other.mode == MazeWyvern.Mode.LASH)
		var before := caught
		if coiled and test == "run":
			# (away from it as fast as he runs, as soon as the tail goes up)
			var off: Vector3 = runner.global_position - other.global_position
			off.y = 0.0
			var dir := off.normalized()
			for i in int(Wyvern.STRIKE_LAND * 60.0) + 10:
				put(on_ground(runner.global_position + dir * 4.4 / 60.0), dir * 4.4)
				await physics_frame
		else:
			await until(Wyvern.STRIKE_TIME + 0.2, func() -> bool: return caught > before)
		results[test] = ("caught" if caught > before else "missed") + " (landed %.1f m off; barb within %.2f m)" % [land_gap, other.lash_closest]
		print("      (%s: %s)" % [test, results[test]])
		other.queue_free()
		away()
		await frames(int(4.0 * 60.0))
	check("landed, it stalks them and the lash catches them standing still", String(results.get("still", "")).begins_with("caught"), "(%s)" % results.get("still", "?"))
	check("running as the tail coils gets them out of its reach", String(results.get("run", "")).begins_with("missed"), "(%s)" % results.get("run", "?"))

	# Up near the nest, it comes at once, keen or not.
	w.process_mode = Node.PROCESS_MODE_INHERIT
	w.look.visible = true
	w._let_be.clear()
	w._spared.clear()
	w._give_up()
	w.global_position = w.roost
	w.look.grounded = true
	w._enter(MazeWyvern.Mode.ROOST)
	w.keen = false
	var by_nest: Vector3 = w.nest_at + w.roost_facing.cross(Vector3.UP) * 3.5 + Vector3.UP * 0.05
	if absf(w._sky_over(by_nest) - w.nest_at.y) > 0.5:
		by_nest = w.nest_at - w.roost_facing * 2.5 + Vector3.UP * 0.05
	put(by_nest)
	var defended := await until(2.0, func() -> bool: return w.mode == MazeWyvern.Mode.LAUNCH)
	check("climbing up by the nest, it comes for them at once (not keen)", defended and w.defending, "(mode %s)" % MazeWyvern.Mode.keys()[w.mode])
	away()

	# A puppet follows the host's news.
	var copy := MazeWyvern.new()
	copy.name = "WyvernCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(99)
	copy.position = w.position
	stage.add_child(copy)
	await frames(3)
	put(spot)
	var behind := 0.0
	var agreed := 0
	var looked := 0
	for i in 60 * 8:
		if i % 6 == 0:
			copy.from_bytes(w.state_bytes())
		await physics_frame
		if i > 30:
			looked += 1
			behind = maxf(behind, copy.global_position.distance_to(w.global_position))
			if copy.mode == w.mode:
				agreed += 1
	check("a puppet follows", behind < 5.0 and agreed > looked * 0.85, "(at worst %.2f m behind; same mode %d of %d frames)" % [behind, agreed, looked])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, w.state_bytes().size() == MazeEnemy.STATE_SIZE)
	copy.queue_free()
	away()

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(MazeWyvern.new(), lairs[0], 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(MazeWyvern.new(), lairs[0], 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks a wyvern", b.puppet and (b as MazeWyvern).mode == (a as MazeWyvern).mode and b.global_position.distance_to(a.global_position) < 0.5 and (b as MazeWyvern).nest != null)
	set_a.queue_free()
	set_b.queue_free()
	var drawn := 0
	for mesh: MeshInstance3D in w.look.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is ArrayMesh and (mesh.mesh as ArrayMesh).get_surface_count() > 0 and mesh.skin != null:
			drawn += 1
	check("it is one skinned mesh at a time (a full one near, a low one far)", drawn == 2, "(%d skinned meshes)" % drawn)

	# The others: a hungry one takes a deer out in the open home to its nest.
	if Ecology.KINDS.has("MazeWyvern"):
		w.queue_free()
		var world := Ecology.put(stage, 5)
		var hunter := make(home, 55)
		await frames(3)
		hunter.hunger = 1.0
		var deer := MazeDeer.new()
		deer.maze = maze
		deer.targets = [runner]
		deer.position = spot
		stage.add_child(deer)
		var fed := await until(60.0, func() -> bool: return deer.dead)
		check("hungry, it takes a deer in the open home to its nest", fed and hunter.mode == MazeWyvern.Mode.ROOST and world.kills >= 1, "(mode %s, deer dead %s)" % [MazeWyvern.Mode.keys()[hunter.mode], deer.dead])
	else:
		print("      (Ecology.KINDS has no MazeWyvern yet: the deer is not tried)")
	roof.queue_free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
