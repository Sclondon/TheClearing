class_name HorseLook
## What a horse (Horse: creatures/horse/horse.gd) is drawn with: three
## materials, one for each of the model's three surfaces, so that one is a
## handful of draws. After the deer's (DeerLook), so that the two stand
## together in one light.
##
## - COAT: short hair, dull and a little rough (a horse long out in the
##   weather), lit in hard bands, streaked along the lie of the hair, with a
##   layer or two of shells that soften the outline. The model's vertex colours
##   say where it is creased (red: and between the ribs, which show), where the
##   coat is dark (green: the points, the dorsal stripe) and pale (blue: a
##   little, under the belly). A grey is DAPPLED (`dapples`): rings of darker
##   hair over its quarters and barrel. Its skin TWITCHES (`twitch`): a
##   shiver that runs over the skin round a point, as at a fly or a touch.
## - MANE: the mane, forelock and tail, in locks that sway as it moves (`sway`,
##   set by the rig), coarse and dull, paler at the ends where the sun has had them.
## - PARTS: eyes, nostrils, mouth, hooves, chestnuts, the halter and its rope, each
##   in its own colour from the vertex colours, wet ones with a hard glint. The
##   eyes are big and dark, with a long pupil across them, and give back a
##   little light (`eyeshine`).
##
## Nothing uses a texture, transparency or the screen, so it costs the same in a
## web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.5, 0.44, 0.34);
uniform vec3 dark : source_color = vec3(0.12, 0.1, 0.09);
uniform vec3 pale : source_color = vec3(0.62, 0.56, 0.46);
// The banded light.
uniform float wrap = 0.25;
uniform float flatness = 0.65;
// The coat: clumps along the lie of the hair, fine grain, broad patches (it is rough: a horse long out).
uniform vec2 clumps = vec2(36.0, 13.0);
uniform float clump_tone = 0.2;
uniform float strands = 300.0;
uniform float streak = 0.12;
uniform float patch = 0.14;
uniform float root_shade = 0.12;
uniform float tip_bleach = 0.06;
uniform float crease = 0.6;
uniform float rim_gain = 0.32;
uniform float rim_width = 0.3;
uniform float rim_ragged = 0.3;
uniform vec3 sheen : source_color = vec3(0.7, 0.68, 0.66);
uniform float sheen_gain = 0.04;
uniform float sheen_gloss = 10.0;
// A grey's dapples: rings of darker hair over the barrel and quarters (0 none).
uniform float dapples = 0.0;
// The skin twitching round a point (in the model's own space), and how hard.
uniform vec3 twitch_at = vec3(0.0, -100.0, 0.0);
uniform float twitch = 0.0;
// Which layer this is: 0 the skin, up to 1 for the tips of the hair.
uniform float shell = 0.0;
uniform float fur_length = 0.012;
uniform float comb = 0.8;
uniform float droop = 0.3;

varying vec3 lie;
varying float strand;
varying vec3 at_rest;

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
	at_rest = VERTEX;
	if (twitch > 0.0) {
		// (a shiver of the skin over the muscle under it: quick, small, dying away from the point)
		float near = 1.0 - smoothstep(0.05, 0.32, distance(VERTEX, twitch_at));
		VERTEX += NORMAL * sin(TIME * 70.0 + VERTEX.y * 40.0) * 0.006 * twitch * near;
	}
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		float hair = mix(0.35, 1.0, COLOR.r);
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * fur_length * hair * shell;
	}
}

