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
## through walls high up, each mouth a bell of concrete on a lip with ivy up to it: up one
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
## The metal catwalks and their ladders (Catwalks; null if there are none).
var catwalks: Catwalks
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


## Lays out the ways up of `maze` as pieces of `layout`: terraces, ivy, brackets and
## bridges. Only in the rings in `zones` (ring -> true), if any are given: each ring
## is laid out with numbers of its own, so it comes out the same whichever others are.
## The placer is given back to hang the vines with once the props are laid out too
## (hang_vines), and then freed by the caller.
static func lay_out(layout: MazeLayout, maze: Maze, zones: Dictionary = {}) -> MazeFeatures:
	var placer := MazeFeatures.new()
	placer._zones = zones
	placer._place(layout, maze)
	return placer


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
	_hang_from_strands()
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
	# The catwalks and their ladders, drawn and bumped into all together.
	var walks := layout.pieces(MazePiece.Kind.CATWALK)
	var ladders := layout.pieces(MazePiece.Kind.LADDER)
	if not walks.is_empty() or not ladders.is_empty():
		catwalks = Catwalks.new()
		catwalks.name = "Catwalks"
		add_child(catwalks)
		catwalks.build(walks, ladders)


## Each vine held from a strung vine (Vine.Held.STRAND) is hung from the strung vine
## nearest its top (VineStrand.hang), so that it goes where that goes.
func _hang_from_strands() -> void:
	var by_square := {}
	for strand in strands:
		var middle := (strand.from + strand.to) * 0.5
		var key := Vector2i(floori(middle.x / SPOT_SQUARE), floori(middle.z / SPOT_SQUARE))
		if not by_square.has(key):
			by_square[key] = []
		by_square[key].append(strand)
	for vine in vines:
		if vine.held != Vine.Held.STRAND:
			continue
		var top := vine.global_position + Vector3.UP * VineStrand.HUNG_UNDER
		var key := Vector2i(floori(top.x / SPOT_SQUARE), floori(top.z / SPOT_SQUARE))
		var best: VineStrand = null
		var least := 0.6
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for strand: VineStrand in by_square.get(key + Vector2i(dx, dz), []):
					if not strand.is_inside_tree():
						continue
					var apart := strand.distance_to(top)
					if apart < least:
						least = apart
						best = strand
		if best:
			best.hang(vine)


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
				# (or ivy up the bare wall from the ground, part of the way)
				if _rng.randf() < _style.amount(&"wall_ivy_share"):
					_taken[[cell, step]] = true
					var high := minf(_face_top(cell, step) * _rng.randf_range(_style.wall_ivy_height_range.x, _style.wall_ivy_height_range.y), IVY_MOST)
					# (with a ledge along the walls, a curtain of it hanging from the ledge's
					# edge to the ground instead: he climbs it onto the ledge)
					var off_wall := 0.0
					# (only the maze walls have the ledge, not the great walls round the ring)
					var beyond := cell + step
					if _style.has_mezzanine() and plan.ring_of(beyond) == ring and not plan.solid.has(beyond):
						high = _style.level_height(0)
						off_wall = _style.level_depth(0)
					# (somewhere along the face clear of any wall meeting it)
					var low := -_room(cell, step, -1) + WALL_IVY * 0.5
					var high_along := _room(cell, step, 1) - WALL_IVY * 0.5
					if low > high_along:
						continue
					var ivy_along := clampf(_rng.randf_range(-0.3, 0.3) * Maze.CELL, low, high_along)
					_climb(_edge(cell, step, off_wall, ivy_along), step, high, WALL_IVY)
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
	_brackets(plan)
	_spots(plan)
	_concrete_bridges(plan)
	_catwalks(plan)
	_furnish_rooms(plan)
	# (the vines are hung after the props are laid out: see hang_vines)


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


## The levels of ledge over the first (MazeStyle.mezzanines): along some
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
		if not _style.has_mezzanine():
			continue
		for step: Vector2i in Maze.STEPS:
			if not plan.has_ledge(cell, step):
				continue
			var count := 1
			while count < _style.mezzanine_count() and _rng.randf() < _style.level_share(count):
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
	return _style.level_height(level)


func _level_depth(level: int) -> float:
	return _style.level_depth(level)


## How deep and wide the platform under each mouth of a pipe is, and how thick: the
## top of the lip the pipe's modelled mouth stands on (SewerMouth; the ivy hangs from its edge).
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
	if _style.has_mezzanine():
		high = maxf(high, minf(_level_height(_style.mezzanine_count() - 1) + PLATFORM_THICK + 1.5, _maze.wall_height(cell, step) - MazeBuilder.CORNICE.y - SewerPipe.HOLE.y - 1.0))
	var middle := _edge(cell, step, -thick * 0.5, along) + Vector3.UP * high
	if not _hole(middle, s):
		return
	_taken[[cell, step]] = true
	_taken[[other, -step]] = true
	_layout.add_piece(MazePiece.Kind.PIPE, Transform3D(Basis(Vector3.UP, atan2(s.x, s.z)), middle),
		{"length": thick, "width": thick})
	var flat_side := Vector3(-s.z, 0.0, s.x)
	for end: Array in [[cell, step, along], [other, -step, -along]]:
		var size := flat_side.abs() * PLATFORM.y + s.abs() * PLATFORM.x + Vector3.UP * PLATFORM_THICK
		# (drawn as the pipe's modelled mouth, a bell on a lip, facing out of the wall: SewerMouth)
		_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(end[0], end[1], PLATFORM.x * 0.5, end[2]) + Vector3.UP * (high - PLATFORM_THICK)),
			{"size": size, "mouth": -Vector3(end[1].x, 0.0, end[1].y)})
		# (ivy up to it from the floor in front of the face: laid once the levels of ledge are, see _pipe_ivy)
		_pipe_climbs.append([end[0], end[1], end[2], high, _maze.ring_of(end[0])])
		_lip(end[0], end[1], PLATFORM.x, end[2], high, PLATFORM.y)
		# (a vine may hang from its edge, beside the ivy, or be strung across from it)
		_ledge_tops.append([end[0], end[1], PLATFORM.x, end[2], high, PLATFORM.y, -1.0, end[2]])


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
		room -= _maze.ledge_style(cell).level_depth(0)
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
	_ledge_tops.append([cell, step, LOWER.y, 0.0, LOWER.x, length, 0.0, ivy_along])
	if not upper:
		return
	var upper_length := Maze.CELL * 0.5
	_layout.add_piece(MazePiece.Kind.TERRACE, Transform3D(Basis.IDENTITY, _edge(cell, step, UPPER.y * 0.5, along)), {"size": size_for.call(upper_length, UPPER.y, UPPER.x)})
	_lip(cell, step, UPPER.y, along, UPPER.x, upper_length)
	# Ivy from the lower terrace up the upper's face, away from the one below.
	var up_along := along + (_rng.randf_range(0.1, 0.35) if ivy_along < along else _rng.randf_range(-0.35, -0.1)) * upper_length
	_climb(_edge(cell, step, UPPER.y, up_along) + Vector3.UP * LOWER.x, step, UPPER.x - LOWER.x)
	_ledge_tops.append([cell, step, UPPER.y, along, UPPER.x, upper_length, LOWER.x, up_along])
	# And now and then on up the wall to its top (stood off it by the cornice).
	if not _maze.ring_wall(cell, step) and _rng.randf() < _style.amount(&"ivy_to_wall_top_share"):
		var top_along := along + _rng.randf_range(-0.3, 0.3) * upper_length
		_climb(_edge(cell, step, MazeBuilder.CORNICE.x, top_along) + Vector3.UP * UPPER.x, step, _maze.wall_height(cell, step) - UPPER.x)


func _climb(at: Vector3, step: Vector2i, high: float, wide := 1.8) -> void:
	_layout.add_piece(MazePiece.Kind.IVY, Transform3D(_facing_out(step), at), {"length": high, "width": wide})


func _bridge(a: Vector3, b: Vector3) -> void:
	_layout.add_piece(MazePiece.Kind.BRIDGE, Transform3D(Basis.IDENTITY, a), {"to": b})


