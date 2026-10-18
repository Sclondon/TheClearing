@tool
class_name RopeBridge
extends Node3D
## A bridge of planks hung on two ropes across a gap, from `from` to `to` (both
## in the world, where the planks meet the ledge at each end). It is simulated:
## the deck is a chain of points held apart, pinned at the ends, that sags under
## its own weight, dips under anyone standing on it (anything in the group
## `bridge_weights`), and sways and settles after. Each plank is a moving body,
## so whoever stands on it rides it. The hand ropes are drawn along the deck,
## a little sideways and up; there is nothing to stop a fall but care.

const POINTS := 15
## How much of its stretch each pass of the solver takes back.
const STIFF := 0.7

@export var from := Vector3.ZERO
@export var to := Vector3(6, 0, 0)
@export var width := 1.3
## How much longer the deck is than the gap (the sag).
@export var slack := 1.06
## The most it sags in the middle, metres, however long it is (a long one is
## strung tighter).
@export var most_sag := 1.5
## How heavy someone is, against the deck's own weight per point.
@export var weight := 9.0

var _points := PackedVector3Array()
var _before := PackedVector3Array()
var _planks: Array[AnimatableBody3D] = []
var _rails: Array[MeshInstance3D] = []
var _piece := 0.0
var _age := 0.0

static var _wood: StandardMaterial3D
static var _hemp: StandardMaterial3D


func _ready() -> void:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.36, 0.3, 0.22)
		_wood.roughness = 1.0
		_wood.metallic_specular = 0.0
		_hemp = StandardMaterial3D.new()
		_hemp.albedo_color = Color(0.42, 0.37, 0.27)
		_hemp.roughness = 1.0
		_hemp.metallic_specular = 0.0
	# (a shallow curve sags by about sqrt(3 / 8 * gap * extra length))
	var gap := from.distance_to(to)
	_piece = gap * minf(slack, 1.0 + 8.0 / 3.0 * pow(most_sag / maxf(gap, 0.01), 2.0)) / (POINTS - 1)
	# Start it hanging in a shallow curve, so it does not drop into place.
	for i in POINTS:
		var t := float(i) / (POINTS - 1)
		_points.append(from.lerp(to, t) + Vector3.DOWN * sin(t * PI) * minf(gap * 0.08, most_sag))
	_before = _points.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snappedf(0.01))
	for i in POINTS - 1:
		var plank := AnimatableBody3D.new()
		plank.top_level = true
		plank.sync_to_physics = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.12, _piece * 1.02)
		shape.shape = box
		plank.add_child(shape)
		var look := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		# (planks a little apart, each a little different)
		mesh.size = Vector3(width * rng.randf_range(0.92, 1.0), 0.07, _piece * 0.82)
		look.mesh = mesh
		look.material_override = _wood
		look.rotation.y = rng.randf_range(-0.04, 0.04)
		plank.add_child(look)
		add_child(plank)
		_planks.append(plank)
	for side in 4:
		for i in POINTS - 1:
			var rail := MeshInstance3D.new()
			var line := CylinderMesh.new()
			line.top_radius = 0.025
			line.bottom_radius = 0.025
			line.height = 1.0
			line.radial_segments = 5
			line.rings = 1
			rail.mesh = line
			rail.material_override = _hemp
			rail.top_level = true
			add_child(rail)
			_rails.append(rail)
	_lay()


func _physics_process(delta: float) -> void:
	# (in the editor it only hangs, as it was made)
	if Engine.is_editor_hint():
		return
	# Hanging still with nobody near, it rests, once settled (see Rope).
	_age += delta
	var middle := POINTS / 2
	if _age > Rope.SETTLE and (_points[middle] - _before[middle]).length_squared() < 0.000001 and not Rope.anyone_near(self, (from + to) * 0.5, from.distance_to(to) * 0.5 + Rope.WAKE):
		return
	var gravity := Vector3.DOWN * 9.8
	var pull := []
	pull.resize(POINTS)
	pull.fill(0.0)
	for body: Node in get_tree().get_nodes_in_group(&"bridge_weights"):
		var at: Vector3 = (body as Node3D).global_position
		var i := _nearest(at)
		if i >= 0:
			pull[i] += 1.0
	# A step of the chain: each point carries on as it was going, falls, and is
	# drawn down by anyone standing near it.
	for i in range(1, POINTS - 1):
		var p := _points[i]
		var moving := (p - _before[i]) * 0.985
		_before[i] = p
		_points[i] = p + moving + (gravity * (1.0 + float(pull[i]) * weight)) * delta * delta
	# Then held to its length, again and again, but not quite: the ropes give a
	# little, and most where the weight is.
	for k in 6:
		_points[0] = from
		_points[POINTS - 1] = to
		for i in POINTS - 1:
			var a := _points[i]
			var b := _points[i + 1]
			var gap := b - a
			var length := gap.length()
			if length < 0.0001:
				continue
			var fix := gap * (1.0 - _piece / length) * 0.5 * STIFF
			if i > 0:
				_points[i] = a + fix
			if i + 1 < POINTS - 1:
				_points[i + 1] = b - fix
	_lay()


## The point of the deck someone at `at` is standing on, or -1.
func _nearest(at: Vector3) -> int:
	var best := -1
	var best_distance := 0.9
	for i in range(1, POINTS - 1):
		var p := _points[i]
		var level := Vector2(at.x - p.x, at.z - p.z).length()
		if level < width and at.y > p.y - 0.3 and at.y < p.y + 0.8 and level < best_distance + width * 0.5:
			best = i
			best_distance = level
	return best


func _lay() -> void:
	var span := (to - from)
	var side := span.cross(Vector3.UP).normalized()
	for i in POINTS - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var along := (b - a).normalized()
		var up := side.cross(along).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		var basis := Basis(side, up, along).orthonormalized()
		_planks[i].global_transform = Transform3D(basis, (a + b) * 0.5)
	# Hand ropes (high, each side) and the ropes under the plank ends.
	var heights := [[0.5, 0.95], [-0.5, 0.95], [0.5, 0.0], [-0.5, 0.0]]
	for s in 4:
		for i in POINTS - 1:
			var lift: float = heights[s][1]
			var out: float = heights[s][0]
			var a: Vector3 = _points[i] + side * width * out + Vector3.UP * lift
			var b: Vector3 = _points[i + 1] + side * width * out + Vector3.UP * lift
			var along: Vector3 = b - a
			var rail := _rails[s * (POINTS - 1) + i]
			var y: Vector3 = along.normalized()
			var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
			rail.global_transform = Transform3D(Basis(x, y * along.length(), x.cross(y)), (a + b) * 0.5)
