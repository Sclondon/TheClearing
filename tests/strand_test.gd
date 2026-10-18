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
