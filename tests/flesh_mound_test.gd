extends SceneTree
## The flesh mounds (scripts/enemies/flesh_mound.gd, and their look in
## creatures/flesh_mound/), headless, in a bare scene: a maze from MazeBuilder
## and the boy standing in it. In turn: an amalgam shambles about with nobody
## near; it sees the boy down a hall, rears and cartwheels at him faster than
## a run, and rolling into him catches him, and it drags his body in and grows;
## a big one grabs him (and misses him if he steps aside in the wind-up), and
## walking into it catches; two put side by side merge into one with both their
## bodies; and a puppet follows its host's news: its size, its grabs, its merge.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/flesh_mound_test.gd
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
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


## A passage cell with `run` open cells straight on from it, and that way.
func straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return []


func spawn(count: int, at: Vector3, facing_to: Vector3, puppet := false) -> MazeFleshMound:
	var mound := MazeFleshMound.new()
	mound.bodies = count
	mound.maze = maze
	mound.puppet = puppet
	mound.position = at + Vector3.UP * 0.05
	stage.add_child(mound)
	var to := facing_to - at
	mound.facing_yaw = atan2(-to.x, -to.z)
	mound.caught.connect(func(who: Node3D) -> void: caught_by.append([who, mound]))
	return mound


func _run() -> void:
	await wait(0.2)
	var found := straight_run(4)
	check("a straight hall to test in", not found.is_empty())
	if found.is_empty():
		_end()
		return
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var far_off := maze.world(cell) + along * Maze.CELL * 3.0

	# --- An amalgam, with nobody about ---
	boy.remove_from_group(&"maze_players")
	var started := Time.get_ticks_msec()
	var wanderer := spawn(3, far_off, maze.world(cell))
	await wait(0.1)
	check("an amalgam is made", wanderer.look != null and wanderer.look.small(), "(in %d ms, its people built the first time)" % (Time.get_ticks_msec() - started))
	var from := wanderer.global_position
	await wait(6.0)
	check("with nobody about it shambles about", wanderer.global_position.distance_to(from) > 2.0 and not wanderer.chasing,
		"(%.1f m in 6 s)" % wanderer.global_position.distance_to(from))
	wanderer.free()
	boy.add_to_group(&"maze_players")

	# --- It sees him down the hall, rears, cartwheels at him, catches him and grows ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var roller := spawn(3, maze.world(cell) + along * 16.0, maze.world(cell))
	roller._age = 10.0
	var wound := await wait(4.0, func() -> bool: return roller.mode == MazeFleshMound.Mode.WINDING)
	check("it sees him down the hall and rears to roll", wound)
	var rolled := await wait(2.0, func() -> bool: return roller.mode == MazeFleshMound.Mode.ROLLING)
	check("then it cartwheels", rolled and roller.look.roll_stage() == FleshMound.Roll.ROLLING)
	var fastest := [0.0]
	var got := await wait(6.0, func() -> bool:
		fastest[0] = maxf(fastest[0], Vector2(roller.velocity.x, roller.velocity.z).length())
		return not caught_by.is_empty())
	check("rolling, faster than a run and slower than a sprint", fastest[0] > 4.4 and fastest[0] < 5.6, "(%.1f m/s)" % fastest[0])
	check("rolling into him catches him", got and caught_by[0][0] == boy)
	var grew := await wait(3.0, func() -> bool: return roller.bodies == 4)
	check("it drags his body in and grows by one", grew, "(%d bodies)" % roller.bodies)
	roller.free()

	# --- A pair sees him near down the hall, crouches and rushes at him ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var pair := spawn(2, maze.world(cell) + along * 8.0, maze.world(cell))
	pair._age = 10.0
	await wait(0.1)
	check("a pair is made", pair.look.form() == FleshMoundLook.Form.PAIR)
	var crouched := await wait(4.0, func() -> bool: return pair.mode == MazeFleshMound.Mode.WINDING)
	check("a pair sees him near down the hall and crouches to rush", crouched)
	var quickest := [0.0]
	var rushed := await wait(4.0, func() -> bool:
		quickest[0] = maxf(quickest[0], Vector2(pair.velocity.x, pair.velocity.z).length())
		return not caught_by.is_empty())
	check("it rushes faster than a sprint", quickest[0] > 5.6, "(%.1f m/s)" % quickest[0])
	check("rushing into him catches him", rushed and caught_by[0][0] == boy)
	var joined := await wait(3.0, func() -> bool: return pair.bodies == 3)
	check("it drags his body in and is an amalgam now", joined and pair.look.form() == FleshMoundLook.Form.AMALGAM)
	pair.free()

	# --- A strider grabs, whichever way round it is ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var ring := spawn(5, maze.world(cell) + along * 10.0, maze.world(cell) + along * 20.0)
	ring._age = 10.0
	ring.notice(boy)
	await wait(0.1)
	check("a strider is made", ring.look.form() == FleshMoundLook.Form.STRIDER)
	var ring_grab := await wait(15.0, func() -> bool: return ring.look.grab_stage() == FleshMound.Stage.WIND_UP)
	check("a strider comes up to him and winds up a grab", ring_grab, "(%.1f m from him)" % ring.global_position.distance_to(boy.global_position))
	var ring_held := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("standing still, its hands catch him", ring_held and caught_by[0][0] == boy)
	var six := await wait(3.0, func() -> bool: return ring.bodies == 6)
	check("it grows by one, still a strider", six and ring.look.form() == FleshMoundLook.Form.STRIDER)
	ring.free()

	# --- A big one: the grab ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var big := spawn(8, maze.world(cell) + along * 12.0, maze.world(cell))
	big._age = 10.0
	big.notice(boy)
	var grabbing := await wait(15.0, func() -> bool: return big.look.grab_stage() == FleshMound.Stage.WIND_UP)
	check("a big one in reach winds up a grab", grabbing, "(%.1f m from him)" % big.global_position.distance_to(boy.global_position))
	var held := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("standing still, its hands catch him", held and caught_by[0][0] == boy)
	big.free()
	caught_by.clear()
	put_boy(maze.world(cell))
	var dodged := spawn(8, maze.world(cell) + along * 12.0, maze.world(cell))
	dodged._age = 10.0
	dodged.notice(boy)
	await wait(15.0, func() -> bool: return dodged.look.grab_stage() == FleshMound.Stage.WIND_UP)
	var across := Vector3(-along.z, 0, along.x)
	put_boy(maze.world(cell) - along * 7.0 + across * 2.0)
	boy.remove_from_group(&"maze_players")
	await wait(dodged.look.wind_up + dodged.look.strike + 0.3)
	check("a step back in the wind-up and the grab misses", caught_by.is_empty())
	boy.add_to_group(&"maze_players")
	dodged.free()
	caught_by.clear()
	var lump := spawn(8, maze.world(cell) + along * 6.0, maze.world(cell))
	lump.grab_range = 0.0
	await wait(0.3)
	put_boy(lump.global_position + along * 1.0)
	var touched := await wait(1.0, func() -> bool: return not caught_by.is_empty())
	check("walking into a big one catches", touched)
	lump.free()

	# --- Two meet and merge ---
	boy.remove_from_group(&"maze_players")
	var a := spawn(4, maze.world(cell) + along * 3.0, maze.world(cell))
	var b := spawn(3, maze.world(cell) + along * 6.0, maze.world(cell))
	var copy_a := spawn(4, maze.world(cell) + along * 3.0, maze.world(cell), true)
	var copy_b := spawn(3, maze.world(cell) + along * 6.0, maze.world(cell), true)
	a._age = 10.0
	b._age = 10.0
	var merging := await wait(2.0, func() -> bool: return b.mode == MazeFleshMound.Mode.MERGING)
	check("two side by side begin to merge (the smaller into the bigger)", merging and a.mode != MazeFleshMound.Mode.MERGING)
	var heard_merging := [false]
	var merged := await wait(4.0, func() -> bool:
		copy_a.from_bytes(a.state_bytes())
		copy_b.from_bytes(b.state_bytes())
		heard_merging[0] = heard_merging[0] or copy_b.look.merging() >= 0.0
		return b.gone())
	check("one is gone, the other has both their bodies", merged and a.bodies == 7, "(%d bodies)" % a.bodies)
	check("it is big now, a mound", not a.small() and not a.look.small())
	await wait(0.5, func() -> bool:
		copy_a.from_bytes(a.state_bytes())
		copy_b.from_bytes(b.state_bytes())
		return false)
	check("a puppet flows into the other as its host does", heard_merging[0])
	check("a puppet of the gone one is gone, the other grows", copy_b.gone() and copy_a.bodies == 7 and copy_a.look.bodies == 7, "(%d)" % copy_a.look.bodies)
	for one in [a, b, copy_a, copy_b]:
		one.free()
	boy.add_to_group(&"maze_players")

	# --- A puppet follows its host ---
	caught_by.clear()
	put_boy(maze.world(cell))
	var host := spawn(8, far_off, maze.world(cell))
	host._age = 10.0
	var puppet := spawn(3, far_off, maze.world(cell), true)
	var worst := 0.0
	var puppet_grabbed := false
	for i in 1800:
		await physics_frame
		if i % 6 == 0:
			puppet.from_bytes(host.state_bytes())
		if i > 60:
			worst = maxf(worst, puppet.global_position.distance_to(host.global_position))
		if puppet.look.grab_stage() != FleshMound.Stage.NONE:
			puppet_grabbed = true
	check("a puppet takes its host's size", puppet.bodies == host.bodies and puppet.look.bodies == host.look.bodies, "(%d)" % puppet.look.bodies)
	check("a puppet follows the host's news", worst < 2.5, "(at worst %.2f m behind)" % worst)
	check("a puppet grabs when its host does", puppet_grabbed)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, host.state_bytes().size() == MazeEnemy.STATE_SIZE)
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] == host))
	_end()


func _end() -> void:
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
