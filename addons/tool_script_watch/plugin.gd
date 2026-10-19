@tool
extends EditorPlugin
## Watches the project's @tool scripts (MazeStyle, Maze...) for changes made
## outside the editor: a merge, a pull, another session. The editor hot-reloads
## such a script, but what open scenes already hold of it keeps the old layout of
## its variables, so every frame the inspector touches them it prints "Bad
## address index", and printing that many errors drags the editor to a few frames
## a second (2026-10-18). Only a restart clears it, so this offers one at once,
## before anything is saved over with the stale copies.
##
## Only a change to a script's own variables counts (one inside its functions
## hot-reloads safely), and saves made in the editor itself (resource_saved) never do.

## How often the scripts are looked at, seconds (a stat of each; there are a few dozen).
const POLL := 1.0
## How long it waits after the last change before asking, seconds (a merge writes many files).
const SETTLE := 1.5

var _times := {}  # path -> modified time, of each @tool script
var _layouts := {}  # path -> its variables, in order (see _layout)
var _changed: PackedStringArray = []
var _poll: Timer
var _settle: Timer
var _dialog: ConfirmationDialog


func _enter_tree() -> void:
	_scan(false)
	_poll = Timer.new()
	_poll.wait_time = POLL
	_poll.timeout.connect(_scan.bind(true))
	add_child(_poll)
	_poll.start()
	_settle = Timer.new()
	_settle.one_shot = true
	_settle.wait_time = SETTLE
	_settle.timeout.connect(_ask)
	add_child(_settle)
	resource_saved.connect(_on_saved)


func _exit_tree() -> void:
	if _dialog:
		_dialog.queue_free()


func _on_saved(resource: Resource) -> void:
	if _times.has(resource.resource_path):
		_times[resource.resource_path] = FileAccess.get_modified_time(resource.resource_path)


## Finds the @tool scripts and their times; with `report`, notes any whose time moved.
func _scan(report: bool) -> void:
	var paths: PackedStringArray = []
	_collect("res://", paths)
	for path in paths:
		var time := FileAccess.get_modified_time(path)
		if _times.has(path):
			if time != _times[path]:
				_times[path] = time
				# (only a change to its variables leaves the copies in open scenes
				# stale: one inside its functions hot-reloads as it should)
				var layout := _layout(path)
				if layout == _layouts[path]:
					continue
				_layouts[path] = layout
				if report and not _changed.has(path):
					_changed.append(path)
				_settle.start()
		elif _is_tool(path):
			_times[path] = time
			_layouts[path] = _layout(path)


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".gd"):
			into.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		# (not hidden folders: .godot, .claude's worktrees; not the addons, this among them)
		if not sub.begins_with(".") and sub != "addons":
			_collect(dir_path.path_join(sub), into)


## The script's own variables (not in its functions), in order: what each copy of
## it holds its values by. Comments and blank lines aside.
func _layout(path: String) -> String:
	var names: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var words := line.strip_edges().split(" ", false)
		var at := words.find("var")
		if at >= 0 and at + 1 < words.size():
			names.append(words[at + 1].trim_suffix(":"))
		elif line.begins_with("extends ") or line.begins_with("class_name "):
			names.append(line.strip_edges())
	return ",".join(names)


func _is_tool(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	for i in 12:
		if file.eof_reached():
			break
		if file.get_line().strip_edges().begins_with("@tool"):
			return true
	return false


func _ask() -> void:
	if _changed.is_empty():
		return
	if _dialog == null:
		_dialog = ConfirmationDialog.new()
		_dialog.title = "Tool scripts changed on disk"
		_dialog.ok_button_text = "Save and restart"
		_dialog.add_button("Restart without saving", true, "discard")
		_dialog.cancel_button_text = "Not now"
		_dialog.confirmed.connect(_restart.bind(true))
		_dialog.custom_action.connect(func(_action: StringName) -> void: _restart(false))
		_dialog.canceled.connect(_changed.clear)
		EditorInterface.get_base_control().add_child(_dialog)
	var names: PackedStringArray = []
	for path in _changed:
		names.append(path.get_file())
	_dialog.dialog_text = "Changed outside the editor:\n  %s\n\nScenes open now hold the old versions of these scripts, which spams \"Bad address index\" and slows the editor right down until it restarts." % "\n  ".join(names)
	_dialog.popup_centered()


func _restart(save: bool) -> void:
	_changed.clear()
	EditorInterface.restart_editor(save)
