class_name SpiderMonkey
extends Node3D
## A spider monkey: how it looks and how it moves, and nothing of what it
## thinks. Whatever drives it (a game's enemy script, a cutscene, the example)
## moves this node about and calls on it; it poses itself from that.
##
## WHAT IT IS. A real spider monkey (Geoffroy's, the black-handed): long thin
## arms (longer than its legs) and legs, a narrow chest over a round pot belly,
## a small round head on a short neck, hook hands of four long fingers and no
## thumb, hand-like feet with a gripping great toe, and a prehensile tail half
## as long again as its head and body, furred but for the bare, ridged grip pad
## under its last part. Its coat is dark, shaggy and long on the back, flanks
## and limbs; its face bare and dark, with pale bare skin round the eyes and
## the muzzle, so that in the mist it is a dark shape with a pale mask. One
## skinned mesh (models/spider_monkey.glb, built in Blender by
## tools/build_spider_monkey.py) on a skeleton posed here, so each is one draw.
##
## HOW IT MOVES. Move the node and turn it; it works out its own speed from how
## it is moved, in its own floor (the node's XZ plane), and its hands and feet
## keep to what it is on. Its origin is always where its feet would be:
## - on the ground it walks on all fours in a diagonal sequence, its tail up in
##   an arch with the tip curled, and fast it bounds;
## - `clinging`: on a wall or a vine up one, climbing (turn the node so that its
##   Y is the wall's normal and its Z the way up it), hand over hand;
## - `hanging`: from a line (a vine, a branch) `HANG_HIGH` above its origin,
##   running along `hold_axis` (world). Still, it hangs by its tail wrapped round
##   the line and one hand, head up, legs and the other arm dangling (or, with
##   `hang_style` TAIL, by the tail alone, upside down, arms dangling), swaying,
##   looking about. Moved along the line, it swings along it hand over hand,
##   its tail a third hand;
## - `airborne`: flung through the air (move it yourself, on whatever arc),
##   arms and legs reaching ahead for what it means to land on, tail up behind.
## It leans into turns, breathes, and its tail is never still. `look_at_point`
## (world, INF for none) is what it turns its head to; left alone it looks
## about.
##
## WHAT IT DOES, each on a call, blending in and out by itself:
## - `chitter()`: a quick chatter, lips pursed, the head bobbing.
## - `shriek()`: a screaming bark, mouth wide, head thrust out.
## - `rustle(seconds)`: shakes what it hangs from (or bounces on all fours),
##   the warning before it drops.
## - `wind_up(seconds)`: hanging, it lets go with its hand, draws itself up and
##   swings back on its tail, ready to fling itself off.
## - `display(seconds)`: the threat on the ground: up on its hind legs, arms
##   raised over its head and shaking, mouth open, bouncing.
## `reaches(point, radius)` says whether its hands or feet are on a point now
## (only while it is `airborne`), for whatever decides a grab.
##
## SOUNDS (`voice`): a whinny, a shriek and a chitter, made in code, through its
## own AudioStreamPlayer3D. Only when called; `voice` off for none.
##
## Set `size` (1: an adult, about 0.45 m head and body), `seed_value` (its own
## small differences) and `hang_style` before it goes into the tree. `settle()`
## puts it straight into its pose where it is, for when it is put somewhere.

enum Hang { HAND, TAIL }

## How high its hold is above its origin while it hangs (metres at size 1).
const HANG_HIGH := 1.0
const CHITTER_TIME := 0.6
const SHRIEK_TIME := 0.75
## Ground speed (its own sizes a second) it starts to bound from.
const BOUND_FROM := 2.2

## Colours, as the model is built (tools/build_spider_monkey.py) and the shader takes them.
const COAT := Color(0.085, 0.072, 0.06)
const MASK := Color(0.62, 0.55, 0.5)

## Limb lengths (metres at size 1): upper arm, forearm; thigh, shin.
const ARM := Vector2(0.245, 0.25)
const LEG := Vector2(0.2, 0.205)
## How long the hand is from the wrist (palm and fingers), and the foot from the ankle.
const HAND_LONG := 0.13
const FOOT_LONG := 0.12
## The tail: its joints, from the root out (it tapers; the last two are its grip).
const TAIL_STEPS: Array[float] = [0.11, 0.11, 0.105, 0.1, 0.095, 0.09, 0.085, 0.075, 0.06, 0.05]
const TAIL_COUNT := 10
## What it hangs from: how thick (the tail wraps round it at this radius).
const HOLD_RADIUS := 0.045

## Its stances (metres at size 1): pelvis and chest, and where each wrist and
## ankle is: left hand, right hand, left foot, right foot. +X is its left, +Z ahead.
const FOURS := {"pelvis": Vector3(0.0, 0.34, -0.14), "chest": Vector3(0.0, 0.47, 0.13),
	"feet": [Vector3(0.085, 0.035, 0.2), Vector3(-0.085, 0.035, 0.2), Vector3(0.075, 0.05, -0.14), Vector3(-0.075, 0.05, -0.14)],
	"poles": [Vector3(0.2, 0.0, -1.0), Vector3(-0.2, 0.0, -1.0), Vector3(0.25, 0.3, 1.0), Vector3(-0.25, 0.3, 1.0)]}
const CLING := {"pelvis": Vector3(0.0, 0.13, -0.15), "chest": Vector3(0.0, 0.16, 0.14),
	"feet": [Vector3(0.17, 0.03, 0.3), Vector3(-0.17, 0.03, 0.3), Vector3(0.15, 0.03, -0.2), Vector3(-0.15, 0.03, -0.2)],
	"poles": [Vector3(1.0, 1.0, -0.3), Vector3(-1.0, 1.0, -0.3), Vector3(1.0, 1.0, 0.4), Vector3(-1.0, 1.0, 0.4)]}
## The gaits: when each foot comes down in the cycle, how much of it each is
## down, how far the body goes in one (metres), how high a foot is lifted.
const WALK := {"offsets": [0.25, 0.75, 0.0, 0.5], "duty": 0.62, "cycle": 0.62, "lift": 0.06}
const BOUND := {"offsets": [0.52, 0.6, 0.02, 0.08], "duty": 0.32, "cycle": 1.3, "lift": 0.12}
## Hand over hand along a line: when each of hand, hand and tail takes hold, how
## long it holds, how far it goes in one cycle.
const SWING := {"offsets": [0.0, 0.5, 0.25], "duty": 0.62, "cycle": 1.1}

