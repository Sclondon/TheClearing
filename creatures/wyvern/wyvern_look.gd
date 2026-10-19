class_name WyvernLook
## How a Wyvern (creatures/wyvern/wyvern.gd) is shaded: one material over its
## model (creatures/wyvern/models/wyvern.glb, built by tools/build_wyvern.py),
## one for its nest (WyvernNest), and the one for the shadow it throws on the
## ground under it.
##
## The model says what each vertex is in UV2.x (see build_wyvern.py: scales,
## membrane, horn, belly plates, eye, mouth, claw or tooth, bare skin), with a
## random number per piece in UV2.y; its colour is the vertex colour, and the
## alpha of that is how open it is (scales, skin: 0 deep in a hollow) or how thin
## (membrane: 1 at the free edge). This draws, from those:
## - scales: small overlapping scales in rows, each a little paler at its middle
##   and dark at its edges, weathered: blotched, scuffed paler here and there;
## - membrane: leathery, dark, creased and veined, old: scarred, and torn ragged
##   at the trailing edge (a few nicks and holes); thin, so that light from
##   behind shines through it, a dull warm grey;
## - horn: pale, ridged in rings along its length, darker towards the tip;
## - belly plates: broad bands across, paler;
## - the eye a dull amber gleam in the dark; the mouth dark; claws and teeth
##   glossy; bare skin dark and pebbled.
## Lit in soft cel bands with a rim, so it sits with a cel-shaded cast; drawn
## from both sides (the membranes are single sheets).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.26;
// How much light comes through the membranes from behind.
uniform float translucency = 0.5;
// How dark, each its own.
instance uniform float tone = 1.0;

varying float kind;
varying float seed;
varying float thin;
varying vec2 place;
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
	thin = COLOR.a;
	place = UV;
}

// Scales in staggered rows: 1 at a scale's middle, 0 at its edge.
float scales(vec2 p) {
	vec2 g = p;
	g.x += 0.5 * mod(floor(g.y), 2.0);
	vec2 f = fract(g) - 0.5;
	return 1.0 - smoothstep(0.18, 0.5, length(f * vec2(1.0, 1.25)));
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
		// Scales, weathered.
		float s = scales(vec2(place.x * 34.0, place.y * 7.0));
		c *= 0.72 + 0.4 * s;
		float blotch = noise(place * vec2(6.0, 2.0) + seed * 9.0);
		c *= 0.85 + 0.3 * blotch;
		c = mix(c, c * 1.5 + 0.02, smoothstep(0.78, 0.9, noise(place * vec2(17.0, 5.0))) * 0.5);
		c *= mix(0.55, 1.0, open);
		rough = 0.85;
		spec = 0.05;
		shine = 0.04 * s;
	} else if (k < 1.5) {
		// Membrane: creases across it, veins out along it, old scars; ragged at the trailing edge.
		float tear = noise(vec2(place.x * 70.0 + seed * 5.0, place.y * 6.0));
		float holes = noise(vec2(place.x * 23.0, place.y * 9.0 + 3.0));
		if ((place.y > 0.86 && tear > mix(0.95, 0.62, smoothstep(0.86, 1.0, place.y))) || (place.y > 0.45 && place.y < 0.9 && holes > 0.965)) {
			discard;
		}
		float veins = noise(vec2(place.x * 60.0, place.y * 5.0));
		float creases = noise(vec2(place.x * 9.0 + place.y * 3.0, place.y * 45.0));
		c *= 0.84 + 0.18 * veins + 0.14 * creases;
		c *= 0.9 + 0.2 * noise(place * vec2(14.0, 11.0));
		// (darker near the arm, where it is thick)
		c *= mix(0.72, 1.05, thin);
		rough = 0.8;
		spec = 0.06;
		shine = 0.05;
	} else if (k < 2.5) {
		// Horn: ringed along its length, darker at the tip.
		float rings = noise(vec2(place.x * 90.0, place.y * 4.0));
		c *= (0.82 + 0.25 * rings) * mix(1.0, 0.55, smoothstep(0.55, 1.0, place.x));
		rough = 0.6;
		spec = 0.08;
		shine = 0.08;
	} else if (k < 3.5) {
		// Belly plates: broad bands across.
		float band = fract(place.x * 22.0);
		c *= 0.78 + 0.3 * smoothstep(0.0, 0.25, band) * (1.0 - smoothstep(0.8, 1.0, band));
		c *= mix(0.6, 1.0, open);
		rough = 0.75;
	} else if (k < 4.5) {
		// The eye: a dull amber gleam.
		c = vec3(0.22, 0.15, 0.06);
		spec = 0.9;
		rough = 0.1;
		glow = 0.25;
		shine = 0.8;
	} else if (k < 5.5) {
		c *= 0.8;
	} else if (k < 6.5) {
		// Claws and teeth: glossy.
		spec = 0.2;
		rough = 0.5;
		shine = 0.3;
	} else {
		// Bare skin: dark, pebbled.
		c *= 0.85 + 0.25 * noise(place * vec2(60.0, 40.0));
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
	float k = floor(kind + 0.5);
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
	// The membranes: light from behind comes through, warm, most where they are thin.
	if (k > 0.5 && k < 1.5) {
		float behind = clamp(-dot(NORMAL, LIGHT), 0.0, 1.0);
		float through = behind * mix(0.35, 1.0, thin) * translucency;
		DIFFUSE_LIGHT += through * strength * LIGHT_COLOR * vec3(1.0, 0.86, 0.72) * 0.55 / PI;
	}
	vec3 half_way = normalize(LIGHT + VIEW);
	float gloss = pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 32.0);
	SPECULAR_LIGHT += smoothstep(0.3, 0.7, gloss) * shine * strength * LIGHT_COLOR * lit;
}
"""

## The nest: sticks and branches, bones and skulls, by vertex colour, in the same soft cel light.
const NEST_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.5;

varying vec3 spot;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	spot = VERTEX;
}

void fragment() {
	// (grain along the sticks; the bones a little mottled)
	float grain = hash(floor(spot * vec3(40.0, 40.0, 40.0)));
	ALBEDO = COLOR.rgb * (0.85 + 0.25 * grain);
	ROUGHNESS = 0.95;
	SPECULAR = 0.02;
}

void light() {
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = smoothstep(0.03, 0.08, facing) * mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(clamp(ATTENUATION, 0.0, 1.0), 1.0, 0.6) : clamp(ATTENUATION, 0.0, 1.0);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
}
"""

