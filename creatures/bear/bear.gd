class_name Bear
extends Node3D
## A screaming bear: a huge bear that something has got into and changed,
## starved to the bone and wrong. Far too long in the leg, so that it stands
## high and gaunt; a deep narrow ribcage with the ribs standing out, the belly
## pinched up to nothing, hip bones and spine knobs poking through, a bony
## hump; a long thin neck carrying the head low. Half its face is skull: on
## its right the skin has gone from the muzzle and round the eye, and the bone
## shows, the eye in it clouded white; it has no lips, so its teeth show all
## along both jaws. Patchy fur sloughing away to pale, veined skin; on its
## right flank bare ribs. Long claws, loose flaps of skin, bloody slaver.
##
## Its horror is its voice. It cries out with the voice of the last thing it
## killed: "help!", "help... me", "no, no, no!", a scream, sobbing. Always the
## same cries in the same voice, over and over, as a recording would be.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## drives it. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and
## prowls, trots or gallops to match; slowing hard, it skids. Set `grounded`
## false while it is falling. The model stands a metre at the shoulder: scale
## it (2.4 makes it stand far over a man, and rear to twice his height).
##
## Then say what it is doing:
## - `look_at_point`: what it watches (INF for nothing).
## - `sniffing`: head up, nose working.
## - `lowered`: the wind-up of a charge, gathered to spring.
## - `rearing`: up on its hind legs.
## - `mauling`: head down over something in front of it, tearing.
## - `voice`: whose voice it has (BearVoice: 0..5 people, 6 an animal).
## - `call_out(which)`: one of its stolen cries (BearVoice.CALL_HELP, CALL_HELP_ME,
##   CALL_NO, SOB; -1 any of the calls), the jaw working with it.
## - `scream()`: its scream, jaws agape (the loudest thing it does).
## - `swipe(side)`: a foreleg raked across in front of it (`swiped` as the claws
##   come through; test `claws_reach(point)`).
## - `huff()`, `pop_jaw()`, `sniff()`, `growl()`.
##
## Signals say when it does each, and `footfall(at, weight)` when a paw comes
## down. It plays its own sounds (made here and in BearVoice, in code, no
## files), unless `sound` is off; its breath steams in the cold.
##
## It is drawn by BearRig (bear_rig.gd) on the model made by
## tools/build_bear.py, with BearLook's materials (bear_look.gd): a few draws,
## and fewer with `low_poly` (no fur shells).

signal called(which: int)
signal screamed
signal swiped
signal huffed
signal footfall(at: Vector3, weight: float)

## The demade, low-poly model, without fur shells. Set before it enters the tree.
@export var low_poly := false
## Layers of fur stood off its coat (each is one more draw of it). Set before it enters the tree.
@export_range(0, 4) var fur_shells := 2
## Multiplies the colours of its fur.
@export var coat_tint := Color.WHITE
## How much of its fur has sloughed away, 0..1.5. Set before it enters the tree.
@export_range(0.0, 1.5) var bare := 1.0
## How brightly its good eye gives back the light.
@export_range(0.0, 2.0) var eyeshine := 0.3
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## Whose voice it has (BearVoice: 0..5 people, 6 an animal). Its cries in a
## new voice are made a little at a time, over the next frames.
@export_range(0, 6) var voice := 0:
	set(value):
		voice = clampi(value, 0, BearVoice.SPEAKERS - 1)
		if is_inside_tree() and sound:
			BearVoice.prepare(voice)
@export_group("Sound and breath")
## Plays its own sounds.
@export var sound := true
@export var volume_db := 0.0
## How far off its voice carries (m): a long way, through the maze.
@export var voice_range := 140.0
## How far off its other sounds carry (m).
@export var sound_range := 60.0
## Its breath steams.
@export var steam := true

var velocity := Vector3.ZERO
var grounded := true
var look_at_point := Vector3.INF
var sniffing := false
var lowered := false
var rearing := false
var mauling := false
var rig: BearRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _body: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _breath: CPUParticles3D
var _exhaled := false
var _cries := 0

static var _huff: AudioStreamWAV
static var _pop: AudioStreamWAV
static var _sniff: AudioStreamWAV
static var _growl: AudioStreamWAV
static var _thud: AudioStreamWAV
static var _rake: AudioStreamWAV

const RATE := 22050


func _ready() -> void:
	rig = BearRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.bare = bare
	rig.eyeshine = eyeshine
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	rig.swiped.connect(_on_swiped)
	if sound:
		_voice = _player(Vector3(0.0, 0.8, 0.9), 1, voice_range, 16.0)
		_body = _player(Vector3(0.0, 0.8, 0.8), 2, sound_range, 8.0)
		_steps = _player(Vector3(0.0, 0.1, 0.0), 4, sound_range, 8.0)
		_steps.stream = thud_sound()
		BearVoice.prepare(voice)
	if steam:
		_breath = _particles(rig.head(), 8, Color(0.92, 0.93, 0.95, 0.28), 0.2, 0.7)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if sound:
		BearVoice.work()
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-14.0 * delta))
		_was_at = at
	if _breath and rig:
		var out := rig.breathing_out()
		if out > 0.75 and not _exhaled:
			_exhaled = true
			_puff(out)
		elif out < 0.3:
			_exhaled = false


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


