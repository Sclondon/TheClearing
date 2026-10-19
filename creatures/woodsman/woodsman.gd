class_name Woodsman
extends Node3D
## The woodsman, after Over the Garden Wall's: a tall, gaunt, weary old man in a
## long coat and a battered top hat, a felling axe over his shoulder and an oil
## lantern held out before him, its warm light the one warm thing in the grey
## halls. He walks slowly, stooped, chops at the ivy on the walls (`chop`), holds
## his lantern up at whoever is there (`raise`), and swings his axe down at them
## when they will not leave him be (`swing`, then `strike`).
##
## The body is the boy's (CharacterRig on models/boy.glb: his walk, his stoop, his
## head turning), drawn half again as tall, his own head hidden and an old man's
## hung in its place; the coat, collar, axe and lantern are hung on his joints.
## Made in Blender by creatures/woodsman/tools/build_woodsman.py.
##
## This is only how he looks, moves and sounds. He does no thinking: a game moves
## him and says what he does.
##
##     var man := Woodsman.new()
##     add_child(man)
##     man.put(spawn_point, spawn_yaw)
##     # each frame:
##     man.global_position = body_position
##     man.rotation.y = facing_yaw            # 0 faces +Z
##     man.velocity = body_velocity           # his feet go with this (the boy's walk)
##     man.aim = something + Vector3.UP       # what he looks at (INF: nothing)
##     man.raise = 1.0                        # his lantern held up at `aim` (0: at his waist)
##     # when you like:
##     man.chop()                             # three chops at what is in front of him; `chopped` each
##     man.swing()                            # the axe up over his head, held until...
##     man.strike()                           # ...brought down; `struck` as it lands
##     man.grunt()                            # a low warning
##
## His lantern is `lantern` (an OilLantern, top level): its glow and its light.
## Needs GameCommon's character-controller (CharacterRig, Toon, Looks, Settings).

## An axe has bitten into the wall (in a `chop`).
signal chopped
## The swung axe has come down: where its blade is now is `blade()`.
signal struck

const MODEL := "res://creatures/woodsman/models/woodsman.glb"
const MODEL_LO := "res://creatures/woodsman/models/woodsman_lo.glb"
## How much taller than the boy he is drawn (the boy stands about 1.2 m).
const SIZE := 1.62
## How broad he is for his height, against the boy (a grown man's build, thinner: CharacterLook's "build").
const BUILD := 0.86
## The render layer he is drawn on (his lantern's light leaves it out). The angel has 11.
const OWN_LAYER := 12
## His clothes: the coat, his shirt under it, trousers, boots, his hands.
const COAT := Color(0.15, 0.135, 0.125)
const SHIRT := Color(0.27, 0.26, 0.24)
const TROUSERS := Color(0.13, 0.125, 0.12)
const BOOTS := Color(0.09, 0.08, 0.075)
const HANDS := Color(0.44, 0.4, 0.36)
## His lantern's flame.
const FLAME := Color(1.0, 0.68, 0.34)

## The low-poly figure and props (or `Settings.low_poly`).
@export var low_poly := false
## His sounds (his steps, his axe, his lantern's creak, his voice), made in code.
@export var sound := true
@export var volume_db := 0.0
@export var sound_range := 40.0
## His lantern's light (off: it glows, but lights nothing round it).
@export var lights := true

## How fast he is going, world units a second. His feet go with this.
var velocity := Vector3.ZERO
var grounded := true
## What he looks at (INF: nothing).
var aim := Vector3.INF
## How far his lantern is held up at `aim`, 0..1.
var raise := 0.0
## His lantern (made when he goes in).
var lantern: OilLantern

## For the rig, which reads his body as it would a Player's.
var is_pushing := false
var is_ducking := false
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

var _rig: WoodsmanRig
var _chop_voice: AudioStreamPlayer3D
var _step_voice: AudioStreamPlayer3D
var _grunt_voice: AudioStreamPlayer3D
var _swish_voice: AudioStreamPlayer3D
var _chops_heard := 0
var _struck := true
static var _carved: ShaderMaterial
static var _meshes := {}
static var _chop_wav: AudioStreamWAV
static var _step_wav: AudioStreamWAV
static var _grunt_wav: AudioStreamWAV
static var _swish_wav: AudioStreamWAV


