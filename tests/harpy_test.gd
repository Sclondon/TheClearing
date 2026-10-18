extends SceneTree
## The harpy (scripts/enemies/maze_harpy.gd, creatures/harpy/), headless, in a
## bare scene: a maze from MazeBuilder and a stand-in player that the test moves
## by hand (a CharacterBody3D with no shape, with `velocity` and `is_ducking`).
## In turn: it finds a perch high on a wall (the ledge, or the top) facing out
## over a hall; someone out in the open in front of it is seen, screeched at,
## and it takes off, out and up over the wall tops, and circles over them;
## someone under a roof (a bridge, a platform) or in the clearing cannot be dived
## at; it stoops (crying) and dives down the hall, and someone who stands still
## is snatched; someone who ducks as it comes is missed, and so is someone who
## steps aside once its line is set; it climbs away; when they stay under cover
## it gives up, flies home and lands on its perch; a puppet follows the host's
## news; MazeEnemies' packing carries it; it is one draw (and its shadow).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/harpy_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var runner: CharacterBody3D
var failures := 0
var caught := 0
var trace := OS.get_cmdline_user_args().has("trace")


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


## Where to stand in the open in front of a harpy's perch: out in its hall, on the ground.
func in_front(harpy: MazeHarpy, out := 7.0) -> Vector3:
	var at: Vector3 = harpy.perch + harpy.perch_out * out
	return Vector3(at.x, maze.ground_height(at) + 0.05, at.z)


