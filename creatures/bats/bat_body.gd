class_name BatBody
## What a bat looks like: one mesh and its material (creatures/bats/bat.gdshader).
## BatColony draws a whole colony with these as one MultiMesh, so a colony is
## one draw however many bats are in it.
##
## The mesh is a big dark bat with a wingspan of 1 (scale it up by the span you
## want), facing +Z, its back up (+Y), wings out along X, open, at rest:
##
## - the body and head, modelled in Blender (creatures/bats/tools/build_bat.py,
##   models/bat_body.glb, about a thousand triangles) and merged in here: a
##   compact furry torso with humped shoulders, darker on the rump and belly,
##   a lighter mantle over the shoulders and chest; a short neck; a head with
##   a short fox-like snout, a wet nose with a nose leaf and nostrils, a lower
##   jaw that opens on small sharp teeth, small bead eyes, and big curved ears,
##   cupped forward with ridges inside and a tragus; a ragged fringe of tufts
##   on the ruff, the shoulders, the flanks and the belly;
## - two wings that are hands, made here. Each has a skeleton, drawn as thin
##   dark rods with knuckles: the upper arm (humerus) from the shoulder, the
##   forearm to the wrist, a clawed thumb at the wrist, and four long fingers
##   (digits 2 to 5), each a metacarpal and then its phalanges. Digit 2 runs
##   along the leading edge, 3 (the longest) out to the wingtip, 4 and 5 fan
##   back to the trailing edge. Skin is stretched between them: in front of
##   the arm (the propatagium), between the fingers, from the fifth finger and
##   the arm back to the body and the hind leg (the plagiopatagium), and
##   between the legs and the tail (the uropatagium). The trailing edge is
##   scalloped between the fingertips. The skin is thin: lighter where it is
##   thinnest, with fine creases across it;
## - hind legs with little hooked toes, trailing behind, and a tail between them.
##
## Nothing in the mesh moves by itself. Every vertex of a wing or a leg says
## which bones carry it (two, and how much of each: the skin between two
## fingers is carried by both), and the shader poses the bones, from each
## bat's custom data, through the wingbeat, the glide, the hover and the fold
## (see the shader). A vertex's bones are CUSTOM1 (bone, other bone, how much
## of the other); what it is is CUSTOM0 (part, how thin or light, how far it
## billows, 1 if it is on the lower jaw); UV is where it lies on its panel of
## skin (for the creases); UV2 is (which side, 1 if it is on a wing or leg).

## The bones, as the shader numbers them. A finger `k` (0 for digit 2 ... 3
## for digit 5) is its metacarpal DIGIT + 2k and its phalanges DIGIT + 2k + 1.
const BODY_BONE := 0
const HUMERUS := 1
const FOREARM := 2
const HAND := 3
const THUMB := 4
const DIGIT := 5
const LEG := 13

## The joints at rest, on the right (+X) wing, wingspan 1. Keep these and the
## shader's in step.
const SHOULDER := Vector3(0.035, 0.012, 0.045)
const ELBOW := Vector3(0.115, 0.012, 0.012)
const WRIST := Vector3(0.245, 0.014, 0.062)
## Each finger's knuckle (the end of its metacarpal) and its tip: digits 2 to 5.
const KNUCKLES: Array[Vector3] = [Vector3(0.335, 0.014, 0.07), Vector3(0.355, 0.013, 0.046), Vector3(0.335, 0.012, 0.0), Vector3(0.298, 0.012, -0.017)]
const TIPS: Array[Vector3] = [Vector3(0.402, 0.012, 0.054), Vector3(0.5, 0.008, -0.02), Vector3(0.405, 0.004, -0.135), Vector3(0.292, 0.0, -0.182)]
const THUMB_KNUCKLE := Vector3(0.24, 0.02, 0.083)
const THUMB_TIP := Vector3(0.233, 0.013, 0.096)
const HIP := Vector3(0.03, -0.004, -0.075)
const ANKLE := Vector3(0.062, -0.006, -0.135)
const TAIL_ROOT := Vector3(0.0, -0.004, -0.105)
const TAIL := Vector3(0.0, -0.006, -0.178)
## How deep the scallops of the trailing edge are, as a share of the way back
## to the wrist (or the shoulder).
const SCALLOP := 0.24

## The body and head, modelled in Blender (creatures/bats/tools/build_bat.py).
const MODEL := "res://creatures/bats/models/bat_body.glb"

