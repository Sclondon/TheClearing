// A bat (creatures/bats/bat_body.gd makes the mesh), drawn many at once by one
// MultiMesh (BatColony). Each instance's custom data is how it is moving:
//   x: how far through a wingbeat it is (0..1, round and round; 0 is the top)
//   y: how hard it is flapping (0: wings held out still, gliding; 1: full beats)
//   z: how far its wings are folded (0: open; 1: wrapped round it, hanging,
//      and then its head is bowed forward, to look out from where it hangs)
//   w: how much it is hovering or braking (deep, cupped, forward strokes)
//
// THE WINGS ARE HANDS, and posed here as a skeleton (BatBody numbers the
// bones): the shoulder (raising, sweeping, twisting the upper arm), the elbow
// and the wrist (bending in the plane of the wing), each finger spread from
// the wrist and its phalanges bent at the knuckle. Every wing vertex is
// carried by one bone or shared between two (CUSTOM1), and posed by each bone
// in turn from the tip to the shoulder, about the joints where they are at rest.
//
// THE WINGBEAT, after slow-motion film of bats:
// - Downstroke (x 0 to 0.5): the wing fully stretched, swept forward, fingers
//   spread, the leading edge turned down, pressing down and forward; the skin
//   billows up under the load, and the tips bend up behind.
// - Upstroke (0.5 to 1): elbow and wrist bend and the fingers draw together,
//   so the wing half closes and is pulled up and back close to the body; the
//   tip trails, and flicks over at the top.
// - The body pitches and bobs against the beat; the head pitches back against
//   it, so it is steadier than the body; the legs trail, spreading the skin of
//   the tail.
// - Gliding: wings held out, fingers spread, a little raised. Hovering or
//   braking: deeper strokes, swept further forward, the hand cupped down.
// - Folding: the fingers close together like an umbrella and fold back along
//   the forearm, the wrist and elbow fold, the arm comes back along the body,
//   and the bundle is wrapped down round it.
//
// What each vertex is: CUSTOM0 (part: 0 fur, 0.125 teeth, 0.25 skin, 0.375
// mouth, 0.5 bone, 0.625 nose, 0.75 ear, 1 eye; how light (fur) or thin (skin);
// how far it billows; 1 on the lower jaw, which opens as it shrieks); UV where
// it lies on its panel of skin; UV2 (side, 1 if it is carried by bones).
//
// Lit as Toon (scripts/toon.gd in The Clearing) lights figures: two flat tones
// with a one-pixel edge between them. The fur and the bones catch a rim of
// light; the skin is thin and dark, and light from behind shines warm through
// it, most where it is thinnest, and its edges glow side on; it has fine
// creases across it; the eyes and nose are dark and wet, with a glint.

shader_type spatial;
render_mode cull_disabled;

uniform vec3 fur : source_color = vec3(0.13, 0.115, 0.11);
uniform vec3 mantle : source_color = vec3(0.22, 0.185, 0.16);
uniform vec3 skin : source_color = vec3(0.1, 0.086, 0.085);
uniform vec3 ear : source_color = vec3(0.27, 0.2, 0.19);
uniform vec3 bone : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 through : source_color = vec3(0.2, 0.115, 0.085);
uniform vec3 teeth : source_color = vec3(0.82, 0.78, 0.68);
uniform vec3 mouth : source_color = vec3(0.13, 0.035, 0.035);
uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.4;
uniform float rim_width = 0.22;

// The joints at rest, on the right wing (keep to BatBody's).
const vec3 SHOULDER = vec3(0.035, 0.012, 0.045);
const vec3 ELBOW = vec3(0.115, 0.012, 0.012);
const vec3 WRIST = vec3(0.245, 0.014, 0.062);
const vec3 HIP = vec3(0.03, -0.004, -0.075);
const vec3 KNUCKLE[4] = vec3[4](vec3(0.335, 0.014, 0.07), vec3(0.355, 0.013, 0.046), vec3(0.335, 0.012, 0.0), vec3(0.298, 0.012, -0.017));
// How far each finger points round from the third, at rest (radians, in the
// plane of the wing): closing the hand turns each by this towards the third.
const float FAN[4] = float[4](0.38, 0.0, -0.75, -1.43);
// Where the head turns on the neck (along, up), and how far it is bowed when folded.
const vec2 NECK = vec2(0.058, 0.011);
const float BOW = 0.95;
// Where the lower jaw hinges (along, up).
const vec2 HINGE = vec2(0.1, 0.004);
// How round the body is where a folded wing is wrapped about it.
const float WRAP = 0.062;

