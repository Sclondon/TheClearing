extends SceneTree
## The hunters that climb (MazeEnemy's CLIMBING: HighWays, HighClimb; the user,
## 2026-10-18: "more creatures should be able to climb things"), headless, in a bare
## scene: a maze from MazeBuilder and the boy up on its mezzanine (the ledge along the
## walls). The high ways of the first section; a panther (a leap), a tribesman (hand
## over hand) and a colony of giant ants (each up the face) coming after him one at a
## time and getting up to him; a puppet panther following its host up; and what the
## climbing costs.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/climbers_test.gd
##
## With a folder after `--` (and a real window, not --headless), it saves a picture
## of each mid-climb there:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tests/climbers_test.gd -- <folder>
##
## `-- all` puts every other kind that climbs after him too (the deinonychus, the
## clown, a lizard person, an imp, a mantis, a mushroom zombie, the psychic child
## following him, a swarm of rats).
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var nav: MazeNav
var builder: MazeBuilder
var boy
var ways: HighWays
var failures := 0
var caught_by: Array = []
var folder := ""
## The rest that climb too (`-- all`).
var every := false
var camera: Camera3D


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
	var args := OS.get_cmdline_user_args()
	every = args.has("all")
	args.erase("all")
	if args.size() > 0:
		folder = args[0]
		DirAccess.make_dir_recursive_absolute(folder)
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	builder = MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.name = "Player"
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	if folder != "":
		MazeLight.put(stage)
		camera = Camera3D.new()
		camera.fov = 60.0
		stage.add_child(camera)
		camera.make_current()
	_run.call_deferred()


func spawn(one: MazeEnemy, at: Vector3) -> MazeEnemy:
	one.maze = maze
	one.position = at + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught_by.clear()


## Somewhere up on the mezzanine over a hall of the first section, away from the
## clearing: [where he stands on it, the way out from its front, a spot on the hall's
## floor along the wall from there `away` metres].
func ledge_spot(away := 13.0) -> Array:
	var lairs := {}
	for cell: Vector2i in nav.lairs(4):
		lairs[cell] = true
	for s in ways.size():
		if ways.kinds[s] != HighWays.Kind.LEDGE or (ways.fronts[s] as Array).is_empty():
			continue
		for front: Array in ways.fronts[s]:
			var a: Vector3 = front[0]
			var b: Vector3 = front[1]
			var out: Vector3 = front[2]
			if a.distance_to(b) < 24.0:
				continue
			var middle := (a + b) * 0.5
			var hall := middle + out * 3.0
			if not lairs.has(maze.cell_at(hall)) or maze.ring_of(maze.cell_at(hall)) != 1:
				continue
			var along := (b - a).normalized()
			var floor_at := middle + out * 3.0 + along * away
			floor_at.y = maze.ground_height(floor_at)
			if ways.in_wall(floor_at) or not nav.clear_of_walls(floor_at, 0.6) or not nav.line_free(hall, floor_at, 0.3):
				continue
			return [middle - out * 0.45 + Vector3.UP * 0.1, out, floor_at]
	return []


func put_boy(at: Vector3, facing: Vector3) -> void:
	boy.global_position = at
	boy.velocity = Vector3.ZERO
	boy.set(&"facing_yaw", atan2(facing.x, facing.z))


