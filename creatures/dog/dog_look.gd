class_name DogLook
## What a feral dog (Dog, creatures/dog/dog.gd) is drawn with: three
## materials, one for each of the model's three surfaces, so that a dog is a
## handful of draws however much is on it.
##
## - COAT: short, coarse, matted fur, after Outside's Fur. The coat is lit in
##   hard bands (cel shading), streaked along the lie of the hair, and drawn
##   again a few times stood off the skin ("shells") with more of it cut away
##   each time, so that what is left stands up as tufts and the outline is
##   ragged. The model's vertex colours say where it is creased (red: the
##   grooves between its ribs, round its eyes and under its jaw go dark, and
##   the hair is thin there, so the ribs show), where it is scarred (green:
##   bare, pale, puckered skin), and where it is paler underneath (blue). On
##   top of that it is mangy: bare grey-pink patches, worked out from where on
##   the coat a point is, as many as `mange` says.
## - CREST: the coarse hair along its neck and spine. It lies flat; `bristle`
##   (0..1) stands it up, the hackles of a dog that means it.
## - PARTS: eyes, nose, teeth, gums, mouth and the insides of its ears, each
##   in its own colour from the vertex colours, wet ones with a hard glint.
##   The eyes catch the light back (`eyeshine`), as a dog's do in the dark.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in
## a web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.16, 0.14, 0.12);
uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);
uniform vec3 skin : source_color = vec3(0.27, 0.21, 0.2);
uniform vec3 scar : source_color = vec3(0.36, 0.3, 0.28);
// The banded light.
uniform float wrap = 0.25;
uniform float flatness = 0.65;
// How many strands across a metre of coat, how long a run of one tone is along them, how far their tones differ.
uniform float strands = 900.0;
uniform float run = 0.022;
uniform float streak = 0.32;
// Patches a few centimetres across, darker or lighter all over.
uniform float patch = 0.22;
uniform float root_shade = 0.5;
uniform float tip_bleach = 0.18;
// How dark the creases go, and how much paler the underside is.
uniform float crease = 0.72;
uniform float pale_gain = 0.75;
// Bare patches: how much of the coat is bare, and how big a patch is (m).
uniform float mange = 0.3;
uniform float mange_size = 0.06;
uniform float rim_gain = 0.45;
uniform float rim_width = 0.3;
uniform float rim_ragged = 0.4;
uniform vec3 sheen : source_color = vec3(0.6, 0.62, 0.66);
uniform float sheen_gain = 0.06;
uniform float sheen_gloss = 12.0;
// Which layer this is: 0 the skin, up to 1 for the tips of the longest hair.
uniform float shell = 0.0;
uniform float fur_length = 0.014;
uniform float comb = 0.8;
uniform float droop = 0.3;
// Fewer, bigger tufts than a groomed coat: it is matted.
uniform float tufts = 700.0;
uniform float face = -0.44;
uniform float face_length = 0.22;

varying vec3 lie;
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

// How bare the coat is here, 0..1: mange (thin at the edge of a patch, bare in
// its middle, the edge ragged), and scars (green).
float bareness(vec2 uv, vec4 colour) {
	vec2 at = uv / mange_size;
	float n = noise(at) * 0.6 + noise(at * 2.7 + 13.0) * 0.28 + noise(at * 9.0 + 41.0) * 0.12;
	float edge = 1.0 - mange * 0.5;
	float mangy = smoothstep(edge - 0.06, edge + 0.1, n);
	return max(mangy, smoothstep(0.3, 0.7, colour.g));
}

void vertex() {
	float bare = bareness(UV, COLOR);
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		float hair = mix(face_length, 1.0, smoothstep(face - 0.05, face + 0.03, UV.x));
		// (shorter in the creases, so that the ribs show through)
		hair *= mix(0.35, 1.0, COLOR.r) * (1.0 - bare);
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * fur_length * hair * shell;
	}
}

