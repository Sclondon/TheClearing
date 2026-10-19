@tool
class_name ClearingStyle
extends Resource
## How the clearing is made (Maze.clearing_style; set in the editor through
## MazeLayout.clearing_style): a level middle with no trees in it, very gentle
## hills over the rest of the field, level again at the foot of its walls, stands
## of pines along the walls, and something different before each entrance (see
## entrances): dense woods round one, grass up to his chest round another, a
## marsh in front of another, and nothing at all near the last.

@export_group("Clearing wall")
## How high the wall round the clearing is, metres (and the walls beside its gates).
@export_range(20.0, 300.0, 0.001, "suffix:m") var clearing_wall_height := 92.0
## How many cells (14 m each) of solid wall thicken it past its face, moving the first section out.
@export_range(0, 6, 1, "suffix:cells") var clearing_wall_thickness_cells := 3

@export_group("Fog")
## Banks of billowing fog lying along the foot of the clearing's wall, the wall
## rising out of them (ClearingFog; the user, 2026-10-18: "The cleaing should
## have billowing fog that the clearing walls rise above"). Thickest at dawn,
## thinner by day, burnt off on a sunny day, beaten down by rain. How thick
## they are at most (0 none, 1 thickest).
@export_range(0.0, 1.0, 0.01, "suffix:amount") var clearing_fog_thickness := 0.8
## How high the fog banks rise against the wall, metres (kept well under its top, which rises out of them).
@export_range(5.0, 120.0, 0.001, "suffix:m") var clearing_fog_height := 42.0
## How far into the clearing from its wall the fog banks lie, metres (thinning and lower towards the middle).
@export_range(20.0, 250.0, 0.001, "suffix:m") var clearing_fog_reach := 120.0
## How many billows of fog there are along each side of the clearing (fewer on a phone).
@export_range(2, 40, 1, "suffix:billows a side") var clearing_fog_billows := 14
## How fast the fog rolls and billows (1 as made; 0 still).
@export_range(0.0, 4.0, 0.01, "suffix:speed") var clearing_fog_speed := 1.0

@export_group("Ground")
## No trees nearer the middle than this, metres.
@export_range(0.0, 250.0, 0.001, "suffix:m") var treeless_radius := 95.0
## The ground is level out to this far from the middle, metres.
@export_range(0.0, 250.0, 0.001, "suffix:m") var flat_radius := 70.0
## How far the level ground takes to rise into the hills, metres.
@export_range(1.0, 200.0, 0.001, "suffix:m") var hill_rise_distance := 60.0
## How high the hills are at most, metres (0: the whole field level).
@export_range(0.0, 12.0, 0.001, "suffix:m") var hill_height := 4.0
## About how far apart the hills are, metres.
@export_range(20.0, 400.0, 0.001, "suffix:m") var hill_spacing := 150.0
## The ground is level this far out from the foot of the clearing's wall, metres, then rises into the hills.
@export_range(0.0, 80.0, 0.001, "suffix:m") var flat_border_width := 18.0

## What is in front of one of the clearing's entrances.
enum Entrance {
	## Nothing in particular: the field as anywhere else.
	PLAIN,
	## The woods, round it (woods density, woods size).
	WOODS,
	## Grass up to his chest in front of it, up to the wall either side (tall
	## grass width, reach and height).
	TALL_GRASS,
	## Flooded: a marsh in front of it, pools and channels of standing water
	## between hummocks of wet ground, sedges growing up out of it (the marsh
	## settings).
	MARSH,
	## Clear: nothing near it at all, no trees nor bushes (clear radius).
	CLEAR,
}

