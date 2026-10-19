@tool
class_name MazeLayout
extends Node3D
## A maze laid out as pieces (MazePiece) that can be seen and changed in the
## editor: every run of wall, pier and terrace, every patch of ivy, vine, rope
## bridge and tree, and the light past the exit. Choose a seed and how many rings,
## press Generate, then move, resize, copy or delete pieces by hand, and save.
## A layout saved in res://mazes/ is played (see Mazes); MazeBuilder.realize turns
## it into the maze the game plays, generated or changed by hand alike.
##
## What the game goes by is the pieces themselves: which lines between cells have
## a wall on them is read from where the wall and pier pieces stand (see `plan`),
## so a wall moved, added or taken away changes the maze for the things that hunt
## in it and for the way out. Walls only count where they stand on the grid's
## lines (every Maze.CELL metres, half a cell off the middle), as generated ones do.
##
## The sections, their gates and the clearing come from the seed, `rings` and the styles.

## Which maze to start from.
@export var maze_seed := 1
## How many rings round the clearing, as the game counts them: the square sections
## first, then the desert (one ring), then the round sections; shown as built.
@export_range(1, 7) var rings := 1
## How the clearing is made (ClearingStyle): its wall, its level middle, its hills
## and its woods. Empty: the game's own, which Generate fills in here to be changed.
@export var clearing_style: ClearingStyle
## How each square section is made, from the clearing out (MazeStyle): its width,
## how wide its halls are, the rules of its passages and its entrances, what is
## on its walls and what hunts it. Empty: the game's own, which Generate fills in.
@export var square_sections: Array[MazeStyle] = []
## The desert between the square sections and the round ones (DesertStyle).
@export var desert: DesertStyle
## How each round section is made, from the desert out (RoundStyle).
@export var round_sections: Array[RoundStyle] = []

## Every section's style, square then round (Maze.styles). (A layout saved
## before they were apart had them all in this one list: it is shared out.)
var styles: Array[MazeStyle]:
	get:
		var all: Array[MazeStyle] = []
		all.append_array(square_sections)
		all.append_array(round_sections)
		return all
	set(value):
		square_sections.clear()
		round_sections.clear()
		for style in value:
			if style is RoundStyle:
				round_sections.append(style)
			elif style and style.round_section:
				round_sections.append(RoundStyle.from(style))
			elif style:
				square_sections.append(style)
## How many times as many of what hunts as the sections' styles say ("What hunts
## it": each count times this, rounded). The user, 2026-10-18: "The monster
## frequency should be much higher".
@export_range(0.0, 10.0, 0.25, "suffix:x") var monster_multiplier := MONSTER_MULTIPLIER
const MONSTER_MULTIPLIER := 3.0
## Whether the game plays this one when it is in res://mazes/.
@export var playable := true
## In the editor, whether it is lit and misted as in the game (off: the editor's
## own plain light, easier for laying out from above).
@export var game_light := true:
	set(value):
		game_light = value
		_show_in_editor()
## Live preview: the maze shown as the game builds it from these rules, and built
## again a moment after any of them is changed, so that what a setting does is
## seen at once. Nothing of it is saved, and the pieces (Generate's) are hidden
## while it is on: Clear them for a light scene, Generate when you want pieces to
## move by hand. (No grass or undergrowth; ivy, here as in the pieces, is flat green.)
@export var live_preview := false:
	set(value):
		live_preview = value
		_preview_key = ""
		_show_in_editor()
## Hall view: a plan of the halls, to look down into from above. Every wall is
## cut off this many metres up, its inside dark where it is cut, and what is on
## the walls and over the halls (ivy, vines, bridges, cables, props) is hidden. 0:
## off, the maze whole. In the editor only (the user, 2026-10-18: "theres also not
## an easy way to view the hallways in the editor").
@export_range(0.0, 60.0, 0.5, "suffix:m") var hall_view := 0.0:
	set(value):
		hall_view = value
		_show_hall_view()
@export_tool_button("Generate", "Reload") var generate_button := generate
@export_tool_button("Generate All", "Reload") var generate_all_button := generate_all
@export_tool_button("Clear", "Remove") var clear_button := clear

## Where the pieces of each kind go.
const GROUPS := {
	MazePiece.Kind.WALL: "Walls", MazePiece.Kind.PIER: "Piers", MazePiece.Kind.TERRACE: "Terraces",
	MazePiece.Kind.IVY: "Ivy", MazePiece.Kind.VINE: "Vines", MazePiece.Kind.BRIDGE: "Bridges",
	MazePiece.Kind.TREE: "Trees", MazePiece.Kind.BEACON: "Beacon", MazePiece.Kind.STRAND: "Strands", MazePiece.Kind.PIPE: "Pipes",
	MazePiece.Kind.PROP: "Props", MazePiece.Kind.WIRE: "Wires", MazePiece.Kind.POND: "Ponds", MazePiece.Kind.ANCHOR: "Anchors",
}

## What each zone (see zone_at) was laid out from at the last Generate (zone_keys):
## Generate lays out again only the zones whose key has changed since, and leaves
## the pieces of the rest (and what was done to them by hand) as they are.
@export_storage var generated_keys := {}

## While laying out (lay_out): the zones being laid out (all, if empty), and the plan
## they are of; and the zone the pieces now being put down count as, where it is
## not where they stand (-1: where they stand).
var laying_zone := -1
var _zones := {}
var _zone_plan: Maze
# (kind -> the number the next piece of it is named with, while laying out)
var _numbers := {}
# A view of some of another layout's pieces (zone_views): kind -> its pieces there.
var _only := {}
var _is_view := false

var _editor_shown: Array[Node] = []
# The live preview: the rules it was built for, the rules seen at the last look
# (it is built once they have stayed the same a moment), and when it looks next.
var _preview_key := ""
var _pending_key := ""
var _look_in := 0.0
var _preview_pieces: MazeLayout
# The live preview zone by zone: what each was built from (zone_keys), what was
# built of each (a MazeBuilder; the ground under all, "ground"; the round sections,
# "round") and the views of the pieces each was built from.
var _preview_keys := {}
var _preview_built := {}
var _preview_views := {}
var _preview_root: Node3D
# (and the key of each zone's stone, _stone_key, and of the ground, so that they are
# kept where they have not changed)
var _preview_stone := {}
var _preview_ground := 0


func _ready() -> void:
	_show_in_editor()
	set_process(Engine.is_editor_hint())


