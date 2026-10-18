class_name RabbitRig
extends Node3D
## Poses a rabbit, a hare or a jackalope (creatures/rabbit/models) in code,
## every frame, from what its Rabbit (the parent) says it is doing. After
## DeerRig (creatures/deer): the feet follow a gait cycle and are put down with
## IK (two bones and the long foot, the elbow folding back and the stifle
## forward, the hand or the foot laid at the angle the gait asks for: a hind
## foot flat on the ground, hock to toe, or up on its toes as it drives off),
## and the spine, neck, head, jaw and nose are laid on top; the ears and the
## scut are on springs.
##
## THE GAITS, chosen by its speed (in a rabbit's measure: a hare, half as big
## again, bounds as a big rabbit would):
## - SITTING (still): hunched, the hind feet flat under it from hock to toe,
##   the forefeet together under the chest; breathing quick and shallow.
## - THE HOP (slow): the forefeet reach forward, one and then the other, and
##   the back arches as the hind feet are brought up together to land flat
##   beside them; the back straightens as the forefeet go on.
## - THE BOUND (fast): the hind feet drive off together, up on their toes; it
##   flies stretched out, forefeet reaching; it lands on one forefoot and then
##   the other, and while they sweep back under it the back curls and the hind
##   feet swing forward outside them, to land ahead of where the forefeet came
##   down (the leporid's track: the big hind prints in front).
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - GRAZING: crouched, head down to the grass, the jaw nibbling, the nose
##   going. ALERT: still, the head up, both ears up and forward, turning; the
##   nose twitching faster.
## - UPRIGHT: sat up on its haunches, its hind feet flat, its forepaws held
##   to its chest, head level, looking. WASHING: sat up, the forepaws drawn
##   down over the face, again and again, the head bobbing into them; now and
##   then it licks a paw.
## - FLATTENED: pressed to the ground, the head low and forward, the ears laid
##   flat along the back, stock still (a hare in its form).
## - FLEEING: ears laid back. FLAGGING: the scut held up against the rump, its
##   white underside to whatever is behind.
## - BOXING: stood up tall on its toes, striking out with its forepaws, one and
##   the other, fast. LOWERED: the head down and forward (a jackalope's antlers
##   pointing ahead).
## - THUMP: both hind feet lifted and brought down hard. GRUNT: the head
##   jerking down and forward, the ears back, the jaw a little open.
## - UNCANNY (the jackalope): while it watches it holds its head stock still
##   and its nose does not twitch, its head turns further round than a hare's,
##   and its eyes give back more light.
##
## Every joint is read from the model's skeleton (tools/build_rabbit.py), so a
## model with other measurements on the same bones would do as well.

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## A rabbit's hip height, for its measure (a model this high is a size of 1).
const HIP := 0.13
## Where in the stride each foot comes down, hopping and bounding, and the share of the stride each is down (fore, hind).
const HOP_DOWN: Array[float] = [0.0, 0.12, 0.62, 0.64]
const BOUND_DOWN: Array[float] = [0.0, 0.08, 0.42, 0.45]
const HOP_DUTY := Vector2(0.62, 0.52)
const BOUND_DUTY := Vector2(0.17, 0.19)
## Speeds (m/s, size 1) over which the hop gives way to the bound.
const BOUND_AT := Vector2(1.1, 2.4)
## Length of a stride (m) against speed (m/s), for a size of 1.
const STRIDE := [0.0, 0.14, 0.6, 0.2, 1.5, 0.34, 3.0, 0.7, 5.0, 1.05, 8.0, 1.45, 12.0, 1.9, 18.0, 2.4]
## How high it flies at the top of a bound (m, size 1, at a long stride).
const RISE := 0.065
## A thump and a grunt, seconds; a stroke of the paws over the face; a punch.
const THUMP_TIME := 0.34
const GRUNT_TIME := 0.5
const WASH_TIME := 0.62
const PUNCH_TIME := 0.24
## How far the jaw drops, wide open, radians.
const GAPE := 0.35

