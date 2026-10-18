// A flying insect (InsectLook makes the mesh), drawn many at once by one
// MultiMesh (InsectSwarm): a moth, a blowfly or a dragonfly, by `kind`.
//
// What each point is, in its texture coordinates (not colours: the web's
// renderer gives a MultiMesh without colours of its own no settled colour to
// its points, and colours are turned from sRGB on their way here):
//   UV2.x  the part: 0 body, 1 fuzz (hair, bristles), 2 abdomen, 3 eye,
//          4 antenna, 5 leg, 6 forewing, 7 hindwing, 8 a luna moth's tail
//   UV     on a wing, where it lies on it (out from the middle, along the
//          body) as the model has it at rest; elsewhere (along the body, up)
// Each insect, in its custom data:
//   x  how far through a wingbeat it is (0..1, round and round)
//   y  how hard it is flying (0: at rest, wings held as it rests; 1: full beats)
//   z  which of its kind it is (a moth: 0 a dusty grey-brown moth, 1 a luna
//      moth, 2 a death's-head hawkmoth; the others: 0)
//   w  its own shade (0..1), so that no two are quite alike
//
// THE WINGS are each turned rigidly about its hinge (where it meets the
// thorax): raised and lowered about the line of the body (the beat), and swept
// forward and back. At rest a moth's lie spread flat (pressed to the wall it
// rests on), a fly's are swept back over its abdomen, a dragonfly's held out
// flat and drooping a little. Beating, a moth's go through a deep clap, a
// dragonfly's fore and hind wings beat out of step (a quarter of a beat), and a
// fly's are a blur: the faster they beat, the less there is of them to see
// (`blur`), drawn as a stipple of the wing.
//
// Lit as The Clearing lights its figures: two flat tones with a hard edge
// between them. Hair catches a rim of light; a fly's abdomen and a
// dragonfly's have a metal sheen that shifts with the angle (an oil film's
// colours), and their eyes a glint; a clear wing is veined (a dragonfly's in a
// fine net, with a dark spot near the tip) and light comes through it.

shader_type spatial;
render_mode cull_disabled;

// 0 moth, 1 fly, 2 dragonfly.
uniform int kind = 0;
// Where the wings are hinged (the right side), forewing and hindwing.
uniform vec3 hinge_fore = vec3(0.045, 0.035, 0.06);
uniform vec3 hinge_hind = vec3(0.045, 0.028, 0.0);
// At rest: how far the wings are raised and swept back.
uniform float rest_lift = 0.0;
uniform float rest_sweep = 0.0;
// Beating: how far up and down the stroke goes, about what middle, how far it
// sweeps back and forth, how far behind the forewings the hindwings beat (a
// share of a beat), and how much of a clear wing is lost to the blur.
uniform float beat_lift = 1.0;
uniform float beat_middle = 0.25;
uniform float beat_sweep = 0.15;
uniform float hind_lag = 0.05;
uniform float blur = 0.0;
// How much of a clear wing's skin is seen (its veins are seen whole).
uniform float clear = 1.0;
uniform float wrap = 0.25;
uniform float flatness = 0.6;
uniform float rim_gain = 0.45;

varying float part;
varying vec2 at_rest;
varying float variety;
varying float tone;
varying float strength;

vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	part = UV2.x;
	at_rest = UV;
	variety = INSTANCE_CUSTOM.z;
	tone = INSTANCE_CUSTOM.w;
	strength = INSTANCE_CUSTOM.y;
	int which = int(part + 0.5);
	if (which == 8 && abs(variety - 1.0) > 0.5) {
		// (only a luna moth has tails)
		VERTEX = vec3(0.0);
	} else if (which >= 6) {
		bool hind = which >= 7;
		vec3 hinge = hind ? hinge_hind : hinge_fore;
		float side = VERTEX.x < 0.0 ? -1.0 : 1.0;
		vec3 v = VERTEX;
		vec3 n = NORMAL;
		v.x *= side;
		n.x *= side;
		float a = 6.2831853 * (INSTANCE_CUSTOM.x - (hind ? hind_lag : 0.0));
		float lift = mix(rest_lift, beat_middle + beat_lift * sin(a), strength);
		float sweep = mix(rest_sweep, beat_sweep * cos(a), strength);
		// Swept back about the upright through the hinge, then raised about the line of the body.
		vec2 swept = turn(v.xz - hinge.xz, -sweep);
		v.xz = hinge.xz + swept;
		n.xz = turn(n.xz, -sweep);
		vec2 up = turn(v.xy - hinge.xy, lift);
		v.xy = hinge.xy + up;
		n.xy = turn(n.xy, lift);
		v.x *= side;
		n.x *= side;
		VERTEX = v;
		NORMAL = n;
	}
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

