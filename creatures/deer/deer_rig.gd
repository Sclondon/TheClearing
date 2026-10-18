class_name DeerRig
extends Node3D
## Poses a deer or an elk (creatures/deer/models, creatures/elk/models) in
## code, every frame, from what its Deer (the parent: a Deer or an Elk) says it
## is doing. After DogRig (creatures/dog/dog_rig.gd): hooves follow a gait
## cycle and are put down with IK (three bones and the hoof, each leg folding
## the way a deer's does: the elbow back, the knee forward, the stifle forward,
## the hock back), and the spine, neck, head and jaw are laid on top; the tail
## and the ears are on springs.
##
## THE GAITS, chosen by its speed (in a deer's measure: an elk, half as big
## again, strides as a big deer would): a four-beat walk, a trot on diagonal
## pairs, and a bounding gallop. In the gallop the hind legs drive off nearly
## together and fling out straight behind; it flies stretched out, forelegs
## reaching far ahead; it lands on its forelegs one after the other, they sweep
## back under it and push off, and the hind legs swing forward past them, folded
## up tight under its belly, for the next drive (the back arching as they come).
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - GRAZING: head down to the ground, the jaw working.
## - ALERT: frozen, the neck straight up, the head high and level, the tail
##   half raised; only the ears move, swivelling, one and then the other
##   turning back; the eyes give back more light.
## - FLAGGING: the tail stands straight up, flicking, the white under it and
##   round it showing. FLEEING: ears back.
## - PRONKING (stotting): bounds straight up off all four legs at once, legs
##   stiff and straight under it, hooves bunched, head up.
## - STAMP: a forefoot lifted high and driven down. SNORT: the head jerks up
##   and back as the breath goes out of it.
## - WRONG (Deer.wrong): its cannons are too long (it stands taller than it
##   should), and its head turns round further than a neck allows.
## - UPRIGHT: stood up on its hind legs, the forelegs hanging folded, the head
##   kept level, looking.
## - An elk's: the BUGLE (neck stretched out and up, nose to the sky, mouth
##   open, trembling), PAWING (one forefoot scraping back over the ground again
##   and again, the head low) and LOWERED (head down, nose to the chest, the
##   antlers pointing ahead: how it charges).
##
## Every joint is read from the model's skeleton (tools/build_deer.py), so a
## model with other measurements on the same bones would do as well.

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## A deer's hip height, for its measure (a model this high is a size of 1).
const HIP := 0.785
## Where in the stride each hoof lands, walking, trotting and galloping.
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const TROT: Array[float] = [0.5, 1.0, 0.0, 0.5]
const GALLOP: Array[float] = [0.5, 0.58, 0.0, 0.07]
## The share of the stride a hoof is down, fore and hind, at a walk, a trot and a gallop.
const DUTY_FORE := Vector3(0.64, 0.46, 0.25)
const DUTY_HIND := Vector3(0.62, 0.44, 0.25)
## The middle of the stretched-out flight of a gallop stride (between the hind
## legs driving off and the forelegs landing).
const FLIGHT := 0.4
const BOUND := 0.07
## Speeds (m/s, for a deer of a size of 1) over which it goes from a walk to a trot, and a trot to a gallop.
const TROT_AT := Vector2(1.5, 2.0)
const GALLOP_AT := Vector2(3.4, 4.2)
## Length of a stride (m) against speed (m/s), for a size of 1.
const STRIDE := [0.0, 0.5, 1.0, 0.95, 2.5, 1.4, 4.2, 2.3, 8.0, 3.4, 13.0, 4.6]
## How far a planted hoof may sweep under it (m), and how much further galloping.
const REACH := 0.5
const GALLOP_REACH := 2.0
## Galloping: how far past where it lands a hoof reaches out first (fore,
## hind), and how far back it is flung as it leaves the ground (fore, hind).
const REACH_OUT := Vector2(0.22, 0.10)
const FLING_BACK := Vector2(0.10, 0.24)
const GLIDE := 0.25
const FOLD := Vector2(3.0, 2.6)
const FOLD_PLANTED := Vector2(-0.2, 0.7)
## A pronk: seconds a bound takes, the share of it on the ground, and how high (m, size 1).
const PRONK_TIME := 0.62
const PRONK_DOWN := 0.26
const PRONK_HEIGHT := 0.42
## A stamp and a snort, seconds.
const STAMP_TIME := 0.5
const SNORT_TIME := 0.45
## Pawing: seconds a stroke takes.
const PAW_TIME := 0.8
## How far the jaw drops, wide open, radians.
const GAPE := 0.55

