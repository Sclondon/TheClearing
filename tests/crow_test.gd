extends SceneTree
## The corvids (creatures/crow/, creatures/blue_jay/): crows in the maze
## (scripts/enemies/crows.gd), ravens (scripts/wildlife/ravens.gd) and the
## clearing's birds (scripts/wildlife/birds.gd), headless, in a bare scene: a
## maze from MazeBuilder (walls with collision, for their perches) and a
## stand-in player that the test moves by hand (a CharacterBody3D with no
## shape, so its `velocity` is whatever the test says). In turn: the three
## models load with their joints and both levels of detail; a flock is one draw;
## a bird flies to a perch and lands on it; the murder sits along the wall tops
## over its hall; someone standing still far off is let alone; walking in sight
## below, they watch and follow along the walls; running near, they erupt,
## wheel over him and call a dormant mummy to the hunt, then settle; a catch
## near them sets them wheeling over the place; they never catch anyone; a
## puppet murder follows the host's news; ravens fly ahead to sit over a hunter
## waiting ahead of him, and come home; the clearing's jays and crows are placed
## in the pines, scold someone under their trees and go up when he runs; the
## sounds.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/crow_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var runner: CharacterBody3D
var failures := 0
var caught := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


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
	var body := GDScript.new()
	body.source_code = "extends CharacterBody3D
var is_ducking := false
var is_sprinting := false
"
	body.reload()
	runner.set_script(body)
	runner.name = "Runner"
	runner.collision_layer = 0
	runner.collision_mask = 0
	stage.add_child(runner)
	runner.add_to_group(&"maze_players")
	_run.call_deferred()


## A passage cell with `run` open cells straight on from it, out of the clearing, and that way.
func straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(4):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return []


func put(at: Vector3, moving := Vector3.ZERO) -> void:
	runner.global_position = at
	runner.velocity = moving


