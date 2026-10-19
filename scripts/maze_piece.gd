@tool
class_name MazePiece
extends Node3D
## One piece of a maze laid out by MazeLayout: a run of wall, a pier, a terrace,
## a patch of ivy, a vine, a rope bridge, a tree, a sewer pipe, a grappling hook spot or the light past the exit. In
## the editor each shows itself as it will be, and can be moved, turned, resized,
## copied or deleted by hand; in the game MazeBuilder.realize makes the real thing
## from it (the walls merged into a few meshes, the ivy an IvyClimb, and so on)
## and the piece itself draws nothing.
##
## Boxes (walls, piers, terraces) stand on their origin: it is the middle of their
## foot, `size` across, and they may be turned about Y. A wall has a footing and
## a cornice besides. Ivy faces its +Z, out from what it grows on, from its origin
## up `length` metres. A vine hangs `length` from its origin. A sewer pipe runs
## along its Z through a wall `width` thick, `length` from mouth to mouth, its origin
## the middle of its floor. A bridge runs from
## its origin to its child `End` (move that to move the far end), and so does a
## vine strung across a hall (a strand). A tree stands
## at its origin, as big as its scale. A prop (MazeProps.Prop: a vent, a culvert,
## an outlet, a drain, a manhole, a puddle, a stain, a crate, a barrel) stands at
## its origin, turned and sized by its transform; one on a wall looks out along
## its +Z. A wire (an old cable) runs from its origin to its child `End`, sagging
## `sag` metres; with `tails` it is snapped, an end that long hanging from each.
## A pond (standing water in a hall: Ponds) lies with its origin in the middle of
## its still surface, `size` across (x and z) and as deep (y) at its deepest, its
## corners as round as `length`, with `width` fish in it; it is never turned.
## A grappling hook spot (an anchor: an iron ring,
## hook or pipe, GrappleSpots) is where the hook bites, its +Z out of the
## wall it is on.

enum Kind { WALL, PIER, TERRACE, IVY, VINE, BRIDGE, TREE, BEACON, STRAND, PIPE, PROP, WIRE, POND, ANCHOR }

@export var kind := Kind.WALL:
	set(value):
		kind = value
		_refresh()
## A box's width (x), height and depth (z), in metres.
@export var size := Vector3(14.0, 34.0, 3.2):
	set(value):
		size = value
		_refresh()
## How a wall is built (Wall.Style: Basic, a plain box, or decorated).
@export var style := Wall.Style.BASIC:
	set(value):
		style = value
		_refresh()
## A wall between rings (only a note: thicker and higher walls are just bigger boxes).
@export var great := false
## A ledge along a wall (MazeStyle.mezzanine_height): a step of it, standing from
## the ground or the level under it (only a note: the plan of the maze ignores it).
@export var ledge := false
## How tall a patch of ivy is, how long a vine, or a pipe from mouth to mouth
## (for a pond, how round its corners are).
@export var length := 6.5:
	set(value):
		length = value
		_refresh()
## How wide a patch of ivy is (for a pond, how many fish swim in it).
@export var width := 1.8:
	set(value):
		width = value
		_refresh()
## Which prop it is (MazeProps.Prop), and (an outlet) whether it drips.
@export var prop := 0:
	set(value):
		prop = value
		_refresh()
@export var drips := false
## Which way from a vine's top what holds it is (a wall, a ledge's edge, a bridge; 0: over it), for its roots.
@export var hold := Vector3.ZERO
## How a vine is held at its top, or a strung vine at its start (Vine.Held; -1: as `hold`
## says, as layouts before were: over a lip if it has a way, else under what is over it),
## how far its top is from what holds it, metres, and how a strung vine is held at its end.
@export var held := -1
@export var reach := 0.0
@export var held_end := -1
## How far a wire sags in the middle, metres; how long the ends hanging from it
## are if it is snapped (from its origin, and from its End: 0 for none), and
## whether an old lamp hangs from its lowest point.
@export var sag := 1.5:
	set(value):
		sag = value
		_refresh()
@export var tails := Vector2.ZERO:
	set(value):
		tails = value
		_refresh()
@export var lamp := false:
	set(value):
		lamp = value
		_refresh()
## What a grappling hook spot is (GrappleSpots.Look: a ring, a hook or a pipe).
@export_enum("Ring", "Hook", "Pipe") var anchor := 0:
	set(value):
		anchor = value
		_refresh()

var _shown: Node3D
var _drawn_end := Vector3.INF


func _ready() -> void:
	# (in the game the piece is only read by MazeBuilder: it does nothing itself)
	set_process(false)
	if not Engine.is_editor_hint():
		return
	set_notify_transform(true)
	_refresh()


## Whether this is a box of stone (a wall, a pier or a terrace).
func is_box() -> bool:
	return kind in [Kind.WALL, Kind.PIER, Kind.TERRACE]


## The box's own size, with any scaling done to the node by hand taken into it.
func box_size() -> Vector3:
	return size * scale.abs()


