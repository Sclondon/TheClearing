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
	multi.instance_count = PIECES * each
	for i in multi.instance_count:
		_placing.append([i / each, rng.randf(), rng.randf() * TAU, rng.randf_range(0.7, 1.3)])
		multi.set_instance_color(i, Color(0.16, 0.27, 0.12).lightened(rng.randf_range(-0.1, 0.25)))
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
		var out := along.cross(Vector3.UP)
		out = out.normalized() if out.length_squared() > 0.001 else Vector3.RIGHT
		out = out.rotated(along, place[2])
		var at := a.lerp(b, place[1]) + out * thickness
		# (a leaf stands out from the stem and droops along it)
		var basis := Basis(out.cross(along).normalized(), out, along).rotated(out.cross(along).normalized(), 0.6)
		multi.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * place[3]), at))


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
