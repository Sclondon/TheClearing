class_name WeaverLook
## How a Weaver (creatures/weaver/weaver.gd) is shaded: one material, put over
## its model (creatures/weaver/models/, built in Blender by tools/build_weaver.py).
##
## The model carries its colours as vertex colours (waxen grey-white skin, the
## porcelain of its head, its pale wings). Its first UV says what part a point is
## on (x: 0 skin, 0.5 head, 1 wing) and, on a wing, how far towards its ragged
## trailing edge it is (y); its second UV is where the point was on the standing
## body, and on a wing where it is in the wing (along, across), for the veins and
## the tatters.
##
## Skin: cel shading in two tones with a soft wrap (light seems to sink into
## it), a cold rim, faint blue veins under it. The head: the same, with a hard
## wet sheen. The wings: veined like a lacewing's, the light coming through them
## from behind (they glow a little against the mist), torn through with holes and
## ragged at the trailing edge (cut out with an alpha scissor, so they cost nothing to sort).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.7;
uniform float flatness = 0.6;
uniform float rim_gain = 0.6;
uniform float rim_width = 0.3;
uniform vec3 rim_colour : source_color = vec3(0.8, 0.85, 0.9);
uniform float gloss = 90.0;
instance uniform float tone = 1.0;

varying float part;
varying float edge;

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
	part = UV.x;
	edge = UV.y;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	float wing = smoothstep(0.75, 0.9, part);
	float head = smoothstep(0.35, 0.45, part) * (1.0 - wing);
	float skin = 1.0 - wing - head;
	// The wing: its veins (long ones from the root, cross veins between), holes
	// torn in it, more of them and a ragged edge towards the trailing edge.
	vec2 w = UV2;
	float vein_long = smoothstep(0.93, 0.97, abs(fract(w.y * 4.0 + w.x * w.x * 2.5 + noise(w * 4.0) * 0.6) - 0.5) * 2.0);
	float vein_cross = smoothstep(0.94, 0.97, abs(fract(w.x * 7.0 + w.y * 2.5 + noise(w * vec2(6.0, 9.0)) * 1.2) - 0.5) * 2.0) * step(0.35, noise(w * vec2(14.0, 5.0)));
	float veins = max(vein_long, vein_cross * 0.7) * wing;
	float tear = noise(w * vec2(9.0, 7.0)) * 0.6 + noise(w * vec2(23.0, 19.0)) * 0.4;
	float hole = step(0.5, wing) * step(tear, mix(0.3, 0.62, smoothstep(0.4, 1.0, w.y)) * smoothstep(0.15, 0.4, w.x));
	// Skin: faint veins, a mottle.
	float mottle = noise(UV2 * 24.0) * 0.6 + noise(UV2 * 70.0) * 0.4;
	float blue = smoothstep(0.93, 0.98, 1.0 - abs(noise(UV2 * vec2(22.0, 70.0)) - 0.5) * 2.0) * skin;
	vec3 base = colour * (1.0 + (mottle - 0.5) * 0.1 * skin) * mix(1.0, tone, skin);
	base = mix(base, base * vec3(0.8, 0.86, 0.98), blue * 0.35);
	base = mix(base, base * 0.6, veins);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (the wings let the light through: a glow of their own against the mist)
	EMISSION = base * 0.5 * wing * (1.0 - veins * 0.7);
	// (the holes cut out: alpha scissor, so nothing to sort)
	ALPHA = 1.0 - hole;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

float cut(float value, float e) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(e - pixel, e + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float wing_part = smoothstep(0.75, 0.9, part);
	// (a wing is lit on whichever side the light falls)
	float side_on = mix(dot(NORMAL, LIGHT), abs(dot(NORMAL, LIGHT)), wing_part);
	float facing = (side_on + wrap) / (1.0 + wrap);
	float lit = cut(facing, 0.05) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.75, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	float wing = smoothstep(0.75, 0.9, part);
	// (lit from behind, a wing glows through)
	float through = clamp(-dot(NORMAL, LIGHT), 0.0, 1.0) * wing * 0.6;
	DIFFUSE_LIGHT += (lit + through) * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * mix(0.4, 1.0, lit) * (1.0 - wing);
	SPECULAR_LIGHT += rim * rim_gain * mix(ALBEDO, ALBEDO * rim_colour * 2.0, 0.5) * strength * LIGHT_COLOR / PI;
	// The porcelain of its head shines hard.
	float head = smoothstep(0.35, 0.45, part) * (1.0 - wing);
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.35);
	SPECULAR_LIGHT += shine * head * strength * LIGHT_COLOR * 0.4;
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
