class_name FleshMound
extends Node3D
## A flesh mound: people grown together into one thing. `bodies` says how
## many are in it, and that says what it is:
##
## - SMALL (3 or 4, an amalgam): boys fused at the hips in a star, a wheel of
##   arms and legs with their mask faces lolling, about as high as two of
##   them. It shambles on whichever limbs are under it, lurching, its hands
##   and feet planting and pushing; and it CARTWHEELS: it rears up with its
##   limbs splayed (`start_roll`, a warning of `roll_wind_up` s), then tips
##   onto them and rolls itself like a wheel, hands and feet slapping down in
##   turn, until `stop_roll`.
## - BIG (5 to FleshMoundLook.MOST): a heaving mound of grown-together flesh
##   filling more of a hall the more are in it, the boys lying in it face up
##   or rising from it to the waist, men's arms and legs growing out of it.
##   It hauls itself along on the hands at its flanks (on the walls, where
##   they are near), gropes ahead with the hands at its front, and GRABS
##   with them (`grab`, a warning of `wind_up` s).
##
## It GROWS: `absorb(point)` pulls a body in from there (it is seen to be
## dragged in and swallowed) and it gains one; `merge_into(other)` flows it
## into another (over `merge_time` s), which then `grow`s by its bodies.
## Each is the look and the motion only: whatever thinks for it moves this
## node, calls these, and decides what catching means.
##
## USE
##     var mound := FleshMound.new()
##     mound.bodies = 3
##     add_child(mound)
##     # each frame, wherever your mover puts it (on the ground, facing -Z):
##     mound.global_position = body.global_position
##     mound.rotation.y = heading
##     mound.aim = player.global_position             # or Vector3.INF
##     if mound.small(): mound.start_roll()            # ... mound.stop_roll()
##     else: mound.grab(player.global_position)        # when in `reach()`
##     if mound.grab_hits(feet, head, 0.3) or mound.touches(chest, 0.3): ...
##
## Its speed it works out from how it moves (or set `moving`). In a narrow
## space a mound squeezes narrower, taller and longer (`measure_room` casts
## rays to either side against `room_mask`; or set `room`).
##
## COST. Three draws: its core (one mesh, its heaving in the shader), all the
## people in it (one skinned mesh on one skeleton, posed each frame; the
## limbs that only hang are posed a few times a second), its trail; and
## shadows. Changing how many bodies are in it builds the people again (the
## first time for each number takes a moment; `prepare` does it beforehand).
## Set `low_poly` before making it for the low-detail parts.

enum Stage { NONE, WIND_UP, STRIKE, HOLD, RECOVER }
enum Roll { NONE, WIND_UP, ROLLING }

const Role := FleshMoundLook.Role
const TRAIL := 40
const TRAIL_STEP := 1.4

signal grown(bodies: int)
## It has flowed all the way into the other (it is hidden now).
signal merged(into: FleshMound)

## How many bodies are in it (FleshMoundLook.FEWEST to MOST).
@export var bodies := 3:
	set(value):
		value = clampi(value, FleshMoundLook.FEWEST, FleshMoundLook.MOST)
		if value != bodies:
			bodies = value
			if is_inside_tree():
				_rebuild()
## How big it is: 1 is as built.
@export var size := 1.0
## Use the low-detail models (every one made after this is set).
static var low_poly := false
var aim := Vector3.INF
var room := INF
var moving := Vector3.INF
@export var measure_room := true
@export_flags_3d_physics var room_mask := 1
@export var narrowest := 0.25
@export var widest := 1.3
@export var room_margin := 1.0
@export_group("Grab")
@export var wind_up := 0.95
@export var strike := 0.32
@export var hold := 0.6
@export var recover := 1.0
## How far the long arms slide out of it to grab (metres, at size 1).
@export var slide := 1.0
@export_group("Roll")
@export var roll_wind_up := 0.6
@export_group("Growing")
@export var absorb_time := 1.6
@export var merge_time := 2.2
@export_group("Trail")
@export var trail_life := 20.0
@export var trailing := true

var _flesh: Node3D
var _core: MeshInstance3D
var _material: ShaderMaterial
var _skeleton: Skeleton3D
var _skin_material: ShaderMaterial
## A bridge of skin stretched to the one it is flowing into.
var _bridge: MeshInstance3D
var _build: FleshParts.Build
var _trail: MultiMeshInstance3D
var _crawl := 0.0
var _time := 0.0
var _frame := 0
var _was_at := Vector3.INF
var _speed := Vector3.ZERO
var _yaw_was := 0.0
var _turning := 0.0
var _jiggle := Vector3.ZERO
var _jiggle_speed := Vector3.ZERO
var _bounce := 0.0
var _bounce_speed := 0.0
var _squeeze := 1.0
var _room_in := 0.0
var _left := INF
var _right := INF
var _shift := 0.0
var _feel := 0.0
var _swell := 0.0
var _grab_time := INF
var _grab_at := Vector3.ZERO
var _roll := Roll.NONE
var _roll_time := 0.0
## The wheel of a small one: how far it has turned, how high its hub is, how it tips over.
var _wheel := 0.0
var _hub := FleshMoundLook.HUB
## How far below the ground the lowest limb would reach this frame (it presses on that).
var _lowest := 0.0
var _tilt := 0.0
var _u := {"crawl": 0.0, "surge": 0.3, "jiggle": Vector3.ZERO, "bounce": 0.0, "rear": 0.0, "bend": 0.0, "lunge": 0.0}
var _hands := PackedVector3Array()
var _absorbing: Array = []
var _merge_to: FleshMound
var _merge_t := 0.0
## One flowing into it.
var _pulled_by: FleshMound
var _trail_at := PackedVector3Array()
var _trail_way := PackedFloat32Array()
var _trail_wide := PackedFloat32Array()
var _trail_age := PackedFloat32Array()
var _trail_next := 0
var _trail_from := Vector3.INF
var _trail_tick := 0.0


## Builds its people beforehand for these numbers of bodies (so that growing
## does not stop the game for a moment the first time).
static func prepare(counts: Array) -> void:
	for n: int in counts:
		FleshMoundLook.people(n, low_poly or FleshParts.low_poly)


func _ready() -> void:
	_flesh = Node3D.new()
	_flesh.name = "Flesh"
	add_child(_flesh)
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = FleshMoundLook.core(low_poly or FleshParts.low_poly)
	_material = FleshMoundLook.core_material()
	_core.material_override = _material
	_core.extra_cull_margin = 4.0
	_flesh.add_child(_core)
	_trail = FleshMoundLook.trail(TRAIL)
	_trail.name = "Trail"
	add_child(_trail)
	_trail_at.resize(TRAIL)
	_trail_way.resize(TRAIL)
	_trail_wide.resize(TRAIL)
	_trail_age.resize(TRAIL)
	_trail_age.fill(INF)
	_rebuild()
	settle()


## Puts its people together for how many bodies it has now.
func _rebuild() -> void:
	if _skeleton:
		_skeleton.free()
	_build = FleshMoundLook.people(bodies, low_poly or FleshParts.low_poly)
	_skeleton = _build.skeleton()
	_skeleton.name = "People"
	_skeleton.scale = Vector3.ONE * size
	_flesh.add_child(_skeleton)
	var skin := _build.skin_for(_skeleton)
	skin.name = "Skin"
	skin.extra_cull_margin = 6.0
	_skin_material = FleshParts.own_material()
	skin.material_override = _skin_material
	_skeleton.add_child(skin)
	for copy in _build.copies:
		for chain: FleshParts.Chain in copy.chains.values():
			chain.data.clear()
	_swell = 1.0
	_frame = 0
	_prepare_next.call_deferred()


## Stands it still as it is: for when it has been put somewhere in a jump.
func settle() -> void:
	_was_at = Vector3.INF
	_speed = Vector3.ZERO
	_jiggle = Vector3.ZERO
	_jiggle_speed = Vector3.ZERO
	_bounce = 0.0
	_bounce_speed = 0.0
	_grab_time = INF
	_roll = Roll.NONE
	_yaw_was = global_rotation.y if is_inside_tree() else rotation.y
	_trail_from = Vector3.INF
	if _build:
		for copy in _build.copies:
			for chain: FleshParts.Chain in copy.chains.values():
				chain.data.erase("plant")
				chain.data.erase("step")


## A small one: a star of a few, that cartwheels (else a mound, that grabs).
func small() -> bool:
	return bodies <= FleshMoundLook.SMALL


# --- Rolling (small) ---

## Rears up with its limbs splayed (the warning), then rolls (small ones only).
func start_roll() -> void:
	if small() and _roll == Roll.NONE:
		_roll = Roll.WIND_UP
		_roll_time = 0.0


func stop_roll() -> void:
	_roll = Roll.NONE


func roll_stage() -> Roll:
	return _roll


# --- Grabbing (big) ---

## Sends the hands at its front for `target` (big ones only). Does nothing if a grab is under way.
func grab(target: Vector3) -> void:
	if small() or grab_stage() != Stage.NONE:
		return
	_grab_time = 0.0
	_grab_at = target


func grab_stage() -> Stage:
	var t := _grab_time
	if t >= wind_up + strike + hold + recover:
		return Stage.NONE
	if t < wind_up:
		return Stage.WIND_UP
	if t < wind_up + strike:
		return Stage.STRIKE
	return Stage.HOLD if t < wind_up + strike + hold else Stage.RECOVER


func strikes_in() -> float:
	return maxf(wind_up - _grab_time, 0.0)


func grab_target() -> Vector3:
	return _grab_at


## How far from its middle (ahead of it) its hands can grab, metres (0 for a small one).
func reach() -> float:
	if small():
		return 0.0
	var longer := clampf(1.0 / (_squeeze * clampf(pow(_squeeze, -0.35), 0.85, 1.45)), 0.75, 2.4)
	return (FleshMoundLook.radii(bodies).z * longer + 3.0 + slide) * size


## Whether a grabbing hand, now (striking, or just closed), is within `radius` of the line from `a` to `b`.
func grab_hits(a: Vector3, b: Vector3, radius: float) -> bool:
	var stage := grab_stage()
	if stage != Stage.STRIKE and not (stage == Stage.HOLD and _grab_time < wind_up + strike + 0.15):
		return false
	if stage == Stage.STRIKE and _grab_time < wind_up + strike * 0.45:
		return false
	for palm in _hands:
		var near := Geometry3D.get_closest_point_to_segment(palm, a, b)
		if near.distance_to(palm) < radius + 0.25 * size:
			return true
	return false


## Whether `point` (in the world) is in it, or within `margin` metres of it.
func touches(point: Vector3, margin := 0.0) -> bool:
	if not _flesh.visible or _merge_to:
		return false
	if small():
		var hub := _flesh.global_transform * (Vector3.UP * _hub * size)
		return point.distance_to(hub) < (0.95 * FleshMoundLook.boy_size(bodies) / 1.3 + margin) * size
	var local := _core.global_transform.affine_inverse() * point
	var scale_now := _core.global_transform.basis.get_scale()
	var widen := margin / (minf(scale_now.x, minf(scale_now.y, scale_now.z)) * 4.0)
	return FleshMoundLook.inside(local) < 1.0 + widen


func sides() -> Vector2:
	return Vector2(_left, _right)


## The grabbing hands' palms now, in the world.
func hands() -> PackedVector3Array:
	return _hands


func skeleton() -> Skeleton3D:
	return _skeleton


# --- Growing ---

## Drags a body in from `at` (in the world) and swallows it; then it has one more
## (`grown` is emitted). The body is seen being pulled in, its arms up.
func absorb(at: Vector3) -> void:
	var lone := _lone()
	var skeleton := lone.skeleton()
	skeleton.top_level = true
	add_child(skeleton)
	skeleton.add_child(lone.skin_for(skeleton))
	skeleton.global_position = at
	_absorbing.append({"skeleton": skeleton, "from": at, "time": 0.0, "copy": lone.copies[0]})


static var _lone_build: FleshParts.Build


## One boy, alone (for one being absorbed).
static func _lone() -> FleshParts.Build:
	if _lone_build == null:
		_lone_build = FleshParts.Build.new()
		_lone_build.add("boy", Transform3D.IDENTITY, -10.0, 0.0, 0.3, true)
		_lone_build.make()
	return _lone_build


## Being absorbed: how far along (0..1), or -1 when nothing is.
func absorbing() -> float:
	return -1.0 if _absorbing.is_empty() else clampf(_absorbing[0].time / absorb_time, 0.0, 1.0)


## Flows into `other` over `merge_time` s; then `merged` is emitted and it hides.
func merge_into(other: FleshMound) -> void:
	_merge_to = other
	_merge_t = 0.0


## Merging into another: how far along (0..1), or -1.
func merging() -> float:
	return -1.0 if _merge_to == null else clampf(_merge_t / merge_time, 0.0, 1.0)


## Gains `count` bodies (up to the most), swelling as it does.
func grow(count := 1) -> void:
	bodies = mini(bodies + count, FleshMoundLook.MOST)
	_swell = 1.0
	grown.emit(bodies)


# --- Each frame ---

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_frame += 1
	if _grab_time < INF:
		_grab_time += delta
	var at := global_position
	var yaw := global_rotation.y
	var basis := Basis(Vector3.UP, yaw)
	var speed := moving
	if not speed.is_finite():
		speed = (at - _was_at) / delta if _was_at.is_finite() else Vector3.ZERO
		if speed.length() > 30.0:
			speed = Vector3.ZERO
	_was_at = at
	var before := _speed
	_speed = _speed.lerp(Vector3(speed.x, 0.0, speed.z), 1.0 - exp(-8.0 * delta))
	var turn := wrapf(yaw - _yaw_was, -PI, PI) / delta
	_yaw_was = yaw
	_turning = lerpf(_turning, clampf(turn * 0.6, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
	var flat := _speed.length()
	_crawl += flat * delta / size + delta * 0.15
	var accel := basis.inverse() * ((_speed - before) / delta)
	var pull := (-accel * 0.09).limit_length(1.2)
	_jiggle_speed += ((pull - _jiggle) * 30.0 - _jiggle_speed * 3.2) * delta
	_jiggle += _jiggle_speed * delta
	var heave := sin(_crawl * TAU / 3.2) * minf(flat / 2.0, 1.0) * 0.12
	_bounce_speed += ((heave - _bounce) * 40.0 - _bounce_speed * 5.0) * delta
	_bounce += _bounce_speed * delta
	_feel = lerpf(_feel, 1.0 if _aim_now().is_finite() else 0.0, 1.0 - exp(-1.8 * delta))
	_swell = maxf(_swell - delta * 0.8, 0.0)
	_growing(delta)
	if small():
		_pose_star(delta, flat)
	else:
		_squeezing(delta, basis)
		_shade(flat)
		_pose_mound(delta)
	_lay_trail(delta)


## Bodies being absorbed, and merging into another.
func _growing(delta: float) -> void:
	for i in range(_absorbing.size() - 1, -1, -1):
		var it: Dictionary = _absorbing[i]
		it.time += delta
		var t := clampf(it.time / absorb_time, 0.0, 1.0)
		var skeleton: Skeleton3D = it.skeleton
		var into := _flesh.global_transform * (Vector3.UP * (_hub if small() else FleshMoundLook.radii(bodies).y * 0.6) * size)
		var from: Vector3 = it.from
		var pull := smoothstep(0.15, 1.0, t)
		# (dragged along the ground, feet first, toppling back into it)
		var dragged := from.lerp(into, pull)
		dragged.y = lerpf(from.y, into.y * 0.5, pull * pull)
		skeleton.global_position = dragged
		var toward := Vector3(into.x - from.x, 0.0, into.z - from.z).normalized()
		if toward.length() < 0.5:
			toward = Vector3.FORWARD
		# Dragged in backwards, arms reaching out of it, sinking as it goes.
		var lean := FleshParts.frame((Vector3.UP - toward * (0.4 + pull * 2.5)).normalized(), -toward)
		skeleton.global_basis = lean.scaled(Vector3.ONE * lerpf(1.0, 0.6, pull * pull))
		var copy: FleshParts.Copy = it.copy
		var bones := copy.body.pose(skeleton, FleshMoundLook.HIPS, Basis.IDENTITY, 0.2 * sin(_time * 9.0), -0.5, sin(_time * 6.0) * 0.6)
		var reach_out := -toward * 0.6 + Vector3.UP
		for side: String in ["l", "r"]:
			var arm: FleshParts.Chain = copy.chains["arm_" + side]
			var chest: Transform3D = bones[2]
			var root := arm.root_from(chest)
			var flail := Vector3(sin(_time * 11.0 + side.length()), cos(_time * 9.0), sin(_time * 13.0)) * 0.15
			var dir := (skeleton.global_basis.inverse() * reach_out).normalized() + flail + Vector3(arm.side * 0.4, 0.0, 0.0)
			arm.reach_to(skeleton, root, root + dir.normalized() * (arm.upper_long + arm.lower_long) * 0.95, Vector3.BACK, dir.normalized(), Vector3.BACK, chest)
			arm.hand(skeleton, -0.2 + 0.5 * absf(sin(_time * 7.0)), 0.3, 1.0, _time, 1.0)
		_swell = maxf(_swell, pull * 0.6)
		if t >= 1.0:
			skeleton.queue_free()
			_absorbing.remove_at(i)
			grow(1)
	if _merge_to:
		_merge_t += delta
		var t := clampf(_merge_t / merge_time, 0.0, 1.0)
		var to := _merge_to.global_position - global_position
		_merge_to._pulled_by = self
		# First the two reach for each other and a bridge of skin grows between
		# them; then it pours itself along it into the other, shrinking, the
		# bridge thinning as it goes.
		var flow := smoothstep(0.35, 1.0, t)
		_flesh.global_position = global_position + to * flow * 0.9
		var stretch := 1.0 + sin(flow * PI) * 0.5
		_flesh.scale = Vector3(1.0 - flow * 0.6, 1.0 - flow * 0.75, stretch * (1.0 - flow * 0.5))
		_merge_to._swell = maxf(_merge_to._swell, flow)
		_stretch_bridge(t)
		if t >= 1.0:
			_flesh.visible = false
			_bridge.visible = false
			var other := _merge_to
			_merge_to = null
			merged.emit(other)


## The bridge of skin between it and the one it flows into, `t` of the way through.
func _stretch_bridge(t: float) -> void:
	if _bridge == null:
		_bridge = MeshInstance3D.new()
		_bridge.name = "Bridge"
		_bridge.mesh = FleshMoundLook.bridge()
		_bridge.material_override = FleshParts.material()
		_bridge.top_level = true
		add_child(_bridge)
	var mine := _middle_of(self)
	var theirs := _middle_of(_merge_to)
	var along := theirs - mine
	var thick := minf(_girth_of(self), _girth_of(_merge_to)) * 0.8 * sqrt(sin(clampf(t * 1.6, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.75, 1.0, t)))
	if along.length() < 0.01 or thick < 0.01:
		_bridge.visible = false
		return
	_bridge.visible = true
	var basis := FleshParts.frame(along, Vector3.UP.cross(along).cross(along) if absf(along.normalized().y) < 0.95 else Vector3.FORWARD)
	_bridge.global_transform = Transform3D(Basis(basis.x * thick, along, basis.z * thick * 0.8), mine)


## The middle of one's flesh in the world, and about how thick it is.
static func _middle_of(one: FleshMound) -> Vector3:
	var high := (one._hub if one.small() else FleshMoundLook.radii(one.bodies).y * 0.55 + 0.3) * one.size
	return one._flesh.global_position + Vector3.UP * high


static func _girth_of(one: FleshMound) -> float:
	return (0.7 if one.small() else FleshMoundLook.radii(one.bodies).y) * one.size


## What its limbs reach for: whatever it is after, or, merging, the other one.
func _aim_now() -> Vector3:
	if _merge_to:
		return _middle_of(_merge_to)
	if _pulled_by and is_instance_valid(_pulled_by) and _pulled_by._merge_to == self:
		return _middle_of(_pulled_by)
	return aim


# --- A small one: the wheel ---

func _pose_star(delta: float, flat: float) -> void:
	_roll_time += delta
	var s := FleshMoundLook.boy_size(bodies)
	var wind := 0.0
	var press := 0.15
	match _roll:
		Roll.WIND_UP:
			wind = smoothstep(0.0, 1.0, _roll_time / roll_wind_up)
			press = 0.03
			if _roll_time >= roll_wind_up:
				_roll = Roll.ROLLING
		Roll.ROLLING:
			press = 0.07
	# (its hub rides on whichever limbs are under it: the lowest of them, last frame, a little pressed)
	if _lowest > -INF:
		_hub += (_lowest - press * s) * minf(1.0, 10.0 * delta)
	_hub = clampf(_hub, 0.4 * s, 1.6 * s)
	_lowest = -INF
	# Rolling without slipping on what is under it; shambling, lurching on.
	var lurch := 0.0
	if _roll == Roll.ROLLING:
		_wheel += flat * delta / (_hub * size)
		_tilt = lerpf(_tilt, 0.0, 1.0 - exp(-4.0 * delta))
	else:
		lurch = sin(_time * 3.1) * 0.12 + sin(_time * 1.7) * 0.08
		_wheel += flat * delta / (_hub * size) * 0.9 + lurch * delta * 0.6
		_tilt = lerpf(_tilt, 0.22 * sin(_time * 1.3) + 0.1 * sin(_time * 3.7), 1.0 - exp(-3.0 * delta))
		_hub += sin(_time * 4.2) * 0.006
	var tip := Basis(Vector3.FORWARD, _tilt)
	var hub := Vector3.UP * _hub
	# The lump at its hub turns with it.
	var lump := FleshMoundLook.radii(bodies) / FleshMoundLook.RADII
	_core.basis = (tip * Basis(Vector3.RIGHT, -_wheel)).scaled(lump * size * (1.0 + _swell * 0.15))
	_core.position = hub * size - _core.basis * (Vector3.UP * FleshMoundLook.MIDDLE)
	_material.set_shader_parameter(&"breath", sin(_time * 2.0))
	_material.set_shader_parameter(&"pulse", exp(-fposmod(_time * 1.6, 1.0) * 8.0))
	for name: StringName in [&"crawl", &"surge", &"bounce", &"rear", &"bend", &"lunge"]:
		_material.set_shader_parameter(name, 0.0)
	_material.set_shader_parameter(&"jiggle", Vector3.ZERO)
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var ground := (to_skeleton * Vector3(global_position.x, global_position.y + 0.06 * size, global_position.z)).y
	var reach_for := _aim_now() if (_merge_to or _pulled_by) else Vector3.INF
	var local_reach := to_skeleton * reach_for if reach_for.is_finite() else Vector3.INF
	_skin_material.set_shader_parameter(&"core_at", Vector4(0.0, _hub, 0.0, 0.0))
	_skin_material.set_shader_parameter(&"core_size", Vector4(0.3, 0.3, 0.3, 1.0) * Vector4(1.0 + _swell * 0.15, 1.0 + _swell * 0.15, 1.0 + _swell * 0.15, 1.0))
	for copy in _build.copies:
		var d := copy.data
		var spoke: float = d.spoke + _wheel
		var phase: float = d.phase
		var out := tip * Vector3(0.0, cos(spoke), -sin(spoke))
		var front := tip * (d.front as Vector3)
		var frame := FleshParts.frame(out, front)
		var writhe := sin(_time * 2.3 + phase) * 0.15 + wind * 0.25
		# The head lolls down, whichever way that is for it.
		var head_down := clampf(-out.dot(Vector3.DOWN.cross(frame.x).normalized()), -1.0, 1.0)
		var globals := copy.body.pose(_skeleton, hub + out * 0.1 * s, frame, writhe * 0.5, 0.35 + head_down * 0.4 + sin(_time * 1.9 + phase) * 0.2, sin(_time * 1.1 + phase) * 0.4)
		var chest: Transform3D = globals[2]
		var hips: Transform3D = globals[0]
		for chain_name: String in ["arm_l", "arm_r", "leg_l", "leg_r"]:
			var chain: FleshParts.Chain = copy.chains[chain_name]
			var parent := chest if chain.arm else hips
			var root := chain.root_from(parent)
			var across := frame.x * chain.side
			var long := chain.upper_long + chain.lower_long
			var dir: Vector3
			if chain.arm:
				# Arms out past its head, splayed, groping.
				dir = (out * (0.8 - wind * 0.3) + across * (0.5 + wind * 0.5))
				# (merging, they reach out for the other and grip it)
				if local_reach.is_finite():
					dir += (local_reach - root).normalized() * 1.6
			else:
				# Legs across into the gaps between the others.
				dir = (-out * 0.35 + across * 0.9 + out.cross(across) * 0.15)
			dir += Vector3(sin(_time * 3.3 + phase + chain.side), cos(_time * 2.7 + phase), sin(_time * 2.1 - phase)) * (0.12 if _roll != Roll.ROLLING else 0.04)
			dir += Vector3(sin(_time * 40.0 + phase), cos(_time * 37.0), 0.0) * wind * 0.05
			dir = dir.normalized()
			var to := root + dir * long * 0.97
			var palm := (-out + dir * 0.3).normalized()
			var along := dir
			var planted := 0.0
			# Whatever comes down on the ground is planted flat on it and pushes.
			_lowest = maxf(_lowest, ground - to.y)
			if to.y < ground:
				planted = clampf((ground - to.y) / (long * 0.3), 0.0, 1.0)
				to.y = ground
				palm = Vector3.DOWN
				along = Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.05 else Vector3.FORWARD
			var pole := (out * 0.5 + front * (1.0 if chain.arm else -1.0) * 0.5).normalized()
			if chain.arm:
				chain.reach_to(_skeleton, root, to - along * chain.end_long * 0.5, pole, along, palm, parent)
				chain.hand(_skeleton, lerpf(0.45 + 0.3 * sin(_time * 4.0 + phase), 0.1, planted) - wind * 0.4, 0.5 * planted, 0.4 + wind * 0.6, _time, 0.4 + wind)
			else:
				chain.reach_to(_skeleton, root, to, pole, along, palm if planted > 0.0 else -dir, parent)
				chain.curl_toes(_skeleton, 0.4 * planted - 0.2)


# --- A mound ---

func _squeezing(delta: float, basis: Basis) -> void:
	if measure_room:
		_room_in -= delta
		if _room_in <= 0.0 and is_inside_tree():
			_room_in = 0.2
			_measure(basis)
	else:
		_left = INF
		_right = INF
	var r := FleshMoundLook.radii(bodies)
	var built := r.x * 2.0 * size
	var want := clampf((room - room_margin * 2.0) / built, narrowest, widest) if room < INF else 1.0
	_squeeze = lerpf(_squeeze, want, 1.0 - exp(-2.2 * delta))
	var taller := clampf(pow(_squeeze, -0.35), 0.85, 1.45)
	var longer := clampf(1.0 / (_squeeze * taller), 0.75, 2.4)
	_core.basis = Basis.from_scale(Vector3(_squeeze, taller, longer) * (r / FleshMoundLook.RADII) * size * (1.0 + _swell * 0.12))
	var half := r.x * 1.05 * _squeeze * size
	var push_right := maxf(half + room_margin - _left, 0.0)
	var push_left := maxf(half + room_margin - _right, 0.0)
	var shift := push_right - push_left
	if push_right > 0.0 and push_left > 0.0:
		shift = (_right - _left) * 0.5
	var most := half * 0.66
	_shift = lerpf(_shift, clampf(shift, -most, most), 1.0 - exp(-3.0 * delta))
	_core.position = Vector3(_shift, 0.0, 0.0)


func _measure(basis: Basis) -> void:
	var space := get_world_3d().direct_space_state
	var across := basis * Vector3.RIGHT
	var far := 30.0 * size
	_left = INF
	_right = INF
	for high: float in [1.0, 3.0]:
		var from := global_position + Vector3.UP * high * size
		for side: float in [-1.0, 1.0]:
			var query := PhysicsRayQueryParameters3D.create(from, from + across * side * far, room_mask)
			var hit := space.intersect_ray(query)
			var gap := from.distance_to(hit["position"]) if not hit.is_empty() else INF
			if side < 0.0:
				_left = minf(_left, gap)
			else:
				_right = minf(_right, gap)
	room = _left + _right


func _shade(flat: float) -> void:
	var t := _grab_time
	var rear := 0.0
	var lunge := 0.0
	match grab_stage():
		Stage.WIND_UP:
			rear = smoothstep(0.0, 0.8, t / wind_up) * 0.55
		Stage.STRIKE:
			var s := (t - wind_up) / strike
			rear = 0.55 - smoothstep(0.0, 1.0, s) * 0.7
			lunge = smoothstep(0.0, 1.0, s) * 1.1
		Stage.HOLD:
			rear = -0.15
			lunge = 1.1
		Stage.RECOVER:
			var s := smoothstep(0.0, 1.0, (t - wind_up - strike - hold) / recover)
			rear = -0.15 * (1.0 - s)
			lunge = 1.1 * (1.0 - s)
		_:
			rear = _feel * 0.15 + 0.04 * sin(_time * 0.7)
	var beat := fposmod(_time * 1.0, 1.0)
	var pulse := exp(-beat * 9.0) + 0.6 * exp(-absf(beat - 0.22) * 14.0) + _swell
	_u.crawl = _crawl
	_u.surge = 0.35 + minf(flat / 1.5, 1.0) * 0.75
	_u.jiggle = _jiggle
	_u.bounce = _bounce
	_u.rear = rear
	_u.bend = _turning
	_u.lunge = lunge
	_material.set_shader_parameter(&"crawl", _u.crawl)
	_material.set_shader_parameter(&"surge", _u.surge)
	_material.set_shader_parameter(&"breath", sin(_time * 1.2) + _swell * 2.0)
	_material.set_shader_parameter(&"pulse", pulse)
	_material.set_shader_parameter(&"jiggle", _jiggle)
	_material.set_shader_parameter(&"bounce", _bounce)
	_material.set_shader_parameter(&"rear", rear)
	_material.set_shader_parameter(&"bend", _turning)
	_material.set_shader_parameter(&"lunge", lunge)


## Where a copy's root is now in the skeleton's space (it heaves with the core).
func _root(copy: FleshParts.Copy) -> Vector3:
	var moved := _core.transform * FleshMoundLook.heave(copy.data.anchor, _u)
	return moved / size + (copy.data.offset as Vector3) * (1.0 + _swell * 0.1)


func _grab_weights() -> Vector3:
	var t := _grab_time
	match grab_stage():
		Stage.WIND_UP:
			return Vector3(smoothstep(0.0, 0.7, t / wind_up), 0.0, -0.15 * smoothstep(0.0, 1.0, t / wind_up))
		Stage.STRIKE:
			var s := (t - wind_up) / strike
			return Vector3(1.0, 1.0 - pow(1.0 - s, 2.5), smoothstep(0.0, 1.0, s))
		Stage.HOLD:
			return Vector3(1.0, 1.0, 1.0)
		Stage.RECOVER:
			var s := smoothstep(0.0, 1.0, (t - wind_up - strike - hold) / recover)
			return Vector3(1.0 - s, 1.0 - s, 1.0 - s)
	return Vector3.ZERO


func _pose_mound(delta: float) -> void:
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var to_world := _skeleton.global_transform
	var reach_for := _aim_now()
	var middle := (_core.transform * (Vector3.UP * FleshMoundLook.MIDDLE)) / size
	var half := _core.basis.get_scale() * FleshMoundLook.RADII / size
	_skin_material.set_shader_parameter(&"core_at", Vector4(middle.x, middle.y, middle.z, 0.0))
	_skin_material.set_shader_parameter(&"core_size", Vector4(half.x, half.y, half.z, 1.0))
	var local_aim := to_skeleton * reach_for if reach_for.is_finite() else Vector3.INF
	var target := to_skeleton * _grab_at
	var weights := _grab_weights()
	var stage := grab_stage()
	# (limbs that only hang are posed every fourth frame, a quarter of them each time)
	var slow_turn := _frame % 4
	_hands.clear()
	var index := 0
	for copy in _build.copies:
		index += 1
		var d := copy.data
		var root := _root(copy)
		var out: Vector3 = (_core.basis.orthonormalized() * (d.out as Vector3)).normalized()
		var phase: float = d.phase
		var parents := {}
		if copy.body:
			var frame := copy.place.basis.orthonormalized()
			var globals := copy.body.pose(_skeleton, root, frame, sin(_time * 1.2 + phase) * 0.06 + _swell * 0.1, 0.3 + sin(_time * 0.5 + phase) * 0.15, sin(_time * 0.37 + phase) * 0.5)
			parents = {"arm": globals[2], "leg": globals[0]}
		for chain_name: String in copy.chains:
			var chain: FleshParts.Chain = copy.chains[chain_name]
			var role: int = d.roles[chain_name]
			var slow := role in [Role.LIMP, Role.TUCKED, Role.DANGLE]
			if slow and (index + chain_name.length()) % 4 != slow_turn and chain.data.has("posed"):
				continue
			chain.data.posed = true
			var parent: Transform3D = parents.get("arm" if chain.arm else "leg", Transform3D.IDENTITY)
			var chain_root := chain.root_from(parent) if copy.body else root
			var to_world_out := out
			_pose_chain(chain, role, chain_root, to_world_out, phase + chain.side, parent, local_aim, target, weights, stage, delta, to_skeleton, to_world, copy.part.begins_with("long"))


func _pose_chain(chain: FleshParts.Chain, role: int, root: Vector3, out: Vector3, phase: float, parent: Transform3D, local_aim: Vector3, target: Vector3, weights: Vector3, stage: Stage, delta: float, to_skeleton: Transform3D, to_world: Transform3D, long_arm: bool) -> void:
	var long := chain.upper_long + chain.lower_long
	var forward := Vector3.FORWARD
	match role:
		Role.GRAB:
			_pose_grabber(chain, root, out, long, phase, parent, local_aim, target, weights, stage, delta, to_skeleton, to_world, long_arm)
		Role.CRAWL:
			var flat := Vector3(out.x, 0.0, out.z).normalized()
			var ideal := root + flat * long * 0.72 + forward * long * 0.38
			ideal.y = 0.07
			var palm := Vector3.DOWN
			var along := (flat + forward * 0.5).normalized()
			var wall := _wall_for(root, flat, long)
			if wall.is_finite():
				ideal = Vector3(wall.x, clampf(root.y + 0.2, 0.6, 2.2), root.z + forward.z * long * 0.3)
				palm = Vector3(signf(flat.x), 0.0, 0.0)
				along = (Vector3.UP + forward * 0.6).normalized()
			var planted := _planted(chain, ideal, long, delta, to_skeleton, to_world)
			var at: Vector3 = planted[0]
			var lift: float = planted[1]
			var wrist := at - along * chain.end_long * 0.55 - palm * 0.04 * chain.size
			chain.reach_to(_skeleton, root, wrist, (Vector3.UP + out * 0.6).normalized(), along, palm.lerp(-out, lift * 0.6).normalized(), parent)
			chain.hand(_skeleton, 0.25 + lift * 0.5, 0.6 * (1.0 - lift), 0.35 * (1.0 - lift), _time, 0.35 if _speed.length() > 0.3 else 0.12)
		Role.REACH:
			var sway := Vector3(sin(_time * 0.45 + phase), 0.0, cos(_time * 0.37 + phase * 1.3)) * 0.35
			var spasm := _spasm(chain, delta, phase)
			var dir := (out + Vector3.UP * 0.5 + sway + spasm).normalized()
			var to := root + dir * long * 0.9
			if local_aim.is_finite():
				var toward := local_aim - root
				if toward.length() < long * 3.0:
					to = to.lerp(root + toward.limit_length(long * 0.97), _feel * 0.65)
			var grip := 0.45 + 0.4 * sin(_time * 0.9 + phase) + spasm.length() * 1.5
			chain.reach_to(_skeleton, root, to, (Vector3.UP.cross(dir) + out * 0.3).normalized(), dir, (Vector3.DOWN + dir.cross(Vector3.UP) * 0.5).normalized(), parent)
			chain.hand(_skeleton, clampf(grip, -0.1, 1.0), 0.2, 0.5 - grip * 0.3, _time, 0.3 + _feel * 0.4)
		Role.LIMP:
			var sway := Vector3(_jiggle.x, 0.0, _jiggle.z) * 0.5 + Vector3(sin(_time * 0.6 + phase), 0.0, 0.0) * 0.08
			var dir := (out * 0.35 + Vector3.DOWN + sway).normalized()
			var to := root + dir * long * 0.97
			to.y = maxf(to.y, 0.12)
			chain.reach_to(_skeleton, root, to, (out + Vector3.UP * 0.3).normalized(), (dir + out * 0.2).normalized(), -out, parent)
			chain.hand(_skeleton, 0.5, 0.25, 0.0)
		Role.KICK:
			var cycle := fposmod(_time * 0.5 + phase / TAU, 1.0)
			var bent := smoothstep(0.0, 0.7, cycle) * (1.0 - smoothstep(0.76, 0.84, cycle))
			var dir := (out + Vector3.UP * 0.3 + Vector3(sin(_time * 0.3 + phase), 0.0, 0.0) * 0.25).normalized()
			var to := root + dir * long * lerpf(0.97, 0.6, bent)
			var knee := (Vector3.UP - dir * dir.y + out.cross(Vector3.UP) * 0.3 * sin(phase)).normalized()
			chain.reach_to(_skeleton, root, to, knee, knee, dir, parent)
			chain.curl_toes(_skeleton, 0.5 * bent - 0.3 * (1.0 - bent))
		Role.DANGLE:
			var sway := Vector3(_jiggle.x, 0.0, _jiggle.z) * 0.4 + Vector3(sin(_time * 0.5 + phase), 0.0, cos(_time * 0.4 + phase)) * 0.06
			var dir := (out * 0.4 + Vector3.DOWN + sway).normalized()
			var to := root + dir * long * 0.93
			to.y = maxf(to.y, 0.1)
			var knee := (Vector3(out.x, 0.0, out.z).normalized() + Vector3.FORWARD * 0.3).normalized()
			chain.reach_to(_skeleton, root, to, knee, knee, (dir + knee * 0.3).normalized(), parent)
			chain.curl_toes(_skeleton, 0.3 + 0.3 * sin(_time * 1.3 + phase))
		Role.TUCKED:
			# Down into the flesh, out of sight.
			var to := root - out * long * 0.7 + Vector3.DOWN * long * 0.2
			chain.reach_to(_skeleton, root, to, out, -out, Vector3.DOWN, parent)


func _wall_for(root: Vector3, flat: Vector3, long: float) -> Vector3:
	var gap := _left if flat.x < 0.0 else _right
	if not is_finite(gap):
		return Vector3.INF
	var x := gap / size * signf(flat.x)
	if absf(x - root.x) > long * 0.95:
		return Vector3.INF
	return Vector3(x, 0.0, 0.0)


## A hand put down at a point that stays put in the world while the body goes on,
## lifted and put down again near `ideal` when it is left too far behind.
## Gives where it is now (skeleton space) and how far it is lifted (0..1).
func _planted(chain: FleshParts.Chain, ideal: Vector3, long: float, delta: float, to_skeleton: Transform3D, to_world: Transform3D) -> Array:
	var d := chain.data
	var ideal_w := to_world * ideal
	if not d.has("plant"):
		d.plant = ideal_w
		d.step = -1.0
	var plant_now: Vector3 = to_skeleton * (d.plant as Vector3)
	if d.step < 0.0 and plant_now.distance_to(ideal) > long * 0.5:
		d.from = d.plant
		# (put down ahead of where it is going, so that it is not left behind at once)
		d.to = ideal_w + _speed * 0.35
		d.step = 0.0
	if d.step >= 0.0:
		d.step += delta / 0.45
		var s := clampf(d.step, 0.0, 1.0)
		var at: Vector3 = (d.from as Vector3).lerp(d.to, smoothstep(0.0, 1.0, s))
		at += Vector3.UP * sin(s * PI) * long * 0.3 * size
		if d.step >= 1.0:
			d.plant = d.to
			d.step = -1.0
		return [to_skeleton * at, sin(s * PI)]
	return [plant_now, 0.0]


## Now and then an arm jerks: an offset, while it lasts.
func _spasm(chain: FleshParts.Chain, delta: float, phase: float) -> Vector3:
	var d := chain.data
	d.spasm_in = d.get("spasm_in", 2.0 + fposmod(phase * 7.0, 5.0)) - delta
	if d.spasm_in <= 0.0:
		d.spasm_in = 3.0 + fposmod(_time * 13.7 + phase, 6.0)
		d.spasm_left = 0.3
		d.spasm_way = Vector3(sin(_time * 31.0 + phase), cos(_time * 17.0), sin(_time * 23.0 - phase)) * 0.6
	var left: float = d.get("spasm_left", 0.0)
	if left <= 0.0:
		return Vector3.ZERO
	d.spasm_left = left - delta
	return (d.spasm_way as Vector3) * sin(left / 0.3 * PI)


func _pose_grabber(chain: FleshParts.Chain, root: Vector3, out: Vector3, long: float, phase: float, parent: Transform3D, local_aim: Vector3, target: Vector3, weights: Vector3, stage: Stage, delta: float, to_skeleton: Transform3D, to_world: Transform3D, long_arm: bool) -> void:
	var forward := Vector3.FORWARD
	var flat := Vector3(out.x, 0.0, out.z).normalized()
	# Groping along the floor ahead, like the crawlers.
	var ideal := root + (flat + forward).normalized() * long * 0.62
	ideal.y = 0.07
	var planted := _planted(chain, ideal, long, delta, to_skeleton, to_world)
	var at: Vector3 = planted[0]
	var lift: float = planted[1]
	var along := (Vector3(at.x - root.x, 0.0, at.z - root.z)).normalized()
	var palm := Vector3.DOWN
	var grip := 0.3 + lift * 0.4 + 0.15 * sin(_time * 1.3 + phase)
	var claw := 0.55 * (1.0 - lift)
	var spread := 0.3
	var jitter := 0.2
	# Feeling for something: lifted and pawing at it.
	if local_aim.is_finite() and _feel > 0.01:
		var toward := local_aim - root
		var paw := root + toward.limit_length(long * 0.92) + Vector3(sin(_time * 2.1 + phase), sin(_time * 1.7 + phase * 2.0) * 0.5 + 0.4, cos(_time * 1.9 + phase)) * 0.25 * chain.size
		var f := _feel * clampf(1.5 - toward.length() / (long * 3.0), 0.0, 1.0)
		at = at.lerp(paw, f)
		along = along.slerp(toward.normalized(), f) if along.length() > 0.5 else toward.normalized()
		palm = palm.lerp((Vector3.DOWN + toward.normalized()).normalized(), f).normalized()
		grip = lerpf(grip, 0.45 + 0.45 * sin(_time * 5.0 + phase * 3.0), f)
		claw = lerpf(claw, 0.4, f)
		spread = lerpf(spread, 0.6, f)
		jitter = lerpf(jitter, 0.6, f)
	# The grab: drawn up and back, splayed; thrown out round the point; clutching.
	if weights.x > 0.0:
		var to := target - root
		var spot := target + Vector3(cos(phase * 2.4), 0.0, sin(phase * 2.4)) * 0.35 * chain.size
		spot.y = clampf(spot.y + 0.6, 0.3, 1.6)
		var room_out := slide / size * (1.0 if long_arm else 0.3)
		var rise := root + (Vector3.UP * 0.8 + out * 0.3 - Vector3(to.x, 0.0, to.z).normalized() * 0.25).normalized() * long * 0.8
		rise += Vector3(sin(_time * 41.0 + phase), sin(_time * 37.0), cos(_time * 43.0 + phase)) * 0.05 * chain.size
		var slid := room_out * weights.z
		var root_out := root + out * slid
		var thrown := root_out + (spot - root_out).limit_length(long * 0.9)
		var pose_at := rise.lerp(thrown, weights.y) if stage != Stage.RECOVER else at.lerp(thrown, weights.x)
		at = at.lerp(pose_at, weights.x) if stage == Stage.WIND_UP else pose_at
		var reach_way := (spot - root_out).normalized()
		var up_way := (Vector3.UP + reach_way * 0.3).normalized()
		along = along.slerp(up_way.slerp(reach_way, weights.y), weights.x).normalized()
		palm = palm.slerp((reach_way + Vector3.DOWN * weights.y).normalized(), weights.x).normalized()
		match stage:
			Stage.WIND_UP:
				grip = lerpf(grip, -0.2, weights.x)
				spread = lerpf(spread, 1.0, weights.x)
				jitter = lerpf(jitter, 1.0, weights.x)
				claw = lerpf(claw, 0.3, weights.x)
			Stage.STRIKE:
				var closing := smoothstep(0.75, 1.0, weights.y)
				grip = lerpf(-0.2, 1.0, closing)
				spread = lerpf(1.0, 0.0, closing)
				claw = 0.3
				jitter = 0.4
			Stage.HOLD:
				grip = 1.0
				claw = 0.5
				jitter = 0.6
			Stage.RECOVER:
				grip = lerpf(grip, 0.6, weights.x)
		if chain.parents[0] < 0:
			root = root_out
	var wrist := at - along * chain.end_long * 0.5 - palm * 0.04 * chain.size
	var pole := (Vector3.UP * 0.7 + out * 0.6).normalized()
	chain.reach_to(_skeleton, root, wrist, pole, along, palm, parent)
	chain.hand(_skeleton, clampf(grip, -0.3, 1.2), claw, spread, _time, jitter)
	if weights.x > 0.0:
		_hands.append(to_world * (wrist + along * chain.end_long * 0.6))


# --- The trail ---

func _lay_trail(delta: float) -> void:
	var multi := _trail.multimesh
	var at := global_position
	if trailing and _flesh.visible:
		if not _trail_from.is_finite():
			_trail_from = at
		var gone := Vector2(at.x - _trail_from.x, at.z - _trail_from.z)
		if gone.length() > TRAIL_STEP * size:
			var i := _trail_next
			_trail_next = (_trail_next + 1) % TRAIL
			var r := FleshMoundLook.radii(bodies)
			var under := _core.global_position if not small() else global_position
			under.y = at.y
			_trail_at[i] = under - Vector3(gone.x, 0.0, gone.y).normalized() * r.z * 0.6 * size + Vector3.UP * 0.03
			_trail_way[i] = atan2(gone.x, gone.y)
			_trail_wide[i] = r.x * 1.3 * size * (_squeeze if not small() else 1.6)
			_trail_age[i] = 0.0
			_trail_from = at
	_trail_tick -= delta
	for i in TRAIL:
		if _trail_age[i] < INF:
			_trail_age[i] += delta
	if _trail_tick > 0.0:
		return
	_trail_tick = 0.2
	var shown := 0
	for i in TRAIL:
		var age := _trail_age[i]
		if age >= trail_life:
			continue
		var fade := 1.0 - age / trail_life
		fade = fade * fade * minf(age * 3.0 + 0.3, 1.0)
		var basis := Basis(Vector3.UP, _trail_way[i]).scaled(Vector3(_trail_wide[i], 1.0, TRAIL_STEP * size * 2.2))
		multi.set_instance_transform(shown, Transform3D(basis, _trail_at[i]))
		multi.set_instance_color(shown, Color(1, 1, 1, fade))
		shown += 1
	multi.visible_instance_count = shown


## Builds its people for one more body ahead of time (so that growing does not
## stop the game for a moment, the first time for that number).
func _prepare_next() -> void:
	if bodies < FleshMoundLook.MOST:
		FleshMoundLook.people(bodies + 1, low_poly or FleshParts.low_poly)
