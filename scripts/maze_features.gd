@tool
class_name MazeFeatures
extends Node3D
## The ways up in the maze. Against the walls stand terraces of the same stone,
## like steps for something far bigger than a boy: a lower one and, often, an
## upper one set back above it. Ivy grows thick enough to climb up their faces
## (IvyClimb), and now and then on up the wall above to its top, where he can walk
## along it as far as the next pier. Vines hang from beams of stone out over their
## edges (Vine) to swing on, and rope bridges (RopeBridge) cross the halls between
## terraces facing each other, and between wall tops. Sewer pipes (SewerPipe) go
## through walls high up, a platform under each mouth with ivy up to it: up one
## side, through the wall ducked, and down the other. And there are places made
## for a grappling hook to catch (GrappleSpots): routes of stone corbels up bare
## walls, an iron ring hanging from each; rings at the lips of ledges; iron
## hooks and old pipes out of the walls to swing from.
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
## The corbel a strung vine is held on at its near end: a short slab of stone set
## into the wall (no pillar to the ground: the user, 2026-10-18), how long along
## the wall, how thick and how far out from it.
const VINE_CORBEL := Vector3(2.2, 0.5, 1.2)

## What is in the maze, for tests and tools: where each terrace stands, and each
## IvyClimb, Vine and RopeBridge made.
var terraces: Array = []
var climbs: Array[IvyClimb] = []
var vines: Array[Vine] = []
var bridges: Array[RopeBridge] = []
var strands: Array[VineStrand] = []
var pipes: Array[SewerPipe] = []
## The grappling hook spots, a GrappleSpots for each square of SPOT_SQUARE metres that has any.
var spots: Array[GrappleSpots] = []
## Where the terraces stand, in the world's x and z (for keeping grass off them).
var footprints: Array[Rect2] = []

var _maze: Maze
var _layout: MazeLayout
var _rng := RandomNumberGenerator.new()
## The style of the ring being laid out.
var _style: MazeStyle
var _taken := {}
## The hook spots are chosen with their own numbers, so that what else is laid
## out is as it was without them.
var _spot_rng := RandomNumberGenerator.new()
## [cell, step] -> how many levels of ledge its face has (see _levels).
var _level_counts := {}
## The lips of the ledges laid out (terraces, platforms, the vines' corbels), for rings:
## [the middle of the top of its front, the way out from it, how long it is along the face].
var _lips: Array = []

## How big the stone corbels of a hook route are: along the wall, out from it, thick.
const CORBEL := Vector3(1.2, 1.4, 0.6)
## How far the corbels of a route are to either side of its line, by turns (so
## that the rope from the one above hangs clear of the one he stands on).
const CORBEL_STAGGER := 1.1
## A ring hangs against a face: its top this far under the top of what it hangs from.
const RING_DROP := 0.14
## The squares the spots are drawn in, metres.
const SPOT_SQUARE := 48.0


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
	for piece in layout.pieces(MazePiece.Kind.PIPE):
		var pipe := SewerPipe.new()
		pipe.length = piece.length
		pipe.wall = piece.width
		pipe.transform = Transform3D(piece.transform.basis.orthonormalized(), piece.position)
		add_child(pipe)
		pipes.append(pipe)
	# The hook spots, a MultiMesh for each square of them.
	var squares := {}
	for piece in layout.pieces(MazePiece.Kind.ANCHOR):
		var key := Vector2i(floori(piece.position.x / SPOT_SQUARE), floori(piece.position.z / SPOT_SQUARE))
		if not squares.has(key):
			var made := GrappleSpots.new()
			made.name = "Spots%d_%d" % [key.x, key.y]
			squares[key] = made
		(squares[key] as GrappleSpots).add(Transform3D(piece.transform.basis.orthonormalized(), piece.position), piece.anchor)
	for key: Vector2i in squares:
		add_child(squares[key])
		spots.append(squares[key])


