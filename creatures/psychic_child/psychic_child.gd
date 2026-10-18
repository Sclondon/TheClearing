class_name PsychicChild
extends Node3D
## A small, thin child in a washed-out hospital smock, barefoot, her head
## shaved, a blank mask for a face, who drifts a hand's breadth off the ground
## humming to herself, while a few small things (pebbles, dead leaves, motes
## of dust) go slowly round and round her in the air. Frightened, she curls up
## in the air with her hands to her head, the air round her warping, the things
## round her racing and rising, a high ringing in it, her nose bleeding; and
## then it all goes out of her at once, a burst that flings everything near
## away. After it she sits on the ground, hugging her knees, still. She can
## also take hold of a thing with her mind on purpose: her arm held out at it,
## shaking, the air warped round it, her nose bleeding.
##
## This is only how she looks, moves and sounds. She does no thinking: a game
## drives her. Put her where the creature is each frame and say how fast she is
## going, what she looks at and how frightened she is; call `burst()`.
##
##     var child := PsychicChild.new()
##     add_child(child)                       # modelled a little under a metre tall
##     child.put(spawn_point, spawn_yaw)
##     # each frame:
##     child.global_position = body_position  # where her feet would be on the ground
##     child.rotation.y = facing_yaw          # 0 faces +Z
##     child.velocity = body_velocity         # world units a second
##     child.aim = player_head                # what she looks at (INF: nothing)
##     child.distress = 0.4                   # 0 calm .. 1 about to burst: all the warning shows by this
##     child.drained = true                   # sitting on the ground, hugging her knees
##     child.humming = true                   # her tune (it breaks off as she is frightened)
##     child.reach_at = hostile_middle        # holding something with her mind: her arm out at it, the air warped round it
##     child.reaching = true
##     child.thud(point)                      # a puff of dust and grit where something is slammed down
##     child.burst()                          # everything flung out from her; `bursting` fires at its height
##     child.far = true                       # not posed or heard (the things round her still drawn)
##
## She is posed by PsychicChildRig (psychic_child_rig.gd), which extends
## CharacterRig: she needs GameCommon's character-controller (CharacterRig,
## Toon, Dust, Settings). The model is creatures/psychic_child/models/
## psychic_child.glb (and _lo), made by creatures/psychic_child/tools/
## build_psychic_child.py in Blender.

## The burst goes out: whatever is to be flung is flung now (BURST_PEAK seconds after `burst()`).
signal bursting

const MODEL := "res://creatures/psychic_child/models/psychic_child.glb"
const MODEL_LO := "res://creatures/psychic_child/models/psychic_child_lo.glb"
## How long after `burst()` it goes out, seconds.
const BURST_PEAK := 0.06
## The small things that go round her: pebbles (and specks of dust, smaller), and dead leaves.
const PEBBLES := 9
const SPECKS := 6
const LEAVES := 6
## How far the warp round her reaches (metres across), and the burst's wave at its widest.
const HAZE_SIZE := 2.6
const WAVE_SIZE := 22.0
## How long the burst's wave takes to go out, seconds.
const WAVE_TIME := 0.45
## How far the warp round what she holds reaches (metres across).
const GRIP_SIZE := 3.2

## Use the low-poly model.
@export var low_poly := false
## Her sounds, made in code, from where she is: the humming, the ringing, the burst.
@export var sound := true
## How loud her humming is, and how far off it is heard (world units).
@export var volume_db := -12.0
@export var sound_range := 26.0
## Poses a second (0: every frame): fewer, to cost less, when she is far enough off for it not to show.
@export var pose_rate := 0.0

## How fast she is going, world units a second.
var velocity := Vector3.ZERO
## What she looks at, in the world (INF: nothing).
var aim := Vector3.INF
## How frightened she is, 0..1: the warning (warp, the things round her racing and
## rising, the ringing, her hands to her head, the nosebleed) all comes from this.
var distress := 0.0
## Spent, after a burst: sitting on the ground, still.
var drained := false
## Whether she hums (while she is calm enough to).
var humming := true
## Holding something with her mind (her arm out at it, the air warping round it, a
## nosebleed coming on), and where it is (INF: nothing).
var reaching := false
var reach_at := Vector3.INF
## Too far off to be seen: not posed, not heard.
var far := false:
	set(value):
		if value == far:
			return
		far = value
		if _rig:
			_rig.visible = not far
			_rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		if _haze:
			_haze.visible = false

