class_name RatLook
## What a rat looks like: a brown rat (Rattus norvegicus), a mesh in metres
## facing +Z, posed in its shader (rat.gdshader) and drawn as a MultiMesh, one
## rat or a few hundred at once. There are two: the rat in full (`mesh(false)`,
## about 1900 triangles: whiskers, toes, a jaw that opens) for a rat seen near,
## and a low one (`mesh(true)`, a couple of hundred) for a swarm and for rats
## further off. And the knot of a rat king's tails (`knot()`). They are a
## Blender model, `models/rat.glb` and `models/rat_lo.glb`, built by
## `tools/build_rats.py` (which says what each point of them tells the shader).
##
## Each rat drawn says in its custom data how it is posed (`custom`): how far
## through its stride and how fast it goes (the gait goes from a walk to a
## bound), how its back bends to the side, how far it is reared up, and whether
## its mouth is open, its tail bound into a rat king's knot or its head down to
## feed; and its own number (its shade, and the time its twitches keep).

const MODEL := "res://creatures/rats/models/rat.glb"
const MODEL_LO := "res://creatures/rats/models/rat_lo.glb"
const SHADER := preload("res://creatures/rats/rat.gdshader")

## What else a rat is doing (`custom`'s flags).
const MOUTH_OPEN := 1
const TAIL_KNOTTED := 2
const HEAD_DOWN := 4

## How long a rat is, nose to rump (m), and its tail.
const LENGTH := 0.25
const TAIL_LENGTH := 0.21

static var _meshes := {}
static var _knot: ArrayMesh
static var _material: ShaderMaterial


## The rat, in full or low, in the material that poses it. One of each for everybody.
static func mesh(low := false) -> ArrayMesh:
	if not _meshes.has(low):
		var made := modelled(MODEL_LO if low else MODEL, "rat_lo" if low else "rat")
		made.surface_set_material(0, material())
		_meshes[low] = made
	return _meshes[low]


## The knot of a rat king's tails, in the same material (it is not posed).
static func knot() -> ArrayMesh:
	if _knot == null:
		_knot = modelled(MODEL, "knot")
		_knot.surface_set_material(0, material())
	return _knot


## The material they are drawn in (one for all: its colours are uniforms).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## The mesh of a thing in a model, by the name it has there.
static func modelled(path: String, which: String) -> ArrayMesh:
	var model := (load(path) as PackedScene).instantiate()
	var part := model.find_child(which, true, false) as MeshInstance3D
	var found := part.mesh as ArrayMesh if part else null
	model.free()
	if found == null:
		push_error("The rats' model %s has nothing in it called %s" % [path, which])
		return ArrayMesh.new()
	return found


## How many triangles a mesh has.
static func triangles(of: Mesh) -> int:
	var total := 0
	for surface in of.get_surface_count():
		var arrays := of.surface_get_arrays(surface)
		var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		total += order.size() / 3 if not order.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## A rat's pose as its custom data: `stride` (whole strides), `go` how fast (0
## standing to 1 flat out), `bend` its back to the side (-1 to 1), `rear` how
## far it is reared up (0 to 1), `flags` (MOUTH_OPEN, TAIL_KNOTTED, HEAD_DOWN),
## and `own` its own number (0 to 1).
static func custom(stride: float, go: float, bend: float, rear: float, flags: int, own: float) -> Color:
	return Color(fposmod(stride, 8.0), roundf((clampf(bend, -1.0, 1.0) + 1.0) * 8.0) + clampf(go, 0.0, 0.99), float(flags) + clampf(rear, 0.0, 0.99), own)


## The same, written straight into a MultiMesh's buffer at `at` (its custom data: after the 12 of a transform).
static func write_custom(buffer: PackedFloat32Array, at: int, stride: float, go: float, bend: float, rear: float, flags: int, own: float) -> void:
	buffer[at + 12] = fposmod(stride, 8.0)
	buffer[at + 13] = roundf((clampf(bend, -1.0, 1.0) + 1.0) * 8.0) + clampf(go, 0.0, 0.99)
	buffer[at + 14] = float(flags) + clampf(rear, 0.0, 0.99)
	buffer[at + 15] = own


## How many strides a second a rat `size` long takes going at `speed` m/s
## (walking, about one body length a stride; flat out, a bound covers more).
static func stride_rate(speed: float, size := 1.0) -> float:
	var stride := LENGTH * size * lerpf(0.75, 1.6, clampf(speed / 3.0, 0.0, 1.0))
	return speed / maxf(stride, 0.01)
