extends SceneTree
## The feral dogs (scripts/enemies/maze_dog.gd on creatures/dog), headless, in
## a bare scene: a maze from MazeBuilder and the boy in it. In turn: the boy's
## trail is laid as he goes; a dog that can neither see nor hear finds the
## trail and follows it to him; one that sees him bays, comes, and bites; a
## lunge he steps out of misses, and the dog shakes itself; where the trail
## breaks it casts about and gives up; a puppet follows what the host sends,
## lunges with it; and a pack of four from `pack_of`.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/dog_test.gd
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


## A passage cell `steps` from `from` by the passages.
func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


## Walks the boy along the passages from where he is to `to`, at `speed`.
func walk_boy(to: Vector2i, speed: float) -> void:
	var path: Array = nav.path(maze.cell_at(boy.global_position), to)
	for cell: Vector2i in path:
		var goal: Vector3 = maze.world(cell)
		while Vector2(goal.x - boy.global_position.x, goal.z - boy.global_position.z).length() > 0.3:
			var step := get_root().get_physics_process_delta_time()
			var to_goal: Vector3 = goal - boy.global_position
			to_goal.y = 0.0
			var move: Vector3 = to_goal.normalized() * minf(speed * step, to_goal.length())
			boy.global_position += move
			boy.velocity = Vector3(move.x, 0.0, move.z) / step
			await physics_frame
	boy.velocity = Vector3.ZERO


func dog_at(cell: Vector2i, yaw := 0.0) -> MazeDog:
	var dog := MazeDog.new()
	dog.maze = maze
	dog.position = maze.world(cell) + Vector3.UP * 0.05
	dog.rotation.y = yaw
	stage.add_child(dog)
	dog.caught.connect(func(player: Node3D) -> void: caught_by.append([player, dog]))
	return dog


