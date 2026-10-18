class_name Moose
extends Elk
## A moose: a bull or a cow (`cow`), or a calf (`calf`). The biggest deer
## there is, all legs: taller at the shoulder than a man, a short deep body on
## long pale-stockinged legs, a high hump over the shoulders with a crest of
## coarse hair along it, a short thick neck and a long heavy head hung low, its
## broad muzzle overhanging the lower lip, the bell (a flap of hide and hair)
## swinging under its throat, and on a bull the great palmate antlers. Nearly
## black. It knows nothing of the game it is in.
##
## It is an Elk (creatures/elk), and so a Deer (creatures/deer), on the same
## rig: move it and it walks or breaks into its long, ungainly, fast trot to
## match (it gallops only flat out); `look_at_point`, `grazing`, `alert`,
## `stamp()`, `snort()`, `pawing`, `lowered` (head down, antlers forward: how it
## charges) and the rest work as they do on them. On top of those:
## - `browsing`: head up and out into the branches, the lips working, stripping
##   twigs.
## - `bristling` (the warning): ears pinned flat back, the hackles standing up
##   along its hump and neck, head lowered and stared out from under its brows
##   at `look_at_point`, now and then licking its lips (`lick()`).
## - `strike()`: rears up on its hind legs and brings its forehooves down hard
##   (STRIKE_TIME; `struck` as they land, at `hooves_position()`).
## - `bugle()` is its call: a bull's deep croaking grunt, a cow's long moan.
## - `wading`: how deep it stands in water (m): its legs go down into it (the
##   game gives it water to stand in).
##
## Signals: `struck`, `licked` (and Elk's and Deer's). With `sound` on it makes
## its sounds (made in code: `call_sound()`, `moan_sound()`).

signal struck
signal licked

## Seconds a strike takes, and when in it the forehooves come down.
const STRIKE_TIME := 1.3
const STRIKE_LANDS := 0.88
## Seconds a call takes: a bull's, a cow's.
const CALL_TIME := 1.1
const MOAN_TIME := 2.1
## Seconds a lick of the lips takes.
const LICK_TIME := 0.7

## A calf: a cow's model, red-brown (scale it down: about half). Set before it enters the tree.
@export var calf := false

var browsing := false
var bristling := false
var wading := 0.0

var _bristle := 0.0
var _browse := 0.0
var _lick_left := 0.0
var _lick_in := 0.5
var _strike_left := 0.0
var _landed := true
var _bones := {}
var _skeleton: Skeleton3D
var _bell_tip := Vector3.INF
var _bell_velocity := Vector3.ZERO
var _bell_length := 0.3
var _hackles_rest := Vector3.ZERO
var _tongue_rest := Vector3.ZERO
var _face := Vector3(0.0, -0.76, 0.65)
var _face_up := Vector3(0.0, 0.65, 0.76)
var _time := 0.0
var _hoof_voice: AudioStreamPlayer3D
static var _call: AudioStreamWAV
static var _moan: AudioStreamWAV


func _ready() -> void:
	if calf:
		cow = true
		coat_tint = Color(1.3, 1.05, 0.9) * coat_tint
	super()
	# (its rig poses it first; what is the moose's own is laid on after)
	rig.process_priority = -1
	_skeleton = rig._skeleton
	for bone: String in ["neck", "neck_1", "head", "jaw", "bell", "hackles", "tongue"]:
		_bones[bone] = _skeleton.find_bone(bone)
	if _bones["hackles"] >= 0:
		_hackles_rest = _skeleton.get_bone_rest(_bones["hackles"]).origin
	if _bones["tongue"] >= 0:
		_tongue_rest = _skeleton.get_bone_rest(_bones["tongue"]).origin
	_bell_length = (0.32 if not cow else 0.18) * (0.6 if calf else 1.0)
	# (its coat is long and coarse)
	if rig.materials.has("coat"):
		DeerLook.tune(rig.materials["coat"], {&"fur_length": 0.02, &"droop": 0.5})
	if _bugle_voice:
		_bugle_voice.stream = moan_sound() if cow else call_sound()
		_bugle_voice.unit_size = 10.0
		_bugle_voice.max_distance = 110.0


func model_path() -> String:
	return "res://creatures/moose/models/moose_%s%s.glb" % ["cow" if cow else "bull", "_lo" if low_poly else ""]


