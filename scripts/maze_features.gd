@tool
class_name MazeFeatures
extends Node3D
## The ways up in the maze. Against the walls stand terraces of the same stone,
## like steps for something far bigger than a boy: a lower one and, often, an
## upper one set back above it. Ivy grows thick enough to climb up their faces
## (IvyClimb), and now and then on up the wall above to its top, where he can walk
## along it as far as the next pier. Vines hang from beams of stone out over their
## edges (Vine) to swing on, and rope bridges (RopeBridge) cross the halls between
## terraces facing each other, and between wall tops.
##
## `lay_out` chooses them from the maze's seed, so every copy of the game in a room
## has the same, as pieces of a MazeLayout; `realize` makes the real things from a
## layout's pieces, as they were laid out or as changed by hand. Faces are the
## sides of cells that have a wall: (cell, step), the wall being the one the
## `step` way, its face looking back into the cell.

## Heights of the lower and upper terraces, and how far each stands out from
## the wall's face.
const LOWER := Vector2(6.5, 3.0)
const UPPER := Vector2(13.0, 1.8)
## (How many of each there are is the ring's MazeStyle's to say.)
## How high the end of a vine hangs over the ground (or terrace) under it: out
## of reach standing, so that it takes a jump to catch.
const VINE_CLEAR := 2.6
## And how far out from the face of what it hangs from, to swing clear of it.
const VINE_OUT := 1.1
## The beam of stone a vine hangs from: how thick, and how far past the vine it
## reaches.
const BEAM := Vector2(0.8, 0.4)
## How far out from the face of a wall a vine hung from its top hangs.
const WALL_VINE_OUT := 0.7
## How far along the wall from a patch of ivy a vine hung from its top hangs (far
## enough that climbing the one he does not catch the other), and how wide ivy up
## a bare wall is.
const VINE_BESIDE := 3.2
const WALL_IVY := 5.0
## (No higher than this, even up the clearing's great wall: its leaves are many.)
const IVY_MOST := 30.0
## The buttress a strung vine is held on at one end: how wide, and how deep out
## from the wall.
const BUTTRESS := Vector2(2.6, 1.8)

## What is in the maze, for tests and tools: where each terrace stands, and each
## IvyClimb, Vine and RopeBridge made.
var terraces: Array = []
var climbs: Array[IvyClimb] = []
var vines: Array[Vine] = []
var bridges: Array[RopeBridge] = []
var strands: Array[VineStrand] = []
## Where the terraces stand, in the world's x and z (for keeping grass off them).
var footprints: Array[Rect2] = []

var _maze: Maze
var _layout: MazeLayout
var _rng := RandomNumberGenerator.new()
## The style of the ring being laid out.
var _style: MazeStyle
var _taken := {}


## Lays out the ways up of `maze` as pieces of `layout`: terraces, ivy, vines and bridges.
static func lay_out(layout: MazeLayout, maze: Maze) -> void:
	var placer := MazeFeatures.new()
	placer._place(layout, maze)
	placer.free()


## Makes the real ivy, vines and bridges of a layout's pieces, under this node.
func realize(layout: MazeLayout) -> void:
	for piece in layout.pieces(MazePiece.Kind.TERRACE):
		terraces.append(piece.position)
		var t := piece.box_transform()
		var half := piece.box_size() * 0.5
		var area := Rect2(Vector2(t.origin.x, t.origin.z), Vector2.ZERO)
		for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
			var p: Vector3 = t * corner
			area = area.expand(Vector2(p.x, p.z))
		footprints.append(area)
	for piece in layout.pieces(MazePiece.Kind.IVY):
		var ivy := IvyClimb.new()
		ivy.height = piece.length
		ivy.width = piece.width
		ivy.transform = Transform3D(piece.transform.basis.orthonormalized(), piece.position)
		add_child(ivy)
		climbs.append(ivy)
	for piece in layout.pieces(MazePiece.Kind.VINE):
		var vine := Vine.new()
		vine.length = piece.length
		vine.position = piece.position
		add_child(vine)
		vines.append(vine)
	for piece in layout.pieces(MazePiece.Kind.BRIDGE):
		var bridge := RopeBridge.new()
		bridge.from = piece.position
		bridge.to = piece.bridge_end()
		add_child(bridge)
		bridges.append(bridge)
	for piece in layout.pieces(MazePiece.Kind.STRAND):
		var strand := VineStrand.new()
		strand.from = piece.position
		strand.to = piece.bridge_end()
		add_child(strand)
		strands.append(strand)


