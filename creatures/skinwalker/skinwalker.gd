class_name Skinwalker
extends Node3D
## A skinwalker, as horror stories tell it: something wearing a coyote's skin.
## On all fours it passes for a coyote, if you do not look closely: too big,
## its joints bending the wrong ways, its eyes shining too much. Then it rises
## on long, gaunt, too-human legs, the coyote's hide hanging down its back, the
## coyote's head worn as a mask over a pale human face, long thin arms with
## fingers far too long; and it moves wrongly, in jerks and bursts.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## drives it. Put it where the creature is each frame and say how fast it is
## going and how it holds itself; call `rise()`, `drop()`, `call_out()` and
## `grab()` when it should.
##
##     var walker := Skinwalker.new()
##     walker.scale = Vector3.ONE * 1.25       # modelled about 1.7 units tall standing
##     add_child(walker)
##     walker.put(spawn_point, spawn_yaw)
##     # each frame:
##     walker.global_position = body_position
##     walker.rotation.y = facing_yaw          # 0 faces +Z
##     walker.velocity = body_velocity         # its limbs go with this: a crawl, a bound
##     walker.aim = player_head                # what it watches (INF: nothing)
##     walker.crouch = 1.0                     # flat down for a burst (the wind-up)
##     walker.glare = 1.0                      # how brightly its eyes shine
##     # when you like:
##     walker.rise()                           # up onto its legs (RISE_TIME); `risen` when up
##     walker.drop()                           # back down on all fours
##     walker.call_out()                       # its mimicked call (made in code), head tipped over
##     walker.grab()                           # arms flung forward; test grab_hits(point)
##
## It is posed by SkinwalkerRig (skinwalker_rig.gd), which extends CharacterRig
## (GameCommon's character-controller: CharacterRig, Toon, Settings), and the
## coyote's skin is furred with CoyoteLook (godot/coyote, which needs godot/dog).
## The model is creatures/skinwalker/models/skinwalker.glb (and _lo), made by
## creatures/skinwalker/tools/build_skinwalker.py in Blender.
##
## ITS CALLS are made in code, here: nobody's real voice is in them. A coyote's
## yip that turns into a human "aah"; a breathy "hey?" in a child's pitch that
## comes out wrong; a "hel-lo" that sags and draws out at its end. Each is a
## glottal buzz through the resonances of the vowels, pitched and bent, a
## little detuned against itself, with an echo.

## Up on its legs (the end of a rise).
signal risen
## Its call has gone out (from `mouth()`).
signal called

const MODEL := "res://creatures/skinwalker/models/skinwalker.glb"
const MODEL_LO := "res://creatures/skinwalker/models/skinwalker_lo.glb"
## How many different calls it has.
const CALLS := 3

@export var low_poly := false
## Its calls and its rise, made in code, from where it is.
@export var sound := true
@export var volume_db := 2.0
@export var sound_range := 70.0

## How fast it is going, world units a second. Its limbs go with this.
var velocity := Vector3.ZERO
var grounded := true
## What it watches, in the world (INF: nothing).
var aim := Vector3.INF
## Flat down for a burst (the wind-up), 0..1.
var crouch := 0.0
## How brightly its eyes shine, 0..1.
var glare := 0.15

## For the rig, which reads its body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.6 * global_basis.get_scale().y
var run_speed: float:
	get:
		return walk_speed * 3.0

var _rig: SkinwalkerRig
var _voice: AudioStreamPlayer3D
var _upright := false
var _was_rising := false

static var _calls: Array[AudioStreamWAV] = []
static var _rise_sound: AudioStreamWAV


func _ready() -> void:
	_rig = SkinwalkerRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.2
	add_child(_rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 9.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.4, 0.1)
		add_child(_voice)


func is_on_floor() -> bool:
	return grounded


func _process(_delta: float) -> void:
	_rig.upright = _upright
	_rig.aim = aim
	_rig.crouch = crouch
	_rig.glare = glare
	var rising := _rig.doing() == SkinwalkerRig.Act.RISE
	if _was_rising and not rising and _upright:
		risen.emit()
	_was_rising = rising


