extends SceneTree
## The pond frogs (scripts/enemies/maze_pond_frogs.gd on creatures/pond_frog),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In
## turn: a pond of them sings until he comes near, hushes as he does, and they
## leap into the water as he comes close, and come out again when he has gone;
## all in the water, there is nothing for the world's hunters to catch; caught
## (Ecology.kill), one is gone and comes back when the colony does, and a
## puppet's goes as its host's does; the clearing's marsh has colonies along
## its pools, each frog on the bank by the water.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/pond_frogs_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Node3D
var failures := 0


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
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func colony_at(at: Vector3, puppet := false) -> MazePondFrogs:
	var frogs := MazePondFrogs.new()
	frogs.maze = maze
	frogs.puppet = puppet
	frogs.position = at + Vector3.UP * 0.05
	stage.add_child(frogs)
	return frogs


func singing(colony: PondFrogs) -> int:
	var n := 0
	for i in colony.count:
		if colony.frog_state(i) == PondFrogs.SIT and colony._hushed[i] <= 0.0:
			n += 1
	return n


func _run() -> void:
	await frames(10)
	var cell: Vector2i = nav.lairs(3)[0]
	var middle := nav.point(cell)
	boy.global_position = middle + Vector3(60.0, 40.0, 0.0)
	var frogs := colony_at(middle)
	await frames(30)
	var colony := frogs.colony
	check("a colony sits round its pond", colony != null and colony.is_inside_tree() and colony.out() == colony.count, "(%d of %d out)" % [colony.out() if colony else 0, colony.count if colony else 0])
	check("and sings, with nobody near", singing(colony) == colony.count)

	# He walks up to it.
	var from := middle + Vector3(14.0, 0.0, 0.0)
	boy.global_position = from + Vector3.UP * 0.1
	var hushed_at := INF
	var dived_at := INF
	for i in 600:
		var to := middle - boy.global_position
		to.y = 0.0
		if to.length() > 0.5:
			boy.global_position += to.normalized() * 1.4 / 60.0
			boy.velocity = to.normalized() * 1.4
		await physics_frame
		var gap := Vector2(to.x, to.z).length()
		if hushed_at == INF and singing(colony) < colony.count:
			hushed_at = gap
		if dived_at == INF and colony.out() < colony.count:
			dived_at = gap
	boy.velocity = Vector3.ZERO
	check("they hush as he comes near", hushed_at < colony.hush_range + colony.pool_radius + 1.5 and hushed_at > colony.dive_range, "(at %.1f m)" % hushed_at)
	check("and leap in as he comes close", dived_at <= colony.dive_range + colony.pool_radius + 1.0, "(at %.1f m)" % dived_at)
	check("all of them, one after another", colony.out() == 0, "(%d still out)" % colony.out())
	await frames(20)
	check("all in the water, there is nothing to catch", frogs.escaped)
	# He goes away: they come up, and out.
	boy.global_position = middle + Vector3(60.0, 40.0, 0.0)
	var back := await wait(40.0, func() -> bool: return colony.out() == colony.count)
	check("when he has gone they climb back out", back, "(%d out)" % colony.out())
	await frames(20)
	check("and are there to be caught again", not frogs.escaped)

	# Caught by the world: one is gone, the rest go in; back with the colony.
	if Ecology.KINDS.has("MazePondFrogs"):
		var world := Ecology.put(stage, 3)
		var copy := colony_at(middle, true)
		await frames(10)
		var dog := MazeDog.new()
		dog.maze = maze
		dog.position = middle + Vector3(30.0, 0.05, 0.0)
		stage.add_child(dog)
		await frames(5)
		world.kill(frogs, dog)
		for i in 10:
			copy.from_bytes(frogs.state_bytes())
			await physics_frame
		await frames(30)
		var gone := func(of: MazePondFrogs) -> int:
			var n := 0
			for i in of.colony.count:
				if of.colony.frog_state(i) == PondFrogs.GONE:
					n += 1
			return n
		check("caught, one frog is eaten", frogs.dead and gone.call(frogs) == 1, "(%d gone)" % gone.call(frogs))
		check("and the rest go in", colony.out() == 0, "(%d out)" % colony.out())
		check("a puppet's goes as its host's does", copy.dead and gone.call(copy) == 1)
		frogs.revive(middle, 0.0)
		await frames(10)
		check("back again, it is whole", gone.call(frogs) == 0 and not frogs.dead)
		dog.queue_free()
		copy.queue_free()
		world.queue_free()
	else:
		print("SKIP: caught by the world (Ecology.KINDS has no MazePondFrogs yet)")

	# The marsh's colonies.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var found := MazePondFrogs.marsh_colonies(maze, 4, rng)
	var good := not found.is_empty()
	var style := maze.clearing_style
	for one: Array in found:
		for bank: Array in one[1]:
			var sit: Vector3 = bank[0]
			var water: Vector3 = bank[1]
			if style.marsh_depth_at(Vector2(sit.x, sit.z), maze.maze_seed) > 0.0 or style.marsh_depth_at(Vector2(water.x, water.z), maze.maze_seed) < 0.1:
				good = false
	check("the marsh has colonies, each frog on the bank by deep enough water", good, "(%d colonies)" % found.size())

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
