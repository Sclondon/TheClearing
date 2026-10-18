class_name BigCat
extends Dog
## A big cat: a Eurasian lynx or a black panther (`kind`). Its look, every move
## and its voice are here; what it does is for the game to say. It knows
## nothing of the game it is in.
##
## - THE LYNX: long-legged and short-bodied, its rump a little high, huge furry
##   paws, a short black-tipped bob of a tail, a flaring barred ruff, tall ears
##   with long black tufts; spotted grey-brown, cream below.
## - THE PANTHER: a melanistic leopard, long and low and heavy in the shoulder,
##   a long thick tail carried low with its end curled up, a broad round head,
##   small round ears; black, the leopard's rosettes there in the black where
##   the light falls on them; green-gold eyes that give the light back.
##
## It is built on the dog (Dog, creatures/dog: needs GameCommon's godot/dog), so
## it is driven the same way: move it (its position and its rotation about Y:
## it faces +Z) and it walks, trots or gallops to match (a cat's walk, its
## rarely used trot, the bounding gallop), its paws planted on the ground.
## Scale it to make it bigger. Then say what it is doing:
## - `look_at_point`: what it watches (INF: nothing). Its head turns to it.
## - `stalking`: the stalk: low on bent legs, the shoulder blades up over its
##   back, its head down level with them and its eyes on what it watches, slow
##   deliberate steps; holding still with a forepaw lifted when it stops
##   (`freeze_step`), the tip of its tail twitching.
## - `crouching`: flat to the ground in ambush, gathered, chin low, tail out flat
##   behind it, the tip flicking.
## - `feeding`: crouched over a kill, head down, tearing at it.
## - `lashing`: the tail lashing from side to side (angry or keyed up).
## - `wary`: ears turned back, watching: it means to go.
## - `climbing`: on a wall. The game turns it (+Z up the wall, or down it
##   head first, its back out from the wall) and moves it along it, and it bounds
##   up as a leopard goes up a tree; its tail hangs.
## - `sitting`, `lying` (the dog's: it dozes off when it has lain a while).
## - `hiss()`: ears flat out to the sides, the mouth wide, lips drawn off the
##   fangs, the head drawn back: a hiss and a spit. (`hissing()` while it lasts.)
## - `growl(seconds)`: a low rumble, the lips lifting a little. The panther's
##   warning when it is close.
## - `pounce(at)`: the hindquarters wiggle and the hind feet tread
##   (WIGGLE_TIME: the last warning), then it springs at `at`, forelegs
##   reaching out wide, claws out, jaws open (the dog's lunge, further:
##   GATHER, SPRING, BITE, LAND). Move it each frame by `lunge_push()` while it
##   does (nothing while it wiggles), and ask `pounce_hits(point)`.
## - `swipe(at)`: a forepaw raised and slashed at `at` (SWIPE_TIME), the body
##   rocked back on its haunches for it. Ask `swipe_hits(point)`.
## - `eyeshine`, `set_eyeshine(amount)`: how brightly its eyes give back the
##   light (a game raises it at night).
##
## It makes its own sounds (made in code: nothing to load), from where it is,
## unless `sound` is off; the signals say when.
##
## It is drawn by BigCatRig (big_cat_rig.gd, which extends the dog's DogRig) on
## creatures/big_cat/models/lynx.glb or panther.glb (made by
## tools/build_big_cat.py), with BigCatLook's materials (big_cat_look.gd).

signal hissed
signal growled
## It has begun to wiggle before a pounce at `at`.
signal pounce_begun(at: Vector3)
signal swiped(at: Vector3)

enum Kind { LYNX, PANTHER }

## Seconds the hindquarters wiggle before a pounce, and that a swipe takes.
const WIGGLE_TIME := 0.7
const SWIPE_TIME := 0.62
## How far through a swipe the paw strikes (from, to), 0..1.
const STRIKE := Vector2(0.42, 0.66)
## Seconds a hiss lasts.
const HISS_TIME := 1.1

## Which cat. Set before it enters the tree.
@export var kind := Kind.PANTHER
## Plays its sounds (made in code) from where it is.
@export var sound := true
@export var volume_db := -8.0
## How far off it is heard (world units).
@export var sound_range := 30.0

var crouching := false
var feeding := false
var lashing := false
var wary := false
var climbing := false
## Stopped mid-stalk with a forepaw lifted.
var freeze_step := false

var _wiggle := INF
var _pounce_at := Vector3.ZERO
var _swipe := INF
var _swipe_at := Vector3.ZERO
var _swipe_side := 0
var _hiss := INF
var _growl_left := 0.0
var _voice: AudioStreamPlayer3D
var _rumble: AudioStreamPlayer3D

static var _hiss_sound: Array[AudioStreamWAV] = []
static var _growl_sound: Array[AudioStreamWAV] = []
static var _snarl_sound: Array[AudioStreamWAV] = []


