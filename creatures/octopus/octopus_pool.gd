class_name OctopusPool
extends MeshInstance3D
## The octopus's water: a pool of black water lying on the ground, wider than
## a hall is long is not (a few metres across), its middle deep and lightless,
## its edge ragged with wet black mud. Rings spread over it from wherever it is
## stirred (`stir`: an arm coming up out of it, the octopus breathing down
## there), and the sky shows on it dimly at a low angle. One draw. It does no
## hiding itself: whatever goes down into it goes down into the ground, which
## hides it (so the ground must be drawn, opaque, under it).
##
##     var pool := OctopusPool.new()
##     pool.radius = 3.0
##     add_child(pool)
##     pool.global_position = on_the_ground
##     pool.stir(point, 1.0)

@export var radius := 3.0
@export var water := Color(0.025, 0.032, 0.034)
@export var sky := Color(0.48, 0.52, 0.54)
@export var mud := Color(0.075, 0.068, 0.058)
@export var shape_seed := 1

const RINGS := 6
const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 water : source_color;
uniform vec3 sky : source_color;
uniform vec3 mud : source_color;
uniform vec4 stirs[6];
uniform float now = 0.0;
uniform float radius = 3.0;

varying vec3 place;
varying float rim;

void vertex() {
	place = VERTEX;
	rim = UV.x;
}

void fragment() {
	// UV.x: 0 in the middle, 1 at the outer edge of the mud.
	float wet = 1.0 - smoothstep(0.66, 0.74, rim);
	float ring = 0.0;
	for (int i = 0; i < 6; i++) {
		vec4 s = stirs[i];
		float age = now - s.z;
		if (s.w <= 0.0 || age < 0.0 || age > 5.0) {
			continue;
		}
		float far = length(place.xz - s.xy);
		float front = age * 0.7;
		float wave = sin((far - front) * 18.0) * exp(-pow((far - front) / 0.3, 2.0)) * smoothstep(0.0, 0.1, far);
		ring += wave * s.w * exp(-age * 0.9);
	}
	// (a slow swell over it all, as something breathes down there)
	ring += 0.12 * sin(length(place.xz) * 5.0 - now * 1.1) * smoothstep(0.1, 0.5, rim) * wet;
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float low = pow(1.0 - clamp(abs(view.y), 0.0, 1.0), 4.0);
	// (the middle is deep: darker than the shallows near the edge)
	vec3 deep = water * mix(0.55, 1.0, smoothstep(0.1, 0.6, rim));
	vec3 colour = mix(deep, sky, clamp(low * 0.5 + ring * 0.22 + 0.03, 0.0, 1.0));
	colour += vec3(0.6) * smoothstep(0.35, 0.55, ring) * 0.3;
	colour = mix(mud, colour, wet);
	ALBEDO = colour;
	ALPHA = 1.0 - smoothstep(0.84, 1.0, rim);
}
"""

static var _shader: Shader
var _stirs: Array[Vector4] = []
var _next := 0
var _material: ShaderMaterial
var _clock := 0.0


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"water", water)
	_material.set_shader_parameter(&"sky", sky)
	_material.set_shader_parameter(&"mud", mud)
	_material.set_shader_parameter(&"radius", radius)
	for i in RINGS:
		_stirs.append(Vector4(0.0, 0.0, -100.0, 0.0))
	_material.set_shader_parameter(&"stirs", _stirs)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _make()


## Sends rings out over it from `at` (in the world), `strength` 0..1.
func stir(at: Vector3, strength := 1.0) -> void:
	if _material == null:
		return
	var local := to_local(at)
	_stirs[_next] = Vector4(local.x, local.z, _clock, clampf(strength, 0.0, 1.0))
	_next = (_next + 1) % RINGS
	_material.set_shader_parameter(&"stirs", _stirs)


func _process(delta: float) -> void:
	_clock += delta
	if _material:
		_material.set_shader_parameter(&"now", _clock)


## A disc with a wandering edge, a little above the ground, and a ring of mud round it.
func _make() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var lumps: Array[Vector3] = []
	for k in 6:
		lumps.append(Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.03, 0.09), float(k + 2)))
	var around := 56
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3(0.0, 0.03, 0.0))
	uvs.append(Vector2(0.0, 0.0))
	var bands := [0.3, 0.6, 0.72, 0.86, 1.0]
	for band: float in bands:
		for j in around:
			var a := TAU * j / around
			var out := 1.0
			for lump in lumps:
				out += lump.y * sin(a * lump.z + lump.x)
			var r := radius * out * band
			vertices.append(Vector3(cos(a) * r, 0.03 - 0.015 * smoothstep(0.7, 1.0, band), sin(a) * r))
			uvs.append(Vector2(band * 0.7 / 0.72 if band <= 0.72 else 0.7 + (band - 0.72) / 0.28 * 0.3, 0.0))
	for j in around:
		indices.append_array([0, 1 + (j + 1) % around, 1 + j])
	for b in bands.size() - 1:
		var inner := 1 + b * around
		var outer := 1 + (b + 1) * around
		for j in around:
			var n := (j + 1) % around
			indices.append_array([inner + j, inner + n, outer + j, inner + n, outer + n, outer + j])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made
