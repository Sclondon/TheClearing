class_name MazeGnome
extends MazeEnemy
## A band of gnomes in the maze. What a gnome looks like and how it moves is
## Gnome (creatures/gnome/, a component of its own); this is only what it
## thinks, and it drives the Gnome by moving it and calling on it.
##
## Gnomes do not catch anyone. They are thieves and a nuisance.
##
## - HOME. A band (`band_of`: three to five) lives in a hollow at the foot of a
##   wall (GnomeHollow: a little door ajar on the dark), pottering about before
##   its door.
## - SEEN, THEY ARE STILL. While anyone in sight is looking their way (the way
##   he faces: what is behind his back he does not see) a gnome does not move at all: it stands as stiff as a garden ornament in whatever
##   it was doing. Only unwatched does it move, and then quickly. Look away and
##   back, and they are closer.
## - STALK. Someone who has something in their pockets (Loot) comes within
##   `territory` of the hollow and is noticed (MazeEnemy's senses): the band
##   creeps after them whenever nobody is looking, on tiptoe, to come up behind
##   them. The patter of little feet and a whisper or a giggle are the warning;
##   turn round and they are statues.
## - SNATCH. Right behind someone and unwatched, a gnome snatches one thing from
##   their pockets (never what is in their hand) and runs for home with it
##   hugged to its chest (FLEE), faster than a run, slower than a sprint, and
##   never stops for being looked at. Catch it (run into it) and it drops what it
##   took (it lies there to be taken back), squeals, tumbles and runs home
##   empty-handed. If it gets home it lays it by its door with the rest of the
##   hoard (all still there to be taken, if you dare) and HIDEs in the hollow a
##   while.
## - THE ROPE. Someone running down at the hollow (from `rope_range`) and two of
##   the band run out with a rope and pull it taut across the hall at shin
##   height between them, giggling. Run into it and you go sprawling (a trip,
##   not a catch: the rest of the band may be on you while you are down); jump
##   it, or walk, and you step over it. They hold it `rope_time` and go home.
## - UP AFTER YOU. Up on a ledge, a terrace or a concrete bridge with something in
##   your pockets is not safe: unwatched they clamber up the bare face after you,
##   hand over hand like little men, and come up behind you along the top; turn
##   and they are statues on the wall. One that snatches up there runs for home
##   off the edge (MazeEnemy's CLIMBING; the user, 2026-10-18: "more creatures
##   should be able to climb things").
## - A lit torch near (FireWard) keeps them off. Anything bigger that would eat
##   them (Ecology: they are small prey) sends them running into the hollow.
##
## Online, as every MazeEnemy: the host's copy thinks; a puppet follows what it
## hears (its mode, whether it is frozen, counts of its snatches and giggles,
## and where it snatches). The theft itself is done on the machine of whoever
## is robbed (only theirs knows their pockets) and told to the room
## ({"folk": "gnome_stole"}); what a gnome drops or lays by its door is put
## down for everyone as anything dropped is (Loot "drop"). The trip, too, is
## done where whoever trips plays.

enum Mode { HOME, STALK, SNATCH, FLEE, CAUGHT, HIDE, ROPE_RUN, ROPE, RETURN }

## Metres a second: pottering at home, creeping after someone unwatched,
## running home with what it took (with a heavy thing, `flee_heavy`), running
## out with the rope.
@export var home_speed := 0.8
@export var stalk_speed := 3.4
@export var flee_speed := 4.8
@export var flee_heavy := 4.3
@export var rope_speed := 5.2
## How far from its hollow a gnome will go after anyone, metres.
@export var territory := 38.0
## How far off a looker freezes it, metres; and how wide their look is (the
## cosine of half of it, about the way they face).
@export var watch_range := 48.0
@export var facing_cone := 0.4
## How near behind someone it comes to snatch, and how near its hands must be
## on them when they close.
@export var snatch_from := 0.8
@export var snatch_reach := 1.15
## How near a fleeing gnome someone must come to catch it.
@export var catch_reach := 0.9
## Seconds in the hollow after it gets home (or runs from something).
@export var hide_time := 14.0
## The rope: how far down the passages from the hollow someone running at it
## is noticed, how long it is held, how high it is, how fast someone must be
## going to trip on it, and how long before the band does it again.
@export var rope_range := 34.0
@export var rope_time := 3.5
@export var rope_height := 0.2
@export var trip_speed := 2.8
@export var rope_every := 14.0
@export var gravity := 20.0
## Further than this from every player it is not posed.
@export var pose_range := 55.0

