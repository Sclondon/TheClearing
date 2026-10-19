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

## The stem, a piece between each two points, all one thing to draw (a MultiMesh: a
## MeshInstance3D each, a maze thick with strung vines had a hundred thousand).
var _stems: MultiMeshInstance3D
var _leaves: MultiMeshInstance3D
var _placing: Array = []
## The roots where its ends are held (_anchor).
var _roots: Array[MeshInstance3D] = []
## The leaves on the stem (_placing), then the bunches where its ends are held
## (_anchor), in the same MultiMesh; how many leaves each bunch, and how many more
## on the stem by each end.
const ANCHOR_LEAVES := 40
const END_LEAVES := 10
## How each end is held (Vine.Held: over a lip, the corbel's, a bracket's or a ledge's, by
## default; on a wall's face; in the ground). An end on a face is tied TIED_OUT from it.
var from_held: int = Vine.Held.LIP
var to_held: int = Vine.Held.LIP
const TIED_OUT := 0.05
## How far a leaf on it droops from standing straight out of it, radians; and how
## far round from level either side its leaves stand out of it at most, so that
## they turn their faces up (not straight up or down from it, where which way
## is up would flip as it swayed).
const DROOP := 0.3
const LEVEL := 0.9


## How much longer than the gap it is strung across (at most), and how far it sags at
## most; one rooted in the ground sags no more than GROUND_SAG, so that it does not
## dip into the floor by its foot.
const SLACK := 1.05
const MOST_SAG := 2.2
const GROUND_SAG := 0.6


func _init() -> void:
	width = FOOTING * 2.0
	drawn = false
	slack = SLACK
	most_sag = MOST_SAG


func _ready() -> void:
	if from_held == Vine.Held.GROUND or to_held == Vine.Held.GROUND:
		most_sag = GROUND_SAG
	super()
	add_to_group(&"vine_strands")
	# (no planks, hand ropes or posts: only the vine, where the deck is: RopeBridge.drawn)
	if _stem == null:
		_stem = StandardMaterial3D.new()
		_stem.albedo_color = Color(0.2, 0.24, 0.12)
		_stem.roughness = 1.0
		_stem.metallic_specular = 0.0
		_leaf = Vine.leaf_material()
		_leaf_mesh = Vine.leaf_mesh(0.2)
		_stem_mesh = CylinderMesh.new()
		_stem_mesh.top_radius = 0.045
		_stem_mesh.bottom_radius = 0.045
		_stem_mesh.height = 1.0
		_stem_mesh.radial_segments = 6
		_stem_mesh.rings = 1
	var stems := MultiMesh.new()
	stems.transform_format = MultiMesh.TRANSFORM_3D
	stems.mesh = _stem_mesh
	stems.instance_count = POINTS - 1
	_stems = MultiMeshInstance3D.new()
	_stems.multimesh = stems
	_stems.material_override = _stem
	_stems.top_level = true
	_stems.visibility_range_end = Rope.SEEN
	add_child(_stems)
	_stems.global_transform = Transform3D.IDENTITY
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from.snappedf(0.01))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh
	var each := maxi(Vine.LEAVES, roundi(_piece / Vine.LEAF_REACH))
	var on_stem := (POINTS - 1) * each + END_LEAVES * 2
	multi.instance_count = on_stem + ANCHOR_LEAVES * 2
	var rest := (to - from).normalized() if from.distance_squared_to(to) > 0.000001 else Vector3.RIGHT
	var rest_out := _rest_out(rest)
	var end_share := minf(1.0, Vine.TOP_REACH / maxf(_piece, 0.01))
	for i in on_stem:
		var piece := i / each
		var t := rng.randf()
		if i >= (POINTS - 1) * each:
			# (bunched on the stem by its ends, thickest nearest them)
			var at_start := i < (POINTS - 1) * each + END_LEAVES
			piece = 0 if at_start else POINTS - 2
			t = pow(rng.randf(), 1.6) * end_share
			if not at_start:
				t = 1.0 - t
		# (out of it to one side or the other, near level, its face up as it lies at rest)
		var angle := rng.randf_range(-LEVEL, LEVEL) + (PI if rng.randf() < 0.5 else 0.0)
		var face := rest.cross(rest_out.rotated(rest, angle))
		_placing.append([piece, t, angle, rng.randf_range(0.7, 1.2), 1.0 if face.y >= 0.0 else -1.0])
		multi.set_instance_color(i, Vine.leaf_colour(rng))
	_leaves = MultiMeshInstance3D.new()
	_leaves.multimesh = multi
	_leaves.material_override = _leaf
	_leaves.top_level = true
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leaves.visibility_range_end = 160.0
	add_child(_leaves)
	_anchor(from, to, from_held, rng, on_stem)
	_anchor(to, from, to_held, rng, on_stem + ANCHOR_LEAVES)
	_lay()