varying float part;
varying float shade;
varying vec2 panel;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// How the joints are held, worked out once per vertex from the bat's state.
struct Pose {
	float lift;      // the shoulder: the arm raised (+) or lowered, about the body's length
	float sweep;     // the shoulder: the arm swung forward (+) or back, in the wing's plane
	float twist;     // the shoulder: the leading edge turned up (+) or down
	float elbow;     // bent (+), bringing the wrist in
	float wrist;     // bent (+), swinging the hand back
	float spread;    // 1 fingers spread, 0 closed together
	float bend;      // the fingers bent up (+) at the knuckles, as the tip trails or flicks
	float cup;       // the hand cupped down at the wrist
	float fold_tips; // the phalanges folded back along the metacarpals
	float legs;      // the legs swung out (+)
	float legs_up;   // the legs raised to the wall behind it (hanging)
};

Pose posed(float beat, float strength, float fold, float hover) {
	float a = 6.2831853 * beat;
	// (0 on the downstroke; up to 1 half way through the upstroke)
	float drawn = strength * pow(max(-sin(a), 0.0), 1.3);
	Pose p;
	p.lift = strength * (0.85 * (1.0 + 0.25 * hover) * cos(a) + 0.08) + (1.0 - strength) * 0.12;
	p.sweep = strength * (0.2 + 0.3 * hover) * sin(a) + hover * 0.25;
	p.twist = -strength * 0.28 * sin(a) + hover * 0.1;
	p.elbow = 0.6 * drawn;
	p.wrist = 0.8 * drawn;
	p.spread = 1.0 - 0.55 * drawn;
	p.bend = strength * 0.42 * sin(a + 0.45) - (1.0 - strength) * 0.04;
	p.cup = 0.12 + 0.35 * hover + 0.15 * strength * max(sin(a), 0.0);
	p.fold_tips = 0.0;
	p.legs = 0.18 + 0.08 * strength * sin(a + 3.14159);
	// Folded: every joint closed up, and the arm wrapped down round the body.
	p.lift = mix(p.lift, -0.15, fold);
	p.sweep = mix(p.sweep, -1.38, fold);
	p.twist = mix(p.twist, 0.0, fold);
	p.elbow = mix(p.elbow, 2.3, fold);
	p.wrist = mix(p.wrist, 2.45, fold);
	p.spread = mix(p.spread, 0.0, fold);
	p.bend = mix(p.bend, -0.1, fold);
	p.cup = mix(p.cup, 0.25, fold);
	p.fold_tips = 1.6 * fold;
	p.legs = mix(p.legs, 0.05, fold);
	p.legs_up = 0.7 * fold;
	return p;
}

// Where `v` (a point, w 1, or a direction, w 0) on bone `b` of the right wing goes.
vec3 carry(int b, vec3 v, float w, Pose p) {
	if (b == 13) {
		// The leg: swung out and down from the hip.
		v.xz = turn(v.xz - HIP.xz * w, -p.legs) + HIP.xz * w;
		v.xy = turn(v.xy - HIP.xy * w, -p.legs * 0.6) + HIP.xy * w;
		v.zy = turn(v.zy - HIP.zy * w, -p.legs_up) + HIP.zy * w;
		return v;
	}
	if (b >= 5) {
		int k = (b - 5) / 2;
		vec3 knuckle = KNUCKLE[k];
		if ((b - 5) % 2 == 1) {
			// The phalanges: bent up or down at the knuckle, and folded back.
			vec2 along = normalize(knuckle.xz - WRIST.xz);
			vec2 rel = v.xz - knuckle.xz * w;
			float out_ = dot(rel, along);
			vec2 bent = turn(vec2(out_, v.y - knuckle.y * w), p.bend * (0.6 + 0.2 * float(k)) - p.cup * 0.5);
			v.xz = knuckle.xz * w + along * bent.x + (rel - along * out_);
			v.y = knuckle.y * w + bent.y;
			v.xz = turn(v.xz - knuckle.xz * w, -p.fold_tips) + knuckle.xz * w;
		}
		// The metacarpal: the finger turned in towards the third as the hand closes.
		v.xz = turn(v.xz - WRIST.xz * w, -FAN[k] * (1.0 - p.spread)) + WRIST.xz * w;
	}
	if (b >= 3) {
		// The wrist: the hand swung back, and cupped down.
		v.xz = turn(v.xz - WRIST.xz * w, -p.wrist) + WRIST.xz * w;
		v.xy = turn(v.xy - WRIST.xy * w, -p.cup) + WRIST.xy * w;
	}
	if (b >= 2) {
		// The elbow.
		v.xz = turn(v.xz - ELBOW.xz * w, p.elbow) + ELBOW.xz * w;
	}
	if (b >= 1) {
		// The shoulder: twisted about the arm, swept, raised.
		v.zy = turn(v.zy - SHOULDER.zy * w, p.twist) + SHOULDER.zy * w;
		v.xz = turn(v.xz - SHOULDER.xz * w, p.sweep) + SHOULDER.xz * w;
		v.xy = turn(v.xy - SHOULDER.xy * w, p.lift) + SHOULDER.xy * w;
	}
	return v;
}

