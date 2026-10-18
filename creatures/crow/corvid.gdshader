// A corvid (an American crow, a raven or a blue jay: creatures/crow/
// corvid_body.gd makes the meshes), drawn many at once by one MultiMesh
// (CorvidFlock). Each bird is posed here, in the vertex shader, from six vec4s
// of `pose` (bird i's are pose[i * 6] to pose[i * 6 + 5]) and one of `looks`,
// which the flock sets every frame:
//
//   pose 0: walk phase (0..1, round and round), step length (m), hopping (0..1:
//           both feet together), legs tucked up (0..1, flying)
//   pose 1: where the head is, from where it is at rest (x, y, z, the bird's
//           own space), its yaw (radians, + to its left)
//   pose 2: the head's pitch (+ bill down) and roll, the bill open (0..1),
//           fluffed (0..1: the feathers raised; a raven's throat hackles out)
//   pose 3: folded (1: the wings folded on the flanks; 0: spread), the
//           wingbeat's phase (0..1, 0 at the top), how hard they beat (0: held
//           out, gliding; 1: full strokes), the body's pitch (radians, + nose down)
//   pose 4: flared (0..1: braking to land, wings up and forward, tail spread
//           down), the tail raised (+, radians), the tail fanned (0..1), banked
//           (radians, + its left wing down)
//   pose 5: the crest raised (0..1, a jay's), toes gripping (0..1), legs reached
//           forward (0..1, landing), crouched (0..1, ready to spring)
//   looks:  a number for the bird, how glossy (0..1), how worn, unused
//
// THE BONES (CUSTOM1.x; CorvidBody numbers them): the body pitches about the
// hip, banks and rises and sinks; the head goes where it is put, turned, the
// neck stretching between body and head (each vertex of the neck carried by
// both, as CUSTOM1.y says); the lower mandible opens on its hinge; the crest
// rises; the tail lifts and fans; each leg is solved from the knee to where its
// foot is to be (two bones, the hock bending backwards), the toes curling.
//
// THE WINGS: modelled folded on the flanks and spread (CUSTOM2/3). Spread,
// each wing is posed as a bird's arm: the shoulder raises (elevation), sweeps
// and twists the humerus, the elbow and wrist fold in the plane of the wing,
// the hand bends up or down at the wrist, and the primaries fan into fingers or
// close together. The wingbeat, after slow-motion film of crows:
// - Downstroke (phase 0 to 0.5): the wing straight and spread, swept a little
//   forward, the leading edge turned down, the primaries fanned into fingers
//   and bent up at their tips by the load.
// - Upstroke (0.5 to 1): elbow and wrist flex, so the wing folds half shut at
//   the wrist and is drawn up and back close to the body, the hand trailing,
//   the primaries closed together and turned edge on; at the top it flicks open.
// - Gliding: held out, raised a little in a shallow V, the fingers spread.
// - Flared: swept up and forward, the leading edge raised steeply, the tail
//   fanned and pressed down, the legs reaching for the perch.
// Then `folded` takes the posed spread wing over to the modelled folded one.
//
// Lit as Toon (scripts/toon.gd in The Clearing) lights figures: two flat tones
// with a one-pixel edge between them, a rim of light round the feathers (the
// crow's and raven's a blue-violet gloss), a glint in the eye and on the bill.

shader_type spatial;
render_mode cull_disabled;

uniform vec4 pose[96];
uniform vec4 looks[16];
// 0 crow, 1 raven, 2 blue jay.
uniform int kind = 0;
uniform float flight_pitch = 0.3;
uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.2;

// The joints (CorvidBody sets them from the model). +X is its left. The
// elbow, wrist and tip are the spread wing's, in its level frame, from the shoulder.
uniform vec3 j_hip = vec3(0.0, 0.13, -0.005);
uniform vec3 j_knee = vec3(0.028, 0.105, 0.016);
uniform vec3 j_hock = vec3(0.024, 0.058, -0.012);
uniform vec3 j_foot = vec3(0.022, 0.006, 0.008);
uniform vec3 j_neck = vec3(0.0, 0.186, 0.064);
uniform vec3 j_head = vec3(0.0, 0.226, 0.104);
uniform vec3 j_hinge = vec3(0.0, 0.222, 0.126);
uniform vec3 j_crest = vec3(0.0, 0.248, 0.104);
uniform vec3 j_tail = vec3(0.0, 0.132, -0.102);
uniform vec3 j_shoulder = vec3(0.034, 0.176, 0.042);
uniform vec3 j_elbow = vec3(0.084, 0.0, -0.012);
uniform vec3 j_wrist = vec3(0.178, 0.002, 0.004);
uniform vec3 j_tip = vec3(0.25, 0.0, -0.006);

