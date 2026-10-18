class_name WallMesh
extends RefCounted
## Many wall boxes gathered into one mesh, each with its top edges and upright
## corners rounded off (the bottom, on the ground, left square): worn concrete
## rather than machined boxes. The rounding is uneven along each edge, wider in
## places and nearly sharp in others (chosen by where the edge is in the world,
## so boxes that meet round alike), and its normals run smoothly round it.
##
## Each face also carries, for the wall's shader (Wall.SHADER), how far each
## point is from its edges: UV the point across the face (x) and up it (y,
## measured down from its top for a side face), UV2 half the face's width each
## way, so that half - |at| is the distance to the nearest edge (on a side face,
## its upright edges in x and its top in y). An edge not rounded (the ends of a
## length of a round wall, which run on into the next) is so far off it shows no wear.

## Far enough that an edge so far off shows no wear.
const FAR := 1000.0

var points := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var indices := PackedInt32Array()


func is_empty() -> bool:
	return points.is_empty()


## The gathered boxes as a mesh (null if there are none).
func mesh() -> ArrayMesh:
	if points.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


## A box `size` with its middle at `at`, in the space of `where`, its edges rounded by about `radius` metres (0: square), the
## upright corners at its ends in x and z rounded too unless `round_x` /
## `round_z` is off. Its long edges get a vertex every `spacing` metres or so, so
## that their rounding can wander along them.
func add_box(where: Transform3D, at: Vector3, size: Vector3, radius: float, round_x := true, round_z := true, spacing := 3.0, bottom := false) -> void:
	var h := size * 0.5
	# (never more than a share of its thinnest way, so a thin ledge keeps its shape)
	var thinnest := h.y
	if round_x:
		thinnest = minf(thinnest, h.x)
	if round_z:
		thinnest = minf(thinnest, h.z)
	var r := minf(radius, thinnest * 0.35)
	var xs := _stops(h.x, r if round_x else 0.0, spacing)
	var zs := _stops(h.z, r if round_z else 0.0, spacing)
	var ys := PackedFloat32Array([-h.y])
	if r > 0.0:
		ys.append(h.y - r)
	ys.append(h.y)
	var ex := h.x if round_x else FAR
	var ez := h.z if round_z else FAR
	var box := [where, at, h, r, round_x, round_z]
	# The top: across x, then z.
	_face(box, Vector3.UP, xs, zs, func(a: float, b: float) -> Vector3: return Vector3(a, h.y, b),
		func(q: Vector3) -> Vector2: return Vector2(q.x, q.z), Vector2(ex, ez))
	# (its underside too if `bottom`: one standing up off the ground, a lintel or a roof)
	if bottom:
		_face(box, Vector3.DOWN, xs, zs, func(a: float, b: float) -> Vector3: return Vector3(a, -h.y, b),
			func(q: Vector3) -> Vector2: return Vector2(q.x, q.z), Vector2(ex, ez))
	# The four sides: across, then up (their y measured down from the top).
	for s: float in [1.0, -1.0]:
		_face(box, Vector3(s, 0, 0), zs, ys, func(a: float, b: float) -> Vector3: return Vector3(h.x * s, b, a),
			func(q: Vector3) -> Vector2: return Vector2(q.z, q.y - h.y + FAR), Vector2(ez, FAR))
		_face(box, Vector3(0, 0, s), xs, ys, func(a: float, b: float) -> Vector3: return Vector3(a, b, h.z * s),
			func(q: Vector3) -> Vector2: return Vector2(q.x, q.y - h.y + FAR), Vector2(ex, FAR))


## Where the vertices go across a face `half` each way of its middle: at its
## edges, where their rounding starts (`r` in; none if 0), and every `spacing`
## or so between.
static func _stops(half: float, r: float, spacing: float) -> PackedFloat32Array:
	var stops := PackedFloat32Array([-half])
	if r > 0.0:
		stops.append(-half + r)
	var inner := half - r
	var count := floori(inner * 2.0 / spacing)
	for i in range(1, count):
		stops.append(-inner + inner * 2.0 * i / count)
	if r > 0.0:
		stops.append(half - r)
	stops.append(half)
	return stops


## One face of `box` ([where, at, half, radius, round_x, round_z]) facing `n`, a
## grid over `across` x `up`, each point made by `point` and its UV by `uv`.
func _face(box: Array, n: Vector3, across: PackedFloat32Array, up: PackedFloat32Array, point: Callable, uv: Callable, half: Vector2) -> void:
	var where: Transform3D = box[0]
	var at: Vector3 = box[1]
	var first := points.size()
	var columns := across.size()
	for b in up:
		for a in across:
			var q: Vector3 = point.call(a, b)
			var made := _rounded(box, q, n)
			points.append(where * (at + made[0]))
			normals.append((where.basis * made[1]).normalized())
			uvs.append(uv.call(q))
			uv2s.append(half)
	# (Godot's fronts are wound clockwise seen from in front)
	var q00: Vector3 = point.call(across[0], up[0])
	var q10: Vector3 = point.call(across[1], up[0])
	var q01: Vector3 = point.call(across[0], up[1])
	var flip := (q10 - q00).cross(q01 - q00).dot(n) > 0.0
	for j in up.size() - 1:
		for i in columns - 1:
			var p00 := first + j * columns + i
			var p10 := p00 + 1
			var p01 := p00 + columns
			var p11 := p01 + 1
			if flip:
				indices.append_array([p00, p01, p11, p00, p11, p10])
			else:
				indices.append_array([p00, p11, p01, p00, p10, p11])


## A point `q` on the square box's face (facing `n`) moved onto the rounded box,
## and its normal there: within the rounding of an edge it is brought round to
## the curve of that edge. The rounding there is the box's, more or less as the
## edge wears (worn deeper in places, nearly sharp in others).
static func _rounded(box: Array, q: Vector3, n: Vector3) -> Array:
	var r: float = box[3]
	if r <= 0.0:
		return [q, n]
	var h: Vector3 = box[2]
	var world: Vector3 = box[0] * (box[1] + q)
	var rv := r * _wear(world)
	var inner := Vector3(clampf(q.x, -h.x + rv, h.x - rv) if box[4] else q.x, minf(q.y, h.y - rv), clampf(q.z, -h.z + rv, h.z - rv) if box[5] else q.z)
	var d := q - inner
	var length := d.length()
	if length < 0.0001:
		return [q, n]
	var out := d / length
	# (a flat face's own points stay where they are: only those in the rounding move)
	return [inner + out * rv, out]


## How deep the edge is worn at `p` (in the world), as a share of its rounding:
## a slow wander along it, and here and there a bite out of it.
static func _wear(p: Vector3) -> float:
	var s := p.x * 0.83 + p.z * 0.91 + p.y * 0.53
	var slow := _noise(s / 2.6)
	var bite := _noise(s / 0.9 + 17.0)
	return 0.55 + slow * 0.6 + pow(bite, 3.0) * 1.1


static func _noise(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	var a := fposmod(sin(i * 127.1) * 43758.5453, 1.0)
	var b := fposmod(sin((i + 1.0) * 127.1) * 43758.5453, 1.0)
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))