## The model (set before it enters the tree; the Rabbit sets it).
var model_path := "res://creatures/rabbit/models/rabbit.glb"
var low_poly := false
var fur_shells := 1
var coat_tint := Color.WHITE
var eyeshine := 0.5
var colours := {}
## How far it is a jackalope that watches (see UNCANNY above), 0..1.
var uncanny := 0.0
## Poses it only every so many frames (1: every frame), for one far off.
var pose_every := 1
## The materials, by name (see RabbitLook.dress).
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


var _rabbit: Rabbit
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _lip: Node3D
var _legs: Array[Array] = []
var _tail: Link
var _ears: Array[Array] = [[], []]
var _links: Array[Link] = []
var _links_settled := false

var _body_rest := Vector3.ZERO
var _chest_rest := Vector3.ZERO
var _pelvis_rest := Vector3.ZERO
var _head_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _paws: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _frames: Array[Array] = []
var _rest_lean: Array[float] = []
var _size := 1.0
var _paw_height := 0.006
var _nose := Vector3.ZERO
var _brow := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _breath := 0.0
var _puffed := 0.0
var _mouth := 0.0
var _look := Vector2.ZERO
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _twitch := 0.0
var _twitch_timer := 0.5
var _sniffing := 0.0
var _skip := 0
var _waited := 0.0
## How far into each mood it is, 0..1.
var _graze := 0.0
var _alert := 0.0
var _upright := 0.0
var _wash := 0.0
var _flat := 0.0
var _flee := 0.0
var _flag := 0.0
var _box := 0.0
var _lower := 0.0
var _wash_clock := 0.0
var _punch_clock := 0.0
var _thumped := 9.0
var _grunted := 9.0


func _ready() -> void:
	_rabbit = get_parent() as Rabbit
	_build()
	_time = randf() * 10.0
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_links_settled = false
	_crouch = 0.0
	_crouch_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0


func thump() -> void:
	_thumped = 0.0


func grunt() -> void:
	_grunted = 0.0
	for side in 2:
		_flick(side, Vector3(0.0, 0.3, -0.8))


func busy() -> bool:
	return _thumped < THUMP_TIME or _grunted < GRUNT_TIME


## Where the tip of its nose is, in the world.
func nose() -> Vector3:
	return _head.global_transform * _nose if _head else global_position


## The top of its head (the points of a jackalope's antlers), in the world.
func brow() -> Vector3:
	return _head.global_transform * _brow if _head else global_position


