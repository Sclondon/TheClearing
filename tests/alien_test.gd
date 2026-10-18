extends SceneTree
## The aliens (scripts/enemies/alien.gd), headless, in a bare maze from
## MazeBuilder: one notices a boy and walks to him and takes him; one blinks
## into the passage ahead of someone walking away from it, after its warning;
## one that is being looked at does not blink; a reach is dodged by stepping
## aside; two hunt together; a puppet follows its host's news, blinks and all.
##
##     godot --headless --path . -s res://tests/alien_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## Someone to hunt that the test moves itself: where they are going and which way they face.
class Walker extends Node3D:
	var velocity := Vector3.ZERO
	var facing_yaw := 0.0
	var path: Array = []
	var speed := 0.0

	func _physics_process(delta: float) -> void:
		velocity = Vector3.ZERO
		if path.is_empty() or speed <= 0.0:
			return
		var to: Vector3 = path[0] - global_position
		to.y = 0.0
		if to.length() < 0.5:
			path.pop_front()
			return
		velocity = to.normalized() * speed
		global_position += velocity * delta
		facing_yaw = atan2(velocity.x, velocity.z)

var stage: Node3D
var maze
var nav
var boy
var walker: Walker
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


func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


func alien_at(cell: Vector2i, targets: Array, yaw := 0.0) -> Alien:
	var alien := Alien.new()
	alien.maze = maze
	alien.targets = targets
	alien.position = maze.world(cell) + Vector3.UP * 0.05
	alien.rotation.y = yaw
	stage.add_child(alien)
	alien.caught.connect(func(who: Node3D) -> void: caught_by.append([who, alien]))
	return alien