## Numbers of their own for one feature at one place: so that turning one feature
## off leaves the others where they were.
static func _numbers(from: int, feature: int) -> RandomNumberGenerator:
	var made := RandomNumberGenerator.new()
	made.seed = hash([from, feature])
	return made


# --- Brackets ---
# (wall decor, laid out whether or not there are vines: the user, 2026-10-18, "all of
# the wall decor props should be independent of the vines- the vines are hung on whats there")

## A bracket of stone on the wall over a ledge: how long along the wall, how thick,
## and how far out at most (no further than the ledge under it, which the ivy up to
## it stands on). One on a wall with no ledge is a shorter corbel (VINE_CORBEL).
const BRACKET := Vector3(4.6, 0.5, 1.2)
## How wide the ivy up to a bracket is, and the ivy up to a ledge.
const BRACKET_IVY_WIDE := 1.6
const LEDGE_IVY_WIDE := 2.6
## How high over what is under it the end of a vine hanging down to a ledge or to
## the floor is: caught standing, or with a hop.
const LOW_VINE_CLEAR := 1.2
## How far out past a ledge's edge a vine hanging from it is.
const LIP_VINE_OUT := 0.3

## The tops of what stands out of the walls that a vine may hang from or be strung
## from, other than the ledges: terraces, brackets and the sewer pipes' platforms, as
## [cell, step, how far out its edge is, along the face, how high its top is, how long
## it is along the face, how high what is under its edge is (-1: the floor or the
## ledge under it), where along the face its ivy is].
var _ledge_tops: Array = []
## The concrete bridges: [their middle, the way across the hall, the way along their side,
## how long, how wide, how high their deck's top is, their level, the face at their
## first end ([cell, step])].
var _decks: Array = []


## The brackets (MazeStyle "Wall decor": brackets): on faces nothing else has, each face
## with numbers of its own (so that they come and go without moving anything else).
func _brackets(plan: Maze) -> void:
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring) or _style.amount(&"bracket_share") <= 0.0:
			continue
		for step: Vector2i in Maze.STEPS:
			if not plan.blocked(cell, step) or _taken.has([cell, step]):
				continue
			var numbers := _numbers(hash([plan.maze_seed, cell, step]), 40)
			if numbers.randf() < _style.amount(&"bracket_share"):
				_bracket(cell, step, numbers)


## A bracket of stone on the face (cell, step), as `numbers` say: over the top ledge
## along it (or the floor), as high as the style says, with ivy up to it from there to
## one side of its middle.
func _bracket(cell: Vector2i, step: Vector2i, numbers: RandomNumberGenerator) -> void:
	var levels := int(_level_counts.get([cell, step], 0))
	var foot := _level_height(levels - 1) if levels > 0 else 0.0
	var long := BRACKET.x if levels > 0 else VINE_CORBEL.x
	var out := minf(BRACKET.z, _level_depth(levels - 1)) if levels > 0 else VINE_CORBEL.z
	var top := _face_top(cell, step) - MazeBuilder.CORNICE.y - 2.0
	var range_of := _style.bracket_height_range
	var high := minf(foot + numbers.randf_range(minf(range_of.x, range_of.y), maxf(range_of.x, range_of.y)), minf(top, foot + IVY_MOST))
	if high < foot + 3.0:
		return
	var way := 1.0 if numbers.randf() < 0.5 else -1.0
	# (all of it clear of the walls at the face's ends)
	var lowest := -_room(cell, step, -1) + long * 0.5
	var highest := _room(cell, step, 1) - long * 0.5
	if lowest > highest:
		return
	var along := numbers.randf_range(lowest, highest)
	_taken[[cell, step]] = true
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var size := side.abs() * long + s.abs() * out + Vector3.UP * BRACKET.y
	_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, _edge(cell, step, out * 0.5, along) + Vector3.UP * (high - BRACKET.y)), {"size": size})
	_lip(cell, step, out, along, high, long)
	# (its ivy, up from the floor or the ledge under it to its edge)
	var ivy_along := along + way * maxf(long * 0.5 - BRACKET_IVY_WIDE * 0.5 - 0.2, 0.0)
	_climb(_edge(cell, step, out, ivy_along) + Vector3.UP * foot, step, high - foot, BRACKET_IVY_WIDE)
	_ledge_tops.append([cell, step, out, along, high, long, foot, ivy_along])


# --- Concrete bridges ---

## The concrete bridges (MazeStyle "Climbing": concrete bridges) across the halls
## with a ledge along both walls, at each level over the first.
func _concrete_bridges(plan: Maze) -> void:
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring) or not _style.has_mezzanine():
			continue
		# Across the hall, from the face (cell, -step) to the far side's (far, step).
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _level_counts.has([cell, -step]):
				continue
			var far := _far_side(cell, step)
			if far == NOWHERE or not _level_counts.has([far, step]):
				continue
			# (one number drawn for the hall whatever is on, each level's own numbers from it)
			var drawn := _rng.randi()
			var one := [cell, -step]
			var other := [far, step]
			for level in mini(int(_level_counts[one]), int(_level_counts[other])):
				var numbers := _numbers(drawn, 10 + level)
				if level > 0 and numbers.randf() < _style.amount(&"concrete_bridge_share"):
					_concrete_bridge(one, other, level, numbers)


## How thick a concrete bridge's deck is over its arch, metres (MazePiece.arch).
const BRIDGE_DECK := 0.6
## How far along a concrete bridge from its end the ivy up to it is, past its side.
const BRIDGE_IVY := 2.0


## An arched concrete bridge across the hall between the ledges at `level` (over the
## first) along the faces `one` and `other` ([cell, step] each): a flat deck flush
## with the ledges, its underside arched smoothly (one span of the ledges'
## concrete, MazePiece.arch), with ivy up to it at each end from the floor, level
## by level. Solid, walked across.
func _concrete_bridge(one: Array, other: Array, level: int, numbers: RandomNumberGenerator) -> void:
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
	# The deck and the arch under it, one smooth span (the user, 2026-10-18: "the
	# concrete arch should be smooth"): from the ledges' fronts, `rise` under the
	# deck, curving up to the deck in the middle; a little into the ledges at each end.
	var under := high - BRIDGE_DECK
	var rise := maxf(minf(_style.concrete_bridge_arch_rise, high - _level_height(level - 1) - 2.5), 0.0)
	_layout.add_piece(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(middle.x, under - rise, middle.z)), {"size": size_of.call(long + 0.6, BRIDGE_DECK + rise), "arch": BRIDGE_DECK})
	# Ivy up to it at each end, from the floor to the first level and on from each level to the next.
	for end: Array in [[one, along], [other, -along]]:
		var face: Array = end[0]
		var limit := Vector2(_room(face[0], face[1], -1), _room(face[0], face[1], 1)) - Vector2.ONE * LEDGE_IVY_WIDE * 0.5
		var way := 1.0 if numbers.randf() < 0.5 else -1.0
		for j in level + 1:
			var at := clampf(float(end[1]) + way * (wide * 0.5 + BRIDGE_IVY + (j % 2) * 3.0), -limit.x, limit.y)
			var foot := _level_height(j - 1) if j > 0 else 0.0
			_climb(_edge(face[0], face[1], _level_depth(j), at) + Vector3.UP * foot, face[1], _level_height(j) - foot, LEDGE_IVY_WIDE)
	_decks.append([middle, across, side, long, wide, high, level, one])


# --- Catwalks ---
# (the user, 2026-10-18: "we need to add a metal cat walk option that will add pathways
# above the mezzanines, rarely in zone 2 and then lots in zone 3")

## How far short of a free end of its stretch of wall a catwalk along it stops, metres
## (its ladder stands there, and whoever climbs it, on the ledge or the floor of that face).
const WALK_END_GAP := 1.0
## How far off the wall's face a catwalk along it stands, metres (not flush: its steel would flicker in the concrete).
const WALK_OFF_WALL := 0.03
## Of the share of halls with catwalks (MazeStyle.catwalk_share), what share of that
## have one across them; and how long one across is before it is hung from a beam
## overhead too, metres.
const WALK_ACROSS := 0.6
const WALK_HUNG := 9.0
## The chance a free end of a catwalk along a wall has a ladder up to it, and a walled
## end of one across a hall (every way over the maze has one at least).
const WALK_LADDER := 0.3
const WALK_SIDE_LADDER := 0.25
## How far along a catwalk across a hall from the wall its ladder beside it is, metres.
const WALK_LADDER_IN := 0.8

