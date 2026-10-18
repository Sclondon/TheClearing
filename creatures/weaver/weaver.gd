class_name Weaver
extends Node3D
## The weaver: a tall, thin, pale figure with six arms and four wings that
## hangs in the air. How it looks and how it moves, and nothing of what it
## thinks: whatever drives it moves this node about and calls on it.
##
## WHAT IT IS. Longer than a man, starved-thin and waxen pale: a long neck and a
## smooth, faceless head like an egg of wet porcelain, bowed a little; a narrow
## ribbed body; six long arms in three pairs (from the shoulders, the ribs and the
## waist), with long hands of long jointed fingers; long thin legs that hang
## beneath it, toes pointed, never touching anything; and on its back four great
## wings in two pairs, a moth's or a lacewing's, pale and veined and tattered,
## the light coming through them. One skinned mesh (models/weaver.glb, built in
## Blender by tools/build_weaver.py) on a skeleton posed here: one draw.
##
## HOW IT MOVES. Move the node and turn it (it faces +Z); its feet hang `size`
## under nothing at all (the node is where its toes would touch, if they did).
## It works out its speed from how it is moved: hovering, it hangs upright and
## its wings beat slowly, fore and hind pairs out of step; going, it leans into
## it, its legs trail, its wings spread and glide. Its hands are never still:
## they turn and weave in front of it as if signing, every finger moving. Its
## head turns to `look_at_point` (world, INF for none), slowly, and tips.
##
## WHAT IT DOES:
## - `weaving` (0..1): its hands come together before it and draw apart in
##   pairs, as if pulling threads; `weave_hands()` are the three pairs of hands
##   (world) to draw threads between;
## - `reach_point` (world, INF for none) with `reaching` (0..1): it bends down
##   to the point, every arm reaching for it, fingers spread, closing as
##   `reaching` reaches 1; `holding`: whatever it took held against it in all
##   six hands (`hold_point()`);
## - `keen()`: a thin rising whine (it is coming), `twang(at)`: the deep pluck
##   of a thread, `hum`: the drone of its wings while it is near (`voice`).
##
## Set `size` (metres, toe to crown) and `seed_value` before it goes into the
## tree. Hide it or disable its processing when far from the camera.

## Its own units: one is its height, toe to crown.
## Limb lengths: upper arm, forearm (each pair the same); thigh, shin.
const ARM := Vector2(0.165, 0.165)
const LEG := Vector2(0.235, 0.235)
const HAND_LONG := 0.11
## Where each pair of arms grows from (from the middle of the chest: across, up, ahead).
const SHOULDERS: Array[Vector3] = [Vector3(0.075, 0.045, -0.005), Vector3(0.062, -0.03, 0.0), Vector3(0.055, -0.1, 0.005)]
## Where each pair of wings grows from (from the chest, the left one), and how long (root to bend, bend to tip).
const WING_ROOTS: Array[Vector3] = [Vector3(0.03, 0.04, -0.045), Vector3(0.028, -0.005, -0.05)]
const WING_LONG: Array[Vector2] = [Vector2(0.24, 0.4), Vector2(0.2, 0.3)]
## How the wings lie, spread (the left one; unit, from the root out).
const WING_SPREAD: Array[Vector3] = [Vector3(0.62, 0.66, -0.42), Vector3(0.78, 0.08, -0.6)]
const WING_FOLD: Array[Vector3] = [Vector3(0.2, -0.75, -0.6), Vector3(0.18, -0.85, -0.5)]

@export var size := 3.3
@export var seed_value := 0
## Use the low-poly model (models/weaver_lo.glb), as `low_poly` does for every one.
@export var force_low := false
@export var voice := true
@export var volume_db := -6.0
@export var voice_range := 45.0

static var low_poly := false

var look_at_point := Vector3.INF
## Drawing threads between its hands, 0..1.
var weaving := 0.0
## Reaching down for a point (world), 0..1 how far.
var reach_point := Vector3.INF
var reaching := 0.0
## Holding what it took against itself.
var holding := false
## Its wings folded down its back (0) or spread (1); left alone it follows its speed.
var wings_open := -1.0
## The drone of its wings.
var hum := false

