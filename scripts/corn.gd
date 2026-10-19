class_name Corn
extends Node3D
## Fields of corn, after the cornfield in Inside (the user, 2026-10-18: "Lets also
## add corn like that one scene in the inside video"): dense, tall, dry, pale
## stalks, taller than the boy, that bend and sway apart round whoever pushes
## through and spring back behind them, rustling. You cannot see far through it,
## and something could be in it: deep in it, the hunters see you only near
## (`sight_reach`, asked by MazeNav.sees).
##
## A field is laid down as patches (`add_patch`: a rectangle of ground, which of
## its sides are open to ground without corn, things to keep out of), the stalks
## set in rows on one grid over the whole world so that patches side by side are
## one field. Each square of SQUARE metres is filled with its stalks only when
## the camera first comes near (a little each frame, FILL_BUDGET), as two
## MultiMeshes: the stalk with all its leaves near (`near`), a plainer one past
## that, out to where the mist has them (`far`). No colliders, no shadows cast.
##
##     var corn := Corn.new()
##     corn.add_patch(Rect2(...), Corn.OPEN_ALL, true, func(p: Vector2) -> float: return 0.0)
##     add_child(corn); corn.build()
##
## Bending is all in the vertex shader (each stalk curved along its length, its
## leaves turned with it): the wind (the weather's, when the world has one), a
## soft lean from anyone near (plant_push's `pushed`, as the low plants have it)
## and, for the stalks near enough to be shoved, a spring each (`_springs`), run
## here for at most MAX_SPRUNG of them: pushed away and to the side, they swing
## back past upright when left and settle. Where they go is MazeBuilder's
## (`plant_maze`: rooms and stretches of hall, MazeStyle "Plants") and Wilds'
## (the plains quarters' fields, DesertStyle "Plains"), from the seed.

## The sides of a patch (`open`): +x, -x, +z, -z.
const OPEN_EAST := 1
const OPEN_WEST := 2
const OPEN_SOUTH := 4
const OPEN_NORTH := 8
const OPEN_ALL := 15
## Metres across a square filled at once (and drawn as one pair of MultiMeshes).
const SQUARE := 8.0
## Metres between the rows, and between the stalks along a row.
const ROW := 0.9
const STEP := 0.62
## How tall the stalk mesh is, metres (each stalk is scaled 0.88 to 1.12 of it: 2.2 to 2.8 m).
const HEIGHT := 2.5
## How long a frame may spend filling squares, microseconds.
const FILL_BUDGET := 1500
## How far the camera must move before the squares wanted are worked out again.
const REPLAN := 3.0
## How many stalks can be sprung at once (the shader's `sprung`).
const MAX_SPRUNG := 64
## How many pushers each push their stalks aside and rustle (the nearest the camera).
const MAX_SHOVERS := 6
const MAX_VOICES := 3
## Metres across the squares the filled stalks are kept in, to find those near a pusher.
const GRID := 2.0
## How far the hunters see someone at the edge of the corn and deep in it, metres.
const SEEN_AT_EDGE := 30.0
const SEEN_DEEP := 8.0

## Per Grass.quality (phones LOW): how much of the stalks are kept, and how far
## the full stalk and the plainer one are drawn, metres.
const PRESETS := {
	Grass.Quality.LOW: {"density": 0.7, "near": 12.0, "far": 40.0},
	Grass.Quality.MEDIUM: {"density": 1.0, "near": 16.0, "far": 52.0},
	Grass.Quality.HIGH: {"density": 1.0, "near": 20.0, "far": 64.0},
}

## Mixed into the stalks' places, so that two fields are not alike.
var seed := 1

## Every patch: {rect, open, rows_x, ground, keep, mask}.
var _patches: Array = []
## The squares (Vector2i) -> the patches over each.
var _squares := {}
var _filled := {}
var _queue: Array = []
var _planned_for := Vector3.INF
var _preset: Dictionary
## The stalks filled so far, by squares of GRID metres: [x, y, z, height, ...].
var _grid := {}
var _stalks := 0

static var _meshes: Array[ArrayMesh] = []
static var _material: ShaderMaterial
## The corn fields in the world now.
static var _all: Array[Corn] = []
static var _frame := -1
## The springs of the stalks being pushed or springing back: a key from where
## the stalk stands -> [x, z, height, bend x, bend z, speed x, speed z, pushed to x, pushed to z].
static var _springs := {}
static var _last_at := {}
static var _rustle: AudioStreamWAV
static var _weather_from: Node
static var _weather_in := 0.0


## Lays down a patch of corn over `rect` (x, z, world metres). `open`: which of its
## sides (OPEN_*) meet ground with no corn (it thins raggedly towards them, and
## is deep only well in from them: the others are walls or more corn). Rows run
## along x if `rows_x`, else along z. `ground`: Vector2 (x, z) -> the height of
## the ground. `keep`: what it keeps off (Rect2s, and Vector3s: x, z and a radius).
## `mask`: optionally Vector2 -> more than 0 where a stalk may stand.
func add_patch(rect: Rect2, open: int, rows_x: bool, ground: Callable, keep: Array = [], mask := Callable()) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var index := _patches.size()
	_patches.append({"rect": rect, "open": open, "rows_x": rows_x, "ground": ground, "keep": keep, "mask": mask})
	for j in range(floori(rect.position.y / SQUARE), ceili(rect.end.y / SQUARE)):
		for i in range(floori(rect.position.x / SQUARE), ceili(rect.end.x / SQUARE)):
			var key := Vector2i(i, j)
			if not _squares.has(key):
				_squares[key] = []
			(_squares[key] as Array).append(index)


## Readies it to be filled near the camera (nothing is made yet).
func build() -> void:
	_preset = PRESETS[Grass.quality]
	material()
	set_process(true)


