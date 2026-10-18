class_name Harpy
extends Node3D
## A harpy: how it looks, moves and sounds, and nothing of what it thinks.
## Whatever drives it (a game's enemy script, the example) moves this node and
## says what it is doing; it poses itself from that.
##
## WHAT IT IS. The harpy of the old stories, starved: a gaunt woman's head and
## trunk (collarbones and ribs under ashen skin, a corded neck, a long skull
## with hollow eyes and a lipless mouth far too wide, lank wet hair hanging over
## most of the face), great ragged grey-black wings where her arms should be,
## built as a bird's are (ten primaries, the outer ones fingered, secondaries,
## coverts, an alula, and at each wrist three bony fingers with hooked claws),
## a bird's feathered belly, rump and ragged tail, feathered thighs, and bare
## scaly raptor legs with long hooked talons. Modelled in Blender
## (tools/build_harpy.py, models/harpy.glb), about 1.75 m standing and 4 m
## across the wings at `scale` 1; posed here, bone by bone, every frame.
##
## WHERE IT IS. Its origin is its middle (the belly), whatever it is doing. On
## a perch, put it `stand_height()` above the ledge (times its scale) and it
## sets its feet on it.
##
## WHAT IT DOES. Say so each frame; each blends in and out by itself:
## - `perched`: standing hunched on a ledge, head low between raised
##   shoulders, wings folded, or with `mantle` (0..1) half spread and draped
##   forward round it like a cloak; toes gripping.
## - flying (`perched` false): it beats its wings as a big bird does, after
##   slow-motion film of eagles and vultures. Downstroke: the wing straight and
##   spread, swept a little forward, the leading edge pressed down, the
##   primaries fanned apart into fingers and their tips bent up by the load.
##   Upstroke: the elbow and wrist bend so the wing folds half shut at the
##   wrist and is drawn up and back close to the body, the primaries closed
##   and turned edge on to let the air through, the hand trailing; at the top
##   it flicks open again. `effort` (0..1) is how hard: 0 is a glide (wings
##   held out, a little raised, the fingers spread and trembling), 1 beating
##   hard to climb. `brake` (0..1) turns the strokes forward and the body
##   upright, to hover or land. `stoop` (0..1) tucks the wings back for a
##   dive, wrists out, a teardrop. `talons` (0..1) throws the legs forward,
##   the toes open, the wings flared high: to land, or to strike.
##   Otherwise the legs trail under the tail, toes curled.
## - `grip` (0..1): the toes closed (on a perch, on what it has caught).
## - `screech()`: the head thrust out low, the jaw dropped open as far as it
##   goes, the wings flung up and half open, the body shuddering; with its
##   screech (made in code, 2 s). `cry()`: a shorter call, mouth open, as it
##   dives. `beat` is emitted at the top of every wingbeat (a wing sound plays).
## - `aim` (world, INF for none): what it looks at.
## It pitches and banks with how it is moved (its speed and turn, measured
## from frame to frame), and its hair hangs and streams in the wind it makes.
##
## `talon_points()` says where its talons are (world), for a game's catching.
##
## Cost: one skinned mesh (one draw, and its shadow). Near the camera the full
## model (about 56k triangles), beyond `lod_distance` a low one (about 20k); set
## `low_poly` for every harpy to use the low one (phones). It poses itself every
## frame: hide it, or set process_mode disabled, when it is far from everyone.

## The top of each wingbeat (the downstroke begins).
signal beat
## The screech goes out (at the top of `screech()`).
signal screeched

const MODEL := "res://creatures/harpy/models/harpy.glb"
## How far up from its feet its origin (its middle) is, on a perch, at scale 1.
const STAND_HEIGHT := 0.86
## Where in the model its origin is (its middle, at rest).
const PIVOT := Vector3(0.0, 1.0, -0.03)
const SCREECH_TIME := 2.0
const CRY_TIME := 0.9

## Primaries P1..P10: how far back of straight out each lies at rest, and folded shut (degrees).
const PRIMARY_REST: Array[float] = [80.0, 73.0, 65.0, 56.0, 46.0, 36.0, 27.0, 19.0, 12.0, 6.0]
const PRIMARY_SHUT: Array[float] = [16.0, 14.5, 13.0, 11.5, 10.0, 8.5, 7.0, 5.5, 4.0, 2.5]

## Every harpy uses the low model.
static var low_poly := false

## Make its sounds (a screech, a cry, wingbeats), from where it is.
@export var sound := true
@export var volume_db := 6.0
## How far off its sounds are heard.
@export var sound_range := 90.0
## Beyond this from the camera the low model is drawn.
@export var lod_distance := 22.0
## Each harpy's own small differences (the tone of its feathers, its timing).
@export var seed_value := 0

## On a perch (false: flying).
var perched := true
var mantle := 0.0
var effort := 0.5
var brake := 0.0
var stoop := 0.0
var talons := 0.0
var grip := 0.0
## What it looks at (world). INF: straight ahead (down, perched).
var aim := Vector3.INF
## How fast it is going: measured from how it is moved, or set it with `measure_velocity` off.
var velocity := Vector3.ZERO
var measure_velocity := true

