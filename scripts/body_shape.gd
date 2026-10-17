class_name BodyShape
## The boy's trousers and boots reshaped, as HeadShape does his head: trousers
## that narrow from the hip to the ankle instead of going down like tubes, and
## shorter, more angular boots.
##
## A cut of trousers is one more option of the slot `body`, added beside the
## model's long trousers as `boy_body__long_<name>` (a look shows it with
## {"parts": {"body": "long_<name>"}}). The boots are part of the figure's own
## mesh (with his hands), so a shape of boot replaces that mesh: `boots(rig,
## name)`. Every shape is kept, to be looked at side by side (tools/legs_sheet.gd).

## Cuts: [name, label, {"thigh", "knee", "ankle": its width there}], or, for one
## shaped like a leg, {"profile": [[height up the leg 0..1, width], ...], and how
## much the calf swells behind, the thigh before and the knee: "calf", "thigh",
## "kneecap"}; widths as
## shares of the width as made (1 at the hip).
const CUTS := [
	["tube", "As made", {}],
	["taper", "Tapered", {"thigh": 0.92, "knee": 0.8, "ankle": 0.6}],
	["slim", "Slim", {"thigh": 0.88, "knee": 0.72, "ankle": 0.52}],
	["soft", "A little tapered", {"thigh": 0.96, "knee": 0.9, "ankle": 0.75}],
	# (after a body: full in the thigh, a knee, the calf swelling behind, a slim ankle)
	["shaped", "Shaped to the leg", {"profile": [[0.0, 0.54], [0.12, 0.6], [0.3, 0.84], [0.47, 0.74], [0.53, 0.77], [0.62, 0.82], [0.8, 0.95], [1.0, 1.0]],
		"calf": 0.22, "thigh": 0.12, "kneecap": 0.12}],
	["shaped_slim", "Shaped and slim", {"profile": [[0.0, 0.48], [0.12, 0.52], [0.3, 0.8], [0.46, 0.63], [0.53, 0.68], [0.62, 0.76], [0.8, 0.92], [1.0, 1.0]],
		"calf": 0.4, "thigh": 0.2, "kneecap": 0.18}],
]
## Boots: [name, label, {"length": how long the foot is in front of the ankle,
## "toe": how flat the top of the toe is, "square": how square its end}].
const BOOTS := [
	["round", "As made", {}],
	["angular", "Shorter and angular", {"length": 0.88, "toe": 0.6, "square": 0.5}],
	["blunt", "Short and blunt", {"length": 0.82, "toe": 0.75, "square": 0.75}],
	["trim", "A little trimmer", {"length": 0.93, "toe": 0.35, "square": 0.25}],
]

## Heights on the boy as made: the top of his thighs and where the legs end.
const HIP := 0.62
const KNEE := 0.36
const HEM := 0.07

static var _made := {}


static func cut_names() -> Array[String]:
	var all: Array[String] = []
	for cut: Array in CUTS:
		all.append(cut[0])
	return all


static func boot_names() -> Array[String]:
	var all: Array[String] = []
	for boot: Array in BOOTS:
		all.append(boot[0])
	return all


## The option of the slot `body` for long trousers of the cut `name`.
static func option(name: String) -> String:
	return "long" if name == "tube" or name == "" else "long_" + name


## Adds every cut of trousers to a figure on the boy's rig (once).
static func add_to(rig: Node) -> void:
	var found := rig.find_children("*_body__long", "MeshInstance3D", true, false)
	if found.is_empty():
		return
	var long := found[0] as MeshInstance3D
	for cut: Array in CUTS:
		var called: String = String(long.name) + "_" + cut[0]
		if cut[0] == "tube" or long.get_parent().has_node(called):
			continue
		var made := long.duplicate() as MeshInstance3D
		made.name = called
		made.mesh = _reshaped(long.mesh, "cut/" + cut[0], cut[2], _taper)
		made.visible = false
		long.get_parent().add_child(made)
		made.owner = long.owner


