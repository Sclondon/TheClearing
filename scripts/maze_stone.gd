@tool
class_name MazeStone
## The materials of the maze: its walls and the ground.
##
## The walls are Outside's sandstone (scripts/sandstone.gd there: courses of
## blocks, joints, stains run down, cracks), turned grey and old, with ivy hung
## from their tops in curtains. The ground is grass in the clearing and out past
## the maze, and trodden earth between the walls. Nothing is a picture: it is all
## worked out from where in the world a point is, and fades out as it gets too
## small to draw, so that it does not shimmer far off.
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
uniform vec3 earth : source_color = vec3(0.24, 0.21, 0.16);
uniform float banded = 1.0;
uniform float wrap = 0.2;
// Half the width of the clearing and of the whole maze, in metres.
uniform float clearing_half = 10.0;
uniform float maze_half = 50.0;
uniform float cell = 8.0;
uniform float wall_thick = 2.6;
// Where walls stand, grown out by a strip at their foot (MazeStone.wall_feet), over
// a square `feet_half` metres each way from the middle; none if 0.
uniform sampler2D feet : filter_linear, repeat_disable;
uniform float feet_half = 0.0;

varying vec3 place;

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

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float pixel = max(length(fwidth(place)), 0.0001);
	vec2 at = place.xz;
	float out_x = max(abs(at.x), abs(at.y));
	// Grass in the clearing and out past the walls; between them trodden earth,
	// with grass coming back along the foot of the walls, where nobody walks.
	float in_maze = smoothstep(clearing_half - 0.6, clearing_half + 0.6, out_x) * (1.0 - smoothstep(maze_half - 0.2, maze_half + 0.4, out_x));

	float by_wall = 0.0;
	if (feet_half > 0.0) {
		by_wall = smoothstep(0.35, 0.75, texture(feet, at / (2.0 * feet_half) + 0.5).r + (patches(at * 0.8) - 0.5) * 0.45);
	}
	float tufts = patches(at * 1.7) * 0.6 + patches(at * 5.0) * 0.4 * clamp(0.6 / pixel, 0.0, 1.0);
	float grassy = 1.0 - in_maze * (1.0 - smoothstep(0.55, 0.75, by_wall * 0.7 + tufts * 0.6));
	float tone = 0.85 + 0.3 * patches(at * 0.35) + (tufts - 0.5) * 0.25;
	ALBEDO = mix(earth, grass, grassy) * tone;
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


## `walls`: the boxes (MazePieces) on the ground whose feet grass grows along, if
## known (see wall_feet). Without them there is none.
static func ground(clearing_half: float, maze_half: float, wall_thick: float, walls: Array[MazePiece] = []) -> ShaderMaterial:
	if _ground == null:
		_ground = Shader.new()
		_ground.code = GROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = _ground
	material.set_shader_parameter(&"clearing_half", clearing_half)
	material.set_shader_parameter(&"maze_half", maze_half)
	material.set_shader_parameter(&"cell", Maze.CELL)
	material.set_shader_parameter(&"wall_thick", wall_thick)
	if not walls.is_empty():
		var half := maze_half + 4.0
		material.set_shader_parameter(&"feet", wall_feet(walls, half))
		material.set_shader_parameter(&"feet_half", half)
	return material


## A map of the ground `half` metres each way from the middle, white along the foot
## of each of `walls` standing on the ground (and under it), black elsewhere.
static func wall_feet(walls: Array[MazePiece], half: float) -> ImageTexture:
	const STRIP := 1.2
	var texels := mini(ceili(half * 2.0), 1024)
	var per_metre := texels / (half * 2.0)
	var image := Image.create_empty(texels, texels, false, Image.FORMAT_L8)
	for piece in walls:
		var where := piece.box_transform()
		if where.origin.y > 0.5:
			continue
		var size := piece.box_size() * 0.5
		var area := Rect2(Vector2(where.origin.x, where.origin.z), Vector2.ZERO)
		for corner: Vector3 in [Vector3(-size.x, 0, -size.z), Vector3(size.x, 0, -size.z), Vector3(-size.x, 0, size.z), Vector3(size.x, 0, size.z)]:
			var p := where * corner
			area = area.expand(Vector2(p.x, p.z))
		area = area.grow(STRIP)
		var from := ((area.position + Vector2(half, half)) * per_metre).floor()
		var to := ((area.end + Vector2(half, half)) * per_metre).ceil()
		var texel_area := Rect2i(Vector2i(from), Vector2i(to - from)).intersection(Rect2i(0, 0, texels, texels))
		if texel_area.has_area():
			image.fill_rect(texel_area, Color.WHITE)
	return ImageTexture.create_from_image(image)
