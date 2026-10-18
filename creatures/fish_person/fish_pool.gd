class_name FishPool
extends MeshInstance3D
## A pool of still black water lying on the ground, a few metres across, with
## a ragged edge of wet mud round it: where a fish person lurks (`FishPerson`,
## given it as its `pool`, sinks into it until only its eyes show, and rises out
## of it). Rings spread out over it from wherever it is stirred (`stir`), and
## it shows the sky dimly at a low angle. One draw; it does no hiding itself:
## whatever goes down into it goes down into the ground, which hides it.
##
##     var pool := FishPool.new()
##     pool.radius = 1.7
##     add_child(pool)
##     pool.global_position = on_the_ground
##     pool.stir(point, 1.0)       # rings out from a point on it, as strong as said (0..1)

## How far it reaches from its middle, world units (its edge wanders in and out of this).
@export var radius := 1.7
## Its water, and the sky it shows at a low angle.
@export var water := Color(0.035, 0.045, 0.045)
@export var sky := Color(0.5, 0.55, 0.56)
## The wet mud round its edge.
@export var mud := Color(0.09, 0.08, 0.065)
## A number that settles the shape of its edge.
@export var shape_seed := 1

const RINGS := 4
const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec3 water : source_color;
uniform vec3 sky : source_color;
uniform vec3 mud : source_color;
// Where rings are going out from (x, z on it, from its middle), when each began, and how strong.
uniform vec4 stirs[4];
uniform float now = 0.0;

varying vec3 place;
varying float rim;

void vertex() {
	place = VERTEX;
	rim = UV.x;
}

void fragment() {
	// UV.x: 0 in the middle, 1 at the outer edge of the mud.
	float wet = 1.0 - smoothstep(0.62, 0.7, rim);
	float ring = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 s = stirs[i];
		float age = now - s.z;
		if (s.w <= 0.0 || age < 0.0 || age > 4.0) {
			continue;
		}
		float far = length(place.xz - s.xy);
		float front = age * 0.55;
		float wave = sin((far - front) * 26.0) * exp(-pow((far - front) / 0.22, 2.0)) * smoothstep(0.0, 0.08, far);
		ring += wave * s.w * exp(-age * 1.1);
	}
	vec3 view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float low = pow(1.0 - clamp(abs(view.y), 0.0, 1.0), 4.0);
	vec3 colour = mix(water, sky, clamp(low * 0.55 + ring * 0.25 + 0.04, 0.0, 1.0));
	colour += vec3(0.6) * smoothstep(0.35, 0.5, ring) * 0.35;
	colour = mix(mud, colour, wet);
	ALBEDO = colour;
	ALPHA = 1.0 - smoothstep(0.82, 1.0, rim);
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
	for k in 5:
		lumps.append(Vector3(rng.randf_range(0.0, TAU), rng.randf_range(0.03, 0.08), float(k + 2)))
	var around := 40
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3(0.0, 0.025, 0.0))
	uvs.append(Vector2(0.0, 0.0))
	var bands := [0.45, 0.68, 0.84, 1.0]
	for band: float in bands:
		for j in around:
			var a := TAU * j / around
			var out := 1.0
			for lump in lumps:
				out += lump.y * sin(a * lump.z + lump.x)
			var r := radius * out * band
			vertices.append(Vector3(cos(a) * r, 0.025 - 0.012 * smoothstep(0.7, 1.0, band), sin(a) * r))
			uvs.append(Vector2(band * 0.7 if band <= 0.68 else 0.7 + (band - 0.68) / 0.32 * 0.3, 0.0))
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