func _place(layout: MazeLayout, plan: Maze) -> void:
	_maze = plan
	_layout = layout
	_rng.seed = hash("features/%d" % plan.maze_seed)
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		# (in the rings, as their styles say: the clearing's walls are left bare, and
		# so are the entrances)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		for step: Vector2i in Maze.STEPS:
			if not plan.blocked(cell, step) or _taken.has([cell, step]):
				continue
			if _rng.randf() >= _style.terraces:
				# (or ivy up the bare wall from the ground, part of the way, and now and
				# then a vine hanging from its top: climb the ivy, swing from the vine)
				var hangs := _rng.randf() < _style.wall_vines
				if hangs or _rng.randf() < _style.wall_ivy:
					_taken[[cell, step]] = true
					var high := minf(_face_top(cell, step) * _rng.randf_range(_style.ivy_reach.x, _style.ivy_reach.y), IVY_MOST)
					# (with a ledge along the walls, a curtain of it hanging from the ledge's
					# edge to the ground instead: he climbs it onto the ledge)
					var off_wall := 0.0
					if _style.ledge > 0.0:
						high = _style.ledge * MazeBuilder.WALL_HEIGHT
						off_wall = _style.ledge_depth
					var ivy_along := _rng.randf_range(-0.3, 0.3) * Maze.CELL
					_climb(_edge(cell, step, off_wall, ivy_along), step, high, WALL_IVY)
					if hangs:
						var beside := ivy_along + (VINE_BESIDE if ivy_along < 0.0 else -VINE_BESIDE)
						var out := WALL_VINE_OUT + off_wall
						_vine(cell, step, out, beside, high, VINE_CLEAR, false)
				continue
			var upper := _rng.randf() < _style.upper_terraces
			var along := _rng.randf_range(-0.2, 0.2) * Maze.CELL
			var across := -step
			# A terrace across the hall too (however wide it is), and a bridge between them.
			var far := _far_side(cell, across)
			var paired := _rng.randf() < _style.bridges and far != NOWHERE and not _taken.has([far, across])
			_terrace(cell, step, upper or paired, along)
			if paired:
				# (along that wall runs the other way)
				_terrace(far, across, true, -along)
				var a := _edge(cell, step, UPPER.y, along) + Vector3.UP * UPPER.x
				var b := _edge(far, across, UPPER.y, -along) + Vector3.UP * UPPER.x
				_bridge(a, b)

	# Bridges from wall top to wall top, across halls with an inner wall each side
	# (from the cell at one side of the hall to the one at the other).
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not plan.blocked(cell, -step) or plan.ring_wall(cell, -step):
				continue
			var far := _far_side(cell, step)
			if far != NOWHERE and not plan.ring_wall(far, step):
				if _rng.randf() < _style.top_bridges:
					var a := _edge(far, step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * MazeBuilder.WALL_HEIGHT
					var b := _edge(cell, -step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * MazeBuilder.WALL_HEIGHT
					_bridge(a, b)


	# Vines strung across halls from wall to wall, sagging (from the cell at one
	# side of the hall to the one at the other).
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not plan.blocked(cell, -step):
				continue
			var far := _far_side(cell, step)
			if far == NOWHERE or _taken.has([cell, -step]) or _rng.randf() >= _style.strands:
				continue
			var low := minf(_face_top(cell, -step), _face_top(far, step))
			var high := low * _rng.randf_range(_style.strand_reach.x, _style.strand_reach.y)
			var along := _rng.randf_range(-0.4, 0.4) * Maze.CELL
			# (held at one end on top of a buttress of stone against the wall, with ivy up
			# its face, so that he can climb to it, step onto it and walk it)
			_taken[[cell, -step]] = true
			var s := Vector3(-step.x, 0.0, -step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var size := side.abs() * BUTTRESS.x + s.abs() * BUTTRESS.y + Vector3.UP * high
			_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, -step, BUTTRESS.y * 0.5, along)), {"size": size})
			_climb(_edge(cell, -step, BUTTRESS.y, along), -step, high, BUTTRESS.x * 0.8)
			var a := _edge(cell, -step, BUTTRESS.y, along) + Vector3.UP * high
			# (along that wall runs the other way)
			var b := _edge(far, step, 0.05, -along + _rng.randf_range(-3.0, 3.0)) + Vector3.UP * (high + _rng.randf_range(-1.5, 1.5))
			_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b})


## How high the face (cell, step) goes: its wall's height, or a rampart's.
func _face_top(cell: Vector2i, step: Vector2i) -> float:
	return _maze.inner_height(_maze.ring_of(cell + step)) if _maze.solid.has(cell + step) else _maze.wall_height(cell, step)


const NOWHERE := Vector2i(-1, -1)


## The cell on the far side of the hall from `cell`, going the `across` way: the
## first with a wall that way, if the hall is open up to it and no more than
## two cells across (NOWHERE if not: a bridge any longer sags too far). `cell`
## itself in a hall one cell wide.
func _far_side(cell: Vector2i, across: Vector2i) -> Vector2i:
	var at := cell
	for i in 2:
		if _maze.blocked(at, across):
			return at if _maze.ring_of(at) == _maze.ring_of(cell) and not _maze.entrances.has(at) else NOWHERE
		at += across
	return NOWHERE


