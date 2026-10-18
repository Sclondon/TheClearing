@tool
class_name MazeStyle
extends Resource
## How one section of the maze is made (a ring round the clearing): its size, its
## walls, its hallways, the rules its passages are grown by, what grows and can be
## climbed on its walls, and what hunts it. Each section has its own
## (Maze.styles), so the maze changes in kind as the boy goes out through it.
##
## The passages are grown from the section's gates over blocks of hallway
## diameter x hallway diameter cells, each new block joined to one already
## reached: mostly from the newest, which makes long passages, now and then (side
## branch chance) from an older one, which makes side branches; going on the way
## it was going when it can (straight on chance), which makes long straight
## hallways. Then some of the walls left between hallways are knocked through
## (loop share), so there is more than one way round.
##
## A cell is Maze.CELL (14 m) across, from the middle of one wall to the next.

@export_group("Size")
## Round: rings of passages between circular walls (see RoundMaze), not square.
## Set by being a RoundStyle (MazeLayout's round sections), not in the inspector.
@export var round_section := false
## How wide the section is, in cells: from the border wall round its inside to the
## one round its outside (on each side). The extra thickness of the wall round its
## inside (the clearing's, or the section inside it's) is on top of this.
@export_range(1, 16) var section_width_cells := 4
## How wide its hallways are, in cells.
@export_range(1, 4) var hallway_diameter_cells := 1
## How many gates lead into it from the section inside it, spread round the wall
## between them. (The first section's are the clearing's four, one on each side.)
@export_range(1, 8) var entrance_count := 1

@export_group("Walls")
## How thick the maze walls inside the section are, metres. (A way through a wall
## one cell long is a slot a cell wide less this.)
@export_range(0.5, 13.0) var maze_wall_diameter := 3.2
## How high the maze walls inside the section are, metres.
@export_range(8.0, 120.0) var maze_wall_height := 34.0
## How high the border wall round the outside of the section is, metres: the wall
## between it and the next section out (for the last square section, the wall out
## to the desert; for the last round one, the wall round the whole maze), and the
## walls beside its gates. The clearing's own wall is ClearingStyle's.
@export_range(20.0, 300.0) var section_border_wall_height := 46.0
## How many cells of solid wall thicken that border wall (each gate a slot through
## them): the next section out is moved that much further out. (Not for the last
## square section, nor round ones.)
@export_range(0, 6) var border_wall_thickness_cells := 0

@export_group("Hallways")
## The chance a passage goes on straight when it can.
@export_range(0.0, 1.0) var straight_on_chance := 0.0
## The chance a passage grows from an older place instead of the newest.
@export_range(0.0, 1.0) var side_branch_chance := 0.0
## The share of blocks with a wall knocked through afterwards.
@export_range(0.0, 0.5) var loop_share := 0.06
## How far each way in runs, in cells, as a narrow corridor (one cell wide) before
## it opens into the section's hallways; 0 (or 1) for none.
@export_range(0, 16) var entrance_corridor_cells := 0
## How wide the way through an entrance corridor is, metres: walls fill the rest
## of the cell either side of it (0: the whole cell is open).
@export_range(0.0, 12.0) var entrance_doorway_width := 0.0

@export_group("Mezzanine")
## How high the ledge along every wall face in the section is, metres, a mezzanine
## to walk along (0 for none). The same height along the higher border walls, so
## that it all joins up. Ivy up the walls grows to its edge, and vines hang past it.
@export_range(0.0, 100.0) var mezzanine_height := 0.0
## How deep it stands out from the wall, and how thick it is, metres.
@export_range(0.5, 4.0) var mezzanine_depth := 1.2
@export_range(0.2, 2.0) var mezzanine_thickness := 0.6
## How many levels of ledge there are, one over another (the first all along the
## walls, the ones over it only along some: platforms), and how far apart they
## are, metres.
@export_range(1, 5) var mezzanine_levels := 1
@export_range(3.0, 30.0) var mezzanine_level_rise := 8.0
## Of the wall faces with a level, the share with the level over it too.
@export_range(0.0, 1.0) var mezzanine_upper_share := 0.5
## How much shallower each level is than the one under it, metres: so they step
## back as they go up, and ivy hung from one's edge comes down onto the one under.
@export_range(0.0, 1.5) var mezzanine_depth_step := 0.6
## The share of wall faces with a level that have ivy up to the level over it.
@export_range(0.0, 1.0) var mezzanine_ivy_share := 0.2
## The share of halls with ledges at the same level both sides that have a rope
## bridge across between them, at each level.
@export_range(0.0, 1.0) var mezzanine_bridge_share := 0.0

