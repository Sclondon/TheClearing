class_name Griffinfly
extends Node3D
## A griffinfly: how it looks, flies and sounds, and nothing of what it thinks.
## Whatever drives it (a game's enemy script, the example) moves this node and
## says what it is doing; it poses itself from that.
##
## WHAT IT IS. A Meganeura, the giant dragonfly-like hunter of the coal forests,
## made bigger still (`wingspan`, 1.2 m by default): two huge faceted eyes all
## but meeting over a small face, toothed jaws, a great slanted thorax, six
## spiny legs held forward under the head as a basket to take prey in the air,
## a long abdomen of ten segments ending in two cerci, and four long, narrow,
## smoky wings in a dense net of veins (GriffinflyLook, tools/build_griffinfly.py).
##
## WHERE IT IS. Its origin is its middle (the thorax, where the wings are). Turn
## the node about Y to say which way it heads; it pitches and banks itself with
## how it is moved (measured from frame to frame).
##
## WHAT IT DOES. Say so each frame; each blends in and out by itself:
## - flying (`perched` false): its four wings beat each on its own, as an
##   odonate's do, each from its own muscles: hovering, the fore and hind pairs
##   beat against each other (half a beat apart); going fast, the hind pair
##   leads by a quarter; each wing twists on its stroke (its leading edge down
##   going down, up going up); turning, the wings on the outside of the turn
##   beat wider. `effort` (0..1): 0 a glide on wings held out flat and still, 1
##   beating hard (hovering, darting, climbing). Darting it dips its nose, braking
##   it lifts it and the abdomen with it; turning, it banks and its abdomen swings out.
## - `basket` (0..1): the legs thrown forward and open under the head, to take
##   something (its strike). `jaws` (0..1): the mandibles open; `snap()` opens
##   and closes them at once, with a click.
## - `perched`: resting on `surface` (the way out of it, world: up for the
##   ground, out of a wall for a wall; it rests head up on a wall), wings held
##   out flat, legs gripping, the abdomen down along the surface.
## - `aim` (world, INF for none): what its head turns to (it looks into its turns otherwise).
## - `rattle` (0..1): its wings clatter louder (when it is about to strike).
##
## `basket_point()` (world): where its legs' basket is, for a game's striking.
##
## SOUND (made in code): the papery clatter of its wingbeats, louder and higher
## the harder it beats, with `rattle` on top; a click of the jaws on `snap()`.
##
## COST: one mesh, posed entirely in its shader (one draw, and its shadow), and
## a dozen uniforms set a frame. Near the camera the full model (about 4,900
## triangles), beyond `detail_range` the low one (about 1,300); `low_poly` (or
## `force_low`) for the low one always (phones). Hidden, it does nothing.

## Every griffinfly uses the low model.
static var low_poly := false

## Wing tip to wing tip, metres.
@export var wingspan := 1.2
## Its own small differences (its shade, its timing).
@export var seed_value := 0
@export var force_low := false
## Nearer the camera than this, the full model.
@export var detail_range := 24.0
## Wingbeats a second, beating hard.
@export var flap_rate := 13.0
@export var sound := true
@export var volume_db := -14.0
@export var sound_range := 36.0

var effort := 1.0
var basket := 0.0
var jaws := 0.0
var perched := false
var surface := Vector3.UP
var aim := Vector3.INF
var rattle := 0.0
## How fast it is going (measured from how it is moved).
var velocity := Vector3.ZERO