## One of its stolen cries in its `voice` (BearVoice.CALL_HELP, CALL_HELP_ME,
## CALL_NO or SOB; -1: one of the three calls, in turn). With `if_ready`, only
## if that cry is made already (false if it is not).
func call_out(which := -1, if_ready := false) -> bool:
	if which < 0:
		which = [BearVoice.CALL_HELP, BearVoice.CALL_HELP_ME, BearVoice.CALL_NO][_cries % 3]
	if if_ready and sound and not BearVoice.is_ready(which, voice):
		return false
	_cries += 1
	var seconds := 1.4
	if _voice:
		var stream := BearVoice.cry(which, voice)
		seconds = stream.data.size() / 2.0 / BearVoice.RATE
		_say(stream)
	if rig:
		rig.speak(seconds * 0.75)
	called.emit(which)
	return true


## Its scream, in its stolen voice: jaws agape, head shaking.
func scream() -> void:
	var seconds := 2.6
	if _voice:
		var stream := BearVoice.cry(BearVoice.SCREAM, voice)
		seconds = stream.data.size() / 2.0 / BearVoice.RATE
		_say(stream, 3.0)
	if rig:
		rig.scream(seconds * 0.8)
	screamed.emit()


func screaming() -> bool:
	return rig != null and rig.screaming()


## A foreleg raked across in front of it (`side` 1: its left); `swiped` as the claws come through.
func swipe(side := 1.0) -> void:
	if rig:
		rig.swipe(side)
	_make(growl_sound(), 0.0, randf_range(1.05, 1.15))


func swiping() -> bool:
	return rig != null and rig.swiping()


## Whether a point (in the world) is within reach of a swipe: in front of it,
## within its forelegs' reach (`reach` m at a scale of 1) of its chest, and not
## far over its head.
func claws_reach(point: Vector3, reach := 1.25) -> bool:
	var size := global_basis.get_scale().x
	var chest := global_position + Vector3.UP * 0.8 * size
	var to := point - chest
	var ahead := global_basis.z.normalized()
	var flat := Vector3(to.x, 0.0, to.z)
	return flat.length() < reach * size and flat.dot(ahead) > -0.1 * size and to.y < 1.4 * size and to.y > -1.2 * size


## A blast of breath out through its teeth: the bear's warning "woof".
func huff() -> void:
	if rig:
		rig.huff()
	_make(huff_sound(), 0.0, randf_range(0.9, 1.05))
	if _breath:
		_puff(2.0)
	huffed.emit()


## Its jaws snapped together twice: bears do it when they mean harm.
func pop_jaw() -> void:
	if rig:
		rig.pop_jaw()
	_make(pop_sound(), -2.0, randf_range(0.95, 1.05))


func sniff() -> void:
	_make(sniff_sound(), -6.0, randf_range(0.9, 1.1))


## A low wet rattle in its chest.
func growl() -> void:
	_make(growl_sound(), -2.0, randf_range(0.85, 0.95))


func snout_tip() -> Vector3:
	return rig.snout_tip() if rig else global_position


func _on_footfall(at: Vector3, weight: float) -> void:
	if _steps and weight > 0.15:
		_steps.volume_db = volume_db - 12.0 + 10.0 * weight
		_steps.pitch_scale = randf_range(0.85, 1.1) * lerpf(1.15, 0.85, weight)
		_steps.play()
	footfall.emit(at, weight)


func _on_swiped() -> void:
	_make(rake_sound(), 0.0, randf_range(0.9, 1.1))
	swiped.emit()


func _puff(strength: float) -> void:
	var size := global_basis.get_scale().y
	_breath.position = rig._snout_tip
	_breath.initial_velocity_min = 0.4 * size * strength
	_breath.initial_velocity_max = 0.8 * size * strength
	_breath.scale_amount_min = 0.7 * size * minf(strength, 1.5)
	_breath.scale_amount_max = 1.2 * size * minf(strength, 1.5)
	_breath.restart()


