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
## Each thing on or about its walls (terraces, ivy, vines, vents, pipes...) has a
## box to turn it on or off (the user, 2026-10-18: "there should be check boxes to
## turn on and off each feature for the section in the editor"); its settings show
## under the box while it is on. Shares are 0 to 1 (0.25: a quarter of them).
##
## A cell is Maze.CELL (14 m) across, from the middle of one wall to the next.

@export_group("Size")
## Round: rings of passages between circular walls (see RoundMaze), not square.
## Set by being a RoundStyle (MazeLayout's round sections), not in the inspector.
@export var round_section := false
## How wide the section is, in cells (14 m each), from the wall round its inside to the one round its outside.
@export_range(1, 16, 1, "suffix:cells") var section_width_cells := 4
## How wide its hallways are, in cells (14 m each).
@export_range(1, 4, 1, "suffix:cells") var hallway_diameter_cells := 1
## How many gates lead into it from the section inside it, spread round the wall between them.
@export_range(1, 8, 1, "suffix:gates") var entrance_count := 1

@export_group("Walls")
## How thick the maze walls inside the section are, metres (a way through one is a cell less this wide).
@export_range(0.5, 13.0, 0.001, "suffix:m") var maze_wall_diameter := 3.2
## How high the maze walls inside the section are, metres.
@export_range(8.0, 120.0, 0.001, "suffix:m") var maze_wall_height := 34.0
## How high the border wall round the outside of the section is, metres (and the walls beside its gates).
@export_range(20.0, 300.0, 0.001, "suffix:m") var section_border_wall_height := 46.0
## How many cells of solid wall thicken that border wall, moving the next section out (not the last ones).
@export_range(0, 6, 1, "suffix:cells") var border_wall_thickness_cells := 0
## How high moss grows up the foot of its walls, metres (its top edge ragged; 0: none).
@export_range(0.0, 8.0, 0.001, "suffix:m") var wall_moss_height := 1.2
## How much of its walls' faces have patches of moss higher up (a share, 0 to 1; 0: none).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var wall_moss_patches := 0.12
## How many times its own size the concrete texture is laid on the maze walls and their ledges.
@export_range(0.5, 12.0, 0.001, "suffix:x") var wall_texture_scale := 4.0
## How far round the maze walls' top edges and corners are worn, metres (ledges half this; 0: square).
@export_range(0.0, 0.6, 0.01, "suffix:m") var wall_edge_rounding := 0.14
## How far round the border wall's edges are worn, metres (and the clearing's, for the first section).
@export_range(0.0, 1.5, 0.01, "suffix:m") var border_wall_edge_rounding := 0.4
## How weathered its walls are: grime under their tops, paler chipped corners, uneven faces (0 none, 1 most).
@export_range(0.0, 1.0, 0.01) var wall_weathering := 0.5

@export_group("Hallways")
## The chance a passage goes on straight when it can (0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:chance") var straight_on_chance := 0.0
## The chance a passage grows from an older place instead of the newest, making side branches (0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:chance") var side_branch_chance := 0.0
## How many blocks get a wall knocked through afterwards, making loops (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of blocks") var loop_share := 0.06
## How far each way in runs as a narrow corridor before it opens into the hallways, in cells (0 or 1: none).
@export_range(0, 16, 1, "suffix:cells") var entrance_corridor_cells := 0
## How wide the way through an entrance corridor is, metres; walls fill the rest of the cell (0: all open).
@export_range(0.0, 12.0, 0.001, "suffix:m") var entrance_doorway_width := 0.0

@export_group("Climbing")
@export_subgroup("Mezzanine (ledges)")
## How high the ledge along every wall face is, metres, a mezzanine to walk along (0: none).
@export_range(0.0, 100.0, 0.001, "suffix:m") var mezzanine_height := 0.0
## How deep the ledge stands out from the wall, metres.
@export_range(0.5, 4.0, 0.001, "suffix:m") var mezzanine_depth := 1.2
## How thick the ledge is, metres.
@export_range(0.2, 2.0, 0.001, "suffix:m") var mezzanine_thickness := 0.6
## How many levels of ledge there are, one over another (those over the first only along some faces).
@export_range(1, 5, 1, "suffix:levels") var mezzanine_levels := 1
## How far apart the levels are, one over the next, metres.
@export_range(3.0, 30.0, 0.001, "suffix:m") var mezzanine_level_rise := 8.0
## Of the faces with a level, how many have the level over it too (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var mezzanine_upper_share := 0.5
## How much shallower each level is than the one under it, metres (so they step back going up).
@export_range(0.0, 1.5, 0.001, "suffix:m") var mezzanine_depth_step := 0.6

@export_subgroup("Terraces")
## Terraces: steps of stone against the walls, like those of something far bigger than a boy, ivy up their faces.
@export var terraces_on: bool:
	get:
		return feature_on(&"terraces_on")
	set(value):
		_switch(&"terraces_on", value)
## How many wall faces have a terrace against them (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var terrace_share := 0.13
## Of terraces, how many have an upper terrace set back above the lower (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of terraces") var upper_terrace_share := 0.55

@export_subgroup("Rope bridges")
## Rope bridges between terraces: a terrace matched by one across the hallway, a bridge between them.
@export var terrace_bridges_on: bool:
	get:
		return feature_on(&"terrace_bridges_on")
	set(value):
		_switch(&"terrace_bridges_on", value)
## How many terraces are matched by one across the hallway, with a rope bridge (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of terraces") var terrace_bridge_share := 0.45
## Rope bridges across hallways from wall top to wall top.
@export var wall_top_bridges_on: bool:
	get:
		return feature_on(&"wall_top_bridges_on")
	set(value):
		_switch(&"wall_top_bridges_on", value)
## How many hallways have a rope bridge from wall top to wall top (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var wall_top_bridge_share := 0.05
## Rope bridges across hallways between mezzanine ledges at the same level.
@export var mezzanine_bridges_on: bool:
	get:
		return feature_on(&"mezzanine_bridges_on")
	set(value):
		_switch(&"mezzanine_bridges_on", value)
## How many halls with ledges level both sides have a rope bridge between them, at each level (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var mezzanine_bridge_share := 0.0

@export_subgroup("Concrete bridges")
## Arched concrete bridges across the hallways between mezzanine ledges at the same level (over the first), walked
## across, with ivy up to each end from the floor, level by level (the user's concept of the second section).
@export var concrete_bridges_on: bool:
	get:
		return feature_on(&"concrete_bridges_on")
	set(value):
		_switch(&"concrete_bridges_on", value)
