@tool
class_name SewerPipe
extends Node3D
## A sewer pipe through a wall, high up: a concrete tube just big enough for a
## boy to crawl through ducked, standing out of both faces of the wall with a
## flange round it at each, and water dripping now and then from both mouths.
## Its origin is the middle of the flat floor inside it; it runs along its z,
## `length` metres from mouth to mouth. The wall it goes through has a hole for
## it (HOLE wide and high from the floor), which the flanges hide the edges of.
##
## A pipe that stops at the wall's faces (`length` no more than `wall`: as the maze
## lays them out since 2026-10-19) has modelled mouths instead of flanges: a bell of
## concrete at each face on a lip jutting out under it (SewerMouth, drawn with the
## walls from the platforms), the slime running out over the lip and the water
## dripping off its front.

## How wide and high the hole through the wall is, from the pipe's floor.
const HOLE := Vector2(1.0, 1.0)
## How wide the tube is inside, how thick its sides, and how far its middle is
## over its floor (the floor is a flat of sludge across its bottom).
const BORE := 1.15
const SIDE := 0.12
const RISE := 0.455
## How far out the flanges reach from the middle, and how thick they are.
const FLANGE := Vector2(1.0, 0.22)
const AROUND := 18

## From mouth to mouth, metres.
@export var length := 16.0:
	set(value):
		length = value
		if is_inside_tree():
			_build()
## How thick the wall is that it goes through (where the flanges are).
@export var wall := 12.0:
	set(value):
		wall = value
		if is_inside_tree():
			_build()

static var _concrete: StandardMaterial3D
static var _sludge: StandardMaterial3D
static var _drop: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	_drips.clear()
	for child in get_children(true):
		remove_child(child)
		child.queue_free()
	_materials()
	var mouths := has_mouths()
	var tube := MeshInstance3D.new()
	tube.name = "Tube"
	tube.mesh = _tube_mesh(length, wall)
	tube.material_override = _concrete
	add_child(tube, false, Node.INTERNAL_MODE_BACK)
	# The sludge along its floor (and, out of a modelled mouth, the slime it leaves
	# down the lip under it).
	var sludge := MeshInstance3D.new()
	sludge.mesh = _sludge_mesh(length, wall)
	sludge.material_override = _sludge
	add_child(sludge, false, Node.INTERNAL_MODE_BACK)
	# Something to crawl on and bump into where it stands out of the wall (in the
	# wall, the hole's sides do; at a modelled mouth, the mouth's own: SewerMouth).
	var body := StaticBody3D.new()
	var out := (length - wall) * 0.5
	for end: float in ([] if mouths else [-1.0, 1.0]):
		var at := end * (wall + out) * 0.5
		for part: Array in [[Vector3(0.0, -0.1, at), Vector3(HOLE.x, 0.2, out)],
				[Vector3(0.0, HOLE.y + 0.1, at), Vector3(HOLE.x, 0.2, out)],
				[Vector3(-HOLE.x * 0.5 - 0.1, HOLE.y * 0.5, at), Vector3(0.2, HOLE.y, out)],
				[Vector3(HOLE.x * 0.5 + 0.1, HOLE.y * 0.5, at), Vector3(0.2, HOLE.y, out)]]:
			var shape := BoxShape3D.new()
			shape.size = part[1]
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = part[0]
			body.add_child(collider)
	add_child(body, false, Node.INTERNAL_MODE_BACK)
	if Engine.is_editor_hint():
		return
	# Water dripping now and then from the lip of each mouth (a modelled mouth's
	# from the front of the lip under it, where the slime runs over).
	for end: float in [-1.0, 1.0]:
		var drips := CPUParticles3D.new()
		if mouths:
			drips.position = Vector3(0.0, -SewerMouth.NOSE - 0.05, end * (wall * 0.5 + MazeFeatures.PLATFORM.x + 0.04))
		else:
			drips.position = Vector3(0.0, 0.02, end * (length * 0.5 - 0.05))
		drips.amount = 3
		drips.lifetime = 3.2
		drips.randomness = 0.9
		drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		drips.emission_box_extents = Vector3(0.12 if mouths else 0.25, 0.0, 0.02)
		drips.direction = Vector3(0.0, -1.0, end * 0.3)
		drips.spread = 4.0
		drips.initial_velocity_min = 0.2
		drips.initial_velocity_max = 0.5
		drips.gravity = Vector3(0.0, -9.8, 0.0)
		drips.scale_amount_min = 0.7
		drips.scale_amount_max = 1.3
		var drop := SphereMesh.new()
		drop.radius = 0.035
		drop.height = 0.12
		drop.radial_segments = 6
		drop.rings = 3
		drop.material = _drop
		drips.mesh = drop
		drips.emitting = false
		drips.visible = false
		add_child(drips, false, Node.INTERNAL_MODE_BACK)
		_drips.append(drips)
	set_process(true)


