class_name AntColony
extends Node3D
## A colony of giant ants, each the size of a dog: a nest mound with a hole in
## it, a trail of trodden ground running out from it, workers going out along
## the trail in lines and coming home along it (some carrying what they found),
## soldiers with great heads keeping round the nest, and when the alarm goes
## up, all of them coming at a point at a run and biting whoever stands there.
## How they look and move, and nothing of what they mean in a game: the game
## says where the trail runs, when to raise the alarm and who is the target,
## what to carry home, and what being bitten does (`overwhelmed`).
##
##     var colony := AntColony.new()
##     colony.colony_seed = 7
##     colony.set_trail(points)        # from the nest (the first point) out to where they forage
##     add_child(colony)
##     colony.alarm(where_it_was_trodden)
##     # every frame, while it is up:
##     colony.target = player.global_position
##     colony.target_moving = player.velocity
##     colony.target_grounded = player.is_on_floor()
##     colony.overwhelmed.connect(...)  # enough of them biting for long enough
##     colony.calm()                    # back to the trail
##     colony.carry(a_carcass)          # a few go and haul it home, into the nest
##
## THE WORKERS go out along the trail from the hole (`walk_speed`, each at its
## own pace, keeping to a lane a little to one side of the middle and
## weaving), meet those coming home (they stop nose to nose for a moment, feelers
## going), forage a few seconds round the end of it (`forage_radius`), come home
## along it, more than half with a load in their jaws, and go down the hole to
## come out again a while later. They leave the nest a few at a time, so they go
## in lines.
##
## THE SOLDIERS keep round the nest (`guard_radius`), pacing, stopping, feelers
## up.
##
## THE ALARM (`alarm(at)`) runs out through them from where it began: each
## within `alarm_reach` of it takes it up as it reaches it (`alarm_wave` metres
## a second), and those in the nest pour out. An alarmed ant stops dead, rears a
## little, its feelers up and flickering, jaws apart, gaster raised, and clicks
## (`clicked`) for `alert_time`; then runs at the target (`run_speed`, round
## walls if `guide` says how), or where the alarm began if there is none. Within
## `bite_reach` of the target it seizes it: up to `most_on` at once, round it,
## heads up, jaws working; the rest mill round them. A target going faster
## than `grip_speed`, or off the ground, tears them off one by one (they are
## thrown and tumble, and come on again). `catch_count` on at once for
## `catch_time`: `overwhelmed`. `calm()` and they go back to the trail (or the
## nest) as they were.
##
## CARRYING (`carry(thing)`): `haulers` workers leave the trail for it, take hold
## round it and drag it home (lifted a little, slowly), along the trail and down
## into the nest, where it sinks out of sight (`carried_home`; then hidden).
##
## The cost is small and flat. All of them are one MultiMesh, or two (those
## within `near_detail` of the camera in the full model, the rest in the low
## one); their legs, feelers, jaws and gaster are moved in the shader. Each is a
## few lines of arithmetic a frame (the trail is laid out in metre steps, so
## where an ant on it is, is a lookup); the nest is one mesh and the trail one
## more. Asleep (process_mode disabled) they cost nothing. Seeded by
## `colony_seed`, two machines that make the same colony get the same ants.

## Enough of them have been on the target for long enough.
signal overwhelmed
## The alarm has gone up (the first to take it up, where it is).
signal alarmed(at: Vector3)
## An ant has clicked (taking up the alarm, or biting), where it is.
signal clicked(at: Vector3)
## What they were carrying has gone down into the nest.
signal carried_home(thing: Node3D)

enum State { NEST, OUT, FORAGE, HOME, GUARD, ALERT, RUSH, ON, FLUNG, CALM, FETCH, HAUL }

@export_range(1, 60) var workers := 22
@export_range(0, 12) var soldiers := 5
@export var colony_seed := 0
## How big they are, against the model's (a worker 1.2 m long), and how much one may differ.
@export var ant_scale := 1.0
@export var size_spread := 0.08
## Walking along the trail, and running when alarmed, metres a second.
@export var walk_speed := 1.6
@export var run_speed := 5.0
## How far round the end of the trail they forage, and how long, seconds.
@export var forage_radius := 6.0
@export var forage_time := Vector2(3.0, 8.0)
## How long a worker stays in the nest before it goes out again, seconds.
@export var nest_time := Vector2(3.0, 14.0)
## How far round the nest the soldiers keep, metres.
@export var guard_radius := 4.5
## The alarm: how far from where it began it is taken up, and how fast it runs through them.
@export var alarm_reach := 28.0
@export var alarm_wave := 8.0
@export var alert_time := 0.55
## How near the target (beyond its radius) one must come to seize it; the most on it at once.
@export var bite_reach := 0.55
@export var most_on := 6
@export var catch_count := 3
@export var catch_time := 1.0
## Going faster than this (m/s), or off the ground, tears them off.
@export var grip_speed := 4.9
@export var grip_time := 0.35
## How many haul a carried thing, and how fast they drag it home, metres a second.
@export var haulers := 3
@export var haul_speed := 0.9
## Within this of the camera they are drawn in the full model; past `draw_far`, not at all.
@export var near_detail := 26.0
@export var draw_far := 110.0
## Only the low model, near or far (phones).
@export var low_poly := false
@export var show_nest := true
@export var show_trail := true
@export var trail_width := 1.3
@export var sound := true
@export var volume_db := -8.0

## Who they go for, when alarmed: a point on the ground (the feet of whoever
## it is), or Vector3.INF for none (they go to where the alarm began).
var target := Vector3.INF
var target_moving := Vector3.ZERO
var target_grounded := true
## How far from its middle the target's body reaches, metres.
var target_radius := 0.4
## Optional, Callable(from: Vector3, goal: Vector3) -> Vector3: where an ant at
## `from` should make for on its way to `goal`, round walls. Asked for each
## running ant a few times a second.
var guide := Callable()
## Optional, Callable(point: Vector3) -> float: the height of the ground. Asked
## for each ant off the trail now and then. Without it, the height of the trail.
var ground := Callable()
## Optional, Callable(point: Vector3) -> bool: ground they will not go onto (inside walls).
var forbid := Callable()

## How many are on the target, and whether the alarm is up.
var on_target := 0
var alarm_up := false
## The ant nearest the target, and how far it is (INF: none out).
var front := Vector3.ZERO
var gap := INF

const TRAIL_STEP := 1.0
## The nest mound: how far out it reaches, how high its rim stands, the hole's width.
const MOUND_RADIUS := 2.6
const RIM_HEIGHT := 0.45
const HOLE_RADIUS := 0.7
const HOLE_DEPTH := 0.9



