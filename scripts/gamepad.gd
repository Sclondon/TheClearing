class_name Gamepad
extends Node
## The gamepad, in one place: the actions its sticks and buttons work, which of
## a gamepad, the keys or a finger was used last (so that whatever says what to
## press can say the right thing), and the marks drawn for its buttons.
##
## Any pad that Godot knows the layout of will do (Xbox, PlayStation, Switch
## Pro: SDL's mappings), plugged in before the game starts or after, and in a
## browser (which only owns up to a pad once one of its buttons has been
## pressed). Every action here listens to every pad (`device`).
##
## What the buttons do, wherever the game is:
##
##   left stick     he moves (a little: walks; all the way: runs, and held there sprints);
##                  in the notebook and on a panel, the mark moves; in an editor, the cross moves over the ground
##   right stick    turns the camera; pressed in, brings it round behind him
##   d-pad          moves the mark in the notebook, on a panel and in an editor's lists
##   A (Cross)      jump (held: higher)        / choose, say, put down
##   B (Circle)     duck, crawl                / back, put away, let go
##   X (Square)     his hand: pick up, throw, pull, turn, fire; held, climb a rope  / remove (editors)
##   Y (Triangle)   -                          / the settings of what is chosen (editors)
##   right trigger  his hand too (to fire)     / further off (editors)
##   left trigger   -                          / nearer (editors)
##   shoulders      -                          / the notebook's tabs, an editor's pages
##   Start          the notebook               / an editor's own buttons
##   Back (Select)  in a tomb: Stuck, Edit and the map
##   left stick in  drops him as a ragdoll and stands him up (as R does) / undo (editors)
##   right stick in the camera behind him      / redo (editors)
##
## `Gamepad.ensure(tree)` makes the actions and puts one of these in the tree
## to hear what is used; it is asked for by whatever needs it, any number of times.

enum Using { KEYS, PAD, TOUCH }
## Which make of pad the marks are drawn for.
enum Make { XBOX, SONY, NINTENDO }

## How far a stick must be pushed to count as a step from one thing to the
## next, and how long held before it steps again, and again.
const PUSH := 0.55
const FIRST_WAIT := 0.36
const NEXT_WAIT := 0.13

const BUTTONS := {
	&"pad_a": JOY_BUTTON_A, &"pad_b": JOY_BUTTON_B, &"pad_x": JOY_BUTTON_X, &"pad_y": JOY_BUTTON_Y,
	&"pad_lb": JOY_BUTTON_LEFT_SHOULDER, &"pad_rb": JOY_BUTTON_RIGHT_SHOULDER,
	&"pad_start": JOY_BUTTON_START, &"pad_back": JOY_BUTTON_BACK,
	&"pad_l3": JOY_BUTTON_LEFT_STICK, &"pad_r3": JOY_BUTTON_RIGHT_STICK,
	&"pad_dpad_left": JOY_BUTTON_DPAD_LEFT, &"pad_dpad_right": JOY_BUTTON_DPAD_RIGHT,
	&"pad_dpad_up": JOY_BUTTON_DPAD_UP, &"pad_dpad_down": JOY_BUTTON_DPAD_DOWN,
}
const AXES := {
	&"pad_ls_left": [JOY_AXIS_LEFT_X, -1.0], &"pad_ls_right": [JOY_AXIS_LEFT_X, 1.0],
	&"pad_ls_up": [JOY_AXIS_LEFT_Y, -1.0], &"pad_ls_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"pad_rs_left": [JOY_AXIS_RIGHT_X, -1.0], &"pad_rs_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"pad_rs_up": [JOY_AXIS_RIGHT_Y, -1.0], &"pad_rs_down": [JOY_AXIS_RIGHT_Y, 1.0],
	&"pad_lt": [JOY_AXIS_TRIGGER_LEFT, 1.0], &"pad_rt": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

## Which was used last. A game on a phone starts with a finger; anywhere else with the keys.
static var using := Using.KEYS
## The pad that is listened to: -1 for every one. (A test listens to one of its
## own, so that a real pad on the desk, which is heard whether the window has
## the focus or not, cannot upset it: see `listen_to`.)
static var device := -1
static var _made := false


## Makes the gamepad's actions, and puts a listener in the tree if there is none.
static func ensure(tree: SceneTree = null) -> void:
	if not _made:
		_made = true
		if TouchControls.wanted():
			using = Using.TOUCH
		for action: StringName in BUTTONS:
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.5)
				var press := InputEventJoypadButton.new()
				press.button_index = BUTTONS[action]
				press.device = device
				InputMap.action_add_event(action, press)
		for action: StringName in AXES:
			if not InputMap.has_action(action):
				InputMap.add_action(action, 0.2)
				var motion := InputEventJoypadMotion.new()
				motion.axis = AXES[action][0]
				motion.axis_value = AXES[action][1]
				motion.device = device
				InputMap.action_add_event(action, motion)
	if tree and tree.root.get_node_or_null(^"Gamepad") == null:
		var listener := Gamepad.new()
		listener.name = "Gamepad"
		listener.process_mode = Node.PROCESS_MODE_ALWAYS
		# (it may be asked for while the tree is being put together)
		tree.root.add_child.call_deferred(listener)