## How many halls with ledges level both sides have a concrete bridge between them, at each level over the first (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var concrete_bridge_share := 0.3
## How high the arch under a bridge rises from its ends to its middle, metres.
@export_range(0.0, 8.0, 0.01, "suffix:m") var concrete_bridge_arch_rise := 2.2
## How wide a bridge's deck is, metres.
@export_range(1.0, 8.0, 0.01, "suffix:m") var concrete_bridge_width := 3.0
## Vines hanging from the side of a concrete bridge, down past the level under it (to the one under that, or the floor).
@export var bridge_hanging_vines_on: bool:
	get:
		return feature_on(&"bridge_hanging_vines_on")
	set(value):
		_switch(&"bridge_hanging_vines_on", value)
## How many concrete bridges have a vine hanging from them (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of bridges") var bridge_hanging_vine_share := 0.6

@export_group("Ivy")
## Climbable ivy up the walls from the ground: to the mezzanine if there is one, else part way up, never to the top.
@export var wall_ivy_on: bool:
	get:
		return feature_on(&"wall_ivy_on")
	set(value):
		_switch(&"wall_ivy_on", value)
## How many wall faces have ivy from the ground (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var wall_ivy_share := 0.0
## How high that ivy reaches with no mezzanine: lowest and highest, as shares of the wall's height (0 to 1).
@export var wall_ivy_height_range := Vector2(0.3, 0.6)
## Ivy on from an upper terrace up to the top of the wall.
@export var ivy_to_wall_top_on: bool:
	get:
		return feature_on(&"ivy_to_wall_top_on")
	set(value):
		_switch(&"ivy_to_wall_top_on", value)
## Of upper terraces, how many have ivy on up to the top of the wall (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of terraces") var ivy_to_wall_top_share := 0.35
## Ivy from the edge of each mezzanine level up to the level over it.
@export var mezzanine_ivy_on: bool:
	get:
		return feature_on(&"mezzanine_ivy_on")
	set(value):
		_switch(&"mezzanine_ivy_on", value)
## Of the faces with a level over the first, how many have ivy up to it (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var mezzanine_ivy_share := 0.2

@export_group("Vines")
## Vines hanging from the top of a run of wall ivy (its own, with wall ivy off), down to a jump over the ground.
@export var hanging_vines_on: bool:
	get:
		return feature_on(&"hanging_vines_on")
	set(value):
		_switch(&"hanging_vines_on", value)
## How many wall faces have ivy with a vine hanging from its top (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var hanging_vine_share := 0.0
## Vines strung across hallways wall to wall: walked as tightropes from a corbel with ivy under it, cut into two hanging vines.
@export var tightrope_vines_on: bool:
	get:
		return feature_on(&"tightrope_vines_on")
	set(value):
		_switch(&"tightrope_vines_on", value)
## How many hallways have a vine strung across (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var tightrope_vine_share := 0.0
## How high a strung vine is: lowest and highest, as shares of the lower wall's height (0 to 1).
@export var tightrope_vine_height_range := Vector2(0.3, 0.75)
## Vines to swing on over terraces, hung from a beam out of the wall.
@export var terrace_vines_on: bool:
	get:
		return feature_on(&"terrace_vines_on")
	set(value):
		_switch(&"terrace_vines_on", value)
## How many terraces have a vine over them (a share, 0 to 1; for the lower and the upper each).
@export_range(0.0, 1.0, 0.001, "suffix:of terraces") var terrace_vine_share := 0.5
## Pairs of stone brackets high over the ledges, across a hall from each other: ivy up to one from the ledge (and up to
## the ledge from the floor, both walls), and from it vines strung across to the other, swept down to the far ledge's
## edge and hanging down to its own ledge (only along walls with a ledge; the user's concept of the first section).
@export var bracket_vines_on: bool:
	get:
		return feature_on(&"bracket_vines_on")
	set(value):
		_switch(&"bracket_vines_on", value)
## How many halls with a ledge along both walls have a pair of brackets (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var bracket_vine_share := 0.3
## How high the brackets are over the ledge's top: lowest and highest, metres.
@export_custom(PROPERTY_HINT_RANGE, "1,80,0.1,suffix:m") var bracket_height_range := Vector2(7.0, 10.0)
## Vines strung across the hall between the edges of the ledges at the same level, both walls, walked as tightropes.
@export var ledge_strung_vines_on: bool:
	get:
		return feature_on(&"ledge_strung_vines_on")
	set(value):
		_switch(&"ledge_strung_vines_on", value)
## How many halls with ledges level both sides have a vine strung between them, at each level (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var ledge_strung_vine_share := 0.2
## Vines swept down across the hall, from the edge of a ledge to the edge of the one a level under it on the far wall.
@export var swept_vines_on: bool:
	get:
		return feature_on(&"swept_vines_on")
	set(value):
		_switch(&"swept_vines_on", value)
## How many halls with ledges both sides have a vine swept down across, at each level over the first (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var swept_vine_share := 0.25
## Vines hanging from the edge of each level of ledge down to the level under it, or the floor, to climb up to it.
@export var ledge_hanging_vines_on: bool:
	get:
		return feature_on(&"ledge_hanging_vines_on")
	set(value):
		_switch(&"ledge_hanging_vines_on", value)
## How many walls with a ledge have a vine hanging from its edge, at each level (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var ledge_hanging_vine_share := 0.1
## Vines grown straight out of a wall's face, roots and a bunch of leaves where they come out: some hang a random way
## down, some sweep down across the hall to the far wall or to the floor part way across (the user, 2026-10-18: "Vines
## should be able to connect directly to the wall and hang a random amount down across the hall as well").
@export var wall_vines_on: bool:
	get:
		return feature_on(&"wall_vines_on")
	set(value):
		_switch(&"wall_vines_on", value)
## How many wall faces have a vine grown out of them (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var wall_vine_share := 0.05
## How high up the wall they grow out: lowest and highest, metres over the floor (or the top ledge under them).
@export_custom(PROPERTY_HINT_RANGE, "1,60,0.1,suffix:m") var wall_vine_height_range := Vector2(4.0, 14.0)
## Of the vines out of a wall, how many sweep down across the hall instead of hanging (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of vines") var wall_vine_sweep_share := 0.45

@export_group("Wall decor")
## Old vents high on the walls: louvred or round, rusted, some of them big (dressing, nothing to climb).
@export var vents_on: bool:
	get:
		return feature_on(&"vents_on")
	set(value):
		_switch(&"vents_on", value)
