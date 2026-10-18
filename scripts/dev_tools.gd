class_name DevTools
extends Control
## God mode for trying the maze out: a DEV button under the clock opens a panel
## that puts things that hunt (and runners, MazeRunner) into the maze ahead of
## the boy, clears or stops them, makes him uncatchable or lets him fly anywhere,
## and moves him to a gate,
## the middle, any ring, the desert or the exit.
## Keys: ` opens it, G god, F fly, M a mummy, N the snake, B a Griever.
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
## The colossus crawls over the maze: far off, out over the walls, not brought short of them.
const COLOSSUS_AHEAD := 80.0
## The other kinds the panel puts in (spawn_hunter): the button, the kind, and
## how far ahead (the big ones further off, like the snake).
const HUNTERS := [
	["GHOUL", "ghoul", AHEAD], ["CENTIPEDE", "centipede", SNAKE_AHEAD], ["SPIDER", "spider", AHEAD],
	["MEAT BEAST", "abomination", SNAKE_AHEAD], ["SLIME WALL", "slime", SNAKE_AHEAD], ["BATS", "bats", AHEAD],
	["BABOONS", "baboons", AHEAD], ["DOGS", "dogs", AHEAD], ["ALIENS", "aliens", AHEAD],
	["BEETLES", "beetles", AHEAD], ["FISH PERSON", "fish_person", AHEAD], ["ANGEL", "angel", SNAKE_AHEAD],
	["FROG", "frog", AHEAD], ["FROG SWARM", "frog_swarm", AHEAD],
	["AMALGAM", "amalgam", AHEAD], ["ABOMINATION", "flesh_mound", SNAKE_AHEAD],
	["HARPY", "harpy", AHEAD], ["BOAR", "boar", SNAKE_AHEAD], ["CHICKENS", "chickens", AHEAD],
	["CHICKENS (TAME)", "tame_chickens", AHEAD], ["GARGOYLE", "gargoyle", AHEAD],
	["DEER", "deer", SNAKE_AHEAD], ["ELK", "elk", SNAKE_AHEAD],
	["IMPS", "imps", AHEAD], ["IMP SWARM", "imp_swarm", AHEAD], ["COLOSSUS", "colossus", COLOSSUS_AHEAD],
]
## The peaceful animals the panel puts in (spawn_wildlife): the button and the kind.
const WILDLIFE := [
	["DEER (TAME)", Wildlife.Kind.DEER], ["ELK (TAME)", Wildlife.Kind.ELK],
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
var _weather_button: Button
var _fly_button: Button
var _scroll: ScrollContainer
## He flies where he looks, through anything (FLY, or F): move to go, jump to
## rise, duck to sink, sprint to go fast.
var flying := false
var _layers := 0
var _mask := 0
const FLY_SPEED := 22.0
const FLY_FAST := 6.0
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
	# (scrolled, when there are more buttons than fit the window's height)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 560)
	_panel.add_child(_scroll)
	_scroll.add_child(grid)
	_god_button = _button("", toggle_god)
	grid.add_child(_god_button)
	_fly_button = _button("", toggle_fly)
	grid.add_child(_fly_button)
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
	grid.add_child(_button("+ RUNNER", spawn_runner))
	grid.add_child(_button("+ RUNNERS", spawn_runners))
	for one: Array in WILDLIFE:
		grid.add_child(_button("+ " + String(one[0]), spawn_wildlife.bind(one[1])))
	grid.add_child(_button("CLEAR ALL", clear))
	grid.add_child(_button("TO GATE", to_gate))
	grid.add_child(_button("TO MIDDLE", to_middle))
	grid.add_child(_button("TO EXIT", to_exit))
	for ring in range(1, world.ring_count() + 1):
		grid.add_child(_button("TO RING %d" % ring, to_ring.bind(ring)))
	if world.maze.round_rings:
		grid.add_child(_button("TO DESERT", to_desert))
	grid.add_child(_button("TO DUSK", to_hour.bind(DayCycle.SUNSET - 0.4)))
	grid.add_child(_button("TO DAWN", to_hour.bind(DayCycle.DAWN - 0.4)))
	_weather_button = _button("", next_weather)
	grid.add_child(_weather_button)
	grid.add_child(_button("CLOSE", toggle))
	_show()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_scroll.custom_minimum_size.y = maxf(get_viewport_rect().size.y - 150.0, 200.0)
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
	var at := _ahead(reach) if kind != "colossus" else _out_ahead(reach)
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
		"amalgam":
			made = [_flesh(3)]
		"flesh_mound":
			made = [_flesh(8)]
		"aliens":
			made = [Alien.new(), Alien.new()]
		"beetles":
			made = [Beetles.new()]
		"fish_person":
			made = [MazeFishPerson.new()]
		"angel":
			made = [MazeAngel.new()]
		"frog":
			made = [MazeFrog.new()]
		"frog_swarm":
			made = [MazeFrogSwarm.new()]
		"harpy":
			# (it flies up to the nearest high wall ahead and perches there)
			made = [MazeHarpy.new()]
		"boar":
			made = [MazeBoar.new()]
		"chickens":
			made = [Chickens.new()]
		"gargoyle":
			# (crouched on the ground as a statue where it is put, so that it is seen:
			# it wakes as he comes near)
			var gargoyle := MazeGargoyle.new()
			gargoyle.seek_perch = false
			made = [gargoyle]
		"deer":
			made = MazeDeer.herd_of(5, randi())
		"elk":
			made = [MazeElk.new()]
		"tame_chickens":
			# (wildlife, not a hunter: put in beside the rest, not among them)
			var flock := TameChickens.new(world.maze, randi())
			flock.position = at
			world.add_child(flock)
			world.tame_chickens.append(flock)
			return
		"imps":
			made = MazeImp.gang(4)
		"imp_swarm":
			made = [MazeImpSwarm.new()]
		"colossus":
			made = [MazeColossus.new()]
	for k in made.size():
		_add(made[k], at + across * (k - (made.size() - 1) * 0.5))


## Puts a runner (MazeRunner) in ahead of him, facing away and jogging on, in
## whichever section that is (the first, from the clearing). Come up to him and
## he leads you to its gate.
func spawn_runner() -> MazeRunner:
	return _add_runner(_ahead(), 0.0)


## Three runners ahead of him, side by side across his way.
func spawn_runners() -> void:
	var at := _ahead()
	var across := _look().cross(Vector3.UP) * 2.2
	for k in 3:
		_add_runner(at + across * (k - 1), 0.0)


func _add_runner(at: Vector3, turn: float) -> MazeRunner:
	var ring := clampi(world.maze.ring_of(world.maze.cell_at(at)), 1, world.maze.rings)
	return world.runners.add(ring, at - Vector3.UP * 0.05, _facing_him(at) + PI + turn, randi())
## Puts a peaceful herd (Wildlife) in ahead of him, grazing.
func spawn_wildlife(kind: Wildlife.Kind) -> void:
	var at := _ahead(SNAKE_AHEAD)
	world.wildlife.add_herd(kind, at, world.maze.in_clearing(world.maze.cell_at(at)), randi())


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


## A point `reach` metres in front of him the way the camera looks, on the
## ground, walls or no walls (for what stands over them).
func _out_ahead(reach: float) -> Vector3:
	var to := world.player.global_position + _look() * reach
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
	var outer: RoundMaze = world.maze.round_rings
	if outer:
		# (in the last cell before the way out of the last circle, facing it)
		var a := outer.exit_angle
		var out_way := Vector3(cos(a), 0.0, sin(a))
		world.put_player(out_way * (outer.outermost() - Maze.CELL * 0.5) + Vector3.UP * 0.05, atan2(out_way.x, out_way.z))
		return
	var out := Vector3(world.maze.exit_side.x, 0.0, world.maze.exit_side.y)
	world.put_player(world.maze.world(world.maze.exit) - out * 3.0 + Vector3.UP * 0.05, atan2(out.x, out.z))


## The weather: as the spells have it, or always overcast, cloudy or raining.
func next_weather() -> void:
	if world.weather:
		world.weather.forced = world.weather.forced + 1 if world.weather.forced < Weather.Kind.RAIN else -1
	_show()


## On to `hour` o'clock (a little before sunset, or dawn, to see the gates go).
func to_hour(hour: float) -> void:
	if world.day:
		world.day.set_hour(hour)


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
		KEY_F:
			toggle_fly()
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
	_fly_button.text = "FLY: ON" if flying else "FLY: OFF"
	_fly_button.modulate = Color(0.75, 1.0, 0.7) if flying else Color.WHITE
	_god_button.modulate = Color(0.75, 1.0, 0.7) if god else Color.WHITE
	_freeze_button.text = "UNFREEZE" if frozen else "FREEZE"
	_kind_button.text = String(Mummy.Kind.keys()[_kind])
	var forced: int = world.weather.forced if world.weather else -1
	_weather_button.text = "WEATHER: " + ("SPELLS" if forced < 0 else String(Weather.Kind.keys()[forced]))


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


## A flesh mound of `count` bodies (an amalgam, small; or the big one).
func _flesh(count: int) -> MazeFleshMound:
	var mound := MazeFleshMound.new()
	mound.bodies = count
	return mound


## Flying, or back to walking where he is.
func toggle_fly() -> void:
	var player = world.player
	flying = not flying
	if flying:
		if player.state == player.State.LADDER:
			player._leave_ladder()
		elif player.state == player.State.ROPE:
			player._leave_rope()
		# (through walls and all: nothing to bump into)
		_layers = player.collision_layer
		_mask = player.collision_mask
		player.collision_layer = 0
		player.collision_mask = 0
	else:
		player.collision_layer = _layers
		player.collision_mask = _mask
	player.velocity = Vector3.ZERO
	player.set_physics_process(not flying)
	_show()


func _physics_process(delta: float) -> void:
	if not flying or world.player == null:
		return
	var basis: Basis = world.camera.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	right.y = 0.0
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
	var way := forward * stick.y + right.normalized() * stick.x
	if Input.is_action_pressed(&"jump"):
		way += Vector3.UP
	if Input.is_action_pressed(&"duck"):
		way += Vector3.DOWN
	var speed := FLY_SPEED * (FLY_FAST if Input.is_action_pressed(&"sprint") else 1.0)
	world.player.global_position += way.limit_length(1.0) * speed * delta
	if way.length_squared() > 0.01:
		world.player.facing_yaw = atan2(forward.x, forward.z)


## Somewhere open in ring `ring` (counting out from the clearing, the square
## ones first, then the round ones), facing out.
func to_ring(ring: int) -> void:
	var maze: Maze = world.maze
	if ring <= maze.rings:
		# (the open cell of that ring nearest the line out from the middle to the east)
		var best := Vector2i(-1, -1)
		var best_off := INF
		for i in maze.size * maze.size:
			var cell := Vector2i(i % maze.size, i / maze.size)
			if maze.ring_of(cell) != ring or maze.solid.has(cell) or maze.entrances.has(cell):
				continue
			var at := maze.world(cell)
			var off := absf(at.z) + (0.0 if at.x > 0.0 else 100000.0)
			if off < best_off:
				best_off = off
				best = cell
		if best.x >= 0:
			world.put_player(maze.world(best) + Vector3.UP * 0.05, PI * 0.5)
		return
	var outer: RoundMaze = maze.round_rings
	if outer == null or ring - maze.rings > outer.rings.size():
		return
	var round_ring: RoundMaze.Ring = outer.rings[ring - maze.rings - 1]
	# (in the middle of a cell of its middle row: a cell's middle is always open)
	var row: Array = round_ring.rows[round_ring.rows.size() / 2]
	var a := (RoundMaze.angle_of(0, row[2]) + RoundMaze.angle_of(1, row[2])) * 0.5
	var spot := RoundBuilder.at(a, (row[0] + row[1]) * 0.5)
	world.put_player(spot + Vector3.UP * 0.05, atan2(spot.x, spot.z))


## In the desert, a little way out from the square maze's way out, facing on out.
func to_desert() -> void:
	var outer: RoundMaze = world.maze.round_rings
	if outer == null:
		return
	var spot := outer.door + outer.way_in * 40.0
	var at := Vector3(spot.x, 0.0, spot.y)
	at.y = world.maze.ground_height(at) + 0.1
	world.put_player(at, atan2(outer.way_in.x, outer.way_in.y))
