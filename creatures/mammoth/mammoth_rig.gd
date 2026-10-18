class_name MammothRig
extends Node3D
## Poses a woolly mammoth (creatures/mammoth/models) in code, every frame,
## from what its Mammoth (the parent) says it is doing. The feet follow a gait
## cycle and are put down with IK (each leg the shoulder or hip, the elbow or
## knee, the wrist or ankle, and the foot: the elbow points back, the knee
## forward, as an elephant's do), and the body, neck, head, jaw, ears, tail and
## the eight bones of the trunk are laid on top.
##
## THE GAIT: an elephant's, a lateral walk at every speed (the hind foot, then
## the fore foot on the same side, then the other side: its feet never all leave
## the ground), its legs nearly straight; going faster it ambles, quicker and
## longer, a hind foot coming down almost as the fore foot on its side lifts.
## The body rolls a little from side to side over the planted feet, and the
## head nods with the stride.
##
## THE TRUNK does everything (each eases in and out):
## - at ease it hangs, swinging a little as it walks, its tip always moving;
## - GRAZING: the head goes down, the trunk reaches to the ground in front, its
##   tip curls round a bunch of grass, the trunk curls up and puts it in the
##   mouth (the jaw chews), and again;
## - FEELING: raised and reaching out towards what it watches, its tip turning
##   and sniffing;
## - TRUMPETING: thrown up in an S over its head, the mouth open;
## - LOWERED (a charge): the head down, the tusks forward, the trunk curled
##   back up under the chin out of the way.
## ALERT: the head up, the ears out; EARS OUT: spread (the matriarch's display).
## STAMP: a forefoot lifted and brought down hard.
##
## The hair (MammothLook, "hair") is told how fast it goes and how the body
## moves, and swings with it. Every joint is read from the model's skeleton
## (tools/build_mammoth.py).

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## A grown cow's hip height, for its measure (a model this high is a size of 1).
const HIP := 1.8
## Where in the stride each foot comes down (a lateral walk: hind left, fore left, hind right, fore right).
const LANDS: Array[float] = [0.25, 0.75, 0.0, 0.5]
## The share of the stride a foot is down: walking, ambling.
const DUTY := Vector2(0.7, 0.52)
## Speeds (m/s, for a size of 1) over which it goes from a walk to an amble.
const AMBLE_AT := Vector2(1.6, 3.0)
## Length of a stride (m) against speed (m/s), for a size of 1.
const STRIDE := [0.0, 1.0, 0.8, 1.7, 1.6, 2.5, 3.0, 3.4, 5.0, 4.3, 7.0, 5.2]
## How high a foot is lifted (m, size 1): walking, ambling.
const LIFT := Vector2(0.17, 0.3)
## A stamp, and a grazing mouthful, seconds.
const STAMP_TIME := 0.7
const GRAZE_TIME := 4.6
const TRUNK_BONES := 8

var model_path := "res://creatures/mammoth/models/mammoth.glb"
var low_poly := false
var fur_shells := 1
var coat_tint := Color.WHITE
## The materials, by name (see MammothLook.dress).
var materials := {}
## Posed only every this many frames (1: every one; 2 for one far off, which saves half the work).
var every := 1
var _owed := 0.0
var _frame_count := 0

var _mammoth: Mammoth
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _trunk: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _legs: Array[Array] = []
var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _toes: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _frames: Array[Array] = []
var _size := 1.0
var _tusk_tips: Array[Vector3] = []
var _trunk_tip := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _last_yaw := 0.0
var _turn := 0.0
var _look := Vector2.ZERO
var _graze := 0.0
var _graze_clock := 0.0
var _feel := 0.0
var _alert := 0.0
var _ears_out := 0.0
var _lower := 0.0
var _trumpet := 0.0
var _stamped := 9.0
var _breath := 0.0
var _drag := Vector3.ZERO
var _drag_velocity := Vector3.ZERO
var _was_moving := Vector3.ZERO
var _flap := 0.0
var _flap_in := 3.0