## How many wall faces have a vent (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of faces") var wall_vent_share := 0.0
## Small pipes out of the walls a little up, a rust stain down the wall under each and a puddle at its foot.
@export var outlets_on: bool:
	get:
		return feature_on(&"outlets_on")
	set(value):
		_switch(&"outlets_on", value)
## How many wall faces have an outlet pipe (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of faces") var outlet_share := 0.0
## Of outlet pipes, how many drip (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of outlets") var outlet_drip_share := 0.6
## Old electric cables looped along the walls on brackets.
@export var wall_cables_on: bool:
	get:
		return feature_on(&"wall_cables_on")
	set(value):
		_switch(&"wall_cables_on", value)
## How many wall faces have a cable looped along them (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of faces") var wall_cable_share := 0.0

@export_group("Tunnels")
## Sewer pipes through the maze walls high up, dripping: a platform under each mouth, ivy up to it, crawled through.
@export var sewer_pipes_on: bool:
	get:
		return feature_on(&"sewer_pipes_on")
	set(value):
		_switch(&"sewer_pipes_on", value)
## How many maze walls have a sewer pipe through them (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of walls") var sewer_pipe_share := 0.0
## How high the pipe goes through, as a share of the wall's height (0.2 to 0.9).
@export_range(0.2, 0.9, 0.001, "suffix:of height") var sewer_pipe_height := 0.62
## Barred culverts at the foot of the walls, black behind the bars, a wet stain and a puddle in front.
@export var culverts_on: bool:
	get:
		return feature_on(&"culverts_on")
	set(value):
		_switch(&"culverts_on", value)
## How many wall faces have a culvert (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of faces") var culvert_share := 0.0
## Drain grates in the floor by a wall's foot, a puddle round some.
@export var drains_on: bool:
	get:
		return feature_on(&"drains_on")
	set(value):
		_switch(&"drains_on", value)
## How many hall cells have a drain grate (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of cells") var drain_share := 0.0
## Manhole covers out in the halls, now and then pushed half off the shaft.
@export var manholes_on: bool:
	get:
		return feature_on(&"manholes_on")
	set(value):
		_switch(&"manholes_on", value)
## How many hall cells have a manhole cover (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of cells") var manhole_share := 0.0

@export_group("Signs of life")
## Heaps of boxes and barrels left against the walls by those who lived here once (solid).
@export var clutter_on: bool:
	get:
		return feature_on(&"clutter_on")
	set(value):
		_switch(&"clutter_on", value)
## How many wall faces have a heap against them (a share, 0 to 0.5).
@export_range(0.0, 0.5, 0.001, "suffix:of faces") var clutter_share := 0.0
## How many things are in each heap: least and most (things).
@export var clutter_heap_size := Vector2i(3, 7)
## Of the things in a heap, how many are barrels, some fallen over (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of things") var clutter_barrel_share := 0.4
## Old electric cables strung across the halls high up, sagging, wall to wall.
@export var cables_on: bool:
	get:
		return feature_on(&"cables_on")
	set(value):
		_switch(&"cables_on", value)
## How many halls have a cable strung across (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var cable_share := 0.0
## How high the cables' ends are: lowest and highest, metres (never over the lower wall top).
@export var cable_height_range := Vector2(9.0, 22.0)
## Of cables across halls, how many are snapped, their two ends hanging (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of cables") var snapped_cable_share := 0.25
## Of the cables not snapped, how many have an old dead lamp hanging from them (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of cables") var cable_lamp_share := 0.3
## Cables beside the vines: in among the strung vines, and a cable's end beside the hanging ones.
@export var cables_by_vines_on: bool:
	get:
		return feature_on(&"cables_by_vines_on")
	set(value):
		_switch(&"cables_by_vines_on", value)
## How many strung vines have a cable beside them (a share, 0 to 1; hanging vines 0.6 of this).
@export_range(0.0, 1.0, 0.001, "suffix:of vines") var cable_by_vine_share := 0.0
## Old junction boxes high on both walls of a hall over the ledges, the cable between them grown over by a vine
## (walked as a tightrope; only along walls with a ledge).
@export var junction_boxes_on: bool:
	get:
		return feature_on(&"junction_boxes_on")
	set(value):
		_switch(&"junction_boxes_on", value)
## How many halls with a ledge along both walls have a pair of junction boxes (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var junction_box_share := 0.15
## How high the junction boxes are over the ledge's top: lowest and highest, metres.
@export_custom(PROPERTY_HINT_RANGE, "1,80,0.1,suffix:m") var junction_box_height_range := Vector2(11.0, 14.0)
## Old cables slanting across the halls, from high on one wall down to the other (only along walls with a ledge).
@export var slanting_cables_on: bool:
	get:
		return feature_on(&"slanting_cables_on")
	set(value):
		_switch(&"slanting_cables_on", value)
## How many halls with a ledge along both walls have a cable slanting across (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var slanting_cable_share := 0.15
## How high a slanting cable's ends are over the ledge's top: its low end and its high end, metres.
@export_custom(PROPERTY_HINT_RANGE, "0,80,0.1,suffix:m") var slanting_cable_heights := Vector2(4.0, 17.0)
## Old cables from a ledge's edge across and down to the wall under the ledge opposite, fixed there, hanging on to the floor.
@export var ledge_cables_on: bool:
	get:
		return feature_on(&"ledge_cables_on")
	set(value):
		_switch(&"ledge_cables_on", value)
## How many halls with a ledge along both walls have a cable down from a ledge (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of halls") var ledge_cable_share := 0.12
## How high a ledge cable is fixed on the far wall, as a share of the ledge's height (0 to 1).
@export_range(0.1, 0.95, 0.001, "suffix:of ledge height") var ledge_cable_fix_height := 0.6

@export_group("Grappling hook spots")
## Routes up bare maze walls for the hook: corbels one above another, an iron ring from each, to a last at the top.
@export var grapple_routes_on: bool:
	get:
		return feature_on(&"grapple_routes_on")
	set(value):
		_switch(&"grapple_routes_on", value)
## How many maze wall faces have a route up them (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var grapple_route_share := 0.03
## How far apart a route's corbels are at most, metres (the hook reaches 13 m).
@export_range(3.0, 11.0, 0.001, "suffix:m") var grapple_route_rise := 6.5
## Iron rings at the lips of ledges (mezzanine levels, terraces, the platforms under pipes) showing where the hook bites.
@export var grapple_rings_on: bool:
	get:
		return feature_on(&"grapple_rings_on")
	set(value):
		_switch(&"grapple_rings_on", value)