class Ant:
	var soldier := false
	var state := 0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var speed := 0.0
	var phase := 0.0
	var s := 0.0
	var out := true
	var lane := 0.0
	var pace := 1.0
	var size := 1.0
	var weave := 0.0
	var timer := 0.0
	var goal := Vector3.INF
	var alarm := 0.0
	var bite := 0.0
	var wait := -1.0
	var slot := 0.0
	var grip := 0.0
	var fling := Vector3.ZERO
	var loaded := false
	var meet := 0.0
	var met := 0.0
	var way := Vector3.INF
	var way_in := 0
	var ground_in := 0
	var floor_y := NAN
	var haul_slot := Vector3.ZERO


var ants: Array[Ant] = []

var _trail := PackedVector3Array()
var _trail_length := 0.0
var _nest := Vector3.ZERO
var _alarm_at := Vector3.INF
var _overwhelm := 0.0
var _rng := RandomNumberGenerator.new()
var _tick := 0
var _meet_in := 0.0
var _time := 0.0

var _near_drawn: MultiMeshInstance3D
var _far_drawn: MultiMeshInstance3D
var _near_buffer := PackedFloat32Array()
var _far_buffer := PackedFloat32Array()
var _nest_mesh: MeshInstance3D
var _trail_mesh: MeshInstance3D
var _clicker: AudioStreamPlayer3D
var _patter: AudioStreamPlayer3D
static var _click_sound: AudioStreamWAV
static var _patter_sound: AudioStreamWAV

var _thing: Node3D
var _thing_route := PackedVector3Array()
var _thing_s := 0.0
var _thing_sink := -1.0
var _thing_base := 0.0


func _ready() -> void:
	_rng.seed = colony_seed
	if _trail.is_empty():
		set_trail(PackedVector3Array([global_position, global_position + global_basis.z * 20.0]))
	for k in workers + soldiers:
		var ant := Ant.new()
		ant.soldier = k >= workers
		ant.size = ant_scale * (1.0 + _rng.randf_range(-size_spread, size_spread))
		ant.pace = _rng.randf_range(0.85, 1.15)
		ant.lane = _rng.randf_range(0.12, 0.38) * (1.0 if _rng.randf() < 0.5 else -1.0)
		ant.weave = _rng.randf() * TAU
		ant.phase = _rng.randf()
		ants.append(ant)
	_near_drawn = _drawn(false)
	_far_drawn = _drawn(true)
	_near_buffer.resize(ants.size() * 16)
	_far_buffer.resize(ants.size() * 16)
	if show_nest:
		_nest_mesh = MeshInstance3D.new()
		_nest_mesh.name = "Nest"
		_nest_mesh.mesh = _mound()
		_nest_mesh.top_level = true
		add_child(_nest_mesh)
	if show_trail:
		_trail_mesh = MeshInstance3D.new()
		_trail_mesh.name = "Trail"
		_trail_mesh.top_level = true
		_trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_trail_mesh)
	if sound:
		_clicker = AudioStreamPlayer3D.new()
		_clicker.stream = click_sound()
		_clicker.max_polyphony = 6
		_clicker.unit_size = 4.0
		_clicker.max_distance = 40.0
		_clicker.volume_db = volume_db
		_clicker.top_level = true
		add_child(_clicker)
		_patter = AudioStreamPlayer3D.new()
		_patter.stream = patter_sound()
		_patter.unit_size = 4.0
		_patter.max_distance = 35.0
		_patter.volume_db = -80.0
		_patter.top_level = true
		add_child(_patter)
	_lay_out()
	start()


func _drawn(low: bool) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = AntLook.mesh(low)
	many.instance_count = ants.size()
	many.visible_instance_count = 0
	var shown := MultiMeshInstance3D.new()
	shown.name = "AntsLow" if low else "Ants"
	shown.multimesh = many
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.top_level = true
	add_child(shown)
	shown.global_transform = Transform3D.IDENTITY
	return shown


# --- The trail and the nest ---

## Where the trail runs: from the nest (the first point, the hole) out to where
## they forage (the last), on the ground. It is smoothed through the points and
## laid out in metre steps.
func set_trail(points: PackedVector3Array) -> void:
	if points.size() < 2:
		return
	# (a smooth curve through the points, then even steps along it)
	var dense := PackedVector3Array()
	for i in points.size() - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for k in 8:
			var t := k / 8.0
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	dense.append(points[points.size() - 1])
	_trail = PackedVector3Array([dense[0]])
	var carried := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var b := dense[i]
		var length := a.distance_to(b)
		while carried + length >= TRAIL_STEP:
			var t := (TRAIL_STEP - carried) / length
			a = a.lerp(b, t)
			length = a.distance_to(b)
			carried = 0.0
			_trail.append(a)
		carried += length
	if _trail[_trail.size() - 1].distance_to(dense[dense.size() - 1]) > 0.3:
		_trail.append(dense[dense.size() - 1])
	_trail_length = float(_trail.size() - 1) * TRAIL_STEP
	_nest = _trail[0]
	if is_inside_tree():
		_lay_out()


func trail() -> PackedVector3Array:
	return _trail


func trail_length() -> float:
	return _trail_length


func nest() -> Vector3:
	return _nest


## Where on the trail `s` metres from the nest is, `side` metres to its left.
func trail_point(s: float, side := 0.0) -> Vector3:
	if _trail.size() < 2:
		return _nest
	var at := clampf(s / TRAIL_STEP, 0.0, float(_trail.size() - 1) - 0.0001)
	var i := int(at)
	var a := _trail[i]
	var b := _trail[i + 1]
	var p := a.lerp(b, at - i)
	if side != 0.0:
		var along := (b - a)
		along.y = 0.0
		along = along.normalized()
		p += Vector3(-along.z, 0.0, along.x) * side
	return p


## The way along the trail at `s` (away from the nest), flat.
func trail_way(s: float) -> Vector3:
	var at := clampi(int(s / TRAIL_STEP), 0, _trail.size() - 2)
	var way := _trail[at + 1] - _trail[at]
	way.y = 0.0
	return way.normalized() if way.length() > 0.001 else Vector3.FORWARD