## Whether its mouths are modelled (SewerMouth, drawn with the walls from the
## platforms under them): it stops at the wall's faces, with no flanges.
func has_mouths() -> bool:
	return length <= wall + 0.01


## The tube's mesh for a pipe `long` from mouth to mouth through a wall `thick`,
## made once for each and shared (there may be hundreds of pipes).
static var _tubes := {}


static func _tube_mesh(long: float, thick: float) -> ArrayMesh:
	var key := Vector2(snappedf(long, 0.01), snappedf(thick, 0.01))
	if _tubes.has(key):
		return _tubes[key]
	var middle := Vector3(0.0, RISE, 0.0)
	var outer := BORE * 0.5 + SIDE
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(tool, middle, outer, -long * 0.5, long * 0.5, false)
	_tube(tool, middle, BORE * 0.5, -long * 0.5, long * 0.5, true)
	if long > thick + 0.01:
		for end: float in [-long * 0.5, long * 0.5]:
			_ring(tool, middle, BORE * 0.5, outer, end, signf(end))
		for face: float in [-thick * 0.5, thick * 0.5]:
			# (a flange against each face of the wall, hiding the edges of the hole)
			var out := face + signf(face) * FLANGE.y
			_tube(tool, middle, FLANGE.x, minf(face, out), maxf(face, out), false)
			_ring(tool, middle, outer, FLANGE.x, out, signf(face))
	_tubes[key] = tool.commit()
	return _tubes[key]


## The sludge along its floor, and out of each modelled mouth a tongue of slime
## over the floor of the bell and the lip, and over the lip's edge a little way
## down its front, where the water runs: dark and wet down its middle, mossy at
## its edges (vertex colours). Made once for each size and shared.
static var _sludges := {}


static func _sludge_mesh(long: float, thick: float) -> ArrayMesh:
	var key := Vector2(snappedf(long, 0.01), snappedf(thick, 0.01))
	if _sludges.has(key):
		return _sludges[key]
	var floor_wide := 2.0 * sqrt(BORE * BORE * 0.25 - RISE * RISE)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet := Color(0.1, 0.11, 0.08)
	var moss := Color(0.13, 0.16, 0.07)
	_strip(tool, [[Vector3(0.0, 0.01, -long * 0.5), floor_wide * 0.5, Vector3.UP], [Vector3(0.0, 0.01, long * 0.5), floor_wide * 0.5, Vector3.UP]], wet)
	if long <= thick + 0.01:
		var deep := MazeFeatures.PLATFORM.x
		var nose := SewerMouth.NOSE
		for end: float in [-1.0, 1.0]:
			var from := thick * 0.5
			# ([where along its middle, how wide each way, the way it faces], from the wall out)
			var line: Array = []
			for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var o := from + (deep - nose) * t
				# (wandering a little as it runs, and narrowing to the lip)
				line.append([Vector3(sin(t * 5.0 + end) * 0.07, 0.012, end * o), lerpf(floor_wide * 0.5, 0.1, t) + sin(t * 7.0 + 1.0) * 0.025, Vector3.UP])
			for d: float in [60.0, 30.0, 0.0]:
				var a := deg_to_rad(d)
				var n := Vector3(0.0, sin(a), end * cos(a))
				line.append([Vector3(0.0, -nose, end * (from + deep - nose)) + n * (nose + 0.015), 0.09, n])
			line.append([Vector3(0.0, -0.32, end * (from + deep + 0.015)), 0.05, Vector3(0.0, 0.0, end)])
			# (the mossy edge first, a little under the wet middle)
			var fringe: Array = []
			for point: Array in line:
				fringe.append([point[0] - point[2] * 0.004, float(point[1]) + 0.05, point[2]])
			_strip(tool, fringe, moss)
			_strip(tool, line, wet)
	_sludges[key] = tool.commit()
	return _sludges[key]


