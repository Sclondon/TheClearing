extends SceneTree
## The giant octopus (MazeOctopus, driving creatures/octopus's Octopus),
## headless, in a bare maze from MazeBuilder: it finds its pool against a wall
## of a hall and lurks down in it, its feelers out along the floor; someone
## walking past out of its reach is let be; someone standing in reach is struck
## at after a wind-up (its skin blanching, papillae up), held, dragged in and
## caught; someone walking past in reach is grabbed, someone running past is
## missed; the boy struggles free with four jumps; a held one is freed by the
## boy cutting the arm (it inks, hides, and the arm grows back), and the ink
## darkens the screen of whoever is in it; it comes out after someone who
## stays near out of reach, crawls slower than a walk and goes back and sinks;
## in a drain it pours itself through the wall to someone at the other side;
## hungry, it drags in and eats a deer; a puppet copy follows the host's news
## (striking, holding, inking, losing an arm); its sounds are made; and what
## posing it costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/octopus_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO


var stage: Node3D
var maze
var nav
var boy
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
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.position = Vector3(0, -50, 0)
	_run.call_deferred()


## A cell with a straight passage of at least `run` cells out of it, and the way out.
func find_hall(run: int, skip := 0) -> void:
	var found := 0
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(cell + step * k, step) or not nav.allowed(cell + step * (k + 1)):
					ok = false
			if ok:
				if found == skip:
					lair = cell
					out = Vector3(step.x, 0.0, step.y)
					return
				found += 1


