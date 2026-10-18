extends SceneTree
## The woolly mammoths (scripts/enemies/maze_mammoth.gd and maze_mammoth_calf.gd
## on creatures/mammoth), headless, in a bare scene: a maze from MazeBuilder and
## the boy in it. In turn:
## - a herd: a matriarch, cows and a calf, linked; the same herd from the same seed;
## - they graze, and walk on together to another place, the calf at its mother's side;
## - he comes into sight: heads up, trunks out to him, the matriarch rumbles;
## - nearer: the herd closes round the calf, the cows facing out; the matriarch
##   comes out, ears spread, and trumpets; then a mock charge that pulls up short;
## - backing away, they settle;
## - staying close by the calf: she charges, and he is trampled; stepping aside
##   at the last moment, she thunders past; up off the ground he is never charged;
## - a hunter near the herd: the ring, and she knocks it flying;
## - out on open ground (off the maze's grid) they graze and are alarmed by sight;
## - puppets follow their hosts, trumpeting with them; the sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/mammoth_test.gd
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


func put_boy(at: Vector3, face_to := Vector3.INF) -> void:
	if boy.is_limp:
		boy.recover()
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	if face_to.is_finite():
		var to: Vector3 = face_to - at
		boy.facing_yaw = atan2(to.x, to.z)


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.queue_free()
	caught_by.clear()
	await frames(3)


## A straight, wide run of passage `length` cells long from a cell well out of the
## clearing (room for a herd: clear 5 m either side of its middle): [start cell, step].
func long_hall(length: int) -> Array:
	for cell: Vector2i in nav.lairs(4):
		for step: Vector2i in Maze.STEPS:
			var at := cell
			var run := 0
			var side := Vector3(step.y, 0.0, -step.x)
			while run < length and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				var middle: Vector3 = nav.point(at)
				if not (nav.clear_of_walls(middle + side * 5.0, 0.5) and nav.clear_of_walls(middle - side * 5.0, 0.5)):
					break
				at += step
				run += 1
			if run == length:
				return [cell, step]
	return []


## Puts a herd in round `at` (the matriarch at it), facing `facing`.
func herd_at(at: Vector3, facing: Vector3, seed_value := 3, on_maze := true) -> Array[MazeMammoth]:
	var herd := MazeMammoth.herd_of(4, seed_value)
	for k in herd.size():
		var one: MazeMammoth = herd[k]
		one.maze = maze
		one.seed_choices(seed_value * 10 + k)
		# (along the hall, a little to either side of its middle; the calf just ahead of the matriarch)
		var side := Vector3(facing.z, 0.0, -facing.x)
		var spots: Array[Vector3] = [Vector3.ZERO, -facing * 4.5 + side * 1.6, facing * 4.5 - side * 1.6, -facing * 2.0 - side * 2.4, facing * 8.5]
		var spot: Vector3 = at + spots[mini(k, spots.size() - 1)] if k < herd.size() - 1 else at + spots[3]
		one.position = spot + Vector3.UP * 0.05
		one.rotation.y = atan2(facing.x, facing.z)
		stage.add_child(one)
		one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return herd


