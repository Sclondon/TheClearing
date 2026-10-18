class_name BoarRig
extends Node3D
## Poses the giant boar (creatures/boar/models/boar*.glb) in code, every frame,
## from what its Boar (the parent) says it is doing. The dogs' rig (DogRig)
## made heavy: hooves follow a gait cycle and are put down with IK, and the
## spine, neck, head and jaw are laid on top; the tail, the ears and the
## strings of slobber are on springs.
##
## THE GAITS, chosen by its speed: a four-beat walk, a trot on diagonal pairs,
## and a rotary gallop (hind, hind, fore, fore) in which each leg is flung out
## behind as it leaves the ground and reaches out ahead before it lands, the
## back gathering and stretching once a stride. It is heavy: its hooves are
## down longer than a dog's, it is barely off the ground between strides, and
## each hoof lands with a jolt that runs up through it (`footfall`).
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - ROOTING: snout to the ground, ploughing: it shoves the disc of its nose
##   forward through the mud, flicks it up and shoves again, the head swinging
##   from side to side, the jaw working.
## - SNIFFING: head up, snout lifted into the air, the disc twitching (quick
##   small jerks of the head), turning slowly to find the wind; ears forward.
## - LOWERED: head down and tusks forward, the weight forward over braced
##   forelegs, ears back: the wind-up, and the charge.
## - SNORT, GRUNT, SQUEAL: the head jerks, the jaw keeps time with the voice
##   it would have (the Boar plays it), the chest heaves.
## - STAMP: a forehoof lifts, strikes and paws back through the ground (`struck`).
## - SKID: when it is slowing hard it braces its forelegs out ahead and sits
##   back on its haunches, sliding.
## - SLAM: running into something: it is stopped dead, its head snapped up
##   and back and its body jolted.
## - STUNNED: afterwards, head hanging, swaying, legs splayed, shaking its head.
## - TOSS: a hooking heave of the head, down, then up and to one side.
## - Hackles: the Boar sets the crest material's `bristle`.
##
## Every joint is read from the model's skeleton (tools/build_boar.py).

## A hoof has come down hard: where, and how hard (0..1: a walk is light, a gallop heavy).
signal footfall(at: Vector3, weight: float)
## A stamp has struck the ground, at `at`.
signal struck(at: Vector3)

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## Where in the stride each hoof lands, walking, trotting and galloping.
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const TROT: Array[float] = [0.5, 1.0, 0.0, 0.5]
const GALLOP: Array[float] = [0.6, 0.5, 0.0, 0.1]
## The share of the stride a hoof is down, fore and hind, at a walk, a trot and a gallop.
const DUTY_FORE := Vector3(0.66, 0.50, 0.32)
const DUTY_HIND := Vector3(0.63, 0.46, 0.30)
## The middle of the first of the two flights of a gallop stride, and how high it is thrown in them.
const FLIGHT := 0.405
const BOUND := 0.05
## Speeds (m/s, in the model) over which it goes from a walk to a trot, and a trot to a gallop.
const TROT_AT := Vector2(0.9, 1.3)
const GALLOP_AT := Vector2(1.9, 2.5)
## Length of a stride (m, in the model) against speed (m/s).
const STRIDE := [0.0, 0.40, 0.8, 0.62, 1.8, 0.95, 2.8, 1.35, 4.0, 1.75, 7.0, 2.4]
const REACH := 0.40
## Galloping: how much further a hoof may sweep under it, how far past where it
## lands a hoof reaches out first (fore, hind), and how far back it is flung as
## it leaves the ground (fore, hind), m in the model.
const GALLOP_REACH := 1.25
const REACH_OUT := Vector2(0.15, 0.08)
const FLING_BACK := Vector2(0.07, 0.14)
const GLIDE := 0.25
const FOLD := Vector2(3.4, 2.2)
const FOLD_PLANTED := Vector2(-0.25, 0.9)
## How far the jaw drops, wide open, radians.
const GAPE := 0.55
## How the jaw and the head go (time in seconds, value) for a snort, a grunt and a squeal.
const SNORT_HEAD := [0.0, 0.0, 0.06, -1.0, 0.16, 0.5, 0.3, -0.2, 0.45, 0.0]
const GRUNT_JAW := [0.0, 0.0, 0.05, 0.35, 0.18, 0.25, 0.32, 0.0]
const SQUEAL_TIME := 1.1
const SNORT_TIME := 0.45
const GRUNT_TIME := 0.32
## A stamp: how long one takes, and when in it the hoof strikes.
const STAMP_TIME := 0.62
const STAMP_STRIKE := 0.36
## A toss of the head, and when in it the tusks come up through what is in front.
const TOSS_TIME := 0.85
const TOSS_HOOK := 0.28
## A slam into a wall: how long the jolt takes.
const SLAM_TIME := 0.7
## Stunned: how many times a second its head shakes, and how long a shake is.
const SHAKE_RATE := 3.6
const SHAKE_TIME := 0.9

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Layers of bristle stood off the coat (none on the low-poly model).
var fur_shells := 2
var coat_tint := Color.WHITE
var mud := 1.0
var eyeshine := 0.35
## The materials, by name (see BoarLook.dress).
var materials := {}


