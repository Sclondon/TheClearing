class_name GargoyleLook
## How a Gargoyle (creatures/gargoyle/gargoyle.gd) is shaded: weathered cast
## stone, one material for every gargoyle (each one's own state goes in
## instance uniforms).
##
## The model (built by tools/build_gargoyle.py) carries where each point stood
## at rest (UV: x, y; UV2.x: z), so the stone is laid on in the model's own
## space and stays put on it however it moves; how far each point lies in a
## hollow (UV2.y); and masks as vertex colour (R the dark inside the mouth and
## nostrils, G the eyes, B the skin of the wings).
##
## - THE STONE is the maze's cast concrete (textures/gargoyle_stone.png, from
##   Poly Haven's concrete_wall_007, CC0), laid on from three sides and given
##   relief from its own grain; darker and greener in every hollow (grime and
##   moss), moss on what faces up, rain stains running down, and a scatter of
##   pale chips where it has been knocked. Lit as the walls are (no cel bands),
##   so that a still one cannot be told from the carvings round it.
## - CRACKS run over it all, hairline and branching. As stone they are only
##   dark lines; alive (`life`), a faint ember glows deep in them, spreading
##   from its heart outward as it wakes and going out again as it sets, and
##   brighter while it strains (`strain`); its eyes kindle.
## - THE WINGS' SKIN is the same stone, thinner and a little darker.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D stone_map : source_color, filter_linear_mipmap, repeat_enable;
// Metres one tile of the stone covers.
uniform float tile = 1.1;
uniform vec3 tint : source_color = vec3(0.74, 0.74, 0.72);
uniform vec3 grime : source_color = vec3(0.24, 0.23, 0.2);
uniform vec3 moss : source_color = vec3(0.25, 0.27, 0.19);
uniform vec3 ember : source_color = vec3(1.0, 0.36, 0.08);
uniform float relief = 1.0;
uniform float weathering = 1.0;
// 0: stone. 1: alive (the cracks and eyes glow).
instance uniform float life = 0.0;
// How hard it is working now (0..1): the cracks glow brighter.
instance uniform float strain = 0.0;
// Each one a little lighter or darker.
instance uniform float tone = 1.0;

varying vec3 rest;
varying float hollow;
varying vec3 mask;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// How near a point is to the edge between two cells of a scatter of points
// (a crazing of cracks, as dried stone breaks): the gap between the nearest
// and the next nearest, small on an edge.
float edges(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = vec2(hash3(vec3(cell + o, 1.7)), hash3(vec3(cell + o, 9.3)));
			float d = length(o + h - f);
			if (d < first) { second = first; first = d; } else if (d < second) { second = d; }
		}
	}
	return second - first;
}

void vertex() {
	rest = vec3(UV.x, UV.y, UV2.x);
	hollow = UV2.y;
	mask = COLOR.rgb;
}

// Bump from a height (metres), by its change across the screen (no tangents needed).
vec3 bumped(vec3 n, vec3 pos, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad);
}

