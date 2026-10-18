class_name PondFrogs
extends Node3D
## Ordinary frogs at the edge of the water: common frogs and leopard frogs,
## a hand long, a dozen or so sitting about the bank of a pool (or along the
## edges of a marsh's pools), facing the water. Their look, every move and
## their voices are here; what frightens them, and how loud they sing, is for
## the game to say. It knows nothing of the game it is in.
##
##     var frogs := PondFrogs.new()
##     frogs.count = 12
##     frogs.pool_radius = 1.8           # a pond is drawn here, and they sit round its edge
##     add_child(frogs)
##     # or, along water that is there already: frogs.pool = false, and before it
##     # goes in, frogs.banks = [[where one sits, the point in the water it leaps to], ...] (world)
##     frogs.frighten = [player]          # Node3Ds that frighten them (their `velocity` is read)
##     frogs.chorus = 0.8                 # how hard they sing, 0..1 (more at dusk, more in rain)
##     frogs.scare(at)                    # a fright from `at`: those near leap in
##
## WHAT THEY DO. They sit still, throats pulsing, now and then turning, and
## sing: each croaks in its own time, a run of "rib-bits" and low purring
## snores, the throat blown up with each; how often, and how loud the chorus is
## (one sound for all of them, from the middle of the pool), is `chorus`.
## Something coming near (`hush_range`) and those near it go quiet and still;
## nearer (`dive_range`), or coming at them fast, they leap into the water, one
## after another along the bank (plop, plop: a ring spreads where each goes
## in). Under a while, they come up again, only their eyes above the water,
## look about, and when nothing is near they climb back out to their places.
##
## THE COST is flat: all of them are one MultiMesh (the little frog of
## creatures/frog, frog.glb, posed in the shader: FrogLook), the rings another,
## and the pond two flat meshes. No rays, no physics; nothing processes while
## `visible` is off.
##
## `take_one(at)` takes the one nearest `at` (it is eaten: gone until
## `restore()`); `out()` is how many are sitting out of the water.

signal dived(at: Vector3)

enum { SIT, HOP, DIVE, UNDER, PEEK, CLIMB, GONE }

## How many frogs (with a pond; along banks given, one to each bank).
@export_range(1, 64) var count := 12
## How long the smallest and biggest are, snout to rump, metres.
@export var frog_size := Vector2(0.07, 0.11)
## A pond drawn here for them, and how big it is (m).
@export var pool := true
@export var pool_radius := 1.8
## How near something must come to hush them, and to send them into the water (m).
@export var hush_range := 9.0
@export var dive_range := 3.2
## Coming at them faster than this (m/s) sends them in from further off (`dive_range` * 1.8).
@export var rush_speed := 2.6
## How long they stay under, seconds (from, to).
@export var under_time := Vector2(7.0, 16.0)
## How hard they sing, 0 (silent) to 1 (a full chorus).
@export_range(0.0, 1.0) var chorus := 0.5
## Their voices.
@export var voice := true
@export var volume_db := -10.0

## Where each sits and the point in the water it leaps to: [Vector3, Vector3]
## pairs in the world. Made round the pond when `pool` is on; give them for water that is there already.
var banks: Array = []
## Whatever frightens them.
var frighten: Array = []

var _state := PackedByteArray()
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _pz := PackedFloat32Array()
var _yaw := PackedFloat32Array()
var _t := PackedFloat32Array()
var _dur := PackedFloat32Array()
var _wait := PackedFloat32Array()
var _size := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _croak_at := PackedFloat32Array()
var _hushed := PackedFloat32Array()
var _fright := PackedFloat32Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _time := 0.0
var _drawn: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _rings: MultiMeshInstance3D
var _ring_buffer := PackedFloat32Array()
var _ring_next := 0
var _voice: AudioStreamPlayer3D
var _plops: Array[AudioStreamPlayer3D] = []
var _plop_next := 0
var _plopped := 0.0
var _rng := RandomNumberGenerator.new()

const RINGS := 8
const RING_TIME := 1.6

static var _material: ShaderMaterial
static var _ring_material: ShaderMaterial
static var _chorus: AudioStreamWAV
static var _plop: Array[AudioStreamWAV] = []