func _notification(what: int) -> void:
	# (the preview's pieces are in no tree: nothing else frees them)
	if what == NOTIFICATION_PREDELETE:
		_drop_preview()


func _process(delta: float) -> void:
	if not live_preview or not is_inside_tree():
		return
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.25
	var key := rules_key()
	if key == _preview_key:
		return
	# (built once a change has stopped: not again and again while a slider is dragged)
	if key == _pending_key:
		_show_in_editor()
	_pending_key = key


## Every rule the maze is made by, as one string: it changes when any does.
func rules_key() -> String:
	var values: Array = [maze_seed, rings]
	for rules: Resource in styles + [clearing_style, desert]:
		values.append(_rules_of(rules))
	return var_to_str(values)


## The settings of a style (MazeStyle, ClearingStyle, DesertStyle), as a list.
static func _rules_of(rules: Resource) -> Array:
	var values: Array = []
	if rules == null:
		return values
	for property in rules.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "entrance_spots":
			values.append(rules.get(property.name))
	return values


## The zone a point is in: 0 the clearing, then each square section as Maze counts
## its rings, and `maze.rings + 1` past them (the desert and beyond, and the ground
## outside a maze that stops at a section). The maze is laid out and built zone by
## zone in the editor, so that a change to one zone's rules builds only it again.
static func zone_at(maze: Maze, point: Vector3) -> int:
	return clampi(maze.ring_of(maze.cell_at(point)), 0, maze.rings + 1)


## The zone a piece is in: where it stands, or the zone it was laid out for.
static func zone_of(maze: Maze, piece: MazePiece) -> int:
	if piece.has_meta(&"zone"):
		return piece.get_meta(&"zone")
	return zone_at(maze, piece.position)


## The rules of a section that change what is in the zones either side of it: how
## thick its walls are (the wall between is the thicker of the two) and its border
## wall (round its outside). (Its width moves every ring past it, and how many ways
## into it there are moves the gates: both are in every zone's key anyway.)
const NEIGHBOUR_RULES: Array[String] = ["maze_wall_diameter", "section_border_wall_height", "border_wall_thickness_cells", "round_section"]


## For each zone of `maze` (zone_at), and for its round sections ("round"), a key
## of all that what is laid out and built there comes from: the seed, the sizes of
## the rings, the zone's rules and what of those either side reaches over
## (NEIGHBOUR_RULES: the walls between are both of theirs), its walls and those
## along its edge, and the gates into it and out of it. Where a key is the same as
## before, the zone comes out the same (tests/zones_test.gd).
static func zone_keys(maze: Maze) -> Dictionary:
	var common := [maze.maze_seed, maze.rings, maze.ring_sizes, maze.round_rings != null]
	# ring -> a hash of its cells' walls, rampart and entrances, in order; and the
	# same of the cells of other rings next to it (corners too: a pier at a corner
	# stands by all four cells round it)
	var cells := {}
	var edges := {}
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		var ring := maze.ring_of(cell)
		var what := [i, maze.east[i], maze.south[i], maze.solid.has(cell), maze.entrances.has(cell),
			maze.blocked(cell, Vector2i(-1, 0)), maze.blocked(cell, Vector2i(0, -1))]
		cells[ring] = hash([cells.get(ring, 0), what])
		var beside := {}
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var other := maze.ring_of(cell + step)
			if other != ring and not beside.has(other):
				beside[other] = true
				edges[other] = hash([edges.get(other, 0), what])
	var clearing := _rules_of(maze.clearing_style)
	var keys := {}
	for zone in maze.rings + 2:
		var parts: Array = [common, cells.get(zone, 0), edges.get(zone, 0)]
		for ring in range(zone - 1, zone + 2):
			var style: MazeStyle = maze.styles[ring - 1] if ring >= 1 and ring <= maze.styles.size() else null
			if style == null:
				parts.append([])
			elif ring == zone:
				parts.append(_rules_of(style))
			else:
				# (of the zones either side, what reaches over: the walls between)
				parts.append(NEIGHBOUR_RULES.map(func(rule: String) -> Variant: return style.get(rule)))
			parts.append(maze.gates[ring - 1] if ring >= 1 and ring <= maze.gates.size() else [])
		# (the clearing's rules shape its wall, the first section's ramparts and the
		# marsh gate's water; and the trees, in it and outside the maze)
		if zone <= 1 or zone == maze.rings + 1:
			parts.append(clearing)
		if zone >= maze.rings:
			parts.append([_rules_of(maze.desert_style), maze.ways_out])
		keys[zone] = hash(var_to_str(parts))
	var outer: Array = [common, clearing, _rules_of(maze.desert_style), maze.ways_out, maze.size]
	for style in maze.styles.slice(maze.rings):
		outer.append(_rules_of(style))
	keys["round"] = hash(var_to_str(outer))
	return keys


## Of a section's rules, those its walls are drawn by (MazeBuilder._walls).
const WALL_LOOK_RULES: Array[String] = ["wall_edge_rounding", "border_wall_edge_rounding", "wall_weathering",
	"wall_moss_height", "wall_moss_patches", "wall_texture_scale"]


## A key of the stone (walls, piers, terraces) and standing water of `view` (zone
## `zone` of `maze`), and of how its walls are drawn: where it is as before, the
## live preview keeps the walls it built there, and the ground if no zone's changed.
static func _stone_key(view: MazeLayout, maze: Maze, zone: int) -> int:
	var parts: Array = []
	for kind: MazePiece.Kind in [MazePiece.Kind.WALL, MazePiece.Kind.PIER, MazePiece.Kind.TERRACE, MazePiece.Kind.POND]:
		for piece in view.pieces(kind):
			parts.append(var_to_str([kind, piece.transform, piece.size, piece.style, piece.great, piece.ledge, piece.length, piece.width]))
	parts.sort()
	# (a zone's walls are drawn as its section's: the clearing's as the first, outside as the last)
	var style: MazeStyle = maze.styles[clampi(zone, 1, maxi(maze.rings, 1)) - 1] if not maze.styles.is_empty() else null
	if style:
		parts.append(WALL_LOOK_RULES.map(func(rule: String) -> Variant: return style.get(rule)))
	return hash(var_to_str(parts))


## The zones (zone_at) whose key in `now` (zone_keys) is not the one in `before`,
## as zone -> true ("round" among them).
static func changed_zones(before: Dictionary, now: Dictionary) -> Dictionary:
	var changed := {}
	for zone in now:
		if before.get(zone) != now[zone]:
			changed[zone] = true
	return changed


