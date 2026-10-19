class_name GibbonWays
extends RefCounted
## The high ways of one section of the maze, as the gibbons (MazeGibbon) go
## by them: along the edge of the ledge on every maze wall's face (the
## mezzanine, MazeStyle.level_height(0)), or where a wall has no ledge, along
## the edge of its top if that is low enough (`MOST_HIGH`); round the corners
## where walls meet, round the end of a wall that is thin enough, and in leaps
## across gaps in a wall and across halls no wider than `LEAP` from the edge
## on one side to the edge on the other. Given the maze's layout, the front
## edges of its terraces too, joined to each other and to the rest in leaps
## (across the hall, to the next along, up or down a storey). Made from the
## maze's plan and layout (no physics), once for each section (`of`), and
## shared by every gibbon in it.
##
## A FACE is the side of a cell that has a wall, (cell, step), as MazeFeatures
## has them: its edge runs along the wall a cell long, `point(face)` its middle.
## `links[face]` are where it leads, each [the face it leads to, how far, the
## way there: [point, kind] pairs, the last that face's middle]. `route` finds
## the faces from one to another; `nearest` the face whose edge is nearest a
## point.

enum Kind {
	EDGE, ## Along an edge (or round a corner of the wall it is on): brachiating, or walking along the top.
	SWING, ## Round the outside of a corner, or the end of a wall: brachiating only.
	LEAP, ## Through the air to another edge.
}

## No higher than this (a rampart, the great walls round a section, the walls of
## a section without ledges, if they are this high): out of anyone's reach.
const MOST_HIGH := 40.0
## The longest leap, metres, and the most it climbs or drops in one.
const LEAP := 17.0
const LEAP_RISE := 4.5
## Between terraces (a step of one storey, the lower to the upper), as much as this.
const TERRACE_RISE := 7.0
## Round the end of a wall no thicker than this.
const THIN := 5.0
## A leap costs this much more than going along an edge as far (it is slower to set up).
const LEAP_COST := 1.4

var maze: Maze
var ring := 0
## face key (cell index * 4 + step index) -> face number.
var faces := {}
var cells: Array[Vector2i] = []
var steps: Array[Vector2i] = []
## The middle of each face's edge (world), the way out from the wall into the hall, the way along it.
var points := PackedVector3Array()
var outs := PackedVector3Array()
var alongs := PackedVector3Array()
## How far the ledge stands out from the face (or the wall top's cornice does).
var depths := PackedFloat32Array()
## Whether one can walk along the top of it (a ledge or a wall top deep enough).
var walkable := PackedByteArray()
## How far the edge runs either way from its middle.
var halves := PackedFloat32Array()
## The faces that are the edges of terraces (MazeFeatures), by the cell they are in: cell index -> [face...].
var extra := {}
var links: Array = []
## Which group of joined-up faces each is in, and how many faces each group has.
var groups := PackedInt32Array()
var group_sizes := PackedInt32Array()

static var _made := {}
# (the pairs of faces linked by _both_ways, while they are made)
var _joined := {}


## The ways of `plan`'s section `section` (made the first time, then kept).
static func of(plan: Maze, section: int, layout: MazeLayout = null) -> GibbonWays:
	var key := "%d/%d/%d/%d" % [plan.get_instance_id(), section, plan.maze_seed, layout.get_instance_id() if layout else 0]
	if _made.has(key):
		return _made[key]
	var ways := GibbonWays.new()
	ways._make(plan, section, layout)
	# (only the last few are kept: each round makes a new maze)
	if _made.size() > 8:
		_made.clear()
	_made[key] = ways
	return ways


func size() -> int:
	return points.size()


func point(face: int) -> Vector3:
	return points[face]


static func _step_index(step: Vector2i) -> int:
	return Maze.STEPS.find(step)


func face_of(cell: Vector2i, step: Vector2i) -> int:
	return faces.get(maze.index(cell) * 4 + _step_index(step), -1) if maze.inside(cell) else -1


# --- Making them ---