// The colours of a film of oil, round and round.
vec3 film(float t) {
	return 0.5 + 0.5 * cos(6.2831853 * (vec3(t) + vec3(0.0, 0.33, 0.67)));
}

// Ordered stipple: is this pixel one of the `amount` (0..1) that are drawn?
bool stippled(vec2 pixel, float amount) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = x + y * 4;
	float order[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (order[index] + 0.5) / 16.0 < amount;
}

// A moth's wings: `uv` where on the wing (out, along), `hind` which.
vec3 moth_wing(vec2 uv, bool hind, int v, float shade) {
	vec2 from = uv - (hind ? hinge_hind.xz : hinge_fore.xz);
	float out_ = length(from);
	float mottle = noise(uv * 38.0 + shade * 17.0) * 0.6 + noise(uv * 90.0) * 0.4;
	vec3 colour;
	if (v == 1) {
		// A luna moth: pale green, a maroon stripe down the leading edge of the
		// forewing, an eyespot on every wing, the hindwings' tails yellowing.
		colour = vec3(0.6, 0.76, 0.5) * (0.92 + 0.12 * mottle);
		vec2 spot = hind ? vec2(0.2, -0.17) : vec2(0.22, 0.035);
		float d = length(uv - spot);
		colour = mix(colour, vec3(0.62, 0.55, 0.22), 1.0 - smoothstep(0.022, 0.026, d));
		colour = mix(colour, vec3(0.32, 0.12, 0.1), line(d - 0.019, 0.004));
		colour = mix(colour, vec3(0.75, 0.8, 0.7), 1.0 - smoothstep(0.008, 0.011, d));
		if (!hind) {
			float edge = 0.115 - 0.32 * pow(max(uv.x - 0.05, 0.0), 2.0) * 1.4;
			colour = mix(colour, vec3(0.38, 0.2, 0.2), smoothstep(edge - 0.01, edge, uv.y) * step(uv.x, 0.42));
		}
		colour = mix(colour, vec3(0.7, 0.68, 0.35), smoothstep(-0.32, -0.45, uv.y));
	} else if (v == 2) {
		// A death's-head hawkmoth: dark mottled forewings with a pale bar,
		// yellow hindwings banded black.
		if (hind) {
			colour = vec3(0.78, 0.6, 0.18) * (0.92 + 0.12 * mottle);
			colour = mix(colour, vec3(0.08, 0.06, 0.05), line(out_ - 0.16, 0.02) + line(out_ - 0.27, 0.025));
		} else {
			colour = mix(vec3(0.12, 0.09, 0.07), vec3(0.34, 0.27, 0.2), mottle);
			colour = mix(colour, vec3(0.55, 0.48, 0.36), line(out_ - 0.24 - 0.015 * sin(uv.y * 50.0), 0.012));
			colour = mix(colour, vec3(0.62, 0.58, 0.5), 1.0 - smoothstep(0.012, 0.016, length(uv - vec2(0.22, 0.04))));
		}
	} else {
		// An ordinary moth, dusty grey-brown: wavy dark cross-lines, a dark
		// spot in the middle of the forewing, the hindwing paler and plain.
		vec3 base = mix(vec3(0.5, 0.45, 0.38), vec3(0.68, 0.64, 0.57), shade);
		colour = base * (0.85 + 0.25 * mottle);
		if (hind) {
			colour = mix(colour, base * 1.12, 0.6);
			colour = mix(colour, base * 0.8, line(out_ - 0.25, 0.006));
		} else {
			float wave = 0.01 * sin(uv.y * 60.0 + shade * 5.0);
			colour = mix(colour, base * 0.55, line(out_ - 0.19 - wave, 0.006) + line(out_ - 0.33 - wave, 0.007));
			colour = mix(colour, base * 0.45, 1.0 - smoothstep(0.012, 0.016, length(uv - vec2(0.24, 0.0))));
			colour = mix(colour, base * 1.2, smoothstep(0.4, 0.47, out_) * 0.5);
		}
	}
	return colour;
}

