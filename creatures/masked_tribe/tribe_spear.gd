class_name TribeSpear
extends Node3D
## A tribesman's spear: a sharpened stick, crooked and knotted, bound with cord
## below a knapped stone point or a splinter of bone, a rag tied by its butt.
## Held, it is wherever the hand holding it puts it (`hold`, each frame). Thrown
## (`throw`), it flies on its own: it falls as it goes and turns to point the way
## it is going, and where it meets anything solid (`collision_mask`) it sticks in,
## its point buried and its shaft quivering, or falls flat if it comes down on
## something it cannot go into. It catches nobody itself: `hits(feet, height,
## radius)` says whether its last stretch of flight passed through an upright
## body there (a player standing, or ducked under it), for the game to decide.
##
##     var spear := TribeSpear.new()
##     spear.point = TribeSpear.Point.BONE
##     add_child(spear)                  # it is top level: it goes where it is told
##     spear.hold(hand_transform)        # each frame it is held (its grip; the point down -Z)
##     spear.throw(velocity)             # off it goes from where it is
##     # each physics frame while `flying()`:
##     if spear.hits(player_feet, 1.3, 0.3): ...
##     # `landed(at, stuck)` when it comes to rest; `lying_at()` is where to pick it up.
##
## One draw (one surface, its tones in its vertex colours: Tribesman.carved).

## It has come to rest: where its point is, and whether it is stuck into something (or lying flat).
signal landed(at: Vector3, stuck: bool)

enum Point { STONE, BONE }
enum State { HELD, FLYING, STUCK, LYING }

const MODEL := "res://creatures/masked_tribe/models/spears.glb"
const MODEL_LO := "res://creatures/masked_tribe/models/spears_lo.glb"
## From its grip to its point, and to its butt, metres (as modelled).
const TIP := 1.19
const BUTT := 0.72
## How deep it goes into what it sticks in.
const BURY := 0.13

## Its head: knapped stone or bone. Set before it goes in.
@export var point := Point.STONE
@export var low_poly := false
## How hard it is pulled down in flight (m/s²: less than a stone, as a spear sails).
@export var gravity := 6.0
## What it sticks in (physics layers): the world.
@export var collision_mask := 1
## Longest it flies before it is let fall, seconds.
@export var longest := 3.0

var state := State.HELD
## Its speed in flight.
var velocity := Vector3.ZERO
## How long it has been flying, or resting since it landed.
var time := 0.0

var _mesh: MeshInstance3D
var _tip_was := Vector3.ZERO
var _quiver := 0.0
var _rest := Transform3D.IDENTITY
var _bodies := []
static var _meshes := {}


func _ready() -> void:
	top_level = true
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh_of(point, low_poly or Settings.low_poly)
	_mesh.material_override = Tribesman.carved()
	add_child(_mesh)
	_tip_was = tip()


## The spear's mesh (shared): its grip at the origin, the point down -Z.
static func mesh_of(which: Point, low := false) -> Mesh:
	var key := "%d%s" % [which, "lo" if low else ""]
	if _meshes.has(key):
		return _meshes[key]
	var scene := (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	var found := scene.find_child("spear_bone" if which == Point.BONE else "spear_stone", true, false) as MeshInstance3D
	var mesh: Mesh = found.mesh if found else null
	scene.free()
	_meshes[key] = mesh
	return mesh


## In a hand: its grip at `grip`'s origin, its point down `grip`'s -Z.
func hold(grip: Transform3D) -> void:
	state = State.HELD
	velocity = Vector3.ZERO
	global_transform = grip
	_tip_was = tip()


## Flies from where it is, at `going` (m/s), point first.
func throw(going: Vector3) -> void:
	state = State.FLYING
	velocity = going
	time = 0.0
	_point_along(going)
	_tip_was = tip()
	# (thrown with its point already in a wall, it is in the wall)
	if is_inside_tree() and going.length_squared() > 0.01:
		var query := PhysicsRayQueryParameters3D.create(global_position, tip(), collision_mask)
		query.exclude = _bodies
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_land(hit.position, hit.normal)


## Lays it at rest somewhere (stuck in, or flat), as if it had landed there.
func put(at: Transform3D, stuck := true) -> void:
	state = State.STUCK if stuck else State.LYING
	global_transform = at
	_rest = at
	time = 0.0
	_quiver = 0.0
	_tip_was = tip()


func flying() -> bool:
	return state == State.FLYING


func held() -> bool:
	return state == State.HELD


## Where its point is, in the world.
func tip() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, -TIP)


