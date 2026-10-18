class_name CorvidBody
## What a corvid looks like: one mesh per kind and the material that poses it
## (creatures/crow/corvid.gdshader). CorvidFlock draws a whole flock with these
## as one MultiMesh, so a flock is one draw (and one more for its shadow) however
## many birds are in it.
##
## The meshes are modelled in Blender (creatures/crow/tools/build_corvids.py):
## an American crow (models/crow.glb, about 11000 triangles, 0.45 m from bill to
## tail), a common raven (models/raven.glb, a third bigger, the wedge tail, the
## shaggy throat, the heavy bill) and a blue jay (creatures/blue_jay/models/
## blue_jay.glb, about 0.28 m, crested). Each has a low-detail twin (_lo.glb,
## about 3700 triangles). One builder makes all three, so they share an anatomy
## and the one shader poses them all:
##
## - the core (dark down) from the rump to the forehead, contour feathers over
##   it in overlapping rows, scapulars, small feathers flowing back over the head;
## - nasal bristles lying forward over the base of the bill; the raven's throat
##   hackles; the jay's crest;
## - twelve tail feathers, closed, with their coverts;
## - each wing in three pieces by the bone that carries it (arm, forearm, hand):
##   ten primaries (the outer ones emarginated, so the spread tip parts into
##   fingers), the alula and primary coverts on the hand, ten secondaries and
##   rows of coverts on the forearm, tertials at the elbow, and a core along
##   the leading edge. Modelled twice: folded on the flank (the mesh) and
##   spread level (its `open` shape);
## - feathered tibiae, scaled tarsi, three toes forward and a strong hind toe,
##   hooked nails; the bill, the lower mandible, the inside of the mouth, eyes.
##
## Nothing in the mesh moves by itself. Each vertex says which bone carries it
## and how much (CUSTOM1), and the shader poses those bones from each bird's
## pose. What each vertex is:
## - CUSTOM0: part (see the constants), feather region, how far along its
##   feather it is (0 at the root), a number for its feather (for a primary, how
##   far out it is, 0 to 1; for a tail feather, where across the tail);
## - CUSTOM1: bone, how much the bone has it against its parent (the neck
##   between body and head, the hock, a toe's curl, the wing's core at the elbow
##   and wrist), unused, and where across its feather it is (-1 to 1);
## - CUSTOM2 and CUSTOM3: where a wing's vertex is, and which way it faces,
##   with the wing spread (level once the body is pitched by `flight_pitch`);
## - UV2: where it is at rest (x, y), for the colours (its z is CUSTOM2.w).
##
## The joints the shader poses about come from the model too (its empties
## `joint_*`), so the script and the shader cannot disagree: `joints(kind)`.

enum Kind { CROW, RAVEN, BLUE_JAY }

## The bones, as the shader numbers them.
const BODY := 0
const HEAD_BONE := 1
const JAW := 2
const TAIL := 3
const ARM := 4
const FOREARM := 5
const HAND := 6
const THIGH := 7
const SHANK := 8
const TOES := 9

## The parts, as the shader colours them (CUSTOM0.r).
const FEATHER := 0.0
const DOWN := 1.0
const BEAK := 2.0
const MOUTH := 3.0
const LEG := 4.0
const CLAW := 5.0
const EYE := 6.0

const MODELS := {
	Kind.CROW: "res://creatures/crow/models/crow",
	Kind.RAVEN: "res://creatures/crow/models/raven",
	Kind.BLUE_JAY: "res://creatures/blue_jay/models/blue_jay",
}
const MATERIALS := {
	"feather": FEATHER, "down": DOWN, "beak": BEAK, "mouth": MOUTH, "leg": LEG, "claw": CLAW, "eye": EYE,
}
## The joints, by the names the model's empties have after `joint_`.
const JOINT_NAMES := ["hip", "knee", "hock", "foot", "neck", "head", "hinge", "crest", "tail", "shoulder", "elbow", "wrist", "tip", "beak_tip"]

static var _meshes := {}
static var _joints := {}
static var _shader: Shader


## The mesh of `kind`; `low`: the low-detail bird (about a third of the
## triangles: fewer, bigger feathers), for phones and for birds far off.
static func mesh(kind: Kind, low := false) -> ArrayMesh:
	var key := "%d/%s" % [kind, low]
	if not _meshes.has(key):
		_meshes[key] = _make(kind, String(MODELS[kind]) + ("_lo.glb" if low else ".glb"))
	return _meshes[key]


## Where the joints of `kind` are, as the model has them: {name: Vector3},
## and "flight_pitch" (a float: the pitch that levels its body to fly).
static func joints(kind: Kind) -> Dictionary:
	if not _joints.has(kind):
		mesh(kind)
	return _joints.get(kind, {})


## A material for a flock of `kind` (each flock has its own: its birds' poses
## are its uniforms).
static func material(kind: Kind) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://creatures/crow/corvid.gdshader")
	var made := ShaderMaterial.new()
	made.shader = _shader
	made.set_shader_parameter(&"kind", int(kind))
	var at := joints(kind)
	for name: String in JOINT_NAMES:
		if at.has(name):
			made.set_shader_parameter(StringName("j_" + name), at[name])
	made.set_shader_parameter(&"flight_pitch", float(at.get("flight_pitch", 0.3)))
	return made


