extends SceneTree
## The giant carnivorous plants (MazeFlytrap, MazeSundew, MazePitcher, driving
## creatures/carnivorous_plants/), headless, in a bare maze from MazeBuilder:
##
## - a flytrap put in the middle of a cell grows against its wall; with nobody
##   about it stays open; someone stepping into it makes it shiver (the
##   warning) and, still in it a moment later, is caught as it snaps; it opens
##   again slowly; someone who steps out at once after the shiver, or runs
##   straight through, is not caught; it kills a deer that stands in it and
##   digests it, shut, full; a puppet copy shivers and snaps when the host's does;
## - a sundew slows a Player on its leaves, then holds him nearly still, jumping
##   tears him free sooner, it lets go and he gets his speed back off it; it
##   kills a small creature it holds;
## - a pitcher takes whoever walks onto its lip and nobody walking past it, and
##   swallows a deer; a puppet copy gulps when the host's does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/carnivorous_plants_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO


var stage: Node3D
var maze: Maze
var nav: MazeNav
var failures := 0
var caught: Array = []


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
	Ecology.put(stage, 5)
	_run.call_deferred()


func put(enemy: MazeEnemy, at: Vector3, yaw := 0.0, puppet := false) -> MazeEnemy:
	enemy.maze = maze
	enemy.puppet = puppet
	enemy.position = at + Vector3.UP * 0.05
	enemy.rotation.y = yaw
	stage.add_child(enemy)
	if not puppet:
		enemy.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return enemy


