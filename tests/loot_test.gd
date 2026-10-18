extends SceneTree
## What lies about and the camps (Loot), in a round played alone: placed from
## the seed (the same twice) and kept off the middle and the ways to the gates;
## taken by one player only; two slots, four with a backpack; a torch burns out;
## a thrown spear staggers a hunter and does not kill it; the swarms keep off a
## lit torch; the grappling hook catches the lip of a ledge and he swings on it;
## a rope ladder hangs from an edge; a map scrap finds the way to a gate; a camp
## has runners sat round its fire; and the room's news (another seat taking,
## something dropped) is heard.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/loot_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	await frames(5)
	main.start_solo()
	await frames(30)
	var world = main.world
	var maze: Maze = world.maze
	var player: Player = world.player
	var loot = world.loot
	check("loot is in", loot != null and not loot.items.is_empty(), "(%d things, %d camps)" % [loot.items.size(), loot.camps.size()])

	# --- Placed from the seed, and kept off the middle and the paths ---
	var again = loot.get_script().new()
	again.world = world
	again.maze = maze
	again.set_physics_process(false)
	world.add_child(again)
	again.populate(hash("loot/%d" % maze.maze_seed))
	var same: bool = again.items.size() == loot.items.size()
	for id: int in loot.items:
		var a: Node3D = loot.items[id]
		var b: Node3D = again.items.get(id)
		if b == null or a.get(&"kind") != b.get(&"kind") or a.global_position.distance_to(b.global_position) > 0.01:
			same = false
	check("the same seed lays out the same", same and again.camps.size() == loot.camps.size())
	again.queue_free()
	var look := maze.clearing_style
	var nearest_middle := INF
	var nearest_path := INF
	for id: int in loot.items:
		var at: Vector3 = loot.items[id].global_position
		if not maze.in_clearing(maze.cell_at(at)):
			continue
		var flat := Vector2(at.x, at.z)
		nearest_middle = minf(nearest_middle, flat.length())
		for gate: Array in look.entrance_spots:
			nearest_path = minf(nearest_path, Geometry2D.get_closest_point_to_segment(flat, Vector2.ZERO, gate[0]).distance_to(flat))
	check("nothing in the middle where everyone wakes", nearest_middle > 30.0, "(nearest %.0f m)" % nearest_middle)
	check("nothing on the ways to the gates", nearest_path > 7.0, "(nearest %.1f m)" % nearest_path)
	var in_maze := 0
	for id: int in loot.items:
		var cell := maze.cell_at(loot.items[id].global_position)
		if maze.inside(cell) and not maze.in_clearing(cell):
			in_maze += 1
	check("things lie in the maze's halls too", in_maze >= 3, "(%d)" % in_maze)
	var occupied := 0
	for camp in loot.camps:
		if camp.kind == Campsite.Kind.OCCUPIED:
			occupied += 1
	check("camps: left and with people", loot.camps.size() >= 3 and occupied >= 1, "(%d, %d with people)" % [loot.camps.size(), occupied])

	# --- Taking: one player only; two slots, four with a backpack ---
	var torch := _bring(loot, LootItem.Kind.TORCH, player, world)
	var torch_id: int = torch.get(&"loot_id")
	check("the prompt sees it", loot.nearest(player) == torch)
	loot.act(player)
	await frames(2)
	check("taken into a slot", loot.slots.has(torch_id) and torch.get(&"loot_state") == LootItem.State.POCKET and not torch.visible)
	loot.grant(torch_id, 2)
	check("nobody else can have it after", int(loot.owners[torch_id]) == world.slot)
	var spear := _bring(loot, LootItem.Kind.SPEAR, player, world)
	loot.act(player)
	await frames(2)
	var flare := _bring(loot, LootItem.Kind.FLARE, player, world)
	loot.act(player)
	await frames(2)
	check("two slots without a backpack", loot.slot_count() == 2 and loot.slots.has(spear.get(&"loot_id")) and not loot.slots.has(flare.get(&"loot_id")) and flare.get(&"loot_state") == LootItem.State.LYING)
	flare.global_position += Vector3(0.0, 0.0, 30.0)
	var bag := _bring(loot, LootItem.Kind.BACKPACK, player, world)
	loot.act(player)
	await frames(2)
	check("a backpack: worn, four slots", loot.pack and loot.slot_count() == 4 and Worn.wearing(player.get_node(^"Rig"), &"back") == &"backpack" and bag.get(&"loot_state") == LootItem.State.SPENT)
	flare.global_position = player.global_position + Vector3(0.6, 0.05, 0.0)
	loot.act(player)
	await frames(2)
	check("and room for a third", loot.slots.has(flare.get(&"loot_id")))

	# --- Another seat takes something: gone for everyone ---
	var theirs := _bring(loot, LootItem.Kind.MAP, player, world)
	var theirs_id: int = theirs.get(&"loot_id")
	loot.hear({"loot": "got", "id": theirs_id, "seat": 1}, 0)
	check("taken by another seat: gone here", theirs.get(&"loot_state") == LootItem.State.POCKET and not theirs.visible and int(loot.owners[theirs_id]) == 1 and not loot.slots.has(theirs_id))
	loot.hear({"loot": "drop", "id": 777777, "kind": LootItem.Kind.SPEAR, "seat": 1, "at": [player.global_position.x + 3.0, player.global_position.y + 1.0, player.global_position.z], "vel": [0, 0, 0], "lit": false, "fuel": 0.0}, 0)
	await frames(150)
	var dropped: Node3D = loot.items.get(777777)
	check("something a friend dropped is seen, and lies", dropped != null and dropped.visible and dropped.get(&"loot_state") == LootItem.State.LYING)

	# --- A torch in his hand: lit; the swarms keep off it; it burns out ---
	world.put_player(world.spawn(0, true), 0.0)
	await frames(10)
	var swarm := Beetles.new()
	swarm.keep_out_of_clearing = false
	world.enemies.add(swarm, maze.cell_at(player.global_position), 0.0, 1, Vector3(4.0, 0.0, 4.0))
	await frames(5)
	check("a swarm would go after him", swarm.huntable(player))
	loot.draw(loot.slots.find(torch_id))
	await frames(3)
	check("the torch in his hand, lit", player.carried == torch and torch.get(&"lit") and loot.hand == torch_id)
	check("the swarm keeps off the torch", not swarm.huntable(player) and FireWard.near(self, player.global_position))
	torch.set(&"fuel", 0.4)
	await frames(45)
	check("the torch burns out", not torch.get(&"lit") and float(torch.get(&"ward_radius")) == 0.0)
	check("and the swarm comes again", swarm.huntable(player))
	swarm.queue_free()
	world.enemies.enemies.erase(swarm)

	# --- A camp: lit with a torch, the torch lit again at it ---
	var camp: Campsite = null
	for c in loot.camps:
		if c.kind == Campsite.Kind.ABANDONED and not c.in_maze:
			camp = c
	if camp:
		world.put_player(camp.global_position + Vector3(1.6, 0.3, 0.0), -PI * 0.5)
		await frames(10)
		loot.act(player)
		check("a burnt-out torch is lit again at a lit fire: not at a cold one", not torch.get(&"lit"))
		torch.set(&"fuel", 100.0)
		torch.call(&"set_lit", true)
		loot.act(player)
		check("a torch lights a cold campfire", camp.lit and FireWard.near(self, camp.global_position + Vector3(2, 0, 0)))
	loot.stow()
	await frames(2)
	check("put away: out of his hand, out", player.carried == null and loot.hand == -1 and not torch.get(&"lit") and loot.slots.has(torch_id))

	# --- A camp with people at it ---
	await frames(90)
	var sat := 0
	for boy in loot.campers:
		if boy.sit_progress > 0.5 and boy.global_position.distance_to(boy.camp.global_position) < 3.5:
			sat += 1
	check("runners sat round a camp's fire", sat >= 2, "(%d of %d)" % [sat, loot.campers.size()])
	var lit_camps := 0
	for c in loot.camps:
		if c.kind == Campsite.Kind.OCCUPIED and c.lit and c._smoke != null:
			lit_camps += 1
	check("their fires burn, and smoke", lit_camps == occupied)

	# --- A thrown spear staggers a hunter, and does not kill it ---
	var hall := _hall_spot(maze)
	world.put_player(hall[0], atan2(hall[1].x, hall[1].z))
	await frames(10)
	var ghoul := MazeGhoul.new()
	ghoul.keep_out_of_clearing = false
	var target: Vector3 = hall[0] + hall[1] * 6.0
	world.enemies.add(ghoul, maze.cell_at(target), 0.0, 3, target - maze.world(maze.cell_at(target)))
	await frames(5)
	loot.draw(loot.slots.find(int(spear.get(&"loot_id"))))
	await frames(3)
	player.facing_yaw = atan2(hall[1].x, hall[1].z)
	player._act()
	var staggered := false
	for i in 90:
		await physics_frame
		if Stagger.on(ghoul):
			staggered = true
			break
	var from_x := ghoul.global_position
	check("the spear staggers the ghoul", staggered and not ghoul.is_physics_processing())
	await frames(40)
	var shoved := ghoul.global_position.distance_to(from_x)
	check("the spear is out of his hand and slots", player.carried == null and not loot.slots.has(int(spear.get(&"loot_id"))))
	await frames(240)
	check("and the ghoul is not killed: it goes on", is_instance_valid(ghoul) and ghoul.is_inside_tree() and ghoul.is_physics_processing() and not Stagger.on(ghoul), "(shoved %.1f m)" % shoved)
	ghoul.queue_free()
	world.enemies.enemies.erase(ghoul)
	await frames(60)
	check("the spear lies where it fell, to be taken again", spear.get(&"loot_state") == LootItem.State.LYING and spear.visible, "(%d, %s, going %.2f)" % [spear.get(&"loot_state"), str(spear.global_position), spear.linear_velocity.length()])

	# --- The grappling hook catches the lip of a ledge ---
	var hook := _bring(loot, LootItem.Kind.HOOK, player, world)
	loot.act(player)
	await frames(2)
	world.put_player(hall[0] - hall[1] * 0.0, atan2(-hall[2].x, -hall[2].z))
	# (stood back from the wall with the ledge along it, facing it)
	var wall_way: Vector3 = hall[2]
	world.put_player(hall[3] - wall_way * 3.4, atan2(wall_way.x, wall_way.z))
	world.camera.snap()
	await frames(10)
	loot.draw(loot.slots.find(int(hook.get(&"loot_id"))))
	await frames(3)
	await frames(40)
	var aim: Node3D = hook.call(&"find_target", player)
	var aim_at: Vector3 = aim.global_position if aim else Vector3.ZERO
	check("the hook finds a ledge's lip in reach", aim != null and aim_at.y > player.global_position.y + 3.0, "(%.1f m up)" % (aim_at.y - player.global_position.y))
	player._act()
	var on_rope := false
	for i in 120:
		await physics_frame
		if player.state == Player.State.ROPE:
			on_rope = true
			break
	check("thrown, it bites and he is on its rope", on_rope)
	# Climbing it to the top (act held, as the rope climbs: pressed afresh once he is on it).
	await frames(10)
	Input.action_press(&"act")
	var up := false
	for i in 900:
		await physics_frame
		# (at the top he hangs from the lip: jump pulls him up over it)
		if player.state == Player.State.HANG and i % 20 == 0:
			player._queue_jump()
		if player.state == Player.State.FREE and player.is_on_floor() and player.global_position.y > aim_at.y - 1.0:
			up = true
			break
	Input.action_release(&"act")
	check("and climbs it onto the ledge", up, "(at %.1f m, the lip %.1f m)" % [player.global_position.y, aim_at.y])

	# --- A rope ladder hung from the ledge's edge ---
	if up:
		var ladder := _bring(loot, LootItem.Kind.LADDER, player, world)
		loot.act(player)
		await frames(2)
		player.facing_yaw = atan2(-wall_way.x, -wall_way.z)
		await frames(2)
		var edge: Array = loot.ladder_edge(player)
		check("an edge to hang the ladder from", not edge.is_empty(), "(%s)" % str(edge))
		loot.use_slot(loot.slots.find(int(ladder.get(&"loot_id"))))
		await frames(2)
		check("the rope ladder hangs", loot.ladders.size() == 1 and loot.ladders[0].is_in_group(&"ladders") and loot.ladders[0].height > 2.0)

	# --- A map scrap: the way to a gate ---
	world.put_player(world.spawn(0, true), 0.0)
	await frames(5)
	var way: Array = loot.way_out(player.global_position)
	check("a map scrap finds the way to a gate", way.size() > 3)
	var map := _bring(loot, LootItem.Kind.MAP, player, world)
	loot.act(player)
	await frames(2)
	var read := [false]
	loot.map_read.connect(func(_s: float) -> void: read[0] = true)
	loot.use_slot(loot.slots.find(int(map.get(&"loot_id"))))
	check("read, and used up", read[0] and not loot.slots.has(int(map.get(&"loot_id"))))

	# --- Fighting back: a stick, a bat and a sword swung; a gun fired ---
	await _weapons(world, maze, player, loot, hall)
	await _rarity(world, maze, loot)

	# --- The dev panel's buttons ---
	var before: int = loot.items.size()
	for one: Array in loot.DEV:
		loot.dev_drop(one[1])
	await frames(5)
	check("the dev panel puts each in", loot.items.size() >= before + 14 and loot.camps.size() >= 10, "(%d more, %d camps)" % [loot.items.size() - before, loot.camps.size()])

	print("%s: %d failed" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


## Each weapon taken, swung or fired at a hunter in a hall; what it does to it.
func _weapons(world, maze: Maze, player: Player, loot, hall: Array) -> void:
	var along: Vector3 = hall[1]
	var yaw := atan2(along.x, along.z)
	for one: Array in [[LootItem.Kind.STICK, "stick"], [LootItem.Kind.BAT, "bat"], [LootItem.Kind.SWORD, "sword"]]:
		_empty(loot)
		world.put_player(hall[0], yaw)
		await frames(6)
		var weapon := _bring(loot, one[0], player, world)
		weapon.set(&"uses", 5 if one[0] != LootItem.Kind.SWORD else 0)
		loot.act(player)
		await frames(40)
		check("a %s is taken into a slot" % one[1], loot.slots.has(int(weapon.get(&"loot_id"))))
		loot.draw(loot.slots.find(int(weapon.get(&"loot_id"))))
		await frames(4)
		check("the %s in both his hands (a bat's hold)" % one[1], player.carried == weapon and weapon.is_in_group(&"bats"))
		var ghoul := _still_hunter(world, maze, player, along, 1.5)
		await frames(3)
		var from := ghoul.global_position
		player.facing_yaw = yaw
		player._act()
		var swung := player.swing_progress < 1.0
		var hit := false
		for i in 60:
			await physics_frame
			if Stagger.on(ghoul):
				hit = true
				break
		await frames(30)
		var shoved := ghoul.global_position.distance_to(from)
		check("the %s is swung (act), with its swing" % one[1], swung and is_equal_approx(player.swing_time, LootItem.MELEE[one[0]]["swing"]))
		check("the %s hits the ghoul and staggers it" % one[1], hit, "(shoved %.2f m)" % shoved)
		check("the %s's blow shoves it back as hard as it should" % one[1], shoved > (1.5 if one[0] == LootItem.Kind.BAT else 0.3), "(%.2f m)" % shoved)
		if one[0] != LootItem.Kind.SWORD:
			check("the %s wears with the blow" % one[1], int(weapon.get(&"uses")) == 4)
		else:
			check("the sword does not wear", int(weapon.get(&"uses")) == 0 and weapon.get(&"loot_state") == LootItem.State.HAND)
		if one[0] == LootItem.Kind.STICK:
			# (struck again at once, it is only knocked on: no holding it down by beating it)
			for i in 300:
				await physics_frame
				if not Stagger.on(ghoul):
					break
			check("the stagger wears off", not Stagger.on(ghoul))
			weapon.set(&"uses", 1)
			# (stepped up to it again, and at it before it has got its feet)
			world.put_player(ghoul.global_position - along * 1.3, yaw)
			await frames(1)
			player.facing_yaw = yaw
			player._act()
			await frames(40)
			check("struck again just after, it is only knocked on", not Stagger.on(ghoul) or ghoul.get_node(^"Stagger").get(&"_seconds") < 0.5)
			check("and a stick snaps at last", loot.hand == -1 and not loot.slots.has(int(weapon.get(&"loot_id"))) and weapon.get(&"loot_state") == LootItem.State.SPENT and player.carried == null)
		ghoul.queue_free()
		world.enemies.enemies.erase(ghoul)
		await frames(2)

	# A revolver with two rounds in it and none spare.
	_empty(loot)
	world.put_player(hall[0], yaw)
	await frames(6)
	var gun := _bring(loot, LootItem.Kind.REVOLVER, player, world)
	gun.set(&"uses", 2)
	loot.act(player)
	await frames(40)
	loot.draw(loot.slots.find(int(gun.get(&"loot_id"))))
	await frames(4)
	check("a revolver in his hand", player.carried == gun and gun.is_in_group(&"guns"))
	check("the HUD shows its rounds", loot.ammo_text().begins_with("2 / 6"), "(%s)" % loot.ammo_text())
	var target := _still_hunter(world, maze, player, along, 8.0)
	# (one that hears it from further down the hall, after nobody)
	var listener := MazeGhoul.new()
	listener.keep_out_of_clearing = false
	var far: Vector3 = hall[0] - along * 6.0
	world.enemies.add(listener, maze.cell_at(far), 0.0, 9, far - maze.world(maze.cell_at(far)))
	# (kept from looking about for itself: only the shot can tell it he is there)
	listener.set_physics_process(false)
	await frames(5)
	listener._spared.clear()
	listener.quarry = null
	listener._forget = 0.0
	player.facing_yaw = yaw
	player._act()
	var fired := false
	for i in 60:
		await physics_frame
		if int(gun.get(&"uses")) == 1:
			fired = true
			break
	check("act brings it up and fires: a round is used", fired and player.gun_raise > 0.5)
	await frames(2)
	check("the shot fells the ghoul", Stagger.felled(target) and not target.is_in_group(&"maze_enemies"))
	check("the shot is loud: a hunter near hears it and comes", listener.hunting() and listener.quarry == player)
	listener.queue_free()
	world.enemies.enemies.erase(listener)
	await frames(Stagger.FALLS * 60 + Stagger.LIES * 60 + Stagger.SINKS * 60 + 20)
	check("felled, it sinks away and is gone", not target.visible and not target.can_process(), "(%s, %s, %s)" % [target.visible, target.can_process(), Stagger.on(target)])
	# Fired again at nothing, and then empty: it clicks.
	await frames(90)
	player._act()
	await frames(60)
	check("a second shot: the gun is empty", int(gun.get(&"uses")) == 0)
	var told := [""]
	loot.said.connect(func(text: String) -> void: told[0] = text)
	await frames(90)
	player._act()
	await frames(40)
	check("empty, with no rounds: it clicks", int(gun.get(&"uses")) == 0 and told[0].begins_with("CLICK"), "(%s)" % told[0])
	# A box of rounds, taken: into his pocket (no slot), and the empty gun is loaded from it.
	var box := _bring(loot, LootItem.Kind.ROUNDS, player, world)
	box.set(&"uses", 3)
	var slots_before: Array = loot.slots.duplicate()
	loot.act(player)
	await frames(40)
	check("a box of rounds takes no slot", loot.slots == slots_before and box.get(&"loot_state") == LootItem.State.SPENT)
	await frames(150)
	check("the empty gun is loaded from it", int(gun.get(&"uses")) == 3 and int(loot.ammo[LootItem.Kind.ROUNDS]) == 0, "(%d in it, %d spare)" % [int(gun.get(&"uses")), int(loot.ammo[LootItem.Kind.ROUNDS])])

	# A shotgun at something past its reach to fell: staggered, not felled. And
	# one the size of the snake is never felled.
	_empty(loot)
	world.put_player(hall[0], yaw)
	await frames(6)
	var shotgun := _bring(loot, LootItem.Kind.SHOTGUN, player, world)
	shotgun.set(&"uses", 2)
	loot.act(player)
	await frames(40)
	loot.draw(loot.slots.find(int(shotgun.get(&"loot_id"))))
	await frames(4)
	check("a shotgun is held in both hands", player.carried == shotgun and bool(shotgun.get(&"two_handed")))
	var distant := _still_hunter(world, maze, player, along, 16.0)
	await frames(3)
	player.facing_yaw = yaw
	player._act()
	await frames(50)
	check("a shotgun's shot past its reach staggers and does not fell", int(shotgun.get(&"uses")) == 1 and Stagger.on(distant) and not Stagger.felled(distant))
	var swarm := Beetles.new()
	var snake := Apophis.new()
	check("the swarms and the great are not felled by a bullet", not loot.can_fell(swarm) and not loot.can_fell(snake) and loot.can_fell(distant))
	swarm.free()
	snake.free()
	distant.queue_free()
	world.enemies.enemies.erase(distant)

	# The room: a guest's felled hunter is felled here too; a friend's shot is seen.
	var theirs := _still_hunter(world, maze, player, along, 5.0)
	await frames(3)
	loot.hear({"loot": "felled", "enemy": world.enemies.enemies.find(theirs), "push": [along.x, along.z]}, 0)
	check("felled by someone else's shot: felled here", Stagger.felled(theirs))
	loot.hear({"loot": "shot", "seat": 1, "id": int(gun.get(&"loot_id")), "kind": LootItem.Kind.REVOLVER, "from": [0, 1, 0], "to": [0, 1, 10], "uses": 2}, 1)
	check("a friend's shot is heard of: what is left in their gun with it", int(gun.get(&"uses")) == 2)
	await frames(Stagger.FALLS * 60 + Stagger.LIES * 60 + Stagger.SINKS * 60 + 20)
	world.enemies.enemies.erase(theirs)
	_empty(loot)


## Rarity, by the rules and the seed: none where the rules say none, every one
## where they say all, rare by default (guns rarer than swords, rounds rarer than
## guns), and the same seed the same.
func _rarity(world, maze: Maze, loot) -> void:
	var none := MazeStyle.new()
	none.gun_chance = 0.0
	none.ammo_chance = 0.0
	var every := MazeStyle.new()
	every.gun_chance = 1.0
	var plain := MazeStyle.new()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var counts := {}
	for i in 4000:
		var kind: int = loot._roll(loot.maze_mix(plain), plain, r)
		counts[kind] = int(counts.get(kind, 0)) + 1
	var guns: int = counts.get(LootItem.Kind.REVOLVER, 0) + counts.get(LootItem.Kind.SHOTGUN, 0)
	var boxes: int = counts.get(LootItem.Kind.ROUNDS, 0) + counts.get(LootItem.Kind.SHELLS, 0)
	var sticks: int = counts.get(LootItem.Kind.STICK, 0)
	var swords: int = counts.get(LootItem.Kind.SWORD, 0)
	check("by default guns are rare (a few in a hundred), rounds rarer", guns > 60 and guns < 260 and boxes < guns and boxes > 20, "(%d guns, %d boxes in 4000)" % [guns, boxes])
	check("sticks common, swords less so", sticks > swords * 2 and swords > 0, "(%d sticks, %d swords)" % [sticks, swords])
	var any := false
	for i in 500:
		if loot._roll(loot.maze_mix(none), none, r) in [LootItem.Kind.REVOLVER, LootItem.Kind.SHOTGUN, LootItem.Kind.ROUNDS, LootItem.Kind.SHELLS]:
			any = true
	check("a section whose rules say no guns has none", not any)
	# A whole section laid out by rules that say every thing is a gun; twice from one seed.
	every.abandoned_camps = 0
	every.loot_items = 6
	var laid := []
	for twice in 2:
		var other = loot.get_script().new()
		other.world = world
		other.maze = maze
		other.set_physics_process(false)
		world.add_child(other)
		other._rng.seed = 1234
		other._populate_ring(1, every)
		var kinds := []
		for id: int in other.items:
			var item: Node3D = other.items[id]
			kinds.append([item.get(&"kind"), item.get(&"uses"), item.global_position.snapped(Vector3.ONE * 0.01)])
		laid.append(kinds)
		other.queue_free()
	var all_guns: bool = laid[0].size() == 6
	for k: Array in laid[0]:
		if not k[0] in LootItem.GUNS or int(k[1]) < 1 or int(k[1]) > 3:
			all_guns = false
	check("a section whose rules say all guns: guns, a few rounds in each", all_guns, "(%s)" % str(laid[0]))
	check("and the same seed lays them out the same", laid[0] == laid[1])
	await frames(2)


## A ghoul `distance` ahead of him along `way`, made to stand still (and let him alone) for a test.
func _still_hunter(world, maze: Maze, player: Player, way: Vector3, distance: float) -> MazeEnemy:
	var ghoul := MazeGhoul.new()
	ghoul.keep_out_of_clearing = false
	var at := player.global_position + way * distance
	world.enemies.add(ghoul, maze.cell_at(at), atan2(-way.x, -way.z), 5, at - maze.world(maze.cell_at(at)))
	ghoul.set_physics_process(false)
	return ghoul


## Empties his hand and pockets.
func _empty(loot) -> void:
	if loot.hand >= 0:
		loot.stow()
	for i in loot.slots.size():
		if loot.slots[i] >= 0:
			loot._spend(loot.slots[i], false)
			loot.slots[i] = -1
	loot.ammo[LootItem.Kind.ROUNDS] = 0
	loot.ammo[LootItem.Kind.SHELLS] = 0


## Puts a new one of `kind` at his feet (a dev drop, numbered as one).
func _bring(loot, kind: LootItem.Kind, player: Player, world) -> Node3D:
	var id: int = 900000 + loot.items.size()
	var at := player.global_position + Vector3(0.6, 0.05, 0.0)
	return loot._place(kind, at, 0.0, id)


## Somewhere in the first ring's halls to stand: [where, the way along the
## hall (open for 8 m), the way to a wall with a ledge along it, a point 1 m
## off that wall's face].
func _hall_spot(maze: Maze) -> Array:
	var nav := MazeNav.new(maze)
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or not nav.allowed(cell) or maze.solid.has(cell):
			continue
		for step: Vector2i in Maze.STEPS:
			var along := Vector3(step.x, 0.0, step.y)
			var p := nav.point(cell)
			if not nav.line_free(p, p + along * 9.0, 2.0):
				continue
			var side := Vector2i(-step.y, step.x)
			for s: Vector2i in [side, -side]:
				if maze.blocked(cell, s) and not maze.ring_wall(cell, s) and not maze.blocked(cell, -s):
					var to_wall := Vector3(s.x, 0.0, s.y)
					var face := maze.world(cell) + to_wall * (Maze.CELL * 0.5 - maze.wall_thick(cell, s) * 0.5)
					if nav.clear_of_walls(face - to_wall * 4.4, 0.5):
						return [p + Vector3.UP * 0.05, along, to_wall, face - to_wall * 1.0 + Vector3.UP * 0.05]
	return [Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT, Vector3.ZERO]