## The catwalks laid out, as dictionaries: their ends ("a", "b": the middle of the top
## of the deck), "wide", "flags" (Catwalks.Side), "beam" (how high the beam it hangs from
## is over it), the section ("ring"), the faces it runs along or between ("faces":
## [cell, step] each), whether it runs along a wall ("along"), which ends are in the air
## ("free") or at a wall ("walled"), the catwalks it meets ("links") and its ladders
## ("ladders": [where, how high] each; "laddered": which ends have one).
var _walks: Array = []
## [cell, step] -> [the catwalk along that face, from, to] (how far along the face from its middle it runs).
var _walk_faces := {}
## The piers where walls meet (MazeLayout._piers), by where they stand -> half their width:
## they stand out from the walls' faces at the corners, and catwalks keep clear of them.
var _piers_at := {}


## The catwalks (MazeStyle "Climbing": catwalks), at each section's MazeStyle.catwalk_level:
## along straight stretches of wall, on brackets from it, into the corners (meeting one
## along the wall there); across the halls, from wall to wall or from one along a wall;
## and ladders up to each way they make over the maze, from the ledge or the floor under
## them. Every stretch, hall and catwalk has numbers of its own (so turning them on or
## off moves nothing else, but the vines that would hang on the wall where they run).
func _catwalks(plan: Maze) -> void:
	for great: bool in [false, true]:
		for pier: Array in MazeLayout._piers(plan, great):
			_piers_at[Vector2(pier[0].x, pier[0].z).snappedf(0.5)] = float(pier[1].x) * 0.5
	var walled: Array = []
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or not _enter(ring) or _style.amount(&"catwalk_share") <= 0.0:
			continue
		var high := _style.catwalk_level()
		if high < 0.0:
			continue
		# Along each straight stretch of wall face (from its first face), all of it or a part.
		for step: Vector2i in Maze.STEPS:
			if not _walk_face(cell, step, high) or _walk_goes_on(cell, step, -1, high):
				continue
			var side := Vector2i(-step.y, step.x)
			var cells: Array[Vector2i] = [cell]
			while _walk_goes_on(cells[-1], step, 1, high):
				cells.append(cells[-1] + side)
			var numbers := _numbers(hash([plan.maze_seed, cell, step]), 60)
			if numbers.randf() >= _style.amount(&"catwalk_share"):
				continue
			var first := 0
			var last := cells.size() - 1
			if cells.size() > 2 and numbers.randf() < 0.5:
				first = numbers.randi_range(0, cells.size() - 2)
				last = numbers.randi_range(first + 1, cells.size() - 1)
			var faces := cells.slice(first, last + 1)
			if _walk_along(ring, faces, step, high):
				for face: Vector2i in faces:
					walled.append([face, step])
	# (nothing else is put on those faces: the vines out of bare wall)
	for face: Array in walled:
		_taken[face] = true
	# Across the halls, from wall to wall (or from one along a wall).
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell) or not _enter(ring):
			continue
		var high := _style.catwalk_level()
		if high < 0.0 or _style.amount(&"catwalk_share") <= 0.0:
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not plan.blocked(cell, -step):
				continue
			var far := _far_side(cell, step)
			if far == NOWHERE:
				continue
			var numbers := _numbers(hash([plan.maze_seed, cell, step]), 61)
			if numbers.randf() < _style.amount(&"catwalk_share") * WALK_ACROSS:
				_walk_across(ring, [cell, -step], [far, step], high, numbers)
	_walk_ladders()
	# The pieces: each catwalk, railed across an end in the air with no ladder, and its ladders.
	for walk: Dictionary in _walks:
		var flags: int = walk.flags
		if walk.free[0] and not walk.laddered[0]:
			flags |= Catwalks.Side.SHUT_START
		if walk.free[1] and not walk.laddered[1]:
			flags |= Catwalks.Side.SHUT_END
		_layout.laying_zone = walk.ring
		_layout.add_piece(MazePiece.Kind.CATWALK, Transform3D(Basis.IDENTITY, walk.a), {"to": walk.b, "width": walk.wide, "catwalk": flags, "length": walk.beam})
		for ladder: Array in walk.ladders:
			_layout.add_piece(MazePiece.Kind.LADDER, ladder[0], {"length": ladder[1]})
		_layout.laying_zone = -1


## Whether a catwalk at `high` may run along the face (cell, step): a wall nothing
## else is on, in a section's hall (not a room), high enough.
func _walk_face(cell: Vector2i, step: Vector2i, high: float) -> bool:
	var ring := _maze.ring_of(cell)
	if ring < 1 or ring > _maze.rings or not _maze.blocked(cell, step) or _taken.has([cell, step]) \
			or _maze.entrances.has(cell) or _maze.solid.has(cell) or _maze.in_room(cell):
		return false
	return _face_top(cell, step) - MazeBuilder.CORNICE.y - MazeStyle.CATWALK_UNDER_TOP >= high - 0.01


## Whether the stretch of wall along the face (cell, step) goes on straight the `way`
## way (1 or -1, along the face's side) into a face a catwalk may run along too.
func _walk_goes_on(cell: Vector2i, step: Vector2i, way: int, high: float) -> bool:
	var across := Vector2i(-step.y, step.x) * way
	var next := cell + across
	return _maze.ring_of(next) == _maze.ring_of(cell) and not _maze.blocked(cell, across) and _pier_at(cell, step, way) <= 0.0 \
			and _walk_face(next, step, high)


## How far a pier standing at the `way` end of the face (cell, step) reaches from the
## corner it stands on (half its width; 0: there is none).
func _pier_at(cell: Vector2i, step: Vector2i, way: int) -> float:
	var s := Vector3(step.x, 0.0, step.y)
	var corner := _maze.world(cell) + s * Maze.CELL * 0.5 + Vector3(-s.z, 0.0, s.x) * way * Maze.CELL * 0.5
	return _piers_at.get(Vector2(corner.x, corner.z).snappedf(0.5), 0.0)


## The rectangle a catwalk from `a` to `b`, `wide`, covers on the ground (they run along x or z).
static func _walk_rect(a: Vector3, b: Vector3, wide: float) -> Rect2:
	var rect := Rect2(Vector2(a.x, a.z), Vector2.ZERO).expand(Vector2(b.x, b.z))
	var across := Vector2(0.0, wide * 0.5) if absf(b.x - a.x) > absf(b.z - a.z) else Vector2(wide * 0.5, 0.0)
	return Rect2(rect.position - across, rect.size + across * 2.0)


## Whether a catwalk from `a` to `b`, `wide`, in section `ring`, would lie over one there
## already (meeting one, end to side, is not).
func _walk_clear(a: Vector3, b: Vector3, wide: float, ring: int) -> bool:
	var rect := _walk_rect(a, b, wide).grow(-0.05)
	for walk: Dictionary in _walks:
		if walk.ring == ring and rect.intersects(_walk_rect(walk.a, walk.b, walk.wide)):
			return false
	return true


## The catwalk running along the wall face `face` ([cell, step]) into its corner with
## the wall the `toward` way, if there is one (-1 if not).
func _walk_into_corner(face: Array, toward: Vector2i) -> int:
	var entry: Array = _walk_faces.get(face, [])
	if entry.is_empty():
		return -1
	var step: Vector2i = face[1]
	var way := 1 if Vector2i(-step.y, step.x) == toward else -1
	var corner := way * (Maze.CELL * 0.5 - _thick(face[0], toward) * 0.5)
	if (way > 0 and float(entry[2]) >= corner - 0.05) or (way < 0 and float(entry[1]) <= corner + 0.05):
		return entry[0]
	return -1


