@tool
class_name MazeProps
extends Node3D
## What is left of the maze's plumbing and of those who lived in it before: old
## vents high on the walls, barred culverts at their feet, small pipes coming out
## of them with rust stains under (some dripping into a puddle), drain grates and
## manhole covers in the floor; heaps of boxes and barrels against the walls, and
## old electric cables strung high across the halls among the vines, sagging,
## some snapped and hanging, now and then a dead lamp hanging from one. All
## weathered and dull, to sit in the grey (DESIGN.md, "Signs of life").
##
## `lay_out` chooses them from the maze's seed by each section's MazeStyle
## ("Sewers", "Signs of life"), as PROP and WIRE pieces of a MazeLayout, after the
## ways up (MazeFeatures), which they keep clear of; `realize` makes them from a
## layout's pieces, as laid out or as moved by hand. They are drawn as one
## MultiMesh for each kind in each square of SQUARE metres (the cables merged into
## one mesh a square), lost past the mist; nothing of them processes (the drips
## fall in their shader); the boxes and barrels are solid, all their shapes in one
## body put together before it goes into the world.

enum Prop { VENT, ROUND_VENT, CULVERT, OUTLET, DRAIN, MANHOLE, PUDDLE, STAIN, CRATE, BARREL, HOLE }

## The squares they are drawn in, metres, and how far off each is drawn (past
## this the mist has them).
const SQUARE := 140.0
const FAR := 150.0
const FLOOR_FAR := 110.0
const WIRE_FAR := 160.0
const DRIP_FAR := 45.0
## How big a barrel is (radius, height), and a crate's side at scale 1.
const BARREL := Vector2(0.3, 0.88)
## How big an old lamp hanging from a cable is drawn (a street lamp's size: it is high up).
const LAMP_SIZE := 1.6

## What was made, for tests and tools: how many of each Prop, how many cables
## (and how many snapped, and lamps), how many solid shapes, how many drips.
var counts := {}
var cables := 0
var snapped := 0
var lamps := 0
var solid_shapes := 0
var drips := 0
## The body the boxes and barrels are in.
var body: StaticBody3D

var _maze: Maze
var _layout: MazeLayout
var _rng := RandomNumberGenerator.new()
## section -> its numbers.
var _rngs := {}
## The sections being laid out (all, if empty).
var _zones := {}
var _style: MazeStyle
## The boxes of stone (walls, piers, terraces) by square of BOX_SQUARE metres:
## [inverse transform, half size].
var _boxes := {}
## What is taken already (the ways up, and props put down), by square: Rect2s
## of the ground, x and z.
var _taken := {}
## The heaps (boxes and barrels) by square, [x and z, radius], for keeping
## other things (Loot) off them.
var _heaps := {}

const BOX_SQUARE := 20.0

static var _meshes := {}
static var _materials := {}
static var _drip_shader: Shader


# --- Laying out ---------------------------------------------------------------

## Lays out the props of `maze` as pieces of `layout`, by the sections' styles;
## only in the sections in `zones` (ring -> true), if any are given.
static func lay_out(layout: MazeLayout, maze: Maze, zones: Dictionary = {}) -> void:
	var placer := MazeProps.new()
	placer._zones = zones
	placer._place(layout, maze)
	placer.free()


func _place(layout: MazeLayout, plan: Maze) -> void:
	_maze = plan
	_layout = layout
	var wanted := false
	for style in plan.styles:
		if style and not style.round_section and _wants(style):
			wanted = true
	if not wanted:
		return
	_hash_boxes(layout)
	_keep_clear_of_ways_up(layout)
	var strands := layout.pieces(MazePiece.Kind.STRAND)
	var vines := layout.pieces(MazePiece.Kind.VINE)
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		if not _in_a_section(cell):
			continue
		var near_gate := _by_a_gate(cell)
		for step: Vector2i in Maze.STEPS:
			if plan.blocked(cell, step):
				_dress_face(cell, step, near_gate)
		_dress_floor(cell, near_gate)
	# Cables across the halls, from the cell at one side of a hall to the one at the other.
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		if not _in_a_section(cell) or _style.cable_share <= 0.0:
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if plan.blocked(cell, -step) and _rng.randf() < _style.cable_share:
				_cable_across(cell, step)
	# Cables in among the vines strung across the halls, and hanging beside the
	# vines hanging from the walls.
	for strand in strands:
		if _style_at(strand.position) and _rng.randf() < _style.cable_by_vine_share:
			_cable_by_strand(strand.position, strand.bridge_end())
	for vine in vines:
		if _style_at(vine.position) and _rng.randf() < _style.cable_by_vine_share * 0.6:
			_cable_by_vine(vine.position, vine.length)


static func _wants(style: MazeStyle) -> bool:
	return style.wall_vent_share + style.culvert_share + style.outlet_share + style.drain_share + style.manhole_share \
		+ style.clutter_share + style.cable_share + style.cable_by_vine_share + style.wall_cable_share > 0.0


## Whether `cell` is in a square section's halls (and its style, `_style`, set).
func _in_a_section(cell: Vector2i) -> bool:
	var ring := _maze.ring_of(cell)
	if ring < 1 or ring > _maze.rings or ring > _maze.styles.size() or _maze.entrances.has(cell) or _maze.solid.has(cell):
		return false
	if not _zones.is_empty() and not _zones.has(ring):
		return false
	_style = _maze.styles[ring - 1]
	# (each section its own numbers, so that it comes out the same whichever others are laid out)
	if not _rngs.has(ring):
		var made := RandomNumberGenerator.new()
		made.seed = hash("props/%d/%d" % [_maze.maze_seed, ring])
		_rngs[ring] = made
	_rng = _rngs[ring]
	return not _style.round_section


func _style_at(point: Vector3) -> bool:
	return _in_a_section(_maze.cell_at(point))


## Within two cells of a gate into or out of its section.
func _by_a_gate(cell: Vector2i) -> bool:
	var ring := _maze.ring_of(cell)
	var gates: Array[Vector2i] = []
	if ring - 1 < _maze.gates.size():
		for way: Array in _maze.gates[ring - 1]:
			gates.append(way[0])
	if ring - 1 < _maze.exits.size():
		gates.append(_maze.exits[ring - 1][0])
	for gate in gates:
		if maxi(absi(gate.x - cell.x), absi(gate.y - cell.y)) <= 2:
			return true
	return false


## The props on the face (cell, step): a vent, a culvert, an outlet, a cable
## along it, a heap against it, each as the style's shares say, where there is
## room (none if not).
func _dress_face(cell: Vector2i, step: Vector2i, near_gate: bool) -> void:
	var s := Vector3(step.x, 0.0, step.y)
	var out := -s
	var side := Vector3(-s.z, 0.0, s.x)
	var foot := _maze.world(cell) + s * (Maze.CELL * 0.5 - _maze.wall_thick(cell, step) * 0.5)
	var top := _maze.wall_height(cell, step)
	# (the step of ledge along the wall's foot, if it has one: vents stay under it)
	var under_ledge := top
	if _style.mezzanine_height > 0.0 and not _maze.ring_wall(cell, step):
		under_ledge = _style.mezzanine_height
	var room := Maze.CELL * 0.5 - 1.0
	if _rng.randf() < _style.wall_vent_share:
		var is_round := _rng.randf() < 0.35
		# (made for the walls' giant scale: most a couple of metres across, now and then a great duct)
		var big := _rng.randf_range(3.2, 5.0) if _rng.randf() < 0.2 else _rng.randf_range(1.3, 2.4)
		var half := 0.6 * big
		var tall := (0.55 if is_round else 0.4) * big
		var high := _rng.randf_range(1.6 + tall, maxf(1.7 + tall, minf(under_ledge - 1.0 - tall, 10.0)))
		var along := _rng.randf_range(-room, room)
		var at := _on_face(foot, out, side, along, high - tall, high + tall, half)
		if at.is_finite():
			_put(Prop.ROUND_VENT if is_round else Prop.VENT, at + Vector3.UP * tall, out, Vector3.ONE * big)
	if _rng.randf() < _style.culvert_share and not near_gate:
		var big := _rng.randf_range(1.2, 2.0)
		var along := _rng.randf_range(-room, room)
		var at := _on_face(foot, out, side, along, 0.0, 1.4 * big, 1.1 * big, 3.0)
		if at.is_finite():
			_put(Prop.CULVERT, at, out, Vector3.ONE * big)
			_puddle(at + out * _rng.randf_range(1.2, 1.8) * big, _rng.randf_range(1.4, 2.4) * big)
	if _rng.randf() < _style.outlet_share:
		var big := _rng.randf_range(0.7, 1.4)
		var high := _rng.randf_range(1.2, minf(4.5, under_ledge - 1.0))
		var along := _rng.randf_range(-room, room)
		var at := _on_face(foot, out, side, along, high - 0.3, high + 0.3, 0.4, 1.5)
		if at.is_finite():
			at += Vector3.UP * 0.3
			var piece := _put(Prop.OUTLET, at, out, Vector3.ONE * big)
			piece.drips = _rng.randf() < _style.outlet_drip_share
			# (rust run down the wall under it, and a puddle at the foot)
			var long := high - 0.1
			_put(Prop.STAIN, at - Vector3.UP * 0.12 * big + out * 0.015, out, Vector3(_rng.randf_range(0.45, 0.8) * big, long, 1.0))
			_puddle(Vector3(at.x, _maze.ground_height(at), at.z) + out * _rng.randf_range(0.5, 0.9), _rng.randf_range(0.8, 1.6))
	if _rng.randf() < _style.wall_cable_share:
		_cable_along(foot, out, side, under_ledge)
	if _rng.randf() < _style.clutter_share and not near_gate:
		_heap(foot, out, side, room)


## A point on the face of the wall whose nominal foot is `foot` (the middle of
## the face on the ground, looking `out`), `along` it and `low` up: found where
## the stone really is (a ledge's step, a pier), with the face flat over `half`
## either side, from `low` to `high`, open in front of it for `clear` metres,
## and nothing there yet. INF if not.
func _on_face(foot: Vector3, out: Vector3, side: Vector3, along: float, low: float, high: float, half: float, clear := 2.0) -> Vector3:
	var base := foot + side * along
	var d := _face_out(base, out, (low + high) * 0.5)
	if is_nan(d):
		return Vector3.INF
	for corner: Vector2 in [Vector2(-half, low + 0.05), Vector2(half, low + 0.05), Vector2(-half, high), Vector2(half, high)]:
		var other := _face_out(foot + side * (along + corner.x), out, corner.y)
		if is_nan(other) or absf(other - d) > 0.05:
			return Vector3.INF
	if _solid(base + out * (d + clear) + Vector3.UP * (low + 0.5)):
		return Vector3.INF
	var at := base + out * d + Vector3.UP * low
	var flat := Rect2(Vector2(at.x, at.z), Vector2.ZERO).expand(Vector2(at.x, at.z) + Vector2(side.x, side.z) * half).expand(Vector2(at.x, at.z) - Vector2(side.x, side.z) * half)
	flat = flat.expand(Vector2(at.x, at.z) + Vector2(out.x, out.z) * 0.6).grow(0.3)
	if not _free(flat):
		return Vector3.INF
	return at


## How far out from `base` along `out` the face of the stone is at `high`: the
## first stone met coming back to it from the hall (NAN if there is none within
## reach, or the way there is in stone).
func _face_out(base: Vector3, out: Vector3, high: float) -> float:
	var reach := 4.0
	var p := base + Vector3.UP * high
	if _solid(p + out * reach):
		return NAN
	var open := reach
	var d := reach
	while d > -2.0:
		d -= 0.25
		if _solid(p + out * d):
			# (closer, between the open point and this)
			var stone := d
			for k in 5:
				var mid := (stone + open) * 0.5
				if _solid(p + out * mid):
					stone = mid
				else:
					open = mid
			return (stone + open) * 0.5
		open = d
	return NAN


## A prop piece of `kind` at `at`, its +Z looking `out`, sized `big`.
func _put(kind: int, at: Vector3, out: Vector3, big: Vector3, yaw := 0.0, tilt := Basis.IDENTITY) -> MazePiece:
	var basis := Basis(Vector3.UP, atan2(out.x, out.z) + yaw) * tilt
	return _layout.add_piece(MazePiece.Kind.PROP, Transform3D(basis.scaled_local(big), at), {"prop": kind})


func _puddle(at: Vector3, wide: float) -> void:
	at.y = _maze.ground_height(at)
	if _solid(at + Vector3.UP * 0.3):
		return
	# (the mesh's water is under half of it: the rest a ring of wet mud)
	wide *= 1.7
	_put(Prop.PUDDLE, at, Vector3(cos(_rng.randf() * TAU), 0.0, sin(_rng.randf() * TAU)), Vector3(wide, 1.0, wide * _rng.randf_range(0.6, 1.0)))


## A drain grate by the foot of a wall, and a manhole cover out in the hall.
func _dress_floor(cell: Vector2i, near_gate: bool) -> void:
	if _rng.randf() < _style.drain_share:
		var steps: Array[Vector2i] = []
		for step: Vector2i in Maze.STEPS:
			if _maze.blocked(cell, step):
				steps.append(step)
		if not steps.is_empty():
			var step := steps[_rng.randi() % steps.size()]
			var s := Vector3(step.x, 0.0, step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var foot := _maze.world(cell) + s * (Maze.CELL * 0.5 - _maze.wall_thick(cell, step) * 0.5) + side * _rng.randf_range(-5.0, 5.0)
			var d := _face_out(foot, -s, 0.3)
			if not is_nan(d):
				var at := foot - s * (d + _rng.randf_range(0.5, 0.8))
				at.y = _maze.ground_height(at)
				if _free(Rect2(Vector2(at.x, at.z) - Vector2(0.8, 0.8), Vector2(1.6, 1.6))) and not _solid(at + Vector3.UP * 0.3 - s * 0.6):
					_put(Prop.DRAIN, at, -s, Vector3.ONE * _rng.randf_range(0.9, 1.2))
					if _rng.randf() < 0.5:
						_puddle(at + side * _rng.randf_range(-0.4, 0.4), _rng.randf_range(1.0, 2.0))
	if _rng.randf() < _style.manhole_share and not near_gate:
		var at := _maze.world(cell) + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0))
		at.y = _maze.ground_height(at)
		# (out in the hall: clear of the walls all round)
		for k in 8:
			var a := k * TAU / 8.0
			if _solid(at + Vector3(cos(a), 0.0, sin(a)) * 2.0 + Vector3.UP * 0.5):
				return
		if not _free(Rect2(Vector2(at.x, at.z) - Vector2(1.0, 1.0), Vector2(2.0, 2.0))):
			return
		var turn := Vector3(cos(_rng.randf() * TAU), 0.0, sin(_rng.randf() * TAU))
		if _rng.randf() < 0.2:
			# (pushed half off its hole: the black shaft showing, the cover tipped on its rim)
			_put(Prop.HOLE, at, turn, Vector3.ONE)
			var off := turn.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * 0.55
			_put(Prop.MANHOLE, at + off + Vector3.UP * 0.02, turn, Vector3.ONE, 0.0, Basis(Vector3.RIGHT, _rng.randf_range(0.04, 0.09)))
		else:
			_put(Prop.MANHOLE, at, turn, Vector3.ONE)


