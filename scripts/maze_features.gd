class_name MazeFeatures
extends Node3D
## The ways up in the maze, put up by MazeBuilder after the walls. Against the
## walls stand terraces of the same stone, like steps for something far bigger
## than a boy: a lower one and, often, an upper one set back above it. Ivy grows
## thick enough to climb up their faces (IvyClimb), and now and then on up the
## wall above to its top, where he can walk along it as far as the next pier.
## Vines hang from their edges (Vine) to swing on, and rope bridges (RopeBridge)
## cross the halls between terraces facing each other, and between wall tops.
##
## It is all chosen from the maze's seed, so every copy of the game in a room has
## the same. Faces are the sides of cells that have a wall: (cell, step), the
## wall being the one the `step` way, its face looking back into the cell.

## Heights of the lower and upper terraces, and how far each stands out from
## the wall's face.
const LOWER := Vector2(6.5, 3.0)
const UPPER := Vector2(13.0, 1.8)
## The share of wall faces with a terrace, of those the upper too, of terraces
## matched by one across the hall with a bridge between, of upper terraces with
## ivy on up to the top of the wall, of terraces with a vine, and of halls with
## a bridge from wall top to wall top.
const TERRACES := 0.13
const UPPERS := 0.55
const PAIRED := 0.45
const TO_TOP := 0.35
const VINES := 0.5
const TOP_BRIDGES := 0.05
## How high the end of a vine hangs over the ground (or terrace) under it: out
## of reach standing, so that it takes a jump to catch.
const VINE_CLEAR := 2.6
## And how far out from the face of what it hangs from, to swing clear of it.
const VINE_OUT := 1.1

var maze: Maze
var builder: MazeBuilder
## What was put up, for tests and tools: [face cell, step, has upper] per
## terrace, and each IvyClimb, Vine and RopeBridge.
var terraces: Array = []
var climbs: Array[IvyClimb] = []
var vines: Array[Vine] = []
var bridges: Array[RopeBridge] = []
## Where the lower terraces stand, in the world's x and z (for keeping grass off them).
var footprints: Array[Rect2] = []

var _rng := RandomNumberGenerator.new()
var _taken := {}


