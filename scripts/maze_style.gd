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

## Cells deep, from the ring's inside wall to its outside wall (on each side).
@export_range(1, 16) var width := 4
## Cells across a hall.
@export_range(1, 4) var span := 1
## The chance a passage goes on straight when it can.
@export_range(0.0, 1.0) var straight := 0.0
## The chance a passage grows from an older place instead of the newest.
@export_range(0.0, 1.0) var branching := 0.0
## The share of blocks with a wall knocked through afterwards.
@export_range(0.0, 0.5) var loops := 0.06
## How far each way in runs, in cells, as a narrow entrance (one cell wide) before
## it opens into the ring's halls; 0 (or 1) for none.
@export_range(0, 16) var entrance := 0


static func made(width_cells: int, hall_span: int, straightness: float, branches: float, loop_share: float, way_in := 0) -> MazeStyle:
	var style := MazeStyle.new()
	style.width = width_cells
	style.span = hall_span
	style.straight = straightness
	style.branching = branches
	style.loops = loop_share
	style.entrance = way_in
	return style


## Avenues: the first ring. The simplest maze, but big: halls two cells wide
## (about 25 m between walls) that run long and straight, few turns and few side
## branches. The ways in from the clearing are narrow and deep: 6 cells (84 m)
## of passage one cell wide, out through the ring before it opens up.
static func avenues() -> MazeStyle:
	return made(6, 2, 0.5, 0.0, 0.0, 4)


## Warren: a close maze of single halls that wind and fork (the first ring's
## old rules).
static func warren() -> MazeStyle:
	return made(4, 1, 0.0, 0.0, 0.06)


## Tangle: single halls that branch often and loop back on themselves, so that
## there are many ways and it is easy to go round in circles.
static func tangle() -> MazeStyle:
	return made(4, 1, 0.3, 0.5, 0.2)


## The styles of the rings, from the clearing out, when a maze is not given its own.
static func defaults() -> Array[MazeStyle]:
	return [avenues(), warren(), tangle()]
