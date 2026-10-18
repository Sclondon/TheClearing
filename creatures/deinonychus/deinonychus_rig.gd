class_name DeinonychusRig
extends Node3D
## Poses a deinonychus (creatures/deinonychus/models/deinonychus*.glb) in code,
## every frame, from what its Deinonychus (the parent) says it is doing. Its
## feet follow a two-legged gait cycle and are put down with IK; the body, the
## stiff tail, the neck, the head, the jaw, the wings and the sickle claws are
## laid on top.
##
## THE GAITS, chosen by its speed: a walk (each foot down a little over half
## the stride, the body vaulting over the planted leg and swaying side to side
## over it) and a run (feet down a third of it, with a flight between steps,
## the feet put down near the midline, the body lower and level, the head
## held dead still and the tail straight out). It leans into turns, the tail
## swinging out to balance it; slowing hard it sits back on its legs, braced,
## the tail up (its quick stops).
##
## A BIRD'S HEAD. Walking, its head is held still in the air while the body
## walks on under it and then thrust forward (the head-bob of a bird). Its
## head snaps from one pose to the next rather than turning smoothly, holds
## there, and snaps again; looking at something it cocks its head to one side
## to look with one eye.
##
## WHAT IT DOES, on top of the gait (each eases in and out):
## - CROUCHING: low and long, the neck drawn back into an S, the tail level.
## - TIRED: the jaw hanging open, panting, the chest heaving.
## - A HOOT: the head lifted and the throat swelling, the beak shut (a
##   closed-mouth call, as birds and crocodiles make); A CLICK: the jaw snapped
##   two or three times; A HISS: the jaw wide, the head low and thrust out.
## - THE POUNCE: a crouch (the wind-up: down on its legs, the head low and
##   fixed on what it wants, the tail flicking side to side), the leap (the
##   legs swung forward under it, the sickle claws forward and down, the wings
##   thrown open to steady it), and then the PIN (on what it has, its feet
##   driving down, the head down, the wings spread and beating to keep its
##   balance on top of it, as hawks do) or, if it missed, a stumble.
##
## Every joint is read from the model's skeleton (tools/build_deinonychus.py).

## A foot has come down: where, and how hard (0..1: a walk is light, a run heavy).
signal footfall(at: Vector3, weight: float)

