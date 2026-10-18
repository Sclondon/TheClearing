class_name MammothLook
## What a woolly mammoth (Mammoth, creatures/mammoth/mammoth.gd) is drawn with:
## three materials, one for each of the model's three surfaces, so that one is a
## handful of draws.
##
## - COAT: the dense under-wool on its body, trunk, ears and tail: lit in hard
##   bands like the figures, streaked and clumped, with a shell or two that
##   stand it off the skin towards the outline. The model's vertex colours say
##   where it is creased (red) and where it is dark (green: low down, the legs).
## - HAIR: the long coarse guard hair hanging over it, as cards (strips from a
##   root to a ragged end: their texture coordinates x root 0 to end 1, y
##   across). The shader makes each card a few coarse strands, ragged at the end
##   (discarded, not blended), and sways it: in the air (`wind`), with the pace
##   (`sway`, set by the rig) and lagging behind as the body moves (`drag`, in
##   the model's space, set by the rig). Paler, bleached, at the ends.
## - PARTS: the tusks (ivory, stained at the root), eyes, the nails, the mouth:
##   each its own colour from the vertex colours, wet ones (alpha) with a hard glint.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in a
## web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.29, 0.24, 0.2);
uniform vec3 dark : source_color = vec3(0.15, 0.12, 0.1);
uniform float wrap = 0.3;
uniform float flatness = 0.62;
uniform vec2 clumps = vec2(9.0, 7.0);
uniform float clump_tone = 0.22;
uniform float strands = 60.0;
uniform float streak = 0.16;
uniform float crease = 0.55;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.35;
// Which layer this is: 0 the skin, up to 1 for the tips of the wool.
uniform float shell = 0.0;
uniform float fur_length = 0.05;
uniform float droop = 0.6;

varying float strand;

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

void vertex() {
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		VERTEX += (NORMAL + down * droop * shell) * fur_length * mix(0.4, 1.0, COLOR.r) * shell;
	}
}

void fragment() {
	vec2 at = vec2(UV.x * clumps.x, UV.y * clumps.y);
	float clump = noise(at) * 0.7 + noise(at * 2.7 + 3.0) * 0.3;
	float fine = noise(vec2(UV.y * strands, UV.x * strands * 0.2));
	strand = mix(clump, fine, 0.35);
	if (shell > 0.0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		vec2 tuft = vec2(UV.y * 24.0, UV.x * 14.0);
		float height = hash(floor(tuft)) * 0.6 + clump * 0.4;
		if (facing > 0.85 - shell * 0.25 + (clump - 0.5) * 0.3 || height < shell * 0.75) {
			discard;
		}
	}
	vec3 base = mix(albedo, dark, clamp(COLOR.g, 0.0, 1.0));
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base *= 1.0 + (clump - 0.5) * clump_tone + (fine - 0.5) * streak;
	base *= mix(0.88, 1.08, shell);
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
	float lit = cut(facing * smoothstep(0.15, 0.6, reach) + (strand - 0.5) * 0.08, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (strand - 0.5) * 0.3) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

const HAIR_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 albedo : source_color = vec3(0.24, 0.19, 0.15);
uniform vec3 dark : source_color = vec3(0.12, 0.095, 0.08);
uniform vec3 tips : source_color = vec3(0.36, 0.29, 0.22);
uniform float wrap = 0.35;
uniform float flatness = 0.62;
// How far the hair swings (m at the ends): in the air always, more with the pace (`sway`, set by the rig).
uniform float wind = 0.035;
uniform float sway = 0.0;
// How far the ends lag behind the body's movement (m, in the model's space; set by the rig).
uniform vec3 drag = vec3(0.0);
uniform float time_offset = 0.0;
// How many coarse strands a card is.
uniform float strands = 4.0;

varying float tip;
varying float own;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	tip = UV.x;
	own = COLOR.a;
	float bend = tip * tip;
	float t = TIME * 1.7 + own * 23.0 + time_offset;
	vec3 swing = vec3(sin(t) * 0.7 + sin(t * 2.3 + 1.0) * 0.3, 0.0, cos(t * 0.8) * 0.6);
	VERTEX += swing * bend * (wind + sway) + drag * bend;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	// A few coarse strands, each ending at its own length: the end of the lock ragged
	float across = UV.y * strands + own * 7.0;
	float which = floor(across);
	float within = fract(across);
	float length = 0.72 + 0.28 * hash(which + own * 31.0);
	float thin = mix(0.4, 0.26, smoothstep(0.2, 1.0, tip / length)) + 0.06 * (1.0 - smoothstep(0.0, 0.12, tip));
	if (tip > length || abs(within - 0.5) > thin) {
		discard;
	}
	vec3 base = mix(albedo, dark, clamp(COLOR.g, 0.0, 1.0)) * (0.85 + 0.3 * hash(which + own * 13.0));
	base = mix(base, tips, smoothstep(0.35, 1.0, tip) * 0.6);
	// (darker in among the hair, near the roots)
	base *= mix(0.65, 1.0, smoothstep(0.0, 0.4, tip));
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	// (the hair is thin: light comes through it, so its shaded side is never black)
	float lit = mix(0.4, 1.0, cut(facing * smoothstep(0.15, 0.6, reach), 0.05));
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;

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
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(6.0, 120.0, wet)), 0.6) * wet * max(lit, 0.35);
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.7;
}
"""

static var _coat_shader: Shader
static var _hair_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, hair, parts), and says which is which: {"coat": the skin layer (its
## shells hang off it as `next_pass`), "hair", "parts"}. `tint` multiplies the
## coat's and the hair's colours; `shells` is how many layers of wool stand off it.
static func dress(model: Node, tint := Color.WHITE, shells := 1, fur_length := 0.05) -> Dictionary:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
		_hair_shader = _shader(HAIR_SHADER)
		_parts_shader = _shader(PARTS_SHADER)
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material: ShaderMaterial
			match String(original.resource_name):
				"coat":
					material = _coat(Color(0.25, 0.22, 0.19) * tint, Color(0.13, 0.115, 0.1) * tint, shells, fur_length)
				"hair":
					material = ShaderMaterial.new()
					material.shader = _hair_shader
					material.set_shader_parameter(&"albedo", Color(0.21, 0.185, 0.16) * tint)
					material.set_shader_parameter(&"dark", Color(0.11, 0.095, 0.085) * tint)
					material.set_shader_parameter(&"tips", Color(0.31, 0.27, 0.23) * tint)
					material.set_shader_parameter(&"time_offset", randf() * 10.0)
				_:
					material = ShaderMaterial.new()
					material.shader = _parts_shader
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


static func _coat(colour: Color, dark: Color, shells: int, fur_length: float) -> ShaderMaterial:
	var skin := _layer(colour, dark, 0.0, fur_length)
	var under := skin
	for i in shells:
		var layer := _layer(colour, dark, float(i + 1) / shells, fur_length)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, dark: Color, shell: float, fur_length: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"dark", dark)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"fur_length", fur_length)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
