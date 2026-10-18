@tool
class_name SewerPipe
extends Node3D
## A sewer pipe through a wall, high up: a concrete tube just big enough for a
## boy to crawl through ducked, standing out of both faces of the wall with a
## flange round it at each, and water dripping now and then from both mouths.
## Its origin is the middle of the flat floor inside it; it runs along its z,
## `length` metres from mouth to mouth. The wall it goes through has a hole for
## it (HOLE wide and high from the floor), which the flanges hide the edges of.

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
	for child in get_children(true):
		remove_child(child)
		child.queue_free()
	_materials()
	var middle := Vector3(0.0, RISE, 0.0)
	var outer := BORE * 0.5 + SIDE
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(tool, middle, outer, -length * 0.5, length * 0.5, false)
	_tube(tool, middle, BORE * 0.5, -length * 0.5, length * 0.5, true)
	for end: float in [-length * 0.5, length * 0.5]:
		_ring(tool, middle, BORE * 0.5, outer, end, signf(end))
	for face: float in [-wall * 0.5, wall * 0.5]:
		# (a flange against each face of the wall, hiding the edges of the hole)
		var out := face + signf(face) * FLANGE.y
		_tube(tool, middle, FLANGE.x, minf(face, out), maxf(face, out), false)
		_ring(tool, middle, outer, FLANGE.x, out, signf(face))
	var tube := MeshInstance3D.new()
	tube.name = "Tube"
	tube.mesh = tool.commit()
	tube.material_override = _concrete
	add_child(tube, false, Node.INTERNAL_MODE_BACK)
	# The sludge along its floor.
	var floor_wide := 2.0 * sqrt(BORE * BORE * 0.25 - RISE * RISE)
	var sludge := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(floor_wide, length)
	sludge.mesh = plane
	sludge.position.y = 0.01
	sludge.material_override = _sludge
	add_child(sludge, false, Node.INTERNAL_MODE_BACK)
	# Something to crawl on and bump into where it stands out of the wall (in the
	# wall, the hole's sides do).
	var body := StaticBody3D.new()
	for end: float in [-1.0, 1.0]:
		var out := (length - wall) * 0.5
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
	# Water dripping from the lip of each mouth, now and then.
	for end: float in [-1.0, 1.0]:
		var drips := CPUParticles3D.new()
		drips.position = Vector3(0.0, 0.02, end * (length * 0.5 - 0.05))
		drips.amount = 3
		drips.lifetime = 3.2
		drips.randomness = 0.9
		drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		drips.emission_box_extents = Vector3(0.25, 0.0, 0.02)
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
		drips.visibility_range_end = 70.0
		add_child(drips, false, Node.INTERNAL_MODE_BACK)


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
	_sludge.albedo_color = Color(0.1, 0.11, 0.08)
	_sludge.roughness = 0.25
	_drop = StandardMaterial3D.new()
	_drop.albedo_color = Color(0.6, 0.66, 0.66, 0.7)
	_drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop.roughness = 0.1
	_drop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
