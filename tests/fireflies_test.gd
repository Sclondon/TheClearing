extends SceneTree
## The fireflies (creatures/fireflies/, and Insects' `fireflies` in
## scripts/wildlife/insects.gd), headless. First a FireflyField on its own: by day
## nothing is drawn; at night the patches near the camera are, nearest first and
## no more than `max_drawn`, and those far off are not; the beetles are drawn only
## close to the camera; someone running scatters them and it dies away when he
## stops; the same patches make the same fireflies; refilling as the camera moves
## costs little. Then in a round played alone: the clearing and the first ring
## have the patches their styles ask for, on the ground; none is out by day; they
## come out at dusk and are drawn round him at night; everyone scatters them; and
## the dev panel's cloud puts them out whatever the hour.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/fireflies_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await process_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await frames(2)
	await _alone()
	await _in_a_round()
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)


func _alone() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(0.0, 1.6, 0.0)
	var field := FireflyField.new()
	field.max_drawn = 200
	stage.add_child(field)
	var near := field.add_patch(Vector3(4.0, 0.0, 0.0), 5.0, 60, Vector2(0.3, 1.5), 11)
	field.add_patch(Vector3(30.0, 0.0, 10.0), 5.0, 60, Vector2(0.3, 1.5), 12)
	field.add_patch(Vector3(-50.0, 0.0, 0.0), 5.0, 60, Vector2(0.3, 1.5), 13)
	field.add_patch(Vector3(400.0, 0.0, 0.0), 5.0, 60, Vector2(0.3, 1.5), 14)
	check("patches put in", field.patch_count() == 4 and field.total() == 240, "(%d patches, %d fireflies)" % [field.patch_count(), field.total()])
	field.night = 0.0
	await frames(3)
	check("by day none are drawn", not field.showing())
	field.night = 1.0
	await frames(3)
	check("at night the near ones are drawn", field.showing() and field.drawn > 0)
	check("no more than max_drawn", field.drawn <= field.max_drawn, "(%d)" % field.drawn)
	check("the far patch is not drawn", field.drawn == 180 and field.drawn < field.total(), "(%d of %d)" % [field.drawn, field.total()])
	check("the beetles only close by", field.bodies_drawn > 0 and field.bodies_drawn <= field.max_bodies, "(%d)" % field.bodies_drawn)
	# Every firefly's home is on the ground of its patch, inside it.
	var patch: Array = field._patches[near]
	var inside := true
	for home: Vector3 in (patch[2] as PackedVector3Array):
		inside = inside and Vector2(home.x - 4.0, home.z).length() <= 5.01 and is_equal_approx(home.y, 0.0)
	check("homes inside their patch, on the ground", inside)
	# The same seed, the same fireflies.
	var other := FireflyField.new()
	stage.add_child(other)
	other.add_patch(Vector3(4.0, 0.0, 0.0), 5.0, 60, Vector2(0.3, 1.5), 11)
	check("the same patch makes the same fireflies", (other._patches[0][2] as PackedVector3Array) == (patch[2] as PackedVector3Array) and (other._patches[0][3] as PackedFloat32Array) == (patch[3] as PackedFloat32Array))
	other.queue_free()
	# Kinds: all three, each its own share.
	var kinds := [0, 0, 0]
	for p: Array in field._patches:
		var customs: PackedFloat32Array = p[3]
		for i in customs.size() / 4:
			kinds[int(customs[i * 4 + 1])] += 1
	check("all three kinds among them", kinds[0] > 0 and kinds[1] > 0 and kinds[2] > 0, str(kinds))
	# Someone running through scatters them; standing, it dies away.
	var runner := Node3D.new()
	stage.add_child(runner)
	field.scarers = [runner]
	for i in 30:
		runner.global_position = Vector3(i * 0.1, 0.0, 0.0)
		await process_frame
	var scared: float = field._scare[0]
	check("running scatters them", scared > 0.5, "(%.2f)" % scared)
	await create_timer(1.5).timeout
	check("standing still, they drift back", field._scare[0] < scared * 0.6, "(%.2f)" % field._scare[0])
	# The camera moves: it refills, nearer ones first, cheaply.
	camera.global_position = Vector3(-50.0, 1.6, 0.0)
	await frames(2)
	check("refilled where the camera went", field.drawn > 0 and field._filled_at.distance_to(camera.global_position) < 1.0)
	check("a refill costs little", field.cost < 3000, "(%d us)" % field.cost)
	stage.queue_free()
	await frames(2)


func _in_a_round() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	await frames(5)
	main.start_solo()
	await frames(40)
	var world = main.world
	var maze: Maze = world.maze
	var insects: Insects = world.insects
	var field: FireflyField = insects.fireflies
	check("fireflies in the round", field != null and field.is_inside_tree())
	var look: ClearingStyle = maze.clearing_style
	var style: MazeStyle = maze.styles[0]
	var clouds := int(Insects._rule(look, &"firefly_clouds", 36))
	var patches := int(Insects._rule(style, &"firefly_patches", 24))
	var in_clearing := 0
	var in_ring := 0
	var grounded := true
	for k in field.patch_count():
		var at := field.patch_middle(k)
		var ring := maze.ring_of(maze.cell_at(at))
		if ring == 0:
			in_clearing += 1
		elif ring == 1:
			in_ring += 1
		grounded = grounded and absf(at.y - maxf(maze.ground_height(at), ClearingStyle.MARSH_LEVEL if look.marsh_rect().has_point(Vector2(at.x, at.z)) else -INF)) < 0.05
	check("clouds over the clearing as its style says", in_clearing >= clouds * 0.8 and in_clearing <= clouds, "(%d, style %d)" % [in_clearing, clouds])
	check("patches in the first ring", in_ring > patches * 0.5 and in_ring <= patches, "(%d, style %d)" % [in_ring, patches])
	check("each patch on the ground (or the marsh's water)", grounded)
	check("none of them hunts", not field.is_in_group(&"pursuers") and not field.is_in_group(&"maze_enemies"))
	var day: DayCycle = world.day
	day.set_hour(12.0)
	await frames(4)
	check("none out by day", field.night == 0.0 and not field.showing())
	day.set_hour(DayCycle.SUNSET + 0.2)
	await frames(4)
	var dusk := field.night
	day.set_hour(23.0)
	await frames(4)
	check("coming out at dusk, all out at night", dusk > 0.0 and dusk < 1.0 and field.night == 1.0, "(dusk %.2f, night %.2f)" % [dusk, field.night])
	# At night, out in the clearing near a cloud: drawn round him.
	var meadow := field.patch_middle(0)
	world.put_player(meadow + Vector3(0.0, 0.3, 3.0), 0.0)
	await frames(10)
	check("drawn round him at night", field.showing() and field.drawn > 0, "(%d drawn)" % field.drawn)
	await frames(70)
	check("he scatters them", field.scarers.has(world.player))
	# The dev panel's cloud: out whatever the hour.
	day.set_hour(12.0)
	var before := field.patch_count()
	insects.put_fireflies(world.player.global_position + Vector3(0.0, 0.0, 4.0))
	await frames(4)
	check("the dev panel's cloud, out by day", field.patch_count() == before + 1 and field.night == 1.0 and field.showing())
	insects.fireflies_out = false
	main.queue_free()
	await frames(2)
