class_name LizardPersonLook
## How a LizardPerson (creatures/lizard_person/lizard_person.gd) is shaded: one
## material for every one, put over its model (creatures/lizard_person/models/,
## built in Blender by tools/build_lizard_person.py).
##
## The model carries what the shader needs. Its vertex colour is the skin's
## own colour (darker over the back, pale under the belly, the dewlap, the eyes,
## claws and mouth); its first UV and its second UV's x are where the point is
## on the body as modelled, so the pattern stays put on it however it moves;
## its second UV's y says what the point is (its whole part: 0 scaled skin,
## 1 an eye, 2 claw or tooth, 3 the inside of the mouth, 4 the eyes' membranes,
## 5 the big scutes) and, in its fraction, how far it is under the belly.
##
## On the skin it cuts fine scales (a cell pattern: each scale a little lighter
## in its middle, darker in the grooves between), mottles it in blotches and
## broken bands across the back, and plates the belly in rows. The scales fade
## out where they would be smaller than a pixel, so that from afar it is only
## mottled. Cold, it is darker (`cold`). Lit in two tones with a rim, as the
## other creatures are, and with a sharp small shine on its scales and its eyes.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.2;
uniform vec3 mottle_dark : source_color = vec3(0.13, 0.135, 0.11);
uniform vec3 mottle_pale : source_color = vec3(0.5, 0.5, 0.42);
// Each one's own skin, a little lighter or darker, and how cold it is (darker).
instance uniform float tone = 1.0;
instance uniform float cold = 0.0;

varying vec3 rest;
varying float kind;
varying float belly;
varying float shiny;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	return vec3(hash3(p), hash3(p + 17.1), hash3(p + 41.7));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The nearest and second nearest cell points: x the gap to the edge between
// them (0 in a groove), y how far from the middle of its own scale.
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 c = o + 0.15 + 0.7 * hash33(i + o) - f;
				float d = dot(c, c);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(sqrt(d2) - sqrt(d1), sqrt(d1));
}

void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	kind = floor(UV2.y + 0.02);
	belly = clamp((UV2.y - kind) / 0.8, 0.0, 1.0);
}

void fragment() {
	vec3 colour = COLOR.rgb;
	shiny = 0.0;
	float k = kind;
	if (k < 0.5 || k > 4.5) {
		// Mottled: blotches, and broken dark bands across the back.
		float big = noise3(rest * 4.0);
		float small = noise3(rest * 13.0 + 3.1);
		float band = smoothstep(0.35, 0.75, sin(rest.z * 8.5 + big * 3.0 + rest.x * 1.5) * 0.5 + 0.5);
		float dark = clamp((band * 0.6 + smoothstep(0.55, 0.8, small) * 0.4) * (1.0 - belly), 0.0, 1.0);
		colour = mix(colour, colour * mottle_dark / 0.32, dark * 0.55);
		float speck = smoothstep(0.72, 0.86, noise3(rest * 22.0 + 7.0)) * (1.0 - belly);
		colour = mix(colour, mottle_pale, speck * 0.25);
		// Scales: fine on the body, big where it is plated; rows on the belly.
		float density = k > 4.5 ? 34.0 : 85.0;
		vec3 at = rest * density;
		float pixel = length(fwidth(at));
		float detail = 1.0 - smoothstep(0.25, 0.7, pixel);
		if (detail > 0.0) {
			vec2 c = cells(at);
			float groove = 1.0 - smoothstep(0.0, 0.07 + pixel * 0.5, c.x);
			float dome = 1.0 - smoothstep(0.1, 0.6, c.y);
			// (the belly's plates: rows across it, a little offset row to row)
			float row = rest.z * 40.0;
			float col = rest.x * 30.0 + floor(row) * 0.5;
			vec2 plate = abs(fract(vec2(col, row)) - 0.5);
			float plate_groove = 1.0 - smoothstep(0.36, 0.47 - pixel * 0.2, max(plate.x * 0.85, plate.y));
			plate_groove = 1.0 - plate_groove;
			float under = smoothstep(0.5, 0.8, belly);
			groove = mix(groove, plate_groove * 0.55, under);
			colour *= mix(1.0, mix(0.84, 1.0, 1.0 - groove) * (1.0 + 0.06 * dome * (1.0 - under)), detail);
			shiny = dome * detail * (1.0 - groove);
		}
		colour *= tone;
	} else if (k < 1.5) {
		shiny = 2.0;
	} else if (k < 2.5) {
		shiny = 0.6;
	}
	ALBEDO = colour * mix(1.0, 0.6, cold);
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
	float lit = cut(facing, 0.04) * mix(0.5, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
	// A small hard shine: on the domes of its scales, and wet on its eyes.
	vec3 half_way = normalize(LIGHT + VIEW);
	float shine = pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), shiny > 1.5 ? 90.0 : 28.0);
	float amount = shiny > 1.5 ? 0.9 : 0.12 * shiny;
	SPECULAR_LIGHT += cut(shine, 0.5) * amount * strength * reach * LIGHT_COLOR;
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
