class_name FrogSwarm
extends Node3D
## A swarm of frogs: dozens of small frogs (fist- to cat-sized) that pour out
## of a muddy pool (this node is the pool: the `nest`) and come across the
## ground at whoever is their `target` in hopping waves, leaping over each
## other, croaking in chorus; those that reach him leap onto him and cling,
## and enough of them on him for long enough bring him down (`caught`). It
## knows nothing of any game: it looks, moves and says when it has caught
## someone. `FrogSwarm.new()` is a whole one.
##
##     var swarm := FrogSwarm.new()
##     swarm.count = 70
##     swarm.position = the_puddle
##     add_child(swarm)
##     swarm.target = player          # any Node3D (its `velocity`, if it has one, is read)
##     swarm.caught.connect(...)
##     swarm.chasing = true           # out they come; `false` calls them home; `reset()` puts them back at once
##     player_speed_scale = 1.0 - 0.6 * swarm.burden()   # (how much they weigh on him: the game slows him)
##
## After the frog swarms of film and folklore (plagues of frogs; the rain of
## frogs in Magnolia; the toads that pour over the road in spring):
## - Out of the pool they come `pour_rate` a second, and hop at him: each hop
##   an arc, longer for bigger frogs, a short sit between; they go round each
##   other's landing places, so the ones behind leap over the ones in front.
##   On the whole they go `speed` m/s: faster than a walk, slower than a run.
## - Those that reach him leap onto him and cling (on his legs, his back, his
##   chest), kicking. Running hard or jumping shakes them off a few at a time
##   (they hold on `cling_time` or so each). `catch_count` on him for
##   `catch_time` and he is `caught`.
## - They hop no higher than `climb` (onto a step, a ledge) nor down more than
##   `drop`: anyone up on something higher is out of their reach. When they
##   have got no nearer for `give_up_after` seconds, or he is further than
##   `chase_distance` from the pool, they hop home and dive back in.
## - Quiet, a few (`lurkers`) sit about the edge of the pool, throats pulsing,
##   croaking now and then.
##
## The cost is flat. A frog has no body: all of them are one MultiMesh, moved
## here in one loop and written to it in one piece; their hops and the throats
## that blow up as they croak are blended in the shader (FrogLook) from two
## poses baked into the model (creatures/frog/models/frog.glb, built by
## tools/build_frogs.py). The ground is found with a ray straight down, once
## for each square of a grid (`CELL` across) round the pool as a frog first
## lands in it, and remembered (as Outside's scarab swarm does).

## Enough of them on `who` for long enough.
signal caught(who: Node3D)
signal came_out
signal went_home

## How many frogs.
@export_range(1, 300) var count := 70
## How long the smallest and the biggest are, metres (most are small).
@export var frog_size := Vector2(0.12, 0.32)
## How fast they come on the whole, metres a second.
@export var speed := 3.4
## How far from the pool they will follow anyone.
@export var chase_distance := 40.0
## How many come out of the pool a second.
@export var pour_rate := 40.0
## The highest they hop up, and the furthest down (m).
@export var climb := 0.7
@export var drop := 2.5
## How many on him bring him down (never more than a third of them), and for how long.
@export var catch_count := 10
@export var catch_time := 1.2
## About how long each holds on while he runs or jumps, seconds.
@export var cling_time := 1.4
## How long they go on when they are getting no nearer, seconds.
@export var give_up_after := 6.0
## Whether they can catch anyone (off: they cling, but nobody is caught; as on a machine that only shows them).
@export var can_catch := true
## How many sit about the pool while all is quiet.
@export var lurkers := 7
## The pool they come out of, drawn on the ground.
@export var pool := true
@export var pool_radius := 1.3
## Their croaking.
@export var voice := true
## What the ground is made of, for the rays that find it.
@export_flags_3d_physics var ground_mask := 1

## Who they are after.
var target: Node3D
## Whether they are out after `target`. Setting it lets them out or calls them home.
var chasing: bool:
	get:
		return _mode == Mode.HUNT
	set(value):
		if value:
			release()
		else:
			recall()
## How many are out of the pool, and how many of those are on him.
var out := 0
var on_target := 0

enum Mode { DORMANT, HUNT, HOME }
const HIDDEN := 0
const SIT := 1
const HOP := 2
const ON := 3
const FLUNG := 4