## How many patches, squares filled and stalks there are.
func counts() -> Vector3i:
	return Vector3i(_patches.size(), _filled.size(), _stalks)


func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)
	if _all.is_empty():
		_springs.clear()
		_last_at.clear()


# --- Where it is, for the hunters ------------------------------------------------

## How deep in corn `point` is: 0 out of it or at its edge, 1 a few metres in from
## any open side (and not up on a ledge over it).
static func cover_at(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var most := 0.0
	for field in _all:
		for index: int in field._squares.get(Vector2i((flat / SQUARE).floor()), []):
			var patch: Dictionary = field._patches[index]
			if not (patch.rect as Rect2).has_point(flat):
				continue
			if absf(point.y - float(patch.ground.call(flat))) > 2.0:
				continue
			most = maxf(most, clampf((_edge_in(patch, flat) - 0.6) / 2.4, 0.0, 1.0))
	return most


## How far off someone at `point` can be seen, at most `reach` metres: less the
## deeper in corn they are (SEEN_AT_EDGE to SEEN_DEEP). Hunters still hear them.
static func sight_reach(point: Vector3, reach: float) -> float:
	if _all.is_empty():
		return reach
	var cover := cover_at(point)
	if cover <= 0.0:
		return reach
	return minf(reach, lerpf(SEEN_AT_EDGE, SEEN_DEEP, cover))


## How far `p` is in from the nearest open side of `patch` (INF with none).
static func _edge_in(patch: Dictionary, p: Vector2) -> float:
	var rect: Rect2 = patch.rect
	var open: int = patch.open
	var d := INF
	if open & OPEN_EAST:
		d = minf(d, rect.end.x - p.x)
	if open & OPEN_WEST:
		d = minf(d, p.x - rect.position.x)
	if open & OPEN_SOUTH:
		d = minf(d, rect.end.y - p.y)
	if open & OPEN_NORTH:
		d = minf(d, p.y - rect.position.y)
	return d


# --- Filling near the camera -------------------------------------------------------

## Fills every square within `radius` metres of `point` now (as the camera coming
## near does, a few a frame).
func fill_near(point: Vector3, radius: float) -> void:
	if _preset.is_empty():
		build()
	for key: Vector2i in _squares:
		if not _filled.has(key) and _distance(key, point) <= radius:
			_fill(key)
	_planned_for = Vector3.INF


static func _distance(key: Vector2i, point: Vector3) -> float:
	var rect := Rect2(Vector2(key) * SQUARE, Vector2.ONE * SQUARE)
	var at := Vector2(point.x, point.z)
	return at.distance_to(Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y)))


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _preset.is_empty():
		return
	var eye := camera.global_position
	if eye.distance_squared_to(_planned_for) > REPLAN * REPLAN:
		_planned_for = eye
		_plan(eye)
	var started := Time.get_ticks_usec()
	while not _queue.is_empty() and Time.get_ticks_usec() - started < FILL_BUDGET:
		var key: Vector2i = _queue.pop_back()
		if not _filled.has(key):
			_fill(key)
	# (the springs, the shader's settings and the rustling: once a frame for every field)
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_drive(camera, delta)


## The squares not filled yet within reach of the camera at `eye`, nearest last
## (taken first).
func _plan(eye: Vector3) -> void:
	var reach: float = _preset.far + SQUARE
	var middle := Vector2i((Vector2(eye.x, eye.z) / SQUARE).floor())
	var span := ceili(reach / SQUARE)
	var wanted: Array = []
	for j in range(middle.y - span, middle.y + span + 1):
		for i in range(middle.x - span, middle.x + span + 1):
			var key := Vector2i(i, j)
			if _squares.has(key) and not _filled.has(key):
				var d := _distance(key, eye)
				if d <= reach:
					wanted.append([key, d])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	_queue = wanted.map(func(one: Array) -> Vector2i: return one[0])


