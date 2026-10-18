extends SceneTree
## The angel (scripts/enemies/maze_angel.gd), headless, in a bare maze from
## MazeBuilder: it hangs well over the floor; a boy standing in its sight is
## gazed at (every eye on him, the wheels stopped, the wings parted), and taken
## up and caught when the gaze is full; someone who steps out of its sight before
## then is let go as the gaze falls away; there is no getting past behind it; ivy
## is cover; it drifts no faster than a walk; a puppet follows its host's news,
## the taking and all.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/angel_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## Someone to hunt that the test moves itself.
class Walker extends Node3D:
	var velocity := Vector3.ZERO
	var facing_yaw := 0.0

var stage: Node3D
var maze
var nav
var boy
var walker: Walker
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
	walker = Walker.new()
	walker.name = "Walker"
	stage.add_child(walker)
	_run.call_deferred()


func angel_at(cell: Vector2i, targets: Array, yaw := 0.0) -> MazeAngel:
	var angel := MazeAngel.new()
	angel.maze = maze
	angel.targets = targets
	angel.position = maze.world(cell) + Vector3.UP * 0.05
	angel.rotation.y = yaw
	stage.add_child(angel)
	angel.caught.connect(func(who: Node3D) -> void: caught_by.append([who, angel]))
	return angel


func clear() -> void:
	for child in stage.get_children():
		if child is MazeAngel:
			child.queue_free()
	caught_by.clear()