## How big it is drawn (1: an adult).
@export var size := 1.0
## Its own small differences (coat, build, how it hangs): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (models/spider_monkey_lo.glb), as `low_poly` does for every one.
@export var force_low := false
## How it hangs still: by its tail and a hand, head up, or by its tail alone, upside down.
@export var hang_style := Hang.HAND
## Its sounds, and how loud and far.
@export var voice := true
@export var volume_db := -3.0
@export var voice_range := 34.0

## Every spider monkey uses the low-poly model (phones).
static var low_poly := false

## What it looks at (world). INF: it looks where it goes, or about it.
var look_at_point := Vector3.INF
## Hanging from a line `HANG_HIGH` above its origin, along `hold_axis`.
var hanging := false
## Which way what it hangs from runs (world).
var hold_axis := Vector3.RIGHT
## Climbing a wall (its node's Y the wall's normal, its Z up the wall).
var clinging := false
## In the air, reaching ahead for where it will land.
var airborne := false

const MODEL := "res://creatures/spider_monkey/models/spider_monkey.glb"
const MODEL_LO := "res://creatures/spider_monkey/models/spider_monkey_lo.glb"

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rest: Array[Transform3D] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
var _frame := Transform3D.IDENTITY
var _voice: AudioStreamPlayer3D

var _t := 0.0
var _was := Vector3.INF
var _forward_was := Vector3.ZERO
var _speed := 0.0
var _turn := 0.0
var _phase := 0.0
var _swing_phase := 0.0
var _travel := 1.0
var _bound := 0.0
var _moving := 0.0
var _cling := 0.0
var _hang := 0.0
var _swinging := 0.0
var _air := 0.0
var _fall := 0.0
var _wind := 0.0
var _wind_left := 0.0
var _display := 0.0
var _display_left := 0.0
var _rustle_left := 0.0
var _rustle := 0.0
var _chitter := INF
var _shriek := INF
var _gaze := Vector3(0.0, -0.1, 1.0)
var _scan := Vector3(0.0, 0.0, 1.0)
var _scan_next := 0.0
var _idle_next := 2.0
var _idle_hand := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _sway_seed := 0.0
var _grabbers := PackedVector3Array()

static var _sounds := {}


func _ready() -> void:
	# (its skeleton as it was modelled, before anything of its own is drawn: tools/rest_joints.gd)
	_rest = _bone_globals(_joints(_standing(), Vector3(0.0, 0.0, 1.0)))
	_rng.seed = seed_value
	_sway_seed = _rng.randf() * TAU
	var low := low_poly or force_low
	_model = (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = SpiderMonkeyLook.material()
	_body.custom_aabb = AABB(Vector3(-1.0, -0.8, -1.0), Vector3(2.0, 2.4, 2.0))
	_body.set_instance_shader_parameter(&"tone", _rng.randf_range(0.85, 1.18))
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 4.0
		_voice.max_distance = voice_range
		_voice.position = Vector3(0.0, 0.6 * size, 0.1 * size)
		add_child(_voice)
	_phase = _rng.randf()
	_swing_phase = _rng.randf()
	settle()


## Puts it straight into its pose as it is now, with nothing going on.
func settle() -> void:
	_was = global_position
	_forward_was = global_basis.z
	_speed = 0.0
	_moving = 0.0
	_cling = 1.0 if clinging else 0.0
	_hang = 1.0 if hanging else 0.0
	_air = 1.0 if airborne else 0.0
	_swinging = 0.0
	_wind = 0.0
	_wind_left = 0.0
	_display = 0.0
	_display_left = 0.0
	_rustle_left = 0.0
	_rustle = 0.0
	_pose(0.0)


func chitter() -> void:
	_chitter = 0.0
	_say(&"chitter")


func shriek() -> void:
	_shriek = 0.0
	_say(&"shriek")


## Shakes what it hangs from, or bounces where it stands, for `seconds`.
func rustle(seconds := 0.8) -> void:
	if _rustle_left <= 0.0:
		_say(&"whinny")
	_rustle_left = maxf(_rustle_left, seconds)


## Hanging, it draws itself up and swings back on its tail, for `seconds`.
func wind_up(seconds := 0.55) -> void:
	_wind_left = maxf(_wind_left, seconds)


func winding() -> bool:
	return _wind_left > 0.0


func display(seconds := 1.6) -> void:
	if _display_left <= 0.0:
		_say(&"shriek")
	_display_left = maxf(_display_left, seconds)


func displaying() -> bool:
	return _display_left > 0.0


## Whether its hands or feet are within `radius` of `point` (world), while it is in the air.
func reaches(point: Vector3, radius: float) -> bool:
	if not airborne:
		return false
	for p in _grabbers:
		if p.distance_to(point) < radius:
			return true
	return false


## Where its hands, feet and head are (world), from the last frame.
func grabbers() -> PackedVector3Array:
	return _grabbers


## Where its head is (world), from the last frame.
func head_position() -> Vector3:
	return _grabbers[4] if _grabbers.size() > 4 else global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	# How it is moving, in its own floor, from how it has been moved.
	var at := global_position
	if not _was.is_finite():
		_was = at
	var basis_now := global_basis.orthonormalized()
	var world_moved := at - _was
	var moved := basis_now.inverse() * world_moved
	moved.y = 0.0
	moved /= size
	_was = at
	var speed := moved.length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))
	_fall = lerpf(_fall, world_moved.y / delta / size, 1.0 - exp(-12.0 * delta))
	if hanging:
		# (along what it hangs from: hand over hand)
		var along := world_moved.dot(hold_axis.normalized()) / size
		_swing_phase = fposmod(_swing_phase + absf(along) / SWING["cycle"], 1.0)
		if absf(along) > 0.0005:
			_travel = signf(along)
	elif not airborne:
		_phase = fposmod(_phase + moved.z / _cycle(), 1.0)
	var forward := basis_now.z
	var up := basis_now.y
	var turned := 0.0
	if _forward_was.length_squared() > 0.5:
		var a := _forward_was - up * _forward_was.dot(up)
		if a.length_squared() > 0.0001:
			turned = a.normalized().signed_angle_to(forward, up)
	_forward_was = forward
	_turn = lerpf(_turn, turned / delta, 1.0 - exp(-6.0 * delta))
	_moving = move_toward(_moving, 1.0 if _speed > 0.12 and not hanging else 0.0, delta * 5.0)
	_swinging = move_toward(_swinging, 1.0 if hanging and _speed > 0.12 else 0.0, delta * 4.0)
	_bound = move_toward(_bound, smoothstep(BOUND_FROM * 0.8, BOUND_FROM * 1.2, _speed) * (1.0 - _cling), delta * 3.0)
	_cling = move_toward(_cling, 1.0 if clinging else 0.0, delta * 5.0)
	_hang = move_toward(_hang, 1.0 if hanging else 0.0, delta * 4.0)
	_air = move_toward(_air, 1.0 if airborne else 0.0, delta * 9.0)
	_wind_left -= delta
	_wind = move_toward(_wind, 1.0 if _wind_left > 0.0 and hanging else 0.0, delta * 5.0)
	_display_left -= delta
	_display = move_toward(_display, 1.0 if _display_left > 0.0 and not hanging and not airborne and not clinging else 0.0, delta * 5.0)
	_rustle_left -= delta
	_rustle = move_toward(_rustle, 1.0 if _rustle_left > 0.0 else 0.0, delta * 6.0)
	_chitter += delta
	_shriek += delta
	_idle_next -= delta
	if _idle_next <= 0.0:
		# (the dangling hand: now scratching its belly, now reaching out, now hanging loose)
		_idle_next = _rng.randf_range(1.5, 4.0)
		_idle_hand = Vector3(_rng.randf_range(-0.08, 0.1), _rng.randf_range(-0.05, 0.2), _rng.randf_range(-0.02, 0.14)) if _rng.randf() < 0.6 else Vector3.ZERO
	_pose(delta)


