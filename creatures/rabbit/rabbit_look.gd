class_name RabbitLook
## What a rabbit, a hare or a jackalope (Rabbit: creatures/rabbit/rabbit.gd)
## is drawn with, and the earth of a warren (RabbitWarren): a material for each
## of the model's two surfaces, so that one animal is a handful of draws.
##
## - COAT: soft, dense fur (after DeerLook's coat): agouti, each hair banded
##   pale and dark so that the coat is finely ticked; lit in hard bands, with a
##   layer of shells that softens the outline. The model's vertex colours say
##   where it is creased (red), where the coat is dark (green: the back, the
##   top of a rabbit's scut), where it is pale (blue: the belly, the chin, the
##   ring round the eye, under the scut) and where it is black (alpha: a hare's
##   ear tips and the top of its tail).
## - PARTS: eyes, nose, claws, teeth, the insides of the ears and a
##   jackalope's antlers, each in its own colour from the vertex colours, wet
##   ones with a hard glint. The eyes are big and dark (a hare's amber), with a
##   round pupil, and give back the light (`eyeshine`, a dull red, as a
##   rabbit's does in a torch beam; `shine` sets its colour).
## - EARTH (a warren): the vertex colours (turf, bare earth, fresh spoil, the
##   dark of the tunnels) with a fine grain of crumbs and stones, lit in the
##   same hard bands, drawn from both sides.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in a
## web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.4, 0.35, 0.29);
uniform vec3 dark : source_color = vec3(0.24, 0.2, 0.16);
uniform vec3 pale : source_color = vec3(0.8, 0.77, 0.71);
uniform vec3 black : source_color = vec3(0.045, 0.04, 0.035);
// The banded light.
uniform float wrap = 0.3;
uniform float flatness = 0.65;
// Soft fur: clumps along the lie of the hair, the ticking of banded hairs, broad patches.
uniform vec2 clumps = vec2(90.0, 30.0);
uniform float clump_tone = 0.2;
uniform float ticking = 0.22;
uniform float strands = 700.0;
uniform float patch = 0.08;
uniform float root_shade = 0.18;
uniform float tip_bleach = 0.08;
uniform float crease = 0.55;
uniform float rim_gain = 0.55;
uniform float rim_width = 0.4;
uniform float rim_ragged = 0.35;
// Which layer this is: 0 the skin, up to 1 for the tips of the hair. The
// layers stand off the skin only towards the outline, to soften it.
uniform float shell = 0.0;
uniform float fur_length = 0.004;
uniform float comb = 0.25;
uniform float droop = 0.0;

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
		float hair = mix(0.4, 1.0, COLOR.r);
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * fur_length * hair * shell;
	}
}

