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
## ring -> [its numbers, its hook spots' numbers].
var _rngs := {}
## The rings being laid out (all, if empty).
var _zones := {}
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
## Only in the rings in `zones` (ring -> true), if any are given: each ring is laid
## out with numbers of its own, so it comes out the same whichever others are.
static func lay_out(layout: MazeLayout, maze: Maze, zones: Dictionary = {}) -> void:
	var placer := MazeFeatures.new()
	placer._zones = zones
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
		vine.hold = piece.hold
		vine.held = piece.vine_held()
		vine.reach = piece.reach
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
		strand.from_held = piece.strand_held(false)
		strand.to_held = piece.strand_held(true)
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


## Starts on ring `ring`: its style and its numbers. Whether it is being laid out.
func _enter(ring: int) -> bool:
	if not _zones.is_empty() and not _zones.has(ring):
		return false
	_style = _maze.styles[ring - 1]
	if not _rngs.has(ring):
		var made := RandomNumberGenerator.new()
		made.seed = hash("features/%d/%d" % [_maze.maze_seed, ring])
		var spots := RandomNumberGenerator.new()
		spots.seed = hash("grapple spots/%d/%d" % [_maze.maze_seed, ring])
		_rngs[ring] = [made, spots]
	_rng = _rngs[ring][0]
	_spot_rng = _rngs[ring][1]
	return true


func _place(layout: MazeLayout, plan: Maze) -> void:
	_maze = plan
	_layout = layout
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		# (in the rings, as their styles say: the clearing's walls are left bare, and
		# so are the entrances)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring):
			continue
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
						_vine(cell, step, out, beside, high, VINE_CLEAR, false, Vine.Held.LIP if off_wall > 0.0 else Vine.Held.FACE, WALL_VINE_OUT)
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
		if not _enter(ring):
			continue
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
		if not _enter(ring):
			continue
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
			var b := _edge(far, step, VineStrand.TIED_OUT, clampf(-along + _rng.randf_range(-3.0, 3.0), -Maze.CELL * 0.5 + 1.5, Maze.CELL * 0.5 - 1.5)) + Vector3.UP * (high + _rng.randf_range(-1.5, 1.5))
			_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b, "held_end": Vine.Held.FACE})

	# Sewer pipes through the maze walls, high up, between halls on both sides.
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring):
			continue
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
	_pipe_ivy()
	_spots(plan)
	_ledge_vines(plan)
	_wall_vines(plan)
	_furnish_rooms(plan)


## How high a room's column stands over its walls, as the piers where walls meet do.
const COLUMN_OVER := MazeBuilder.PIER.y
## How big a room's pine is, smallest and largest, as times a clearing pine's 13 m:
## up the light well its walls make.
const ROOM_PINE := Vector2(1.8, 2.5)


## What stands in each room (Maze.rooms; a pond is Ponds'): its column, or four, of
## the walls' stone, from the floor to over the tops of its walls, on the corners of
## cells Maze.columns says (clear of the ways through it, which go by the cells'
## middles); or a great pine in its middle.
func _furnish_rooms(plan: Maze) -> void:
	for room: Dictionary in plan.rooms:
		var ring: int = room.ring
		if not _enter(ring):
			continue
		var rect: Rect2i = room.rect
		_layout.laying_zone = ring
		if room.fill == Maze.Room.TREE:
			var numbers := _numbers(hash(rect.position), plan.maze_seed)
			var at := plan.room_middle(room)
			at.y = plan.ground_height(at) - 0.15
			var big := numbers.randf_range(ROOM_PINE.x, ROOM_PINE.y)
			_layout.add_piece(MazePiece.Kind.TREE, Transform3D(Basis(Vector3.UP, numbers.randf() * TAU).scaled(Vector3.ONE * big), at), {})
		elif room.fill == Maze.Room.COLUMN:
			var high := plan.maze_wall_height(ring) + COLUMN_OVER
			for x in range(rect.position.x, rect.end.x + 1):
				for y in range(rect.position.y, rect.end.y + 1):
					var corner := Vector2i(x, y)
					if not plan.columns.has(corner):
						continue
					var wide: float = plan.columns[corner]
					_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, plan.corner_at(corner)), {"size": Vector3(wide, high, wide)})
		_layout.laying_zone = -1


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
		if not _enter(ring):
			continue
		if _style.mezzanine_height <= 0.0:
			continue
		for step: Vector2i in Maze.STEPS:
			if not plan.has_ledge(cell, step):
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
				# (a step of the wall standing on the level under it; round the corner where
				# the wall ends or turns away, as the first level goes: see MazeLayout._ledges)
				var under := _level_height(level - 1)
				var past := {-1: _past_end(cell, step, -1, deep), 1: _past_end(cell, step, 1, deep)}
				var size: Vector3 = flat_side.abs() * (length + float(past[-1]) + float(past[1])) + s.abs() * deep + Vector3.UP * (high - under)
				_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, deep * 0.5, middle + (float(past[1]) - float(past[-1])) * 0.5) + Vector3.UP * under), {"size": size, "ledge": true})
				# (ivy from its edge down onto the level under it, somewhere along it)
				if _rng.randf() < _style.amount(&"mezzanine_ivy_share"):
					var along := middle + _rng.randf_range(-0.3, 0.3) * length
					_climb(_edge(cell, step, deep, along) + Vector3.UP * under, step, high - under, WALL_IVY * 0.6)
	# Across the end face of each wall that ends, the levels over the first go round
	# it too (from this face, or from the face behind if that has the level as well
	# and is the one going +x or +z: one each).
	for key: Array in levels:
		var cell: Vector2i = key[0]
		var step: Vector2i = key[1]
		var ring := plan.ring_of(cell)
		if not _enter(ring):
			continue
		var behind := [cell + step, -step]
		var thick := _thick(cell, step)
		var s := Vector3(step.x, 0.0, step.y)
		var flat_side := Vector3(-s.z, 0.0, s.x)
		for way: int in [-1, 1]:
			if _corner(cell, step, way) != FaceEnd.END:
				continue
			for level in range(1, int(levels[key])):
				if int(levels.get(behind, 0)) > level and step.x + step.y < 0:
					continue
				var deep := _level_depth(level)
				var under := _level_height(level - 1)
				var size := s.abs() * thick + flat_side.abs() * deep + Vector3.UP * (_level_height(level) - under)
				_layout.laying_zone = ring
				_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, -thick * 0.5, way * (Maze.CELL * 0.5 + thick * 0.5 + deep * 0.5)) + Vector3.UP * under), {"size": size, "ledge": true})
				_layout.laying_zone = -1
	# Rope bridges across the halls between ledges at the same level.
	for key: Array in levels:
		var cell: Vector2i = key[0]
		var step: Vector2i = key[1]
		if step.x < 0 or step.y < 0:
			continue
		_enter(plan.ring_of(cell))
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


