@tool
class_name MezzanineLevel
extends Resource
## One level of ledge along a section's walls (MazeStyle.mezzanines): how far it rises
## over the level under it (the first, over the ground), how deep it stands out from
## the wall, and along how many of the faces that have the level under it it runs (the
## first runs along every wall). The levels stack by themselves, each standing on the
## one under it (the user, 2026-10-18: "I should be able to add mezzanines as a list and
## control them indvidiually, height and depth. The automatically get stacked on top of
## eachother, and the limits of depth and theight should be the whole hallway for
## edditing purposes").
##
## The sliders run up to the highest maze wall (120 m) and across the widest hall
## (4 cells, 56 m), and further typed in; laying out keeps them sensible for the
## section (MazeStyle.level_height, level_depth): no level over its walls' tops, none
## so deep that ledges facing each other close the hall.

## How high this level's top is over the top of the level under it (the first: over the ground), metres.
@export_range(0.0, 120.0, 0.01, "or_greater", "suffix:m") var height := 8.0
## How deep it stands out from the wall, metres (shallower than the level under it, it steps back).
@export_range(0.0, 56.0, 0.01, "or_greater", "suffix:m") var depth := 1.2
## Of the faces with the level under it, how many have this one too (a share, 0 to 1; 1: every one; the first level
## runs along every wall whatever this is).
@export_range(0.0, 1.0, 0.001, "suffix:of faces") var share := 1.0


## A level `height` over the one under it, `depth` deep, along `share` of the faces under it.
static func made(rise: float, deep: float, faces := 1.0) -> MezzanineLevel:
	var level := MezzanineLevel.new()
	level.height = rise
	level.depth = deep
	level.share = faces
	return level
