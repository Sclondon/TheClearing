class_name Boar
extends Node3D
## A giant wild boar, after the boar gods of Princess Mononoke: a real boar's
## shape made monstrous. A hump of muscle over the shoulders with a crest of
## black bristle down it, a long wedge of a head ending in a wet disc of a nose,
## small eyes deep under its brow, great curving tusks (chipped, scored, one
## broken off short), short thick legs on cloven hooves, mud caked up its legs
## and belly, old scars, broken arrows still in its hide, slobber hanging from
## its jaws and steam on its breath. Its look, its moves and its sounds are
## here; what it does is for the game to say. It knows nothing of the game it
## is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks,
## trots or gallops to match, its hooves planted at its feet; slowing hard from
## a run, it skids. Set `grounded` false while it is falling. The model stands
## a metre at the shoulder: scale it to make it the giant it is (2.7 makes it
## stand well over a man's head).
##
## Then say what it is doing:
## - `look_at_point`: what it watches (INF for nothing): its head turns to it.
## - `rooting`: snout to the ground, ploughing up the mud, head swinging.
## - `sniffing`: snout up into the wind, the disc of its nose working.
## - `bristling`: its hackles (the crest down its spine) up.
## - `lowered`: head down, tusks forward, braced: the wind-up and the charge.
## - `stunned`: swaying, head hung, shaking it now and then.
## - `snort()`, `grunt()`, `squeal()` (its charging cry), `stamp()` (paws the
##   ground with a forehoof), `slam()` (it has run into something), `toss(side)`
##   (a hooking heave of its tusks up and to one side; `tossed` is emitted as
##   they come up through whatever is in front of it).
##
## Signals say when it does each, and `footfall(at, weight)` when a hoof comes
## down hard. It plays its own sounds (made here in code, no files), unless
## `sound` is off; its breath steams and its hooves throw up dirt.
##
## It is drawn by BoarRig (boar_rig.gd) on the model made by
## tools/build_boar.py, with BoarLook's materials (boar_look.gd): a few draws,
## and fewer with `low_poly` (no bristle shells).

signal snorted
signal grunted
signal squealed
## A forehoof has struck the ground, at `at`.
signal stamped(at: Vector3)
signal slammed
## Its tusks are coming up through what is in front of it, in a toss.
signal tossed
## A hoof has come down hard.
signal footfall(at: Vector3, weight: float)

## The demade, low-poly model, without bristle shells. Set before it enters the tree.
@export var low_poly := false
## Layers of bristle stood off its coat (each is one more draw of it). Set before it enters the tree.
@export_range(0, 4) var fur_shells := 2
## Multiplies the colours of its coat.
@export var coat_tint := Color.WHITE
## How muddy it is, 0..1.5.
@export_range(0.0, 1.5) var mud := 1.0
## How brightly its eyes give back the light.
@export_range(0.0, 2.0) var eyeshine := 0.35
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
@export_group("Sound and breath")
## Plays its own sounds (snorts, grunts, its squeal, hooves, the slam).
@export var sound := true
@export var volume_db := 2.0
## How far off it can be heard (m).
@export var sound_range := 70.0
## Its breath steams, and its hooves and snout throw up dirt.
@export var steam := true

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## Whether its hooves are on the ground.
var grounded := true
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var rooting := false
var sniffing := false
var bristling := false
var lowered := false
var stunned := false
var rig: BoarRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _hoofbeats: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _breath: CPUParticles3D
var _blast: CPUParticles3D
var _dust: CPUParticles3D
var _kick: CPUParticles3D
var _toss_hooked := true
var _exhaled := false
var _skid_dust := 0.0
var _plough_was := 0.0

static var _snort: AudioStreamWAV
static var _grunt: AudioStreamWAV
static var _squeal: AudioStreamWAV
static var _thud: AudioStreamWAV
static var _slam: AudioStreamWAV