func _place(layout: MazeLayout, plan: Maze) -> void:
	_maze = plan
	_layout = layout
	_rng.seed = hash("features/%d" % plan.maze_seed)
	_spot_rng.seed = hash("grapple spots/%d" % plan.maze_seed)
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
			if _rng.randf() >= _style.amount(&"terrace_share"):
				# (or ivy up the bare wall from the ground, part of the way, and now and
				# then a vine hanging from its top: climb the ivy, swing from the vine)
				var hangs := _rng.randf() < _style.amount(&"hanging_vine_share")
				if hangs or _rng.randf() < _style.amount(&"wall_ivy_share"):
					_taken[[cell, step]] = true
					var high := minf(_face_top(cell, step) * _rng.randf_range(_style.wall_ivy_height_range.x, _style.wall_ivy_height_range.y), IVY_MOST)
					# (with a ledge along the walls, a curtain of it hanging from the ledge's
					# edge to the ground instead: he climbs it onto the ledge)
					var off_wall := 0.0
					# (only the maze walls have the ledge, not the great walls round the ring)
					var beyond := cell + step
					if _style.mezzanine_height > 0.0 and plan.ring_of(beyond) == ring and not plan.solid.has(beyond):
						high = _style.mezzanine_height
						off_wall = _style.mezzanine_depth
					# (somewhere along the face clear of any wall meeting it)
					var low := -_room(cell, step, -1) + WALL_IVY * 0.5
					var high_along := _room(cell, step, 1) - WALL_IVY * 0.5
					if low > high_along:
						continue
					var ivy_along := clampf(_rng.randf_range(-0.3, 0.3) * Maze.CELL, low, high_along)
					_climb(_edge(cell, step, off_wall, ivy_along), step, high, WALL_IVY)
					if hangs:
						var beside := ivy_along + (VINE_BESIDE if ivy_along < 0.0 else -VINE_BESIDE)
						# (on the wall, well clear of its ends: not tucked into a corner as if hung on a pier)
						beside = clampf(beside, low, high_along)
						var out := WALL_VINE_OUT + off_wall
						_vine(cell, step, out, beside, high, VINE_CLEAR, false)
				continue
			var upper := _rng.randf() < _style.upper_terrace_share
			var along := _rng.randf_range(-0.2, 0.2) * Maze.CELL
			var across := -step
			# A terrace across the hall too (however wide it is), and a bridge between them.
			var far := _far_side(cell, across)
			var paired := _rng.randf() < _style.amount(&"terrace_bridge_share") and far != NOWHERE and not _taken.has([far, across])
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
				if _rng.randf() < _style.amount(&"wall_top_bridge_share"):
					var a := _edge(far, step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * _maze.wall_height(far, step)
					var b := _edge(cell, -step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * _maze.wall_height(cell, -step)
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
			if far == NOWHERE or _taken.has([cell, -step]) or _rng.randf() >= _style.amount(&"tightrope_vine_share"):
				continue
			var low := minf(_face_top(cell, -step), _face_top(far, step))
			var high := low * _rng.randf_range(_style.tightrope_vine_height_range.x, _style.tightrope_vine_height_range.y)
			var along := _rng.randf_range(-0.4, 0.4) * Maze.CELL
			# (held at its near end on a corbel set into the wall, a curtain of ivy
			# hanging from its edge to the ground, so that he can climb to it, step
			# onto it and walk the vine)
			_taken[[cell, -step]] = true
			var s := Vector3(-step.x, 0.0, -step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var size := side.abs() * VINE_CORBEL.x + s.abs() * VINE_CORBEL.z + Vector3.UP * VINE_CORBEL.y
			_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, -step, VINE_CORBEL.z * 0.5, along) + Vector3.UP * (high - VINE_CORBEL.y)), {"size": size})
			_lip(cell, -step, VINE_CORBEL.z, along, high, VINE_CORBEL.x)
			_climb(_edge(cell, -step, VINE_CORBEL.z, along), -step, high, VINE_CORBEL.x * 0.8)
			var a := _edge(cell, -step, VINE_CORBEL.z, along) + Vector3.UP * high
			# (along that wall runs the other way)
			# (on its own length of that wall, not past it where the next cell may be open:
			# tied to the wall, not to the air)
			var b := _edge(far, step, 0.05, clampf(-along + _rng.randf_range(-3.0, 3.0), -Maze.CELL * 0.5 + 1.5, Maze.CELL * 0.5 - 1.5)) + Vector3.UP * (high + _rng.randf_range(-1.5, 1.5))
			_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b})

	# Sewer pipes through the maze walls, high up, between halls on both sides.
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		if _style.amount(&"sewer_pipe_share") <= 0.0:
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other := cell + step
			if not plan.blocked(cell, step) or plan.ring_wall(cell, step) or plan.ring_of(other) != ring \
					or plan.solid.has(other) or plan.entrances.has(other) or _taken.has([cell, step]) or _taken.has([other, -step]):
				continue
			if _rng.randf() < _style.amount(&"sewer_pipe_share"):
				_pipe(cell, step)

	_levels(plan)
	_spots(plan)


