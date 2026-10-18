extends SceneTree
## The pterodactyl (scripts/enemies/maze_pterodactyl.gd, creatures/pterodactyl/),
## headless, in a bare scene: a maze from MazeBuilder and a stand-in player that
## the test moves by hand (a CharacterBody3D with no shape, with `velocity` and
## `is_ducking`). In turn: it roosts on a high wall top near where it is put;
## who is under a roof, in a narrow passage or in the clearing is out of its
## reach, and who is out in a wide hall or up on a wall top is in the open; it
## sees someone in the open, croaks and launches, comes over them (croaking
## overhead), wheels round and dives; someone standing still is snatched and
## carried off (caught only after it has carried them a while), and it never
## goes through stone; ducking does not save anyone, stepping aside once its
## line is set does; getting under cover before its line is set breaks off the
## dive; kept under cover, it gives up, lets them be and soars on; it comes down
## to roost again; a puppet follows the host's news; two never dive at one
## person at once; MazeEnemies' packing carries it; it is one draw (and its shadow).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/pterodactyl_test.gd
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


func make(cell: Vector2i, seed_value: int) -> MazePterodactyl:
	var p := MazePterodactyl.new()
	p.name = "Pterodactyl%d" % seed_value
	p.maze = maze
	p.seed_choices(seed_value)
	p.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(p)
	p.caught.connect(func(_who: Node3D) -> void: caught += 1)
	return p


