@tool
class_name SewerMouth
extends RefCounted
## The mouth of a sewer pipe (SewerPipe) where it comes out of a wall, modelled
## in concrete (the user, 2026-10-19: "the sewer tunnel entrances should have
## modeleed funnel entrances rather than just square terraces"): the pipe flares
## out of the wall into a bell, like a culvert's outfall, its rim worn round, and
## it stands on a lip of concrete jutting out under it, flat on top so he can stand
## at the mouth (and climb onto it, from the ivy up to its front), its front edge
## rounded over, its corners round in plan, and its underside curving back down
## into the wall in a cove, as a corbel's does.
##
## It is drawn from the platform under the mouth (a PIER piece with `mouth`, the way
## out of the wall): the platform's box is the lip's flat top (`size`, as before),
## the bell standing on it at the wall and the cove hanging under it. It is merged
## into the walls' squares by MazeBuilder (WallMesh, the ledges' concrete, so it
## weathers as they do: grime run down from its lip, its edges worn pale), and
## bumped into as a few boxes (`colliders`): the lip, the bell's two cheeks and its roof.

## How far the bell stands out of the wall, how wide it is inside at its mouth
## (its radius, metres), how thick its rim is, and how far round it is against the
## wall (covering the edges of the hole the pipe goes through).
const BELL := 0.85
const FLARE := 1.0
const SKIN := 0.16
const COLLAR := 0.9
## How round the lip's front edge is (as the ledges' edges are worn), and how far
## down the wall under the lip its cove runs, from the lip's foot.
const NOSE := 0.14
const COVE := 1.2
## How square the lip is in plan (higher, squarer; 2 would be a half ellipse).
const SQUARE := 6.0
## How many steps round the bell.
const AROUND := 20
## Far enough that an edge so far off shows no wear (as WallMesh.FAR).
const FAR := WallMesh.FAR


## The mouth's own frame, for a platform `size` in the space of `where` whose way
## out of the wall is `out` (in the platform's own space): its origin on the wall's
## face at the foot of the lip, +X along the wall, +Y up, +Z out of the wall.
static func frame(where: Transform3D, size: Vector3, out: Vector3) -> Transform3D:
	var z := out.normalized()
	return where * Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), -z * extents(size, out).z * 0.5)


## How wide the lip is along the wall, how thick, and how deep out from it.
static func extents(size: Vector3, out: Vector3) -> Vector3:
	var z := out.normalized()
	return Vector3(absf(size.x * z.z) + absf(size.z * z.x), size.y, absf(size.x * z.x) + absf(size.z * z.z))


## How far out the lip's front is at `u` along it (-1 to 1, end to end), as a
## share of its depth: round at the corners.
static func reach(u: float) -> float:
	return pow(maxf(1.0 - pow(absf(u), SQUARE), 0.0), 1.0 / SQUARE)


## Adds the mouth to `mesh`: the lip, its front edge rounded over (NOSE), and the bell.
static func add(mesh: WallMesh, where: Transform3D, size: Vector3, out: Vector3) -> void:
	var at := frame(where, size, out)
	var e := extents(size, out)
	var half := e.x * 0.5
	var deep := e.z
	var top := e.y
	var nose := minf(NOSE, top * 0.45)
	# The lip: across it (closer together near its ends, where its corners turn
	# in sharply), and down its profile: its top out from the wall, over its nose,
	# down its front and back up under it in the cove to the wall.
	var us := PackedFloat32Array([-1.0, -0.998, -0.99, -0.975, -0.95, -0.9, -0.82, -0.7, -0.5, -0.25, 0.0])
	for k in range(us.size() - 2, -1, -1):
		us.append(-us[k])
	# ([out, up, how far down from the top edge: -1 on the top])
	var profile: Array = []
	for t: float in [0.0, 0.3, 0.6, 0.85, 1.0]:
		profile.append([(deep - nose) * t, top, -1.0])
	for d: float in [67.5, 45.0, 22.5, 0.0]:
		var a := deg_to_rad(d)
		profile.append([deep - nose + nose * cos(a), top - nose + nose * sin(a), (top - (top - nose + nose * sin(a))) if d <= 45.0 else -1.0])
	profile.append([deep, 0.0, top])
	for k in range(1, 9):
		var a := PI * 0.5 * k / 8.0
		var o := deep * (1.0 - sin(a))
		var y := -COVE * (1.0 - cos(a))
		profile.append([o, y, top + (deep - o) + (0.0 - y)])
	var grid: Array = []
	for row: Array in profile:
		var points := PackedVector3Array()
		for u in us:
			points.append(Vector3(u * half, row[1], float(row[0]) * reach(u)))
		grid.append(points)
	# (its top worn from its front and its ends; down its front, from its top edge
	# and its ends; split at the middle of the nose, where the one gives way to the other)
	var lip_wear := func(j: int, i: int, face: int) -> Array:
		var row: Array = profile[j]
		if float(profile[face][2]) < 0.0:
			return [Vector2(us[i] * half, row[0]), Vector2(half, deep)]
		return [Vector2(us[i] * half, FAR - maxf(row[2], 0.0)), Vector2(half, FAR)]
	_surface(mesh, at, grid, lip_wear, 6)
	# The bell, round from the floor on one side over to the floor on the other,
	# along its profile: inside it from the wall out, round its rim, and back along
	# its outside to the wall ([out, radius, how far from the rim]).
	var r0 := SewerPipe.BORE * 0.5
	var bell: Array = []
	for k in 7:
		var t := k / 6.0
		var r := r0 + (FLARE - r0) * t * t
		bell.append([BELL * t, r, Vector2(BELL * (1.0 - t), FLARE - r).length()])
	var lip := SKIN * 0.5
	for k in range(1, 6):
		var a := -PI * 0.5 + PI * k / 5.0
		bell.append([BELL + lip * cos(a), FLARE + lip + lip * sin(a), 0.0])
	for k in range(1, 5):
		var t := 1.0 - k / 4.0
		var r := COLLAR + (FLARE + SKIN - COLLAR) * t
		bell.append([BELL * t, r, Vector2(BELL * (1.0 - t), FLARE + SKIN - r).length()])
	var middle := top + SewerPipe.RISE
	grid = []
	for row: Array in bell:
		var r: float = row[1]
		# (from the floor round over the top to the floor: the floor is the lip's top)
		var low := asin(minf(SewerPipe.RISE / r, 1.0))
		var points := PackedVector3Array()
		for k in AROUND + 1:
			var a := -low + (PI + 2.0 * low) * k / AROUND
			points.append(Vector3(r * cos(a), middle + r * sin(a), row[0]))
		grid.append(points)
	# (its rim worn, and grime run back from it)
	var bell_wear := func(j: int, _i: int, _face: int) -> Array:
		return [Vector2.ZERO, Vector2(FAR, float(bell[j][2]) + 0.001)]
	_surface(mesh, at, grid, bell_wear, -1)


