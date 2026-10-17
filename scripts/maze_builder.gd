class_name MazeBuilder
extends Node3D
## Puts a Maze (scripts/maze.gd) up in the world: the walls as one mesh, with a
## box to bump into for each straight run of wall, the ground, pines round the
## clearing, and a pale light standing up past the exit, seen over the walls.
##
## Build a new one for each maze; free the old one.

const WALL_HEIGHT := 8.0
const WALL_THICK := 0.7

var maze: Maze
## The light past the exit.
var beacon: Node3D


func build(plan: Maze) -> void:
	maze = plan
	var runs := _runs()
	_walls(runs)
	_ground()
	_trees()
	_beacon()


## Every straight run of wall, as [middle, size] boxes.
func _runs() -> Array:
	var runs: Array = []
	var n := maze.size
	var middle := (n - 1) * 0.5
	# Along x, on the line north of row j (j = n is the south edge).
	for j in n + 1:
		var start := -1
		for x in n + 1:
			var wall := false
			if x < n:
				wall = maze.blocked(Vector2i(x, j), Vector2i(0, -1)) if j < n else maze.blocked(Vector2i(x, n - 1), Vector2i(0, 1))
			if wall and start < 0:
				start = x
			elif not wall and start >= 0:
				var z := (j - 0.5 - middle) * Maze.CELL
				var cx := ((start + x - 1) * 0.5 - middle) * Maze.CELL
				var length := (x - start) * Maze.CELL + WALL_THICK
				runs.append([Vector3(cx, WALL_HEIGHT * 0.5, z), Vector3(length, WALL_HEIGHT, WALL_THICK)])
				start = -1
	# Along z, on the line west of column i.
	for i in n + 1:
		var start := -1
		for y in n + 1:
			var wall := false
			if y < n:
				wall = maze.blocked(Vector2i(i, y), Vector2i(-1, 0)) if i < n else maze.blocked(Vector2i(n - 1, y), Vector2i(1, 0))
			if wall and start < 0:
				start = y
			elif not wall and start >= 0:
				var x := (i - 0.5 - middle) * Maze.CELL
				var cz := ((start + y - 1) * 0.5 - middle) * Maze.CELL
				var length := (y - start) * Maze.CELL + WALL_THICK
				runs.append([Vector3(x, WALL_HEIGHT * 0.5, cz), Vector3(WALL_THICK, WALL_HEIGHT, length)])
				start = -1
	return runs


func _walls(runs: Array) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "Walls"
	for run: Array in runs:
		var at: Vector3 = run[0]
		var size: Vector3 = run[1]
		_box(tool, at, size)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = at
		body.add_child(collider)
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	visual.material_override = MazeStone.wall(WALL_HEIGHT)
	body.add_child(visual)
	add_child(body)


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
	var half := maze.extent() * 0.5
	var size := maze.extent() + 160.0
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
	visual.material_override = MazeStone.ground(maze.clearing * Maze.CELL * 0.5, half)
	body.add_child(visual)
	add_child(body)


## Pines in the corners of the clearing, and a wood outside the maze.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = maze.maze_seed
	var pine := PineTree.new()
	pine.height = 9.0
	pine.seed = maze.maze_seed % 1000
	var corner := maze.clearing * Maze.CELL * 0.5 - 2.2
	var points: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			points.append(Vector3(sx * corner + rng.randf_range(-0.5, 0.5), 0.0, sz * corner + rng.randf_range(-0.5, 0.5)))
	var outside := maze.extent() * 0.5 + 8.0
	for i in 140:
		var angle := rng.randf() * TAU
		var reach := outside + rng.randf() * 50.0
		var point := Vector3(cos(angle), 0.0, sin(angle)) * reach
		# (round the corners too, not only in a ring)
		point.x = clampf(point.x * 1.3, -outside - 50.0, outside + 50.0)
		point.z = clampf(point.z * 1.3, -outside - 50.0, outside + 50.0)
		if maxf(absf(point.x), absf(point.z)) > outside:
			points.append(point)
	PineTree.forest(self, points, pine, 3, Vector2(0.8, 1.4), 48.0, 0.0)


func _beacon() -> void:
	beacon = Node3D.new()
	beacon.name = "Beacon"
	var out := maze.world(maze.exit + maze.exit_side)
	beacon.position = out
	var beam := CylinderMesh.new()
	beam.top_radius = 0.35
	beam.bottom_radius = 0.7
	beam.height = 60.0
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
	visual.position.y = 30.0
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(visual)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.6, 0.8, 1.0)
	lamp.omni_range = 9.0
	lamp.light_energy = 1.5
	lamp.position.y = 1.5
	beacon.add_child(lamp)
	add_child(beacon)