@export_group("Entrances")
## What is in front of each of the clearing's entrances, in turn round them.
@export var entrances: Array[Entrance] = [Entrance.WOODS, Entrance.TALL_GRASS, Entrance.MARSH, Entrance.CLEAR]
## The tall grass in front of its entrance: a meadow of its own, running right
## up to the foot of the wall and to the gate (the user, 2026-10-18: "the tall
## grass area needs to be bigger in the clearing and run right up to the walls
## and door"). Half an oval with its straight side along the wall: this wide
## along the wall, reaching this far out into the clearing from it, metres; its
## edge wandering in and out by up to this share of that; the grass as high as
## this, in a hollow this deep (level again at the foot of the wall).
## How wide the tall grass is along the wall, metres.
@export_range(20.0, 600.0, 0.001, "suffix:m") var tall_grass_width := 340.0
## How far the tall grass reaches out into the clearing from the wall, metres.
@export_range(10.0, 280.0, 0.001, "suffix:m") var tall_grass_reach := 150.0
## How far its edge wanders in and out, as a share of its reach (0 to 0.6).
@export_range(0.0, 0.6, 0.001, "suffix:of reach") var tall_grass_ragged := 0.25
## How high the tall grass grows, metres.
@export_range(0.5, 3.0, 0.001, "suffix:m") var tall_grass_height := 1.5
## How deep the hollow is that the tall grass grows in, metres.
@export_range(0.0, 4.0, 0.001, "suffix:m") var tall_grass_hollow := 1.2
## How far round a clear entrance nothing grows but grass, metres.
@export_range(5.0, 200.0, 0.001, "suffix:m") var clear_radius := 75.0

@export_group("Marsh")
## How wide the marsh in front of a flooded entrance is along the wall, metres.
@export_range(20.0, 400.0, 0.001, "suffix:m") var marsh_width := 190.0
## How far the marsh reaches out into the clearing, metres.
@export_range(20.0, 250.0, 0.001, "suffix:m") var marsh_reach := 125.0
## How far out from the wall the marsh begins, metres.
@export_range(0.0, 40.0, 0.001, "suffix:m") var marsh_distance := 3.0
## How far its edge wanders in and out (0 to 1; at 1, by 0.7 of its size).
@export_range(0.0, 1.0, 0.001, "suffix:ragged") var marsh_ragged := 0.5
## How much of it is open water, the rest hummocks and tussocks of wet ground (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of it") var marsh_water := 0.5
## About how far apart the hummocks are, metres.
@export_range(2.0, 30.0, 0.001, "suffix:m") var marsh_hummock_size := 6.5
## How much of it is channels of water winding between the hummocks (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of it") var marsh_channels := 0.6
## How deep its shallow water is at most, metres.
@export_range(0.05, 1.0, 0.001, "suffix:m") var marsh_shallow_depth := 0.45
## How deep its dark pools are (over his head: he swims), metres.
@export_range(0.3, 4.0, 0.001, "suffix:m") var marsh_pool_depth := 1.6
## How much of it is deep pools (a share, 0 to 0.4).
@export_range(0.0, 0.4, 0.001, "suffix:of it") var marsh_deep_pools := 0.08
## How tall the sedges growing up out of its water are, metres.
@export_range(0.3, 2.5, 0.001, "suffix:m") var marsh_grass_height := 0.95
## How deep the water may be that sedges still grow up out of, metres (none in deeper pools).
@export_range(0.05, 1.5, 0.001, "suffix:m") var marsh_grass_depth := 0.55
## Reeds and bulrushes, in clumps along the edges of the pools (0 none, 1 many).
@export_range(0.0, 1.0, 0.001, "suffix:amount") var marsh_reeds := 0.5
## Lily pads on the open water (0 none, 1 many).
@export_range(0.0, 1.0, 0.001, "suffix:amount") var marsh_lily_pads := 0.5
## The way in to its gate flooded: water from the foot of the wall out into
## the marsh and on through the gate's slot into the hall beyond (Ponds), no
## dry way across it. How deep, metres (to his knees or waist; 0: no flooded way).
@export_range(0.0, 0.95, 0.001, "suffix:m") var marsh_flood_depth := 0.7
## How wide the flooded way in is along the wall, metres.
@export_range(10.0, 200.0, 0.001, "suffix:m") var marsh_flood_width := 70.0
## How far out from the wall the flooded way in reaches, metres.
@export_range(5.0, 120.0, 0.001, "suffix:m") var marsh_flood_reach := 42.0

## How high the marsh's water stands (under the level ground round it), metres.
const MARSH_LEVEL := -0.25
## Nothing deep, and no reeds nor lily pads, in a lane this wide (each way) and
## this long out from the flooded entrance: the way in from its gate is open,
## though wet.
const MARSH_LANE := Vector2(5.0, 30.0)