## A catwalk along the faces `cells` (one after another along the wall) on their `step`
## side, at `high`: on brackets from the wall, its railing on the hall's side; into a
## corner at an end where the wall turns across it (to the side of a catwalk along that
## wall if one runs into the corner), or stopping short of the stretch's end. Whether
## there was room for it.
func _walk_along(ring: int, cells: Array, step: Vector2i, high: float) -> bool:
	var wide := _style.catwalk_width
	var side := Vector2i(-step.y, step.x)
	var reach := {}
	var free := {}
	var links: Array = []
	for way: int in [-1, 1]:
		var end: Vector2i = cells[0] if way < 0 else cells[-1]
		var across := side * way
		var pier := _pier_at(end, step, way)
		if pier > 0.0:
			# (short of a pier standing out of the corner there)
			reach[way] = Maze.CELL * 0.5 - pier - WALK_END_GAP
			free[way] = true
		elif _maze.blocked(end, across):
			reach[way] = Maze.CELL * 0.5 - _thick(end, across) * 0.5 - WALK_OFF_WALL
			free[way] = false
			var met := _walk_into_corner([end, across], step)
			if met >= 0:
				reach[way] -= float(_walks[met].wide) + WALK_OFF_WALL
				links.append(met)
		else:
			reach[way] = Maze.CELL * 0.5 - WALK_END_GAP
			free[way] = true
	var from: float = -reach[-1]
	var to: float = (cells.size() - 1) * Maze.CELL + reach[1]
	if to - from < 2.0:
		return false
	var a := _edge(cells[0], step, wide * 0.5 + WALK_OFF_WALL, from) + Vector3.UP * high
	var b := _edge(cells[0], step, wide * 0.5 + WALK_OFF_WALL, to) + Vector3.UP * high
	if not _walk_clear(a, b, wide, ring):
		return false
	var s := Vector3(step.x, 0.0, step.y)
	var right := Vector3(side.x, 0.0, side.y).cross(Vector3.UP)
	var flags: int = (Catwalks.Side.WALL_RIGHT | Catwalks.Side.RAIL_LEFT) if right.dot(s) > 0.0 else (Catwalks.Side.WALL_LEFT | Catwalks.Side.RAIL_RIGHT)
	var index := _walks.size()
	_walks.append({"a": a, "b": b, "wide": wide, "flags": flags, "beam": 0.0, "ring": ring, "faces": cells.map(func(cell: Vector2i) -> Array: return [cell, step]),
		"along": true, "free": [free[-1], free[1]], "walled": [false, false], "links": links, "ladders": [], "laddered": [false, false]})
	for met: int in links:
		_walks[met].links.append(index)
	for k in cells.size():
		_walk_faces[[cells[k], step]] = [index, from - k * Maze.CELL, to - k * Maze.CELL]
	return true


## A catwalk across the hall at `high` from the wall face `one` to the face `other` across
## from it ([cell, step] each), as `numbers` say: from a catwalk along either wall if one
## runs there (meeting its side), else from the wall itself on struts; hung from a beam
## under the walls' tops too if it is long; railed on one side or both.
func _walk_across(ring: int, one: Array, other: Array, high: float, numbers: RandomNumberGenerator) -> void:
	var wide := _style.catwalk_width
	for face: Array in [one, other]:
		if not _walk_faces.has(face) and not _walk_face(face[0], face[1], high):
			return
	var room := Vector2(_room(one[0], one[1], -1), _room(one[0], one[1], 1)) - Vector2.ONE * (wide * 0.5 + 0.6)
	var far_room := Vector2(_room(other[0], other[1], -1), _room(other[0], other[1], 1)) - Vector2.ONE * (wide * 0.5 + 0.6)
	# (clear of the piers at the faces' ends)
	for way: int in [-1, 1]:
		var k := 0 if way < 0 else 1
		if _pier_at(one[0], one[1], way) > 0.0:
			room[k] = minf(room[k], Maze.CELL * 0.5 - _pier_at(one[0], one[1], way) - wide * 0.5 - 0.6)
		if _pier_at(other[0], other[1], way) > 0.0:
			far_room[k] = minf(far_room[k], Maze.CELL * 0.5 - _pier_at(other[0], other[1], way) - wide * 0.5 - 0.6)
	# (straight across: along the far wall, which runs the other way, it is at -along)
	var lowest := maxf(-room.x, -far_room.y)
	var highest := minf(room.y, far_room.x)
	if lowest > highest:
		return
	var along := numbers.randf_range(lowest, highest)
	var pick := numbers.randf()
	# (from somewhere along a catwalk along either wall, to meet it)
	for k in 2:
		var entry: Array = _walk_faces.get([one, other][k], [])
		if entry.is_empty():
			continue
		var turn := 1.0 if k == 0 else -1.0
		var lo := maxf(lowest, minf(float(entry[1]) * turn, float(entry[2]) * turn) + wide * 0.5)
		var hi := minf(highest, maxf(float(entry[1]) * turn, float(entry[2]) * turn) - wide * 0.5)
		if lo <= hi:
			along = lerpf(lo, hi, pick)
			break
	# Its ends: meeting a catwalk along the wall, or at the wall itself (well clear of one
	# along it elsewhere, which its ladder would come up through).
	var links: Array = []
	var outs: Array[float] = []
	for k in 2:
		var x := along if k == 0 else -along
		var entry: Array = _walk_faces.get([one, other][k], [])
		if not entry.is_empty() and x - wide * 0.5 >= float(entry[1]) - 0.01 and x + wide * 0.5 <= float(entry[2]) + 0.01:
			links.append(entry[0])
			outs.append(float(_walks[entry[0]].wide) + WALK_OFF_WALL)
		elif not entry.is_empty() and x + wide * 0.5 + 1.6 > float(entry[1]) and x - wide * 0.5 - 1.6 < float(entry[2]):
			return
		else:
			links.append(-1)
			outs.append(0.02)
	var a := _edge(one[0], one[1], outs[0], along) + Vector3.UP * high
	var b := _edge(other[0], other[1], outs[1], -along) + Vector3.UP * high
	var long := a.distance_to(b)
	if long < 2.0 or not _walk_clear(a, b, wide, ring):
		return
	var flags := 0
	if _style.catwalk_railings == 1:
		flags = Catwalks.Side.RAIL_LEFT | Catwalks.Side.RAIL_RIGHT
	else:
		flags = Catwalks.Side.RAIL_LEFT if numbers.randf() < 0.5 else Catwalks.Side.RAIL_RIGHT
	if links[0] < 0:
		flags |= Catwalks.Side.WALL_START
	if links[1] < 0:
		flags |= Catwalks.Side.WALL_END
	var beam := 0.0
	if long > WALK_HUNG:
		var top := minf(_face_top(one[0], one[1]), _face_top(other[0], other[1])) - MazeBuilder.CORNICE.y - 0.4
		if top - high > 1.5:
			beam = top - high
			flags |= Catwalks.Side.HUNG
	var index := _walks.size()
	var met := links.filter(func(link: int) -> bool: return link >= 0)
	_walks.append({"a": a, "b": b, "wide": wide, "flags": flags, "beam": beam, "ring": ring, "faces": [one, other],
		"along": false, "free": [false, false], "walled": [links[0] < 0, links[1] < 0], "links": met, "ladders": [], "laddered": [false, false]})
	for link: int in met:
		_walks[link].links.append(index)


## Ladders up to the catwalks: at a free end of one along a wall now and then, beside
## one across a hall near a wall now and then; and one at least up to every way they
## make over the maze (catwalks meeting each other), each catwalk with numbers of its own.
func _walk_ladders() -> void:
	var group := range(_walks.size())
	var find := func(i: int) -> int:
		while group[i] != i:
			i = group[i]
		return i
	for i in _walks.size():
		for j: int in _walks[i].links:
			group[find.call(i)] = find.call(j)
	var reached := {}
	for i in _walks.size():
		var walk: Dictionary = _walks[i]
		_enter(walk.ring)
		var numbers := _numbers(hash([_maze.maze_seed, (walk.a as Vector3).snappedf(0.01)]), 62)
		for end in 2:
			var roll := numbers.randf()
			if walk.free[end] and roll < WALK_LADDER:
				_end_ladder(walk, end)
			elif walk.walled[end] and roll < WALK_SIDE_LADDER:
				_side_ladder(walk, end, numbers.randf() < 0.5)
		if not walk.ladders.is_empty():
			reached[find.call(i)] = true
	for i in _walks.size():
		var walk: Dictionary = _walks[i]
		if reached.has(find.call(i)):
			continue
		_enter(walk.ring)
		var done := false
		for end in 2:
			if not done and walk.free[end]:
				done = _end_ladder(walk, end)
		for end in 2:
			if not done and walk.walled[end]:
				done = _side_ladder(walk, end, true)
		if not done and walk.along:
			done = _hall_ladder(walk)
		if done:
			reached[find.call(i)] = true


