class_name MazeBuilder
extends Node3D
## Puts a Maze (scripts/maze.gd) up in the world: the walls as meshes, with a box
## to bump into for each straight run of wall, the ground, pines in the clearing,
## the wall of the next ring standing beyond the last one built, and a pale light
## standing up past the exit, seen over the walls.
##
## The walls are not made for people. The passages are wide enough for a cart,
## and the walls go up five times as high as that; the walls between rings (the
## clearing's own wall among them) are higher and thicker again.
##
## Build a new one for each maze; free the old one.

## The walls inside a ring, and the great walls between rings.
const WALL_HEIGHT := 34.0
const WALL_THICK := 3.2
const RING_HEIGHT := 46.0
const RING_THICK := 4.2

var maze: Maze
## The light past the exit.
var beacon: Node3D
## The terraces, ivy, vines and bridges (MazeFeatures).
var features: MazeFeatures


func build(plan: Maze) -> void:
	maze = plan
	var inner: Array = []
	var great: Array = []
	for run: Array in _runs():
		(great if run[2] else inner).append(run)
	great.append_array(_next_ring())
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	_walls(body, inner, WALL_HEIGHT)
	_walls(body, great, RING_HEIGHT)
	features = MazeFeatures.new()
	features.name = "Features"
	add_child(features)
	features.build(maze, self)
	_ground()
	_trees()
	_beacon()


## Every straight run of wall, as [middle, size, between rings] boxes.
func _runs() -> Array:
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
				var thick := RING_THICK if kind else WALL_THICK
				var high := RING_HEIGHT if kind else WALL_HEIGHT
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
				var thick := RING_THICK if kind else WALL_THICK
				var high := RING_HEIGHT if kind else WALL_HEIGHT
				runs.append([Vector3(x, high * 0.5, cz), Vector3(thick, high, (y - start) * Maze.CELL + thick), kind])
				start = -1
			if wall and start < 0:
				start = y
				kind = great
	return runs


## The outside wall of the next ring, which is not built yet: unbroken for now,
## so that past the gate there is open ground to the foot of the next wall.
func _next_ring() -> Array:
	var half := Maze.ring_extent(maze.rings + 1) * 0.5
	var long := half * 2.0 + RING_THICK
	var runs: Array = []
	for side in [-1.0, 1.0]:
		runs.append([Vector3(0.0, RING_HEIGHT * 0.5, side * half), Vector3(long, RING_HEIGHT, RING_THICK), true])
		runs.append([Vector3(side * half, RING_HEIGHT * 0.5, 0.0), Vector3(RING_THICK, RING_HEIGHT, long), true])
	return runs


## How far the footing of a wall stands out from its face, and how high it is;
## the same for the cornice along its top. And how much wider a pier is than the
## walls it stands at, and how far it rises above them.
const FOOT := Vector2(0.7, 1.6)
const CORNICE := Vector2(0.6, 1.8)
const PIER := Vector2(2.2, 4.0)


