extends SceneTree
## The frog swarms (scripts/enemies/maze_frog_swarm.gd on creatures/frog),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In
## turn: quiet, a few frogs sit about their pool; the boy comes near and they
## pour out at him; standing still, they climb onto him, weigh him down (he is
## slowed) and catch him, then go home and he has his speed back; up on
## something high, they cannot reach him and give up; running away, he
## outruns them; a puppet follows the host's news, and catches nobody.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/frog_swarm_test.gd
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


func swarm_at(at: Vector3) -> MazeFrogSwarm:
	var swarm := MazeFrogSwarm.new()
	swarm.maze = maze
	swarm.position = at + Vector3.UP * 0.05
	stage.add_child(swarm)
	swarm.caught.connect(func(player: Node3D) -> void: caught_by.append([player, swarm]))
	return swarm


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


## Walks the boy straight towards `to` at `speed` (m/s) for `seconds`.
func walk_boy(to: Vector3, speed: float, seconds: float) -> void:
	for i in int(seconds * 60.0):
		var step := get_root().get_physics_process_delta_time()
		var way: Vector3 = to - boy.global_position
		way.y = 0.0
		if way.length() < 0.2:
			boy.velocity = Vector3.ZERO
			await physics_frame
			continue
		var move: Vector3 = way.normalized() * minf(speed * step, way.length())
		boy.global_position += move
		boy.velocity = Vector3(move.x, 0.0, move.z) / step
		await physics_frame
	boy.velocity = Vector3.ZERO


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	# A long way down the passages from the pool, for him to come from and run to.
	var route: Array = []
	for cell: Vector2i in lairs:
		if nav.distance(home, cell) >= 6:
			route = nav.path(home, cell)
			break
	check("a way for him to go", route.size() >= 6, "(%d cells)" % route.size())
	var pool: Vector3 = maze.world(home)

	# --- Quiet: frogs sit about the pool ---
	put_boy(maze.world(route[route.size() - 1]))
	var swarm := swarm_at(pool)
	await frames(30)
	check("quiet, a few sit about the pool", swarm.mode == MazeFrogSwarm.Mode.DORMANT and swarm.swarm.out == swarm.swarm.lurkers, "(%d out)" % swarm.swarm.out)

	# --- He comes near: they pour out ---
	put_boy(maze.world(route[1]))
	var poured := await wait(4.0, func() -> bool: return swarm.swarm.out > 40)
	check("he comes near: they pour out at him", poured and swarm.mode == MazeFrogSwarm.Mode.HUNT, "(%d out)" % swarm.swarm.out)
	var run_speed: float = boy.run_speed
	var slowed := [1.0]
	var got := await wait(15.0, func() -> bool:
		slowed[0] = minf(slowed[0], boy.run_speed / run_speed)
		return not caught_by.is_empty())
	check("standing still, they climb onto him and catch him", got and caught_by[0][0] == boy)
	check("they weigh him down as they climb on", slowed[0] < 0.8, "(down to %.0f%% of his speed)" % (slowed[0] * 100.0))
	var gone_home := await wait(15.0, func() -> bool: return swarm.mode == MazeFrogSwarm.Mode.DORMANT)
	check("then they hop home", gone_home)
	check("and he has his speed back", is_equal_approx(boy.run_speed, run_speed) and not boy.has_meta(&"frog_speeds"), "(%.2f)" % boy.run_speed)
	await clear()

	# --- Up on something high: out of reach, they give up ---
	put_boy(maze.world(route[1]))
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.4, 2.0)
	shape.shape = box
	block.add_child(shape)
	stage.add_child(block)
	block.global_position = maze.world(route[1]) + Vector3.UP * 1.2
	put_boy(maze.world(route[1]) + Vector3.UP * 2.4)
	swarm = swarm_at(pool)
	var out := await wait(5.0, func() -> bool: return swarm.mode == MazeFrogSwarm.Mode.HUNT)
	check("they come for him on his block", out)
	var gave_up := await wait(20.0, func() -> bool: return swarm.mode != MazeFrogSwarm.Mode.HUNT)
	check("they cannot reach him up there, and give up", gave_up and caught_by.is_empty(), "(caught %d)" % caught_by.size())
	block.queue_free()
	await clear()

	# --- Running away, he outruns them ---
	put_boy(maze.world(route[1]))
	swarm = swarm_at(pool)
	out = await wait(5.0, func() -> bool: return swarm.mode == MazeFrogSwarm.Mode.HUNT)
	check("they come out again", out)
	var most := 0
	var path_away: Array = route.slice(1, 8)
	for cell: Vector2i in path_away:
		await walk_boy(maze.world(cell), 4.6, Maze.CELL / 4.6)
		most = maxi(most, swarm.swarm.on_target)
	check("running away, he outruns them", caught_by.is_empty() and most < 4, "(at most %d on him)" % most)
	await clear()

	# --- A puppet follows the host, and catches nobody ---
	put_boy(maze.world(route[1]))
	var host := swarm_at(pool)
	var copy := MazeFrogSwarm.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	var copied := false
	for i in 500:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if copy.swarm.chasing and copy.swarm.out > 20:
			copied = true
	check("the puppet's frogs come out when the host's do", copied)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
