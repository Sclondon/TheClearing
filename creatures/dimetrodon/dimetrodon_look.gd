class_name DimetrodonLook
## What the dimetrodon (Dimetrodon, creatures/dimetrodon/dimetrodon.gd)
## is drawn with: two materials, one for each of the model's two surfaces, so
## that it is two draws. Lit in hard bands, as the other creatures are.
##
## - SKIN: a hide of fine pebbly scales, and the skin of its sail, (drawn from the first texture
##   coordinates, metres along it and round it), dusky grey-brown, each scale a little
##   different, darker in the gaps between them. The model's vertex colours say
##   where it is creased (red: dark), where it is banded darker (green) and
##   where it is paler (blue: underneath).
## - PARTS: eyes, teeth, claws, the spines of its sail and the mouth, each in its own
##   colour from the vertex colours, wet ones with a hard glint.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in
## a web build as on a desktop.

const SKIN_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.30, 0.29, 0.26);
uniform vec3 belly : source_color = vec3(0.47, 0.45, 0.40);
uniform vec3 band : source_color = vec3(0.17, 0.165, 0.15);
uniform float band_gain = 0.55;
uniform float crease = 0.6;
// The scales: how many to a metre, how dark the gaps, how much they differ in tone.
uniform float scales = 13.0;
uniform float gap = 0.32;
uniform float scale_tone = 0.16;
uniform float patch = 0.12;
// The banded light.
uniform float wrap = 0.25;
uniform float flatness = 0.65;
uniform float rim_gain = 0.3;
uniform float rim_width = 0.28;

varying float pebble;

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Scales: the nearest two cells of a jittered grid; near the line between
	// them is a gap. (Fades out where the scales are smaller than a pixel.)
	vec2 at = UV * scales;
	vec2 cell = floor(at);
	vec2 f = fract(at);
	float near = 8.0;
	float next = 8.0;
	vec2 which = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 p = o + 0.15 + 0.7 * hash2(cell + o) - f;
			float d = dot(p, p);
			if (d < near) {
				next = near;
				near = d;
				which = cell + o;
			} else if (d < next) {
				next = d;
			}
		}
	}
	float edge = sqrt(next) - sqrt(near);
	float fine = clamp(1.0 - fwidth(at.x) * 1.2, 0.0, 1.0);
	float groove = (1.0 - smoothstep(0.03, 0.2, edge)) * fine;
	// (each scale a low dome: paler on its crown, darker round its edge)
	float crown = 1.0 - smoothstep(0.05, 0.6, sqrt(near));
	pebble = (hash(which) - 0.5) * fine;
	vec3 base = mix(albedo, belly, clamp(COLOR.b, 0.0, 1.0));
	base = mix(base, band, clamp(COLOR.g, 0.0, 1.0) * band_gain);
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base *= 1.0 + pebble * scale_tone + (noise(UV * 1.3) - 0.5) * patch * 2.0;
	base *= mix(1.0, mix(0.84, 1.08, crown), fine);
	base *= 1.0 - groove * gap;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach) + pebble * 0.05, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.2;
uniform vec3 shine : source_color = vec3(0.8, 0.6, 0.3);

varying float wet;

void vertex() {
	wet = COLOR.a;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (wet > 0.97) {
		// An eye: where on its front this is (the second texture coordinates), 0 at
		// the middle of the pupil, 1 at its rim. A reptile's: a golden-brown iris
		// round a dark round pupil.
		float r = length(UV2 - vec2(0.5)) / 0.4;
		float pixel = max(fwidth(r), 0.002);
		float pupil = 1.0 - smoothstep(0.42 - pixel, 0.42 + pixel, r);
		float rim = smoothstep(0.78 - pixel, 0.88 + pixel, r);
		vec3 iris = COLOR.rgb * mix(1.2, 0.6, smoothstep(0.4, 0.85, r));
		ALBEDO = mix(mix(iris, vec3(0.02, 0.018, 0.015), pupil), vec3(0.05, 0.045, 0.04), rim);
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = shine * eyeshine * (0.25 + 0.75 * facing * facing) * (1.0 - rim) * mix(0.6, 0.3, pupil);
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// A wet surface (an eye, the mouth) has one small hard glint on it.
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 120.0, wet)), 0.6) * wet * lit;
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.8;
}
"""

static var _skin_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (skin, parts), and says which is which. `skin_tint` multiplies the hide's
## colours; `scales` is how many scales to a metre of it. Pass what an earlier
## call made as `shared` to use the same materials (for its low model).
static func dress(model: Node, skin_tint := Color.WHITE, scales := 36.0, eyeshine := 0.3, shared := {}) -> Dictionary:
	if _skin_shader == null:
		_skin_shader = _shader(SKIN_SHADER)
		_parts_shader = _shader(PARTS_SHADER)
	var made := shared.duplicate()
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var label := String(original.resource_name)
			if not made.has(label):
				var material := ShaderMaterial.new()
				if label == "skin":
					material.shader = _skin_shader
					var colour := original.albedo_color * skin_tint
					material.set_shader_parameter(&"albedo", colour)
					material.set_shader_parameter(&"belly", colour.lerp(Color(0.58, 0.54, 0.47), 0.45))
					material.set_shader_parameter(&"band", colour.darkened(0.5))
					material.set_shader_parameter(&"band_gain", 0.6)
					material.set_shader_parameter(&"scales", scales)
					material.set_shader_parameter(&"gap", 0.24)
				else:
					material.shader = _parts_shader
					material.set_shader_parameter(&"eyeshine", eyeshine)
				made[label] = material
			part.set_surface_override_material(surface, made[label])
	return made


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
