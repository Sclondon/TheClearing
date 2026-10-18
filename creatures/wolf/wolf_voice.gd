class_name WolfVoice
## A grey wolf's voice (Wolf), made in code: nothing to load.
##
## - HOWLS: a wolf's howl is nearly a pure tone (a few weak harmonics over it)
##   that glides: it swoops up at the start, holds long and wavering, sometimes
##   breaks up a step and back (a yodel), and falls away at its end. The mouth
##   opens from an "oo" through an "ah" and closes again, so the tone brightens
##   and dulls with it. Five long ones and two short rallying ones, each its own
##   rise and fall; several at once, at different pitches, gliding past each
##   other, is a pack's chorus. A little of the hall's echo goes with each.
## - WOOF: the soft, deep "huff" of an alarm bark. GROWL: a low, rough rumble.
##
## Each sound is made the first time it is wanted (`want`), a little every frame
## (`bake_some`: BUDGET samples a frame), and kept for every wolf after: so
## making them never holds up a frame. `make_now` makes one at once (for tests).

const RATE := 16000
## How many samples are made a frame, at most.
const BUDGET := 1200
## Every sound, by name.
const KEYS: Array[String] = ["howl0", "howl1", "howl2", "howl3", "howl4", "rally0", "rally1", "woof", "growl"]
## Each howl: how long (s); its pitch over it (pairs: how far through it, Hz);
## how open the mouth is (pairs: how far through, 0..1); and its breaks (each:
## how far through, how long in seconds, how far up it jumps).
const PLANS := {
	"howl0": {"length": 4.6, "pitch": [0.0, 330.0, 0.12, 520.0, 0.5, 560.0, 0.86, 470.0, 1.0, 380.0],
		"open": [0.0, 0.1, 0.16, 0.85, 0.6, 0.6, 1.0, 0.2], "breaks": []},
	"howl1": {"length": 5.0, "pitch": [0.0, 280.0, 0.15, 400.0, 0.5, 415.0, 0.9, 370.0, 1.0, 330.0],
		"open": [0.0, 0.1, 0.2, 0.7, 0.7, 0.55, 1.0, 0.15], "breaks": [[0.52, 0.55, 1.18]]},
	"howl2": {"length": 4.0, "pitch": [0.0, 430.0, 0.1, 650.0, 0.45, 680.0, 0.8, 640.0, 1.0, 520.0],
		"open": [0.0, 0.15, 0.12, 0.9, 0.7, 0.7, 1.0, 0.25], "breaks": []},
	"howl3": {"length": 4.4, "pitch": [0.0, 350.0, 0.2, 470.0, 0.55, 500.0, 0.9, 450.0, 1.0, 370.0],
		"open": [0.0, 0.12, 0.22, 0.8, 0.6, 0.65, 1.0, 0.2], "breaks": [[0.38, 0.22, 1.24], [0.66, 0.18, 1.2]]},
	"howl4": {"length": 3.8, "pitch": [0.0, 450.0, 0.08, 600.0, 0.3, 590.0, 0.85, 430.0, 1.0, 340.0],
		"open": [0.0, 0.2, 0.1, 0.9, 0.5, 0.6, 1.0, 0.15], "breaks": []},
	"rally0": {"length": 1.6, "pitch": [0.0, 380.0, 0.25, 560.0, 0.7, 540.0, 1.0, 440.0],
		"open": [0.0, 0.2, 0.3, 0.9, 1.0, 0.3], "breaks": []},
	"rally1": {"length": 1.8, "pitch": [0.0, 330.0, 0.3, 500.0, 0.75, 490.0, 1.0, 410.0],
		"open": [0.0, 0.2, 0.3, 0.85, 1.0, 0.3], "breaks": [[0.5, 0.15, 1.15]]},
	"woof": {"length": 0.34},
	"growl": {"length": 1.5},
}
## The walls' echo after a howl: (seconds later, how loud).
const ECHOES: Array[Vector2] = [Vector2(0.13, 0.3), Vector2(0.29, 0.19), Vector2(0.53, 0.11), Vector2(0.81, 0.06)]

static var _made := {}
static var _queue: Array[String] = []
static var _job: Job
static var _frame := -1
static var _bright := PackedFloat32Array()
static var _dull := PackedFloat32Array()


