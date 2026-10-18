class_name Insects
extends Node3D
## The small things that fly about the maze and the clearing (InsectSwarm,
## creatures/insects/): atmosphere, and here and there a warning. None of them
## hunts or catches anyone, none is among MazeEnemies or in `pursuers`, and
## nothing about them is sent over the network: each machine makes its own from
## the round's seed, disturbed by the same players, so they agree well enough.
##
## - MOTHS round every light: anything in the group `moth_lights` (a Node3D;
##   its meta `moth_radius`, how far out they flutter, `moth_height`, how high
##   over it the light is, and `moth_count` a share more or fewer). The angel's
##   heart, the pale light past the exit and every fire (GameCommon's Fire,
##   when one is put in: it joins by itself) are put in it here. Pale, dusty,
##   erratic, a few resting on the wall by the light that scatter as someone
##   comes. And big ones (luna and death's-head moths among them) resting on
##   the walls of the halls with their wings spread, that scatter as you pass
##   (MazeStyle, "Wildlife": wall_moths); and clouds of them out over the
##   clearing's grass in the evening and through the night (ClearingStyle,
##   "Wildlife": dusk_moth_clouds).
## - FLIES round everything of meat and rot: anything in the group
##   `fly_carrion` (meta `carrion_radius`, `carrion_height`): the flesh mounds,
##   the meat beast, the slime wall, carcasses lying in dead ends (MazeStyle:
##   carcasses), the boar's lair (a carcass he has been at); and, for a while,
##   wherever someone was caught. They buzz (a sound made in code): flies mean
##   something dead or something of meat is near. Stand still among them long
##   enough and a few land on you.
## - DRAGONFLIES over the marsh (ClearingStyle: marsh_dragonflies), in patches
##   along its pools, darting and hovering, perching on the bulrushes' tips.
## - FIREFLIES at dusk and through the night (FireflyField, creatures/fireflies/:
##   one field for them all): clouds of them rise from the clearing's tall grass,
##   the woods (up into the boughs), the marsh's pools and the meadow
##   (ClearingStyle: firefly_clouds), and in the first ring from the foot of the
##   ivy and the ferns and moss at the walls' feet (MazeStyle: firefly_patches);
##   each kind blinks in its own rhythm, one kind all together in waves; they
##   scatter from anyone running through them and drift back. They come out as
##   the light goes (DayCycle.daylight: `firefly_night`).
##
## How many: MazeStyle "Wildlife" (moths_per_light, wall_moths,
## flies_per_carrion, carcasses, firefly_patches) and ClearingStyle "Wildlife"
## (marsh_dragonflies, dusk_moth_clouds, firefly_clouds). Each swarm is drawn and
## moved only near the camera (InsectSwarm.active_range), so a round's many swarms
## cost only the few in view; the fireflies are moved in their shader, and only
## those near the camera are drawn.

const LIGHTS := &"moth_lights"
const CARRION := &"fly_carrion"
## How often what is in the groups (and what hunts the maze) is looked at again, seconds.
const SCAN_EVERY := 1.0
## How long flies stay where someone was caught, seconds.
const CAUGHT_TIME := 45.0
## Nearer the camera than this, a wall moth's place on the wall is found (a ray).
const PLACE_RANGE := 70.0
## The carcass's colours (hide, belly, meat, bone, hooves).
const CARCASS_COLOURS := {"hide": Color(0.2, 0.15, 0.11), "hide_pale": Color(0.36, 0.31, 0.25), "flesh": Color(0.34, 0.08, 0.07), "bone": Color(0.6, 0.56, 0.48), "hoof": Color(0.06, 0.05, 0.04)}

var maze: Maze
## The round (World), if there is one: its players, what hunts, the hour, the marsh.
var world: Node
var seed_value := 0

## The swarms, by what they are round.
var moths := {}
var flies := {}
var dragonflies: Array[InsectSwarm] = []
var wall_moths: Array[InsectSwarm] = []
var dusk_moths: Array[InsectSwarm] = []
var carcasses: Array[Node3D] = []
## Flies where someone was caught: [swarm, seconds left].
var caught_flies: Array = []
## The fireflies, all of them; and whether they are out whatever the hour (the dev panel's).
var fireflies: FireflyField
var fireflies_out := false

var _rng := RandomNumberGenerator.new()
var _scan := 0.0
var _player_at := Vector3.INF
var _boars := {}
var _unplaced: Array[InsectSwarm] = []


