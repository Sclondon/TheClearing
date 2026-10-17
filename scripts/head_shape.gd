class_name HeadShape
## Heads for the boy's rig made by reshaping his own round head (the model's
## `boy_head__base`), rather than modelled: faceless heads like a mask, after the
## boy in Inside, with a jaw and a chin. Each is added to a figure beside the
## heads the model has, as `boy_head__<name>`, so that it is one more option of
## the slot `head` and CharacterRig.restyle shows it when a look says
## {"parts": {"head": "<name>"}}. Nothing else about the figure changes: the new
## head is skinned to the same bones, and the hair still sits on it.
##
## Every shape is kept, so that they can be looked at side by side
## (tools/head_sheet.gd); SHAPES says what each is. `round` is the head as made.

## [name, label, how it is made]. The numbers are shares of the head's size:
##   chin      how far the chin comes down          forward  and out in front
##   jaw       how much the jaw narrows to the chin  flat     how flat the face is, as a mask
##   cheek     how much the cheeks are drawn in      tall     how much higher the crown is
##   brow      a ridge across the top of the face
const SHAPES := [
	["round", "Round (as made)", {}],
	["mask", "Mask", {"chin": 0.16, "forward": 0.12, "jaw": 0.22, "flat": 0.22, "cheek": 0.08, "tall": 0.04, "brow": 0.0}],
	["mask_long", "Long mask", {"chin": 0.26, "forward": 0.14, "jaw": 0.3, "flat": 0.2, "cheek": 0.1, "tall": 0.08, "brow": 0.0}],
	["mask_soft", "Soft mask", {"chin": 0.09, "forward": 0.07, "jaw": 0.13, "flat": 0.14, "cheek": 0.04, "tall": 0.02, "brow": 0.0}],
	["mask_brow", "Mask with a brow", {"chin": 0.15, "forward": 0.12, "jaw": 0.2, "flat": 0.26, "cheek": 0.1, "tall": 0.03, "brow": 0.05}],
	["mask_square", "Square jaw", {"chin": 0.13, "forward": 0.1, "jaw": 0.06, "flat": 0.28, "cheek": 0.02, "tall": 0.02, "brow": 0.02}],
	["inside", "After Inside", {"chin": 0.15, "forward": 0.17, "jaw": 0.15, "flat": 0.25, "cheek": 0.11, "tall": 0.05, "brow": 0.02}],
	["inside_round", "After Inside, rounder", {"chin": 0.15, "forward": 0.15, "jaw": 0.14, "flat": 0.07, "cheek": 0.07, "tall": 0.05, "brow": 0.03}],
	["inside_full", "After Inside, full face", {"chin": 0.12, "forward": 0.13, "jaw": 0.1, "flat": 0.0, "cheek": 0.04, "tall": 0.04, "brow": 0.04}],
]

## Made heads, by name, so each is built once and shared by every figure.
static var _made := {}


## The names of every shape, `round` first.
static func names() -> Array[String]:
	var all: Array[String] = []
	for shape: Array in SHAPES:
		all.append(shape[0])
	return all


## Adds every shape to a figure on the boy's rig (once; it does nothing the
## second time). Call it once the rig is in the tree, before restyling it.
static func add_to(rig: Node) -> void:
	var found := rig.find_children("*_head__base", "MeshInstance3D", true, false)
	if found.is_empty():
		return
	var base := found[0] as MeshInstance3D
	var prefix := String(base.name).trim_suffix("base")
	for shape: Array in SHAPES:
		if shape[0] == "round" or base.get_parent().has_node(prefix + shape[0]):
			continue
		var head := base.duplicate() as MeshInstance3D
		head.name = prefix + shape[0]
		head.mesh = mesh(base.mesh, shape[0])
		head.visible = false
		base.get_parent().add_child(head)
		head.owner = base.owner


## The round head reshaped as the shape `name` says.
static func mesh(round_head: Mesh, name: String) -> Mesh:
	var key := "%d/%s" % [round_head.get_instance_id(), name]
	if _made.has(key):
		return _made[key]
	var how: Dictionary = {}
	for shape: Array in SHAPES:
		if shape[0] == name:
			how = shape[2]
	var aabb := round_head.get_aabb()
	var centre := aabb.get_center()
	var reach := aabb.size * 0.5
	var made := ArrayMesh.new()
	for s in round_head.get_surface_count():
		var arrays := round_head.surface_get_arrays(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in points.size():
			var p := points[i]
			points[i] = _shaped(p, centre, reach, how)
			if i < normals.size():
				normals[i] = _bent(normals[i], p, centre, reach, how)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		# (tangents would need working out again; the toon shading does without them)
		arrays[Mesh.ARRAY_TANGENT] = null
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var flags := 0
		if bones != null and points.size() > 0 and bones.size() == points.size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		made.surface_set_material(made.get_surface_count() - 1, round_head.surface_get_material(s))
		made.surface_set_name(made.get_surface_count() - 1, round_head.surface_get_name(s))
	_made[key] = made
	return made


static func _ease(from: float, to: float, x: float) -> float:
	var t := clampf((x - from) / (to - from), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Where a point of the round head goes. +Z is the way he faces, +Y up.
static func _shaped(p: Vector3, centre: Vector3, reach: Vector3, how: Dictionary) -> Vector3:
	if how.is_empty():
		return p
	var u := (p - centre) / reach
	# How much of the face a point is (the front of the head) and how low.
	var front := _ease(-0.15, 0.75, u.z)
	var low := _ease(0.05, -0.95, u.y)
	var out := u
	# The jaw narrows to the chin, at the front only (the neck stays as it is).
	out.x *= 1.0 - how.get("jaw", 0.0) * low * front
	# The cheeks drawn in, above the jaw.
	out.x *= 1.0 - how.get("cheek", 0.0) * front * (1.0 - low) * _ease(1.0, 0.0, absf(u.y))
	# The chin: down and out, most at the very front and bottom.
	out.y -= how.get("chin", 0.0) * low * front * front * 1.6
	out.z += how.get("forward", 0.0) * low * front
	# The face flattened like a mask: the front of the head pushed back to a
	# gently curved plane, the more so the further forward it was.
	var flat: float = how.get("flat", 0.0)
	var plane := 1.0 - flat
	if out.z > plane - 0.25:
		var over := out.z - (plane - 0.25)
		out.z = plane - 0.25 + over / (1.0 + over * flat * 6.0)
	# A ridge across the top of the face.
	out.z += how.get("brow", 0.0) * front * _ease(0.0, 0.25, u.y) * _ease(0.6, 0.3, u.y) * 2.0
	# A higher crown.
	out.y *= 1.0 + how.get("tall", 0.0) * _ease(0.0, 1.0, u.y)
	return centre + out * reach


## A normal at `p`, turned as the surface round it was by the reshaping.
static func _bent(normal: Vector3, p: Vector3, centre: Vector3, reach: Vector3, how: Dictionary) -> Vector3:
	if how.is_empty():
		return normal
	var e := 0.002
	var here := _shaped(p, centre, reach, how)
	var dx := (_shaped(p + Vector3(e, 0, 0), centre, reach, how) - here) / e
	var dy := (_shaped(p + Vector3(0, e, 0), centre, reach, how) - here) / e
	var dz := (_shaped(p + Vector3(0, 0, e), centre, reach, how) - here) / e
	var j := Basis(dx, dy, dz)
	return (j.inverse().transposed() * normal).normalized()


## The option of the slot `head` that shows the shape `name` (`round` is the
## model's own head, `base`).
static func option(name: String) -> String:
	return "base" if name == "round" or name == "" else name