## For the rig, which reads her body as it would a Player's.
var is_pushing := false
var walk_speed := 0.6
var run_speed := 1.8

var _rig: PsychicChildRig
var _blood: ShaderMaterial
var _blood_part: MeshInstance3D
var _bleed := 0.0
var _time := 0.0
var _shown_distress := 0.0
var _burst_time := INF
var _wave_time := INF
var _peaked := true
var _ground_y := 0.0
# The things round her: each piece's orbit (radius, height, phase, speed), where it
# is now (world), and how fast it is going when flung; whether it lies on the ground.
var _pieces := 0
var _orbit: Array[Vector4] = []
var _at: Array[Vector3] = []
var _speed: Array[Vector3] = []
var _spin: Array[Vector3] = []
var _turn: Array[Basis] = []
var _size: Array[float] = []
var _lying: Array[bool] = []
var _flung := false
var _gather := 1.0
var _stones: MultiMeshInstance3D
var _leaves: MultiMeshInstance3D
var _haze: MeshInstance3D
var _haze_material: ShaderMaterial
var _wave: MeshInstance3D
var _wave_material: ShaderMaterial
var _grip: MeshInstance3D
var _grip_material: ShaderMaterial
var _grip_level := 0.0
var _thud_time := INF
var _dust: Dust
var _hum: AudioStreamPlayer3D
var _ring: AudioStreamPlayer3D
var _boom: AudioStreamPlayer3D
var _hum_level := 0.0
var _toned := false
static var _hum_sound: AudioStreamWAV
static var _ring_sound: AudioStreamWAV
static var _burst_sound: AudioStreamWAV
static var _warp_shader: Shader


func _ready() -> void:
	_rig = PsychicChildRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.2
	add_child(_rig)
	_blood = _rig.own_blood()
	_blood_part = _rig.blood_part()
	_make_pieces()
	_make_warp()
	if sound:
		_hum = _voice(volume_db, sound_range, 1.0)
		_ring = _voice(volume_db - 2.0, sound_range * 1.3, 1.0)
		_boom = _voice(volume_db + 16.0, 70.0, 0.8)


