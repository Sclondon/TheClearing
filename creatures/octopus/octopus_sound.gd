class_name OctopusSound
## The octopus's sounds, made in code (nothing to load), each made once:
##
## - `slither()`: the wet slide of its arms over stone and mud, a loop: a low
##   smear of wet noise that swells and fades as an arm drags, with the little
##   clicks and pops of suckers letting go. The octopus plays it louder the
##   faster its arms move.
## - `splash()`: an arm thrown up out of its water.
## - `slap()`: a lash coming down on the floor, wet and heavy.
## - `suck()`: suckers taking hold, a squelch and a run of wet pops.
## - `jet()`: the rush of water and ink out of its siphon, bubbling.

const RATE := 22050

static var _made := {}


static func slither() -> AudioStreamWAV:
	var at := func(t: float, rng: RandomNumberGenerator, s: Dictionary) -> float:
		# a slow swell, as an arm drags and stops (looping: in whole turns over the 3 s)
		var swell := 0.55 + 0.45 * sin(t * TAU / 3.0 * 2.0) * sin(t * TAU / 3.0 + 1.0)
		var low := _low(s, "a", rng.randf_range(-1.0, 1.0), 0.06)
		var wet := _low(s, "b", rng.randf_range(-1.0, 1.0), 0.35) - low
		var pop := 0.0
		if rng.randf() < 0.0016 * swell:
			s["pop"] = 1.0
			s["pitch"] = rng.randf_range(700.0, 2200.0)
		s["pop"] = maxf(float(s.get("pop", 0.0)) - 1.0 / (0.012 * RATE), 0.0)
		pop = sin(t * TAU * float(s.get("pitch", 1000.0))) * pow(float(s["pop"]), 2.0)
		return (low * 2.2 + wet * 0.9) * swell + pop * 0.5
	return _make("slither", 3.0, at, true)


static func splash() -> AudioStreamWAV:
	return _make("splash", 0.9, func(t: float, rng: RandomNumberGenerator, s: Dictionary) -> float:
		var hit := exp(-t * 9.0)
		var noise := _low(s, "a", rng.randf_range(-1.0, 1.0), 0.5)
		var drops := 0.0
		if t > 0.15 and rng.randf() < 0.004 * exp(-t * 3.0):
			s["drop"] = 1.0
			s["pitch"] = rng.randf_range(900.0, 2600.0)
		s["drop"] = maxf(float(s.get("drop", 0.0)) - 1.0 / (0.02 * RATE), 0.0)
		drops = sin(t * TAU * float(s.get("pitch", 1500.0)) * (1.0 + float(s["drop"]))) * float(s["drop"])
		return noise * hit * 1.6 + _low(s, "b", noise, 0.05) * hit * 3.0 + drops * 0.4)


static func slap() -> AudioStreamWAV:
	return _make("slap", 0.45, func(t: float, rng: RandomNumberGenerator, s: Dictionary) -> float:
		var hit := exp(-t * 22.0)
		var body := sin(t * TAU * (90.0 - 40.0 * t)) * exp(-t * 12.0)
		var noise := _low(s, "a", rng.randf_range(-1.0, 1.0), 0.6) * hit
		return body * 1.4 + noise * 1.5 + _low(s, "b", rng.randf_range(-1.0, 1.0), 0.08) * exp(-t * 6.0) * 1.2)


static func suck() -> AudioStreamWAV:
	return _make("suck", 0.6, func(t: float, rng: RandomNumberGenerator, s: Dictionary) -> float:
		var squelch := _low(s, "a", rng.randf_range(-1.0, 1.0), 0.12) * smoothstep(0.0, 0.05, t) * exp(-t * 5.0)
		if rng.randf() < 0.004:
			s["pop"] = 1.0
			s["pitch"] = rng.randf_range(500.0, 1400.0)
		s["pop"] = maxf(float(s.get("pop", 0.0)) - 1.0 / (0.015 * RATE), 0.0)
		return squelch * 3.0 + sin(t * TAU * float(s.get("pitch", 800.0))) * float(s["pop"]) * 0.5)


static func jet() -> AudioStreamWAV:
	return _make("jet", 1.3, func(t: float, rng: RandomNumberGenerator, s: Dictionary) -> float:
		var rush := smoothstep(0.0, 0.08, t) * exp(-t * 2.2)
		var hiss := _low(s, "a", rng.randf_range(-1.0, 1.0), 0.45) - _low(s, "b", rng.randf_range(-1.0, 1.0), 0.04)
		var bubbles := 0.0
		if rng.randf() < 0.006 * rush:
			s["pop"] = 1.0
			s["pitch"] = rng.randf_range(250.0, 900.0)
		s["pop"] = maxf(float(s.get("pop", 0.0)) - 1.0 / (0.03 * RATE), 0.0)
		bubbles = sin(t * TAU * float(s.get("pitch", 500.0)) * (1.0 + 0.5 * float(s["pop"]))) * float(s["pop"])
		return hiss * rush * 1.4 + bubbles * 0.5 + _low(s, "c", rng.randf_range(-1.0, 1.0), 0.03) * rush * 2.5)


## A one-pole low-pass filter kept in `state` under `key`.
static func _low(state: Dictionary, key: String, value: float, amount: float) -> float:
	var was: float = state.get(key, 0.0)
	var now := lerpf(was, value, amount)
	state[key] = now
	return now


static func _make(key: String, length: float, sample: Callable, loop := false) -> AudioStreamWAV:
	if _made.has(key):
		return _made[key]
	var count := int(RATE * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var state := {}
	var values := PackedFloat32Array()
	values.resize(count)
	var loudest := 0.0
	for i in count:
		var v := tanh(float(sample.call(float(i) / RATE, rng, state)) * 1.5)
		values[i] = v
		loudest = maxf(loudest, absf(v))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var v := values[i] / maxf(loudest, 0.001)
		if loop:
			# (faded in and out at the ends, so that it loops without a click)
			v *= smoothstep(0.0, 0.05, float(i) / RATE) * smoothstep(0.0, 0.05, float(count - i) / RATE)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = RATE
	made.data = data
	if loop:
		made.loop_mode = AudioStreamWAV.LOOP_FORWARD
		made.loop_end = count
	_made[key] = made
	return made