func clear() -> void:
	for child in stage.get_children():
		if child is Alien:
			child.queue_free()
	caught_by.clear()
	walker.path.clear()
	walker.speed = 0.0


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]

	# --- It walks to a boy who stands, and takes him ---
	boy.global_position = maze.world(home) + Vector3.UP * 0.1
	await frames(20)
	var alien := alien_at(cell_from(home, 1), [boy])
	alien.blink_every = 1000.0
	alien.notice(boy)
	var reached := [false]
	var top := [0.0]
	var got := await wait(40.0, func() -> bool:
		if alien.mode == Alien.Mode.REACHING:
			reached[0] = true
		top[0] = maxf(top[0], Vector2(alien.velocity.x, alien.velocity.z).length())
		return not caught_by.is_empty())
	check("an alien walks to a boy who stands and takes him", got and caught_by[0][0] == boy, "(raised its hand: %s; %.1f m off)" % [reached[0], alien.global_position.distance_to(boy.global_position)])
	check("it walks no faster than %.2f m/s" % alien.walk_speed, top[0] <= alien.walk_speed + 0.05 and top[0] > 0.5, "(%.2f at most)" % top[0])
	clear()
	await frames(2)

	# --- It blinks ahead of someone walking away ---
	boy.global_position = maze.world(lairs[0]) + Vector3.UP * 0.1
	var start := cell_from(home, 0)
	var path: Array = []
	var far_cell := cell_from(home, 9)
	for cell: Vector2i in nav.path(home, far_cell):
		path.append(maze.world(cell))
	walker.global_position = maze.world(home)
	walker.path = path.duplicate()
	walker.speed = 2.0
	await frames(2)
	walker.facing_yaw = atan2(walker.velocity.x, walker.velocity.z)
	# (behind them, three cells back the way they came)
	var behind := Vector2i(-1, -1)
	var field: PackedInt32Array = nav.field(home)
	var ahead_field: PackedInt32Array = nav.field(far_cell)
	for i in field.size():
		if field[i] == 3 and ahead_field[i] > ahead_field[maze.index(home)]:
			behind = Vector2i(i % maze.size, i / maze.size)
	alien = alien_at(behind if behind.x >= 0 else start, [walker])
	alien.blink_wait_now()
	alien.notice(walker)
	var warned := [false, Vector3.INF, Vector3.ZERO, 0.0]
	var blinked := await wait(20.0, func() -> bool:
		if alien.mode == Alien.Mode.WARNING and not warned[0]:
			warned[0] = true
			warned[1] = alien.blink_target
			warned[2] = walker.velocity
			warned[3] = alien.global_position.distance_to(walker.global_position)
		if trace and Engine.get_physics_frames() % 60 == 0:
			print("      %s at %s, walker at %s" % [Alien.Mode.keys()[alien.mode], alien.global_position, walker.global_position])
		return alien.mode == Alien.Mode.ARRIVING)
	check("it warns, then blinks, when someone walks off with their back to it", warned[0] and blinked, "(%s)" % Alien.Mode.keys()[alien.mode])
	if warned[0]:
		var off: Vector3 = warned[1] - walker.global_position
		check("the warning is where it comes, ahead of them", (warned[2] as Vector3).dot(warned[1] - (walker.global_position - warned[2] * 1.1)) > 0.0 and alien.global_position.distance_to(warned[1]) < 1.0,
			"(%.1f m from them now; it was %.1f m off before)" % [off.length(), warned[3]])
	await wait(2.0)
	check("it comes on at them after", alien.mode == Alien.Mode.HUNTING or alien.mode == Alien.Mode.REACHING, "(%s)" % Alien.Mode.keys()[alien.mode])
	clear()
	await frames(2)

	# --- Looked at, it does not blink ---
	walker.global_position = maze.world(home)
	var watcher_cell := Vector2i(-1, -1)
	for i in field.size():
		var cell := Vector2i(i % maze.size, i / maze.size)
		if field[i] >= 2 and field[i] <= 4 and nav.allowed(cell) and nav.sees(maze.world(home) + Vector3.UP * 1.4, maze.world(cell) + Vector3.UP * 1.4) and maze.world(cell).distance_to(maze.world(home)) > 14.0:
			watcher_cell = cell
	check("somewhere in sight to stand it", watcher_cell.x >= 0)
	alien = alien_at(watcher_cell, [walker])
	alien.blink_wait_now()
	alien.walk_speed = 0.0
	var facing_it := alien.global_position - walker.global_position
	walker.facing_yaw = atan2(facing_it.x, facing_it.z)
	alien.notice(walker)
	var warnings := [0]
	await wait(8.0, func() -> bool:
		var to := alien.global_position - walker.global_position
		walker.facing_yaw = atan2(to.x, to.z)
		if alien.mode == Alien.Mode.WARNING:
			warnings[0] += 1
		return false)
	check("looked at, it does not blink", warnings[0] == 0, "(%d frames warning)" % warnings[0])
	# Look away: now it does.
	var turned := await wait(8.0, func() -> bool:
		var to := alien.global_position - walker.global_position
		walker.facing_yaw = atan2(-to.x, -to.z)
		return alien.mode == Alien.Mode.WARNING)
	check("looked away from, it does", turned)
	# And turning back during the warning calls it off.
	var called_off := await wait(3.0, func() -> bool:
		var to := alien.global_position - walker.global_position
		walker.facing_yaw = atan2(to.x, to.z)
		return alien.mode != Alien.Mode.WARNING)
	check("turning back to it calls the blink off", called_off and alien.mode != Alien.Mode.GONE and alien.mode != Alien.Mode.ARRIVING, "(%s)" % Alien.Mode.keys()[alien.mode])
	clear()
	await frames(2)

	# --- A reach dodged ---
	walker.global_position = maze.world(home)
	alien = alien_at(home, [walker])
	alien.blink_every = 1000.0
	alien.global_position = maze.world(home) + Vector3(0.0, 0.05, -2.0)
	alien.notice(walker)
	await wait(3.0, func() -> bool: return alien.mode == Alien.Mode.REACHING)
	await wait(0.3)
	# (a quick step to one side as the hand comes up)
	var side := Vector3(1.0, 0.0, 0.0) if nav.clear_of_walls(walker.global_position + Vector3(4.0, 0.0, 0.0), 0.5) else Vector3(-1.0, 0.0, 0.0)
	walker.path = [walker.global_position + side * 6.0]
	walker.speed = 4.0
	await wait(1.6)
	check("stepping aside from its raised hand, it misses", caught_by.is_empty(), "(%d caught)" % caught_by.size())
	clear()
	await frames(2)

	# --- Two together, and a puppet ---
	walker.global_position = maze.world(home)
	var first := alien_at(cell_from(home, 2), [walker])
	var second := alien_at(cell_from(home, 3), [walker])
	first.notice(walker)
	await frames(30)
	check("one that notices someone tells the other", second.hunting(), "(second after %s)" % second.quarry)
	var copy := Alien.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = first.position
	stage.add_child(copy)
	var worst := 0.0
	var copy_modes := {}
	var host_modes := {}
	first.blink_every = 2.0
	walker.path = path.duplicate()
	walker.speed = 1.6
	for i in 60 * 16:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(first.state_bytes())
		host_modes[first.mode] = true
		copy_modes[copy.mode] = true
		if i > 30 and first.mode != Alien.Mode.GONE and first.mode != Alien.Mode.ARRIVING:
			worst = maxf(worst, copy.global_position.distance_to(first.global_position))
	var named := func(modes: Dictionary) -> String:
		var names := PackedStringArray()
		for m: int in modes:
			names.append(Alien.Mode.keys()[m])
		return ",".join(names)
	check("a puppet alien follows its host", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("and does what it does", host_modes.keys().all(func(m: int) -> bool: return copy_modes.has(m)), "(host %s; puppet %s)" % [named.call(host_modes), named.call(copy_modes)])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, first.state_bytes().size() == MazeEnemy.STATE_SIZE)
	var meshes := 0
	for node in first.body().find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).is_visible_in_tree():
			meshes += 1
	check("it is one draw (and its lights only while they show)", meshes <= 3, "(%d meshes showing)" % meshes)
	clear()
	await frames(5)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
