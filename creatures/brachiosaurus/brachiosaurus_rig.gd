class_name BrachiosaurusRig
extends Node3D
## Poses the brachiosaurus (creatures/brachiosaurus/models/brachiosaurus*.glb)
## in code, every frame, from what its Brachiosaurus (the parent) says it is
## doing. Its feet follow a gait cycle and are put down with IK, each one
## staying where it was put down until it is lifted again (so nothing slides);
## the spine, the long neck, the head, jaw and tail are laid on top.
##
## THE WALK: slow, four beats (hind, fore on that side, the other hind, its
## fore: an elephant's walk), each foot down about seven tenths of the stride,
## lifted high and slow (a sauropod's foot comes up a long way off the ground
## and is set down flat), so that where each will come down can be seen. The
## hip over a lifted foot sags, the whole body rolls with the steps, the neck
## sways a little against it and the tail behind. Turning on the spot it steps
## round. (`footfall` as each foot comes down.)
##
## WHAT IT DOES, on top of the walk (each eases in and out):
## - BROWSING (`browse_point`): its neck stretched up and round to the leaves
##   there, its head reaching in, nibbling: the jaw working, a tug of the head
##   as it strips them.
## - LOOKING (`look_at_point`): its head turned to it, the neck curving down
##   to see it when it is low down (someone at its feet).
## - BELLOW and RUMBLE: the neck lifted and the jaw wide in a bellow; the
##   throat fluttering in a rumble.
##
## THE FEET: `landing(i)` says where a lifted foot will come down (in the
## world) and how near it is to coming down, so that a game can warn of it.
##
## FAR OFF it can be drawn with the low model (`lod_range`) and posed only
## every few frames (`pose_every`): set those from the game.
##
## Every joint is read from the model's skeleton (tools/build_brachiosaurus.py).

## A foot has come down: where, and how hard (0..1).
signal footfall(at: Vector3, weight: float)

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## Where in the stride each foot is put down (a lateral walk: hind, fore, hind, fore).
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
## The share of the stride a foot is down, walking slowly and faster.
const DUTY := Vector2(0.72, 0.62)
## Speeds (m/s) over which it goes from its slow walk to its fastest.
const FAST_AT := Vector2(1.4, 2.6)
## Length of a stride (m) against speed (m/s).
const STRIDE := [0.0, 2.6, 0.5, 3.3, 1.2, 4.4, 2.0, 5.4, 3.0, 6.4]
## How far a foot reaches, at most, before or behind where it stands (fore, hind).
const REACH := Vector2(1.5, 1.7)
## How high a foot is lifted (fore, hind), m.
const LIFT := Vector2(0.5, 0.55)
const FOLD := Vector2(1.6, 1.3)
const FOLD_PLANTED := Vector2(-0.1, 0.35)
## How far the jaw drops, wide open, radians.
const GAPE := 0.55
const NECK_BONES: Array[String] = ["neck", "neck_1", "neck_2", "neck_3"]
## How much of a turn of the neck each of its bones takes (base to head).
const NECK_SHARE: Array[float] = [0.34, 0.28, 0.22, 0.16]
## How much each bends to bring the head down to look at something low.
const DIP_SHARE: Array[float] = [0.42, 0.24, 0.12, -0.05]
const TAIL_SHARE: Array[float] = [0.12, 0.15, 0.18, 0.19, 0.19, 0.17]
const BELLOW_TIME := 2.6
const RUMBLE_TIME := 3.0
## Where the tip of its snout is, in the head's space.
const SNOUT := Vector3(0.0, -0.32, 0.8)

## Use the low-poly model only. Set before it enters the tree.
var low_poly := false
var skin_tint := Color.WHITE
var scales := 14.0
var eyeshine := 0.2
## Further than this from the camera it is drawn with the low model (0: never).
var lod_range := 70.0
## Posed only every this many frames (1: every frame). The game sets it, by how far it is.
var pose_every := 1
## Where the ground is under a point (x, z) in the world (its height): for its feet on uneven ground. Unset: flat.
var ground_at := Callable()
## The materials, by name (see BrachiosaurusLook.dress).
var materials := {}