var mode := Mode.HOME
var body: Gnome
## The band it is one of (shared by all of them).
var band: Band
## The number (Loot) of what it has taken and carries, or -1.
var carrying := -1
## Whether it is held still by being looked at.
var frozen := false
## In its hollow: out of everyone's reach (Ecology passes over it).
var escaped := false

var _yaw := 0.0
var _spawn := Vector3.ZERO
var _home_spot := Vector3.ZERO
var _home_in := 0.0
var _mode_time := 0.0
var _whisper_in := 4.0
var _snatches := 0
var _giggles := 0
var _squeals := 0
var _stole := false
var _victim_at := Vector3.INF
var _rope_end := Vector3.ZERO
var _tripped := {}
var _gather := 0.0
var _far := false
var _far_check := 0.0
var _world: Node
var _heard_flags := -1
var _watch_in := 0.0
var _watched := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO


## What a band shares: its hollow and its members, and its rope.
class Band:
	extends RefCounted
	var members: Array = []
	var hollow: GnomeHollow
	var rope: GnomeRope
	var rope_in := 0.0
	var hoard := 0


## A band of `count` gnomes (put them round one cell: the first finds the
## nearest wall and makes the hollow at its foot).
static func band_of(count := 4) -> Array[MazeGnome]:
	var shared := Band.new()
	var made: Array[MazeGnome] = []
	for k in count:
		var one := MazeGnome.new()
		one.band = shared
		shared.members.append(one)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 34.0
	hear_range = 10.0
	memory = 10.0
	alert_range = 30.0
	pack = &"gnomes"
	spare_time = 6.0
	climbs = Climbs.CLAMBER
	climb_speed = 2.0
	fears_fire = true


func _ready() -> void:
	if band == null:
		band = Band.new()
		band.members.append(self)
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.15
	shape.height = 0.5
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.25
	add_child(collider)
	body = Gnome.new()
	body.seed_value = _rng.randi()
	body.size = _rng.randf_range(0.37, 0.44)
	body.force_low = Settings.low_poly or Mummy.low_poly
	body.still = _rng.randi_range(0, 3) as Gnome.Still
	add_child(body)
	body.top_level = true
	_spawn = global_position
	_home_spot = _spawn
	_yaw = rotation.y
	rotation.y = 0.0
	_prev_pos = global_position
	_curr_pos = global_position
	_whisper_in = _rng.randf_range(3.0, 7.0)
	_world = _find_world()
	if Ecology.current:
		Ecology.current.killed.connect(_on_killed)
	var net := _net()
	if net and not net.is_connected(&"packet", _on_packet):
		net.connect(&"packet", _on_packet)
	_place.call_deferred()


func _find_world() -> Node:
	var at := get_parent()
	while at:
		if at.get_script() and (at.get_script() as Script).get_global_name() == &"World":
			return at
		at = at.get_parent()
	return null


## The first of the band makes the hollow, at the foot of the wall nearest
## where it was put; each then has a spot of its own before the door.
func _place() -> void:
	if not is_inside_tree():
		return
	if band.hollow == null and band.members.find(self) == 0 or (band.hollow == null and band.members.size() == 1):
		_make_hollow()
	if band.hollow:
		var k := band.members.find(self)
		var round_about := 0.6 + k * 1.1
		var out := band.hollow.global_basis.z
		var across := band.hollow.global_basis.x
		_home_spot = band.hollow.mouth() + out * (0.6 + 0.5 * absf(sin(round_about))) + across * cos(round_about) * 0.9
		_home_spot.y = maze.ground_height(_home_spot) if maze else _home_spot.y
		global_position = _home_spot
		_yaw = atan2(out.x, out.z) + _rng.randf_range(-0.6, 0.6)
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), global_position)
	body.settle()


func _make_hollow() -> void:
	var middle := _spawn + Vector3.UP * 0.4
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	var normal := Vector3.BACK
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, middle + way * Maze.CELL, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var point: Vector3 = hit["position"]
		if best == Vector3.INF or middle.distance_to(point) < middle.distance_to(best):
			best = point
			normal = hit["normal"]
	if best == Vector3.INF:
		best = _spawn
	normal.y = 0.0
	normal = normal.normalized() if normal.length() > 0.1 else Vector3.BACK
	var foot := Vector3(best.x, maze.ground_height(best) if maze else _spawn.y, best.z)
	var hollow := GnomeHollow.new()
	hollow.name = "GnomeHollow"
	hollow.seed_value = _rng.randi()
	get_parent().add_child(hollow)
	hollow.global_transform = Transform3D(Basis(normal.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, normal), foot)
	band.hollow = hollow
	band.rope = GnomeRope.new()
	band.rope.name = "GnomeRope"
	get_parent().add_child(band.rope)
	band.rope.visible = false


