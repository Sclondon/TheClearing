class_name DevTools
extends Control
## God mode for trying the maze out: a DEV button under the clock opens a panel
## docked down the left, as an editor's are:
## - a toolbar of switches, lit while on: GOD (nothing catches him), FLY (through
##   anything), FREEZE (what hunts stops), and CLEAR (takes it all away);
## - Spawn: everything that can be put in ahead of him (hunters, runners, animals,
##   loot), under headings, with a search: tap a row and one is put in;
## - Travel: a map of the whole maze (tap it and he is there; the wheel zooms on
##   him) and the places by name: the clearing, each ring, each desert quarter, the way out;
## - World: the time of day (a slider, and dawn, noon, dusk, night) and the weather;
## - along its foot, where he is and the frame rate.
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
	["PAIR", "flesh_pair", AHEAD], ["AMALGAM", "amalgam", AHEAD], ["STRIDER", "strider", AHEAD], ["BALL", "ball", SNAKE_AHEAD],
	["ABOMINATION", "flesh_mound", SNAKE_AHEAD],
	["HARPY", "harpy", AHEAD], ["BOAR", "boar", SNAKE_AHEAD], ["CHICKENS", "chickens", AHEAD],
	["CHICKENS (TAME)", "tame_chickens", AHEAD], ["GARGOYLE", "gargoyle", AHEAD],
	["DEER", "deer", SNAKE_AHEAD], ["ELK", "elk", SNAKE_AHEAD],
	["IMPS", "imps", AHEAD], ["IMP SWARM", "imp_swarm", AHEAD], ["COLOSSUS", "colossus", COLOSSUS_AHEAD],
	["COYOTES", "coyotes", SNAKE_AHEAD], ["SKINWALKER", "skinwalker", SNAKE_AHEAD],
	["TRIPOD", "tripod", SNAKE_AHEAD],
	["CROWS", "crows", AHEAD], ["RAVENS", "ravens", AHEAD], ["BLUE JAYS", "blue_jays", AHEAD],
	["CLOWN", "clown", SNAKE_AHEAD], ["STEGOSAURUS", "stegosaurus", SNAKE_AHEAD],
	["SPIDER MONKEYS", "spider_monkeys", AHEAD], ["LIZARD PEOPLE", "lizard_people", AHEAD],
	["MASKED TRIBE", "tribe", AHEAD], ["DEINONYCHUS", "deinonychus", SNAKE_AHEAD],
	["PTERODACTYL", "pterodactyl", AHEAD], ["SNAIL", "snail", SNAKE_AHEAD], ["HYDRA", "hydra", AHEAD],
	["GIBBONS", "gibbons", AHEAD], ["BEAR", "bear", SNAKE_AHEAD], ["BRACHIOSAURUS", "brachiosaurus", COLOSSUS_AHEAD],
	["DIMETRODON", "dimetrodon", AHEAD], ["GRIFFINFLIES", "griffinflies", AHEAD],
	["PSYCHIC CHILD", "psychic_child", AHEAD], ["LYNX", "lynx", AHEAD], ["PANTHER", "panther", SNAKE_AHEAD],
	["WOLVES", "wolves", SNAKE_AHEAD], ["FOXES", "foxes", AHEAD], ["FROGS (POND)", "pond_frogs", AHEAD],
	["RABBITS", "rabbits", AHEAD], ["HARES", "hares", AHEAD], ["JACKALOPE", "jackalope", AHEAD],
	["OCTOPUS", "octopus", AHEAD], ["OCTOPUS (DRAIN)", "octopus_drain", AHEAD],
	["MOOSE", "moose", SNAKE_AHEAD], ["MOOSE (COW, CALF)", "moose_family", SNAKE_AHEAD], ["MAMMOTHS", "mammoths", SNAKE_AHEAD],
	["FLYTRAP", "flytrap", AHEAD], ["SUNDEW", "sundew", AHEAD], ["PITCHER", "pitcher", AHEAD],
	["MUSHROOMS", "mushrooms", AHEAD], ["MUSHROOM ZOMBIES", "mushroom_zombies", AHEAD],
	["GNOMES", "gnomes", AHEAD], ["WEAVER", "weaver", AHEAD], ["ANTS", "ants", SNAKE_AHEAD], ["MANTIS", "mantis", AHEAD],
	["RATS", "rats", AHEAD], ["RAT SWARM", "rat_swarm", AHEAD], ["RAT KING", "rat_king", AHEAD],
	["LUCK DRAGON", "luck_dragon", COLOSSUS_AHEAD],
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