func _process(delta: float) -> void:
	if _rabbit == null or _skeleton == null:
		return
	# (far off, posed only now and then: the time between goes into the next)
	_waited += delta
	_skip += 1
	if _skip < pose_every:
		return
	_skip = 0
	delta = minf(_waited, 1.0 / 20.0)
	_waited = 0.0
	_time += delta
	var velocity := _rabbit.velocity / maxf(global_basis.get_scale().x, 0.01)
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _rabbit.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw

	# --- Moods ---
	var r := _rabbit
	_graze = _approach(_graze, 1.0 if r.grazing and not r.alert else 0.0, 4.0, delta)
	_alert = _approach(_alert, 1.0 if r.alert else 0.0, 8.0 if r.alert else 2.5, delta)
	_upright = _approach(_upright, 1.0 if r.upright or r.boxing else 0.0, 6.0 if r.upright else 4.0, delta)
	_wash = _approach(_wash, 1.0 if r.washing and not r.upright else 0.0, 4.0, delta)
	_flat = _approach(_flat, 1.0 if r.flattened else 0.0, 7.0 if r.flattened else 3.0, delta)
	_flee = _approach(_flee, 1.0 if r.fleeing else 0.0, 7.0, delta)
	_flag = _approach(_flag, 1.0 if r.flagging else 0.0, 12.0 if r.flagging else 2.5, delta)
	_box = _approach(_box, 1.0 if r.boxing else 0.0, 6.0, delta)
	_lower = _approach(_lower, 1.0 if r.lowered else 0.0, 6.0, delta)
	_thumped += delta
	_grunted += delta
	var watching := _alert * uncanny if r.look_at_point.is_finite() else 0.0
	if materials.has("parts"):
		(materials["parts"] as ShaderMaterial).set_shader_parameter(&"eyeshine", eyeshine * (1.0 + 1.5 * _alert + 3.0 * watching))
	_puffed = clampf(_puffed + (speed / (6.0 * _size) * 0.25 - 0.06) * delta, 0.0, 1.0)
	if grounded and not _was_grounded:
		_crouch_velocity += 1.2
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 300.0 - _crouch_velocity * 24.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.2)
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed / _size, absf(_turn) * 0.08), 10.0, delta)
	var bound := smoothstep(BOUND_AT.x, BOUND_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	var still := (1.0 - _upright) * (1.0 - _wash) * (1.0 - _flat * 0.6)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var gait := smoothstep(0.04, 0.3, _pace) * (1.0 - _air) * still
	var travel := clampf(speed / maxf(_pace * _size, 0.05), 0.0, 1.0)
	var big := stride * _size * travel
	var targets: Array[Vector3] = []
	var leans: Array[float] = []
	var pitches: Array[float] = []
	for i in 4:
		var fore := i < 2
		var duty: float = lerpf(HOP_DUTY.x if fore else HOP_DUTY.y, BOUND_DUTY.x if fore else BOUND_DUTY.y, bound)
		var down := lerpf(HOP_DOWN[i], BOUND_DOWN[i], bound)
		var u := fposmod(_phase - down, 1.0)
		var rest := _paws[i]
		var land := lerpf(0.5 * duty * big, (0.03 if fore else 0.05) * _size + (0.8 if fore else 0.45) * duty * big, bound)
		var lift := lerpf(0.022 if fore else 0.03, 0.065 if fore else 0.075, bound) * _size
		var z := 0.0
		var y := 0.0
		var lean := _rest_lean[i]
		var pitch := 0.0
		if u < duty:
			var k := u / duty
			z = land - u * big
			if fore:
				# (the hand comes up vertical, then back, as the forefoot is left behind)
				lean = lerpf(_rest_lean[i], lerpf(1.2, 1.75, bound), smoothstep(0.35, 1.0, k))
			else:
				# (the hind foot flat as it lands; up on its toes as it drives off, the more the faster)
				lean = lerpf(_rest_lean[i], lerpf(0.7, 1.35, bound), smoothstep(0.3, 1.0, k))
		else:
			var w := (u - duty) / (1.0 - duty)
			var off := land - duty * big
			z = lerpf(off, land, smoothstep(0.0, 1.0, w))
			y = sin(PI * pow(w, 0.8)) * lift
			if fore:
				# (tucked up under the chest, then reaching out to land)
				lean = lerpf(lerpf(2.0, 2.6, bound), lerpf(0.9, 0.35, bound), smoothstep(0.25, 0.9, w))
				pitch = lerpf(1.1, -0.2, smoothstep(0.3, 0.9, w))
			else:
				# (flung out behind, the foot trailing, then swung forward, folded, to land flat)
				z -= 0.06 * _size * bound * sin(PI * clampf(w / 0.4, 0.0, 1.0))
				lean = lerpf(lerpf(1.2, 1.9, bound), lerpf(0.4, 0.15, bound), smoothstep(0.15, 0.8, w))
				pitch = lerpf(lerpf(1.0, 2.0, bound), 0.1, smoothstep(0.3, 0.95, w))
		targets.append(Vector3(rest.x, _paw_height + y * gait, rest.z + z * gait))
		leans.append(lerpf(_rest_lean[i], lean, gait))
		pitches.append(pitch * gait)

	# --- The body over them ---
	var cycle := TAU * _phase
	var extended := clampf((_phase - 0.62) / 0.38, 0.0, 1.0)
	var gathered := clampf((_phase - 0.2) / 0.25, 0.0, 1.0)
	var rise := (sin(PI * extended) * RISE * minf(stride / 1.2, 1.3) + sin(PI * gathered) * 0.012) * _size * bound * gait
	var stand := gait * lerpf(0.012, 0.03, bound) * _size
	var pitch_body := lerpf(0.05 * sin(cycle - TAU * 0.6), 0.1 + 0.16 * cos(cycle - TAU * 0.03), bound) * gait
	var flex := lerpf(sin(PI * clampf((_phase - 0.4) / 0.45, 0.0, 1.0)) * 0.6,
			sin(PI * clampf((_phase - 0.16) / 0.32, 0.0, 1.0)) - 0.7 * sin(PI * extended), bound) * gait
	var bank := clampf(-_turn * speed * 0.02, -0.25, 0.25)
	var air_pitch := _air * clampf(-velocity.y * 0.05, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, stand + rise - _crouch * _size * 0.08, 0.0)
	var body_turn := Vector3(pitch_body + air_pitch, 0.0, bank)
	var chest_turn := Vector3(0.14 * flex, clampf(_turn * 0.04, -0.2, 0.2), 0.0)
	var pelvis_turn := Vector3(-0.38 * flex, -clampf(_turn * 0.03, -0.15, 0.15), 0.0)
	var pelvis_at := _pelvis_rest + Vector3(0.0, -0.004 * flex, 0.022 * flex) * _size
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]

	# Grazing: the front lower. Alert: up a little at the front, on its forelegs.
	body_turn.x += 0.08 * _graze - 0.06 * _alert * (1.0 - _upright)
	body_at.y += 0.006 * _size * _alert * (1.0 - _upright)
	# Flattened: pressed to the ground, the legs folded under it.
	body_at.y -= 0.035 * _size * _flat
	body_turn.x += 0.05 * _flat
	# Lowered: the front down, the head will go down further.
	body_turn.x += 0.08 * _lower

	# The thump: both hind feet lifted and slammed down.
	if _thumped < THUMP_TIME:
		var k := _thumped / THUMP_TIME
		var raised := sin(PI * clampf(k / 0.6, 0.0, 1.0)) if k < 0.6 else 0.0
		if k >= 0.6 and k < 0.66:
			_crouch_velocity -= 0.5
		for i in [2, 3]:
			targets[i] += Vector3(0.0, 0.03 * _size * raised, -0.01 * _size * raised)
			leans[i] = lerpf(leans[i], 0.9, raised)
		body_turn.x += 0.07 * raised
		body_at.y += 0.012 * _size * raised

	# Sat up (upright, washing, boxing): turned up about its hips, the hind feet flat, the forepaws at its chest.
	var up := maxf(_upright, _wash * 0.82) * (1.0 - gait)
	if up > 0.01:
		var tall := smoothstep(0.0, 1.0, up)
		var pitch := -lerpf(1.05, 1.3, _box) * tall
		# (turned up about the bottom of its rump, which comes down onto its heels: it sits back on them)
		var seat := Vector3(0.0, 0.045 * _size, _hips[2].z - 0.035 * _size) - _body_rest
		body_at += seat - Basis(Vector3.RIGHT, pitch) * seat + Vector3(0.0, 0.05 * _size * _box * tall, 0.0)
		body_turn.x += pitch
		var turned := Transform3D(Basis.from_euler(body_turn), body_at)
		var face := turned * (_head_rest - _body_rest + Vector3(0.0, -0.005, 0.045) * _size)
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			var shoulder := turned * (_hips[i] - _body_rest)
			var held := shoulder + Vector3(0.0, -0.045 * _size, 0.03 * _size)
			var lean := 2.3
			if _wash > 0.01:
				# (both paws drawn down over the face from above the eyes, together; every third stroke one licked)
				_wash_clock += delta / WASH_TIME / 2.0
				var stroke := fposmod(_wash_clock * 2.0, 1.0)
				var down := smoothstep(0.0, 0.7, stroke) if stroke < 0.7 else 1.0 - smoothstep(0.7, 1.0, stroke)
				var rub := face + Vector3(side * 0.012 * _size, (0.03 - 0.05 * down) * _size, 0.008 * _size)
				held = held.lerp(rub, smoothstep(0.2, 0.9, _wash))
				lean = lerpf(lean, 1.0, _wash)
			if _box > 0.01:
				# (a punch, one and then the other)
				_punch_clock += delta / PUNCH_TIME / 2.0
				var punch := maxf(sin(TAU * (_punch_clock + i * 0.5)), 0.0)
				var strike := shoulder + Vector3(0.0, 0.0, 0.035 * _size) + Vector3(0.0, 0.03, 0.08) * _size * punch
				held = held.lerp(strike, _box)
				lean = lerpf(lean, lerpf(1.6, 0.4, punch), _box)
			targets[i] = targets[i].lerp(held, smoothstep(0.25, 1.0, up))
			leans[i] = lerpf(leans[i], lean, up)
			pitches[i] = lerpf(pitches[i], 0.9, up)
			poles[i] = poles[i].slerp(Vector3(0.0, -0.4, -1.0).normalized(), up)
		for i in [2, 3]:
			# (boxing, up on its toes)
			leans[i] = lerpf(leans[i], 0.9, _box)
	else:
		_wash_clock = 0.0

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_pelvis.position = pelvis_at
	_breathe(delta)
	_look_about(delta, watching)
	_pose_head(delta, body_turn.x + chest_turn.x, bound * gait, watching)
	_pose_face(delta, watching)
	_pose_legs(targets, leans, pitches, poles, velocity.y)
	_carry_tail(delta, bound * gait)
	_carry_ears(delta, bound * gait, watching)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## Its ribs: quick and shallow, quicker after it has run; held still in its form.
