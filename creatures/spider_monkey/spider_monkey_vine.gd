class_name SpiderMonkeyVine
extends MeshInstance3D
## An old woody vine (a liana, long dead) strung along a wall or between
## trees, for spider monkeys to hang from: a twisted rope of bark sagging
## between the places it is held (`anchors`), knotted, with thin tendrils hanging
## from it and, at either end, its stem going on down to the ground. One mesh,
## one draw (and its shadow).
##
## Give it `anchors` (its own space: the line runs through them in order,
## sagging `sag` metres in the middle of each span), `ground` (how far down,
## in its own Y, its two ends go; NAN for nowhere: they end in the air) and
## `away` (which way is off the wall it runs along, to keep its tendrils and
## stems off it), then `build()`. `point_at(t)` and `axis_at(t)` (t from 0 at
## its first anchor to 1 at its last) say where the line is and which way it
## runs there, in its own space, for whatever hangs from it; `nearest(point)`
## where along it a point is nearest; `foot(end)` where a stem meets the ground.

@export var anchors := PackedVector3Array()
@export var sag := 0.35
@export var thickness := 0.045
@export var ground := NAN
@export var away := Vector3.BACK
@export var seed_value := 0

## The line, finely: points and how far along it each is (0..1).
var _line := PackedVector3Array()
var _along := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

static var _material: StandardMaterial3D


func _ready() -> void:
	if mesh == null and anchors.size() >= 2:
		build()


func build() -> void:
	_rng.seed = seed_value
	_line = PackedVector3Array()
	# (through the anchors smoothly, a Catmull-Rom curve, sagging between them)
	for a in anchors.size() - 1:
		var p0 := anchors[maxi(a - 1, 0)]
		var p1 := anchors[a]
		var p2 := anchors[a + 1]
		var p3 := anchors[mini(a + 2, anchors.size() - 1)]
		var steps := maxi(4, int(p1.distance_to(p2) / 0.25))
		for k in steps:
			var t := float(k) / steps
			var dip := pow(sin(PI * t), 2.0) * sag
			var at := 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t)
			_line.append(at + Vector3.DOWN * dip)
	_line.append(anchors[anchors.size() - 1])
	_along = PackedFloat32Array()
	var total := 0.0
	_along.append(0.0)
	for k in range(1, _line.size()):
		total += _line[k].distance_to(_line[k - 1])
		_along.append(total)
	for k in _along.size():
		_along[k] /= maxf(total, 0.001)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var off := away.normalized()
	# The vine itself: twisted, knotted, thicker towards its stems.
	var radii := PackedFloat32Array()
	for k in _line.size():
		var knot := 1.0 + 0.35 * maxf(0.0, sin(k * 1.9 + seed_value)) ** 6.0
		var stem := 1.0 + 0.4 * (1.0 - minf(_along[k], 1.0 - _along[k]) * 6.0) if minf(_along[k], 1.0 - _along[k]) < 0.16 else 1.0
		radii.append(thickness * knot * stem)
	_tube(st, _line, radii, 7, Color(0.2, 0.18, 0.15))
	# A second, thinner strand twisted round it.
	var twist := PackedVector3Array()
	var thin := PackedFloat32Array()
	for k in _line.size():
		var dir := _dir_at(k)
		var side := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.95 else Vector3.RIGHT
		var up := side.cross(dir).normalized()
		var a := k * 0.55 + seed_value
		twist.append(_line[k] + (side * cos(a) + up * sin(a)) * thickness * 1.1)
		thin.append(thickness * 0.4)
	_tube(st, twist, thin, 5, Color(0.17, 0.155, 0.13))
	# Thin tendrils hanging from it, swaying a little apart.
	var count := int(_line.size() / 6.0)
	for i in count:
		var k := _rng.randi_range(2, _line.size() - 3)
		var long := _rng.randf_range(0.3, 1.6)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		var at := _line[k] + Vector3.DOWN * thickness
		var drift := Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.1, 0.1)) + off * 0.06
		for s in 6:
			pts.append(at)
			rad.append(thickness * 0.22 * (1.0 - s / 6.0) + 0.004)
			at += Vector3.DOWN * long / 5.0 + drift * (s / 5.0)
		_tube(st, pts, rad, 4, Color(0.22, 0.2, 0.16))
	# The stems at its two ends, down to the ground, wavering, clinging to the wall.
	if not is_nan(ground):
		for end in 2:
			var top := _line[0] if end == 0 else _line[_line.size() - 1]
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			var high := top.y - ground
			var steps := maxi(4, int(high / 0.4))
			for s in steps + 1:
				var t := float(s) / steps
				var wave := Vector3(sin(t * 7.0 + end * 2.0 + seed_value) * 0.12, 0.0, 0.0)
				wave = wave - off * off.dot(wave)
				pts.append(Vector3(top.x, lerpf(top.y, ground - 0.1, t), top.z) + wave + off * (0.02 + 0.03 * t))
				rad.append(thickness * (1.3 + 0.5 * t))
			_tube(st, pts, rad, 7, Color(0.19, 0.17, 0.14))
	mesh = st.commit()
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
		_material.metallic_specular = 0.0
	material_override = _material


