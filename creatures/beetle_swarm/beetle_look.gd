class_name BeetleLook
## What the beetles of a swarm look like: two kinds, each a small mesh a unit
## long facing +Z, to be drawn a few hundred at a time as one MultiMesh
## (BeetleSwarm).
##
## - The ground beetle (GROUND), after the violet ground beetle, Carabus
##   violaceus: long oval wing cases with a flattened margin, a heart-shaped
##   shield over the thorax, a narrow waist, a small head with jaws, long
##   running legs and long feelers.
## - The dor beetle (DOR), after Geotrupes: squat and domed, short strong legs
##   (Outside's scarab with its toothed head shield rounded off).
##
## Both are glossy black with an oily sheen (`beetle.gdshader`): the overcast
## sky mirrored in a hard-edged pale band along the shell, the colours of an oil
## film round its edges (each beetle starts somewhere else on their round), and
## one hard light on it. They are a Blender model, `models/beetles.glb`, built
## by `tools/build_beetles.py` (which says what to mind in changing it). Their
## six legs are moved in the shader, from what each point of the model says of
## its leg; both kinds are in the one mesh, and each beetle shows only its own
## (see the shader), so a swarm of both is still one draw.

enum Kind { GROUND, DOR }

const MODEL := "res://creatures/beetle_swarm/models/beetles.glb"
const SHADER := preload("res://creatures/beetle_swarm/beetle.gdshader")
## The objects in the model, by kind.
const NAMES := ["ground_beetle", "dor_beetle"]

static var _mesh: ArrayMesh


## Both beetles, legs and all, in one surface in the material that moves them. One for everybody.
static func mesh() -> ArrayMesh:
	if _mesh == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for kind in NAMES.size():
			_lay_out(tool, modelled(NAMES[kind]), kind)
		tool.index()
		_mesh = tool.commit()
		_mesh.surface_set_material(0, material())
	return _mesh


## The material a beetle is drawn in (a new one: its colours are uniforms).
static func material() -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = SHADER
	return made


## The mesh of a thing in the model, by the name it has there.
static func modelled(which: String) -> ArrayMesh:
	var model := (load(MODEL) as PackedScene).instantiate()
	var part := model.find_child(which, true, false) as MeshInstance3D
	var found := part.mesh as ArrayMesh if part else null
	model.free()
	if found == null:
		push_error("The beetles' model has nothing in it called %s" % which)
		return ArrayMesh.new()
	return found


## How many triangles a beetle of each kind has.
static func triangles(kind: int) -> int:
	var made := modelled(NAMES[kind])
	var total := 0
	for surface in made.get_surface_count():
		var order: PackedInt32Array = made.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		total += order.size() / 3
	return total


# A beetle of the model as the shader wants it, added to `tool`: each point with
# its normal, what the model says of its leg (its first texture coordinate), and
# how much it shines and which kind it is (its second: the more it shines, the
# less rough the model's material is).
static func _lay_out(tool: SurfaceTool, from: ArrayMesh, kind: int) -> void:
	for surface in from.get_surface_count():
		var paint := from.surface_get_material(surface) as BaseMaterial3D
		var shine := snappedf(1.0 - paint.roughness, 0.01) if paint else 0.0
		var arrays := from.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var legs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := order.size() if not order.is_empty() else points.size()
		tool.set_uv2(Vector2(shine, kind))
		for i in count:
			var k := order[i] if not order.is_empty() else i
			var leg := legs[k] if k < legs.size() else Vector2.ZERO
			# (how far down the leg, in hundredths; and which three it steps with, 0 or a half)
			tool.set_uv(Vector2(snappedf(leg.x, 0.01), snappedf(leg.y, 0.5)))
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])
