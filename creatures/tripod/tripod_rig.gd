class_name TripodRig
extends Node3D
## Poses the tripod's skeleton (creatures/tripod/models/tripod.glb) in code,
## every frame, from what its Tripod (the parent) has worked out: where the
## body is and how it leans, how the hood is turned, where the eye looks,
## where the heat ray's arm reaches, where each foot is, and where the points
## of each tentacle are. No clips: every bone is set here.
##
## Every bone of the model rests upright with no turn, so a bone's pose is
## just where its rest point has gone and how the part round it has turned.
## The legs are long and flexible, many short bones each: a leg is laid along
## a smooth arch from its hip (leaving up and out) to its ankle (coming in from
## straight above), bowed just enough to be as long as the leg is, so that it
## coils up high when the foot is drawn in and runs out nearly straight when
## it reaches far. On that a spring at its middle lags behind the body and the
## foot and overshoots (a whippy sway), a ripple runs down it while it swings,
## and a landing makes it splay and wobble before it takes the weight. The
## foot is kept flat. The arm is two-bone IK
## from its shoulder (the elbow down and out) with the emitter pointing at
## what it aims at; a tentacle's bones each run from one of its points to the
## next, stretched along their length when the points are further apart than
## they rest.
##
## Two meshes share the one skeleton: the full model, drawn near, and the
## demade one (`tripod_lo`) beyond `far_from` (and always, with `low_poly`).

const PATH := "res://creatures/tripod/models/tripod.glb"
const LEGS := 3
const TENTACLES := 5
## The tentacle that reaches and grasps (it has claws).
const GRASPER := 4
## The emitter's length, and the way it points at rest (in the model).
const EMITTER_LENGTH := 3.8
const EMITTER_REST := Vector3(0.0, -0.3, 1.0)
## The great eye's lens looks this way at rest (in the model).
const EYE_REST := Vector3(0.0, -0.45, 1.0)
## The leg meets the top of the foot's pad this high over the sole.
const ANKLE_HEIGHT := 1.6
## Bones in each leg, hip to ankle.
const LEG_BONES := 12
## The leg's spring (how stiff, how damped) and how far it may swing off its arch (m).
const LEG_SPRING := 2.2
const LEG_DAMPING := 0.55
const LEG_SWAY := 9.0

## Use only the demade model. Set before it enters the tree.
var low_poly := false
## How far off the full model gives way to the demade one (metres, at scale 1).
var far_from := 150.0
## The materials, by name (see TripodLook.dress).
var materials := {}
var skeleton: Skeleton3D
var full: MeshInstance3D
var low: MeshInstance3D

# The rest pose, in the skeleton's space.
var body_rest := Vector3.ZERO
var head_rest := Vector3.ZERO
var eye_rest := Vector3.ZERO
var shoulder_rest := Vector3.ZERO
var elbow_rest := Vector3.ZERO
var wrist_rest := Vector3.ZERO
var hips_rest: Array[Vector3] = []
var feet_rest: Array[Vector3] = []
## Each leg's length, hip to ankle (m).
var leg_length: Array[float] = []
# Each leg's bones' rest directions, and the spring at its middle.
var _leg_rest_dirs: Array[PackedVector3Array] = []
var _mid: Array[Vector3] = []
var _mid_speed: Array[Vector3] = []
var _mid_ready: Array[bool] = []
var _time := 0.0
var roots_rest: Array[Vector3] = []
var segment_length: Array[float] = []
var upper_length := 7.0
var fore_length := 6.0

var _bone := {}
var _parent := PackedInt32Array()
var _global: Array[Transform3D] = []
var _leg_hinge: Array[Vector3] = []
var _arm_hinge := Vector3.LEFT