func _cycle() -> float:
	return lerpf(WALK["cycle"], BOUND["cycle"], _bound)


# --- Posing ---

## One whole pose: pelvis and chest, each wrist and ankle, which way each elbow
## and knee bends, which way the hands and feet point, which way its belly
## faces, the tail (points out from its root), and the rest.
class Pose:
	var pelvis := Vector3.ZERO
	var chest := Vector3.ZERO
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var poles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	## Which way each hand and foot points, and how much it is set that way (0: on from the forearm or shin).
	var ways: Array[Vector3] = [Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD]
	var set_way := [0.0, 0.0, 0.0, 0.0]
	## Which way its belly faces.
	var front := Vector3.DOWN
	var tail := PackedVector3Array()
	var head_up := 0.0
	var head_turn := 0.0
	var jaw := 0.0
	var lips := 0.0
	var fingers := [0.3, 0.3]
	var toes := [0.2, 0.2]

	static func from(stance: Dictionary) -> Pose:
		var p := Pose.new()
		p.pelvis = stance["pelvis"]
		p.chest = stance["chest"]
		for i in 4:
			p.feet[i] = stance["feet"][i]
			p.poles[i] = stance["poles"][i]
		return p

	func blend(other: Pose, w: float) -> Pose:
		if w <= 0.0:
			return self
		if w >= 1.0:
			return other
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		for i in 4:
			p.feet[i] = feet[i].lerp(other.feet[i], w)
			p.poles[i] = poles[i].lerp(other.poles[i], w)
			p.ways[i] = ways[i].lerp(other.ways[i], w)
			p.set_way[i] = lerpf(set_way[i], other.set_way[i], w)
		p.front = front.lerp(other.front, w)
		p.tail = PackedVector3Array()
		for k in mini(tail.size(), other.tail.size()):
			p.tail.append(tail[k].lerp(other.tail[k], w))
		p.head_up = lerpf(head_up, other.head_up, w)
		p.head_turn = lerpf(head_turn, other.head_turn, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		p.lips = lerpf(lips, other.lips, w)
		for i in 2:
			p.fingers[i] = lerpf(fingers[i], other.fingers[i], w)
			p.toes[i] = lerpf(toes[i], other.toes[i], w)
		return p


## Where a foot is in its step: (forward, up) from where it stands.
static func _step(phase: float, offset: float, duty: float, reach: float, lift: float) -> Vector2:
	var s := fposmod(phase - offset, 1.0)
	if s < duty:
		return Vector2(reach * (0.5 - s / duty), 0.0)
	var k := (s - duty) / (1.0 - duty)
	var e := k * k * (3.0 - 2.0 * k)
	return Vector2(reach * (-0.5 + e), lift * sin(PI * k))


## The way its torso is held: across (to its left), along the spine, and out of its belly.
static func _torso(pelvis: Vector3, chest: Vector3, front_hint: Vector3) -> Basis:
	var spine := (chest - pelvis).normalized()
	var front := front_hint - spine * front_hint.dot(spine)
	if front.length() < 0.01:
		front = Vector3.BACK - spine * spine.z
	front = front.normalized()
	var side := spine.cross(front).normalized()
	return Basis(side, spine, front)


## Where its tail grows from, for a pelvis held so.
static func _tail_root(pelvis: Vector3, torso: Basis) -> Vector3:
	return pelvis - torso.z * 0.055 - torso.y * 0.045


## A free tail: up from the root by `rise` (radians from straight back), each
## joint bending on by `bend` (up, + towards its back) and `curl` more at the
## end, swinging `swing` to the side. Points from the root (the first is zero).
func _tail_free(torso: Basis, rise: float, bend: float, curl: float, swing: float) -> PackedVector3Array:
	var back := -torso.y
	var over := -torso.z
	var side := torso.x
	var points := PackedVector3Array([Vector3.ZERO])
	var at := Vector3.ZERO
	var angle := rise
	for k in TAIL_COUNT:
		var lash := sin(_t * 1.7 + _sway_seed - k * 0.55) * 0.05 * (k + 1) / TAIL_COUNT
		var dir := (back * cos(angle) + over * sin(angle) + side * (swing + lash) * (0.3 + k * 0.08)).normalized()
		at += dir * TAIL_STEPS[k]
		points.append(at)
		angle += bend + curl * smoothstep(5.0, 9.0, float(k))
	return points


## A tail holding on: from `root` to round `hold` (both its own space), wrapped
## round what runs along `axis` there, the last two joints its grip (curled
## the way that puts the bare pad under it against the hold, for a body whose
## left is `side`), the rest hanging between in a curve that bows towards `bow`.
static func _tail_grip(root: Vector3, hold: Vector3, axis: Vector3, bow: Vector3, side: Vector3) -> PackedVector3Array:
	axis = axis.normalized()
	var to_root := root - hold
	var u := (to_root - axis * to_root.dot(axis))
	u = u.normalized() if u.length() > 0.001 else Vector3.DOWN
	var v := side.cross(-u)
	v -= axis * v.dot(axis)
	v = v.normalized() if v.length() > 0.05 else axis.cross(u).normalized()
	# (round the hold: in at the side, over the top, down the far side)
	var r := HOLD_RADIUS + 0.012
	var wrap := PackedVector3Array()
	for angle: float in [1.35, 2.85, 4.05]:
		wrap.append(hold + (u * cos(angle) + v * sin(angle)) * r + axis * angle * 0.006)
	var entry := wrap[0]
	var free := 0.0
	for k in TAIL_COUNT - 2:
		free += TAIL_STEPS[k]
	var chord := entry - root
	var c := chord.length()
	var mid := root + chord * 0.5
	var out := bow - chord.normalized() * bow.dot(chord.normalized())
	out = out.normalized() if out.length() > 0.001 else Vector3.BACK
	# (how far the middle of the curve stands off the straight line, for its length)
	var sag := sqrt(maxf(0.0, 3.0 * c * (free - c) / 8.0))
	var control := mid + out * sag * 2.0
	var points := PackedVector3Array([Vector3.ZERO])
	var gone := 0.0
	for k in TAIL_COUNT - 2:
		gone += TAIL_STEPS[k]
		var t := gone / free
		var q := root.lerp(control, t).lerp(control.lerp(entry, t), t)
		points.append(q - root)
	points.append(wrap[1] - root)
	points.append(wrap[2] - root)
	return points


## On all fours (or on a wall with `_cling`), going.
func _fours_pose() -> Pose:
	var p := Pose.from(FOURS).blend(Pose.from(CLING), _cling)
	var b := _bound
	var cycle := lerpf(WALK["cycle"], BOUND["cycle"], b)
	var duty := lerpf(WALK["duty"], BOUND["duty"], b)
	var lift := lerpf(WALK["lift"], BOUND["lift"], b)
	var reach := cycle * duty * lerpf(1.0, 0.8, _cling)
	for i in 4:
		var off := lerpf(WALK["offsets"][i], BOUND["offsets"][i], b)
		var s := _step(_phase, off, duty, reach, lift)
		var out := s.y * 0.5 * _cling * (1.0 if i % 2 == 0 else -1.0)
		p.feet[i] += Vector3(out, s.y, s.x) * _moving
	# The hands flat and turned out a little; the feet flat ahead.
	for i in 4:
		var sign := 1.0 if i % 2 == 0 else -1.0
		p.ways[i] = Vector3(0.15 * sign, -0.15, 1.0).normalized() if i < 2 else Vector3(0.1 * sign, -0.2, 1.0).normalized()
		p.set_way[i] = 0.9
	# The body rolls from one side to the other at a walk; at a bound it bunches and stretches.
	var roll := sin(TAU * _phase) * 0.014 * (1.0 - b) * _moving
	var bob := -cos(TAU * 2.0 * _phase) * 0.012 * (1.0 - b) * _moving
	var bound := sin(TAU * (_phase - 0.2)) * 0.045 * b * _moving
	var stretch := sin(TAU * (_phase - 0.05)) * 0.06 * b * _moving
	p.pelvis += Vector3(-roll, bob + bound, -stretch * 0.5)
	p.chest += Vector3(roll, bob * 0.6 + bound * 0.7, stretch * 0.5)
	# Bouncing in place (a rustle on the ground: the threat before it comes on).
	if _rustle > 0.0:
		var bounce := absf(sin(_t * 15.0)) * 0.05 * _rustle
		p.pelvis.y += bounce
		p.chest.y += bounce * 1.2
	p.front = Vector3.DOWN
	p.head_up = 0.25 + 0.15 * _cling
	p.fingers = [0.35, 0.35]
	p.toes = [0.3, 0.3]
	var breath := sin(_t * 3.0)
	p.chest.y += breath * 0.003
	# The tail up behind in an arch, the tip curled (on a wall, trailing down it).
	var torso := _torso(p.pelvis, p.chest, p.front)
	var rise := lerpf(1.25, 0.25, _cling) - 0.25 * b * _moving
	p.tail = _tail_free(torso, rise, lerpf(-0.17, -0.02, _cling), lerpf(-0.35, 0.3, _cling), sin(TAU * _phase) * 0.12 * _moving)
	p.jaw = 0.12 * b * _moving
	return p


## Hanging from the line above it, still (in its `hang_style`) or swinging along it.
func _hang_pose() -> Pose:
	var axis := (global_basis.orthonormalized().inverse() * hold_axis)
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
	var hold := Vector3(0.0, HANG_HIGH, 0.0)
	var still := _hang_still(hold, axis, hang_style)
	if _swinging > 0.0:
		still = still.blend(_hand_over_hand(hold, axis), smoothstep(0.0, 1.0, _swinging))
	return still


func _hang_still(hold: Vector3, axis: Vector3, style: Hang) -> Pose:
	var p := Pose.new()
	var breath := sin(_t * 2.6)
	# Which side of it holds on (its left, if the line runs that way).
	var hand_side := 1.0 if axis.x >= 0.0 else -1.0
	if style == Hang.HAND:
		# By the tail and one hand, head up, the body hanging under the line.
		p.pelvis = Vector3(0.0, 0.27, 0.03)
		p.chest = Vector3(0.015, 0.56 + breath * 0.004, 0.07)
		p.front = Vector3.BACK
		var grip := 0 if hand_side > 0.0 else 1
		var free_arm := 1 - grip
		p.feet[grip] = hold + axis * 0.07 * hand_side + Vector3(0.0, -0.085, -0.005)
		p.ways[grip] = Vector3.UP
		p.set_way[grip] = 1.0
		p.fingers[grip] = 1.0
		p.poles[grip] = Vector3(hand_side * 0.8, 0.0, 0.6)
		var loose := Vector3(-0.13 * hand_side, 0.16, 0.12) + Vector3(sin(_t * 0.9 + _sway_seed) * 0.015, 0.0, sin(_t * 0.7) * 0.02)
		if _idle_hand != Vector3.ZERO:
			loose = Vector3(-_idle_hand.x * hand_side, 0.32 + _idle_hand.y * 0.4, 0.13 + _idle_hand.z)
		p.feet[free_arm] = loose
		p.ways[free_arm] = Vector3.DOWN
		p.set_way[free_arm] = 0.0
		p.fingers[free_arm] = 0.55
		p.poles[free_arm] = Vector3(-hand_side * 0.6, 0.0, -1.0)
		# The legs hanging, knees a little drawn up, the feet loose.
		p.feet[2] = Vector3(0.085, 0.015 + sin(_t * 1.1 + _sway_seed) * 0.01, 0.11)
		p.feet[3] = Vector3(-0.08, 0.04, 0.14)
		p.poles[2] = Vector3(0.3, 0.0, 1.0)
		p.poles[3] = Vector3(-0.3, 0.0, 1.0)
		p.ways[2] = Vector3(0.1, -0.9, 0.4).normalized()
		p.ways[3] = Vector3(-0.1, -0.9, 0.45).normalized()
		p.set_way[2] = 0.6
		p.set_way[3] = 0.6
		p.toes = [0.5, 0.6]
		var torso := _torso(p.pelvis, p.chest, p.front)
		var root := _tail_root(p.pelvis, torso)
		# (the tail up round its side from the rump, holding on beyond its body from the hand)
		p.tail = _tail_grip(root, hold - axis * 0.2 * hand_side, axis, -axis * hand_side * 0.8 + Vector3(0.0, 0.0, -0.6), torso.x)
		p.head_up = -0.1
	else:
		# By the tail alone, upside down, arms dangling, one foot on the line too.
		p.pelvis = Vector3(0.0, 0.47, 0.0)
		p.chest = Vector3(0.0, 0.17 + breath * 0.004, 0.06)
		p.front = Vector3.BACK
		for i in 2:
			var sign := 1.0 if i == 0 else -1.0
			var dangle := sin(_t * 0.8 + _sway_seed + i * 1.7) * 0.03
			p.feet[i] = Vector3(0.1 * sign + dangle * sign, -0.25, 0.1 + dangle)
			p.ways[i] = Vector3.DOWN
			p.set_way[i] = 0.3
			p.fingers[i] = 0.5
			p.poles[i] = Vector3(sign * 0.5, 0.0, -1.0)
		p.feet[2] = hold + axis * 0.1 + Vector3(0.0, -0.1, 0.0)
		p.ways[2] = Vector3.UP
		p.set_way[2] = 1.0
		p.poles[2] = Vector3(0.5, 0.0, 1.0)
		p.feet[3] = Vector3(-0.09, 0.58, 0.12)
		p.ways[3] = Vector3(0.0, 0.4, 1.0).normalized()
		p.set_way[3] = 0.5
		p.poles[3] = Vector3(-0.4, 0.0, 1.0)
		p.toes = [1.0, 0.5]
		var torso := _torso(p.pelvis, p.chest, p.front)
		var root := _tail_root(p.pelvis, torso)
		p.tail = _tail_grip(root, hold - axis * 0.03, axis, Vector3(0.0, 0.0, -1.0), torso.x)
		p.head_up = 0.0
	p.fingers[0] = maxf(p.fingers[0], 0.3)
	return p


## Swinging along the line hand over hand, the tail taking hold behind.
func _hand_over_hand(hold: Vector3, axis: Vector3) -> Pose:
	var p := Pose.new()
	var way := axis * _travel
	var cycle: float = SWING["cycle"]
	var duty: float = SWING["duty"]
	var reach := cycle * duty
	# The body swings under its hands, one way and the other with each reach.
	var sway := sin(TAU * _swing_phase * 2.0)
	p.pelvis = Vector3(0.0, 0.3, 0.02) - way * 0.06 + way * sway * 0.05
	p.chest = Vector3(0.0, 0.58, 0.06) + way * 0.04 + way * sway * 0.03
	p.front = Vector3.BACK
	for i in 2:
		var s := _step(_swing_phase, SWING["offsets"][i], duty, reach, 0.12)
		var sign := 1.0 if i == 0 else -1.0
		var grip := hold + way * (s.x + 0.04) + Vector3(0.02 * sign, -0.085 - s.y, 0.05 * s.y)
		p.feet[i] = grip
		p.ways[i] = (Vector3.UP + way * 0.5 * s.y).normalized()
		p.set_way[i] = 1.0
		p.fingers[i] = 1.0 - s.y * 4.0
		p.poles[i] = Vector3(sign * 0.6, 0.0, 0.7)
	# The legs trailing, tucked a little.
	p.feet[2] = Vector3(0.08, 0.03, 0.08) - way * 0.12
	p.feet[3] = Vector3(-0.08, 0.05, 0.1) - way * 0.1
	p.poles[2] = Vector3(0.3, 0.0, 1.0)
	p.poles[3] = Vector3(-0.3, 0.0, 1.0)
	p.ways[2] = Vector3(0.0, -0.8, 0.5).normalized()
	p.ways[3] = Vector3(0.0, -0.8, 0.5).normalized()
	p.set_way[2] = 0.5
	p.set_way[3] = 0.5
	var t := _step(_swing_phase, SWING["offsets"][2], duty, reach, 0.12)
	var torso := _torso(p.pelvis, p.chest, p.front)
	var root := _tail_root(p.pelvis, torso)
	p.tail = _tail_grip(root, hold + way * (t.x - 0.25) - Vector3.UP * t.y, axis, Vector3(0.0, 0.0, -1.0), torso.x)
	p.head_up = 0.05
	return p


## Hanging, drawn up and swung back on its tail, the hand let go: about to fling itself off.
func _wind_pose() -> Pose:
	var axis := (global_basis.orthonormalized().inverse() * hold_axis)
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
	var hold := Vector3(0.0, HANG_HIGH, 0.0)
	var p := Pose.new()
	var shake := sin(_t * 23.0) * 0.012
	p.pelvis = Vector3(0.0, 0.5, -0.2)
	p.chest = Vector3(shake, 0.72, -0.02)
	p.front = Vector3(0.0, 0.4, 1.0).normalized()
	# Arms up and out over its head, hands open; knees drawn up to its chest.
	p.feet[0] = Vector3(0.24, 0.95, 0.08)
	p.feet[1] = Vector3(-0.24, 0.95, 0.08)
	p.ways[0] = Vector3(0.3, 1.0, 0.4).normalized()
	p.ways[1] = Vector3(-0.3, 1.0, 0.4).normalized()
	p.set_way = [0.6, 0.6, 0.6, 0.6]
	p.poles[0] = Vector3(1.0, -0.3, -0.5)
	p.poles[1] = Vector3(-1.0, -0.3, -0.5)
	p.feet[2] = Vector3(0.1, 0.45, 0.12)
	p.feet[3] = Vector3(-0.1, 0.45, 0.12)
	p.ways[2] = Vector3(0.0, 0.2, 1.0).normalized()
	p.ways[3] = Vector3(0.0, 0.2, 1.0).normalized()
	p.poles[2] = Vector3(0.4, 0.6, 1.0)
	p.poles[3] = Vector3(-0.4, 0.6, 1.0)
	p.fingers = [0.0, 0.0]
	p.toes = [0.0, 0.0]
	var torso := _torso(p.pelvis, p.chest, p.front)
	var root := _tail_root(p.pelvis, torso)
	p.tail = _tail_grip(root, hold, axis, Vector3(0.0, 0.3, -1.0), torso.x)
	p.head_up = 0.25
	p.jaw = 0.75
	return p


## In the air: arms and legs reaching ahead and down for what it will land on, tail up behind.
func _air_pose() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, 0.42, -0.14)
	p.chest = Vector3(0.0, 0.46, 0.15)
	p.front = Vector3.DOWN
	var open := sin(_t * 9.0) * 0.02
	p.feet[0] = Vector3(0.2, 0.3 + open, 0.55)
	p.feet[1] = Vector3(-0.2, 0.3 - open, 0.55)
	p.feet[2] = Vector3(0.13, 0.08, 0.06)
	p.feet[3] = Vector3(-0.13, 0.08, 0.04)
	p.poles[0] = Vector3(1.0, 0.3, -0.3)
	p.poles[1] = Vector3(-1.0, 0.3, -0.3)
	p.poles[2] = Vector3(0.6, 0.4, 1.0)
	p.poles[3] = Vector3(-0.6, 0.4, 1.0)
	p.ways[0] = Vector3(0.2, -0.3, 1.0).normalized()
	p.ways[1] = Vector3(-0.2, -0.3, 1.0).normalized()
	p.ways[2] = Vector3(0.1, -0.5, 1.0).normalized()
	p.ways[3] = Vector3(-0.1, -0.5, 1.0).normalized()
	p.set_way = [0.8, 0.8, 0.7, 0.7]
	p.fingers = [0.0, 0.0]
	p.toes = [0.0, 0.0]
	var torso := _torso(p.pelvis, p.chest, p.front)
	p.tail = _tail_free(torso, 0.45, -0.05, -0.25, sin(_t * 6.0) * 0.1)
	p.head_up = 0.35
	p.jaw = 0.7
	return p


