class_name OctopusLook
## How the giant octopus is shaded (creatures/octopus): one material for its
## skinned body (and the same, writhing, for an arm cut off it). Cel shaded as
## the rest of the cast is (two flat tones with a one-pixel edge, shadows only
## dimming, a rim of light at grazing angles), and WET: a hard little highlight
## that slides over it as it moves.
##
## ITS SKIN CHANGES. Lying still it takes the tone and the grain of what it is
## on (`camouflage`, 0..1 how far it has given that up: its instance uniform
## `reveal`), point by point: low down, the floor's (`floor_tone`, mud), higher
## up, the walls' (`wall_tone`, stone grey: an arm feeling up a wall goes grey
## as it climbs), and in its water, the water's (`water_tone`, black). Over that
## it lays a mottle of blotches and specks about the size of the ground's own,
## and its gloss is dulled. `papillae` (0..1) raises the little horns and bumps
## of its skin (they stand up when it is about to strike, and when it is calm
## and hidden: a rough patch of mud that is not quite mud). `waves` sends dark
## clouds rolling over it (as a real octopus does when it is agitated, a tell),
## and `flush` (-1..1) floods it dark or pale (blanching pale as it winds up,
## dark as it strikes). Revealed it is its own colour: a dull reddish-brown,
## darker and mottled on the back, pale underneath, the suckers a pale cream.
##
## What a point is comes from the model (creatures/octopus/tools/build_octopus.py):
## its first UV says what part it is (x: 0 skin, 1 sucker, 2 eye, 3 the dark of
## the mouth and siphon, 4 web) and its rest height (y); its second UV is its
## rest x and z (so the mottling stays put on it as it moves), and on an eye
## where on the eye the point is. Its vertex colour: red how open it is (dark in
## the creases), green how far on its underside (on a sucker, its rim), blue how
## far out along an arm. The eye is painted here: a pale gold-grey iris, flecked,
## with a dark ring, and the horizontal slit of a pupil.

const COMMON := """
uniform float wrap = 0.35;
uniform float flatness = 0.65;
uniform float rim_gain = 0.28;
uniform float rim_width = 0.2;
uniform float gloss = 420.0;
uniform float shine = 0.22;

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// ROUGHNESS carries how wet a point is to light() (1 - wet).
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
	SPECULAR_LIGHT += rim * rim_gain * (0.4 + 0.6 * wet) * ALBEDO * 1.3 * strength * LIGHT_COLOR / PI;
	float h = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float spot = cut(pow(h, gloss), 0.5) + 0.07 * cut(pow(h, gloss * 0.2), 0.6);
	SPECULAR_LIGHT += spot * wet * shine * strength * LIGHT_COLOR * smoothstep(0.0, 0.3, reach + 0.2);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Little horns and bumps of skin: 1 at the tip of one, 0 between (cells, as warts are).
float papilla(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	for (int z = 0; z <= 1; z++) {
		for (int y = 0; y <= 1; y++) {
			for (int x = 0; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash3(i + g), hash3(i + g + 17.0), hash3(i + g + 31.0));
				vec3 d = g + o - f;
				best = min(best, dot(d, d) * (0.6 + 0.8 * hash3(i + g + 5.0)));
			}
		}
	}
	return clamp(1.0 - best * 3.0, 0.0, 1.0);
}
"""

