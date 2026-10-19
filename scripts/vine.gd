@tool
class_name Vine
extends Rope
## A vine hanging from a ledge, a wall or a beam: a Rope (so it swings, and the
## boy catches it, climbs it and leaps off it as he does a rope), drawn as a
## green stem with leaves along it that go where the stem goes.

## Leaves along each piece of the stem: at least LEAVES, and one for every
## LEAF_REACH metres of it (so a long vine is as leafy as a short one).
const LEAVES := 6
const LEAF_REACH := 0.25
## More leaves bunched round the top of the stem, where it is held, and how far
## down it they go, metres.
const TOP_LEAVES := 14
const TOP_REACH := 0.8
## How far out from the stem a leaf on it hangs, from lying down along it, radians:
## between these, each its own (hanging down and out, its face out from the stem, it
## is seen face on from beside the vine, not edge on as when it stood out level).
const LEAN := Vector2(0.45, 1.05)

static var _leaf_mesh: ArrayMesh
static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D

var _leaves: MultiMeshInstance3D
## Each leaf's piece, how far along it, which way round the stem, how big, and how
## far out from the stem it hangs.
var _placing: Array = []
## Which way from its top what holds it is (a wall, a ledge's edge, a bridge; 0: over it): its roots grip that.
var hold := Vector3.ZERO
## What holds it there (Held), and how far its top is from it, metres (from the
## wall's face, or out past the ledge's edge).
var held: int = Held.OVER
var reach := 0.0

## How a vine is held at its top (or a strung vine at an end): what its roots grip.
enum Held {
	## Under something over it (a beam's or a bracket's underside): its roots spread over that.
	OVER,
	## Over the lip of a ledge, a corbel or a bridge, level with its top: the stem comes up
	## over the edge and its roots spread over the top (and grip the edge's face a little).
	LIP,
	## Out of a wall's face: the stem grows out of the face, and its roots spread over it.
	FACE,
	## Out of the ground (a vine swept down to the floor): its roots spread over the ground.
	GROUND,
}


func _init() -> void:
	thickness = 0.04


func _ready() -> void:
	super()
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.2, 0.24, 0.12)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = leaf_material()
		_leaf_mesh = leaf_mesh(0.2)
	_links.material_override = _stem
	_knot.material_override = _stem
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snappedf(0.01))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	var each := maxi(LEAVES, roundi(length / PIECES / LEAF_REACH))
	var on_stem := PIECES * each + TOP_LEAVES
	multi.instance_count = on_stem + ANCHOR_LEAVES
	for i in PIECES * each:
		_placing.append([i / each, rng.randf(), rng.randf() * TAU, rng.randf_range(0.7, 1.2), rng.randf_range(LEAN.x, LEAN.y)])
		multi.set_instance_color(i, leaf_colour(rng))
	# (bunched round the top of the stem, thickest nearest it)
	var top_share := minf(1.0, TOP_REACH / maxf(length / PIECES, 0.01))
	for k in TOP_LEAVES:
		_placing.append([0, pow(rng.randf(), 1.6) * top_share, rng.randf() * TAU, rng.randf_range(0.6, 1.05), rng.randf_range(LEAN.x, LEAN.y)])
		multi.set_instance_color(PIECES * each + k, leaf_colour(rng))
	# (where it is held: young green roots over what holds it, and a bunch of leaves over them)
	var how := held
	if how == Held.OVER and hold.length_squared() > 0.0001:
		how = Held.LIP
	var made := anchor(global_position, hold, how, reach, true, rng, ANCHOR_LEAVES)
	add_child(made[0])
	for k in ANCHOR_LEAVES:
		multi.set_instance_transform(on_stem + k, made[1][k][0])
		multi.set_instance_color(on_stem + k, made[1][k][1])
	_leaves = MultiMeshInstance3D.new()
	_leaves.multimesh = multi
	_leaves.material_override = _leaf
	_leaves.top_level = true
	_leaves.visibility_range_end = Rope.SEEN
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leaves)
	_draw()


func _draw() -> void:
	super()
	if _leaves == null:
		return
	var multi := _leaves.multimesh
	for i in _placing.size():
		var place: Array = _placing[i]
		var a := _points[place[0]]
		var b := _points[place[0] + 1]
		var along := (b - a).normalized() if a.distance_squared_to(b) > 0.000001 else Vector3.DOWN
		var out := round_stem(along, Vector3.DOWN, Vector3.RIGHT, place[2])
		# (its stalk's foot on the stem: a little inside it, as the stem is drawn six-sided)
		var at := a.lerp(b, place[1]) + out * thickness * 0.8
		multi.set_instance_transform(i, Transform3D(stem_leaf(along, out, place[3], place[4]), at))


## How a leaf sits on a stem running `along` that stands out of it the `out` way
## (at right angles to it), `size` times as big as the mesh: its stalk out from
## the stem, its blade hanging down along it and `lean` out from it, its face out.
static func stem_leaf(along: Vector3, out: Vector3, size: float, lean: float) -> Basis:
	var y := along * cos(lean) + out * sin(lean)
	var z := out * cos(lean) - along * sin(lean)
	return Basis(y.cross(z), y, z).scaled(Vector3.ONE * size)


## A leaf's colour, as `rng` says: green, some paler and younger, some darker.
static func leaf_colour(rng: RandomNumberGenerator) -> Color:
	return Color(0.19, 0.31, 0.14).lightened(rng.randf_range(-0.12, 0.22))


## The material of every vine's leaves: coloured by each leaf's colour, both sides drawn.
static func leaf_material() -> StandardMaterial3D:
	var made := StandardMaterial3D.new()
	made.vertex_color_use_as_albedo = true
	made.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.roughness = 1.0
	made.metallic_specular = 0.0
	return made


# --- Where it is held ---
# (the user, 2026-10-18: "the vines need to have a root or leaves at their connection
# points"; and then "The roots should be smaller and green, and more leaves should be
# bunched around the connection": young green tendrils and rootlets lying over what holds
# it, never out into the air, and a bunch of leaves on them)

## How many leaves are bunched round where a vine is held (on its roots, and on the
## stem where it comes out to hang).
const ANCHOR_LEAVES := 48
## How thick the stem is where it is held (a vine's), metres.
const HELD_STEM := 0.04
## The shapes of the roots, made once each: [what holds it, how far, hanging, which] ->
## [mesh, the spots on what holds it for leaves, the spots along the stem out to it].
static var _shapes := {}
static var _root_material: StandardMaterial3D


## The frame what holds a vine is described in at its top: +Z the way to what holds
## it, level (`hold`; any way round, as `rng` says, if it is over it), +Y up.
static func held_frame(hold: Vector3, rng: RandomNumberGenerator) -> Basis:
	var z := Vector3(hold.x, 0.0, hold.z)
	if z.length_squared() < 0.0001:
		z = Vector3.BACK.rotated(Vector3.UP, rng.randf() * TAU)
	z = z.normalized()
	return Basis(Vector3.UP.cross(z), Vector3.UP, z)


## Where a vine is held at `at`, `hold` the way to what holds it, held as `held`
## says (Vine.Held) `reach` metres from it, and whether the stem hangs down from
## there (`dangling`) or goes out level from it (a strung vine's end): its roots
## (one shape for many vines, drawn once each) and `count` leaves bunched over
## them, as [roots, [[transform, colour], ...]], in the world.
static func anchor(at: Vector3, hold: Vector3, held: int, reach: float, dangling: bool, rng: RandomNumberGenerator, count: int) -> Array:
	if _root_material == null:
		_root_material = StandardMaterial3D.new()
		_root_material.vertex_color_use_as_albedo = true
		_root_material.roughness = 1.0
		_root_material.metallic_specular = 0.0
		_root_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame := held_frame(hold, rng)
	var key := [held, snappedf(reach, 0.05), dangling, rng.randi() % 4]
	if not _shapes.has(key):
		_shapes[key] = _anchor_shape(key[0], key[1], key[2], key[3])
	var shape: Array = _shapes[key]
	var shown := MeshInstance3D.new()
	shown.mesh = shape[0]
	shown.material_override = _root_material
	shown.top_level = true
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.visibility_range_end = 90.0
	shown.transform = Transform3D(frame, at)
	var spots: Array = shape[1]
	var stem: Array = shape[2]
	var leaves: Array = []
	for i in count:
		var base: Vector3
		var leaf: Basis
		if not stem.is_empty() and i % 4 == 0:
			# (on the stem where it comes out to hang: standing out of it, its face up)
			var spot: Array = stem[rng.randi() % stem.size()]
			var tangent: Vector3 = spot[1]
			var out := tangent.cross(Vector3.UP * (1.0 if rng.randf() < 0.5 else -1.0) + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5))).normalized()
			if out.length_squared() < 0.5:
				out = tangent.cross(Vector3.RIGHT).normalized()
			base = spot[0] + out * HELD_STEM * 0.8
			var y := (out + tangent * 0.4).normalized()
			var z := Vector3.UP - y * y.y
			z = z.normalized() if z.length_squared() > 0.01 else -tangent
			leaf = Basis(y.cross(z), y, z)
		else:
			# (on a root, lying over what it holds, its stalk off the root: thickest near
			# where the vine is held, fewer out at the roots' tips)
			var spot: Array = spots[rng.randi() % spots.size()]
			if rng.randf() < float(spot[3]) * 0.6:
				spot = spots[rng.randi() % spots.size()]
			var normal: Vector3 = spot[1]
			var way := (spot[2] as Vector3).rotated(normal, rng.randf_range(0.4, 1.7) * (1.0 if rng.randf() < 0.5 else -1.0))
			# (lifted off it a little; hanging further from what is over it)
			var lift := rng.randf_range(0.5, 1.1) if held == Held.OVER else rng.randf_range(0.08, 0.45)
			var y := way * cos(lift) + normal * sin(lift)
			var z := normal * cos(lift) - way * sin(lift)
			base = spot[0]
			leaf = Basis(y.cross(z), y, z)
		var colour := leaf_colour(rng)
		leaves.append([Transform3D(frame * leaf.scaled(Vector3.ONE * rng.randf_range(0.7, 1.15)), at + frame * base), colour])
	return [shown, leaves]


## The roots of one way of being held (see anchor), in the frame of held_frame,
## the vine's top at the origin: [mesh, spots on what holds it ([where, out of
## it, the way the root runs there, how far along the root]), spots along the
## stem out to the top ([where, the way along it])].
static func _anchor_shape(held: int, reach: float, dangling: bool, which: int) -> Array:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([held, reach, dangling, which])
	var spots: Array = []
	var stem: Array = []
	var stem_colour := Color(0.2, 0.24, 0.12)
	var root_colour := Color(0.36, 0.48, 0.2)
	var hair_colour := Color(0.42, 0.45, 0.27)
	# Where the stem meets what holds it, the way out of that there, and the plane the
	# roots lie on (its two ways along it).
	var meet := Vector3.ZERO
	var normal := Vector3.UP
	var u := Vector3.RIGHT
	var v := Vector3.BACK
	var tendrils := 6 + which % 2
	var longest := 0.42
	# (the angles round `meet` the roots may run, in the plane, from `v`)
	var spread := Vector2(-PI, PI)
	# (how far along `normal` the surface the roots lie on is from the top)
	var plane := 0.0
	match held:
		Held.FACE:
			# (out of the face `reach` away, a little over the top when it hangs, and down to it)
			meet = Vector3(0.0, (0.1 + reach * 0.35) if dangling else 0.0, reach)
			normal = Vector3.FORWARD
			plane = -reach
			u = Vector3.RIGHT
			v = Vector3.UP
			var control := Vector3(0.0, meet.y + 0.02, 0.0) if dangling else meet * 0.5
			stem = _arc(tool, meet + Vector3.BACK * 0.01, control, Vector3.ZERO, stem_colour)
			# (aerial rootlets from the stem back to the face, where it is far enough off it)
			if reach > 0.15:
				for k in 3:
					var from: Vector3 = stem[1 + k][0]
					var to := Vector3(from.x + rng.randf_range(-0.06, 0.06), from.y - rng.randf_range(0.0, 0.08), reach)
					_tube(tool, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3.DOWN * 0.02, to]), 0.006, 0.003, hair_colour, 3)
		Held.LIP:
			# (up over the edge from the top, on which its roots lie, back from the edge)
			meet = Vector3(0.0, HELD_STEM, reach + 0.18)
			normal = Vector3.UP
			u = Vector3.RIGHT
			v = Vector3.BACK
			spread = Vector2(-1.9, 1.9)
			var control := Vector3(0.0, HELD_STEM + 0.07, 0.0) if dangling else Vector3(0.0, HELD_STEM, reach * 0.5 + 0.09)
			stem = _arc(tool, meet, control, Vector3.ZERO, stem_colour)
			# (rootlets gripping the edge's face, a short way down it)
			for k in 3:
				var x := rng.randf_range(-0.16, 0.16)
				var points := PackedVector3Array()
				var down := rng.randf_range(0.08, 0.18)
				for s in 4:
					points.append(Vector3(x + rng.randf_range(-0.02, 0.02) * s, -down * s / 3.0, reach - 0.006))
				points[0] = Vector3(x * 0.4, 0.004, reach + 0.03)
				_tube(tool, points, 0.007, 0.003, hair_colour, 3)
		Held.OVER:
			# (spread over the underside the top is against: short, a beam is narrow)
			normal = Vector3.DOWN
			u = Vector3.RIGHT
			v = Vector3.BACK
			longest = 0.3
		Held.GROUND:
			normal = Vector3.UP
			u = Vector3.RIGHT
			v = Vector3.BACK
			longest = 0.5
	# The roots: young green tendrils lying over what holds it, from where the stem
	# meets it, wandering; now and then a finer one off one.
	for k in tendrils:
		var angle := lerpf(spread.x, spread.y, (k + rng.randf_range(0.2, 0.8)) / tendrils)
		var heading := v.rotated(normal, angle)
		var long := rng.randf_range(0.45, 1.0) * longest
		var flat := Vector2(meet.dot(u), meet.dot(v))
		var way := Vector2(heading.dot(u), heading.dot(v)).normalized()
		var steps := 5
		var trail: Array[Vector2] = [flat]
		for s in steps:
			way = way.rotated(rng.randf_range(-0.5, 0.5))
			var next := flat + way * long / steps
			# (on a lip, kept back from the edge: never out over it)
			if held == Held.LIP and next.y < reach + 0.03:
				way.y = absf(way.y)
				next = flat + way * long / steps
			flat = next
			trail.append(flat)
		var from := 0.017
		var to := 0.005
		var points := PackedVector3Array()
		for s in trail.size():
			var r := lerpf(from, to, float(s) / (trail.size() - 1))
			var p := u * trail[s].x + v * trail[s].y + normal * (plane + r)
			points.append(p)
			if s > 0:
				var running := (points[s] - points[s - 1]).normalized()
				spots.append([p + normal * r, normal, running, float(s) / steps])
		_tube(tool, points, from, to, root_colour, 4)
		if rng.randf() < 0.5:
			var at := 2 + rng.randi() % 2
			var side := trail[at]
			var side_way := (trail[at] - trail[at - 1]).normalized().rotated(rng.randf_range(0.6, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0))
			var fine := PackedVector3Array()
			for s in 3:
				fine.append(u * side.x + v * side.y + normal * (plane + 0.005))
				side += side_way * long * 0.12
				side_way = side_way.rotated(rng.randf_range(-0.5, 0.5))
			_tube(tool, fine, 0.006, 0.003, hair_colour, 3)
	# (where the stem meets it counts as a spot too: the thick of the bunch)
	for k in 3:
		spots.append([meet + normal * 0.01, normal, v.rotated(normal, rng.randf() * TAU), 0.0])
	tool.generate_normals()
	return [tool.commit(), spots, stem]


## The stem from where it is held (`from`) out to the vine's top (`to`), bowed
## towards `control` (a quadratic curve): drawn, and the spots along it for leaves
## ([where, the way along it]).
static func _arc(tool: SurfaceTool, from: Vector3, control: Vector3, to: Vector3, colour: Color) -> Array:
	var points := PackedVector3Array()
	var steps := 6
	for s in steps + 1:
		var t := float(s) / steps
		points.append(from * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + to * t * t)
	_tube(tool, points, HELD_STEM * 0.8, HELD_STEM, colour, 6)
	var spots: Array = []
	for s in range(1, steps):
		spots.append([points[s], (points[s + 1] - points[s - 1]).normalized()])
	return spots