## The levels of ledge over the first (MazeStyle.mezzanine_levels): along some
## faces of the maze walls, each level over one that is there, shallower than it;
## ivy from the edge of each down to the one under; rope bridges across halls
## between ledges at the same level.
func _levels(plan: Maze) -> void:
	# [cell, step] -> how many levels its face has.
	var levels := _level_counts
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		if _style.mezzanine_height <= 0.0:
			continue
		for step: Vector2i in Maze.STEPS:
			var beyond := cell + step
			if not plan.blocked(cell, step) or plan.ring_of(beyond) != ring or plan.solid.has(beyond):
				continue
			var count := 1
			while count < _style.mezzanine_levels and _rng.randf() < _style.mezzanine_upper_share:
				count += 1
			levels[[cell, step]] = count
			var room := {-1: _room(cell, step, -1), 1: _room(cell, step, 1)}
			var s := Vector3(step.x, 0.0, step.y)
			var flat_side := Vector3(-s.z, 0.0, s.x)
			var length: float = room[-1] + room[1]
			var middle: float = (room[1] - room[-1]) * 0.5
			for level in range(1, count):
				var high := _level_height(level)
				var deep := _level_depth(level)
				# (a step of the wall standing on the level under it)
				var under := _level_height(level - 1)
				var size := flat_side.abs() * length + s.abs() * deep + Vector3.UP * (high - under)
				_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, deep * 0.5, middle) + Vector3.UP * under), {"size": size, "ledge": true})
				# (ivy from its edge down onto the level under it, somewhere along it)
				if _rng.randf() < _style.amount(&"mezzanine_ivy_share"):
					var along := middle + _rng.randf_range(-0.3, 0.3) * length
					_climb(_edge(cell, step, deep, along) + Vector3.UP * under, step, high - under, WALL_IVY * 0.6)
	# Rope bridges across the halls between ledges at the same level.
	for key: Array in levels:
		var cell: Vector2i = key[0]
		var step: Vector2i = key[1]
		if step.x < 0 or step.y < 0:
			continue
		_style = plan.styles[plan.ring_of(cell) - 1]
		var far := _far_side(cell, -step)
		if far == NOWHERE or not levels.has([far, -step]):
			continue
		for level in mini(levels[key], levels[[far, -step]]):
			if _rng.randf() >= _style.amount(&"mezzanine_bridge_share"):
				continue
			var along := _rng.randf_range(-0.3, 0.3) * Maze.CELL
			var deep := _level_depth(level)
			var high := _level_height(level)
			_bridge(_edge(cell, step, deep, along) + Vector3.UP * high, _edge(far, -step, deep, -along) + Vector3.UP * high)


## How high the top of level `level` is (0 the first), and how deep it is, by the
## style of the ring being laid out.
func _level_height(level: int) -> float:
	return _style.mezzanine_height + level * _style.mezzanine_level_rise


func _level_depth(level: int) -> float:
	return maxf(_style.mezzanine_depth - level * _style.mezzanine_depth_step, 0.6)


## How far a pipe stands out of each face of its wall, and how deep and wide the
## platform under each mouth is (the ivy hangs from its edge).
const PIPE_OUT := 0.8
const PLATFORM := Vector2(1.8, 2.6)
const PLATFORM_THICK := 0.5


