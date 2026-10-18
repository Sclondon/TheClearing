class_name LootItem
extends RigidBody3D
## Something left lying about the clearing and the maze, to find and take (see
## Loot, which places them, keeps everyone's copies in step and keeps the
## inventory): a grappling hook, a backpack, a spear, a torch, a flare, a scrap of
## a map, a rope ladder; something to fight with: a stick, a bat, a sword,
## rarely a revolver or a shotgun, and more rarely still a box of a few rounds
## for one (DESIGN.md: "What lies about", "Fighting back"); and meat, cut from a
## carcass. Meat is for what eats it: lying on the ground it is in the group
## `meat` (meat-eaters that smell it go to it, and a feral dog fed it is a
## friend: MazeDog), and `eat` is how it is eaten.
##
## One of these is a loose body like anything the boy can carry (Player.carried),
## and what Player does with what is in his hand works on it: act throws it. A
## torch is also in the group `torches` (he holds it up), a spear in `spears`; a
## stick, a bat and a sword in `bats` (he holds it in both hands and swings it:
## Player.swing_progress, and Loot sees what it hits), a gun in `guns` (he brings
## it up and fires it: Player calls `fire`, and Loot shoots). The grappling hook
## is not one of these but a LootHook (a GrappleHook) with the same `kind`,
## `loot_id` and `loot_state`, made by `LootItem.make`.
##
## Its models are built in Blender: props/tools/build_props.py (props/models/).

## What it is. (Sent over the network by number: new kinds go on the end.)
enum Kind { HOOK, BACKPACK, SPEAR, TORCH, FLARE, MAP, LADDER, STICK, BAT, SWORD, REVOLVER, SHOTGUN, ROUNDS, SHELLS, MEAT }
## Where it is: lying about, in someone's pocket (pack), in someone's hand, in
## the air (thrown or dropped), or used up (a burnt-out flare, a hung ladder).
enum State { LYING, POCKET, HAND, FLYING, SPENT }

## What each is called (in the inventory, the prompt, the dev panel) and its model.
const NAMES := {
	Kind.HOOK: "GRAPPLING HOOK", Kind.BACKPACK: "BACKPACK", Kind.SPEAR: "SPEAR", Kind.TORCH: "TORCH",
	Kind.FLARE: "FLARE", Kind.MAP: "MAP SCRAP", Kind.LADDER: "ROPE LADDER", Kind.STICK: "STICK", Kind.BAT: "BAT",
	Kind.SWORD: "SWORD", Kind.REVOLVER: "REVOLVER", Kind.SHOTGUN: "SHOTGUN", Kind.ROUNDS: "BOX OF ROUNDS",
	Kind.SHELLS: "BOX OF SHELLS", Kind.MEAT: "RAW MEAT",
}
const SHORT := {
	Kind.HOOK: "HOOK", Kind.BACKPACK: "BACKPACK", Kind.SPEAR: "SPEAR", Kind.TORCH: "TORCH",
	Kind.FLARE: "FLARE", Kind.MAP: "MAP", Kind.LADDER: "LADDER", Kind.STICK: "STICK", Kind.BAT: "BAT",
	Kind.SWORD: "SWORD", Kind.REVOLVER: "REVOLVER", Kind.SHOTGUN: "SHOTGUN", Kind.ROUNDS: "ROUNDS",
	Kind.SHELLS: "SHELLS", Kind.MEAT: "MEAT",
}
const MODELS := {
	Kind.HOOK: "res://props/models/hook.glb", Kind.BACKPACK: "res://props/models/pack.glb",
	Kind.SPEAR: "res://props/models/spear.glb", Kind.TORCH: "res://props/models/torch.glb",
	Kind.FLARE: "res://props/models/flare.glb", Kind.MAP: "res://props/models/map.glb",
	Kind.LADDER: "res://props/models/ladder.glb", Kind.STICK: "res://props/models/branch.glb",
	Kind.BAT: "res://props/models/bat.glb", Kind.SWORD: "res://props/models/sword.glb",
	Kind.REVOLVER: "res://props/models/revolver.glb", Kind.SHOTGUN: "res://props/models/shotgun.glb",
	Kind.ROUNDS: "res://props/models/rounds.glb", Kind.SHELLS: "res://props/models/shells.glb",
	Kind.MEAT: "res://props/models/meat.glb",
}
## Held in the hand to be used (act throws, casts, swings or fires it, or holds
## meat out to a dog), or used from the inventory straight off (read, hung).
const IN_HAND := [Kind.HOOK, Kind.SPEAR, Kind.TORCH, Kind.FLARE, Kind.STICK, Kind.BAT, Kind.SWORD, Kind.REVOLVER, Kind.SHOTGUN,
	Kind.MEAT]