## Takes away every piece in `zones` (zone -> true) of `maze`.
func remove_zones(maze: Maze, zones: Dictionary) -> void:
	for kind: MazePiece.Kind in GROUPS:
		for piece in pieces(kind):
			if zones.has(zone_of(maze, piece)):
				piece.get_parent().remove_child(piece)
				piece.queue_free()


## For each of `zones` (zone -> true) of `maze`, a layout that is a view of the
## pieces of this one in it, for MazeBuilder.realize_zone (not in the tree: free each).
func zone_views(maze: Maze, zones: Dictionary) -> Dictionary:
	var views := {}
	for zone in zones:
		var view := MazeLayout.new()
		view._is_view = true
		view.maze_seed = maze_seed
		views[zone] = view
	for kind: MazePiece.Kind in GROUPS:
		for piece in pieces(kind):
			var view: MazeLayout = views.get(zone_of(maze, piece))
			if view:
				if not view._only.has(kind):
					var found: Array[MazePiece] = []
					view._only[kind] = found
				(view._only[kind] as Array[MazePiece]).append(piece)
	return views


## In the editor: the ground under the pieces, and (with `game_light`) the game's
## sky, mist and sun, so that it is seen as it will be played. None of it is saved.
func _show_in_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for shown: Node in _editor_shown:
		shown.queue_free()
	_editor_shown.clear()
	var open := get_tree().edited_scene_root
	if open == null or not (open == self or open.is_ancestor_of(self)):
		return
	_show_hall_view()
	for kind: MazePiece.Kind in GROUPS:
		var holder := get_node_or_null(NodePath(GROUPS[kind])) as Node3D
		if holder:
			holder.visible = not live_preview and not (hall_view > 0.0 and HALL_VIEW_HIDES.has(kind))
	if live_preview:
		_show_preview()
		_light()
		return
	_drop_preview()
	var size := Maze.ring_extent(rings + 1, styles, clearing_style) + 80.0
	# (the round sections, past the moor, are not pieces: they are shown as the
	# game will build them, from the seed and their styles)
	var plan := Maze.generate(maze_seed, rings, styles, clearing_style, desert)
	var outer := plan.round_rings
	if outer:
		size = (outer.outermost() + 300.0) * 2.0
		var sections := RoundBuilder.new()
		sections.plan = outer
		add_child(sections, false, Node.INTERNAL_MODE_BACK)
		_editor_shown.append(sections)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = MazeStone.ground(Maze.CLEARING * Maze.CELL * 0.5, plan.extent() * 0.5, MazeBuilder.WALL_THICK)
	add_child(ground, false, Node.INTERNAL_MODE_BACK)
	_editor_shown.append(ground)
	if clearing_style and clearing_style.shaped():
		var field := MazeBuilder.hills(clearing_style, maze_seed, ground.material_override)
		add_child(field, false, Node.INTERNAL_MODE_BACK)
		_editor_shown.append(field)
	_light()


## With `game_light`, the game's sky, mist and sun (unless the scene has its own).
func _light() -> void:
	if game_light and get_tree().edited_scene_root.find_children("*", "WorldEnvironment", true, true).is_empty():
		var before := get_child_count(true)
		MazeLight.put(self, true)
		for i in range(before, get_child_count(true)):
			_editor_shown.append(get_child(i, true))


## The live preview: the maze built as the game builds it (MazeBuilder), from
## pieces laid out but never put in the scene (so none draws itself or is saved).
## It is built zone by zone (zone_at), and kept: when the rules change, only the
## zones whose key (zone_keys) has changed are laid out and built again, and the
## ground under them all.
func _show_preview() -> void:
	var started := Time.get_ticks_msec()
	_preview_key = rules_key()
	_pending_key = _preview_key
	var plan := Maze.generate(maze_seed, rings, styles, clearing_style, desert)
	var keys := zone_keys(plan)
	var changed := changed_zones(_preview_keys, keys)
	if changed.is_empty() and is_instance_valid(_preview_root):
		return
	var whole := changed.size() >= keys.size() or not is_instance_valid(_preview_pieces) or not is_instance_valid(_preview_root)
	if whole:
		_drop_preview()
		changed = changed_zones({}, keys)
		_preview_root = Node3D.new()
		_preview_root.name = "Preview"
		add_child(_preview_root, false, Node.INTERNAL_MODE_BACK)
		_preview_pieces = MazeLayout.new()
		_preview_pieces.lay_out(plan)
	else:
		_preview_pieces.remove_zones(plan, changed)
		_preview_pieces.lay_out(plan, changed)
	plan.ponds = Ponds.read(_preview_pieces)
	var zones := {}
	for zone in changed:
		if zone is int:
			zones[zone] = true
	var views := _preview_pieces.zone_views(plan, zones)
	var kept := 0
	for zone: int in zones:
		# (its walls as they were, if its stone is: only what is on them changed)
		var stone := _stone_key(views[zone], plan, zone)
		var walls: Node = null
		var old: Node = _preview_built.get(zone)
		if _preview_stone.get(zone) == stone and is_instance_valid(old):
			walls = old.get_node_or_null("Walls")
			if walls:
				old.remove_child(walls)
				kept += 1
		var built := MazeBuilder.new()
		built.name = "Zone%d" % zone
		built.preview = true
		_put_preview(zone, built)
		built.realize_zone(views[zone], plan, walls)
		_hide_for_hall_view(built)
		_preview_stone[zone] = stone
		if is_instance_valid(_preview_views.get(zone)):
			(_preview_views[zone] as MazeLayout).free()
		_preview_views[zone] = views[zone]
	# (the ground under it all, which shows where the walls stand, and the water in
	# it: built again only if they, or the clearing's hills or the desert, have changed)
	var stones: Array = []
	for zone in keys:
		if zone is int:
			stones.append(_preview_stone.get(zone))
	var ground_key := hash(var_to_str([stones, plan.ring_sizes, _rules_of(plan.clearing_style), keys.get("round")]))
	if ground_key != _preview_ground or not is_instance_valid(_preview_built.get("ground")):
		var ground := MazeBuilder.new()
		ground.name = "Ground"
		ground.preview = true
		_put_preview("ground", ground)
		ground.realize_ground(_preview_pieces, plan)
		_preview_ground = ground_key
	else:
		kept += 1
	if changed.has("round"):
		var sections: RoundBuilder = null
		if plan.round_rings:
			sections = RoundBuilder.new()
			sections.name = "Round"
			sections.plan = plan.round_rings
		_put_preview("round", sections)
	_preview_keys = keys
	print("Maze preview: %s built in %.1f s%s" % ["every zone" if whole else _zone_names(plan, changed), (Time.get_ticks_msec() - started) / 1000.0,
		" (walls and ground kept)" if kept > zones.size() else (" (some walls kept)" if kept > 0 else "")])