void fragment() {
	vec2 at = vec2(UV.y * clumps.x, UV.x * clumps.y);
	float clump = noise(at) * 0.7 + noise(at * 2.3 + 5.0) * 0.3;
	float fine_grain = noise(vec2(UV.y * strands, UV.x * strands * 0.25));
	float fine = clamp(0.6 / max(fwidth(UV.y * strands), 0.0001), 0.0, 1.0);
	strand = mix(clump, fine_grain, 0.25);
	float tone = 1.0 + (clump - 0.5) * clump_tone + (fine_grain - 0.5) * streak * fine + (noise(UV * vec2(7.0, 4.0)) - 0.5) * patch;
	if (shell > 0.0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (facing > 0.8 - shell * 0.3 + (clump - 0.5) * 0.25) {
			discard;
		}
		vec2 tuft = vec2(UV.y * clumps.x * 2.0, UV.x * clumps.y * 1.5);
		float height = hash(floor(tuft)) * 0.6 + clump * 0.4;
		vec2 within = fract(tuft) - 0.5;
		if (height < shell * 0.8 + (1.0 - COLOR.r) * 0.3 || abs(within.x) * 2.0 + max(within.y, 0.0) > 1.15 - shell * 0.6) {
			discard;
		}
	}
	vec3 base = mix(albedo, dark, clamp(COLOR.g, 0.0, 1.0));
	base = mix(base, pale, smoothstep(0.15, 0.8, COLOR.b));
	if (dapples > 0.0) {
		// (on the barrel and quarters: rings of dark round paler middles)
		float where = smoothstep(0.75, 0.95, at_rest.y) * smoothstep(1.75, 1.45, at_rest.y) * (1.0 - clamp(COLOR.g * 2.0, 0.0, 1.0));
		vec2 grid = at_rest.zy * 7.0 + vec2(at_rest.x * 3.0, 0.0);
		vec2 cell = floor(grid);
		vec2 centre = vec2(hash(cell), hash(cell + 17.0)) * 0.5 + 0.25;
		float r = length(fract(grid) - centre);
		float ring = smoothstep(0.18, 0.32, r) * (1.0 - smoothstep(0.42, 0.55, r));
		base *= 1.0 - ring * 0.22 * dapples * where;
	}
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base *= tone * mix(1.0 - root_shade, 1.0 + tip_bleach, shell);
	ALBEDO = base;
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
	float band = pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss) * lit * (0.4 + strand);
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;
}
"""

const MANE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 albedo : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 tips : source_color = vec3(0.2, 0.17, 0.14);
uniform float wrap = 0.3;
uniform float flatness = 0.65;
// How far the locks swing (set by the rig as it moves, and shakes), m at their ends.
uniform float sway = 0.0;
uniform float time_offset = 0.0;

varying float tip;
varying float own;

void vertex() {
	// (each lock's texture coordinates run from its root, 0, to its end, 1; its
	// vertex colour's alpha is its own, so that no two swing alike)
	tip = UV.x;
	own = COLOR.a;
	float t = TIME * 2.6 + own * 9.0 + time_offset;
	VERTEX += vec3(sin(t) * 0.6, sin(t * 1.3) * 0.15, cos(t * 0.7) * 0.4 + 0.2) * tip * tip * (0.01 + sway);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	// (coarse: streaked along each lock, and the ends sun-bleached and ragged)
	float streaks = 0.85 + 0.3 * fract(sin(floor(UV.y * 9.0 + own * 31.0) * 12.9898) * 43758.5453);
	ALBEDO = mix(albedo * 0.85, tips, smoothstep(0.35, 1.0, tip) * (0.5 + 0.5 * own)) * streaks;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (abs(dot(NORMAL, LIGHT)) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.25;
uniform vec3 shine : source_color = vec3(0.7, 0.85, 0.8);

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
		// An eye: where on its front this is (the second texture coordinates), 0.5, 0.5 the middle of the
		// pupil, which is long and across it, as a horse's is
		vec2 at = UV2 - vec2(0.5);
		float r = length(at) / 0.4;
		float bar = length(at * vec2(0.75, 2.4)) / 0.4;
		float pixel = max(fwidth(bar), 0.002);
		float pupil = 1.0 - smoothstep(0.6 - pixel, 0.6 + pixel, bar);
		vec3 iris = COLOR.rgb * mix(1.4, 0.6, smoothstep(0.3, 0.9, r));
		ALBEDO = mix(iris, vec3(0.012, 0.01, 0.01), pupil);
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = shine * eyeshine * (0.15 + 0.85 * pow(facing, 3.0)) * mix(0.25, 0.7, pupil) * (1.0 - smoothstep(0.75, 1.0, r));
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
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 140.0, wet)), 0.6) * wet * max(lit, 0.35);
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.9;
}
"""

## Each coat's colours: the body, its points (and dorsal stripe), the pale, the mane and tail, and how dappled.
const COATS := {
	# A grey gone pale with age: mid grey dappled darker, dark legs, a mane and tail paler than the body
	0: {"coat": Color(0.53, 0.53, 0.52), "dark": Color(0.25, 0.25, 0.25), "pale": Color(0.66, 0.66, 0.64),
		"mane": Color(0.60, 0.59, 0.56), "dapples": 1.0},
	# A dun: a dull sandy grey-brown body, black points, the dorsal stripe, a black mane and tail
	1: {"coat": Color(0.46, 0.41, 0.33), "dark": Color(0.10, 0.09, 0.08), "pale": Color(0.56, 0.51, 0.42),
		"mane": Color(0.09, 0.08, 0.075), "dapples": 0.0},
	# A dark bay, nearly black-brown, with black points and a black mane and tail
	2: {"coat": Color(0.22, 0.16, 0.12), "dark": Color(0.065, 0.055, 0.05), "pale": Color(0.32, 0.25, 0.2),
		"mane": Color(0.055, 0.048, 0.045), "dapples": 0.0},
}

static var _coat_shader: Shader
static var _mane_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, mane, parts), in coat `coat` (Horse.Coat), and says which is which:
## {"coat": the skin layer of the coat (its shells hang off it as `next_pass`),
## "mane", "parts"}. `tint` multiplies the coat's colours; `shells` is how
## many layers of hair stand off it.
static func dress(model: Node, coat := 1, tint := Color.WHITE, shells := 1, eyeshine := 0.25, fur_length := 0.012) -> Dictionary:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
		_mane_shader = _shader(MANE_SHADER)
		_parts_shader = _shader(PARTS_SHADER)
	var colours: Dictionary = COATS.get(coat, COATS[1])
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material: ShaderMaterial
			match String(original.resource_name):
				"coat":
					material = _coat(colours["coat"] * tint, colours["dark"] * tint, colours["pale"] * tint, shells, fur_length, colours["dapples"])
				"mane":
					var hair: Color = colours["mane"] * tint
					material = ShaderMaterial.new()
					material.shader = _mane_shader
					material.set_shader_parameter(&"albedo", hair)
					material.set_shader_parameter(&"tips", hair.lerp(Color(0.62, 0.58, 0.5), 0.25))
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


static func _coat(colour: Color, dark: Color, pale: Color, shells: int, fur_length: float, dapples: float) -> ShaderMaterial:
	var skin := _layer(colour, dark, pale, 0.0, fur_length, dapples)
	var under := skin
	for i in shells:
		var layer := _layer(colour, dark, pale, float(i + 1) / shells, fur_length, dapples)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, dark: Color, pale: Color, shell: float, fur_length: float, dapples: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"dark", dark)
	material.set_shader_parameter(&"pale", pale)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"fur_length", fur_length)
	material.set_shader_parameter(&"dapples", dapples)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