var _model: Node3D
var _body: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _bone := {}
var _rest_local: Array[Basis] = []
var _rest_global: Array[Basis] = []
var _rest_global_inv: Array[Basis] = []
var _rest_origin: Array[Vector3] = []
var _rest_global_xf: Array[Transform3D] = []
## The tip of each toe's last joint, with its talon (skeleton space, at rest), by bone.
var _toe_tip := {}
var _primary_dir: Array[Vector3] = []
var _hair: Array[Dictionary] = []

var _w := {"perched": 1.0, "mantle": 0.0, "effort": 0.5, "brake": 0.0, "stoop": 0.0, "talons": 0.0, "grip": 0.0, "glide": 0.0}
var _phase := 0.0
var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _turn := 0.0
var _climb := 0.0
var _screech := INF
var _cry := INF
var _screeched := true
var _gaze := Vector3(0.0, -0.4, 1.0)
var _rng := RandomNumberGenerator.new()
var _voice: AudioStreamPlayer3D
var _call: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D
static var _screech_wav: AudioStreamWAV
static var _cry_wav: AudioStreamWAV
static var _beat_wav: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_model = (load(MODEL) as PackedScene).instantiate()
	_model.position = -PIVOT
	_body.add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = HarpyLook.material()
		mesh.set_instance_shader_parameter(&"tone", _rng.randf_range(0.9, 1.1))
		# (posed far from its rest: never culled by its rest box)
		mesh.custom_aabb = AABB(Vector3(-2.6, -1.2, -2.6), Vector3(5.2, 4.4, 5.2))
		_meshes.append(mesh)
	_set_lod()
	for i in _skeleton.get_bone_count():
		_bone[_skeleton.get_bone_name(i)] = i
		_rest_local.append(_skeleton.get_bone_rest(i).basis)
		var g := _skeleton.get_bone_global_rest(i)
		_rest_global.append(g.basis.orthonormalized())
		_rest_global_inv.append(g.basis.orthonormalized().inverse())
		_rest_origin.append(g.origin)
		_rest_global_xf.append(g)
	for side: String in ["_l", "_r"]:
		for t in 4:
			var b: int = _bone["toe%db%s" % [t + 1, side]]
			var a: int = _bone["toe%da%s" % [t + 1, side]]
			var along := _rest_origin[b] - _rest_origin[a]
			_toe_tip[b] = _rest_origin[b] + along.normalized() * (along.length() + 0.035) + Vector3.DOWN * 0.03
	for n in 10:
		var a := deg_to_rad(PRIMARY_REST[n])
		_primary_dir.append(Vector3(cos(a), 0.0, -sin(a)))
	for name: String in ["hair_f1", "hair_f2", "hair_b1", "hair_b2", "hair_l", "hair_r"]:
		var i: int = _bone[name]
		var kids := _skeleton.get_bone_children(i)
		var tip: Vector3 = _rest_origin[kids[0]] if kids.size() > 0 else _rest_origin[i] + Vector3(0.0, -0.24, 0.0)
		_hair.append({"bone": i, "rest": (tip - _rest_origin[i]).normalized(), "dir": Vector3.DOWN, "spin": Vector3.ZERO})
	if sound:
		_voice = _player(screech_sound(), volume_db)
		_call = _player(cry_sound(), volume_db - 2.0)
		_wings = _player(beat_sound(), volume_db - 6.0)
		_wings.max_distance = sound_range * 0.5
	settle()


