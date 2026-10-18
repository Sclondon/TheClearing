// A rat (RatLook, Rat, RatSwarm, RatKing), drawn one or a few hundred at a
// time as one MultiMesh. The mesh (models/rat.glb or rat_lo.glb, made by
// tools/build_rats.py) is one brown rat standing still, in metres, facing +Z;
// everything it does is posed here. Each point says (not in colours: the web
// gives a MultiMesh's points none it can be sure of):
//   UV.x   which part, in sixteenths (0 body, 1 head, 2 whisker, 3 jaw, 4 and 5
//          the left and right front leg, 6 and 7 the left and right hind leg,
//          8 the tail, 15 not posed)
//   UV.y   how far out along it (0 at its root; along the body 0 at the rump)
//   UV2.x  its colour, in eighths (0 fur, 1 pink skin, 2 tail, 3 eye, 4 tooth,
//          5 whisker, 6 filth, 7 the inside of the mouth)
//   UV2.y  how pale the fur is there (0 the back, 1 the belly)
// and each rat, in its custom data (RatLook.custom packs it):
//   x  how far through its stride, in whole strides (it wraps at 8)
//   y  how fast it goes (the fraction: 0 standing, up to 1 flat out) and how its
//      back bends to the side (the whole part: 0 to 16, 8 straight)
//   z  how far it is reared up (the fraction), and what else it is doing (the
//      whole part, in bits: 1 its mouth open, 2 its tail bound into a rat
//      king's knot (only its root shows), 4 its head down to the ground)
//   w  its own number, 0 to 1 (its colour, and the time its twitches keep)
//
// The gait goes from a walk (the legs one after another) to the bounding
// scurry of a rat in a hurry (the front feet together, then the hind, the back
// arching and stretching); the head sniffs about, the whiskers twitch, the tail
// sways after it. Reared, it sits up on its haunches with its hands to its
// chest and its nose up. Lit in two flat tones with a soft rim of fur, as the
// figures are.

shader_type spatial;
render_mode cull_back, shadows_disabled;

uniform vec3 fur : source_color = vec3(0.235, 0.2, 0.165);
uniform vec3 belly : source_color = vec3(0.47, 0.43, 0.38);
uniform vec3 skin : source_color = vec3(0.6, 0.46, 0.44);
uniform vec3 tail_skin : source_color = vec3(0.47, 0.4, 0.39);
uniform vec3 eye : source_color = vec3(0.012, 0.01, 0.01);
uniform vec3 tooth : source_color = vec3(0.74, 0.52, 0.2);
uniform vec3 whisker : source_color = vec3(0.55, 0.53, 0.5);
uniform vec3 filth : source_color = vec3(0.13, 0.1, 0.085);
uniform vec3 mouth : source_color = vec3(0.22, 0.06, 0.06);
// How far each rat's colour wanders from the rest (darker, greyer, browner).
uniform float tone_spread = 0.28;
// How far a foot swings (radians about its root) and lifts (m), flat out.
uniform float swing = 0.75;
uniform float lift = 0.012;
uniform float rim_gain = 0.55;

// Where the parts turn, in metres (models/rat.json, written by build_rats.py:
// keep in step when the model is built again).
const vec3 SHOULDER = vec3(0.019, 0.047, 0.04);
const vec3 HIP = vec3(0.026, 0.05, -0.058);
const vec3 NECK = vec3(0.0, 0.056, 0.07);
const vec3 JAW = vec3(0.0, 0.037, 0.11);
const vec3 TAIL = vec3(0.0, 0.04, -0.104);
const vec3 HAUNCH = vec3(0.0, 0.02, -0.07);

varying flat float code;
varying float pale;
varying float tone;
varying float along;

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