func _run() -> void:
	await frames(10)
	# The models.
	for kind in [CorvidBody.Kind.CROW, CorvidBody.Kind.RAVEN, CorvidBody.Kind.BLUE_JAY]:
		var full := CorvidBody.mesh(kind)
		var low := CorvidBody.mesh(kind, true)
		var joints := CorvidBody.joints(kind)
		var full_tris: int = (full.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 if full.get_surface_count() > 0 else 0
		var low_tris: int = (low.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 if low.get_surface_count() > 0 else 0
		check("%s: the model and its low-detail twin, with its joints" % CorvidBody.Kind.keys()[kind], full_tris > 8000 and low_tris > 2000 and low_tris < full_tris / 2 and joints.has("shoulder") and joints.has("wrist") and joints.has("flight_pitch"), "(%d and %d triangles, %d joints)" % [full_tris, low_tris, joints.size()])

	var found := straight_run(5)
	check("a straight passage to test in", not found.is_empty())
	var start: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var side := Vector3(-along.z, 0.0, along.x)
	put(maze.world(start) - along * 300.0)

	# One bird, two perches: it flies from one to the other and lands on it.
	var test_flock := CorvidFlock.new()
	test_flock.count = 1
	stage.add_child(test_flock)
	var a := Vector3(500.0, 3.0, 500.0)
	var b := a + Vector3(9.0, 1.5, 0.0)
	test_flock.set_perches(PackedVector3Array([a, b]), PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD]), false)
	test_flock.settle()
	var first: int = test_flock.perch_of(0)
	var meshes := test_flock.find_children("*", "MultiMeshInstance3D", false, false)
	check("a flock is one MultiMesh", meshes.size() == 1)
	test_flock.send_ahead(0, 1 - first)
	var flew := false
	var highest := -INF
	for f in 60 * 5:
		await process_frame
		if test_flock.act_of(0) == CorvidFlock.Act.FLY:
			flew = true
			highest = maxf(highest, test_flock.bird_position(0).y)
		if flew and test_flock.perch_of(0) == 1 - first and test_flock.act_of(0) != CorvidFlock.Act.FLY:
			break
	var there: Vector3 = [a, b][1 - first]
	check("a crow flies to another perch, over and down onto it, and lands", flew and test_flock.perch_of(0) == 1 - first and test_flock.bird_position(0).distance_to(there) < 0.05 and highest > maxf(a.y, b.y) + 0.3, "(highest %.1f m)" % highest)
	test_flock.queue_free()

	# The murder, on the walls over a hall.
	var crows := Crows.new()
	crows.name = "Crows"
	crows.maze = maze
	crows.seed_choices(4321)
	crows.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(crows)
	crows.caught.connect(func(_who: Node3D) -> void: caught += 1)
	await frames(20)
	var flock: CorvidFlock = crows.flock
	var ground: float = maze.ground_height(crows.position)
	var high := 0
	for i in flock.count:
		if flock.perch_of(i) >= 0 and flock.bird_position(i).y > ground + 5.0:
			high += 1
	check("a murder of 7 to 13 crows", flock.count >= 7 and flock.count <= 13, "(%d)" % flock.count)
	check("they sit high on the walls over the hall", crows.roosted() and high == flock.count, "(%d of %d on a wall top or ledge, %d perches)" % [high, flock.count, flock.perch_points.size()])

	# A mummy, dormant, a little way along, to hear them.
	var mummy := Mummy.new()
	mummy.name = "Mummy"
	mummy.start_dormant = true
	mummy.sight_range = 0.0
	mummy.hear_range = 0.0
	mummy.maze = maze
	mummy.position = maze.world(start + way * 4) + Vector3.UP * 0.05
	stage.add_child(mummy)

	# Standing still far off: nothing.
	await frames(60 * 2)
	check("nobody near: they roost", crows.mode == Crows.Mode.ROOST)

	# Walking in the hall below, in sight: they watch, and follow along the walls.
	var home := flock.centre()
	# (down the middle of the hall, from a little short of under them)
	var middle: Vector3 = maze.world(start + way * 2)
	var walk_from := middle + along * ((home - middle).dot(along) - 6.0) + Vector3.UP * (ground + 0.05)
	var flights := 0
	var watched := false
	for i in 60 * 14:
		put(walk_from + along * 1.4 * i / 60.0, along * 1.4)
		await physics_frame
		watched = watched or crows.mode == Crows.Mode.WATCH
		flights = maxi(flights, flock.flying())
		if crows.mode == Crows.Mode.ALARM:
			break
	await frames(60 * 3)
	var moved := Vector2(flock.centre().x - home.x, flock.centre().z - home.z).length()
	check("walking below, they watch him", watched)
	check("and follow him along the walls in short flights", flights >= 1 and moved > 6.0, "(%d in the air at once; the murder moved %.0f m)" % [flights, moved])
	check("walking does not set them off", crows.mode != Crows.Mode.ALARM)

	# Running near: they erupt, wheel over him, and call the mummy.
	var centre := flock.centre()
	var hall: Vector3 = maze.world(maze.cell_at(centre))
	var from := hall + along * ((centre - hall).dot(along) - 10.0) + Vector3.UP * (ground + 0.05)
	for i in 120:
		put(from + along * 4.4 * i / 60.0, along * 4.4)
		await physics_frame
		if crows.mode == Crows.Mode.ALARM:
			break
	check("running near sets them off", crows.mode == Crows.Mode.ALARM and crows.chasing)
	put(runner.global_position)
	var up := 0
	for i in 60 * 3:
		await physics_frame
		up = maxi(up, flock.flying())
	check("the whole murder goes up and wheels over him", up >= flock.count - 1 and flock.circling(), "(%d of %d in the air at once)" % [up, flock.count])
	var over: float = Vector2(flock.centre().x - runner.global_position.x, flock.centre().z - runner.global_position.z).length()
	check("over him", over < 14.0, "(%.1f m off)" % over)
	check("the cawing calls the mummy to the hunt", mummy.quarry == runner, "(mummy %s)" % Mummy.Mode.keys()[mummy.mode])
	mummy.queue_free()
	var settled := false
	for i in 60 * 20:
		await physics_frame
		if crows.mode != Crows.Mode.ALARM and flock.flying() == 0:
			settled = true
			break
	check("then they settle on the walls again", settled and flock.perched() >= flock.count - 1, "(%d perched)" % flock.perched())

	# A catch near them: they wheel over the place.
	put(runner.global_position - along * 200.0)
	await frames(30)
	var spot: Vector3 = flock.centre() + side * 2.0
	spot.y = ground
	crows.saw_catch(spot)
	await frames(60 * 3)
	var mark_off: float = Vector2(flock.centre().x - spot.x, flock.centre().z - spot.z).length()
	check("a catch near them: they wheel over the place", crows.mode == Crows.Mode.MARK and flock.flying() >= flock.count - 1 and mark_off < 14.0, "(%d up, %.1f m off)" % [flock.flying(), mark_off])
	check("they never catch anyone", caught == 0)

	# A puppet copy follows the host's news.
	var enemies := MazeEnemies.new()
	stage.add_child(enemies)
	enemies.maze = maze
	var copy := Crows.new()
	enemies.add(copy, maze.cell_at(crows.position), 0.0, 4321)
	copy.puppet = true
	await frames(10)
	copy.from_bytes(crows.state_bytes())
	await frames(60 * 2)
	check("a puppet murder follows the news", copy.mode == Crows.Mode.MARK and copy.flock.circling(), "(%s)" % Crows.Mode.keys()[copy.mode])
	enemies.queue_free()
	crows.queue_free()
	await frames(5)

	# Ravens: when he comes near, they fly ahead to sit over a hunter waiting there.
	var pair := Ravens.new(maze, 99)
	pair.position = maze.world(start) + Vector3.UP * 0.05
	pair.targets = [runner]
	stage.add_child(pair)
	await frames(20)
	check("a pair of ravens (or one) on the walls", pair.flock.count >= 1 and pair.flock.perched() == pair.flock.count, "(%d)" % pair.flock.count)
	var waiting := Mummy.new()
	waiting.name = "Waiting"
	waiting.start_dormant = true
	waiting.sight_range = 0.0
	waiting.hear_range = 0.0
	waiting.maze = maze
	waiting.position = maze.world(start + way * 5) + Vector3.UP * 0.05
	stage.add_child(waiting)
	var raven_home := pair.flock.centre()
	var raven_hall: Vector3 = maze.world(start)
	put(raven_hall + along * ((raven_home - raven_hall).dot(along) - 4.0) + Vector3.UP * (ground + 0.05), along * 0.5)
	await frames(60 * 2)
	check("he comes near: they fly ahead to the hunter", pair.mode == Ravens.Mode.OMEN and pair.omen == waiting)
	await frames(60 * 9)
	var off: float = Vector2(pair.flock.centre().x - waiting.global_position.x, pair.flock.centre().z - waiting.global_position.z).length()
	check("and sit on the walls over it", off < 20.0 and pair.flock.perched() == pair.flock.count, "(%.0f m from it)" % off)
	waiting.queue_free()
	await frames(60 * 2)
	check("it goes: they fly home", pair.mode == Ravens.Mode.HOME)
	pair.queue_free()

	# The clearing's birds.
	var trees: Array = []
	for piece in (stage.get_node("Maze") as MazeBuilder).layout.pieces(MazePiece.Kind.TREE):
		trees.append(piece.global_transform)
	var birds := Birds.new()
	stage.add_child(birds)
	birds.populate(maze, trees, 77)
	await frames(10)
	var look: ClearingStyle = maze.clearing_style
	check("the clearing's jays and crows", birds.jays.size() == look.blue_jay_families and birds.crows.size() == look.crow_flocks, "(%d families of jays, %d of crows, %d trees)" % [birds.jays.size(), birds.crows.size(), trees.size()])
	if not birds.jays.is_empty():
		var jays: BlueJays = birds.jays[0]
		var in_trees := 0
		for i in jays.count:
			if jays.perch_of(i) >= 0 and jays.bird_position(i).y > maze.ground_height(jays.bird_position(i)) + 1.0:
				in_trees += 1
		check("jays sit in the pines (and some on the ground)", in_trees >= 1, "(%d of %d up in the branches)" % [in_trees, jays.count])
		var trunk: Vector3 = birds._jay_trees[0][0]
		put(trunk + Vector3(2.0, 0.05, 0.0))
		await frames(60 * 3)
		var scolding := 0
		for i in jays.count:
			if jays.act_of(i) in [CorvidFlock.Act.SCOLD, CorvidFlock.Act.CALL]:
				scolding += 1
		check("someone under their tree: they scold him", jays._scold.is_finite() and scolding >= 1, "(%d scolding)" % scolding)
		put(trunk + Vector3(300.0, 0.05, 0.0))
		await frames(30)
		check("he goes: they calm down", not jays._scold.is_finite())
	if not birds.crows.is_empty():
		var meadow: CorvidFlock = birds.crows[0]
		await frames(60 * 4)
		var mid := meadow.centre()
		put(Vector3(mid.x, maze.ground_height(mid) + 0.05, mid.z) + Vector3(12.0, 0.0, 0.0), Vector3(-4.5, 0.0, 0.0))
		await frames(30)
		await frames(60)
		check("running at the clearing's crows, they go up cawing", meadow.circling() and meadow.flying() >= meadow.count - 1, "(%d up)" % meadow.flying())
	birds.queue_free()

	# The sounds.
	var sounds := CorvidVoice.sounds()
	var all := true
	for call in CorvidFlock.Call.values():
		var list: Array = sounds.get(call, [])
		if list.is_empty() or (list[0] as AudioStreamWAV).data.size() < 1000:
			all = false
	check("every call is made (caws, croaks, knocks, jays, the hawk)", all and sounds.has("wings"))

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
