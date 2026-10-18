class_name StegosaurusRig
extends Node3D
## Poses the stegosaurus (creatures/stegosaurus/models/stegosaurus*.glb) in
## code, every frame, from what its Stegosaurus (the parent) says it is doing.
## Its feet follow a gait cycle and are put down with IK, each one staying
## where it was put down on the ground until it is lifted again (so nothing
## slides, turning or walking); the spine, neck, head, jaw and tail are laid on
## top.
##
## THE WALK: slow and heavy, four beats (hind, fore on that side, the other
## hind, its fore: the walk of an elephant), each foot down nearly three
## quarters of the stride and lifted only a little. Each step is felt through
## it: the hip over the lifted foot sags, the body rolls and shifts its weight
## from side to side, the hips and shoulders swing against each other, and the
## tail sways behind, a stride behind them. Faster (`AMBLE_AT`), the feet are
## down less and it rocks more. Turning on the spot, it steps round.
## (`footfall` as each foot comes down.)
##
## WHAT IT DOES, on top of the walk (each eases in and out):
## - GRAZING: neck down, beak to the ground (as low as it must go to reach,
##   found as it goes), cropping: a tug back of the head, the jaw working.
## - LOOKING: its head (low, it cannot lift it high) turned to `look_at_point`.
## - WARNING: side on to whoever it is warning (`threat_side` says which side
##   they are on), its head low and turned to them, its weight back over its
##   braced hind legs and rolled a little to show them the plates, its tail
##   raised and cocked away from them, swaying slowly from side to side so
##   that the spikes wave.
## - THE SWING (`swing(side)`): the tail is drawn back further, away, and
##   then whipped round across behind it and out to that side, low (the
##   spikes at a man's chest), the hips thrown round with it, and swings back.
##   `swept` as the spikes come through; `sweeping()` while they are dangerous.
## - RUMBLE and BELLOW: the throat flutters and the jaw parts (the Stegosaurus
##   plays the sound); a bellow lifts the head and opens the jaw wide.
##
## Every joint is read from the model's skeleton (tools/build_stegosaurus.py).

## A foot has come down: where, and how hard (0..1).
signal footfall(at: Vector3, weight: float)
## The spikes are coming through the middle of a swing.
signal swept

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## Where in the stride each foot is put down (a lateral walk: hind, fore, hind, fore).
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
## The share of the stride a foot is down, walking and ambling.
const DUTY := Vector2(0.74, 0.6)
## Speeds (m/s, in the model) over which it goes from a walk to an amble.
const AMBLE_AT := Vector2(1.5, 2.4)
## Length of a stride (m, in the model) against speed (m/s).
const STRIDE := [0.0, 1.1, 0.5, 1.5, 1.2, 2.2, 2.0, 2.8, 3.0, 3.4]
## How far a foot reaches, at most, before or behind where it stands (fore, hind).
const REACH := Vector2(0.7, 0.85)
## How high a foot is lifted, walking (fore, hind), m.
const LIFT := Vector2(0.14, 0.17)
## How the zigzag of each leg folds as it shortens: planted, and lifted (fore, hind).
const FOLD := Vector2(2.0, 1.5)
const FOLD_PLANTED := Vector2(-0.15, 0.5)
## How far the jaw drops, wide open, radians.
const GAPE := 0.5
## A swing of the tail: how long it takes, and when in it the spikes are dangerous.
const SWING_TIME := 1.45
const WHIP := Vector2(0.42, 0.80)
## How the tail goes in a swing (time, how far round towards the side swung to:
## 1 is right round, out to the side; below 0 drawn back the other way).
const SWING_YAW := [0.0, -0.45, 0.30, -0.95, 0.40, -0.92, 0.52, -0.1, 0.62, 0.95, 0.78, 1.12, 1.0, 0.8, SWING_TIME, 0.0]
## And how it is pitched (up raised, down low: down through the whip, the spikes at chest height).
const SWING_PITCH := [0.0, 0.12, 0.30, 0.22, 0.42, 0.02, 0.58, -0.17, 0.80, -0.15, 1.1, -0.05, SWING_TIME, 0.0]
## How much of a turn of the tail each of its six bones takes (base to tip).
const TAIL_SHARE: Array[float] = [0.11, 0.15, 0.18, 0.2, 0.19, 0.17]
## Each bone of the tail lags the one before it by this (s): the whip.
const TAIL_LAG := 0.04
## How far round the whole tail bends (radians) for a turn of it of 1.
const TAIL_BEND := 1.15
const RUMBLE_TIME := 2.4
const BELLOW_TIME := 1.9
## Where the tip of its beak is, in the head's space.
const BEAK := Vector3(0.0, -0.085, 0.52)
## The spikes (their roots and points), in the space of the last bone of the tail.
const SPIKES: Array[Vector3] = [
	Vector3(0.05, 0.154, 0.43), Vector3(0.595, 0.621, 0.243),
	Vector3(0.036, 0.02, -0.07), Vector3(0.536, 0.351, -0.651),
]

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
var skin_tint := Color.WHITE
## Scales to a metre of its hide (a calf: more).
var scales := 11.0
var eyeshine := 0.2
## The materials, by name (see StegosaurusLook.dress).
var materials := {}