func _player(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = db
	player.unit_size = 10.0
	player.max_distance = sound_range
	player.position = Vector3(0.0, 0.5, 0.1)
	add_child(player)
	return player


func _set_lod() -> void:
	for mesh in _meshes:
		var lo := String(mesh.name).ends_with("_lo")
		if low_poly:
			mesh.visible = lo
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = 0.0
		else:
			mesh.visible = true
			mesh.visibility_range_begin = lod_distance if lo else 0.0
			mesh.visibility_range_end = 0.0 if lo else lod_distance


## How far up from its feet its origin is when perched (world units at its scale).
func stand_height() -> float:
	return STAND_HEIGHT * global_basis.get_scale().y


## Stands it still in what it is told now, with nothing going on.
func settle() -> void:
	_was = global_position if is_inside_tree() else Vector3.INF
	_yaw_was = global_rotation.y if is_inside_tree() else 0.0
	_turn = 0.0
	_climb = 0.0
	_w["perched"] = 1.0 if perched else 0.0
	_w["mantle"] = mantle
	_w["effort"] = effort
	_w["brake"] = brake
	_w["stoop"] = stoop
	_w["talons"] = talons
	_w["grip"] = grip
	_screech = INF
	_cry = INF
	for h: Dictionary in _hair:
		h["dir"] = Vector3.DOWN
		h["spin"] = Vector3.ZERO
	if _skeleton:
		_pose(0.0)


## For pictures and tests: stops it posing itself (`frozen`), and poses it
## exactly: `state` holds any of perched, mantle, effort, brake, stoop, talons,
## grip (0..1); `phase` is where in the wingbeat (0 the top, the downstroke to
## 0.52); `call` how far through a screech, in seconds (INF: none).
var frozen := false


func hold(state: Dictionary, phase := 0.0, call := INF) -> void:
	for key: String in state:
		if _w.has(key):
			_w[key] = float(state[key])
	_phase = phase
	_screech = call
	velocity = state.get("velocity", Vector3.ZERO)
	if aim.is_finite():
		var local := global_transform.affine_inverse() * aim - Vector3(0.0, 0.6, 0.15)
		_gaze = local.normalized()
		_gaze.z = maxf(_gaze.z, 0.15)
		_gaze = _gaze.normalized()
	for h: Dictionary in _hair:
		h["dir"] = (Vector3.DOWN - velocity * 0.07).normalized()
		h["spin"] = Vector3.ZERO
	_pose(0.0)


## Screeches: the head thrust out, jaw dropped, wings flung up; `screeched` at the top of it.
func screech() -> void:
	_screech = 0.0
	_screeched = false
	if _voice:
		_voice.play()


## A shorter call, as it dives.
func cry() -> void:
	_cry = 0.0
	if _call:
		_call.play()


func screeching() -> bool:
	return _screech < SCREECH_TIME


## Where its talons are (world): the tips of each foot's four toes, hooks and all.
func talon_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for side: String in ["_l", "_r"]:
		for t in 4:
			var i: int = _bone["toe%db%s" % [t + 1, side]]
			out.append(_skeleton.global_transform * (_skeleton.get_bone_global_pose(i) * (_rest_global_xf[i].affine_inverse() * _toe_tip[i])))
	return out


## Where its head is (world), for whatever should see it.
func head_point() -> Vector3:
	var g := _skeleton.get_bone_global_pose(_bone["head"])
	return _skeleton.global_transform * (g.origin + g.basis.orthonormalized() * (_rest_global_inv[_bone["head"]] * Vector3(0.0, 0.06, 0.04)))


func _process(delta: float) -> void:
	if delta <= 0.0 or frozen:
		return
	_t += delta
	var at := global_position
	if not _was.is_finite():
		_was = at
		_yaw_was = global_rotation.y
	if measure_velocity:
		var moved := (at - _was) / delta
		velocity = velocity.lerp(moved, 1.0 - exp(-10.0 * delta))
	var yaw := global_rotation.y
	_turn = lerpf(_turn, wrapf(yaw - _yaw_was, -PI, PI) / delta, 1.0 - exp(-4.0 * delta))
	_was = at
	_yaw_was = yaw
	var speed := velocity.length()
	_climb = lerpf(_climb, atan2(velocity.y, maxf(Vector2(velocity.x, velocity.z).length(), 0.5)) if speed > 1.0 else 0.0, 1.0 - exp(-5.0 * delta))
	# What it has been told, blended in.
	var rate := 1.0 - exp(-5.0 * delta)
	_w["perched"] = lerpf(_w["perched"], 1.0 if perched else 0.0, 1.0 - exp(-4.0 * delta))
	_w["mantle"] = lerpf(_w["mantle"], mantle, rate * 0.6)
	_w["effort"] = lerpf(_w["effort"], effort, rate)
	_w["brake"] = lerpf(_w["brake"], brake, rate)
	_w["stoop"] = lerpf(_w["stoop"], stoop, 1.0 - exp(-6.0 * delta))
	_w["talons"] = lerpf(_w["talons"], talons, 1.0 - exp(-8.0 * delta))
	_w["grip"] = lerpf(_w["grip"], grip, 1.0 - exp(-10.0 * delta))
	# The wingbeat: slow and deep for a bird this size, quicker for hard work and braking.
	var flapping: float = (1.0 - _w["perched"]) * (1.0 - _w["stoop"])
	var hz: float = lerpf(1.5, 2.3, _w["effort"]) + _w["brake"] * 0.6
	if flapping > 0.02 and (_w["effort"] > 0.05 or _w["brake"] > 0.1):
		var before := _phase
		_phase = fposmod(_phase + hz * delta, 1.0)
		if _phase < before:
			beat.emit()
			if _wings and _w["effort"] + _w["brake"] > 0.35:
				_wings.pitch_scale = _rng.randf_range(0.9, 1.1)
				_wings.play()
	elif _phase > 0.0:
		# (gliding: the wings come to rest held out)
		_phase = move_toward(_phase, 0.0 if _phase < 0.5 else 1.0, delta * 0.5)
		if _phase >= 1.0:
			_phase = 0.0
	if _screech < INF:
		_screech += delta
		if not _screeched and _screech > 0.35:
			_screeched = true
			screeched.emit()
		if _screech > SCREECH_TIME + 1.0:
			_screech = INF
	if _cry < INF:
		_cry += delta
		if _cry > CRY_TIME + 1.0:
			_cry = INF
	# Where it looks.
	var want: Vector3 = Vector3(0.0, -0.45, 1.0) if _w["perched"] > 0.5 else Vector3(0.0, -0.15, 1.0)
	if aim.is_finite():
		var local := global_transform.affine_inverse() * aim
		local -= Vector3(0.0, 0.6, 0.15)
		if local.length() > 0.3:
			want = local.normalized()
			# (it cannot turn its head right round)
			want.z = maxf(want.z, 0.15)
	_gaze = _gaze.slerp(want.normalized(), 1.0 - exp(-4.0 * delta)).normalized()
	_pose(delta)


# --- Poses ---

## One wing's pose, as angles (radians), as a bird's wing: in a frame where the
## body runs level (forward +Z, the tail -Z), the left wing out along +X, its
## top +Y; the right wing is its mirror. That frame is tipped onto her upright
## trunk by `tilt` (see _pose_wing): level with the world in flight, along her
## back on a perch.
class Wing:
	## The upper arm: up (+) and down, forward (+) and back, leading edge down (+, pronation).
	var elev := 0.0
	var sweep := 0.0
	var pitch := 0.0
	## Folding: the forearm at the elbow, the hand at the wrist; the hand's tip up (+).
	var elbow := 0.0
	var wrist := 0.0
	var lift := 0.0
	## The primaries: 0 shut together, 1 as at rest, more fanned into fingers; turned edge on (+).
	var spread := 1.0
	var feather_twist := 0.0
	## The shoulder raised (+) and brought forward (+).
	var shrug := 0.0
	var reach := 0.0
	## The whole wing, folded as it is, turned down (-) about the body's length
	## from the shoulder: to lay a folded wing against the flank, or drape it.
	var roll := 0.0

	func _init(e := 0.0, s := 0.0, p := 0.0, el := 0.0, w := 0.0, l := 0.0, sp := 1.0, ft := 0.0, sh := 0.0, re := 0.0, ro := 0.0) -> void:
		elev = e
		sweep = s
		pitch = p
		elbow = el
		wrist = w
		lift = l
		spread = sp
		feather_twist = ft
		shrug = sh
		reach = re
		roll = ro

	func mixed(other: Wing, t: float) -> Wing:
		if t <= 0.0:
			return self
		if t >= 1.0:
			return other
		return Wing.new(lerpf(elev, other.elev, t), lerpf(sweep, other.sweep, t), lerpf(pitch, other.pitch, t), lerpf(elbow, other.elbow, t),
			lerpf(wrist, other.wrist, t), lerpf(lift, other.lift, t), lerpf(spread, other.spread, t), lerpf(feather_twist, other.feather_twist, t),
			lerpf(shrug, other.shrug, t), lerpf(reach, other.reach, t), lerpf(roll, other.roll, t))


## The body: how it leans, its spine, neck and head, jaw; its legs and tail.
class Frame:
	var pitch := 0.0  # the whole body tipped forward (+)
	var roll := 0.0
	var lift := 0.0
	var spine := 0.0  # hunched forward (+)
	var neck := 0.0  # bent down (+)
	var head := 0.0  # nodded down (+)
	var jaw := 0.0
	var thigh := 0.0  # swung forward (+)
	var knee := 0.0  # shin swung back (+)
	var ankle := 0.0  # tarsus swung forward (+)
	var curl := 0.0  # toes closed (+)
	var open := 0.0  # toes spread wide
	var tail := 0.0  # raised (+)
	var fan := 0.0  # tail spread
	var crouch := 0.0

	func mixed(other: Frame, t: float) -> Frame:
		if t <= 0.0:
			return self
		if t >= 1.0:
			return other
		var f := Frame.new()
		for key: String in ["pitch", "roll", "lift", "spine", "neck", "head", "jaw", "thigh", "knee", "ankle", "curl", "open", "tail", "fan", "crouch"]:
			f.set(key, lerpf(get(key), other.get(key), t))
		return f


static func _d(degrees: float) -> float:
	return deg_to_rad(degrees)


## The wing at a point of the wingbeat (`phase`: 0 the top, the downstroke to DOWN, then the upstroke).
const DOWN := 0.52


func _flap(phase: float, strength: float, braking: float) -> Wing:
	var top := lerpf(28.0, 66.0, strength) + braking * 6.0
	var bottom := lerpf(-12.0, -48.0, strength) - braking * 4.0
	var w := Wing.new()
	if phase < DOWN:
		var u := phase / DOWN
		var e := 0.5 - 0.5 * cos(PI * u)
		var mid := sin(PI * u)
		w.elev = _d(lerpf(top, bottom, e))
		w.sweep = _d(8.0 + 10.0 * mid + braking * 32.0)
		w.pitch = _d(6.0 + 14.0 * mid * strength - braking * 22.0)
		w.elbow = _d(5.0 + braking * 14.0)
		w.wrist = _d(3.0 + braking * 8.0)
		# (the tips bent up by the load, most in the middle of the stroke)
		w.lift = _d(-6.0 + 22.0 * mid * strength)
		w.spread = 1.15 + 0.2 * strength
		w.feather_twist = _d(-6.0 * mid)
	else:
		var u := (phase - DOWN) / (1.0 - DOWN)
		var e := 0.5 - 0.5 * cos(PI * u)
		var mid := sin(PI * u)
		w.elev = _d(lerpf(bottom, top, e))
		w.sweep = _d(lerpf(8.0, -16.0, mid) + braking * 18.0)
		w.pitch = _d(-24.0 * mid * (0.4 + 0.6 * strength) - braking * 10.0)
		# Folded half shut at the wrist, the hand trailing, then flicked open at the top.
		var fold := mid * (1.0 - smoothstep(0.78, 1.0, u)) + (1.0 - smoothstep(0.0, 0.12, u)) * 0.0
		w.elbow = _d(5.0 + 62.0 * fold * (0.55 + 0.45 * strength))
		w.wrist = _d(3.0 + 95.0 * fold * (0.55 + 0.45 * strength))
		w.lift = _d(-30.0 * mid + 18.0 * smoothstep(0.7, 1.0, u))
		w.spread = lerpf(0.25, 1.2, smoothstep(0.72, 1.0, u)) if u > 0.3 else lerpf(1.2, 0.25, smoothstep(0.0, 0.3, u))
		w.feather_twist = _d(55.0 * mid)
	w.shrug = _d(4.0 * sin(TAU * phase))
	return w


func _glide() -> Wing:
	var tremble := sin(_t * 23.0 + seed_value) * 0.5 + sin(_t * 31.0) * 0.5
	return Wing.new(_d(9.0), _d(3.0), _d(4.0), _d(6.0), _d(4.0), _d(7.0 + tremble * 2.0), 1.1 + tremble * 0.04, _d(tremble * 3.0))


func _stooped() -> Wing:
	return Wing.new(_d(14.0), _d(-38.0), _d(14.0), _d(62.0), _d(82.0), _d(-6.0), 0.15, 0.0, _d(6.0))


func _folded() -> Wing:
	return Wing.new(_d(4.0), _d(-92.0), _d(0.0), _d(150.0), _d(160.0), _d(0.0), 0.0, 0.0, _d(10.0), 0.0, _d(-74.0))


func _mantled() -> Wing:
	return Wing.new(_d(18.0), _d(34.0), _d(-14.0), _d(62.0), _d(74.0), _d(-24.0), 0.6, _d(10.0), _d(26.0), _d(14.0), _d(-42.0))


func _flared() -> Wing:
	return Wing.new(_d(58.0), _d(-4.0), _d(-34.0), _d(22.0), _d(18.0), _d(14.0), 1.35, _d(-10.0), _d(8.0))


func _display() -> Wing:
	return Wing.new(_d(48.0), _d(14.0), _d(-12.0), _d(42.0), _d(36.0), _d(18.0), 1.3, 0.0, _d(20.0))


func _pose(_delta: float) -> void:
	var perch: float = _w["perched"]
	var shudder := 0.0
	var screech_w := 0.0
	if _screech < INF:
		screech_w = smoothstep(0.0, 0.3, _screech) * (1.0 - smoothstep(SCREECH_TIME - 0.3, SCREECH_TIME + 0.2, _screech))
		shudder = sin(_screech * 47.0) * 0.5 + sin(_screech * 71.0) * 0.5
	var cry_w := 0.0
	if _cry < INF:
		cry_w = smoothstep(0.0, 0.15, _cry) * (1.0 - smoothstep(CRY_TIME - 0.2, CRY_TIME, _cry))

	# --- The wings ---
	var air := _flap(_phase, _w["effort"], _w["brake"])
	var flapping: float = clampf(maxf(_w["effort"] * 3.0, _w["brake"] * 3.0), 0.0, 1.0)
	var wing := _glide().mixed(air, flapping)
	wing = wing.mixed(_stooped(), _w["stoop"])
	wing = wing.mixed(_flared(), _w["talons"] * (1.0 - _w["stoop"]) * 0.85)
	var sat := _folded().mixed(_mantled(), _w["mantle"])
	# (on a perch, now and then a shiver through the feathers)
	sat.lift += sin(_t * 0.7 + seed_value) * 0.03
	wing = wing.mixed(sat, perch)
	wing = wing.mixed(_display(), screech_w)
	# Banked into turns: the outer wing a little higher.
	var bank := clampf(-_turn * 0.18, -0.6, 0.6) * (1.0 - perch)

	# --- The body ---
	var fly := Frame.new()
	var horizontal := clampf(Vector2(velocity.x, velocity.z).length() / 6.0, 0.0, 1.0)
	fly.pitch = _d(lerpf(55.0, 78.0, horizontal)) - _climb * 0.6
	fly.roll = bank
	fly.spine = _d(-6.0)
	fly.neck = _d(-38.0)
	fly.head = _d(-22.0)
	fly.thigh = _d(8.0)
	fly.knee = _d(14.0)
	fly.ankle = _d(-10.0)
	fly.curl = 0.9
	fly.tail = _d(-72.0)
	fly.fan = _d(4.0) + absf(bank) * 0.4
	var braking := Frame.new()
	braking.pitch = _d(18.0)
	braking.spine = _d(4.0)
	braking.neck = _d(-6.0)
	braking.head = _d(6.0)
	braking.thigh = _d(40.0)
	braking.knee = _d(20.0)
	braking.ankle = _d(30.0)
	braking.open = 0.4
	braking.tail = _d(-55.0)
	braking.fan = _d(22.0)
	var diving := Frame.new()
	diving.pitch = _d(84.0) - _climb * 0.5
	diving.neck = _d(-48.0)
	diving.head = _d(-20.0)
	diving.thigh = _d(2.0)
	diving.knee = _d(18.0)
	diving.ankle = _d(-14.0)
	diving.curl = 1.0
	diving.tail = _d(-80.0)
	var striking := Frame.new()
	striking.pitch = _d(28.0)
	striking.spine = _d(-14.0)
	striking.neck = _d(-30.0)
	striking.head = _d(-10.0)
	striking.jaw = 0.75
	striking.thigh = _d(85.0)
	striking.knee = _d(-10.0)
	striking.ankle = _d(55.0)
	striking.open = 1.0
	striking.tail = _d(-45.0)
	striking.fan = _d(26.0)
	var body := fly.mixed(braking, _w["brake"])
	body = body.mixed(diving, _w["stoop"])
	body = body.mixed(striking, _w["talons"])
	var sit := Frame.new()
	sit.pitch = _d(30.0 + 4.0 * sin(_t * 1.3))
	sit.spine = _d(22.0)
	sit.neck = _d(18.0)
	sit.head = _d(8.0)
	sit.thigh = _d(32.0)
	sit.knee = _d(46.0)
	sit.ankle = _d(26.0)
	sit.curl = 0.75
	sit.tail = _d(-62.0)
	sit.crouch = 1.0
	sit.lift = 0.012 * sin(_t * 1.3)
	body = body.mixed(sit, perch)
	body.curl = maxf(body.curl, _w["grip"]) * (1.0 - body.open)
	var call := maxf(screech_w, cry_w)
	if call > 0.0:
		body.spine -= _d(6.0) * screech_w
		body.neck += _d(14.0) * screech_w - _d(8.0) * cry_w
		body.head -= _d(46.0) * screech_w + _d(10.0) * cry_w
		body.jaw = maxf(body.jaw, call * (0.92 + 0.08 * shudder))
		body.roll += shudder * _d(2.5) * screech_w

	# --- Onto the skeleton ---
	_body.basis = Basis(Vector3.FORWARD, body.roll) * Basis(Vector3.RIGHT, body.pitch)
	_body.position = Vector3(0.0, body.lift, 0.0)
	_turn_bone("spine", Basis(Vector3.RIGHT, body.spine * 0.45))
	_turn_bone("chest", Basis(Vector3.RIGHT, body.spine * 0.55))
	# The gaze: the head turns and nods to it, on top of the pose.
	var gaze_yaw := atan2(_gaze.x, _gaze.z)
	var gaze_pitch := -asin(clampf(_gaze.y, -1.0, 1.0))
	var level := body.pitch + body.spine + body.neck + body.head
	var nod := clampf(gaze_pitch - level, -0.9, 0.9) * (1.0 - call * 0.3)
	_turn_bone("neck", Basis(Vector3.UP, gaze_yaw * 0.45) * Basis(Vector3.RIGHT, body.neck + nod * 0.4))
	_turn_bone("head", Basis(Vector3.UP, gaze_yaw * 0.55) * Basis(Vector3.RIGHT, body.head + nod * 0.6) * Basis(Vector3.BACK, shudder * 0.05 * screech_w))
	_turn_bone("jaw", Basis(Vector3.RIGHT, body.jaw * 0.95))
	# The bird's frame the wings are posed in: level with the world in flight,
	# down her back on a perch, between for the screech.
	var wing_tilt := lerpf(body.pitch + body.spine, _d(84.0), perch)
	wing_tilt = lerpf(wing_tilt, _d(62.0), screech_w * perch)
	for side in [1.0, -1.0]:
		var w := wing
		if side > 0.0:
			w = Wing.new(wing.elev + bank * 0.5, wing.sweep, wing.pitch, wing.elbow, wing.wrist, wing.lift, wing.spread, wing.feather_twist, wing.shrug, wing.reach, wing.roll)
		else:
			w = Wing.new(wing.elev - bank * 0.5, wing.sweep, wing.pitch, wing.elbow, wing.wrist, wing.lift, wing.spread, wing.feather_twist, wing.shrug, wing.reach, wing.roll)
		_pose_wing(w, side, wing_tilt)
		_pose_leg(body, side)
	_turn_bone("tail", Basis(Vector3.RIGHT, body.tail))
	_turn_bone("tail_l", Basis(Vector3.UP, -body.fan))
	_turn_bone("tail_r", Basis(Vector3.UP, body.fan))
	_hang_hair(_delta)
	if perch > 0.01:
		_ground(perch)


func _pose_wing(w: Wing, side: float, tilt: float) -> void:
	var s := "_l" if side > 0.0 else "_r"
	_turn_bone("clavicle" + s, Basis(Vector3.UP, -w.reach) * Basis(Vector3.BACK, w.shrug), side)
	_turn_bone("humerus" + s, Basis(Vector3.RIGHT, -tilt) * Basis(Vector3.BACK, w.roll) * Basis(Vector3.UP, -w.sweep) * Basis(Vector3.BACK, w.elev) * Basis(Vector3.RIGHT, w.pitch), side)
	_turn_bone("forearm" + s, Basis(Vector3.UP, -w.elbow), side)
	_turn_bone("hand" + s, Basis(Vector3.UP, w.wrist) * Basis(Vector3.BACK, w.lift), side)
	_turn_bone("finger" + s, Basis(Vector3.BACK, w.lift * 0.5), side)
	# The secondaries keep lying back along the body as the forearm folds forward.
	var back := clampf((w.elbow + w.sweep) * 0.85, -0.3, 1.4)
	for k in 4:
		_turn_bone("sec%d%s" % [k + 1, s], Basis(Vector3.UP, back * (0.7 + 0.1 * k) + (w.spread - 1.0) * 0.05 * (k - 1.5)), side)
	# The primaries, fanned or shut, turned edge on in the upstroke.
	for n in 10:
		var rest := PRIMARY_REST[n]
		var angle := 0.0
		if w.spread < 1.0:
			angle = lerpf(PRIMARY_SHUT[n], rest, w.spread)
		else:
			# (fanned wider: the outer ones apart into fingers)
			angle = rest + (w.spread - 1.0) * (float(n) - 4.5) * -3.2
		var turn := Basis(Vector3.UP, _d(angle - rest))
		var twist := Basis(_primary_dir[n], w.feather_twist * (0.4 + 0.06 * n))
		_turn_bone("p%d%s" % [n + 1, s], twist * turn, side)
	_turn_bone("claws" + s, Basis(Vector3.BACK, -0.4 + 0.4 * w.spread) * Basis(Vector3.UP, 0.2), side)


func _pose_leg(body: Frame, side: float) -> void:
	var s := "_l" if side > 0.0 else "_r"
	_turn_bone("thigh" + s, Basis(Vector3.RIGHT, -body.thigh) * Basis(Vector3.BACK, _d(4.0) + body.open * _d(10.0)), side)
	_turn_bone("shin" + s, Basis(Vector3.RIGHT, body.knee), side)
	_turn_bone("tarsus" + s, Basis(Vector3.RIGHT, -body.ankle), side)
	var curl := body.curl
	var open := body.open
	for t in 4:
		var n := t + 1
		var a := "toe%da%s" % [n, s]
		var b := "toe%db%s" % [n, s]
		if n == 1:
			_turn_bone(a, Basis(Vector3.RIGHT, -curl * 0.7 + open * 0.5), side)
			_turn_bone(b, Basis(Vector3.RIGHT, -curl * 1.0 + open * 0.2), side)
		else:
			var splay := (0.0 if n == 3 else (-1.0 if n == 2 else 1.0)) * open * 0.35
			_turn_bone(a, Basis(Vector3.UP, splay) * Basis(Vector3.RIGHT, curl * 0.6 - open * 0.45), side)
			_turn_bone(b, Basis(Vector3.RIGHT, curl * 1.05 - open * 0.15), side)


## Turns a bone by `q`, a rotation in the model's frame at rest (on the left side, mirrored for the right), on its parent.
func _turn_bone(name: String, q: Basis, side := 1.0) -> void:
	var i: int = _bone.get(name, -1)
	if i < 0:
		return
	if side < 0.0:
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		q = m * q * m
	var local := _rest_local[i] * (_rest_global_inv[i] * q * _rest_global[i])
	_skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())