## What is at the `way` end (1 or -1, along the face's side, as _edge has it) of
## the face (cell, step): another wall across it (an inside corner), the wall going
## on, the wall turning away from the face, or the wall's end.
enum FaceEnd { INSIDE, ON, TURN, END }


func _corner(cell: Vector2i, step: Vector2i, way: int) -> FaceEnd:
	var side := Vector2i(-step.y, step.x) * way
	if _maze.blocked(cell, side):
		return FaceEnd.INSIDE
	if _maze.blocked(cell + side, step):
		return FaceEnd.ON
	return FaceEnd.TURN if _maze.blocked(cell + step, side) else FaceEnd.END


## How far past the `way` end of the face (cell, step) a level of ledge `deep`
## goes on, past the cell, round the corner: where the wall ends, on to its end and
## a ledge's depth more (to meet the one across its end face); where it turns away,
## on to the corner, and a ledge's depth more if the wall runs along x (the one
## along the wall it turns into, along z, stops at the corner: one in the corner's
## stone, not two whose tops would flicker); not into another ring.
func _past_end(cell: Vector2i, step: Vector2i, way: int, deep: float) -> float:
	var corner := _corner(cell, step, way)
	if corner == FaceEnd.INSIDE or corner == FaceEnd.ON:
		return 0.0
	var next := cell + Vector2i(-step.y, step.x) * way
	if _maze.ring_of(next) != _maze.ring_of(cell) or _maze.solid.has(next):
		return 0.0
	var end := _thick(cell, step) * 0.5
	return end + (deep if corner == FaceEnd.END or step.y != 0 else 0.0)


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
	# (over the highest level of ledge there may be, not buried in it)
	if _style.mezzanine_height > 0.0:
		high = maxf(high, minf(_level_height(_style.mezzanine_levels - 1) + PLATFORM_THICK + 1.5, _maze.wall_height(cell, step) - MazeBuilder.CORNICE.y - SewerPipe.HOLE.y - 1.0))
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
		# (ivy up to it from the floor in front of the face: laid once the levels of ledge are, see _pipe_ivy)
		_pipe_climbs.append([end[0], end[1], end[2], high, _maze.ring_of(end[0])])
		_lip(end[0], end[1], PLATFORM.x, end[2], high, PLATFORM.y)


## The ivy up to the pipes' platforms: [cell, step, along, how high, ring] each.
var _pipe_climbs: Array = []


## Ivy up to each pipe's platform from the floor in front of its face: the top of
## the highest level of ledge along it that reaches out under the platform's edge,
## or the ground (in front of the ledges, if none does), so that none of it is
## buried in a ledge.
func _pipe_ivy() -> void:
	for climb: Array in _pipe_climbs:
		if not _enter(int(climb[4])):
			continue
		var cell: Vector2i = climb[0]
		var step: Vector2i = climb[1]
		var high: float = climb[3]
		var foot := 0.0
		for level in int(_level_counts.get([cell, step], 0)):
			if _level_depth(level) >= PLATFORM.x and _level_height(level) < high - 2.0:
				foot = _level_height(level)
		_climb(_edge(cell, step, PLATFORM.x, climb[2]) + Vector3.UP * foot, step, high - foot, PLATFORM.y * 0.7)