var _steg: Stegosaurus
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _neck_1: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Array[Node3D] = []
var _legs: Array[Array] = []

var _body_rest := Vector3.ZERO
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
var _down: Array[bool] = [true, true, true, true]
## Where each foot was put down (in the world), and where a lifted one left the ground.
var _plant: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _lifted_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _planted := false
var _drop := 0.0
var _mouth := 0.0
var _breath := 0.0
var _look := Vector2.ZERO
var _alert := 0.0
## How far into each mood it is, 0..1.
var _graze := 0.0
var _warn := 0.0
var _side := 1.0
## Grazing: how far down its neck must go to put its beak on the ground (found as it goes), and its cropping.
var _dip := 0.4
var _crop := 0.0
## Seconds since each act began (large: not doing it).
var _swung := 99.0
var _swing_side := 1.0
var _swept := true
var _rumbled := 99.0
var _bellowed := 99.0


func _ready() -> void:
	_steg = get_parent() as Stegosaurus
	_build()
	_time = randf() * 10.0
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_planted = false
	_last_yaw = global_rotation.y
	_turn = 0.0
	_pace = 0.0


## Swings its tail round at whoever is on `side` (1: its left).
func swing(side: float) -> void:
	_swung = 0.0
	_swing_side = signf(side) if side != 0.0 else 1.0
	_swept = false


func swinging() -> bool:
	return _swung < SWING_TIME


## Whether the spikes are coming round now, fast enough to hurt.
func sweeping() -> bool:
	return _swung >= WHIP.x and _swung <= WHIP.y


func rumble() -> void:
	_rumbled = 0.0


func bellow() -> void:
	_bellowed = 0.0


## The line of the end of its tail (from its middle to its tip), in the world.
func tail_line() -> PackedVector3Array:
	var made := PackedVector3Array()
	for i in range(1, _tail.size()):
		made.append(_tail[i].global_position)
	return made


## The tips of its four spikes, in the world (left front, left back, right front, right back).
func spike_tips() -> PackedVector3Array:
	var made := PackedVector3Array()
	if _tail.size() < 6:
		return made
	var last := _tail[5].global_transform
	for side: float in [1.0, -1.0]:
		for k in 2:
			var tip := SPIKES[k * 2 + 1]
			made.append(last * Vector3(tip.x * side, tip.y, tip.z))
	return made


## How near `point` (in the world) is to its tail's end or its spikes (m).
func tail_gap(point: Vector3) -> float:
	if _tail.size() < 6:
		return INF
	var near := INF
	var line := tail_line()
	for i in line.size() - 1:
		near = minf(near, _to_segment(point, line[i], line[i + 1]))
	var last := _tail[5].global_transform
	for side: float in [1.0, -1.0]:
		for k in 2:
			var root := SPIKES[k * 2]
			var tip := SPIKES[k * 2 + 1]
			near = minf(near, _to_segment(point, last * Vector3(root.x * side, root.y, root.z), last * Vector3(tip.x * side, tip.y, tip.z)))
	return near


## Where the tip of its beak is, in the world.
func beak_tip() -> Vector3:
	return _head.global_transform * BEAK if _head else global_position


## The head joint, for anything that should go with it (its breath).
func head() -> Node3D:
	return _head


