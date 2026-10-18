class_name Brachiosaurus
extends Node3D
## A brachiosaurus (Brachiosaurus altithorax), as it is drawn now and at its
## real size: about 21 m from snout to tail, the shoulders 6.6 m up, the back
## sloping down to the hips (its forelimbs are longer than its hind), the long
## neck held high and the small head 13 m up, with the arch of its nasal crest
## over the snout. Columnar legs like an elephant's, one claw on each thumb,
## three on each hind foot; a short tail held off the ground. Its look, its
## moves and its sounds are here; what it does is for the game to say. It
## knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks
## to match, slow and heavy, each foot lifted high and set down flat where it
## lands; turning on the spot, it steps round. On uneven ground give it
## `ground_at` (the height of the ground under a point) and set its height to
## the ground under its middle: its feet find the ground each.
##
## Then say what it is doing:
## - `browse_point`: leaves it is eating (INF for none): its neck stretches to
##   them, its head reaches in and its jaw works.
## - `look_at_point`: what it watches (INF for nothing): its head turns to it,
##   and the neck curves down to see something low.
## - `bellow()` (a long, deep, hollow honk that carries a long way),
##   `rumble()` (a growl too low to hear well, felt), `snort()`.
##
## THE FEET. Each foot comes down on whatever is under it. `landing(i)` says
## where a lifted foot will come down and how near to coming down it is, and
## with `foot_shadows` on it draws a dark spot on the ground there that
## darkens as the foot comes down: a warning. `footfall(at, weight)` as each
## lands (its sound, its dust).
##
## It is drawn by BrachiosaurusRig (brachiosaurus_rig.gd) on the model made by
## tools/build_brachiosaurus.py, with BrachiosaurusLook's materials
## (brachiosaurus_look.gd): two draws, and the low-poly model from `lod_range`
## out (or always, with `low_poly`); `pose_every` poses it only every few frames.

signal bellowed
signal rumbled
## A foot has come down: where (its sole, on the ground), and how hard.
signal footfall(at: Vector3, weight: float)

## Only the low-poly model. Set before it enters the tree.
@export var low_poly := false
## From this far from the camera it is drawn with the low model (0: never). Set before it enters the tree.
@export var lod_range := 70.0
## Multiplies the colours of its hide.
@export var skin_tint := Color.WHITE
## Scales to a metre of its hide.
@export var scales := 14.0
@export_range(0.0, 2.0) var eyeshine := 0.2
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## Draws a warning on the ground where each lifted foot will come down.
@export var foot_shadows := false
@export_group("Sound and dust")
@export var sound := true
@export var volume_db := 4.0
## How far off it can be heard (m).
@export var sound_range := 160.0
@export var dust := true

## How fast it is going, in the world.
var velocity := Vector3.ZERO
var browse_point := Vector3.INF
var look_at_point := Vector3.INF
## The height of the ground under (x, z) in the world. Unset: flat, where it stands.
var ground_at := Callable():
	set(value):
		ground_at = value
		if rig:
			rig.ground_at = value
## Posed only every this many frames (1: every frame): for far off.
var pose_every := 1:
	set(value):
		pose_every = maxi(value, 1)
		if rig:
			rig.pose_every = pose_every
var rig: BrachiosaurusRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D
var _mouth: AudioStreamPlayer3D
var _dust: CPUParticles3D
var _shadows: MultiMeshInstance3D
var _nibble_in := 2.0

static var _bellow: AudioStreamWAV
static var _rumble: AudioStreamWAV
static var _snort: AudioStreamWAV
static var _thud: AudioStreamWAV
static var _crunch: AudioStreamWAV


func _ready() -> void:
	rig = BrachiosaurusRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.lod_range = lod_range
	rig.skin_tint = skin_tint
	rig.scales = scales
	rig.eyeshine = eyeshine
	rig.ground_at = ground_at
	rig.pose_every = pose_every
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	if sound:
		_voice = _player(Vector3(0.0, 12.0, 7.5), 1)
		_feet = _player(Vector3(0.0, 0.5, 0.0), 4)
		_feet.stream = thud_sound()
		_mouth = _player(Vector3(0.0, 12.5, 8.0), 1)
		_mouth.unit_size = 4.0
		_mouth.max_distance = 30.0
	if dust:
		_dust = _particles(self, 22, Color(0.42, 0.40, 0.36, 0.5), 1.4, 2.2)
		_dust.top_level = true
		_dust.direction = Vector3.UP
		_dust.spread = 80.0
		_dust.gravity = Vector3(0.0, -1.0, 0.0)
	if foot_shadows:
		_shadows = _shadow_spots()
		add_child(_shadows)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 40.0:
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-8.0 * delta))
		_was_at = at
	if _shadows:
		_lay_shadows()
	if browse_point.is_finite() and _mouth:
		_nibble_in -= delta
		if _nibble_in <= 0.0:
			_nibble_in = randf_range(1.0, 2.2)
			_mouth.stream = crunch_sound()
			_mouth.volume_db = volume_db - 8.0
			_mouth.pitch_scale = randf_range(0.85, 1.15)
			_mouth.play()


