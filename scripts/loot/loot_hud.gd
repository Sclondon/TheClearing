class_name LootHud
extends Control
## The inventory on the screen (Loot), in the game's look (Special Elite on
## dark stone, moss edges, as the HUD and the dev panel): a row of slots at the
## top (two, four with a backpack), each with what is in it drawn small (a
## picture of its model, made once when the round starts); the one in his hand
## edged in moss. Tap a slot (or press its number, 1 to 4) to take a tool into
## his hand or put it back, or to read a map or hang a ladder; DROP (or X) puts
## down what is in his hand. On a pad: the d-pad left and right choose a slot,
## up uses it, down drops, Y takes the last tool back into his hand or puts it away.
##
## Under the slots, a line now and then ("NO ROOM: DROP SOMETHING"); at the
## foot of the screen what the act button would take ("E  TAKE THE TORCH"), and
## over it, while he holds a gun, its rounds and his spare ones ("2 / 6  SPARE 3");
## and a map scrap, while it is read.

const FONT := preload("res://fonts/SpecialElite-Regular.ttf")
const INK := Color(0.93, 0.9, 0.8)
const MOSS := Color(0.45, 0.62, 0.33)
const STONE := Color(0.13, 0.14, 0.13, 0.86)
const SLOT := 96.0

var loot: Loot
## The slot chosen with the d-pad.
var chosen := 0

var _bar: HBoxContainer
var _buttons: Array[Button] = []
var _drop: Button
var _prompt: Label
var _ammo: Label
var _toast: Label
var _toast_time := 0.0
var _map_panel: PanelContainer
var _map: LootMap
var _map_time := 0.0
var _last_hand := -1
static var _icons := {}


func _init(of: Loot = null) -> void:
	loot = of
	name = "LootHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_bar = HBoxContainer.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.offset_top = 10
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 8)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_drop = _button("DROP", func() -> void: loot.drop())
	_drop.custom_minimum_size = Vector2(110, SLOT)
	_drop.add_to_group(&"touch_blockers")

	_toast = _label("", 28)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = SLOT + 20
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)

	# (the rounds in the gun in his hand, and his spare ones: only while he holds one)
	_ammo = _label("", 30)
	_ammo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ammo.offset_top = -196
	_ammo.offset_bottom = -158
	_ammo.offset_left = -260
	_ammo.offset_right = 260
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ammo.add_theme_color_override("font_color", INK)
	_ammo.visible = false
	add_child(_ammo)

	_prompt = _label("", 32)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_bottom = -110
	_prompt.offset_left = -320
	_prompt.offset_right = 320
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	_map_panel = PanelContainer.new()
	_map_panel.set_anchors_preset(Control.PRESET_CENTER)
	_map_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_map_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clear := StyleBoxEmpty.new()
	_map_panel.add_theme_stylebox_override("panel", clear)
	_map = LootMap.new(loot)
	_map_panel.add_child(_map)
	_map_panel.visible = false
	add_child(_map_panel)

	if loot:
		loot.changed.connect(_show)
		loot.said.connect(say)
		loot.map_read.connect(read_map)
	_show()
	_make_icons()


