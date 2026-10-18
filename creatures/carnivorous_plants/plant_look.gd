class_name PlantLook
## How the giant carnivorous plants are shaded, and their models (made by
## tools/build_plants.py). One shader for them all, cel shaded in hard bands as
## the figures are (after Toon), its colours the model's own (vertex colours):
##
## - WET where the model says (UV x): nectar, glue, a slippery lip, black fluid.
##   The light glints off it in a small hard spot and a thin sheen at its edges,
##   so it glistens as you move: the sweet glisten that draws things in.
## - GRIP: anything with tentacles (UV y, how far up one a point is) bends them
##   over `grip_point` (in the model's space) as `grip` rises, and the leaves (UV2
##   x, how far along one a point is) curl in over it a little.
## - It fades out past `far` (the mist has it by then), and sways a very little.

const FLYTRAP := "res://creatures/carnivorous_plants/models/flytrap.glb"
const FLYTRAP_LO := "res://creatures/carnivorous_plants/models/flytrap_lo.glb"
const SUNDEW := "res://creatures/carnivorous_plants/models/sundew.glb"
const SUNDEW_LO := "res://creatures/carnivorous_plants/models/sundew_lo.glb"
const PITCHER := "res://creatures/carnivorous_plants/models/pitcher.glb"
const PITCHER_LO := "res://creatures/carnivorous_plants/models/pitcher_lo.glb"
## Where the pitcher's lid is hinged, in its model (from build_plants.py).
const LID_HINGE := Vector3(0.0, 0.89, -0.71)
## How far the lid is held up from shut, as it is modelled, radians.
const LID_OPEN := 1.05

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.1;
uniform float flatness = 0.65;
uniform float rim_gain = 0.25;
uniform float rim_width = 0.16;
// The glint off what is wet: how bright, how small, and the sheen at its edges.
uniform float glint = 1.1;
uniform float gloss = 60.0;
uniform float sheen = 0.12;
// Bending tentacles and curling leaves over what is held (the model's space).
uniform vec3 grip_point = vec3(0.0, 0.0, 0.0);
uniform float grip = 0.0;
uniform float grip_reach = 1.6;
uniform float sway = 0.015;
// Shading itself darker (a trap gone dull as it digests), 0..1.
uniform float dull = 0.0;

varying float wet;
varying vec3 spot;

void vertex() {
	wet = UV.x;
	spot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float up = UV.y;
	float along = UV2.x;
	vec3 to = grip_point - VERTEX;
	float near = 1.0 - smoothstep(grip_reach * 0.4, grip_reach, length(to));
	// (the tentacles lean over to it; the leaf under them curls up towards it)
	VERTEX += normalize(to + vec3(0.0, 0.0001, 0.0)) * grip * near * (up * 0.11 + along * 0.3 * (1.0 - up));
	float t = TIME * 0.7 + VERTEX.x * 0.5 + VERTEX.z * 0.4;
	VERTEX.xz += vec2(sin(t), cos(t * 1.3)) * sway * (along + up * 0.4);
}

float hash(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

varying float glitter;

void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - 0.45 * dull);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// (a drop glints all over; a wet surface only in beads of nectar here and there on it)
	glitter = wet > 0.95 ? 1.0 : step(0.9, hash(spot * 30.0)) * wet;
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
	float rim = cut(graze, 1.0 - rim_width) * lit;
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	float edge = cut(graze, 0.72) * sheen * smoothstep(0.5, 0.9, wet);
	float beads = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 18.0), 0.5) * glitter;
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + (shine * glint * wet * 0.5 + beads * glint + edge * wet) * (0.35 + 0.65 * lit)) * strength * LIGHT_COLOR / PI;
}
"""

static var _shader: Shader
static var _meshes := {}


## A material for one plant (each its own, so that its grip is its own).
static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	return made


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


## A part of a model drawn with `with`, faded out past `far` metres.
static func part(path: String, name: String, with: Material, far := 90.0) -> MeshInstance3D:
	var shown := MeshInstance3D.new()
	shown.name = name
	shown.mesh = meshes(path).get(name)
	shown.material_override = with
	shown.visibility_range_end = far
	shown.visibility_range_end_margin = 10.0
	shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return shown


## A sound made in code, mono 22050 Hz, from samples (any loudness: it is made to fill 16 bits).
static func wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 30000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = 22050
	made.data = data
	return made