class Link:
	var joint: Node3D
	var bone := -1
	var rest := Vector3.DOWN
	var aim := Vector3.DOWN
	var twist := 0.0
	var length := 0.1
	var stiffness := 120.0
	var damping := 8.0
	var drag := 1.0
	var gravity := 6.0
	var limit := 1.2
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var held_tip := Vector3.ZERO


var _boar: Boar
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
var _legs: Array[Array] = []
var _tail: Array[Link] = []
var _ears: Array[Array] = [[], []]
var _links: Array[Link] = []
var _links_settled := false

var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _hooves: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
var _size := 1.0
var _hoof_height := 0.05
## Where the disc of its nose and the tips of its tusks are, in the head's space.
var _snout_tip := Vector3(0.0, -0.168, 0.487)
var _tusk_tip := Vector3(0.15, 0.035, 0.255)

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _speed_was := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _drop := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _mirrored := false
var _down: Array[bool] = [true, true, true, true]
var _mouth := 0.0
var _puffed := 0.0
var _breath := 0.0
var _alert := 0.0
var _look := Vector2.ZERO
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _ear_back := 0.0
var _swish := 0.0
var _swish_phase := 0.0
## How far into each mood it is, 0..1.
var _root := 0.0
var _sniffing := 0.0
var _lower := 0.0
var _stun := 0.0
var _skid := 0.0
var _bristle := 0.0
## Rooting: where in a shove it is, and how far down its neck must go to put its nose to the ground (worked out as it goes).
var _plough := 0.0
var _dip := 0.0
var _cast := 0.0
var _twitch := 0.0
var _twitch_in := 0.0
## Seconds since each act began (large: not doing it).
var _snorted := 9.0
var _grunted := 9.0
var _squealed := 9.0
var _stamped := 9.0
var _stamp_leg := 0
var _stamp_struck := true
var _tossed := 9.0
var _toss_side := 1.0
var _slammed := 9.0
var _shaken := 9.0
var _shake_in := 0.5


func _ready() -> void:
	_boar = get_parent() as Boar
	_build()
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_links_settled = false
	_crouch = 0.0
	_crouch_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0
	_speed_was = 0.0
	_skid = 0.0


func snort() -> void:
	_snorted = 0.0
	_crouch_velocity -= 0.8


func grunt() -> void:
	_grunted = 0.0


func squeal() -> void:
	_squealed = 0.0


## Lifts a forehoof and paws the ground with it (the other one next time).
func stamp() -> void:
	_stamped = 0.0
	_stamp_struck = false
	_stamp_leg = 1 - _stamp_leg


func stamping() -> bool:
	return _stamped < STAMP_TIME


## Heaves its head down, then up and to one side (`side` 1: its left).
func toss(side := 1.0) -> void:
	_tossed = 0.0
	_toss_side = signf(side) if side != 0.0 else 1.0