## The model (set before it enters the tree; the Deer sets it).
var model_path := "res://creatures/deer/models/deer_doe.glb"
var low_poly := false
var fur_shells := 1
var coat_tint := Color.WHITE
var eyeshine := 0.6
var wrong := 0.0
## A fawn's spots, 0..1.
var spots := 0.0
var colours := {}
## The materials, by name (see DeerLook.dress).
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


var _deer: Deer
var _elk: Elk
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
var _stretch: Array[Basis] = []
var _size := 1.0
var _paw_height := 0.09
var _taller := 0.0
## Where its nose and its brow (the front of its antlers) are, in the head's space.
var _nose := Vector3.ZERO
var _brow := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _drop := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _mirrored := false
var _mouth := 0.0
var _breath := 0.0
var _puffed := 0.0
var _look := Vector2.ZERO
var _tilt := 0.0
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _twitch_timer := 3.0
var _swish := 0.0
## How far into each mood it is, 0..1.
var _graze := 0.0
var _alert := 0.0
var _flag := 0.0
var _flee := 0.0
var _pronk := 0.0
var _pronk_clock := 0.0
var _upright := 0.0
var _bugle := 0.0
var _paw := 0.0
var _paw_clock := 0.0
var _lower := 0.0
var _stamped := 9.0
var _snorted := 9.0


func _ready() -> void:
	_deer = get_parent() as Deer
	_elk = _deer as Elk
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


func stamp() -> void:
	_stamped = 0.0


func snort() -> void:
	_snorted = 0.0
	for side in 2:
		_flick(side, Vector3(0.0, 0.6, -0.6))


func busy() -> bool:
	return _stamped < STAMP_TIME or _snorted < SNORT_TIME


## Where the tip of its nose is, in the world.
func nose() -> Vector3:
	return _head.global_transform * _nose if _head else global_position


## The way its nose points, in the world (for breath).
func nose_way() -> Vector3:
	if _head == null:
		return global_basis.z
	return (_head.global_transform * _nose - _head.global_transform * (_nose * 0.6)).normalized()


## The way out of its open mouth, in the world (for a bugle's steam).
func mouth_way() -> Vector3:
	return (nose_way() + Vector3.UP * 0.4).normalized()


## The front of its antlers (or its brow), in the world: what a charge strikes with.
func brow() -> Vector3:
	return _head.global_transform * _brow if _head else global_position