func _make(plan: Maze, section: int, layout: MazeLayout) -> void:
	maze = plan
	ring = section
	if ring < 1 or ring > maze.styles.size():
		return
	# (only the band of cells the section is: from the inside of its ring to the outside)
	var middle := maze.size / 2
	var inner := (maze.ring_sizes[ring - 1] - 1) / 2 if ring - 1 < maze.ring_sizes.size() else 0
	var outer := (maze.ring_sizes[ring] - 1) / 2 if ring < maze.ring_sizes.size() else middle
	for y in range(maxi(middle - outer, 0), mini(middle + outer + 1, maze.size)):
		var row_inside := absi(y - middle) <= inner
		for x in range(maxi(middle - outer, 0), mini(middle + outer + 1, maze.size)):
			if row_inside and absi(x - middle) <= inner:
				continue
			_add_faces_of(Vector2i(x, y))
	var plain := points.size()
	if layout:
		_add_terraces(layout)
	links.resize(points.size())
	for f in points.size():
		links[f] = _links_of(f) if f < plain else []
	for f in range(plain, points.size()):
		_link_terrace(f)
	_joined.clear()
	# Which of them are joined up (a gibbon can get from any to any other of the same group).
	groups.resize(points.size())
	groups.fill(-1)
	for f in points.size():
		if groups[f] >= 0:
			continue
		var members := around(f, 1 << 20)
		for g in members:
			groups[g] = group_sizes.size()
		group_sizes.append(members.size())


## The faces of the plan's walls round `cell`, if it is a cell of the section's halls.
func _add_faces_of(cell: Vector2i) -> void:
	if not _cell_ok(cell):
		return
	for step: Vector2i in Maze.STEPS:
		var rail := _rail(cell, step)
		if rail.is_empty():
			continue
		var s := Vector3(step.x, 0.0, step.y)
		var at: Vector3 = maze.world(cell) + s * (Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5 - float(rail[1]))
		at.y = maze.ground_height(at) + rail[0]
		faces[maze.index(cell) * 4 + _step_index(step)] = points.size()
		cells.append(cell)
		steps.append(step)
		points.append(at)
		outs.append(-s)
		alongs.append(Vector3(-s.z, 0.0, s.x))
		depths.append(rail[1])
		walkable.append(1 if rail[1] >= 0.9 or maze.wall_thick(cell, step) >= 2.0 and rail[2] else 0)
		halves.append(Maze.CELL * 0.5)


func _cell_ok(cell: Vector2i) -> bool:
	return maze.inside(cell) and maze.ring_of(cell) == ring and not maze.solid.has(cell) and not maze.entrances.has(cell) and not maze.in_clearing(cell)


## [how high its edge is over the ground, how far out from the face, whether it is a wall's top], or [] for none.
func _rail(cell: Vector2i, step: Vector2i) -> Array:
	if not _cell_ok(cell) or not maze.blocked(cell, step):
		return []
	var style: MazeStyle = maze.styles[ring - 1]
	if maze.has_ledge(cell, step):
		return [style.level_height(0), style.level_depth(0), false] if style.level_height(0) <= MOST_HIGH else []
	var high := maze.wall_height(cell, step)
	return [high, MazeBuilder.CORNICE.x, true] if high <= MOST_HIGH else []


## Where the edge of face (cell, step) runs (the line, world, at its height): a point on it.
func _edge_line(cell: Vector2i, step: Vector2i) -> Vector3:
	var f := face_of(cell, step)
	return points[f] if f >= 0 else Vector3.INF


func _links_of(f: int) -> Array:
	var made: Array = []
	var cell := cells[f]
	var step := steps[f]
	var s := Vector3(step.x, 0.0, step.y)
	var here := points[f]
	var thick := maze.wall_thick(cell, step)
	for way: int in [1, -1]:
		var sw := Vector2i(-step.y, step.x) * way
		var swv := Vector3(sw.x, 0.0, sw.y)
		if maze.blocked(cell, sw):
			# Into the corner, onto the wall across the end of this one.
			var next := face_of(cell, sw)
			if next >= 0:
				var corner := here + swv * ((points[next] - here).dot(swv))
				corner.y = (here.y + points[next].y) * 0.5
				made.append(_link(next, [[corner, Kind.EDGE], [points[next], Kind.EDGE]], here))
			continue
		var on := face_of(cell + sw, step)
		if on >= 0:
			# Straight on along the same wall.
			made.append(_link(on, [[points[on], Kind.EDGE]], here))
			continue
		if maze.blocked(cell + sw, step):
			continue
		# The wall ends here. Round its corner onto a wall going on from it...
		var round := face_of(cell + sw + step, -sw)
		if round >= 0:
			var corner := here + swv * ((points[round] - here).dot(swv))
			corner.y = (here.y + points[round].y) * 0.5
			made.append(_link(round, [[corner, Kind.SWING], [points[round], Kind.SWING]], here))
		elif thick <= THIN:
			# ...or round its end onto its other side.
			var back := face_of(cell + step, -step)
			if back >= 0:
				var past := Maze.CELL * 0.5 + thick * 0.5 + depths[f]
				var a := here + swv * past
				var b := points[back] + swv * past
				made.append(_link(back, [[a, Kind.SWING], [b, Kind.SWING], [points[back], Kind.EDGE]], here))
		# ...and a leap across the gap in the wall, to where it goes on.
		for k in [2, 3]:
			var gap_face := face_of(cell + sw * k, step)
			if gap_face < 0:
				if maze.blocked(cell + sw * (k - 1), step):
					break
				continue
			var end := Maze.CELL * 0.5 + thick * 0.5
			var a := here + swv * end
			var b := points[gap_face] - swv * end
			a.y = here.y
			b.y = points[gap_face].y
			if a.distance_to(b) <= LEAP and absf(a.y - b.y) <= LEAP_RISE:
				made.append(_link(gap_face, [[a, Kind.EDGE], [b, Kind.LEAP], [points[gap_face], Kind.EDGE]], here))
			break
	# Across the hall, to the edge facing it.
	var at := cell
	for k in 3:
		if maze.blocked(at, -step):
			var other := face_of(at, -step)
			if other >= 0 and other != f:
				var to := points[other]
				var gap := Vector2(to.x - here.x, to.z - here.z).length()
				if gap <= LEAP and absf(to.y - here.y) <= LEAP_RISE:
					made.append(_link(other, [[to, Kind.LEAP]], here))
			break
		at -= step
		if not _cell_ok(at):
			break
	return made


## The terraces standing against the walls (MazeFeatures: the layout's TERRACE
## pieces, steps for something bigger than a boy): the front edge of each one's
## top is a face too, as long as the terrace.
func _add_terraces(layout: MazeLayout) -> void:
	for piece in layout.pieces(MazePiece.Kind.TERRACE):
		var t := piece.box_transform()
		var size := piece.box_size()
		var top := t.origin.y + size.y
		if top < 3.0 or top > MOST_HIGH:
			continue
		var cell := maze.cell_at(t.origin)
		if not _cell_ok(cell):
			continue
		# (its long side runs along the wall; it stands out from the wall the other way)
		var x := t.basis.x.normalized()
		var z := t.basis.z.normalized()
		var long_x := size.x >= size.z
		var along := x if long_x else z
		var deep := size.z if long_x else size.x
		var long := size.x if long_x else size.z
		if long < 3.0:
			continue
		var across := z if long_x else x
		var out := Vector3.ZERO
		for way: Vector3 in [across, -across]:
			var step := Vector2i(roundi(-way.x), roundi(-way.z))
			if step in Maze.STEPS and maze.blocked(cell, step):
				out = way
		if out == Vector3.ZERO:
			continue
		var at := t.origin + out * deep * 0.5
		at.y = top
		var f := points.size()
		cells.append(cell)
		steps.append(Vector2i(roundi(-out.x), roundi(-out.z)))
		points.append(at)
		outs.append(out)
		alongs.append(along)
		depths.append(deep)
		walkable.append(1)
		halves.append(long * 0.5)
		var key := maze.index(cell)
		if not extra.has(key):
			extra[key] = []
		extra[key].append(f)


## A terrace's links (and theirs back to it): along to an edge that goes on from
## either end of it, and leaps to the edges near it it can reach (across the
## hall, to the next along the wall, up or down to the terrace over or under it).
func _link_terrace(f: int) -> void:
	var here := points[f]
	var ends := [here + alongs[f] * halves[f], here - alongs[f] * halves[f]]
	var near: Array = []
	var middle := cells[f]
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for g in _faces_in(middle + Vector2i(dx, dz)):
				if g != f:
					near.append(g)
	var made := 0
	for g: int in near:
		var there := points[g]
		var rise := absf(there.y - here.y)
		if rise > TERRACE_RISE or Vector2(there.x - here.x, there.z - here.z).length() > LEAP + halves[f] + halves[g]:
			continue
		if _joined.has(Vector2i(mini(f, g), maxi(f, g))):
			continue
		# (on from one end of it, onto an edge at its height: a joint, gone along)
		var joined := false
		for end: Vector3 in ends:
			var onto := on_edge(g, end)
			if end.distance_to(onto) < 1.5 and rise < 1.0:
				_both_ways(f, g, [[end, Kind.EDGE], [onto, Kind.EDGE], [there, Kind.EDGE]])
				joined = true
				break
		if joined:
			continue
		# (a leap: from the nearer end or the middle of this edge to the nearest point of that one)
		var best := INF
		var from := here
		var to := there
		for p: Vector3 in [here, ends[0], ends[1]]:
			var q := on_edge(g, p)
			var gap := Vector2(q.x - p.x, q.z - p.z).length()
			if gap < best:
				best = gap
				from = p
				to = q
		if best > LEAP or best < 1.0 or rise > TERRACE_RISE or made >= 8:
			continue
		# (never a leap into the face of the wall behind it, nor through its own wall)
		# (up or down a storey, it may go in over the one below to the one above, a little)
		var back := 2.5 if rise > 2.0 else 0.5
		if (to - from).dot(outs[f]) < -back or (from - to).dot(outs[g]) < -back:
			continue
		_both_ways(f, g, [[from, Kind.EDGE], [to, Kind.LEAP], [there, Kind.EDGE]])
		made += 1


