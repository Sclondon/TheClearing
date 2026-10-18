class_name DimetrodonRig
extends Node3D
## Poses the dimetrodon (creatures/dimetrodon/models/dimetrodon*.glb) in code,
## every frame, from what its Dimetrodon (the parent) says it is doing.
##
## THE WALK is a sprawler's: the upper arm and thigh swing round out to the
## side (two-bone IK to each foot, the elbow and knee kept out and up), the
## feet planted out wide and staying where they were put down, in a lateral
## sequence with the diagonal feet nearly together (fore left with hind right,
## then the other two), while the whole spine swings from side to side in an
## S, the shoulders one way and the hips the other, each step taken with the
## bend of the body, and the tail wagging behind it, a beat later. Faster (its
## rush, its lunge) the body is held higher and the swing is bigger.
##
## WHAT IT DOES, on top of the walk (each eases in and out):
## - BASKING: lying flat, the belly on the warm ground, the legs splayed, the
##   head down on its chin, still but for its breathing.
## - THREAT: up high on its legs, its head raised and turned to them, the
##   jaws gaping wide to show its teeth (the Dimetrodon hisses).
## - THE LUNGE (`lunge()`): a sudden low dart forward, the head thrust out
##   and the jaws flung open, and snapped shut (`snapped`) at the end of it.
## - LOOKING: its head turned to `look_at_point`.

signal footfall(at: Vector3, weight: float)
## The jaws have snapped shut in a lunge.
signal snapped

const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## Where in the stride each foot is put down: the diagonals nearly together.
const WALK: Array[float] = [0.0, 0.5, 0.58, 0.08]
const DUTY := Vector2(0.68, 0.48)
const FAST_AT := Vector2(1.0, 3.5)
const STRIDE := [0.0, 0.42, 0.4, 0.55, 1.0, 0.75, 2.5, 1.05, 4.0, 1.3, 7.0, 1.7]
const REACH := 0.32
const LIFT := Vector2(0.07, 0.08)
## How far the spine swings from side to side (rad), walking and fast.
const SWING := Vector2(0.13, 0.2)
const GAPE := 0.95
## How long a lunge takes, and when in it the jaws snap shut.
const LUNGE_TIME := 0.75
const SNAP_AT := 0.42
const HEAD_TIP := Vector3(0.0, -0.03, 0.5)

var low_poly := false
var skin_tint := Color.WHITE
var scales := 36.0
var eyeshine := 0.3
var materials := {}

var _dim: Dimetrodon
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Array[Node3D] = []
var _legs: Array[Array] = []
var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _ankles: Array[Vector3] = []
var _lengths: Array[Vector2] = []
var _frames: Array[Array] = []
var _foot_rest: Array[Basis] = []

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _last_yaw := 0.0
var _turn := 0.0
var _down: Array[bool] = [true, true, true, true]
var _plant: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _lifted_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _planted := false
var _bask := 0.0
var _threat := 0.0
var _mouth := 0.0
var _breath := 0.0
var _look := Vector2.ZERO
var _lunged := 99.0
var _snapped := true


func _ready() -> void:
	_dim = get_parent() as Dimetrodon
	_build()
	_time = randf() * 10.0
	_last_yaw = global_rotation.y


func settle() -> void:
	_planted = false
	_last_yaw = global_rotation.y
	_turn = 0.0
	_pace = 0.0


func lunge() -> void:
	_lunged = 0.0
	_snapped = false


func lunging() -> bool:
	return _lunged < LUNGE_TIME


func head() -> Node3D:
	return _head


## Where the front of its jaws is, in the world.
func snout_tip() -> Vector3:
	return _head.global_transform * HEAD_TIP if _head else global_position