func tossing() -> bool:
	return _tossed < TOSS_TIME


## Stopped dead against something.
func slam() -> void:
	_slammed = 0.0
	_crouch_velocity += 3.5
	for side in 2:
		_flick(side, Vector3(0.0, 1.5, 2.0))


## Where the disc of its nose is, in the world.
func snout_tip() -> Vector3:
	return _head.global_transform * _snout_tip if _head else global_position


## Where the tip of one of its tusks is, in the world (`side` 1: its left).
func tusk_tip(side := 1.0) -> Vector3:
	return _head.global_transform * Vector3(_tusk_tip.x * side, _tusk_tip.y, _tusk_tip.z) if _head else global_position


## The head joint, for anything that should go with it (its breath).
func head() -> Node3D:
	return _head


func _process(delta: float) -> void:
	if _boar == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	# (it works in the model's own size: drawn three times as big, it strides as one this size going a third as fast)
	var velocity := _boar.velocity / maxf(global_basis.get_scale().x, 0.01)
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _boar.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)

	# --- Moods ---
	_snorted += delta
	_grunted += delta
	_squealed += delta
	_stamped += delta
	_tossed += delta
	_slammed += delta
	_root = _approach(_root, 1.0 if _boar.rooting and not _boar.lowered else 0.0, 2.5, delta)
	_sniffing = _approach(_sniffing, 1.0 if _boar.sniffing and not _boar.lowered else 0.0, 3.0, delta)
	_lower = _approach(_lower, 1.0 if _boar.lowered else 0.0, 5.0, delta)
	_stun = _approach(_stun, 1.0 if _boar.stunned else 0.0, 4.0 if _boar.stunned else 1.5, delta)
	# Slowing hard from a run, it skids.
	var slowing := (_speed_was - speed) / delta
	_speed_was = speed
	var skidding := slowing > 2.5 and speed > 0.6 and grounded
	_skid = _approach(_skid, 1.0 if skidding else 0.0, 10.0 if skidding else 3.0, delta)
	_bristle = _approach(_bristle, maxf(1.0 if _boar.bristling else 0.0, _lower), 5.0, delta)
	if materials.has("crest"):
		(materials["crest"] as ShaderMaterial).set_shader_parameter(&"bristle", _bristle)
	_alert = _approach(_alert, 1.0 if _boar.look_at_point.is_finite() else 0.0, 4.0, delta)
	_puffed = clampf(_puffed + (speed / 3.0 * 0.22 - 0.05) * delta, 0.0, 1.0)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.3 + 1.0, 1.0, 3.0)
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 200.0 - _crouch_velocity * 18.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.14)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.25), 8.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta * (1.0 - 0.7 * _skid), 1.0)
	var gait := smoothstep(0.05, 0.4, _pace) * (1.0 - _air) * (1.0 - _skid)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(0.05, 0.08, trot), 0.15, gallop) * _size
	var flying := gallop * gait
	var bound := cos(2.0 * TAU * (_phase - FLIGHT))
	var rise := (0.25 + bound) * BOUND * _size * flying
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := DUTY_FORE if fore else DUTY_HIND
		var duty := lerpf(lerpf(duties.x, duties.y, trot), duties.z, gallop)
		var span := minf(duty * stride, REACH * lerpf(1.0, GALLOP_REACH, gallop) * _size) * travel
		var middle := lerpf(-0.03, 0.03 if fore else -0.04, gallop) * travel
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(WALK[i], TROT[i], trot), GALLOP[other], gallop), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85))
		if at >= duty and flying > 0.0:
			# Galloping, a hoof is flung out behind as it leaves the ground, and
			# reaches out ahead before it lands (drawn back under it as it does).
			var swing := (at - duty) / (1.0 - duty)
			var out: float = REACH_OUT.x if fore else REACH_OUT.y
			var back: float = FLING_BACK.x if fore else FLING_BACK.y
			cycle.z += (out * sin(PI * smoothstep(0.4, 1.0, swing)) - back * sin(PI * clampf(swing / 0.4, 0.0, 1.0))) * _size * travel * flying
		var rest := _hooves[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		# (stunned, it stands with its legs splayed to keep its feet; skidding, braced)
		var wide := 1.0 + 0.2 * _stun + 0.08 * _lower
		var target := Vector3(rest.x * lerpf(1.0, 0.8, trot * gait) * wide, _hoof_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait)
		target.z += (0.16 if fore else 0.05) * _size * _skid
		target.z += (0.05 if fore else -0.02) * _size * _lower * (1.0 - gait)
		targets.append(target)
		pitches.append(cycle.x * gait)
		var down := at < duty
		if down:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		if down and not _down[i] and gait > 0.5 and _pace > 0.5:
			footfall.emit(global_transform * target, clampf((_pace - 0.6) / 3.0, 0.15, 1.0))
		_down[i] = down
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait * (1.0 - 0.45 * flying)) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.015
		drop = maxf(drop, _hips[i].y - _hoof_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	# (it never sinks far to reach: its back gathers and stretches for the ends of its stride instead)
	_drop = _approach(_drop, minf(drop, 0.035 * _size) + 0.004, 9.0, delta)
	var sprung := 0.02 * trot * (1.0 - gallop)
	var vault := 0.016 * (1.0 - trot)
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	var rock := (high_hind - high_fore) / 0.6 + sin(TAU * (_phase - FLIGHT)) * 0.07 * flying
	var back_bend := cos(TAU * (_phase - FLIGHT - 0.5)) * flying
	var bend := clampf(_turn * 0.06, -0.25, 0.25)
	var swing_fore := (targets[1].z - targets[0].z) * 0.18 * (1.0 - gallop)
	var swing_hind := (targets[3].z - targets[2].z) * 0.22 * (1.0 - gallop)
	var bank := clampf(-_turn * speed * 0.012, -0.18, 0.18)
	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	var chest_turn := Vector3(back_bend * 0.22, bend + swing_fore, (targets[0].y - targets[1].y) * 0.5)
	var pelvis_turn := Vector3(-back_bend * 0.4, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.6)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]

	# Rooting: the front of it lower, the forelegs a little bent.
	body_turn.x += 0.07 * _root
	body_at.y -= 0.03 * _size * _root
	# Lowered: the weight forward over braced forelegs, the shoulders hunched, the rump up.
	body_turn.x += 0.09 * _lower
	body_at.y -= 0.035 * _size * _lower
	chest_turn.x += -0.06 * _lower
	# Skidding: sat back on its haunches, the front of it up, the forelegs out ahead.
	body_turn.x -= 0.16 * _skid
	body_at.y -= 0.05 * _size * _skid
	body_at.z -= 0.05 * _size * _skid
	pelvis_turn.x += 0.12 * _skid
	# Stunned: swaying on its feet, the head hung low.
	var sway := sin(_time * 1.7) * 0.5 + sin(_time * 2.9 + 1.0) * 0.3
	body_turn.z += sway * 0.06 * _stun
	body_at.x += sway * 0.025 * _size * _stun
	body_at.y -= 0.03 * _size * _stun
	# A slam: stopped dead, jolted back and up.
	var jolt := 0.0
	if _slammed < SLAM_TIME:
		var u := _slammed / SLAM_TIME
		jolt = sin(PI * minf(u * 3.0, 1.0)) * (1.0 - u) + (1.0 - smoothstep(0.0, 0.4, u)) * 0.3
		body_at.z -= 0.08 * _size * jolt
		body_turn.x -= 0.12 * jolt
		chest_turn.x -= 0.1 * jolt
	# A toss: the shoulders heave up with the head.
	var heave := 0.0
	if _tossed < TOSS_TIME:
		heave = _keyed([0.0, 0.0, 0.18, -0.5, TOSS_HOOK + 0.06, 1.0, 0.55, 0.3, TOSS_TIME, 0.0], _tossed)
		chest_turn.x -= 0.10 * heave
		chest_turn.y += 0.12 * heave * _toss_side
		body_turn.z -= 0.05 * heave * _toss_side
	_shake(delta)
	var shook := 0.0
	if _shaken < SHAKE_TIME:
		var u := _shaken / SHAKE_TIME
		shook = sin(PI * u) * (1.0 - u * 0.3)
		chest_turn.z += sin(TAU * SHAKE_RATE * _shaken - 0.6) * 0.08 * shook
	# A stamp: one forehoof lifted high and forward, struck down and dragged back through the ground.
	if _stamped < STAMP_TIME:
		var u := _stamped / STAMP_TIME
		var i := _stamp_leg
		var raise := _keyed([0.0, 0.0, 0.26, 1.0, STAMP_STRIKE / STAMP_TIME, 0.0, 1.0, 0.0], u)
		var reach := _keyed([0.0, 0.0, 0.3, 0.7, STAMP_STRIKE / STAMP_TIME, 0.45, 0.85, -0.7, 1.0, 0.0], u)
		targets[i] = targets[i] + Vector3(0.0, raise * 0.17 * _size, reach * 0.12 * _size)
		pitches[i] += raise * 0.7
		# (it sinks onto the other three, and the shoulder on that side drops as it strikes)
		chest_turn.z += (raise * 0.05 - (0.04 if u > STAMP_STRIKE / STAMP_TIME and u < 0.8 else 0.0)) * (1.0 if i == 0 else -1.0)
		if not _stamp_struck and u >= STAMP_STRIKE / STAMP_TIME:
			_stamp_struck = true
			_crouch_velocity += 0.9
			struck.emit(global_transform * targets[i])

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, lerpf(1.0, 0.8, gallop), flying, jolt, heave, shook)
	_pose_jaw()
	_pose_legs(targets, pitches, poles, velocity.y)
	_carry_tail(delta, gallop)
	_carry_ears(delta, gallop)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)
	_measure_snout(delta)