## Where the box is, as a transform without scale (its origin the middle of its foot).
func box_transform() -> Transform3D:
	return Transform3D(transform.basis.orthonormalized(), transform.origin)


## Whether a point (in the space of this piece's parent) is inside the box.
func box_has(point: Vector3, margin := 0.0) -> bool:
	if not is_box():
		return false
	var local := box_transform().affine_inverse() * point
	var half := box_size() * 0.5
	return absf(local.x) <= half.x + margin and absf(local.z) <= half.z + margin and local.y >= -margin and local.y <= box_size().y + margin


## The far end of a bridge, in the space of this piece's parent.
func bridge_end() -> Vector3:
	var end := get_node_or_null(^"End") as Node3D
	return transform * (end.position if end else Vector3(6.0, 0.0, 0.0))


func _process(_delta: float) -> void:
	# (in the editor, a bridge redraws when its far end is moved)
	if Engine.is_editor_hint() and kind in [Kind.BRIDGE, Kind.STRAND, Kind.WIRE] and _shown and bridge_end() != _drawn_end:
		_refresh()


## Shows the piece in the editor. (In the game, MazeBuilder makes the real thing.)
func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _shown:
		_shown.queue_free()
		_shown = null
	set_process(kind in [Kind.BRIDGE, Kind.STRAND, Kind.WIRE])
	match kind:
		Kind.WALL, Kind.PIER, Kind.TERRACE:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var s := box_size()
			for part: Array in Wall.style_boxes(style if kind == Kind.WALL else Wall.Style.BASIC, s):
				MazeBuilder.box(tool, part[0], part[1])
			var mesh := MeshInstance3D.new()
			mesh.mesh = tool.commit()
			mesh.material_override = Wall.material_for(MazeBuilder.surface_of(self), true)
			# (drawn at the box's own size: undo the node's scale, which is in `size` already)
			mesh.scale = Vector3.ONE / scale.abs().max(Vector3.ONE * 0.001)
			_shown = mesh
		Kind.IVY:
			var ivy := IvyClimb.new()
			ivy.height = length
			ivy.width = width
			_shown = ivy
		Kind.VINE:
			var vine := Vine.new()
			vine.length = length
			vine.hold = hold
			vine.held = vine_held()
			vine.reach = reach
			_shown = vine
		Kind.BRIDGE:
			if not has_node(^"End"):
				return
			var bridge := RopeBridge.new()
			bridge.from = global_position
			bridge.to = get_parent().to_global(bridge_end()) if get_parent() is Node3D else bridge_end()
			_drawn_end = bridge_end()
			_shown = bridge
		Kind.STRAND:
			if not has_node(^"End"):
				return
			var strand := VineStrand.new()
			strand.from = global_position
			strand.to = get_parent().to_global(bridge_end()) if get_parent() is Node3D else bridge_end()
			strand.from_held = strand_held(false)
			strand.to_held = strand_held(true)
			_drawn_end = bridge_end()
			_shown = strand
		Kind.TREE:
			var pine := PineTree.new()
			pine.height = 13.0
			pine.seed = absi(hash(global_position.snappedf(0.1))) % 1000
			_shown = pine.instance(0)
		Kind.BEACON:
			_shown = MazeBuilder.beacon_light()
		Kind.PIPE:
			var pipe := SewerPipe.new()
			pipe.length = length
			pipe.wall = width
			_shown = pipe
		Kind.PROP, Kind.WIRE:
			# (drawn as the game draws it, in the piece's own space)
			if kind == Kind.WIRE and not has_node(^"End"):
				return
			_drawn_end = bridge_end()
			_shown = MazeProps.shown(self)
		Kind.POND:
			_shown = Ponds.sheet(size)
		Kind.ANCHOR:
			var spot := MeshInstance3D.new()
			spot.mesh = GrappleSpots.mesh_of(anchor)
			spot.material_override = GrappleSpots.material()
			# (as big as it is: undo the node's scale)
			spot.scale = Vector3.ONE / scale.abs().max(Vector3.ONE * 0.001)
			_shown = spot
	if _shown:
		# (shown, but not part of the scene: it is made again whenever it is opened)
		add_child(_shown, false, Node.INTERNAL_MODE_BACK)


func _notification(what: int) -> void:
	# (a vine's rope and a bridge's planks are laid where they hang in the world: moved, they are laid again)
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and kind in [Kind.VINE, Kind.BRIDGE, Kind.STRAND, Kind.WIRE]:
		_refresh()


## How the vine of this piece is held at its top (Vine.Held: see `held`).
func vine_held() -> int:
	if held >= 0:
		return held
	return Vine.Held.LIP if hold.length_squared() > 0.0001 else Vine.Held.OVER


## How the strung vine of this piece is held at its start, or (`at_end`) its end (Vine.Held).
func strand_held(at_end: bool) -> int:
	var how := held_end if at_end else held
	return how if how >= 0 else Vine.Held.LIP
