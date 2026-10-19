class_name VineThicket
extends Node3D
## The vines at rest, drawn together: for each SQUARE metres of the maze, one
## MultiMesh each of the stems' pieces, the knots, the leaves and each shape of
## roots, of every vine and strung vine there that is hanging still. A maze thick
## with vines has tens of thousands, and drawn each by itself (a stem, a knot, its
## leaves, its roots) they were thousands of draws a frame.
##
## A vine (or a strung vine) that comes to rest (Rope.rest) is parked here: what it
## draws is copied into its square's MultiMeshes, in places kept for it, and its
## own are hidden. Woken (its next step), it is unparked: its places here are
## emptied and it draws itself again as it moves. Nothing of how it looks changes.
##
##     VineThicket.park(vine, [[key, mesh, material, shadows, seen, colours, rows], ...])
##     VineThicket.unpark(vine)

## How big a square is, metres.
const SQUARE := 32.0

## [square, key] -> Part
var _parts := {}
## Instance id of what is parked (or was) -> [[part, first place, how many], ...]
var _places := {}
## Instance ids of those parked now.
var _parked := {}


## One MultiMesh of a square: each thing's rows in it (12 floats a transform, 4 more a
## colour), one PackedFloat32Array each (all zero for one not parked: drawn as
## nothing), put together when it is sent again; and whether it is to be.
class Part:
	var shown: MultiMeshInstance3D
	var stride := 12
	var segments: Array[PackedFloat32Array] = []
	var count := 0
	var dirty := false

	func rows() -> PackedFloat32Array:
		var all := PackedFloat32Array()
		for segment in segments:
			all.append_array(segment)
		return all


## The thicket under `holder` (the vines' parent), made if there is none yet.
static func of(holder: Node) -> VineThicket:
	var found := holder.get_node_or_null(^"VineThicket") as VineThicket
	if found == null:
		found = VineThicket.new()
		found.name = "VineThicket"
		holder.add_child(found)
		found.global_transform = Transform3D.IDENTITY
	return found


## Parks `thing` (in the tree, at rest): `draws` is what it draws, each [key (what
## mesh and material, the same for all that share them), mesh, material, whether it
## casts shadows, how far off it is seen, whether it has colours, and its instances'
## rows as a MultiMesh's buffer has them (12 floats a transform, then 4 a colour)].
## Its own drawing is the caller's to hide.
static func park(thing: Node3D, draws: Array) -> void:
	if Engine.is_editor_hint() or not thing.is_inside_tree() or thing.get_parent() == null:
		return
	of(thing.get_parent())._park(thing, draws)


## Unparks `thing`: its places are emptied. Its own drawing is the caller's to show.
static func unpark(thing: Node3D) -> void:
	if not thing.is_inside_tree() or thing.get_parent() == null:
		return
	var found := thing.get_parent().get_node_or_null(^"VineThicket") as VineThicket
	if found:
		found._unpark(thing.get_instance_id())


func _park(thing: Node3D, draws: Array) -> void:
	var id := thing.get_instance_id()
	var at := thing.global_position
	if thing.has_method(&"near_spot"):
		var spot: Vector4 = thing.call(&"near_spot")
		at = Vector3(spot.x, spot.y, spot.z)
	var square := Vector2i(floori(at.x / SQUARE), floori(at.z / SQUARE))
	var places: Array = _places.get(id, [])
	var first_time := places.is_empty()
	for k in draws.size():
		var draw: Array = draws[k]
		var rows: PackedFloat32Array = draw[6]
		var part: Part
		var which: int
		if first_time:
			part = _part(square, draw)
			which = part.segments.size()
			part.segments.append(rows)
			part.count += rows.size() / part.stride
			places.append([part, which, rows.size()])
		else:
			part = places[k][0]
			which = places[k][1]
			# (the same size as when its place was kept: its instances do not change)
			if rows.size() != int(places[k][2]):
				rows.resize(int(places[k][2]))
			part.segments[which] = rows
		if not part.dirty:
			part.dirty = true
			_dirty.append(part)
	if first_time:
		_places[id] = places
		thing.tree_exiting.connect(_unpark.bind(id), CONNECT_ONE_SHOT)
	_parked[id] = true


