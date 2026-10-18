class_name GibbonLook
## How a Gibbon (creatures/gibbon/gibbon.gd) is shaded: one material for every
## gibbon, put over its model (creatures/gibbon/models/, built in Blender by
## tools/build_gibbon.py).
##
## The model carries no colours of its own, only where things are, in its
## vertex colours: red, how light the coat is there (half is the coat as it is:
## a little darker down the back and in the folds, lighter at the tips of the
## shag); green, where the pale fur would be on a ringed gibbon (the ring round
## its face, the backs of its hands and feet); blue, bare skin (the face, the
## palms and soles, dark grey-black). Each gibbon gives its own coat and pale
## (instance uniforms `coat`, `pale`, `ring`), so one model makes every kind.
## Its first UV says how much a point is an eye (x) and how much it is fur (y:
## fur is faintly streaked and has a rim of light at its edge). Its second UV is
## where the point was on the standing body, so the streaks stay put on it.
##
## Shading is cel shading in two tones with a rim of light at grazing angles,
## so it sits with a cel-shaded cast without needing their scripts. Shadows
## only dim it, so that the shag does not break up into patches.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.55;
uniform float flatness = 0.65;
uniform float rim_gain = 0.45;
uniform float rim_width = 0.24;
uniform vec3 skin : source_color = vec3(0.12, 0.11, 0.105);
uniform vec3 eye : source_color = vec3(0.09, 0.05, 0.03);
uniform vec3 bone : source_color = vec3(0.78, 0.74, 0.64);
// Each gibbon's own coat, the pale of its ring, hands and feet, and whether it has them.
instance uniform vec3 coat : source_color = vec3(0.1, 0.09, 0.08);
instance uniform vec3 pale : source_color = vec3(0.8, 0.78, 0.74);
instance uniform float ring = 1.0;

varying float eyes;
varying float furry;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying float teeth;

void vertex() {
	teeth = step(1.5, UV.x);
	eyes = clamp(UV.x, 0.0, 1.0) * (1.0 - teeth);
	furry = UV.y;
}

void fragment() {
	float streak = noise(UV2 * vec2(80.0, 12.0));
	float shade = COLOR.r * 2.0 * (1.0 + (streak - 0.5) * 0.3 * furry);
	vec3 fur = mix(coat, pale, clamp(COLOR.g, 0.0, 1.0) * ring);
	// (dark fur takes the light a little greyer, as black hair does)
	vec3 colour = fur * shade + vec3(0.012) * furry;
	colour = mix(colour, skin, clamp(COLOR.b, 0.0, 1.0));
	colour = mix(colour, eye, clamp(eyes, 0.0, 1.0));
	colour = mix(colour, bone, teeth);
	ALBEDO = colour;
	ROUGHNESS = mix(1.0, 0.3, clamp(eyes, 0.0, 1.0));
	SPECULAR = 0.5 * clamp(eyes, 0.0, 1.0);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.72, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	// The rim: a brighter shade of the surface itself, and a soft grey sheen on dark fur
	// (so a black gibbon against the mist still has an edge).
	SPECULAR_LIGHT += rim * (rim_gain * ALBEDO + vec3(0.025) * furry) * strength * LIGHT_COLOR / PI;
	// (and its wet eyes catch the light)
	float glint = pow(clamp(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0, 1.0), 24.0) * eyes;
	SPECULAR_LIGHT += glint * 0.8 * LIGHT_COLOR * strength;
}
"""

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material