func _exit_tree() -> void:
	if band and band.members.find(self) == 0:
		for thing: Node in [band.hollow, band.rope]:
			if is_instance_valid(thing):
				thing.queue_free()


# --- Its world (Loot and the room) ---

## Loot (untyped: it and the room, Net, are not there for a test run with -s).
func _loot() -> Node:
	return _world.get(&"loot") as Node if _world else null


## The room (Net), if there is one.
func _net() -> Node:
	return get_node_or_null(^"/root/Net")


func _send(message: Dictionary) -> void:
	var net := _net()
	if net:
		net.call(&"send_json", 255, message)


## Its number among everything that hunts (the same on every machine), or -1.
func _index() -> int:
	if _world == null or _world.get(&"enemies") == null:
		return -1
	return (_world.get(&"enemies") as MazeEnemies).enemies.find(self)


func _online() -> bool:
	return _world != null and _world.get(&"online") == true


## The seat `player` plays in (this machine's player, or a friend), or -1.
func _seat_of(player: Node3D) -> int:
	if _world == null:
		return -1
	if player == _world.get(&"player"):
		return int(_world.get(&"slot"))
	if player is RemotePlayer:
		return (player as RemotePlayer).slot
	return -1


## What `player` has in their pockets (not in their hand), by number.
func pocketed(player: Node3D) -> Array[int]:
	var found: Array[int] = []
	var loot = _loot()
	var seat := _seat_of(player)
	if loot == null or seat < 0:
		return found
	for id: int in loot.owners:
		if int(loot.owners[id]) != seat:
			continue
		var item: Node3D = loot._item(id)
		if item and item.get(&"loot_state") == LootItem.State.POCKET and id != (loot.hand if seat == int(_world.get(&"slot")) else -9):
			found.append(id)
	return found


# --- Watched ---

