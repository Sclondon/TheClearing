// A chicken (creatures/chicken/chicken_body.gd makes the mesh), drawn many at
// once by one MultiMesh (ChickenFlock). Each bird is posed here, in the vertex
// shader, from four vec4s of `pose` (bird i's are pose[i * 4] to pose[i * 4 + 3])
// and one of `looks`, which the flock sets every frame:
//
//   pose 0: walk phase (0..1, round and round), step length (m), scratch
//           (0..1: raking the ground, one foot and then the other, on the walk
//           phase), legs tucked up (0..1, flying)
//   pose 1: where the head is, from where it is at rest (x, y, z, in the bird's
//           own space, so the flock can hold it still in the world while the
//           body walks on: a chicken's head-lock), and its yaw (radians, + to
//           her left)
//   pose 2: the head's pitch (+ beak down) and roll, the beak open (0..1),
//           puffed up (0..1: every feather raised, the hackles flared)
//   pose 3: the wings open (0..1, from folded to spread), the wingbeat's phase
//           (0..1, 0 at the top), how hard they beat (0..1), the body's pitch
//           (radians, + nose down)
//   looks:  which colours (0 red-brown, 1 speckled, 2 white, 3 black), 1 for a
//           rooster, a random number for the bird, how molted (0..1)
//
// THE BONES (CUSTOM1.x; ChickenBody numbers them): the body pitches about the
// hip, rolls a little with each step and bobs; the head goes where it is put,
// turned, and the neck stretches between body and head (each vertex of the
// neck is carried by both, as CUSTOM1.y says); the lower mandible opens on its
// hinge; the tail lifts and spreads; each wing goes from folded to spread (the
// model's two shapes) and beats about the shoulder, half folding on the
// upstroke; each leg is solved from the knee to where its foot is to be (two
// bones, the hock bending backwards), the toes level, curling as the foot
// swings forward.
//
// Lit as Toon (scripts/toon.gd in The Clearing) lights figures: two flat tones
// with a one-pixel edge between them, a rim of light round the feathers (a
// green sheen on black ones), a glint in the eye.

shader_type spatial;
render_mode cull_disabled;

uniform vec4 pose[64];
uniform vec4 looks[16];
// How dirty the birds are: mud up the legs and the belly.
uniform float filth = 0.6;
uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.22;

// The joints at rest (keep to ChickenBody's). +X is her left.
const vec3 NECK_BASE = vec3(0.0, 0.37, 0.1);
const vec3 HEAD = vec3(0.0, 0.49, 0.168);
const vec3 KNEE = vec3(0.062, 0.245, 0.005);
const vec3 HOCK = vec3(0.056, 0.122, -0.032);
const vec3 FOOT = vec3(0.052, 0.026, 0.012);
const vec3 SHOULDER = vec3(0.07, 0.355, 0.07);
const vec3 TAIL_ROOT = vec3(0.0, 0.39, -0.17);
const vec3 HIP = vec3(0.0, 0.27, 0.0);
const vec3 HINGE = vec3(0.0, 0.484, 0.196);
const vec3 MIDDLE = vec3(0.0, 0.3, -0.02);

varying float part;
varying float region;
varying float along;
varying float tag;
varying float across;
varying vec3 rest;
varying float variant;
varying float rooster;
varying float seed;

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

// The rotation about `axis` (unit) by `a`.
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

// The rotation that turns `from` onto `to` (both unit).
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

// The body: pitched about the hip, rolled with the step, raised or lowered.
struct Body {
	mat3 turn;
	vec3 lift;
};

vec3 on_body(Body b, vec3 v) {
	return HIP + b.turn * (v - HIP) + b.lift;
}

// Where a foot is to be, and how far its toes curl, for one leg (`side` 1 her
// left, -1 her right) on the walk phase `phase`.
vec4 foot_goal(float side, float phase, float step_len, float scratch, float tuck) {
	vec3 foot = vec3(FOOT.x * side, 0.0, FOOT.z);
	// Walking: on the ground for the first 60% of the stride, sliding back;
	// then lifted and swung forward, the toes curled up under.
	float duty = 0.6;
	float curl = 0.0;
	vec3 walk = foot;
	if (phase < duty) {
		walk.z += step_len * (0.5 - phase / duty);
	} else {
		float u = (phase - duty) / (1.0 - duty);
		float swing = smoothstep(0.0, 1.0, u);
		walk.z += step_len * (swing - 0.5);
		walk.y += (0.025 + 0.22 * step_len) * sin(3.14159 * u);
		curl = sin(3.14159 * min(u * 1.3, 1.0)) * min(step_len * 12.0, 1.0);
	}
	// Scratching: this foot reaches forward and rakes back hard over the
	// ground on its half of the phase, and stands while the other rakes.
	vec3 rake = foot;
	float rake_curl = 0.0;
	float mine = side > 0.0 ? phase : fract(phase + 0.5);
	if (mine < 0.5) {
		float u = mine / 0.5;
		float back = smoothstep(0.2, 0.7, u);
		rake.z += 0.075 - 0.19 * back;
		rake.y += 0.045 * (1.0 - smoothstep(0.08, 0.25, u)) * step(u, 0.5) + 0.05 * smoothstep(0.7, 1.0, u);
		rake_curl = 0.6 * smoothstep(0.7, 0.9, u);
	} else {
		rake.z -= 0.01;
	}
	vec3 goal = mix(walk, rake, scratch);
	curl = mix(curl, rake_curl, scratch);
	// Flying: drawn up under the body, the toes balled.
	goal = mix(goal, vec3(0.04 * side, 0.2, -0.06), tuck);
	curl = mix(curl, 1.0, tuck);
	return vec4(goal, curl);
}