## Where its hips are (the pivot of a swing), in the world.
func hips() -> Vector3:
	return _pelvis.global_position if _pelvis else global_position


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _process(delta: float) -> void:
	if _steg == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var size := maxf(global_basis.get_scale().x, 0.01)
	var velocity := _steg.velocity / size
	var speed := Vector2(velocity.x, velocity.z).length()
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 6.0, delta)
	_last_yaw = yaw
	if not _planted:
		_planted = true
		for i in 4:
			_plant[i] = global_transform * _feet[i]
			_lifted_at[i] = _plant[i]

	# --- Moods ---
	_swung += delta
	_rumbled += delta
	_bellowed += delta
	var swinging_now := _swung < SWING_TIME
	_graze = _approach(_graze, 1.0 if _steg.grazing and not _steg.warning and not swinging_now else 0.0, 1.6, delta)
	_warn = _approach(_warn, 1.0 if _steg.warning or swinging_now else 0.0, 3.0, delta)
	if _steg.warning and not swinging_now:
		_side = lerpf(_side, signf(_steg.threat_side) if _steg.threat_side != 0.0 else _side, 1.0 - exp(-3.0 * delta))
	elif swinging_now:
		_side = lerpf(_side, _swing_side, 1.0 - exp(-12.0 * delta))
	_alert = _approach(_alert, 1.0 if _steg.look_at_point.is_finite() else 0.0, 3.0, delta)
	if not _swept and _swung >= (WHIP.x + WHIP.y) * 0.5:
		_swept = true
		swept.emit()

	# --- The walk ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 1.8), 4.0, delta)
	var amble := smoothstep(AMBLE_AT.x, AMBLE_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.03, 0.25, _pace)
	var duty := lerpf(DUTY.x, DUTY.y, amble)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var to_model := global_transform.affine_inverse()
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var lifted: Array[float] = []
	for i in 4:
		var fore := i < 2
		var rest := _feet[i]
		# (the swing pulls a hind foot back and out a little to brace it)
		var braced := rest + Vector3(signf(rest.x) * 0.12 * _warn, 0.0, 0.0 if fore else -0.05 * _warn)
		var reach: float = REACH.x if fore else REACH.y
		var span := minf(duty * stride, reach * 2.0) * travel
		var landing := braced + Vector3(0.0, 0.0, span * 0.5)
		var at := fposmod(_phase - WALK[i], 1.0)
		var target: Vector3
		var up := 0.0
		if at < duty or gait < 0.01:
			if not _down[i]:
				_down[i] = true
				_plant[i] = global_transform * landing
				if gait > 0.3:
					footfall.emit(_plant[i], clampf(0.35 + _pace * 0.25, 0.0, 1.0) * size)
			target = to_model * _plant[i]
		else:
			if _down[i]:
				_down[i] = false
				_lifted_at[i] = _plant[i]
			var u := (at - duty) / (1.0 - duty)
			var from := to_model * _lifted_at[i]
			target = from.lerp(landing, smoothstep(0.0, 1.0, u))
			up = sin(PI * pow(u, 0.8))
			target.y = rest.y + up * (LIFT.x if fore else LIFT.y) * lerpf(1.0, 1.25, amble) * gait
		if at < duty or gait < 0.01:
			target.y = rest.y
		# (standing, its feet come to stand where they should; a foot far out of place steps)
		if gait < 0.5:
			var settled := braced.lerp(target, gait * 2.0)
			if gait < 0.02:
				settled = target.lerp(braced, 1.0 - exp(-1.5 * delta))
				_plant[i] = global_transform * Vector3(settled.x, rest.y, settled.z)
			target = settled
		targets.append(target)
		pitches.append(lerpf(0.0, 0.5, up) * (1.0 if fore else 0.7))
		lifted.append(up)

	# Each hip sags as the foot under it is lifted; the body rolls and shifts its weight.
	var sag_fore := (lifted[0] + lifted[1]) * 0.5
	var sag_hind := (lifted[2] + lifted[3]) * 0.5
	var heave := lerpf(1.0, 1.6, amble) * gait
	var roll_hind := (lifted[3] - lifted[2]) * 0.045 * heave
	var roll_fore := (lifted[1] - lifted[0]) * 0.035 * heave
	var shift := sin(TAU * (_phase - 0.1)) * 0.04 * heave
	var swing_hind := (targets[3].z - targets[2].z) * 0.10
	var swing_fore := (targets[1].z - targets[0].z) * 0.08
	var bank := clampf(-_turn * speed * 0.01, -0.08, 0.08)
	var body_at := _body_rest + Vector3(shift, -_drop - (sag_hind * 0.035 + sag_fore * 0.02) * heave, 0.0)
	var body_turn := Vector3((sag_hind - sag_fore) * 0.012 * heave, 0.0, (roll_hind + roll_fore) * 0.5 + bank)
	var chest_turn := Vector3(0.0, swing_fore * 0.5, roll_fore - roll_hind * 0.3)
	var pelvis_turn := Vector3(0.0, swing_hind, roll_hind * 0.6)

	# Warning: its weight back over its braced hind legs, rolled a little towards them to show its plates.
	body_turn.x -= 0.03 * _warn
	body_turn.z -= 0.05 * _warn * _side
	body_at.y -= 0.05 * _warn
	# The swing: the hips thrown round with the tail, the shoulders twisting against them.
	if _swung < SWING_TIME:
		var whip := _keyed(SWING_YAW, _swung)
		pelvis_turn.y += -_swing_side * whip * 0.36
		chest_turn.y += _swing_side * whip * 0.06
		body_turn.z -= _swing_side * whip * 0.035
		body_at.x += _swing_side * whip * 0.06
	# Grazing: the front of it lower.
	body_turn.x += 0.03 * _graze
	# Breathing, and the rumble in its chest.
	_breath += delta * TAU * lerpf(0.18, 0.4, smoothstep(1.0, 2.5, _pace))
	var swell := sin(_breath) * 0.012
	var rumbling := 0.0
	if _rumbled < RUMBLE_TIME:
		rumbling = smoothstep(0.0, 0.2, _rumbled) * (1.0 - smoothstep(RUMBLE_TIME * 0.7, RUMBLE_TIME, _rumbled))
		swell += sin(_time * TAU * 11.0) * 0.006 * rumbling
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, rumbling, gait)
	_pose_jaw(rumbling)
	_pose_tail(gait, delta)
	_pose_legs(targets, pitches, lifted)
	# (it never sinks far to reach: the legs are columns)
	_drop = _approach(_drop, 0.0, 4.0, delta)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_measure_beak(delta)