## Whether anyone in sight is looking its way (then it does not move): within
## `facing_cone` of the way they face (the boy's own look, the same for every
## player and on every machine: what creeps up behind him he does not see,
## though whoever plays him may), within `watch_range`, nothing in between.
func watched() -> bool:
	var head := global_position + Vector3.UP * 0.45
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true or player.get(&"is_limp") == true:
			continue
		var yaw: Variant = player.get(&"facing_yaw")
		if yaw == null:
			continue
		var eye := player.global_position + Vector3.UP * 1.3
		var to := head - eye
		if to.length() > watch_range:
			continue
		var flat_to := Vector3(to.x, 0.0, to.z)
		if flat_to.length() > 0.5 and Vector3(sin(yaw), 0.0, cos(yaw)).dot(flat_to.normalized()) < facing_cone:
			continue
		# (a ray against the walls themselves: one stood at a wall's foot is still in sight)
		var ray := PhysicsRayQueryParameters3D.create(eye, head, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		return true
	return false


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_puppet_snatch()
		_trip_local()
		return
	if maze == null:
		return
	_sense(delta)
	_mode_time += delta
	_gather -= delta
	band.rope_in -= delta
	var still_ok := mode in [Mode.HOME, Mode.STALK, Mode.RETURN, Mode.SNATCH]
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = 0.1
		_watched = watched()
	frozen = still_ok and _watched
	var after := _target()
	chasing = mode in [Mode.STALK, Mode.SNATCH]
	# Up after them onto a ledge, unwatched (seen, stock still where it is, even on the wall).
	if climbing_now() or (mode == Mode.STALK and after):
		if climbing_now() and _watched:
			frozen = true
			velocity = Vector3.ZERO
			_prev_pos = _curr_pos
			_curr_pos = global_position
			return
		if not _watched and _ways_up(delta, 0.2, stalk_speed):
			_yaw = aloft_yaw()
			_prev_pos = _curr_pos
			_curr_pos = global_position
			return
	var wish := Vector3.ZERO
	var speed := 0.0
	if threat and mode not in [Mode.HIDE, Mode.FLEE]:
		_go_home_now()
	match mode:
		Mode.HOME:
			if band.members.find(self) == 0:
				_plan_rope()
			if after and not frozen:
				mode = Mode.STALK
				_mode_time = 0.0
				_giggle()
			else:
				_home_in -= delta
				var to := _home_spot - global_position
				to.y = 0.0
				if _home_in <= 0.0:
					_home_in = _rng.randf_range(3.0, 8.0)
					var out := band.hollow.global_basis.z if band.hollow else Vector3.BACK
					_home_spot = (band.hollow.mouth() if band.hollow else _spawn) + out * _rng.randf_range(0.6, 2.2) + out.cross(Vector3.UP) * _rng.randf_range(-1.6, 1.6)
				if to.length() > 0.3:
					wish = to.normalized()
					speed = home_speed
		Mode.STALK:
			if after == null:
				mode = Mode.RETURN
			else:
				var aim := _behind(after)
				var to := aim - global_position
				to.y = 0.0
				var flat := after.global_position - global_position
				flat.y = 0.0
				if flat.length() < snatch_from + 0.35 and _gather <= 0.0 and not frozen:
					_begin_snatch(after)
				else:
					wish = _route(aim)
					speed = stalk_speed
					_whisper_in -= delta
					if _whisper_in <= 0.0 and not frozen:
						_whisper_in = _rng.randf_range(4.0, 8.0)
						body.whisper()
		Mode.SNATCH:
			if frozen:
				# (turned on in the middle of it: foiled, and stock still)
				mode = Mode.STALK
				_mode_time = 0.0
				_gather = 1.0
			else:
				_snatching(delta)
		Mode.FLEE:
			_fleeing(delta)
			wish = _route(_mouth())
			speed = _flee_pace()
		Mode.CAUGHT:
			if _mode_time > 0.9:
				body.tumbling = false
				mode = Mode.RETURN
				_mode_time = 0.0
		Mode.HIDE:
			if _mode_time > hide_time and threat == null:
				escaped = false
				visible = true
				collision_layer = PUPPET_LAYER if puppet else 4
				mode = Mode.HOME
				_mode_time = 0.0
		Mode.ROPE_RUN:
			var to := _rope_end - global_position
			to.y = 0.0
			if to.length() < 0.35:
				global_position.x = _rope_end.x
				global_position.z = _rope_end.z
				if _partner() and _partner().mode in [Mode.ROPE_RUN, Mode.ROPE] and Vector2(_partner()._rope_end.x - _partner().global_position.x, _partner()._rope_end.z - _partner().global_position.z).length() < 0.4:
					for one: MazeGnome in [self, _partner()]:
						one.mode = Mode.ROPE
						one._mode_time = 0.0
						one._giggle()
			else:
				wish = _route(_rope_end)
				speed = rope_speed
			if _mode_time > 7.0:
				_drop_rope()
		Mode.ROPE:
			var partner := _partner()
			if partner == null or partner.mode != Mode.ROPE or _mode_time > rope_time:
				_drop_rope()
			else:
				# (facing the one at the other end, leaning back on it)
				var across := partner.global_position - global_position
				_yaw = lerp_angle(_yaw, atan2(across.x, across.z), 1.0 - exp(-10.0 * delta))
		Mode.RETURN:
			var to := _mouth() - global_position
			to.y = 0.0
			if after and not frozen and _mode_time > 2.0:
				mode = Mode.STALK
				_mode_time = 0.0
			elif to.length() < 1.6:
				mode = Mode.HOME
				_mode_time = 0.0
			else:
				wish = _route(_mouth())
				speed = stalk_speed * 0.8
	if frozen:
		wish = Vector3.ZERO
		speed = 0.0
	_move(wish, speed, delta)
	_trip_local()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whom it climbs up after: whom it stalks (see `_target`).
func _climb_after() -> Node3D:
	return _target() if mode == Mode.STALK else null


## Up there behind them: the snatch, as on the floor (it is its own again, on the
## ledge: running home with it, it drops off the edge).
func _strike_aloft(player: Node3D) -> void:
	_let_go_climb()
	_begin_snatch(player)


## Whom it goes after: the one it noticed, if they have something in their
## pockets and are in its territory.
func _target() -> Node3D:
	if not hunting() or quarry is MazeEnemy:
		return null
	if mode in [Mode.FLEE, Mode.HIDE, Mode.CAUGHT]:
		return null
	var home := _mouth()
	if Vector2(quarry.global_position.x - home.x, quarry.global_position.z - home.z).length() > territory:
		return null
	if pocketed(quarry).is_empty():
		return null
	return quarry


## A spot just behind `player`, out of the way they face.
func _behind(player: Node3D) -> Vector3:
	var yaw: Variant = player.get(&"facing_yaw")
	var back := Vector3(sin(yaw), 0.0, cos(yaw)) * -1.0 if yaw != null else (global_position - player.global_position).normalized()
	return player.global_position + back * snatch_from * 0.8


func _mouth() -> Vector3:
	return band.hollow.mouth() if band and band.hollow else _spawn


func _flee_pace() -> float:
	var loot = _loot()
	var item: Node3D = loot._item(carrying) if loot and carrying >= 0 else null
	if item and item.get(&"kind") in [LootItem.Kind.SPEAR, LootItem.Kind.HOOK, LootItem.Kind.LADDER]:
		return flee_heavy
	return flee_speed


## The way on to `aim` through the passages, flat.
func _route(aim: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, aim, MazeNav.clearance_for(0.2)) - global_position
	# (near, and nothing in the way at its height: straight there, right up to a wall's foot,
	# where the way through the passages keeps further off)
	var direct := aim - global_position
	direct.y = 0.0
	if direct.length() < 9.0 and is_inside_tree():
		var knee := Vector3.UP * 0.3
		if get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + knee, aim + knee, 1)).is_empty():
			to = direct
	to.y = 0.0
	var push := _apart(0.25)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	if push != Vector3.ZERO:
		wish = (wish + push * 0.6).normalized()
	return wish


