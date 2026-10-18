class_name GnomeRope
extends MeshInstance3D
## A length of old rope between two points: two gnomes' hands, pulled taut
## across a hall at shin height, or lying slack along the ground as they run
## out with it. One small mesh (two crossed strips, so that it reads from any
## side), remade only while `a` or `b` or `sag` change.

## The ends (world), and how far it sags in the middle, metres.
var a := Vector3.ZERO
var b := Vector3.RIGHT
var sag := 0.05
## How thick it is, metres.
@export var thickness := 0.025

const COLOUR := Color(0.16, 0.13, 0.1)
const SEGMENTS := 10

var _strip := ImmediateMesh.new()
var _drawn := [Vector3.INF, Vector3.INF, -1.0]


func _ready() -> void:
	top_level = true
	mesh = _strip
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOUR
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Strung from `from` to `to`, sagging `drop` metres at the middle.
func set_ends(from: Vector3, to: Vector3, drop := 0.05) -> void:
	a = from
	b = to
	sag = drop
	if from.distance_to(_drawn[0]) < 0.01 and to.distance_to(_drawn[1]) < 0.01 and absf(drop - _drawn[2]) < 0.005:
		return
	_drawn = [from, to, drop]
	global_transform = Transform3D.IDENTITY
	_strip.clear_surfaces()
	_strip.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := (to - from)
	var side := along.cross(Vector3.UP).normalized() * thickness * 0.5
	if side.length() < 0.0001:
		side = Vector3.RIGHT * thickness * 0.5
	var up := Vector3.UP * thickness * 0.5
	for k in SEGMENTS:
		var p := point_at(float(k) / SEGMENTS)
		var q := point_at(float(k + 1) / SEGMENTS)
		for off: Vector3 in [side, up]:
			_strip.surface_add_vertex(p - off)
			_strip.surface_add_vertex(p + off)
			_strip.surface_add_vertex(q + off)
			_strip.surface_add_vertex(p - off)
			_strip.surface_add_vertex(q + off)
			_strip.surface_add_vertex(q - off)
	_strip.surface_end()


## A point along it (0 at `a`, 1 at `b`), sag and all.
func point_at(t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
