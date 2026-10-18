class_name BatBody
## What a bat looks like: one low mesh, made here in code, and its material
## (creatures/bats/bat.gdshader). BatColony draws a whole colony with these as
## one MultiMesh, so a colony is one draw however many bats are in it.
##
## The mesh is a big dark bat with a wingspan of 1 (scale it up by the span you
## want), facing +Z, its back up (+Y), wings out along X, open flat:
##
## - a round body, darker on the rump and belly, with a lighter mantle of fur
##   over the shoulders and chest and a ragged ruff of tufts round the neck and
##   along its flanks;
## - a round head on the neck with a short snout, two small dark eyes that
##   catch the light, and two big upright ears, cupped forward, paler inside;
## - wings of thin dark skin on long fingers whose bones show as dark lines,
##   scalloped between the fingertips, thinner (and so brighter against the
##   light) towards their trailing edge, a small hooked thumb at each wrist;
## - hind legs trailing behind, with the skin of the tail between them.
##
## Nothing in the mesh moves: the shader beats, bends and folds the wings, and
## bows the head when the bat hangs, from each bat's custom data (see the
## shader's comment); everything else is the bat's transform.
##
## What each vertex is, for the shader: CUSTOM0.r its part (FUR, SKIN, EAR, EYE),
## CUSTOM0.g how light it is (fur: the mantle; skin: how thin, towards the edge;
## ear: unused), UV.y near 0 along a bone line (where UV.x is 1) or, on an eye,
## out from its middle; UV2.y 1 on a wing (UV2.x 0 left, 1 right).

## Where the wing's joints are, as modelled (x out, z along the body; y up).
## The shader hinges the wing at SHOULDER and WRIST: keep them in step with it.
const SHOULDER := Vector2(0.035, 0.045)
const WRIST := Vector2(0.22, 0.075)
const TIP := Vector2(0.5, -0.03)
## The ends of the three fingers that spread the back of the wing, and where the
## wing's skin meets the leg at the ankle.
const FINGERS: Array[Vector2] = [Vector2(0.42, -0.17), Vector2(0.3, -0.215), Vector2(0.175, -0.185)]
const ANKLE := Vector2(0.042, -0.13)
## How far each scallop of the trailing edge is drawn in towards the wrist.
const SCALLOP := 0.3
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
const SKIN := 0.33
const EAR := 0.66
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
	# (what each vertex is goes in CUSTOM0, as floats: COLOR is taken as sRGB
	# and turned linear on the way to the shader, which scrambles codes kept in it)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_loft(st, BODY, func(z: float, _k: int) -> float: return _mantle(z))
	_loft(st, HEAD, func(z: float, _k: int) -> float: return 0.12 + 0.4 * smoothstep(0.112, 0.13, z) - 0.3 * smoothstep(0.15, 0.158, z))
	_ruff(st)
	_tail(st)
	for side in [-1.0, 1.0]:
		_wing(st, side)
		_thumb(st, side)
		_ear(st, side)
		_eye(st, side)
		_leg(st, side)
		_flank(st, side)
	return st.commit()


# How light the fur is along the body: the mantle over the shoulders and chest.
static func _mantle(z: float) -> float:
	return smoothstep(-0.05, 0.0, z) * (1.0 - smoothstep(0.05, 0.075, z))


# One corner: where, which way it faces, what part, how light; and for a wing,
# where the bones run (`line` 0 on a bone, with `boned` 1) and which wing (`side`).
static func _vert(st: SurfaceTool, at: Vector3, normal: Vector3, part: float, light := 0.0, side := 0.0, line := 1.0, boned := 0.0) -> void:
	st.set_custom(0, Color(part, light, 0.0, 0.0))
	st.set_normal(normal.normalized())
	st.set_uv(Vector2(boned, line))
	st.set_uv2(Vector2(1.0 if side > 0.0 else 0.0, 1.0 if side != 0.0 else 0.0))
	st.add_vertex(at)


# A round tube through `sections` (along, half width, half height, height of
# its middle), smooth-shaded, lit along it by `light`(along, k).
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
				_vert(st, at, normals[corner[0]][corner[1]], FUR, light.call(at.z, corner[1]))


# A tuft of fur: a little ragged triangle standing out from the body at `root`,
# pointing `out` (and back), `size` long.
static func _tuft(st: SurfaceTool, root: Vector3, out: Vector3, across: Vector3, size: float, light: float) -> void:
	var tip := root + (out + Vector3(0, 0, -0.9)).normalized() * size
	var a := root + across * size * 0.45
	var b := root - across * size * 0.45
	for at: Vector3 in [a, tip, b]:
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


static func _wing_point(at: Vector2, side: float) -> Vector3:
	# (bowed a little, so that it is not a flat board, and sagging to the back)
	var bow := 0.014 * sin(PI * clampf(at.x / TIP.x, 0.0, 1.0)) - 0.012 * maxf(-at.y, 0.0)
	return Vector3(at.x * side, bow, at.y)


static func _wing(st: SurfaceTool, side: float) -> void:
	var tips: Array[Vector2] = [TIP]
	tips.append_array(FINGERS)
	tips.append(ANKLE)
	var scallops: Array[Vector2] = []
	for i in tips.size() - 1:
		scallops.append(((tips[i] + tips[i + 1]) * 0.5).lerp(WRIST, SCALLOP))
	var inner := Vector2(0.12, -0.03)
	var front := WRIST + Vector2(-0.07, 0.035)
	# How thin the skin is at each point (the shader lets more light through
	# where it is thin): thinnest at the trailing edge, thickest at the arm.
	var thin := {WRIST: 0.0, SHOULDER: 0.0, inner: 0.35, ANKLE: 0.5, front: 0.7, TIP: 0.6}
	for point in FINGERS:
		thin[point] = 0.85
	for point in scallops:
		thin[point] = 1.0
	# Each finger: from the wrist out to its tip, the skin either side of it.
	var triangles := []
	for i in FINGERS.size() + 1:
		var tip: Vector2 = tips[i]
		if i > 0:
			triangles.append([[WRIST, 0.0], [scallops[i - 1], 1.0], [tip, 0.0], true])
		triangles.append([[WRIST, 0.0], [tip, 0.0], [scallops[i], 1.0], true])
	# The skin between the arm, the body and the leg.
	triangles.append([[WRIST, 1.0], [scallops[-1], 1.0], [inner, 1.0], false])
	triangles.append([[inner, 1.0], [scallops[-1], 1.0], [ANKLE, 1.0], false])
	triangles.append([[WRIST, 0.0], [inner, 1.0], [SHOULDER, 0.0], true])
	triangles.append([[inner, 1.0], [ANKLE, 1.0], [SHOULDER, 1.0], false])
	# (and a little skin in front of the arm, from the shoulder to the wrist)
	triangles.append([[SHOULDER, 0.0], [front, 1.0], [WRIST, 0.0], true])
	for tri: Array in triangles:
		var corners := [tri[0], tri[1], tri[2]]
		if side < 0.0:
			corners.reverse()
		for corner: Array in corners:
			_vert(st, _wing_point(corner[0], side), Vector3.UP, SKIN, thin.get(corner[0], 0.5), side, corner[1], 1.0 if tri[3] else 0.0)


# The thumb: a little hooked claw at the wrist, on the leading edge, pointing forward.
static func _thumb(st: SurfaceTool, side: float) -> void:
	var root := _wing_point(WRIST, side) + Vector3(0.0, 0.004, 0.004)
	var knuckle := root + Vector3(-0.004 * side, 0.004, 0.02)
	var tip := knuckle + Vector3(-0.007 * side, -0.006, 0.009)
	var w := 0.0045
	var ring := [Vector3(w * side, 0, 0), Vector3(0, w, 0), Vector3(-w * side, 0, 0), Vector3(0, -w * 0.6, 0)]
	for k in 4:
		var a: Vector3 = ring[k]
		var b: Vector3 = ring[(k + 1) % 4]
		var out := (a + b).normalized()
		for at: Vector3 in [root + a, knuckle + a * 0.6, knuckle + b * 0.6, root + a, knuckle + b * 0.6, root + b, knuckle + a * 0.6, tip, knuckle + b * 0.6]:
			_vert(st, at, out, FUR, 0.0, side, 1.0, 0.0)


# An ear: a tall cupped shell standing up from the top of the head, leaning
# out, its hollow facing forward (the front faces of its triangles: the shader
# paints them paler).
static func _ear(st: SurfaceTool, side: float) -> void:
	var base := Vector3(0.021 * side, 0.044, 0.084)
	var up := Vector3(0.38 * side, 1.0, -0.12).normalized()
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
		var corners := tri.duplicate()
		var normal: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalized()
		# (wound so that the front faces look forward, out of the hollow)
		if normal.dot(-back) < 0.0:
			corners.reverse()
			normal = -normal
		for at: Vector3 in corners:
			_vert(st, at, normal, EAR)


# An eye: a small dark bead on the side of the face; UV.y runs from 0 in its
# middle to 1 at its rim, for the shader's glint.
static func _eye(st: SurfaceTool, side: float) -> void:
	var out := Vector3(0.78 * side, 0.5, 0.38).normalized()
	var middle := Vector3(0.024 * side, 0.031, 0.114) + out * 0.002
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
			var n := (at - (middle - out * 0.006)).normalized()
			st.set_custom(0, Color(EYE, 0.0, 0.0, 0.0))
			st.set_normal(n)
			st.set_uv(Vector2(0.0, 0.0 if at == middle else 1.0))
			st.set_uv2(Vector2.ZERO)
			st.add_vertex(at)


static func _leg(st: SurfaceTool, side: float) -> void:
	var hip := Vector3(0.024 * side, -0.004, -0.075)
	var ankle := Vector3(ANKLE.x * side, -0.004, ANKLE.y)
	var foot := Vector3(0.045 * side, 0.004, -0.152)
	var width := Vector3(0.0, 0.01, 0.0)
	for tri in [[hip - width, ankle - width, ankle + width], [hip - width, ankle + width, hip + width]]:
		for at: Vector3 in tri:
			_vert(st, at, Vector3(side, 0.0, 0.0), FUR)
	# Toes: three little hooked claws, that it hangs by.
	for k in 3:
		var spread := (k - 1) * 0.006
		var toe := foot + Vector3(spread * side, 0.0, -0.014)
		var hook := toe + Vector3(0.0, -0.008, 0.004)
		for at: Vector3 in [ankle + Vector3(spread, 0.004, 0), toe, hook, ankle + Vector3(spread, -0.004, 0), toe, ankle + Vector3(spread, 0.004, 0)]:
			_vert(st, at, Vector3(side, 0.3, 0.0), FUR)


static func _tail(st: SurfaceTool) -> void:
	var middle := Vector3(0.0, 0.0, -0.09)
	var end := Vector3(0.0, -0.008, -0.158)
	var points := [Vector3(-0.024, -0.004, -0.075), Vector3(-ANKLE.x, -0.004, ANKLE.y), end, Vector3(ANKLE.x, -0.004, ANKLE.y), Vector3(0.024, -0.004, -0.075)]
	for i in points.size() - 1:
		for at: Vector3 in [middle, points[i], points[i + 1]]:
			# (a line along each leg, where the skin is stretched from it)
			var line := 0.0 if (at.z <= -0.07 and at.z > -0.14 and at != middle) else 1.0
			_vert(st, at, Vector3.UP, SKIN, 0.7 if at == end else 0.3, 0.0, line, 1.0 if i == 0 or i == 3 else 0.0)
