@tool
class_name IvyClimb
extends Ladder
## Ivy grown thick enough up a wall to climb: a Ladder (the boy takes hold by
## going into it, climbs with up and down, steps off at the top onto whatever it
## grows up against, and leaps off backwards with jump), drawn as old woody stems
## up the face with a mat of leaves over them, `width` across. Its back is to
## the wall: place it on the face with its +Z pointing out, as a Ladder.

@export var width := 1.8

static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _leaf_mesh: ArrayMesh

## How near the camera must come for it to be drawn, metres (it is lost in the
## mist further off: its leaves are not drawn past 160 m), and how often it looks.
const SHOWN_FROM := 175.0
const LOOK_EVERY := 0.5
## Whether its stems and leaves are drawn yet; and the one Grower for the level,
## which looks for patches near the camera (each looking for itself every frame
## cost milliseconds: a maze has thousands).
var grown := false
static var _grower: Node


func _ready() -> void:
	add_to_group(&"ladders")
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.24, 0.2, 0.14)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf.roughness = 1.0
		_leaf.metallic_specular = 0.0
		_leaf_mesh = Vine.leaf_mesh(0.18)
	# (drawn only once the camera first comes near enough to see it: a maze has
	# hundreds of patches, too many leaves to lay all at once; the editor draws all)
	if Engine.is_editor_hint() and plain:
		_grow_plain()
	elif Engine.is_editor_hint():
		_grow()
	else:
		if not is_instance_valid(_grower):
			_grower = Grower.new()
			_grower.name = "IvyGrower"
			get_tree().root.add_child.call_deferred(_grower)
		(_grower as Grower).waiting.append(self)


## Goes round the patches not drawn yet, a share of them each frame (all of them
## each LOOK_EVERY), and draws those the camera has come near, a few a frame.
class Grower extends Node:
	## How long it may spend a frame drawing patches that have come near, microseconds.
	const BUDGET := 2000
	var waiting: Array = []
	var _at := 0
	var _due: Array = []

	func _process(delta: float) -> void:
		var camera := get_viewport().get_camera_3d()
		if camera and not waiting.is_empty():
			var eye := camera.global_position
			var share := ceili(waiting.size() * delta / IvyClimb.LOOK_EVERY)
			for k in share:
				if waiting.is_empty():
					break
				_at = _at % waiting.size()
				var ivy = waiting[_at]
				if not is_instance_valid(ivy) or ivy.grown:
					waiting[_at] = waiting[-1]
					waiting.pop_back()
				elif ivy.global_position.distance_to(eye) < IvyClimb.SHOWN_FROM:
					_due.append(ivy)
					waiting[_at] = waiting[-1]
					waiting.pop_back()
				else:
					_at += 1
		var started := Time.get_ticks_usec()
		while not _due.is_empty() and Time.get_ticks_usec() - started < BUDGET:
			var ivy = _due.pop_back()
			if is_instance_valid(ivy) and not ivy.grown:
				ivy._grow()


## In the editor, patches are drawn as flat green, not grown leaf by leaf: Generate
## and the live preview put thousands at once, nearly a minute of leaves. (The game
## grows them as the camera comes near.)
static var plain := true
static var _plain_material: StandardMaterial3D


## He climbs across it as well as up: most of its width, not its ragged edges.
func spread() -> float:
	return maxf(width * 0.5 - 0.35, 0.0)


## Draws it as a flat green patch where its leaves would be.
func _grow_plain() -> void:
	grown = true
	if _plain_material == null:
		_plain_material = StandardMaterial3D.new()
		_plain_material.albedo_color = Color(0.22, 0.32, 0.16)
		_plain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The same growth as in the game, coarser, each length of it a flat green band
	# as wide as its leaves spread: its shape, without the leaves.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snappedf(0.01))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece: Array in _network(rng, 2.0):
		var a: Vector3 = piece[0]
		var b: Vector3 = piece[1]
		var side: Vector3 = (b - a).cross(Vector3.BACK).normalized() * (0.2 + float(piece[2]) * 6.0)
		for v: Vector3 in [a - side, b - side, b + side, a - side, b + side, a + side]:
			tool.add_vertex(v + Vector3.BACK * 0.03)
	var patch := MeshInstance3D.new()
	patch.mesh = tool.commit()
	patch.material_override = _plain_material
	add_child(patch)


