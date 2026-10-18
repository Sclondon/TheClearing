class_name SlimeWallLook
## What a slime wall (SlimeWall, creatures/slime_wall/slime_wall.gd) is made of,
## to look at. Everything is worked out here in code: no models, no pictures.
##
## - THE JELLY is one closed, rounded box, drawn twice: its inside faces first
##   (only seen from within it), then its outside faces. The outside reads the
##   screen behind it, bends it a little, and clouds it by how much jelly the
##   eye looks through: from where the eye enters the box to where it leaves it,
##   or to whatever stands inside it, whichever is nearer (the depth of the
##   scene tells it that). So a bone near the front is plain, one at the back is
##   a shape in the murk, and someone on the far side is a green ghost. Its
##   size is three numbers (`half_size`) that the shader rounds the box to, so
##   it can be squeezed narrower or taller every frame without building a thing;
##   and the shader makes it sag, bulge at the foot, quiver, surge forward as it
##   moves, sway as it starts and stops, and glint wet.
## - WHAT IT HAS EATEN is one mesh: skeletons whole and in pieces, skulls,
##   bones, a ribcage, a pelvis, a hand, a boot, a scrap of red shirt, a coil of
##   rope, a horned beast's skull, a strip of linen bandage and a rusted blade.
##   Each piece carries where in the jelly it hangs (as a share of the box, so
##   the box can change shape round it) and a number of its own, from which the
##   shader turns it slowly about an axis of its own and lets it drift. One draw.
## - DRIPS: a few beads of slime that run down its faces (one draw).
## - THE TRAIL: wet patches on the ground behind it that dry and fade (one draw,
##   in the world; see SlimeWall).

## Everything in the jelly is laid out in the box's own space: x across it
## (its width), y up from the ground it stands on, z the way it is going.

const NOISE := """
float hash1(float n) { return fract(sin(n) * 43758.5453); }
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
"""

## The shape of the jelly, shared by both its passes: the rounded box, and how it moves.
const SHAPE := """
// Half its width, half its height and half its depth (metres); it stands on y = 0.
uniform vec3 half_size = vec3(6.0, 3.5, 2.25);
uniform float round_r = 1.2;
// How much its top sags in the middle, its foot spreads, and its skin quivers.
uniform float sag = 0.45;
uniform float foot = 0.35;
uniform float wobble = 0.35;
// Set each frame by SlimeWall: how hard it is going (0..1), how far it is
// swaying forward (metres at the top, + forward), how fast it is being
// squeezed (+ narrower), and a point it is bulging towards (box space) and how much.
uniform float surge = 0.0;
uniform float sway = 0.0;
uniform float squish = 0.0;
uniform vec3 reach = vec3(0.0, 1.0, 3.0);
uniform float reach_amount = 0.0;

varying vec3 local_pos;
varying vec3 local_cam;
varying vec3 local_n;

vec3 jelly_point(vec3 g, out vec3 n) {
	vec3 q = g * half_size;
	float r = min(round_r, min(half_size.x, min(half_size.y, half_size.z)) * 0.95);
	vec3 inner = max(half_size - vec3(r), vec3(0.001));
	vec3 c = clamp(q, -inner, inner);
	vec3 d = q - c;
	n = d / max(length(d), 0.0001);
	vec3 p = c + n * r + vec3(0.0, half_size.y, 0.0);
	float tall = 2.0 * half_size.y;
	float up = clamp(p.y / tall, 0.0, 1.0);
	float across = clamp(p.x / half_size.x, -1.0, 1.0);
	float t = TIME;
	// The top sags between the walls, and the foot spreads forward and back.
	p.y -= sag * smoothstep(0.55, 1.0, up) * (1.0 - across * across * 0.7) * (1.0 + 0.4 * sin(t * 0.7 + p.x * 0.3));
	p.z += sign(n.z) * foot * (1.0 - smoothstep(0.0, 0.22, up)) * abs(n.z) * (1.0 + 0.3 * sin(t * 1.3 + p.x));
	// It quivers all over, more the higher it is.
	float w = noise3(p * 0.33 + vec3(0.0, t * 0.55, t * 0.35)) - 0.5;
	w += 0.5 * (noise3(p * 0.85 - vec3(t * 0.45, 0.0, t * 0.2)) - 0.5);
	w += 0.25 * sin(t * 2.1 + p.y * 1.3 + p.x * 0.7);
	p += n * w * wobble * (0.25 + up) * smoothstep(0.0, 0.08, up);
	// Going, the front heaves in waves that climb it.
	float front = max(n.z, 0.0);
	p.z += front * surge * (0.3 + 0.35 * sin(t * 2.6 - p.y * 0.8 + p.x * 0.2));
	// Starting and stopping, the whole of it sways like a jelly on a plate.
	p.z += sway * up * up;
	// Squeezed, it rises.
	p.y *= 1.0 + max(squish, 0.0) * 0.12 * up;
	// It swells towards what it is after.
	vec3 to = p - reach;
	p += normalize(vec3(reach.x - p.x, 0.0, reach.z - p.z) + vec3(0.0001)) * reach_amount * exp(-dot(to, to) * 0.08) * front;
	p.y = max(p.y, 0.0);
	return p;
}
"""

## The outside of the jelly: it bends and clouds what is behind it.
const FRONT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
// What clear jelly does to what is seen through it, what it is when it is deep,
// the sludge at the bottom of it, the pale of its skin seen edge on, and the glint on it.
uniform vec3 clear_tint : source_color = vec3(0.66, 0.80, 0.52);
uniform vec3 deep : source_color = vec3(0.20, 0.27, 0.13);
uniform vec3 sludge : source_color = vec3(0.16, 0.15, 0.08);
uniform vec3 skin : source_color = vec3(0.74, 0.84, 0.62);
uniform vec3 glint : source_color = vec3(0.95, 1.0, 0.9);
// How fast it clouds, per metre looked through (and the sludge, how deep it lies
// and how thick it is); how much it bends what is behind.
uniform float density = 0.22;
uniform float clear_depth = 1.1;
uniform float sludge_depth = 0.9;
uniform float sludge_density = 1.4;
uniform float bend = 0.06;
uniform float skin_amount = 0.5;
%s
%s
void vertex() {
	vec3 n;
	vec3 p = jelly_point(VERTEX, n);
	VERTEX = p;
	NORMAL = n;
	local_pos = p;
	local_n = n;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	local_cam = transpose(mat3(MODEL_MATRIX)) * (cam - MODEL_MATRIX[3].xyz);
}

