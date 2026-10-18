class_name RabbitWarren
extends Node3D
## A rabbits' warren: earth with holes dug into it, and the tunnels going in
## out of sight. A MOUND is a low hummock five metres across with five holes in
## its flanks, its top worn flat and grazed short; a BANK lies against the foot
## of a wall (its back on the wall's face, along its local X; its holes face
## +Z) with four holes in its slope. Before each hole a worn trench, an earthen
## lip round the mouth, and fresh earth fanned out round it.
##
## It knows nothing of rabbits: a game sends them in and out by its holes.
## `mouth(i)` is where a hole's mouth is (on the floor of the tunnel, in the
## world), `deep(i)` a point down its tunnel out of sight, `way_in(i)` the way
## in, `nearest_hole(point)` the nearest mouth. With `solid` on it is ground
## that can be walked over (its low-detail surface, on `collision_layer`), trench, lip and all.
##
## Drawn with RabbitLook's earth: one draw, nothing to load but the model.

enum Kind { MOUND, BANK }

@export var kind := Kind.MOUND
## The demade model (the same holes, a coarser surface). Set before it enters the tree.
@export var low_poly := false
## Walked over (its surface is ground). Set before it enters the tree.
@export var solid := true
@export_flags_3d_physics var collision_layer := 1
## Multiplies its colours.
@export var tint := Color.WHITE

var _mouths: Array[Vector3] = []
var _deeps: Array[Vector3] = []
var _model: Node3D
var _body: StaticBody3D


func _ready() -> void:
	_model = (load("res://creatures/rabbit/models/%s%s.glb" % ["warren_bank" if kind == Kind.BANK else "warren_mound", "_lo" if low_poly else ""]) as PackedScene).instantiate()
	add_child(_model)
	var material := RabbitLook.earth()
	if tint != Color.WHITE:
		material = material.duplicate() as ShaderMaterial
		material.set_shader_parameter(&"tint", tint)
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		part.material_override = material
		if solid and _body == null:
			_body = StaticBody3D.new()
			_body.name = "Ground"
			_body.collision_layer = collision_layer
			_body.collision_mask = 0
			var shape := CollisionShape3D.new()
			shape.shape = _ground_shape(kind)
			_body.add_child(shape)
			part.add_child(_body)
	for k in 16:
		var mouth := _model.find_child("hole_%d" % k, true, false) as Node3D
		var deep := _model.find_child("deep_%d" % k, true, false) as Node3D
		if mouth == null or deep == null:
			break
		_mouths.append(mouth.position)
		_deeps.append(deep.position)


static var _shapes := {}


## The ground of a warren of `kind`, to walk on: the low-detail model's surface,
## trench and lip and all (made once for each kind and shared).
static func _ground_shape(of: Kind) -> Shape3D:
	if _shapes.has(of):
		return _shapes[of]
	var low: Node = (load("res://creatures/rabbit/models/%s_lo.glb" % ("warren_bank" if of == Kind.BANK else "warren_mound")) as PackedScene).instantiate()
	var shape: Shape3D = null
	for part: MeshInstance3D in low.find_children("*", "MeshInstance3D", true, false):
		shape = part.mesh.create_trimesh_shape()
		break
	low.free()
	_shapes[of] = shape
	return shape


## How many holes it has.
func hole_count() -> int:
	return _mouths.size()


## The mouth of hole `i`, on its floor, in the world.
func mouth(i: int) -> Vector3:
	return global_transform * _mouths[i]


## A point down the tunnel of hole `i`, out of sight, in the world.
func deep(i: int) -> Vector3:
	return global_transform * _deeps[i]


## The way into hole `i` (flat, in the world).
func way_in(i: int) -> Vector3:
	var to := deep(i) - mouth(i)
	to.y = 0.0
	return to.normalized()


## The hole whose mouth is nearest `point` (-1 if it has none).
func nearest_hole(point: Vector3) -> int:
	var best := -1
	var near := INF
	for i in _mouths.size():
		var d := mouth(i).distance_squared_to(point)
		if d < near:
			near = d
			best = i
	return best


## About how far it reaches from its middle, metres.
func reach() -> float:
	return 1.8 if kind == Kind.BANK else 2.7