## Swung (Loot: what a blow does). `reach`: metres past his middle to what it
## hits (past its girth); `seconds` and `shove`: the stagger (Stagger.hit);
## `uses`: blows that land before it breaks (a range; 0, never); `swing`: how
## long a swing takes, seconds; `cleaves`: it hits everything in its sweep, not
## only the first. A stick is weak and soon snaps; a bat knocks a hunter well
## back; a sword is the best of them and never breaks.
const MELEE := {
	Kind.STICK: {"reach": 1.55, "seconds": 1.3, "shove": 0.9, "uses": Vector2i(3, 6), "swing": 0.45, "cleaves": false},
	Kind.BAT: {"reach": 1.75, "seconds": 2.2, "shove": 4.2, "uses": Vector2i(12, 16), "swing": 0.6, "cleaves": false},
	Kind.SWORD: {"reach": 2.0, "seconds": 3.4, "shove": 2.0, "uses": Vector2i(0, 0), "swing": 0.55, "cleaves": true},
}
## Fired (Loot: what a shot does). `capacity`: rounds it holds; `ammo`: the
## kind of box that fills it; `range`: how far it reaches, metres; `fells`: out
## to how far a shot fells what it hits (further, it only staggers it);
## `aim`: how far off a shot may pass and still hit, metres past a hunter's
## girth (and per metre away); `kick`, `two_handed`: for the Player and the rig;
## `reload`: seconds to load it from spare rounds.
const GUNS := {
	Kind.REVOLVER: {"capacity": 6, "ammo": Kind.ROUNDS, "range": 45.0, "fells": 30.0, "aim": Vector2(0.35, 0.0),
		"kick": 0.6, "two_handed": false, "reload": 1.6},
	Kind.SHOTGUN: {"capacity": 2, "ammo": Kind.SHELLS, "range": 24.0, "fells": 11.0, "aim": Vector2(0.45, 0.09),
		"kick": 1.3, "two_handed": true, "reload": 1.4},
}
## Where a gun's muzzle is, and its fore-end (where the off hand holds a long one), in its own space.
const MUZZLE := {Kind.REVOLVER: Vector3(0.0, 0.058, -0.21), Kind.SHOTGUN: Vector3(0.0, 0.04, -0.73)}
const SUPPORT := {Kind.SHOTGUN: Vector3(0.0, 0.0, -0.27)}
## A box of rounds or shells: the gun kind it fills.
const BOX_FOR := {Kind.ROUNDS: Kind.REVOLVER, Kind.SHELLS: Kind.SHOTGUN}

## How long a torch burns, seconds, all told; and from how long before the end
## it burns low.
const TORCH_BURNS := 240.0
const TORCH_LOW := 30.0
## How long a thrown flare burns, seconds.
const FLARE_BURNS := 45.0
## A lit torch (or flare) keeps what fears fire this far off, metres (FireWard).
const WARD := 5.0
## What a dropped or thrown thing collides with (the world), and its layer.
const LAYER := 8
const MASK := 1

## Told when it leaves the hand that held it (put down, thrown, or put away).
signal released(item: Node3D)
## Told when it comes to rest after being thrown or dropped.
signal rested(item: Node3D)
## Told when (meat) it is eaten.
signal eaten(item: Node3D)

var kind := Kind.TORCH
## Its number, the same on every copy of the game (Loot gives it).
var loot_id := -1
var loot_state := State.LYING
## Who has it in their hand (the Player, or a friend's RemotePlayer), if anyone.
var bearer: Node3D
## A torch's or a flare's: whether it burns, and how many seconds of burning it has left.
var lit := false
var fuel := 0.0
## Fire wards (FireWard): how far off what fears fire is kept, while it burns.
var ward_radius := 0.0
## A stick's or a bat's blows left before it breaks (0: it never does); the
## rounds in a gun; the rounds in a box of them. Travels with it to whoever has it next.
var uses := 0
## A gun's, for the Player and the rig: held in both hands, and how hard it kicks.
var two_handed := false
var kick := 0.5
## The Loot that keeps it (a gun asks it to shoot).
var loot: Node