## Where each entrance is, as Maze.generate found them: [the middle of the
## gateway at the inside face of the wall (x, z), the way into the clearing].
var entrance_spots: Array = []

@export_group("Woods")
## How thick the woods round their entrance are: 0 none, 1 a tree every woods tree spacing
## metres or so.
@export_range(0.0, 1.0, 0.001, "suffix:density") var woods_density := 0.85
## How far the woods reach out from their entrance, metres.
@export_range(20.0, 300.0, 0.001, "suffix:m") var woods_size := 185.0
## About how far apart the trees in the woods are, metres.
@export_range(3.0, 20.0, 0.001, "suffix:m") var woods_tree_spacing := 6.5

@export_group("Plants")
## Ferns round the foot of each pine, on average (more in the woods, where they stand close).
@export_range(0.0, 10.0, 0.001, "suffix:per tree") var ferns_per_tree := 2.5
## The chance of a cushion of moss at the foot of a pine.
@export_range(0.0, 1.0, 0.001, "suffix:chance") var moss_per_tree_chance := 0.5
## Bushes over the field (none within the treeless radius), most of them near the trees.
@export_range(0, 400, 1, "suffix:bushes") var bush_count := 70

@export_group("Wildlife")
## Herds of deer grazing out in the meadow (Wildlife: peaceful, they run from you).
@export_range(0, 4, 1, "suffix:herds") var deer_herds := 2
## Herds of elk (a bull, cows and calves) grazing out in the meadow.
@export_range(0, 4, 1, "suffix:herds") var elk_herds := 1
## Flocks of tame chickens (TameChickens) foraging in the clearing: hens and a
## rooster that hunt nobody, the first at the edge of the woods.
@export_range(0, 6, 1, "suffix:flocks") var chicken_flocks := 2
## Families of blue jays (BlueJays) in the pines at the edge of the woods,
## flitting about the branches and down to the ground.
@export_range(0, 6, 1, "suffix:families") var blue_jay_families := 3
## Small flocks of crows in the tops of the pines, foraging out in the meadow by the woods.
@export_range(0, 4, 1, "suffix:flocks") var crow_flocks := 1
## Dragonflies over the marsh (Insects), about this many in all, in patches
## along its pools, perching on the bulrushes.
@export_range(0, 120, 1, "suffix:dragonflies") var marsh_dragonflies := 36
## Clouds of fireflies (Insects: FireflyField) at dusk and through the night: over the tall grass,
## in the woods, over the marsh and out in the meadow.
@export_range(0, 80, 1, "suffix:clouds") var firefly_clouds := 36
## Griffinflies (MazeGriffinfly: giant dragonflies) hunting over the marsh; they buzz and knock
## you down, never catch. None by default: the clearing is safe.
@export_range(0, 4, 1, "suffix:griffinflies") var marsh_griffinflies := 0
## Colonies of frogs along the edges of the marsh's pools (MazePondFrogs).
@export_range(0, 12, 1, "suffix:colonies") var marsh_frog_colonies := 6
## Tame foxes (one or a pair each) out in the meadow (MazeFox, tame): they follow at a
## distance, sit and watch, slip away, and pounce for mice in the grass.
@export_range(0, 3, 1, "suffix:foxes or pairs") var foxes := 1
## Rabbit warrens out in the meadow (MazeRabbit: hummocks, a colony of four to six each).
@export_range(0, 6, 1, "suffix:warrens") var rabbit_warrens := 2
## Brown hares lying up in the open meadow (MazeHare; every other one a pair that box).
@export_range(0, 6, 1, "suffix:hares") var hares := 2
## Lonely horses at the clearing's edge (run with the hunters, so guests see them).
@export_range(0, 2, 1, "suffix:horses") var horses := 1
## Schools of small fish in the marsh's water (FishSchool), and how many fish in
## each: they dart off from whoever wades near.
@export_range(0, 20, 1, "suffix:schools") var marsh_fish_schools := 9
## How many fish are in each school in the marsh.
@export_range(1, 40, 1, "suffix:fish") var marsh_fish_per_school := 14
## Clouds of moths out over the grass, in the evening and through the night (Insects).
@export_range(0, 8, 1, "suffix:clouds") var dusk_moth_clouds := 3
## Packs of coyotes out in the meadow (Wildlife: tame, they stare, shadow, yip and
## run off, and are never bold).
@export_range(0, 4, 1, "suffix:packs") var coyote_packs := 1