## The pieces the hall view hides (of the live preview, all of a zone's Features and Props).
const HALL_VIEW_HIDES: Array[MazePiece.Kind] = [MazePiece.Kind.IVY, MazePiece.Kind.VINE, MazePiece.Kind.BRIDGE,
	MazePiece.Kind.STRAND, MazePiece.Kind.PIPE, MazePiece.Kind.PROP, MazePiece.Kind.WIRE, MazePiece.Kind.ANCHOR, MazePiece.Kind.BEACON]


## Shows the hall view (hall_view) as it is now set: the walls cut off by their
## shader (Wall.shader, in the editor), and what is on them hidden.
func _show_hall_view() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	Wall.shader()
	RenderingServer.global_shader_parameter_set(&"maze_cut", hall_view)
	for kind: MazePiece.Kind in HALL_VIEW_HIDES:
		var holder := get_node_or_null(NodePath(GROUPS[kind])) as Node3D
		if holder:
			holder.visible = not live_preview and hall_view <= 0.0
	for built: Variant in _preview_built.values():
		if is_instance_valid(built):
			_hide_for_hall_view(built)


func _hide_for_hall_view(built: Node) -> void:
	for part: String in ["Features", "Props"]:
		var node := built.get_node_or_null(part) as Node3D
		if node:
			node.visible = hall_view <= 0.0


## Puts `node` (or nothing) in the live preview as what is built of `part`, in
## place of what was.
func _put_preview(part: Variant, node: Node) -> void:
	var old: Node = _preview_built.get(part)
	if is_instance_valid(old):
		old.get_parent().remove_child(old)
		old.queue_free()
	_preview_built.erase(part)
	if node:
		_preview_root.add_child(node)
		_preview_built[part] = node


## Takes the live preview away.
func _drop_preview() -> void:
	if is_instance_valid(_preview_root) and not is_queued_for_deletion():
		_preview_root.queue_free()
	_preview_root = null
	_preview_built.clear()
	for view: MazeLayout in _preview_views.values():
		if is_instance_valid(view):
			view.free()
	_preview_views.clear()
	_preview_keys.clear()
	_preview_stone.clear()
	_preview_ground = 0
	if is_instance_valid(_preview_pieces):
		_preview_pieces.free()
	_preview_pieces = null


## Lays out the maze for `maze_seed` and `rings`, in place of what is here: only the
## zones (zone_at) whose rules, or whose walls and gates or their neighbours',
## have changed since the last Generate, leaving the rest and what was done to
## them by hand as they are. Generate All lays out every zone again.
func generate() -> void:
	_fill_in_styles()
	var started := Time.get_ticks_msec()
	var plan := Maze.generate(maze_seed, rings, styles, clearing_style, desert)
	var keys := zone_keys(plan)
	var changed := changed_zones(generated_keys, keys)
	var whole := generated_keys.is_empty() or changed.size() >= keys.size() or get_child_count() == 0
	if whole:
		clear()
		lay_out(plan)
	else:
		remove_zones(plan, changed)
		lay_out(plan, changed)
	generated_keys = keys
	_show_in_editor()
	if Engine.is_editor_hint():
		print("Maze generated (%s) in %.1f s" % ["every zone" if whole else _zone_names(plan, changed), (Time.get_ticks_msec() - started) / 1000.0])


## Lays out every zone again, in place of what is here.
func generate_all() -> void:
	generated_keys = {}
	generate()


## The zones in `zones` of `maze`, by name, for the editor's output.
static func _zone_names(maze: Maze, zones: Dictionary) -> String:
	var names: Array[String] = []
	for zone in zones:
		if zone is String:
			names.append("the round sections")
		elif zone == 0:
			names.append("the clearing")
		elif zone > maze.rings:
			names.append("outside")
		else:
			names.append("section %d" % zone)
	return ", ".join(names) if not names.is_empty() else "nothing changed"


## The game's own styles, filled in to be changed here, where none are set.
func _fill_in_styles() -> void:
	if square_sections.is_empty():
		square_sections = MazeStyle.square_defaults()
	if round_sections.is_empty():
		round_sections.assign(MazeStyle.round_defaults())
	if clearing_style == null:
		clearing_style = ClearingStyle.new()
	if desert == null:
		desert = DesertStyle.new()


## Takes away every piece.
func clear() -> void:
	generated_keys = {}
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Every piece of a kind.
func pieces(kind: MazePiece.Kind) -> Array[MazePiece]:
	var found: Array[MazePiece] = []
	if _is_view:
		found.assign(_only.get(kind, []))
		return found
	var group := get_node_or_null(NodePath(GROUPS[kind]))
	if group:
		for child in group.get_children():
			if child is MazePiece and (child as MazePiece).kind == kind:
				found.append(child)
	# (and any put somewhere else by hand)
	for child in get_children():
		if child is MazePiece and (child as MazePiece).kind == kind:
			found.append(child)
	return found


## The maze as it now stands: the rings, clearing and gates of the seed, with
## the walls where the wall and pier pieces are.
func plan() -> Maze:
	var maze := Maze.generate(maze_seed, rings, styles, clearing_style, desert)
	var blocks: Array[MazePiece] = pieces(MazePiece.Kind.WALL) + pieces(MazePiece.Kind.PIER)
	maze.set_walls(func(cell: Vector2i, step: Vector2i) -> bool:
		var on_line := maze.world(cell) + Vector3(step.x, 0.0, step.y) * Maze.CELL * 0.5 + Vector3.UP * 2.0
		for block in blocks:
			# (a ledge along a wall stands out from it, but is not a wall)
			if block.ledge:
				continue
			if block.box_has(on_line, 0.05):
				return true
		return false)
	# (the standing water where the pond pieces lie: the ground under it is lower)
	maze.ponds = Ponds.read(self)
	return maze


