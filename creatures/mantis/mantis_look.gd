class_name MantisLook
## What the giant mantis (GiantMantis, creatures/mantis/mantis.gd) is drawn
## with: one material for the whole model (`models/mantis.glb`, or the demade
## `mantis_lo.glb`), so that it is one draw.
##
## Pale grey-green, the colour of a dead leaf's underside in the mist, lit in
## hard bands (cel shading) with a soft pale rim; faint lengthwise streaks and
## mottling so that it is not one flat colour, and lies among leaves as one.
## The model's vertex colours give each part its colour; their alpha says what
## it is:
## - 1, hard body: as above.
## - 0.5, an eye: paler and glassy, with its false pupil: the small dark spot a
##   compound eye shows where its facets look straight at you, so that, from
##   wherever you look at it, it seems to be looking back (the dot moves round
##   the eye as you move round it, as a real mantis's does).
## - 0, a wing: the veins drawn from its UV (u across the wing, v along it): a
##   net of fine darker lines, the forewings leathery and the hindwings smoky.
##
## Nothing uses a texture, transparency or the screen.

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
// How much of the model's colour is kept (the rest grey: Inside's near-colourless light), and how light it is.
uniform float saturation = 0.5;
uniform float lightness = 0.95;
// The banded light.
uniform float wrap = 0.3;
uniform float shade_floor = 0.42;
uniform vec3 rim_colour : source_color = vec3(0.78, 0.8, 0.76);
uniform float rim_gain = 0.12;
// The false pupil: how big the dark spot is, and how dark.
uniform float pupil = 0.982;
uniform float pupil_dark = 0.8;
// Wing veins: how many across and along, how dark.
uniform vec2 veins = vec2(9.0, 26.0);
uniform float vein_dark = 0.35;

varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

float line_of(float value, float width) {
	float f = abs(fract(value) - 0.5) * 2.0;
	float pixel = max(fwidth(value) * 2.0, 0.0005);
	return 1.0 - smoothstep(1.0 - width - pixel, 1.0 - width + pixel, 1.0 - f);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float grey = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	vec3 colour = mix(vec3(grey), COLOR.rgb, saturation) * lightness * tint;
	float kind = COLOR.a;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (kind < 0.25) {
		// A wing: a net of veins, long ones along it and cross veins between
		float along = line_of(UV.x * veins.x, 0.12);
		float across = line_of(UV.y * veins.y + sin(UV.x * 17.0) * 0.3, 0.08);
		colour *= 1.0 - vein_dark * max(along, across * 0.7);
	} else if (kind < 0.75) {
		// An eye: the false pupil, where its facets look straight back
		float spot = smoothstep(pupil - 0.01, pupil + 0.01, facing);
		colour = mix(colour, vec3(0.03, 0.035, 0.03), spot * pupil_dark);
	} else {
		// Hard body: a faint mottling, as of a dead leaf
		float mottle = sin(local_point.x * 13.0 + local_point.y * 17.0) * sin(local_point.z * 11.0 - local_point.y * 7.0);
		colour *= 0.95 + 0.06 * mottle;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = smoothstep(0.62, 0.8, 1.0 - facing);
	EMISSION = rim_colour * rim * rim_gain * (kind > 0.75 ? 1.0 : 0.5);
}

void light() {
	float near = clamp(ATTENUATION, 0.0, 1.0);
	float amount = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap) * smoothstep(0.1, 0.5, near);
	float pixel = max(fwidth(amount), 0.001);
	float lit = smoothstep(0.08 - pixel, 0.08 + pixel, amount);
	float strength = mix(near, 1.0, 0.5);
	DIFFUSE_LIGHT += mix(shade_floor, 1.0, lit) * strength * LIGHT_COLOR / PI;
}
"""

const MODEL := "res://creatures/mantis/models/mantis.glb"
const MODEL_LO := "res://creatures/mantis/models/mantis_lo.glb"

static var _shader: Shader
static var _material: ShaderMaterial


## The material (shared; its colours are uniforms).
static func material() -> ShaderMaterial:
	if _material == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = _shader
	return _material


## The model (`low`: the demade one), with its skeleton, in the material.
static func model(low := false) -> Node3D:
	var scene := load(MODEL_LO if low else MODEL) as PackedScene
	if scene == null:
		push_error("MantisLook: no model (build it with creatures/mantis/tools/build_mantis.py)")
		return Node3D.new()
	var made := scene.instantiate() as Node3D
	for found: Node in made.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		mesh.material_override = material()
		# (it is pale and among plants: its shadow is a soft smudge the walls' shadows hide anyway)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return made