@export_group("What lies about")
## Things left lying about the clearing to find (Loot), how many of each: among
## the edge of the woods, in the tall grass, by the pond and out in the field,
## never in the middle where everyone wakes nor on the ways to the gates. (More
## lie by the camps.)
@export_range(0, 6, 1, "suffix:hooks") var loot_hooks := 1
## Backpacks lying about the clearing.
@export_range(0, 6, 1, "suffix:backpacks") var loot_backpacks := 1
## Spears lying about the clearing.
@export_range(0, 6, 1, "suffix:spears") var loot_spears := 2
## Torches lying about the clearing.
@export_range(0, 6, 1, "suffix:torches") var loot_torches := 2
## Flares lying about the clearing.
@export_range(0, 6, 1, "suffix:flares") var loot_flares := 1
## Maps lying about the clearing.
@export_range(0, 6, 1, "suffix:maps") var loot_maps := 1
## Ladders lying about the clearing.
@export_range(0, 6, 1, "suffix:ladders") var loot_ladders := 1
## Things to fight with: sticks (common, weak, they snap), bats (they knock a
## hunter back), swords (the best; none in the clearing by default).
@export_range(0, 8, 1, "suffix:sticks") var loot_sticks := 3
## Bats lying about the clearing (they knock a hunter back).
@export_range(0, 6, 1, "suffix:bats") var loot_bats := 1
## Swords lying about the clearing (the best; none by default).
@export_range(0, 6, 1, "suffix:swords") var loot_swords := 0
## The chance a gun lies somewhere in the clearing this round (a shotgun
## `shotgun_share` of the time, with `rounds_in_gun` in it), and that a box of
## rounds does (`rounds_per_box` in it). Rare, and rarer.
@export_range(0.0, 1.0, 0.01, "suffix:chance") var gun_chance := 0.15
## Of guns (and boxes of rounds), how many are shotguns, the rest revolvers (a share, 0 to 1).
@export_range(0.0, 1.0, 0.05, "suffix:of guns") var shotgun_share := 0.3
## How many rounds a gun is found with: fewest and most (rounds).
@export var rounds_in_gun := Vector2i(1, 3)
## The chance a box of rounds lies somewhere in the clearing this round (0 to 1).
@export_range(0.0, 1.0, 0.01, "suffix:chance") var ammo_chance := 0.08
## How many rounds are left in a box: fewest and most (rounds or shells).
@export var rounds_per_box := Vector2i(2, 4)
## The chance anything left lying by a camp in the clearing is a gun (0 to 1).
@export_range(0.0, 1.0, 0.005, "suffix:chance") var camp_gun_chance := 0.03
## The chance anything left by a camp in the clearing is a box of rounds (0 to 1).
@export_range(0.0, 1.0, 0.005, "suffix:chance") var camp_ammo_chance := 0.02
## Camps (Campsite): left behind (a cold fire, a thing or two by it), and with
## runners resting at them round a fire whose smoke is seen from afar (the first
## at the edge of the woods).
@export_range(0, 6, 1, "suffix:camps") var abandoned_camps := 3
## Camps with runners resting at them round a fire whose smoke is seen from afar.
@export_range(0, 4, 1, "suffix:camps") var occupied_camps := 2

var _noise: FastNoiseLite
var _noise_seed := -1
var _marsh: FastNoiseLite
var _marsh_seed := -1
var _meadow_edge: FastNoiseLite

## How far in from the edge of the marsh's square (marsh_rect) the hills' coarse
## ground is sunk out of sight under its own (coarse_height_at), metres: more
## than a step of the hills' mesh.
const MARSH_COARSE_MARGIN := 4.0

## The names these settings had before (as saved in older mazes), and the new ones.
const RENAMED := {
	&"glade": &"treeless_radius", &"flat": &"flat_radius", &"rise": &"hill_rise_distance", &"hills": &"hill_height",
	&"hill_size": &"hill_spacing", &"wall_level": &"flat_border_width", &"woods": &"woods_density",
	&"woods_reach": &"woods_size", &"spacing": &"woods_tree_spacing", &"ferns": &"ferns_per_tree",
	&"moss": &"moss_per_tree_chance", &"bushes": &"bush_count",
}


