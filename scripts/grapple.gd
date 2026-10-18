class_name GrappleHook
extends RigidBody3D
## A grappling hook on a coil of rope, to carry. It is a loose thing like a rock
## (in the groups `throwable` and `interest`), and also in `grapples`, which is
## how whoever picks it up knows what to do with it: act throws it, not away,
## but at the nearest thing in front of him that a hook will catch (a
## `GrapplePoint`, or anything else in the group `grapple_points`) that is
## within its reach, above him, and not hidden from him. That one is shown with
## a small mark over it for as long as he holds the hook, so it can be seen
## before he throws that it will catch.
##
## The hook flies there on its line and bites; a `Rope` is hung from the place
## and he is on it (`Player.take_rope`), swinging as on any rope. When he lets
## go of the rope, however he does, the hook comes away and is wound back in to
## his hand. Thrown with nothing in reach it falls short and is wound back in.
## `GrappleHook.new()` is a whole one.
##
## It also catches the spots a level is given for it (GrappleSpots: rings,
## hooks and pipes, many to a node), and vines: thrown at a hanging Vine it
## wraps round it, and he is hauled in on its line to where it wrapped and takes
## hold of the vine itself, swinging on with what the haul gave him (`hauling`,
## which the Player reads); thrown at a vine strung across a hall (VineStrand)
## it wraps round that, and its rope hangs from there to be climbed. What is in
## reach is found through NearIndex, never by asking every one of them. Besides
## the mark on what it would catch, the next few things it could catch in reach
## are marked faintly, so that a way up can be seen and planned.

enum State {
	HOME, ## On its coil: lying about, or in his hand.
	FLYING, ## Thrown, and on its way.
	BITTEN, ## Caught fast, its rope hanging from it.
	SPENT, ## Thrown at nothing: dropping at the end of its line.
	RETURNING, ## Being wound back in.
}

## What it is thrown at: a node of its own (a GrapplePoint, a ledge's lip
## found by feeling for it), one of a GrappleSpots' spots, a hanging vine, a
## strung vine.
enum Catch { POINT, SPOT, VINE, STRAND }

## How many pieces the line is drawn in while the hook is in the air.
const LINKS := 10
## How many more of what it could catch in reach are marked, faintly.
const OTHERS := 4
## How much nearer than they are the spots made for it, and vines, count when
## choosing what to throw at (so that one is chosen over the lip of a ledge
## about as far off).
const SPOT_PULL := 0.8
const VINE_PULL := 0.9
## How far over his hands it wraps a hanging vine, if the vine reaches so low.
const VINE_OVER := 3.0

## The furthest it will catch anything: how much rope there is, in metres.
@export var reach := 9.5
## How far above his hands a thing has to be for it to be worth throwing at.
@export var rise := 1.5
## How far from straight overhead the line to it may be, in degrees. (At the
## flattest it takes him off his feet hardest.)
@export var steep := 58.0
## How far to either side of where he is facing (and the camera is looking) it
## may be, in degrees.
@export var cone := 75.0
## How fast it flies, and how fast it is wound back in, m/s.
@export var speed := 26.0
@export var wind_speed := 30.0
## How far a throw at nothing goes before it drops.
@export var short := 5.5

var state := State.HOME
## Who has it, if anyone.
var holder: Player
## What it would catch if it were thrown now (nothing, if nothing is in reach).
var target: Node3D
## The rope it has hung, while it is bitten.
var rope: Rope
## How good what `find_target` last found is (less is better: about how far off it is).
var best_score := INF
## Thrown at a hanging vine and wrapped round it: he is being hauled in to it
## (the Player hauls him up its line, and takes hold of `wrapped` at `wrap_at`
## down it when he gets there).
var hauling := false
## The vine it is wrapped round (or flying at), and where.
var wrapped: Node3D
var wrap_at := 0.0

## Where what it would catch is, when that is not a node of its own (a spot, a vine).
var _spot: Marker3D
var _marks: Array[Sprite3D] = []
## What `find_target` found: what kind, on what, where (down a vine; across a strand, in the world).
var _found := Catch.POINT
var _found_on: Node3D
var _found_at := 0.0
var _found_point := Vector3.ZERO
## And the rest it could catch, to mark faintly.
var _others := PackedVector3Array()
## What it was thrown at.
var _catch := Catch.POINT
var _wrap_point := Vector3.ZERO