// A clear wing's veins (1 on a vein): a fly's few long ones fanning out from
// the hinge and a cross-vein or two; a dragonfly's many, in a fine net.
float veins(vec2 uv, bool hind) {
	vec2 from = uv - (hind ? hinge_hind.xz : hinge_fore.xz);
	float out_ = length(from);
	float round_ = atan(from.y, from.x);
	if (kind == 1) {
		float along = line(fract(round_ * 3.2 + 0.5) - 0.5, 0.035) * step(0.03, out_);
		float leading = line(from.y - 0.04 + 0.12 * out_ * out_, 0.006);
		float cross_ = line(out_ - 0.22, 0.004) * step(-0.05, from.y) * step(from.y, 0.03);
		return clamp(along + leading + cross_, 0.0, 1.0);
	}
	float long_ = line(fract(from.y * 70.0 + out_ * 4.0) - 0.5, 0.06);
	float cross_ = line(fract(from.x * 85.0) - 0.5, 0.05);
	float leading = line(from.y - (hind ? 0.012 : 0.012) + 0.02 * out_, 0.003);
	return clamp(long_ * 0.45 + cross_ * 0.35 + leading, 0.0, 1.0);
}

void fragment() {
	int which = int(part + 0.5);
	int v = int(variety + 0.5);
	vec3 colour = vec3(0.3);
	float sheen = 0.0;
	float glint = 0.0;
	float hair = 0.0;
	float lit_through = 0.0;
	bool wing = which >= 6;
	if (wing) {
		bool hind = which == 7;
		vec2 uv = at_rest;
		if (kind == 0) {
			colour = moth_wing(uv, hind || which == 8, v, tone);
			hair = 0.4;
			lit_through = 0.25;
			// (beating hard, a little of the wing is lost to the blur)
			if (!stippled(FRAGCOORD.xy, 1.0 - 0.35 * blur * strength)) {
				discard;
			}
		} else {
			float vein = veins(uv, hind);
			float spot = 0.0;
			if (kind == 2) {
				// The pterostigma: a dark spot on the leading edge near the tip.
				float tip_at = hind ? 0.43 : 0.44;
				spot = step(tip_at, uv.x) * step(uv.x, tip_at + 0.03) * step((hind ? hinge_hind.z : hinge_fore.z) + 0.004, uv.y);
			}
			vec3 skin = kind == 1 ? vec3(0.62, 0.62, 0.6) : vec3(0.84, 0.86, 0.84);
			vec3 rib = kind == 1 ? vec3(0.12, 0.1, 0.08) : vec3(0.3, 0.29, 0.24);
			colour = mix(skin, rib, max(vein, spot));
			float seen = mix(clear, 1.0, max(vein, spot) * 0.85);
			seen *= 1.0 - blur * strength;
			if (!stippled(FRAGCOORD.xy, seen)) {
				discard;
			}
			sheen = 0.25;
			lit_through = 0.6;
		}
	} else if (which == 3) {
		// The eyes: a moth's dark, a fly's red-brown, a dragonfly's blue-green; wet, with a glint.
		colour = kind == 0 ? vec3(0.06, 0.05, 0.04) : (kind == 1 ? vec3(0.5, 0.07, 0.04) : vec3(0.12, 0.42, 0.42));
		glint = 1.0;
		sheen = kind == 2 ? 0.5 : 0.0;
	} else if (which == 4 || which == 5) {
		colour = kind == 0 ? (v == 2 ? vec3(0.15, 0.11, 0.08) : vec3(0.42, 0.37, 0.3)) : vec3(0.06, 0.055, 0.05);
		if (kind == 0 && v == 1) {
			colour = vec3(0.55, 0.5, 0.3);
		}
	} else {
		bool hairy = which == 1;
		if (kind == 0) {
			vec3 base = v == 1 ? vec3(0.84, 0.85, 0.78) : (v == 2 ? vec3(0.2, 0.15, 0.11) : mix(vec3(0.5, 0.45, 0.38), vec3(0.66, 0.62, 0.55), tone));
			colour = base * (hairy ? 1.12 : 1.0);
			if (v == 2) {
				// The death's-head: a pale skull on the thorax, and a yellow
				// abdomen banded black.
				float along = at_rest.x;
				if (along < 0.0) {
					colour = mix(vec3(0.75, 0.58, 0.16), vec3(0.08, 0.06, 0.05), step(0.5, fract(along * 16.0)));
				} else if (along < 0.1 && at_rest.y > 0.03) {
					colour = mix(colour, vec3(0.7, 0.62, 0.42), 1.0 - smoothstep(0.022, 0.03, length(vec2(along - 0.065, 0.0))));
				}
			}
			hair = 1.0;
		} else if (kind == 1) {
			// A blowfly: a dark grey thorax with bristles, a metallic blue-green abdomen.
			colour = which == 2 ? vec3(0.05, 0.13, 0.15) : vec3(0.12, 0.12, 0.13);
			sheen = which == 2 ? 1.0 : 0.2;
			glint = which == 2 ? 0.6 : 0.0;
			hair = hairy ? 0.6 : 0.2;
		} else {
			// A dragonfly: a green-brown thorax striped dark, an iridescent blue
			// abdomen banded black at its joints.
			if (which == 2) {
				float joints = fract((0.15 - at_rest.x) / 0.065);
				colour = mix(vec3(0.07, 0.28, 0.5), vec3(0.02, 0.03, 0.04), step(0.82, joints));
				sheen = 1.0;
				glint = 0.5;
			} else {
				float stripe = step(0.5, fract(at_rest.x * 40.0 + at_rest.y * 25.0));
				colour = mix(vec3(0.2, 0.32, 0.14), vec3(0.06, 0.07, 0.04), stripe * 0.8);
				sheen = 0.3;
			}
		}
	}
	colour *= 0.94 + 0.12 * tone;
	// (a moth's pale dust catches what light there is: it is seen in the dusk)
	if (kind == 0 && which != 3) {
		EMISSION = colour * 0.1;
	}
	ALBEDO = colour;
	SPECULAR = 0.0;
	// What light() needs, passed in what it can read: ROUGHNESS says how it
	// shines (1 hair, with a rim; below 0.5 a glint, the lower the sharper), and
	// BACKLIGHT the colour of the rim or of the light coming through a wing.
	ROUGHNESS = glint > 0.0 ? 0.45 - 0.2 * glint : (hair > 0.0 ? 1.0 : 0.8);
	BACKLIGHT = hair > 0.0 ? colour * (0.6 + 0.7 * hair) : colour * lit_through;
	// The metal sheen: the colours of a film round the edges, the sky in a band along the top.
	if (sheen > 0.0) {
		float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		vec3 mirrored = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
		vec3 oil = film(graze * 1.1 + tone * 0.3 + (kind == 2 ? 0.55 : 0.4));
		EMISSION = sheen * (oil * colour * 1.6 * smoothstep(0.3, 0.8, graze) + vec3(0.5, 0.53, 0.56) * 0.18 * smoothstep(0.45, 0.6, mirrored.y));
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
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (ROUGHNESS > 0.9) {
		// Hair catches the light along its edges.
		float rim = cut(graze, 0.72) * mix(lit, 1.0, 0.4);
		SPECULAR_LIGHT += rim * rim_gain * BACKLIGHT * strength_ * LIGHT_COLOR / PI;
	} else if (ROUGHNESS > 0.6) {
		// Light from behind comes through a wing.
		float behind = smoothstep(0.0, 0.6, -dot(NORMAL, LIGHT));
		SPECULAR_LIGHT += behind * BACKLIGHT * strength_ * LIGHT_COLOR / PI;
	} else {
		// A glint: one small bright light on the eye or the shell.
		float sharp = mix(140.0, 40.0, ROUGHNESS / 0.45);
		float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), sharp), 0.5);
		SPECULAR_LIGHT += shine * 0.9 * strength_ * LIGHT_COLOR;
	}
}