func _run() -> void:
	await frames(10)
	put(Vector3(0, 0.05, 0))
	# A hall out in the open to put it over (the middle of a lair cell, in the open).
	var lairs: Array[Vector2i] = nav.lairs(4)
	var probe := make(lairs[0], 1)
	probe._roost_left = 9999.0
	await frames(3)
	var home := Vector2i(-1, -1)
	for cell in lairs:
		put(on_ground(maze.world(cell)))
		await frames(1)
		if probe.exposed(runner):
			home = cell
			break
	probe.queue_free()
	put(Vector3(0, 0.05, 0))
	check("there is a hall out in the open to test in", home.x >= 0)
	if home.x < 0:
		print("FAILED (no open hall)")
		quit(1)
		return
	var spot := on_ground(maze.world(home))

	var ptero := make(home, 99)
	ptero._roost_left = 9999.0
	await frames(5)
	var feet: Vector3 = ptero.roost - Vector3.UP * Pterodactyl.STAND_HEIGHT * MazePterodactyl.SIZE
	var ground: float = maze.ground_height(feet)
	var under := ptero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.3, feet + Vector3.DOWN * 1.0, 1))
	check("it roosts high on a wall top", ptero.mode == MazePterodactyl.Mode.ROOST and feet.y - ground > 8.0, "(%.1f m up)" % (feet.y - ground))
	check("its feet are on stone", not under.is_empty() and (under["position"] as Vector3).distance_to(feet) < 0.3)
	check("it stands on all fours there", ptero.look.grounded)
	await frames(60)
	check("with nobody about it stays roosting", ptero.mode == MazePterodactyl.Mode.ROOST)

	# Out of its reach: under a roof, in a narrow passage, in the clearing.
	var shelter := spot + Vector3(3.0, 0.0, 0.0)
	var roof := slab(shelter + Vector3.UP * 3.0, Vector3(4.0, 0.5, 4.0))
	put(shelter)
	await frames(2)
	check("under a roof (a bridge, a platform) is out of its reach", not ptero.exposed(runner))
	var narrow := spot + Vector3(0.0, 0.0, -4.0)
	var wall_a := slab(narrow + Vector3(2.2, 3.0, 0.0), Vector3(0.6, 6.0, 12.0))
	var wall_b := slab(narrow + Vector3(-2.2, 3.0, 0.0), Vector3(0.6, 6.0, 12.0))
	put(narrow)
	await frames(2)
	check("in a narrow passage (4 m across) is out of its reach", not ptero.exposed(runner))
	wall_a.queue_free()
	wall_b.queue_free()
	put(Vector3(0, 0.05, 0))
	await frames(2)
	check("in the clearing nobody is hunted", not ptero.exposed(runner))
	# In the open: out in a wide hall, and up on a wall top.
	var top_spot: Vector3 = ptero.roost - Vector3.UP * Pterodactyl.STAND_HEIGHT * MazePterodactyl.SIZE + Vector3.UP * 0.05 - ptero.roost_facing * 3.0
	put(top_spot)
	await frames(2)
	check("up on a wall top is in the open", ptero.exposed(runner), "(%.1f m up)" % top_spot.y)
	put(spot)
	await frames(2)
	check("out in a wide hall is in the open", ptero.exposed(runner))

	# Seen: the croak and the launch; over them, croaking; round; the dive.
	var calls_before: int = ptero._calls
	var launched := await until(3.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.LAUNCH)
	check("it sees them, croaks and launches", launched and ptero.look.croaking())
	var over := await until(Pterodactyl.LAUNCH_TIME + 2.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.PASS)
	check("it comes over them", over)
	var nearest_over := [INF]
	var round_again := await until(14.0, func() -> bool:
		nearest_over[0] = minf(nearest_over[0], Vector2(ptero.global_position.x - spot.x, ptero.global_position.z - spot.z).length())
		return ptero.mode == MazePterodactyl.Mode.WHEEL)
	check("it passes over them (its shadow on them) croaking, and wheels round", round_again and ptero._calls >= calls_before + 2 and nearest_over[0] < 5.0, "(came within %.1f m of overhead; %d croaks)" % [nearest_over[0], ptero._calls - calls_before])
	var dived := await until(18.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.DIVE)
	check("it dives at them", dived, "(mode %s)" % MazePterodactyl.Mode.keys()[ptero.mode])
	var inside_walls := [0]
	var start_caught := caught
	var snatched_at := [-1]
	var carried_up := [0.0]
	var frame := [0]
	await until(8.0, func() -> bool:
		frame[0] += 1
		if not ptero.maze_free(ptero.global_position):
			inside_walls[0] += 1
		if ptero.mode == MazePterodactyl.Mode.CARRY:
			if snatched_at[0] < 0:
				snatched_at[0] = frame[0]
				carried_up[0] = ptero.global_position.y
		return ptero.mode == MazePterodactyl.Mode.CLIMB or caught > start_caught)
	check("standing still, they are snatched", ptero.snatched and snatched_at[0] > 0, "(its feet came within %.2f m, %s from their feet)" % [ptero.closest, ptero.closest_at])
	check("and carried off before they are caught", caught == start_caught + 1 and frame[0] - snatched_at[0] >= int(MazePterodactyl.CARRY_TIME * 60.0) - 2 and ptero.global_position.y > carried_up[0] + 3.0, "(%d frames carried, rose %.1f m)" % [frame[0] - snatched_at[0], ptero.global_position.y - carried_up[0]])
	check("it never goes through stone", inside_walls[0] == 0, "(%d frames inside)" % inside_walls[0])
	check("caught once, only by its feet", caught == start_caught + 1)
	check("and it lets them be a while after", ptero._let_be.has(runner))
	ptero.process_mode = Node.PROCESS_MODE_DISABLED
	ptero.visible = false
	await frames(int(ptero.spare_time * 60.0) + 10)

	# Others: the duck (no help), the sidestep (a miss), getting under cover in time (it breaks off).
	var results := {}
	for test: String in ["duck", "sidestep", "cover"]:
		var other := make(home, 7 + results.size())
		other._roost_left = 9999.0
		await frames(3)
		put(spot)
		runner.set(&"is_ducking", false)
		var went := await until(30.0, func() -> bool: return other.mode == MazePterodactyl.Mode.DIVE)
		if not went:
			results[test] = "never dived (mode %s)" % MazePterodactyl.Mode.keys()[other.mode]
			other.queue_free()
			continue
		var before := caught
		var did := [false]
		await until(8.0, func() -> bool:
			if not did[0] and test == "cover":
				did[0] = true
				put(shelter)
			elif not did[0] and other._locked:
				did[0] = true
				if test == "duck":
					runner.set(&"is_ducking", true)
				else:
					var across: Vector3 = other.dive_way.cross(Vector3.UP).normalized()
					put(runner.global_position + across * 1.8)
			return other.mode in [MazePterodactyl.Mode.CLIMB, MazePterodactyl.Mode.SOAR] or caught > before)
		results[test] = "caught" if other.snatched else "missed"
		print("      (%s: its feet came within %.2f m, %s from their feet; %s)" % [test, other.closest, other.closest_at, results[test]])
		runner.set(&"is_ducking", false)
		await until(3.0, func() -> bool: return caught > before or other.mode != MazePterodactyl.Mode.CARRY)
		other.queue_free()
		put(Vector3(0, 0.05, 0))
		await frames(int(4.0 * 60.0))
	check("ducking does not save them (its feet come down on them)", results.get("duck", "") == "caught", "(%s)" % results.get("duck", "?"))
	check("stepping aside once its line is set, its feet close on air", results.get("sidestep", "") == "missed", "(%s)" % results.get("sidestep", "?"))
	check("getting under cover before its line is set, it breaks off", results.get("cover", "") == "missed", "(%s)" % results.get("cover", "?"))

	# Kept under cover, it gives up, lets them be and soars on; then it comes down to roost again.
	ptero.process_mode = Node.PROCESS_MODE_INHERIT
	ptero.visible = true
	ptero._let_be.clear()
	ptero._spared.clear()
	put(spot)
	await until(30.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.PASS or ptero.mode == MazePterodactyl.Mode.WHEEL)
	put(shelter)
	var gave_up := await until(ptero.lose_time + 6.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.SOAR)
	check("kept under cover, it gives up and soars on", gave_up and ptero._let_be.has(runner))
	var top: float = maze.maze_wall_height(maze.ring_of(maze.cell_at(spot)))
	await frames(120)
	check("it soars high over the walls", ptero.global_position.y > top + 8.0, "(at %.1f m, the walls %.1f m)" % [ptero.global_position.y, top])
	put(Vector3(0, 0.05, 0))
	ptero._soar_left = 0.0
	var roosted := await until(40.0, func() -> bool: return ptero.mode == MazePterodactyl.Mode.ROOST)
	check("it comes down to roost again, on all fours", roosted and ptero.global_position.distance_to(ptero.roost) < 0.1 and ptero.look.grounded)

	# A puppet follows the host's news.
	var copy := MazePterodactyl.new()
	copy.name = "PterodactylCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(99)
	copy.position = ptero.position
	stage.add_child(copy)
	await frames(3)
	ptero._let_be.clear()
	ptero._roost_left = 0.0
	put(spot)
	var behind := 0.0
	var agreed := 0
	var looked := 0
	for i in 60 * 12:
		if i % 6 == 0:
			copy.from_bytes(ptero.state_bytes())
		await physics_frame
		if i > 30:
			looked += 1
			behind = maxf(behind, copy.global_position.distance_to(ptero.global_position))
			if copy.mode == ptero.mode:
				agreed += 1
	check("a puppet follows", behind < 5.0 and agreed > looked * 0.85, "(at worst %.2f m behind; same mode %d of %d frames)" % [behind, agreed, looked])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, ptero.state_bytes().size() == MazeEnemy.STATE_SIZE)
	copy.queue_free()

	# Two never dive at one person at once.
	var pair: Array[MazePterodactyl] = [make(home, 41), make(home, 42)]
	for p in pair:
		p._roost_left = 9999.0
	ptero.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(3)
	put(spot)
	var both := [false]
	var one := [false]
	await until(20.0, func() -> bool:
		var hunting := 0
		for p in pair:
			if p.mode in [MazePterodactyl.Mode.PASS, MazePterodactyl.Mode.WHEEL, MazePterodactyl.Mode.DIVE]:
				hunting += 1
		if hunting == 2:
			both[0] = true
		if hunting == 1:
			one[0] = true
		return pair[0].mode == MazePterodactyl.Mode.DIVE or pair[1].mode == MazePterodactyl.Mode.DIVE)
	check("of two that see someone, only one goes for them", one[0] and not both[0], "(one hunted: %s, both: %s; modes %s %s)" % [one[0], both[0], MazePterodactyl.Mode.keys()[pair[0].mode], MazePterodactyl.Mode.keys()[pair[1].mode]])
	for p in pair:
		p.queue_free()
	put(Vector3(0, 0.05, 0))

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(MazePterodactyl.new(), lairs[0], 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(MazePterodactyl.new(), lairs[0], 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks a pterodactyl", b.puppet and (b as MazePterodactyl).mode == (a as MazePterodactyl).mode and b.global_position.distance_to(a.global_position) < 0.5)
	var meshes := ptero.look.find_children("*", "MeshInstance3D", true, false)
	var drawn := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh is ArrayMesh and (mesh.mesh as ArrayMesh).get_surface_count() > 0 and mesh.skin != null:
			drawn += 1
	check("it is one skinned mesh at a time (a full one near, a low one far)", drawn == 2, "(%d skinned meshes)" % drawn)
	roof.queue_free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
