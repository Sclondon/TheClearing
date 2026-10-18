extends SceneTree
## The giant centipede, headless: first its body on its own (CentipedeBody,
## creatures/centipede: following its head without stretching, the stages of a
## strike, the claws' hit test), then the maze's Centipede (scripts/enemies/):
## hunting a boy who stands and catching him, keeping its head out of the walls,
## lying coiled and waking when it sees someone, searching where it lost them,
## going to coil up in a dead end, and a puppet copy following the host's news.
##
##     godot --headless --path . -s res://tests/centipede_test.gd [-- trace]
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0
var caught_by: Array = []
var trace := OS.get_cmdline_user_args().has("trace")


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
	_run.call_deferred()


func _run() -> void:
	await _body_alone()
	await _in_the_maze()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


# --- The body on its own, on a bare floor ---

func _body_alone() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	stage.add_child(ground)
	var body := CentipedeBody.new()
	body.voice = false
	stage.add_child(body)
	await frames(3)
	check("its body is laid out", body.spine.size() == body.segments + 1)
	check("it is three draws", body.cost()["draws"] == 3, "(%d triangles)" % body.cost()["triangles"])
	# Runs forward 20 m and round a bend: every length stays its own distance from the next.
	for i in 180:
		var turn := 0.02 if i > 90 else 0.0
		var basis := body.global_basis.rotated(Vector3.UP, turn)
		body.global_transform = Transform3D(basis, body.global_position + basis.z * 0.11)
		await process_frame
	var worst := 0.0
	var spacing := body.spine[2].distance_to(body.spine[3])
	for i in range(2, body.spine.size() - 1):
		worst = maxf(worst, absf(body.spine[i].distance_to(body.spine[i + 1]) - spacing))
	check("its body follows its head without stretching", worst < 0.15, "(lengths %.2f m, out by at most %.2f)" % [spacing, worst])
	var tail := body.spine[body.spine.size() - 1]
	check("its tail is well behind its head", tail.distance_to(body.global_position) > body.length * 0.6, "(%.1f m)" % tail.distance_to(body.global_position))
	# Rears: it bends but does not stretch.
	body.rear(1.0)
	for i in 120:
		await process_frame
	worst = 0.0
	for i in range(1, body.spine.size() - 1):
		worst = maxf(worst, absf(body.spine[i].distance_to(body.spine[i + 1]) - spacing))
	check("reared, its head is up", body.head_at.y > body.rear_height * 0.6, "(%.2f m up)" % body.head_at.y)
	check("reared, it does not stretch", worst < 0.15, "(out by at most %.2f)" % worst)
	body.rear(0.0)
	for i in 60:
		await process_frame
	# The strike: the stages in order, and the claws find a target in front and miss one to the side.
	var forward := body.global_basis.z
	var target := body.global_position + forward * 4.5
	var aside := body.global_position + forward * 4.5 + body.global_basis.x * 3.0
	body.strike(target + Vector3.UP * 0.6)
	var seen := {}
	var hit := false
	var hit_aside := false
	for i in 6000:
		await process_frame
		seen[body.stage()] = true
		if i > 10 and body.stage() == CentipedeBody.Stage.NONE:
			break
		if body.bites(target, target + Vector3.UP * 1.1, 0.85):
			hit = true
		if body.bites(aside, aside + Vector3.UP * 1.1, 0.85):
			hit_aside = true
	check("a strike goes through every stage", seen.size() == 5, "(%s)" % str(seen.keys()))
	check("its claws find what is in front of it", hit)
	check("and miss what is to one side", not hit_aside)
	body.lay_coil()
	await frames(2)
	var middle := Vector3.ZERO
	for at in body.spine:
		middle += at
	middle /= body.spine.size()
	check("coiled, it lies in a ring", middle.distance_to(body.global_position) < 4.5, "(its middle %.1f m from its head)" % middle.distance_to(body.global_position))
	body.queue_free()
	ground.queue_free()
	await frames(2)


# --- In the maze ---

func put_boy(cell: Vector2i) -> void:
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


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


func spawn(cell: Vector2i, resting: bool) -> Centipede:
	var hunter := Centipede.new()
	hunter.name = "Centipede"
	hunter.maze = maze
	hunter.start_resting = resting
	hunter.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(hunter)
	hunter.body.voice = false
	hunter.caught.connect(_on_caught.bind(hunter))
	return hunter


