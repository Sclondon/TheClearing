class_name CoyoteLook
## What a coyote (Coyote, creatures/coyote/coyote.gd) is drawn with: the dog's
## three materials (DogLook: a furred coat, a crest that bristles, and the
## vertex-coloured parts with eyeshine), its coat recoloured as a coyote's.
##
## A coyote's coat is grizzled: each guard hair is banded pale and dark, and
## some are tipped black, so up close it is a speckle of grey, buff and black,
## and from further off a grey-tan. Its model (tools/build_coyote.py) paints
## its markings into the coat's vertex colours, which this shader reads:
## - red: how open the surface is (dark in creases, as the dog's);
## - green: how dark its markings are (the saddle down its back, the line down
##   the front of each foreleg, the rims of its ears, the end of its tail);
## - blue: how pale (the cream of its throat, chest, belly and lips);
## - alpha: how tawny (its legs, the backs of its ears, its muzzle).
## The fur is longer than the dog's, and none of it is bare.
##
## Nothing uses a texture, transparency or the screen.

## The colours of a coyote's coat (sRGB), as the model's base colour is tinted.
const PALE := Color(0.75, 0.69, 0.58)
const TAWNY := Color(0.64, 0.43, 0.24)
const DARK := Color(0.085, 0.075, 0.065)

static var _coat_shader: Shader


## The coat's shader: the dog's (DogLook.COAT_SHADER) with the coyote's colouring.
static func coat_shader() -> Shader:
	if _coat_shader == null:
		_coat_shader = Shader.new()
		_coat_shader.code = DogLook.COAT_SHADER.replace(
			"uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);",
			"""uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);
// A coyote's: tawny where the alpha of its vertex colour says, its dark markings
// where the green says; and the grizzle of banded guard hairs over the rest.
uniform vec3 tawny : source_color = vec3(0.64, 0.43, 0.24);
uniform vec3 dark : source_color = vec3(0.085, 0.075, 0.065);
uniform float tawny_gain = 0.85;
uniform float dark_gain = 0.9;
uniform float grizzle = 0.55;
uniform float grizzle_size = 0.35;""").replace(
			"	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);",
			"""	float paleness = clamp(COLOR.b, 0.0, 1.0) * pale_gain;
	vec3 base = mix(albedo, tawny, clamp(COLOR.a, 0.0, 1.0) * tawny_gain);
	// (banded guard hairs: here a pale band, there a black tip, in streaks along the lie)
	float band = noise(vec2(UV.y * strands * grizzle_size, UV.x * strands * grizzle_size * 0.22));
	float tipped = smoothstep(0.62, 0.8, noise(vec2(UV.y * strands * grizzle_size * 0.6 + 7.0, UV.x * strands * grizzle_size * 0.15)));
	base *= mix(1.0, mix(0.6, 1.4, band) * mix(1.0, 0.35, tipped), grizzle * (1.0 - paleness));
	base = mix(base, pale, paleness);
	base = mix(base, dark, clamp(COLOR.g, 0.0, 1.0) * dark_gain);""")
	return _coat_shader


## Gives every surface of `model` its material (see DogLook.dress), the coat a
## coyote's: {"coat": its skin layer (the shells hang off it as `next_pass`),
## "crest", "parts"}. `coat_tint` multiplies the coat's colours (one a little
## greyer or redder than the next).
static func dress(model: Node, coat_tint := Color.WHITE, shells := 2, eyeshine := 0.5) -> Dictionary:
	var made := DogLook.dress(model, coat_tint, shells, 0.0, eyeshine)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and String(original.resource_name) == "coat":
				var coat := coat_material(original.albedo_color * coat_tint, shells, coat_tint)
				made["coat"] = coat
				part.set_surface_override_material(surface, coat)
	return made


## A furred coyote coat in `colour` (the grey-tan of its back), with `shells` layers of fur.
static func coat_material(colour: Color, shells := 2, tint := Color.WHITE) -> ShaderMaterial:
	var skin := _layer(colour, 0.0, tint)
	var under := skin
	for i in shells:
		var layer := _layer(colour, float(i + 1) / shells, tint)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, shell: float, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = coat_shader()
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"pale", PALE * tint)
	material.set_shader_parameter(&"tawny", TAWNY * tint)
	material.set_shader_parameter(&"dark", DARK)
	material.set_shader_parameter(&"pale_gain", 0.92)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mange", 0.0)
	material.set_shader_parameter(&"fur_length", 0.022)
	material.set_shader_parameter(&"clump_tone", 0.3)
	material.set_shader_parameter(&"droop", 0.4)
	return material
