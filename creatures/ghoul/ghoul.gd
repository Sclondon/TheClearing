class_name Ghoul
extends Node3D
## A ghoul: a mummy with nothing left on, after the ReDeads of Zelda. Raw,
## dried red-brown flesh on a starved, hunched frame, arms to its knees, and a
## skull under skin made into a mask: deep dark eyes under a heavy brow, a long
## slack jaw with the mouth open low in it. It stands like a statue until it is
## woken; then it shuffles, screams (a ragged shriek that is meant to root
## whoever hears it to the spot), rushes, and grabs, hugging them to it.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## drives it. Put it where the creature is each frame and say how fast it is
## going, and call `scream()` and `grab()`; it tells you when the shriek goes
## out (`shrieked`) and whether a grab closes on a point (`grab_hits`).
##
##     var ghoul := Ghoul.new()
##     ghoul.scale = Vector3.ONE * 1.6       # modelled about 1.4 m tall
##     add_child(ghoul)
##     # each frame:
##     ghoul.global_position = body_position
##     ghoul.rotation.y = facing_yaw          # 0 faces +Z
##     ghoul.velocity = body_velocity         # world units a second
##     ghoul.awake = true                     # false: a statue
##     ghoul.aim = player_position + Vector3.UP # what it looks at and reaches for (INF: nothing)
##     ghoul.reaching = 1.0                    # how far its arms come up for `aim` when it is near
##     # when you like:
##     ghoul.scream()                         # `shrieked` is emitted at the top of it
##     ghoul.grab()                           # test `grab_hits(point)` while `stage()` is CLOSE
##     ghoul.held = true                      # it has them: it clings instead of hugging the air
##
## It is posed by GhoulRig (ghoul_rig.gd), which extends CharacterRig: it needs
## GameCommon's character-controller (CharacterRig, Player, Toon, Dust,
## Settings). The model is creatures/ghoul/models/ghoul.glb (and ghoul_lo.glb),
## made by creatures/ghoul/tools/build_ghoul.py in Blender.

## The shriek has gone out (the top of a scream): whoever is to be held by it is held now.
signal shrieked
## The arms of a grab have begun to close: test `grab_hits` from now until `stage()` is no longer CLOSE.
signal closing

const MODEL := "res://creatures/ghoul/models/ghoul.glb"
const MODEL_LO := "res://creatures/ghoul/models/ghoul_lo.glb"

## Use the low-poly model.
@export var low_poly := false
## Its shriek, made in code, from where it stands.
@export var sound := true
## How loud the shriek is, and how far off it is heard (world units).
@export var volume_db := 4.0
@export var sound_range := 60.0

## How fast it is going, world units a second. Its feet go with this.
var velocity := Vector3.ZERO
## Whether it is on the ground (off it, its legs hang).
var grounded := true
## A statue (false) or about (true). It wakes and falls still over a moment.
var awake := false
## What it looks at and reaches for, in the world (INF: nothing).
var aim := Vector3.INF
## How far its arms come up for `aim` when it is near to it, 0..1.
var reaching := 1.0
## In a grab: whether it has hold of someone.
var held := false:
	set(value):
		held = value
		if _rig:
			_rig.held = value

## For the rig, which reads its body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.55 * global_basis.get_scale().y
var run_speed: float:
	get:
		return walk_speed * 3.0

var _rig: GhoulRig
var _voice: AudioStreamPlayer3D
var _shrieked := true
var _closing := true
static var _shriek: AudioStreamWAV


func _ready() -> void:
	_rig = GhoulRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.2
	add_child(_rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = shriek_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 8.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.3, 0.1)
		add_child(_voice)


func is_on_floor() -> bool:
	return grounded


func _process(_delta: float) -> void:
	_rig.awake = 1.0 if awake else 0.0
	_rig.aim = aim
	_rig.arms_reach = reaching
	var t := _rig.act_time()
	if not _shrieked and _rig._doing == GhoulRig.Act.SCREAM and t >= GhoulRig.SCREAM_RISE:
		_shrieked = true
		shrieked.emit()
	if not _closing and _rig._doing == GhoulRig.Act.GRAB and t >= GhoulRig.REACH:
		_closing = true
		closing.emit()


## Throws its head back and shrieks. `shrieked` is emitted when the sound goes
## out (SCREAM_RISE seconds on); the whole takes `act_length(GhoulRig.Act.SCREAM)`.
func scream() -> void:
	_rig.act(GhoulRig.Act.SCREAM)
	_shrieked = false
	if _voice:
		_voice.play()


## Throws its arms wide and hugs them closed in front of it. `closing` is
## emitted as they close (REACH seconds on); then, while `stage()` is CLOSE,
## `grab_hits` says whether a point is within them.
func grab() -> void:
	_rig.act(GhoulRig.Act.GRAB)
	_closing = false
	held = false


## What it is doing: GhoulRig.Act.NONE, SCREAM or GRAB.
func doing() -> GhoulRig.Act:
	return _rig._doing if _rig else GhoulRig.Act.NONE


## Where it is in what it is doing.
func stage() -> GhoulRig.Stage:
	return _rig.stage() if _rig else GhoulRig.Stage.NONE


func busy() -> bool:
	return doing() != GhoulRig.Act.NONE