## The panel: docked down the left like an editor's, with a toolbar of switches,
## tabs (Spawn, Travel, World) and a status line along its foot.
## (in the HUD's units: it is laid out for 720 x 1280, so on a 1280 x 720 window a unit is
## a little over half a pixel)
const DOCK_WIDTH := 640.0
var _panel: PanelContainer
var _god_button: Button
var _freeze_button: Button
var _fly_button: Button
var _spawn_tree: Tree
var _search: LineEdit
var _travel_tree: Tree
var _map: DevMap
var _hour: HSlider
var _hour_label: Label
var _weather: OptionButton
var _status: Label
var _status_in := 0.0
var _open: Button
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
	_open = _button("DEV", toggle)
	var open := _open
	open.position = Vector2(16, 64)
	open.custom_minimum_size = Vector2(84, 48)
	add_child(open)

	_panel = PanelContainer.new()
	_panel.theme = _theme()
	_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_left = 8.0
	# (below the clock)
	_panel.offset_top = 72.0
	_panel.offset_bottom = -8.0
	_panel.offset_right = 8.0 + DOCK_WIDTH
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	# The title, and a way to shut it.
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "DEV TOOLS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", MOSS.lightened(0.25))
	header.add_child(title)
	var shut := _tool("X", toggle, "Close (`)")
	shut.toggle_mode = false
	header.add_child(shut)
	column.add_child(header)
	# The switches, lit while on.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	_god_button = _tool("GOD", toggle_god, "Nothing can catch him (G)")
	_fly_button = _tool("FLY", toggle_fly, "Fly where the camera looks, through anything: jump up, duck down, sprint fast (F)")
	_freeze_button = _tool("FREEZE", toggle_freeze, "Everything that hunts stops where it is")
	var wipe := _tool("CLEAR", clear, "Take away everything that hunts")
	wipe.toggle_mode = false
	for one: Button in [_god_button, _fly_button, _freeze_button, wipe]:
		one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(one)
	column.add_child(bar)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(_spawn_page())
	tabs.add_child(_travel_page())
	tabs.add_child(_world_page())
	column.add_child(tabs)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", INK.darkened(0.25))
	_status.clip_text = true
	column.add_child(_status)
	_show()


func toggle() -> void:
	_panel.visible = not _panel.visible
	# (the panel lies over the button: it is shut with its own X, or `)
	_open.visible = not _panel.visible
	# (fingers on the panel are not to move him or turn the camera)
	if world.touch:
		world.touch.set_process_input(not _panel.visible)
	_show()


func toggle_god() -> void:
	god = not god
	_show()


