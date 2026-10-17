class_name TouchControls
extends Control
## Touch input: a floating stick on the left of the screen; on the right, two
## small buttons (duck, act) and jump anywhere else. Where the camera can be
## turned (`look_enabled`), jump is its own button, and a drag anywhere else on
## the right turns the camera: a mark there shows where, and two quick taps
## bring the camera round behind him.
##
## Sprint, two ways, neither of which takes the right thumb off jump for long:
## push the stick on out past its rim (a second, dashed ring shows where) and
## he sprints for as long as the thumb is out there; or tap the SPRINT button
## (left of jump) and he sprints until it is tapped again or the stick is let go.
##
## The stick appears wherever the thumb lands and its base trails the thumb when
## dragged past the rim, so the player never has to look for it or re-centre.

signal jump_pressed
signal jump_released
signal act_pressed
## Two quick taps where the camera is turned: put it back behind him.
signal look_reset

## Fraction of the screen width (from the left) that belongs to the stick.
@export_range(0.2, 0.8) var stick_zone := 0.5
## Stick travel in viewport pixels.
@export var stick_radius := 105.0
@export_range(0.0, 0.5) var dead_zone := 0.14
@export var tint := Color(1.0, 1.0, 1.0)

## Stick output, length 0..1. X is right, Y is down the screen.
var move := Vector2.ZERO
var jump_held := false
var duck_held := false
## Sprinting (see the class notes): the button's toggle, or the stick pushed past its rim.
var sprint_held: bool:
	get:
		return _sprint_on or _rim
	set(value):
		_sprint_on = value
## How far past its rim the stick must be pushed to sprint, as a share of `stick_radius`.
@export var sprint_rim := 1.28
## The hand: pressed (`act_pressed`) it picks up, throws and so on; held, it climbs a rope.
var act_held := false
## Set by an orbiting camera: drags on the right of the screen (off the
## buttons) then turn it, and jump is its button only.
var look_enabled := false

var _stick_index := -1
var _jump_index := -1
var _duck_index := -1
var _act_index := -1
var _sprint_index := -1
## The button's toggle, and the stick out past its rim.
var _sprint_on := false
var _rim := false
var _sprint_alpha := 0.0
var _rim_alpha := 0.0
var _look_index := -1
var _look := Vector2.ZERO
## The touch that is turning the camera: where and when it came down, how far
## it has gone, and when the last tap there was (for two quick taps).
var _look_from := Vector2.ZERO
var _look_since := 0.0
var _look_gone := 0.0
var _tapped_at := -10.0
var _look_alpha := 0.0
## Whether the camera has been turned by touch yet (until it has, the mark says how).
static var _look_known := false
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_alpha := 0.0
var _jump_alpha := 0.0
var _duck_alpha := 0.0
var _act_alpha := 0.0
var _hint_alpha := 0.0
## Whether a finger has been on the screen since the game started (a mouse made to stand for one does not count).
static var touched := false


## Whether the controls are to be drawn, and the editors laid out for a phone: on a phone or a tablet, in its own
## game or in its browser; and anywhere else once a finger has really been on the screen. Never for a mouse.
static func wanted() -> bool:
	return touched or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _init() -> void:
	add_to_group(&"touch_controls")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shown on a phone from the start; on a desk only once a finger has been on the screen (`wanted`).
	_hint_alpha = 1.0 if wanted() else 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# (a mouse standing for a finger still works them, but does not bring them up)
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			touched = true
		var pos: Vector2 = make_input_local(event).position
		if event.pressed:
			_press(event.index, pos)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag and event.index == _look_index:
		_look += event.relative
		_look_gone += event.relative.length()
		if _look_gone > 40.0:
			_look_known = true
	elif event is InputEventScreenDrag and event.index == _stick_index:
		_drag(make_input_local(event).position)


func _notification(what: int) -> void:
	# Touches never get a release event if the app loses focus mid-press.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		for index: int in [_stick_index, _jump_index, _duck_index, _act_index, _look_index, _sprint_index]:
			_release(index)


