// A bat (creatures/bats/bat_body.gd makes the mesh), drawn many at once by one
// MultiMesh (BatColony). Each instance's custom data is how its wings are held:
//   x: how far through a wingbeat it is (0..1, round and round)
//   y: how hard it is flapping (0: wings held out still, gliding; 1: full beats)
//   z: how far its wings are folded (0: open; 1: wrapped round it, hanging)
//   w: its tone (1 as made; a little more or less, so no two are quite alike)
// The mesh says what each vertex is: UV2.y is 1 on a wing (UV2.x 0 on the
// left, 1 on the right), UV.y is near 0 along a bone (where UV.x is 1), COLOR.r
// is the part (0 fur, 0.5 skin, 1 an eye).
//
// Lit as Toon (scripts/toon.gd in The Clearing) lights figures: two flat tones
// with a one-pixel edge between them, and a rim. The wing skin also lets a
// little light through from behind.

shader_type spatial;
render_mode cull_disabled;

uniform vec3 fur : source_color = vec3(0.15, 0.135, 0.13);
uniform vec3 skin : source_color = vec3(0.26, 0.22, 0.21);
uniform vec3 bone : source_color = vec3(0.08, 0.07, 0.07);
uniform vec3 through : source_color = vec3(0.3, 0.17, 0.14);
uniform vec3 eye : source_color = vec3(0.95, 0.88, 0.72);
uniform float eye_glow = 0.8;
uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.7;
uniform float rim_width = 0.16;

// Where the wing hinges, as modelled (half-span 0.5): the shoulder and the
// wrist, out from the middle and along the body. Keep to BatBody's.
const float SHOULDER = 0.05;
const float SHOULDER_Z = 0.045;
const float WRIST = 0.22;
const float WRIST_Z = 0.075;
// How round the body is where a folded wing is wrapped about it.
const float WRAP = 0.05;
// Which way the leading finger runs from the wrist to the tip.
const vec2 LEAD = vec2(0.936, -0.351);

varying float part;
varying float line;
varying float boned;
varying float tone;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	part = COLOR.r;
	line = UV.y;
	boned = UV.x;
	tone = INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : 1.0;
	if (UV2.y > 0.5) {
		float side = UV2.x > 0.5 ? 1.0 : -1.0;
		float beat = 6.2831853 * INSTANCE_CUSTOM.x;
		float strength = INSTANCE_CUSTOM.y;
		float fold = INSTANCE_CUSTOM.z;
		float open = 1.0 - fold;
		// The arm beats; the hand follows it a moment late, so the wing rolls
		// and its tip flicks; the stroke goes forward on the way down. Held
		// still (gliding), the arms are raised a little and the hands bowed.
		float arm = strength * (0.78 * sin(beat) + 0.1) + (1.0 - strength) * 0.08;
		float hand = strength * 0.55 * sin(beat - 1.1) - (1.0 - strength) * 0.1;
		float sweep = strength * 0.16 * cos(beat);
		vec3 p = VERTEX;
		vec3 n = NORMAL;
		p.x *= side;
		n.x *= side;
		float at_hand = smoothstep(WRIST - 0.05, WRIST + 0.03, p.x);
		float at_arm = smoothstep(SHOULDER, SHOULDER + 0.08, p.x);
		// Folding, as a bat folds: the fingers close up like a fan and the hand
		// swings back along the forearm; the arm swings back along the body
		// (the skin between gathering in); and the folded wing is wrapped down
		// round the belly.
		vec2 aside = vec2(-LEAD.y, LEAD.x);
		vec2 from_wrist = vec2(p.x - WRIST, p.z - WRIST_Z);
		vec2 fanned = LEAD * dot(from_wrist, LEAD) * (1.0 - 0.45 * fold) + aside * dot(from_wrist, aside) * (1.0 - 0.85 * fold);
		from_wrist = turn(mix(from_wrist, fanned, at_hand), -2.75 * fold * at_hand);
		n.xz = turn(n.xz, -2.75 * fold * at_hand);
		p.xz = from_wrist + vec2(WRIST, WRIST_Z);
		p.x = SHOULDER + (p.x - SHOULDER) * (1.0 - 0.45 * fold * (1.0 - at_hand));
		float back = (-1.45 * fold - sweep) * at_arm;
		p.xz = turn(vec2(p.x - SHOULDER, p.z - SHOULDER_Z), back) + vec2(SHOULDER, SHOULDER_Z);
		n.xz = turn(n.xz, back);
		// The hand's flick about the wrist, and the beat about the shoulder.
		p.xy = turn(vec2(p.x - WRIST, p.y), hand * open * at_hand) + vec2(WRIST, 0.0);
		n.xy = turn(n.xy, hand * open * at_hand);
		float lift = arm * open * at_arm;
		p.xy = turn(vec2(p.x - SHOULDER, p.y), lift) + vec2(SHOULDER, 0.0);
		n.xy = turn(n.xy, lift);
		// Folded up, the strip of wing beside the body is wrapped round its
		// belly like a cloak, the two meeting down the middle.
		float out_from = max(p.x - 0.03, 0.0);
		float round_by = min(out_from / WRAP, 1.75);
		vec3 wrapped = vec3(cos(round_by) * WRAP * 1.15, p.y * 0.3 - sin(round_by) * WRAP * 1.15, p.z);
		p = mix(p, wrapped, fold * at_arm);
		n = mix(n, vec3(cos(round_by), -sin(round_by), 0.0), fold * at_arm);
		p.x *= side;
		n.x *= side;
		VERTEX = p;
		NORMAL = n;
	}
}

void fragment() {
	vec3 colour = part < 0.25 ? fur : skin;
	// The bones of the fingers, a dark line a pixel or so wide at any distance.
	float pixel = max(fwidth(line), 0.0001);
	float on_bone = (1.0 - smoothstep(0.0, pixel * 1.3, line)) * boned;
	colour = mix(colour, bone, on_bone);
	ALBEDO = colour * tone;
	if (part > 0.75) {
		ALBEDO = eye * 0.4;
		EMISSION = eye * eye_glow;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (both sides of a wing are its outside: it is lit from whichever is seen)
	if (part > 0.25 && part < 0.75 ? dot(NORMAL, VIEW) < 0.0 : !FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// Light from behind a wing glows through its skin (not its fur).
	float behind = cut(-dot(NORMAL, LIGHT), 0.1) * step(0.25, part) * step(part, 0.75);
	DIFFUSE_LIGHT += behind * through * strength * LIGHT_COLOR / PI / max(ALBEDO, vec3(0.05));
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
