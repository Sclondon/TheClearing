@tool
class_name GrappleSpots
extends Node3D
## The places in one square of the maze that a grappling hook is made to catch
## (MazePiece.Kind.ANCHOR, laid out by MazeFeatures from MazeStyle's "Grappling
## hook spots"): iron rings hanging from the ends of stone corbels up a wall and
## from the lips of ledges, iron hooks driven into the walls, and old iron pipes
## sticking out of them. Drawn as one MultiMesh for each look, and doing nothing
## at all after that: no processing. The hook (GrappleHook.find_target) finds the
## squares near him with NearIndex (the group GROUP) and looks through only
## their spots.
##
## Each spot is a transform: its origin is where the hook bites (and its rope
## hangs from), its +Z the way out of the wall it is on.

enum Look {
	RING, ## An iron ring hanging from a staple, against a face: the hook bites in its top.
	HOOK, ## An iron hook driven into a wall, bent up at its end.
	PIPE, ## An iron pipe sticking out of a wall, the hook caught over its end.
}

const GROUP := &"grapple_spot_sets"
## How far out from the face it hangs from a ring's top is (on the eye of its
## staple): far enough that the hook thrown from below comes up past the edge
## of what it hangs from.
const RING_OUT := 0.1
## Past this they are lost in the mist (as the vines are).
const SEEN := 130.0
## What they are made of: rusty iron, a shade warmer and lighter than the concrete,
## so that from below they can be picked out against it.
const IRON := Color(0.26, 0.15, 0.1)

static var _meshes := {}
static var _material: Material

## Where each spot's hook bites, in the world, and its look.
var points := PackedVector3Array()
var looks := PackedInt32Array()
var _turns: Array[Basis] = []
var _middle := Vector3.ZERO
var _spread := 0.0


## Adds a spot (before this goes into the tree): at `where` (its +Z out of the wall), as `look`.
func add(where: Transform3D, look: int) -> void:
	points.append(where.origin)
	looks.append(look)
	_turns.append(where.basis.orthonormalized())


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	if points.is_empty():
		return
	_middle = (lo + hi) * 0.5
	_spread = Vector2(hi.x - lo.x, hi.z - lo.z).length() * 0.5 + 0.5
	for look: int in Look.values():
		var count := 0
		for each in looks:
			if each == look:
				count += 1
		if count == 0:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh_of(look)
		multi.instance_count = count
		var k := 0
		for i in points.size():
			if looks[i] == look:
				multi.set_instance_transform(k, Transform3D(_turns[i], points[i]))
				k += 1
		var shown := MultiMeshInstance3D.new()
		shown.multimesh = multi
		shown.material_override = material()
		shown.top_level = true
		shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shown.visibility_range_end = 0.0 if Engine.is_editor_hint() else SEEN
		add_child(shown)


## Where the spots are across the ground, for NearIndex: their middle, and how far they spread from it.
func near_spot() -> Vector4:
	return Vector4(_middle.x, _middle.y, _middle.z, _spread)


## The way out of the wall the spot `index` is on.
func out_of(index: int) -> Vector3:
	return _turns[index].z


static func material() -> Material:
	if _material == null:
		if Engine.is_editor_hint():
			var plain := StandardMaterial3D.new()
			plain.albedo_color = IRON
			plain.roughness = 0.8
			_material = plain
		else:
			_material = Toon.surface(IRON)
	return _material


## The mesh of a look, in the spot's own space (its origin where the hook bites,
## +Z out of the wall).
static func mesh_of(look: int) -> Mesh:
	if _meshes.has(look):
		return _meshes[look]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match look:
		Look.RING:
			# (a ring, flat against the face, hung from a staple let into it)
			var hoop := TorusMesh.new()
			hoop.inner_radius = 0.15
			hoop.outer_radius = 0.215
			hoop.rings = 14
			hoop.ring_segments = 6
			tool.append_from(hoop, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -0.18, 0.0)))
			_bar(tool, Vector3(0.0, 0.01, -RING_OUT - 0.02), Vector3(0.0, 0.01, 0.0), 0.03)
			_bar(tool, Vector3(-0.08, 0.01, -RING_OUT + 0.01), Vector3(0.08, 0.01, -RING_OUT + 0.01), 0.04)
		Look.HOOK:
			# (a shank out of the wall, bent up at its end into a crook)
			_bar(tool, Vector3(0.0, -0.05, -0.55), Vector3(0.0, -0.05, 0.0), 0.05)
			_bar(tool, Vector3(0.0, -0.08, 0.0), Vector3(0.0, 0.2, 0.06), 0.045)
			_bar(tool, Vector3(-0.12, -0.05, -0.55), Vector3(0.12, -0.05, -0.55), 0.06)
		Look.PIPE:
			# (a length of pipe out of the wall, a flange where it comes out and a lip on its end)
			_bar(tool, Vector3(0.0, -0.12, -0.95), Vector3(0.0, -0.12, 0.0), 0.12)
			_bar(tool, Vector3(0.0, -0.12, -0.95), Vector3(0.0, -0.12, -0.88), 0.22)
			_bar(tool, Vector3(0.0, -0.12, -0.07), Vector3(0.0, -0.12, 0.02), 0.15)
	tool.generate_normals()
	var mesh := tool.commit()
	_meshes[look] = mesh
	return mesh


## A round bar from `a` to `b`, `radius` thick.
static func _bar(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = a.distance_to(b)
	rod.radial_segments = 8
	rod.rings = 1
	var up := (b - a).normalized()
	var across := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	tool.append_from(rod, 0, Transform3D(Basis(across, up, across.cross(up)), (a + b) * 0.5))
