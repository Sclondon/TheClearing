extends SceneTree
## The colossus (scripts/enemies/maze_colossus.gd, and its look and motion in
## creatures/colossus/), headless, in a bare scene: a maze from MazeBuilder and
## the boy in it. In turn: it stands on footholds in its ring; with nobody about
## it walks round the ring over the walls, every foot coming down on a hall's
## floor clear of the walls and none outside its ring; a foot's shadow shows
## before it lands; whoever is under a foot when it lands is caught, and whoever
## is at the foot of a wall beside it is not; its legs block a hall; it sees the
## boy out in the open and not at the foot of a wall; it reaches for him in the
## open and catches him, and misses him when he gets to the foot of a wall;
## running near its feet makes it stop and look; a puppet follows the host's
## steps; and beside the great wall round the clearing it hauls itself up to
## look over it.
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


## The point at the foot of the nearest wall to `at` (`off` metres from its face), on the floor.
func wall_foot(giant: MazeColossus, at: Vector3, off := 0.5) -> Vector3:
	var best := Vector3.INF
	for r in range(1, 40):
		for k in 24:
			var a := TAU * k / 24.0
			var p := at + Vector3(cos(a), 0.0, sin(a)) * float(r) * 0.5
			if giant.clear_of_walls(p, off) and not giant.clear_of_walls(p, off + 0.5) and maze.ring_of(maze.cell_at(p)) == 1:
				return p
	return best


## A point on the floor in the open `distance` metres in front of it (or as near as can be).
func open_ahead(giant: MazeColossus, distance: float) -> Vector3:
	var middle := giant.figure.pelvis()
	var yaw := giant.figure.body_yaw()
	for spread: float in [0.0, 0.2, -0.2, 0.4, -0.4, 0.6, -0.6]:
		for extra: float in [0.0, 4.0, -4.0, 8.0, -8.0]:
			var p := middle + Basis(Vector3.UP, yaw + spread).z * (distance + extra)
			p.y = 0.0
			if giant._floor(p, MazeColossus.HAND_MARGIN + 1.5):
				return p
	return Vector3.INF


