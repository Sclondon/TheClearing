// An imp of an ImpSwarm (creatures/imp_swarm/imp_swarm.gd), many drawn at once
// by one MultiMesh. The mesh (models/imp_swarm.glb, made by
// creatures/imp/tools/build_imp.py) is one imp on all fours, standing still;
// its limbs are moved here. Each point says (UV) which part it is on and how
// far out along it (0 at the shoulder or hip, 1 at the claws), and (UV2.x,
// eighths) its colour: up to 1 how sooty its skin, then a part (2 eye, 3 teeth,
// 4 mouth, 5 claw or horn, 6 wing, 7 ear). Colours are not vertex colours
// because the web gives a MultiMesh's points none it can be sure of.
//
// Each imp's custom data:
//   x: how far through its stride (whole strides; it stops when it stands)
//   y: how hard it scuttles (0 standing, 1 flat out)
//   z: how splayed (0 on the ground, 1 flat against a wall or a body)
//   w: its own number, 0..1 (its jaw chatters and its skin differs by it)
//
// The scuttle is a trot: left hand with right foot, then the others; each
// limb swings fore and aft about its root and lifts as it comes forward; the
// tail lashes, the wings flutter, the jaw chatters. Lit in two flat tones, as
// ImpLook lights a single imp.

shader_type spatial;
render_mode cull_back, shadows_disabled;

uniform vec3 skin : source_color = vec3(0.2, 0.085, 0.06);
uniform vec3 soot : source_color = vec3(0.07, 0.055, 0.05);
uniform vec3 eye : source_color = vec3(1.0, 0.62, 0.12);
uniform vec3 tooth : source_color = vec3(0.8, 0.74, 0.58);
uniform vec3 mouth : source_color = vec3(0.16, 0.03, 0.03);
uniform vec3 claw : source_color = vec3(0.16, 0.13, 0.1);
uniform vec3 wing : source_color = vec3(0.13, 0.055, 0.045);
uniform vec3 ear : source_color = vec3(0.26, 0.11, 0.08);
uniform float swing = 0.1;
uniform float lift = 0.06;
uniform float rim_gain = 0.5;

// Where each part turns, in the mesh's units (from imp_swarm.json, written by
// build_imp.py: keep in step when the model is built again).
const vec3 ARM_L = vec3(0.083, 0.276, 0.114);
const vec3 ARM_R = vec3(-0.083, 0.276, 0.114);
const vec3 LEG_L = vec3(0.062, 0.213, -0.139);
const vec3 LEG_R = vec3(-0.062, 0.213, -0.139);
const vec3 TAIL = vec3(0.0, 0.277, -0.154);
const vec3 WINGS = vec3(0.0, 0.348, 0.113);
const vec3 JAW = vec3(0.0, 0.253, 0.228);
const vec3 HEAD = vec3(0.0, 0.237, 0.169);

// (flat: a triangle is one part, never a blend of two codes, which would pass through the others)
varying flat float code;
varying flat float glow;
varying float tone;

vec3 turn_x(vec3 p, vec3 about, float a) {
	vec3 q = p - about;
	float c = cos(a);
	float s = sin(a);
	return about + vec3(q.x, q.y * c - q.z * s, q.y * s + q.z * c);
}

vec3 turn_y(vec3 p, vec3 about, float a) {
	vec3 q = p - about;
	float c = cos(a);
	float s = sin(a);
	return about + vec3(q.x * c + q.z * s, q.y, -q.x * s + q.z * c);
}

vec3 turn_z(vec3 p, vec3 about, float a) {
	vec3 q = p - about;
	float c = cos(a);
	float s = sin(a);
	return about + vec3(q.x * c - q.y * s, q.x * s + q.y * c, q.z);
}

void vertex() {
	int part = int(UV.x * 16.0);
	float along = UV.y;
	float stride = INSTANCE_CUSTOM.x;
	float go = INSTANCE_CUSTOM.y;
	float splay = INSTANCE_CUSTOM.z;
	float own = INSTANCE_CUSTOM.w;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float t = TIME + own * 17.0;
	if (part >= 1 && part <= 4) {
		// (a trot: left hand with right foot)
		float offset = (part == 1 || part == 4) ? 0.0 : 0.5;
		float phase = (stride + offset) * TAU;
		float side = (part == 1 || part == 3) ? 1.0 : -1.0;
		// The foot slides fore and aft and lifts as it comes forward: the limb
		// leans with it, each point as much as it is out along it.
		float reach = smoothstep(0.0, 1.0, along);
		v.z += sin(phase) * swing * go * reach;
		v.y += max(cos(phase), 0.0) * lift * go * reach;
		// Splayed, the limbs go out to the side and down flat.
		v.x += side * splay * 0.1 * reach;
		v.y -= splay * 0.06 * reach;
	} else if (part == 5) {
		float a = sin(t * (3.0 + 6.0 * go) - along * 3.0) * (0.25 + 0.35 * go) * along;
		v = turn_y(v, TAIL, a);
		n = turn_y(n, vec3(0.0), a);
	} else if (part == 6) {
		float side = sign(v.x);
		v = turn_z(v, WINGS, side * sin(t * 26.0) * 0.35 * (0.3 + go) * along);
	} else if (part == 7) {
		float chatter = (0.5 + 0.5 * sin(t * 38.0)) * (0.15 + 0.35 * go);
		v = turn_x(v, JAW, chatter);
	} else if (part == 8) {
		v = turn_y(v, HEAD, sin(t * 2.3) * 0.25 * (1.0 - go));
	}
	v.y += abs(sin(stride * TAU)) * 0.025 * go * (1.0 - splay);
	v.y -= splay * 0.08 * smoothstep(0.15, 0.35, v.y);
	VERTEX = v;
	NORMAL = n;
	code = UV2.x * 8.0;
	glow = UV2.y;
	tone = 0.85 + 0.3 * fract(own * 7.31);
}

void fragment() {
	vec3 c = mix(skin, soot, clamp(code, 0.0, 1.0)) * tone;
	if (code > 1.5) {
		int which = int(code + 0.5);
		c = which == 2 ? eye : which == 3 ? tooth : which == 4 ? mouth : which == 5 ? claw : which == 6 ? wing : ear;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = eye * glow * 1.8;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.5) / 1.5;
	float lit = cut(facing, 0.05) * mix(0.55, 1.0, reach);
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, 0.6) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.75) * rim_gain * ALBEDO * 1.5 * strength * LIGHT_COLOR / PI;
}