## A picture from the hall, looking at `at` (a real window only).
func shot(name: String, at: Vector3, out: Vector3) -> void:
	if folder == "":
		return
	var side := out.cross(Vector3.UP).normalized()
	camera.global_position = Vector3(at.x, maxf(at.y - 1.0, maze.ground_height(at) + 1.6), at.z) + out * 6.0 + side * 3.0
	camera.look_at(at + Vector3.UP * 0.4)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func _run() -> void:
	await frames(10)

	# --- The high ways ---
	ways = HighWays.of(maze, 1, builder.layout)
	var counts := [0, 0, 0]
	var with_fronts := 0
	for s in ways.size():
		counts[ways.kinds[s]] += 1
		if not (ways.fronts[s] as Array).is_empty():
			with_fronts += 1
	check("the first section's high ways are made from its layout", ways.size() > 40 and counts[HighWays.Kind.LEDGE] > 40,
		"(%d surfaces: %d ledges, %d terraces, %d bridges; in %.1f ms)" % [ways.size(), counts[0], counts[1], counts[2], ways.made_in])
	check("nearly all can be climbed to (have a front)", with_fronts > ways.size() * 0.8, "(%d of %d)" % [with_fronts, ways.size()])
	var spot := ledge_spot()
	check("a stretch of mezzanine over a hall to stand on", not spot.is_empty())
	if spot.is_empty():
		_end()
		return
	var on: Vector3 = spot[0]
	var out: Vector3 = spot[1]
	var floor_at: Vector3 = spot[2]
	var high: float = on.y - maze.ground_height(on)
	put_boy(on, -out)
	await wait(0.5)
	check("he stands on the mezzanine, %.1f m up" % high, absf(boy.global_position.y - on.y) < 0.4 and ways.under(boy.global_position) >= 0,
		"(at %.2f, its top %.2f)" % [boy.global_position.y, on.y])

	# --- Each of them, after him ---
	var panther := MazePanther.new()
	panther.lie_up = false
	await _after_him("a panther", panther, floor_at, on, out, 30.0)
	var tribesman := MazeTribesman.new()
	await _after_him("a tribesman", tribesman, floor_at, on, out, 40.0)
	var ants := MazeAnts.new()
	ants.sound = false
	await _after_him("a colony of giant ants", ants, floor_at, on, out, 40.0)
	if every:
		# (the rest that climb, with `-- all`)
		await _after_him("a deinonychus", MazeDeinonychus.new(), floor_at, on, out, 30.0)
		await _after_him("a clown", MazeClown.new(), floor_at, on, out, 30.0)
		await _after_him("a lizard person", MazeLizardPerson.new(), floor_at, on, out, 40.0)
		await _after_him("an imp", MazeImp.new(), floor_at, on, out, 40.0)
		await _after_him("a mantis", MazeMantis.new(), on + out * 3.0 + Vector3.DOWN * (on.y - maze.ground_height(on)), on, out, 40.0)
		await _after_him("a mushroom zombie", MazeMushroomZombie.new(), floor_at, on, out, 90.0)
		await _after_him("a psychic child", MazePsychicChild.new(), floor_at, on, out, 60.0)
		await _after_him("a swarm of rats", MazeRatSwarm.new(), floor_at, on, out, 40.0)

	# --- A puppet panther follows its host up ---
	clear()
	put_boy(on, -out)
	await wait(0.3)
	var host := spawn(MazePanther.new(), floor_at) as MazePanther
	host.lie_up = false
	var copy := MazePanther.new()
	copy.lie_up = false
	copy.puppet = true
	spawn(copy, floor_at)
	await frames(2)
	host.notice(boy)
	var worst := 0.0
	var saw := {}
	for i in 60 * 25:
		await physics_frame
		copy.from_bytes(host.state_bytes())
		if host.aloft != 0 and i > 30:
			if saw.is_empty():
				put_boy(on + out.cross(Vector3.UP).normalized() * 6.0, -out)
			saw[copy.aloft] = true
			if copy.aloft == host.aloft:
				worst = maxf(worst, absf(copy.global_position.y - host.global_position.y))
		if not caught_by.is_empty():
			break
	check("a puppet goes up with its host (heard how: %s)" % [saw.keys()], saw.has(HighClimb.Aloft.ON) and (saw.has(HighClimb.Aloft.LEAP) or saw.has(HighClimb.Aloft.CLIMB)),
		"(at worst %.2f m off its height)" % worst)
	check("and keeps to its height (no falling)", worst < 1.2, "(%.2f m)" % worst)
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] == host))

	# --- What it costs ---
	clear()
	put_boy(floor_at + out * 2.0, -out)
	var idle := spawn(MazePanther.new(), floor_at) as MazePanther
	idle.lie_up = false
	await frames(2)
	idle.notice(boy)
	var started := Time.get_ticks_usec()
	for i in 10000:
		idle._ways_up(1.0 / 60.0, 0.32, 5.0)
	var each := (Time.get_ticks_usec() - started) / 10000.0
	check("looking whether a hunter needs to climb is cheap (its quarry on the floor)", each < 20.0, "(%.2f us a step)" % each)
	var asks := 2000
	started = Time.get_ticks_usec()
	for i in asks:
		ways.under(on + Vector3(randf_range(-20.0, 20.0), 0.0, randf_range(-20.0, 20.0)))
	check("and finding the surface someone stands on", (Time.get_ticks_usec() - started) / float(asks) < 40.0,
		"(%.2f us)" % ((Time.get_ticks_usec() - started) / float(asks)))
	clear()
	_end()