## A sewer pipe through the wall on the `step` side of `cell`, with a platform
## under each mouth and ivy from the ground up to its edge: somewhere along the
## wall clear of any wall meeting it at either end, on either side, if there is
## room (none if not).
func _pipe(cell: Vector2i, step: Vector2i) -> void:
	var other := cell + step
	var thick := _thick(cell, step)
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector2i(-step.y, step.x)
	# (how far along it may be from the middle of the face, to keep clear of walls
	# meeting this one at either end)
	var room := {}
	for way: int in [-1, 1]:
		# (the other face runs the other way along the wall)
		room[way] = minf(_room(cell, step, way), _room(other, -step, -way)) - PLATFORM.y * 0.5 - 0.5
	if room[-1] + room[1] < 0.0:
		return
	var along := _rng.randf_range(-room[-1], room[1])
	var high := _maze.wall_height(cell, step) * _style.sewer_pipe_height
	var middle := _edge(cell, step, -thick * 0.5, along) + Vector3.UP * high
	if not _hole(middle, s):
		return
	_taken[[cell, step]] = true
	_taken[[other, -step]] = true
	_layout.add_piece(MazePiece.Kind.PIPE, Transform3D(Basis(Vector3.UP, atan2(s.x, s.z)), middle),
		{"length": thick + PIPE_OUT * 2.0, "width": thick})
	var flat_side := Vector3(-s.z, 0.0, s.x)
	for end: Array in [[cell, step, along], [other, -step, -along]]:
		var size := flat_side.abs() * PLATFORM.y + s.abs() * PLATFORM.x + Vector3.UP * PLATFORM_THICK
		_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(end[0], end[1], PLATFORM.x * 0.5, end[2]) + Vector3.UP * (high - PLATFORM_THICK)), {"size": size})
		_climb(_edge(end[0], end[1], PLATFORM.x, end[2]), end[1], high, PLATFORM.y * 0.7)
		_lip(end[0], end[1], PLATFORM.x, end[2], high, PLATFORM.y)


## Cuts the hole for a pipe through the wall at `middle` (the middle of its floor,
## in the middle of the wall), the wall running across `through`: the wall's run
## is split into the parts either side of it, under it and over it. Whether there
## was a wall there to cut.
func _hole(middle: Vector3, through: Vector3) -> bool:
	var probe := middle + Vector3.UP * SewerPipe.HOLE.y * 0.5
	for piece in _layout.pieces(MazePiece.Kind.WALL):
		if piece.rotation != Vector3.ZERO or not piece.box_has(probe):
			continue
		var size := piece.box_size()
		var foot := piece.position
		# (along the wall: x or z, whichever the pipe does not run along)
		var along := Vector3(1.0, 0.0, 0.0) if absf(through.x) < 0.5 else Vector3(0.0, 0.0, 1.0)
		var long := size.dot(along)
		var start := foot.dot(along) - long * 0.5
		var end := start + long
		var hole_from := middle.dot(along) - SewerPipe.HOLE.x * 0.5
		var hole_to := hole_from + SewerPipe.HOLE.x
		var across := size - along * long
		var base := foot - along * foot.dot(along)
		var settings := {"style": piece.style, "great": piece.great}
		var parts: Array = []
		if hole_from - start > 0.01:
			parts.append([base + along * (start + hole_from) * 0.5, across + along * (hole_from - start)])
		if end - hole_to > 0.01:
			parts.append([base + along * (hole_to + end) * 0.5, across + along * (end - hole_to)])
		var gap := across + along * SewerPipe.HOLE.x
		parts.append([base + along * (hole_from + hole_to) * 0.5, Vector3(gap.x, middle.y, gap.z)])
		var over := middle.y + SewerPipe.HOLE.y
		parts.append([base + along * (hole_from + hole_to) * 0.5 + Vector3.UP * over, Vector3(gap.x, size.y - over, gap.z)])
		piece.get_parent().remove_child(piece)
		piece.free()
		for part: Array in parts:
			var made := settings.duplicate()
			made["size"] = part[1]
			_layout.add_piece(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, part[0]), made)
		return true
	return false