## Puts in everything a round has, from `seed_number`: the carcasses, the wall
## moths, the marsh's dragonflies, the clouds over the clearing, and moths for
## the lights there are; the rest come as they are found (`_scan`).
func populate(plan: Maze, seed_number: int, round_world: Node = null) -> void:
	maze = plan
	world = round_world
	seed_value = seed_number
	_rng.seed = seed_number
	if is_inside_tree():
		get_tree().node_added.connect(_on_node_added)
	var nav := MazeNav.new(plan)
	var lairs := nav.lairs(3)
	var style: MazeStyle = plan.styles[0] if not plan.styles.is_empty() else MazeStyle.new()
	# Carcasses in dead ends, and big moths resting on the walls of halls.
	var ends: Array[Vector2i] = []
	var halls: Array[Vector2i] = []
	for cell in lairs:
		if plan.ring_of(cell) < 1 or plan.ring_of(cell) > plan.rings:
			continue
		if nav.dead_end(cell):
			ends.append(cell)
		else:
			halls.append(cell)
	for i in mini(style.carcasses, ends.size()):
		var cell: Vector2i = ends.pop_at(_rng.randi_range(0, ends.size() - 1))
		add_carcass(_dead_end_spot(nav, cell), _rng.randf() * TAU)
	for i in style.wall_moths:
		if halls.is_empty():
			break
		var cell: Vector2i = halls[_rng.randi_range(0, halls.size() - 1)]
		_add_wall_moths(nav.point(cell), _rng.randi())
	_marsh_dragonflies()
	_dusk_clouds()
	_fireflies()
	_join_lights()
	# (flies where anyone is caught: the host hears of every catch, a guest of its own)
	if world:
		if world.has_signal(&"caught"):
			world.connect(&"caught", on_player_caught)
		var hunters: Node = world.get(&"enemies")
		if hunters and hunters.has_signal(&"caught"):
			hunters.connect(&"caught", on_enemy_caught)
		var griever: Node3D = world.get(&"griever")
		if griever and griever.has_signal(&"caught"):
			griever.connect(&"caught", func(who: Node3D) -> void: on_enemy_caught(who, griever))
	_scan = 0.0


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# A fire put in anywhere draws moths (GameCommon's Fire, by its class).
func _on_node_added(node: Node) -> void:
	if node is Node3D and _is_fire(node):
		node.add_to_group(LIGHTS)


static func _is_fire(node: Node) -> bool:
	var script := node.get_script() as Script
	return script != null and script.get_global_name() == &"Fire"


# The lights there are now: the light past the exit, and any fires.
func _join_lights() -> void:
	if world == null:
		return
	var builder := world.get_node_or_null(^"Maze")
	var beacon: Node3D = builder.get(&"beacon") if builder else null
	if beacon and is_instance_valid(beacon):
		beacon.set_meta(&"moth_radius", 1.8)
		beacon.set_meta(&"moth_height", 1.6)
		beacon.add_to_group(LIGHTS)
	for node: Node in world.find_children("*", "Node3D", true, false):
		if _is_fire(node):
			node.add_to_group(LIGHTS)


# --- Each frame ---

func _process(delta: float) -> void:
	if maze == null:
		return
	if world and world.get(&"player") and is_instance_valid(world.get(&"player")):
		_player_at = (world.get(&"player") as Node3D).global_position
	if fireflies:
		fireflies.night = firefly_night()
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_EVERY
		_look_about()
	for k in range(caught_flies.size() - 1, -1, -1):
		var entry: Array = caught_flies[k]
		entry[1] -= delta
		var swarm: InsectSwarm = entry[0]
		# (at the end they drift off one way and another: the cloud thins and goes)
		if entry[1] < 6.0:
			swarm.radius = lerpf(swarm.radius, 6.0, delta * 0.4)
		if entry[1] <= 0.0:
			swarm.queue_free()
			caught_flies.remove_at(k)


