class_name FrogLook
## How the frogs are shaded (creatures/frog): one material for the giant toad
## (GiantToad, a skinned mesh), one for the swarm's little frogs (FrogSwarm,
## one MultiMesh). Both are cel shaded as the rest of the cast is (two flat
## tones with a one-pixel edge, shadows only dimming, a rim of light at
## grazing angles) and both are WET: a hard little highlight that slides over
## them as they turn, broken up by their warts, and a brighter rim.
##
## What a point is comes from the model (creatures/frog/tools/build_frogs.py):
## its first UV says what part it is (x: 0 skin, 1 eye, 2 mouth, 3 tongue) and
## on the skin, y is its height at rest; its second UV is, on the skin, its x
## and z at rest (so the fine warts painted here stay put on it as it moves),
## and on an eye where on the eye the point is (across and up, as seen from the
## way the eye looks; y of the first UV how far it faces that way). The eye is
## painted here: a gold iris with dark flecks and a dark rim, and a horizontal
## pupil; a blink draws the lower lid up over it.
##
## THE TOAD: colours are the model's vertex colours (muddy olive and brown,
## darker blotches, pale belly and throat, ochre wart tips, the pink mouth),
## times `tint` (an instance uniform: each toad a little different). Fine
## warts are added in the shader, as bumps lit as the big ones are.
##
## THE SWARM: each frog's colour comes from a palette, chosen by its seed
## (INSTANCE_CUSTOM.z): muddy greens, browns, ochre, a sickly yellow-green, a
## grey; the model's colours give only how light each point is (belly, bands,
## blotches: in CUSTOM0.w, as FrogSwarm builds the mesh). The poses are blended
## in the vertex shader: INSTANCE_CUSTOM.x how far into the leap (the hind
## legs thrown out behind: CUSTOM0.xyz is how far each point moves for it),
## y how far the throat is blown up (CUSTOM1.xyz), w a kick of the legs (when
## it clings or tumbles).

const COMMON := """
uniform float wrap = 0.35;
uniform float flatness = 0.65;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.2;
uniform float gloss = 160.0;
uniform float shine = 0.32;
uniform vec3 iris : source_color = vec3(0.78, 0.52, 0.12);
uniform vec3 iris_dark : source_color = vec3(0.32, 0.16, 0.03);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Cells of warts: how near the middle of the nearest wart a point is (1 at its top, 0 between them).
float warts(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash3(i + g), hash3(i + g + 17.0), hash3(i + g + 31.0));
				vec3 d = g + o * 0.8 + 0.1 - f;
				best = min(best, dot(d, d) * (0.7 + 0.6 * hash3(i + g + 5.0)));
			}
		}
	}
	return clamp(1.0 - best * 2.2, 0.0, 1.0);
}

// The eye, from where on it a point is: a gold iris, flecked, with a dark rim and a horizontal pupil;
// the back of the eye dark; the lower lid drawn up over it as it blinks.
vec3 eye_colour(vec2 at, float toward, float shut, vec3 lid) {
	vec2 q = at;
	float r = length(q);
	float pixel = max(fwidth(r), 0.002);
	vec3 c = mix(iris_dark, iris, smoothstep(0.95, 0.35, r));
	c *= 0.75 + 0.35 * hash3(floor(vec3(q * 14.0, 1.0)));
	float pupil = length(q / vec2(0.5, 0.2));
	float pp = max(fwidth(pupil), 0.002);
	c = mix(vec3(0.015, 0.012, 0.01), c, smoothstep(1.0 - pp, 1.0 + pp, pupil));
	c = mix(c, vec3(0.05, 0.035, 0.02), smoothstep(0.82 - pixel, 0.92 + pixel, r));
	c = mix(iris_dark * 0.6, c, smoothstep(-0.35, 0.05, toward));
	float closed = mix(-1.3, 1.15, shut);
	float lp = max(fwidth(q.y), 0.002);
	return mix(c, lid, 1.0 - smoothstep(closed - lp, closed + lp, q.y));
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// ROUGHNESS carries how wet a point is to light() (1 - wet), as varyings do not reach it everywhere.
void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float turned = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(turned, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.78, 1.0, smoothstep(0.1, 0.85, turned));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float wet = 1.0 - ROUGHNESS;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * (0.5 + 0.5 * wet) * ALBEDO * 1.3 * strength * LIGHT_COLOR / PI;
	// The wet shine: one hard little highlight, and a fainter, broader one round it.
	float h = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float spot = cut(pow(h, gloss), 0.5) + 0.07 * cut(pow(h, gloss * 0.2), 0.6);
	SPECULAR_LIGHT += spot * wet * shine * strength * LIGHT_COLOR * smoothstep(0.0, 0.3, reach + 0.2);
}
"""