## Stunned, it shakes its head now and then.
func _shake(delta: float) -> void:
	_shaken += delta
	if _stun < 0.5:
		_shake_in = 0.4
		return
	_shake_in -= delta
	if _shake_in <= 0.0:
		_shake_in = randf_range(1.0, 1.8)
		_shaken = 0.0
		for side in 2:
			_flick(side, Vector3(0.9 if side == 0 else -0.9, 0.4, 0.0))


## Its ribs: slow and deep at rest, quick and heaving when it has run.
func _breathe(delta: float) -> void:
	var panting := smoothstep(0.25, 0.6, _puffed)
	_breath += delta * TAU * lerpf(0.3, 1.6, panting)
	var swell := sin(_breath) * lerpf(0.012, 0.028, panting)
	if _snorted < SNORT_TIME:
		swell -= sin(PI * _snorted / SNORT_TIME) * 0.03
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## How hard it is breathing (0..1): for its steaming breath.
func breathing_out() -> float:
	return clampf(-cos(_breath), 0.0, 1.0) * lerpf(0.4, 1.0, smoothstep(0.25, 0.6, _puffed))


## Head and neck: carried low, turned to what it watches; nose to the ground
## rooting, lifted to the wind sniffing, down with the tusks forward lowered;
## snapped up by a slam, hung and shaken stunned, heaved in a toss.
func _pose_head(delta: float, upstream: float, level: float, flying: float, jolt: float, heave: float, shook: float) -> void:
	# Rooting: the shove (the disc pushed forward, the head swinging), then a flick up.
	_plough += delta * lerpf(1.1, 0.0, _lower)
	var shove := fposmod(_plough, 1.0)
	var flick := smoothstep(0.62, 0.74, shove) * (1.0 - smoothstep(0.78, 1.0, shove))
	var swing := sin(_plough * TAU * 0.5) * 0.32 + sin(_plough * 1.3) * 0.12
	# Sniffing: the nose working (quick small jerks), the head turning slowly to find the wind.
	_cast += delta * 0.6
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(0.07, 0.18) if randf() < 0.85 else randf_range(0.5, 0.9)
		_twitch = randf_range(-1.0, 1.0)
	var awake := 1.0 - _stun
	var yaw := _look.x * awake * (1.0 - _root) * (1.0 - _lower * 0.6)
	yaw += swing * _root + (sin(_cast * 1.7) * 0.4 + _twitch * 0.03) * _sniffing
	var pitch := _look.y * awake * (1.0 - _root) * (1.0 - _lower) * (1.0 - _sniffing)
	# Nose down to the ground, to the depth found for it, and ploughing.
	pitch += (_dip + 0.12 * (1.0 - shove) * (1.0 - flick) - 0.35 * flick) * _root
	# Snout up into the wind.
	pitch -= 0.55 * _sniffing - _twitch * 0.025 * _sniffing
	# Lowered: the head down, tusks forward (the neck down, the head turned up at the end of it).
	var lowered := _lower * (1.0 - _skid * 0.5)
	# Stunned: hung low.
	pitch += 0.4 * _stun
	if _snorted < SNORT_TIME:
		pitch += _keyed(SNORT_HEAD, _snorted) * 0.18
	if _grunted < GRUNT_TIME:
		pitch += sin(PI * _grunted / GRUNT_TIME) * 0.06
	if _squealed < SQUEAL_TIME:
		pitch -= sin(PI * minf(_squealed / 0.3, 1.0) * 0.5) * (1.0 - smoothstep(0.75, 1.0, _squealed / SQUEAL_TIME)) * 0.35
	var toss_pitch := 0.0
	var toss_yaw := 0.0
	var toss_roll := 0.0
	if _tossed < TOSS_TIME:
		# (down, then a hooking heave up and to one side, and back)
		toss_pitch = _keyed([0.0, 0.0, 0.16, 0.45, TOSS_HOOK, -0.2, TOSS_HOOK + 0.12, -0.75, 0.6, -0.3, TOSS_TIME, 0.0], _tossed)
		toss_yaw = _keyed([0.0, 0.0, 0.16, -0.15, TOSS_HOOK + 0.1, 0.55, 0.6, 0.25, TOSS_TIME, 0.0], _tossed) * _toss_side
		toss_roll = _keyed([0.0, 0.0, 0.16, 0.1, TOSS_HOOK + 0.1, -0.5, 0.6, -0.2, TOSS_TIME, 0.0], _tossed) * _toss_side
	var stretch := flying * 0.12 * level
	var neck := Vector3(-upstream * 0.6 * level + pitch * 0.6 + lowered * 0.42 + stretch + toss_pitch * 0.6 - jolt * 0.35, yaw * 0.5 + toss_yaw * 0.5, toss_roll * 0.3)
	var head := Vector3(-upstream * 0.4 * level + pitch * 0.4 - lowered * 0.22 - stretch * 0.6 + toss_pitch * 0.4 - jolt * 0.4, yaw * 0.5 + toss_yaw * 0.5, toss_roll * 0.7)
	if shook > 0.0:
		var w := TAU * SHAKE_RATE * _shaken
		neck.y += sin(w) * 0.25 * shook
		head.z += sin(w + 0.4) * 0.45 * shook
		head.y += sin(w + 0.2) * 0.15 * shook
	# (the quick jerks of a nose at work, sniffing and rooting)
	head.x += _twitch * 0.02 * maxf(_sniffing, _root * 0.5)
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = head


## Rooting, it finds how far down its neck must go to put the disc of its nose
## on the ground, from where its nose was last frame (so it reaches the ground
## whatever it is doing with its legs).
func _measure_snout(delta: float) -> void:
	if _root < 0.02:
		_dip = _approach(_dip, 0.6, 2.0, delta)
		return
	var ground := global_position.y - position.y
	var tip := snout_tip()
	var above := (tip.y - ground) / maxf(global_basis.get_scale().y, 0.01) - 0.03
	_dip = clampf(_dip + above * 3.5 * delta / maxf(_root, 0.3), 0.0, 1.6)


## The jaw: grunts, the squeal, a snort's twitch, champing while it roots,
## hanging open when it is out of breath or stunned.
func _pose_jaw() -> void:
	var open := 0.0
	if _grunted < GRUNT_TIME:
		open = _keyed(GRUNT_JAW, _grunted)
	if _squealed < SQUEAL_TIME:
		var u := _squealed / SQUEAL_TIME
		open = maxf(open, smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.8, 1.0, u)) * (0.85 + 0.1 * sin(_time * 37.0)))
	if _snorted < SNORT_TIME:
		open = maxf(open, sin(PI * _snorted / SNORT_TIME) * 0.15)
	open = maxf(open, _root * (0.12 + 0.1 * sin(_plough * TAU * 2.0)))
	open = maxf(open, smoothstep(0.35, 0.8, _puffed) * (0.18 + 0.06 * sin(_breath)))
	open = maxf(open, _stun * 0.25)
	_mouth = lerpf(_mouth, open, 0.5)
	_jaw.rotation.x = _mouth * GAPE


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _hooves[i]
		var stretched := rest + Vector3(0.0, 0.12, 0.26 if fore else -0.26) * _size
		var landing := rest + Vector3(0.0, 0.08, 0.2 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var hoof := to_body * target
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((hoof.z - under) * GLIDE, -0.07, 0.07)
		var lifted := maxf(_air, clampf((target.y - _hoof_height) / (0.05 * _size), 0.0, 1.0))
		_solve_leg(i, hip, hoof, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.4, _air)), to_body.basis * poles[i], lifted)