## The side of a square of the ground they remember, metres.
const CELL := 0.25
const BLOCKED := 1000000.0
## How many squares of ground are looked at afresh in one frame, at most.
const RAYS := 24
## How many frogs to a square before they land elsewhere.
const CROWD := 2
const MODEL := "res://creatures/frog/models/frog.glb"

var _mode := Mode.DORMANT
var _time := 0.0
var _pour := 0.0
var _next_out := 0
var _meter := 0.0
var _fed := false
var _best_seen := INF
var _stuck_for := 0.0
var _home_for := 0.0
var _rays := 0
var _front := Vector3.ZERO

# Each frog.
var _state := PackedByteArray()
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _pz := PackedFloat32Array()
var _hx := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _ax := PackedFloat32Array()
var _ay := PackedFloat32Array()
var _az := PackedFloat32Array()
var _bx := PackedFloat32Array()
var _by := PackedFloat32Array()
var _bz := PackedFloat32Array()
var _t := PackedFloat32Array()
var _dur := PackedFloat32Array()
var _high := PackedFloat32Array()
var _size := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _wait := PackedFloat32Array()
var _onto := PackedByteArray()
var _spin := PackedFloat32Array()

var _nest := Vector3.ZERO
var _width := 0
var _corner := Vector2.ZERO
var _heights := PackedFloat32Array()
var _crowd := PackedByteArray()
var _crowded := PackedInt32Array()

var _drawn: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _voice: AudioStreamPlayer3D
var _query: PhysicsRayQueryParameters3D
var _rng := RandomNumberGenerator.new()

static var _mesh: ArrayMesh
static var _chorus: AudioStreamWAV


func _ready() -> void:
	_rng.randomize()
	_nest = global_position
	var reach := chase_distance + 4.0
	_width = clampi(ceili(reach * 2.0 / CELL) + 1, 8, 400)
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.resize(_width * _width)
	_heights.fill(NAN)
	_crowd.resize(_width * _width)
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = ground_mask
	_query.hit_from_inside = true

	for list: PackedFloat32Array in [_px, _py, _pz, _hx, _hz, _ax, _ay, _az, _bx, _by, _bz, _t, _dur, _high, _size, _seed, _wait, _spin]:
		list.resize(count)
	_state.resize(count)
	_onto.resize(count)
	for i in count:
		_seed[i] = _rng.randf()
		_size[i] = lerpf(frog_size.x, frog_size.y, pow(_rng.randf(), 1.8))
		_hz[i] = 1.0

	_drawn = MultiMeshInstance3D.new()
	_drawn.top_level = true
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = mesh()
	many.instance_count = count
	_drawn.multimesh = many
	_drawn.material_override = FrogLook.swarm_material()
	add_child(_drawn)
	_drawn.global_transform = Transform3D.IDENTITY
	_drawn.custom_aabb = AABB(_nest - Vector3(reach, 6.0, reach), Vector3(reach * 2.0, 12.0, reach * 2.0))
	_buffer.resize(count * 16)
	many.buffer = _buffer

	if pool:
		add_child(_pool_mesh())
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = chorus_sound()
		_voice.unit_size = 5.0
		_voice.max_distance = 45.0
		_voice.top_level = true
		add_child(_voice)
	reset()


## The little frog, as the swarm draws it: one surface, the leap and the
## croak in CUSTOM0 and CUSTOM1 (how far each point moves for them), how light
## the point is in CUSTOM0.w. One for every swarm.
static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var scene := load(MODEL) as PackedScene
	var root := scene.instantiate()
	var piece := root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var from := piece.mesh as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var arrays := from.surface_get_arrays(0)
	var shapes := from.surface_get_blend_shape_arrays(0)
	var names := {}
	for k in from.get_blend_shape_count():
		names[String(from.get_blend_shape_name(k))] = k
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var leap: PackedVector3Array = shapes[names.get("leap", 0)][Mesh.ARRAY_VERTEX]
	var croak: PackedVector3Array = shapes[names.get("croak", 1)][Mesh.ARRAY_VERTEX]
	var relative := from.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if order.is_empty():
		order.resize(points.size())
		for i in points.size():
			order[i] = i
	for i in order:
		var p := points[i]
		var a := leap[i] if relative else leap[i] - p
		var b := croak[i] if relative else croak[i] - p
		var c := colours[i] if i < colours.size() else Color(0.12, 0.14, 0.05)
		st.set_custom(0, Color(a.x, a.y, a.z, c.r * 0.3 + c.g * 0.59 + c.b * 0.11))
		st.set_custom(1, Color(b.x, b.y, b.z, 0.0))
		st.set_normal(normals[i])
		st.set_uv(uvs[i])
		st.set_uv2(uv2s[i])
		st.add_vertex(p)
	root.free()
	_mesh = st.commit()
	return _mesh