func _ready() -> void:
	rig = BoarRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.mud = mud
	rig.eyeshine = eyeshine
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	rig.struck.connect(_on_struck)
	if sound:
		_voice = _player(Vector3(0.0, 0.6, 1.0), 1)
		_hoofbeats = _player(Vector3(0.0, 0.1, 0.0), 6)
		_hoofbeats.stream = thud_sound()
		_hoofbeats.volume_db = volume_db - 4.0
		_impact = _player(Vector3(0.0, 0.5, 0.8), 2)
	if steam:
		_breath = _particles(rig.head(), 8, Color(0.92, 0.93, 0.95, 0.32), 0.22, 0.6)
		_blast = _particles(rig.head(), 26, Color(0.95, 0.96, 0.98, 0.45), 0.28, 1.6)
		_dust = _particles(self, 30, Color(0.36, 0.31, 0.25, 0.7), 0.35, 1.8)
		_dust.top_level = true
		_dust.direction = Vector3.UP
		_dust.spread = 70.0
		_dust.gravity = Vector3(0.0, -4.0, 0.0)
		_kick = _particles(self, 6, Color(0.33, 0.28, 0.22, 0.6), 0.25, 1.0)
		_kick.top_level = true
		_kick.direction = Vector3.UP
		_kick.spread = 55.0
		_kick.gravity = Vector3(0.0, -6.0, 0.0)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				# (put somewhere: not a speed)
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-14.0 * delta))
		_was_at = at
	if not _toss_hooked and rig._tossed >= BoarRig.TOSS_HOOK:
		_toss_hooked = true
		tossed.emit()
	if steam and rig:
		_steam_and_dirt(delta)


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func snort() -> void:
	if rig:
		rig.snort()
	_say(snort_sound(), 0.0, randf_range(0.92, 1.06))
	if _blast:
		_puff(_blast, 2.4)
	snorted.emit()


func grunt() -> void:
	if rig:
		rig.grunt()
	_say(grunt_sound(), -2.0, randf_range(0.9, 1.1))
	grunted.emit()


## Its charging cry: a deep, tearing squeal.
func squeal() -> void:
	if rig:
		rig.squeal()
	_say(squeal_sound(), 2.0, randf_range(0.95, 1.03))
	squealed.emit()


## Paws the ground with a forehoof (`stamped` comes as it strikes).
func stamp() -> void:
	if rig:
		rig.stamp()


## It has run into something: jolted to a stop, the crash of it.
func slam() -> void:
	if rig:
		rig.slam()
	if _impact:
		_impact.stream = slam_sound()
		_impact.volume_db = volume_db + 4.0
		_impact.pitch_scale = randf_range(0.92, 1.05)
		_impact.play()
	if _dust:
		_burst(_dust, rig.snout_tip() + Vector3.UP * 0.3 * global_basis.get_scale().y, 2.5)
	slammed.emit()


## A hooking heave of its tusks, up and to one side (`side` 1: its left).
## `tossed` is emitted as they come up through what is in front of it.
func toss(side := 1.0) -> void:
	if rig:
		rig.toss(side)
	_toss_hooked = false
	_say(grunt_sound(), 2.0, 0.8)


## Stamping or tossing: too taken up to do anything else.
func busy() -> bool:
	return rig != null and (rig.stamping() or rig.tossing())


## Where the disc of its nose is, in the world.
func snout_tip() -> Vector3:
	return rig.snout_tip() if rig else global_position


## Where the tip of a tusk is, in the world (`side` 1: its left).
func tusk_tip(side := 1.0) -> Vector3:
	return rig.tusk_tip(side) if rig else global_position


## Whether its head and tusks are on `point` (in the world): within `radius`
## (m, at a scale of 1) of the line from one tusk tip across its snout to the other.
func gores(point: Vector3, radius := 0.25) -> bool:
	var size := global_basis.get_scale().x
	var left := tusk_tip(1.0)
	var right := tusk_tip(-1.0)
	var nose := snout_tip()
	var near := minf(_to_segment(point, left, nose), _to_segment(point, nose, right))
	return near < radius * size


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Breath and dirt ---