func _move(wish: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.move_toward(wish * speed, (40.0 if not frozen else 400.0) * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	if mode == Mode.HIDE:
		velocity = Vector3.ZERO
		return
	move_and_slide()
	if flat.length() > 0.3:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.z), 1.0 - exp(-14.0 * delta))


# --- The snatch ---

func _begin_snatch(player: Node3D) -> void:
	mode = Mode.SNATCH
	_mode_time = 0.0
	_stole = false
	_snatches += 1
	_victim_at = player.global_position
	var to := player.global_position - global_position
	_yaw = atan2(to.x, to.z)
	body.snatch()


func _snatching(_delta: float) -> void:
	var victim := quarry
	if victim and is_instance_valid(victim):
		_victim_at = victim.global_position
	# At the end of the reach, if it is whoever plays here, it is done here.
	if not _stole and _mode_time >= Gnome.SNATCH_TIME * 0.55:
		_stole = true
		var mine: Node3D = _world.get(&"player") if _world else null
		if victim and victim == mine and _flat_to(victim) < snatch_reach:
			var id := _steal_from_local()
			if id >= 0:
				_got(id)
				return
	# (a friend's own game takes it, and tells us: see _on_packet; or it missed)
	if _mode_time > Gnome.SNATCH_TIME + 0.6:
		mode = Mode.STALK if quarry else Mode.RETURN
		_mode_time = 0.0
		_gather = 1.5


func _flat_to(player: Node3D) -> float:
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


## Takes one thing from this machine's player's pockets (not his hand), says
## so, and tells the room. Its number, or -1 if he had nothing.
func _steal_from_local() -> int:
	var loot = _loot()
	if loot == null:
		return -1
	var choices: Array[int] = []
	for i in loot.slots.size():
		if loot.slots[i] >= 0 and loot.slots[i] != loot.hand:
			choices.append(loot.slots[i])
	if choices.is_empty():
		return -1
	var id: int = choices[_rng.randi_range(0, choices.size() - 1)]
	loot.slots[loot.slots.find(id)] = -1
	loot.owners[id] = -1
	var item: Node3D = loot._item(id)
	loot.changed.emit()
	loot.said.emit("A GNOME HAS TAKEN YOUR %s" % LootItem.SHORT.get(item.get(&"kind") if item else 0, "THING"))
	if _online():
		_send({"folk": "gnome_stole", "enemy": _index(), "id": id})
	return id


## It has `id`: off home with it.
func _got(id: int) -> void:
	carrying = id
	var loot = _loot()
	if loot:
		loot.owners[id] = -1
	if not puppet:
		mode = Mode.FLEE
		_mode_time = 0.0
		frozen = false
		_giggle()


