extends SceneTree
## Strung vines (VineStrand), headless: each has a buttress with ivy up it at one
## end; the boy stands on one as a tightrope, set down a little to one side he is
## drawn back over it, it dips under him; he cuts it with the act button and it is
## two hanging vines, and he is on one of them or falling clear.
##
##     godot --headless --path . -s res://tests/strand_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


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


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(30)
	var world = main.world
	var player = world.player
	var features = world.maze_features()
	check("strung vines", features.strands.size() > 5, "(%d)" % features.strands.size())
	# The ledge along the walls: up a curtain of ivy from the ground onto it.
	var style: MazeStyle = world.maze.styles[0]
	var ledge_top := style.mezzanine_height
	var ledges := 0
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.PIER):
		if is_equal_approx(piece.position.y + piece.size.y, ledge_top):
			ledges += 1
	check("ledges along the walls", ledges > 100, "(%d)" % ledges)
	var ivy: IvyClimb = null
	for climb: IvyClimb in features.climbs:
		if climb.bottom_y() < 0.1 and absf(climb.top_y() - ledge_top) < 0.1:
			ivy = climb
			break
	check("ivy up to the ledge", ivy != null, "(at %s)" % [ivy.global_position if ivy else Vector3.ZERO])
	if ivy:
		player.global_position = ivy.stand(0.05) + ivy.global_basis.z * 0.6
		player.velocity = Vector3.ZERO
		await frames(10)
		for i in 900:
			if player.state == player.State.LADDER:
				let_go()
				Input.action_press(&"move_up")
			else:
				steer(ivy.facing())
			await physics_frame
			if player.state == player.State.FREE and player.is_on_floor() and player.global_position.y > ledge_top - 0.3:
				break
		let_go()
		await frames(30)
		check("climbs onto the ledge and stands on it", player.is_on_floor() and absf(player.global_position.y - ledge_top) < 0.3, "(at %.2f, the ledge %.2f, state %d)" % [player.global_position.y, ledge_top, player.state])

	var strand = features.strands[0]
	# (the buttress under its first end, as high as it is held)
	var buttress := false
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TERRACE):
		if piece.box_has(strand.from - Vector3.UP * 0.5, 0.2):
			buttress = true
	check("held on a buttress", buttress)

	var middle: Vector3 = strand._points[RopeBridge.POINTS / 2]
	var across: Vector3 = (strand.to - strand.from).normalized().cross(Vector3.UP)
	var level_before: float = middle.y
	world.dev = null
	player.state = player.State.FREE
	player.global_position = middle + across * 0.12 + Vector3.UP * 0.4
	player.velocity = Vector3.ZERO
	await frames(90)
	var off: float = absf((player.global_position - strand._closest(player.global_position)).dot(across))
	check("stands on it", player.is_on_floor() and absf(player.global_position.y - strand._points[RopeBridge.POINTS / 2].y) < 0.6, "(at %.2f, the vine %.2f)" % [player.global_position.y, strand._points[RopeBridge.POINTS / 2].y])
	check("drawn back over it", off < 0.06, "(%.2f m to the side)" % off)
	check("it dips under him", strand._points[RopeBridge.POINTS / 2].y < level_before - 0.05, "(%.2f -> %.2f)" % [level_before, strand._points[RopeBridge.POINTS / 2].y])

	var vines_before: int = root.find_children("*", "Vine", true, false).size()
	var cut: bool = world.try_cut()
	await frames(2)
	var vines_after: int = root.find_children("*", "Vine", true, false).size()
	check("cut", cut and not is_instance_valid(strand), "")
	check("two vines hang where it was", vines_after == vines_before + 2, "(%d -> %d)" % [vines_before, vines_after])
	await frames(90)
	check("he keeps hold of his half", player.state == player.State.ROPE, "(state %d, at %.1f)" % [player.state, player.global_position.y])

	print("STRAND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
