extends SceneTree
## The giant snail (scripts/enemies/maze_snail.gd on creatures/snail),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In
## turn: alone, it crawls about slowly and leaves its slime; seeing him down a
## hall it comes after him, slower than a walk; in its slime he is held back
## to less than it hunts at (and away from it he is not); an eye stalk rolls in
## when he comes near its tip; touching it he is drawn in and only then caught;
## up on a wall top out of its reach, it climbs the wall after him (up the
## face and onto the top) and catches him there; lost, it pulls into its
## shell, and comes out again; bumped by another creature it pulls in; a
## puppet follows the host, up the wall too, and pulls in when it does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/snail_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0
var caught_by: Array = []
var camera: Camera3D


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
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	# (the stick is read against the camera: it says which way is forward for him)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	if boy.is_limp:
		boy.recover()
	boy.process_mode = Node.PROCESS_MODE_INHERIT
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func snail_at(at: Vector3, yaw := 0.0) -> MazeSnail:
	var snail := MazeSnail.new()
	snail.maze = maze
	snail.position = at + Vector3.UP * 0.05
	snail.rotation.y = yaw
	stage.add_child(snail)
	snail.caught.connect(func(player: Node3D) -> void: caught_by.append([player, snail]))
	return snail


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	Input.action_release(&"move_up")
	await frames(2)


func mode_name(snail: MazeSnail) -> String:
	return MazeSnail.Mode.keys()[snail.mode]