@export_group("Climbing")
## The share of wall faces with a terrace against them: steps of stone like those
## of something far bigger than a boy, with ivy up their faces to climb.
@export_range(0.0, 1.0) var terrace_share := 0.13
## Of those, the share with an upper terrace set back above the lower.
@export_range(0.0, 1.0) var upper_terrace_share := 0.55
## The share of terraces matched by one across the hallway, with a rope bridge between.
@export_range(0.0, 1.0) var terrace_bridge_share := 0.45
## Of upper terraces, the share with ivy on up to the top of the wall.
@export_range(0.0, 1.0) var ivy_to_wall_top_share := 0.35
## The share of terraces with a vine to swing on, hung from a beam out over them.
@export_range(0.0, 1.0) var terrace_vine_share := 0.5
## The share of hallways with a rope bridge across from wall top to wall top.
@export_range(0.0, 1.0) var wall_top_bridge_share := 0.05
## The share of wall faces with climbable ivy from the ground: up to the mezzanine
## if there is one, otherwise part of the way up the wall (wall ivy height range,
## as shares of the wall's height), never to the top.
@export_range(0.0, 1.0) var wall_ivy_share := 0.0
@export var wall_ivy_height_range := Vector2(0.3, 0.6)
## The share of wall faces with a vine hanging from the top of such ivy, down to
## a jump over the ground.
@export_range(0.0, 1.0) var hanging_vine_share := 0.0
## The share of hallways with a vine strung across from wall to wall: walked as a
## tightrope from a buttress with ivy up it, and cut into two hanging vines. How
## high (tightrope vine height range), as shares of the lower wall's height.
@export_range(0.0, 1.0) var tightrope_vine_share := 0.0
@export var tightrope_vine_height_range := Vector2(0.3, 0.75)
## The share of maze walls with a sewer pipe through them, high up, dripping: a
## platform under each mouth with ivy up to it from the ground, so that he can
## climb to one, crawl through the wall and come down the other side. How high
## (sewer pipe height), as a share of the wall's height.
@export_range(0.0, 0.5) var sewer_pipe_share := 0.0
@export_range(0.2, 0.9) var sewer_pipe_height := 0.62

@export_group("Plants")
## How thickly ferns, moss and tufts of grass grow along the foot of its walls (0
## none, 1 all along every wall).
@export_range(0.0, 1.0) var plant_density := 0.0

