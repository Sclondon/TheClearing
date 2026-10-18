extends SceneTree
## The clown (MazeClown, driving creatures/clown's Clown), headless, in a bare
## maze from MazeBuilder: with nobody about he prowls; someone in sight down a
## hall with their back to him is noticed and stalked; looked at, he stops dead
## and stays put, and comes on again when they look away; a wall between them
## does not hold him; near enough, he giggles and sprints (faster than the boy's
## sprint), and looking at him while he giggles stops him; his sprint catches
## someone who stands there, but someone already sprinting away gets clear, and
## he stands winded after; a puppet copy follows the host's news, giggles when
## it does, and stands still while whoever plays on its machine looks at it.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/clown_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player: where it faces is all it has.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO


var stage: Node3D
var maze
var nav
var failures := 0
var caught: Array = []
## A straight hall: its first cell, which way it runs, and how many cells long it is.
var hall := Vector2i.ZERO
var along := Vector3.ZERO
var run := 0


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


## The longest straight hall there is (at most 5 cells), away from the clearing.
func find_hall() -> void:
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var k := 0
			while k < 5 and not maze.blocked(cell + step * k, step) and nav.allowed(cell + step * (k + 1)):
				k += 1
			if k > run:
				run = k
				hall = cell
				along = Vector3(step.x, 0.0, step.y)