func _process(delta: float) -> void:
	if _deer == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	# (it works in a deer's measure: an elk half as big again strides as a deer would going two thirds as fast)
	var velocity := _deer.velocity / maxf(global_basis.get_scale().x, 0.01) / _size
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _deer.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw

	# --- Moods ---
	_graze = _approach(_graze, 1.0 if _deer.grazing and not _deer.alert else 0.0, 3.0, delta)
	_alert = _approach(_alert, 1.0 if _deer.alert else 0.0, 7.0 if _deer.alert else 2.5, delta)
	_flag = _approach(_flag, 1.0 if _deer.flagging else 0.0, 9.0 if _deer.flagging else 2.0, delta)
	_flee = _approach(_flee, 1.0 if _deer.fleeing else 0.0, 6.0, delta)
	_pronk = _approach(_pronk, 1.0 if _deer.pronking and grounded else 0.0, 8.0, delta)
	_upright = _approach(_upright, 1.0 if _deer.upright else 0.0, 2.2, delta)
	if _elk:
		_bugle = _approach(_bugle, 1.0 if _elk.bugling() and _elk.bugle_progress() < 0.9 else 0.0, 6.0 if _elk.bugling() else 3.0, delta)
		_paw = _approach(_paw, 1.0 if _elk.pawing else 0.0, 6.0, delta)
		_lower = _approach(_lower, 1.0 if _elk.lowered else 0.0, 5.0, delta)
		if materials.has("mane"):
			(materials["mane"] as ShaderMaterial).set_shader_parameter(&"sway", clampf(speed * 0.008, 0.0, 0.05) + 0.02 * _bugle)
	_stamped += delta
	_snorted += delta
	if materials.has("parts"):
		(materials["parts"] as ShaderMaterial).set_shader_parameter(&"eyeshine", eyeshine * (1.0 + 2.5 * _alert))
	_puffed = clampf(_puffed + (speed / 6.0 * 0.22 - 0.05) * delta, 0.0, 1.0)
	if _elk:
		_elk.heavy = maxf(_puffed, _paw * 0.5)
	if grounded and not _was_grounded:
		_crouch_velocity += 1.5
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 240.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.16)
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.25), 10.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace) * (1.0 - _pronk)
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var still := (1.0 - _pronk) * (1.0 - _upright * 0.0)
	var gait := smoothstep(0.05, 0.45, _pace) * (1.0 - _air) * still
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(0.06, 0.10, trot), 0.30, gallop) * _size
	var flying := gallop * gait
	var bound := cos(2.0 * TAU * (_phase - FLIGHT))
	var rise := (0.2 + bound) * BOUND * _size * flying
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := DUTY_FORE if fore else DUTY_HIND
		var duty := lerpf(lerpf(duties.x, duties.y, trot), duties.z, gallop)
		var span := minf(duty * stride * _size, REACH * lerpf(1.0, GALLOP_REACH, gallop) * _size) * travel
		var middle := lerpf(-0.03, 0.05 if fore else -0.03, gallop) * travel * _size
		var other := i ^ 1 if _mirrored else i
		var at := fposmod(_phase - lerpf(lerpf(WALK[i], TROT[i], trot), GALLOP[other], gallop), 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85), gallop)
		if at >= duty and flying > 0.0:
			# Galloping, a hoof is flung out behind as it leaves the ground, and
			# reaches out ahead before it lands (drawn back under it as it does).
			var swing := (at - duty) / (1.0 - duty)
			var out: float = REACH_OUT.x if fore else REACH_OUT.y
			var back: float = FLING_BACK.x if fore else FLING_BACK.y
			cycle.z += (out * sin(PI * smoothstep(0.45, 1.0, swing)) - back * sin(PI * clampf(swing / 0.35, 0.0, 1.0))) * _size * travel * flying
		var rest := _paws[i]
		var carried := 0.0
		if at >= duty:
			var swing := (at - duty) / (1.0 - duty)
			carried = clampf(minf(swing, 1.0 - swing) * 6.0, 0.0, 1.0) * maxf(rise, 0.0)
		targets.append(Vector3(rest.x * lerpf(1.0, 0.8, trot * gait), _paw_height + (cycle.y + carried) * gait, rest.z + (middle + cycle.z) * gait))
		pitches.append(cycle.x * gait)
		if at < duty:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait * (1.0 - 0.45 * flying)) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.012 * _size
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	_drop = _approach(_drop, drop + 0.004 * _size, 9.0, delta)
	var sprung := 0.02 * trot * (1.0 - gallop) * _size
	var vault := 0.014 * (1.0 - trot) * _size
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	var rock := (high_hind - high_fore) / (0.7 * _size) + sin(TAU * (_phase - FLIGHT)) * 0.07 * flying
	var back_bend := cos(TAU * (_phase - FLIGHT - 0.5)) * flying
	var bend := clampf(_turn * 0.05, -0.25, 0.25)
	var swing_fore := (targets[1].z - targets[0].z) * 0.18 * (1.0 - gallop) / _size
	var swing_hind := (targets[3].z - targets[2].z) * 0.22 * (1.0 - gallop) / _size
	var bank := clampf(-_turn * speed * 0.012, -0.2, 0.2)
	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch * _size + (high_fore + high_hind) * 0.5 + rise + _taller, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	var chest_turn := Vector3(back_bend * 0.22, bend + swing_fore, (targets[0].y - targets[1].y) * 0.5 / _size)
	var pelvis_turn := Vector3(-back_bend * 0.42, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.6 / _size)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	position.y = 0.0

	# Grazing: the front of it a little lower.
	body_turn.x += 0.05 * _graze
	# Alert: stiff, a little up at the front.
	body_turn.x -= 0.03 * _alert
	# Lowered (an elk about to charge, or charging): the front sinks.
	body_turn.x += 0.07 * _lower * (1.0 - flying)
	body_at.y -= 0.03 * _size * _lower

	# The pronk: up off all four at once, legs stiff and bunched under it.
	if _pronk > 0.01:
		_pronk_clock += delta / PRONK_TIME
		var u := fposmod(_pronk_clock, 1.0)
		var up := 0.0
		var squat := 0.0
		if u < PRONK_DOWN:
			squat = sin(PI * u / PRONK_DOWN)
		else:
			up = sin(PI * (u - PRONK_DOWN) / (1.0 - PRONK_DOWN))
		position.y = up * PRONK_HEIGHT * _size * _pronk
		body_at.y -= squat * 0.06 * _size * _pronk
		body_turn.x += (-0.12 * up + 0.05 * squat) * _pronk
		for i in 4:
			var fore := i < 2
			var bunched := _paws[i] + Vector3(0.0, 0.0, (-0.06 if fore else 0.07) * _size * up)
			targets[i] = targets[i].lerp(Vector3(bunched.x, _paw_height, bunched.z), _pronk)
			pitches[i] = lerpf(pitches[i], 0.15 * up, _pronk)
	else:
		_pronk_clock = 0.0

	# The stamp: a forefoot lifted high and brought down hard.
	if _stamped < STAMP_TIME:
		var u := _stamped / STAMP_TIME
		var raised := sin(PI * clampf(u / 0.55, 0.0, 1.0))
		if u > 0.55:
			raised = 0.0
			if u < 0.6:
				_crouch_velocity -= 0.6
		var leg := 0 if not _mirrored else 1
		targets[leg] += Vector3(0.0, 0.2 * _size * raised, 0.05 * _size * raised)
		pitches[leg] += 1.1 * raised
		body_turn.x -= 0.04 * raised

	# Pawing (an elk): one forefoot scraping back over the ground, again and again.
	if _paw > 0.01:
		_paw_clock += delta / PAW_TIME
		var u := fposmod(_paw_clock, 1.0)
		var leg := 1 if not _mirrored else 0
		var lift_up := 0.0
		var reach_z := 0.0
		if u < 0.35:
			var k := u / 0.35
			lift_up = sin(PI * k * 0.85) * 0.16
			reach_z = lerpf(-0.12, 0.2, smoothstep(0.0, 1.0, k))
		elif u < 0.45:
			var k := (u - 0.35) / 0.1
			lift_up = lerpf(0.06, 0.0, k)
			reach_z = 0.2
		elif u < 0.9:
			reach_z = lerpf(0.2, -0.12, smoothstep(0.0, 1.0, (u - 0.45) / 0.45))
		else:
			reach_z = -0.12
			lift_up = sin(PI * (u - 0.9) / 0.1) * 0.03
		var scrape := _paws[leg] + Vector3(0.0, lift_up * _size, reach_z * _size)
		targets[leg] = targets[leg].lerp(Vector3(scrape.x, _paw_height + scrape.y - _paws[leg].y, scrape.z), _paw)
		pitches[leg] = lerpf(pitches[leg], 0.9 * lift_up / 0.16 if u < 0.45 else -0.25, _paw)
		body_turn.x += 0.03 * _paw
		chest_turn.z += 0.04 * _paw * (1.0 if leg == 1 else -1.0)
	else:
		_paw_clock = 0.0

	# Upright: stood up on its hind legs, turned up about its hips, the forelegs hanging folded.
	if _upright > 0.01:
		var pitch := -1.15 * smoothstep(0.0, 1.0, _upright)
		var hip := Vector3(0.0, _hips[2].y, _hips[2].z) - _body_rest
		body_at += hip - Basis(Vector3.RIGHT, pitch) * hip + Vector3(0.0, 0.05 * _size * _upright, 0.0)
		body_turn.x += pitch
		var turned := Transform3D(Basis.from_euler(body_turn), body_at)
		for i in 2:
			var shoulder := turned * (_hips[i] - _body_rest)
			var hanging := shoulder + Vector3(0.0, -0.32 * _size, 0.12 * _size)
			targets[i] = targets[i].lerp(hanging, smoothstep(0.2, 1.0, _upright))
			pitches[i] = lerpf(pitches[i], 1.2, _upright)
			poles[i] = poles[i].slerp(Vector3(0.0, -0.3, -1.0).normalized(), _upright)

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_breathe(delta)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, flying, gallop)
	_pose_jaw()
	_pose_legs(targets, pitches, poles, velocity.y)
	_carry_tail(delta, gallop)
	_carry_ears(delta, gallop)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