func _run() -> void:
	await wait(0.2)
	# A hall cell deep in the ring, far from the clearing.
	var start := Vector2i(-1, -1)
	for cell: Vector2i in nav.lairs(4):
		if maze.ring_of(cell) == 1:
			start = cell
			break
	check("a place in the first ring", start.x >= 0)

	# --- Standing, and walking round the ring with nobody about ---
	var giant := spawn(start, 0.0)
	await wait(0.5)
	var ok_feet := true
	for foot in 2:
		ok_feet = ok_feet and giant.foothold(giant.figure.landing(foot), giant.figure.landing_yaw(foot))
	check("it stands on footholds in its ring", ok_feet and giant.ring == 1)
	var falls: Array = []
	var bad: Array = []
	var over_walls := [0]
	giant.figure.footfall.connect(func(foot: int, point: Vector3) -> void:
		falls.append(point)
		if not giant.foothold(point, giant.figure.landing_yaw(foot)) or maze.ring_of(maze.cell_at(point)) != 1:
			bad.append(point))
	giant.figure.lifted.connect(func(foot: int, to: Vector3) -> void:
		if giant.clearance(giant.figure._swing_from, to) > 20.0:
			over_walls[0] += 1)
	var from := giant.figure.pelvis()
	var in_clearing := [false]
	var shadow_seen := [false]
	for i in 60 * 50:
		await physics_frame
		if maze.in_clearing(maze.cell_at(giant.figure.pelvis())):
			in_clearing[0] = true
		var foot := giant.figure.stepping()
		if foot >= 0 and giant.figure.step_progress() > 0.7 and giant.figure._blots[foot].visible:
			shadow_seen[0] = true
	var went := giant.figure.pelvis().distance_to(from)
	check("with nobody about it walks round the ring", falls.size() >= 8 and went > 60.0, "(%d steps, %.0f m in 50 s)" % [falls.size(), went])
	check("every foot comes down on a hall's floor, clear of the walls, in its ring", bad.is_empty() and not falls.is_empty(), "(%d of %d wrong)" % [bad.size(), falls.size()])
	check("it steps over walls", over_walls[0] > 0, "(%d times)" % over_walls[0])
	check("it never comes into the clearing", not in_clearing[0])
	check("a foot's shadow shows where it will come down", shadow_seen[0])

	# --- Crushed under a foot; safe at the foot of a wall ---
	boy.add_to_group(&"maze_players")
	giant.sense_range = 0.0
	caught_by.clear()
	var target := [Vector3.INF]
	var put_under := func(foot: int, to: Vector3) -> void:
		if not target[0].is_finite():
			target[0] = to
			put_boy(to + Basis(Vector3.UP, giant.figure.landing_yaw(foot)).z * 2.0)
	giant.figure.lifted.connect(put_under)
	await wait(12.0, func() -> bool: return target[0].is_finite())
	await wait(10.0, func() -> bool: return not caught_by.is_empty())
	check("whoever is under a foot when it comes down is caught", not caught_by.is_empty())
	giant.figure.lifted.disconnect(put_under)
	await wait(5.0)
	caught_by.clear()
	target[0] = Vector3.INF
	var by_wall := [Vector3.INF]
	var put_beside := func(_foot: int, to: Vector3) -> void:
		if not target[0].is_finite():
			target[0] = to
			by_wall[0] = wall_foot(giant, to, 0.4)
			if by_wall[0].is_finite():
				put_boy(by_wall[0])
	giant.figure.lifted.connect(put_beside)
	await wait(12.0, func() -> bool: return target[0].is_finite())
	await wait(giant.figure.step_length() + 1.0)
	check("whoever is at the foot of a wall beside it is not", caught_by.is_empty() and by_wall[0].is_finite(), "(%.1f m from where the foot came down)" % Vector2(by_wall[0].x - target[0].x, by_wall[0].z - target[0].z).length() if by_wall[0].is_finite() else "")
	giant.figure.lifted.disconnect(put_beside)

	# --- Its legs block the hall ---
	await wait(8.0, func() -> bool: return giant.figure.stepping() < 0)
	var foot_at := giant.figure.landing(0)
	var space := stage.get_world_3d().direct_space_state
	var across := Basis(Vector3.UP, giant.figure.landing_yaw(0)).x
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot_at + across * 14.0 + Vector3.UP * 12.0, foot_at - across * 14.0 + Vector3.UP * 12.0, 1))
	var leg_hit := false
	if not hit.is_empty():
		for body in giant._colliders:
			if hit["collider"] == body:
				leg_hit = true
	check("its legs stand in the hall to bump into", leg_hit)

	# --- Seeing from above (it stands still from now on, but to reach) ---
	await wait(8.0, func() -> bool: return giant.figure.stepping() < 0)
	giant._pause = 1e9
	giant.process_mode = Node.PROCESS_MODE_DISABLED
	var open := open_ahead(giant, giant.figure.height * 0.28)
	put_boy(open)
	await wait(0.2)
	check("it sees him out in the open", open.is_finite() and not giant.hidden(boy, giant.figure.eye()))
	var foot_of := wall_foot(giant, open, 0.4)
	put_boy(foot_of)
	await wait(0.2)
	check("it does not see him at the foot of a wall", foot_of.is_finite() and giant.hidden(boy, giant.figure.eye()))

	# --- Reaching: caught in the open ---
	giant.process_mode = Node.PROCESS_MODE_INHERIT
	giant.sense_range = 110.0
	giant._reach_in = 0.0
	caught_by.clear()
	put_boy(open)
	var reached := await wait(8.0, func() -> bool: return giant.mode == MazeColossus.Mode.REACHING)
	check("it reaches for him in the open", reached, "(%.0f m from its middle)" % Vector2(open.x - giant.figure.pelvis().x, open.z - giant.figure.pelvis().z).length())
	var hovered := await wait(10.0, func() -> bool: return giant.figure.reach_stage() == Colossus.Reach.HOVER)
	check("its hand hovers over him, its shadow on him", hovered and giant.figure._hand_blot.visible)
	await wait(12.0, func() -> bool: return not caught_by.is_empty() or giant.figure.reach_stage() == Colossus.Reach.RISE)
	check("the hand comes down on him", not caught_by.is_empty())
	await wait(15.0, func() -> bool: return giant.mode != MazeColossus.Mode.REACHING)

	# --- Reaching: missed at the foot of a wall ---
	giant._pause = 1e9
	caught_by.clear()
	giant._reach_in = 0.0
	giant._spared.clear()
	put_boy(open)
	await wait(8.0, func() -> bool: return giant.mode == MazeColossus.Mode.REACHING)
	await wait(10.0, func() -> bool: return giant.figure.reach_stage() == Colossus.Reach.HOVER)
	put_boy(foot_of)
	await wait(15.0, func() -> bool: return giant.mode != MazeColossus.Mode.REACHING)
	check("at the foot of a wall the hand misses him", caught_by.is_empty() and giant.mode != MazeColossus.Mode.REACHING)

	# --- Feeling the ground ---
	put_boy(Vector3(0, -500, 0))
	giant.sense_range = 0.0
	await wait(10.0, func() -> bool: return giant.mode == MazeColossus.Mode.WALKING and giant.figure.stepping() < 0)
	var planted := giant.figure.landing(0)
	var run_from := wall_foot(giant, planted, 0.6)
	var listened := false
	if run_from.is_finite():
		var dir := (planted - run_from)
		dir.y = 0.0
		var side := dir.normalized().cross(Vector3.UP)
		for i in 90:
			put_boy(run_from + side * (i * 0.1 - 4.5))
			await physics_frame
			if giant.mode == MazeColossus.Mode.LISTENING:
				listened = true
				break
	check("running near its feet makes it stop and look", listened)

	# --- A puppet follows the host's steps ---
	put_boy(Vector3(0, -500, 0))
	giant.mode = MazeColossus.Mode.WALKING
	var copy := spawn(maze.cell_at(giant.global_position), giant.figure.body_yaw(), true)
	copy.figure.put(giant.figure.pelvis(), giant.figure.body_yaw())
	for foot in 2:
		copy.figure.plant(foot, giant.figure.landing(foot), giant.figure.landing_yaw(foot))
	var steps_before: int = giant._steps
	for i in 60 * 14:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(giant.state_bytes())
	var apart := 0.0
	await wait(8.0, func() -> bool: return giant.figure.stepping() < 0 and copy.figure.stepping() < 0)
	for foot in 2:
		apart = maxf(apart, giant.figure.landing(foot).distance_to(copy.figure.landing(foot)))
	check("a puppet follows the host's steps", giant._steps > steps_before and apart < 1.0, "(%d steps, feet %.2f m apart at most)" % [giant._steps - steps_before, apart])
	copy.queue_free()
	giant.queue_free()

	# --- Looking over the great wall ---
	var rampart_cell := Vector2i(-1, -1)
	var best := INF
	for c: Vector2i in nav.lairs(1):
		if maze.ring_of(c) == 1 and maze.depth_in_ring(c) == maze.styles[0].border_wall_thickness_cells:
			var at := maze.world(c)
			var across_side := minf(absf(at.x), absf(at.z))
			if across_side > 30.0 and across_side < best:
				best = across_side
				rampart_cell = c
	var peer := spawn(rampart_cell, 0.0)
	peer.sense_range = 0.0
	await wait(0.5)
	peer._pause = 1e9
	var peering: bool = peer._start_peering()
	await wait(9.0)
	var over: float = peer.figure.eye().y - maze.styles[0].section_border_wall_height
	check("beside the great wall it hauls itself up to look over it", peering and peer.mode == MazeColossus.Mode.PEERING and over > 10.0, "(its eyes %.0f m over the top)" % over)
	await wait(peer.peer_time)
	check("and gets down again and walks on", peer.mode == MazeColossus.Mode.WALKING and peer.figure.lean_on == Vector3.INF)
	_end()


func _end() -> void:
	print("COLOSSUS TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
