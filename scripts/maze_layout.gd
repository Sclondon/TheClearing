@tool
class_name MazeLayout
extends Node3D
## A maze laid out as pieces (MazePiece) that can be seen and changed in the
## editor: every run of wall, pier and terrace, every patch of ivy, vine, rope
## bridge and tree, and the light past the exit. Choose a seed and how many rings,
## press Generate, then move, resize, copy or delete pieces by hand, and save.
## A layout saved in res://mazes/ is played (see Mazes); MazeBuilder.realize turns
## it into the maze the game plays, generated or changed by hand alike.
##
## What the game goes by is the pieces themselves: which lines between cells have
## a wall on them is read from where the wall and pier pieces stand (see `plan`),
## so a wall moved, added or taken away changes the maze for the things that hunt
## in it and for the way out. Walls only count where they stand on the grid's
## lines (every Maze.CELL metres, half a cell off the middle), as generated ones do.
##
## The rings, their gates and the clearing come from the seed, `rings` and `styles`.

## Which maze to start from.
@export var maze_seed := 1
## How many rings round the clearing.
@export_range(1, 3) var rings := 1
## How each ring is made, from the clearing out: its width, how wide its halls are
## and its rules (MazeStyle). Empty: the game's own (MazeStyle.defaults()).
@export var styles: Array[MazeStyle] = []
## Whether the game plays this one when it is in res://mazes/.
@export var playable := true
## In the editor, whether it is lit and misted as in the game (off: the editor's
## own plain light, easier for laying out from above).
@export var game_light := true:
	set(value):
		game_light = value
		_show_in_editor()
@export_tool_button("Generate", "Reload") var generate_button := generate
@export_tool_button("Clear", "Remove") var clear_button := clear

## Where the pieces of each kind go.
const GROUPS := {
	MazePiece.Kind.WALL: "Walls", MazePiece.Kind.PIER: "Piers", MazePiece.Kind.TERRACE: "Terraces",
	MazePiece.Kind.IVY: "Ivy", MazePiece.Kind.VINE: "Vines", MazePiece.Kind.BRIDGE: "Bridges",
	MazePiece.Kind.TREE: "Trees", MazePiece.Kind.BEACON: "Beacon",
}

var _editor_shown: Array[Node] = []


func _ready() -> void:
	_show_in_editor()


## In the editor: the ground under the pieces, and (with `game_light`) the game's
## sky, mist and sun, so that it is seen as it will be played. None of it is saved.
func _show_in_editor() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	for shown: Node in _editor_shown:
		shown.queue_free()
	_editor_shown.clear()
	var open := get_tree().edited_scene_root
	if open == null or not (open == self or open.is_ancestor_of(self)):
		return
	var size := Maze.ring_extent(rings + 1, styles) + 80.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = MazeStone.ground(Maze.CLEARING * Maze.CELL * 0.5, Maze.ring_extent(rings, styles) * 0.5, MazeBuilder.WALL_THICK)
	add_child(ground, false, Node.INTERNAL_MODE_BACK)
	_editor_shown.append(ground)
	if game_light and open.find_children("*", "WorldEnvironment", true, true).is_empty():
		var before := get_child_count(true)
		MazeLight.put(self, true)
		for i in range(before, get_child_count(true)):
			_editor_shown.append(get_child(i, true))


## Lays out the maze for `maze_seed` and `rings`, in place of what is here.
func generate() -> void:
	clear()
	lay_out(Maze.generate(maze_seed, rings, styles))


## Takes away every piece.
func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Every piece of a kind.
func pieces(kind: MazePiece.Kind) -> Array[MazePiece]:
	var found: Array[MazePiece] = []
	var group := get_node_or_null(NodePath(GROUPS[kind]))
	if group:
		for child in group.get_children():
			if child is MazePiece and (child as MazePiece).kind == kind:
				found.append(child)
	# (and any put somewhere else by hand)
	for child in get_children():
		if child is MazePiece and (child as MazePiece).kind == kind:
			found.append(child)
	return found


## The maze as it now stands: the rings, clearing and gates of the seed, with
## the walls where the wall and pier pieces are.
func plan() -> Maze:
	var maze := Maze.generate(maze_seed, rings, styles)
	var blocks: Array[MazePiece] = pieces(MazePiece.Kind.WALL) + pieces(MazePiece.Kind.PIER)
	maze.set_walls(func(cell: Vector2i, step: Vector2i) -> bool:
		var on_line := maze.world(cell) + Vector3(step.x, 0.0, step.y) * Maze.CELL * 0.5 + Vector3.UP * 2.0
		for block in blocks:
			if block.box_has(on_line, 0.05):
				return true
		return false)
	return maze


