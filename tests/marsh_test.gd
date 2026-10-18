extends SceneTree
## The marsh in front of the clearing's flooded entrance (Marsh): built before
## the maze goes into the world (as some tests build it) and after, it is there
## with its water, and the water looks as it was asked to; it is wide, mostly
## shallow water and wet ground with a few deep pools; sedges may grow in the
## shallow water but not in the deep pools; the lane in from its gate has
## nothing deep and nothing standing in it; it meets the field without a step;
## its ground can be stood on; and no tree stands in it.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/marsh_test.gd

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	for seed_value: int in [1234, 77]:
		await _one(seed_value)
	print("MARSH TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


func _one(seed_value: int) -> void:
	print("-- seed %d" % seed_value)
	var maze := Maze.generate(seed_value, 1)
	var look := maze.clearing_style
	var way := look.entrance(ClearingStyle.Entrance.MARSH)
	check("a flooded entrance", not way.is_empty())
	if way.is_empty():
		return
	# Built out of the world first (the pond's water used to be looked at before
	# it was made, an error in every test built this way), then put in.
	var started := Time.get_ticks_usec()
	var builder := MazeBuilder.new()
	builder.build(maze)
	var took := (Time.get_ticks_usec() - started) / 1000.0
	var marsh := builder.get_node_or_null("Marsh") as Marsh
	check("the marsh is built", marsh != null)
	if marsh == null:
		builder.free()
		return
	var marsh_started := Time.get_ticks_usec()
	var again := Marsh.new()
	again.realize(maze)
	print("built the maze in %.0f ms; the marsh alone %.0f ms" % [took, (Time.get_ticks_usec() - marsh_started) / 1000.0])
	again.free()
	root.add_child(builder)
	for i in 3:
		await physics_frame
	check("it has its water", marsh.water != null and marsh.water.water != null and marsh.water.is_in_group(&"water"))
	if marsh.water and marsh.water.water:
		check("the water looks as asked", marsh.water.water.foam.is_equal_approx(marsh.water.look["foam"]) and not marsh.water.water.sides)
		check("the water stands at the marsh level", is_equal_approx(marsh.water.surface_y(), ClearingStyle.MARSH_LEVEL))
	check("wide", marsh.area.size.x > 150.0 and marsh.area.size.y > 100.0, str(marsh.area.size))

	# Over the marsh proper: how much is shallow water, wet ground, deep pool.
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var inside := 0
	var shallow := 0
	var ground := 0
	var deep := 0
	var sedge_in_water := 0
	var sedge_in_deep := 0
	var off_by := 0.0
	var off_sum := 0.0
	for i in 8000:
		var p := marsh.area.position + Vector2(rng.randf(), rng.randf()) * marsh.area.size
		var off := absf(marsh.ground_at(p) - maze.ground_height(Vector3(p.x, 0.0, p.y)))
		off_by = maxf(off_by, off)
		off_sum += off
		if look.marsh_wet_at(p, maze.maze_seed) < 0.9:
			continue
		inside += 1
		var depth := marsh.depth_at(p)
		if depth > look.marsh_grass_depth:
			deep += 1
			if marsh.sedge_at(p) > 0.0:
				sedge_in_deep += 1
		elif depth > 0.03:
			shallow += 1
			if marsh.sedge_at(p) > 0.0:
				sedge_in_water += 1
		else:
			ground += 1
	print("inside %d: shallow water %d, wet ground %d, deep %d" % [inside, shallow, ground, deep])
	check("plenty of shallow water", shallow > inside * 0.25)
	check("plenty of wet ground", ground > inside * 0.2)
	check("a few deep pools", deep > 0 and deep < inside * 0.3)
	check("sedges grow up out of the shallow water", sedge_in_water > shallow * 0.5, "(%d of %d)" % [sedge_in_water, shallow])
	check("none in the deep pools", sedge_in_deep == 0, "(%d)" % sedge_in_deep)
	check("its ground is the style's (but for the steepest, between its points)", off_sum / 8000.0 < 0.02 and off_by < 0.5, "(%.3f m out on average, %.3f at most)" % [off_sum / 8000.0, off_by])

	# The lane in from its gate.
	var deepest_in_lane := -10.0
	var reeds_in_lane := 0
	for i in 3000:
		var p := gate + inward * rng.randf_range(0.0, ClearingStyle.MARSH_LANE.y) + side * rng.randf_range(-ClearingStyle.MARSH_LANE.x, ClearingStyle.MARSH_LANE.x)
		deepest_in_lane = maxf(deepest_in_lane, marsh.depth_at(p))
		if marsh.reed_at(p) > 0.0:
			reeds_in_lane += 1
	check("nothing deep in the lane in from the gate", deepest_in_lane < look.marsh_shallow_depth + 0.05, "(%.2f m)" % deepest_in_lane)
	check("no reeds in the lane", reeds_in_lane == 0)
	var standing := 0
	for found: Node in marsh.get_children():
		if found is MultiMeshInstance3D:
			var multi := (found as MultiMeshInstance3D).multimesh
			for i in multi.instance_count:
				var at := multi.get_instance_transform(i).origin
				if look.marsh_lane_at(Vector2(at.x, at.z)) > 0.5:
					standing += 1
	check("no bulrush nor lily pad in the lane", standing == 0, "(%d)" % standing)
	check("bulrushes and lily pads", marsh.bulrush_count > 100 and marsh.lily_pad_count > 50, "(%d, %d)" % [marsh.bulrush_count, marsh.lily_pad_count])
	check("level and dry at the foot of the wall", absf(maze.ground_height(Vector3(gate.x, 0.0, gate.y) + Vector3(inward.x, 0.0, inward.y) * 1.0)) < 0.01)

	# It meets the field without a step round its edge.
	var step := 0.0
	var rect := marsh.area
	for i in 400:
		var t := i / 400.0
		for p: Vector2 in [rect.position + Vector2(rect.size.x * t, 0.5), rect.position + Vector2(0.5, rect.size.y * t), rect.end - Vector2(rect.size.x * t, 0.5), rect.end - Vector2(0.5, rect.size.y * t)]:
			step = maxf(step, absf(look.coarse_height_at(p.x, p.y, maze.maze_seed) - look.height_at(p.x, p.y, maze.maze_seed)))
	check("no step at its edge", step < 0.02, "(%.3f m)" % step)
	check("the hills' coarse ground sunk under it", look.coarse_height_at(rect.get_center().x, rect.get_center().y, maze.maze_seed) < ClearingStyle.MARSH_LEVEL - look.marsh_pool_depth)

	# Stood on: a ray down onto shallow water finds its own ground.
	var space := builder.get_world_3d().direct_space_state
	var worst := 0.0
	var rays := 0
	for i in 400:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		if look.marsh_wet_at(p, maze.maze_seed) < 0.5:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 5.0, p.y), Vector3(p.x, -10.0, p.y)))
		if hit.is_empty():
			worst = INF
			break
		rays += 1
		worst = maxf(worst, absf(hit.position.y - marsh.ground_at(p)))
	check("its ground is stood on", rays > 50 and worst < 0.1, "(%d rays, %.3f m out at most)" % [rays, worst])
	check("the water is waded in", marsh.water.depth_at(Vector3(gate.x, ClearingStyle.MARSH_LEVEL - 0.3, gate.y) + Vector3(inward.x, 0.0, inward.y) * 40.0) > 0.25)

	# No tree in it.
	var trees_in := 0
	for piece in builder.layout.pieces(MazePiece.Kind.TREE):
		if look.marsh_wet_at(Vector2(piece.position.x, piece.position.z), maze.maze_seed) > 0.0:
			trees_in += 1
	check("no tree in it", trees_in == 0, "(%d)" % trees_in)
	builder.queue_free()
	await process_frame