func _ready() -> void:
	_rng.seed = hash(str(global_position.snapped(Vector3.ONE * 0.1)))
	if pool:
		banks.clear()
		for i in count:
			var round_about := TAU * (i + _rng.randf_range(-0.3, 0.3)) / count
			var out := Vector3(cos(round_about), 0.0, sin(round_about))
			banks.append([global_position + out * pool_radius * _rng.randf_range(1.02, 1.22), global_position + out * pool_radius * _rng.randf_range(0.35, 0.7) + Vector3.UP * 0.02])
		add_child(_pond())
	count = banks.size()
	for list: PackedFloat32Array in [_px, _py, _pz, _yaw, _t, _dur, _wait, _size, _seed, _croak_at, _hushed, _fright]:
		list.resize(count)
	_state.resize(count)
	_from.resize(count)
	_to.resize(count)
	for i in count:
		_seed[i] = _rng.randf()
		_size[i] = lerpf(frog_size.x, frog_size.y, _rng.randf())
		_croak_at[i] = _rng.randf_range(0.0, 6.0)
		_fright[i] = -1.0
		_sit(i)

	_drawn = MultiMeshInstance3D.new()
	_drawn.top_level = true
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = FrogSwarm.mesh()
	many.instance_count = count
	_drawn.multimesh = many
	_drawn.material_override = material()
	add_child(_drawn)
	_drawn.global_transform = Transform3D.IDENTITY
	var box := AABB(global_position, Vector3.ZERO)
	for bank: Array in banks:
		box = box.expand(bank[0]).expand(bank[1])
	_drawn.custom_aabb = box.grow(1.0)
	_buffer.resize(count * 16)

	_rings = MultiMeshInstance3D.new()
	_rings.top_level = true
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rings := MultiMesh.new()
	rings.transform_format = MultiMesh.TRANSFORM_3D
	rings.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.orientation = PlaneMesh.FACE_Y
	rings.mesh = quad
	rings.instance_count = RINGS
	_rings.multimesh = rings
	_rings.material_override = ring_material()
	add_child(_rings)
	_rings.global_transform = Transform3D.IDENTITY
	_rings.custom_aabb = box.grow(2.0)
	_ring_buffer.resize(RINGS * 16)
	rings.buffer = _ring_buffer

	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = chorus_sound()
		_voice.unit_size = 4.0
		_voice.max_distance = 45.0
		_voice.volume_db = -60.0
		add_child(_voice)
		_voice.position = box.get_center() - global_position + Vector3.UP * 0.2
		for k in 2:
			var plop := AudioStreamPlayer3D.new()
			plop.unit_size = 3.0
			plop.max_distance = 25.0
			plop.volume_db = volume_db - 2.0
			plop.top_level = true
			add_child(plop)
			_plops.append(plop)
	_write()


## A fright from `at`: those within reach of it leap in (one after another).
func scare(at: Vector3, reach := -1.0) -> void:
	if reach < 0.0:
		reach = dive_range * 1.5
	for i in count:
		if _state[i] in [SIT, HOP, PEEK] and Vector3(_px[i], _py[i], _pz[i]).distance_to(at) < reach:
			_frighten(i, _rng.randf_range(0.0, 0.35))


## How many are sitting out of the water.
func out() -> int:
	var n := 0
	for i in count:
		if _state[i] in [SIT, HOP, CLIMB]:
			n += 1
	return n


## Where the one sitting out nearest `at` is (INF: none are out).
func nearest_out(at: Vector3) -> Vector3:
	var best := Vector3.INF
	var far := INF
	for i in count:
		if _state[i] in [SIT, HOP, CLIMB, DIVE]:
			var p := Vector3(_px[i], _py[i], _pz[i])
			if p.distance_to(at) < far:
				far = p.distance_to(at)
				best = p
	return best