# A maze saved with the old names still loads.
func _set(property: StringName, value: Variant) -> bool:
	if RENAMED.has(property):
		set(RENAMED[property], value)
		return true
	# (the round pond there was before the marsh: its settings are let go)
	if String(property).begins_with("pond_"):
		return true
	# (and the round tall grass there was before it ran up to the wall)
	if property == &"tall_grass_radius" or property == &"tall_grass_distance":
		return true
	return false


## How high the ground is at (x, z), for a maze made from `seed_value`: 0 at the
## middle, at the foot of the clearing's walls and everywhere past them.
func height_at(x: float, z: float, seed_value: int) -> float:
	var height := _unflooded_height_at(x, z, seed_value)
	# (the flooded way in to the marsh's gate: under water to his knees or waist)
	var flood := marsh_flood_at(Vector2(x, z), seed_value)
	if flood > 0.0:
		height = lerpf(height, MARSH_LEVEL - marsh_flood_depth_at(Vector2(x, z), seed_value), flood)
	return height


func _unflooded_height_at(x: float, z: float, seed_value: int) -> float:
	var hill := _hill_at(x, z, seed_value)
	# (the marsh: hummocks round its water, blended into the field at its edge)
	var wet := _marsh_wet_at(Vector2(x, z), seed_value)
	if wet > 0.0:
		return lerpf(hill, MARSH_LEVEL + _marsh_lie(Vector2(x, z), wet, seed_value), wet)
	# (the tall grass in a hollow of its own, level at the foot of the wall)
	if tall_grass_hollow > 0.0:
		var d := _meadow_oval(Vector2(x, z))
		if d < 1.15:
			var half := Maze.CLEARING * Maze.CELL * 0.5
			var from_wall := half - maxf(absf(x), absf(z))
			var sunk := smoothstep(1.15, 0.85, d) * smoothstep(2.0, 16.0, from_wall)
			return lerpf(hill, -tall_grass_hollow, sunk)
	return hill


## The ground as the hills' mesh and heightmap have it, a point every few
## metres (MazeBuilder.HILL_STEP): as height_at, but sunk out of sight under the
## marsh, which has finer ground of its own over it (Marsh).
func coarse_height_at(x: float, z: float, seed_value: int) -> float:
	var marsh := marsh_rect()
	if marsh.has_area() and marsh.grow(-MARSH_COARSE_MARGIN).has_point(Vector2(x, z)):
		return MARSH_LEVEL - marsh_pool_depth - 1.0
	return height_at(x, z, seed_value)


## Whether the ground is anything but level: hills, a marsh or a hollow.
func shaped() -> bool:
	return hill_height > 0.0 or not entrance(Entrance.MARSH).is_empty() or (tall_grass_hollow > 0.0 and tall_grass_middle().is_finite())


## The first entrance with `kind` in front of it, as [where (x, z), the way in],
## or [] if none has.
func entrance(kind: Entrance) -> Array:
	for i in mini(entrances.size(), entrance_spots.size()):
		if entrances[i] == kind:
			return entrance_spots[i]
	return []


## The square (x, z) the marsh lies in, its ragged edge and all, or an empty one
## if there is none.
func marsh_rect() -> Rect2:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return Rect2()
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	var grown := 1.0 + marsh_ragged * 0.7
	var middle := gate + inward * (marsh_distance + marsh_reach * 0.5)
	var rect := Rect2(gate, Vector2.ZERO)
	for across: Vector2 in [side, -side]:
		rect = rect.expand(gate + across * marsh_width * 0.5 * grown)
		rect = rect.expand(middle + inward * marsh_reach * 0.5 * grown + across * marsh_width * 0.5 * grown)
	var half := Maze.CLEARING * Maze.CELL * 0.5
	return rect.grow(2.0).intersection(Rect2(-half, -half, half * 2.0, half * 2.0))


## How far into the marsh `point` (x, z) is: 1 well inside it, falling to 0 at
## its ragged edge and just out from the foot of the wall (but for the flooded
## way in to its gate, which is wet to the wall).
func marsh_wet_at(point: Vector2, seed_value: int) -> float:
	return maxf(_marsh_wet_at(point, seed_value), marsh_flood_at(point, seed_value))


