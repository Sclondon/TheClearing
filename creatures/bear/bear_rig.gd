class_name BearRig
extends Node3D
## Poses the screaming bear (creatures/bear/models/bear*.glb) in code, every
## frame, from what its Bear (the parent) says it is doing. The boar's rig
## (BoarRig) on longer legs: paws follow a gait cycle and are put down with
## IK, and the spine, neck, head and jaw are laid on top; the stub of a tail,
## the ears and the strings of slaver are on springs.
##
## THE GAITS, chosen by its speed: a slow, heavy four-beat walk (the prowl:
## its head carried low and swinging, the shoulder blades rolling over the
## top of it with each step), a trot, and a rotary gallop for the charge, each
## leg flung out behind and reaching far out ahead, the back gathering and
## stretching. Each paw comes down with a jolt (`footfall`).
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - SNIFFING: head up, nose lifted and working (quick small jerks), turning
##   slowly to find the scent.
## - LOWERED: the wind-up of a charge: the front of it dropped, head low and
##   thrust out, the haunches gathered under it.
## - REARING: up on its hind legs, far taller than a man, the forelegs hanging
##   in front of it, claws out; the head comes forward to look down.
## - SCREAM: its jaws gape as far as they go (it has no lips: the teeth all
##   bare), the head thrust out and shaking, the chest heaving.
## - SPEAK: the jaw works as a mouth would if it were saying something (its
##   stolen voice, which the Bear plays), the head tipped a little over.
## - SWIPE: a foreleg flung up and out to its side, then raked down and across
##   in front of it (`swiped` as the claws come through).
## - MAULING: head down over something on the ground in front of it, tearing.
## - HUFF and JAW POP: a blast of breath, the chest jerking; the jaws snapped
##   together twice, as bears do when they mean harm.
## - Always: now and then a twitch, too quick, of the head or a leg, that no
##   animal should make.
##
## Every joint is read from the model's skeleton (tools/build_bear.py).

## A paw has come down hard: where, and how hard (0..1: a walk is light, a gallop heavy).
signal footfall(at: Vector3, weight: float)
## A swipe's claws are coming through in front of it.
signal swiped

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## Where in the stride each paw lands, walking, trotting and galloping.
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const TROT: Array[float] = [0.5, 1.0, 0.0, 0.5]
const GALLOP: Array[float] = [0.6, 0.5, 0.0, 0.1]
## The share of the stride a paw is down, fore and hind, at a walk, a trot and a gallop.
const DUTY_FORE := Vector3(0.68, 0.50, 0.34)
const DUTY_HIND := Vector3(0.66, 0.48, 0.32)
const FLIGHT := 0.405
const BOUND := 0.06
## Speeds (m/s, in the model) over which it goes from a walk to a trot, and a trot to a gallop.
const TROT_AT := Vector2(1.5, 1.9)
const GALLOP_AT := Vector2(2.1, 2.6)
## Length of a stride (m, in the model) against speed (m/s).
const STRIDE := [0.0, 0.50, 0.5, 0.95, 1.2, 1.35, 1.9, 1.75, 2.8, 2.4, 5.0, 3.2]
const REACH := 0.45
const GALLOP_REACH := 1.3
const REACH_OUT := Vector2(0.16, 0.10)
const FLING_BACK := Vector2(0.08, 0.16)
const GLIDE := 0.25
const FOLD := Vector2(3.0, 2.2)
const FOLD_PLANTED := Vector2(-0.2, 0.9)
## How far the jaw drops, wide open, radians.
const GAPE := 0.85
## How far it tips back to rear (radians), and how long a swipe takes (s) and when in it the claws come through.
const REAR_ANGLE := 1.12
const SWIPE_TIME := 0.8
const SWIPE_HIT := 0.4
const HUFF_TIME := 0.4
const POP_TIME := 0.45

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
var fur_shells := 2
var coat_tint := Color.WHITE
var bare := 1.0
var eyeshine := 0.3
## The materials, by name (see BearLook.dress).
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


var _bear: Bear
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
var _paws: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
var _size := 1.0
var _paw_height := 0.04
var _pivot := Vector3.ZERO
## Where the end of its muzzle is, in the head's space.
var _snout_tip := Vector3(0.0, -0.03, 0.30)

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
var _ear_back := 0.0
## How far into each mood it is, 0..1.
var _sniffing := 0.0
var _lower := 0.0
var _rear := 0.0
var _maul := 0.0
var _skid := 0.0
var _cast := 0.0
var _twitch := 0.0
var _twitch_in := 0.0
var _tic := 9.0
var _tic_in := 3.0
var _tic_way := Vector3.ZERO
## Seconds since each act began (large: not doing it), and how long a voice goes on.
var _screamed := 99.0
var _scream_time := 2.0
var _spoke := 99.0
var _speak_time := 1.0
var _swiped := 99.0
var _swipe_side := 1.0
var _swipe_struck := true
var _huffed := 99.0
var _popped := 99.0


func _ready() -> void:
	_bear = get_parent() as Bear
	_build()
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_last_yaw = global_rotation.y


func settle() -> void:
	_links_settled = false
	_crouch = 0.0
	_crouch_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0
	_speed_was = 0.0
	_skid = 0.0


## Its jaws gape and its head shakes for `seconds` (the length of its scream).
func scream(seconds := 2.0) -> void:
	_screamed = 0.0
	_scream_time = seconds
	_crouch_velocity -= 0.6


## Its jaw works for `seconds`, as if it were saying something.
func speak(seconds := 1.0) -> void:
	_spoke = 0.0
	_speak_time = seconds


func screaming() -> bool:
	return _screamed < _scream_time


## A foreleg flung up and out, then raked down and across (`side` 1: its left).
func swipe(side := 1.0) -> void:
	_swiped = 0.0
	_swipe_side = signf(side) if side != 0.0 else 1.0
	_swipe_struck = false


func swiping() -> bool:
	return _swiped < SWIPE_TIME


func huff() -> void:
	_huffed = 0.0
	_crouch_velocity -= 0.9


func pop_jaw() -> void:
	_popped = 0.0


## Where the end of its muzzle is, in the world.
func snout_tip() -> Vector3:
	return _head.global_transform * _snout_tip if _head else global_position


## Where the claws of a forepaw are, in the world (`side` 1: its left).
func claw_tip(side := 1.0) -> Vector3:
	var leg: Array = _legs[0 if side > 0.0 else 1]
	var paw := leg[3] as Node3D
	return paw.global_transform * Vector3(0.0, -0.01, 0.1) if paw else global_position


## The head joint, for anything that should go with it (its breath).
func head() -> Node3D:
	return _head


## How far up on its hind legs it is, 0..1.
func reared() -> float:
	return _rear