func _ready() -> void:
	var model: Node3D = (load(PATH) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = TripodLook.dress(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "tripod_lo":
			low = mesh
		else:
			full = mesh
		# (it moves a long way from where it rests: never culled for that)
		mesh.custom_aabb = AABB(Vector3(-70.0, -10.0, -70.0), Vector3(140.0, 90.0, 140.0))
	if low_poly:
		full.visible = false
	else:
		full.visibility_range_end = far_from
		full.visibility_range_end_margin = 10.0
		low.visibility_range_begin = far_from
		low.visibility_range_begin_margin = 10.0
	_read_rest()


func _read_rest() -> void:
	for b in skeleton.get_bone_count():
		_bone[skeleton.get_bone_name(b)] = b
		_parent.append(skeleton.get_bone_parent(b))
		_global.append(skeleton.get_bone_global_rest(b))
	body_rest = _at("body")
	head_rest = _at("head")
	eye_rest = _at("eye")
	shoulder_rest = _at("arm_upper")
	elbow_rest = _at("arm_fore")
	wrist_rest = _at("emitter")
	upper_length = shoulder_rest.distance_to(elbow_rest)
	fore_length = elbow_rest.distance_to(wrist_rest)
	_arm_hinge = _hinge(shoulder_rest, elbow_rest, wrist_rest, Vector3.LEFT)
	for i in LEGS:
		hips_rest.append(_at("leg_%d_0" % i))
		feet_rest.append(_at("foot_%d" % i))
		var dirs := PackedVector3Array()
		var length := 0.0
		for j in LEG_BONES:
			var a := _at("leg_%d_%d" % [i, j])
			var b := _at("leg_%d_%d" % [i, j + 1]) if j < LEG_BONES - 1 else feet_rest[i] + Vector3.UP * ANKLE_HEIGHT
			dirs.append(b - a)
			length += a.distance_to(b)
		_leg_rest_dirs.append(dirs)
		leg_length.append(length)
		var out := Vector3(feet_rest[i].x, 0.0, feet_rest[i].z).normalized()
		_leg_hinge.append(Vector3.UP.cross(out).normalized())
		_mid.append(Vector3.ZERO)
		_mid_speed.append(Vector3.ZERO)
		_mid_ready.append(false)
	for k in TENTACLES:
		roots_rest.append(_at("tent_%d_0" % k))
		segment_length.append(_at("tent_%d_0" % k).distance_to(_at("tent_%d_1" % k)))


func _at(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


static func _hinge(a: Vector3, b: Vector3, c: Vector3, fallback: Vector3) -> Vector3:
	var h := (b - a).cross(c - b)
	return h.normalized() if h.length() > 0.0001 else fallback


## An orthonormal frame with `along` as its Y and `side` (made square to it) as its X.
static func frame(along: Vector3, side: Vector3) -> Basis:
	var y := along.normalized()
	var x := side - y * side.dot(y)
	x = x.normalized() if x.length() > 0.0001 else y.cross(Vector3.FORWARD).normalized()
	return Basis(x, y, x.cross(y))


## How a part that ran `rest_along` with its hinge `rest_side` at rest is turned now.
static func turned(along: Vector3, side: Vector3, rest_along: Vector3, rest_side: Vector3) -> Basis:
	return frame(along, side) * frame(rest_along, rest_side).inverse()


## Two-bone IK: [knee, end], reaching from `root` towards `target`, the knee
## bent towards `pole`. If it cannot reach, it points straight there.
static func two_bone(root: Vector3, target: Vector3, upper: float, lower: float, pole: Vector3) -> Array:
	var to := target - root
	var length := to.length()
	var dir := to / maxf(length, 0.0001)
	var d := clampf(length, absf(upper - lower) + 0.01, upper + lower - 0.001)
	var a := (upper * upper - lower * lower + d * d) / (2.0 * d)
	var h := sqrt(maxf(upper * upper - a * a, 0.0))
	var bend := pole - dir * pole.dot(dir)
	if bend.length_squared() < 0.0001:
		bend = dir.cross(Vector3.RIGHT)
	bend = bend.normalized()
	return [root + dir * a + bend * h, root + dir * d]


func _put(bone: String, basis: Basis, origin: Vector3) -> void:
	_global[_bone[bone]] = Transform3D(basis, origin)


## Where a rest point of the body (`body`, in the skeleton's space) is now.
func on_body(point: Vector3, body_at: Vector3, body_turn: Basis) -> Vector3:
	return body_at + body_turn * (point - body_rest)


## Where a rest point of the hood is now.
func on_head(point: Vector3, head_at: Vector3, head_turn: Basis) -> Vector3:
	return head_at + head_turn * (point - head_rest)


## Sets every bone. Everything is in the skeleton's space:
## - `body_at`, `body_turn`: where the body's rest point is and how it is turned;
## - `head_yaw`, `head_pitch`: the hood's turn on it (radians);
## - `eye_dir`: the way the great eye's lens looks;
## - `aim`: what the heat ray's emitter points at, and `unfold` (0..1) how far
##   the arm is reached out to it from folded;
## - `feet`: where each foot's sole is; `swings`: how far through a step each
##   leg is (0 planted); `tentacles`: each tentacle's five points;
## - `delta`: the time since the last pose (0 puts the legs' springs at rest).
func pose(body_at: Vector3, body_turn: Basis, head_yaw: float, head_pitch: float, eye_dir: Vector3, aim: Vector3, unfold: float, feet: Array, swings: Array, tentacles: Array, delta := 0.0) -> void:
	if skeleton == null:
		return
	_time += delta
	_put("body", body_turn, body_at)
	var head_turn := body_turn * Basis(Vector3.UP, head_yaw) * Basis(Vector3.RIGHT, -head_pitch)
	var head_at := on_body(head_rest, body_at, body_turn)
	_put("head", head_turn, head_at)

	# The eye turns in its bezel to look along `eye_dir` (no further than 65 degrees off the hood's).
	var rest_look := (head_turn * EYE_REST).normalized()
	var look := eye_dir.normalized() if eye_dir.length() > 0.001 else rest_look
	var off := rest_look.angle_to(look)
	if off > deg_to_rad(65.0):
		look = rest_look.slerp(look, deg_to_rad(65.0) / off)
	var eye_turn := Basis(Quaternion(rest_look, look)) if rest_look.dot(look) > -0.999 else Basis()
	_put("eye", eye_turn * head_turn, on_head(eye_rest, head_at, head_turn))

	# The heat ray's arm: from folded at rest, reaching its wrist out towards what it aims at.
	var shoulder := on_head(shoulder_rest, head_at, head_turn)
	var folded_wrist := on_head(wrist_rest, head_at, head_turn)
	var to_aim := aim - shoulder
	var reach := (upper_length + fore_length) * 0.86
	# (it holds the emitter out high, level with the hood, and points it down: it fires from on high)
	var flat_aim := Vector3(to_aim.x, 0.0, to_aim.z)
	var reach_way := (flat_aim.normalized() * 0.92 + Vector3.UP * 0.08).normalized() if flat_aim.length() > 0.5 else Vector3.DOWN
	var wrist := folded_wrist.lerp(shoulder + reach_way * reach, clampf(unfold, 0.0, 1.0)) if to_aim.length() > 0.5 else folded_wrist
	var rest_bend := (elbow_rest - shoulder_rest) - (wrist_rest - shoulder_rest).normalized() * (elbow_rest - shoulder_rest).dot((wrist_rest - shoulder_rest).normalized())
	var pole := head_turn * rest_bend + head_turn * Vector3(-0.6, -0.4, 0.0)
	var solved := two_bone(shoulder, wrist, upper_length, fore_length, pole)
	var elbow: Vector3 = solved[0]
	wrist = solved[1]
	var hinge := (elbow - shoulder).cross(wrist - elbow)
	hinge = hinge.normalized() if hinge.length() > 0.001 else head_turn * _arm_hinge
	var rest_upper := elbow_rest - shoulder_rest
	var rest_fore := wrist_rest - elbow_rest
	_put("arm_upper", turned(elbow - shoulder, hinge, rest_upper, _arm_hinge), shoulder)
	_put("arm_fore", turned(wrist - elbow, hinge, rest_fore, _arm_hinge), elbow)
	var point := (aim - wrist).normalized() if (aim - wrist).length() > 0.5 else head_turn * EMITTER_REST.normalized()
	point = (head_turn * EMITTER_REST.normalized()).slerp(point, clampf(unfold * 1.4, 0.0, 1.0))
	_put("emitter", turned(point, hinge, EMITTER_REST, _arm_hinge), wrist)

	# The legs.
	for i in LEGS:
		var hip := on_body(hips_rest[i], body_at, body_turn)
		var foot: Vector3 = feet[i]
		var points := leg_points(i, hip, foot, float(swings[i]), body_at, delta)
		var out := Vector3(foot.x - body_at.x, 0.0, foot.z - body_at.z)
		out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		var side := Vector3.UP.cross(out).normalized()
		for j in LEG_BONES:
			_put("leg_%d_%d" % [i, j], turned(points[j + 1] - points[j], side, _leg_rest_dirs[i][j], _leg_hinge[i]), points[j])
		_put("foot_%d" % i, turned(Vector3.UP, side, Vector3.UP, _leg_hinge[i]), foot)

	# The tentacles: each bone from one of its points to the next.
	var down := head_turn * Vector3.DOWN
	for k in TENTACLES:
		var points: PackedVector3Array = tentacles[k]
		for j in 4:
			var a := points[j]
			var b := points[j + 1]
			var span := b - a
			var length := span.length()
			var dir := span / length if length > 0.001 else down
			var bend := Basis(Quaternion(down, dir)) if down.dot(dir) > -0.999 else Basis(Vector3.RIGHT, PI)
			var stretch := maxf(length / segment_length[k], 0.2)
			_put("tent_%d_%d" % [k, j], bend * head_turn * Basis.from_scale(Vector3(1.0, stretch, 1.0)), a)

	# Each bone's pose against its parent's.
	for b in _global.size():
		var parent := _parent[b]
		var local := _global[b] if parent < 0 else _global[parent].affine_inverse() * _global[b]
		skeleton.set_bone_pose(b, local)


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


## A leg's arch from `hip` to `ankle`, with `arch` metres of bow in it, as `count` + 1 points.
static func _arch(hip: Vector3, ankle: Vector3, out: Vector3, arch: float, count: int) -> PackedVector3Array:
	var p1 := hip + (out * 0.55 + Vector3.UP * 0.85).normalized() * arch
	var p2 := ankle + Vector3.UP * (arch * 1.1)
	var points := PackedVector3Array()
	for k in count + 1:
		points.append(_bezier(hip, p1, p2, ankle, float(k) / count))
	return points


static func _length_of(points: PackedVector3Array) -> float:
	var total := 0.0
	for k in points.size() - 1:
		total += points[k].distance_to(points[k + 1])
	return total


## Where leg `i`'s joints are (LEG_BONES + 1 points, hip to ankle): its arch,
## bowed to its length, with its spring's sway and a ripple while it swings
## (`swing` 0..1 through a step) laid over it.
func leg_points(i: int, hip: Vector3, foot: Vector3, swing: float, body_at: Vector3, delta: float) -> PackedVector3Array:
	var ankle := foot + Vector3.UP * ANKLE_HEIGHT
	var out := Vector3(foot.x - body_at.x, 0.0, foot.z - body_at.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var side := Vector3.UP.cross(out).normalized()
	# How much bow makes it as long as it is (it can only be as straight as a line).
	var low := 0.1
	var high := 80.0
	for k in 14:
		var arch := (low + high) * 0.5
		if _length_of(_arch(hip, ankle, out, arch, 12)) < leg_length[i]:
			low = arch
		else:
			high = arch
	var base := _arch(hip, ankle, out, (low + high) * 0.5, 24)
	# Its middle on a spring: it lags behind as the body and the foot move, and overshoots.
	var middle := base[12]
	if not _mid_ready[i] or delta <= 0.0:
		_mid[i] = middle
		_mid_speed[i] = Vector3.ZERO
		_mid_ready[i] = true
	else:
		var pull := (middle - _mid[i]) * LEG_SPRING * LEG_SPRING - _mid_speed[i] * LEG_DAMPING * 2.0 * LEG_SPRING
		_mid_speed[i] += pull * delta
		_mid[i] += _mid_speed[i] * delta
	var sway := (_mid[i] - middle).limit_length(LEG_SWAY)
	_mid[i] = middle + sway
	# A ripple running down it while it swings, and a slow writhe always.
	var ripple := sin(swing * PI) * 1.8
	var points := PackedVector3Array()
	for k in base.size():
		var t := float(k) / (base.size() - 1)
		var hump := sin(t * PI)
		var wave := sin(TAU * (t * 1.4 - _time * 0.7 - i * 0.3))
		var writhe := sin(TAU * (t * 0.9 + _time * 0.11 + i * 0.37)) * 0.5
		points.append(base[k] + sway * hump + side * hump * (ripple * wave + writhe) + Vector3.UP * hump * ripple * 0.4 * wave)
	# Laid out again evenly along it, LEG_BONES to the leg.
	var run := PackedFloat32Array([0.0])
	for k in points.size() - 1:
		run.append(run[k] + points[k].distance_to(points[k + 1]))
	var total := run[run.size() - 1]
	var even := PackedVector3Array()
	var at := 0
	for j in LEG_BONES + 1:
		var want := total * j / LEG_BONES
		while at < run.size() - 2 and run[at + 1] < want:
			at += 1
		var f := clampf((want - run[at]) / maxf(run[at + 1] - run[at], 0.0001), 0.0, 1.0)
		even.append(points[at].lerp(points[at + 1], f))
	return even


## A foot has come down: the leg splays and wobbles before it takes the weight.
func kick(i: int, strength: float) -> void:
	if i < _mid_speed.size():
		var out := Vector3(feet_rest[i].x, 0.0, feet_rest[i].z).normalized()
		_mid_speed[i] += (Vector3.DOWN * 7.0 + out * 5.0 + Vector3.UP.cross(out) * randf_range(-3.0, 3.0)) * strength


## Where the end of the emitter's horn is now (in the skeleton's space), and the way it points.
func emitter_tip() -> Array:
	var at := _global[_bone["emitter"]]
	var along := (at.basis * EMITTER_REST.normalized()).normalized()
	return [at.origin + along * EMITTER_LENGTH, along]


## Where the great eye's lens is now (in the skeleton's space), and the way it looks.
func eye_lens() -> Array:
	var at := _global[_bone["eye"]]
	var along := (at.basis * EYE_REST.normalized()).normalized()
	return [at.origin + along * 0.9, along]


## Where a tentacle's root is now (in the skeleton's space).
func root_of(k: int, body_at: Vector3, body_turn: Basis, head_yaw: float, head_pitch: float) -> Vector3:
	var head_turn := body_turn * Basis(Vector3.UP, head_yaw) * Basis(Vector3.RIGHT, -head_pitch)
	return on_head(roots_rest[k], on_body(head_rest, body_at, body_turn), head_turn)


## A bone's pose in the skeleton's space, from the last `pose`.
func bone_pose(bone: String) -> Transform3D:
	return _global[_bone[bone]]