## Puts down the pieces of `maze`: only those in `zones` (zone_at: zone -> true),
## if any are given, as they would be laid out with all the rest.
func lay_out(maze: Maze, zones: Dictionary = {}) -> void:
	_zones = {}
	for zone in zones:
		if zone is int:
			_zones[zone] = true
	# (only the round sections changed: nothing of them is pieces)
	if not zones.is_empty() and _zones.is_empty():
		return
	_zone_plan = maze
	_numbers = {}
	_lay_out(maze)
	_zones = {}
	_zone_plan = null
	_numbers = {}


func _lay_out(maze: Maze) -> void:
	maze_seed = maze.maze_seed
	# (the desert and the round sections past the square ones count too)
	rings = maze.rings + (1 + maze.round_rings.rings.size() if maze.round_rings else 0)
	clearing_style = maze.clearing_style
	desert = maze.desert_style
	var runs := _runs(maze)
	for run: Array in runs:
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": run[2]})
	# (the wall round the next ring, unbuilt, when the maze stops here; round
	# sections past the moor are RoundBuilder's)
	for run: Array in ([] if maze.round_rings else _next_ring(maze)):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": true})
	for great in [false, true]:
		for pier: Array in _piers(maze, great, _zones):
			_add(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(pier[0].x, 0.0, pier[0].z)), {"size": pier[1], "great": great})
	for rampart: Array in _ramparts(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, rampart[0]), {"size": rampart[1], "great": true})
	for gatehouse: Array in _gatehouses(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, gatehouse[0]), {"size": gatehouse[1], "great": true})
	# (along the maze walls and the great walls round the rings, the user, 2026-10-18;
	# each in the zone of the ring it looks into)
	# (and the ramparts, the clearing's thick wall, on the first section's side: as great walls, stopping at their gates)
	var ramparts := _ramparts(maze).map(func(rampart: Array) -> Array: return [rampart[0], rampart[1], true])
	for ledge: Array in _ledges(maze, runs + ramparts, runs + ramparts):
		var was := laying_zone
		laying_zone = ledge[2] if laying_zone < 0 else laying_zone
		_add(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, ledge[0]), {"size": ledge[1], "ledge": true})
		laying_zone = was
	MazeFeatures.lay_out(self, maze, _zones)
	Ponds.lay_out(self, maze, _zones)
	maze.ponds = Ponds.read(self)
	# (after the ways up and the ponds: the props keep clear of them, and cables hang by the vines)
	MazeProps.lay_out(self, maze, _zones)
	_trees(maze)
	if not maze.round_rings:
		_add(MazePiece.Kind.BEACON, Transform3D(Basis.IDENTITY, maze.world(maze.exit + maze.exit_side * 2)), {})


## Adds a piece of `kind` at `where`, with `settings` (property: value).
func add_piece(kind: MazePiece.Kind, where: Transform3D, settings: Dictionary) -> MazePiece:
	return _add(kind, where, settings)


func _add(kind: MazePiece.Kind, where: Transform3D, settings: Dictionary) -> MazePiece:
	# (laying out some zones only: none in the others)
	if not _zones.is_empty() and not _zones.has(laying_zone if laying_zone >= 0 else zone_at(_zone_plan, where.origin)):
		return null
	var group := get_node_or_null(NodePath(GROUPS[kind])) as Node3D
	if group == null:
		group = Node3D.new()
		group.name = GROUPS[kind]
		add_child(group)
		_own(group)
	var piece := MazePiece.new()
	var number := group.get_child_count() + 1
	if _zone_plan:
		# (past the highest yet: with some zones laid out again, there are gaps)
		if not _numbers.has(kind):
			_numbers[kind] = _highest_number(group) + 1
		number = _numbers[kind]
		_numbers[kind] += 1
	piece.name = "%s%d" % [String(GROUPS[kind]).trim_suffix("s"), number]
	if laying_zone >= 0:
		piece.set_meta(&"zone", laying_zone)
	piece.kind = kind
	for key: String in settings:
		piece.set(key, settings[key])
	piece.transform = where
	group.add_child(piece)
	_own(piece)
	if kind in [MazePiece.Kind.BRIDGE, MazePiece.Kind.STRAND, MazePiece.Kind.WIRE]:
		var end := Marker3D.new()
		end.name = "End"
		end.position = where.affine_inverse() * settings.get("to", where.origin + Vector3(6, 0, 0))
		piece.add_child(end)
		_own(end)
	return piece