void vertex() {
	int i = INSTANCE_ID;
	vec4 p0 = pose[i * 4];
	vec4 p1 = pose[i * 4 + 1];
	vec4 p2 = pose[i * 4 + 2];
	vec4 p3 = pose[i * 4 + 3];
	vec4 look = looks[i];
	variant = look.x;
	rooster = look.y;
	seed = look.z;

	part = CUSTOM0.x;
	region = CUSTOM0.y;
	along = CUSTOM0.z;
	tag = CUSTOM0.w;
	across = CUSTOM1.w;
	rest = vec3(UV2, CUSTOM2.w);
	int bone = int(CUSTOM1.x + 0.5);
	float share = CUSTOM1.y;
	float sex = CUSTOM1.z;
	vec3 v = VERTEX;
	vec3 n = NORMAL;

	// The other's parts, and molted feathers, are not drawn.
	bool hidden = (sex > 0.5 && sex < 1.5 && rooster > 0.5) || (sex > 1.5 && rooster < 0.5);
	int kind = int(part + 0.5);
	if (kind == 0 && bone != 4 && bone != 5 && hash(tag * 91.0 + seed * 17.0) < look.w * 0.35) {
		hidden = true;
	}

	float puff = p2.w;
	float walk_phase = p0.x;
	float step_len = p0.y;
	float scratch = p0.z;
	float tuck = p0.w;

	// Puffed up, the feathers stand off the body, tips most; the hackles flare.
	if ((kind == 0 || kind == 1) && bone <= 3) {
		float lift = puff * (kind == 0 ? 0.012 + 0.03 * along : 0.01);
		vec3 out_dir = normalize(v - MIDDLE + vec3(0.0, 0.0, 0.0001));
		if (bone == 1 && share > 0.05 && share < 0.98 && region > 1.5 && region < 2.5) {
			// (a hackle: out from the neck)
			vec3 axis = normalize(HEAD - NECK_BASE);
			vec3 rel = v - NECK_BASE;
			out_dir = normalize(rel - axis * dot(rel, axis) + vec3(0.0, 0.0001, 0.0));
			lift = puff * (0.01 + 0.05 * along);
		}
		v += out_dir * lift;
	}

	// The body.
	float stepping = clamp(step_len * 10.0, 0.0, 1.0) * (1.0 - tuck);
	Body body;
	float roll = 0.05 * sin(6.2831853 * walk_phase) * stepping;
	body.turn = rot_x(p3.w) * rot_z(roll);
	body.lift = vec3(0.0, -0.008 * cos(12.566 * walk_phase) * stepping - 0.012 * scratch - 0.06 * clamp(p3.w, 0.0, 0.8), 0.0);

	vec3 at = v;
	vec3 facing = n;
	if (bone == 1 || bone == 2) {
		// The head where it is put, turned; the neck between body and head.
		vec3 hv = v;
		vec3 hn = n;
		if (bone == 2) {
			mat3 open = rot_x(p2.z * 0.55);
			hv = HINGE + open * (v - HINGE);
			hn = open * n;
		}
		mat3 head_turn = rot_y(p1.w) * rot_x(p2.x) * rot_z(p2.y);
		vec3 head_at = HEAD + p1.xyz;
		vec3 on_head = head_at + head_turn * (hv - HEAD);
		vec3 on_head_n = head_turn * hn;
		vec3 on_b = on_body(body, v);
		vec3 on_b_n = body.turn * n;
		float w = bone == 2 ? 1.0 : share;
		at = mix(on_b, on_head, w);
		facing = mix(on_b_n, on_head_n, w);
	} else if (bone == 3) {
		// The tail: lifted and spread when puffed up or flying.
		float lift_by = 0.35 * puff + 0.25 * p3.z - 0.1 * scratch;
		float spread = sign(v.x) * (0.15 * puff + 0.3 * p3.z);
		mat3 t = rot_x(-lift_by) * rot_z(spread);
		at = on_body(body, TAIL_ROOT + t * (v - TAIL_ROOT));
		facing = body.turn * t * n;
	} else if (bone == 4 || bone == 5) {
		float side = bone == 4 ? 1.0 : -1.0;
		float beat = 6.2831853 * p3.y;
		float strength = p3.z;
		// (half folded on the upstroke)
		float open = p3.x * (1.0 - 0.2 * strength * max(-sin(beat), 0.0));
		vec3 wv = mix(v, CUSTOM2.xyz, open);
		vec3 wn = normalize(mix(n, CUSTOM3.xyz, open));
		vec3 shoulder = vec3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z);
		// Beating: up and down about the shoulder, swept forward on the downstroke.
		float up = strength * 0.75 * cos(beat) * open + (0.12 + 0.12 * strength) * open;
		float sweep = strength * 0.25 * sin(beat) * open;
		mat3 w = rot_y(side * sweep) * rot_z(side * up);
		at = on_body(body, shoulder + w * (wv - shoulder));
		facing = body.turn * w * wn;
	} else if (bone >= 6) {
		// A leg: from the knee (on the body) to where the foot is to be.
		float side = (bone % 2 == 0) ? 1.0 : -1.0;
		float phase = side > 0.0 ? walk_phase : fract(walk_phase + 0.5);
		vec4 goal = foot_goal(side, phase, step_len, scratch, tuck);
		vec3 knee0 = vec3(KNEE.x * side, KNEE.y, KNEE.z);
		vec3 hock0 = vec3(HOCK.x * side, HOCK.y, HOCK.z);
		vec3 foot0 = vec3(FOOT.x * side, FOOT.y, FOOT.z);
		vec3 knee = on_body(body, knee0);
		vec3 foot = goal.xyz + vec3(0.0, FOOT.y, 0.0);
		float l1 = length(hock0 - knee0);
		float l2 = length(foot0 - hock0);
		vec3 d = foot - knee;
		float dist = clamp(length(d), 0.03, l1 + l2 - 0.002);
		vec3 dn = normalize(d);
		foot = knee + dn * dist;
		float a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist);
		float h = sqrt(max(l1 * l1 - a * a, 0.0));
		// (the hock bends backwards)
		vec3 back = normalize(cross(vec3(1.0, 0.0, 0.0), dn));
		if (back.z > 0.0) {
			back = -back;
		}
		vec3 hock = knee + dn * a + back * h;
		mat3 thigh_turn = turn_onto(normalize(hock0 - knee0), normalize(hock - knee));
		mat3 shank_turn = turn_onto(normalize(foot0 - hock0), normalize(foot - hock));
		vec3 on_thigh = knee + thigh_turn * (v - knee0);
		vec3 on_thigh_n = thigh_turn * n;
		if (bone <= 7) {
			at = on_thigh;
			facing = on_thigh_n;
		} else if (bone <= 9) {
			vec3 on_shank = hock + shank_turn * (v - hock0);
			at = mix(on_thigh, on_shank, share);
			facing = mix(on_thigh_n, shank_turn * n, share);
		} else {
			// The toes stay level (turned with the body's yaw only), each
			// curling down and in about its root, the further out the more.
			vec3 rel = v - foot0;
			vec2 flat_dir = normalize(rel.xz + vec2(0.0001, 0.0));
			vec3 bend_axis = normalize(cross(vec3(0.0, 1.0, 0.0), vec3(flat_dir.x, 0.0, flat_dir.y)));
			mat3 curl = rot_axis(bend_axis, goal.w * 1.3 * share);
			at = foot + curl * rel;
			facing = curl * n;
		}
	} else {
		at = on_body(body, v);
		facing = body.turn * n;
	}
	if (hidden) {
		at = vec3(0.0);
	}
	VERTEX = at;
	NORMAL = normalize(facing);
}

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// A feather's colour: its region's, by the bird's colours, with the bird's
// own patterns (lacing, speckles, the hackle's dark stripe).
vec3 feather_colour(int reg, float v_, float t, float x, float cock) {
	int col = int(v_ + 0.5);
	float edge = smoothstep(0.55, 0.95, abs(x));
	float shaft = 1.0 - smoothstep(0.06, 0.14, abs(x));
	vec3 c;
	if (col == 0) {
		// Red-brown: rust, the hackle golden, the tail and flight feathers near black.
		vec3 body_c = srgb(vec3(0.6, 0.35, 0.17));
		vec3 back_c = srgb(vec3(0.52, 0.28, 0.12));
		vec3 hackle_c = srgb(vec3(0.7, 0.44, 0.2));
		if (cock > 0.5) {
			body_c = srgb(vec3(0.1, 0.075, 0.06));
			back_c = srgb(vec3(0.55, 0.19, 0.07));
			hackle_c = srgb(vec3(0.9, 0.56, 0.2));
		}
		if (reg == 0 || reg == 8) {
			c = body_c;
		} else if (reg == 1) {
			c = back_c;
		} else if (reg == 2 || reg == 7) {
			c = mix(hackle_c, hackle_c * 0.45, shaft * 0.6);
		} else if (reg == 3) {
			c = cock > 0.5 ? srgb(vec3(0.52, 0.17, 0.07)) : back_c * 1.05;
		} else if (reg == 4) {
			c = mix(srgb(vec3(0.42, 0.22, 0.1)), srgb(vec3(0.12, 0.08, 0.06)), smoothstep(0.1, 0.6, x * sign(x)) * (cock > 0.5 ? 0.8 : 0.45));
			c = mix(c, back_c, smoothstep(0.7, 0.3, t) * 0.3);
		} else {
			c = cock > 0.5 ? srgb(vec3(0.07, 0.065, 0.06)) : srgb(vec3(0.17, 0.12, 0.08));
		}
	} else if (col == 1) {
		// Speckled: mahogany, each feather with a black bar and a white tip.
		vec3 base = srgb(vec3(0.46, 0.25, 0.12));
		if (reg == 5 || reg == 6) {
			base = srgb(vec3(0.07, 0.065, 0.06));
		} else if (reg == 4) {
			base = mix(srgb(vec3(0.35, 0.16, 0.07)), srgb(vec3(0.85, 0.82, 0.74)), step(0.5, fract(t * 4.0 + 0.2)) * 0.7);
		} else if (reg == 2 || reg == 7) {
			base = srgb(vec3(0.55, 0.28, 0.1));
		}
		float bar = smoothstep(0.6, 0.66, t) * (1.0 - smoothstep(0.8, 0.84, t));
		float tip = smoothstep(0.84, 0.88, t);
		c = mix(base, srgb(vec3(0.05, 0.045, 0.04)), bar);
		c = mix(c, srgb(vec3(0.9, 0.88, 0.82)), tip * (reg == 4 ? 0.5 : 1.0));
	} else if (col == 2) {
		// White: dingy, yellowed and grey in places.
		c = srgb(vec3(0.86, 0.84, 0.77));
		if (reg == 4 || reg == 5 || reg == 6) {
			c = srgb(vec3(0.8, 0.8, 0.76));
		}
		if (reg == 2 || reg == 7) {
			c = srgb(vec3(0.9, 0.86, 0.72));
		}
	} else {
		// Black.
		c = srgb(vec3(0.075, 0.075, 0.08));
	}
	// The shaft, and the vane's edges.
	c *= 1.0 + 0.18 * shaft * (col == 3 ? 0.0 : 1.0) - 0.15 * edge;
	return c;
}