## Its ribs: slow and deep, quick and shallow when it has run; still when it is frozen.
func _breathe(delta: float) -> void:
	var panting := smoothstep(0.25, 0.6, _puffed)
	_breath += delta * TAU * lerpf(lerpf(0.4, 0.15, _alert), 2.4, panting)
	var swell := sin(_breath) * lerpf(lerpf(0.012, 0.004, _alert), 0.02, panting)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## Head and neck: kept level whatever the body under them is doing, turned to
## what it watches; down to the ground grazing, high and straight alert,
## stretched out galloping, thrown up to bugle, down with the antlers forward.
func _pose_head(delta: float, upstream: float, flying: float, gallop: float) -> void:
	_tilt = _approach(_tilt, 0.0, 5.0, delta)
	var yaw := _look.x * (1.0 - _graze * 0.7) * (1.0 - _bugle * 0.6)
	var pitch := _look.y * (1.0 - _graze) * (1.0 - _bugle) * (1.0 - _lower)
	# Grazing: the neck down and forward, the head turned down at the end of it, nose to the ground.
	pitch += 1.65 * _graze
	# Alert: the neck straight up, the head high.
	var raise := 0.32 * _alert + 0.18 * _pronk + 0.15 * _flag * (1.0 - flying)
	# A snort: the head jerks up and back, then down.
	if _snorted < SNORT_TIME:
		var u := _snorted / SNORT_TIME
		raise += sin(PI * minf(u / 0.3, 1.0)) * 0.22 * (1.0 if u < 0.3 else 0.0) - sin(PI * clampf((u - 0.3) / 0.7, 0.0, 1.0)) * 0.12
	# Galloping: stretched out ahead.
	var stretch := flying * (0.32 + 0.06 * sin(TAU * (_phase - FLIGHT))) * (1.0 - _lower)
	var neck := Vector3(-upstream * 0.55 + pitch * 0.55 - raise + stretch, yaw * 0.45, 0.0)
	var head := Vector3(-upstream * 0.45 + pitch * 0.45 + raise * 0.7 - stretch * 0.5, yaw * 0.4, _tilt)
	# The bugle: the neck out and up, the nose to the sky.
	neck.x += 0.42 * _bugle
	head.x -= 1.55 * _bugle
	head.x += sin(_time * 29.0) * 0.012 * _bugle
	# Lowered: the neck down, the nose tucked to the chest, the antlers forward; tossing a little.
	neck.x += 0.8 * _lower
	head.x += (1.5 + 0.05 * sin(_time * 3.1)) * _lower
	head.z += sin(_time * 2.3) * 0.06 * _lower
	# Pawing: the head low.
	neck.x += 0.25 * _paw * (1.0 - _lower)
	_chest.rotation.y += yaw * 0.08
	if wrong > 0.0:
		# (the wrong one's head comes round further than it should, and stays a little too long on one side)
		head.y = yaw * lerpf(0.4, 0.58, wrong)
		head.z += sin(_time * 0.37) * 0.12 * wrong * _alert
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = head


