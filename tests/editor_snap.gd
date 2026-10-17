@tool
extends Node
## For checking what the editor shows: opened in the editor (tests/editor_check.tscn),
## it waits for the scene to come up, points the editor's 3D camera at the maze,
## saves what the 3D view draws to `out`, and closes the editor. Does nothing in the game.
##
##     godot --editor --path . res://tests/editor_check.tscn

@export var out := "user://editor_view.png"
@export var eye := Vector3(30, 26, 70)
@export var look_at_point := Vector3(0, 0, 10)

var _time := 0.0
var _done := false


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or _done:
		return
	_time += delta
	var view := EditorInterface.get_editor_viewport_3d(0)
	if view == null:
		return
	var camera := view.get_camera_3d()
	if camera and _time > 8.0:
		camera.global_transform = Transform3D(Basis.looking_at(look_at_point - eye), eye)
	if _time > 12.0:
		_done = true
		view.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
		print("EDITOR VIEW SAVED ", ProjectSettings.globalize_path(out))
		get_tree().quit()
