@tool
extends Node
## For checking the Wall in the editor (tests/look_check.tscn): once the scene is
## up, sets the wall's look to each in turn, as the Inspector would; then reloads
## its script, as the editor does when the file changes, and sets them again; and
## counts the meshes it has (there should be one). Then closes the editor. Errors
## come out in the editor's output.

var _time := 0.0
var _done := false


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or _done:
		return
	_time += delta
	if _time < 6.0:
		return
	_done = true
	var wall := get_parent().get_node(^"Wall")
	for round in 2:
		for look in [1, 2, 3, 4, 5, 0]:
			wall.set(&"look", look)
			print("LOOK set ", wall.get(&"look"), " tile ", wall.get(&"tile_size"), " texture ", wall.get(&"texture"))
		if round == 0:
			(wall.get_script() as Script).reload(true)
			print("LOOK script reloaded")
	var meshes := 0
	for child in wall.get_children(true):
		if child is MeshInstance3D:
			meshes += 1
	print("LOOK meshes ", meshes)
	print("LOOK CHECK DONE")
	get_tree().quit()
