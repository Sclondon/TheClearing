class_name ChickenBody
## What a chicken looks like: one mesh and its material (creatures/chicken/
## chicken.gdshader). ChickenFlock draws a whole flock with these as one
## MultiMesh, so a flock is one draw (and one more for its shadow) however many
## birds are in it.
##
## The mesh is a hen and a rooster at once, modelled in Blender
## (creatures/chicken/tools/build_chicken.py, models/chicken.glb, about 11000
## triangles for the two; each bird draws the parts that are its own and hides
## the rest). A hen standing, facing +Z, her feet on Y = 0, about half a metre to
## the top of her comb:
##
## - the core: a smooth body from the tail's root over the back and the deep
##   breast, up the neck to the skull and the bare red face, all under-down;
## - contour feathers over it in overlapping rows, each a small curved vane with
##   a raised shaft (longer, looser ones on the belly, tiny ones on the crown);
##   the neck's hackles (the rooster's a long cape over his shoulders), his
##   saddle lancets, the tail (a tent of broad feathers; his with great sickles
##   arching back over it);
## - the wings, folded on the flanks (primaries under, secondaries over them,
##   three rows of coverts over their roots), with their open shape too;
## - feathered drumsticks; scaly shanks from the hock (the ankle, bending
##   backwards) to the feet, his with spurs; three spread toes forward and one
##   back, jointed, with nails;
## - the comb (the hen's small, his tall and serrated), the wattles, the ear
##   lobes, a hooked beak and the lower mandible, nostrils, and the eyes.
##
## Nothing in the mesh moves by itself. Each vertex says which bone carries it
## and how much (CUSTOM1), and the shader poses those bones from each bird's
## pose (see chicken.gdshader). What each vertex is:
## - CUSTOM0: part (see the constants), feather region, how far along its
##   feather it is (0 at the root), a random number for its feather;
## - CUSTOM1: bone, how much the bone has it (against its parent: the neck
##   between body and head, the hock between drumstick and shank; for a toe, how
##   far along it is, for the curl), whose it is (0 both, 1 the hen's, 2 the
##   rooster's), and where across its feather it is (-1 to 1);
## - CUSTOM2 and CUSTOM3: where a wing's vertex is, and which way it faces,
##   with the wing spread (the model's shape key `open`);
## - UV2: where it is at rest (x, y), for the colours (its z is CUSTOM2.w).

## The bones, as the shader numbers them.
const BODY := 0
const HEAD_BONE := 1
const JAW := 2
const TAIL := 3
const WING_L := 4
const WING_R := 5
const THIGH_L := 6
const THIGH_R := 7
const SHANK_L := 8
const SHANK_R := 9
const TOES_L := 10
const TOES_R := 11

## The parts, as the shader colours them (CUSTOM0.r).
const FEATHER := 0.0
const DOWN := 1.0
const SKIN := 2.0
const LOBE := 3.0
const BEAK := 4.0
const LEG := 5.0
const CLAW := 6.0
const EYE := 7.0
const NOSTRIL := 8.0

## The joints at rest (keep to the model's and the shader's). +X is her left.
const NECK_BASE := Vector3(0.0, 0.37, 0.1)
const HEAD := Vector3(0.0, 0.49, 0.168)
const KNEE := Vector3(0.062, 0.245, 0.005)
const HOCK := Vector3(0.056, 0.122, -0.032)
const FOOT := Vector3(0.052, 0.026, 0.012)

const MODEL := "res://creatures/chicken/models/chicken.glb"
const MODEL_LO := "res://creatures/chicken/models/chicken_lo.glb"
const MATERIALS := {
	"feather": FEATHER, "down": DOWN, "comb": SKIN, "lobe": LOBE, "beak": BEAK, "leg": LEG,
	"claw": CLAW, "eye": EYE, "nostril": NOSTRIL,
}

static var _mesh: ArrayMesh
static var _mesh_low: ArrayMesh
static var _shader: Shader


## The mesh; `low`: the low-detail bird (models/chicken_lo.glb, about a third of
## the triangles: fewer, bigger feathers), for phones.
static func mesh(low := false) -> ArrayMesh:
	if low:
		if _mesh_low == null:
			_mesh_low = _make(MODEL_LO)
		return _mesh_low
	if _mesh == null:
		_mesh = _make(MODEL)
	return _mesh


## A material for a flock (each flock has its own: its birds' poses are its
## uniforms).
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://creatures/chicken/chicken.gdshader")
	var made := ShaderMaterial.new()
	made.shader = _shader
	return made


