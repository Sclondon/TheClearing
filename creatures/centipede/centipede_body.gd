class_name CentipedeBody
extends Node3D
## A giant centipede, to look at and to move: its armoured body, its legs
## rippling down both sides, its feelers and its poison claws, and how it
## rears, strikes and coils. It does no thinking: whatever drives it moves
## this node about and calls it to do things.
##
## WHERE IT IS. This node is where its head is, on the ground (its origin at
## floor level, forward its +Z). Move it however you like (as a child of a
## CharacterBody3D, or by setting its global transform each frame), and the
## body follows: every part of it passes where the head passed, round the same
## corners. Near a wall (anything on `wall_mask`) the body runs a little way up
## the foot of it, and further up it round a tight corner, as a centipede goes
## round a room's skirting; set `climb` to 0 to keep it flat.
##
## ITS LEGS walk by themselves from how far it has gone: a pair to each length
## of it, each leg stepping in turn down the body in waves, quicker the faster
## it goes. The last pair trail out behind. Lifted off the ground, they claw at
## the air.
##
## WHAT IT CAN BE TOLD:
## - `aim`: a point in the world it is interested in (INF for none). Its
##   feelers reach for it and its head turns to it.
## - `rear(amount)`: lifts the front of it (`rear_length` metres of it) up off
##   the ground, 0 (flat) to 1 (`rear_height` metres up), feelers raised. With
##   `look_about`, it sways its reared head from side to side, feeling the air.
## - `strike(at)`: rears back high with its claws spread (WIND_UP,
##   `wind_up` seconds: the warning), throws its head and front at `at`
##   (POUNCE, no further than `pounce_reach`), lies there with its claws
##   shut on where it was (HOLD), and draws back (RECOVER). `stage()` and
##   `strikes_in()` say where it is in that, and `bites(a, b, radius)` whether
##   the claws, as they go, have passed within `radius` of the line from `a`
##   to `b` (a target's feet to its head, say): ask it every frame of POUNCE.
## - `lay_straight()`, `lay_along(points)` and `lay_coil(radius, middle)` put
##   its body straight down somewhere (behind the head as it is now), without
##   walking it there: at the start, or when it is put somewhere new.
##   `curl(radius, middle, seconds)` curls it up where it lies, as it comes to
##   rest (hold it still meanwhile).
##
## LOOKS. Three draws whatever its length: the plates of its body (one
## MultiMesh), its head, and every leg, feeler and claw (one MultiMesh of a
## jointed bar). It is lit with cel shading and a hard chitin gloss
## (CentipedeParts). Further than `cull_distance` from the camera it is
## hidden and its legs are not worked out, though its body still follows.
##
## SOUND. With `voice`, the dry clatter of its legs (louder the faster it goes)
## and a chitter as it rears to strike, made here from noise.
##
## Example (see example.gd):
##     var centipede := CentipedeBody.new()
##     add_child(centipede)          # where its head is
##     centipede.lay_straight()
##     ...each frame: move it; centipede.aim = target.global_position
##     if close: centipede.strike(target.global_position)

## It has begun to throw itself at where it was told (the end of WIND_UP).
signal pounced(at: Vector3)

enum Stage { NONE, WIND_UP, POUNCE, HOLD, RECOVER }

## How long it is, head to the tips of its trailing legs (metres), and how
## many lengths (each with a pair of legs) its body is in.
@export_range(4.0, 60.0) var length := 18.0
@export_range(6, 48) var segments := 22
## How wide its body is, and how high it rides (the middle of its body over the ground).
@export var width := 1.3
@export var ride := 0.6
## How long a leg is (each of its two parts), and how far out its feet stand from the middle of its body.
@export var leg_length := 0.8
@export var foot_out := 1.55
## How far one wave of steps carries it (metres): a leg steps once in this.
@export var stride := 1.1
## How much of it rears, and how high.
@export var rear_length := 6.5
@export var rear_height := 3.2
## Seconds each part of a strike takes, and the furthest it throws its head.
@export var wind_up := 0.55
@export var pounce_time := 0.2
@export var hold_time := 0.4
@export var recover_time := 0.7
@export var pounce_reach := 6.0
## How far up a wall's foot it runs (0: never), and what counts as a wall.
@export_range(0.0, 1.0) var climb := 1.0
@export_flags_3d_physics var wall_mask := 1
## How high up a wall it goes round a tight corner (metres).
@export var corner_climb := 2.6
## Shell, the pale band at the back of each plate, the underside, the legs, and the tips of claws and feelers.
@export var shell := Color(0.075, 0.06, 0.05)
@export var edge := Color(0.38, 0.27, 0.16)
@export var under := Color(0.3, 0.23, 0.15)
@export var leg := Color(0.52, 0.43, 0.3)
@export var tip := Color(0.04, 0.03, 0.025)
@export var voice := true
## Further than this from the camera it is hidden (0: never).
@export var cull_distance := 110.0

## What it is interested in, in the world (INF: nothing).
var aim := Vector3.INF
## Sways its reared head about, feeling the air.
var look_about := false
## The middle of each length of its body, head first, in the world (after the last frame drawn).
var spine := PackedVector3Array()
## Its head, as drawn: where the middle of it is, and which way it points.
var head_at := Vector3.ZERO
var head_way := Vector3.BACK

var _rear := 0.0
var _rear_to := 0.0
var _strike_time := INF
var _strike_at := Vector3.ZERO
var _lunge := Vector3.ZERO
var _jaw_was := Vector3.INF
var _jaw_now := Vector3.INF
var _claws_open := 0.0
var _clock := 0.0
var _gait := 0.0
var _speed := 0.0
var _last := Vector3.INF
var _look_yaw := 0.0
var _hidden := false
# The path its head has taken, newest first: the ground under it, where the
# middle of the body is from there (raised, and up a wall), and which way is up.
var _trail_at := PackedVector3Array()
var _trail_lift := PackedVector3Array()
var _trail_up := PackedVector3Array()
var _turn_was := Vector3.ZERO
var _step := 0.25
var _spacing := 0.7
var _head_long := 1.1
var _plates: MultiMeshInstance3D
var _bars: MultiMeshInstance3D
var _head: MeshInstance3D
var _plate_buffer := PackedFloat32Array()
var _bar_buffer := PackedFloat32Array()
var _bar_count := 0
var _curl_from := PackedVector3Array()
var _curl_to := PackedVector3Array()
var _curl_time := 0.0
var _curl_for := 0.0
var _clatter: AudioStreamPlayer3D
var _chitter: AudioStreamPlayer3D

## Bars: two to each leg, then the feelers, the poison claws, and the trailing legs.
const FEELER_LINKS := 7
const FEELER := 2.6

static var _clatter_stream: AudioStreamWAV
static var _chitter_stream: AudioStreamWAV


func _ready() -> void:
	_spacing = (length - _head_long - leg_length * 1.6) / segments
	_step = clampf(_spacing * 0.35, 0.12, 0.4)
	spine.resize(segments + 1)
	_build()
	if _trail_at.is_empty():
		lay_straight()


# --- Telling it what to do ---

## Lifts the front of it, 0 (flat on the ground) to 1 (as high as it goes).
func rear(amount: float) -> void:
	_rear_to = clampf(amount, 0.0, 1.2)


## Rears back, claws spread, and throws itself at `at` (see the stages).
func strike(at: Vector3) -> void:
	if stage() != Stage.NONE:
		return
	_strike_at = at
	_strike_time = 0.0
	_jaw_was = Vector3.INF
	if _chitter:
		_chitter.play()


func stage() -> Stage:
	if _strike_time < wind_up:
		return Stage.WIND_UP
	if _strike_time < wind_up + pounce_time:
		return Stage.POUNCE
	if _strike_time < wind_up + pounce_time + hold_time:
		return Stage.HOLD
	if _strike_time < wind_up + pounce_time + hold_time + recover_time:
		return Stage.RECOVER
	return Stage.NONE


## Seconds until it pounces, while it winds up.
func strikes_in() -> float:
	return wind_up - _strike_time


## Moves where the strike will land (in WIND_UP: it follows its target round).
func retarget(at: Vector3) -> void:
	if stage() == Stage.WIND_UP:
		_strike_at = at


## Where its claws are now, in the world.
func jaws() -> Vector3:
	return head_at + head_way * _head_long * 0.62


## Whether its claws, from where they were a frame ago to where they are, have
## passed within `radius` of the line from `a` to `b`. Only while it pounces.
func bites(a: Vector3, b: Vector3, radius: float) -> bool:
	if stage() != Stage.POUNCE and stage() != Stage.HOLD or not _jaw_now.is_finite():
		return false
	var from := _jaw_was if _jaw_was.is_finite() else _jaw_now
	var nearest := Geometry3D.get_closest_points_between_segments(from, _jaw_now, a, b)
	return nearest[0].distance_to(nearest[1]) < radius


## How thick it is (half its width), for anything that wants to keep out of it.
func radius() -> float:
	return width * 0.5


# --- Putting it down ---

## Lays its body straight out behind its head, as far as the walls let it
## (then it turns aside along them).
func lay_straight() -> void:
	var back := -global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var points := PackedVector3Array([global_position])
	var at := global_position
	var left := length + 2.0
	while left > 0.0:
		var hit := _ray(at + Vector3.UP * ride, at + Vector3.UP * ride + back * 3.0)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(at + Vector3.UP * ride) < width + 0.6:
			var normal: Vector3 = hit["normal"]
			back = Vector3(-normal.z, 0.0, normal.x) * signf(Vector3(-normal.z, 0.0, normal.x).dot(back) + 0.001)
		at += back * 1.0
		points.append(at)
		left -= 1.0
	lay_along(points)


## Lays its body along `points` (head first, on the ground).
func lay_along(points: PackedVector3Array) -> void:
	_trail_at.clear()
	_trail_lift.clear()
	_trail_up.clear()
	var k := 1
	var at := points[0]
	var count := int((length + 2.0) / _step) + 8
	for i in count:
		_keep(at, true)
		if k < points.size():
			var to := points[k] - at
			while to.length() <= _step and k < points.size() - 1:
				k += 1
				to = points[k] - at
			at += to.normalized() * minf(_step, to.length())
		else:
			at += (points[points.size() - 1] - points[maxi(points.size() - 2, 0)]).normalized() * _step
	_trail_at.reverse()
	_trail_lift.reverse()
	_trail_up.reverse()
	_curl_for = 0.0
	_last = global_position
	_turn_was = Vector3.ZERO
	_strike_time = INF
	_lunge = Vector3.ZERO
	_draw(0.0)


## Lays it coiled where it is: its body wound round in a ring of `radius`
## metres behind its head (and inwards, if it is longer than the ring), as it
## rests in a corner. The middle of the ring is off to its left, or at
## `middle` if that is given (then the ring is as wide as the head is from it).
func lay_coil(radius_of_ring := 2.8, middle := Vector3.INF) -> void:
	lay_along(_coil_points(radius_of_ring, middle))


## Curls up where it lies, over `seconds`: its body wound in from where it is
## to the coil `lay_coil` would lay. For when it has come to rest somewhere.
## Hold it still meanwhile.
func curl(radius_of_ring := 2.8, middle := Vector3.INF, seconds := 1.6) -> void:
	var was := _trail_at.duplicate()
	var was_lift := _trail_lift.duplicate()
	var was_up := _trail_up.duplicate()
	lay_coil(radius_of_ring, middle)
	var count := mini(was.size(), _trail_at.size())
	_curl_from = was.slice(0, count)
	_curl_to = _trail_at.slice(0, count)
	_trail_at = _curl_from.duplicate()
	_trail_lift = was_lift.slice(0, count)
	_trail_up = was_up.slice(0, count)
	_curl_time = 0.0
	_curl_for = maxf(seconds, 0.01)


func _coil_points(radius_of_ring: float, middle: Vector3) -> PackedVector3Array:
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	var outer := radius_of_ring
	if not middle.is_finite():
		# (the head goes round the ring to its left: the middle of the ring is off to that side)
		middle = global_position + Vector3(forward.z, 0.0, -forward.x) * radius_of_ring
	else:
		middle.y = global_position.y
		outer = clampf(middle.distance_to(global_position), width, radius_of_ring * 1.3)
	var start := atan2(global_position.x - middle.x, global_position.z - middle.z)
	# (round to the left or the right, whichever way it faces round the ring)
	var round_way := 1.0 if Vector3(sin(start + 0.1), 0.0, cos(start + 0.1)).dot(forward) > Vector3(sin(start - 0.1), 0.0, cos(start - 0.1)).dot(forward) else -1.0
	var points := PackedVector3Array()
	var gone := 0.0
	var turn := 0.0
	while gone < length + 2.0:
		var r := maxf(outer - turn / TAU * width * 1.15, width * 0.7)
		var angle := start - turn * round_way
		points.append(middle + Vector3(sin(angle), 0.0, cos(angle)) * r)
		turn += 0.3 / r
		gone += 0.3
	return points


# --- Each frame ---

func _process(delta: float) -> void:
	_clock += delta
	var here := global_position
	var moved := 0.0
	if _last.is_finite():
		moved = Vector2(here.x - _last.x, here.z - _last.z).length()
		_speed = lerpf(_speed, moved / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))
	_last = here
	if moved > 3.0:
		lay_straight()
		return
	_gait += moved / stride
	if moved < 0.002 * delta * 60.0:
		# (standing, its legs still shift a little)
		_gait += delta * 0.12
	if _curl_time < _curl_for:
		# Curling up: each place along it drawn round into the coil.
		_curl_time += delta
		var by := smoothstep(0.0, 1.0, _curl_time / _curl_for)
		for k in _curl_to.size():
			_trail_at[k] = _curl_from[k].lerp(_curl_to[k], by)
		_gait += delta * 1.5
	elif _trail_at.is_empty() or here.distance_to(_trail_at[0]) >= _step:
		_keep(here, false)
	_strike_time += delta
	_strike(delta)
	_rear = lerpf(_rear, _rear_to if stage() == Stage.NONE else _rear, 1.0 - exp(-4.0 * delta))
	var hidden := cull_distance > 0.0 and _camera_far()
	if hidden != _hidden:
		_hidden = hidden
		for part: Node3D in [_plates, _bars, _head]:
			part.visible = not hidden
	if not hidden:
		_draw(delta)
	_sound()


func _camera_far() -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera != null and camera.global_position.distance_to(global_position) > cull_distance + length


# How the strike goes: rearing, the throw, lying there, drawing back.
func _strike(delta: float) -> void:
	var now := stage()
	if now == Stage.NONE:
		_lunge = _lunge.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta))
		_claws_open = lerpf(_claws_open, 0.25 if aim.is_finite() else 0.05, 1.0 - exp(-5.0 * delta))
		return
	match now:
		Stage.WIND_UP:
			_rear = lerpf(_rear, 1.1, 1.0 - exp(-9.0 * delta))
			_claws_open = lerpf(_claws_open, 1.0, 1.0 - exp(-12.0 * delta))
			_lunge = _lunge.lerp(-_forward() * 0.6, 1.0 - exp(-6.0 * delta))
		Stage.POUNCE:
			if _strike_time - delta < wind_up:
				pounced.emit(_strike_at)
			var by := (_strike_time - wind_up) / pounce_time
			_rear = lerpf(1.1, 0.0, by)
			_lunge = _throw() * by
			_claws_open = 1.0 - smoothstep(0.6, 1.0, by)
		Stage.HOLD:
			_rear = 0.0
			_lunge = _throw()
			_claws_open = 0.0
		Stage.RECOVER:
			var by := (_strike_time - wind_up - pounce_time - hold_time) / recover_time
			_rear = lerpf(0.0, _rear_to, by)
			_lunge = _throw() * (1.0 - smoothstep(0.0, 1.0, by))


# How far its head is thrown, from where it lies flat to where it was told (no further than it reaches).
func _throw() -> Vector3:
	var flat_head := global_position + Vector3.UP * ride + _forward() * _head_long * 0.5
	var to := _strike_at + Vector3.UP * 0.3 - flat_head
	if to.length() > pounce_reach:
		to = to.normalized() * pounce_reach
	return to


func _forward() -> Vector3:
	var f := global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.BACK


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, wall_mask)
	query.collide_with_areas = false
	var parent := get_parent()
	if parent is CollisionObject3D:
		query.exclude = [(parent as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


# Keeps a place on its trail (newest first, or, laying it out, oldest first),
# working out how it lies there: raised off the ground by its legs, and, near
# a wall, up the foot of it (higher round a corner).
func _keep(at: Vector3, laying: bool) -> void:
	var lift := Vector3.UP * ride
	var up := Vector3.UP
	if climb > 0.0 and is_inside_tree():
		var newest := at if laying or _trail_at.is_empty() else _trail_at[0]
		var going := (at - newest)
		going.y = 0.0
		var turn := 0.0
		if going.length() > 0.01:
			going = going.normalized()
			if _turn_was != Vector3.ZERO:
				turn = clampf(_turn_was.signed_angle_to(going, Vector3.UP) / maxf(_step, 0.01) * 0.5, -1.0, 1.0)
			_turn_was = going
		var ahead := going if going != Vector3.ZERO else _forward()
		var side := Vector3(ahead.z, 0.0, -ahead.x)
		var low := at + Vector3.UP * ride
		var best := INF
		var normal := Vector3.ZERO
		for way: float in [1.0, -1.0]:
			var hit := _ray(low, low + side * way * (width * 0.5 + 2.2))
			if not hit.is_empty():
				var d := low.distance_to(hit["position"])
				var n: Vector3 = hit["normal"]
				if d < best and absf(n.y) < 0.5:
					best = d
					normal = Vector3(n.x, 0.0, n.z).normalized()
		if normal != Vector3.ZERO:
			# Near enough the wall: up the foot of it a little; round a corner (turning, or
			# with a wall coming up ahead), further.
			var hug := 1.0 - smoothstep(width * 0.5 + 0.3, width * 0.5 + 2.2, best)
			var cornering := clampf(absf(turn) * 2.0, 0.0, 1.0)
			var front := _ray(low, low + ahead * 4.0)
			if not front.is_empty() and absf((front["normal"] as Vector3).y) < 0.5:
				cornering = maxf(cornering, 1.0 - low.distance_to(front["position"]) / 4.0)
			var tilt := clampf(hug * (0.45 + cornering * 0.6), 0.0, 0.95) * climb
			var height := (0.35 + corner_climb * cornering) * hug * climb
			up = _turned(Vector3.UP, normal, tilt * 0.92).normalized()
			# (on the wall, the middle of it stands off the face by its ride, not off the ground)
			var toward := -normal * maxf(best - ride, 0.0) * tilt
			lift = toward + Vector3.UP * (ride + height * tilt)
		# (eased in from the last place kept, so that it rises and falls smoothly)
		if not laying and not _trail_lift.is_empty():
			lift = _trail_lift[0].lerp(lift, 0.3)
			up = _turned(_trail_up[0], up, 0.3).normalized()
	if laying:
		_trail_at.append(at)
		_trail_lift.append(lift)
		_trail_up.append(up)
		return
	_trail_at.insert(0, at)
	_trail_lift.insert(0, lift)
	_trail_up.insert(0, up)
	var most := int((length + 3.0) / _step) + 8
	if _trail_at.size() > most:
		_trail_at.resize(most)
		_trail_lift.resize(most)
		_trail_up.resize(most)


# --- Drawing it ---

func _draw(delta: float) -> void:
	if _trail_at.is_empty():
		return
	var ease := 1.0 - exp(-12.0 * delta) if delta > 0.0 else 1.0
	var count := segments + 1
	var centres := PackedVector3Array()
	var ups := PackedVector3Array()
	centres.resize(count)
	ups.resize(count)
	# Along the trail: the head's middle at half a head's length back, then each
	# length of it. Thrown forward in a strike, the whole of it slides on along its
	# path, and that path runs on from the head straight to where it is thrown.
	var forward := _forward()
	var flat_lunge := Vector3(_lunge.x, 0.0, _lunge.z)
	var thrown := flat_lunge.length()
	# (drawn back as it winds up, it slides back along its own path instead)
	var back := thrown if thrown > 0.01 and flat_lunge.dot(forward) < 0.0 else 0.0
	var leads := thrown > 0.01 and back == 0.0
	var a := global_position + flat_lunge if leads else global_position
	var a_lift := _trail_lift[0]
	var a_up := _trail_up[0]
	var j := -1 if leads else 0
	var b := global_position if j < 0 else _trail_at[0]
	var part := a.distance_to(b)
	var walked := 0.0
	var trail := _trail_at.size()
	var gaps := PackedFloat32Array()
	gaps.resize(count)
	for i in count:
		var along := _head_long * 0.5 + (i - 0.5) * _spacing if i > 0 else _head_long * 0.3
		gaps[i] = along - (_head_long * 0.5 + (i - 1.5) * _spacing if i > 1 else _head_long * 0.3) if i > 0 else 0.0
		along += back
		while along > walked + part and j < trail - 1:
			walked += part
			a = b
			if j >= 0:
				a_lift = _trail_lift[j]
				a_up = _trail_up[j]
			j += 1
			b = _trail_at[j]
			part = a.distance_to(b)
		var share := clampf((along - walked) / maxf(part, 0.0001), 0.0, 1.0)
		var k := maxi(j, 0)
		centres[i] = a.lerp(b, share) + a_lift.lerp(_trail_lift[k], share)
		ups[i] = a_up.lerp(_trail_up[k], share).normalized()
	# Reared: the front of it curves up off the ground (and, thrown, comes down at
	# the height it was thrown at). Then each length is drawn back to its proper
	# distance from the one behind it, from the back forwards: it bends, it does
	# not stretch, so the higher it rears the further back its head comes.
	var across := Vector3(forward.z, 0.0, -forward.x)
	var raised := PackedFloat32Array()
	raised.resize(count)
	if _rear > 0.01 or thrown > 0.01:
		_look_yaw = lerpf(_look_yaw, sin(_clock * 1.3) * 0.9 + sin(_clock * 3.1) * 0.15 if look_about and stage() == Stage.NONE else 0.0, 1.0 - exp(-3.0 * delta) if delta > 0.0 else 1.0)
		var last := 0
		for i in count:
			var along := i * _spacing
			if along >= rear_length:
				break
			last = i
			var share := 1.0 - along / rear_length
			var eased := share * share * (3.0 - 2.0 * share)
			var sway := across * sin(_look_yaw) * 1.4 * eased * eased * clampf(_rear, 0.0, 1.0)
			var lift := Vector3.UP * (_rear * rear_height * eased + _lunge.y * eased * eased) + sway
			centres[i] += lift
			raised[i] = maxf(lift.y, 0.0)
		for i in range(last, -1, -1):
			if i + 1 >= count:
				continue
			var from := centres[i + 1]
			var out := centres[i] - from
			if out.length() > 0.001:
				centres[i] = from + out.normalized() * gaps[i + 1]
	spine = centres
	# The plates.
	var low := centres[0]
	var high := centres[0]
	for i in range(1, count):
		var run := centres[i - 1] - centres[mini(i + 1, count - 1)] if i < count - 1 else centres[i - 1] - centres[i]
		run = run.normalized() if run.length() > 0.001 else forward
		var up := ups[i]
		up = (up - run * up.dot(run)).normalized() if absf(up.dot(run)) < 0.98 else Vector3.UP
		var side := up.cross(run).normalized()
		# (the hindmost few lengths are smaller, and the head-end ones a little)
		var size := lerpf(1.0, 0.62, smoothstep(0.75, 1.0, float(i) / count)) * lerpf(0.86, 1.0, smoothstep(0.0, 0.12, float(i) / count))
		var basis := Basis(side * width * size, up * width * 0.85 * size, run * _spacing)
		_put(_plate_buffer, i - 1, 12, Transform3D(basis, centres[i]))
		low = low.min(centres[i])
		high = high.max(centres[i])
	# The head.
	var neck := centres[0] - centres[1]
	var way := neck.normalized() if neck.length() > 0.01 else forward
	if aim.is_finite() and stage() == Stage.NONE:
		var to := (aim - centres[0]).normalized()
		way = _turned(way, to, 0.45).normalized() if way.dot(to) > -0.2 else way
	if _look_yaw != 0.0:
		way = way.rotated(Vector3.UP, _look_yaw * 0.5 * clampf(_rear, 0.0, 1.0))
	if stage() == Stage.POUNCE or stage() == Stage.HOLD:
		way = _turned(way, _lunge.normalized(), 0.5).normalized() if _lunge.length() > 0.1 else way
	head_way = _turned(head_way, way, ease).normalized() if delta > 0.0 else way
	var head_up := (ups[0] - head_way * ups[0].dot(head_way))
	head_up = head_up.normalized() if head_up.length() > 0.05 else Vector3.UP
	var head_side := head_up.cross(head_way).normalized()
	head_up = head_way.cross(head_side)
	head_at = centres[0]
	_head.global_transform = Transform3D(Basis(head_side * width * 1.1, head_up * width * 1.05, head_way * _head_long), head_at)
	_jaw_was = _jaw_now
	_jaw_now = jaws()
	_legs(centres, ups, raised, forward)
	var box := AABB(low, high - low).grow(foot_out + rear_height + FEELER)
	_plates.multimesh.buffer = _plate_buffer
	_bars.multimesh.buffer = _bar_buffer
	_plates.custom_aabb = box
	_bars.custom_aabb = box


# Every leg, the feelers, the claws, and the trailing legs, as bars.
func _legs(centres: PackedVector3Array, ups: PackedVector3Array, raised: PackedFloat32Array, forward: Vector3) -> void:
	var n := 0
	var count := centres.size()
	var lift_each := 0.32
	var stance := 0.55
	var reach := stride * stance * 0.5
	for i in range(1, count):
		var run := (centres[i - 1] - centres[mini(i + 1, count - 1)])
		run = run.normalized() if run.length() > 0.001 else forward
		var up := ups[i]
		up = (up - run * up.dot(run)).normalized() if absf(up.dot(run)) < 0.98 else Vector3.UP
		var side := up.cross(run).normalized()
		var size := lerpf(1.0, 0.7, smoothstep(0.75, 1.0, float(i) / count))
		# How far this length is off the ground (reared): its legs claw at the air.
		var airborne := clampf((raised[i] - 0.15) / 0.6, 0.0, 1.0)
		for s: float in [1.0, -1.0]:
			var hip := centres[i] + side * s * width * 0.36 * size - up * width * 0.08
			var cycle := fposmod(_gait - i * 0.11 + (0.5 if s < 0.0 else 0.0), 1.0)
			var fore := 0.0
			var lifted := 0.0
			if cycle < stance:
				fore = lerpf(reach, -reach, cycle / stance)
			else:
				var t := (cycle - stance) / (1.0 - stance)
				fore = lerpf(-reach, reach, t * t * (3.0 - 2.0 * t))
				lifted = sin(PI * t) * lift_each * clampf(_speed * 0.5 + 0.2, 0.0, 1.0)
			# (the legs angle back a little, more towards the tail)
			var rake := -0.25 - 0.25 * float(i) / count
			var foot := centres[i] + side * s * foot_out * size - up * (ride - lifted) + run * (fore + rake)
			var knee := (hip + foot) * 0.5 + up * leg_length * 0.42 * size + side * s * 0.12
			if airborne > 0.0:
				# Off the ground, its legs are drawn in and claw at the air.
				var flail := sin(_clock * 11.0 + i * 1.3 + s * 1.7) * 0.3
				var folded_knee := hip + side * s * leg_length * 0.8 * size + up * 0.12 + run * (flail * 0.4 - 0.1)
				var folded_foot := folded_knee - up * leg_length * 0.6 * size + run * (flail - 0.25) - side * s * 0.12
				knee = knee.lerp(folded_knee, airborne)
				foot = foot.lerp(folded_foot, airborne)
			var thick := 0.11 * size
			_bar(n, hip, knee, thick, run, Color(0.12, 0.0, 0.0))
			_bar(n + 1, knee, foot, thick * 0.75, run, Color(0.0, 0.9, 0.0))
			n += 2
	# The trailing legs: long, out behind, a little apart.
	var tail := centres[count - 1]
	var tail_run := (centres[count - 2] - tail).normalized() if (centres[count - 2] - tail).length() > 0.001 else forward
	var tail_up := ups[count - 1]
	var tail_side := tail_up.cross(tail_run).normalized()
	for s: float in [1.0, -1.0]:
		var wag := sin(_clock * 2.0 + s) * 0.12
		var root := tail + tail_side * s * width * 0.25 - tail_run * _spacing * 0.3
		var mid := root - tail_run * leg_length * 1.0 + tail_side * s * (0.45 + wag) + tail_up * 0.15
		var end := mid - tail_run * leg_length * 1.1 + tail_side * s * (0.3 + wag) - tail_up * 0.25
		_bar(n, root, mid, 0.1, tail_up, Color(0.3, 0.0, 0.0))
		_bar(n + 1, mid, end, 0.07, tail_up, Color(0.2, 0.8, 0.0))
		n += 2
	# The feelers: from the front of its head, up and out, waving; reaching for what it is after.
	var front := head_at + head_way * _head_long * 0.42
	var head_side := Vector3.UP.cross(head_way).normalized() if absf(head_way.y) < 0.98 else Vector3.RIGHT
	var head_up := head_way.cross(head_side).normalized()
	for s: float in [1.0, -1.0]:
		var at := front + head_side * s * width * 0.22 + head_up * 0.08
		var dir := (head_way + head_side * s * 0.55 + head_up * (0.25 + _rear * 0.4)).normalized()
		var target := Vector3.INF
		if aim.is_finite():
			target = aim + Vector3.UP * 1.0 + head_side * s * 0.5
		var link := FEELER / FEELER_LINKS
		for k in FEELER_LINKS:
			var wave := sin(_clock * (3.3 + s * 0.4) - k * 0.7) * 0.22 + sin(_clock * 7.1 + k + s) * 0.06
			dir = (dir + head_side * s * wave * 0.25 + head_up * wave * 0.2 - head_up * 0.03).normalized()
			if target.is_finite():
				dir = _turned(dir, (target - at).normalized(), 0.18).normalized()
			var next := at + dir * link
			_bar(n, at, next, lerpf(0.035, 0.012, float(k) / FEELER_LINKS), head_up, Color(0.35, 0.0, lerpf(0.0, 0.9, float(k) / FEELER_LINKS)))
			n += 1
			at = next
	# The poison claws: from under its head, curving in to meet in front of it; spread wide to strike.
	var under_head := head_at - head_up * width * 0.12 + head_way * _head_long * 0.2
	for s: float in [1.0, -1.0]:
		# (three parts: a thick base, the curve, and a black hooked point, turned in to meet the other)
		var root := under_head + head_side * s * width * 0.28
		var spread := lerpf(0.1, 1.0, _claws_open)
		var mid := root + head_way * 0.55 + head_side * s * (0.12 + 0.45 * spread) - head_up * 0.1
		var bend := mid + head_way * (0.38 - 0.08 * spread) - head_side * s * lerpf(0.3, 0.02, spread) + head_up * 0.02
		var point := bend + head_way * lerpf(0.05, 0.22, spread) - head_side * s * lerpf(0.3, 0.16, spread) + head_up * 0.04
		_bar(n, root, mid, 0.14, head_up, Color(0.8, 0.0, 0.0))
		_bar(n + 1, mid, bend, 0.1, head_up, Color(0.75, 0.6, 0.0))
		_bar(n + 2, bend, point, 0.055, head_up, Color(0.5, 0.0, 1.0))
		n += 3
	# Its eyes: a little black glossy cluster each side behind the feelers.
	for s: float in [1.0, -1.0]:
		var eye := head_at + head_way * _head_long * 0.18 + head_side * s * width * 0.36 + head_up * width * 0.12
		_bar(n, eye - head_side * s * 0.05, eye + head_side * s * 0.07 + head_up * 0.02, 0.075, head_way, Color(0.0, 0.0, 1.0))
		n += 1


func _bar(n: int, from: Vector3, to: Vector3, thick: float, side: Vector3, tint: Color) -> void:
	_put(_bar_buffer, n, 16, CentipedeParts.between(from, to, thick, side))
	var o := n * 16 + 12
	_bar_buffer[o] = tint.r
	_bar_buffer[o + 1] = tint.g
	_bar_buffer[o + 2] = tint.b
	_bar_buffer[o + 3] = 1.0


## `a` turned towards `b` by `weight` (both of a length of one); safe when they are nearly the same way or opposite.
static func _turned(a: Vector3, b: Vector3, weight: float) -> Vector3:
	var d := a.dot(b)
	if d > 0.9995 or d < -0.9995:
		var mixed := a.lerp(b, weight)
		return mixed.normalized() if mixed.length_squared() > 0.000001 else a
	return a.slerp(b, weight)


static func _put(buffer: PackedFloat32Array, n: int, stride_of: int, t: Transform3D) -> void:
	var o := n * stride_of
	buffer[o] = t.basis.x.x
	buffer[o + 1] = t.basis.y.x
	buffer[o + 2] = t.basis.z.x
	buffer[o + 3] = t.origin.x
	buffer[o + 4] = t.basis.x.y
	buffer[o + 5] = t.basis.y.y
	buffer[o + 6] = t.basis.z.y
	buffer[o + 7] = t.origin.y
	buffer[o + 8] = t.basis.x.z
	buffer[o + 9] = t.basis.y.z
	buffer[o + 10] = t.basis.z.z
	buffer[o + 11] = t.origin.z


# --- What it is made of ---

func _build() -> void:
	var colours := {"shell": shell, "edge": edge, "under": under, "leg": leg, "tip": tip}
	var plates := MultiMesh.new()
	plates.transform_format = MultiMesh.TRANSFORM_3D
	plates.mesh = CentipedeParts.plate()
	plates.instance_count = segments
	_plate_buffer.resize(segments * 12)
	_plates = MultiMeshInstance3D.new()
	_plates.name = "Plates"
	_plates.multimesh = plates
	_plates.material_override = CentipedeParts.material(colours, true)
	_plates.top_level = true
	add_child(_plates)
	_plates.global_transform = Transform3D.IDENTITY
	_head = MeshInstance3D.new()
	_head.name = "Head"
	_head.mesh = CentipedeParts.head()
	_head.material_override = _plates.material_override
	_head.top_level = true
	add_child(_head)
	_bar_count = segments * 4 + 4 + FEELER_LINKS * 2 + 8
	var bars := MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_3D
	bars.use_colors = true
	bars.mesh = CentipedeParts.bar()
	bars.instance_count = _bar_count
	_bar_buffer.resize(_bar_count * 16)
	_bars = MultiMeshInstance3D.new()
	_bars.name = "Legs"
	_bars.multimesh = bars
	_bars.material_override = CentipedeParts.material(colours, false)
	_bars.top_level = true
	add_child(_bars)
	_bars.global_transform = Transform3D.IDENTITY
	if voice:
		_sounds()
		_clatter = AudioStreamPlayer3D.new()
		_clatter.stream = _clatter_stream
		_clatter.unit_size = 6.0
		_clatter.volume_db = -60.0
		add_child(_clatter)
		_chitter = AudioStreamPlayer3D.new()
		_chitter.stream = _chitter_stream
		_chitter.unit_size = 8.0
		_chitter.volume_db = -4.0
		add_child(_chitter)


## How many triangles it is, and how many things are drawn for it.
func cost() -> Dictionary:
	var plate_tris := CentipedeParts.plate().surface_get_array_len(0) / 3
	var head_tris := CentipedeParts.head().surface_get_array_len(0) / 3
	var bar_tris := CentipedeParts.bar().surface_get_array_len(0) / 3
	return {"triangles": plate_tris * segments + head_tris + bar_tris * _bar_count, "draws": 3}


# --- Its sound ---

func _sound() -> void:
	if _clatter == null:
		return
	var loud := clampf(_speed / 5.0, 0.0, 1.0) if not _hidden else 0.0
	if loud < 0.02:
		if _clatter.playing:
			_clatter.stop()
		return
	if not _clatter.playing:
		_clatter.play()
	_clatter.volume_db = linear_to_db(loud * 0.9)
	_clatter.pitch_scale = 0.75 + 0.4 * loud


static func _sounds() -> void:
	if _clatter_stream:
		return
	var rate := 22050
	var chance := RandomNumberGenerator.new()
	chance.seed = 71
	# The clatter: dry ticks of many feet, thick and uneven.
	var samples := PackedFloat32Array()
	samples.resize(rate)
	var ticks := 140
	for t in ticks:
		var at := chance.randi_range(0, samples.size() - 400)
		var loud := chance.randf_range(0.2, 0.7)
		var tone := chance.randf_range(0.25, 0.6)
		var last := 0.0
		for k in 360:
			var noise := chance.randf_range(-1.0, 1.0)
			last = lerpf(last, noise, tone)
			samples[at + k] += last * loud * exp(-k / 40.0)
	_clatter_stream = _wave(samples, rate, true)
	# The chitter: a rattle that rises, quick ticks closer and closer together.
	samples = PackedFloat32Array()
	samples.resize(int(rate * 0.6))
	var at := 0
	var gap := 900.0
	while at < samples.size() - 300:
		var last := 0.0
		for k in 300:
			var noise := chance.randf_range(-1.0, 1.0)
			last = lerpf(last, noise, 0.5)
			samples[at + k] += last * 0.7 * exp(-k / 50.0)
		at += int(gap)
		gap = maxf(gap * 0.9, 180.0)
	_chitter_stream = _wave(samples, rate, false)


static func _wave(samples: PackedFloat32Array, rate: int, loops: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for n in samples.size():
		data.encode_s16(n * 2, int(clampf(samples[n], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	stream.data = data
	return stream
