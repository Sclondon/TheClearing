extends SceneTree
## The ways up, headless: the maze has terraces, ivy, vines and bridges, the same
## for the same seed; the boy climbs ivy onto a terrace, catches a vine, and
## stands on a rope bridge, which dips under him.
##
##     godot --headless --path . -s res://tests/climb_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


## Pushes the stick so that he goes the world way `towards` (level), as a thumb
## would with the camera where it is.
func steer(towards: Vector3) -> void:
	var basis: Basis = main.world.camera.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var stick := Vector2(towards.dot(right), towards.dot(forward))
	press(&"move_right", stick.x)
	press(&"move_left", -stick.x)
	press(&"move_up", stick.y)
	press(&"move_down", -stick.y)


func press(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func let_go() -> void:
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down", &"jump"]:
		Input.action_release(action)


func _run() -> void:
	await frames(5)
	# (a ring with every way up in it: the game's first ring has only vines)
	MazeStyle.chosen = [MazeStyle.warren()]
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("CLMB", 1))
	await frames(20)
	var world = main.world
	var features = world.get_node("Maze").features
	check("terraces", features.terraces.size() > 5, "(%d)" % features.terraces.size())
	check("ivy", features.climbs.size() > 5, "(%d)" % features.climbs.size())
	check("vines", features.vines.size() > 2, "(%d)" % features.vines.size())
	check("bridges", features.bridges.size() > 0, "(%d)" % features.bridges.size())
	var again := MazeBuilder.new()
	root.add_child(again)
	again.build(Maze.generate(Maze.seed_for("CLMB", 1)))
	check("same seed, same ways up", again.features.terraces == features.terraces and again.features.climbs.size() == features.climbs.size())
	again.queue_free()

	var player = world.player
	# Ivy: the lowest one, from the ground.
	var ivy: IvyClimb = null
	for climb: IvyClimb in features.climbs:
		if climb.bottom_y() < 0.1:
			ivy = climb
			break
	player.global_position = ivy.stand(0.05) + ivy.global_basis.z * 0.6
	player.velocity = Vector3.ZERO
	await frames(10)
	var up_to := 0.0
	for i in 600:
		# (on it, up the screen is up it)
		if player.state == player.State.LADDER:
			let_go()
			Input.action_press(&"move_up")
		else:
			steer(ivy.facing())
		await physics_frame
		up_to = maxf(up_to, player.global_position.y)
		if player.state == player.State.FREE and player.is_on_floor() and player.global_position.y > ivy.top_y() - 0.3:
			break
	let_go()
	await frames(20)
	var onto: Vector3 = ivy.stand(ivy.top_y() + 0.03) + ivy.facing() * 0.75
	var hit := KinematicCollision3D.new()
	if player.test_move(Transform3D(Basis.IDENTITY, onto), Vector3.UP * 0.01, hit, 0.001, true):
		print("  onto blocked by ", hit.get_collider(), " ", hit.get_collider().get_parent() if hit.get_collider() else null, " at ", hit.get_position(), " normal ", hit.get_normal(), " onto ", onto)
	check("climbs the ivy onto the terrace", player.state == player.State.FREE and player.is_on_floor() and player.global_position.y > ivy.top_y() - 0.3,
		"(at %.1f m, top %.1f, highest %.1f, state %d)" % [player.global_position.y, ivy.top_y(), up_to, player.state])

	# A vine: put him under its end and jump into it.
	var vine: Vine = features.vines[0]
	var under: Vector3 = vine.point_at(vine.length) + Vector3.DOWN * (MazeFeatures.VINE_CLEAR - 0.05)
	player.global_position = under
	player.velocity = Vector3.ZERO
	await frames(2)
	var jump := InputEventAction.new()
	jump.action = &"jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	Input.action_press(&"jump")
	var caught := false
	for i in 90:
		await physics_frame
		if player.state == player.State.ROPE:
			caught = true
			break
	Input.action_release(&"jump")
	check("catches a vine", caught, "(state %d)" % player.state)
	await frames(10)

	# A bridge: set him down on the middle of it.
	var bridge: RopeBridge = features.bridges[0]
	var middle: Vector3 = (bridge.from + bridge.to) * 0.5
	# (first by its end, so that it wakes and settles as it hangs with nobody on it:
	# asleep, it keeps the shape it was laid out in)
	player.state = player.State.FREE
	player.global_position = bridge.from + Vector3.UP * 0.5
	player.velocity = Vector3.ZERO
	await frames(120)
	var level_before: float = bridge._points[RopeBridge.POINTS / 2].y
	player.state = player.State.FREE
	player.global_position = bridge._points[RopeBridge.POINTS / 2] + Vector3.UP * 0.5
	player.velocity = Vector3.ZERO
	await frames(120)
	var level_after: float = bridge._points[RopeBridge.POINTS / 2].y
	check("stands on the bridge", player.is_on_floor() and player.global_position.y > middle.y - 3.0,
		"(at %.1f, ends at %.1f)" % [player.global_position.y, middle.y])
	check("the bridge dips under him", level_after < level_before - 0.05, "(%.2f -> %.2f)" % [level_before, level_after])

	print("CLIMB TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