var _coil: Node3D
var _head: Node3D
var _links: Array[MeshInstance3D] = []
var _mark: Sprite3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _at: Node3D
var _flight := 0.0
var _takes := 1.0
var _drop := 0.0
var _look := 0


func _ready() -> void:
	add_to_group(&"throwable")
	add_to_group(&"interest")
	add_to_group(&"grapples")
	mass = 1.2
	gravity_scale = 2.0
	angular_damp = 6.0
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = -0.12
	add_child(collider)
	var hemp := Toon.surface(Color(0.45, 0.38, 0.26))
	var iron := Toon.surface(Color(0.17, 0.16, 0.17))
	# The coil: a few turns of rope, hanging from where it is held (which is where this node is).
	_coil = Node3D.new()
	add_child(_coil)
	for i in 4:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.085 + 0.004 * (i % 2)
		turn.outer_radius = turn.inner_radius + 0.03
		turn.rings = 14
		turn.ring_segments = 5
		var loop := MeshInstance3D.new()
		loop.mesh = turn
		# (stood on edge, each lying a little askew of the last)
		loop.rotation = Vector3(PI * 0.5, 0.0, 0.0) + Vector3(0.0, (i - 1.5) * 0.16, (i % 2 - 0.5) * 0.12)
		loop.position = Vector3((i - 1.5) * 0.022, -0.12, 0.0)
		loop.material_override = hemp
		_coil.add_child(loop)
	# The hook: a shank with an eye, and three flukes curving back up from its foot.
	_head = Node3D.new()
	add_child(_head)
	_piece(_head, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 0.011, 0.2, iron)
	var eye := TorusMesh.new()
	eye.inner_radius = 0.012
	eye.outer_radius = 0.026
	eye.rings = 8
	eye.ring_segments = 5
	var loop_eye := MeshInstance3D.new()
	loop_eye.mesh = eye
	loop_eye.rotation.x = PI * 0.5
	loop_eye.position.y = 0.115
	loop_eye.material_override = iron
	_head.add_child(loop_eye)
	for i in 3:
		var fluke := Node3D.new()
		fluke.rotation.y = TAU * i / 3.0
		_head.add_child(fluke)
		_piece(fluke, Vector3(0.0, -0.105, 0.03), Vector3(1.05, 0.0, 0.0), 0.01, 0.075, iron)
		_piece(fluke, Vector3(0.0, -0.09, 0.075), Vector3(-0.35, 0.0, 0.0), 0.009, 0.07, iron)
		_piece(fluke, Vector3(0.0, -0.045, 0.085), Vector3(0.25, 0.0, 0.0), 0.006, 0.045, iron)
	for i in LINKS:
		var link := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.018
		mesh.height = 1.0
		mesh.radial_segments = 5
		mesh.rings = 1
		link.mesh = mesh
		link.material_override = hemp
		link.top_level = true
		link.visible = false
		add_child(link)
		_links.append(link)
	# The mark over what it will catch: a ring, the same size however far off, seen through anything.
	_mark = Sprite3D.new()
	_mark.texture = _mark_image()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.fixed_size = true
	_mark.no_depth_test = true
	_mark.shaded = false
	_mark.pixel_size = 0.0011
	_mark.modulate = Color(1.0, 0.86, 0.35, 0.95)
	_mark.render_priority = 4
	_mark.top_level = true
	_mark.visible = false
	add_child(_mark)
	# (and the faint ones, smaller, over the rest it could catch)
	for i in OTHERS:
		var faint := _mark.duplicate() as Sprite3D
		faint.pixel_size = 0.0007
		faint.modulate = Color(1.0, 0.9, 0.6, 0.5)
		faint.render_priority = 3
		add_child(faint)
		_marks.append(faint)
	_spot = Marker3D.new()
	_spot.top_level = true
	add_child(_spot)
	_rest()