const MODEL := "res://creatures/weaver/models/weaver.glb"
const MODEL_LO := "res://creatures/weaver/models/weaver_lo.glb"

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rest: Array[Transform3D] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
var _frame := Transform3D.IDENTITY
var _voice: AudioStreamPlayer3D
var _drone: AudioStreamPlayer3D

var _t := 0.0
var _was := Vector3.INF
var _speed := 0.0
var _going := Vector3.ZERO
var _turn := 0.0
var _yaw_was := 0.0
var _beat := 0.0
var _open := 0.6
var _weave := 0.0
var _reach := 0.0
var _hold := 0.0
var _gaze := Vector3(0.0, -0.2, 1.0)
var _tilt := 0.0
var _tilt_want := 0.0
var _tilt_next := 2.0
var _phases := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _hands := PackedVector3Array()
var _head_at := Vector3.ZERO
var _chest_at := Vector3.ZERO

static var _sounds := {}


func _ready() -> void:
	_rng.seed = seed_value
	_phases.resize(6)
	for i in 6:
		_phases[i] = _rng.randf() * TAU
	_hands.resize(6)
	_rest = _bone_globals(_joints(_standing(), Vector3(0.0, -0.2, 1.0)))
	var low := low_poly or force_low
	_model = (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = WeaverLook.material()
	_body.custom_aabb = AABB(Vector3(-1.0, -0.3, -1.0), Vector3(2.0, 1.8, 2.0))
	_body.set_instance_shader_parameter(&"tone", _rng.randf_range(0.92, 1.06))
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 6.0
		_voice.max_distance = voice_range
		_voice.position = Vector3(0.0, 0.85 * size, 0.0)
		add_child(_voice)
		_drone = AudioStreamPlayer3D.new()
		_drone.volume_db = volume_db - 10.0
		_drone.unit_size = 4.0
		_drone.max_distance = voice_range * 0.5
		_drone.position = Vector3(0.0, 0.75 * size, -0.1 * size)
		add_child(_drone)
	settle()


## Straight into its pose where it is, with nothing going on.
func settle() -> void:
	_was = global_position
	_yaw_was = global_rotation.y
	_speed = 0.0
	_going = Vector3.ZERO
	_weave = weaving
	_reach = reaching
	_hold = 1.0 if holding else 0.0
	_pose(0.0)


## A thin whine rising: it is coming.
func keen() -> void:
	_say(&"keen")


## The deep pluck of a thread, heard from `at` (world; INF: where it is).
func twang(at := Vector3.INF) -> void:
	if _voice == null or not is_inside_tree():
		return
	var plucked := AudioStreamPlayer3D.new()
	plucked.stream = sound(&"twang")
	plucked.volume_db = volume_db + 2.0
	plucked.unit_size = 5.0
	plucked.max_distance = voice_range * 1.4
	plucked.pitch_scale = _rng.randf_range(0.85, 1.15)
	add_child(plucked)
	plucked.global_position = at if at.is_finite() else global_position + Vector3.UP * size * 0.6
	plucked.finished.connect(plucked.queue_free)
	plucked.play()


## The three pairs of hands (world), left then right of each, from the last frame.
func weave_hands() -> PackedVector3Array:
	return _hands


## Where what it holds is (world): before its belly, in all its hands.
func hold_point() -> Vector3:
	var at := Vector3.ZERO
	for p in _hands:
		at += p
	return at / maxf(_hands.size(), 1.0)


func head_position() -> Vector3:
	return _head_at


func chest_position() -> Vector3:
	return _chest_at


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := (at - _was) / size
	_was = at
	var basis_now := global_basis.orthonormalized()
	var local_moved := basis_now.inverse() * moved
	_going = _going.lerp(local_moved / delta, 1.0 - exp(-4.0 * delta))
	_speed = Vector2(_going.x, _going.z).length()
	var yaw_now := global_rotation.y
	_turn = lerpf(_turn, wrapf(yaw_now - _yaw_was, -PI, PI) / delta, 1.0 - exp(-4.0 * delta))
	_yaw_was = yaw_now
	var open := wings_open if wings_open >= 0.0 else clampf(0.55 + _speed * 1.2, 0.0, 1.0)
	_open = move_toward(_open, open, delta * 1.2)
	_weave = move_toward(_weave, weaving, delta * 2.5)
	_reach = move_toward(_reach, reaching if reach_point.is_finite() else 0.0, delta * 2.0)
	_hold = move_toward(_hold, 1.0 if holding else 0.0, delta * 2.0)
	# The wings beat slower as it glides (and still when folded).
	_beat += delta * lerpf(TAU * 1.3, TAU * 0.5, clampf(_speed * 2.0, 0.0, 1.0)) * _open
	_tilt_next -= delta
	if _tilt_next <= 0.0:
		_tilt_next = _rng.randf_range(2.0, 6.0)
		_tilt_want = _rng.randf_range(-0.45, 0.45) if _rng.randf() < 0.6 else 0.0
	_tilt = lerpf(_tilt, _tilt_want, 1.0 - exp(-1.2 * delta))
	if _drone:
		if hum and not _drone.playing:
			_drone.stream = sound(&"hum")
			_drone.play()
		elif not hum and _drone.playing:
			_drone.stop()
	_pose(delta)


# --- Posing ---

class Pose:
	var pelvis := Vector3.ZERO
	var chest := Vector3.ZERO
	## Each hand's wrist: upper left, upper right, middle left, middle right, lower left, lower right.
	var hands: Array[Vector3] = []
	var poles: Array[Vector3] = []
	var curls := PackedFloat32Array([0.4, 0.4, 0.4, 0.4, 0.4, 0.4])
	## The feet (the toes' tips): left, right.
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var head_up := 0.0
	var head_tilt := 0.0
	## The wings: how far each pair is spread (0 folded), and its beat (radians up).
	var spread := 0.6
	var beats := PackedFloat32Array([0.0, 0.0])


## Hanging still, its arms hanging loose: the way it was modelled.
func _standing() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, 0.545, 0.0)
	p.chest = Vector3(0.0, 0.76, 0.02)
	for i in 6:
		var s := 1.0 if i % 2 == 0 else -1.0
		var row := i / 2
		var root := p.chest + Vector3(SHOULDERS[row].x * s, SHOULDERS[row].y, SHOULDERS[row].z)
		p.hands.append(root + Vector3(0.1 * s, -0.27, 0.05))
		p.poles.append(Vector3(0.6 * s, 0.0, -1.0))
	p.feet = [Vector3(0.035, 0.0, -0.02), Vector3(-0.035, 0.0, -0.02)]
	p.spread = 0.6
	return p