## Rises up onto its legs (SkinwalkerRig.RISE_TIME); `risen` when it is up.
func rise() -> void:
	if _upright:
		return
	_upright = true
	_rig.act(SkinwalkerRig.Act.RISE)
	_play(rise_sound())


## Down on all fours again.
func drop() -> void:
	if not _upright:
		return
	_upright = false
	_rig.act(SkinwalkerRig.Act.DROP)


func is_upright() -> bool:
	return _upright


## How far up it is now, 0 (on all fours) .. 1 (standing).
func how_upright() -> float:
	return _rig.how_upright() if _rig else 0.0


func rising() -> bool:
	return _rig != null and _rig.doing() == SkinwalkerRig.Act.RISE


## Its mimicked call (`which`, 0 .. CALLS - 1; -1 any): the head tipped right over.
func call_out(which := -1) -> void:
	if which < 0:
		which = randi() % CALLS
	if _rig.doing() == SkinwalkerRig.Act.NONE:
		_rig.act(SkinwalkerRig.Act.CALL)
	_play(call_sound(which % CALLS), randf_range(0.94, 1.04))
	called.emit()


## Both arms flung forward, the fingers spread (SkinwalkerRig.GRAB_TIME).
func grab() -> void:
	_rig.act(SkinwalkerRig.Act.GRAB)


func busy() -> bool:
	return _rig != null and _rig.doing() != SkinwalkerRig.Act.NONE


## Whether a point (in the world) is within its reach as it grabs: in front of
## it, within its arms' length, `radius` more all round.
func grab_hits(point: Vector3, radius := 0.3) -> bool:
	var size := global_basis.get_scale().y
	var at := global_transform.affine_inverse() * point
	var r := radius / size
	var high := lerpf(0.7, 1.6, how_upright())
	return at.z > -0.1 - r and at.z < 1.0 + r and absf(at.x) < 0.45 + r and at.y > -r and at.y < high + r


## Where its face is, in the world.
func mouth() -> Vector3:
	return _rig._head.global_position if _rig and _rig._head else to_global(Vector3(0.0, 1.5, 0.1))


## Puts it straight somewhere, as it is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if _rig:
		_rig.upright = _upright
		_rig.settle()


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()


# --- Its sounds, made in code ---

const RATE := 22050
## Vowels: their first three resonances (Hz), for a child-sized throat.
const VOWELS := {
	"a": Vector3(850.0, 1250.0, 2800.0), "e": Vector3(620.0, 2100.0, 2900.0), "i": Vector3(330.0, 2700.0, 3400.0),
	"o": Vector3(640.0, 980.0, 2800.0), "u": Vector3(360.0, 1000.0, 2600.0), "l": Vector3(420.0, 1100.0, 2800.0),
}


## One of its calls (see the class's notes), made once and shared.
static func call_sound(which: int) -> AudioStreamWAV:
	while _calls.size() < CALLS:
		_calls.append(_make_call(_calls.size()))
	return _calls[which]


## The rise: joints cracking, irregular, and a long wet breath dragged in.
static func rise_sound() -> AudioStreamWAV:
	if _rise_sound:
		return _rise_sound
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var length := 2.0
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var breath := Band.new(700.0, 1.5, RATE)
	var t := 0.08
	var cracks: Array[float] = []
	while t < 1.6:
		cracks.append(t)
		t += rng.randf_range(0.05, 0.28)
	for i in samples.size():
		var s := float(i) / RATE
		var drawn := smoothstep(0.3, 1.0, s) * (1.0 - smoothstep(1.6, 2.0, s))
		breath.set_frequency(500.0 + 900.0 * smoothstep(0.3, 1.7, s), 1.6)
		samples[i] = breath.run(rng.randf_range(-1.0, 1.0)) * drawn * 0.6
	for at in cracks:
		var ring := Band.new(rng.randf_range(900.0, 2600.0), 6.0, RATE)
		var start := int(at * RATE)
		var loud := rng.randf_range(0.5, 1.0)
		for k in int(0.05 * RATE):
			if start + k >= samples.size():
				break
			var u := float(k) / (0.05 * RATE)
			var click := rng.randf_range(-1.0, 1.0) * pow(1.0 - u, 6.0)
			samples[start + k] += (click * 0.8 + ring.run(click) * 2.5) * loud
	_rise_sound = _wav(samples)
	return _rise_sound


