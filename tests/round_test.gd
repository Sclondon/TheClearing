extends SceneTree
## The round sections (RoundMaze), headless, for a few seeds: there are three,
## each further out than the last, past the square maze's corners; every cell
## of each can be got to from its gates in, so its ways out can be.
##
##     godot --headless --path . -s res://tests/round_test.gd

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


## The forest, swamp and plains quarters (WildLands): each has its things, all
## inside its wedge, nothing in the way near a door or gate.
func _wilds(seed_value: int) -> void:
	var maze := Maze.generate(seed_value, 7)
	var lands := maze.round_rings.wilds
	check("seed %d: the wild quarters planned" % seed_value, lands != null)
	if lands == null:
		return
	var squares := lands.squares()
	for side in WildLands.SIDES:
		var biome := lands.look.biome_of(side)
		if biome == DesertStyle.Biome.DESERT:
			continue
		var name: String = DesertStyle.Biome.keys()[biome].to_lower()
		var found := {"trees": 0, "snags": 0, "logs": 0, "rocks": 0, "big rocks": 0, "ferns": 0, "bushes": 0, "bulrushes": 0, "lily pads": 0, "mist": 0}
		var outside := 0
		var in_the_way := 0
		var highest := 0.0
		var lowest := INF
		for square in squares:
			if not lands.biomes_in(square).has(biome):
				continue
			var c := lands.contents(square)
			for blocker: Array in c.blockers:
				var p: Vector2 = blocker[0]
				if DesertStyle.quarter_at(p.x, p.y) != side:
					continue
				if lands.margin_at(p) < blocker[1] + 1.0:
					outside += 1
				if lands.ways_distance(p) < lands.look.keep_clear_radius:
					in_the_way += 1
			found.trees += c.trees.size()
			found.snags += c.snags.size()
			found.logs += c.logs.size()
			found.rocks += c.rocks.size()
			for rock: Array in c.rocks:
				found["big rocks"] += 1 if rock[2] >= 6.0 else 0
			found.ferns += c.plants.get(Undergrowth.Kind.FERN, []).size()
			found.bushes += c.plants.get(Undergrowth.Kind.BUSH, []).size()
			for kind: int in c.rushes:
				found.bulrushes += c.rushes[kind].size()
			found["lily pads"] += c.pads.size()
			found.mist += c.mist.size()
			if (square.x + square.y) % 4 == 0:
				var middle := (Vector2(square) + Vector2(0.5, 0.5)) * WildLands.SQUARE
				if DesertStyle.quarter_at(middle.x, middle.y) == side and lands.margin_at(middle) > 30.0:
					var h := lands.height_at(middle.x, middle.y)
					highest = maxf(highest, h)
					lowest = minf(lowest, h)
		var wanted := {
			DesertStyle.Biome.FOREST: ["trees", "logs", "ferns", "bushes"],
			DesertStyle.Biome.SWAMP: ["snags", "bulrushes", "lily pads", "mist"],
			DesertStyle.Biome.PLAINS: ["rocks", "big rocks"],
		}
		for what: String in wanted[biome]:
			check("seed %d: the %s quarter has %s" % [seed_value, name, what], found[what] > (500 if what == "trees" else 0), "(%d)" % found[what])
		check("seed %d: the %s quarter's things inside its walls" % [seed_value, name], outside == 0, "(%d not)" % outside)
		check("seed %d: the %s quarter's doors and gates clear" % [seed_value, name], in_the_way == 0, "(%d in the way)" % in_the_way)
		if biome == DesertStyle.Biome.SWAMP:
			var pool: Rect2 = lands.pools[side]
			var inside := true
			for corner: Vector2 in [pool.position, pool.end, Vector2(pool.position.x, pool.end.y), Vector2(pool.end.x, pool.position.y)]:
				inside = inside and lands.margin_at(corner) > 1.0 and DesertStyle.quarter_at(corner.x, corner.y) == side
			check("seed %d: the swamp's water inside its walls" % seed_value, inside)
			check("seed %d: the swamp's hummocks stand out of its water, and its pools are under it" % seed_value, highest > lands.water_level() and lowest < lands.water_level(), "(%.2f to %.2f, water %.2f)" % [lowest, highest, lands.water_level()])
		if biome == DesertStyle.Biome.PLAINS:
			check("seed %d: the plains have hills" % seed_value, highest > 2.0, "(%.1f m)" % highest)
		# (the dry ground is level with the square maze's floor at the doors)
		for door: Vector2 in maze.round_rings.doors:
			if DesertStyle.quarter_at(door.x, door.y) == side:
				check("seed %d: the %s quarter's ground meets the door" % [seed_value, name], absf(lands.height_at(door.x, door.y)) < 0.05)


