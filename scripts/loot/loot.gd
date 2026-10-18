class_name Loot
extends Node3D
## What lies about the clearing and the maze, and the camps (DESIGN.md: "What
## lies about", "Camps"): placed from the round's seed by the rules in
## ClearingStyle and MazeStyle ("What lies about"), so everyone in a room finds
## the same things in the same places; this player's inventory; and keeping
## everyone's copies in step.
##
## TAKING. The act button (Player.act_first) near something lying about stoops
## for it and puts it in the inventory: two slots, four with a backpack on (a
## backpack is worn as soon as it is taken, Worn). Online, only the room's maker
## says who gets what (a guest asks, K_JSON {"loot": "take"}); it is gone for
## everyone the moment it is given ("got").
##
## USING. A tool for the hand (hook, spear, torch, flare) is taken into it from
## its slot (and put back the same way: tap the slot, its number key, or Y on a
## pad), and the act button uses it as the Player uses anything in his hand: the
## hook is thrown at a ledge's lip and climbed, the spear and the flare are
## thrown, the torch lights a campfire it is held to (or is lit again at one). A
## map scrap is read and a rope ladder hung from the slot itself. With anything
## in his hand he cannot take hold of ivy or a vine: it is put away for him when
## he walks into ivy. DROP (or X) puts down what is in his hand.
##
## FIGHTING BACK (DESIGN.md: "Fighting back"). A stick, a bat or a sword is held
## as a bat is (Player swings it with the act button; `swing_hits` sees what it
## meets as it comes round: a stagger and a shove, its own; a stick or a bat
## wears and breaks). A revolver or a shotgun is fired (Player._fire calls
## LootItem.fire, which comes to `gun_fire`): `shoot` finds what it hits, which is
## felled (Stagger.fell) or staggered; `noise` brings what hunts to it. Rounds
## left in a gun go with it (LootItem.uses); boxes of rounds go loose into
## `ammo` and load an empty gun (`_reload`). How rare each is is the sections'
## rules (`_roll`, `_arm`, `maze_mix`).
##
## In the room: who has what in their hand, what is dropped or thrown (and where
## it comes to rest), torches lit and out, camps lit, ladders hung and things
## used up are all told to everyone (K_JSON {"loot": ...}), passed on by the
## host as the rest of the room's news is. A spear's stagger and a flare's lure
## work where the hunters are run (alone, or on the host): a guest's spear asks
## the host to stagger what it hit. So do a guest's blows and shots; a swing and
## a shot are seen (and a shot heard) by everyone ("swing", "shot"), and a hunter
## felled is felled on every copy ("felled", from the host).

## Said to the HUD: the inventory or what is in reach has changed.
signal changed
## A line for the HUD to show for a moment.
signal said(text: String)
## A map scrap is being read: the HUD shows it.
signal map_read(seconds: float)

const SLOTS := 2
const PACK_SLOTS := 4
## How near (over the ground) something must be to take it, and how far above or below.
const REACH := 1.35
const REACH_UP := 1.2
## How near a campfire a torch must be held to light it, or be lit at it.
const CAMP_REACH := 2.6
## A thrown spear staggers a hunter it passes this near.
const SPEAR_HITS := 1.5
## A flare draws hunters this near to it, metres, and anew every so often while it burns.
const LURE_RANGE := 45.0
const LURE_EVERY := 3.0
## How long a map scrap is read for, seconds.
const MAP_SECONDS := 9.0
## A rope ladder hangs from an edge with a drop of between these, metres.
const LADDER_DROP := Vector2(2.4, 16.0)
## The dev panel's buttons: what it puts in ahead of him.
const DEV := [
	["+ HOOK", "hook"], ["+ BACKPACK", "backpack"], ["+ SPEAR", "spear"], ["+ TORCH", "torch"], ["+ FLARE", "flare"],
	["+ MAP", "map"], ["+ LADDER", "ladder"], ["+ STICK", "stick"], ["+ BAT", "bat"], ["+ SWORD", "sword"],
	["+ REVOLVER", "revolver"], ["+ SHOTGUN", "shotgun"], ["+ ROUNDS", "rounds"], ["+ SHELLS", "shells"],
	["+ CAMP", "camp"], ["+ CAMP (LIT)", "camp_lit"],
]
const DEV_KINDS := {
	"hook": LootItem.Kind.HOOK, "backpack": LootItem.Kind.BACKPACK, "spear": LootItem.Kind.SPEAR,
	"torch": LootItem.Kind.TORCH, "flare": LootItem.Kind.FLARE, "map": LootItem.Kind.MAP, "ladder": LootItem.Kind.LADDER,
	"stick": LootItem.Kind.STICK, "bat": LootItem.Kind.BAT, "sword": LootItem.Kind.SWORD,
	"revolver": LootItem.Kind.REVOLVER, "shotgun": LootItem.Kind.SHOTGUN, "rounds": LootItem.Kind.ROUNDS,
	"shells": LootItem.Kind.SHELLS,
}
## What a camp left behind has lying by it, and what is lying in the maze's
## halls, by how likely each is (kind, weight). The maze's weapons are weighed
## in by each section's style (MazeStyle: stick, bat and sword weights), and
## guns and boxes of rounds by its chances (`_roll`).
const CAMP_MIX := [[LootItem.Kind.TORCH, 3], [LootItem.Kind.FLARE, 2], [LootItem.Kind.MAP, 2], [LootItem.Kind.SPEAR, 2],
	[LootItem.Kind.LADDER, 1], [LootItem.Kind.HOOK, 1], [LootItem.Kind.STICK, 2], [LootItem.Kind.BAT, 1]]
const MAZE_MIX := [[LootItem.Kind.FLARE, 3], [LootItem.Kind.MAP, 3], [LootItem.Kind.TORCH, 2], [LootItem.Kind.SPEAR, 2],
	[LootItem.Kind.HOOK, 1], [LootItem.Kind.LADDER, 1], [LootItem.Kind.BACKPACK, 1]]
## A shot is heard by what hunts this near, metres (it goes to see), and who fired
## it is known to what hunts this near (it goes after them).
const SHOT_HEARD := 90.0
const SHOT_KNOWN := 40.0
## What a shot does to what it does not fell (out of a gun's `fells` reach, or too
## big for a bullet): a long stagger.
const SHOT_SECONDS := 5.0
const SHOT_SHOVE := 1.8
## What a bullet does not fell, only staggers: the great and the unnatural. (By
## class name; the swarms, MazeEnemy.fears_fire, are not hit at all.)
const BULLETPROOF := [&"Apophis", &"MazeColossus", &"MazeTripod", &"MazeAngel", &"MazeGargoyle", &"MazeSlimeWall",
	&"MazeFleshMound", &"Abomination", &"Centipede", &"MazeSkinwalker", &"Griever"]
## With something to fight with in his hand, the act button fights (not takes
## what lies at his feet) when anything that hunts is this near.
const FIGHT_NEAR := 7.0

## Where in the clearing something is put.
enum Region { WOODS, TALL_GRASS, POND, FIELD }

var world: World
var maze: Maze
## Everything there is to find, by its number (the same on every copy).
var items := {}
var camps: Array[Campsite] = []
var campers: Array[Camper] = []
var ladders: Array[RopeLadder] = []
## This player's inventory: an item's number in each slot, -1 for none.
var slots: Array[int] = []
## The number of what is in his hand (one of his slots), or -1.
var hand := -1
## Whether he wears a backpack.
var pack := false
## His spare rounds, by the kind of box (LootItem.Kind.ROUNDS, SHELLS): taken from
## boxes found, loaded into a gun when it is empty. They take no slot.
var ammo := {LootItem.Kind.ROUNDS: 0, LootItem.Kind.SHELLS: 0}
## Seconds left loading the gun in his hand (0: not).
var reloading := 0.0
## What is in reach to take now (for the HUD's prompt), or null.
var in_reach: Node3D

## Who has each thing, by its number: the seat, or -1. (Kept by everyone; the
## host's is the one that counts.)
var owners := {}

var _next := 0
var _stowing := false
var _dropping := false
var _look_in := 0.0
var _ivy_in := 0.0
var _pending := {}
var _thrown := {}
var _lures := {}
var _base_speeds := Vector2.ZERO
var _base_swing := 0.6
var _swing_was := 1.0
var _reload_item: Node3D
var _rng := RandomNumberGenerator.new()
## (x, z) circles where the grass is trodden down, by 10 m square: [middle, radius].
var _trodden := {}


