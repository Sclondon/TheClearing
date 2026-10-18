extends SceneTree
## Mazes laid out as pieces and changed by hand: a generated layout gives the same
## plan as the maze it came from; saved and loaded, it builds the same things; and
## a wall taken away, a terrace moved and a vine added by hand are what the game
## then has (the plan opens where the wall was). It also leaves a layout at
## res://tests/layout_check.tscn to open in the editor.
##
##     godot --headless --path . -s res://tests/layout_test.gd

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


## Makes every node under `node` part of the scene rooted at `root`, as the editor does.
func own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		own(child, root)


func _run() -> void:
	await process_frame
	# (a ring with terraces to move: the game's first ring has only vines)
	MazeStyle.chosen = [MazeStyle.warren()]
	var seed_value := Maze.seed_for("LAYOUT", 1)
	var maze := Maze.generate(seed_value)
	var layout := MazeLayout.new()
	root.add_child(layout)
	layout.lay_out(maze)
	var walls: Array = layout.pieces(MazePiece.Kind.WALL)
	check("laid out as pieces", walls.size() > 20 and layout.pieces(MazePiece.Kind.VINE).size() > 5, "(%d walls, %d vines)" % [walls.size(), layout.pieces(MazePiece.Kind.VINE).size()])
	var read := layout.plan()
	check("its plan is the maze's", read.east == maze.east and read.south == maze.south and read.exit == maze.exit)

	# By hand: take away an inner wall, move a terrace, add a vine.
	var taken: MazePiece = null
	for piece: MazePiece in walls:
		if not piece.great and piece.box_size().x > Maze.CELL * 1.5:
			taken = piece
			break
	var opened := maze.cell_at(taken.position + Vector3(0, 0, Maze.CELL * 0.5))
	var line := Vector2i(0, -1)
	check("that wall was a wall", maze.blocked(opened, line), str(opened))
	var taken_at := taken.position
	var taken_long := taken.box_size().x
	taken.get_parent().remove_child(taken)
	taken.free()
	var terrace: MazePiece = layout.pieces(MazePiece.Kind.TERRACE)[0]
	terrace.position += Vector3(1.5, 0.0, 0.0)
	var moved_to := terrace.position
	var vine := layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, Vector3(3, 9, 3)), {"length": 5.0})
	var vines_now := layout.pieces(MazePiece.Kind.VINE).size()

	# Saved as a scene, as the editor would.
	own(layout, layout)
	var scene := PackedScene.new()
	check("packs", scene.pack(layout) == OK)
	var path := "res://tests/layout_check.tscn"
	check("saves", ResourceSaver.save(scene, path) == OK)
	var loaded := (load(path) as PackedScene).instantiate() as MazeLayout
	check("loads", loaded != null and loaded.maze_seed == seed_value)
	var builder := MazeBuilder.new()
	root.add_child(builder)
	builder.add_child(loaded)
	builder.realize(loaded)
	check("the wall taken away is open", not builder.maze.blocked(opened, line), str(opened))
	var others_kept := true
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if maze.inside(cell + step) and maze.blocked(cell, step) != builder.maze.blocked(cell, step):
				# (only the line under the wall taken away may differ)
				var middle := maze.world(cell) + Vector3(step.x, 0, step.y) * Maze.CELL * 0.5
				if absf(middle.z - taken_at.z) > 0.5 or absf(middle.x - taken_at.x) > taken_long * 0.5:
					others_kept = false
	check("and every other wall is as it was", others_kept)
	check("the terrace stands where it was moved to", builder.features.terraces.has(moved_to), str(moved_to))
	check("the vine added is there", builder.features.vines.size() == vines_now, "(%d)" % builder.features.vines.size())
	check("a beacon", builder.beacon != null)
	check("a way out still", builder.maze.path_out(builder.maze.cell_at(Vector3.ZERO)).size() > 3)

	print("LAYOUT TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
