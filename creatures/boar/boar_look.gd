class_name BoarLook
## What the giant boar (Boar, creatures/boar/boar.gd) is drawn with: three
## materials, one for each of the model's three surfaces, so that it is a
## handful of draws however much is on it. After the dogs' (DogLook).
##
## - COAT: coarse black-brown bristle, lit in hard bands (cel shading), lying
##   in stiff clumps along the lie of the hair, grizzled at the tips, and drawn
##   again a few times stood off the skin ("shells") so that its outline is a
##   rough brush of bristles. The model's vertex colours say where it is creased
##   (red: dark), where it is caked with mud (green: wet and dark low down,
##   drying paler and cracked at its upper edge, the bristles stuck flat under
##   it), and where the hair is paler (blue: the grizzled snout and cheeks). Old
##   scars (the second texture coordinates) are bare, puckered and pale.
##   `mud` scales how muddy it is.
## - CREST: the long stiff hair along its spine. It lies back; `bristle` (0..1)
##   stands it up, the hackles of a boar about to charge.
## - PARTS: eyes, the disc of its nose, tusks, hooves, mouth, the arrows in it
##   and its slobber, each in its own colour from the vertex colours, wet ones
##   with a hard glint.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in
## a web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.10, 0.085, 0.07);
uniform vec3 pale : source_color = vec3(0.36, 0.32, 0.27);
uniform vec3 skin : source_color = vec3(0.24, 0.19, 0.18);
uniform vec3 scar : source_color = vec3(0.30, 0.25, 0.23);
uniform vec3 scar_edge : source_color = vec3(0.20, 0.13, 0.12);
uniform float scar_width = 0.35;
uniform float scar_bald = 0.7;
// Mud: wet and dark where it is thick, drying paler towards its edge.
uniform vec3 mud_wet : source_color = vec3(0.13, 0.10, 0.075);
uniform vec3 mud_dry : source_color = vec3(0.34, 0.29, 0.22);
uniform float mud = 1.0;
// The banded light.
uniform float wrap = 0.25;
uniform float flatness = 0.65;
// The bristles lie in stiff clumps: how many to a metre across the lie of the
// hair and along it, and how much they differ in tone.
uniform vec2 clumps = vec2(40.0, 10.0);
uniform float clump_tone = 0.25;
uniform float strands = 160.0;
uniform float streak = 0.2;
uniform float patch = 0.1;
uniform float root_shade = 0.12;
uniform float tip_grizzle = 0.3;
uniform float crease = 0.75;
uniform float pale_gain = 0.85;
uniform float rim_gain = 0.4;
uniform float rim_width = 0.3;
uniform float rim_ragged = 0.35;
uniform vec3 sheen : source_color = vec3(0.6, 0.6, 0.62);
uniform float sheen_gain = 0.06;
uniform float sheen_gloss = 9.0;
// Which layer this is: 0 the skin, up to 1 for the tips of the longest bristles.
uniform float shell = 0.0;
uniform float fur_length = 0.022;
uniform float comb = 0.9;
uniform float droop = 0.2;
// Shorter on the face (the first texture coordinate runs back from the nose).
uniform float face = -0.66;
uniform float face_length = 0.35;

varying vec3 lie;
varying float strand;
varying float caked;

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

// How far from the middle of a scar (cm), from the second texture coordinates
// (as the dogs': see creatures/boar/tools/build_boar.py).
float scar_gap(vec2 uv2, vec2 uv) {
	float across = abs(uv2.x - 0.5) * 10.0;
	float near = 1.0 - smoothstep(0.7, 1.3, abs(uv2.y - 0.5) * 10.0);
	return mix(9.0, across / (0.75 + 0.5 * noise(uv * vec2(9.0, 60.0))), near);
}

float bareness(vec2 uv, vec2 uv2) {
	return 1.0 - smoothstep(scar_width, scar_bald, scar_gap(uv2, uv));
}

