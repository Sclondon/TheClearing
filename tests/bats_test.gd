extends SceneTree
## The bats (scripts/enemies/bats.gd, creatures/bats/), headless, in a bare
## scene: a maze from MazeBuilder and a stand-in player that the test moves by
## hand (a CharacterBody3D with no shape, so its `velocity` is whatever the test
## says). In turn: the colony finds a roost on a wall and hangs there; standing
## quietly a little way off does not wake it; running past does; awake, it
## follows the player along the passages and whirls round their head; it calls
## a dormant mummy near it to the hunt; it never catches anyone; standing still
## it soon loses interest and goes home, and every bat is hanging again; a
## puppet colony follows the host's news; MazeEnemies' packing carries it; and
## the colony is one draw.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/bats_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var runner: CharacterBody3D
var failures := 0
var caught := 0
var trace := OS.get_cmdline_user_args().has("trace")


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
	var found := straight_run(4)
	check("a straight passage to test in", not found.is_empty())
	var start: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	# Nobody near at first.
	put(maze.world(start) + Vector3(0, 0, 0) - along * 200.0)
	var bats := Bats.new()
	bats.name = "Bats"
	bats.maze = maze
	bats.seed_choices(1234)
	bats.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(bats)
	bats.caught.connect(func(_who: Node3D) -> void: caught += 1)
	await frames(5)
	var roost: Vector3 = bats.colony.roost()
	var middle: Vector3 = maze.world(start + way * 2)
	check("it finds a roost on a wall, high up", bats.roosted() and absf(roost.y - bats.roost_height) < 0.1, "(at %s, %.1f m from the cell's middle)" % [roost, Vector2(roost.x - middle.x, roost.z - middle.z).length()])
	var space := bats.get_world_3d().direct_space_state
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(roost + bats.roost_out * 0.5, roost - bats.roost_out * 0.5, 1))
	var open := space.intersect_ray(PhysicsRayQueryParameters3D.create(roost + bats.roost_out * 0.1, roost + bats.roost_out * 3.0, 1))
	check("the roost is on a face of stone (a wall or a terrace), with room in front", not face.is_empty() and open.is_empty(), "(on %s)" % (face["collider"].name if not face.is_empty() else "nothing"))
	await frames(30)
	check("asleep, all hanging", bats.mode == Bats.Mode.ROOST and bats.colony.all_home())

	# A mummy, dormant, some way down the passage, to hear the alarm.
	var mummy := Mummy.new()
	mummy.name = "Mummy"
	mummy.start_dormant = true
	# (blind and deaf: only being told can set it hunting)
	mummy.sight_range = 0.0
	mummy.hear_range = 0.0
	mummy.maze = maze
	mummy.position = maze.world(start + way * 4) + Vector3.UP * 0.05
	stage.add_child(mummy)
	await frames(10)

	# Standing quietly, 9 m off along the passage: it sleeps on.
	put(Vector3(roost.x, 0.05, roost.z) - along * 9.0 + bats.roost_out * 0.5)
	await frames(90)
	check("someone standing quietly 9 m off does not wake it", bats.mode == Bats.Mode.ROOST)
	check("nor does the mummy see them", not mummy.is_awake() or mummy.quarry == null, "(mummy %s)" % Mummy.Mode.keys()[mummy.mode])

	# Running past: it wakes, and the bats let go.
	var woke := [false]
	bats.spotted.connect(func(_who: Node3D) -> void: woke[0] = true)
	var pace := 4.4
	var from := runner.global_position
	for i in 120:
		put(from + along * pace * i / 60.0, along * pace)
		await physics_frame
		if bats.mode == Bats.Mode.MOB:
			break
	check("running past wakes it", bats.mode == Bats.Mode.MOB and woke[0], "(%.1f m from the roost)" % Vector2(runner.global_position.x - roost.x, runner.global_position.z - roost.z).length())
	await frames(40)
	check("the bats leave the roost", bats.colony.flying() >= bats.colony.count - 2, "(%d flying)" % bats.colony.flying())

	# Awake, it follows them along the passage and whirls round their head.
	from = runner.global_position
	var worst := 0.0
	var walls := 0
	for i in 240:
		var t := minf(i / 60.0, 2.5)
		put(from + along * pace * t, along * pace if t < 2.5 else Vector3.ZERO)
		await physics_frame
		if i > 90:
			worst = maxf(worst, bats.colony.centre().distance_to(runner.global_position + Vector3.UP * 1.6))
		if not nav.clear_of_walls(bats.global_position, -0.2):
			walls += 1
		if trace and i % 30 == 0:
			print("      %d: colony at %s, middle of the bats %s, the runner %s" % [i, bats.global_position, bats.colony.centre(), runner.global_position])
	check("the colony keeps with them", worst < 5.0, "(the middle of the bats at worst %.1f m from their head)" % worst)
	check("the colony goes by the passages", walls == 0, "(%d frames in a wall)" % walls)
	var near := 0
	for b in bats.colony.count:
		if bats.colony.bat_position(b).distance_to(runner.global_position + Vector3.UP * 1.6) < 4.0:
			near += 1
	check("most of the bats are round their head", near >= bats.colony.count * 2 / 3, "(%d of %d within 4 m)" % [near, bats.colony.count])
	# They keep clear of the head and shoulders (wing tips and all), but for one diving
	# (or for a moment, one just out of a dive and on its way out again).
	var colony: BatColony = bats.colony
	var too_close := 0
	var looked := 0
	for i in 180:
		await physics_frame
		var head := runner.global_position + Vector3.UP * 1.65
		for b in colony.count:
			if colony._dive[b].x > 0.0 or colony._phase[b] != BatColony.Phase.FLY:
				continue
			var at := colony.bat_position(b)
			if at.y < head.y - colony.target_depth or at.y > head.y + 0.35:
				continue
			looked += 1
			if Vector2(at.x - head.x, at.z - head.z).length() < colony._clear_of(colony._size[b]) - 0.1:
				too_close += 1
	check("the swirl keeps clear of their head and shoulders", too_close * 100 <= looked, "(%d too close in %d looks at bats level with them)" % [too_close, looked])
	check("the mummy was called to the hunt", mummy.quarry == runner, "(mummy %s, after %s)" % [Mummy.Mode.keys()[mummy.mode], mummy.quarry])
	check("the bats catch nobody", caught == 0)

	# A puppet colony follows the host's news.
	var copy := Bats.new()
	copy.name = "BatsCopy"
	copy.maze = maze
	copy.puppet = true
	copy.seed_choices(1234)
	copy.position = maze.world(start + way * 2) + Vector3.UP * 0.05
	stage.add_child(copy)
	await frames(3)
	check("the puppet has the same roost", copy.roosted() and copy.colony.roost().distance_to(roost) < 0.01)
	var behind := 0.0
	var agreed := 0
	for i in 180:
		if i % 6 == 0:
			copy.from_bytes(bats.state_bytes())
		await physics_frame
		if i > 30:
			behind = maxf(behind, copy.global_position.distance_to(bats.global_position))
			if copy.mode == bats.mode:
				agreed += 1
	check("a puppet colony follows", behind < 2.5 and agreed > 140, "(at worst %.2f m behind; same mode %d of 149 frames; %d of its bats flying)" % [behind, agreed, copy.colony.flying()])
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, bats.state_bytes().size() == MazeEnemy.STATE_SIZE)

	# Standing still (and ducked down), it soon loses interest and goes home.
	put(runner.global_position)
	var t0 := Time.get_ticks_msec()
	var back := false
	for i in 60 * 20:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(bats.state_bytes())
		if bats.mode == Bats.Mode.ROOST and bats.colony.all_home():
			back = true
			break
	var seconds := (Time.get_ticks_msec() - t0) / 1000.0
	check("standing still, it gives up and every bat is back on the roost", back, "(after %.1f s; mode %s, %d flying)" % [seconds, Bats.Mode.keys()[bats.mode], bats.colony.flying()])
	await frames(60)
	check("and the puppet's bats too", copy.mode == Bats.Mode.ROOST and copy.colony.all_home(), "(%d flying)" % copy.colony.flying())
	# Rested, running past does not wake it at once; right under it does.
	put(Vector3(roost.x, 0.05, roost.z) - along * 12.0 + bats.roost_out * 0.5, along * 4.4)
	await frames(30)
	check("just home, a runner 12 m off does not wake it", bats.mode == Bats.Mode.ROOST)
	put(Vector3(roost.x, 0.05, roost.z) + bats.roost_out * 0.5, Vector3.ZERO)
	await frames(30)
	check("but someone right under it does", bats.mode == Bats.Mode.MOB)

	# Placed by MazeEnemies: packed and unpacked with the rest.
	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(Bats.new(), start + way, 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(Bats.new(), start + way, 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	check("MazeEnemies packs and unpacks a colony", (b as Bats).roosted() and (b as Bats).colony.roost() == (a as Bats).colony.roost() and b.puppet)
	check("the colony is drawn in one draw", bats.colony.get_child_count() == 1 and bats.colony.get_child(0) is MultiMeshInstance3D)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