func _run() -> void:
	await frames(10)
	# A long straight hall, ending in a wall.
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	var length := 0
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, s) and maze.inside(at + s) and not maze.in_clearing(at + s):
				at += s
				run += 1
			if run >= 4 and maze.blocked(at, s) and run > length:
				hall = cell
				step = s
				length = run
	check("a long straight hall", hall.x >= 0, "(%d cells)" % length)
	var way := Vector3(step.x, 0.0, step.y)
	var start: Vector3 = maze.world(hall)
	var far_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 9:
			far_cell = cell
			break

	# --- Alone, it crawls about slowly, and leaves its slime ---
	put_boy(maze.world(far_cell))
	var snail := snail_at(start, atan2(way.x, way.z))
	await frames(5)
	var from: Vector3 = snail.global_position
	await wait(6.0)
	var moved: float = Vector2(snail.global_position.x - from.x, snail.global_position.z - from.z).length()
	check("alone, it crawls about", snail.mode == MazeSnail.Mode.CRAWLING and moved > 1.0, "(%s, %.1f m in 6 s)" % [mode_name(snail), moved])
	check("slowly", moved / 6.0 < 0.8, "(%.2f m/s)" % (moved / 6.0))
	check("it leaves slime behind it", snail.creature.slime.patches() > 0 and snail.creature.slime_at(from + Vector3.UP * 0.05) > 0.0, "(%d patches)" % snail.creature.slime.patches())
	check("on the floor where it set off", snail.creature.slime_at(from) > 0.5)
	await clear()

	# --- Seeing him down the hall, it comes after him, slower than a walk ---
	var end: Vector3 = maze.world(hall + step * length)
	snail = snail_at(start, atan2(way.x, way.z))
	put_boy(start + way * 26.0)
	var hunting := await wait(3.0, func() -> bool: return snail.hunting())
	check("seeing him down the hall, it comes after him", hunting and snail.mode == MazeSnail.Mode.HUNTING, "(%s)" % mode_name(snail))
	from = snail.global_position
	await wait(5.0)
	var speed: float = snail.global_position.distance_to(from) / 5.0
	check("slower than a walk", speed > 0.8 and speed < boy.walk_speed, "(%.2f m/s; he walks at %.1f)" % [speed, boy.walk_speed])
	check("its eye stalks reach for him", snail.creature.aim.is_finite() or snail.global_position.distance_to(boy.global_position) > 18.0)

	# --- In its slime he is held back; out of it he is not ---
	var trail_point: Vector3 = from + way * 0.5
	var fresh: float = snail.creature.slime_at(trail_point)
	check("its trail lies behind it", fresh > 0.5, "(%.2f fresh)" % fresh)
	snail.sight_range = 0.0
	snail.hear_range = 0.0
	snail.quarry = null
	snail._forget = 0.0
	# (he runs along its trail, back the way it came: -way; forward for him is -Z, so the hall must face it)
	var run_way: Vector3 = -way
	var slime_speed := await _run_speed(trail_point, run_way, snail)
	var clear_speed := await _run_speed(start + way * 9.0 + Vector3(-way.z, 0.0, way.x) * 3.5, run_way, null)
	check("running in its slime, he is held back to less than it hunts at", slime_speed < snail.hunt_speed * 0.95 and slime_speed > 0.1, "(%.2f m/s)" % slime_speed)
	check("out of it, he runs as ever", clear_speed > 3.0, "(%.2f m/s)" % clear_speed)
	await clear()

	# --- An eye stalk rolls in when he comes near its tip ---
	snail = snail_at(start, atan2(way.x, way.z))
	snail.sight_range = 0.0
	snail.hear_range = 0.0
	put_boy(maze.world(far_cell))
	await wait(1.0)
	var tip: Vector3 = snail.creature.eye_tip(0)
	snail.targets = [boy]
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	boy.global_position = tip - Vector3.UP * 1.2 + snail.up * 0.0
	await frames(6)
	var stalk: float = snail.creature.rig._eye_out[0]
	check("an eye stalk rolls in when he comes near its tip", stalk < 0.8 and caught_by.is_empty(), "(out %.2f)" % stalk)
	boy.process_mode = Node.PROCESS_MODE_INHERIT
	snail.targets = []
	await clear()

	# --- Touching it, he is drawn in, and only then caught ---
	snail = snail_at(start, atan2(way.x, way.z))
	snail.sight_range = 0.0
	snail.hear_range = 0.0
	await frames(30)
	put_boy(snail.global_position + way * 0.6)
	var drawing := await wait(1.0, func() -> bool: return snail.mode == MazeSnail.Mode.DRAWING)
	check("touching its head, he is drawn in", drawing and caught_by.is_empty(), "(%s)" % mode_name(snail))
	check("held while it lasts", boy.process_mode == Node.PROCESS_MODE_DISABLED)
	var took := [0]
	var got := await wait(3.0, func() -> bool:
		took[0] += 1
		return not caught_by.is_empty())
	check("then caught", got and caught_by[0][0] == boy, "(after %.1f s)" % (took[0] / 60.0))
	check("not before HOLD", took[0] / 60.0 > MazeSnail.HOLD * 0.7)
	check("and let go", boy.process_mode != Node.PROCESS_MODE_DISABLED)
	await clear()

	# --- Up on a wall top, out of its reach: it climbs the wall after him ---
	# (a wall along the hall between it and another passage of the ring: not the edge of the maze)
	var cell: Vector2i = hall + step
	var across := Vector2i(-step.y, step.x)
	var found := false
	for lair: Vector2i in nav.lairs(3):
		for side: Vector2i in Maze.STEPS:
			var top: Vector3 = maze.world(lair) + Vector3(side.x, 0.0, side.y) * (Maze.CELL * 0.5)
			if maze.blocked(lair, side) and maze.inside(lair + side) and not maze.ring_wall(lair, side) and not maze.blocked(lair, -side) and _top_at(top, maze.wall_height(lair, side)):
				cell = lair
				across = side
				found = true
				break
		if found:
			break
	check("a wall top to stand on", found)
	var out := Vector3(across.x, 0.0, across.y)
	var top_height: float = maze.wall_height(cell, across)
	var perch: Vector3 = maze.world(cell) + out * (Maze.CELL * 0.5) + Vector3.UP * (top_height + 0.05)
	put_boy(perch)
	await frames(30)
	var stood: bool = boy.is_on_floor() and absf(boy.global_position.y - top_height) < 1.0
	check("he stands on the wall top", stood, "(%.1f m up, wall %.1f)" % [boy.global_position.y, top_height])
	snail = snail_at(maze.world(cell) - out * 5.0, atan2(-out.z, out.x))
	snail.memory = 600.0
	snail.climb_speed = 6.0
	await frames(5)
	snail.notice(boy)
	var on_wall := await wait(20.0, func() -> bool: return absf(snail.up.y) < 0.3)
	check("it goes for the wall under him and up it", on_wall and snail.climbing, "(up %s, %s)" % [snail.up, mode_name(snail)])
	var rose := await wait(30.0, func() -> bool: return snail.global_position.y > top_height * 0.5)
	check("on up the face", rose, "(%.1f m up)" % snail.global_position.y)
	var topped := await wait(30.0, func() -> bool: return snail.up.y > 0.8 and snail.global_position.y > top_height - 1.0 or not caught_by.is_empty())
	check("and over onto the top", topped, "(%.1f m up, up %s)" % [snail.global_position.y, snail.up])
	var caught_up := await wait(20.0, func() -> bool: return not caught_by.is_empty())
	check("where it catches him", caught_up, "(%.1f m from him)" % snail.global_position.distance_to(boy.global_position))
	check("its slime lies up the wall", snail.creature.slime.patches() > 20)

	# --- Lost, it pulls into its shell, comes out, and comes down ---
	# (after him again, far off now, then he is gone)
	await wait(MazeSnail.HOLD + 0.5)
	put_boy(maze.world(far_cell))
	snail._spared.clear()
	snail.notice(boy)
	await frames(3)
	snail.quarry = null
	snail._forget = 0.0
	snail.memory = 1.0
	var pulled := await wait(2.0, func() -> bool: return snail.mode == MazeSnail.Mode.WITHDRAWN)
	check("lost, it pulls into its shell", pulled and snail.creature.withdrawn, "(%s)" % mode_name(snail))
	var out_again := await wait(snail.withdraw_time + 4.0, func() -> bool: return snail.mode in [MazeSnail.Mode.CRAWLING, MazeSnail.Mode.CLIMBING])
	check("and comes out again", out_again and not snail.creature.withdrawn, "(%s)" % mode_name(snail))
	var down := await wait(40.0, func() -> bool: return snail._on_floor())
	check("and comes back down", down, "(%.1f m up)" % snail.global_position.y)
	await clear()

	# --- Bumped by another creature, it pulls in ---
	snail = snail_at(start, atan2(way.x, way.z))
	snail.sight_range = 0.0
	put_boy(maze.world(far_cell))
	await frames(30)
	var other := MazeBoar.new()
	other.maze = maze
	other.sight_range = 0.0
	other.smell_range = Vector2.ZERO
	other.position = snail.creature.shell_point() + Vector3(-way.z, 0.0, way.x) * 1.2
	other.position.y = 0.05
	stage.add_child(other)
	var bumped := await wait(2.0, func() -> bool: return snail.mode == MazeSnail.Mode.WITHDRAWN)
	check("bumped by another creature, it pulls in", bumped, "(%s)" % mode_name(snail))
	await clear()

	# --- A puppet follows the host (up a wall too), and pulls in when it does ---
	put_boy(perch)
	await frames(20)
	var host := snail_at(maze.world(cell) - out * 5.0, atan2(-out.z, out.x))
	host.memory = 600.0
	host.climb_speed = 6.0
	var copy := MazeSnail.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	await frames(5)
	host.notice(boy)
	var furthest := 0.0
	var off_frames := 0
	var counted := 0
	var copy_in := false
	for i in 900:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
			counted += 1
			if copy.up.dot(host.up) < 0.5:
				off_frames += 1
		if i == 600:
			host._withdraw(2.0)
		if i > 610:
			copy_in = copy_in or copy.creature.withdrawn
		if not caught_by.is_empty():
			break
	check("the puppet keeps up with the host", furthest < 3.0, "(at most %.2f m off)" % furthest)
	check("on the same surface (but for a moment at an edge)", off_frames < counted * 0.1, "(%d of %d frames off)" % [off_frames, counted])
	check("the puppet climbed too", copy.global_position.y > 3.0 or not caught_by.is_empty(), "(%.1f m up)" % copy.global_position.y)
	check("the puppet pulls in when the host does", copy_in or not caught_by.is_empty())
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	# --- Its sounds are made ---
	check("its sounds are made", Snail.slither_sound().data.size() > 1000 and Snail.squelch_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


## How fast the boy runs (m/s, over two seconds) from `at`, pushing the stick
## forward (the camera behind him looking along `run_way`), laying a fresh
## stretch of slime that way first if `snail` is given.
func _run_speed(at: Vector3, run_way: Vector3, snail: MazeSnail) -> float:
	camera.global_position = at - run_way * 6.0 + Vector3.UP * 3.0
	camera.look_at(at + run_way * 10.0, Vector3.UP)
	if snail:
		var slime: SnailSlime = snail.creature.slime
		slime.cut()
		var lay_from := at - run_way * 2.0
		for k in 30:
			var point := lay_from + run_way * (k * 0.6)
			slime.lay(Transform3D(Basis(Vector3.UP, atan2(run_way.x, run_way.z)), point), 3.0)
	put_boy(at)
	await frames(20)
	boy.takes_input = true
	Input.action_press(&"move_up")
	await frames(30)
	var from: Vector3 = boy.global_position
	await frames(120)
	var gone: Vector3 = boy.global_position - from
	Input.action_release(&"move_up")
	boy.takes_input = false
	await frames(20)
	return Vector2(gone.x, gone.z).length() / 2.0


## Whether there is a wall top `high` up at `point` (its x and z) to stand on.
func _top_at(point: Vector3, high: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, high + 20.0, point.z), Vector3(point.x, 0.5, point.z))
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and absf((hit.position as Vector3).y - high) < 0.6