## Puts in what lies about for a round of `seed_value` into `in_world`, its
## inventory on `hud_layer`, and sits the campers down.
static func put(in_world: World, seed_value: int, hud_layer: CanvasLayer) -> Loot:
	var loot := Loot.new()
	loot.name = "Loot"
	loot.world = in_world
	loot.maze = in_world.maze
	in_world.add_child(loot)
	loot.populate(hash("loot/%d" % seed_value))
	if in_world.player:
		loot.attach(in_world.player)
	if hud_layer:
		var hud := LootHud.new(loot)
		hud_layer.add_child(hud)
	return loot


## This player: the act button asks here first (Player.act_first).
func attach(player: Player) -> void:
	player.act_first = act
	_base_speeds = Vector2(player.run_speed, player.sprint_speed)
	_base_swing = player.swing_time
	slots.resize(SLOTS)
	slots.fill(-1)


# --- Placing ------------------------------------------------------------------

## Places the camps and everything lying about, from `seed_value`, by the rules
## in the clearing's style and each ring's.
func populate(seed_value: int) -> void:
	_rng.seed = seed_value
	var look := maze.clearing_style
	var spots: Array[Vector2] = []
	# The clearing's camps: those with runners at them first (one at the edge of
	# the woods, smoke going up over it), then those left.
	var occupied: int = look.get(&"occupied_camps") if look.get(&"occupied_camps") != null else 2
	var abandoned: int = look.get(&"abandoned_camps") if look.get(&"abandoned_camps") != null else 3
	var camp_regions := [Region.WOODS, Region.FIELD, Region.POND, Region.TALL_GRASS, Region.FIELD]
	for i in occupied + abandoned:
		var spot := _clearing_spot(camp_regions[i % camp_regions.size()], spots, 45.0, 70.0, 30.0)
		if not spot.is_finite():
			continue
		spots.append(spot)
		var at := Vector3(spot.x, maze.ground_height(Vector3(spot.x, 0.0, spot.y)), spot.y)
		add_camp(at, Campsite.Kind.OCCUPIED if i < occupied else Campsite.Kind.ABANDONED, _rng.randi(), false, look)
	# What lies about the clearing, kind by kind, among the woods' edge, the tall
	# grass and by the pond (and anywhere in the field), off the middle where
	# everyone wakes and the ways to the gates.
	var counts := [
		[LootItem.Kind.HOOK, &"loot_hooks", 1], [LootItem.Kind.BACKPACK, &"loot_backpacks", 1],
		[LootItem.Kind.SPEAR, &"loot_spears", 2], [LootItem.Kind.TORCH, &"loot_torches", 2],
		[LootItem.Kind.FLARE, &"loot_flares", 1], [LootItem.Kind.MAP, &"loot_maps", 1],
		[LootItem.Kind.LADDER, &"loot_ladders", 1],
		[LootItem.Kind.STICK, &"loot_sticks", 3], [LootItem.Kind.BAT, &"loot_bats", 1], [LootItem.Kind.SWORD, &"loot_swords", 0],
	]
	# (now and then a gun, and more rarely a box of rounds: by chance, from the seed)
	var shotgun_share: float = _rule(look, &"shotgun_share", 0.3)
	if _rng.randf() < _rule(look, &"gun_chance", 0.15):
		counts.append([LootItem.Kind.SHOTGUN if _rng.randf() < shotgun_share else LootItem.Kind.REVOLVER, &"", 1])
	if _rng.randf() < _rule(look, &"ammo_chance", 0.08):
		counts.append([LootItem.Kind.SHELLS if _rng.randf() < shotgun_share else LootItem.Kind.ROUNDS, &"", 1])
	var spread: Array[Vector2] = []
	for camp in camps:
		spread.append(Vector2(camp.position.x, camp.position.z))
	var region := 0
	for entry: Array in counts:
		var count: int = entry[2] if entry[1] == &"" else (look.get(entry[1]) if look.get(entry[1]) != null else entry[2])
		for i in count:
			var spot := _clearing_spot(region % 4, spread, 9.0, 40.0, 12.0)
			region += 1
			if not spot.is_finite():
				continue
			spread.append(spot)
			var at := Vector3(spot.x, 0.0, spot.y)
			at.y = maze.ground_height(at) + 0.02
			_arm(_place(entry[0], at, _rng.randf_range(0.0, TAU)), look, _rng)
			_tread(spot, 0.75)
	# The maze, ring by ring (the square ones): a camp or so left in a wide hall
	# or a dead end, and things lying in dead ends and well into its halls.
	for ring in range(1, maze.rings + 1):
		if ring > maze.styles.size():
			break
		var style: MazeStyle = maze.styles[ring - 1]
		if style.round_section:
			continue
		_populate_ring(ring, style)
	_trample_grass()


## A ring's camps and loot (MazeStyle, "What lies about").
func _populate_ring(ring: int, style: MazeStyle) -> void:
	var nav := MazeNav.new(maze)
	var cells: Array[Vector2i] = []
	var near_gates: Array[Vector2i] = []
	if ring - 1 < maze.gates.size():
		for way: Array in maze.gates[ring - 1]:
			near_gates.append(way[0])
	if ring - 1 < maze.exits.size():
		near_gates.append(maze.exits[ring - 1][0])
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != ring or not nav.allowed(cell) or maze.solid.has(cell):
			continue
		var by_gate := false
		for gate in near_gates:
			if maxi(absi(gate.x - cell.x), absi(gate.y - cell.y)) <= 2:
				by_gate = true
		if not by_gate:
			cells.append(cell)
	if cells.is_empty():
		return
	# (the ends of halls first: those with the most walls round them)
	var order: Array = []
	for cell in cells:
		var walls := 0
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step):
				walls += 1
		order.append([-walls, _rng.randf(), cell])
	order.sort()
	var used: Array[Vector2i] = []
	var camp_count: int = style.get(&"abandoned_camps") if style.get(&"abandoned_camps") != null else 1
	for entry: Array in order:
		if camp_count <= 0:
			break
		var cell: Vector2i = entry[2]
		# (in the middle of the hall, with room round it for the lean-to: where halls
		# are more than a cell wide, half a cell over towards the open sides, as
		# MazeRunner._middle_of has it)
		var middle := maze.world(cell)
		if style.hallway_diameter_cells > 1:
			for step: Vector2i in Maze.STEPS:
				if not maze.blocked(cell, step) and maze.ring_of(cell + step) == ring:
					middle += Vector3(step.x, 0.0, step.y) * Maze.CELL * 0.5
		if not nav.clear_of_walls(middle, 3.0) or not _off_heaps(middle, 4.5):
			continue
		var camp := add_camp(middle, Campsite.Kind.ABANDONED, _rng.randi(), true, style)
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step):
				# (the tallies on the wall at the end of the hall, found once the walls are solid)
				camp.scratch_wall_towards(Vector3(step.x, 0.0, step.y))
				break
		used.append(cell)
		camp_count -= 1
	var loose: int = style.get(&"loot_items") if style.get(&"loot_items") != null else 6
	for entry: Array in order:
		if loose <= 0:
			break
		var cell: Vector2i = entry[2]
		if cell in used:
			continue
		var at := nav.point(cell) + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
		if not nav.clear_of_walls(at, 1.4) or not _off_heaps(at, 0.5):
			at = nav.point(cell)
			if not _off_heaps(at, 0.5):
				continue
		at.y = maze.ground_height(at) + 0.02
		_arm(_place(_roll(maze_mix(style), style, _rng), at, _rng.randf_range(0.0, TAU)), style, _rng)
		used.append(cell)
		loose -= 1


## Whether `at` is clear of the heaps of boxes and barrels (MazeProps) by `margin`.
func _off_heaps(at: Vector3, margin: float) -> bool:
	var built := world.get_node_or_null(^"Maze") as MazeBuilder if world else null
	return built == null or built.props == null or not built.props.near_heap(at, margin)


