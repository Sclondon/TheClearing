extends SceneTree
## The stegosaurus (scripts/enemies/maze_stegosaurus.gd on creatures/stegosaurus),
## headless, in a bare scene: a maze from MazeBuilder and the boy in it. In
## turn: alone, it grazes slowly about where it was put; someone creeping by
## out of its space it does not notice; someone running past further off it
## notices and watches, but lets go; the boy too near, behind its flank, it
## turns side on to and warns (a rumble, the tail up), then swings its tail at
## and he is thrown limp and caught; backing off in the warning, he is let be
## and nothing is swung; up out of its reach it ignores him; a calf keeps by
## its mother, and near the calf is too near her; a puppet follows the host
## and swings when it does; its sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/stegosaurus_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
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
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	if boy.is_limp:
		boy.recover()
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func steg_at(at: Vector3, yaw := 0.0, one: MazeStegosaurus = null) -> MazeStegosaurus:
	var steg := one if one else MazeStegosaurus.new()
	steg.maze = maze
	steg.position = at + Vector3.UP * 0.05
	steg.rotation.y = yaw
	stage.add_child(steg)
	steg.caught.connect(func(player: Node3D) -> void: caught_by.append([player, steg]))
	return steg


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy or child is CharacterBody3D and child != boy:
			child.queue_free()
	caught_by.clear()
	await frames(2)


func mode_name(steg: MazeStegosaurus) -> String:
	return MazeStegosaurus.Mode.keys()[steg.mode]