## A heap of boxes and barrels against the face: side by side along it, now and
## then a box stood on another, a barrel fallen over in front.
func _heap(foot: Vector3, out: Vector3, side: Vector3, room: float) -> void:
	var count := _rng.randi_range(mini(_style.clutter_heap_size.x, _style.clutter_heap_size.y), maxi(_style.clutter_heap_size.x, _style.clutter_heap_size.y))
	if count <= 0:
		return
	# What is in it, and how much wall it takes.
	var things: Array = []
	var long := 0.0
	for i in count:
		var barrel := _rng.randf() < _style.clutter_barrel_share
		var fallen := barrel and _rng.randf() < 0.25
		var big := _rng.randf_range(0.95, 1.05) if barrel else _rng.randf_range(0.8, 1.4)
		var wide := (BARREL.x * 2.0 * big + 0.05) if barrel and not fallen else (0.0 if fallen else big * _rng.randf_range(0.95, 1.3))
		things.append([barrel, fallen, big, wide])
		long += wide + 0.06
	var along := _rng.randf_range(-room + long * 0.5, room - long * 0.5) if room > long * 0.5 else 0.0
	var middle := _on_face(foot, out, side, along, 0.0, 1.4, long * 0.5 + 0.3, 4.0)
	if not middle.is_finite():
		return
	var d := (middle - foot).dot(out)
	var cursor := along - long * 0.5
	var lean := _rng.randf_range(-0.12, 0.12)
	for thing: Array in things:
		var barrel: bool = thing[0]
		var fallen: bool = thing[1]
		var big: float = thing[2]
		var wide: float = thing[3]
		var at := foot + side * (cursor + wide * 0.5) + out * d
		cursor += wide + 0.06
		if fallen:
			# (lying in front of the heap, rolled a little way out)
			var lie := foot + side * (along + _rng.randf_range(-long * 0.5, long * 0.5)) + out * (d + _rng.randf_range(1.0, 1.7))
			lie.y = _maze.ground_height(lie) + BARREL.x * big
			var roll := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * Basis(Vector3.FORWARD, PI * 0.5)
			_put(Prop.BARREL, lie, side, Vector3.ONE * big, 0.0, roll)
			continue
		at.y = _maze.ground_height(at)
		if barrel:
			_put(Prop.BARREL, at + out * (BARREL.x * big + 0.04), out, Vector3.ONE * big, _rng.randf_range(0.0, TAU))
			continue
		var size := Vector3(wide, big * _rng.randf_range(0.75, 1.0), big * _rng.randf_range(0.85, 1.0))
		_put(Prop.CRATE, at + out * (size.z * 0.5 + 0.04), out, size, lean + _rng.randf_range(-0.1, 0.1))
		if size.y < 1.25 and _rng.randf() < 0.5:
			# (a smaller box left on top, askew)
			var small := size * _rng.randf_range(0.6, 0.85)
			_put(Prop.CRATE, at + out * (size.z * 0.5 + 0.04) + side * _rng.randf_range(-0.1, 0.1) + Vector3.UP * size.y, out, small, _rng.randf_range(-0.5, 0.5))
		elif _rng.randf() < 0.3:
			# (or one set down in front of it)
			var front := size * _rng.randf_range(0.55, 0.8)
			_put(Prop.CRATE, at + out * (size.z + front.z * 0.5 + 0.1) + side * _rng.randf_range(-0.2, 0.2), out, front, _rng.randf_range(-0.6, 0.6))
	var c := foot + side * along + out * (d + 1.0)
	_add_heap(Vector2(c.x, c.z), long * 0.5 + 0.8)
	var flat := Rect2(Vector2(c.x, c.z), Vector2.ZERO).grow(long * 0.5 + 0.5)
	_take(flat)


# --- Cables -------------------------------------------------------------------

## A cable across the hall from the face (cell, -step) to the far side, high up:
## snapped now and then, a dead lamp hanging from some.
func _cable_across(cell: Vector2i, step: Vector2i) -> void:
	var far := _far_side(cell, step)
	if far == Vector2i(-1, -1):
		return
	var low := minf(_maze.wall_height(cell, -step), _maze.wall_height(far, step)) - 2.0
	var range_of := _style.cable_height_range
	var h_a := minf(_rng.randf_range(range_of.x, range_of.y), low)
	var h_b := clampf(h_a + _rng.randf_range(-2.5, 2.5), range_of.x * 0.8, low)
	var along := _rng.randf_range(-0.4, 0.4) * Maze.CELL
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var foot_a := _maze.world(cell) - s * (Maze.CELL * 0.5 - _maze.wall_thick(cell, -step) * 0.5) + side * along
	var foot_b := _maze.world(far) + s * (Maze.CELL * 0.5 - _maze.wall_thick(far, step) * 0.5) + side * (along + _rng.randf_range(-3.0, 3.0))
	var d_a := _face_out(foot_a, s, h_a)
	var d_b := _face_out(foot_b, -s, h_b)
	if is_nan(d_a) or is_nan(d_b):
		return
	var a := foot_a + s * d_a + Vector3.UP * h_a
	var b := foot_b - s * d_b + Vector3.UP * h_b
	_wire(a, b, a.distance_to(b) * _rng.randf_range(0.05, 0.13), true)


## A cable beside a vine strung from `a` to `b` (its buttress end first), in
## among it: from the wall a little along from each of its ends, now and then
## crossing it in the middle.
func _cable_by_strand(a: Vector3, b: Vector3) -> void:
	var across := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var side := across.cross(Vector3.UP)
	var way := 1.0 if _rng.randf() < 0.5 else -1.0
	var off_a := way * _rng.randf_range(1.8, 3.0)
	var off_b := off_a if _rng.randf() < 0.6 else -off_a * _rng.randf_range(0.5, 1.0)
	var h_a := a.y + _rng.randf_range(-1.5, 1.0)
	var h_b := b.y + _rng.randf_range(-1.0, 1.5)
	# (the walls behind its ends, found from about where they are: its buttress
	# end stands out from its wall, its far end is held on the wall itself)
	var from_a := Vector3(a.x, 0.0, a.z) - across * MazeFeatures.BUTTRESS.y + side * off_a
	var from_b := Vector3(b.x, 0.0, b.z) + side * off_b
	var d_a := _face_out(from_a, across, h_a)
	var d_b := _face_out(from_b, -across, h_b)
	if is_nan(d_a) or is_nan(d_b):
		return
	var p := from_a + across * d_a + Vector3.UP * h_a
	var q := from_b - across * d_b + Vector3.UP * h_b
	_wire(p, q, p.distance_to(q) * _rng.randf_range(0.08, 0.16), false)


## A cable's end hanging beside a vine hung from `top`, `long` metres: from the
## wall the vine hangs by, a little along it.
func _cable_by_vine(top: Vector3, long: float) -> void:
	# (which way the wall is: the nearest stone level with the vine's top)
	var best := INF
	var wall := Vector3.ZERO
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		for k in 16:
			if _solid(top + way * (0.2 * (k + 1)) + Vector3.DOWN * 0.3):
				if 0.2 * (k + 1) < best:
					best = 0.2 * (k + 1)
					wall = way
				break
	if wall == Vector3.ZERO:
		return
	var side := wall.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var high := top.y - _rng.randf_range(0.3, 2.0)
	var from := Vector3(top.x, 0.0, top.z) + side * _rng.randf_range(0.6, 1.4)
	var d := _face_out(from, -wall, high)
	if is_nan(d):
		return
	var at := from - wall * d + Vector3.UP * high
	var hang := minf(long * _rng.randf_range(0.35, 0.8), high - 2.8)
	if hang < 1.0:
		return
	_layout.add_piece(MazePiece.Kind.WIRE, Transform3D(Basis.IDENTITY, at), {"to": at - wall + side * 0.3, "sag": 0.0, "tails": Vector2(hang, 0.0)})


## A cable looped along the face on brackets, a few spans of it, sagging between.
func _cable_along(foot: Vector3, out: Vector3, side: Vector3, under_ledge: float) -> void:
	var high := under_ledge - _rng.randf_range(1.2, 2.2) if under_ledge < 20.0 else _rng.randf_range(5.0, 10.0)
	var spans := _rng.randi_range(2, 4)
	var span := _rng.randf_range(2.5, 3.8)
	var start := _rng.randf_range(-Maze.CELL * 0.5 + 1.0, Maze.CELL * 0.5 - 1.0 - spans * span)
	var points: Array[Vector3] = []
	for k in spans + 1:
		var along := start + k * span
		var h := high + _rng.randf_range(-0.15, 0.15)
		var d := _face_out(foot + side * along, out, h)
		if is_nan(d):
			break
		points.append(foot + side * along + out * (d + 0.08) + Vector3.UP * h)
	if points.size() < 2:
		return
	for k in points.size() - 1:
		# (each bracket's span sags its own way)
		_layout.add_piece(MazePiece.Kind.WIRE, Transform3D(Basis.IDENTITY, points[k]), {"to": points[k + 1], "sag": _rng.randf_range(0.25, 0.7)})