## Its pose now, from what it is doing.
func _now() -> Pose:
	var p := _standing()
	var lean := clampf(_going.z * 1.6, -0.25, 0.42)
	var bob := sin(_t * 1.1) * 0.012 + sin(_beat) * 0.006 * _open
	p.pelvis += Vector3(0.0, bob, -lean * 0.08)
	p.chest += Vector3(sin(_t * 0.7) * 0.006, bob * 1.2, lean * 0.12)
	# The legs hang, trailing back as it goes, swaying a little out of step.
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var sway := sin(_t * 0.9 + k * 1.7) * 0.02
		p.feet[k] = Vector3(0.035 * s + sway * 0.5, 0.01 + lean * 0.12, -0.02 - lean * 0.3 + sway)
	# The hands, never still: each turning slow loops before it, as if signing.
	for i in 6:
		var s := 1.0 if i % 2 == 0 else -1.0
		var row := i / 2
		var root := p.chest + Vector3(SHOULDERS[row].x * s, SHOULDERS[row].y, SHOULDERS[row].z)
		var ph := _phases[i]
		var w := 1.6 + row * 0.25
		var loop := Vector3(0.05 * sin(_t * w + ph), 0.045 * sin(_t * w * 1.37 + ph * 2.0), 0.04 * cos(_t * w * 0.71 + ph))
		var signing := root + Vector3((0.07 + 0.02 * row) * s, -0.12 - row * 0.025, 0.13 - row * 0.015) + loop
		p.hands[i] = signing
		p.poles[i] = Vector3(0.9 * s, -0.2, -0.6)
		p.curls[i] = 0.45 + 0.4 * sin(_t * 1.9 + ph * 1.3)
	# Weaving: pairs of hands together before it, drawing apart and back.
	if _weave > 0.0:
		for row in 3:
			var draw := 0.5 + 0.5 * sin(_t * 2.4 + row * 2.1)
			var height := p.chest.y - 0.05 - row * 0.07
			for side in 2:
				var s := 1.0 if side == 0 else -1.0
				var i := row * 2 + side
				var at := Vector3(s * (0.02 + 0.2 * draw), height + 0.02 * sin(_t * 3.0 + i), 0.2 + 0.03 * row)
				p.hands[i] = p.hands[i].lerp(at, _weave)
				p.curls[i] = lerpf(p.curls[i], 0.75, _weave)
		p.head_up -= 0.25 * _weave
	# Reaching down for a point, every arm out for it; closing on it.
	if _reach > 0.0 and reach_point.is_finite():
		var local := (global_transform.affine_inverse() * reach_point) / size
		var bend := smoothstep(0.0, 1.0, _reach)
		p.chest += Vector3(0.0, -0.06 * bend, 0.08 * bend)
		p.pelvis += Vector3(0.0, 0.0, -0.04 * bend)
		for i in 6:
			var s := 1.0 if i % 2 == 0 else -1.0
			var row := i / 2
			var round_about := Vector3(s * (0.05 + 0.025 * row), 0.06 - row * 0.06, 0.03 * (row - 1))
			var grip := local + round_about * lerpf(1.6, 0.55, bend)
			p.hands[i] = p.hands[i].lerp(grip, bend)
			p.poles[i] = p.poles[i].lerp(Vector3(1.0 * s, 0.6, -0.2), bend)
			p.curls[i] = lerpf(0.05, 0.9, smoothstep(0.75, 1.0, _reach))
		p.head_up -= 0.5 * bend
	# Holding what it took against itself, in all six hands.
	if _hold > 0.0:
		for i in 6:
			var s := 1.0 if i % 2 == 0 else -1.0
			var row := i / 2
			var at := Vector3(s * 0.06, 0.55 + row * 0.04, 0.12 + 0.02 * (2 - row))
			p.hands[i] = p.hands[i].lerp(at, _hold)
			p.curls[i] = lerpf(p.curls[i], 0.95, _hold)
	# The wings.
	p.spread = _open
	for pair in 2:
		var beat := sin(_beat + pair * PI * 0.55)
		var glide := clampf(_speed * 2.0, 0.0, 1.0)
		p.beats[pair] = beat * lerpf(0.55, 0.12, glide) * _open + sin(_t * 23.0 + pair) * 0.015
	p.head_tilt = _tilt
	return p