@export_group("What hunts it")
## How many of each thing that hunts are put in the section's passages (by
## MazeEnemies.populate, from the round's seed). Packs and colonies count as one.
@export_range(0, 4) var snakes := 1
@export_range(0, 6) var mummy_packs := 2
## A ReDead-like ghoul each, standing in a dead end.
@export_range(0, 6) var ghouls := 2
@export_range(0, 3) var centipedes := 1
## Giant spiders, each waiting high on a wall.
@export_range(0, 4) var spiders := 2
@export_range(0, 3) var abominations := 1
## Walls of slime that fill a hallway.
@export_range(0, 3) var slime_walls := 1
@export_range(0, 4) var bat_colonies := 2
@export_range(0, 3) var baboon_troops := 1
## Pairs of aliens (each pack two or three).
@export_range(0, 3) var alien_packs := 1
## "Biblically accurate" angels (MazeAngel): wheels of eyes drifting over the
## halls, whose gaze takes whoever stays in it.
@export_range(0, 2) var angels := 1
@export_range(0, 3) var dog_packs := 1
## Swarms of beetles, each waiting in cracks at the foot of a wall (in a dead end or along a hall).
@export_range(0, 4) var beetle_swarms := 2
## Fish people, each lurking in a pool of black water in a hall.
@export_range(0, 6) var fish_people := 2
## Giant toads, each squatting in a dead end.
@export_range(0, 3) var frogs := 1
## Swarms of small frogs, each in a muddy pool in a dead end.
@export_range(0, 3) var frog_swarms := 1
## Amalgams: three or four bodies grown together, that shamble and cartwheel (and
## grow, absorbing whom they catch and merging when they meet).
@export_range(0, 4) var amalgams := 2
## Pairs: two bodies grown together back to back, that scuttle and rush (and
## grow as amalgams do: a pair that catches someone is an amalgam).
@export_range(0, 6) var pairs := 2
## Striders: five or six bodies joined at the hips in a ring that walks on all
## their legs and grabs with those facing you (and grows: past six, a mound).
@export_range(0, 3) var striders := 1
## Flesh mounds: many bodies grown together into a mound that nearly fills a hall.
@export_range(0, 3) var flesh_mounds := 1
## Harpies, each perched high on a wall (its ledge, or its top) over a hallway.
@export_range(0, 4) var harpies := 1
## Giant boars, each rooting in a dead end or a wide hall.
@export_range(0, 3) var boars := 1
## Flocks of feral chickens (a rooster and his hens), foraging in a hall.
@export_range(0, 4) var chicken_flocks := 2
## Gargoyles, each crouched as a statue on a ledge over a hall (a terrace's edge or a
## wall top), dropping on whoever passes beneath.
@export_range(0, 4) var gargoyles := 2
## Herds of deer (four or five each, one of them wrong), standing in the halls.
@export_range(0, 3) var deer_herds := 1
## Bull elk, each holding a stretch of halls as his own.
@export_range(0, 3) var elk := 1
## Gangs of tiny imps (three or four), each perched on a wall.
@export_range(0, 4) var imp_gangs := 2
## Swarms of imps, each a crack at the foot of a wall that dozens pour out of.
@export_range(0, 3) var imp_swarms := 1
## A colossus that crawls over the ring on its wall tops (one at most: it would
## stand 260 m tall). The Avenues and the Galleries, whose walls are thick and
## far apart, have one.
@export_range(0, 1) var colossi := 0
## Packs of coyotes (three to five each): skittish, they shadow people at a
## distance and yip, but three or more of them can grow bold round someone alone.
@export_range(0, 4) var coyote_packs := 2
## Skinwalkers, each hidden among a pack of coyotes as one of them (one more
## pack is put in for any there is no pack for).
@export_range(0, 2) var skinwalkers := 1
## Martian tripods (MazeTripod), each striding round the ring over the walls,
## its searchlight sweeping the halls. One at most: it is huge.
@export_range(0, 1) var tripods := 1
## Murders of crows (Crows), each sitting along the wall tops over a hall: they
## follow whoever passes along the walls, and erupt cawing at anyone who runs,
## which calls the hunters.
@export_range(0, 4) var crow_murders := 2

@export_group("Who else is in it")
## How many runners run the section's passages (MazeRunners, from the round's
## seed): other boys, driven by the computer, who know their section. They lead
## anyone who comes up to them to its gate out, draw what hunts away, and are
## hunted themselves. Each one poses a whole boy, so keep it small.
@export_range(0, 6) var runners := 2