## A ladder of `walk` standing at `p` (on the ground, its +Z `out` from the catwalk) up
## to it from what is under it along the face (cell, step), `x` out from the wall: the
## top of the highest ledge there, or the floor. Whether there was height for one.
func _walk_ladder(walk: Dictionary, p: Vector3, out: Vector3, cell: Vector2i, step: Vector2i, x: float) -> bool:
	var high: float = walk.a.y
	var foot := _foot_under(cell, step, x, high)
	if high - foot < 2.0:
		return false
	walk.ladders.append([Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), Vector3(p.x, foot, p.z)), high - foot])
	return true


## A ladder at end `end` (0 its start, 1 its end) of a catwalk along a wall, up from the ledge or floor there.
func _end_ladder(walk: Dictionary, end: int) -> bool:
	var a: Vector3 = walk.a
	var b: Vector3 = walk.b
	var out := (a - b).normalized() if end == 0 else (b - a).normalized()
	out.y = 0.0
	var p: Vector3 = (a if end == 0 else b) + out * Catwalks.LADDER_OUT
	var step: Vector2i = walk.faces[0][1]
	if not _walk_ladder(walk, p, out, _maze.cell_at(p), step, float(walk.wide) * 0.5):
		return false
	walk.laddered[end] = true
	return true


## A ladder beside a catwalk across a hall, WALK_LADDER_IN from the wall at end `end`, on
## its right side (or left), up from the ledge or floor along that wall.
func _side_ladder(walk: Dictionary, end: int, on_right: bool) -> bool:
	var a: Vector3 = walk.a
	var b: Vector3 = walk.b
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var out := along.cross(Vector3.UP) * (1.0 if on_right else -1.0)
	var at: Vector3 = (a + along * WALK_LADDER_IN) if end == 0 else (b - along * WALK_LADDER_IN)
	var p := at + out * (float(walk.wide) * 0.5 + Catwalks.LADDER_OUT)
	var face: Array = walk.faces[end]
	return _walk_ladder(walk, p, out, face[0], face[1], WALK_LADDER_IN + 0.15)


## A ladder beside a catwalk along a wall, on the hall's side, where nothing meets it
## (a catwalk across): up from the ledge under it or the floor.
func _hall_ladder(walk: Dictionary) -> bool:
	var a: Vector3 = walk.a
	var b: Vector3 = walk.b
	var step: Vector2i = walk.faces[0][1]
	var out := -Vector3(step.x, 0.0, step.y)
	var long := a.distance_to(b)
	for t: float in [0.5, 0.25, 0.75, 0.1, 0.9]:
		var at := a.lerp(b, t)
		var clear := true
		for link: int in walk.links:
			for end: Vector3 in [_walks[link].a, _walks[link].b]:
				if Vector2(end.x - at.x, end.z - at.z).length() < float(_walks[link].wide) * 0.5 + float(walk.wide) * 0.5 + 1.0:
					clear = false
		if not clear or long * minf(t, 1.0 - t) < 1.0:
			continue
		var p := at + out * (float(walk.wide) * 0.5 + Catwalks.LADDER_OUT)
		return _walk_ladder(walk, p, out, _maze.cell_at(p), step, float(walk.wide) + Catwalks.LADDER_OUT)
	return false


# --- The vines ---
# (the user, 2026-10-18: "the vines are hung on whats there. There should be 3 sliders-
# one for mezzanine crossing density, one for hanging straight down vine desnity, a
# thirdn for random corssing vine desnity ... and fourth and final for overall vine
# density. There hsould also be a single height limit as a percentage of hte wall height")

## What a vine is hung on: the edge of a ledge, bare wall, or a thing on the wall (a
## terrace, a bracket, a sewer pipe's platform, a concrete bridge's side, a vent, an
## outlet, a culvert, a junction box), or the side of a catwalk.
enum Anchor { LEDGE, WALL, THING, CATWALK }
## How strongly each pulls vines to it, hanging and strung across: the hanging and
## random crossing densities are the chance for each ledge edge (at each level); bare
## wall faces have this much of it, things on the walls this much (at most every one),
## the sides of catwalks this much.
const PULL := {Anchor.LEDGE: Vector2(1.0, 1.0), Anchor.WALL: Vector2(0.3, 0.3), Anchor.THING: Vector2(4.0, 1.5), Anchor.CATWALK: Vector2(1.5, 1.0)}
## How high up its band of wall a vine out of bare wall comes out: lowest and highest,
## metres over the floor (or the top ledge under it).
const WALL_VINE_HEIGHTS := Vector2(4.0, 14.0)
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
## The props on the walls vines are hung on.
const HUNG_ON := [MazeProps.Prop.VENT, MazeProps.Prop.ROUND_VENT, MazeProps.Prop.OUTLET, MazeProps.Prop.CULVERT, MazeProps.Prop.JUNCTION_BOX]

## [cell, step] -> the tops of the things on that face a vine strung across to it may
## be tied to: [where, how far along the face].
var _targets := {}


## Hangs the vines, by each section's MazeStyle "Vines", on what was laid out: by this
## (ledges, terraces, brackets, sewer pipes, concrete bridges) and by MazeProps (vents,
## outlets, culverts, junction boxes), and on bare wall (then the placer is freed). Each
## place a vine may hang has numbers of its own, apart from everything else's, so that
## the vines' rules change only the vines.
func hang_vines() -> void:
	# (where there are things on the walls already, to keep clear of)
	var near := {}
	for piece in _layout.pieces(MazePiece.Kind.IVY):
		_note(near, piece.position, piece.width * 0.5)
	for piece in _layout.pieces(MazePiece.Kind.PROP):
		if piece.prop in HUNG_ON:
			_note(near, piece.position, piece.basis.get_scale().x * 0.6)
	# (and the catwalks' ladders, to climb clear of vines)
	for walk: Dictionary in _walks:
		for ladder: Array in walk.ladders:
			_note(near, (ladder[0] as Transform3D).origin, 0.6)
	_mezzanine_crossings(near)
	for anchor: Dictionary in _anchors():
		_hang_on(anchor, near)
	# (and from the vines strung across, now they are all there)
	_strand_vines()


## How strongly a vine strung across pulls vines to hang from it, against a ledge's edge
## (MazeStyle.hanging_vine_density times this, for each); how far from its ends they hang
## at least (a share of it); how far apart along it, at least, metres; and how high over
## what is under them they end at least, metres.
const STRAND_PULL := 0.8
const STRAND_ENDS := 0.18
const STRAND_APART := 1.6
const STRAND_VINE_CLEAR := 2.4


## Vines hanging from the vines strung across the halls (the user, 2026-10-19: "hanging
## vines should be able to hang from crossing vines"): for each strung vine of the sections
## being laid out, as its section's hanging and overall densities say, each with numbers of
## its own (from where it is strung), so no other vine moves. From points along it (as it
## hangs at rest), clear of its ends, under the height limit, down towards the floor (or
## the ledge or catwalk under them) and ending well clear of it. In the game their tops go
## where those points go (VineStrand.hang): as it sags, sways, is walked and is cut.
func _strand_vines() -> void:
	for piece in _layout.pieces(MazePiece.Kind.STRAND):
		var ring := MazeLayout.zone_of(_maze, piece)
		if ring < 1 or ring > _maze.rings or not _enter(ring):
			continue
		var a := piece.position
		var b := piece.bridge_end()
		var grounded := piece.strand_held(false) == Vine.Held.GROUND or piece.strand_held(true) == Vine.Held.GROUND
		var gap := a.distance_to(b)
		if grounded or gap < 3.0:
			continue
		var numbers := _numbers(hash([_maze.maze_seed, a.snappedf(0.01), b.snappedf(0.01)]), 70)
		var chance := _style.hanging_vine_density * _style.amount(&"vine_density") * STRAND_PULL
		var count := _count(chance, numbers, gap > 6.0)
		if count <= 0:
			continue
		# (as it hangs at rest: RopeBridge's sag for a strand of its length)
		var most := VineStrand.MOST_SAG
		var sag := sqrt(3.0 / 8.0 * gap * maxf(gap * minf(VineStrand.SLACK, 1.0 + 8.0 / 3.0 * pow(most / gap, 2.0)) - gap, 0.0))
		var limit := _maze.maze_wall_height(ring) * _style.vine_height_limit / 100.0
		var taken: Array[float] = []
		_layout.laying_zone = ring
		for k in count:
			var t := numbers.randf_range(STRAND_ENDS, 1.0 - STRAND_ENDS)
			var pick := numbers.randf()
			if taken.any(func(other: float) -> bool: return absf(other - t) * gap < STRAND_APART):
				continue
			var top := a.lerp(b, t) + Vector3.DOWN * (4.0 * t * (1.0 - t) * sag + VineStrand.HUNG_UNDER)
			var longest := top.y - _floor_under(top, ring) - STRAND_VINE_CLEAR
			if top.y > limit or longest < 1.5:
				continue
			taken.append(t)
			var length := lerpf(minf(2.0, longest), longest, pick)
			_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, top), {"length": length, "hold": Vector3.ZERO, "held": Vine.Held.STRAND, "reach": 0.0})
		_layout.laying_zone = -1


