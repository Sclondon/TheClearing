@tool
class_name MazeStone
## The materials of the maze: its walls and the ground.
##
## The walls are Outside's sandstone (scripts/sandstone.gd there: courses of
## blocks, joints, stains run down, cracks), turned grey and old, with ivy hung
## from their tops in curtains. The ground is grass in the clearing and out past
## the maze, and dirt between the walls: dry and cracked in places, damp, and mud,
## with stones in it, moss along the foot of the walls and puddles in its hollows
## that show the walls and the sky. It is all worked out from where in the world a
## point is (the dirt's close detail and its noise read from two small pictures,
## tools/make_mud_texture.gd), and fades out as it gets too small to draw, so that
## it does not shimmer far off.
##
## Both are lit as the figures are, in hard bands, with a little wrap.

const STONE := Color(0.4, 0.42, 0.39)
const IVY := Color(0.13, 0.23, 0.11)

const WALL_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.5, 0.5, 0.47);
uniform vec3 ivy : source_color = vec3(0.13, 0.23, 0.11);
uniform vec3 moss : source_color = vec3(0.2, 0.27, 0.13);
uniform vec3 wet : source_color = vec3(0.16, 0.19, 0.18);
uniform float banded = 1.0;
uniform float wrap = 0.2;
uniform float course = 2.4;
uniform float block = 5.5;
uniform float wear = 0.9;
uniform float cracks = 0.6;
// Whether joints are painted on (1), or the stone is built of blocks that are
// their own shapes, each in its own tone given as the vertex colour (0).
uniform float painted = 1.0;
// How tall the walls are, and how far down the ivy comes on average (0..1).
uniform float height = 34.0;
uniform float overgrown = 0.55;

varying vec3 place;
varying vec3 lie;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(whole), hash(whole + vec2(1.0, 0.0)), part.x),
			mix(hash(whole + vec2(0.0, 1.0)), hash(whole + vec2(1.0, 1.0)), part.x), part.y);
}

float seen(float size, float pixel) {
	return clamp(size * 0.4 / pixel - 0.2, 0.0, 1.0);
}

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lie = NORMAL;
}

void fragment() {
	vec3 facing = abs(normalize(lie));
	bool flat_top = facing.y > 0.92;
	vec2 at = flat_top ? place.xz : vec2(facing.x > facing.z ? place.z : place.x, place.y);
	float pixel = max(length(fwidth(place)), 0.0001);

	// The blocks, as in Outside's sandstone.
	float row = floor(at.y / course);
	float span = block * (0.75 + 0.6 * hash(vec2(row, 3.7)));
	float along = at.x / span + hash(vec2(row, 9.1));
	float column = floor(along);
	vec2 within = vec2(fract(along) * span, fract(at.y / course) * course);
	vec2 to_joint = min(within, vec2(span, course) - within);
	float joint = min(to_joint.x, to_joint.y);
	float tone = 1.0;
	tone += (hash(vec2(row, 1.3)) - 0.5) * 0.1 * seen(course, pixel);
	tone += (hash(vec2(row, column)) - 0.5) * 0.14 * seen(course, pixel * 1.5);
	float runs = patches(vec2(at.x * 1.6, at.y * 0.22 + 3.0)) * patches(at * 0.31 + 11.0);
	tone -= smoothstep(0.28, 0.5, runs) * 0.16 * wear * (flat_top ? 0.4 : 1.0) * seen(0.6, pixel);
	if (!flat_top) {
		float lip = seen(0.08, pixel);
		tone += (1.0 - smoothstep(0.05, 0.05 + pixel, course - within.y)) * 0.06 * lip;
		tone -= (1.0 - smoothstep(0.07, 0.07 + pixel, within.y)) * 0.1 * lip;
	}
	float chip = patches(at * vec2(1.3, 2.1) + 5.0);
	float gap = 0.016 + wear * 0.1 * chip * chip * chip;
	float line = (1.0 - smoothstep(gap - pixel, gap + pixel, joint)) * clamp(gap * 1.6 / pixel, 0.0, 1.0);
	float wander = patches(at * 0.27 + 23.0) + 0.2 * patches(at * 1.3 + 7.0) + 0.05 * patches(at * 5.3);
	float stretch = smoothstep(0.45, 0.7, patches(at * 0.5 + 90.0));
	float where_cracked = stretch * smoothstep(1.0 - cracks * 0.8, 1.1 - cracks * 0.8, patches(at * 0.13 + 40.0) + 0.25);
	float from_crack = abs(wander - 0.62) / max(fwidth(wander), 0.00001);
	float thick = (0.004 + 0.016 * stretch) / pixel;
	float crack = (1.0 - smoothstep(max(thick - 0.5, 0.0), thick + 0.5, from_crack)) * clamp(thick * 2.0, 0.0, 1.0) * where_cracked;
	vec3 colour = albedo * mix(1.0, tone, painted) * (1.0 - 0.5 * line * painted) * (1.0 - 0.55 * crack) * COLOR.rgb;

	// Damp. Water seeps out along the joints and runs down the face in long dark
	// streaks; the foot of the wall is soaked to a few metres up, black-green, and
	// moss takes the joints and the flats of the blocks the higher it is wet.
	if (!flat_top) {
		float streak_at = at.x * 0.55 + patches(vec2(at.x * 0.8, at.y * 0.05)) * 1.5;
		float streaks = smoothstep(0.55, 0.85, patches(vec2(streak_at, 0.5)) * patches(vec2(at.x * 0.13, at.y * 0.025 + 2.0)) * 1.8);
		float soaked = 1.0 - smoothstep(0.0, 3.0 + 4.0 * patches(vec2(at.x * 0.07, 6.0)), place.y);
		float damp = max(streaks * 0.8, soaked);
		colour = mix(colour, wet * tone, damp * 0.75);
		float mossy = smoothstep(0.45, 0.75, patches(at * 0.45 + 70.0) * 0.7 + soaked * 0.5 + line * 0.4 + streaks * 0.2);
		colour = mix(colour, moss * (0.7 + 0.5 * patches(at * 3.1)), mossy * 0.85);
	} else {
		colour = mix(colour, moss, 0.6);
	}

	// Ivy: curtains hung from the top, longer in some places than others, with a
	// ragged edge of leaves. On top of the wall it is a mat.
	float drop = height * overgrown * (0.15 + 1.6 * patches(vec2(at.x * 0.2, 1.7)) * patches(vec2(at.x * 0.05, 8.2)));
	float down = height - place.y;
	vec2 leaf_at = vec2(at.x, place.y) / 0.35;
	float leaves = patches(leaf_at) * 0.6 + patches(leaf_at * 2.3 + 4.0) * 0.4;
	float covered = flat_top ? smoothstep(0.35, 0.45, patches(place.xz * 0.4) + 0.2) : 1.0 - smoothstep(drop - 0.4, drop + 0.4, down + (leaves - 0.5) * 3.0 * seen(0.3, pixel));
	float leaf_tone = 0.75 + 0.5 * patches(leaf_at * 1.1 + 30.0) * seen(0.25, pixel);
	colour = mix(colour, ivy * leaf_tone, covered);

	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
}
"""

const GROUND_SHADER := """
shader_type spatial;

