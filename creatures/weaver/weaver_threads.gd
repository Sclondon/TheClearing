class_name WeaverThreads
extends MeshInstance3D
## The threads a weaver leaves: fine strands strung across a space, pale and
## faintly shining (threads of light in the mist), a shimmer creeping along
## them. Any number in one mesh (one draw), remade only when one is added,
## taken away, cut or set quivering.
##
## `add(a, b)` strings one from `a` to `b` (world) and gives its number;
## `pluck(n, strength)` sets it humming (it quivers, and settles); `drag(n, at)`
## pulls its middle to a point (something caught in it); `cut(n, at)` snaps it
## there, the two halves springing back and curling away to nothing; `remove(n)`
## takes it away at once. `nearest(n, point)` is the nearest point of it to one.

## How thick each thread is drawn, metres, and how far the plain ones sag.
@export var thickness := 0.012
@export var sag := 0.06

const COLOUR := Color(0.85, 0.88, 0.9)
const SEGMENTS := 12

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(0.85, 0.88, 0.9);

void fragment() {
	// (UV.x along the thread, UV.y how far it has faded)
	float shimmer = 0.55 + 0.45 * pow(0.5 + 0.5 * sin(UV.x * 6.0 - TIME * 1.7), 6.0);
	ALBEDO = colour * shimmer;
	ALPHA = (1.0 - UV.y);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

class Strand:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var pull := Vector3.INF
	var quiver := 0.0
	var phase := 0.0
	## Cut: where along it (0..1), and how long since.
	var cut_at := -1.0
	var cut_time := 0.0

var threads := {}
var _next := 0
var _strip := ImmediateMesh.new()
var _dirty := true
var _moving := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _strip
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"colour", COLOUR)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add(from: Vector3, to: Vector3) -> int:
	var made := Strand.new()
	made.a = from
	made.b = to
	made.phase = randf() * TAU
	var n := _next
	_next += 1
	threads[n] = made
	_dirty = true
	return n


func remove(n: int) -> void:
	threads.erase(n)
	_dirty = true


func pluck(n: int, strength := 1.0) -> void:
	if threads.has(n):
		(threads[n] as Strand).quiver = maxf((threads[n] as Strand).quiver, strength)
		_moving = true


## Its middle pulled to `at` (world), or let go with INF.
func drag(n: int, at: Vector3) -> void:
	if threads.has(n):
		(threads[n] as Strand).pull = at
		_dirty = true


func cut(n: int, at: Vector3) -> void:
	if not threads.has(n):
		return
	var t: Strand = threads[n]
	if t.cut_at >= 0.0:
		return
	var ab := t.b - t.a
	t.cut_at = clampf((at - t.a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.1, 0.9)
	t.cut_time = 0.0
	t.pull = Vector3.INF
	_moving = true


func is_cut(n: int) -> bool:
	return threads.has(n) and (threads[n] as Strand).cut_at >= 0.0


## The point of thread `n` nearest `point` (world), as drawn (INF: no such thread).
func nearest(n: int, point: Vector3) -> Vector3:
	if not threads.has(n):
		return Vector3.INF
	var t: Strand = threads[n]
	var best := Vector3.INF
	for k in SEGMENTS + 1:
		var p := _at(t, float(k) / SEGMENTS, 0.0)
		if not best.is_finite() or p.distance_to(point) < best.distance_to(point):
			best = p
	return best


func _process(delta: float) -> void:
	if _moving:
		var still := true
		for n: int in threads.keys():
			var t: Strand = threads[n]
			if t.quiver > 0.0:
				t.quiver = maxf(t.quiver - delta * 0.7, 0.0)
				still = false
			if t.cut_at >= 0.0:
				t.cut_time += delta
				still = false
				if t.cut_time > 1.4:
					threads.erase(n)
		_moving = not still
		_dirty = true
	if _dirty:
		_dirty = false
		_draw()


func _draw() -> void:
	_strip.clear_surfaces()
	if threads.is_empty():
		return
	_strip.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var time := Time.get_ticks_msec() * 0.001
	for n: int in threads:
		var t: Strand = threads[n]
		var length := t.a.distance_to(t.b)
		var side := (t.b - t.a).cross(Vector3.UP).normalized() * thickness * 0.5
		if side.length() < 0.0001:
			side = Vector3.RIGHT * thickness * 0.5
		var up := Vector3.UP * thickness * 0.5
		var fade := smoothstep(0.6, 1.4, t.cut_time) if t.cut_at >= 0.0 else 0.0
		for k in SEGMENTS:
			var u0 := float(k) / SEGMENTS
			var u1 := float(k + 1) / SEGMENTS
			if t.cut_at >= 0.0 and u0 < t.cut_at and u1 > t.cut_at:
				continue
			var p := _at(t, u0, time)
			var q := _at(t, u1, time)
			for off: Vector3 in [side, up]:
				_vertex(p - off, u0 * length, fade)
				_vertex(p + off, u0 * length, fade)
				_vertex(q + off, u1 * length, fade)
				_vertex(p - off, u0 * length, fade)
				_vertex(q + off, u1 * length, fade)
				_vertex(q - off, u1 * length, fade)
	_strip.surface_end()


func _vertex(at: Vector3, along: float, fade: float) -> void:
	_strip.surface_set_uv(Vector2(along, fade))
	_strip.surface_add_vertex(at)


## A point along thread `t` (0 at `a`, 1 at `b`): its sag, its pull, its quiver,
## and (cut) each half springing back to its end and curling down.
func _at(t: Strand, u: float, time: float) -> Vector3:
	var p := t.a.lerp(t.b, u) + Vector3.DOWN * sag * 4.0 * u * (1.0 - u)
	if t.pull.is_finite():
		var mid := t.a.lerp(t.b, 0.5)
		p += (t.pull - mid) * (1.0 - absf(u - 0.5) * 2.0)
	if t.quiver > 0.0:
		var across := (t.b - t.a).cross(Vector3.UP).normalized()
		p += (Vector3.UP * 0.7 + across * 0.7) * sin(u * PI) * sin(time * 38.0 + t.phase) * 0.05 * t.quiver
	if t.cut_at >= 0.0:
		var spring := smoothstep(0.0, 0.6, t.cut_time)
		var end := t.a if u < t.cut_at else t.b
		var from_end := absf(u - (0.0 if u < t.cut_at else 1.0))
		p = p.lerp(end + Vector3.DOWN * from_end * 1.2, spring * smoothstep(0.0, 0.6, from_end * 2.0))
	return p
