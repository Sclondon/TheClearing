extends SceneTree
## Bridges' and strung vines' bodies only near someone (RopeBridge.Bodies), headless:
## how many bodies a solo round makes as it starts (well under Jolt's limit), a strung
## vine far off with none, its planks made as he comes up to it and gone once he has
## left it behind; and the boy has a body of his own.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/bodies_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func bodies() -> int:
	return root.find_children("*", "CollisionObject3D", true, false).size()


func _initialize() -> void:
	MazeStyle.chosen = MazeStyle.defaults()
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(90)
	var world = main.world
	var player = world.player
	var features = world.maze_features()
	var total := bodies()
	var solid := 0
	var all: Array = []
	all.append_array(features.bridges)
	all.append_array(features.strands)
	for bridge: RopeBridge in all:
		if bridge.has_bodies():
			solid += 1
	print("bridges %d, strung vines %d; with bodies %d" % [features.bridges.size(), features.strands.size(), solid])
	check("bodies as the round starts", total < 10000, "(%d)" % total)
	check("the boy has a body", PhysicsServer3D.body_get_space(player.get_rid()).is_valid())

	# A strung vine far from him: no bodies. Then he comes up to it, as fast as he runs.
	var strand: VineStrand = null
	for each: VineStrand in features.strands:
		if each.reach_to(player.global_position) > 120.0:
			strand = each
			break
	check("a strung vine far off", strand != null)
	if strand == null:
		quit(1)
		return
	check("far off, it has no bodies", not strand.has_bodies())
	var middle: Vector3 = strand._points[RopeBridge.POINTS / 2] + Vector3.UP * 0.4
	var along := (strand.to - strand.from)
	along.y = 0.0
	var start := middle + along.normalized().cross(Vector3.UP) * 70.0
	player.state = player.State.FREE
	var made_at := -1.0
	var steps := int(70.0 / 6.3 * Engine.physics_ticks_per_second)
	for i in steps + 1:
		player.global_position = start.lerp(middle, float(i) / steps)
		player.velocity = Vector3.ZERO
		await physics_frame
		if made_at < 0.0 and strand.has_bodies():
			made_at = strand.reach_to(player.global_position)
	check("its bodies are made as he comes up to it", made_at > 5.0, "(%.1f m off)" % made_at)
	var planks := strand.find_children("*", "AnimatableBody3D", false, false).size()
	check("a body a plank", planks == RopeBridge.POINTS - 1, "(%d)" % planks)
	# (and he stands on it)
	await frames(60)
	check("stands on it", player.is_on_floor() and absf(player.global_position.y - strand._points[RopeBridge.POINTS / 2].y) < 0.6,
		"(at %.2f, the vine %.2f)" % [player.global_position.y, strand._points[RopeBridge.POINTS / 2].y])

	# He goes off a long way: its bodies go.
	player.global_position = start + (start - middle).normalized() * 40.0 + Vector3.UP * 30.0
	for i in 90:
		player.global_position = start + (start - middle).normalized() * 40.0 + Vector3.UP * 30.0
		player.velocity = Vector3.ZERO
		await physics_frame
	await process_frame
	check("gone once he has left it", not strand.has_bodies() and strand.find_children("*", "AnimatableBody3D", false, false).is_empty())
	check("bodies still few", bodies() < 10000, "(%d)" % bodies())

	print("BODIES TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