var _brach: Brachiosaurus
var _skeletons: Array[Skeleton3D] = []
var _models: Array[Node3D] = []
var _shown := 0
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Array[Node3D] = []
var _head: Node3D
var _jaw: Node3D
var _tail: Array[Node3D] = []
var _legs: Array[Array] = []

var _body_rest := Vector3.ZERO
var _neck_base := Vector3.ZERO
var _head_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _feet: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _last_yaw := 0.0
var _turn := 0.0
var _waited := 0.0
var _frame := 0
var _down: Array[bool] = [true, true, true, true]
var _plant: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _lifted_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## Where each lifted foot will come down (world), and how far through its lift it is (0..1; -1 down).
var _landing: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _lift: Array[float] = [-1.0, -1.0, -1.0, -1.0]
var _planted := false
var _mouth := 0.0
var _breath := 0.0
## Where its head is turned (yaw, pitch), how far it is dipping its neck, how far into browsing.
var _aim := Vector2.ZERO
var _dip := 0.0
var _browse := 0.0
var _nibble := 0.0
var _bellowed := 99.0
var _rumbled := 99.0
var _check_lod := 0.0


func _ready() -> void:
	_brach = get_parent() as Brachiosaurus
	_build()
	_time = randf() * 10.0
	_nibble = randf()
	_last_yaw = global_rotation.y


func settle() -> void:
	_planted = false
	_last_yaw = global_rotation.y
	_turn = 0.0
	_pace = 0.0


func bellow() -> void:
	_bellowed = 0.0


func rumble() -> void:
	_rumbled = 0.0


## Where foot `i` (fore left, fore right, hind left, hind right) will come down
## if it is lifted, in the world, and how far through its lift it is (0 just
## lifted, 1 down; -1: it is down now).
func landing(i: int) -> Vector4:
	var at := _landing[i] if _lift[i] >= 0.0 else _plant[i]
	return Vector4(at.x, at.y, at.z, _lift[i])


## Where foot `i` stands (or last stood), in the world.
func foot(i: int) -> Vector3:
	return _plant[i]


## How wide each foot's sole is (radius, m): fore, hind.
func sole() -> Vector2:
	var size := global_basis.get_scale().x
	return Vector2(0.43, 0.56) * size


func head() -> Node3D:
	return _head


## Where the tip of its snout is, in the world.
func snout_tip() -> Vector3:
	return _head.global_transform * SNOUT if _head else global_position


## Whether it is drawn with its low model now.
func low_now() -> bool:
	return _shown == 1 or low_poly


func _process(delta: float) -> void:
	if _brach == null or _skeletons.is_empty():
		return
	_waited += delta
	_frame += 1
	_check_lod -= delta
	if _check_lod <= 0.0:
		_check_lod = 0.5
		_choose_model()
	if pose_every > 1 and _frame % pose_every != 0:
		return
	delta = minf(_waited, 0.25)
	_waited = 0.0
	_pose(delta)


func _choose_model() -> void:
	if _models.size() < 2:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := camera != null and lod_range > 0.0 and camera.global_position.distance_to(global_position) > lod_range
	var want := 1 if far else 0
	if want != _shown:
		_shown = want
		_models[0].visible = want == 0
		_models[1].visible = want == 1