func toggle_freeze() -> void:
	frozen = not frozen
	for hunter in _hunters():
		hunter.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
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
		"flesh_pair":
			made = [_flesh(2)]
		"amalgam":
			made = [_flesh(3)]
		"ball":
			made = [_flesh(7)]
		"strider":
			made = [_flesh(5)]
		"flesh_mound":
			made = [_flesh(9)]
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
		"coyotes":
			made = MazeCoyote.pack_of(4, randi())
		"skinwalker":
			# (hidden among a pack of three, as in the maze: the second of the row is it)
			var pack_now := MazeCoyote.pack_of(3, randi())
			var walker := MazeSkinwalker.new()
			walker.pack_id = pack_now[0].pack_id
			made = [pack_now[0], walker, pack_now[1], pack_now[2]]
		"tripod":
			# (it stands over the hall ahead, its light on the ground in front of him)
			made = [MazeTripod.new()]
		"crows":
			made = [Crows.new()]
		"clown":
			made = [MazeClown.new()]
		"stegosaurus":
			# (a mother and her calf)
			made = MazeStegosaurus.family(1)
		"spider_monkeys":
			# (they string their vines along the walls nearest the first of them)
			made = MazeSpiderMonkey.troop(5)
		"lizard_people":
			# (each runs up the nearest wall ahead and waits there, head down)
			made = MazeLizardPerson.band(3)
		"tribe":
			made = MazeTribesman.party_of(4, randi())
		"deinonychus":
			made = MazeDeinonychus.pack_of(3, randi())
		"pterodactyl":
			# (it finds the nearest high wall top ahead to roost on, and soars from there)
			made = [MazePterodactyl.new()]
		"snail":
			made = [MazeSnail.new()]
		"hydra":
			# (it puts itself in the middle of the hall, its pool across it)
			made = [MazeHydra.new()]
		"gibbons":
			# (each finds its way up onto the ledges and wall tops near)
			made = MazeGibbon.troop(4)
		"bear":
			made = [MazeBear.new()]
		"brachiosaurus":
			made = [MazeBrachiosaurus.new()]
		"dimetrodon":
			made = [MazeDimetrodon.new()]
		"griffinflies":
			# (a pair, hunting the halls round where they are put)
			made = [MazeGriffinfly.new(), MazeGriffinfly.new()]
		"psychic_child":
			made = [MazePsychicChild.new()]
		"lynx":
			var lynx := MazeLynx.new()
			lynx.lie_up = false
			made = [lynx]
		"panther":
			var panther := MazePanther.new()
			panther.lie_up = false
			made = [panther]
		"wolves":
			# (a pack of five; its den is where its leader is put)
			made = MazeWolf.pack_of(5, randi())
		"foxes":
			made = MazeFox.pair_of(2, randi())
		"pond_frogs":
			made = [MazePondFrogs.new()]
		"rabbits":
			# (a warren and its colony where he is looking, its holes towards him)
			MazeRabbit.add_colony(world.enemies, at - Vector3.UP * 0.05, _facing_him(at), RabbitWarren.Kind.MOUND, 5, randi(), true)
			return
		"hares":
			# (a pair, that box now and then)
			MazeHare.add_hares(world.enemies, at - Vector3.UP * 0.05, true, randi(), true)
			return
		"jackalope":
			made = [MazeJackalope.new()]
		"octopus":
			made = [MazeOctopus.new()]
		"octopus_drain":
			var octopus := MazeOctopus.new()
			octopus.drain = true
			made = [octopus]
		"moose":
			var bull := MazeMoose.new()
			bull.rut = 1.0
			made = [bull]
		"moose_family":
			made = MazeMoose.family(randi())
		"mammoths":
			made = MazeMammoth.herd_of(4, randi())
		"flytrap":
			made = [MazeFlytrap.new()]
		"sundew":
			made = [MazeSundew.new()]
		"pitcher":
			made = [MazePitcher.new()]
		"mushrooms":
			made = [MazeMushrooms.new()]
		"mushroom_zombies":
			made = MazeMushroomZombie.horde_of(3, 0)
		"gnomes":
			made = MazeGnome.band_of(4)
		"weaver":
			made = [MazeWeaver.new()]
		"ants":
			# (its nest where it is put, its trail out from there along the passages)
			made = [MazeAnts.new()]
		"mantis":
			# (it takes its post against the nearest wall, among plants it brings)
			made = [MazeMantis.new()]
		"rats":
			made = MazeRat.mischief(5, randi())
		"rat_swarm":
			made = [MazeRatSwarm.new()]
		"rat_king":
			made = [MazeRatKing.new()]
		"luck_dragon":
			# (it rises over the walls ahead, and comes to him as soon as he stands still in the open)
			var dragon := MazeLuckDragon.new()
			dragon.still_time = 1.5
			dragon._visit_rest = 0.0
			made = [dragon]
		"ravens":
			# (wildlife: on the walls round where they are put, not among the hunters)
			world.birds.add_ravens_at(at)
			return
		"blue_jays":
			# (wildlife: in the trees near, or on the walls, or the ground)
			world.birds.add_jays_at(at)
			return
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
## Puts something to find (or a camp) down ahead of him (Loot.DEV).
func spawn_loot(what: String) -> void:
	if world.loot:
		world.loot.dev_drop(what)