## How many ledge edges have a ring at their lip (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of ledges") var grapple_ring_share := 0.2
## Iron hooks and old pipes sticking out of the walls high over the halls, to swing from.
@export var grapple_swings_on: bool:
	get:
		return feature_on(&"grapple_swings_on")
	set(value):
		_switch(&"grapple_swings_on", value)
## How many maze wall faces have a hook or pipe to swing from (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var grapple_swing_share := 0.04
## How high a swing hook is over the ground or the highest ledge on the face: lowest and highest, metres.
@export var grapple_swing_height_range := Vector2(7.0, 10.5)

@export_group("Plants")
## Ferns, moss and tufts of grass along the foot of the walls.
@export var undergrowth_on: bool:
	get:
		return feature_on(&"undergrowth_on")
	set(value):
		_switch(&"undergrowth_on", value)
## How thickly the undergrowth grows along the walls' feet (0 none, 1 all along every wall).
@export_range(0.0, 1.0, 0.001, "suffix:density") var plant_density := 0.0
## Short grass along the foot of the walls, in runs of a few metres.
@export var wall_grass_on: bool:
	get:
		return feature_on(&"wall_grass_on")
	set(value):
		_switch(&"wall_grass_on", value)
## How many wall faces have grass along their foot (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var wall_grass_share := 0.25

@export_group("Water")
## Ponds: standing water in the halls (Ponds), the ground going down under it so he wades, and in the deepest swims.
@export var ponds_on: bool:
	get:
		return feature_on(&"ponds_on")
	set(value):
		_switch(&"ponds_on", value)
## How many hall cells have standing water, a pond or a flooded stretch (a share, 0 to 0.3).
@export_range(0.0, 0.3, 0.001, "suffix:of cells") var pond_share := 0.02
## How deep a pond is: shallowest and deepest, metres (to his waist at 0.8).
@export var pond_depth_range := Vector2(0.15, 0.8)
## Flooded halls: a stretch of hall under water from wall to wall, instead of a pond lying within one cell.
@export var flooded_halls_on: bool:
	get:
		return feature_on(&"flooded_halls_on")
	set(value):
		_switch(&"flooded_halls_on", value)
## Of the standing water, how much floods a stretch of hall (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of ponds") var flooded_hall_share := 0.4
## How long a flooded stretch is at most, in cells.
@export_range(2, 8, 1, "suffix:cells") var flooded_hall_length := 4
## Ponds deep enough to swim.
@export var swim_ponds_on: bool:
	get:
		return feature_on(&"swim_ponds_on")
	set(value):
		_switch(&"swim_ponds_on", value)
## How many ponds are deep enough to swim (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of ponds") var swim_pond_share := 0.12
## How deep a swimming pond is, metres.
@export_range(1.0, 3.0, 0.001, "suffix:m") var swim_pond_depth := 1.7
## Schools of small fish in the ponds, that dart off from whoever wades near.
@export var fish_on: bool:
	get:
		return feature_on(&"fish_on")
	set(value):
		_switch(&"fish_on", value)
## How many ponds (no shallower than FishSchool.SHALLOWEST) have a school of fish (a share, 0 to 1).
@export_range(0.0, 1.0, 0.001, "suffix:of ponds") var fish_share := 0.6
## How many fish are in each school.
@export_range(1, 40, 1, "suffix:fish") var fish_per_school := 12