void fragment() {
	int kind = int(part + 0.5);
	int reg = int(region + 0.5);
	vec3 colour;
	float wet = 0.0;
	vec3 rim_colour = vec3(0.0);
	float rim_on = 0.0;
	int col = int(variant + 0.5);
	// (each feather its own a little)
	float own = hash(tag * 53.0 + 1.3);
	if (kind == 0 || kind == 1) {
		if (kind == 1) {
			// The under-down: the body's colour, darker.
			colour = feather_colour(rest.y > 0.36 && rest.z < 0.0 ? 1 : 0, variant, 0.4, 0.5, rooster) * 0.7;
		} else {
			colour = feather_colour(reg, variant, along, across, rooster);
			colour *= 0.88 + 0.24 * own;
		}
		rim_on = 1.0;
		rim_colour = col == 3 ? srgb(vec3(0.15, 0.35, 0.22)) : colour * 1.5;
		if (col == 0 && rooster > 0.5 && (reg == 5 || reg == 6 || reg == 0)) {
			rim_colour = srgb(vec3(0.12, 0.3, 0.22));
		}
	} else if (kind == 2) {
		// The comb, the wattles and the face: red, darker at the edges.
		colour = srgb(vec3(0.62, 0.07, 0.05)) * (0.85 + 0.15 * own);
		wet = 0.0;
	} else if (kind == 3) {
		colour = col == 2 ? srgb(vec3(0.88, 0.85, 0.78)) : srgb(vec3(0.66, 0.12, 0.08));
		wet = 0.0;
	} else if (kind == 4) {
		vec3 horn = col == 3 ? srgb(vec3(0.24, 0.21, 0.19)) : srgb(vec3(0.78, 0.66, 0.38));
		colour = mix(horn * 0.8, horn * 1.1, along);
	} else if (kind == 5) {
		// Scaly legs: rings of scales, darker in their seams.
		vec3 skin = (col == 1 || col == 3) ? srgb(vec3(0.5, 0.52, 0.5)) : srgb(vec3(0.8, 0.64, 0.25));
		float rings = abs(fract(along * 9.0) - 0.5);
		float seam = 1.0 - smoothstep(0.32, 0.46, rings);
		colour = skin * (1.0 - 0.3 * (1.0 - seam));
	} else if (kind == 6) {
		colour = srgb(vec3(0.22, 0.19, 0.16));
	} else if (kind == 7) {
		// The eye: a black pupil in an orange iris.
		float off = UV.y;
		colour = off < 0.17 ? vec3(0.01) : (off < 0.42 ? srgb(vec3(0.85, 0.45, 0.08)) : srgb(vec3(0.3, 0.12, 0.05)));
		wet = 1.0;
	} else {
		colour = vec3(0.02);
	}
	// Filthy: mud up the legs and under the belly, in splashes.
	float mud_line = 0.2 + 0.06 * hash(floor(rest.x * 40.0) + floor(rest.z * 40.0) * 7.0 + seed * 11.0);
	float mud = filth * (1.0 - smoothstep(mud_line - 0.08, mud_line, rest.y));
	if (kind == 5 || kind == 6 || kind <= 1) {
		colour = mix(colour, srgb(vec3(0.17, 0.13, 0.09)), mud * (kind == 5 ? 0.55 : 0.7));
	}
	ALBEDO = colour;
	SPECULAR = 0.0;
	// What light() needs, in what it can read: ROUGHNESS 1 a rim of light (the
	// feathers), 0.5 wet with a glint (the eye; the comb a little), else plain.
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
	} else if (ROUGHNESS > 0.4 && ROUGHNESS < 0.6) {
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 140.0), 0.5);
		SPECULAR_LIGHT += shine * BACKLIGHT.x * 1.5 * LIGHT_COLOR;
	}
}
