extends SceneTree
## Hanging from strung vines (Player._try_catch_strand, _hang_strand), headless:
## the boy falls past a strung vine and catches it; hangs under it, going with it;
## goes hand over hand along it; pulls himself up onto it and stands on it as a
## tightrope; ducks and is hanging under it again; ducks again and drops.
##
##     godot --headless --path . -s res://tests/strand_hang_test.gd

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
	# (the game's own rules, not whatever the maze editor is set to: they have strung vines)
	MazeStyle.chosen = MazeStyle.defaults()
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
	world.dev = null
	# A long one, about level, well up off the ground: a tightrope across a hall.
	var strand: VineStrand = null
	for each: VineStrand in world.maze_features().strands:
		if absf(each.from.y - each.to.y) < 1.0 and each.span() > 7.0 and (strand == null or each.span() > strand.span()):
			strand = each
	check("a strung vine across a hall", strand != null)
	if strand == null:
		_end()
		return
	var middle := strand.point_at_distance(strand.span() * 0.5)
	var across := strand.line().cross(Vector3.UP)

	# Falling past it, just to one side of it: he catches it.
	player.state = player.State.FREE
	player.global_position = middle + across * 0.35 + Vector3.UP * 0.6 - Vector3.UP * player.hang_height
	player.velocity = Vector3.ZERO
	await frames(40)
	check("catches it falling past", player.state == player.State.HANG and player._strand == strand, "(state %d)" % player.state)
	var hands: Vector3 = player.global_position + Vector3.UP * player.hang_height
	check("hangs under it by his hands", strand.point_near(hands).distance_to(hands) < 0.25, "(%.2f m from it)" % strand.point_near(hands).distance_to(hands))
	await frames(30)
	check("still hanging", player.state == player.State.HANG)

	# Hand over hand along it.
	var along: float = strand.distance_along(player.global_position)
	var left: Vector3 = player._ledge_left()
	var camera_right: Vector3 = world.camera.global_transform.basis.x
	var action := &"move_right" if camera_right.dot(left) > 0.0 else &"move_left"
	Input.action_press(action)
	await frames(60)
	Input.action_release(action)
	var moved := absf(strand.distance_along(player.global_position) - along)
	check("goes hand over hand along it", moved > 0.4 and player.state == player.State.HANG, "(%.2f m)" % moved)

	# Up onto it.
	# (a press as the input handler takes it: Input.action_press sends no event)
	player._queue_jump()
	await frames(90)
	var feet: Vector3 = player.global_position
	check("pulls himself up onto it", player.state == player.State.FREE and absf(feet.y - strand.point_near(feet).y) < 0.5, "(state %d, %.2f over it)" % [player.state, feet.y - strand.point_near(feet).y])
	await frames(30)
	check("stands on it as a tightrope", player.tightrope > 0.0 and player.tightrope_on == strand, "(%.2f)" % player.tightrope)

	# Down off it again: duck.
	Input.action_press(&"duck")
	await frames(4)
	Input.action_release(&"duck")
	await frames(20)
	check("ducks and hangs under it", player.state == player.State.HANG and player._strand == strand, "(state %d)" % player.state)
	await frames(30)
	Input.action_press(&"duck")
	await frames(4)
	Input.action_release(&"duck")
	await frames(30)
	check("ducks again and drops", player.state == player.State.FREE and player.global_position.y < middle.y - player.hang_height - 0.3, "(state %d, at %.1f)" % [player.state, player.global_position.y])
	_end()


func _end() -> void:
	print("STRAND HANG TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(1 if failures else 0)
