@tool
extends Node
## In tests/zone_preview_check.tscn, opened in the editor: once the live preview is
## up, changes one rule after another of the maze's sections, a few seconds apart,
## so that the editor's output shows what each builds again and how long it takes
## (MazeLayout prints "Maze preview: ... built in"), then quits.
##
##     "$G" --headless --path . --editor tests/zone_preview_check.tscn

const POKES := [
	[1, "random_crossing_density", 0.4],
	[2, "clutter_share", 0.2],
	[1, "maze_wall_height", 90.0],
	[0, "straight_on_chance", 0.3],
]

var _clock := 0.0
var _done := 0


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_clock += delta
	if _clock < 8.0 * (_done + 1):
		return
	var layout := get_parent() as MazeLayout
	if _done >= POKES.size():
		get_tree().quit()
		return
	var poke: Array = POKES[_done]
	print("-- section %d: %s = %s" % [poke[0] + 1, poke[1], poke[2]])
	layout.square_sections[poke[0]].set(poke[1], poke[2])
	_done += 1