## Puts boots of the shape `name` on a figure on the boy's rig.
static func boots(rig: Node, name: String) -> void:
	var how: Dictionary = {}
	for boot: Array in BOOTS:
		if boot[0] == name:
			how = boot[2]
	for part: MeshInstance3D in rig.find_children("*", "MeshInstance3D", true, false):
		if "__" in String(part.name) or not _has_material(part.mesh, "boots"):
			continue
		if not part.has_meta(&"as_made"):
			part.set_meta(&"as_made", part.mesh)
		var as_made: Mesh = part.get_meta(&"as_made")
		part.mesh = as_made if how.is_empty() else _reshaped(as_made, "boots/" + name, how, _boot)


static func _has_material(mesh: Mesh, material: String) -> bool:
	for s in mesh.get_surface_count():
		var used := mesh.surface_get_material(s)
		if used and used.resource_name == material:
			return true
	return false


static func _ease(from: float, to: float, x: float) -> float:
	var t := clampf((x - from) / (to - from), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Copies a mesh, moving the points of the surfaces `reshape` cares about.
## `reshape` is given each surface's material name, its points, and `how`, and
## returns the points moved; normals are turned to match (a numerical Jacobian of
## the move would be costly here, so they are worked out again from the faces
## round each point, which suits the smooth cloth and leather).
static func _reshaped(mesh: Mesh, key: String, how: Dictionary, reshape: Callable) -> Mesh:
	var full := "%d/%s" % [mesh.get_instance_id(), key]
	if _made.has(full):
		return _made[full]
	var made := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var used := mesh.surface_get_material(s)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved: PackedVector3Array = reshape.call(used.resource_name if used else "", points, how)
		if moved != points:
			arrays[Mesh.ARRAY_VERTEX] = moved
			arrays[Mesh.ARRAY_NORMAL] = _normals(moved, arrays[Mesh.ARRAY_INDEX], arrays[Mesh.ARRAY_NORMAL], points)
			arrays[Mesh.ARRAY_TANGENT] = null
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var flags := 0
		if bones != null and points.size() > 0 and bones.size() == points.size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		made.surface_set_material(made.get_surface_count() - 1, used)
		made.surface_set_name(made.get_surface_count() - 1, mesh.surface_get_name(s))
	_made[full] = made
	return made


## Normals from the faces, kept smooth across seams: points that sat in the same
## place before the move share one normal, as they did.
static func _normals(points: PackedVector3Array, indices: Variant, old: PackedVector3Array, before: PackedVector3Array) -> PackedVector3Array:
	var sums := {}
	var count := points.size()
	var order: PackedInt32Array = indices if indices != null else PackedInt32Array(range(count))
	for t in range(0, order.size() - 2, 3):
		var a := points[order[t]]
		var b := points[order[t + 1]]
		var c := points[order[t + 2]]
		var face := (b - a).cross(c - a)
		for k in 3:
			var where := before[order[t + k]].snappedf(0.0001)
			sums[where] = sums.get(where, Vector3.ZERO) + face
	var normals := PackedVector3Array()
	normals.resize(count)
	for i in count:
		var n: Vector3 = sums.get(before[i].snappedf(0.0001), Vector3.ZERO)
		# (Godot's faces wind the other way round, so the cross product points in)
		n = -n.normalized() if n.length() > 0.0 else old[i]
		# (and if that ever disagrees with the old normal, the old one knows better which side is out)
		normals[i] = n if n.dot(old[i]) > -0.2 else old[i]
	return normals


## Trousers narrowed towards the hem, each leg round its own middle.
static func _taper(material: String, points: PackedVector3Array, how: Dictionary) -> PackedVector3Array:
	if material != "overalls" or how.is_empty():
		return points
	# Where the middle of each leg is, height by height.
	var bins := 24
	var sums := {}
	for p in points:
		if p.y < HIP and absf(p.x) > 0.005:
			var key := Vector2i(1 if p.x > 0.0 else -1, clampi(int((p.y - HEM) / (HIP - HEM) * bins), 0, bins - 1))
			var entry: Array = sums.get(key, [Vector3.ZERO, 0])
			sums[key] = [entry[0] + p, entry[1] + 1]
	var moved := points.duplicate()
	for i in points.size():
		var p := points[i]
		if p.y >= HIP:
			continue
		var key := Vector2i(1 if p.x > 0.0 else -1, clampi(int((p.y - HEM) / (HIP - HEM) * bins), 0, bins - 1))
		if not sums.has(key):
			continue
		var middle: Vector3 = sums[key][0] / float(sums[key][1])
		var width := 1.0
		var front := 1.0
		var back := 1.0
		if how.has("profile"):
			var t := clampf((p.y - HEM) / (HIP - HEM), 0.0, 1.0)
			width = _along(how["profile"], t)
			# (front and back of the leg, not its sides)
			front += how.get("thigh", 0.0) * _bump(t, 0.78, 0.16) + how.get("kneecap", 0.0) * _bump(t, 0.53, 0.05)
			back += how.get("calf", 0.0) * _bump(t, 0.31, 0.12)
		elif p.y > KNEE:
			var thigh: float = how.get("thigh", 1.0)
			width = lerpf(how["knee"], lerpf(thigh, 1.0, _ease(HIP - 0.08, HIP, p.y)), _ease(KNEE, HIP - 0.08, p.y))
		else:
			width = lerpf(how["ankle"], how["knee"], _ease(HEM, KNEE, p.y))
		var off := Vector2(p.x - middle.x, p.z - middle.z) * width
		off.y *= front if off.y > 0.0 else back
		moved[i] = Vector3(middle.x + off.x, p.y, middle.z + off.y)
	return moved


## Boots shortened in front of the ankle, the top of the toe flattened and its
## end squared off.
static func _boot(material: String, points: PackedVector3Array, how: Dictionary) -> PackedVector3Array:
	if material != "boots" or how.is_empty():
		return points
	# Each boot's heel and toe, and how high it is.
	var low := {}
	for p in points:
		var side := 1 if p.x > 0.0 else -1
		var entry: Array = low.get(side, [INF, -INF, 0.0, 0, -INF])
		entry[0] = minf(entry[0], p.z)
		entry[1] = maxf(entry[1], p.z)
		entry[2] += p.x
		entry[3] += 1
		entry[4] = maxf(entry[4], p.y)
		low[side] = entry
	var moved := points.duplicate()
	for i in points.size():
		var p := points[i]
		var entry: Array = low[1 if p.x > 0.0 else -1]
		var heel: float = entry[0]
		var tip: float = entry[1]
		var middle_x: float = entry[2] / float(entry[3])
		var ankle := heel + (tip - heel) * 0.3
		var ahead := _ease(ankle, tip, p.z)
		var q := p
		# Shorter in front of the ankle.
		if p.z > ankle:
			q.z = ankle + (p.z - ankle) * how["length"]
		# The top of the toe flattened down towards the sole.
		var sole := 0.0
		var toe_top := 0.055
		if p.y > sole + 0.02:
			q.y = lerpf(p.y, minf(p.y, toe_top), ahead * how["toe"])
		# The end squared: the sides held out towards the tip instead of rounding in.
		var across := p.x - middle_x
		q.x = middle_x + across * (1.0 + ahead * ahead * how["square"] * 0.45)
		# And the toe's end pushed flat.
		if ahead > 0.85:
			q.z = lerpf(q.z, ankle + (tip - ankle) * how["length"] * 0.97, how["square"] * (ahead - 0.85) / 0.15)
		moved[i] = q
	return moved


## A smooth curve through [x, y] points (x rising), at `x`.
static func _along(points: Array, x: float) -> float:
	for i in points.size() - 1:
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if x <= b[0]:
			return lerpf(a[1], b[1], _ease(a[0], b[0], x))
	return points.back()[1]


## A smooth swelling round `at`, `wide` either side, 1 at its height.
static func _bump(x: float, at: float, wide: float) -> float:
	var d := clampf(absf(x - at) / wide, 0.0, 1.0)
	return 1.0 - d * d * (3.0 - 2.0 * d)
