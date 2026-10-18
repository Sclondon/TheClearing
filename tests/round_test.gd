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
	print("ROUND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