## Has every action hear only one pad (or, with -1, any): what a pad can do to
## an action made before or after this is asked. For the tools.
static func listen_to(only: int) -> void:
	device = only
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)
				event.device = only
				InputMap.action_add_event(action, event)
		Input.action_release(action)


## Whether something a pad did is to be listened to (see `device`).
static func heard(event: InputEvent) -> bool:
	return (event is InputEventJoypadButton or event is InputEventJoypadMotion) and (device == -1 or event.device == device)


static func pressed(event: InputEvent, action: StringName) -> bool:
	return event is InputEventJoypadButton and heard(event) and event.is_action_pressed(action)


static func using_pad() -> bool:
	return using == Using.PAD


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if heard(event) and event.pressed:
			using = Using.PAD
	elif event is InputEventJoypadMotion:
		# (a stick that is a hair off its middle says so all the time: that is not somebody using it)
		if heard(event) and absf(event.axis_value) > 0.3:
			using = Using.PAD
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			using = Using.KEYS
	elif event is InputEventScreenTouch:
		# (a mouse made to stand for a finger is a mouse)
		using = Using.KEYS if event.device == InputEvent.DEVICE_ID_EMULATION else Using.TOUCH


# --- The sticks

## The left stick: x to the right, y down, length up to 1.
static func left() -> Vector2:
	return Input.get_vector(&"pad_ls_left", &"pad_ls_right", &"pad_ls_up", &"pad_ls_down")


static func right() -> Vector2:
	return Input.get_vector(&"pad_rs_left", &"pad_rs_right", &"pad_rs_up", &"pad_rs_down")


## The d-pad, as a direction (or none).
static func dpad() -> Vector2:
	return Vector2(Input.get_axis(&"pad_dpad_left", &"pad_dpad_right"), Input.get_axis(&"pad_dpad_up", &"pad_dpad_down"))


## The triggers: how far the right is pulled, less how far the left is.
static func triggers() -> float:
	return Input.get_action_strength(&"pad_rt") - Input.get_action_strength(&"pad_lt")


## Lets go of everything a pad holds (when what it was held for has gone).
static func let_go() -> void:
	for action: StringName in BUTTONS.keys() + AXES.keys():
		Input.action_release(action)


## A stick or a d-pad as steps from one thing to the next: one when it is
## pushed, and after a moment one after another for as long as it is held.
## Whatever is moved so keeps one of these and asks it each frame.
class Steps:
	## Whether the left stick steps as well as the d-pad.
	var stick := true
	var _way := Vector2.ZERO
	var _wait := 0.0

	## The step to take this frame: a direction (one of four), or none.
	func take(delta: float) -> Vector2:
		var way := Gamepad.dpad()
		if way == Vector2.ZERO and stick:
			var pushed := Gamepad.left()
			if pushed.length() > Gamepad.PUSH:
				way = pushed
		if way != Vector2.ZERO:
			way = Vector2(signf(way.x), 0.0) if absf(way.x) > absf(way.y) else Vector2(0.0, signf(way.y))
		if way != _way:
			_way = way
			_wait = Gamepad.FIRST_WAIT
			return way
		if way == Vector2.ZERO:
			return way
		_wait -= delta
		if _wait <= 0.0:
			_wait = Gamepad.NEXT_WAIT
			return way
		return Vector2.ZERO


# --- The marks

## Whose pad it is, from what it calls itself.
static func make() -> Make:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return Make.XBOX
	var name := Input.get_joy_name(device if pads.has(device) else pads[0]).to_lower()
	for word: String in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]:
		if name.contains(word):
			return Make.SONY
	for word: String in ["nintendo", "switch", "joy-con", "joycon"]:
		if name.contains(word):
			return Make.NINTENDO
	return Make.XBOX


