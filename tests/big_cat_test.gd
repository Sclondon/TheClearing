extends SceneTree
## The big cats (scripts/enemies/maze_lynx.gd and maze_panther.gd, on
## maze_cat.gd and creatures/big_cat), headless, in a bare maze with the boy in
## it. In turn: the creature's moves (the wiggle then the spring, the swipe,
## the hiss); a lynx put in a hall goes up onto the ledge over it, watches him
## and slips off as he comes; one at its kill hisses first and
## swipes only when he comes on; a panther he faces hesitates and never
## springs; with his back to it, it creeps up and pounces; run from close, it
## chases and catches; from its ledge it drops behind someone who runs under
## it; on the ground with nobody about it climbs ivy onto a ledge; hungry, it
## kills a deer; a puppet keeps up with the host and pounces when it does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/big_cat_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var boy: Node3D
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
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3, facing := 0.0) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = facing


## Sets the boy going along `way` at `speed` (his own body moves him), facing `facing` (INF: the way he goes).
func step_boy(way: Vector3, speed: float, facing := INF) -> void:
	boy.velocity = way.normalized() * speed
	boy.facing_yaw = atan2(way.x, way.z) if facing == INF else facing


func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


## A long straight run of open cells in the maze: (first cell, the step along it, how many).
func long_hall() -> Array:
	var best := [Vector2i.ZERO, Vector2i(1, 0), 0]
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 8 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best[2]:
				best = [cell, step, run]
	return best


func add_cat(one: MazeCat, at: Vector3, facing := 0.0) -> MazeCat:
	one.maze = maze
	one.seed_choices(7)
	one.position = at + Vector3.UP * 0.05
	one.rotation.y = facing
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(3)


func _run() -> void:
	await frames(10)
	await _creature()
	var hall := long_hall()
	var first: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var start := nav.point(first)
	print("a hall of %d cells" % hall[2])
	await _lynx(start, way)
	await _cornered()
	await _panther(start, way)
	await _from_above(start, way)
	await _climbs()
	await _kills(start, way)
	await _puppet(start, way)
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


# --- The creature on its own ---

func _creature() -> void:
	var cat := BigCat.new()
	cat.kind = BigCat.Kind.PANTHER
	cat.sound = false
	stage.add_child(cat)
	await frames(5)
	cat.pounce(Vector3(0.0, 0.4, 3.5))
	check("a pounce begins with the wiggle", cat.wiggling() and cat.lunge_stage() == Dog.Lunge.NONE)
	await wait(BigCat.WIGGLE_TIME + 0.05)
	check("then it springs", cat.lunge_stage() != Dog.Lunge.NONE)
	var travelled := 0.0
	var hit := false
	for i in 60:
		cat.global_position += cat.lunge_push() / 60.0
		travelled = cat.global_position.z
		hit = hit or cat.pounce_hits(Vector3(0.0, 0.5, 3.5), 0.9)
		await physics_frame
	check("it springs several metres and lands on what it sprang at", travelled > 2.4 and hit, "(%.2f m)" % travelled)
	cat.global_position = Vector3.ZERO
	cat.settle()
	var lynx := BigCat.new()
	lynx.kind = BigCat.Kind.LYNX
	lynx.sound = false
	stage.add_child(lynx)
	lynx.global_position = Vector3(4.0, 0.0, 0.0)
	await frames(5)
	lynx.swipe(Vector3(4.2, 0.5, 1.0))
	var struck := false
	var early := false
	for i in 50:
		await physics_frame
		var reach := lynx.swipe_hits(Vector3(4.2, 0.5, 1.0), 0.95)
		if reach and lynx.swipe_progress() < BigCat.STRIKE.x:
			early = true
		struck = struck or reach
	check("a swipe lands only as it strikes, after the paw goes up", struck and not early)
	lynx.hiss()
	check("a hiss", lynx.hissing())
	cat.queue_free()
	lynx.queue_free()
	await frames(3)


# --- The lynx ---