func _fleeing(_delta: float) -> void:
	# Caught: anyone who comes up to it.
	for player: Node3D in players():
		if not is_instance_valid(player) or player is MazeRunner or player.get(&"escaped") == true:
			continue
		if _flat_to(player) < catch_reach and absf(player.global_position.y - global_position.y) < 1.4:
			_caught_by(player)
			return
	var home := _mouth()
	if Vector2(home.x - global_position.x, home.z - global_position.z).length() < 0.5:
		# Home: it lays what it took by its door and goes in.
		if band.hollow and carrying >= 0:
			_put_down(band.hollow.hoard_spot(band.hoard), Vector3.ZERO)
			band.hoard += 1
		_hide()


func _caught_by(player: Node3D) -> void:
	var away := global_position - player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	if carrying >= 0:
		_put_down(global_position + Vector3.UP * 0.4 + away * 0.2, away * 1.5 + Vector3.UP * 2.0)
	mode = Mode.CAUGHT
	_mode_time = 0.0
	_squeals += 1
	body.squeal()
	body.tumbling = true
	velocity = away * 2.5
	_yaw = atan2(-away.x, -away.z)


## Lets go of what it carries at `at`, falling with `going`; for everyone.
func _put_down(at: Vector3, going: Vector3) -> void:
	var loot = _loot()
	var id := carrying
	carrying = -1
	if loot == null:
		return
	var item: Node3D = loot._item(id)
	if item == null:
		return
	loot._put_down(item, at, going)
	if _online():
		_send({"loot": "drop", "id": id, "kind": item.get(&"kind"), "seat": -1,
			"at": [at.x, at.y, at.z], "vel": [going.x, going.y, going.z], "lit": false, "fuel": item.get(&"fuel")})


## Into the hollow: out of sight and reach for `hide_time`.
func _hide() -> void:
	mode = Mode.HIDE
	_mode_time = 0.0
	escaped = true
	visible = false
	collision_layer = 0
	quarry = null
	_forget = 0.0
	global_position = _mouth()


func _go_home_now() -> void:
	if carrying >= 0:
		_put_down(global_position + Vector3.UP * 0.4, Vector3.UP)
	if mode in [Mode.ROPE, Mode.ROPE_RUN]:
		_drop_rope()
	if Vector2(_mouth().x - global_position.x, _mouth().z - global_position.z).length() < 1.0:
		_hide()
	else:
		mode = Mode.FLEE
		_mode_time = 0.0


## Killed while carrying something (Ecology): it falls where it died.
func _on_killed(prey: MazeEnemy, _hunter: MazeEnemy) -> void:
	if prey == self and carrying >= 0:
		_put_down(global_position + Vector3.UP * 0.3, Vector3.ZERO)


func _giggle() -> void:
	_giggles += 1
	body.giggle()


# --- The rope ---

## (The first of the band, at home.) Someone running down at the hollow, and
## two of the band run out with the rope across the hall in front of them.
func _plan_rope() -> void:
	if band.rope_in > 0.0 or band.hollow == null:
		return
	var free: Array = band.members.filter(func(one: MazeGnome) -> bool: return is_instance_valid(one) and not one.dead and one.mode == Mode.HOME and one.carrying < 0)
	if free.size() < 2:
		return
	var home := _mouth()
	var home_cell := maze.cell_at(home)
	for player: Node3D in players():
		if not is_instance_valid(player) or player is MazeRunner or not huntable(player):
			continue
		var going: Variant = player.get(&"velocity")
		if not (going is Vector3):
			continue
		var flat := Vector3((going as Vector3).x, 0.0, (going as Vector3).z)
		var to_home := home - player.global_position
		to_home.y = 0.0
		if flat.length() < 3.6 or to_home.length() > rope_range or to_home.length() < 6.0:
			continue
		var door_out := home + band.hollow.global_basis.z * 2.0
		if flat.normalized().dot(to_home.normalized()) < 0.6 or not nav.sees(player.global_position + Vector3.UP, door_out + Vector3.UP, rope_range):
			continue
		# Across the hall, partway between him and the door, ahead of him.
		var cross_at := home - to_home.normalized() * minf(to_home.length() * 0.45, 9.0)
		var across := Vector3(-to_home.z, 0.0, to_home.x).normalized()
		var ends := _wall_to_wall(cross_at, across)
		if ends.is_empty():
			return
		var pair: Array = [free[0], free[1]]
		# (the nearer of each pair takes the nearer end)
		if (pair[0] as MazeGnome).global_position.distance_to(ends[0]) > (pair[0] as MazeGnome).global_position.distance_to(ends[1]):
			ends.reverse()
		for k in 2:
			var one: MazeGnome = pair[k]
			one.mode = Mode.ROPE_RUN
			one._mode_time = 0.0
			one._rope_end = ends[k]
		band.rope_in = rope_every
		return