func _ready() -> void:
	_mammoth = get_parent() as Mammoth
	_build()
	_time = randf() * 10.0
	_graze_clock = randf()
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_last_yaw = global_rotation.y
	_turn = 0.0
	_drag = Vector3.ZERO
	_drag_velocity = Vector3.ZERO
	_was_moving = Vector3.ZERO


func stamp() -> void:
	_stamped = 0.0


func busy() -> bool:
	return _stamped < STAMP_TIME


## Where the tips of its tusks are, in the world (none on a calf).
func tusk_tips() -> Array[Vector3]:
	var tips: Array[Vector3] = []
	if _head:
		for at in _tusk_tips:
			tips.append(_head.global_transform * at)
	return tips


## Where the tip of its trunk is, in the world.
func trunk_tip() -> Vector3:
	return _trunk.back().global_transform * _trunk_tip if not _trunk.is_empty() else global_position


func head_position() -> Vector3:
	return _head.global_position if _head else global_position


func _process(delta: float) -> void:
	if _mammoth == null or _skeleton == null:
		return
	# (far off, the game may have it posed only every other frame: `every`)
	_owed += delta
	_frame_count += 1
	if _frame_count < every:
		return
	delta = minf(_owed, 1.0 / 25.0)
	_owed = 0.0
	_frame_count = 0
	_time += delta
	var scale_now := maxf(global_basis.get_scale().x, 0.01)
	var velocity := _mammoth.velocity / scale_now / _size
	var speed := Vector2(velocity.x, velocity.z).length()
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 6.0, delta)
	_last_yaw = yaw

	# --- Moods ---
	_graze = _approach(_graze, 1.0 if _mammoth.grazing and speed < 0.6 else 0.0, 1.6, delta)
	_feel = _approach(_feel, 1.0 if _mammoth.feeling else 0.0, 2.2, delta)
	_alert = _approach(_alert, 1.0 if _mammoth.alert else 0.0, 3.0, delta)
	_ears_out = _approach(_ears_out, 1.0 if _mammoth.ears_out else 0.0, 5.0, delta)
	_lower = _approach(_lower, 1.0 if _mammoth.lowered else 0.0, 3.5, delta)
	_trumpet = _approach(_trumpet, 1.0 if _mammoth.trumpeting() and _mammoth.trumpet_progress() < 0.85 else 0.0, 6.0 if _mammoth.trumpeting() else 2.0, delta)
	_stamped += delta

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.8), 6.0, delta)
	var amble := smoothstep(AMBLE_AT.x, AMBLE_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	if _mammoth.grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.03, 0.3, _pace)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var duty := lerpf(DUTY.x, DUTY.y, amble)
	var lift := lerpf(LIFT.x, LIFT.y, amble) * _size
	var targets: Array[Vector3] = []
	var flexes: Array[float] = []
	var load_left := 0.0
	var load_right := 0.0
	var load_fore := 0.0
	var load_hind := 0.0
	for i in 4:
		var at := fposmod(_phase - LANDS[i], 1.0)
		var span := minf(duty * stride * _size, 1.6 * _size) * travel
		var toe := _toes[i]
		var z := 0.0
		var y := 0.0
		var flex := 0.0
		if at < duty:
			z = lerpf(span * 0.5, -span * 0.5, at / duty)
			var bearing := sin(PI * at / duty)
			if i % 2 == 0:
				load_left += bearing
			else:
				load_right += bearing
			if i < 2:
				load_fore += bearing
			else:
				load_hind += bearing
		else:
			var swing := (at - duty) / (1.0 - duty)
			z = lerpf(-span * 0.5, span * 0.5, smoothstep(0.0, 1.0, swing))
			y = sin(PI * pow(swing, 0.8)) * lift
			# (the foot curls back as it lifts, the sole turned up behind, and flat again to land)
			flex = sin(PI * clampf(swing * 1.3, 0.0, 1.0)) * lerpf(0.55, 0.8, amble)
		targets.append(Vector3(toe.x, toe.y + y * gait, toe.z + z * gait))
		flexes.append(flex * gait)

	# The body: rolls over the planted feet, nods with the stride, sinks a little walking fast
	var roll := (load_left - load_right) * 0.018 * gait
	var pitch := (load_hind - load_fore) * 0.012 * gait
	var bob := (sin(TAU * _phase * 2.0) * 0.012 - 0.03 * amble) * _size * gait
	var bank := clampf(-_turn * speed * 0.02, -0.06, 0.06)
	var body_turn := Vector3(pitch, 0.0, roll + bank)
	var body_at := _body_rest + Vector3(0.0, bob, 0.0)
	# Grazing and lowered: the front of it a little down; alert or trumpeting, up
	body_turn.x += 0.03 * _graze + 0.05 * _lower - 0.025 * maxf(_alert, _trumpet)
	body_at.y -= 0.04 * _size * _lower

	# The stamp: a forefoot up, and down hard
	if _stamped < STAMP_TIME:
		var u := _stamped / STAMP_TIME
		var raised := sin(PI * clampf(u / 0.6, 0.0, 1.0)) if u < 0.6 else 0.0
		targets[0] += Vector3(0.0, 0.55 * _size * raised, 0.25 * _size * raised)
		flexes[0] += 0.5 * raised
		body_turn.x -= 0.06 * raised
		body_at.y += 0.02 * _size * raised

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = Vector3(0.0, clampf(_turn * 0.05, -0.08, 0.08), -roll * 0.5)
	_pelvis.rotation = Vector3(0.0, -clampf(_turn * 0.04, -0.06, 0.06), roll * 0.6)
	_breathe(delta)
	_look_about(delta)
	_pose_head(gait, amble)
	_pose_trunk(delta, gait, speed)
	_pose_jaw()
	_pose_ears(delta)
	_pose_tail(delta, gait)
	_pose_legs(targets, flexes)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing_hair(delta, velocity * _size, speed)


