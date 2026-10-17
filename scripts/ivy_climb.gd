@tool
class_name IvyClimb
extends Ladder
## Ivy grown thick enough up a wall to climb: a Ladder (the boy takes hold by
## going into it, climbs with up and down, steps off at the top onto whatever it
## grows up against, and leaps off backwards with jump), drawn as old woody stems
## up the face with a mat of leaves over them, `width` across. Its back is to
## the wall: place it on the face with its +Z pointing out, as a Ladder.

@export var width := 1.8

static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _leaf_mesh: ArrayMesh


func _ready() -> void:
	add_to_group(&"ladders")
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.24, 0.2, 0.14)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf.roughness = 1.0
		_leaf.metallic_specular = 0.0
		_leaf_mesh = Vine.leaf_mesh(0.13)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snappedf(0.01))
	# Stems: a few thick ones that wander up the face, close against it.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in 5:
		var x := rng.randf_range(-0.45, 0.45) * width
		var wander := rng.randf() * TAU
		var y := 0.0
		var last := Vector3(x, 0.0, -0.08)
		while y < height:
			y = minf(y + 0.6, height)
			var next := Vector3(clampf(x + sin(y * 0.9 + wander) * 0.18 * width, -width * 0.5, width * 0.5), y, -0.08)
			_branch(tool, last, next, 0.035)
			last = next
	tool.generate_normals()
	var stems := MeshInstance3D.new()
	stems.mesh = tool.commit()
	stems.material_override = _stem
	add_child(stems)
	# Leaves, thick over the whole patch and thinning at its edges.
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	var count := int(width * height * 70.0)
	multi.instance_count = count
	for i in count:
		var across := rng.randf_range(-0.5, 0.5)
		# (fewer out at the sides)
		across *= 0.6 + 0.4 * rng.randf()
		var at := Vector3(across * width, rng.randf() * height, rng.randf_range(-0.05, 0.12))
		var basis := Basis(Vector3.BACK, rng.randf_range(-1.2, 1.2) + PI).rotated(Vector3.RIGHT, rng.randf_range(-0.9, -0.2))
		multi.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), at))
		multi.set_instance_color(i, Color(0.09, 0.17, 0.07).lightened(rng.randf_range(-0.05, 0.14)))
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = multi
	leaves.material_override = _leaf
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leaves)


## A square-sectioned length of stem from `a` to `b`.
static func _branch(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.BACK).normalized() * radius
	var out := Vector3.BACK * radius
	var corners := [side + out, -side + out, -side - out, side - out]
	for k in 4:
		var p: Vector3 = corners[k]
		var q: Vector3 = corners[(k + 1) % 4]
		for v: Vector3 in [a + p, b + p, b + q, a + p, b + q, a + q]:
			tool.add_vertex(v)