func _breathe(delta: float) -> void:
	var panting := smoothstep(0.2, 0.6, _puffed)
	_breath += delta * TAU * lerpf(1.1, 3.2, panting) * (1.0 - 0.6 * _flat)
	var swell := sin(_breath) * lerpf(0.016, 0.03, panting) * (1.0 - 0.7 * _flat)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell * 0.7, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## Head and neck: kept level whatever the body under them is doing, turned to
## what it watches; down to the grass grazing, high alert, out and low in its
## form, stretched out bounding, down to charge.
func _pose_head(delta: float, upstream: float, running: float, watching: float) -> void:
	var yaw := _look.x * (1.0 - _graze * 0.6) * (1.0 - _flat * 0.8)
	var pitch := _look.y * (1.0 - _graze) * (1.0 - _flat) * (1.0 - _lower)
	# Grazing: the neck down, the head turned down at the end of it, nose to the grass.
	pitch += 0.75 * _graze
	var raise := 0.28 * _alert + 0.1 * _flag * (1.0 - running)
	# Washing: the head bobs down into the paws with each stroke.
	if _wash > 0.01:
		var stroke := fposmod(_wash_clock * 2.0, 1.0)
		pitch += (0.25 + 0.2 * sin(TAU * stroke)) * _wash
		yaw += sin(_wash_clock * PI * 0.66) * 0.3 * _wash
	# A grunt: the head jerks down and forward.
	if _grunted < GRUNT_TIME:
		var k := _grunted / GRUNT_TIME
		pitch += sin(PI * minf(k / 0.25, 1.0)) * 0.35 * (1.0 if k < 0.25 else 0.0) + sin(PI * clampf((k - 0.25) / 0.75, 0.0, 1.0)) * 0.15
	var stretch := running * (0.2 + 0.06 * sin(TAU * _phase))
	var neck := Vector3(-upstream * 0.6 + pitch * 0.5 - raise + stretch, yaw * 0.5, 0.0)
	var head := Vector3(-upstream * 0.4 + pitch * 0.5 + raise * 0.6 - stretch * 0.4, yaw * 0.5, 0.0)
	# Flattened: the neck stretched out low along the ground, the chin down.
	neck.x += -0.25 * _flat
	head.x += 0.35 * _flat
	# Lowered: the neck down, the head tucked so that the top of it (a jackalope's antlers) leads.
	neck.x += 0.45 * _lower
	head.x += 0.9 * _lower
	head.z += sin(_time * 2.1) * 0.05 * _lower
	if watching > 0.0:
		# (the jackalope watching: its head turns round further, and holds there)
		head.y = lerpf(head.y, _look.x * 0.75, watching)
	_neck.rotation = neck
	_head.rotation = head