## A cell `steps` cells on in a straight line from `from` (open all the way), and its step, or none.
func straight_from(from: Vector2i, steps: int) -> Array:
	for step: Vector2i in Maze.STEPS:
		var ok := true
		for k in steps:
			if maze.blocked(from + step * k, step) or not nav.allowed(from + step * (k + 1)):
				ok = false
				break
		if ok:
			return [from + step * steps, step]
	return []


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	# A cell with a straight run of two cells from it (28 m), for the angel and the boy.
	var home := Vector2i(-1, -1)
	var run := []
	for cell: Vector2i in lairs:
		run = straight_from(cell, 2)
		if not run.is_empty() and nav.allowed(cell - (run[1] as Vector2i)) and not maze.blocked(cell, -(run[1] as Vector2i)):
			home = cell
			break
	check("a straight hall to test in", home.x >= 0)
	var far_cell: Vector2i = run[0]
	var step: Vector2i = run[1]

	# --- It hangs over the floor; everyone passes under it ---
	boy.global_position = maze.world(far_cell) + Vector3.UP * 0.1
	await frames(20)
	var angel := angel_at(home, [boy], atan2(float(step.x), float(step.y)))
	angel.drift_speed = 0.0
	angel.wander_speed = 0.0
	await frames(5)
	var heart_up: float = angel.body().global_position.y - angel.global_position.y
	check("its heart hangs high over the floor", heart_up > 5.0, "(%.1f m up)" % heart_up)
	check("nobody bumps into it", angel.collision_layer == 0)

	# --- A boy standing in its sight is gazed at, and taken ---
	var took := [0.0, false, false, 0.0, 1.0, 0.0]
	var start_ms := Time.get_ticks_msec()
	var got := await wait(20.0, func() -> bool:
		var g: float = angel.gaze_on(boy)
		if g > 0.5 and not took[1]:
			took[1] = true
			took[3] = angel.body().eyes_on(boy.global_position + Vector3.UP * 1.2, 0.25)
		if g > 0.95:
			took[4] = minf(took[4], angel.body().turning())
			took[5] = maxf(took[5], angel.body().parted())
		if angel.mode == MazeAngel.Mode.TAKING and not took[2]:
			took[2] = true
			took[0] = float(Engine.get_physics_frames())
		return not caught_by.is_empty())
	var seconds := float(Time.get_ticks_msec() - start_ms) / 1000.0
	check("a boy standing in its sight is taken", got and caught_by[0][0] == boy, "(after %.1f s; gaze_time %.1f)" % [seconds, angel.gaze_time])
	check("its eyes turn to him as it gazes (all that can: the far side of a wheel cannot)", took[3] > 0.15, "(%.0f%% of them on him)" % (took[3] * 100.0))
	check("its wheels stand still and its face wings part when the gaze is full", took[4] < 0.05 and took[5] > 0.6, "(turning %.2f, parted %.2f)" % [took[4], took[5]])
	check("he is drawn up before he is caught", took[2])
	await frames(2)
	check("and let go after", boy.get_node_or_null(^"AngelTaken") == null and boy.takes_input == false, "")
	clear()
	await frames(2)

	# --- Out of its sight before the gaze is full, he is let go ---
	walker.global_position = maze.world(far_cell)
	angel = angel_at(home, [walker])
	angel.drift_speed = 0.0
	angel.wander_speed = 0.0
	await wait(10.0, func() -> bool: return angel.gaze_on(walker) > 0.6)
	var built: float = angel.gaze_on(walker)
	# (round a corner: a cell near by that it cannot see)
	var hidden := Vector2i(-1, -1)
	var field: PackedInt32Array = nav.field(far_cell)
	for i in field.size():
		var cell := Vector2i(i % maze.size, i / maze.size)
		if field[i] >= 1 and field[i] <= 4 and nav.allowed(cell) and not nav.sees(angel.heart(), maze.world(cell) + Vector3.UP, 1000.0):
			hidden = cell
			break
	check("somewhere round a corner", hidden.x >= 0)
	walker.global_position = maze.world(hidden)
	var fell := await wait(4.0, func() -> bool: return angel.gaze <= 0.0)
	check("stepping out of its sight lets the gaze fall away", built > 0.55 and fell and caught_by.is_empty(), "(it had built to %.2f)" % built)
	await wait(3.0)
	check("and he is not taken", caught_by.is_empty() and angel.mode != MazeAngel.Mode.TAKING)
	clear()
	await frames(2)

	# --- No getting past behind it ---
	var behind := home - step * 1
	walker.global_position = maze.world(behind)
	angel = angel_at(home, [walker], atan2(float(step.x), float(step.y)))
	angel.drift_speed = 0.0
	angel.wander_speed = 0.0
	var seen_behind := await wait(6.0, func() -> bool: return angel.gaze_on(walker) > 0.3)
	check("it sees behind it as well as before it", seen_behind)
	clear()
	await frames(2)

	# --- Ivy is cover ---
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	var was = boy.state
	boy.state = Player.State.LADDER
	check("on the ivy he is in cover", MazeAngel.in_cover(boy))
	boy.state = was
	check("off it he is not", not MazeAngel.in_cover(boy))
	boy.process_mode = Node.PROCESS_MODE_INHERIT

	# --- It drifts, slowly ---
	walker.global_position = maze.world(lairs[0])
	angel = angel_at(far_cell, [walker])
	var top := [0.0, 0.0]
	var from: Vector3 = angel.global_position
	await wait(20.0, func() -> bool:
		top[0] = maxf(top[0], Vector2(angel.velocity.x, angel.velocity.z).length())
		top[1] = maxf(top[1], angel.wall_push(angel.global_position, 3.4).length())
		return false)
	check("it drifts about, slower than a walk", top[0] > 0.2 and top[0] <= angel.drift_speed + 0.05 and angel.global_position.distance_to(from) > 0.5, "(%.2f m/s at most; %.1f m from where it was put)" % [top[0], angel.global_position.distance_to(from)])
	check("keeping its wheels out of the walls", top[1] < 0.6, "(at worst %.2f m too near)" % top[1])
	clear()
	await frames(2)

	# --- A puppet follows its host, the taking and all ---
	walker.global_position = maze.world(far_cell)
	var host := angel_at(home, [walker])
	host.drift_speed = 0.0
	host.wander_speed = 0.0
	host.gaze_time = 2.0
	var copy := MazeAngel.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	var copy_modes := {}
	var host_modes := {}
	var worst := 0.0
	var gaze_seen := 0.0
	for i in 60 * 6:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		host_modes[host.mode] = true
		copy_modes[copy.mode] = true
		gaze_seen = maxf(gaze_seen, copy.gaze)
		worst = maxf(worst, copy.global_position.distance_to(host.global_position))
	check("a puppet angel follows its host", worst < 2.5, "(at worst %.2f m off)" % worst)
	check("and gazes and takes as it does", host_modes.has(MazeAngel.Mode.TAKING) and copy_modes.has(MazeAngel.Mode.TAKING) and gaze_seen > 0.8,
		"(host %s; puppet %s; its gaze up to %.2f)" % [host_modes.keys(), copy_modes.keys(), gaze_seen])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, host.state_bytes().size() == MazeEnemy.STATE_SIZE)
	var meshes := 0
	for node in host.body().find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).is_visible_in_tree():
			meshes += 1
	check("it is a handful of draws", meshes <= 10, "(%d showing)" % meshes)
	clear()
	await frames(5)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