// How caked with mud, 0..1, with a ragged edge.
float mud_cake(float painted, vec2 uv) {
	float n = noise(uv * vec2(14.0, 14.0)) * 0.6 + noise(uv * vec2(41.0, 37.0)) * 0.4;
	return smoothstep(0.35, 0.6, painted * mud + (n - 0.5) * 0.35);
}

void vertex() {
	float bare = bareness(UV, UV2);
	caked = mud_cake(COLOR.g, UV);
	// (scar tissue stands a little proud, and caked mud a little more)
	VERTEX += NORMAL * (0.0018 * (1.0 - smoothstep(0.0, scar_width * 1.4, scar_gap(UV2, UV))) + 0.004 * caked);
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		float hair = mix(face_length, 1.0, smoothstep(face - 0.05, face + 0.05, UV.x));
		hair *= mix(0.35, 1.0, COLOR.r) * (1.0 - bare) * (1.0 - caked * 0.85);
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * fur_length * hair * shell;
	}
}

void fragment() {
	vec2 at = vec2(UV.y * clumps.x, UV.x * clumps.y);
	float clump = noise(at) * 0.7 + noise(at * 2.3 + 5.0) * 0.3;
	float fine_grain = noise(vec2(UV.y * strands, UV.x * strands * 0.2));
	float fine = clamp(0.6 / max(fwidth(UV.y * strands), 0.0001), 0.0, 1.0);
	strand = mix(clump, fine_grain, 0.3);
	float tone = 1.0 + (clump - 0.5) * clump_tone + (fine_grain - 0.5) * streak * fine + (noise(UV * vec2(6.0, 4.0)) - 0.5) * patch;
	tone *= mix(0.85, 1.0, smoothstep(0.15, 0.45, clump));
	float bare = bareness(UV, UV2);
	if (shell > 0.0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (facing > 0.84 - shell * 0.3 + (clump - 0.5) * 0.25) {
			discard;
		}
		if (bare > 0.7 - shell * 0.4 + (clump - 0.5) * 0.3 || caked > 0.55 - shell * 0.3) {
			discard;
		}
		// The ends of the clumps: a ragged brush of bristles.
		vec2 tuft = vec2(UV.y * clumps.x * 2.5, UV.x * clumps.y * 1.5);
		float height = hash(floor(tuft)) * 0.6 + clump * 0.4;
		vec2 within = fract(tuft) - 0.5;
		float across = abs(within.x) * 2.0 + max(within.y, 0.0);
		if (height < shell * 0.8 + (1.0 - COLOR.r) * 0.3 || across > 1.1 - shell * 0.6) {
			discard;
		}
	}
	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	// (grizzled: the tips of the bristles are pale)
	base = mix(base * (1.0 - root_shade), mix(base, pale, tip_grizzle), shell);
	base *= tone;
	float gap = scar_gap(UV2, UV);
	float on_scar = 1.0 - smoothstep(scar_width * 0.7, scar_width * 1.3, gap);
	vec3 tissue = mix(scar_edge, scar, 1.0 - smoothstep(0.0, scar_width, gap));
	vec3 hide = mix(skin * (0.85 + 0.3 * noise(UV * 90.0)) * mix(0.6, 1.0, COLOR.r), tissue, on_scar);
	vec3 colour = mix(base, hide, smoothstep(0.45, 0.85, bare) * (shell > 0.0 ? 0.0 : 1.0));
	// Mud: dark and wet where it is thick, dry, pale and cracked towards its edge.
	float thick = smoothstep(0.55, 1.0, COLOR.g * mud);
	float crack = smoothstep(0.04, 0.0, abs(noise(UV * 90.0) - 0.5)) * (1.0 - thick) * 0.6;
	vec3 dirt = mix(mud_dry, mud_wet, thick) * (0.85 + 0.3 * noise(UV * 30.0)) * (1.0 - crack * 0.5);
	ALBEDO = mix(colour, dirt, caked);
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
	float lit = cut(amount + (strand - 0.5) * 0.06, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (strand - 0.5) * rim_ragged) * lit;
	vec3 along = normalize(normalize(lie) + NORMAL * (strand - 0.5) * 0.8);
	float across = dot(along, normalize(LIGHT + VIEW));
	float band = pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss) * lit * (0.4 + strand) * (1.0 - caked);
	// (wet mud has a dull shine of its own)
	vec3 half_way = normalize(LIGHT + VIEW);
	float wet = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 24.0), 0.55) * caked * lit * 0.5;
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5) + wet * vec3(0.5)) * strength * LIGHT_COLOR / PI;
}
"""

const CREST_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.085, 0.072, 0.062);
uniform vec3 tips : source_color = vec3(0.30, 0.27, 0.23);
uniform float wrap = 0.3;
uniform float flatness = 0.65;
// 0 lying back along the spine, 1 standing straight up: the hackles.
uniform float bristle = 0.0;
// How far a bristle's tip goes when it stands (m, in the model).
uniform float stand = 0.11;
uniform float time_offset = 0.0;

varying float tip;

void vertex() {
	// (each bristle's texture coordinates run from its root, 0, to its tip, 1;
	// its vertex colour's alpha is its own, so that no two stand alike)
	tip = UV.x;
	float own = COLOR.a;
	float quiver = sin(TIME * 19.0 + own * 40.0 + time_offset) * 0.10 * bristle;
	VERTEX += vec3((own - 0.5) * 0.45, 0.95, 0.75 + quiver + (own - 0.5) * 0.5) * tip * bristle * stand * mix(0.55, 1.2, own);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = mix(albedo * 0.7, tips, smoothstep(0.35, 1.0, tip));
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
uniform float eyeshine = 0.35;
uniform vec3 shine : source_color = vec3(0.9, 0.45, 0.2);

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
		// the middle of the pupil, 1 at its rim. A boar's eye is small and dark, a
		// little red-brown about a wide pupil.
		float r = length(UV2 - vec2(0.5)) / 0.4;
		float pixel = max(fwidth(r), 0.002);
		float pupil = 1.0 - smoothstep(0.5 - pixel, 0.5 + pixel, r);
		float rim = smoothstep(0.75 - pixel, 0.86 + pixel, r);
		vec3 iris = COLOR.rgb * mix(1.1, 0.55, smoothstep(0.4, 0.85, r));
		ALBEDO = mix(mix(iris, vec3(0.02, 0.015, 0.015), pupil), vec3(0.05, 0.03, 0.025), rim);
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
	// A wet surface (the disc of its nose, an eye, slobber) has one small hard glint on it.
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 120.0, wet)), 0.6) * wet * lit;
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.8;
}
"""

static var _coat_shader: Shader
static var _crest_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, crest, parts), and says which is which: {"coat": the skin layer of
## the coat (its shells hang off it as `next_pass`), "crest", "parts"}.
## `coat_tint` multiplies the coat's colours; `shells` is how many layers of
## bristle stand off it; `mud` how muddy it is (0..1.5).
static func dress(model: Node, coat_tint := Color.WHITE, shells := 2, mud := 1.0, eyeshine := 0.35) -> Dictionary:
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
					material = _coat(original.albedo_color * coat_tint, shells, mud)
				"crest":
					material = ShaderMaterial.new()
					material.shader = _crest_shader
					material.set_shader_parameter(&"albedo", original.albedo_color * coat_tint)
					material.set_shader_parameter(&"tips", (original.albedo_color * coat_tint).lightened(0.22))
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


static func _coat(colour: Color, shells: int, mud: float) -> ShaderMaterial:
	var skin := _layer(colour, 0.0, mud)
	var under := skin
	for i in shells:
		var layer := _layer(colour, float(i + 1) / shells, mud)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, shell: float, mud: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"pale", colour.lerp(Color(0.5, 0.45, 0.38), 0.55))
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mud", mud)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
