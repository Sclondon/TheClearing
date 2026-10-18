class_name OctopusDrain
extends MeshInstance3D
## Drains at the foot of a wall: low black slots where the wall meets the
## floor, a little wider than a man's shoulders and no higher than a shin,
## running back into the dark (an octopus fits through any gap bigger than its
## beak, so it can live in one and pass through a wall by it). Round each mouth
## the wall is stained dark and wet above it, streaks running down to it, and a
## dark wet tongue of mud lies on the floor in front. All the drains given are
## one mesh, one draw.
##
##     var drains := OctopusDrain.new()
##     drains.mouths = [[point_on_the_floor_at_the_wall_face, out_of_the_wall], ...]
##     add_child(drains)   # (at the world's origin: the mouths are in the world)

## Each [where (on the floor, at the wall's face), the way out of the wall (level)].
var mouths: Array = []
@export var width := 1.3
@export var height := 0.42

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 hole : source_color = vec3(0.008, 0.008, 0.009);
uniform vec3 stain : source_color = vec3(0.05, 0.05, 0.048);

void fragment() {
	int kind = int(round(COLOR.r * 2.0));
	vec2 q = UV;
	if (kind == 0) {
		// The slot: black, its top a low arch, its edges a little soft.
		float top = 1.0 - 0.25 * pow(abs(q.x * 2.0 - 1.0), 2.0);
		float a = (1.0 - smoothstep(0.86, 1.0, abs(q.x * 2.0 - 1.0))) * (1.0 - smoothstep(top - 0.12, top, q.y));
		ALBEDO = hole;
		ALPHA = a;
	} else if (kind == 1) {
		// The wet stain on the wall round it, streaks running down.
		float streak = 0.5 + 0.5 * sin(q.x * 37.0 + sin(q.x * 11.0) * 2.0);
		float a = (1.0 - smoothstep(0.2, 1.0, abs(q.x * 2.0 - 1.0))) * (1.0 - smoothstep(0.15 + 0.6 * streak, 1.0, q.y));
		ALBEDO = stain;
		ALPHA = a * 0.55;
	} else {
		// The wet tongue of mud in front of it.
		vec2 c = (q - vec2(0.5, 0.0)) * vec2(2.0, 1.0);
		float a = 1.0 - smoothstep(0.35, 1.0, length(c));
		ALBEDO = stain * 0.6;
		ALPHA = a * 0.6;
	}
}
"""

static var _shader: Shader


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rebuild()


## Makes its mesh again from `mouths`.
func rebuild() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mouth: Array in mouths:
		var at: Vector3 = mouth[0]
		var out: Vector3 = (mouth[1] as Vector3).normalized()
		var along := out.cross(Vector3.UP).normalized()
		# the stain on the wall, then the slot over it, then the mud in front
		_quad(st, at + out * 0.012 - along * width * 0.85, along * width * 1.7, Vector3.UP * height * 4.5, 0.5)
		_quad(st, at + out * 0.02 - along * width * 0.5 + Vector3.UP * 0.005, along * width, Vector3.UP * height, 0.0)
		_quad(st, at + Vector3.UP * 0.035 - along * width * 0.8, along * width * 1.6, out * 1.6, 1.0)
	mesh = st.commit()
	custom_aabb = AABB(Vector3(-2000, -10, -2000), Vector3(4000, 20, 4000))


static func _quad(st: SurfaceTool, corner: Vector3, across: Vector3, up: Vector3, kind: float) -> void:
	var corners := [[corner, Vector2(0, 0)], [corner + across, Vector2(1, 0)], [corner + across + up, Vector2(1, 1)], [corner + up, Vector2(0, 1)]]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(Color(kind, 0, 0))
		st.set_uv(corners[i][1])
		st.add_vertex(corners[i][0])