func _lynx(start: Vector3, way: Vector3) -> void:
	var lynx := add_cat(MazeLynx.new(), start) as MazeLynx
	put_boy(start + way * 28.0, yaw_to(start + way * 28.0, start))
	await frames(5)
	check("a lynx goes up onto the ledge over the hall it is put in", lynx.place == MazeCat.Place.LEDGE, "(%.1f m up)" % (lynx.global_position.y - maze.ground_height(lynx.global_position)))
	var watched := await wait(6.0, func() -> bool: return lynx.mode == MazeCat.Mode.WATCH)
	check("seeing him, it watches him", watched, "(mode %d)" % lynx.mode)
	var slipped := false
	for i in 600:
		var to := lynx.global_position - boy.global_position
		to.y = 0.0
		if to.length() > 3.0:
			step_boy(to, 1.6)
		else:
			boy.velocity = Vector3.ZERO
		await physics_frame
		if lynx.mode in [MazeCat.Mode.SLIP, MazeCat.Mode.FLEE, MazeCat.Mode.DROP]:
			slipped = true
			break
	check("as he comes it slips away", slipped, "(mode %d)" % lynx.mode)
	await wait(4.0)
	check("and lets him be", caught_by.is_empty())
	await clear()


func _cornered() -> void:
	# (a lynx at its kill in a hall, and the boy walking up to it)
	var hall := long_hall()
	var back := nav.point(hall[0])
	var along := Vector3(hall[1].x, 0.0, hall[1].y)
	var lynx := MazeLynx.new()
	lynx.lie_up = false
	add_cat(lynx, back)
	await frames(3)
	lynx.ate(60.0)
	var mouth := back + along * 16.0
	put_boy(mouth, yaw_to(mouth, back))
	await frames(20)
	var hissed := false
	var swiped_before_hiss := false
	for i in 1200:
		var to := lynx.global_position - boy.global_position
		to.y = 0.0
		if to.length() > 1.2:
			step_boy(to, 1.4)
		else:
			boy.velocity = Vector3.ZERO
		await physics_frame
		if lynx.mode == MazeCat.Mode.HISS:
			hissed = true
		if lynx.mode == MazeCat.Mode.SWIPE and not hissed:
			swiped_before_hiss = true
		if not caught_by.is_empty():
			break
	check("at its kill, it hisses first", hissed and not swiped_before_hiss)
	check("and swipes him down when he comes on", not caught_by.is_empty())
	await clear()


# --- The panther ---

func _panther(start: Vector3, way: Vector3) -> void:
	var panther := MazePanther.new()
	panther.lie_up = false
	add_cat(panther, start, atan2(way.x, way.z))
	# He stands facing it, 8 m off.
	var at := start + way * 8.0
	put_boy(at, yaw_to(at, start))
	var hesitated := await wait(8.0, func() -> bool: return panther.mode == MazeCat.Mode.HESITATE)
	check("faced, a panther hesitates", hesitated, "(mode %d)" % panther.mode)
	for i in 300:
		boy.facing_yaw = yaw_to(boy.global_position, panther.global_position)
		await physics_frame
	check("and never springs while he looks at it", caught_by.is_empty() and panther.mode != MazeCat.Mode.POUNCE)
	await clear()

	# He stands with his back to it.
	panther = MazePanther.new()
	panther.lie_up = false
	add_cat(panther, start, atan2(way.x, way.z))
	put_boy(at, atan2(way.x, way.z))
	var heard := {"growl": false, "wiggle": false}
	panther.cat.growled.connect(func() -> void: heard["growl"] = true)
	panther.cat.pounce_begun.connect(func(_to: Vector3) -> void: heard["wiggle"] = true)
	var had := await wait(20.0, func() -> bool:
		boy.facing_yaw = atan2(way.x, way.z)
		return not caught_by.is_empty())
	check("with his back to it, it creeps up and pounces", had, "(mode %d, %.1f m off)" % [panther.mode, panther.global_position.distance_to(boy.global_position)])
	check("after a growl and the wiggle", heard["growl"] and heard["wiggle"], str(heard))
	await clear()

	# He runs from it, near.
	panther = MazePanther.new()
	panther.lie_up = false
	add_cat(panther, start, atan2(way.x, way.z))
	put_boy(start + way * 9.0, yaw_to(start + way * 9.0, start))
	await wait(1.5)
	var chased := false
	for i in 360:
		step_boy(way, 5.6)
		await physics_frame
		chased = chased or panther.mode == MazeCat.Mode.CHASE
		if not caught_by.is_empty():
			break
	check("run from close, it chases", chased)
	check("and catches him", not caught_by.is_empty(), "(%.1f m off)" % panther.global_position.distance_to(boy.global_position))
	await clear()

	# He sprints off from further: it cannot keep up.
	panther = MazePanther.new()
	panther.lie_up = false
	add_cat(panther, start, atan2(way.x, way.z))
	put_boy(start + way * 14.0, yaw_to(start + way * 14.0, start))
	await wait(1.0)
	for i in 400:
		step_boy(way, 5.6)
		await physics_frame
	check("a sprint from further off gets away", caught_by.is_empty())
	await clear()


