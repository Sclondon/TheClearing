class_name Horse
extends Node3D
## A feral horse that has been out a long time: a little thin (the hips and the
## ribs show), its mane and tail long and tangled, in a muted coat (a dappled
## grey, a dun, a dark bay), with or without an old rope halter and a frayed end
## of lead rope. Its look and every move are here; what it does is for the game
## to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks,
## trots, canters or gallops to match, each on its true footfalls (HorseRig).
## Set `grounded` false while it is falling. Scale it to make it bigger.
##
## Then say what it is doing (each eases in and out): `look_at_point`,
## `grazing`, `alert`, `fleeing`, `spooked`, `dozing`, `friendly`. And the
## moves: `stamp()`, `snort()`, `whinny()` (a long call that carries),
## `nicker()` (a soft low one, close by), `shake()`, `roll()` (about 9 s: down,
## over onto its back, up again), `twitch(point)` (the skin shivering there).
##
## Signals say when it stamps, snorts, whinnies; with `sound` on it makes the
## sounds too (made in code, nothing to load), its hooves among them.

signal stamped
signal snorted
signal whinnied

enum Coat { GREY, DUN, BAY }

## Seconds a whinny takes.
const WHINNY_TIME := 1.7

@export var coat := Coat.DUN
## An old rope halter, and a frayed end of lead rope. Set before it enters the tree.
@export var haltered := false
@export var low_poly := false
@export_range(0, 3) var fur_shells := 1
@export var coat_tint := Color.WHITE
@export_range(0.0, 3.0) var eyeshine := 0.25
@export var measure_velocity := true
@export var sound := true
@export var volume_db := -4.0

var velocity := Vector3.ZERO
var grounded := true
var look_at_point := Vector3.INF
var grazing := false
var alert := false
var fleeing := false
var spooked := false
var dozing := false
var friendly := false
## How hard it is blowing (0..1), set by the rig.
var heavy := 0.0
var rig: HorseRig

var _was_at := Vector3.INF
var _whinny_left := 0.0
var _voice: AudioStreamPlayer3D
var _call: AudioStreamPlayer3D
var _hooves: AudioStreamPlayer3D
static var _sounds := {}


func _ready() -> void:
	rig = HorseRig.new()
	rig.name = "Rig"
	rig.model_path = model_path()
	rig.coat = coat
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.eyeshine = eyeshine
	add_child(rig)
	if sound:
		_voice = _player(8.0, 60.0, volume_db)
		_call = _player(30.0, 260.0, volume_db + 2.0)
		_hooves = _player(5.0, 40.0, volume_db - 6.0)
		_hooves.max_polyphony = 4
		rig.footfall.connect(_on_footfall)


func _player(unit: float, far: float, db: float) -> AudioStreamPlayer3D:
	var made := AudioStreamPlayer3D.new()
	made.unit_size = unit * scale.x
	made.max_distance = far
	made.volume_db = db
	made.position = Vector3(0.0, 1.5, 0.7)
	add_child(made)
	return made


func model_path() -> String:
	return "res://creatures/horse/models/horse%s%s.glb" % ["_haltered" if haltered else "", "_lo" if low_poly else ""]


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _whinny_left > 0.0:
		_whinny_left -= delta
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-12.0 * delta))
		_was_at = at


func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func stamp() -> void:
	if rig:
		rig.stamp()
	stamped.emit()
	_play(_voice, _sound("stamp"), randf_range(0.9, 1.1))


func snort() -> void:
	if rig:
		rig.snort()
	snorted.emit()
	_play(_voice, _sound("snort"), randf_range(0.9, 1.05))


## Calls out: a long whinny that carries far across the maze.
func whinny() -> void:
	_whinny_left = WHINNY_TIME
	whinnied.emit()
	_play(_call, _sound("whinny"), randf_range(0.95, 1.04))


func whinnying() -> bool:
	return _whinny_left > 0.0


func whinny_progress() -> float:
	return 1.0 - _whinny_left / WHINNY_TIME if _whinny_left > 0.0 else 0.0


func nicker() -> void:
	if rig:
		rig.nicker()
	_play(_voice, _sound("nicker"), randf_range(0.95, 1.05))


func shake() -> void:
	if rig:
		rig.shake()


func roll() -> void:
	if rig:
		rig.roll()


func twitch(point: Vector3) -> void:
	if rig:
		rig.twitch(point)


func rolling() -> bool:
	return rig != null and rig.rolling()


func shaking() -> bool:
	return rig != null and rig.shaking()