## How high what is under `point` (in section `ring`) is: the floor, the top of a ledge
## along a wall of its cell that reaches out under it, or a catwalk under it.
func _floor_under(point: Vector3, ring: int) -> float:
	var cell := _maze.cell_at(point)
	var foot := 0.0
	for step: Vector2i in Maze.STEPS:
		if _maze.blocked(cell, step):
			var x := (point - _edge(cell, step, 0.0, 0.0)).dot(-Vector3(step.x, 0.0, step.y))
			foot = maxf(foot, _foot_under(cell, step, x, point.y))
	for walk: Dictionary in _walks:
		if walk.ring == ring and float(walk.a.y) < point.y and _walk_rect(walk.a, walk.b, walk.wide).grow(0.4).has_point(Vector2(point.x, point.z)):
			foot = maxf(foot, float(walk.a.y))
	return foot


## How many vines there are of a density `chance` at one place, as `numbers` say (its
## first number always drawn): the whole number of it, and one more by chance; one at
## most if not `many`.
static func _count(chance: float, numbers: RandomNumberGenerator, many: bool) -> int:
	var roll := numbers.randf()
	var count := floori(maxf(chance, 0.0))
	if roll < chance - count:
		count += 1
	return count if many else mini(count, 1)


## How high vines may go on the face (cell, step): MazeStyle.vine_height_limit of its height.
func _limit(cell: Vector2i, step: Vector2i) -> float:
	return _face_top(cell, step) * _style.vine_height_limit / 100.0


## How high what is under a point `x` out from the face (cell, step) and `y` high is:
## the top of the highest level of ledge along it under it that reaches out past it, or the floor.
func _foot_under(cell: Vector2i, step: Vector2i, x: float, y: float) -> float:
	var foot := 0.0
	for level in int(_level_counts.get([cell, step], 0)):
		if _level_height(level) < y - 0.5 and _level_depth(level) > x + 0.15:
			foot = maxf(foot, _level_height(level))
	return foot


## Vines strung across the halls with ledges along both walls, edge to edge
## (MazeStyle.mezzanine_crossing_density): at the same level, and swept down from a
## level to the one under it on the far side; none over the height limit.
func _mezzanine_crossings(near: Dictionary) -> void:
	var plan := _maze
	for i in plan.size * plan.size:
		var cell := Vector2i(i % plan.size, i / plan.size)
		var ring := plan.ring_of(cell)
		if ring < 1 or ring > plan.rings or plan.entrances.has(cell) or plan.solid.has(cell):
			continue
		if not _enter(ring):
			continue
		var chance := _style.mezzanine_crossing_density * _style.amount(&"vine_density")
		if chance <= 0.0:
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _level_counts.has([cell, -step]):
				continue
			var far := _far_side(cell, step)
			if far == NOWHERE or not _level_counts.has([far, step]):
				continue
			var one := [cell, -step]
			var other := [far, step]
			var counts := [int(_level_counts[one]), int(_level_counts[other])]
			var limit := minf(_limit(cell, -step), _limit(far, step))
			var hall := hash([plan.maze_seed, cell, step])
			_layout.laying_zone = ring
			for level in maxi(counts[0], counts[1]):
				if _level_height(level) > limit:
					break
				# (at the same level, both sides)
				var numbers := _numbers(hall, 20 + level)
				if level < mini(counts[0], counts[1]):
					for k in _count(chance, numbers, true):
						_ledge_strand(one, other, level, numbers, near)
				# (down from this level on one side to the one under it on the other)
				numbers = _numbers(hall, 30 + level)
				var ways: Array = []
				if level > 0 and counts[0] > level and counts[1] >= level:
					ways.append([one, other])
				if level > 0 and counts[1] > level and counts[0] >= level:
					ways.append([other, one])
				for k in _count(chance, numbers, true):
					if not ways.is_empty():
						var way: Array = ways[numbers.randi() % ways.size()]
						_swept_vine(way[0], way[1], level, numbers, near)
			_layout.laying_zone = -1


## A vine strung across the hall between the edges of the ledges at `level` along
## the faces `one` and `other` ([cell, step] each): under the ledges of the first
## section, across the floor's channel and over the top ledges of the second.
func _ledge_strand(one: Array, other: Array, level: int, numbers: RandomNumberGenerator, near: Dictionary) -> void:
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
	_note(near, a, 0.0)
	_note(near, b, 0.0)


## A vine swept down across the hall from the edge of the ledge at `level` along
## the face `from` to the edge of the one a level under it along `to`.
func _swept_vine(from: Array, to: Array, level: int, numbers: RandomNumberGenerator, near: Dictionary) -> void:
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
	_note(near, a, 0.0)
	_note(near, b, 0.0)