func _pose(delta: float) -> void:
	var p := _now()
	_frame = Transform3D(Basis(Vector3.BACK, clampf(-_turn * 0.15, -0.2, 0.2)), Vector3.ZERO)
	var want := Vector3(0.0, -0.25, 1.0)
	var rate := 0.8
	if look_at_point.is_finite():
		var local := (global_transform.affine_inverse() * look_at_point) / size
		want = (local - p.chest - Vector3(0.0, 0.15, 0.0)).normalized()
		if want.z < 0.05:
			want.z = 0.05
			want = want.normalized()
		rate = 1.8
	_gaze = _gaze.slerp(want, 1.0 - exp(-rate * delta)) if delta > 0.0 else want
	_apply(p)


# --- The skeleton ---

const BONES: Array[String] = ["hips", "belly", "chest", "neck", "head",
	"arm_1l", "arm_1r", "arm_2l", "arm_2r", "arm_3l", "arm_3r",
	"forearm_1l", "forearm_1r", "forearm_2l", "forearm_2r", "forearm_3l", "forearm_3r",
	"hand_1l", "hand_1r", "hand_2l", "hand_2r", "hand_3l", "hand_3r",
	"fingers_1l", "fingers_1r", "fingers_2l", "fingers_2r", "fingers_3l", "fingers_3r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	"wing_fl", "wing_fr", "wingtip_fl", "wingtip_fr", "wing_hl", "wing_hr", "wingtip_hl", "wingtip_hr"]
const HIPS := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const ARM_U := 5
const ARM_L := 11
const HAND := 17
const FINGERS := 23
const LEG_U := 29
const LEG_L := 31
const FOOT := 33
const WING := 35
const WINGTIP := 37
const HIND := 39

## The head: how far it sits up the neck (units), its half-width and its length.
const HEAD_SIZE := Vector3(0.042, 0.062, 0.05)


func _joints(p: Pose, gaze_dir: Vector3) -> Dictionary:
	var j := {}
	var spine := (p.chest - p.pelvis).normalized()
	var side := (Vector3.RIGHT - spine * spine.x).normalized()
	var front := side.cross(spine).normalized()
	var torso := Basis(side, spine, front)
	j["torso"] = torso
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	j["belly"] = p.pelvis.lerp(p.chest, 0.5) + front * 0.004
	var neck := p.chest + spine * 0.075 + front * 0.012
	j["neck"] = neck
	# The head on its long neck, turned along `gaze_dir`, bowed and tipped.
	var gaze := (Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	var head_at := neck + (spine * 0.8 + Vector3.UP * 0.2).normalized() * 0.07 + gaze * 0.012
	var head_basis := Basis.looking_at(-gaze, Vector3.UP if absf(gaze.y) < 0.95 else front)
	head_basis = Basis(head_basis.z, p.head_tilt) * head_basis
	j["head_xform"] = Transform3D(head_basis, head_at)
	# Six arms, each bent at the elbow to reach its hand.
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	var hands: Array[Basis] = []
	var knuckles := PackedVector3Array()
	for i in 6:
		var s := 1.0 if i % 2 == 0 else -1.0
		var row := i / 2
		var root := p.chest + side * SHOULDERS[row].x * s + spine * SHOULDERS[row].y + front * SHOULDERS[row].z
		var mid := _bend(root, p.hands[i], ARM.x, ARM.y, p.poles[i])
		var end := mid + (p.hands[i] - mid).normalized() * ARM.y
		roots.append(root)
		mids.append(mid)
		ends.append(end)
		var along := (end - mid).normalized()
		hands.append(_along(along, side))
		knuckles.append(end + along * 0.045)
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	j["hands"] = hands
	j["knuckles"] = knuckles
	j["curls"] = p.curls
	# Two long legs hanging, toes pointed.
	var hips := PackedVector3Array()
	var knees := PackedVector3Array()
	var ankles := PackedVector3Array()
	var toes := PackedVector3Array()
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var hip := p.pelvis + side * 0.04 * s - spine * 0.02
		var toe := p.feet[k]
		var ankle := toe + (Vector3.UP * 0.9 - front * 0.25).normalized() * 0.07
		var knee := _bend(hip, ankle, LEG.x, LEG.y, Vector3(0.15 * s, 0.0, 1.0))
		hips.append(hip)
		knees.append(knee)
		ankles.append(knee + (ankle - knee).normalized() * LEG.y)
		toes.append(toe)
	j["hips"] = hips
	j["knees"] = knees
	j["ankles"] = ankles
	j["toes"] = toes
	# Four wings, each root to bend to tip, spread or folded, beating.
	var wing_roots := PackedVector3Array()
	var wing_mids := PackedVector3Array()
	var wing_tips := PackedVector3Array()
	for pair in 2:
		for k in 2:
			var s := 1.0 if k == 0 else -1.0
			var r := WING_ROOTS[pair]
			var root := p.chest + side * r.x * s + spine * r.y + front * r.z
			var spread := WING_SPREAD[pair]
			var fold := WING_FOLD[pair]
			var dir := fold.lerp(spread, clampf(p.spread, 0.0, 1.0))
			dir = (torso * Vector3(dir.x * s, dir.y, dir.z)).normalized()
			# (beating: up and down about the body's long axis, the tip lagging)
			var beat := p.beats[pair] * s
			var axis := front
			var one := dir.rotated(axis, beat)
			var two := dir.rotated(axis, beat * 1.35)
			var mid := root + one * WING_LONG[pair].x
			wing_roots.append(root)
			wing_mids.append(mid)
			wing_tips.append(mid + two * WING_LONG[pair].y)
	j["wing_roots"] = wing_roots
	j["wing_mids"] = wing_mids
	j["wing_tips"] = wing_tips
	return j


func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	var torso: Basis = j["torso"]
	pairs[HIPS] = [j["pelvis"] - torso.y * 0.06, j["pelvis"]]
	pairs[BELLY] = [j["pelvis"], j["belly"]]
	pairs[CHEST] = [j["belly"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	var hands: Array = j["hands"]
	var curls: PackedFloat32Array = j["curls"]
	for i in 6:
		pairs[ARM_U + i] = [j["roots"][i], j["mids"][i]]
		pairs[ARM_L + i] = [j["mids"][i], j["ends"][i]]
		var hand: Basis = hands[i]
		pairs[HAND + i] = Transform3D(hand, j["ends"][i])
		pairs[FINGERS + i] = Transform3D(hand * Basis(Vector3.RIGHT, curls[i] * 1.2), j["knuckles"][i])
	for k in 2:
		pairs[LEG_U + k] = [j["hips"][k], j["knees"][k]]
		pairs[LEG_L + k] = [j["knees"][k], j["ankles"][k]]
		pairs[FOOT + k] = [j["ankles"][k], j["toes"][k]]
	for w in 4:
		var pair := w / 2
		var k := w % 2
		var bone := (WING if pair == 0 else HIND) + k
		var tip := (WINGTIP if pair == 0 else HIND + 2) + k
		pairs[bone] = [j["wing_roots"][w], j["wing_mids"][w]]
		pairs[tip] = [j["wing_mids"][w], j["wing_tips"][w]]
	return pairs


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
		var side := torso.x if b < WING else torso.z
		out.append(Transform3D(_along((c - a) / maxf(length, 0.0001), side), a))
	return out


static func _along(y: Vector3, side: Vector3) -> Basis:
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


static func _bend(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var along := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3.UP
	return a + along * x + side * h


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
	var to_world := _model.global_transform * _frame
	var hands: Array = j["hands"]
	for i in 6:
		_hands[i] = to_world * ((j["ends"][i] as Vector3) + (hands[i] as Basis).y * HAND_LONG * 0.7)
	_head_at = to_world * (j["head_xform"] as Transform3D).origin
	_chest_at = to_world * p.chest


# --- Its voice ---

func _say(what: StringName) -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = sound(what)
	_voice.pitch_scale = _rng.randf_range(0.95, 1.05)
	_voice.play()


## Its sounds, made once and shared: `keen`, `twang` or `hum`.
static func sound(what: StringName) -> AudioStreamWAV:
	if _sounds.has(what):
		return _sounds[what]
	var made: AudioStreamWAV
	match what:
		&"keen":
			made = _keen_sound(2.2)
		&"twang":
			made = _pluck_sound(1.6, 82.0)
		&"hum":
			made = _hum_sound(2.0)
	_sounds[what] = made
	return made


## A thin, glassy whine that rises and wavers, like a wet finger round a glass.
static func _keen_sound(length: float) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var phase2 := 0.0
	for i in count:
		var t := float(i) / mix
		var k := t / length
		var pitch := 880.0 + 520.0 * smoothstep(0.0, 1.0, k) + 9.0 * sin(t * 31.0)
		phase += pitch / mix
		phase2 += pitch * 1.503 / mix
		var env := smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(0.8, 1.0, k))
		samples[i] = (sin(TAU * phase) * 0.7 + sin(TAU * phase2) * 0.25) * env
	return _wav(samples, mix, false)


## A deep string plucked (Karplus-Strong), ringing on.
static func _pluck_sound(length: float, pitch: float) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var period := int(mix / pitch)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var at := 0
	for i in count:
		var next := (at + 1) % period
		var value := (line[at] + line[next]) * 0.4985
		line[at] = value
		samples[i] = value
		at = next
	return _wav(samples, mix, false)


## The drone of its wings: a low, breathy, beating hum (looped).
static func _hum_sound(length: float) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	for i in count:
		var t := float(i) / mix
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.04)
		var beat := 0.6 + 0.4 * sin(TAU * t * 2.5)
		samples[i] = (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.5 * t) * 0.2 + low * 1.4) * beat
	return _wav(samples, mix, true)


static func _wav(samples: PackedFloat32Array, mix: int, looped: bool) -> AudioStreamWAV:
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 24000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = mix
	made.data = data
	if looped:
		made.loop_mode = AudioStreamWAV.LOOP_FORWARD
		made.loop_end = samples.size()
	return made