func busy() -> bool:
	return (rig != null and rig.busy()) or whinnying()


func nose_position() -> Vector3:
	return rig.nose() if rig else global_position


## Where a rider would sit, in the world.
func seat() -> Transform3D:
	return global_transform * rig.seat_local() if rig else global_transform


func _on_footfall(_leg: int) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.8 or _hooves == null or not _hooves.is_inside_tree():
		return
	_hooves.stream = _sound("hoof")
	_hooves.volume_db = volume_db - 14.0 + minf(speed, 10.0) * 1.0
	_hooves.pitch_scale = randf_range(0.85, 1.15)
	_hooves.play()


func _play(player: AudioStreamPlayer3D, stream: AudioStream, pitch := 1.0) -> void:
	if player == null or not player.is_inside_tree():
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


static func _sound(kind: String) -> AudioStreamWAV:
	if not _sounds.has(kind):
		match kind:
			"whinny":
				_sounds[kind] = whinny_sound()
			"nicker":
				_sounds[kind] = _pulsed(0.75, 130.0, 22.0, 3)
			"snort":
				_sounds[kind] = _blow(0.5, 1700.0, 6)
			_:
				_sounds[kind] = _thud(0.16 if kind == "hoof" else 0.22, 85.0 if kind == "hoof" else 95.0)
	return _sounds[kind]


## The whinny: a high squeal breaking in, falling away in a long shuddering
## run ("hee-hee-hee-hee"), down into low nickering at its end. Made once.
static func whinny_sound() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * WHINNY_TIME)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var samples := PackedFloat32Array()
	samples.resize(count)
	var nasal := Band.new(1300.0, 3.0, rate)
	var upper := Band.new(2700.0, 4.0, rate)
	var low := Band.new(500.0, 2.0, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var pitch := 950.0 + 450.0 * smoothstep(0.0, 0.12, t) - 820.0 * smoothstep(0.15, 1.25, t)
		pitch *= 1.0 + 0.09 * sin(TAU * 11.0 * t) * smoothstep(0.2, 0.4, t)
		pitch = maxf(pitch, 150.0)
		phase += pitch / rate
		var saw := 0.0
		for h in range(1, 6):
			saw += sin(TAU * phase * h) / h
		var shudder := 0.6 + 0.4 * sin(TAU * 11.0 * t) if t > 0.3 else 1.0
		var env := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(1.45, WHINNY_TIME, t)) * shudder
		var breath := rng.randf_range(-1.0, 1.0) * 0.3
		var value := (nasal.run(saw + breath) * 1.3 + upper.run(saw) * 0.6 + low.run(saw) * 0.5 * smoothstep(0.9, 1.3, t)) * env
		samples[i] = tanh(value * 1.4)
		loudest = maxf(loudest, absf(samples[i]))
	return _wav(samples, loudest, rate)


static func _pulsed(length: float, pitch: float, pulse_rate: float, seed_value: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var samples := PackedFloat32Array()
	samples.resize(count)
	var hum := Band.new(400.0, 2.0, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		phase += pitch * (1.0 - 0.2 * t / length) / rate
		var pulse := pow(0.5 + 0.5 * sin(TAU * pulse_rate * t), 3.0)
		var value := hum.run(sin(TAU * phase) + 0.4 * sin(TAU * phase * 2.0) + rng.randf_range(-0.2, 0.2)) * pulse * sin(PI * t / length)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	return _wav(samples, loudest, rate)


static func _blow(length: float, centre: float, seed_value: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var samples := PackedFloat32Array()
	samples.resize(count)
	var hiss := Band.new(centre, 1.2, rate)
	var body := Band.new(500.0, 2.0, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var air := smoothstep(0.0, 0.015, t) * exp(-t * 7.0)
		var flutter := 0.7 + 0.3 * sin(TAU * 30.0 * t)
		var n := rng.randf_range(-1.0, 1.0)
		var value := (hiss.run(n) * 0.8 + body.run(n) * 1.2) * air * flutter
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	return _wav(samples, loudest, rate)


static func _thud(length: float, pitch: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var samples := PackedFloat32Array()
	samples.resize(count)
	var click := Band.new(1800.0, 2.0, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := sin(TAU * (pitch - 40.0 * t / length) * t) * exp(-t * 28.0) + click.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 90.0) * 0.5
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	return _wav(samples, loudest, rate)


static func _wav(samples: PackedFloat32Array, loudest: float, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 26000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	made.data = data
	return made


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * clampf(frequency, 20.0, rate * 0.45) / rate
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