## The threat on the ground: up on its hind legs, arms over its head, shaking, mouth open.
func _display_pose() -> Pose:
	var p := Pose.new()
	var bounce := absf(sin(_t * 8.0)) * 0.05
	var wave := sin(_t * 13.0)
	p.pelvis = Vector3(0.0, 0.33 + bounce, -0.02)
	p.chest = Vector3(0.0, 0.62 + bounce * 1.2, 0.03)
	p.front = Vector3.BACK
	p.feet[0] = Vector3(0.2, 1.0 + bounce + wave * 0.04, 0.05)
	p.feet[1] = Vector3(-0.2, 1.0 + bounce - wave * 0.04, 0.05)
	p.ways[0] = Vector3(0.3, 1.0, 0.2).normalized()
	p.ways[1] = Vector3(-0.3, 1.0, 0.2).normalized()
	p.set_way[0] = 0.7
	p.set_way[1] = 0.7
	p.poles[0] = Vector3(1.0, 0.0, -0.4)
	p.poles[1] = Vector3(-1.0, 0.0, -0.4)
	p.feet[2] = Vector3(0.09, 0.05, 0.02)
	p.feet[3] = Vector3(-0.09, 0.05, 0.02)
	p.ways[2] = Vector3(0.15, -0.3, 1.0).normalized()
	p.ways[3] = Vector3(-0.15, -0.3, 1.0).normalized()
	p.set_way[2] = 0.9
	p.set_way[3] = 0.9
	p.poles[2] = Vector3(0.4, 0.0, 1.0)
	p.poles[3] = Vector3(-0.4, 0.0, 1.0)
	p.fingers = [0.1 + absf(wave) * 0.4, 0.1 + absf(wave) * 0.4]
	var torso := _torso(p.pelvis, p.chest, p.front)
	p.tail = _tail_free(torso, 0.9, -0.12, -0.3, wave * 0.15)
	p.head_up = 0.3
	p.head_turn = sin(_t * 5.0) * 0.25
	p.jaw = 0.85 + sin(_t * 17.0) * 0.1
	return p