func _init() -> void:
	lunge_reach = Vector2(1.4, 4.2)
	eyeshine = 0.6


func _ready() -> void:
	rig = BigCatRig.new()
	rig.name = "Rig"
	rig.variant = kind
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.mange = 0.0
	rig.eyeshine = eyeshine
	add_child(rig)
	if sound:
		_voice = _speaker(volume_db)
		_rumble = _speaker(volume_db - 2.0)


func _speaker(loud: float) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.volume_db = loud
	speaker.unit_size = 4.0
	speaker.max_distance = sound_range
	speaker.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	speaker.position = Vector3(0.0, 0.6, 0.5)
	add_child(speaker)
	return speaker


func _process(delta: float) -> void:
	var was_at := global_position
	super(delta)
	if delta <= 0.0:
		return
	if climbing and measure_velocity:
		# (on a wall it goes the way it faces: that is what its legs keep pace with)
		var along := global_basis.z.normalized()
		velocity = Vector3(0.0, 0.0, (global_position - was_at).dot(along) / delta)
	if _wiggle < INF:
		_wiggle += delta
		if _wiggle >= WIGGLE_TIME:
			_wiggle = INF
			lunge(_pounce_at)
			if _voice and kind == Kind.PANTHER:
				_say(_voice, _snarl(), randf_range(0.92, 1.06))
	if _swipe < INF:
		_swipe += delta
		if _swipe >= SWIPE_TIME:
			_swipe = INF
	if _hiss < INF:
		_hiss += delta
		if _hiss >= HISS_TIME:
			_hiss = INF
	if _growl_left > 0.0:
		_growl_left -= delta
		if _growl_left <= 0.0 and _rumble:
			_rumble.stop()


## Stands it still where it is, with nothing in motion.
func settle() -> void:
	super()
	_wiggle = INF
	_swipe = INF


## Ears flat, mouth wide, lips off the fangs: a hiss and a spit.
func hiss() -> void:
	_hiss = 0.0
	hissed.emit()
	if _voice:
		_say(_voice, _hissing(), randf_range(0.9, 1.1) * (1.15 if kind == Kind.LYNX else 0.9))


func hissing() -> bool:
	return _hiss < INF


## How far into a hiss it is, 0..1 (1: none).
func hiss_progress() -> float:
	return _hiss / HISS_TIME if _hiss < INF else 1.0


## A low rumble for `seconds`, the lips lifting a little.
func growl(seconds := 2.0) -> void:
	_growl_left = seconds
	growled.emit()
	if _rumble:
		_say(_rumble, _growling(), randf_range(0.9, 1.05) * (1.3 if kind == Kind.LYNX else 1.0))


func growling() -> bool:
	return _growl_left > 0.0


## Wiggles, then springs at `at` (the dog's lunge, as far as brings it there
## within `lunge_reach`); `wiggle` off, it springs at once (from a run, as in a
## chase). Not while it pounces already.
func pounce(at: Vector3, wiggle := true) -> void:
	if _wiggle < INF or lunge_stage() != Lunge.NONE:
		return
	_pounce_at = at
	pounce_begun.emit(at)
	if wiggle:
		_wiggle = 0.0
		return
	lunge(at)
	if _voice and kind == Kind.PANTHER:
		_say(_voice, _snarl(), randf_range(0.92, 1.06))


## Wiggling before a pounce.
func wiggling() -> bool:
	return _wiggle < INF


func wiggle_progress() -> float:
	return _wiggle / WIGGLE_TIME if _wiggle < INF else 0.0


## Wiggling or springing.
func pouncing() -> bool:
	return _wiggle < INF or lunge_stage() != Lunge.NONE


## Where the pounce is aimed (in the world).
func pounce_target() -> Vector3:
	return _pounce_at


## Whether what it springs at is under its forepaws or its jaws now: late in
## the spring and as it lands on it, within `radius` (m, at a scale of 1) of
## the middle of its chest's front.
func pounce_hits(point: Vector3, radius := 0.6) -> bool:
	var stage := lunge_stage()
	if stage != Lunge.BITE and not (stage == Lunge.SPRING and lunge_progress() > 0.55):
		return false
	var front := rig.jaw_tip() if rig else global_position
	return front.distance_to(point) < radius * global_basis.get_scale().x or global_position.distance_to(point) < radius * 0.8 * global_basis.get_scale().x


## A forepaw raised and slashed at `at` (the one on that side). Not while it
## swipes or pounces already.
func swipe(at: Vector3) -> void:
	if _swipe < INF or pouncing():
		return
	_swipe = 0.0
	_swipe_at = at
	var local := global_transform.affine_inverse() * at
	_swipe_side = 0 if local.x >= 0.0 else 1
	swiped.emit(at)
	if _voice:
		_say(_voice, _hissing(), randf_range(1.2, 1.35))


func swiping() -> bool:
	return _swipe < INF


