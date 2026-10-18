// The griffinfly (GriffinflyLook makes the mesh, Griffinfly moves it): a giant
// dragonfly of the coal forests, posed here and nowhere else, so that it is one
// draw however much it moves.
//
// What each point is, in its texture coordinates (not colours: the web's
// renderer turns colours from sRGB on their way here):
//   UV2.x  the part: 0 the thorax, 1 the face, 2 an eye, 3 a jaw, 4 a feeler,
//          5 the abdomen, 6 7 8 the fore, middle and hind pair of legs,
//          9 a forewing, 10 a hindwing
// Its points are as the model has them (one unit across the wings, facing +Z);
// what the shader does to them it is told by its uniforms, every frame:
//
// THE WINGS each turn rigidly about their own hinge (where they meet the thorax),
// each by its own angles (`beat`, `sweep`, `twist`, one for each wing: the right
// and left forewing, the right and left hindwing): raised and lowered about the
// line of the body, swept forward and back, and twisted about their own length
// (the leading edge down on the downstroke, up on the upstroke). Beating fast,
// they are drawn as a stipple of themselves (`blur`).
// THE HEAD (face, eyes, jaws, feelers) turns about its neck (`head_turn`: yaw,
// pitch); the jaws open and snap shut (`jaws`).
// THE LEGS swing about their hips: forward and down into a basket under the head
// (`basket`), or down and out to grip where it rests (`grip`).
// THE ABDOMEN bends evenly along its length, down (`curl`) and to the side (`sway`).
//
// Lit as Warren lights its figures: two flat tones with a hard edge between them.
// The eyes shine and are faceted, the chitin has a dull bronze sheen, and a wing
// is a smoky membrane in a dense net of veins that light comes through.

shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_always;

// Where its wings are hinged (the right side), its legs' hips (the right side)
// and its neck: as the model (tools/build_griffinfly.py) has them.
const vec3 HINGE_FORE = vec3(0.012, 0.043, 0.13);
const vec3 HINGE_HIND = vec3(0.012, 0.041, 0.088);
const vec3 HIP_FORE = vec3(0.009, -0.03, 0.163);
const vec3 HIP_MID = vec3(0.012, -0.032, 0.138);
const vec3 HIP_HIND = vec3(0.014, -0.03, 0.112);
const vec3 NECK = vec3(0.0, 0.004, 0.19);
const vec3 JAW_ROOT = vec3(0.016, -0.022, 0.232);
// Where the abdomen begins, and how long it is.
const float ABDOMEN_ROOT = 0.068;
const float ABDOMEN_LENGTH = 0.44;

// Each wing's angles: x the right forewing, y the left, z the right hindwing, w the left.
uniform vec4 beat = vec4(0.0);
uniform vec4 sweep = vec4(0.0);
uniform vec4 twist = vec4(0.0);
uniform float blur = 0.0;
uniform vec2 head_turn = vec2(0.0);
uniform float jaws = 0.0;
uniform float basket = 0.0;
uniform float grip = 0.0;
uniform float curl = 0.0;
uniform float sway = 0.0;
// Its own shade (0..1), so that no two are quite alike.
uniform float tone = 0.5;

uniform float wrap = 0.35;
uniform float flatness = 0.6;
uniform float rim_gain = 0.3;

varying float part;
varying vec3 rest;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// Turns `v` (and its normal) about the point `pivot`: yaw about Y, then pitch about X.
void about(inout vec3 v, inout vec3 n, vec3 pivot, float yaw, float pitch) {
	vec3 p = v - pivot;
	p.yz = turn(p.yz, pitch);
	n.yz = turn(n.yz, pitch);
	p.xz = turn(p.xz, -yaw);
	n.xz = turn(n.xz, -yaw);
	v = pivot + p;
}