func _voice(loudness: float, reach: float, height: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.volume_db = loudness
	player.unit_size = 4.0
	player.max_distance = reach
	player.position = Vector3(0.0, height, 0.05)
	add_child(player)
	return player


func is_on_floor() -> bool:
	return true


## Puts her straight somewhere, hanging still as she is, the things round her in their places.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	_ground_y = at.y
	_flung = false
	_gather = 1.0
	for i in _pieces:
		_lying[i] = false
		_at[i] = _orbit_point(i)
		_speed[i] = Vector3.ZERO
	if _rig:
		_rig.distress = distress
		_rig.drained = 1.0 if drained else 0.0
		_rig.settle()


## Everything near her is flung out from her: she is thrown open in the air
## (PsychicChildRig.BURST), a wave goes out through the air and the dust, the
## things round her shoot away, and there is a crack and a boom. `bursting` is
## emitted as it goes out.
func burst() -> void:
	_burst_time = 0.0
	_peaked = false
	if _rig:
		_rig.act(PsychicChildRig.Act.BURST)
	if _boom:
		if _boom.stream == null:
			_boom.stream = burst_sound()
		_boom.play()


## Whether she is in the middle of a burst.
func busy() -> bool:
	return _burst_time < PsychicChildRig.BURST


## Where her head is (for a line-of-sight test, or to look at her).
func head() -> Vector3:
	return to_global(Vector3(0.0, 0.88, 0.0)) + Vector3.UP * (0.12 * _shown_distress if not drained else -0.4)


func _process(delta: float) -> void:
	_time += delta
	_shown_distress = move_toward(_shown_distress, distress, delta * 3.0)
	_ground_y = global_position.y
	if _burst_time < INF:
		_burst_time += delta
		if not _peaked and _burst_time >= BURST_PEAK:
			_peaked = true
			_go_out()
		if _burst_time > 6.0:
			_burst_time = INF
	if _rig and not far:
		_rig.aim = aim
		_rig.distress = _shown_distress
		_rig.drained = 1.0 if drained else 0.0
		_rig.humming = humming and _shown_distress < 0.2
		_rig.pose_rate = pose_rate
		_rig.reach = 1.0 if reaching else 0.0
		_rig.reach_at = reach_at
	_bleed_now(delta)
	_move_pieces(delta)
	_warp(delta)
	_sounds(delta)


## The burst goes out: the wave, the dust, the things round her flung.
func _go_out() -> void:
	_wave_time = 0.0
	_flung = true
	_gather = 0.0
	var middle := global_position + Vector3.UP * 0.6
	for i in _pieces:
		var out := _at[i] - middle
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(cos(i * 2.4), 0.0, sin(i * 2.4))
		_speed[i] = out * randf_range(9.0, 16.0) + Vector3.UP * randf_range(1.5, 5.0)
		_spin[i] = Vector3(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		_lying[i] = false
	if _dust == null:
		_dust = Dust.new()
		add_child(_dust)
	_dust.process_mode = Node.PROCESS_MODE_INHERIT
	for k in 14:
		var round_about := TAU * k / 14.0
		var way := Vector3(cos(round_about), 0.0, sin(round_about))
		_dust.puff(Vector3(global_position.x, _ground_y, global_position.z) + way * 0.8, way * 9.0, 0.9, 1)
	bursting.emit()


# --- The nosebleed ---

## It starts as she is badly frightened, runs down while she is, and dries (is
## gone) a while after she is calm again.
func _bleed_now(delta: float) -> void:
	if _blood == null or _blood_part == null:
		return
	var running := _shown_distress > 0.45 or busy() or (reaching and _grip_level > 0.6)
	if running:
		_bleed = minf(_bleed + delta * (0.35 + _shown_distress), 1.0)
	elif not drained:
		_bleed = maxf(_bleed - delta * 0.05, 0.0)
	_blood_part.visible = _bleed > 0.01 and not far
	_blood.set_shader_parameter(&"bleed", _bleed)


# --- The things round her ---

func _make_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	_pieces = PEBBLES + SPECKS + LEAVES
	for i in _pieces:
		var leaf := i >= PEBBLES + SPECKS
		var speck := i >= PEBBLES and not leaf
		_orbit.append(Vector4(rng.randf_range(0.34, 0.8), rng.randf_range(0.15, 1.15), rng.randf() * TAU, rng.randf_range(0.28, 0.55) * (1.0 if rng.randf() < 0.85 else -1.0)))
		_at.append(Vector3.ZERO)
		_speed.append(Vector3.ZERO)
		_spin.append(Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)))
		_turn.append(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)))
		_size.append(rng.randf_range(0.022, 0.05) if not speck and not leaf else (rng.randf_range(0.006, 0.01) if speck else rng.randf_range(0.8, 1.2)))
		_lying.append(false)
	# Pebbles (and specks): a rough low stone, each of its own size and grey.
	var stone := SphereMesh.new()
	stone.radius = 0.5
	stone.height = 0.75
	stone.radial_segments = 6
	stone.rings = 3
	var stone_look := StandardMaterial3D.new()
	stone_look.vertex_color_use_as_albedo = true
	stone_look.roughness = 1.0
	stone.material = stone_look
	_stones = _pieces_of(stone, PEBBLES + SPECKS)
	for i in PEBBLES + SPECKS:
		var grey := rng.randf_range(0.32, 0.5)
		_stones.multimesh.set_instance_color(i, Color(grey, grey * 0.97, grey * 0.93))
	# Dead leaves: thin, curled, dull brown.
	# (a flat, curled oval: a low sphere squashed thin, drawn longer than it is wide)
	var leaf_shape := SphereMesh.new()
	leaf_shape.radius = 0.024
	leaf_shape.height = 0.007
	leaf_shape.radial_segments = 6
	leaf_shape.rings = 2
	var leaf_look := StandardMaterial3D.new()
	leaf_look.vertex_color_use_as_albedo = true
	leaf_look.roughness = 1.0
	leaf_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	# (lit the same from either side: a dead leaf is thin)
	leaf_look.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	leaf_look.backlight_enabled = true
	leaf_look.backlight = Color(0.5, 0.45, 0.35)
	leaf_shape.material = leaf_look
	_leaves = _pieces_of(leaf_shape, LEAVES)
	for i in LEAVES:
		var brown := rng.randf_range(0.26, 0.4)
		_leaves.multimesh.set_instance_color(i, Color(brown, brown * 0.86, brown * 0.68))
	for i in _pieces:
		_at[i] = _orbit_point(i)