func _run() -> void:
	await frames(10)
	# Nobody near at first.
	put(Vector3(0, 0.05, 0))
	var lairs: Array[Vector2i] = nav.lairs(4)
	var harpy := MazeHarpy.new()
	harpy.name = "Harpy"
	harpy.maze = maze
	harpy.seed_choices(99)
	harpy.position = maze.world(lairs[lairs.size() / 2]) + Vector3.UP * 0.05
	stage.add_child(harpy)
	harpy.caught.connect(func(_who: Node3D) -> void: caught += 1)
	await frames(5)
	var ground: float = maze.ground_height(harpy.perch)
	var feet: Vector3 = harpy.perch - Vector3.UP * Harpy.STAND_HEIGHT * MazeHarpy.SIZE
	var under := harpy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.3, feet + Vector3.DOWN * 1.0, 1))
	check("it perches high on a wall", harpy.mode == MazeHarpy.Mode.PERCH and feet.y - ground > 8.0, "(%.1f m up)" % (feet.y - ground))
	check("its feet are on stone (a ledge or the wall top)", not under.is_empty() and (under["position"] as Vector3).distance_to(feet) < 0.4, "(%s)" % ("nothing under it" if under.is_empty() else "%.2f m above it" % (under["position"] as Vector3).distance_to(feet)))
	var open := harpy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(harpy.perch, harpy.perch + harpy.perch_out * 5.0, 1))
	check("it faces out over open air", open.is_empty())
	await frames(60)
	check("with nobody about it sits", harpy.mode == MazeHarpy.Mode.PERCH)

	# Who is under cover cannot be dived at: here, under a slab of stone (a bridge, a
	# platform) put over a spot out in the hall.
	var shelter: Vector3 = in_front(harpy, 7.0) + harpy.perch_out.cross(Vector3.UP) * 3.0
	var roof := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.5, 4.0)
	slab.shape = box
	roof.add_child(slab)
	stage.add_child(roof)
	roof.global_position = shelter + Vector3.UP * 3.0
	var wall_foot: Vector3 = shelter
	put(wall_foot)
	await frames(2)
	check("under a roof (a bridge, a platform) is under cover", not harpy.exposed(runner))
	put(Vector3(0, 0.05, 0))
	await frames(2)
	check("in the clearing nobody is hunted", not harpy.exposed(runner))

	# Out in the open in front of it: seen, screeched at.
	var spot := in_front(harpy, 7.0)
	put(spot)
	await frames(2)
	check("out in the open in its hall, they can be dived at", harpy.exposed(runner))
	var screeched := await until(2.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.SCREECH)
	check("it sees them and screeches", screeched and harpy.look.screeching())
	var up := await until(MazeHarpy.SCREECH_TIME + 8.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.CIRCLE)
	var top: float = maze.maze_wall_height(maze.ring_of(maze.cell_at(spot)))
	check("it takes off and climbs over the walls to circle", up and harpy.global_position.y > top + 2.0, "(at %.1f m, the walls %.1f m)" % [harpy.global_position.y, top])
	var stooped := await until(8.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.STOOP)
	check("after circling a while it stoops (the cry)", stooped)
	# It dives, and someone standing still is taken.
	var dived := await until(4.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.DIVE)
	check("it dives into the hall", dived)
	# (counted in an array: a lambda's own locals do not reach out of it)
	var inside_walls := [0]
	var start_caught := caught
	await until(6.0, func() -> bool:
		if not harpy.maze_free(harpy.global_position):
			inside_walls[0] += 1
		return harpy.mode == MazeHarpy.Mode.CLIMB)
	check("standing still, they are snatched", caught == start_caught + 1 and harpy.snatched, "(its talons came within %.2f m, %s from their feet)" % [harpy.closest, harpy.closest_at])
	check("it never goes through stone", inside_walls[0] == 0, "(%d frames inside)" % inside_walls[0])
	check("it never catches anyone but by its talons (one catch)", caught == start_caught + 1)
	# (they are let alone a while after being caught)
	await frames(int(harpy.spare_time * 60.0) + 10)

	# A second harpy: the duck, and the sidestep.
	var dodges := [false, false]
	for k in 2:
		var other := MazeHarpy.new()
		other.name = "Harpy%d" % k
		other.maze = maze
		other.seed_choices(7 + k)
		other.circle_time = Vector2(1.0, 1.0)
		other.position = harpy.position
		stage.add_child(other)
		other.caught.connect(func(_who: Node3D) -> void: caught += 1)
		harpy.process_mode = Node.PROCESS_MODE_DISABLED
		harpy.visible = false
		await frames(3)
		put(in_front(other, 7.0))
		runner.set(&"is_ducking", false)
		var went := await until(20.0, func() -> bool: return other.mode == MazeHarpy.Mode.DIVE)
		if not went:
			check("the harpy dives again (%s)" % ("duck" if k == 0 else "sidestep"), false, "(mode %s)" % MazeHarpy.Mode.keys()[other.mode])
			continue
		var before := caught
		var moved := [false]
		await until(6.0, func() -> bool:
			if not moved[0] and other._locked:
				moved[0] = true
				if k == 0:
					runner.set(&"is_ducking", true)
				else:
					var across: Vector3 = other.dive_along.cross(Vector3.UP).normalized()
					put(runner.global_position + across * 1.7)
			return other.mode == MazeHarpy.Mode.CLIMB)
		dodges[k] = moved[0] and caught == before
		print("      (%s: the talons came within %.2f m, %s from their feet)" % ["duck" if k == 0 else "sidestep", other.closest, other.closest_at])
		runner.set(&"is_ducking", false)
		other.queue_free()
	check("ducking as it comes, the talons pass over", dodges[0])
	check("stepping aside once its line is set, they pass by", dodges[1])
	harpy.process_mode = Node.PROCESS_MODE_INHERIT
	harpy.visible = true

	# Under cover it loses them, gives up and goes home.
	put(spot)
	await until(12.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.CIRCLE)
	put(wall_foot)
	var home := await until(harpy.lose_time + 30.0, func() -> bool: return harpy.mode == MazeHarpy.Mode.PERCH)
	check("kept under cover, it gives up, flies home and lands", home and harpy.global_position.distance_to(harpy.perch) < 0.1)

	# A puppet follows the host's news.
	var copy := MazeHarpy.new()
	copy.name = "HarpyCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(99)
	copy.position = harpy.position
	stage.add_child(copy)
	await frames(3)
	put(spot)
	var behind := 0.0
	var agreed := 0
	var looked := 0
	for i in 60 * 12:
		if i % 6 == 0:
			copy.from_bytes(harpy.state_bytes())
		await physics_frame
		if i > 30:
			looked += 1
			behind = maxf(behind, copy.global_position.distance_to(harpy.global_position))
			if copy.mode == harpy.mode:
				agreed += 1
	check("a puppet follows", behind < 4.0 and agreed > looked * 0.85, "(at worst %.2f m behind; same mode %d of %d frames)" % [behind, agreed, looked])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, harpy.state_bytes().size() == MazeEnemy.STATE_SIZE)

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(MazeHarpy.new(), lairs[0], 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(MazeHarpy.new(), lairs[0], 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks a harpy", b.puppet and (b as MazeHarpy).mode == (a as MazeHarpy).mode and b.global_position.distance_to(a.global_position) < 0.5)
	var meshes := harpy.look.find_children("*", "MeshInstance3D", true, false)
	check("it is one skinned mesh at a time (a full one near, a low one far)", meshes.size() == 2)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
