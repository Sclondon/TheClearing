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
		_leaf = Vine.leaf_material()
		_leaf_mesh = leaf_mesh(0.2)
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
## The flat patches drawn (_grow_plain), by where and how big, up to PLAIN_KEPT.
static var _plain_meshes := {}
const PLAIN_KEPT := 20000


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
	# as wide as its leaves spread: its shape, without the leaves. (Kept, by where
	# it is and how big: the maze editor builds a zone again and again, and most of
	# its patches come out where they were.)
	var key := hash([global_position.snappedf(0.01), height, width])
	var mesh: Mesh = _plain_meshes.get(key)
	if mesh == null:
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
		mesh = tool.commit()
		if _plain_meshes.size() >= PLAIN_KEPT:
			_plain_meshes.clear()
		_plain_meshes[key] = mesh
	var patch := MeshInstance3D.new()
	patch.mesh = mesh
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
		# (lying on the wall: as far out from it as the stem is thick)
		pieces.append([Vector3(at.x, at.y, thick), Vector3(next.x, next.y, thick), thick])
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
	# Leaves, on the stems: shared out by each length's share of all the stem, each
	# on its stalk from the stem, to one side or the other, lying over the wall (the
	# user, 2026-10-18: "try to make sure they arent just floating"; scattered either
	# side of the stems, they stood off the wall with nothing under them).
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	# (a wide patch, up a bare wall, has bigger leaves, so that it reads from across
	# a hall, and more than cover it, so that it is a mat and not a scatter)
	var leaf_scale := clampf(width / 1.8, 1.0, 2.4)
	# (as many as made a mat of the old diamond leaves, less a third: these are broader)
	var count := int(width * height * 70.0 * 1.3 * LEAF_SHARE / leaf_scale)
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
		var up := along.normalized()
		var thick: float = piece[2]
		owed += along.length() * per_metre
		# (a thick stem carries big old leaves, a thin shoot small young ones)
		var big := lerpf(0.75, 1.25, clampf((thick - 0.012) / 0.033, 0.0, 1.0)) * leaf_scale
		while owed >= 1.0 and i < count:
			owed -= 1.0
			# (its stalk's foot on the stem, to one side, its blade out and somewhat down
			# that side, lying over the wall: tilted from the stem's front back towards
			# it, its tip just off it)
			var way := 1.0 if rng.randf() < 0.5 else -1.0
			var out := (up.rotated(Vector3.BACK, way * rng.randf_range(0.6, 2.2)) + Vector3.DOWN * 0.3).normalized()
			out = Vector3(out.x, out.y, 0.0).normalized()
			var size := rng.randf_range(0.7, 1.3) * big
			var long := LEAF_LONG * size
			var foot := a + along * rng.randf() + out * thick * 0.5 + Vector3.BACK * thick * rng.randf_range(0.6, 1.5)
			var tip := rng.randf_range(0.012, 0.07)
			var lean := asin(clampf((tip - foot.z) / long, -0.6, 0.6))
			var y := out * cos(lean) + Vector3.BACK * sin(lean)
			var z := Vector3.BACK * cos(lean) - out * sin(lean)
			var basis := Basis(y.cross(z), y, z).rotated(y, rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * size)
			var at := foot
			# (paler and younger on the thin shoots, darker on the old stems)
			var colour := Color(0.11, 0.2, 0.08).lightened(rng.randf_range(-0.05, 0.1) + (1.0 - clampf((thick - 0.012) / 0.033, 0.0, 1.0)) * 0.07)
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


## How long a leaf is, stalk and all, metres (before its patch's and its own size),
## and how many leaves there are for as many as made a mat of the old diamonds.
const LEAF_LONG := 0.2
const LEAF_SHARE := 0.65


## An ivy leaf `size` long from the foot of its stalk to its tip, along +Y, its face
## to +Z (the user, 2026-10-18: "lets make a real leaf shape"): a long stalk, then
## five lobes, the middle one the longest, the two at its foot small, the blade
## dished a little and its lobes' tips curling back. Twelve triangles, a fan from
## its middle, paler in the middle where its veins meet (the colours multiply each
## leaf's own).
static func leaf_mesh(size: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := size * 0.24
	var blade := size - stalk
	# (round the blade's right half from the notch the stalk goes into to the tip:
	# [across, along, how far it curls back], as shares of the blade; the left as its mirror)
	var half := [[0.0, 0.08, 0.02], [0.36, 0.0, -0.05], [0.29, 0.28, 0.02], [0.52, 0.5, -0.07], [0.17, 0.62, 0.02], [0.0, 1.0, -0.09]]
	var outline: Array[Vector3] = []
	for k in half.size():
		outline.append(Vector3(half[k][0], half[k][1], half[k][2]) * blade + Vector3.UP * stalk)
	for k in range(half.size() - 2, 0, -1):
		outline.append(Vector3(-half[k][0], half[k][1], half[k][2]) * blade + Vector3.UP * stalk)
	var middle := Vector3(0.0, stalk + blade * 0.38, 0.0)
	var pale := Color(1.0, 1.0, 0.82)
	var tip := Color(0.72, 0.76, 0.68)
	var notch := Color(0.86, 0.9, 0.8)
	for k in outline.size():
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		for v: Vector3 in [middle, p, q]:
			tool.set_color(pale if v == middle else (tip if v.z < 0.0 else notch))
			tool.add_vertex(v)
	var s := size * 0.02
	var foot := Color(0.85, 0.75, 0.6)
	for v: Vector3 in [Vector3(-s, 0, 0), Vector3(s, 0, 0), Vector3(s, stalk + blade * 0.1, 0), Vector3(-s, 0, 0), Vector3(s, stalk + blade * 0.1, 0), Vector3(-s, stalk + blade * 0.1, 0)]:
		tool.set_color(foot if v.y == 0.0 else pale)
		tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


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