## Left, right.
const SIDES: Array[String] = ["_l", "_r"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
## The share of the stride a foot is down, walking and running.
const DUTY := Vector2(0.62, 0.32)
## Speeds (m/s, in the model) over which it goes from a walk to a run.
const RUN_AT := Vector2(2.2, 3.2)
## Length of a stride (m, in the model: two steps) against speed (m/s).
const STRIDE := [0.0, 0.32, 1.0, 0.82, 2.0, 1.25, 3.0, 1.65, 4.5, 2.2, 6.5, 2.9, 9.0, 3.7]
## Furthest a planted foot may sweep under it, m.
const REACH := 1.1
## The pounce: the wind-up, the leap and the landing (seconds), and how long a pin is held.
const WIND_UP := 0.6
const LEAP_TIME := 0.42
const LAND_TIME := 0.55
const PIN_TIME := 1.8
## Calls, seconds.
const HOOT_TIME := 1.1
const CLICK_TIME := 0.42
const HISS_TIME := 0.75
## How a swing of the tail is shared out down it (it is stiff: most at its root), and the flick of the wind-up.
const TAIL_SHARE: Array[float] = [0.55, 0.25, 0.12, 0.08]
const TAIL_WHIP: Array[float] = [0.0, 0.08, 0.2, 0.3]
## How far the jaw drops, wide open, radians.
const GAPE := 0.75

enum Pounce { NONE, CROUCH, LEAP, LAND }

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## Layers of feather tips stood off its outline (none on the low-poly model).
var plume_shells := 2
var tint := Color.WHITE
var eyeshine := 0.4
## The materials, by name (see DeinonychusLook.dress).
var materials := {}

var _dino: Deinonychus
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _neck: Node3D
var _neck_1: Node3D
var _neck_2: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Array[Node3D] = []
var _legs: Array[Array] = []
var _sickles: Array[Node3D] = []
var _arms: Array[Array] = []
var _elbow_axis: Array[Vector3] = []
var _wrist_axis: Array[Vector3] = []

var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _balls: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
var _foot_height := 0.04
var _size := 1.0
## Where the tip of the snout and each sickle claw are, in the head's and the foot's space.
var _snout_tip := Vector3(0.0, -0.05, 0.40)
var _claw_tip := Vector3(0.0, 0.12, 0.13)

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _speed_was := 0.0
var _air := 0.0
var _drop := 0.0
var _bounce := 0.0
var _bounce_velocity := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _down: Array[bool] = [true, true]
var _crouch := 0.0
var _tired := 0.0
var _brake := 0.0
var _alert := 0.0
var _breath := 0.0
var _mouth := 0.0
var _swell := 0.0
var _tail_swing := 0.0
var _tail_swing_velocity := 0.0
var _tail_lift := 0.0
## The head: where it is turned now (yaw, pitch, roll), and where it is snapping to.
var _look := Vector3.ZERO
var _look_to := Vector3.ZERO
var _look_in := 0.0
## Seconds since each act began (large: not doing it).
var _hooted := 9.0
var _clicked := 9.0
var _hissed := 9.0
var _pounced := 99.0
var _pinned := 99.0
var _missed := 99.0
var _hoot_pitch := 1.0


func _ready() -> void:
	_dino = get_parent() as Deinonychus
	_build()
	_time = randf() * 10.0
	_phase = randf()
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_bounce = 0.0
	_bounce_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0
	_speed_was = 0.0
	_brake = 0.0
	_tail_swing = 0.0
	_tail_swing_velocity = 0.0


func hoot(pitch := 1.0) -> void:
	_hooted = 0.0
	_hoot_pitch = pitch


func click() -> void:
	_clicked = 0.0


func hiss() -> void:
	_hissed = 0.0


## Starts a pounce: the wind-up, then the leap (the game moves it), then it lands.
func pounce() -> void:
	_pounced = 0.0
	_pinned = 99.0
	_missed = 99.0


## Where in a pounce it is.
func pounce_stage() -> Pounce:
	if _pounced < WIND_UP:
		return Pounce.CROUCH
	if _pounced < WIND_UP + LEAP_TIME:
		return Pounce.LEAP
	if _pounced < WIND_UP + LEAP_TIME + LAND_TIME:
		return Pounce.LAND
	return Pounce.NONE


## On top of what it caught, wings beating: held for PIN_TIME.
func pin() -> void:
	_pinned = 0.0
	_pounced = 99.0


func pinning() -> bool:
	return _pinned < PIN_TIME


## It has missed: a stumbling landing.
func stumble() -> void:
	_missed = 0.0
	_pounced = 99.0


func stumbling() -> bool:
	return _missed < LAND_TIME + 0.3


## Where the tip of its snout is, in the world.
func snout_tip() -> Vector3:
	return _head.global_transform * _snout_tip if _head else global_position


## Where the point of a sickle claw is, in the world (`side` 0 its left, 1 its right).
func claw_tip(side: int) -> Vector3:
	if _sickles.size() <= side:
		return global_position
	var claw := _sickles[side]
	return claw.global_transform * _claw_tip


## The head joint, for anything that should go with it.
func head() -> Node3D:
	return _head


func _process(delta: float) -> void:
	if _dino == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	# (it works in the model's own size)
	var velocity := _dino.velocity / maxf(global_basis.get_scale().x, 0.01)
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _dino.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 10.0, delta)
	_last_yaw = yaw
	_air = _approach(_air, 0.0 if grounded else 1.0, 16.0, delta)

	# --- Moods and acts ---
	_hooted += delta
	_clicked += delta
	_hissed += delta
	_pounced += delta
	_pinned += delta
	_missed += delta
	var stage := pounce_stage()
	var winding := 1.0 if stage == Pounce.CROUCH else 0.0
	var leaping := 1.0 if stage == Pounce.LEAP else 0.0
	var landing := 1.0 if stage == Pounce.LAND else 0.0
	var pinned := 1.0 if pinning() else 0.0
	var stumbled := 1.0 if stumbling() else 0.0
	_crouch = _approach(_crouch, maxf(1.0 if _dino.crouching else 0.0, maxf(winding * 1.25, landing * 0.7)), 7.0 if winding > 0.0 else 4.0, delta)
	_tired = _approach(_tired, 1.0 if _dino.tired else 0.0, 3.0, delta)
	_alert = _approach(_alert, 1.0 if _dino.look_at_point.is_finite() else 0.0, 5.0, delta)
	var slowing := (_speed_was - speed) / delta
	_speed_was = speed
	var braking := slowing > 3.0 and speed > 0.8 and grounded
	_brake = _approach(_brake, 1.0 if braking else 0.0, 14.0 if braking else 4.0, delta)
	if grounded and not _was_grounded:
		_bounce_velocity -= clampf(-velocity.y * 0.25 + 0.6, 0.6, 2.5)
	_was_grounded = grounded
	_bounce_velocity += (-_bounce * 260.0 - _bounce_velocity * 20.0) * delta
	_bounce = clampf(_bounce + _bounce_velocity * delta, -0.12, 0.05)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.2), 7.0, delta)
	var run := smoothstep(RUN_AT.x, RUN_AT.y, _pace)
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta * (1.0 - 0.6 * _brake), 1.0)
	var gait := smoothstep(0.05, 0.35, _pace) * (1.0 - _air) * (1.0 - _brake * 0.7) * (1.0 - pinned)
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var duty := lerpf(DUTY.x, DUTY.y, run)
	var lift := lerpf(0.09, 0.26, run) * _size
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var loads: Array[float] = [0.0, 0.0]
	for i in 2:
		var at := fposmod(_phase - 0.5 * i, 1.0)
		var span := minf(duty * stride, REACH * _size) * travel
		var cycle := _foot_cycle(at, duty, span * 0.5, lift)
		var rest := _balls[i]
		# (running, it puts its feet down near the middle line, one before the other)
		var target := Vector3(rest.x * lerpf(1.0, 0.55, run * gait), _foot_height + cycle.y * gait, rest.z + (0.04 * run + cycle.z) * gait)
		# Braking: the feet out ahead, the weight back over them.
		target.z += 0.22 * _size * _brake
		targets.append(target)
		pitches.append(cycle.x * gait)
		var down := at < duty
		if down:
			loads[i] = sin(PI * at / duty)
		if down and not _down[i] and gait > 0.5 and _pace > 0.4:
			footfall.emit(global_transform * target, clampf((_pace - 0.5) / 5.0, 0.1, 1.0))
		_down[i] = down
	# The body: vaulting over the planted leg at a walk, sinking onto it and
	# springing off it at a run, swaying over the planted foot.
	var load := loads[0] + loads[1]
	var vault := 0.022 * (1.0 - run)
	var spring := 0.045 * run
	var flight := (1.0 - clampf(load, 0.0, 1.0)) * run
	var rise := ((load - 0.75) * vault - load * spring + flight * 0.025) * gait
	var sway := (loads[0] - loads[1]) * 0.028 * (1.0 - run * 0.8) * gait
	var body_at := _body_rest + Vector3(sway * _size, rise * _size - 0.035 * run * _size + _bounce * _size, 0.0)
	var lean := 0.11 * run * gait
	var bank := clampf(-_turn * speed * 0.03, -0.3, 0.3)
	var body_turn := Vector3(lean - 0.18 * _brake, sin(TAU * _phase) * 0.07 * gait * (1.0 - run * 0.5), bank + (loads[1] - loads[0]) * 0.035 * gait)
	var chest_turn := Vector3(0.0, -body_turn.y * 0.6, -body_turn.z * 0.3)
	# Crouching: down on its legs, long and low.
	body_at.y -= 0.24 * _size * _crouch
	body_at.z -= 0.04 * _size * _crouch
	body_turn.x += 0.10 * _crouch - 0.06 * winding * sin(PI * clampf(_pounced / WIND_UP, 0.0, 1.0))
	# The leap: stretched out, nose up a little as it goes, then level.
	if leaping > 0.0:
		var u := (_pounced - WIND_UP) / LEAP_TIME
		body_turn.x += lerpf(-0.22, 0.12, u)
	# The pin: down on what it has, leaning over it.
	body_at.y -= 0.16 * _size * pinned
	body_turn.x += 0.28 * pinned
	# A stumble: pitched forward, a wobble.
	if stumbled > 0.0:
		var u := clampf(_missed / (LAND_TIME + 0.3), 0.0, 1.0)
		var jolt := sin(PI * minf(u * 2.5, 1.0)) * (1.0 - u)
		body_turn.x += 0.3 * jolt
		body_turn.z += sin(_missed * 18.0) * 0.08 * (1.0 - u)
		body_at.y -= 0.1 * _size * jolt
	# Tired: the chest heaving with its panting.
	var panting := _tired
	_breath += delta * TAU * lerpf(0.4, 3.2, panting)
	var heave := sin(_breath) * lerpf(0.01, 0.035, panting)
	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_chest.scale = Vector3(1.0 + heave, 1.0 + heave * 0.7, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale

	_pose_tail(delta, run, gait, winding, leaping + pinned)
	_pose_head(delta, run, gait, stride, body_turn.x + chest_turn.x, winding, leaping, pinned)
	_pose_jaw(delta, winding, pinned)
	_pose_legs(targets, pitches, leaping, landing, pinned, velocity.y)
	_pose_arms(delta, run, gait, leaping, pinned, winding, stumbled)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


## The tail: stiff, held straight out behind for balance. It swings out
## against a turn (with a little lag), counters the swing of the hips, comes
## up braking, leaping and pinning; in the wind-up its end flicks quickly
## from side to side.
func _pose_tail(delta: float, run: float, gait: float, winding: float, balancing: float) -> void:
	var swing_to := clampf(_turn * 0.10, -0.5, 0.5) - _body.rotation.y * 0.8
	_tail_swing_velocity += ((swing_to - _tail_swing) * 140.0 - _tail_swing_velocity * 14.0) * delta
	_tail_swing += _tail_swing_velocity * delta
	_tail_lift = _approach(_tail_lift, 0.03 * run + 0.22 * _brake + 0.16 * balancing - 0.05 * (1.0 - gait) * (1.0 - _alert) + 0.04 * _crouch, 6.0, delta)
	var flick := sin(_time * TAU * 7.5) * winding
	for k in _tail.size():
		var share: float = TAIL_SHARE[k]
		var whip: float = flick * TAIL_WHIP[k]
		var body_pitch := _body.rotation.x
		_tail[k].rotation = Vector3((-_tail_lift - body_pitch * 0.6) * share * (1.0 if k == 0 else 0.5) + 0.01 * sin(_time * 1.3 + k), _tail_swing * share + whip, 0.0)


## Head and neck: the neck an S, the head held level whatever the body does;
## walking it bobs (held still, then thrust forward); it snaps from pose to
## pose, cocks its head at what it watches, drops it low in the wind-up and
## the pin, lifts it to hoot.
func _pose_head(delta: float, run: float, gait: float, stride: float, upstream: float, winding: float, leaping: float, pinned: float) -> void:
	_snap_look(delta, run)
	# The bob: two a stride; held still (the body walking on under it), then thrust.
	var walking := gait * (1.0 - run)
	var beat := fposmod(_phase * 2.0, 1.0)
	var bob := lerpf(1.0, -1.0, beat / 0.72) if beat < 0.72 else lerpf(-1.0, 1.0, smoothstep(0.72, 1.0, beat))
	bob *= minf(0.045, stride * 0.12) * walking / maxf(_size, 0.01)
	# (as an angle at the root of the neck and its middle: back is up and in)
	var reach := bob / 0.3
	var low := 0.35 * _crouch + 0.25 * winding + 0.45 * pinned - 0.1 * leaping
	var hooting := 0.0
	if _hooted < HOOT_TIME:
		hooting = sin(PI * clampf(_hooted / HOOT_TIME, 0.0, 1.0))
	var hissing := 0.0
	if _hissed < HISS_TIME:
		hissing = sin(PI * clampf(_hissed / HISS_TIME, 0.0, 1.0))
	# (running, the neck reaches forward, low; tired, it hangs)
	var forward := 0.12 * run * gait + 0.12 * _tired
	var neck_x := -upstream * 0.5 + reach * 0.6 + low * 0.55 + forward - hooting * 0.18 + hissing * 0.2
	var mid_x := reach * 0.5 - low * 0.25 + forward * 0.5 - hooting * 0.12
	var top_x := -reach * 0.3 - low * 0.35 - forward * 0.3 - hooting * 0.05 - hissing * 0.2
	_neck.rotation = Vector3(neck_x, _look.x * 0.25, 0.0)
	_neck_1.rotation = Vector3(mid_x, _look.x * 0.3, 0.0)
	_neck_2.rotation = Vector3(top_x, _look.x * 0.25, 0.0)
	# (the head itself: level in the world, whatever the neck and the body do, and turned to look)
	var pitch := _look.y * (1.0 - pinned) + 0.5 * pinned + 0.15 * winding - 0.25 * hooting
	var carried := upstream + neck_x + mid_x + top_x
	_head.rotation = Vector3(pitch - carried, _look.x * 0.2, _look.z)
	# The throat swells with a hoot.
	_swell = _approach(_swell, hooting, 10.0, delta)
	_neck_2.scale = Vector3(1.0 + 0.25 * _swell, 1.0 + 0.15 * _swell, 1.0)
	_head.scale = Vector3.ONE / _neck_2.scale


## Where the head is turned: it snaps from pose to pose. Watching something it
## turns to it (and now and then cocks its head, to look with one eye), and
## holds it there, adjusting in small snaps; at ease it looks about.
func _snap_look(delta: float, run: float) -> void:
	_look_in -= delta
	var point := _dino.look_at_point
	if _look_in <= 0.0:
		if point.is_finite() and _head:
			var to := point - _head.global_position
			var yaw_to := clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.3, 1.3)
			var pitch_to := clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.7)
			var cock := 0.0
			if (_dino.cocking or randf() < 0.25) and run < 0.3:
				cock = randf_range(0.3, 0.5) * (1.0 if randf() < 0.5 else -1.0)
			_look_to = Vector3(yaw_to + randf_range(-0.05, 0.05), pitch_to + randf_range(-0.04, 0.04), cock)
			_look_in = randf_range(0.25, 0.7) if run < 0.5 else 0.15
		elif run > 0.5:
			_look_to = Vector3(randf_range(-0.08, 0.08), 0.02, 0.0)
			_look_in = randf_range(0.3, 0.8)
		else:
			var cock := randf_range(0.25, 0.45) * (1.0 if randf() < 0.5 else -1.0) if (_dino.cocking or randf() < 0.3) else 0.0
			_look_to = Vector3(randf_range(-0.9, 0.9), randf_range(-0.25, 0.2), cock)
			_look_in = randf_range(0.5, 1.8)
	# (a snap: fast to the new pose, then held)
	_look = _look.lerp(_look_to, 1.0 - exp(-22.0 * delta))