## Everything a vine may be hung on, in the sections being laid out, as dictionaries:
## its section ("ring"), the face it is on ("cell", "step"), what it is ("kind", an
## Anchor), where on it a vine is held ("at": on its edge, or on the wall's face), the
## way out of what holds it ("out") and along it ("side"), how far along it either way
## a vine may be ("span"), how it is held ("held", Vine.Held), how far out from it a
## vine hanging from it hangs ("reach"), how high what is under it is ("foot"), whether
## a vine hanging from it reaches all the way down to that ("full"), whether one may be
## strung across from it ("crosses"), where its ivy is along it ("ivy"), and its numbers' seed ("key").
func _anchors() -> Array:
	var anchors: Array = []
	var seed_of := func(kind: int, at: Vector3) -> int: return hash([_maze.maze_seed, kind, at.snappedf(0.01)])
	# The edges of the ledges, at each level.
	for face: Array in _level_counts:
		var cell: Vector2i = face[0]
		var step: Vector2i = face[1]
		var ring := _maze.ring_of(cell)
		if not _enter(ring):
			continue
		var span := minf(_room(cell, step, -1), _room(cell, step, 1)) - 1.0
		if span < 0.0:
			continue
		for level in int(_level_counts[face]):
			var at := _edge(cell, step, _level_depth(level), 0.0) + Vector3.UP * _level_height(level)
			anchors.append(_anchor(ring, cell, step, Anchor.LEDGE, at, span, Vine.Held.LIP, LIP_VINE_OUT,
				_level_height(level - 1) if level > 0 else 0.0, true, hash([_maze.maze_seed, cell, step, level])))
	# Terraces, brackets and the sewer pipes' platforms.
	for top: Array in _ledge_tops:
		var cell: Vector2i = top[0]
		var step: Vector2i = top[1]
		var ring := _maze.ring_of(cell)
		if not _enter(ring):
			continue
		var at := _edge(cell, step, top[2], top[3]) + Vector3.UP * float(top[4])
		var foot: float = top[6] if float(top[6]) >= 0.0 else _foot_under(cell, step, float(top[2]) + LIP_VINE_OUT, at.y)
		var anchor := _anchor(ring, cell, step, Anchor.THING, at, float(top[5]) * 0.5 - 0.5, Vine.Held.LIP, LIP_VINE_OUT, foot, true, seed_of.call(Anchor.THING, at))
		anchor["ivy"] = float(top[7]) - float(top[3])
		anchors.append(anchor)
		_target(cell, step, at)
	# The sides of the concrete bridges (vines hang from them, none is strung from them).
	for deck: Array in _decks:
		var face: Array = deck[7]
		var ring := _maze.ring_of(face[0])
		if not _enter(ring):
			continue
		var level: int = deck[6]
		for way: float in [1.0, -1.0]:
			var at: Vector3 = deck[0] + deck[2] * way * float(deck[4]) * 0.5
			at.y = deck[5]
			var anchor := _anchor(ring, face[0], face[1], Anchor.THING, at, float(deck[3]) * 0.2, Vine.Held.LIP, 0.25,
				_level_height(level - 2) if level >= 2 else 0.0, true, seed_of.call(Anchor.THING, at))
			anchor["out"] = deck[2] * way
			anchor["side"] = deck[1]
			anchor["crosses"] = false
			anchors.append(anchor)
	# The catwalks: over the hall's side of one along a wall (strung across from it too, and
	# tied to from across the hall), both sides of one across a hall (its middle, over the floor).
	for walk: Dictionary in _walks:
		var ring: int = walk.ring
		if not _enter(ring):
			continue
		var a: Vector3 = walk.a
		var b: Vector3 = walk.b
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var long := a.distance_to(b)
		var wide: float = walk.wide
		if walk.along:
			# (a place on each face it runs along: that face's far side and floor are its vines')
			for face: Array in walk.faces:
				var cell: Vector2i = face[0]
				var step: Vector2i = face[1]
				var entry: Array = _walk_faces[face]
				var lo := maxf(float(entry[1]), -Maze.CELL * 0.5)
				var hi := minf(float(entry[2]), Maze.CELL * 0.5)
				var at := _edge(cell, step, wide + WALK_OFF_WALL, (lo + hi) * 0.5) + Vector3.UP * (a.y - 0.05)
				var anchor := _anchor(ring, cell, step, Anchor.CATWALK, at, (hi - lo) * 0.5 - 1.0, Vine.Held.LIP, 0.15,
					_foot_under(cell, step, wide + 0.15, at.y), true, seed_of.call(Anchor.CATWALK, at))
				anchor["side"] = along
				anchors.append(anchor)
				_target(cell, step, at)
			continue
		# (one across a hall: over the floor, clear of the ledges either side; none strung from it)
		var face: Array = walk.faces[0]
		var span := long * 0.5 - 1.0
		for level in mini(int(_level_counts.get(face, 0)), _style.mezzanine_count()):
			span = minf(span, long * 0.5 - _level_depth(level) - 0.8)
		for out: Vector3 in [along.cross(Vector3.UP), -along.cross(Vector3.UP)]:
			var at := (a + b) * 0.5 + out * wide * 0.5 + Vector3.DOWN * 0.05
			var anchor := _anchor(ring, face[0], face[1], Anchor.CATWALK, at, span, Vine.Held.LIP, 0.15, 0.0, true, seed_of.call(Anchor.CATWALK, at))
			anchor["out"] = out
			anchor["side"] = along
			anchor["crosses"] = false
			anchors.append(anchor)
	# Vents, outlets, culverts and junction boxes (MazeProps): over the top of each.
	for piece in _layout.pieces(MazePiece.Kind.PROP):
		if not (piece.prop in HUNG_ON):
			continue
		var out := piece.basis.orthonormalized().z
		out = Vector3(out.x, 0.0, out.z).normalized()
		var cell := _maze.cell_at(piece.position + out * 0.6)
		var step := Vector2i(-roundi(out.x), -roundi(out.z))
		var ring := _maze.ring_of(cell)
		if ring < 1 or ring > _maze.rings or _maze.solid.has(cell) or not _maze.blocked(cell, step) or not _enter(ring):
			continue
		var big := piece.basis.get_scale().x
		# (its top's front edge, and how wide it is)
		var top: Vector2 = {MazeProps.Prop.VENT: Vector2(0.45, 0.1), MazeProps.Prop.ROUND_VENT: Vector2(0.56, 0.1),
			MazeProps.Prop.OUTLET: Vector2(MazeProps.OUTLET_RADIUS, MazeProps.OUTLET_REACH), MazeProps.Prop.CULVERT: Vector2(1.44, 0.18),
			MazeProps.Prop.JUNCTION_BOX: Vector2(0.5, 0.33)}[piece.prop] * big
		var half: float = {MazeProps.Prop.VENT: 0.6, MazeProps.Prop.ROUND_VENT: 0.4, MazeProps.Prop.OUTLET: 0.0,
			MazeProps.Prop.CULVERT: 1.0, MazeProps.Prop.JUNCTION_BOX: 0.35}[piece.prop] * big
		var at := piece.position + Vector3.UP * top.x + out * top.y
		var x := (at - _edge(cell, step, 0.0, 0.0)).dot(out)
		var anchor := _anchor(ring, cell, step, Anchor.THING, at, half * 0.6, Vine.Held.LIP, 0.1, _foot_under(cell, step, x + 0.1, at.y), false, seed_of.call(Anchor.THING, at))
		anchor["out"] = out
		anchors.append(anchor)
		_target(cell, step, at)
	# Bare wall: a place on each face nothing else has, as its own numbers say (under
	# the first ledge, or over the top one, where it has ledges).
	for i in _maze.size * _maze.size:
		var cell := Vector2i(i % _maze.size, i / _maze.size)
		var ring := _maze.ring_of(cell)
		if ring < 1 or ring > _maze.rings or _maze.entrances.has(cell) or _maze.solid.has(cell) or not _enter(ring):
			continue
		for step: Vector2i in Maze.STEPS:
			if not _maze.blocked(cell, step) or _taken.has([cell, step]):
				continue
			var numbers := _numbers(hash([_maze.maze_seed, cell, step]), 50)
			var levels := int(_level_counts.get([cell, step], 0))
			var band := _band(cell, step, levels, levels > 0 and numbers.randf() < 0.5)
			var high := minf(band.x + numbers.randf_range(WALL_VINE_HEIGHTS.x, WALL_VINE_HEIGHTS.y), band.y)
			var lowest := -_room(cell, step, -1) + WALL_VINE_ENDS
			var highest := _room(cell, step, 1) - WALL_VINE_ENDS
			if high - band.x < 3.0 or lowest > highest:
				continue
			# (under the ledges, out of the first level's front)
			var face := _level_depth(0) if levels > 0 and band.x <= 0.0 else 0.0
			var at := _edge(cell, step, face, numbers.randf_range(lowest, highest)) + Vector3.UP * high
			anchors.append(_anchor(ring, cell, step, Anchor.WALL, at, 0.0, Vine.Held.FACE, WALL_GROWN_OUT, band.x, false, seed_of.call(Anchor.WALL, at)))
	return anchors


func _anchor(ring: int, cell: Vector2i, step: Vector2i, kind: Anchor, at: Vector3, span: float, held: int, reach: float, foot: float, full: bool, key: int) -> Dictionary:
	var s := Vector3(step.x, 0.0, step.y)
	return {"ring": ring, "cell": cell, "step": step, "kind": kind, "at": at, "out": -s, "side": Vector3(-s.z, 0.0, s.x),
		"span": maxf(span, 0.0), "held": held, "reach": reach, "foot": foot, "full": full, "crosses": true, "ivy": INF, "key": key}


## Notes the top of a thing on the face (cell, step) at `at`, for vines strung across to it.
func _target(cell: Vector2i, step: Vector2i, at: Vector3) -> void:
	if not _targets.has([cell, step]):
		_targets[[cell, step]] = []
	_targets[[cell, step]].append(at)