func _button_radius() -> float:
	return stick_radius * 0.58


## The buttons sit in the bottom right corner, measured from it in button
## sizes so that they are on the screen either way up: duck under the thumb's
## resting place, act beside it, jump above them, sprint left of jump.
func _duck_centre() -> Vector2:
	var r := _button_radius()
	return Vector2(size.x - r * 1.25, size.y - r * 1.3)


func _act_centre() -> Vector2:
	return _duck_centre() - Vector2(_button_radius() * 2.3, 0.0)


func _jump_centre() -> Vector2:
	return (_duck_centre() + _act_centre()) * 0.5 - Vector2(0.0, _button_radius() * 2.15)


## Sprint: left of jump, at its height, out of the stick's half of the screen.
func _sprint_centre() -> Vector2:
	var beside := _jump_centre().x - stick_radius * 0.62 - _button_radius() * 1.25
	return Vector2(maxf(beside, size.x * stick_zone + _button_radius() * 1.15), _jump_centre().y)


## Where the mark for turning the camera is drawn.
func _look_centre() -> Vector2:
	return Vector2(size.x * 0.72, size.y * 0.3)


func _press(index: int, pos: Vector2) -> void:
	# The top right corner belongs to the menu button.
	if pos.y < 64.0 and pos.x > size.x - 130.0:
		return
	if wanted():
		_hint_alpha = 1.0
	var reach := _button_radius() * 1.3
	if pos.x < size.x * stick_zone:
		if _stick_index == -1:
			_stick_index = index
			_stick_origin = pos
			_stick_knob = pos
			move = Vector2.ZERO
	elif pos.distance_to(_sprint_centre()) < reach:
		if _sprint_index == -1:
			_sprint_index = index
			_sprint_on = not _sprint_on
	elif pos.distance_to(_duck_centre()) < reach:
		if _duck_index == -1:
			_duck_index = index
			duck_held = true
	elif pos.distance_to(_act_centre()) < reach:
		if _act_index == -1:
			_act_index = index
			act_held = true
			act_pressed.emit()
	elif look_enabled and pos.distance_to(_jump_centre()) > stick_radius * 0.62 * 1.45:
		if _look_index == -1:
			_look_index = index
			_look_from = pos
			_look_gone = 0.0
			_look_since = Time.get_ticks_msec() * 0.001
	elif _jump_index == -1:
		_jump_index = index
		jump_held = true
		jump_pressed.emit()


func _release(index: int) -> void:
	if index == -1:
		return
	if index == _stick_index:
		_stick_index = -1
		# (letting go of the stick is stopping: the sprint goes with it)
		_sprint_on = false
		_rim = false
		move = Vector2.ZERO
	elif index == _jump_index:
		_jump_index = -1
		jump_held = false
		jump_released.emit()
	elif index == _sprint_index:
		_sprint_index = -1
	elif index == _duck_index:
		_duck_index = -1
		duck_held = false
	elif index == _look_index:
		_look_index = -1
		# (a touch that came and went without going anywhere is a tap; two of them close together bring the camera round)
		var now := Time.get_ticks_msec() * 0.001
		if _look_gone < 14.0 and now - _look_since < 0.3:
			if now - _tapped_at < 0.45:
				_tapped_at = -10.0
				look_reset.emit()
			else:
				_tapped_at = now
	elif index == _act_index:
		_act_index = -1
		act_held = false