func _look_about() -> void:
	var players := _players()
	_hunters()
	# Moths for every light, flies for everything of meat; gone with them.
	for node: Node in get_tree().get_nodes_in_group(LIGHTS):
		if node is Node3D and not moths.has(node.get_instance_id()):
			moths[node.get_instance_id()] = _moths_round(node as Node3D)
	for node: Node in get_tree().get_nodes_in_group(CARRION):
		if node is Node3D and not flies.has(node.get_instance_id()):
			flies[node.get_instance_id()] = _flies_round(node as Node3D)
	for table: Dictionary in [moths, flies]:
		for id: int in table.keys():
			var swarm: InsectSwarm = table[id]
			var over := instance_from_id(id) as Node3D
			if over == null or not is_instance_valid(over) or not over.is_inside_tree() or (over is MazeEnemy and over.get(&"visible") == false and over.process_mode == Node.PROCESS_MODE_DISABLED):
				swarm.queue_free()
				table.erase(id)
			elif table == flies and over.has_meta(&"carrion_radius"):
				swarm.radius = float(over.get_meta(&"carrion_radius"))
	# Everyone disturbs them; the clouds over the clearing are out only at dusk and by night.
	var dusk := _dusk()
	for swarm: InsectSwarm in _all():
		swarm.scarers = players
	for swarm in dusk_moths:
		swarm.active = dusk
	if fireflies:
		fireflies.scarers = players
	# Big moths on the walls find their place on the wall when someone first comes near.
	var camera := get_viewport().get_camera_3d()
	for k in range(_unplaced.size() - 1, -1, -1):
		var swarm := _unplaced[k]
		if camera and camera.global_position.distance_to(swarm.centre) < PLACE_RANGE:
			_unplaced.remove_at(k)
			_place_on_wall(swarm)


func _players() -> Array:
	var found: Array = get_tree().get_nodes_in_group(&"maze_players")
	return found.filter(func(p: Node) -> bool: return is_instance_valid(p) and p is Node3D)


## Every swarm there is now.
func _all() -> Array[InsectSwarm]:
	var all: Array[InsectSwarm] = []
	for swarm: InsectSwarm in moths.values():
		all.append(swarm)
	for swarm: InsectSwarm in flies.values():
		all.append(swarm)
	all.append_array(dragonflies)
	all.append_array(wall_moths)
	all.append_array(dusk_moths)
	for entry: Array in caught_flies:
		all.append(entry[0])
	return all


## How many swarms are drawn and moved now.
func running() -> int:
	var n := 0
	for swarm in _all():
		if is_instance_valid(swarm) and swarm.running():
			n += 1
	return n


# What hunts the maze, as it comes and goes: the angel is a light; the flesh
# mounds, the meat beast and the slime wall are meat; the boar has a carcass
# in his lair.
func _hunters() -> void:
	var hunters: Array = []
	if world and world.get(&"enemies"):
		hunters = (world.get(&"enemies") as MazeEnemies).enemies
	else:
		hunters = get_tree().get_nodes_in_group(&"maze_enemies")
	for enemy: Node in hunters:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy is MazeAngel:
			if not enemy.is_in_group(LIGHTS):
				var angel := enemy as MazeAngel
				enemy.set_meta(&"moth_radius", 4.2 * angel.size)
				enemy.set_meta(&"moth_height", angel.hover * angel.size)
				enemy.set_meta(&"moth_count", 1.7)
				enemy.add_to_group(LIGHTS)
		elif enemy is MazeFleshMound:
			var mound := enemy as MazeFleshMound
			enemy.set_meta(&"carrion_radius", mound.girth() * 0.9)
			enemy.set_meta(&"carrion_height", 0.9 * mound.size if mound.small() else mound.girth() * 0.6)
			enemy.add_to_group(CARRION)
		elif enemy is Abomination:
			enemy.set_meta(&"carrion_radius", 2.2)
			enemy.set_meta(&"carrion_height", 1.7)
			enemy.add_to_group(CARRION)
		elif enemy is MazeSlimeWall:
			enemy.set_meta(&"carrion_radius", 2.6)
			enemy.set_meta(&"carrion_height", 2.2)
			enemy.add_to_group(CARRION)
		elif enemy is MazeBoar and not _boars.has(enemy.get_instance_id()):
			# (where he roots: the bones of something he has been at)
			_boars[enemy.get_instance_id()] = true
			var at := (enemy as Node3D).global_position + Vector3((enemy as Node3D).global_basis.z.x, 0.0, (enemy as Node3D).global_basis.z.z).normalized() * -2.5
			add_carcass(at, _rng.randf() * TAU)


# --- Moths ---

## How many of a thing a ring's style wants where `point` is (the clearing: the first ring's).
func _style_at(point: Vector3) -> MazeStyle:
	if maze.styles.is_empty():
		return MazeStyle.new()
	var ring := clampi(maze.ring_of(maze.cell_at(point)), 1, maze.styles.size())
	return maze.styles[ring - 1]


func _scaled(n: float) -> int:
	return maxi(int(round(n * (0.6 if Settings.low_poly else 1.0))), 1)