## A surface through a grid of points (rows of columns) in the frame `at`, its
## normals running smoothly over it, each point worn as `wear` (row, column, the row
## whose face it is measured as) says: [UV, UV2], as WallMesh puts them. The row
## `cut` (if any) is made twice, worn as the row before it and as itself, so that the
## wear of two faces is not smeared across the edge between them. Where a column's
## points meet in one (the lip's top at its ends, against the wall) it faces as the next one in does.
static func _surface(mesh: WallMesh, at: Transform3D, grid: Array, wear: Callable, cut: int) -> void:
	var rows := grid.size()
	var cols := (grid[0] as PackedVector3Array).size()
	var starts: Array = []
	for j in rows:
		var p: PackedVector3Array = grid[j]
		var before: PackedVector3Array = grid[maxi(j - 1, 0)]
		var after: PackedVector3Array = grid[mini(j + 1, rows - 1)]
		var first := mesh.points.size()
		starts.append([first, first + (cols if j == cut else 0)])
		for face: int in ([j - 1, j] if j == cut else [j]):
			for i in cols:
				var n := (after[i] - before[i]).cross(p[mini(i + 1, cols - 1)] - p[maxi(i - 1, 0)])
				if n.length_squared() < 1e-10:
					var k := i + (1 if i == 0 else -1)
					n = (after[k] - before[k]).cross(p[mini(k + 1, cols - 1)] - p[maxi(k - 1, 0)])
				mesh.points.append(at * p[i])
				mesh.normals.append((at.basis * n).normalized())
				var w: Array = wear.call(j, i, face)
				mesh.uvs.append(w[0])
				mesh.uv2s.append(w[1])
	for j in rows - 1:
		var a: int = starts[j][1]
		var b: int = starts[j + 1][0]
		for i in cols - 1:
			_triangle(mesh, a + i, b + i, b + i + 1)
			_triangle(mesh, a + i, b + i + 1, a + i + 1)


## One triangle, wound to face the way its points' normals do (Godot's front faces
## are the ones whose (q - p) x (r - p) points away from the viewer).
static func _triangle(mesh: WallMesh, p: int, q: int, r: int) -> void:
	var n := mesh.normals[p] + mesh.normals[q] + mesh.normals[r]
	var face := (mesh.points[q] - mesh.points[p]).cross(mesh.points[r] - mesh.points[p])
	if face.length_squared() < 1e-12:
		return
	if face.dot(n) > 0.0:
		mesh.indices.append_array([p, r, q])
	else:
		mesh.indices.append_array([p, q, r])


## What to bump into, as [transform, size] boxes in the space `where` is in: the lip
## (the platform's box, as before), the bell's two cheeks (narrowing from its mouth to
## the hole through the wall, so he is led in) and its roof (sloping down to the
## top of the hole). Inside the wall, the hole's sides are bumped into.
static func colliders(where: Transform3D, size: Vector3, out: Vector3) -> Array:
	var at := frame(where, size, out)
	var e := extents(size, out)
	var top := e.y
	var made: Array = []
	made.append([at * Transform3D(Basis.IDENTITY, Vector3(0.0, top * 0.5, e.z * 0.5)), Vector3(e.x, top, e.z)])
	var thick := 0.3
	var high := SewerPipe.RISE + FLARE + SKIN
	var wide := sqrt(FLARE * FLARE - SewerPipe.RISE * SewerPipe.RISE)
	for s: float in [-1.0, 1.0]:
		var from := Vector3(s * (SewerPipe.HOLE.x * 0.5 + thick * 0.5), 0.0, 0.0)
		var to := Vector3(s * (wide + thick * 0.5), 0.0, BELL)
		var run := to - from
		var turn := Basis(Vector3.UP, atan2(run.x, run.z))
		var middle := (from + to) * 0.5 + Vector3.UP * (top + high * 0.5)
		made.append([at * Transform3D(turn, middle), Vector3(thick, high, run.length() + 0.1)])
	# (its underside from the top of the hole at the wall to the top of the bell's mouth)
	var low := Vector3(0.0, top + SewerPipe.HOLE.y, 0.0)
	var mouth := Vector3(0.0, top + SewerPipe.RISE + FLARE, BELL)
	var slope := mouth - low
	var tilt := Basis(Vector3.RIGHT, -atan2(slope.y, slope.z))
	var roof := 0.25
	made.append([at * Transform3D(tilt, (low + mouth) * 0.5 + tilt.y * roof * 0.5), Vector3((wide + thick) * 2.0, roof, slope.length() + 0.1)])
	return made
