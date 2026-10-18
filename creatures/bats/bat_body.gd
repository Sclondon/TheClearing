class_name BatBody
## What a bat looks like: one low mesh, made here in code, and its material
## (creatures/bats/bat.gdshader). BatColony draws a whole colony with these as
## one MultiMesh, so a colony is one draw however many bats are in it.
##
## The mesh is a big dark bat with a wingspan of 1 (scale it up by the span you
## want), facing +Z, its back up (+Y), wings out along X, open flat. It has a
## long body and a fox's muzzle, tall pointed ears, two pale eyes, hind legs
## trailing behind with the skin of the tail stretched between them, and wings
## of thin skin on long fingers whose bones show as dark lines. Nothing in the
## mesh moves: the shader beats, bends and folds the wings, from each bat's
## custom data (see the shader's comment), and everything else is the bat's
## transform.

## Where the wing's joints are, as modelled (x out, z along the body; y up).
## The shader hinges the wing at SHOULDER and WRIST: keep them in step with it.
const SHOULDER := Vector2(0.035, 0.045)
const WRIST := Vector2(0.22, 0.075)
const TIP := Vector2(0.5, -0.03)
## The ends of the three fingers that spread the back of the wing, and where the
## wing's skin meets the leg at the ankle.
const FINGERS: Array[Vector2] = [Vector2(0.42, -0.17), Vector2(0.3, -0.215), Vector2(0.175, -0.185)]
const ANKLE := Vector2(0.042, -0.135)
## How far each scallop of the trailing edge is drawn in towards the wrist.
const SCALLOP := 0.3
## The body, tail to nose: (along, half width, half height, height of its middle).
const BODY: Array[Vector4] = [
	Vector4(-0.125, 0.004, 0.004, 0.0),
	Vector4(-0.09, 0.03, 0.025, 0.0),
	Vector4(-0.04, 0.046, 0.039, 0.0),
	Vector4(0.02, 0.054, 0.046, 0.004),
	Vector4(0.062, 0.039, 0.036, 0.008),
	Vector4(0.088, 0.038, 0.038, 0.013),
	Vector4(0.112, 0.031, 0.029, 0.01),
	Vector4(0.14, 0.016, 0.014, 0.004),
	Vector4(0.158, 0.004, 0.004, 0.002),
]
const ROUND := 8

## Parts, as the shader tells them apart (COLOR.r).
const FUR := 0.0
const SKIN := 0.5
const EYE := 1.0

static var _mesh: ArrayMesh
static var _shader: Shader


## The bat (made once, and shared).
static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _make()
	return _mesh


## A material for bats, coloured `fur` and `skin` (wings and ears), with eyes of `eye`.
static func material(fur := Color(0.15, 0.135, 0.13), skin := Color(0.26, 0.22, 0.21), eye := Color(0.95, 0.88, 0.72)) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://creatures/bats/bat.gdshader")
	var made := ShaderMaterial.new()
	made.shader = _shader
	made.set_shader_parameter(&"fur", fur)
	made.set_shader_parameter(&"skin", skin)
	made.set_shader_parameter(&"bone", fur.darkened(0.4))
	made.set_shader_parameter(&"eye", eye)
	return made


static func _make() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body(st)
	for side in [-1.0, 1.0]:
		_wing(st, side)
		_ear(st, side)
		_eye(st, side)
		_leg(st, side)
	_tail(st)
	return st.commit()


# One corner: where, which way it faces, what part, and for the wings, where the
# bones run (`line` 0 on a bone, with `boned` 1) and which wing (`side`) it is.
static func _vert(st: SurfaceTool, at: Vector3, normal: Vector3, part: float, side := 0.0, line := 1.0, boned := 0.0) -> void:
	st.set_color(Color(part, 0.0, 0.0))
	st.set_normal(normal.normalized())
	st.set_uv(Vector2(boned, line))
	st.set_uv2(Vector2(1.0 if side > 0.0 else 0.0, 1.0 if side != 0.0 else 0.0))
	st.add_vertex(at)