func _thick(cell: Vector2i, step: Vector2i) -> float:
	return _maze.wall_thick(cell, step)


## A point on the ground in front of the face (cell, step), `out` metres out
## from the wall's face and `along` metres along it from the middle.
func _edge(cell: Vector2i, step: Vector2i, out: float, along: float) -> Vector3:
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	return _maze.world(cell) + s * (Maze.CELL * 0.5 - _thick(cell, step) * 0.5 - out) + side * along


## The way out of a face, as a Basis whose +Z points out of the wall (as a Ladder wants).
static func _facing_out(step: Vector2i) -> Basis:
	var z := -Vector3(step.x, 0.0, step.y)
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


func _terrace(cell: Vector2i, step: Vector2i, upper: bool, along: float) -> void:
	_taken[[cell, step]] = true
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var length := Maze.CELL * 0.85
	# (a box long along the wall, deep out from it)
	var size_for := func(long: float, deep: float, high: float) -> Vector3:
		return (side.abs() * long + s.abs() * deep) + Vector3.UP * high
	_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, step, LOWER.y * 0.5, 0.0)), {"size": size_for.call(length, LOWER.y, LOWER.x)})
	# Ivy up its face, somewhere along it.
	var ivy_along := _rng.randf_range(-0.3, 0.3) * length
	_climb(_edge(cell, step, LOWER.y, ivy_along), step, LOWER.x)
	if _rng.randf() < _style.terrace_vines:
		_vine(cell, step, LOWER.y + VINE_OUT, _away_from(ivy_along, length), LOWER.x, VINE_CLEAR)
	if not upper:
		return
	var upper_length := Maze.CELL * 0.5
	_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, step, UPPER.y * 0.5, along)), {"size": size_for.call(upper_length, UPPER.y, UPPER.x)})
	# Ivy from the lower terrace up the upper's face, away from the one below.
	var up_along := along + (_rng.randf_range(0.1, 0.35) if ivy_along < along else _rng.randf_range(-0.35, -0.1)) * upper_length
	_climb(_edge(cell, step, UPPER.y, up_along) + Vector3.UP * LOWER.x, step, UPPER.x - LOWER.x)
	if _rng.randf() < _style.terrace_vines:
		# (out past the lower terrace's edge, over the hall: jumped to from that edge)
		_vine(cell, step, LOWER.y + 1.0, along + _away_from(up_along - along, upper_length), UPPER.x, LOWER.x + 1.6)
	# And now and then on up the wall to its top (stood off it by the cornice).
	if not _maze.ring_wall(cell, step) and _rng.randf() < _style.ivy_to_top:
		var top_along := along + _rng.randf_range(-0.3, 0.3) * upper_length
		_climb(_edge(cell, step, MazeBuilder.CORNICE.x, top_along) + Vector3.UP * UPPER.x, step, MazeBuilder.WALL_HEIGHT - UPPER.x)


func _climb(at: Vector3, step: Vector2i, high: float, wide := 1.8) -> void:
	_layout.add_piece(MazePiece.Kind.IVY, Transform3D(_facing_out(step), at), {"length": high, "width": wide})


## A vine `out` from the face (cell, step) and `along` it, down to `end` over the
## ground: hanging from a beam of stone out of the wall whose top is `top` high,
## or (`beam` false) from the top of the wall itself, `top` high.
func _vine(cell: Vector2i, step: Vector2i, out: float, along: float, top: float, end: float, beam := true) -> void:
	if not beam:
		_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, _edge(cell, step, out, along) + Vector3.UP * top), {"length": top - end})
		return
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var reach := out + BEAM.y
	var size := side.abs() * BEAM.x + s.abs() * reach + Vector3.UP * BEAM.x
	_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, reach * 0.5, along) + Vector3.UP * (top - BEAM.x)), {"size": size})
	var under := top - BEAM.x
	_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, _edge(cell, step, out, along) + Vector3.UP * under), {"length": under - end})


func _bridge(a: Vector3, b: Vector3) -> void:
	_layout.add_piece(MazePiece.Kind.BRIDGE, Transform3D(Basis.IDENTITY, a), {"to": b})


## Somewhere along a face `length` long for a vine, at least 3 m from the ivy
## at `ivy` (so that climbing the one he does not catch the other).
func _away_from(ivy: float, length: float) -> float:
	var at := _rng.randf_range(-0.42, 0.42) * length
	if absf(at - ivy) < 3.0:
		at = ivy + (3.0 if ivy < 0.0 else -3.0)
	return at