## Cuts the hole for a pipe through the wall at `middle` (the middle of its floor,
## in the middle of the wall), the wall running across `through`: the wall's run
## is split into the parts either side of it, under it and over it. Whether there
## was a wall there to cut.
func _hole(middle: Vector3, through: Vector3) -> bool:
	var probe := middle + Vector3.UP * SewerPipe.HOLE.y * 0.5
	for piece in _layout.pieces(MazePiece.Kind.WALL):
		if piece.rotation != Vector3.ZERO or not piece.box_has(probe):
			continue
		# (a run of wall may go on into the next section, and be of its zone: not
		# cut from this one, so that each zone is laid out the same alone or with the rest)
		if MazeLayout.zone_of(_maze, piece) != MazeLayout.zone_at(_maze, middle):
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
		# (its parts of the zone it was of, wherever their middles are)
		var zone := MazeLayout.zone_of(_maze, piece)
		piece.get_parent().remove_child(piece)
		piece.free()
		var was := _layout.laying_zone
		_layout.laying_zone = zone
		for part: Array in parts:
			var made := settings.duplicate()
			made["size"] = part[1]
			_layout.add_piece(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, part[0]), made)
		_layout.laying_zone = was
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
	if _maze.has_ledge(cell, side):
		room -= _maze.ledge_style(cell).mezzanine_depth
	return room


## How high the face (cell, step) goes: its wall's height, or a rampart's.
func _face_top(cell: Vector2i, step: Vector2i) -> float:
	return _maze.inner_height(_maze.ring_of(cell + step)) if _maze.solid.has(cell + step) else _maze.wall_height(cell, step)


const NOWHERE := Vector2i(-1, -1)


## The cell on the far side of the hall from `cell`, going the `across` way: the
## first with a wall that way, if the hall is open up to it and no more than
## two cells across (NOWHERE if not: a bridge any longer sags too far). `cell`
## itself in a hall one cell wide. Never across a room (Maze.rooms): it is open
## floor round what stands in it, nothing strung or bridged over it.
func _far_side(cell: Vector2i, across: Vector2i) -> Vector2i:
	var at := cell
	for i in 2:
		if _maze.in_room(at):
			return NOWHERE
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
## or (`beam` false) from the top of the wall itself, `top` high, held as `held` says
## (Vine.Held) `from_face` out from what holds it.
func _vine(cell: Vector2i, step: Vector2i, out: float, along: float, top: float, end: float, beam := true, held: int = Vine.Held.FACE, from_face := 0.0) -> void:
	if not beam:
		_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, _edge(cell, step, out, along) + Vector3.UP * top), {"length": top - end, "hold": Vector3(step.x, 0.0, step.y), "held": held, "reach": from_face})
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


# --- The vines of halls with ledges ---
# (the user's concept of the first section, 2026-10-18: ivy up to the ledges, brackets
# high over them with vines strung across, swept down and hanging from them, vines
# strung between the ledges and hanging from their edges to the floor)

## A bracket of stone on the wall over a ledge: how long along the wall, how thick,
## and how far out at most (no further than the ledge under it, which the ivy up to
## it and the vine hanging from it stand on).
const BRACKET := Vector3(4.6, 0.5, 1.2)
## Along a bracket from its middle (towards the side its ivy is on): where the ivy up
## to it is, the vine strung across from it, the vine swept down from it, and the
## vine hanging from it.
const BRACKET_IVY := 1.4
const BRACKET_ACROSS := 0.4
const BRACKET_SWEEP := -0.6
const BRACKET_VINE := -1.6
## How far along the wall from the ivy up to a bracket the ivy up to the ledge is.
const LEDGE_IVY_BESIDE := 4.0
## How wide the ivy up to a bracket is, and the ivy up to a ledge.
const BRACKET_IVY_WIDE := 1.6
const LEDGE_IVY_WIDE := 2.6
## How high over what is under it the end of a vine hanging down to a ledge or to
## the floor is: caught standing, or with a hop.
const LOW_VINE_CLEAR := 1.2
## How far out past a ledge's edge a vine hanging from it is.
const LIP_VINE_OUT := 0.3


## Numbers of their own for one feature at one place: so that turning one feature
## off leaves the others where they were.
static func _numbers(from: int, feature: int) -> RandomNumberGenerator:
	var made := RandomNumberGenerator.new()
	made.seed = hash([from, feature])
	return made