func swipe_progress() -> float:
	return _swipe / SWIPE_TIME if _swipe < INF else 0.0


## Which forepaw swipes: 0 its left, 1 its right.
func swipe_side() -> int:
	return _swipe_side


func swipe_target() -> Vector3:
	return _swipe_at


## Whether the swiping paw is on `point` now (as it strikes, within `radius` m
## at a scale of 1).
func swipe_hits(point: Vector3, radius := 0.55) -> bool:
	var u := swipe_progress()
	if _swipe == INF or u < STRIKE.x or u > STRIKE.y or rig == null:
		return false
	return (rig as BigCatRig).fore_paw(_swipe_side).distance_to(point) < radius * global_basis.get_scale().x


## Too taken up to do anything else: pouncing, swiping or shaking.
func busy() -> bool:
	return super() or pouncing() or swiping()


## How brightly its eyes give back the light, now.
func set_eyeshine(amount: float) -> void:
	eyeshine = amount
	if rig and rig.materials.has("parts"):
		(rig.materials["parts"] as ShaderMaterial).set_shader_parameter(&"eyeshine", amount)
	if rig:
		# (bright, in the dark: two points of light, seen from far off)
		(rig as BigCatRig).set_glow(maxf(amount - 0.8, 0.0) * 0.9)


func _say(speaker: AudioStreamPlayer3D, stream: AudioStreamWAV, pitch: float) -> void:
	speaker.stream = stream
	speaker.pitch_scale = pitch
	speaker.play()


# --- The voice, made in code ---

const RATE := 22050


func _hissing() -> AudioStreamWAV:
	if _hiss_sound.is_empty():
		for k in 2:
			_hiss_sound.append(BigCat._make_hiss(k))
	return _hiss_sound[randi() % _hiss_sound.size()]


func _growling() -> AudioStreamWAV:
	if _growl_sound.is_empty():
		for k in 2:
			_growl_sound.append(BigCat._make_growl(k))
	return _growl_sound[randi() % _growl_sound.size()]


func _snarl() -> AudioStreamWAV:
	if _snarl_sound.is_empty():
		_snarl_sound.append(BigCat._make_snarl(0))
	return _snarl_sound[0]


## A hiss: breath forced through the teeth, a hard spit at its start, falling away.
static func _make_hiss(which: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + which * 7
	var length := 0.9
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var high := Band.new(4200.0 + which * 500.0, 0.9, RATE)
	var throat := Band.new(1600.0, 1.8, RATE)
	for i in samples.size():
		var t := float(i) / RATE
		var u := t / length
		var noise := rng.randf_range(-1.0, 1.0)
		var spit := exp(-t * 38.0) * 1.6
		var envelope := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.45, 1.0, u)) * (0.85 + 0.15 * sin(t * 37.0))
		samples[i] = (high.run(noise) * 1.3 + throat.run(noise) * 0.4) * (envelope + spit)
	return _wav(samples)


## A growl: a low rough rumble, pulsing, with breath in it.
static func _make_growl(which: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 57 + which * 11
	var length := 2.4
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var body := Band.new(180.0, 1.2, RATE)
	var breath := Band.new(700.0, 1.0, RATE)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var u := t / length
		var f := 62.0 + 9.0 * sin(t * 1.7 + which) + rng.randf_range(-4.0, 4.0)
		phase += f / RATE
		# (a rough voice: its cycles each a little different, pulsing a couple of dozen times a second)
		var pulse := 0.55 + 0.45 * sin(TAU * (23.0 + which * 3.0) * t)
		var voice := (sin(TAU * phase) + 0.6 * sin(TAU * phase * 2.0) + 0.35 * sin(TAU * phase * 3.0)) * pulse
		var envelope := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.75, 1.0, u))
		samples[i] = (voice * 0.5 + body.run(voice + rng.randf_range(-0.4, 0.4)) * 1.4 + breath.run(rng.randf_range(-1.0, 1.0)) * 0.25) * envelope
	return _wav(samples)


## The panther's snarl as it springs: a short, harsh, coughing roar.
static func _make_snarl(_which: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var length := 0.55
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var throat := Band.new(420.0, 1.5, RATE)
	var rasp := Band.new(1900.0, 1.2, RATE)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var u := t / length
		var f := 140.0 + 90.0 * sin(PI * minf(u * 1.5, 1.0))
		phase += f / RATE
		var voice := sin(TAU * phase) + 0.5 * sin(TAU * phase * 2.0) + 0.3 * sin(TAU * phase * 3.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var envelope := smoothstep(0.0, 0.04, u) * pow(1.0 - u, 1.4)
		samples[i] = (throat.run(voice) * 1.2 + voice * 0.3 + rasp.run(noise) * 0.9) * envelope
	return _wav(samples)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## A resonant band-pass filter (a biquad), for the voice.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * minf(frequency, rate * 0.45) / rate
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