vec3 unproject(vec2 screen_uv, float depth, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

void fragment() {
	// How far the eye goes through jelly: into the box and out of it, or to what is in it.
	vec3 rd = normalize(local_pos - local_cam);
	vec3 inv = 1.0 / (rd + vec3(1e-5));
	vec3 bmin = vec3(-half_size.x, 0.0, -half_size.z - 0.5);
	vec3 bmax = vec3(half_size.x, 2.0 * half_size.y, half_size.z + 0.5);
	vec3 t0 = (bmin - local_cam) * inv;
	vec3 t1 = (bmax - local_cam) * inv;
	vec3 tfar = max(t0, t1);
	float out_at = min(min(tfar.x, tfar.y), tfar.z);
	float here = length(VERTEX);
	// The skin quivers: a bent normal, for the light and the bending.
	float t = TIME;
	vec3 q = local_pos * 0.9;
	vec3 bumpy = vec3(noise3(q + vec3(t * 0.3, 0.0, 0.0)), noise3(q + vec3(5.2, t * 0.25, 1.3)), noise3(q + vec3(2.1, 7.7, t * 0.3))) - 0.5;
	bumpy += 0.5 * (vec3(noise3(q * 3.1 + vec3(1.0, t * 0.4, 0.0)), noise3(q * 3.1 + vec3(8.0, 2.0, t * 0.4)), noise3(q * 3.1 + vec3(4.0, t * 0.3, 6.0))) - 0.5);
	vec3 nv = normalize(NORMAL + (VIEW_MATRIX * vec4(bumpy * 0.7, 0.0)).xyz);
	vec2 off = nv.xy * bend;
	vec2 uv = SCREEN_UV - off;
	// (nothing in front of the jelly is pulled into it)
	float scene = length(unproject(uv, texture(depth_tex, uv).r, INV_PROJECTION_MATRIX));
	if (scene < here) {
		uv = SCREEN_UV;
		scene = length(unproject(uv, texture(depth_tex, uv).r, INV_PROJECTION_MATRIX));
	}
	float end_at = min(out_at, scene);
	float through = max(end_at - here, 0.0);
	// How much of that is down in the sludge at the bottom.
	float low = 0.0;
	if (abs(rd.y) > 1e-4) {
		float cut_at = (sludge_depth - local_cam.y) / rd.y;
		low = rd.y < 0.0 ? max(end_at - max(here, cut_at), 0.0) : max(min(end_at, cut_at) - here, 0.0);
	} else if (local_cam.y < sludge_depth) {
		low = through;
	}
	low = min(low, through);
	// (the first metre or so is nearly clear; past it, it clouds by `density`)
	float murk = 1.0 - exp(-(density * max(through - clear_depth, 0.0) + 0.06 * min(through, clear_depth) + 0.02));
	float silt = 1.0 - exp(-sludge_density * low);
	vec3 behind = textureLod(screen_tex, uv, 0.0).rgb;
	// Deep in it, things go green and dark; near the top, the light comes down through it.
	float up = clamp(local_pos.y / (2.0 * half_size.y), 0.0, 1.0);
	vec3 depth_col = deep * (0.6 + 0.7 * up);
	vec3 col = mix(behind * clear_tint, depth_col, murk);
	col = mix(col, sludge, silt * 0.92);
	// Seen edge on, its skin; and a sheen where it faces the sky.
	vec3 view = normalize(-VERTEX);
	float facing = clamp(dot(nv, view), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.0);
	col = mix(col, skin, clamp(edge * skin_amount, 0.0, 0.75));
	vec3 sky = normalize((VIEW_MATRIX * vec4(0.25, 1.0, 0.35, 0.0)).xyz);
	float top = max(dot(nv, sky), 0.0);
	col += skin * 0.06 * smoothstep(0.6, 0.95, top);
	// A wet film on it, in swirls.
	float film = noise3(local_pos * vec3(1.2, 0.5, 1.2) + vec3(0.0, -t * 0.1, 0.0)) * 0.6 + noise3(local_pos * 3.0 - vec3(0.0, t * 0.2, 0.0)) * 0.4;
	col = mix(col, skin, smoothstep(0.55, 0.75, film) * 0.12);
	// Wet glints: small, sharp, broken up.
	float spec = pow(max(dot(reflect(-view, nv), sky), 0.0), 90.0);
	float wet = smoothstep(0.5, 0.65, noise3(local_pos * 4.0 + vec3(0.0, t * 0.08, 0.0)));
	col = mix(col, glint, smoothstep(0.3, 0.5, spec) * wet * smoothstep(0.15, 0.45, facing));
	// Slime running down it.
	float streak = smoothstep(0.66, 0.82, noise3(vec3(local_pos.x * 3.0, local_pos.y * 0.2 + t * 0.12, local_pos.z * 3.0)));
	col = mix(col, skin * 0.95, streak * 0.14 * (1.0 - murk * 0.5));
	ALBEDO = col;
	ALPHA = 1.0;
}
"""

## The inside of the jelly: what is seen from within it (or by a camera pushed into it).
const BACK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix;

uniform vec3 deep : source_color = vec3(0.25, 0.31, 0.21);
uniform vec3 skin : source_color = vec3(0.78, 0.86, 0.70);
uniform float density = 0.16;
%s
%s
void vertex() {
	vec3 n;
	vec3 p = jelly_point(VERTEX, n);
	VERTEX = p;
	NORMAL = n;
	local_pos = p;
	local_n = n;
	local_cam = vec3(0.0);
}

void fragment() {
	float through = length(VERTEX);
	float murk = 1.0 - exp(-density * (through + 0.3));
	float up = clamp(local_pos.y / (2.0 * half_size.y), 0.0, 1.0);
	ALBEDO = deep * (0.45 + 0.6 * up);
	ALPHA = clamp(0.3 + murk, 0.0, 0.94);
}
"""

## What it has eaten: each piece placed and turned by the shader (see `contents`).
const CONTENTS_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec3 half_size = vec3(6.0, 3.5, 2.25);
uniform float sway = 0.0;
uniform float surge = 0.0;
// How big the pieces are drawn (1: as made), smaller when it is squeezed thin.
uniform float content_scale = 1.0;
uniform vec3 rot_color : source_color = vec3(0.32, 0.36, 0.22);

varying float erosion;
varying vec3 at;

float hash1(float n) { return fract(sin(n) * 43758.5453); }

mat3 turn(vec3 axis, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	return mat3(
		vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y + axis.z * s, oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s, oc * axis.y * axis.z - axis.x * s, oc * axis.z * axis.z + c));
}