## The faces whose edges are in `cell` (the plan's and the terraces').
func _faces_in(cell: Vector2i) -> Array:
	var found: Array = []
	if not maze.inside(cell):
		return found
	var key := maze.index(cell)
	for k in 4:
		var f: int = faces.get(key * 4 + k, -1)
		if f >= 0:
			found.append(f)
	found.append_array(extra.get(key, []))
	return found


## Links `a` to `b` by `path` (ending at `b`'s middle), and `b` back to `a` by it turned round.
func _both_ways(a: int, b: int, path: Array) -> void:
	_joined[Vector2i(mini(a, b), maxi(a, b))] = true
	links[a].append(_link(b, path, points[a]))
	var back: Array = []
	for i in range(path.size() - 2, -1, -1):
		# (each leg back is gone the way the leg out of it was: a leap back is still a leap)
		back.append([path[i][0], path[i + 1][1]])
	back.append([points[a], path[0][1]])
	if link(b, a).is_empty():
		links[b].append(_link(a, back, points[b]))


## A link to face `to` by `path` from `from`: [to, how far, path].
func _link(to: int, path: Array, from: Vector3) -> Array:
	var far := 0.0
	var at := from
	for leg: Array in path:
		var d := at.distance_to(leg[0])
		far += d * (LEAP_COST if leg[1] == Kind.LEAP else 1.0)
		at = leg[0]
	return [to, far, path]


# --- Using them ---

## The face whose edge is nearest `at` (within `within` metres of it), or -1;
## with `group` given (0 or more), only of that group; with `least`, only of a
## group of at least that many faces.
func nearest(at: Vector3, within := 14.0, group := -1, least := 0) -> int:
	if points.is_empty():
		return -1
	var middle := maze.cell_at(at)
	var reach := int(ceil(within / Maze.CELL)) + 1
	var best := -1
	var best_d := within
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := middle + Vector2i(dx, dz)
			for f: int in _faces_in(cell):
				if (group >= 0 and groups[f] != group) or (least > 0 and group_sizes[groups[f]] < least):
					continue
				var d := at.distance_to(on_edge(f, at))
				if d < best_d:
					best_d = d
					best = f
	return best


## The point on face `f`'s edge nearest `at` (it runs `halves[f]` either way of its middle).
func on_edge(f: int, at: Vector3) -> Vector3:
	var along := clampf((at - points[f]).dot(alongs[f]), -halves[f], halves[f])
	return points[f] + alongs[f] * along


## The link from face `a` to face `b`, or [] if they are not linked.
func link(a: int, b: int) -> Array:
	for l: Array in links[a]:
		if l[0] == b:
			return l
	return []


## The faces from `from` to `to` (both in it) by the shortest way, if there is one no
## longer than `most` metres: [] if there is none.
func route(from: int, to: int, most := 220.0) -> Array[int]:
	var found: Array[int] = []
	if from < 0 or to < 0:
		return found
	if from == to:
		found.append(from)
		return found
	var best := {from: 0.0}
	var came := {}
	var open: Array = [[0.0, from]]
	while not open.is_empty():
		# (the nearest still open: few enough that a scan is cheaper than a heap)
		var pick := 0
		for i in open.size():
			if open[i][0] < open[pick][0]:
				pick = i
		var item: Array = open[pick]
		open.remove_at(pick)
		var f: int = item[1]
		var d: float = item[0]
		if f == to:
			break
		if d > best.get(f, INF) or d > most:
			continue
		for l: Array in links[f]:
			var n: int = l[0]
			var nd: float = d + l[1]
			if nd < best.get(n, INF):
				best[n] = nd
				came[n] = f
				open.append([nd, n])
	if not came.has(to):
		return found
	var at := to
	while at != from:
		found.push_front(at)
		at = came[at]
	found.push_front(from)
	return found


## The faces within `steps` links of `from`.
func around(from: int, steps: int) -> Array[int]:
	var seen := {from: 0}
	var queue: Array[int] = [from]
	var head := 0
	while head < queue.size():
		var f := queue[head]
		head += 1
		if seen[f] >= steps:
			continue
		for l: Array in links[f]:
			if not seen.has(l[0]):
				seen[l[0]] = seen[f] + 1
				queue.append(l[0])
	return queue