func _walls(body: StaticBody3D, runs: Array, height: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var great := height == RING_HEIGHT
	for run: Array in runs:
		var at: Vector3 = run[0]
		var size: Vector3 = run[1]
		var wide := Vector3(1.0 if size.x < size.z else 0.0, 0.0, 1.0 if size.z < size.x else 0.0)
		_solid(tool, body, at, size)
		# A stepped footing, and a cornice standing out along the top.
		_solid(tool, body, Vector3(at.x, FOOT.y * 0.5, at.z), size * Vector3(1, 0, 1) + wide * FOOT.x * 2.0 + Vector3.UP * FOOT.y)
		_solid(tool, body, Vector3(at.x, height - CORNICE.y * 0.5, at.z), size * Vector3(1, 0, 1) + wide * CORNICE.x * 2.0 + Vector3.UP * CORNICE.y)
	for pier: Array in _piers(great):
		_solid(tool, body, pier[0], pier[1])
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	visual.material_override = MazeStone.wall(height)
	body.add_child(visual)


## A box drawn and bumped into.
func _solid(tool: SurfaceTool, body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	_box(tool, at, size)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


## Square piers, standing above the walls, wherever three or four walls meet or
## one turns a corner: the great ones (`great`) where a wall between rings is
## one of them, the others elsewhere. As [middle, size].
func _piers(great: bool) -> Array:
	var piers: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	for j in n + 1:
		for i in n + 1:
			# The four walls that meet at the corner north-west of cell (i, j).
			var walls := [_along_x(i - 1, j), _along_x(i, j), _along_z(i, j - 1), _along_z(i, j)]
			var count := 0
			var any_great := false
			for wall: int in walls:
				if wall > 0:
					count += 1
				any_great = any_great or wall == 2
			var straight: bool = count == 2 and ((walls[0] > 0 and walls[1] > 0) or (walls[2] > 0 and walls[3] > 0))
			if count < 2 or straight or any_great != great:
				continue
			var thick := (RING_THICK if great else WALL_THICK) + PIER.x
			var high := (RING_HEIGHT if great else WALL_HEIGHT) + PIER.y
			piers.append([Vector3((i - 0.5 - middle) * Maze.CELL, high * 0.5, (j - 0.5 - middle) * Maze.CELL), Vector3(thick, high, thick)])
	return piers


## The wall along x on the line north of row j, over column x: 0 none, 1 a
## wall, 2 a wall between rings.
func _along_x(x: int, j: int) -> int:
	if x < 0 or x >= maze.size or j < 0 or j > maze.size:
		return 0
	var cell := Vector2i(x, j) if j < maze.size else Vector2i(x, maze.size - 1)
	var step := Vector2i(0, -1) if j < maze.size else Vector2i(0, 1)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## The wall along z on the line west of column i, over row y.
func _along_z(i: int, y: int) -> int:
	if y < 0 or y >= maze.size or i < 0 or i > maze.size:
		return 0
	var cell := Vector2i(i, y) if i < maze.size else Vector2i(maze.size - 1, y)
	var step := Vector2i(-1, 0) if i < maze.size else Vector2i(1, 0)
	if not maze.blocked(cell, step):
		return 0
	return 2 if maze.ring_wall(cell, step) else 1


## Five faces of a box (no bottom), facing out.
func _box(tool: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3.RIGHT, Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3.LEFT, Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3.BACK, Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3.FORWARD, Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1] * h
		var v: Vector3 = face[2] * h
		var centre: Vector3 = at + normal * h
		var a := centre - u - v
		var b := centre + u - v
		var c := centre + u + v
		var d := centre - u + v
		tool.set_normal(normal)
		# (clockwise seen from outside, as Godot faces are)
		for corner: Vector3 in [a, c, b, a, d, c]:
			tool.add_vertex(corner)


func _ground() -> void:
	var size := Maze.ring_extent(maze.rings + 1) + 80.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 2.0, size)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -1.0
	body.add_child(collider)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var visual := MeshInstance3D.new()
	visual.mesh = plane
	visual.material_override = MazeStone.ground(maze.clearing * Maze.CELL * 0.5, maze.extent() * 0.5, WALL_THICK)
	body.add_child(visual)
	add_child(body)


## Stands of pines round the edge of the clearing, kept out of the way of its
## gates, and a few out on the ground past the last ring.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze.maze_seed
	var pine := PineTree.new()
	pine.height = 13.0
	pine.seed = maze.maze_seed % 1000
	var edge := maze.clearing * Maze.CELL * 0.5 - RING_THICK * 0.5
	var points: Array = []
	for stand in 7:
		# Somewhere along the wall, not in front of a gate (the middle of a side).
		var side := rng.randi() % 4
		var along := rng.randf_range(0.25, 0.95) * (1.0 if rng.randf() < 0.5 else -1.0) * edge
		var into := rng.randf_range(5.0, 12.0)
		var middle := _on_side(side, along, edge - into)
		for i in rng.randi_range(3, 6):
			var p := middle + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
			if maxf(absf(p.x), absf(p.z)) < edge - 3.0 and p.length() > 12.0:
				points.append(p)
	for i in 6:
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * (edge - 6.0)
		if p.length() > 14.0:
			points.append(p)
	var built := maze.extent() * 0.5 + 6.0
	var next := Maze.ring_extent(maze.rings + 1) * 0.5 - 6.0
	for i in 60:
		var side := rng.randi() % 4
		var p := _on_side(side, rng.randf_range(-next, next), rng.randf_range(built, next))
		points.append(p)
	PineTree.forest(self, points, pine, 3, Vector2(0.8, 1.5), 48.0, 0.0)


## A point `out` metres from the middle on one side (0 north, 1 east, 2 south,
## 3 west), `along` metres along it.
static func _on_side(side: int, along: float, out: float) -> Vector3:
	match side:
		0: return Vector3(along, 0.0, -out)
		1: return Vector3(out, 0.0, along)
		2: return Vector3(along, 0.0, out)
	return Vector3(-out, 0.0, along)


func _beacon() -> void:
	beacon = Node3D.new()
	beacon.name = "Beacon"
	var out := maze.world(maze.exit + maze.exit_side * 2)
	beacon.position = out
	var beam := CylinderMesh.new()
	beam.top_radius = 0.6
	beam.bottom_radius = 1.2
	beam.height = 110.0
	beam.cap_top = false
	beam.cap_bottom = false
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.55, 0.75, 0.9, 0.12)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.disable_fog = true
	var visual := MeshInstance3D.new()
	visual.mesh = beam
	visual.material_override = glow
	visual.position.y = 55.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(visual)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 0.8, 1.0)
	lamp.omni_range = 12.0
	lamp.light_energy = 1.5
	lamp.position.y = 1.5
	beacon.add_child(lamp)
	add_child(beacon)