## Lets them out after `target`.
func release() -> void:
	if _mode == Mode.HUNT:
		return
	_mode = Mode.HUNT
	_fed = false
	_meter = 0.0
	_best_seen = INF
	_stuck_for = 0.0
	came_out.emit()


## Calls them home: they hop back to the pool and dive in.
func recall() -> void:
	if _mode != Mode.HUNT:
		return
	_mode = Mode.HOME
	for i in count:
		if _state[i] == ON:
			_let_go(i, Vector3.ZERO)
		elif _state[i] == HOP and _onto[i] == 1:
			_onto[i] = 0


## Puts them all back in the pool at once (a few sitting about it), as to begin with.
func reset() -> void:
	_mode = Mode.DORMANT
	_fed = false
	_meter = 0.0
	_state.fill(HIDDEN)
	_buffer.fill(0.0)
	out = 0
	on_target = 0
	_front = _nest
	for i in mini(lurkers, count):
		_lurk(i)
	_write_all()


## How much they weigh on him, 0..1 (1: as many on him as catch him).
func burden() -> float:
	return clampf(float(on_target) / float(_needed()), 0.0, 1.0)


## How near they are to catching him, 0..1.
func danger() -> float:
	return clampf(_meter / maxf(catch_time, 0.01), 0.0, 1.0)


## Where the front of them is (the frog nearest `target`, or the pool).
func front() -> Vector3:
	return _front


## Whether they are all in the pool (bar the lurkers).
func home() -> bool:
	return _mode == Mode.DORMANT


func frog_position(i: int) -> Vector3:
	return Vector3(_px[i], _py[i], _pz[i])


func frog_state(i: int) -> int:
	return _state[i]


func _needed() -> int:
	return mini(catch_count, maxi(count / 3, 1))


# A frog sitting about the edge of the pool.
func _lurk(i: int) -> void:
	var way := TAU * float(i) / float(maxi(lurkers, 1)) + _seed[i]
	var far := pool_radius * (0.85 + 0.35 * _seed[i])
	_state[i] = SIT
	_px[i] = _nest.x + cos(way) * far
	_pz[i] = _nest.z + sin(way) * far
	var under := _probe(_px[i], _pz[i], _nest.y)
	_py[i] = under if under < BLOCKED else _nest.y
	# (facing out of the pool, mostly)
	var look := way + (_seed[i] - 0.5) * 1.6
	_hx[i] = cos(look)
	_hz[i] = sin(look)
	_wait[i] = _rng.randf_range(2.0, 8.0)
	out += 1