uniform vec3 grass : source_color = vec3(0.13, 0.2, 0.09);
// The dirt between the walls: packed and dry, damp, and wet mud; the stones in
// it; and the moss that grows along the foot of the walls.
uniform vec3 dry : source_color = vec3(0.35, 0.32, 0.27);
uniform vec3 damp : source_color = vec3(0.24, 0.215, 0.18);
uniform vec3 mud : source_color = vec3(0.13, 0.115, 0.095);
uniform vec3 stone : source_color = vec3(0.34, 0.33, 0.31);
uniform vec3 moss : source_color = vec3(0.1, 0.13, 0.065);
// What a puddle shows of what is over it: the walls round it, and the sky.
uniform vec3 walls_seen : source_color = vec3(0.62, 0.63, 0.63);
uniform vec3 sky_seen : source_color = vec3(0.82, 0.86, 0.86);
// How high the walls stand, for what a puddle shows over them.
uniform float wall_height = 34.0;
// How wet it is all over: more of it mud, and more and bigger puddles.
uniform float wetness = 0.45;
// The close detail of the dirt (tools/make_mud_texture.gd: height, pebbles,
// cracks, grit), and how much ground one copy of it covers, metres.
uniform sampler2D detail_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_map : filter_linear, repeat_enable;
uniform float tile = 2.4;
// 2: everything; 1 (phones and the web): the detail laid once, not twice, and
// the puddles still.
uniform float detail = 2.0;
uniform float banded = 1.0;
uniform float wrap = 0.2;
// Half the width of the clearing and of the whole maze, in metres.
uniform float clearing_half = 10.0;
uniform float maze_half = 50.0;
// The desert outside the square maze, out to this far from the middle (0: none).
uniform float desert_radius = 0.0;
uniform vec3 sand : source_color = vec3(0.66, 0.59, 0.46);
uniform vec3 sand_dark : source_color = vec3(0.5, 0.44, 0.34);
// What each quarter of the desert ring is (DesertStyle.Biome: 0 desert, 1 forest,
// 2 swamp, 3 plains), north (-z), east, south, west; and whether the desert ones
// are left to the sand (SandGround) laid over them: not drawn here at all.
uniform vec4 quarter_biomes = vec4(0.0);
uniform float sand_laid = 0.0;
uniform vec3 forest_floor : source_color = vec3(0.17, 0.14, 0.09);
uniform vec3 swamp_mud : source_color = vec3(0.12, 0.13, 0.08);
uniform vec3 plains_grass : source_color = vec3(0.34, 0.36, 0.24);
uniform vec3 plains_rock : source_color = vec3(0.42, 0.41, 0.38);
// Where walls stand (MazeStone.wall_feet), over a square `feet_half` metres each
// way from the middle (none if 0): r, grown out by the strip of moss at their
// foot; g, by the wet ground the rain runs off them onto.
uniform sampler2D feet : filter_linear_mipmap, repeat_disable;
uniform float feet_half = 0.0;

varying vec3 place;
// Which way the ground faces, in the world (up but on the clearing's hills).
varying vec3 ground_up;

// Smooth noise, a number at random on every whole metre (of p) and eased between
// them. (Read from a picture of numbers at random, drawn smoothly between its
// pixels, where the place in a pixel is eased first: one read, not four hashes.)
float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return textureLod(noise_map, (whole + part + 0.5) / 256.0, 0.0).r;
}

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// How a height laid over level ground (in metres) slopes, along x and z: from how
// it changes from one pixel to the next and how far apart those are on the ground.
vec2 slope_of(float height, vec3 across, vec3 down) {
	float hx = dFdx(height);
	float hy = dFdy(height);
	float det = across.x * down.z - across.z * down.x;
	if (abs(det) < 1.0e-10) {
		return vec2(0.0);
	}
	return vec2(hx * down.z - hy * across.z, across.x * hy - down.x * hx) / det;
}

void fragment() {
	// How much ground one pixel covers, metres: what is smaller than that fades.
	vec3 across = dFdx(place);
	vec3 down = dFdy(place);
	float reach = max(max(length(across), length(down)), 0.0001);
	vec2 at = place.xz;
	float out_x = max(abs(at.x), abs(at.y));
	// Grass in the clearing and out past the walls; between them dirt, with moss
	// along the foot of the walls, where nobody walks.
	float in_maze = smoothstep(clearing_half - 0.6, clearing_half + 0.6, out_x) * (1.0 - smoothstep(maze_half - 0.2, maze_half + 0.4, out_x));
	vec2 near_wall = vec2(0.0);
	if (feet_half > 0.0) {
		near_wall = texture(feet, at / (2.0 * feet_half) + 0.5).rg;
	}
	float by_wall = smoothstep(0.35, 0.75, near_wall.r + (patches(at * 0.8) - 0.5) * 0.45);

	// The lie of the ground, low (0) to high (1), in swells some metres across.
	float lie = patches(at / 11.0 + 3.1) * 0.5 + patches(at / 3.7 - 7.7) * 0.32 + patches(at * 0.85 + 1.3) * 0.18;
	// Wet: in broad patches, where the rain runs off the walls, and lower down.
	float splash = near_wall.g * (0.75 + 0.5 * patches(at * 0.6 + 4.0));
	float soaked = clamp(wetness + (patches(at / 23.0 + 9.0) - 0.5) * 0.9 + splash * 0.4 - (lie - 0.5) * 1.4 - 0.15, 0.0, 1.0);
	// Puddles, a metre or a few across, in the hollows of the low ground.
	float hollow = lie * 0.45 + patches(at / 2.9 + 11.0) * 0.38 + patches(at / 1.1 - 3.0) * 0.17;
	float brim = 0.2 + wetness * 0.12 + splash * 0.05 + (patches(at / 37.0 + 2.0) - 0.5) * 0.1;
	float depth = brim - hollow;

	// The close detail, laid twice, turned two ways and at two sizes, so that it
	// does not repeat: the bigger for clods, cracks and stones, the smaller for
	// grit and gravel. Which shows more goes in patches.
	vec4 big = texture(detail_map, mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866)) * at / tile);
	vec4 small = vec4(0.45, 0.0, 0.0, 0.6);
	if (detail > 1.5) {
		small = texture(detail_map, mat2(vec2(0.342, -0.94), vec2(0.94, 0.342)) * at / (tile * 0.41) + 0.31);
	}
	float share = 0.25 + 0.5 * smoothstep(0.2, 0.8, patches(at * 0.37 + 5.0));
	float near = clamp(1.6 - reach * 40.0, 0.0, 1.0);
	// Cracks open only where the ground has dried, and there only in patches,
	// where a crust has dried hard. (They are cut into the detail's height too:
	// filled back in where there is no crust.)
	float crust = smoothstep(0.62, 0.9, 1.0 - soaked) * smoothstep(0.5, 0.72, patches(at * 0.45 + 13.0) * 0.7 + patches(at * 1.6 - 4.0) * 0.3);
	float height = mix(big.r, small.r, share) + big.b * 0.18 * (1.0 - share) * (1.0 - crust);
	// (stones sink into mud)
	float sunk = 1.0 - 0.8 * smoothstep(0.45, 0.85, soaked);
	float stones = max(big.g * (1.0 - share * 0.6), small.g * share);
	float pebble = smoothstep(0.04, 0.25, stones) * sunk;
	float cracked = big.b * crust * near;

	vec3 colour = mix(dry, damp, smoothstep(0.1, 0.5, soaked));
	colour = mix(colour, mud, smoothstep(0.5, 0.92, soaked));
	// Clods and scuffs a hand or a stride across, lighter and darker, browner
	// and greyer, so that the ground is never one even tone.
	float clod = patches(at * 1.9 + 3.0) * 0.6 + patches(at * 0.63 - 1.0) * 0.4;
	colour *= 0.82 + 0.36 * clod;
	colour *= mix(vec3(1.06, 1.0, 0.92), vec3(0.94, 0.97, 1.02), patches(at * 0.21 + 9.0));
	colour *= 0.88 + 0.24 * patches(at * 0.31 + 7.0);
	colour *= 1.0 + (mix(big.a, small.a, share) - 0.6) * 0.4 * near + (height - 0.45) * 0.6;
	// Stones: grey and brown, a shade apart each, dull, darker wet.
	// (lighter on top of their domes, darker at their foot)
	float crown = clamp((height - 0.4) * 7.0, 0.0, 1.0);
	vec3 stone_colour = stone * mix(vec3(0.95, 0.9, 0.84), vec3(1.0), stones) * (0.62 + 0.38 * stones) * (0.7 + 0.5 * crown) * mix(1.0, 0.6, soaked);
	colour = mix(colour, stone_colour, pebble);
	colour *= 1.0 - 0.35 * cracked;
	// (the wettest mud by a pool is darkest)
	colour *= 1.0 - 0.3 * smoothstep(-0.035, 0.0, depth) * in_maze;

	// Moss in ragged patches along the foot of the walls, over the mud.
	float mossy = by_wall * smoothstep(0.35, 0.65, patches(at * 1.9 + 2.0) * 0.65 + patches(at * 5.3) * 0.35 + by_wall * 0.2) * in_maze;

	// It is lit as bumpy as it is: the detail, softer in mud and under moss, and the swells.
	float bumps = (mix(height, mix(big.a, small.a, share), mossy) - 0.45) * 0.05 * (1.0 - 0.55 * smoothstep(0.45, 0.95, soaked) * (1.0 - mossy)) * near + clod * 0.02 + lie * 0.35;
	vec2 slope = slope_of(bumps, across, down);
	// Water: flat, but for a faint stir on it, and the stones in its shallow
	// edges standing out of it.
	float edge = max(fwidth(depth), 0.003);
	float pool = smoothstep(0.0, edge * 1.5 + 0.004, depth) * in_maze * (1.0 - by_wall);
	pool *= 1.0 - pebble * (1.0 - smoothstep(0.01, 0.03, depth));
	vec2 still = vec2(0.0);
	if (detail > 1.5) {
		float stir = (patches(at * 1.3 + TIME * vec2(0.21, 0.08)) + patches(at * 3.1 - TIME * vec2(0.05, 0.27)) * 0.4) * 0.003 * near;
		still = slope_of(stir, across, down);
	}
	slope = mix(slope, still, pool);
	vec3 up = normalize(ground_up + vec3(-slope.x, 0.0, -slope.y));

	// The moss, and the clearing's grass beyond the maze.
	// (in cushions: lighter on their tops, the dirt between them dark)
	float cushion = clamp((mix(big.a, small.a, share) - 0.35) * 1.6, 0.0, 1.0) * near + (1.0 - near) * 0.5;
	colour = mix(colour, moss * (0.8 + 0.4 * patches(at * 3.1 + 8.0)) * (0.55 + 0.8 * cushion), mossy * mix(1.0, 0.75 + 0.25 * cushion, near));
	float grassy = 1.0 - in_maze;
	// (sand in the desert: in ripples across the wind, darker in the hollows)
	float sandy = 0.0;
	if (desert_radius > 0.0) {
		sandy = smoothstep(maze_half + 0.4, maze_half + 3.0, out_x) * (1.0 - smoothstep(desert_radius - 2.0, desert_radius, length(at)));
	}
	grassy *= 1.0 - sandy;
	colour = mix(colour, grass * (0.85 + 0.3 * patches(at * 0.35)), grassy);
	float ripple = 0.5 + 0.5 * sin(dot(at, vec2(0.83, 0.55)) * 2.6 + patches(at * 0.15) * 6.0);
	vec3 sand_colour = mix(sand_dark, sand, patches(at / 40.0 + 5.0) * 0.6 + 0.4 * smoothstep(0.0, 1.0, place.y / 8.0)) * (0.94 + 0.08 * ripple * near);
	// (each quarter of the desert ring its biome's ground: the diagonal walls part them)
	float biome = abs(at.x) > abs(at.y) ? (at.x > 0.0 ? quarter_biomes.y : quarter_biomes.w) : (at.y > 0.0 ? quarter_biomes.z : quarter_biomes.x);
	if (sandy > 0.5 && biome < 0.5 && sand_laid > 0.5) {
		discard;
	}
	vec3 rocky = mix(plains_grass * (0.8 + 0.4 * patches(at * 0.3)), plains_rock * (0.85 + 0.3 * patches(at * 1.7)), smoothstep(0.55, 0.75, patches(at / 18.0 + 3.0)));
	vec3 biome_colour = biome < 0.5 ? sand_colour : (biome < 1.5 ? forest_floor * (0.8 + 0.4 * patches(at * 0.5)) : (biome < 2.5 ? swamp_mud * (0.75 + 0.5 * patches(at * 0.2)) : rocky));
	colour = mix(colour, biome_colour, sandy);

	// A puddle shows what is over it, most of all seen at a low angle: the walls
	// round it, and the sky over them. Which, is found by following the bounced
	// ray over the map of where the walls stand, until it is higher than they are.
	// It is murky: the mud under it shows through dimly.
	vec3 view = normalize(CAMERA_POSITION_WORLD - place);
	vec3 bounce = reflect(-view, up);
	float fresnel = 0.03 + 0.97 * pow(1.0 - clamp(dot(up, view), 0.0, 1.0), 5.0);
	vec3 seen = sky_seen * (0.9 + 0.1 * bounce.y);
	if (pool > 0.0 && feet_half > 0.0) {
		float flat_len = max(length(bounce.xz), 0.0001);
		vec2 along = bounce.xz / flat_len;
		float rise = bounce.y / flat_len;
		// (in longer and longer steps, out to a hundred metres or so; each looks at
		// the map as coarse as its step is long, so that it cannot step over a wall)
		float texel = 2.0 * feet_half / float(textureSize(feet, 0).x);
		for (int i = 1; i <= 12; i++) {
			float far = float(i * i) * 0.75;
			float high = rise * far;
			if (high > wall_height) {
				break;
			}
			float coarse = log2(max(float(2 * i - 1) * 0.75 / texel, 1.0));
			if (textureLod(feet, (at + along * far) / (2.0 * feet_half) + 0.5, coarse).r > 0.6 / (1.0 + coarse * 0.7)) {
				// (a wall: darker low down, where its foot is wet and in shade, and in
				// streaks where the rain has run down it)
				vec2 hit = at + along * far;
				float streaks = patches(vec2(dot(hit, vec2(0.71, 0.71)) * 0.45, high * 0.02)) * 0.6 + patches(vec2(dot(hit, vec2(-0.71, 0.71)) * 1.3, 3.0)) * 0.4;
				seen = walls_seen * mix(0.6, 1.1, high / wall_height) * (0.78 + 0.4 * streaks);
				break;
			}
		}
	}
	float shown = 0.3 + 0.7 * fresnel;
	ALBEDO = mix(colour, mix(mud, damp, 0.3) * 0.7 * (1.0 - shown), pool);
	EMISSION = seen * shown * pool;
	// (wet ground has a sheen: see light())
	ROUGHNESS = mix(mix(1.0, 0.45, smoothstep(0.55, 1.0, soaked) * (1.0 - grassy) * (1.0 - mossy)), 0.05, pool);
	SPECULAR = 0.0;
	NORMAL = normalize(mat3(VIEW_MATRIX) * up);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
	// The sheen of wet mud and water.
	float gloss = 1.0 - ROUGHNESS;
	if (gloss > 0.01) {
		// (soft: the sun is behind cloud, so there is no hard glint off the water)
		float shine = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), mix(6.0, 48.0, gloss * gloss));
		SPECULAR_LIGHT += shine * gloss * reach * LIGHT_COLOR * 0.22;
	}
}
"""

static var _wall: Shader
static var _ground: Shader


static func wall(height: float, built := true) -> ShaderMaterial:
	if _wall == null:
		_wall = Shader.new()
		_wall.code = WALL_SHADER
	var material := ShaderMaterial.new()
	material.shader = _wall
	material.set_shader_parameter(&"albedo", STONE)
	material.set_shader_parameter(&"ivy", IVY)
	material.set_shader_parameter(&"height", height)
	material.set_shader_parameter(&"painted", 0.0 if built else 1.0)
	return material


## `walls`: the boxes (MazePieces) on the ground whose feet moss grows along and
## whose rain wets the ground by them, if known (see wall_feet). Without them
## there is none. (`_wall_thick` is no longer needed: where the walls stand is
## read from them.)
static func ground(clearing_half: float, maze_half: float, _wall_thick: float, walls: Array[MazePiece] = []) -> ShaderMaterial:
	if _ground == null:
		_ground = Shader.new()
		_ground.code = GROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = _ground
	material.set_shader_parameter(&"clearing_half", clearing_half)
	material.set_shader_parameter(&"maze_half", maze_half)
	material.set_shader_parameter(&"detail_map", load("res://textures/mud.png"))
	material.set_shader_parameter(&"noise_map", load("res://textures/mud_noise.png"))
	# (as Outside's sand: a phone or a browser gets the plainer ground)
	material.set_shader_parameter(&"detail", 1.0 if OS.has_feature("web") or OS.has_feature("mobile") else 2.0)
	if not walls.is_empty():
		var half := maze_half + 4.0
		material.set_shader_parameter(&"feet", wall_feet(walls, half))
		material.set_shader_parameter(&"feet_half", half)
	return material


## A map of the ground `half` metres each way from the middle, of each of `walls`
## standing on the ground: r, white along its foot (and under it), black
## elsewhere; g, how wet the ground is from the rain run off it, 1 at its foot and
## falling to nothing `WET` metres out.
static func wall_feet(walls: Array[MazePiece], half: float) -> ImageTexture:
	const STRIP := 1.2
	const WET := 4.0
	const STEPS := 5
	var texels := mini(ceili(half * 2.0), 1024)
	var per_metre := texels / (half * 2.0)
	var image := Image.create_empty(texels, texels, false, Image.FORMAT_RG8)
	var areas: Array[Rect2] = []
	for piece in walls:
		var where := piece.box_transform()
		if where.origin.y > 0.5:
			continue
		var size := piece.box_size() * 0.5
		var area := Rect2(Vector2(where.origin.x, where.origin.z), Vector2.ZERO)
		for corner: Vector3 in [Vector3(-size.x, 0, -size.z), Vector3(size.x, 0, -size.z), Vector3(-size.x, 0, size.z), Vector3(size.x, 0, size.z)]:
			var p := where * corner
			area = area.expand(Vector2(p.x, p.z))
		areas.append(area)
	# (the wet ground in steps, the furthest and faintest first, each nearer one
	# over it; then the strip at the foot)
	for step in STEPS:
		var out := WET * (1.0 - float(step) / STEPS)
		for area in areas:
			_fill(image, area.grow(out), half, per_metre, Color(0.0, float(step + 1) / STEPS, 0.0))
	for area in areas:
		_fill(image, area.grow(STRIP), half, per_metre, Color(1.0, 1.0, 0.0))
	# (coarser copies, for a puddle looking far off over it for walls)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _fill(image: Image, area: Rect2, half: float, per_metre: float, colour: Color) -> void:
	var from := ((area.position + Vector2(half, half)) * per_metre).floor()
	var to := ((area.end + Vector2(half, half)) * per_metre).ceil()
	var texel_area := Rect2i(Vector2i(from), Vector2i(to - from)).intersection(Rect2i(0, 0, image.get_width(), image.get_height()))
	if texel_area.has_area():
		image.fill_rect(texel_area, colour)