## Parts, as the shader tells them apart (CUSTOM0.r).
const FUR := 0.0
const TEETH := 0.125
const SKIN := 0.25
const MOUTH := 0.375
const BONE := 0.5
const NOSE := 0.625
const EAR := 0.75
const EYE := 1.0
## What each of the model's materials is: part, how light (the fur's own
## lightness is worked out from where it is, see _mantle), and whether it is
## on the lower jaw (which the shader opens).
const MODEL_PARTS := {
	"fur": [FUR, -1.0, false], "tuft": [FUR, -1.0, false], "jaw": [FUR, 0.15, true],
	"ear": [EAR, 0.0, false], "ear_inner": [EAR, 1.0, false], "eye": [EYE, 0.0, false],
	"teeth": [TEETH, 0.0, false], "jaw_teeth": [TEETH, 0.0, true],
	"mouth": [MOUTH, 0.0, false], "tongue": [MOUTH, 1.0, true], "nose": [NOSE, 0.0, false],
}

static var _mesh: ArrayMesh
static var _shader: Shader


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _make()
	return _mesh


## A material for bats: `fur` (and `mantle`, the lighter fur of the shoulders
## and chest), `skin` (wings and the backs of the ears), `ear` (their insides),
## and eyes that catch light of `eye`.
static func material(fur := Color(0.13, 0.115, 0.11), mantle := Color(0.22, 0.185, 0.16), skin := Color(0.1, 0.086, 0.085), ear := Color(0.27, 0.2, 0.19), eye := Color(0.95, 0.88, 0.72)) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://creatures/bats/bat.gdshader")
	var made := ShaderMaterial.new()
	made.shader = _shader
	made.set_shader_parameter(&"fur", fur)
	made.set_shader_parameter(&"mantle", mantle)
	made.set_shader_parameter(&"skin", skin)
	made.set_shader_parameter(&"ear", ear)
	made.set_shader_parameter(&"bone", fur.darkened(0.45))
	made.set_shader_parameter(&"eye", eye)
	return made