var _model: Node3D
var _fire: Fire
var _still := 0.0
var _aloft := 0.0


## A new one of `kind`: a LootItem, or for the hook a LootHook.
static func make(of: Kind) -> RigidBody3D:
	if of == Kind.HOOK:
		return LootHook.new()
	var item := LootItem.new()
	item.kind = of
	return item


func _ready() -> void:
	# (after the rig has posed whoever holds it: see _process)
	process_priority = 100
	add_to_group(&"loot")
	add_to_group(&"fire_wards")
	collision_layer = LAYER
	collision_mask = MASK
	mass = 0.8
	gravity_scale = 1.6
	angular_damp = 3.0
	var shape := CapsuleShape3D.new()
	var collider := CollisionShape3D.new()
	match kind:
		Kind.SPEAR:
			shape.radius = 0.05
			shape.height = 2.1
			collider.position.y = 0.2
		Kind.TORCH:
			shape.radius = 0.05
			shape.height = 0.8
			collider.position.y = 0.18
		Kind.MEAT:
			# (it hangs below the knuckle it is held by)
			shape.radius = 0.07
			shape.height = 0.3
			collider.position.y = -0.18
		Kind.STICK, Kind.BAT:
			shape.radius = 0.04
			shape.height = 0.85
			collider.position.y = 0.33
		Kind.SWORD:
			shape.radius = 0.035
			shape.height = 1.0
			collider.position.y = 0.4
		_:
			shape.radius = 0.08
			shape.height = 0.3
	collider.shape = shape
	if kind == Kind.BACKPACK:
		# (a pack lies flat: a box, not a capsule standing up)
		var flat := BoxShape3D.new()
		flat.size = Vector3(0.38, 0.2, 0.5)
		collider.shape = flat
		collider.position.y = 0.1
	elif kind in GUNS:
		# (a gun lies on its side: a box along its barrel)
		var long := BoxShape3D.new()
		long.size = Vector3(0.05, 0.12, 0.85 if kind == Kind.SHOTGUN else 0.26)
		collider.shape = long
		collider.position = Vector3(0.0, 0.0, -0.18 if kind == Kind.SHOTGUN else -0.08)
	elif kind in BOX_FOR:
		var little := BoxShape3D.new()
		little.size = Vector3(0.1, 0.06, 0.08)
		collider.shape = little
		collider.position.y = 0.03
	add_child(collider)
	_model = (load(MODELS[kind]) as PackedScene).instantiate() as Node3D
	add_child(_model)
	LootItem.shade(_model)
	match kind:
		Kind.TORCH:
			add_to_group(&"torches")
			fuel = TORCH_BURNS
			_fire = Fire.torch()
			_fire.position = Vector3(0.0, 0.5, 0.0)
			add_child(_fire)
		Kind.SPEAR:
			add_to_group(&"spears")
		Kind.STICK, Kind.BAT, Kind.SWORD:
			add_to_group(&"bats")
		Kind.REVOLVER, Kind.SHOTGUN:
			add_to_group(&"guns")
			two_handed = GUNS[kind]["two_handed"]
			kick = GUNS[kind]["kick"]
		Kind.FLARE:
			fuel = FLARE_BURNS
			_fire = Fire.new()
			_fire.size = 0.22
			_fire.spread = 0.35
			_fire.core = Color(1.0, 0.85, 0.8)
			_fire.body = Color(1.0, 0.18, 0.12)
			_fire.tip = Color(0.6, 0.04, 0.08)
			_fire.light_energy = 5.0
			_fire.light_range = 24.0
			_fire.position = Vector3(0.0, 0.17, 0.0)
			add_child(_fire)
	if _fire:
		_fire.visible = false
	add_child(LootGlint.new(float(posmod(loot_id, 9)) * 0.41))
	set_lit(lit)
	if loot_state == State.LYING:
		lie()


## Shades a model of the props as the world is (Toon.surface of each material's colour).
static func shade(model: Node) -> void:
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var key := original.albedo_color.to_html()
			if not made.has(key):
				made[key] = Toon.surface(original.albedo_color)
			part.set_surface_override_material(surface, made[key])


## What it is called.
func title() -> String:
	return NAMES[kind]


## Whether it is held in the hand to be used (or used from the inventory).
func in_hand() -> bool:
	return kind in IN_HAND


