class_name ImpLook
## How an Imp (creatures/imp/imp.gd) is shaded: one material for every imp, put
## over its model (creatures/imp/models/, built in Blender by tools/build_imp.py).
##
## The model carries its colours as vertex colours: sooty red-brown skin, darker
## to charcoal along the back, the hands, feet, horns and ear tips; a duller,
## warmer belly; bone-yellow needle teeth and claws; a dark wet mouth. Its first
## UV says how much a point glows (x: 1 for the eyes) and how wet it is (y: the
## eyes, the mouth and the teeth shine; skin a little); its second UV is where
## the point was on the standing body, so the creases and mottling of its
## leathery skin stay put on it as it moves.
##
## Shading is cel shading in two tones with a hard edge and a thin rim of light
## at grazing angles, so it sits with the cel-shaded cast; wet parts take a
## hard little highlight, so the eyes glint and the teeth catch the light.
## Each imp's own skin is a little lighter or darker (`tone`) and redder or
## sootier (`warmth`).

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.55;
uniform float rim_width = 0.25;
uniform vec3 rim_colour : source_color = vec3(1.0, 0.55, 0.4);
uniform float gloss = 60.0;
instance uniform float tone = 1.0;
instance uniform float warmth = 0.0;

varying float glow;
varying float wet;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	glow = UV.x;
	wet = UV.y;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	// How much of it is skin (not teeth, claws, eyes or mouth): the dull, dark parts.
	float skin = 1.0 - smoothstep(0.25, 0.6, wet);
	// Leathery: mottled, and finely creased.
	float mottle = noise(UV2 * 40.0) * 0.5 + noise(UV2 * 110.0) * 0.5;
	float crease = smoothstep(0.44, 0.5, abs(noise(UV2 * vec2(160.0, 50.0)) - 0.5) * 2.0);
	float shade = 1.0 + (mottle - 0.5) * 0.16 * skin - crease * 0.08 * skin;
	vec3 sooty = mix(colour, vec3(dot(colour, vec3(0.4, 0.4, 0.2))) * vec3(0.9, 0.85, 0.8), clamp(-warmth, 0.0, 1.0) * 0.6 * skin);
	vec3 redder = mix(sooty, sooty * vec3(1.25, 0.85, 0.75), clamp(warmth, 0.0, 1.0) * skin);
	ALBEDO = redder * shade * mix(1.0, tone, skin);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = colour * glow * 1.6;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing, 0.05) * mix(0.5, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * mix(0.35, 1.0, lit);
	SPECULAR_LIGHT += rim * rim_gain * mix(ALBEDO, ALBEDO * rim_colour * 2.0, 0.5) * strength * LIGHT_COLOR / PI;
	// A hard little highlight on wet things: the eyes glint, the teeth catch the light.
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.45);
	SPECULAR_LIGHT += shine * smoothstep(0.4, 0.8, wet) * strength * LIGHT_COLOR * 0.9;
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
