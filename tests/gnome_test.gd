extends SceneTree
## The gnomes (scripts/enemies/maze_gnome.gd, creatures/gnome/), headless, in a
## round played alone (main.tscn, so that there is Loot and an inventory), with
## the round's own hunters taken out. A band makes its hollow at a wall's foot;
## looked at, they do not move at all; looked away from, they creep up behind
## him; one snatches a thing from his pockets (never his hand) and runs for
## home; caught, it drops it; another gets home and lays what it took by the
## door and hides; their rope across a hall trips him when he runs into it and
## not when he walks; a puppet follows the host (frozen too).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/gnome_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var main: Node
var world
var maze: Maze
var nav: MazeNav
var boy: Player
var loot
var eye: Camera3D
var failures := 0
## The way he is made to face (INF: as he will).
var want_yaw := INF


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		_hold_look()


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		_hold_look()
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


## His eyes: a camera of the test's own, put behind him looking `look`.
func look(way: Vector3) -> void:
	way.y = 0.0
	way = way.normalized()
	eye.global_position = boy.global_position + Vector3.UP * 1.6 - way * 3.0
	eye.look_at(eye.global_position + way)
	want_yaw = atan2(way.x, way.z)
	boy.facing_yaw = want_yaw


## (he would turn back to the way he was going: he is held to the way he is made to face)
func _hold_look() -> void:
	if boy and want_yaw != INF:
		boy.facing_yaw = want_yaw


func give(kind: LootItem.Kind) -> int:
	var item: Node3D = loot._place(kind, boy.global_position + Vector3.UP * 3.0, 0.0, 900000 + loot._next)
	loot._next += 1
	var id: int = item.get(&"loot_id")
	loot.grant(id, world.slot)
	return id


func moved(band: Array, from: Array) -> float:
	var most := 0.0
	for k in band.size():
		most = maxf(most, (band[k] as Node3D).global_position.distance_to(from[k]))
	return most


func places(band: Array) -> Array:
	return band.map(func(one: Node3D) -> Vector3: return one.global_position)


