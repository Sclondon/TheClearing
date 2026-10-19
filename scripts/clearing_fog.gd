class_name ClearingFog
extends MultiMeshInstance3D
## Banks of billowing fog along the foot of the clearing's wall, the wall
## rising high out of them (the user, 2026-10-18: "The cleaing should have
## billowing fog that the clearing walls rise above"). Its look by default:
## always there, as thick as Weather says (thickest at dawn, thinner by day, all
## but burnt off on a sunny day, beaten down by rain), so that walking out
## from the middle the wall's foot is lost in rolling white and its top stands
## clear above it.
##
## Each billow is one upright quad, turned about the upright to face the camera,
## drawn by a shader: a dome of fog whose edge and folds are noise rolling
## slowly up and over (warped by more noise as it goes), lit from above, faded
## into the ground and the wall where it meets them (the depth buffer). Three
## rows of them along each side, the tallest against the wall, lower and
## thinner towards the middle (ClearingStyle "Fog": how thick, high, far in,
## how many, how fast). All of it one draw.
##
## Near the camera a billow fades away (a quad that big, close, would cover the
## screen); in the bank, the mist thickens instead (Weather, DayCycle.thicken).

## How near the camera a billow fades out, metres.
const NEAR := 26.0
## The rows of billows: [how far out from the wall (a share of the reach), how
## high (a share of the fog's height), how wide (a share of the space each has)].
const ROWS := [[0.08, 1.0, 2.1], [0.35, 0.78, 1.9], [0.7, 0.5, 1.7]]

var style: ClearingStyle
var _look: ShaderMaterial
## Half the clearing's width, metres (its wall's face).
var half := 0.0
## How far the fog has rolled (seconds, at its speed).
var _clock := 0.0


## The fog banks of `plan`'s clearing, under `parent`.
static func put(parent: Node3D, plan: Maze) -> ClearingFog:
	var fog := ClearingFog.new()
	fog.name = "ClearingFog"
	fog.style = plan.clearing_style if plan.clearing_style else ClearingStyle.new()
	fog._build(plan)
	parent.add_child(fog)
	return fog


func _build(plan: Maze) -> void:
	half = Maze.CLEARING * Maze.CELL * 0.5
	var low := Settings.low_poly or Grass.quality == Grass.Quality.LOW
	var billows := maxi(2, int(style.clearing_fog_billows * 0.5) if low else style.clearing_fog_billows)
	var rows: Array = ROWS.slice(0, 2) if low else ROWS
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("clearing fog/%d" % plan.maze_seed)
	var places: Array[Transform3D] = []
	var side_length := half * 2.0
	for side in 4:
		var along := Vector2(1.0, 0.0).rotated(side * PI * 0.5)
		var inward := along.orthogonal()
		for row: Array in rows:
			var height: float = style.clearing_fog_height * row[1]
			var spacing := side_length / billows
			for i in billows:
				var t := (i + 0.5 + rng.randf_range(-0.3, 0.3)) / billows - 0.5
				var out: float = style.clearing_fog_reach * row[0] * rng.randf_range(0.7, 1.3) + 4.0
				var flat := -inward * (half - out) + along * t * (side_length - out * 2.0)
				var ground := plan.ground_height(Vector3(flat.x, 0.0, flat.y))
				var tall := height * rng.randf_range(0.8, 1.2)
				var wide: float = spacing * row[2] * rng.randf_range(0.85, 1.25)
				# (the quad's foot sunk under the ground: its middle a third of the way up)
				var middle := Vector3(flat.x, ground + tall * 0.32, flat.y)
				places.append(Transform3D(Basis.from_scale(Vector3(wide, tall, 1.0)), middle))
	var quad := QuadMesh.new()
	var meshes := MultiMesh.new()
	meshes.transform_format = MultiMesh.TRANSFORM_3D
	meshes.mesh = quad
	meshes.instance_count = places.size()
	for i in places.size():
		meshes.set_instance_transform(i, places[i])
	multimesh = meshes
	var shader := Shader.new()
	shader.code = SHADER.replace("//LOW", "#define LOW" if low else "")
	_look = ShaderMaterial.new()
	_look.shader = shader
	_look.set_shader_parameter(&"near", NEAR)
	material_override = _look
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (turned to the camera by the shader, so never culled by its own box)
	custom_aabb = AABB(Vector3(-half - 200.0, -50.0, -half - 200.0), Vector3(half * 2.0 + 400.0, 300.0, half * 2.0 + 400.0))
	_clock = rng.randf() * 100.0




