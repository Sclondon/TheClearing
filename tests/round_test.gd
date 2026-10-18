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
	print("ROUND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
