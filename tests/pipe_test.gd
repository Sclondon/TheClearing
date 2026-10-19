extends SceneTree
## Sewer pipes (SewerPipe), headless: there are some in the first ring; the boy
## climbs the ivy under one onto its platform, crawls through the wall ducked,
## and comes out on the platform on the other side.
##
##     godot --headless --path . -s res://tests/pipe_test.gd

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
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down", &"jump", &"duck"]:
		Input.action_release(action)


func _initialize() -> void:
	# (the Avenues, which has sewer pipes: the rules set in the editor may have none)
	MazeStyle.chosen = [MazeStyle.avenues()]
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(30)
	var world = main.world
	world.dev = null
	var player = world.player
	var features = world.maze_features()
	check("sewer pipes", features.pipes.size() > 3, "(%d)" % features.pipes.size())
	if features.pipes.is_empty():
		quit(1)
		return
	var pipe: SewerPipe = features.pipes[0]
	var along: Vector3 = pipe.global_basis.z
	var floor_y := pipe.global_position.y
	var mouth: Vector3 = pipe.global_position - along * pipe.length * 0.5
	# (the ivy under that mouth)
	var ivy: IvyClimb = null
	for climb: IvyClimb in features.climbs:
		if absf(climb.top_y() - floor_y) < 0.1 and climb.global_position.distance_to(Vector3(mouth.x, climb.global_position.y, mouth.z)) < 3.0:
			ivy = climb
	check("ivy up to its platform", ivy != null)
	if ivy == null:
		quit(1)
		return
	player.global_position = ivy.stand(0.05) + ivy.global_basis.z * 0.6
	player.velocity = Vector3.ZERO
	await frames(10)
	for i in 1500:
		if player.state == player.State.LADDER:
			let_go()
			Input.action_press(&"move_up")
		else:
			steer(ivy.facing())
		await physics_frame
		if player.state == player.State.FREE and player.is_on_floor() and player.global_position.y > floor_y - 0.3:
			break
	let_go()
	await frames(20)
	check("climbs onto the platform", player.is_on_floor() and absf(player.global_position.y - floor_y) < 0.3, "(at %.2f, the floor %.2f)" % [player.global_position.y, floor_y])
	# Ducked, along the pipe to the far platform.
	var far_end: Vector3 = pipe.global_position + along * (pipe.length * 0.5 + 1.0)
	Input.action_press(&"duck")
	for i in 1500:
		var to: Vector3 = far_end - player.global_position
		to.y = 0.0
		if to.length() < 0.4:
			break
		steer(to.normalized())
		await physics_frame
	let_go()
	await frames(30)
	var through: float = (player.global_position - pipe.global_position).dot(along)
	check("crawls through to the other side", through > pipe.length * 0.5 and absf(player.global_position.y - floor_y) < 0.4, "(%.1f m along, at %.2f)" % [through, player.global_position.y])
	print("PIPE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