## The jaw nibbling while it grazes, a little open as it grunts; the nose and
## the split lip twitching, in bursts, faster when it is alert (not while it
## lies in its form, nor a jackalope watching).
func _pose_face(delta: float, watching: float) -> void:
	var open := _graze * 0.10 * maxf(sin(_time * 31.0), 0.0)
	if _grunted < GRUNT_TIME:
		open = maxf(open, sin(PI * _grunted / GRUNT_TIME) * 0.6)
	open = maxf(open, smoothstep(0.4, 0.8, _puffed) * 0.12)
	_mouth = lerpf(_mouth, open, 0.5)
	_jaw.rotation.x = _mouth * GAPE
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(0.4, 2.0) if _sniffing > 0.5 else randf_range(0.5, 1.5)
		_sniffing = 1.0 if randf() < lerpf(0.55, 0.9, _alert) else 0.0
	var quiet := (1.0 - _flat) * (1.0 - watching)
	_twitch += delta * TAU * lerpf(7.0, 11.0, _alert)
	_lip.rotation.x = sin(_twitch) * 0.09 * _sniffing * quiet
	_lip.position.y = _lip_rest().y + sin(_twitch) * 0.0012 * _size * _sniffing * quiet


func _lip_rest() -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(&"lip")).origin


func _pose_legs(targets: Array[Vector3], leans: Array[float], pitches: Array[float], poles: Array[Vector3], vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 4.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		# (in the air: the forefeet reach down to land, the hind feet trail as it rises and come forward to land)
		var stretched := rest + Vector3(0.0, 0.03, 0.08 if fore else -0.07) * _size
		var landing := rest + Vector3(0.0, 0.02, 0.05 if fore else 0.02) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var lean := lerpf(leans[i], 1.3 if fore else 1.6, _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - (_chest_rest if fore else _pelvis_rest))
		var paw := to_body * target
		var last := to_body.basis * Vector3(0.0, -sin(lean), cos(lean))
		_solve_leg(i, hip, paw, last, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.8, _air)), to_body.basis * poles[i])


