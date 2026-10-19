class_name HighWays
extends RefCounted
## The high ways of one zone of the maze, as what hunts there climbs or leaps up
## onto them (MazeEnemy.climbs, HighClimb; the user, 2026-10-18: "more creatures
## should be able to climb things"): every flat top above the floor that one could
## stand on, a SURFACE each. The levels of ledge along the walls (the layout's PIER
## pieces with `ledge`: MazeStyle.mezzanines), the terraces (TERRACE pieces) and the
## concrete bridges between ledges (PIER pieces with an `arch`). Anything else laid
## out as a box whose top is walked on (the metal catwalks to come) is one more
## line in `_wanted`: a surface is only a box's top, from where it stands.
##
## Made from the maze's plan and layout (no physics), once for each zone (`of`), and
## shared by everything in it. A surface is a rectangle (x and z, the walls are square
## to the axes) and its top's height; its FRONTS are the sides of it one climbs up
## to (those not against a wall nor against another surface at its height), each a
## line along its top's edge and the way out from it. `way_up` is how to get up to a
## surface from the floor, stage by stage: up the front of the level under it first,
## along that, and up the next (the ledges step back as they rise).
##
## Cheap to ask: the surfaces are kept by the cells they are over (`_by_cell`), and
## each question looks at the few in one cell.

enum Kind { LEDGE, TERRACE, DECK }

## Higher than this over the floor under it, someone is up (a jump is not).
const UP := 1.4
## How near a surface's top (m) a point must be to be on it.
const ON := 0.45

var maze: Maze
var zone := 0
## Each surface: where it is (x and z), how high its top is, what it is.
var rects: Array[Rect2] = []
var tops := PackedFloat32Array()
var kinds := PackedByteArray()
## Each surface's fronts: [[a, b, out], ...] (a and b the ends of its edge at its top, out the way out from it).
var fronts: Array = []

# cell index -> PackedInt32Array of the surfaces over it.
var _by_cell := {}

static var _made := {}


## The high ways of `plan`'s zone `zone_number` (MazeLayout.zone_at), from `layout`'s
## pieces (made the first time, then kept).
static func of(plan: Maze, zone_number: int, layout: MazeLayout) -> HighWays:
	var key := "%d/%d/%d/%d" % [plan.get_instance_id(), zone_number, plan.maze_seed, layout.get_instance_id() if layout else 0]
	var known: Variant = _made.get(key)
	if known != null:
		return known
	var ways := HighWays.new()
	var started := Time.get_ticks_usec()
	ways._make(plan, zone_number, layout)
	ways.made_in = (Time.get_ticks_usec() - started) / 1000.0
	# (only the last few are kept: each round makes a new maze)
	if _made.size() > 8:
		_made.clear()
	_made[key] = ways
	return ways


## How long it took to make, ms (for the tests).
var made_in := 0.0


## The pieces `node`'s maze was built from: the layout of the MazeBuilder named Maze
## beside one of the nodes it is under (as MazeGibbon finds it), or null.
static func layout_for(node: Node, plan: Maze) -> MazeLayout:
	var at: Node = node.get_parent()
	while at:
		var builder := at.get_node_or_null(^"Maze") as MazeBuilder
		if builder and builder.maze == plan:
			return builder.layout
		at = at.get_parent()
	return null


func size() -> int:
	return tops.size()


# --- Making them ---

## Whether a piece's top is a surface, and what kind.
static func _wanted(piece: MazePiece) -> int:
	if piece.kind == MazePiece.Kind.TERRACE:
		return Kind.TERRACE
	if piece.kind == MazePiece.Kind.PIER and piece.arch > 0.0:
		return Kind.DECK
	if piece.kind == MazePiece.Kind.PIER and piece.ledge:
		return Kind.LEDGE
	return -1


func _make(plan: Maze, zone_number: int, layout: MazeLayout) -> void:
	maze = plan
	zone = zone_number
	if layout == null:
		return
	for piece in layout.pieces(MazePiece.Kind.PIER) + layout.pieces(MazePiece.Kind.TERRACE):
		var kind := _wanted(piece)
		if kind < 0 or MazeLayout.zone_of(plan, piece) != zone:
			continue
		var t := piece.box_transform()
		var half := piece.box_size() * 0.5
		var top := t.origin.y + piece.box_size().y
		if top - maze.ground_height(t.origin) < UP:
			continue
		var area := Rect2(Vector2(t.origin.x, t.origin.z), Vector2.ZERO)
		for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
			var p: Vector3 = t * corner
			area = area.expand(Vector2(p.x, p.z))
		if area.size.x < 0.3 or area.size.y < 0.3:
			continue
		var s := tops.size()
		rects.append(area)
		tops.append(top)
		kinds.append(kind)
		var first := maze.cell_at(Vector3(area.position.x, 0.0, area.position.y))
		var last := maze.cell_at(Vector3(area.end.x, 0.0, area.end.y))
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				if not maze.inside(cell):
					continue
				var i := maze.index(cell)
				var list: PackedInt32Array = _by_cell.get(i, PackedInt32Array())
				list.append(s)
				_by_cell[i] = list
	fronts.resize(tops.size())
	for s in tops.size():
		fronts[s] = _fronts_of(s)