func _process(delta: float) -> void:
	if _dim == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 20.0)
	_time += delta
	var size := maxf(global_basis.get_scale().x, 0.01)
	var velocity := _dim.velocity / size
	var speed := Vector2(velocity.x, velocity.z).length()
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw
	if not _planted:
		_planted = true
		for i in 4:
			_plant[i] = global_transform * _ankles[i]
			_lifted_at[i] = _plant[i]
	_lunged += delta
	var lunging_now := _lunged < LUNGE_TIME
	_bask = _approach(_bask, 1.0 if _dim.basking and speed < 0.2 and not lunging_now else 0.0, 2.0 if _dim.basking else 5.0, delta)
	_threat = _approach(_threat, 1.0 if _dim.threatening and not lunging_now else 0.0, 7.0, delta)
	if not _snapped and _lunged >= SNAP_AT:
		_snapped = true
		snapped.emit()

	# --- The walk ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.6), 8.0, delta)
	var fast := smoothstep(FAST_AT.x, FAST_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.03, 0.15, _pace)
	var duty := lerpf(DUTY.x, DUTY.y, fast)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var to_model := global_transform.affine_inverse()
	var targets: Array[Vector3] = []
	var lifted: Array[float] = []
	for i in 4:
		var rest := _ankles[i]
		# (basking, the legs splay out further; rearing in threat, they come in a little under it)
		var out := signf(rest.x) * (0.06 * _bask - 0.03 * _threat)
		var stance := rest + Vector3(out, 0.0, 0.0)
		var span := minf(duty * stride, REACH * 2.0) * travel
		var landing := stance + Vector3(0.0, 0.0, span * 0.5)
		var at := fposmod(_phase - WALK[i], 1.0)
		var target: Vector3
		var up := 0.0
		if at < duty or gait < 0.01:
			if not _down[i]:
				_down[i] = true
				_plant[i] = global_transform * landing
				if gait > 0.3:
					footfall.emit(_plant[i], clampf(0.3 + _pace * 0.15, 0.0, 1.0) * size)
			target = to_model * _plant[i]
		else:
			if _down[i]:
				_down[i] = false
				_lifted_at[i] = _plant[i]
			var u := (at - duty) / (1.0 - duty)
			target = (to_model * _lifted_at[i]).lerp(landing, smoothstep(0.0, 1.0, u))
			up = sin(PI * u)
			target.y = rest.y + up * (LIFT.x if i < 2 else LIFT.y) * lerpf(1.0, 1.5, fast) * gait
		if at < duty or gait < 0.01:
			target.y = rest.y
		if gait < 0.5:
			var settled := stance.lerp(target, gait * 2.0)
			if gait < 0.02:
				settled = target.lerp(stance, 1.0 - exp(-3.0 * delta))
				_plant[i] = global_transform * Vector3(settled.x, rest.y, settled.z)
			target = settled
		targets.append(target)
		lifted.append(up)

	# The spine swings in an S with the steps: the shoulders one way, the hips the other.
	var swing := lerpf(SWING.x, SWING.y, fast) * gait
	var wave := sin(TAU * (_phase + 0.05))
	var lunge_k := 0.0
	if lunging_now:
		var u := _lunged / LUNGE_TIME
		lunge_k = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.55, 1.0, u))
	var height := lerpf(0.0, 0.05, fast) - 0.19 * _bask + 0.09 * _threat - 0.04 * lunge_k
	_breath += delta * TAU * lerpf(0.25, 0.5, fast)
	var swell := sin(_breath) * 0.015 * (1.0 - 0.5 * _bask)
	_body.position = _body_rest + Vector3(0.0, height + sin(TAU * _phase * 2.0) * 0.01 * gait, 0.06 * lunge_k)
	_body.rotation = Vector3(-0.08 * _threat + 0.04 * lunge_k, 0.0, (lifted[1] - lifted[0]) * 0.03)
	_chest.rotation = Vector3(0.0, wave * swing, 0.0)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_pelvis.rotation = Vector3(0.0, -wave * swing * 0.9, 0.0)
	_pose_head(delta, wave * swing, lunge_k)
	_pose_tail(delta, wave, swing)
	_pose_legs(targets, lifted)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


func _pose_head(delta: float, swing: float, lunge_k: float) -> void:
	var target := Vector2.ZERO
	var point := _dim.look_at_point
	if point.is_finite():
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)) - swing * 0.6, -0.9, 0.9)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.4)
	else:
		target.x = sin(_time * 0.3) * 0.15
		target.y = sin(_time * 0.2 + 1.0) * 0.04
	_look = _look.lerp(target, 1.0 - exp(-(6.0 if _threat > 0.3 or lunge_k > 0.0 else 2.0) * delta))
	# (against the swing of the shoulders, so that the head keeps on its way)
	var yaw := _look.x - swing * 0.8
	var pitch := _look.y * 0.8 + 0.16 * _bask - 0.25 * _threat - 0.12 * lunge_k
	_neck.rotation = Vector3(pitch * 0.5, yaw * 0.5, 0.0)
	_head.rotation = Vector3(pitch * 0.5, yaw * 0.5, 0.0)
	# The jaws: wide in threat, flung open in a lunge and snapped shut; a hiss flutters them.
	var open := _threat * (0.75 + 0.06 * sin(_time * 23.0))
	if _lunged < LUNGE_TIME:
		var u := _lunged
		open = maxf(open, smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(SNAP_AT - 0.06, SNAP_AT, u)))
	open = maxf(open, 0.04 * (1.0 - _bask))
	_mouth = lerpf(_mouth, open, 0.5 if open < _mouth else 0.3)
	_jaw.rotation.x = _mouth * GAPE