func _process(delta: float) -> void:
	if _bear == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	# (it works in the model's own size)
	var velocity := _bear.velocity / maxf(global_basis.get_scale().x, 0.01)
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _bear.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)

	# --- Moods ---
	_screamed += delta
	_spoke += delta
	_swiped += delta
	_huffed += delta
	_popped += delta
	_sniffing = _approach(_sniffing, 1.0 if _bear.sniffing and not _bear.lowered and not _bear.rearing else 0.0, 3.0, delta)
	_lower = _approach(_lower, 1.0 if _bear.lowered else 0.0, 5.0, delta)
	_rear = _approach(_rear, 1.0 if _bear.rearing else 0.0, 2.6 if _bear.rearing else 3.2, delta)
	_maul = _approach(_maul, 1.0 if _bear.mauling else 0.0, 4.0, delta)
	var slowing := (_speed_was - speed) / delta
	_speed_was = speed
	var skidding := slowing > 2.2 and speed > 0.8 and grounded
	_skid = _approach(_skid, 1.0 if skidding else 0.0, 10.0 if skidding else 3.0, delta)
	_alert = _approach(_alert, 1.0 if _bear.look_at_point.is_finite() else 0.0, 4.0, delta)
	_puffed = clampf(_puffed + (speed / 2.5 * 0.22 - 0.05) * delta, 0.0, 1.0)
	if grounded and not _was_grounded:
		_crouch_velocity += clampf(-velocity.y * 0.3 + 1.0, 1.0, 3.0)
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 200.0 - _crouch_velocity * 18.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.14)
	_tics(delta)

	# --- The gait ---
	var standing := 1.0 - _rear
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.3) * standing, 8.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta * (1.0 - 0.7 * _skid), 1.0)
	var gait := smoothstep(0.05, 0.4, _pace) * (1.0 - _air) * (1.0 - _skid)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(0.06, 0.09, trot), 0.16, gallop) * _size
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
		var middle := lerpf(-0.03, 0.04 if fore else -0.05, gallop) * travel
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(WALK[i], TROT[i], trot), GALLOP[other], gallop), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85))
		if at >= duty and flying > 0.0:
			var swing := (at - duty) / (1.0 - duty)
			var out: float = REACH_OUT.x if fore else REACH_OUT.y
			var back: float = FLING_BACK.x if fore else FLING_BACK.y
			cycle.z += (out * sin(PI * smoothstep(0.4, 1.0, swing)) - back * sin(PI * clampf(swing / 0.4, 0.0, 1.0))) * _size * travel * flying
		var rest := _paws[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		var wide := 1.0 + 0.1 * _lower + 0.15 * _maul
		var target := Vector3(rest.x * lerpf(1.0, 0.85, trot * gait) * wide, _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait)
		target.z += (0.14 if fore else 0.05) * _size * _skid
		# (lowered, the forepaws reach out ahead and the hind come in under it, gathered to spring)
		target.z += (0.06 if fore else 0.06) * _size * _lower * (1.0 - gait)
		# (rearing, the hind paws come in under its hips)
		if not fore:
			target.z += 0.07 * _size * _rear
		targets.append(target)
		pitches.append(cycle.x * gait)
		var down := at < duty
		if down:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		if down and not _down[i] and gait > 0.5 and _pace > 0.35 and (not fore or _rear < 0.3):
			footfall.emit(global_transform * target, clampf((_pace - 0.4) / 2.5, 0.2, 1.0))
		_down[i] = down
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait * (1.0 - 0.45 * flying)) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.015
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	_drop = _approach(_drop, minf(drop, 0.04 * _size) + 0.004, 9.0, delta)
	var sprung := 0.02 * trot * (1.0 - gallop)
	var vault := 0.02 * (1.0 - trot)
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	var rock := (high_hind - high_fore) / 0.6 + sin(TAU * (_phase - FLIGHT)) * 0.08 * flying
	var back_bend := cos(TAU * (_phase - FLIGHT - 0.5)) * flying
	var bend := clampf(_turn * 0.06, -0.25, 0.25)
	var swing_fore := (targets[1].z - targets[0].z) * 0.22 * (1.0 - gallop)
	var swing_hind := (targets[3].z - targets[2].z) * 0.22 * (1.0 - gallop)
	var bank := clampf(-_turn * speed * 0.012, -0.18, 0.18)
	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	# (the prowl: its shoulder blades roll over the top of it with each step, the chest swaying under them)
	var roll := (targets[0].y - targets[1].y) * 1.4 + (targets[1].z - targets[0].z) * 0.25 * (1.0 - trot)
	var chest_turn := Vector3(back_bend * 0.22, bend + swing_fore, roll)
	var pelvis_turn := Vector3(-back_bend * 0.4, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.8)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]

	# Lowered: the front of it dropped, gathered to spring.
	body_turn.x += 0.14 * _lower
	body_at.y -= 0.05 * _size * _lower
	pelvis_turn.x += 0.08 * _lower
	# Skidding: sat back, the forepaws braced out ahead.
	body_turn.x -= 0.14 * _skid
	body_at.y -= 0.04 * _size * _skid
	pelvis_turn.x += 0.12 * _skid
	# Mauling: the front of it down over what it has, the shoulders working.
	body_turn.x += 0.16 * _maul
	body_at.y -= 0.06 * _size * _maul
	chest_turn.z += sin(_time * 5.0) * 0.06 * _maul
	chest_turn.y += sin(_time * 3.1) * 0.08 * _maul
	# A swipe: the weight thrown back onto the hind legs and the shoulder turned into it.
	var swipe_lift := 0.0
	if _swiped < SWIPE_TIME:
		var u := _swiped / SWIPE_TIME
		swipe_lift = _keyed([0.0, 0.0, 0.3, 1.0, 0.55, 1.0, 0.85, 0.35, 1.0, 0.0], u)
		var turn := _keyed([0.0, 0.0, 0.3, 0.35, 0.5, -0.3, 0.8, -0.2, 1.0, 0.0], u)
		chest_turn.y += turn * _swipe_side
		chest_turn.z += turn * 0.25 * _swipe_side
		body_turn.x -= 0.2 * swipe_lift * (1.0 - _rear)
		body_at.y += 0.03 * _size * swipe_lift * (1.0 - _rear)
		if not _swipe_struck and _swiped >= SWIPE_HIT:
			_swipe_struck = true
			swiped.emit()
	# Rearing: tipped back about its hips, up onto its hind legs.
	var tip := _rear * REAR_ANGLE
	var turned := Basis(Vector3.RIGHT, -tip) * _pivot
	body_at += _pivot - turned + Vector3(0.0, 0.07 * _size * _rear, 0.0)
	body_turn.x -= tip
	chest_turn.x -= 0.15 * _rear
	pelvis_turn.x += 0.1 * _rear
	# Screaming: the chest heaves.
	var shriek := 0.0
	if _screamed < _scream_time:
		var u := _screamed / _scream_time
		shriek = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.75, 1.0, u))
		chest_turn.x -= 0.08 * shriek
	if _huffed < HUFF_TIME:
		chest_turn.x += sin(PI * _huffed / HUFF_TIME) * 0.06
	# Its tics: a jerk of a shoulder, too quick.
	if _tic < 0.2:
		chest_turn.z += _tic_way.z * sin(PI * _tic / 0.2) * 0.12

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta, shriek)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, lerpf(1.0, 0.8, gallop), flying, shriek)
	_pose_jaw(shriek)
	_pose_legs(targets, pitches, poles, velocity.y, swipe_lift)
	_carry_tail(delta, gallop)
	_carry_ears(delta, gallop)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## Now and then, a twitch too quick for an animal: the head or a shoulder jerks.
