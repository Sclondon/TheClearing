class_name Beast
extends Node3D
## The beast, after Over the Garden Wall's: a tall shadow in the dark, black as a
## silhouette, great branching antlers like dead boughs, two pale burning eyes,
## and a lantern of its own glowing faintly in its fist. It is seen mostly from
## far off, standing still at the end of a hall; it holds its lantern up to whoever
## is alone and hums to them (`lure`), and it reaches for them with its long
## hands (`reach`).
##
## The body is the boy's (CharacterRig on models/boy.glb) drawn more than twice as
## tall and black, his own head hidden and the beast's hung in its place; the
## shroud over its shoulders and its long skirts are hung on its joints. Made in
## Blender by creatures/beast/tools/build_beast.py. Its lantern is the woodsman's
## (OilLantern, creatures/woodsman/), cold and faint.
##
## This is only how it looks, moves and sounds. It does no thinking: a game moves it.
##
##     var beast := Beast.new()
##     add_child(beast)
##     beast.put(spawn_point, spawn_yaw)
##     # each frame:
##     beast.global_position = body_position
##     beast.rotation.y = facing_yaw
##     beast.velocity = body_velocity
##     beast.aim = someone + Vector3.UP        # what it looks at (INF: nothing)
##     beast.lure = 1.0                        # its lantern up and bright, humming (0: faint, at its side)
##     beast.burn = 1.0                        # how brightly its eyes burn
##     # when you like:
##     beast.reach()                           # the warning, then the grab; `grabbing` as the hands close
##
## Needs GameCommon's character-controller and creatures/woodsman (OilLantern, Woodsman.carved).

## Its hands have closed: whoever is at `hand()` now is taken.
signal grabbing

const MODEL := "res://creatures/beast/models/beast.glb"
const MODEL_LO := "res://creatures/beast/models/beast_lo.glb"
## How much taller than the boy it is drawn (about 2.8 m to the crown, the antlers over that).
const SIZE := 2.35
## The render layer it is drawn on (its lantern's light leaves it out). The woodsman has 12.
const OWN_LAYER := 13
const BLACK := Color(0.022, 0.021, 0.02)
## Its lantern's flame, cold and pale, and its eyes.
const FLAME := Color(0.72, 0.84, 0.76)
const EYES := Color(0.92, 0.95, 0.86)

@export var low_poly := false
@export var sound := true
@export var volume_db := 0.0
## How far its hum carries, metres.
@export var sound_range := 55.0
@export var lights := true

var velocity := Vector3.ZERO
var grounded := true
var aim := Vector3.INF
## Its lantern held up and bright, and its hum, 0..1 (its hum begins past a half).
var lure := 0.0
## How brightly its eyes burn, 0..1 (eased).
var burn := 0.7
var lantern: OilLantern

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

var _rig: BeastRig
var _eyes_material: ShaderMaterial
var _glow_material: ShaderMaterial
var _burning := 0.7
var _hum: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _grabbed := true
static var _meshes := {}
static var _hum_wav: AudioStreamWAV
static var _reach_wav: AudioStreamWAV