func clear_dogs() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	MazeDog.trails.clear()
	await frames(2)


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	put_boy(maze.world(home))
	await frames(20)

	# --- The trail, and a dog following it by scent alone ---
	# A long way from the boy's cell: the dog is put on it, partway along.
	var far_end: Vector2i = home
	for cell: Vector2i in lairs:
		if nav.distance(home, cell) >= 12:
			far_end = cell
			break
	var route: Array = nav.path(home, far_end)
	check("a long way for the boy to go", route.size() >= 12, "(%d cells)" % route.size())
	var dog_cell: Vector2i = route[4]
	var beyond: Vector2i = route[10]
	var dog := dog_at(dog_cell)
	# (it can neither see nor hear: only its nose)
	dog.sight_range = 0.0
	dog.hear_range = 0.0
	# (and it waits where it is while he goes by: held still, so that it is not off wandering)
	dog.roam_speed = 0.0
	dog._rest_left = 999.0
	await frames(5)
	# The boy walks past where the dog is and on, six cells beyond it, and stands.
	await walk_boy(beyond, 3.0)
	dog.roam_speed = 1.5
	dog._rest_left = 0.0
	var trail: PackedVector4Array = MazeDog.trails.get(boy, PackedVector4Array())
	check("the boy's trail is laid as he goes", trail.size() > 20, "(%d crumbs)" % trail.size())
	var tracked := await wait(20.0, func() -> bool: return dog.mode == MazeDog.Mode.TRACK)
	check("the dog picks up his trail", tracked, "(mode %s)" % MazeDog.Mode.keys()[dog.mode])

	var start_gap: float = dog.global_position.distance_to(boy.global_position)
	var near := await wait(40.0, func() -> bool: return dog.global_position.distance_to(boy.global_position) < 5.0)
	check("it follows the trail to him, out of sight", near, "(from %.1f m to %.1f m)" % [start_gap, dog.global_position.distance_to(boy.global_position)])
	await process_frame
	check("nose down on it, near enough to be seen", dog.dog.tracking)
	await clear_dogs()

	# --- One that sees him: it bays, comes on, and bites ---
	put_boy(maze.world(home))
	await frames(10)
	var straight := Vector2i(-1, -1)
	for step: Vector2i in Maze.STEPS:
		var at: Vector2i = home
		var run := 0
		while run < 3 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
			at += step
			run += 1
		if run == 3:
			straight = at
			break
	check("a straight passage from the boy", straight.x >= 0)
	var to_boy: Vector3 = maze.world(home) - maze.world(straight)
	dog = dog_at(straight, atan2(to_boy.x, to_boy.z))
	var bayed := await wait(3.0, func() -> bool: return dog.mode == MazeDog.Mode.BAY)
	check("it sees him and bays", bayed)
	check("the howl is shown", dog.dog.howling())
	var lunged := await wait(15.0, func() -> bool: return dog.mode == MazeDog.Mode.LUNGE)
	check("it closes and springs", lunged)
	var bitten := await wait(2.0, func() -> bool: return not caught_by.is_empty())
	check("its jaws catch him (he stood still)", bitten and caught_by[0][0] == boy)
	await clear_dogs()

	# --- A lunge he steps out of misses; it shakes itself ---
	put_boy(maze.world(home))
	await frames(70)
	dog = dog_at(straight, atan2(to_boy.x, to_boy.z))
	lunged = await wait(15.0, func() -> bool: return dog.mode == MazeDog.Mode.LUNGE)
	check("it springs again", lunged)
	# (he jumps aside, a long way, as it springs)
	var aside := Vector3(-to_boy.z, 0.0, to_boy.x).normalized()
	var dodge: Vector3 = maze.world(home) + aside * 5.0
	if not nav.line_free(maze.world(home), dodge, 0.3):
		dodge = maze.world(home) - aside * 5.0
	put_boy(dodge)
	var shaking := await wait(2.0, func() -> bool: return dog.mode == MazeDog.Mode.SHAKE)
	check("it misses, and shakes itself", shaking and caught_by.is_empty(), "(mode %s, caught %d)" % [MazeDog.Mode.keys()[dog.mode], caught_by.size()])
	check("the shake is shown", dog.dog.busy())
	await clear_dogs()

	# --- Where the trail breaks, it casts about and gives up ---
	put_boy(maze.world(home))
	await frames(10)
	# (the dog on his way, held still while he goes by, as before)
	dog = dog_at(route[2])
	dog.sight_range = 0.0
	dog.hear_range = 0.0
	dog.roam_speed = 0.0
	dog._rest_left = 999.0
	await walk_boy(route[6], 3.0)
	dog.roam_speed = 1.5
	dog._rest_left = 0.0
	# (and then he is up on a wall: far off, and no trail to it)
	put_boy(maze.world(lairs[0]) + Vector3.UP * 20.0)
	var cast := await wait(30.0, func() -> bool: return dog.mode == MazeDog.Mode.CAST)
	check("the trail stops: it casts about", cast, "(mode %s)" % MazeDog.Mode.keys()[dog.mode])
	var gave_up := await wait(8.0, func() -> bool: return dog.mode == MazeDog.Mode.ROAM)
	check("and gives up", gave_up)
	await clear_dogs()

	# --- A puppet follows the host, and lunges with it ---
	put_boy(maze.world(home))
	await frames(70)
	var host := dog_at(straight, atan2(to_boy.x, to_boy.z))
	var copy := MazeDog.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	var furthest := 0.0
	var copied_lunge := false
	for i in 900:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		furthest = maxf(furthest, copy.global_position.distance_to(host.global_position)) if i > 30 else furthest
		if copy.dog.lunge_stage() != Dog.Lunge.NONE:
			copied_lunge = true
	check("the puppet keeps up with the host", furthest < 1.5, "(at most %.2f m off)" % furthest)
	check("the puppet lunges when the host does", copied_lunge)
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear_dogs()

	# --- A pack ---
	var four := MazeDog.pack_of(4, 7)
	var looks := {}
	for one in four:
		looks["%d %s %.2f" % [one.variant, one.coat_tint, one.size]] = true
	check("a pack of four, no two alike", four.size() == 4 and looks.size() == 4)
	var again := MazeDog.pack_of(4, 7)
	check("the same pack from the same seed", again[2].size == four[2].size and again[3].coat_tint == four[3].coat_tint)
	for one in four + again:
		one.free()
	var probe := MazeDog.new()
	check("speeds: tracking slower than a run, the chase between a run and a sprint", probe.track_speed < 4.4 and probe.chase_speed > 4.4 and probe.chase_speed < 5.6)
	probe.free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