static func ready(key: String) -> bool:
	return _made.has(key)


## Asks for a sound to be made (a little each frame, by `bake_some`).
static func want(key: String) -> void:
	if _made.has(key) or _queue.has(key) or (_job and _job.key == key):
		return
	_queue.append(key)


static func stream(key: String) -> AudioStreamWAV:
	return _made.get(key)


static func length(key: String) -> float:
	return float(PLANS[key]["length"])


## How open the mouth is `seconds` into a howl, 0..1.
static func openness(key: String, seconds: float) -> float:
	var plan: Dictionary = PLANS[key]
	if not plan.has("open"):
		return 0.0
	return _keyed(plan["open"], seconds / float(plan["length"]))


## Makes some of what is wanted (once a frame, however many wolves call it).
static func bake_some() -> void:
	var frame := Engine.get_process_frames()
	if frame == _frame:
		return
	_frame = frame
	if _job == null:
		if _queue.is_empty():
			return
		_job = Job.new(_queue.pop_front())
	if _job.run(BUDGET):
		_made[_job.key] = _job.made
		_job = null


## Makes a sound at once (and keeps it).
static func make_now(key: String) -> AudioStreamWAV:
	if not _made.has(key):
		var job := Job.new(key)
		while not job.run(1 << 30):
			pass
		_made[key] = job.made
		_queue.erase(key)
	return _made[key]


## A drawn curve: (where, value) pairs, eased between.
static func _keyed(keys: Array, at: float) -> float:
	if at <= keys[0]:
		return keys[1]
	var k := 0
	while k + 2 < keys.size() and at > keys[k + 2]:
		k += 2
	if k + 2 >= keys.size():
		return keys[keys.size() - 1]
	var u: float = (at - keys[k]) / maxf(keys[k + 2] - keys[k], 0.0001)
	return lerpf(keys[k + 1], keys[k + 3], smoothstep(0.0, 1.0, u))


static func _tables() -> void:
	if not _bright.is_empty():
		return
	_bright.resize(1024)
	_dull.resize(1024)
	var bright: Array[float] = [1.0, 0.42, 0.22, 0.12, 0.06, 0.03]
	var dull: Array[float] = [1.0, 0.16, 0.05, 0.015]
	for i in 1024:
		var a := TAU * i / 1024.0
		var b := 0.0
		for k in bright.size():
			b += sin(a * (k + 1)) * bright[k]
		var d := 0.0
		for k in dull.size():
			d += sin(a * (k + 1)) * dull[k]
		_bright[i] = b / 1.6
		_dull[i] = d / 1.2