@export_group("Wildlife")
## Herds of ordinary deer in the halls (Wildlife: peaceful, they run from you;
## not among what hunts it).
@export_range(0, 4) var wild_deer_herds := 1
@export_range(0, 4) var wild_elk_herds := 1
## Flocks of tame chickens (TameChickens), which hunt nobody, foraging in the halls.
@export_range(0, 4) var tame_chicken_flocks := 0
## Pairs of ravens (Ravens) on the wall tops, which hunt nobody: omens, that fly
## ahead of whoever comes near to sit over a hunter waiting there.
@export_range(0, 4) var raven_pairs := 2
## Insects (Insects): moths round each light in its halls (the angel, fires,
## the light past the exit), big moths resting on its walls that scatter as
## you pass, flies round each thing of meat in it (flesh mounds, the meat
## beast, the slime wall, the boar's lair, carcasses), and carcasses lying in
## its dead ends.
@export_range(0, 60) var moths_per_light := 18
@export_range(0, 30) var wall_moths := 8
@export_range(0, 80) var flies_per_carrion := 26
@export_range(0, 8) var carcasses := 3

@export_group("What lies about")
## Things left lying in its halls to find (Loot): in the ends of halls first
## (the most walls round them), then anywhere, never by its gates.
@export_range(0, 20) var loot_items := 6
## Camps left behind in its halls (cold fires, tallies scratched on the wall
## beside them, often signs of a struggle).
@export_range(0, 4) var abandoned_camps := 1

## For tests and tools: styles used in place of the defaults while set.
static var chosen: Array[MazeStyle] = []

## The names these settings had before (as saved in older mazes), and the new ones.
const RENAMED := {
	&"width": &"section_width_cells", &"section_depth_cells": &"section_width_cells", &"span": &"hallway_diameter_cells", &"wall_thick": &"maze_wall_diameter",
	&"rampart": &"border_wall_thickness_cells", &"inner_height": &"section_border_wall_height",
	&"straight": &"straight_on_chance", &"branching": &"side_branch_chance", &"loops": &"loop_share",
	&"entrance": &"entrance_corridor_cells", &"doorway": &"entrance_doorway_width",
	&"terraces": &"terrace_share", &"upper_terraces": &"upper_terrace_share", &"bridges": &"terrace_bridge_share",
	&"ivy_to_top": &"ivy_to_wall_top_share", &"terrace_vines": &"terrace_vine_share",
	&"top_bridges": &"wall_top_bridge_share", &"wall_ivy": &"wall_ivy_share", &"ivy_reach": &"wall_ivy_height_range",
	&"wall_vines": &"hanging_vine_share", &"strands": &"tightrope_vine_share",
	&"strand_reach": &"tightrope_vine_height_range", &"undergrowth": &"plant_density",
	&"ledge_depth": &"mezzanine_depth", &"ledge_thick": &"mezzanine_thickness",
}


func _validate_property(property: Dictionary) -> void:
	# (whether it is round is what kind of style it is: saved, not shown)
	if property.name == "round_section":
		property.usage = PROPERTY_USAGE_NO_EDITOR


# A maze saved with the old names still loads.
func _set(property: StringName, value: Variant) -> bool:
	if RENAMED.has(property):
		set(RENAMED[property], value)
		return true
	if property == &"ledge":
		# (it was a share of the maze walls' height)
		mezzanine_height = float(value) * maze_wall_height
		return true
	return false


static func made(depth_cells: int, hallway_cells: int, straightness: float, branches: float, loops: float, corridor := 0, door := 0.0, round := false) -> MazeStyle:
	var style: MazeStyle = RoundStyle.new() if round else MazeStyle.new()
	style.section_width_cells = depth_cells
	style.hallway_diameter_cells = hallway_cells
	style.straight_on_chance = straightness
	style.side_branch_chance = branches
	style.loop_share = loops
	style.entrance_corridor_cells = corridor
	style.entrance_doorway_width = door
	return style