## The vines of the halls with a ledge along both walls (MazeStyle "Climbing":
## concrete bridges; "Vines": bracket vines, vines strung between the ledges, vines
## swept down across the hall) and of the walls with a ledge (vines hanging from
## each level's edge to the level under it or the floor).
func _ledge_vines(plan: Maze) -> void:
	# (the faces given ivy up to the first level here: no hanging vine beside it as well)
	var ivied := {}
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring) or _style.mezzanine_height <= 0.0:
			continue
		# Across the hall, from the face (cell, -step) to the far side's (far, step).
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _level_counts.has([cell, -step]):
				continue
			var far := _far_side(cell, step)
			if far == NOWHERE or not _level_counts.has([far, step]):
				continue
			# (one number drawn for the hall whatever is on, each feature's own numbers from it)
			var drawn := _rng.randi()
			var one := [cell, -step]
			var other := [far, step]
			var common := mini(int(_level_counts[one]), int(_level_counts[other]))
			if _numbers(drawn, 0).randf() < _style.amount(&"bracket_vine_share"):
				_brackets(one, other, _numbers(drawn, 1), ivied)
			for level in common:
				var numbers := _numbers(drawn, 10 + level)
				# (over the first level: arched concrete bridges between ledges at the same height)
				if level > 0 and numbers.randf() < _style.amount(&"concrete_bridge_share"):
					_concrete_bridge(one, other, level, numbers, ivied)
				numbers = _numbers(drawn, 20 + level)
				if numbers.randf() < _style.amount(&"ledge_strung_vine_share"):
					_ledge_strand(one, other, level, numbers)
				# (down from a level's edge across to the far ledge one level under it, either way)
				numbers = _numbers(drawn, 30 + level)
				if level > 0 and numbers.randf() < _style.amount(&"swept_vine_share"):
					if numbers.randf() < 0.5:
						_swept_vine(one, other, level, numbers)
					else:
						_swept_vine(other, one, level, numbers)
	# Vines hanging from the ledges' edges down to the level under them, or the floor.
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring) or _style.mezzanine_height <= 0.0:
			continue
		for step: Vector2i in Maze.STEPS:
			if not _level_counts.has([cell, step]):
				continue
			var drawn := _rng.randi()
			for level in int(_level_counts[[cell, step]]):
				var numbers := _numbers(drawn, level)
				if numbers.randf() >= _style.amount(&"ledge_hanging_vine_share") or _taken.has([cell, step]) or (level == 0 and ivied.has([cell, step])):
					continue
				var room := minf(_room(cell, step, -1), _room(cell, step, 1)) - 1.0
				if room < 0.0:
					continue
				var top := _level_height(level)
				var under := _level_height(level - 1) if level > 0 else 0.0
				var along := numbers.randf_range(-room, room)
				_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, _edge(cell, step, _level_depth(level) + LIP_VINE_OUT, along) + Vector3.UP * top),
					{"length": top - under - LOW_VINE_CLEAR, "hold": Vector3(step.x, 0.0, step.y), "held": Vine.Held.LIP, "reach": LIP_VINE_OUT})


## A pair of brackets across a hall, on the faces `one` and `other` ([cell, step]
## each): on one of them (its own ivy and vines) ivy from the floor to the ledge's
## edge and from the ledge up to the bracket, a vine hanging from the bracket to the
## ledge, and vines strung from it across to the other bracket and down to the far
## ledge's edge; ivy to the ledge under the other bracket too.
func _brackets(one: Array, other: Array, numbers: RandomNumberGenerator, ivied: Dictionary) -> void:
	# (the bracket with the ivy: either, of those whose face nothing else has)
	var near := one
	var far := other
	if numbers.randf() < 0.5:
		near = other
		far = one
	if _taken.has(near):
		var swap := near
		near = far
		far = swap
	if _taken.has(near):
		return
	var ledge := _style.mezzanine_height
	var depth := _style.mezzanine_depth
	var out := minf(BRACKET.z, depth)
	var top := minf(_face_top(near[0], near[1]), _face_top(far[0], far[1])) - MazeBuilder.CORNICE.y - 2.0
	var high := minf(ledge + numbers.randf_range(_style.bracket_height_range.x, _style.bracket_height_range.y), top)
	if high < ledge + 3.0:
		return
	# (which way along the wall its ivy is; everything of it clear of the walls at the ends)
	var way := 1.0 if numbers.randf() < 0.5 else -1.0
	var parts := [BRACKET.x * 0.5, -BRACKET.x * 0.5, BRACKET_IVY + LEDGE_IVY_BESIDE + LEDGE_IVY_WIDE * 0.5]
	var reach_low := 0.0
	var reach_high := 0.0
	for part: float in parts:
		reach_low = minf(reach_low, part * way)
		reach_high = maxf(reach_high, part * way)
	var lowest := -_room(near[0], near[1], -1) - reach_low
	var highest := _room(near[0], near[1], 1) - reach_high
	if lowest > highest:
		return
	var along := numbers.randf_range(lowest, highest)
	_bracket(near[0], near[1], along, high, out)
	# Ivy up from the floor to the ledge's edge, and on up from the ledge to the bracket.
	_climb(_edge(near[0], near[1], depth, along + way * (BRACKET_IVY + LEDGE_IVY_BESIDE)), near[1], ledge, LEDGE_IVY_WIDE)
	_climb(_edge(near[0], near[1], out, along + way * BRACKET_IVY) + Vector3.UP * ledge, near[1], high - ledge, BRACKET_IVY_WIDE)
	ivied[near] = true
	# A vine hanging from it down to the ledge (over the ledge, a step in from its edge).
	var under := high - BRACKET.y
	_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, _edge(near[0], near[1], out * 0.6, along + way * BRACKET_VINE) + Vector3.UP * under),
		{"length": under - ledge - LOW_VINE_CLEAR})
	# The bracket across the hall (along that wall runs the other way), about as high.
	var far_room := Vector2(_room(far[0], far[1], -1), _room(far[0], far[1], 1)) - Vector2.ONE * BRACKET.x * 0.5
	if -far_room.x > far_room.y:
		return
	var far_along := clampf(-along + numbers.randf_range(-1.5, 1.5), -far_room.x, far_room.y)
	var far_high := minf(high + numbers.randf_range(-1.0, 1.0), top)
	_bracket(far[0], far[1], far_along, far_high, out)
	# (ivy up to the ledge under it, if nothing else is on that face)
	if not _taken.has(far):
		var ivy_along := clampf(far_along - way * LEDGE_IVY_BESIDE * 0.5, -_room(far[0], far[1], -1) + LEDGE_IVY_WIDE * 0.5, _room(far[0], far[1], 1) - LEDGE_IVY_WIDE * 0.5)
		_climb(_edge(far[0], far[1], depth, ivy_along), far[1], ledge, LEDGE_IVY_WIDE)
		ivied[far] = true
	# Vines strung from it: across to the other bracket, and swept down to the far ledge's edge.
	var a := _edge(near[0], near[1], out, along + way * BRACKET_ACROSS) + Vector3.UP * high
	var b := _edge(far[0], far[1], out, far_along) + Vector3.UP * far_high
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b})
	var sweep_room := Vector2(_room(far[0], far[1], -1), _room(far[0], far[1], 1)) - Vector2.ONE * 1.0
	var sweep_along := clampf(-along + way * numbers.randf_range(2.0, 4.0), -sweep_room.x, sweep_room.y)
	var c := _edge(near[0], near[1], out, along + way * BRACKET_SWEEP) + Vector3.UP * high
	var d := _edge(far[0], far[1], depth, sweep_along) + Vector3.UP * ledge
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, c), {"to": d})


