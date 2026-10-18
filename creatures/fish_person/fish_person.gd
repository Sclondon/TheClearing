class_name FishPerson
extends Node3D
## A fish person: a deep one, out of Innsmouth. Taller than a man and stooped,
## grey-green and scaled, paler on the belly, wet; a bulbous fish's head with
## round glassy eyes set wide, a lipless mouth right across it full of needle
## teeth, gills that flare down its neck, a ragged fin down its back, webbed
## hands with long clawed fingers and long webbed feet. It lurks in black water
## up to its eyes, rises out of it, shambles, lopes bent double, croaks (a
## gurgling, rattling croak that breaks into a screech) and lunges, grabbing
## with both webbed hands.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## drives it. Put it where the creature is each frame and say how fast it is
## going, and call `emerge()`, `submerge()`, `croak()` and `grab()`; it tells
## you when the croak goes out (`croaked`), when it is up (`risen`) and whether
## a grab closes on a point (`grab_hits`).
##
##     var fish := FishPerson.new()
##     fish.scale = Vector3.ONE * 1.5        # modelled about 1.42 m tall
##     add_child(fish)
##     fish.put(spawn_point, spawn_yaw, true) # true: down in the water
##     # each frame:
##     fish.global_position = body_position
##     fish.rotation.y = facing_yaw           # 0 faces +Z
##     fish.velocity = body_velocity          # its feet go with this (fast, it lopes)
##     fish.awake = true                      # false: it squats, still
##     fish.winded = 0.0                      # 0..1: how hard it is breathing
##     fish.aim = player_position + Vector3.UP # what it looks at and reaches for (INF: nothing)
##     # when you like:
##     fish.emerge()                          # up out of the water; `risen` when it is
##     fish.croak()                           # `croaked` at the height of it
##     fish.grab()                            # test `grab_hits(point)` while `stage()` is CLOSE
##     fish.held = true                       # it has them: it drags them to its mouth
##     fish.submerge()                        # back down into the water
##
## Give it a `FishPool` (`pool`) and it stirs the water as it rises, sinks,
## breathes and wades. It is posed by FishPersonRig (fish_person_rig.gd), which
## extends CharacterRig: it needs GameCommon's character-controller
## (CharacterRig, Toon, Settings). The model is
## creatures/fish_person/models/fish_person.glb (and fish_person_lo.glb), made
## by creatures/fish_person/tools/build_fish_person.py in Blender.

## The croak has gone out (the height of it): whoever is to be called by it is called now.
signal croaked
## The hands of a grab have begun to close: test `grab_hits` from now until `stage()` is no longer CLOSE.
signal closing
## It has come right up out of the water (`emerge`), or gone right down (`submerge`).
signal risen
signal sank

const MODEL := "res://creatures/fish_person/models/fish_person.glb"
const MODEL_LO := "res://creatures/fish_person/models/fish_person_lo.glb"
## Seconds to come up out of the water, and to go back down.
const RISE_TIME := 1.6
const SINK_TIME := 2.2

## Use the low-poly model.
@export var low_poly := false
## Its croak, made in code, from where it stands.
@export var sound := true
## How loud the croak is, and how far off it is heard (world units).
@export var volume_db := 5.0
@export var sound_range := 70.0

## How fast it is going, world units a second. Its feet go with this.
var velocity := Vector3.ZERO
## Whether it is on the ground (off it, its legs hang).
var grounded := true
## Squatting still (false) or up and about (true). It changes over a moment.
var awake := false
## How hard it is breathing, 0..1: its mouth gulps and its gills pump faster.
var winded := 0.0
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
## How far down in the water it is, 0 (not at all) to 1 (to its eyes). Set by
## `emerge`, `submerge` and `put`.
var sunk := 0.0
## The water it lurks in, if any: stirred as it rises, sinks, breathes and wades.
var pool: FishPool

## For the rig, which reads its body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.55 * global_basis.get_scale().y
var run_speed: float:
	get:
		return walk_speed * 3.0

var _rig: FishPersonRig
var _voice: AudioStreamPlayer3D
var _croaked := true
var _closing := true
## Going up (-1), down (1) or neither (0), and how far through it.
var _going := 0
var _going_time := 0.0
var _breathed := 0.0
var _waded := 0.0
static var _croak: AudioStreamWAV


func _ready() -> void:
	_rig = FishPersonRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.2
	add_child(_rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = croak_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 9.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.3, 0.15)
		add_child(_voice)


func is_on_floor() -> bool:
	return grounded


func _process(delta: float) -> void:
	if _going != 0:
		_going_time += delta
		var length := RISE_TIME if _going < 0 else SINK_TIME
		var t := clampf(_going_time / length, 0.0, 1.0)
		# (it rises slowly at first, then all at once; it sinks steadily)
		sunk = 1.0 - t * t * (3.0 - 2.0 * t) if _going < 0 else t
		if t >= 1.0:
			var up := _going < 0
			_going = 0
			if up:
				risen.emit()
			else:
				sank.emit()
	_rig.awake = 1.0 if awake or _going < 0 else 0.0
	_rig.sunk = sunk
	_rig.winded = winded
	_rig.aim = aim
	_rig.arms_reach = reaching
	var t := _rig.act_time()
	if not _croaked and _rig._doing == FishPersonRig.Act.CROAK and t >= FishPersonRig.SWELL:
		_croaked = true
		croaked.emit()
	if not _closing and _rig._doing == FishPersonRig.Act.GRAB and t >= FishPersonRig.WIND + FishPersonRig.LUNGE:
		_closing = true
		closing.emit()
	_stir(delta)


## Comes up out of the water (over RISE_TIME); `risen` when it is up.
func emerge() -> void:
	if sunk <= 0.0 and _going == 0:
		return
	_going = -1
	_going_time = (1.0 - sunk) * RISE_TIME
	if pool:
		pool.stir(global_position, 1.0)


## Goes back down into the water (over SINK_TIME); `sank` when it is under.
func submerge() -> void:
	if sunk >= 1.0 and _going == 0:
		return
	_going = 1
	_going_time = sunk * SINK_TIME
	if pool:
		pool.stir(global_position, 0.7)


## Rising or sinking.
func moving_in_water() -> bool:
	return _going != 0


## Draws itself up and croaks. `croaked` is emitted when the croak goes out
## (SWELL seconds on); the whole takes `act_length(FishPersonRig.Act.CROAK)`.
func croak() -> void:
	_rig.act(FishPersonRig.Act.CROAK)
	_croaked = false
	if _voice:
		_voice.play()


## Gathers itself and lunges, both hands out. `closing` is emitted as they
## clamp shut (WIND + LUNGE seconds on); then, while `stage()` is CLOSE,
## `grab_hits` says whether a point is within them.
func grab() -> void:
	_rig.act(FishPersonRig.Act.GRAB)
	_closing = false
	held = false


## What it is doing: FishPersonRig.Act.NONE, CROAK or GRAB.
func doing() -> FishPersonRig.Act:
	return _rig._doing if _rig else FishPersonRig.Act.NONE


## Where it is in what it is doing.
func stage() -> FishPersonRig.Stage:
	return _rig.stage() if _rig else FishPersonRig.Stage.NONE


func busy() -> bool:
	return doing() != FishPersonRig.Act.NONE


## How long a croak or a grab takes, seconds.
static func act_length(what: FishPersonRig.Act) -> float:
	match what:
		FishPersonRig.Act.CROAK:
			return FishPersonRig.SWELL + FishPersonRig.CROAKING + FishPersonRig.SUBSIDE
		FishPersonRig.Act.GRAB:
			return FishPersonRig.WIND + FishPersonRig.LUNGE + FishPersonRig.CLOSE + FishPersonRig.HOLD + FishPersonRig.LET_GO
	return 0.0


## Whether a point (in the world) is taken by its hands as they close: in
## front of it, out to the end of its lunge, and within its height, `radius`
## (world units) more all round. Only while `stage()` is CLOSE (or `always`).
func grab_hits(point: Vector3, radius := 0.25, always := false) -> bool:
	if not always and stage() != FishPersonRig.Stage.CLOSE:
		return false
	var size := global_basis.get_scale().y
	var at := global_transform.affine_inverse() * point
	var r := radius / size
	return at.z > 0.0 - r and at.z < 0.95 + r and absf(at.x) < 0.36 + r and at.y > -r and at.y < 1.4 + r


## Where its mouth is in the world (the croak comes from it).
func mouth() -> Vector3:
	return to_global(Vector3(0.0, 1.27 - (_rig.drop() if _rig else 0.0), 0.2))


## Where its eyes are, for anything that should see what it sees.
func eyes() -> Vector3:
	return to_global(Vector3(0.0, 1.36 - (_rig.drop() if _rig else 0.0), 0.1))


## Puts it straight somewhere, standing (or squatting) as it is; `under`: down in the water.
func put(at: Vector3, yaw: float, under := false) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	sunk = 1.0 if under else 0.0
	_going = 0
	if _rig:
		_rig.awake = 1.0 if awake else 0.0
		_rig.sunk = sunk
		_rig.settle()


## Stirs its pool: rings out from it as it rises and sinks, a bubble now and
## then as it breathes down there, and a ring from each step it takes in it.
func _stir(delta: float) -> void:
	if pool == null or not is_instance_valid(pool):
		return
	var size := global_basis.get_scale().y
	var flat := Vector2(global_position.x - pool.global_position.x, global_position.z - pool.global_position.z)
	if flat.length() > pool.radius * 1.1:
		return
	if _going != 0:
		_waded -= delta
		if _waded <= 0.0:
			_waded = 0.32
			pool.stir(global_position + global_basis.z * 0.1 * size, 0.6)
		return
	if sunk > 0.9:
		_breathed -= delta
		if _breathed <= 0.0:
			_breathed = randf_range(2.5, 6.0)
			pool.stir(eyes() + global_basis.z * 0.12 * size, 0.18)
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		_waded -= delta
		if _waded <= 0.0:
			_waded = 0.45
			pool.stir(global_position, 0.45)


## The croak, made once and shared: something that breathes water trying to
## make a sound in air. A wet gulp and gurgle of bubbles first; then a slow,
## creaking voice down in a swollen throat (glottal pulses at a frog's pitch,
## every other one weak so that it rattles, through the resonances of a wet
## "oo"), in pulses; it strains up into a hoarse screech that breaks (the
## voice leaps up and the throat goes to "ee", hissing); and dies back into a
## rattle and a gurgle. 2.2 s.
static func croak_sound() -> AudioStreamWAV:
	if _croak:
		return _croak
	var rate := 22050
	var length := 2.2
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat: Array[Band] = [Band.new(380.0, 3.5, rate), Band.new(850.0, 4.0, rate), Band.new(2400.0, 5.0, rate)]
	var gains := [1.0, 0.65, 0.3]
	var bubble := Band.new(500.0, 9.0, rate)
	var hiss := Band.new(3300.0, 1.3, rate)
	var phase := 0.0
	var odd := false
	var pulse_gain := 1.0
	var wander := 0.0
	var low := 0.0
	var popping := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		# Bubbles: a wet gurgle, thickest at the start and the end.
		var gurgle := 0.8 * (1.0 - smoothstep(0.12, 0.42, t)) + 0.2 * smoothstep(0.4, 0.7, t) * (1.0 - smoothstep(1.1, 1.4, t)) + 0.9 * smoothstep(1.62, 1.8, t) * (1.0 - smoothstep(2.0, length, t))
		if rng.randf() < 0.0022 * gurgle:
			popping = 1.0
			bubble.set_frequency(rng.randf_range(240.0, 950.0), 10.0)
		popping = maxf(popping - 1.0 / (0.035 * rate), 0.0)
		value += bubble.run(rng.randf_range(-1.0, 1.0) * popping * popping) * 4.0
		# The voice: slow and creaking, in pulses, straining up into a screech.
		var voice := smoothstep(0.3, 0.4, t) * (1.0 - smoothstep(1.6, 1.82, t))
		var screech := smoothstep(1.02, 1.28, t) * (1.0 - smoothstep(1.5, 1.72, t))
		var throb := 0.3 + 0.7 * pow(maxf(sin((t - 0.32) * TAU * 7.0), 0.0), 0.5)
		throb = lerpf(throb, 1.0, screech)
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := 64.0 + 9.0 * sin(t * 3.1) + 340.0 * screech * (0.85 + 0.15 * sin(t * TAU * 11.0))
		# (it breaks: a leap up and back, twice)
		if (t > 1.2 and t < 1.27) or (t > 1.41 and t < 1.46):
			pitch *= 1.45
		pitch *= 1.0 + 0.09 * wander
		var before := phase
		phase += pitch / rate * (1.0 + rng.randf_range(-0.06, 0.06))
		if floorf(phase) != floorf(before):
			odd = not odd
			pulse_gain = rng.randf_range(0.6, 1.1) * (0.45 if odd and screech < 0.5 else 1.0)
		var p := fposmod(phase, 1.0)
		var glottal := (pow(1.0 - p, 6.0) * 2.0 - 0.3) * pulse_gain
		throat[0].set_frequency(lerpf(380.0, 330.0, screech), 3.5)
		throat[1].set_frequency(lerpf(850.0, 2150.0, screech), 4.0)
		var voiced := 0.0
		for k in throat.size():
			voiced += throat[k].run(glottal) * gains[k]
		var breath := hiss.run(rng.randf_range(-1.0, 1.0)) * (0.2 + 1.0 * screech)
		value += (voiced * 2.2 + breath) * voice * throb
		# (and under it all the swollen throat, throbbing)
		low = lerpf(low, glottal, 0.025)
		value += low * 1.6 * voice * (1.0 - screech) * throb
		value = tanh(value * 2.2)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	_croak = AudioStreamWAV.new()
	_croak.format = AudioStreamWAV.FORMAT_16_BITS
	_croak.mix_rate = rate
	_croak.data = data
	return _croak


## A resonant band-pass filter (a biquad), for the croak.
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
