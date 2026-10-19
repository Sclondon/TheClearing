@tool
class_name Vine
extends Rope
## A vine hanging from a ledge or the top of a wall: a Rope (so it swings, and the
## boy catches it, climbs it and leaps off it as he does a rope), drawn as a
## green stem with leaves along it that go where the stem goes.

## Leaves along each piece of the stem: at least LEAVES, and one for every
## LEAF_REACH metres of it (so a long vine is as leafy as a short one).
const LEAVES := 4
const LEAF_REACH := 0.4

static var _leaf_mesh: ArrayMesh
static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D

var _leaves: MultiMeshInstance3D
## Each leaf's piece, how far along it, which way round the stem, and how big.
var _placing: Array = []
## Which way from its top what holds it is (a wall, a ledge's edge, a bridge; 0: over it): its roots grip that.
var hold := Vector3.ZERO


func _init() -> void:
	thickness = 0.04


func _ready() -> void:
	super()
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.2, 0.24, 0.12)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf.roughness = 1.0
		_leaf.metallic_specular = 0.0
		_leaf_mesh = leaf_mesh(0.16)
	_links.material_override = _stem
	_knot.material_override = _stem
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snappedf(0.01))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	var each := maxi(LEAVES, roundi(length / PIECES / LEAF_REACH))
	multi.instance_count = PIECES * each + ANCHOR_LEAVES
	for i in PIECES * each:
		_placing.append([i / each, rng.randf(), rng.randf() * TAU, rng.randf_range(0.7, 1.3)])
		multi.set_instance_color(i, Color(0.16, 0.27, 0.12).lightened(rng.randf_range(-0.1, 0.25)))
	# (where it is held: a clump of leaves, and a knot of roots gripping what holds it)
	var size := thickness / 0.04
	var clump := anchor_leaves(global_position, hold, size, rng, ANCHOR_LEAVES)
	for k in ANCHOR_LEAVES:
		multi.set_instance_transform(PIECES * each + k, clump[k][0])
		multi.set_instance_color(PIECES * each + k, clump[k][1])
	add_child(roots(global_position, hold, size, rng))
	_leaves = MultiMeshInstance3D.new()
	_leaves.multimesh = multi
	_leaves.material_override = _leaf
	_leaves.top_level = true
	_leaves.visibility_range_end = Rope.SEEN
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leaves)
	_draw()


func _draw() -> void:
	super()
	if _leaves == null:
		return
	var multi := _leaves.multimesh
	for i in _placing.size():
		var place: Array = _placing[i]
		var a := _points[place[0]]
		var b := _points[place[0] + 1]
		var along := (b - a).normalized() if a.distance_squared_to(b) > 0.000001 else Vector3.DOWN
		var out := round_stem(along, Vector3.DOWN, Vector3.RIGHT, place[2])
		var at := a.lerp(b, place[1]) + out * thickness
		# (a leaf stands out from the stem and droops along it)
		var basis := Basis(out.cross(along).normalized(), out, along).rotated(out.cross(along).normalized(), 0.6)
		multi.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * place[3]), at))


# --- Where it is held ---
# (the user, 2026-10-18: "the vines need to have a root or leaves at their connection
# points": a knot of woody roots gripping what holds it, a clump of leaves round it)

## How many leaves round where a vine is held.
const ANCHOR_LEAVES := 18
static var _roots: ArrayMesh
static var _root_material: StandardMaterial3D


## The way the roots at `at` grip what holds the vine there, `hold` the way to it
## from there (0: over it), as a frame whose +Z points into it.
static func held_frame(hold: Vector3) -> Basis:
	var z := hold.normalized() if hold.length_squared() > 0.0001 else Vector3.UP
	var x := z.cross(Vector3.UP)
	x = x.normalized() if x.length_squared() > 0.001 else Vector3.RIGHT
	return Basis(x, z.cross(x), z)


## A knot of roots where a vine is held at `at` (`hold` as for held_frame), as big
## as `size` says (1 for a vine 4 cm thick), turned round its way as `rng` says: one
## shape for every vine, drawn once each.
static func roots(at: Vector3, hold: Vector3, size: float, rng: RandomNumberGenerator) -> MeshInstance3D:
	if _roots == null:
		_roots = _root_mesh()
		_root_material = StandardMaterial3D.new()
		_root_material.albedo_color = Color(0.22, 0.18, 0.12)
		_root_material.roughness = 1.0
		_root_material.metallic_specular = 0.0
		_root_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shown := MeshInstance3D.new()
	shown.mesh = _roots
	shown.material_override = _root_material
	shown.top_level = true
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.visibility_range_end = 90.0
	var frame := held_frame(hold)
	shown.transform = Transform3D(frame.rotated(frame.z, rng.randf() * TAU).scaled(Vector3.ONE * size * rng.randf_range(0.85, 1.15)), at)
	return shown