func _physics_process(delta: float) -> void:
	_time += delta
	if _mode == Mode.DORMANT and global_position.distance_squared_to(_nest) > 0.0025:
		_move_nest()
	_rays = RAYS
	var him := Vector3.INF
	var shaking := false
	var going := Vector3.ZERO
	if target and is_instance_valid(target) and target.is_inside_tree():
		him = target.global_position
		var v: Variant = target.get(&"velocity")
		if v is Vector3:
			going = v
		shaking = Vector2(going.x, going.z).length() > 3.6 or absf(going.y) > 2.0
	var hunting := _mode == Mode.HUNT and him.is_finite()
	if _mode == Mode.HUNT:
		if not him.is_finite() or (Vector2(him.x - _nest.x, him.z - _nest.z).length() > chase_distance and on_target == 0):
			recall()
			hunting = false
	_home_for = _home_for + delta if _mode == Mode.HOME else 0.0
	if _mode == Mode.HOME and out == 0:
		_mode = Mode.DORMANT
		for i in mini(lurkers, count):
			_lurk(i)
		went_home.emit()

	# Out of the pool, so many a second.
	if hunting and out < count:
		_pour += pour_rate * delta
		while _pour >= 1.0 and out < count:
			_pour -= 1.0
			for tries in count:
				_next_out = (_next_out + 1) % count
				if _state[_next_out] == HIDDEN:
					break
			_come_out(_next_out)

	var latched := 0
	var best := INF
	var best_at := _nest
	for i in count:
		var state := _state[i]
		if state == HIDDEN:
			continue
		var seed := _seed[i]
		match state:
			SIT:
				_wait[i] -= delta
				if _mode == Mode.DORMANT:
					if _wait[i] <= 0.0:
						# (a lurker turns about, now and then)
						var turn := (seed - 0.5) * 2.0 + _rng.randf_range(-0.8, 0.8)
						var hx := _hx[i]
						_hx[i] = hx * cos(turn) - _hz[i] * sin(turn)
						_hz[i] = hx * sin(turn) + _hz[i] * cos(turn)
						_wait[i] = _rng.randf_range(2.0, 8.0)
				elif _wait[i] <= 0.0 and _mode == Mode.HOME and _home_for > 9.0:
					# (one that cannot find its way back sinks into the mud where it is)
					_state[i] = HIDDEN
					out -= 1
					continue
				elif _wait[i] <= 0.0:
					_plan_hop(i, him, hunting)
			HOP:
				_t[i] += delta
				var p := minf(_t[i] / _dur[i], 1.0)
				_px[i] = lerpf(_ax[i], _bx[i], p)
				_pz[i] = lerpf(_az[i], _bz[i], p)
				var end_y := _by[i]
				if _onto[i] == 1 and him.is_finite():
					# (aiming at him as he moves)
					_bx[i] = lerpf(_bx[i], him.x + _hx[i] * -0.25, minf(delta * 6.0, 1.0))
					_bz[i] = lerpf(_bz[i], him.z + _hz[i] * -0.25, minf(delta * 6.0, 1.0))
					end_y = him.y + 0.3 + seed * 0.6
				_py[i] = lerpf(_ay[i], end_y, p) + 4.0 * _high[i] * p * (1.0 - p)
				if p >= 1.0:
					if _onto[i] == 1 and hunting and not _fed and Vector2(_px[i] - him.x, _pz[i] - him.z).length() < 0.9 and absf(_py[i] - him.y - 0.6) < 1.1:
						_state[i] = ON
						_t[i] = atan2(_pz[i] - him.z, _px[i] - him.x)
						_ay[i] = clampf(_py[i] - him.y, 0.15, 1.5)
						_wait[i] = cling_time * (0.5 + seed)
					else:
						_state[i] = SIT
						_py[i] = _by[i] if _onto[i] == 0 else _ground_at(_px[i], _pz[i], _py[i])
						_wait[i] = _rng.randf_range(0.02, 0.22)
						if _mode == Mode.HOME and Vector2(_px[i] - _nest.x, _pz[i] - _nest.z).length() < pool_radius * 0.7:
							_state[i] = HIDDEN
							out -= 1
					_onto[i] = 0
			ON:
				if not hunting or _fed:
					_let_go(i, going)
					continue
				latched += 1
				# Round him and up him; shaken off as he runs or jumps.
				if shaking:
					_wait[i] -= delta
				if _wait[i] <= 0.0 or target.global_position.distance_to(Vector3(_px[i], _py[i], _pz[i])) > 3.0:
					_let_go(i, going)
					continue
				_t[i] += delta * (seed - 0.5) * 1.5
				var top := 0.25 + seed * 1.15
				_ay[i] = move_toward(_ay[i], top, delta * 0.4)
				var round_him := 0.24 + _size[i] * 0.45 - _ay[i] * 0.03
				_px[i] = him.x + cos(_t[i]) * round_him
				_pz[i] = him.z + sin(_t[i]) * round_him
				_py[i] = him.y + _ay[i]
			FLUNG:
				_by[i] -= 14.0 * delta
				_px[i] += _ax[i] * delta
				_py[i] += _by[i] * delta
				_pz[i] += _az[i] * delta
				_spin[i] += delta * 12.0
				var under := _ground_at(_px[i], _pz[i], _py[i] + 0.3)
				if _py[i] <= under:
					_py[i] = under
					_state[i] = SIT
					_spin[i] = 0.0
					_wait[i] = 0.4 + seed * 0.5
		if hunting and _state[i] != HIDDEN:
			var gap := Vector2(_px[i] - him.x, _pz[i] - him.z).length()
			if gap < best:
				best = gap
				best_at = Vector3(_px[i], _py[i], _pz[i])
	on_target = latched
	_front = best_at if best < INF else _nest
	_write_all()

	if _voice:
		var croakers := out if _mode != Mode.DORMANT else 2
		var loud := clampf(croakers / 25.0, 0.0, 1.0)
		_voice.global_position = _front
		if loud > 0.0 and not _voice.playing:
			_voice.play()
		elif loud <= 0.0 and _voice.playing:
			_voice.stop()
		_voice.volume_db = linear_to_db(maxf(loud, 0.01)) - 6.0

	if hunting:
		# Enough of them on him for long enough, and he is down.
		if latched >= _needed() and not _fed:
			_meter += delta
			if _meter >= catch_time and can_catch:
				_fed = true
				caught.emit(target)
				recall()
				return
		else:
			_meter = maxf(_meter - delta * 0.6, 0.0)
		# Getting no nearer, with nothing to show for it: they give up.
		if latched > 0 or out < count * 0.5:
			_best_seen = best
			_stuck_for = 0.0
		elif best < _best_seen - 0.4:
			_best_seen = best
			_stuck_for = 0.0
		else:
			_stuck_for += delta
			if _stuck_for > give_up_after:
				recall()