## A cable piece from `a` to `b`: snapped (its ends hanging) or with a lamp, as
## the style says, if `across` a hall.
func _wire(a: Vector3, b: Vector3, sag: float, across: bool) -> void:
	var settings := {"to": b, "sag": sag}
	if across and _rng.randf() < _style.snapped_cable_share:
		var span := a.distance_to(b)
		var t_a := minf(span * _rng.randf_range(0.35, 0.8), a.y - 3.0)
		var t_b := minf(span * _rng.randf_range(0.2, 0.6), b.y - 3.0)
		settings["tails"] = Vector2(maxf(t_a, 0.5), maxf(t_b, 0.0))
	elif across and _rng.randf() < _style.cable_lamp_share:
		settings["lamp"] = true
	_layout.add_piece(MazePiece.Kind.WIRE, Transform3D(Basis.IDENTITY, a), settings)


## The cell on the far side of the hall from `cell`, going the `across` way (as
## MazeFeatures has it): the first with a wall that way, no more than two cells over.
func _far_side(cell: Vector2i, across: Vector2i) -> Vector2i:
	var at := cell
	for i in 2:
		if _maze.blocked(at, across):
			return at if _maze.ring_of(at) == _maze.ring_of(cell) and not _maze.entrances.has(at) else Vector2i(-1, -1)
		at += across
	return Vector2i(-1, -1)


# --- What is where ------------------------------------------------------------

func _hash_boxes(layout: MazeLayout) -> void:
	for kind: MazePiece.Kind in [MazePiece.Kind.WALL, MazePiece.Kind.PIER, MazePiece.Kind.TERRACE]:
		for piece in layout.pieces(kind):
			var t := piece.box_transform()
			var half := piece.box_size() * 0.5
			var area := _area_of(t, half)
			var entry := [t.affine_inverse(), half]
			for key in _squares_of(area, BOX_SQUARE):
				if not _boxes.has(key):
					_boxes[key] = []
				(_boxes[key] as Array).append(entry)


## The ground a box (half size `half`, standing on `t`) covers, x and z.
static func _area_of(t: Transform3D, half: Vector3) -> Rect2:
	var area := Rect2(Vector2(t.origin.x, t.origin.z), Vector2.ZERO)
	for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
		var p: Vector3 = t * corner
		area = area.expand(Vector2(p.x, p.z))
	return area


static func _squares_of(area: Rect2, square: float) -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for sx in range(floori(area.position.x / square), floori(area.end.x / square) + 1):
		for sz in range(floori(area.position.y / square), floori(area.end.y / square) + 1):
			keys.append(Vector2i(sx, sz))
	return keys


## Whether a point is in stone (a wall, a pier, a terrace).
func _solid(p: Vector3) -> bool:
	for entry: Array in _boxes.get(Vector2i(floori(p.x / BOX_SQUARE), floori(p.z / BOX_SQUARE)), []):
		var local: Vector3 = (entry[0] as Transform3D) * p
		var half: Vector3 = entry[1]
		if absf(local.x) <= half.x and absf(local.z) <= half.z and local.y >= 0.0 and local.y <= half.y * 2.0:
			return true
	return false


## The ways up are kept clear: ivy, the terraces and buttresses, the pipes and
## their platforms, the beams the vines hang from.
func _keep_clear_of_ways_up(layout: MazeLayout) -> void:
	for piece in layout.pieces(MazePiece.Kind.IVY):
		var t := Transform3D(piece.transform.basis.orthonormalized(), piece.position)
		var area := _area_of(t * Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.2)), Vector3(piece.width * 0.5 + 1.2, 0.0, 1.6))
		_take(area)
	for piece in layout.pieces(MazePiece.Kind.TERRACE):
		_take(_area_of(piece.box_transform(), piece.box_size() * 0.5).grow(1.2))
	for piece in layout.pieces(MazePiece.Kind.PIER):
		if not piece.ledge and piece.position.y > 0.5:
			_take(_area_of(piece.box_transform(), piece.box_size() * 0.5).grow(1.0))
	for piece in layout.pieces(MazePiece.Kind.PIPE):
		var t := Transform3D(piece.transform.basis.orthonormalized(), piece.position)
		_take(_area_of(t, Vector3(2.2, 0.0, piece.length * 0.5 + 2.5)))


func _take(area: Rect2) -> void:
	for key in _squares_of(area, BOX_SQUARE):
		if not _taken.has(key):
			_taken[key] = []
		(_taken[key] as Array).append(area)


## Whether nothing has taken any of `area` yet (and then it is taken).
func _free(area: Rect2) -> bool:
	var keys := _squares_of(area, BOX_SQUARE)
	for key in keys:
		for other: Rect2 in _taken.get(key, []):
			if other.intersects(area):
				return false
	_take(area)
	return true


func _add_heap(at: Vector2, radius: float) -> void:
	var key := Vector2i(floori(at.x / BOX_SQUARE), floori(at.y / BOX_SQUARE))
	if not _heaps.has(key):
		_heaps[key] = []
	(_heaps[key] as Array).append([at, radius])