@export_group("What hunts it")
## Snakes in the section's passages (how many of each thing that hunts are put in the section, from the round's seed).
@export_range(0, 4, 1, "suffix:snakes") var snakes := 1
## Packs of mummies in the section.
@export_range(0, 6, 1, "suffix:packs") var mummy_packs := 2
## A ReDead-like ghoul each, standing in a dead end.
@export_range(0, 6, 1, "suffix:ghouls") var ghouls := 2
## Giant centipedes in the section.
@export_range(0, 3, 1, "suffix:centipedes") var centipedes := 1
## Giant spiders, each waiting high on a wall.
@export_range(0, 4, 1, "suffix:spiders") var spiders := 2
## Abominations in the section.
@export_range(0, 3, 1, "suffix:abominations") var abominations := 1
## Walls of slime that fill a hallway.
@export_range(0, 3, 1, "suffix:walls") var slime_walls := 1
## Colonies of bats in the section.
@export_range(0, 4, 1, "suffix:colonies") var bat_colonies := 2
## Troops of baboons in the section.
@export_range(0, 3, 1, "suffix:troops") var baboon_troops := 1
## Pairs of aliens (each pack two or three).
@export_range(0, 3, 1, "suffix:packs") var alien_packs := 1
## "Biblically accurate" angels (MazeAngel): wheels of eyes drifting over the
## halls, whose gaze takes whoever stays in it.
@export_range(0, 2, 1, "suffix:angels") var angels := 1
## Packs of dogs in the section.
@export_range(0, 3, 1, "suffix:packs") var dog_packs := 1
## Swarms of beetles, each waiting in cracks at the foot of a wall (in a dead end or along a hall).
@export_range(0, 4, 1, "suffix:swarms") var beetle_swarms := 2
## Fish people, each lurking in a pool of black water in a hall.
@export_range(0, 6, 1, "suffix:fish people") var fish_people := 2
## Giant toads, each squatting in a dead end.
@export_range(0, 3, 1, "suffix:toads") var frogs := 1
## Swarms of small frogs, each in a muddy pool in a dead end.
@export_range(0, 3, 1, "suffix:swarms") var frog_swarms := 1
## Amalgams: three or four bodies grown together, that shamble and cartwheel (and
## grow, absorbing whom they catch and merging when they meet).
@export_range(0, 4, 1, "suffix:amalgams") var amalgams := 2
## Pairs: two bodies grown together back to back, that scuttle and rush (and
## grow as amalgams do: a pair that catches someone is an amalgam).
@export_range(0, 6, 1, "suffix:pairs") var pairs := 2
## Striders: five or six bodies joined at the hips in a ring that walks on all
## their legs and grabs with those facing you (and grows: past six, a mound).
@export_range(0, 3, 1, "suffix:striders") var striders := 1
## Balls: seven or eight bodies grown into a sphere that rolls after you, faster
## and faster down a straight hall, slow to turn a corner (and grows: past eight, a mound).
@export_range(0, 3, 1, "suffix:balls") var balls := 1
## Flesh mounds: many bodies grown together into a mound that nearly fills a hall.
@export_range(0, 3, 1, "suffix:mounds") var flesh_mounds := 1
## Harpies, each perched high on a wall (its ledge, or its top) over a hallway.
@export_range(0, 4, 1, "suffix:harpies") var harpies := 1
## Giant boars, each rooting in a dead end or a wide hall.
@export_range(0, 3, 1, "suffix:boars") var boars := 1
## Flocks of feral chickens (a rooster and his hens), foraging in a hall.
@export_range(0, 4, 1, "suffix:flocks") var chicken_flocks := 2
## Gargoyles, each crouched as a statue on a ledge over a hall (a terrace's edge or a
## wall top), dropping on whoever passes beneath.
@export_range(0, 4, 1, "suffix:gargoyles") var gargoyles := 2
## Herds of deer (four or five each, one of them wrong), standing in the halls.
@export_range(0, 3, 1, "suffix:herds") var deer_herds := 1
## Bull elk, each holding a stretch of halls as his own.
@export_range(0, 3, 1, "suffix:elk") var elk := 1
## Gangs of tiny imps (three or four), each perched on a wall.
@export_range(0, 4, 1, "suffix:gangs") var imp_gangs := 2
## Swarms of imps, each a crack at the foot of a wall that dozens pour out of.
@export_range(0, 3, 1, "suffix:swarms") var imp_swarms := 1
## A colossus that crawls over the ring on its wall tops (one at most: it would
## stand 260 m tall). The Avenues and the Galleries, whose walls are thick and
## far apart, have one.
@export_range(0, 1, 1, "suffix:colossi") var colossi := 0
## Packs of coyotes (three to five each): skittish, they shadow people at a
## distance and yip, but three or more of them can grow bold round someone alone.
@export_range(0, 4, 1, "suffix:packs") var coyote_packs := 2
## Skinwalkers, each hidden among a pack of coyotes as one of them (one more
## pack is put in for any there is no pack for).
@export_range(0, 2, 1, "suffix:skinwalkers") var skinwalkers := 1
## Martian tripods (MazeTripod), each striding round the ring over the walls,
## its searchlight sweeping the halls. One at most: it is huge.
@export_range(0, 1, 1, "suffix:tripods") var tripods := 1
## Horror clowns (MazeClown), each prowling the halls with a red balloon floating
## over the walls: still while anyone looks at him, a sprint when nobody does.
@export_range(0, 3, 1, "suffix:clowns") var clowns := 1
## Stegosaurs, each grazing in a hall (sometimes with a calf): they hunt nobody,
## but anyone too near is warned off, and then the spiked tail is swung at them.
@export_range(0, 4, 1, "suffix:stegosaurs") var stegosaurs := 1
## Troops of spider monkeys (four to seven), hanging from vines strung along the
## walls over a hall, dropping on whoever passes under.
@export_range(0, 4, 1, "suffix:troops") var spider_monkey_troops := 1
## Bands of lizard people (two or three each), clinging to the walls over a hall.
@export_range(0, 4, 1, "suffix:bands") var lizard_people := 2
## Hunting parties of the masked tribe (MazeTribesman: three to five of the maze's
## lost boys gone wild, masked, with spears), each camped round its totem in a dead end.
@export_range(0, 4, 1, "suffix:parties") var tribe_parties := 1
## Packs of deinonychus (each three or four): feathered pack hunters, one drawing
## you while the others go round to cut you off; climbing high escapes them.
@export_range(0, 3, 1, "suffix:packs") var deinonychus_packs := 1
## Pterodactyls, soaring high over the maze and roosting on its high wall tops;
## they dive at anyone out in the open.
@export_range(0, 6, 1, "suffix:pterodactyls") var pterodactyls := 2
## Wyverns (MazeWyvern): two-legged dragons, a pair nesting on a high wall top in the
## outer rings, soaring over their territory. They hunt anyone in the open (a diving grab
## that carries you off, or landing to stalk you and lash with the barbed tail) part of the
## time, and go at once for anyone who climbs near the nest.
@export_range(0, 2, 1, "suffix:pairs") var wyvern_pairs := 1
## Giant snails, each crawling a straight hall (it climbs the walls after anyone up high).
@export_range(0, 3, 1, "suffix:snails") var snails := 1
## Hydras (MazeHydra): each lies in a marsh pool of its own in a hall and strikes
## with many heads at anyone who passes in reach.
@export_range(0, 3, 1, "suffix:hydras") var hydras := 1
## Troops of gibbons (three to five), living on the ledges, terraces and wall tops
## (only of sections that have them): they call when they see you below (fetching
## other hunters) and knock down climbers.
@export_range(0, 3, 1, "suffix:troops") var gibbon_troops := 1
## Screaming bears: each prowls the halls calling out in the voice of the last
## thing it killed; it rears and screams, charges and swipes.
@export_range(0, 2, 1, "suffix:bears") var bears := 1
## Brachiosaurs roaming out past the square sections: the desert's quarters and the
## round sections with wide halls (read from the first section's style). Gentle; only
## their feet are dangerous.
@export_range(0, 8, 1, "suffix:brachiosaurs") var brachiosaurs := 4
## Dimetrodons basking in the wide halls (cold-blooded ambushers, slow to chase).
@export_range(0, 4, 1, "suffix:dimetrodons") var dimetrodons := 1
## Dimetrodons basking out in the desert's open ground (read from the first section's style).
@export_range(0, 6, 1, "suffix:dimetrodons") var desert_dimetrodons := 2
## Pairs of griffinflies (MazeGriffinfly: giant dragonflies), each holding a stretch of
## halls: they buzz and knock you down; two harrying someone alone catch them.
@export_range(0, 4, 1, "suffix:pairs") var griffinfly_pairs := 1
## Psychic children (MazePsychicChild), each drifting about the halls: they hunt
## nobody, watch over whoever is calm near them (taking hold of what comes after
## them with their minds), and burst when they are frightened.
@export_range(0, 3, 1, "suffix:children") var psychic_children := 1
## Lynx (MazeLynx): shy small-game hunters that watch from the ledges over the halls
## and slip away; dangerous only cornered or at a kill.
@export_range(0, 4, 1, "suffix:lynx") var lynxes := 2
## Black panthers (MazePanther): solitary stalkers that lie up on ledges and come on
## from above or behind, strongest at night; face them, don't run.
@export_range(0, 3, 1, "suffix:panthers") var panthers := 1
## Packs of grey wolves (four to six each, a breeding pair at their head), each with
## its den in a dead end: they patrol in file, howl at dusk and through the night, and
## hunt by endurance (a trot slower than a run that never tires).
@export_range(0, 3, 1, "suffix:packs") var wolf_packs := 1
## Jackalopes (MazeJackalope): a hare with antlers that stares instead of hiding, and
## butts whoever comes too near.
@export_range(0, 2, 1, "suffix:jackalopes") var jackalopes := 1
## Giant octopuses, each lurking in a black pool against a hall's wall or in a
## drain through a wall (every other one), reaching for whoever lingers near.
@export_range(0, 3, 1, "suffix:octopuses") var octopuses := 1
## Moose, each at a wallow of its own in a hall (every other one a cow with her calf;
## the bulls in the rut some of the time): unpredictable, charging whoever comes near
## the calf, or a bull in the rut whoever he sees.
@export_range(0, 3, 1, "suffix:moose") var moose := 1
## Herds of woolly mammoths (a matriarch, cows and a calf) grazing in the widest halls:
## they ring the calf, and the matriarch trumpets, mock-charges and then charges.
@export_range(0, 2, 1, "suffix:herds") var mammoth_herds := 1
## Lonely horses: feral, each alone, wandering the wide halls; wary, but come slowly
## and touch one and it trusts and follows you.
@export_range(0, 2, 1, "suffix:horses") var horses := 1
## Giant Venus flytraps (MazeFlytrap), in pairs at the foot of a hall's walls: a touch
## makes one shiver, and it snaps shut on whoever is still in it.
@export_range(0, 8, 1, "suffix:flytraps") var flytraps := 4
## Giant sundews (MazeSundew): sticky rosettes out from a wall's foot that slow and hold you.
@export_range(0, 6, 1, "suffix:sundews") var sundews := 2
## Giant pitcher plants (MazePitcher): a slippery mouth at a wall's foot; step on it and you go in.
@export_range(0, 6, 1, "suffix:pitchers") var pitchers := 2
## Patches of mushrooms (MazeMushrooms) whose puffballs' spores blur and slow you and call the zombies.
@export_range(0, 12, 1, "suffix:patches") var mushroom_patches := 4
## Hordes of mushroom zombies (three or four and a sleeper each): blind, hunting by sound.
@export_range(0, 4, 1, "suffix:hordes") var zombie_hordes := 2
## Bands of gnomes (three to five), each in a hollow at a wall's foot: statues when looked
## at, they creep up and steal from pockets, and trip runners with a rope.
@export_range(0, 4, 1, "suffix:bands") var gnome_bands := 2
## Weavers: six-armed, four-winged figures drifting over the halls, leaving strands across
## them that hold whoever walks into them upright, until it comes and takes them.
@export_range(0, 2, 1, "suffix:weavers") var weavers := 1
## Colonies of giant ants (MazeAnts), each a nest in a dead end with a trail out along the
## halls: they let alone whoever keeps off the trail, and come at whoever treads on it.
@export_range(0, 3, 1, "suffix:colonies") var ant_colonies := 1
## Giant praying mantises (MazeMantis), each still among ferns against a hall wall, striking
## at whoever comes within its reach.
@export_range(0, 3, 1, "suffix:mantises") var mantises := 1
## Mischiefs of rats (three to six each) running the wall feet, scavenging; harmless.
@export_range(0, 6, 1, "suffix:mischiefs") var rat_mischiefs := 2
## Swarms of rats in drains at a wall's foot, that pour out like a river at whoever comes by.
@export_range(0, 3, 1, "suffix:swarms") var rat_swarms := 1
## Rat kings: knots of rats fused by their tails, slow, whose shriek calls the swarms in, bold.
@export_range(0, 2, 1, "suffix:rat kings") var rat_kings := 1
## The luck dragon: soars over the outer rings and the desert, comes down to whoever stands
## still in the open, calms the hunters near and may carry them further out (one in all).
@export_range(0, 1, 1, "suffix:dragons") var luck_dragons := 1
## Murders of crows (Crows), each sitting along the wall tops over a hall: they
## follow whoever passes along the walls, and erupt cawing at anyone who runs,
## which calls the hunters.
@export_range(0, 4, 1, "suffix:murders") var crow_murders := 2

