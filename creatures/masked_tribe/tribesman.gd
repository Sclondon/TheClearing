class_name Tribesman
extends Node3D
## One of the masked tribe: a lost boy of the maze gone wild long ago, after Lord
## of the Flies. He is the boy (the very body the players have, on CharacterRig),
## his skin daubed grey with clay and ash, in what is left of his shirt and
## breeches, barefoot in the mud; his face hidden entirely behind a big crude
## carved mask of wood, bone or bark (five, each different: `mask`); in his fist a
## sharpened stick of a spear with a stone or bone point (`point`). He drums the
## butt of his spear on the ground and chants when he finds someone (`chant`),
## draws back and throws it, a call going with it (`wind_up`, then `loose`), and
## jabs with it close up (`jab`); thrown, he must go and take it up again
## (`pick_up`).
##
## This is only how he looks, moves and sounds. He does no thinking: a game drives
## him. Put him where he is each frame and say how fast he is going.
##
##     var man := Tribesman.new()
##     man.mask = 2                          # 0..4
##     man.point = TribeSpear.Point.BONE
##     add_child(man)
##     man.put(spawn_point, spawn_yaw)
##     # each frame:
##     man.global_position = body_position
##     man.rotation.y = facing_yaw            # 0 faces +Z
##     man.velocity = body_velocity           # his feet go with this (the boy's walk, run and sprint)
##     man.stalking = false                   # true: he creeps, crouched (the boy's sneak)
##     man.aim = target + Vector3.UP          # what he looks at, throws at and jabs at (INF: nothing)
##     # when you like:
##     man.chant()                            # `called` at the first blow of the drumming
##     man.wind_up()                          # drawn back, aimed at `aim`, held until...
##     man.loose(Tribesman.launch(man.spear_point(), target, 17.0, man.spear.gravity))
##     man.jab()                              # test jab_hits(...) while stage() is THRUST or HOLD
##     man.pick_up()                          # takes his spear up again from where it lies (near him)
##
## `spear` (a TribeSpear, top level) is his spear in his hand or in flight or
## lying where it fell; ask it `hits(...)` while it flies. Needs GameCommon's
## character-controller (CharacterRig, Player, Toon, Dust, Settings, Looks and the
## boy's shapes). The masks, spears and the totem are made by
## creatures/masked_tribe/tools/build_tribe.py in Blender.

## The first blow of the drumming: whoever is to be called by it is called now.
signal called
## The spear has left his hand.
signal released(spear: TribeSpear)
## A jab has begun to go out: test `jab_hits` from now while `stage()` is THRUST or HOLD.
signal thrusting

const MASKS := "res://creatures/masked_tribe/models/masks.glb"
const MASKS_LO := "res://creatures/masked_tribe/models/masks_lo.glb"
const TOTEM := "res://creatures/masked_tribe/models/totem.glb"
const TOTEM_LO := "res://creatures/masked_tribe/models/totem_lo.glb"
## How many masks there are (`mask` 0 .. MASK_COUNT - 1).
const MASK_COUNT := 5
## How long taking up his spear takes, seconds (his hand closes on it halfway: Player.PICKUP_TAKES).
const PICK_TIME := 0.8
## His skin, daubed with grey clay; the stripes of ash across it; his breeches; the mud on his feet.
const CLAY := Color(0.33, 0.33, 0.315)
const ASH := 0.22
const RAG_DARK := Color(0.21, 0.2, 0.19)
const MUD := Color(0.3, 0.28, 0.26)
const MATTED := Color(0.13, 0.12, 0.11)

## Which mask he wears, 0..4: a long face of wood with stick horns, a bleached
## beast's skull with antlers, a round bark face in a crown of sticks, a white
## oval under a fan of black feathers, a tusked beast's face hung with bark.
@export_range(0, 4) var mask := 0
## His spear's head.
@export var point := TribeSpear.Point.STONE
## The low-poly boy and masks (or `Settings.low_poly`).
@export var low_poly := false
## His voice and drumming, made in code, from where he stands.
@export var sound := true
@export var volume_db := 2.0
@export var sound_range := 55.0
## A little more or less grey to his clay (each boy daubed by his own hand).
@export var clay_tint := 1.0