## Two points across the hall at `at` along `across`, a little off each wall.
func _wall_to_wall(at: Vector3, across: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var from := Vector3(at.x, maze.ground_height(at) + 0.3, at.z)
	var ends := []
	for side: float in [1.0, -1.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + across * side * 14.0, 1))
		# (no wall that side within reach: as far as the rope goes)
		var end: Vector3 = (hit["position"] as Vector3) - across * side * 0.3 if not hit.is_empty() else from + across * side * 13.0
		end.y = maze.ground_height(end)
		ends.append(end)
	return ends


func _partner() -> MazeGnome:
	for one: MazeGnome in band.members:
		if one != self and is_instance_valid(one) and one.mode in [Mode.ROPE_RUN, Mode.ROPE]:
			return one
	return null


func _drop_rope() -> void:
	for one: MazeGnome in [self, _partner()]:
		if one and one.mode in [Mode.ROPE_RUN, Mode.ROPE]:
			one.mode = Mode.RETURN
			one._mode_time = 0.0


## The rope taut between the two holding it: its two ends (world), or empty.
func rope_ends() -> Array:
	if mode != Mode.ROPE:
		return []
	var partner := _partner()
	if partner == null or partner.mode != Mode.ROPE:
		return []
	var lift := Vector3.UP * rope_height
	return [Vector3(global_position.x, global_position.y, global_position.z) + lift, partner.global_position + lift]


## This machine's player runs into a taut rope (on the ground, going fast across
## it): he trips, and goes sprawling. Once a rope.
func _trip_local() -> void:
	var partner := _partner()
	if partner and band.members.find(partner) < band.members.find(self):
		return
	var ends := rope_ends()
	if ends.is_empty():
		_tripped.clear()
		return
	var mine: Variant = _world.get(&"player") if _world else local_player()
	if not (mine is Player):
		return
	var boy := mine as Player
	if _tripped.has(boy) or not boy.is_on_floor() or boy.is_limp:
		return
	var flat := Vector2(boy.velocity.x, boy.velocity.z)
	if flat.length() < trip_speed:
		return
	var a := Vector2(ends[0].x, ends[0].z)
	var b := Vector2(ends[1].x, ends[1].z)
	var feet := Vector2(boy.global_position.x, boy.global_position.z)
	var near := Geometry2D.get_closest_point_to_segment(feet, a, b)
	if near.distance_to(feet) > 0.3 or absf(boy.global_position.y - (ends[0] as Vector3).y) > 0.6:
		return
	var along := (b - a).normalized()
	var across := Vector2(-along.y, along.x)
	if absf(flat.normalized().dot(across)) < 0.35:
		return
	_tripped[boy] = true
	trip(boy)


## Sends `boy` sprawling, as a hard landing does.
static func trip(boy: Player) -> void:
	boy._take_landing(12.2)


# --- Being run by someone else ---

## As a puppet: when it snatches, whoever plays here may be who it took from.
func _puppet_snatch() -> void:
	if mode != Mode.SNATCH or _stole:
		return
	_mode_time += get_physics_process_delta_time()
	if _mode_time < Gnome.SNATCH_TIME * 0.55:
		return
	_stole = true
	var mine: Variant = _world.get(&"player") if _world else null
	if not (mine is Player):
		return
	var boy := mine as Player
	if _heard_extra.is_finite() and Vector2(_heard_extra.x - boy.global_position.x, _heard_extra.z - boy.global_position.z).length() < 2.5 and _flat_to(boy) < snatch_reach + 0.5:
		var id := _steal_from_local()
		if id >= 0:
			carrying = id


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if kind != 74 or _world == null:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not (message is Dictionary) or str(message.get("folk", "")) != "gnome_stole" or int(message.get("enemy", -2)) != _index():
		return
	if _net().get(&"is_host") == true and from != int(_world.get(&"slot")):
		_send(message)
	var id := int(message.get("id", -1))
	if id < 0 or id == carrying:
		return
	_got(id)


func yaw() -> float:
	return _yaw


func net_state() -> int:
	return mode