## How far `point` is from the trail (flat), and how far along it the nearest place is.
func off_trail(point: Vector3) -> Vector2:
	var best := INF
	var best_s := 0.0
	for i in _trail.size() - 1:
		var a := Vector2(_trail[i].x, _trail[i].z)
		var b := Vector2(_trail[i + 1].x, _trail[i + 1].z)
		var p := Vector2(point.x, point.z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_s = (i + t) * TRAIL_STEP
	return Vector2(best, best_s)


## The height of the mound's face at `r` metres from the middle of the hole
## (from the ground): a black mouth at the ground, a steep inner wall up to the
## rim, and the spoil heaped round it falling away to the ground.
static func mound_height(r: float) -> float:
	if r < HOLE_RADIUS:
		return 0.03
	var rim := 1.2
	if r < rim:
		return 0.03 + (RIM_HEIGHT - 0.03) * sin((r - HOLE_RADIUS) / (rim - HOLE_RADIUS) * PI * 0.5) ** 0.7
	return RIM_HEIGHT * (1.0 - smoothstep(rim, MOUND_RADIUS, r)) ** 1.5


## Where an ant's feet are at `r` metres from the middle of the hole: on the
## mound, or going down the hole (under the black of its mouth).
static func floor_height(r: float) -> float:
	if r < HOLE_RADIUS:
		return -HOLE_DEPTH * (1.0 - (r / HOLE_RADIUS) ** 2)
	return mound_height(r)


# Builds what is drawn of the nest and the trail where they now are.
func _lay_out() -> void:
	if _nest_mesh:
		_nest_mesh.global_transform = Transform3D(Basis.IDENTITY, _nest)
	if _trail_mesh:
		_trail_mesh.mesh = _trail_ribbon()
	var reach := 0.0
	for p in _trail:
		reach = maxf(reach, p.distance_to(_nest))
	reach += forage_radius + alarm_reach + 10.0
	var box := AABB(_nest - Vector3(reach, 8.0, reach), Vector3(reach * 2.0, 16.0, reach * 2.0))
	for drawn: MultiMeshInstance3D in [_near_drawn, _far_drawn]:
		if drawn:
			drawn.custom_aabb = box


# A mound of dug-out soil round a black hole: lumpy, crumbling, damp and dark
# at the lip, drier and paler on top, with crumbs of it scattered round.
func _mound() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var sides := 40
	var shake := RandomNumberGenerator.new()
	shake.seed = colony_seed + 17
	var bumps: Array[float] = []
	for k in sides:
		bumps.append(shake.randf_range(0.85, 1.15))
	# (smoothed round, so that it is heaped, not peaked)
	for pass_number in 2:
		var smoothed: Array[float] = []
		for k in sides:
			smoothed.append((bumps[(k + sides - 1) % sides] + bumps[k] * 2.0 + bumps[(k + 1) % sides]) * 0.25)
		bumps = smoothed
	var grid: Array = []
	for i in rings + 1:
		var row: Array = []
		var t := float(i) / rings
		# (rings close together at the mouth and the rim, where the shape turns)
		var r := HOLE_RADIUS * 0.999 * t * 3.0 if i <= 3 else lerpf(HOLE_RADIUS, MOUND_RADIUS * 1.08, ((i - 3.0) / (rings - 3.0)) ** 1.3)
		if i == 0:
			r = 0.0
		for k in sides:
			var a := TAU * k / sides + (shake.randf_range(-0.04, 0.04) if r > HOLE_RADIUS else 0.0)
			var lump := lerpf(1.0, bumps[k] * (0.85 + 0.3 * sin(a * 5.0 + i * 0.7)), clampf((r - HOLE_RADIUS) / 0.6, 0.0, 1.0))
			var h := mound_height(r)
			if r > HOLE_RADIUS:
				h = h * lump + shake.randf_range(-0.018, 0.018) * float(i < rings)
			# (the mouth's edge is ragged)
			var reach := r * (shake.randf_range(0.9, 1.08) if i == 3 else 1.0)
			if i == rings:
				h = -0.05
			row.append(Vector3(cos(a) * reach, h, sin(a) * reach))
		grid.append(row)
	for i in rings:
		for k in sides:
			var n := (k + 1) % sides
			var quad: Array = [grid[i][k], grid[i][n], grid[i + 1][n], grid[i + 1][k]]
			for corner: Vector3 in [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]]:
				tool.set_color(_soil(corner))
				tool.add_vertex(corner)
	# Crumbs: little clods of spoil rolled down off the heap
	for c in 70:
		var a := shake.randf() * TAU
		var r := shake.randf_range(MOUND_RADIUS * 0.75, MOUND_RADIUS * 1.6)
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
		at.y = maxf(mound_height(r), 0.0)
		var size := shake.randf_range(0.04, 0.11)
		var top := at + Vector3(0.0, size * 0.9, 0.0)
		var round: Array[Vector3] = []
		for k in 4:
			var b := a + TAU * k / 4.0 + shake.randf_range(-0.3, 0.3)
			round.append(at + Vector3(cos(b), 0.0, sin(b)) * size * shake.randf_range(0.8, 1.3) - Vector3.UP * 0.02)
		for k in 4:
			for corner: Vector3 in [top, round[k], round[(k + 1) % 4]]:
				tool.set_color(_soil(corner) * 0.9)
				tool.add_vertex(corner)
	tool.generate_normals()
	var made := tool.commit()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 1.0
	paint.metallic_specular = 0.0
	made.surface_set_material(0, paint)
	return made


# The soil's colour at a point of the mound: black in the mouth, dark and damp
# at its lip, paler and drier over the top of the heap, damp again at its foot.
static func _soil(at: Vector3) -> Color:
	var r := Vector2(at.x, at.z).length()
	var dark := smoothstep(HOLE_RADIUS * 1.15, HOLE_RADIUS * 0.85, r)
	var dry := smoothstep(0.9, 1.7, r) * (1.0 - smoothstep(2.1, MOUND_RADIUS * 1.1, r) * 0.7)
	var grain := 0.92 + 0.16 * fposmod(sin(at.x * 41.0 + at.z * 17.0) * 437.0, 1.0)
	var soil := Color(0.16, 0.145, 0.13).lerp(Color(0.27, 0.25, 0.22), dry) * grain
	return soil.lerp(Color(0.01, 0.008, 0.007), dark)