## Puts a peaceful herd (Wildlife) in ahead of him, grazing.
func spawn_wildlife(kind: Wildlife.Kind) -> void:
	var at := _ahead(SNAKE_AHEAD)
	world.wildlife.add_herd(kind, at, world.maze.in_clearing(world.maze.cell_at(at)), randi())


## Puts insects in ahead of him (Insects.put): moths round a lantern, flies on a
## carcass, a patch of dragonflies.
func spawn_insects(kind: InsectLook.Kind) -> void:
	world.insects.put(kind, _ahead(7.0))


## Puts a cloud of fireflies a few metres ahead of him, out whatever the hour.
func spawn_fireflies() -> void:
	world.insects.put_fireflies(_ahead(7.0))


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
	# (the switches show what is on; the world page what the day and weather are)
	_god_button.set_pressed_no_signal(god)
	_fly_button.set_pressed_no_signal(flying)
	_freeze_button.set_pressed_no_signal(frozen)
	var forced: int = world.weather.forced if world.weather else -1
	_weather.select(forced + 1)
	if world.day:
		_hour.set_value_no_signal(world.day.hour)
		_hour_label.text = _clock(world.day.hour)


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


## A flesh mound of `count` bodies (a pair, an amalgam, a strider, or the big one).
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
## ones first, then the desert, then the round ones), facing out.
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
	if outer == null or ring - maze.rings - 1 > outer.rings.size():
		return
	if ring == maze.rings + 1:
		to_desert()
		return
	var round_ring: RoundMaze.Ring = outer.rings[ring - maze.rings - 2]
	# (in the middle of a cell of its middle row: a cell's middle is always open)
	var row: Array = round_ring.rows[round_ring.rows.size() / 2]
	var a := (RoundMaze.angle_of(0, row[2]) + RoundMaze.angle_of(1, row[2])) * 0.5
	var spot := RoundBuilder.at(a, (row[0] + row[1]) * 0.5)
	world.put_player(spot + Vector3.UP * 0.05, atan2(spot.x, spot.z))


## In quarter `q` of the desert ring (RoundMaze.doors: one door into each), a
## little way out from the square maze's way into it, facing on out.
func to_quarter(q: int) -> void:
	var outer: RoundMaze = world.maze.round_rings
	if outer == null or q >= outer.doors.size():
		return
	var spot := outer.doors[q] + outer.ways_in[q] * 40.0
	var at := Vector3(spot.x, 0.0, spot.y)
	at.y = world.maze.ground_height(at) + 0.1
	world.put_player(at, atan2(outer.ways_in[q].x, outer.ways_in[q].y))


## In the desert, a little way out from the square maze's way out, facing on out.
func to_desert() -> void:
	to_quarter(0)


# --- The panel's pages ------------------------------------------------------