func _tics(delta: float) -> void:
	_tic += delta
	_tic_in -= delta
	if _tic_in <= 0.0:
		_tic_in = randf_range(1.5, 5.0)
		_tic = 0.0
		_tic_way = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))


func _breathe(delta: float, shriek: float) -> void:
	var panting := maxf(smoothstep(0.25, 0.6, _puffed), shriek)
	_breath += delta * TAU * lerpf(0.28, 1.5, panting)
	var swell := sin(_breath) * lerpf(0.014, 0.03, panting)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## How hard it is breathing out (0..1): for its breath in the cold.
func breathing_out() -> float:
	return clampf(-cos(_breath), 0.0, 1.0) * lerpf(0.4, 1.0, smoothstep(0.25, 0.6, _puffed))


## Head and neck: carried low and swinging as it prowls; up and working
## sniffing; low and thrust out lowered; forward and down to look at what is
## below it reared; thrust out and shaking screaming; down tearing mauling.
func _pose_head(delta: float, upstream: float, level: float, flying: float, shriek: float) -> void:
	_cast += delta * 0.55
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(0.07, 0.18) if randf() < 0.85 else randf_range(0.5, 0.9)
		_twitch = randf_range(-1.0, 1.0)
	var prowl := (1.0 - _sniffing) * (1.0 - _lower) * (1.0 - _rear) * (1.0 - _maul)
	var yaw := _look.x * (1.0 - _lower * 0.6) * (1.0 - _maul)
	# (prowling, its head swings low from side to side, nose to the ground)
	yaw += sin(_cast * 1.3) * 0.28 * prowl * (1.0 - _alert * 0.7) + (sin(_cast * 1.7) * 0.35 + _twitch * 0.03) * _sniffing
	var pitch := _look.y * (1.0 - _lower) * (1.0 - _sniffing) * (1.0 - _maul)
	pitch += 0.32 * prowl * (1.0 - _alert * 0.6)
	pitch -= 0.6 * _sniffing - _twitch * 0.03 * _sniffing
	# Lowered: the head low and thrust out.
	pitch += 0.1 * _lower
	var thrust := 0.35 * _lower
	# Mauling: the head down to the ground, tearing from side to side.
	pitch += 0.9 * _maul
	yaw += sin(_time * 7.0) * 0.25 * _maul
	var roll := sin(_time * 7.0 + 1.0) * 0.3 * _maul
	# Screaming: the head thrust out and up, shaking.
	if shriek > 0.0:
		pitch -= 0.35 * shriek
		thrust += 0.3 * shriek
		yaw += sin(_time * 23.0) * 0.06 * shriek
		roll += sin(_time * 19.0 + 0.5) * 0.12 * shriek
	# Speaking: the head tipped over, as a listening dog's is (but it is the one talking).
	if _spoke < _speak_time:
		var u := _spoke / _speak_time
		roll += 0.35 * smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u))
	if _huffed < HUFF_TIME:
		pitch += sin(PI * _huffed / HUFF_TIME) * 0.12
	# Its tics: the head snapped round, too quick.
	if _tic < 0.18:
		var jerk := sin(PI * _tic / 0.18)
		yaw += _tic_way.x * jerk * 0.35
		roll += _tic_way.y * jerk * 0.5
	var stretch := flying * 0.15 * level + thrust
	var neck := Vector3(-upstream * 0.6 * level + pitch * 0.55 + stretch, yaw * 0.5, roll * 0.3)
	var head := Vector3(-upstream * 0.4 * level + pitch * 0.45 - stretch * 0.8, yaw * 0.5, roll * 0.7)
	head.x += _twitch * 0.02 * _sniffing
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = head


