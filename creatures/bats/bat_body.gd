class_name BatBody
## What a bat looks like: one mesh, made here in code, and its material
## (creatures/bats/bat.gdshader). BatColony draws a whole colony with these as
## one MultiMesh, so a colony is one draw however many bats are in it.
##
## The mesh is a big dark bat with a wingspan of 1 (scale it up by the span you
## want), facing +Z, its back up (+Y), wings out along X, open, at rest:
##
## - a round furry body, darker on the rump and belly, with a lighter mantle
##   over the shoulders and chest and a ragged ruff round the neck and flanks;
## - a round head with a short snout, two small dark eyes that catch the
##   light, and two big upright ears, cupped forward, paler inside;
## - two wings that are hands. Each has a skeleton, drawn as thin dark rods
##   with knuckles: the upper arm (humerus) from the shoulder, the forearm to
##   the wrist, a clawed thumb at the wrist, and four long fingers (digits 2 to
##   5), each a metacarpal and then its phalanges. Digit 2 runs along the
##   leading edge, 3 (the longest) out to the wingtip, 4 and 5 fan back to the
##   trailing edge. Skin is stretched between them: in front of the arm (the
##   propatagium), between the fingers, from the fifth finger and the arm back
##   to the body and the hind leg (the plagiopatagium), and between the legs
##   and the tail (the uropatagium). The trailing edge is scalloped between
##   the fingertips. The skin is thin: lighter where it is thinnest, with fine
##   creases across it;
## - hind legs with little hooked toes, trailing behind, and a tail between them.
##
## Nothing in the mesh moves by itself. Every vertex of a wing or a leg says
## which bones carry it (two, and how much of each: the skin between two
## fingers is carried by both), and the shader poses the bones, from each
## bat's custom data, through the wingbeat, the glide, the hover and the fold
## (see the shader). A vertex's bones are CUSTOM1 (bone, other bone, how much
## of the other); what it is is CUSTOM0 (part, how thin or light, how far it
## billows); UV is where it lies on its panel of skin (for the creases) or,
## on an eye, how far out from its middle; UV2 is (which side, 1 if it is on
## a wing or leg).

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

## The body, tail to neck, and the head, neck to nose: (along, half width,
## half height, height of its middle).
const BODY: Array[Vector4] = [
	Vector4(-0.12, 0.006, 0.006, 0.0),
	Vector4(-0.105, 0.022, 0.02, 0.0),
	Vector4(-0.085, 0.034, 0.031, 0.0),
	Vector4(-0.055, 0.046, 0.042, 0.0),
	Vector4(-0.02, 0.054, 0.049, 0.002),
	Vector4(0.015, 0.056, 0.05, 0.005),
	Vector4(0.042, 0.048, 0.044, 0.008),
	Vector4(0.06, 0.032, 0.03, 0.01),
	Vector4(0.072, 0.024, 0.023, 0.011),
]
const HEAD: Array[Vector4] = [
	Vector4(0.06, 0.016, 0.016, 0.014),
	Vector4(0.07, 0.027, 0.026, 0.016),
	Vector4(0.082, 0.032, 0.03, 0.017),
	Vector4(0.096, 0.033, 0.03, 0.017),
	Vector4(0.11, 0.029, 0.026, 0.015),
	Vector4(0.121, 0.024, 0.021, 0.011),
	Vector4(0.133, 0.017, 0.015, 0.008),
	Vector4(0.146, 0.013, 0.011, 0.006),
	Vector4(0.156, 0.009, 0.008, 0.006),
	Vector4(0.161, 0.003, 0.003, 0.006),
]
const ROUND := 12

## Parts, as the shader tells them apart (CUSTOM0.r).
const FUR := 0.0
const SKIN := 0.25
const BONE := 0.5
const EAR := 0.75
const EYE := 1.0

static var _mesh: ArrayMesh
static var _shader: Shader


## The bat (made once, and shared).
static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _make()
	return _mesh


## A material for bats: `fur` (and `mantle`, the lighter fur of the shoulders
## and chest), `skin` (wings and the backs of the ears), `ear` (their insides),
## and eyes that catch light of `eye`.
static func material(fur := Color(0.13, 0.115, 0.11), mantle := Color(0.22, 0.185, 0.16), skin := Color(0.1, 0.086, 0.085), ear := Color(0.36, 0.26, 0.25), eye := Color(0.95, 0.88, 0.72)) -> ShaderMaterial:
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
	_loft(st, BODY, func(z: float) -> float: return _mantle(z))
	_loft(st, HEAD, func(z: float) -> float: return 0.12 + 0.4 * smoothstep(0.112, 0.13, z) - 0.3 * smoothstep(0.15, 0.158, z))
	_ruff(st)
	_rod(st, TAIL_ROOT, TAIL, 0.004, 0.0015, BODY_BONE, 0.0)
	for side: float in [-1.0, 1.0]:
		_wing(st, side)
		_ear(st, side)
		_eye(st, side)
		_flank(st, side)
	return st.commit()


# How light the fur is along the body: the mantle over the shoulders and chest.
static func _mantle(z: float) -> float:
	return smoothstep(-0.05, 0.0, z) * (1.0 - smoothstep(0.05, 0.075, z))


# One corner: where (on the right side: `side` -1 mirrors it), which way it
# faces, what it is and how light or thin, which bones carry it, where it lies
# on its panel, and how far it billows.
static func _vert(st: SurfaceTool, at: Vector3, normal: Vector3, part: float, light := 0.0, side := 0.0, bone := 0, other := 0, share := 0.0, uv := Vector2.ZERO, billow := 0.0) -> void:
	var mirror := Vector3(-1.0 if side < 0.0 else 1.0, 1.0, 1.0)
	st.set_custom(0, Color(part, light, billow, 0.0))
	st.set_custom(1, Color(bone, other, share, 0.0))
	st.set_normal((normal * mirror).normalized())
	st.set_uv(uv)
	st.set_uv2(Vector2(1.0 if side >= 0.0 else 0.0, 1.0 if bone > 0 or other > 0 else 0.0))
	st.add_vertex(at * mirror)


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
static func _loft(st: SurfaceTool, sections: Array[Vector4], light: Callable) -> void:
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for s in sections.size():
		var section := sections[s]
		var before := sections[maxi(s - 1, 0)]
		var after := sections[mini(s + 1, sections.size() - 1)]
		# (how fast it narrows here, so that the normals lean along the tube)
		var slope := ((after.y + after.z) - (before.y + before.z)) * 0.5 / maxf(after.x - before.x, 0.001)
		var ring := PackedVector3Array()
		var facing := PackedVector3Array()
		for k in ROUND:
			var a := TAU * k / ROUND
			ring.append(Vector3(cos(a) * section.y, section.w + sin(a) * section.z, section.x))
			var n := Vector3(cos(a) / maxf(section.y, 0.001), sin(a) / maxf(section.z, 0.001), 0.0).normalized()
			facing.append(Vector3(n.x, n.y, -slope).normalized())
		rings.append(ring)
		normals.append(facing)
	for r in rings.size() - 1:
		for k in ROUND:
			var j := (k + 1) % ROUND
			for corner in [[r, k], [r + 1, k], [r + 1, j], [r, k], [r + 1, j], [r, j]]:
				var at: Vector3 = rings[corner[0]][corner[1]]
				_vert(st, at, normals[corner[0]][corner[1]], FUR, light.call(at.z))


# A tuft of fur: a little ragged triangle standing out from the body at `root`,
# pointing `out` (and back), `size` long.
static func _tuft(st: SurfaceTool, root: Vector3, out: Vector3, across: Vector3, size: float, light: float) -> void:
	var tip := root + (out + Vector3(0, 0, -0.9)).normalized() * size
	for at: Vector3 in [root + across * size * 0.45, tip, root - across * size * 0.45]:
		_vert(st, at, out, FUR, light)


# The ruff: tufts all round the neck, pale like the mantle, lying back.
static func _ruff(st: SurfaceTool) -> void:
	for k in 14:
		var a := TAU * (k + 0.5) / 14.0
		var out := Vector3(cos(a), sin(a) * 0.9, 0.0)
		var root := Vector3(cos(a) * 0.036, 0.011 + sin(a) * 0.033, 0.064)
		_tuft(st, root, out, Vector3(-sin(a), cos(a), 0.0), 0.024 + 0.008 * float(k % 2), 0.95)


# Ragged fur along each flank, where the wing meets the body.
static func _flank(st: SurfaceTool, side: float) -> void:
	for k in 5:
		var z := -0.07 + k * 0.026
		var round_at := 0.45 + 0.25 * float(k % 2)
		var out := Vector3(cos(round_at) * side, sin(round_at), 0.0)
		var section := _section_at(z)
		var root := Vector3(out.x * section.y * 0.98, section.w + out.y * section.z * 0.98, z)
		_tuft(st, root, out, Vector3(0, 0, 1).cross(out).normalized(), 0.018 + 0.006 * float(k % 2), _mantle(z) * 0.7)


static func _section_at(z: float) -> Vector4:
	for s in BODY.size() - 1:
		if z <= BODY[s + 1].x:
			return BODY[s].lerp(BODY[s + 1], (z - BODY[s].x) / (BODY[s + 1].x - BODY[s].x))
	return BODY[-1]


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


# --- The head ---

# An ear: a tall cupped shell standing up from the top of the head, leaning
# out, its hollow facing forward (its normals face out of the hollow: the
# shader paints that side paler).
static func _ear(st: SurfaceTool, side: float) -> void:
	var base := Vector3(0.021, 0.044, 0.084)
	var up := Vector3(0.38, 1.0, -0.12).normalized()
	var across := (Vector3.RIGHT - up * up.x).normalized()
	var back := across.cross(up).normalized()
	if back.z > 0.0:
		back = -back
	var height := 0.072
	var rows: Array[PackedVector3Array] = []
	for r in 4:
		var t := r / 3.0
		var half := 0.019 * (1.0 - t * 0.78)
		var row := PackedVector3Array()
		for c: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			# (the middle drawn back into a hollow; the rim curled forward)
			var hollow := (1.0 - c * c) * 0.017 * (1.0 - t * 0.55)
			row.append(base + up * height * t + across * c * half + back * hollow)
		rows.append(row)
	var tip := base + up * height * 1.12 + back * 0.004
	var tris := []
	for r in 3:
		for c in 4:
			tris.append([rows[r][c], rows[r][c + 1], rows[r + 1][c + 1]])
			tris.append([rows[r][c], rows[r + 1][c + 1], rows[r + 1][c]])
	for c in 4:
		tris.append([rows[3][c], rows[3][c + 1], tip])
	for tri: Array in tris:
		var normal: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		if normal.dot(-back) < 0.0:
			normal = -normal
		var corners := tri if side > 0.0 else [tri[0], tri[2], tri[1]]
		for at: Vector3 in corners:
			_vert(st, at, normal, EAR, 0.0, side * 0.0001)


# An eye: a small dark bead on the side of the face; UV.y runs from 0 in its
# middle to 1 at its rim, for the shader's glint.
static func _eye(st: SurfaceTool, side: float) -> void:
	var out := Vector3(0.78, 0.5, 0.38).normalized()
	var middle := Vector3(0.024, 0.031, 0.114) + out * 0.002
	var across := out.cross(Vector3.UP).normalized()
	var up := across.cross(out).normalized()
	var r := 0.0065
	for k in 8:
		var a := TAU * k / 8.0
		var b := TAU * (k + 1) / 8.0
		var p := middle - out * 0.002 + (across * cos(a) + up * sin(a)) * r
		var q := middle - out * 0.002 + (across * cos(b) + up * sin(b)) * r
		var corners := [middle, p, q] if side > 0.0 else [middle, q, p]
		for at: Vector3 in corners:
			_vert(st, at, (at - (middle - out * 0.006)).normalized(), EYE, 0.0, side * 0.0001, 0, 0, 0.0, Vector2(0.0, 0.0 if at == middle else 1.0))