## The jaw: shut for a hoot, clacked for clicks, wide for a hiss and in the
## wind-up and pin, hanging open panting.
func _pose_jaw(delta: float, winding: float, pinned: float) -> void:
	var open := 0.0
	if _clicked < CLICK_TIME:
		open = maxf(0.0, sin(_clicked * TAU * 7.0)) * 0.3
	if _hissed < HISS_TIME:
		var u := _hissed / HISS_TIME
		open = maxf(open, smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u)) * 0.8)
	open = maxf(open, winding * 0.45)
	open = maxf(open, pinned * (0.55 + 0.25 * sin(_time * 9.0)))
	open = maxf(open, _tired * (0.28 + 0.06 * sin(_breath * 2.0)))
	if _hooted < HOOT_TIME:
		open *= 0.1
	_mouth = _approach(_mouth, open, 30.0, delta)
	_jaw.rotation.x = _mouth * GAPE


func _pose_legs(targets: Array[Vector3], pitches: Array[float], leaping: float, landing: float, pinned: float, vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	for i in 2:
		var rest := _balls[i]
		var target := targets[i]
		# In the air: the legs drawn up (or, leaping, swung forward, the claws out ahead).
		var tucked := rest + Vector3(0.0, 0.2, 0.1) * _size
		var thrust := rest + Vector3(0.0, 0.32, 0.42) * _size
		var air_pose := tucked.lerp(thrust, leaping)
		if vertical_speed < -1.0 and leaping == 0.0:
			air_pose = rest + Vector3(0.0, 0.08, 0.12) * _size
		target = target.lerp(air_pose, maxf(_air, leaping))
		# Pinning: both feet forward, on what it has, driving down.
		var on_it := rest + Vector3(0.0, 0.12 + 0.03 * sin(_time * 9.0 + i * 2.0), 0.38) * _size
		target = target.lerp(on_it, pinned)
		var hip := _hips[i]
		var foot := to_body * target
		var toe_pitch := lerpf(pitches[i], -0.3, leaping) + 0.4 * pinned
		_solve_leg(i, hip, foot, to_body.basis * Basis(Vector3.RIGHT, toe_pitch))
		# The sickle claw: held up off the ground; struck forward and down leaping and pinning.
		var strike := maxf(leaping, pinned * (0.8 + 0.2 * sin(_time * 9.0 + i)))
		_sickles[i].rotation = Vector3(lerpf(-0.12, 1.15, strike) - toe_pitch * 0.5, 0.0, 0.0)


func _foot_cycle(phase: float, duty: float, half_step: float, lift: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.7, 1.0, planted) * -0.45, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	# (toes curled as it comes off the ground, opening out ahead as it comes down)
	return Vector3(lerpf(0.9, -0.15, smoothstep(0.0, 0.85, swing)), sin(PI * pow(swing, 0.8)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (as the dogs' and the boar's
## hind legs: the knee forward, the ankle back, the long foot forward to the ball).
func _solve_leg(index: int, hip: Vector3, target: Vector3, foot_basis: Basis) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.08, total - 0.004)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := AHEAD - line * AHEAD.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var ball := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		bend += (span - reach) / span * 1.2
	var last := line * cos(bend) + aside * sin(bend)
	var far := lengths.x + lengths.y - 0.003
	var near := absf(lengths.x - lengths.y) + 0.01
	var second := ball - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = ball - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	ball = second + last * lengths.z
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
	(bones[3] as Node3D).transform = Transform3D(foot_basis, ball)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## The wings: folded against its sides, held a little out running (for
## balance) and flared on the outside of a hard turn; thrown open leaping;
## spread and beating on what it has pinned; half open in the wind-up.
func _pose_arms(delta: float, run: float, gait: float, leaping: float, pinned: float, winding: float, stumbled: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var outside := clampf(-_turn * side * 0.15, 0.0, 1.0) * run
		var open := clampf(0.12 * run * gait + 0.5 * outside + 0.3 * winding + 1.0 * leaping + 0.9 * pinned + 0.6 * stumbled, 0.0, 1.0)
		var beat := 0.0
		if pinned > 0.0:
			beat = sin(_time * TAU * 3.2 + i * 0.3) * 0.5 * pinned
		elif stumbled > 0.0:
			beat = sin(_time * TAU * 4.0) * 0.3 * stumbled
		var swing := sin(TAU * _phase + i * PI) * 0.08 * run * gait
		var bones: Array = _arms[i]
		(bones[0] as Node3D).basis = Basis(Vector3.BACK, side * (open * 1.0 + beat)) * Basis(Vector3.RIGHT, swing - open * 0.35)
		(bones[1] as Node3D).basis = Basis(_elbow_axis[i], open * 1.2 + beat * 0.2)
		(bones[2] as Node3D).basis = Basis(_wrist_axis[i], open * 1.4 + beat * 0.3)


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
	var path := "res://creatures/deinonychus/models/deinonychus%s.glb" % ("_lo" if low_poly else "")
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	materials = DeinonychusLook.dress(model, tint, 0 if low_poly else plume_shells, eyeshine)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_neck_2 = _joint(_neck_1, &"neck_2")
	_head = _joint(_neck_2, &"head")
	_jaw = _joint(_head, &"jaw")
	var from := _body
	for bone: String in ["tail", "tail_1", "tail_2", "tail_3"]:
		var link := _joint(from, bone)
		_tail.append(link)
		from = link
	for i in 2:
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["thigh", "shin", "shank", "foot"]:
			at.append(_body_rest + _rest(bone + SIDES[i]))
			bones.append(_joint(_body, bone + SIDES[i]))
		_legs.append(bones)
		_sickles.append(_joint(bones[3], "sickle" + SIDES[i]))
		_hips.append(at[0] - _body_rest)
		_balls.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		var line := (at[3] - at[0]).normalized()
		var aside := (AHEAD - line * AHEAD.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
		var arm := _joint(_chest, "arm" + SIDES[i])
		var forearm := _joint(arm, "forearm" + SIDES[i])
		var hand := _joint(forearm, "hand" + SIDES[i])
		_arms.append([arm, forearm, hand])
		# (the elbow and the wrist open about the line square to the two bones either side of them)
		var upper := forearm.position.normalized()
		var lower := hand.position.normalized()
		var fingers := _skeleton.get_bone_rest(_skeleton.find_bone("hand_end" + SIDES[i])).origin.normalized()
		_elbow_axis.append(lower.cross(upper).normalized())
		_wrist_axis.append(fingers.cross(lower).normalized())
	_foot_height = _balls[0].y
	_size = _body_rest.y / 0.86


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