## A bracket of stone on the face (cell, step), `along` it, its top `high`, `out`
## from the wall.
func _bracket(cell: Vector2i, step: Vector2i, along: float, high: float, out: float) -> void:
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var size := side.abs() * BRACKET.x + s.abs() * out + Vector3.UP * BRACKET.y
	_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, out * 0.5, along) + Vector3.UP * (high - BRACKET.y)), {"size": size})


## A vine strung across the hall between the edges of the ledges at `level` along
## the faces `one` and `other` ([cell, step] each): under the ledges of the first
## section, across the floor's channel and over the top ledges of the second.
func _ledge_strand(one: Array, other: Array, level: int, numbers: RandomNumberGenerator) -> void:
	var high := _level_height(level)
	var deep := _level_depth(level)
	var room := Vector2(_room(one[0], one[1], -1), _room(one[0], one[1], 1)) - Vector2.ONE * 1.0
	var far_room := Vector2(_room(other[0], other[1], -1), _room(other[0], other[1], 1)) - Vector2.ONE * 1.0
	if -room.x > room.y or -far_room.x > far_room.y:
		return
	var along := numbers.randf_range(-room.x, room.y)
	var far_along := clampf(-along + numbers.randf_range(-2.0, 2.0), -far_room.x, far_room.y)
	var a := _edge(one[0], one[1], deep, along) + Vector3.UP * high
	var b := _edge(other[0], other[1], deep, far_along) + Vector3.UP * high
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b})


## A vine swept down across the hall from the edge of the ledge at `level` along
## the face `from` to the edge of the one a level under it along `to`.
func _swept_vine(from: Array, to: Array, level: int, numbers: RandomNumberGenerator) -> void:
	var room := Vector2(_room(from[0], from[1], -1), _room(from[0], from[1], 1)) - Vector2.ONE * 1.0
	var far_room := Vector2(_room(to[0], to[1], -1), _room(to[0], to[1], 1)) - Vector2.ONE * 1.0
	if -room.x > room.y or -far_room.x > far_room.y:
		return
	var along := numbers.randf_range(-room.x, room.y)
	var way := 1.0 if numbers.randf() < 0.5 else -1.0
	var far_along := clampf(-along + way * numbers.randf_range(2.0, 4.0), -far_room.x, far_room.y)
	var a := _edge(from[0], from[1], _level_depth(level), along) + Vector3.UP * _level_height(level)
	var b := _edge(to[0], to[1], _level_depth(level - 1), far_along) + Vector3.UP * _level_height(level - 1)
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b})