varying float part;
varying float region;
varying float along;
varying float tag;
varying float across;
varying vec3 rest;
varying float seed;
varying float gloss;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

mat3 rot_axis(vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	vec3 u = axis;
	return mat3(
		vec3(t * u.x * u.x + c, t * u.x * u.y + s * u.z, t * u.x * u.z - s * u.y),
		vec3(t * u.x * u.y - s * u.z, t * u.y * u.y + c, t * u.y * u.z + s * u.x),
		vec3(t * u.x * u.z + s * u.y, t * u.y * u.z - s * u.x, t * u.z * u.z + c));
}

mat3 turn_onto(vec3 from, vec3 to) {
	vec3 axis = cross(from, to);
	float s = length(axis);
	float c = dot(from, to);
	if (s < 0.0001) {
		return mat3(1.0);
	}
	return rot_axis(axis / s, atan(s, c));
}

float hash(float n) {
	return fract(sin(n * 127.1 + 31.7) * 43758.5453);
}

// The body: pitched about the hip, banked, raised or lowered.
struct Body {
	mat3 turn;
	vec3 lift;
};

vec3 on_body(Body b, vec3 v) {
	return j_hip + b.turn * (v - j_hip) + b.lift;
}

// One wing's pose (the left; the right is its mirror), radians.
struct Wing {
	float elev;   // the arm raised (+) about the body's length
	float sweep;  // swung forward (+)
	float twist;  // the leading edge turned down (+)
	float elbow;  // folded (+), the wrist coming in and forward
	float wrist;  // folded (+), the hand swinging back
	float lift;   // the hand bent up (+) at the wrist
	float spread; // the primaries: 0 closed together, 1 as modelled, more fanned apart
};

Wing mixed(Wing a, Wing b, float t) {
	Wing w;
	w.elev = mix(a.elev, b.elev, t);
	w.sweep = mix(a.sweep, b.sweep, t);
	w.twist = mix(a.twist, b.twist, t);
	w.elbow = mix(a.elbow, b.elbow, t);
	w.wrist = mix(a.wrist, b.wrist, t);
	w.lift = mix(a.lift, b.lift, t);
	w.spread = mix(a.spread, b.spread, t);
	return w;
}

Wing glide() {
	Wing w;
	w.elev = 0.13;
	w.sweep = 0.02;
	w.twist = 0.04;
	w.elbow = 0.12;
	w.wrist = 0.1;
	w.lift = 0.12;
	w.spread = 1.22;
	return w;
}

// The wingbeat at `phase` (0 the top), `strength` how deep.
Wing flap(float phase, float strength) {
	const float DOWN = 0.5;
	float top = mix(0.45, 1.15, strength);
	float bottom = mix(-0.2, -0.68, strength);
	Wing w;
	if (phase < DOWN) {
		float u = phase / DOWN;
		float e = 0.5 - 0.5 * cos(3.14159 * u);
		float mid = sin(3.14159 * u);
		w.elev = mix(top, bottom, e);
		w.sweep = 0.12 + 0.16 * mid;
		w.twist = 0.12 + 0.22 * mid * strength;
		w.elbow = 0.06;
		w.wrist = 0.04;
		w.lift = -0.05 + 0.38 * mid * strength;
		w.spread = 1.15 + 0.25 * strength;
	} else {
		float u = (phase - DOWN) / (1.0 - DOWN);
		float e = 0.5 - 0.5 * cos(3.14159 * u);
		float mid = sin(3.14159 * u);
		w.elev = mix(bottom, top, e);
		w.sweep = mix(0.12, -0.3, mid);
		w.twist = -0.42 * mid * strength;
		float fold = mid * (1.0 - smoothstep(0.78, 1.0, u)) * (0.45 + 0.55 * strength);
		w.elbow = 0.06 + 0.95 * fold;
		w.wrist = 0.04 + 1.55 * fold;
		w.lift = -0.55 * mid * strength + 0.35 * smoothstep(0.72, 1.0, u);
		w.spread = u < 0.3 ? mix(1.3, 0.25, smoothstep(0.0, 0.3, u)) : mix(0.25, 1.25, smoothstep(0.7, 1.0, u));
	}
	return w;
}

