class_name GnomeHollow
extends Node3D
## Where gnomes live: a hollow at the foot of a wall, with a little weathered
## door in it standing ajar on the dark, an arch of rough stones round it, a heap
## of dug earth and pebbles in front, and roots trailing over it. Built in code,
## one mesh (one draw), no textures.
##
## Put it with its origin on the ground at the foot of the wall's face and its
## +Z pointing out of the wall (Y up). `mouth()` is the spot just before the
## door where a gnome goes in; `hoard_spot(k)` places by it to lay what they
## have taken, in a little heap.

## How wide and high the doorway is, metres.
@export var door_size := Vector2(0.46, 0.68)
## How far the door stands open, radians (0 shut).
@export var ajar := 0.6
@export var seed_value := 0

const DARK := Color(0.012, 0.01, 0.009)
const WOOD := Color(0.16, 0.14, 0.12)
const WOOD_DARK := Color(0.08, 0.07, 0.06)
const STONE := Color(0.2, 0.2, 0.19)
const EARTH := Color(0.09, 0.07, 0.055)
const ROOT := Color(0.07, 0.055, 0.045)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_darkness(tool)
	_arch(tool)
	_door(tool)
	_earth(tool)
	_roots(tool)
	tool.generate_normals()
	var shown := MeshInstance3D.new()
	shown.name = "Hollow"
	shown.mesh = tool.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	shown.material_override = mat
	add_child(shown)


## The spot just before the door, where a gnome goes in (world).
func mouth() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 0.4)


## A place by the door to lay a thing taken (world), the `k`th of a little heap.
func hoard_spot(k: int) -> Vector3:
	var a := 0.9 + k * 1.3
	return global_transform * Vector3(sin(a) * (0.35 + 0.08 * k), 0.02, 0.45 + absf(cos(a)) * 0.25)


# --- Building it ---

## The dark of the doorway, a little way into the wall, arched at the top.
func _darkness(tool: SurfaceTool) -> void:
	var w := door_size.x * 0.5
	var h := door_size.y
	var spring := h - w
	var depth := 0.008
	var outline: Array[Vector3] = [Vector3(-w, 0.0, depth), Vector3(w, 0.0, depth)]
	for k in 9:
		var a := PI * k / 8.0
		outline.append(Vector3(w * cos(a), spring + w * sin(a), depth))
	var middle := Vector3(0.0, h * 0.45, depth)
	tool.set_color(DARK)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		_tri(tool, middle, b, a)


## Rough stones round the doorway.
func _arch(tool: SurfaceTool) -> void:
	var w := door_size.x * 0.5 + 0.05
	var spring := door_size.y - door_size.x * 0.5
	for k in 11:
		var a := PI * k / 10.0
		var at := Vector3(w * cos(a), spring + w * sin(a), 0.02) if k > 0 and k < 10 else Vector3(w * (1.0 if k == 0 else -1.0), spring * 0.5, 0.02)
		var size := Vector3(_rng.randf_range(0.07, 0.1), _rng.randf_range(0.06, 0.09), 0.06)
		_lump(tool, at, size, STONE.darkened(_rng.randf_range(0.0, 0.35)), 5)
	for k in 3:
		var side := 1.0 if k % 2 == 0 else -1.0
		_lump(tool, Vector3(side * (w + 0.01), 0.05 + k * 0.08, 0.03), Vector3(0.08, 0.06, 0.06), STONE.darkened(_rng.randf_range(0.1, 0.4)), 5)