static func _body(st: SurfaceTool) -> void:
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for section in BODY:
		var ring := PackedVector3Array()
		var facing := PackedVector3Array()
		for k in ROUND:
			var a := TAU * k / ROUND
			ring.append(Vector3(cos(a) * section.y, section.w + sin(a) * section.z, section.x))
			facing.append(Vector3(cos(a) / maxf(section.y, 0.001), sin(a) / maxf(section.z, 0.001), 0.0).normalized())
		rings.append(ring)
		normals.append(facing)
	for r in rings.size() - 1:
		for k in ROUND:
			var j := (k + 1) % ROUND
			for corner in [[r, k], [r + 1, k], [r + 1, j], [r, k], [r + 1, j], [r, j]]:
				_vert(st, rings[corner[0]][corner[1]], normals[corner[0]][corner[1]], FUR)


static func _wing_point(at: Vector2, side: float) -> Vector3:
	# (bowed a little, so that it is not a flat board, and sagging to the back)
	var bow := 0.014 * sin(PI * clampf(at.x / TIP.x, 0.0, 1.0)) - 0.03 * maxf(-at.y, 0.0)
	return Vector3(at.x * side, bow, at.y)


static func _wing(st: SurfaceTool, side: float) -> void:
	var tips: Array[Vector2] = [TIP]
	tips.append_array(FINGERS)
	tips.append(ANKLE)
	var scallops: Array[Vector2] = []
	for i in tips.size() - 1:
		scallops.append(((tips[i] + tips[i + 1]) * 0.5).lerp(WRIST, SCALLOP))
	var inner := Vector2(0.12, -0.03)
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
	triangles.append([[SHOULDER, 0.0], [WRIST + Vector2(-0.07, 0.035), 1.0], [WRIST, 0.0], true])
	for tri: Array in triangles:
		var corners := [tri[0], tri[1], tri[2]]
		if side < 0.0:
			corners.reverse()
		for corner: Array in corners:
			_vert(st, _wing_point(corner[0], side), Vector3.UP, SKIN, side, corner[1], 1.0 if tri[3] else 0.0)


static func _ear(st: SurfaceTool, side: float) -> void:
	var front := Vector3(0.011 * side, 0.03, 0.104)
	var back := Vector3(0.03 * side, 0.027, 0.078)
	var tip := Vector3(0.04 * side, 0.098, 0.07)
	var out := (back - front).cross(tip - front) * side
	var corners := [front, back, tip] if side > 0.0 else [front, tip, back]
	for at: Vector3 in corners:
		_vert(st, at, out if out.x * side > 0.0 else -out, SKIN, 0.0, 0.0 if at == tip else 1.0, 1.0)


static func _eye(st: SurfaceTool, side: float) -> void:
	var middle := Vector3(0.022 * side, 0.03, 0.116)
	var out := Vector3(0.7 * side, 0.3, 0.7).normalized()
	var across := Vector3(0.0, 0.008, 0.0)
	var along := Vector3(-0.0055 * side, 0.0, 0.006)
	var corners := [middle + across, middle + along, middle - across, middle + across, middle - across, middle - along]
	if side < 0.0:
		corners = [corners[0], corners[2], corners[1], corners[3], corners[5], corners[4]]
	for at: Vector3 in corners:
		_vert(st, at + out * 0.003, out, EYE)


static func _leg(st: SurfaceTool, side: float) -> void:
	var hip := Vector3(0.022 * side, -0.004, -0.08)
	var ankle := Vector3(ANKLE.x * side, -0.004, ANKLE.y)
	var toe := Vector3(0.046 * side, 0.012, -0.168)
	var width := Vector3(0.0, 0.009, 0.0)
	for tri in [[hip - width, ankle - width, ankle + width], [hip - width, ankle + width, hip + width], [ankle - width, toe, ankle + width]]:
		for at: Vector3 in tri:
			_vert(st, at, Vector3(side, 0.0, 0.0), FUR)


static func _tail(st: SurfaceTool) -> void:
	var middle := Vector3(0.0, 0.0, -0.09)
	var end := Vector3(0.0, -0.01, -0.185)
	var points := [Vector3(-0.022, -0.004, -0.08), Vector3(-ANKLE.x, -0.004, ANKLE.y), end, Vector3(ANKLE.x, -0.004, ANKLE.y), Vector3(0.022, -0.004, -0.08)]
	for i in points.size() - 1:
		for at: Vector3 in [middle, points[i], points[i + 1]]:
			# (a line along each leg, where the skin is stretched from it)
			var line := 0.0 if (at.z <= -0.08 and at.z > -0.15 and at != middle) else 1.0
			_vert(st, at, Vector3.UP, SKIN, 0.0, line, 1.0 if i == 0 or i == 3 else 0.0)