## Two-bone IK (hip, elbow or stifle, wrist or hock) in body space, with the
## last bone (the hand, the long foot) laid along `last` to the paw.
func _solve_leg(index: int, hip: Vector3, paw: Vector3, last: Vector3, paw_basis: Basis, pole: Vector3) -> void:
	var lengths := _lengths[index]
	var far := lengths.x + lengths.y - 0.002 * _size
	# (never folded up so tight that the knee comes up through the back)
	var near := maxf(absf(lengths.x - lengths.y) + 0.006 * _size, (lengths.x + lengths.y) * (0.5 if index >= 2 else 0.35))
	var line := (paw - hip).normalized() if (paw - hip).length_squared() > 0.000001 else Vector3.DOWN
	var reach := (paw - hip).length()
	if reach > far + lengths.z * 0.98:
		paw = hip + line * (far + lengths.z * 0.98)
	var second := paw - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = paw - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized() if across.length_squared() > 0.0000001 else Vector3.DOWN
	second = hip + along * gap
	paw = second + last * lengths.z
	var aside := pole - along * pole.dot(along)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + aside * sin(fold)) * lengths.x
	var normal := aside.cross(along).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Rabbit's `look_at_point`),
## or lets it look about.
func _look_about(delta: float, watching: float) -> void:
	var target := Vector2.ZERO
	var point := _rabbit.look_at_point
	var turns := lerpf(1.5, 2.5, uncanny)
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -turns, turns)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.5)
	else:
		target.x = sin(_time * 0.41) * 0.3 + sin(_time * 0.93 + 1.0) * 0.1
		target.y = 0.04 + sin(_time * 0.31 + 2.0) * 0.05
	# (alert, it turns its head in quick snaps and holds it; the jackalope, smoothly, as if it were not moving at all)
	var rate := lerpf(5.0, 16.0, _alert) * lerpf(1.0, 0.25, watching)
	_look = _look.lerp(target, 1.0 - exp(-rate * delta))


