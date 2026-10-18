// A bat (creatures/bats/bat_body.gd makes the mesh), drawn many at once by one
// MultiMesh (BatColony). Each instance's custom data is how it is held:
//   x: how far through a wingbeat it is (0..1, round and round)
//   y: how hard it is flapping (0: wings held out still, gliding; 1: full beats)
//   z: how far its wings are folded (0: open; 1: wrapped round it, hanging,
//      and then its head is bowed forward, to look out from where it hangs)
//   w: its tone (1 as made; a little more or less, so no two are quite alike)
// What each vertex is, the mesh says (see BatBody): CUSTOM0.r the part (0 fur,
// 0.33 wing skin, 0.66 ear, 1 eye), CUSTOM0.g how light (the mantle of the fur;
// how thin the skin is), UV.y near 0 along a bone (where UV.x is 1) or, on an
// eye, out from its middle; UV2.y 1 on a wing (UV2.x 0 left, 1 right).
//
// Lit as Toon (scripts/toon.gd in The Clearing) lights figures: two flat tones
// with a one-pixel edge between them, and a rim. The fur's rim is wide and pale,
// as fur catches the light; the wings are thin dark skin that the light shines
// through from behind, most at their thin trailing edges, and that glows at its
// edges seen side on; the eyes are dark and wet, with a glint.

shader_type spatial;
render_mode cull_disabled;

uniform vec3 fur : source_color = vec3(0.13, 0.115, 0.11);
uniform vec3 mantle : source_color = vec3(0.22, 0.185, 0.16);
uniform vec3 skin : source_color = vec3(0.1, 0.086, 0.085);
uniform vec3 ear : source_color = vec3(0.36, 0.26, 0.25);
uniform vec3 bone : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 through : source_color = vec3(0.17, 0.075, 0.05);
uniform vec3 eye : source_color = vec3(0.95, 0.88, 0.72);
uniform float eye_glow = 0.9;
uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.4;
uniform float rim_width = 0.22;

// Where the wing hinges, as modelled (half-span 0.5): the shoulder and the
// wrist, out from the middle and along the body. Keep to BatBody's.
const float SHOULDER = 0.05;
const float SHOULDER_Z = 0.045;
const float WRIST = 0.22;
const float WRIST_Z = 0.075;
// How round the body is where a folded wing is wrapped about it.
const float WRAP = 0.062;
// Which way the leading finger runs from the wrist to the tip.
const vec2 LEAD = vec2(0.936, -0.351);
// Where the head turns on the neck (along, up), and how far it is bowed when folded.
const vec2 NECK = vec2(0.058, 0.011);
const float BOW = 0.95;

varying float part;
varying float shade;
varying float line;
varying float boned;
varying float tone;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	part = CUSTOM0.r;
	shade = CUSTOM0.g;
	line = UV.y;
	boned = UV.x;
	tone = INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : 1.0;
	float fold = INSTANCE_CUSTOM.z;
	if (UV2.y > 0.5) {
		float side = UV2.x > 0.5 ? 1.0 : -1.0;
		float beat = 6.2831853 * INSTANCE_CUSTOM.x;
		float strength = INSTANCE_CUSTOM.y;
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
		float round_by = min(out_from / WRAP, 1.8);
		vec3 wrapped = vec3(cos(round_by) * WRAP * 1.15, p.y * 0.3 - sin(round_by) * WRAP * 1.15, p.z);
		p = mix(p, wrapped, fold * at_arm);
		n = mix(n, vec3(cos(round_by), -sin(round_by), 0.0), fold * at_arm);
		p.x *= side;
		n.x *= side;
		VERTEX = p;
		NORMAL = n;
	} else if (fold > 0.0) {
		// Hanging, its head is bowed forward on its neck, so that (head down)
		// it looks out from the wall, ears pointing down.
		float at_head = smoothstep(NECK.x - 0.006, NECK.x + 0.014, VERTEX.z);
		float bow = -BOW * fold * at_head;
		VERTEX.zy = turn(VERTEX.zy - NECK, bow) + NECK;
		NORMAL.zy = turn(NORMAL.zy, bow);
	}
}

void fragment() {
	vec3 colour;
	bool is_skin = part > 0.17 && part < 0.5;
	bool is_ear = part >= 0.5 && part < 0.83;
	float on_bone = 0.0;
	if (part < 0.17) {
		colour = mix(fur, mantle, shade);
	} else if (is_skin) {
		colour = skin;
		// The bones of the fingers, a dark line a pixel or so wide at any distance.
		float pixel = max(fwidth(line), 0.0001);
		on_bone = (1.0 - smoothstep(0.0, pixel * 1.3, line)) * boned;
		colour = mix(colour, bone, on_bone);
	} else if (is_ear) {
		// (pale in the hollow, which its normals face out of)
		colour = dot(NORMAL, VIEW) > 0.0 ? ear : skin;
	} else {
		colour = vec3(0.025, 0.02, 0.02);
		EMISSION = eye * eye_glow * (1.0 - smoothstep(0.1, 0.2, line));
	}
	ALBEDO = colour * tone;
	SPECULAR = 0.0;
	// What light() needs to know, passed in what it can read (varyings do not
	// reach it everywhere): ROUGHNESS says what this is (1 fur, 0.75 skin, 0.5
	// an eye), BACKLIGHT the colour of its rim (fur) or of the light through it (skin).
	if (part < 0.17) {
		ROUGHNESS = 1.0;
		BACKLIGHT = mix(fur * 1.6, mantle * 1.1, shade);
	} else if (part < 0.83) {
		ROUGHNESS = 0.75;
		BACKLIGHT = through * (0.25 + 0.75 * shade) * (1.0 - 0.85 * on_bone);
	} else {
		ROUGHNESS = 0.5;
		BACKLIGHT = vec3(0.0);
	}
	// (both sides of a wing or an ear are its outside: lit from whichever is seen;
	// the body is closed, and its normals are made to face out)
	if ((is_skin || is_ear) && dot(NORMAL, VIEW) < 0.0) {
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
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (ROUGHNESS > 0.6 && ROUGHNESS < 0.9) {
		// Light from behind shines through the skin, most where it is thin;
		// and side on, its edges glow.
		float behind = cut(-dot(NORMAL, LIGHT), 0.05);
		// (added as it comes through, not as the surface's colour lit)
		SPECULAR_LIGHT += behind * BACKLIGHT * strength * LIGHT_COLOR / PI;
		float edge = cut(graze, 0.8) * smoothstep(0.5, 0.95, length(BACKLIGHT) / max(length(through), 0.001));
		SPECULAR_LIGHT += edge * BACKLIGHT * 0.4 * strength * LIGHT_COLOR / PI;
	} else if (ROUGHNESS > 0.9) {
		// Fur catches the light all round its edge, palest on the mantle.
		float rim = cut(graze, 1.0 - rim_width) * mix(lit, 1.0, 0.4);
		SPECULAR_LIGHT += rim * rim_gain * BACKLIGHT * strength * LIGHT_COLOR / PI;
	} else {
		// A wet eye: one small bright light on it.
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 220.0), 0.5);
		SPECULAR_LIGHT += shine * 1.5 * LIGHT_COLOR;
	}
}
