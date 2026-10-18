extends SceneTree
## The things that hunt in the maze (scripts/enemies/), headless, in a bare
## scene: a maze from MazeBuilder, the boy standing still in it, and then in
## turn the way through (MazeNav), Apophis, a pack of mummies, each of the
## other kinds of mummy, staying out of the clearing, wandering with nobody
## about, puppets following what the host sends, and MazeEnemies putting the
## same ones in the same places from the same seed.
##
##     godot --headless --path . -s res://tests/enemy_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0
var caught_by: Array = []
## (with `trace` after `--`, it says what each is doing as it goes)
var trace := OS.get_cmdline_user_args().has("trace")


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


## Lets up to `seconds` go by, or fewer if `until` comes true. Says whether it did.
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


func put_boy(cell: Vector2i) -> void:
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


## A passage cell `steps` from the boy's cell by the passages (and out of the clearing).
func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


func steps_between(a: Vector3, b: Vector3) -> int:
	return nav.distance(maze.cell_at(a), maze.cell_at(b))


func _on_caught(player: Node3D, who: Node) -> void:
	caught_by.append([player, who])


func clear_enemies() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()


func _run() -> void:
	await frames(10)
	print("maze %d x %d, exit %s" % [maze.size, maze.size, maze.exit])

	# --- The way through ---
	var lairs: Array = nav.lairs(5)
	check("places to lurk", lairs.size() > 40, "(%d cells)" % lairs.size())
	var far: Vector2i = lairs[lairs.size() - 1]
	var start: Vector2i = lairs[0]
	var path: Array = nav.path(far, start)
	check("a path between two far cells", path.size() > 2 and path[0] == far and path.back() == start, "(%d cells)" % path.size())
	var walls_crossed := 0
	for i in path.size() - 1:
		if maze.blocked(path[i], path[i + 1] - path[i]):
			walls_crossed += 1
	check("the path goes through no wall", walls_crossed == 0)
	var no_clearing := true
	for cell in path:
		if maze.in_clearing(cell):
			no_clearing = false
	check("the path keeps out of the clearing", no_clearing)
	# Line of sight: down a straight open run, yes; through a wall, no.
	var open_run := Vector2i(-1, -1)
	var walled := Vector2i(-1, -1)
	for cell: Vector2i in lairs:
		if open_run.x < 0 and not maze.blocked(cell, Vector2i(1, 0)) and not maze.blocked(cell + Vector2i(1, 0), Vector2i(1, 0)):
			open_run = cell
		if walled.x < 0 and maze.blocked(cell, Vector2i(1, 0)):
			walled = cell
	check("sees down an open passage", nav.sees(maze.world(open_run) + Vector3.UP, maze.world(open_run + Vector2i(2, 0)) + Vector3.UP))
	check("does not see through a wall", not nav.sees(maze.world(walled) + Vector3.UP, maze.world(walled + Vector2i(1, 0)) + Vector3.UP))
	var t0 := Time.get_ticks_usec()
	for i in 200:
		nav._fields.clear()
		nav.field(Vector2i(i % maze.size, (i * 7) % maze.size))
	print("      a field of the whole maze: %.3f ms" % ((Time.get_ticks_usec() - t0) / 200000.0))

	# --- Apophis ---
	var home: Vector2i = lairs[lairs.size() / 2]
	put_boy(home)
	await frames(20)
	var snake_cell := cell_from(home, 6)
	var snake := Apophis.new()
	snake.name = "Apophis"
	snake.maze = maze
	snake.start_resting = false
	snake.position = maze.world(snake_cell) + Vector3.UP * 0.05
	stage.add_child(snake)
	snake.caught.connect(_on_caught.bind(snake))
	# (he has caught sight of the boy, far off down the passages)
	snake.notice(boy)
	var steps_at_start := steps_between(snake.global_position, boy.global_position)
	var through := [0]
	var tick := [0]
	var watch := func() -> bool:
		tick[0] += 1
		if trace and tick[0] % 60 == 0:
			print("      %d s: %s at %s, %d cells off, after %s, way %s" % [tick[0] / 60, Apophis.State.keys()[snake.state], snake.global_position, steps_between(snake.global_position, boy.global_position), snake.quarry, snake.way(snake._radius * 1.6)])
		# (his head may never be inside a wall)
		if not nav.clear_of_walls(snake.global_position, -0.05):
			through[0] += 1
		return not caught_by.is_empty()
	var got := await wait(50.0, watch)
	check("Apophis comes by the passages and catches a boy who stands", got, "(from %d cells; %d frames in a wall; at %s)" % [steps_at_start, through[0], snake.global_position])
	check("his head kept out of the walls", through[0] == 0)
	check("caught(player) says who", got and caught_by[0][0] == boy)
	var cost: Dictionary = snake.cost()
	check("he is a few draws", cost["draws"] <= 3, "(%d triangles in %d draws)" % [cost["triangles"], cost["draws"]])
	# Lying at rest, he wakes when he sees someone.
	caught_by.clear()
	snake.start_resting = true
	snake.reset()
	# (nobody in sight, he lies still)
	put_boy(far)
	await frames(30)
	check("at rest he lies still", snake.state == Apophis.State.DORMANT)
	# (somewhere he can see, two or three cells off)
	var head_cell: Vector2i = maze.cell_at(snake.global_position)
	var field: PackedInt32Array = nav.field(head_cell)
	var seen_cell := Vector2i(-1, -1)
	for i in field.size():
		var cell := Vector2i(i % maze.size, i / maze.size)
		if field[i] >= 1 and field[i] <= 3 and nav.sees(snake.global_position + Vector3.UP, maze.world(cell) + Vector3.UP):
			seen_cell = cell
	check("somewhere in his sight to stand", seen_cell.x >= 0)
	put_boy(seen_cell)
	await frames(5)
	var woke := await wait(4.0, func() -> bool: return snake.state != Apophis.State.DORMANT)
	check("he wakes on seeing someone", woke, "(state %s)" % Apophis.State.keys()[snake.state])
	# A puppet of him follows the host's news.
	var copy := Apophis.new()
	copy.name = "ApophisCopy"
	copy.maze = maze
	copy.puppet = true
	copy.position = snake.position
	stage.add_child(copy)
	var worst := 0.0
	for i in 240:
		await physics_frame
		if i % 5 == 0:
			copy.from_bytes(snake.state_bytes())
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(snake.global_position))
	check("a puppet Apophis follows the host's news", worst < 2.5, "(at worst %.2f m behind; state %s / %s)" % [worst, Apophis.State.keys()[snake.state], Apophis.State.keys()[copy.state]])
	check("his news is %d bytes" % MazeEnemy.STATE_SIZE, snake.state_bytes().size() == MazeEnemy.STATE_SIZE)
	clear_enemies()
	await frames(2)

	# --- A pack of mummies ---
	put_boy(home)
	await frames(10)
	var pack_cell := cell_from(home, 4)
	var mummies: Array = []
	for k in [Mummy.Kind.SHAMBLER, Mummy.Kind.SHAMBLER, Mummy.Kind.BRUTE]:
		var mummy := Mummy.new()
		mummy.kind = k
		mummy.maze = maze
		mummy.position = maze.world(pack_cell) + Vector3(mummies.size() * 0.9 - 0.9, 0.05, 0.0)
		stage.add_child(mummy)
		mummy.caught.connect(_on_caught.bind(mummy))
		mummies.append(mummy)
	# (one of them catches sight of him: the others are told)
	mummies[0].notice(boy)
	var before := steps_between(mummies[0].global_position, boy.global_position)
	got = await wait(70.0, func() -> bool: return not caught_by.is_empty())
	var closest := 99
	for mummy in mummies:
		closest = mini(closest, steps_between(mummy.global_position, boy.global_position))
	check("a pack of mummies comes by the passages and catches a boy who stands", got, "(from %d cells; now %d)" % [before, closest])
	var apart := true
	for a in mummies:
		for b in mummies:
			if a != b and a.global_position.distance_to(b.global_position) < 0.4:
				apart = false
	check("they keep apart", apart)
	# One that sees him tells the others.
	var noticed := 0
	for mummy in mummies:
		if mummy.quarry == boy or mummy.chasing:
			noticed += 1
	check("the pack hunts together", noticed >= 2, "(%d of 3 after him)" % noticed)
	# A puppet mummy follows its host, swipes and all.
	var host: Mummy = mummies[0]
	# (alone, so that it is the one that gets to him)
	mummies[1].queue_free()
	mummies[2].queue_free()
	var shadow := Mummy.new()
	shadow.maze = maze
	shadow.puppet = true
	shadow.position = host.position
	stage.add_child(shadow)
	put_boy(cell_from(maze.cell_at(host.global_position), 1))
	host._spared.clear()
	host.notice(boy)
	caught_by.clear()
	worst = 0.0
	var swiped := false
	for i in 1200:
		await physics_frame
		if i % 5 == 0:
			shadow.from_bytes(host.state_bytes())
		if i > 30:
			worst = maxf(worst, shadow.global_position.distance_to(host.global_position))
		if trace and i % 60 == 0:
			print("      host %s at %s, %.1f m from him, after %s, stage %d" % [Mummy.Mode.keys()[host.mode], host.global_position, host.global_position.distance_to(boy.global_position), host.quarry, host._rig.stage()])
		if shadow._rig.stage() != MummyRig.Stage.NONE:
			swiped = true
		if not caught_by.is_empty() and i > 200:
			break
	check("a puppet mummy follows the host's news", worst < 1.5, "(at worst %.2f m behind)" % worst)
	check("and swipes when its host does", swiped, "(the host swiped %d times)" % host._swipes)
	clear_enemies()
	await frames(2)

	# --- Each other kind gets to him ---
	for k in [Mummy.Kind.PRIEST, Mummy.Kind.CRAWLER, Mummy.Kind.CHILD, Mummy.Kind.ROYAL]:
		put_boy(home)
		await frames(5)
		var one := Mummy.new()
		one.kind = k
		one.maze = maze
		one.position = maze.world(cell_from(home, 2)) + Vector3.UP * 0.05
		stage.add_child(one)
		one.caught.connect(_on_caught.bind(one))
		got = await wait(30.0, func() -> bool: return not caught_by.is_empty())
		check("a %s mummy catches him" % Mummy.Kind.keys()[k], got, "(%d cells off at the end)" % steps_between(one.global_position, boy.global_position))
		clear_enemies()
		await frames(2)

	# --- The clearing is out of bounds ---
	put_boy(maze.cell_at(Vector3.ZERO))
	var gate: Array = maze.gates[0][0]
	var outside: Vector2i = gate[0] + gate[1]
	var guard := Mummy.new()
	guard.maze = maze
	guard.position = maze.world(cell_from(outside, 2)) + Vector3.UP * 0.05
	stage.add_child(guard)
	guard.alerted(boy, guard.global_position)
	var entered := [false]
	await wait(25.0, func() -> bool:
		if maze.in_clearing(maze.cell_at(guard.global_position)):
			entered[0] = true
		return false)
	check("a mummy comes to the clearing's gate and no further", not entered[0] and steps_between(guard.global_position, maze.world(outside)) <= 1, "(%s; %d cells from the gate)" % [guard.global_position, steps_between(guard.global_position, maze.world(outside))])
	clear_enemies()
	await frames(2)

	# --- With nobody about they wander ---
	boy.remove_from_group(&"maze_players")
	var wanderer := Mummy.new()
	wanderer.maze = maze
	wanderer.position = maze.world(home) + Vector3.UP * 0.05
	stage.add_child(wanderer)
	var serpent := Apophis.new()
	serpent.maze = maze
	serpent.start_resting = false
	serpent.position = maze.world(far) + Vector3.UP * 0.05
	stage.add_child(serpent)
	var cells := {}
	var snake_from := serpent.global_position
	var snake_went := 0.0
	for i in 60 * 25:
		await physics_frame
		cells[maze.cell_at(wanderer.global_position)] = true
		snake_went = maxf(snake_went, serpent.global_position.distance_to(snake_from))
	check("a mummy wanders with nobody about", cells.size() >= 3, "(%d cells visited)" % cells.size())
	# (how far it gets, not how many cells: the first ring's halls are two cells wide)
	check("so does Apophis", snake_went >= 20.0, "(%.0f m from where it started)" % snake_went)
	var inside: bool = maze.inside(maze.cell_at(wanderer.global_position)) and maze.inside(maze.cell_at(serpent.global_position))
	check("and they stay in the maze", inside)
	boy.add_to_group(&"maze_players")
	clear_enemies()
	await frames(2)

	# --- MazeEnemies: the same seed, the same ones in the same places ---
	var a := MazeEnemies.new()
	stage.add_child(a)
	a.populate(maze, 77)
	var b := MazeEnemies.new()
	b.puppet = true
	stage.add_child(b)
	b.populate(maze, 77)
	var same := a.enemies.size() == b.enemies.size() and a.enemies.size() > 3
	for i in mini(a.enemies.size(), b.enemies.size()):
		if a.enemies[i].get_class() != b.enemies[i].get_class() or a.enemies[i].global_position.distance_to(b.enemies[i].global_position) > 0.01 or a.enemies[i].get_script() != b.enemies[i].get_script():
			same = false
	check("MazeEnemies: the same seed puts the same ones in the same places", same, "(%d of them)" % a.enemies.size())
	var lurk_ok := true
	for enemy in a.enemies:
		if maze.in_clearing(maze.cell_at(enemy.global_position)) or maze.distance[maze.index(maze.cell_at(enemy.global_position))] < 3:
			lurk_ok = false
	check("none of them starts in or near the clearing", lurk_ok)
	var data: PackedByteArray = a.pack()
	check("pack() is a byte for the count and %d each" % MazeEnemy.STATE_SIZE, data.size() == 1 + a.enemies.size() * MazeEnemy.STATE_SIZE, "(%d bytes)" % data.size())
	b.unpack(data)
	await frames(2)
	var far_off := 0.0
	for i in a.enemies.size():
		far_off = maxf(far_off, a.enemies[i].global_position.distance_to(b.enemies[i].global_position))
		if trace:
			print("      %s %s: %.2f m" % [a.enemies[i].name, a.enemies[i].get_script().get_global_name(), a.enemies[i].global_position.distance_to(b.enemies[i].global_position)])
	check("unpack() puts the puppets where the host's are", far_off < 0.6, "(%.2f m at most)" % far_off)
	# What each costs a frame, here (a phone is several times slower).
	var mummy: Mummy = null
	var serpent2: Apophis = null
	for enemy in a.enemies:
		if enemy is Mummy and mummy == null:
			mummy = enemy
		if enemy is Apophis and serpent2 == null:
			serpent2 = enemy
	var dt := 1.0 / 60.0
	var t := Time.get_ticks_usec()
	for i in 100:
		mummy._physics_process(dt)
	var think := (Time.get_ticks_usec() - t) / 100000.0
	t = Time.get_ticks_usec()
	for i in 100:
		mummy._rig._process(dt)
	var pose := (Time.get_ticks_usec() - t) / 100000.0
	t = Time.get_ticks_usec()
	for i in 100:
		serpent2._physics_process(dt)
	var hunt := (Time.get_ticks_usec() - t) / 100000.0
	t = Time.get_ticks_usec()
	for i in 100:
		serpent2._draw(dt)
	var lay := (Time.get_ticks_usec() - t) / 100000.0
	print("      a mummy: %.3f ms to think and move, %.3f ms to pose; Apophis: %.3f ms to think and move, %.3f ms to lay his body (this PC)" % [think, pose, hunt, lay])

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