## How long a scream or a grab takes, seconds.
static func act_length(what: GhoulRig.Act) -> float:
	match what:
		GhoulRig.Act.SCREAM:
			return GhoulRig.SCREAM_RISE + GhoulRig.SCREAMING + GhoulRig.SCREAM_FALL
		GhoulRig.Act.GRAB:
			return GhoulRig.REACH + GhoulRig.CLOSE + GhoulRig.HOLD + GhoulRig.LET_GO
	return 0.0


## Whether a point (in the world) is taken by its arms as they close: in front
## of it, within the reach of its arms and the height of its body, `radius`
## (world units) more all round. Only while `stage()` is CLOSE (or `always`).
func grab_hits(point: Vector3, radius := 0.25, always := false) -> bool:
	if not always and stage() != GhoulRig.Stage.CLOSE:
		return false
	var size := global_basis.get_scale().y
	var at := global_transform.affine_inverse() * point
	var r := radius / size
	return at.z > -0.05 - r and at.z < 0.85 + r and absf(at.x) < 0.42 + r and at.y > -r and at.y < 1.45 + r


## Where its mouth is in the world, for anything that should see it scream.
func mouth() -> Vector3:
	return to_global(Vector3(0.0, 1.28, 0.08))


## Puts it straight somewhere, standing still as it is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if _rig:
		_rig.awake = 1.0 if awake else 0.0
		_rig.settle()


## The shriek, made once and shared: a ragged, human-ish scream torn out of a
## dry throat. A choked gasp in first; then a strained voice (a train of
## glottal pulses, each a little off in time and loudness, every other one weak
## where the throat rattles) through the resonances of an open "aah", with as
## much breath as voice in it, pushed until it distorts. Its pitch strains
## upwards, wavers, and cracks (jumps up and falls back) more than once; it
## sags at the end and dies in a rattle of slow clicks.
static func shriek_sound() -> AudioStreamWAV:
	if _shriek:
		return _shriek
	var rate := 22050
	var length := 1.75
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var samples := PackedFloat32Array()
	samples.resize(count)
	var formants: Array[Band] = [Band.new(820.0, 4.0, rate), Band.new(1500.0, 5.0, rate), Band.new(2750.0, 6.0, rate), Band.new(3900.0, 5.0, rate)]
	var gains := [1.0, 0.75, 0.5, 0.25]
	var breath := Band.new(3200.0, 1.2, rate)
	var gasp := Band.new(1400.0, 2.0, rate)
	var low := 0.0
	var phase := 0.0
	var pulse_gain := 1.0
	var odd := false
	var wander := 0.0
	# Where its voice breaks: (when, how long, by how much)
	var cracks := [Vector3(0.52, 0.07, 1.42), Vector3(0.83, 0.11, 1.6), Vector3(1.04, 0.05, 1.33), Vector3(1.19, 0.09, 0.62)]
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		# The gasp: air dragged in through a closing throat, and caught.
		if t < 0.27:
			var air := sin(PI * clampf((t - 0.02) / 0.22, 0.0, 1.0)) * 0.55
			gasp.set_frequency(1100.0 + 2200.0 * t / 0.27, 2.0)
			value += gasp.run(rng.randf_range(-1.0, 1.0)) * air
		# The voice
		var voice_in := smoothstep(0.26, 0.31, t) * (1.0 - smoothstep(1.28, 1.42, t))
		var rattle := smoothstep(1.3, 1.42, t) * (1.0 - smoothstep(1.6, length, t))
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		var pitch := 470.0 + 270.0 * smoothstep(0.27, 0.6, t) - 230.0 * smoothstep(0.95, 1.38, t)
		pitch *= 1.0 + 0.07 * wander + 0.03 * sin(t * TAU * 5.3 + 2.0 * sin(t * TAU * 1.7))
		for crack: Vector3 in cracks:
			if t > crack.x and t < crack.x + crack.y:
				pitch *= crack.z
		# (the rattle: the voice gone, the throat clicking ever slower)
		pitch = lerpf(pitch, lerpf(48.0, 17.0, smoothstep(1.4, length, t)), rattle)
		var before := phase
		phase += pitch / rate * (1.0 + rng.randf_range(-0.03, 0.03))
		if floorf(phase) != floorf(before):
			odd = not odd
			pulse_gain = rng.randf_range(0.75, 1.05) * (0.55 if odd and t > 0.9 else 1.0)
		var p := fposmod(phase, 1.0)
		# (a glottal pulse: a sharp opening and a slower close, rich in overtones)
		var pulse := (pow(1.0 - p, 4.0) * 2.0 - 0.4) * pulse_gain
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var noise := breath.run(rng.randf_range(-1.0, 1.0)) * (0.5 + 0.5 * (1.0 - p))
		value += (throat * 2.2 + noise * 0.9) * voice_in
		low = lerpf(low, pulse, 0.08)
		value += (low * 0.7 + throat * 0.25) * rattle
		# (pushed too hard for the throat: it tears)
		value = tanh(value * 2.4)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	_shriek = AudioStreamWAV.new()
	_shriek.format = AudioStreamWAV.FORMAT_16_BITS
	_shriek.mix_rate = rate
	_shriek.data = data
	return _shriek


## A resonant band-pass filter (a biquad), for the shriek.
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