## The way round it, at angle 0, that its leaves stand out of it lying `rest`: level, to one side.
static func _rest_out(rest: Vector3) -> Vector3:
	var out := rest.cross(Vector3.UP)
	return out.normalized() if out.length_squared() > 0.001 else Vector3.RIGHT


## How far out from what holds it an end held `held` way is.
static func _reach(held: int) -> float:
	return TIED_OUT if held == Vine.Held.FACE else 0.0


## Where it is held at `end` (the way `other`, its far end, is away from it), held
## as `held` says: its roots over what holds it, and a bunch of leaves over them
## (Vine.anchor), so that it grows out of what holds it rather than stopping in the
## air. They do not move. Its leaves are the stem leaves' MultiMesh's from `first` on.
func _anchor(end: Vector3, other: Vector3, held: int, rng: RandomNumberGenerator, first: int) -> void:
	var out := Vector3(other.x - end.x, 0.0, other.z - end.z).normalized()
	var made := Vine.anchor(end, -out, held, _reach(held), false, rng, ANCHOR_LEAVES)
	add_child(made[0])
	_roots.append(made[0])
	var multi := _leaves.multimesh
	for i in ANCHOR_LEAVES:
		multi.set_instance_transform(first + i, made[1][i][0])
		multi.set_instance_color(first + i, made[1][i][1])


## The vines hanging from it (the user, 2026-10-19: "hanging vines should be able to hang
## from crossing vines"), each [vine, where along it (its points' index and the share of
## the way to the next)]: each step it moves (only near someone, as it rests otherwise)
## their tops go where those points have gone. Cut, each goes with its half.
var _hung: Array = []
## How far under the stem's middle a vine hanging from it is held, metres.
const HUNG_UNDER := 0.05


## Hangs `vine` from it, at the point of it nearest the vine's top.
func hang(vine: Vine) -> void:
	_hung.append([vine, _place_of(vine.global_position + Vector3.UP * HUNG_UNDER)])
	vine.follow(_point_on(_hung[-1][1]) + Vector3.DOWN * HUNG_UNDER, true)


## Where along it the point nearest `point` is: its points' index, and how far to the next.
func _place_of(point: Vector3) -> float:
	var best := 0.0
	var least := INF
	for i in POINTS - 1:
		var a := _points[i]
		var ab := _points[i + 1] - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var apart := (a + ab * t).distance_squared_to(point)
		if apart < least:
			least = apart
			best = i + t
	return best


## The point of it `place` along (see _place_of), as it hangs now.
func _point_on(place: float) -> Vector3:
	var i := clampi(int(place), 0, POINTS - 2)
	return _points[i].lerp(_points[i + 1], place - i)


## How far along it from its start `place` is, as it hangs now, metres.
func _length_to(place: float) -> float:
	var length := 0.0
	var i := clampi(int(place), 0, POINTS - 2)
	for k in i:
		length += _points[k].distance_to(_points[k + 1])
	return length + _points[i].distance_to(_points[i + 1]) * (place - i)


## Drawn by the VineThicket while it rests (Rope.rest), with every vine near it at
## rest; its own stem, leaves and roots hidden meanwhile.
var _parked := false


func park() -> void:
	if _parked or _leaves == null or Engine.is_editor_hint():
		return
	_parked = true
	var draws := [VineThicket.draw_of(&"strand stem", _stems, Rope.SEEN),
			VineThicket.draw_of(&"strand leaves", _leaves, _leaves.visibility_range_end)]
	for roots in _roots:
		draws.append(VineThicket.draw_of_mesh([&"roots", roots.mesh.get_instance_id()], roots, roots.visibility_range_end))
	VineThicket.park(self, draws)
	_show_own(false)


func _unpark() -> void:
	_parked = false
	VineThicket.unpark(self)
	_show_own(true)


func _show_own(shown: bool) -> void:
	_stems.visible = shown
	_leaves.visible = shown
	for roots in _roots:
		roots.visible = shown