void vertex() {
	vec3 share = vec3(UV2.x, UV.x, UV2.y);
	float own = COLOR.a;
	// (a piece against a face says so with its eating-away below zero, and how
	// far in from the face it lies, in metres, in place of its depth: + the front)
	bool on_face = UV.y < 0.0;
	erosion = abs(UV.y);
	float t = TIME;
	vec3 room = max(half_size - vec3(0.9, 0.8, 1.0) * content_scale, vec3(0.15));
	mat3 r;
	vec3 middle;
	if (on_face) {
		// Against a face it lies as it is, rocking a little and drifting along the face.
		r = turn(vec3(0.0, 0.0, 1.0), sin(t * 0.23 + own * 20.0) * 0.1);
		vec2 along = vec2(sin(t * 0.07 + own * 13.0), 0.5 * sin(t * 0.05 + own * 29.0)) * 0.03;
		vec2 across = clamp(share.xy + along, vec2(-1.0), vec2(1.0)) * max(half_size.xy - vec2(1.1, 0.9) * content_scale, vec2(0.15));
		float side = share.z < 0.0 ? -1.0 : 1.0;
		middle = vec3(across.x, half_size.y + across.y, side * max(half_size.z - abs(share.z), 0.1));
	} else {
		vec3 axis = normalize(vec3(hash1(own * 13.1) - 0.5, hash1(own * 7.3) - 0.5, hash1(own * 3.7) - 0.5) + vec3(0.001));
		// (the pieces settled at the bottom hardly stir)
		float settled = smoothstep(-0.55, -0.8, share.y);
		float speed = mix(0.04 + 0.1 * hash1(own * 5.1), 0.008, settled);
		r = turn(axis, own * 6.2831 + t * speed * (hash1(own * 2.9) > 0.5 ? 1.0 : -1.0));
		vec3 drift = (1.0 - settled) * vec3(sin(t * 0.13 + own * 20.0), 0.6 * sin(t * 0.11 + own * 31.0), sin(t * 0.09 + own * 17.0));
		middle = vec3(0.0, half_size.y, 0.0) + clamp(share + drift * 0.05, vec3(-1.0), vec3(1.0)) * room;
	}
	vec3 p = middle + r * (VERTEX * content_scale);
	float up = clamp(p.y / (2.0 * half_size.y), 0.0, 1.0);
	p.z += sway * up * up + surge * 0.15 * up;
	VERTEX = p;
	NORMAL = r * NORMAL;
	at = p;
}