func _pose(delta: float) -> void:
	_time += delta
	var size := maxf(global_basis.get_scale().x, 0.01)
	var velocity := _brach.velocity / size
	var speed := Vector2(velocity.x, velocity.z).length()
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / maxf(delta, 0.001), 5.0, delta)
	_last_yaw = yaw
	if not _planted:
		_planted = true
		for i in 4:
			_plant[i] = _on_ground(global_transform * _feet[i], i)
			_lifted_at[i] = _plant[i]
			_lift[i] = -1.0

	_bellowed += delta
	_rumbled += delta
	_browse = _approach(_browse, 1.0 if _brach.browse_point.is_finite() else 0.0, 1.2, delta)

	# --- The walk ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 4.0), 3.0, delta)
	var fast := smoothstep(FAST_AT.x, FAST_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.03, 0.2, _pace)
	var duty := lerpf(DUTY.x, DUTY.y, fast)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var to_model := global_transform.affine_inverse()
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var lifted: Array[float] = []
	for i in 4:
		var fore := i < 2
		var rest := _feet[i]
		var reach: float = REACH.x if fore else REACH.y
		var span := minf(duty * stride, reach * 2.0) * travel
		var landing := rest + Vector3(0.0, 0.0, span * 0.5)
		var at := fposmod(_phase - WALK[i], 1.0)
		var target: Vector3
		var up := 0.0
		if at < duty or gait < 0.01:
			if not _down[i]:
				_down[i] = true
				# (it comes down where it was always going to: the spot its shadow showed)
				_plant[i] = _landing[i]
				_lift[i] = -1.0
				if gait > 0.3:
					footfall.emit(_plant[i], clampf(0.5 + _pace * 0.2, 0.0, 1.0) * size)
			target = to_model * _plant[i]
		else:
			if _down[i]:
				_down[i] = false
				_lifted_at[i] = _plant[i]
				# Where it will come down is settled as it is lifted: where the foot
				# would be put, carried on as far as the body goes while it swings.
				var swing_time := (1.0 - duty) * stride / maxf(_pace, 0.05)
				_landing[i] = _on_ground(global_transform * landing + _brach.velocity * swing_time * travel, i)
			var u := (at - duty) / (1.0 - duty)
			var from := to_model * _lifted_at[i]
			_lift[i] = u
			var land := to_model * _landing[i]
			target = from.lerp(land, smoothstep(0.0, 1.0, u))
			up = sin(PI * pow(u, 0.75))
			target.y = lerpf(from.y, land.y, u) + up * (LIFT.x if fore else LIFT.y) * gait
		# (standing, its feet come to stand where they should)
		if gait < 0.5:
			var settled := rest.lerp(target, gait * 2.0)
			if gait < 0.02:
				settled = target.lerp(rest, 1.0 - exp(-1.5 * delta))
				var ground := to_model * _on_ground(global_transform * Vector3(settled.x, rest.y, settled.z), i)
				settled.y = ground.y
				_plant[i] = global_transform * settled
			target = settled
		targets.append(target)
		pitches.append(lerpf(0.0, 0.35, up) * (1.0 if fore else 0.7))
		lifted.append(up)

	# The body: each hip sags over a lifted foot; it rolls with the steps.
	var sag_fore := (lifted[0] + lifted[1]) * 0.5
	var sag_hind := (lifted[2] + lifted[3]) * 0.5
	var heave := lerpf(1.0, 1.4, fast) * gait
	var roll_hind := (lifted[3] - lifted[2]) * 0.03 * heave
	var roll_fore := (lifted[1] - lifted[0]) * 0.025 * heave
	var shift := sin(TAU * (_phase - 0.1)) * 0.07 * heave
	var swing_hind := (targets[3].z - targets[2].z) * 0.035
	var swing_fore := (targets[1].z - targets[0].z) * 0.03
	# (on uneven ground the body follows the mean of its feet)
	var ground_fore := 0.0
	var ground_hind := 0.0
	if ground_at.is_valid():
		for i in 4:
			var under := (to_model * _on_ground(global_transform * _feet[i], i)).y - _feet[i].y
			if i < 2:
				ground_fore += under * 0.5
			else:
				ground_hind += under * 0.5
	var body_at := _body_rest + Vector3(shift, (ground_fore + ground_hind) * 0.5 - (sag_hind * 0.06 + sag_fore * 0.05) * heave, 0.0)
	var body_pitch := (ground_hind - ground_fore) / 5.0
	var body_turn := Vector3(body_pitch + (sag_fore - sag_hind) * 0.005 * heave, 0.0, (roll_hind + roll_fore) * 0.5)
	var chest_turn := Vector3(0.0, swing_fore * 0.5, roll_fore - roll_hind * 0.3)
	var pelvis_turn := Vector3(0.0, swing_hind, roll_hind * 0.6)
	_breath += delta * TAU * lerpf(0.1, 0.2, fast)
	var swell := sin(_breath) * 0.008
	var rumbling := 0.0
	if _rumbled < RUMBLE_TIME:
		rumbling = smoothstep(0.0, 0.3, _rumbled) * (1.0 - smoothstep(RUMBLE_TIME * 0.7, RUMBLE_TIME, _rumbled))
		swell += sin(_time * TAU * 8.0) * 0.004 * rumbling
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_pose_neck(delta, body_turn.x, rumbling, gait)
	_pose_jaw(rumbling)
	_pose_tail(gait, delta)
	_pose_legs(targets, pitches)
	var skeleton := _skeletons[_shown]
	for i in _joints.size():
		skeleton.set_bone_pose(_bones[i], _joints[i].transform)


## Puts foot `i`'s joint (at `at`, in the world) its height over the ground
## there (the game's `ground_at`, or flat ground where the creature stands).
func _on_ground(at: Vector3, i: int) -> Vector3:
	var ground := (get_parent() as Node3D).global_position.y
	if ground_at.is_valid():
		ground = float(ground_at.call(at.x, at.z))
	at.y = ground + _feet[i].y * global_basis.get_scale().y
	return at


## The neck and head: turned to what it browses or watches, the neck curving
## down to look at something low; lifted bellowing; swaying with the walk.
func _pose_neck(delta: float, upstream: float, rumbling: float, gait: float) -> void:
	var target := Vector2.ZERO
	var dip := 0.0
	var point := _brach.browse_point if _brach.browse_point.is_finite() else _brach.look_at_point
	var base := global_transform * _neck_base
	if point.is_finite():
		var to := point - base
		var rest := global_basis * (_head_rest - _neck_base)
		target.x = clampf(angle_difference(atan2(rest.x, rest.z), atan2(to.x, to.z)), -1.3, 1.3)
		var flat := Vector2(to.x, to.z).length()
		var want := atan2(to.y, flat)
		var have := atan2(rest.y, Vector2(rest.x, rest.z).length())
		# (above where it holds its head: it stretches up; well below: it dips its neck to see)
		target.y = clampf(have - want, -0.35, 0.3)
		if want < have - 0.2:
			dip = clampf((have - want - 0.2) * 1.1, 0.0, 1.0) * (1.0 - _browse)
	else:
		target.x = sin(_time * 0.13) * 0.35 + sin(_time * 0.37 + 1.0) * 0.12
		target.y = sin(_time * 0.11 + 2.0) * 0.06
	_aim = _aim.lerp(target, 1.0 - exp(-0.9 * delta))
	_dip = _approach(_dip, dip, 0.7, delta)
	_nibble += delta * 0.8
	var tug := smoothstep(0.65, 0.78, fposmod(_nibble, 1.0)) * (1.0 - smoothstep(0.8, 1.0, fposmod(_nibble, 1.0)))
	var lift := 0.0
	if _bellowed < BELLOW_TIME:
		lift = sin(PI * minf(_bellowed / 0.6, 1.0) * 0.5) * (1.0 - smoothstep(BELLOW_TIME * 0.7, BELLOW_TIME, _bellowed))
	var sway := sin(TAU * _phase - 0.6) * 0.03 * gait
	var bob := sin(TAU * _phase * 2.0 - 0.8) * 0.012 * gait
	for k in _neck.size():
		var pitch := -upstream * (0.5 if k == 0 else 0.0) + _aim.y * NECK_SHARE[k] + _dip * DIP_SHARE[k] * 1.4 + bob
		pitch -= lift * 0.08 * (1.0 - k * 0.2)
		pitch += 0.05 * tug * _browse * (1.0 if k == 3 else 0.0)
		var yaw := _aim.x * NECK_SHARE[k] + sway * (1.0 - k * 0.25)
		_neck[k].rotation = Vector3(pitch, yaw, 0.0)
	# (the head keeps its own level: it looks at what it looks at, down when the neck dips)
	var head_pitch := -_aim.y * 0.15 + _dip * 0.45 - lift * 0.25 + 0.06 * tug * _browse
	head_pitch += sin(_time * TAU * 9.0) * 0.004 * rumbling
	_head.rotation = Vector3(head_pitch, _aim.x * 0.1 + sin(_nibble * TAU * 0.5) * 0.08 * _browse, 0.0)