func _ready() -> void:
	# (drawn half again as tall as the boy, and narrower for it: gaunt. His speeds go with
	# his height, as the rig reads them)
	scale = Vector3(SIZE * BUILD, SIZE, SIZE * BUILD)
	_rig = WoodsmanRig.new()
	_rig.low_poly = low_poly
	_rig.cap_hand = false
	# (bent with his years, his head forward; slow and stiff, nothing loose about him)
	_rig.stoop = 0.3
	_rig.looseness = 0.45
	add_child(_rig)
	_dress()
	var low := low_poly or Settings.low_poly
	_hang(_rig._head, "head", low)
	_hang(_rig._hips, "coat", low)
	_hang(_rig._chest if _rig._chest else _rig._spine, "collar", low)
	var axe := _hang(_rig._hands[1], "axe", low)
	# (in his fist as a spear is: the grip in his hand, the head down -Z, the edge down -Y)
	axe.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), CharacterRig.GUN_IN_HAND)
	_rig.axe = axe
	lantern = OilLantern.new()
	lantern.size = SIZE
	lantern.flame = FLAME
	# (it lights the halls round him: both walls of a wide one)
	lantern.light_range = 12.0
	lantern.light_energy = 2.0
	lantern.low_poly = low
	lantern.lights = lights
	lantern.sound = sound
	lantern.leaves_out = 1 << (OWN_LAYER - 1)
	add_child(lantern)
	# (he is drawn on a layer of his own, which his lantern's light leaves out: it lights the
	# halls round him, and he stands dark against them, as the woodsman of the story does)
	for drawn: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		drawn.layers = 1 << (OWN_LAYER - 1)
	if sound:
		_chop_voice = _voice(chop_sound(), 6.0)
		_step_voice = _voice(step_sound(), 3.0)
		_step_voice.volume_db = volume_db - 6.0
		_grunt_voice = _voice(grunt_sound(), 6.0)
		_swish_voice = _voice(swish_sound(), 5.0)
		_rig.footfall.connect(_on_footfall)


## Hangs the model's `called` on `joint` (a MeshInstance3D, one draw).
func _hang(joint: Node3D, called: String, low: bool) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.mesh = part(called, low)
	made.material_override = carved()
	joint.add_child(made)
	return made