void fragment() {
	// Which way the surface faced at rest, from how the rest position changes across the screen.
	vec3 rn = normalize(cross(dFdx(rest), dFdy(rest)));
	if (dot(rn, rn) < 0.5) { rn = vec3(0.0, 1.0, 0.0); }
	vec3 w = pow(abs(rn), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 a = texture(stone_map, rest.zy / tile).rgb;
	vec3 b = texture(stone_map, rest.xz / tile + 0.37).rgb;
	vec3 c = texture(stone_map, rest.xy / tile + 0.71).rgb;
	vec3 stone = a * w.x + b * w.y + c * w.z;
	float grain = dot(stone, vec3(0.333));

	// Broad changes of tone, and the stone's own.
	float broad = noise3(rest * 2.3) * 0.6 + noise3(rest * 6.0 + 7.0) * 0.4;
	vec3 colour = stone * tint * tone * (0.86 + 0.28 * broad);
	// Up-facing (as it stood) and in the hollows: moss and grime.
	float up = abs(rn.y) * step(0.0, rn.y + 0.2);
	float patch = noise3(rest * 11.0 + 3.0);
	float mossy = smoothstep(0.55, 0.85, hollow * 0.8 + patch * 0.5) + smoothstep(0.75, 0.95, up) * smoothstep(0.45, 0.7, patch) * 0.8;
	colour = mix(colour, colour * grime * 2.4, smoothstep(0.2, 0.9, hollow) * 0.75 * weathering);
	colour = mix(colour, moss * (0.7 + 0.6 * grain), clamp(mossy, 0.0, 1.0) * 0.5 * weathering);
	// Rain stains: dark drips running down it.
	float drips = noise3(vec3(rest.x * 38.0, rest.y * 2.2, rest.z * 38.0));
	float stain = smoothstep(0.55, 0.85, drips) * smoothstep(0.35, 0.75, noise3(rest * 3.0 + 11.0));
	colour *= 1.0 - 0.3 * stain * weathering;
	// Chips: pale fresh stone where it has been knocked.
	vec3 warp = vec3(noise3(rest * 31.0), noise3(rest * 31.0 + 17.0), noise3(rest * 31.0 + 29.0)) - 0.5;
	float chip = smoothstep(0.84, 0.9, noise3(rest * 13.0 + warp * 1.6 + 41.0)) * (1.0 - hollow) * smoothstep(0.4, 0.7, noise3(rest * 3.0 + 5.0));
	colour = mix(colour, colour * 1.18 + 0.02, chip * 0.6);

	// Cracks: hairlines where a ridged noise crosses its middle, branching at two sizes.
	// (laid on the side it most faces, jittered so they run jagged; only here and there)
	vec2 plane = w.x > w.y && w.x > w.z ? rest.zy : (w.y > w.z ? rest.xz : rest.xy);
	plane += warp.xy * 0.035;
	float e1 = edges(plane * 6.0);
	float e2 = edges(plane * 15.0 + 3.1);
	float crack = max((1.0 - smoothstep(0.0, fwidth(e1) * 1.2 + 0.015, e1)) * smoothstep(0.45, 0.6, noise3(rest * 2.2 + 2.0)),
		(1.0 - smoothstep(0.0, fwidth(e2) * 1.0 + 0.02, e2)) * smoothstep(0.55, 0.7, noise3(rest * 3.1 + 9.0)) * 0.8);
	colour *= 1.0 - 0.42 * crack;

	// The dark of its mouth and nostrils; its eyes.
	colour = mix(colour, vec3(0.03, 0.025, 0.02), mask.r);
	colour = mix(colour, colour * 0.35, mask.g);
	// (the skin of the wings a little darker)
	colour *= 1.0 - 0.12 * mask.b;
	ALBEDO = colour;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;

	float height = (grain - 0.5) * 0.004 - crack * 0.0015 - chip * 0.001;
	NORMAL = bumped(NORMAL, VERTEX, height * relief);

	// Alive: the ember in the cracks, spreading out from the heart as it wakes.
	float from_heart = length(rest - vec3(0.0, 1.1, 0.05)) / 1.6 + noise3(rest * 3.0) * 0.25;
	float lit = smoothstep(from_heart - 0.15, from_heart + 0.05, life * 1.25);
	float flicker = 0.75 + 0.25 * noise3(rest * 5.0 + vec3(0.0, TIME * 0.8, 0.0));
	float glow = crack * lit * (0.2 + 0.8 * strain) * flicker * (1.0 - mask.r);
	vec3 eyes = ember * mask.g * smoothstep(0.2, 0.7, life) * 2.2;
	EMISSION = ember * glow * 0.32 + eyes;
}
"""

const STONE_MAP := "res://creatures/gargoyle/textures/gargoyle_stone.png"

static var _material: ShaderMaterial


## The one material every gargoyle shares.
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter(&"stone_map", load(STONE_MAP))
	return _material