## On a perch: the body lowered or raised so that its feet stand where they should.
func _ground(weight: float) -> void:
	var lowest := INF
	for side: String in ["_l", "_r"]:
		var g := _skeleton.get_bone_global_pose(_bone["toe3a" + side])
		lowest = minf(lowest, to_local(_skeleton.global_transform * g.origin).y)
	if lowest < INF:
		_body.position.y += (-STAND_HEIGHT + 0.035 - lowest) * weight


## The hair hangs under gravity and streams back in the wind of its flight, swinging a little after the head.
func _hang_hair(delta: float) -> void:
	var to_skeleton := (_skeleton.global_basis).inverse()
	var wind := -velocity * 0.07
	for h: Dictionary in _hair:
		var i: int = h["bone"]
		var want := (Vector3.DOWN + wind + Vector3(sin(_t * 1.7 + i) * 0.05, 0.0, cos(_t * 1.3 + i) * 0.05)).normalized()
		var dir: Vector3 = h["dir"]
		var spin: Vector3 = h["spin"]
		if delta > 0.0:
			spin += (want - dir) * 60.0 * delta
			spin *= exp(-7.0 * delta)
			dir = (dir + spin * delta).normalized()
		else:
			dir = want
		h["dir"] = dir
		h["spin"] = spin
		var parent := _skeleton.get_bone_parent(i)
		var pose := _skeleton.get_bone_global_pose(parent).basis.orthonormalized()
		var target := (pose * _rest_global_inv[parent]).inverse() * (to_skeleton * dir)
		var rest: Vector3 = h["rest"]
		target = target.normalized()
		# (no further than this from how it hangs at rest: it is not to go through her face)
		var most := 0.9
		var angle := rest.angle_to(target)
		if angle > most:
			target = rest.slerp(target, most / angle)
		var axis := rest.cross(target)
		var q := Basis.IDENTITY
		if axis.length() > 0.0001:
			q = Basis(axis.normalized(), rest.angle_to(target))
		_skeleton.set_bone_pose_rotation(i, (_rest_local[i] * (_rest_global_inv[i] * q * _rest_global[i])).get_rotation_quaternion())


