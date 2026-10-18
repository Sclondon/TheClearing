class_name DevTools
extends Control
## God mode for trying the maze out: a DEV button under the clock opens a panel
## that puts things that hunt into the maze ahead of the boy, clears or stops
## them, makes him uncatchable, and moves him to a gate, the middle or the exit.
## Keys: ` opens it, G god, M a mummy, N the snake, B a Griever.
##
## On when the game is run from the Godot editor, or with the flag `dev`
## (`-- --dev`, or `?dev` on the page). Then everyone starts in front of a gate
## of the clearing (World.spawn) unless `start=middle` is given too.
##
## What it puts in is only in this copy of the game: play alone with it.

const FONT := preload("res://fonts/SpecialElite-Regular.ttf")
const Flags := preload("res://scripts/flags.gd")
const INK := Color(0.93, 0.9, 0.8)
const MOSS := Color(0.45, 0.62, 0.33)
const STONE := Color(0.13, 0.14, 0.13, 0.86)
## How far ahead of him things are put, metres (short of any wall in the way).
const AHEAD := 12.0
## The snake is long: further off, so that he is not on top of him.
const SNAKE_AHEAD := 20.0
## The other kinds the panel puts in (spawn_hunter): the button, the kind, and
## how far ahead (the big ones further off, like the snake).
const HUNTERS := [
	["GHOUL", "ghoul", AHEAD], ["CENTIPEDE", "centipede", SNAKE_AHEAD], ["SPIDER", "spider", AHEAD],
	["ABOMINATION", "abomination", SNAKE_AHEAD], ["SLIME WALL", "slime", SNAKE_AHEAD], ["BATS", "bats", AHEAD],
	["BABOONS", "baboons", AHEAD], ["DOGS", "dogs", AHEAD], ["ALIENS", "aliens", AHEAD],
	["IMPS", "imps", AHEAD], ["IMP SWARM", "imp_swarm", AHEAD],
]

var world: World
## He cannot be caught.
var god := false
## What hunts the maze is stopped where it is.
var frozen := false

var _panel: PanelContainer
var _god_button: Button
var _freeze_button: Button
var _kind_button: Button
var _kind := 0
var _gate := 0
## Grievers put in here (the one World puts in is world.griever).
var _grievers: Array[Griever] = []


## Whether dev tools are on for this run.
static func enabled() -> bool:
	if Flags.value("dev") != "":
		return true
	# (run from the editor: its debugger is attached, and the game often sits in its Game
	# tab; tests and tools run with -s have neither)
	return EngineDebugger.is_active() or Engine.is_embedded_in_editor()


func _init(in_world: World) -> void:
	world = in_world
	name = "DevTools"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var open := _button("DEV", toggle)
	open.position = Vector2(16, 64)
	open.custom_minimum_size = Vector2(84, 48)
	add_child(open)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = STONE
	box.border_color = MOSS.darkened(0.2)
	box.set_border_width_all(2)
	box.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.position = Vector2(16, 120)
	_panel.visible = false
	add_child(_panel)
	var grid := GridContainer.new()
	# (three across, so that it all fits on a phone held either way)
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_panel.add_child(grid)
	_god_button = _button("", toggle_god)
	grid.add_child(_god_button)
	_freeze_button = _button("", toggle_freeze)
	grid.add_child(_freeze_button)
	_kind_button = _button("", next_kind)
	grid.add_child(_kind_button)
	grid.add_child(_button("+ MUMMY", spawn_mummy))
	grid.add_child(_button("+ PACK", spawn_pack))
	grid.add_child(_button("+ SNAKE", spawn_snake))
	grid.add_child(_button("+ GRIEVER", spawn_griever))
	for one: Array in HUNTERS:
		grid.add_child(_button("+ " + String(one[0]), spawn_hunter.bind(one[1], one[2])))
	grid.add_child(_button("CLEAR ALL", clear))
	grid.add_child(_button("TO GATE", to_gate))
	grid.add_child(_button("TO MIDDLE", to_middle))
	grid.add_child(_button("TO EXIT", to_exit))
	grid.add_child(_button("CLOSE", toggle))
	_show()


func toggle() -> void:
	_panel.visible = not _panel.visible
	# (fingers on the panel are not to move him or turn the camera)
	if world.touch:
		world.touch.set_process_input(not _panel.visible)


func toggle_god() -> void:
	god = not god
	_show()


func toggle_freeze() -> void:
	frozen = not frozen
	for hunter in _hunters():
		hunter.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
	_show()


func next_kind() -> void:
	_kind = (_kind + 1) % Mummy.Kind.size()
	_show()


# --- Putting things in ------------------------------------------------------

func spawn_mummy() -> void:
	var mummy := Mummy.new()
	mummy.kind = _kind as Mummy.Kind
	_add(mummy, _ahead())


## A pack of the chosen kind and two shamblers, side by side.
func spawn_pack() -> void:
	var at := _ahead()
	var across := _look().cross(Vector3.UP) * 2.4
	for k in 3:
		var mummy := Mummy.new()
		mummy.kind = _kind as Mummy.Kind if k == 0 else Mummy.Kind.SHAMBLER
		_add(mummy, at + across * (k - 1))


