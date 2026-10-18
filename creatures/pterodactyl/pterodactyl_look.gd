class_name PterodactylLook
## How a Pterodactyl (creatures/pterodactyl/pterodactyl.gd) is shaded: one
## material over its model (creatures/pterodactyl/models/pterodactyl.glb, built
## by tools/build_pterodactyl.py), and the one for the shadow it throws on the
## ground under it.
##
## The model says what each vertex is in UV2.x (see build_pterodactyl.py: fur,
## membrane, beak, crest, eye, mouth, claw, bare skin), with a random number
## per piece in UV2.y; its colour is the vertex colour, and the alpha of that
## is how open it is (fur, skin: 0 deep in a hollow) or how thin (membrane: 1
## at the free edge). This draws, from those:
## - fur (pycnofibres): short dense hair-like filaments lying back along the
##   body, in fine streaks, darker in the hollows, with a soft fuzzy rim of
##   light at the edges of the body;
## - membrane: leathery, dark, with fine creases and the stiffening fibres
##   (actinofibrils) running out along the wing; thin, so that light from behind
##   shines through it (most at the trailing edge), a dull warm grey;
## - beak: horn, pale, faintly ridged along its length, with a dull sheen;
## - crest: dark, with faint streaks running back along it;
## - the eye black and wet; the mouth dark; claws black and glossy; bare skin dark and pebbled.
## Lit in soft cel bands with a rim, so it sits with a cel-shaded cast; drawn
## from both sides (the membranes are single sheets).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.28;
// How much light comes through the membranes from behind.
uniform float translucency = 0.55;
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

void fragment() {
	vec3 c = COLOR.rgb;
	float open = COLOR.a;
	float rough = 1.0;
	float spec = 0.0;
	float glow = 0.0;
	shine = 0.0;
	float k = floor(kind + 0.5);
	if (k < 0.5) {
		// Fur: fine streaks lying back along the body, and a fuzz.
		float streak = noise(vec2(place.x * 9.0, place.y * 140.0)) * 0.6 + noise(vec2(place.x * 30.0, place.y * 380.0)) * 0.4;
		c *= 0.75 + 0.5 * streak;
		c *= mix(0.55, 1.0, open);
		rough = 0.95;
	} else if (k < 1.5) {
		// Membrane: creases across it, the fibres out along it.
		float fibres = noise(vec2(place.x * 70.0, place.y * 7.0));
		float creases = noise(vec2(place.x * 9.0 + place.y * 3.0, place.y * 45.0));
		c *= 0.86 + 0.18 * fibres + 0.12 * creases;
		// (darker near the arm, where it is thick)
		c *= mix(0.75, 1.05, thin);
		rough = 0.8;
		spec = 0.06;
		shine = 0.05;
	} else if (k < 2.5) {
		// The beak: horn, faintly ridged along its length.
		float ridges = noise(vec2(place.x * 40.0, place.y * 300.0));
		c *= 0.9 + 0.15 * ridges;
		rough = 0.55;
		spec = 0.08;
		shine = 0.07;
	} else if (k < 3.5) {
		// The crest: dark, streaked back along it.
		c *= 0.85 + 0.25 * noise(vec2(place.x * 60.0, place.y * 12.0));
		rough = 0.7;
		spec = 0.1;
		shine = 0.08;
	} else if (k < 4.5) {
		// The eye: black, wet.
		spec = 0.9;
		rough = 0.1;
		glow = 0.05;
		shine = 0.8;
	} else if (k < 5.5) {
		c *= 0.8;
	} else if (k < 6.5) {
		// Claws: black, glossy.
		spec = 0.2;
		rough = 0.5;
		shine = 0.35;
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
	// (fur is fuzzy at its edges: a broader, softer rim)
	float fuzz = k < 0.5 ? 1.4 : 1.0;
	float rim = cut(graze, 1.0 - rim_width * fuzz) * lit;
	SPECULAR_LIGHT += rim * rim_gain * fuzz * ALBEDO * strength * LIGHT_COLOR / PI;
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

## The shadow on the ground: the shape of a pterosaur seen from below (a body,
## the long head and crest, the narrow wings swept back a little), soft at its
## edges, dark in the middle. The quad it is drawn on spans the wings, its +Z
## (UV.y towards 0) the way it is going. `strength` how dark; `spread` how far
## the wings are open (0 folded for a dive: a narrow arrow).
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
	// (x across the wings, -1..1; y along the body, -1 its tail .. 1 its beak)
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float soft = 0.025 + blur * 0.12;
	float ax = abs(p.x);
	float span = mix(0.32, 0.98, spread);
	// The wings: a leading edge swept back a little, a trailing edge curving in to the body.
	float lead = 0.12 - ax * mix(0.42, 0.18, spread);
	float trail = lead - mix(0.2, 0.42, smoothstep(span, 0.0, ax) * spread + 0.15) * (1.0 - smoothstep(0.0, span, ax) * 0.75);
	float wing = band(p.y, trail, lead, soft) * (1.0 - smoothstep(span - soft * 2.0, span, ax));
	// The body (a short spindle), the neck and the long wedge of the head, the crest behind it.
	float body = 1.0 - smoothstep(1.0 - soft * 8.0, 1.0, length(vec2(p.x / 0.045, (p.y + 0.05) / 0.2)));
	float neck = band(p.y, 0.1, 0.42, soft) * (1.0 - smoothstep(0.008, 0.008 + soft * 0.6, ax));
	float wedge = 0.022 * (1.0 - smoothstep(0.42, 0.98, p.y));
	float head = band(p.y, 0.36, 0.98, soft) * (1.0 - smoothstep(wedge, wedge + soft * 0.6, ax));
	float shape = clamp(max(max(wing, body), max(neck, head)), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = shape * strength * 0.85;
}
"""

static var _material: ShaderMaterial
static var _shadow: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func shadow_material() -> ShaderMaterial:
	if _shadow == null:
		var shader := Shader.new()
		shader.code = SHADOW_SHADER
		_shadow = ShaderMaterial.new()
		_shadow.shader = shader
	return _shadow