## The vines on `anchor` (see _anchors), as its section's densities say, each with numbers
## of its own: hanging straight down from it, and strung or swept across the hall from it.
func _hang_on(anchor: Dictionary, near: Dictionary) -> void:
	var ring: int = anchor.ring
	if not _enter(ring):
		return
	var overall := _style.amount(&"vine_density")
	var at: Vector3 = anchor.at
	if overall <= 0.0 or at.y > _limit(anchor.cell, anchor.step):
		return
	var pull: Vector2 = PULL[anchor.kind]
	var many: bool = anchor.span > 1.0
	var hang_numbers := _numbers(anchor.key, 1)
	var cross_numbers := _numbers(anchor.key, 2)
	var hangs := _count(_style.hanging_vine_density * overall * pull.x, hang_numbers, many)
	var crosses := _count(_style.random_crossing_density * overall * pull.y, cross_numbers, many)
	_layout.laying_zone = ring
	var crossed := false
	if anchor.crosses:
		for k in crosses:
			crossed = _cross(anchor, cross_numbers, near) or crossed
	# (out of bare wall a vine either hangs or is strung across, not both from one place)
	if not (crossed and anchor.kind == Anchor.WALL):
		for k in hangs:
			_hang(anchor, hang_numbers, near)
	_layout.laying_zone = -1


## Where along `anchor` a vine is, as `numbers` say: anywhere along it, clear of its ivy.
func _along(anchor: Dictionary, numbers: RandomNumberGenerator) -> float:
	var span: float = anchor.span
	var x := numbers.randf_range(-span, span) if span > 0.0 else 0.0
	var ivy: float = anchor.ivy
	if is_finite(ivy) and absf(x - ivy) < 1.6:
		x = clampf(ivy + (1.6 if ivy < 0.0 else -1.6), -span, span)
	return x


## A vine hanging straight down from `anchor`: to a hop over what is under it, or (out
## of bare wall, or over a prop) a random way down.
func _hang(anchor: Dictionary, numbers: RandomNumberGenerator, near: Dictionary) -> void:
	var out: Vector3 = anchor.out
	var top: Vector3 = anchor.at + anchor.side * _along(anchor, numbers) + out * float(anchor.reach)
	var longest: float = top.y - float(anchor.foot) - LOW_VINE_CLEAR
	if longest < 1.5:
		return
	# (things on the walls are hung on where they are; elsewhere, clear of what is there)
	if anchor.kind != Anchor.THING and not _clear_of(near, top, anchor.ring):
		return
	var length := longest if anchor.full else numbers.randf_range(minf(2.0, longest), longest)
	_layout.add_piece(MazePiece.Kind.VINE, Transform3D(Basis.IDENTITY, top), {"length": length, "hold": -out, "held": anchor.held, "reach": anchor.reach})
	_note(near, top, 0.0)


## A vine strung across the hall from `anchor`: to a thing on the far wall about
## across from it (a bracket, a vent, a junction box...), or to the far wall itself,
## lower down (higher, from low down), or swept down to the floor part way across.
## Clear of the ledges both sides, and under the height limit. Whether there was room.
func _cross(anchor: Dictionary, numbers: RandomNumberGenerator, near: Dictionary) -> bool:
	var cell: Vector2i = anchor.cell
	var step: Vector2i = anchor.step
	var across := -step
	var ring: int = anchor.ring
	var held: int = anchor.held
	var a: Vector3 = anchor.at + anchor.side * _along(anchor, numbers) + (anchor.out * VineStrand.TIED_OUT if held == Vine.Held.FACE else Vector3.ZERO)
	var levels := int(_level_counts.get([cell, step], 0))
	var far := _far_side(cell, across)
	var far_levels := int(_level_counts.get([far, across], 0)) if far != NOWHERE else 0
	# (between ledges both sides: a mezzanine crossing, not this)
	if anchor.kind == Anchor.LEDGE and far_levels > 0:
		return false
	if anchor.kind == Anchor.WALL and not _clear_of(near, a, ring):
		return false
	var s := Vector3(step.x, 0.0, step.y)
	var wide := Maze.CELL * 0.8
	if far != NOWHERE:
		wide = absf((_edge(far, across, 0.0, 0.0) - _edge(cell, step, 0.0, 0.0)).dot(s))
	var along := (a - _edge(cell, step, 0.0, 0.0)).dot(anchor.side)
	var to_floor := far == NOWHERE or numbers.randf() < 0.35
	var b := Vector3.INF
	var held_end := Vine.Held.FACE
	if not to_floor:
		var far_limit := minf(_limit(far, across), _face_top(far, across) - MazeBuilder.CORNICE.y - 1.0)
		# (lower down, or from low down up)
		var lowest := a.y - 9.0
		var highest := (a.y + 8.0) if a.y < 6.0 else a.y + 1.5
		# (a thing on the far wall about across from it, now and then)
		var tie := numbers.randf() < 0.7
		var far_side := Vector3(-across.y, 0.0, across.x)
		var best := INF
		for target: Vector3 in _targets.get([far, across], []):
			var off := absf((target - _edge(far, across, 0.0, 0.0)).dot(far_side) + along)
			if tie and off < 6.0 and off < best and target.y > lowest and target.y < highest and target.y <= far_limit:
				best = off
				b = target
		if b.is_finite():
			held_end = Vine.Held.LIP
		else:
			var low := a.y - numbers.randf_range(1.0, 7.0) if a.y > 6.0 else a.y + numbers.randf_range(3.0, 8.0)
			low = minf(low, far_limit)
			var far_room := Vector2(_room(far, across, -1), _room(far, across, 1)) - Vector2.ONE * WALL_VINE_ENDS
			if low < 2.0 or -far_room.x > far_room.y:
				return false
			b = _edge(far, across, VineStrand.TIED_OUT, clampf(-along + numbers.randf_range(-3.0, 3.0), -far_room.x, far_room.y)) + Vector3.UP * low
			if not _clear_of(near, b, ring):
				return false
	else:
		# (to the floor part way across: not out under the far wall's ledge)
		var far_ledge := _level_depth(0) + 0.5 if far_levels > 0 else 0.5
		var out := numbers.randf_range(maxf(GROUND_ROOT, wide * 0.3), minf(wide * 0.75, wide - far_ledge))
		var room := Vector2(_room(cell, step, -1), _room(cell, step, 1)) - Vector2.ONE * WALL_VINE_ENDS
		if out < GROUND_ROOT or a.y < VineStrand.GROUND_SAG * 4.0 + 1.0 or -room.x > room.y:
			return false
		b = _edge(cell, step, out, clampf(along + numbers.randf_range(-3.0, 3.0), -room.x, room.y))
		held_end = Vine.Held.GROUND
	if not _sweep_clears(a, b, [cell, step], levels, far_levels, wide, held_end == Vine.Held.GROUND):
		return false
	_layout.add_piece(MazePiece.Kind.STRAND, Transform3D(Basis.IDENTITY, a), {"to": b, "held": held, "held_end": held_end})
	_note(near, a, 0.0)
	_note(near, b, 0.0)
	return true


## Notes something on a wall at `at`, `wide` along it either side, in `near` (cell -> [[where, how wide, section]]).
func _note(near: Dictionary, at: Vector3, wide: float) -> void:
	var key := _maze.cell_at(at)
	if not near.has(key):
		near[key] = []
	near[key].append([Vector2(at.x, at.z), wide, _maze.ring_of(key)])


## Whether `at` is WALL_VINE_CLEAR from everything of section `ring` noted in `near` (see _note).
func _clear_of(near: Dictionary, at: Vector3, ring: int) -> bool:
	var cell := _maze.cell_at(at)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for noted: Array in near.get(cell + Vector2i(dx, dy), []):
				if int(noted[2]) == ring and (noted[0] as Vector2).distance_to(Vector2(at.x, at.z)) < WALL_VINE_CLEAR + float(noted[1]):
					return false
	return true


## The band of the face (cell, step) that has `levels` levels of ledge a vine may grow
## out of: (its foot, its top), from the floor to under the cornice, or with ledges, to
## under the first ledge's top (out of its front: the first level is a step of stone from
## the floor), or (`over`) from the top ledge to under the cornice.
func _band(cell: Vector2i, step: Vector2i, levels: int, over: bool) -> Vector2:
	var top := _face_top(cell, step) - MazeBuilder.CORNICE.y - 1.0
	if levels <= 0:
		return Vector2(0.0, top)
	if over:
		return Vector2(_level_height(levels - 1), top)
	return Vector2(0.0, _level_height(0) - 1.0)


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
	# (the first level a step of stone from the floor, each over it from the one under it)
	if x < _level_depth(0) + m and y < _level_height(0) + m:
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