func _pieces_of(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = MultiMesh.new()
	holder.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	holder.multimesh.use_colors = true
	holder.multimesh.mesh = mesh
	holder.multimesh.instance_count = count
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (they are placed in the world, wherever they have been flung)
	holder.top_level = true
	holder.custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0) * 16384.0, Vector3.ONE * 32768.0)
	add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	return holder


## Where a piece is on its way round her now: slowly round, bobbing; frightened,
## faster and higher, and closer in; drained, nowhere (it lies where it fell).
func _orbit_point(i: int) -> Vector3:
	var orbit := _orbit[i]
	var d := _shown_distress
	var angle := orbit.z
	var radius := orbit.x * (1.0 - 0.25 * d)
	var height := orbit.y + 0.06 * sin(_time * 0.9 + orbit.z * 3.0) + d * (0.35 + 0.3 * orbit.y)
	return global_position + Vector3(cos(angle) * radius, height, sin(angle) * radius)


func _move_pieces(delta: float) -> void:
	if far and not _flung:
		return
	var d := _shown_distress
	# (calm again, the things on the ground rise and come back round her, slowly)
	if _flung and not drained and not busy():
		_gather = minf(_gather + delta / 3.5, 1.0)
		if _gather >= 1.0:
			_flung = false
	for i in _pieces:
		var orbit := _orbit[i]
		orbit.z = fposmod(orbit.z + orbit.w * delta * (1.0 + 5.0 * d * d + 1.5 * d), TAU)
		_orbit[i] = orbit
		if _flung:
			if not _lying[i]:
				_speed[i] += Vector3.DOWN * 18.0 * delta
				_at[i] += _speed[i] * delta
				_turn[i] = _turn[i].rotated(_spin[i].normalized(), _spin[i].length() * delta).orthonormalized()
				if _at[i].y <= _ground_y + 0.01:
					_at[i].y = _ground_y + 0.01
					_speed[i] = Vector3.ZERO
					_lying[i] = true
			elif _gather > 0.0:
				_at[i] = _at[i].lerp(_orbit_point(i), smoothstep(0.0, 1.0, _gather) * minf(delta * 3.0, 1.0) + _gather * _gather * 0.05)
		else:
			# (jittering as she trembles)
			var jitter := Vector3(sin(_time * 33.0 + i), sin(_time * 29.0 + i * 2.0), cos(_time * 31.0 + i)) * 0.012 * d * d
			_at[i] = _orbit_point(i) + jitter
			_turn[i] = _turn[i].rotated(_spin[i].normalized(), _spin[i].length() * delta * (1.0 + 3.0 * d)).orthonormalized()
		var size := _size[i]
		if i < PEBBLES + SPECKS:
			_stones.multimesh.set_instance_transform(i, Transform3D(_turn[i].scaled(Vector3(size, size * 0.7, size * 0.85)), _at[i]))
		else:
			var leaf := _turn[i]
			if _lying[i]:
				leaf = Basis(Vector3.UP, orbit.z)
			_leaves.multimesh.set_instance_transform(i - PEBBLES - SPECKS, Transform3D(leaf * Basis.from_scale(Vector3(size, size, size * 1.6)), _at[i] + (Vector3.UP * 0.004 if _lying[i] else Vector3.ZERO)))


# --- The warp of the air ---

## The air round her bends what is seen through it (the screen behind, drawn
## again through ripples): a haze round her that grows with her distress, and
## the burst's wave, a ring of it going out from her.
const WARP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// How much it bends: the haze through the middle, and the ring (its radius, 0..1, and how wide).
uniform float haze = 0.0;
uniform float ring = -1.0;
uniform float ring_strength = 0.0;
uniform float ring_width = 0.12;
uniform float time = 0.0;
// A shade cast over what is seen through it, at its strongest.
uniform float dim = 0.0;
// Drawn with the scene tonemapped as it is drawn (no glow or adjustments), what is
// on the screen has been tonemapped already, and what this draws will be again: so
// the filmic tonemap is first undone (`filmic` 1; 0 for a linear one; 2 where the
// scene is tonemapped after, in a pass of its own: nothing to undo), or the warp
// would show as a paler disc.
uniform float filmic = 1.0;
uniform float white = 1.0;
uniform float exposure = 1.0;
uniform float bend_scale = 1.0;

float film(float x) {
	const float FA = 0.88;
	const float FB = 0.6;
	const float FC = 0.1;
	const float FD = 0.2;
	const float FE = 0.01;
	const float FF = 0.3;
	return (x * (FA * x + FC * FB) + FD * FE) / (x * (FA * x + FB) + FD * FF) - FE / FF;
}


