extends SceneTree
## The moose (scripts/enemies/maze_moose.gd and maze_moose_calf.gd on
## creatures/moose), headless, in a bare scene: a maze from MazeBuilder and the
## boy in it. In turn:
## - a cow and her calf, together; each at a wallow (a calf shares its mother's);
## - a bull out of the rut only watches him from down the hall;
## - a bull in the rut warns (ears back, hackles up, a lick of the lips), then
##   charges in its trot, faster than he can run; standing still he is knocked
##   down, it rounds on him and rears, and the hooves catch him;
## - knocked down, getting straight up and away: the hooves miss;
## - getting behind something (out of its line) ends a charge: it stands blowing;
## - up off the ground he is only watched;
## - a cow: near her calf she warns; far from it, she only watches; the calf
##   goes round behind her; she charges a hunter after her calf, and knocks it back;
## - a moose runs from a bigger hunter after it;
## - puppets follow their hosts, with the strike, and a guest's own boy is
##   knocked down where the host's moose knocked him; the sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/moose_test.gd
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


func put_boy(at: Vector3, face_to := Vector3.INF) -> void:
	if boy.is_limp:
		boy.recover()
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	if face_to.is_finite():
		var to: Vector3 = face_to - at
		boy.facing_yaw = atan2(to.x, to.z)


func enemy_in(one: MazeEnemy, at: Vector3, yaw := 0.0) -> MazeEnemy:
	one.maze = maze
	one.position = at + Vector3.UP * 0.05
	one.rotation.y = yaw
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	if boy.is_limp:
		boy.recover()
	await frames(3)


## A straight run of passage `length` cells long from a cell well out of the clearing: [start cell, step].
func long_hall(length: int) -> Array:
	for cell: Vector2i in nav.lairs(4):
		for step: Vector2i in Maze.STEPS:
			var at := cell
			var run := 0
			while run < length and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run == length:
				return [cell, step]
	return []


func a_bull(at: Vector3, facing: Vector3, rut: float) -> MazeMoose:
	var bull := MazeMoose.new()
	bull.rut = rut
	bull.seed_choices(5)
	return enemy_in(bull, at, atan2(facing.x, facing.z)) as MazeMoose


