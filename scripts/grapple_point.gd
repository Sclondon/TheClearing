class_name GrapplePoint
extends Marker3D
## Somewhere a grappling hook will catch (`scripts/grapple.gd`): the end of a
## beam, the top of a post, a branch, a ring let into a wall. Put one where the
## hook is to bite, and the rope will hang from there. It is in the group
## `grapple_points`, and anything else in that group will do as well (any
## Node3D: it is where the node is that the hook goes).
##
## A level marks them in one of three ways:
##     add_child(GrapplePoint.new())            # with its position set, like any node
##     GrapplePoint.mark(beam, Vector3(2.4, 0.9, 0.0))   # on something, in its own space
##     GrapplePoint.auto(prop, "lintel")        # wherever that kind of thing would hold a hook
## A prop scene can also say for itself: every Marker3D in it whose name begins
## with "Grapple" is made one by `auto`.

## Where each kind of prop holds a hook, by its name (see `auto`): "ends" is
## both ends of the longest thing in it, "top" the top of the highest.
const HOLDS := {
	"lintel": "ends", "scaffold": "ends", "awning": "ends",
	"column": "top", "column_broken": "top", "obelisk": "top", "torch_stand": "top",
	"palm_a": "top", "palm_b": "top", "palm_c": "top", "palm_doum": "top",
	"statue_pharaoh": "top", "statue_anubis": "top",
}

## Whether an iron ring is shown there (for a bare wall or ceiling; a beam end
## or a post top needs nothing to show a hook will hold).
@export var ring := false


func _ready() -> void:
	add_to_group(&"grapple_points")
	if not ring:
		return
	# A ring hanging from a staple, of dark iron.
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.07
	hoop.outer_radius = 0.1
	hoop.rings = 12
	hoop.ring_segments = 6
	var iron := MeshInstance3D.new()
	iron.mesh = hoop
	iron.rotation.x = PI * 0.5
	iron.position.y = -0.1
	iron.material_override = Toon.surface(Color(0.16, 0.15, 0.15))
	add_child(iron)


## Marks a place on `on` (in its own space) as one a hook will catch.
static func mark(on: Node3D, at: Vector3, with_ring := false) -> GrapplePoint:
	var point := GrapplePoint.new()
	point.ring = with_ring
	point.position = at
	on.add_child(point)
	return point


## Marks wherever a prop of the kind named `what` would hold a hook: the ends of
## a lintel, the top of a column or an obelisk, the crown of a palm. They are
## found from its collision boxes, so it works on any prop made of those. And
## whatever the prop is, its own Marker3Ds named "Grapple..." are marked.
static func auto(prop: Node3D, what: String) -> void:
	for marker in prop.find_children("Grapple*", "Marker3D", true, false):
		if not marker is GrapplePoint:
			marker.add_to_group(&"grapple_points")
	var how: String = HOLDS.get(what, "")
	if how == "":
		return
	# Its solid parts, as boxes in its own space: [middle, half size].
	var longest: Array = []
	var highest: Array = []
	for child in prop.get_children():
		var solid := child as CollisionShape3D
		if solid == null or not solid.shape is BoxShape3D:
			continue
		var half: Vector3 = (solid.shape as BoxShape3D).size * 0.5 * solid.scale.abs()
		var part := [solid.position, half]
		if longest.is_empty() or maxf(half.x, half.z) > maxf(longest[1].x, longest[1].z):
			longest = part
		if highest.is_empty() or solid.position.y + half.y > highest[0].y + highest[1].y:
			highest = part
	if longest.is_empty():
		return
	if how == "ends":
		# (a little in from each end, on top, where a hook thrown over it would lodge)
		var middle: Vector3 = longest[0]
		var half: Vector3 = longest[1]
		var along := Vector3(half.x - 0.2, 0.0, 0.0) if half.x >= half.z else Vector3(0.0, 0.0, half.z - 0.2)
		for way: float in [-1.0, 1.0]:
			mark(prop, middle + Vector3.UP * half.y + along * way)
	else:
		mark(prop, highest[0] + Vector3.UP * highest[1].y)