## The jaw: chewing grazing, open to bugle, panting after a long run.
func _pose_jaw() -> void:
	var open := 0.0
	open = maxf(open, _graze * 0.12 * (0.5 + 0.5 * sin(_time * 8.5)))
	if _elk and _elk.bugling():
		var u := _elk.bugle_progress()
		open = maxf(open, smoothstep(0.05, 0.2, u) * (1.0 - smoothstep(0.7, 0.8, u)) * (0.85 + 0.1 * sin(_time * 23.0)))
		# (the grunts at its end)
		if u > 0.72:
			open = maxf(open, absf(sin((u - 0.72) / 0.28 * PI * 4.0)) * 0.4)
	var panting := smoothstep(0.35, 0.7, _puffed)
	open = maxf(open, panting * (0.15 + 0.06 * sin(_breath)))
	_mouth = lerpf(_mouth, open, 0.5)
	_jaw.rotation.x = _mouth * GAPE


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var stretched := rest + Vector3(0.0, 0.12, 0.30 if fore else -0.30) * _size
		var landing := rest + Vector3(0.0, 0.10 if fore else 0.16, 0.22 if fore else -0.04) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * GLIDE, -0.07 * _size, 0.07 * _size)
		var lifted := maxf(_air, clampf((target.y - _paw_height) / (0.05 * _size), 0.0, 1.0))
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.6, _air)), to_body.basis * poles[i], lifted)