## How far behind the face of the clearing's wall the flooded way in to the
## marsh's gate goes on (the hills' ground under the wall, and the slot through it).
const FLOOD_BEHIND := 8.0


## How far into the flooded way in to the marsh's gate `point` (x, z) is: 1 in
## it, 0 out of it, raggedly between. It lies in front of the gate, from the
## foot of the wall (and on under it) out into the marsh.
func marsh_flood_at(point: Vector2, seed_value: int) -> float:
	if marsh_flood_depth <= 0.0:
		return 0.0
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return 0.0
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(way[1])
	if out < -FLOOD_BEHIND:
		return 0.0
	var along := absf(from_gate.dot((way[1] as Vector2).orthogonal()))
	var oval := Vector2(along / (marsh_flood_width * 0.5), maxf(out, 0.0) / marsh_flood_reach).length()
	if oval > 1.3:
		return 0.0
	var ragged := _marsh_noise(seed_value).get_noise_2d(point.x / 13.0 + 140.0, point.y / 13.0 - 60.0) * 0.18
	return smoothstep(1.05, 0.8, oval + ragged)


## How deep the water of the flooded way is over its ground at `point` (x, z):
## the flood depth at the wall and through its gate, a little shallower here
## and there further out.
func marsh_flood_depth_at(point: Vector2, seed_value: int) -> float:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return marsh_flood_depth
	var out := (point - (way[0] as Vector2)).dot(way[1])
	var lie := _marsh_noise(seed_value).get_noise_2d(point.x / 7.0 - 90.0, point.y / 7.0 + 35.0) * 0.5 + 0.5
	return marsh_flood_depth * lerpf(1.0, 0.7 + 0.3 * lie, smoothstep(10.0, 22.0, out))


## The square (x, z) the flooded way lies over in front of the gate, from the
## wall's face (and FLOOD_BEHIND under it) out (empty if there is none).
func marsh_flood_rect() -> Rect2:
	var way := entrance(Entrance.MARSH)
	if way.is_empty() or marsh_flood_depth <= 0.0:
		return Rect2()
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal() * marsh_flood_width * 0.5 * 1.3
	var rect := Rect2(gate - inward * FLOOD_BEHIND, Vector2.ZERO)
	for corner: Vector2 in [gate - inward * FLOOD_BEHIND + side, gate - inward * FLOOD_BEHIND - side, gate + inward * marsh_flood_reach * 1.3 + side, gate + inward * marsh_flood_reach * 1.3 - side]:
		rect = rect.expand(corner)
	return rect


func _marsh_wet_at(point: Vector2, seed_value: int) -> float:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return 0.0
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var out := (point - gate).dot(inward)
	if out <= marsh_distance:
		return 0.0
	var oval := _marsh_oval(point, way)
	if oval >= 1.0 + marsh_ragged * 0.7:
		return 0.0
	var noise := _marsh_noise(seed_value)
	var edge := clampf((noise.get_noise_2d(point.x / 55.0, point.y / 55.0) * 0.75 + noise.get_noise_2d(point.x / 17.0 + 50.0, point.y / 17.0) * 0.25) * 1.3, -1.0, 1.0)
	oval /= 1.0 + marsh_ragged * 0.7 * edge
	return smoothstep(1.0, 0.7, oval) * smoothstep(marsh_distance, marsh_distance + 7.0, out)


## How deep the marsh's water is over the ground at `point` (x, z), metres
## (less than 0 where the ground stands up out of it, or there is no marsh).
func marsh_depth_at(point: Vector2, seed_value: int) -> float:
	if marsh_wet_at(point, seed_value) <= 0.0:
		return -1.0
	return MARSH_LEVEL - height_at(point.x, point.y, seed_value)


## 1 in the lane out from the flooded entrance's gate (MARSH_LANE), where
## nothing deep is and nothing stands in the way, 0 out of it.
func marsh_lane_at(point: Vector2) -> float:
	var way := entrance(Entrance.MARSH)
	if way.is_empty():
		return 0.0
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(way[1])
	var along := absf(from_gate.dot((way[1] as Vector2).orthogonal()))
	if out < -2.0:
		return 0.0
	return (1.0 - smoothstep(MARSH_LANE.x, MARSH_LANE.x * 2.0, along)) * (1.0 - smoothstep(MARSH_LANE.y, MARSH_LANE.y * 1.5, out))