func colours() -> Dictionary:
	return {"coat": Color(0.24, 0.17, 0.115), "dark": Color(0.075, 0.055, 0.045), "pale": Color(0.44, 0.41, 0.36)}


## Its call: for `seconds` (a bull's grunt, a cow's moan, if not said).
func bugle(seconds := -1.0) -> void:
	if seconds <= 0.0:
		seconds = MOAN_TIME if cow else CALL_TIME
	super(seconds)
	if _bugle_voice and _bugle_voice.playing:
		_bugle_voice.pitch_scale = randf_range(0.95, 1.05) / (1.25 if calf else 1.0)


## Licks its lips: the tongue out over the muzzle and back.
func lick() -> void:
	_lick_left = LICK_TIME
	licked.emit()


## Rears up and brings its forehooves down hard.
func strike() -> void:
	_strike_left = STRIKE_TIME
	_landed = false


func striking() -> bool:
	return _strike_left > 0.0


## How far through a strike it is, 0..1 (0 when it is not).
func strike_progress() -> float:
	return 1.0 - _strike_left / STRIKE_TIME if _strike_left > 0.0 else 0.0


## Where its forehooves come down, in the world (in front of its chest).
func hooves_position() -> Vector3:
	return global_position + global_basis.z.normalized() * 0.95 * scale.x


func busy() -> bool:
	return super() or striking()


func _process(delta: float) -> void:
	super(delta)
	if delta <= 0.0 or _skeleton == null:
		return
	_time += delta
	_bristle = DeerRig._approach(_bristle, 1.0 if bristling else 0.0, 4.0 if bristling else 1.5, delta)
	_browse = DeerRig._approach(_browse, 1.0 if browsing and not bristling else 0.0, 2.5, delta)
	# Angry: the ears flat back (the rig lays them back for one in flight).
	fleeing = _bristle > 0.35 or lowered
	if not bristling:
		# (soon after it begins to bristle, the first lick)
		_lick_in = randf_range(0.35, 0.8)
	else:
		_lick_in -= delta
		if _lick_in <= 0.0:
			_lick_in = randf_range(1.6, 3.2)
			lick()
	if _lick_left > 0.0:
		_lick_left -= delta
	# The strike: up on its hind legs, held a moment, then the forehooves
	# driven down (faster than the rig would let it fall: it is led by hand).
	if _strike_left > 0.0:
		_strike_left -= delta
		var u := strike_progress()
		var up := smoothstep(0.0, 0.45, u) * 0.62 * (1.0 - smoothstep(0.58, STRIKE_LANDS / STRIKE_TIME, u))
		upright = up > 0.2
		rig._upright = up
		if not _landed and u >= STRIKE_LANDS / STRIKE_TIME:
			_landed = true
			upright = false
			stamp()
			struck.emit()
	elif upright and _landed:
		upright = false
	if wading > 0.0:
		rig.position.y -= wading
	_pose()


## What the rig does not: the head lowered and staring, or up browsing; the
## hackles; the tongue; the bell swinging.
func _pose() -> void:
	var neck := 0.0
	var head := 0.0
	# Bristling: the neck down, the head kept up to stare out from under the brows.
	neck += 0.30 * _bristle * (1.0 - float(lowered))
	head -= 0.42 * _bristle * (1.0 - float(lowered))
	# Browsing: neck up, nose up and out into the branches, tugging.
	var tug := sin(_time * 2.4) * 0.06 + sin(_time * 5.3) * 0.03
	neck -= (0.45 + tug) * _browse
	head -= (0.5 - tug) * _browse
	_turn_bone("neck", neck * 0.5)
	_turn_bone("neck_1", neck * 0.5)
	_turn_bone("head", head)
	# The jaw: working at the twigs browsing; open a little to lick.
	var lick_u := 1.0 - _lick_left / LICK_TIME if _lick_left > 0.0 else 0.0
	var licking := sin(PI * lick_u)
	_turn_bone("jaw", 0.12 * _browse * (0.5 + 0.5 * sin(_time * 7.0)) + 0.22 * licking)
	if _bones["tongue"] >= 0:
		# (out past the lower lip, and up over the muzzle)
		var out := _face * 0.2 * licking + _face_up * 0.1 * licking * smoothstep(0.25, 0.6, lick_u)
		_skeleton.set_bone_pose_position(_bones["tongue"], _tongue_rest + out)
	if _bones["hackles"] >= 0:
		var stand := 0.085 * _bristle + 0.01 * sin(_time * 1.3) * _bristle
		_skeleton.set_bone_pose_position(_bones["hackles"], _hackles_rest + Vector3(0.0, stand, 0.03 * _bristle))
	_swing_bell()


