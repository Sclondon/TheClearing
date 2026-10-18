class_name OctopusInk
extends MeshInstance3D
## A cloud of the octopus's ink: a dark, soft cloud that billows out from where
## it was let go to about `radius` across over a second, hangs low and drifts,
## and thins away after `life` seconds. One draw (soft puffs turned to the
## camera, moved in the shader), and then it frees itself.
##
##     var cloud := OctopusInk.new()
##     add_child(cloud)
##     cloud.global_position = where
##     OctopusInk.darkness_at(point)   # 0..1: how deep in any ink a point is (for the screen: OctopusInk.Blind)
##
## `OctopusInk.Blind` is the screen going dark for whoever is in it: put one in
## (a CanvasLayer), give it the node to watch (the player) as `watch`, and it
## darkens the picture, swirling, as deep as the camera or the one watched is in
## any ink, from every cloud there is.

const PUFFS := 18

@export var radius := 4.6
@export var life := 9.0
@export var fade := 3.0

static var clouds: Array[OctopusInk] = []
static var _mesh: ArrayMesh
static var _shader: Shader

var age := 0.0
var _material: ShaderMaterial

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform float age = 0.0;
uniform float radius = 4.6;
uniform float life = 9.0;
uniform float fade = 3.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float seed;
varying float strength;

void vertex() {
	seed = CUSTOM0.w;
	float spread = radius * (1.0 - exp(-age * 2.4));
	vec3 dir = CUSTOM0.xyz;
	// (it hangs low: what billows up sinks back, and it all drifts a little)
	vec3 off = dir * spread * vec3(1.0, 0.55, 1.0) + vec3(sin(seed * 31.0 + age * 0.3), -0.12 * age, cos(seed * 17.0 + age * 0.25)) * 0.4 * age;
	off.y = max(off.y, -0.6);
	vec3 centre = (MODEL_MATRIX * vec4(off, 1.0)).xyz;
	float size = (0.8 + 2.3 * (1.0 - exp(-age * 1.6))) * (0.7 + 0.6 * fract(seed * 7.7));
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 at = centre + (right * (UV.x - 0.5) + up * (UV.y - 0.5)) * size;
	VERTEX = (VIEW_MATRIX * vec4(at, 1.0)).xyz;
	strength = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(life - fade, life, age));
}

void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	float swirl = sin(atan(q.y, q.x) * 3.0 + seed * 20.0 + age * 0.7) * 0.12;
	float soft = 1.0 - smoothstep(0.25 + swirl, 1.0, d);
	ALBEDO = mix(vec3(0.012, 0.012, 0.016), vec3(0.06, 0.055, 0.06), smoothstep(0.4, 1.0, d));
	// (softened where it meets the floor and the walls, so that no edge of a puff shows)
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float gap = -behind.z / behind.w + VERTEX.z;
	ALPHA = soft * 0.62 * strength * clamp(gap / 0.9, 0.0, 1.0);
}
"""


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	_material.set_shader_parameter(&"radius", radius)
	_material.set_shader_parameter(&"life", life)
	_material.set_shader_parameter(&"fade", fade)
	material_override = _material
	mesh = _puffs()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-radius - 4.0, -3.0, -radius - 4.0), Vector3(radius * 2.0 + 8.0, 9.0, radius * 2.0 + 8.0))
	clouds.append(self)


func _exit_tree() -> void:
	clouds.erase(self)


func _process(delta: float) -> void:
	age += delta
	_material.set_shader_parameter(&"age", age)
	if age > life:
		queue_free()


## How thick the ink is at `point` (0..1).
func thickness_at(point: Vector3) -> float:
	var spread := radius * (1.0 - exp(-age * 2.4)) + 1.2
	var middle := global_position + Vector3.DOWN * 0.3
	var off := point - middle
	off.y *= 1.6
	var inside := 1.0 - smoothstep(spread * 0.55, spread * 1.05, off.length())
	return inside * smoothstep(0.0, 0.4, age) * (1.0 - smoothstep(life - fade, life, age))


## How deep in any ink `point` is (0..1).
static func darkness_at(point: Vector3) -> float:
	var most := 0.0
	for cloud in clouds:
		if is_instance_valid(cloud) and cloud.is_inside_tree():
			most = maxf(most, cloud.thickness_at(point))
	return most


static func _puffs() -> ArrayMesh:
	if _mesh:
		return _mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for k in PUFFS:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-1, 1))
		dir = dir.normalized() * pow(rng.randf(), 0.5) if k > 0 else Vector3.ZERO
		var seed := rng.randf()
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			st.set_custom(0, Color(dir.x, dir.y, dir.z, seed))
			st.set_uv(corner)
			st.add_vertex(Vector3.ZERO)
	_mesh = st.commit()
	return _mesh


## The screen going dark for whoever is in ink (see above).
class Blind extends CanvasLayer:
	## The node whose place counts as well as the camera's (the player).
	var watch: Node3D
	## A line of text to show at the foot of the screen (empty: none).
	var prompt := "":
		set(value):
			prompt = value
			if _label:
				_label.text = value
				_label.visible = value != ""
	var _cover: ColorRect
	var _label: Label
	var _dark := 0.0

	func _init() -> void:
		layer = 2
		name = "InkBlind"

	func _ready() -> void:
		_cover = ColorRect.new()
		_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform float dark = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(3.0, 2.0);
	float swirl = noise(p + vec2(TIME * 0.15, -TIME * 0.1)) * 0.6 + noise(p * 2.7 - TIME * 0.2) * 0.4;
	float edge = smoothstep(0.1, 0.75, length(UV - 0.5) * 1.4);
	float a = clamp(dark * (0.78 + 0.3 * swirl) + dark * edge * 0.25, 0.0, 0.97);
	COLOR = vec4(vec3(0.01, 0.01, 0.015) + vec3(0.03) * swirl * dark, a);
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		_cover.material = material
		_cover.visible = false
		add_child(_cover)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_label.offset_bottom = -110.0
		_label.add_theme_font_size_override(&"font_size", 34)
		_label.add_theme_color_override(&"font_color", Color(0.93, 0.9, 0.8))
		_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.05))
		_label.add_theme_constant_override(&"outline_size", 8)
		_label.visible = false
		add_child(_label)

	## How dark the screen is now (0..1).
	func darkness() -> float:
		return _dark

	func _process(delta: float) -> void:
		var want := 0.0
		var camera := get_viewport().get_camera_3d()
		if camera:
			want = OctopusInk.darkness_at(camera.global_position)
		if watch and is_instance_valid(watch):
			want = maxf(want, OctopusInk.darkness_at(watch.global_position + Vector3.UP * 1.0))
		_dark = lerpf(_dark, want, 1.0 - exp(-delta * (6.0 if want > _dark else 1.5)))
		_cover.visible = _dark > 0.01
		if _cover.visible:
			(_cover.material as ShaderMaterial).set_shader_parameter(&"dark", _dark)
