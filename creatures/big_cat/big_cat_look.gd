class_name BigCatLook
## What a big cat (BigCat, creatures/big_cat/big_cat.gd) is drawn with: two
## materials, one for each of the model's two surfaces, so that a cat is a
## handful of draws.
##
## - COAT: the dog's fur (DogLook.COAT_SHADER: lit in hard bands, streaked
##   along the lie of the hair, drawn again a few times stood off the skin so
##   that the outline is soft), with a cat's markings laid over it. The model
##   (tools/build_big_cat.py) paints them into the coat's vertex colours:
##   - red: how open the surface is (dark in creases, as the dog's);
##   - green: how dark its markings are (the lynx's ear backs, tufts, the end of
##     its tail and the bars of its ruff);
##   - blue: how pale (the lynx's cream underside, lips, chin and eye rings);
##   - alpha: its spots: 0 to 0.5 solid spots (none to the strongest), 0.5 to
##     1 rosettes (a broken ring round a centre a little darker than the ground).
##   The spots themselves are worked out here, from where on the coat a point
##   is (cells in the coat's texture coordinates, which run in metres along and
##   across the lie of the hair), so they need no texture.
##   The lynx's fur is long and soft; the panther's short and sleek, with a
##   sheen along the lie of the hair that its rosettes do not have: that, and
##   their being a shade darker, is how they show in the black where the light
##   falls, and not in the shade.
## - PARTS: eyes, nose, teeth, gums, mouth, whiskers and the insides of its
##   ears, each in its own colour from the vertex colours, wet ones with a
##   hard glint. The eyes give the light back (`eyeshine`), the lynx's yellow,
##   the panther's green-gold: at night, two points in the dark.
##
## Nothing uses a texture, transparency or the screen.

## The colours of each coat (sRGB): the ground, the pale underside, the dark
## markings, the spots; the eyeshine.
const COATS := {
	BigCat.Kind.LYNX: {
		"albedo": Color(0.40, 0.345, 0.28), "pale": Color(0.74, 0.69, 0.60), "dark": Color(0.06, 0.055, 0.05),
		"spot": Color(0.17, 0.14, 0.11), "spot_size": 0.034, "spot_gain": 0.75,
		"fur_length": 0.015, "clump_tone": 0.2, "droop": 0.35, "sheen_gain": 0.04, "ghost": 0.0,
		"shine": Color(0.95, 0.85, 0.4),
	},
	BigCat.Kind.PANTHER: {
		"albedo": Color(0.05, 0.046, 0.045), "pale": Color(0.07, 0.064, 0.06), "dark": Color(0.02, 0.018, 0.017),
		"spot": Color(0.024, 0.021, 0.02), "spot_size": 0.062, "spot_gain": 1.0,
		"fur_length": 0.005, "clump_tone": 0.1, "droop": 0.15, "sheen_gain": 0.07, "ghost": 0.85,
		"shine": Color(0.62, 0.95, 0.42),
	},
}

static var _coat_shader: Shader
static var _parts_shader: Shader


## The coat's shader: the dog's (DogLook.COAT_SHADER) with a cat's markings.
static func coat_shader() -> Shader:
	if _coat_shader == null:
		_coat_shader = Shader.new()
		_coat_shader.code = DogLook.COAT_SHADER.replace(
			"uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);",
			"""uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);
// A cat's: its dark markings where the green of its vertex colour says, its
// spots where the alpha says (solid spots below a half, rosettes above).
uniform vec3 dark : source_color = vec3(0.06, 0.055, 0.05);
uniform float dark_gain = 0.95;
uniform vec3 spot : source_color = vec3(0.17, 0.14, 0.11);
uniform float spot_gain = 0.8;
// How big a spot's cell is (m), and how much less sheen the spots have than the rest.
uniform float spot_size = 0.035;
uniform float ghost = 0.0;
varying float spotted;""").replace(
			"float bareness(vec2 uv, vec2 uv2) {",
			"""// The nearest of the points scattered one to a cell round `p`: how far it is,
// and a number of its own.
vec2 cellular(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = vec2(hash(cell + o), hash(cell + o + 17.0));
			float d = length(o + 0.15 + h * 0.7 - f);
			if (d < best) {
				best = d;
				id = hash(cell + o + 31.0);
			}
		}
	}
	return vec2(best, id);
}

// How spotted it is here, 0..1: a solid spot, or (`rosette` 1) a broken ring
// round a centre a little darker than the ground.
float spots(vec2 uv, float rosette) {
	vec2 p = uv / spot_size;
	p += vec2(noise(p * 1.3), noise(p * 1.3 + 9.0)) * 0.45;
	vec2 c = cellular(p);
	float radius = mix(0.24, 0.40, c.y);
	float edge = max(fwidth(c.x), 0.02);
	float solid = 1.0 - smoothstep(radius - edge, radius + edge, c.x);
	float inner = radius * 0.62;
	float ring = smoothstep(inner - edge, inner + edge, c.x) * solid;
	float broken = smoothstep(0.3, 0.55, noise(p * 3.1 + c.y * 13.0));
	return mix(solid, max(ring * broken, 0.35 * solid), rosette);
}

float bareness(vec2 uv, vec2 uv2) {""").replace(
			"	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);",
			"""	float marked = clamp(COLOR.a, 0.0, 1.0);
	float rosette = step(0.5, marked);
	float strength = rosette > 0.5 ? (marked - 0.5) * 2.0 : marked * 2.0;
	spotted = spots(UV, rosette) * strength * spot_gain;
	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);
	base = mix(base, spot, spotted);
	base = mix(base, dark, clamp(COLOR.g, 0.0, 1.0) * dark_gain);""").replace(
			"	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;",
			"	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * (1.0 - spotted * ghost) * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;")
	return _coat_shader


