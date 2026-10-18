extends SceneTree
## The peaceful herds (scripts/wildlife.gd), headless, in a bare scene: a maze
## from MazeBuilder and the boy in it. In turn: the clearing has the herds its
## style asks for, out in the meadow (away from the middle and from the ways to
## the gates), and the rings theirs; the same seed puts the same animals in the
## same places; none of them is a hunter; a herd watches him come, runs off
## when he is near (and catches nobody), and settles to graze again; herds far
## from him are not drawn.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/wildlife_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var boy
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait(seconds: float, until: Callable) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.call():
			return true
	return false


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	stage.add_child(builder)
	builder.build(maze)
	# (a stand-in for him: where he is, and how fast he goes)
	boy = Walker.new()
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func _run() -> void:
	await frames(10)
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	var life := Wildlife.new()
	stage.add_child(life)
	life.populate(maze, 1234)
	var look: ClearingStyle = maze.clearing_style
	var in_clearing: Array = life.herds.filter(func(h: Wildlife.Herd) -> bool: return h.clearing)
	check("the clearing's herds", in_clearing.size() == look.deer_herds + look.elk_herds, "(%d)" % in_clearing.size())
	var rings := 0
	for ring in mini(maze.styles.size(), maze.rings):
		var style: MazeStyle = maze.styles[ring]
		rings += style.wild_deer_herds + style.wild_elk_herds
	check("and the rings' herds, in their halls", life.herds.size() - in_clearing.size() == rings and rings > 0
			and life.herds.all(func(h: Wildlife.Herd) -> bool: return h.clearing or not maze.in_clearing(maze.cell_at(h.home))))
	var placed := true
	for herd: Wildlife.Herd in in_clearing:
		var flat := Vector2(herd.home.x, herd.home.z)
		var off_axis := minf(absf(flat.x), absf(flat.y))
		placed = placed and flat.length() > 100.0 and off_axis > 40.0
	check("out in the meadow: off the middle, off the ways to the gates", placed)
	var kinds := {}
	for herd: Wildlife.Herd in life.herds:
		for one: Wildlife.Animal in herd.animals:
			kinds["fawn" if one.node.fawn else ("young" if one.young else ("cow" if one.node is Elk and (one.node as Elk).cow else "adult"))] = true
	check("deer with fawns, elk with cows and calves", kinds.has("fawn") and kinds.has("cow") and kinds.has("young"), str(kinds.keys()))
	var hunters := life.animals().filter(func(d: Deer) -> bool: return d.is_in_group(&"pursuers") or d.is_in_group(&"maze_enemies"))
	check("none of them hunts", hunters.is_empty())
	var again := Wildlife.new()
	stage.add_child(again)
	again.populate(maze, 1234)
	var same := again.herds.size() == life.herds.size()
	for k in mini(again.herds.size(), life.herds.size()):
		same = same and again.herds[k].home.is_equal_approx(life.herds[k].home) and again.herds[k].animals.size() == life.herds[k].animals.size()
	check("the same seed, the same herds in the same places", same)
	again.queue_free()

	# A herd in the meadow: he walks up to it
	var herd: Wildlife.Herd = in_clearing[0]
	var middle := herd.middle()
	var toward := (Vector3(-middle.x, 0.0, -middle.z)).normalized()
	boy.global_position = middle + toward * 28.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.3
	var watching := await wait(2.0, func() -> bool: return herd.mode == Wildlife.Mode.WATCH)
	await frames(30)
	check("he comes in sight: they watch him", watching and herd.animals[0].node.alert)
	boy.global_position = middle + toward * 9.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.3
	var fled := await wait(2.0, func() -> bool: return herd.mode == Wildlife.Mode.FLEE)
	check("he comes near: they run", fled)
	await frames(20)
	check("the deer stot, white tails up", herd.kind != Wildlife.Kind.DEER or herd.animals[0].node.flagging)
	await frames(90)
	var after := herd.middle()
	check("away from him", after.distance_to(boy.global_position) > middle.distance_to(boy.global_position) + 6.0,
			"(%.0f m to %.0f m)" % [middle.distance_to(boy.global_position), after.distance_to(boy.global_position)])
	var settled := await wait(16.0, func() -> bool: return herd.mode in [Wildlife.Mode.SETTLE, Wildlife.Mode.GRAZE, Wildlife.Mode.WATCH])
	check("and settle again", settled, "(%s)" % Wildlife.Mode.keys()[herd.mode])
	var still_in: bool = absf(herd.middle().x) < maze.clearing * Maze.CELL * 0.5 and absf(herd.middle().z) < maze.clearing * Maze.CELL * 0.5
	check("still in the clearing", still_in)
	# Far from him, not drawn
	var far_herd: Wildlife.Herd = null
	for one: Wildlife.Herd in life.herds:
		if one.middle().distance_to(boy.global_position) > Wildlife.POSE_RANGE + 20.0:
			far_herd = one
	await frames(40)
	check("a herd far off is not drawn", far_herd != null and not far_herd.posed and not far_herd.animals[0].node.visible)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


class Walker:
	extends Node3D
	var velocity := Vector3.ZERO