func _moths_round(light: Node3D) -> InsectSwarm:
	var swarm := InsectSwarm.new()
	swarm.name = "Moths%d" % light.get_instance_id()
	swarm.kind = InsectLook.Kind.MOTH
	var size := float(light.get_meta(&"moth_radius", _fire_size(light) * 3.0 if _is_fire(light) else 1.2))
	var high := float(light.get_meta(&"moth_height", _fire_size(light) * 0.6 if _is_fire(light) else 0.0))
	swarm.count = _scaled(_style_at(light.global_position).moths_per_light * float(light.get_meta(&"moth_count", 1.0)))
	swarm.swarm_seed = hash("moths/%d/%s" % [seed_value, str(light.global_position.snapped(Vector3.ONE))])
	swarm.follow = light
	swarm.follow_offset = Vector3.UP * high
	swarm.radius = clampf(size, 0.6, 6.0)
	swarm.spread_height = Vector2(-0.45, 0.6) * swarm.radius
	swarm.speed = 1.2 + 0.25 * swarm.radius
	swarm.wingspan = Vector2(0.05, 0.085) if size < 3.0 else Vector2(0.08, 0.14)
	swarm.varieties = Vector3(1.0, 0.04, 0.04)
	swarm.rest_share = 0.25
	swarm.flap_rate = 11.0
	# (small things: past this they are a speck in the mist; the angel's, round its glow, further)
	swarm.active_range = 45.0 if size >= 3.0 else 32.0
	# (a light that stays where it is: some rest on the walls round it)
	if not light is MazeEnemy:
		swarm.perches = _walls_round(light.global_position + Vector3.UP * high, swarm.radius * 2.5)
	add_child(swarm)
	return swarm


## Places on the walls round `point` within `reach`, to rest on: a few on each
## face a ray finds, heads up.
func _walls_round(point: Vector3, reach: float) -> Array[Transform3D]:
	var places: Array[Transform3D] = []
	if not is_inside_tree():
		return places
	var space := get_world_3d().direct_space_state
	for k in 8:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + way * reach))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var normal: Vector3 = hit["normal"]
		var across := normal.cross(Vector3.UP).normalized()
		for j in 3:
			var at: Vector3 = hit["position"] + across * _rng.randf_range(-0.8, 0.8) + Vector3.UP * _rng.randf_range(-0.6, 0.9)
			places.append(Transform3D(InsectSwarm._basis_from(normal, Vector3.UP.rotated(normal, _rng.randf_range(-0.4, 0.4))), at))
	return places


func _fire_size(fire: Node) -> float:
	var size: Variant = fire.get(&"size")
	return float(size) if size != null else 0.5


## Big moths resting on a wall near `point`, wings spread (their places on the
## wall are found with a ray when someone first comes near: `_place_on_wall`).
func _add_wall_moths(point: Vector3, swarm_seed: int) -> InsectSwarm:
	var swarm := InsectSwarm.new()
	swarm.name = "WallMoths%d" % wall_moths.size()
	swarm.kind = InsectLook.Kind.MOTH
	var pick := RandomNumberGenerator.new()
	pick.seed = swarm_seed
	swarm.count = pick.randi_range(1, 3)
	swarm.swarm_seed = swarm_seed
	swarm.wingspan = Vector2(0.11, 0.16)
	swarm.varieties = Vector3(0.4, 0.3, 0.3)
	swarm.centre = point + Vector3.UP * 2.0
	swarm.radius = 1.6
	swarm.spread_height = Vector2(-0.8, 1.2)
	swarm.speed = 1.8
	swarm.flap_rate = 7.0
	swarm.rest_share = 1.0
	swarm.fly_time = Vector2(4.0, 8.0)
	swarm.rest_time = Vector2(40.0, 120.0)
	swarm.scare_range = 3.2
	swarm.active_range = 30.0
	swarm.active = false
	add_child(swarm)
	wall_moths.append(swarm)
	_unplaced.append(swarm)
	return swarm


# A wall moth swarm's places: the nearest wall face, a metre or three up it,
# side by side, heads up.
func _place_on_wall(swarm: InsectSwarm) -> void:
	var space := get_world_3d().direct_space_state
	var from := swarm.centre
	var best: Dictionary = {}
	for k in 8:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 14.0))
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.3:
			if best.is_empty() or from.distance_to(hit["position"]) < from.distance_to(best["position"]):
				best = hit
	if best.is_empty():
		swarm.queue_free()
		wall_moths.erase(swarm)
		return
	var normal: Vector3 = best["normal"]
	var spot: Vector3 = best["position"]
	var across := normal.cross(Vector3.UP).normalized()
	var places: Array[Transform3D] = []
	for i in swarm.count + 2:
		var at := spot + across * _rng.randf_range(-1.6, 1.6) + Vector3.UP * _rng.randf_range(-1.0, 1.4)
		var up_wall := Vector3.UP.rotated(normal, _rng.randf_range(-0.35, 0.35))
		places.append(Transform3D(InsectSwarm._basis_from(normal, up_wall), at))
	swarm.perches = places
	swarm.centre = spot + normal * 1.5
	swarm.active = true
	swarm.settle()