## A stand-in for someone moving at `speed` (it keeps its velocity: nothing drives it).
func runner_at(at: Vector3, speed: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	stage.add_child(body)
	body.global_position = at
	body.velocity = Vector3(speed, 0.0, 0.0)
	return body


func _run() -> void:
	await frames(10)
	# A long straight hall to put it in, room all round it.
	var hall := Vector2i(-1, -1)
	var step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(4):
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var ok := true
			for k in [-1, 1, 2]:
				if not maze.inside(cell + s * k) or maze.in_clearing(cell + s * k):
					ok = false
			if ok and not maze.blocked(cell, s) and not maze.blocked(cell, -s) and not maze.blocked(cell + s, s):
				hall = cell
				step = s
				break
		if hall.x >= 0:
			break
	check("a straight hall to put it in", hall.x >= 0)
	var way := Vector3(step.x, 0.0, step.y)
	var middle: Vector3 = maze.world(hall)
	middle.y = maze.ground_height(middle)
	var yaw := atan2(way.x, way.z)
	var left := Vector3(cos(yaw), 0.0, -sin(yaw))
	# (the side of it with room)
	var room := 1.0 if nav.line_free(middle, middle + left * 6.0, 0.4) else -1.0
	var far_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(4):
		if nav.distance(hall, cell) > 8:
			far_cell = cell
			break

	# --- Alone, it grazes ---
	# (near enough that it is posed, far enough not to be noticed standing still)
	var near_cell: Vector2i = hall
	for cell: Vector2i in nav.lairs(1):
		if nav.distance(hall, cell) == 3:
			near_cell = cell
			break
	put_boy(maze.world(near_cell))
	var steg := steg_at(middle, yaw)
	var furthest := 0.0
	var grazed := false
	for i in 20 * 60:
		await physics_frame
		furthest = maxf(furthest, steg.global_position.distance_to(middle))
		grazed = grazed or steg.steg.grazing
	check("alone, it grazes", steg.mode == MazeStegosaurus.Mode.GRAZE and grazed and not steg.hunting(), "(%s)" % mode_name(steg))
	check("slowly, near where it was put", furthest < steg.territory_range + 1.0, "(at most %.1f m off in 20 s)" % furthest)
	await clear()

	# --- Creeping by out of its space: not noticed ---
	steg = steg_at(middle, yaw)
	steg.walk_speed = 0.0
	await frames(5)
	put_boy(steg.global_position + left * room * 5.6)
	var noticed := await wait(3.0, func() -> bool: return steg.hunting() or steg.mode != MazeStegosaurus.Mode.GRAZE)
	check("standing (or creeping) 5.6 m from its body, he is not noticed", not noticed, "(%s, %.1f m)" % [mode_name(steg), steg.body_gap(boy.global_position)])
	put_boy(maze.world(far_cell))
	# --- Someone running past further off: noticed and watched, let go ---
	var running := runner_at(steg.global_position + left * room * 8.5 + Vector3.UP * 0.1, 4.4)
	steg.targets = [running]
	var watched := await wait(2.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.WATCH)
	await frames(10)
	check("someone running 8.5 m off it notices, and watches", watched and steg.steg.look_at_point.is_finite(), "(%s)" % mode_name(steg))
	var warned := await wait(2.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.WARN)
	check("but out of its space, it does not warn them", not warned)
	running.global_position = steg.global_position + left * room * 40.0
	var calm := await wait(steg.calm_time + 3.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.GRAZE)
	check("gone, it goes back to grazing", calm, "(%s)" % mode_name(steg))
	running.queue_free()
	steg.targets = []
	await clear()

	# --- Too near, behind its flank: the warning, then the swing ---
	steg = steg_at(middle, yaw)
	steg.walk_speed = 0.0
	var rumbles := [0]
	var swings := [0]
	steg.steg.rumbled.connect(func() -> void: rumbles[0] += 1)
	steg.steg.swung.connect(func(_side: float) -> void: swings[0] += 1)
	await frames(5)
	var behind: Vector3 = steg.hips_at() + left * room * 3.0 - way * 1.2
	put_boy(behind)
	var warning := await wait(1.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.WARN)
	await frames(35)
	check("the boy too near (3 m off its flank, standing): it warns", warning and steg.steg.warning, "(%s)" % mode_name(steg))
	check("rumbling, its tail towards him", rumbles[0] >= 1 and steg.side == room, "(%d rumbles, side %d, he is on %d)" % [rumbles[0], steg.side, room])
	var started := Time.get_ticks_msec()
	var swung := await wait(steg.warn_time + 1.5, func() -> bool: return steg.mode == MazeStegosaurus.Mode.SWING)
	var warned_for := (Time.get_ticks_msec() - started) / 1000.0
	check("a long, clear warning first", swung and swings[0] == 1, "(swung %s)" % swung)
	var limp := [false]
	var hit := await wait(4.0, func() -> bool:
		limp[0] = limp[0] or boy.is_limp
		return not caught_by.is_empty())
	check("then the tail comes round: he is thrown limp and caught", hit and limp[0] and caught_by[0][0] == boy, "(limp %s, caught %d)" % [limp[0], caught_by.size()])
	var bearing: float = absf(angle_difference(steg.facing_yaw, atan2((behind - steg.hips_at()).x, (behind - steg.hips_at()).z)))
	check("it had turned side on to him", bearing > 1.3 and bearing < 2.6, "(%.0f deg from its nose)" % rad_to_deg(bearing))
	var chased := steg.global_position.distance_to(middle)
	check("it never chases", chased < 1.5, "(%.1f m from where it stood)" % chased)
	await clear()

	# --- Backing off in the warning: let be ---
	steg = steg_at(middle, yaw)
	steg.walk_speed = 0.0
	swings[0] = 0
	steg.steg.swung.connect(func(_side: float) -> void: swings[0] += 1)
	await frames(5)
	put_boy(steg.hips_at() + left * room * 3.5 - way * 1.0)
	warning = await wait(1.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.WARN)
	await frames(50)
	put_boy(steg.hips_at() + left * room * 12.0)
	var swung_anyway := await wait(steg.warn_time + 1.0, func() -> bool: return steg.mode == MazeStegosaurus.Mode.SWING)
	check("he backs off out of its space while it warns: no swing", warning and not swung_anyway and swings[0] == 0 and caught_by.is_empty(), "(%s)" % mode_name(steg))
	await clear()

	# --- Up out of its reach ---
	var perch := Node3D.new()
	stage.add_child(perch)
	put_boy(maze.world(far_cell))
	steg = steg_at(middle, yaw)
	steg.walk_speed = 0.0
	await frames(5)
	perch.global_position = steg.hips_at() + left * room * 2.5 + Vector3.UP * 4.0
	steg.targets = [perch]
	warned = await wait(3.0, func() -> bool: return steg.mode != MazeStegosaurus.Mode.GRAZE)
	check("someone up high over it it ignores", not warned, "(%s)" % mode_name(steg))
	perch.queue_free()
	await clear()

	# --- A calf keeps by its mother; near the calf is too near ---
	put_boy(maze.world(far_cell))
	var family := MazeStegosaurus.family(1)
	var mother: MazeStegosaurus = steg_at(middle, yaw, family[0])
	mother.walk_speed = 0.0
	var calf: MazeStegosaurus = steg_at(middle + left * room * 3.5 + way * 2.0, yaw, family[1])
	var kept := 0.0
	for i in 8 * 60:
		await physics_frame
		kept = maxf(kept, calf.global_position.distance_to(mother.global_position))
	check("the calf keeps by its mother", kept < 6.5 and calf.calf and calf.steg.scale.x < 0.5, "(at most %.1f m off)" % kept)
	put_boy(calf.global_position + (calf.global_position - mother.global_position).normalized() * 4.0)
	await frames(2)
	var protective := await wait(1.5, func() -> bool: return mother.mode == MazeStegosaurus.Mode.WARN)
	check("near the calf is too near its mother", protective, "(%s, %.1f m from her body)" % [mode_name(mother), mother.body_gap(boy.global_position)])
	await wait(6.0)
	check("the calf catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != calf))
	put_boy(maze.world(far_cell))
	await clear()

	# --- A puppet follows the host and swings when it does ---
	var host := steg_at(middle, yaw)
	host.walk_speed = 0.0
	var copy := MazeStegosaurus.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = host.position
	stage.add_child(copy)
	copy.caught.connect(func(player: Node3D) -> void: caught_by.append([player, copy]))
	var copied := [0]
	copy.steg.swung.connect(func(_side: float) -> void: copied[0] += 1)
	var off := 0.0
	for i in 420:
		await physics_frame
		if i == 30:
			put_boy(host.hips_at() + left * room * 3.0 - way * 1.2)
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30:
			off = maxf(off, copy.global_position.distance_to(host.global_position))
	check("the puppet keeps up with the host", off < 1.5, "(at most %.2f m off)" % off)
	check("the puppet swings when the host does", copied[0] >= 1 and copy.side == host.side, "(%d)" % copied[0])
	check("the puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	await clear()

	# --- Its sounds are made ---
	check("its sounds are made", Stegosaurus.rumble_sound().data.size() > 1000 and Stegosaurus.bellow_sound().data.size() > 1000 and Stegosaurus.swish_sound().data.size() > 1000 and Stegosaurus.thud_sound().data.size() > 1000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
