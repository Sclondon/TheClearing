class_name FoxLook
## What a red fox (Fox, creatures/fox/fox.gd) is drawn with: the dog's three
## materials (DogLook: a furred coat, a crest that bristles, and the
## vertex-coloured parts with eyeshine), its coat recoloured as a fox's.
##
## A fox's coat is rust red, deepest down the back, ginger on the flanks and
## cheeks, with white and black markings that are sharp-edged where a coyote's
## blur. Its model (tools/build_fox.py) paints them into the coat's vertex
## colours, which this shader reads:
## - red: how open the surface is (dark in creases, as the dog's);
## - green: how dark (black): its stockings, the backs of its ears, the line
##   from each eye down its muzzle, the dusky top of its brush;
## - blue: how pale (white): its lips, chin, throat and bib, the greyish belly,
##   the tip of its brush;
## - alpha: how ginger (the paler orange of its flanks and cheeks).
## The fur is long and soft (longest on the brush), with a faint grizzle of
## darker-tipped guard hairs over the red; none of it is bare.
##
## Nothing uses a texture, transparency or the screen.

## The colours of a fox's coat (sRGB), as the model's base colour (the rust of
## its back) is tinted.
const PALE := Color(0.78, 0.76, 0.70)
const GINGER := Color(0.56, 0.32, 0.13)
const DARK := Color(0.055, 0.045, 0.04)

static var _coat_shader: Shader


## The coat's shader: the dog's (DogLook.COAT_SHADER) with the fox's colouring.
static func coat_shader() -> Shader:
	if _coat_shader == null:
		_coat_shader = Shader.new()
		_coat_shader.code = DogLook.COAT_SHADER.replace(
			"uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);",
			"""uniform vec3 pale : source_color = vec3(0.42, 0.37, 0.31);
// A fox's: ginger where the alpha of its vertex colour says, black where the
// green says; and a faint grizzle of dark-tipped guard hairs over the red.
uniform vec3 ginger : source_color = vec3(0.56, 0.32, 0.13);
uniform vec3 dark : source_color = vec3(0.055, 0.045, 0.04);
uniform float ginger_gain = 0.8;
uniform float dark_gain = 0.95;
uniform float grizzle = 0.3;
uniform float grizzle_size = 0.35;""").replace(
			"	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);",
			"""	float paleness = clamp(COLOR.b, 0.0, 1.0) * pale_gain;
	vec3 base = mix(albedo, ginger, clamp(COLOR.a, 0.0, 1.0) * ginger_gain);
	// (dark-tipped guard hairs, in streaks along the lie, on the red only)
	float tipped = smoothstep(0.66, 0.84, noise(vec2(UV.y * strands * grizzle_size * 0.6 + 7.0, UV.x * strands * grizzle_size * 0.15)));
	base *= mix(1.0, 0.55, tipped * grizzle * (1.0 - paleness));
	base = mix(base, pale, paleness);
	base = mix(base, dark, clamp(COLOR.g, 0.0, 1.0) * dark_gain);""")
	return _coat_shader


## Gives every surface of `model` its material (see DogLook.dress), the coat a
## fox's: {"coat": its skin layer (the shells hang off it as `next_pass`),
## "crest", "parts"}. `coat_tint` multiplies the coat's colours (one a little
## redder or paler than the next).
static func dress(model: Node, coat_tint := Color.WHITE, shells := 2, eyeshine := 0.6) -> Dictionary:
	var made := DogLook.dress(model, coat_tint, shells, 0.0, eyeshine)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and String(original.resource_name) == "coat":
				var coat := coat_material(original.albedo_color * coat_tint, shells, coat_tint)
				made["coat"] = coat
				part.set_surface_override_material(surface, coat)
	return made


## A furred fox coat in `colour` (the rust of its back), with `shells` layers of fur.
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
	material.set_shader_parameter(&"pale", PALE)
	material.set_shader_parameter(&"ginger", GINGER * tint)
	material.set_shader_parameter(&"dark", DARK)
	material.set_shader_parameter(&"pale_gain", 0.95)
	material.set_shader_parameter(&"shell", shell)
	material.set_shader_parameter(&"mange", 0.0)
	material.set_shader_parameter(&"fur_length", 0.026)
	material.set_shader_parameter(&"clump_tone", 0.22)
	material.set_shader_parameter(&"droop", 0.45)
	material.set_shader_parameter(&"crease", 0.6)
	return material