func _voice(stream: AudioStreamWAV, unit: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.unit_size = unit
	voice.max_distance = sound_range
	voice.position = Vector3(0.0, 0.9, 0.1)
	add_child(voice)
	return voice


## Turns the boy out as the old man: a long coat (the boy's suit jacket, in the
## coat's cloth) over a grey shirt, dark trousers and boots, his own head, hair
## and face hidden (the old man's is hung on in their place).
func _dress() -> void:
	var look := Looks.decode("", 0)
	var colours: Dictionary = look["colours"]
	colours["skin"] = HANDS
	colours["shirt"] = SHIRT
	colours["jacket"] = COAT
	colours["brass"] = Color(0.22, 0.2, 0.18)
	colours["overalls"] = TROUSERS
	colours["boots"] = BOOTS
	colours["socks"] = BOOTS
	Looks.apply(_rig, look)
	var parts: Dictionary = _rig.look["parts"]
	parts["body"] = "suit"
	for slot: String in ["over", "patch", "head", "hair", "hairtop", "face", "locks", "skirt"]:
		parts[slot] = "none"
	_rig.look["cap"] = false
	_rig.restyle()
	# (the suit's jacket is short-sleeved and open over the boy's skin: here the coat's
	# cloth goes over all of it, his arms and up round his neck, and his shirt is dark)
	var cloth := {"skin": COAT, "jacket": COAT, "shirt": SHIRT}
	for part: MeshInstance3D in _rig.find_children("*_body__suit", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var made := part.mesh.surface_get_material(surface)
			var worn := part.get_surface_override_material(surface) as ShaderMaterial
			if made == null or worn == null or not cloth.has(made.resource_name):
				continue
			var mine := worn.duplicate() as ShaderMaterial
			mine.set_shader_parameter(&"albedo", cloth[made.resource_name])
			mine.set_shader_parameter(&"stripe", 0.0)
			part.set_surface_override_material(surface, mine)


func is_on_floor() -> bool:
	return grounded


func _process(_delta: float) -> void:
	_rig.aim = aim
	_rig.raise = raise
	lantern.hold = _rig.lantern_hold()
	lantern.yaw = rotation.y
	if _rig._doing == WoodsmanRig.Act.CHOP:
		var landed := _rig.chops_landed()
		if landed > _chops_heard:
			_chops_heard = landed
			chopped.emit()
			if _chop_voice:
				_chop_voice.pitch_scale = randf_range(0.9, 1.08)
				_chop_voice.play()
	if not _struck and _rig.stage() in [WoodsmanRig.Stage.STRIKE, WoodsmanRig.Stage.THROUGH] and _rig.act_time() - _rig._struck_at >= WoodsmanRig.STRIKE * 0.8:
		_struck = true
		struck.emit()


## Three chops at what is in front of him (`aim`: the wall, the ivy); `chopped` as each bites.
func chop() -> void:
	_rig.act(WoodsmanRig.Act.CHOP)
	_chops_heard = 0


## The axe raised high over his head at `aim`, held there (the warning) until `strike`.
func swing() -> void:
	_rig.act(WoodsmanRig.Act.SWING)
	_struck = false


## Brings a raised axe down (`struck` as it lands).
func strike() -> void:
	_rig.strike()
	if _swish_voice:
		_swish_voice.play()


## Stops whatever he is doing and stands easy.
func cancel() -> void:
	_rig.act(WoodsmanRig.Act.NONE)


## A low warning, deep in his chest: "hmm-mm", and a breath out.
func grunt() -> void:
	if _grunt_voice:
		_grunt_voice.play()


func doing() -> WoodsmanRig.Act:
	return _rig._doing if _rig else WoodsmanRig.Act.NONE


func stage() -> WoodsmanRig.Stage:
	return _rig.stage() if _rig else WoodsmanRig.Stage.NONE


func busy() -> bool:
	return doing() != WoodsmanRig.Act.NONE


## Whether the axe is up and held, waiting to come down.
func raised() -> bool:
	return stage() == WoodsmanRig.Stage.WIND and _rig.act_time() >= WoodsmanRig.WIND * 0.9


## Where the axe's blade is, in the world.
func blade() -> Vector3:
	return _rig.blade_point()


## Where his eyes are, under the brim of his hat.
func eyes() -> Vector3:
	return _rig._head.global_transform * Vector3(0.0, 0.09, 0.06)


## Puts him straight somewhere, standing as he is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if lantern:
		lantern.put(at + Vector3.UP * 1.0, yaw)


func _on_footfall(_at: Vector3, _foot: int, weight: float) -> void:
	if _step_voice and weight > 0.2:
		_step_voice.pitch_scale = randf_range(0.85, 1.05)
		_step_voice.volume_db = volume_db - 9.0 + 6.0 * clampf(weight, 0.0, 1.0)
		_step_voice.play()


## A part of his model (shared).
static func part(called: String, low := false) -> Mesh:
	var key := called + ("lo" if low else "")
	if not _meshes.has(key):
		var scene := (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
		var found := scene.find_child(called, true, false) as MeshInstance3D
		_meshes[key] = found.mesh if found else null
		scene.free()
	return _meshes[key]


## The one material of what is hung on him: the figures' cel shading (Toon), its
## tones taken from the model's vertex colours.
static func carved() -> ShaderMaterial:
	if _carved:
		return _carved
	var shader := Shader.new()
	shader.code = Toon.SHADER.replace("ALBEDO = albedo * (1.0 - stripe * line);", "ALBEDO = albedo * COLOR.rgb * (1.0 - stripe * line);")
	_carved = ShaderMaterial.new()
	_carved.shader = shader
	_carved.set_shader_parameter(&"albedo", Color.WHITE)
	_carved.set_shader_parameter(&"rim_gain", 0.3)
	_carved.set_shader_parameter(&"wrap", 0.1)
	return _carved


# --- Sounds (made in code, once, shared) ---

## An axe biting into wood and ivy against stone: a hard knock, a dull thud under
## it, the crack of the stems and a patter of leaves. 0.5 s.
static func chop_sound() -> AudioStreamWAV:
	if _chop_wav:
		return _chop_wav
	var rate := 22050
	var count := int(rate * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var samples := PackedFloat32Array()
	samples.resize(count)
	var knock := Band.new(1400.0, 6.0, rate)
	var thud := Band.new(160.0, 2.5, rate)
	var crack := Band.new(3200.0, 2.0, rate)
	var leaves := Band.new(5200.0, 0.8, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		var value := knock.run(noise * exp(-t * 70.0)) * 2.2
		value += thud.run(noise * exp(-t * 25.0) * 3.0 + sin(TAU * 110.0 * t) * exp(-t * 30.0) * 0.4) * 2.0
		value += crack.run(noise * exp(-maxf(t - 0.01, 0.0) * 120.0) * (1.0 if t > 0.01 else 0.0)) * 0.9
		# (the leaves, pattering down a little after)
		var patter := smoothstep(0.03, 0.08, t) * (1.0 - smoothstep(0.25, 0.48, t)) * (0.4 + 0.6 * float(rng.randf() < 0.15))
		value += leaves.run(noise * patter) * 0.5
		value = tanh(value * 1.3)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_chop_wav = wav(samples, rate, loudest)
	return _chop_wav


## A heavy old boot coming down in the mud: a soft thud and a squelch. 0.22 s.
static func step_sound() -> AudioStreamWAV:
	if _step_wav:
		return _step_wav
	var rate := 22050
	var count := int(rate * 0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	var samples := PackedFloat32Array()
	samples.resize(count)
	var thud := Band.new(120.0, 1.5, rate)
	var squelch := Band.new(700.0, 3.0, rate)
	var grit := Band.new(2600.0, 1.2, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		var value := thud.run(noise * exp(-t * 40.0) * 3.0) * 2.0
		var wet := smoothstep(0.02, 0.05, t) * exp(-maxf(t - 0.05, 0.0) * 30.0)
		squelch.set_frequency(700.0 + 500.0 * smoothstep(0.03, 0.15, t), 3.0)
		value += squelch.run(noise * wet) * 0.9
		value += grit.run(noise * exp(-t * 60.0)) * 0.3
		value = tanh(value * 1.4)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_step_wav = wav(samples, rate, loudest)
	return _step_wav


## His warning: an old man's low "hmm-mm", deep and hoarse, falling, and a
## breath let out after it (a voice through the resonances of a closed "mm",
## opening a little to an "uh"). 1.3 s.
static func grunt_sound() -> AudioStreamWAV:
	if _grunt_wav:
		return _grunt_wav
	var rate := 22050
	var count := int(rate * 1.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 85
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat: Array[Band] = [Band.new(260.0, 3.0, rate), Band.new(700.0, 4.0, rate), Band.new(2300.0, 5.0, rate)]
	var breath := Band.new(1100.0, 0.9, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		# ("hmm", a dip, "mm", then the breath)
		var hum := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.32, 0.4, t)) + smoothstep(0.42, 0.48, t) * (1.0 - smoothstep(0.78, 0.9, t)) * 0.85
		var pitch := 98.0 - 10.0 * smoothstep(0.0, 0.4, t) + 6.0 * smoothstep(0.42, 0.5, t) - 18.0 * smoothstep(0.5, 0.9, t)
		phase += pitch / rate * (1.0 + rng.randf_range(-0.03, 0.03))
		var p := fposmod(phase, 1.0)
		var glottal := pow(1.0 - p, 4.0) * 2.0 - 0.4
		var open := smoothstep(0.6, 0.85, t) * 0.6
		throat[0].set_frequency(lerpf(260.0, 520.0, open), 3.0)
		throat[1].set_frequency(lerpf(900.0, 1100.0, open), 4.0)
		var v := throat[0].run(glottal) + throat[1].run(glottal) * (0.25 + 0.4 * open) + throat[2].run(glottal) * 0.08
		# (the rasp in an old throat)
		v *= 1.0 + 0.35 * rng.randf_range(-1.0, 1.0)
		var out := smoothstep(0.85, 0.92, t) * (1.0 - smoothstep(1.05, 1.28, t))
		var value := tanh((v * hum * 1.4 + breath.run(rng.randf_range(-1.0, 1.0)) * out * 0.5) * 1.8)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_grunt_wav = wav(samples, rate, loudest)
	return _grunt_wav


## The axe coming down through the air: a rising, falling whoosh. 0.4 s.
static func swish_sound() -> AudioStreamWAV:
	if _swish_wav:
		return _swish_wav
	var rate := 22050
	var count := int(rate * 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	var samples := PackedFloat32Array()
	samples.resize(count)
	var air := Band.new(600.0, 1.4, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var loud := smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.16, 0.38, t))
		air.set_frequency(500.0 + 1300.0 * sin(clampf(t / 0.32, 0.0, 1.0) * PI), 1.4)
		var value := tanh(air.run(rng.randf_range(-1.0, 1.0)) * loud * 3.0)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_swish_wav = wav(samples, rate, loudest)
	return _swish_wav


static func wav(samples: PackedFloat32Array, rate: int, loudest: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	made.data = data
	return made


## A resonant band-pass filter (a biquad), for the voices and the knocks.
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