func _turn_bone(bone: String, angle: float) -> void:
	var index: int = _bones[bone]
	if index < 0 or absf(angle) < 0.0005:
		return
	var pose := _skeleton.get_bone_pose_rotation(index)
	_skeleton.set_bone_pose_rotation(index, pose * Quaternion(Vector3.RIGHT, angle))


## The bell: a weight on a string from its throat, swinging as the head moves, hanging down.
func _swing_bell() -> void:
	var index: int = _bones["bell"]
	if index < 0:
		return
	var parent := _skeleton.get_bone_parent(index)
	var held := _skeleton.global_transform * _skeleton.get_bone_global_pose(parent) * _skeleton.get_bone_rest(index)
	var root := held.origin
	var length := _bell_length * scale.x
	var delta := get_process_delta_time()
	if not _bell_tip.is_finite() or _bell_tip.distance_to(root) > length * 4.0:
		_bell_tip = root + Vector3.DOWN * length
		_bell_velocity = Vector3.ZERO
	var target := root + Vector3.DOWN * length
	_bell_velocity += ((target - _bell_tip) * 60.0 - _bell_velocity * 4.0) * delta
	_bell_tip += _bell_velocity * delta
	var way := (_bell_tip - root).normalized()
	_bell_tip = root + way * length
	var local := (held.basis.orthonormalized().inverse() * way).normalized()
	_skeleton.set_bone_pose_rotation(index, Quaternion(Vector3.DOWN, local))


## A bull's call: a deep, hollow, croaking grunt that breaks upward at its end
## ("uh-WAH"), a cough of breath behind it. Made once and shared.
static func call_sound() -> AudioStreamWAV:
	if _call:
		return _call
	var rate := 22050
	var count := int(rate * CALL_TIME)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var samples := PackedFloat32Array()
	samples.resize(count)
	var mouth := Band.new(380.0, 3.0, rate)
	var chest := Band.new(160.0, 1.5, rate)
	var air := Band.new(900.0, 1.2, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / CALL_TIME
		# (a low croak, rising into the "wah" as the mouth opens)
		var pitch := 72.0 + 30.0 * smoothstep(0.35, 0.6, u) - 25.0 * smoothstep(0.7, 1.0, u)
		phase += pitch * (1.0 + 0.04 * rng.randf_range(-1.0, 1.0)) / rate
		var pulse := pow(1.0 - fposmod(phase, 1.0), 5.0) * 2.0 - 0.3
		mouth.set_frequency(lerpf(330.0, 720.0, smoothstep(0.3, 0.6, u)), 3.0)
		var voice := mouth.run(pulse) * 1.8 + chest.run(pulse) * 0.9
		var shape := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.75, 1.0, u)) * (0.7 + 0.3 * smoothstep(0.3, 0.55, u))
		var breath := air.run(rng.randf_range(-1.0, 1.0)) * 0.35 * smoothstep(0.55, 0.7, u) * (1.0 - smoothstep(0.85, 1.0, u))
		var value := tanh((voice * shape + breath) * 1.4)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_call = _wav(samples, loudest, rate)
	return _call


## A cow's call: a long nasal moan, wavering, rising and falling away. Made once and shared.
static func moan_sound() -> AudioStreamWAV:
	if _moan:
		return _moan
	var rate := 22050
	var count := int(rate * MOAN_TIME)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var samples := PackedFloat32Array()
	samples.resize(count)
	var nose := Band.new(1100.0, 4.0, rate)
	var throat := Band.new(450.0, 2.0, rate)
	var phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / MOAN_TIME
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.04, -1.0, 1.0)
		var pitch := 210.0 + 120.0 * sin(PI * clampf(u * 1.2, 0.0, 1.0)) - 60.0 * smoothstep(0.75, 1.0, u)
		pitch *= 1.0 + 0.015 * sin(TAU * 5.0 * t) + 0.02 * wander
		phase += pitch / rate
		var pulse := pow(1.0 - fposmod(phase, 1.0), 3.0) * 2.0 - 0.5
		var value := nose.run(pulse) * 1.2 + throat.run(pulse) * 1.0
		value *= smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.8, 1.0, u))
		value = tanh(value * 1.5)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_moan = _wav(samples, loudest, rate)
	return _moan
