class_name BearLook
## What the screaming bear (Bear, creatures/bear/bear.gd) is drawn with: two
## materials, one for each of the model's two surfaces, so that it is a
## handful of draws. After the boar's (BoarLook).
##
## - COAT: ragged dark grey-brown fur, lit in hard bands (cel shading), in
##   clumps along the lie of the hair, grizzled at the tips, and drawn again a
##   few times stood off the skin ("shells"), hanging lank, so that its outline
##   is a tatter of hair. The model's vertex colours say where it is creased
##   (red: dark), where the fur has sloughed off (green: pale, blotched, veined
##   skin, with a raw edge where the fur still clings), where the hair is paler
##   (blue), and where even the skin has gone (alpha 0: bare bone, ivory,
##   cracked, dark in its seams). `bare` scales how much of it has sloughed.
## - PARTS: teeth, gums, eyes (the left its own, dark; the right clouded
##   white), claws, the bare ribs and bone, flaps of skin, slaver: each in its
##   own colour from the vertex colours, wet ones with a hard glint.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in
## a web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.15, 0.135, 0.12);
uniform vec3 pale : source_color = vec3(0.36, 0.33, 0.30);
// Bare skin: pallid grey with a little blood under it, blotched and veined.
uniform vec3 skin : source_color = vec3(0.43, 0.40, 0.39);
uniform vec3 blotch : source_color = vec3(0.32, 0.27, 0.26);
uniform vec3 vein : source_color = vec3(0.24, 0.24, 0.29);
uniform vec3 raw : source_color = vec3(0.34, 0.20, 0.19);
// Bone: ivory, the seams of the skull dark.
uniform vec3 bone : source_color = vec3(0.53, 0.50, 0.43);
uniform vec3 seam : source_color = vec3(0.20, 0.17, 0.14);
uniform float bare = 1.0;
// The banded light.
uniform float wrap = 0.25;
uniform float flatness = 0.65;
uniform vec2 clumps = vec2(34.0, 9.0);
uniform float clump_tone = 0.3;
uniform float strands = 150.0;
uniform float streak = 0.22;
uniform float patch = 0.12;
uniform float root_shade = 0.12;
uniform float tip_grizzle = 0.28;
uniform float crease = 0.75;
uniform float pale_gain = 0.8;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.3;
uniform float rim_ragged = 0.4;
// Which layer this is: 0 the skin, up to 1 for the tips of the longest hair.
uniform float shell = 0.0;
uniform float fur_length = 0.03;
uniform float comb = 0.7;
// (the hair hangs lank: it droops a long way)
uniform float droop = 0.6;
uniform float face = -0.7;
uniform float face_length = 0.3;

varying vec3 lie;
varying float strand;
varying float bald;
varying float boned;

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

// How bare, 0..1, with a ragged edge (where the fur is coming away in clumps).
float bareness(float painted, vec2 uv) {
	float n = noise(uv * vec2(18.0, 15.0)) * 0.6 + noise(uv * vec2(53.0, 47.0)) * 0.4;
	return smoothstep(0.35, 0.55, painted * bare + (n - 0.5) * 0.4);
}