## Whether the clearing's knee high grass gives way at `point` (x, z) to the
## marsh's own sedges (Marsh): more and more of it towards the marsh, none
## well inside it.
func marsh_keeps_grass_out(point: Vector2, seed_value: int) -> bool:
	var wet := marsh_wet_at(point, seed_value)
	if wet <= 0.05:
		return false
	# (dithered, so that there is no line where the one gives way to the other)
	return wet > 0.08 + float(hash(point) & 1023) / 1023.0 * 0.35


## Whether `point` (x, z) is where no tree or bush may be: near a clear entrance,
## in the tall grass, or in or at the edge of the marsh.
func kept_clear(point: Vector2) -> bool:
	var clear := entrance(Entrance.CLEAR)
	if not clear.is_empty() and point.distance_to(clear[0]) < clear_radius:
		return true
	if _meadow_oval(point) < 1.05:
		return true
	var marsh := entrance(Entrance.MARSH)
	return not marsh.is_empty() and _marsh_oval(point, marsh) < 1.0 + marsh_ragged * 0.7 + 0.1


## How much tall grass there is at `point` (x, z): 1 in the meadow in front of a
## tall grass entrance, none past its edge.
func tall_grass_at(point: Vector2) -> float:
	# (a meadow of its own: its edge sharp, where the hollow begins)
	return smoothstep(1.02, 0.95, _meadow_oval(point))


## The middle of the tall grass (x, z), half its reach out from its gate, or
## not finite if there is none.
func tall_grass_middle() -> Vector2:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return Vector2.INF
	return way[0] + way[1] * tall_grass_reach * 0.5


## The square (x, z) the tall grass lies in, its ragged edge and all (an empty
## one if there is none), within the clearing.
func tall_grass_rect() -> Rect2:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return Rect2()
	var gate: Vector2 = way[0]
	var inward: Vector2 = way[1]
	var side := inward.orthogonal()
	var grown := 1.0 + tall_grass_ragged + 0.05
	var rect := Rect2(gate - inward * 2.0, Vector2.ZERO)
	for across: Vector2 in [side, -side]:
		rect = rect.expand(gate - inward * 2.0 + across * tall_grass_width * 0.5 * grown)
		rect = rect.expand(gate + inward * tall_grass_reach * grown + across * tall_grass_width * 0.5 * grown)
	var half := Maze.CLEARING * Maze.CELL * 0.5
	return rect.intersection(Rect2(-half, -half, half * 2.0, half * 2.0))


## A place (x, z) at random in the tall grass, well in from its edge (not
## finite if there is none).
func tall_grass_spot(rng: RandomNumberGenerator) -> Vector2:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return Vector2.INF
	var round_about := rng.randf_range(0.0, PI)
	var out := sqrt(rng.randf()) * 0.8
	return (way[0] as Vector2) + (way[1] as Vector2) * sin(round_about) * out * tall_grass_reach \
		+ (way[1] as Vector2).orthogonal() * cos(round_about) * out * tall_grass_width * 0.5


# How far out in the tall grass's half oval `point` is: 1 at its ragged edge,
# 0 at the foot of the wall in front of its gate, INF if there is no tall grass
# or the point is behind the wall.
func _meadow_oval(point: Vector2) -> float:
	var way := entrance(Entrance.TALL_GRASS)
	if way.is_empty():
		return INF
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(way[1])
	if out < -2.0:
		return INF
	var along := from_gate.dot((way[1] as Vector2).orthogonal())
	var oval := Vector2(along / (tall_grass_width * 0.5), maxf(out, 0.0) / tall_grass_reach).length()
	if oval > 1.0 + tall_grass_ragged + 0.2:
		return oval
	# (its edge wandering in and out, in bays and spits some tens of metres across)
	if _meadow_edge == null:
		_meadow_edge = FastNoiseLite.new()
		_meadow_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_meadow_edge.seed = 31
		_meadow_edge.frequency = 1.0 / 45.0
		_meadow_edge.fractal_octaves = 2
	return oval / (1.0 + tall_grass_ragged * _meadow_edge.get_noise_2d(point.x, point.y))