func _pose(delta: float) -> void:
	var p := _fours_pose()
	if _hang > 0.0:
		p = p.blend(_hang_pose(), smoothstep(0.0, 1.0, _hang))
	if _wind > 0.0:
		p = p.blend(_wind_pose(), smoothstep(0.0, 1.0, _wind))
	if _display > 0.0:
		p = p.blend(_display_pose(), smoothstep(0.0, 1.0, _display))
	if _air > 0.0:
		p = p.blend(_air_pose(), smoothstep(0.0, 1.0, _air))
	# The chitter: lips pushed out, a quick working of the jaw, the head bobbing.
	if _chitter < CHITTER_TIME:
		var c := sin(PI * _chitter / CHITTER_TIME)
		p.jaw = maxf(p.jaw, 0.18 * absf(sin(_chitter * 38.0)) * c)
		p.lips = maxf(p.lips, c)
		p.head_up += sin(_chitter * 19.0) * 0.08 * c
	# The shriek: mouth wide, head thrust up and out.
	if _shriek < SHRIEK_TIME:
		var s := minf(sin(PI * _shriek / SHRIEK_TIME) * 2.0, 1.0)
		p.jaw = maxf(p.jaw, 0.95 * s)
		p.head_up += 0.3 * s
	var lean := clampf(-_turn * _speed * 0.05, -0.3, 0.3) * (1.0 - _hang) * (1.0 - _cling)
	# Swaying under its hold (a pendulum about the line), shaken when it rustles.
	var hold := Vector3(0.0, HANG_HIGH, 0.0)
	var swing := Transform3D.IDENTITY
	if _hang > 0.0:
		var axis := (global_basis.orthonormalized().inverse() * hold_axis)
		axis.y = 0.0
		axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
		var sway := sin(_t * 1.5 + _sway_seed) * 0.06 + sin(_t * 0.6 + _sway_seed * 2.0) * 0.04
		sway += sin(_t * 19.0) * 0.07 * _rustle
		sway -= 0.35 * _wind
		var twist := sin(_t * 0.45 + _sway_seed) * 0.25 * (1.0 - _swinging)
		var turn := Basis(axis, sway * _hang) * Basis(Vector3.UP, twist * _hang)
		swing = Transform3D(turn, hold - turn * hold)
	# In the air, pitched by how it falls (head down falling, up rising).
	var pitch := 0.0
	if _air > 0.0:
		var flat := maxf(_speed, 0.5)
		pitch = clampf(atan2(-_fall, flat) * 0.6, -0.5, 0.9) * _air
	_frame = swing * Transform3D(Basis(Vector3.BACK, lean) * Basis(Vector3.RIGHT, pitch), Vector3.ZERO)
	_look(p, delta)
	_apply(p)