## The jaw: it has no lips, so it never quite closes; it gapes screaming,
## works speaking, snaps popping, tears mauling, and hangs when it is winded.
func _pose_jaw(shriek: float) -> void:
	var open := 0.06 + 0.03 * sin(_time * 0.7)
	open = maxf(open, shriek * (0.92 + 0.08 * sin(_time * 31.0)))
	if _spoke < _speak_time:
		var u := _spoke / _speak_time
		var talk := 0.25 + 0.2 * sin(_spoke * TAU * 3.3) + 0.12 * sin(_spoke * TAU * 5.1)
		open = maxf(open, talk * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.8, 1.0, u)))
	if _popped < POP_TIME:
		var u := _popped / POP_TIME
		open = maxf(open, absf(sin(u * TAU)) * 0.45 * (1.0 - u))
	if _huffed < HUFF_TIME:
		open = maxf(open, sin(PI * _huffed / HUFF_TIME) * 0.3)
	open = maxf(open, _maul * (0.3 + 0.3 * sin(_time * 9.0)))
	open = maxf(open, smoothstep(0.35, 0.8, _puffed) * (0.25 + 0.08 * sin(_breath)))
	open = maxf(open, _lower * 0.35)
	# (snapping shut fast, as a jaw does)
	_mouth = lerpf(_mouth, open, 0.6 if open < _mouth and _popped < POP_TIME else 0.35)
	_jaw.rotation.x = _mouth * GAPE


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], vertical_speed: float, swipe_lift: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var stretched := rest + Vector3(0.0, 0.12, 0.26 if fore else -0.26) * _size
		var landing := rest + Vector3(0.0, 0.08, 0.2 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		var pitch := lerpf(pitches[i], 0.4, _air)
		if fore:
			# Off the ground: reared, the forelegs hang in front of it, claws out; swiping, one rakes.
			var side := 1.0 if i == 0 else -1.0
			var length := _lengths[i].x + _lengths[i].y + _lengths[i].z
			var hang := Vector3(side * 0.1, -0.62, 0.42) * length
			if _screamed < _scream_time:
				# (screaming up there, it spreads its arms wide)
				var u := _screamed / _scream_time
				var wide := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.7, 1.0, u))
				hang = hang.lerp(Vector3(side * 0.42, -0.35, 0.4) * length, wide * _rear)
			var lifted := _rear
			if _swiped < SWIPE_TIME and side == _swipe_side:
				var u := _swiped / SWIPE_TIME
				var arm := Vector3(
					_keyed([0.0, 0.1, 0.3, 0.45, 0.5, -0.05, 0.75, -0.3, 1.0, 0.0], u) * side,
					_keyed([0.0, -0.6, 0.3, 0.1, 0.5, -0.5, 0.75, -0.78, 1.0, -0.85], u),
					_keyed([0.0, 0.3, 0.3, 0.35, 0.5, 0.75, 0.75, 0.4, 1.0, 0.2], u)) * length
				hang = hang.lerp(arm, swipe_lift)
				lifted = maxf(lifted, swipe_lift)
				pitch = lerpf(pitch, -0.9, swipe_lift)
			var raised := hip + to_body.basis * hang
			paw = paw.lerp(raised, lifted)
			pitch = lerpf(pitch, -0.5, _rear * (1.0 - swipe_lift))
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * GLIDE, -0.07, 0.07) * (1.0 - _rear)
		var up := maxf(_air, clampf((target.y - _paw_height) / (0.05 * _size), 0.0, 1.0))
		if fore:
			up = maxf(up, maxf(_rear, swipe_lift))
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, pitch), to_body.basis * poles[i], up)