func _piece(on: Node3D, at: Vector3, turn: Vector3, radius: float, length: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.rotation = turn
	part.material_override = material
	on.add_child(part)


## A ring with a dot in the middle of it.
static func _mark_image() -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var away := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length()
			var ink := clampf(1.5 - absf(away - 24.0) * 0.6, 0.0, 1.0)
			ink = maxf(ink, clampf(1.5 - (away - 4.0) * 0.6, 0.0, 1.0))
			# (a dark edge to it, so that it shows against sand and sky alike)
			var edge := clampf(1.5 - absf(away - 24.0) * 0.3, 0.0, 1.0) * 0.55
			image.set_pixel(x, y, Color(ink, ink, ink, maxf(ink, edge)))
	return ImageTexture.create_from_image(image)


## Told by whoever picks it up, and (with nobody) when it is put down or dropped.
func taken_by(who: Node) -> void:
	if who == null and state != State.HOME:
		# (wherever the hook had got to, it is back on its coil)
		_release_rope()
		_home()
	holder = who as Player
	target = null
	_others.clear()
	_show_marks(false)


## Whether it is on its coil and can be thrown.
func is_home() -> bool:
	return state == State.HOME


## What `who` would catch with it from where he stands: the nearest thing a
## hook holds on that is within reach, high enough above him, in front of him
## (the way he faces, and the way the camera looks, both count), and in plain sight.
##
## Looked for among what is near him only (NearIndex): the nodes in the group
## `grapple_points`, the spots of the GrappleSpots near, hanging vines (where
## it would wrap one: VINE_OVER over his hands, or as low as it reaches) and
## strung ones. The best of them is returned (a GrapplePoint itself, or a
## marker of the hook's own where the spot or the vine is); `best_score` says
## how good it is, and the next few in plain sight are kept to be marked.
func find_target(who: Player) -> Node3D:
	best_score = INF
	_others.clear()
	if not who.is_inside_tree() or not is_inside_tree():
		return null
	var hands := who.global_position + Vector3.UP * who.hang_height
	var aim := _aim(who)
	var tree := get_tree()
	# [score, where, Catch, on what, how far along it]
	var found: Array = []
	for node: Node in NearIndex.near(tree, &"grapple_points", hands, reach):
		var point := node as Node3D
		if point and point.is_visible_in_tree():
			_consider(found, hands, aim, point.global_position, 1.0, Catch.POINT, point, 0.0)
	for node: Node in NearIndex.near(tree, GrappleSpots.GROUP, hands, reach):
		var spots := node as GrappleSpots
		if spots == null:
			continue
		for i in spots.points.size():
			_consider(found, hands, aim, spots.points[i], SPOT_PULL, Catch.SPOT, spots, i)
	for node: Node in NearIndex.near(tree, &"ropes", hands, reach):
		var vine := node as Vine
		# (not one somebody is on)
		if vine == null or vine.load_at >= 0.0 or not vine.is_visible_in_tree():
			continue
		var top := vine.global_position
		if Vector2(top.x - hands.x, top.z - hands.z).length() > reach + 1.0:
			continue
		var want := minf(hands.y + VINE_OVER, top.y - 0.8)
		want = maxf(want, vine.bottom_y() + 0.5)
		if want < hands.y + rise or want > top.y - 0.4:
			continue
		var along := vine.nearest(Vector3(top.x, want, top.z))
		_consider(found, hands, aim, vine.point_at(along), VINE_PULL, Catch.VINE, vine, along)
	for node: Node in NearIndex.near(tree, &"vine_strands", hands, reach):
		var strand := node as VineStrand
		if strand == null:
			continue
		# (where it would come down on it, thrown up over his head the way he is going)
		var over := strand._closest(hands + aim * 1.5 + Vector3.UP * 3.0)
		_consider(found, hands, aim, over, VINE_PULL, Catch.STRAND, strand, 0.0)
	if found.is_empty():
		return null
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var space := get_world_3d().direct_space_state
	var best: Array = []
	var looked := 0
	for each: Array in found:
		if _others.size() >= OTHERS or looked >= OTHERS + 4:
			break
		looked += 1
		var at: Vector3 = each[1]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hands, at, 1, [who.get_rid()]))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(at) > 0.5:
			continue
		if best.is_empty():
			best = each
		else:
			_others.append(at)
	if best.is_empty():
		return null
	best_score = best[0]
	_found = best[2]
	_found_on = best[3]
	_found_at = best[4]
	_found_point = best[1]
	if _found == Catch.POINT:
		return _found_on
	_spot.global_position = _found_point
	return _spot


## The way he would throw: the way he faces, and the way the camera looks too.
func _aim(who: Player) -> Vector3:
	var facing := Vector3(sin(who.facing_yaw), 0.0, cos(who.facing_yaw))
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var look := -camera.global_basis.z
		look.y = 0.0
		if look.length() > 0.2 and facing.dot(look.normalized()) > -0.5:
			return (facing + look.normalized()).normalized()
	return facing