# Clouds of moths out over the grass at dusk, about the meadow.
func _dusk_clouds() -> void:
	var look := maze.clearing_style
	for i in look.dusk_moth_clouds:
		var spot := TameChickens.clearing_spot(maze, _rng, i == 0)
		if not spot.is_finite():
			continue
		var swarm := InsectSwarm.new()
		swarm.name = "DuskMoths%d" % i
		swarm.kind = InsectLook.Kind.MOTH
		swarm.count = _scaled(16)
		swarm.swarm_seed = _rng.randi()
		var at := Vector3(spot.x, 0.0, spot.y)
		swarm.centre = at + Vector3.UP * (maze.ground_height(at) + 1.3)
		swarm.radius = 3.0
		swarm.spread_height = Vector2(-0.8, 1.0)
		swarm.speed = 1.4
		swarm.varieties = Vector3(1.0, 0.08, 0.0)
		swarm.rest_share = 0.0
		swarm.active = _dusk()
		add_child(swarm)
		dusk_moths.append(swarm)


func _dusk() -> bool:
	var day: Node = world.get(&"day") if world else null
	if day == null:
		return false
	var hour := float(day.get(&"hour"))
	return hour >= DayCycle.SUNSET - 1.2 or hour < DayCycle.DAWN + 0.4


# --- Flies ---

func _flies_round(carrion: Node3D) -> InsectSwarm:
	var swarm := InsectSwarm.new()
	swarm.name = "Flies%d" % carrion.get_instance_id()
	swarm.kind = InsectLook.Kind.FLY
	var reach := float(carrion.get_meta(&"carrion_radius", 0.8))
	var high := float(carrion.get_meta(&"carrion_height", 0.5))
	swarm.count = _scaled(_style_at(carrion.global_position).flies_per_carrion * clampf(reach / 1.5, 1.0, 1.6))
	swarm.swarm_seed = hash("flies/%d/%s" % [seed_value, str(carrion.global_position.snapped(Vector3.ONE))])
	swarm.follow = carrion
	swarm.follow_offset = Vector3.UP * high * 0.5
	swarm.radius = reach
	swarm.spread_height = Vector2(-high * 0.4, high * 0.8 + 0.4)
	swarm.land_height = high * 0.5
	# (where on it they land: its own places, in its own space, if it has them)
	if carrion.has_meta(&"carrion_perches"):
		swarm.perches.assign(carrion.get_meta(&"carrion_perches"))
		swarm.perches_follow = true
	_fly_habits(swarm)
	add_child(swarm)
	return swarm


func _fly_habits(swarm: InsectSwarm) -> void:
	swarm.wingspan = Vector2(0.03, 0.04)
	swarm.speed = 3.2
	swarm.flap_rate = 40.0
	swarm.rest_share = 0.35
	swarm.fly_time = Vector2(1.5, 6.0)
	swarm.rest_time = Vector2(2.0, 9.0)
	swarm.scare_range = 1.6
	swarm.land_on_still = 4
	swarm.still_time = 3.0
	swarm.buzz = true
	swarm.active_range = 25.0


## A dead deer lying at `at`, turned `yaw`, under flies.
func add_carcass(at: Vector3, yaw: float) -> Node3D:
	var dead := InsectLook.carcass()
	dead.name = "Carcass%d" % carcasses.size()
	add_child(dead)
	Toon.apply(dead, CARCASS_COLOURS)
	at.y = maze.ground_height(at) if maze else at.y
	dead.global_position = at
	dead.rotation.y = yaw
	dead.set_meta(&"carrion_radius", 0.9)
	dead.set_meta(&"carrion_height", 0.55)
	dead.set_meta(&"carrion_perches", _upper_faces(dead, 48))
	dead.add_to_group(CARRION)
	carcasses.append(dead)
	return dead


