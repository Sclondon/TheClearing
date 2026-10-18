class_name BearVoice
## The bear's stolen voice (Bear, creatures/bear/bear.gd): the cries of the
## last thing it killed, made here in code. Nobody's real voice is in them:
## each is a buzz of a throat (a glottal pulse, a little ragged in pitch and
## loudness, with breath through it) sent through the resonances of a mouth
## shaping the sounds of a word (a cascade of formant filters, after Klatt),
## then coloured as if it came out of something that is not a person: a growl
## an octave under it, a wet catch in it, and the walls of the maze throwing it
## back.
##
## WHAT IT CRIES (`cry(which, speaker)`): CALL_HELP "help!", shouted;
## CALL_HELP_ME "help... me", the last word dragged out and breaking; CALL_NO
## "no, no, no!", rising; SCREAM a long scream that cracks at its top and ends
## in a gasp; SOB caught, shuddering breaths. WHOSE VOICE (`speaker`): a man,
## a woman, a boy, an old man, another woman, a young man, or (BEAST) the
## shriek of an animal. Each is made once and kept: the bear says them the
## same every time, which is how you know it is not a person.

enum { CALL_HELP, CALL_HELP_ME, CALL_NO, SCREAM, SOB }
const CRIES := 5
## The human voices, then the beast's.
const SPEAKERS := 7
const BEAST := 6
const RATE := 22050

## Each speaker: [how high the voice is (Hz), how small the throat (formants
## scaled), how breathy, how rough].
const VOICES := [
	[128.0, 1.0, 0.25, 0.20], [215.0, 1.16, 0.38, 0.10], [285.0, 1.28, 0.42, 0.06], [108.0, 0.96, 0.5, 0.42],
	[238.0, 1.12, 0.3, 0.16], [152.0, 1.04, 0.24, 0.14], [520.0, 1.45, 0.3, 0.7],
]
## The sounds of the words: the first five resonances (Hz) of a man's mouth.
const SOUNDS := {
	"a": [800.0, 1200.0, 2500.0, 3500.0, 4500.0], "e": [530.0, 1840.0, 2480.0, 3500.0, 4500.0],
	"E": [610.0, 1700.0, 2450.0, 3500.0, 4500.0], "i": [300.0, 2250.0, 2900.0, 3600.0, 4500.0],
	"o": [500.0, 850.0, 2450.0, 3500.0, 4500.0], "u": [330.0, 900.0, 2300.0, 3400.0, 4500.0],
	"l": [360.0, 1050.0, 2650.0, 3500.0, 4500.0], "m": [260.0, 1150.0, 2300.0, 3300.0, 4300.0],
	"n": [260.0, 1500.0, 2500.0, 3400.0, 4300.0], "uh": [600.0, 1150.0, 2400.0, 3400.0, 4400.0],
}
const WIDTHS := [90.0, 110.0, 150.0, 220.0, 280.0]

static var _made := {}
## Cries being made a little at a time (Speech), oldest first.
static var _making: Array = []
static var _worked_frame := -1


## One of its cries in one voice, made once and shared (made now, all at once,
## if it was not made already: `prepare` it ahead to spread the work out).
static func cry(which: int, speaker: int) -> AudioStreamWAV:
	var key := _key(which, speaker)
	if not _made.has(key):
		var speech := _find(key)
		if speech == null:
			speech = Speech.new(which, clampi(speaker, 0, SPEAKERS - 1))
		else:
			_making.erase(speech)
		while not speech.run(1 << 62):
			pass
		_made[key] = speech.stream
	return _made[key]


## Whether a cry is made and ready to play.
static func is_ready(which: int, speaker: int) -> bool:
	return _made.has(_key(which, speaker))


## Puts every cry in a voice in hand to be made a little at a time (`work`).
static func prepare(speaker: int) -> void:
	for which in CRIES:
		var key := _key(which, speaker)
		if not _made.has(key) and _find(key) == null:
			_making.append(Speech.new(which, clampi(speaker, 0, SPEAKERS - 1)))


## Makes the cries in hand for at most `microseconds`, once a frame however
## many bears ask.
static func work(microseconds := 1500) -> void:
	var frame := Engine.get_process_frames()
	if frame == _worked_frame or _making.is_empty():
		return
	_worked_frame = frame
	var until := Time.get_ticks_usec() + microseconds
	while not _making.is_empty() and Time.get_ticks_usec() < until:
		var speech: Speech = _making[0]
		if speech.run(until):
			_making.pop_front()
			_made[speech.key] = speech.stream


## How long one of its cries goes on (s).
static func length_of(which: int, speaker: int) -> float:
	var stream := cry(which, speaker)
	return stream.data.size() / 2.0 / RATE


static func _key(which: int, speaker: int) -> int:
	return which * 16 + clampi(speaker, 0, SPEAKERS - 1)


static func _find(key: int) -> Speech:
	for speech: Speech in _making:
		if speech.key == key:
			return speech
	return null


# --- Saying it ---

## What is said: a list of [sound, seconds, pitch at its start and end (as
## shares of the speaker's), loudness at its start and end, breath]. "h" is
## breath alone, "-" silence, "p" a closed mouth and a pop, "<" a sob's catch.
static func _words(which: int) -> Array:
	match which:
		CALL_HELP:
			return [["h", 0.09, 1.7, 1.7, 0.4, 0.7, 1.0], ["e", 0.10, 1.75, 1.95, 0.7, 1.0, 0.2],
					["E", 0.26, 1.95, 1.55, 1.0, 0.8, 0.25], ["l", 0.07, 1.55, 1.45, 0.8, 0.6, 0.2], ["p", 0.09, 1.4, 1.4, 0.0, 0.0, 0.0],
					["-", 0.35, 1.0, 1.0, 0.0, 0.0, 0.0]]
		CALL_HELP_ME:
			return [["h", 0.08, 1.4, 1.4, 0.3, 0.6, 1.0], ["E", 0.24, 1.45, 1.35, 0.8, 0.9, 0.3], ["l", 0.06, 1.3, 1.25, 0.7, 0.5, 0.25],
					["p", 0.08, 1.2, 1.2, 0.0, 0.0, 0.0], ["-", 0.16, 1.0, 1.0, 0.0, 0.0, 0.0],
					["m", 0.11, 1.35, 1.4, 0.3, 0.6, 0.2], ["i", 0.30, 1.45, 1.3, 0.9, 0.8, 0.3], ["<", 0.06, 1.2, 1.2, 0.2, 0.2, 0.8],
					["i", 0.45, 1.25, 0.8, 0.7, 0.0, 0.55], ["-", 0.4, 1.0, 1.0, 0.0, 0.0, 0.0]]
		CALL_NO:
			return [["n", 0.06, 1.5, 1.5, 0.4, 0.7, 0.1], ["o", 0.17, 1.55, 1.45, 0.9, 0.7, 0.2], ["-", 0.08, 1.0, 1.0, 0.0, 0.0, 0.0],
					["n", 0.05, 1.65, 1.65, 0.4, 0.7, 0.1], ["o", 0.17, 1.7, 1.6, 0.9, 0.7, 0.2], ["-", 0.07, 1.0, 1.0, 0.0, 0.0, 0.0],
					["n", 0.05, 1.85, 1.9, 0.5, 0.8, 0.1], ["o", 0.42, 2.0, 1.4, 1.0, 0.0, 0.35], ["-", 0.4, 1.0, 1.0, 0.0, 0.0, 0.0]]
		SCREAM:
			return [["h", 0.12, 2.0, 2.0, 0.2, 0.6, 1.0], ["a", 0.30, 2.0, 2.9, 0.5, 1.0, 0.4], ["a", 0.85, 2.9, 3.2, 1.0, 1.0, 0.3],
					["a", 0.35, 3.2, 2.4, 1.0, 0.6, 0.45], ["uh", 0.25, 2.4, 1.5, 0.6, 0.0, 0.7], ["-", 0.10, 1.0, 1.0, 0.0, 0.0, 0.0],
					["h", 0.30, 1.0, 1.0, 0.5, 0.0, 1.0], ["-", 0.4, 1.0, 1.0, 0.0, 0.0, 0.0]]
		SOB:
			return [["<", 0.05, 1.2, 1.2, 0.3, 0.3, 0.9], ["uh", 0.16, 1.25, 1.1, 0.6, 0.3, 0.6], ["h", 0.12, 1.0, 1.0, 0.4, 0.2, 1.0],
					["<", 0.05, 1.3, 1.3, 0.3, 0.3, 0.9], ["uh", 0.14, 1.35, 1.2, 0.6, 0.3, 0.6], ["h", 0.10, 1.0, 1.0, 0.3, 0.1, 1.0],
					["<", 0.04, 1.4, 1.4, 0.3, 0.3, 0.9], ["uh", 0.34, 1.4, 0.9, 0.7, 0.0, 0.65], ["h", 0.35, 1.0, 1.0, 0.5, 0.0, 1.0],
					["-", 0.3, 1.0, 1.0, 0.0, 0.0, 0.0]]
	return []