## How far along the face (cell, step) it is clear, from the middle of the face
## the `way` way along it (1 or -1, along the face's side, as _edge has it): to
## the face of a wall meeting it at that end, and the step of ledge along that
## wall's foot, if there is one there.
func _room(cell: Vector2i, step: Vector2i, way: int) -> float:
	var side := Vector2i(-step.y, step.x) * way
	if not _maze.blocked(cell, side):
		return Maze.CELL * 0.5
	var room := Maze.CELL * 0.5 - _maze.wall_thick(cell, side) * 0.5
	var ring := _maze.ring_of(cell)
	if not _maze.ring_wall(cell, side) and ring >= 1 and ring <= _maze.styles.size():
		var style: MazeStyle = _maze.styles[ring - 1]
		if style.mezzanine_height > 0.0:
			room -= style.mezzanine_depth
	return room


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
	_lip(cell, step, LOWER.y, 0.0, LOWER.x, length)
	# Ivy up its face, somewhere along it.
	var ivy_along := _rng.randf_range(-0.3, 0.3) * length
	_climb(_edge(cell, step, LOWER.y, ivy_along), step, LOWER.x)
	if _rng.randf() < _style.amount(&"terrace_vine_share"):
		_vine(cell, step, LOWER.y + VINE_OUT, _away_from(ivy_along, length), LOWER.x, VINE_CLEAR)
	if not upper:
		return
	var upper_length := Maze.CELL * 0.5
	_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, step, UPPER.y * 0.5, along)), {"size": size_for.call(upper_length, UPPER.y, UPPER.x)})
	_lip(cell, step, UPPER.y, along, UPPER.x, upper_length)
	# Ivy from the lower terrace up the upper's face, away from the one below.
	var up_along := along + (_rng.randf_range(0.1, 0.35) if ivy_along < along else _rng.randf_range(-0.35, -0.1)) * upper_length
	_climb(_edge(cell, step, UPPER.y, up_along) + Vector3.UP * LOWER.x, step, UPPER.x - LOWER.x)
	if _rng.randf() < _style.amount(&"terrace_vine_share"):
		# (out past the lower terrace's edge, over the hall: jumped to from that edge)
		_vine(cell, step, LOWER.y + 1.0, along + _away_from(up_along - along, upper_length), UPPER.x, LOWER.x + 1.6)
	# And now and then on up the wall to its top (stood off it by the cornice).
	if not _maze.ring_wall(cell, step) and _rng.randf() < _style.amount(&"ivy_to_wall_top_share"):
		var top_along := along + _rng.randf_range(-0.3, 0.3) * upper_length
		_climb(_edge(cell, step, MazeBuilder.CORNICE.x, top_along) + Vector3.UP * UPPER.x, step, _maze.wall_height(cell, step) - UPPER.x)


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


# --- Grappling hook spots ---

## Notes the lip of a ledge laid out on the face (cell, step): its front `out`
## from the wall's face, `along` it from the middle of the face, its top `top`
## high, `length` long along the face.
func _lip(cell: Vector2i, step: Vector2i, out: float, along: float, top: float, length: float) -> void:
	_lips.append([_edge(cell, step, out, along) + Vector3.UP * top, -Vector3(step.x, 0.0, step.y), length, _maze.ring_of(cell)])


## The grappling hook spots, by each ring's MazeStyle "Grappling hook spots":
## routes of corbels up bare maze walls to their tops, hooks and pipes to swing
## from, and rings at the lips of ledges. (After everything else, with numbers
## of their own, on faces nothing else has taken.)
func _spots(plan: Maze) -> void:
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		_style = plan.styles[ring - 1]
		for step: Vector2i in Maze.STEPS:
			var beyond := cell + step
			if not plan.blocked(cell, step) or plan.ring_wall(cell, step) or plan.ring_of(beyond) != ring \
					or plan.solid.has(beyond) or _taken.has([cell, step]):
				continue
			var pick := _spot_rng.randf()
			if pick < _style.amount(&"grapple_route_share"):
				_route(cell, step)
			elif pick < _style.amount(&"grapple_route_share") + _style.amount(&"grapple_swing_share"):
				_swing_spot(cell, step)
	# Rings at the lips of the ledges: each level along a face, terraces, platforms.
	for key: Array in _level_counts:
		var cell: Vector2i = key[0]
		var step: Vector2i = key[1]
		_style = plan.styles[plan.ring_of(cell) - 1]
		var room := minf(_room(cell, step, -1), _room(cell, step, 1)) - 1.0
		for level in int(_level_counts[key]):
			if _spot_rng.randf() < _style.amount(&"grapple_ring_share") and room > 0.0:
				var along := _spot_rng.randf_range(-room, room) * 0.8
				_ring(_edge(cell, step, _level_depth(level), along) + Vector3.UP * _level_height(level), -Vector3(step.x, 0.0, step.y))
	for lip: Array in _lips:
		_style = plan.styles[int(lip[3]) - 1]
		if _spot_rng.randf() >= _style.amount(&"grapple_ring_share"):
			continue
		var out: Vector3 = lip[1]
		var side := Vector3(-out.z, 0.0, out.x)
		var room: float = maxf(float(lip[2]) * 0.5 - 0.6, 0.0)
		_ring(lip[0] + side * _spot_rng.randf_range(-room, room), out)