# Somewhere at the closed end of a dead end, off the middle of its way in.
func _dead_end_spot(nav: MazeNav, cell: Vector2i) -> Vector3:
	var middle := nav.point(cell)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			return middle - Vector3(step.x, 0.0, step.y) * 2.5 + Vector3(step.y, 0.0, step.x) * _rng.randf_range(-1.5, 1.5)
	return middle


## Someone was caught at `at`: flies gather there for a while.
func caught_at(at: Vector3) -> InsectSwarm:
	for entry: Array in caught_flies:
		if (entry[0] as InsectSwarm).centre.distance_to(at) < 3.0 and entry[1] > CAUGHT_TIME - 5.0:
			return entry[0]
	var swarm := InsectSwarm.new()
	swarm.name = "CaughtFlies%d" % caught_flies.size()
	swarm.kind = InsectLook.Kind.FLY
	swarm.count = _scaled(16)
	swarm.swarm_seed = hash("caught/%d/%s" % [seed_value, str(at.snapped(Vector3.ONE))])
	at.y = maze.ground_height(at) + 0.35 if maze else at.y
	swarm.centre = at
	swarm.radius = 0.9
	swarm.spread_height = Vector2(-0.3, 0.9)
	_fly_habits(swarm)
	swarm.land_on_still = 0
	swarm.rest_share = 0.25
	swarm.scarers = _players()
	add_child(swarm)
	caught_flies.append([swarm, CAUGHT_TIME])
	return swarm


## World's news that someone was caught by `enemy` (where it is, near enough).
func on_enemy_caught(who: Node3D, enemy: Node3D) -> void:
	caught_at(enemy.global_position.lerp(who.global_position, 0.5) if is_instance_valid(who) else enemy.global_position)


## World's news that this player was caught (and is already back in the clearing).
func on_player_caught(_slot: int) -> void:
	if _player_at.is_finite():
		caught_at(_player_at)


# --- Dragonflies ---

# Patches of them along the marsh's pools, perching on its bulrushes.
func _marsh_dragonflies() -> void:
	var total := maze.clearing_style.marsh_dragonflies
	if total <= 0 or world == null:
		return
	var marsh: Marsh = null
	for found: Node in world.find_children("Marsh", "Node3D", true, false):
		marsh = found as Marsh
	if marsh == null or marsh.bulrush_tops.is_empty():
		return
	# The bulrushes by squares; the patches go where most of them are.
	const SQUARE := 24.0
	var squares := {}
	for k in marsh.bulrush_tops.size():
		var key := Vector2i((Vector2(marsh.bulrush_tops[k].x, marsh.bulrush_tops[k].z) / SQUARE).floor())
		if not squares.has(key):
			squares[key] = []
		squares[key].append(k)
	var keys := squares.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return squares[a].size() > squares[b].size() or squares[a].size() == squares[b].size() and (a.x < b.x or a.x == b.x and a.y < b.y))
	var per := 6
	var patches := mini(ceili(float(_scaled(total)) / per), keys.size())
	for p in patches:
		var key: Vector2i = keys[p]
		var mine: Array = squares[key]
		var middle := Vector3.ZERO
		for k: int in mine:
			middle += marsh.bulrush_roots[k]
		middle /= mine.size()
		middle.y = ClearingStyle.MARSH_LEVEL
		add_dragonflies(middle, SQUARE * 0.6, per, _rng.randi(), marsh, mine)


## A patch of `count` dragonflies hunting over `at` (`reach` round it), perching
## on the bulrushes `tips` of `marsh` (indices into its bulrush_tops), if given.
func add_dragonflies(at: Vector3, reach: float, count: int, swarm_seed: int, marsh: Marsh = null, tips: Array = []) -> InsectSwarm:
	var swarm := InsectSwarm.new()
	swarm.name = "Dragonflies%d" % dragonflies.size()
	swarm.kind = InsectLook.Kind.DRAGONFLY
	swarm.count = count
	swarm.swarm_seed = swarm_seed
	swarm.centre = at
	swarm.radius = reach
	swarm.patrol_height = Vector2(0.9, 2.3)
	swarm.wingspan = Vector2(0.1, 0.13)
	swarm.speed = 7.5
	swarm.flap_rate = 14.0
	swarm.rest_share = 0.3
	swarm.fly_time = Vector2(3.0, 9.0)
	swarm.rest_time = Vector2(4.0, 16.0)
	swarm.scare_range = 2.2
	if marsh and not tips.is_empty():
		var places: Array[Transform3D] = []
		var roots := PackedVector3Array()
		for k: int in tips:
			places.append(Transform3D(Basis.IDENTITY, marsh.bulrush_tops[k]))
			roots.append(marsh.bulrush_roots[k])
		swarm.perches = places
		swarm.perch_moves = func(perch: int, _point: Vector3) -> Vector3:
			return Marsh.bulrush_sway(roots[perch], fposmod(Time.get_ticks_msec() * 0.001, 3600.0))
	add_child(swarm)
	swarm.scarers = _players()
	dragonflies.append(swarm)
	return swarm


# --- For the dev panel ---

## Puts a swarm in at `at` (DevTools): MOTHS round a lantern, FLIES on a
## carcass, DRAGONFLIES hunting a patch.
func put(kind: InsectLook.Kind, at: Vector3) -> Node3D:
	at.y = maze.ground_height(at) if maze else at.y
	match kind:
		InsectLook.Kind.MOTH:
			var lamp := Node3D.new()
			lamp.name = "DevLantern"
			add_child(lamp)
			lamp.global_position = at + Vector3.UP * 1.6
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.82, 0.55)
			glow.omni_range = 6.0
			glow.light_energy = 1.6
			lamp.add_child(glow)
			var bulb := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.09
			ball.height = 0.18
			bulb.mesh = ball
			var lit := StandardMaterial3D.new()
			lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			lit.albedo_color = Color(1.0, 0.9, 0.7)
			bulb.material_override = lit
			lamp.add_child(bulb)
			lamp.set_meta(&"moth_radius", 1.2)
			lamp.add_to_group(LIGHTS)
			_scan = 0.0
			return lamp
		InsectLook.Kind.FLY:
			var dead := add_carcass(at, randf() * TAU)
			_scan = 0.0
			return dead
		_:
			return add_dragonflies(at, 8.0, 6, randi())


## Places on the upper faces of `model`'s meshes (in its own space) for flies to
## land on: `most` points of its surface that face up, spread over it.
func _upper_faces(model: Node3D, most: int) -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	var pick := RandomNumberGenerator.new()
	pick.seed = 5
	for piece: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var place := model.global_transform.affine_inverse() * piece.global_transform if piece.is_inside_tree() else piece.transform
		for surface in piece.mesh.get_surface_count():
			var arrays := piece.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in points.size():
				var normal := (place.basis * normals[k]).normalized()
				if normal.y > 0.55 and pick.randf() < 0.25:
					var ahead := Vector3(pick.randf_range(-1, 1), 0.0, pick.randf_range(-1, 1))
					found.append(Transform3D(InsectSwarm._basis_from(normal, ahead), place * points[k]))
	while found.size() > most:
		found.remove_at(pick.randi_range(0, found.size() - 1))
	return found


# --- Fireflies ---

## How dark it is for the fireflies: 0 by day, rising through dusk to 1 at night.
func firefly_night() -> float:
	if fireflies_out:
		return 1.0
	var day: Node = world.get(&"day") if world else null
	if day == null:
		return 0.0
	return clampf(inverse_lerp(0.72, 0.18, float(day.get(&"daylight"))), 0.0, 1.0)