func _physics_process(delta: float) -> void:
	if _parked:
		_unpark()
	super(delta)
	if Engine.is_editor_hint():
		return
	for each: Array in _hung:
		if is_instance_valid(each[0]):
			(each[0] as Vine).follow(_point_on(each[1]) + Vector3.DOWN * HUNG_UNDER)
	# Whoever stands on it is drawn back over it, unless he is stepping off.
	for body: Node in get_tree().get_nodes_in_group(&"maze_players"):
		var walker := body as CharacterBody3D
		if walker == null or not walker.is_on_floor() or not _carries(walker.global_position):
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
		# (and he balances on it: arms out, one foot before the other)
		if absf(aside) < 0.6 and &"tightrope" in walker:
			walker.set(&"tightrope", 0.2)
			walker.set(&"tightrope_aside", aside * signf(across.dot(walker.global_basis.x)))
			walker.set(&"tightrope_on", self)


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
	var cut_place := _place_of(at)
	var whole := _length_to(POINTS - 1.0)
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
		vine.hold = Vector3(end.x - at.x, 0.0, end.z - at.z).normalized()
		vine.held = from_held if from_start else to_held
		vine.reach = _reach(vine.held)
		get_parent().add_child(vine)
		vine.lay_to(end + (at - end).normalized() * length)
		made.append(vine)
		# (the vines hanging from this half go with it, as far down it as they were along it)
		for each: Array in _hung:
			var place: float = each[1]
			if not is_instance_valid(each[0]) or (place < cut_place) != from_start:
				continue
			var down := _length_to(place) if from_start else whole - _length_to(place)
			if down < length - 0.1:
				vine.carry(each[0], down)
				each[0] = null
	# (any left, on a half too short to hang, fall with it)
	for each: Array in _hung:
		if is_instance_valid(each[0]):
			(each[0] as Vine).queue_free()
	_hung.clear()
	# (where the vines are is looked up afresh once they have swung down: NearIndex)
	NearIndex.moved(get_tree(), &"ropes")
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
		_stems.multimesh.set_instance_transform(i, Transform3D(Basis(x, y * along.length(), x.cross(y)), (a + b) * 0.5))
	var multi := _leaves.multimesh
	# (round the stem as it lies strung straight from end to end: see Vine.round_stem)
	var rest := (to - from).normalized() if from.distance_squared_to(to) > 0.000001 else Vector3.RIGHT
	var rest_out := _rest_out(rest)
	for i in _placing.size():
		var place: Array = _placing[i]
		var a := _points[place[0]]
		var b := _points[place[0] + 1]
		var along := (b - a).normalized() if a.distance_squared_to(b) > 0.000001 else rest
		var out := Vine.round_stem(along, rest, rest_out, place[2])
		# (its stalk's foot on the stem; its face up, the way it was at rest, and drooping a little)
		var leaf_at := a.lerp(b, place[1]) + out * 0.045 * 0.8
		var face := along.cross(out) * float(place[4])
		var y := out * cos(DROOP) - face * sin(DROOP)
		var z := face * cos(DROOP) + out * sin(DROOP)
		multi.set_instance_transform(i, Transform3D(Basis(y.cross(z), y, z).scaled(Vector3.ONE * place[3]), leaf_at))


# --- For hanging under it (Player._hold_strand) ---

## Which way it runs across the ground, from `from` to `to` (level, unit length).
func line() -> Vector3:
	var along := to - from
	along.y = 0.0
	return along.normalized()


## How far it runs across the ground, metres.
func span() -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


## How far along it, across the ground from `from`, a point is.
func distance_along(point: Vector3) -> float:
	return clampf((point - from).dot(line()), 0.0, span())


## The point of it (as it hangs now) `distance` metres along it across the ground.
func point_at_distance(distance: float) -> Vector3:
	var span_now := maxf(span(), 0.001)
	var t := clampf(distance / span_now, 0.0, 1.0) * (POINTS - 1)
	var i := mini(int(t), POINTS - 2)
	var level := from + line() * distance
	var y := lerpf(_points[i].y, _points[i + 1].y, t - i)
	return Vector3(level.x, y, level.z)


## The point of it nearest `point`.
func point_near(point: Vector3) -> Vector3:
	return _closest(point)


# Whether someone whose feet are at `feet` is stood on it: over its line (from any
# point along it, not only its joints), and on it, not under it or well over it.
func _carries(feet: Vector3) -> bool:
	var on := _closest(feet)
	var level := Vector2(feet.x - on.x, feet.z - on.z).length()
	return level < 0.6 and feet.y > on.y - 0.3 and feet.y < on.y + 0.8
