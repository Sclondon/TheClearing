extends SceneTree
## A generated round is made by the rules set in the maze editor (Mazes.rules):
## each section's style and the clearing's look as its MazeLayout has them.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/rules_test.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var editor := (load(Mazes.RULES) as PackedScene).instantiate() as MazeLayout
	var main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 10:
		await process_frame
	var maze: Maze = main.world.maze
	_check(maze.styles.size() >= editor.styles.size(), "a style for every section the editor sets (%d, editor %d)" % [maze.styles.size(), editor.styles.size()])
	var same := true
	for k in editor.styles.size():
		for property in ["section_depth_cells", "hallway_diameter_cells", "maze_wall_diameter", "maze_wall_height", "section_border_wall_height", "border_wall_thickness_cells", "straight_on_chance", "loop_share", "round_section"]:
			if maze.styles[k].get(property) != editor.styles[k].get(property):
				print("  section %d %s: game %s, editor %s" % [k + 1, property, maze.styles[k].get(property), editor.styles[k].get(property)])
				same = false
	_check(same, "each section as the editor has it (section 1 walls %.0f m, the editor %.0f m)" % [maze.styles[0].maze_wall_height, editor.styles[0].maze_wall_height])
	if editor.clearing_style:
		_check(maze.clearing_style.get_property_list().all(func(p: Dictionary) -> bool: return p.usage & PROPERTY_USAGE_STORAGE == 0 or p.name == "entrance_spots" or maze.clearing_style.get(p.name) == editor.clearing_style.get(p.name)), "the clearing as the editor has it")
	# The clearing's wall is its own; each section's border wall is its outer one.
	_check(maze.inner_height(1) == maze.clearing_style.clearing_wall_height and maze.rampart(1) == maze.clearing_style.clearing_wall_thickness_cells, "the clearing's wall by its own controls (%.0f m, %d cells)" % [maze.inner_height(1), maze.rampart(1)])
	_check(maze.ring_sizes[1] == Maze.CLEARING + (maze.styles[0].section_depth_cells + maze.clearing_style.clearing_wall_thickness_cells) * 2, "the first section starts past the clearing's wall")
	var outer_ok := true
	for ring in range(2, maze.rings + 1):
		if maze.inner_height(ring) != maze.styles[ring - 2].section_border_wall_height or maze.rampart(ring) != maze.styles[ring - 2].border_wall_thickness_cells:
			outer_ok = false
	_check(outer_ok, "each section's border wall is the one round its outside (1 to 2: %.0f m)" % maze.inner_height(2))
	print("  (made from the round's own seed, %d; the editor's is %d)" % [maze.maze_seed, editor.maze_seed])
	editor.free()
	print("RULES TEST PASSED" if failures == 0 else "RULES TEST FAILED (%d)" % failures)
	quit(failures)