## One sound being made: first its samples, then their bytes.
class Job:
	var key := ""
	var made: AudioStreamWAV
	var _plan: Dictionary
	var _dry := PackedFloat32Array()
	var _wet := PackedFloat32Array()
	var _bytes := PackedByteArray()
	var _at := 0
	var _encoding := false
	var _loudest := 0.001
	var _phase := 0.0
	var _wander := 0.0
	var _air := 0.0
	var _low := 0.0
	var _length := 1.0
	var _howl := true
	var _rng := RandomNumberGenerator.new()
	# (a resonance for the bark and the growl)
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0

	func _init(which: String) -> void:
		key = which
		_plan = WolfVoice.PLANS[which]
		_length = float(_plan["length"])
		_howl = _plan.has("pitch")
		_rng.seed = hash(which)
		WolfVoice._tables()
		var tail := 0.9 if _howl else 0.25
		_dry.resize(int((_length + tail) * WolfVoice.RATE))
		_wet.resize(_dry.size())
		_band(700.0 if which == "woof" else 380.0, 1.6)

	func _band(frequency: float, q: float) -> void:
		var w := TAU * frequency / WolfVoice.RATE
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_a1 = -2.0 * cos(w) / a0
		_a2 = (1.0 - alpha) / a0

	func _resonate(x: float) -> float:
		var y := _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y

	## Makes up to `budget` more samples (or bytes); true when it is done.
	func run(budget: int) -> bool:
		var rate := WolfVoice.RATE
		if not _encoding:
			var end := mini(_at + budget, _dry.size())
			var spoken := int(_length * rate)
			var pitch: Array = _plan.get("pitch", [])
			var opening: Array = _plan.get("open", [])
			var breaks: Array = _plan.get("breaks", [])
			for i in range(_at, end):
				var dry := 0.0
				if i < spoken:
					var t := float(i) / rate
					var u := t / _length
					if _howl:
						dry = _howl_sample(t, u, pitch, opening, breaks)
					elif key == "woof":
						dry = _woof_sample(t, u)
					else:
						dry = _growl_sample(t, u)
				_dry[i] = dry
				var wet := dry
				if _howl:
					for echo: Vector2 in WolfVoice.ECHOES:
						var back := i - int(echo.x * rate)
						if back >= 0:
							wet += _dry[back] * echo.y
				_wet[i] = wet
				_loudest = maxf(_loudest, absf(wet))
			_at = end
			if _at >= _dry.size():
				_encoding = true
				_at = 0
				_bytes.resize(_wet.size() * 2)
			return false
		var end := mini(_at + budget * 4, _wet.size())
		var gain := 26000.0 / _loudest
		for i in range(_at, end):
			_bytes.encode_s16(i * 2, int(clampf(_wet[i] * gain, -32000.0, 32000.0)))
		_at = end
		if _at < _wet.size():
			return false
		made = AudioStreamWAV.new()
		made.format = AudioStreamWAV.FORMAT_16_BITS
		made.mix_rate = rate
		made.data = _bytes
		return true

	func _howl_sample(t: float, u: float, pitch: Array, opening: Array, breaks: Array) -> float:
		_wander = clampf(_wander + _rng.randf_range(-1.0, 1.0) * 0.002, -0.5, 0.5)
		var f := WolfVoice._keyed(pitch, u)
		# (a slow waver, deepening towards the end, and a little drift)
		f *= 1.0 + lerpf(0.008, 0.02, u) * sin(TAU * 5.1 * t) + 0.012 * _wander
		for b: Array in breaks:
			var from: float = b[0]
			var into := (u - from) * _length
			if into > 0.0 and into < float(b[1]):
				var step := smoothstep(0.0, 0.04, into) * (1.0 - smoothstep(float(b[1]) - 0.05, float(b[1]), into))
				f *= lerpf(1.0, float(b[2]), step)
		_phase = fposmod(_phase + f / WolfVoice.RATE, 1.0)
		var o := WolfVoice._keyed(opening, u)
		var index := int(_phase * 1024.0) & 1023
		var voice := lerpf(WolfVoice._dull[index], WolfVoice._bright[index], o)
		var envelope := smoothstep(0.0, 0.07, u) * (1.0 - smoothstep(0.8, 1.0, u)) * (0.75 + 0.25 * o)
		# (breath at the start, and a little all through)
		_air = lerpf(_air, _rng.randf_range(-1.0, 1.0), 0.25)
		var breath := _air * (0.03 + 0.12 * (1.0 - smoothstep(0.0, 0.05, u)))
		return (voice + breath) * envelope

	func _woof_sample(t: float, u: float) -> float:
		# A low huff: a burst of breath through the throat, a deep tone under it, dying fast.
		var f := lerpf(175.0, 120.0, u)
		_phase = fposmod(_phase + f / WolfVoice.RATE, 1.0)
		var tone := WolfVoice._bright[int(_phase * 1024.0) & 1023]
		var noise := _resonate(_rng.randf_range(-1.0, 1.0)) * 3.0
		var envelope := smoothstep(0.0, 0.04, u) * pow(1.0 - u, 2.2)
		return (tone * 0.5 + noise) * envelope

	func _growl_sample(t: float, u: float) -> float:
		# A low rumble: a deep, rough tone that pulses (the throat rattling) through a resonance.
		var f := 92.0 + 10.0 * sin(TAU * 0.7 * t) + _rng.randf_range(-4.0, 4.0)
		_phase = fposmod(_phase + f / WolfVoice.RATE, 1.0)
		var tone := WolfVoice._bright[int(_phase * 1024.0) & 1023]
		var rattle := pow(absf(sin(TAU * 26.0 * t + sin(TAU * 3.1 * t) * 2.0)), 2.0)
		var noise := _resonate(_rng.randf_range(-1.0, 1.0)) * 2.0
		_low = lerpf(_low, tone * (0.4 + 0.6 * rattle) + noise * rattle, 0.35)
		var envelope := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u))
		return _low * envelope
