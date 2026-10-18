class_name ColossusLook
## How a Colossus (creatures/colossus/colossus.gd) is shaded and what it throws
## up: one material for its body, the shadow its feet and hands cast before
## they come down, and the dust and stones of its steps. All made in code.
##
## The model (creatures/colossus/models/, built in Blender by
## tools/build_colossus.py) carries its colours as vertex colours: dark matted
## fur, weathered stone with moss on whatever faces up, grass, vines, and the
## pale glow of its eyes and runes. Its first UV says how much a point glows
## (x) and what it is (y: 0 fur, 1 stone, 2 a plant); its second is where the
## point was on the standing body, so that the grain of the stone and the
## streaks in the fur stay put on it as it moves.
##
## Shading is the house cel light (two tones with a soft wrap, a rim at grazing
## angles), so that it sits with cel-shaded figures without their scripts. And
## a mist of its own over its upper body (`mist_from` to `mist_to`, in metres
## above the ground): so high up, it is lost in the overcast, the way a far wall
## is, while its eyes still show through.

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.2;
// The pale glow of its eyes and runes, and how strongly it glows (it brightens when it has seen someone).
uniform vec3 glow_colour : source_color = vec3(0.78, 0.92, 1.0);
uniform float glow_energy = 1.6;
// Its own mist: from mist_from to mist_to metres up (world), as much as mist_amount, of mist_colour.
uniform vec3 mist_colour : source_color = vec3(0.6, 0.64, 0.63);
uniform float mist_from = 75.0;
uniform float mist_to = 200.0;
uniform float mist_amount = 0.45;
// The grain of the stone (soft blotches) and its cracks (cells), made in code
// (ColossusLook.grain_texture, crack_texture), and how often they repeat in
// one of the model's units.
uniform sampler2D grain_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D crack_tex : repeat_enable, filter_linear_mipmap;
uniform float grain = 1.0;

varying float glow;
varying float kind;
varying float world_y;