const SHADER := """
shader_type spatial;
render_mode cull_back;

// How far it has given up its camouflage (0 hidden, 1 its own colours), its flush (-1 dark .. 1 pale),
// how far its papillae stand up, how much dark rolls over it, and how much it writhes (a cut-off arm).
instance uniform float reveal = 0.0;
instance uniform float flush = 0.0;
instance uniform float papillae = 0.0;
instance uniform float waves = 0.0;
instance uniform float writhe = 0.0;
instance uniform float blink = 0.0;
// What it takes on: the floor low down, the walls higher, its water (xyz its middle at the surface, w how far; w < 0 none).
instance uniform vec3 floor_tone : source_color = vec3(0.16, 0.145, 0.125);
instance uniform vec3 wall_tone : source_color = vec3(0.4, 0.4, 0.38);
instance uniform vec3 water_tone : source_color = vec3(0.035, 0.045, 0.045);
instance uniform vec4 water = vec4(0.0, 0.0, 0.0, -1.0);
instance uniform float floor_y = 0.0;

uniform vec3 own : source_color = vec3(0.29, 0.235, 0.205);
uniform vec3 pale : source_color = vec3(0.76, 0.72, 0.66);
uniform vec3 dark : source_color = vec3(0.06, 0.04, 0.035);
uniform vec3 sucker : source_color = vec3(0.66, 0.6, 0.53);
uniform vec3 iris : source_color = vec3(0.62, 0.55, 0.38);
uniform vec3 iris_dark : source_color = vec3(0.22, 0.18, 0.12);

varying flat float part;
varying vec3 rest;
varying vec3 world;
varying float facing;

#COMMON

void vertex() {
	part = UV.x;
	// (the export turns texture coordinates upside down: v is 1 - v)
	facing = 1.0 - UV.y;
	rest = vec3(UV2.x, 1.0 - UV.y, 1.0 - UV2.y);
	int kind = int(round(part));
	if (kind == 0 || kind == 4) {
		// (the papillae: the arms' finer towards the tip, none on the underside)
		float bump = papilla(rest * mix(7.0, 16.0, COLOR.b));
		VERTEX += NORMAL * bump * papillae * mix(0.045, 0.012, COLOR.b) * (1.0 - COLOR.g);
	}
	if (writhe > 0.0) {
		float t = COLOR.b;
		VERTEX += vec3(sin(TIME * 6.0 - t * 9.0), 0.25 * sin(TIME * 4.3 - t * 7.0), cos(TIME * 5.1 - t * 8.0)) * writhe * t * 0.35;
	}
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The eye: a pale gold-grey iris, flecked, a dark ring, the horizontal slit of a pupil; the back of it dark;
// the lids (skin) drawn over it in a blink.
vec3 eye_colour(vec2 at, float toward, float shut, vec3 lid) {
	float r = length(at);
	float pixel = max(fwidth(r), 0.002);
	vec3 c = mix(iris_dark, iris, smoothstep(0.98, 0.35, r));
	c *= 0.78 + 0.32 * hash3(floor(vec3(at * 16.0, 3.0)));
	// (a bar of a pupil, wider in the middle: an octopus keeps it level)
	float pupil = length(at / vec2(0.58, 0.13 + 0.06 * (1.0 - abs(at.x) / 0.58)));
	float pp = max(fwidth(pupil), 0.002);
	c = mix(vec3(0.012, 0.01, 0.01), c, smoothstep(1.0 - pp, 1.0 + pp, pupil));
	c = mix(c, vec3(0.05, 0.04, 0.03), smoothstep(0.84 - pixel, 0.95 + pixel, r));
	c = mix(iris_dark * 0.5, c, smoothstep(-0.3, 0.1, toward));
	float lp = max(fwidth(at.y), 0.002);
	float open = 1.0 - shut;
	return mix(c, lid, 1.0 - smoothstep(-open - lp, -open + lp, at.y) + smoothstep(open - lp, open + lp, at.y));
}

void fragment() {
	int kind = int(round(part));
	float hollow = COLOR.r;
	float under = COLOR.g;
	float along = COLOR.b;
	// What it is on, here: the floor low down, the walls higher up, its water.
	float high = world.y - floor_y;
	vec3 env = mix(floor_tone, wall_tone, smoothstep(0.35, 1.3, high));
	if (water.w > 0.0) {
		float wet_in = 1.0 - smoothstep(water.w * 0.75, water.w, length(world.xz - water.xz));
		env = mix(env, water_tone, wet_in * (1.0 - smoothstep(0.05, 0.45, world.y - water.y)));
	}
	// Its camouflage: that tone, in blotches and specks about the ground's size.
	float blotch = noise3(rest * 2.3) * 0.6 + noise3(rest * 5.7) * 0.4;
	float speck = noise3(rest * 17.0);
	vec3 hidden = env * (0.72 + 0.5 * blotch) * (0.9 + 0.2 * speck);
	// Its own: dull reddish-brown, darker and mottled on the back, pale under it.
	vec3 mine = own * (0.62 + 0.62 * blotch) * (0.92 + 0.16 * speck);
	mine = mix(mine, pale * 0.82, smoothstep(0.35, 0.9, under) * 0.75);
	float bump = papilla(rest * mix(7.0, 16.0, along));
	vec3 colour = mix(hidden, mine, reveal);
	// (the tips of the papillae a touch paler, more so when they stand up)
	colour *= 1.0 + bump * (0.08 + 0.25 * papillae) * (1.0 - under);
	float wet = mix(0.45, 0.9, reveal);
	if (kind == 1) {
		vec3 cup = mix(sucker * 0.45, sucker, under);
		colour = mix(mix(env * 1.1, env * 0.6, 1.0 - under), cup, max(reveal, 0.1));
		wet = 0.95;
	} else if (kind == 2) {
		vec3 lid = colour * 0.8;
		colour = eye_colour(vec2(UV2.x, 1.0 - UV2.y), facing, blink, lid);
		wet = 1.0;
	} else if (kind == 3) {
		colour = vec3(0.02, 0.015, 0.012);
		wet = 0.8;
	}
	if (kind != 2) {
		// Dark clouds rolling over it, agitated; and its flush.
		float roll = sin(rest.x * 2.1 + rest.z * 1.3 + along * 11.0 - TIME * 6.5) * 0.5 + 0.5;
		roll *= sin(rest.z * 1.7 - rest.x * 0.9 + along * 5.0 - TIME * 3.1) * 0.5 + 0.5;
		colour = mix(colour, dark, smoothstep(0.25, 0.55, roll) * waves * 0.75);
		colour = mix(colour, flush > 0.0 ? pale : dark, abs(flush));
		colour *= mix(0.45, 1.0, hollow);
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0 - wet;
	SPECULAR = 0.0;
}
"""

static var _material: ShaderMaterial


## Its material (one for every octopus: what differs between them is their instance uniforms).
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER.replace("#COMMON", COMMON)
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


## Puts its material on every mesh of `model`.
static func dress(model: Node) -> void:
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(s, material())