## The one nearest `at` (out of the water, if any are) is taken: gone, and the rest leap in.
func take_one(at: Vector3) -> void:
	var best := -1
	var far := INF
	for pass_out in [true, false]:
		for i in count:
			if _state[i] == GONE or (pass_out and _state[i] not in [SIT, HOP, CLIMB]):
				continue
			var d := Vector3(_px[i], _py[i], _pz[i]).distance_to(at)
			if d < far:
				far = d
				best = i
		if best >= 0:
			break
	if best >= 0:
		_state[best] = GONE
	scare(at, dive_range * 2.5)


## Those taken come back (on their banks), and everything is as it was.
func restore() -> void:
	for i in count:
		if _state[i] == GONE:
			_sit(i)


func frog_state(i: int) -> int:
	return _state[i]


func frog_position(i: int) -> Vector3:
	return Vector3(_px[i], _py[i], _pz[i])


# --- Each frame ---

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	delta = minf(delta, 0.1)
	_time += delta
	_plopped = maxf(_plopped - delta, 0.0)
	# What frightens them: where it is and how it is coming.
	var near_points: Array[Vector3] = []
	var near_moving: Array[Vector3] = []
	for one: Variant in frighten:
		if not is_instance_valid(one) or not (one is Node3D) or not (one as Node3D).is_inside_tree():
			continue
		var at := (one as Node3D).global_position
		if at.distance_to(global_position) > hush_range + pool_radius + 20.0:
			continue
		near_points.append(at)
		var v: Variant = (one as Node3D).get(&"velocity")
		near_moving.append(v if v is Vector3 else Vector3.ZERO)
	var singing := 0
	for i in count:
		var state := _state[i]
		if state == GONE:
			continue
		var here := Vector3(_px[i], _py[i], _pz[i])
		var bank: Vector3 = banks[i][0]
		# How near the nearest fright is, and whether it is coming at them.
		var nearest := INF
		var rushing := false
		for k in near_points.size():
			var to := here - near_points[k]
			to.y *= 0.5
			var d := to.length()
			nearest = minf(nearest, d)
			var flat := Vector3(near_moving[k].x, 0.0, near_moving[k].z)
			if d < dive_range * 1.8 and flat.length() > rush_speed and flat.normalized().dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.6:
				rushing = true
		if nearest < hush_range:
			_hushed[i] = 2.0 + _seed[i] * 3.0
		else:
			_hushed[i] = maxf(_hushed[i] - delta, 0.0)
		if _fright[i] >= 0.0:
			_fright[i] -= delta
			if _fright[i] < 0.0 and state in [SIT, HOP, CLIMB, PEEK]:
				_dive(i)
				continue
		match state:
			SIT:
				if nearest < dive_range or rushing:
					_frighten(i, _rng.randf_range(0.0, 0.3) * (0.4 if rushing else 1.0))
				_wait[i] -= delta
				if _wait[i] <= 0.0 and _hushed[i] <= 0.0:
					# (now and then one turns a little where it sits)
					_wait[i] = _rng.randf_range(4.0, 12.0)
					_yaw[i] += _rng.randf_range(-0.5, 0.5)
				if _hushed[i] <= 0.0 and chorus > 0.02:
					singing += 1
			HOP, DIVE, CLIMB:
				_t[i] += delta
				var p := minf(_t[i] / _dur[i], 1.0)
				var a: Vector3 = _from[i]
				var b: Vector3 = _to[i]
				var high := 0.16 + 0.1 * _seed[i] if state != CLIMB else 0.12
				_px[i] = lerpf(a.x, b.x, p)
				_pz[i] = lerpf(a.z, b.z, p)
				_py[i] = lerpf(a.y, b.y, p) + 4.0 * high * p * (1.0 - p)
				if p >= 1.0:
					if state == DIVE:
						_state[i] = UNDER
						_wait[i] = _rng.randf_range(under_time.x, under_time.y)
						_splash(b)
						dived.emit(b)
						# (those near it on the bank go in after it)
						for j in count:
							if j != i and _state[j] == SIT and _fright[j] < 0.0 and Vector3(_px[j], _py[j], _pz[j]).distance_to(bank) < 1.6 and _rng.randf() < 0.75:
								_frighten(j, _rng.randf_range(0.08, 0.45))
					else:
						_sit(i)
			UNDER:
				_wait[i] -= delta
				if _wait[i] <= 0.0:
					if nearest < hush_range * 0.6:
						_wait[i] = _rng.randf_range(2.0, 5.0)
					else:
						# Up, only the eyes above the water.
						_state[i] = PEEK
						_wait[i] = _rng.randf_range(2.0, 5.0)
						var water: Vector3 = banks[i][1]
						_px[i] = water.x + (_seed[i] - 0.5) * 0.3
						_pz[i] = water.z + (fposmod(_seed[i] * 7.0, 1.0) - 0.5) * 0.3
						_py[i] = water.y - _size[i] * 0.28
						var to_bank := bank - water
						_yaw[i] = atan2(to_bank.x, to_bank.z) + (_seed[i] - 0.5)
			PEEK:
				if nearest < dive_range * 1.4:
					_state[i] = UNDER
					_wait[i] = _rng.randf_range(under_time.x, under_time.y) * 0.6
					continue
				_wait[i] -= delta
				if _wait[i] <= 0.0:
					if nearest < hush_range:
						_wait[i] = _rng.randf_range(1.5, 4.0)
					else:
						# Out again, and back to its place.
						_state[i] = CLIMB
						_from[i] = here
						_to[i] = bank
						_t[i] = 0.0
						_dur[i] = 0.32
	_write()
	(_rings.material_override as ShaderMaterial).set_shader_parameter(&"now", _time)
	if _voice:
		var loud := chorus * clampf(float(singing) / maxf(count * 0.6, 1.0), 0.0, 1.0)
		if loud > 0.01 and not _voice.playing:
			_voice.play(_rng.randf_range(0.0, 3.5))
		elif loud <= 0.01 and _voice.playing:
			_voice.stop()
		_voice.volume_db = volume_db + linear_to_db(maxf(loud, 0.001))


