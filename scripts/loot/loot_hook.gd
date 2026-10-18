class_name LootHook
extends GrappleHook
## The grappling hook to be found (see LootItem, whose `kind`, `loot_id` and
## `loot_state` it shares): the character controller's GrappleHook, which the boy
## throws with act at whatever is in reach above him and swings and climbs on,
## made to catch where the maze gives it something to catch: the lip of any
## ledge in reach (a mezzanine, a terrace, the platform under a sewer pipe, the
## top of a buttress), found by feeling for it with rays, as well as anything in
## the group `grapple_points`, the hook spots (GrappleSpots) and vines (GrappleHook's
## own). Out of reach of the wall tops, by design (it is a way up to the ledges,
## not over the walls), but where a route of hook spots goes up to one.
##
## Lying about it is the coil of rope with the grapnel on it (props/models/hook.glb);
## in his hand, GrappleHook's own coil. Its rope frays: after `bites` catches it
## parts, and it is gone (`frayed`).

signal released(item: Node3D)
signal rested(item: Node3D)
## Its rope has parted: it is used up.
signal frayed(item: Node3D)

## How many catches its rope is good for.
const BITES := 6

var kind := LootItem.Kind.HOOK
var loot_id := -1
var loot_state := LootItem.State.LYING
var bearer: Node3D
var lit := false
var fuel := 0.0
var ward_radius := 0.0
## Catches left before the rope parts.
var bites := BITES

var _model: Node3D
var _ledge: Marker3D
var _still := 0.0
var _aloft := 0.0
var _fraying := false
## How good the lip `_find_ledge` last found is (as GrappleHook.best_score).
var _ledge_score := INF


func _ready() -> void:
	super()
	process_priority = 100
	# (taken with the act button as Loot says, into the inventory, not straight
	# into the hand as a loose thing would be)
	remove_from_group(&"throwable")
	remove_from_group(&"interest")
	add_to_group(&"loot")
	reach = 13.0
	steep = 62.0
	collision_layer = LootItem.LAYER
	collision_mask = LootItem.MASK
	_model = (load(LootItem.MODELS[LootItem.Kind.HOOK]) as PackedScene).instantiate() as Node3D
	add_child(_model)
	LootItem.shade(_model)
	add_child(LootGlint.new(float(posmod(loot_id, 9)) * 0.41))
	_ledge = Marker3D.new()
	_ledge.top_level = true
	add_child(_ledge)
	if loot_state == LootItem.State.LYING:
		lie()


func title() -> String:
	return LootItem.NAMES[kind]


func in_hand() -> bool:
	return true


## As LootItem.lie: on the ground, still. The coil and grapnel model shows; the
## held coil does not.
func lie() -> void:
	loot_state = LootItem.State.LYING
	visible = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	collision_layer = LootItem.LAYER
	collision_mask = LootItem.MASK
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_show_coil(false)


