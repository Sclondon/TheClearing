class_name GiantSpiderLegs
extends RefCounted
## A GiantSpider's eight legs, walking by themselves.
##
## Each foot is planted somewhere in the world and stays there until the place
## it would rather be (its rest place round the body, carried ahead of where
## the body is going) has got too far from it. They step four at a time, as a
## spider does: the first and third legs of one side with the second and
## fourth of the other (two "tetrapods"), each four going only when the other
## four are down; a foot left far too far behind steps anyway.
##
## Where a foot goes is found by casting rays against the world (`mask`): from
## the leg's root out towards its rest place, and failing that, down onto the
## surface from above it. "Down" is the body's own down, so the same legs walk
## on a floor, up a wall, or across a ceiling.
##
## A leg can be let go (`free`): its foot then follows a point the body gives
## it (a front leg raised to threaten, the legs held out as it hangs on its
## thread), and when it is planted again it steps down to the surface.
##
## Each leg is a short hip (coxa) out of the body, then the femur rising to a
## knee held high, the tibia coming down, and the metatarsus standing on the
## foot: two-bone IK for femur and tibia, with the metatarsus kept steep over
## the foot.

const COUNT := 8
## Where each leg leaves the body (body space at size 1, forward -Z), left
## side, front to back; the right side is the mirror.
const HIPS: Array[Vector3] = [Vector3(-0.3, -0.03, -0.36), Vector3(-0.41, -0.03, -0.13), Vector3(-0.43, -0.03, 0.1), Vector3(-0.35, -0.03, 0.3)]
## The hip's length, out from the body.
const COXA := 0.2
## Each pair's femur, tibia and metatarsus (at size 1). The fourth pair is the longest.
const BONES: Array[Vector3] = [Vector3(0.95, 0.85, 0.8), Vector3(0.9, 0.8, 0.72), Vector3(0.85, 0.78, 0.7), Vector3(1.0, 0.9, 0.85)]
## Where each pair's foot rests (ground space under the body's middle, forward
## -Z): the angle round from straight ahead (degrees), and how far out.
const REST: Array[Vector2] = [Vector2(30.0, 2.2), Vector2(68.0, 2.15), Vector2(112.0, 2.1), Vector2(150.0, 2.3)]

## How big the spider is (1: about four metres across its legs).
var size := 1.0
## What the feet stand on, and what the rays pass through.
var mask := 1
var exclude: Array[RID] = []

## Each foot in the world, and the way the surface under it faces.
var feet := PackedVector3Array()
var normals := PackedVector3Array()
## Each leg's joints in the world, from the last `pose`: where it leaves the
## body, the end of the hip, the knee and the ankle.
var hips := PackedVector3Array()
var roots := PackedVector3Array()
var knees := PackedVector3Array()
var ankles := PackedVector3Array()
var stepping: Array[bool] = []
## Let go: following a point, not planted.
var free: Array[bool] = []
## Steps taken (for sounds, and tests).
var steps := 0

var _t := PackedFloat32Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _from_normal := PackedVector3Array()
var _to_normal := PackedVector3Array()


func _init() -> void:
	# (packed arrays are values: each is sized by name)
	feet.resize(COUNT)
	hips.resize(COUNT)
	roots.resize(COUNT)
	knees.resize(COUNT)
	ankles.resize(COUNT)
	_from.resize(COUNT)
	_to.resize(COUNT)
	for i in COUNT:
		normals.append(Vector3.UP)
		_from_normal.append(Vector3.UP)
		_to_normal.append(Vector3.UP)
		stepping.append(false)
		free.append(false)
		_t.append(0.0)


## -1 for the left legs (0..3), 1 for the right (4..7).
static func side(i: int) -> float:
	return -1.0 if i < 4 else 1.0


## Leg i's root in body space, at size 1.
static func hip_local(i: int) -> Vector3:
	var h := HIPS[i % 4]
	return h if i < 4 else Vector3(-h.x, h.y, h.z)


## Leg i's rest place in ground space, at size 1.
static func rest_local(i: int) -> Vector3:
	var r := REST[i % 4]
	var angle := deg_to_rad(r.x)
	return Vector3(sin(angle) * r.y * side(i), 0.0, -cos(angle) * r.y)


## Which four leg i steps with (0 or 1).
static func group(i: int) -> int:
	return (i % 4 + (0 if i < 4 else 1)) % 2


func bones(i: int) -> Vector3:
	return BONES[i % 4] * size


## Puts every foot straight down where it rests.
func settle(space: PhysicsDirectSpaceState3D, body: Transform3D, ground: Transform3D) -> void:
	for i in COUNT:
		_roots(i, body)
		var hit := _place(space, i, ground * (rest_local(i) * size), ground.basis.y)
		feet[i] = hit[0]
		normals[i] = hit[1]
		stepping[i] = false
		free[i] = false


## Moves the feet on. `body` is the body now, `ground` the surface under it
## (its up the surface's), `velocity` how it is moving, and `held` a point for
## each leg that is let go (INF for a leg that walks).
func update(delta: float, space: PhysicsDirectSpaceState3D, body: Transform3D, ground: Transform3D, velocity: Vector3, held: PackedVector3Array) -> void:
	var speed := velocity.length()
	# Quicker, longer steps the faster it goes.
	var step_time := clampf(0.24 - speed * 0.024, 0.075, 0.24)
	var stride := (0.36 + speed * 0.1) * size
	var up := ground.basis.y
	var wants := PackedVector3Array()
	var wants_normal := PackedVector3Array()
	var errors := PackedFloat32Array()
	wants.resize(COUNT)
	wants_normal.resize(COUNT)
	errors.resize(COUNT)
	for i in COUNT:
		_roots(i, body)
		if held[i].is_finite():
			if not free[i]:
				free[i] = true
				stepping[i] = false
			feet[i] = feet[i].lerp(held[i], 1.0 - exp(-14.0 * delta))
			normals[i] = up
			continue
		var aim := ground * (rest_local(i) * size) + velocity * step_time * 1.5
		var hit := _place(space, i, aim, up)
		wants[i] = hit[0]
		wants_normal[i] = hit[1]
		errors[i] = feet[i].distance_to(hit[0])
		var b := bones(i)
		if feet[i].distance_to(roots[i]) > (b.x + b.y + b.z) * 0.98:
			errors[i] += 10.0
		if free[i]:
			# Let go until now: down onto the surface at once.
			free[i] = false
			_begin(i, wants[i], wants_normal[i])
			errors[i] = 0.0

	# Steps under way go on (and keep after where they are going).
	var up_count := [0, 0]
	for i in COUNT:
		if free[i] or not stepping[i]:
			continue
		_to[i] = _to[i].lerp(wants[i], 1.0 - exp(-(10.0 + 30.0 * _t[i]) * delta))
		_to_normal[i] = wants_normal[i]
		_t[i] = minf(_t[i] + delta / step_time, 1.0)
		var t := _t[i]
		var eased := t * t * (3.0 - 2.0 * t)
		var lift := (_from_normal[i] + _to_normal[i] + up).normalized()
		var height := clampf(_from[i].distance_to(_to[i]) * 0.5, 0.12 * size, 0.6 * size)
		feet[i] = _from[i].lerp(_to[i], eased) + lift * sin(t * PI) * height
		var blend := _from_normal[i].lerp(_to_normal[i], eased)
		normals[i] = blend.normalized() if blend.length_squared() > 0.01 else _to_normal[i]
		if t >= 1.0:
			stepping[i] = false
			feet[i] = wants[i]
			normals[i] = wants_normal[i]
			steps += 1
		else:
			up_count[group(i)] += 1

	# New steps, four at a time: the four that most want to go, once the other four are down.
	var worst := [0.0, 0.0]
	for i in COUNT:
		if not free[i] and not stepping[i]:
			worst[group(i)] = maxf(worst[group(i)], errors[i])
	var g := 0 if worst[0] >= worst[1] else 1
	if up_count[0] + up_count[1] == 0 and worst[g] > stride:
		for i in COUNT:
			if group(i) == g and not free[i] and not stepping[i] and errors[i] > stride * 0.2:
				_begin(i, wants[i], wants_normal[i])
	# A foot left far behind goes anyway.
	for i in COUNT:
		if not free[i] and not stepping[i] and errors[i] > stride * 2.6:
			_begin(i, wants[i], wants_normal[i])


## How many feet are in the air (stepping or let go).
func lifted() -> int:
	var count := 0
	for i in COUNT:
		if stepping[i] or free[i]:
			count += 1
	return count


func _begin(i: int, to: Vector3, to_normal: Vector3) -> void:
	stepping[i] = true
	_t[i] = 0.0
	_from[i] = feet[i]
	_from_normal[i] = normals[i]
	_to[i] = to
	_to_normal[i] = to_normal


func _roots(i: int, body: Transform3D) -> void:
	var hip := hip_local(i)
	hips[i] = body * (hip * size)
	var out := Vector3(hip.x, 0.0, hip.z * 0.4).normalized()
	roots[i] = body * ((hip + out * COXA + Vector3.DOWN * 0.04) * size)


## Where a foot of leg `i` reaching towards `aim` lands: [point, normal].
func _place(space: PhysicsDirectSpaceState3D, i: int, aim: Vector3, up: Vector3) -> Array:
	if space == null:
		return [aim, up]
	var b := bones(i)
	var reach := b.x + b.y + b.z
	var root := roots[i]
	# Out from the root towards the aim, and a little past it.
	var hit := _ray(space, root, root + (aim - root) * 1.2)
	if not hit.is_empty() and root.distance_to(hit["position"]) < reach * 0.95:
		return [hit["position"], hit["normal"]]
	# Down onto the surface from over the aim.
	hit = _ray(space, aim + up * 1.5 * size, aim - up * 4.0 * size)
	if not hit.is_empty():
		return [hit["position"], hit["normal"]]
	return [aim, up]


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	query.hit_from_inside = false
	return space.intersect_ray(query)


## Works out the knees and ankles for the feet where they are: the knees up
## along `up` and out from the body's middle `centre`.
func pose(up: Vector3, centre: Vector3) -> void:
	for i in COUNT:
		var b := bones(i)
		var root := roots[i]
		var foot := feet[i]
		var inward := root - foot
		inward -= up * inward.dot(up)
		inward = inward.normalized() if inward.length_squared() > 0.0001 else Vector3.ZERO
		# The metatarsus stands steep over the foot, leaning in towards the body.
		var ankle := foot + (up * 0.8 + inward * 0.5).normalized() * b.z
		var out := root - centre
		out -= up * out.dot(up)
		var pole := up + out.normalized() * 0.3
		if free[i] and (foot - root).dot(up) > 0.3 * size:
			# Raised: the knee out to the side, so the leg arcs up and over.
			pole = out.normalized() - up * 0.2
		var solved := two_bone(root, ankle, b.x, b.y, pole)
		knees[i] = solved[0]
		ankles[i] = solved[1]


## Two-bone IK: the knee and the end, reaching from `root` towards `target`,
## the knee bent towards `pole`. If it cannot reach, it points straight there.
static func two_bone(root: Vector3, target: Vector3, upper: float, lower: float, pole: Vector3) -> Array:
	var to := target - root
	var length := to.length()
	var dir := to / maxf(length, 0.0001)
	var d := clampf(length, absf(upper - lower) + 0.01, upper + lower - 0.001)
	var a := (upper * upper - lower * lower + d * d) / (2.0 * d)
	var h := sqrt(maxf(upper * upper - a * a, 0.0))
	var bend := pole - dir * pole.dot(dir)
	if bend.length_squared() < 0.0001:
		bend = dir.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var knee := root + dir * a + bend * h
	return [knee, root + dir * d]