func dummy(at: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.add_to_group(&"maze_players")
	return d


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child is Dummy or child is CharacterBody3D:
			child.free()
	caught.clear()


## A hall cell (a straight run of passage) well out of the clearing, with walls both sides.
func hall() -> Vector2i:
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
				return cell
	return nav.lairs(4)[0]


## Walks a dummy from `from` to `to` at `speed`, a physics frame at a time; stops early if `until` says.
func walk(who: Node3D, from: Vector3, to: Vector3, speed: float, until := Callable()) -> void:
	who.global_position = from
	var steps := int(from.distance_to(to) / speed * 60.0)
	for i in steps:
		who.global_position = from.lerp(to, float(i + 1) / steps)
		who.set(&"velocity", (to - from).normalized() * speed)
		await physics_frame
		if until.is_valid() and until.call():
			return


func _run() -> void:
	var cell := hall()
	var middle := maze.world(cell)
	print("hall %s" % cell)

	# --- The flytrap ---
	var trap: MazeFlytrap = put(MazeFlytrap.new(), middle)
	var out := Vector3(sin(trap.rotation.y), 0.0, cos(trap.rotation.y))
	var rosette := trap.figure.global_position
	var wall_at := -1.0
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(rosette + Vector3.UP, rosette + Vector3.UP - out * 6.0, 1))
	if not hit.is_empty():
		wall_at = (hit["position"] as Vector3).distance_to(rosette + Vector3.UP)
	check("put in a cell's middle, a flytrap grows with its rosette against a wall", wall_at > 0.0 and wall_at < 1.5, "(the wall %.2f m behind it)" % wall_at)
	await wait(2.0)
	check("with nobody about it stays open", trap.mode == MazeFlytrap.Mode.OPEN and trap.figure.is_open())
	var mouth := trap.figure.mouth()
	var side := Vector3(out.z, 0.0, -out.x)
	var who := dummy(mouth + out * 5.0)
	await walk(who, mouth + out * 5.0, mouth, 1.6, func() -> bool: return trap.mode != MazeFlytrap.Mode.OPEN)
	check("someone stepping into it makes it shiver (the warning)", trap.mode == MazeFlytrap.Mode.TOUCHED and trap.figure._twitch > 0.0, "(%s)" % MazeFlytrap.Mode.keys()[trap.mode])
	check("and nobody is caught by the shiver", caught.is_empty())
	var got := await wait(2.0, func() -> bool: return caught.has(who))
	check("still in it a moment later, they are caught as it snaps", got and trap.figure.shut > 0.9, "(shut %.2f)" % trap.figure.shut)
	who.global_position = mouth + out * 8.0
	var opened := await wait(16.0, func() -> bool: return trap.mode == MazeFlytrap.Mode.OPEN)
	check("then it opens again, slowly", opened and trap.figure.is_open())
	caught.clear()

	# Step in, and straight back out when it shivers
	await walk(who, mouth + out * 5.0, mouth + out * 0.5, 1.6, func() -> bool: return trap.mode == MazeFlytrap.Mode.TOUCHED)
	var at := who.global_position
	await walk(who, at, at + out * 3.0, 4.0)
	await wait(1.5)
	check("someone who steps out as it shivers is not caught", caught.is_empty() and trap.mode == MazeFlytrap.Mode.OPEN, "(%s)" % MazeFlytrap.Mode.keys()[trap.mode])
	await wait(3.0)
	# Running straight through it, across its mouth
	await walk(who, mouth - side * 4.0, mouth + side * 4.0, 4.4)
	await wait(1.5)
	check("someone running straight through it is not caught", caught.is_empty(), "(%s)" % MazeFlytrap.Mode.keys()[trap.mode])
	who.global_position = mouth + out * 20.0
	await wait(10.0, func() -> bool: return trap.mode == MazeFlytrap.Mode.OPEN)

	# A deer that stands in it is killed, and digested
	var deer: MazeDeer = put(MazeDeer.new(), mouth + Vector3.UP * 0.1)
	for i in 120:
		deer.global_position = Vector3(mouth.x, deer.global_position.y, mouth.z)
		await physics_frame
		if deer.dead:
			break
	check("a deer standing in it is killed", deer.dead)
	await wait(0.5)
	check("and it stays shut on it, full, digesting", trap.mode == MazeFlytrap.Mode.DIGESTING and trap.figure.full and trap.figure.is_shut(), "(%s)" % MazeFlytrap.Mode.keys()[trap.mode])

	# A puppet copy shivers and snaps as the host's does
	clear()
	trap = put(MazeFlytrap.new(), middle)
	var copy: MazeFlytrap = put(MazeFlytrap.new(), middle, 0.0, true)
	copy.from_bytes(trap.state_bytes())
	who = dummy(trap.figure.mouth() + out * 6.0)
	var copy_twitched := false
	var copy_snapped := false
	mouth = trap.figure.mouth()
	for i in 240:
		if i < 90:
			who.global_position = (mouth + out * 6.0).lerp(mouth, i / 90.0)
		if i % 6 == 0:
			copy.from_bytes(trap.state_bytes())
		await physics_frame
		copy_twitched = copy_twitched or copy.figure._twitch > 0.0
		copy_snapped = copy_snapped or copy.figure.is_snapping() or copy.figure.is_shut()
	check("a puppet flytrap shivers when the host's does", copy_twitched)
	check("and snaps when it does", copy_snapped and trap.figure.is_shut())
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, trap.state_bytes().size() == MazeEnemy.STATE_SIZE)
	clear()

	# --- The sundew ---
	var dew: MazeSundew = put(MazeSundew.new(), middle)
	var boy = load("res://player.tscn").instantiate()
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	boy.takes_input = false
	var walk_was: float = boy.walk_speed
	boy.global_position = dew.global_position + Vector3(1.4, 0.3, 0.0).rotated(Vector3.UP, dew.rotation.y)
	await wait(0.6)
	check("on a sundew's leaves a Player is slowed", boy.walk_speed < walk_was * 0.8, "(walk %.2f, was %.2f)" % [boy.walk_speed, walk_was])
	var held := await wait(2.0, func() -> bool: return dew.held_left > 0.0)
	check("and after a moment held nearly still", held and boy.walk_speed < walk_was * 0.2, "(walk %.2f)" % boy.walk_speed)
	await wait(0.3)
	check("its tentacles bend over him", dew.figure.grip > 0.1 and dew.figure.held.is_finite(), "(grip %.2f)" % dew.figure.grip)
	var left: float = dew.held_left
	boy.jumped.emit()
	await wait(0.1)
	check("jumping tears him free sooner", dew.held_left < left - dew.struggle * 0.8, "(%.2f s left, was %.2f)" % [dew.held_left, left])
	await wait(dew.hold_time + 0.5, func() -> bool: return dew.held_left <= 0.0)
	check("then it lets go", dew.held_left <= 0.0 and dew.free_in > 0.0)
	boy.global_position = dew.global_position + Vector3(6.0, 0.3, 0.0)
	await wait(0.5)
	check("and off it he has his speed back", is_equal_approx(boy.walk_speed, walk_was), "(walk %.2f)" % boy.walk_speed)
	boy.free()
	# It eats what is small enough (a deer, for one that takes things that big)
	dew.prey_size = 2
	dew.kill_time = 1.0
	var fawn: MazeDeer = put(MazeDeer.new(), dew.global_position + Vector3(1.3, 0.1, 0.0).rotated(Vector3.UP, dew.rotation.y))
	for i in 180:
		fawn.global_position = dew.global_position + Vector3(1.3, 0.1, 0.0).rotated(Vector3.UP, dew.rotation.y)
		await physics_frame
		if fawn.dead:
			break
	check("a sundew kills a creature small enough that it holds", fawn.dead)
	clear()

	# --- The pitcher ---
	var pit: MazePitcher = put(MazePitcher.new(), middle)
	var lip := pit.global_position
	out = Vector3(sin(pit.rotation.y), 0.0, cos(pit.rotation.y))
	side = Vector3(out.z, 0.0, -out.x)
	who = dummy(lip + out * 6.0)
	await walk(who, lip + side * 5.0 + out * 2.2, lip - side * 5.0 + out * 2.2, 1.6)
	check("someone walking past a pitcher is not taken", caught.is_empty())
	await walk(who, lip + out * 5.0, lip, 1.6, func() -> bool: return caught.has(who))
	check("someone walking onto its lip goes in (caught)", caught.has(who), "(%.2f m from its middle)" % who.global_position.distance_to(lip))
	check("and its lid drops", pit.mode == MazePitcher.Mode.FED and pit.figure._lid_goal > 0.5)
	who.global_position = lip + out * 20.0
	await wait(pit.fed_time + 1.0, func() -> bool: return pit.mode == MazePitcher.Mode.OPEN)
	check("then it lifts its lid again", pit.mode == MazePitcher.Mode.OPEN)
	var copy_pit: MazePitcher = put(MazePitcher.new(), middle, 0.0, true)
	copy_pit.from_bytes(pit.state_bytes())
	await wait(0.2)
	var deer2: MazeDeer = put(MazeDeer.new(), lip + Vector3.UP * 0.1)
	for i in 60:
		deer2.global_position = Vector3(lip.x, deer2.global_position.y, lip.z)
		await physics_frame
		if deer2.dead:
			break
	copy_pit.from_bytes(pit.state_bytes())
	await wait(0.1)
	check("it swallows a deer that walks onto it", deer2.dead and pit.mode == MazePitcher.Mode.DIGESTING)
	check("and a puppet copy gulps when the host's does", copy_pit.figure._lid_goal > 0.5 and copy_pit.swallows == pit.swallows, "(%d swallows, the host's %d)" % [copy_pit.swallows, pit.swallows])
	clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
