extends SceneTree
## The fish person (MazeFishPerson, driving creatures/fish_person's FishPerson),
## headless, in a bare maze from MazeBuilder: it lurks sunk in its pool with
## nobody about; someone walking past in sight does not bring it up, but
## someone running does, and so does someone stepping into its pool; it rises,
## croaks, and its croak brings up another one near enough; it lopes at
## someone in sight and lunges and catches them standing still; someone who
## sprints away gets away; it goes back to its pool and sinks into it again; a
## puppet copy follows the host's news, rising and croaking when it does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/fish_person_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO


var stage: Node3D
var maze
var nav
var failures := 0
var caught: Array = []
var lair := Vector2i.ZERO
var out := Vector3.ZERO


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
	_run.call_deferred()


## A cell with a straight passage of at least `run` cells out of it, and the way out.
func find_hall(run: int) -> void:
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(cell + step * k, step) or not nav.allowed(cell + step * (k + 1)):
					ok = false
			if ok:
				lair = cell
				out = Vector3(step.x, 0.0, step.y)
				return


func dummy(at: Vector3, facing: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.facing_yaw = atan2(facing.x, facing.z)
	d.add_to_group(&"maze_players")
	return d


func fish_at(at: Vector3) -> MazeFishPerson:
	var f := MazeFishPerson.new()
	f.maze = maze
	f.position = at + Vector3.UP * 0.05
	f.rotation.y = atan2(out.x, out.z)
	stage.add_child(f)
	f.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return f


func clear() -> void:
	for child in stage.get_children():
		if child is MazeFishPerson or child is Dummy:
			child.free()
	caught.clear()


func _run() -> void:
	find_hall(3)
	print("hall %s, along %s" % [lair, out])
	var home: Vector3 = maze.world(lair)

	# Nobody about: it lurks, down in its pool.
	var f := fish_at(home)
	await wait(2.0)
	check("with nobody about it lurks in its pool", f.mode == MazeFishPerson.Mode.LURKING and f.figure.sunk > 0.99 and f.global_position.distance_to(f._home) < 0.3, "(%s, sunk %.2f)" % [MazeFishPerson.Mode.keys()[f.mode], f.figure.sunk])
	check("it has its pool", f.pool != null and f.pool.is_inside_tree())
	check("down there it is not in anyone's way", f.collision_layer == 0)

	# Someone walking past in sight, not too near: it stays down.
	var walker := dummy(home + out * 9.0, -out)
	walker.velocity = -out * 1.4
	await wait(2.0)
	check("someone walking past 9 m off does not bring it up", f.mode == MazeFishPerson.Mode.LURKING)

	# Running: it rises, croaks, and hunts.
	walker.velocity = -out * 4.4
	var rose := await wait(2.0, func() -> bool: return f.mode != MazeFishPerson.Mode.LURKING)
	check("someone running 9 m off brings it up", rose, "(%s)" % MazeFishPerson.Mode.keys()[f.mode])
	var croaked := await wait(4.0, func() -> bool: return f.figure.doing() == FishPersonRig.Act.CROAK)
	check("it rises out of the water and croaks", croaked and f.figure.sunk < 0.05, "(sunk %.2f)" % f.figure.sunk)
	walker.velocity = Vector3.ZERO
	clear()

	# Stepping into its pool brings it up; its croak brings up another.
	f = fish_at(home)
	var other_cell := lair
	var steps: PackedInt32Array = nav.field(lair)
	for cell: Vector2i in nav.lairs(1):
		var d: int = steps[maze.index(cell)]
		if d >= 2 and d <= 3 and maze.world(cell).distance_to(home) < 40.0:
			other_cell = cell
			break
	var second := fish_at(maze.world(other_cell))
	await wait(0.5)
	var wader := dummy(home + out * 1.0, -out)
	await wait(2.0, func() -> bool: return f.mode != MazeFishPerson.Mode.LURKING)
	check("stepping into its pool brings it up", f.mode != MazeFishPerson.Mode.LURKING)
	await wait(5.0, func() -> bool: return second.mode != MazeFishPerson.Mode.LURKING)
	check("its croak brings up another %.0f m off" % second.global_position.distance_to(home), second.mode != MazeFishPerson.Mode.LURKING, "(%s)" % MazeFishPerson.Mode.keys()[second.mode])
	clear()

	# Up and hunting, it lopes at someone in sight and lunges and catches them.
	f = fish_at(home)
	var still := dummy(home + out * 9.0, -out)
	still.velocity = -out * 4.4
	await wait(2.0, func() -> bool: return f.mode != MazeFishPerson.Mode.LURKING)
	still.velocity = Vector3.ZERO
	var fastest := 0.0
	var got := false
	for i in 60 * 14:
		await physics_frame
		fastest = maxf(fastest, Vector2(f.velocity.x, f.velocity.z).length())
		if caught.has(still):
			got = true
			break
	check("it lopes at someone in sight, faster than a run", fastest > 4.4, "(%.1f m/s at most)" % fastest)
	check("it lunges and catches someone standing still", got, "(%.2f m apart, %s)" % [f.global_position.distance_to(still.global_position), FishPersonRig.Act.keys()[f.figure.doing()]])
	clear()

	# Someone who sprints away from it gets away; then it goes back to its pool and sinks.
	f = fish_at(home)
	var runner := dummy(home + out * 7.0, -out)
	runner.velocity = -out * 4.4
	await wait(3.0, func() -> bool: return f.mode == MazeFishPerson.Mode.HUNTING)
	runner.velocity = out * 5.6
	var gone := 0.0
	for i in 600:
		if gone < 40.0:
			runner.global_position += out * 5.6 / 60.0
			gone += 5.6 / 60.0
		else:
			runner.velocity = Vector3.ZERO
		await physics_frame
	check("someone who sprints away (5.6 m/s) is not caught", caught.is_empty(), "(%.1f m apart at the end)" % f.global_position.distance_to(runner.global_position))
	runner.free()
	var back := await wait(40.0, func() -> bool: return f.mode == MazeFishPerson.Mode.LURKING)
	check("having lost them it goes back to its pool and sinks", back and f.global_position.distance_to(f._home) < 1.0 and f.figure.sunk > 0.95, "(%s, %.2f m from home, sunk %.2f)" % [MazeFishPerson.Mode.keys()[f.mode], f.global_position.distance_to(f._home), f.figure.sunk])
	clear()

	# A puppet copy follows the host, rising and croaking when it does.
	f = fish_at(home)
	var target := dummy(home + out * 6.0, -out)
	target.velocity = -out * 4.4
	var copy := MazeFishPerson.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = f.position
	copy.rotation.y = f.rotation.y
	stage.add_child(copy)
	var worst := 0.0
	var copy_croaked := false
	var copy_rose := false
	for i in 480:
		if i % 6 == 0:
			copy.from_bytes(f.state_bytes())
		if i == 60:
			target.velocity = Vector3.ZERO
		await physics_frame
		if i > 30:
			worst = maxf(worst, copy.global_position.distance_to(f.global_position))
		copy_croaked = copy_croaked or copy.figure.doing() == FishPersonRig.Act.CROAK
		copy_rose = copy_rose or copy.figure.sunk < 0.05
	check("a puppet fish person follows the host's news", worst < 1.6, "(at worst %.2f m behind)" % worst)
	check("it rises when the host's does", copy_rose)
	check("and croaks when it does", copy_croaked)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, f.state_bytes().size() == MazeEnemy.STATE_SIZE)
	clear()

	# The croak, made in code.
	var croak := FishPerson.croak_sound()
	check("its croak is made (%.1f s)" % croak.get_length(), croak.get_length() > 1.5)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