## The door, planks and two iron straps, standing open on its hinge.
func _door(tool: SurfaceTool) -> void:
	var w := door_size.x * 0.92
	var h := door_size.y * 0.9
	var hinge := Vector3(-door_size.x * 0.5, 0.01, -0.01)
	var turn := Basis(Vector3.UP, -ajar)
	var t := 0.035
	var planks := 4
	for p in planks:
		var x0 := w * p / planks
		var x1 := w * (p + 1) / planks - 0.006
		var top := h - 0.12 * pow(absf((x0 + x1) * 0.5 / w - 0.5) * 2.0, 2.0)
		var col := WOOD.darkened(_rng.randf_range(0.0, 0.3))
		_box(tool, hinge, turn, Vector3(x0, 0.0, -t * 0.5), Vector3(x1, top, t * 0.5), col)
	for y in [0.12, h - 0.16]:
		_box(tool, hinge, turn, Vector3(0.0, y, t * 0.5), Vector3(w * 0.9, y + 0.025, t * 0.5 + 0.008), WOOD_DARK)


## Dug earth heaped before it, and pebbles.
func _earth(tool: SurfaceTool) -> void:
	for k in 5:
		var a := -1.2 + k * 0.6
		var at := Vector3(sin(a) * 0.42, 0.0, 0.18 + cos(a) * 0.22)
		_lump(tool, at, Vector3(_rng.randf_range(0.18, 0.26), _rng.randf_range(0.05, 0.09), _rng.randf_range(0.14, 0.2)), EARTH.lightened(_rng.randf_range(0.0, 0.12)), 7)
	for k in 9:
		var at := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(0.15, 0.7))
		var r := _rng.randf_range(0.02, 0.05)
		_lump(tool, at, Vector3(r, r * 0.7, r), STONE.darkened(_rng.randf_range(0.0, 0.4)), 4)


## Roots trailing down over the arch from above, out of cracks in the wall.
func _roots(tool: SurfaceTool) -> void:
	for k in 6:
		var x := _rng.randf_range(-0.3, 0.3)
		var top := door_size.y + _rng.randf_range(0.02, 0.12)
		var long := _rng.randf_range(0.15, 0.4)
		var points: Array[Vector3] = []
		for s in 6:
			var u := s / 5.0
			points.append(Vector3(x + sin(u * 3.0 + k) * 0.04, top - long * u, 0.02 + 0.05 * sin(u * PI)))
		for s in points.size() - 1:
			var r := 0.008 * (1.0 - s / 6.0) + 0.002
			_rod(tool, points[s], points[s + 1], r, ROOT)


# --- Shapes ---

func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tool.set_color(col)
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)


## A box from `lo` to `hi` (in the frame of `turn` about `pivot`).
func _box(tool: SurfaceTool, pivot: Vector3, turn: Basis, lo: Vector3, hi: Vector3, col: Color) -> void:
	var c := []
	for i in 8:
		var p := Vector3(hi.x if i & 1 else lo.x, hi.y if i & 2 else lo.y, hi.z if i & 4 else lo.z)
		c.append(pivot + turn * p)
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	for f in faces:
		_quad(tool, c[f[0]], c[f[1]], c[f[2]], c[f[3]], col)


## A rough lump: a squashed, jittered half-sphere sitting on `at`.
func _lump(tool: SurfaceTool, at: Vector3, size: Vector3, col: Color, sides: int) -> void:
	var rings := 3
	var grid := []
	for r in rings + 1:
		var v := float(r) / rings
		var row := []
		for s in sides:
			var a := TAU * s / sides
			var jitter := _rng.randf_range(0.85, 1.15)
			var up := sin(v * PI * 0.5)
			var out := cos(v * PI * 0.5) * jitter
			row.append(at + Vector3(cos(a) * size.x * out, size.y * up * jitter, sin(a) * size.z * out))
		grid.append(row)
	for r in rings:
		for s in sides:
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][(s + 1) % sides]
			var c: Vector3 = grid[r + 1][(s + 1) % sides]
			var d: Vector3 = grid[r + 1][s]
			_quad(tool, a, d, c, b, col)


## A thin square rod from `a` to `b`.
func _rod(tool: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.BACK).normalized() * r
	var up := along.cross(side).normalized() * r
	var ring := [side, up, -side, -up]
	for i in 4:
		var p: Vector3 = ring[i]
		var q: Vector3 = ring[(i + 1) % 4]
		_quad(tool, a + p, b + p, b + q, a + q, col)