## Head and neck: carried low and turned to what it watches; beak to the
## ground grazing, with the tug of cropping; low and turned to its threat
## warning; lifted bellowing.
func _pose_head(delta: float, upstream: float, rumbling: float, gait: float) -> void:
	_crop += delta * 0.65
	var tug := smoothstep(0.7, 0.8, fposmod(_crop, 1.0)) * (1.0 - smoothstep(0.84, 1.0, fposmod(_crop, 1.0)))
	var yaw := _look.x * (1.0 - _graze * 0.8)
	var pitch := _look.y * (1.0 - _graze)
	# Beak to the ground, to the depth found for it; the head tugs back cropping, and swings a little between bites.
	pitch += (_dip - 0.12 * tug) * _graze
	yaw += sin(_crop * TAU * 0.5) * 0.18 * _graze
	# Warning: the head low.
	pitch += 0.12 * _warn
	# Bellowing: head up, a little.
	if _bellowed < BELLOW_TIME:
		pitch -= sin(PI * minf(_bellowed / 0.4, 1.0) * 0.5) * (1.0 - smoothstep(BELLOW_TIME * 0.7, BELLOW_TIME, _bellowed)) * 0.35
	# (a little nod with each step, against the heave of the body)
	pitch += sin(TAU * _phase * 2.0) * 0.02 * gait
	var neck := Vector3(-upstream * 0.7 + pitch * 0.6, yaw * 0.55, 0.0)
	var head_turn := Vector3(-upstream * 0.3 + pitch * 0.4, yaw * 0.45, 0.0)
	head_turn.x += sin(_time * TAU * 13.0) * 0.006 * rumbling
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_neck_1.scale = Vector3(1.0 + 0.02 * rumbling * sin(_time * TAU * 9.0), 1.0, 1.0)
	_head.rotation = head_turn


## Grazing, it finds how far down its neck must go to put its beak on the
## ground, from where the beak was last frame (so it reaches the ground
## whatever its legs and body are doing).
func _measure_beak(delta: float) -> void:
	if _graze < 0.02:
		_dip = _approach(_dip, 0.6, 2.0, delta)
		return
	var ground := (get_parent() as Node3D).global_position.y
	var above := (beak_tip().y - ground) / maxf(global_basis.get_scale().y, 0.01) - 0.05
	_dip = clampf(_dip + above * 1.2 * delta / maxf(_graze, 0.3), 0.0, 1.9)