func spawn_snake() -> void:
	_add(Apophis.new(), _ahead(SNAKE_AHEAD))


func spawn_griever() -> void:
	var at := _ahead()
	var griever := Griever.new()
	griever.name = "DevGriever%d" % _grievers.size()
	world.add_child(griever)
	griever.setup(world.maze, world.maze.cell_at(at), _facing_him(at))
	griever.place(at, _facing_him(at))
	griever.caught.connect(world._on_caught)
	Grass.push(griever, 1.6)
	_grievers.append(griever)
	if frozen:
		griever.process_mode = Node.PROCESS_MODE_DISABLED


## Puts one of the other kinds in ahead of him (see HUNTERS): one creature, or
## a whole pack for those that go about in packs, side by side across his way.
func spawn_hunter(kind: String, reach := AHEAD) -> void:
	var at := _ahead(reach)
	var across := _look().cross(Vector3.UP) * 2.6
	var made: Array = []
	match kind:
		"ghoul":
			made = [MazeGhoul.new()]
		"centipede":
			made = [Centipede.new()]
		"spider":
			made = [MazeSpider.new()]
		"abomination":
			made = [Abomination.new()]
		"slime":
			made = [MazeSlimeWall.new()]
		"bats":
			made = [Bats.new()]
		"baboons":
			made = MazeBaboon.troop(5)
		"dogs":
			made = MazeDog.pack_of(4, randi())
		"aliens":
			made = [Alien.new(), Alien.new()]
		"imps":
			made = MazeImp.gang(4)
		"imp_swarm":
			made = [MazeImpSwarm.new()]
	for k in made.size():
		_add(made[k], at + across * (k - (made.size() - 1) * 0.5))


## Takes away everything that hunts (the Griever World put in is only put to
## sleep and hidden, as the room's news is built from it).
func clear() -> void:
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	for griever in _grievers:
		griever.queue_free()
	_grievers.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false


## Puts one in at `at`, facing him. (Allowed in the clearing, so that what is put
## in there stays where it can be seen.)
func _add(enemy: MazeEnemy, at: Vector3) -> void:
	enemy.keep_out_of_clearing = false
	var cell := world.maze.cell_at(at)
	world.enemies.add(enemy, cell, _facing_him(at), randi(), at - world.maze.world(cell) - Vector3.UP * 0.05)
	Grass.push(enemy, 1.0)
	if frozen:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED


## Level, the way the camera looks.
func _look() -> Vector3:
	var look := -world.camera.global_basis.z
	look.y = 0.0
	return look.normalized() if look.length() > 0.01 else Vector3.FORWARD


## A point `reach` metres in front of him the way the camera looks, on the
## ground, brought back short of any wall in the way, so that it can be seen.
func _ahead(reach := AHEAD) -> Vector3:
	var from := world.player.global_position + Vector3.UP * 1.0
	var to := from + _look() * reach
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [world.player.get_rid()]))
	if not hit.is_empty():
		to = from + _look() * maxf((hit["position"] as Vector3).distance_to(from) - 3.0, 2.5)
	return Vector3(to.x, world.maze.ground_height(to) + 0.05, to.z)


## The way from `at` to him.
func _facing_him(at: Vector3) -> float:
	var to := world.player.global_position - at
	return atan2(to.x, to.z)


func _hunters() -> Array[Node]:
	var all: Array[Node] = []
	all.append_array(world.enemies.enemies)
	all.append(world.griever)
	all.append_array(_grievers)
	return all


# --- Moving him -------------------------------------------------------------

## In front of the next gate out of the clearing, each press the next one round.
func to_gate() -> void:
	var spot := world.gate_spot(_gate)
	_gate = (_gate + 1) % world.maze.gates[0].size()
	world.put_player(spot.origin, spot.basis.get_euler().y)


func to_middle() -> void:
	world.put_player(world.spawn(0, true), world.spawn_yaw(0, true))


## In the last cell before the way out, facing it.
func to_exit() -> void:
	var out := Vector3(world.maze.exit_side.x, 0.0, world.maze.exit_side.y)
	world.put_player(world.maze.world(world.maze.exit) - out * 3.0 + Vector3.UP * 0.05, atan2(out.x, out.z))


# ----------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_QUOTELEFT:
			toggle()
		KEY_G:
			toggle_god()
		KEY_M:
			spawn_mummy()
		KEY_N:
			spawn_snake()
		KEY_B:
			spawn_griever()
		_:
			return
	get_viewport().set_input_as_handled()


func _show() -> void:
	_god_button.text = "GOD: ON" if god else "GOD: OFF"
	_god_button.modulate = Color(0.75, 1.0, 0.7) if god else Color.WHITE
	_freeze_button.text = "UNFREEZE" if frozen else "FREEZE"
	_kind_button.text = String(Mummy.Kind.keys()[_kind])


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = STONE if state == "normal" or state == "focus" else STONE.lerp(MOSS, 0.4 if state == "pressed" else 0.2)
		box.border_color = MOSS.darkened(0.2)
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(pressed)
	return button