void fragment() {
	// Eaten away: rotten green in blotches, and darker the more it is gone.
	float blot = fract(sin(dot(floor(at * 9.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 col = COLOR.rgb;
	col = mix(col, rot_color, clamp(erosion * (0.45 + 0.55 * blot), 0.0, 0.85));
	ALBEDO = col;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
"""

## Beads of slime running down its faces.
const DRIP_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform vec3 skin : source_color = vec3(0.80, 0.88, 0.72);
uniform vec3 glint : source_color = vec3(0.95, 1.0, 0.9);
%s
%s
varying float fade;

void vertex() {
	// INSTANCE_CUSTOM: across (-1..1), which face (+1 front, -1 back), when, how fast.
	vec4 own = INSTANCE_CUSTOM;
	float life = fract(TIME * (0.05 + 0.08 * own.w) + own.z);
	float tall = 2.0 * half_size.y;
	vec3 g = vec3(own.x * 0.85, mix(0.75, -0.95, life), own.y);
	vec3 n;
	vec3 p = jelly_point(g, n);
	// (stretched long as it runs)
	vec3 v = VERTEX;
	v.y *= 1.0 + life * 1.5;
	VERTEX = p + n * 0.06 + v;
	fade = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.85, 1.0, life));
}

void fragment() {
	vec3 view = normalize(-VERTEX);
	float edge = 1.0 - clamp(dot(NORMAL, view), 0.0, 1.0);
	vec3 sky = normalize((VIEW_MATRIX * vec4(0.25, 1.0, 0.35, 0.0)).xyz);
	float spec = pow(max(dot(reflect(-view, NORMAL), sky), 0.0), 30.0);
	ALBEDO = mix(skin * 0.8, glint, step(0.4, spec));
	ALPHA = fade * (0.22 + 0.35 * edge);
}
"""

## The wet trail it leaves: patches on the ground that dry.
const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 wet : source_color = vec3(0.14, 0.17, 0.11);
uniform vec3 shine : source_color = vec3(0.78, 0.86, 0.72);
uniform float now = 0.0;
uniform float lasts = 25.0;
%s
varying float age;
varying vec3 world;
varying vec2 own;

void vertex() {
	age = (now - INSTANCE_CUSTOM.x) / lasts;
	own = INSTANCE_CUSTOM.yz;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (age < 0.0 || age > 1.0) {
		discard;
	}
	// Ragged at its sides, thinner as it dries, and shining where it is still wet.
	float side = abs(UV.x - 0.5) * 2.0;
	float ragged = noise3(world * vec3(0.9, 0.0, 0.9) + vec3(own.x * 10.0, 0.0, 0.0)) * 0.5 + noise3(world * 2.5) * 0.25;
	float keep = 1.0 - smoothstep(0.55 + ragged * 0.4 - age * 0.35, 0.95 - age * 0.3, side);
	float pools = smoothstep(0.35 + age * 0.4, 0.75, noise3(world * vec3(0.45, 0.0, 0.45) + vec3(3.0, 0.0, own.y * 7.0)));
	float ends = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	float alpha = keep * ends * (0.24 + 0.3 * pools) * (1.0 - smoothstep(0.4, 1.0, age));
	vec3 view = normalize(-VERTEX);
	vec3 sky = normalize((VIEW_MATRIX * vec4(0.2, 1.0, 0.3, 0.0)).xyz);
	vec3 n = normalize(NORMAL + (VIEW_MATRIX * vec4(vec3(noise3(world * 3.0) - 0.5, 0.0, noise3(world * 3.0 + 9.0) - 0.5) * 0.6, 0.0)).xyz);
	float spec = pow(max(dot(reflect(-view, n), sky), 0.0), 24.0);
	ALBEDO = mix(wet, shine, smoothstep(0.3, 0.6, spec) * pools * (1.0 - age));
	ALPHA = alpha;
}
"""


static func front_material() -> ShaderMaterial:
	return _material(FRONT_SHADER % [NOISE, SHAPE])


static func back_material() -> ShaderMaterial:
	return _material(BACK_SHADER % [NOISE, SHAPE])


static func contents_material() -> ShaderMaterial:
	return _material(CONTENTS_SHADER)


static func drip_material() -> ShaderMaterial:
	return _material(DRIP_SHADER % [NOISE, SHAPE])


static func trail_material() -> ShaderMaterial:
	return _material(TRAIL_SHADER % NOISE)


static var _shaders := {}


static func _material(code: String) -> ShaderMaterial:
	# (one Shader for every slime wall: only the materials are their own)
	if not _shaders.has(code):
		var shader := Shader.new()
		shader.code = code
		_shaders[code] = shader
	var material := ShaderMaterial.new()
	material.shader = _shaders[code]
	return material


## The jelly's mesh: the faces of a box from -1 to 1, cut finer near its edges
## (where the shader rounds it), `cuts` to a side. The shader gives it its size.
static func jelly_mesh(cuts := 26) -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var stops := PackedFloat32Array()
	for i in cuts + 1:
		stops.append(sin((float(i) / cuts * 2.0 - 1.0) * PI * 0.5))
	# Each face: its normal axis and sign, and the two axes across it (so it winds outward).
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var first := verts.size()
		for j in cuts + 1:
			for i in cuts + 1:
				verts.append(normal + u * stops[i] + v * stops[j])
		for j in cuts:
			for i in cuts:
				var a := first + j * (cuts + 1) + i
				var b := a + 1
				var c := a + cuts + 1
				var d := c + 1
				indices.append_array([a, d, b, a, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for k in verts.size():
		normals[k] = verts[k].normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A bead of slime.
static func drip_mesh() -> ArrayMesh:
	var made := Pieces.new()
	made.ellipsoid(Vector3(0.0, -0.05, 0.0), Vector3(0.022, 0.08, 0.02), Basis.IDENTITY, Color.WHITE, 5, 6)
	return made.mesh()


## A patch of the trail: a strip of ground one metre long and one wide (scaled by SlimeWall).
static func trail_mesh() -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	return mesh


# --- What it has eaten ---

const BONE := Color(0.80, 0.74, 0.58)
const OLD_BONE := Color(0.60, 0.53, 0.38)
const DARK := Color(0.08, 0.07, 0.06)
const LEATHER := Color(0.24, 0.17, 0.12)
const SHIRT := Color(0.55, 0.13, 0.11)
const ROPE := Color(0.58, 0.48, 0.32)
const LINEN := Color(0.80, 0.74, 0.60)
const RUST := Color(0.42, 0.24, 0.14)
const HORN := Color(0.30, 0.26, 0.20)


## Builds pieces into one mesh: each vertex is where it is in its piece (from
## the piece's middle), and carries where in the jelly that piece hangs (UV2.x,
## UV.x, UV2.y: shares of the box, -1..1), how far it is eaten away (UV.y), and
## its colour, with a number of the piece's own in the colour's alpha.
class Pieces:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	## The piece being built: where it hangs, its own number, how eaten it is.
	var share := Vector3.ZERO
	var own := 0.0
	var eaten := 0.0
	## Each part added is put through this first (to pose a piece made of parts).
	var place := Transform3D.IDENTITY

	func _add(v: Vector3, n: Vector3, color: Color) -> void:
		verts.append(place * v)
		normals.append((place.basis * n).normalized())
		colors.append(Color(color.r, color.g, color.b, own))
		uvs.append(Vector2(share.y, eaten))
		uv2s.append(Vector2(share.x, share.z))

	func ellipsoid(at: Vector3, radii: Vector3, basis: Basis, color: Color, rings := 6, segments := 8) -> void:
		var first := verts.size()
		for j in rings + 1:
			var lat := PI * float(j) / rings - PI * 0.5
			for i in segments + 1:
				var lon := TAU * float(i) / segments
				var unit := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
				_add(at + basis * (unit * radii), basis * (unit / radii).normalized(), color)
		for j in rings:
			for i in segments:
				var a := first + j * (segments + 1) + i
				var b := a + segments + 1
				indices.append_array([a, a + 1, b, a + 1, b + 1, b])

	## A tube along `points`, `radii` thick at each (as many as points, or one for all).
	func tube(points: PackedVector3Array, radii: PackedFloat32Array, color: Color, sides := 6, capped := true) -> void:
		var first := verts.size()
		var count := points.size()
		var side_ref := Vector3.UP
		for k in count:
			var ahead := (points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)]).normalized()
			if absf(ahead.dot(side_ref)) > 0.9:
				side_ref = Vector3.RIGHT
			var x := ahead.cross(side_ref).normalized()
			var y := x.cross(ahead).normalized()
			side_ref = y
			var radius: float = radii[mini(k, radii.size() - 1)]
			for i in sides + 1:
				var a := TAU * float(i) / sides
				var out := x * cos(a) + y * sin(a)
				_add(points[k] + out * radius, out, color)
		for k in count - 1:
			for i in sides:
				var a := first + k * (sides + 1) + i
				var b := a + sides + 1
				indices.append_array([a, b, a + 1, a + 1, b, b + 1])
		if capped:
			for end: int in [0, count - 1]:
				var radius: float = radii[mini(end, radii.size() - 1)]
				ellipsoid(points[end], Vector3.ONE * radius * 1.05, Basis.IDENTITY, color, 3, sides)

	func box(at: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
		var half := size * 0.5
		var faces := [
			[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
			[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
			[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
			[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
			[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		]
		for face: Array in faces:
			var n: Vector3 = face[0]
			var u: Vector3 = face[1]
			var v: Vector3 = face[2]
			var first := verts.size()
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				_add(at + basis * ((n + u * corner.x + v * corner.y) * half), basis * n, color)
			indices.append_array([first, first + 2, first + 1, first, first + 3, first + 2])

	## A sheet (cloth, a strip of bandage): `points` along its middle, `widths` across, waved.
	func sheet(points: PackedVector3Array, across: Vector3, widths: PackedFloat32Array, color: Color, wave := 0.05) -> void:
		var first := verts.size()
		var count := points.size()
		for k in count:
			var w: float = widths[mini(k, widths.size() - 1)]
			var ahead := (points[mini(k + 1, count - 1)] - points[maxi(k - 1, 0)]).normalized()
			var n := ahead.cross(across).normalized()
			for side in [-1.0, 0.0, 1.0]:
				var lift := n * sin(k * 1.7 + side * 2.0) * wave
				_add(points[k] + across * w * 0.5 * side + lift, n, color)
		for k in count - 1:
			for i in 2:
				var a := first + k * 3 + i
				var b := a + 3
				indices.append_array([a, b, a + 1, a + 1, b, b + 1])

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var made := ArrayMesh.new()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return made


## Everything in it, as one mesh: `count` pieces chosen and placed by `seed_value`.
## Pieces are human-sized (a skeleton is about 1.7 m); the bigger the jelly, the more room between them.
static func contents(seed_value: int, count := 18) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made := Pieces.new()
	# What it has: always two whole skeletons and a ribcage with its skull; then the rest, by chance.
	var kinds: Array[String] = ["skeleton", "skeleton", "torso", "skull", "skull", "pelvis", "boot", "shirt", "rope", "beast", "bandage", "blade", "hand", "femur", "femur", "bones", "bones", "vertebrae", "skull", "arm", "plate", "boot", "skeleton", "torso", "skull", "bones", "hand", "femur", "vertebrae", "skull", "pelvis", "arm", "bones", "shirt", "beast", "skull", "bones", "femur", "vertebrae", "torso"]
	var placed: Array[Vector3] = []
	for k in mini(count, kinds.size()):
		var kind := kinds[k]
		# Where it hangs: apart from the others; a few have sunk to the bottom.
		var share := Vector3.ZERO
		var sunk := rng.randf() < 0.3 and kind not in ["skeleton", "torso", "shirt", "bandage"]
		for attempt in 24:
			share = Vector3(rng.randf_range(-0.85, 0.85), rng.randf_range(-0.85, -0.7) if sunk else rng.randf_range(-0.55, 0.75), rng.randf_range(-0.7, 0.7))
			var ok := true
			for other in placed:
				if Vector3((share.x - other.x) * 1.6, share.y - other.y, (share.z - other.z) * 0.8).length() < 0.3:
					ok = false
					break
			if ok:
				break
		placed.append(share)
		made.share = share
		made.own = rng.randf()
		made.eaten = rng.randf_range(0.1, 0.75)
		made.place = Transform3D.IDENTITY
		match kind:
			"skeleton":
				_skeleton(made, rng, true)
			"torso":
				_skeleton(made, rng, false)
			"skull":
				_skull(made, Vector3.ZERO, Basis.IDENTITY, BONE if rng.randf() < 0.5 else OLD_BONE, rng.randf() < 0.6)
			"pelvis":
				_pelvis(made, Vector3.ZERO, Basis.IDENTITY, OLD_BONE)
			"femur":
				_long_bone(made, Vector3(0, -0.24, 0), Vector3(0, 0.24, 0), 0.02, BONE)
			"arm":
				_arm(made, Vector3.ZERO, Basis.from_euler(Vector3(0.4, 0.0, 1.2)), BONE, 0.9)
			"hand":
				_hand(made, Vector3.ZERO, Basis.IDENTITY, BONE, 0.7)
			"bones":
				for b in 4:
					var from := Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
					var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
					_long_bone(made, from, from + dir * rng.randf_range(0.18, 0.34), rng.randf_range(0.009, 0.016), OLD_BONE)
			"vertebrae":
				for b in 6:
					var at := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
					_vertebra(made, at, Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)), OLD_BONE)
			"boot":
				_boot(made)
			"shirt":
				_shirt(made, rng)
			"rope":
				_rope(made)
			"beast":
				_beast_skull(made)
			"bandage":
				_bandage(made, rng)
			"blade":
				_blade(made)
			"plate":
				made.box(Vector3.ZERO, Vector3(0.42, 0.012, 0.3), Basis.from_euler(Vector3(0.1, 0.4, 0.05)), RUST)
				made.box(Vector3(0.0, 0.01, 0.0), Vector3(0.05, 0.03, 0.05), Basis.IDENTITY, RUST.darkened(0.3))
	# Specks of what is not yet gone, and bubbles, hanging all through it.
	made.place = Transform3D.IDENTITY
	for k in 70:
		made.share = Vector3(rng.randf_range(-0.95, 0.95), rng.randf_range(-0.9, 0.9), rng.randf_range(-0.85, 0.85))
		made.own = rng.randf()
		made.eaten = rng.randf_range(0.3, 0.9)
		if k % 3 == 0:
			made.eaten = 0.0
			made.ellipsoid(Vector3.ZERO, Vector3.ONE * rng.randf_range(0.025, 0.07), Basis.IDENTITY, Color(0.86, 0.92, 0.8), 3, 5)
		else:
			var size := rng.randf_range(0.02, 0.06)
			made.box(Vector3.ZERO, Vector3(size, size * rng.randf_range(0.3, 1.0), size * rng.randf_range(0.5, 1.5)), Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0.0)), [OLD_BONE, LEATHER, RUST, SHIRT, Color(0.2, 0.18, 0.1)][k % 5])
	_against_faces(made, rng)
	return made.mesh()


static func _long_bone(made: Pieces, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var mid := (from + to) * 0.5
	var points := PackedVector3Array([from, from.lerp(to, 0.15), mid, from.lerp(to, 0.85), to])
	made.tube(points, PackedFloat32Array([radius * 1.3, radius, radius * 0.85, radius, radius * 1.3]), color, 6, false)
	var along := (to - from).normalized()
	var side := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
	for end: Vector3 in [from, to]:
		made.ellipsoid(end + side * radius * 0.6, Vector3.ONE * radius * 1.7, Basis.IDENTITY, color, 4, 6)
		made.ellipsoid(end - side * radius * 0.6, Vector3.ONE * radius * 1.5, Basis.IDENTITY, color, 4, 6)


static func _vertebra(made: Pieces, at: Vector3, basis: Basis, color: Color) -> void:
	made.ellipsoid(at, Vector3(0.024, 0.016, 0.022), basis, color, 4, 6)
	made.box(at + basis * Vector3(0, 0, -0.03), Vector3(0.012, 0.012, 0.035), basis, color)
	made.box(at + basis * Vector3(0, 0, -0.015), Vector3(0.06, 0.01, 0.01), basis, color)


static func _skull(made: Pieces, at: Vector3, basis: Basis, color: Color, jaw := true) -> void:
	# Cranium, face, cheekbones, the dark holes of the eyes and nose, teeth; the jaw if it has kept it.
	made.ellipsoid(at + basis * Vector3(0, 0.06, -0.02), Vector3(0.075, 0.08, 0.095), basis, color, 7, 10)
	made.ellipsoid(at + basis * Vector3(0, 0.0, 0.05), Vector3(0.055, 0.055, 0.04), basis, color, 5, 8)
	for s in [-1.0, 1.0]:
		made.ellipsoid(at + basis * Vector3(0.028 * s, 0.025, 0.072), Vector3(0.019, 0.017, 0.012), basis, DARK, 4, 6)
		made.ellipsoid(at + basis * Vector3(0.055 * s, 0.005, 0.045), Vector3(0.02, 0.012, 0.025), basis, color, 3, 6)
	made.ellipsoid(at + basis * Vector3(0, -0.008, 0.088), Vector3(0.008, 0.012, 0.006), basis, DARK, 3, 5)
	for i in 6:
		var x := (float(i) - 2.5) * 0.009
		made.box(at + basis * Vector3(x, -0.036, 0.078 - absf(x) * 0.4), Vector3(0.007, 0.012, 0.006), basis, Color(0.9, 0.86, 0.72))
	if jaw:
		var hang := Basis(Vector3.RIGHT, 0.35)
		var jaw_points := PackedVector3Array()
		for i in 7:
			var a := lerpf(-1.2, 1.2, float(i) / 6.0)
			jaw_points.append(at + basis * (Vector3(0, -0.035, 0.0) + hang * Vector3(sin(a) * 0.05, -0.02 - absf(cos(a)) * 0.01, cos(a) * 0.065 - 0.01)))
		made.tube(jaw_points, PackedFloat32Array([0.009]), color, 5, true)


static func _ribcage(made: Pieces, at: Vector3, basis: Basis, color: Color, ribs := 7) -> void:
	# The spine down its back, ribs curving round from it, and the breastbone.
	var spine := PackedVector3Array()
	for i in 12:
		spine.append(at + basis * Vector3(0, 0.46 - i * 0.045, -0.08))
	made.tube(spine, PackedFloat32Array([0.016]), color, 5, true)
	for i in 12:
		made.box(at + basis * Vector3(0, 0.46 - i * 0.045, -0.105), Vector3(0.012, 0.02, 0.03), basis, color)
	for i in ribs:
		var y := 0.42 - i * 0.05
		var wide := 0.1 + 0.05 * sin(float(i + 1) / ribs * PI)
		for s in [-1.0, 1.0]:
			var points := PackedVector3Array()
			for k in 9:
				var phi := float(k) / 8.0 * PI * (0.88 if i < ribs - 2 else 0.6)
				points.append(at + basis * Vector3(s * wide * sin(phi), y - 0.045 * float(k) / 8.0, -0.08 + 0.115 * (1.0 - cos(phi))))
			made.tube(points, PackedFloat32Array([0.007]), color, 4, false)
	made.box(at + basis * Vector3(0, 0.3, 0.15), Vector3(0.03, 0.18, 0.012), basis, color)


static func _pelvis(made: Pieces, at: Vector3, basis: Basis, color: Color) -> void:
	for s in [-1.0, 1.0]:
		made.ellipsoid(at + basis * Vector3(0.08 * s, 0.03, -0.01), Vector3(0.07, 0.065, 0.018), basis * Basis(Vector3.UP, 0.6 * s), color, 5, 8)
	made.box(at + basis * Vector3(0, 0.02, -0.06), Vector3(0.06, 0.08, 0.03), basis, color)
	var ring := PackedVector3Array()
	for k in 11:
		var a := PI * float(k) / 10.0
		ring.append(at + basis * Vector3(cos(a) * 0.08, -0.035, sin(a) * 0.06 - 0.01))
	made.tube(ring, PackedFloat32Array([0.012]), color, 5, true)


static func _hand(made: Pieces, at: Vector3, basis: Basis, color: Color, curl := 0.5) -> void:
	made.box(at, Vector3(0.07, 0.015, 0.075), basis, color)
	for f in 5:
		var spread := (float(f) - 2.0) * 0.17
		var from := Vector3((float(f) - 2.0) * 0.016, 0.0, 0.035)
		var points := PackedVector3Array([at + basis * from])
		var dir := Vector3(sin(spread), 0.0, cos(spread))
		var p := from
		for j in 3:
			dir = (dir + Vector3(0, -curl * 0.6, 0)).normalized()
			p += dir * (0.032 - j * 0.006) * (0.75 if f == 0 else 1.0)
			points.append(at + basis * p)
		made.tube(points, PackedFloat32Array([0.005]), color, 4, true)


static func _arm(made: Pieces, at: Vector3, basis: Basis, color: Color, bend: float) -> void:
	var elbow := at + basis * Vector3(0, -0.3, 0)
	var wrist := elbow + basis * (Basis(Vector3.RIGHT, -bend) * Vector3(0, -0.26, 0))
	_long_bone(made, at, elbow, 0.014, color)
	_long_bone(made, elbow, wrist + basis * Vector3(0.012, 0, 0), 0.009, color)
	_long_bone(made, elbow + basis * Vector3(0.015, 0, 0), wrist - basis * Vector3(0.006, 0, 0), 0.008, color)
	_hand(made, wrist + basis * (Basis(Vector3.RIGHT, -bend) * Vector3(0, -0.045, 0)), basis * Basis(Vector3.RIGHT, -bend - PI * 0.5), color, 0.7)


static func _leg(made: Pieces, at: Vector3, basis: Basis, color: Color, bend: float) -> void:
	var knee := at + basis * Vector3(0, -0.43, 0)
	var ankle := knee + basis * (Basis(Vector3.RIGHT, bend) * Vector3(0, -0.4, 0))
	_long_bone(made, at, knee, 0.02, color)
	_long_bone(made, knee, ankle, 0.016, color)
	_long_bone(made, knee + basis * Vector3(0.03, 0, 0), ankle + basis * Vector3(0.025, 0, 0), 0.008, color)
	made.ellipsoid(knee + basis * Vector3(0, 0, 0.03), Vector3(0.022, 0.026, 0.012), basis, color, 3, 6)
	var foot := basis * Basis(Vector3.RIGHT, bend)
	made.box(ankle + foot * Vector3(0, -0.02, 0.06), Vector3(0.06, 0.025, 0.16), foot, color)


## A skeleton (or, not whole, a ribcage with its skull and an arm), posed as it fell, about 1.7 m.
static func _skeleton(made: Pieces, rng: RandomNumberGenerator, whole: bool) -> void:
	var color := BONE if rng.randf() < 0.5 else OLD_BONE
	var body := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.2, 0.2)))
	_ribcage(made, Vector3(0, 0.0, 0), body, color)
	var neck := body * Vector3(0, 0.56, -0.04)
	var head := body * Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-0.4, 0.4)))
	_skull(made, neck + head * Vector3(0, 0.07, 0.0), head, color, rng.randf() < 0.7)
	for s in [-1.0, 1.0]:
		var shoulder := body * Vector3(0.19 * s, 0.45, -0.05)
		made.tube(PackedVector3Array([body * Vector3(0.02 * s, 0.5, 0.06), shoulder]), PackedFloat32Array([0.008]), color, 4, true)
		if whole or s < 0.0:
			_arm(made, shoulder, body * Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.0), 0.0, s * rng.randf_range(0.2, 1.4))), color, rng.randf_range(0.2, 1.6))
	if whole:
		var spine := PackedVector3Array()
		for i in 5:
			spine.append(body * Vector3(0, -0.08 - i * 0.04, -0.08))
		made.tube(spine, PackedFloat32Array([0.015]), color, 5, true)
		var hips := body * Vector3(0, -0.3, -0.04)
		_pelvis(made, hips, body, color)
		for s in [-1.0, 1.0]:
			_leg(made, hips + body * Vector3(0.09 * s, -0.04, 0.0), body * Basis.from_euler(Vector3(rng.randf_range(-1.1, 0.5), 0.0, s * rng.randf_range(0.0, 0.5))), color, rng.randf_range(0.1, 1.4))


static func _boot(made: Pieces) -> void:
	made.box(Vector3(0, -0.12, 0.04), Vector3(0.1, 0.025, 0.27), Basis.IDENTITY, DARK)
	made.ellipsoid(Vector3(0, -0.08, 0.06), Vector3(0.055, 0.045, 0.13), Basis.IDENTITY, LEATHER, 5, 8)
	made.tube(PackedVector3Array([Vector3(0, -0.08, -0.03), Vector3(0, 0.05, -0.04), Vector3(0.005, 0.14, -0.035)]), PackedFloat32Array([0.05, 0.048, 0.052]), LEATHER, 8, false)
	_long_bone(made, Vector3(0, 0.02, -0.04), Vector3(0.01, 0.26, -0.05), 0.012, OLD_BONE)


## A torn scrap of a red shirt like the runners wear: someone was here before.
static func _shirt(made: Pieces, rng: RandomNumberGenerator) -> void:
	for strip in 3:
		var points := PackedVector3Array()
		var x := (float(strip) - 1.0) * 0.14
		for k in 8:
			var y := 0.25 - k * 0.07
			points.append(Vector3(x + sin(k * 0.9 + strip) * 0.03, y, sin(k * 0.7 + strip * 1.3) * 0.06))
		var widths := PackedFloat32Array()
		for k in 8:
			widths.append(0.15 * (1.0 - 0.6 * rng.randf() * float(k) / 7.0))
		made.sheet(points, Vector3.RIGHT, widths, SHIRT, 0.03)


static func _rope(made: Pieces) -> void:
	var points := PackedVector3Array()
	for k in 60:
		var a := float(k) * 0.42
		var r := 0.16 + 0.015 * sin(k * 0.5)
		points.append(Vector3(cos(a) * r, float(k) * 0.0045 - 0.13, sin(a) * r))
	for k in 10:
		points.append(points[points.size() - 1] + Vector3(0.05, -0.02, 0.06).rotated(Vector3.UP, k * 0.3))
	made.tube(points, PackedFloat32Array([0.016]), ROPE, 5, true)


## The skull of something horned that wandered in.
static func _beast_skull(made: Pieces) -> void:
	made.ellipsoid(Vector3(0, 0.03, -0.05), Vector3(0.08, 0.075, 0.1), Basis.IDENTITY, BONE, 6, 9)
	made.tube(PackedVector3Array([Vector3(0, 0.02, 0.0), Vector3(0, 0.0, 0.12), Vector3(0, -0.02, 0.24)]), PackedFloat32Array([0.055, 0.045, 0.03]), BONE, 7, true)
	for s in [-1.0, 1.0]:
		made.ellipsoid(Vector3(0.05 * s, 0.04, 0.02), Vector3(0.018, 0.016, 0.014), Basis.IDENTITY, DARK, 3, 6)
		var horn := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 12:
			var a := float(k) * 0.42
			horn.append(Vector3(s * (0.07 + 0.04 * a), 0.09 + sin(a) * 0.09, -0.08 - cos(a) * 0.09 + 0.09))
			radii.append(0.028 * (1.0 - float(k) / 13.0))
		made.tube(horn, radii, HORN, 6, true)


static func _bandage(made: Pieces, rng: RandomNumberGenerator) -> void:
	var points := PackedVector3Array()
	for k in 16:
		var t := float(k) / 15.0
		points.append(Vector3(sin(t * 7.0) * 0.18, 0.5 - t * 1.0, cos(t * 5.0 + rng.randf()) * 0.12))
	made.sheet(points, Vector3(1, 0, 0.3).normalized(), PackedFloat32Array([0.07]), LINEN, 0.02)


static func _blade(made: Pieces) -> void:
	made.box(Vector3(0, 0.25, 0), Vector3(0.05, 0.62, 0.008), Basis.IDENTITY, RUST)
	made.box(Vector3(0, 0.6, 0), Vector3(0.012, 0.09, 0.006), Basis(Vector3.FORWARD, 0.0) * Basis.from_scale(Vector3(1, 1, 1)), RUST)
	made.box(Vector3(0, -0.07, 0), Vector3(0.16, 0.025, 0.03), Basis.IDENTITY, RUST.darkened(0.25))
	made.tube(PackedVector3Array([Vector3(0, -0.08, 0), Vector3(0, -0.22, 0)]), PackedFloat32Array([0.016]), LEATHER, 6, true)


## Puts a piece against a face: `side` 1 the front, -1 the back; `inset` how
## far in from it (metres; about zero pokes out of it), `across` and `up` where
## on the face (-1..1), and `turned` how it lies, as it is built (it is not
## tumbled by the shader, only rocked).
static func _on_face(made: Pieces, rng: RandomNumberGenerator, side: float, inset: float, across: float, up: float, turned: Basis) -> void:
	made.share = Vector3(across, up, side * maxf(inset, 0.001))
	made.own = rng.randf()
	made.eaten = -rng.randf_range(0.05, 0.45) - 0.001
	made.place = Transform3D(turned, Vector3.ZERO)


## What is seen best of it: bodies just inside its faces, under a thin skin of
## jelly; two great beasts' bones; bones and an arm poking out; hands pressed
## against the inside of the front.
static func _against_faces(made: Pieces, rng: RandomNumberGenerator) -> void:
	# Twelve people, seven at the front and five at the back, spread across it, each as it fell.
	var slots := [-0.85, -0.57, -0.28, 0.0, 0.28, 0.57, 0.85]
	for k in range(6, 0, -1):
		var j := rng.randi_range(0, k)
		var swap: float = slots[k]
		slots[k] = slots[j]
		slots[j] = swap
	for k in 12:
		var side := 1.0 if k < 7 else -1.0
		var across: float = slots[k % 7] + rng.randf_range(-0.08, 0.08)
		if side < 0.0:
			across = -across * 0.8
		var lean := Basis(Vector3.BACK, rng.randf_range(-1.3, 1.3)) * Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
		_on_face(made, rng, side, rng.randf_range(0.3, 1.0), across, rng.randf_range(-0.45, 0.5), lean)
		_skeleton(made, rng, k % 4 != 3)
	# A great beast against the back, and the long spine of something against the front.
	_on_face(made, rng, -1.0, 1.0, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3)))
	_big_beast(made)
	_on_face(made, rng, 1.0, 0.75, rng.randf_range(-0.4, 0.4), rng.randf_range(0.3, 0.6), Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)))
	_long_spine(made)
	# Bones poking out of it: two at the front, one at the back; and an arm reaching out of the front.
	for k in 3:
		var side := 1.0 if k < 2 else -1.0
		_on_face(made, rng, side, 0.05, rng.randf_range(-0.85, 0.85), rng.randf_range(-0.6, 0.7), Basis(Vector3.RIGHT, side * rng.randf_range(1.1, 1.4)) * Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6)))
		_long_bone(made, Vector3(0, -0.24, 0), Vector3(0, 0.24, 0), 0.022, OLD_BONE)
	_on_face(made, rng, 1.0, 0.2, rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.3), Basis(Vector3.RIGHT, PI * 0.5 + 0.25) * Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)))
	_arm(made, Vector3.ZERO, Basis.IDENTITY, BONE, 0.35)
	_on_face(made, rng, -1.0, 0.1, rng.randf_range(-0.7, 0.7), rng.randf_range(0.0, 0.6), Basis(Vector3.UP, PI))
	_skull(made, Vector3.ZERO, Basis.IDENTITY, OLD_BONE, false)
	# Hands pressed flat against the inside of the front, a little way apart.
	var at_x := rng.randf_range(-0.5, 0.5)
	var at_y := rng.randf_range(-0.35, 0.1)
	for k in 2:
		_on_face(made, rng, 1.0, 0.06, at_x + (k - 0.5) * 0.06, at_y + k * 0.03, Basis(Vector3.BACK, (k - 0.5) * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5))
		made.eaten = -0.02
		_hand(made, Vector3.ZERO, Basis.IDENTITY, BONE, 0.1)


## The bones of something as big as a horse: a long arched spine with spines
## along its top, ribs hung from it, a long skull, and its legs trailing.
static func _big_beast(made: Pieces) -> void:
	var color := OLD_BONE
	var spine := PackedVector3Array()
	for k in 16:
		var x := lerpf(-1.4, 1.5, float(k) / 15.0)
		spine.append(Vector3(x, 0.12 * sin(float(k) / 15.0 * PI), 0.0))
	made.tube(spine, PackedFloat32Array([0.05]), color, 6, true)
	for k in 22:
		var x := lerpf(-1.3, 1.45, float(k) / 21.0)
		var y := 0.12 * sin((x + 1.4) / 2.9 * PI)
		made.box(Vector3(x, y + 0.05, 0.0), Vector3(0.07, 0.09, 0.09), Basis.IDENTITY, color)
		made.box(Vector3(x, y + 0.14, 0.0), Vector3(0.025, 0.2 * (1.0 - absf(x) * 0.35), 0.03), Basis(Vector3.BACK, 0.25), color)
	for k in 9:
		var x := lerpf(-0.9, 0.55, float(k) / 8.0)
		var r := 0.38 + 0.18 * sin(float(k + 1) / 9.0 * PI)
		for s in [-1.0, 1.0]:
			var points := PackedVector3Array()
			for j in 9:
				var phi := float(j) / 8.0 * PI * 0.85
				points.append(Vector3(x + float(j) * 0.012, 0.1 - r * (1.0 - cos(phi)) * 1.1, s * r * sin(phi)))
			made.tube(points, PackedFloat32Array([0.022, 0.02, 0.016]), color, 5, false)
	# The skull, long, at the front end, hung low.
	var head := Vector3(-1.75, -0.12, 0.0)
	made.ellipsoid(head, Vector3(0.24, 0.15, 0.13), Basis(Vector3.BACK, -0.4), color, 6, 9)
	made.tube(PackedVector3Array([head + Vector3(-0.1, -0.05, 0.0), head + Vector3(-0.4, -0.2, 0.0), head + Vector3(-0.62, -0.32, 0.0)]), PackedFloat32Array([0.11, 0.08, 0.06]), color, 7, true)
	made.tube(PackedVector3Array([head + Vector3(0.12, -0.12, 0.0), head + Vector3(-0.25, -0.33, 0.0), head + Vector3(-0.55, -0.43, 0.0)]), PackedFloat32Array([0.04, 0.035, 0.03]), color, 5, true)
	for s in [-1.0, 1.0]:
		made.ellipsoid(head + Vector3(-0.08, 0.04, s * 0.11), Vector3(0.05, 0.04, 0.025), Basis.IDENTITY, DARK, 3, 6)
	for k in 7:
		made.box(head + Vector3(-0.2 - k * 0.055, -0.27 - k * 0.022, 0.0), Vector3(0.025, 0.05, 0.05), Basis.IDENTITY, Color(0.86, 0.8, 0.64))
	# Its legs, trailing.
	for leg in [[-0.8, 1.0], [-0.8, -1.0], [1.2, 1.0], [1.2, -1.0]]:
		var top := Vector3(leg[0], -0.15, leg[1] * 0.25)
		var knee := top + Vector3(0.2 * leg[1], -0.75, 0.15 * leg[1])
		var hoof := knee + Vector3(-0.15, -0.7, 0.05 * leg[1])
		_long_bone(made, top, knee, 0.04, color)
		_long_bone(made, knee, hoof, 0.03, color)


## The spine of something long, a snake or worse: a winding run of vertebrae with short ribs.
static func _long_spine(made: Pieces) -> void:
	var points := PackedVector3Array()
	for k in 30:
		var t := float(k) / 29.0
		points.append(Vector3(lerpf(-1.8, 1.8, t), 0.35 * sin(t * TAU * 1.2), 0.08 * sin(t * 9.0)))
	made.tube(points, PackedFloat32Array([0.035]), OLD_BONE, 6, true)
	for k in range(1, 29):
		var at := points[k]
		var along := (points[k + 1] - points[k - 1]).normalized()
		var side := along.cross(Vector3.BACK).normalized()
		made.box(at, Vector3(0.06, 0.07, 0.07), Basis.IDENTITY, OLD_BONE)
		for s in [-1.0, 1.0]:
			made.tube(PackedVector3Array([at, at + side * s * 0.12 + Vector3(0, 0, 0.1), at + side * s * 0.2 + Vector3(0, 0, 0.18)]), PackedFloat32Array([0.012, 0.009, 0.006]), OLD_BONE, 4, false)
	made.ellipsoid(points[0] + Vector3(-0.12, 0.0, 0.0), Vector3(0.16, 0.09, 0.1), Basis.IDENTITY, OLD_BONE, 5, 8)
