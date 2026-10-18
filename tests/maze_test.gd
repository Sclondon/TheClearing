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
	check("first ring only, for now", a.rings == 1 and a.size == Maze.RINGS[1])

	for built in [1, 3]:
		for seed_value in [1, 2, 3, 99, 12345]:
			var maze := Maze.generate(seed_value, built)
			var name := "%d ring(s), seed %d" % [built, seed_value]
			var unreached := 0
			for i in maze.size * maze.size:
				var cell := Vector2i(i % maze.size, i / maze.size)
				if not maze.in_clearing(cell) and maze.distance[i] < 0:
					unreached += 1
			check("%s: every cell reachable" % name, unreached == 0, "(%d not)" % unreached)
			var path := maze.path_out(maze.cell_at(Vector3.ZERO))
			check("%s: a way out from the middle" % name, path.size() > maze.clearing / 2 + 4 * built, "(%d cells)" % path.size())
			# Every ring wall is shut but for the gates: 4 out of the clearing, 1 out of each ring after.
			var openings := 0
			var open := 0
			for i in maze.size * maze.size:
				var cell := Vector2i(i % maze.size, i / maze.size)
				for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					if not maze.inside(cell + step):
						continue
					if maze.ring_wall(cell, step) and not maze.blocked(cell, step):
						openings += 1
					if not maze.in_clearing(cell) and not maze.blocked(cell, step):
						open += 1
			check("%s: rings shut but for their gates" % name, openings == 4 + built - 1, "(%d)" % openings)
			var ring_cells := maze.size * maze.size - maze.clearing * maze.clearing
			check("%s: still a maze" % name, open < ring_cells * 1.2, "(%d open of %d cells)" % [open, ring_cells])
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