func dummy(at: Vector3, facing: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.facing_yaw = atan2(facing.x, facing.z)
	d.add_to_group(&"maze_players")
	return d


func clown(at: Vector3) -> MazeClown:
	var c := MazeClown.new()
	c.maze = maze
	c.position = at + Vector3.UP * 0.05
	c.rotation.y = atan2(along.x, along.z)
	stage.add_child(c)
	c.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return c


func clear() -> void:
	for child in stage.get_children():
		if child is MazeClown or child is Dummy or child is Player:
			child.free()
	caught.clear()


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	find_hall()
	print("hall %s, along %s, %d cells" % [hall, along, run])
	var start: Vector3 = maze.world(hall)

	# Nobody about: he prowls.
	var c := clown(start)
	await wait(3.0)
	check("with nobody about he prowls", c.mode == MazeClown.Mode.PROWLING and flat(c.global_position, start) > 0.5, "(%s, %.1f m)" % [MazeClown.Mode.keys()[c.mode], flat(c.global_position, start)])
	clear()

	# Someone down the hall, their back to him: noticed and stalked.
	c = clown(start)
	var far_off: float = minf(Maze.CELL * run - 2.0, 30.0)
	var who := dummy(start + along * far_off, along)
	var stalked := await wait(2.0, func() -> bool: return c.mode == MazeClown.Mode.STALKING)
	check("someone down the hall with their back to him is stalked", stalked, "(%s, %.0f m off)" % [MazeClown.Mode.keys()[c.mode], far_off])
	var gap := flat(c.global_position, who.global_position)
	await wait(1.0)
	var closer := gap - flat(c.global_position, who.global_position)
	check("he comes on, quicker than a walk and slower than a run", closer > 2.0 and closer < 4.4, "(%.2f m in 1 s)" % closer)
	check("his music box plays", c.figure.music and not c.figure.frozen)

	# They turn round: he stops dead, and stays put while they look.
	who.facing_yaw = atan2(-along.x, -along.z)
	var stopped := await wait(0.5, func() -> bool: return c.mode == MazeClown.Mode.STILL)
	var still_at := c.global_position
	await wait(1.5)
	check("looked at, he stops dead", stopped and c.figure.frozen, "(%s)" % MazeClown.Mode.keys()[c.mode])
	check("and does not move while they look", c.global_position.distance_to(still_at) < 0.05 and Vector2(c.velocity.x, c.velocity.z).length() < 0.01, "(%.3f m)" % c.global_position.distance_to(still_at))
	check("his figure is frozen and its velocity nothing", c.figure.frozen and c.figure.velocity.length() < 0.01)

	# They look away: he comes on again.
	who.facing_yaw = atan2(along.x, along.z)
	var moving := await wait(0.6, func() -> bool: return c.mode == MazeClown.Mode.STALKING)
	await wait(0.5)
	check("they look away and he comes on again", moving and c.global_position.distance_to(still_at) > 0.5, "(%s, %.2f m)" % [MazeClown.Mode.keys()[c.mode], c.global_position.distance_to(still_at)])
	clear()

	# Someone looking his way through a wall does not hold him.
	var across := Vector3(along.z, 0.0, -along.x)
	var walled := Vector2i.ZERO
	var beside := Vector2i.ZERO
	var found := false
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			if not found and maze.blocked(cell, step) and nav.allowed(cell + step):
				beside = cell
				walled = cell + step
				found = true
	if found:
		c = clown(maze.world(beside))
		var behind_wall: Vector3 = maze.world(walled)
		var peeper := dummy(behind_wall, maze.world(beside) - behind_wall)
		await wait(0.3)
		check("someone facing him through a wall does not see him", not c.watched_by(peeper) and not c.watched)
		peeper.free()
	else:
		print("(no cell beside the hall behind a wall: skipped)")
	clear()

	# Near, and nobody looking: he giggles, then sprints.
	c = clown(start)
	who = dummy(start + along * 8.0, along)
	var giggled := await wait(3.0, func() -> bool: return c.mode == MazeClown.Mode.GRINNING)
	check("within reach and unwatched he giggles", giggled and c.figure.busy(), "(%s)" % MazeClown.Mode.keys()[c.mode])
	var sprinting := await wait(1.5, func() -> bool: return c.mode == MazeClown.Mode.SPRINTING)
	await wait(0.4)
	var pace := Vector2(c.velocity.x, c.velocity.z).length()
	check("and sprints, faster than the boy's sprint (5.6)", sprinting and pace > 7.0, "(%.1f m/s)" % pace)
	var got := await wait(2.5, func() -> bool: return caught.has(who))
	check("touching him catches whoever stands there", got, "(%.2f m apart)" % flat(c.global_position, who.global_position))
	check("and then he stands winded", c.mode == MazeClown.Mode.WINDED)
	clear()

	# Looking at him while he giggles stops him.
	c = clown(start)
	who = dummy(start + along * 8.0, along)
	await wait(3.0, func() -> bool: return c.mode == MazeClown.Mode.GRINNING)
	who.facing_yaw = atan2(-along.x, -along.z)
	var halted := await wait(0.4, func() -> bool: return c.mode == MazeClown.Mode.STILL)
	await wait(1.0)
	check("looking at him as he giggles stops him before he runs", halted and c.mode == MazeClown.Mode.STILL and caught.is_empty(), "(%s)" % MazeClown.Mode.keys()[c.mode])
	clear()

	# Someone already sprinting away when he bursts gets clear; he tires.
	c = clown(start)
	var room: float = Maze.CELL * run - 1.0
	who = dummy(start + along * 9.5, along)
	await wait(3.0, func() -> bool: return c.mode == MazeClown.Mode.GRINNING)
	var speed := 0.0
	var winded := false
	for i in 60 * 5:
		speed = minf(speed + 5.6 / 0.4 / 60.0, 5.6)
		var ahead: Vector3 = who.global_position + along * speed / 60.0
		if flat(ahead, start) < room:
			who.global_position = ahead
		await physics_frame
		winded = winded or c.mode == MazeClown.Mode.WINDED
		if caught.has(who):
			break
	if Maze.CELL * run - 1.0 >= 9.5 + 5.6 * 3.2:
		check("someone sprinting away as he bursts gets clear", not caught.has(who), "(%.1f m apart)" % flat(c.global_position, who.global_position))
	else:
		print("(the hall is too short to sprint down: skipped the getaway)")
	check("his sprint is short: he tires and stands winded", winded)
	clear()

	# A puppet copy: follows the host, giggles when it does; and its own machine's player holds it still.
	c = clown(start)
	who = dummy(start + along * 20.0, along)
	var copy := MazeClown.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = c.position
	stage.add_child(copy)
	var boy: Player = load("res://player.tscn").instantiate()
	stage.add_child(boy)
	boy.global_position = start + across * 3.0 + Vector3.UP * 0.1
	boy.remove_from_group(&"maze_players")
	copy.targets = [boy]
	var worst := 0.0
	var copy_giggled := false
	for i in 300:
		if i % 6 == 0:
			copy.from_bytes(c.state_bytes())
		await physics_frame
		# (the boy on the puppet's machine looks the other way)
		boy.facing_yaw = atan2(-(copy.global_position.x - boy.global_position.x), -(copy.global_position.z - boy.global_position.z))
		if i > 30:
			worst = maxf(worst, flat(copy.global_position, c.global_position))
		copy_giggled = copy_giggled or copy.figure.busy()
	check("a puppet clown follows the host's news", worst < 1.6, "(at worst %.2f m behind)" % worst)
	check("it giggles when the host's does", copy_giggled or c._giggles == 0, "(host giggled %d times)" % c._giggles)
	# Now the boy on its machine looks at it: it stands still there while the host's goes on.
	c.mode = MazeClown.Mode.PROWLING
	who.free()
	var held_at := copy.global_position
	for i in 120:
		if i % 6 == 0:
			copy.from_bytes(c.state_bytes())
		await physics_frame
		boy.facing_yaw = atan2(copy.global_position.x - boy.global_position.x, copy.global_position.z - boy.global_position.z)
	check("a puppet stands still while whoever plays on its machine looks at it", copy.global_position.distance_to(held_at) < 0.3 and copy.figure.frozen, "(%.2f m; host %.2f m away)" % [copy.global_position.distance_to(held_at), flat(c.global_position, held_at)])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, c.state_bytes().size() == MazeEnemy.STATE_SIZE)
	clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