func _label(text: String, size_px: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	_style(button, false, false)
	button.pressed.connect(pressed)
	return button


func _style(button: Button, held: bool, picked: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		var base := STONE.lerp(MOSS, 0.32) if held else STONE
		box.bg_color = base if state == "normal" or state == "focus" else base.lerp(MOSS, 0.4 if state == "pressed" else 0.2)
		box.border_color = INK if picked else (MOSS.lightened(0.25) if held else MOSS.darkened(0.2))
		box.set_border_width_all(3 if held or picked else 2)
		box.set_corner_radius_all(4)
		box.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, box)


## Redraws the slots for what is in them now, and the prompt.
func _show() -> void:
	if loot == null or _bar == null:
		return
	var count := loot.slot_count()
	while _buttons.size() < count:
		var i := _buttons.size()
		var button := _button("", func() -> void: _tap(i))
		button.custom_minimum_size = Vector2(SLOT, SLOT)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_constant_override("icon_max_width", 70)
		button.add_to_group(&"touch_blockers")
		_bar.add_child(button)
		_buttons.append(button)
	if _drop.get_parent() == null:
		_bar.add_child(_drop)
	_bar.move_child(_drop, -1)
	for i in _buttons.size():
		var button := _buttons[i]
		var item := loot.in_slot(i)
		var held := item != null and int(item.get(&"loot_id")) == loot.hand
		_style(button, held, i == chosen and Gamepad.using == Gamepad.Using.PAD)
		if item == null:
			button.icon = null
			button.text = str(i + 1)
			button.modulate = Color(1, 1, 1, 0.7)
			continue
		button.modulate = Color.WHITE
		var kind: int = item.get(&"kind")
		button.icon = _icons.get(kind)
		var words: String = LootItem.SHORT[kind]
		if kind == LootItem.Kind.TORCH and float(item.get(&"fuel")) <= 0.0:
			words = "BURNT"
		elif kind == LootItem.Kind.HOOK:
			words = "HOOK %d" % int(item.get(&"bites"))
		elif kind in LootItem.GUNS:
			words = "%s %d" % [words, int(item.get(&"uses"))]
		button.text = ("" if button.icon else words + "\n") + ("%d %s" % [i + 1, words] if button.icon else str(i + 1))
	_drop.visible = loot.hand >= 0
	if loot.hand >= 0:
		_last_hand = loot.hand
	_ammo.text = loot.ammo_text()
	_ammo.visible = _ammo.text != ""
	var near := loot.in_reach
	if near and is_instance_valid(near):
		var key := "" if Gamepad.using == Gamepad.Using.TOUCH else ("X  " if Gamepad.using == Gamepad.Using.PAD else "E  ")
		_prompt.text = key + "TAKE THE " + String(near.call(&"title"))
	else:
		_prompt.text = ""


func _tap(i: int) -> void:
	chosen = i
	loot.use_slot(i)


## A line under the slots for a moment.
func say(text: String) -> void:
	_toast.text = text
	_toast_time = 2.4
	_toast.modulate.a = 1.0


## Shows the map scrap, drawn for where he is, for `seconds`.
func read_map(seconds: float) -> void:
	_map.read()
	_map_panel.visible = true
	_map_time = seconds


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	if _map_time > 0.0:
		_map_time -= delta
		_map_panel.modulate.a = clampf(_map_time / 0.6, 0.0, 1.0)
		if _map_time <= 0.0:
			_map_panel.visible = false
	# (a torch burning down, the hook's catches: the words change without anything being taken or dropped)
	if Engine.get_process_frames() % 30 == 0:
		_show()


func _unhandled_input(event: InputEvent) -> void:
	if loot == null:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var i := int(key.keycode - KEY_1)
				if i < loot.slot_count():
					_tap(i)
			KEY_Q:
				_toggle_hand()
			KEY_X:
				loot.drop()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if Gamepad.pressed(event, &"pad_dpad_left"):
		chosen = posmod(chosen - 1, loot.slot_count())
		_show()
	elif Gamepad.pressed(event, &"pad_dpad_right"):
		chosen = posmod(chosen + 1, loot.slot_count())
		_show()
	elif Gamepad.pressed(event, &"pad_dpad_up"):
		_tap(chosen)
	elif Gamepad.pressed(event, &"pad_dpad_down"):
		loot.drop()
	elif Gamepad.pressed(event, &"pad_y"):
		_toggle_hand()


## Puts away what is in his hand, or takes back the last tool he had out (or the first there is).
func _toggle_hand() -> void:
	if loot.hand >= 0:
		loot.stow()
		return
	var i := loot.slots.find(_last_hand)
	if i < 0:
		for k in loot.slot_count():
			var item := loot.in_slot(k)
			if item and item.call(&"in_hand"):
				i = k
				break
	if i >= 0:
		loot.draw(i)


## Pictures of each kind, made once from its model in a little scene of its
## own, for the slots. (Nothing is drawn headless: the slots say what is in
## them in words until the pictures come.)
func _make_icons() -> void:
	if not _icons.is_empty() or DisplayServer.get_name() == "headless":
		return
	var view := SubViewport.new()
	view.size = Vector2i(128, 128)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.6
	sky.environment = environment
	view.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 1.4
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	camera.current = true
	for kind: int in LootItem.MODELS:
		var model := (load(LootItem.MODELS[kind]) as PackedScene).instantiate() as Node3D
		view.add_child(model)
		LootItem.shade(model)
		var box := AABB()
		var first := true
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var bounds := part.global_transform * part.get_aabb() if part.is_inside_tree() else part.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
		var middle := box.get_center()
		var reach := box.size.length()
		camera.size = reach * 0.8
		camera.global_position = middle + Vector3(0.6, 0.8, 1.0).normalized() * (reach + 1.0)
		camera.look_at(middle)
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		if image and not image.is_empty():
			_icons[kind] = ImageTexture.create_from_image(image)
		model.queue_free()
	view.queue_free()
	_show()