# --- Sound (made in code: nothing to load) ---

## The screech: a woman's scream and a raptor's in one throat. A rasping
## breath in; then a high, strained voice (jittered glottal pulses through the
## resonances of a shrill "ee-ah", as much breath as voice) that cracks
## upwards as it starts, wavers, and is chopped into a raptor's stuttering
## "kek-kek" as it goes on; under it all a wet rattle in the throat, and at the
## end the voice gives out into it. 2 s.
static func screech_sound() -> AudioStreamWAV:
	if _screech_wav:
		return _screech_wav
	var rate := 22050
	var length := 2.0
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var samples := PackedFloat32Array()
	samples.resize(count)
	var formants: Array[Band] = [Band.new(700.0, 5.0, rate), Band.new(1900.0, 6.0, rate), Band.new(3100.0, 7.0, rate), Band.new(4200.0, 6.0, rate)]
	var gains := [1.0, 0.85, 0.55, 0.3]
	var breath := Band.new(3600.0, 1.0, rate)
	var rasp := Band.new(1800.0, 1.5, rate)
	var phase := 0.0
	var low_phase := 0.0
	var wander := 0.0
	var pulse_gain := 1.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		# The breath in: a dry rasp through the teeth.
		if t < 0.32:
			var air := sin(PI * clampf(t / 0.3, 0.0, 1.0)) * 0.5
			rasp.set_frequency(1500.0 + 2500.0 * t / 0.32, 1.6)
			value += rasp.run(rng.randf_range(-1.0, 1.0)) * air
		var voice_in := smoothstep(0.3, 0.36, t) * (1.0 - smoothstep(1.55, 1.8, t))
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := 820.0 + 380.0 * smoothstep(0.3, 0.42, t) - 260.0 * smoothstep(1.1, 1.75, t)
		# (it cracks up as it starts, and again)
		if t > 0.36 and t < 0.47:
			pitch *= 1.45
		if t > 0.93 and t < 1.0:
			pitch *= 1.3
		pitch *= 1.0 + 0.06 * wander + 0.035 * sin(t * TAU * 6.5)
		var before := phase
		phase += pitch / rate * (1.0 + rng.randf_range(-0.04, 0.04))
		if floorf(phase) != floorf(before):
			pulse_gain = rng.randf_range(0.7, 1.05)
		var p := fposmod(phase, 1.0)
		var pulse := (pow(1.0 - p, 5.0) * 2.0 - 0.33) * pulse_gain
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var noise := breath.run(rng.randf_range(-1.0, 1.0))
		# The raptor in it: chopped into a stutter, faster and harder as it goes.
		var kek_rate := lerpf(9.0, 15.0, smoothstep(0.7, 1.5, t))
		var kek := 1.0 - smoothstep(0.75, 1.1, t) * (0.5 + 0.5 * pow(maxf(0.0, sin(t * TAU * kek_rate)), 0.4)) * 0.85
		value += (throat * 2.4 + noise * 1.1) * voice_in * kek
		# The rattle under it, and at the end alone.
		var rattle := smoothstep(0.32, 0.5, t) * 0.35 + smoothstep(1.5, 1.75, t) * 0.65
		rattle *= 1.0 - smoothstep(1.85, length, t)
		var low_hz := lerpf(70.0, 26.0, smoothstep(1.5, length, t))
		var low_before := low_phase
		low_phase += low_hz / rate * (1.0 + rng.randf_range(-0.1, 0.1))
		var click := 0.0
		if floorf(low_phase) != floorf(low_before):
			click = rng.randf_range(0.6, 1.0)
		value += rasp.run(click * 6.0 + rng.randf_range(-0.2, 0.2)) * rattle
		value = tanh(value * 2.6)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_screech_wav = _wav(samples, loudest, rate)
	return _screech_wav