## The shadow on the ground: the shape of a wyvern seen from below (the broad
## wings scalloped between their fingers, the body, the long neck and the horned
## head, the long tail and its barb), soft at its edges. The quad it is drawn on
## spans the wings, its +Z (UV.y towards 0) the way it is going. `strength` how
## dark; `spread` how far the wings are open (0 folded for a dive).
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

instance uniform float strength = 1.0;
instance uniform float spread = 1.0;
instance uniform float blur = 0.0;

float band(float x, float a, float b, float soft) {
	return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x));
}

void fragment() {
	// (x across the wings, -1..1; y along the body, -1 the tail's end .. 1 ahead of the snout)
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float soft = 0.02 + blur * 0.1;
	float ax = abs(p.x);
	float span = mix(0.3, 0.98, spread);
	float out_t = clamp(ax / span, 0.0, 1.0);
	// The wings: the leading edge swept back a little, the trailing edge scalloped between the fingers.
	float lead = 0.08 - ax * mix(0.3, 0.12, spread);
	float chord = mix(0.36, 0.05, out_t) * (1.0 - 0.28 * abs(sin(out_t * 3.14159 * 2.6))) * mix(0.5, 1.0, spread);
	float wing = band(p.y, lead - chord, lead, soft) * (1.0 - smoothstep(span - soft * 2.0, span, ax));
	// The body, the neck and the head, the tail and its barb.
	float body = 1.0 - smoothstep(1.0 - soft * 8.0, 1.0, length(vec2(p.x / 0.07, (p.y + 0.02) / 0.17)));
	float neck = band(p.y, 0.1, 0.42, soft) * (1.0 - smoothstep(0.022, 0.022 + soft * 0.6, ax));
	float head = band(p.y, 0.38, 0.57, soft) * (1.0 - smoothstep(0.03, 0.03 + soft * 0.6, ax));
	float horns = band(p.y, 0.36, 0.42, soft) * band(ax, 0.02, 0.05, soft);
	float tail_w = mix(0.03, 0.006, smoothstep(-0.15, -0.86, p.y));
	float tail = band(p.y, -0.86, -0.1, soft) * (1.0 - smoothstep(tail_w, tail_w + soft * 0.6, ax));
	float barb_w = 0.04 * (1.0 - abs(p.y + 0.9) / 0.06);
	float barb = band(p.y, -0.96, -0.84, soft) * (1.0 - smoothstep(barb_w, barb_w + soft * 0.6, ax));
	float shape = clamp(max(max(max(wing, body), max(neck, head)), max(max(tail, barb), horns)), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = shape * strength * 0.85;
}
"""

static var _material: ShaderMaterial
static var _nest: ShaderMaterial
static var _shadow: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func nest_material() -> ShaderMaterial:
	if _nest == null:
		var shader := Shader.new()
		shader.code = NEST_SHADER
		_nest = ShaderMaterial.new()
		_nest.shader = shader
	return _nest


static func shadow_material() -> ShaderMaterial:
	if _shadow == null:
		var shader := Shader.new()
		shader.code = SHADOW_SHADER
		_shadow = ShaderMaterial.new()
		_shadow.shader = shader
	return _shadow