## Where a hoof is in its stride: x how far the fetlock is bent (the hoof
## turned back), y how high, z how far ahead.
func _foot_cycle(phase: float, duty: float, half_step: float, lift: float, gallop: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.75, 1.0, planted) * 0.35, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	var bent := lerpf(1.2, 1.7, gallop)
	return Vector3(lerpf(bent, -0.15, smoothstep(0.15, 0.85, swing)), sin(PI * pow(swing, 0.75)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (DogRig._solve_leg); the
## wrong deer's cannons and forearms are drawn longer than they are.
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis, pole: Vector3, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06 * _size, total - 0.004 * _size)
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
	var far := lengths.x + lengths.y - 0.003 * _size
	var near := absf(lengths.x - lengths.y) + 0.01 * _size
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
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1] * _stretch[index * 2], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2] * _stretch[index * 2 + 1], second)
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Deer's `look_at_point`), or
## lets it gaze about.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _deer.look_at_point
	var turns := lerpf(1.7, 3.05, wrong)
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -turns, turns)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.8, 0.6)
	else:
		target.x = sin(_time * 0.37) * 0.35 + sin(_time * 0.83 + 1.0) * 0.12
		target.y = 0.05 + sin(_time * 0.29 + 2.0) * 0.06
	# (alert, it turns its head in snaps, and holds it)
	var rate := 14.0 if _alert > 0.5 else 5.0
	_look = _look.lerp(target, 1.0 - exp(-rate * delta))


## The tail: down and swishing at ease, standing straight up flagged, flicking.
func _carry_tail(delta: float, gallop: float) -> void:
	_swish += delta * TAU * lerpf(0.6, 2.6, _flag)
	var up := _flag * 2.5 + 0.35 * _alert * (1.0 - _flag) + 0.25 * gallop * (1.0 - _flag)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_swish - i * 0.9) * lerpf(0.12, 0.35, _flag) * (1.0 - _alert * 0.8)
		var curl := (up - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5) if i == 0 else -0.25 * _flag
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, -curl) * link.rest
		link.limit = lerpf(0.5, 0.2, _flag)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(1.5, 5.0)
		if _alert < 0.5 and randf() < 0.5:
			var which := randi() % 2
			_flick(which, Vector3(0.6 if which == 0 else -0.6, 0.4, 0.0))


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * 2.0