## Adds `at` to `found` if the hook could be thrown at it from `hands`: in
## reach, high enough, not too flat a throw, and in front of him (what is all
## but overhead is in front of him whichever way he faces).
func _consider(found: Array, hands: Vector3, aim: Vector3, at: Vector3, pull: float, catch: Catch, on: Node3D, along: float) -> void:
	var to := at - hands
	var distance := to.length()
	if distance > reach or to.y < rise:
		return
	var level := Vector3(to.x, 0.0, to.z)
	var slope := rad_to_deg(atan2(level.length(), to.y))
	if slope > steep:
		return
	var aside := rad_to_deg(level.normalized().angle_to(aim)) if level.length() > 0.8 and slope > 30.0 else 0.0
	if aside > cone:
		return
	found.append([distance * (1.0 + aside / 45.0) * pull, at, catch, on, along])


## Throws it: at `at` if there is anything to throw it at, and otherwise out
## ahead of `who`, where it will find nothing and drop.
func cast(who: Player, at: Node3D) -> void:
	if state != State.HOME:
		return
	holder = who
	_at = at
	_from = global_position
	# (what it was thrown at, as it was found)
	_catch = _found if at == _spot else Catch.POINT
	wrapped = _found_on if _catch in [Catch.VINE, Catch.STRAND] else null
	wrap_at = _found_at
	_wrap_point = _found_point
	hauling = false
	if at:
		_to = at.global_position
	else:
		var facing := Vector3(sin(who.facing_yaw), 0.0, cos(who.facing_yaw))
		_to = _from + facing * short + Vector3.UP * short * 0.55
	_flight = 0.0
	_takes = maxf(_from.distance_to(_to) / speed, 0.12)
	state = State.FLYING
	who.hook_out = true
	_head.top_level = true
	_show_marks(false)
	_fly(0.0)


## Where on what it was thrown at it is to bite, now (a vine swings, and a strung
## one sways): the marker is put there. False if that is gone.
func _follow() -> bool:
	if _catch == Catch.VINE or _catch == Catch.STRAND:
		if not is_instance_valid(wrapped) or not wrapped.is_inside_tree():
			return false
		if _catch == Catch.VINE:
			_spot.global_position = (wrapped as Vine).point_at(wrap_at)
		else:
			_wrap_point = (wrapped as VineStrand)._closest(_wrap_point)
			_spot.global_position = _wrap_point
	return true


## The hook lets go of what it had bitten on and is wound in. (The Player calls
## this when he leaves its rope.)
func come_away() -> void:
	if state != State.BITTEN:
		return
	_release_rope()
	_wind_in()


func _release_rope() -> void:
	if is_instance_valid(rope):
		rope.queue_free()
	rope = null
	hauling = false
	wrapped = null


func _wind_in() -> void:
	state = State.RETURNING
	_from = _head.global_position
	if is_instance_valid(holder):
		holder.reel_progress = 0.0


func _home() -> void:
	state = State.HOME
	if is_instance_valid(holder):
		holder.hook_out = false
	_rest()


## The hook hanging under the coil, and no line out.
func _rest() -> void:
	_head.top_level = false
	_head.transform = Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, -0.3, 0.02))
	_head.visible = true
	_coil.visible = true
	for link in _links:
		link.visible = false


func _physics_process(delta: float) -> void:
	match state:
		State.HOME:
			_watch()
		State.FLYING:
			if not is_instance_valid(holder) or holder.carried != self:
				_home()
				return
			if _at and not is_instance_valid(_at):
				_at = null
			if _at and not _follow():
				# (the vine it was thrown at is gone: cut)
				_at = null
				wrapped = null
			if _at:
				_to = _at.global_position
			_flight += delta / _takes
			if _flight < 1.0:
				return
			if _at:
				_bite()
			else:
				state = State.SPENT
				_drop = 0.0
		State.SPENT:
			_drop += delta
			_to += Vector3.DOWN * 9.0 * _drop * delta
			if _drop > 0.22:
				_wind_in()
		State.BITTEN:
			if not is_instance_valid(rope) or not is_instance_valid(holder) or holder.carried != self:
				_release_rope()
				_home()
			elif _catch == Catch.VINE or _catch == Catch.STRAND:
				# Wrapped round a vine: its rope hangs from where it is wrapped, and
				# goes where the vine goes; cut from under it, it falls away.
				if not _follow():
					_release_rope()
					_wind_in()
					return
				rope.global_position = _spot.global_position
				_head.global_position = _spot.global_position
		State.RETURNING:
			if not is_instance_valid(holder) or holder.carried != self:
				_home()
				return
			_from = _from.move_toward(global_position, wind_speed * delta)
			if _from.distance_to(global_position) < 0.25:
				_home()