## Lies still where it is, on the ground, to be found: frozen, so that it costs nothing.
func lie() -> void:
	loot_state = State.LYING
	visible = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	collision_layer = LAYER
	collision_mask = MASK
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if kind == Kind.MEAT:
		add_to_group(&"meat")


## Laid on the ground at `at` (its foot), turned `yaw`, as it was left there.
func lay_at(at: Vector3, yaw: float) -> void:
	var tip := Basis(Vector3.UP, yaw)
	if kind in [Kind.SPEAR, Kind.TORCH, Kind.FLARE, Kind.STICK, Kind.BAT, Kind.SWORD, Kind.MEAT]:
		# (long things lie along the ground)
		tip = tip * Basis(Vector3.RIGHT, PI * 0.5)
		at += Vector3.UP * (0.045 if kind == Kind.SPEAR else (0.025 if kind == Kind.SWORD else (0.06 if kind == Kind.MEAT else 0.035)))
	elif kind in GUNS:
		# (a gun lies on its side)
		tip = tip * Basis(Vector3.BACK, PI * 0.5)
		at += Vector3.UP * 0.022
	global_transform = Transform3D(tip, at)
	lie()


## Out of the world, in someone's pocket or pack.
func pocket() -> void:
	loot_state = State.POCKET
	visible = false
	freeze = true
	collision_layer = 0
	collision_mask = 0
	bearer = null
	set_lit(false)
	remove_from_group(&"meat")


## Let go in the air (thrown or dropped): it falls, and comes to rest.
func fly(velocity_now: Vector3, spin := Vector3.ZERO) -> void:
	loot_state = State.FLYING
	remove_from_group(&"meat")
	visible = true
	bearer = null
	collision_layer = LAYER
	collision_mask = MASK
	freeze = false
	linear_velocity = velocity_now
	angular_velocity = spin
	_still = 0.0
	_aloft = 0.0


## A torch or a flare alight, or out.
func set_lit(on: bool) -> void:
	lit = on and fuel > 0.0 and (kind == Kind.TORCH or kind == Kind.FLARE)
	if _fire:
		_fire.visible = lit
	ward_radius = WARD if lit else 0.0


## Used up, and left where it is (a flare burnt out), or gone (a hung ladder, a read map).
func spend(gone := true) -> void:
	loot_state = State.SPENT
	set_lit(false)
	remove_from_group(&"loot")
	remove_from_group(&"meat")
	if gone:
		visible = false
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		lie()
		loot_state = State.SPENT


## (Meat) eaten, by whatever has come to it where it lies or been fed it from a
## hand: Loot hears, and it is used up everywhere.
func eat() -> void:
	if kind == Kind.MEAT and loot_state != State.SPENT:
		eaten.emit(self)


## Told by the Player who picks it up (Player._take), and with nobody when it
## leaves his hand.
func taken_by(who: Node) -> void:
	if who == null:
		bearer = null
		released.emit(self)
	else:
		bearer = who as Node3D
		loot_state = State.HAND


func _physics_process(delta: float) -> void:
	if lit:
		fuel -= delta
		if fuel <= TORCH_LOW and _fire and kind == Kind.TORCH:
			# (burning low: smaller, and its light falling off)
			var left := clampf(fuel / TORCH_LOW, 0.0, 1.0)
			_fire.intensity = lerpf(0.45, 1.0, left)
		if fuel <= 0.0:
			fuel = 0.0
			set_lit(false)
	if loot_state == State.FLYING:
		_aloft += delta
		var speed := linear_velocity.length()
		if kind == Kind.SPEAR and speed > 4.0 and _aloft < 1.5:
			# (a thrown spear flies point first)
			global_basis = Basis(Quaternion(Vector3.UP, linear_velocity.normalized()))
			angular_velocity = Vector3.ZERO
		if LootItem.settle(self, delta):
			rested.emit(self)