## How thick a concrete bridge's deck is over its arch, metres, and how long at most
## each block of its arch is along it (it is built of blocks, each as deep as the arch
## is there and overlapping the next by half, so that it steps down smoothly).
const BRIDGE_DECK := 0.6
const ARCH_BLOCK := 0.45
## How far along a concrete bridge from its end the ivy up to it is, past its side.
const BRIDGE_IVY := 2.0


## An arched concrete bridge across the hall between the ledges at `level` (over the
## first) along the faces `one` and `other` ([cell, step] each): a flat deck flush
## with the ledges, its underside arched (blocks of the ledges' concrete, each as
## deep as the arch is there, their edges worn round as the walls' are), with ivy up
## to it at each end from the floor, level by level, and now and then a vine hanging
## from its side. Solid, walked across.
func _concrete_bridge(one: Array, other: Array, level: int, numbers: RandomNumberGenerator, ivied: Dictionary) -> void:
	var wide := _style.concrete_bridge_width
	var high := _level_height(level)
	var deep := _level_depth(level)
	var room := Vector2(_room(one[0], one[1], -1), _room(one[0], one[1], 1)) - Vector2.ONE * (wide * 0.5 + 0.5)
	var far_room := Vector2(_room(other[0], other[1], -1), _room(other[0], other[1], 1)) - Vector2.ONE * (wide * 0.5 + 0.5)
	# (straight across: along the far wall, which runs the other way, it is at -along)
	var lowest := maxf(-room.x, -far_room.y)
	var highest := minf(room.y, far_room.x)
	if lowest > highest:
		return
	var along := numbers.randf_range(lowest, highest)
	var a := _edge(one[0], one[1], deep, along) + Vector3.UP * high
	var b := _edge(other[0], other[1], deep, -along) + Vector3.UP * high
	var middle := (a + b) * 0.5
	var span := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var long := span.length()
	if long < 2.0:
		return
	# (clear of a rope bridge between these ledges)
	for piece in _layout.pieces(MazePiece.Kind.BRIDGE):
		if absf(piece.position.y - high) < 0.5 and ((piece.position + piece.bridge_end()) * 0.5).distance_to(middle) < wide + 2.0:
			return
	var across := span / long
	var side := across.cross(Vector3.UP)
	var size_of := func(length: float, tall: float) -> Vector3:
		return across.abs() * length + side.abs() * wide + Vector3.UP * tall
	# The deck, a little into the ledges at each end.
	var under := high - BRIDGE_DECK
	_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(middle.x, under, middle.z)), {"size": size_of.call(long + 0.6, BRIDGE_DECK)})
	# The arch under it: from the ledges' fronts, `rise` under the deck, up to the deck in the middle.
	var rise := minf(_style.concrete_bridge_arch_rise, high - _level_height(level - 1) - 2.5)
	var blocks := maxi(ceili(long / ARCH_BLOCK), 4)
	for k in blocks:
		var x := -long * 0.5 + (k + 0.5) * long / blocks
		var u := 2.0 * x / long
		var tall := rise * u * u
		if tall < 0.08:
			continue
		_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(middle.x, under - tall, middle.z) + across * x), {"size": size_of.call(long / blocks * 2.0, tall + 0.02)})
	# Ivy up to it at each end, from the floor to the first level and on from each level to the next.
	for end: Array in [[one, along], [other, -along]]:
		var face: Array = end[0]
		var limit := Vector2(_room(face[0], face[1], -1), _room(face[0], face[1], 1)) - Vector2.ONE * LEDGE_IVY_WIDE * 0.5
		var way := 1.0 if numbers.randf() < 0.5 else -1.0
		for j in level + 1:
			var at := clampf(float(end[1]) + way * (wide * 0.5 + BRIDGE_IVY + (j % 2) * 3.0), -limit.x, limit.y)
			var foot := _level_height(j - 1) if j > 0 else 0.0
			_climb(_edge(face[0], face[1], _level_depth(j), at) + Vector3.UP * foot, face[1], _level_height(j) - foot, LEDGE_IVY_WIDE)
		ivied[face] = true
	# A vine hanging from its side, down past the level under it (to the one under that, or the floor).
	if numbers.randf() < _style.amount(&"bridge_hanging_vine_share"):
		var way := 1.0 if numbers.randf() < 0.5 else -1.0
		var top := middle + across * long * numbers.randf_range(-0.2, 0.2) + side * way * (wide * 0.5 + 0.25)
		var end := _level_height(level - 2) if level >= 2 else 0.0
		_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, top), {"length": high - end - LOW_VINE_CLEAR, "hold": -side * way, "held": Vine.Held.LIP, "reach": 0.25})


# --- Vines out of the walls ---
# (the user, 2026-10-18: "Vines should be able to connect directly to the wall and hang
# a random amount down across the hall as well as the designated anchor points")

## How far out from a wall's face a vine grown out of it hangs, metres (its stem comes
## out of the face and bends down to there).
const WALL_GROWN_OUT := 0.35
## How far along the wall from anything else on it (ivy, a vine, a strung vine's end)
## a vine out of the wall keeps, metres; and from the wall's ends.
const WALL_VINE_CLEAR := 2.0
const WALL_VINE_ENDS := 1.5
## How far out across the hall a vine swept down to the floor is rooted, at least, metres.
const GROUND_ROOT := 2.5
## How far clear of a ledge a vine swept across the hall keeps, metres.
const LEDGE_CLEAR := 0.4