## Avenues: the first section. The simplest maze, but big: hallways two cells wide
## (about 16 m between walls) that run long and straight, few turns and few side
## branches. Its maze walls are massive, 12 m thick, so each way through a wall a
## cell long is a slot about three of him wide. (The wall round the clearing, on
## its inside, is ClearingStyle's.) A mezzanine a third of the way up every wall, ivy up to it,
## vines hanging from it and strung across the hallways above it, plants at the
## foot of the walls, and sewer pipes through the walls high up.
static func avenues() -> MazeStyle:
	var style := made(6, 2, 0.5, 0.0, 0.0)
	style.maze_wall_diameter = 12.0
	style.mezzanine_height = style.maze_wall_height / 3.0
	style.terrace_share = 0.0
	style.wall_top_bridge_share = 0.0
	style.wall_ivy_share = 0.1
	style.hanging_vine_share = 0.08
	style.tightrope_vine_share = 0.12
	style.tightrope_vine_height_range = Vector2(0.45, 0.75)
	style.sewer_pipe_share = 0.08
	style.plant_density = 0.8
	style.harpies = 2
	style.colossi = 1
	return style


## Galleries: the second section. Hallways and walls like the Avenues', but up
## the walls levels of ledges step back one over another, the higher ones only
## here and there (platforms), with ivy from each up to the next and rope bridges
## across the hallways between them.
static func galleries() -> MazeStyle:
	var style := made(6, 2, 0.5, 0.0, 0.0)
	style.maze_wall_diameter = 12.0
	# (three ways in from the Avenues)
	style.entrance_count = 3
	style.mezzanine_height = 8.0
	style.mezzanine_depth = 2.4
	style.mezzanine_levels = 3
	style.mezzanine_level_rise = 8.0
	style.mezzanine_upper_share = 0.55
	style.mezzanine_depth_step = 0.6
	style.mezzanine_ivy_share = 0.25
	style.mezzanine_bridge_share = 0.2
	style.terrace_share = 0.0
	style.wall_top_bridge_share = 0.0
	style.wall_ivy_share = 0.1
	style.hanging_vine_share = 0.04
	style.plant_density = 0.6
	style.colossi = 1
	return style


## Narrows: a close maze of single hallways that wind and fork, with terraces, ivy,
## vines and rope bridges to climb.
static func narrows() -> MazeStyle:
	var style := made(4, 1, 0.0, 0.0, 0.06)
	# (three ways in from the Galleries)
	style.entrance_count = 3
	return style


## Tangle: single hallways that branch often and loop back on themselves, so that
## there are many ways and it is easy to go round in circles.
static func tangle() -> MazeStyle:
	return made(4, 1, 0.3, 0.5, 0.2)


## Spokes: the first round section, past the moor. Hallways two cells wide, long
## and straight, round and out like the spokes and rims of a wheel.
static func spokes() -> MazeStyle:
	var style := made(4, 2, 0.6, 0.0, 0.05, 0, 0.0, true)
	style.maze_wall_diameter = 4.0
	return style


## Whorl: single hallways that wind round and fork.
static func whorl() -> MazeStyle:
	var style := made(5, 1, 0.3, 0.3, 0.06, 0, 0.0, true)
	# (the wall out to the Labyrinth: as high as the Labyrinth's own round the whole)
	style.section_border_wall_height = 60.0
	return style


## Thicket: single hallways that branch often and loop back on themselves.
static func thicket() -> MazeStyle:
	var style := made(5, 1, 0.1, 0.5, 0.18, 0, 0.0, true)
	return style


## The Labyrinth: the last section, single hallways that wind and dead-end, under
## the highest walls of all.
static func labyrinth() -> MazeStyle:
	var style := made(6, 1, 0.0, 0.1, 0.03, 0, 0.0, true)
	style.maze_wall_height = 46.0
	style.section_border_wall_height = 60.0
	return style


## The styles of the sections, from the clearing out, when a maze is not given its own.
static func defaults() -> Array[MazeStyle]:
	if not chosen.is_empty():
		return chosen
	return square_defaults() + round_defaults()


## The game's own square sections, and its own round ones.
static func square_defaults() -> Array[MazeStyle]:
	return [avenues(), galleries(), narrows()]


static func round_defaults() -> Array[MazeStyle]:
	return [spokes(), whorl(), labyrinth()]
