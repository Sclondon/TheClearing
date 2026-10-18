class_name GriffinflyLook
## What the griffinfly looks like: its mesh (full and low detail) and a material
## for it, posed in the shader (`griffinfly.gdshader`), so that one griffinfly
## is one draw however its wings, head, legs and abdomen move.
##
## A griffinfly (Meganeura, of the coal forests): two huge faceted eyes nearly
## meeting over a small face, toothed jaws under it, a short neck, a great
## thorax slanted back with the legs forward under it and the wings on its top,
## six spiny legs held forward as a basket, a long abdomen of ten segments with
## two cerci at its tip, and four long narrow wings, smoky, in a dense net of
## veins. Dull bronze-brown, near enough the colour of the maze.
##
## The model is one unit across the wings, facing +Z, back up; Griffinfly scales
## it. Built in Blender by `tools/build_griffinfly.py`, its parts told apart by
## material (PARTS).

const MODEL := "res://creatures/griffinfly/models/griffinfly.glb"
const MODEL_LO := "res://creatures/griffinfly/models/griffinfly_lo.glb"
const SHADER := preload("res://creatures/griffinfly/griffinfly.gdshader")
## The parts, by material, as the shader numbers them.
const PARTS := {"body": 0, "head": 1, "eye": 2, "jaw": 3, "antenna": 4, "abdomen": 5,
	"leg_fore": 6, "leg_mid": 7, "leg_hind": 8, "wing": 9, "hindwing": 10}
## Where its wings are hinged and its neck is, in the model (as the shader has them).
const HINGE_FORE := Vector3(0.012, 0.043, 0.13)
const HINGE_HIND := Vector3(0.012, 0.041, 0.088)
const NECK := Vector3(0.0, 0.004, 0.19)
## Where its basket of legs is, in front of and under its head (what it takes prey with).
const BASKET := Vector3(0.0, -0.06, 0.23)

static var _meshes := {}


## Its mesh (`low`: the low-detail one, about a quarter of the triangles). One for everybody.
static func mesh(low := false) -> ArrayMesh:
	if not _meshes.has(low):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lay_out(tool, _modelled(MODEL_LO if low else MODEL))
		_meshes[low] = tool.commit()
	return _meshes[low]


## A material for one griffinfly (its own: the pose is in its uniforms).
static func material(tone := 0.5) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = SHADER
	made.set_shader_parameter(&"tone", tone)
	return made


## How many triangles it is.
static func triangles(low := false) -> int:
	var made := mesh(low)
	return made.surface_get_array_len(0) / 3 if made.get_surface_count() > 0 else 0


static func _modelled(path: String) -> ArrayMesh:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("GriffinflyLook: no model at %s (build it with creatures/griffinfly/tools/build_griffinfly.py)" % path)
		return ArrayMesh.new()
	var model := scene.instantiate()
	var found: ArrayMesh = null
	for piece: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		found = piece.mesh as ArrayMesh
	model.free()
	return found if found else ArrayMesh.new()


# The model as the shader wants it, added to `tool`: each point with its normal
# and what part it is (UV2.x). The clear wings go last, so that they are drawn
# over the body (it is drawn in one go, see-through wings and all).
static func _lay_out(tool: SurfaceTool, from: ArrayMesh) -> void:
	var order_of := range(from.get_surface_count())
	order_of.sort_custom(func(a: int, b: int) -> bool: return _part_of(from, a) < _part_of(from, b))
	for surface: int in order_of:
		var paint := from.surface_get_material(surface)
		var named := paint.resource_name if paint else "body"
		var part: int = PARTS.get(named, 0)
		var arrays := from.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		for i in count:
			var k := order[i] if not order.is_empty() else i
			tool.set_uv2(Vector2(part, 0.0))
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])


static func _part_of(from: ArrayMesh, surface: int) -> int:
	var paint := from.surface_get_material(surface)
	return PARTS.get(paint.resource_name if paint else "body", 0)