## The vines grown straight out of the walls (MazeStyle "Vines": vines out of the
## walls), after everything else and on faces nothing else has taken, each face
## with numbers of its own: out of the face somewhere along it (under the first
## ledge, or over the top one, where it has ledges), and hanging a random way down,
## or swept down across the hall to the far wall or to the floor part way across.
func _wall_vines(plan: Maze) -> void:
	# (where there are things on the walls already, by cell, to keep clear of)
	var near := {}
	for piece in _layout.pieces(MazePiece.Kind.VINE):
		_note(near, piece.position, 0.0)
	for piece in _layout.pieces(MazePiece.Kind.STRAND):
		_note(near, piece.position, 0.0)
		_note(near, piece.bridge_end(), 0.0)
	for piece in _layout.pieces(MazePiece.Kind.IVY):
		_note(near, piece.position, piece.width * 0.5)
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring):
			continue
		for step: Vector2i in Maze.STEPS:
			if not plan.blocked(cell, step) or _taken.has([cell, step]):
				continue
			var numbers := _numbers(_rng.randi(), 0)
			if numbers.randf() < _style.amount(&"wall_vine_share"):
				_layout.laying_zone = ring
				_wall_vine(cell, step, numbers, near)
				_layout.laying_zone = -1


## Notes something on a wall at `at`, `wide` along it either side, in `near` (cell -> [[where, how wide]]).
func _note(near: Dictionary, at: Vector3, wide: float) -> void:
	var key := _maze.cell_at(at)
	if not near.has(key):
		near[key] = []
	near[key].append([Vector2(at.x, at.z), wide])


## Whether `at` is WALL_VINE_CLEAR from everything noted in `near` (see _note).
func _clear_of(near: Dictionary, at: Vector3) -> bool:
	var cell := _maze.cell_at(at)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for noted: Array in near.get(cell + Vector2i(dx, dy), []):
				if (noted[0] as Vector2).distance_to(Vector2(at.x, at.z)) < WALL_VINE_CLEAR + float(noted[1]):
					return false
	return true


## A vine out of the face (cell, step), as `numbers` say (see _wall_vines).
func _wall_vine(cell: Vector2i, step: Vector2i, numbers: RandomNumberGenerator, near: Dictionary) -> void:
	var levels := int(_level_counts.get([cell, step], 0))
	# (the band of the wall it grows out of: from the floor up to under the first ledge
	# (or the wall's cornice), or over the top ledge)
	var band := _band(cell, step, levels, levels > 0 and numbers.randf() < 0.5)
	var high := minf(band.x + numbers.randf_range(_style.wall_vine_height_range.x, _style.wall_vine_height_range.y), band.y)
	if high - band.x < 3.0:
		return
	var lowest := -_room(cell, step, -1) + WALL_VINE_ENDS
	var highest := _room(cell, step, 1) - WALL_VINE_ENDS
	if lowest > highest:
		return
	var along := numbers.randf_range(lowest, highest)
	if not _clear_of(near, _edge(cell, step, 0.0, along)):
		return
	var s := Vector3(step.x, 0.0, step.y)
	if numbers.randf() < _style.wall_vine_sweep_share and _wall_sweep(cell, step, along, high, band, levels, numbers, near):
		return
	# Hanging a random way down, its end no lower than a hop over what is under it.
	var longest := high - band.x - LOW_VINE_CLEAR
	if longest < 1.5:
		return
	var top := _edge(cell, step, WALL_GROWN_OUT, along) + Vector3.UP * high
	_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, top),
		{"length": numbers.randf_range(minf(2.0, longest), longest), "hold": s, "held": Vine.Held.FACE, "reach": WALL_GROWN_OUT})
	_note(near, top, 0.0)


## The band of the face (cell, step) that has `levels` levels of ledge a vine may grow
## out of: (its foot, its top), from the floor to under the first ledge (or the cornice),
## or (`over`) from the top ledge to under the cornice.
func _band(cell: Vector2i, step: Vector2i, levels: int, over: bool) -> Vector2:
	var top := _face_top(cell, step) - MazeBuilder.CORNICE.y - 1.0
	if levels <= 0:
		return Vector2(0.0, top)
	if over:
		return Vector2(_level_height(levels - 1), top)
	return Vector2(0.0, _style.mezzanine_height - _style.mezzanine_thickness - 0.6)


