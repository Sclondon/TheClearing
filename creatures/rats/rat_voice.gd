class_name RatVoice
## The rats' sounds, made in code the first time each is wanted and kept (one
## of each for everybody), so there is nothing to load:
##
## - `squeak()`: one rat's sharp squeak or two (a rat that is startled).
## - `roar()`: a swarm's squealing roar, in a loop: a crowd of squeals over one
##   another, claws scrabbling on stone, and the rumble of bodies.
## - `shriek()`: a rat king's shriek: its rats all screaming at once, harsh,
##   rising and falling, long enough to carry.
## - `writhing()`: a rat king's squeaking and chittering as it writhes, in a loop.
##
## Squeals are chirps of a few thousand hertz that wobble and break, each with a
## harmonic or two and a rasp of noise through it.

const RATE := 16000

static var _made := {}


static func squeak() -> AudioStreamWAV:
	return _cached("squeak", func() -> PackedFloat32Array: return _squeak())


static func roar() -> AudioStreamWAV:
	return _cached("roar", func() -> PackedFloat32Array: return _roar(), true)


static func shriek() -> AudioStreamWAV:
	return _cached("shriek", func() -> PackedFloat32Array: return _shriek())


static func writhing() -> AudioStreamWAV:
	return _cached("writhing", func() -> PackedFloat32Array: return _writhing(), true)


static func _cached(name: String, make: Callable, loop := false) -> AudioStreamWAV:
	if _made.has(name):
		return _made[name]
	var made := _stream(make.call(), loop)
	_made[name] = made
	return made


# One squeal into `samples` from `start`: `long` samples, going from `high` to
# `low` hertz (and back up by `turn` of the way), a wobble of `wobble`, a rasp
# of `rasp` (0 to 1), as loud as `loud`.
static func _squeal(samples: PackedFloat32Array, start: int, long: int, high: float, low: float, turn: float, wobble: float, rasp: float, loud: float, rng: RandomNumberGenerator, wrap := false) -> void:
	var size := samples.size()
	var phase := 0.0
	var wobble_rate := rng.randf_range(18.0, 40.0)
	var last := 0.0
	for k in long:
		var s := float(k) / long
		var pitch := lerpf(high, low, s / turn) if s < turn else lerpf(low, high * 0.85, (s - turn) / maxf(1.0 - turn, 0.01))
		pitch *= 1.0 + sin(TAU * wobble_rate * k / RATE) * wobble
		phase += pitch / RATE
		var up := minf(s * 14.0, 1.0) * minf((1.0 - s) * 6.0, 1.0)
		var tone := sin(TAU * phase) + 0.45 * sin(TAU * phase * 2.0) * (1.0 if pitch * 2.0 < RATE * 0.48 else 0.0)
		var noise := rng.randf_range(-1.0, 1.0)
		last = lerpf(last, noise, 0.6)
		var value := tone * (1.0 - rasp * 0.5 + rasp * last) * up * loud
		var at := start + k
		if wrap:
			samples[at % size] += value
		elif at < size:
			samples[at] += value


static func _squeak() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.32))
	_squeal(samples, 0, int(RATE * 0.09), 4200.0, 3000.0, 0.7, 0.04, 0.3, 0.8, rng)
	_squeal(samples, int(RATE * 0.12), int(RATE * 0.16), 4600.0, 2700.0, 0.6, 0.06, 0.4, 1.0, rng)
	return samples


static func _roar() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 2.5))
	var size := samples.size()
	# The rumble of bodies: dark noise, slow.
	var low := 0.0
	var slower := 0.0
	for k in size:
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.05)
		slower = lerpf(slower, low, 0.1)
		samples[k] += slower * 1.4
	# Claws scrabbling on stone: tiny clicks.
	for n in 700:
		var start := rng.randi_range(0, size - 1)
		var loud := rng.randf_range(0.05, 0.25)
		var last := 0.0
		for k in 28:
			var noise := rng.randf_range(-1.0, 1.0)
			samples[(start + k) % size] += (noise - last) * loud * (1.0 - k / 28.0)
			last = noise
	# The squealing: a crowd of voices over one another.
	for n in 48:
		var long := int(RATE * rng.randf_range(0.06, 0.28))
		var high := rng.randf_range(2400.0, 5200.0)
		_squeal(samples, rng.randi_range(0, size - 1), long, high, high * rng.randf_range(0.55, 0.85), rng.randf_range(0.4, 0.9), rng.randf_range(0.02, 0.09), rng.randf_range(0.2, 0.7), rng.randf_range(0.15, 0.4), rng, true)
	return samples


static func _shriek() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 1.7))
	# Its rats screaming together, long and harsh, each a little off the others.
	for n in 6:
		var start := int(RATE * rng.randf_range(0.0, 0.15))
		var long := int(RATE * rng.randf_range(1.1, 1.5))
		var high := rng.randf_range(2600.0, 3800.0)
		_squeal(samples, start, long, high, high * rng.randf_range(0.6, 0.75), rng.randf_range(0.25, 0.45), rng.randf_range(0.06, 0.12), 0.75, 0.5, rng)
	# And the shorter cries of the rest through it.
	for n in 16:
		var long := int(RATE * rng.randf_range(0.05, 0.18))
		var high := rng.randf_range(3000.0, 5600.0)
		_squeal(samples, rng.randi_range(0, samples.size() - long), long, high, high * 0.7, 0.6, 0.05, 0.5, 0.35, rng)
	return samples


static func _writhing() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 3.0))
	var size := samples.size()
	for n in 22:
		var long := int(RATE * rng.randf_range(0.05, 0.22))
		var high := rng.randf_range(2600.0, 5000.0)
		_squeal(samples, rng.randi_range(0, size - 1), long, high, high * rng.randf_range(0.6, 0.85), rng.randf_range(0.5, 0.9), 0.05, 0.4, rng.randf_range(0.3, 0.7), rng, true)
	for n in 260:
		var start := rng.randi_range(0, size - 1)
		var loud := rng.randf_range(0.05, 0.2)
		var last := 0.0
		for k in 24:
			var noise := rng.randf_range(-1.0, 1.0)
			samples[(start + k) % size] += (noise - last) * loud * (1.0 - k / 24.0)
			last = noise
	return samples


static func _stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	var size := samples.size()
	var data := PackedByteArray()
	data.resize(size * 2)
	for k in size:
		data.encode_s16(k * 2, int(clampf(samples[k] / loudest, -1.0, 1.0) * 27000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = RATE
	made.data = data
	if loop:
		made.loop_mode = AudioStreamWAV.LOOP_FORWARD
		made.loop_end = size
	return made