void fragment() {
	vec2 grain = vec2(UV.y * strands, UV.x / run);
	float fine = clamp(0.6 / max(fwidth(grain.x), 0.0001), 0.0, 1.0);
	strand = noise(grain);
	float tone = 1.0 + (strand - 0.5) * streak * fine + (noise(UV * vec2(19.0, 47.0)) - 0.5) * patch;
	float bare = bareness(UV, COLOR);
	if (shell > 0.0) {
		// (towards a bare patch the hair thins out, the longest going first)
		if (bare > 0.75 - shell * 0.45 + (strand - 0.5) * 0.3) {
			discard;
		}
		float row = floor(UV.y * tufts);
		vec2 tuft = vec2(UV.y * tufts, UV.x * tufts * 0.13 + hash(vec2(row, 7.0)) * 7.0);
		float height = hash(floor(tuft)) * 0.75 + strand * 0.25;
		vec2 within = fract(tuft) - 0.5;
		float across = max(abs(within.x) * 2.0, abs(within.y) * 2.0 - 0.35);
		float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		float thin = smoothstep(0.55, 0.95, edge) * 0.45;
		// (thin in the creases too)
		thin += (1.0 - COLOR.r) * 0.35;
		if (height < shell + thin || across > 1.2 - shell * 0.75) {
			discard;
		}
	}
	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base *= tone * mix(1.0 - root_shade, 1.0 + tip_bleach, shell);
	// Bare skin: grey-pink, mottled, and scar tissue paler still.
	vec3 hide = mix(skin, scar, smoothstep(0.2, 0.7, COLOR.g)) * (0.85 + 0.3 * noise(UV * 90.0)) * mix(0.6, 1.0, COLOR.r);
	ALBEDO = mix(base, hide, smoothstep(0.45, 0.85, bare) * (shell > 0.0 ? 0.0 : 1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	lie = TANGENT;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount + (strand - 0.5) * 0.14, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (strand - 0.5) * rim_ragged) * lit;
	vec3 along = normalize(normalize(lie) + NORMAL * (strand - 0.5) * 0.8);
	float across = dot(along, normalize(LIGHT + VIEW));
	float band = pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss) * lit * (0.4 + strand);
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;
}
"""

const CREST_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.13, 0.115, 0.10);
uniform vec3 tips : source_color = vec3(0.30, 0.27, 0.23);
uniform float wrap = 0.3;
uniform float flatness = 0.65;
// 0 lying flat along the back, 1 standing straight up: the hackles.
uniform float bristle = 0.0;
// How far a tuft's tip goes when it stands (m, in the model).
uniform float stand = 0.04;
uniform float time_offset = 0.0;

varying float tip;

void vertex() {
	// (each tuft's texture coordinates run from its root, 0, to its tip, 1;
	// its vertex colour's alpha is its own, so that no two stand alike)
	tip = UV.x;
	float own = COLOR.a;
	float quiver = sin(TIME * 23.0 + own * 40.0 + time_offset) * 0.12 * bristle;
	VERTEX += vec3((own - 0.5) * 0.5, 0.85, 0.8 + quiver + (own - 0.5) * 0.6) * tip * bristle * stand * mix(0.5, 1.2, own);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = mix(albedo * 0.7, tips, smoothstep(0.2, 1.0, tip));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.5;
uniform vec3 shine : source_color = vec3(0.95, 0.8, 0.35);

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
	if (wet > 0.95) {
		// (strongest looking straight at it, as eyeshine is)
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = shine * eyeshine * (0.25 + 0.75 * facing * facing);
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// A wet surface has one small hard glint on it.
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 120.0, wet)), 0.6) * wet * lit;
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.8;
}
"""

static var _coat_shader: Shader
static var _crest_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives
## it (coat, crest, parts), and says which is which: {"coat": the skin layer
## of the coat (its shells hang off it as `next_pass`), "crest", "parts"}.
## `coat_tint` multiplies the coat's colours (a dog a little darker or redder
## than the next); `shells` is how many layers of fur stand off it.
static func dress(model: Node, coat_tint := Color.WHITE, shells := 2, mange := 0.3, eyeshine := 0.5) -> Dictionary:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
		_crest_shader = _shader(CREST_SHADER)
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
					material = _coat(original.albedo_color * coat_tint, shells, mange)
				"crest":
					material = ShaderMaterial.new()
					material.shader = _crest_shader
					material.set_shader_parameter(&"albedo", original.albedo_color * coat_tint)
					material.set_shader_parameter(&"tips", (original.albedo_color * coat_tint).lightened(0.18))
					material.set_shader_parameter(&"time_offset", randf() * 10.0)
				_:
					material = ShaderMaterial.new()
					material.shader = _parts_shader
					material.set_shader_parameter(&"eyeshine", eyeshine)
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


## Sets a parameter on a coat made by `dress`: on the skin and every shell over it.
static func tune(material: ShaderMaterial, values: Dictionary) -> void:
	while material:
		for parameter: StringName in values:
			material.set_shader_parameter(parameter, values[parameter])
		material = material.next_pass as ShaderMaterial


static func _coat(colour: Color, shells: int, mange: float) -> ShaderMaterial:
	var skin := _layer(colour, 0.0, mange)
	var under := skin
	for i in shells:
		var layer := _layer(colour, float(i + 1) / shells, mange)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, shell: float, mange: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"pale", colour.lerp(Color(0.62, 0.55, 0.46), 0.6))
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mange", mange)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
