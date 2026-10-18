@tool
class_name RoundStyle
extends MazeStyle
## How one round section is made (MazeLayout's round sections, out past the
## desert): rings of passages between circular walls (see RoundMaze). Only what
## a round section is made by is shown: how wide it is and its hallways, its
## walls, and the rules its passages are grown by. Its border wall is the circle
## round its outside.

## What a round section goes by (the rest of a MazeStyle is not used for one).
const SHOWN: Array[StringName] = [
	&"section_width_cells", &"hallway_diameter_cells", &"maze_wall_diameter", &"maze_wall_height",
	&"section_border_wall_height", &"straight_on_chance", &"side_branch_chance", &"loop_share",
	&"wall_moss_height", &"wall_moss_patches", &"wall_texture_scale",
]


func _init() -> void:
	round_section = true


## A round style with what a round section goes by taken from `style` (a
## MazeStyle with round section on, as layouts saved before RoundStyle had them).
static func from(style: MazeStyle) -> RoundStyle:
	var made := RoundStyle.new()
	for property in SHOWN:
		made.set(property, style.get(property))
	return made


func _validate_property(property: Dictionary) -> void:
	if property.name == "round_section":
		# (it is always round: not saved either)
		property.usage = PROPERTY_USAGE_NONE
	elif property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not SHOWN.has(StringName(property.name)):
		property.usage &= ~PROPERTY_USAGE_EDITOR
