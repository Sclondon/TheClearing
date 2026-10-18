extends SceneTree
## The maze plan on its own: the same seed gives the same maze, every cell can be
## reached, the clearing is open, each ring is walled off from the next but for
## its gates, there is a way out, and the walls are mostly kept.
##
##     godot --headless --path . -s res://tests/maze_test.gd

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	var a := Maze.generate(Maze.seed_for("ABCD", 1))
	var b := Maze.generate(Maze.seed_for("ABCD", 1))
	var c := Maze.generate(Maze.seed_for("ABCD", 2))
	check("same seed, same maze", a.east == b.east and a.south == b.south and a.exit == b.exit)
	check("next round, new maze", a.east != c.east or a.south != c.south)
	check("first ring only, for now", a.rings == 1 and a.size == Maze.CLEARING + (a.styles[0].width + a.styles[0].rampart) * 2)

	for built in [1, 3]:
		for seed_value in [1, 2, 3, 99, 12345]:
			var maze := Maze.generate(seed_value, built)
			var name := "%d ring(s), seed %d" % [built, seed_value]
			var unreached := 0
			for i in maze.size * maze.size:
				var cell := Vector2i(i % maze.size, i / maze.size)
				if not maze.in_clearing(cell) and not maze.solid.has(cell) and maze.distance[i] < 0:
					unreached += 1
			check("%s: every cell reachable" % name, unreached == 0, "(%d not)" % unreached)
			var path := maze.path_out(maze.cell_at(Vector3.ZERO))
			check("%s: a way out from the middle" % name, path.size() > maze.clearing / 2 + 4 * built, "(%d cells)" % path.size())
			# Every ring wall is shut but for the gates, each a cell long: 4 out of the
			# clearing, 1 out of each ring after.
			var span := 1
			var from_clearing := 0
			var openings := 0
			var open := 0
			for i in maze.size * maze.size:
				var cell := Vector2i(i % maze.size, i / maze.size)
				for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					if not maze.inside(cell + step):
						continue
					if maze.ring_wall(cell, step) and not maze.blocked(cell, step):
						if maze.in_clearing(cell) or maze.in_clearing(cell + step):
							from_clearing += 1
						else:
							openings += 1
					if not maze.in_clearing(cell) and not maze.blocked(cell, step):
						open += 1
			check("%s: rings shut but for their gates" % name, from_clearing >= 4 * span and from_clearing <= 4 * (span + 1) and openings == built - 1, "(%d from the clearing, %d after)" % [from_clearing, openings])
			var ring_cells := maze.size * maze.size - maze.clearing * maze.clearing
			check("%s: still a maze" % name, open < ring_cells * 1.7, "(%d open of %d cells)" % [open, ring_cells])
			# Each way in from the clearing is a narrow entrance as long as the style says:
			# walled both sides all along, but for where it opens up at its far end.
			var entrance := maze.styles[0].entrance
			var open_sided := 0
			if entrance >= 2:
				for way: Array in maze.gates[0]:
					var step: Vector2i = way[1]
					var side := Vector2i(-step.y, step.x)
					for k in range(1, entrance):
						var cell: Vector2i = way[0] + step * k
						if not maze.blocked(cell, side) or not maze.blocked(cell, -side):
							open_sided += 1
			check("%s: long narrow entrances" % name, open_sided == 0, "(%d cells open at the side)" % open_sided)
			# The gates from the clearing are slots through its wall: wide enough for him
			# (about three of him), and no wider than a cell.
			var slots: Array[float] = []
			for way: Array in maze.gates[0]:
				slots.append(Maze.CELL - maze.wall_thick(way[0], way[1]))
			check("%s: gates a slot he can get through" % name, slots.min() >= 1.5 and slots.max() <= Maze.CELL, str(slots))
			# The first ring's halls are as wide as its style says: every cell in it opens
			# on a neighbour both across and along (but the entrances, and what they cut
			# off beside them).
			var narrow := 0
			for i in maze.size * maze.size:
				var cell := Vector2i(i % maze.size, i / maze.size)
				if maze.ring_of(cell) != 1 or maze.solid.has(cell) or maze.entrances.has(cell):
					continue
				var across := not maze.blocked(cell, Vector2i(1, 0)) or not maze.blocked(cell, Vector2i(-1, 0))
				var along := not maze.blocked(cell, Vector2i(0, 1)) or not maze.blocked(cell, Vector2i(0, -1))
				if not (across and along):
					narrow += 1
			# Every gate from the clearing leads on into the ring: from just inside each,
			# the way out can be reached without going back through the clearing.
			var shut_in := 0
			for way: Array in maze.gates[0]:
				if not _reaches_exit(maze, way[0] + way[1]):
					shut_in += 1
			check("%s: no gate a dead end" % name, shut_in == 0, "(%d of %d)" % [shut_in, maze.gates[0].size()])
			var first_ring := 0
			for i in maze.size * maze.size:
				var counted := Vector2i(i % maze.size, i / maze.size)
				if maze.ring_of(counted) == 1 and not maze.solid.has(counted) and not maze.entrances.has(counted):
					first_ring += 1
			check("%s: wide halls in the first ring" % name, maze.styles[0].span < 2 or narrow < first_ring * 0.12, "(%d of %d cells in a narrow hall)" % [narrow, first_ring])
			var middle := maze.size / 2
			check("%s: clearing open" % name, not maze.blocked(Vector2i(middle, middle), Vector2i(1, 0)) and not maze.blocked(Vector2i(middle - 3, middle - 3), Vector2i(0, 1)))
			var edge := maze.exit + maze.exit_side
			check("%s: exit on the edge" % name, not maze.inside(edge) and not maze.blocked(maze.exit, maze.exit_side))
			check("%s: escaped past the exit" % name, maze.escaped(maze.world(edge)) and not maze.escaped(maze.world(maze.exit)))

	# The boxes the walls are built of face out on every side, the top too (wound as
	# Godot's front faces are: clockwise seen from outside), or they show hollow.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	MazeBuilder.box(tool, Vector3.ZERO, Vector3(4, 6, 2))
	var arrays := tool.commit().surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inside_out := 0
	for t in range(0, points.size(), 3):
		if (points[t + 1] - points[t]).cross(points[t + 2] - points[t]).dot(normals[t]) > 0.0:
			inside_out += 1
	check("wall boxes face out on every side", inside_out == 0, "(%d of %d triangles inside out)" % [inside_out, points.size() / 3])

	print("MAZE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)


## Whether the exit can be reached from `from` without going into the clearing.
func _reaches_exit(maze: Maze, from: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == maze.exit:
			return true
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if maze.inside(next) and not seen.has(next) and not maze.in_clearing(next) and not maze.blocked(cell, step):
				seen[next] = true
				queue.push_back(next)
	return false