## Puts in a camp of `kind` at `at` (on the ground), with what lies by it, and
## (with people at it) its runners sat round the fire.
func add_camp(at: Vector3, kind: Campsite.Kind, seed_value: int, in_maze: bool, rules: Resource = null) -> Campsite:
	var camp := Campsite.new(kind, seed_value, in_maze)
	camp.name = "Camp%d" % camps.size()
	camp.ground = maze.ground_height
	camp.position = at
	add_child(camp)
	camps.append(camp)
	_tread(Vector2(at.x, at.z), 5.0)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + 1
	# What was left lying by it: a thing or two at a camp left behind, one at one with people at it.
	var left := r.randi_range(1, 2) if kind == Campsite.Kind.ABANDONED else 1
	for i in mini(left, camp.stash.size()):
		var spot := camp.global_transform * camp.stash[i]
		spot.y = maze.ground_height(spot) + 0.02
		_arm(_place(_roll(CAMP_MIX, rules, r, "camp_" if rules is ClearingStyle else ""), spot, r.randf_range(0.0, TAU)), rules, r)
	if kind == Campsite.Kind.OCCUPIED:
		var sitting := r.randi_range(2, 3)
		for i in sitting:
			var boy := DrivenBoy.make(Camper) as Camper
			boy.name = "Camper%d" % campers.size()
			boy.camp = camp
			# (the third asleep on a bedroll, if there is one laid out)
			boy.sleeper = i == 2 and not camp.beds.is_empty()
			boy.seat = camp.global_transform * (camp.beds[0] if boy.sleeper else camp.seats[i])
			add_child(boy)
			var look: Dictionary = Looks.decode("", 0)
			look["colours"]["shirt"] = MazeRunners.SHIRTS[(campers.size() + 1) % MazeRunners.SHIRTS.size()]
			Looks.apply(boy.get_node(^"Rig") as CharacterRig, look)
			(boy.get_node(^"Rig") as CharacterRig).cap_hand = false
			Grass.push(boy)
			campers.append(boy)
	return camp


## Puts one of `kind` down lying at `at`, turned `yaw`; numbered in turn (the
## same on every copy), or with `id`.
func _place(kind: LootItem.Kind, at: Vector3, yaw: float, id := -1) -> Node3D:
	var item := LootItem.make(kind)
	if id < 0:
		id = _next
		_next += 1
	item.set(&"loot_id", id)
	item.name = "Loot%d" % id
	add_child(item)
	item.call(&"lay_at", at, yaw)
	item.set(&"loot", self)
	item.connect(&"released", _on_released)
	item.connect(&"rested", _on_rested)
	if item.has_signal(&"frayed"):
		item.connect(&"frayed", _on_frayed)
	items[id] = item
	owners[id] = -1
	return item


## A rule of a section's (or the clearing's) style, or `otherwise` if it has none.
static func _rule(rules: Resource, setting: StringName, otherwise: Variant) -> Variant:
	if rules == null:
		return otherwise
	var value: Variant = rules.get(setting)
	return otherwise if value == null else value


## What lies in a section's halls, by weight: MAZE_MIX and its style's weapons.
static func maze_mix(style: Resource) -> Array:
	var mix := MAZE_MIX.duplicate()
	mix.append([LootItem.Kind.STICK, _rule(style, &"stick_weight", 3)])
	mix.append([LootItem.Kind.BAT, _rule(style, &"bat_weight", 2)])
	mix.append([LootItem.Kind.SWORD, _rule(style, &"sword_weight", 1)])
	return mix


## One thing to leave lying, by the rules (a MazeStyle or the ClearingStyle, or
## null for the defaults): a gun `gun_chance` of the time (a shotgun
## `shotgun_share` of those), a box of rounds `ammo_chance` of the time, and
## otherwise one of `mix` by weight. (`prefix`: "camp_" for the clearing's camps, which have chances of their own.)
func _roll(mix: Array, rules: Resource, r: RandomNumberGenerator, prefix := "") -> LootItem.Kind:
	var roll := r.randf()
	var guns: float = _rule(rules, StringName(prefix + "gun_chance"), 0.04)
	var boxes: float = _rule(rules, StringName(prefix + "ammo_chance"), 0.025)
	if roll < guns:
		return LootItem.Kind.SHOTGUN if r.randf() < float(_rule(rules, &"shotgun_share", 0.3)) else LootItem.Kind.REVOLVER
	if roll < guns + boxes:
		return LootItem.Kind.SHELLS if r.randf() < float(_rule(rules, &"shotgun_share", 0.3)) else LootItem.Kind.ROUNDS
	return _pick(mix, r)


## Sets what `item` has in it by the rules: the rounds in a gun (`rounds_in_gun`)
## or a box (`rounds_per_box`), the blows a stick or a bat has in it before it
## breaks. From `r`, so the same on every copy.
func _arm(item: Node3D, rules: Resource, r: RandomNumberGenerator) -> void:
	if item == null:
		return
	var kind: int = item.get(&"kind")
	if kind in LootItem.GUNS:
		var span: Vector2i = _rule(rules, &"rounds_in_gun", Vector2i(1, 3))
		item.set(&"uses", clampi(r.randi_range(span.x, span.y), 0, LootItem.GUNS[kind]["capacity"]))
	elif kind in LootItem.BOX_FOR:
		var span: Vector2i = _rule(rules, &"rounds_per_box", Vector2i(2, 4))
		item.set(&"uses", r.randi_range(span.x, span.y))
	elif kind in LootItem.MELEE:
		var blows: Vector2i = LootItem.MELEE[kind]["uses"]
		item.set(&"uses", r.randi_range(blows.x, blows.y))


## One of `mix` ([kind, weight]...), by weight.
func _pick(mix: Array, r: RandomNumberGenerator = null) -> LootItem.Kind:
	var with := r if r else _rng
	var total := 0
	for entry: Array in mix:
		total += maxi(int(entry[1]), 0)
	var roll := with.randi_range(1, maxi(total, 1))
	for entry: Array in mix:
		roll -= maxi(int(entry[1]), 0)
		if roll <= 0 and int(entry[1]) > 0:
			return entry[0]
	return mix[0][0]


## A place in the clearing (x, z) in `region` (or anywhere, if none is found
## there): `apart` from `others`, at least `from_middle` from the middle, off
## the ways from the middle to the gates (`off_path`), in from the walls, out
## of the water. Not finite if none.
func _clearing_spot(region: int, others: Array[Vector2], apart: float, from_middle: float, off_path: float) -> Vector2:
	var look := maze.clearing_style
	var half := Maze.CLEARING * Maze.CELL * 0.5
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	var meadow := look.tall_grass_middle()
	var pond := _pond_middle()
	for attempt in 400:
		var spot := Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))
		var where := region if attempt < 250 else Region.FIELD
		if where == Region.WOODS and not woods.is_empty():
			var way := (woods[1] as Vector2).rotated(_rng.randf_range(-1.1, 1.1))
			spot = (woods[0] as Vector2) + way * look.woods_size * _rng.randf_range(0.85, 1.08)
		elif where == Region.TALL_GRASS and meadow.is_finite():
			spot = meadow + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * look.tall_grass_radius * sqrt(_rng.randf()) * 0.85
		elif where == Region.POND and pond.is_finite():
			spot = pond + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _pond_radius() * _rng.randf_range(1.3, 1.7)
		if maxf(absf(spot.x), absf(spot.y)) > half - 14.0 or spot.length() < from_middle:
			continue
		if look.marsh_rect().has_point(spot):
			continue
		if maze.ground_height(Vector3(spot.x, 0.0, spot.y)) < ClearingStyle.MARSH_LEVEL + 0.1:
			continue
		var ok := true
		for gate: Array in look.entrance_spots:
			if Geometry2D.get_closest_point_to_segment(spot, Vector2.ZERO, gate[0]).distance_to(spot) < off_path:
				ok = false
		for other in others:
			if other.distance_to(spot) < apart:
				ok = false
		if ok:
			return spot
	return Vector2.INF


## The marsh's middle and (half its) size, if the clearing has one: loot is
## left round its shore.
func _pond_middle() -> Vector2:
	var marsh := maze.clearing_style.marsh_rect()
	return marsh.get_center() if marsh.has_area() else Vector2.INF


func _pond_radius() -> float:
	var marsh := maze.clearing_style.marsh_rect()
	return maxf(marsh.size.x, marsh.size.y) * 0.5 if marsh.has_area() else 20.0


