class_name HairShape
## Hair made of locks: chunky, tapering, faceted clumps laid over the scalp,
## flowing out from a whorl at the crown, the fringe falling forward over the
## brow and the tips lifting off the head, so that the outline is loose and
## ragged rather than a smooth cap. Drawn over one of the model's close cuts
## (the look's own `hair`, `crop` by default), which fills in under them.
##
## Each style is one more option of a slot of its own, `locks`, added to a figure
## as `boy_locks__<name>`: a look shows it with {"parts": {"locks": "<name>"}}.
## It is skinned to the head as the model's hair is, and coloured as hair.
## Every style is kept, to be looked at side by side (The Clearing's
## tools/hair_sheet.gd); STYLES says what each is.

## [name, label, {"count": locks, "length": metres, "width": metres, "lift": how far
## the tips stand off, "fringe": how much longer the locks over the brow are,
## "messy": how much each lock wanders from the flow, "band": how far up from the
## hairline they grow (all over, if not given), "wavy": the waved hair
## shader rather than the curly one}].
const STYLES := [
	["loose", "Loose locks", {"count": 46, "length": 0.075, "width": 0.042, "lift": 0.018, "fringe": 1.35, "messy": 0.35, "wavy": true}],
	["messy", "Messy", {"count": 56, "length": 0.085, "width": 0.04, "lift": 0.03, "fringe": 1.45, "messy": 0.7, "wavy": true}],
	["short", "Short and chunky", {"count": 40, "length": 0.055, "width": 0.046, "lift": 0.012, "fringe": 1.2, "messy": 0.3, "wavy": true}],
	["swept", "Swept to the side", {"count": 46, "length": 0.08, "width": 0.042, "lift": 0.016, "fringe": 1.5, "messy": 0.25, "wavy": true, "sweep": 0.6}],
	["curly_locks", "Locks, curled shading", {"count": 46, "length": 0.075, "width": 0.042, "lift": 0.018, "fringe": 1.35, "messy": 0.35, "wavy": false}],
	# (after Inside's boy: the close cut whole on top, and only a ring of broad, flat clumps
	# round the hairline, longest over the brow and at the temples)
	["inside", "Broad clumps at the hairline", {"count": 70, "length": 0.07, "width": 0.07, "lift": 0.003, "fringe": 1.4, "messy": 0.12, "wavy": true, "band": 0.32}],
]

## Segments along a lock.
const STEPS := 5

static var _made := {}


static func names() -> Array[String]:
	var all: Array[String] = []
	for style: Array in STYLES:
		all.append(style[0])
	return all


## Adds every style to a figure on the boy's rig (once). Call it once the rig is
## in the tree, before restyling it.
static func add_to(rig: Node) -> void:
	var heads := rig.find_children("*_head__base", "MeshInstance3D", true, false)
	var cuts := rig.find_children("*_hair__crop", "MeshInstance3D", true, false)
	var waved := rig.find_children("*_hair__quiff", "MeshInstance3D", true, false)
	if heads.is_empty() or cuts.is_empty():
		return
	var head := heads[0] as MeshInstance3D
	var cut := cuts[0] as MeshInstance3D
	var prefix := String(head.name).trim_suffix("head__base") + "locks__"
	for style: Array in STYLES:
		if cut.get_parent().has_node(prefix + style[0]):
			continue
		var how: Dictionary = style[2]
		var hair_from: MeshInstance3D = waved[0] if how.get("wavy", false) and not waved.is_empty() else cut
		var locks := cut.duplicate() as MeshInstance3D
		locks.name = prefix + style[0]
		locks.mesh = mesh(head.mesh, cut.mesh, hair_from.mesh.surface_get_material(0), style[0], how)
		locks.visible = false
		cut.get_parent().add_child(locks)
		locks.owner = cut.owner