void vertex() {
	glow = UV.x;
	kind = UV.y;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	float stone = clamp(1.0 - abs(kind - 1.0), 0.0, 1.0) * (1.0 - clamp(glow * 4.0, 0.0, 1.0));
	float fur = clamp(1.0 - kind, 0.0, 1.0);
	vec2 at = UV2 * grain;
	// Stone: broad weathering, a finer grain and a speckle, a few long cracks
	// (the edges of great cells, here and there), flecks of pale lichen.
	float broad = texture(grain_tex, at * 0.45).r;
	float fine = texture(grain_tex, at * 2.7 + vec2(0.31, 0.17)).r;
	float speck = texture(grain_tex, at * 11.0 + vec2(0.7, 0.3)).r;
	float cells = texture(crack_tex, at * 0.22).r;
	float some = smoothstep(0.5, 0.62, texture(grain_tex, at * 0.3 + vec2(0.2, 0.6)).r);
	float crack = (1.0 - smoothstep(0.004, 0.012, cells)) * some;
	float lichen = smoothstep(0.7, 0.76, speck) * smoothstep(0.45, 0.7, broad);
	vec3 rock = colour * mix(0.55, 1.05, broad) * mix(0.85, 1.07, fine) * mix(0.9, 1.06, speck);
	rock *= 1.0 - crack * 0.45;
	rock = mix(rock, vec3(0.52, 0.54, 0.47), lichen * 0.3);
	// Fur: streaks running down it, matted in clumps.
	float streak = texture(grain_tex, at * vec2(5.0, 0.5)).r;
	vec3 hair = colour * mix(0.6, 1.3, streak) * mix(0.85, 1.1, broad);
	ALBEDO = mix(mix(colour, hair, fur), rock, stone);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// High up it is lost in the overcast.
	float veil = smoothstep(mist_from, mist_to, world_y) * mist_amount;
	ALBEDO = mix(ALBEDO, mist_colour * 0.75, veil);
	EMISSION = glow_colour * clamp(glow, 0.0, 1.0) * glow_energy * (1.0 - veil * 0.3);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing, 0.04) * mix(0.5, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

## The shadow on the ground under a foot or a hand that is coming down: a soft
## dark blot (a flat square, faded round), darker as it nears.
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform float strength = 0.0;
uniform float softness = 0.45;

void fragment() {
	vec2 at = UV * 2.0 - 1.0;
	float d = length(at * at * at * at) * 0.5 + length(at) * 0.5;
	float blot = 1.0 - smoothstep(1.0 - softness, 1.0, d);
	ALBEDO = vec3(0.02, 0.02, 0.025);
	ALPHA = blot * strength;
}
"""

static var _material: ShaderMaterial
static var _shadow_shader: Shader


## The body's material: one for every colossus (set its uniforms per instance
## with `instance_material` if you want one to differ).
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter(&"grain_tex", grain_texture())
		_material.set_shader_parameter(&"crack_tex", crack_texture())
	return _material


## A material of its own for one colossus (its glow and mist can be set apart).
static func instance_material() -> ShaderMaterial:
	return material().duplicate() as ShaderMaterial


static var _grain: NoiseTexture2D
static var _cracks: NoiseTexture2D


## Soft fractal noise that tiles: the weathering and grain of its stone, the streaks in its fur.
static func grain_texture() -> NoiseTexture2D:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		noise.seed = 11
		_grain = NoiseTexture2D.new()
		_grain.width = 256
		_grain.height = 256
		_grain.seamless = true
		_grain.generate_mipmaps = true
		_grain.noise = noise
	return _grain


## Cells that tile, dark along their edges: the cracks in its stone.
static func crack_texture() -> NoiseTexture2D:
	if _cracks == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		noise.cellular_jitter = 0.9
		noise.frequency = 0.03
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.seed = 5
		_cracks = NoiseTexture2D.new()
		_cracks.width = 256
		_cracks.height = 256
		_cracks.seamless = true
		_cracks.generate_mipmaps = true
		_cracks.noise = noise
	return _cracks


## A shadow blot's material (each blot has its own, for its strength).
static func shadow_material() -> ShaderMaterial:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shadow_shader
	return material


## A cloud of dust for a footfall: big soft puffs that roll out along the
## ground and hang, rising a little. `size` is the foot's size, metres.
static func dust(size: float) -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.emitting = false
	puff.one_shot = true
	puff.amount = 40
	puff.lifetime = 5.0
	puff.explosiveness = 0.92
	puff.local_coords = false
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	puff.emission_ring_axis = Vector3.UP
	puff.emission_ring_radius = size * 0.5
	puff.emission_ring_inner_radius = size * 0.3
	puff.emission_ring_height = 0.5
	puff.direction = Vector3(0.0, 0.15, 0.0)
	puff.spread = 180.0
	puff.flatness = 0.85
	puff.initial_velocity_min = size * 0.5
	puff.initial_velocity_max = size * 1.0
	puff.gravity = Vector3(0.0, 0.25, 0.0)
	puff.damping_min = size * 0.12
	puff.damping_max = size * 0.2
	puff.scale_amount_min = size * 0.35
	puff.scale_amount_max = size * 0.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(0.4, 0.85))
	grow.add_point(Vector2(1.0, 1.0))
	puff.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.53, 0.49, 0.0))
	fade.set_color(1, Color(0.6, 0.6, 0.57, 0.0))
	fade.add_point(0.05, Color(0.46, 0.44, 0.4, 0.8))
	fade.add_point(0.5, Color(0.56, 0.56, 0.53, 0.45))
	puff.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _puff_material()
	puff.mesh = quad
	return puff


## Stones and clods of earth: falling from a foot as it is lifted and carried,
## and showering from its body as it moves. `size` is how big a stone is, metres.
static func stones(size: float) -> CPUParticles3D:
	var rain := CPUParticles3D.new()
	rain.emitting = false
	rain.amount = 40
	rain.lifetime = 3.2
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rain.emission_sphere_radius = 4.0
	rain.direction = Vector3.DOWN
	rain.spread = 20.0
	rain.initial_velocity_min = 0.0
	rain.initial_velocity_max = 2.0
	rain.gravity = Vector3(0.0, -14.0, 0.0)
	rain.angular_velocity_min = -200.0
	rain.angular_velocity_max = 200.0
	rain.scale_amount_min = size * 0.4
	rain.scale_amount_max = size * 1.2
	rain.color = Color(0.42, 0.4, 0.36)
	var rock := BoxMesh.new()
	rock.size = Vector3(1.0, 0.7, 0.8)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.3, 0.28, 0.25)
	material.roughness = 1.0
	rock.material = material
	rain.mesh = rock
	return rain


static var _puff: StandardMaterial3D
static var _glint: ShaderMaterial

## A soft pale point for each eye, drawn through the mist (it ignores fog) and
## only from far off (from 70 m, fully by 200 m), so that from across the maze
## or the clearing two pale lights show where its head is.
const GLINT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(0.78, 0.92, 1.0);
instance uniform float bright = 1.4;

void vertex() {
	// (always facing the camera)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float far = smoothstep(70.0, 200.0, length(VERTEX));
	float spot = exp(-r * r * 9.0) + exp(-r * r * 2.5) * 0.25;
	ALBEDO = colour * spot * bright * 0.6 * far;
}
"""


static func glint_material() -> ShaderMaterial:
	if _glint == null:
		var shader := Shader.new()
		shader.code = GLINT_SHADER
		_glint = ShaderMaterial.new()
		_glint.shader = shader
	return _glint


static func _puff_material() -> StandardMaterial3D:
	if _puff == null:
		_puff = StandardMaterial3D.new()
		_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff.vertex_color_use_as_albedo = true
		_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# (or each puff would be drawn a metre across, whatever its scale)
		_puff.billboard_keep_scale = true
		_puff.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var round_puff := GradientTexture2D.new()
		round_puff.fill = GradientTexture2D.FILL_RADIAL
		round_puff.fill_from = Vector2(0.5, 0.5)
		round_puff.fill_to = Vector2(1.0, 0.5)
		round_puff.width = 64
		round_puff.height = 64
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		soft.add_point(0.5, Color(1, 1, 1, 0.55))
		round_puff.gradient = soft
		_puff.albedo_texture = round_puff
	return _puff