// Braking to land: swept up and forward, the leading edge raised steeply.
Wing flare(float phase, float strength) {
	Wing w = flap(phase, strength * 0.7);
	w.elev = 0.75 + 0.45 * (w.elev - 0.2);
	w.sweep += 0.5;
	w.twist -= 0.7;
	w.lift += 0.2;
	w.spread = max(w.spread, 1.1) + 0.2;
	return w;
}

// Where `v` (a point, w 1; or a direction, w 0) of a left wing's bone `b`
// goes, posed as `w`, in the level frame from the shoulder.
vec3 carry(int b, vec3 v, float w1, Wing w, float fan) {
	vec3 elbow = j_elbow * w1;
	vec3 wrist = j_wrist * w1;
	if (b >= 6) {
		// The primaries fan apart, or close in towards the first, about the wrist.
		float turn = w.spread < 1.0 ? (1.0 - w.spread) * fan * 1.15 : -(w.spread - 1.0) * (fan - 0.4) * 0.55;
		v = wrist + rot_y(turn) * (v - wrist);
		// The hand: bent up at the wrist (about the chord), then folded back.
		v = wrist + rot_y(w.wrist) * rot_z(w.lift) * (v - wrist);
	}
	if (b >= 5) {
		v = elbow + rot_y(-w.elbow) * (v - elbow);
	}
	// The shoulder: twisted about the arm, swept, raised.
	v = rot_z(w.elev) * rot_y(-w.sweep) * rot_x(w.twist) * v;
	return v;
}

// Where a foot is to be, and how far its toes curl, for one leg (`side` 1 its
// left, -1 its right) on the walk phase `phase`.
vec4 foot_goal(float side, float phase, float step_len, float hop) {
	vec3 foot = vec3(j_foot.x * side, 0.0, j_foot.z);
	float duty = 0.55;
	float curl = 0.0;
	// (hopping, both feet go together)
	float p = mix(phase, fract(phase + (side > 0.0 ? 0.0 : 0.5)), 1.0 - hop);
	vec3 walk = foot;
	if (p < duty) {
		walk.z += step_len * (0.5 - p / duty);
	} else {
		float u = (p - duty) / (1.0 - duty);
		float swing = smoothstep(0.0, 1.0, u);
		walk.z += step_len * (swing - 0.5);
		walk.y += (0.012 + 0.25 * step_len) * sin(3.14159 * u);
		curl = sin(3.14159 * min(u * 1.3, 1.0)) * min(step_len * 20.0, 1.0);
	}
	return vec4(walk, curl);
}