## Puts `one` in the hall at `from`, sets it after the boy up on the ledge at `on`,
## and checks it gets up to him within `seconds`. (He looks at the wall, not at it:
## the clown and the gnomes come only unwatched.)
func _after_him(what: String, one: MazeEnemy, from: Vector3, on: Vector3, out: Vector3, seconds: float) -> void:
	clear()
	put_boy(on, out)
	await wait(0.3)
	spawn(one, from)
	await frames(3)
	var colony := one as MazeAnts
	var rats := one as MazeRatSwarm
	var child := one as MazePsychicChild
	if colony:
		await wait(1.0, func() -> bool: return colony.ready_to_go())
		colony._raise(boy)
	elif rats:
		await wait(1.0, func() -> bool: return rats.swarm != null)
		rats.notice(boy)
	elif child:
		child.followed = boy
		child.mode = MazePsychicChild.Mode.FOLLOW
	elif one is MazeMushroomZombie:
		# (blind: it hears him, below)
		(one as MazeMushroomZombie)._hear(boy, boy.global_position)
	else:
		one.notice(boy)
	var highest := 0.0
	var nearest := INF
	var shots := {}
	var walked := false
	var high := on.y - 0.1 - maze.ground_height(on)
	var got := false
	var ticks := 0
	for i in int(seconds * 60.0):
		ticks = i
		await physics_frame
		if one is MazeMushroomZombie and i % 20 == 0:
			# (blind: he is heard moving about up there)
			(one as MazeMushroomZombie)._hear(boy, boy.global_position)
		if child:
			child.mode = MazePsychicChild.Mode.FOLLOW if not child.climbing_now() else child.mode
		var body := one.global_position
		if rats:
			body = rats.swarm.front
			highest = maxf(highest, body.y - maze.ground_height(on))
		elif colony:
			# (the ants: the one nearest him, and the highest)
			body = colony.colony.front
			for k in colony.colony.ants.size():
				highest = maxf(highest, colony.colony.ant_position(k).y - maze.ground_height(on))
			var up_ant := -1
			for k in colony.colony.ants.size():
				if colony.colony.ant_state(k) == AntColony.State.CLIMB and colony.colony.ant_position(k).y - maze.ground_height(on) > 5.0:
					up_ant = k
			if not shots.has("climb") and up_ant >= 0:
				shots["climb"] = true
				await shot("ants_climbing", colony.colony.ant_position(up_ant), out)
		else:
			highest = maxf(highest, body.y - maze.ground_height(on))
			if not shots.has("up") and (one.aloft == HighClimb.Aloft.LEAP or one.aloft == HighClimb.Aloft.CLIMB) and body.y - maze.ground_height(body) > 4.0:
				shots["up"] = true
				await shot(what.get_slice(" ", 1) + "_mid_climb", body, out)
				# (and he moves off along the ledge: it must come along it to him)
				put_boy(on + out.cross(Vector3.UP).normalized() * 6.0, -out)
			if one.aloft == HighClimb.Aloft.ON and body.y - maze.ground_height(body) > high - 1.0:
				walked = true
		var d := Vector2(body.x - boy.global_position.x, body.z - boy.global_position.z).length()
		if absf(body.y - boy.global_position.y) < 1.5:
			nearest = minf(nearest, d)
		if not caught_by.is_empty() or (colony and colony.colony.on_target > 0) or (rats and rats.swarm.on_target > 0) \
				or (child and walked and nearest < 1.8):
			got = true
			break
	var took := float(ticks) / 60.0
	check("%s gets up to him (%.1f m up)" % [what, high], got and (walked or colony != null or rats != null),
		"(highest %.1f m, nearest at his height %.1f m, %s%s; %.1f s of the game)" % [highest, nearest, "caught him" if not caught_by.is_empty() else ("on him" if got else "not there"), ", along the ledge after him" if walked else "", took])


func _end() -> void:
	print("CLIMBERS TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures > 0 else 0)