## Kinds of the things put in (HUNTERS' kinds), by the heading they are listed under.
const HEADINGS := {
	"flesh_pair": "Flesh", "amalgam": "Flesh", "strider": "Flesh", "ball": "Flesh", "flesh_mound": "Flesh",
	"abomination": "Flesh", "slime": "Flesh",
	"crows": "Birds and bugs", "ravens": "Birds and bugs", "blue_jays": "Birds and bugs",
	"bats": "Birds and bugs", "beetles": "Birds and bugs",
	"tame_chickens": "Tame animals",
	"stegosaurus": "Prehistoric", "deinonychus": "Prehistoric", "pterodactyl": "Prehistoric",
	"brachiosaurus": "Prehistoric", "dimetrodon": "Prehistoric", "griffinflies": "Birds and bugs",
	"foxes": "Tame animals", "pond_frogs": "Tame animals", "rabbits": "Tame animals", "hares": "Tame animals",
	"jackalope": "Tame animals", "lynx": "Big cats", "panther": "Big cats",
	"spider_monkeys": "Apes and monkeys", "gibbons": "Apes and monkeys", "baboons": "Apes and monkeys",
}


## Spawn: everything that can be put in ahead of him, under headings, with a
## search; a tap on a row puts one in.
func _spawn_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Spawn"
	_search = LineEdit.new()
	_search.placeholder_text = "Search..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(_filter)
	page.add_child(_search)
	_spawn_tree = _tree()
	page.add_child(_spawn_tree)
	var top := _spawn_tree.create_item()
	var headings := {}
	var under := func(heading: String) -> TreeItem:
		if not headings.has(heading):
			var item := _spawn_tree.create_item(top)
			item.set_text(0, heading)
			item.set_selectable(0, false)
			item.set_custom_color(0, MOSS.lightened(0.2))
			headings[heading] = item
		return headings[heading]
	var row := func(heading: String, text: String, action: Callable) -> void:
		var item := _spawn_tree.create_item(under.call(heading))
		item.set_text(0, text)
		item.set_metadata(0, action)
	for kind in Mummy.Kind.size():
		var named := String(Mummy.Kind.keys()[kind]).capitalize()
		row.call("Mummies", "Mummy: " + named, _spawn_mummy_kind.bind(kind, false))
	for kind in Mummy.Kind.size():
		var named := String(Mummy.Kind.keys()[kind]).capitalize()
		row.call("Mummies", "Pack led by a " + named.to_lower(), _spawn_mummy_kind.bind(kind, true))
	row.call("Hunters", "Snake (Apophis)", spawn_snake)
	row.call("Hunters", "Griever", spawn_griever)
	for one: Array in HUNTERS:
		row.call(HEADINGS.get(one[1], "Hunters"), String(one[0]).capitalize(), spawn_hunter.bind(one[1], one[2]))
	for one: Array in WILDLIFE:
		row.call("Tame animals", String(one[0]).capitalize(), spawn_wildlife.bind(one[1]))
	for one: Array in [["Moths", InsectLook.Kind.MOTH], ["Flies", InsectLook.Kind.FLY], ["Dragonflies", InsectLook.Kind.DRAGONFLY]]:
		row.call("Birds and bugs", one[0], spawn_insects.bind(one[1]))
	row.call("Birds and bugs", "Fireflies", spawn_fireflies)
	row.call("Runners", "Runner", spawn_runner)
	row.call("Runners", "Three runners", spawn_runners)
	for one: Array in Loot.DEV:
		row.call("Loot and camps", String(one[0]).trim_prefix("+ ").capitalize(), spawn_loot.bind(one[1]))
	_spawn_tree.item_selected.connect(_picked.bind(_spawn_tree))
	return page


