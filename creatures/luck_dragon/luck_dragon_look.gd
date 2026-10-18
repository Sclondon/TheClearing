class_name LuckDragonLook
## How a LuckDragon (creatures/luck_dragon/luck_dragon.gd) is shaded: one
## material over its model (creatures/luck_dragon/models/luck_dragon.glb,
## built by tools/build_luck_dragon.py).
##
## The model says what each vertex is in UV2.x (see build_luck_dragon.py:
## scales, fur, the soft skin of the face, eye, nose and claws, mouth), with a
## random number per piece in UV2.y; its colour is the vertex colour, and the
## alpha of that is how open it is (0 deep in a fold). This draws, from those:
## - scales: small, rounded and overlapping, in rows round the body (each a
##   little paler at its edge), and broad plates across the belly; a pearly
##   sheen that turns faintly pink, green and blue as it slants away;
## - fur: soft white locks, strands running along them, darker at the root;
## - the face: fine soft scales, close-set, without the sheen of the body's;
## - the eyes: dark and wet, a deep brown ring round a black middle, with a glint;
## - nose and claws: dark and a little glossy; the mouth dark.
## Lit in soft cel bands with a rim, so it sits with the game's cel-shaded
## cast, and drawn from both sides (the fur is single sheets).

const SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform float wrap = 0.4;
uniform float flatness = 0.4;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.3;
uniform float pearl = 1.0;
// How pale, each dragon its own.
instance uniform float tone = 1.0;

varying float kind;
varying float seed;
varying float shine;
varying float sheen;

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
	kind = UV2.x;
	seed = UV2.y;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float open = COLOR.a;
	float rough = 0.8;
	float spec = 0.1;
	float glow = 0.0;
	shine = 0.0;
	sheen = 0.0;
	float k = floor(kind + 0.5);
	if (k < 0.5) {
		// Scales: rows round the body (UV.x metres along it, UV.y round it).
		float belly = 1.0 - smoothstep(0.08, 0.13, abs(UV.y - 0.75));
		vec2 q = vec2(UV.x * 5.2, UV.y * 30.0);
		q.y += floor(q.x) * 0.5;
		vec2 f = fract(q);
		// (each scale a rounded tip pointing back along the body, its edge paler)
		float d = length(vec2((f.y - 0.5) * 1.15, f.x * 0.95));
		float edge = smoothstep(0.38, 0.52, d);
		float scale = mix(0.96, 1.03, 1.0 - edge) * (0.96 + 0.08 * hash(floor(q)));
		// The belly: broad plates across it.
		float plate = fract(UV.x * 2.6);
		float seam = smoothstep(0.0, 0.08, plate) * smoothstep(1.0, 0.86, plate);
		float plates = mix(0.9, 1.02, seam);
		c *= mix(scale, plates, belly);
		c *= mix(0.6, 1.0, open);
		spec = 0.15;
		rough = 0.6;
		shine = 0.15;
		sheen = pearl * (1.0 - belly * 0.5);
	} else if (k < 1.5) {
		// Fur: soft strands along each lock, darker at the root.
		float strand = noise(vec2(UV.y * 9.0 + seed * 31.0, UV.x * 1.5));
		c *= 0.88 + 0.16 * strand;
		c *= mix(0.72, 1.0, smoothstep(0.0, 0.45, UV.x));
		spec = 0.05;
		rough = 0.95;
	} else if (k < 2.5) {
		// The face: soft, close skin, faintly mottled.
		c *= 0.95 + 0.07 * noise(UV * vec2(14.0, 60.0) + seed * 9.0);
		c *= mix(0.62, 1.0, open);
		spec = 0.05;
		rough = 0.85;
		shine = 0.03;
		sheen = pearl * 0.4;
	} else if (k < 3.5) {
		// The eyes: a deep brown ring round a black middle, wet.
		float front = 1.0 - smoothstep(0.0, 0.42, UV.y);
		c = mix(c, vec3(0.16, 0.09, 0.05), front * 0.8);
		c = mix(c, vec3(0.015), 1.0 - smoothstep(0.0, 0.2, UV.y));
		spec = 0.9;
		rough = 0.08;
		shine = 1.0;
		glow = 0.04;
	} else if (k < 4.5) {
		c *= 0.9 + 0.2 * noise(UV * 40.0);
		spec = 0.3;
		rough = 0.4;
		shine = 0.3;
	} else {
		spec = 0.1;
		rough = 0.7;
	}
	ALBEDO = c * tone * 0.74;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = c * glow;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing, 0.05) * mix(0.6, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.55, 1.0, smoothstep(0.05, 0.9, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
	// The pearl: a faint sheen of pink, green and blue as the scales slant away.
	vec3 nacre = 0.5 + 0.5 * cos(6.2831 * (graze * 0.9 + vec3(0.0, 0.33, 0.67)));
	SPECULAR_LIGHT += sheen * smoothstep(0.55, 1.0, graze) * nacre * 0.05 * strength * LIGHT_COLOR * lit;
	// A soft glint (the scales, the wet eyes).
	vec3 half_way = normalize(LIGHT + VIEW);
	float gloss = pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 40.0);
	SPECULAR_LIGHT += smoothstep(0.3, 0.7, gloss) * shine * strength * LIGHT_COLOR * lit;
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