## The grass trodden down round (x, z), out to `radius`: a camp's patch, a
## little bare ground round something lying in it.
func _tread(at: Vector2, radius: float) -> void:
	var key := Vector2i(floori(at.x / 10.0), floori(at.y / 10.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var near := key + Vector2i(dx, dz)
			if not _trodden.has(near):
				_trodden[near] = []
			_trodden[near].append([at, radius])


## How much grass grows at (x, z) for what is trodden down: 0..1.
func trodden(p: Vector2) -> float:
	var list: Variant = _trodden.get(Vector2i(floori(p.x / 10.0), floori(p.y / 10.0)))
	if list == null:
		return 1.0
	var keep := 1.0
	for circle: Array in list:
		var d := p.distance_to(circle[0]) / float(circle[1])
		if d < 1.15:
			if float(circle[1]) > 2.0:
				# (a camp's patch: worn thin, raggedly, never quite bare)
				var ragged := 0.18 * sin(p.x * 1.7 + p.y * 0.6) * cos(p.y * 1.3 - p.x * 0.4)
				keep = minf(keep, lerpf(0.22, 1.0, smoothstep(0.35, 1.1, d + ragged)))
			else:
				keep = minf(keep, smoothstep(0.55, 1.0, d))
	return keep


## Has the clearing's grass grow thin where it is trodden (the squares not yet filled with it).
func _trample_grass() -> void:
	for node: Node in get_tree().get_nodes_in_group(Grass.FIELDS):
		var field := node as Grass
		var before: Callable = field.mask
		field.mask = func(p: Vector2) -> float:
			return (before.call(p) if before.is_valid() else 1.0) * trodden(p)


# --- Taking -------------------------------------------------------------------

## The act button, asked first (Player.act_first): takes what is in reach, or
## lights a fire (or a torch at one) with the torch in his hand. True if it did
## something with it; false leaves it to the Player (who throws what he holds).
func act(player: Player) -> bool:
	var held := _item(hand)
	if held and held.get(&"kind") == LootItem.Kind.TORCH:
		var camp := _camp_near(player.global_position, CAMP_REACH)
		if camp:
			if held.get(&"lit") and not camp.lit:
				light_camp(camps.find(camp))
				said.emit("THE FIRE IS LIT")
				return true
			if camp.lit:
				_relight(held)
				said.emit("THE TORCH IS LIT")
				return true
	# (something to fight with in his hand, and something that hunts near: he fights)
	if held and held.call(&"weapon") and hunter_near(player.global_position, FIGHT_NEAR):
		return false
	var found := nearest(player)
	if found == null or not player.is_on_floor():
		return false
	if found.get(&"kind") == LootItem.Kind.BACKPACK:
		if pack:
			said.emit("YOU HAVE A BACKPACK")
			return true
	elif found.get(&"kind") in LootItem.BOX_FOR:
		pass
	elif slots.find(-1) < 0:
		# (with something in his hand, the button is for that: he throws it)
		if hand >= 0:
			return false
		said.emit("NO ROOM: DROP SOMETHING")
		return true
	# He stoops for it (as for anything he picks up) and has it.
	player.pickup_point = found.global_position
	player.pickup_progress = 0.0
	ask_for(int(found.get(&"loot_id")))
	return true


## The nearest thing lying about within his reach, or null.
func nearest(player: Node3D) -> Node3D:
	var best: Node3D = null
	var least := REACH
	for id: int in items:
		var item: Node3D = items[id]
		if not is_instance_valid(item) or item.get(&"loot_state") != LootItem.State.LYING or _pending.has(id):
			continue
		var to := item.global_position - player.global_position
		var level := Vector2(to.x, to.z).length()
		if level < least and to.y < REACH_UP and to.y > -REACH_UP:
			least = level
			best = item
	return best


## Asks for item `id` (alone, or as the host, it is simply taken).
func ask_for(id: int) -> void:
	if not world.online or Net.is_host:
		grant(id, world.slot)
	else:
		_pending[id] = 2.5
		Net.send_json(Net.BROADCAST, {"loot": "take", "id": id})


## (Where it is decided: alone, or the host.) `seat` gets item `id`, if nobody
## has it yet; everyone is told.
func grant(id: int, seat: int) -> void:
	var item := _item(id)
	if item == null or int(owners.get(id, -1)) >= 0:
		return
	var state: int = item.get(&"loot_state")
	if state != LootItem.State.LYING and state != LootItem.State.FLYING:
		return
	_got(id, seat)
	if world.online:
		Net.send_json(Net.BROADCAST, {"loot": "got", "id": id, "seat": seat})


## Item `id` is `seat`'s now: out of the world, into their pocket (or onto their back).
func _got(id: int, seat: int) -> void:
	var item := _item(id)
	if item == null:
		return
	_pending.erase(id)
	owners[id] = seat
	item.call(&"pocket")
	var kind: int = item.get(&"kind")
	if seat == world.slot:
		if kind == LootItem.Kind.BACKPACK:
			pack = true
			Worn.put_on(world.player.get_node(^"Rig"), &"backpack")
			slots.resize(PACK_SLOTS)
			for i in range(SLOTS, PACK_SLOTS):
				slots[i] = -1
			item.call(&"spend")
			said.emit("A BACKPACK: ROOM FOR FOUR")
		elif kind in LootItem.BOX_FOR:
			# (a box of rounds goes in his pocket loose: it takes no slot)
			var rounds: int = item.get(&"uses")
			ammo[kind] = int(ammo[kind]) + rounds
			item.call(&"spend")
			LootGunFx.play(self, "pickup_1", world.player.global_position, -8.0, 8.0)
			said.emit("%d %s" % [rounds, "REVOLVER ROUNDS" if kind == LootItem.Kind.ROUNDS else "SHOTGUN SHELLS"] if rounds != 1 else ("A REVOLVER ROUND" if kind == LootItem.Kind.ROUNDS else "A SHOTGUN SHELL"))
			# (and a gun in his hand that is empty is loaded with them)
			var held := _item(hand)
			if held and held.get(&"kind") == LootItem.BOX_FOR[kind] and int(held.get(&"uses")) <= 0:
				_reload(held)
		else:
			var free := slots.find(-1)
			if free < 0:
				# (it came while he had no room after all: it is put down at his feet)
				_put_down(item, world.player.global_position + Vector3.UP * 0.4, Vector3.ZERO)
				return
			slots[free] = id
			if kind in LootItem.GUNS:
				var rounds: int = item.get(&"uses")
				said.emit("A %s: %s" % [String(item.call(&"title")), "EMPTY" if rounds == 0 else ("ONE ROUND IN IT" if rounds == 1 else "%d ROUNDS IN IT" % rounds)])
			else:
				said.emit(String(item.call(&"title")))
		changed.emit()
	elif kind in LootItem.BOX_FOR:
		item.call(&"spend")
	elif kind == LootItem.Kind.BACKPACK:
		item.call(&"spend")
		var other: RemotePlayer = world.remotes.get(seat)
		if other:
			Worn.put_on(other.rig, &"backpack")


# --- The inventory --------------------------------------------------------------

## How many slots he has.
func slot_count() -> int:
	return slots.size()


## The item in slot `i` (null if none).
func in_slot(i: int) -> Node3D:
	return _item(slots[i]) if i >= 0 and i < slots.size() else null


## Slot `i` tapped: a tool for the hand goes into it (or back out of it), a map
## is read, a rope ladder hung.
func use_slot(i: int) -> void:
	var item := in_slot(i)
	if item == null:
		return
	var kind: int = item.get(&"kind")
	if kind == LootItem.Kind.MAP:
		_read_map(item)
	elif kind == LootItem.Kind.LADDER:
		_hang_ladder(item)
	elif slots[i] == hand:
		stow()
	else:
		draw(i)


## Takes what is in slot `i` into his hand (putting away what was there).
func draw(i: int) -> void:
	var item := in_slot(i)
	var player := world.player
	if item == null or not item.call(&"in_hand"):
		return
	if player.state != Player.State.FREE or player.is_limp or player.cast_progress < 1.0 or player.hook_out:
		said.emit("NOT NOW")
		return
	if hand >= 0:
		stow()
	if player.carried:
		# (something of the world's he was holding is put down)
		player.let_go()
	hand = slots[i]
	var body := item as RigidBody3D
	body.collision_layer = LootItem.LAYER
	body.collision_mask = LootItem.MASK
	body.visible = true
	body.global_position = (player.get_node(^"Rig") as CharacterRig).hand_position()
	player._take(body)
	# (straight into his hand, not eased there from where it was)
	player._carry_ease = 1.0
	if item.get(&"kind") == LootItem.Kind.TORCH:
		item.call(&"set_lit", true)
	# (each weapon swings at its own speed)
	var kind: int = item.get(&"kind")
	player.swing_time = LootItem.MELEE[kind]["swing"] if kind in LootItem.MELEE else _base_swing
	_swing_was = 1.0
	_tell_hand(item)
	changed.emit()


## Puts what is in his hand back in its slot.
func stow() -> void:
	var item := _item(hand)
	hand = -1
	reloading = 0.0
	if item == null:
		changed.emit()
		return
	_stowing = true
	if world.player.carried == item:
		world.player.let_go()
	_stowing = false
	item.call(&"pocket")
	_tell_hand(null)
	changed.emit()


## Puts down what is in his hand, at his feet.
func drop() -> void:
	var item := _item(hand)
	if item == null:
		return
	_dropping = true
	world.player.let_go()
	_dropping = false


## Told by an item when it leaves the hand it was in: put away (nothing to do),
## or let go of: thrown or dropped, and out of the inventory.
func _on_released(item: Node3D) -> void:
	if _stowing:
		return
	var id: int = item.get(&"loot_id")
	if id != hand:
		return
	hand = -1
	reloading = 0.0
	var i := slots.find(id)
	if i >= 0:
		slots[i] = -1
	owners[id] = -1
	# (it flies as the Player threw it; its velocity is known next step)
	item.call(&"let_fly")
	_thrown[id] = 0.0
	# (a flare is struck as it is thrown; only put down, it is not)
	if item.get(&"kind") == LootItem.Kind.FLARE and not _dropping:
		item.call(&"set_lit", true)
	_tell_hand(null)
	changed.emit()


## Puts `item` down at `at`, falling with `velocity`, and tells everyone.
func _put_down(item: Node3D, at: Vector3, velocity: Vector3) -> void:
	var id: int = item.get(&"loot_id")
	owners[id] = -1
	item.global_position = at
	item.call(&"fly", velocity)
	_thrown[id] = 0.0


## Told by an item come to rest after flying: where it lies is told to everyone
## (by whoever let it go), and a flare that lands burning draws the hunters.
func _on_rested(item: Node3D) -> void:
	var id: int = item.get(&"loot_id")
	if _thrown.has(id) and world.online:
		var at := item.global_position
		var turn := item.global_basis.get_rotation_quaternion()
		Net.send_json(Net.BROADCAST, {"loot": "rest", "id": id, "at": [at.x, at.y, at.z], "turn": [turn.x, turn.y, turn.z, turn.w]})
	_thrown.erase(id)
	if item.get(&"kind") == LootItem.Kind.FLARE and item.get(&"lit"):
		_lures[id] = 0.0


func _on_frayed(item: Node3D) -> void:
	var id: int = item.get(&"loot_id")
	if id == hand:
		_stowing = true
		world.player.let_go()
		_stowing = false
		hand = -1
	var i := slots.find(id)
	if i >= 0:
		slots[i] = -1
	_spend(id)
	said.emit("THE HOOK'S ROPE HAS FRAYED THROUGH")
	changed.emit()


## Item `id` used up, here and everywhere.
func _spend(id: int, tell := true) -> void:
	var item := _item(id)
	if item:
		item.call(&"spend")
		# (out of a friend's hand too, if it was in one)
		for seat: Variant in world.remotes:
			var other: RemotePlayer = world.remotes[seat]
			if is_instance_valid(other) and other.carried == item:
				other.carried = null
	owners[id] = -2
	if tell and world.online:
		Net.send_json(Net.BROADCAST, {"loot": "spent", "id": id})


func _tell_hand(item: Node3D) -> void:
	if not world.online:
		return
	if item == null:
		Net.send_json(Net.BROADCAST, {"loot": "hand", "id": -1, "seat": world.slot})
	else:
		Net.send_json(Net.BROADCAST, {"loot": "hand", "id": item.get(&"loot_id"), "seat": world.slot, "lit": item.get(&"lit"), "fuel": item.get(&"fuel"), "uses": item.get(&"uses")})


# --- Using things ----------------------------------------------------------------

func _read_map(item: Node3D) -> void:
	var i := slots.find(int(item.get(&"loot_id")))
	if i >= 0:
		slots[i] = -1
	_spend(int(item.get(&"loot_id")))
	map_read.emit(MAP_SECONDS)
	said.emit("THE MAP CRUMBLES AS YOU READ IT")
	changed.emit()


## The cells of the way from where he is to the gate out of where he is (the
## clearing's nearest gate, or his ring's way out), for a map scrap; [] if
## there is none to show (the round sections past the moor).
func way_out(from: Vector3) -> Array[Vector2i]:
	var here := maze.cell_at(from)
	if not maze.inside(here):
		return []
	var ring := maze.ring_of(here)
	var nav := MazeNav.new(maze, false)
	var goals: Array[Vector2i] = []
	if ring == 0:
		for way: Array in maze.gates[0]:
			goals.append(way[0])
	elif ring - 1 < maze.exits.size() and ring <= maze.styles.size() and not maze.styles[ring - 1].round_section:
		goals.append(maze.exits[ring - 1][0])
	var best: Array[Vector2i] = []
	for goal in goals:
		var path := nav.path(here, goal)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


## Hangs the rope ladder from the edge he stands at, down to the ground below.
func _hang_ladder(item: Node3D) -> void:
	var player := world.player
	var edge := ladder_edge(player)
	if edge.is_empty():
		said.emit("STAND AT AN EDGE TO HANG IT")
		return
	var id: int = item.get(&"loot_id")
	var i := slots.find(id)
	if i >= 0:
		slots[i] = -1
	_spend(id, false)
	var top: Vector3 = edge[0]
	var out: Vector3 = edge[1]
	var drop_m: float = edge[2]
	ladders.append(RopeLadder.hang(self, top, out, drop_m))
	if world.online:
		Net.send_json(Net.BROADCAST, {"loot": "ladder", "id": id, "at": [top.x, top.y, top.z], "out": [out.x, out.z], "drop": drop_m})
	said.emit("THE LADDER IS HUNG")
	changed.emit()


## Where a rope ladder would hang from where `player` stands: the lip of the
## drop in front of him (within a step or two), the way out from it, and how
## far down the ground is: [top, out, drop], or [] if there is no such edge.
func ladder_edge(player: Player) -> Array:
	if not player.is_on_floor():
		return []
	var space := player.get_world_3d().direct_space_state
	var feet := player.global_position
	var skip: Array[RID] = [player.get_rid()]
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, PI]:
		var way := Vector3(sin(player.facing_yaw + turn), 0.0, cos(player.facing_yaw + turn))
		var lip := Vector3.INF
		for k in 12:
			var probe := feet + way * (0.15 + k * 0.15)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 0.5, probe + Vector3.DOWN * 0.6, 1, skip))
			if hit.is_empty():
				lip = feet + way * (0.15 + maxf(k - 1, 0) * 0.15)
				break
		if not lip.is_finite():
			continue
		# (and well past the lip, how far down)
		var beyond := lip + way * 0.45
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond, beyond + Vector3.DOWN * (LADDER_DROP.y + 1.0), 1, skip))
		if down.is_empty():
			continue
		var drop_m := feet.y - (down["position"] as Vector3).y
		if drop_m < LADDER_DROP.x or drop_m > LADDER_DROP.y:
			continue
		return [Vector3(lip.x, feet.y, lip.z), way, drop_m]
	return []