static func _make() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (what each vertex is, and its bones, go in CUSTOM0 and CUSTOM1 as floats:
	# COLOR is taken as sRGB and turned linear on its way to the shader, which
	# scrambles codes kept in it)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_model(st)
	_rod(st, TAIL_ROOT, TAIL, 0.004, 0.0015, BODY_BONE, 0.0)
	for side: float in [-1.0, 1.0]:
		_wing(st, side)
	return st.commit()


# How light the fur is where it is: the mantle over the shoulders and chest
# and round the neck, darker on the rump, the belly and the crown, and a paler
# muzzle.
static func _mantle(at: Vector3) -> float:
	var mantle := smoothstep(-0.05, 0.0, at.z) * (1.0 - smoothstep(0.055, 0.075, at.z))
	var muzzle := smoothstep(0.112, 0.13, at.z) * 0.4
	return clampf(maxf(mantle * (0.75 + 0.25 * smoothstep(-0.03, 0.02, at.y)), muzzle), 0.0, 1.0)


# One corner: where (on the right side: `side` -1 mirrors it), which way it
# faces, what it is and how light or thin, which bones carry it, where it lies
# on its panel, how far it billows, and whether it is on the lower jaw.
static func _vert(st: SurfaceTool, at: Vector3, normal: Vector3, part: float, light := 0.0, side := 0.0, bone := 0, other := 0, share := 0.0, uv := Vector2.ZERO, billow := 0.0, jaw := false) -> void:
	var mirror := Vector3(-1.0 if side < 0.0 else 1.0, 1.0, 1.0)
	st.set_custom(0, Color(part, light, billow, 1.0 if jaw else 0.0))
	st.set_custom(1, Color(bone, other, share, 0.0))
	st.set_normal((normal * mirror).normalized())
	st.set_uv(uv)
	st.set_uv2(Vector2(1.0 if side >= 0.0 else 0.0, 1.0 if bone > 0 or other > 0 else 0.0))
	st.add_vertex(at * mirror)


# The body and head, from the model: every triangle of it, each vertex marked
# with what its material says it is. They are carried by no bone (the shader
# pitches the body, bows the head and opens the jaw itself).
static func _model(st: SurfaceTool) -> void:
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_error("BatBody: no model at %s (build it with creatures/bats/tools/build_bat.py)" % MODEL)
		return
	var root := scene.instantiate()
	for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		# (where it is in the model: its own transform and its parents')
		var place := Transform3D.IDENTITY
		var node: Node = piece
		while node != root and node != null:
			if node is Node3D:
				place = (node as Node3D).transform * place
			node = node.get_parent()
		var mesh := piece.mesh
		for surface in mesh.get_surface_count():
			var named := mesh.surface_get_material(surface).resource_name if mesh.surface_get_material(surface) else "fur"
			var what: Array = MODEL_PARTS.get(named, MODEL_PARTS["fur"])
			var arrays := mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if order.is_empty():
				order.resize(points.size())
				for i in points.size():
					order[i] = i
			for i in order:
				var at := place * points[i]
				var normal := (place.basis * normals[i]).normalized()
				var light: float = what[1] if what[1] >= 0.0 else _mantle(at) * (1.15 if named == "tuft" else 1.0)
				_vert(st, at, normal, what[0], light, 0.0, 0, 0, 0.0, Vector2.ZERO, 0.0, what[2])
	root.free()


# A triangle, wound so that its front faces `out` (and mirrored with it).
static func _tri(st: SurfaceTool, corners: Array, out: Vector3, part: float, light: float, side: float, bone: int) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var normal := (b - a).cross(c - a)
	if normal.dot(out) < 0.0:
		var swap := b
		b = c
		c = swap
	if side < 0.0:
		var swap := b
		b = c
		c = swap
	for at: Vector3 in [a, b, c]:
		_vert(st, at, out, part, light, side, bone, bone)


# A round tube through `sections` (along, half width, half height, height of
# its middle), smooth-shaded, lit along it by `light`(along).
# --- The wing ---

# A wing (and its leg): the bones, then the skin between them.
static func _wing(st: SurfaceTool, side: float) -> void:
	# The bones, as rods, thick at the body and fine at the tips, with knuckles.
	_rod(st, SHOULDER, ELBOW, 0.0058, 0.0048, HUMERUS, side)
	_rod(st, ELBOW, WRIST, 0.005, 0.0038, FOREARM, side)
	_knuckle(st, ELBOW, 0.0068, FOREARM, side)
	_knuckle(st, WRIST, 0.0062, HAND, side)
	_rod(st, WRIST, THUMB_KNUCKLE, 0.0034, 0.0026, THUMB, side)
	_knuckle(st, THUMB_KNUCKLE, 0.003, THUMB, side)
	_rod(st, THUMB_KNUCKLE, THUMB_TIP, 0.0026, 0.0, THUMB, side)
	for k in 4:
		var thick := 0.0036 - k * 0.0003
		_rod(st, WRIST, KNUCKLES[k], thick, thick * 0.8, DIGIT + 2 * k, side)
		_knuckle(st, KNUCKLES[k], thick * 1.25, DIGIT + 2 * k + 1, side)
		_rod(st, KNUCKLES[k], TIPS[k], thick * 0.8, 0.0008, DIGIT + 2 * k + 1, side)
	_rod(st, HIP, ANKLE, 0.0048, 0.0034, LEG, side)
	_knuckle(st, ANKLE, 0.0045, LEG, side)
	for t in 3:
		var root := ANKLE + Vector3((t - 1) * 0.004, 0.0, -0.004)
		var toe := root + Vector3((t - 1) * 0.004, 0.003, -0.013)
		_rod(st, root, toe, 0.0018, 0.0012, LEG, side)
		_rod(st, toe, toe + Vector3(0.0, -0.007, 0.003), 0.0012, 0.0, LEG, side)

	# The skin. Each panel is a sheet between two lines of bone, carried by
	# both; `free` says which end of it is the free, scalloped edge.
	var fingers: Array = []
	for k in 4:
		fingers.append([[WRIST, KNUCKLES[k], TIPS[k]], [DIGIT + 2 * k, DIGIT + 2 * k + 1]])
	# (the skin between the second and third fingers reaches only part way along the third)
	var third_short := [[WRIST, KNUCKLES[1], KNUCKLES[1].lerp(TIPS[1], 0.55)], [DIGIT + 2, DIGIT + 3]]
	_panel(st, fingers[0], third_short, 6, 3, 1.0, 0.1, side)
	_panel(st, fingers[1], fingers[2], 9, 5, 1.0, SCALLOP, side)
	_panel(st, fingers[2], fingers[3], 9, 4, 1.0, SCALLOP, side)
	# The plagiopatagium: from the fifth finger, the wrist, the forearm and the
	# upper arm, back to the body's flank and the leg. Its free edge runs from
	# the fifth fingertip to the ankle.
	var arm := [[TIPS[3], KNUCKLES[3], WRIST, ELBOW, SHOULDER], [DIGIT + 7, DIGIT + 6, FOREARM, HUMERUS]]
	var flank := [[ANKLE, HIP, Vector3(0.042, 0.004, -0.02), Vector3(0.042, 0.008, 0.03)], [LEG, BODY_BONE, BODY_BONE]]
	_panel(st, arm, flank, 11, 6, 0.0, 0.2, side)
	# The propatagium, in front of the arm from the shoulder to the wrist.
	var front_edge := [[SHOULDER + Vector3(0.0, 0.0, 0.006), (SHOULDER + WRIST) * 0.5 + Vector3(0.0, 0.002, 0.034), WRIST + Vector3(-0.004, 0.0, 0.012)], [HUMERUS, FOREARM]]
	_panel(st, [[SHOULDER, ELBOW, WRIST], [HUMERUS, FOREARM]], front_edge, 6, 2, -1.0, 0.0, side)
	# The uropatagium: from the leg to the tail, its free edge from the ankle to the tail's tip.
	_panel(st, [[HIP, ANKLE], [LEG]], [[TAIL_ROOT, TAIL], [BODY_BONE]], 4, 3, 1.0, 0.18, side)


# A point `u` (0..1) of the way along a line of bones, by length: where, and
# which bone carries it.
static func _along(line: Array, u: float) -> Array:
	var points: Array = line[0]
	var bones: Array = line[1]
	var lengths: Array[float] = []
	var total := 0.0
	for i in points.size() - 1:
		var length: float = (points[i + 1] - points[i]).length()
		lengths.append(length)
		total += length
	var want := clampf(u, 0.0, 1.0) * total
	for i in lengths.size():
		if want <= lengths[i] or i == lengths.size() - 1:
			var t := clampf(want / maxf(lengths[i], 0.0001), 0.0, 1.0)
			return [(points[i] as Vector3).lerp(points[i + 1], t), bones[i]]
		want -= lengths[i]
	return [points.back(), bones.back()]


# A sheet of skin between two lines of bone `a` and `b`, `across` steps along
# them and `between` steps from one to the other. `free` is the end (1, 0) of
# the lines where its edge is free, scalloped `scallop` deep in the middle
# between them (-1: no free end). Each vertex is carried by the bones of the
# two points it lies between, as much by each as it is near it.
static func _panel(st: SurfaceTool, a: Array, b: Array, across: int, between: int, free: float, scallop: float, side: float) -> void:
	var grid: Array = []
	for i in across + 1:
		var row: Array = []
		for j in between + 1:
			var u := float(i) / across
			var v := float(j) / between
			# (towards the free edge, the middle of the sheet is drawn in: the scallop)
			var bulge := sin(PI * v) * scallop
			var w := u * (1.0 - bulge) if free > 0.5 else (1.0 - (1.0 - u) * (1.0 - bulge) if free > -0.5 else u)
			var from: Array = _along(a, w)
			var to: Array = _along(b, w)
			var at := (from[0] as Vector3).lerp(to[0], v)
			# How thin the skin is (most at the free edge), and how far it billows (most in the middle).
			var thin := w if free > 0.5 else (1.0 - w if free > -0.5 else 0.6 * v)
			row.append([at, from[1], to[1], v, Vector2(w, v), thin, sin(PI * v) * sin(PI * clampf(w, 0.0, 1.0))])
		grid.append(row)
	for i in across:
		for j in between:
			var quad: Array = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			for corners: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				if side < 0.0:
					corners = [corners[0], corners[2], corners[1]]
				for c: Array in corners:
					_vert(st, c[0], Vector3.UP, SKIN, c[5], side, c[1], c[2], c[3], c[4], c[6])


# A bone: a thin tapering rod from `from` to `to`, four-sided, carried by `bone`.
static func _rod(st: SurfaceTool, from: Vector3, to: Vector3, thick: float, thin: float, bone: int, side: float) -> void:
	var along := (to - from).normalized()
	var one := along.cross(Vector3.UP)
	if one.length() < 0.1:
		one = along.cross(Vector3.RIGHT)
	one = one.normalized()
	var two := along.cross(one).normalized()
	var round_it := [one, two, -one, -two]
	for k in 4:
		var p: Vector3 = round_it[k]
		var q: Vector3 = round_it[(k + 1) % 4]
		var out := (p + q).normalized()
		_tri(st, [from + p * thick, to + p * thin, to + q * thin], out, BONE, 0.0, side, bone)
		_tri(st, [from + p * thick, to + q * thin, from + q * thick], out, BONE, 0.0, side, bone)


# A knuckle: a little eight-sided bead at a joint, carried by `bone`.
static func _knuckle(st: SurfaceTool, at: Vector3, size: float, bone: int, side: float) -> void:
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corners := [at + axes[0] * sx * size, at + axes[1] * sy * size, at + axes[2] * sz * size]
				_tri(st, corners, Vector3(sx, sy, sz), BONE, 0.0, side, bone)