func _sit(i: int) -> void:
	_state[i] = SIT
	var bank: Vector3 = banks[i][0]
	var water: Vector3 = banks[i][1]
	_px[i] = bank.x
	_py[i] = bank.y
	_pz[i] = bank.z
	var to := water - bank
	_yaw[i] = atan2(to.x, to.z) + (_seed[i] - 0.5) * 1.4
	_wait[i] = _rng.randf_range(2.0, 10.0)
	_fright[i] = -1.0


func _frighten(i: int, after: float) -> void:
	if _fright[i] < 0.0 or _fright[i] > after:
		_fright[i] = after


## Into the water, at its place in it.
func _dive(i: int) -> void:
	_fright[i] = -1.0
	_state[i] = DIVE
	_from[i] = Vector3(_px[i], _py[i], _pz[i])
	var water: Vector3 = banks[i][1]
	_to[i] = water - Vector3.UP * 0.05
	var to := water - _from[i]
	_yaw[i] = atan2(to.x, to.z)
	_t[i] = 0.0
	_dur[i] = 0.26 + 0.06 * _seed[i]


func _splash(at: Vector3) -> void:
	var ring := _ring_next
	_ring_next = (_ring_next + 1) % RINGS
	var k := ring * 16
	# (a flat ring on the water; its size grows in the shader, from when it began)
	var t := Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.06)
	_ring_buffer[k] = t.basis.x.x
	_ring_buffer[k + 1] = t.basis.y.x
	_ring_buffer[k + 2] = t.basis.z.x
	_ring_buffer[k + 3] = t.origin.x
	_ring_buffer[k + 4] = t.basis.x.y
	_ring_buffer[k + 5] = t.basis.y.y
	_ring_buffer[k + 6] = t.basis.z.y
	_ring_buffer[k + 7] = t.origin.y
	_ring_buffer[k + 8] = t.basis.x.z
	_ring_buffer[k + 9] = t.basis.y.z
	_ring_buffer[k + 10] = t.basis.z.z
	_ring_buffer[k + 11] = t.origin.z
	_ring_buffer[k + 12] = _time
	_ring_buffer[k + 13] = 1.0
	_ring_buffer[k + 14] = 0.0
	_ring_buffer[k + 15] = 0.0
	_rings.multimesh.buffer = _ring_buffer
	(_rings.material_override as ShaderMaterial).set_shader_parameter(&"now", _time)
	if not _plops.is_empty() and _plopped <= 0.0:
		var plop := _plops[_plop_next]
		_plop_next = (_plop_next + 1) % _plops.size()
		plop.global_position = at
		plop.stream = plop_sound(_rng.randi() % 3)
		plop.pitch_scale = _rng.randf_range(0.9, 1.15)
		plop.play()
		_plopped = 0.07


# Every frog into the MultiMesh: where, which way, how big, its pose (leap, croak, seed).
func _write() -> void:
	for i in count:
		var at := i * 16
		var state := _state[i]
		if state == GONE or state == UNDER:
			for k in 16:
				_buffer[at + k] = 0.0
			continue
		var size := _size[i]
		var forward := Vector3(sin(_yaw[i]), 0.0, cos(_yaw[i]))
		var basis := Basis.looking_at(-forward, Vector3.UP)
		var leap := 0.0
		var croak := 0.0
		match state:
			SIT:
				# (singing: each in its own time, a run of two or three throat-swells)
				if _hushed[i] <= 0.0 and chorus > 0.02:
					var period := lerpf(9.0, 2.6, chorus) * (0.8 + 0.5 * _seed[i])
					var c := fposmod(_time + _croak_at[i], period)
					if c < 0.75:
						croak = absf(sin(c / 0.25 * PI)) * 0.9
				else:
					# (still, the throat only pulsing a little)
					croak = 0.08 + 0.06 * sin(_time * 6.0 + _seed[i] * 20.0)
			HOP, DIVE, CLIMB:
				var p := minf(_t[i] / _dur[i], 1.0)
				var a: Vector3 = _from[i]
				var b: Vector3 = _to[i]
				var flat := Vector2(b.x - a.x, b.z - a.z).length()
				var high := 0.16 + 0.1 * _seed[i]
				var slope := ((b.y - a.y) + 4.0 * high * (1.0 - 2.0 * p)) / maxf(flat, 0.2)
				basis = basis * Basis(Vector3.RIGHT, -clampf(atan(slope) * 0.8, -1.1, 1.1))
				leap = smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.6, 1.0, p) * (0.0 if state == DIVE else 1.0))
			PEEK:
				croak = 0.05
		basis = basis.scaled(Vector3.ONE * size)
		var origin := Vector3(_px[i], _py[i], _pz[i])
		_buffer[at] = basis.x.x
		_buffer[at + 1] = basis.y.x
		_buffer[at + 2] = basis.z.x
		_buffer[at + 3] = origin.x
		_buffer[at + 4] = basis.x.y
		_buffer[at + 5] = basis.y.y
		_buffer[at + 6] = basis.z.y
		_buffer[at + 7] = origin.y
		_buffer[at + 8] = basis.x.z
		_buffer[at + 9] = basis.y.z
		_buffer[at + 10] = basis.z.z
		_buffer[at + 11] = origin.z
		_buffer[at + 12] = leap
		_buffer[at + 13] = croak
		_buffer[at + 14] = _seed[i]
		_buffer[at + 15] = 0.0
	_drawn.multimesh.buffer = _buffer


# --- How they look ---

## Their material: the swarm's (FrogLook), with the colours of common and
## leopard frogs: olive and brown, a few green, spotted dark.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = FrogLook.swarm_material().shader
		_material.set_shader_parameter(&"colour_a", Color(0.21, 0.24, 0.1))
		_material.set_shader_parameter(&"colour_b", Color(0.26, 0.2, 0.11))
		_material.set_shader_parameter(&"colour_c", Color(0.18, 0.27, 0.12))
		_material.set_shader_parameter(&"colour_d", Color(0.3, 0.26, 0.15))
		_material.set_shader_parameter(&"colour_e", Color(0.2, 0.2, 0.14))
		_material.set_shader_parameter(&"belly", Color(0.62, 0.6, 0.48))
	return _material


const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float now = 0.0;
uniform float life = 1.6;
uniform vec3 tint : source_color = vec3(0.62, 0.64, 0.66);

varying float age;

void vertex() {
	age = (now - INSTANCE_CUSTOM.x) / life;
	float grow = 0.12 + 1.3 * sqrt(clamp(age, 0.0, 1.0));
	VERTEX.xz *= grow * step(0.5, INSTANCE_CUSTOM.y) * step(age, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	// (two thin rings, the inner a little behind the outer, thinning as they go)
	float width = mix(0.09, 0.025, clamp(age, 0.0, 1.0));
	float ring = max(1.0 - abs(r - 0.92) / width, (1.0 - abs(r - 0.62) / (width * 0.8)) * 0.6);
	// (they fade out by dithering, so nothing is blended)
	float fade = (1.0 - clamp(age, 0.0, 1.0)) * ring;
	float dither = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	if (fade < 0.3 + dither * 0.6) {
		discard;
	}
	ALBEDO = tint;
}
"""


static func ring_material() -> ShaderMaterial:
	if _ring_material == null:
		var shader := Shader.new()
		shader.code = RING_SHADER
		_ring_material = ShaderMaterial.new()
		_ring_material.shader = shader
	# (each pond its own: its own clock)
	return _ring_material.duplicate() as ShaderMaterial


# A pond: dark, still water in a ragged ring of wet black mud, its edge fading
# into the ground, and clumps of rushes standing round it.
func _pond() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pond"
	var mud := StandardMaterial3D.new()
	mud.vertex_color_use_as_albedo = true
	mud.roughness = 0.85
	mud.cull_mode = BaseMaterial3D.CULL_DISABLED
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.02, 0.022, 0.021)
	water.roughness = 0.3
	water.metallic_specular = 0.3
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sides := 40
	var lie := func(k: int, layer: int) -> float:
		return 1.0 + 0.09 * sin(k * TAU / sides * 3.0 + layer + _rng.randf() * 0.2) + 0.05 * sin(k * TAU / sides * 7.0 + 2.0)
	for layer in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_normal(Vector3.UP)
		var inner: Array[Vector3] = []
		var outer: Array[Vector3] = []
		for k in sides:
			var turn := TAU * k / sides
			var shape_k: float = lie.call(k, layer)
			var near := pool_radius * (0.95 if layer == 0 else 0.0) * shape_k
			var far := pool_radius * (1.4 if layer == 0 else 0.93) * shape_k
			inner.append(Vector3(cos(turn) * near, 0.0, sin(turn) * near))
			outer.append(Vector3(cos(turn) * far, 0.0, sin(turn) * far))
		for k in sides:
			var n := (k + 1) % sides
			if layer == 0:
				# (black wet mud at the water, fading out into the ground's own colour at its edge)
				var wet := Color(0.05, 0.045, 0.038)
				var dry := Color(0.16, 0.15, 0.13)
				for v: Array in [[inner[k], wet], [outer[k], dry], [outer[n], dry], [inner[k], wet], [outer[n], dry], [inner[n], wet]]:
					tool.set_color(v[1])
					tool.add_vertex(v[0])
			else:
				tool.add_vertex(Vector3.ZERO)
				tool.add_vertex(outer[k])
				tool.add_vertex(outer[n])
		var made := MeshInstance3D.new()
		made.mesh = tool.commit()
		made.material_override = mud if layer == 0 else water
		made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		made.position.y = 0.012 + 0.008 * layer
		holder.add_child(made)
	holder.add_child(_rushes())
	return holder


# Clumps of rushes round the pond: thin dark blades, all one mesh.
func _rushes() -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clumps := 5 + _rng.randi_range(0, 3)
	for c in clumps:
		var turn := _rng.randf() * TAU
		var middle := Vector3(cos(turn), 0.0, sin(turn)) * pool_radius * _rng.randf_range(0.9, 1.25)
		for b in _rng.randi_range(9, 16):
			var root := middle + Vector3(_rng.randf_range(-0.18, 0.18), 0.0, _rng.randf_range(-0.18, 0.18))
			var tall := _rng.randf_range(0.45, 1.1)
			var lean := Vector3(_rng.randf_range(-0.25, 0.25), 0.0, _rng.randf_range(-0.25, 0.25)) * tall
			var tip := root + Vector3.UP * tall + lean
			var across := Vector3(cos(turn + b), 0.0, sin(turn + b)) * 0.012
			var shade := Color(0.12, 0.13, 0.08).lerp(Color(0.2, 0.2, 0.12), _rng.randf())
			tool.set_color(shade * 0.7)
			tool.set_normal((lean.normalized() if lean.length() > 0.01 else Vector3.FORWARD).cross(Vector3.UP).normalized())
			tool.add_vertex(root - across)
			tool.add_vertex(root + across)
			tool.set_color(shade)
			tool.add_vertex(tip)
	var made := MeshInstance3D.new()
	made.mesh = tool.commit()
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.roughness = 1.0
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.material_override = look
	return made


# --- Their voices, made here ---

## The chorus: rib-bits (two or three buzzing pulses), the low purring snore of
## the leopard frog, and the grating purr of the common frog, high and low,
## overlapping, in a loop of five seconds.
static func chorus_sound() -> AudioStreamWAV:
	if _chorus:
		return _chorus
	var rate := 22050
	var long := rate * 5
	var samples := PackedFloat32Array()
	samples.resize(long)
	var chance := RandomNumberGenerator.new()
	chance.seed = 9
	for call in 34:
		var start := chance.randi_range(0, long - 1)
		var kind := chance.randi() % 3
		var pitch := chance.randf_range(320.0, 620.0) if kind == 0 else chance.randf_range(140.0, 260.0)
		var buzz := chance.randf_range(40.0, 70.0) if kind == 0 else chance.randf_range(16.0, 30.0)
		var pulses := chance.randi_range(2, 3) if kind == 0 else 1
		var length_each := chance.randf_range(0.05, 0.08) if kind == 0 else chance.randf_range(0.5, 1.2)
		var loud := chance.randf_range(0.2, 0.5) * (1.0 if kind == 0 else 0.7)
		for pulse in pulses:
			var at := start + int(pulse * rate * 0.11)
			var length := int(rate * length_each)
			var phase := 0.0
			for k in length:
				var t := float(k) / rate
				phase += pitch * (1.0 - 0.12 * float(k) / length) / rate
				var tone := fposmod(phase, 1.0) * 2.0 - 1.0
				# (a snore is a rattle: the voice beaten hard, on and off)
				var throb := 0.5 + 0.5 * sin(t * buzz * TAU)
				throb = throb * throb if kind > 0 else throb
				var shape := sin(float(k) / length * PI)
				samples[(at + k) % long] += tone * throb * shape * loud
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	var loudest := 0.001
	for k in long:
		loudest = maxf(loudest, absf(samples[k]))
	for k in long:
		low += (samples[k] / loudest - low) * 0.4
		data.encode_s16(k * 2, int(clampf(low * 0.85, -1.0, 1.0) * 28000.0))
	_chorus = AudioStreamWAV.new()
	_chorus.format = AudioStreamWAV.FORMAT_16_BITS
	_chorus.mix_rate = rate
	_chorus.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_chorus.loop_end = long
	_chorus.data = data
	return _chorus


## A plop: a frog going into the water (a bubble's quick rising note over a little splash).
static func plop_sound(which: int) -> AudioStreamWAV:
	while _plop.size() < 3:
		var rate := 22050
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + _plop.size()
		var length := int(rate * 0.22)
		var data := PackedByteArray()
		data.resize(length * 2)
		var phase := 0.0
		var base := rng.randf_range(420.0, 650.0)
		var hiss := 0.0
		for k in length:
			var t := float(k) / rate
			phase += base * (1.0 + 2.2 * minf(t / 0.06, 1.0)) / rate
			var bubble := sin(TAU * phase) * exp(-t * 38.0)
			hiss += (rng.randf_range(-1.0, 1.0) - hiss) * 0.3
			var splash := hiss * exp(-t * 24.0) * 0.35 * smoothstep(0.0, 0.005, t)
			data.encode_s16(k * 2, int(clampf((bubble * 0.8 + splash) * 0.8, -1.0, 1.0) * 26000.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = data
		_plop.append(stream)
	return _plop[which % 3]