void vertex() {
	bald = bareness(COLOR.g, UV);
	boned = 1.0 - smoothstep(0.35, 0.65, COLOR.a);
	// (bare, it is shrunk a little onto what is under it)
	VERTEX -= NORMAL * 0.003 * bald;
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		float hair = mix(face_length, 1.0, smoothstep(face - 0.05, face + 0.05, UV.x));
		// (longest and most ragged at the edge of a bare patch, where it hangs off in clumps)
		hair *= mix(0.4, 1.0, COLOR.r) * (1.0 + smoothstep(0.1, 0.5, COLOR.g) * 0.8) * (1.0 - boned);
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
	tone *= mix(0.8, 1.0, smoothstep(0.15, 0.45, clump));
	if (shell > 0.0) {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (facing > 0.84 - shell * 0.3 + (clump - 0.5) * 0.25) {
			discard;
		}
		if (bald > 0.6 - shell * 0.35 + (clump - 0.5) * 0.4 || boned > 0.3) {
			discard;
		}
		// The ends of the clumps: lank, matted tails of hair.
		vec2 tuft = vec2(UV.y * clumps.x * 2.2, UV.x * clumps.y * 1.3);
		float height = hash(floor(tuft)) * 0.6 + clump * 0.4;
		vec2 within = fract(tuft) - 0.5;
		float across = abs(within.x) * 2.0 + max(within.y, 0.0);
		if (height < shell * 0.75 + (1.0 - COLOR.r) * 0.3 || across > 1.1 - shell * 0.65) {
			discard;
		}
	}
	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);
	base *= mix(1.0 - crease, 1.0, COLOR.r);
	base = mix(base * (1.0 - root_shade), mix(base, pale, tip_grizzle), shell);
	base *= tone;
	// Bare skin: blotched, veined, and raw where the fur has only just come away.
	float blot = smoothstep(0.45, 0.75, noise(UV * vec2(22.0, 19.0)) * 0.7 + noise(UV * 70.0) * 0.3);
	float veins = smoothstep(0.035, 0.0, abs(noise(UV * vec2(31.0, 26.0)) - 0.5)) * smoothstep(0.3, 0.7, noise(UV * 9.0 + 3.0));
	vec3 hide = mix(skin, blotch, blot * 0.7);
	hide = mix(hide, vein, veins * 0.6);
	hide *= mix(0.7, 1.0, COLOR.r) * (0.9 + 0.2 * noise(UV * 120.0));
	float fresh = smoothstep(0.75, 0.5, bald) * smoothstep(0.3, 0.55, bald);
	hide = mix(hide, raw, fresh * 0.75);
	// Bone: ivory, pitted, the seams dark.
	float cracks = smoothstep(0.02, 0.0, abs(noise(UV * vec2(40.0, 33.0)) - 0.5)) * smoothstep(0.35, 0.6, noise(UV * 13.0 + 7.0));
	vec3 skull = bone * (0.78 + 0.3 * noise(UV * 80.0)) * mix(0.6, 1.0, COLOR.r) * mix(0.8, 1.0, noise(UV * vec2(25.0, 20.0)));
	skull = mix(skull, seam, cracks * 0.7);
	vec3 colour = mix(base, hide, smoothstep(0.4, 0.8, bald) * (shell > 0.0 ? 0.0 : 1.0));
	colour = mix(colour, skull, boned * (shell > 0.0 ? 0.0 : 1.0));
	ALBEDO = colour;
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
	// (bare skin is greasy: a dull, hard sheen on it)
	vec3 half_way = normalize(LIGHT + VIEW);
	float sheen = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 18.0), 0.5) * smoothstep(0.5, 0.9, bald) * (1.0 - boned) * lit * 0.35;
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + sheen * vec3(0.6)) * strength * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.65;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.3;
uniform vec3 shine : source_color = vec3(0.75, 0.62, 0.45);
// Its clouded eye's faint glow, in the dark.
uniform float clouded_glow = 0.12;

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
		// the middle of the pupil, 1 at its rim.
		float r = length(UV2 - vec2(0.5)) / 0.4;
		float pixel = max(fwidth(r), 0.002);
		float pupil = 1.0 - smoothstep(0.42 - pixel, 0.42 + pixel, r);
		float rim = smoothstep(0.78 - pixel, 0.9 + pixel, r);
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		if (COLOR.r > 0.5) {
			// Clouded over: milky, a ghost of a pupil under it.
			vec3 milk = COLOR.rgb * mix(1.0, 0.8, smoothstep(0.3, 0.9, r));
			ALBEDO = mix(mix(milk, milk * 0.72, pupil * 0.5), vec3(0.25, 0.22, 0.2), rim);
			EMISSION = vec3(0.8, 0.85, 0.9) * clouded_glow * (0.4 + 0.6 * facing) * (1.0 - rim);
		} else {
			vec3 iris = COLOR.rgb * mix(1.3, 0.6, smoothstep(0.4, 0.85, r));
			ALBEDO = mix(mix(iris, vec3(0.01), pupil), vec3(0.03, 0.02, 0.02), rim);
			EMISSION = shine * eyeshine * (0.25 + 0.75 * facing * facing) * (1.0 - rim) * mix(0.6, 0.3, pupil);
		}
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// A wet surface (gums, an eye, slaver) has one small hard glint on it.
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 120.0, wet)), 0.6) * wet * lit;
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.8;
}
"""

static var _coat_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, parts), and says which is which: {"coat": the skin layer of the coat
## (its shells hang off it as `next_pass`), "parts"}. `coat_tint` multiplies
## the fur's colours; `shells` is how many layers of hair stand off it; `bare`
## how much of it has sloughed (0..1.5).
static func dress(model: Node, coat_tint := Color.WHITE, shells := 2, bare := 1.0, eyeshine := 0.3) -> Dictionary:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
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
					material = _coat(original.albedo_color * coat_tint, shells, bare)
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


static func _coat(colour: Color, shells: int, bare: float) -> ShaderMaterial:
	var skin := _layer(colour, 0.0, bare)
	var under := skin
	for i in shells:
		var layer := _layer(colour, float(i + 1) / shells, bare)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, shell: float, bare: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"pale", colour.lerp(Color(0.5, 0.47, 0.43), 0.5))
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"bare", bare)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader
