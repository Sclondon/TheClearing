@tool
class_name VineStrand
extends RopeBridge
## A vine strung across a hall from one wall to the other, sagging in the middle,
## drawn as the vines that hang are (Vine: a green stem with leaves along it). It
## is a RopeBridge one footstep wide: walked as a tightrope, it dips and sways
## under him, and keeps him on it if he goes carefully (he is drawn back over it
## while he stands on it and is not stepping off). `cut` it and it falls into two
## vines hanging from where its ends were held, to swing on (or to hang from: he
## is on it when he cuts it, and catches his half as it goes).
##
## From `from` to `to`, in the world.

## How far either side of the stem his feet stay on it, metres, and how quickly
## he is drawn back over it.
const FOOTING := 0.17
const BALANCE := 7.0
## A cut vine hangs no lower than this over the ground.
const CLEAR := 1.6

static var _stem: StandardMaterial3D
static var _leaf: StandardMaterial3D
static var _leaf_mesh: ArrayMesh
static var _stem_mesh: CylinderMesh

var _stems: Array[MeshInstance3D] = []
var _leaves: MultiMeshInstance3D
var _placing: Array = []
## The tufts of leaves where its ends are tied to the walls (_anchor), and how many leaves each.
var _tufts: Array[MultiMeshInstance3D] = []
const ANCHOR_LEAVES := 28


func _init() -> void:
	width = FOOTING * 2.0
	slack = 1.05
	most_sag = 2.2


func _ready() -> void:
	super()
	add_to_group(&"vine_strands")
	# (no planks, hand ropes or posts to be seen: only the vine, where the deck is)
	_deck.visible = false
	_rails.visible = false
	_posts.visible = false
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.2, 0.24, 0.12)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = StandardMaterial3D.new()
		_leaf.vertex_color_use_as_albedo = true
		_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf.roughness = 1.0
		_leaf.metallic_specular = 0.0
		_leaf_mesh = Vine.leaf_mesh(0.16)
		_stem_mesh = CylinderMesh.new()
		_stem_mesh.top_radius = 0.045
		_stem_mesh.bottom_radius = 0.045
		_stem_mesh.height = 1.0
		_stem_mesh.radial_segments = 6
		_stem_mesh.rings = 1
	for i in POINTS - 1:
		var stem := MeshInstance3D.new()
		stem.mesh = _stem_mesh
		stem.material_override = _stem
		stem.top_level = true
		stem.visibility_range_end = Rope.SEEN
		add_child(stem)
		_stems.append(stem)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snappedf(0.01))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	var each := maxi(Vine.LEAVES, roundi(_piece / Vine.LEAF_REACH))
	multi.instance_count = (POINTS - 1) * each
	for i in multi.instance_count:
		_placing.append([i / each, rng.randf(), rng.randf() * TAU, rng.randf_range(0.7, 1.3)])
		multi.set_instance_color(i, Color(0.16, 0.27, 0.12).lightened(rng.randf_range(-0.1, 0.25)))
	_leaves = MultiMeshInstance3D.new()
	_leaves.multimesh = multi
	_leaves.material_override = _leaf
	_leaves.top_level = true
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leaves.visibility_range_end = 160.0
	add_child(_leaves)
	_anchor(from, to, rng)
	_anchor(to, from, rng)
	_lay()


## Where it is tied to the wall at `end`: a tuft of leaves spread over the face
## behind it (the face looks towards `other`, the far end), so that it grows out
## of the wall rather than stopping in the air. It does not move.
func _anchor(end: Vector3, other: Vector3, rng: RandomNumberGenerator) -> void:
	var out := Vector3(other.x - end.x, 0.0, other.z - end.z).normalized()
	var across := out.cross(Vector3.UP)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	multi.instance_count = ANCHOR_LEAVES
	for i in ANCHOR_LEAVES:
		# (thickest round the end, thinning out over the face, more of it below)
		var spot := Vector2.from_angle(rng.randf() * TAU) * pow(rng.randf(), 0.7) * 0.75
		spot.y = spot.y * 1.3 - 0.15
		var at := end + across * spot.x + Vector3.UP * spot.y + out * rng.randf_range(0.0, 0.08)
		var basis := Basis.looking_at(-out, Vector3.UP).rotated(out, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		multi.set_instance_transform(i, Transform3D(basis, at))
		multi.set_instance_color(i, Color(0.16, 0.27, 0.12).lightened(rng.randf_range(-0.12, 0.2)))
	var tuft := MultiMeshInstance3D.new()
	tuft.multimesh = multi
	tuft.material_override = _leaf
	tuft.top_level = true
	tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tuft.visibility_range_end = 160.0
	add_child(tuft)
	_tufts.append(tuft)


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	# Whoever stands on it is drawn back over it, unless he is stepping off.
	for body: Node in get_tree().get_nodes_in_group(&"maze_players"):
		var walker := body as CharacterBody3D
		if walker == null or not walker.is_on_floor() or _nearest(walker.global_position) < 0:
			continue
		var off := walker.global_position - _closest(walker.global_position)
		off.y = 0.0
		var along := to - from
		along.y = 0.0
		var across := along.normalized().cross(Vector3.UP)
		var aside := off.dot(across)
		var stepping := Vector3(walker.velocity.x, 0.0, walker.velocity.z).dot(across * signf(aside))
		if absf(aside) < 0.6 and stepping < 2.5:
			walker.global_position -= across * aside * minf(1.0, BALANCE * delta)


## How far a point is from the vine.
func distance_to(point: Vector3) -> float:
	return _closest(point).distance_to(point)


## The point on the vine nearest `point`.
func _closest(point: Vector3) -> Vector3:
	var best := _points[0]
	for i in POINTS - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var ab := b - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var p := a + ab * t
		if p.distance_squared_to(point) < best.distance_squared_to(point):
			best = p
	return best


## Cuts it at the point nearest `point`: it is gone, and from each end hangs a
## vine as long as the part of it on that side (no lower than CLEAR over the
## ground under it), laid out along where it was, to swing down. Returns them.
func cut(point: Vector3) -> Array[Vine]:
	var at := _closest(point)
	var made: Array[Vine] = []
	for from_start: bool in [true, false]:
		var end := from if from_start else to
		var length := 0.0
		var last := end
		for k in POINTS:
			var p := _points[k if from_start else POINTS - 1 - k]
			if p.distance_to(end) > at.distance_to(end):
				break
			length += p.distance_to(last)
			last = p
		length = minf(length + at.distance_to(last), end.y - CLEAR)
		if length < 1.5:
			continue
		var vine := Vine.new()
		vine.length = length
		vine.position = end
		get_parent().add_child(vine)
		vine.lay_to(end + (at - end).normalized() * length)
		made.append(vine)
	queue_free()
	return made


func _lay() -> void:
	super()
	if _leaves == null:
		return
	for i in POINTS - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var along := b - a
		var y := along.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		_stems[i].global_transform = Transform3D(Basis(x, y * along.length(), x.cross(y)), (a + b) * 0.5)
	var multi := _leaves.multimesh
	for i in _placing.size():
		var place: Array = _placing[i]
		var a := _points[place[0]]
		var b := _points[place[0] + 1]
		var along := (b - a).normalized() if a.distance_squared_to(b) > 0.000001 else Vector3.RIGHT
		var out := along.cross(Vector3.UP)
		out = out.normalized() if out.length_squared() > 0.001 else Vector3.RIGHT
		out = out.rotated(along, place[2])
		var leaf_at := a.lerp(b, place[1]) + out * 0.045
		var basis := Basis(out.cross(along).normalized(), out, along).rotated(out.cross(along).normalized(), 0.6)
		multi.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * place[3]), leaf_at))