## A vine out of the face (cell, step) at `along`, `high` up its band `band`, swept
## down across the hall: to the far wall in the same band, lower down, or (from the
## band under the ledges, or a wall without) to the floor part way across. Whether
## there was room for it, clear of the ledges both sides.
func _wall_sweep(cell: Vector2i, step: Vector2i, along: float, high: float, band: Vector2, levels: int, numbers: RandomNumberGenerator, near: Dictionary) -> bool:
	var across := -step
	var far := _far_side(cell, across)
	var over := levels > 0 and band.x > 0.0
	var a := _edge(cell, step, VineStrand.TIED_OUT, along) + Vector3.UP * high
	var far_levels := int(_level_counts.get([far, across], 0)) if far != NOWHERE else 0
	var wide := Maze.CELL * 0.8
	if far != NOWHERE:
		wide = absf((_edge(far, across, 0.0, 0.0) - _edge(cell, step, 0.0, 0.0)).dot(Vector3(step.x, 0.0, step.y)))
	var b: Vector3
	var held_end := Vine.Held.FACE
	if far != NOWHERE and (over or numbers.randf() < 0.5):
		# (to the far wall, lower down, in the same band of it)
		var far_band := _band(far, across, far_levels, over and far_levels > 0)
		var low := minf(high - numbers.randf_range(2.0, 8.0), far_band.y)
		low = maxf(low, far_band.x + 2.0)
		if low > high - 1.0:
			return false
		var far_room := Vector2(_room(far, across, -1), _room(far, across, 1)) - Vector2.ONE * WALL_VINE_ENDS
		if -far_room.x > far_room.y:
			return false
		b = _edge(far, across, VineStrand.TIED_OUT, clampf(-along + numbers.randf_range(-3.0, 3.0), -far_room.x, far_room.y)) + Vector3.UP * low
	elif not over:
		# (to the floor part way across: not out under the far wall's ledge)
		var far_ledge := _style.mezzanine_depth + 0.5 if far_levels > 0 else 0.5
		var out := numbers.randf_range(maxf(GROUND_ROOT, wide * 0.3), minf(wide * 0.75, wide - far_ledge))
		if out < GROUND_ROOT or high < VineStrand.GROUND_SAG * 4.0 + 1.0:
			return false
		var room := Vector2(_room(cell, step, -1), _room(cell, step, 1)) - Vector2.ONE * WALL_VINE_ENDS
		b = _edge(cell, step, out, clampf(along + numbers.randf_range(-3.0, 3.0), -room.x, room.y))
		held_end = Vine.Held.GROUND
	else:
		return false
	if not _clear_of(near, b) or not _sweep_clears(a, b, [cell, step], levels, far_levels, wide, held_end == Vine.Held.GROUND):
		return false
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b, "held": Vine.Held.FACE, "held_end": held_end})
	_note(near, a, 0.0)
	_note(near, b, 0.0)
	return true


## Whether a vine strung from `a`, on the face `face` with `levels` levels of ledge,
## to `b` (on the far wall, `wide` across the hall, with `far_levels`; or `grounded`,
## in the floor) keeps clear of the ledges both sides, as far as it sags.
func _sweep_clears(a: Vector3, b: Vector3, face: Array, levels: int, far_levels: int, wide: float, grounded: bool) -> bool:
	var gap := a.distance_to(b)
	var most := VineStrand.GROUND_SAG if grounded else VineStrand.MOST_SAG
	var sag := sqrt(3.0 / 8.0 * gap * maxf(gap * minf(VineStrand.SLACK, 1.0 + 8.0 / 3.0 * pow(most / maxf(gap, 0.01), 2.0)) - gap, 0.0))
	var out := -Vector3(face[1].x, 0.0, face[1].y)
	var foot := _edge(face[0], face[1], 0.0, 0.0)
	for k in range(1, 12):
		var t := k / 12.0
		var p := a.lerp(b, t) + Vector3.DOWN * 4.0 * t * (1.0 - t) * sag
		var x := (p - foot).dot(out)
		if p.y < (0.0 if grounded else 0.3) or _in_ledges(levels, x, p.y) or _in_ledges(far_levels, wide - x, p.y):
			return false
	return true


## Whether a point `x` out from a face with `levels` levels of ledge, `y` high, is
## within LEDGE_CLEAR of one of them.
func _in_ledges(levels: int, x: float, y: float) -> bool:
	if levels <= 0:
		return false
	var m := LEDGE_CLEAR
	if x < _level_depth(0) + m and y > _style.mezzanine_height - _style.mezzanine_thickness - m and y < _style.mezzanine_height + m:
		return true
	for level in range(1, levels):
		if x < _level_depth(level) + m and y > _level_height(level - 1) - m and y < _level_height(level) + m:
			return true
	return false


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
		if not _enter(ring):
			continue
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
		_enter(plan.ring_of(cell))
		var room := minf(_room(cell, step, -1), _room(cell, step, 1)) - 1.0
		for level in int(_level_counts[key]):
			if _spot_rng.randf() < _style.amount(&"grapple_ring_share") and room > 0.0:
				var along := _spot_rng.randf_range(-room, room) * 0.8
				_ring(_edge(cell, step, _level_depth(level), along) + Vector3.UP * _level_height(level), -Vector3(step.x, 0.0, step.y))
	for lip: Array in _lips:
		_enter(int(lip[3]))
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
