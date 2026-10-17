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

enum State {
	HOME, ## On its coil: lying about, or in his hand.
	FLYING, ## Thrown, and on its way.
	BITTEN, ## Caught fast, its rope hanging from it.
	SPENT, ## Thrown at nothing: dropping at the end of its line.
	RETURNING, ## Being wound back in.
}

## How many pieces the line is drawn in while the hook is in the air.
const LINKS := 10

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
	_mark.visible = false


## Whether it is on its coil and can be thrown.
func is_home() -> bool:
	return state == State.HOME


## What `who` would catch with it from where he stands: the nearest thing a
## hook holds on that is within reach, high enough above him, in front of him
## (the way he faces, and the way the camera looks, both count), and in plain sight.
func find_target(who: Player) -> Node3D:
	var hands := who.global_position + Vector3.UP * who.hang_height
	var facing := Vector3(sin(who.facing_yaw), 0.0, cos(who.facing_yaw))
	var aim := facing
	var camera := get_viewport().get_camera_3d()
	if camera:
		var look := -camera.global_basis.z
		look.y = 0.0
		if look.length() > 0.2 and facing.dot(look.normalized()) > -0.5:
			aim = (facing + look.normalized()).normalized()
	var space := get_world_3d().direct_space_state
	var best: Node3D
	var least := INF
	for node in get_tree().get_nodes_in_group(&"grapple_points"):
		var point := node as Node3D
		if point == null or not point.is_visible_in_tree():
			continue
		var to := point.global_position - hands
		var distance := to.length()
		if distance > reach or to.y < rise:
			continue
		var level := Vector3(to.x, 0.0, to.z)
		if rad_to_deg(atan2(level.length(), to.y)) > steep:
			continue
		# (what is all but overhead is in front of him whichever way he faces)
		var aside := rad_to_deg(level.normalized().angle_to(aim)) if level.length() > 0.8 else 0.0
		if aside > cone:
			continue
		var score := distance * (1.0 + aside / 45.0)
		if score >= least:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hands, point.global_position, 1))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(point.global_position) > 0.5:
			continue
		least = score
		best = point
	return best


## Throws it: at `at` if there is anything to throw it at, and otherwise out
## ahead of `who`, where it will find nothing and drop.
func cast(who: Player, at: Node3D) -> void:
	if state != State.HOME:
		return
	holder = who
	_at = at
	_from = global_position
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
	_mark.visible = false
	_fly(0.0)


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
	for link in _links:
		link.visible = false
	if not who.take_rope(rope, down, self):
		# (he is in no state to take it: it comes away again)
		_release_rope()
		_wind_in()


## Held and ready: looks for what it would catch, and marks it.
func _watch() -> void:
	if not is_instance_valid(holder) or holder.carried != self:
		_mark.visible = false
		return
	_look += 1
	if _look % 3 == 0:
		var ready := holder.state == Player.State.FREE and not holder.is_limp
		target = find_target(holder) if ready else null
	_mark.visible = is_instance_valid(target)
	if _mark.visible:
		_mark.global_position = target.global_position


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