func _steam_and_dirt(delta: float) -> void:
	var size := global_basis.get_scale().y
	# Each breath out steams from its nose (heavier when it has run).
	var out := rig.breathing_out()
	if out > 0.75 and not _exhaled:
		_exhaled = true
		_puff(_breath, out)
	elif out < 0.3:
		_exhaled = false
	# Skidding, dirt sprays from its forehooves; rooting, from its snout each time it flicks up.
	_skid_dust -= delta
	if rig._skid > 0.4 and _skid_dust <= 0.0:
		_skid_dust = 0.08
		var front := global_position + global_basis.z.normalized() * 0.45 * size
		_burst(_kick, front, 1.4)
	var plough := fposmod(rig._plough, 1.0)
	if rig._root > 0.6 and _plough_was < 0.64 and plough >= 0.64:
		_burst(_kick, rig.snout_tip(), 1.2)
	_plough_was = plough


func _on_footfall(at: Vector3, weight: float) -> void:
	if _hoofbeats and weight > 0.2:
		_hoofbeats.volume_db = volume_db - 10.0 + 10.0 * weight
		_hoofbeats.pitch_scale = randf_range(0.85, 1.1) * lerpf(1.2, 0.85, weight)
		_hoofbeats.play()
	if _kick and weight > 0.5:
		_burst(_kick, at, weight)
	footfall.emit(at, weight)


func _on_struck(at: Vector3) -> void:
	if _impact:
		_impact.stream = thud_sound()
		_impact.volume_db = volume_db + 1.0
		_impact.pitch_scale = randf_range(0.7, 0.8)
		_impact.play()
	if _dust:
		_burst(_dust, at, 1.0)
	stamped.emit(at)


func _puff(emitter: CPUParticles3D, strength: float) -> void:
	var size := global_basis.get_scale().y
	emitter.position = rig._snout_tip
	emitter.initial_velocity_min = 0.5 * size * strength
	emitter.initial_velocity_max = 1.0 * size * strength
	emitter.scale_amount_min = 0.8 * size * minf(strength, 1.5)
	emitter.scale_amount_max = 1.4 * size * minf(strength, 1.5)
	emitter.restart()


func _burst(emitter: CPUParticles3D, at: Vector3, strength: float) -> void:
	var size := global_basis.get_scale().y
	emitter.global_position = at
	emitter.initial_velocity_min = 0.6 * size * strength
	emitter.initial_velocity_max = 1.4 * size * strength
	emitter.scale_amount_min = 0.7 * size
	emitter.scale_amount_max = 1.3 * size
	emitter.restart()