void vertex() {
	int i = INSTANCE_ID;
	vec4 p0 = pose[i * 6];
	vec4 p1 = pose[i * 6 + 1];
	vec4 p2 = pose[i * 6 + 2];
	vec4 p3 = pose[i * 6 + 3];
	vec4 p4 = pose[i * 6 + 4];
	vec4 p5 = pose[i * 6 + 5];
	vec4 look = looks[i];
	seed = look.x;
	gloss = look.y;

	part = CUSTOM0.x;
	region = CUSTOM0.y;
	along = CUSTOM0.z;
	tag = CUSTOM0.w;
	across = CUSTOM1.w;
	rest = vec3(UV2, CUSTOM2.w);
	int bone = int(CUSTOM1.x + 0.5);
	float share = CUSTOM1.y;
	int reg = int(region + 0.5);
	int kind_of_part = int(part + 0.5);
	vec3 v = VERTEX;
	vec3 n = NORMAL;

	float fluff = p2.w;
	float fold = p3.x;
	float tuck = p0.w;
	float crouch = p5.w;

	// Fluffed, the feathers stand off the body, tips most; a raven's throat hackles bristle out.
	if (kind_of_part == 0 && bone <= 1 && reg != 5) {
		vec3 out_dir = normalize(v - (j_hip + vec3(0.0, 0.02, 0.02)) + vec3(0.0, 0.0001, 0.0));
		float lift = fluff * (0.004 + 0.012 * along) * (reg == 4 ? 2.5 : 1.0);
		v += out_dir * lift;
	}

	// The body's feathers (and the down) shade as one form: their normals bent
	// out from the middle of the body (or the head), so the light falls on the
	// bird in one clean band, not feather by feather.
	if ((kind_of_part == 0 || kind_of_part == 1) && bone <= 1 && reg != 5) {
		float unit = j_hip.y / 0.13;
		vec3 middle = mix(j_hip + vec3(0.0, 0.028, 0.015) * unit, j_head, smoothstep(0.3, 0.75, share));
		n = normalize(mix(n, normalize(v - middle), 0.72));
	}

	Body body;
	float stepping = clamp(p0.y * 14.0, 0.0, 1.0) * (1.0 - tuck);
	// (a crow's swagger: the body rolls and dips with each step)
	float roll = 0.07 * sin(6.2831853 * p0.x) * stepping * (1.0 - p0.z);
	body.turn = rot_x(p3.w) * rot_z(roll - p4.w);
	body.lift = vec3(0.0, -0.006 * cos(12.566 * p0.x) * stepping * (1.0 - p0.z) - 0.03 * crouch * (j_hip.y / 0.13), 0.0);

	vec3 at = v;
	vec3 facing = n;
	if (bone == 1 || bone == 2) {
		// The head where it is put, turned; the neck between body and head.
		vec3 hv = v;
		vec3 hn = n;
		if (bone == 2) {
			mat3 open = rot_x(p2.z * 0.6);
			hv = j_hinge + open * (v - j_hinge);
			hn = open * n;
		} else if (reg == 5 && kind_of_part == 0) {
			// The crest: raised (back and up from lying along the crown), the tips most.
			mat3 raise = rot_x(-(p5.x - 0.35) * 0.9 * (0.4 + 0.6 * along));
			hv = j_crest + raise * (v - j_crest);
			hn = raise * n;
		}
		mat3 head_turn = rot_y(p1.w) * rot_x(p2.x) * rot_z(p2.y);
		vec3 head_at = j_head + p1.xyz;
		vec3 on_head = head_at + head_turn * (hv - j_head);
		vec3 on_head_n = head_turn * hn;
		vec3 on_b = on_body(body, v);
		vec3 on_b_n = body.turn * n;
		float w = (bone == 2 || share > 0.999) ? 1.0 : share;
		at = mix(on_b, on_head, w);
		facing = mix(on_b_n, on_head_n, w);
	} else if (bone == 3) {
		// The tail: raised, and fanned (each feather about the root, by where across it is).
		vec3 axis = normalize(vec3(0.0, 0.95, -0.32));
		float fan = p4.z * (tag * 2.0 - 1.0) * 0.75;
		mat3 t = rot_x(-p4.y) * rot_axis(axis, kind_of_part == 0 && reg == 12 ? -fan : -fan * 0.6);
		at = on_body(body, j_tail + t * (v - j_tail));
		facing = body.turn * t * n;
	} else if (bone >= 4 && bone <= 6) {
		vec3 spread_v = CUSTOM2.xyz;
		vec3 spread_n = CUSTOM3.xyz;
		float side = spread_v.x >= 0.0 ? 1.0 : -1.0;
		vec3 shoulder = vec3(j_shoulder.x * side, j_shoulder.y, j_shoulder.z);
		// Into the wing's level frame (and the right wing mirrored onto the left).
		mat3 level = rot_x(flight_pitch);
		vec3 rel = level * (spread_v - shoulder);
		vec3 rn = level * spread_n;
		rel.x *= side;
		rn.x *= side;
		Wing w = mixed(glide(), flap(p3.y, p3.z), clamp(p3.z * 3.0, 0.0, 1.0));
		w = mixed(w, flare(p3.y, p3.z), p4.x);
		float fan = (reg == 9 && kind_of_part == 0) ? tag : 0.0;
		vec3 posed = carry(bone, rel, 1.0, w, fan);
		vec3 posed_n = carry(bone, rn, 0.0, w, fan);
		if (share < 0.999 && bone >= 5) {
			// (the core across a joint: shared with the bone inside it)
			posed = mix(carry(bone - 1, rel, 1.0, w, fan), posed, share);
			posed_n = mix(carry(bone - 1, rn, 0.0, w, fan), posed_n, share);
		}
		posed.x *= side;
		posed_n.x *= side;
		mat3 back = rot_x(-flight_pitch);
		vec3 spread_at = shoulder + back * posed;
		vec3 spread_facing = back * posed_n;
		// Folded: over to the modelled folded wing.
		vec3 wing_v = mix(spread_at, v, fold);
		vec3 wing_n = normalize(mix(spread_facing, n, fold));
		at = on_body(body, wing_v);
		facing = body.turn * wing_n;
	} else if (bone >= 7) {
		// A leg: from the knee (on the body) to where the foot is to be.
		float side = v.x >= 0.0 ? 1.0 : -1.0;
		vec4 goal = foot_goal(side, p0.x, p0.y, p0.z);
		vec3 knee0 = vec3(j_knee.x * side, j_knee.y, j_knee.z);
		vec3 hock0 = vec3(j_hock.x * side, j_hock.y, j_hock.z);
		vec3 foot0 = vec3(j_foot.x * side, j_foot.y, j_foot.z);
		vec3 knee = on_body(body, knee0);
		vec3 foot = goal.xyz + vec3(0.0, j_foot.y, 0.0);
		// Flying, drawn up under the belly; landing, reached forward for the perch.
		vec3 tucked = on_body(body, vec3(j_foot.x * side * 0.8, j_knee.y - 0.02 * (j_hip.y / 0.13), j_knee.z - 0.06 * (j_hip.y / 0.13)));
		vec3 reaching = on_body(body, foot0 + vec3(0.0, 0.01, 0.045) * (j_hip.y / 0.13));
		foot = mix(foot, tucked, tuck);
		foot = mix(foot, reaching, p5.z);
		float l1 = length(hock0 - knee0);
		float l2 = length(foot0 - hock0);
		vec3 d = foot - knee;
		float dist = clamp(length(d), 0.01, l1 + l2 - 0.0005);
		vec3 dn = normalize(d);
		foot = knee + dn * dist;
		float a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist);
		float h = sqrt(max(l1 * l1 - a * a, 0.0));
		// (the hock bends backwards)
		vec3 behind = normalize(cross(vec3(1.0, 0.0, 0.0), dn));
		if (behind.z > 0.0) {
			behind = -behind;
		}
		vec3 hock = knee + dn * a + behind * h;
		mat3 thigh_turn = turn_onto(normalize(hock0 - knee0), normalize(hock - knee));
		mat3 shank_turn = turn_onto(normalize(foot0 - hock0), normalize(foot - hock));
		vec3 on_thigh = knee + thigh_turn * (v - knee0);
		vec3 on_thigh_n = thigh_turn * n;
		if (bone == 7) {
			at = on_thigh;
			facing = on_thigh_n;
		} else if (bone == 8) {
			vec3 on_shank = hock + shank_turn * (v - hock0);
			at = mix(on_thigh, on_shank, share);
			facing = mix(on_thigh_n, shank_turn * n, share);
		} else {
			// The toes: level with the body's yaw (pitched with it in flight),
			// curling down about their roots to grip, the further out the more.
			float curl_by = max(goal.w * (1.0 - tuck), max(p5.y, tuck * 0.9)) * (1.0 - p5.z * 0.8);
			vec3 rel = v - foot0;
			vec2 flat_dir = normalize(rel.xz + vec2(0.0001, 0.0));
			vec3 bend_axis = normalize(cross(vec3(0.0, 1.0, 0.0), vec3(flat_dir.x, 0.0, flat_dir.y)));
			mat3 curl = rot_axis(bend_axis, curl_by * 1.5 * share);
			mat3 tilt = rot_x(p3.w * tuck);
			at = foot + tilt * curl * rel;
			facing = tilt * curl * n;
		}
	} else {
		at = on_body(body, v);
		facing = body.turn * n;
	}
	VERTEX = at;
	NORMAL = normalize(facing);
}

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// A blue jay's feather: by region, with its bars, white tips and black
// necklace (see the regions in build_corvids.py).
vec3 jay_feather(int reg, float t, float x, float own) {
	vec3 blue = srgb(vec3(0.2, 0.42, 0.84));
	vec3 pale_blue = srgb(vec3(0.46, 0.58, 0.8));
	vec3 grey_blue = srgb(vec3(0.47, 0.53, 0.64));
	vec3 white = srgb(vec3(0.84, 0.84, 0.82));
	vec3 off_white = srgb(vec3(0.74, 0.74, 0.73));
	vec3 black = srgb(vec3(0.045, 0.045, 0.055));
	// (black bars across the wing and tail feathers)
	float bars = smoothstep(0.74, 0.8, abs(fract(t * 8.5 + 0.15) - 0.5) * 2.0);
	if (reg == 0 || reg == 4) {
		return mix(off_white, white, smoothstep(0.0, 0.6, own));
	} else if (reg == 3) {
		return white;
	} else if (reg == 1 || reg == 15 || reg == 13) {
		return mix(grey_blue, pale_blue, 0.3 * own);
	} else if (reg == 2 || reg == 5) {
		return mix(pale_blue, blue, 0.2 + 0.25 * t);
	} else if (reg == 6 || reg == 7 || reg == 14) {
		return black;
	} else if (reg == 8) {
		vec3 c = mix(blue, black, bars * 0.3);
		// (the greater coverts tipped white: the wing bar)
		return own > 0.55 ? mix(c, white, smoothstep(0.8, 0.86, t)) : c;
	} else if (reg == 9) {
		// Primaries: blue on the outer vane, dark on the inner, finely barred.
		vec3 c = mix(black, blue, smoothstep(-0.1, 0.25, -x * 1.0) * 0.9 + 0.1);
		return mix(c, black, bars * 0.5 + smoothstep(0.88, 0.96, t) * 0.6);
	} else if (reg == 10 || reg == 11) {
		vec3 c = mix(blue, black, bars * 0.9);
		c = mix(c, black, smoothstep(0.72, 0.76, t));
		return mix(c, white, smoothstep(0.84, 0.88, t));
	} else if (reg == 12) {
		// The tail: blue, barred black, a black band near the end and the
		// outer feathers tipped white.
		vec3 c = mix(blue, black, bars * 0.8);
		c = mix(c, black, smoothstep(0.78, 0.82, t));
		float outer = abs(tag * 2.0 - 1.0);
		return mix(c, white, smoothstep(0.88, 0.92, t) * smoothstep(0.25, 0.6, outer));
	}
	return grey_blue;
}