## The ears: at ease each turns about on its own; alert, both forward, and now
## and then one swivels right round behind, listening; laid back flat when it
## runs flat out, bugles or lowers its head to charge.
func _carry_ears(delta: float, gallop: float) -> void:
	var flat := maxf(maxf(_flee, gallop * 0.5), maxf(_bugle, _lower * 0.8))
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.5, 2.2) if _alert > 0.5 else randf_range(0.8, 3.0)
		var pick := randi() % 4
		var far := 1.6 if _alert > 0.5 else 1.0
		_ear_turn_to = Vector2(randf_range(0.6, far) if pick == 0 else 0.0, randf_range(0.6, far) if pick == 1 else 0.0)
	_ear_turn = _ear_turn.lerp(_ear_turn_to * (1.0 - flat), 1.0 - exp(-10.0 * delta))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		var forward := _alert * 0.35 * (1.0 - turn)
		var lean := Basis(Vector3.RIGHT, -flat * 1.1 + forward) * Basis(BEHIND, out * (flat * 0.25 - forward * 0.3))
		root.aim = lean * root.rest
		root.twist = out * (turn * 1.4 + flat * 0.4 - forward * 0.5)
		tip.aim = Basis(Vector3.RIGHT, -flat * 0.2) * tip.rest


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
	var model: Node = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = DeerLook.dress(model, coat_tint, 0 if low_poly else fur_shells, eyeshine, colours, 0.008 * (1.0 if _elk == null else 1.8))
	if spots > 0.0 and materials.has("coat"):
		DeerLook.tune(materials["coat"], {&"spots": spots})
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	_nose = _rest(&"nose")
	_brow = _rest(&"brow")
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
		var lengths := Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3]))
		# The wrong one: forearm, gaskin and cannons drawn out longer.
		var longer := 1.0 + 0.32 * wrong
		var lower_way := (at[2] - at[1]).normalized()
		var hock_way := (at[3] - at[2]).normalized()
		_stretch.append(_along(lower_way, lerpf(1.0, longer, 0.5)))
		_stretch.append(_along(hock_way, longer))
		lengths.y *= lerpf(1.0, longer, 0.5)
		lengths.z *= longer
		_lengths.append(lengths)
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
	_size = _hips[2].y / HIP
	# (with longer legs it stands that much taller)
	var plain := _hips[2].y - _paw_height
	var reach_now := 0.0
	for i in [2, 3]:
		reach_now += (_lengths[i].x + _lengths[i].y + _lengths[i].z) * 0.5
	var reach_was := 0.0
	for i in [2, 3]:
		var a := _body_rest + _rest("upper" + SUFFIXES[i])
		var b := _body_rest + _rest("lower" + SUFFIXES[i])
		var c := _body_rest + _rest("hock" + SUFFIXES[i])
		var d := _body_rest + _rest("paw" + SUFFIXES[i])
		reach_was += (a.distance_to(b) + b.distance_to(c) + c.distance_to(d)) * 0.5
	_taller = (reach_now - reach_was) * (plain / reach_was) * 0.95
	for i in 4:
		_spans[i] *= (plain + _taller) / plain
	var names: Array[String] = ["tail", "tail_1", "tail_end"]
	var from := _pelvis
	for i in 2:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = 1600.0 if i == 0 else 700.0
		link.damping = 45.0 if i == 0 else 22.0
		link.gravity = 3.0
		link.limit = 0.5
		_tail.append(link)
		from = link.joint
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var tip := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, tip]:
			link.stiffness = 1100.0 if link == root else 500.0
			link.damping = 24.0 if link == root else 11.0
			link.gravity = 0.0 if link == root else 1.5
			link.drag = 0.5
			link.limit = 0.5 if link == root else 0.6
		_ears[side] = [root, tip]


## A stretch along `way` by `amount` (1 none).
static func _along(way: Vector3, amount: float) -> Basis:
	var m := Basis.IDENTITY
	for k in 3:
		var axis := Vector3.ZERO
		axis[k] = 1.0
		m[k] = axis + way * way.dot(axis) * (amount - 1.0)
	return m


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