## Stands it still where it is: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func bellow() -> void:
	if rig:
		rig.bellow()
	_say(bellow_sound(), 4.0, randf_range(0.94, 1.04))
	bellowed.emit()


func rumble() -> void:
	if rig:
		rig.rumble()
	_say(rumble_sound(), 2.0, randf_range(0.95, 1.05))
	rumbled.emit()


func snort() -> void:
	_say(snort_sound(), -2.0, randf_range(0.9, 1.1))


## Where foot `i` (fore left, fore right, hind left, hind right) will come down
## (x, y, z: its joint over the sole, in the world) and how far through its
## lift it is (w: 0 just lifted, 1 down; -1 it is down).
func landing(i: int) -> Vector4:
	return rig.landing(i) if rig else Vector4(global_position.x, global_position.y, global_position.z, -1.0)


## How wide each foot's sole is (radius, m): fore, hind.
func sole() -> Vector2:
	return rig.sole() if rig else Vector2(0.43, 0.56)


## Where the tip of its snout is, in the world.
func snout_tip() -> Vector3:
	return rig.snout_tip() if rig else global_position


func _on_footfall(at: Vector3, weight: float) -> void:
	var size := global_basis.get_scale().y
	var sole_at := at - Vector3.UP * 0.33 * size
	if _feet and weight > 0.2:
		_feet.global_position = sole_at
		_feet.volume_db = volume_db - 6.0 + 8.0 * minf(weight, 1.0)
		_feet.pitch_scale = randf_range(0.8, 1.0) / maxf(sqrt(size), 0.5)
		_feet.play()
	if _dust and weight > 0.35:
		_dust.global_position = sole_at
		_dust.initial_velocity_min = 0.5 * size
		_dust.initial_velocity_max = 1.4 * size
		_dust.scale_amount_min = 0.8 * size
		_dust.scale_amount_max = 1.6 * size
		_dust.restart()
	footfall.emit(sole_at, weight)


# --- The warning under its feet ---

const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shade : source_color = vec3(0.04, 0.04, 0.045);