## Lights camp `index`'s fire, here and everywhere.
func light_camp(index: int, tell := true) -> void:
	if index < 0 or index >= camps.size():
		return
	camps[index].light()
	if tell and world.online:
		Net.send_json(Net.BROADCAST, {"loot": "camp", "index": index})


func _relight(torch: Node3D) -> void:
	torch.set(&"fuel", LootItem.TORCH_BURNS)
	torch.call(&"set_lit", true)
	if world.online:
		Net.send_json(Net.BROADCAST, {"loot": "lit", "id": torch.get(&"loot_id"), "lit": true, "fuel": LootItem.TORCH_BURNS})


## The nearest camp within `reach` of `at`, or null.
func _camp_near(at: Vector3, reach: float) -> Campsite:
	for camp in camps:
		if camp.hearth().distance_to(at + Vector3.UP * 0.3) < reach:
			return camp
	return null


# --- Every step -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var player := world.player
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = 0.1
		var near := nearest(player) if player.state == Player.State.FREE else null
		if near != in_reach:
			in_reach = near
			changed.emit()
	for id: int in _pending.keys():
		_pending[id] -= delta
		if _pending[id] <= 0.0:
			_pending.erase(id)
			said.emit("SOMEONE ELSE GOT IT")
	# Thrown: whatever was let go of, told to everyone with how it flies; a
	# spear in the air staggers what it passes.
	for id: int in _thrown.keys():
		var item := _item(id)
		if item == null:
			_thrown.erase(id)
			continue
		if _thrown[id] == 0.0:
			_thrown[id] = 0.001
			_tell_flight(item)
		if item.get(&"kind") == LootItem.Kind.SPEAR and item.get(&"loot_state") == LootItem.State.FLYING:
			_spear_hits(item)
	# A burning flare draws the hunters.
	for id: int in _lures.keys():
		var flare := _item(id)
		if flare == null or not flare.get(&"lit"):
			_lures.erase(id)
			continue
		var landing: bool = _lures[id] == 0.0
		_lures[id] -= delta
		if _lures[id] <= 0.0:
			_lures[id] = LURE_EVERY
			lure(flare.global_position, landing)
	# Something to fight with in his hand: a swing coming round, a gun being loaded.
	if hand >= 0:
		var held := _item(hand)
		if held:
			_fight_step(player, held)
	if reloading > 0.0:
		_reload_step(delta)
	# Walking into ivy with something in his hand, he puts it away to take hold.
	_ivy_in -= delta
	if hand >= 0 and _ivy_in <= 0.0:
		_ivy_in = 0.12
		if _into_ladder(player):
			stow()
	# With the pack full, he goes a little slower.
	if _base_speeds != Vector2.ZERO:
		var laden := pack and slots.find(-1) < 0
		player.run_speed = _base_speeds.x * (0.93 if laden else 1.0)
		player.sprint_speed = _base_speeds.y * (0.95 if laden else 1.0)