## The parts' shader: the dog's (DogLook.PARTS_SHADER), a cat's pupil smaller.
static func parts_shader() -> Shader:
	if _parts_shader == null:
		_parts_shader = Shader.new()
		_parts_shader.code = DogLook.PARTS_SHADER.replace(
			"float pupil = 1.0 - smoothstep(0.42 - pixel, 0.42 + pixel, r);",
			"float pupil = 1.0 - smoothstep(0.30 - pixel, 0.30 + pixel, r);")
	return _parts_shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, parts), and says which is which: {"coat": the coat's skin layer (its
## shells hang off it as `next_pass`), "parts"}. `coat_tint` multiplies the
## coat's colours; `shells` is how many layers of fur stand off it.
static func dress(model: Node, kind: BigCat.Kind, coat_tint := Color.WHITE, shells := 2, eyeshine := 0.6) -> Dictionary:
	var made := {}
	var look: Dictionary = COATS[kind]
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material: ShaderMaterial
			if String(original.resource_name) == "coat":
				material = coat_material(kind, coat_tint, shells)
			else:
				material = ShaderMaterial.new()
				material.shader = parts_shader()
				material.set_shader_parameter(&"eyeshine", eyeshine)
				material.set_shader_parameter(&"shine", look["shine"])
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


## A furred coat for `kind`, with `shells` layers of fur.
static func coat_material(kind: BigCat.Kind, tint := Color.WHITE, shells := 2) -> ShaderMaterial:
	var skin := _layer(kind, 0.0, tint)
	var under := skin
	for i in shells:
		var layer := _layer(kind, float(i + 1) / shells, tint)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(kind: BigCat.Kind, shell: float, tint: Color) -> ShaderMaterial:
	var look: Dictionary = COATS[kind]
	var material := ShaderMaterial.new()
	material.shader = coat_shader()
	material.set_shader_parameter(&"albedo", (look["albedo"] as Color) * tint)
	material.set_shader_parameter(&"pale", (look["pale"] as Color) * tint)
	material.set_shader_parameter(&"dark", look["dark"])
	material.set_shader_parameter(&"spot", (look["spot"] as Color) * tint)
	material.set_shader_parameter(&"spot_size", look["spot_size"])
	material.set_shader_parameter(&"spot_gain", look["spot_gain"])
	material.set_shader_parameter(&"ghost", look["ghost"])
	material.set_shader_parameter(&"pale_gain", 0.9)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mange", 0.0)
	material.set_shader_parameter(&"fur_length", look["fur_length"])
	material.set_shader_parameter(&"clump_tone", look["clump_tone"])
	material.set_shader_parameter(&"droop", look["droop"])
	material.set_shader_parameter(&"sheen_gain", look["sheen_gain"])
	material.set_shader_parameter(&"sheen_gloss", 14.0)
	material.set_shader_parameter(&"crease", 0.55)
	material.set_shader_parameter(&"clumps", Vector2(44.0, 16.0))
	material.set_shader_parameter(&"sheen", Color(0.32, 0.34, 0.38) if kind == BigCat.Kind.PANTHER else Color(0.6, 0.62, 0.66))
	material.set_shader_parameter(&"streak", 0.06 if kind == BigCat.Kind.PANTHER else 0.12)
	return material
