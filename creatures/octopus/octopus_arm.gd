class_name OctopusArm
extends RefCounted
## One of the octopus's arms, as a soft chain of points (OctopusRig.ARM_BONES + 1
## of them, from the crown to the tip, in the world) that bends anywhere.
##
## Each frame its Octopus says what shape it wants it in (`want`: a line of
## points laid along some path, as `lay` lays them: along the floor to where it
## is feeling, up and coiled to strike, wrapped round what it holds...), and the
## arm goes there as something soft would: every point is pulled to its place
## by a spring (stiffer at the base, so the tip lags and whips), then the chain
## is made its length again from the root out, and kept up off the floor except
## where the ground is open (its water, the drain it is in). How fast each point
## went is kept, for the sound of it moving.

const BONES := OctopusRig.ARM_BONES

## The points, root to tip, in the world; how fast each moved; the way its suckers face along each bone.
var points := PackedVector3Array()
var speeds := PackedVector3Array()
var sides := PackedVector3Array()
## How far it has grown (1: whole; less, after it has been cut, growing back).
var grown := 1.0
## Its phase, so that the arms do not all writhe together.
var phase := 0.0


func _init(root: Vector3, out: Vector3, segment: float, seed_phase: float) -> void:
	phase = seed_phase
	points.resize(BONES + 1)
	speeds.resize(BONES + 1)
	sides.resize(BONES)
	for i in BONES + 1:
		points[i] = root + out * segment * i
	for j in BONES:
		sides[j] = Vector3.DOWN


## Puts it straight where it wants to be (nothing lagging).
func settle(want: PackedVector3Array) -> void:
	for i in BONES + 1:
		points[i] = want[i]
		speeds[i] = Vector3.ZERO


## Lays the arm along `path` (a line of points from its root), a point every
## `segment` metres; whatever length is left over past the end curls up in a
## spiral (`curl` 0 straight on, 1 a tight coil), turning about `axis`.
static func lay(path: PackedVector3Array, segment: float, curl: float, axis: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(path[0])
	var at := 0
	var travelled := 0.0
	var here := path[0]
	for i in range(1, BONES + 1):
		var want := segment
		while at < path.size() - 1:
			var left := here.distance_to(path[at + 1])
			if left >= want:
				here = here + (path[at + 1] - here) / maxf(left, 0.00001) * want
				want = 0.0
				break
			want -= left
			here = path[at + 1]
			at += 1
		if want > 0.0:
			break
		travelled += segment
		out.append(here)
	# The rest curls up from the end.
	if out.size() < BONES + 1:
		var tangent := Vector3.FORWARD
		if out.size() >= 2:
			tangent = (out[out.size() - 1] - out[out.size() - 2]).normalized()
		elif path.size() >= 2:
			tangent = (path[path.size() - 1] - path[path.size() - 2]).normalized()
		var spin := axis.normalized() if axis.length() > 0.01 else tangent.cross(Vector3.UP).normalized()
		if spin.length() < 0.5:
			spin = Vector3.RIGHT
		var radius := lerpf(6.0, 0.7, clampf(curl, 0.0, 1.0))
		var point := out[out.size() - 1]
		while out.size() < BONES + 1:
			tangent = tangent.rotated(spin, clampf(segment / radius, 0.0, 1.4))
			point += tangent * segment
			out.append(point)
			radius = maxf(radius * lerpf(0.97, 0.78, clampf(curl, 0.0, 1.0)), 0.3)
	return out


## Goes a step towards `want` (from `root`, which it is fixed to): `stiffness`
## how fast it gets there (1/s), `damping` how much it overshoots (1 none),
## the floor at `floor_y` (kept off but where `open(point)` says the ground is
## open), `radius(i)` how thick it is at each point.
func step(delta: float, root: Vector3, want: PackedVector3Array, stiffness: float, damping: float, floor_y: float, open: Callable, segment: float) -> void:
	if delta <= 0.0:
		return
	var before := points.duplicate()
	points[0] = root
	for i in range(1, BONES + 1):
		var t := float(i) / BONES
		var k := stiffness * lerpf(1.25, 0.7, t)
		var pull := (want[i] - points[i]) * k * k - speeds[i] * 2.0 * damping * k
		speeds[i] += pull * delta
		points[i] += speeds[i] * delta
	# Its length again, from the root out; and kept off the floor.
	var length := segment * grown
	for i in range(1, BONES + 1):
		var span := points[i] - points[i - 1]
		var d := span.length()
		points[i] = points[i - 1] + (span / d if d > 0.0001 else (want[i] - want[i - 1]).normalized()) * length
		var t := float(i) / BONES
		var lowest := floor_y + lerpf(0.2, 0.025, pow(t, 0.75))
		if points[i].y < lowest and not open.call(points[i]):
			points[i].y = lowest
	for i in range(1, BONES + 1):
		speeds[i] = (points[i] - before[i]) / delta if before[i].distance_to(points[i]) < 4.0 else Vector3.ZERO
	_sides(floor_y)


## The way its suckers face along each bone: carried down it from the root
## (where they face down), drawn round towards the inside of any bend (an arm
## curls with its suckers inside) and towards the floor where it lies on it.
func _sides(floor_y: float) -> void:
	var carried := Vector3.DOWN
	for j in BONES:
		var along := (points[j + 1] - points[j]).normalized()
		var want := carried - along * carried.dot(along)
		if j > 0 and j < BONES:
			var bend := (points[j + 1] - points[j]) - (points[j] - points[j - 1])
			bend -= along * bend.dot(along)
			var amount := clampf(bend.length() / 0.12, 0.0, 1.0)
			if amount > 0.05:
				want = want.normalized() + bend.normalized() * amount * 1.5
		var low := Vector3.DOWN - along * along.y
		var lying := 1.0 - clampf((points[j].y - floor_y - 0.1) / 0.9, 0.0, 1.0)
		want = want.normalized() + low * (0.3 + 2.5 * lying)
		want -= along * want.dot(along)
		if want.length() < 0.001:
			want = along.cross(Vector3.RIGHT)
		want = want.normalized()
		# (it turns about itself only smoothly)
		sides[j] = sides[j].slerp(want, 0.35).normalized() if sides[j].dot(want) > -0.95 else want
		carried = sides[j]


## The tip.
func tip() -> Vector3:
	return points[BONES]


## How far `point` is from the arm (from the nearest point along it), and how far along it that is (0..1).
func nearest(point: Vector3) -> Vector2:
	var best := INF
	var at := 0.0
	for i in BONES:
		var a := points[i]
		var b := points[i + 1]
		var ab := b - a
		var f := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := point.distance_to(a + ab * f)
		if d < best:
			best = d
			at = (i + f) / BONES
	return Vector2(best, at)


## How fast it is moving, on the whole (m/s, the outer half).
func motion() -> float:
	var total := 0.0
	for i in range(BONES / 2, BONES + 1):
		total += speeds[i].length()
	return total / (BONES / 2 + 1)
