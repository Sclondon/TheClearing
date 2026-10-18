class_name InsectLook
## What the flying insects look like: a mesh and a material for each kind, to
## be drawn many at once as one MultiMesh (InsectSwarm).
##
## - MOTH: a stout furry body with a collar of tufts, feathery feelers combed
##   both sides, broad forewings over rounded hindwings. Three kinds by the
##   instance's variety (the shader paints them): a dusty grey-brown moth with
##   wavy dark cross-lines, a pale green luna moth with eyespots and long tails,
##   and a death's-head hawkmoth, dark above with yellow hindwings banded black
##   and a skull on its back.
## - FLY: a blowfly, its head nearly all red eye, a bristly dark thorax, a round
##   metallic blue-green abdomen, clear veined wings swept back over it at rest.
## - DRAGONFLY: great blue-green eyes meeting over its head, a striped thorax,
##   a long thin abdomen of ten segments (iridescent blue, black at the joints),
##   four long, narrow, finely netted wings with a dark spot near each tip.
##
## Each is one unit across the wings, facing +Z, back up; the swarm scales it.
## They are a Blender model, `models/insects.glb`, built by
## `tools/build_insects.py`, their parts told apart by material; the wings are
## beaten in the shader (`insect.gdshader`), which also paints them.

enum Kind { MOTH, FLY, DRAGONFLY }

const MODEL := "res://creatures/insects/models/insects.glb"
const CARCASS := "res://creatures/insects/models/carcass.glb"
const SHADER := preload("res://creatures/insects/insect.gdshader")
## The objects in the model, by kind.
const NAMES := ["moth", "fly", "dragonfly"]
## The parts, by material, as the shader numbers them.
const PARTS := {"body": 0, "fuzz": 1, "abdomen": 2, "eye": 3, "antenna": 4, "leg": 5, "wing": 6, "hindwing": 7, "tail": 8}

## How each kind's wings are hinged and held (the shader's uniforms).
const WINGS := {
	Kind.MOTH: {"hinge_fore": Vector3(0.045, 0.035, 0.06), "hinge_hind": Vector3(0.045, 0.028, 0.0),
		"rest_lift": 0.0, "rest_sweep": 0.0, "beat_lift": 1.05, "beat_middle": 0.3, "beat_sweep": 0.18,
		"hind_lag": 0.04, "blur": 0.3, "clear": 1.0, "wrap": 0.85},
	Kind.FLY: {"hinge_fore": Vector3(0.045, 0.08, 0.06), "hinge_hind": Vector3(0.045, 0.08, 0.06),
		"rest_lift": 0.1, "rest_sweep": 1.15, "beat_lift": 0.95, "beat_middle": 0.15, "beat_sweep": 0.45,
		"hind_lag": 0.0, "blur": 0.72, "clear": 0.32},
	Kind.DRAGONFLY: {"hinge_fore": Vector3(0.02, 0.05, 0.24), "hinge_hind": Vector3(0.02, 0.046, 0.15),
		"rest_lift": -0.07, "rest_sweep": 0.0, "beat_lift": 0.55, "beat_middle": 0.08, "beat_sweep": 0.12,
		"hind_lag": 0.25, "blur": 0.4, "clear": 0.42},
}

static var _meshes := {}
static var _materials := {}


## The mesh of an insect of `kind`, every part in one surface. One for everybody.
static func mesh(kind: Kind) -> ArrayMesh:
	if not _meshes.has(kind):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lay_out(tool, modelled(NAMES[kind]))
		var made := tool.commit()
		_meshes[kind] = made
	return _meshes[kind]


## The material an insect of `kind` is drawn in (one for everybody: it has no
## colours of its own to change; make your own from `SHADER` for that).
static func material(kind: Kind) -> ShaderMaterial:
	if not _materials.has(kind):
		var made := ShaderMaterial.new()
		made.shader = SHADER
		made.set_shader_parameter(&"kind", int(kind))
		var wings: Dictionary = WINGS[kind]
		for key: String in wings:
			made.set_shader_parameter(StringName(key), wings[key])
		_materials[kind] = made
	return _materials[kind]


## The mesh of a thing in the model, by the name it has there.
static func modelled(which: String) -> ArrayMesh:
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_error("InsectLook: no model at %s (build it with creatures/insects/tools/build_insects.py)" % MODEL)
		return ArrayMesh.new()
	var model := scene.instantiate()
	var found: ArrayMesh = null
	for piece: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if piece.name == which or piece.get_parent().name == which:
			found = piece.mesh as ArrayMesh
	model.free()
	if found == null:
		push_error("InsectLook: the model has nothing in it called %s" % which)
		return ArrayMesh.new()
	return found


## How many triangles an insect of `kind` is.
static func triangles(kind: Kind) -> int:
	var made := mesh(kind)
	return made.surface_get_array_len(0) / 3 if made.get_surface_count() > 0 else 0


# The model's insect as the shader wants it, added to `tool`: each point with
# its normal, what part it is (UV2.x), and where it lies (UV: on a wing, out
# from the middle and along the body; elsewhere, along the body and up).
static func _lay_out(tool: SurfaceTool, from: ArrayMesh) -> void:
	for surface in from.get_surface_count():
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
			var at := points[k]
			tool.set_uv2(Vector2(part, 0.0))
			tool.set_uv(Vector2(absf(at.x), at.z) if part >= 6 else Vector2(at.z, at.y))
			tool.set_normal(normals[k])
			tool.add_vertex(at)


## A dead deer lying on its side, bloated, torn open on its ribs (a prop for
## flies to gather on), in metres, in the model's own plain materials (hide,
## hide_pale, flesh, bone, hoof: shade it as the game shades things).
static func carcass() -> Node3D:
	var scene := load(CARCASS) as PackedScene
	if scene == null:
		push_error("InsectLook: no model at %s (build it with creatures/insects/tools/build_insects.py)" % CARCASS)
		return Node3D.new()
	return scene.instantiate() as Node3D