var _body: Node3D
var _meshes: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _turn := 0.0
var _accel := Vector3.ZERO
var _w := {"perched": 0.0, "effort": 1.0, "basket": 0.0, "jaws": 0.0, "pitch": 0.0, "bank": 0.0, "curl": 0.1, "sway": 0.0, "head_yaw": 0.0, "head_pitch": 0.0, "hover": 1.0, "rattle": 0.0}
# Each wing's own small differences of timing and stroke (right fore, left fore, right hind, left hind).
var _wing_lag := Vector4.ZERO
var _wing_jitter := Vector4.ZERO
var _snap := 0.0
var _skipped := 0.0
var _far := false
var _far_check := 0.0
var _wings: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
static var _clatter_wav: AudioStreamWAV
static var _click_wav: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_body = Node3D.new()
	_body.name = "Body"
	_body.scale = Vector3.ONE * wingspan
	add_child(_body)
	_material = GriffinflyLook.material(_rng.randf())
	var low := low_poly or force_low
	for detailed: bool in ([false] if low else [true, false]):
		var piece := MeshInstance3D.new()
		piece.name = "Detailed" if detailed else "Plain"
		piece.mesh = GriffinflyLook.mesh(not detailed)
		piece.material_override = _material
		if not low:
			if detailed:
				piece.visibility_range_end = detail_range
			else:
				piece.visibility_range_begin = detail_range
		# (its wings and legs move in the shader, beyond the model's own box)
		piece.extra_cull_margin = 0.6
		_body.add_child(piece)
		_meshes.append(piece)
	_phase = _rng.randf()
	_wing_lag = Vector4(0.0, _rng.randf_range(-0.03, 0.03), 0.0, _rng.randf_range(-0.03, 0.03))
	_wing_jitter = Vector4(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
	if sound:
		_wings = _player(clatter_sound(), volume_db)
		_click = _player(click_sound(), volume_db + 4.0)
	settle()


func _player(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = db
	player.unit_size = 2.5
	player.max_distance = sound_range
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player


## Puts it straight into the pose it is told (no easing in), where it is now.
func settle() -> void:
	_was = global_position if is_inside_tree() else position
	_yaw_was = rotation.y
	velocity = Vector3.ZERO
	_accel = Vector3.ZERO
	_w["perched"] = 1.0 if perched else 0.0
	_w["effort"] = effort
	_w["basket"] = basket
	_w["jaws"] = jaws
	_w["rattle"] = rattle
	_w["pitch"] = 0.0
	_w["bank"] = 0.0
	if is_inside_tree():
		_pose(0.0)


## Opens its jaws and snaps them shut, with a click (taking something).
func snap() -> void:
	_snap = 0.28
	if _click and is_inside_tree():
		_click.pitch_scale = _rng.randf_range(0.9, 1.1)
		_click.play()


## Where its basket of legs is (world): what it takes prey with.
func basket_point() -> Vector3:
	return _body.global_transform * GriffinflyLook.BASKET if _body else global_position


## Where its head is (world).
func head_point() -> Vector3:
	return _body.global_transform * (GriffinflyLook.NECK + Vector3(0.0, 0.0, 0.03)) if _body else global_position


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		if _wings and _wings.playing:
			_wings.stop()
		return
	# (far from the camera, posed at half the rate: nobody can tell)
	_skipped += delta
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var camera := get_viewport().get_camera_3d()
		_far = camera != null and camera.global_position.distance_to(global_position) > detail_range
	if _far and Engine.get_process_frames() % 2 == 0:
		return
	_pose(_skipped)
	_skipped = 0.0


func _pose(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	_t += dt
	# How it is moving, from how it was moved (smoothed: a game may move it in steps).
	var here := global_position
	if dt > 0.0 and _was.is_finite():
		var moving := (here - _was) / dt
		if moving.length() > 40.0:
			moving = velocity
		var was_moving := velocity
		velocity = velocity.lerp(moving, 1.0 - exp(-14.0 * dt))
		_accel = _accel.lerp((velocity - was_moving) / dt, 1.0 - exp(-8.0 * dt))
		_turn = lerpf(_turn, wrapf(rotation.y - _yaw_was, -PI, PI) / dt, 1.0 - exp(-8.0 * dt))
	_was = here
	_yaw_was = rotation.y
	var ease := 1.0 - exp(-9.0 * dt) if dt > 0.0 else 1.0
	_w["perched"] = lerpf(_w["perched"], 1.0 if perched else 0.0, 1.0 - exp(-6.0 * dt) if dt > 0.0 else 1.0)
	_w["effort"] = lerpf(_w["effort"], 0.0 if perched else effort, ease)
	_w["basket"] = lerpf(_w["basket"], basket, 1.0 - exp(-14.0 * dt) if dt > 0.0 else 1.0)
	_snap -= dt
	var jaw_wish := maxf(jaws, 1.0 if _snap > 0.12 else 0.0)
	_w["jaws"] = lerpf(_w["jaws"], jaw_wish if _snap <= 0.0 or _snap > 0.12 else 0.0, 1.0 - exp(-30.0 * dt) if dt > 0.0 else 1.0)
	_w["rattle"] = lerpf(_w["rattle"], rattle, ease)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var heading := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var side := heading.cross(Vector3.UP)
	var forward_push := _accel.dot(heading)
	var sideways := _accel.dot(side)
	_w["hover"] = lerpf(_w["hover"], 1.0 - smoothstep(1.0, 4.5, speed), ease)
	var p: float = _w["perched"]
	var e: float = _w["effort"]
	var hover: float = _w["hover"]
	# The body: level hovering (the nose a touch up), the nose down going fast
	# and dipping as it speeds up, up as it brakes; banked into its turns.
	var pitch := (-0.05 * hover + 0.012 * speed + clampf(forward_push * 0.018, -0.35, 0.35) - 0.03 * velocity.y) * (1.0 - p)
	var bank := clampf(-_turn * 0.22 - sideways * 0.03, -0.7, 0.7) * (1.0 - p)
	_w["pitch"] = lerpf(_w["pitch"], pitch, 1.0 - exp(-7.0 * dt) if dt > 0.0 else 1.0)
	_w["bank"] = lerpf(_w["bank"], bank, 1.0 - exp(-7.0 * dt) if dt > 0.0 else 1.0)
	# The abdomen: hanging a little hovering, straight darting, lifted braking, swung out turning.
	var curl := lerpf(lerpf(0.22, 0.04, smoothstep(1.0, 6.0, speed)) - clampf(-forward_push * 0.02, -0.1, 0.3), 0.06, p)
	_w["curl"] = lerpf(_w["curl"], curl + 0.03 * sin(_t * 1.3 + seed_value), 1.0 - exp(-4.0 * dt) if dt > 0.0 else 1.0)
	_w["sway"] = lerpf(_w["sway"], clampf(_turn * 0.18, -0.4, 0.4) * (1.0 - p) + 0.04 * sin(_t * 0.9 + seed_value * 0.3), 1.0 - exp(-5.0 * dt) if dt > 0.0 else 1.0)
	# The head: to what it looks at, else into its turn.
	var yaw_wish := clampf(_turn * 0.18, -0.5, 0.5)
	var pitch_wish := 0.0
	if aim.is_finite() and _body:
		var local := _body.global_transform.affine_inverse() * aim - GriffinflyLook.NECK
		yaw_wish = clampf(atan2(local.x, local.z), -1.0, 1.0)
		pitch_wish = clampf(atan2(-local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
	_w["head_yaw"] = lerpf(_w["head_yaw"], yaw_wish * (1.0 - p * 0.5), 1.0 - exp(-10.0 * dt) if dt > 0.0 else 1.0)
	_w["head_pitch"] = lerpf(_w["head_pitch"], pitch_wish, 1.0 - exp(-10.0 * dt) if dt > 0.0 else 1.0)
	_place_body()
	_beat_wings(dt, e, hover, p)
	_material.set_shader_parameter(&"head_turn", Vector2(_w["head_yaw"], _w["head_pitch"]))
	_material.set_shader_parameter(&"jaws", _w["jaws"])
	_material.set_shader_parameter(&"basket", _w["basket"] * (1.0 - p))
	_material.set_shader_parameter(&"grip", p)
	_material.set_shader_parameter(&"curl", _w["curl"])
	_material.set_shader_parameter(&"sway", _w["sway"])
	_sound(e, p)


# Where the body is turned: banked and pitched in flight; on a perch, flat on its surface.
func _place_body() -> void:
	if _body == null:
		return
	var flying := Basis(Vector3.RIGHT, float(_w["pitch"])) * Basis(Vector3.FORWARD, float(_w["bank"]))
	var p: float = _w["perched"]
	if p < 0.01:
		_body.basis = flying.scaled(Vector3.ONE * wingspan)
		_body.position = Vector3.ZERO
		return
	# (on the surface: Y out of it, the head up it on a wall or the way it heads on the ground)
	var out := surface.normalized() if surface.length() > 0.01 else Vector3.UP
	var ahead := Vector3.UP - out * Vector3.UP.dot(out)
	if ahead.length() < 0.3:
		ahead = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		ahead = (ahead - out * ahead.dot(out))
	ahead = ahead.normalized()
	var resting := Basis(out.cross(ahead).normalized(), out, ahead)
	var local := global_basis.orthonormalized().inverse() * resting
	_body.basis = Basis(flying.get_rotation_quaternion().slerp(local.get_rotation_quaternion(), p)).scaled(Vector3.ONE * wingspan)
	# (its legs under it hold it a little off the surface)
	_body.position = global_basis.orthonormalized().inverse() * out * 0.05 * wingspan * p


# The four wings, each on its own stroke.
func _beat_wings(dt: float, e: float, hover: float, p: float) -> void:
	var rate := flap_rate * lerpf(0.75, 1.12, e) * (1.0 + 0.12 * float(_w["rattle"]))
	if e > 0.02:
		_phase = fposmod(_phase + dt * rate, 1.0)
	# Hovering the hind pair beats half a beat off the fore (they beat against each
	# other); flying fast it leads by a quarter.
	var lead := lerpf(0.25, 0.5, hover)
	var turning := clampf(_turn * 0.25, -0.35, 0.35)
	var beat := Vector4.ZERO
	var sweep := Vector4.ZERO
	var twist := Vector4.ZERO
	for k in 4:
		var hind := k >= 2
		var left := k % 2 == 1
		var phase := _phase + (lead if hind else 0.0) + _wing_lag[k] + 0.012 * sin(_t * 2.1 + _wing_jitter[k])
		var a := TAU * phase
		# (the wings on the outside of a turn beat wider: turning left, the right ones)
		var wide := 1.0 + (turning if not left else -turning)
		var stroke := lerpf(0.08, 0.72, e) * wide * (1.0 + 0.08 * sin(_t * 1.7 + _wing_jitter[k]))
		var middle := lerpf(0.03, 0.12, e)
		var flying := middle + stroke * sin(a)
		# (gliding, the wings held out flat; a little shiver now and then)
		var held := -0.03 + 0.01 * sin(_t * 23.0 + k)
		var lift := lerpf(flying, held, smoothstep(0.15, 0.0, e))
		# Resting: held out flat, drooping a little, the hind pair a touch back.
		lift = lerpf(lift, -0.1 if not hind else -0.07, p)
		var swept := (0.1 * cos(a) * e + (0.06 if hind else -0.03)) * (1.0 - p) + (0.12 if hind else -0.06) * p
		var turned := -0.55 * cos(a) * e * (1.0 - p)
		beat[k] = lift
		sweep[k] = swept
		twist[k] = turned
	_material.set_shader_parameter(&"beat", beat)
	_material.set_shader_parameter(&"sweep", sweep)
	_material.set_shader_parameter(&"twist", twist)
	_material.set_shader_parameter(&"blur", clampf(e * 0.75 * (rate / 14.0), 0.0, 0.85))


func _sound(e: float, p: float) -> void:
	if _wings == null:
		return
	var loud := e * (1.0 - p)
	if loud > 0.04:
		if not _wings.playing:
			_wings.play(_rng.randf() * 0.9)
		_wings.volume_db = volume_db + linear_to_db(clampf(loud, 0.05, 1.0)) + 9.0 * float(_w["rattle"])
		_wings.pitch_scale = lerpf(0.85, 1.1, e) * (1.0 + 0.18 * float(_w["rattle"]))
	elif _wings.playing:
		_wings.stop()


# --- Its sounds, made in code ---

## A loop of its wings: at each stroke a papery clatter (a burst of rough noise
## through a band, the wing's membrane cracking like stiff paper), over a low
## thrum of the beat itself. One second, 13 beats (two strokes each).
static func clatter_sound() -> AudioStreamWAV:
	if _clatter_wav != null:
		return _clatter_wav
	const RATE := 22050
	const BEATS := 13
	var n := RATE
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var band := _Band.new(900.0, 1.2, RATE)
	var low := _Band.new(240.0, 0.9, RATE)
	for s in n:
		var t := float(s) / RATE
		var beat := fposmod(t * BEATS, 1.0)
		# (two strokes a beat: the downstroke louder)
		var down := exp(-pow((beat - 0.08) / 0.05, 2.0))
		var up := 0.55 * exp(-pow((beat - 0.58) / 0.06, 2.0))
		var crackle := rng.randf_range(-1.0, 1.0) * (0.6 + 0.4 * rng.randf())
		var paper := band.run(crackle) * (down + up)
		var thrum := low.run(rng.randf_range(-1.0, 1.0)) * (0.35 + 0.65 * (down + up)) + 0.5 * sin(TAU * BEATS * 2.0 * t) * (down + up)
		samples[s] = paper * 1.0 + thrum * 0.55
	_clatter_wav = _wav(samples, RATE, true)
	return _clatter_wav


## The jaws snapping shut: a hard double click.
static func click_sound() -> AudioStreamWAV:
	if _click_wav != null:
		return _click_wav
	const RATE := 22050
	var n := int(RATE * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var band := _Band.new(2600.0, 2.0, RATE)
	for s in n:
		var t := float(s) / RATE
		var hit := exp(-t / 0.004) + 0.6 * exp(-maxf(t - 0.035, 0.0) / 0.005) * (1.0 if t > 0.035 else 0.0)
		samples[s] = band.run(rng.randf_range(-1.0, 1.0)) * hit
	_click_wav = _wav(samples, RATE, false)
	return _click_wav


static func _wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for s in samples.size():
		data.encode_s16(s * 2, int(clampf(samples[s] / peak * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## A band-pass filter (a biquad), for shaping noise.
class _Band:
	var a0 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * frequency / rate
		var alpha := sin(w) / (2.0 * q)
		var norm := 1.0 + alpha
		a0 = alpha / norm
		a1 = 0.0
		a2 = -alpha / norm
		b1 = -2.0 * cos(w) / norm
		b2 = (1.0 - alpha) / norm

	func run(x: float) -> float:
		var y := a0 * x + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
