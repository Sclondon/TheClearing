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
## A transform that draws nothing (the places of something not parked).
const NOTHING := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

## [square, key] -> Part
var _parts := {}
## Instance id of what is parked (or was) -> [[part, first place, how many], ...]
var _places := {}
## Instance ids of those parked now.
var _parked := {}


## One MultiMesh of a square: the rows of its instances (12 floats a transform, 4 more
## a colour), its places handed out in turn, and whether it is to be sent again.
class Part:
	var shown: MultiMeshInstance3D
	var stride := 12
	var rows := PackedFloat32Array()
	var count := 0
	var dirty := false


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
		var first: int
		if first_time:
			part = _part(square, draw)
			first = part.count
			part.count += rows.size() / part.stride
			part.rows.resize(part.count * part.stride)
			places.append([part, first, rows.size() / part.stride])
		else:
			part = places[k][0]
			first = places[k][1]
		# (the same number as when its places were kept: its instances do not change)
		var n := mini(rows.size(), int(places[k][2]) * part.stride)
		for i in n:
			part.rows[first * part.stride + i] = rows[i]
		part.dirty = true
	if first_time:
		_places[id] = places
		thing.tree_exiting.connect(_unpark.bind(id), CONNECT_ONE_SHOT)
	_parked[id] = true
	set_process(true)


func _unpark(id: int) -> void:
	if not _parked.has(id):
		return
	_parked.erase(id)
	for place: Array in _places.get(id, []):
		var part: Part = place[0]
		for i in int(place[2]):
			var o: int = (int(place[1]) + i) * part.stride
			for j in 12:
				part.rows[o + j] = 0.0
		part.dirty = true
	# (freed: its places stay empty)
	set_process(true)


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
	return part


## The squares that changed are sent to be drawn, once a frame at most.
func _process(_delta: float) -> void:
	for part: Part in _parts.values():
		if not part.dirty:
			continue
		part.dirty = false
		var multi := part.shown.multimesh
		if multi.instance_count != part.count:
			multi.instance_count = part.count
		multi.buffer = part.rows
	set_process(false)


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