## Where its eyes are on: what it was given, or where it goes, or (still) about it.
func _look(p: Pose, delta: float) -> void:
	var want := Vector3(0.0, -0.15, 1.0)
	var snap := 6.0
	if look_at_point.is_finite():
		var local := (_frame.affine_inverse() * (global_transform.affine_inverse() * look_at_point)) / size
		want = (local - p.chest - Vector3(0.0, 0.1, 0.05)).normalized()
		if want.z < 0.05:
			want.z = 0.05
			want = want.normalized()
		snap = 10.0
	elif _moving < 0.5 and _air < 0.5:
		_scan_next -= delta
		if _scan_next <= 0.0:
			_scan_next = _rng.randf_range(0.7, 2.8)
			_scan = Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.6, 0.2), 1.0)
		want = _scan.normalized()
		if _cling > 0.5:
			want = Vector3(_scan.x * 0.5, 0.6, 0.6 + _scan.y).normalized()
	_gaze = _gaze.slerp(want, 1.0 - exp(-snap * delta)) if delta > 0.0 else want


# --- The skeleton ---

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space (where its two ends are, worked out in `_joints`), so the
## mesh bends between them however the body is put.
const BONES: Array[String] = ["hips", "belly", "chest", "neck", "head", "jaw",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "fingers_l", "fingers_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "toes_l", "toes_r",
	"tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7", "tail_8", "tail_9", "tail_10"]
