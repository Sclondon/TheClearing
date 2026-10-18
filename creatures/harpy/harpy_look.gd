class_name HarpyLook
## How a Harpy (creatures/harpy/harpy.gd) is shaded: one material over its
## model (creatures/harpy/models/harpy.glb, built by tools/build_harpy.py).
##
## The model says what each vertex is in UV2.x (see build_harpy.py: skin,
## feather, hair, scales, horn, eye, mouth, teeth, plumage), with a random
## number per piece in UV2.y; its colour is the vertex colour, and the alpha of
## that is how open it is (0 deep in a hollow). This draws, from those:
## - skin: ashen and mottled, darker in its hollows, with a damp sheen;
## - feathers: the barbs running out from the rachis at a slant, the rachis
##   pale down the middle, the vane darker towards its edges and ragged there;
## - plumage (the skin under the body's feathers and over the wing's arm):
##   rows of small shingled coverts, each a rounded tip with a dark edge;
## - hair: wet, almost black, with a glint running along it;
## - scales: the tarsi and toes in rows of plates with dark seams;
## - horn (talons, claws): black and glossy; the eyes milky and dull; the mouth dark.
## Lit in soft cel bands with a rim, so it sits with a cel-shaded cast; drawn
## from both sides (feathers and hair are single sheets).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.25;
// How filthy and how dark, each harpy its own.
instance uniform float tone = 1.0;

varying float kind;
varying float seed;
varying vec3 local_pos;
// How much of a glint it takes (wet skin and hair, horn, the eyes).
varying float shine;

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
	local_pos = VERTEX;
}

float is(float k) {
	return 1.0 - step(0.5, abs(kind - k));
}

void fragment() {
	vec3 c = COLOR.rgb;
	float open = COLOR.a;
	float rough = 1.0;
	float spec = 0.0;
	float glow = 0.0;
	shine = 0.0;
	float k = floor(kind + 0.5);
	if (k < 0.5) {
		// Skin: mottled, filthy in its hollows.
		float m = noise(local_pos.xy * 60.0 + local_pos.z * 40.0) * 0.6 + noise(local_pos.zy * 170.0) * 0.4;
		c *= 0.82 + 0.3 * m;
		c *= mix(0.45, 1.0, open);
		spec = 0.05;
		rough = 0.8;
		shine = 0.08;
	} else if (k < 1.5) {
		// A feather: barbs slanting out from the rachis towards the tip.
		float s = UV.x;
		float t = UV.y;
		float barbs = sin((s * 90.0 - abs(t) * 18.0 + seed * 40.0) * 1.0);
		float frayed = noise(vec2(s * 40.0, t * 3.0 + seed * 13.0));
		c *= 0.88 + 0.12 * barbs;
		c *= mix(1.0, 0.7, smoothstep(0.6, 1.0, abs(t)) * frayed);
		c = mix(c, c * 1.9 + vec3(0.02), (1.0 - smoothstep(0.0, 0.08, abs(t))) * 0.6);
		spec = 0.03;
		rough = 0.9;
	} else if (k < 2.5) {
		// Wet hair: a glint along it.
		float along = UV.x;
		c *= 0.8 + 0.4 * noise(vec2(seed * 50.0, along * 12.0));
		spec = 0.02;
		rough = 0.9;
		shine = 0.05;
	} else if (k < 3.5) {
		// Scales: rows of plates with dark seams.
		vec2 q = UV * vec2(9.0, 10.0);
		q.y += floor(q.x) * 0.5;
		vec2 f = fract(q);
		float seam = smoothstep(0.0, 0.12, f.x) * smoothstep(1.0, 0.85, f.x) * smoothstep(0.0, 0.1, f.y) * smoothstep(1.0, 0.8, f.y);
		c *= mix(0.45, 1.05, seam) * (0.85 + 0.3 * hash(floor(q)));
		spec = 0.05;
		rough = 0.8;
	} else if (k < 4.5) {
		// Horn: black, glossy.
		spec = 0.15;
		rough = 0.6;
		shine = 0.4;
	} else if (k < 5.5) {
		// The eyes: milky, dull, wet.
		spec = 0.9;
		rough = 0.12;
		glow = 0.12;
		shine = 0.7;
	} else if (k < 6.5) {
		c *= 0.8;
	} else if (k < 7.5) {
		spec = 0.1;
		rough = 0.7;
	} else {
		// Plumage: small coverts in shingled rows, each a rounded tip with a dark edge.
		vec2 q = UV * vec2(1.0 / 0.024, 1.0 / 0.03);
		q.x += floor(q.y) * 0.5;
		vec2 f = fract(q);
		vec2 id = floor(q);
		float tip = length(vec2((f.x - 0.5) * 1.2, f.y * 0.9));
		float edge = smoothstep(0.42, 0.55, tip);
		float barbs = sin(f.x * 30.0 + f.y * 8.0);
		c = c * (0.8 + 0.5 * hash(id)) * (1.0 - edge * 0.55) * (0.92 + 0.08 * barbs);
		c *= mix(0.6, 1.0, open);
		rough = 0.85;
	}
	ALBEDO = c * tone;
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
	float lit = cut(facing, 0.05) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
	// A soft glint (wet skin and hair, glossy horn, the eyes).
	vec3 half_way = normalize(LIGHT + VIEW);
	float gloss = pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 32.0);
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
