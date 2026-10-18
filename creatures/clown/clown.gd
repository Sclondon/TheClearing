class_name Clown
extends Node3D
## A horror clown: too tall and too thin, in a faded, stained, baggy suit with a
## ruff, big flapping shoes and white gloves; a mask of white greasepaint for a
## face, dark diamonds painted through the eyes and a grin painted much wider
## than any mouth. He holds one red balloon on a long string, and it floats high
## over him (over walls, if `balloon_height` says so), bobbing as he goes: the
## only colour near him. A music box tinkles where he is while he moves, and
## winds down when he is still; he giggles, and his shoes slap.
##
## This is only how he looks, moves and sounds. He does no thinking: a game
## drives him. Put him where the creature is each frame and say how fast he is
## going; freeze him, wind him, make him giggle.
##
##     var clown := Clown.new()
##     clown.scale = Vector3.ONE * 1.55       # modelled about 1.5 m tall
##     clown.balloon_height = 36.0            # world units over his feet
##     add_child(clown)
##     # each frame:
##     clown.global_position = body_position
##     clown.rotation.y = facing_yaw          # 0 faces +Z
##     clown.velocity = body_velocity         # world units a second (fast: a flailing stop-motion sprint)
##     clown.aim = player_position + Vector3.UP # what he looks at (INF: nothing)
##     clown.frozen = true                    # stopped dead mid-pose, the head slowly tilting over
##     clown.winded = true                    # bent double, panting
##     clown.music = true                     # the music box plays (while he is not frozen)
##     clown.giggle()                         # a giggle, a hand to his mouth
##     clown.far = true                       # not posed or heard (the balloon is still there)
##
## He is posed by ClownRig (clown_rig.gd), which extends CharacterRig: he needs
## GameCommon's character-controller (CharacterRig, Player, Toon, Settings). The
## model is creatures/clown/models/clown.glb (and clown_lo.glb), made by
## creatures/clown/tools/build_clown.py in Blender.

const MODEL := "res://creatures/clown/models/clown.glb"
const MODEL_LO := "res://creatures/clown/models/clown_lo.glb"
## The balloon's red (a little stronger than the boy's red shirt: the strongest colour about).
const BALLOON := Color(0.62, 0.09, 0.07)
## The balloon's size (world units across, and from the knot to its top).
const BALLOON_SIZE := Vector2(1.0, 1.2)
## The music box's tune, (note, beats): an air in A minor, in three, that goes round.
const TUNE := [[69, 1], [72, 1], [76, 1], [75, 1], [76, 1], [71, 1], [72, 1], [69, 1], [64, 1], [68, 3],
		[69, 1], [72, 1], [76, 1], [77, 1], [76, 1], [72, 1], [71, 1], [68, 1], [64, 1], [69, 3], [0, 3]]
## Seconds a beat of it, wound up.
const BEAT := 0.42

## Use the low-poly model.
@export var low_poly := false
## His sounds, made in code, from where he is: the music box, the giggle, his shoes.
@export var sound := true
## How loud the music box is, and how far off it is heard (world units).
@export var volume_db := -9.0
@export var sound_range := 34.0
## How high the balloon floats over his feet, world units.
@export var balloon_height := 6.0
## Faster than this (world units a second) he goes in stop-motion, posed this many times a second.
@export var stop_motion := 11.0
## Poses a second otherwise (0: every frame): fewer, to cost less, when he is far enough off for it not to show.
@export var pose_rate := 0.0

## How fast he is going, world units a second. His feet go with this.
var velocity := Vector3.ZERO
## Whether he is on the ground.
var grounded := true
## What he looks at, in the world (INF: nothing).
var aim := Vector3.INF
## Stopped dead mid-pose (only his head moves, tilting slowly over, and then not even that).
var frozen := false
## Bent double, out of breath.
var winded := false
## Whether the music box plays (it winds down while he is frozen, and starts again when he moves).
var music := true
## Too far off to be seen: not posed, not heard (the balloon still floats).
var far := false:
	set(value):
		if value == far:
			return
		far = value
		if _rig:
			_rig.visible = not far
			_rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT

## For the rig, which reads his body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.6 * global_basis.get_scale().y
var run_speed: float:
	get:
		return walk_speed * 3.0

var _rig: ClownRig
var _balloon: Node3D
var _string: MeshInstance3D
var _balloon_at := Vector3.ZERO
var _balloon_speed := Vector3.ZERO
var _balloon_set := false
var _time := 0.0
var _box: Array[AudioStreamPlayer3D] = []
var _voice: AudioStreamPlayer3D
var _shoes: AudioStreamPlayer3D
var _note := 0
var _note_in := 0.0
var _wound := 1.0
var _giggles := 0
static var _tine: AudioStreamWAV
static var _giggle: AudioStreamWAV
static var _slap: AudioStreamWAV


func _ready() -> void:
	_rig = ClownRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.3
	add_child(_rig)
	_rig.slapped.connect(_on_slapped)
	_make_balloon()
	if sound:
		for k in 2:
			var tine := AudioStreamPlayer3D.new()
			tine.stream = tine_sound()
			tine.volume_db = volume_db
			tine.unit_size = 5.0
			tine.max_distance = sound_range
			tine.position = Vector3(0.0, 1.0, 0.1)
			add_child(tine)
			_box.append(tine)
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = giggle_sound()
		_voice.volume_db = volume_db + 5.0
		_voice.unit_size = 5.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.35, 0.1)
		add_child(_voice)
		_shoes = AudioStreamPlayer3D.new()
		_shoes.stream = slap_sound()
		_shoes.volume_db = volume_db + 1.0
		_shoes.unit_size = 4.0
		_shoes.max_distance = sound_range
		add_child(_shoes)


func is_on_floor() -> bool:
	return grounded


## The balloon, its knot and its string. Kept apart from him (top_level): it
## floats on its own, drawn up to `balloon_height` over his fist and held there
## by its string.
func _make_balloon() -> void:
	_balloon = Node3D.new()
	_balloon.name = "Balloon"
	_balloon.top_level = true
	add_child(_balloon)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = BALLOON
	rubber.roughness = 0.32
	rubber.metallic_specular = 0.7
	rubber.rim_enabled = true
	rubber.rim = 0.4
	# (a glow of its own, faint, so that it still shows red through the mist)
	rubber.emission_enabled = true
	rubber.emission = BALLOON
	rubber.emission_energy_multiplier = 0.35
	var skin := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALLOON_SIZE.x * 0.5
	sphere.height = BALLOON_SIZE.y - 0.06
	sphere.radial_segments = 16
	sphere.rings = 10
	skin.mesh = sphere
	skin.material_override = rubber
	skin.position.y = 0.06 + sphere.height * 0.5
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_balloon.add_child(skin)
	var knot := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.012
	cone.height = 0.08
	cone.radial_segments = 6
	cone.rings = 1
	knot.mesh = cone
	knot.material_override = rubber
	knot.position.y = 0.04
	knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_balloon.add_child(knot)
	_string = MeshInstance3D.new()
	_string.name = "String"
	var line := CylinderMesh.new()
	line.top_radius = 0.009
	line.bottom_radius = 0.009
	line.height = 1.0
	line.radial_segments = 4
	line.rings = 1
	_string.mesh = line
	var thread := StandardMaterial3D.new()
	thread.albedo_color = Color(0.3, 0.29, 0.28)
	thread.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_string.material_override = thread
	_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_string.top_level = true
	add_child(_string)


func _process(delta: float) -> void:
	_time += delta
	if _rig:
		_rig.aim = aim
		_rig.frozen = frozen
		_rig.winded = 1.0 if winded else 0.0
		_rig.stop_motion = stop_motion
		_rig.pose_rate = pose_rate
	_float(delta)
	_play_box(delta)


## The balloon drifts over his fist, lagging behind him as he goes and jerked
## down a little by each step; the string runs straight from his fist to its knot.
func _float(delta: float) -> void:
	var fist := _rig.fist() if _rig and not far else global_position + Vector3.UP * 1.4 * global_basis.get_scale().y
	var high := maxf(balloon_height, fist.y - global_position.y + 1.0)
	var drift := Vector3(sin(_time * 0.37) * 0.45, sin(_time * 0.9) * 0.2, cos(_time * 0.29) * 0.45) * minf(high / 6.0, 3.0)
	var target := Vector3(fist.x, global_position.y + high, fist.z) + drift
	if not _balloon_set:
		_balloon_set = true
		_balloon_at = target
	_balloon_speed += ((target - _balloon_at) * 1.4 - _balloon_speed * 1.3) * minf(delta, 0.1)
	_balloon_at += _balloon_speed * minf(delta, 0.1)
	# (on its string, it can go no further from his fist than the string is long)
	var length := high - (fist.y - global_position.y) + 0.4
	var out := _balloon_at - fist
	if out.length() > length:
		_balloon_at = fist + out.normalized() * length
		_balloon_speed -= out.normalized() * maxf(_balloon_speed.dot(out.normalized()), 0.0)
	var up := (_balloon_at - fist).normalized()
	var across := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_balloon.global_transform = Transform3D(Basis(across, up, across.cross(up)).rotated(up, _time * 0.2), _balloon_at)
	var span := _balloon_at - fist
	var side := span.normalized().cross(Vector3.RIGHT if absf(span.normalized().x) < 0.9 else Vector3.FORWARD).normalized()
	_string.global_transform = Transform3D(Basis(side, span, side.cross(span.normalized())), fist + span * 0.5)


## Plays the music box's tune, one note at a time, while he moves; frozen, it
## winds down (slower and lower, and stops), and starts again when he moves.
func _play_box(delta: float) -> void:
	_wound = move_toward(_wound, 0.0 if frozen else 1.0, delta / (1.4 if frozen else 0.3))
	if _box.is_empty() or far or not music:
		return
	if _wound < 0.18:
		return
	_note_in -= delta * _wound
	if _note_in > 0.0:
		return
	var note: Array = TUNE[_note % TUNE.size()]
	_note += 1
	_note_in = BEAT * float(note[1])
	if note[0] == 0:
		return
	var tine := _box[_note % 2]
	tine.pitch_scale = pow(2.0, (float(note[0]) - 81.0) / 12.0) * lerpf(0.82, 1.0, _wound) * randf_range(0.996, 1.004)
	tine.volume_db = volume_db + linear_to_db(lerpf(0.4, 1.0, _wound))
	tine.play()


func _on_slapped(at: Vector3, weight: float) -> void:
	if _rig:
		_balloon_speed += Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)) * weight
	if _shoes == null or far or weight < 0.3:
		return
	_shoes.global_position = at
	_shoes.pitch_scale = randf_range(0.85, 1.12)
	_shoes.volume_db = volume_db + 1.0 + linear_to_db(weight)
	_shoes.play()


## Giggles: his shoulders hitch, a hand comes up to his mouth; the giggle is heard.
func giggle() -> void:
	_giggles += 1
	if _rig:
		_rig.act(ClownRig.Act.GIGGLE)
	if _voice and not far:
		_voice.pitch_scale = randf_range(0.94, 1.06)
		_voice.play()


## Whether he is in the middle of a giggle.
func busy() -> bool:
	return _rig != null and _rig._doing != ClownRig.Act.NONE


## Where the balloon is (its knot), in the world.
func balloon_position() -> Vector3:
	return _balloon_at


## Where his face is in the world, for anything that should see it.
func face() -> Vector3:
	return to_global(Vector3(0.0, 1.42, 0.06))


## Puts him straight somewhere, standing still as he is (the balloon over him).
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	_balloon_set = false
	_balloon_speed = Vector3.ZERO
	if _rig:
		_rig.settle()


## A music box's tine, made once and shared: an A (880 Hz) struck and ringing
## away, a little of its octave and of the high, clangy partial a steel tine
## has, and the tick of the pin that plucks it. Played at other pitches for the
## other notes. 1.4 s.
static func tine_sound() -> AudioStreamWAV:
	if _tine:
		return _tine
	var rate := 22050
	var count := int(rate * 1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples := PackedFloat32Array()
	samples.resize(count)
	var loudest := 0.0
	var f := 880.0
	for i in count:
		var t := float(i) / rate
		var value := sin(TAU * f * t) * exp(-t * 3.0)
		value += 0.3 * sin(TAU * f * 2.0 * t + 0.4) * exp(-t * 6.0)
		value += 0.16 * sin(TAU * f * 5.4 * t) * exp(-t * 16.0)
		# (a second tine a hair out of tune beside it: the shimmer)
		value += 0.25 * sin(TAU * f * 1.0035 * t) * exp(-t * 3.4)
		value += rng.randf_range(-1.0, 1.0) * 0.35 * exp(-t * 500.0)
		value *= smoothstep(0.0, 0.002, t)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_tine = _wav(samples, loudest, rate)
	return _tine


## The giggle, made once and shared: a man's high giggle through his teeth, "hee
## hee hee hee hehhh", quicker and quicker and then one long one sinking away:
## breathy pulses of voice through the resonances of an "ee", each begun with a
## breath. 1.0 s.
static func giggle_sound() -> AudioStreamWAV:
	if _giggle:
		return _giggle
	var rate := 22050
	var length := 1.0
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var samples := PackedFloat32Array()
	samples.resize(count)
	var formants: Array[Band] = [Band.new(330.0, 3.0, rate), Band.new(2350.0, 6.0, rate), Band.new(3050.0, 7.0, rate)]
	var gains := [1.0, 0.55, 0.35]
	var breath := Band.new(3300.0, 1.4, rate)
	# Each syllable: when it starts, how long, its pitch at the start and at the end.
	var syllables := [Vector4(0.0, 0.09, 390.0, 420.0), Vector4(0.14, 0.085, 410.0, 440.0), Vector4(0.26, 0.08, 425.0, 455.0),
			Vector4(0.37, 0.08, 440.0, 470.0), Vector4(0.5, 0.42, 455.0, 260.0)]
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var voice := 0.0
		var air := 0.0
		var pitch := 400.0
		for s: Vector4 in syllables:
			var u := (t - s.x) / s.y
			if u < -0.25 or u > 1.0:
				continue
			# (a breath first, then the voice, cut off at the end)
			air = maxf(air, smoothstep(-0.25, 0.0, u) * (1.0 - smoothstep(0.05, 0.3, u)) + 0.25 * (1.0 - u) * float(u > 0.0))
			voice = maxf(voice, smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.6, 1.0, u)))
			pitch = lerpf(s.z, s.w, clampf(u, 0.0, 1.0))
		pitch *= 1.0 + 0.04 * sin(t * TAU * 6.0)
		phase += pitch / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 5.0) * 2.0 - 0.33
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var noise := breath.run(rng.randf_range(-1.0, 1.0))
		var value := throat * 2.0 * voice + noise * (0.7 * air + 0.35 * voice)
		samples[i] = tanh(value * 1.6)
		loudest = maxf(loudest, absf(samples[i]))
	_giggle = _wav(samples, loudest, rate)
	return _giggle


## A big shoe slapping down flat, made once and shared: a dull thump of the heel
## and the flat crack of the sole after it. 0.16 s.
static func slap_sound() -> AudioStreamWAV:
	if _slap:
		return _slap
	var rate := 22050
	var count := int(rate * 0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var samples := PackedFloat32Array()
	samples.resize(count)
	var crack := Band.new(1300.0, 1.3, rate)
	var low := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var thump := sin(TAU * (120.0 - 260.0 * t) * t) * exp(-t * 40.0)
		var sole := t - 0.022
		var flat := 0.0
		if sole > 0.0:
			var noise := rng.randf_range(-1.0, 1.0)
			low = lerpf(low, noise, 0.25)
			flat = crack.run(noise) * 1.6 * exp(-sole * 75.0) + low * 0.5 * exp(-sole * 30.0)
		samples[i] = thump * 0.8 + flat
		loudest = maxf(loudest, absf(samples[i]))
	_slap = _wav(samples, loudest, rate)
	return _slap


static func _wav(samples: PackedFloat32Array, loudest: float, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## A resonant band-pass filter (a biquad), for the giggle and the slap.
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