func _unpark(id: int) -> void:
	if not _parked.has(id):
		return
	_parked.erase(id)
	for place: Array in _places.get(id, []):
		var part: Part = place[0]
		var nothing := PackedFloat32Array()
		nothing.resize(int(place[2]))
		part.segments[int(place[1])] = nothing
		if not part.dirty:
			part.dirty = true
			_dirty.append(part)
	# (freed: its place stays empty)


func _part(square: Vector2i, draw: Array) -> Part:
	var key := [square, draw[0]]
	var part: Part = _parts.get(key)
	if part:
		return part
	part = Part.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = draw[5]
	multi.mesh = draw[1]
	part.stride = 16 if draw[5] else 12
	part.shown = MultiMeshInstance3D.new()
	part.shown.multimesh = multi
	part.shown.material_override = draw[2]
	part.shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if draw[3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (seen as far off as each of them is, from the middle of the square)
	part.shown.visibility_range_end = float(draw[4]) + SQUARE * 0.71
	add_child(part.shown)
	_parts[key] = part
	if not _squares.has(square):
		_squares[square] = []
	(_squares[square] as Array).append(part)
	part.shown.visible = not _out_of_sight.has(square)
	return part


## The squares that changed are sent to be drawn, once a frame at most; and the
## squares out of the camera's sight (MazeSight) are not drawn.
func _process(_delta: float) -> void:
	for part: Part in _dirty:
		part.dirty = false
		var multi := part.shown.multimesh
		if multi.instance_count != part.count:
			multi.instance_count = part.count
		multi.buffer = part.rows()
	_dirty.clear()
	_cull()


## Squares (Vector2i) -> their Parts; those hidden now, out of sight; and what was
## in sight when they were last hidden or shown (MazeSight.version).
var _squares := {}
var _out_of_sight := {}
var _sight_version := -1
var _maze: Maze
var _dirty: Array[Part] = []


## Hides the squares none of whose cells are in sight, and shows again those that are.
func _cull() -> void:
	if _maze == null:
		var up := get_parent()
		while up != null and not (&"maze" in up and up.get(&"maze") is Maze):
			up = up.get_parent()
		if up == null:
			return
		_maze = up.get(&"maze")
	MazeSight.look(_maze)
	if MazeSight.version == _sight_version:
		return
	_sight_version = MazeSight.version
	var showing := {}
	if MazeSight.everything():
		showing = _squares
	else:
		var size := _maze.size
		var middle := (size - 1) * 0.5
		var half := Maze.CELL * 0.5
		for index: int in MazeSight.seen():
			var x := (index % size - middle) * Maze.CELL
			var z := (index / size - middle) * Maze.CELL
			for sz in range(floori((z - half) / SQUARE), floori((z + half) / SQUARE) + 1):
				for sx in range(floori((x - half) / SQUARE), floori((x + half) / SQUARE) + 1):
					showing[Vector2i(sx, sz)] = true
		# (and the squares round the camera itself)
		var eye := MazeSight.eye()
		var near := MazeSight.NEAR
		for sz in range(floori((eye.z - near) / SQUARE), floori((eye.z + near) / SQUARE) + 1):
			for sx in range(floori((eye.x - near) / SQUARE), floori((eye.x + near) / SQUARE) + 1):
				showing[Vector2i(sx, sz)] = true
	for square: Vector2i in _squares:
		var hide := not showing.has(square)
		if hide == _out_of_sight.has(square):
			continue
		if hide:
			_out_of_sight[square] = true
		else:
			_out_of_sight.erase(square)
		for part: Part in _squares[square]:
			part.shown.visible = not hide


## How many are parked now (for tests and probes).
func parked() -> int:
	return _parked.size()


## The rows of one transform, as a MultiMesh's buffer has them.
static func rows_of(t: Transform3D) -> PackedFloat32Array:
	return PackedFloat32Array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x,
			t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
			t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z])


## What a MultiMeshInstance3D draws, for `park`: [key, its mesh and material, ...].
static func draw_of(key: Variant, shown: MultiMeshInstance3D, seen: float) -> Array:
	return [key, shown.multimesh.mesh, shown.material_override, shown.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			seen, shown.multimesh.use_colors, shown.multimesh.buffer]


## What a MeshInstance3D draws, for `park`.
static func draw_of_mesh(key: Variant, shown: MeshInstance3D, seen: float) -> Array:
	return [key, shown.mesh, shown.material_override, shown.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			seen, false, rows_of(shown.global_transform)]