# Where the fireflies live (one FireflyField for them all): over the clearing's
# tall grass, in the woods (up into the boughs), over the marsh's pools, out in the
# meadow; and in the first ring, at the foot of the ivy and along the ferns and
# moss at the walls' feet. How many patches: ClearingStyle "Wildlife"
# (firefly_clouds), MazeStyle "Wildlife" (firefly_patches).
func _fireflies() -> void:
	fireflies = FireflyField.new()
	fireflies.name = "Fireflies"
	fireflies.max_drawn = 400 if Settings.low_poly else 900
	fireflies.max_bodies = 16 if Settings.low_poly else 48
	fireflies.lights = 0 if Settings.low_poly else 1
	add_child(fireflies)
	var look := maze.clearing_style
	var style: MazeStyle = maze.styles[0] if not maze.styles.is_empty() else MazeStyle.new()
	var clouds := int(_rule(look, &"firefly_clouds", 36))
	var patches := int(_rule(style, &"firefly_patches", 24))
	var per_cloud := _scaled(44)
	var per_patch := _scaled(16)
	var pick := RandomNumberGenerator.new()
	pick.seed = hash("fireflies/%d" % seed_value)
	var marsh_area := look.marsh_rect()
	var ground := func(at: Vector3) -> float:
		var under := maze.ground_height(at)
		return maxf(under, ClearingStyle.MARSH_LEVEL) if marsh_area.has_point(Vector2(at.x, at.z)) else under
	var builder: MazeBuilder = world.get_node_or_null(^"Maze") as MazeBuilder if world else null
	# The clearing: the tall grass first, then the woods, the marsh and the meadow.
	var trees: Array[Vector3] = []
	var half := maze.clearing * Maze.CELL * 0.5 - 6.0
	if builder and builder.layout:
		for piece in builder.layout.pieces(MazePiece.Kind.TREE):
			if maxf(absf(piece.position.x), absf(piece.position.z)) < half:
				trees.append(piece.position)
	var bulrushes := PackedVector3Array()
	if world:
		for found: Node in world.find_children("Marsh", "Node3D", true, false):
			bulrushes = (found as Marsh).bulrush_roots
	var meadow := look.tall_grass_middle()
	for i in clouds:
		var share := float(i) / maxf(clouds, 1)
		var at := Vector3.INF
		var heights := Vector2(0.25, 1.5)
		var reach := 7.0
		if share < 0.35 and meadow.is_finite():
			var spot: Vector2 = look.tall_grass_spot(pick)
			at = Vector3(spot.x, 0.0, spot.y)
			heights = Vector2(0.9, 2.6)
		elif share < 0.6 and not trees.is_empty():
			at = trees[pick.randi_range(0, trees.size() - 1)] + Vector3(pick.randf_range(-3.0, 3.0), 0.0, pick.randf_range(-3.0, 3.0))
			heights = Vector2(0.3, 4.5)
			reach = 6.0
		elif share < 0.8 and not bulrushes.is_empty():
			at = bulrushes[pick.randi_range(0, bulrushes.size() - 1)]
			heights = Vector2(0.3, 1.7)
		else:
			var spot := TameChickens.clearing_spot(maze, pick, pick.randf() < 0.3)
			if spot.is_finite():
				at = Vector3(spot.x, 0.0, spot.y)
		if at.is_finite():
			at.y = ground.call(at)
			fireflies.add_patch(at, reach, per_cloud, heights, pick.randi(), ground)
	# The first ring: at the foot of the ivy, and along the plants at the walls' feet.
	var ivy: Array[Vector3] = []
	if builder and builder.features:
		for climb: IvyClimb in builder.features.climbs:
			if is_instance_valid(climb) and maze.ring_of(maze.cell_at(climb.global_position)) == 1:
				ivy.append(climb.global_position + climb.global_basis.z * 1.2)
	var plants: Array[Vector3] = []
	if builder and builder.undergrowth:
		for key: Array in builder.undergrowth.get(&"_placed"):
			if key[0] != Undergrowth.Kind.FERN and key[0] != Undergrowth.Kind.MOSS:
				continue
			for where: Transform3D in builder.undergrowth.get(&"_placed")[key]:
				if maze.ring_of(maze.cell_at(where.origin)) == 1 and pick.randf() < 0.1:
					plants.append(where.origin)
	if plants.is_empty():
		# (a ring with no plants: the moss along the foot of its walls, in its halls)
		var nav := MazeNav.new(maze)
		for cell in nav.lairs(1):
			if maze.ring_of(cell) != 1 or pick.randf() > 0.25:
				continue
			for step: Vector2i in Maze.STEPS:
				if maze.blocked(cell, step):
					var face := nav.point(cell) + Vector3(step.x, 0.0, step.y) * 3.0
					plants.append(face + Vector3(step.y, 0.0, step.x) * pick.randf_range(-4.0, 4.0))
					break
	for i in patches:
		var at := Vector3.INF
		var heights := Vector2(0.2, 1.6)
		if i % 5 < 2 and not ivy.is_empty():
			at = ivy.pop_at(pick.randi_range(0, ivy.size() - 1))
			heights = Vector2(0.3, 3.2)
		elif not plants.is_empty():
			at = plants.pop_at(pick.randi_range(0, plants.size() - 1))
		if at.is_finite():
			at.y = maze.ground_height(at)
			fireflies.add_patch(at, 3.5, per_patch, heights, pick.randi(), maze.ground_height)


## A style's setting `named`, or `otherwise` if the style has no such setting.
static func _rule(style: Resource, named: StringName, otherwise: Variant) -> Variant:
	var value: Variant = style.get(named) if style else null
	return value if value != null else otherwise


## Puts a cloud of fireflies in at `at` (DevTools), and has them all out whatever the hour.
func put_fireflies(at: Vector3) -> int:
	at.y = maze.ground_height(at) if maze else at.y
	fireflies_out = true
	return fireflies.add_patch(at, 5.0, 40, Vector2(0.3, 2.0), randi(), maze.ground_height if maze else Callable())