func _hill_at(x: float, z: float, seed_value: int) -> float:
	if hill_height <= 0.0:
		return 0.0
	var half := Maze.CLEARING * Maze.CELL * 0.5
	var from_wall := half - maxf(absf(x), absf(z))
	if from_wall <= flat_border_width:
		return 0.0
	var from_middle := Vector2(x, z).length()
	if from_middle <= flat_radius:
		return 0.0
	var shown := smoothstep(flat_radius, flat_radius + hill_rise_distance, from_middle) * smoothstep(flat_border_width, flat_border_width + hill_rise_distance, from_wall)
	return hill_height * shown * (_hill_noise(seed_value).get_noise_2d(x, z) * 0.5 + 0.5)


func _hill_noise(seed_value: int) -> FastNoiseLite:
	if _noise == null or _noise_seed != seed_value:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = seed_value
		_noise.frequency = 1.0 / hill_spacing
		_noise.fractal_octaves = 2
		_noise_seed = seed_value
	return _noise


# How far out in the marsh's oval `point` is (1 at its edge before it is made
# ragged), for the marsh entrance `way`; INF behind its gate.
func _marsh_oval(point: Vector2, way: Array) -> float:
	var inward: Vector2 = way[1]
	var from_gate: Vector2 = point - way[0]
	var out := from_gate.dot(inward)
	if out < 0.0:
		return INF
	var half_reach := marsh_reach * 0.5
	return Vector2((out - marsh_distance - half_reach) / half_reach, from_gate.dot(inward.orthogonal()) / (marsh_width * 0.5)).length()


# How high the marsh's ground stands over its water at `point` (less than 0
# under it): hummocks and tussocks standing up out of shallow water, channels
# winding between them, and a few deep pools; drier towards its edge, as `wet`
# falls (marsh_wet_at).
func _marsh_lie(point: Vector2, wet: float, seed_value: int) -> float:
	var noise := _marsh_noise(seed_value)
	var p := point / marsh_hummock_size
	var lumps := noise.get_noise_2d(p.x, p.y) * 0.65 + noise.get_noise_2d(p.x * 2.3 + 17.0, p.y * 2.3 - 5.0) * 0.35
	var lie := lumps * 0.5 + 0.5
	# (channels: where a slower noise crosses its middle, in winding lines)
	var wander := absf(noise.get_noise_2d(p.x * 0.26 - 40.0, p.y * 0.26 + 23.0))
	lie -= (1.0 - smoothstep(0.02, 0.15, wander)) * marsh_channels * 0.5
	# (the water standing over about the share of it asked for; less near its
	# edge; and over broad stretches more of it, open meres, or less, flats of
	# tussocks, so that it is not the same all over)
	var broad := noise.get_noise_2d(point.x / 42.0 - 70.0, point.y / 42.0 + 12.0)
	var level := 0.5 + (marsh_water - 0.5) * 0.5 - (1.0 - wet) * 0.35 + broad * 0.2
	var over := lie - level
	var height := 0.42 * (1.0 - exp(-over * 4.0)) if over > 0.0 else -marsh_shallow_depth * (1.0 - exp(over * 5.0))
	# (the deep pools: well inside it, never in the lane in from the gate)
	var deep := noise.get_noise_2d(point.x / 26.0 + 80.0, point.y / 26.0 - 31.0) * 0.5 + 0.5
	var start := 0.84 - marsh_deep_pools * 1.2
	var sunk := smoothstep(start, start + 0.12, deep) * smoothstep(0.55, 0.9, wet) * (1.0 - marsh_lane_at(point))
	return lerpf(height, minf(height, -marsh_pool_depth), sunk)


func _marsh_noise(seed_value: int) -> FastNoiseLite:
	if _marsh == null or _marsh_seed != seed_value:
		_marsh = FastNoiseLite.new()
		_marsh.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_marsh.seed = seed_value + 7
		_marsh.frequency = 1.0
		_marsh.fractal_type = FastNoiseLite.FRACTAL_NONE
		_marsh_seed = seed_value
	return _marsh