## The jaw: working as it crops, parted in a rumble, wide in a bellow.
func _pose_jaw(rumbling: float) -> void:
	var open := _graze * (0.08 + 0.08 * sin(_crop * TAU * 2.0))
	open = maxf(open, rumbling * (0.18 + 0.05 * sin(_time * 21.0)))
	if _bellowed < BELLOW_TIME:
		var u := _bellowed / BELLOW_TIME
		open = maxf(open, smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u)) * 0.85)
	open = maxf(open, _warn * 0.06)
	_mouth = lerpf(_mouth, open, 0.4)
	_jaw.rotation.x = _mouth * GAPE


## The tail: held out behind, swaying a stride behind the hips as it walks;
## raised and cocked away from its threat, waving, warning; whipped round in a swing.
func _pose_tail(gait: float, delta: float) -> void:
	for i in _tail.size() - 1:
		var share := TAIL_SHARE[i]
		var sway := sin(TAU * _phase - 1.2 - i * 0.45) * 0.035 * gait + sin(_time * 0.45 - i * 0.5) * 0.02
		# (warning: drawn away from them, the spikes waving slowly from side to side)
		var wave := (sin(_time * 1.5 - i * 0.35) * 0.3 - 0.45) * _warn
		var yaw := sway - _side * wave * share * TAIL_BEND
		# (positive pitch lifts a bone that points back)
		var pitch := (0.14 if i == 0 else 0.02) * _warn
		if _swung < SWING_TIME:
			var lagged := _swung - i * TAIL_LAG
			yaw = sway * 0.3 - _swing_side * _keyed(SWING_YAW, lagged) * share * TAIL_BEND
			pitch = _keyed(SWING_PITCH, lagged) * (0.55 if i == 0 else 0.12)
		var aim := Vector3(pitch, yaw, 0.0)
		# (out of a swing it eases back to how it is held, not at once)
		_tail[i].rotation = aim if _swung < SWING_TIME else _tail[i].rotation.lerp(aim, 1.0 - exp(-5.0 * delta))


func _pose_legs(targets: Array[Vector3], pitches: Array[float], lifted: Array[float]) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 4:
		var fore := i < 2
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var foot := to_body * targets[i]
		var pole := to_body.basis * (BEHIND if fore else AHEAD)
		_solve_leg(i, hip, foot, to_body.basis * Basis(Vector3.RIGHT, pitches[i]), pole, lifted[i])


## Three-bone IK in body space, folding in a zigzag (as BoarRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, foot_basis: Basis, pole: Vector3, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, total - 0.006)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var foot := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	var fore := index < 2
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		bend += (span - reach) / span * lerpf(FOLD_PLANTED.x if fore else FOLD_PLANTED.y, FOLD.x if fore else FOLD.y, lifted)
	var last := line * cos(bend) + aside * sin(bend)
	var far := lengths.x + lengths.y - 0.004
	var near := absf(lengths.x - lengths.y) + 0.02
	var second := foot - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = foot - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	foot = second + last * lengths.z
	var off := aside - along * aside.dot(along)
	off = off.normalized() if off.length_squared() > 0.0001 else aside
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + off * sin(fold)) * lengths.x
	var normal := aside.cross(line).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(foot_basis, foot)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Stegosaurus's
## `look_at_point`), or lets it gaze about.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _steg.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.1, 1.1)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.4, 0.4)
	else:
		target.x = sin(_time * 0.21) * 0.3 + sin(_time * 0.53 + 1.0) * 0.1
		target.y = 0.05 + sin(_time * 0.17 + 2.0) * 0.06
	_look = _look.lerp(target, 1.0 - exp(-(2.5 if _alert > 0.5 else 1.0) * delta))


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
	var t0: float = keys[k * 2]
	var t1: float = keys[k * 2 + 2]
	var v0: float = keys[k * 2 + 1]
	var v1: float = keys[k * 2 + 3]
	var m0: float = (v1 - keys[k * 2 - 1]) / (t1 - keys[k * 2 - 2]) if k > 0 else 0.0
	var m1: float = (keys[k * 2 + 5] - v0) / (keys[k * 2 + 4] - t0) if k < last - 1 else 0.0
	var span := t1 - t0
	var u := (time - t0) / span
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * span * m1


func _build() -> void:
	var path := "res://creatures/stegosaurus/models/stegosaurus%s.glb" % ("_lo" if low_poly else "")
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = StegosaurusLook.dress(model, skin_tint, scales, eyeshine)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	var from := _pelvis
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
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])


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
