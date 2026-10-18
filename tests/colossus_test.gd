extends SceneTree
## The colossus (scripts/enemies/maze_colossus.gd, and its look and motion in
## creatures/colossus/), headless, in a bare scene: a maze from MazeBuilder and
## the boy in it. In turn: it crouches with every hand and foot on a wall top
## of its ring; with nobody about it crawls on over the walls, every hand and
## foot coming down on a wall top in its ring, never over the clearing; it sees
## the boy out in the open and not at the foot of a wall; it presses its finger
## down at him in the open (its shadow on him first) and catches him; the finger
## stands in the hall to bump into; when he gets to the foot of a wall it misses,
## tries again, and gives up and crawls on; running near a hand or foot makes it
## stop and peer about; a puppet follows the host's hands and feet; and beside
## the great wall round the clearing it rears up to look over it.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/colossus_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Player
var failures := 0
var caught_by: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


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
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func spawn(cell: Vector2i, yaw: float, as_puppet := false) -> MazeColossus:
	var giant := MazeColossus.new()
	giant.maze = maze
	giant.puppet = as_puppet
	giant.seed_choices(5)
	giant.position = maze.world(cell) + Vector3.UP * 0.05
	giant.rotation.y = yaw
	stage.add_child(giant)
	giant.caught.connect(func(who: Node3D) -> void: caught_by.append([who, giant]))
	return giant


## Whether a point is one of its wall tops.
func on_a_top(giant: MazeColossus, point: Vector3) -> bool:
	var top := giant.nearest_top(point, 5.0)
	return top.is_finite() and top.distance_to(point) < 0.1


## The point at the foot of the nearest wall to `at` (`off` metres from its face), on the floor.
func wall_foot(giant: MazeColossus, at: Vector3, off := 0.5) -> Vector3:
	for r in range(1, 60):
		for k in 24:
			var a := TAU * k / 24.0
			var p := at + Vector3(cos(a), 0.0, sin(a)) * float(r) * 0.5
			if giant.clear_of_walls(p, off) and not giant.clear_of_walls(p, off + 0.5) and maze.ring_of(maze.cell_at(p)) == 1:
				return p
	return Vector3.INF


## A point on the floor in the open, `distance` metres ahead of it (or as near as can be), seen from its eyes.
func open_ahead(giant: MazeColossus, distance: float) -> Vector3:
	var middle := giant.figure.pelvis()
	var yaw := giant.figure.body_yaw()
	for spread: float in [0.0, 0.2, -0.2, 0.4, -0.4, 0.6, -0.6, 0.8, -0.8]:
		for extra: float in [0.0, 6.0, -6.0, 12.0, -12.0, 18.0]:
			var p := middle + Basis(Vector3.UP, yaw + spread).z * (distance + extra)
			p.y = 0.0
			if maze.ring_of(maze.cell_at(p)) == 1 and giant.clear_of_walls(p, MazeColossus.FINGER_MARGIN + 1.5):
				put_boy(p)
				if not giant.hidden(boy, giant.figure.eye()):
					return p
	return Vector3.INF