## The scut: tucked down at ease, held up against the rump flagging, a flick
## now and then.
func _carry_tail(delta: float, running: float) -> void:
	var up := _flag * 2.0 + 0.3 * running * (1.0 - _flag) + 0.25 * _alert * (1.0 - _flag)
	var curl := up - _pelvis.rotation.x * 0.7 - _body.rotation.x * 0.4
	_tail.aim = Basis(Vector3.RIGHT, curl) * _tail.rest
	_tail.limit = 0.4


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * 1.5


## The ears: at ease each turns about on its own, and one now and then lies
## out to the side; alert, both up and forward, and one swivels back,
## listening; laid back along the neck as it runs, flat along its back in its
## form, back as it grunts or charges.
func _carry_ears(delta: float, running: float, watching: float) -> void:
	var back := maxf(maxf(_flee, running * 0.6), maxf(_lower * 0.9, 1.0 if _grunted < GRUNT_TIME else 0.0))
	var flat := _flat
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.5, 2.0) if _alert > 0.5 else randf_range(0.8, 3.2)
		var pick := randi() % 4
		var far := 1.4 if _alert > 0.5 else 0.9
		_ear_turn_to = Vector2(randf_range(0.5, far) if pick == 0 else 0.0, randf_range(0.5, far) if pick == 1 else 0.0)
		if watching > 0.5:
			# (the jackalope's ears both on whatever it watches, and still)
			_ear_turn_to = Vector2.ZERO
	_ear_turn = _ear_turn.lerp(_ear_turn_to * (1.0 - back) * (1.0 - flat), 1.0 - exp(-10.0 * delta))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		var forward := _alert * 0.35 * (1.0 - turn) + 0.3 * _upright * (1.0 - _alert)
		var lean := Basis(Vector3.RIGHT, -back * 1.15 - flat * 1.55 + forward + _graze * 0.15) * Basis(BEHIND, out * (back * 0.18 + flat * 0.05 - forward * 0.2 + _graze * 0.12))
		root.aim = lean * root.rest
		root.twist = out * (turn * 1.5 + back * 0.4 - forward * 0.6)
		tip.aim = Basis(Vector3.RIGHT, -(back + flat) * 0.15) * tip.rest
		root.stiffness = lerpf(900.0, 2200.0, maxf(back, flat))


func _swing(delta: float) -> void:
	var ground := global_position.y - position.y + 0.004
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
	var u := (time - t0) / (t1 - t0)
	return lerpf(v0, v1, u * u * (3.0 - 2.0 * u))


func _build() -> void:
	var model: Node = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	var hare := model_path.contains("hare") or model_path.contains("jackalope")
	materials = RabbitLook.dress(model, coat_tint, 0 if low_poly else fur_shells, eyeshine, colours, 0.004 if hare else 0.0032,
			Color(0.6, 0.95, 0.7) if uncanny > 0.0 else Color(0.95, 0.42, 0.25))
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_chest_rest = _chest.position
	_pelvis_rest = _pelvis.position
	_neck = _joint(_chest, &"neck")
	_head = _joint(_neck, &"head")
	_jaw = _joint(_head, &"jaw")
	_lip = _joint(_head, &"lip")
	_head_rest = _body_rest + _chest_rest + _rest(&"neck") + _rest(&"head")
	_nose = _rest(&"nose")
	_brow = _rest(&"brow")
	for i in 4:
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		var last := (at[3] - at[2]).normalized()
		_rest_lean.append(atan2(-last.y, last.z))
		var fore := i < 2
		var along := (at[2] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - along * pole.dot(along)).normalized()
		var normal := aside.cross(along).normalized()
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = _hips[2].y / HIP
	_tail = _link(_pelvis, &"tail", _rest(&"tail_end"))
	_tail.stiffness = 1400.0
	_tail.damping = 40.0
	_tail.gravity = 2.0
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var tip := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		root.stiffness = 900.0
		root.damping = 22.0
		root.gravity = 0.0
		root.drag = 0.5
		root.limit = 0.5
		tip.stiffness = 420.0
		tip.damping = 10.0
		tip.gravity = 1.2
		tip.drag = 0.5
		tip.limit = 0.6
		_ears[side] = [root, tip]


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