## The dive call: a high scream falling away, ragged and breathy, 0.9 s.
static func cry_sound() -> AudioStreamWAV:
	if _cry_wav:
		return _cry_wav
	var rate := 22050
	var length := 0.9
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var samples := PackedFloat32Array()
	samples.resize(count)
	var formants: Array[Band] = [Band.new(800.0, 5.0, rate), Band.new(2300.0, 6.0, rate), Band.new(3300.0, 7.0, rate)]
	var breath := Band.new(4000.0, 1.0, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.5, length, t))
		var pitch := lerpf(1500.0, 620.0, pow(t / length, 0.7)) * (1.0 + 0.05 * sin(t * TAU * 11.0) + rng.randf_range(-0.03, 0.03))
		phase += pitch / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 5.0) * 2.0 - 0.33
		var throat := formants[0].run(pulse) + formants[1].run(pulse) * 0.9 + formants[2].run(pulse) * 0.5
		var value := (throat * 2.5 + breath.run(rng.randf_range(-1.0, 1.0)) * 1.3) * env
		value = tanh(value * 2.4)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_cry_wav = _wav(samples, loudest, rate)
	return _cry_wav


## A wingbeat: the air thumped down by a great wing, a soft heavy whump with the rustle of feathers on it.
static func beat_sound() -> AudioStreamWAV:
	if _beat_wav:
		return _beat_wav
	var rate := 22050
	var length := 0.35
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples := PackedFloat32Array()
	samples.resize(count)
	var thump := Band.new(140.0, 0.8, rate)
	var rustle := Band.new(2600.0, 0.9, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.04, t) * exp(-t * 11.0)
		var n := rng.randf_range(-1.0, 1.0)
		var value := thump.run(n) * 5.0 * env + rustle.run(n) * 0.5 * env * (0.6 + 0.4 * sin(t * 260.0))
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_beat_wav = _wav(samples, loudest, rate)
	return _beat_wav


static func _wav(samples: PackedFloat32Array, loudest: float, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _rate := 22050
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
		set_frequency(frequency, q)

	func set_frequency(frequency: float, q: float) -> void:
		var w := TAU * frequency / _rate
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