## Frozen (bit 7), and counts of its snatches (three bits), giggles (two) and squeals (two).
func net_flag() -> int:
	return (_snatches & 0x07) | ((_giggles & 0x03) << 3) | ((_squeals & 0x03) << 5) | (0x80 if frozen else 0)


## Snatching, where whoever it snatches at is; else none.
func net_point() -> Vector3:
	if mode == Mode.SNATCH and _victim_at.is_finite():
		return _victim_at
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	frozen = (flag & 0x80) != 0
	chasing = mode in [Mode.STALK, Mode.SNATCH]
	if mode != was:
		_mode_time = 0.0
		if mode == Mode.SNATCH:
			_stole = false
		if mode == Mode.HIDE:
			visible = false
			escaped = true
		elif was == Mode.HIDE:
			visible = true
			escaped = false
		if body:
			body.tumbling = mode == Mode.CAUGHT
	if _heard_flags >= 0 and body:
		if (flag & 0x07) != (_heard_flags & 0x07):
			body.snatch()
		if ((flag >> 3) & 0x03) != ((_heard_flags >> 3) & 0x03):
			body.giggle()
		if ((flag >> 5) & 0x03) != ((_heard_flags >> 5) & 0x03):
			body.squeal()
	_heard_flags = flag
	_yaw = facing


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1


## It keeps to its hollow: when it is after nobody it goes home (and out of
## everyone's sight, it stays there, as `roam_unseen` follows this).
func goal() -> Vector3:
	if threat and is_instance_valid(threat) and not threat.dead:
		return _mouth()
	if hunting() and _target():
		return _behind(quarry)
	return _home_spot


# --- Drawing it ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			body.visible = not far
			body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	_draw_rope()
	if _far:
		return
	body.visible = mode != Mode.HIDE and visible
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	body.frozen = frozen and mode != Mode.CAUGHT
	body.creeping = mode == Mode.STALK
	body.carrying = carrying >= 0
	body.hauling = mode == Mode.ROPE
	body.tumbling = mode == Mode.CAUGHT
	var near_player := nearest_player(global_position)
	body.pattering = not frozen and near_player != null and near_player.global_position.distance_to(global_position) < 14.0 and mode in [Mode.STALK, Mode.FLEE, Mode.ROPE_RUN, Mode.RETURN]
	if body.frozen:
		return
	if mode in [Mode.STALK, Mode.SNATCH] and near_player:
		body.look_at_point = near_player.global_position + Vector3.UP * 1.2
	elif mode == Mode.ROPE and _partner():
		body.look_at_point = _partner().global_position + Vector3.UP * 0.3
	else:
		body.look_at_point = Vector3.INF
	var lean := aloft_tilt(true)
	if mode == Mode.CAUGHT:
		lean = Basis(Vector3.RIGHT, -1.3 * smoothstep(0.0, 0.25, _mode_time) * (1.0 - smoothstep(0.65, 0.9, _mode_time)))
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw) * lean, at)
	_show_carried()


## What it carries, held to its chest (it is still in its pocket for Loot: only shown).
func _show_carried() -> void:
	if carrying < 0:
		return
	var loot = _loot()
	var item: Node3D = loot._item(carrying) if loot else null
	if item == null or item.get(&"loot_state") != LootItem.State.POCKET:
		# (dropped, or laid down: no longer its)
		carrying = -1
		return
	item.visible = true
	var turn := Basis(Vector3.UP, _yaw) * Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, 0.2)
	item.global_transform = Transform3D(turn, body.carry_point() - turn.y * 0.05)


## The band's rope: taut between the two holding it, slack on the ground as they run out.
func _draw_rope() -> void:
	if band == null or band.rope == null or band.members.find(self) != 0:
		return
	var holders: Array = band.members.filter(func(one: MazeGnome) -> bool: return is_instance_valid(one) and one.mode in [Mode.ROPE_RUN, Mode.ROPE])
	if holders.size() < 2:
		band.rope.visible = false
		return
	var a: MazeGnome = holders[0]
	var b: MazeGnome = holders[1]
	band.rope.visible = true
	if a.mode == Mode.ROPE and b.mode == Mode.ROPE:
		band.rope.set_ends(a.body.rope_point(), b.body.rope_point(), 0.03)
	else:
		var lift := Vector3.UP * 0.03
		band.rope.set_ends(a.global_position + lift, b.global_position + lift, -0.0)