## Where its point was a physics frame ago (in flight: the stretch it went through is `tip_was()` to `tip()`).
func tip_was() -> Vector3:
	return _tip_was


## Where a hand should go to take it up again: its grip.
func lying_at() -> Vector3:
	return global_position


## Whether its point's last stretch of flight went through an upright body: one
## standing on `feet`, `height` tall, `radius` round.
func hits(feet: Vector3, height: float, radius: float) -> bool:
	# (in flight, or the moment it landed: the stretch that brought it there)
	if state == State.HELD or (state != State.FLYING and time > 0.0):
		return false
	return passes(_tip_was, tip(), feet, height, radius)


## Whether a stretch from `a` to `b` passes within `radius` of an upright body
## from `feet` up `height`.
static func passes(a: Vector3, b: Vector3, feet: Vector3, height: float, radius: float) -> bool:
	# (nearest points of the stretch and the body's upright line)
	var d1 := b - a
	var d2 := Vector3.UP * height
	var r := a - feet
	var aa := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if aa < 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		var bb := d1.dot(d2)
		var denom := aa * e - bb * bb
		s = clampf((bb * f - c * e) / denom, 0.0, 1.0) if denom > 0.000001 else 0.0
		t = (bb * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / aa, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((bb - c) / aa, 0.0, 1.0)
	return (a + d1 * s).distance_to(feet + d2 * t) < radius


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		return
	time += delta
	if state != State.FLYING:
		_tip_was = tip()
		return
	_tip_was = tip()
	velocity.y -= gravity * delta
	var next := global_position + velocity * delta
	var from := _tip_was
	var to := next + velocity.normalized() * TIP
	var hit := {}
	if is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(from, to + velocity.normalized() * 0.05, collision_mask)
		query.exclude = _bodies
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_land(hit.position, hit.normal)
		return
	global_position = next
	_point_along(velocity)
	if time > longest:
		state = State.LYING
		landed.emit(tip(), false)


## Meets something: sticks into it, point buried, or (glancing, or flat on the
## floor at a low angle) falls and lies there.
func _land(at: Vector3, normal: Vector3) -> void:
	var way := velocity.normalized()
	var square := -way.dot(normal)
	if square > 0.3:
		# (in it goes: the point BURY deep, the shaft out along the way it came)
		var grip := at - way * (TIP - BURY)
		global_position = grip
		_point_along(way)
		state = State.STUCK
		_quiver = 1.0
	else:
		# (it skids and lies flat where it came down)
		var flat := way.slide(normal).normalized() if way.slide(normal).length() > 0.01 else Vector3.FORWARD
		global_position = at + normal * 0.03 - flat * (TIP * 0.5)
		_point_along(flat)
		state = State.LYING
	_rest = global_transform
	time = 0.0
	velocity = Vector3.ZERO
	landed.emit(tip(), state == State.STUCK)


func _process(delta: float) -> void:
	# Stuck in, its shaft quivers and is still.
	if state == State.STUCK and _quiver > 0.0:
		_quiver = maxf(_quiver - delta * 1.1, 0.0)
		var swing := sin(time * 55.0) * 0.06 * _quiver * _quiver
		var pivot := _rest * Vector3(0.0, 0.0, -(TIP - BURY))
		var turned := Basis(_rest.basis.x.normalized(), swing)
		global_transform = Transform3D(turned * _rest.basis, pivot + turned * (_rest.origin - pivot))


func _point_along(way: Vector3) -> void:
	if way.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(way.normalized().y) < 0.98 else Vector3.FORWARD
	global_basis = Basis.looking_at(way, up)