void vertex() {
	part = CUSTOM0.r;
	shade = CUSTOM0.g;
	panel = UV;
	float beat = INSTANCE_CUSTOM.x;
	float strength = INSTANCE_CUSTOM.y;
	float fold = INSTANCE_CUSTOM.z;
	float hover = INSTANCE_CUSTOM.w;
	float a = 6.2831853 * beat;
	if (UV2.y > 0.5) {
		Pose p = posed(beat, strength, fold, hover);
		float side = UV2.x > 0.5 ? 1.0 : -1.0;
		vec3 v = VERTEX;
		vec3 n = NORMAL;
		v.x *= side;
		n.x *= side;
		// The skin billows up under the load of the downstroke (and a little in a glide).
		float load = (strength * (0.25 + 0.75 * max(sin(a), 0.0)) + (1.0 - strength) * 0.4 + hover * 0.4) * (1.0 - fold);
		v.y += CUSTOM0.b * load * 0.012;
		int first = int(CUSTOM1.x + 0.5);
		int second = int(CUSTOM1.y + 0.5);
		vec3 at = carry(first, v, 1.0, p);
		vec3 facing = carry(first, n, 0.0, p);
		if (second != first) {
			at = mix(at, carry(second, v, 1.0, p), CUSTOM1.z);
			facing = mix(facing, carry(second, n, 0.0, p), CUSTOM1.z);
		}
		// Folded up, what the arm and hand carry lies in a narrow bundle along
		// the flank; it is wrapped down round the belly like a cloak, the two
		// meeting down the middle.
		// (all the skin the arm has any hold on goes round, so none of it is
		// left standing out at the hips; the thumbs are hooked out over the top)
		bool on_arm = (first >= 1 && first <= 12) || (second >= 1 && second <= 12);
		float wrapping = on_arm ? fold * fold : 0.0;
		if (wrapping > 0.0) {
			float round_by = min(max(at.x - 0.02, 0.0) / (WRAP * 0.75), 2.6);
			float out_by = first == 4 ? 1.55 : 1.15;
			vec3 wrapped = vec3(cos(round_by) * WRAP * out_by, at.y * 0.3 - sin(round_by) * WRAP * out_by, at.z);
			at = mix(at, wrapped, wrapping);
			facing = mix(facing, vec3(cos(round_by), -sin(round_by), 0.0), wrapping);
		}
		at.x *= side;
		facing.x *= side;
		VERTEX = at;
		NORMAL = normalize(facing);
	} else {
		// The lower jaw drops open as it shrieks (hovering round someone).
		if (CUSTOM0.a > 0.5) {
			float open = hover * 0.55 * (1.0 - fold);
			VERTEX.zy = turn(VERTEX.zy - HINGE, -open) + HINGE;
			NORMAL.zy = turn(NORMAL.zy, -open);
		}
		// Hanging, its head is bowed forward on its neck, so that (head down)
		// it looks out from the wall, ears forward.
		if (fold > 0.0) {
			float at_head = smoothstep(NECK.x - 0.006, NECK.x + 0.014, VERTEX.z);
			float bow = -BOW * fold * at_head;
			VERTEX.zy = turn(VERTEX.zy - NECK, bow) + NECK;
			NORMAL.zy = turn(NORMAL.zy, bow);
		}
	}
	// The body pitches against the beat, and the head pitches back against
	// that: it is steadier than the body.
	float pitch = strength * (1.0 - fold) * 0.09 * sin(a + 0.6);
	if (UV2.y < 0.5) {
		float at_head = smoothstep(NECK.x - 0.006, NECK.x + 0.014, VERTEX.z);
		VERTEX.zy = turn(VERTEX.zy - NECK, -pitch * 0.8 * at_head) + NECK;
		NORMAL.zy = turn(NORMAL.zy, -pitch * 0.8 * at_head);
	}
	VERTEX.zy = turn(VERTEX.zy, pitch);
	NORMAL.zy = turn(NORMAL.zy, pitch);
}

