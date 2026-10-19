@tool
class_name RoundStyle
extends MazeStyle
## How one round section is made (MazeLayout's round sections, out past the
## desert): rings of passages between circular walls (see RoundMaze), or circles
## of rotating doors, or one great tunnel round (its layout). Only what a round
## section is made by is shown: how wide it is and its hallways, its walls, and
## the rules its passages are grown by (or its doors, or its tunnel). Its border
## wall is the circle round its outside.

## What a round section is.
enum Layout {
	## Passages between walls, grown as a maze.
	MAZE,
	## Halls round it between circles of wall, each circle broken by doorways with
	## a great slab turning in each on a pivot: the way through is to time it.
	ROTATING_DOORS,
	## One wide roofed tunnel all the way round, lit by openings in its roof.
	TUNNEL,
}

## What a round section goes by (the rest of a MazeStyle is not used for one).
const SHOWN: Array[StringName] = [
	&"section_width_cells", &"hallway_diameter_cells", &"maze_wall_diameter", &"maze_wall_height",
	&"section_border_wall_height", &"straight_on_chance", &"side_branch_chance", &"loop_share",
	&"wall_moss_height", &"wall_moss_patches", &"wall_texture_scale",
	&"wall_edge_rounding", &"border_wall_edge_rounding", &"wall_weathering",
]
## Of those, what only a maze goes by.
const MAZE_ONLY: Array[StringName] = [&"hallway_diameter_cells", &"straight_on_chance", &"side_branch_chance", &"loop_share"]
## What its doors go by, and its tunnel.
const DOORS_SHOWN: Array[StringName] = [&"door_circles", &"door_count", &"door_turn_seconds", &"door_gap_width"]
const TUNNEL_SHOWN: Array[StringName] = [&"tunnel_width", &"tunnel_height", &"tunnel_skylight_spacing"]

@export_group("Layout")
## What the section is: a maze, circles of rotating doors, or one tunnel round.
@export var layout := Layout.MAZE:
	set(value):
		layout = value
		notify_property_list_changed()

@export_group("Rotating doors")
## How many circles of doors there are across the section, one behind another (halls round between them).
@export_range(1, 6, 1, "suffix:circles") var door_circles := 3
## How many doorways each circle has, spread round it (each with its door).
@export_range(4, 96, 1, "suffix:per circle") var door_count := 30
## How long a door takes to turn half round, seconds: from one opening to the next.
@export_range(2.0, 60.0, 0.001, "suffix:s") var door_turn_seconds := 9.0
## How wide the gap is either side of a door when it stands open (edge on), metres.
@export_range(1.5, 20.0, 0.001, "suffix:m") var door_gap_width := 4.5

@export_group("Tunnel")
## How wide the tunnel is inside, wall to wall, metres.
@export_range(10.0, 80.0, 0.001, "suffix:m") var tunnel_width := 26.0
## How high its roof is, metres.
@export_range(6.0, 60.0, 0.001, "suffix:m") var tunnel_height := 18.0
## How far apart the openings in its roof are, round it, metres.
@export_range(10.0, 200.0, 0.001, "suffix:m") var tunnel_skylight_spacing := 34.0


func _init() -> void:
	round_section = true


## A round style with what a round section goes by taken from `style` (a
## MazeStyle with round section on, as layouts saved before RoundStyle had them).
static func from(style: MazeStyle) -> RoundStyle:
	var made := RoundStyle.new()
	for property in SHOWN:
		made.set(property, style.get(property))
	if style is RoundStyle:
		for property: StringName in [&"layout"] + DOORS_SHOWN + TUNNEL_SHOWN:
			made.set(property, style.get(property))
	return made


func _validate_property(property: Dictionary) -> void:
	# (MazeStyle's first: its feature boxes are not saved as themselves)
	super(property)
	var name := StringName(property.name)
	if name == &"round_section":
		# (it is always round: not saved either)
		property.usage = PROPERTY_USAGE_NONE
	elif not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
		return
	elif name == &"layout":
		return
	elif DOORS_SHOWN.has(name):
		if layout != Layout.ROTATING_DOORS:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	elif TUNNEL_SHOWN.has(name):
		if layout != Layout.TUNNEL:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	elif not SHOWN.has(name) or (layout != Layout.MAZE and MAZE_ONLY.has(name)) or (layout == Layout.TUNNEL and name == &"section_width_cells"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