func _foot_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.65, 1.0, planted) * 0.5, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	return Vector3(lerpf(0.7, -0.2, smoothstep(0.0, 0.8, swing)), sin(PI * pow(swing, 0.75)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (as BoarRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis, pole: Vector3, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06, total - 0.004)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var paw := hip + line * reach
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
	var second := paw - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = paw - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	paw = second + last * lengths.z
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
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _bear.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.2, 1.2)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.7)
	else:
		target.x = sin(_time * 0.31) * 0.2 + sin(_time * 0.8 + 1.0) * 0.06
		target.y = 0.05 + sin(_time * 0.3 + 2.0) * 0.05
	_look = _look.lerp(target, 1.0 - exp(-(5.0 if _alert > 0.5 else 2.5) * delta))


## The stub of a tail: hanging, a little stiff.
func _carry_tail(_delta: float, gallop: float) -> void:
	for i in _tail.size():
		var link := _tail[i]
		var curl := -_pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 + 0.3 * gallop if i == 0 else 0.0
		link.aim = Basis(Vector3.RIGHT, curl) * link.rest


## The ears: back flat lowered, charging or screaming, forward sniffing, the
## good one twitching at ease (the torn one barely moves).
func _carry_ears(delta: float, gallop: float) -> void:
	var back := maxf(maxf(_lower, gallop * 0.7), maxf(_rear * 0.6, 1.0 if _screamed < _scream_time else 0.0))
	_ear_back = _approach(_ear_back, back, 6.0, delta)
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		var lean := Basis(Vector3.RIGHT, -_ear_back * 0.9 + _sniffing * 0.3) * Basis(BEHIND, out * _ear_back * 0.3)
		root.aim = lean * root.rest
		tip.aim = tip.rest


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
	var path := "res://creatures/bear/models/bear%s.glb" % ("_lo" if low_poly else "")
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = BearLook.dress(model, coat_tint, 0 if low_poly else fur_shells, bare, eyeshine)
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
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
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
	_paw_height = _paws[0].y
	_size = _hips[2].y / 0.52
	_pivot = Vector3(0.0, _hips[2].y, _hips[2].z) - _body_rest
	var from := _pelvis
	var names: Array[String] = ["tail", "tail_1", "tail_end"]
	for i in 2:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = 1200.0
		link.damping = 30.0
		link.gravity = 3.0
		link.limit = 0.6
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