func _drag(pos: Vector2) -> void:
	var offset := pos - _stick_origin
	var out := offset.length()
	# Past the rim (by a little more to start than to stop) he sprints; the base
	# only trails the thumb once it is out beyond the sprinting ring.
	_rim = out > stick_radius * sprint_rim if not _rim else out > stick_radius * 1.05
	var trail := stick_radius * (sprint_rim + 0.22)
	if out > trail:
		_stick_origin = pos - offset / out * trail
		offset = pos - _stick_origin
	var distance := minf(offset.length(), stick_radius)
	if offset.length() > stick_radius:
		offset = offset / offset.length() * stick_radius
	_stick_knob = pos
	var strength := inverse_lerp(dead_zone, 1.0, distance / stick_radius)
	move = offset / distance * clampf(strength, 0.0, 1.0) if distance > 0.0 else Vector2.ZERO


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-14.0 * delta)
	_stick_alpha = lerpf(_stick_alpha, 1.0 if _stick_index != -1 else 0.0, blend)
	_jump_alpha = lerpf(_jump_alpha, 1.0 if jump_held else 0.0, blend)
	_duck_alpha = lerpf(_duck_alpha, 1.0 if duck_held else 0.0, blend)
	_act_alpha = lerpf(_act_alpha, 1.0 if _act_index != -1 else 0.0, blend)
	_sprint_alpha = lerpf(_sprint_alpha, 1.0 if sprint_held else 0.0, blend)
	_rim_alpha = lerpf(_rim_alpha, 1.0 if _stick_index != -1 else 0.0, blend)
	_look_alpha = lerpf(_look_alpha, 1.0 if _look_index != -1 else 0.0, blend)
	queue_redraw()


func _draw() -> void:
	if _hint_alpha <= 0.0:
		return
	# Everything is drawn twice over: a dark ground and a pale line on it, so
	# that it shows on bright sand as well as in the dark.
	var rest := Vector2(size.x * 0.14, size.y - size.x * 0.13)
	var origin := _stick_origin if _stick_index != -1 else rest
	var knob := _stick_knob if _stick_index != -1 else rest
	draw_circle(origin, stick_radius, Color(0.0, 0.0, 0.0, lerpf(0.1, 0.16, _stick_alpha)))
	draw_arc(origin, stick_radius, 0.0, TAU, 48, Color(tint, lerpf(0.45, 0.7, _stick_alpha)), 2.5, true)
	# (the sprinting ring, dashed, out past the rim: it lights up while he sprints)
	if _rim_alpha > 0.01:
		var ring := stick_radius * sprint_rim
		for k in 24:
			var a := TAU * k / 24.0
			draw_arc(origin, ring, a, a + TAU / 48.0, 4, Color(tint, lerpf(0.3, 0.95, _sprint_alpha) * _rim_alpha), lerpf(2.0, 4.0, _sprint_alpha), true)
	draw_circle(knob, stick_radius * 0.36, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(knob, stick_radius * 0.33, Color(tint, lerpf(0.4, 0.7, _stick_alpha)))

	var jump_centre := _jump_centre()
	_draw_button(jump_centre, stick_radius * 0.62, _jump_alpha)
	_draw_button(_duck_centre(), _button_radius(), _duck_alpha)
	_draw_button(_act_centre(), _button_radius(), _act_alpha)
	_draw_button(_sprint_centre(), _button_radius(), _sprint_alpha)
	var mark := Color(tint, 0.9)
	# Jump: a chevron pointing up. Duck: one pointing down. Grab: an open hand.
	draw_polyline([jump_centre + Vector2(-17.0, 8.0), jump_centre + Vector2(0.0, -11.0), jump_centre + Vector2(17.0, 8.0)], mark, 3.5, true)
	var duck := _duck_centre()
	draw_polyline([duck + Vector2(-13.0, -6.0), duck + Vector2(0.0, 8.0), duck + Vector2(13.0, -6.0)], mark, 3.5, true)
	_draw_hand(_act_centre(), _button_radius() * 0.5, mark)
	_draw_sprint(_sprint_centre(), _button_radius(), mark)
	if look_enabled:
		_draw_look(_look_centre(), _button_radius() * 0.8)


# Sprint: two chevrons leaning forward, like speed lines, and the word under them.
func _draw_sprint(centre: Vector2, radius: float, colour: Color) -> void:
	var w := radius * 0.26
	for k in 2:
		var at := centre + Vector2(-radius * 0.2 + k * radius * 0.32, -radius * 0.14)
		draw_polyline([at + Vector2(-w * 0.55, -w), at + Vector2(w * 0.55, 0.0), at + Vector2(-w * 0.55, w)], colour, 3.5, true)
	var font := get_theme_default_font()
	var big := int(radius * 0.27)
	var words := "SPRINT"
	var wide := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big).x
	draw_string(font, centre + Vector2(-wide * 0.5, radius * 0.55), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big, colour)