## Whether a point (x and z) is within `margin` of a heap of boxes and barrels
## (for putting other things down clear of them).
func near_heap(point: Vector3, margin: float) -> bool:
	var at := Vector2(point.x, point.z)
	var key := Vector2i(floori(at.x / BOX_SQUARE), floori(at.y / BOX_SQUARE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for heap: Array in _heaps.get(key + Vector2i(dx, dz), []):
				if at.distance_to(heap[0]) < float(heap[1]) + margin:
					return true
	return false


# --- Making them --------------------------------------------------------------

## Makes the props and cables of a layout's pieces, under this node.
func realize(layout: MazeLayout) -> void:
	# [prop, square] -> [[transform, colour]]
	var placed := {}
	# square -> SurfaceTool of the cables there; [lamp transforms]; drips [transform, custom]
	var cable_tools := {}
	var lamp_spots := {}
	var drip_spots := {}
	body = StaticBody3D.new()
	body.name = "Solid"
	for piece in layout.pieces(MazePiece.Kind.PROP):
		var kind: int = piece.prop
		var t := piece.transform
		var key := [kind, _square(t.origin)]
		if not placed.has(key):
			placed[key] = []
		(placed[key] as Array).append([t, _tint(kind, t.origin)])
		counts[kind] = counts.get(kind, 0) + 1
		if kind == Prop.CRATE or kind == Prop.BARREL:
			_collide(kind, t)
			_add_heap(Vector2(t.origin.x, t.origin.z), maxf(t.basis.get_scale().x, t.basis.get_scale().z) * 0.7)
		if kind == Prop.OUTLET and piece.drips:
			var big := t.basis.get_scale().x
			var lip := t.origin + t.basis.orthonormalized().z * OUTLET_REACH * big - Vector3.UP * OUTLET_RADIUS * big * 0.8
			var fall := maxf(lip.y - 0.05, 0.3)
			var dkey := _square(lip)
			if not drip_spots.has(dkey):
				drip_spots[dkey] = []
			for n in 2:
				var phase := absf(sin(lip.x * 12.9898 + lip.z * 78.233 + n * 3.1))
				(drip_spots[dkey] as Array).append([Transform3D(Basis.IDENTITY, lip), Color(fall, phase, 1.8 + phase * 1.6 + n * 0.7, 0.0)])
			drips += 2
	for piece in layout.pieces(MazePiece.Kind.WIRE):
		var a := piece.position
		var b := piece.bridge_end()
		var key := _square((a + b) * 0.5)
		if not cable_tools.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			cable_tools[key] = tool
		var lamp_at := cable(cable_tools[key], a, b, piece.sag, piece.tails, piece.lamp)
		cables += 1
		if piece.tails != Vector2.ZERO:
			snapped += 1
		if lamp_at.is_finite():
			if not lamp_spots.has(key):
				lamp_spots[key] = []
			(lamp_spots[key] as Array).append([Transform3D(Basis(Vector3.UP, a.x * 0.37 + a.z * 0.11).scaled(Vector3.ONE * LAMP_SIZE), lamp_at), Color.WHITE])
			lamps += 1
	for key: Array in placed:
		_draw(mesh(key[0]), placed[key], key[0])
	for key: Vector2i in lamp_spots:
		_draw(lamp_mesh(), lamp_spots[key], -1)
	for key: Vector2i in cable_tools:
		var cables_here := MeshInstance3D.new()
		cables_here.mesh = (cable_tools[key] as SurfaceTool).commit()
		cables_here.material_override = material(false)
		cables_here.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_far(cables_here, WIRE_FAR)
		add_child(cables_here)
	for key: Vector2i in drip_spots:
		_drips(drip_spots[key])
	# (all its shapes in before it goes into the world)
	add_child(body)


## Which square a point is drawn in.
static func _square(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / SQUARE), floori(p.z / SQUARE))


## How far off it is drawn (none in the editor, which is seen from far over it).
static func _far(shown: GeometryInstance3D, far: float) -> void:
	if Engine.is_editor_hint():
		return
	shown.visibility_range_end = far
	shown.visibility_range_end_margin = 12.0
	shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## A MultiMesh of `mesh` at each of `spots` ([transform, colour]).
func _draw(shape: Mesh, spots: Array, kind: int) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = shape
	multi.instance_count = spots.size()
	for i in spots.size():
		multi.set_instance_transform(i, spots[i][0])
		multi.set_instance_color(i, spots[i][1])
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = multi
	var see_through := kind == Prop.PUDDLE or kind == Prop.STAIN
	shown.material_override = puddle_material() if kind == Prop.PUDDLE else material(see_through)
	# (only the boxes and barrels are big enough for their shadows to be seen)
	if kind != Prop.CRATE and kind != Prop.BARREL:
		shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var on_floor := kind in [Prop.DRAIN, Prop.MANHOLE, Prop.PUDDLE, Prop.HOLE]
	_far(shown, FLOOR_FAR if on_floor else FAR)
	add_child(shown)


## A box or barrel to bump into.
func _collide(kind: int, t: Transform3D) -> void:
	var big := t.basis.get_scale()
	var turn := t.basis.orthonormalized()
	var collider := CollisionShape3D.new()
	if kind == Prop.CRATE:
		var box := BoxShape3D.new()
		box.size = big
		collider.shape = box
		collider.transform = Transform3D(turn, t.origin + turn.y * big.y * 0.5)
	else:
		var drum := CylinderShape3D.new()
		drum.radius = BARREL.x * big.x
		drum.height = BARREL.y * big.y
		collider.shape = drum
		collider.transform = Transform3D(turn, t.origin + turn.y * BARREL.y * big.y * 0.5)
	body.add_child(collider)
	solid_shapes += 1


## A colour for a prop of `kind` at `p`, chosen by where it is (the same in every copy).
static func _tint(kind: int, p: Vector3) -> Color:
	var pick := absf(sin(p.x * 12.9898 + p.z * 78.233 + p.y * 3.7) * 43758.5453)
	pick -= floorf(pick)
	match kind:
		Prop.BARREL:
			# (old drums: rust, a faded blue, army olive, grey; all gone dull)
			var paints := [Color(0.38, 0.22, 0.16), Color(0.24, 0.3, 0.34), Color(0.3, 0.32, 0.22), Color(0.36, 0.36, 0.34), Color(0.34, 0.26, 0.19)]
			return paints[int(pick * paints.size()) % paints.size()]
		Prop.CRATE:
			return Color.WHITE.lerp(Color(0.72, 0.7, 0.66), pick)
		_:
			return Color.WHITE.lerp(Color(0.8, 0.76, 0.7), pick)


## Drops falling from outlets: each swells at the lip and falls to the ground,
## all in their shader (custom data: how far it falls, its phase, its period).
func _drips(spots: Array) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = drop_mesh()
	multi.instance_count = spots.size()
	var bounds := AABB()
	for i in spots.size():
		var t: Transform3D = spots[i][0]
		multi.set_instance_transform(i, t)
		multi.set_instance_custom_data(i, spots[i][1])
		var fall: float = (spots[i][1] as Color).r
		var span := AABB(t.origin - Vector3(0.1, fall + 0.1, 0.1), Vector3(0.2, fall + 0.2, 0.2))
		bounds = span if i == 0 else bounds.merge(span)
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = multi
	shown.material_override = drip_material()
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (they fall below where they are: seen so)
	shown.custom_aabb = AABB(bounds.position - Vector3.ONE, bounds.size + Vector3.ONE * 2.0)
	_far(shown, DRIP_FAR)
	add_child(shown)


## For the maze editor: a piece drawn as the game draws it, in its own space.
static func shown(piece: MazePiece) -> Node3D:
	var drawn := MeshInstance3D.new()
	if piece.kind == MazePiece.Kind.WIRE:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var end := piece.get_node(^"End") as Node3D
		var lamp_at := cable(tool, Vector3.ZERO, end.position, piece.sag, piece.tails, piece.lamp)
		drawn.mesh = tool.commit()
		drawn.material_override = material(false)
		if lamp_at.is_finite():
			var lamp := MeshInstance3D.new()
			lamp.mesh = lamp_mesh()
			lamp.material_override = material(false)
			lamp.position = lamp_at
			lamp.scale = Vector3.ONE * LAMP_SIZE
			drawn.add_child(lamp)
		return drawn
	drawn.mesh = mesh(piece.prop)
	drawn.material_override = puddle_material() if piece.prop == Prop.PUDDLE else material(piece.prop == Prop.STAIN)
	return drawn


# --- Materials ----------------------------------------------------------------

## The props' material: their own vertex colours (times each one's tint), dull.
static func material(see_through: bool) -> StandardMaterial3D:
	var key := "clear" if see_through else "solid"
	if not _materials.has(key):
		var made := StandardMaterial3D.new()
		made.vertex_color_use_as_albedo = true
		made.roughness = 0.95
		made.metallic_specular = 0.25
		if see_through:
			made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			made.cull_mode = BaseMaterial3D.CULL_DISABLED
			made.roughness = 1.0
			made.metallic_specular = 0.0
		_materials[key] = made
	return _materials[key]


## Standing water: dark and glossy, its edge fading out (alpha in its vertex colours).
static func puddle_material() -> StandardMaterial3D:
	if not _materials.has("puddle"):
		var made := StandardMaterial3D.new()
		made.vertex_color_use_as_albedo = true
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# (a dull sheen, not a mirror: the sky's glare off a mirror reads as a pale slab)
		made.roughness = 0.3
		made.metallic_specular = 0.3
		_materials["puddle"] = made
	return _materials["puddle"]


const DRIP_SHADER := """
shader_type spatial;
render_mode cull_disabled;

void vertex() {
	// (custom: how far it falls, its phase, its period in seconds)
	float t = fract(TIME / INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.y);
	float swell = smoothstep(0.0, 0.75, t);
	float falling = max(t - 0.75, 0.0) / 0.25;
	VERTEX *= mix(0.25, 1.0, swell) * step(t, 0.985);
	VERTEX.y *= 1.0 + falling * 2.5;
	VERTEX.y -= falling * falling * INSTANCE_CUSTOM.x;
}

void fragment() {
	ALBEDO = vec3(0.5, 0.55, 0.55);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
"""


static func drip_material() -> ShaderMaterial:
	if not _materials.has("drip"):
		if _drip_shader == null:
			_drip_shader = Shader.new()
			_drip_shader.code = DRIP_SHADER
		var made := ShaderMaterial.new()
		made.shader = _drip_shader
		_materials["drip"] = made
	return _materials["drip"]


# --- Meshes -------------------------------------------------------------------

## How far an outlet's pipe stands out of the wall, and how wide it is, at scale 1.
const OUTLET_REACH := 0.45
const OUTLET_RADIUS := 0.13

## Colours: iron gone to rust, darker iron, wet black, weathered wood, concrete.
const RUST := Color(0.24, 0.18, 0.14)
const IRON := Color(0.13, 0.13, 0.12)
const BLACK := Color(0.025, 0.025, 0.022)
const WOOD := Color(0.29, 0.26, 0.21)
const WOOD_DARK := Color(0.19, 0.17, 0.14)
const CONCRETE := Color(0.21, 0.2, 0.18)


## The mesh of a prop (made once).
static func mesh(kind: int) -> ArrayMesh:
	if not _meshes.has(kind):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			Prop.VENT: _vent(tool)
			Prop.ROUND_VENT: _round_vent(tool)
			Prop.CULVERT: _culvert(tool)
			Prop.OUTLET: _outlet(tool)
			Prop.DRAIN: _drain(tool)
			Prop.MANHOLE: _manhole(tool)
			Prop.PUDDLE: _puddle_shape(tool)
			Prop.STAIN: _stain(tool)
			Prop.CRATE: _crate(tool)
			Prop.BARREL: _barrel(tool)
			Prop.HOLE: _hole(tool)
		_meshes[kind] = tool.commit()
	return _meshes[kind]


## A louvred vent on a wall, 1.2 by 0.8 m round its middle, standing out along +Z.
static func _vent(tool: SurfaceTool) -> void:
	var w := 0.6
	var h := 0.4
	_box(tool, Vector3(0, h, 0.04), Vector3(w * 2.0 + 0.16, 0.1, 0.08), RUST)
	_box(tool, Vector3(0, -h, 0.04), Vector3(w * 2.0 + 0.16, 0.1, 0.08), RUST.darkened(0.1))
	for x: float in [-w, w]:
		_box(tool, Vector3(x, 0, 0.04), Vector3(0.1, h * 2.0, 0.08), RUST.darkened(0.05))
	_face(tool, Vector3(0, 0, 0.012), Vector3(w, 0, 0), Vector3(0, h, 0), BLACK)
	# (the louvres, slanted down and out; one hanging loose)
	for k in 6:
		var y := -h + 0.1 + k * (h * 2.0 - 0.2) / 5.0
		var turn := Basis(Vector3.RIGHT, 0.75 if k != 3 else 1.25)
		_box(tool, Vector3(0, y, 0.045), Vector3(w * 2.0 - 0.08, 0.11, 0.012), RUST.lightened(0.06) if k % 2 == 0 else RUST, turn)


## A round vent: a ring of iron with a cross of bars and a ring of bar inside.
static func _round_vent(tool: SurfaceTool) -> void:
	var r := 0.55
	_face_disc(tool, Vector3(0, 0, 0.012), r * 0.9, 16, BLACK)
	_ring_z(tool, Vector3.ZERO, r * 0.85, r, 0.1, 18, IRON.lerp(RUST, 0.6))
	_ring_z(tool, Vector3.ZERO, r * 0.42, r * 0.5, 0.06, 14, RUST)
	_box(tool, Vector3(0, 0, 0.04), Vector3(r * 1.8, 0.06, 0.05), RUST.darkened(0.1))
	_box(tool, Vector3(0, 0, 0.04), Vector3(0.06, r * 1.8, 0.05), RUST.darkened(0.1))


## A culvert at a wall's foot: an opening 1.6 wide and 1.2 high, black behind
## heavy bars, with a concrete lip and sill.
static func _culvert(tool: SurfaceTool) -> void:
	var w := 0.8
	var h := 1.2
	_face(tool, Vector3(0, h * 0.5, 0.012), Vector3(w, 0, 0), Vector3(0, h * 0.5, 0), BLACK)
	_box(tool, Vector3(0, h + 0.12, 0.09), Vector3(w * 2.0 + 0.5, 0.24, 0.18), CONCRETE)
	for x: float in [-w - 0.13, w + 0.13]:
		_box(tool, Vector3(x, h * 0.5, 0.09), Vector3(0.26, h, 0.18), CONCRETE.darkened(0.06))
	_box(tool, Vector3(0, 0.06, 0.2), Vector3(w * 2.0 + 0.5, 0.12, 0.4), CONCRETE.darkened(0.2))
	for k in 7:
		var x := -w + 0.12 + k * (w * 2.0 - 0.24) / 6.0
		_box(tool, Vector3(x, h * 0.5 + 0.06, 0.07), Vector3(0.05, h - 0.12, 0.05), IRON.lerp(RUST, 0.5))
	_box(tool, Vector3(0, h * 0.62, 0.07), Vector3(w * 2.0, 0.06, 0.06), RUST)
	# (slime down the sill)
	_face(tool, Vector3(0, 0.122, 0.2), Vector3(w * 0.9, 0, 0), Vector3(0, 0, 0.19), Color(0.13, 0.15, 0.09), Vector3.UP)


## A small pipe out of a wall along +Z, with a flange against it, dark inside.
static func _outlet(tool: SurfaceTool) -> void:
	var r := OUTLET_RADIUS
	_ring_z(tool, Vector3.ZERO, r, r * 1.9, 0.05, 12, IRON.lerp(RUST, 0.5))
	_tube_z(tool, Vector3.ZERO, r, 0.0, OUTLET_REACH, 12, RUST)
	_ring_z(tool, Vector3(0, 0, OUTLET_REACH - 0.04), r * 0.75, r * 1.08, 0.04, 12, RUST.darkened(0.15))
	_face_disc(tool, Vector3(0, 0, OUTLET_REACH - 0.03), r * 0.78, 12, BLACK)


## A drain grate in the floor, 0.9 by 0.5, its long side along X.
static func _drain(tool: SurfaceTool) -> void:
	var w := 0.45
	var d := 0.25
	_face(tool, Vector3(0, 0.008, 0), Vector3(w, 0, 0), Vector3(0, 0, d), BLACK, Vector3.UP)
	_box(tool, Vector3(0, 0.02, -d - 0.04), Vector3(w * 2.0 + 0.16, 0.04, 0.08), CONCRETE.darkened(0.15))
	_box(tool, Vector3(0, 0.02, d + 0.04), Vector3(w * 2.0 + 0.16, 0.04, 0.08), CONCRETE.darkened(0.15))
	for x: float in [-w - 0.04, w + 0.04]:
		_box(tool, Vector3(x, 0.02, 0), Vector3(0.08, 0.04, d * 2.0), CONCRETE.darkened(0.15))
	for k in 9:
		var x := -w + 0.05 + k * (w * 2.0 - 0.1) / 8.0
		_box(tool, Vector3(x, 0.025, 0), Vector3(0.035, 0.03, d * 2.0), IRON.lerp(RUST, 0.4))


## A manhole cover, 0.9 m across, a little proud of the ground, with raised rings
## and bars across it, rusted.
static func _manhole(tool: SurfaceTool) -> void:
	var r := 0.45
	_disc_y(tool, Vector3(0, 0.03, 0), r, 18, IRON.lerp(RUST, 0.45))
	_tube_y(tool, Vector3.ZERO, r, 0.0, 0.03, 18, IRON)
	_ring_y(tool, Vector3(0, 0.03, 0), r * 0.82, r * 0.9, 0.012, 18, RUST.lightened(0.05))
	_ring_y(tool, Vector3(0, 0.03, 0), r * 0.36, r * 0.44, 0.012, 14, RUST.lightened(0.05))
	for k in 4:
		var turn := Basis(Vector3.UP, k * PI / 4.0)
		_box(tool, Vector3(0, 0.036, 0), Vector3(r * 1.6, 0.012, 0.04), RUST.lightened(0.08), turn)
	# (the frame round it, set in the ground)
	_ring_y(tool, Vector3(0, 0.0, 0), r + 0.01, r + 0.12, 0.02, 18, CONCRETE.darkened(0.25))


## The open shaft a manhole cover was pushed off: a black hole in a frame.
static func _hole(tool: SurfaceTool) -> void:
	var r := 0.45
	_disc_y(tool, Vector3(0, 0.006, 0), r, 18, BLACK)
	_ring_y(tool, Vector3(0, 0.0, 0), r, r + 0.12, 0.025, 18, CONCRETE.darkened(0.25))


## A puddle, an uneven patch about a metre across (at scale 1) in a ring of wet,
## dark mud twice as wide, both fading out at their edges.
static func _puddle_shape(tool: SurfaceTool) -> void:
	var around := 24
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var rim: Array[float] = []
	for k in around:
		rim.append(rng.randf_range(0.6, 1.0))
	# (rings out from the middle: [how far out, as a share of the rim; colour])
	var rings := [
		[0.0, Color(0.035, 0.04, 0.035, 0.9)],
		[0.42, Color(0.035, 0.04, 0.035, 0.85)],
		[0.55, Color(0.07, 0.065, 0.055, 0.6)],
		[0.8, Color(0.08, 0.072, 0.06, 0.3)],
		[1.0, Color(0.09, 0.08, 0.065, 0.0)],
	]
	for r in rings.size() - 1:
		for k in around:
			var k2 := (k + 1) % around
			var points: Array = []
			var colours: Array = []
			for pair: Array in [[r, k], [r, k2], [r + 1, k2], [r + 1, k]]:
				var a := float(pair[1]) * TAU / around
				var reach: float = rings[pair[0]][0] * rim[pair[1]] * 0.5
				# (the water's own edge wobbles more than the mud's)
				points.append(Vector3(cos(a) * reach, 0.012, sin(a) * reach))
				colours.append(rings[pair[0]][1])
			_tri_c(tool, [points[0], points[1], points[2]], [colours[0], colours[1], colours[2]], Vector3.UP)
			_tri_c(tool, [points[0], points[2], points[3]], [colours[0], colours[2], colours[3]], Vector3.UP)


## A rust stain run down a wall: from its top (the origin) down 1 m, 1 m wide, at
## scale 1; darkest at the top and middle, fading out at its sides and foot.
static func _stain(tool: SurfaceTool) -> void:
	var rows := 6
	var cols := 4
	for j in rows:
		for i in cols:
			var corners: Array = []
			var colours: Array = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var u := float(c.x) / cols - 0.5
				var v := float(c.y) / rows
				# (narrowing as it runs down)
				var x := u * (1.0 - v * 0.55)
				corners.append(Vector3(x, -v, 0.0))
				var strength := (1.0 - absf(u) * 2.0) * (1.0 - v * v) * 0.75
				colours.append(Color(0.2, 0.13, 0.08, clampf(strength, 0.0, 1.0)))
			_tri_c(tool, [corners[0], corners[1], corners[2]], [colours[0], colours[1], colours[2]], Vector3.BACK)
			_tri_c(tool, [corners[0], corners[2], corners[3]], [colours[0], colours[2], colours[3]], Vector3.BACK)


## A crate of planks, 1 m each way at scale 1, standing on its origin: battens
## round each face's edges, a brace across, the planks' seams dark.
static func _crate(tool: SurfaceTool) -> void:
	var h := 0.5
	_box(tool, Vector3(0, h, 0), Vector3.ONE * (1.0 - 0.06), WOOD)
	# (seams between planks: dark bands across the sides)
	for k in 3:
		var y := 0.25 + k * 0.25
		_box(tool, Vector3(0, y, 0), Vector3(0.95, 0.02, 0.95), WOOD_DARK.darkened(0.3))
	var b := 0.08
	for x: float in [-h + b * 0.5, h - b * 0.5]:
		for z: float in [-h + b * 0.5, h - b * 0.5]:
			_box(tool, Vector3(x, h, z), Vector3(b, 1.0, b), WOOD_DARK)
	for y: float in [b * 0.5, 1.0 - b * 0.5]:
		for x: float in [-h + b * 0.5, h - b * 0.5]:
			_box(tool, Vector3(x, y, 0), Vector3(b, b, 1.0), WOOD_DARK)
		for z: float in [-h + b * 0.5, h - b * 0.5]:
			_box(tool, Vector3(0, y, z), Vector3(1.0, b, b), WOOD_DARK)
	# (a brace across the front and the back)
	for z: float in [-h, h]:
		_box(tool, Vector3(0, h, z), Vector3(1.25, 0.08, 0.03), WOOD.darkened(0.12), Basis(Vector3.BACK, 0.78))


## An oil drum, standing on its origin: its side with two rolled ribs, its lid a
## little sunk in a rim, its paint (the tint) worn to rust round the rims.
static func _barrel(tool: SurfaceTool) -> void:
	var r := BARREL.x
	var high := BARREL.y
	var paint := Color(0.78, 0.78, 0.76)
	var worn := Color(0.5, 0.4, 0.33)
	_tube_y(tool, Vector3.ZERO, r, 0.0, 0.05, 16, worn)
	_tube_y(tool, Vector3.ZERO, r, 0.05, high - 0.05, 16, paint)
	_tube_y(tool, Vector3.ZERO, r, high - 0.05, high, 16, worn)
	for y: float in [high * 0.33, high * 0.66]:
		_tube_y(tool, Vector3.ZERO, r + 0.014, y - 0.02, y + 0.02, 16, paint.darkened(0.2))
	_ring_y(tool, Vector3(0, high, 0), r - 0.03, r + 0.005, 0.02, 16, worn)
	_disc_y(tool, Vector3(0, high - 0.015, 0), r - 0.03, 16, paint.darkened(0.25))
	_box(tool, Vector3(r * 0.5, high, 0.0), Vector3(0.06, 0.02, 0.06), worn.darkened(0.3))


## An old lamp hanging from a cable: a short cord, a cap, an enamelled shade and
## a dead bulb, hanging down from its origin.
static func lamp_mesh() -> ArrayMesh:
	if not _meshes.has("lamp"):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tube_y(tool, Vector3(0, -0.45, 0), 0.012, 0.0, 0.45, 5, BLACK)
		_tube_y(tool, Vector3(0, -0.55, 0), 0.04, 0.0, 0.1, 8, IRON)
		var enamel := Color(0.27, 0.31, 0.27)
		# (a cone, wide at its foot)
		var around := 12
		for k in around:
			var a0 := k * TAU / around
			var a1 := (k + 1) * TAU / around
			var t0 := Vector3(cos(a0) * 0.05, -0.55, sin(a0) * 0.05)
			var t1 := Vector3(cos(a1) * 0.05, -0.55, sin(a1) * 0.05)
			var b0 := Vector3(cos(a0) * 0.24, -0.74, sin(a0) * 0.24)
			var b1 := Vector3(cos(a1) * 0.24, -0.74, sin(a1) * 0.24)
			var n0 := Vector3(cos(a0), 0.9, sin(a0)).normalized()
			var n1 := Vector3(cos(a1), 0.9, sin(a1)).normalized()
			_tri_n(tool, [t0, b1, b0], [n0, n1, n0], enamel)
			_tri_n(tool, [t0, t1, b1], [n0, n1, n1], enamel)
			# (its inside, dark)
			_tri_n(tool, [t0, b0, b1], [-n0, -n0, -n1], enamel.darkened(0.6))
			_tri_n(tool, [t0, b1, t1], [-n0, -n1, -n1], enamel.darkened(0.6))
		_tube_y(tool, Vector3(0, -0.72, 0), 0.06, 0.0, 0.1, 8, Color(0.5, 0.5, 0.46))
		_disc_y(tool, Vector3(0, -0.72, 0), 0.06, 8, Color(0.45, 0.45, 0.42), true)
		_meshes["lamp"] = tool.commit()
	return _meshes["lamp"]


static func drop_mesh() -> ArrayMesh:
	if not _meshes.has("drop"):
		var drop := SphereMesh.new()
		drop.radius = 0.03
		drop.height = 0.08
		drop.radial_segments = 6
		drop.rings = 3
		var made := ArrayMesh.new()
		made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, drop.get_mesh_arrays())
		_meshes["drop"] = made
	return _meshes["drop"]