## Whether he is going into a ladder (ivy, a rope ladder) near enough to take hold of it.
func _into_ladder(player: Player) -> bool:
	if player.state != Player.State.FREE or player._wish.length_squared() < 0.04:
		return false
	for node: Node in NearIndex.near(get_tree(), &"ladders", player.global_position, 4.5):
		var ladder := node as Ladder
		if ladder == null:
			continue
		var foot := ladder.global_position
		if absf(foot.x - player.global_position.x) > 3.0 or absf(foot.z - player.global_position.z) > 3.0:
			continue
		if player.global_position.y < ladder.bottom_y() - 0.5 or player.global_position.y > ladder.top_y() - 0.5:
			continue
		var to := ladder.stand(player.global_position.y) - player.global_position
		to.y = 0.0
		if to.length() < 0.75 and player._wish.normalized().dot(ladder.facing()) > 0.5:
			return true
	return false


## Tells everyone of `item` let go of: where, how it is going, and whether it burns.
func _tell_flight(item: Node3D) -> void:
	if not world.online:
		return
	var at := item.global_position
	var going := (item as RigidBody3D).linear_velocity
	Net.send_json(Net.BROADCAST, {"loot": "drop", "id": item.get(&"loot_id"), "kind": item.get(&"kind"), "seat": world.slot,
		"at": [at.x, at.y, at.z], "vel": [going.x, going.y, going.z], "lit": item.get(&"lit"), "fuel": item.get(&"fuel"), "uses": item.get(&"uses")})


## A thrown spear in the air: anything that hunts that it passes near enough is staggered.
func _spear_hits(spear: Node3D) -> void:
	var going := (spear as RigidBody3D).linear_velocity
	if going.length() < 3.0:
		return
	for hunter in hunters():
		if Stagger.on(hunter) or hunter.get(&"fears_fire") == true:
			continue
		var to := hunter.global_position - spear.global_position
		var level := Vector2(to.x, to.z).length()
		if level < SPEAR_HITS + _girth(hunter) and to.y > -3.0 and to.y < 1.0:
			stagger(hunter, going)
			spear.set(&"linear_velocity", going * -0.15 + Vector3.UP * 1.5)
			return


## About how far round a hunter is past its middle (its size), metres.
func _girth(hunter: Node3D) -> float:
	var r: Variant = hunter.get(&"radius")
	if r is float:
		return clampf(r, 0.0, 3.0)
	return 0.6


## Everything that hunts: the MazeEnemies and the Griever(s).
func hunters() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if node is Node3D and (node as Node3D).is_inside_tree():
			found.append(node)
	for node: Node in get_tree().get_nodes_in_group(&"grievers"):
		if node is Node3D and (node as Node3D).visible:
			found.append(node)
	return found


## Staggers `hunter` along `push` for `seconds`, shoved `shove`: here, where the
## hunters are run, or by asking the host.
func stagger(hunter: Node3D, push: Vector3, seconds := Stagger.SECONDS, shove := Stagger.SHOVE) -> void:
	if not world.online or Net.is_host:
		Stagger.hit(hunter, push, seconds, shove)
		return
	var index := _hunter_index(hunter)
	if index != -1:
		Net.send_json(Net.BROADCAST, {"loot": "stagger", "enemy": index, "push": [push.x, push.z], "secs": seconds, "shove": shove})


## A flare burning at `at`: (where the hunters are run) what hunts within
## LURE_RANGE and is after nobody goes to see; and when it has just landed, what
## is after someone further off than the flare is drawn off them too.
func lure(at: Vector3, landing := false) -> void:
	if world.online and not Net.is_host:
		return
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		var enemy := node as MazeEnemy
		if enemy == null or enemy.puppet or enemy.fears_fire or enemy.global_position.distance_to(at) > LURE_RANGE:
			continue
		if enemy.hunting():
			if not landing or enemy.quarry == null or enemy.quarry.global_position.distance_to(enemy.global_position) < 10.0:
				continue
			enemy.quarry = null
			enemy._forget = 0.0
		enemy._last_seen = at


func _item(id: int) -> Node3D:
	var item: Variant = items.get(id)
	return item if item != null and is_instance_valid(item) else null


# --- Fighting back ------------------------------------------------------------------

## Whether anything that hunts is within `reach` of `at` (level).
func hunter_near(at: Vector3, reach: float) -> bool:
	for hunter in hunters():
		var to := hunter.global_position - at
		if Vector2(to.x, to.z).length() < reach + _girth(hunter) and absf(to.y) < 6.0:
			return true
	return false


## Every step with something to fight with in his hand: a swing begun (told to
## the room), and the moment it comes round (what it meets).
func _fight_step(player: Player, held: Node3D) -> void:
	var kind: int = held.get(&"kind")
	if not kind in LootItem.MELEE:
		_swing_was = 1.0
		return
	var now := player.swing_progress
	if _swing_was >= 1.0 and now < 1.0 and world.online:
		Net.send_json(Net.BROADCAST, {"loot": "swing", "seat": world.slot})
	if _swing_was < Player.SWING_HITS and now >= Player.SWING_HITS:
		swing_hits(player, held)
	_swing_was = now


## The weapon in his hands comes round: what hunts in front of him within its
## reach is staggered and shoved back (the first it meets; all of them, for a
## sword). Not one already reeling, or just come out of it (Stagger.open_to_blows):
## it is only shoved. A stick or a bat wears with each blow that lands, and
## breaks. Returns how many it hit.
func swing_hits(player: Player, held: Node3D) -> int:
	var kind: int = held.get(&"kind")
	var spec: Dictionary = LootItem.MELEE[kind]
	var facing := Vector3(sin(player.facing_yaw), 0.0, cos(player.facing_yaw))
	var targets: Array = []
	for hunter in hunters():
		if hunter.get(&"fears_fire") == true:
			continue
		var to := hunter.global_position - player.global_position
		var level := Vector3(to.x, 0.0, to.z)
		var reach := level.length() - _girth(hunter)
		if reach > spec["reach"] or to.y < -2.0 or to.y > 2.6:
			continue
		if level.length() > 0.4 and level.normalized().dot(facing) < 0.2:
			continue
		targets.append([reach, hunter])
	if targets.is_empty():
		return 0
	targets.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if not spec["cleaves"]:
		targets.resize(1)
	for entry: Array in targets:
		var hunter: Node3D = entry[1]
		if Stagger.open_to_blows(hunter):
			stagger(hunter, facing, spec["seconds"], spec["shove"])
		else:
			# (still reeling: knocked on a little, no more)
			stagger(hunter, facing, 0.0, spec["shove"] * 0.4)
	LootGunFx.play(self, "impact_wood", held.global_position, -2.0 if kind == LootItem.Kind.STICK else 0.0, 30.0,
		1.25 if kind == LootItem.Kind.STICK else (0.8 if kind == LootItem.Kind.SWORD else 1.0))
	var left: int = held.get(&"uses")
	if left > 0:
		held.set(&"uses", left - 1)
		if left - 1 <= 0:
			_broken(held)
	return targets.size()