func _from_above(start: Vector3, way: Vector3) -> void:
	var panther := add_cat(MazePanther.new(), start) as MazePanther
	await frames(5)
	check("a panther starts up on the ledge over the hall", panther.place == MazeCat.Place.LEDGE)
	if panther.place != MazeCat.Place.LEDGE:
		await clear()
		return
	var under := Vector3(panther.global_position.x, maze.ground_height(start), panther.global_position.z) + panther.ledge_out * 5.0
	put_boy(under, atan2(way.x, way.z))
	await wait(1.5)
	var dropped := false
	for i in 300:
		step_boy(way, 4.4)
		await physics_frame
		if panther.mode == MazeCat.Mode.DROP:
			dropped = true
		if dropped and panther.place == MazeCat.Place.GROUND:
			break
	check("someone running under it, it drops off its ledge after them", dropped and panther.place == MazeCat.Place.GROUND, "(mode %d, place %d)" % [panther.mode, panther.place])
	await clear()


func _climbs() -> void:
	# Ivy that goes up to a ledge, and a panther near its foot with nobody about.
	var found: Array = []
	var probe := MazePanther.new()
	probe.lie_up = false
	add_cat(probe, nav.point(nav.lairs(3)[0]))
	await frames(3)
	for node: Node in get_tree_nodes(&"ladders"):
		var ivy := node as Ladder
		if ivy == null:
			continue
		var foot := ivy.stand(ivy.bottom_y())
		probe.global_position = foot
		var up := probe._ivy_up(foot, 3.0)
		if not up.is_empty():
			found = [ivy, foot]
			break
	await clear()
	check("ivy up to a ledge to climb", not found.is_empty())
	if found.is_empty():
		return
	put_boy(Vector3(9999.0, 0.0, 9999.0))
	var panther := MazePanther.new()
	panther.lie_up = false
	var foot: Vector3 = found[1]
	add_cat(panther, foot + (found[0] as Ladder).facing() * -3.0)
	var climbed := await wait(25.0, func() -> bool: return panther.place == MazeCat.Place.LEDGE)
	check("with nobody about it climbs the ivy onto the ledge", climbed, "(place %d, mode %d)" % [panther.place, panther.mode])
	await clear()


func get_tree_nodes(group: StringName) -> Array:
	return stage.get_tree().get_nodes_in_group(group)


func _kills(start: Vector3, way: Vector3) -> void:
	if not Ecology.KINDS.has("MazePanther"):
		print("SKIP: a panther kills a deer (MazePanther is not in Ecology.KINDS yet)")
		return
	put_boy(Vector3(9999.0, 0.0, 9999.0))
	var world := Ecology.put(stage, 3, null)
	var panther := MazePanther.new()
	panther.lie_up = false
	add_cat(panther, start, atan2(way.x, way.z))
	var deer := MazeDeer.new()
	deer.maze = maze
	deer.position = start + way * 12.0
	stage.add_child(deer)
	await frames(3)
	panther.hunger = 1.0
	var killed := await wait(30.0, func() -> bool: return deer.dead)
	check("hungry, a panther kills a deer", killed, "(%.1f m apart)" % panther.global_position.distance_to(deer.global_position))
	check("and eats", panther.mode in [MazeCat.Mode.FEED, MazeCat.Mode.DRAG, MazeCat.Mode.CLIMB])
	world.queue_free()
	await clear()


func _puppet(start: Vector3, way: Vector3) -> void:
	var host := MazePanther.new()
	host.lie_up = false
	add_cat(host, start, atan2(way.x, way.z))
	var copy := MazePanther.new()
	copy.maze = maze
	copy.puppet = true
	copy.lie_up = false
	copy.position = start
	stage.add_child(copy)
	put_boy(start + way * 8.0, atan2(way.x, way.z))
	var furthest := 0.0
	var copied_pounce := false
	for i in 900:
		boy.facing_yaw = atan2(way.x, way.z)
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30 and host.mode != MazeCat.Mode.POUNCE:
			furthest = maxf(furthest, copy.global_position.distance_to(host.global_position))
		copied_pounce = copied_pounce or copy.cat.pouncing()
		if not caught_by.is_empty() and i > 0 and copied_pounce:
			break
	check("the puppet keeps up with the host", furthest < 1.6, "(at most %.2f m off)" % furthest)
	check("and pounces when the host does", copied_pounce)
	await clear()
