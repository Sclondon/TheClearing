extends SceneTree
## The dimetrodon (scripts/enemies/maze_dimetrodon.gd on creatures/dimetrodon),
## headless, in a bare scene: a maze from MazeBuilder, a sun, and the boy. In
## turn: alone it basks, side on to the sun; someone far off it does not
## notice; the boy near in front: it rises and hisses (a warning), then lunges
## and catches him; backing off while it rises, he is missed; it chases slower
## than a run and gives up; cold, it notices less far, rises slower and
## chases slower; out in the desert it ambushes too; a puppet follows the host
## and lunges when it does; its sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/dimetrodon_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var sun: DirectionalLight3D
var failures := 0
var caught_by: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


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
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	stage.add_child(sun)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	if boy.is_limp:
		boy.recover()
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func dim_at(at: Vector3, yaw := 0.0, one: MazeDimetrodon = null) -> MazeDimetrodon:
	var dim := one if one else MazeDimetrodon.new()
	dim.maze = maze
	dim.position = at + Vector3.UP * 0.05
	dim.rotation.y = yaw
	stage.add_child(dim)
	dim.caught.connect(func(player: Node3D) -> void: caught_by.append([player, dim]))
	return dim


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


func mode_name(dim: MazeDimetrodon) -> String:
	return MazeDimetrodon.Mode.keys()[dim.mode]