func _in_the_maze() -> void:
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
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]
	put_boy(home)
	await frames(20)

	# It comes by the passages and catches a boy who stands.
	var hunter := spawn(cell_from(home, 6), false)
	hunter.notice(boy)
	var from := steps_between(hunter.global_position, boy.global_position)
	var in_walls := [0]
	var tick := [0]
	var struck := [false]
	var got := await wait(50.0, func() -> bool:
		tick[0] += 1
		if trace and tick[0] % 60 == 0:
			print("      %d s: %s at %s, %d cells off" % [tick[0] / 60, Centipede.State.keys()[hunter.state], hunter.global_position.snappedf(0.1), steps_between(hunter.global_position, boy.global_position)])
		if not nav.clear_of_walls(hunter.global_position, -0.05):
			in_walls[0] += 1
		if hunter.state == Centipede.State.STRIKE:
			struck[0] = true
		return not caught_by.is_empty())
	check("it comes by the passages and catches a boy who stands", got, "(from %d cells)" % from)
	check("it struck to catch him", struck[0])
	check("its head kept out of the walls", in_walls[0] == 0, "(%d frames in one)" % in_walls[0])
	check("caught(player) says who", got and caught_by[0][0] == boy)

	# A puppet copy follows it, strike and all.
	var copy := Centipede.new()
	copy.name = "CentipedeCopy"
	copy.maze = maze
	copy.puppet = true
	copy.start_resting = false
	copy.position = hunter.position
	stage.add_child(copy)
	copy.body.voice = false
	hunter._spared.clear()
	put_boy(cell_from(maze.cell_at(hunter.global_position), 2))
	hunter.notice(boy)
	caught_by.clear()
	var worst := 0.0
	var copied_strike := false
	for i in 900:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(hunter.state_bytes())
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(hunter.global_position))
		if copy.body.stage() != CentipedeBody.Stage.NONE:
			copied_strike = true
		if not caught_by.is_empty() and i > 120:
			break
	check("a puppet follows the host's news", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("and strikes when its host does", copied_strike)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, hunter.state_bytes().size() == MazeEnemy.STATE_SIZE)
	copy.queue_free()

	# Losing him: it goes to where he was, stops and feels about for him, then prowls.
	caught_by.clear()
	hunter._spared.clear()
	put_boy(cell_from(maze.cell_at(hunter.global_position), 3))
	await frames(5)
	hunter.notice(boy)
	await wait(1.0)
	boy.remove_from_group(&"maze_players")
	var searched := await wait(25.0, func() -> bool: return hunter.state == Centipede.State.SEARCH)
	check("losing him, it stops to feel about for him", searched, "(state %s)" % Centipede.State.keys()[hunter.state])
	var prowled := await wait(8.0, func() -> bool: return hunter.state == Centipede.State.PROWL)
	check("then prowls", prowled)
	# With nobody about for long enough, it goes to a dead end and coils up.
	hunter.rest_after = 2.0
	var ticks := [0]
	var rested := await wait(60.0, func() -> bool:
		ticks[0] += 1
		if trace and ticks[0] % 60 == 0:
			print("      %d s: %s at %s, den %s ring %.1f, turned %.1f, v %.2f" % [ticks[0] / 60, Centipede.State.keys()[hunter.state], hunter.global_position.snappedf(0.1), maze.world(hunter._den).snappedf(0.1), hunter._den_radius, hunter._den_turned, Vector2(hunter.velocity.x, hunter.velocity.z).length()])
		return hunter.state == Centipede.State.RESTING)
	var cell: Vector2i = maze.cell_at(hunter.global_position)
	check("with nobody about it coils up in a dead end or a corner", rested and hunter.walls_round(hunter._den) >= 2, "(state %s, in %s, den %s)" % [Centipede.State.keys()[hunter.state], cell, hunter._den])
	hunter.queue_free()
	await frames(2)

	# Coiled at rest, it lies still until it sees someone; then it wakes.
	var den: Vector2i = home
	for c: Vector2i in lairs:
		if nav.dead_end(c):
			den = c
			break
	var sleeper := spawn(den, true)
	put_boy(lairs[0] if lairs[0] != den else lairs[1])
	await wait(1.5)
	check("coiled, it lies still with nobody in sight", sleeper.state == Centipede.State.RESTING)
	var seen_from := Vector2i(-1, -1)
	var field: PackedInt32Array = nav.field(den)
	for i in field.size():
		var c := Vector2i(i % maze.size, i / maze.size)
		if field[i] >= 1 and field[i] <= 2 and nav.sees(maze.world(den) + Vector3.UP, maze.world(c) + Vector3.UP):
			seen_from = c
	boy.add_to_group(&"maze_players")
	put_boy(seen_from)
	var woke := await wait(4.0, func() -> bool: return sleeper.state != Centipede.State.RESTING)
	check("it wakes on seeing someone", woke, "(state %s)" % Centipede.State.keys()[sleeper.state])
	sleeper.queue_free()
	await frames(2)