## A number 0..1 from three whole numbers, the same on every copy of the game.
static func _rand(i: int, j: int, k: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
	h = ((h >> 13) ^ h) * 1274126177
	h = (h >> 16) ^ h
	return float(h & 0xffff) / 65536.0


## Sets square `key`'s stalks: one at each point of the rows' grid that falls in a
## patch (a little off it at random), but where something is kept clear, thinning
## raggedly towards the open sides, with a few gaps; each turned, sized and leant
## a little at random, now and then leant over a good way (broken).
func _fill(key: Vector2i) -> void:
	_filled[key] = true
	var square := Rect2(Vector2(key) * SQUARE, Vector2.ONE * SQUARE)
	var centre := square.get_center()
	var kept: float = _preset.density
	var buffer := PackedFloat32Array()
	var low := INF
	var high := -INF
	for index: int in _squares[key]:
		var patch: Dictionary = _patches[index]
		var area := square.intersection(patch.rect)
		if not area.has_area():
			continue
		var rows_x: bool = patch.rows_x
		# (across the rows, and along them)
		var a0 := area.position.y if rows_x else area.position.x
		var a1 := area.end.y if rows_x else area.end.x
		var b0 := area.position.x if rows_x else area.position.y
		var b1 := area.end.x if rows_x else area.end.y
		var turn := 1 if rows_x else 2
		for i in range(floori(a0 / ROW) - 1, ceili(a1 / ROW) + 1):
			for j in range(floori(b0 / STEP) - 1, ceili(b1 / STEP) + 1):
				var s := seed * 7 + turn
				if _rand(i, j, s + 3) > kept:
					continue
				var across := (i + 0.5 + (_rand(i, j, s) - 0.5) * 0.4) * ROW
				var along := (j + 0.5 + (_rand(i, j, s + 1) - 0.5) * 0.7) * STEP
				var p := Vector2(along, across) if rows_x else Vector2(across, along)
				if not area.has_point(p):
					continue
				# (ragged towards the open sides, and a few gaps)
				var edge := _edge_in(patch, p)
				if edge < 2.2 and _rand(i, j, s + 4) * 2.2 > edge:
					continue
				if _rand(i, j, s + 5) < 0.03:
					continue
				if _kept_out(patch.keep, p):
					continue
				var mask: Callable = patch.mask
				if mask.is_valid() and float(mask.call(p)) <= 0.0:
					continue
				var y: float = patch.ground.call(p)
				low = minf(low, y)
				high = maxf(high, y)
				var big := 0.88 + _rand(i, j, s + 6) * 0.24
				var lean := 0.12 * _rand(i, j, s + 7)
				if _rand(i, j, s + 8) < 0.08:
					lean = 0.25 + 0.3 * _rand(i, j, s + 9)
				var lean_way := _rand(i, j, s + 10) * TAU
				var basis := Basis(Vector3(cos(lean_way), 0.0, sin(lean_way)), lean) * Basis(Vector3.UP, _rand(i, j, s + 11) * TAU)
				basis = basis.scaled(Vector3.ONE * big)
				buffer.append_array([basis.x.x, basis.y.x, basis.z.x, p.x - centre.x,
					basis.x.y, basis.y.y, basis.z.y, y,
					basis.x.z, basis.y.z, basis.z.z, p.y - centre.y])
				var cell := Vector2i((p / GRID).floor())
				if not _grid.has(cell):
					_grid[cell] = []
				(_grid[cell] as Array).append_array([p.x, y, p.y, HEIGHT * big])
	var count := buffer.size() / 12
	if count == 0:
		return
	_stalks += count
	var box := AABB(Vector3(-SQUARE * 0.5 - 2.5, low - 0.5, -SQUARE * 0.5 - 2.5), Vector3(SQUARE + 5.0, high - low + HEIGHT * 1.25 + 1.0, SQUARE + 5.0))
	for far in 2:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh(far == 1)
		multi.instance_count = count
		multi.buffer = buffer
		multi.custom_aabb = box
		var shown := MultiMeshInstance3D.new()
		shown.multimesh = multi
		shown.material_override = _material
		shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shown.position = Vector3(centre.x, 0.0, centre.y)
		if far == 0:
			shown.visibility_range_end = _preset.near
		else:
			shown.visibility_range_begin = _preset.near
			shown.visibility_range_end = _preset.far
		add_child(shown)


static func _kept_out(keep: Array, p: Vector2) -> bool:
	for one: Variant in keep:
		if one is Rect2:
			if (one as Rect2).has_point(p):
				return true
		elif one is Vector3:
			var round_off: Vector3 = one
			if p.distance_squared_to(Vector2(round_off.x, round_off.y)) < round_off.z * round_off.z:
				return true
	return false


# --- Each frame: the springs, the wind, the rustling ----------------------------------

func _drive(camera: Camera3D, delta: float) -> void:
	delta = minf(delta, 0.1)
	var eye := camera.global_position
	# Who is going through it: the nearest the camera, to the shader (a soft lean)
	# and, the nearest MAX_SHOVERS, shoving the stalks they are among.
	var found: Array = []
	for node in get_tree().get_nodes_in_group(Grass.PUSHERS):
		if node is Node3D and node.is_inside_tree() and (node as Node3D).global_position.distance_squared_to(eye) < 3600.0:
			found.append(node)
	if found.size() > 1:
		found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	var packed := PackedVector4Array()
	packed.resize(Grass.MAX_PUSHERS)
	var n := mini(found.size(), Grass.MAX_PUSHERS)
	for i in n:
		var at: Vector3 = (found[i] as Node3D).global_position
		packed[i] = Vector4(at.x, at.y, at.z, (found[i] as Node).get_meta(&"grass_radius", 0.7))
	for spring: Array in _springs.values():
		spring[7] = 0.0
		spring[8] = 0.0
	var loudness := {}
	for i in mini(found.size(), MAX_SHOVERS):
		var node: Node3D = found[i]
		var at := node.global_position
		var id := node.get_instance_id()
		var was: Vector3 = _last_at.get(id, at)
		_last_at[id] = at
		var moved := Vector2(at.x - was.x, at.z - was.z)
		var speed := moved.length() / maxf(delta, 0.001)
		var heading := moved.normalized() if moved.length() > 0.0001 else Vector2.ZERO
		var radius: float = node.get_meta(&"grass_radius", 0.7)
		var touched := _shove(at, radius, heading)
		if touched > 0:
			loudness[node] = clampf(speed / 3.5, 0.0, 1.0) * clampf(touched / 4.0, 0.0, 1.0)
	_spring(delta)
	# (the stalks most bent, if there are more than the shader takes)
	var moving: Array = _springs.values()
	if moving.size() > MAX_SPRUNG:
		moving.sort_custom(func(a: Array, b: Array) -> bool: return a[3] * a[3] + a[4] * a[4] > b[3] * b[3] + b[4] * b[4])
	var sprung := PackedVector4Array()
	sprung.resize(MAX_SPRUNG)
	var count := mini(moving.size(), MAX_SPRUNG)
	for i in count:
		var spring: Array = moving[i]
		sprung[i] = Vector4(spring[0], spring[1], spring[3], spring[4])
	_material.set_shader_parameter(&"pushers", packed)
	_material.set_shader_parameter(&"pusher_count", n)
	_material.set_shader_parameter(&"sprung", sprung)
	_material.set_shader_parameter(&"sprung_count", count)
	var focus := Vector3(0.0, -1000.0, 0.0)
	var followed: Variant = camera.get(&"target")
	if followed is Node3D and is_instance_valid(followed):
		focus = (followed as Node3D).global_position + Vector3.UP
	_material.set_shader_parameter(&"focus", focus)
	_weather_in -= delta
	if _weather_in <= 0.0:
		_weather_in = 2.0
		_weather_from = null
		var up := get_parent()
		while up != null and _weather_from == null:
			var weather: Variant = up.get(&"weather")
			if weather is Node:
				_weather_from = weather
			up = up.get_parent()
	if is_instance_valid(_weather_from):
		_material.set_shader_parameter(&"wind", float(_weather_from.get(&"wind")))
	_rustling(loudness, delta)


## Pushes the stalks near a pusher at `at` (`radius` its size, `heading` the way
## it is going) away from it, more to the side than ahead: how many it touches.
func _shove(at: Vector3, radius: float, heading: Vector2) -> int:
	var reach := radius * 1.5 + 1.0
	var touched := 0
	for field in _all:
		if field._grid.is_empty():
			continue
		for gz in range(floori((at.z - reach) / GRID), floori((at.z + reach) / GRID) + 1):
			for gx in range(floori((at.x - reach) / GRID), floori((at.x + reach) / GRID) + 1):
				var stalks: Array = field._grid.get(Vector2i(gx, gz), [])
				for k in range(0, stalks.size(), 4):
					var x: float = stalks[k]
					var z: float = stalks[k + 2]
					var away := Vector2(x - at.x, z - at.z)
					var far := away.length()
					if far >= reach or absf(float(stalks[k + 1]) - at.y) > 2.2:
						continue
					touched += 1
					away = away / maxf(far, 0.001)
					# (parted to the sides of the way he goes, not shoved on ahead of him)
					away = (away - heading * away.dot(heading) * 0.6).normalized()
					var tall: float = stalks[k + 3]
					var push := away * tall * 0.6 * pow(1.0 - far / reach, 1.2)
					var name := Vector2i(roundi(x * 20.0), roundi(z * 20.0))
					var spring: Array = _springs.get(name, [])
					if spring.is_empty():
						spring = [x, z, tall, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
						_springs[name] = spring
					spring[7] += push.x
					spring[8] += push.y
	return touched


## Each sprung stalk swings towards where it is pushed (upright when nobody is),
## past it and back, settling in a couple of seconds; let go once it is still.
static func _spring(delta: float) -> void:
	var steps := ceili(delta / (1.0 / 60.0))
	var dt := delta / maxi(steps, 1)
	var settled: Array = []
	for name: Vector2i in _springs:
		var spring: Array = _springs[name]
		var tall: float = spring[2]
		var to := Vector2(spring[7], spring[8]).limit_length(tall * 0.75)
		var bend := Vector2(spring[3], spring[4])
		var speed := Vector2(spring[5], spring[6])
		# (each a little stiffer or softer than the next)
		var stiff := 34.0 + fmod(absf(spring[0] * 7.3 + spring[1] * 3.1), 10.0)
		var damping := 2.0 * 0.3 * sqrt(stiff)
		for s in steps:
			speed += ((to - bend) * stiff - speed * damping) * dt
			bend += speed * dt
		spring[3] = bend.x
		spring[4] = bend.y
		spring[5] = speed.x
		spring[6] = speed.y
		if to == Vector2.ZERO and bend.length() < 0.004 and speed.length() < 0.02:
			settled.append(name)
	for name: Vector2i in settled:
		_springs.erase(name)


# --- The rustle ----------------------------------------------------------------------

var _voices := {}


## A rustle from each of the nearest few pushing through the corn, as loud as
## they are fast; quiet, and stopped, when they stand still or are out of it.
func _rustling(loudness: Dictionary, delta: float) -> void:
	var wanted: Array = loudness.keys()
	wanted.sort_custom(func(a: Node3D, b: Node3D) -> bool: return loudness[a] > loudness[b])
	wanted = wanted.slice(0, MAX_VOICES)
	for node: Node3D in wanted:
		if not _voices.has(node) and _voices.size() < MAX_VOICES + 2:
			var voice := AudioStreamPlayer3D.new()
			voice.stream = rustle_sound()
			voice.unit_size = 4.0
			voice.max_distance = 40.0
			voice.volume_db = -60.0
			add_child(voice)
			voice.play(randf() * 1.5)
			_voices[node] = [voice, 0.0]
	for node: Variant in _voices.keys():
		var held: Array = _voices[node]
		var voice: AudioStreamPlayer3D = held[0]
		var target: float = loudness.get(node, 0.0) if is_instance_valid(node) and wanted.has(node) else 0.0
		held[1] = move_toward(held[1], target, delta * 3.0)
		if is_instance_valid(node):
			voice.global_position = (node as Node3D).global_position + Vector3.UP * 0.9
		voice.volume_db = linear_to_db(maxf(held[1], 0.001)) - 2.0
		voice.pitch_scale = 0.9 + 0.25 * held[1]
		if held[1] <= 0.0 and target <= 0.0:
			voice.queue_free()
			_voices.erase(node)


## Dry leaves brushed past, over and over: crackling grains of high, dry noise on
## a soft hiss, looped (1.4 s). Made once, when first heard.
static func rustle_sound() -> AudioStreamWAV:
	if _rustle:
		return _rustle
	var rate := 16000
	var long := int(rate * 1.4)
	var chance := RandomNumberGenerator.new()
	chance.seed = 4417
	var envelope := PackedFloat32Array()
	envelope.resize(long)
	envelope.fill(0.1)
	# (grains: a leaf scraping by, a stalk knocking, each dying away; wrapped round the loop)
	for g in 90:
		var start := chance.randi_range(0, long - 1)
		var fade := chance.randf_range(0.004, 0.03) * rate
		var strength := chance.randf_range(0.15, 0.9) * (1.6 if chance.randf() < 0.1 else 1.0)
		for k in int(fade * 4.0):
			envelope[(start + k) % long] += strength * exp(-k / fade)
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	var smooth := 0.0
	for k in long:
		var raw := chance.randf_range(-1.0, 1.0)
		low += (raw - low) * 0.25
		smooth += ((raw - low) - smooth) * 0.7
		data.encode_s16(k * 2, int(clampf(smooth * envelope[k] * 0.55, -1.0, 1.0) * 30000.0))
	_rustle = AudioStreamWAV.new()
	_rustle.format = AudioStreamWAV.FORMAT_16_BITS
	_rustle.mix_rate = rate
	_rustle.data = data
	_rustle.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_rustle.loop_end = long
	return _rustle


# --- The stalk ----------------------------------------------------------------------

## The stalk (made once): `plain` the one for far off. Near: a thin tapering stalk
## of three sides, eleven long leaves from its joints, alternately either side,
## arching out and hanging down, each twisted along its length (dry); an ear in
## its husk leaning out from halfway up; a tassel at the top. Far: two crossed
## strips for the stalk and seven leaves of two pieces each. Pale dry yellow-grey,
## greyer leaves here and there. UV: how far out along a leaf (0 the stalk, for the
## flutter), and a number at random for each part.
static func mesh(plain := false) -> ArrayMesh:
	if _meshes.is_empty():
		_meshes = [_stalk(false), _stalk(true)]
	return _meshes[1 if plain else 0]


static func _stalk(plain: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 2.35
	var foot_colour := Color(0.3, 0.28, 0.22)
	var top_colour := Color(0.45, 0.42, 0.33)
	# The stalk.
	if plain:
		for turn: float in [0.0, PI * 0.5]:
			var side := Vector3(cos(turn), 0.0, sin(turn))
			var rows := [[0.0, 0.034], [1.2, 0.026], [top, 0.014]]
			for r in 2:
				var y0: float = rows[r][0]
				var y1: float = rows[r + 1][0]
				var w0: float = rows[r][1]
				var w1: float = rows[r + 1][1]
				var c0 := foot_colour.lerp(top_colour, y0 / top)
				var c1 := foot_colour.lerp(top_colour, y1 / top)
				_quad(tool, [Vector3(0, y0, 0) - side * w0, Vector3(0, y0, 0) + side * w0, Vector3(0, y1, 0) + side * w1, Vector3(0, y1, 0) - side * w1], [c0, c0, c1, c1], side.cross(Vector3.UP), 0.0, 0.0)
	else:
		var heights := [0.0, 0.35, 0.8, 1.3, 1.8, top]
		for r in heights.size() - 1:
			var y0: float = heights[r]
			var y1: float = heights[r + 1]
			var w0 := lerpf(0.03, 0.013, y0 / top)
			var w1 := lerpf(0.03, 0.013, y1 / top)
			for f in 3:
				var a := f * TAU / 3.0
				var b := (f + 1) * TAU / 3.0
				var pa := Vector3(cos(a), 0.0, sin(a))
				var pb := Vector3(cos(b), 0.0, sin(b))
				var out := ((pa + pb) * 0.5).normalized()
				# (darker at each joint)
				var c0 := foot_colour.lerp(top_colour, y0 / top) * 0.85
				var c1 := foot_colour.lerp(top_colour, y1 / top)
				_quad(tool, [pa * w0 + Vector3.UP * y0, pb * w0 + Vector3.UP * y0, pb * w1 + Vector3.UP * y1, pa * w1 + Vector3.UP * y1], [c0, c0, c1, c1], out, 0.0, 0.0)
	# The leaves.
	var leaves := 7 if plain else 11
	var first_turn := rng.randf() * TAU
	for l in leaves:
		var f := l / float(leaves - 1)
		var y := lerpf(0.25, 2.0, f) + rng.randf_range(-0.05, 0.05)
		var turn := first_turn + l * PI + rng.randf_range(-0.45, 0.45) + l * 0.35
		var long := lerpf(1.0, 0.6, f) * rng.randf_range(0.85, 1.15)
		var droop := rng.randf_range(1.0, 1.8) if rng.randf() < 0.8 else 2.6
		var grey := rng.randf() < 0.3
		var base := Color(0.42, 0.39, 0.31) if not grey else Color(0.39, 0.38, 0.34)
		var tip := Color(0.55, 0.51, 0.41) if not grey else Color(0.5, 0.49, 0.45)
		_leaf(tool, Vector3(0.0, y, 0.0), turn, long, (0.14 if plain else 0.095) * rng.randf_range(0.85, 1.15), droop, rng.randf_range(-1.3, 1.3), base, tip, 2 if plain else 5, rng.randf())
	if plain:
		return tool.commit()
	# The ear: a spindle in its husk leaning out from the stalk, silk at its tip.
	var ear_turn := first_turn + 0.9
	var lean := Vector3(cos(ear_turn), 0.0, sin(ear_turn))
	var axis := (lean * sin(0.45) + Vector3.UP * cos(0.45)).normalized()
	var across := lean.cross(Vector3.UP).normalized()
	var over := axis.cross(across).normalized()
	var foot := Vector3(0.0, 1.08, 0.0) + lean * 0.02
	var profile := [[0.0, 0.012], [0.05, 0.036], [0.15, 0.038], [0.24, 0.02], [0.29, 0.004]]
	var husk := Color(0.5, 0.45, 0.34)
	for r in profile.size() - 1:
		for f in 5:
			var a := f * TAU / 5.0
			var b := (f + 1) * TAU / 5.0
			var pa := across * cos(a) + over * sin(a)
			var pb := across * cos(b) + over * sin(b)
			var y0: float = profile[r][0]
			var y1: float = profile[r + 1][0]
			var w0: float = profile[r][1]
			var w1: float = profile[r + 1][1]
			_quad(tool, [foot + axis * y0 + pa * w0, foot + axis * y0 + pb * w0, foot + axis * y1 + pb * w1, foot + axis * y1 + pa * w1], [husk * 0.9, husk * 0.9, husk, husk], (pa + pb).normalized(), 0.0, 0.3)
	var silk := foot + axis * 0.29
	_tri(tool, silk - across * 0.012, silk + across * 0.012, silk + axis * 0.06 + lean * 0.05 + Vector3.DOWN * 0.03, Color(0.3, 0.23, 0.16), 0.5)
	# The tassel: a few thin spikes from the top, out and drooping.
	for t in 7:
		var a := t * TAU / 7.0 + 0.3
		var out := Vector3(cos(a), 0.0, sin(a))
		var side := out.cross(Vector3.UP) * 0.007
		var from := Vector3(0.0, top - 0.02, 0.0)
		var mid := from + out * 0.08 + Vector3.UP * 0.15
		var end := from + out * 0.2 + Vector3.UP * 0.06
		var colour := Color(0.46, 0.39, 0.28)
		_tri(tool, from - side, from + side, mid, colour, 0.6)
		_tri(tool, mid - side * 0.7, mid + side * 0.7, end, colour, 0.6)
	return tool.commit()


## A leaf from `at` on the stalk, the `turn` way: up and out, then arching over and
## hanging down (`droop`), narrowing to a point, twisted `twist` radians along it.
static func _leaf(tool: SurfaceTool, at: Vector3, turn: float, long: float, wide: float, droop: float, twist: float, base: Color, tip: Color, pieces: int, which: float) -> void:
	var out := Vector3(cos(turn), 0.0, sin(turn))
	var flat := out.cross(Vector3.UP).normalized()
	var rows: Array = []
	for k in pieces + 1:
		var t := k / float(pieces)
		var middle := at + out * (0.02 + long * 0.85 * t) + Vector3.UP * long * (0.36 * t - droop * t * t)
		var along := (out * 0.85 + Vector3.UP * (0.36 - 2.0 * droop * t)).normalized()
		var normal := flat.cross(along).normalized()
		var side := flat * cos(twist * t) + normal * sin(twist * t)
		var half := wide * (0.45 + 0.55 * sin(minf(t * 2.2, 1.0) * PI * 0.5)) * pow(1.0 - t, 0.8)
		rows.append([middle - side * half, middle + side * half, base.lerp(tip, t), side.cross(along).normalized(), t])
	for k in pieces:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		_quad_each(tool, [a[0], a[1], b[1], b[0]], [a[2], a[2], b[2], b[2]], [a[3], a[3], b[3], b[3]], [a[4], a[4], b[4], b[4]], which)


static func _quad(tool: SurfaceTool, corners: Array, colours: Array, normal: Vector3, out: float, which: float) -> void:
	_quad_each(tool, corners, colours, [normal, normal, normal, normal], [out, out, out, out], which)


static func _quad_each(tool: SurfaceTool, corners: Array, colours: Array, normals: Array, outs: Array, which: float) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(colours[k])
		tool.set_normal(normals[k])
		tool.set_uv(Vector2(outs[k], which))
		tool.add_vertex(corners[k])


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, which: float) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.set_uv(Vector2(0.0, which))
		tool.add_vertex(p)


# --- The shader ------------------------------------------------------------------------

## The material every stalk is drawn with (shared by every field).
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


## Each stalk bends along its length as one curve (its leaves, ear and tassel
## turned with it), by: the wind, in gusts rolling across the field and a sway of
## its own; a soft lean from anyone near (plant_push's `pushed`, reaching further
## than for the low plants); its spring, if it is one of those shoved aside
## (`sprung`: where it stands, and how far its top is bent, metres); and, while
## the camera is down among the stalks, leant a little aside from its view of
## whom it follows (`focus`), and pressed down right by the camera. The leaves
## flutter a little at their tips. Darker low down, where little light gets in.
const SHADER := """
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform vec4 sprung[64];
uniform int sprung_count = 0;
uniform float wind = 0.1;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform vec3 focus = vec3(0.0, -1000.0, 0.0);
uniform float lane = 1.3;

varying float v_up;

#include "res://scripts/plant_push.gdshaderinc"

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return mix(mix(hash(whole), hash(whole + vec2(1.0, 0.0)), part.x),
			mix(hash(whole + vec2(0.0, 1.0)), hash(whole + vec2(1.0, 1.0)), part.x), part.y);
}

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float tall = length(MODEL_MATRIX[1].xyz) * 2.5;
	vec3 rel = VERTEX - root;
	float rnd = hash(root.xz * 3.1);

	// The wind: gusts rolling across, and each stalk's own sway.
	vec2 wd = normalize(wind_dir + vec2(0.0001));
	vec2 g = root.xz / 24.0 - wd * TIME * (0.2 + wind * 0.6);
	float gust = smoothstep(0.2, 0.85, noise(g) * 0.65 + noise(g * 2.3 + 5.0) * 0.35);
	vec2 bend = wd * tall * (0.015 + wind * 0.11) * (0.3 + gust);
	bend += wd * tall * (0.008 + 0.03 * wind) * sin(TIME * (1.1 + rnd * 0.6) + rnd * 6.283);
	bend += vec2(-wd.y, wd.x) * tall * (0.005 + 0.015 * wind) * sin(TIME * 1.7 + rnd * 11.0);

	// A soft lean from anyone near, and the shoved ones' springs.
	bend += pushed(root, 1.7).xz * tall * 0.1;
	for (int i = 0; i < 64; i++) {
		if (i >= sprung_count) {
			break;
		}
		vec2 d = sprung[i].xy - root.xz;
		if (dot(d, d) < 0.0016) {
			bend += sprung[i].zw;
			break;
		}
	}

	// While the camera is down among them: leaning a little aside from its view of
	// whom it follows, and those right by the camera pressed down out of its way
	// (not filling the screen).
	vec3 eye = CAMERA_POSITION_WORLD;
	vec2 seg = focus.xz - eye.xz;
	float seg_long = length(seg);
	float low = 0.0;
	if (focus.y > -500.0 && seg_long > 0.5 && eye.y < root.y + tall + 1.5) {
		float t = clamp(dot(root.xz - eye.xz, seg) / (seg_long * seg_long), 0.0, 1.0);
		vec2 off = root.xz - (eye.xz + seg * t);
		float d = length(off);
		float k = (1.0 - smoothstep(lane * 0.3, lane, d)) * (1.0 - smoothstep(seg_long - 1.6, seg_long - 0.6, t * seg_long));
		bend += off / max(d, 0.01) * k * tall * 0.2;
		low = 1.0 - smoothstep(0.7, 1.8, length(root.xz - eye.xz));
	}

	// Bent along an arc: the whole of it turned through `a` by the top.
	float lean = length(bend);
	vec2 dir = lean > 0.0001 ? bend / lean : wd;
	float curve = min(2.0 * lean / tall, 1.5) / tall;
	float s = max(rel.y, 0.0);
	float a = curve * s;
	float out_ = curve > 0.00001 ? (1.0 - cos(a)) / curve : 0.0;
	float up = curve > 0.00001 ? sin(a) / curve : s;
	float along = dot(rel.xz, dir);
	vec2 side = rel.xz - dir * along;
	vec3 moved = root + vec3(dir.x, 0.0, dir.y) * (out_ + along * cos(a)) + vec3(side.x, 0.0, side.y) + vec3(0.0, up - along * sin(a), 0.0);
	// (the leaves' tips flutter, and hang lower on some stalks than others)
	moved.y -= UV.x * UV.x * 0.18 * fract(rnd * 7.0);
	moved.y += sin(TIME * (2.4 + rnd) + UV.y * 6.283) * 0.03 * UV.x * (0.4 + wind + min(lean, 1.0));
	VERTEX = root + (moved - root) * (1.0 - low * 0.9);

	float nd = dot(NORMAL.xz, dir);
	vec2 nside = NORMAL.xz - dir * nd;
	NORMAL = normalize(vec3(dir.x, 0.0, dir.y) * (nd * cos(a) + NORMAL.y * sin(a)) + vec3(nside.x, 0.0, nside.y) + vec3(0.0, NORMAL.y * cos(a) - nd * sin(a), 0.0));
	v_up = s;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	// (dark down among the stalks, where little light gets in)
	colour *= mix(0.28, 1.0, smoothstep(0.1, 2.0, v_up));
	ALBEDO = colour;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""


# --- In the maze -------------------------------------------------------------------------

## The corn in the square sections, as each section's style says (MazeStyle
## "Plants": corn_room_share, corn_hall_share): rooms filled from wall to wall
## (not one with a pond; round its column or its pine), and stretches of hall a
## few cells long, as wide as the hall, none at a gate between sections; nothing
## on a terrace (`footprints`, MazeFeatures'). All from the seed, each section from
## its own numbers, so a change to one section's corn changes only its own.
static func plant_maze(maze: Maze, footprints: Array) -> Corn:
	var corn := Corn.new()
	corn.name = "Corn"
	corn.seed = maze.maze_seed % 9973
	# [cell] -> rows along x; and the rooms' pines
	var in_corn := {}
	var pines := {}
	# (the ring of each cell by how far out from the middle it is: Maze.ring_of, worked out once)
	var middle_cell := maze.size / 2
	var ring_out := PackedInt32Array()
	for out in middle_cell + 2:
		ring_out.append(maze.ring_of(Vector2i(middle_cell + out, middle_cell)))
	var last := ring_out.size() - 1
	# (which sections have corn, how thick their walls are and how deep the step of ledge at their feet)
	var growing := {}
	var thick := {}
	var step_out := {}
	for ring in range(1, maze.styles.size() + 1):
		var style: MazeStyle = maze.styles[ring - 1]
		thick[ring] = style.maze_wall_diameter
		step_out[ring] = style.mezzanine_depth if style.mezzanine_height > 0.0 else 0.0
		if not style.round_section and style.corn_on and (style.corn_room_share > 0.0 or style.corn_hall_share > 0.0):
			growing[ring] = true
	var rings := {}
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		var ring := ring_out[mini(maxi(absi(cell.x - middle_cell), absi(cell.y - middle_cell)), last)]
		if not growing.has(ring) or maze.solid.has(cell) or maze.entrances.has(cell):
			continue
		if not rings.has(ring):
			rings[ring] = []
		(rings[ring] as Array).append(cell)
	if rings.is_empty():
		return corn
	# (the cells by the ways through the walls between sections, and those under standing water)
	var by_gates := {}
	var through: Array = maze.exits + maze.ways_out
	for ways_in: Array in maze.gates:
		through.append_array(ways_in)
	for way: Array in through:
		for side in 2:
			var at: Vector2i = way[0] + way[1] * side
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					by_gates[at + Vector2i(dx, dy)] = true
	var wet := {}
	for pond: Dictionary in maze.ponds:
		var rect: Rect2 = pond.rect
		var from := maze.cell_at(Vector3(rect.position.x, 0.0, rect.position.y))
		var to := maze.cell_at(Vector3(rect.end.x, 0.0, rect.end.y))
		for x in range(from.x, to.x + 1):
			for y in range(from.y, to.y + 1):
				wet[Vector2i(x, y)] = true
	for ring: int in rings:
		var style: MazeStyle = maze.styles[ring - 1]
		if style.round_section or not style.corn_on:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("corn/%d/%d" % [maze.maze_seed, ring])
		# The rooms: each by a number of its own (drawn for every room).
		for room: Dictionary in maze.rooms:
			if room.ring != ring:
				continue
			var pick := rng.randf()
			var rows_x := rng.randf() < 0.5
			if pick >= style.corn_room_share or room.fill == Maze.Room.POND:
				continue
			var rect: Rect2i = room.rect
			for x in range(rect.position.x, rect.end.x):
				for y in range(rect.position.y, rect.end.y):
					in_corn[Vector2i(x, y)] = rows_x
			if room.fill == Maze.Room.TREE:
				var middle := maze.room_middle(room)
				pines[rect] = Vector3(middle.x, middle.z, 3.4)
		# The halls: stretches walked from cells at random, until the share is had.
		var halls: Dictionary = {}
		for cell: Vector2i in rings[ring]:
			if maze.in_room(cell) or wet.has(cell) or by_gates.has(cell):
				continue
			halls[cell] = true
		var want := roundi(style.corn_hall_share * halls.size())
		var cells: Array = halls.keys()
		var made := 0
		for attempt in want * 4:
			if made >= want or cells.is_empty():
				break
			var start: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if in_corn.has(start):
				continue
			var walk: Array[Vector2i] = [start]
			var heading := Vector2i.ZERO
			var cell := start
			var long := rng.randi_range(2, 5)
			while walk.size() < long:
				var ways: Array[Vector2i] = []
				for step: Vector2i in Maze.STEPS:
					var next := cell + step
					if halls.has(next) and not maze.blocked(cell, step) and not walk.has(next) and not in_corn.has(next):
						ways.append(step)
				if ways.is_empty():
					break
				var step: Vector2i = heading if ways.has(heading) and rng.randf() < 0.75 else ways[rng.randi_range(0, ways.size() - 1)]
				heading = step
				cell += step
				walk.append(cell)
			# (wall to wall across a hall more than a cell wide)
			for w in style.hallway_diameter_cells - 1:
				for one: Vector2i in walk.duplicate():
					for step: Vector2i in Maze.STEPS:
						var next := one + step
						if halls.has(next) and not maze.blocked(one, step) and not walk.has(next) and not in_corn.has(next):
							walk.append(next)
			var rows_x := heading.x != 0 if heading != Vector2i.ZERO else rng.randf() < 0.5
			for one: Vector2i in walk:
				in_corn[one] = rows_x
				made += 1
	# Each cell of it a patch: its floor between the walls (and in front of the
	# step of ledge at their feet), open where it meets a cell with no corn.
	var ground := func(p: Vector2) -> float: return maze.ground_height(Vector3(p.x, 0.0, p.y))
	# (the terraces over the cells with corn: by cell, as there are a couple of thousand)
	var terraces := {}
	for footprint: Rect2 in footprints:
		var from := maze.cell_at(Vector3(footprint.position.x, 0.0, footprint.position.y))
		var to := maze.cell_at(Vector3(footprint.end.x, 0.0, footprint.end.y))
		for x in range(from.x, to.x + 1):
			for y in range(from.y, to.y + 1):
				if in_corn.has(Vector2i(x, y)):
					if not terraces.has(Vector2i(x, y)):
						terraces[Vector2i(x, y)] = []
					(terraces[Vector2i(x, y)] as Array).append(footprint.grow(0.3))
	var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell: Vector2i in in_corn:
		var middle := maze.world(cell)
		var west := middle.x - Maze.CELL * 0.5
		var east := middle.x + Maze.CELL * 0.5
		var north := middle.z - Maze.CELL * 0.5
		var south := middle.z + Maze.CELL * 0.5
		var open := 0
		for k in 4:
			var step := sides[k]
			if maze.blocked(cell, step):
				# (half the wall: a wall between sections the thicker of the two, and no thinner than RING_THICK)
				var ring := ring_out[mini(maxi(absi(cell.x - middle_cell), absi(cell.y - middle_cell)), last)]
				var next := cell + step
				var other := ring_out[mini(maxi(absi(next.x - middle_cell), absi(next.y - middle_cell)), last)]
				var wall: float = thick[ring] if other == ring else maxf(MazeBuilder.RING_THICK, maxf(thick[ring], thick.get(other, 0.0)))
				var inset: float = wall * 0.5 + MazeBuilder.FOOT.x + 0.2 + step_out[ring]
				match k:
					0: east -= inset
					1: west += inset
					2: south -= inset
					3: north += inset
			elif not in_corn.has(cell + step):
				open |= 1 << k
		var rect := Rect2(west, north, east - west, south - north)
		var keep: Array = []
		for corner: Vector2i in [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]:
			if maze.columns.has(corner):
				var at := maze.corner_at(corner)
				var half: float = maze.columns[corner] * 0.5 + 0.7
				keep.append(Rect2(at.x - half, at.z - half, half * 2.0, half * 2.0))
		if maze.in_room(cell):
			var room_rect: Rect2i = maze.rooms[maze.room_cells[cell]].rect
			if pines.has(room_rect):
				keep.append(pines[room_rect])
		keep.append_array(terraces.get(cell, []))
		corn.add_patch(rect, open, in_corn[cell], ground, keep)
	return corn
