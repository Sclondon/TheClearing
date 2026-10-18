extends SceneTree
## The imps (scripts/enemies/maze_imp.gd, creatures/imp/), headless, in a bare
## scene: a maze from MazeBuilder and the boy standing in it. A gang that
## perches on a wall, notices him, comes down and leaps on him; riders holding
## him back; enough of them bringing him down; one shaken off by a jump and
## throwing a tantrum; a rider's cackle fetching a baboon; going home and back
## up the wall; and a puppet following the host.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/imp_test.gd
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


func put_boy(cell: Vector2i) -> void:
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func cell_from(from: Vector2i, steps: int) -> Vector2i:
	var field: PackedInt32Array = nav.field(from)
	for i in field.size():
		if field[i] == steps:
			return Vector2i(i % maze.size, i / maze.size)
	return Vector2i(-1, -1)


func spawn(one: MazeEnemy, cell: Vector2i, offset := Vector3.ZERO) -> MazeEnemy:
	one.maze = maze
	one.position = maze.world(cell) + offset + Vector3.UP * 0.05
	stage.add_child(one)
	one.caught.connect(func(player: Node3D) -> void: caught_by.append([player, one]))
	return one


func clear() -> void:
	for child in stage.get_children():
		if child is MazeEnemy:
			child.free()
	caught_by.clear()
	MazeImp._riders.clear()


func modes(list: Array) -> String:
	var names := []
	for one: MazeImp in list:
		names.append(MazeImp.Mode.keys()[one.mode])
	return ", ".join(names)