## Puts down the pieces of `maze`.
func lay_out(maze: Maze) -> void:
	maze_seed = maze.maze_seed
	rings = maze.rings
	for run: Array in _runs(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": run[2]})
	for run: Array in _next_ring(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": true})
	for great in [false, true]:
		for pier: Array in _piers(maze, great):
			_add(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(pier[0].x, 0.0, pier[0].z)), {"size": pier[1], "great": great})
	MazeFeatures.lay_out(self, maze)
	_trees(maze)
	_add(MazePiece.Kind.BEACON, Transform3D(Basis.IDENTITY, maze.world(maze.exit + maze.exit_side * 2)), {})


## Adds a piece of `kind` at `where`, with `settings` (property: value).
func add_piece(kind: MazePiece.Kind, where: Transform3D, settings: Dictionary) -> MazePiece:
	return _add(kind, where, settings)


func _add(kind: MazePiece.Kind, where: Transform3D, settings: Dictionary) -> MazePiece:
	var group := get_node_or_null(NodePath(GROUPS[kind])) as Node3D
	if group == null:
		group = Node3D.new()
		group.name = GROUPS[kind]
		add_child(group)
		_own(group)
	var piece := MazePiece.new()
	piece.name = "%s%d" % [String(GROUPS[kind]).trim_suffix("s"), group.get_child_count() + 1]
	piece.kind = kind
	for key: String in settings:
		piece.set(key, settings[key])
	piece.transform = where
	group.add_child(piece)
	_own(piece)
	if kind == MazePiece.Kind.BRIDGE:
		var end := Marker3D.new()
		end.name = "End"
		end.position = where.affine_inverse() * settings.get("to", where.origin + Vector3(6, 0, 0))
		piece.add_child(end)
		_own(end)
	return piece


## In the editor, makes a node part of the scene being edited, so that it is saved.
func _own(node: Node) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var root := get_tree().edited_scene_root
	node.owner = root if root and (root == self or root.is_ancestor_of(self)) else self


## Every straight run of wall, as [middle, size, between rings] boxes.
static func _runs(maze: Maze) -> Array:
	var runs: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	# Along x, on the line north of row j (j = n is the south edge).
	for j in n + 1:
		var start := -1
		var kind := false
		for x in n + 2:
			var wall := false
			var great := false
			if x < n:
				var cell := Vector2i(x, j) if j < n else Vector2i(x, n - 1)
				var step := Vector2i(0, -1) if j < n else Vector2i(0, 1)
				wall = maze.blocked(cell, step)
				great = maze.ring_wall(cell, step)
			if start >= 0 and (not wall or great != kind):
				var z := (j - 0.5 - middle) * Maze.CELL
				var cx := ((start + x - 1) * 0.5 - middle) * Maze.CELL
				var thick := MazeBuilder.RING_THICK if kind else MazeBuilder.WALL_THICK
				var high := MazeBuilder.RING_HEIGHT if kind else MazeBuilder.WALL_HEIGHT
				runs.append([Vector3(cx, high * 0.5, z), Vector3((x - start) * Maze.CELL + thick, high, thick), kind])
				start = -1
			if wall and start < 0:
				start = x
				kind = great
	# Along z, on the line west of column i.
	for i in n + 1:
		var start := -1
		var kind := false
		for y in n + 2:
			var wall := false
			var great := false
			if y < n:
				var cell := Vector2i(i, y) if i < n else Vector2i(n - 1, y)
				var step := Vector2i(-1, 0) if i < n else Vector2i(1, 0)
				wall = maze.blocked(cell, step)
				great = maze.ring_wall(cell, step)
			if start >= 0 and (not wall or great != kind):
				var x := (i - 0.5 - middle) * Maze.CELL
				var cz := ((start + y - 1) * 0.5 - middle) * Maze.CELL
				var thick := MazeBuilder.RING_THICK if kind else MazeBuilder.WALL_THICK
				var high := MazeBuilder.RING_HEIGHT if kind else MazeBuilder.WALL_HEIGHT
				runs.append([Vector3(x, high * 0.5, cz), Vector3(thick, high, (y - start) * Maze.CELL + thick), kind])
				start = -1
			if wall and start < 0:
				start = y
				kind = great
	return runs


## The outside wall of the next ring, which is not built yet: unbroken for now,
## so that past the gate there is open ground to the foot of the next wall.
static func _next_ring(maze: Maze) -> Array:
	var half := Maze.ring_extent(maze.rings + 1, maze.styles) * 0.5
	var long := half * 2.0 + MazeBuilder.RING_THICK
	var runs: Array = []
	for side in [-1.0, 1.0]:
		runs.append([Vector3(0.0, MazeBuilder.RING_HEIGHT * 0.5, side * half), Vector3(long, MazeBuilder.RING_HEIGHT, MazeBuilder.RING_THICK), true])
		runs.append([Vector3(side * half, MazeBuilder.RING_HEIGHT * 0.5, 0.0), Vector3(MazeBuilder.RING_THICK, MazeBuilder.RING_HEIGHT, long), true])
	return runs


## Square piers, standing above the walls, wherever three or four walls meet or
## one turns a corner: the great ones (`great`) where a wall between rings is
## one of them, the others elsewhere. As [middle, size].
static func _piers(maze: Maze, great: bool) -> Array:
	var piers: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	for j in n + 1:
		for i in n + 1:
			# The four walls that meet at the corner north-west of cell (i, j).
			var walls := [_along_x(maze, i - 1, j), _along_x(maze, i, j), _along_z(maze, i, j - 1), _along_z(maze, i, j)]
			var count := 0
			var any_great := false
			for wall: int in walls:
				if wall > 0:
					count += 1
				any_great = any_great or wall == 2
			var straight: bool = count == 2 and ((walls[0] > 0 and walls[1] > 0) or (walls[2] > 0 and walls[3] > 0))
			if count < 2 or straight or any_great != great:
				continue
			var thick := (MazeBuilder.RING_THICK if great else MazeBuilder.WALL_THICK) + MazeBuilder.PIER.x
			var high := (MazeBuilder.RING_HEIGHT if great else MazeBuilder.WALL_HEIGHT) + MazeBuilder.PIER.y
			piers.append([Vector3((i - 0.5 - middle) * Maze.CELL, high * 0.5, (j - 0.5 - middle) * Maze.CELL), Vector3(thick, high, thick)])
	return piers


## The wall along x on the line north of row j, over column x: 0 none, 1 a
## wall, 2 a wall between rings.
static func _along_x(maze: Maze, x: int, j: int) -> int:
	if x < 0 or x >= maze.size or j < 0 or j > maze.size:
		return 0
	var cell := Vector2i(x, j) if j < maze.size else Vector2i(x, maze.size - 1)
	var step := Vector2i(0, -1) if j < maze.size else Vector2i(0, 1)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## The wall along z on the line west of column i, over row y.
static func _along_z(maze: Maze, i: int, y: int) -> int:
	if y < 0 or y >= maze.size or i < 0 or i > maze.size:
		return 0
	var cell := Vector2i(i, y) if i < maze.size else Vector2i(maze.size - 1, y)
	var step := Vector2i(-1, 0) if i < maze.size else Vector2i(1, 0)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## Stands of pines round the edge of the clearing, kept out of the way of its
## gates, and a few out on the ground past the last ring.
func _trees(maze: Maze) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze.maze_seed
	var edge := maze.clearing * Maze.CELL * 0.5 - MazeBuilder.RING_THICK * 0.5
	var points: Array = []
	# (a stand for each cell along a side, and as many trees out in the open)
	for stand in maze.clearing:
		# Somewhere along the wall, not in front of a gate (the middle of a side).
		var side := rng.randi() % 4
		var along := rng.randf_range(0.25, 0.95) * (1.0 if rng.randf() < 0.5 else -1.0) * edge
		var into := rng.randf_range(5.0, 12.0)
		var middle := _on_side(side, along, edge - into)
		for i in rng.randi_range(3, 6):
			var p := middle + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
			if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > 12.0:
				points.append(p)
	for i in maze.clearing:
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * (edge - 6.0)
		if p.length() > 14.0:
			points.append(p)
	var built := maze.extent() * 0.5 + 6.0
	var next := Maze.ring_extent(maze.rings + 1, maze.styles) * 0.5 - 6.0
	for i in 60:
		var side := rng.randi() % 4
		points.append(_on_side(side, rng.randf_range(-next, next), rng.randf_range(built, next)))
	for p: Vector3 in points:
		var big := rng.randf_range(0.8, 1.5)
		_add(MazePiece.Kind.TREE, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * big), p), {})


## A point `out` metres from the middle on one side (0 north, 1 east, 2 south,
## 3 west), `along` metres along it.
static func _on_side(side: int, along: float, out: float) -> Vector3:
	match side:
		0: return Vector3(along, 0.0, -out)
		1: return Vector3(out, 0.0, along)
		2: return Vector3(along, 0.0, out)
	return Vector3(-out, 0.0, along)