## Travel: the map (tap to go there) and the places by name.
func _travel_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "Travel"
	_map = DevMap.new(self)
	page.add_child(_map)
	_travel_tree = _tree()
	page.add_child(_travel_tree)
	var top := _travel_tree.create_item()
	var maze: Maze = world.maze
	var outer: RoundMaze = maze.round_rings
	var group := func(text: String) -> TreeItem:
		var item := _travel_tree.create_item(top)
		item.set_text(0, text)
		item.set_selectable(0, false)
		item.set_custom_color(0, MOSS.lightened(0.2))
		return item
	var place := func(under: TreeItem, text: String, action: Callable) -> void:
		var item := _travel_tree.create_item(under)
		item.set_text(0, text)
		item.set_metadata(0, action)
	var clearing: TreeItem = group.call("Clearing")
	place.call(clearing, "Middle", to_middle)
	place.call(clearing, "In front of the next gate", to_gate)
	var square: TreeItem = group.call("Square sections")
	for ring in range(1, maze.rings + 1):
		place.call(square, "Ring %d" % ring, to_ring.bind(ring))
	if outer:
		var desert: TreeItem = group.call("Desert ring (ring %d)" % (maze.rings + 1))
		for q in outer.doors.size():
			var quarter := DesertStyle.quarter_at(outer.doors[q].x, outer.doors[q].y)
			var side: String = {Vector2i(0, -1): "N", Vector2i(1, 0): "E", Vector2i(0, 1): "S", Vector2i(-1, 0): "W"}[quarter]
			var biome := String(DesertStyle.Biome.keys()[outer.desert.biome_of(quarter)]).capitalize()
			place.call(desert, "%s quarter (%s)" % [biome, side], to_quarter.bind(q))
		if not outer.rings.is_empty():
			var round: TreeItem = group.call("Round sections")
			for k in outer.rings.size():
				var ring := maze.rings + 2 + k
				place.call(round, "Ring %d" % ring, to_ring.bind(ring))
	place.call(group.call("Out"), "The way out", to_exit)
	_travel_tree.item_selected.connect(_picked.bind(_travel_tree))
	return page


## World: the time of day and the weather.
func _world_page() -> Control:
	var page := VBoxContainer.new()
	page.name = "World"
	page.add_theme_constant_override("separation", 8)
	var time := HBoxContainer.new()
	var heading := Label.new()
	heading.text = "Time of day"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time.add_child(heading)
	_hour_label = Label.new()
	time.add_child(_hour_label)
	page.add_child(time)
	_hour = HSlider.new()
	_hour.min_value = 0.0
	_hour.max_value = 24.0
	_hour.step = 0.25
	_hour.custom_minimum_size.y = 56.0
	_hour.value_changed.connect(func(value: float) -> void:
		to_hour(value)
		_hour_label.text = _clock(value))
	page.add_child(_hour)
	var jumps := HBoxContainer.new()
	for one: Array in [["Dawn", DayCycle.DAWN - 0.4], ["Noon", 12.0], ["Dusk", DayCycle.SUNSET - 0.4], ["Night", 0.0]]:
		var jump := _tool(one[0], func() -> void:
			to_hour(one[1])
			_show(), "On to %s" % _clock(one[1]))
		jump.toggle_mode = false
		jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jumps.add_child(jump)
	page.add_child(jumps)
	var heading_weather := Label.new()
	heading_weather.text = "Weather"
	page.add_child(heading_weather)
	_weather = OptionButton.new()
	_weather.add_item("As the spells have it")
	for kind in Weather.Kind.size():
		_weather.add_item(String(Weather.Kind.keys()[kind]).capitalize())
	_weather.item_selected.connect(func(index: int) -> void:
		if world.weather:
			world.weather.forced = index - 1)
	page.add_child(_weather)
	return page


## A row picked in the spawn or travel list: done, and let go again, so that the
## same row can be tapped again at once.
func _picked(tree: Tree) -> void:
	var item := tree.get_selected()
	if item == null:
		return
	var action: Variant = item.get_metadata(0)
	if action is Callable:
		(action as Callable).call()
		_status.text = "%s: %s" % ["Put in" if tree == _spawn_tree else "Went to", item.get_text(0)]
		_status_in = 1.5
	tree.deselect_all.call_deferred()


