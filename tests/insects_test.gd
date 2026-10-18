extends SceneTree
## The insects (scripts/wildlife/insects.gd, creatures/insects/), headless, in
## a round played alone. In turn: a round has the carcasses, wall moths, marsh
## dragonflies and dusk clouds its styles ask for, and moths at the light past
## the exit; none of them hunts (not in `pursuers`, not among what hunts);
## swarms far from the camera are neither drawn nor moved, and near ones are;
## moths gather round a light put in; flies gather round a carcass and buzz,
## and land on him when he stands still among them, and leave when he moves;
## flies come where he is caught; dragonflies over the marsh perch on the
## bulrushes; the dev panel's buttons put each kind in; and what it all costs
## a frame.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/insects_test.gd
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


func wait(seconds: float, until: Callable) -> bool:
	for i in int(seconds * 60.0):
		await process_frame
		if until.call():
			return true
	return false


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
	var maze: Maze = world.maze
	var player: Node3D = world.player
	var insects: Insects = world.insects
	check("insects in the round", insects != null and insects.is_inside_tree())
	var style: MazeStyle = maze.styles[0]
	var look: ClearingStyle = maze.clearing_style
	await frames(70)

	# How many, as the styles say.
	check("carcasses in dead ends", insects.carcasses.size() >= mini(style.carcasses, 1) and insects.carcasses.size() <= style.carcasses + 2, "(%d, style %d)" % [insects.carcasses.size(), style.carcasses])
	check("big moths on the walls", insects.wall_moths.size() > 0 and insects.wall_moths.size() <= style.wall_moths, "(%d, style %d)" % [insects.wall_moths.size(), style.wall_moths])
	var dragonflies := 0
	for swarm in insects.dragonflies:
		dragonflies += swarm.count
	var marsh_there := look.marsh_rect().has_area()
	check("dragonflies over the marsh", not marsh_there or absf(dragonflies - look.marsh_dragonflies) <= 6, "(%d, style %d)" % [dragonflies, look.marsh_dragonflies])
	check("clouds of moths over the clearing (out only at dusk)", insects.dusk_moths.size() == look.dusk_moth_clouds)
	var beacon: Node3D = world.get_node("Maze").beacon
	check("moths at the light past the exit", beacon != null and insects.moths.has(beacon.get_instance_id()))
	var flies_on_carcasses := insects.carcasses.all(func(c: Node3D) -> bool: return insects.flies.has(c.get_instance_id()))
	check("flies on every carcass", flies_on_carcasses)

	# None of them hunts.
	var hunting := false
	for swarm in insects._all():
		hunting = hunting or swarm.is_in_group(&"pursuers") or swarm.is_in_group(&"maze_enemies") or (swarm as Node).get_script() == MazeEnemy
	for dead in insects.carcasses:
		hunting = hunting or dead.is_in_group(&"pursuers") or dead.is_in_group(&"maze_enemies")
	check("none of them hunts", not hunting and get_nodes_in_group(&"pursuers").all(func(n: Node) -> bool: return not (n is InsectSwarm)))

	# Far away, nothing is drawn or moved; near, it is.
	var far_swarm: InsectSwarm = null if insects.carcasses.is_empty() else insects.flies.get(insects.carcasses[0].get_instance_id())
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	var far: int = insects._all().filter(func(s: InsectSwarm) -> bool: return s.middle().distance_to(camera.global_position) > s.active_range + s.radius + 5.0).size()
	var far_running: int = insects._all().filter(func(s: InsectSwarm) -> bool: return s.middle().distance_to(camera.global_position) > s.active_range + s.radius + 5.0 and s.running()).size()
	check("swarms far from the camera are not drawn or moved", far > 3 and far_running == 0, "(%d far, %d of them running, %d swarms in all)" % [far, far_running, insects._all().size()])
	if far_swarm:
		var before := far_swarm.insect_position(0)
		await frames(30)
		check("and do not move", far_swarm.insect_position(0) == before)
		world.put_player(far_swarm.middle() + Vector3(4.0, 0.2, 0.0), 0.0)
		await frames(30)
		check("near one is drawn and moved", far_swarm.running() and far_swarm.insect_position(0) != before)
		check("flies buzz", far_swarm.get_node_or_null(^"Buzz") != null and (far_swarm.get_node(^"Buzz") as AudioStreamPlayer3D).playing)
		# Stand still among them, and some land on him; move, and they are off.
		world.put_player(far_swarm.middle() + Vector3(0.9, 0.2, 0.4), 0.0)
		var landed := await wait(25.0, func() -> bool: return far_swarm.on_someone() > 0)
		check("flies land on him when he stands still", landed, "(%d on him)" % far_swarm.on_someone())
		world.put_player(far_swarm.middle() + Vector3(3.0, 0.2, 0.4), 0.0)
		await frames(10)
		world.put_player(far_swarm.middle() + Vector3(6.0, 0.2, 0.4), 0.0)
		await frames(10)
		check("and are off when he moves", far_swarm.on_someone() == 0)

	# Moths gather round a light put in.
	var spot: Vector3 = maze.world(maze.cell_at(player.global_position)) + Vector3(5.0, 0.0, 5.0)
	var lamp: Node3D = insects.put(InsectLook.Kind.MOTH, spot)
	await frames(80)
	var cloud: InsectSwarm = insects.moths.get(lamp.get_instance_id())
	check("a light put in draws moths", cloud != null and cloud.running(), "(%s)" % ("none" if cloud == null else "%d moths" % cloud.count))
	if cloud:
		await frames(240)
		var round_it := 0
		for i in cloud.count:
			if cloud.insect_position(i).distance_to(lamp.global_position) < cloud.radius * 2.2:
				round_it += 1
		check("and they flutter round it", round_it >= cloud.count * 0.8, "(%d of %d)" % [round_it, cloud.count])
		# The light moves; they go with it.
		lamp.global_position += Vector3(3.0, 0.0, 0.0)
		await frames(200)
		var middle := cloud.swarm_middle()
		check("and follow it", Vector2(middle.x - lamp.global_position.x, middle.z - lamp.global_position.z).length() < cloud.radius, "(%.1f m off)" % middle.distance_to(lamp.global_position))
		lamp.queue_free()
		await frames(80)
		check("and go with it", not is_instance_valid(cloud) or cloud.is_queued_for_deletion())

	# Caught: flies come to where he was.
	var where := maze.world(maze.exit) + Vector3(2.0, 0.3, 1.0)
	for cell in MazeNav.new(maze).lairs(4):
		where = maze.world(cell) + Vector3(1.0, 0.3, 0.0)
		break
	world.put_player(where, 0.0)
	await frames(10)
	var had := insects.caught_flies.size()
	world._back_to_the_clearing()
	await frames(5)
	var came: bool = insects.caught_flies.size() == had + 1
	var at: Vector3 = (insects.caught_flies.back()[0] as InsectSwarm).centre if came else Vector3.INF
	check("flies come where he was caught", came and Vector2(at.x - where.x, at.z - where.z).length() < 1.5, "(%s, he was at %s)" % [at, where])
	# (and only for a while)
	if came:
		insects.caught_flies.back()[1] = 0.5
		await frames(60)
		check("for a while", insects.caught_flies.size() == had)

	# Dragonflies over the marsh, perching on the bulrushes.
	if not insects.dragonflies.is_empty():
		var patch: InsectSwarm = insects.dragonflies[0]
		world.put_player(patch.middle() + Vector3(0.0, 0.5, patch.radius + 6.0), 0.0)
		await frames(20)
		check("dragonflies near are moved", patch.running())
		var perched := await wait(40.0, func() -> bool: return patch.resting() > 0)
		check("one perches on a bulrush", perched, "(%d resting)" % patch.resting())
		if perched:
			var k := 0
			for i in patch.count:
				if patch.state_of(i) == InsectSwarm.State.PERCH:
					k = i
			var near_tip := INF
			var marsh: Marsh = world.find_children("Marsh", "Node3D", true, false)[0]
			for j in marsh.bulrush_tops.size():
				var tip := marsh.bulrush_tops[j] + Marsh.bulrush_sway(marsh.bulrush_roots[j], fposmod(Time.get_ticks_msec() * 0.001, 3600.0))
				near_tip = minf(near_tip, tip.distance_to(patch.insect_position(k)))
			check("on its tip", near_tip < 0.05, "(%.3f m from the nearest)" % near_tip)
		# Walking up to it sends it off.
		var resting_one := -1
		for i in patch.count:
			if patch.state_of(i) == InsectSwarm.State.PERCH:
				resting_one = i
		if resting_one >= 0:
			world.put_player(patch.insect_position(resting_one) + Vector3(1.0, -1.5, 0.0), 0.0)
			var off := await wait(2.0, func() -> bool: return patch.state_of(resting_one) == InsectSwarm.State.FLY)
			check("and flies off when he comes near", off)

	# The dev panel's buttons.
	if world.dev == null:
		world.dev = load("res://scripts/dev_tools.gd").new(world)
	var lights: int = get_nodes_in_group(Insects.LIGHTS).size()
	var dead: int = insects.carcasses.size()
	var patches: int = insects.dragonflies.size()
	world.dev.spawn_insects(InsectLook.Kind.MOTH)
	world.dev.spawn_insects(InsectLook.Kind.FLY)
	world.dev.spawn_insects(InsectLook.Kind.DRAGONFLY)
	await frames(80)
	check("MOTHS, FLIES, DRAGONFLIES", get_nodes_in_group(Insects.LIGHTS).size() == lights + 1 and insects.carcasses.size() == dead + 1 and insects.dragonflies.size() == patches + 1)

	# What they cost: everything near him moved, as a frame of the round goes.
	var most := 0
	var sum := 0
	var running := 0
	for i in 120:
		await process_frame
		most = maxi(most, InsectSwarm.cost_total)
		sum += InsectSwarm.cost_total
		running = maxi(running, insects.running())
	print("COST: %d swarms running, %.3f ms a frame on average, %.3f ms at most" % [running, sum / 120.0 / 1000.0, most / 1000.0])
	check("and cost little", sum / 120.0 < 1500.0, "(%.2f ms)" % (sum / 120.0 / 1000.0))

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
