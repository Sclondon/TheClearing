class_name FishSchool
extends MultiMeshInstance3D
## A school of small fish in still water: a dozen or so dark little fish, a
## hand long, hanging just under the surface, nosing slowly about together, that
## dart off all at once from whoever wades near and scatter, stirring rings on
## the water, and gather again further off.
##
## One MultiMesh for the whole school, its tails beating in its shader; a light
## script moves them (where the school is going, and each fish trailing its
## place in it), and only while it is woken (set_process: Ponds wakes those near
## the camera, twice a second). It is not drawn past SEEN metres.
##
##     var school := FishSchool.put(parent, area, level, depth_at, 12, seed, pool)
##
## `depth_at` (a Callable of a point (x, z)) says how deep the water is there:
## the fish keep where it is no shallower than SHALLOWEST.

## Everything made is in this group (for Ponds to wake).
const GROUP := &"fish_schools"
## No fish where the water is shallower than this, metres.
const SHALLOWEST := 0.32
## Not drawn past this far from the camera, metres.
const SEEN := 42.0
## They dart off from anyone within this many metres of the school.
const SHY := 4.5
## How fast the school noses about, and how fast it darts, metres a second.
const CRUISE := 0.35
const DART := 3.4

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 back : source_color = vec3(0.07, 0.075, 0.06);
uniform vec3 flank : source_color = vec3(0.3, 0.31, 0.26);
uniform float banded = 1.0;

varying float v_side;

void vertex() {
	// (INSTANCE_CUSTOM: x a phase of its own, y how hard it is swimming, 0 to 1)
	float t = clamp(0.5 - VERTEX.z / 0.17, 0.0, 1.0);
	float beat = TIME * mix(7.0, 22.0, INSTANCE_CUSTOM.y) + INSTANCE_CUSTOM.x * 6.283;
	float sway = sin(beat - t * 3.2) * mix(0.012, 0.03, INSTANCE_CUSTOM.y);
	VERTEX.x += sway * t * t;
	v_side = COLOR.r;
}

void fragment() {
	// (dark down its back, a paler flank that catches the light as it turns)
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = mix(back, flank, v_side * (0.4 + 0.6 * facing));
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
}

void light() {
	float towards = dot(NORMAL, LIGHT);
	float lit = mix(clamp(towards * 0.5 + 0.5, 0.0, 1.0), step(0.3, towards * 0.5 + 0.5), banded * 0.5);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
"""

## Where the school may go (x, z), how high the water stands, and how deep it is.
var area: Rect2
var level := 0.0
var depth_at: Callable
## The water it is in (a Pool), for the rings it stirs; may be null.
var pool: Node3D
var count := 12

var _rng := RandomNumberGenerator.new()
var _centre := Vector3.ZERO
var _target := Vector3.ZERO
var _alarm := 0.0
var _idle := 0.0
var _clock := 0.0
var _at := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _offset := PackedVector3Array()
var _keen := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _down := PackedFloat32Array()
var _buffer := PackedFloat32Array()

static var _material: ShaderMaterial
static var _mesh: ArrayMesh


## Puts a school of `fish` fish under `parent`, somewhere in `where` (x, z) deep
## enough, in water standing at `level` that is `depth_at` deep; null if there is
## nowhere deep enough.
static func put(parent: Node, where: Rect2, water_level: float, depth: Callable, fish: int, seed_value: int, water: Node3D = null) -> FishSchool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var home := Vector2.INF
	for i in 24:
		var p := where.position + Vector2(rng.randf(), rng.randf()) * where.size
		if depth.call(p) >= SHALLOWEST + 0.08:
			home = p
			break
	if not home.is_finite():
		return null
	var school := FishSchool.new()
	school.name = "Fish"
	school.area = where
	school.level = water_level
	school.depth_at = depth
	school.count = fish
	school.pool = water
	school._rng.seed = seed_value + 1
	school._centre = Vector3(home.x, water_level, home.y)
	parent.add_child(school)
	return school


## Schools of fish over `where` (x, z), as many as `schools`: put where the water
## is deep enough, the first of them in `first` (if it is given) and the rest
## anywhere, each keeping within a stretch of water round where it is put.
static func scatter(parent: Node, where: Rect2, water_level: float, depth: Callable, schools: int, fish: int, seed_value: int, water: Node3D = null, first := Rect2()) -> Array[FishSchool]:
	var made: Array[FishSchool] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in schools:
		var over := first.intersection(where) if k < schools / 3 + 1 and first.has_area() else where
		if not over.has_area():
			over = where
		for tries in 40:
			var p := over.position + Vector2(rng.randf(), rng.randf()) * over.size
			if depth.call(p) < SHALLOWEST + 0.12:
				continue
			var stretch := Rect2(p - Vector2.ONE * 11.0, Vector2.ONE * 22.0).intersection(where)
			var school := put(parent, stretch, water_level, depth, fish, rng.randi(), water)
			if school:
				made.append(school)
			break
	return made


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = SEEN
	visibility_range_end_margin = 6.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	material_override = _material_of()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh_of()
	multimesh.instance_count = count
	multimesh.custom_aabb = AABB(Vector3(area.position.x - 2.0, level - 3.0, area.position.y - 2.0), Vector3(area.size.x + 4.0, 3.5, area.size.y + 4.0))
	_at.resize(count)
	_yaw.resize(count)
	_offset.resize(count)
	_keen.resize(count)
	_sizes.resize(count)
	_phase.resize(count)
	_down.resize(count)
	_buffer.resize(count * 16)
	for i in count:
		# (a loose cloud, longer than it is wide, some further down than others)
		var round := _rng.randf() * TAU
		var out := sqrt(_rng.randf())
		_offset[i] = Vector3(cos(round) * out * 0.9, 0.0, sin(round) * out * 0.6)
		_keen[i] = _rng.randf_range(1.6, 4.0)
		_sizes[i] = _rng.randf_range(0.7, 1.35)
		_phase[i] = _rng.randf()
		_down[i] = _rng.randf_range(0.1, 0.26)
		_at[i] = _centre + _offset[i]
		_yaw[i] = _rng.randf() * TAU
	_target = _centre
	_place(0.0)
	# (woken by Ponds when the camera comes near)
	set_process(false)


## Where the middle of the school is now.
func centre() -> Vector3:
	return _centre


## How alarmed it is (1 just startled, falling to 0 as it calms).
func alarm() -> float:
	return _alarm


## Where each fish is now.
func fish_positions() -> PackedVector3Array:
	return _at


func _process(delta: float) -> void:
	_clock += delta
	# Anyone wading near?
	var threat := Vector3.INF
	var nearest := SHY
	for body: Node in get_tree().get_nodes_in_group(&"bridge_weights"):
		var at := (body as Node3D).global_position
		if absf(at.y - level) > 2.2:
			continue
		var apart := Vector2(at.x - _centre.x, at.z - _centre.z).length()
		if apart < nearest:
			nearest = apart
			threat = at
	if threat.is_finite():
		if _alarm < 0.35 or Vector2(_target.x - threat.x, _target.z - threat.z).length() < SHY + 1.0:
			_flee(threat)
		var water: Water = pool.get(&"water") as Water if pool else null
		if _alarm < 0.35 and water:
			# (a stir on the water where they were)
			water.ripple(_centre, 0.4)
		_alarm = 1.0
	else:
		_alarm = maxf(_alarm - delta * 0.45, 0.0)
	# Nosing about: to somewhere near, now and then a rest.
	var flat := Vector2(_target.x - _centre.x, _target.z - _centre.z)
	if flat.length() < 0.4:
		_idle -= delta
		if _idle <= 0.0:
			_idle = _rng.randf_range(0.5, 3.0)
			_wander()
	else:
		var speed := lerpf(CRUISE, DART, _alarm)
		var step := flat.normalized() * minf(speed * delta, flat.length())
		var next := Vector2(_centre.x, _centre.z) + step
		if depth_at.call(next) < SHALLOWEST:
			_wander()
		else:
			_centre.x = next.x
			_centre.z = next.y
	_place(delta)


# The school's way off from `threat`: the best of a few places away from it,
# deep enough, the furthest from it.
func _flee(threat: Vector3) -> void:
	var away := Vector2(_centre.x - threat.x, _centre.z - threat.z)
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
	var best := Vector2(_centre.x, _centre.z)
	var furthest := -1.0
	for i in 8:
		var turn := _rng.randf_range(-1.1, 1.1)
		var p := Vector2(_centre.x, _centre.z) + away.rotated(turn) * _rng.randf_range(4.0, 8.0)
		p = p.clamp(area.position, area.end)
		if depth_at.call(p) < SHALLOWEST:
			continue
		var from := p.distance_to(Vector2(threat.x, threat.z))
		if from > furthest:
			furthest = from
			best = p
	_target = Vector3(best.x, level, best.y)
	_idle = 0.0


func _wander() -> void:
	for i in 10:
		var p := Vector2(_centre.x, _centre.z) + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(1.0, 5.0)
		p = p.clamp(area.position, area.end)
		if depth_at.call(p) >= SHALLOWEST + 0.05:
			_target = Vector3(p.x, level, p.y)
			return
	_target = _centre


# Each fish after its place in the school (each as quick to it as it is keen,
# quicker when alarmed, the cloud looser), turned the way it goes, a little
# under the surface but over the bottom; written into the MultiMesh at once.
func _place(delta: float) -> void:
	var spread := lerpf(1.0, 1.9, _alarm)
	var swirl := _clock * 0.25
	var effort := clampf(0.15 + _alarm * 0.85, 0.0, 1.0)
	for i in count:
		var o := _offset[i].rotated(Vector3.UP, swirl + sin(_clock * 0.4 + i) * 0.3) * spread
		var goal := _centre + o
		var was := _at[i]
		var now := was.lerp(goal, minf(1.0, _keen[i] * delta * (1.0 + _alarm * 2.5))) if delta > 0.0 else goal
		var bottom: float = level - depth_at.call(Vector2(now.x, now.z))
		now.y = maxf(level - _down[i] * (1.0 + _alarm * 0.6), bottom + 0.07)
		var moved := Vector2(now.x - was.x, now.z - was.z)
		if moved.length() > 0.0005:
			_yaw[i] = lerp_angle(_yaw[i], atan2(moved.x, moved.y), minf(1.0, delta * 9.0))
		_at[i] = now
		var basis := Basis(Vector3.UP, _yaw[i]).scaled(Vector3.ONE * _sizes[i])
		var k := i * 16
		_buffer[k] = basis.x.x
		_buffer[k + 1] = basis.y.x
		_buffer[k + 2] = basis.z.x
		_buffer[k + 3] = now.x
		_buffer[k + 4] = basis.x.y
		_buffer[k + 5] = basis.y.y
		_buffer[k + 6] = basis.z.y
		_buffer[k + 7] = now.y
		_buffer[k + 8] = basis.x.z
		_buffer[k + 9] = basis.y.z
		_buffer[k + 10] = basis.z.z
		_buffer[k + 11] = now.z
		_buffer[k + 12] = _phase[i]
		_buffer[k + 13] = effort
		_buffer[k + 14] = 0.0
		_buffer[k + 15] = 0.0
	multimesh.buffer = _buffer


static func _material_of() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	return _material


# A fish a hand long along +Z (its head that way): a slim body seen from above
# with a forked tail, and the same seen from the side, crossed (red in its
# colour: its paler flank).
static func _mesh_of() -> ArrayMesh:
	if _mesh:
		return _mesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (the outline, from the snout back, as half-widths along its length)
	var outline: Array[Vector2] = [Vector2(0.085, 0.0), Vector2(0.06, 0.012), Vector2(0.02, 0.016), Vector2(-0.03, 0.011), Vector2(-0.058, 0.004)]
	var tail: Array[Vector2] = [Vector2(-0.058, 0.004), Vector2(-0.088, 0.02), Vector2(-0.078, 0.0), Vector2(-0.088, -0.02)]
	for plane in 2:
		# (0: lying flat, seen from above; 1: on edge, seen from the side)
		var across := Vector3.RIGHT if plane == 0 else Vector3.UP
		var normal := Vector3.UP if plane == 0 else Vector3.RIGHT
		var side := 0.0 if plane == 0 else 1.0
		for k in outline.size() - 1:
			var a := outline[k]
			var b := outline[k + 1]
			var a1 := Vector3(0, 0, a.x) + across * a.y
			var a2 := Vector3(0, 0, a.x) - across * a.y
			var b1 := Vector3(0, 0, b.x) + across * b.y
			var b2 := Vector3(0, 0, b.x) - across * b.y
			for v: Vector3 in [a1, b1, b2, a1, b2, a2]:
				tool.set_color(Color(side if v.dot(across) < 0.0 else side * 0.5, 0, 0))
				tool.set_normal(normal)
				tool.add_vertex(v)
		var root := Vector3(0, 0, tail[0].x)
		for k in [[1, 2], [2, 3]]:
			var p := Vector3(0, 0, tail[k[0]].x) + across * tail[k[0]].y
			var q := Vector3(0, 0, tail[k[1]].x) + across * tail[k[1]].y
			for v: Vector3 in [root, p, q]:
				tool.set_color(Color(side * 0.3, 0, 0))
				tool.set_normal(normal)
				tool.add_vertex(v)
	_mesh = tool.commit()
	return _mesh