## An old cable from `a` to `b` (in the space being drawn into), sagging `sag`
## in the middle: a black tube on a ceramic insulator at each end. Snapped
## (`tails`), it is only the two ends hanging down from where it was held, as
## long as they say. Where a lamp hangs from it, if `lamp` (INF if none).
static func cable(tool: SurfaceTool, a: Vector3, b: Vector3, sag: float, tails: Vector2, lamp: bool) -> Vector3:
	var pick := absf(sin(a.x * 3.1 + a.z * 7.7 + b.y))
	var radius := 0.022 + 0.014 * pick
	var colour := BLACK.lerp(Color(0.16, 0.14, 0.12), pick)
	var porcelain := Color(0.5, 0.49, 0.45)
	for end: Vector3 in [a, b]:
		if end == b and tails != Vector2.ZERO and tails.y <= 0.0:
			continue
		_box(tool, end + Vector3.UP * 0.03, Vector3(0.09, 0.14, 0.09), porcelain)
	var points := PackedVector3Array()
	if tails == Vector2.ZERO:
		var steps := 16
		for k in steps + 1:
			var t := float(k) / steps
			points.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
		_strand(tool, points, radius, colour)
		if lamp:
			return a.lerp(b, 0.5) + Vector3.DOWN * sag
		return Vector3.INF
	# (snapped: each end hangs from where it was held, out a little towards where it went, then down)
	for end: Array in [[a, b, tails.x], [b, a, tails.y]]:
		var long: float = end[2]
		if long <= 0.0:
			continue
		var from: Vector3 = end[0]
		var toward: Vector3 = end[1] - from
		toward.y = 0.0
		toward = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.RIGHT
		var curl := toward.cross(Vector3.UP)
		var tail := PackedVector3Array()
		var steps := 12
		for k in steps + 1:
			var t := float(k) / steps
			var reach := sin(t * PI * 0.5) * minf(long * 0.3, 1.6)
			tail.append(from + toward * reach + Vector3.DOWN * long * t + curl * sin(t * 5.0 + pick * 6.0) * 0.12 * t)
		_strand(tool, tail, radius, colour)
	return Vector3.INF


