class_name OctopusRig
extends Node3D
## Poses the octopus's skeleton (creatures/octopus/models/octopus.glb) in code,
## every frame, from what its Octopus (the parent) has worked out: where the
## body is and how it is turned, how the mantle hangs and breathes, the siphon,
## and where every joint of every arm is. No clips: every bone is set here.
##
## Every bone of the model rests with no turn, so a bone's pose is where its
## rest point has gone and how the part round it has turned. An arm's bones
## each run from one of its points to the next (`arms`: ARM_BONES + 1 points
## each, from the crown to the tip), turned so that the side its suckers are on
## faces the way given for it (`sides`: one a bone), and stretched along their
## length when the points are further apart than they rest (an octopus's arm
## stretches as it reaches) or shortened (an arm growing back is short).
##
## Two meshes share the one skeleton: the full model, drawn near, and the
## demade one (`octopus_lo`) beyond `far_from` (and always, with `low_poly`).

const PATH := "res://creatures/octopus/models/octopus.glb"
const ARMS := 8
const ARM_BONES := 20
const ARM_LENGTH := 8.4

## Use only the demade model. Set before it enters the tree.
var low_poly := false
## How far off the full model gives way to the demade one (metres).
var far_from := 45.0
var skeleton: Skeleton3D
var full: MeshInstance3D
var low: MeshInstance3D

## The rest pose, in the skeleton's space.
var body_rest := Vector3.ZERO
var head_rest := Vector3.ZERO
var mantle_rest := Vector3.ZERO
var siphon_rest := Vector3.ZERO
## Each arm's root (bone 0) at rest, and the way it runs out.
var roots_rest: Array[Vector3] = []
var dirs_rest: Array[Vector3] = []
## The length of one of an arm's bones at rest.
var segment := ARM_LENGTH / ARM_BONES

var _bone := {}
var _parent := PackedInt32Array()
var _global: Array[Transform3D] = []
var _arm_bones: Array[PackedInt32Array] = []


func _ready() -> void:
	var model: Node3D = (load(PATH) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	OctopusLook.dress(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "octopus_lo":
			low = mesh
		else:
			full = mesh
		# (its arms reach a long way from where it rests: never culled for that)
		mesh.custom_aabb = AABB(Vector3(-12.0, -4.0, -12.0), Vector3(24.0, 12.0, 24.0))
	if low_poly:
		full.visible = false
		low.visibility_range_begin = 0.0
	else:
		full.visibility_range_end = far_from
		full.visibility_range_end_margin = 4.0
		low.visibility_range_begin = far_from
		low.visibility_range_begin_margin = 4.0
	_read_rest()


func _read_rest() -> void:
	for b in skeleton.get_bone_count():
		_bone[skeleton.get_bone_name(b)] = b
		_parent.append(skeleton.get_bone_parent(b))
		_global.append(skeleton.get_bone_global_rest(b))
	body_rest = _at("body")
	head_rest = _at("head")
	mantle_rest = _at("mantle")
	siphon_rest = _at("siphon")
	for k in ARMS:
		var bones := PackedInt32Array()
		for j in ARM_BONES:
			bones.append(_bone["arm_%d_%d" % [k, j]])
		_arm_bones.append(bones)
		var root := _at("arm_%d_0" % k)
		roots_rest.append(root)
		dirs_rest.append((_at("arm_%d_1" % k) - root).normalized())
	segment = _at("arm_0_0").distance_to(_at("arm_0_1"))


func _at(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


## The meshes it draws (both of them, near and far), for instance uniforms.
func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if full:
		out.append(full)
	if low:
		out.append(low)
	return out


## An orthonormal frame with `along` as its Y and `side` (made square to it) as its X.
static func frame(along: Vector3, side: Vector3) -> Basis:
	var y := along.normalized()
	var x := side - y * side.dot(y)
	x = x.normalized() if x.length() > 0.0001 else y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.5:
		x = y.cross(Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## How a part that ran `rest_along` with its side `rest_side` at rest is turned now.
static func turned(along: Vector3, side: Vector3, rest_along: Vector3, rest_side: Vector3) -> Basis:
	return frame(along, side) * frame(rest_along, rest_side).inverse()


## A stretch by `amount` along `axis` (a unit vector), as a basis.
static func stretch_along(axis: Vector3, amount: float) -> Basis:
	var k := amount - 1.0
	return Basis(Vector3.RIGHT + axis * axis.x * k, Vector3.UP + axis * axis.y * k, Vector3.BACK + axis * axis.z * k)


## Where an arm's root is now, from the body's pose (all in the skeleton's space).
func root_of(k: int, body: Transform3D) -> Vector3:
	return body * (roots_rest[k] - body_rest)


## The way arm k runs out from its root now.
func out_of(k: int, body: Transform3D) -> Vector3:
	return (body.basis * dirs_rest[k]).normalized()


## Sets every bone. Everything is in the skeleton's space:
## - `body`: the crown's pose (where its rest point is, and how it is turned; a
##   scale in it squeezes the whole body, for a gap);
## - `mantle`: the mantle's turn on the head (pitching back or up, and a scale
##   for its breathing); `siphon`: the siphon's turn;
## - `arms`: each arm's points (ARM_BONES + 1, crown to tip); `sides`: for each
##   of an arm's bones, the way its suckers face.
func pose(body: Transform3D, mantle: Basis, siphon: Basis, arms: Array, sides: Array) -> void:
	if skeleton == null:
		return
	_put("body", body.basis, body.origin)
	var head := Transform3D(body.basis, body * (head_rest - body_rest))
	_put("head", head.basis, head.origin)
	_put("mantle", head.basis * mantle, head * (mantle_rest - head_rest))
	_put("siphon", head.basis * siphon, head * (siphon_rest - head_rest))
	for k in ARMS:
		var points: PackedVector3Array = arms[k]
		var faces: PackedVector3Array = sides[k]
		var rest_dir := dirs_rest[k]
		var bones := _arm_bones[k]
		for j in ARM_BONES:
			var a := points[j]
			var span := points[j + 1] - a
			var length := span.length()
			var along := span / length if length > 0.0001 else out_of(k, body)
			var turn := turned(along, faces[j], rest_dir, Vector3.DOWN)
			var amount := clampf(length / segment, 0.1, 3.0)
			_global[bones[j]] = Transform3D(turn * stretch_along(rest_dir, amount), a)
	# Each bone's pose against its parent's.
	for b in _global.size():
		var parent := _parent[b]
		var local := _global[b] if parent < 0 else _global[parent].affine_inverse() * _global[b]
		skeleton.set_bone_pose(b, local)


func _put(bone: String, basis: Basis, origin: Vector3) -> void:
	_global[_bone[bone]] = Transform3D(basis, origin)