# An open hand, palm towards the eye, about `reach` from its middle to a fingertip.
func _draw_hand(centre: Vector2, reach: float, colour: Color) -> void:
	var palm := centre + Vector2(0.0, reach * 0.34)
	var thick := reach * 0.25
	# The palm, then four fingers fanned a little, the middle one longest, and the thumb out to the side.
	draw_circle(palm, reach * 0.5, colour)
	draw_rect(Rect2(palm + Vector2(-reach * 0.5, -reach * 0.42), Vector2(reach, reach * 0.5)), colour)
	for finger: Array in [[-0.37, -0.12, 0.84], [-0.125, -0.04, 1.0], [0.125, 0.04, 0.95], [0.37, 0.13, 0.76]]:
		var root := palm + Vector2(float(finger[0]) * reach, -reach * 0.36)
		var tip := root + Vector2(float(finger[1]), -1.0).normalized() * reach * float(finger[2])
		draw_line(root, tip, colour, thick, true)
		draw_circle(tip, thick * 0.5, colour)
	var thumb_root := palm + Vector2(-reach * 0.42, reach * 0.02)
	var thumb_tip := thumb_root + Vector2(-0.8, -0.6).normalized() * reach * 0.62
	draw_line(thumb_root, thumb_tip, colour, thick * 1.1, true)
	draw_circle(thumb_tip, thick * 0.55, colour)


# The mark for turning the camera: an eye in a ring with an arrowhead to each
# side, above and below; and, until he has done it once, the words for it.
func _draw_look(centre: Vector2, radius: float) -> void:
	var faint := lerpf(0.55 if not _look_known else 0.3, 0.9, _look_alpha)
	draw_circle(centre, radius, Color(0.0, 0.0, 0.0, 0.12 * faint / 0.55))
	draw_arc(centre, radius, 0.0, TAU, 40, Color(tint, faint * 0.8), 2.0, true)
	var mark := Color(tint, faint)
	# (the eye: two lids and the dark of it)
	var wide := radius * 0.5
	var lids := PackedVector2Array()
	for i in 13:
		var along := i / 12.0
		lids.append(centre + Vector2(lerpf(-wide, wide, along), -sin(along * PI) * wide * 0.55))
	for i in 13:
		var along := 1.0 - i / 12.0
		lids.append(centre + Vector2(lerpf(-wide, wide, along), sin(along * PI) * wide * 0.55))
	draw_polyline(lids, mark, 2.5, true)
	draw_circle(centre, wide * 0.3, mark)
	for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var tip := centre + way * radius * 1.38
		var back := tip - way * radius * 0.2
		var across := Vector2(-way.y, way.x) * radius * 0.2
		draw_polyline([back + across, tip, back - across], mark, 2.5, true)
	if not _look_known:
		var font := get_theme_default_font()
		var words := "Drag to look around"
		var big := 20
		var wide_words := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big).x
		var at := centre + Vector2(-wide_words * 0.5, radius * 1.38 + 34.0)
		draw_string_outline(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, big, Color(tint, 0.9))


func _draw_button(centre: Vector2, radius: float, pressed: float) -> void:
	draw_circle(centre, radius, Color(0.0, 0.0, 0.0, lerpf(0.22, 0.1, pressed)))
	draw_circle(centre, radius * lerpf(0.0, 0.92, pressed), Color(tint, 0.45 * pressed))
	draw_arc(centre, radius, 0.0, TAU, 40, Color(tint, lerpf(0.6, 0.95, pressed)), 2.5, true)


## How far the look-drag has moved since this was last asked, in pixels.
func take_look() -> Vector2:
	var moved := _look
	_look = Vector2.ZERO
	return moved