## The fog now: how thick (0 to 1), how light it is, the mist's colour, the wind (0 to 1).
func show_fog(amount: float, light: float, mist: Color, wind: float, delta: float) -> void:
	visible = amount > 0.01
	if not visible:
		return
	_clock += delta * style.clearing_fog_speed * (1.0 + wind * 1.5)
	_look.set_shader_parameter(&"amount", amount)
	_look.set_shader_parameter(&"clock", _clock)
	_look.set_shader_parameter(&"colour", mist.lightened(0.22) * lerpf(0.45, 1.0, light))
	_look.set_shader_parameter(&"mist", mist)


## How deep in a bank a point is (0 out of it, 1 deep in its thickest part).
func in_bank(point: Vector3, ground: float) -> float:
	var from_wall := half - maxf(absf(point.x), absf(point.z))
	if from_wall < 0.0:
		return 0.0
	var reach := style.clearing_fog_reach
	var height := style.clearing_fog_height * lerpf(1.0, 0.42, clampf(from_wall / reach, 0.0, 1.0))
	return (1.0 - smoothstep(reach * 0.2, reach * 0.75, from_wall)) * (1.0 - smoothstep(height * 0.5, height, point.y - ground))


const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords, fog_disabled;
//LOW

uniform float amount = 1.0;
uniform float clock = 0.0;
uniform float near = 26.0;
uniform vec3 colour : source_color = vec3(0.8, 0.83, 0.82);
// The mist it fades into far off (its own haze, lighter than the mist on the rest,
// so that the banks stand out white at the foot of the far wall).
uniform vec3 mist : source_color = vec3(0.66, 0.7, 0.69);
uniform float haze = 0.0022;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying float seed;
varying float fade;
varying vec2 metres;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float billow(vec2 p) {
	return vnoise(p) * 0.62 + vnoise(p * 2.3 + 5.1) * 0.38;
}

vec3 unproject(vec2 screen_uv, float depth, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	seed = hash2(centre.xz * 0.013);
	// (each swelling and settling slowly, out of step with the rest)
	float swell = 1.0 + 0.07 * sin(clock * 0.11 + seed * 6.283);
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	to_eye.y = 0.0;
	float dist = length(to_eye);
	vec3 side = normalize(vec3(-to_eye.z, 0.0, to_eye.x) + vec3(0.0001, 0.0, 0.0));
	fade = smoothstep(near, near * 2.2, dist);
	vec2 corner = vec2(UV.x - 0.5, 0.5 - UV.y);
	metres = vec2(corner.x * wide, (corner.y + 0.32) * tall) * swell;
	VERTEX = centre + side * corner.x * wide * swell + vec3(0.0, corner.y * tall * swell, 0.0);
	if (fade <= 0.0) {
		VERTEX = centre;
	}
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	// The fog's folds, rolling slowly up and over, warped as they go.
	vec2 q = metres * 0.045 + vec2(seed * 17.0, -clock * 0.05);
#ifndef LOW
	q += (vec2(vnoise(q * 0.7 + vec2(clock * 0.03, 0.0)), vnoise(q * 0.7 + vec2(4.3, -clock * 0.04))) - 0.5) * 1.6;
#endif
	float n = billow(q);
	// A dome, bulging at its top and flat at its foot, its edge eaten by the folds.
	float r = length(vec2(p.x, max(p.y - 0.3, 0.0) * 1.35));
	float edge = 0.62 + 0.38 * (n - 0.5) * 2.0 * 0.55;
	float a = 1.0 - smoothstep(edge - 0.32, edge, r);
	a *= mix(0.55, 1.0, n);
	vec3 behind = unproject(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float soft = clamp((length(behind) - length(VERTEX)) / 14.0, 0.0, 1.0);
	// (lit from above: brighter on top and in the folds that face up, darker underneath)
	float lit = mix(0.82, 1.08, smoothstep(0.0, 1.0, p.y)) * mix(0.9, 1.06, n);
	float hazed = (1.0 - exp(-length(VERTEX) * haze)) * 0.6;
	ALBEDO = mix(colour * lit, mist, hazed);
	ALPHA = clamp(a * amount * fade * soft * 0.9, 0.0, 1.0);
}
"""