const TOAD_SHADER := """
shader_type spatial;
render_mode cull_back;

instance uniform vec3 tint = vec3(1.0);
instance uniform float blink = 0.0;
uniform float wart_scale = 26.0;
uniform float wetness = 1.0;

varying flat float part;
varying vec3 rest;
varying float facing;

#COMMON

void vertex() {
	part = UV.x;
	facing = UV.y;
	rest = vec3(UV2.x, UV.y, UV2.y);
}

void fragment() {
	int kind = int(round(part));
	vec3 colour = COLOR.rgb;
	float wet = 0.8;
	if (kind == 0) {
		colour *= tint;
		// Fine warts all over, between the big ones: little spots, darker round their feet and tipped paler.
		// (only their colour: bumps in the normal break the cel shading into scales)
		float w = warts(rest * wart_scale);
		float wpix = fwidth(w);
		// (far off, where they would only shimmer, they fade out)
		float near = 1.0 - smoothstep(0.25, 0.6, wpix);
		colour *= mix(1.0, 0.88 + 0.2 * w, near);
		wet = 0.85 * wetness;
	} else if (kind == 1) {
		vec3 lid = tint * vec3(0.2, 0.17, 0.08);
		colour = eye_colour(UV2, facing, blink, lid);
		wet = 1.0;
	} else if (kind == 2) {
		colour = COLOR.rgb;
		wet = 0.9;
	} else {
		colour = COLOR.rgb;
		wet = 1.0;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0 - wet;
	SPECULAR = 0.0;
}
"""

const SWARM_SHADER := """
shader_type spatial;
render_mode cull_back;

// The palette the frogs are coloured from, by each one's seed.
uniform vec3 colour_a : source_color = vec3(0.16, 0.2, 0.07);
uniform vec3 colour_b : source_color = vec3(0.24, 0.18, 0.08);
uniform vec3 colour_c : source_color = vec3(0.33, 0.29, 0.08);
uniform vec3 colour_d : source_color = vec3(0.27, 0.31, 0.1);
uniform vec3 colour_e : source_color = vec3(0.17, 0.17, 0.13);
uniform vec3 belly : source_color = vec3(0.55, 0.52, 0.35);

varying flat float part;
varying float facing;
varying vec3 rest;
varying float lightness;
varying float seed;

#COMMON

void vertex() {
	part = UV.x;
	facing = UV.y;
	rest = VERTEX;
	lightness = CUSTOM0.w;
	seed = INSTANCE_CUSTOM.z;
	float kick = sin(INSTANCE_CUSTOM.w) * 0.35 * step(0.001, abs(INSTANCE_CUSTOM.w));
	VERTEX += CUSTOM0.xyz * clamp(INSTANCE_CUSTOM.x + kick, 0.0, 1.2) + CUSTOM1.xyz * INSTANCE_CUSTOM.y;
}

void fragment() {
	int kind = int(round(part));
	float s = fract(seed * 7.31);
	vec3 base = s < 0.2 ? colour_a : (s < 0.4 ? colour_b : (s < 0.6 ? colour_c : (s < 0.8 ? colour_d : colour_e)));
	// (each a little lighter or darker, greener or browner)
	base *= 0.8 + 0.45 * fract(seed * 13.7);
	base = mix(base, base * vec3(1.1, 1.0, 0.75), fract(seed * 3.3));
	vec3 colour;
	float wet = 0.85;
	if (kind == 0) {
		// Dark spots, the bands and blotches of the model, and the pale belly.
		float spots = warts(rest * 9.0 + seed * 40.0);
		colour = base * (1.0 - 0.55 * smoothstep(0.35, 0.45, spots) * step(0.5, fract(seed * 5.1) + 0.3));
		colour *= mix(0.55, 1.15, smoothstep(0.08, 0.2, lightness));
		colour = mix(colour, belly * (0.85 + 0.3 * fract(seed * 2.9)), smoothstep(0.24, 0.4, lightness));
	} else if (kind == 1) {
		colour = eye_colour(UV2, facing, 0.0, base * 0.6);
		wet = 1.0;
	} else {
		colour = base * 0.25;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0 - wet;
	SPECULAR = 0.0;
}
"""

static var _toad: ShaderMaterial
static var _swarm: ShaderMaterial


## The giant toad's material (one for every toad: what differs between them is
## its instance uniforms `tint` and `blink`).
static func toad_material() -> ShaderMaterial:
	if _toad == null:
		var shader := Shader.new()
		shader.code = TOAD_SHADER.replace("#COMMON", COMMON)
		_toad = ShaderMaterial.new()
		_toad.shader = shader
	return _toad


## The swarm's material.
static func swarm_material() -> ShaderMaterial:
	if _swarm == null:
		var shader := Shader.new()
		shader.code = SWARM_SHADER.replace("#COMMON", COMMON)
		_swarm = ShaderMaterial.new()
		_swarm.shader = shader
	return _swarm
