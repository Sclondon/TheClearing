extends SceneTree
## The giant ants (scripts/enemies/maze_ants.gd, creatures/giant_ant/),
## headless, in a bare scene: a maze from MazeBuilder and stand-in players
## that the test moves by hand (CharacterBody3Ds with no shape, so their
## `velocity` is whatever the test says). In turn: the colony digs its nest in a
## dead end and lays a trail out from it by the passages, clear of the walls;
## its workers go out and come home along it, some in the nest, the soldiers
## round it; someone walking beside the trail is let alone; someone treading on
## it near them raises the alarm, which they take up (stopping, clicking)
## before any comes at him; standing still he is seized and caught; a sprint
## tears them off and gets away, and they calm and go back to the trail; a run
## does not; coming up to the nest raises it too; a creature that eats (a
## ghoul) on the trail is killed and its carcass hauled home into the nest; a
## carcass by the trail is hauled home; a puppet raises and lays the alarm as
## the host does; MazeEnemies' packing carries it; few draws; and what a frame
## of it costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/ants_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var runner: CharacterBody3D
var failures := 0
var caught: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


## Waits up to `seconds` (of physics frames) for `test`; whether it came true.
func wait(seconds: float, test := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if test.is_valid() and test.call():
			return true
	return not test.is_valid()


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
	runner = CharacterBody3D.new()
	runner.name = "Runner"
	runner.collision_layer = 0
	runner.collision_mask = 0
	stage.add_child(runner)
	runner.add_to_group(&"maze_players")
	var camera := Camera3D.new()
	stage.add_child(camera)
	_run.call_deferred()


func put_runner(at: Vector3, moving := Vector3.ZERO) -> void:
	runner.global_position = at
	runner.velocity = moving


func colony_at(cell: Vector2i, seed_value := 41, puppet := false) -> MazeAnts:
	var ants := MazeAnts.new()
	ants.sound = false
	ants.maze = maze
	ants.puppet = puppet
	ants.seed_choices(seed_value)
	ants.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(ants)
	ants.caught.connect(func(player: Node3D) -> void:
		caught.append([player, ants])
		if OS.get_cmdline_user_args().has("trace"):
			print("  caught at %s going %s (%d on)" % [player.global_position, (player as CharacterBody3D).velocity, ants.colony.on_target]))
	return ants


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught.clear()
	await frames(3)


# Moves the runner along `points` at `speed` for up to `seconds`, or until `stop` is true.
func run_along(points: Array, speed: float, seconds: float, stop := Callable()) -> void:
	var k := 0
	for i in int(seconds * 60.0):
		await physics_frame
		if k >= points.size():
			runner.velocity = Vector3.ZERO
			if stop.is_valid() and stop.call():
				return
			continue
		var to: Vector3 = points[k] - runner.global_position
		to.y = 0.0
		if to.length() < 0.3:
			k += 1
			continue
		runner.velocity = to.normalized() * speed
		runner.global_position += runner.velocity / 60.0
		if stop.is_valid() and stop.call():
			return


func _run() -> void:
	await frames(5)
	var ends: Array[Vector2i] = []
	for cell in nav.lairs(2):
		if nav.dead_end(cell):
			ends.append(cell)
	if ends.is_empty():
		ends = nav.lairs(3)
	check("somewhere to put it", not ends.is_empty())
	var home: Vector2i = ends[ends.size() / 2]

	# --- The nest and the trail ---
	put_runner(Vector3(0.0, 0.0, 0.0))
	var ants := colony_at(home)
	await frames(3)
	check("it has made its colony", ants.ready_to_go())
	var colony := ants.colony
	var nest := colony.nest()
	check("the nest is in its dead end", maze.cell_at(nest) == home)
	check("the nest stands clear of the walls", nav.clear_of_walls(nest, AntColony.MOUND_RADIUS))
	check("the trail runs out a long way", colony.trail_length() > 35.0, "(%.0f m)" % colony.trail_length())
	var clear := true
	for p in colony.trail():
		clear = clear and nav.clear_of_walls(p, 0.8)
	check("the trail keeps off the walls", clear)
	await wait(6.0)
	var on_trail := colony.counted(AntColony.State.OUT) + colony.counted(AntColony.State.HOME)
	check("workers go out and come home along it", colony.counted(AntColony.State.OUT) > 2 and colony.counted(AntColony.State.HOME) > 2, "(%d out, %d home)" % [colony.counted(AntColony.State.OUT), colony.counted(AntColony.State.HOME)])
	check("some are in the nest or foraging", colony.counted(AntColony.State.NEST) + colony.counted(AntColony.State.FORAGE) > 0)
	var guards := 0
	for ant: AntColony.Ant in colony.ants:
		if ant.soldier and ant.pos.distance_to(nest) < colony.guard_radius + 1.0:
			guards += 1
	check("the soldiers keep round the nest", guards == colony.soldiers, "(%d of %d)" % [guards, colony.soldiers])
	var loaded := 0
	for ant: AntColony.Ant in colony.ants:
		if ant.state == AntColony.State.HOME and ant.loaded:
			loaded += 1
	check("some come home carrying", loaded > 0, "(%d)" % loaded)
	check("nothing is alarmed", colony.alarmed_count() == 0 and ants.mode == MazeAnts.Mode.CALM)
	check("it draws in few draws", colony.get_child_count() <= 8 and colony.ants.size() == ants.worker_count + ants.soldier_count, "(%d ants)" % colony.ants.size())

	# --- Beside the trail, he is let alone ---
	var s := colony.trail_length() * 0.5
	var way := colony.trail_way(s)
	var beside := colony.trail_point(s, 3.2)
	if not nav.clear_of_walls(beside, 0.5):
		beside = colony.trail_point(s, -3.2)
	put_runner(beside)
	# (lambdas see a copy of a local: what they find out goes in a dictionary)
	var seen := {"safe": true}
	var points: Array = []
	for k in 6:
		var p := colony.trail_point(s + k * 2.0, 3.2 if beside.distance_to(colony.trail_point(s, 3.2)) < 0.1 else -3.2)
		points.append(p)
	await run_along(points, 1.6, 7.0, func() -> bool:
		seen["safe"] = seen["safe"] and ants.mode == MazeAnts.Mode.CALM
		return false)
	check("walking beside the trail, he is let alone", seen["safe"] and ants.mode == MazeAnts.Mode.CALM)

	# --- On it near them: the alarm, the warning, the catch ---
	var near := colony.nearest_ant(colony.trail_point(s))
	var spot := colony.trail_point(s)
	var best := INF
	for t in range(4, int(colony.trail_length()) - 4):
		var p := colony.trail_point(float(t))
		var n := colony.nearest_ant(p)
		if n.y > 3.0 and n.y < 7.0 and p.distance_to(nest) > 12.0 and absf(n.y - 5.0) < best:
			best = absf(n.y - 5.0)
			spot = p
	put_runner(spot)
	var raised := await wait(1.0, func() -> bool: return ants.mode == MazeAnts.Mode.ALARM)
	check("treading on the trail near them raises the alarm", raised)
	seen["alerted_first"] = false
	seen["first_on"] = -1.0
	seen["frames"] = 0
	var got := await wait(10.0, func() -> bool:
		seen["frames"] += 1
		if colony.counted(AntColony.State.ALERT) > 0 and colony.on_target == 0:
			seen["alerted_first"] = true
		if colony.on_target > 0 and seen["first_on"] < 0.0:
			seen["first_on"] = seen["frames"] / 60.0
		return not caught.is_empty())
	check("they take it up (stop, click) before any reaches him", seen["alerted_first"])
	check("standing still, he is seized and caught", got and caught[0][0] == runner, "(first on him %.1f s, caught %.1f s after the alarm)" % [seen["first_on"], seen["frames"] / 60.0])
	check("with time to see them come", seen["first_on"] > 0.8)
	await wait(3.0, func() -> bool: return ants.mode == MazeAnts.Mode.CALM)
	check("caught, they calm", ants.mode == MazeAnts.Mode.CALM)
	await wait(4.0)

	# --- A sprint gets away; a run does not ---
	# (off their trail, by the passages, to somewhere far from it: along it there are only more of them)
	var away := _escape_from(spot, colony)
	caught.clear()
	# (he comes back once they have all gone back to their ways, not into the middle of them)
	put_runner(Vector3.ZERO)
	await wait(30.0, func() -> bool: return colony.alarmed_count() == 0 and colony.counted(AntColony.State.CALM) == 0)
	put_runner(spot)
	await wait(1.0, func() -> bool: return ants.mode == MazeAnts.Mode.ALARM)
	# (he sees them stop and click, and goes at once)
	await wait(0.4)
	await run_along(away, 5.6, 14.0, func() -> bool: return ants.mode == MazeAnts.Mode.CALM)
	check("a sprint tears them off and gets away", caught.is_empty(), "(%d caught)" % caught.size())
	var calmed := await wait(10.0, func() -> bool: return ants.mode == MazeAnts.Mode.CALM)
	check("and they give up and calm", calmed)
	var back := await wait(25.0, func() -> bool: return colony.alarmed_count() == 0 and colony.counted(AntColony.State.CALM) == 0)
	check("and go back to their ways", back, "(%d calm still)" % colony.counted(AntColony.State.CALM))
	check("a run is slower than they are, a sprint faster", colony.run_speed > 4.4 and colony.run_speed < 5.6)
	caught.clear()
	put_runner(spot)
	await wait(1.0, func() -> bool: return ants.mode == MazeAnts.Mode.ALARM)
	await wait(0.6)
	await run_along(away, 4.4, 14.0, func() -> bool: return not caught.is_empty())
	check("running, he is caught", not caught.is_empty())
	put_runner(Vector3.ZERO)
	await wait(3.0, func() -> bool: return ants.mode == MazeAnts.Mode.CALM)
	await wait(6.0)

	# --- Up to the nest ---
	caught.clear()
	var out := colony.trail_way(0.0)
	put_runner(Vector3.ZERO)
	await wait(0.5)
	var nest_calm := ants.mode == MazeAnts.Mode.CALM
	# (off the trail, beside the nest)
	var across := Vector3(-out.z, 0.0, out.x)
	var by_nest := nest + out * 5.0 + across * 3.0
	if not nav.clear_of_walls(by_nest, 0.4):
		by_nest = nest + out * 5.0 - across * 3.0
	put_runner(by_nest)
	raised = await wait(1.0, func() -> bool: return ants.mode == MazeAnts.Mode.ALARM)
	check("coming up to the nest raises the alarm", nest_calm and raised)
	var poured := await wait(3.0, func() -> bool:
		var n := 0
		for ant: AntColony.Ant in colony.ants:
			if ant.soldier and ant.state in [AntColony.State.RUSH, AntColony.State.ON, AntColony.State.ALERT]:
				n += 1
		return n >= colony.soldiers)
	check("the soldiers come for him", poured)
	await run_along(_away_from(by_nest, nest, 6), 5.6, 14.0, func() -> bool: return ants.mode == MazeAnts.Mode.CALM)
	await wait(20.0, func() -> bool: return colony.alarmed_count() == 0)
	put_runner(Vector3(0.0, 0.0, 0.0))
	caught.clear()

	# --- Ecology: a creature that eats, on the trail, is killed and carried home ---
	var flies := Insects.new()
	flies.maze = maze
	stage.add_child(flies)
	var life := Ecology.put(stage, 3, flies)
	await frames(2)
	var ghoul := MazeGhoul.new()
	ghoul.maze = maze
	var prey_at := colony.trail_point(colony.trail_length() * 0.3)
	ghoul.position = prey_at + Vector3.UP * 0.05
	stage.add_child(ghoul)
	ants.trace_prey = OS.get_cmdline_user_args().has("trace")
	var killed := await wait(15.0, func() -> bool: return ghoul.dead)
	ants.trace_prey = false
	check("a ghoul on their trail is killed", killed, "(alarm: %s, on it %d, held %.1f s, after %s)" % [MazeAnts.Mode.keys()[ants.mode], colony.on_target, ants._hold, ants.quarry])
	check("and its carcass is taken up to be hauled home", colony.carrying() != null)
	var dragged := colony.carrying()
	var home_at := await wait(90.0, func() -> bool: return colony.carrying() == null)
	check("and hauled down into the nest", home_at and dragged and not dragged.visible)
	life.queue_free()

	# --- A carcass by the trail is hauled home ---
	var dead := InsectLook.carcass()
	stage.add_child(dead)
	dead.global_position = colony.trail_point(colony.trail_length() * 0.25, 2.5)
	dead.set_meta(&"carrion_radius", 0.9)
	dead.add_to_group(&"fly_carrion")
	var taken := await wait(8.0, func() -> bool: return colony.carrying() == dead)
	check("a carcass near the trail is taken up", taken)
	var hauled := await wait(90.0, func() -> bool: return colony.carrying() == null)
	check("and hauled home", hauled and not dead.visible and not dead.is_in_group(&"fly_carrion"))
	flies.queue_free()

	# --- A puppet raises and lays the alarm as the host does ---
	var copy := colony_at(home, 41, true)
	await frames(3)
	var news := func() -> void: copy.from_bytes(ants.state_bytes())
	news.call()
	await frames(2)
	check("the puppet's colony is the host's (same nest and trail)", copy.colony.nest().distance_to(nest) < 0.01 and absf(copy.colony.trail_length() - colony.trail_length()) < 0.01)
	put_runner(spot)
	var echoed := false
	for i in 120:
		await physics_frame
		if i % 6 == 0:
			news.call()
		if copy.colony.alarm_up and copy.colony.target.is_finite():
			echoed = true
			break
	check("the puppet raises the alarm when the host does", echoed)
	put_runner(Vector3(0.0, 0.0, 0.0))
	ants._calm()
	news.call()
	await frames(2)
	check("and lays it when the host does", not copy.colony.alarm_up)
	check("the puppet catches nobody", caught.all(func(c: Array) -> bool: return c[1] != copy))
	# (MazeEnemies sends it with the rest)
	var holder := MazeEnemies.new()
	holder.maze = maze
	stage.add_child(holder)
	var packed := holder.add(MazeAnts.new(), home, 0.0, 41)
	await frames(3)
	var bytes := holder.pack()
	check("MazeEnemies packs it", bytes.size() == 1 + MazeEnemy.STATE_SIZE and (packed as MazeAnts).ready_to_go())
	holder.queue_free()
	copy.queue_free()

	# --- What a frame of it costs ---
	var started := Time.get_ticks_usec()
	for i in 200:
		colony._process(1.0 / 60.0)
	var each := (Time.get_ticks_usec() - started) / 200.0
	check("a frame of a colony costs little", each < 600.0, "(%.0f us, %d ants)" % [each, colony.ants.size()])
	started = Time.get_ticks_usec()
	for i in 200:
		ants._physics_process(1.0 / 60.0)
	each = (Time.get_ticks_usec() - started) / 200.0
	check("and its thinking little", each < 300.0, "(%.0f us)" % each)

	await clear()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


# Points by the passages from `from` to the cell within a dozen steps that is furthest from the colony's trail.
func _escape_from(from: Vector3, colony: AntColony) -> Array:
	var here := maze.cell_at(from)
	var steps := nav.field(here)
	var best := here
	var far := -1.0
	for cell in nav.lairs(1):
		var d := steps[maze.index(cell)]
		if d < 4 or d > 12:
			continue
		var off := colony.off_trail(nav.point(cell)).x
		if off > far:
			far = off
			best = cell
	var points: Array = []
	for cell in nav.path(here, best):
		points.append(nav.point(cell))
	return points


# Points by the passages from `from`, going `cells` cells further from `away`
# (as far as there is), or with `trail_of`, further from that colony's trail.
func _away_from(from: Vector3, away: Vector3, cells: int, trail_of: AntColony = null) -> Array:
	var points: Array = []
	var at := maze.cell_at(from)
	var came := {at: true}
	for k in cells:
		var pick := at
		var far := -1.0
		for step: Vector2i in Maze.STEPS:
			var next := at + step
			if maze.blocked(at, step) or came.has(next) or not nav.allowed(next):
				continue
			var d := nav.point(next).distance_to(away) if trail_of == null else trail_of.off_trail(nav.point(next)).x + nav.point(next).distance_to(away) * 0.1
			if d > far:
				far = d
				pick = next
		if pick == at:
			break
		came[pick] = true
		at = pick
		points.append(nav.point(at))
	return points
