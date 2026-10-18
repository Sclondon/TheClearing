@tool
class_name RoundBuilder
extends Node3D
## Puts up the round sections of a maze (RoundMaze): the great circular walls
## between them, with their gates, and the walls of their passages, round and
## out; and the light past the way out of the last. Each wall is a box (a curved
## one, short straight lengths round the circle); they are merged into one mesh
## and one shape to walk into for each stretch of each section, so that a
## thousand-metre maze goes up in moments.

## How many stretches each section is built in, round it (each its own mesh,
## drawn only when on the screen and near enough).
const STRETCHES := 32
## Curved walls are made of straight lengths no longer than this round, radians.
const STEP := 0.05
## Past this the walls are lost in the mist: not drawn.
const FAR := 700.0

var plan: RoundMaze
## The light past the way out.
var beacon: Node3D

# [look, section, stretch] -> [vertices, normals].
var _parts := {}


func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	# The great walls across the desert ring from the square's corners to the first
	# circle, unbroken: its quarters are walled apart.
	if plan.desert:
		var corner := plan.square_half * sqrt(2.0)
		for a: float in RoundMaze.DIAGONALS:
			_radial(0, a, corner, plan.inner_radius, MazeBuilder.RING_THICK, plan.desert.diagonal_wall_height, true)
		# (the desert ring the last built: its far wall, with a way out of each quarter)
		if plan.rings.is_empty():
			_circle(0, plan.inner_radius, MazeBuilder.RING_THICK, plan.desert.far_wall_height, plan.desert_gates)
	for k in plan.rings.size():
		var ring: RoundMaze.Ring = plan.rings[k]
		var style := ring.style
		# The great wall round its inside, with its gates: the outer wall of the
		# circle inside it, or for the first the desert's far wall.
		var inside_high := plan.rings[k - 1].style.section_border_wall_height if k > 0 else (plan.desert.far_wall_height if plan.desert else MazeBuilder.RING_HEIGHT)
		_circle(k, ring.inner, MazeBuilder.RING_THICK, inside_high, ring.gates_in)
		if k == plan.rings.size() - 1:
			_circle(k, ring.outer, MazeBuilder.RING_THICK, style.section_border_wall_height, ring.gates_out)
		var thick := style.maze_wall_diameter
		var high := style.maze_wall_height
		for i in ring.rows.size():
			var row: Array = ring.rows[i]
			var cells: int = row[2]
			for j in cells:
				# Out from the middle between it and the next round, where they are not joined.
				if not RoundMaze.joined(ring, Vector2i(i, j), Vector2i(i, (j + 1) % cells)):
					_radial(k, RoundMaze.angle_of(j + 1, cells), row[0], row[1], thick, high)
				# Round between it and the cells of the next row out that it touches.
				if i + 1 < ring.rows.size():
					for touch: Array in RoundMaze.touching(j, cells, ring.rows[i + 1][2]):
						if not RoundMaze.joined(ring, Vector2i(i, j), Vector2i(i + 1, touch[0])):
							_arc(k, row[1], touch[1], touch[2], thick, high, false)
	var maze_material := Wall.material_for(MazeBuilder.MAZE_LOOK, true)
	var great_material := Wall.material_for(MazeBuilder.GREAT_LOOK, true)
	great_material.set_shader_parameter(&"tile_size", Wall.LOOKS[MazeBuilder.GREAT_LOOK][1] * MazeBuilder.GREAT_TILE_SCALE)
	for key: Array in _parts:
		var part: Array = _parts[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part[0]
		arrays[Mesh.ARRAY_NORMAL] = part[1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var shown := MeshInstance3D.new()
		shown.mesh = mesh
		shown.material_override = great_material if key[0] == 1 else maze_material
		# (in the editor, seen from far over the whole maze, always)
		shown.visibility_range_end = 0.0 if Engine.is_editor_hint() else FAR
		add_child(shown)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(part[0])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
	# (its shapes all in before it goes into the world: see MazeBuilder.realize)
	add_child(body)
	# The light past the way out.
	beacon = MazeBuilder.beacon_light()
	beacon.name = "Beacon"
	beacon.position = Vector3(cos(plan.exit_angle), 0.0, sin(plan.exit_angle)) * (plan.outermost() + 22.0)
	add_child(beacon)


## A point `r` out at angle `a`, on the ground.
static func at(a: float, r: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a)) * r


## A great wall round the circle `r` out, but for a gap at each of `gates` (angles).
func _circle(k: int, r: float, thick: float, high: float, gates: Array[float]) -> void:
	var gap := RoundMaze.GATE_WIDE * 0.5 / r
	var count := ceili(TAU / STEP)
	for n in count:
		var a0 := TAU * n / count
		var a1 := TAU * (n + 1) / count
		var lo := a0
		var hi := a1
		var whole := true
		for g: float in gates:
			# (the stretch of this length inside the gap, if any, is left out)
			var g0 := g - gap
			var g1 := g + gap
			for shift: float in [-TAU, 0.0, TAU]:
				var s0 := g0 + shift
				var s1 := g1 + shift
				if s1 <= lo or s0 >= hi:
					continue
				whole = false
				if s0 > lo:
					_arc(k, r, lo, s0, thick, high, true)
				lo = maxf(lo, s1)
		if whole or lo < hi:
			_arc(k, r, lo, hi, thick, high, true)


## A wall round the circle `r` out from angle `a0` to `a1`, in straight lengths.
func _arc(k: int, r: float, a0: float, a1: float, thick: float, high: float, great: bool) -> void:
	var lengths := maxi(ceili((a1 - a0) / STEP), 1)
	for n in lengths:
		var b0 := a0 + (a1 - a0) * n / lengths
		var b1 := a0 + (a1 - a0) * (n + 1) / lengths
		var middle := (b0 + b1) * 0.5
		var half := (b1 - b0) * 0.5
		# (a little longer than the chord, so that the lengths meet round the outside)
		var long := 2.0 * r * sin(half) + thick * tan(half) * 2.0 + 0.05
		_box(k, middle, r * cos(half), Vector3(long, high, thick), great)


## A wall out from `r0` to `r1` at angle `a` (as long again as the walls it meets are thick, to meet them).
func _radial(k: int, a: float, r0: float, r1: float, thick: float, high: float, great := false) -> void:
	_box(k, a, (r0 + r1) * 0.5, Vector3(thick, high, r1 - r0 + thick), great)


## A box `size` (along the circle, high, out) standing with its middle `r` out
## at angle `a`.
func _box(k: int, a: float, r: float, size: Vector3, great: bool) -> void:
	var out := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-out.z, 0.0, out.x)
	var middle := out * r
	var stretch := posmod(floori(a / TAU * STRETCHES), STRETCHES)
	var key := [1 if great else 0, k, stretch]
	if not _parts.has(key):
		_parts[key] = [PackedVector3Array(), PackedVector3Array()]
	var part: Array = _parts[key]
	var points: PackedVector3Array = part[0]
	var normals: PackedVector3Array = part[1]
	var hx := along * size.x * 0.5
	var hz := out * size.z * 0.5
	var top := Vector3.UP * size.y
	# (each face as two triangles, wound so that its outside is its front)
	for face: Array in [[hz, hx, top], [-hz, -hx, top], [hx, -hz, top], [-hx, hz, top]]:
		var n: Vector3 = face[0]
		var w: Vector3 = face[1]
		var c := middle + n
		var p0 := c - w
		var p1 := c + w
		var p2 := c + w + top
		var p3 := c - w + top
		_quad(points, normals, p0, p1, p2, p3, n.normalized())
	var corner := [middle - hx - hz, middle + hx - hz, middle + hx + hz, middle - hx + hz]
	_quad(points, normals, corner[3] + top, corner[2] + top, corner[1] + top, corner[0] + top, Vector3.UP)
	part[0] = points
	part[1] = normals


static func _quad(points: PackedVector3Array, normals: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	# (Godot's fronts are wound clockwise as seen from in front)
	var tris := [p0, p2, p1, p0, p3, p2]
	if (p1 - p0).cross(p2 - p0).dot(normal) < 0.0:
		tris = [p0, p1, p2, p0, p2, p3]
	for p: Vector3 in tris:
		points.append(p)
		normals.append(normal)