## The highest number a piece in `group` is named with (Wall12: 12).
static func _highest_number(group: Node) -> int:
	var highest := 0
	for child in group.get_children():
		var digits := String(child.name).lstrip("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
		if digits.is_valid_int():
			highest = maxi(highest, digits.to_int())
	return highest


## In the editor, makes a node part of the scene being edited, so that it is saved.
func _own(node: Node) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var root := get_tree().edited_scene_root
	node.owner = root if root and (root == self or root.is_ancestor_of(self)) else self


## Every straight run of wall, as [middle, size, between rings] boxes.
static func _runs(maze: Maze) -> Array:
	var runs: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	# Along x, on the line north of row j (j = n is the south edge).
	for j in n + 1:
		var start := -1
		var kind := false
		var thick := 0.0
		var run_ring := -1
		var tall := 0.0
		for x in n + 2:
			var wall := false
			var great := false
			var here := 0.0
			var high := 0.0
			var in_ring := -1
			if x < n:
				var cell := Vector2i(x, j) if j < n else Vector2i(x, n - 1)
				var step := Vector2i(0, -1) if j < n else Vector2i(0, 1)
				# (none in or round a rampart: its stone is laid whole, see _ramparts)
				wall = maze.blocked(cell, step) and not maze.solid.has(cell) and not maze.solid.has(cell + step)
				great = maze.ring_wall(cell, step)
				here = maze.wall_thick(cell, step)
				high = maze.wall_height(cell, step)
				in_ring = maze.ring_of(cell)
			# (a run inside a ring stops where it crosses into the next, at the wall between:
			# each ring's walls its own, so that the editor can lay out a ring alone)
			if start >= 0 and (not wall or great != kind or here != thick or high != tall or (not kind and in_ring != run_ring)):
				var z := (j - 0.5 - middle) * Maze.CELL
				var cx := ((start + x - 1) * 0.5 - middle) * Maze.CELL
				var long := (x - start) * Maze.CELL + thick
				if not kind:
					var back := _cut_back(maze, [Vector2i(start - 1, j - 1), Vector2i(start - 1, j)], _great_z(maze, start, j), thick)
					var front := _cut_back(maze, [Vector2i(x, j - 1), Vector2i(x, j)], _great_z(maze, x, j), thick)
					long -= back + front
					cx += (back - front) * 0.5
				runs.append([Vector3(cx, tall * 0.5, z), Vector3(long, tall, thick), kind])
				start = -1
			if wall and start < 0:
				start = x
				kind = great
				thick = here
				tall = high
				run_ring = in_ring
	# Along z, on the line west of column i.
	for i in n + 1:
		var start := -1
		var kind := false
		var thick := 0.0
		var run_ring := -1
		var tall := 0.0
		for y in n + 2:
			var wall := false
			var great := false
			var here := 0.0
			var high := 0.0
			var in_ring := -1
			if y < n:
				var cell := Vector2i(i, y) if i < n else Vector2i(n - 1, y)
				var step := Vector2i(-1, 0) if i < n else Vector2i(1, 0)
				wall = maze.blocked(cell, step) and not maze.solid.has(cell) and not maze.solid.has(cell + step)
				great = maze.ring_wall(cell, step)
				here = maze.wall_thick(cell, step)
				high = maze.wall_height(cell, step)
				in_ring = maze.ring_of(cell)
			if start >= 0 and (not wall or great != kind or here != thick or high != tall or (not kind and in_ring != run_ring)):
				var x := (i - 0.5 - middle) * Maze.CELL
				var cz := ((start + y - 1) * 0.5 - middle) * Maze.CELL
				var long := (y - start) * Maze.CELL + thick
				if not kind:
					var back := _cut_back(maze, [Vector2i(i - 1, start - 1), Vector2i(i, start - 1)], _great_x(maze, i, start), thick)
					var front := _cut_back(maze, [Vector2i(i - 1, y), Vector2i(i, y)], _great_x(maze, i, y), thick)
					long -= back + front
					cz += (back - front) * 0.5
				runs.append([Vector3(x, tall * 0.5, cz), Vector3(thick, tall, long), kind])
				start = -1
			if wall and start < 0:
				start = y
				kind = great
				thick = here
				tall = high
				run_ring = in_ring
	return runs


## How far to take back the end of a run of wall inside a ring where it meets a
## great wall, so that no face of it lies in one of the great wall's (they are
## different concretes, and would flicker where they met): to the face of a
## rampart if one of `beyond` (the cells past its end, either side of its line)
## is one, to the near face of a great wall `crossing` thick across its end.
static func _cut_back(maze: Maze, beyond: Array, crossing: float, thick: float) -> float:
	for cell: Vector2i in beyond:
		if maze.solid.has(cell):
			# (a rampart stands half its wall out past its cells: see _ramparts)
			var way: Array = maze.gates[maze.ring_of(cell) - 1][0]
			return (thick + maze.wall_thick(way[0], way[1])) * 0.5
	return (thick + crossing) * 0.5 if crossing > 0.0 else 0.0


## The ramparts round the inside of rings (Maze.rampart), as [middle of the
## foot, size]: solid stone as high as the wall between rings, from the face of
## that wall out over the rampart's cells to the face of the walls beyond, as
## four sides, each broken by a slot (as narrow as a way through a wall a cell
## long) where an entrance runs through it.
static func _ramparts(maze: Maze) -> Array:
	var walls: Array = []
	for ring in range(1, maze.rings + 1):
		var cells := maze.rampart(ring)
		if cells <= 0:
			continue
		var way: Array = maze.gates[ring - 1][0]
		var thick := maze.wall_thick(way[0], way[1])
		var slot := Maze.CELL - thick
		var near := maze.ring_sizes[ring - 1] * Maze.CELL * 0.5 - thick * 0.5
		var far := near + thick + cells * Maze.CELL
		for side: Vector2i in Maze.STEPS:
			var out := Vector3(side.x, 0.0, side.y)
			var along := Vector3(absf(out.z), 0.0, absf(out.x))
			# (north and south sides run the whole way, corners and all; east and west between them)
			var reach := far if side.y != 0 else near
			var cuts: Array[float] = [-reach]
			for gate: Array in maze.gates[ring - 1]:
				if gate[1] == side:
					var at: float = maze.world(gate[0]).dot(along)
					cuts.append_array([at - slot * 0.5, at + slot * 0.5])
			cuts.append(reach)
			cuts.sort()
			for i in range(0, cuts.size(), 2):
				var long: float = cuts[i + 1] - cuts[i]
				var middle := out * (near + far) * 0.5 + along * (cuts[i] + cuts[i + 1]) * 0.5
				walls.append([middle, along * long + out.abs() * (far - near) + Vector3.UP * maze.inner_height(ring)])
	return walls


## The ledges along the walls of rings that have one (MazeStyle.mezzanine_height), as [middle
## of the foot, size, ring]: along each long face of each of `boxes` ([middle of the
## foot, size]) that looks into such a ring, and round its ends (the user, 2026-10-18:
## "the mezzanine should go around corners not just end"): where the wall ends, a ledge
## across its end face too and those along its faces on past it to meet it; where it
## turns away from the face, the one along the run along x on past the corner (the one
## along z stops at it: so that no two meet in the same stone, whose tops would
## flicker). Not past the end of a face buried in another wall, nor into another ring.
## `all` is every run of wall, `boxes` among them, for what each meets.
static func _ledges(maze: Maze, boxes: Array, all: Array = []) -> Array:
	var ledges: Array = []
	var others: Array = all if not all.is_empty() else boxes
	var inside := func(p: Vector3, besides: Array) -> bool:
		for other: Array in others:
			if other == besides:
				continue
			var half: Vector3 = other[1] * 0.5
			var c: Vector3 = other[0]
			if absf(p.x - c.x) < half.x and absf(p.z - c.z) < half.z:
				return true
		return false
	var style_at := func(p: Vector3) -> MazeStyle:
		var cell := maze.cell_at(p)
		# (none in the clearing: the user, 2026-10-18)
		var ring := maze.ring_of(cell)
		if ring < 1 or ring > maze.rings or not maze.inside(cell) or maze.solid.has(cell):
			return null
		var style: MazeStyle = maze.styles[ring - 1]
		return style if style.mezzanine_height > 0.0 else null
	for box: Array in boxes:
		var middle: Vector3 = box[0]
		var size: Vector3 = box[1]
		var long_x := size.x >= size.z
		var out := Vector3(0.0, 0.0, 1.0) if long_x else Vector3(1.0, 0.0, 0.0)
		var dir := Vector3(1.0, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, 1.0)
		var half: float = (size.z if long_x else size.x) * 0.5
		var long: float = size.x if long_x else size.z
		var centre := Vector3(middle.x, 0.0, middle.z)
		# (whether each end is a dead end: nothing else in the stone just inside it;
		# a great wall's end is the side of a gate, where its ledge stops)
		var dead := {}
		for end: float in [-1.0, 1.0]:
			dead[end] = not (box.size() > 2 and box[2]) and not inside.call(centre + dir * end * (long * 0.5 - 0.3), box)
		for way: float in [-1.0, 1.0]:
			var face := centre + out * way * half
			var style: MazeStyle = style_at.call(face + out * way * 1.0)
			if style == null:
				continue
			var ring := maze.ring_of(maze.cell_at(face + out * way * 1.0))
			var deep := style.mezzanine_depth
			var reach := {-1.0: 0.0, 1.0: 0.0}
			for end: float in [-1.0, 1.0]:
				var lip := face + out * way * deep * 0.5 + dir * end * long * 0.5
				# (buried in a wall meeting it there, or open; on past it if it ends or
				# turns away, and it is along x or the wall ends; not into another ring)
				if inside.call(lip - dir * end * 0.3, box) or not (dead[end] or long_x):
					continue
				var past: MazeStyle = style_at.call(lip + dir * end * deep * 0.5)
				if past == style and maze.ring_of(maze.cell_at(lip + dir * end * deep * 0.5)) == ring and not inside.call(lip + dir * end * deep * 0.5, box):
					reach[end] = deep
			var length: float = long + reach[-1.0] + reach[1.0]
			var foot: Vector3 = face + out * way * deep * 0.5 + dir * (float(reach[1.0]) - float(reach[-1.0])) * 0.5
			ledges.append([foot, dir * length + out * deep + Vector3.UP * style.mezzanine_height, ring])
		# Across each dead end's face, from one long face to the other.
		for end: float in [-1.0, 1.0]:
			if not dead[end]:
				continue
			var end_face := centre + dir * end * long * 0.5
			var style: MazeStyle = style_at.call(end_face + dir * end * 1.0)
			if style == null or inside.call(end_face + dir * end * style.mezzanine_depth * 0.5, box):
				continue
			var deep := style.mezzanine_depth
			ledges.append([end_face + dir * end * deep * 0.5, out * half * 2.0 + dir * deep + Vector3.UP * style.mezzanine_height, maze.ring_of(maze.cell_at(end_face + dir * end * 1.0))])
	# (one of each: the clearing's wall and the rampart behind it share a face)
	var once := {}
	for ledge: Array in ledges:
		once[[(ledge[0] as Vector3).snappedf(0.05), (ledge[1] as Vector3).snappedf(0.05)]] = ledge
	return once.values()


## The walls either side of each narrow entrance (MazeStyle.entrance_doorway_width), as
## [middle of the foot, size]: filling the entrance's cells but for the doorway
## down the middle, as high as the wall round the inside of the ring it leads into.
static func _gatehouses(maze: Maze) -> Array:
	var walls: Array = []
	for ring in range(1, maze.rings + 1):
		var style: MazeStyle = maze.styles[ring - 1]
		if style.entrance_doorway_width <= 0.0:
			continue
		for way: Array in maze.gates[ring - 1]:
			var step: Vector2i = way[1]
			var s := Vector3(step.x, 0.0, step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var cells := 0
			while maze.entrances.get(way[0] + step * (cells + 1), Vector2i.ZERO) == step:
				cells += 1
			if cells == 0:
				continue
			# (from the middle of the wall it goes through to the far end of the entrance)
			var start: Vector3 = maze.world(way[0]) + s * Maze.CELL * 0.5
			var middle := start + s * cells * Maze.CELL * 0.5
			var wide := (Maze.CELL - style.entrance_doorway_width) * 0.5
			var size := side.abs() * wide + s.abs() * cells * Maze.CELL + Vector3.UP * maze.inner_height(ring)
			for out in [-1.0, 1.0]:
				walls.append([middle + side * out * (style.entrance_doorway_width + wide) * 0.5, size])
	return walls


## The outside wall of the next ring, which is not built yet: unbroken for now,
## so that past the gate there is open ground to the foot of the next wall.
static func _next_ring(maze: Maze) -> Array:
	var half := Maze.ring_extent(maze.rings + 1, maze.styles, maze.clearing_style) * 0.5
	var long := half * 2.0 + MazeBuilder.RING_THICK
	var high := maze.inner_height(maze.rings + 1)
	var runs: Array = []
	for side in [-1.0, 1.0]:
		runs.append([Vector3(0.0, high * 0.5, side * half), Vector3(long, high, MazeBuilder.RING_THICK), true])
		runs.append([Vector3(side * half, high * 0.5, 0.0), Vector3(MazeBuilder.RING_THICK, high, long), true])
	return runs


## Walls thicker than this have no piers.
const MAX_PIERED := 5.0


## Square piers, standing above the walls, wherever three or four walls meet or
## one turns a corner: the great ones (`great`) where a wall between rings is
## one of them, the others elsewhere. As [middle, size]. Only those in `zones`
## (zone_at), if any are given.
static func _piers(maze: Maze, great: bool, zones: Dictionary = {}) -> Array:
	var piers: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	for j in n + 1:
		for i in n + 1:
			if not zones.is_empty() and not zones.has(zone_at(maze, Vector3((i - 0.5 - middle) * Maze.CELL, 0.0, (j - 0.5 - middle) * Maze.CELL))):
				continue
			# The four walls that meet at the corner north-west of cell (i, j).
			var walls := [_along_x(maze, i - 1, j), _along_x(maze, i, j), _along_z(maze, i, j - 1), _along_z(maze, i, j)]
			var thickest := maxf(maxf(_thick_x(maze, i - 1, j), _thick_x(maze, i, j)), maxf(_thick_z(maze, i, j - 1), _thick_z(maze, i, j)))
			var count := 0
			var any_great := false
			for wall: int in walls:
				if wall > 0:
					count += 1
				any_great = any_great or wall == 2
			var straight: bool = count == 2 and ((walls[0] > 0 and walls[1] > 0) or (walls[2] > 0 and walls[3] > 0))
			# (and none on walls too massive for one to stand out from them)
			if count < 2 or straight or any_great != great or thickest > MAX_PIERED:
				continue
			var thick := thickest + MazeBuilder.PIER.x
			# (a great one as high as the wall round the outermost ring it stands at)
			var ring := maxi(maxi(maze.ring_of(Vector2i(i - 1, j - 1)), maze.ring_of(Vector2i(i, j - 1))), maxi(maze.ring_of(Vector2i(i - 1, j)), maze.ring_of(Vector2i(i, j))))
			var high := (maze.inner_height(ring) if great else maze.maze_wall_height(ring)) + MazeBuilder.PIER.y
			piers.append([Vector3((i - 0.5 - middle) * Maze.CELL, high * 0.5, (j - 0.5 - middle) * Maze.CELL), Vector3(thick, high, thick)])
	return piers


## The wall along x on the line north of row j, over column x: 0 none, 1 a
## wall, 2 a wall between rings.
static func _along_x(maze: Maze, x: int, j: int) -> int:
	if x < 0 or x >= maze.size or j < 0 or j > maze.size:
		return 0
	var cell := Vector2i(x, j) if j < maze.size else Vector2i(x, maze.size - 1)
	var step := Vector2i(0, -1) if j < maze.size else Vector2i(0, 1)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## How thick the wall along x on the line north of row j, over column x, is (0 for none).
static func _thick_x(maze: Maze, x: int, j: int) -> float:
	if _along_x(maze, x, j) == 0:
		return 0.0
	return maze.wall_thick(Vector2i(x, j) if j < maze.size else Vector2i(x, maze.size - 1), Vector2i(0, -1) if j < maze.size else Vector2i(0, 1))


## How thick the wall along z on the line west of column i, over row y, is (0 for none).
static func _thick_z(maze: Maze, i: int, y: int) -> float:
	if _along_z(maze, i, y) == 0:
		return 0.0
	return maze.wall_thick(Vector2i(i, y) if i < maze.size else Vector2i(maze.size - 1, y), Vector2i(-1, 0) if i < maze.size else Vector2i(1, 0))


## The wall along z on the line west of column i, over row y.
static func _along_z(maze: Maze, i: int, y: int) -> int:
	if y < 0 or y >= maze.size or i < 0 or i > maze.size:
		return 0
	var cell := Vector2i(i, y) if i < maze.size else Vector2i(maze.size - 1, y)
	var step := Vector2i(-1, 0) if i < maze.size else Vector2i(1, 0)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## Stands of pines round the edge of the clearing, kept out of the way of its
## gates, and a few out on the ground past the last ring.
func _trees(maze: Maze) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze.maze_seed
	var gate: Array = maze.gates[0][0]
	var edge := maze.clearing * Maze.CELL * 0.5 - maze.wall_thick(gate[0], gate[1]) * 0.5
	var look := maze.clearing_style
	var points: Array = []
	# (a stand for each cell along a side, and as many trees out in the open, none in the glade in the middle)
	for stand in maze.clearing:
		# Somewhere along the wall, not in front of a gate (the middle of a side).
		var side := rng.randi() % 4
		var along := rng.randf_range(0.25, 0.95) * (1.0 if rng.randf() < 0.5 else -1.0) * edge
		var into := rng.randf_range(5.0, 12.0)
		var middle := _on_side(side, along, edge - into)
		for i in rng.randi_range(3, 6):
			var p := middle + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
			if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > look.treeless_radius:
				points.append(p)
	for i in maze.clearing:
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * (edge - 6.0)
		if p.length() > look.treeless_radius:
			points.append(p)
	# Dense woods round the woods entrance, right up to its door, thinning out
	# towards their edge.
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	if look.woods_density > 0.0 and not woods.is_empty():
		var gate_at: Vector2 = woods[0]
		var steps := ceili(look.woods_size / look.woods_tree_spacing)
		for a in range(-steps, steps + 1):
			for b in range(-steps, steps + 1):
				var flat := gate_at + (Vector2(a, b) + Vector2(rng.randf(), rng.randf()) * 0.8) * look.woods_tree_spacing
				var p := Vector3(flat.x, 0.0, flat.y)
				var deep := 1.0 - flat.distance_to(gate_at) / look.woods_size
				if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > look.treeless_radius \
						and rng.randf() < look.woods_density * smoothstep(0.0, 0.35, deep):
					points.append(p)
	# (nothing near the clear entrance, nor in the pond)
	points = points.filter(func(p: Vector3) -> bool: return not look.kept_clear(Vector2(p.x, p.z)))
	var built := maze.extent() * 0.5 + 6.0
	var next := Maze.ring_extent(maze.rings + 1, maze.styles, maze.clearing_style) * 0.5 - 6.0
	# (none in the desert outside, when there are round sections)
	if not maze.round_rings:
		for i in 60:
			var side := rng.randi() % 4
			points.append(_on_side(side, rng.randf_range(-next, next), rng.randf_range(built, next)))
	for p: Vector3 in points:
		# (on the hills, a little sunk so that no root stands out of a slope)
		p.y = maze.ground_height(p) - 0.15
		var big := rng.randf_range(0.8, 1.5)
		_add(MazePiece.Kind.TREE, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * big), p), {})


## A point `out` metres from the middle on one side (0 north, 1 east, 2 south,
## 3 west), `along` metres along it.
static func _on_side(side: int, along: float, out: float) -> Vector3:
	match side:
		0: return Vector3(along, 0.0, -out)
		1: return Vector3(out, 0.0, along)
		2: return Vector3(along, 0.0, out)
	return Vector3(-out, 0.0, along)


## How thick a great wall along x on the line north of row j is at the line west
## of column i (where a wall along z there would meet it), 0 for none.
static func _great_x(maze: Maze, i: int, j: int) -> float:
	var thick := 0.0
	for x in [i - 1, i]:
		if _along_x(maze, x, j) == 2:
			thick = maxf(thick, _thick_x(maze, x, j))
	return thick


## How thick a great wall along z on the line west of column i is at the line
## north of row j (where a wall along x there would meet it), 0 for none.
static func _great_z(maze: Maze, i: int, j: int) -> float:
	var thick := 0.0
	for y in [j - 1, j]:
		if _along_z(maze, i, y) == 2:
			thick = maxf(thick, _thick_z(maze, i, y))
	return thick