## Its ribs, slow and deep; quicker after it has run.
func _breathe(delta: float) -> void:
	_breath += delta * TAU * lerpf(0.18, 0.5, _lower)
	var swell := sin(_breath) * 0.008
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## Head and neck: turned to what it watches (a mammoth's neck turns little),
## nodding with the stride; down grazing and charging, up alert and trumpeting.
func _pose_head(gait: float, amble: float) -> void:
	var yaw := clampf(_look.x, -0.7, 0.7) * (1.0 - _lower * 0.6)
	var pitch := clampf(_look.y, -0.35, 0.3) * (1.0 - _graze) * (1.0 - _lower) * (1.0 - _trumpet)
	var nod := sin(TAU * (_phase * 2.0 - 0.15)) * 0.025 * gait * (1.0 + amble)
	pitch += nod
	pitch += 0.30 * _graze + 0.42 * _lower - 0.18 * _alert - 0.32 * _trumpet + 0.06 * _feel
	_neck.rotation = Vector3(pitch * 0.45, yaw * 0.45, 0.0)
	_head.rotation = Vector3(pitch * 0.55, yaw * 0.55, sin(_time * 0.31) * 0.02 + sin(_time * 3.0) * 0.04 * _trumpet)


## The trunk: a curl for each of its bones (about its side-to-side axis:
## forward is up and out, back is under), and a sideways swing, mixed from
## every mood it is in.
func _pose_trunk(delta: float, gait: float, speed: float) -> void:
	var curl: Array[float] = []
	var side: Array[float] = []
	curl.resize(TRUNK_BONES)
	side.resize(TRUNK_BONES)
	var ease := 1.0 - maxf(maxf(_graze, _feel), maxf(_trumpet, _lower))
	_graze_clock += delta / GRAZE_TIME * _graze
	var g := fposmod(_graze_clock, 1.0)
	# Grazing: reach to the ground ahead, curl the tip round the grass, curl up to the mouth, chew
	var reach := 1.0 - smoothstep(0.38, 0.55, g)
	var grab := smoothstep(0.26, 0.38, g) * (1.0 - smoothstep(0.72, 0.95, g))
	var up := smoothstep(0.42, 0.62, g) * (1.0 - smoothstep(0.85, 1.0, g))
	for i in TRUNK_BONES:
		var t := float(i) / (TRUNK_BONES - 1)
		# At ease: hanging, swinging as it walks, the tip always moving
		var c := (sin(_time * 0.6 + i * 0.35) * 0.03 + sin(TAU * _phase) * 0.05 * gait * t - 0.02 * speed * t) * ease
		var s := (sin(_time * 0.45 + i * 0.5) * 0.035 * t + sin(_time * 1.7 + i) * 0.03 * t * t) * ease
		c += (sin(_time * 2.3 + i * 0.9) * 0.08 * t * t) * ease
		# Grazing
		var graze_curl := (-0.32 if i == 0 else -0.05) * reach + (0.85 if i >= 5 else 0.0) * grab + (0.36 if i > 0 else 0.1) * up
		c += graze_curl * _graze
		# Feeling: raised and reaching out to what it watches, the tip sniffing
		var feel_curl: float = [-0.55, -0.32, -0.25, -0.2, -0.15, -0.1, -0.05, 0.1][i] + sin(_time * 6.5 + i * 1.3) * 0.07 * t
		c += feel_curl * _feel
		s += clampf(_look.x, -0.8, 0.8) * 0.06 * _feel + sin(_time * 4.1 + i) * 0.05 * t * _feel
		# Trumpeting: thrown up in an S over its head, trembling
		var trumpet_curl: float = [-0.78, -0.55, -0.45, -0.38, -0.3, -0.18, 0.12, 0.42][i] + sin(_time * 31.0 + i) * 0.015
		c += trumpet_curl * _trumpet
		# Lowered: curled back up under its chin
		var tucked: float = [0.22, 0.38, 0.4, 0.36, 0.3, 0.25, 0.22, 0.2][i]
		c += tucked * _lower
		curl[i] = c
		side[i] = s
	for i in TRUNK_BONES:
		_trunk[i].basis = Basis(Vector3.BACK, side[i]) * Basis(Vector3.RIGHT, curl[i])