## A tube of `sides` sides along `points`, `from` thick at its start tapering to `to`, coloured.
static func _tube(tool: SurfaceTool, points: PackedVector3Array, from: float, to: float, colour: Color, sides := 5) -> void:
	var rings: Array = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var x := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var y := along.cross(x)
		var r := lerpf(from, to, float(i) / (points.size() - 1))
		var ring: Array[Vector3] = []
		for s in sides:
			var t := s * TAU / sides
			ring.append(points[i] + (x * cos(t) + y * sin(t)) * r)
		rings.append(ring)
	tool.set_color(colour)
	for i in points.size() - 1:
		for s in sides:
			var a: Vector3 = rings[i][s]
			var b: Vector3 = rings[i][(s + 1) % sides]
			var c: Vector3 = rings[i + 1][(s + 1) % sides]
			var d: Vector3 = rings[i + 1][s]
			for p: Vector3 in [a, b, c, a, c, d]:
				tool.add_vertex(p)


## Which way out from a stem running `along` a leaf stands, `angle` round it: the
## way it stands round the stem lying `rest` (`rest_out` at angle 0), turned the
## least way that takes `rest` to `along`. So a leaf goes round with the stem as it
## swings, smoothly. (Taken from the world's up, as they were, the leaves of a
## vine hanging nearly straight jumped round it whenever it swung past straight:
## the user, 2026-10-18, "the leaves seem to teleport when they move".)
static func round_stem(along: Vector3, rest: Vector3, rest_out: Vector3, angle: float) -> Vector3:
	var out := rest_out.rotated(rest, angle)
	if along.dot(rest) < -0.999:
		return out
	return Quaternion(rest, along) * out


## A leaf `size` long from the foot of its stalk to its tip, along +Y, its face to
## +Z (the user, 2026-10-18: "lets make a real leaf shape"): a short stalk, then a
## pointed oval blade, widest a third of the way along, folded a little along its
## midrib (its edges up towards its face) and its tip curling back. Ten triangles,
## paler down the midrib (the colours multiply each leaf's own).
static func leaf_mesh(size: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := size * 0.2
	var blade := size - stalk
	# (along the blade: how far, and how wide each side)
	var stations := [0.0, 0.3, 0.64, 1.0]
	var widths := [0.0, 0.31, 0.25, 0.0]
	var mid: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for k in stations.size():
		var t: float = stations[k]
		var w: float = widths[k] * blade
		var z := -0.12 * blade * t * t
		mid.append(Vector3(0.0, stalk + blade * t, z))
		left.append(Vector3(-w, stalk + blade * t, z + w * 0.3))
		right.append(Vector3(w, stalk + blade * t, z + w * 0.3))
	var pale := Color(1.0, 1.0, 0.85)
	var edge := Color(0.74, 0.78, 0.7)
	var add := func(p: Vector3, colour: Color) -> void:
		tool.set_color(colour)
		tool.add_vertex(p)
	# (the stalk: a thin strip into the blade's foot)
	var s := size * 0.022
	var foot := Color(0.95, 1.0, 0.7)
	for p: Array in [[Vector3(-s, 0, 0), foot], [Vector3(s, 0, 0), foot], [Vector3(s, stalk + blade * 0.05, 0), pale],
			[Vector3(-s, 0, 0), foot], [Vector3(s, stalk + blade * 0.05, 0), pale], [Vector3(-s, stalk + blade * 0.05, 0), pale]]:
		add.call(p[0], p[1])
	for k in stations.size() - 1:
		# (each side: from the midrib out to the edge and on to the next station)
		for side: Array in [left, right]:
			var a: Vector3 = mid[k]
			var b: Vector3 = mid[k + 1]
			var c: Vector3 = side[k + 1]
			var d: Vector3 = side[k]
			var flip: bool = side == right
			if k < stations.size() - 2:
				for p: Vector3 in ([a, b, c] if not flip else [a, c, b]):
					add.call(p, pale if p == a or p == b else edge)
			if k > 0:
				for p: Vector3 in ([a, c, d] if not flip else [a, d, c]):
					add.call(p, pale if p == a else edge)
	tool.generate_normals()
	return tool.commit()