func _run() -> void:
	await frames(10)
	var lairs: Array = nav.lairs(5)
	var home: Vector2i = lairs[lairs.size() / 2]

	# --- A gang perches on a wall, nobody about ---
	boy.remove_from_group(&"maze_players")
	put_boy(lairs[0])
	var gang := MazeImp.gang(3)
	check("a gang is three imps", gang.size() == 3)
	var from := cell_from(home, 2)
	for k in gang.size():
		spawn(gang[k], from, Vector3(k - 1, 0, 0) * 0.8)
	await frames(5)
	var perched := true
	var heights := []
	for one in gang:
		var up: float = one.global_position.y - maze.ground_height(one.global_position)
		heights.append("%.1f" % up)
		if one.mode != MazeImp.Mode.PERCH or up < 2.5 or not one.body.clinging:
			perched = false
	check("each clings to a wall, up out of reach", perched, "(heights %s)" % [heights])
	await wait(1.0)
	check("and stays there with nobody about", gang.all(func(o: MazeImp) -> bool: return o.mode == MazeImp.Mode.PERCH))

	# --- They notice him, come down, and one leaps on him ---
	boy.add_to_group(&"maze_players")
	put_boy(home)
	await frames(3)
	gang[0].notice(boy)
	var down := await wait(1.0, func() -> bool: return gang.all(func(o: MazeImp) -> bool: return o.mode != MazeImp.Mode.PERCH))
	check("one notices him and the gang comes down off the wall", down, "(%s)" % modes(gang))
	check("the one that saw him cackled", gang[0]._cackles > 0)
	var rode := await wait(10.0, func() -> bool: return MazeImp.riding(boy) > 0)
	check("an imp leaps on him and holds on", rode, "(%s)" % modes(gang))
	var leapt := gang.any(func(o: MazeImp) -> bool: return o._leaps > 0)
	check("by leaping", leapt)
	# Held back: he cannot run as fast with them on him.
	boy.velocity = Vector3(5.6, 0.0, 0.0)
	var rider: MazeImp = null
	for one in gang:
		if one.mode == MazeImp.Mode.RIDING:
			rider = one
	if rider:
		rider._hold_back_local()
	var speed := Vector2(boy.velocity.x, boy.velocity.z).length()
	check("a rider holds him back", speed < 5.0, "(%.2f m/s with %d on him)" % [speed, MazeImp.riding(boy)])
	# Three on him for long enough bring him down.
	var caught := await wait(14.0, func() -> bool: return not caught_by.is_empty())
	check("three of them on him bring him down", caught and caught_by[0][0] == boy, "(%s)" % modes(gang))
	await frames(2)
	check("and they let go of him", MazeImp.riding(boy) == 0)
	clear()

	# --- Shaken off by a jump: it tumbles off and throws a tantrum ---
	put_boy(home)
	await frames(3)
	var one := spawn(MazeImp.new(), cell_from(home, 1)) as MazeImp
	await frames(3)
	one.quarry = boy
	one._forget = 20.0
	one._mount(boy)
	one._grip = 0.3
	await frames(5)
	check("riding him", one.mode == MazeImp.Mode.RIDING)
	boy.velocity.y = 6.0
	var flung := await wait(2.0, func() -> bool: return one.mode == MazeImp.Mode.FLUNG)
	check("a jump shakes it off", flung)
	var sulk := await wait(3.0, func() -> bool: return one.mode == MazeImp.Mode.TANTRUM)
	check("it lands and throws a tantrum", sulk and one.body.in_tantrum())
	clear()

	# --- A rider's cackle fetches a baboon ---
	put_boy(home)
	await frames(3)
	var baboon := spawn(MazeBaboon.new(), cell_from(home, 2)) as MazeBaboon
	boy.remove_from_group(&"maze_players")
	await frames(3)
	boy.add_to_group(&"maze_players")
	var caller := spawn(MazeImp.new(), cell_from(home, 1)) as MazeImp
	await frames(3)
	caller.quarry = boy
	caller._forget = 20.0
	caller._mount(boy)
	caller._grip = 100.0
	caller._call = 0.0
	var fetched := await wait(1.0, func() -> bool: return baboon.quarry == boy)
	check("its cackle tells a baboon near where he is", fetched)
	clear()

	# --- It forgets him, goes home, and climbs back up its wall ---
	put_boy(home)
	await frames(3)
	var homer := spawn(MazeImp.new(), cell_from(home, 1)) as MazeImp
	await frames(3)
	homer.notice(boy)
	await wait(1.5)
	boy.remove_from_group(&"maze_players")
	homer.quarry = null
	homer._forget = 0.0
	var back := await wait(20.0, func() -> bool: return homer.mode == MazeImp.Mode.PERCH)
	check("with nobody to go after it goes home, back up its wall", back, "(%s)" % MazeImp.Mode.keys()[homer.mode])
	boy.add_to_group(&"maze_players")
	clear()

	# --- Puppets follow the host ---
	put_boy(home)
	await frames(3)
	var host := spawn(MazeImp.new(), cell_from(home, 2)) as MazeImp
	host.seed_choices(3)
	var copy := MazeImp.new()
	copy.seed_choices(3)
	copy.puppet = true
	spawn(copy, cell_from(home, 2))
	await frames(3)
	host.notice(boy)
	var worst := 0.0
	var copy_rode := false
	for i in 420:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 30 and host.mode != MazeImp.Mode.RIDING:
			worst = maxf(worst, copy.global_position.distance_to(host.global_position))
		if copy.mode == MazeImp.Mode.RIDING and copy.ridden == boy:
			copy_rode = true
	check("a puppet follows the host's news", worst < 2.0, "(at worst %.2f m behind)" % worst)
	check("and rides him when the host does", copy_rode or host._leaps == 0, "(host %s, leaps %d)" % [MazeImp.Mode.keys()[host.mode], host._leaps])
	check("a puppet catches nobody", caught_by.all(func(c: Array) -> bool: return c[1] != copy))
	clear()

	# --- The component's example runs on its own ---
	var example: Node3D = load("res://creatures/imp/example.gd").new()
	stage.add_child(example)
	await wait(0.2)
	var was_at: Vector3 = example.walker.global_position
	var found := true
	for b in Imp.BONES.size():
		if example.walker._index[b] < 0:
			found = false
	check("the model has every bone", found, "(vertices %d)" % example.walker._body.mesh.surface_get_array_len(0))
	await wait(2.0)
	check("the example runs them round", example.walker.global_position.distance_to(was_at) > 0.3)
	example.free()
	for what: StringName in [&"cackle", &"chitter", &"shriek"]:
		check("its %s is made" % what, Imp.sound(what).data.size() > 1000)

	print("IMP TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)
