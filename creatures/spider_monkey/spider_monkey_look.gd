class_name SpiderMonkeyLook
## How a SpiderMonkey (creatures/spider_monkey/spider_monkey.gd) is shaded: one
## material for every spider monkey, put over its model
## (creatures/spider_monkey/models/, built in Blender by
## tools/build_spider_monkey.py).
##
## The model carries its colours as vertex colours: the coat near black-brown,
## a little browner on the belly and inside the limbs; the bare face dark grey
## with its pale mask of skin round the eyes and the muzzle; dark hands, feet
## and the grip pad under the tail. Its first UV says how wet a point is (x: the
## eyes, the nose, the lips) and how much it is fur (y); its second UV is where
## the point was on the standing body, so that the streaks of the coat stay put
## on it as it moves.
##
## Shading is cel shading in two tones with a hard edge and a rim of light at
## grazing angles (a brighter shade of the coat itself, so the shaggy edge of it
## reads against the mist); the fur is finely streaked and takes the light
## softly; wet parts take a hard little highlight, so the eyes glint. Each one's
## coat is a little lighter or darker (`tone`).

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.55;
uniform float flatness = 0.65;
uniform float rim_gain = 0.6;
uniform float rim_width = 0.3;
uniform float gloss = 70.0;
instance uniform float tone = 1.0;

varying float wet;
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

void vertex() {
	wet = UV.x;
	furry = UV.y;
}

void fragment() {
	// Fine streaks in the coat, running along the hair, and a coarser mottling.
	float streak = noise(UV2 * vec2(90.0, 14.0));
	float clump = noise(UV2 * 22.0);
	float shade = 1.0 + ((streak - 0.5) * 0.3 + (clump - 0.5) * 0.18) * furry;
	ALBEDO = COLOR.rgb * shade * mix(1.0, tone, furry);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	// Shadows only dim it, so that the shaggy coat does not break up into patches.
	float lit = cut(facing, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.72, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// (the hair takes it; the bare skin of the belly and limbs between the hair hardly)
	float rim = cut(graze, 1.0 - rim_width) * mix(0.4, 1.0, lit) * mix(0.25, 1.0, smoothstep(0.75, 1.0, furry));
	// (a brighter shade of the coat: its dark mass still reads against the mist)
	SPECULAR_LIGHT += rim * rim_gain * (ALBEDO * 2.2 + vec3(0.02)) * strength * LIGHT_COLOR / PI;
	// A hard little highlight on wet things: the eyes glint.
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.45);
	SPECULAR_LIGHT += shine * smoothstep(0.4, 0.8, wet) * strength * LIGHT_COLOR * 0.8;
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
