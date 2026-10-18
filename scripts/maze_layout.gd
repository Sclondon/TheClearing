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
## How many rings round the clearing: the square ones first, then (past a moor)
## the round ones (MazeStyle.round_section), shown as the game will build them.
@export_range(1, 7) var rings := 1
## How each ring is made, from the clearing out (MazeStyle): its width, how wide
## its halls are, the rules of its passages and its entrances, and what is on
## its walls. Empty: the game's own (MazeStyle.defaults()), which Generate fills
## in here to be changed.
@export var styles: Array[MazeStyle] = []
## How the clearing is made (ClearingStyle): its level middle, its hills and its
## woods. Empty: the game's own, which Generate fills in here to be changed.
@export var clearing_style: ClearingStyle
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
	MazePiece.Kind.TREE: "Trees", MazePiece.Kind.BEACON: "Beacon", MazePiece.Kind.STRAND: "Strands", MazePiece.Kind.PIPE: "Pipes",
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
	# (the round sections, past the moor, are not pieces: they are shown as the
	# game will build them, from the seed and their styles)
	var plan := Maze.generate(maze_seed, rings, styles, clearing_style)
	var outer := plan.round_rings
	if outer:
		size = (outer.outermost() + 300.0) * 2.0
		var sections := RoundBuilder.new()
		sections.plan = outer
		add_child(sections, false, Node.INTERNAL_MODE_BACK)
		_editor_shown.append(sections)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = MazeStone.ground(Maze.CLEARING * Maze.CELL * 0.5, plan.extent() * 0.5, MazeBuilder.WALL_THICK)
	add_child(ground, false, Node.INTERNAL_MODE_BACK)
	_editor_shown.append(ground)
	if clearing_style and clearing_style.shaped():
		var field := MazeBuilder.hills(clearing_style, maze_seed, ground.material_override)
		add_child(field, false, Node.INTERNAL_MODE_BACK)
		_editor_shown.append(field)
	if game_light and open.find_children("*", "WorldEnvironment", true, true).is_empty():
		var before := get_child_count(true)
		MazeLight.put(self, true)
		for i in range(before, get_child_count(true)):
			_editor_shown.append(get_child(i, true))


## Lays out the maze for `maze_seed` and `rings`, in place of what is here.
func generate() -> void:
	clear()
	# (the game's own ring styles, filled in to be changed here, ring by ring)
	# (and any more rings than it has styles for, the game's own for those)
	var own := MazeStyle.defaults()
	if styles.is_empty():
		styles = own.duplicate()
	while styles.size() < mini(rings, own.size()):
		styles.append(own[styles.size()])
	if clearing_style == null:
		clearing_style = ClearingStyle.new()
	lay_out(Maze.generate(maze_seed, rings, styles, clearing_style))
	_show_in_editor()


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
	var maze := Maze.generate(maze_seed, rings, styles, clearing_style)
	var blocks: Array[MazePiece] = pieces(MazePiece.Kind.WALL) + pieces(MazePiece.Kind.PIER)
	maze.set_walls(func(cell: Vector2i, step: Vector2i) -> bool:
		var on_line := maze.world(cell) + Vector3(step.x, 0.0, step.y) * Maze.CELL * 0.5 + Vector3.UP * 2.0
		for block in blocks:
			# (a ledge along a wall stands out from it, but is not a wall)
			if block.ledge:
				continue
			if block.box_has(on_line, 0.05):
				return true
		return false)
	return maze


