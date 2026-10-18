class_name Elk
extends Deer
## A bull elk in the rut: half as big again as a deer and far heavier, taller
## at the shoulder than a boy, a pale tan body under a dark chocolate neck and
## head, a long shaggy dark mane hanging under his neck, a buff rump, and a
## six-point rack of antlers that sweeps back over his shoulders. His breath
## steams.
##
## He is a Deer (creatures/deer/deer.gd): driven the same way (move him and he
## walks, trots or gallops to match; `look_at_point`, `grazing`, `alert`,
## `stamp()`, `snort()`), on the same rig, with these on top:
## - `bugle(seconds)`: he stretches his neck out and up, nose to the sky,
##   mouth open, lip curled, and screams: a rising, whistling shriek with a
##   growl under it, ending in grunts. Steam pours from his mouth. `bugling()`.
## - `pawing`: he paws the ground with a forefoot, scraping it back, again and
##   again, head low: the wind-up before a charge.
## - `lowered`: head down, nose tucked to his chest, antlers pointing forward:
##   how he charges (move him at a gallop with it on).
## - `heavy`: how hard he is breathing (0..1): more steam, quicker.
##
## Signals: `bugled` (and Deer's). With `sound` on he makes the bugle too (made
## in code: `bugle_sound()`).

signal bugled

## Seconds a bugle takes, by default.
const BUGLE_TIME := 3.3

## A cow (no antlers, no mane, smaller; she does not bugle). Set before he enters the tree.
@export var cow := false

var pawing := false
var lowered := false
var heavy := 0.0

var _bugle_left := 0.0
var _bugle_time := BUGLE_TIME
var _breath: CPUParticles3D
var _breath_in := 1.0
var _bugle_voice: AudioStreamPlayer3D
static var _bugle: AudioStreamWAV


func _ready() -> void:
	super()
	_breath = _steam()
	add_child(_breath)
	_breath.top_level = true
	if sound:
		_bugle_voice = AudioStreamPlayer3D.new()
		_bugle_voice.stream = bugle_sound()
		_bugle_voice.volume_db = volume_db + 2.0
		_bugle_voice.unit_size = 14.0
		_bugle_voice.max_distance = 140.0
		_bugle_voice.position = Vector3(0.0, 2.2, 1.0)
		add_child(_bugle_voice)


func model_path() -> String:
	return "res://creatures/elk/models/elk_%s%s.glb" % ["cow" if cow else "bull", "_lo" if low_poly else ""]


func colours() -> Dictionary:
	return {"coat": Color(0.55, 0.45, 0.33), "dark": Color(0.16, 0.105, 0.075), "pale": Color(0.84, 0.74, 0.56)}


func _process(delta: float) -> void:
	super(delta)
	if _bugle_left > 0.0:
		_bugle_left -= delta
	# His breath: a puff at each breath out, more of it the harder he breathes, a stream while he bugles.
	_breath.global_position = nose_position()
	if bugling() and bugle_progress() > 0.12 and bugle_progress() < 0.85:
		_breath.emitting = true
		_breath.initial_velocity_min = 1.2
		_breath.initial_velocity_max = 2.0
		_breath.direction = rig.mouth_way() if rig else Vector3.UP
	else:
		_breath_in -= delta
		_breath.initial_velocity_min = 0.25
		_breath.initial_velocity_max = 0.6
		if _breath_in <= 0.0:
			_breath_in = lerpf(3.2, 0.9, heavy) * randf_range(0.85, 1.15)
			_breath.emitting = true
			_breath.direction = rig.nose_way() if rig else Vector3.FORWARD
		elif _breath_in < lerpf(3.2, 0.9, heavy) - 0.5:
			_breath.emitting = false


## Screams for `seconds`.
func bugle(seconds := BUGLE_TIME) -> void:
	_bugle_time = seconds
	_bugle_left = seconds
	bugled.emit()
	if _bugle_voice and _bugle_voice.is_inside_tree():
		_bugle_voice.pitch_scale = BUGLE_TIME / maxf(seconds, 0.5) * randf_range(0.97, 1.03)
		_bugle_voice.play()