static func _make(kind: Kind, path: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in 4:
		st.set_custom_format(c, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("CorvidBody: no model at %s (build it with creatures/crow/tools/build_corvids.py)" % path)
		return st.commit()
	var root := scene.instantiate()
	var at := {}
	for node: Node in root.find_children("*", "Node3D", true, false):
		var named := String(node.name)
		if named.begins_with("joint_"):
			at[named.substr(6)] = (node as Node3D).position
		elif named == "meta_flight_pitch":
			at["flight_pitch"] = (node as Node3D).position.x
	if not _joints.has(kind):
		_joints[kind] = at
	for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_add_piece(st, piece, root, at)
	root.free()
	return st.commit()


# Which bone carries an object, from its name (-1: the body, its feathers and
# the neck's, which the neck bends between body and head; -2: a wing's core,
# by where each vertex is).
static func _bone_of(named: String) -> int:
	if named.begins_with("wing_"):
		if named.ends_with("_arm"):
			return ARM
		if named.ends_with("_fore"):
			return FOREARM
		if named.ends_with("_hand"):
			return HAND
		return -2
	for pair: Array in [["thigh", THIGH], ["shank", SHANK], ["toes", TOES], ["claws", TOES], ["tail", TAIL], ["jaw", JAW], ["mouth", JAW]]:
		if named.begins_with(pair[0]):
			return pair[1]
	for prefix: String in ["eye", "beak", "bristles", "crest"]:
		if named.begins_with(prefix):
			return HEAD_BONE
	return -1


# How much of a point on the body or neck goes with the head: none below the
# neck's root, all from under the skull.
static func _neck_share(point: Vector3, at: Dictionary) -> float:
	var base: Vector3 = at.get("neck", Vector3.ZERO)
	var axis: Vector3 = at.get("head", Vector3.UP) - base
	var t := (point - base).dot(axis) / maxf(axis.length_squared(), 0.000001)
	return smoothstep(0.0, 0.8, t)


static func _add_piece(st: SurfaceTool, piece: MeshInstance3D, root: Node, at: Dictionary) -> void:
	var place := Transform3D.IDENTITY
	var node: Node = piece
	while node != root and node != null:
		if node is Node3D:
			place = (node as Node3D).transform * place
		node = node.get_parent()
	var named := String(piece.name)
	var bone := _bone_of(named)
	var mesh := piece.mesh
	var shoulder: Vector3 = at.get("shoulder", Vector3.ZERO)
	var pitch: float = at.get("flight_pitch", 0.3)
	var elbow_x: float = (at.get("elbow", Vector3.ZERO) as Vector3).x
	var wrist_x: float = (at.get("wrist", Vector3.ZERO) as Vector3).x
	var hock: Vector3 = at.get("hock", Vector3.ZERO)
	var foot: Vector3 = at.get("foot", Vector3.ZERO)
	var reach := (at.get("knee", Vector3.ZERO) as Vector3).distance_to(foot)
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		# (Blender may number a material: "leg.001")
		var part: float = MATERIALS.get(material.resource_name.get_slice(".", 0) if material else "feather", FEATHER)
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
				var point := place * points[j]
				var normal := (place.basis * normals[j]).normalized()
				var open_at := place * open_points[j]
				var open_normal := (place.basis * open_normals[j]).normalized()
				var uv := uvs[j] if not uvs.is_empty() else Vector2.ZERO
				# (V is flipped on the way out of Blender)
				uv.y = 1.0 - uv.y
				var uv2 := uv2s[j] if not uv2s.is_empty() else Vector2.ZERO
				uv2.y = 1.0 - uv2.y
				var b := bone
				var share := 1.0
				if b == -1:
					share = _neck_share(point, at)
					b = HEAD_BONE
				elif b == -2:
					# (the wing's core: by how far out it is, spread and levelled;
					# shared with the bone inside it across the elbow and the wrist)
					var level := (open_at - Vector3(shoulder.x * signf(open_at.x), shoulder.y, shoulder.z)).rotated(Vector3.RIGHT, pitch)
					var out := absf(level.x)
					if out < elbow_x:
						b = ARM
					elif out < wrist_x:
						b = FOREARM
						share = smoothstep(elbow_x - 0.012, elbow_x + 0.012, out)
					else:
						b = HAND
						share = smoothstep(wrist_x - 0.01, wrist_x + 0.012, out)
				elif b == SHANK:
					# (the hock between the tibia and the tarsus)
					share = smoothstep(hock.y + 0.004, hock.y - 0.006, point.y)
				elif b == TOES:
					var middle := Vector3(foot.x * signf(point.x), 0.0, foot.z)
					share = clampf(Vector2(point.x - middle.x, point.z - middle.z).length() / maxf(reach * 0.45, 0.001), 0.0, 1.0)
				var region := uv2.y * 16.0 - 0.5 if part == FEATHER else 0.0
				var tag := uv2.x if part == FEATHER else 0.0
				st.set_custom(0, Color(part, region, uv.y, tag))
				st.set_custom(1, Color(b, share, 0.0, uv.x))
				st.set_custom(2, Color(open_at.x, open_at.y, open_at.z, point.z))
				st.set_custom(3, Color(open_normal.x, open_normal.y, open_normal.z, 0.0))
				st.set_uv(uv)
				st.set_uv2(Vector2(point.x, point.y))
				st.set_normal(normal)
				st.add_vertex(point)