## Puts down the pieces of `maze`.
func lay_out(maze: Maze) -> void:
	maze_seed = maze.maze_seed
	# (the round sections past the square ones count too)
	rings = maze.rings + (maze.round_rings.rings.size() if maze.round_rings else 0)
	clearing_style = maze.clearing_style
	for run: Array in _runs(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": run[2]})
	# (the wall round the next ring, unbuilt, when the maze stops here; round
	# sections past the moor are RoundBuilder's)
	for run: Array in ([] if maze.round_rings else _next_ring(maze)):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, Vector3(run[0].x, 0.0, run[0].z)), {"size": run[1], "great": true})
	for great in [false, true]:
		for pier: Array in _piers(maze, great):
			_add(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, Vector3(pier[0].x, 0.0, pier[0].z)), {"size": pier[1], "great": great})
	for rampart: Array in _ramparts(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, rampart[0]), {"size": rampart[1], "great": true})
	for gatehouse: Array in _gatehouses(maze):
		_add(MazePiece.Kind.WALL, Transform3D(Basis.IDENTITY, gatehouse[0]), {"size": gatehouse[1], "great": true})
	# (along the maze walls only, not the great walls round the rings)
	for ledge: Array in _ledges(maze, _runs(maze).filter(func(run: Array) -> bool: return not run[2])):
		_add(MazePiece.Kind.PIER, Transform3D(Basis.IDENTITY, ledge[0]), {"size": ledge[1], "ledge": true})
	MazeFeatures.lay_out(self, maze)
	_trees(maze)
	if not maze.round_rings:
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
	if kind in [MazePiece.Kind.BRIDGE, MazePiece.Kind.STRAND]:
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
		var thick := 0.0
		var tall := 0.0
		for x in n + 2:
			var wall := false
			var great := false
			var here := 0.0
			var high := 0.0
			if x < n:
				var cell := Vector2i(x, j) if j < n else Vector2i(x, n - 1)
				var step := Vector2i(0, -1) if j < n else Vector2i(0, 1)
				# (none in or round a rampart: its stone is laid whole, see _ramparts)
				wall = maze.blocked(cell, step) and not maze.solid.has(cell) and not maze.solid.has(cell + step)
				great = maze.ring_wall(cell, step)
				here = maze.wall_thick(cell, step)
				high = maze.wall_height(cell, step)
			if start >= 0 and (not wall or great != kind or here != thick or high != tall):
				var z := (j - 0.5 - middle) * Maze.CELL
				var cx := ((start + x - 1) * 0.5 - middle) * Maze.CELL
				var long := (x - start) * Maze.CELL + thick
				if not kind:
					var back := _cut_back(maze, [Vector2i(start - 1, j - 1), Vector2i(start - 1, j)], _great_z(maze, start, j), thick)
					var front := _cut_back(maze, [Vector2i(x, j - 1), Vector2i(x, j)], _great_z(maze, x, j), thick)
					long -= back + front
					cx += (back - front) * 0.5
				runs.append([Vector3(cx, tall * 0.5, z), Vector3(long, tall, thick), kind])
				start = -1
			if wall and start < 0:
				start = x
				kind = great
				thick = here
				tall = high
	# Along z, on the line west of column i.
	for i in n + 1:
		var start := -1
		var kind := false
		var thick := 0.0
		var tall := 0.0
		for y in n + 2:
			var wall := false
			var great := false
			var here := 0.0
			var high := 0.0
			if y < n:
				var cell := Vector2i(i, y) if i < n else Vector2i(n - 1, y)
				var step := Vector2i(-1, 0) if i < n else Vector2i(1, 0)
				wall = maze.blocked(cell, step) and not maze.solid.has(cell) and not maze.solid.has(cell + step)
				great = maze.ring_wall(cell, step)
				here = maze.wall_thick(cell, step)
				high = maze.wall_height(cell, step)
			if start >= 0 and (not wall or great != kind or here != thick or high != tall):
				var x := (i - 0.5 - middle) * Maze.CELL
				var cz := ((start + y - 1) * 0.5 - middle) * Maze.CELL
				var long := (y - start) * Maze.CELL + thick
				if not kind:
					var back := _cut_back(maze, [Vector2i(i - 1, start - 1), Vector2i(i, start - 1)], _great_x(maze, i, start), thick)
					var front := _cut_back(maze, [Vector2i(i - 1, y), Vector2i(i, y)], _great_x(maze, i, y), thick)
					long -= back + front
					cz += (back - front) * 0.5
				runs.append([Vector3(x, tall * 0.5, cz), Vector3(thick, tall, long), kind])
				start = -1
			if wall and start < 0:
				start = y
				kind = great
				thick = here
				tall = high
	return runs