## The jaw (the lower lip): open to trumpet, chewing after a mouthful.
func _pose_jaw() -> void:
	var g := fposmod(_graze_clock, 1.0)
	var chew := smoothstep(0.6, 0.7, g) * (0.5 + 0.5 * sin(_time * 9.0)) * _graze
	_jaw.rotation.x = 0.28 * _trumpet + 0.07 * chew


## The ears: lying back against the head, flapping now and then; spread out wide in a display.
func _pose_ears(delta: float) -> void:
	_flap_in -= delta
	if _flap_in <= 0.0:
		_flap_in = randf_range(3.0, 8.0)
		_flap = 1.0
	_flap = maxf(_flap - delta * 2.2, 0.0)
	var flap := sin(PI * _flap * 2.0) * 0.25 * _flap
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var spread := 0.85 * _ears_out + 0.25 * _alert + flap
		_ears[side].rotation = Vector3(-0.1 * _ears_out, out * spread, out * 0.15 * _ears_out)


func _pose_tail(delta: float, gait: float) -> void:
	var swish := sin(_time * 1.3) * 0.25 + sin(TAU * _phase) * 0.12 * gait
	_tail[0].rotation = Vector3(-0.15 * _alert + 0.3 * _lower, 0.0, swish)
	_tail[1].rotation = Vector3(0.0, 0.0, swish * 0.8)


func _pose_legs(targets: Array[Vector3], flexes: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 4:
		var fore := i < 2
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - spine.position)
		var toe := to_body * targets[i]
		_solve_leg(i, hip, toe, flexes[i], to_body.basis)