const EYES_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform vec3 colour : source_color = vec3(0.92, 0.95, 0.86);
uniform float burn = 1.0;
void fragment() {
	// (they burn through the mist: dimmed only a little by how far off they are)
	float far = clamp(exp(-length(VERTEX) * 0.01), 0.45, 1.0);
	ALBEDO = colour * (0.25 + 1.1 * burn) * far;
}
"""


func _ready() -> void:
	scale = Vector3.ONE * SIZE
	_rig = BeastRig.new()
	_rig.low_poly = low_poly
	_rig.cap_hand = false
	_rig.stoop = 0.22
	_rig.looseness = 0.3
	_rig.dusty = false
	add_child(_rig)
	_dress()
	var low := low_poly or Settings.low_poly
	_hang(_rig._head, "head", low)
	var eyes := _hang(_rig._head, "eyes", low)
	_eyes_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = EYES_SHADER
	_eyes_material.shader = shader
	_eyes_material.set_shader_parameter(&"colour", EYES)
	eyes.material_override = _eyes_material
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (and a soft glow round each, so that they are seen burning from far down a hall, in the dark)
	_glow_material = ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = OilLantern.HALO_SHADER
	_glow_material.shader = glow_shader
	_glow_material.set_shader_parameter(&"flame", EYES)
	for side: float in [1.0, -1.0]:
		var glow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.15
		glow.mesh = quad
		glow.material_override = _glow_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(side * 0.034, 0.112, 0.11)
		_rig._head.add_child(glow)
	_hang(_rig._chest if _rig._chest else _rig._spine, "cape", low)
	_hang(_rig._hips, "shroud", low)
	lantern = OilLantern.new()
	lantern.size = 1.5
	lantern.flame = FLAME
	lantern.light_range = 7.0
	lantern.light_energy = 0.9
	lantern.low_poly = low
	lantern.lights = lights
	lantern.sound = false
	lantern.glow = 0.3
	lantern.leaves_out = 1 << (OWN_LAYER - 1)
	add_child(lantern)
	# (drawn on a layer of its own, which its lantern's light leaves out: a shape cut out of the dark)
	for drawn: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		drawn.layers = 1 << (OWN_LAYER - 1)
	if sound:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = hum_sound()
		_hum.volume_db = -60.0
		_hum.unit_size = 14.0
		_hum.max_distance = sound_range
		_hum.position = Vector3(0.0, 1.0, 0.0)
		add_child(_hum)
		_creak = AudioStreamPlayer3D.new()
		_creak.stream = reach_sound()
		_creak.volume_db = volume_db
		_creak.unit_size = 8.0
		_creak.max_distance = sound_range
		_creak.position = Vector3(0.0, 1.0, 0.0)
		add_child(_creak)


func _hang(joint: Node3D, called: String, low: bool) -> MeshInstance3D:
	var made := MeshInstance3D.new()
	made.mesh = part(called, low)
	made.material_override = Woodsman.carved()
	joint.add_child(made)
	return made


## Black all over: the figure only a shape cut out of the dark.
func _dress() -> void:
	var look := Looks.decode("", 0)
	var colours: Dictionary = look["colours"]
	for key: String in ["skin", "shirt", "jacket", "brass", "overalls", "boots", "socks", "hair"]:
		colours[key] = BLACK
	Looks.apply(_rig, look)
	var parts: Dictionary = _rig.look["parts"]
	parts["body"] = "suit"
	for slot: String in ["over", "patch", "head", "hair", "hairtop", "face", "locks", "skirt"]:
		parts[slot] = "none"
	_rig.look["cap"] = false
	_rig.restyle()


func is_on_floor() -> bool:
	return grounded


func _process(delta: float) -> void:
	_rig.aim = aim
	_rig.lure = lure
	lantern.hold = _rig.lantern_hold()
	lantern.yaw = rotation.y
	lantern.glow = lerpf(0.28, 1.0, clampf(lure, 0.0, 1.0))
	var reaching := _rig._doing == BeastRig.Act.REACH and _rig.stage() == BeastRig.Stage.WIND
	_burning = move_toward(_burning, 1.0 if reaching else burn, delta * 2.0)
	_eyes_material.set_shader_parameter(&"burn", _burning)
	_glow_material.set_shader_parameter(&"glow", 0.4 + 1.2 * _burning)
	if _hum:
		# (its hum swells in as it lures, and dies away)
		var want := clampf((lure - 0.4) / 0.6, 0.0, 1.0)
		var loud := db_to_linear(_hum.volume_db) if _hum.playing else 0.0
		loud = move_toward(loud, want * db_to_linear(volume_db), delta * 0.5)
		if loud > 0.001 and not _hum.playing:
			_hum.play()
		elif loud <= 0.001 and _hum.playing:
			_hum.stop()
		_hum.volume_db = linear_to_db(maxf(loud, 0.00001))
	if not _grabbed and _rig.stage() in [BeastRig.Stage.GRAB, BeastRig.Stage.HOLD] and _rig.act_time() >= BeastRig.WIND + BeastRig.GRAB * 0.7:
		_grabbed = true
		grabbing.emit()


## Draws its arms up and out (the warning, BeastRig.WIND), then flings them at
## `aim` and closes its hands (`grabbing`).
func reach() -> void:
	_rig.act(BeastRig.Act.REACH)
	_grabbed = false
	if _creak:
		_creak.play()


func cancel() -> void:
	_rig.act(BeastRig.Act.NONE)


func reaching() -> bool:
	return _rig._doing == BeastRig.Act.REACH


## Where its reaching hand is, in the world.
func hand() -> Vector3:
	return _rig.hand_point()


func eyes() -> Vector3:
	return _rig._head.global_transform * Vector3(0.0, 0.11, 0.08)


func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if lantern:
		lantern.put(at + Vector3.UP * 1.4, yaw)


static func part(called: String, low := false) -> Mesh:
	var key := called + ("lo" if low else "")
	if not _meshes.has(key):
		var scene := (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
		var found := scene.find_child(called, true, false) as MeshInstance3D
		_meshes[key] = found.mesh if found else null
		scene.free()
	return _meshes[key]


## Its hum, made once and shared, looping: a slow, low tune in a minor key, hummed
## with the mouth shut by a voice far too deep, a ghost of it an octave over it,
## each note sliding into the next, and an echo as if from down a long hall. Its
## own tune, nobody's song. About 9 s.
static func hum_sound() -> AudioStreamWAV:
	if _hum_wav:
		return _hum_wav
	var rate := 22050
	# (the tune: [semitones from D, beats]; a beat is 0.62 s)
	var tune := [[0, 2.0], [3, 1.0], [2, 1.0], [0, 1.5], [-5, 0.5], [-2, 2.0], [0, 1.0], [-4, 1.0], [-5, 4.0]]
	var beat := 0.62
	var total := 0.0
	for note: Array in tune:
		total += float(note[1]) * beat
	total += 0.6
	var count := int(rate * total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var dry := PackedFloat32Array()
	dry.resize(count)
	var throat: Array[Woodsman.Band] = [Woodsman.Band.new(280.0, 4.0, rate), Woodsman.Band.new(820.0, 5.0, rate), Woodsman.Band.new(2300.0, 6.0, rate)]
	var ghost := Woodsman.Band.new(600.0, 3.0, rate)
	var phase := 0.0
	var phase2 := 0.0
	var root := 73.4
	for i in count:
		var t := float(i) / rate
		# (which note, and how far into it: the pitch slides over the first fifth of each)
		var at := 0.0
		var semis := 0.0
		var before := float(tune[0][0])
		var loud := 0.0
		for k in tune.size():
			var length: float = float(tune[k][1]) * beat
			if t < at + length or k == tune.size() - 1:
				var into := clampf((t - at) / length, 0.0, 1.0)
				var from := before if k > 0 else float(tune[0][0])
				semis = lerpf(from, float(tune[k][0]), smoothstep(0.0, 0.2, into))
				# (a breath between some notes)
				loud = smoothstep(0.0, 0.08, into) if k in [0, 4, 7] else 1.0
				loud *= 1.0 - (smoothstep(0.85, 1.0, into) if k in [3, 6, 8] else 0.0)
				break
			at += length
			before = float(tune[k][0])
		loud *= smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(total - 0.9, total - 0.1, t))
		var vibrato := 1.0 + 0.012 * sin(TAU * 4.6 * t) * smoothstep(0.3, 1.0, t)
		var pitch := root * pow(2.0, semis / 12.0) * vibrato
		phase += pitch / rate
		phase2 += pitch * 2.0 / rate
		var glottal := pow(1.0 - fposmod(phase, 1.0), 4.0) * 2.0 - 0.4
		var v := throat[0].run(glottal) + throat[1].run(glottal) * 0.3 + throat[2].run(glottal) * 0.06
		var high := ghost.run(pow(1.0 - fposmod(phase2, 1.0), 6.0) - 0.15 + rng.randf_range(-0.3, 0.3)) * 0.25
		dry[i] = (v + high) * loud
	# (the echo, down a long hall: twice, fainter, the second wrapping round to the start, so it loops)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var loudest := 0.0
	for i in count:
		var value := dry[i] + dry[(i - int(0.31 * rate) + count) % count] * 0.4 + dry[(i - int(0.67 * rate) + count) % count] * 0.2
		value = tanh(value * 1.5)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_hum_wav = Woodsman.wav(samples, rate, loudest)
	_hum_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hum_wav.loop_begin = 0
	_hum_wav.loop_end = count
	return _hum_wav


## Its reach: the groan of wood bending, slow catches of it, and a long breath
## drawn in. 1.1 s.
static func reach_sound() -> AudioStreamWAV:
	if _reach_wav:
		return _reach_wav
	var rate := 22050
	var count := int(rate * 1.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	var samples := PackedFloat32Array()
	samples.resize(count)
	var groan := Woodsman.Band.new(240.0, 5.0, rate)
	var air := Woodsman.Band.new(1600.0, 0.8, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var pitch := 38.0 + 20.0 * smoothstep(0.0, 0.9, t) + 6.0 * sin(t * 9.0)
		phase += pitch / rate
		var catch := pow(1.0 - fposmod(phase, 1.0), 6.0) - 0.15
		var loud := smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.75, 1.0, t))
		var value := groan.run(catch * 3.0) * loud * 1.6
		value += air.run(rng.randf_range(-1.0, 1.0)) * smoothstep(0.1, 0.6, t) * (1.0 - smoothstep(0.85, 1.08, t)) * 0.4
		value = tanh(value * 1.6)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_reach_wav = Woodsman.wav(samples, rate, loudest)
	return _reach_wav