## A tube of four sides along `points`.
static func _strand(tool: SurfaceTool, points: PackedVector3Array, radius: float, colour: Color) -> void:
	var sides := 4
	var rings: Array = []
	for k in points.size():
		var along := (points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]).normalized()
		var x := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
		var y := along.cross(x).normalized()
		var ring: Array = []
		for s in sides:
			var a := s * TAU / sides + PI * 0.25
			var n := x * cos(a) + y * sin(a)
			ring.append([points[k] + n * radius, n])
		rings.append(ring)
	for k in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var p0: Array = rings[k][s]
			var p1: Array = rings[k][s2]
			var p2: Array = rings[k + 1][s2]
			var p3: Array = rings[k + 1][s]
			_tri_n(tool, [p0[0], p1[0], p2[0]], [p0[1], p1[1], p2[1]], colour)
			_tri_n(tool, [p0[0], p2[0], p3[0]], [p0[1], p2[1], p3[1]], colour)


# --- Shapes -------------------------------------------------------------------

## A triangle with a normal at each corner, wound to face the way they point.
static func _tri_n(tool: SurfaceTool, p: Array, n: Array, colour: Color) -> void:
	var facing: Vector3 = (n[0] as Vector3) + n[1] + n[2]
	var order := [0, 1, 2]
	# (Godot's front faces are the ones whose (q - p) x (r - p) points away from the viewer)
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(facing) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		tool.set_color(colour)
		tool.set_normal(n[i])
		tool.add_vertex(p[i])