## It has reached what it was thrown at: its rope hangs from there to his
## hands, with a little over, and he is on it.
func _bite() -> void:
	var who := holder
	var top := _to
	var facing := Vector3(sin(who.facing_yaw), 0.0, cos(who.facing_yaw))
	var hold := who.global_position + Vector3.UP * who.hang_height + facing * 0.16
	var down := top.distance_to(hold)
	rope = Rope.new()
	rope.length = down + 0.5
	rope.thickness = 0.02
	who.get_parent().add_child(rope)
	rope.global_position = top
	rope.lay_to(top + (hold - top).normalized() * rope.length)
	state = State.BITTEN
	_head.global_transform = Transform3D(Basis(Vector3.RIGHT, PI), top + Vector3.UP * 0.06)
	if _catch == Catch.VINE or _catch == Catch.STRAND:
		# (wrapped round it, its flukes about the stem: lying across the line)
		var across := (hold - top).normalized().cross(Vector3.UP)
		across = across.normalized() if across.length_squared() > 0.01 else Vector3.RIGHT
		_head.global_transform = Transform3D(Basis(across, PI * 0.5), top)
	if _catch == Catch.VINE:
		# It wraps the vine, which gives as it takes the jerk of the line, and he
		# is hauled in to it.
		hauling = true
		(wrapped as Vine).push(wrap_at, (hold - top).normalized() * 1.5)
	for link in _links:
		link.visible = false
	if not who.take_rope(rope, down, self):
		# (he is in no state to take it: it comes away again)
		_release_rope()
		_wind_in()


## Held and ready: looks for what it would catch, and marks it.
func _watch() -> void:
	if not is_instance_valid(holder) or holder.carried != self:
		_show_marks(false)
		return
	_look += 1
	# (not while he winds up to throw: what he throws at is what was marked)
	if _look % 3 == 0 and holder.cast_progress >= 1.0:
		var ready := holder.state == Player.State.FREE and not holder.is_limp
		target = find_target(holder) if ready else null
		if target == null:
			_others.clear()
	if is_instance_valid(target) and target == _spot and _found == Catch.VINE and is_instance_valid(_found_on):
		# (a vine swings: the mark goes with it)
		_spot.global_position = (_found_on as Vine).point_at(_found_at)
	_mark.visible = is_instance_valid(target)
	if _mark.visible:
		_mark.global_position = target.global_position
	for i in OTHERS:
		_marks[i].visible = i < _others.size()
		if _marks[i].visible:
			_marks[i].global_position = _others[i]


func _show_marks(shown: bool) -> void:
	if _mark:
		_mark.visible = shown
	for faint in _marks:
		faint.visible = shown


func _process(_delta: float) -> void:
	match state:
		State.FLYING:
			_fly(minf(_flight, 1.0))
		State.SPENT:
			_fly(1.0)
		State.RETURNING:
			_head.global_position = _from
			_line(global_position, _from, 0.0)


## Where the hook is `through` its flight (0..1): from his hand to where it is
## going, over a low arc, its line paid out behind it.
func _fly(through: float) -> void:
	var hand := global_position
	var eased := 1.0 - (1.0 - through) * (1.0 - through) * 0.35 - (1.0 - through) * 0.65
	var at := hand.lerp(_to, eased) + Vector3.UP * sin(PI * eased) * hand.distance_to(_to) * 0.06
	var going := (_to - hand).normalized()
	# (it flies eye first, its flukes trailing)
	_head.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, going if absf(going.y) < 0.999 else Vector3.UP)), at)
	_line(hand, at, 0.05 + 0.1 * (1.0 - through))


## Draws the line from `a` to `b`, sagging by that fraction of its length.
func _line(a: Vector3, b: Vector3, sag: float) -> void:
	var span := a.distance_to(b)
	var before := a
	for i in LINKS:
		var part := float(i + 1) / LINKS
		var next := a.lerp(b, part) + Vector3.DOWN * sin(PI * part) * span * sag
		var along := next - before
		var link := _links[i]
		link.visible = along.length() > 0.01
		if link.visible:
			var up := along.normalized()
			var across := up.cross(Vector3.RIGHT)
			across = across.normalized() if across.length_squared() > 0.001 else Vector3.BACK
			link.global_transform = Transform3D(Basis(across.cross(up), up * along.length(), across), (before + next) * 0.5)
		before = next