func _run() -> void:
	await frames(10)
	var hall := long_hall(4)
	check("a long straight hall", not hall.is_empty())
	var start: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var far_end: Vector3 = maze.world(start + step * 3)
	var near_end: Vector3 = maze.world(start)

	# --- A cow and her calf ---
	var pair := MazeMoose.family(3)
	check("a family: a cow and her calf", pair.size() == 2 and pair[0].cow and pair[1] is MazeMooseCalf and pair[0].calf == pair[1] and pair[1].mother == pair[0])
	for one in pair:
		one.free()

	# --- Out of the rut: a bull only watches ---
	var bull := a_bull(far_end, -way, 0.0)
	put_boy(far_end - way * 16.0, far_end)
	var watched := await wait(3.0, func() -> bool: return bull.mode == MazeMoose.Mode.WATCH)
	await wait(1.5)
	check("out of the rut, a bull down the hall only watches him", watched and bull.mode in [MazeMoose.Mode.WATCH, MazeMoose.Mode.BROWSE] and not bull.in_rut, "(%s)" % MazeMoose.Mode.keys()[bull.mode])
	check("its wallow: a pool where it was put", bull.pool != null and bull.pool.global_position.distance_to(far_end) < 1.0)
	# ...but come right up to it, and it warns
	put_boy(bull.global_position - way * 4.0, bull.global_position)
	var warned := await wait(2.0, func() -> bool: return bull.mode == MazeMoose.Mode.WARN)
	check("right up to it, even out of the rut it warns", warned)
	await clear()

	# --- In the rut: the warning, the charge, knocked down, the strike ---
	bull = a_bull(far_end, -way, 1.0)
	check("in the rut", bull.in_rut)
	var licked := [false]
	bull.moose.licked.connect(func() -> void: licked[0] = true)
	put_boy(far_end - way * 18.0, far_end)
	warned = await wait(3.0, func() -> bool: return bull.mode == MazeMoose.Mode.WARN)
	await frames(30)
	check("in the rut he warns him from 18 m", warned)
	check("the warning: hackles up, ears back, staring at him", bull.moose.bristling and bull.moose.fleeing and bull.moose.look_at_point.distance_to(boy.global_position + Vector3.UP) < 2.0)
	var charged := await wait(4.0, func() -> bool: return bull.mode == MazeMoose.Mode.CHARGE)
	check("licking his lips; then he charges", charged and licked[0], "(licked %s)" % licked[0])
	var top := [0.0]
	var knocked := await wait(5.0, func() -> bool:
		top[0] = maxf(top[0], Vector2(bull.velocity.x, bull.velocity.z).length())
		return bull.mode == MazeMoose.Mode.KNOCK)
	check("faster than a sprint", top[0] > boy.sprint_speed, "(%.1f m/s)" % top[0])
	await frames(2)
	check("standing in his way he is knocked down", knocked and boy.is_limp)
	var struck := await wait(3.0, func() -> bool: return bull.mode == MazeMoose.Mode.STRIKE)
	check("it rounds on him and rears to strike", struck and bull.moose.striking())
	var caught := await wait(2.5, func() -> bool: return not caught_by.is_empty())
	check("lying there, the hooves catch him", caught and caught_by[0][0] == boy)
	await clear()

	# --- Knocked down, up and away at once: missed ---
	bull = a_bull(far_end, -way, 1.0)
	bull.warn_time = Vector2(0.8, 0.8)
	put_boy(far_end - way * 14.0, far_end)
	knocked = await wait(9.0, func() -> bool: return bull.mode == MazeMoose.Mode.KNOCK)
	var down_at: Vector3 = bull._down_at
	await wait(MazeMoose.KNOCK_TIME + 0.1)
	# (up, and running off: four metres from where he went down, clear of the walls)
	var aside := Vector3(way.z, 0.0, -way.x)
	var clear_spot := down_at - way * 4.5
	for spot: Vector3 in [down_at + aside * 4.0, down_at - aside * 4.0, down_at - way * 4.5]:
		if nav.clear_of_walls(spot, 0.6):
			clear_spot = spot
			break
	put_boy(clear_spot)
	await wait(3.0)
	check("knocked down, up and away at once: the hooves miss", knocked and caught_by.is_empty() and bull.mode in [MazeMoose.Mode.BLOW, MazeMoose.Mode.WARN, MazeMoose.Mode.CHARGE, MazeMoose.Mode.STRIKE, MazeMoose.Mode.KNOCK], "(%s)" % MazeMoose.Mode.keys()[bull.mode])
	await clear()

	# --- Behind something: the charge ends ---
	bull = a_bull(far_end, -way, 1.0)
	bull.warn_time = Vector2(0.8, 0.8)
	put_boy(far_end - way * 16.0, far_end)
	charged = await wait(6.0, func() -> bool: return bull.mode == MazeMoose.Mode.CHARGE)
	# (out of its line: on the far side of a wall of the hall, in the passage there)
	var hidden := Vector3.INF
	var hide_near := INF
	for cell: Vector2i in nav.lairs(1):
		var p: Vector3 = nav.point(cell)
		var d: float = p.distance_to(boy.global_position)
		if d < hide_near and p.distance_to(bull.global_position) < 30.0 and not nav.line_free(bull.global_position + Vector3.UP * 0.6, p + Vector3.UP * 0.6, 0.3) and nav.clear_of_walls(p, 0.5):
			hide_near = d
			hidden = p
	check("somewhere out of its line to hide", hidden.is_finite())
	put_boy(hidden)
	var blown := await wait(4.0, func() -> bool: return bull.mode == MazeMoose.Mode.BLOW)
	check("out of its line (round a corner), it pulls up and stands blowing", charged and blown and caught_by.is_empty() and not boy.is_limp, "(%s)" % MazeMoose.Mode.keys()[bull.mode])
	await clear()

	# --- Up off the ground: only watched ---
	bull = a_bull(far_end, -way, 1.0)
	put_boy(far_end - way * 12.0, far_end)
	await frames(2)
	boy.global_position += Vector3.UP * 3.0
	var never := true
	for i in 240:
		boy.global_position = Vector3(boy.global_position.x, far_end.y + 3.1, boy.global_position.z)
		boy.velocity = Vector3.ZERO
		await physics_frame
		if bull.mode in [MazeMoose.Mode.WARN, MazeMoose.Mode.CHARGE]:
			never = false
	check("up off the ground he is only watched", never, "(%s)" % MazeMoose.Mode.keys()[bull.mode])
	await clear()

	# --- A cow and her calf ---
	pair = MazeMoose.family(9)
	var cow: MazeMoose = enemy_in(pair[0], far_end, atan2(-way.x, -way.z)) as MazeMoose
	var young: MazeMoose = enemy_in(pair[1], far_end - way * 3.0) as MazeMoose
	put_boy(far_end - way * 18.5, far_end)
	await wait(3.0)
	check("far from her calf, she only watches", cow.mode in [MazeMoose.Mode.WATCH, MazeMoose.Mode.BROWSE], "(%s)" % MazeMoose.Mode.keys()[cow.mode])
	check("the calf keeps near her", young.global_position.distance_to(cow.global_position) < 7.0)
	put_boy(young.global_position - way * 7.0, young.global_position)
	warned = await wait(3.0, func() -> bool: return cow.mode == MazeMoose.Mode.WARN)
	check("near her calf, she warns", warned)
	await wait(1.0)
	var behind: float = (young.global_position - cow.global_position).dot((cow.global_position - boy.global_position).normalized())
	check("the calf goes round behind her", behind > 0.5, "(%.1f m behind)" % behind)
	await clear()

	# --- She charges a hunter after her calf, and knocks it back ---
	var world_life := Ecology.put(stage, 1)
	pair = MazeMoose.family(11)
	cow = enemy_in(pair[0], far_end, atan2(-way.x, -way.z)) as MazeMoose
	young = enemy_in(pair[1], far_end + way * 1.5) as MazeMoose
	boy.remove_from_group(&"maze_players")
	var dog := MazeDog.new()
	enemy_in(dog, far_end - way * 12.0, atan2(way.x, way.z))
	await frames(2)
	dog.hunger = 1.0
	dog.notice(young)
	var defended := await wait(6.0, func() -> bool: return cow.mode in [MazeMoose.Mode.WARN, MazeMoose.Mode.CHARGE] and cow._target == dog)
	check("a hunter after her calf: she turns on it", defended, "(%s)" % MazeMoose.Mode.keys()[cow.mode])
	var shoved := await wait(8.0, func() -> bool: return dog.get_node_or_null(^"Stagger") != null)
	check("and knocks it back", shoved)
	await clear()
	world_life.queue_free()
	await frames(2)

	# --- It runs from a bigger hunter after it ---
	bull = a_bull(far_end, -way, 0.0)
	var snake := Apophis.new()
	snake.puppet = true
	enemy_in(snake, far_end - way * 10.0)
	await frames(5)
	bull.threat = snake
	var from_snake: float = bull.global_position.distance_to(snake.global_position)
	var fled := await wait(1.0, func() -> bool: return bull.mode == MazeMoose.Mode.FLEE)
	await wait(3.0)
	var later: float = bull.global_position.distance_to(snake.global_position)
	check("with a bigger hunter after it, it trots off", fled and later > from_snake + 2.0, "(%.1f m to %.1f m)" % [from_snake, later])
	await clear()
	boy.add_to_group(&"maze_players")

	# --- Puppets ---
	var host := a_bull(far_end, -way, 1.0)
	host.warn_time = Vector2(0.8, 0.8)
	var copy := MazeMoose.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	put_boy(far_end - way * 14.0, far_end)
	var furthest := 0.0
	var copy_struck := false
	for i in 600:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30 and host.mode != MazeMoose.Mode.KNOCK:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
		if copy.moose.striking():
			copy_struck = true
	check("the puppet moose keeps up with its host", furthest < 2.5, "(at most %.2f m off)" % furthest)
	check("and strikes when its host does", copy_struck)
	await clear()
	# A guest's own boy is knocked down where the host's moose knocked him.
	var guest := MazeMoose.new()
	guest.maze = maze
	guest.puppet = true
	guest.position = far_end
	stage.add_child(guest)
	put_boy(far_end - way * 2.0)
	await frames(3)
	var news: MazeMoose = MazeMoose.new()
	news.maze = maze
	news.position = far_end
	stage.add_child(news)
	await frames(2)
	news.process_mode = Node.PROCESS_MODE_DISABLED
	guest.from_bytes(news.state_bytes())
	news.mode = MazeMoose.Mode.KNOCK
	news._knocks = 1
	news._down_at = boy.global_position
	guest.from_bytes(news.state_bytes())
	await frames(2)
	check("a guest's boy goes down where the host's moose knocked him", boy.is_limp)
	await wait(MazeMoose.KNOCK_TIME + 0.3)
	check("and gets up again", not boy.is_limp)
	await clear()

	# --- Sounds ---
	var grunt := Moose.call_sound()
	var moan := Moose.moan_sound()
	check("a bull's grunt and a cow's moan are made", grunt.data.size() > 20000 and moan.data.size() > 40000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
