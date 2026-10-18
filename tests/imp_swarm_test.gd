extends SceneTree
## The imp swarm (scripts/enemies/maze_imp_swarm.gd, creatures/imp_swarm/),
## headless, in a bare scene: a maze from MazeBuilder and the boy standing in
## it. A crack at the foot of a wall; woken by him coming near; pouring out
## after him, some up the walls; on him, holding him back, and bringing him
## down; a roll throwing them all off; getting up out of reach (they give up
## and go home); a puppet swarm following the host's; and what a frame costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/imp_swarm_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
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
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


func spawn(one: MazeEnemy, cell: Vector2i) -> MazeEnemy:
	one.maze = maze
	one.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught_by.clear()


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	put_boy(maze.world(lairs[0]))

	# --- The crack, at the foot of a wall; asleep with nobody near ---
	var cell := cell_from(home, 2)
	var host := spawn(MazeImpSwarm.new(), cell) as MazeImpSwarm
	await frames(4)
	check("its crack is at the foot of a wall", host.nested() and host.against_wall)
	await wait(1.0)
	check("asleep with nobody near", host.mode == MazeImpSwarm.Mode.ASLEEP and host.swarm.out == 0)

	# --- He comes near: a warning, then they pour out after him ---
	var spot: Vector3 = host._nest + host.out_of_wall * 7.0
	var by_wall: Vector3 = host._nest + Vector3.UP.cross(host.out_of_wall) * 10.0 + host.out_of_wall * 0.6
	put_boy(by_wall)
	var woke := await wait(4.0, func() -> bool: return host.mode != MazeImpSwarm.Mode.ASLEEP)
	check("he comes near and wakes them", woke, "(%.1f m off)" % boy.global_position.distance_to(host._nest))
	check("they chitter in the crack first", host.mode == MazeImpSwarm.Mode.WARN and host.swarm.out == 0)
	var poured := await wait(3.0, func() -> bool: return host.swarm.out > 20)
	check("then pour out", poured, "(%d out)" % host.swarm.out)
	var on_wall := 0
	var reached := false
	var slowest := INF
	for i in 600:
		await physics_frame
		for k in host.swarm.count:
			if host.swarm.imp_state(k) == ImpSwarm.WALL:
				on_wall += 1
				break
		if host.swarm.on_him > 0 and not reached:
			reached = true
			boy.velocity = Vector3(5.6, 0.0, 0.0)
			host._hold_back_local()
			slowest = Vector2(boy.velocity.x, boy.velocity.z).length()
		if not caught_by.is_empty():
			break
	check("some run up the walls", on_wall > 0, "(%d frames with one on a wall)" % on_wall)
	check("they reach him and run up him", reached)
	check("and hold him back", slowest < 5.5, "(%.2f m/s)" % slowest)
	check("enough of them on him bring him down", not caught_by.is_empty() and caught_by[0][0] == boy)
	await frames(2)
	check("then they let go and go home", host.swarm.on_him == 0 and host.mode == MazeImpSwarm.Mode.HOME, "(%s)" % MazeImpSwarm.Mode.keys()[host.mode])
	var asleep := await wait(15.0, func() -> bool: return host.mode == MazeImpSwarm.Mode.ASLEEP and host.swarm.out == 0)
	check("and back down the crack", asleep)
	clear()

	# --- A roll throws them all off ---
	put_boy(spot)
	var second := spawn(MazeImpSwarm.new(), cell) as MazeImpSwarm
	await frames(4)
	second.swarm.catch_count = 1000
	second.wake_on(boy)
	var on := await wait(10.0, func() -> bool: return second.swarm.on_him >= 3)
	check("they get on him again", on, "(%d on him)" % second.swarm.on_him)
	boy.is_diving = true
	second._shake(boy)
	boy.is_diving = false
	var off := 0
	for k in second.swarm.count:
		if second.swarm.imp_state(k) == ImpSwarm.ON_HIM:
			off += 1
	check("a roll throws them all off", off == 0, "(%d left on)" % off)

	# --- Up out of their reach: they give up and go home ---
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 6.0, 3.0)
	shape.shape = box
	block.add_child(shape)
	stage.add_child(block)
	block.global_position = boy.global_position + Vector3.UP * 3.0
	second.swarm.shake_off()
	put_boy(boy.global_position + Vector3.UP * 6.2)
	var gave_up := await wait(20.0, func() -> bool: return second.mode == MazeImpSwarm.Mode.HOME or second.mode == MazeImpSwarm.Mode.ASLEEP)
	check("up on something, they give up and go home", gave_up, "(%s, %d on him, %d out, stuck %.1f, gap %.1f, best %.1f, boy y %.1f)" % [MazeImpSwarm.Mode.keys()[second.mode], second.swarm.on_him, second.swarm.out, second.swarm._stuck_for, second.swarm._gap, second.swarm._best_seen, boy.global_position.y])
	block.free()
	clear()

	# --- A puppet swarm follows the host's ---
	put_boy(maze.world(lairs[0]))
	await frames(3)
	var leader := spawn(MazeImpSwarm.new(), cell) as MazeImpSwarm
	var copy := MazeImpSwarm.new()
	copy.puppet = true
	spawn(copy, cell)
	await frames(4)
	put_boy(spot)
	var copy_out := false
	for i in 300:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(leader.state_bytes())
		if copy.swarm.out > 10:
			copy_out = true
	check("a puppet's imps come out when the host's do", copy_out == (leader.swarm.out > 0), "(host %d out, puppet %d)" % [leader.swarm.out, copy.swarm.out])
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	# What a frame of a whole swarm out costs.
	var spent := 0
	var counted := 0
	for i in 60:
		var start := Time.get_ticks_usec()
		leader.swarm._physics_process(1.0 / 60.0)
		spent += Time.get_ticks_usec() - start
		counted += 1
		await physics_frame
	print("a frame of %d imps (%d out): %.2f ms" % [leader.swarm.count, leader.swarm.out, spent / 1000.0 / counted])
	clear()

	# --- The component's example runs on its own ---
	var example: Node3D = load("res://creatures/imp_swarm/example.gd").new()
	stage.add_child(example)
	var ran := await wait(4.0, func() -> bool: return example.swarm.out > 10)
	check("the example lets them out", ran, "(%d out)" % example.swarm.out)
	check("the swarm's mesh is light", ImpSwarm.mesh().surface_get_array_len(0) < 2500, "(%d vertices)" % ImpSwarm.mesh().surface_get_array_len(0))
	example.free()

	print("IMP SWARM TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)