// The scene's colour that was shown as `shown`.
float unshown(float shown) {
	if (filmic > 1.5) {
		return shown;
	}
	float target = clamp(shown, 0.0, 0.999);
	if (filmic < 0.5) {
		return target / exposure;
	}
	float top = film(white);
	float lo = 0.0;
	float hi = 16.0;
	for (int i = 0; i < 16; i++) {
		float mid = (lo + hi) * 0.5;
		if (film(mid) / top < target) {
			lo = mid;
		} else {
			hi = mid;
		}
	}
	return (lo + hi) * 0.5 / exposure;
}

void vertex() {
	// Face the camera.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 at = UV * 2.0 - 1.0;
	float r = length(at);
	vec2 out_way = r > 0.0001 ? at / r : vec2(0.0);
	// The haze: slow crossing ripples, strongest in the middle, nothing at the edge.
	float body = 1.0 - smoothstep(0.15, 0.95, r);
	vec2 ripple = vec2(sin(at.y * 9.0 + time * 3.1) + sin((at.x + at.y) * 13.0 - time * 4.3),
			cos(at.x * 10.0 - time * 2.7) + sin((at.x - at.y) * 11.0 + time * 3.7)) * 0.5;
	vec2 bend = ripple * haze * body * 0.012;
	// The ring of the wave, pushing outward as it goes.
	float band = exp(-pow((r - ring) / ring_width, 2.0)) * ring_strength;
	bend += out_way * band * 0.05;
	bend *= bend_scale;
	vec3 seen = texture(screen_tex, SCREEN_UV - bend).rgb;
	seen = vec3(unshown(seen.r), unshown(seen.g), unshown(seen.b));
	float shade = (haze * body * 0.5 + band) * dim;
	ALBEDO = seen * (1.0 - shade);
	ALPHA = clamp(max(haze * body, band) * 6.0, 0.0, 1.0) * (1.0 - smoothstep(0.7, 1.0, r));
}
"""


func _make_warp() -> void:
	if _warp_shader == null:
		_warp_shader = Shader.new()
		_warp_shader.code = WARP_SHADER
	_haze_material = ShaderMaterial.new()
	_haze_material.shader = _warp_shader
	_haze_material.set_shader_parameter(&"dim", 0.1)
	_haze_material.render_priority = 1
	_haze = _warp_quad(_haze_material, HAZE_SIZE)
	_haze.position = Vector3(0.0, 0.62, 0.0)
	_wave_material = ShaderMaterial.new()
	_wave_material.shader = _warp_shader
	_wave_material.set_shader_parameter(&"dim", 0.1)
	_wave_material.set_shader_parameter(&"ring_width", 0.08)
	_wave_material.render_priority = 1
	_wave = _warp_quad(_wave_material, WAVE_SIZE)
	# (round whatever she holds with her mind, wherever it is)
	_grip_material = ShaderMaterial.new()
	_grip_material.shader = _warp_shader
	_grip_material.set_shader_parameter(&"dim", 0.16)
	_grip_material.render_priority = 1
	_grip = _warp_quad(_grip_material, GRIP_SIZE)
	_grip.top_level = true
	_wave.position = Vector3(0.0, 0.7, 0.0)


func _warp_quad(material: ShaderMaterial, size: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	quad.mesh = mesh
	quad.material_override = material
	quad.scale = Vector3.ONE * size
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.visible = false
	add_child(quad)
	return quad


## Tells the warp's materials how the scene is tonemapped, so that they can undo it.
func _match_tonemap() -> void:
	var environment: Environment = get_world_3d().environment if is_inside_tree() and get_world_3d() else null
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera and camera.environment:
		environment = camera.environment
	for material: ShaderMaterial in [_haze_material, _wave_material, _grip_material]:
		if environment == null:
			material.set_shader_parameter(&"filmic", 0.0)
			material.set_shader_parameter(&"exposure", 1.0)
			continue
		# (with glow or adjustments the scene is tonemapped after, in a pass of its
		# own, and what is on the screen when this draws is not yet: nothing to undo)
		var after := environment.glow_enabled or environment.adjustment_enabled
		material.set_shader_parameter(&"filmic", 2.0 if after else (0.0 if environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR else 1.0))
		material.set_shader_parameter(&"white", environment.tonemap_white)
		material.set_shader_parameter(&"exposure", environment.tonemap_exposure)


func _warp(delta: float) -> void:
	if (_haze.visible or _wave.visible or _grip.visible) and (not _toned or fmod(_time, 2.0) < delta):
		_toned = true
		_match_tonemap()
	var d := _shown_distress
	var haze := smoothstep(0.08, 1.0, d) * 1.0
	if busy():
		haze = maxf(haze, 1.0 - smoothstep(0.1, 0.8, _burst_time))
	_haze.visible = haze > 0.01 and not far
	if _haze.visible:
		_haze_material.set_shader_parameter(&"haze", haze)
		_haze_material.set_shader_parameter(&"time", _time)
		_haze.scale = Vector3.ONE * HAZE_SIZE * (0.8 + 0.5 * d)
		_haze.position.y = 0.62 + 0.12 * d
	if _wave_time < INF:
		_wave_time += delta
		var t := _wave_time / WAVE_TIME
		_wave.visible = t < 1.0 and not far
		if t >= 1.0:
			_wave_time = INF
		else:
			_wave_material.set_shader_parameter(&"ring", 0.06 + 0.9 * sqrt(t))
			_wave_material.set_shader_parameter(&"ring_strength", 1.0 - t)
			_wave_material.set_shader_parameter(&"time", _time)
	elif _wave.visible:
		_wave.visible = false
	# Round what she holds: the air warped and dimmed, as round her.
	_grip_level = move_toward(_grip_level, 1.0 if reaching and reach_at.is_finite() else 0.0, delta * 3.0)
	_grip.visible = _grip_level > 0.01 and not far
	if _grip.visible:
		if reach_at.is_finite():
			_grip.global_position = _grip.global_position.lerp(reach_at, 1.0 - exp(-14.0 * delta)) if _grip_level > 0.05 else reach_at
		_grip_material.set_shader_parameter(&"haze", _grip_level * 0.85)
		_grip_material.set_shader_parameter(&"time", _time * 1.4)
	if _dust and _burst_time > 2.5 and _thud_time > 2.5 and _dust.process_mode != Node.PROCESS_MODE_DISABLED:
		_dust.process_mode = Node.PROCESS_MODE_DISABLED
	_thud_time += delta


## A puff of dust and grit where something is slammed down (at a point on the ground).
func thud(at: Vector3) -> void:
	if _dust == null:
		_dust = Dust.new()
		add_child(_dust)
	_dust.process_mode = Node.PROCESS_MODE_INHERIT
	_thud_time = 0.0
	_dust.puff(at, Vector3.ZERO, 1.1, 6, 1.6)


# --- Sounds ---

## Her humming, louder when she is near calm and breaking off as she is
## frightened; the ringing, rising with her distress; the burst's crack and boom.
func _sounds(delta: float) -> void:
	if _hum == null:
		return
	var d := _shown_distress
	var hum_to := 0.0 if far or drained or not humming or busy() else 1.0 - smoothstep(0.1, 0.35, d)
	_hum_level = move_toward(_hum_level, hum_to, delta * 1.5)
	if _hum_level > 0.01:
		if _hum.stream == null:
			_hum.stream = hum_sound()
		if not _hum.playing:
			_hum.play()
		_hum.volume_db = volume_db + linear_to_db(_hum_level)
		# (it wavers, and goes flat, as she is unsettled)
		_hum.pitch_scale = 1.0 - 0.06 * d + 0.012 * sin(_time * 0.7)
	elif _hum.playing:
		_hum.stop()
	var ring_level := 0.0 if far or busy() else smoothstep(0.12, 0.7, d)
	if ring_level > 0.01:
		if _ring.stream == null:
			_ring.stream = ring_sound()
		if not _ring.playing:
			_ring.play()
		_ring.volume_db = volume_db - 4.0 + linear_to_db(ring_level) + 10.0 * d
		_ring.pitch_scale = 0.85 + 0.45 * d
	elif _ring.playing:
		_ring.stop()


## A child's humming, made once and shared: a soft nasal "mmm" (one wave a
## cycle, its overtones falling away fast, read from a table), with a little
## breath in it, carrying a slow, sad little air in A minor that goes round
## (it is made to loop). Each note glides into the next; held ones waver.
static func hum_sound() -> AudioStreamWAV:
	if _hum_sound:
		return _hum_sound
	var rate := 16000
	# (note as a MIDI number, beats; 0 is a breath)
	var tune := [[69, 1.0], [72, 1.0], [76, 1.5], [74, 0.5], [72, 1.0], [71, 2.0], [0, 1.0],
			[69, 1.0], [71, 1.0], [72, 1.5], [71, 0.5], [69, 1.0], [68, 1.0], [69, 2.0], [0, 1.5]]
	var beat := 0.42
	var total := 0.0
	for note: Array in tune:
		total += float(note[1]) * beat
	var count := int(total * rate)
	var table := PackedFloat32Array()
	table.resize(256)
	for k in 256:
		var p := TAU * k / 256.0
		table[k] = sin(p) + 0.32 * sin(2.0 * p) + 0.12 * sin(3.0 * p) + 0.05 * sin(4.0 * p) + 0.02 * sin(5.0 * p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var pitch := 440.0
	var level := 0.0
	var breath := 0.0
	var at := 0.0
	var index := 0
	var started := 0.0
	var i := 0
	while i < count:
		var t := float(i) / rate
		while index < tune.size() - 1 and t >= at + float(tune[index][1]) * beat:
			at += float(tune[index][1]) * beat
			index += 1
			started = at
		var note: int = tune[index][0]
		var length: float = float(tune[index][1]) * beat
		var into := t - started
		var want := 0.0 if note == 0 else 1.0
		# (a breath between phrases; the end of each note eases off a little)
		want *= 1.0 - 0.25 * smoothstep(length - 0.12, length, into)
		level = lerpf(level, want, 0.0025)
		if note != 0:
			var target := 440.0 * pow(2.0, (note - 69) / 12.0)
			pitch = lerpf(pitch, target, 0.004)
		var vibrato := 1.0 + 0.006 * sin(t * TAU * 5.2) * smoothstep(0.25, 0.6, into)
		phase = fposmod(phase + pitch * vibrato / rate, 1.0)
		var value := table[int(phase * 256.0) & 255] * level * 0.55
		breath = lerpf(breath, rng.randf_range(-1.0, 1.0), 0.15)
		value += breath * (0.04 * level + 0.05 * (1.0 - want) * smoothstep(0.0, 0.2, into) * (1.0 - smoothstep(0.3, 0.6, into)))
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 24000.0))
		i += 1
	_hum_sound = AudioStreamWAV.new()
	_hum_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_hum_sound.mix_rate = rate
	_hum_sound.data = data
	_hum_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hum_sound.loop_end = count
	return _hum_sound


## The ringing: a thin high tone, with a second just off it so that the two
## beat slowly, and a faint shimmer an octave over. One second, made to loop.
static func ring_sound() -> AudioStreamWAV:
	if _ring_sound:
		return _ring_sound
	var rate := 16000
	var count := rate
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		# (whole numbers of cycles a second, so that the loop has no seam)
		var value := sin(TAU * 2900.0 * t) * 0.5 + sin(TAU * 2903.0 * t) * 0.4 + sin(TAU * 5807.0 * t) * 0.08 + sin(TAU * 1450.0 * t) * 0.06
		data.encode_s16(i * 2, int(value * 0.6 * 30000.0))
	_ring_sound = AudioStreamWAV.new()
	_ring_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_ring_sound.mix_rate = rate
	_ring_sound.data = data
	_ring_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ring_sound.loop_end = count
	return _ring_sound


## The burst: a dry crack like a stick snapped close by, a deep soft boom under
## it falling away, and a rushing scatter of grit after.
static func burst_sound() -> AudioStreamWAV:
	if _burst_sound:
		return _burst_sound
	var rate := 16000
	var length := 1.8
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var grit := 0.0
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		var crack := noise * exp(-t * 60.0) * 1.4
		phase += lerpf(70.0, 26.0, minf(t / 0.9, 1.0)) / rate
		var boom := sin(TAU * phase) * exp(-t * 3.2) * smoothstep(0.0, 0.01, t) * 1.2
		low = lerpf(low, noise, 0.02)
		boom += low * exp(-t * 4.0) * 2.0
		grit = lerpf(grit, noise, 0.5)
		var scatter := (noise - grit) * 0.5 * smoothstep(0.05, 0.2, t) * exp(-t * 2.2) * (0.6 + 0.4 * absf(sin(t * 47.0)))
		var value := tanh((crack + boom + scatter) * 1.3)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	_burst_sound = AudioStreamWAV.new()
	_burst_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_burst_sound.mix_rate = rate
	_burst_sound.data = data
	return _burst_sound