func _run() -> void:
	await wait(0.2)
	# A cell out in the first ring, well away from the clearing.
	var start := Vector2i(-1, -1)
	for cell: Vector2i in nav.lairs(4):
		if maze.ring_of(cell) == 1 and maze.depth_in_ring(cell) >= maze.rampart(1) + 3:
			start = cell
			break
	check("a place in the first ring", start.x >= 0)

	# --- Crouched on the walls, and crawling over them with nobody about ---
	var giant := spawn(start, 0.0)
	await wait(0.5)
	var ok_limbs := true
	for limb in 4:
		ok_limbs = ok_limbs and on_a_top(giant, giant.figure.landing(limb))
	check("every hand and foot on a wall top of its ring", ok_limbs and giant.ring == 1 and giant.tops.size() > 100, "(%d wall tops)" % giant.tops.size())
	var falls: Array = []
	var bad: Array = []
	giant.figure.planted.connect(func(_limb: int, point: Vector3) -> void:
		falls.append(point)
		if not on_a_top(giant, point) or maze.ring_of(maze.cell_at(point)) != 1:
			bad.append(point))
	var from := giant.figure.pelvis()
	var over_clearing := false
	var debris := false
	for i in 60 * 45:
		await physics_frame
		if maze.in_clearing(maze.cell_at(giant.figure.pelvis())):
			over_clearing = true
		for rain in giant.figure._debris:
			debris = debris or rain.emitting
	var went := giant.figure.pelvis().distance_to(from)
	check("with nobody about it crawls on over the walls", falls.size() >= 6 and went > 25.0, "(%d moves, %.0f m in 45 s)" % [falls.size(), went])
	check("every hand and foot comes down on a wall top in its ring", bad.is_empty() and not falls.is_empty(), "(%d of %d wrong)" % [bad.size(), falls.size()])
	check("never over the clearing", not over_clearing)
	check("stones rain down where a hand or foot comes down", debris)

	# --- Seeing from above (it holds still from now on, but for its finger) ---
	boy.add_to_group(&"maze_players")
	await wait(8.0, func() -> bool: return giant.figure.stepping() < 0)
	giant._pause = 1e9
	giant.process_mode = Node.PROCESS_MODE_DISABLED
	var open := open_ahead(giant, 70.0)
	await wait(0.2)
	check("it sees him out in the open", open.is_finite() and not giant.hidden(boy, giant.figure.eye()), "(%.0f m off)" % Vector2(open.x - giant.figure.pelvis().x, open.z - giant.figure.pelvis().z).length() if open.is_finite() else "")
	var foot_of := wall_foot(giant, open, 0.4)
	put_boy(foot_of)
	await wait(0.2)
	check("it does not see him at the foot of a wall", foot_of.is_finite() and giant.hidden(boy, giant.figure.eye()))

	# --- The finger: caught in the open ---
	giant.process_mode = Node.PROCESS_MODE_INHERIT
	giant._press_in = 0.0
	caught_by.clear()
	put_boy(open)
	var pressing := await wait(8.0, func() -> bool: return giant.mode == MazeColossus.Mode.PRESSING)
	check("it reaches its finger out over him", pressing)
	var hovering := await wait(10.0, func() -> bool: return giant.figure.press_stage() == Colossus.Press.HOVER)
	check("its fingertip's shadow on him, it peering down", hovering and giant.figure._tip_blot.visible and giant.figure.stoop > 0.5)
	var down := await wait(12.0, func() -> bool: return giant.figure.press_stage() == Colossus.Press.PRESS)
	var space := stage.get_world_3d().direct_space_state
	var tip := giant.figure.fingertip()
	var across := giant.figure.press_along.cross(Vector3.UP)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(tip + across * 6.0 + Vector3.UP * 4.0, tip - across * 6.0 + Vector3.UP * 4.0, 1))
	check("the finger comes down into the hall, to bump into", down and tip.y < 2.0 and not hit.is_empty() and hit["collider"] == giant._finger_body, "(the tip %.1f m up)" % tip.y)
	await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("under the fingertip as it presses, he is caught", not caught_by.is_empty())
	giant.figure.release()
	await wait(15.0, func() -> bool: return giant.mode != MazeColossus.Mode.PRESSING)
	giant._pause = 1e9

	# --- The finger: missed at the foot of a wall; it tries again, gives up ---
	caught_by.clear()
	giant._press_in = 0.0
	giant._spared.clear()
	put_boy(open)
	await wait(8.0, func() -> bool: return giant.mode == MazeColossus.Mode.PRESSING)
	await wait(12.0, func() -> bool: return giant.figure.press_stage() == Colossus.Press.DESCEND)
	put_boy(foot_of)
	var lifted := await wait(15.0, func() -> bool: return giant.figure.press_stage() == Colossus.Press.LIFT)
	check("at the foot of a wall the finger misses him", lifted and caught_by.is_empty())
	var gave_up := await wait(40.0, func() -> bool: return giant.mode == MazeColossus.Mode.CRAWLING)
	check("and it gives up and crawls on", gave_up and caught_by.is_empty() and not giant.figure.pressing())
	giant._pause = 1e9

	# --- Feeling the walls shake ---
	put_boy(Vector3(0, -500, 0))
	giant.sense_range = 0.0
	await wait(3.0)
	var planted := giant.figure.landing(Colossus.FOOT_L)
	var run_from := wall_foot(giant, Vector3(planted.x, 0.0, planted.z), 0.6)
	var listened := false
	if run_from.is_finite():
		for i in 90:
			put_boy(run_from + Vector3(i * 0.1 - 4.5, 0.0, 0.0) if giant.clear_of_walls(run_from + Vector3(i * 0.1 - 4.5, 0.0, 0.0), 0.3) else run_from + Vector3(0.0, 0.0, i * 0.1 - 4.5))
			await physics_frame
			if giant.mode == MazeColossus.Mode.LISTENING:
				listened = true
				break
	check("running near a hand or foot makes it stop and peer about", listened)

	# --- A puppet follows the host's hands and feet ---
	put_boy(Vector3(0, -500, 0))
	giant.mode = MazeColossus.Mode.CRAWLING
	giant._pause = 0.0
	var copy := spawn(maze.cell_at(giant.global_position), giant.figure.body_yaw(), true)
	await wait(0.2)
	for limb in 4:
		copy.figure.plant(limb, giant.figure.landing(limb), giant.figure.landing_yaw(limb))
	var steps_before: int = giant._steps
	for i in 60 * 16:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(giant.state_bytes())
	await wait(8.0, func() -> bool: return giant.figure.stepping() < 0 and copy.figure.stepping() < 0)
	var apart := 0.0
	for limb in 4:
		apart = maxf(apart, giant.figure.landing(limb).distance_to(copy.figure.landing(limb)))
	check("a puppet follows the host's hands and feet", giant._steps > steps_before and apart < 1.0, "(%d moves, %.2f m apart at most)" % [giant._steps - steps_before, apart])
	copy.queue_free()
	giant.queue_free()

	# --- Looking over the great wall ---
	var rampart_cell := Vector2i(-1, -1)
	var best := INF
	for c: Vector2i in nav.lairs(1):
		if maze.ring_of(c) == 1 and maze.depth_in_ring(c) == maze.rampart(1) + 1:
			var at := maze.world(c)
			var across_side := minf(absf(at.x), absf(at.z))
			if across_side > 60.0 and across_side < best:
				best = across_side
				rampart_cell = c
	var peer := spawn(rampart_cell, 0.0)
	peer.sense_range = 0.0
	await wait(0.5)
	peer._pause = 1e9
	var peering: bool = peer._start_peering()
	await wait(10.0)
	var over: float = peer.figure.eye().y - maze.inner_height(1)
	check("beside the great wall it rears up to look over it", peering and peer.mode == MazeColossus.Mode.PEERING and over > 15.0, "(its eyes %.0f m over the top)" % over)
	await wait(peer.peer_time)
	check("and gets down again", peer.mode == MazeColossus.Mode.CRAWLING and peer.figure.lean_on == Vector3.INF)
	_end()


func _end() -> void:
	print("COLOSSUS TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