func dummy(at: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.add_to_group(&"maze_players")
	return d


func octopus_at(at: Vector3, in_drain := false) -> MazeOctopus:
	var o := MazeOctopus.new()
	o.maze = maze
	o.drain = in_drain
	o.position = at + Vector3.UP * 0.05
	stage.add_child(o)
	o.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return o


func clear() -> void:
	for child in stage.get_children():
		if child is MazeOctopus or child is Dummy or child is OctopusInk or (child is MazeEnemy and not child is MazeOctopus):
			child.free()
	for child in stage.get_children():
		if child is MeshInstance3D and child.get_script() == null:
			child.free()
	caught.clear()
	boy.remove_from_group(&"maze_players")
	boy.position = Vector3(0, -50, 0)
	boy.takes_input = false


func flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## A point `distance` out from its mouth into the hall, `side` metres along it.
func spot(o: MazeOctopus, distance: float, side := 0.0) -> Vector3:
	var mouth: Vector3 = o.mouths[o.den]
	var way: Vector3 = o.outs[o.den]
	return mouth + way * distance + way.cross(Vector3.UP) * side + Vector3.UP * 0.05


func _run() -> void:
	find_hall(2)
	print("hall %s, along %s" % [lair, out])
	var home: Vector3 = maze.world(lair)

	# Its pool, against a wall; down in it with nobody about.
	var o := octopus_at(home)
	await wait(1.0, func() -> bool: return o._ready_den)
	check("it finds its lair: a pool", o.pool != null and o.mouths.size() == 1)
	check("its pool is against a wall of the hall, not in the middle", flat(o.mouths[0] - home) > 0.5 or o.reach < o.grab_reach, "(%.1f m from the cell's middle)" % flat(o.mouths[0] - home))
	check("it never reaches right across the hall", o.reach <= o.grab_reach, "(reach %.1f m)" % o.reach)
	await wait(4.0)
	check("down there it lurks, out of sight", o.mode == MazeOctopus.Mode.LURK and o.sunk > 0.99 and o.collision_layer == 0)
	var feeler: int = o._feelers[0]
	var points: PackedVector3Array = o.figure.arm_points(feeler)
	var outside := 0
	for p in points:
		if p.y > o._floor - 0.1 and flat(p - o.mouths[0]) > o.pool_radius * 0.8:
			outside += 1
	check("a feeler lies out along the floor beyond its pool", outside >= 4, "(%d of its points)" % outside)
	check("camouflaged as it feels about (its own colours hidden)", o.figure.reveal < 0.15, "(reveal %.2f)" % o.figure.reveal)

	# Someone walking past out of its reach is let be.
	var far_side := dummy(spot(o, o.reach + 2.5, -8.0))
	var wound := false
	for i in 60 * 5:
		far_side.global_position += o.outs[0].cross(Vector3.UP) * 1.4 / 60.0
		await physics_frame
		wound = wound or o.act != MazeOctopus.Act.IDLE
	check("someone walking past out of reach is not struck at", not wound and caught.is_empty())
	far_side.free()

	# Standing in reach: the wind-up (the warning), the lash, held, dragged in, caught.
	var still := dummy(spot(o, 3.8, 1.0))
	var winding := await wait(2.0, func() -> bool: return o.act == MazeOctopus.Act.WIND)
	check("someone standing in reach is struck at", winding)
	await wait(o.wind_time * 0.8)
	check("the wind-up shows: its skin blanches, its papillae rise", o.act == MazeOctopus.Act.WIND and o.figure.reveal > 0.3 and o.figure.papillae > 0.6, "(reveal %.2f, papillae %.2f)" % [o.figure.reveal, o.figure.papillae])
	var arm_top := -INF
	for p in o.figure.arm_points(o.active):
		arm_top = maxf(arm_top, p.y)
	check("the arm rears up out of the water to strike", arm_top > o._floor + 2.0, "(%.1f m up)" % (arm_top - o._floor))
	var held := await wait(2.0, func() -> bool: return o.act == MazeOctopus.Act.HOLD)
	check("standing still, they are caught round the legs", held)
	var start := flat(still.global_position - o.mouths[0])
	await wait(1.0)
	var wrapped: Vector2 = o.figure.near_arm(o.active, still.global_position + Vector3.UP * 0.6)
	check("the arm is wound round them", wrapped.x < 0.6, "(%.2f m)" % wrapped.x)
	check("and drags them towards the water", flat(still.global_position - o.mouths[0]) < start - 0.8, "(%.1f m to %.1f m)" % [start, flat(still.global_position - o.mouths[0])])
	var got := await wait(8.0, func() -> bool: return caught.has(still))
	check("dragged all the way in, they are caught", got)
	clear()

	# Walking past in reach: grabbed. Running past: missed.
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(1.0)
	var walker := dummy(spot(o, 3.5, -6.0))
	var grabbed := false
	for i in 60 * 8:
		walker.global_position += o.outs[0].cross(Vector3.UP) * 1.5 / 60.0
		await physics_frame
		if o.act == MazeOctopus.Act.HOLD:
			grabbed = true
			break
	check("walking past within its reach, they are grabbed", grabbed)
	clear()
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(1.0)
	var runner := dummy(spot(o, 3.5, -o.reach - 1.0))
	var lashed := 0
	var held_runner := false
	var was := MazeOctopus.Act.IDLE
	for i in int(60 * (2.0 * o.reach + 2.0) / 4.4):
		runner.global_position += o.outs[0].cross(Vector3.UP) * 4.4 / 60.0
		await physics_frame
		if o.act == MazeOctopus.Act.LASH and was != MazeOctopus.Act.LASH:
			lashed += 1
		was = o.act
		held_runner = held_runner or o.act == MazeOctopus.Act.HOLD
	check("running past, it lashes and misses", lashed >= 1 and not held_runner, "(%d lashes)" % lashed)
	clear()

	# The boy struggles free: four jumps.
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(1.0)
	boy.add_to_group(&"maze_players")
	boy.global_position = spot(o, 3.5)
	boy.velocity = Vector3.ZERO
	var boy_held := await wait(4.0, func() -> bool: return o.held_here == boy)
	check("the boy is grabbed, and held on his own machine", boy_held)
	check("held, he cannot walk off", boy.takes_input == false)
	await wait(0.5)
	for i in 4:
		Input.action_press(&"jump")
		await physics_frame
		await physics_frame
		Input.action_release(&"jump")
		await wait(0.2)
	check("four jumps and he is free", o.held_here == null and o.act != MazeOctopus.Act.HOLD and caught.is_empty())
	await wait(1.0)
	check("and is not grabbed again at once", o.act != MazeOctopus.Act.HOLD)
	clear()

	# A friend cuts the arm: it lets go, inks, hides, the arm grows back.
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(1.0)
	var friend := dummy(spot(o, 3.0))
	await wait(4.0, func() -> bool: return o.act == MazeOctopus.Act.HOLD)
	await wait(0.6)
	var arm: int = o.active
	var on_arm: PackedVector3Array = o.figure.arm_points(arm)
	# (the boy comes up beside the arm, out of the water, and cuts it)
	var beside := on_arm[OctopusArm.BONES - 6]
	boy.add_to_group(&"maze_players")
	boy.global_position = Vector3(beside.x, o._floor + 0.05, beside.z) + o.outs[0].cross(Vector3.UP) * 0.8
	Input.action_press(&"act")
	await physics_frame
	await physics_frame
	Input.action_release(&"act")
	await wait(0.3)
	check("the act button by an arm cuts it", o.figure.grown(arm) < 0.8 and o.cuts == 1, "(grown %.2f)" % o.figure.grown(arm))
	check("it lets go of what it held", o.act != MazeOctopus.Act.HOLD and caught.is_empty())
	check("it inks, and hides in its water", o.inks == 1 and o.mode == MazeOctopus.Mode.HIDE)
	await wait(0.8)
	var dark := OctopusInk.darkness_at(o.mouths[0] + Vector3.UP * 1.0)
	check("the ink is thick by the water (the screen goes dark there)", dark > 0.4, "(%.2f)" % dark)
	var blind := MazeOctopus._blind
	boy.global_position = o.mouths[0] + o.outs[0] * 1.0
	await wait(0.8)
	check("the boy's screen darkens in it", blind != null and blind.darkness() > 0.3, "(%.2f)" % (blind.darkness() if blind else -1.0))
	var grown_then: float = o.figure.grown(arm)
	await wait(2.0)
	check("the arm grows back", o.figure.grown(arm) > grown_then)
	await wait(o.hide_time + 1.0, func() -> bool: return o.mode == MazeOctopus.Mode.LURK)
	check("after a while it lurks again", o.mode == MazeOctopus.Mode.LURK)
	clear()

	# It comes out after someone near but out of reach, crawls slower than a walk, and goes back.
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(1.0)
	var lingerer := dummy(spot(o, o.reach + 2.5))
	o.notice(lingerer)
	var came := await wait(8.0, func() -> bool: return o.mode == MazeOctopus.Mode.OUT and o.sunk <= 0.0)
	check("someone staying near out of reach brings it out of the water", came, "(%s, sunk %.2f)" % [MazeOctopus.Mode.keys()[o.mode], o.sunk])
	check("out on the ground it is solid", o.collision_layer == 4)
	var fastest := 0.0
	for i in 120:
		o.notice(lingerer)
		await physics_frame
		fastest = maxf(fastest, flat(o.velocity))
	check("it crawls after them slower than a walk", fastest > 0.3 and fastest < 1.6, "(%.2f m/s at most)" % fastest)
	lingerer.global_position = spot(o, 40.0)
	lingerer.free()
	var sank := await wait(30.0, func() -> bool: return o.mode == MazeOctopus.Mode.LURK and o.sunk > 0.99)
	check("having lost them it goes back to its water and sinks", sank, "(%s)" % MazeOctopus.Mode.keys()[o.mode])
	clear()

	# Ecology: hungry, it grabs a deer that comes near and eats it.
	var eco := Ecology.put(stage, 1)
	o = octopus_at(home)
	await wait(1.5, func() -> bool: return o._ready_den)
	await wait(0.5)
	var deer := MazeDeer.new()
	deer.maze = maze
	deer.position = spot(o, 3.0)
	stage.add_child(deer)
	await wait(0.2)
	o.hunger = 1.0
	o.quarry = deer
	o._forget = 20.0
	var ate := await wait(12.0, func() -> bool: return deer.dead)
	check("hungry, it drags a deer in and eats it", ate)
	eco.free()
	clear()

	# In a drain, it pours itself through the wall to someone on the other side.
	var drain_cell := Vector2i(-1, -1)
	var drain_step := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step) and maze.inside(cell + step) and nav.allowed(cell + step) and not maze.ring_wall(cell, step):
				drain_cell = cell
				drain_step = step
				break
		if drain_cell.x >= 0:
			break
	var d := octopus_at(maze.world(drain_cell), true)
	await wait(1.5, func() -> bool: return d._ready_den)
	check("in a drain it has a mouth on each side of the wall", d.drains != null and d.mouths.size() == 2, "(cell %s, %d mouths)" % [drain_cell, d.mouths.size()])
	if d.mouths.size() == 2:
		check("the two mouths face away from each other", d.outs[0].dot(d.outs[1]) < -0.9)
		await wait(1.0)
		var beyond := dummy(d.mouths[1] + d.outs[1] * 3.5 + Vector3.UP * 0.05)
		d.notice(beyond)
		var through := await wait(6.0, func() -> bool: return d.den == 1)
		check("someone at the other mouth: it squeezes through the wall to them", through)
		var struck := await wait(4.0, func() -> bool: return d.act != MazeOctopus.Act.IDLE)
		check("and strikes from there", struck)
	clear()

	# A puppet copy follows the host: striking, holding, inking, losing an arm.
	o = octopus_at(home)
	var copy := MazeOctopus.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = o.position
	stage.add_child(copy)
	await wait(1.5, func() -> bool: return o._ready_den and copy._ready_den)
	var bait := dummy(spot(o, 3.5))
	var copy_wound := false
	var copy_held := false
	for i in 300:
		if i % 6 == 0:
			copy.from_bytes(o.state_bytes())
		await physics_frame
		copy_wound = copy_wound or copy.figure.doing[o.active] == Octopus.Do.WIND
		copy_held = copy_held or copy.figure.doing[o.active] == Octopus.Do.HOLD
	check("a puppet winds up and holds when the host's does", copy_wound and copy_held)
	o.cut_arm(o.active)
	for i in 30:
		if i % 6 == 0:
			copy.from_bytes(o.state_bytes())
		await physics_frame
	check("it loses the arm and inks when the host's does", copy.figure.grown(o.active) < 0.8 and copy._heard_inks == 1)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, o.state_bytes().size() == MazeEnemy.STATE_SIZE)
	bait.free()
	clear()

	# Its sounds, made in code.
	check("its sounds are made", OctopusSound.slither().get_length() > 2.0 and OctopusSound.splash().get_length() > 0.5 and OctopusSound.jet().get_length() > 1.0)

	# What posing one costs.
	var one := Octopus.new()
	stage.add_child(one)
	one.mouth = Vector3.INF
	for k in Octopus.ARMS:
		one.feel(k, one.global_position + Vector3(sin(k), 0, cos(k)) * 5.0)
	await physics_frame
	var began := Time.get_ticks_usec()
	for i in 120:
		one._process(1.0 / 60.0)
	var each := (Time.get_ticks_usec() - began) / 120.0
	print("posing one octopus: %.2f ms a frame" % (each / 1000.0))
	check("posing one costs well under a millisecond and a half", each < 1500.0, "(%.0f us)" % each)
	one.free()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