@export_group("Who else is in it")
## How many runners run the section's passages (MazeRunners, from the round's
## seed): other boys, driven by the computer, who know their section. They lead
## anyone who comes up to them to its gate out, draw what hunts away, and are
## hunted themselves. Each one poses a whole boy, so keep it small.
@export_range(0, 6, 1, "suffix:runners") var runners := 2

@export_group("Wildlife")
## Herds of ordinary deer in the halls (Wildlife: peaceful, they run from you;
## not among what hunts it).
@export_range(0, 4, 1, "suffix:herds") var wild_deer_herds := 1
## Herds of ordinary elk in the halls (peaceful, they run from you).
@export_range(0, 4, 1, "suffix:herds") var wild_elk_herds := 1
## Colonies of ordinary frogs (MazePondFrogs, a dozen or so) round a little pond of
## their own in a hall: they sing at dusk and in the rain, go quiet and plop into the
## water as you come near. Prey for the hunters.
@export_range(0, 6, 1, "suffix:colonies") var frog_ponds := 2
## Red foxes (MazeFox), alone or a pair: curious, they follow at a distance, sit and
## watch, slip away, carry off things lying about, and hunt the small things.
@export_range(0, 4, 1, "suffix:foxes or pairs") var fox_pairs := 2
## Rabbit warrens (MazeRabbit): a bank of burrows at the foot of a wall in a hall, its
## colony grazing in front of it; they thump and bolt down their holes at anyone near.
@export_range(0, 4, 1, "suffix:warrens") var rabbit_warrens := 1
## Brown hares (MazeHare) lying up in the halls, every other one a pair that box.
@export_range(0, 4, 1, "suffix:hares") var hares := 1
## Patches of fireflies at dusk and by night, at the foot of the ivy and the walls (Insects).
@export_range(0, 60, 1, "suffix:patches") var firefly_patches := 24
## Flocks of tame chickens (TameChickens), which hunt nobody, foraging in the halls.
@export_range(0, 4, 1, "suffix:flocks") var tame_chicken_flocks := 0
## Pairs of ravens (Ravens) on the wall tops, which hunt nobody: omens, that fly
## ahead of whoever comes near to sit over a hunter waiting there.
@export_range(0, 4, 1, "suffix:pairs") var raven_pairs := 2
## Moths round each light in its halls (the angel, fires, the light past the exit).
@export_range(0, 60, 1, "suffix:per light") var moths_per_light := 18
## Big moths resting on its walls, that scatter as you pass.
@export_range(0, 30, 1, "suffix:moths") var wall_moths := 8
## Flies round each thing of meat in it (flesh mounds, the slime wall, the boar's lair, carcasses).
@export_range(0, 80, 1, "suffix:per carcass") var flies_per_carrion := 26
## Carcasses lying in its dead ends.
@export_range(0, 8, 1, "suffix:carcasses") var carcasses := 3

