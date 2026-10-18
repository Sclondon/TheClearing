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
## Moss up the foot of its walls, to about this many metres off the ground (its
## top edge ragged; 0: none), and in patches higher up over about this share of
## the walls' faces (0: none).
@export_range(0.0, 8.0) var wall_moss_height := 1.2
@export_range(0.0, 1.0) var wall_moss_patches := 0.12
## How many times bigger than the concrete texture's own size it is laid on the
## maze walls and their ledges (walls this high want it big; the great walls
## between sections have their own, bigger still).
@export_range(0.5, 12.0) var wall_texture_scale := 4.0
## How far round the maze walls' top edges and corners are worn, metres (more in
## places, nearly sharp in others; 0: square). Their ledges half this.
@export_range(0.0, 0.6, 0.01) var wall_edge_rounding := 0.14
## The same for the border wall round its outside (and the clearing's, for the
## first section): walls that big are worn rounder.
@export_range(0.0, 1.5, 0.01) var border_wall_edge_rounding := 0.4
## How weathered its walls are at their edges and tops: grime where the rain runs
## off their top edges, paler worn corners with chips out of them, and faces
## very slightly uneven (0: none).
@export_range(0.0, 1.0, 0.01) var wall_weathering := 0.5
## The share of wall faces with short grass along their foot, in runs of a few metres.
@export_range(0.0, 1.0) var wall_grass_share := 0.25

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

@export_group("Sewers")
## What the maze's drains and ducts show of themselves (MazeProps; dressing,
## nothing to climb). The share of wall faces with an old vent high on them:
## louvred or round, rusted, some of them big.
@export_range(0.0, 0.5) var wall_vent_share := 0.0
## The share of wall faces with a barred culvert at their foot, black behind its
## bars, a wet stain and a puddle in front of it.
@export_range(0.0, 0.5) var culvert_share := 0.0
## The share of wall faces with a small pipe coming out of them a little up, a
## rust stain running down the wall under it and a puddle at the foot; of those,
## the share that drip.
@export_range(0.0, 0.5) var outlet_share := 0.0
@export_range(0.0, 1.0) var outlet_drip_share := 0.6
## The share of hall cells with a drain grate in the floor by a wall's foot (a
## puddle round some), and with a manhole cover out in the hall (now and then
## pushed half off its hole).
@export_range(0.0, 0.5) var drain_share := 0.0
@export_range(0.0, 0.5) var manhole_share := 0.0

@export_group("Signs of life")
## Others lived here once (MazeProps). The share of wall faces with boxes and
## barrels left against them, how many things in each heap (most and least), and
## the share of those that are barrels (some fallen over). They are solid.
@export_range(0.0, 0.5) var clutter_share := 0.0
@export var clutter_heap_size := Vector2i(3, 7)
@export_range(0.0, 1.0) var clutter_barrel_share := 0.4
## The share of halls with an old electric cable strung across them high up,
## sagging, from wall to wall, and how high its ends are, metres (never over the
## lower wall top).
@export_range(0.0, 1.0) var cable_share := 0.0
@export var cable_height_range := Vector2(9.0, 22.0)
## The share of vines strung across a hall with a cable strung beside them, in
## among the vine, and of vines hanging from the walls with a cable's end hanging
## beside them.
@export_range(0.0, 1.0) var cable_by_vine_share := 0.0
## Of cables across halls, the share snapped, their two ends hanging; of the rest,
## the share with an old lamp (dead) hanging from them.
@export_range(0.0, 1.0) var snapped_cable_share := 0.25
@export_range(0.0, 1.0) var cable_lamp_share := 0.3
## The share of wall faces with a cable looped along them on brackets.
@export_range(0.0, 0.5) var wall_cable_share := 0.0

@export_group("Plants")
## How thickly ferns, moss and tufts of grass grow along the foot of its walls (0
## none, 1 all along every wall).
@export_range(0.0, 1.0) var plant_density := 0.0

@export_group("Water")
## The share of hall cells with standing water in them (Ponds): a pond lying in
## the hall, or a stretch of the hall flooded from wall to wall. The ground goes
## down under it, so he wades, and in the deepest swims.
@export_range(0.0, 0.3) var pond_share := 0.02
## Of those, the share that flood a stretch of the hall, how many cells long at
## most (the rest are ponds lying within one cell).
@export_range(0.0, 1.0) var flooded_hall_share := 0.4
@export_range(2, 8) var flooded_hall_length := 4
## How deep a pond is, metres, from puddle-deep to wading (to his waist at 0.8).
@export var pond_depth_range := Vector2(0.15, 0.8)
## The share of ponds deep enough to swim, and how deep those are, metres.
@export_range(0.0, 1.0) var swim_pond_share := 0.12
@export_range(1.0, 3.0) var swim_pond_depth := 1.7
## The share of ponds (no shallower than FishSchool.SHALLOWEST) with a school of
## small fish in them, that dart off from whoever wades near; how many in each.
@export_range(0.0, 1.0) var fish_share := 0.6
@export_range(1, 40) var fish_per_school := 12

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
## Balls: seven or eight bodies grown into a sphere that rolls after you, faster
## and faster down a straight hall, slow to turn a corner (and grows: past eight, a mound).
@export_range(0, 3) var balls := 1
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
## Horror clowns (MazeClown), each prowling the halls with a red balloon floating
## over the walls: still while anyone looks at him, a sprint when nobody does.
@export_range(0, 3) var clowns := 1
## Stegosaurs, each grazing in a hall (sometimes with a calf): they hunt nobody,
## but anyone too near is warned off, and then the spiked tail is swung at them.
@export_range(0, 4) var stegosaurs := 1
## Troops of spider monkeys (four to seven), hanging from vines strung along the
## walls over a hall, dropping on whoever passes under.
@export_range(0, 4) var spider_monkey_troops := 1
## Bands of lizard people (two or three each), clinging to the walls over a hall.
@export_range(0, 4) var lizard_people := 2
## Hunting parties of the masked tribe (MazeTribesman: three to five of the maze's
## lost boys gone wild, masked, with spears), each camped round its totem in a dead end.
@export_range(0, 4) var tribe_parties := 1
## Packs of deinonychus (each three or four): feathered pack hunters, one drawing
## you while the others go round to cut you off; climbing high escapes them.
@export_range(0, 3) var deinonychus_packs := 1
## Pterodactyls, soaring high over the maze and roosting on its high wall tops;
## they dive at anyone out in the open.
@export_range(0, 6) var pterodactyls := 2
## Giant snails, each crawling a straight hall (it climbs the walls after anyone up high).
@export_range(0, 3) var snails := 1
## Hydras (MazeHydra): each lies in a marsh pool of its own in a hall and strikes
## with many heads at anyone who passes in reach.
@export_range(0, 3) var hydras := 1
## Troops of gibbons (three to five), living on the ledges, terraces and wall tops
## (only of sections that have them): they call when they see you below (fetching
## other hunters) and knock down climbers.
@export_range(0, 3) var gibbon_troops := 1
## Screaming bears: each prowls the halls calling out in the voice of the last
## thing it killed; it rears and screams, charges and swipes.
@export_range(0, 2) var bears := 1
## Brachiosaurs roaming out past the square sections: the desert's quarters and the
## round sections with wide halls (read from the first section's style). Gentle; only
## their feet are dangerous.
@export_range(0, 8) var brachiosaurs := 4
## Dimetrodons basking in the wide halls (cold-blooded ambushers, slow to chase).
@export_range(0, 4) var dimetrodons := 1
## Dimetrodons basking out in the desert's open ground (read from the first section's style).
@export_range(0, 6) var desert_dimetrodons := 2
## Pairs of griffinflies (MazeGriffinfly: giant dragonflies), each holding a stretch of
## halls: they buzz and knock you down; two harrying someone alone catch them.
@export_range(0, 4) var griffinfly_pairs := 1
## Psychic children (MazePsychicChild), each drifting about the halls: they hunt
## nobody, watch over whoever is calm near them (taking hold of what comes after
## them with their minds), and burst when they are frightened.
@export_range(0, 3) var psychic_children := 1
## Lynx (MazeLynx): shy small-game hunters that watch from the ledges over the halls
## and slip away; dangerous only cornered or at a kill.
@export_range(0, 4) var lynxes := 2
## Black panthers (MazePanther): solitary stalkers that lie up on ledges and come on
## from above or behind, strongest at night; face them, don't run.
@export_range(0, 3) var panthers := 1
## Packs of grey wolves (four to six each, a breeding pair at their head), each with
## its den in a dead end: they patrol in file, howl at dusk and through the night, and
## hunt by endurance (a trot slower than a run that never tires).
@export_range(0, 3) var wolf_packs := 1
## Jackalopes (MazeJackalope): a hare with antlers that stares instead of hiding, and
## butts whoever comes too near.
@export_range(0, 2) var jackalopes := 1
## Giant octopuses, each lurking in a black pool against a hall's wall or in a
## drain through a wall (every other one), reaching for whoever lingers near.
@export_range(0, 3) var octopuses := 1
## Moose, each at a wallow of its own in a hall (every other one a cow with her calf;
## the bulls in the rut some of the time): unpredictable, charging whoever comes near
## the calf, or a bull in the rut whoever he sees.
@export_range(0, 3) var moose := 1
## Herds of woolly mammoths (a matriarch, cows and a calf) grazing in the widest halls:
## they ring the calf, and the matriarch trumpets, mock-charges and then charges.
@export_range(0, 2) var mammoth_herds := 1
## Lonely horses: feral, each alone, wandering the wide halls; wary, but come slowly
## and touch one and it trusts and follows you.
@export_range(0, 2) var horses := 1
## Giant Venus flytraps (MazeFlytrap), in pairs at the foot of a hall's walls: a touch
## makes one shiver, and it snaps shut on whoever is still in it.
@export_range(0, 8) var flytraps := 4
## Giant sundews (MazeSundew): sticky rosettes out from a wall's foot that slow and hold you.
@export_range(0, 6) var sundews := 2
## Giant pitcher plants (MazePitcher): a slippery mouth at a wall's foot; step on it and you go in.
@export_range(0, 6) var pitchers := 2
## Patches of mushrooms (MazeMushrooms) whose puffballs' spores blur and slow you and call the zombies.
@export_range(0, 12) var mushroom_patches := 4
## Hordes of mushroom zombies (three or four and a sleeper each): blind, hunting by sound.
@export_range(0, 4) var zombie_hordes := 2
## Bands of gnomes (three to five), each in a hollow at a wall's foot: statues when looked
## at, they creep up and steal from pockets, and trip runners with a rope.
@export_range(0, 4) var gnome_bands := 2
## Weavers: six-armed, four-winged figures drifting over the halls, leaving strands across
## them that hold whoever walks into them upright, until it comes and takes them.
@export_range(0, 2) var weavers := 1
## Colonies of giant ants (MazeAnts), each a nest in a dead end with a trail out along the
## halls: they let alone whoever keeps off the trail, and come at whoever treads on it.
@export_range(0, 3) var ant_colonies := 1
## Giant praying mantises (MazeMantis), each still among ferns against a hall wall, striking
## at whoever comes within its reach.
@export_range(0, 3) var mantises := 1
## Mischiefs of rats (three to six each) running the wall feet, scavenging; harmless.
@export_range(0, 6) var rat_mischiefs := 2
## Swarms of rats in drains at a wall's foot, that pour out like a river at whoever comes by.
@export_range(0, 3) var rat_swarms := 1
## Rat kings: knots of rats fused by their tails, slow, whose shriek calls the swarms in, bold.
@export_range(0, 2) var rat_kings := 1
## The luck dragon: soars over the outer rings and the desert, comes down to whoever stands
## still in the open, calms the hunters near and may carry them further out (one in all).
@export_range(0, 1) var luck_dragons := 1
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
## Colonies of ordinary frogs (MazePondFrogs, a dozen or so) round a little pond of
## their own in a hall: they sing at dusk and in the rain, go quiet and plop into the
## water as you come near. Prey for the hunters.
@export_range(0, 6) var frog_ponds := 2
## Red foxes (MazeFox), alone or a pair: curious, they follow at a distance, sit and
## watch, slip away, carry off things lying about, and hunt the small things.
@export_range(0, 4) var fox_pairs := 2
## Rabbit warrens (MazeRabbit): a bank of burrows at the foot of a wall in a hall, its
## colony grazing in front of it; they thump and bolt down their holes at anyone near.
@export_range(0, 4) var rabbit_warrens := 1
## Brown hares (MazeHare) lying up in the halls, every other one a pair that box.
@export_range(0, 4) var hares := 1
## Patches of fireflies at dusk and by night, at the foot of the ivy and the walls (Insects).
@export_range(0, 60) var firefly_patches := 24
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
@export_range(0, 8) var abandoned_camps := 1
## How likely each thing lying in its halls is to be a stick (common, weak, it
## snaps), a bat (knocks a hunter back) or a sword (the best: never breaks),
## weighed against the rest of what lies there (flares and maps 3 each, torches
## and spears 2, a hook, a ladder and a backpack 1).
@export_range(0, 12) var stick_weight := 3
@export_range(0, 12) var bat_weight := 2
@export_range(0, 12) var sword_weight := 1
## The chance that any one thing lying in its halls (or by its camps) is a gun:
## rare. A shotgun `shotgun_share` of the time, a revolver otherwise; and found
## with a few rounds in it (`rounds_in_gun`, of six or two).
@export_range(0.0, 1.0, 0.005) var gun_chance := 0.04
@export_range(0.0, 1.0, 0.05) var shotgun_share := 0.3
@export var rounds_in_gun := Vector2i(1, 3)
## The chance that any one is a box of rounds for one (rarer still), and how
## many are left in a box (revolver rounds or shotgun shells, as `shotgun_share`).
@export_range(0.0, 1.0, 0.005) var ammo_chance := 0.025
@export var rounds_per_box := Vector2i(2, 4)

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
