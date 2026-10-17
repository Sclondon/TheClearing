extends SceneTree
## The maze plan on its own: the same seed gives the same maze, every cell can be
## reached, the clearing is open, there is a way out, and the walls are mostly kept.
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

	for seed_value in [1, 2, 3, 99, 12345]:
		var maze := Maze.generate(seed_value)
		var unreached := 0
		for i in maze.size * maze.size:
			var cell := Vector2i(i % maze.size, i / maze.size)
			if not maze.in_clearing(cell) and maze.distance[i] < 0:
				unreached += 1
		check("seed %d: every cell reachable" % seed_value, unreached == 0, "(%d not)" % unreached)
		var path := maze.path_out(maze.cell_at(Vector3.ZERO))
		check("seed %d: a way out from the middle" % seed_value, path.size() > maze.size, "(%d cells)" % path.size())
		var open := 0
		for x in range(maze.size - 1):
			for y in range(maze.size - 1):
				open += 1 - maze.east[maze.index(Vector2i(x, y))]
		check("seed %d: still a maze" % seed_value, open < maze.size * maze.size * 0.75, "(%d open east walls)" % open)
		check("seed %d: clearing open" % seed_value, not maze.blocked(Vector2i(12, 12), Vector2i(1, 0)) and not maze.blocked(Vector2i(10, 10), Vector2i(0, 1)))
		var edge := maze.exit + maze.exit_side
		check("seed %d: exit on the edge" % seed_value, not maze.inside(edge) and not maze.blocked(maze.exit, maze.exit_side))
		check("seed %d: escaped past the exit" % seed_value, maze.escaped(maze.world(edge)) and not maze.escaped(maze.world(maze.exit)))

	print("MAZE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
