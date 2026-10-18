class_name SporeCloud
extends Node3D
## A puff of spores out of a puffball: a burst of olive-brown dust that billows
## out and up, hangs in the air a few seconds, and settles and thins away. One
## MultiMesh of soft round puffs that face the camera (one draw), moved only
## while it is out.
##
##     var cloud := SporeCloud.new()
##     add_child(cloud)
##     cloud.puff(pore, 1.0)            # out of a pore there (world), as big as `size`
##     cloud.density_at(point)          # 0..1: how thick it is at a point (world), for what it does to you
##     cloud.active()                   # whether it is out

## How long a cloud hangs about, seconds, and how wide it billows, metres (at size 1).
const LIFETIME := 7.0
const WIDTH := 3.2
## How many puffs it is drawn with.
const PUFFS := 48
const COLOUR := Color(0.6, 0.56, 0.42)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 fog_tint : source_color = vec3(0.66, 0.68, 0.7);

void vertex() {
	// (each puff faces the camera, keeping its own size)
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 at = UV * 2.0 - 1.0;
	float round_puff = 1.0 - smoothstep(0.15, 1.0, length(at));
	// (a little lumpy, so the puffs read as dust rather than discs)
	float lumps = 0.75 + 0.25 * sin(at.x * 7.0 + COLOR.b * 20.0) * sin(at.y * 6.0 + COLOR.r * 17.0);
	ALBEDO = COLOR.rgb;
	ALPHA = round_puff * lumps * COLOR.a;
}
"""

static var _shader: Shader
var age := LIFETIME
var size := 1.0
var origin := Vector3.ZERO

var _multi: MultiMesh
var _shown: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _at: Array[Vector3] = []
var _going: Array[Vector3] = []
var _grow: Array[float] = []


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_multi.instance_count = PUFFS
	_shown = MultiMeshInstance3D.new()
	_shown.multimesh = _multi
	_shown.material_override = material
	_shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shown.top_level = true
	_shown.custom_aabb = AABB(Vector3(-8.0, -2.0, -8.0), Vector3(16.0, 8.0, 16.0))
	add_child(_shown)
	_at.resize(PUFFS)
	_going.resize(PUFFS)
	_grow.resize(PUFFS)
	_shown.visible = false
	set_process(false)


## Billows out of a pore at `at` (world), `how_big` times the size of a puffball's.
func puff(at: Vector3, how_big := 1.0) -> void:
	origin = at
	size = how_big
	age = 0.0
	_rng.seed = hash(at)
	_shown.global_transform = Transform3D.IDENTITY
	for i in PUFFS:
		_at[i] = at + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.1, 0.1))
		var round_about := _rng.randf() * TAU
		var out := _rng.randf_range(0.3, 1.0)
		_going[i] = Vector3(cos(round_about) * out, _rng.randf_range(0.5, 2.0), sin(round_about) * out) * 2.6 * how_big
		_grow[i] = _rng.randf_range(0.6, 1.3)
	_shown.visible = true
	set_process(true)
	_place(0.0)


func active() -> bool:
	return age < LIFETIME


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		_shown.visible = false
		set_process(false)
		return
	_place(delta)


func _place(delta: float) -> void:
	var t := age / LIFETIME
	for i in PUFFS:
		# (thrown out, slowed by the air, then drifting and sinking)
		_going[i] = _going[i] * exp(-2.4 * delta) + Vector3(0.0, -0.12 * delta, 0.0)
		_at[i] += _going[i] * delta
		var puff_size := (0.25 + 1.0 * sqrt(clampf(age / 2.5, 0.0, 1.0))) * _grow[i] * size
		var basis := Basis.from_scale(Vector3.ONE * puff_size)
		_multi.set_instance_transform(i, Transform3D(basis, _at[i]))
		var alpha := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.35, 1.0, t)) * 0.42
		_multi.set_instance_color(i, Color(COLOUR.r * (0.9 + 0.1 * _grow[i]), COLOUR.g, COLOUR.b, alpha))


## How thick it is at `point` (world): 0 (none) to 1 (in the heart of a fresh one).
func density_at(point: Vector3) -> float:
	if age >= LIFETIME:
		return 0.0
	var reach := lerpf(0.6, WIDTH, smoothstep(0.0, 1.6, age)) * size
	var middle := origin + Vector3.UP * minf(age * 0.35, 1.0) * size
	var apart := point.distance_to(middle)
	var fresh := 1.0 - smoothstep(0.3, 1.0, age / LIFETIME)
	return fresh * (1.0 - smoothstep(reach * 0.55, reach, apart))