## The sides of surface `s` that are open: neither against a wall (by the plan) nor
## against another surface at its height.
func _fronts_of(s: int) -> Array:
	var made: Array = []
	var r := rects[s]
	var top := tops[s]
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var middle := (a + b) * 0.5
		var out2 := (middle - r.get_center())
		out2 = Vector2(signf(out2.x), 0.0) if absf(b.y - a.y) > absf(b.x - a.x) else Vector2(0.0, signf(out2.y))
		var out := Vector3(out2.x, 0.0, out2.y)
		var length := a.distance_to(b)
		# (looked at a little out from it, at a few places along it: a side against a wall, or against
		# another at its height, at its middle and both quarters, is not a way up)
		var open := 0
		for u: float in [0.25, 0.5, 0.75]:
			var p2 := a.lerp(b, u) + out2 * 0.3
			var p := Vector3(p2.x, top - 0.1, p2.y)
			if not in_wall(p) and level_at(p, top, 0.3) < 0:
				open += 1
		if open >= 2 and length > 0.8:
			made.append([Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), out])
	return made


## Whether a point is inside a wall, by the plan (the walls' faces; no ledges): outside
## the maze, in a solid cell, or nearer the side of its cell than that side's wall's face.
func in_wall(p: Vector3) -> bool:
	var cell := maze.cell_at(p)
	if not maze.inside(cell) or maze.solid.has(cell):
		return true
	var off := p - maze.world(cell)
	var half := Maze.CELL * 0.5
	for step: Vector2i in Maze.STEPS:
		var along := off.x * step.x + off.z * step.y
		if along > half - maze.wall_thick(cell, step) * 0.5 - 0.02 and maze.blocked(cell, step):
			return true
	return false


# --- Using them ---

## The surfaces over the cell `p` is in.
func _near(p: Vector3) -> PackedInt32Array:
	var cell := maze.cell_at(p)
	if not maze.inside(cell):
		return PackedInt32Array()
	return _by_cell.get(maze.index(cell), PackedInt32Array())


## The surface whose top is within `within` of `height` and is under `p` (x and z; `inset`
## metres in from its sides, as far as it is wide), the nearest in height; or -1.
func level_at(p: Vector3, height: float, within := ON, inset := 0.0) -> int:
	var best := -1
	var best_d := within
	var at := Vector2(p.x, p.z)
	for s in _near(p):
		var d := absf(tops[s] - height)
		if d > best_d:
			continue
		var r := rects[s]
		var i := minf(inset, minf(r.size.x, r.size.y) * 0.5 - 0.05)
		if r.grow(-i).has_point(at):
			best = s
			best_d = d
	return best


## The surface someone at `p` stands on (its top a little under their feet, or at
## them), or -1.
func under(p: Vector3) -> int:
	return level_at(p + Vector3.DOWN * 0.15, p.y - 0.15, ON + 0.15, -0.25)


## The surface for someone at `p` who is up off the floor but on none (on ivy up to a
## ledge, hanging from its lip, just jumped): the nearest within `reach` (x and z) whose
## top is from a metre under them to `higher` over them; or -1.
func near(p: Vector3, reach := 2.5, higher := 12.0) -> int:
	var best := -1
	var best_d := reach
	for s in _near(p):
		if tops[s] < p.y - 1.0 or tops[s] > p.y + higher:
			continue
		var d := _rect_distance(rects[s], Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = s
	return best


static func _rect_distance(r: Rect2, at: Vector2) -> float:
	var nearest := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
	return nearest.distance_to(at)


## The point on a front of surface `s` nearest `p` (x and z), kept `inset` in from the
## front's ends when it is long enough: [the point, the way out], or [] if it has none.
func nearest_front(s: int, p: Vector3, inset := 0.6) -> Array:
	var best: Array = []
	var best_d := INF
	for front: Array in fronts[s]:
		var a: Vector3 = front[0]
		var b: Vector3 = front[1]
		var long := a.distance_to(b)
		var way := (b - a) / maxf(long, 0.001)
		var i := minf(inset, long * 0.5)
		var along := clampf((p - a).dot(way), i, long - i)
		var on := a + way * along
		var d := Vector2(on.x - p.x, on.z - p.z).length()
		if d < best_d:
			best_d = d
			best = [on, front[2]]
	return best


## The way up onto surface `s`, at the place on its fronts nearest `p`, from the floor:
## its stages from the lowest, each [the point on the front's edge at its top, the way
## out from it, how high its top is, how high what it rises from is (the floor, or the
## surface under it)]. [] if it has no front.
func way_up(s: int, p: Vector3) -> Array:
	var stages: Array = []
	var on := s
	var from := p
	for k in 6:
		var front := nearest_front(on, from)
		if front.is_empty():
			return [] if stages.is_empty() else stages
		var edge: Vector3 = front[0]
		var out: Vector3 = front[1]
		var below := edge + out * 0.2
		# (the highest surface under its front, if any, a good step down)
		var under_it := -1
		for t in _near(below):
			if tops[t] < tops[on] - 0.4 and rects[t].has_point(Vector2(below.x, below.z)) and (under_it < 0 or tops[t] > tops[under_it]):
				under_it = t
		var base := tops[under_it] if under_it >= 0 else maze.ground_height(below)
		stages.push_front([edge, out, tops[on], base])
		if under_it < 0:
			break
		on = under_it
		from = edge
	return stages