func _foot_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.65, 1.0, planted) * 0.5, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	return Vector3(lerpf(0.7, -0.2, smoothstep(0.0, 0.8, swing)), sin(PI * pow(swing, 0.75)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (as DogRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, hoof_basis: Basis, pole: Vector3, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06, total - 0.004)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var hoof := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		var fore := index < 2
		bend += (span - reach) / span * lerpf(FOLD_PLANTED.x if fore else FOLD_PLANTED.y, FOLD.x if fore else FOLD.y, lifted)
	var last := line * cos(bend) + aside * sin(bend)
	var far := lengths.x + lengths.y - 0.003
	var near := absf(lengths.x - lengths.y) + 0.01
	var second := hoof - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = hoof - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	hoof = second + last * lengths.z
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
	(bones[3] as Node3D).transform = Transform3D(hoof_basis, hoof)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Boar's `look_at_point`), or
## lets it gaze about.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _boar.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.2, 1.2)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.5)
	else:
		target.x = sin(_time * 0.37) * 0.25 + sin(_time * 0.8 + 1.0) * 0.08
		target.y = 0.05 + sin(_time * 0.3 + 2.0) * 0.05
	_look = _look.lerp(target, 1.0 - exp(-(6.0 if _alert > 0.5 else 3.0) * delta))


## The tail: hanging and swishing at ease, swishing hard when it is roused,
## up stiff with its tassel flying when it charges.
func _carry_tail(delta: float, gallop: float) -> void:
	var roused := maxf(_bristle, _sniffing * 0.6)
	_swish = _approach(_swish, lerpf(0.35, 1.0, roused) * (1.0 - gallop * 0.6), 3.0, delta)
	_swish_phase += delta * TAU * lerpf(0.9, 2.6, roused)
	var carried := -0.1 + 0.35 * roused + 1.1 * gallop * _lower + 0.5 * _skid - 0.2 * _stun
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_swish_phase - i * 0.9) * _swish * (0.45 if i == 0 else 0.25)
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 if i == 0 else carried * 0.25
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = lerpf(0.9, 0.3, gallop)


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * 2.0


## The ears: forward when it sniffs or roots, back flat when it is lowered or
## charging, drooping stunned, one or other flicking at ease.
func _carry_ears(delta: float, gallop: float) -> void:
	var back := maxf(_lower, gallop * 0.6)
	_ear_back = _approach(_ear_back, back, 6.0, delta)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.8, 3.0)
		var pick := randi() % 4
		_ear_turn_to = Vector2(randf_range(0.4, 0.9) if pick == 0 else 0.0, randf_range(0.4, 0.9) if pick == 1 else 0.0)
		if pick == 2 and _alert < 0.5 and _lower < 0.1:
			_flick(randi() % 2, Vector3(0.6, 0.4, 0.0))
	var listening := (1.0 - _alert) * (1.0 - _ear_back)
	_ear_turn = _ear_turn.lerp(_ear_turn_to * listening, 1.0 - exp(-8.0 * delta))
	var forward := maxf(_sniffing, _root * 0.5)
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		var lean := Basis(Vector3.RIGHT, -_ear_back * 0.9 + forward * 0.35 + _stun * 0.15) * Basis(BEHIND, out * (_ear_back * 0.25 + turn * 0.4 - forward * 0.1 + _stun * 0.35))
		root.aim = lean * root.rest
		root.twist = out * turn * 0.6
		tip.aim = Basis(Vector3.RIGHT, -_ear_back * 0.2) * tip.rest