void vertex() {
	part = UV2.x;
	rest = VERTEX;
	int which = int(part + 0.5);
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float side = v.x < 0.0 ? -1.0 : 1.0;
	if (which >= 9) {
		// A wing: twisted about its length, swept, then raised about its hinge.
		bool hind = which == 10;
		vec3 hinge = hind ? HINGE_HIND : HINGE_FORE;
		int k = (hind ? 2 : 0) + (side < 0.0 ? 1 : 0);
		float lift = beat[k];
		float back = sweep[k];
		float pitch = twist[k];
		v.x *= side;
		n.x *= side;
		vec3 p = v - hinge;
		p.yz = turn(p.yz, pitch);
		n.yz = turn(n.yz, pitch);
		p.xz = turn(p.xz, -back);
		n.xz = turn(n.xz, -back);
		p.xy = turn(p.xy, lift);
		n.xy = turn(n.xy, lift);
		v = hinge + p;
		v.x *= side;
		n.x *= side;
	} else if (which >= 6) {
		// A leg, about its hip: forward and down into the basket, or down and out to grip.
		vec3 hip = which == 6 ? HIP_FORE : (which == 7 ? HIP_MID : HIP_HIND);
		float reach = which == 6 ? 1.0 : (which == 7 ? 0.8 : 0.65);
		v.x *= side;
		n.x *= side;
		vec3 p = v - hip;
		float down = basket * 0.55 * reach + grip * (which == 6 ? 0.2 : 0.75);
		float out_ = basket * 0.35 + grip * 0.6;
		float on = grip * (which == 6 ? -0.5 : (which == 8 ? 0.6 : 0.1));
		p.yz = turn(p.yz, -down);
		n.yz = turn(n.yz, -down);
		p.xy = turn(p.xy, -out_);
		n.xy = turn(n.xy, -out_);
		p.xz = turn(p.xz, on);
		n.xz = turn(n.xz, on);
		v = hip + p;
		v.x *= side;
		n.x *= side;
	} else if (which >= 1 && which <= 4) {
		// The head: the jaws open about their roots, then all of it turns about the neck.
		if (which == 3) {
			vec3 root = JAW_ROOT * vec3(side, 1.0, 1.0);
			vec3 p = v - root;
			float open_ = jaws * 0.75 * side;
			p.xz = turn(p.xz, open_);
			n.xz = turn(n.xz, open_);
			v = root + p;
		}
		about(v, n, NECK, head_turn.x, head_turn.y);
	} else if (which == 5 && v.z < ABDOMEN_ROOT) {
		// The abdomen: bent evenly along its length (an arc), down and to the side.
		float s = ABDOMEN_ROOT - v.z;
		float t = s / ABDOMEN_LENGTH;
		float k = curl / ABDOMEN_LENGTH;
		float a = k * s;
		float base_y = 0.008;
		vec2 centre;
		if (abs(k) < 0.0001) {
			centre = vec2(ABDOMEN_ROOT - s, base_y);
		} else {
			centre = vec2(ABDOMEN_ROOT - sin(a) / k, base_y - (1.0 - cos(a)) / k);
		}
		vec2 normal_ = vec2(-sin(a), cos(a));
		float up = v.y - base_y;
		vec2 zy = centre + normal_ * up;
		v.z = zy.x;
		v.y = zy.y;
		n.yz = turn(n.yz, -a);
		float aside = sway * t;
		vec2 xz = turn(vec2(v.x, v.z - ABDOMEN_ROOT), aside * 0.5);
		v.x = xz.x + sway * t * t * 0.12;
		v.z = xz.y + ABDOMEN_ROOT;
	}
	VERTEX = v;
	NORMAL = normalize(n);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A line `width` wide where `value` is 0, its edge a pixel soft.
float line(float value, float width) {
	float pixel = max(fwidth(value), 0.0002);
	return 1.0 - smoothstep(width, width + pixel * 1.5, abs(value));
}

// Ordered stipple: is this pixel one of the `amount` (0..1) that are drawn?
bool stippled(vec2 pixel, float amount) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = x + y * 4;
	float order[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (order[index] + 0.5) / 16.0 < amount;
}

// A griffinfly's wing (1 on a vein): a thick dark leading edge (the costa and
// the veins packed behind it), long veins running out nearly side by side from
// the root, more of them branching in further out, and between them a dense net
// of cross-veins; no node and no dark spot near the tip (its kind had none).
float veins(vec2 uv, bool hind) {
	vec3 hinge = hind ? HINGE_HIND : HINGE_FORE;
	vec2 from = uv - hinge.xz;
	float out_ = max(from.x, 0.0);
	// (how far in front of or behind the hinge's line, squeezed as the wing narrows to its tip)
	float across = from.y / (0.04 + 0.03 * sin(3.14159 * clamp(out_ * 2.1, 0.0, 1.0)));
	// (the front edge: the costa, and the veins packed in behind it, a dark band)
	float front = (hind ? 0.026 : 0.03) * (1.0 - 1.8 * out_ * out_) + 0.004;
	float leading = 1.0 - smoothstep(0.0025, 0.0045, front - from.y);
	leading *= step(from.y, front + 0.004);
	float long_ = line(fract(across * 3.5 + out_ * 1.5) - 0.5, 0.05);
	float cross_ = line(fract(out_ * 110.0 + noise(vec2(across * 7.0, out_ * 25.0)) * 0.7) - 0.5, 0.045) * 0.45;
	return clamp(leading + long_ * 0.6 + cross_, 0.0, 1.0);
}

void fragment() {
	int which = int(part + 0.5);
	vec3 colour = vec3(0.16, 0.13, 0.1);
	float sheen = 0.2;
	float glint = 0.0;
	float lit_through = 0.0;
	float shade = 0.92 + 0.16 * tone;
	float wing_alpha = 1.0;
	if (which >= 9) {
		bool hind = which == 10;
		vec2 uv = vec2(abs(rest.x), rest.z);
		float vein = veins(uv, hind);
		// (smoky, darker towards the root and along the front)
		float smoke = 0.5 + 0.35 * smoothstep(0.25, 0.0, uv.x - 0.012);
		vec3 skin = mix(vec3(0.6, 0.59, 0.56), vec3(0.42, 0.39, 0.34), smoke * 0.6);
		vec3 rib = vec3(0.12, 0.1, 0.08);
		colour = mix(skin, rib, vein);
		// A clear membrane, the veins seen whole; beating hard, a blur of itself.
		wing_alpha = mix(0.16 + 0.12 * smoke, 0.92, vein) * (1.0 - blur * 0.6);
		sheen = 0.15;
		lit_through = 0.7;
	} else if (which == 2) {
		// The eyes: dark olive, faceted, wet, with a glint; a paler band round where they meet the head.
		vec3 e = normalize(vec3(abs(rest.x) - 0.025, rest.y - 0.021, rest.z - 0.214));
		vec2 facet = vec2(atan(e.z, e.x) * 9.0, e.y * 14.0);
		facet.x += 0.5 * mod(floor(facet.y), 2.0);
		float cell = length(fract(facet) - 0.5);
		colour = mix(vec3(0.065, 0.07, 0.055), vec3(0.14, 0.14, 0.11), smoothstep(0.5, 0.25, cell) * 0.6);
		colour = mix(colour, vec3(0.22, 0.2, 0.15), smoothstep(0.55, 0.85, -e.x) * 0.6);
		glint = 1.0;
		sheen = 0.35;
	} else if (which == 3) {
		// The jaws: dark chitin, black at the teeth.
		colour = mix(vec3(0.16, 0.12, 0.08), vec3(0.03, 0.025, 0.02), smoothstep(0.24, 0.252, rest.z));
		glint = 0.7;
	} else if (which == 4) {
		colour = vec3(0.07, 0.06, 0.05);
	} else if (which >= 6) {
		colour = vec3(0.09, 0.075, 0.06);
		glint = 0.4;
	} else if (which == 5) {
		// The abdomen: each segment darker at its joints, a paler ring at its
		// front, a pale line down its back; a dull bronze sheen.
		float seg = (ABDOMEN_ROOT - rest.z) / ABDOMEN_LENGTH * 10.0;
		float f = fract(seg);
		colour = vec3(0.15, 0.12, 0.09);
		colour = mix(colour, vec3(0.3, 0.27, 0.21), smoothstep(0.02, 0.06, f) * smoothstep(0.18, 0.12, f) * 0.8);
		colour = mix(colour, vec3(0.04, 0.035, 0.03), smoothstep(0.86, 0.97, f));
		float back = smoothstep(0.5, 0.95, normalize(vec2(rest.x, rest.y - 0.008 + 0.018 * pow(seg / 10.0, 2.0))).y);
		colour = mix(colour, vec3(0.27, 0.24, 0.18), back * 0.45 * step(seg, 9.3));
		sheen = 0.6;
		glint = 0.3;
	} else {
		// The thorax and face: bronze-brown, the thorax's flanks striped dark (two oblique bands).
		colour = which == 1 ? vec3(0.22, 0.19, 0.14) : vec3(0.17, 0.14, 0.1);
		if (which == 0) {
			float slant = rest.z * 0.75 + rest.y * 0.9;
			float stripe = line(fract(slant * 22.0) - 0.5, 0.14) * smoothstep(0.012, 0.024, abs(rest.x));
			colour = mix(colour, vec3(0.05, 0.045, 0.035), stripe * 0.85);
			colour = mix(colour, vec3(0.28, 0.25, 0.19), smoothstep(0.03, 0.05, rest.y) * 0.4);
		}
		colour *= 0.9 + 0.2 * noise(rest.xz * 300.0 + rest.y * 200.0);
		sheen = 0.4;
	}
	colour *= shade;
	ALBEDO = colour;
	ALPHA = wing_alpha;
	SPECULAR = 0.0;
	// What light() needs, passed in what it can read: ROUGHNESS says how it
	// shines (below 0.5 a glint, the lower the sharper; between 0.6 and 0.9 a
	// wing that light comes through) and BACKLIGHT the colour of that light.
	ROUGHNESS = glint > 0.0 ? 0.45 - 0.2 * glint : (lit_through > 0.0 ? 0.8 : 0.95);
	BACKLIGHT = colour * lit_through;
	if (sheen > 0.0) {
		// A dull sheen: the sky caught along the top, a little brighter at grazing angles.
		float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		vec3 mirrored = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
		EMISSION = sheen * (vec3(0.42, 0.36, 0.26) * colour * 1.5 * smoothstep(0.35, 0.85, graze) + vec3(0.5, 0.53, 0.56) * 0.09 * smoothstep(0.4, 0.6, mirrored.y));
	}
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
	float lit = cut(facing * smoothstep(0.1, 0.5, reach), 0.04);
	float strength_ = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength_ * LIGHT_COLOR / PI;
	if (ROUGHNESS > 0.9) {
		float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		SPECULAR_LIGHT += cut(graze, 0.78) * mix(lit, 1.0, 0.3) * rim_gain * ALBEDO * strength_ * LIGHT_COLOR / PI;
	} else if (ROUGHNESS > 0.6) {
		// Light from behind comes through a wing.
		float behind = smoothstep(0.0, 0.6, -dot(NORMAL, LIGHT));
		SPECULAR_LIGHT += behind * BACKLIGHT * strength_ * LIGHT_COLOR / PI;
	} else {
		// A glint: one small bright light on the eye or the chitin.
		float sharp = mix(260.0, 60.0, ROUGHNESS / 0.45);
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), sharp), 0.5);
		SPECULAR_LIGHT += shine * 0.3 * strength_ * LIGHT_COLOR;
	}
}