func _run() -> void:
	await frames(10)
	var hall := long_hall(5)
	check("a long straight hall", not hall.is_empty())
	var start: Vector2i = hall[0]
	var step: Vector2i = hall[1]
	var way := Vector3(step.x, 0.0, step.y)
	var aside := Vector3(way.z, 0.0, -way.x)
	var far_end: Vector3 = nav.point(start + step * 4)
	var near_end: Vector3 = nav.point(start)

	# --- A herd ---
	var herd := MazeMammoth.herd_of(4, 3)
	var matriarch: MazeMammoth = herd[0]
	var young: MazeMammoth = herd.back()
	check("a herd of four: a matriarch, cows and a calf", herd.size() == 4 and matriarch.lead and young is MazeMammothCalf and herd.all(func(m: MazeMammoth) -> bool: return m.matriarch == matriarch and m.calf == young))
	check("the calf has a mother in the herd", young.mother != null and young.mother in herd and young.mother != young)
	var again := MazeMammoth.herd_of(4, 3)
	check("the same herd from the same seed", again[1].size == herd[1].size and again[2].size == herd[2].size)
	for one in herd + again:
		one.free()

	# --- Grazing, and moving on together ---
	put_boy(near_end - way * 80.0)
	boy.remove_from_group(&"maze_players")
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	young = herd.back()
	await wait(4.0)
	check("they graze", herd.all(func(m: MazeMammoth) -> bool: return m.mode == MazeMammoth.Mode.GRAZE) and matriarch.mammoth.grazing, "(%s)" % [herd.map(func(m: MazeMammoth) -> String: return MazeMammoth.Mode.keys()[m.mode])])
	matriarch._graze_left = 0.0
	var moving := await wait(2.0, func() -> bool: return matriarch.herd_mode == MazeMammoth.Mode.MOVE)
	var goal: Vector3 = matriarch.herd_goal
	var from: Vector3 = matriarch.global_position
	await wait(6.0)
	check("the matriarch walks on to another place", moving and matriarch.global_position.distance_to(goal) < from.distance_to(goal) - 2.0, "(%.1f m to %.1f m from it)" % [from.distance_to(goal), matriarch.global_position.distance_to(goal)])
	var together := herd.all(func(m: MazeMammoth) -> bool: return m.global_position.distance_to(matriarch.global_position) < 26.0)
	check("and the herd follows her", together)
	check("the calf at its mother's side", young.global_position.distance_to(young.mother.global_position) < 7.0, "(%.1f m)" % young.global_position.distance_to(young.mother.global_position))
	await clear()
	boy.add_to_group(&"maze_players")

	# --- The alarm, the ring, the display, the mock charge ---
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	young = herd.back()
	var rumbled := [false]
	var trumpeted := [false]
	matriarch.mammoth.rumbled.connect(func() -> void: rumbled[0] = true)
	matriarch.mammoth.trumpeted.connect(func() -> void: trumpeted[0] = true)
	put_boy(near_end - way * 30.0, far_end)
	await wait(1.0)
	put_boy(far_end - way * 23.0, far_end)
	var alarmed := await wait(3.0, func() -> bool: return matriarch.herd_mode == MazeMammoth.Mode.ALERT)
	await wait(1.0)
	check("he comes into sight: the herd is alarmed, the matriarch rumbles", alarmed and rumbled[0])
	check("heads up, trunks out to him", herd.all(func(m: MazeMammoth) -> bool: return m.mammoth.alert) and matriarch.mammoth.feeling)
	put_boy(far_end - way * 15.0, far_end)
	# (what she does, frame by frame, and how near she comes to him)
	var seen := {}
	var closest := [999.0]
	var watch := func() -> void:
		seen[matriarch.mode] = true
		if matriarch.mode == MazeMammoth.Mode.MOCK or matriarch.mode == MazeMammoth.Mode.RECOVER:
			closest[0] = minf(closest[0], matriarch._flat(boy.global_position))
	var ringed := await wait(3.0, func() -> bool:
		watch.call()
		return matriarch.herd_mode == MazeMammoth.Mode.RING)
	await wait(6.5, func() -> bool:
		watch.call()
		return false)
	var cows: Array = herd.filter(func(m: MazeMammoth) -> bool: return m != matriarch and m != young)
	var round_calf := cows.all(func(m: MazeMammoth) -> bool: return m.global_position.distance_to(young.global_position) < 8.0)
	var facing_out := cows.all(func(m: MazeMammoth) -> bool:
		var to_boy: Vector3 = (boy.global_position - m.global_position)
		return Vector3(sin(m.facing_yaw), 0.0, cos(m.facing_yaw)).dot(Vector3(to_boy.x, 0.0, to_boy.z).normalized()) > 0.0)
	check("nearer: the herd closes round the calf, the cows facing out", ringed and round_calf and facing_out)
	check("the matriarch spreads her ears and trumpets", seen.has(MazeMammoth.Mode.DISPLAY) and trumpeted[0])
	await wait(4.0, func() -> bool:
		watch.call()
		return false)
	check("then a mock charge that pulls up short", seen.has(MazeMammoth.Mode.MOCK) and seen.has(MazeMammoth.Mode.RECOVER) and caught_by.is_empty() and closest[0] > 4.0, "(came within %.1f m)" % closest[0])
	# Backing away: they settle
	put_boy(far_end - way * 60.0)
	var settled := await wait(12.0, func() -> bool: return matriarch.herd_mode in [MazeMammoth.Mode.GRAZE, MazeMammoth.Mode.MOVE])
	check("he backs away: they settle", settled and caught_by.is_empty())
	await clear()

	# --- Staying close by the calf: the charge ---
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	young = herd.back()
	matriarch.display_time = 1.0
	put_boy(far_end - way * 7.5, far_end)
	var charged := await wait(14.0, func() -> bool: return matriarch.mode == MazeMammoth.Mode.CHARGE)
	var top := [0.0]
	var trampled := await wait(5.0, func() -> bool:
		top[0] = maxf(top[0], Vector2(matriarch.velocity.x, matriarch.velocity.z).length())
		return not caught_by.is_empty())
	check("staying close by the calf after the warning: she charges", charged)
	check("she comes on fast (her charge is faster than a sprint), and he is trampled", trampled and caught_by[0][0] == boy and top[0] > boy.run_speed and matriarch.charge_speed > boy.sprint_speed, "(%.1f m/s from a standing start)" % top[0])
	await clear()
	# Stepping aside at the last moment
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	young = herd.back()
	matriarch.display_time = 1.0
	put_boy(far_end - way * 7.5, far_end)
	charged = await wait(14.0, func() -> bool: return matriarch.mode == MazeMammoth.Mode.CHARGE and matriarch._flat(boy.global_position) < 4.5)
	var heading := Vector3(sin(matriarch.facing_yaw), 0.0, cos(matriarch.facing_yaw))
	var across := Vector3(heading.z, 0.0, -heading.x)
	var dodge: Vector3 = boy.global_position + across * 6.0
	if not nav.clear_of_walls(dodge, 0.5):
		dodge = boy.global_position - across * 6.0
	put_boy(dodge)
	await wait(1.5)
	check("stepping aside at the last moment, she thunders past", charged and caught_by.is_empty(), "(%s)" % MazeMammoth.Mode.keys()[matriarch.mode])
	put_boy(far_end - way * 60.0)
	await wait(1.0)
	await clear()
	# Up off the ground
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	young = herd.back()
	var never := true
	for i in 480:
		boy.global_position = far_end - way * 6.0 + Vector3.UP * 3.2
		boy.velocity = Vector3.ZERO
		await physics_frame
		if matriarch.mode == MazeMammoth.Mode.CHARGE:
			never = false
	check("up off the ground he is never charged", never and caught_by.is_empty(), "(%s)" % MazeMammoth.Mode.keys()[matriarch.mode])
	await clear()

	# --- A hunter near the herd ---
	boy.remove_from_group(&"maze_players")
	put_boy(near_end - way * 80.0)
	var life := Ecology.put(stage, 2)
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	var dog := MazeDog.new()
	dog.maze = maze
	dog.position = far_end - way * 13.0 + Vector3.UP * 0.05
	stage.add_child(dog)
	await frames(2)
	var ring_for_dog := await wait(4.0, func() -> bool: return matriarch.herd_mode == MazeMammoth.Mode.RING and matriarch.intruder == dog)
	check("a hunter near the herd: the ring", ring_for_dog, "(%s)" % MazeMammoth.Mode.keys()[matriarch.herd_mode])
	var flung := await wait(16.0, func() -> bool:
		if is_instance_valid(dog) and dog.get_node_or_null(^"Stagger") == null and dog.global_position.distance_to(far_end) > 9.0:
			# (it stays about, near the herd)
			dog.global_position = dog.global_position.lerp(far_end, 0.02)
		return is_instance_valid(dog) and dog.get_node_or_null(^"Stagger") != null)
	check("and she knocks it flying", flung)
	await clear()
	life.queue_free()
	boy.add_to_group(&"maze_players")
	await frames(2)

	# --- Out on open ground ---
	var out_there := Vector3(maze.extent() + 400.0, 0.0, 0.0)
	var ground := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(300.0, 1.0, 300.0)
	ground.add_child(box)
	ground.position = out_there + Vector3.DOWN * 0.5
	stage.add_child(ground)
	await frames(2)
	put_boy(out_there + Vector3(0.0, 0.0, -60.0))
	herd = herd_at(out_there, Vector3.BACK, 5)
	matriarch = herd[0]
	await wait(3.0)
	check("out on open ground, off the maze's grid", matriarch.in_open)
	check("they graze there too", matriarch.mode == MazeMammoth.Mode.GRAZE and matriarch.herd_mode in [MazeMammoth.Mode.GRAZE, MazeMammoth.Mode.MOVE])
	put_boy(out_there + Vector3(0.0, 0.0, -20.0), out_there)
	var seen_open := await wait(3.0, func() -> bool: return matriarch.herd_mode in [MazeMammoth.Mode.ALERT, MazeMammoth.Mode.RING])
	check("and are alarmed by him in sight", seen_open)
	await clear()
	ground.queue_free()

	# --- Puppets ---
	herd = herd_at(far_end, -way)
	matriarch = herd[0]
	var copy := MazeMammoth.new()
	copy.maze = maze
	copy.puppet = true
	copy.lead = true
	copy.size = matriarch.size
	copy.position = matriarch.position
	stage.add_child(copy)
	var heard_trumpet := [false]
	copy.mammoth.trumpeted.connect(func() -> void: heard_trumpet[0] = true)
	put_boy(far_end - way * 22.0, far_end)
	var furthest := 0.0
	for i in 600:
		await physics_frame
		if i == 120:
			put_boy(far_end - way * 13.0, far_end)
		if i % 6 == 0:
			copy.from_bytes(matriarch.state_bytes())
		if i > 30:
			furthest = maxf(furthest, copy.global_position.distance_to(matriarch.global_position))
	check("the puppet mammoth keeps up with its host", furthest < 2.5, "(at most %.2f m off)" % furthest)
	check("and trumpets when its host does", heard_trumpet[0])
	await clear()

	# --- Sounds ---
	check("a trumpet, a rumble and a thud are made", Mammoth.trumpet_sound().data.size() > 40000 and Mammoth.rumble_sound().data.size() > 40000 and Mammoth.thud_sound().data.size() > 8000)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