@export_group("What lies about")
## Things left lying in its halls to find (Loot): in the ends of halls first, then anywhere, never by its gates.
@export_range(0, 20, 1, "suffix:things") var loot_items := 6
## Camps left behind in its halls (cold fires, tallies scratched on the wall, often signs of a struggle).
@export_range(0, 8, 1, "suffix:camps") var abandoned_camps := 1
## How likely a thing lying about is a stick (common, weak, it snaps), weighed against the rest
## (flares and maps 3 each, torches and spears 2, a hook, a ladder and a backpack 1).
@export_range(0, 12, 1, "suffix:weight") var stick_weight := 3
## How likely a thing lying about is a bat (knocks a hunter back), weighed against the rest.
@export_range(0, 12, 1, "suffix:weight") var bat_weight := 2
## How likely a thing lying about is a sword (the best: never breaks), weighed against the rest.
@export_range(0, 12, 1, "suffix:weight") var sword_weight := 1
## The chance that any one thing lying in its halls (or by its camps) is a gun: rare (0 to 1).
@export_range(0.0, 1.0, 0.005, "suffix:chance") var gun_chance := 0.04
## Of guns (and boxes of rounds), how many are shotguns, the rest revolvers (a share, 0 to 1).
@export_range(0.0, 1.0, 0.05, "suffix:of guns") var shotgun_share := 0.3
## How many rounds a gun is found with: fewest and most (rounds, of six or two).
@export var rounds_in_gun := Vector2i(1, 3)
## The chance that any one thing is a box of rounds for a gun: rarer still (0 to 1).
@export_range(0.0, 1.0, 0.005, "suffix:chance") var ammo_chance := 0.025
## How many rounds are left in a box: fewest and most (rounds or shells).
@export var rounds_per_box := Vector2i(2, 4)

## Which features' boxes have been set by hand (feature -> on). A feature not in
## it is on when its amount is more than 0: so sections saved before the boxes
## came load just as they were, and so do the presets below.
@export_storage var features_switched := {}

## Each feature's on/off box, and the settings it shows under it while on (the
## first: how much of it there is, which goes to 0 while it is off).
const FEATURES := {
	&"terraces_on": [&"terrace_share", &"upper_terrace_share"],
	&"terrace_bridges_on": [&"terrace_bridge_share"],
	&"wall_top_bridges_on": [&"wall_top_bridge_share"],
	&"mezzanine_bridges_on": [&"mezzanine_bridge_share"],
	&"wall_ivy_on": [&"wall_ivy_share", &"wall_ivy_height_range"],
	&"ivy_to_wall_top_on": [&"ivy_to_wall_top_share"],
	&"mezzanine_ivy_on": [&"mezzanine_ivy_share"],
	&"hanging_vines_on": [&"hanging_vine_share"],
	&"tightrope_vines_on": [&"tightrope_vine_share", &"tightrope_vine_height_range"],
	&"terrace_vines_on": [&"terrace_vine_share"],
	&"bracket_vines_on": [&"bracket_vine_share", &"bracket_height_range"],
	&"ledge_strung_vines_on": [&"ledge_strung_vine_share"],
	&"swept_vines_on": [&"swept_vine_share"],
	&"concrete_bridges_on": [&"concrete_bridge_share", &"concrete_bridge_arch_rise", &"concrete_bridge_width"],
	&"bridge_hanging_vines_on": [&"bridge_hanging_vine_share"],
	&"ledge_hanging_vines_on": [&"ledge_hanging_vine_share"],
	&"wall_vines_on": [&"wall_vine_share", &"wall_vine_height_range", &"wall_vine_sweep_share"],
	&"vents_on": [&"wall_vent_share"],
	&"outlets_on": [&"outlet_share", &"outlet_drip_share"],
	&"wall_cables_on": [&"wall_cable_share"],
	&"sewer_pipes_on": [&"sewer_pipe_share", &"sewer_pipe_height"],
	&"culverts_on": [&"culvert_share"],
	&"drains_on": [&"drain_share"],
	&"manholes_on": [&"manhole_share"],
	&"clutter_on": [&"clutter_share", &"clutter_heap_size", &"clutter_barrel_share"],
	&"cables_on": [&"cable_share", &"cable_height_range", &"snapped_cable_share", &"cable_lamp_share"],
	&"cables_by_vines_on": [&"cable_by_vine_share"],
	&"junction_boxes_on": [&"junction_box_share", &"junction_box_height_range"],
	&"slanting_cables_on": [&"slanting_cable_share", &"slanting_cable_heights"],
	&"ledge_cables_on": [&"ledge_cable_share", &"ledge_cable_fix_height"],
	&"grapple_routes_on": [&"grapple_route_share", &"grapple_route_rise"],
	&"grapple_rings_on": [&"grapple_ring_share"],
	&"grapple_swings_on": [&"grapple_swing_share", &"grapple_swing_height_range"],
	&"undergrowth_on": [&"plant_density"],
	&"wall_grass_on": [&"wall_grass_share"],
	&"ponds_on": [&"pond_share", &"pond_depth_range"],
	&"flooded_halls_on": [&"flooded_hall_share", &"flooded_hall_length"],
	&"swim_ponds_on": [&"swim_pond_share", &"swim_pond_depth"],
	&"fish_on": [&"fish_share", &"fish_per_school"],
}
## Features that are only of another (hidden, box and all, while that is off).
const PART_OF := {
	&"terrace_bridges_on": &"terraces_on", &"ivy_to_wall_top_on": &"terraces_on", &"terrace_vines_on": &"terraces_on",
	&"flooded_halls_on": &"ponds_on", &"swim_ponds_on": &"ponds_on", &"fish_on": &"ponds_on",
	&"bridge_hanging_vines_on": &"concrete_bridges_on",
}
## How much of a feature there is when its box is turned on with its amount at 0
## and nothing to go back to (its own default is 0).
const AMOUNT_WHEN_TURNED_ON := 0.05

## Each feature's amount setting -> its box.
static var _box_of := {}

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


## Whether a feature (its box: a key of FEATURES) is on: as set by hand, or else
## whether there is any of it (so an old save, or a preset, is as its amounts say).
func feature_on(box: StringName) -> bool:
	if features_switched.has(box):
		return features_switched[box]
	return float(get(FEATURES[box][0])) > 0.0


