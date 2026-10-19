extends SceneTree
## Where the ledges are laid (MazeStyle.mezzanine_height): how many of the first
## level look into the clearing, into each ring, and stand along its great walls
## and ramparts; and the clearing's walls as laid. The first ring set to have a
## ledge 10 m up (or as the second argument says).
##
##     godot --headless --path . --audio-driver Dummy -s res://tools/ledge_probe.gd -- [seed] [ledge m]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var styles := MazeStyle.square_defaults()
	styles[0].mezzanine_height = float(args[1]) if args.size() > 1 else 10.0
	styles[0].mezzanine_depth = 1.0
	var maze := Maze.generate(int(args[0]) if args.size() > 0 else 1, styles.size(), styles)
	var layout := MazeLayout.new()
	root.add_child(layout)
	layout.lay_out(maze)
	var by_ring := {}
	for piece in layout.pieces(MazePiece.Kind.PIER):
		if piece.ledge and piece.position.y < 0.1:
			var ring := maze.ring_of(maze.cell_at(piece.position))
			by_ring[ring] = by_ring.get(ring, 0) + 1
	print("ledges on the ground by the ring they stand in: ", by_ring)
	print("rampart cells round ring 1: ", maze.rampart(1), ", solid cells: ", maze.solid.size())
	var edge := maze.ring_sizes[0] * Maze.CELL * 0.5
	print("clearing edge at %.1f m; great walls within 20 m of it:" % edge)
	for piece in layout.pieces(MazePiece.Kind.WALL):
		var size := piece.box_size()
		var far := maxf(absf(piece.position.x), absf(piece.position.z))
		if absf(far - edge) < 20.0 + maxf(size.x, size.z) * 0.0 and minf(size.x, size.z) > 0.0 and maxf(size.x, size.z) > 30.0:
			print("  wall at %s size %s great %s" % [piece.position.snappedf(0.1), size.snappedf(0.1), piece.great])
	quit()