static func _make_call(which: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + which * 31
	# (what is said: a list of (vowel, seconds, pitch at its start, pitch at its end, breath))
	var parts: Array = []
	match which:
		0:
			# A coyote's yip that turns into a human "aah", sagging
			parts = [["yip", 0.13, 900.0, 1500.0, 0.2], ["a", 0.5, 640.0, 210.0, 0.3], ["a", 0.25, 210.0, 150.0, 0.7]]
		1:
			# "hey?": a breath, then e gliding to i, rising like a question, cut off
			parts = [["h", 0.09, 260.0, 260.0, 1.0], ["e", 0.22, 255.0, 270.0, 0.25], ["i", 0.18, 270.0, 330.0, 0.25]]
		2:
			# "hel-lo": the second half sags and draws out far too long
			parts = [["h", 0.07, 250.0, 250.0, 1.0], ["e", 0.13, 245.0, 250.0, 0.25], ["l", 0.07, 245.0, 235.0, 0.2],
					["o", 0.32, 240.0, 205.0, 0.25], ["u", 0.55, 205.0, 120.0, 0.5]]
	var length := 0.12
	for part: Array in parts:
		length += part[1]
	length += 0.55
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var bands: Array[Band] = [Band.new(600.0, 5.0, RATE), Band.new(1500.0, 7.0, RATE), Band.new(2800.0, 8.0, RATE)]
	var air := Band.new(2500.0, 1.3, RATE)
	var phase := 0.0
	var second := 0.0
	var at := 0.05
	var formants := VOWELS["e"] as Vector3
	for k in parts.size():
		var part: Array = parts[k]
		var kind: String = part[0]
		var seconds: float = part[1]
		var next: Array = parts[k + 1] if k + 1 < parts.size() else part
		var aim_vowel: Vector3 = VOWELS.get(kind, VOWELS.get(next[0], VOWELS["a"]))
		var start := int(at * RATE)
		for i in int(seconds * RATE):
			var index := start + i
			if index >= samples.size():
				break
			var u := float(i) / (seconds * RATE)
			var pitch := lerpf(part[2], part[3], u) * (1.0 + 0.025 * sin(TAU * 4.7 * (at + u * seconds)))
			# (wrong: a second voice a little off, beating against the first)
			phase += pitch / RATE
			second += pitch * 1.013 / RATE
			formants = formants.lerp(aim_vowel, 0.004)
			for b in 3:
				bands[b].set_frequency(formants[b], 6.0 + b)
			var pulse := (pow(1.0 - fposmod(phase, 1.0), 4.0) * 2.0 - 0.4) + 0.5 * (pow(1.0 - fposmod(second, 1.0), 4.0) * 2.0 - 0.4)
			var voice := 0.0
			if kind == "yip":
				for h in 5:
					voice += sin(TAU * phase * (h + 1)) / (h + 1)
				voice *= 0.6
			else:
				voice = bands[0].run(pulse) * 1.0 + bands[1].run(pulse) * 0.7 + bands[2].run(pulse) * 0.35
			var breath: float = part[4]
			var hiss := air.run(rng.randf_range(-1.0, 1.0))
			if kind == "h":
				voice = 0.0
			var edge := smoothstep(0.0, 0.08, u) if k == 0 else 1.0
			if k == parts.size() - 1:
				edge *= 1.0 - smoothstep(0.75, 1.0, u)
			samples[index] += (voice * (1.0 - breath * 0.6) * 2.2 + hiss * breath * 1.4) * edge
		at += seconds
	# (not quite a voice: a slow flutter through it, and the walls throwing it back)
	for i in samples.size():
		samples[i] *= 0.8 + 0.2 * sin(TAU * 31.0 * i / RATE)
	var out := samples.duplicate()
	for echo: Vector2 in [Vector2(0.13, 0.35), Vector2(0.29, 0.18), Vector2(0.47, 0.09)]:
		var gap := int(echo.x * RATE)
		for i in range(gap, out.size()):
			out[i] += samples[i - gap] * echo.y
	return _wav(out)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 29000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## A resonant band-pass filter (a biquad).
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
		var w := TAU * minf(frequency, _rate * 0.45) / _rate
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
