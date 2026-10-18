extends SceneTree
## How long each step of building a maze takes, for `rings` rings (and how many
## pieces there are), to see what makes a round slow to start.
##
##     godot --headless --path . -s res://tools/build_times.gd -- [rings]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rings: int = int(args[0]) if args.size() > 0 else 2
	var t := [Time.get_ticks_usec()]
	var lap := func(what: String) -> void:
		print("%-22s %7.0f ms" % [what, (Time.get_ticks_usec() - t[0]) / 1000.0])
		t[0] = Time.get_ticks_usec()
	var maze := Maze.generate(1234, rings)
	lap.call("generate (%d cells)" % (maze.size * maze.size))
	var builder := MazeBuilder.new()
	root.add_child(builder)
	var layout := MazeLayout.new()
	builder.add_child(layout)
	builder.layout = layout
	layout.lay_out(maze)
	lap.call("lay out (%d pieces)" % layout.find_children("*", "MazePiece", true, false).size())
	builder.maze = maze
	var body := StaticBody3D.new()
	builder.add_child(body)
	builder._walls(body, layout)
	lap.call("walls (%d shapes)" % body.get_child_count())
	builder.features = MazeFeatures.new()
	builder.add_child(builder.features)
	builder.features.realize(layout)
	lap.call("features")
	builder._grass()
	lap.call("grass")
	builder._ground()
	lap.call("ground")
	builder._trees(layout)
	lap.call("trees")
	builder._undergrowth(layout)
	lap.call("undergrowth")
	if maze.round_rings:
		var sections := RoundBuilder.new()
		sections.plan = maze.round_rings
		builder.add_child(sections)
		lap.call("round sections")
	var enemies := MazeEnemies.new()
	builder.add_child(enemies)
	enemies.populate(maze, 1234)
	lap.call("enemies (%d)" % enemies.get_child_count())
	quit()
