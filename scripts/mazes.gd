class_name Mazes
## Mazes laid out (and perhaps changed by hand) in the editor and saved in
## res://mazes/: each a scene whose root is a MazeLayout. Rounds play them in the
## order of their file names, round 1 the first, and round round again when they
## run out; with none there (or none `playable`), every round's maze is
## generated from the room's code and the round, as before.
##
## To make one: open res://maze_editor.tscn, set the MazeLayout's seed and rings,
## press Generate, change what you like, and save it as res://mazes/<name>.tscn.

const FOLDER := "res://mazes"
## Where the rules for generated mazes are set: the maze editor's MazeLayout, its
## `styles` (one MazeStyle a section) and `clearing_style`. A generated maze is
## made by them from the room's own seed.
const RULES := "res://maze_editor.tscn"


## The section styles, clearing look and desert set in the maze editor ([styles,
## clearing style, desert style]), each a copy (generating changes the
## clearing's): its square sections then its round ones, the game's own where it
## sets none; [[], null, null] with no editor.
static func rules() -> Array:
	# (a test's own choice comes first: MazeStyle.chosen)
	var scene := load(RULES) as PackedScene if ResourceLoader.exists(RULES) and MazeStyle.chosen.is_empty() else null
	if scene == null:
		return [[] as Array[MazeStyle], null, null]
	var state := scene.get_state()
	# (read off the saved scene, not made: it holds the whole laid-out maze too)
	var layout := MazeLayout.new()
	for i in state.get_node_property_count(0):
		var property := state.get_node_property_name(0, i)
		if property in [&"styles", &"square_sections", &"round_sections", &"clearing_style", &"desert"]:
			layout.set(property, state.get_node_property_value(0, i))
	var square: Array[MazeStyle] = []
	for style in (layout.square_sections if not layout.square_sections.is_empty() else MazeStyle.square_defaults()):
		square.append(style.duplicate(true))
	var round: Array[MazeStyle] = []
	for style in (layout.round_sections if not layout.round_sections.is_empty() else MazeStyle.round_defaults()):
		round.append(style.duplicate(true))
	var clearing: ClearingStyle = layout.clearing_style.duplicate(true) if layout.clearing_style else null
	var desert: DesertStyle = layout.desert.duplicate(true) if layout.desert else null
	layout.free()
	return [square + round, clearing, desert]


## The playable layouts, in order.
static func designed() -> PackedStringArray:
	var found := PackedStringArray()
	if not DirAccess.dir_exists_absolute(FOLDER):
		return found
	var names := Array(DirAccess.get_files_at(FOLDER))
	names.sort()
	for file: String in names:
		# (in an exported game the scenes are listed as .remap)
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tscn") or file.ends_with(".scn")) or found.has(FOLDER.path_join(file)):
			continue
		var path := FOLDER.path_join(file)
		var scene := load(path) as PackedScene
		if scene and scene.get_state().get_node_count() > 0 and _playable(scene):
			found.append(path)
	return found


## The layout to play on `round_number` (counting from 1), or "" for a generated maze.
static func for_round(round_number: int) -> String:
	var all := designed()
	if all.is_empty():
		return ""
	return all[(maxi(round_number, 1) - 1) % all.size()]


static func _playable(scene: PackedScene) -> bool:
	var state := scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"playable":
			return state.get_node_property_value(0, i)
	return true