## The leg from its hip (or shoulder) to the toe: the foot stood up from the
## ground (curled back by `flex`), and the two long bones between the hip and the
## wrist (or ankle) folding as an elephant's do.
func _solve_leg(index: int, hip: Vector3, toe: Vector3, flex: float, to_body: Basis) -> void:
	var lengths := _lengths[index]
	var fore := index < 2
	var up := (to_body * Vector3.UP).normalized()
	var forward := (to_body * AHEAD).normalized()
	var wrist := toe + (up * cos(flex) + forward * sin(flex)) * lengths.z
	var to := wrist - hip
	var reach := clampf(to.length(), absf(lengths.x - lengths.y) + 0.02 * _size, lengths.x + lengths.y - 0.002 * _size)
	var line := to.normalized() if to.length_squared() > 0.0001 else Vector3.DOWN
	wrist = hip + line * reach
	var pole := BEHIND if fore else AHEAD
	var aside := (pole - line * pole.dot(line))
	aside = aside.normalized() if aside.length_squared() > 0.0001 else pole
	var bend := acos(clampf((lengths.x * lengths.x + reach * reach - lengths.y * lengths.y) / (2.0 * lengths.x * reach), -1.0, 1.0))
	var elbow := hip + (line * cos(bend) + aside * sin(bend)) * lengths.x
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	var normal := Vector3.RIGHT
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (elbow - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (wrist - elbow).normalized()) * frames[1], elbow)
	var foot_way := (toe - wrist).normalized() if (toe - wrist).length_squared() > 0.0001 else -up
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, foot_way) * frames[2], wrist)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it watches (the Mammoth's `look_at_point`), or lets it gaze about.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _mammoth.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.2, 1.2)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.4)
	else:
		target.x = sin(_time * 0.23) * 0.2 + sin(_time * 0.61 + 1.0) * 0.08
		target.y = sin(_time * 0.19 + 2.0) * 0.05
	_look = _look.lerp(target, 1.0 - exp(-2.5 * delta))


## The guard hair: its pace, and the body's movement for its ends to lag behind.
func _swing_hair(delta: float, velocity: Vector3, speed: float) -> void:
	if not materials.has("hair"):
		return
	var local := global_basis.orthonormalized().inverse() * velocity
	var accel := (local - _was_moving) / maxf(delta, 0.001)
	_was_moving = local
	# (the ends stream back as it goes, and swing on as it stops or turns)
	var want := (-local * 0.02 - accel * 0.025).limit_length(0.25 * _size)
	_drag_velocity += ((want - _drag) * 28.0 - _drag_velocity * 5.0) * delta
	_drag += _drag_velocity * delta
	var material := materials["hair"] as ShaderMaterial
	material.set_shader_parameter(&"sway", clampf(speed * 0.01, 0.0, 0.06) * _size)
	material.set_shader_parameter(&"drag", _drag)


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Reads a curve drawn by hand: (time, value) pairs, joined straight.
static func _keyed(keys: Array, time: float) -> float:
	var last := keys.size() / 2 - 1
	if time <= keys[0]:
		return keys[1]
	for k in last:
		var t1: float = keys[k * 2 + 2]
		if time <= t1:
			var t0: float = keys[k * 2]
			return lerpf(keys[k * 2 + 1], keys[k * 2 + 3], (time - t0) / (t1 - t0))
	return keys[last * 2 + 1]


func _build() -> void:
	var model: Node = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = MammothLook.dress(model, coat_tint, 0 if low_poly else fur_shells)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_head = _joint(_neck, &"head")
	_jaw = _joint(_head, &"jaw")
	var from := _head
	for i in TRUNK_BONES:
		from = _joint(from, "trunk_%d" % i)
		_trunk.append(from)
	_trunk_tip = _rest(&"trunk_end")
	for suffix: String in ["_l", "_r"]:
		_ears.append(_joint(_head, "ear" + suffix))
		if _skeleton.find_bone("tusk" + suffix) >= 0:
			_tusk_tips.append(_rest("tusk" + suffix))
	_tail.append(_joint(_pelvis, &"tail"))
	_tail.append(_joint(_tail[0], &"tail_1"))
	for i in 4:
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "foot"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		var toe := _body_rest + _rest("foot" + SUFFIXES[i]) + _rest("toe" + SUFFIXES[i])
		_legs.append(bones)
		_hips.append(at[0] - _body_rest)
		_toes.append(toe)
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(toe)))
		var normal := Vector3.RIGHT
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, (toe - at[2]).normalized()).inverse(),
		])
	_size = (_body_rest + _rest(&"upper_rl")).y / HIP


func _rest(bone: StringName) -> Vector3:
	var index := _skeleton.find_bone(bone)
	return _skeleton.get_bone_rest(index).origin if index >= 0 else Vector3.ZERO


func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var joint := Node3D.new()
	var index := _skeleton.find_bone(bone)
	joint.name = bone
	joint.position = _skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint
