class_name GrieverLegs
extends RefCounted
## A Griever's eight metal legs, walking by themselves.
##
## Each foot is planted somewhere in the world and stays there until the place
## it would rather be (its rest place round the body, carried a little ahead of
## where the body is going) is too far from it; then it steps, lifting in an
## arc. A leg does not step while a leg beside it, or the one across from it,
## is in the air, so they fall into alternating groups by themselves; one that
## is pulled far too far steps anyway.
##
## Where a foot goes is found by casting rays: from the hip out towards its rest
## place, which in a passage meets the wall's footing or the wall itself (the
## middle legs reach high, so that it braces itself across the passage), and,
## failing that, straight down to the ground.
##
## Each leg is three bones: thigh and shin by two-bone IK with the knee kept up
## and out like a spider's, and a short claw that stabs into whatever the foot
## stands on. A piston runs from the body to the thigh, and another from the
## thigh to the shin.

## How many legs, and the bones of each (metres).
const COUNT := 8
const THIGH := 2.05
const SHIN := 2.5
const CLAW := 0.6

## Where each leg leaves the body (body space, forward -Z), left side first,
## front to back; the right side is the mirror.
const HIPS: Array[Vector3] = [Vector3(-1.25, -0.15, -1.3), Vector3(-1.5, -0.06, -0.45), Vector3(-1.5, -0.06, 0.45), Vector3(-1.25, -0.15, 1.3)]
## Where each foot would rest (ground space: on the ground under the body's
## middle, forward -Z): the angle round from straight ahead (degrees), how far
## out, and how high up a wall it reaches for if there is one.
const REST: Array[Vector3] = [Vector3(38.0, 3.6, 0.0), Vector3(78.0, 3.7, 2.8), Vector3(108.0, 3.7, 1.3), Vector3(145.0, 3.6, 0.0)]

## Planted (or stepping) feet in the world, and the way the surface faces.
var feet := PackedVector3Array()
var normals := PackedVector3Array()
## Each leg's hip, knee and ankle in the world, from the last `pose`.
var hips := PackedVector3Array()
var knees := PackedVector3Array()
var ankles := PackedVector3Array()
var stepping: Array[bool] = []
## Whether each foot found anything to stand on.
var grounded: Array[bool] = []
## How far through its step each leg is (0..1).
var _t := PackedFloat32Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _to_normal := PackedVector3Array()
var _from_normal := PackedVector3Array()
## Steps taken (for sounds, and tests).
var steps := 0
var exclude: Array[RID] = []


func _init() -> void:
	for i in COUNT:
		feet.append(Vector3.ZERO)
		normals.append(Vector3.UP)
		hips.append(Vector3.ZERO)
		knees.append(Vector3.ZERO)
		ankles.append(Vector3.ZERO)
		stepping.append(false)
		grounded.append(true)
		_t.append(0.0)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_to_normal.append(Vector3.UP)
		_from_normal.append(Vector3.UP)


## Leg i's hip in body space.
static func hip_local(i: int) -> Vector3:
	var h := HIPS[i % 4]
	return h if i < 4 else Vector3(-h.x, h.y, h.z)


## Leg i's rest place in ground space, at the height it reaches for on a wall.
static func rest_local(i: int) -> Vector3:
	var r := REST[i % 4]
	var angle := deg_to_rad(r.x)
	var side := -1.0 if i < 4 else 1.0
	return Vector3(sin(angle) * r.y * side, r.z, -cos(angle) * r.y)


## Puts every foot straight down where it rests.
func settle(space: PhysicsDirectSpaceState3D, body: Transform3D, ground: Transform3D) -> void:
	for i in COUNT:
		var hit := _place(space, body * hip_local(i), ground * rest_local(i), ground.basis.y)
		feet[i] = hit[0]
		normals[i] = hit[1]
		grounded[i] = hit[2]
		stepping[i] = false


## Moves the feet on: `body` is the body's place now, `ground` the place under
## it (yaw only), `velocity` how it is moving.
func update(delta: float, space: PhysicsDirectSpaceState3D, body: Transform3D, ground: Transform3D, velocity: Vector3) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	# Quicker, longer steps the faster it goes.
	var step_time := clampf(0.34 - speed * 0.035, 0.15, 0.34)
	var stride := clampf(0.75 + speed * 0.16, 0.75, 1.7)
	var reach := THIGH + SHIN + CLAW * 0.5
	var wants := PackedVector3Array()
	var wants_normal := PackedVector3Array()
	var wants_ground: Array[bool] = []
	var errors := PackedFloat32Array()
	for i in COUNT:
		var hip := body * hip_local(i)
		hips[i] = hip
		# (aim ahead, so the foot lands where the body is going to be)
		var aim := ground * rest_local(i) + velocity * step_time * 1.6
		var hit := _place(space, hip, aim, ground.basis.y)
		wants.append(hit[0])
		wants_normal.append(hit[1])
		wants_ground.append(hit[2])
		var error: float = feet[i].distance_to(hit[0])
		if feet[i].distance_to(hip) > reach:
			error += 10.0
		errors.append(error)

	# Steps under way go on (and keep after where they are going).
	for i in COUNT:
		if not stepping[i]:
			continue
		_to[i] = _to[i].lerp(wants[i], 1.0 - exp(-(10.0 + 30.0 * _t[i]) * delta))
		_to_normal[i] = wants_normal[i]
		_t[i] = minf(_t[i] + delta / step_time, 1.0)
		var t := _t[i]
		var eased := t * t * (3.0 - 2.0 * t)
		var lift := (_from_normal[i] + _to_normal[i] + Vector3.UP * 2.0).normalized()
		var height := clampf(_from[i].distance_to(_to[i]) * 0.45, 0.25, 0.9)
		feet[i] = _from[i].lerp(_to[i], eased) + lift * sin(t * PI) * height
		normals[i] = _from_normal[i].slerp(_to_normal[i], eased) if _from_normal[i].dot(_to_normal[i]) > -0.9 else _to_normal[i]
		if t >= 1.0:
			stepping[i] = false
			feet[i] = wants[i]
			normals[i] = wants_normal[i]
			grounded[i] = wants_ground[i]
			steps += 1

	# New steps: the furthest out first, if the legs round them are down.
	var order: Array[int] = []
	for i in COUNT:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return errors[a] > errors[b])
	var up := 0
	for i in COUNT:
		if stepping[i]:
			up += 1
	for i: int in order:
		if stepping[i] or errors[i] < stride:
			continue
		var overdue := errors[i] > stride * 2.2
		if up >= 4 or (not overdue and _neighbour_up(i)):
			continue
		stepping[i] = true
		_t[i] = 0.0
		_from[i] = feet[i]
		_from_normal[i] = normals[i]
		_to[i] = wants[i]
		_to_normal[i] = wants_normal[i]
		up += 1


func _neighbour_up(i: int) -> bool:
	var side := i / 4 * 4
	var k := i % 4
	if k > 0 and stepping[side + k - 1]:
		return true
	if k < 3 and stepping[side + k + 1]:
		return true
	return stepping[(i + 4) % COUNT]


## Where a foot reaching from `hip` towards `aim` lands: [point, normal, on something].
func _place(space: PhysicsDirectSpaceState3D, hip: Vector3, aim: Vector3, up: Vector3) -> Array:
	if space == null:
		return [aim, up, false]
	var reach := THIGH + SHIN + CLAW
	# Out from the hip towards the aim, and a little past it.
	var to := hip + (aim - hip) * 1.25
	var hit := _ray(space, hip, to)
	if not hit.is_empty() and hip.distance_to(hit["position"]) < reach * 0.97:
		return [hit["position"], hit["normal"], true]
	# Straight down from the aim (and over a lip, from a little above it).
	hit = _ray(space, aim + up * 1.2, aim - up * 7.0)
	if not hit.is_empty():
		return [hit["position"], hit["normal"], true]
	return [aim, up, false]


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	query.hit_from_inside = false
	return space.intersect_ray(query)


## Works out the knees and ankles for the feet where they are, with the knees
## up along `up` and out from the body's middle `centre`.
func pose(up: Vector3, centre: Vector3) -> void:
	for i in COUNT:
		var hip := hips[i]
		var foot := feet[i]
		var toward_hip := (hip - foot).normalized()
		# The claw stands out of the surface, leaning back towards the body.
		var claw_dir := (normals[i] * 0.65 + toward_hip * 0.35 + up * 0.15).normalized()
		var ankle := foot + claw_dir * CLAW
		var out := hip - centre
		out -= up * out.dot(up)
		var pole := up * 1.0 + out.normalized() * 0.45
		var solved := two_bone(hip, ankle, THIGH, SHIN, pole)
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


## The mean height of the feet over `ground` (along its up), and how the front
## stands above the back and the left above the right.
func lie(ground: Transform3D) -> Vector3:
	var up := ground.basis.y
	var total := 0.0
	var front := 0.0
	var back := 0.0
	var left := 0.0
	var right := 0.0
	for i in COUNT:
		var h := (feet[i] - ground.origin).dot(up)
		total += h
		if i % 4 == 0:
			front += h
		elif i % 4 == 3:
			back += h
		if i < 4:
			left += h
		else:
			right += h
	return Vector3(total / COUNT, (front - back) * 0.5, (left - right) / 4.0)