## What is written on a button, for the make of pad: "A", "LB", "Start"... A
## PlayStation's four are shapes, and are drawn, not written (see `draw`).
static func word(action: StringName) -> String:
	var whose := make()
	match action:
		&"pad_a":
			return "B" if whose == Make.NINTENDO else "A"
		&"pad_b":
			return "A" if whose == Make.NINTENDO else "B"
		&"pad_x":
			return "Y" if whose == Make.NINTENDO else "X"
		&"pad_y":
			return "X" if whose == Make.NINTENDO else "Y"
		&"pad_lb":
			return "L1" if whose == Make.SONY else ("L" if whose == Make.NINTENDO else "LB")
		&"pad_rb":
			return "R1" if whose == Make.SONY else ("R" if whose == Make.NINTENDO else "RB")
		&"pad_lt":
			return "L2" if whose == Make.SONY else ("ZL" if whose == Make.NINTENDO else "LT")
		&"pad_rt":
			return "R2" if whose == Make.SONY else ("ZR" if whose == Make.NINTENDO else "RT")
		&"pad_start":
			return "Options" if whose == Make.SONY else ("+" if whose == Make.NINTENDO else "Start")
		&"pad_back":
			return "Share" if whose == Make.SONY else ("-" if whose == Make.NINTENDO else "Back")
		&"pad_l3":
			return "L"
		&"pad_r3":
			return "R"
		&"pad_ls":
			return "L"
		&"pad_rs":
			return "R"
		&"pad_dpad":
			return "+"
	return "?"


## The same in words, to go in a sentence: "A", "Cross", "the left stick"...
static func said(action: StringName) -> String:
	if make() == Make.SONY and action in [&"pad_a", &"pad_b", &"pad_x", &"pad_y"]:
		return {&"pad_a": "Cross", &"pad_b": "Circle", &"pad_x": "Square", &"pad_y": "Triangle"}[action]
	match action:
		&"pad_ls":
			return "the left stick"
		&"pad_rs":
			return "the right stick"
		&"pad_l3":
			return "the left stick pressed in"
		&"pad_r3":
			return "the right stick pressed in"
		&"pad_dpad":
			return "the d-pad"
	return word(action)


## How wide the mark for a button is, for a ring of this radius.
static func mark_width(action: StringName, radius: float, font: Font = null) -> float:
	var text := word(action)
	if text.length() <= 1 or font == null:
		return radius * 2.0
	return maxf(radius * 2.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(radius * 1.15)).x + radius * 1.1)