void vertex() {
	int part = int(UV.x * 16.0);
	along = UV.y;
	float stride = INSTANCE_CUSTOM.x;
	float go = fract(INSTANCE_CUSTOM.y);
	float bend = (floor(INSTANCE_CUSTOM.y) - 8.0) / 8.0;
	float rear = fract(INSTANCE_CUSTOM.z);
	int flags = int(floor(INSTANCE_CUSTOM.z) + 0.5);
	float own = INSTANCE_CUSTOM.w;
	bool open = (flags & 1) != 0;
	bool curl = (flags & 2) != 0;
	bool feed = (flags & 4) != 0;
	float t = TIME + own * 37.0;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float moving = smoothstep(0.0, 0.05, go);
	float bound = smoothstep(0.35, 0.85, go);

	if (part != 15) {
		// The legs: a walk (left hind, left fore, right hind, right fore, a quarter apart) at a walk, going over to
		// a bound flat out (both fore together, then both hind, half a stride on).
		if (part >= 4 && part <= 7) {
			float walk = part == 6 ? 0.0 : part == 4 ? 0.25 : part == 7 ? 0.5 : 0.75;
			float hop = part == 6 ? 0.0 : part == 7 ? 0.07 : part == 4 ? 0.5 : 0.57;
			float phase = (stride + mix(walk, hop, bound)) * TAU;
			vec3 root = part >= 6 ? HIP : SHOULDER;
			root.x *= (part == 5 || part == 7) ? -1.0 : 1.0;
			float reach = smoothstep(0.0, 0.6, along);
			float a = -sin(phase) * swing * (0.45 + 0.55 * go) * moving;
			v = turn_x(v, root, a * reach);
			n = turn_x(n, vec3(0.0), a * reach);
			v.y += max(cos(phase), 0.0) * lift * (0.5 + go) * moving * reach;
			if (part <= 5) {
				// (reared, the hands come up to the chest)
				v = turn_x(v, root, -rear * 1.5 * smoothstep(0.0, 0.3, along));
				n = turn_x(n, vec3(0.0), -rear * 1.5);
			}
		}
		// The head sniffs about, more when still; down to the ground to feed; the jaw drops to squeal; whiskers twitch.
		if (part >= 1 && part <= 3) {
			float neck = smoothstep(NECK.z - 0.004, NECK.z + 0.03, v.z);
			float look = sin(t * 1.3) * 0.35 + sin(t * 3.1) * 0.12;
			float nod = sin(t * 2.2) * 0.12 + (feed ? 0.75 + 0.12 * sin(t * 7.0) : 0.0) - rear * 0.55;
			if (part == 3 || open) {
				float gape = open ? 0.38 + 0.12 * sin(t * 31.0) : 0.04 * max(sin(t * 9.0), 0.0) * (feed ? 4.0 : 1.0);
				if (part == 3) {
					v = turn_x(v, JAW, gape);
					n = turn_x(n, vec3(0.0), gape);
				}
			}
			if (part == 2) {
				float twitch = sin(t * 23.0 + along * 2.0) * 0.12 * along;
				v = turn_y(v, vec3(sign(v.x) * 0.007, v.y, 0.129), twitch * sign(v.x));
			}
			v = turn_x(v, NECK, nod * (1.0 - go * 0.6) * neck);
			v = turn_y(v, NECK, look * (1.0 - go * 0.8) * neck);
			n = turn_x(n, vec3(0.0), nod * (1.0 - go * 0.6) * neck);
			n = turn_y(n, vec3(0.0), look * (1.0 - go * 0.8) * neck);
		}
		// The tail sways after it, the more the faster it goes; a rat king's is bound into the knot.
		if (part == 8) {
			float sway = sin(along * 7.0 - t * (2.5 + 7.0 * go)) * (0.012 + 0.02 * go) * along;
			v.x += sway;
			if (curl) {
				// (bound into a rat king's knot: only its root shows, going down into the tangle; the rest is
				// drawn up into the knot, out of sight)
				v.x -= sway;
				v.y -= smoothstep(0.0, 0.32, along) * 0.02;
				if (along > 0.32) {
					v = TAIL + vec3(0.0, -0.025, -0.07);
				}
			}
			// (the root of it goes up with the rump when it rears; the rest lies on the ground)
			v = turn_x(v, HAUNCH, rear * 0.55 * (1.0 - smoothstep(0.0, 0.25, along)));
		}
		// The back: arched and stretched in a bound (the rump rides up as the hind feet come in under it).
		float hind = smoothstep(0.02, -0.08, v.z);
		float arch = sin(stride * TAU + 0.8) * 0.009 * bound;
		v.y += arch * hind * (part == 8 ? 1.0 - along : 1.0);
		v.y += abs(sin(stride * TAU)) * 0.004 * go * (1.0 - rear);
		// Bent to one side: a curve along the length of it (the middle still, nose and rump to the one side).
		float off = v.z + 0.01;
		v.x += bend * 1.6 * off * off * (part == 8 ? 0.5 : 1.0);
		// Reared up on its haunches, nose up (the hind feet stay flat on the ground, the haunches go with the body).
		if (part != 8) {
			float sit = -rear * 1.05;
			if (part == 6 || part == 7) {
				sit *= 1.0 - smoothstep(0.2, 0.5, along);
			}
			v = turn_x(v, HAUNCH, sit);
			n = turn_x(n, vec3(0.0), sit);
		}
		if (part == 8 || part == 6 || part == 7) {
			v.y = max(v.y, 0.0015);
		}
	}
	VERTEX = v;
	NORMAL = n;
	code = floor(UV2.x * 8.0);
	pale = UV2.y;
	// (each its own shade: some darker, some greyer)
	tone = 1.0 + (fract(own * 7.31) - 0.5) * tone_spread;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	int which = int(code + 0.5);
	vec3 c = mix(fur, belly, smoothstep(0.2, 0.9, pale));
	c *= tone;
	if (which == 1) {
		// (inside the ears greyer: thin skin with a little fur over it)
		c = pale > 0.9 ? mix(skin, fur, 0.45) : skin;
	} else if (which == 2) {
		// (scaly: rings round it, close together)
		float ring = abs(fract(along * 64.0) - 0.5);
		c = tail_skin * mix(0.78, 1.0, smoothstep(0.08, 0.2, ring)) * mix(0.8, 1.05, clamp(along, 0.0, 1.0));
	} else if (which == 3) {
		c = eye;
	} else if (which == 4) {
		c = tooth;
	} else if (which == 5) {
		c = whisker;
	} else if (which == 6) {
		c = filth * tone;
	} else if (which == 7) {
		c = mouth;
	}
	ALBEDO = c;
	// (a glint in the eye)
	SPECULAR = which == 3 ? 0.9 : 0.0;
	ROUGHNESS = which == 3 ? 0.15 : 1.0;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.4) / 1.4;
	float lit = cut(facing, 0.08) * mix(0.55, 1.0, reach);
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, 0.6) : reach;
	DIFFUSE_LIGHT += mix(0.35, 1.0, lit) * strength * LIGHT_COLOR / PI;
	// The fur's soft rim, where it is seen aslant.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += smoothstep(0.55, 0.95, graze) * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
	if (ROUGHNESS < 0.5) {
		float shine = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 60.0);
		SPECULAR_LIGHT += cut(shine, 0.5) * strength * LIGHT_COLOR * 0.8;
	}
}
