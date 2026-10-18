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
		for property in ["section_width_cells", "hallway_diameter_cells", "maze_wall_diameter", "maze_wall_height", "section_border_wall_height", "border_wall_thickness_cells", "straight_on_chance", "loop_share", "round_section"]:
			if maze.styles[k].get(property) != editor.styles[k].get(property):
				print("  section %d %s: game %s, editor %s" % [k + 1, property, maze.styles[k].get(property), editor.styles[k].get(property)])
				same = false
	_check(same, "each section as the editor has it (section 1 walls %.0f m, the editor %.0f m)" % [maze.styles[0].maze_wall_height, editor.styles[0].maze_wall_height])
	if editor.clearing_style:
		_check(maze.clearing_style.get_property_list().all(func(p: Dictionary) -> bool: return p.usage & PROPERTY_USAGE_STORAGE == 0 or p.name == "entrance_spots" or maze.clearing_style.get(p.name) == editor.clearing_style.get(p.name)), "the clearing as the editor has it")
	# Square and round sections, and the desert, each by their own rules.
	_check(editor.square_sections.all(func(s: MazeStyle) -> bool: return not s.round_section) and editor.round_sections.all(func(s: MazeStyle) -> bool: return s is RoundStyle), "the editor's square sections are square and its round ones RoundStyles (%d and %d)" % [editor.square_sections.size(), editor.round_sections.size()])
	_check(maze.styles.slice(editor.square_sections.size()).all(func(s: MazeStyle) -> bool: return s.round_section), "the round ones are round in the game")
	_check(maze.desert_style != null and (editor.desert == null or maze.desert_style.desert_width == editor.desert.desert_width), "the desert as the editor has it (%.0f m)" % maze.desert_style.desert_width)
	var shown := func(thing: Object) -> Array:
		return thing.get_property_list().filter(func(p: Dictionary) -> bool: return p.usage & PROPERTY_USAGE_EDITOR and p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE).map(func(p: Dictionary) -> String: return p.name)
	var round_shown: Array = shown.call(RoundStyle.new())
	_check(round_shown.size() == RoundStyle.SHOWN.size(), "a round section shows only what it goes by: %s" % ", ".join(round_shown))
	var square_shown: Array = shown.call(MazeStyle.new())
	_check(not square_shown.has("round_section") and not square_shown.has("desert_width"), "a square section shows no round switch and no desert (%d settings)" % square_shown.size())
	var layout_shown: Array = shown.call(editor)
	_check(layout_shown.has("square_sections") and layout_shown.has("round_sections") and layout_shown.has("desert") and not layout_shown.has("styles"), "the layout shows square sections, the desert and round sections apart: %s" % ", ".join(layout_shown))
	var old := MazeLayout.new()
	var mixed: Array[MazeStyle] = MazeStyle.square_defaults()
	var legacy := MazeStyle.made(5, 1, 0.3, 0.3, 0.06)
	legacy.round_section = true
	mixed.append(legacy)
	old.styles = mixed
	_check(old.square_sections.size() == 4 and old.round_sections.size() == 1 and old.round_sections[0].section_width_cells == 5, "a layout saved with one list is shared out")
	old.free()
	# The clearing's wall is its own; each section's border wall is its outer one.
	_check(maze.inner_height(1) == maze.clearing_style.clearing_wall_height and maze.rampart(1) == maze.clearing_style.clearing_wall_thickness_cells, "the clearing's wall by its own controls (%.0f m, %d cells)" % [maze.inner_height(1), maze.rampart(1)])
	_check(maze.ring_sizes[1] == Maze.CLEARING + (maze.styles[0].section_width_cells + maze.clearing_style.clearing_wall_thickness_cells) * 2, "the first section starts past the clearing's wall")
	var outer_ok := true
	for ring in range(2, maze.rings + 1):
		if maze.inner_height(ring) != maze.styles[ring - 2].section_border_wall_height or maze.rampart(ring) != maze.styles[ring - 2].border_wall_thickness_cells:
			outer_ok = false
	_check(outer_ok, "each section's border wall is the one round its outside (1 to 2: %.0f m)" % maze.inner_height(2))
	print("  (made from the round's own seed, %d; the editor's is %d)" % [maze.maze_seed, editor.maze_seed])
	editor.free()
	print("RULES TEST PASSED" if failures == 0 else "RULES TEST FAILED (%d)" % failures)
	quit(failures)