## A ring hanging against the front of a ledge whose top front edge is at `lip`
## (`out` the way out from it): the hook bites in its top.
func _ring(lip: Vector3, out: Vector3) -> void:
	_spot(lip + out * GrappleSpots.RING_OUT + Vector3.DOWN * RING_DROP, out, GrappleSpots.Look.RING)


func _spot(at: Vector3, out: Vector3, look: GrappleSpots.Look) -> void:
	var z := out.normalized()
	_layout.add_piece(MazePiece.Kind.ANCHOR, Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), at), {"anchor": look})


## How high the floor in front of the face (cell, step) is: the top of the
## highest level of ledge along it, or the ground; and how far that floor
## stands out from the face.
func _floor_of(cell: Vector2i, step: Vector2i) -> Vector2:
	if not _level_counts.has([cell, step]):
		return Vector2.ZERO
	var top := int(_level_counts[[cell, step]]) - 1
	return Vector2(_level_height(top), _level_depth(top))


## A route of corbels up the face (cell, step), from its floor to its top: one
## every grapple route rise at most, by turns either side of a line up the
## wall, each with a ring hanging from its end; and a last ring hanging from
## the cornice along the wall's top.
func _route(cell: Vector2i, step: Vector2i) -> void:
	var room := minf(_room(cell, step, -1), _room(cell, step, 1)) - CORBEL_STAGGER - CORBEL.x
	if room < 0.0:
		return
	var base := _floor_of(cell, step).x
	var top := _maze.wall_height(cell, step)
	var cornice := top - MazeBuilder.CORNICE.y
	var span := top - base
	if span < 6.0:
		return
	_taken[[cell, step]] = true
	var steps := maxi(ceili(span / _style.grapple_route_rise), 1)
	var rise := span / steps
	var along := _spot_rng.randf_range(-room, room)
	var out := -Vector3(step.x, 0.0, step.y)
	var s := Vector3(step.x, 0.0, step.y)
	var flat_side := Vector3(-s.z, 0.0, s.x)
	var way := 1.0 if _spot_rng.randf() < 0.5 else -1.0
	for k in range(1, steps):
		var high := minf(base + rise * k, cornice - 0.4)
		var at := along + CORBEL_STAGGER * way
		way = -way
		var size := flat_side.abs() * CORBEL.x + s.abs() * CORBEL.y + Vector3.UP * CORBEL.z
		_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, CORBEL.y * 0.5, at) + Vector3.UP * (high - CORBEL.z)), {"size": size})
		_ring(_edge(cell, step, CORBEL.y, at) + Vector3.UP * high, out)
	_ring(_edge(cell, step, MazeBuilder.CORNICE.x, along + CORBEL_STAGGER * way) + Vector3.UP * top, out)


## An iron hook or an old pipe out of the face (cell, step), high over the floor
## in front of it, to swing from.
func _swing_spot(cell: Vector2i, step: Vector2i) -> void:
	var room := minf(_room(cell, step, -1), _room(cell, step, 1)) - 1.0
	var high := _floor_of(cell, step).x + _spot_rng.randf_range(_style.grapple_swing_height_range.x, _style.grapple_swing_height_range.y)
	if room < 0.0 or high > _maze.wall_height(cell, step) - MazeBuilder.CORNICE.y - 1.0:
		return
	_taken[[cell, step]] = true
	var pipe := _spot_rng.randf() < 0.5
	# (the hook's crook, or the pipe's end, this far out from the wall)
	var reach := 0.95 if pipe else 0.55
	_spot(_edge(cell, step, reach, _spot_rng.randf_range(-room, room)) + Vector3.UP * high, -Vector3(step.x, 0.0, step.y),
		GrappleSpots.Look.PIPE if pipe else GrappleSpots.Look.HOOK)