func build(plan: Maze, walls: MazeBuilder) -> void:
	maze = plan
	builder = walls
	_rng.seed = hash("features/%d" % maze.maze_seed)
	var lower_tool := SurfaceTool.new()
	lower_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper_tool := SurfaceTool.new()
	upper_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "Terraces"
	add_child(body)

	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) > 1:
			continue
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step) or _taken.has([cell, step]):
				continue
			if _rng.randf() >= TERRACES:
				continue
			var upper := _rng.randf() < UPPERS
			var along := _rng.randf_range(-0.2, 0.2) * Maze.CELL
			var across := -step
			# A terrace across the hall too, and a bridge between them.
			var paired := _rng.randf() < PAIRED and maze.blocked(cell, across) and not _taken.has([cell, across])
			_terrace(cell, step, upper or paired, along, lower_tool, upper_tool, body)
			if paired:
				# (along that wall runs the other way)
				_terrace(cell, across, true, -along, lower_tool, upper_tool, body)
				var a := _edge(cell, step, UPPER.y, along) + Vector3.UP * UPPER.x
				var b := _edge(cell, across, UPPER.y, -along) + Vector3.UP * UPPER.x
				_bridge(a, b)

	# Bridges from wall top to wall top, across halls with an inner wall each side.
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1:
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if maze.blocked(cell, step) and maze.blocked(cell, -step) and not maze.ring_wall(cell, step) and not maze.ring_wall(cell, -step):
				if _rng.randf() < TOP_BRIDGES:
					var a := _edge(cell, step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * MazeBuilder.WALL_HEIGHT
					var b := _edge(cell, -step, MazeBuilder.CORNICE.x, 0.0) + Vector3.UP * MazeBuilder.WALL_HEIGHT
					_bridge(a, b)

	for made: Array in [[lower_tool, LOWER.x], [upper_tool, UPPER.x]]:
		var visual := MeshInstance3D.new()
		visual.mesh = (made[0] as SurfaceTool).commit()
		visual.material_override = MazeStone.wall(made[1])
		body.add_child(visual)


func _thick(cell: Vector2i, step: Vector2i) -> float:
	return MazeBuilder.RING_THICK if maze.ring_wall(cell, step) else MazeBuilder.WALL_THICK


## A point on the ground in front of the face (cell, step), `out` metres out
## from the wall's face and `along` metres along it from the middle.
func _edge(cell: Vector2i, step: Vector2i, out: float, along: float) -> Vector3:
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	return maze.world(cell) + s * (Maze.CELL * 0.5 - _thick(cell, step) * 0.5 - out) + side * along


## The way out of a face, as a Basis whose +Z points out of the wall (as a Ladder wants).
static func _facing_out(step: Vector2i) -> Basis:
	var z := -Vector3(step.x, 0.0, step.y)
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


func _terrace(cell: Vector2i, step: Vector2i, upper: bool, along: float, lower_tool: SurfaceTool, upper_tool: SurfaceTool, body: StaticBody3D) -> void:
	_taken[[cell, step]] = true
	terraces.append([cell, step, upper])
	var s := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-s.z, 0.0, s.x)
	var length := Maze.CELL * 0.85
	# (a box long along the wall, deep out from it)
	var size_for := func(long: float, deep: float, high: float) -> Vector3:
		return (side.abs() * long + s.abs() * deep) + Vector3.UP * high
	var low_middle := _edge(cell, step, LOWER.y * 0.5, 0.0) + Vector3.UP * LOWER.x * 0.5
	var low_size: Vector3 = size_for.call(length, LOWER.y, LOWER.x)
	builder._solid(lower_tool, body, low_middle, low_size)
	footprints.append(Rect2(low_middle.x - low_size.x * 0.5, low_middle.z - low_size.z * 0.5, low_size.x, low_size.z))
	# Ivy up its face, somewhere along it.
	var ivy_along := _rng.randf_range(-0.3, 0.3) * length
	_climb(_edge(cell, step, LOWER.y, ivy_along), step, LOWER.x)
	if _rng.randf() < VINES:
		_vine(_edge(cell, step, LOWER.y + VINE_OUT, _away_from(ivy_along, length)) + Vector3.UP * LOWER.x, LOWER.x - VINE_CLEAR)
	if not upper:
		return
	var upper_length := Maze.CELL * 0.5
	var up_middle := _edge(cell, step, UPPER.y * 0.5, along) + Vector3.UP * UPPER.x * 0.5
	builder._solid(upper_tool, body, up_middle, size_for.call(upper_length, UPPER.y, UPPER.x))
	# Ivy from the lower terrace up the upper's face, away from the one below.
	var up_along := along + (_rng.randf_range(0.1, 0.35) if ivy_along < along else _rng.randf_range(-0.35, -0.1)) * upper_length
	_climb(_edge(cell, step, UPPER.y, up_along) + Vector3.UP * LOWER.x, step, UPPER.x - LOWER.x)
	if _rng.randf() < VINES:
		# (out past the lower terrace's edge, over the hall: jumped to from that edge)
		_vine(_edge(cell, step, LOWER.y + 1.0, along + _away_from(up_along - along, upper_length)) + Vector3.UP * UPPER.x, UPPER.x - LOWER.x - 1.6)
	# And now and then on up the wall to its top (stood off it by the cornice).
	if not maze.ring_wall(cell, step) and _rng.randf() < TO_TOP:
		var top_along := along + _rng.randf_range(-0.3, 0.3) * upper_length
		_climb(_edge(cell, step, MazeBuilder.CORNICE.x, top_along) + Vector3.UP * UPPER.x, step, MazeBuilder.WALL_HEIGHT - UPPER.x)


func _climb(at: Vector3, step: Vector2i, high: float) -> void:
	var ivy := IvyClimb.new()
	ivy.height = high
	ivy.transform = Transform3D(_facing_out(step), at)
	add_child(ivy)
	climbs.append(ivy)


func _vine(top: Vector3, length: float) -> void:
	var vine := Vine.new()
	vine.length = length
	vine.position = top
	add_child(vine)
	vines.append(vine)


func _bridge(a: Vector3, b: Vector3) -> void:
	var bridge := RopeBridge.new()
	bridge.from = a
	bridge.to = b
	add_child(bridge)
	bridges.append(bridge)


## Somewhere along a face `length` long for a vine, at least 3 m from the ivy
## at `ivy` (so that climbing the one he does not catch the other).
func _away_from(ivy: float, length: float) -> float:
	var at := _rng.randf_range(-0.42, 0.42) * length
	if absf(at - ivy) < 3.0:
		at = ivy + (3.0 if ivy < 0.0 else -3.0)
	return at
