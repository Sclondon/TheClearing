extends SceneTree
## What the maze editor's Generate costs, step by step, with the editor's own
## rules (maze_editor.tscn): making the plan, laying out the pieces, the pieces
## going into the tree (each drawing itself), and the round sections and ground
## shown with it. A layout outside the editor does the same work but for saving.
##
##     godot --headless --path . -s res://tools/generate_times.gd


func _initialize() -> void:
	var editor := (load(Mazes.RULES) as PackedScene).instantiate() as MazeLayout
	var layout := MazeLayout.new()
	layout.maze_seed = editor.maze_seed
	layout.rings = editor.rings
	layout.square_sections = editor.square_sections
	layout.round_sections = editor.round_sections
	layout.clearing_style = editor.clearing_style
	layout.desert = editor.desert
	editor.free()
	var t := Time.get_ticks_usec()
	var plan := Maze.generate(layout.maze_seed, layout.rings, layout.styles, layout.clearing_style, layout.desert)
	print("plan (Maze.generate)        %7.0f ms  (%d x %d cells)" % [(Time.get_ticks_usec() - t) / 1000.0, plan.size, plan.size])
	t = Time.get_ticks_usec()
	layout.lay_out(plan)
	print("lay out the pieces          %7.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var counts := {}
	for kind in MazePiece.Kind.values():
		counts[MazePiece.Kind.keys()[kind]] = layout.pieces(kind).size()
	print("pieces: %s" % str(counts))
	t = Time.get_ticks_usec()
	root.add_child(layout)
	print("into the tree (each drawn)  %7.0f ms  (%d nodes)" % [(Time.get_ticks_usec() - t) / 1000.0, layout.find_children("*", "", true, false).size()])
	t = Time.get_ticks_usec()
	if plan.round_rings:
		var sections := RoundBuilder.new()
		sections.plan = plan.round_rings
		root.add_child(sections)
	print("round sections shown        %7.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	if layout.clearing_style and layout.clearing_style.shaped():
		root.add_child(MazeBuilder.hills(layout.clearing_style, layout.maze_seed, StandardMaterial3D.new()))
	print("clearing hills shown        %7.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	# The live preview (MazeLayout.live_preview): the same rules built as the game
	# builds them, from pieces never put in the scene.
	t = Time.get_ticks_usec()
	var plan2 := Maze.generate(layout.maze_seed, layout.rings, layout.styles, layout.clearing_style, layout.desert)
	var pieces := MazeLayout.new()
	pieces.lay_out(plan2)
	var built := MazeBuilder.new()
	built.preview = true
	root.add_child(built)
	built.realize(pieces, plan2)
	print("live preview built          %7.0f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	# (in the editor every ivy patch is drawn at once: as the preview draws them, and as Generate's do)
	var ivies := built.find_children("*", "IvyClimb", true, false)
	t = Time.get_ticks_usec()
	for ivy: IvyClimb in ivies:
		ivy._grow_plain()
	print("  + its %d ivy, flat        %7.0f ms" % [ivies.size(), (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	for ivy: IvyClimb in ivies.slice(0, 200):
		ivy._grow()
	print("  (grown leaf by leaf, all  %7.0f ms)" % ((Time.get_ticks_usec() - t) / 1000.0 * ivies.size() / 200.0))
	pieces.free()
	quit()