## The wild quarters built (Wilds) round a spot in each: the trunks and rocks
## are there to bump into, and the swamp's and plains' ground to walk on.
func _wilds_built(seed_value: int) -> void:
	if seed_value != 77:
		return
	var maze := Maze.generate(seed_value, 7)
	var lands := maze.round_rings.wilds
	var wilds := Wilds.new()
	root.add_child(wilds)
	wilds.realize(lands, StandardMaterial3D.new())
	for side in WildLands.SIDES:
		var biome := lands.look.biome_of(side)
		if biome == DesertStyle.Biome.DESERT:
			continue
		var name: String = DesertStyle.Biome.keys()[biome].to_lower()
		var middle := Vector2(side) * (lands.plan.square_half + lands.plan.inner_radius) * 0.5
		var square := Vector2i((middle / WildLands.SQUARE).floor())
		wilds.fill_near(Vector3(middle.x, 0.0, middle.y), 40.0)
		for i in 3:
			await physics_frame
		var space := wilds.get_world_3d().direct_space_state
		var c := lands.contents(square)
		var standing: Array = c.trees + c.snags + c.rocks
		if standing.is_empty():
			check("seed %d: something stands in the middle of the %s quarter" % [seed_value, name], false)
			continue
		var hits := 0
		for thing: Array in standing:
			var foot: Vector3 = (thing[0] as Transform3D).origin
			var ground := lands.height_at(foot.x, foot.z)
			var radius: float = thing[2]
			var from := Vector3(foot.x + radius + 2.0, ground + 0.5, foot.z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(foot.x, ground + 0.5, foot.z)))
			if not hit.is_empty():
				hits += 1
		check("seed %d: what stands in the %s quarter is bumped into" % [seed_value, name], hits >= standing.size() * 0.9, "(%d of %d)" % [hits, standing.size()])
		if biome != DesertStyle.Biome.FOREST:
			var spot := middle + Vector2(7.3, 5.1)
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(spot.x, 40.0, spot.y), Vector3(spot.x, -5.0, spot.y)))
			var want := lands.ground_at(spot)
			var landed: float = (down.position as Vector3).y if not down.is_empty() else -99.0
			# (or on something standing there)
			check("seed %d: the %s quarter's ground walked on where it is drawn" % [seed_value, name], landed > want - 0.15, "(%.2f, drawn %.2f)" % [landed, want])
	check("seed %d: the wild quarters built near only" % seed_value, wilds.built_count() > 0 and wilds.built_count() < lands.squares().size())
	wilds.free()


func _run() -> void:
	for seed_value in [1, 77, 4242]:
		var maze := Maze.generate(seed_value, 7)
		var plan := maze.round_rings
		check("seed %d: three round sections" % seed_value, plan != null and plan.rings.size() == 3)
		if plan == null:
			continue
		check("seed %d: past the square's corners" % seed_value, plan.inner_radius > maze.extent() * 0.5 * sqrt(2.0))
		for k in plan.rings.size():
			var ring: RoundMaze.Ring = plan.rings[k]
			var seen := {}
			var queue: Array[Vector2i] = []
			for g: float in ring.gates_in:
				var cell := Vector2i(0, RoundMaze.cell_at(g, ring.rows[0][2]))
				seen[cell] = true
				queue.append(cell)
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for next: Vector2i in plan._neighbours(ring, cell):
					if not seen.has(next) and RoundMaze.joined(ring, cell, next):
						seen[next] = true
						queue.append(next)
			var cells := 0
			for row: Array in ring.rows:
				cells += row[2]
			check("seed %d: section %d all joined up" % [seed_value, maze.rings + k + 1], seen.size() == cells, "(%d of %d)" % [seen.size(), cells])
			var last: Array = ring.rows.back()
			var outs := true
			for g: float in ring.gates_out:
				outs = outs and seen.has(Vector2i(ring.rows.size() - 1, RoundMaze.cell_at(g, last[2])))
			check("seed %d: section %d ways out reached" % [seed_value, maze.rings + k + 1], outs)
		# The desert ring: four quarters walled apart, each with its own way in from
		# the square maze and its own gate on through the first circle.
		var quarters_in := {}
		for door: Vector2 in plan.doors:
			quarters_in[DesertStyle.quarter_at(door.x, door.y)] = true
		check("seed %d: a way in from the square maze to each quarter" % seed_value, plan.doors.size() == 4 and quarters_in.size() == 4, "(%d doors, %d quarters)" % [plan.doors.size(), quarters_in.size()])
		var quarters_out := {}
		for g: float in plan.desert_gates:
			var at := Vector2.from_angle(g) * plan.inner_radius
			quarters_out[DesertStyle.quarter_at(at.x, at.y)] = true
			# (well clear of the diagonal walls)
			var off_diagonal := INF
			for a: float in RoundMaze.DIAGONALS:
				off_diagonal = minf(off_diagonal, absf(angle_difference(g, a)))
			check("seed %d: the gate at %.2f clear of the walls between quarters" % [seed_value, g], off_diagonal > 0.3)
		check("seed %d: a gate out of each quarter" % seed_value, plan.desert_gates.size() == 4 and quarters_out.size() == 4)
		# (no way round the diagonal walls: they run from the square's corners right to the circle)
		var built := RoundBuilder.new()
		built.plan = plan
		root.add_child(built)
		for i in 3:
			await physics_frame
		var space := built.get_world_3d().direct_space_state
		var walled := true
		for a: float in RoundMaze.DIAGONALS:
			for r in range(int(plan.square_half * sqrt(2.0)) + 4, int(plan.inner_radius) - 4, 20):
				var across := Vector2.from_angle(a).orthogonal() * 8.0
				var at := Vector2.from_angle(a) * r
				var query := PhysicsRayQueryParameters3D.create(Vector3(at.x - across.x, 2.0, at.y - across.y), Vector3(at.x + across.x, 2.0, at.y + across.y))
				if space.intersect_ray(query).is_empty():
					walled = false
		check("seed %d: the quarters walled apart" % seed_value, walled)
		built.free()
		# (sand only where a quarter is desert)
		var look := DesertStyle.new()
		look.south_quarter = DesertStyle.Biome.DESERT
		plan.desert = look
		plan._level.clear()
		var sandy := []
		for side: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var mid := side * (plan.square_half + plan.inner_radius) * 0.5
			var most := 0.0
			for t in range(-8, 9):
				var p := mid + side.orthogonal() * t * 12.0
				most = maxf(most, plan.desert_height(p.x, p.y))
			sandy.append(most > 0.5)
		check("seed %d: dunes only in the desert quarters (north and south here)" % seed_value, sandy == [true, false, true, false], str(sandy))
		_wilds(seed_value)
		await _wilds_built(seed_value)
	print("ROUND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