## Only the rows whose names have `text` in them (the headings with any such rows, open).
func _filter(text: String) -> void:
	var wanted := text.strip_edges().to_lower()
	var heading := _spawn_tree.get_root().get_first_child()
	while heading:
		var any := false
		var item := heading.get_first_child()
		while item:
			var shown := wanted == "" or item.get_text(0).to_lower().contains(wanted)
			item.visible = shown
			any = any or shown
			item = item.get_next()
		heading.visible = any
		if wanted != "":
			heading.collapsed = false
		heading = heading.get_next()


## A mummy of `kind`, alone or leading a pack.
func _spawn_mummy_kind(kind: int, pack: bool) -> void:
	_kind = kind
	if pack:
		spawn_pack()
	else:
		spawn_mummy()


## Puts him at a place on the ground (x, z) from the map: in the square maze, in
## the middle of the nearest cell he could stand in (not inside a rampart).
func travel_to(at: Vector2) -> void:
	var maze: Maze = world.maze
	var spot := Vector3(at.x, 0.0, at.y)
	var cell := maze.cell_at(spot)
	if maze.inside(cell) and not maze.in_clearing(cell):
		var best := cell
		var nearest := INF
		for y in range(cell.y - 6, cell.y + 7):
			for x in range(cell.x - 6, cell.x + 7):
				var other := Vector2i(x, y)
				if maze.inside(other) and not maze.solid.has(other) and Vector2(other - cell).length() < nearest:
					nearest = Vector2(other - cell).length()
					best = other
		spot = maze.world(best)
	spot.y = maze.ground_height(spot) + 0.1
	world.put_player(spot, world.player.facing_yaw)
	_status.text = "Went to %.0f, %.0f" % [spot.x, spot.z]
	_status_in = 1.5


func _process(delta: float) -> void:
	if not _panel.visible or world.player == null:
		return
	_status_in -= delta
	if _status_in > 0.0:
		return
	_status_in = 0.25
	var at: Vector3 = world.player.global_position
	_status.text = "%.0f, %.0f, %.0f   %s   %d fps" % [at.x, at.y, at.z, _where(at), Engine.get_frames_per_second()]
	if world.day and not _hour.has_focus():
		_hour.set_value_no_signal(world.day.hour)
		_hour_label.text = _clock(world.day.hour)


## Which part of the maze a place is in, by name.
func _where(at: Vector3) -> String:
	var maze: Maze = world.maze
	var outer: RoundMaze = maze.round_rings
	var cell := maze.cell_at(at)
	if maze.inside(cell):
		return "the clearing" if maze.in_clearing(cell) else "ring %d" % maze.ring_of(cell)
	if outer == null:
		return "out"
	var out := Vector2(at.x, at.z).length()
	if out < outer.inner_radius:
		return "%s quarter" % String(DesertStyle.Biome.keys()[outer.desert.biome_at(at.x, at.z)]).to_lower()
	for k in outer.rings.size():
		if out < outer.rings[k].outer:
			return "ring %d" % (maze.rings + 2 + k)
	return "out"


static func _clock(hour: float) -> String:
	return "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]


## A list in the panel: rows under headings, no root shown.
func _tree() -> Tree:
	var tree := Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.focus_mode = Control.FOCUS_NONE
	tree.select_mode = Tree.SELECT_ROW
	return tree


## A toolbar switch (lit while pressed), with what it does on hovering.
func _tool(text: String, pressed: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 64)
	button.pressed.connect(pressed)
	return button


