class_name SmokeColumn
extends MultiMeshInstance3D
## Smoke going up from a campfire, high enough to be seen over the grass and the
## mist from far across the clearing: a column of soft grey puffs that rise,
## swell, lean away on the wind and thin out. One draw (a MultiMesh of flat
## puffs turned to the camera), and every puff is moved in its shader, so it
## costs the script nothing a frame.
##
##     var smoke := SmokeColumn.new()
##     smoke.height = 26.0
##     fire_node.add_child(smoke)

## How high it goes before it has thinned away, metres, and how wide the puffs
## are at the foot and at the top.
@export var height := 38.0
@export var width := Vector2(1.0, 9.0)
## How many puffs, how fast they rise (m/s), and the wind they lean on (level, m/s).
@export var puffs := 22
@export var rise := 1.6
@export var wind := Vector2(1.1, 0.4)
## Its colour, and how much of it there is (0..1).
@export var colour := Color(0.42, 0.42, 0.42)
@export_range(0.0, 1.0) var thickness := 0.7

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float height = 38.0;
uniform vec2 width = vec2(1.0, 9.0);
uniform float rise = 1.6;
uniform vec2 wind = vec2(1.1, 0.4);
uniform vec4 colour : source_color = vec4(0.42, 0.42, 0.42, 1.0);
uniform float thickness = 0.55;
uniform vec4 mist : source_color = vec4(0.62, 0.64, 0.64, 1.0);
uniform float mist_far = 420.0;
varying float v_age;
varying float v_seed;
varying float v_far;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float life = height / rise;
	float age = fract(TIME / life + seed);
	v_age = age;
	v_seed = seed;
	float up = age * height;
	// (leaning off on the wind more the higher it goes, and wandering)
	vec3 centre = vec3(wind.x * life * age * age * 0.5, up, wind.y * life * age * age * 0.5);
	centre.x += sin(TIME * 0.3 + seed * 17.0) * age * 2.0;
	centre.z += cos(TIME * 0.23 + seed * 11.0) * age * 2.0;
	float size = mix(width.x, width.y, pow(age, 0.7));
	// turned to face the camera
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 upv = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world_centre = (MODEL_MATRIX * vec4(centre, 1.0)).xyz;
	float spin = seed * 6.28 + TIME * 0.1 * (seed - 0.5);
	vec2 corner = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * VERTEX.xy;
	vec3 world = world_centre + (right * corner.x + upv * corner.y) * size;
	v_far = length(world - CAMERA_POSITION_WORLD);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV - 0.5;
	float n = noise(UV * 4.0 + v_seed * 13.0) * 0.6 + noise(UV * 9.0 - v_seed * 7.0) * 0.4;
	float body = smoothstep(0.5, 0.12, length(p) + (n - 0.5) * 0.35);
	// (thick soon after it leaves the fire, thinning out as it goes up)
	float fade = smoothstep(0.0, 0.06, v_age) * (1.0 - smoothstep(0.6, 1.0, v_age));
	float shade = mix(0.8, 1.1, n) * mix(0.85, 1.12, v_age);
	vec3 c = colour.rgb * shade;
	// (into the mist with distance, but never all the way: it is meant to be seen from afar)
	c = mix(c, mist.rgb, clamp(v_far / mist_far, 0.0, 0.55));
	ALBEDO = c;
	ALPHA = body * fade * thickness;
}
"""

static var _shader: Shader


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = quad
	many.instance_count = puffs
	for i in puffs:
		many.set_instance_transform(i, Transform3D.IDENTITY)
		many.set_instance_custom_data(i, Color(float(i) / puffs + randf() * 0.02, 0.0, 0.0, 0.0))
	multimesh = many
	# (it reaches well up and out from where it stands: never culled for being off to one side)
	custom_aabb = AABB(Vector3(-width.y - 20.0, -1.0, -width.y - 20.0), Vector3(width.y * 2.0 + 40.0, height + width.y + 4.0, width.y * 2.0 + 40.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"height", height)
	material.set_shader_parameter(&"width", width)
	material.set_shader_parameter(&"rise", rise)
	material.set_shader_parameter(&"wind", wind)
	material.set_shader_parameter(&"colour", colour)
	material.set_shader_parameter(&"thickness", thickness)
	material_override = material


## Sets the colour the far puffs fade towards (the mist's).
func set_mist(colour_of_mist: Color) -> void:
	(material_override as ShaderMaterial).set_shader_parameter(&"mist", colour_of_mist)