void fragment() {
	int kp = int(part + 0.5);
	int reg = int(region + 0.5);
	vec3 colour;
	float wet = 0.0;
	vec3 rim_colour = vec3(0.0);
	float rim_on = 0.0;
	float own = hash(tag * 53.0 + 1.3);
	bool jay = kind == 2;
	// The crow's and raven's black: never quite black, with a blue-violet gloss
	// (a raven's more, with green); the flight feathers worn browner.
	vec3 black = kind == 1 ? srgb(vec3(0.22, 0.22, 0.25)) : srgb(vec3(0.24, 0.24, 0.27));
	vec3 sheen = kind == 1 ? srgb(vec3(0.33, 0.32, 0.46)) : srgb(vec3(0.31, 0.34, 0.46));
	if (kp == 0) {
		if (jay) {
			colour = jay_feather(reg, along, across, own);
			rim_colour = colour * 1.4 + vec3(0.03);
		} else {
			colour = black;
			if (reg >= 9 && reg <= 12) {
				colour = mix(black, srgb(vec3(0.29, 0.28, 0.28)), 0.4 + 0.4 * own);
			}
			// (the shaft a little lighter, the vane's edges darker)
			float shaft = 1.0 - smoothstep(0.05, 0.14, abs(across));
			colour *= 1.0 + 0.4 * shaft - 0.15 * smoothstep(0.6, 0.95, abs(across));
			rim_colour = mix(sheen, srgb(vec3(0.22, 0.36, 0.36)), kind == 1 ? 0.35 * own : 0.15 * own) * (0.35 + 0.3 * gloss);
		}
		colour *= 0.9 + 0.2 * own;
		rim_on = 1.0;
	} else if (kp == 1) {
		// The down under the feathers (seen between them): the colour of what is over it.
		if (jay) {
			// (blue-grey over the back and crown, white under, the face white)
			float unit = j_hip.y / 0.13;
			float above = smoothstep(j_hip.y + 0.025 * unit, j_hip.y + 0.045 * unit, rest.y + (rest.z - j_hip.z) * 0.25);
			float face = smoothstep(j_head.y + 0.004 * unit, j_head.y - 0.006 * unit, rest.y) * step(j_neck.z, rest.z);
			colour = mix(srgb(vec3(0.78, 0.78, 0.77)), srgb(vec3(0.42, 0.5, 0.66)), above * (1.0 - face));
			rim_colour = colour;
		} else {
			colour = black * 0.85;
		}
	} else if (kp == 2) {
		// The bill: black horn, glossy.
		colour = srgb(vec3(0.06, 0.06, 0.065)) * (0.85 + 0.3 * along);
		wet = 0.4;
	} else if (kp == 3) {
		colour = jay ? srgb(vec3(0.3, 0.2, 0.2)) : srgb(vec3(0.17, 0.1, 0.11));
	} else if (kp == 4) {
		// Legs and toes: black, scaled.
		vec3 skin = jay ? srgb(vec3(0.12, 0.12, 0.13)) : srgb(vec3(0.06, 0.06, 0.065));
		float rings = abs(fract(along * 10.0) - 0.5);
		colour = skin * (0.85 + 0.3 * smoothstep(0.3, 0.45, rings));
		wet = 0.15;
	} else if (kp == 5) {
		colour = srgb(vec3(0.04, 0.04, 0.04));
	} else if (kp == 6) {
		// The eye: a dark brown iris round a black pupil.
		float off = UV.y;
		colour = off < 0.2 ? vec3(0.004) : (off < 0.42 ? (jay ? srgb(vec3(0.07, 0.05, 0.04)) : srgb(vec3(0.16, 0.1, 0.06))) : srgb(vec3(0.04, 0.035, 0.03)));
		wet = 1.0;
	} else {
		colour = vec3(0.02);
	}
	ALBEDO = colour;
	SPECULAR = 0.0;
	// What light() needs, in what it can read: ROUGHNESS 1 a rim of light (the
	// feathers), 0.5 wet with a glint (the eye, the bill), else plain.
	if (rim_on > 0.5) {
		ROUGHNESS = 1.0;
		BACKLIGHT = rim_colour;
	} else if (wet > 0.0) {
		ROUGHNESS = 0.5;
		BACKLIGHT = vec3(wet);
	} else {
		ROUGHNESS = 0.8;
		BACKLIGHT = vec3(0.0);
	}
	// (both sides of a feather are its outside)
	if (dot(NORMAL, VIEW) < 0.0) {
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
	if (ROUGHNESS > 0.9) {
		float rim = cut(graze, 1.0 - rim_width) * mix(lit, 1.0, 0.4);
		SPECULAR_LIGHT += rim * rim_gain * BACKLIGHT * strength * LIGHT_COLOR / PI;
		// (a crow's gloss: a soft sheen where the light glances off the feathers)
		if (kind < 2) {
			float glint = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 18.0);
			SPECULAR_LIGHT += cut(glint, 0.6) * 0.22 * BACKLIGHT * strength * LIGHT_COLOR / PI;
		}
	} else if (ROUGHNESS > 0.4 && ROUGHNESS < 0.6) {
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 140.0), 0.5);
		SPECULAR_LIGHT += shine * BACKLIGHT.x * 1.5 * LIGHT_COLOR;
	}
}