func _swing(delta: float) -> void:
	var ground := global_position.y - position.y + 0.02
	for link in _links:
		var parent := (link.joint.get_parent() as Node3D).global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * link.joint.position
		var held_tip := root + frame * link.aim * link.length * parent.basis.get_scale().x
		if not _links_settled:
			link.tip = held_tip
			link.held_tip = held_tip
			link.velocity = Vector3.ZERO
		var held_velocity := (held_tip - link.held_tip) / delta
		link.held_tip = held_tip
		var before := link.tip
		var pull := (held_tip - link.tip) * link.stiffness - (link.velocity - held_velocity) * link.damping
		link.velocity += (pull - link.velocity * link.drag + Vector3.DOWN * link.gravity) * delta
		link.tip += link.velocity * delta
		link.tip.y = maxf(link.tip.y, ground)
		var along := (link.tip - root).normalized()
		var held := (held_tip - root).normalized()
		var off := held.angle_to(along)
		if off > link.limit:
			along = held.slerp(along, link.limit / off)
		link.tip = root + along * (held_tip - root).length()
		link.velocity = (link.tip - before) / delta
		link.joint.basis = Basis(Quaternion(link.rest, (frame.inverse() * along).normalized())) * Basis(link.rest, link.twist)
		_skeleton.set_bone_pose(link.bone, link.joint.transform)
	_links_settled = true


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
	var path := "res://creatures/boar/models/boar%s.glb" % ("_lo" if low_poly else "")
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = BoarLook.dress(model, coat_tint, 0 if low_poly else fur_shells, mud, eyeshine)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "hoof"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_hooves.append(at[3])
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
	_hoof_height = _hooves[0].y
	_size = _hips[2].y / 0.52
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_3", "tail_end"]
	for i in 4:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = lerpf(1500.0, 500.0, i / 3.0)
		link.damping = lerpf(40.0, 18.0, i / 3.0)
		link.gravity = 4.0
		link.limit = 0.9
		_tail.append(link)
		from = link.joint
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var tip := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, tip]:
			link.stiffness = 1100.0 if link == root else 600.0
			link.damping = 22.0 if link == root else 12.0
			link.gravity = 0.0 if link == root else 1.0
			link.drag = 0.5
			link.limit = 0.6 if link == root else 0.5
		_ears[side] = [root, tip]
		# The slobber: a loose string, swinging and stretching with every jolt.
		var drool := _link(_jaw, "drool" + suffix, _rest("drool_end" + suffix))
		drool.stiffness = 25.0
		drool.damping = 1.5
		drool.gravity = 9.0
		drool.drag = 0.4
		drool.limit = 1.3


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


func _link(parent: Node3D, bone: StringName, end: Vector3) -> Link:
	var link := Link.new()
	link.joint = Node3D.new()
	link.bone = _skeleton.find_bone(bone)
	link.joint.name = bone
	link.joint.position = _skeleton.get_bone_rest(link.bone).origin
	parent.add_child(link.joint)
	link.rest = end.normalized()
	link.aim = link.rest
	link.length = end.length()
	_links.append(link)
	return link