## A stick or a bat has broken on a blow: out of his hand and gone.
func _broken(item: Node3D) -> void:
	var id: int = item.get(&"loot_id")
	if id == hand:
		_stowing = true
		world.player.let_go()
		_stowing = false
		hand = -1
	var i := slots.find(id)
	if i >= 0:
		slots[i] = -1
	_spend(id)
	_tell_hand(null)
	LootGunFx.play(self, "impact_wood", item.global_position, 2.0, 30.0, 1.5)
	said.emit("THE STICK SNAPS" if item.get(&"kind") == LootItem.Kind.STICK else "THE BAT SPLITS")
	changed.emit()


## The gun in his hand: the trigger pulled (LootItem.fire, from Player._fire).
## Loaded, it goes off: what it hits is felled or staggered, what hunts hears
## it, the room sees it. Empty, it clicks, or is loaded from his spare rounds
## if he has any. True if it went off.
func gun_fire(item: Node3D, shooter: Node3D, aim: Vector3) -> bool:
	if reloading > 0.0:
		return false
	var kind: int = item.get(&"kind")
	var spec: Dictionary = LootItem.GUNS[kind]
	var rounds: int = item.get(&"uses")
	if rounds <= 0:
		if int(ammo[spec["ammo"]]) > 0:
			_reload(item)
		else:
			LootGunFx.play(self, "dry", item.global_position, -4.0, 6.0)
			said.emit("CLICK. NO ROUNDS LEFT")
		return false
	item.set(&"uses", rounds - 1)
	var muzzle: Transform3D = item.call(&"muzzle")
	aim = aim.normalized() if aim.length_squared() > 0.0001 else -muzzle.basis.z.normalized()
	var end := shoot(muzzle.origin, aim, kind, shooter)
	LootGunFx.shot(self, muzzle, end, kind)
	noise(muzzle.origin, shooter)
	if world.online:
		Net.send_json(Net.BROADCAST, {"loot": "shot", "seat": world.slot, "id": item.get(&"loot_id"), "kind": kind,
			"from": [muzzle.origin.x, muzzle.origin.y, muzzle.origin.z], "to": [end.x, end.y, end.z], "uses": rounds - 1})
	if rounds - 1 <= 0:
		if int(ammo[spec["ammo"]]) > 0:
			_reload(item)
		else:
			said.emit("THAT WAS THE LAST ROUND")
	changed.emit()
	return true


## Loads the gun from his spare rounds (it takes a moment: LootItem.GUNS reload).
func _reload(item: Node3D) -> void:
	if reloading > 0.0:
		return
	reloading = LootItem.GUNS[item.get(&"kind")]["reload"]
	_reload_item = item
	LootGunFx.play(self, "break_open", item.global_position, -6.0, 8.0)
	said.emit("LOADING")
	changed.emit()


func _reload_step(delta: float) -> void:
	reloading -= delta
	if reloading > 0.0:
		return
	reloading = 0.0
	var item := _reload_item
	_reload_item = null
	if not is_instance_valid(item) or int(item.get(&"loot_id")) != hand:
		return
	var spec: Dictionary = LootItem.GUNS[item.get(&"kind")]
	var going_in := mini(spec["capacity"] - int(item.get(&"uses")), int(ammo[spec["ammo"]]))
	item.set(&"uses", int(item.get(&"uses")) + going_in)
	ammo[spec["ammo"]] = int(ammo[spec["ammo"]]) - going_in
	LootGunFx.play(self, "break_close", item.global_position, -6.0, 8.0)
	_tell_hand(item)
	changed.emit()


## A shot from `from` along `aim` out of a gun of `kind`, by `shooter`: what
## hunts it hits (the nearest a bullet passes close enough to, short of any
## wall; with a shotgun, all in its spread) is felled or staggered (`hit_by_shot`).
## Returns where the shot ended (what it hit, a wall, or its reach).
func shoot(from: Vector3, aim: Vector3, kind: int, shooter: Node3D = null) -> Vector3:
	var spec: Dictionary = LootItem.GUNS[kind]
	var reach: float = spec["range"]
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = []
	if shooter is CollisionObject3D:
		skip.append((shooter as CollisionObject3D).get_rid())
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + aim * reach, 1, skip))
	var end := from + aim * reach
	if not wall.is_empty():
		end = wall["position"]
		reach = from.distance_to(end)
	var tolerance: Vector2 = spec["aim"]
	var struck: Array = []
	for hunter in hunters():
		if hunter.get(&"fears_fire") == true:
			continue
		var girth := _girth(hunter)
		# (the nearest a shot passes to it: to a line up its middle, from its feet to over its head)
		var tall := maxf(1.6, girth * 2.6)
		var best := INF
		var along_best := 0.0
		for k in 4:
			var point := hunter.global_position + Vector3.UP * (tall * (0.15 + 0.25 * k))
			var along := (point - from).dot(aim)
			if along < 0.4 or along > reach + girth:
				continue
			var off := (point - from - aim * along).length()
			if off < best:
				best = off
				along_best = along
		if best <= girth + tolerance.x + tolerance.y * along_best:
			struck.append([along_best, hunter])
	if struck.is_empty():
		return end
	struck.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if kind != LootItem.Kind.SHOTGUN:
		struck.resize(1)
	for entry: Array in struck:
		hit_by_shot(entry[1], aim, entry[0] <= float(spec["fells"]))
	if kind != LootItem.Kind.SHOTGUN:
		end = from + aim * float(struck[0][0])
	return end


## Whether a shot can fell `hunter` (not one of the great or the unnatural).
func can_fell(hunter: Node3D) -> bool:
	if not hunter is MazeEnemy or hunter.get(&"fears_fire") == true:
		return false
	var script := hunter.get_script() as Script
	while script:
		if script.get_global_name() in BULLETPROOF:
			return false
		script = script.get_base_script()
	return true


## `hunter` is hit by a shot going `way`: felled if it can be and was near
## enough (`close`), and otherwise staggered a long while.
func hit_by_shot(hunter: Node3D, way: Vector3, close: bool) -> void:
	if close and can_fell(hunter):
		fell(hunter, way)
	else:
		stagger(hunter, way, SHOT_SECONDS, SHOT_SHOVE)


## Fells `hunter` for good (Stagger.fell): where the hunters are run, and
## everyone told; a guest asks the host.
func fell(hunter: Node3D, push: Vector3) -> void:
	var index := _hunter_index(hunter)
	if not world.online or Net.is_host:
		Stagger.fell(hunter, push)
		if world.online and index >= 0:
			Net.send_json(Net.BROADCAST, {"loot": "felled", "enemy": index, "push": [push.x, push.z]})
		return
	if index >= 0:
		Net.send_json(Net.BROADCAST, {"loot": "fell", "enemy": index, "push": [push.x, push.z]})


## A shot at `at` by `shooter` (where the hunters are run): what hunts within
## SHOT_HEARD and is after nobody comes to see; within SHOT_KNOWN it knows who
## fired, and goes after them. The Griever comes to look too.
func noise(at: Vector3, shooter: Node3D) -> void:
	if world.online and not Net.is_host:
		return
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		var enemy := node as MazeEnemy
		if enemy == null or enemy.puppet or Stagger.on(enemy):
			continue
		var d := enemy.global_position.distance_to(at)
		if d > SHOT_HEARD:
			continue
		if d < SHOT_KNOWN and shooter and enemy.huntable(shooter):
			enemy.notice(shooter)
		elif not enemy.hunting():
			enemy._last_seen = at
	for node: Node in get_tree().get_nodes_in_group(&"grievers"):
		var griever := node as Node3D
		if griever and griever.visible and griever.global_position.distance_to(at) < SHOT_HEARD and griever.has_method(&"alert"):
			griever.call(&"alert", at)


## A hunter's number, as the room knows it (MazeEnemies' list; the Griever -2), or -1.
func _hunter_index(hunter: Node3D) -> int:
	if hunter == world.griever:
		return -2
	return world.enemies.enemies.find(hunter) if world.enemies else -1


func _hunter_at(index: int) -> Node3D:
	if index == -2:
		return world.griever
	if world.enemies and index >= 0 and index < world.enemies.enemies.size():
		return world.enemies.enemies[index]
	return null


## What the HUD says of the gun in his hand: the rounds in it and his spare
## ones (or that he is loading it); "" if he holds none.
func ammo_text() -> String:
	var held := _item(hand)
	if held == null or not held.get(&"kind") in LootItem.GUNS:
		return ""
	var spec: Dictionary = LootItem.GUNS[held.get(&"kind")]
	if reloading > 0.0:
		return "LOADING..."
	return "%d / %d   SPARE %d" % [int(held.get(&"uses")), int(spec["capacity"]), int(ammo[spec["ammo"]])]