## A strip along a line of [middle, how wide each way, the way it faces] points, its
## sides square across the pipe (x), coloured `colour`.
static func _strip(tool: SurfaceTool, line: Array, colour: Color) -> void:
	for k in line.size() - 1:
		var a: Array = line[k]
		var b: Array = line[k + 1]
		var corners := [[a[0] - Vector3(a[1], 0, 0), a[2]], [a[0] + Vector3(a[1], 0, 0), a[2]],
			[b[0] + Vector3(b[1], 0, 0), b[2]], [b[0] - Vector3(b[1], 0, 0), b[2]]]
		var n: Vector3 = (a[2] as Vector3) + (b[2] as Vector3)
		var p0: Vector3 = corners[0][0]
		var face := ((corners[1][0] as Vector3) - p0).cross((corners[2][0] as Vector3) - p0)
		# (wound to face the way it faces: Godot's front faces are the ones whose
		# (q - p) x (r - p) points away from the viewer)
		var order := [0, 2, 1, 0, 3, 2] if face.dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
		for i: int in order:
			tool.set_color(colour)
			tool.set_normal(corners[i][1])
			tool.add_vertex(corners[i][0])


## The side of a tube round `middle`, `radius` round, from z `from` to `to`;
## facing in (`inward`) or out.
static func _tube(tool: SurfaceTool, middle: Vector3, radius: float, from: float, to: float, inward: bool) -> void:
	for k in AROUND:
		var a := TAU * k / AROUND
		var b := TAU * (k + 1) / AROUND
		var da := Vector3(cos(a), sin(a), 0.0)
		var db := Vector3(cos(b), sin(b), 0.0)
		var p0 := middle + da * radius + Vector3(0, 0, from)
		var p1 := middle + db * radius + Vector3(0, 0, from)
		var p2 := middle + db * radius + Vector3(0, 0, to)
		var p3 := middle + da * radius + Vector3(0, 0, to)
		var na := -da if inward else da
		var nb := -db if inward else db
		var quad := [[p0, na], [p1, nb], [p2, nb], [p0, na], [p2, nb], [p3, na]] if inward else [[p0, na], [p2, nb], [p1, nb], [p0, na], [p3, na], [p2, nb]]
		for v: Array in quad:
			tool.set_normal(v[1])
			tool.set_uv(Vector2(float(k) / AROUND, (v[0] as Vector3).z))
			tool.add_vertex(v[0])


## A flat ring at z `at`, from `inner` to `outer` round `middle`, facing `way` along z.
static func _ring(tool: SurfaceTool, middle: Vector3, inner: float, outer: float, at: float, way: float) -> void:
	var normal := Vector3(0.0, 0.0, way)
	for k in AROUND:
		var a := TAU * k / AROUND
		var b := TAU * (k + 1) / AROUND
		var i0 := middle + Vector3(cos(a), sin(a), 0.0) * inner + Vector3(0, 0, at)
		var i1 := middle + Vector3(cos(b), sin(b), 0.0) * inner + Vector3(0, 0, at)
		var o0 := middle + Vector3(cos(a), sin(a), 0.0) * outer + Vector3(0, 0, at)
		var o1 := middle + Vector3(cos(b), sin(b), 0.0) * outer + Vector3(0, 0, at)
		var tris := [i0, o1, o0, i0, i1, o1] if way > 0.0 else [i0, o0, o1, i0, o1, i1]
		for p: Vector3 in tris:
			tool.set_normal(normal)
			tool.set_uv(Vector2(p.x, p.y))
			tool.add_vertex(p)


static func _materials() -> void:
	if _concrete:
		return
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.36, 0.34, 0.31)
	_concrete.roughness = 0.95
	# (drawn from inside and out alike)
	_concrete.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sludge = StandardMaterial3D.new()
	_sludge.albedo_color = Color.WHITE
	# (its colour is its vertices': the wet sludge, and moss at the edges of the slime out of a mouth)
	_sludge.vertex_color_use_as_albedo = true
	_sludge.roughness = 0.4
	_drop = StandardMaterial3D.new()
	_drop.albedo_color = Color(0.6, 0.66, 0.66, 0.7)
	_drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop.roughness = 0.1
	_drop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


# The drips, which only fall while the camera is near (each falling costs, even
# unseen), looked at now and then.
var _drips: Array[CPUParticles3D] = []
var _look_in := randf()
const DRIPS_SEEN := 80.0


func _process(delta: float) -> void:
	_look_in -= delta
	if _look_in > 0.0 or _drips.is_empty():
		return
	_look_in = 0.5
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and camera.global_position.distance_to(global_position) < DRIPS_SEEN
	for drips in _drips:
		if drips.emitting != near:
			drips.emitting = near
			drips.visible = near
