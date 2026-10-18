class_name AntLook
## What the giant ants of a colony (AntColony) look like: a worker, a soldier
## and the load a worker carries home, each at its real size (the worker 1.2 m
## from its jaws to the tip of its gaster, the size of a dog; the soldier with
## a head nearly twice as big and heavy jaws), facing +Z, to be drawn a colony
## at a time as one MultiMesh.
##
## They are after the carpenter ants: a heart-shaped head held a little down,
## big oval compound eyes, toothed triangular jaws, elbowed feelers (a long
## scape, then a whip of beads thickening to its tip), a narrow humped thorax,
## one upright scale for a waist and a big gaster of four plates, and six long
## legs, each coxa, femur, tibia and beaded tarsus. Dark glossy chitin lit in
## hard bands (`ant.gdshader`): the overcast sky in a pale band along the
## back, the legs duller and browner, the eyes black, a paler fringe at the rim
## of each plate of the gaster.
##
## The model is `models/ants.glb` (and the demade `ants_lo.glb`, about 1000
## triangles to the full one's 2400), built by `tools/build_ants.py`, which
## says what each point tells the shader. Their legs (a tripod gait), feelers,
## jaws and gaster are moved in the shader, so a colony is one draw, or two
## with the far ones in the low model.

enum Kind { WORKER, SOLDIER }

const MODEL := "res://creatures/giant_ant/models/ants.glb"
const MODEL_LO := "res://creatures/giant_ant/models/ants_lo.glb"
const SHADER := preload("res://creatures/giant_ant/ant.gdshader")
## The objects in the model, in the order of their number in UV2.y.
const NAMES := ["worker", "soldier", "load"]

static var _meshes := {}
static var _material: ShaderMaterial


## The worker, the soldier and the load in one surface, in the material that
## moves them (one for everybody; `low` the demade one).
static func mesh(low := false) -> ArrayMesh:
	if not _meshes.has(low):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for which in NAMES.size():
			_lay_out(tool, modelled(NAMES[which], low), which)
		tool.index()
		var made := tool.commit()
		made.surface_set_material(0, material())
		_meshes[low] = made
	return _meshes[low]


## The material they are drawn in (shared: its colours are uniforms).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## A thing in the model by its name (`low`: in the demade one).
static func modelled(which: String, low := false) -> ArrayMesh:
	var scene := load(MODEL_LO if low else MODEL) as PackedScene
	if scene == null:
		push_error("AntLook: no model (build it with creatures/giant_ant/tools/build_ants.py)")
		return ArrayMesh.new()
	var model := scene.instantiate()
	var part := model.find_child(which, true, false) as MeshInstance3D
	var found := part.mesh as ArrayMesh if part else null
	model.free()
	if found == null:
		push_error("The ants' model has nothing in it called %s" % which)
		return ArrayMesh.new()
	return found


## How many triangles each has (worker, soldier, load).
static func triangles(low := false) -> Array[int]:
	var counts: Array[int] = []
	for which: String in NAMES:
		var made := modelled(which, low)
		var total := 0
		for surface in made.get_surface_count():
			var order: PackedInt32Array = made.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			total += order.size() / 3
		counts.append(total)
	return counts


# A thing of the model as the shader wants it, added to `tool`: each point with
# its normal, what part it is and how far along it (its first texture
# coordinate, as the model has it), and which it belongs to (the second).
static func _lay_out(tool: SurfaceTool, from: ArrayMesh, which: int) -> void:
	for surface in from.get_surface_count():
		var arrays := from.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var parts: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		tool.set_uv2(Vector2(0.0, which))
		for i in count:
			var k := order[i] if not order.is_empty() else i
			var uv := parts[k] if k < parts.size() else Vector2.ZERO
			tool.set_uv(Vector2(snappedf(uv.x, 0.005), roundf(uv.y)))
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])