## How fast he is going, world units a second. His feet go with this.
var velocity := Vector3.ZERO
## Whether he is on the ground.
var grounded := true
## Creeping, crouched low (the boy's sneak).
var stalking := false
## What he is after: looked at, thrown at, jabbed at (INF: nothing).
var aim := Vector3.INF
## His spear (made when he goes in).
var spear: TribeSpear

## For the rig, which reads his body as it would a Player's.
var is_pushing := false
var is_ducking: bool:
	get:
		return stalking
var walk_speed: float:
	get:
		return 1.6 * global_basis.get_scale().y
var run_speed: float:
	get:
		return 4.4 * global_basis.get_scale().y
var sprint_speed: float:
	get:
		return 5.6 * global_basis.get_scale().y
var pickup_progress := 1.0
var pickup_point := Vector3.ZERO

var _rig: TribesmanRig
var _mask: MeshInstance3D
var _rags: MeshInstance3D
var _chant_voice: AudioStreamPlayer3D
var _yell_voice: AudioStreamPlayer3D
var _called := true
var _thrust := true
var _jab_tip_was := Vector3.ZERO
static var _carved: ShaderMaterial
static var _mask_meshes := {}
static var _chant: AudioStreamWAV
static var _yell: AudioStreamWAV


func _ready() -> void:
	spear = TribeSpear.new()
	spear.point = point
	spear.low_poly = low_poly
	add_child(spear)
	_rig = TribesmanRig.new()
	_rig.low_poly = low_poly
	_rig.cap_hand = false
	# (hunched, his head thrust forward: nothing of the boy's ease left in him)
	_rig.stoop = 0.2
	_rig.spear = spear
	add_child(_rig)
	_dress()
	_mask = MeshInstance3D.new()
	_mask.mesh = mask_mesh(mask, low_poly or Settings.low_poly)
	_mask.material_override = carved()
	_rig._head.add_child(_mask)
	_rags = MeshInstance3D.new()
	_rags.mesh = mask_mesh(-1, low_poly or Settings.low_poly)
	_rags.material_override = carved()
	_rig._hips.add_child(_rags)
	if sound:
		_chant_voice = _voice(chant_sound())
		_yell_voice = _voice(yell_sound())


func _voice(stream: AudioStreamWAV) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.unit_size = 8.0
	voice.max_distance = sound_range
	voice.position = Vector3(0.0, 1.1, 0.1)
	voice.pitch_scale = 0.94 + 0.03 * (mask % 5)
	add_child(voice)
	return voice


## Turns the boy out as one of them: bare to the waist, his skin daubed grey with
## clay and striped with ash, breeches cut off at the knee with a fringe of rags
## knotted over them (what is left of his shirt), bare muddy feet; the plain
## face (it is never seen).
func _dress() -> void:
	var look := Looks.decode("", 0)
	var colours: Dictionary = look["colours"]
	colours["skin"] = Color(CLAY.r * clay_tint, CLAY.g * clay_tint, CLAY.b * clay_tint)
	# (his shirt is long gone: where it was is his skin, striped with ash)
	colours["shirt"] = colours["skin"]
	colours["overalls"] = RAG_DARK
	colours["boots"] = MUD
	colours["socks"] = MUD
	colours["hair"] = MATTED
	Looks.apply(_rig, look)
	var parts: Dictionary = _rig.look["parts"]
	parts["body"] = "base"
	parts["over"] = "none"
	parts["patch"] = "none"
	_rig.restyle()
	for part: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var made := part.mesh.surface_get_material(surface)
			var worn := part.get_surface_override_material(surface) as ShaderMaterial
			if made and made.resource_name == "shirt" and worn:
				# (the shirt's fine stripe, made broad: bands of ash daubed round him)
				worn.set_shader_parameter(&"stripe", ASH)
				worn.set_shader_parameter(&"stripe_gap", 0.2 + 0.03 * (mask % 3))
				worn.set_shader_parameter(&"stripe_width", 0.06)


func is_on_floor() -> bool:
	return grounded


func _process(delta: float) -> void:
	_rig.aim = aim
	_rig.armed = spear.held()
	var t := _rig.act_time()
	if not _called and _rig._doing == TribesmanRig.Act.CHANT and t >= TribesmanRig.BEATS[0]:
		_called = true
		called.emit()
	if not _thrust and _rig._doing == TribesmanRig.Act.JAB and t >= TribesmanRig.GATHER:
		_thrust = true
		thrusting.emit()
	# Taking his spear up again: his hand closes on it halfway through.
	if pickup_progress < 1.0:
		pickup_progress = minf(pickup_progress + delta / PICK_TIME, 1.0)
		if not spear.held() and pickup_progress >= Player.PICKUP_TAKES:
			spear.hold(_rig.spear_transform())


func _physics_process(_delta: float) -> void:
	_jab_tip_was = _rig.spear_tip() if _rig and spear.held() else Vector3.ZERO


## Plants himself and drums his spear on the ground, chanting (`called` at the
## first blow); the whole takes TribesmanRig.CHANT.
func chant() -> void:
	_rig.act(TribesmanRig.Act.CHANT)
	_called = false
	if _chant_voice:
		_chant_voice.play()


## Turns side on and draws his spear back over his shoulder, aimed at `aim`, with
## a call; he holds it there until `loose`. (Unarmed, he does nothing.)
func wind_up() -> void:
	if not spear.held():
		return
	_rig.act(TribesmanRig.Act.THROW)
	if _yell_voice:
		_yell_voice.play()


## Throws: the spear leaves his hand now, at `going` (see `launch`), and he
## follows through.
func loose(going: Vector3) -> void:
	if not spear.held():
		return
	_rig.loose()
	spear.throw(going)
	released.emit(spear)


## Stops a wind-up (or anything) where it is and stands easy.
func cancel() -> void:
	_rig.act(TribesmanRig.Act.NONE)


## Draws his spear back at his hip and drives it out at `aim`, both hands on it
## (`thrusting` as it goes out).
func jab() -> void:
	if not spear.held():
		return
	_rig.act(TribesmanRig.Act.JAB)
	_thrust = false


## Whether the point of his jab, going out, passes through an upright body (one
## standing on `feet`, `height` tall, `radius` round). Only while it goes out
## and is held there (THRUST, HOLD), or `always`.
func jab_hits(feet: Vector3, height: float, radius: float, always := false) -> bool:
	if not spear.held():
		return false
	var now := stage()
	if not always and now != TribesmanRig.Stage.THRUST and now != TribesmanRig.Stage.HOLD:
		return false
	var tip := _rig.spear_tip()
	var from := _jab_tip_was if _jab_tip_was != Vector3.ZERO else tip
	return TribeSpear.passes(from, tip, feet, height, radius)


## Stoops and takes his spear up from where it lies (it must be near: within his
## reach of where he stands). Over PICK_TIME.
func pick_up() -> void:
	if spear.held() or pickup_progress < 1.0:
		return
	pickup_point = spear.lying_at()
	pickup_progress = 0.0


## Back in his hand at once (as if he had another).
func rearm() -> void:
	pickup_progress = 1.0
	spear.hold(_rig.spear_transform())


## Whether the spear is in his hand.
func armed() -> bool:
	return spear.held() and pickup_progress >= Player.PICKUP_TAKES


func doing() -> TribesmanRig.Act:
	return _rig._doing if _rig else TribesmanRig.Act.NONE


func stage() -> TribesmanRig.Stage:
	return _rig.stage() if _rig else TribesmanRig.Stage.NONE


func busy() -> bool:
	return doing() != TribesmanRig.Act.NONE or pickup_progress < 1.0


## How long a call or a jab takes (a throw: from its loosing), seconds.
static func act_length(what: TribesmanRig.Act) -> float:
	match what:
		TribesmanRig.Act.CHANT:
			return TribesmanRig.CHANT
		TribesmanRig.Act.THROW:
			return TribesmanRig.LOOSE + TribesmanRig.FOLLOW
		TribesmanRig.Act.JAB:
			return TribesmanRig.GATHER + TribesmanRig.THRUST + TribesmanRig.HOLD + TribesmanRig.RECOVER
	return 0.0


## Where the point of the spear in his hand is (or the spear itself, out of it).
func spear_point() -> Vector3:
	return _rig.spear_tip() if spear.held() else spear.tip()


## Where his eyes are (behind the mask), for what should see what he sees.
func eyes() -> Vector3:
	return _rig._head.global_transform * Vector3(0.0, 0.11, 0.12)


## Puts him straight somewhere, standing as he is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO


## The speed to throw at to come down on `to` from `from` at `speed` (the flat,
## quick way; lobbed at 45° if it is out of reach), falling at `gravity`.
static func launch(from: Vector3, to: Vector3, speed: float, gravity: float) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d := flat.length()
	var h := to.y - from.y
	if d < 0.05:
		return (to - from).normalized() * speed
	var v2 := speed * speed
	var root := v2 * v2 - gravity * (gravity * d * d + 2.0 * h * v2)
	var angle := PI * 0.25
	if root >= 0.0:
		angle = atan((v2 - sqrt(root)) / (gravity * d))
	return flat / d * cos(angle) * speed + Vector3.UP * sin(angle) * speed


## The one material of the masks, spears and totem: the figures' cel shading
## (Toon), its tones taken from the model's vertex colours.
static func carved() -> ShaderMaterial:
	if _carved:
		return _carved
	var shader := Shader.new()
	shader.code = Toon.SHADER.replace("ALBEDO = albedo * (1.0 - stripe * line);", "ALBEDO = albedo * COLOR.rgb * (1.0 - stripe * line);")
	_carved = ShaderMaterial.new()
	_carved.shader = shader
	_carved.set_shader_parameter(&"albedo", Color.WHITE)
	_carved.set_shader_parameter(&"rim_gain", 0.35)
	_carved.set_shader_parameter(&"wrap", 0.1)
	return _carved


## Mask `which` (shared), in the space of the boy's head joint; -1: the fringe
## of rags at his waist, in the space of his hips joint.
static func mask_mesh(which: int, low := false) -> Mesh:
	var key := "%d%s" % [which, "lo" if low else ""]
	if not _mask_meshes.has(key):
		var scene := (load(MASKS_LO if low else MASKS) as PackedScene).instantiate()
		var called := "rags" if which < 0 else "mask%d" % clampi(which, 0, MASK_COUNT - 1)
		var found := scene.find_child(called, true, false) as MeshInstance3D
		_mask_meshes[key] = found.mesh if found else null
		scene.free()
	return _mask_meshes[key]


## The tribe's totem: a pole in a cairn, a beast's skull on top, hung with bones
## and teeth, sharpened sticks round its foot. Its foot at the origin. One draw.
static func totem(low := false) -> MeshInstance3D:
	var scene := (load(TOTEM_LO if low or Settings.low_poly else TOTEM) as PackedScene).instantiate()
	var found := scene.find_child("totem", true, false) as MeshInstance3D
	var made := MeshInstance3D.new()
	made.mesh = found.mesh if found else null
	made.material_override = carved()
	scene.free()
	return made


## The call, made once and shared: spear butts driven into hard ground and a
## boy's voice, hoarse from shouting, barking with each blow, "hu! hu! hu!",
## and the last a long rising "haa-ah" (the voice through the resonances of an
## "oo" for the barks, an "ah" for the last; a second voice a little behind and
## off pitch, as if others were with him). 1.75 s.
static func chant_sound() -> AudioStreamWAV:
	if _chant:
		return _chant
	var rate := 22050
	var length := TribesmanRig.CHANT
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var samples := PackedFloat32Array()
	samples.resize(count)
	var thud := Band.new(90.0, 3.0, rate)
	var knock := Band.new(900.0, 4.0, rate)
	var voices: Array = []
	for k in 2:
		voices.append([Band.new(450.0, 4.0, rate), Band.new(1000.0, 5.0, rate), Band.new(2600.0, 6.0, rate)])
	var phases := [0.0, 0.0]
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		# The blows: a dull thump and the knock of wood on the ground.
		for beat in TribesmanRig.BEATS:
			var d := t - beat
			if d >= 0.0 and d < 0.3:
				var hit := exp(-d * 22.0)
				value += thud.run(rng.randf_range(-1.0, 1.0) * hit * 4.0 + sin(TAU * 70.0 * d) * hit * 0.6) * 2.5
				value += knock.run(rng.randf_range(-1.0, 1.0) * exp(-d * 90.0)) * 0.8
		# The voices: a bark at each blow, the last long and rising.
		var voiced := 0.0
		var ah := 0.0
		var loud := 0.0
		for k in TribesmanRig.BEATS.size():
			var d: float = t - TribesmanRig.BEATS[k] - 0.01
			var last := k == TribesmanRig.BEATS.size() - 1
			var span := 0.32 if last else 0.17
			if d >= 0.0 and d < span:
				loud = maxf(loud, smoothstep(0.0, 0.02, d) * (1.0 - smoothstep(span * 0.6, span, d)))
				if last:
					ah = smoothstep(0.03, 0.12, d)
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		for k in 2:
			var behind := 0.012 * k
			var pitch := (215.0 + 30.0 * ah + 60.0 * ah * smoothstep(1.42, 1.62, t)) * (1.0 + 0.04 * wander) * (1.0 + 0.025 * k)
			var before: float = phases[k]
			phases[k] += pitch / rate * (1.0 + rng.randf_range(-0.04, 0.04))
			var p := fposmod(phases[k], 1.0)
			var glottal := pow(1.0 - p, 5.0) * 2.0 - 0.33
			var bands: Array = voices[k]
			(bands[0] as Band).set_frequency(lerpf(450.0, 780.0, ah), 4.0)
			(bands[1] as Band).set_frequency(lerpf(1000.0, 1250.0, ah), 5.0)
			var v := (bands[0] as Band).run(glottal) + (bands[1] as Band).run(glottal) * 0.6 + (bands[2] as Band).run(glottal) * 0.2
			v += rng.randf_range(-1.0, 1.0) * 0.25
			voiced += v * (1.0 if k == 0 else 0.6) * (1.0 if behind == 0.0 else 0.9)
		value += voiced * loud * 1.4
		value = tanh(value * 1.6)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_chant = _wav(samples, rate, loudest)
	return _chant


## The call that goes with a throw: a hoarse "hyah!" thrown out, rising and
## breaking off. 0.5 s.
static func yell_sound() -> AudioStreamWAV:
	if _yell:
		return _yell
	var rate := 22050
	var length := 0.5
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat: Array[Band] = [Band.new(700.0, 4.0, rate), Band.new(1200.0, 5.0, rate), Band.new(2700.0, 6.0, rate)]
	var hiss := Band.new(3000.0, 1.5, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var loud := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.3, 0.48, t))
		# ("h", then "ya": the throat opening from an "ee" to an "ah")
		var open := smoothstep(0.02, 0.12, t)
		var pitch := 250.0 + 150.0 * smoothstep(0.03, 0.2, t) - 90.0 * smoothstep(0.25, 0.45, t)
		phase += pitch / rate * (1.0 + rng.randf_range(-0.05, 0.05))
		var p := fposmod(phase, 1.0)
		var glottal := pow(1.0 - p, 5.0) * 2.0 - 0.33
		throat[0].set_frequency(lerpf(330.0, 780.0, open), 4.0)
		throat[1].set_frequency(lerpf(2200.0, 1250.0, open), 5.0)
		var v := throat[0].run(glottal) + throat[1].run(glottal) * 0.55 + throat[2].run(glottal) * 0.2
		var breath := hiss.run(rng.randf_range(-1.0, 1.0)) * (0.9 * (1.0 - open) + 0.35)
		var value := tanh((v * 1.6 + breath) * loud * 2.0)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_yell = _wav(samples, rate, loudest)
	return _yell


static func _wav(samples: PackedFloat32Array, rate: int, loudest: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## A resonant band-pass filter (a biquad), for the voice and the drum.
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