## How it has grown: lengths of stem up the face, as [from, to, thickness]
## (in its own space, close against the wall). A few stems root along its foot
## and climb, wandering, drawn back towards the middle of the patch as they
## stray; side shoots fork off them now and then and reach out a short way,
## some forking again. So the patch is thick where the stems run and ragged at
## its edges and top, with tendrils past them, as ivy is, not a square of it.
## `coarse` makes the lengths that many times longer (fewer of them).
func _network(rng: RandomNumberGenerator, coarse := 1.0) -> Array:
	var pieces: Array = []
	# Each growing tip: [where (x, up), which way, how thick, lengths left (-1: to the
	# top), forks deep, how high it may go (each stem stops at its own: the top is ragged)].
	var tips: Array = []
	var roots := clampi(int(width / 0.5), 3, 8)
	for r in roots:
		var x := lerpf(-0.42, 0.42, (r + 0.5) / roots) * width + rng.randf_range(-0.15, 0.15)
		tips.append([Vector2(x, 0.0), Vector2(rng.randf_range(-0.3, 0.3), 1.0).normalized(), 0.045, -1, 0, height * rng.randf_range(0.82, 1.06)])
	var guard := 0
	while not tips.is_empty() and guard < 6000:
		guard += 1
		var tip: Array = tips.pop_back()
		var at: Vector2 = tip[0]
		var way: Vector2 = tip[1]
		var thick: float = tip[2]
		var left: int = tip[3]
		var deep: int = tip[4]
		if left == 0:
			continue
		var top: float = tip[5]
		way = way.rotated(rng.randf_range(-0.4, 0.4))
		# (drawn up, and back towards the middle when it strays past the edge)
		var stray := at.x / maxf(width * 0.5, 0.1)
		way = (way + Vector2(-stray * 0.3, 0.45 if left < 0 else 0.1)).normalized()
		var next := at + way * rng.randf_range(0.25, 0.45) * coarse
		next.x = clampf(next.x, -width * 0.65, width * 0.65)
		if next.y > top or next.y < 0.0:
			continue
		pieces.append([Vector3(at.x, at.y, -0.08), Vector3(next.x, next.y, -0.08), thick])
		tips.append([next, way, maxf(thick * 0.985, 0.012), left - 1 if left > 0 else -1, deep, top])
		# A side shoot: out to one side and a little down, short, now and then forking.
		if deep < 2 and rng.randf() < (0.36 if deep == 0 else 0.18) * coarse:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			tips.append([next, way.rotated(side * rng.randf_range(0.7, 1.5)), maxf(thick * 0.55, 0.012), rng.randi_range(2, 7), deep + 1, top])
	return pieces


## Draws its stems and leaves: leaves along the stems, thickest where they run.
func _grow() -> void:
	grown = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snappedf(0.01))
	var pieces := _network(rng)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	for piece: Array in pieces:
		_branch(tool, piece[0], piece[1], piece[2])
		length += (piece[1] as Vector3).distance_to(piece[0])
	tool.generate_normals()
	var stems := MeshInstance3D.new()
	stems.mesh = tool.commit()
	stems.material_override = _stem
	add_child(stems)
	# Leaves, along the stems: as many as covered the patch before, shared out by
	# each length's share of all the stem, spread either side of it.
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	# (a wide patch, up a bare wall, has bigger leaves, so that it reads from across
	# a hall, and more than cover it, so that it is a mat and not a scatter)
	var leaf_scale := clampf(width / 1.8, 1.0, 2.4)
	# (as many as covered a square of it: along the stems, bigger, they make a mat)
	var count := int(width * height * 70.0 * 1.3 / leaf_scale)
	multi.instance_count = count
	# (all at once, as the multimesh's buffer: a transform, then a colour, for each)
	var buffer := PackedFloat32Array()
	buffer.resize(count * 16)
	var per_metre := count / maxf(length, 0.01)
	var i := 0
	var owed := 0.0
	for piece: Array in pieces:
		var a: Vector3 = piece[0]
		var b: Vector3 = piece[1]
		var along := b - a
		var side := along.cross(Vector3.BACK).normalized()
		owed += along.length() * per_metre
		# (a thick stem carries a broad fan of leaves, a thin shoot a narrow one)
		var spread := (0.22 + float(piece[2]) * 7.0) * leaf_scale
		while owed >= 1.0 and i < count:
			owed -= 1.0
			var off := rng.randfn(0.0, 0.5) * spread
			var at := a + along * rng.randf() + side * off + Vector3.BACK * rng.randf_range(0.0, 0.16)
			var basis := Basis(Vector3.BACK, rng.randf_range(-1.2, 1.2) + PI).rotated(Vector3.RIGHT, rng.randf_range(-0.9, -0.2))
			basis = basis.scaled(Vector3.ONE * rng.randf_range(0.7, 1.4) * leaf_scale)
			# (paler and younger out at the tips and edges, darker in the thick of it)
			var colour := Color(0.09, 0.17, 0.07).lightened(rng.randf_range(-0.05, 0.1) + clampf(absf(off) / spread, 0.0, 1.0) * 0.06)
			var o := i * 16
			for row in 3:
				buffer[o + row * 4] = basis[0][row]
				buffer[o + row * 4 + 1] = basis[1][row]
				buffer[o + row * 4 + 2] = basis[2][row]
				buffer[o + row * 4 + 3] = at[row]
			buffer[o + 12] = colour.r
			buffer[o + 13] = colour.g
			buffer[o + 14] = colour.b
			buffer[o + 15] = colour.a
			i += 1
	multi.instance_count = i
	multi.buffer = buffer.slice(0, i * 16)
	var leaves := MultiMeshInstance3D.new()
	leaves.multimesh = multi
	leaves.material_override = _leaf
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (lost in the mist further off than this anyway)
	leaves.visibility_range_end = 160.0
	add_child(leaves)


## A square-sectioned length of stem from `a` to `b`.
static func _branch(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.BACK).normalized() * radius
	var out := Vector3.BACK * radius
	var corners := [side + out, -side + out, -side - out, side - out]
	for k in 4:
		var p: Vector3 = corners[k]
		var q: Vector3 = corners[(k + 1) % 4]
		for v: Vector3 in [a + p, b + p, b + q, a + p, b + q, a + q]:
			tool.add_vertex(v)
