class_name BaboonLook
## How a Baboon (creatures/baboon/baboon.gd) is shaded: one material for every
## baboon, put over its model (creatures/baboon/models/, built in Blender by
## tools/build_baboon.py).
##
## The models carry their colours as vertex colours: the coat dark on the back
## and paler under the belly and inside the limbs, the pale rump (and the
## mandrill's patch), the paler mane, dark hands and feet. Their first UV says
## how much a point glows (x: 1 for the ember eyes) and how much it is fur (y:
## fur is faintly streaked and has a paler backlit fringe; skin and teeth are
## plain); x is 2 on the mandrill's snout, whose colours are cut here instead:
## from its second UV, where on the snout each point is (along it, round it), a
## crimson ridge and nose with a wet shine, slate-blue ribbed cheeks with dark
## grooves, black skin between, all with sharp edges. Elsewhere the second UV is
## where the point was on the standing body, so the streaks stay put on it.
##
## Shading is cel shading in two tones with a one-pixel edge and a rim of
## light at grazing angles, so it sits with a cel-shaded cast without needing
## their scripts. Shadows only dim it, so that the coat (above all under the
## mane) does not break up into patches.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.55;
uniform float flatness = 0.65;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.22;
// Each baboon's own coat, a little lighter or darker.
instance uniform float tone = 1.0;

varying float glow;
varying float furry;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	glow = UV.x;
	furry = UV.y;
}

// The mandrill's face, cut sharp here from where on the muzzle a point is
// (UV2: x how far along it, y how far round from the side towards the top;
// see BaboonLook.MUZZLE): the crimson ridge and nose, the ribbed blue cheeks
// with dark grooves, the black skin between.
uniform vec3 crimson : source_color = vec3(0.42, 0.04, 0.06);
uniform vec3 wet : source_color = vec3(0.66, 0.3, 0.3);
uniform vec3 slate : source_color = vec3(0.21, 0.31, 0.46);
uniform vec3 groove : source_color = vec3(0.07, 0.08, 0.12);
uniform vec3 skin : source_color = vec3(0.07, 0.06, 0.06);

float inside(float value, float from, float to) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(from - pixel, from + pixel, value) * (1.0 - smoothstep(to - pixel, to + pixel, value));
}

vec3 face(vec2 at) {
	float t = at.x;
	float phi = at.y;
	vec3 c = skin;
	// The cheek pads, and their ribs: ridges blue, grooves dark.
	float pad = inside(phi, -0.33, 0.93) * inside(t, 0.05, 0.8);
	float rib = fract((phi + 0.35) / 1.3 * 5.0);
	float ribbed = inside(rib, 0.14, 0.86);
	c = mix(c, mix(groove, slate, ribbed), pad);
	// The ridge down the nose, narrow, and the broad nose pad at the end.
	float ridge = inside(abs(phi - 1.5708), -1.0, mix(0.2, 0.26, t)) * step(0.02, t);
	float nose = inside(t, 0.84, 2.0) * inside(phi, -0.5, 2.0);
	c = mix(c, crimson, max(ridge, nose));
	// A wet shine on the top of the nose.
	c = mix(c, wet, inside(t, 0.91, 0.955) * inside(phi, 1.25, 2.0));
	return c;
}

void fragment() {
	// Fine streaks in the fur, running along the body.
	float streak = noise(UV2 * vec2(70.0, 10.0));
	float shade = 1.0 + (streak - 0.5) * 0.22 * furry;
	vec3 colour = COLOR.rgb;
	ALBEDO = colour * shade * mix(1.0, tone, furry);
	if (glow > 1.5) {
		ALBEDO = face(UV2);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = colour * clamp(glow, 0.0, 1.0) * step(glow, 1.5) * 1.3;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	// Shadows (its own above all: the mane on its back) only dim it, so that
	// the coat does not break up into patches; the turn away from the light cuts.
	float lit = cut(facing, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	// (and a little falling off across the lit side, so round forms read as round)
	lit *= mix(0.72, 1.0, smoothstep(0.1, 0.85, facing));
	// (flat within a sun's light; a lamp's fades with distance as it should)
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	// The rim is a brighter shade of the surface itself (never paler than it: a
	// pale rim on a mane whose clumps all face sideways turns it to glass).
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * (1.0 - 0.5 * furry) * strength * LIGHT_COLOR / PI;
}
"""

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


