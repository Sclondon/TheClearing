class_name OilLantern
extends Node3D
## An oil lantern (a hurricane lamp of dark tin) hung from a hand by its bail,
## swinging under it as the hand moves, its glass lit from within and one
## OmniLight warm round it that really lights the walls near. The woodsman's
## (warm, bright) and the beast's (pale, faint) are both this.
##
##     var lamp := OilLantern.new()
##     lamp.size = 1.65                       # the figure's scale: the model is in the boy's units
##     lamp.flame = Color(1.0, 0.7, 0.36)
##     add_child(lamp)                        # top level: it hangs where it is told
##     # each frame:
##     lamp.hold = hand_point                 # where the top of its bail is, in the world
##     lamp.yaw = facing_yaw                  # which way it faces round
##     lamp.glow = 1.0                        # 0 out .. 1 as bright as it goes (eased)
##
## Cheap: three draws (frame, glass, a soft halo round it), and one light without
## shadows, which `lights` (or Settings.low_poly) leaves out: then only the glass
## and the halo glow. The model is built by tools/build_woodsman.py
## (models/woodsman.glb, `lantern` and `lantern_glass`).

const MODEL := "res://creatures/woodsman/models/woodsman.glb"
const MODEL_LO := "res://creatures/woodsman/models/woodsman_lo.glb"
## From the top of the bail down to the middle of the glass, and to the foot, as modelled.
const GLASS_DOWN := 0.125
const LENGTH := 0.2

## The colour of its flame.
@export var flame := Color(1.0, 0.7, 0.36)
## How big it is drawn (the model is in the boy's units).
@export var size := 1.0
## How far its light reaches, metres, and how strong it is, at full glow.
@export var light_range := 9.0
@export var light_energy := 1.5
## Its light. Off (or Settings.low_poly): only the glass and the halo glow.
@export var lights := true
## The low-poly model (or Settings.low_poly).
@export var low_poly := false
## The render layers its light leaves out (its holder, drawn on a layer of its own:
## a lantern held before someone lights the walls, not their face full on).
@export_flags_3d_render var leaves_out := 0
## It creaks on its bail when it swings (a sound made in code).
@export var sound := true
@export var volume_db := -4.0

## Where the top of its bail is held, in the world (INF: where it is).
var hold := Vector3.INF
## Which way round it faces, radians about Y.
var yaw := 0.0
## How brightly it burns, 0..1 (eased towards).
var glow := 1.0
## How brightly it burns now.
var shown := 1.0

var _frame: MeshInstance3D
var _glass: MeshInstance3D
var _halo: MeshInstance3D
var _light: OmniLight3D
var _creak: AudioStreamPlayer3D
var _glass_material: ShaderMaterial
var _halo_material: ShaderMaterial
var _bob := Vector3.INF
var _bob_was := Vector3.INF
var _creak_in := 0.0
var _flicker := 0.0
static var _meshes := {}
static var _creak_wav: AudioStreamWAV

const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
uniform vec3 flame : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 1.0;
varying vec3 normal_view;
void vertex() {
	normal_view = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
}
void fragment() {
	// (hottest in the middle of the globe, where the wick is; the mist dims it only a little with distance)
	float facing = clamp(dot(normalize(normal_view), normalize(-VERTEX)), 0.0, 1.0);
	float far = exp(-length(VERTEX) * 0.012);
	vec3 hot = mix(flame, vec3(1.0, 0.97, 0.9), 0.55 * facing * facing);
	ALBEDO = mix(vec3(0.05, 0.045, 0.04), hot * (0.55 + 0.6 * facing), glow) * mix(0.55, 1.0, far);
}
"""

const HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 flame : source_color = vec3(1.0, 0.7, 0.36);
uniform float glow = 1.0;
void vertex() {
	// (a billboard, facing the camera)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float soft = pow(clamp(1.0 - d, 0.0, 1.0), 2.4);
	// (it carries through the mist: the light itself is not dimmed by it, the halo a little)
	float far = clamp(exp(-length(VERTEX) * 0.02), 0.35, 1.0);
	ALBEDO = flame * soft * 0.55 * glow * far;
}
"""


func _ready() -> void:
	top_level = true
	var low := low_poly or Settings.low_poly
	_frame = MeshInstance3D.new()
	_frame.mesh = part("lantern", low)
	_frame.material_override = Woodsman.carved()
	add_child(_frame)
	_glass = MeshInstance3D.new()
	_glass.mesh = part("lantern_glass", low)
	_glass_material = ShaderMaterial.new()
	_glass_material.shader = _shader(GLASS_SHADER)
	_glass.material_override = _glass_material
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)
	_halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.5
	_halo.mesh = quad
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = _shader(HALO_SHADER)
	_halo.material_override = _halo_material
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	if lights and not Settings.low_poly:
		_light = OmniLight3D.new()
		_light.light_color = flame
		_light.omni_range = light_range
		_light.omni_attenuation = 1.4
		_light.shadow_enabled = false
		# (it lights the halls, not the lantern's own glass)
		_light.light_specular = 0.2
		_light.light_cull_mask = 0xFFFFF & ~leaves_out
		add_child(_light)
	if sound:
		_creak = AudioStreamPlayer3D.new()
		_creak.stream = creak_sound()
		_creak.volume_db = volume_db
		_creak.unit_size = 3.0
		_creak.max_distance = 22.0
		add_child(_creak)
	_dress()