# The trodden trail: a dark, patchy streak on the ground, softening at its edges.
func _trail_ribbon() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := trail_width * 0.5
	var lefts: Array[Vector3] = []
	var mids: Array[Vector3] = []
	var rights: Array[Vector3] = []
	var shades: Array[float] = []
	var noise := RandomNumberGenerator.new()
	noise.seed = colony_seed + 3
	for i in _trail.size():
		var s := i * TRAIL_STEP
		var way := trail_way(s)
		var side := Vector3(-way.z, 0.0, way.x)
		var p := _trail[i] + Vector3.UP * 0.05
		# (it starts at the rim of the mound, and fades out where they forage)
		var r := Vector2(p.x - _nest.x, p.z - _nest.z).length()
		if r < MOUND_RADIUS:
			p.y = _nest.y + maxf(mound_height(r), 0.0) + 0.03
		var wobble := half * noise.randf_range(0.7, 1.25)
		lefts.append(p + side * wobble)
		mids.append(p)
		rights.append(p - side * wobble)
		var fade := smoothstep(0.0, 3.0, s) * (1.0 - smoothstep(_trail_length - 6.0, _trail_length, s))
		shades.append(fade * noise.randf_range(0.45, 0.85))
	var dark := Color(0.06, 0.055, 0.05)
	for i in _trail.size() - 1:
		for strip: Array in [[lefts, mids, 0.0, 1.0], [mids, rights, 1.0, 0.0]]:
			var a: Array[Vector3] = strip[0]
			var b: Array[Vector3] = strip[1]
			var ea: float = strip[2]
			var eb: float = strip[3]
			var corners := [[a[i], ea * shades[i]], [b[i], eb * shades[i]], [b[i + 1], eb * shades[i + 1]], [a[i + 1], ea * shades[i + 1]]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				tool.set_color(Color(dark, corners[k][1] * 0.8))
				tool.set_normal(Vector3.UP)
				tool.add_vertex(corners[k][0])
	var made := tool.commit()
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.disable_receive_shadows = true
	made.surface_set_material(0, paint)
	return made


# --- Starting off ---

## Puts every ant where it would be after a while of going about (from the seed):
## some in the nest, the rest in lines along the trail, a few foraging; the
## soldiers round the nest. Nothing alarmed.
func start() -> void:
	_rng.seed = colony_seed
	alarm_up = false
	_alarm_at = Vector3.INF
	target = Vector3.INF
	var lines: Array = []
	var line := 0
	var k := 0
	for ant in ants:
		ant.wait = -1.0
		ant.alarm = 0.0
		ant.bite = 0.0
		ant.loaded = false
		if ant.soldier:
			ant.state = State.GUARD
			ant.pos = _guard_spot()
			ant.yaw = _rng.randf() * TAU
			ant.timer = _rng.randf_range(0.0, 3.0)
			ant.goal = ant.pos
			continue
		var pick := _rng.randf()
		if pick < 0.25:
			ant.state = State.NEST
			ant.timer = _rng.randf_range(0.0, nest_time.y)
			ant.pos = _nest + Vector3.DOWN * HOLE_DEPTH
		elif pick < 0.35:
			ant.state = State.FORAGE
			ant.goal = _forage_spot()
			ant.pos = _forage_spot()
			ant.timer = _rng.randf_range(forage_time.x, forage_time.y)
		else:
			# (in lines of two to four, one behind another)
			if k == 0 or _rng.randf() < 0.3:
				lines.append([_rng.randf_range(2.0, _trail_length - 2.0), _rng.randf() < 0.5])
				line = lines.size() - 1
			var at: Array = lines[line]
			k += 1
			ant.out = at[1]
			ant.s = clampf(float(at[0]) - (k % 4) * 1.5 * (1.0 if ant.out else -1.0), 0.5, _trail_length - 0.5)
			ant.state = State.OUT if ant.out else State.HOME
			ant.loaded = not ant.out and _rng.randf() < 0.55
			ant.pos = _on_trail(ant)
			ant.yaw = _yaw_of(trail_way(ant.s) * (1.0 if ant.out else -1.0))


func _guard_spot() -> Vector3:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(MOUND_RADIUS * 0.9, guard_radius)
	var at := _nest + Vector3(cos(a), 0.0, sin(a)) * r
	if forbid.is_valid() and forbid.call(at):
		at = _nest + (_trail_end_way() * r)
	at.y = _ground_at(at)
	return at


func _forage_spot() -> Vector3:
	var end := _trail[_trail.size() - 1]
	for tries in 6:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * forage_radius
		var at := end + Vector3(cos(a), 0.0, sin(a)) * r
		if not forbid.is_valid() or not forbid.call(at):
			at.y = _ground_at(at)
			return at
	return end


func _trail_end_way() -> Vector3:
	return trail_way(0.0)


# --- What the game does ---

## Raises the alarm at `at`: it runs out through them from there.
func alarm(at: Vector3) -> void:
	var first := not alarm_up
	alarm_up = true
	_alarm_at = at
	var near_nest := at.distance_to(_nest) < alarm_reach
	var out_of_nest := 0
	for ant in ants:
		if ant.state in [State.ALERT, State.RUSH, State.ON, State.FLUNG] or ant.wait >= 0.0:
			continue
		var d := ant.pos.distance_to(at)
		if ant.state == State.NEST:
			# (those in the nest pour out if it is near enough)
			if near_nest:
				var out := _rng.randf() * TAU
				ant.pos = _nest + Vector3(cos(out), 0.0, sin(out)) * _rng.randf_range(0.2, HOLE_RADIUS * 0.8) + Vector3.DOWN * HOLE_DEPTH * 0.5
				ant.wait = _nest.distance_to(at) / alarm_wave + 0.3 + out_of_nest * 0.18
				out_of_nest += 1
			continue
		if ant.soldier and near_nest:
			d = minf(d, _nest.distance_to(at) * 0.8)
		if d < alarm_reach:
			ant.wait = d / alarm_wave + _rng.randf_range(0.0, 0.25)
	if first:
		alarmed.emit(at)


## The alarm is over: back to the trail, or the nest, as they were.
func calm() -> void:
	alarm_up = false
	_alarm_at = Vector3.INF
	target = Vector3.INF
	for ant in ants:
		ant.wait = -1.0
		if ant.state in [State.ALERT, State.RUSH, State.ON, State.FLUNG]:
			_to_calm(ant)
	if _thing and _thing_sink < 0.0:
		_take_hold()


## Throws off every one on the target (as when it has been caught).
func shake_off() -> void:
	for ant in ants:
		if ant.state == State.ON:
			_fling(ant)
	_overwhelm = 0.0


## Sends `haulers` workers for `thing`, to drag it home into the nest. False if
## they are already carrying something.
func carry(thing: Node3D) -> bool:
	if _thing and is_instance_valid(_thing):
		return false
	_thing = thing
	_thing_sink = -1.0
	_thing_base = thing.global_position.y
	# (the way home: to the nearest place on the trail, then along it)
	var near := off_trail(thing.global_position)
	_thing_route = PackedVector3Array([thing.global_position])
	_thing_s = near.y
	_take_hold()
	return true


## What they are carrying now (null: nothing).
func carrying() -> Node3D:
	return _thing if _thing and is_instance_valid(_thing) else null


## Takes one ant away (eaten): it goes back into the nest, to come out later.
func lose(index: int) -> void:
	if index < 0 or index >= ants.size():
		return
	var ant := ants[index]
	ant.state = State.NEST
	ant.wait = -1.0
	ant.timer = nest_time.y * 3.0
	ant.pos = _nest + Vector3.DOWN * HOLE_DEPTH


func _take_hold() -> void:
	var free: Array[Ant] = []
	for ant in ants:
		if not ant.soldier and ant.state in [State.OUT, State.HOME, State.FORAGE, State.NEST, State.CALM, State.FETCH, State.HAUL]:
			free.append(ant)
	var at := _thing.global_position
	free.sort_custom(func(a: Ant, b: Ant) -> bool: return _cost_to(a, at) < _cost_to(b, at))
	for ant in ants:
		if ant.state in [State.FETCH, State.HAUL]:
			ant.state = State.CALM
			_to_calm(ant)
	for k in mini(haulers, free.size()):
		var ant := free[k]
		var a := TAU * k / haulers + 0.4
		ant.haul_slot = Vector3(cos(a), 0.0, sin(a)) * 0.95
		if ant.state == State.NEST:
			ant.pos = _nest + Vector3.DOWN * HOLE_DEPTH * 0.5
		ant.state = State.FETCH
		ant.way_in = 0


func _cost_to(ant: Ant, at: Vector3) -> float:
	return (ant.pos.distance_to(at) if ant.state != State.NEST else _nest.distance_to(at) + 10.0)


# --- Reading ---

func ant_position(i: int) -> Vector3:
	return ants[i].pos


func ant_state(i: int) -> State:
	return ants[i].state as State


func counted(state: State) -> int:
	var n := 0
	for ant in ants:
		if ant.state == state:
			n += 1
	return n


## How many are alarmed (taking it up, running, on the target or thrown off).
func alarmed_count() -> int:
	var n := 0
	for ant in ants:
		if ant.state in [State.ALERT, State.RUSH, State.ON, State.FLUNG]:
			n += 1
	return n


## The nearest ant out of the nest to `point` (-1: none), and how far.
func nearest_ant(point: Vector3) -> Vector2:
	var best := -1
	var far := INF
	for i in ants.size():
		if ants[i].state == State.NEST:
			continue
		var d := ants[i].pos.distance_to(point)
		if d < far:
			far = d
			best = i
	return Vector2(best, far)


# --- Each frame ---

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_time += delta
	_tick += 1
	_meet_in -= delta
	if _meet_in <= 0.0:
		_meet_in = 0.3
		_meetings()
	# (counted first, and kept up as they seize and are thrown off, so that no more than `most_on` hold on)
	on_target = counted(State.ON)
	gap = INF
	var rushing := 0
	var middle := Vector3.ZERO
	for i in ants.size():
		var ant := ants[i]
		var was := ant.pos
		if ant.wait >= 0.0:
			ant.wait -= delta
			if ant.wait < 0.0:
				_alert(ant)
		match ant.state:
			State.NEST:
				_nest_step(ant, delta)
			State.OUT, State.HOME:
				_trail_step(ant, delta)
			State.FORAGE:
				_forage_step(ant, delta)
			State.GUARD:
				_guard_step(ant, delta)
			State.ALERT:
				_alert_step(ant, delta)
			State.RUSH:
				_rush_step(ant, delta, i)
				rushing += 1
				middle += ant.pos
			State.ON:
				_on_step(ant, delta)
				rushing += 1
				middle += ant.pos
			State.FLUNG:
				_flung_step(ant, delta)
			State.CALM:
				_calm_step(ant, delta, i)
			State.FETCH:
				_fetch_step(ant, delta, i)
			State.HAUL:
				_haul_step(ant, delta)
		var moved := ant.pos - was
		moved.y = 0.0
		ant.speed = lerpf(ant.speed, moved.length() / maxf(delta, 0.0001), minf(delta * 12.0, 1.0))
		ant.phase = fposmod(ant.phase + moved.length() / maxf(0.52 * ant.size, 0.01), 1.0)
		var alarmed_now := ant.state in [State.ALERT, State.RUSH, State.ON, State.FLUNG]
		ant.alarm = move_toward(ant.alarm, 1.0 if alarmed_now else 0.0, delta * (6.0 if alarmed_now else 1.5))
		ant.bite = move_toward(ant.bite, 1.0 if ant.state == State.ON else 0.0, delta * 8.0)
		if target.is_finite() and ant.state != State.NEST:
			var d := Vector2(ant.pos.x - target.x, ant.pos.z - target.z).length()
			if d < gap:
				gap = d
				front = ant.pos
	_haul_thing(delta)
	# (a target tearing free, going faster than `grip_speed` or off the ground, is not held)
	var tearing := Vector2(target_moving.x, target_moving.z).length() > grip_speed or not target_grounded
	if on_target >= catch_count and not tearing:
		_overwhelm += delta
		if _overwhelm >= catch_time:
			_overwhelm = 0.0
			overwhelmed.emit()
	else:
		_overwhelm = maxf(_overwhelm - delta * 2.0, 0.0)
	if _patter:
		var loud := clampf(rushing / 6.0, 0.0, 1.0)
		if loud > 0.0:
			_patter.global_position = middle / maxi(rushing, 1)
			if not _patter.playing:
				_patter.play()
		_patter.volume_db = lerpf(_patter.volume_db, (volume_db - 4.0 + 6.0 * loud) if loud > 0.0 else -60.0, minf(delta * 4.0, 1.0))
		if _patter.volume_db < -55.0 and _patter.playing:
			_patter.stop()
	_draw_ants()


func _alert(ant: Ant) -> void:
	ant.wait = -1.0
	if ant.state == State.NEST:
		var out := _rng.randf() * TAU
		ant.pos = _nest + Vector3(cos(out), 0.0, sin(out)) * _rng.randf_range(0.3, HOLE_RADIUS) + Vector3.DOWN * HOLE_DEPTH * 0.3
	ant.state = State.ALERT
	ant.timer = alert_time * _rng.randf_range(0.8, 1.3)
	_click(ant.pos)


func _click(at: Vector3) -> void:
	clicked.emit(at)
	if _clicker and is_inside_tree():
		_clicker.global_position = at + Vector3.UP * 0.3
		_clicker.pitch_scale = _rng.randf_range(0.85, 1.25)
		_clicker.play()


func _to_calm(ant: Ant) -> void:
	ant.state = State.CALM
	ant.pitch = 0.0
	ant.roll = 0.0
	ant.way_in = 0
	if ant.soldier:
		ant.goal = _guard_spot()
	else:
		var near := off_trail(ant.pos)
		ant.s = clampf(near.y, 0.5, _trail_length - 0.5)
		ant.out = _rng.randf() < 0.5
		ant.goal = _on_trail(ant)


# Where an ant on the trail at its `s` is, in its lane and weaving.
func _on_trail(ant: Ant) -> Vector3:
	var side := ant.lane + 0.14 * sin(ant.s * 0.8 + ant.weave)
	var p := trail_point(ant.s, side if ant.out else -side)
	var r := Vector2(p.x - _nest.x, p.z - _nest.z).length()
	if r < MOUND_RADIUS:
		p.y = _nest.y + floor_height(r)
	return p


func _yaw_of(way: Vector3) -> float:
	return atan2(way.x, way.z)


func _turn(ant: Ant, way: Vector3, delta: float, rate := 8.0) -> void:
	if Vector2(way.x, way.z).length() < 0.001:
		return
	ant.yaw = rotate_toward(ant.yaw, _yaw_of(way), rate * delta)


func _ground_at(point: Vector3) -> float:
	var r := Vector2(point.x - _nest.x, point.z - _nest.z).length()
	var base := float(ground.call(point)) if ground.is_valid() else _trail_height_near(point)
	if r < MOUND_RADIUS:
		return _nest.y + floor_height(r)
	return base


func _trail_height_near(point: Vector3) -> float:
	if _trail.is_empty():
		return point.y
	return trail_point(off_trail(point).y).y


# Off the trail: moves `ant` towards `goal` at `speed`, round walls when there is a guide; whether it is there.
func _go(ant: Ant, goal: Vector3, speed: float, delta: float, index: int, near := 0.4) -> bool:
	var to := goal - ant.pos
	to.y = 0.0
	if to.length() < near:
		return true
	var aim := goal
	if guide.is_valid():
		ant.way_in -= 1
		if ant.way_in <= 0 or not ant.way.is_finite():
			ant.way_in = 8 + index % 5
			ant.way = guide.call(ant.pos, goal)
		aim = ant.way
		if Vector2(aim.x - ant.pos.x, aim.z - ant.pos.z).length() < 0.6:
			aim = goal
			ant.way_in = 0
	var way := aim - ant.pos
	way.y = 0.0
	way = way.normalized()
	_turn(ant, way, delta, 10.0)
	var ahead := Vector3(sin(ant.yaw), 0.0, cos(ant.yaw))
	# (it goes the way it faces, so it turns as it runs; slower while it is turned far off its way)
	var step := ahead * speed * delta * clampf(ahead.dot(way) * 1.2, 0.2, 1.0)
	var next := ant.pos + step
	if forbid.is_valid() and forbid.call(next):
		var along_x := ant.pos + Vector3(step.x, 0.0, 0.0)
		var along_z := ant.pos + Vector3(0.0, 0.0, step.z)
		next = along_x if not forbid.call(along_x) else (along_z if not forbid.call(along_z) else ant.pos)
	ant.ground_in -= 1
	if ant.ground_in <= 0:
		ant.ground_in = 4 + index % 3
		ant.floor_y = _ground_at(next)
	next.y = lerpf(ant.pos.y, ant.floor_y if not is_nan(ant.floor_y) else next.y, minf(delta * 10.0, 1.0))
	ant.pos = next
	return to.length() < near + speed * delta


func _nest_step(ant: Ant, delta: float) -> void:
	ant.timer -= delta
	if ant.timer <= 0.0:
		ant.state = State.OUT
		ant.out = true
		ant.s = 0.0
		ant.loaded = false
		ant.pos = _nest + Vector3.DOWN * HOLE_DEPTH
		ant.yaw = _yaw_of(trail_way(0.0))


func _trail_step(ant: Ant, delta: float) -> void:
	if ant.meet > 0.0:
		ant.meet -= delta
		return
	var speed := walk_speed * ant.pace * (0.8 if ant.loaded else 1.0)
	# (out of the hole and up over the rim it climbs slowly)
	if ant.s < 2.0:
		speed *= 0.7
	ant.s += speed * delta * (1.0 if ant.out else -1.0)
	var at := _on_trail(ant)
	if ant.s < HOLE_RADIUS * 0.6:
		at = _nest + (at - _nest) * 0.5
		at.y = _nest.y + floor_height(Vector2(at.x - _nest.x, at.z - _nest.z).length())
	var way := at - ant.pos
	way.y = 0.0
	if way.length() > 0.001:
		_turn(ant, way, delta, 6.0)
	ant.pos = at
	# (on the slope of the mound and down the hole it tips with the ground)
	var r := Vector2(at.x - _nest.x, at.z - _nest.z).length()
	ant.pitch = -atan((floor_height(r + 0.3) - floor_height(maxf(r - 0.3, 0.0))) / 0.6) * (1.0 if ant.out else -1.0) if r < MOUND_RADIUS else 0.0
	if ant.out and ant.s >= _trail_length:
		ant.state = State.FORAGE
		ant.goal = _forage_spot()
		ant.timer = _rng.randf_range(forage_time.x, forage_time.y)
	elif not ant.out and ant.s <= 0.0:
		ant.state = State.NEST
		ant.loaded = false
		ant.timer = _rng.randf_range(nest_time.x, nest_time.y)
		ant.pitch = 0.0


func _forage_step(ant: Ant, delta: float) -> void:
	ant.timer -= delta
	if ant.timer <= 0.0:
		ant.state = State.HOME
		ant.out = false
		ant.s = _trail_length
		ant.loaded = _rng.randf() < 0.55
		ant.way_in = 0
		return
	if _go(ant, ant.goal, walk_speed * 0.7 * ant.pace, delta, 0):
		# (it stops a moment, feeling about, and tries somewhere else)
		ant.goal = _forage_spot() if _rng.randf() < 0.04 else ant.goal
		if _rng.randf() < delta * 1.5:
			ant.goal = _forage_spot()


func _guard_step(ant: Ant, delta: float) -> void:
	ant.timer -= delta
	if ant.timer > 0.0:
		# (standing: it turns a little now and then)
		if _rng.randf() < delta * 0.5:
			ant.yaw += _rng.randf_range(-0.8, 0.8)
		return
	if _go(ant, ant.goal, walk_speed * 0.55, delta, 1):
		ant.timer = _rng.randf_range(1.5, 5.0)
		ant.goal = _guard_spot()


func _alert_step(ant: Ant, delta: float) -> void:
	ant.timer -= delta
	var at := target if target.is_finite() else _alarm_at
	if at.is_finite():
		_turn(ant, at - ant.pos, delta, 9.0)
	# (it rears a little where it stands)
	ant.pitch = move_toward(ant.pitch, -0.18, delta * 2.0)
	if ant.timer <= 0.0:
		ant.state = State.RUSH
		ant.pitch = 0.0
		ant.way_in = 0


func _rush_step(ant: Ant, delta: float, index: int) -> void:
	var at := target if target.is_finite() else _alarm_at
	if not at.is_finite():
		_to_calm(ant)
		return
	var flat := Vector2(at.x - ant.pos.x, at.z - ant.pos.z).length()
	var reach := target_radius + bite_reach
	if target.is_finite() and flat < reach + 0.35 and on_target < most_on and absf(at.y - ant.pos.y) < 2.0:
		ant.state = State.ON
		on_target += 1
		ant.slot = atan2(ant.pos.x - at.x, ant.pos.z - at.z)
		ant.grip = 0.0
		_click(ant.pos)
		return
	# (the rest mill round those on it, a body's width further out)
	var goal := at
	if target.is_finite() and on_target >= most_on and flat < reach + 2.0:
		var a := atan2(ant.pos.x - at.x, ant.pos.z - at.z) + delta * 1.6
		goal = at + Vector3(sin(a), 0.0, cos(a)) * (reach + 1.1)
	goal += _apart(ant, index) * 0.8
	# (each at its own pace, but none much faster than `run_speed`: a sprint must get away)
	_go(ant, goal, run_speed * clampf(ant.pace, 0.9, 1.04), delta, index, 0.05)


# A push away from the others near it that are running too.
func _apart(ant: Ant, index: int) -> Vector3:
	var push := Vector3.ZERO
	for k in ants.size():
		var other := ants[k]
		if other == ant or not (other.state in [State.RUSH, State.ON]):
			continue
		var out := ant.pos - other.pos
		out.y = 0.0
		var d := out.length()
		if d < 1.1 and d > 0.001:
			push += out / d * (1.1 - d)
	return push


func _on_step(ant: Ant, delta: float) -> void:
	if not target.is_finite():
		_to_calm(ant)
		return
	var moving := Vector2(target_moving.x, target_moving.z).length()
	if moving > grip_speed or not target_grounded:
		ant.grip += delta * (1.0 + 2.0 * float(not target_grounded))
	else:
		ant.grip = maxf(ant.grip - delta, 0.0)
	if ant.grip > grip_time * ant.pace:
		_fling(ant)
		return
	# (round the target, hanging on: dragged with it, heads up, jaws working)
	ant.slot += sin(_time * 2.0 + ant.weave) * delta * 0.3
	var round := Vector3(sin(ant.slot), 0.0, cos(ant.slot))
	var want := target + round * (target_radius + 0.42 * ant.size)
	ant.pos = ant.pos.lerp(Vector3(want.x, target.y, want.z), minf(delta * 14.0, 1.0))
	ant.yaw = lerp_angle(ant.yaw, _yaw_of(-round), minf(delta * 12.0, 1.0))
	ant.pitch = lerpf(ant.pitch, -0.42 + 0.06 * sin(_time * 17.0 + ant.weave), minf(delta * 10.0, 1.0))
	if _rng.randf() < delta * 1.2:
		_click(ant.pos)


func _fling(ant: Ant) -> void:
	if ant.state == State.ON:
		on_target -= 1
	ant.state = State.FLUNG
	var round := Vector3(sin(ant.slot), 0.0, cos(ant.slot))
	ant.fling = round * _rng.randf_range(2.0, 3.5) + Vector3.UP * _rng.randf_range(2.0, 3.5) + target_moving * 0.25
	ant.timer = _rng.randf_range(0.8, 1.2)
	ant.grip = 0.0


func _flung_step(ant: Ant, delta: float) -> void:
	ant.timer -= delta
	ant.fling.y -= 20.0 * delta
	var next := ant.pos + ant.fling * delta
	if forbid.is_valid() and forbid.call(next):
		ant.fling.x = -ant.fling.x * 0.3
		ant.fling.z = -ant.fling.z * 0.3
		next = ant.pos + Vector3(0.0, ant.fling.y * delta, 0.0)
	var floor := _ground_at(next)
	if next.y <= floor:
		next.y = floor
		ant.fling.y = 0.0
		ant.fling.x *= 0.85
		ant.fling.z *= 0.85
		ant.roll = move_toward(ant.roll, 0.0, delta * 9.0)
	else:
		ant.roll += delta * 11.0
	ant.pos = next
	ant.pitch = move_toward(ant.pitch, 0.0, delta * 4.0)
	if ant.timer <= 0.0:
		ant.roll = 0.0
		if alarm_up:
			ant.state = State.RUSH
			ant.way_in = 0
		else:
			_to_calm(ant)


func _calm_step(ant: Ant, delta: float, index: int) -> void:
	ant.pitch = move_toward(ant.pitch, 0.0, delta * 2.0)
	ant.roll = 0.0
	if ant.soldier:
		if _go(ant, ant.goal, walk_speed, delta, index, 0.6):
			ant.state = State.GUARD
			ant.timer = _rng.randf_range(0.5, 3.0)
		return
	if _go(ant, ant.goal, walk_speed * 1.3, delta, index, 0.5):
		ant.state = State.OUT if ant.out else State.HOME


func _fetch_step(ant: Ant, delta: float, index: int) -> void:
	if _thing == null or not is_instance_valid(_thing):
		_to_calm(ant)
		return
	var slot := _thing.global_position + _thing.global_basis.get_rotation_quaternion() * ant.haul_slot
	if ant.pos.y < _nest.y - 0.2 and ant.pos.distance_to(_nest) < HOLE_RADIUS * 2.0:
		# (coming up out of the hole)
		ant.pos.y = move_toward(ant.pos.y, _nest.y, delta * 1.2)
	if _go(ant, slot, walk_speed * 1.4 * ant.pace, delta, index, 0.3):
		ant.state = State.HAUL


func _haul_step(ant: Ant, delta: float) -> void:
	if _thing == null or not is_instance_valid(_thing):
		_to_calm(ant)
		return
	var round := _thing.global_basis.get_rotation_quaternion() * ant.haul_slot
	var want := _thing.global_position + round
	want.y = _thing_base if _thing_sink < 0.0 else want.y
	ant.pos = ant.pos.lerp(want, minf(delta * 8.0, 1.0))
	ant.yaw = lerp_angle(ant.yaw, _yaw_of(-round), minf(delta * 8.0, 1.0))
	ant.pitch = lerpf(ant.pitch, -0.25, minf(delta * 4.0, 1.0))


# The thing being carried: still until its haulers all have hold of it, then
# dragged to the trail and along it home, and down into the hole.
func _haul_thing(delta: float) -> void:
	if _thing == null:
		return
	if not is_instance_valid(_thing):
		_thing = null
		return
	if _thing_sink >= 0.0:
		_thing_sink += delta
		var t := clampf(_thing_sink / 2.5, 0.0, 1.0)
		_thing.global_position = _nest + Vector3.DOWN * (HOLE_DEPTH + 0.6) * t
		if t >= 1.0:
			_thing.visible = false
			var done := _thing
			_thing = null
			for ant in ants:
				if ant.state == State.HAUL or ant.state == State.FETCH:
					ant.state = State.NEST
					ant.timer = _rng.randf_range(nest_time.x, nest_time.y)
					ant.pos = _nest + Vector3.DOWN * HOLE_DEPTH
			carried_home.emit(done)
		return
	var held := 0
	for ant in ants:
		if ant.state == State.HAUL:
			held += 1
	if held < mini(haulers, 2):
		return
	var at := _thing.global_position
	var aim: Vector3
	var on_trail := off_trail(at)
	if on_trail.x > 1.0 and _thing_s > 0.5:
		aim = trail_point(_thing_s)
		if guide.is_valid():
			aim = guide.call(at, aim)
	else:
		_thing_s = maxf(minf(_thing_s, on_trail.y) - haul_speed * delta, 0.0)
		aim = trail_point(_thing_s)
	var way := aim - at
	way.y = 0.0
	if way.length() > 0.001:
		var step := way.normalized() * minf(haul_speed * delta, way.length())
		_thing.global_position = Vector3(at.x + step.x, 0.0, at.z + step.z)
		var heading := atan2(way.x, way.z)
		_thing.global_rotation.y = lerp_angle(_thing.global_rotation.y, heading, minf(delta * 1.5, 1.0))
	var r := Vector2(_thing.global_position.x - _nest.x, _thing.global_position.z - _nest.z).length()
	_thing_base = _ground_at(_thing.global_position)
	_thing.global_position.y = _thing_base + 0.12 + 0.03 * sin(_time * 6.0)
	if r < HOLE_RADIUS * 1.1 or (_thing_s <= 0.01 and r < MOUND_RADIUS):
		_thing_sink = 0.0


# Out-going and home-coming workers that meet stop nose to nose a moment.
func _meetings() -> void:
	for a in ants:
		if a.state != State.OUT or a.meet > 0.0 or _time - a.met < 4.0:
			continue
		for b in ants:
			if b.state != State.HOME or b.meet > 0.0 or _time - b.met < 4.0:
				continue
			if absf(a.s - b.s) < 1.4 and a.pos.distance_to(b.pos) < 1.5:
				a.meet = 0.5
				b.meet = 0.5
				a.met = _time
				b.met = _time
				break


# --- Drawing them ---

func _draw_ants() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := camera.global_position if camera else _nest
	var near := 0
	var far := 0
	for ant in ants:
		if ant.state == State.NEST:
			continue
		var d := eye.distance_to(ant.pos)
		if d > draw_far:
			continue
		var basis := Basis.from_euler(Vector3(ant.pitch, ant.yaw, ant.roll), EULER_ORDER_YXZ).scaled(Vector3.ONE * ant.size)
		# (rearing, it keeps its hind feet down: lifted by as much as its nose-up tips them under)
		var lift := 0.012 * sin(ant.phase * TAU * 2.0) * clampf(ant.speed / walk_speed, 0.0, 1.0) + maxf(-sin(ant.pitch), 0.0) * 0.4 * ant.size
		var at := ant.pos + Vector3.UP * lift
		var stride := clampf(ant.speed / (walk_speed * 0.9), 0.0, 1.0)
		var custom := Color(ant.phase + roundf(stride * 8.0), (1.0 if ant.soldier else 0.0) + (0.5 if ant.loaded else 0.0), ant.alarm, ant.bite)
		if d < near_detail and not low_poly:
			_write(_near_buffer, near, basis, at, custom)
			near += 1
		else:
			_write(_far_buffer, far, basis, at, custom)
			far += 1
	_near_drawn.multimesh.buffer = _near_buffer
	_near_drawn.multimesh.visible_instance_count = near
	_far_drawn.multimesh.buffer = _far_buffer
	_far_drawn.multimesh.visible_instance_count = far


func _write(buffer: PackedFloat32Array, i: int, basis: Basis, at: Vector3, custom: Color) -> void:
	var o := i * 16
	buffer[o] = basis.x.x
	buffer[o + 1] = basis.y.x
	buffer[o + 2] = basis.z.x
	buffer[o + 3] = at.x
	buffer[o + 4] = basis.x.y
	buffer[o + 5] = basis.y.y
	buffer[o + 6] = basis.z.y
	buffer[o + 7] = at.y
	buffer[o + 8] = basis.x.z
	buffer[o + 9] = basis.y.z
	buffer[o + 10] = basis.z.z
	buffer[o + 11] = at.z
	buffer[o + 12] = custom.r
	buffer[o + 13] = custom.g
	buffer[o + 14] = custom.b
	buffer[o + 15] = custom.a


# --- Their sounds ---

## A click: the snap of a jaw and the creak of a gaster's file (short, dry, high).
static func click_sound() -> AudioStreamWAV:
	if _click_sound:
		return _click_sound
	var rate := 22050
	var long := int(rate * 0.09)
	var noise := RandomNumberGenerator.new()
	noise.seed = 11
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	for k in long:
		var t := float(k) / rate
		# (two quick ticks, then a short dry rasp)
		var tick := exp(-t * 900.0) + 0.7 * exp(-maxf(t - 0.018, 0.0) * 700.0) * float(t >= 0.018)
		var rasp := 0.25 * exp(-maxf(t - 0.03, 0.0) * 60.0) * float(t >= 0.03) * (0.5 + 0.5 * sin(t * TAU * 140.0))
		var raw := noise.randf_range(-1.0, 1.0)
		low += (raw - low) * 0.6
		var sample := (raw - low) * (tick + rasp) + sin(t * TAU * 2900.0) * tick * 0.4
		data.encode_s16(k * 2, int(clampf(sample * 0.5, -1.0, 1.0) * 30000.0))
	_click_sound = AudioStreamWAV.new()
	_click_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_click_sound.mix_rate = rate
	_click_sound.data = data
	return _click_sound


## Many hard feet running on mud: a soft patter, in a loop of two seconds.
static func patter_sound() -> AudioStreamWAV:
	if _patter_sound:
		return _patter_sound
	var rate := 22050
	var long := rate * 2
	var samples := PackedFloat32Array()
	samples.resize(long)
	var chance := RandomNumberGenerator.new()
	chance.seed = 23
	for tap in 420:
		var start := chance.randi_range(0, long - 1)
		var loud := chance.randf_range(0.1, 0.35)
		var length := int(rate * 0.012)
		for k in length:
			samples[(start + k) % long] += chance.randf_range(-1.0, 1.0) * loud * exp(-float(k) / length * 5.0)
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	for k in long:
		low += (samples[k] - low) * 0.35
		data.encode_s16(k * 2, int(clampf(low * 0.9, -1.0, 1.0) * 30000.0))
	_patter_sound = AudioStreamWAV.new()
	_patter_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_patter_sound.mix_rate = rate
	_patter_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_patter_sound.loop_end = long
	_patter_sound.data = data
	return _patter_sound