void fragment() {
	vec2 at = vec2(UV.y * clumps.x, UV.x * clumps.y);
	float clump = noise(at) * 0.7 + noise(at * 2.3 + 5.0) * 0.3;
	float grain = noise(vec2(UV.y * strands, UV.x * strands * 0.3));
	float fine = clamp(0.6 / max(fwidth(UV.y * strands), 0.0001), 0.0, 1.0);
	strand = mix(clump, grain, 0.3);
	// (each hair is banded: grey at its root, a pale band, a dark tip; seen together, ticked)
	float tick = (noise(vec2(UV.y * strands * 0.5, UV.x * strands * 0.2)) - 0.5) * 2.0 * ticking * fine;
	float tone = 1.0 + (clump - 0.5) * clump_tone + tick + (noise(UV * vec2(9.0, 5.0)) - 0.5) * patch;
	if (shell > 0.0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (facing > 0.82 - shell * 0.3 + (clump - 0.5) * 0.25) {
			discard;
		}
		vec2 tuft = vec2(UV.y * clumps.x * 2.0, UV.x * clumps.y * 1.5);
		float height = hash(floor(tuft)) * 0.6 + clump * 0.4;
		vec2 within = fract(tuft) - 0.5;
		if (height < shell * 0.75 + (1.0 - COLOR.r) * 0.3 || abs(within.x) * 2.0 + max(within.y, 0.0) > 1.2 - shell * 0.6) {
			discard;
		}
	}
	vec3 base = mix(albedo, dark, clamp(COLOR.g, 0.0, 1.0));
	// (a rabbit's pale parts are soft-edged, its belly fading into its flank)
	base = mix(base, pale, smoothstep(0.1, 0.75, COLOR.b));
	base = mix(base, black, smoothstep(0.15, 0.7, COLOR.a));
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base *= tone * mix(1.0 - root_shade, 1.0 + tip_bleach, shell);
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
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount + (strand - 0.5) * 0.08, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (strand - 0.5) * rim_ragged) * lit;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.5;
uniform vec3 shine : source_color = vec3(0.95, 0.42, 0.25);

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
		// An eye: where on its front this is (the second texture coordinates), 0.5, 0.5 the middle of the pupil,
		// which is round and large; the iris a ring round it, darker at its rim
		vec2 at = UV2 - vec2(0.5);
		float r = length(at) / 0.4;
		float pixel = max(fwidth(r), 0.002);
		float pupil = 1.0 - smoothstep(0.52 - pixel, 0.52 + pixel, r);
		vec3 iris = COLOR.rgb * mix(1.25, 0.45, smoothstep(0.4, 0.95, r));
		ALBEDO = mix(iris, vec3(0.012, 0.01, 0.01), pupil);
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = shine * eyeshine * (0.1 + 0.9 * pow(facing, 3.0)) * mix(0.3, 0.8, pupil) * (1.0 - smoothstep(0.75, 1.0, r));
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
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 160.0, wet)), 0.6) * wet * max(lit, 0.35);
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.9;
}
"""

const EARTH_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float wrap = 0.3;
uniform float flatness = 0.6;
uniform float grain = 0.22;
uniform vec3 tint : source_color = vec3(1.0);
// How much of its colour it keeps (0 grey).
uniform float colourfulness = 0.6;

varying vec3 at;

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
	at = VERTEX;
}

void fragment() {
	// (the colours are painted as seen: brought to light's measure, and most of their colour taken out, as the
	// light here takes it out of everything)
	vec3 painted = pow(COLOR.rgb, vec3(1.45)) * 1.3;
	vec3 col = mix(vec3(dot(painted, vec3(0.3, 0.55, 0.15))), painted, colourfulness);
	// (crumbs and small round stones; blades of turf where it is green)
	float crumbs = noise(at.xz * 60.0) * 0.6 + noise(at.xz * 190.0 + at.y * 40.0) * 0.4;
	vec2 g = at.xz * 28.0;
	vec2 cell = floor(g);
	vec2 off = fract(g) - (vec2(hash(cell), hash(cell + 7.0)) * 0.6 + 0.2);
	float stones = step(0.86, hash(cell + 3.0)) * (1.0 - smoothstep(0.07, 0.13, length(off)));
	float green = clamp((COLOR.g - COLOR.r) * 12.0 + 0.5, 0.0, 1.0);
	float blades = noise(vec2(at.x * 300.0, at.z * 40.0)) * green;
	vec3 base = col * tint * (1.0 + (crumbs - 0.5) * grain + blades * 0.12 - stones * 0.22);
	if (!FRONT_FACING) {
		base *= 0.4;
	}
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
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.06);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
}
"""

static var _coat_shader: Shader
static var _parts_shader: Shader
static var _earth_shader: Shader
static var _earth: ShaderMaterial


## Gives every surface of `model` its material, by the name the model gives it
## (coat, parts), and says which is which: {"coat": the skin layer of the coat
## (its shells hang off it as `next_pass`), "parts"}. `tint` multiplies the
## coat's colours; `shells` is how many layers of hair stand off it; `colours`
## (optional) sets "coat", "dark" and "pale"; `shine` the colour its eyes give
## back.
static func dress(model: Node, tint := Color.WHITE, shells := 1, eyeshine := 0.5, colours := {}, fur_length := 0.004, shine := Color(0.95, 0.42, 0.25)) -> Dictionary:
	_make_shaders()
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material: ShaderMaterial
			if String(original.resource_name) == "coat":
				material = _coat(colours.get("coat", original.albedo_color) * tint, colours.get("dark", Color(0.24, 0.2, 0.16)) * tint,
						colours.get("pale", Color(0.8, 0.77, 0.71)), shells, fur_length)
			else:
				material = ShaderMaterial.new()
				material.shader = _parts_shader
				material.set_shader_parameter(&"eyeshine", eyeshine)
				material.set_shader_parameter(&"shine", shine)
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


## The earth a warren is made of (one material, shared by every warren).
static func earth() -> ShaderMaterial:
	_make_shaders()
	if _earth == null:
		_earth = ShaderMaterial.new()
		_earth.shader = _earth_shader
	return _earth


## Sets a parameter on a coat made by `dress`: on the skin and every shell over it.
static func tune(material: ShaderMaterial, values: Dictionary) -> void:
	while material:
		for parameter: StringName in values:
			material.set_shader_parameter(parameter, values[parameter])
		material = material.next_pass as ShaderMaterial


static func _make_shaders() -> void:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
		_parts_shader = _shader(PARTS_SHADER)
		_earth_shader = _shader(EARTH_SHADER)


static func _coat(colour: Color, dark: Color, pale: Color, shells: int, fur_length: float) -> ShaderMaterial:
	var skin := _layer(colour, dark, pale, 0.0, fur_length)
	var under := skin
	for i in shells:
		var layer := _layer(colour, dark, pale, float(i + 1) / shells, fur_length)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, dark: Color, pale: Color, shell: float, fur_length: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"dark", dark)
	material.set_shader_parameter(&"pale", pale)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"fur_length", fur_length)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