## Whether `item` (flying) has come down: slow, with the ground just under it,
## for a moment (or flying too long). Then it is laid flat where it is, as it
## would be found. (A loose body left to roll comes to rest only slowly; this
## puts it down neatly, the same on every copy.)
static func settle(item: RigidBody3D, delta: float) -> bool:
	var aloft: float = item.get(&"_aloft")
	# (a thin thing can go through a heightmap's ground between one step and
	# the next: if it has, it is put down where it went through)
	var space := item.get_world_3d().direct_space_state
	var last: Vector3 = item.get_meta(&"last", item.global_position)
	item.set_meta(&"last", item.global_position)
	if last.y > item.global_position.y:
		var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(last + Vector3.UP * 0.1, item.global_position + Vector3.DOWN * 0.05, 1))
		if not through.is_empty() and (through["normal"] as Vector3).y > 0.55 and item.global_position.y < (through["position"] as Vector3).y:
			var going := item.linear_velocity
			item.call(&"lay_at", through["position"], atan2(going.x, going.z) if Vector2(going.x, going.z).length() > 0.1 else 0.0)
			return true
	if aloft < 0.35 or (item.linear_velocity.length() > 3.0 and aloft < 6.0):
		item.set(&"_still", 0.0)
		return false
	var from := item.global_position + Vector3.UP * 0.3
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.3, 1))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.55:
		item.set(&"_still", 0.0)
		if item.global_position.y < -40.0:
			# (fallen out of the world: back where it would be found)
			item.global_position = Vector3(item.global_position.x, 1.0, item.global_position.z)
			item.linear_velocity = Vector3.ZERO
		return false
	var still: float = item.get(&"_still") + delta
	item.set(&"_still", still)
	if still < 0.25 and aloft < 6.0:
		return false
	var along := item.global_basis.y
	var level := Vector3(along.x, 0.0, along.z)
	var yaw := atan2(level.x, level.z) if level.length() > 0.3 else item.global_basis.get_euler().y
	item.call(&"lay_at", hit["position"], yaw)
	return true


func _process(_delta: float) -> void:
	if loot_state != State.HAND or not is_instance_valid(bearer):
		return
	# A friend's copy holds it in their figure's hand; the Player puts it in his
	# own (Player._place_carried), and only a spear needs turning after that.
	var rig: CharacterRig = bearer.get(&"rig") if not (bearer is Player) else null
	var yaw: float = bearer.get(&"facing_yaw") if bearer.get(&"facing_yaw") != null else 0.0
	if rig:
		if kind in GUNS:
			# (held by its grip, pointing where their arm points it)
			global_transform = rig.gun_transform()
			return
		global_position = rig.hand_position()
		if kind in MELEE:
			global_basis = rig.bat_basis()
			return
		if kind == Kind.TORCH:
			global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.18)
			global_position -= global_basis.y * 0.14
		elif kind != Kind.SPEAR:
			global_basis = Basis(Vector3.UP, yaw)
	if kind == Kind.SPEAR:
		# (carried point up, leaning forward, held a third of the way up; winding
		# up to throw, brought down level over his shoulder, point first)
		var winding: float = bearer.get(&"throw_progress") if bearer.get(&"throw_progress") != null else 1.0
		var level := smoothstep(0.0, 0.25, winding) if winding < 1.0 else 0.0
		global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lerpf(0.32, PI * 0.5 - 0.12, level))
	elif kind == Kind.FLARE and rig == null:
		global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.4)
	elif kind == Kind.MEAT:
		# (held by the knuckle of its bone, the meat hanging from his hand, swinging a little as he goes)
		var going: Vector3 = bearer.get(&"velocity") if bearer.get(&"velocity") != null else Vector3.ZERO
		var swing := clampf(Vector2(going.x, going.z).length() * 0.06, 0.0, 0.35)
		global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -swing * sin(Time.get_ticks_msec() * 0.009) - 0.15)


## Whether it is something to fight with (swung or fired).
func weapon() -> bool:
	return kind in MELEE or kind in GUNS


## A gun: the trigger pulled by `shooter`, aimed along `aim` (Player._fire).
## Loot shoots, clicks if it is empty, or loads it. True if it went off.
func fire(shooter: Node3D, aim: Vector3) -> bool:
	if loot == null or not kind in GUNS:
		return false
	return loot.call(&"gun_fire", self, shooter, aim)


## A gun's muzzle in the world, its -Z the way it points.
func muzzle() -> Transform3D:
	return global_transform.translated_local(MUZZLE.get(kind, Vector3.ZERO))


## Where the off hand holds a long gun, in the world (CharacterRig).
func support_point() -> Vector3:
	return global_transform * SUPPORT.get(kind, Vector3(0.0, 0.0, -0.3))


## Thrown or put down from a hand (the Player has let go of it and set it going): it flies.
func let_fly() -> void:
	loot_state = State.FLYING
	bearer = null
	_aloft = 0.0
	_still = 0.0
