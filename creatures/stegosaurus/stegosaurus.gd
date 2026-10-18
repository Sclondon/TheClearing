class_name Stegosaurus
extends Node3D
## A stegosaurus (Stegosaurus stenops), as the bones have it and at its real
## size: 8.6 m from beak to tail, its back arching 2.85 m up over the hips on
## long hind legs and falling to the low shoulders, the biggest of its plates
## near 3.75 m up. A tiny, long, low head with a horny beak and cheeks, carried
## low on a short neck with a pavement of bony studs in the skin of its throat;
## two alternating rows of tall plates down its back; the thagomizer, two
## pairs of long spikes held out from the end of its tail; elephant feet. Its
## look, its moves and its sounds are here; what it does is for the game to
## say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks
## to match, slow and heavy, each foot planted where it comes down; turning on
## the spot, it steps round. Scale it down for a calf (and give it more
## `scales`).
##
## Then say what it is doing:
## - `look_at_point`: what it watches (INF for nothing): its head turns to it.
## - `grazing`: beak to the ground, cropping.
## - `warning` (with `threat_side`: which side of it they are on, 1 its left):
##   side on, braced, its tail raised and cocked away from them, the spikes
##   waving slowly. The warning before a swing.
## - `swing(side)`: the tail whipped round at whoever is on that side, low;
##   `sweeping()` while the spikes come through, `tail_gap(point)` how near
##   they and the end of the tail are to something.
## - `rumble()` (a deep growl of a warning), `bellow()`, and `huff()`.
##
## Signals say when it does each, and `footfall(at, weight)` when a foot
## comes down. It plays its own sounds (made here in code, no files), unless
## `sound` is off; its feet raise a little dust.
##
## It is drawn by StegosaurusRig (stegosaurus_rig.gd) on the model made by
## tools/build_stegosaurus.py, with StegosaurusLook's materials
## (stegosaurus_look.gd): three draws, on a low-poly model with `low_poly`.

signal rumbled
signal bellowed
signal huffed
## It has begun a swing of its tail, at `side` (1: its left).
signal swung(side: float)
## The spikes are coming through the middle of the swing.
signal swept
## A foot has come down.
signal footfall(at: Vector3, weight: float)

## The demade, low-poly model. Set before it enters the tree.
@export var low_poly := false
## Multiplies the colours of its hide.
@export var skin_tint := Color.WHITE
## Scales to a metre of its hide (more for a calf, so they are as small).
@export var scales := 11.0
## How brightly its eyes give back the light.
@export_range(0.0, 2.0) var eyeshine := 0.2
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
@export_group("Sound and dust")
## Plays its own sounds (rumbles, the bellow, its feet, the swish of its tail).
@export var sound := true
@export var volume_db := 3.0
## How far off it can be heard (m).
@export var sound_range := 80.0
## Its feet raise a little dust.
@export var dust := true

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var grazing := false
var warning := false
## Which side of it what it is warning is (1: its left, -1: its right).
var threat_side := 1.0
var rig: StegosaurusRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D
var _tail_sound: AudioStreamPlayer3D
var _dust: CPUParticles3D
var _swished := true

static var _rumble: AudioStreamWAV
static var _bellow: AudioStreamWAV
static var _huff: AudioStreamWAV
static var _thud: AudioStreamWAV
static var _swish: AudioStreamWAV


func _ready() -> void:
	rig = StegosaurusRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.skin_tint = skin_tint
	rig.scales = scales
	rig.eyeshine = eyeshine
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	rig.swept.connect(func() -> void: swept.emit())
	if sound:
		_voice = _player(Vector3(0.0, 1.3, 3.0), 1)
		_feet = _player(Vector3(0.0, 0.2, 0.8), 4)
		_feet.stream = thud_sound()
		_tail_sound = _player(Vector3(0.0, 1.8, -3.5), 1)
	if dust:
		_dust = _particles(self, 18, Color(0.40, 0.37, 0.32, 0.55), 0.6, 1.6)
		_dust.top_level = true
		_dust.direction = Vector3.UP
		_dust.spread = 75.0
		_dust.gravity = Vector3(0.0, -1.5, 0.0)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 40.0:
				# (put somewhere: not a speed)
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-10.0 * delta))
		_was_at = at
	if not _swished and rig and rig._swung >= StegosaurusRig.WHIP.x - 0.08:
		_swished = true
		if _tail_sound:
			_tail_sound.stream = swish_sound()
			_tail_sound.volume_db = volume_db + 4.0
			_tail_sound.pitch_scale = randf_range(0.9, 1.05)
			_tail_sound.play()


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