void fragment() {
	// (the part, by its code: 0 fur, 1 teeth, 2 skin, 3 mouth, 4 bone, 5 nose, 6 ear, 8 eye)
	int kind = int(round(part * 8.0));
	bool thin_skin = kind == 2 || kind == 6;
	vec3 colour;
	if (kind == 0) {
		colour = mix(fur, mantle, shade);
	} else if (kind == 2) {
		// Fine creases running across the skin between the bones.
		float across = panel.x * 9.0 + 0.12 * sin(panel.y * 11.0 + panel.x * 3.0);
		float pixel = max(fwidth(across), 0.0001);
		float crease = 1.0 - smoothstep(0.0, pixel * 1.5, abs(fract(across) - 0.5));
		colour = skin * (1.0 - 0.13 * crease);
	} else if (kind == 1) {
		colour = teeth;
	} else if (kind == 3) {
		colour = mix(mouth, mouth * 2.2, shade);
	} else if (kind == 4) {
		colour = bone;
	} else if (kind == 5) {
		colour = bone * 0.8;
	} else if (kind == 6) {
		// (the hollow of the ear paler than its back)
		colour = shade > 0.5 ? ear : skin;
	} else {
		colour = vec3(0.025, 0.02, 0.02);
	}
	ALBEDO = colour;
	SPECULAR = 0.0;
	// What light() needs to know, passed in what it can read (varyings do not
	// reach it everywhere): ROUGHNESS says how it is lit (1 a rim, as fur, bone
	// and teeth are; 0.75 thin skin, lit through; 0.5 wet, with a glint: the
	// eyes and the nose), BACKLIGHT the colour of the rim or of the light through it.
	if (kind == 0) {
		ROUGHNESS = 1.0;
		BACKLIGHT = mix(fur * 1.6, mantle * 1.1, shade);
	} else if (thin_skin) {
		ROUGHNESS = 0.75;
		BACKLIGHT = through * (kind == 6 ? 0.1 : 0.1 + 0.32 * shade * shade);
	} else if (kind == 5 || kind == 8) {
		ROUGHNESS = 0.5;
		BACKLIGHT = vec3(0.0);
	} else {
		ROUGHNESS = 1.0;
		BACKLIGHT = kind == 1 ? teeth * 0.4 : (kind == 4 ? bone * 0.9 : vec3(0.0));
	}
	// (both sides of the skin, and of a tuft of fur, are its outside: lit from
	// whichever is seen; the body itself is closed, so its back faces are hidden)
	if ((thin_skin || kind == 0) && dot(NORMAL, VIEW) < 0.0) {
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
		// Light from behind shines through the skin, most where it is thin
		// (added as it comes through, not as the surface's colour lit); and
		// side on, its thin edges glow.
		float behind = smoothstep(0.0, 0.5, -dot(NORMAL, LIGHT));
		SPECULAR_LIGHT += behind * BACKLIGHT * strength * LIGHT_COLOR / PI;
		float edge = cut(graze, 0.8) * smoothstep(0.25, 0.42, length(BACKLIGHT) / max(length(through), 0.001));
		SPECULAR_LIGHT += edge * BACKLIGHT * 0.4 * strength * LIGHT_COLOR / PI;
	} else if (ROUGHNESS > 0.9) {
		// Fur and bone catch the light along their edges.
		float rim = cut(graze, 1.0 - rim_width) * mix(lit, 1.0, 0.4);
		SPECULAR_LIGHT += rim * rim_gain * BACKLIGHT * strength * LIGHT_COLOR / PI;
	} else {
		// A wet eye: one small bright light on it.
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 90.0), 0.5);
		SPECULAR_LIGHT += shine * 1.5 * LIGHT_COLOR;
	}
}