func _dress() -> void:
	for node: Node3D in [_frame, _glass]:
		node.scale = Vector3.ONE * size
	_halo.scale = Vector3.ONE * size * 2.2
	_halo.position = Vector3(0.0, -GLASS_DOWN * size, 0.0)
	_glass_material.set_shader_parameter(&"flame", flame)
	_halo_material.set_shader_parameter(&"flame", flame)
	if _light:
		_light.light_color = flame
		_light.position = Vector3(0.0, -GLASS_DOWN * size, 0.0)


## Puts it straight at `at` (hanging still), facing `facing`.
func put(at: Vector3, facing: float) -> void:
	hold = at
	yaw = facing
	_bob = Vector3.INF


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 20.0)
	if not hold.is_finite():
		hold = global_position
	var length := LENGTH * size * 0.6
	# A pendulum: the lantern's middle swings under the hand, slowed by the air.
	if not _bob.is_finite():
		_bob = hold + Vector3.DOWN * length
		_bob_was = _bob
	var moved := (_bob - _bob_was) * (1.0 - 2.2 * delta)
	_bob_was = _bob
	_bob += moved + Vector3.DOWN * 9.8 * delta * delta
	_bob = hold + (_bob - hold).normalized() * length
	var down := (_bob - hold).normalized()
	# (a lantern on a stiff bail cannot swing up past level)
	if down.y > -0.25:
		down = Vector3(down.x, -0.25, down.z).normalized()
		_bob = hold + down * length
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var up := -down
	var right := up.cross(forward).normalized()
	var basis_now := Basis(right, up, right.cross(up).normalized()).orthonormalized()
	global_transform = Transform3D(basis_now, hold)
	# Its flame: eased to how bright it is told, and flickering a little.
	shown = move_toward(shown, glow, delta * 1.5)
	_flicker += delta
	var flicker := 1.0 + 0.06 * sin(_flicker * 17.0) * sin(_flicker * 5.3 + 1.0) + 0.03 * sin(_flicker * 41.0)
	_glass_material.set_shader_parameter(&"glow", shown * flicker)
	_halo_material.set_shader_parameter(&"glow", shown * flicker)
	_halo.visible = shown > 0.02
	if _light:
		_light.visible = shown > 0.02
		_light.light_energy = light_energy * shown * flicker
		_light.omni_range = light_range * (0.4 + 0.6 * shown)
	# It creaks when it swings hard.
	_creak_in -= delta
	var swing := moved.length() / maxf(delta, 0.001)
	if _creak and _creak_in <= 0.0 and swing > 0.35 * size:
		_creak_in = randf_range(1.6, 3.5)
		_creak.pitch_scale = randf_range(0.85, 1.15)
		_creak.play()


## The middle of its glass, in the world (where its light is).
func light_point() -> Vector3:
	return global_transform * Vector3(0.0, -GLASS_DOWN * size, 0.0)


static func _shader(code: String) -> Shader:
	var made := Shader.new()
	made.code = code
	return made


## A part of the lantern's model (shared).
static func part(called: String, low := false) -> Mesh:
	var key := called + ("lo" if low else "")
	if not _meshes.has(key):
		var scene := (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
		var found := scene.find_child(called, true, false) as MeshInstance3D
		_meshes[key] = found.mesh if found else null
		scene.free()
	return _meshes[key]


## Its creak, made once and shared: the tin bail rubbing in its ears as it swings,
## a thin rising squeak and a fall, twice, with a tick of metal. 0.55 s.
static func creak_sound() -> AudioStreamWAV:
	if _creak_wav:
		return _creak_wav
	var rate := 22050
	var count := int(rate * 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var samples := PackedFloat32Array()
	samples.resize(count)
	var loudest := 0.0
	var phase := 0.0
	var ring := Woodsman.Band.new(2400.0, 9.0, rate)
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		for k in 2:
			var start := 0.04 + 0.24 * k
			var d := t - start
			if d >= 0.0 and d < 0.2:
				var loud := smoothstep(0.0, 0.03, d) * (1.0 - smoothstep(0.12, 0.2, d)) * (1.0 - 0.35 * k)
				# (stick and slip: the squeak is a buzz of tiny catches)
				var pitch := 820.0 + 460.0 * sin(d / 0.2 * PI) - 120.0 * k
				phase += pitch / rate
				var catch := pow(1.0 - fposmod(phase, 1.0), 3.0) - 0.25
				value += catch * loud * (0.8 + rng.randf_range(-0.2, 0.2))
		# (the tick of the tin)
		if t < 0.03:
			value += ring.run(rng.randf_range(-1.0, 1.0) * exp(-t * 160.0)) * 3.0
		else:
			value += ring.run(0.0) * 3.0
		value = tanh(value * 1.4)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_creak_wav = Woodsman.wav(samples, rate, loudest)
	return _creak_wav