func _come_out(i: int) -> void:
	var way := _rng.randf() * TAU
	if _state[i] == HIDDEN:
		out += 1
		_px[i] = _nest.x + cos(way) * pool_radius * 0.4
		_pz[i] = _nest.z + sin(way) * pool_radius * 0.4
		_py[i] = _nest.y - _size[i] * 0.3
		_hx[i] = cos(way)
		_hz[i] = sin(way)
	_state[i] = SIT
	_wait[i] = _rng.randf_range(0.0, 0.15)


# The next hop: at him (or home), round walls and the others' landing places;
# onto him, if he is near enough to leap onto.
func _plan_hop(i: int, him: Vector3, hunting: bool) -> void:
	var x := _px[i]
	var y := _py[i]
	var z := _pz[i]
	var seed := _seed[i]
	var size := _size[i]
	var bigness := inverse_lerp(frog_size.x, maxf(frog_size.y, frog_size.x + 0.01), size)
	var length := lerpf(0.9, 1.9, bigness)
	var dur := lerpf(0.3, 0.42, bigness)
	var goal := _nest
	if hunting:
		# (spread out across his way, so they come as a wave, not a string)
		var across := Vector3(-(him.z - z), 0.0, him.x - x).normalized()
		goal = him + across * (seed - 0.5) * 1.6
	var to := Vector2(goal.x - x, goal.z - z)
	var far := to.length()
	if hunting:
		var gap := Vector2(him.x - x, him.z - z).length()
		var up := him.y - y
		if gap < length * 0.9 + 0.3 and up > -0.6 and up < climb + 1.0 and not _fed:
			# Onto him.
			_hop(i, Vector3(him.x, him.y, him.z), dur, 0.35 + up * 0.3 + seed * 0.3, true)
			return
	if far < 0.05:
		_wait[i] = 0.3
		return
	var dir := to / far
	if _mode == Mode.HOME:
		length = minf(length, far)
	else:
		length = minf(length * (0.8 + 0.4 * seed), maxf(far, 0.4))
	var swerve := (_rng.randf() - 0.5) * 0.7
	for attempt in 7:
		var angle: float = swerve + [0.0, 0.6, -0.6, 1.2, -1.2, 2.0, -2.0][attempt]
		var d := dir.rotated(angle)
		var reach := length * (1.0 if attempt < 5 else 0.5)
		var lx := x + d.x * reach
		var lz := z + d.y * reach
		var ground := _height(lx, lz, y)
		if ground >= BLOCKED or ground - y > climb or y - ground > drop:
			continue
		var cell := _cell(lx, lz)
		if cell >= 0 and _crowd[cell] >= CROWD and attempt < 4:
			continue
		# (and nothing in the way between: a wall)
		var middle := _height(x + d.x * reach * 0.5, z + d.y * reach * 0.5, y)
		if middle >= BLOCKED or middle - y > climb + 0.3:
			continue
		_hop(i, Vector3(lx, ground, lz), dur * (0.7 + 0.3 * reach / maxf(length, 0.01)), 0.18 + reach * 0.22 + seed * 0.2, false)
		return
	# Nowhere to go: it sits a moment.
	_wait[i] = 0.25


func _hop(i: int, to: Vector3, dur: float, high: float, onto: bool) -> void:
	_state[i] = HOP
	_ax[i] = _px[i]
	_ay[i] = _py[i]
	_az[i] = _pz[i]
	_bx[i] = to.x
	_by[i] = to.y
	_bz[i] = to.z
	_t[i] = 0.0
	_dur[i] = dur
	_high[i] = high
	_onto[i] = 1 if onto else 0
	var flat := Vector2(to.x - _px[i], to.z - _pz[i])
	if flat.length() > 0.01:
		flat = flat.normalized()
		_hx[i] = flat.x
		_hz[i] = flat.y
	var old := _cell(_px[i], _pz[i])
	if old >= 0 and _crowd[old] > 0:
		_crowd[old] -= 1
	var cell := _cell(to.x, to.z)
	if cell >= 0 and not onto and _crowd[cell] < 250:
		_crowd[cell] += 1


# Off him: thrown the way he was going, and out.
func _let_go(i: int, going: Vector3) -> void:
	var way := _t[i]
	_state[i] = FLUNG
	_ax[i] = going.x * 0.5 + cos(way) * 1.8
	_az[i] = going.z * 0.5 + sin(way) * 1.8
	_by[i] = 2.0 + going.y * 0.3
	_spin[i] = 0.0


# Every frog into the MultiMesh: where it is, which way it faces, how it is tipped, how big, and its pose.
func _write_all() -> void:
	var him := target.global_position if target and is_instance_valid(target) and target.is_inside_tree() else Vector3.INF
	for i in count:
		var at := i * 16
		var state := _state[i]
		if state == HIDDEN:
			for k in 16:
				_buffer[at + k] = 0.0
			continue
		var size := _size[i]
		var forward := Vector3(_hx[i], 0.0, _hz[i])
		var basis := Basis.IDENTITY
		var leap := 0.0
		var croak := 0.0
		var kick := 0.0
		var origin := Vector3(_px[i], _py[i], _pz[i])
		match state:
			SIT:
				basis = Basis.looking_at(-forward, Vector3.UP)
				# (now and then its throat blows up: a croak)
				var c := fposmod(_time * 1.3 + _seed[i] * 9.0, 4.0 + _seed[i] * 3.0)
				croak = sin(clampf(c / 0.45, 0.0, 1.0) * PI) if c < 0.45 else 0.0
			HOP:
				var p := minf(_t[i] / _dur[i], 1.0)
				var flat := Vector2(_bx[i] - _ax[i], _bz[i] - _az[i]).length()
				var slope := ((_by[i] - _ay[i]) + 4.0 * _high[i] * (1.0 - 2.0 * p)) / maxf(flat, 0.2)
				var pitch := clampf(atan(slope) * 0.7, -0.9, 0.9)
				basis = Basis.looking_at(-forward, Vector3.UP) * Basis(Vector3.RIGHT, -pitch)
				leap = smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.55, 0.95, p))
			ON:
				if him.is_finite():
					var out_way := Vector3(_px[i] - him.x, 0.0, _pz[i] - him.z).normalized()
					# (belly to him, head up, its back out)
					var z := Vector3.UP
					var y := out_way
					basis = Basis(y.cross(z).normalized(), y, z)
					origin -= out_way * size * 0.15
				leap = 0.35
				kick = _time * 14.0 + _seed[i] * 10.0
			FLUNG:
				basis = Basis.looking_at(-forward, Vector3.UP) * Basis(Vector3.RIGHT, _spin[i])
				leap = 0.6
				kick = _time * 18.0 + _seed[i] * 10.0
		basis = basis.scaled(Vector3.ONE * size)
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
		_buffer[at + 15] = kick
	_drawn.multimesh.buffer = _buffer


# --- The ground ---

func _cell(x: float, z: float) -> int:
	var cx := int((x - _corner.x) / CELL)
	var cz := int((z - _corner.y) / CELL)
	if cx < 0 or cz < 0 or cx >= _width or cz >= _width:
		return -1
	return cz * _width + cx


# How high the ground is at a place, for a frog at the height `from`: remembered, or looked for now.
func _height(x: float, z: float, from: float) -> float:
	var index := _cell(x, z)
	if index < 0:
		return BLOCKED
	var known := _heights[index]
	if known == known:
		return known
	if _rays <= 0:
		# (enough looking for one frame: it goes on as if the ground were level, and looks next time)
		return from
	_rays -= 1
	known = _probe(_corner.x + (index % _width + 0.5) * CELL, _corner.y + (index / _width + 0.5) * CELL, from)
	_heights[index] = known
	return known


# The ground under a frog that is coming down (not blocked: where it is, if nothing is known).
func _ground_at(x: float, z: float, from: float) -> float:
	var h := _height(x, z, from)
	return h if h < BLOCKED else _nest.y


# Looks straight down for the ground.
func _probe(x: float, z: float, from: float) -> float:
	if not is_inside_tree():
		return BLOCKED
	_query.from = Vector3(x, from + climb + 0.45, z)
	_query.to = Vector3(x, from - drop - 0.6, z)
	var found := get_world_3d().direct_space_state.intersect_ray(_query)
	if found.is_empty():
		return BLOCKED
	var high: float = found.position.y
	if found.normal == Vector3.ZERO:
		# (it started inside something: a wall)
		return BLOCKED
	return high


# --- The pool ---

# A muddy pool: a ragged ring of wet mud round dark, still water.
func _pool_mesh() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pool"
	var mud := StandardMaterial3D.new()
	mud.albedo_color = Color(0.09, 0.07, 0.045)
	mud.roughness = 0.45
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.03, 0.03, 0.022)
	water.roughness = 0.3
	water.metallic_specular = 0.25
	mud.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	for layer in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides := 18
		var rim: Array[Vector3] = []
		for k in sides:
			var turn := TAU * k / sides
			var far := pool_radius * (1.25 if layer == 0 else 0.85) * (1.0 + 0.12 * sin(k * 2.3 + layer) + 0.07 * sin(k * 5.1))
			rim.append(Vector3(cos(turn) * far, 0.0, sin(turn) * far))
		tool.set_normal(Vector3.UP)
		for k in sides:
			tool.add_vertex(Vector3.ZERO)
			tool.add_vertex(rim[(k + 1) % sides])
			tool.add_vertex(rim[k])
		var shape := MeshInstance3D.new()
		shape.mesh = tool.commit()
		shape.material_override = mud if layer == 0 else water
		shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shape.position.y = 0.012 + 0.006 * layer
		holder.add_child(shape)
	return holder


# --- Their voices ---

## A chorus of frogs, made here: dozens of croaks (each two or three buzzing
## pulses, a "rib-bit"), high and low, overlapping, in a loop of four seconds.
static func chorus_sound() -> AudioStreamWAV:
	if _chorus:
		return _chorus
	var rate := 22050
	var long := rate * 4
	var samples := PackedFloat32Array()
	samples.resize(long)
	var chance := RandomNumberGenerator.new()
	chance.seed = 5
	for croak in 46:
		var start := chance.randi_range(0, long - 1)
		var pitch := chance.randf_range(260.0, 720.0)
		var buzz := chance.randf_range(55.0, 95.0)
		var pulses := chance.randi_range(2, 3)
		var loud := chance.randf_range(0.15, 0.45)
		for pulse in pulses:
			var at := start + int(pulse * rate * 0.075)
			var length := int(rate * chance.randf_range(0.035, 0.05))
			var phase := 0.0
			for k in length:
				var t := float(k) / rate
				phase += pitch * (1.0 - 0.15 * float(k) / length) / rate
				var tone := fposmod(phase, 1.0) * 2.0 - 1.0
				var throb := 0.5 + 0.5 * sin(t * buzz * TAU)
				var shape := sin(float(k) / length * PI)
				var where := (at + k) % long
				samples[where] += tone * throb * shape * loud
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	for k in long:
		low += (samples[k] - low) * 0.45
		data.encode_s16(k * 2, int(clampf(low * 0.8, -1.0, 1.0) * 30000.0))
	_chorus = AudioStreamWAV.new()
	_chorus.format = AudioStreamWAV.FORMAT_16_BITS
	_chorus.mix_rate = rate
	_chorus.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_chorus.loop_end = long
	_chorus.data = data
	return _chorus


# The pool has been moved (put somewhere after it went in): everything it knew of the ground is forgotten.
func _move_nest() -> void:
	_nest = global_position
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.fill(NAN)
	_crowd.fill(0)
	var reach := _width * CELL * 0.5
	_drawn.custom_aabb = AABB(_nest - Vector3(reach, 6.0, reach), Vector3(reach * 2.0, 12.0, reach * 2.0))
	reset()