# --- The room's news -----------------------------------------------------------

## A message from the room ({"loot": ...}), from seat `from`.
func hear(message: Dictionary, from: int) -> void:
	var what := str(message.get("loot", ""))
	var id := int(message.get("id", -1))
	if Net.is_host and from != world.slot:
		if what == "take":
			grant(id, from)
			return
		if what == "stagger":
			var index := int(message.get("enemy", -1))
			var hunter: Node3D = world.griever if index == -2 else (world.enemies.enemies[index] if index >= 0 and index < world.enemies.enemies.size() else null)
			var push: Array = message.get("push", [0, 0])
			if hunter:
				Stagger.hit(hunter, Vector3(push[0], 0.0, push[1]), float(message.get("secs", Stagger.SECONDS)), float(message.get("shove", Stagger.SHOVE)))
			return
		if what == "fell":
			var hunter := _hunter_at(int(message.get("enemy", -1)))
			var push: Array = message.get("push", [0, 0])
			if hunter:
				fell(hunter, Vector3(push[0], 0.0, push[1]))
			return
		if what == "shot":
			# (what hunts hears a guest's shot here, where it is run)
			var at: Array = message.get("from", [0, 0, 0])
			noise(Vector3(at[0], at[1], at[2]), world.remotes.get(from))
		# (the rest is passed on to everyone; a guest speaks only for itself)
		if message.has("seat"):
			message["seat"] = from
		Net.send_json(Net.BROADCAST, message)
	match what:
		"got":
			_got(id, int(message.get("seat", -1)))
		"hand":
			var item := _item(id)
			if item and message.has("uses"):
				item.set(&"uses", int(message.get("uses", 0)))
			_heard_hand(int(message.get("seat", -1)), id, bool(message.get("lit", false)), float(message.get("fuel", 0.0)))
		"drop":
			_heard_drop(message)
		"rest":
			var item := _item(id)
			if item and item.get(&"loot_state") != LootItem.State.POCKET and item.get(&"loot_state") != LootItem.State.HAND:
				var at: Array = message.get("at", [0, 0, 0])
				var turn: Array = message.get("turn", [0, 0, 0, 1])
				item.global_transform = Transform3D(Basis(Quaternion(turn[0], turn[1], turn[2], turn[3])), Vector3(at[0], at[1], at[2]))
				item.call(&"lie")
				if item.get(&"kind") == LootItem.Kind.FLARE and item.get(&"lit"):
					_lures[id] = 0.0
		"lit":
			var item := _item(id)
			if item:
				item.set(&"fuel", float(message.get("fuel", 0.0)))
				item.call(&"set_lit", bool(message.get("lit", false)))
		"camp":
			light_camp(int(message.get("index", -1)), false)
		"ladder":
			_spend(id, false)
			var at: Array = message.get("at", [0, 0, 0])
			var out: Array = message.get("out", [0, 1])
			ladders.append(RopeLadder.hang(self, Vector3(at[0], at[1], at[2]), Vector3(out[0], 0.0, out[1]), float(message.get("drop", 3.0))))
		"spent":
			_spend(id, false)
		"swing":
			var other: RemotePlayer = world.remotes.get(int(message.get("seat", -1)))
			if other:
				other.swung()
		"shot":
			_heard_shot(message)
		"felled":
			var hunter := _hunter_at(int(message.get("enemy", -1)))
			var push: Array = message.get("push", [0, 0])
			if hunter:
				Stagger.fell(hunter, Vector3(push[0], 0.0, push[1]))


## Someone else's shot: seen and heard where it was, their gun brought up and kicking.
func _heard_shot(message: Dictionary) -> void:
	var kind := int(message.get("kind", LootItem.Kind.REVOLVER))
	var a: Array = message.get("from", [0, 0, 0])
	var b: Array = message.get("to", [0, 0, 1])
	var from := Vector3(a[0], a[1], a[2])
	var to := Vector3(b[0], b[1], b[2])
	var way := (to - from).normalized() if from.distance_to(to) > 0.01 else Vector3.FORWARD
	var item := _item(int(message.get("id", -1)))
	if item:
		item.set(&"uses", int(message.get("uses", 0)))
	var other: RemotePlayer = world.remotes.get(int(message.get("seat", -1)))
	if other:
		other.fired(LootItem.GUNS.get(kind, {"kick": 0.6})["kick"], way)
	LootGunFx.shot(self, Transform3D(Basis.looking_at(way, Vector3.UP if absf(way.y) < 0.98 else Vector3.RIGHT), from), to, kind)


## Seat `seat` has `id` in their hand now (-1: nothing).
func _heard_hand(seat: int, id: int, lit: bool, fuel: float) -> void:
	var other: RemotePlayer = world.remotes.get(seat)
	if other == null:
		return
	var was := other.carried as Node3D
	if is_instance_valid(was) and was.get(&"loot_state") == LootItem.State.HAND:
		was.call(&"pocket")
	other.carried = null
	var item := _item(id)
	if item == null:
		return
	owners[id] = seat
	other.carried = item as RigidBody3D
	if item.has_method(&"held_by"):
		item.call(&"held_by", other)
	else:
		item.visible = true
		item.set(&"bearer", other)
		item.set(&"loot_state", LootItem.State.HAND)
		item.set(&"fuel", fuel)
		item.call(&"set_lit", lit)


## Someone has let go of something (or the dev panel has put one in): it is
## where they say, flying as they say; one this copy never heard of is made.
func _heard_drop(message: Dictionary) -> void:
	var id := int(message.get("id", -1))
	var item := _item(id)
	if item == null:
		item = _place(int(message.get("kind", LootItem.Kind.TORCH)) as LootItem.Kind, Vector3.ZERO, 0.0, id)
	var seat := int(message.get("seat", -1))
	var other: RemotePlayer = world.remotes.get(seat)
	if other and other.carried == item:
		other.carried = null
	owners[id] = -1
	var at: Array = message.get("at", [0, 0, 0])
	var vel: Array = message.get("vel", [0, 0, 0])
	item.global_position = Vector3(at[0], at[1], at[2])
	item.set(&"fuel", float(message.get("fuel", 0.0)))
	if message.has("uses"):
		item.set(&"uses", int(message.get("uses", 0)))
	item.call(&"fly", Vector3(vel[0], vel[1], vel[2]))
	item.call(&"set_lit", bool(message.get("lit", false)))


# --- The dev panel ------------------------------------------------------------------

## Puts one of `what` (DEV) down a few metres ahead of him: a thing, or a camp.
func dev_drop(what: String) -> void:
	var player := world.player
	var look := -world.camera.global_basis.z
	look.y = 0.0
	look = look.normalized() if look.length() > 0.01 else Vector3.FORWARD
	if what == "camp" or what == "camp_lit":
		var at := _ahead(player, look, 7.0)
		add_camp(at, Campsite.Kind.OCCUPIED if what == "camp_lit" else Campsite.Kind.ABANDONED, randi(), not maze.in_clearing(maze.cell_at(at)))
		return
	var at := _ahead(player, look, 2.2) + Vector3.UP * 0.02
	var id := (world.slot + 1) * 100000 + _next
	_next += 1
	var item := _place(DEV_KINDS[what], at, randf_range(0.0, TAU), id)
	var r := RandomNumberGenerator.new()
	r.randomize()
	# (the dev panel's guns come with half a load, its boxes with a few)
	_arm(item, null, r)
	if item.get(&"kind") in LootItem.GUNS:
		item.set(&"uses", ceili(LootItem.GUNS[item.get(&"kind")]["capacity"] * 0.5))
	if world.online:
		Net.send_json(Net.BROADCAST, {"loot": "drop", "id": id, "kind": item.get(&"kind"), "seat": world.slot,
			"at": [at.x, at.y + 0.3, at.z], "vel": [0, 0, 0], "lit": false, "fuel": item.get(&"fuel"), "uses": item.get(&"uses")})


## A point on the ground `reach` ahead of `player` the way `look`, short of any wall.
func _ahead(player: Player, look: Vector3, reach: float) -> Vector3:
	var from := player.global_position + Vector3.UP * 1.0
	var to := from + look * reach
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()]))
	if not hit.is_empty():
		to = from + look * maxf((hit["position"] as Vector3).distance_to(from) - 1.0, 1.0)
	var down := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 2.0, to + Vector3.DOWN * 6.0, 1, [player.get_rid()]))
	if not down.is_empty():
		return down["position"]
	return Vector3(to.x, maze.ground_height(to), to.z)