func modes(band: Array) -> String:
	return ", ".join(band.map(func(one: MazeGnome) -> String: return MazeGnome.Mode.keys()[one.mode]))


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(30)
	world = main.world
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	loot = world.loot
	# (only the gnomes: the round's own hunters are taken out)
	for one in world.enemies.enemies:
		one.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.global_position = Vector3(0, -500, 0)
	if world.runners:
		for one in world.runners.get_children():
			one.queue_free()
	eye = Camera3D.new()
	world.add_child(eye)
	eye.make_current()
	await frames(3)

	# --- A band at the end of a dead end, its hollow at a wall's foot ---
	# (one with a straight hall of two cells out of it, so that there is room to see along)
	var home := Vector2i(-1, -1)
	var out := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(3):
		if not nav.dead_end(cell):
			continue
		for s: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, s) and not maze.blocked(cell + s, s):
				home = cell
				out = s
		if home.x >= 0:
			break
	check("found a dead end for them", home.x >= 0)
	var band := MazeGnome.band_of(4)
	for k in band.size():
		# (towards the end wall, so that its hollow is in that)
		var back := -Vector3(out.x, 0.0, out.y)
		world.enemies.add(band[k], home, 0.0, 100 + k, back * 3.0 + Vector3(back.z, 0.0, back.x) * (k - 1.5) * 0.7)
	await frames(6)
	var hollow: GnomeHollow = band[0].band.hollow
	check("the first of the band makes a hollow", hollow != null and is_instance_valid(hollow))
	if hollow:
		var into := hollow.global_position + Vector3.UP * 0.4 + hollow.global_basis.z * 0.3
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(into, into - hollow.global_basis.z * 0.8, 1))
		check("at the foot of a wall, facing out of it", not hit.is_empty() and absf(hollow.global_position.y - maze.ground_height(hollow.global_position)) < 0.2)
	check("all four share it", band.all(func(one: MazeGnome) -> bool: return one.band.hollow == hollow))
	check("they are at home", band.all(func(one: MazeGnome) -> bool: return one.mode == MazeGnome.Mode.HOME), "(%s)" % modes(band))

	# --- He has things in his pockets, and comes near ---
	var map_id := give(LootItem.Kind.MAP)
	var flare_id := give(LootItem.Kind.FLARE)
	check("he has two things in his pockets", loot.slots.has(map_id) and loot.slots.has(flare_id))
	var mouth: Vector3 = hollow.mouth()
	# (straight out from its door, as far as there is room for, up to 9 m)
	var hall: Vector3 = hollow.global_basis.z
	hall.y = 0.0
	hall = hall.normalized()
	var room: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mouth + Vector3.UP * 0.5, mouth + Vector3.UP * 0.5 + hall * 30.0, 1))
	var reach: float = 9.0 if room.is_empty() else clampf((room["position"] as Vector3).distance_to(mouth) - 2.0, 4.0, 9.0)
	var far_room: float = 30.0 if room.is_empty() else (room["position"] as Vector3).distance_to(mouth) - 2.0
	boy.global_position = mouth + hall * reach + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	await frames(3)
	for one: MazeGnome in band:
		one.notice(boy)
	# Looked at: nothing moves, however long.
	look(-hall)
	await frames(10)
	var before := places(band)
	await wait(2.5)
	var still := moved(band, before)
	check("looked at, they do not move at all", still < 0.05, "(%.2f m)" % still)
	check("and stand frozen", band.all(func(one: MazeGnome) -> bool: return one.frozen and one.body.frozen))
	# Looked away from: they creep up behind him.
	look(hall)
	before = places(band)
	var came := await wait(4.0, func() -> bool: return band.any(func(one: MazeGnome) -> bool: return one.mode == MazeGnome.Mode.STALK and one.global_position.distance_to(mouth) > 2.5))
	check("looked away from, they come after him", came and moved(band, before) > 1.0, "(%s; %.1f m)" % [modes(band), moved(band, before)])
	check("on tiptoe, pattering", band.any(func(one: MazeGnome) -> bool: return one.body.creeping))
	# Look back: frozen again, nearer.
	look(-hall)
	await frames(12)
	before = places(band)
	await wait(1.0)
	var ahead := band.filter(func(one: MazeGnome) -> bool: return Vector3(sin(want_yaw), 0.0, cos(want_yaw)).dot((one.global_position - boy.global_position) * Vector3(1, 0, 1)) > 0.6 * (one.global_position - boy.global_position).length())
	var still_ahead := ahead.all(func(one: MazeGnome) -> bool: return one.frozen and one.global_position.distance_to(before[band.find(one)]) < 0.05)
	check("look back and those before him are statues again", not ahead.is_empty() and still_ahead, "(%d of them before him)" % ahead.size())
	# Away again: one comes right up behind him and takes something.
	look(hall)
	var took := await wait(8.0, func() -> bool: return band.any(func(one: MazeGnome) -> bool: return one.carrying >= 0))
	var thief: MazeGnome = null
	for one: MazeGnome in band:
		if one.carrying >= 0:
			thief = one
	check("one snatches something from his pockets", took and thief != null, "(%s)" % modes(band))
	if thief == null:
		print("  ", band.map(func(o: MazeGnome) -> String: return "%.1f m fr=%s w=%s gather=%.1f" % [o._flat_to(boy), o.frozen, o.watched(), o._gather]), " yaw %.2f want %.2f" % [boy.facing_yaw, want_yaw])
	if thief == null:
		_end()
		return
	var stolen: int = thief.carrying
	check("it is gone from his pockets", not loot.slots.has(stolen) and loot.slots.count(-1) >= 1)
	check("and it runs for home with it", thief.mode == MazeGnome.Mode.FLEE)
	await frames(2)
	check("hugging it to its chest", thief.body.carrying and loot._item(stolen).visible)
	await wait(0.3)
	# Caught: it drops it, and it can be taken back.
	look(thief.global_position - boy.global_position)
	await frames(3)
	check("it is not frozen running home, looked at or not", not thief.frozen)
	boy.global_position = thief.global_position + Vector3(0.3, 0.1, 0.0)
	await frames(3)
	check("caught, it squeals and tumbles", thief.mode == MazeGnome.Mode.CAUGHT, "(%s)" % MazeGnome.Mode.keys()[thief.mode])
	var dropped: Node3D = loot._item(stolen)
	await wait(2.0, func() -> bool: return dropped.get(&"loot_state") == LootItem.State.LYING)
	check("and what it took lies there to be taken", dropped.get(&"loot_state") == LootItem.State.LYING and int(loot.owners[stolen]) == -1 and thief.carrying == -1)
	loot.grant(stolen, world.slot)
	check("he takes it back", loot.slots.has(stolen))

	# --- One gets home with it: laid by the door, and it hides ---
	look(hall)
	boy.global_position = mouth + hall * minf(reach, 7.0) + Vector3.UP * 0.1
	for one: MazeGnome in band:
		one.notice(boy)
		one._gather = 0.0
	var second := await wait(10.0, func() -> bool: return band.any(func(one: MazeGnome) -> bool: return one.carrying >= 0))
	check("another takes something", second)
	thief = null
	for one: MazeGnome in band:
		if one.carrying >= 0:
			thief = one
	if thief:
		stolen = thief.carrying
		# (he stands well away, his back to it, and lets it go)
		boy.global_position = mouth + hall * reach + Vector3.UP * 0.1
		var hid := await wait(8.0, func() -> bool: return thief.mode == MazeGnome.Mode.HIDE)
		check("it gets home and goes into the hollow", hid, "(%s)" % MazeGnome.Mode.keys()[thief.mode])
		check("out of sight and reach", not thief.visible and thief.escaped)
		var laid: Node3D = loot._item(stolen)
		await wait(2.0, func() -> bool: return laid.get(&"loot_state") == LootItem.State.LYING)
		check("what it took lies by its door", laid.get(&"loot_state") == LootItem.State.LYING and laid.global_position.distance_to(mouth) < 1.6, "(%.2f m from the door)" % laid.global_position.distance_to(mouth))

	# --- The rope: taut across the hall, he trips running and not walking ---
	var pair: Array = [band[0], band[1]]
	if band[0].mode == MazeGnome.Mode.HIDE or band[1].mode == MazeGnome.Mode.HIDE:
		pair = band.filter(func(one: MazeGnome) -> bool: return one.mode != MazeGnome.Mode.HIDE).slice(0, 2)
	var across := Vector3(-hall.z, 0.0, hall.x)
	var cross_at := mouth + hall * minf(reach, 5.0)
	var ends: Array = band[0]._wall_to_wall(cross_at, across)
	check("the rope's ends are found against the walls", ends.size() == 2 and (ends[0] as Vector3).distance_to(ends[1]) > 2.0)
	for k in 2:
		pair[k].mode = MazeGnome.Mode.ROPE_RUN
		pair[k]._mode_time = 0.0
		pair[k]._rope_end = ends[k]
	var strung := false
	for t in 16:
		if await wait(0.5, func() -> bool: return pair[0].mode == MazeGnome.Mode.ROPE and pair[1].mode == MazeGnome.Mode.ROPE):
			strung = true
			break
	check("two run out and pull it taut", strung, "(%s)" % modes(pair))
	await frames(2)
	check("the rope is seen", band[0].band.rope.visible)
	var rope: Array = pair[0].rope_ends()
	if rope.is_empty():
		rope = pair[1].rope_ends()
	check("at shin height", not rope.is_empty() and absf((rope[0] as Vector3).y - maze.ground_height(rope[0]) - pair[0].rope_height) < 0.1)
	var on_line: Vector3 = (rope[0] as Vector3).lerp(rope[1], 0.5) if not rope.is_empty() else cross_at
	boy.global_position = Vector3(on_line.x, maze.ground_height(on_line) + 0.05, on_line.z)
	await frames(4)
	# Walking across: he steps over it.
	boy.velocity = hall * 1.5
	for one: MazeGnome in pair:
		one._trip_local()
	check("walking, he steps over it", boy.landing_progress >= 1.0)
	# Running into it: he goes sprawling.
	boy.velocity = -hall * 4.6
	for one: MazeGnome in pair:
		one._trip_local()
	check("running into it, he trips and sprawls", boy.landing == Player.Landing.SPRAWL and boy.landing_progress < 1.0)
	await wait(rope_wait(pair))
	check("then they let it go and go home", pair.all(func(one: MazeGnome) -> bool: return one.mode in [MazeGnome.Mode.RETURN, MazeGnome.Mode.HOME, MazeGnome.Mode.STALK]), "(%s)" % modes(pair))

	# --- The band plans the rope itself when someone runs at the hollow ---
	for one: MazeGnome in band:
		if one.mode != MazeGnome.Mode.HIDE:
			one.mode = MazeGnome.Mode.HOME
	band[0].band.rope_in = 0.0
	boy.global_position = mouth + hall * minf(far_room, 16.0) + Vector3.UP * 0.1
	await frames(2)
	boy.velocity = -hall * 5.0
	band[0]._plan_rope()
	check("someone running at the hollow: two run out with the rope", band.filter(func(one: MazeGnome) -> bool: return one.mode == MazeGnome.Mode.ROPE_RUN).size() == 2, "(%s)" % modes(band))
	boy.velocity = Vector3.ZERO

	# --- A puppet follows the host, frozen and all ---
	var host: MazeGnome = band[2]
	var copy := MazeGnome.new()
	copy.puppet = true
	world.enemies.add(copy, home, 0.0, 7)
	await frames(3)
	look(host.global_position - boy.global_position)
	boy.global_position = host.global_position + hall * 6.0 + Vector3.UP * 0.1
	await frames(4)
	for i in 10:
		copy.from_bytes(host.state_bytes())
		await physics_frame
	check("a puppet is where the host's is", copy.global_position.distance_to(host.global_position) < 1.0, "(%.2f m)" % copy.global_position.distance_to(host.global_position))
	check("and frozen when it is", copy.frozen == host.frozen, "(host %s)" % host.frozen)
	_end()


func rope_wait(pair: Array) -> float:
	return pair[0].rope_time + 0.6


func _end() -> void:
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