func _particles(parent: Node3D, amount: int, colour: Color, size: float, life: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = amount
	emitter.lifetime = life
	emitter.explosiveness = 0.85
	emitter.local_coords = false
	emitter.direction = Vector3(0.0, -0.3, 1.0)
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


## A soft round spot, for the puffs of breath (made once).
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

func _player(at: Vector3, polyphony: int, reach: float, unit: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.position = at
	player.unit_size = unit
	player.max_distance = reach
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


func _say(stream: AudioStreamWAV, gain := 0.0) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db + gain
	# (always the same: it plays its cries back as they were, every time)
	_voice.pitch_scale = 1.0
	_voice.play()


func _make(stream: AudioStreamWAV, gain: float, pitch: float) -> void:
	if _body == null:
		return
	_body.stream = stream
	_body.volume_db = volume_db + gain
	_body.pitch_scale = pitch
	_body.play()


## A huff: a blast of breath forced out through the teeth, a cough of a voice under it.
static func huff_sound() -> AudioStreamWAV:
	if _huff:
		return _huff
	var count := int(RATE * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var chest := BearVoice.Reso.new(180.0, 140.0, RATE)
	var throat := BearVoice.Band.new(650.0, 1.6, RATE)
	var teeth := BearVoice.Band.new(2400.0, 1.3, RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var level := minf(t / 0.01, 1.0) * pow(maxf(1.0 - t / 0.42, 0.0), 2.2)
		phase += lerpf(95.0, 70.0, t / 0.42) / RATE
		var air := rng.randf_range(-1.0, 1.0)
		var cough := (pow(1.0 - fposmod(phase, 1.0), 4.0) - 0.2) * (1.0 - smoothstep(0.0, 0.15, t))
		samples[i] = tanh((throat.run(air) * 2.5 + teeth.run(air) * 1.2 + chest.run(cough) * 3.0) * level * 1.6)
	_huff = BearVoice._wav(samples)
	return _huff


## Jaws snapped together twice: hard, hollow clacks of tooth on tooth.
static func pop_sound() -> AudioStreamWAV:
	if _pop:
		return _pop
	var count := int(RATE * 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var samples := PackedFloat32Array()
	samples.resize(count)
	for clack: float in [0.02, 0.21]:
		var ring := BearVoice.Band.new(1300.0, 6.0, RATE)
		var bone := BearVoice.Band.new(3100.0, 5.0, RATE)
		var start := int(clack * RATE)
		for k in int(0.09 * RATE):
			if start + k >= count:
				break
			var u := float(k) / RATE
			var hit := rng.randf_range(-1.0, 1.0) * exp(-u * 160.0)
			samples[start + k] += ring.run(hit) * 3.0 * exp(-u * 40.0) + bone.run(hit) * 2.0
	_pop = BearVoice._wav(samples)
	return _pop


## Sniffing: three quick snatches of air through the nose.
static func sniff_sound() -> AudioStreamWAV:
	if _sniff:
		return _sniff
	var count := int(RATE * 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var nose := BearVoice.Band.new(1700.0, 1.2, RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		var level := 0.0
		for at: float in [0.0, 0.14, 0.27]:
			var u := t - at
			if u > 0.0 and u < 0.1:
				level += sin(PI * u / 0.1)
		samples[i] = nose.run(rng.randf_range(-1.0, 1.0)) * level * 2.0
	_sniff = BearVoice._wav(samples)
	return _sniff


## A low wet rattle in its chest, rising a little.
static func growl_sound() -> AudioStreamWAV:
	if _growl:
		return _growl
	var length := 1.1
	var count := int(RATE * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var chest := BearVoice.Reso.new(240.0, 160.0, RATE)
	var throat := BearVoice.Reso.new(520.0, 300.0, RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var level := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(length * 0.7, length, t))
		phase += (58.0 + 18.0 * t + rng.randf_range(-6.0, 6.0)) / RATE
		var pulse := pow(1.0 - fposmod(phase, 1.0), 6.0) - 0.15
		var rattle := 0.6 + 0.4 * sin(TAU * 23.0 * t)
		var air := rng.randf_range(-1.0, 1.0) * 0.3
		samples[i] = tanh((chest.run(pulse) * 3.0 + throat.run(pulse + air) * 1.5) * rattle * level * 1.8)
	_growl = BearVoice._wav(samples)
	return _growl


## A heavy paw coming down: a soft deep thud.
static func thud_sound() -> AudioStreamWAV:
	if _thud:
		return _thud
	var count := int(RATE * 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var scuff := BearVoice.Band.new(700.0, 0.9, RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += lerpf(80.0, 34.0, minf(t / 0.12, 1.0)) / RATE
		var body := sin(TAU * phase) * exp(-t * 20.0)
		var dirt := scuff.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 40.0) * 0.5
		samples[i] = tanh((body * 1.5 + dirt) * 1.5)
	_thud = BearVoice._wav(samples)
	return _thud


## Claws raking the air: a ripping whoosh.
static func rake_sound() -> AudioStreamWAV:
	if _rake:
		return _rake
	var count := int(RATE * 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var band := BearVoice.Band.new(900.0, 1.0, RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		band.tune(600.0 + 2600.0 * sin(PI * t / 0.35), 1.2)
		var level := sin(PI * minf(t / 0.3, 1.0))
		samples[i] = band.run(rng.randf_range(-1.0, 1.0)) * level * 2.5
	_rake = BearVoice._wav(samples)
	return _rake
