class_name WolfLook
## What a grey wolf (Wolf, creatures/wolf/wolf.gd) is drawn with: the dog's
## three materials (DogLook: a furred coat, a crest that bristles, and the
## vertex-coloured parts with eyeshine), its coat recoloured as a wolf's.
##
## A grey wolf's coat is grizzled: each long guard hair is banded pale and
## dark and many are tipped black, so up close it is a speckle of grey, cream
## and black, and from further off a cool grey. Its model
## (tools/build_wolf.py) paints its markings into the coat's vertex colours,
## which this shader reads:
## - red: how open the surface is (dark in creases, as the dog's);
## - green: how dark its markings are (the saddle over its back and down its
##   tail, the mane along its nape, the line from each eye, the bridge of the
##   nose, the rims of its ears, the end of its tail);
## - blue: how pale (the cream of its mask: lips, the sides of the muzzle,
##   cheeks, a spot over each eye; and its throat, chest, belly, the insides of
##   its legs);
## - alpha: how buff (its legs, the backs of its ears, the top of the muzzle).
## The fur is the longest of the dogs', lies loosely, and none of it is bare.
##
## Nothing uses a texture, transparency or the screen.

## The colours of a wolf's coat (sRGB), as the model's base colour is tinted.
const PALE := Color(0.70, 0.68, 0.63)
const BUFF := Color(0.58, 0.52, 0.42)
const DARK := Color(0.07, 0.066, 0.062)

static var _coat_shader: Shader


## The coat's shader: the dog's (DogLook.COAT_SHADER) with the wolf's colouring.
static func coat_shader() -> Shader:
	if _coat_shader == null:
		_coat_shader = Shader.new()
		_coat_shader.code = DogLook.COAT_SHADER.replace(
			"uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);",
			"""uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);
// A wolf's: buff where the alpha of its vertex colour says, its dark markings
// where the green says; and the grizzle of banded, black-tipped guard hairs over the rest.
uniform vec3 buff : source_color = vec3(0.58, 0.52, 0.42);
uniform vec3 dark : source_color = vec3(0.07, 0.066, 0.062);
uniform float buff_gain = 0.8;
uniform float dark_gain = 0.85;
uniform float grizzle = 0.6;
uniform float grizzle_size = 0.3;""").replace(
			"	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);",
			"""	float paleness = clamp(COLOR.b, 0.0, 1.0) * pale_gain;
	vec3 base = mix(albedo, buff, clamp(COLOR.a, 0.0, 1.0) * buff_gain);
	// (banded guard hairs: here a pale band, there a black tip, in streaks along the lie;
	// more black tips where it is darker, as over the saddle)
	float band = noise(vec2(UV.y * strands * grizzle_size, UV.x * strands * grizzle_size * 0.2));
	float darkness = clamp(COLOR.g, 0.0, 1.0);
	float tipped = smoothstep(0.62 - 0.25 * darkness, 0.8 - 0.2 * darkness, noise(vec2(UV.y * strands * grizzle_size * 0.6 + 7.0, UV.x * strands * grizzle_size * 0.14)));
	base *= mix(1.0, mix(0.7, 1.28, band) * mix(1.0, 0.3, tipped), grizzle * (1.0 - paleness * 0.8));
	base = mix(base, pale * mix(0.9, 1.05, band), paleness);
	base = mix(base, dark * mix(0.8, 2.2, band), darkness * dark_gain * mix(0.6, 1.0, tipped));""")
	return _coat_shader


## Gives every surface of `model` its material (see DogLook.dress), the coat a
## wolf's: {"coat": its skin layer (the shells hang off it as `next_pass`),
## "crest", "parts"}. `coat_tint` multiplies the coat's colours (one a little
## greyer, darker or warmer than the next).
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


## A furred wolf's coat in `colour` (the grey of its flanks), with `shells` layers of fur.
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
	material.set_shader_parameter(&"buff", BUFF * tint)
	material.set_shader_parameter(&"dark", DARK)
	material.set_shader_parameter(&"pale_gain", 0.85)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mange", 0.0)
	# (long, loose fur: the guard hairs stand off it further than a coyote's)
	material.set_shader_parameter(&"fur_length", 0.02)
	material.set_shader_parameter(&"clumps", Vector2(26.0, 9.0))
	material.set_shader_parameter(&"clump_tone", 0.28)
	material.set_shader_parameter(&"droop", 0.45)
	material.set_shader_parameter(&"face_length", 0.3)
	return material
