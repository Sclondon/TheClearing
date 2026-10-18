@tool
class_name MazeStyle
extends Resource
## How one ring of the maze is made: how deep it is, how wide its halls are, and
## the rules its passages are grown by. Each ring has its own (Maze.styles), so
## the maze changes in kind as the boy goes out through it.
##
## The passages are grown from the ring's gates over blocks of `span` x `span`
## cells (a hall `span` cells wide), each new block joined to one already reached:
## mostly from the newest, which makes long passages, now and then (`branching`)
## from an older one, which makes side branches; going on the way it was going
## when it can (`straight`), which makes long straight halls. `loops` then knocks
## through some of the walls left between halls, so there is more than one way round.

## Cells of maze deep, from its inside wall to its outside wall (on each side),
## not counting its rampart, which is laid on inside them.
@export_range(1, 16) var width := 4
## Cells across a hall.
@export_range(1, 4) var span := 1
## How thick its walls are, metres. (A cell is Maze.CELL across, wall middle to
## wall middle: a way through a wall one cell long is a slot that much narrower.)
@export_range(0.5, 13.0) var wall_thick := 3.2
## Rows of cells of solid stone round the inside of the ring, making the wall
## round what it is round that much thicker (and the ring that much further out):
## each way in a slot through it.
@export_range(0, 6) var rampart := 0
## How high the wall round the inside of the ring is, metres: the wall between it
## and what it is round, its rampart, and the walls either side of its entrances.
@export_range(20.0, 200.0) var inner_height := 46.0
## The chance a passage goes on straight when it can.
@export_range(0.0, 1.0) var straight := 0.0
## The chance a passage grows from an older place instead of the newest.
@export_range(0.0, 1.0) var branching := 0.0
## The share of blocks with a wall knocked through afterwards.
@export_range(0.0, 0.5) var loops := 0.06
## How far each way in runs, in cells, as a narrow entrance (one cell wide) before
## it opens into the ring's halls; 0 (or 1) for none.
@export_range(0, 16) var entrance := 0
## How wide the way through an entrance is, metres: walls of the next ring's
## height fill the rest of the cell either side of it (0: the whole cell is open).
@export_range(0.0, 12.0) var doorway := 0.0

@export_group("On the walls")
## The share of wall faces with a terrace against them: steps of stone like those
## of something far bigger than a boy, with ivy up their faces to climb.
@export_range(0.0, 1.0) var terraces := 0.13
## Of those, the share with an upper terrace set back above the lower.
@export_range(0.0, 1.0) var upper_terraces := 0.55
## The share of terraces matched by one across the hall, with a rope bridge between.
@export_range(0.0, 1.0) var bridges := 0.45
## Of upper terraces, the share with ivy on up to the top of the wall.
@export_range(0.0, 1.0) var ivy_to_top := 0.35
## The share of terraces with a vine to swing on, hung from a beam out over them.
@export_range(0.0, 1.0) var terrace_vines := 0.5
## The share of halls with a rope bridge across from wall top to wall top.
@export_range(0.0, 1.0) var top_bridges := 0.05
## The share of wall faces with a vine hanging from the top of the wall, down to
## a jump over the ground.
@export_range(0.0, 1.0) var wall_vines := 0.0

## For tests and tools: styles used in place of the defaults while set.
static var chosen: Array[MazeStyle] = []


static func made(width_cells: int, hall_span: int, straightness: float, branches: float, loop_share: float, way_in := 0, door := 0.0) -> MazeStyle:
	var style := MazeStyle.new()
	style.width = width_cells
	style.span = hall_span
	style.straight = straightness
	style.branching = branches
	style.loops = loop_share
	style.entrance = way_in
	style.doorway = door
	return style


## Avenues: the first ring. The simplest maze, but big: halls two cells wide
## (about 25 m between walls) that run long and straight, few turns and few side
## branches. Its walls are massive, 12 m thick, so each way through a wall a
## cell long is a slot about three of him wide; and the wall round the clearing
## is a rampart 54 m thick and 92 m high (twice the other walls between rings),
## each gate a slot through it.
static func avenues() -> MazeStyle:
	var style := made(6, 2, 0.5, 0.0, 0.0)
	style.wall_thick = 12.0
	# (the clearing's wall three cells thicker, 54 m in all, a slot through it at each gate)
	style.rampart = 3
	style.inner_height = 92.0
	# (nothing on its walls but vines hanging from their tops)
	style.terraces = 0.0
	style.top_bridges = 0.0
	style.wall_vines = 0.1
	return style


## Warren: a close maze of single halls that wind and fork (the first ring's
## old rules), with terraces, ivy, vines and rope bridges to climb.
static func warren() -> MazeStyle:
	return made(4, 1, 0.0, 0.0, 0.06)


## Tangle: single halls that branch often and loop back on themselves, so that
## there are many ways and it is easy to go round in circles.
static func tangle() -> MazeStyle:
	return made(4, 1, 0.3, 0.5, 0.2)


## The styles of the rings, from the clearing out, when a maze is not given its own.
static func defaults() -> Array[MazeStyle]:
	if not chosen.is_empty():
		return chosen
	return [avenues(), warren(), tangle()]