## How far to take back the end of a run of wall inside a ring where it meets a
## great wall, so that no face of it lies in one of the great wall's (they are
## different concretes, and would flicker where they met): to the face of a
## rampart if one of `beyond` (the cells past its end, either side of its line)
## is one, to the near face of a great wall `crossing` thick across its end.
static func _cut_back(maze: Maze, beyond: Array, crossing: float, thick: float) -> float:
	for cell: Vector2i in beyond:
		if maze.solid.has(cell):
			# (a rampart stands half its wall out past its cells: see _ramparts)
			var way: Array = maze.gates[maze.ring_of(cell) - 1][0]
			return (thick + maze.wall_thick(way[0], way[1])) * 0.5
	return (thick + crossing) * 0.5 if crossing > 0.0 else 0.0


## The ramparts round the inside of rings (MazeStyle.border_wall_thickness_cells), as [middle of the
## foot, size]: solid stone as high as the wall between rings, from the face of
## that wall out over the rampart's cells to the face of the walls beyond, as
## four sides, each broken by a slot (as narrow as a way through a wall a cell
## long) where an entrance runs through it.
static func _ramparts(maze: Maze) -> Array:
	var walls: Array = []
	for ring in range(1, maze.rings + 1):
		var style: MazeStyle = maze.styles[ring - 1]
		if style.border_wall_thickness_cells <= 0:
			continue
		var way: Array = maze.gates[ring - 1][0]
		var thick := maze.wall_thick(way[0], way[1])
		var slot := Maze.CELL - thick
		var near := maze.ring_sizes[ring - 1] * Maze.CELL * 0.5 - thick * 0.5
		var far := near + thick + style.border_wall_thickness_cells * Maze.CELL
		for side: Vector2i in Maze.STEPS:
			var out := Vector3(side.x, 0.0, side.y)
			var along := Vector3(absf(out.z), 0.0, absf(out.x))
			# (north and south sides run the whole way, corners and all; east and west between them)
			var reach := far if side.y != 0 else near
			var cuts: Array[float] = [-reach]
			for gate: Array in maze.gates[ring - 1]:
				if gate[1] == side:
					var at: float = maze.world(gate[0]).dot(along)
					cuts.append_array([at - slot * 0.5, at + slot * 0.5])
			cuts.append(reach)
			cuts.sort()
			for i in range(0, cuts.size(), 2):
				var long: float = cuts[i + 1] - cuts[i]
				var middle := out * (near + far) * 0.5 + along * (cuts[i] + cuts[i + 1]) * 0.5
				walls.append([middle, along * long + out.abs() * (far - near) + Vector3.UP * style.section_border_wall_height])
	return walls


## The ledges along the walls of rings that have one (MazeStyle.mezzanine_height), as [middle
## of the foot, size]: along each long face of each of `boxes` ([middle of the
## foot, size]) that looks into such a ring, as long as the box.
static func _ledges(maze: Maze, boxes: Array) -> Array:
	var ledges: Array = []
	for box: Array in boxes:
		var middle: Vector3 = box[0]
		var size: Vector3 = box[1]
		var long_x := size.x >= size.z
		var out := Vector3(0.0, 0.0, 1.0) if long_x else Vector3(1.0, 0.0, 0.0)
		var half: float = (size.z if long_x else size.x) * 0.5
		for way: float in [-1.0, 1.0]:
			var face := Vector3(middle.x, 0.0, middle.z) + out * way * half
			var cell := maze.cell_at(face + out * way * 1.0)
			var ring := maze.ring_of(cell)
			if ring < 1 or ring > maze.rings or not maze.inside(cell) or maze.solid.has(cell):
				continue
			var style: MazeStyle = maze.styles[ring - 1]
			if style.mezzanine_height <= 0.0:
				continue
			var high := style.mezzanine_height
			var long: float = size.x if long_x else size.z
			var along := Vector3(long, 0.0, 0.0) if long_x else Vector3(0.0, 0.0, long)
			# (a step of the wall, from the ground up: nothing under it to see through)
			var foot := face + out * way * style.mezzanine_depth * 0.5
			ledges.append([foot, along + out * style.mezzanine_depth + Vector3.UP * high])
	return ledges