## Where the line is at `t` (0..1 along it), in its own space.
func point_at(t: float) -> Vector3:
	if _line.is_empty():
		return Vector3.ZERO
	t = clampf(t, 0.0, 1.0)
	for k in range(1, _along.size()):
		if _along[k] >= t:
			var f := (t - _along[k - 1]) / maxf(_along[k] - _along[k - 1], 0.0001)
			return _line[k - 1].lerp(_line[k], f)
	return _line[_line.size() - 1]


## Which way the line runs at `t`.
func axis_at(t: float) -> Vector3:
	var a := point_at(t - 0.01)
	var b := point_at(t + 0.01)
	return (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector3.RIGHT


## How long the line is (metres).
func length() -> float:
	var total := 0.0
	for k in range(1, _line.size()):
		total += _line[k].distance_to(_line[k - 1])
	return total


## Where along it (0..1) is nearest `point` (its own space).
func nearest(point: Vector3) -> float:
	var best := 0.0
	var far := INF
	for k in _line.size():
		var d := _line[k].distance_squared_to(point)
		if d < far:
			far = d
			best = _along[k]
	return best


## Where the stem at one end (0 its first, 1 its last) meets the ground, in its own space.
func foot(end: int) -> Vector3:
	var top := point_at(0.0 if end == 0 else 1.0)
	return Vector3(top.x, ground if not is_nan(ground) else top.y, top.z) + away.normalized() * 0.05


func _dir_at(k: int) -> Vector3:
	var a := _line[maxi(k - 1, 0)]
	var b := _line[mini(k + 1, _line.size() - 1)]
	return (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector3.RIGHT


## A tube along `points`, a radius at each, `sides` round, coloured `colour` (a little mottled).
func _tube(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int, colour: Color) -> void:
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var prev_side := Vector3.ZERO
	for k in points.size():
		var a := points[maxi(k - 1, 0)]
		var b := points[mini(k + 1, points.size() - 1)]
		var dir := (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector3.DOWN
		var side := prev_side - dir * prev_side.dot(dir) if prev_side != Vector3.ZERO else dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
		side = side.normalized()
		prev_side = side
		var up := side.cross(dir).normalized()
		var ring := PackedVector3Array()
		var outs := PackedVector3Array()
		for s in sides:
			var angle := TAU * s / sides
			var bump := 1.0 + 0.12 * sin(angle * 3.0 + k * 1.3)
			var out := side * cos(angle) + up * sin(angle)
			ring.append(points[k] + out * radii[k] * bump)
			outs.append(out)
		rings.append(ring)
		normals.append(outs)
	for k in rings.size() - 1:
		var shade := 0.85 + 0.3 * _rng.randf()
		st.set_color(Color(colour.r * shade, colour.g * shade, colour.b * shade))
		for s in sides:
			var s2 := (s + 1) % sides
			# (smooth: each corner its own normal, straight out from the line)
			for corner: Vector2i in [Vector2i(k, s), Vector2i(k, s2), Vector2i(k + 1, s2), Vector2i(k, s), Vector2i(k + 1, s2), Vector2i(k + 1, s)]:
				st.set_normal(normals[corner.x][corner.y])
				st.add_vertex(rings[corner.x][corner.y])