## A burst of soft, fading puffs (steam or dust) from `parent`.
func _particles(parent: Node3D, amount: int, colour: Color, size: float, life: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = amount
	emitter.lifetime = life
	emitter.explosiveness = 0.85
	emitter.local_coords = false
	emitter.direction = Vector3(0.0, -0.4, 1.0)
	emitter.spread = 22.0
	emitter.gravity = Vector3(0.0, 0.35, 0.0)
	emitter.damping_min = 1.5
	emitter.damping_max = 2.5
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
	grow.add_point(Vector2(0.0, 0.35))
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
	player.unit_size = 10.0
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


## A snort: two blasts of air through the nose, the second weaker, each
## fluttering where the nostrils flap, over a rumble in the chest.
static func snort_sound() -> AudioStreamWAV:
	if _snort:
		return _snort
	var rate := 22050
	var count := int(rate * 0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nose := Band.new(520.0, 1.6, rate)
	var hiss := Band.new(1500.0, 1.3, rate)
	var chest := Band.new(110.0, 3.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var flap := 0.0
	for i in count:
		var t := float(i) / rate
		var level := 0.0
		for blast: Vector3 in [Vector3(0.0, 0.26, 1.0), Vector3(0.3, 0.2, 0.55)]:
			var u := t - blast.x
			if u > 0.0 and u < blast.y:
				level += blast.z * minf(u / 0.012, 1.0) * pow(1.0 - u / blast.y, 1.6)
		flap += (32.0 + 8.0 * sin(t * 17.0)) / rate
		var flutter := 0.55 + 0.45 * sin(TAU * flap)
		var air := rng.randf_range(-1.0, 1.0)
		var value := (nose.run(air) * 1.4 + hiss.run(air) * 0.5) * level * flutter
		value += chest.run(air) * level * 2.5
		samples[i] = tanh(value * 2.2)
	_snort = _wave(samples, rate)
	return _snort


## A grunt: a low, rough, closed-mouthed voice, falling a little.
static func grunt_sound() -> AudioStreamWAV:
	if _grunt:
		return _grunt
	var rate := 22050
	var length := 0.42
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var formants: Array[Band] = [Band.new(260.0, 4.0, rate), Band.new(620.0, 5.0, rate), Band.new(1350.0, 6.0, rate)]
	var gains := [1.0, 0.6, 0.25]
	var breath := Band.new(800.0, 1.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var level := minf(t / 0.02, 1.0) * (1.0 - smoothstep(length * 0.55, length, t))
		var pitch := lerpf(82.0, 64.0, t / length) * (1.0 + rng.randf_range(-0.06, 0.06))
		phase += pitch / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 5.0) * 2.0 - 0.3
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var value := (throat * 2.0 + breath.run(rng.randf_range(-1.0, 1.0)) * 0.4) * level
		samples[i] = tanh(value * 2.0)
	_grunt = _wave(samples, rate)
	return _grunt


## Its charging cry: a deep bellow that tears up into a squeal and breaks,
## with a growl an octave under it, pushed until it distorts.
static func squeal_sound() -> AudioStreamWAV:
	if _squeal:
		return _squeal
	var rate := 22050
	var length := 1.25
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var formants: Array[Band] = [Band.new(700.0, 4.0, rate), Band.new(1250.0, 5.0, rate), Band.new(2400.0, 6.0, rate), Band.new(3300.0, 5.0, rate)]
	var gains := [1.0, 0.8, 0.45, 0.2]
	var breath := Band.new(2200.0, 1.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low_phase := 0.0
	var wander := 0.0
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(length * 0.7, length, t))
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := 150.0 + 260.0 * smoothstep(0.05, 0.4, t) - 120.0 * smoothstep(0.75, length, t)
		pitch *= 1.0 + 0.06 * wander + 0.04 * sin(t * TAU * 7.0)
		if t > 0.52 and t < 0.6:
			pitch *= 1.35
		phase += pitch / rate
		low_phase += pitch * 0.5 / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 4.0) * 2.0 - 0.4
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var growl := (pow(1.0 - fposmod(low_phase, 1.0), 3.0) - 0.25) * (1.0 - smoothstep(0.2, 0.6, t) * 0.6)
		var value := (throat * 2.0 + growl * 1.2 + breath.run(rng.randf_range(-1.0, 1.0)) * 0.9) * level
		samples[i] = tanh(value * 3.0)
	_squeal = _wave(samples, rate)
	return _squeal


## A hoof coming down: a deep, short thud with a scuff of dirt in it.
static func thud_sound() -> AudioStreamWAV:
	if _thud:
		return _thud
	var rate := 22050
	var count := int(rate * 0.28)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var scuff := Band.new(900.0, 0.9, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		phase += lerpf(95.0, 38.0, minf(t / 0.12, 1.0)) / rate
		var body := sin(TAU * phase) * exp(-t * 22.0)
		var dirt := scuff.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 45.0) * 0.6
		samples[i] = tanh((body * 1.5 + dirt) * 1.6)
	_thud = _wave(samples, rate)
	return _thud


## Running into stone: a great hollow boom, the crunch of it, and grit falling.
static func slam_sound() -> AudioStreamWAV:
	if _slam:
		return _slam
	var rate := 22050
	var length := 1.3
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var crunch := Band.new(700.0, 0.8, rate)
	var grit := Band.new(2600.0, 1.2, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var crackle := 0.0
	for i in count:
		var t := float(i) / rate
		phase += lerpf(62.0, 28.0, minf(t / 0.4, 1.0)) / rate
		var boom := sin(TAU * phase) * exp(-t * 4.5) * minf(t / 0.004, 1.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var crash := crunch.run(noise) * exp(-t * 11.0) * 1.4
		# (grit and chips falling after: little clicks, thinning out)
		if rng.randf() < 0.004 * exp(-t * 2.0):
			crackle = rng.randf_range(0.4, 1.0)
		crackle *= 0.985
		var falling := grit.run(noise) * crackle * smoothstep(0.08, 0.2, t) * 0.8
		samples[i] = tanh((boom * 1.8 + crash + falling) * 1.5)
	_slam = _wave(samples, rate)
	return _slam


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