## The locks of a style, for a head (its size and place) and a cut of hair (whose
## bone weights they take), in `material`.
static func mesh(head: Mesh, cut: Mesh, material: Material, name: String, how: Dictionary) -> Mesh:
	var key := "%d/%s" % [head.get_instance_id(), name]
	if _made.has(key):
		return _made[key]
	var aabb := head.get_aabb()
	var centre := aabb.get_center()
	var reach := aabb.size * 0.5
	# The hair's bones and weights (all the head, as it is): every lock takes those of the cut's first point.
	var arrays := cut.surface_get_arrays(0)
	var bones: Variant = arrays[Mesh.ARRAY_BONES]
	var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
	var per := 8 if bones != null and (bones as PackedInt32Array).size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8 else 4
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if per == 8:
		tool.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	var bone_set := PackedInt32Array()
	var weight_set := PackedFloat32Array()
	if bones != null:
		bone_set = (bones as PackedInt32Array).slice(0, per)
		weight_set = (weights as PackedFloat32Array).slice(0, per)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	# The whorl the hair grows from: on top, towards the back.
	var crown := Vector3(0.0, 0.85, -0.5).normalized()
	var count: int = how["count"]
	var golden := PI * (3.0 - sqrt(5.0))
	# (`count` is how many there would be over the whole head: the ones under the hairline are left out)
	for i in count * 2:
		# Roots spread evenly over the top of the head (a Fibonacci sphere), above the hairline.
		var y := 1.0 - (float(i) + 0.5) / float(count)
		var round := sqrt(maxf(1.0 - y * y, 0.0))
		var around := golden * i
		var dir := Vector3(cos(around) * round, y, sin(around) * round)
		# (the hairline: high over the brow, over the ears at the sides, down to the nape behind)
		var line := lerpf(-0.42, 0.3, smoothstep(-0.6, 0.85, dir.z))
		if dir.y < line or dir.y > line + float(how.get("band", 3.0)):
			continue
		_lock(tool, dir, crown, centre, reach, how, rng, bone_set, weight_set)
	tool.generate_normals()
	var made := tool.commit()
	made.surface_set_material(0, material)
	_made[key] = made
	return made


## One lock, rooted at `dir` on the head (a unit direction from its middle).
static func _lock(tool: SurfaceTool, dir: Vector3, crown: Vector3, centre: Vector3, reach: Vector3, how: Dictionary,
		rng: RandomNumberGenerator, bone_set: PackedInt32Array, weight_set: PackedFloat32Array) -> void:
	# It flows away from the crown, along the head, and a little at random.
	var flow := (dir - crown)
	flow = (flow - dir * flow.dot(dir))
	if flow.length() < 0.05:
		flow = Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1))
		flow = flow - dir * flow.dot(dir)
	flow = flow.normalized()
	var sweep: float = how.get("sweep", 0.0)
	if sweep != 0.0 and dir.z > 0.0:
		flow = (flow + Vector3.RIGHT * sweep * dir.z).normalized()
	flow = flow.rotated(dir, rng.randf_range(-1.0, 1.0) * float(how["messy"]) * 0.6)
	var front := smoothstep(0.3, 0.9, dir.z)
	var messy: float = how["messy"]
	var length: float = how["length"] * rng.randf_range(0.8, 1.2) * lerpf(1.0, how["fringe"], front)
	var width: float = how["width"] * rng.randf_range(0.8, 1.15)
	var lift: float = how["lift"] * rng.randf_range(0.6, 1.4) * (1.0 + messy * rng.randf())
	var bend := rng.randf_range(-0.5, 0.5) * messy
	# (on top of the head they lie down; it is towards the edges that they stand off)
	lift *= smoothstep(0.98, 0.55, dir.y)
	var radius := (reach.x + reach.z) * 0.5
	var points: Array[Vector3] = []
	var sides: Array[Vector3] = []
	var ups: Array[Vector3] = []
	for s in STEPS + 1:
		var t := float(s) / STEPS
		# Round the head along the flow, standing further off it towards the tip.
		var angle := length * t / radius
		var along := dir.rotated(dir.cross(flow).normalized(), -angle)
		# (out past the close crop under it, which stands off the head)
		var off := radius * 1.2 + lift * t * t
		var at := centre + along * reach / radius * off
		at += along.cross(flow).normalized() * bend * length * t * t
		points.append(at)
		ups.append(along)
		sides.append(along.cross(flow).normalized())
	for s in STEPS:
		var t0 := float(s) / STEPS
		var t1 := float(s + 1) / STEPS
		# A lens in section, thick in the middle, tapering to a point at the tip.
		var w0 := width * (1.0 - pow(t0, 1.8) * 0.85) * 0.5
		var w1 := width * (1.0 - pow(t1, 1.8) * 0.85) * 0.5
		var a := _section(points[s], sides[s], ups[s], w0)
		var b := _section(points[s + 1], sides[s + 1], ups[s + 1], maxf(w1, 0.0005))
		for k in 4:
			var k2 := (k + 1) % 4
			for v: Vector3 in [a[k], b[k], b[k2], a[k], b[k2], a[k2]]:
				if not bone_set.is_empty():
					tool.set_bones(bone_set)
					tool.set_weights(weight_set)
				tool.add_vertex(v)


## A diamond across a lock: `half` wide each side, a third of that thick.
static func _section(at: Vector3, side: Vector3, up: Vector3, half: float) -> Array:
	return [at + side * half, at + up * half * 0.55, at - side * half, at - up * half * 0.3]