## The walls either side of each narrow entrance (MazeStyle.entrance_doorway_width), as
## [middle of the foot, size]: filling the entrance's cells but for the doorway
## down the middle, as high as the wall round the inside of the ring it leads into.
static func _gatehouses(maze: Maze) -> Array:
	var walls: Array = []
	for ring in range(1, maze.rings + 1):
		var style: MazeStyle = maze.styles[ring - 1]
		if style.entrance_doorway_width <= 0.0:
			continue
		for way: Array in maze.gates[ring - 1]:
			var step: Vector2i = way[1]
			var s := Vector3(step.x, 0.0, step.y)
			var side := Vector3(-s.z, 0.0, s.x)
			var cells := 0
			while maze.entrances.get(way[0] + step * (cells + 1), Vector2i.ZERO) == step:
				cells += 1
			if cells == 0:
				continue
			# (from the middle of the wall it goes through to the far end of the entrance)
			var start: Vector3 = maze.world(way[0]) + s * Maze.CELL * 0.5
			var middle := start + s * cells * Maze.CELL * 0.5
			var wide := (Maze.CELL - style.entrance_doorway_width) * 0.5
			var size := side.abs() * wide + s.abs() * cells * Maze.CELL + Vector3.UP * maze.inner_height(ring)
			for out in [-1.0, 1.0]:
				walls.append([middle + side * out * (style.entrance_doorway_width + wide) * 0.5, size])
	return walls


## The outside wall of the next ring, which is not built yet: unbroken for now,
## so that past the gate there is open ground to the foot of the next wall.
static func _next_ring(maze: Maze) -> Array:
	var half := Maze.ring_extent(maze.rings + 1, maze.styles) * 0.5
	var long := half * 2.0 + MazeBuilder.RING_THICK
	var high := maze.inner_height(maze.rings + 1)
	var runs: Array = []
	for side in [-1.0, 1.0]:
		runs.append([Vector3(0.0, high * 0.5, side * half), Vector3(long, high, MazeBuilder.RING_THICK), true])
		runs.append([Vector3(side * half, high * 0.5, 0.0), Vector3(MazeBuilder.RING_THICK, high, long), true])
	return runs


## Walls thicker than this have no piers.
const MAX_PIERED := 5.0


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
			var thickest := maxf(maxf(_thick_x(maze, i - 1, j), _thick_x(maze, i, j)), maxf(_thick_z(maze, i, j - 1), _thick_z(maze, i, j)))
			var count := 0
			var any_great := false
			for wall: int in walls:
				if wall > 0:
					count += 1
				any_great = any_great or wall == 2
			var straight: bool = count == 2 and ((walls[0] > 0 and walls[1] > 0) or (walls[2] > 0 and walls[3] > 0))
			# (and none on walls too massive for one to stand out from them)
			if count < 2 or straight or any_great != great or thickest > MAX_PIERED:
				continue
			var thick := thickest + MazeBuilder.PIER.x
			# (a great one as high as the wall round the outermost ring it stands at)
			var ring := maxi(maxi(maze.ring_of(Vector2i(i - 1, j - 1)), maze.ring_of(Vector2i(i, j - 1))), maxi(maze.ring_of(Vector2i(i - 1, j)), maze.ring_of(Vector2i(i, j))))
			var high := (maze.inner_height(ring) if great else maze.maze_wall_height(ring)) + MazeBuilder.PIER.y
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


## How thick the wall along x on the line north of row j, over column x, is (0 for none).
static func _thick_x(maze: Maze, x: int, j: int) -> float:
	if _along_x(maze, x, j) == 0:
		return 0.0
	return maze.wall_thick(Vector2i(x, j) if j < maze.size else Vector2i(x, maze.size - 1), Vector2i(0, -1) if j < maze.size else Vector2i(0, 1))