## The jaw: working as it nibbles, parted in a rumble, wide in a bellow.
func _pose_jaw(rumbling: float) -> void:
	var open := _browse * (0.1 + 0.1 * sin(_nibble * TAU * 2.0))
	open = maxf(open, rumbling * (0.12 + 0.04 * sin(_time * 17.0)))
	if _bellowed < BELLOW_TIME:
		var u := _bellowed / BELLOW_TIME
		open = maxf(open, smoothstep(0.05, 0.2, u) * (1.0 - smoothstep(0.7, 1.0, u)) * 0.8)
	_mouth = lerpf(_mouth, open, 0.35)
	_jaw.rotation.x = _mouth * GAPE


## The tail: held out behind and up off the ground, swaying a stride behind the hips.
func _pose_tail(gait: float, delta: float) -> void:
	for i in _tail.size() - 1:
		var share := TAIL_SHARE[i]
		var sway := sin(TAU * _phase - 1.4 - i * 0.5) * 0.06 * gait * share * 4.0 + sin(_time * 0.3 - i * 0.6) * 0.025
		var pitch := sin(TAU * _phase * 2.0 - 1.0 - i * 0.4) * 0.01 * gait
		_tail[i].rotation = _tail[i].rotation.lerp(Vector3(pitch, sway, 0.0), 1.0 - exp(-6.0 * delta))


func _pose_legs(targets: Array[Vector3], pitches: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 4:
		var fore := i < 2
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var at := to_body * targets[i]
		var pole := to_body.basis * (BEHIND if fore else AHEAD)
		_solve_leg(i, hip, at, to_body.basis * Basis(Vector3.RIGHT, pitches[i]), pole)


## Three-bone IK in body space, folding in a zigzag (as StegosaurusRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, foot_basis: Basis, pole: Vector3) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, total - 0.01)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var at := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	var fore := index < 2
	if reach > span:
		bend *= (total - reach) / maxf(total - span, 0.001)
	else:
		bend += (span - reach) / span * (FOLD.x if fore else FOLD.y)
	var last := line * cos(bend) + aside * sin(bend)
	var far := lengths.x + lengths.y - 0.008
	var near := absf(lengths.x - lengths.y) + 0.04
	var second := at - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = at - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	at = second + last * lengths.z
	var off := aside - along * aside.dot(along)
	off = off.normalized() if off.length_squared() > 0.0001 else aside
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + off * sin(fold)) * lengths.x
	var normal := aside.cross(line).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame_of(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame_of(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame_of(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(foot_basis, at)


static func _frame_of(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Reads a curve drawn by hand: (time, value) pairs, joined smoothly.
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
	var names: Array = ["_lo"] if low_poly else ([""] if lod_range <= 0.0 else ["", "_lo"])
	for suffix in names:
		var model: Node3D = (load("res://creatures/brachiosaurus/models/brachiosaurus%s.glb" % suffix) as PackedScene).instantiate()
		add_child(model)
		_models.append(model)
		_skeletons.append(model.find_children("*", "Skeleton3D", true, false)[0])
		materials = BrachiosaurusLook.dress(model, skin_tint, scales, eyeshine, materials)
	for k in range(1, _models.size()):
		_models[k].visible = false
	var skeleton := _skeletons[0]
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	var from := _chest
	for bone in NECK_BONES:
		var joint := _joint(from, bone)
		_neck.append(joint)
		from = joint
	_head = _joint(from, &"head")
	_jaw = _joint(_head, &"jaw")
	_neck_base = _model_point(&"neck")
	_head_rest = _model_point(&"head")
	from = _pelvis
	for bone: String in ["tail", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_end"]:
		var joint := _joint(from, bone)
		_tail.append(joint)
		from = joint
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "hoof"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_feet.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		var line := (at[3] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame_of(normal, (at[1] - at[0]).normalized()).inverse(), _frame_of(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame_of(normal, last).inverse(),
		])
	skeleton = null


## Where a bone's joint is at rest, in the model's space.
func _model_point(bone: StringName) -> Vector3:
	var skeleton := _skeletons[0]
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


func _rest(bone: StringName) -> Vector3:
	var skeleton := _skeletons[0]
	return skeleton.get_bone_rest(skeleton.find_bone(bone)).origin


func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var skeleton := _skeletons[0]
	var joint := Node3D.new()
	var index := skeleton.find_bone(bone)
	joint.name = bone
	joint.position = skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint
