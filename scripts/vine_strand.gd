@tool
class_name VineStrand
extends Node3D
## A vine strung across a hall from one wall to the other, sagging in the middle:
## a stem with leaves along it, hanging still (it is out of reach, high over the
## hall, and drawn once; nothing simulates it). From `from` to `to`, in the world.

@export var from := Vector3.ZERO
@export var to := Vector3(10.0, 0.0, 0.0)
## How far the middle hangs below a straight line between its ends, metres
## (0: a share of its length).
@export var sag := 0.0

const STEPS := 24
const THICK := 0.1
## Leaves per metre of stem.
const LEAVES := 30.0
## Tendrils hanging off it: about one every this many metres, this long at most.
const TENDRIL_EVERY := 0.9
const TENDRIL_LONG := 4.5

static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _leaf_mesh: ArrayMesh


func _ready() -> void:
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.2, 0.22, 0.13)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_stem.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf.roughness = 1.0
		_leaf.metallic_specular = 0.0
		_leaf_mesh = Vine.leaf_mesh(0.42)
	top_level = true
	global_transform = Transform3D.IDENTITY
	var points := curve()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snappedf(0.01))
	# Stems twisted round each other along the curve, and tendrils hanging off
	# them, mostly short, each a line of points.
	var lines: Array[PackedVector3Array] = []
	var along_all := (to - from).normalized()
	var across := along_all.cross(Vector3.UP).normalized()
	for s in 3:
		var twisted := PackedVector3Array()
		var turns := rng.randf_range(3.0, 6.0)
		var phase := s * TAU / 3.0
		for i in points.size():
			var a := phase + i / float(points.size() - 1) * turns * TAU
			twisted.append(points[i] + (across * cos(a) + Vector3.UP * sin(a)) * THICK * 1.4)
		lines.append(twisted)
	var span := from.distance_to(to)
	for k in int(span / TENDRIL_EVERY):
		var at := points[rng.randi_range(1, points.size() - 2)]
		var long := 0.4 + pow(rng.randf(), 2.0) * TENDRIL_LONG
		var drift := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var tendril := PackedVector3Array()
		for s in 5:
			var t := s / 4.0
			tendril.append(at + Vector3.DOWN * long * t + drift * sin(t * 2.5) * long * 0.3)
		lines.append(tendril)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in lines:
		var thick := THICK * (0.7 if line.size() == points.size() else 0.3)
		for i in line.size() - 1:
			_tube(tool, line[i], line[i + 1], thick)
	tool.generate_normals()
	var stem := MeshInstance3D.new()
	stem.mesh = tool.commit()
	stem.material_override = _stem
	add_child(stem)
	# Leaves along the stem and the tendrils, every way round, drooping.
	var pieces: Array = []
	var length := 0.0
	for line in lines:
		for i in line.size() - 1:
			pieces.append([line[i], line[i + 1]])
			length += line[i].distance_to(line[i + 1])
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	multi.instance_count = int(length * LEAVES)
	for i in multi.instance_count:
		var piece: Array = pieces[rng.randi_range(0, pieces.size() - 1)]
		var a: Vector3 = piece[0]
		var b: Vector3 = piece[1]
		var at := a.lerp(b, rng.randf())
		var along := (b - a).normalized()
		var round_about := Basis(along, rng.randf() * TAU)
		var upright := absf(along.y) > 0.8
		var out := round_about * (Vector3.RIGHT if upright else Vector3.UP).cross(along).normalized()
		# (hanging leaves droop: more of them below the stem)
		if not upright:
			out = (out + Vector3.DOWN * 0.6).normalized()
		var basis := Basis.looking_at(out, along).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		multi.set_instance_transform(i, Transform3D(basis, at + out * 0.05))
		multi.set_instance_color(i, Color(0.16, 0.26, 0.12).lightened(rng.randf_range(-0.1, 0.22)))
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = multi
	leaves.material_override = _leaf
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaves.visibility_range_end = 160.0
	add_child(leaves)


## Points along it from `from` to `to`, hanging as a chain does (near enough: a
## parabola), with a little twist of slack so that no two hang alike.
func curve() -> PackedVector3Array:
	var drop := sag if sag > 0.0 else from.distance_to(to) * 0.12
	var points := PackedVector3Array()
	for i in STEPS + 1:
		var t := i / float(STEPS)
		points.append(from.lerp(to, t) + Vector3.DOWN * drop * 4.0 * t * (1.0 - t))
	return points


static func _tube(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized() if absf(along.y) < 0.95 else Vector3.RIGHT
	var up := side.cross(along).normalized()
	for k in 4:
		var p0 := (side * cos(k * TAU / 4.0) + up * sin(k * TAU / 4.0)) * radius
		var p1 := (side * cos((k + 1) * TAU / 4.0) + up * sin((k + 1) * TAU / 4.0)) * radius
		tool.add_vertex(a + p0)
		tool.add_vertex(b + p0)
		tool.add_vertex(b + p1)
		tool.add_vertex(a + p0)
		tool.add_vertex(b + p1)
		tool.add_vertex(a + p1)