## A deep, long growl from its chest: its warning.
func rumble() -> void:
	if rig:
		rig.rumble()
	_say(rumble_sound(), 2.0, randf_range(0.92, 1.05))
	rumbled.emit()


## A long, low, honking bellow.
func bellow() -> void:
	if rig:
		rig.bellow()
	_say(bellow_sound(), 3.0, randf_range(0.95, 1.04))
	bellowed.emit()


## A blast of breath through its nose.
func huff() -> void:
	_say(huff_sound(), -2.0, randf_range(0.9, 1.1))
	huffed.emit()


## Swings its tail round at whoever is on `side` (1: its left).
func swing(side: float) -> void:
	if rig:
		rig.swing(side)
	_swished = false
	swung.emit(side)


## Swinging: too taken up to do anything else.
func swinging() -> bool:
	return rig != null and rig.swinging()


## Whether the spikes are coming round now, fast enough to hurt.
func sweeping() -> bool:
	return rig != null and rig.sweeping()


## How near `point` (in the world) is to the end of its tail or its spikes (m).
func tail_gap(point: Vector3) -> float:
	return rig.tail_gap(point) if rig else INF


## Where the tips of its spikes are, in the world.
func spike_tips() -> PackedVector3Array:
	return rig.spike_tips() if rig else PackedVector3Array()


## Where the tip of its beak is, in the world.
func beak_tip() -> Vector3:
	return rig.beak_tip() if rig else global_position


## Where its hips are (what a swing turns about), in the world.
func hips() -> Vector3:
	return rig.hips() if rig else global_position


func _on_footfall(at: Vector3, weight: float) -> void:
	if _feet and weight > 0.2:
		_feet.volume_db = volume_db - 9.0 + 9.0 * minf(weight, 1.0)
		_feet.pitch_scale = randf_range(0.85, 1.05) / maxf(sqrt(weight), 0.5)
		_feet.play()
	if _dust and weight > 0.45:
		var size := global_basis.get_scale().y
		_dust.global_position = at
		_dust.initial_velocity_min = 0.3 * size
		_dust.initial_velocity_max = 0.9 * size
		_dust.scale_amount_min = 0.7 * size
		_dust.scale_amount_max = 1.4 * size
		_dust.restart()
	footfall.emit(at, weight)


## A burst of soft, fading puffs (dust) from `parent`.
func _particles(parent: Node3D, amount: int, colour: Color, size: float, life: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = amount
	emitter.lifetime = life
	emitter.explosiveness = 0.9
	emitter.local_coords = false
	emitter.damping_min = 1.5
	emitter.damping_max = 2.5
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.25
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	emitter.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, colour)
	ramp.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	emitter.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	emitter.scale_amount_curve = grow
	parent.add_child(emitter)
	return emitter


static var _dot: ImageTexture


## A soft round spot, for the puffs (made once).
static func _soft_dot() -> ImageTexture:
	if _dot:
		return _dot
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r := Vector2(x - 15.5, y - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - r, 0.0, 1.0) ** 1.6))
	_dot = ImageTexture.create_from_image(image)
	return _dot


# --- Sounds ---

func _player(at: Vector3, polyphony: int) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.position = at
	player.unit_size = 14.0
	player.max_distance = sound_range
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


func _say(stream: AudioStreamWAV, gain: float, pitch: float) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db + gain
	_voice.pitch_scale = pitch
	_voice.play()