func _run() -> void:
	await frames(10)
	# A long straight wide hall to put it in.
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var ok := true
			for k in [-1, 1, 2]:
				if not maze.inside(cell + s * k) or maze.in_clearing(cell + s * k):
					ok = false
			if ok and not maze.blocked(cell, s) and not maze.blocked(cell, -s) and not maze.blocked(cell + s, s):
				hall = cell
				step = s
				break
		if hall.x >= 0:
			break
	check("a straight hall to put it in", hall.x >= 0)
	var way := Vector3(step.x, 0.0, step.y)
	var middle: Vector3 = maze.world(hall)
	middle.y = maze.ground_height(middle)
	var yaw := atan2(way.x, way.z)
	var far_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 8:
			far_cell = cell
			break

	# --- Alone, it basks side on to the sun ---
	put_boy(maze.world(far_cell))
	var dim := dim_at(middle, yaw)
	dim.warmth_override = 1.0
	await wait(25.0)
	var towards := sun.global_basis.z
	var across := absf(angle_difference(dim.facing_yaw, atan2(towards.x, towards.z)))
	check("alone, it basks", dim.mode == MazeDimetrodon.Mode.BASK and dim.dim.basking, "(%s)" % mode_name(dim))
	check("side on to the sun, its sail to the light", absf(across - PI * 0.5) < 0.3, "(%.0f deg from the sun's way)" % rad_to_deg(across))

	# --- Someone far off: not noticed ---
	put_boy(dim.global_position + way * 11.0)
	var noticed := await wait(2.0, func() -> bool: return dim.mode != MazeDimetrodon.Mode.BASK)
	check("someone 11 m off it does not notice", not noticed, "(%s)" % mode_name(dim))
	await clear()

	# --- Near in front: it rises and hisses, then lunges and catches ---
	dim = dim_at(middle, yaw)
	dim.warmth_override = 1.0
	await frames(30)
	var hisses := [0]
	var snaps := [0]
	dim.dim.hissed.connect(func() -> void: hisses[0] += 1)
	dim.dim.snapped.connect(func() -> void: snaps[0] += 1)
	put_boy(dim.global_position + dim.global_basis_forward() * 3.0)
	var rose := await wait(1.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.RISE)
	check("the boy 3 m in front: it rises, gaping, and hisses (a warning)", rose and hisses[0] == 1 and dim.dim.threatening, "(%s)" % mode_name(dim))
	var started := Time.get_ticks_msec()
	var lunged := await wait(2.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.LUNGE)
	var rise_warm := (Time.get_ticks_msec() - started) / 1000.0
	check("then it lunges", lunged)
	var hit := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("and its jaws catch him", hit and caught_by[0][0] == boy and snaps[0] >= 1, "(%d caught)" % caught_by.size())
	await clear()

	# --- Backing off while it rises: missed ---
	dim = dim_at(middle, yaw)
	dim.warmth_override = 1.0
	await frames(30)
	put_boy(dim.global_position + dim.global_basis_forward() * 3.0)
	rose = await wait(1.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.RISE)
	put_boy(dim.global_position + dim.global_basis_forward() * 9.0)
	await wait(2.5)
	check("he backs off while it rises: nothing catches him", rose and caught_by.is_empty(), "(%s)" % mode_name(dim))
	await clear()
	# --- It chases slower than a run, and gives up ---
	put_boy(maze.world(far_cell))
	dim = dim_at(middle, yaw)
	dim.warmth_override = 1.0
	await frames(30)
	var fastest := 0.0
	var gave_up := false
	var runner := CharacterBody3D.new()
	stage.add_child(runner)
	runner.global_position = dim.global_position + dim.global_basis_forward() * 4.0
	dim.targets = [runner]
	await wait(1.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.RISE)
	for i in 12 * 60:
		await physics_frame
		fastest = maxf(fastest, Vector2(dim.velocity.x, dim.velocity.z).length() if dim.mode == MazeDimetrodon.Mode.CHASE else 0.0)
		# (the runner keeps ahead of it at a run, down the hall)
		var off: Vector3 = runner.global_position - dim.global_position
		off.y = 0.0
		if off.length() < 9.0:
			runner.global_position = dim.global_position + off.normalized() * 9.0
		if dim.mode == MazeDimetrodon.Mode.RETURN or dim.mode == MazeDimetrodon.Mode.BASK:
			gave_up = true
			break
	check("it chases slower than a run (4.4 m/s)", fastest > 0.5 and fastest < 3.3, "(%.1f m/s)" % fastest)
	check("and soon gives up", gave_up, "(%s)" % mode_name(dim))
	runner.queue_free()
	await clear()

	# --- Cold: notices less far, rises slower ---
	put_boy(maze.world(far_cell))
	dim = dim_at(middle, yaw)
	dim.warmth_override = 0.05
	await frames(30)
	put_boy(dim.global_position + dim.global_basis_forward() * 5.5)
	noticed = await wait(1.5, func() -> bool: return dim.mode != MazeDimetrodon.Mode.BASK)
	check("cold, it does not notice him 5.5 m off", not noticed, "(%s, warmth %.2f)" % [mode_name(dim), dim.warmth])
	put_boy(dim.global_position + dim.global_basis_forward() * 2.8)
	rose = await wait(1.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.RISE)
	started = Time.get_ticks_msec()
	lunged = await wait(3.0, func() -> bool: return dim.mode == MazeDimetrodon.Mode.LUNGE)
	var rise_cold := (Time.get_ticks_msec() - started) / 1000.0
	check("cold, it rises slower before it lunges", rose and lunged and rise_cold > rise_warm + 0.3, "(%.2f s cold, %.2f s warm)" % [rise_cold, rise_warm])
	await clear()

	# --- Out in the desert ---
	var open_maze := Maze.generate(Maze.seed_for("TEST", 1), 7)
	var desert_at := MazeBrachiosaurus.spots(open_maze, 1, 3)[0]
	dim = MazeDimetrodon.new()
	dim.maze = open_maze
	dim.position = desert_at
	dim.warmth_override = 1.0
	stage.add_child(dim)
	dim.caught.connect(func(player: Node3D) -> void: caught_by.append([player, dim]))
	await frames(10)
	var stand_in := Node3D.new()
	stage.add_child(stand_in)
	stand_in.global_position = dim.global_position + dim.global_basis_forward() * 2.6
	dim.targets = [stand_in]
	var desert_hit := await wait(4.0, func() -> bool: return not caught_by.is_empty())
	check("out in the desert, it ambushes too", desert_hit, "(%s)" % mode_name(dim))
	stand_in.queue_free()
	await clear()

	# --- A puppet follows the host and lunges when it does ---
	put_boy(maze.world(far_cell))
	var host := dim_at(middle, yaw)
	host.warmth_override = 1.0
	var copy := MazeDimetrodon.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	copy.caught.connect(func(player: Node3D) -> void: caught_by.append([player, copy]))
	var copied := [0]
	copy.dim.snapped.connect(func() -> void: copied[0] += 1)
	var off_most := 0.0
	for i in 360:
		await physics_frame
		if i == 30:
			put_boy(host.global_position + host.global_basis_forward() * 3.0)
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			off_most = maxf(off_most, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", off_most < 1.5, "(at most %.2f m off)" % off_most)
	check("the puppet lunges when the host does", copied[0] >= 1, "(%d)" % copied[0])
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	check("its sounds are made", Dimetrodon.hiss_sound().data.size() > 1000 and Dimetrodon.snap_sound().data.size() > 500 and Dimetrodon.grunt_sound().data.size() > 500)
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