const HIPS := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const ARM_U := 6
const ARM_L := 8
const HAND := 10
const FINGERS := 12
const LEG_U := 14
const LEG_L := 16
const FOOT := 18
const TOES := 20
const TAIL := 22

## The skull's half-width (metres at size 1), and where the jaw hinges (head space: +Z ahead, +Y up).
const HEAD_SIZE := 0.052
const HINGE := Vector3(0.0, -0.022, 0.01)
## How far along the hand the fingers start, and along the foot the toes.
const PALM := 0.055
const SOLE := 0.065


## The way it was modelled: its body as on all fours, but its arms and legs
## spread out from it (wide of its chest and haunches, so that the mesh under
## the arms and between the legs belongs to the body, and stays put however
## the limbs are turned).
func _standing() -> Pose:
	var p := Pose.from(FOURS)
	p.feet = [Vector3(0.36, 0.2, 0.3), Vector3(-0.36, 0.2, 0.3), Vector3(0.25, 0.08, -0.08), Vector3(-0.25, 0.08, -0.08)]
	p.poles = [Vector3(0.3, 0.2, -1.0), Vector3(-0.3, 0.2, -1.0), Vector3(0.4, 0.4, 1.0), Vector3(-0.4, 0.4, 1.0)]
	for i in 4:
		var sign := 1.0 if i % 2 == 0 else -1.0
		p.ways[i] = Vector3(0.5 * sign, -0.3, 1.0).normalized() if i < 2 else Vector3(0.3 * sign, -0.3, 1.0).normalized()
		p.set_way[i] = 0.5
	p.front = Vector3.DOWN
	var torso := _torso(p.pelvis, p.chest, p.front)
	# (the tail laid out back and a little up, nearly straight, to be modelled round)
	p.tail = _tail_free(torso, 0.5, -0.04, 0.0, 0.0)
	return p