func bugling() -> bool:
	return _bugle_left > 0.0


## How far through his bugle he is, 0..1 (0 when he is not).
func bugle_progress() -> float:
	return 1.0 - _bugle_left / _bugle_time if _bugle_left > 0.0 else 0.0


func busy() -> bool:
	return super() or bugling()


## Steam: soft pale puffs that swell, drift up and fade.
func _steam() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.name = "Breath"
	puff.amount = 24
	puff.lifetime = 1.6
	puff.emitting = false
	puff.one_shot = false
	puff.explosiveness = 0.0
	puff.local_coords = false
	puff.spread = 18.0
	puff.gravity = Vector3(0.0, 0.25, 0.0)
	puff.damping_min = 1.2
	puff.damping_max = 1.8
	puff.scale_amount_min = 0.12
	puff.scale_amount_max = 0.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 2.6))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.42))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	puff.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.88, 0.9, 0.92) * COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.2, 1.0, r)) * 0.8;
}
"""
	quad.material = material
	puff.mesh = quad
	return puff


## The bugle, made once and shared. It starts as a deep groan dragged up out of
## the chest, breaks upward into a high, thin, rising whistle (with the groan
## still going under it, two voices at once, as a real bull's do), holds it
## screaming and wavering, falls away, and ends in a run of hard grunts.
static func bugle_sound() -> AudioStreamWAV:
	if _bugle:
		return _bugle
	var rate := 22050
	var length := BUGLE_TIME
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat := Band.new(700.0, 2.5, rate)
	var breath := Band.new(1800.0, 1.5, rate)
	var whistle_air := Band.new(1500.0, 8.0, rate)
	var low_phase := 0.0
	var high_phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0)
		# The low voice: a groan rising from 110 Hz, kept under the whistle, gone by the grunts.
		var groan_in := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(2.15, 2.4, t))
		var low_pitch := 110.0 + 120.0 * smoothstep(0.0, 0.6, t) - 40.0 * smoothstep(1.6, 2.3, t)
		low_phase += low_pitch * (1.0 + 0.02 * wander) / rate
		var pulse := pow(1.0 - fposmod(low_phase, 1.0), 3.0) * 2.0 - 0.5
		var low := throat.run(pulse) * 1.6 + pulse * 0.25
		# The whistle: breaks in at 0.45 s, climbs to ~1.5 kHz, holds, wavering, and falls away.
		var whistle_in := smoothstep(0.42, 0.55, t) * (1.0 - smoothstep(2.05, 2.35, t))
		var high_pitch := 520.0 + 980.0 * smoothstep(0.45, 1.05, t) - 700.0 * smoothstep(1.75, 2.3, t)
		high_pitch *= 1.0 + 0.012 * sin(TAU * 6.2 * t) + 0.025 * wander
		high_phase += high_pitch / rate
		var whistle := sin(TAU * high_phase) + 0.22 * sin(TAU * high_phase * 2.0) + 0.08 * sin(TAU * high_phase * 3.0)
		whistle_air.set_frequency(high_pitch, 6.0)
		var air := whistle_air.run(rng.randf_range(-1.0, 1.0)) * 0.9
		var value := low * groan_in * lerpf(1.0, 0.45, whistle_in) + (whistle * 0.75 + air) * whistle_in
		value += breath.run(rng.randf_range(-1.0, 1.0)) * 0.25 * (groan_in + whistle_in * 0.5)
		# The grunts: four hard chuckles, each a burst of low pulses.
		for g in 4:
			var start := 2.42 + g * 0.2
			if t > start and t < start + 0.13:
				var u := (t - start) / 0.13
				var grunt := sin(PI * u) * (1.0 - g * 0.12)
				var gp := fposmod((t - start) * (95.0 - g * 6.0), 1.0)
				value += (throat.run(pow(1.0 - gp, 4.0) * 2.0 - 0.4) * 1.8 + rng.randf_range(-0.2, 0.2)) * grunt
		value = tanh(value * 1.6)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_bugle = _wav(samples, loudest, rate)
	return _bugle