## Where the leaves round a vine's hold go: [transform, colour] each, `count` of them.
static func anchor_leaves(at: Vector3, hold: Vector3, size: float, rng: RandomNumberGenerator, count: int) -> Array:
	var frame := held_frame(hold)
	var made: Array = []
	for i in count:
		# (thickest round where it is held, spreading over what holds it, more back towards it)
		var spread := Vector2.from_angle(rng.randf() * TAU) * pow(rng.randf(), 0.6) * 0.45 * size
		var spot := at + frame.x * spread.x + frame.y * spread.y + frame.z * rng.randf_range(-0.05, 0.35) * size
		var facing := (-frame.z + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
		var basis := Basis.looking_at(facing, Vector3.UP if absf(facing.y) < 0.95 else Vector3.BACK).rotated(facing, rng.randf() * TAU)
		made.append([Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.5) * size), spot), Color(0.15, 0.26, 0.11).lightened(rng.randf_range(-0.12, 0.2))])
	return made


## The roots: gnarled, tapering tendrils from the origin, spreading out round +Z and
## back along it (into what holds the vine), kinked as they go.
static func _root_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var tendrils := 9
	for k in tendrils:
		var a := (k + rng.randf_range(-0.3, 0.3)) * TAU / tendrils
		var heading := Vector3(cos(a), sin(a), rng.randf_range(0.25, 0.9)).normalized()
		var long := rng.randf_range(0.35, 0.85)
		var points := PackedVector3Array([Vector3.ZERO])
		var at := Vector3.ZERO
		var steps := 6
		for s in steps:
			heading = (heading + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.2, 0.3))).normalized()
			at += heading * long / steps
			points.append(at)
		_tube(tool, points, 0.04, 0.007)
		# (a side root off it, now and then)
		if rng.randf() < 0.6:
			var from := points[2]
			var side := PackedVector3Array([from])
			var way := (heading + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0.2)).normalized()
			for s in 3:
				from += way * long * 0.12
				way = (way + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5), 0.0)).normalized()
				side.append(from)
			_tube(tool, side, 0.018, 0.005)
	tool.generate_normals()
	return tool.commit()


## A tube of five sides along `points`, `from` thick at its start tapering to `to`.
static func _tube(tool: SurfaceTool, points: PackedVector3Array, from: float, to: float) -> void:
	var sides := 5
	var rings: Array = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var x := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var y := along.cross(x)
		var r := lerpf(from, to, float(i) / (points.size() - 1))
		var ring: Array[Vector3] = []
		for s in sides:
			var t := s * TAU / sides
			ring.append(points[i] + (x * cos(t) + y * sin(t)) * r)
		rings.append(ring)
	for i in points.size() - 1:
		for s in sides:
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][(s + 1) % sides]
			var c: Vector3 = rings[i + 1][(s + 1) % sides]
			var d: Vector3 = rings[i + 1][s]
			tool.add_vertex(a)
			tool.add_vertex(b)
			tool.add_vertex(c)
			tool.add_vertex(a)
			tool.add_vertex(c)
			tool.add_vertex(d)




## Which way out from a stem running `along` a leaf stands, `angle` round it: the
## way it stands round the stem lying `rest` (`rest_out` at angle 0), turned the
## least way that takes `rest` to `along`. So a leaf goes round with the stem as it
## swings, smoothly. (Taken from the world's up, as they were, the leaves of a
## vine hanging nearly straight jumped round it whenever it swung past straight:
## the user, 2026-10-18, "the leaves seem to teleport when they move".)
static func round_stem(along: Vector3, rest: Vector3, rest_out: Vector3, angle: float) -> Vector3:
	var out := rest_out.rotated(rest, angle)
	if along.dot(rest) < -0.999:
		return out
	return Quaternion(rest, along) * out


## A leaf, pointed at both ends, `size` long, lying in the XY plane along +Y.
static func leaf_mesh(size: float) -> ArrayMesh:
	var points := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(size * 0.32, size * 0.45, 0), Vector3(0, size, 0), Vector3(-size * 0.32, size * 0.45, 0),
	])
	var normals := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