## How much of a feature there is, by its amount setting (`setting`, the first of
## a FEATURES entry): the setting while its box is on, 0 while it is off. What
## makes the maze reads this instead of the setting, so that off is as 0 was,
## the same random numbers drawn.
func amount(setting: StringName) -> float:
	if _box_of.is_empty():
		for box: StringName in FEATURES:
			_box_of[FEATURES[box][0]] = box
	var box: StringName = _box_of[setting]
	return float(get(setting)) if feature_on(box) else 0.0


func _switch(box: StringName, on: bool) -> void:
	# (a new dictionary: duplicated styles may share the old one)
	var switched := features_switched.duplicate()
	switched[box] = on
	features_switched = switched
	var setting: StringName = FEATURES[box][0]
	if on and float(get(setting)) <= 0.0:
		# (turned on with none of it: back to its default, or a little)
		var default := float(get_script().get_property_default_value(setting))
		set(setting, default if default > 0.0 else AMOUNT_WHEN_TURNED_ON)
	notify_property_list_changed()


func _validate_property(property: Dictionary) -> void:
	var name := StringName(property.name)
	# (whether it is round is what kind of style it is: saved, not shown)
	if name == &"round_section":
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif FEATURES.has(name):
		# (a box: saved in features_switched, not itself)
		property.usage &= ~PROPERTY_USAGE_STORAGE
		if PART_OF.has(name) and not feature_on(PART_OF[name]):
			property.usage &= ~PROPERTY_USAGE_EDITOR
		elif Engine.is_editor_hint() and not features_switched.has(name):
			# (shown in the editor: held as it is, so that dragging its amount to 0
			# leaves the box on)
			var switched := features_switched.duplicate()
			switched[name] = feature_on(name)
			features_switched = switched
	else:
		for box: StringName in FEATURES:
			if FEATURES[box].has(name):
				if not feature_on(box) or (PART_OF.has(box) and not feature_on(PART_OF[box])):
					property.usage &= ~PROPERTY_USAGE_EDITOR
				break


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


## The groups `bare` empties: every count in them goes to none.
const PEOPLED := ["What hunts it", "Who else is in it", "Wildlife"]


## A copy of this style with `times` as many of each thing that hunts it (every
## count in "What hunts it", rounded; one there is never rounded away). 1: itself.
func crowded(times: float) -> MazeStyle:
	if is_equal_approx(times, 1.0):
		return self
	var copy: MazeStyle = duplicate(true)
	var group := ""
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		if property.type == TYPE_INT and group == "What hunts it":
			var count := int(get(property.name))
			copy.set(property.name, maxi(roundi(count * times), 1 if count > 0 and times > 0.0 else 0))
	return copy


## A copy of this style with nothing in it: none of what hunts it, who else is in
## it, its wildlife or what lies about, and none of its dressing (ledges, terraces,
## ivy, vines, sewers, clutter, hook spots, plants, ponds), as narrow as a section
## can be. For the clearing alone (Maze.generate with no rings, a test mode): its
## first section is only a narrow way round behind the clearing's shut gates.
func bare() -> MazeStyle:
	var copy: MazeStyle = duplicate(true)
	copy.section_width_cells = 1
	copy.mezzanine_height = 0.0
	copy.loot_items = 0
	copy.abandoned_camps = 0
	var group := ""
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		var name: String = property.name
		if property.type == TYPE_INT and group in PEOPLED:
			copy.set(name, 0)
		elif property.type == TYPE_FLOAT and (name.ends_with("_share") or name.ends_with("_density")):
			copy.set(name, 0.0)
	return copy


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
	# (one thin ledge: a lip of concrete, not a balcony)
	style.mezzanine_levels = 1
	style.mezzanine_thickness = 0.25
	style.mezzanine_depth = 0.9
	style.terrace_share = 0.0
	style.wall_top_bridge_share = 0.0
	style.wall_ivy_share = 0.1
	style.hanging_vine_share = 0.08
	style.tightrope_vine_share = 0.22
	style.tightrope_vine_height_range = Vector2(0.45, 0.75)
	style.sewer_pipe_share = 0.08
	style.plant_density = 0.8
	style.harpies = 2
	style.colossi = 1
	sewers(style, 1.0)
	# (signs of those who lived here before: camps, heaps of boxes and barrels, old
	# cables strung high across the halls among the vines, some snapped, lamps)
	style.abandoned_camps = 3
	style.clutter_share = 0.07
	style.cable_share = 0.14
	style.cable_by_vine_share = 0.6
	style.wall_cable_share = 0.05
	return style


## Vents, culverts, outlets, drains and manholes, `amount` times as many as the
## Avenues have.
static func sewers(style: MazeStyle, amount: float) -> void:
	style.wall_vent_share = 0.05 * amount
	style.culvert_share = 0.025 * amount
	style.outlet_share = 0.06 * amount
	style.drain_share = 0.05 * amount
	style.manhole_share = 0.025 * amount


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
	style.tightrope_vine_share = 0.15
	style.terrace_share = 0.0
	style.wall_top_bridge_share = 0.0
	style.wall_ivy_share = 0.1
	style.hanging_vine_share = 0.04
	style.plant_density = 0.6
	style.colossi = 1
	sewers(style, 0.8)
	return style


## Narrows: a close maze of single hallways that wind and fork, with terraces, ivy,
## vines and rope bridges to climb.
static func narrows() -> MazeStyle:
	var style := made(4, 1, 0.0, 0.0, 0.06)
	# (three ways in from the Galleries)
	style.entrance_count = 3
	sewers(style, 0.7)
	return style


## Tangle: single hallways that branch often and loop back on themselves, so that
## there are many ways and it is easy to go round in circles.
static func tangle() -> MazeStyle:
	var style := made(4, 1, 0.3, 0.5, 0.2)
	sewers(style, 0.7)
	return style


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
	return [spokes(), turnstiles(), bore()]


## The Turnstiles: the second round section. Not passages but halls round between
## circles of wall, each circle broken by doorways with a great slab turning in each:
## through when it stands edge on.
static func turnstiles() -> MazeStyle:
	var style := whorl()
	style.section_width_cells = 6
	(style as RoundStyle).layout = RoundStyle.Layout.ROTATING_DOORS
	return style


## The Bore: the last section, one wide roofed tunnel all the way round, dim, lit
## through slots in its roof, from the way in to the way out.
static func bore() -> MazeStyle:
	var style := labyrinth()
	(style as RoundStyle).layout = RoundStyle.Layout.TUNNEL
	return style