## The panel's look: dark stone, moss edges, the game's typewriter face, small.
func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 26
	var box := func(fill: Color, edge: Color, width := 2, margin := 10.0) -> StyleBoxFlat:
		var made := StyleBoxFlat.new()
		made.bg_color = fill
		made.border_color = edge
		made.set_border_width_all(width)
		made.set_corner_radius_all(3)
		made.set_content_margin_all(margin)
		return made
	var edge := MOSS.darkened(0.35)
	var well := Color(0.06, 0.07, 0.06, 0.9)
	var clear := Color(0, 0, 0, 0)
	theme.set_stylebox(&"panel", &"PanelContainer", box.call(STONE, edge, 3, 16.0))
	for state: StringName in [&"normal", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"Button", box.call(STONE.lightened(0.05), edge))
	theme.set_stylebox(&"hover", &"Button", box.call(STONE.lerp(MOSS, 0.2), edge))
	theme.set_stylebox(&"pressed", &"Button", box.call(STONE.lerp(MOSS, 0.55), MOSS))
	theme.set_stylebox(&"hover_pressed", &"Button", box.call(STONE.lerp(MOSS, 0.65), MOSS))
	for colour: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		theme.set_color(colour, &"Button", INK)
	for colour: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
		theme.set_color(colour, &"Button", Color.WHITE)
	theme.set_color(&"font_color", &"Label", INK)
	theme.set_stylebox(&"panel", &"Tree", box.call(well, edge, 2, 8.0))
	theme.set_stylebox(&"focus", &"Tree", box.call(clear, clear, 0))
	theme.set_stylebox(&"selected", &"Tree", box.call(STONE.lerp(MOSS, 0.5), MOSS))
	theme.set_stylebox(&"selected_focus", &"Tree", box.call(STONE.lerp(MOSS, 0.5), MOSS))
	theme.set_stylebox(&"hovered", &"Tree", box.call(STONE.lerp(MOSS, 0.2), clear, 0))
	theme.set_color(&"font_color", &"Tree", INK)
	theme.set_color(&"font_hovered_color", &"Tree", Color.WHITE)
	theme.set_constant(&"v_separation", &"Tree", 14)
	theme.set_constant(&"item_margin", &"Tree", 26)
	theme.set_stylebox(&"panel", &"TabContainer", box.call(clear, clear, 0, 6.0))
	theme.set_stylebox(&"tab_selected", &"TabContainer", box.call(STONE.lerp(MOSS, 0.45), MOSS, 2, 14.0))
	theme.set_stylebox(&"tab_unselected", &"TabContainer", box.call(STONE, edge, 2, 14.0))
	theme.set_stylebox(&"tab_hovered", &"TabContainer", box.call(STONE.lerp(MOSS, 0.25), edge, 2, 14.0))
	theme.set_color(&"font_selected_color", &"TabContainer", Color.WHITE)
	theme.set_color(&"font_unselected_color", &"TabContainer", INK.darkened(0.2))
	theme.set_color(&"font_hovered_color", &"TabContainer", INK)
	theme.set_stylebox(&"normal", &"LineEdit", box.call(well, edge))
	theme.set_stylebox(&"focus", &"LineEdit", box.call(well, MOSS))
	theme.set_color(&"font_color", &"LineEdit", INK)
	theme.set_stylebox(&"normal", &"OptionButton", box.call(STONE.lightened(0.05), edge))
	theme.set_stylebox(&"hover", &"OptionButton", box.call(STONE.lerp(MOSS, 0.2), edge))
	theme.set_stylebox(&"pressed", &"OptionButton", box.call(STONE.lerp(MOSS, 0.4), MOSS))
	theme.set_color(&"font_color", &"OptionButton", INK)
	theme.set_stylebox(&"slider", &"HSlider", box.call(well, edge, 2, 6.0))
	theme.set_stylebox(&"grabber_area", &"HSlider", box.call(MOSS.darkened(0.2), MOSS, 2, 6.0))
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", box.call(MOSS, MOSS, 2, 6.0))
	theme.set_stylebox(&"panel", &"TooltipPanel", box.call(STONE, MOSS))
	theme.set_color(&"font_color", &"TooltipLabel", INK)
	theme.set_stylebox(&"panel", &"PopupMenu", box.call(STONE, MOSS))
	theme.set_color(&"font_color", &"PopupMenu", INK)
	theme.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	theme.set_stylebox(&"hover", &"PopupMenu", box.call(STONE.lerp(MOSS, 0.4), clear, 0))
	return theme
