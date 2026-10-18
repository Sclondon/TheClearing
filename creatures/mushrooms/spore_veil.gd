class_name SporeVeil
extends CanvasLayer
## What breathing spores does to how you see: the picture blurs, greys and goes
## dusty brown at its edges. One for the screen, made the first time anything
## reports (`report`); anything that knows how thick the spores are round the
## player says so each frame, and the thickest is shown, fading as it thins.
## Under the HUD (layer -1). Costs nothing while clear (it is hidden).
##
##     SporeVeil.report(get_tree(), self, cloud.density_at(head))   # each frame, 0..1

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec3 dust : source_color = vec3(0.56, 0.5, 0.36);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 step_size = SCREEN_PIXEL_SIZE * (2.0 + 7.0 * amount);
	vec3 sum = texture(screen, uv).rgb * 0.2;
	// (eight taps round about: a soft blur, swimming a little)
	float swim = TIME * 1.7;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398 + swim * 0.2;
		sum += texture(screen, uv + vec2(cos(a), sin(a)) * step_size * (1.0 + 0.3 * sin(swim + float(k)))).rgb * 0.1;
	}
	float grey = dot(sum, vec3(0.3, 0.59, 0.11));
	vec3 seen = mix(sum, vec3(grey), 0.65 * amount);
	float edge = smoothstep(0.25, 0.75, length(uv - 0.5));
	seen = mix(seen, dust * (0.6 + 0.4 * grey), clamp(0.25 * amount + 0.55 * edge * amount, 0.0, 0.85));
	COLOR = vec4(seen, 1.0);
}
"""

static var _veils := {}

## How thick it is shown now, 0..1, eased.
var amount := 0.0
var _reports := {}
var _rect: ColorRect
var _material: ShaderMaterial


## The veil over `tree`'s screen (made if there is none).
static func of(tree: SceneTree) -> SporeVeil:
	var found: SporeVeil = _veils.get(tree)
	if found and is_instance_valid(found):
		return found
	found = SporeVeil.new()
	found.name = "SporeVeil"
	tree.root.add_child.call_deferred(found)
	_veils[tree] = found
	return found


## Says how thick the spores are round the player for `by` (0..1).
static func report(tree: SceneTree, by: Object, thickness: float) -> void:
	if thickness <= 0.0 and not _veils.has(tree):
		return
	of(tree)._reports[by] = thickness


func _ready() -> void:
	layer = -1
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	visible = false


func _exit_tree() -> void:
	for tree: SceneTree in _veils.keys():
		if _veils[tree] == self:
			_veils.erase(tree)


func _process(delta: float) -> void:
	var thickest := 0.0
	for by: Variant in _reports.keys():
		if not is_instance_valid(by):
			_reports.erase(by)
			continue
		thickest = maxf(thickest, _reports[by])
	# (it comes on fast, and clears slowly)
	amount = move_toward(amount, thickest, delta * (2.5 if thickest > amount else 0.35))
	visible = amount > 0.01
	_material.set_shader_parameter(&"amount", amount)