func lay_at(at: Vector3, yaw: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	lie()


func pocket() -> void:
	loot_state = LootItem.State.POCKET
	visible = false
	freeze = true
	collision_layer = 0
	collision_mask = 0
	bearer = null


func fly(velocity_now: Vector3, spin := Vector3.ZERO) -> void:
	loot_state = LootItem.State.FLYING
	visible = true
	bearer = null
	collision_layer = LootItem.LAYER
	collision_mask = LootItem.MASK
	freeze = false
	linear_velocity = velocity_now
	angular_velocity = spin
	_still = 0.0
	_aloft = 0.0
	_show_coil(false)


func set_lit(_on: bool) -> void:
	pass


func spend(_gone := true) -> void:
	loot_state = LootItem.State.SPENT
	remove_from_group(&"loot")
	visible = false
	freeze = true
	collision_layer = 0
	collision_mask = 0


## In a hand, GrappleHook's coil hangs from it; lying, the model does.
func _show_coil(held: bool) -> void:
	if _model:
		_model.visible = not held
	if _coil:
		_coil.visible = held
	if _head and loot_state != LootItem.State.HAND:
		_head.visible = held


func taken_by(who: Node) -> void:
	super(who)
	if who == null:
		bearer = null
		released.emit(self)
	else:
		bearer = who as Node3D
		loot_state = LootItem.State.HAND
		_show_coil(true)


## Shown in a friend's hand (they hold it: no Player here to throw it).
func held_by(who: Node3D) -> void:
	bearer = who
	loot_state = LootItem.State.HAND
	visible = true
	_show_coil(true)
	_head.visible = true


## What the hook would catch: the lip of the nearest ledge in reach in front of
## him (see `_find_ledge`), or what GrappleHook would (a spot made for it, a
## vine, a grapple point), whichever is the better. (The spots and vines count
## a little nearer than they are: one is chosen over a lip about as far off.)
func find_target(who: Player) -> Node3D:
	var other := super(who)
	var other_score := best_score
	var edge := _find_ledge(who)
	if edge.is_finite() and _ledge_score < other_score:
		_ledge.global_position = edge
		best_score = _ledge_score
		return _ledge
	return other


## Feels for a ledge's lip in front of `who` that the hook would catch: rays
## down from out of his reach onto the ground in front of him, out to a few
## metres, the way he faces and the camera looks; the first top (level ground,
## high enough over his hands) is walked back towards him to its edge. The
## nearest lip in plain sight from his hands, within the rope's reach, wins.
## Not finite if there is none.
func _find_ledge(who: Player) -> Vector3:
	if not who.is_inside_tree():
		return Vector3.INF
	var space := who.get_world_3d().direct_space_state
	var hands := who.global_position + Vector3.UP * who.hang_height
	var facing := Vector3(sin(who.facing_yaw), 0.0, cos(who.facing_yaw))
	var aim := facing
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var look := -camera.global_basis.z
		look.y = 0.0
		if look.length() > 0.2 and facing.dot(look.normalized()) > -0.3:
			aim = (facing + look.normalized()).normalized()
	var best := Vector3.INF
	var least := INF
	var skip: Array[RID] = [who.get_rid()]
	for turn: float in [0.0, 0.45, -0.45, 0.9, -0.9]:
		var way := aim.rotated(Vector3.UP, turn)
		for out: float in [1.2, 2.2, 3.4, 4.8, 6.4]:
			var over := hands + way * out
			var from := Vector3(over.x, hands.y + reach * 0.98, over.z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(over.x, hands.y + rise, over.z), 1, skip))
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.8:
				continue
			var top: Vector3 = hit["position"]
			# (walked back towards him till the top ends: that is the lip)
			var lip := top
			for k in 12:
				var back := lip - way * 0.25
				var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(back.x, top.y + 0.4, back.z), Vector3(back.x, top.y - 0.35, back.z), 1, skip))
				if down.is_empty():
					break
				lip = back
			if lip.distance_to(top) > 2.9:
				continue
			# (a little out from the lip: the rope hangs clear of it, so that at its top
			# he is beside the edge to pull himself over, not under it)
			var point := lip - way * 0.3 + Vector3.UP * 0.05
			var distance := point.distance_to(hands)
			if distance > reach:
				continue
			var level := Vector3(point.x - hands.x, 0.0, point.z - hands.z)
			if rad_to_deg(atan2(level.length(), point.y - hands.y)) > steep:
				continue
			var score := distance * (1.0 + absf(turn) * 0.6)
			if score >= least:
				continue
			# (in plain sight from his hands: nothing but the ledge itself in the way)
			var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(hands, point, 1, skip))
			if not sight.is_empty() and (sight["position"] as Vector3).distance_to(point) > 0.45:
				continue
			least = score
			best = point
			break
	_ledge_score = least
	return best


func _bite() -> void:
	super()
	if state == GrappleHook.State.BITTEN:
		bites -= 1


func _physics_process(delta: float) -> void:
	super(delta)
	if loot_state == LootItem.State.FLYING:
		_aloft += delta
		if LootItem.settle(self, delta):
			rested.emit(self)
	# (its last catch over and the hook wound in, the rope parts)
	if bites <= 0 and state == GrappleHook.State.HOME and not _fraying and loot_state == LootItem.State.HAND:
		_fraying = true
		frayed.emit(self)


## As LootItem.let_fly.
func let_fly() -> void:
	loot_state = LootItem.State.FLYING
	bearer = null
	_aloft = 0.0
	_still = 0.0
	_show_coil(false)