## How thick the wall along z on the line west of column i, over row y, is (0 for none).
static func _thick_z(maze: Maze, i: int, y: int) -> float:
	if _along_z(maze, i, y) == 0:
		return 0.0
	return maze.wall_thick(Vector2i(i, y) if i < maze.size else Vector2i(maze.size - 1, y), Vector2i(-1, 0) if i < maze.size else Vector2i(1, 0))


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
	var gate: Array = maze.gates[0][0]
	var edge := maze.clearing * Maze.CELL * 0.5 - maze.wall_thick(gate[0], gate[1]) * 0.5
	var look := maze.clearing_style
	var points: Array = []
	# (a stand for each cell along a side, and as many trees out in the open, none in the glade in the middle)
	for stand in maze.clearing:
		# Somewhere along the wall, not in front of a gate (the middle of a side).
		var side := rng.randi() % 4
		var along := rng.randf_range(0.25, 0.95) * (1.0 if rng.randf() < 0.5 else -1.0) * edge
		var into := rng.randf_range(5.0, 12.0)
		var middle := _on_side(side, along, edge - into)
		for i in rng.randi_range(3, 6):
			var p := middle + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
			if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > look.treeless_radius:
				points.append(p)
	for i in maze.clearing:
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * (edge - 6.0)
		if p.length() > look.treeless_radius:
			points.append(p)
	# Dense woods round the woods entrance, right up to its door, thinning out
	# towards their edge.
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	if look.woods_density > 0.0 and not woods.is_empty():
		var gate_at: Vector2 = woods[0]
		var steps := ceili(look.woods_size / look.woods_tree_spacing)
		for a in range(-steps, steps + 1):
			for b in range(-steps, steps + 1):
				var flat := gate_at + (Vector2(a, b) + Vector2(rng.randf(), rng.randf()) * 0.8) * look.woods_tree_spacing
				var p := Vector3(flat.x, 0.0, flat.y)
				var deep := 1.0 - flat.distance_to(gate_at) / look.woods_size
				if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > look.treeless_radius \
						and rng.randf() < look.woods_density * smoothstep(0.0, 0.35, deep):
					points.append(p)
	# (nothing near the clear entrance, nor in the pond)
	points = points.filter(func(p: Vector3) -> bool: return not look.kept_clear(Vector2(p.x, p.z)))
	var built := maze.extent() * 0.5 + 6.0
	var next := Maze.ring_extent(maze.rings + 1, maze.styles) * 0.5 - 6.0
	if maze.round_rings:
		# (pines over the moor, between the square maze and the first circle)
		var moor := maze.round_rings.inner_radius - 12.0
		for i in 220:
			var turn := rng.randf() * TAU
			var p := Vector3(cos(turn), 0.0, sin(turn)) * rng.randf_range(built, moor)
			if maxf(absf(p.x), absf(p.z)) > built:
				points.append(p)
	else:
		for i in 60:
			var side := rng.randi() % 4
			points.append(_on_side(side, rng.randf_range(-next, next), rng.randf_range(built, next)))
	for p: Vector3 in points:
		# (on the hills, a little sunk so that no root stands out of a slope)
		p.y = maze.ground_height(p) - 0.15
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


## How thick a great wall along x on the line north of row j is at the line west
## of column i (where a wall along z there would meet it), 0 for none.
static func _great_x(maze: Maze, i: int, j: int) -> float:
	var thick := 0.0
	for x in [i - 1, i]:
		if _along_x(maze, x, j) == 2:
			thick = maxf(thick, _thick_x(maze, x, j))
	return thick


## How thick a great wall along z on the line west of column i is at the line
## north of row j (where a wall along x there would meet it), 0 for none.
static func _great_z(maze: Maze, i: int, j: int) -> float:
	var thick := 0.0
	for y in [j - 1, j]:
		if _along_z(maze, i, y) == 2:
			thick = maxf(thick, _thick_z(maze, i, y))
	return thick
