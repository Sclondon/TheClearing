@tool
extends EditorPlugin
## Drops the 3D view's camera into a hall of the maze being edited, at a boy's
## height, so that it can be looked round and flown along from there (hold the
## right mouse button: WASD, Q and E, the mouse to look; the wheel while held for
## speed). The user, 2026-10-18: "I wanted a way to move the camera into the
## hallways easily".
##
## G with the mouse over a hall, while the maze (a MazeLayout) or a piece of it is
## selected; or the Into the Hall button on the 3D view's bar, for the hall in the
## middle of the view (with anything selected or nothing).
##
## The editor lets no plugin set its camera, so this does it by its own Focus
## Selection: it selects a mark put in the hall, has the view focus on it (which
## brings the camera to a few metres from it), and gives the selection back.

## How high over the ground the mark is, metres: a boy's eyes.
const EYES := 1.7
## How far it keeps off the walls (and the ledges along them), metres.
const OFF_WALLS := 1.0

var _button: Button
var _mouse := Vector2.ZERO


func _enter_tree() -> void:
	_button = Button.new()
	_button.text = "Into the Hall"
	_button.tooltip_text = "Drops the camera into the hall in the middle of the view (or press G over a hall, with the maze selected). Then hold the right mouse button to fly: WASD, Q and E."
	_button.flat = true
	_button.pressed.connect(func() -> void:
		var viewport := EditorInterface.get_editor_viewport_3d(0)
		_into_hall(viewport.get_camera_3d(), viewport.get_visible_rect().size * 0.5))
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)
	_button.queue_free()


func _handles(object: Object) -> bool:
	return _layout_of(object) != null


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouse:
		_mouse = (event as InputEventMouse).position
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_G and not (key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed):
		if _into_hall(camera, _mouse):
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


## The MazeLayout `object` is or is in, or null.
func _layout_of(object: Object) -> MazeLayout:
	var node := object as Node
	while node:
		if node is MazeLayout:
			return node
		node = node.get_parent()
	return null


## The MazeLayout to go into: the selected one (or the one a selected piece is
## in), or the first in the open scene.
func _layout() -> MazeLayout:
	for node in EditorInterface.get_selection().get_selected_nodes():
		var layout := _layout_of(node)
		if layout:
			return layout
	var root := EditorInterface.get_edited_scene_root()
	if root is MazeLayout:
		return root
	if root:
		for found in root.find_children("*", "MazeLayout", true, false):
			return found
	return null


## Puts the camera in the hall under `at` (a point in the view `camera` draws).
## False if there is no maze, or the point is not on the ground.
func _into_hall(camera: Camera3D, at: Vector2) -> bool:
	var layout := _layout()
	if layout == null or camera == null:
		return false
	var from := camera.project_ray_origin(at)
	var way := camera.project_ray_normal(at)
	if way.y > -0.01:
		return false
	var spot := layout.to_local(from + way * (layout.global_position.y - from.y) / way.y)
	var maze := Maze.generate(layout.maze_seed, layout.rings, layout.styles, layout.clearing_style, layout.desert)
	var cell := maze.cell_at(spot)
	if not maze.inside(cell) or maze.solid.has(cell):
		return false
	# (off the walls round the cell, and the ledges along them)
	var middle := maze.world(cell)
	var off := Vector2(spot.x - middle.x, spot.z - middle.z)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			continue
		var room := Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5 - OFF_WALLS
		if maze.has_ledge(cell, step):
			room -= maze.ledge_style(cell).mezzanine_depth
		room = maxf(room, 0.0)
		if step.x != 0:
			off.x = minf(off.x, room) if step.x > 0 else maxf(off.x, -room)
		else:
			off.y = minf(off.y, room) if step.y > 0 else maxf(off.y, -room)
	var mark := Node3D.new()
	mark.name = "HallCameraMark"
	layout.add_child(mark, false, Node.INTERNAL_MODE_BACK)
	mark.position = Vector3(middle.x + off.x, maze.ground_height(Vector3(middle.x + off.x, 0.0, middle.z + off.y)) + EYES, middle.z + off.y)
	var selection := EditorInterface.get_selection()
	var was := selection.get_selected_nodes()
	selection.clear()
	selection.add_node(mark)
	# (the Focus Selection of the view the camera is of)
	var view := camera.get_viewport().get_parent().get_parent()
	for menu: MenuButton in view.find_children("*", "MenuButton", true, false):
		var popup := menu.get_popup()
		for i in popup.item_count:
			if popup.get_item_text(i) == "Focus Selection":
				popup.id_pressed.emit(popup.get_item_id(i))
				break
	_give_back(was, mark)
	return true


## Selects again what was selected, once the view has focused on the mark, and takes the mark away.
func _give_back(was: Array[Node], mark: Node) -> void:
	await get_tree().process_frame
	var selection := EditorInterface.get_selection()
	selection.clear()
	for node in was:
		if is_instance_valid(node):
			selection.add_node(node)
	mark.queue_free()