## Draws the mark for a button, its middle at `at`: its letter in a ring (a
## shape, on a PlayStation's four; a ring within a ring for a stick; a cross
## for the d-pad; its word in a lozenge for a shoulder, a trigger or Start).
## `ink` is the line and the letter; `ground`, if given, is filled in under them.
static func draw(on: CanvasItem, action: StringName, at: Vector2, radius: float, ink: Color, ground := Color(0, 0, 0, 0), font: Font = null) -> void:
	if font == null:
		font = ThemeDB.fallback_font
	var thick := maxf(1.6, radius * 0.14)
	if action == &"pad_dpad":
		var arm := radius * 0.36
		for bar: Rect2 in [Rect2(at.x - radius, at.y - arm, radius * 2.0, arm * 2.0), Rect2(at.x - arm, at.y - radius, arm * 2.0, radius * 2.0)]:
			if ground.a > 0.0:
				on.draw_rect(bar, ground)
		on.draw_polyline([at + Vector2(-arm, -arm), at + Vector2(-arm, -radius), at + Vector2(arm, -radius), at + Vector2(arm, -arm), at + Vector2(radius, -arm),
			at + Vector2(radius, arm), at + Vector2(arm, arm), at + Vector2(arm, radius), at + Vector2(-arm, radius), at + Vector2(-arm, arm),
			at + Vector2(-radius, arm), at + Vector2(-radius, -arm), at + Vector2(-arm, -arm)], ink, thick, true)
		return
	var text := word(action)
	var size := int(radius * 1.15)
	if text.length() > 1:
		# (a word: in a lozenge as wide as it needs)
		var wide := mark_width(action, radius, font)
		var box := StyleBoxFlat.new()
		box.bg_color = ground
		box.border_color = ink
		box.set_border_width_all(int(ceilf(thick)))
		box.set_corner_radius_all(int(radius * 0.7))
		box.anti_aliasing = true
		on.draw_style_box(box, Rect2(at.x - wide * 0.5, at.y - radius, wide, radius * 2.0))
		on.draw_string(font, Vector2(at.x - wide * 0.5, at.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, wide, size, ink)
		return
	if ground.a > 0.0:
		on.draw_circle(at, radius, ground)
	on.draw_arc(at, radius, 0.0, TAU, 28, ink, thick, true)
	if action in [&"pad_ls", &"pad_rs", &"pad_l3", &"pad_r3"]:
		# (a stick: its cap inside the ring; pressed in, the cap is filled)
		if action in [&"pad_l3", &"pad_r3"]:
			on.draw_circle(at, radius * 0.62, Color(ink, ink.a * 0.35))
		on.draw_arc(at, radius * 0.62, 0.0, TAU, 20, ink, thick * 0.8, true)
		on.draw_string(font, Vector2(at.x - radius, at.y + size * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(size * 0.8), ink)
		return
	if make() == Make.SONY and action in [&"pad_a", &"pad_b", &"pad_x", &"pad_y"]:
		var r := radius * 0.46
		match action:
			&"pad_a":
				on.draw_line(at + Vector2(-r, -r), at + Vector2(r, r), ink, thick, true)
				on.draw_line(at + Vector2(r, -r), at + Vector2(-r, r), ink, thick, true)
			&"pad_b":
				on.draw_arc(at, r * 1.1, 0.0, TAU, 20, ink, thick, true)
			&"pad_x":
				on.draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), ink, false, thick)
			&"pad_y":
				on.draw_polyline([at + Vector2(0.0, -r * 1.15), at + Vector2(r * 1.1, r * 0.8), at + Vector2(-r * 1.1, r * 0.8), at + Vector2(0.0, -r * 1.15)], ink, thick, true)
		return
	on.draw_string(font, Vector2(at.x - radius, at.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, ink)


## Draws a row of marks with what each does written after it: `told` is
## [[action, "what it does"], ...]. Returns how wide the row came out.
static func draw_row(on: CanvasItem, told: Array, at: Vector2, radius: float, ink: Color, ground := Color(0, 0, 0, 0), font: Font = null, points := 0) -> float:
	if font == null:
		font = ThemeDB.fallback_font
	if points == 0:
		points = int(radius * 1.3)
	var x := at.x
	for entry: Array in told:
		var wide := mark_width(entry[0], radius, font)
		draw(on, entry[0], Vector2(x + wide * 0.5, at.y), radius, ink, ground, font)
		x += wide + radius * 0.45
		var text: String = entry[1]
		on.draw_string(font, Vector2(x, at.y + points * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, points, ink)
		x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, points).x + radius * 1.5
	return x - at.x


## How wide `draw_row` would draw a row.
static func row_width(told: Array, radius: float, font: Font = null, points := 0) -> float:
	if font == null:
		font = ThemeDB.fallback_font
	if points == 0:
		points = int(radius * 1.3)
	var wide := 0.0
	for entry: Array in told:
		wide += mark_width(entry[0], radius, font) + radius * 0.45 + font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, points).x + radius * 1.5
	return wide


## What the buttons do, on a dark ground of its own: marks and words as
## `draw_row` draws them, its bottom left corner at `at`, in as many rows (going
## up) as keep it no wider than `most`.
static func draw_legend(on: CanvasItem, told: Array, at: Vector2, most := INF, radius := 12.0, points := 17) -> void:
	var rows: Array = [[]]
	for entry: Array in told:
		if not (rows[-1] as Array).is_empty() and row_width(rows[-1] + [entry], radius, null, points) > most - 20.0:
			rows.append([])
		(rows[-1] as Array).append(entry)
	var tall := radius * 2.0 + 12.0
	var widest := 0.0
	for row: Array in rows:
		widest = maxf(widest, row_width(row, radius, null, points))
	on.draw_rect(Rect2(at.x, at.y - tall * rows.size(), widest + 8.0, tall * rows.size()), Color(0.0, 0.0, 0.0, 0.6))
	for i in rows.size():
		draw_row(on, rows[i], Vector2(at.x + 10.0, at.y - tall * (rows.size() - i) + tall * 0.5), radius, Color.WHITE, Color(0, 0, 0, 0), null, points)
