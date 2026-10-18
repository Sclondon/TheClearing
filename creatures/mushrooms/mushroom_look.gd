class_name MushroomLook
## How the mushrooms are shaded, and their models (made by
## tools/build_mushrooms.py): cel shaded in hard bands as the figures are (after
## Toon), their colours the model's own (vertex colours), damp and matt.
##
## - GLOW: in the dark they glow (foxfire): the bonnets' caps and stems
##   wholly, the gills of the rest faintly (UV x says how much). `night` (0 by
##   day, 1 at night) is how much.
## - SQUASH: drawn as a MultiMesh, each one's custom data (red) squashes it
##   flat and wide (a puffball as it puffs); green sways it.
## - It fades out past the patch's `far` (the mist has it by then).

const MODELS := "res://creatures/mushrooms/models/mushrooms.glb"
const MODELS_LO := "res://creatures/mushrooms/models/mushrooms_lo.glb"
const GROWTHS := "res://creatures/mushrooms/models/growths.glb"
const GROWTHS_LO := "res://creatures/mushrooms/models/growths_lo.glb"
## The foxfire's colour.
const GLOW := Color(0.55, 0.8, 0.62)

const SHADER := """
shader_type spatial;

uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.2;
uniform float rim_width = 0.18;
uniform float night = 0.0;
uniform vec3 glow_colour : source_color = vec3(0.55, 0.8, 0.62);
uniform float glow_gain = 1.2;
// Drawn one by one (not a MultiMesh): how squashed, and how much it sways.
uniform float squash = 0.0;
uniform float sway = 0.0;

varying float glow;

void vertex() {
	glow = UV.x;
	float up = UV.y;
	float squashed = squash + INSTANCE_CUSTOM.r;
	float swing = sway + INSTANCE_CUSTOM.g;
	VERTEX.y *= 1.0 - 0.6 * squashed;
	VERTEX.xz *= 1.0 + 0.35 * squashed;
	float t = TIME * 1.3 + NODE_POSITION_WORLD.x * 0.7 + INSTANCE_CUSTOM.b * 6.28;
	VERTEX.xz += vec2(sin(t), cos(t * 0.8)) * swing * up * up * 0.02;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = glow_colour * glow * night * glow_gain;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 1.0 - rim_width) * lit * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader
static var _shared: ShaderMaterial
static var _meshes := {}


## A material of its own (for one that glows or squashes alone).
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	return made


## The one material every patch shares (so one setting of `night` lights them all).
static func shared() -> ShaderMaterial:
	if _shared == null:
		_shared = material()
	return _shared


## How dark it is, for the glow: 0 by day, 1 at night (every patch, and every zombie's growths).
static func set_night(value: float) -> void:
	shared().set_shader_parameter(&"night", value)


## The meshes in a model, by name (each model is loaded once).
static func meshes(path: String) -> Dictionary:
	if _meshes.has(path):
		return _meshes[path]
	var found := {}
	var scene := (load(path) as PackedScene).instantiate()
	for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		found[String(part.name)] = part.mesh
	scene.free()
	_meshes[path] = found
	return found


static func mesh(name: String, low := false) -> Mesh:
	return meshes(MODELS_LO if low or Settings.low_poly else MODELS).get(name)


static func growth(name: String, low := false) -> Mesh:
	return meshes(GROWTHS_LO if low or Settings.low_poly else GROWTHS).get(name)