void fragment() {
	// (a soft round spot, a darker ring at its rim: where the foot will come down)
	float r = length(UV - vec2(0.5)) * 2.0;
	float spot = 1.0 - smoothstep(0.55, 1.0, r);
	float rim = smoothstep(0.62, 0.78, r) * (1.0 - smoothstep(0.82, 0.96, r));
	ALBEDO = shade;
	ALPHA = clamp(spot * 0.75 + rim * 0.6, 0.0, 1.0) * COLOR.a;
}
"""


## Four soft spots (one draw), laid on the ground under the lifted feet.
func _shadow_spots() -> MultiMeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADOW_SHADER
	material.shader = shader
	plane.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = plane
	multi.instance_count = 4
	var spots := MultiMeshInstance3D.new()
	spots.name = "FootShadows"
	spots.multimesh = multi
	spots.top_level = true
	spots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spots.custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 30.0, 80.0))
	return spots


func _lay_shadows() -> void:
	_shadows.global_transform = Transform3D(Basis.IDENTITY, global_position)
	var multi := _shadows.multimesh
	var soles := sole()
	var size := global_basis.get_scale().y
	for i in 4:
		var land := landing(i)
		var radius := soles.x if i < 2 else soles.y
		var at := Vector3(land.x, land.y, land.z) - global_position
		at.y += -0.33 * size + 0.06
		var strength := 0.0 if land.w < 0.0 else smoothstep(0.0, 0.25, land.w) * lerpf(0.55, 1.0, land.w)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius * lerpf(1.7, 1.25, maxf(land.w, 0.0))), at))
		multi.set_instance_color(i, Color(1.0, 1.0, 1.0, strength))


## A burst of soft, fading puffs (dust) from `parent`.
func _particles(parent: Node3D, amount: int, colour: Color, size: float, life: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = amount
	emitter.lifetime = life
	emitter.explosiveness = 0.9
	emitter.local_coords = false
	emitter.damping_min = 1.2
	emitter.damping_max = 2.2
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	emitter.emission_ring_axis = Vector3.UP
	emitter.emission_ring_radius = 0.6
	emitter.emission_ring_inner_radius = 0.3
	emitter.emission_ring_height = 0.1
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	emitter.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, colour)
	ramp.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	emitter.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	emitter.scale_amount_curve = grow
	parent.add_child(emitter)
	return emitter


static var _dot: ImageTexture


static func _soft_dot() -> ImageTexture:
	if _dot:
		return _dot
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r := Vector2(x - 15.5, y - 15.5).length() / 15.5
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - r, 0.0, 1.0) ** 1.6))
	_dot = ImageTexture.create_from_image(image)
	return _dot


# --- Sounds ---

func _player(at: Vector3, polyphony: int) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.position = at
	player.unit_size = 22.0
	player.max_distance = sound_range
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


func _say(stream: AudioStreamWAV, gain: float, pitch: float) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db + gain
	_voice.pitch_scale = pitch
	_voice.play()


## A bellow: a long, deep, hollow honk through the crest of its nose, rising
## and falling, with a low growl under it; it carries a long way.
static func bellow_sound() -> AudioStreamWAV:
	if _bellow:
		return _bellow
	var rate := 22050
	var length := 2.8
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	var formants: Array[Band] = [Band.new(180.0, 7.0, rate), Band.new(420.0, 8.0, rate), Band.new(760.0, 7.0, rate), Band.new(1500.0, 5.0, rate)]
	var gains := [1.0, 0.75, 0.3, 0.08]
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(length * 0.6, length, t))
		var pitch := 46.0 + 16.0 * smoothstep(0.1, 0.8, t) - 22.0 * smoothstep(1.4, length, t)
		pitch *= 1.0 + 0.01 * sin(t * TAU * 4.0) + rng.randf_range(-0.008, 0.008)
		phase += pitch / rate
		low += pitch * 0.5 / rate
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 3.0) * 2.0 - 0.5
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var growl := (pow(1.0 - fposmod(low, 1.0), 4.0) - 0.2) * 0.6
		samples[i] = tanh((throat * 2.2 + growl) * level * 2.0)
	_bellow = _wave(samples, rate)
	return _bellow


## A rumble: a growl so low it is felt as much as heard, rough and slow.
static func rumble_sound() -> AudioStreamWAV:
	if _rumble:
		return _rumble
	var rate := 22050
	var length := 3.0
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 223
	var chest := Band.new(110.0, 2.5, rate)
	var throat := Band.new(260.0, 3.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(length * 0.55, length, t))
		phase += (28.0 + 4.0 * sin(t * 1.7)) / rate
		var p := fposmod(phase, 1.0)
		var flutter := 0.6 + 0.4 * sin(t * TAU * 6.0 + sin(t * 2.0) * 2.0)
		var pulse := (pow(1.0 - p, 6.0) * 2.0 - 0.3) * flutter
		samples[i] = tanh((chest.run(pulse) * 3.0 + throat.run(pulse) * 1.2 + pulse * 0.6 + throat.run(rng.randf_range(-1.0, 1.0)) * 0.1) * level * 2.2)
	_rumble = _wave(samples, rate)
	return _rumble


## A snort: air blown out through its nostrils.
static func snort_sound() -> AudioStreamWAV:
	if _snort:
		return _snort
	var rate := 22050
	var length := 0.8
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 227
	var nose := Band.new(320.0, 1.2, rate)
	var chest := Band.new(70.0, 2.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var level := minf(t / 0.03, 1.0) * pow(1.0 - t / length, 2.0)
		var air := rng.randf_range(-1.0, 1.0)
		samples[i] = tanh((nose.run(air) * 1.4 + chest.run(air) * 3.0) * level * 2.0)
	_snort = _wave(samples, rate)
	return _snort


## A foot coming down: a deep, heavy boom, and the ground giving under it.
static func thud_sound() -> AudioStreamWAV:
	if _thud:
		return _thud
	var rate := 22050
	var count := int(rate * 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 229
	var grit := Band.new(500.0, 0.8, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		phase += lerpf(55.0, 18.0, minf(t / 0.3, 1.0)) / rate
		var body := sin(TAU * phase) * exp(-t * 6.0)
		var dirt := grit.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 20.0) * 0.6
		samples[i] = tanh((body * 2.0 + dirt) * 1.6)
	_thud = _wave(samples, rate)
	return _thud


## Leaves stripped from a branch: a quick tearing rustle and a crunch.
static func crunch_sound() -> AudioStreamWAV:
	if _crunch:
		return _crunch
	var rate := 22050
	var length := 0.5
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 233
	var leaves := Band.new(2400.0, 0.9, rate)
	var snap := Band.new(900.0, 1.5, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var u := t / length
		var tear := sin(PI * minf(u * 1.4, 1.0)) * (0.6 + 0.4 * sin(t * TAU * 37.0))
		var crack := exp(-absf(t - 0.32) * 60.0)
		samples[i] = tanh((leaves.run(rng.randf_range(-1.0, 1.0)) * tear * 1.6 + snap.run(rng.randf_range(-1.0, 1.0)) * crack * 2.5) * 1.4)
	_crunch = _wave(samples, rate)
	return _crunch


static func _wave(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


## A resonant band-pass filter (a biquad), for the sounds.
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