## A flat triangle facing `normal`, with a colour at each corner.
static func _tri_c(tool: SurfaceTool, p: Array, colours: Array, normal: Vector3) -> void:
	var order := [0, 1, 2]
	if ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0]).dot(normal) > 0.0:
		order = [0, 2, 1]
	for i: int in order:
		tool.set_color(colours[i])
		tool.set_normal(normal)
		tool.add_vertex(p[i])


## A flat rectangle round `at`, its half sides `u` and `v`, facing `normal` (+Z unless given).
static func _face(tool: SurfaceTool, at: Vector3, u: Vector3, v: Vector3, colour: Color, normal := Vector3.BACK) -> void:
	var c := [colour, colour, colour]
	_tri_c(tool, [at - u - v, at + u - v, at + u + v], c, normal)
	_tri_c(tool, [at - u - v, at + u + v, at - u + v], c, normal)


## A box `size` round `at`, turned by `turn` about its middle.
static func _box(tool: SurfaceTool, at: Vector3, size: Vector3, colour: Color, turn := Basis.IDENTITY) -> void:
	var h := size * 0.5
	for axis in 3:
		for sign_of: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sign_of
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = h[(axis + 1) % 3]
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = h[(axis + 2) % 3]
			var middle := n * h[axis]
			var corners := [middle - u - v, middle + u - v, middle + u + v, middle - u + v]
			for i in 4:
				corners[i] = at + turn * (corners[i] as Vector3)
			var normal := turn * n
			var c := [colour, colour, colour]
			_tri_c(tool, [corners[0], corners[1], corners[2]], c, normal)
			_tri_c(tool, [corners[0], corners[2], corners[3]], c, normal)


## The side of an upright tube round `foot`, from `from` to `to` up.
static func _tube_y(tool: SurfaceTool, foot: Vector3, radius: float, from: float, to: float, around: int, colour: Color) -> void:
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		var n0 := Vector3(cos(a0), 0, sin(a0))
		var n1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := foot + n0 * radius + Vector3.UP * from
		var p1 := foot + n1 * radius + Vector3.UP * from
		var p2 := foot + n1 * radius + Vector3.UP * to
		var p3 := foot + n0 * radius + Vector3.UP * to
		_tri_n(tool, [p0, p1, p2], [n0, n1, n1], colour)
		_tri_n(tool, [p0, p2, p3], [n0, n1, n0], colour)


## A disc facing up (or down) at `at`.
static func _disc_y(tool: SurfaceTool, at: Vector3, radius: float, around: int, colour: Color, down := false) -> void:
	var n := Vector3.DOWN if down else Vector3.UP
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		_tri_c(tool, [at, at + Vector3(cos(a0), 0, sin(a0)) * radius, at + Vector3(cos(a1), 0, sin(a1)) * radius], [colour, colour, colour], n)


## A flat ring facing up, `inner` to `outer`, standing `high` (with its sides).
static func _ring_y(tool: SurfaceTool, at: Vector3, inner: float, outer: float, high: float, around: int, colour: Color) -> void:
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var top := at + Vector3.UP * high
		var c := [colour, colour, colour]
		_tri_c(tool, [top + d0 * inner, top + d1 * inner, top + d1 * outer], c, Vector3.UP)
		_tri_c(tool, [top + d0 * inner, top + d1 * outer, top + d0 * outer], c, Vector3.UP)
	_tube_y(tool, at, outer, 0.0, high, around, colour.darkened(0.15))


## The side of a tube along +Z round `at`, from `from` to `to`.
static func _tube_z(tool: SurfaceTool, at: Vector3, radius: float, from: float, to: float, around: int, colour: Color) -> void:
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		var n0 := Vector3(cos(a0), sin(a0), 0)
		var n1 := Vector3(cos(a1), sin(a1), 0)
		var p0 := at + n0 * radius + Vector3.BACK * from
		var p1 := at + n1 * radius + Vector3.BACK * from
		var p2 := at + n1 * radius + Vector3.BACK * to
		var p3 := at + n0 * radius + Vector3.BACK * to
		_tri_n(tool, [p0, p1, p2], [n0, n1, n1], colour)
		_tri_n(tool, [p0, p2, p3], [n0, n1, n0], colour)


## A disc facing +Z at `at`.
static func _face_disc(tool: SurfaceTool, at: Vector3, radius: float, around: int, colour: Color) -> void:
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		_tri_c(tool, [at, at + Vector3(cos(a0), sin(a0), 0) * radius, at + Vector3(cos(a1), sin(a1), 0) * radius], [colour, colour, colour], Vector3.BACK)


## A flat ring facing +Z, `inner` to `outer`, standing `deep` out from `at` (with its rim).
static func _ring_z(tool: SurfaceTool, at: Vector3, inner: float, outer: float, deep: float, around: int, colour: Color) -> void:
	var front := at + Vector3.BACK * deep
	for k in around:
		var a0 := k * TAU / around
		var a1 := (k + 1) * TAU / around
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		var c := [colour, colour, colour]
		_tri_c(tool, [front + d0 * inner, front + d1 * inner, front + d1 * outer], c, Vector3.BACK)
		_tri_c(tool, [front + d0 * inner, front + d1 * outer, front + d0 * outer], c, Vector3.BACK)
	_tube_z(tool, at, outer, 0.0, deep, around, colour.darkened(0.15))