## Where everything is, for a pose and a way of looking (metres at size 1, its own space).
func _joints(p: Pose, gaze_dir: Vector3) -> Dictionary:
	var j := {}
	var torso := _torso(p.pelvis, p.chest, p.front)
	var side := torso.x
	var spine := torso.y
	var front := torso.z
	j["torso"] = torso
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	# The pot belly hangs out from the middle of it.
	j["belly"] = p.pelvis.lerp(p.chest, 0.42) + front * 0.025
	var neck := p.chest + spine * 0.055 + front * 0.012
	j["neck"] = neck
	# Limbs, each bent at the elbow or knee to reach its wrist or ankle.
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	for i in 4:
		var arm := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var root := (p.chest + side * sign * 0.075 - front * 0.01) if arm else (p.pelvis + side * sign * 0.055 - spine * 0.02)
		var lengths := ARM if arm else LEG
		var mid := _bend(root, p.feet[i], lengths.x, lengths.y, p.poles[i])
		roots.append(root)
		mids.append(mid)
		ends.append(mid + (p.feet[i] - mid).normalized() * lengths.y)
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	# The hands and feet: on from the forearm and shin, or set their own way.
	var hands: Array[Basis] = []
	var tips := PackedVector3Array()
	for i in 4:
		var along := (ends[i] - mids[i]).normalized()
		var way := p.ways[i].normalized() if p.ways[i].length() > 0.01 else along
		var dir := along.slerp(way, clampf(p.set_way[i], 0.0, 1.0)).normalized()
		var basis := _along(dir, side)
		hands.append(basis)
		tips.append(ends[i] + dir * (PALM if i < 2 else SOLE))
	j["hands"] = hands
	j["knuckles"] = tips
	# The head, turned to look along `gaze_dir`, tipped up by `head_up`; the jaw.
	var gaze := (Basis(Vector3.UP, p.head_turn) * Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	var top := spine - front * 0.5
	top = top - gaze * top.dot(gaze)
	if top.length() < 0.05:
		top = Vector3.UP - gaze * gaze.y
	var head_at := neck + spine * 0.04 + gaze * 0.022
	var head_basis := Basis.looking_at(-gaze, top.normalized())
	var head := Transform3D(head_basis, head_at)
	j["head_xform"] = head
	j["jaw_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.7), head * HINGE)
	j["lips"] = p.lips
	# The tail, from its root.
	var root := _tail_root(p.pelvis, torso)
	var tail := PackedVector3Array()
	for k in TAIL_COUNT + 1:
		tail.append(root + (p.tail[k] if k < p.tail.size() else Vector3.ZERO))
	j["tail"] = tail
	j["fingers"] = p.fingers
	j["toes"] = p.toes
	return j


## Each bone's two ends, as a pair, or (for the bones that are not stretched
## between two places) its whole transform.
func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	var torso: Basis = j["torso"]
	pairs[HIPS] = [j["pelvis"] - torso.y * 0.06, j["pelvis"]]
	pairs[BELLY] = [j["pelvis"], j["belly"]]
	pairs[CHEST] = [j["belly"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	pairs[JAW] = j["jaw_xform"]
	var hands: Array = j["hands"]
	var fingers: Array = j["fingers"]
	var toes: Array = j["toes"]
	for i in 4:
		var arm := i < 2
		var root: Vector3 = j["roots"][i]
		var mid: Vector3 = j["mids"][i]
		var end: Vector3 = j["ends"][i]
		pairs[(ARM_U if arm else LEG_U) + i % 2] = [root, mid]
		pairs[(ARM_L if arm else LEG_L) + i % 2] = [mid, end]
		var hand: Basis = hands[i]
		var curl: float = fingers[i] if arm else toes[i - 2]
		pairs[(HAND if arm else FOOT) + i % 2] = Transform3D(hand, end)
		pairs[(FINGERS if arm else TOES) + i % 2] = Transform3D(hand * Basis(Vector3.RIGHT, curl * 1.5), j["knuckles"][i])
	var tail: PackedVector3Array = j["tail"]
	for k in TAIL_COUNT:
		pairs[TAIL + k] = [tail[k], tail[k + 1]]
	return pairs


## Each bone's transform (skeleton space, as `_rest` is) for these joints.
func _bone_globals(j: Dictionary) -> Array[Transform3D]:
	var pairs := _pairs(j)
	var torso: Basis = j["torso"]
	var out: Array[Transform3D] = []
	for b in BONES.size():
		if pairs[b] is Transform3D:
			out.append(pairs[b])
			continue
		var a: Vector3 = pairs[b][0]
		var c: Vector3 = pairs[b][1]
		var length := (c - a).length()
		out.append(Transform3D(_along((c - a) / maxf(length, 0.0001), torso.x), a))
	return out


## A basis whose Y is `y`, with X as near `side` as can be.
static func _along(y: Vector3, side: Vector3) -> Basis:
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## The middle joint of a limb from `a` to `target`, bones `l1` and `l2` long, bending towards `pole`.
static func _bend(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var along := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3.UP
	return a + along * x + side * h


## Poses the skeleton.
func _apply(p: Pose) -> void:
	var j := _joints(p, _gaze)
	var globals := _bone_globals(j)
	for b in globals.size():
		var moved := _frame * globals[b] * _rest[b].affine_inverse()
		var g := _skeleton_from_model * moved * _skeleton_from_model.affine_inverse() * _model_rest[b]
		var bone := _index[b]
		if bone < 0:
			continue
		var parent := _skeleton.get_bone_parent(bone)
		if parent >= 0:
			g = _skeleton.get_bone_global_pose(parent).affine_inverse() * g
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())
	# Where it can take hold of something: its hands and feet, and where its head is.
	var to_world := _model.global_transform * _frame
	_grabbers = PackedVector3Array()
	var hands: Array = j["hands"]
	for i in 4:
		var end: Vector3 = j["ends"][i]
		_grabbers.append(to_world * (end + (hands[i] as Basis).y * (HAND_LONG if i < 2 else FOOT_LONG) * 0.7))
	var head: Transform3D = j["head_xform"]
	_grabbers.append(to_world * (head * Vector3(0.0, 0.0, 0.03)))


# --- Its voice ---

func _say(what: StringName) -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = sound(what)
	_voice.pitch_scale = _rng.randf_range(0.9, 1.12)
	_voice.play()


## Its sounds, made once and shared: `whinny`, `shriek` or `chitter`.
static func sound(what: StringName) -> AudioStreamWAV:
	if _sounds.has(what):
		return _sounds[what]
	var made: AudioStreamWAV
	match what:
		&"whinny":
			made = _voice_sound(1.0, 41, _whinny_shape, 11.0)
		&"shriek":
			made = _voice_sound(0.7, 53, _shriek_shape)
		&"chitter":
			made = _voice_sound(0.5, 67, _chitter_shape, 17.0)
	_sounds[what] = made
	return made


## Its whinny (the spider monkey's call, like a small horse's): a high, quavering
## squeal that falls in a run of quick pulses (pitch, loudness, how much of each
## pulse is voiced; `t` 0..1).
static func _whinny_shape(t: float) -> Vector3:
	var pitch := 2300.0 - 1100.0 * smoothstep(0.0, 1.0, t)
	return Vector3(pitch, 1.0 - 0.5 * t, 0.85)


## Its shriek: a harsh scream that breaks upward.
static func _shriek_shape(t: float) -> Vector3:
	var pitch := 1500.0 + 900.0 * sin(PI * clampf(t / 0.8, 0.0, 1.0)) + 220.0 * sin(t * 61.0)
	return Vector3(pitch, 1.0, 1.0)


## Its chitter: quick, soft, twittering pulses.
static func _chitter_shape(t: float) -> Vector3:
	return Vector3(2800.0 + 500.0 * sin(t * 40.0), 0.6, 0.45)


## A small, shrill voice: glottal pulses (a little off in time) through a
## throat's resonances, with breath, chopped into pulses `rate` a second (0:
## one long cry). `shape(t)` is (pitch, loudness, how much of each pulse is
## voice) at each moment.
static func _voice_sound(length: float, seed: int, shape: Callable, rate := 0.0) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := PackedFloat32Array()
	samples.resize(count)
	var bands: Array[_Band] = [_Band.new(1900.0, 5.0, mix), _Band.new(3300.0, 6.0, mix), _Band.new(4800.0, 6.0, mix)]
	var gains := [1.0, 0.7, 0.35]
	var breath := _Band.new(5200.0, 1.2, mix)
	var phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / mix
		var s: Vector3 = shape.call(t / length)
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := s.x * (1.0 + 0.06 * wander)
		var gate := 1.0
		if rate > 0.0:
			var pulse_at := fposmod(t * rate, 1.0)
			gate = smoothstep(0.0, 0.1, pulse_at) * (1.0 - smoothstep(s.z * 0.8, s.z, pulse_at))
			pitch *= 1.1 - 0.15 * pulse_at
		phase += pitch / mix * (1.0 + rng.randf_range(-0.04, 0.04))
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 4.0) * 2.0 - 0.4
		var throat := 0.0
		for k in bands.size():
			throat += bands[k].run(pulse) * gains[k]
		var air := breath.run(rng.randf_range(-1.0, 1.0)) * (0.5 + 0.5 * (1.0 - p))
		var fade := smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(length - 0.1, length, t))
		var value := (throat * 1.5 + air * 0.8) * gate * s.y * fade
		value = tanh(value * 2.0)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 26000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = mix
	made.data = data
	return made


## A resonant band-pass filter (a biquad).
class _Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * frequency / rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_a1 = -2.0 * cos(w) / a0
		_a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y