## Its warning: a deep growl far down in its chest, rough and fluttering,
## swelling and falling away, felt as much as heard.
static func rumble_sound() -> AudioStreamWAV:
	if _rumble:
		return _rumble
	var rate := 22050
	var length := 2.4
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var formants: Array[Band] = [Band.new(160.0, 3.0, rate), Band.new(380.0, 4.0, rate), Band.new(760.0, 5.0, rate)]
	var gains := [1.0, 0.55, 0.2]
	var breath := Band.new(500.0, 0.8, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var wander := 0.0
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(length * 0.6, length, t)) * (0.75 + 0.25 * sin(t * TAU * 0.9))
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0)
		var pitch := (44.0 + 6.0 * sin(t * 2.1) - 8.0 * smoothstep(1.2, length, t)) * (1.0 + 0.05 * wander)
		phase += pitch / rate
		var p := fposmod(phase, 1.0)
		# (the flutter of a throat: the pulses come in rough bursts)
		var flutter := 0.6 + 0.4 * sin(t * TAU * 9.0 + sin(t * 3.0) * 2.0)
		var pulse := (pow(1.0 - p, 6.0) * 2.0 - 0.3) * flutter
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var value := (throat * 2.4 + pulse * 0.5 + breath.run(rng.randf_range(-1.0, 1.0)) * 0.25) * level
		samples[i] = tanh(value * 2.4)
	_rumble = _wave(samples, rate)
	return _rumble


## A bellow: a long, low, hollow honk through the nose, rising and falling,
## with a growl under it.
static func bellow_sound() -> AudioStreamWAV:
	if _bellow:
		return _bellow
	var rate := 22050
	var length := 1.9
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var formants: Array[Band] = [Band.new(260.0, 6.0, rate), Band.new(620.0, 7.0, rate), Band.new(1050.0, 6.0, rate), Band.new(2100.0, 5.0, rate)]
	var gains := [1.0, 0.8, 0.35, 0.1]
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(length * 0.65, length, t))
		var pitch := 72.0 + 26.0 * smoothstep(0.05, 0.5, t) - 34.0 * smoothstep(0.9, length, t)
		pitch *= 1.0 + 0.012 * sin(t * TAU * 5.5) + rng.randf_range(-0.01, 0.01)
		phase += pitch / rate
		low += pitch * 0.5 / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 3.0) * 2.0 - 0.5
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var growl := (pow(1.0 - fposmod(low, 1.0), 4.0) - 0.2) * 0.5
		samples[i] = tanh((throat * 2.0 + growl) * level * 2.0)
	_bellow = _wave(samples, rate)
	return _bellow


## A huff: a short blast of air through the nose, over a grunt.
static func huff_sound() -> AudioStreamWAV:
	if _huff:
		return _huff
	var rate := 22050
	var length := 0.55
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var nose := Band.new(420.0, 1.4, rate)
	var chest := Band.new(90.0, 2.5, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var level := minf(t / 0.02, 1.0) * pow(1.0 - t / length, 2.0)
		var air := rng.randf_range(-1.0, 1.0)
		samples[i] = tanh((nose.run(air) * 1.3 + chest.run(air) * 3.0) * level * 2.0)
	_huff = _wave(samples, rate)
	return _huff


## A foot coming down: a deep, heavy thud, with a crunch of grit in it.
static func thud_sound() -> AudioStreamWAV:
	if _thud:
		return _thud
	var rate := 22050
	var count := int(rate * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var grit := Band.new(700.0, 0.9, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		phase += lerpf(70.0, 26.0, minf(t / 0.2, 1.0)) / rate
		var body := sin(TAU * phase) * exp(-t * 11.0)
		var dirt := grit.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 35.0) * 0.5
		samples[i] = tanh((body * 1.8 + dirt) * 1.5)
	_thud = _wave(samples, rate)
	return _thud


## The swish of the tail coming round: a rush of air rising and falling, and a heavy whoomp in it.
static func swish_sound() -> AudioStreamWAV:
	if _swish:
		return _swish
	var rate := 22050
	var length := 0.75
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var air := Band.new(400.0, 1.2, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / length
		air.set_frequency(lerpf(300.0, 1400.0, sin(PI * minf(u * 1.3, 1.0))), 1.2)
		var level := sin(PI * pow(u, 0.7)) ** 2
		phase += lerpf(55.0, 35.0, u) / rate
		var whoomp := sin(TAU * phase) * smoothstep(0.25, 0.45, u) * (1.0 - smoothstep(0.45, 0.8, u))
		samples[i] = tanh((air.run(rng.randf_range(-1.0, 1.0)) * 2.2 * level + whoomp * 0.9) * 1.6)
	_swish = _wave(samples, rate)
	return _swish


static func _wave(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


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