static func _make(path: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in 4:
		st.set_custom_format(c, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("ChickenBody: no model at %s (build it with creatures/chicken/tools/build_chicken.py)" % path)
		return st.commit()
	var root := scene.instantiate()
	for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_add_piece(st, piece, root)
	root.free()
	return st.commit()


# Which bone carries an object, from its name.
static func _bone_of(named: String) -> int:
	for prefix: String in ["wing_l", "wing_r", "thigh_l", "thigh_r", "shank_l", "spur_l", "shank_r", "spur_r", "toes_l", "claws_l", "toes_r", "claws_r", "tail", "jaw", "saddle"]:
		if named.begins_with(prefix):
			match prefix:
				"wing_l": return WING_L
				"wing_r": return WING_R
				"thigh_l": return THIGH_L
				"thigh_r": return THIGH_R
				"shank_l", "spur_l": return SHANK_L
				"shank_r", "spur_r": return SHANK_R
				"toes_l", "claws_l": return TOES_L
				"toes_r", "claws_r": return TOES_R
				"tail": return TAIL
				"jaw": return JAW
				"saddle": return BODY
	for prefix: String in ["comb", "wattle", "lobes", "eye", "beak", "nostril"]:
		if named.begins_with(prefix):
			return HEAD_BONE
	# (the body, its feathers and the hackles: the neck bends them between body and head)
	return -1


# How much of a point on the body or neck goes with the head: none below the
# neck's root, all from under the skull.
static func _neck_share(at: Vector3) -> float:
	var axis := HEAD - NECK_BASE
	var t := (at - NECK_BASE).dot(axis) / axis.length_squared()
	return smoothstep(0.05, 0.82, t)


# Whether a point of the body is the bare red skin of the face: round the eye,
# from the beak back, under the crown.
static func _face(at: Vector3) -> bool:
	var rel := at - HEAD
	if rel.z < -0.012 or rel.y > 0.014:
		return false
	return Vector3(rel.x * 0.9, rel.y + 0.004, rel.z - 0.012).length() < 0.031


static func _add_piece(st: SurfaceTool, piece: MeshInstance3D, root: Node) -> void:
	var place := Transform3D.IDENTITY
	var node: Node = piece
	while node != root and node != null:
		if node is Node3D:
			place = (node as Node3D).transform * place
		node = node.get_parent()
	var named := String(piece.name)
	var sex := 1.0 if named.ends_with("__h") else (2.0 if named.ends_with("__r") else 0.0)
	var bone := _bone_of(named)
	var mesh := piece.mesh
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		var part: float = MATERIALS.get(material.resource_name if material else "feather", FEATHER)
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var open_points := points
		var open_normals := normals
		var shapes := mesh.surface_get_blend_shape_arrays(surface)
		if not shapes.is_empty():
			open_points = (shapes[0] as Array)[Mesh.ARRAY_VERTEX]
			open_normals = (shapes[0] as Array)[Mesh.ARRAY_NORMAL] if (shapes[0] as Array)[Mesh.ARRAY_NORMAL] != null else normals
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if order.is_empty():
			order.resize(points.size())
			for i in points.size():
				order[i] = i
		for k in range(0, order.size(), 3):
			for j: int in [order[k], order[k + 1], order[k + 2]]:
				var at := place * points[j]
				var normal := (place.basis * normals[j]).normalized()
				var open_at := place * open_points[j]
				var open_normal := (place.basis * open_normals[j]).normalized()
				var uv := uvs[j] if not uvs.is_empty() else Vector2.ZERO
				# (V is flipped on the way out of Blender)
				uv.y = 1.0 - uv.y
				var uv2 := uv2s[j] if not uv2s.is_empty() else Vector2.ZERO
				uv2.y = 1.0 - uv2.y
				var what := part
				var b := bone
				var share := 1.0
				if b < 0:
					share = _neck_share(at)
					b = HEAD_BONE
					if part == DOWN and _face(at):
						what = SKIN
				elif b == SHANK_L or b == SHANK_R:
					# (the hock between the drumstick and the shank)
					share = smoothstep(HOCK.y + 0.012, HOCK.y - 0.016, at.y)
				elif b == TOES_L or b == TOES_R:
					var foot := Vector3(FOOT.x * signf(at.x), 0.0, FOOT.z)
					share = clampf(Vector2(at.x - foot.x, at.z - foot.z).length() / 0.065, 0.0, 1.0)
				var region := uv2.y * 8.0 - 0.5 if part == FEATHER else (4.0 if b == WING_L or b == WING_R else 0.0)
				var tag := uv2.x if part == FEATHER else 0.0
				var along := uv.y
				st.set_custom(0, Color(what, region, along, tag))
				st.set_custom(1, Color(b, share, sex, uv.x))
				st.set_custom(2, Color(open_at.x, open_at.y, open_at.z, at.z))
				st.set_custom(3, Color(open_normal.x, open_normal.y, open_normal.z, 0.0))
				st.set_uv(uv)
				st.set_uv2(Vector2(at.x, at.y))
				st.set_normal(normal)
				st.add_vertex(at)