## One cry being made, a stretch of it at a time (`run`), so that making it
## never holds up a frame for long.
class Speech:
	var key := 0
	var which := 0
	var stream: AudioStreamWAV
	var _words: Array
	var _base := 128.0
	var _throat := 1.0
	var _breathy := 0.3
	var _rough := 0.2
	var _beast := false
	var _rng := RandomNumberGenerator.new()
	var _samples := PackedFloat32Array()
	var _mouth: Array[Reso] = []
	var _growl_mouth: Reso
	var _breath_band: Band
	var _pop_band: Band
	var _shape: Array
	var _phase := 0.0
	var _low_phase := 0.0
	var _wobble := 0.0
	var _last_flow := 0.0
	var _shimmer := 1.0
	# (where it has got to: which word, how far into it, and when that word began)
	var _word := 0
	var _i := 0
	var _at := 0.04

	func _init(cry_which: int, speaker: int) -> void:
		which = cry_which
		key = BearVoice._key(cry_which, speaker)
		_words = BearVoice._words(cry_which)
		var voice: Array = BearVoice.VOICES[speaker]
		_base = voice[0]
		_throat = voice[1]
		_breathy = voice[2]
		_rough = voice[3]
		_beast = speaker == BearVoice.BEAST
		_rng.seed = 4100 + cry_which * 97 + speaker * 13
		var length := 0.06
		for word: Array in _words:
			length += word[1]
		_samples.resize(int(BearVoice.RATE * (length + 0.7)))
		for k in 5:
			_mouth.append(Reso.new(500.0 * (k + 1), BearVoice.WIDTHS[k], BearVoice.RATE))
		_growl_mouth = Reso.new(320.0, 160.0, BearVoice.RATE)
		_breath_band = Band.new(2600.0, 1.2, BearVoice.RATE)
		_pop_band = Band.new(1100.0, 1.0, BearVoice.RATE)
		_shape = (BearVoice.SOUNDS["E"] as Array).duplicate()

	## Makes more of it, until `until` (Time.get_ticks_usec); true when it is done.
	func run(until: int) -> bool:
		var checked := 0
		if _word >= _words.size():
			return _finish(until)
		while _word < _words.size():
			var word: Array = _words[_word]
			var seconds: float = word[1]
			var count := int(seconds * BearVoice.RATE)
			while _i < count:
				_sample(word, seconds, count)
				_i += 1
				checked += 1
				if checked >= 256:
					checked = 0
					if Time.get_ticks_usec() >= until:
						return false
			_at += seconds
			_word += 1
			_i = 0
		return _finish(until)

	func _sample(word: Array, seconds: float, count: int) -> void:
		var rate := BearVoice.RATE
		var k := _word
		var i := _i
		var sound: String = word[0]
		var index := int(_at * rate) + i
		if index >= _samples.size() or sound == "-":
			return
		var next: Array = _words[k + 1] if k + 1 < _words.size() else word
		var u := float(i) / maxf(count, 1)
		var t := _at + u * seconds
		var scream := which == BearVoice.SCREAM
		# The pitch: the word's own glide, a tremble of fear (quick, uneven), and ragged from cycle to cycle.
		_wobble = clampf(_wobble + _rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		var tremble := 1.0 + 0.035 * sin(TAU * 5.6 * t) + 0.02 * sin(TAU * 8.3 * t + 1.0) + 0.018 * _wobble
		if scream:
			tremble += 0.05 * sin(TAU * 6.2 * t) * smoothstep(0.3, 0.7, t)
			# (it cracks at its height, for a moment, an octave up and back)
			if t > 0.95 and t < 1.07:
				tremble *= 1.0 + 0.45 * sin(PI * (t - 0.95) / 0.12)
		var pitch := _base * lerpf(word[2], word[3], u) * tremble
		if _beast:
			pitch *= 1.0 + 0.15 * sin(TAU * 13.0 * t)
		_phase += pitch / rate
		_low_phase += pitch * 0.5 / rate
		var p := fposmod(_phase, 1.0)
		if p < pitch / rate:
			_shimmer = 1.0 + _rng.randf_range(-1.0, 1.0) * (0.08 + _rough * 0.25)
		# A glottal pulse (open, then snapping shut) and breath that comes with it.
		var flow := 0.0
		if p < 0.45:
			flow = 0.5 - 0.5 * cos(PI * p / 0.45)
		elif p < 0.62:
			flow = cos(PI * 0.5 * (p - 0.45) / 0.17)
		# (what a mouth gives out is how fast that flow changes: the snap shut is the loud part)
		var pulse := (flow - _last_flow) * rate / pitch * 0.32 * _shimmer
		_last_flow = flow
		# (rough: every other cycle weaker, which a strained throat does)
		if _rough > 0.0 and int(_phase) % 2 == 1:
			pulse *= 1.0 - _rough * 0.5
		var loud := lerpf(word[4], word[5], u)
		var breath: float = clampf(word[6] + _breathy * 0.4, 0.0, 1.0)
		var air := _rng.randf_range(-1.0, 1.0) * (0.4 + 0.6 * flow)
		# The mouth: its resonances glide to the next sound's (retuned every 16
		# samples: often enough to glide, cheap enough to make quickly).
		if i % 16 == 0:
			var aim: Array = BearVoice.SOUNDS.get(sound, BearVoice.SOUNDS.get(next[0], BearVoice.SOUNDS["uh"]))
			for f in 5:
				_shape[f] = lerpf(_shape[f], aim[f] * _throat * (1.15 if scream and f == 0 else 1.0), 0.054)
				_mouth[f].tune(_shape[f], BearVoice.WIDTHS[f] * (1.6 if scream else 1.0))
		var source := pulse * (1.0 - breath * 0.7) + air * breath * 0.3
		if sound == "h":
			source = air * 1.1
		elif sound == "p":
			source = 0.0
			if u > 0.75:
				source = _pop_band.run(_rng.randf_range(-1.0, 1.0)) * 2.5 * (1.0 - u) * 4.0
		elif sound == "<":
			# (a sob's catch: the throat shut on a click, a gulp of air)
			source = air * 0.6 + (_rng.randf_range(-1.0, 1.0) if u < 0.15 else 0.0)
		var said := source
		for f in 5:
			said = _mouth[f].run(said)
		if sound == "m" or sound == "n":
			said *= 0.45
		# Breath at the lips, a hiss over everything.
		said += _breath_band.run(air) * breath * 0.25
		# (and what it really is: a growl an octave under the voice, a wet rattle)
		var low := 1.0 - fposmod(_low_phase, 1.0)
		var growl := _growl_mouth.run(low * low * low - 0.25) * 0.35
		var rattle := 1.0 + 0.25 * sin(TAU * 27.0 * t) * _rough
		var edge := smoothstep(0.0, 0.05, u) if k == 0 or _words[k - 1][0] == "-" else 1.0
		_samples[index] = (said * rattle + growl * (0.6 if not _beast else 0.3)) * loud * edge

	# (the stages after the voice: pushed hard, the echoes, made into a sound;
	# each a stretch at a time too)
	var _stage := 0
	var _cursor := 0
	var _out := PackedFloat32Array()
	var _loudest := 0.001
	var _data := PackedByteArray()

	## Pushed hard, as a scream is, and the halls throwing it back; true when it is done.
	func _finish(until: int) -> bool:
		var count := _samples.size()
		var drive := 2.4 if which == BearVoice.SCREAM else 1.6
		var echoes: Array[Vector2] = [Vector2(0.11, 0.32), Vector2(0.23, 0.2), Vector2(0.37, 0.12), Vector2(0.55, 0.06)]
		while _stage < 7:
			var stop := mini(_cursor + 2048, count)
			match _stage:
				0:
					for i in range(_cursor, stop):
						_samples[i] = tanh(_samples[i] * drive)
				1, 2, 3, 4:
					if _out.is_empty():
						_out = _samples.duplicate()
					var echo := echoes[_stage - 1]
					var gap := int(echo.x * BearVoice.RATE)
					for i in range(maxi(_cursor, gap), stop):
						_out[i] += _samples[i - gap] * echo.y
				5:
					for i in range(_cursor, stop):
						_loudest = maxf(_loudest, absf(_out[i]))
				6:
					if _data.is_empty():
						_data.resize(count * 2)
					for i in range(_cursor, stop):
						_data.encode_s16(i * 2, int(clampf(_out[i] / _loudest, -1.0, 1.0) * 29000.0))
			_cursor = stop
			if _cursor >= count:
				_cursor = 0
				_stage += 1
			if Time.get_ticks_usec() >= until:
				break
		if _stage < 7:
			return false
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = BearVoice.RATE
		stream.data = _data
		return true


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


## One resonance of a mouth (Klatt's resonator: a two-pole filter that passes
## the low sounds whole, so that a chain of them shapes a voice).
class Reso:
	var _a := 1.0
	var _b := 0.0
	var _c := 0.0
	var _rate := 22050
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, width: float, rate: int) -> void:
		_rate = rate
		tune(frequency, width)

	func tune(frequency: float, width: float) -> void:
		var r := exp(-PI * width / _rate)
		_c = -r * r
		_b = 2.0 * r * cos(TAU * minf(frequency, _rate * 0.45) / _rate)
		_a = 1.0 - _b - _c

	func run(x: float) -> float:
		var y := _a * x + _b * _y1 + _c * _y2
		_y2 = _y1
		_y1 = y
		return y


## A resonant band-pass filter (a biquad), for breath and noise.
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
		tune(frequency, q)

	func tune(frequency: float, q: float) -> void:
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