func _pose_tail(delta: float, wave: float, swing: float) -> void:
	for i in _tail.size() - 1:
		var lagged := sin(TAU * (_phase + 0.05) - 0.9 - i * 0.55)
		var yaw := -lagged * swing * (0.5 + i * 0.15) + sin(_time * 0.5 - i * 0.6) * 0.02
		# (basking, the tail lies along the ground)
		var pitch := 0.05 * _bask * (1.0 if i < 2 else -0.4) - 0.03 * _threat
		_tail[i].rotation = _tail[i].rotation.lerp(Vector3(pitch, yaw, 0.0), 1.0 - exp(-12.0 * delta))


func _pose_legs(targets: Array[Vector3], lifted: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 4:
		var spine := _chest if i < 2 else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var ankle := to_body * targets[i]
		var out := signf(_hips[i].x)
		var pole := (to_body.basis * Vector3(out, 0.9, 0.0)).normalized()
		var foot_basis := to_body.basis * Basis(Vector3.RIGHT, 0.35 * lifted[i]) * _foot_rest[i]
		_solve_leg(i, hip, ankle, pole, foot_basis)


## Two-bone IK in body space, the elbow or knee out to `pole`; the foot laid flat.
func _solve_leg(index: int, hip: Vector3, target: Vector3, pole: Vector3, foot_basis: Basis) -> void:
	var a := _lengths[index].x
	var b := _lengths[index].y
	var to := target - hip
	var reach := clampf(to.length(), absf(a - b) + 0.01, a + b - 0.002)
	var line := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.000001 else Vector3.UP
	var angle := acos(clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0))
	var knee := hip + (line * cos(angle) + aside * sin(angle)) * a
	var ankle := hip + line * reach
	var normal := line.cross(aside).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame_of(normal, (knee - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame_of(normal, (ankle - knee).normalized()) * frames[1], knee)
	(bones[2] as Node3D).transform = Transform3D(foot_basis, ankle)


static func _frame_of(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


static func _keyed(keys: Array, time: float) -> float:
	var last := keys.size() / 2 - 1
	if time <= keys[0]:
		return keys[1]
	if time >= keys[last * 2]:
		return keys[last * 2 + 1]
	var k := 0
	while time > keys[k * 2 + 2]:
		k += 1
	var u: float = (time - keys[k * 2]) / (keys[k * 2 + 2] - keys[k * 2])
	return lerpf(keys[k * 2 + 1], keys[k * 2 + 3], smoothstep(0.0, 1.0, u))


func _build() -> void:
	var path := "res://creatures/dimetrodon/models/dimetrodon%s.glb" % ("_lo" if low_poly else "")
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = DimetrodonLook.dress(model, skin_tint, scales, eyeshine)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_head = _joint(_neck, &"head")
	_jaw = _joint(_head, &"jaw")
	var from := _pelvis
	for bone: String in ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_end"]:
		var joint := _joint(from, bone)
		_tail.append(joint)
		from = joint
	for i in 4:
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_ankles.append(at[2])
		_lengths.append(Vector2(at[0].distance_to(at[1]), at[1].distance_to(at[2])))
		var out := signf(at[0].x)
		var line := (at[2] - at[0]).normalized()
		var pole := Vector3(out, 0.9, 0.0).normalized()
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := line.cross(aside).normalized()
		_frames.append([_frame_of(normal, (at[1] - at[0]).normalized()).inverse(), _frame_of(normal, (at[2] - at[1]).normalized()).inverse()])
		_foot_rest.append(Basis.IDENTITY)


func _rest(bone: StringName) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin


func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var joint := Node3D.new()
	var index := _skeleton.find_bone(bone)
	joint.name = bone
	joint.position = _skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint
