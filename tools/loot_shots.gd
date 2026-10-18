extends SceneTree
## Pictures of what lies about and the camps (Loot), landscape: a camp left
## behind in the clearing seen from the boy's height; a camp with runners round
## its fire at dusk; its smoke seen from far across the clearing; each thing
## lying in the grass (all together, and each close); the boy with a torch in a
## hall at night; on the grappling hook's rope; throwing the spear; the
## inventory on the screen; ("9", alone, in the game's own sections) a route of
## grappling hook spots, the ring above marked, and the hook thrown at a hanging
## vine, him hauled in to it and on it; (w) a stick, a bat and a sword held and swung; (g)
## the guns held and fired, a ghoul shot, the rounds on the HUD; (l) the weapons
## lying in a hall; (r) a friend in the room with a bat and a shotgun. Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/loot_shots.gd -- <folder> [only: 1 1c 2 3 4 5 6 7 8 w g l r]

var main: Node
var folder := "loot_shots"
var only := ""
var world
var maze: Maze
var loot
var eye: Camera3D
var player: Player


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	# (the hook spots and the vines, alone: in the game's own sections, as tests/loot_test.gd has them)
	if only.begins_with("9"):
		MazeStyle.chosen = MazeStyle.defaults()
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func wanted(name: String) -> bool:
	return only == "" or only.contains(name)


func shot(name: String, with_hud := false) -> void:
	main._ui.visible = with_hud
	for layer: Node in world.get_children():
		if layer is CanvasLayer and layer.name != "Vignette":
			(layer as CanvasLayer).visible = with_hud
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	# (in steps of the physics, which go at a fixed 60 a second, so that a throw is caught where it is meant to be)
	for i in maxi(roundi(seconds * 60.0), 1):
		await physics_frame


## The shot's camera at `from`, looking at `at`.
func frame(from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	eye.make_current()


func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, maze.ground_height(at), at.z)


## Empties his pockets (and his hand) for the next picture.
func empty_pockets() -> void:
	if loot.hand >= 0:
		loot.stow()
	for i in loot.slots.size():
		if loot.slots[i] >= 0:
			loot._spend(loot.slots[i], false)
			loot.slots[i] = -1
	loot.changed.emit()


## Takes a new `kind` from at his feet into his pocket, as the act button does.
func take(kind: LootItem.Kind, id: int) -> void:
	loot._place(kind, player.global_position + Vector3(0.4, 0.05, 0.0), 0.0, id)
	loot.act(player)
	await wait(0.7)


## How many trees stand within `reach` of (x, z) `at`.
func trees_near(at: Vector3, reach: float) -> int:
	var count := 0
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TREE):
		if Vector2(piece.position.x - at.x, piece.position.z - at.z).length() < reach:
			count += 1
	return count


## The way round `at` (level) with the fewest trees in the way, out to `reach`.
func open_way(at: Vector3, reach: float, toward := Vector3.ZERO) -> Vector3:
	var best := Vector3.FORWARD
	var least := 1 << 30
	for k in 16:
		var way := Vector3(sin(k * TAU / 16.0), 0.0, cos(k * TAU / 16.0))
		var count := 0
		for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.TREE):
			var p := Vector3(piece.position.x, 0.0, piece.position.z)
			var rel := p - Vector3(at.x, 0.0, at.z)
			var along := rel.dot(way)
			if along > -1.0 and along < reach and (rel - way * along).length() < 3.0:
				count += 1
		# (and looking back at the camp, the clearing behind it if asked)
		var score := count * 10 - (int(way.dot(toward) * 3.0) if toward != Vector3.ZERO else 0)
		if score < least:
			least = score
			best = way
	return best


func _run() -> void:
	await wait(0.5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("LOOT", 1))
	world = main.world
	maze = world.maze
	loot = world.loot
	player = world.player
	eye = Camera3D.new()
	eye.fov = 55.0
	world.add_child(eye)
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	for runner in world.runners.runners:
		runner.process_mode = Node.PROCESS_MODE_DISABLED
		runner.visible = false
	world.day.set_hour(11.0)
	await wait(1.0)

	var left_camp: Campsite = null
	var people_camp: Campsite = null
	var fewest := 1 << 30
	for camp: Campsite in loot.camps:
		if camp.in_maze:
			continue
		var trees := trees_near(camp.global_position, 14.0)
		if camp.kind == Campsite.Kind.ABANDONED and trees < fewest:
			fewest = trees
			left_camp = camp
		if camp.kind == Campsite.Kind.OCCUPIED and people_camp == null:
			people_camp = camp

	# 1. A camp left behind, from the boy's height.
	if wanted("1") and left_camp:
		var c := left_camp.global_position
		var way := open_way(c, 9.0, -c.normalized())
		var side := Vector3(-way.z, 0.0, way.x)
		world.put_player(ground(c + way * 3.4 + side * 1.6) + Vector3.UP * 0.05, atan2(-way.x - side.x * 0.4, -way.z - side.z * 0.4))
		_fill_grass(c)
		await wait(1.5)
		frame(ground(c + way * 6.5 - side * 0.8) + Vector3.UP * 1.45, c + Vector3.UP * 0.25 - way * 0.5)
		await shot("1_abandoned_camp")
		frame(ground(c + way * 3.2 + side * 3.0) + Vector3.UP * 2.6, c - way * 0.6)
		await shot("1b_abandoned_camp_above")

	# 1c. A camp left in the maze, tallies scratched on the wall beside it.
	if wanted("1c"):
		for camp: Campsite in loot.camps:
			if not camp.in_maze or camp.wall.is_empty():
				continue
			world.day.set_hour(14.0)
			var c := camp.global_position
			var face: Vector3 = camp.wall[0]
			var out: Vector3 = camp.wall[1]
			var along := Vector3(-out.z, 0.0, out.x)
			world.put_player(c + out * 2.6 + Vector3.UP * 0.05, atan2(-out.x, -out.z))
			await wait(1.0)
			var view := _open_view(c, 2.0)
			frame(c + view * 7.0 + Vector3.UP * 4.2, (face * 0.25 + c * 0.75) + Vector3.UP * 0.6)
			await shot("1c_maze_camp")
			frame(face + out * 2.6 + along * 0.8 + Vector3.UP * 1.8, face + Vector3.UP * 2.0)
			await shot("1d_tallies_on_the_wall")
			break

	# 2. A camp with runners at it, at dusk, in the mist.
	if wanted("2") and people_camp:
		world.day.set_hour(DayCycle.SUNSET + 0.6)
		var c := people_camp.global_position
		var way := open_way(c, 9.0)
		var side := Vector3(-way.z, 0.0, way.x)
		world.put_player(ground(c + way * 4.6 - side * 2.4) + Vector3.UP * 0.05, atan2(-way.x, -way.z))
		_fill_grass(c)
		await wait(4.0)
		frame(ground(c + way * 6.2 + side * 3.4) + Vector3.UP * 1.9, c + Vector3.UP * 0.5 - side * 0.4)
		await shot("2_occupied_camp_dusk")
		# (and one of them pointing to what is worth taking, as the boy comes up)
		world.put_player(ground(c + way * 2.6) + Vector3.UP * 0.05, atan2(-way.x, -way.z))
		await wait(2.0)
		frame(ground(c + way * 4.6 + side * 3.2) + Vector3.UP * 1.6, c + Vector3.UP * 0.6)
		await shot("2b_camper_pointing")

	# 3. Its smoke, from far off across the clearing.
	if wanted("3") and people_camp:
		world.day.set_hour(16.5)
		var c := people_camp.global_position
		var away := (Vector3(-c.x, 0.0, -c.z)).normalized()
		var from := ground(c + away * 150.0) + Vector3.UP * 1.6
		world.put_player(ground(c + away * 146.0) + Vector3.UP * 0.05, atan2(-away.x, -away.z))
		await wait(3.0)
		frame(from, c + Vector3.UP * 14.0)
		await shot("3_smoke_from_afar")

	# 4. Each thing lying in the grass: all together, and each close.
	if wanted("4"):
		world.day.set_hour(10.0)
		var spot := Vector3(70.0, 0.0, 40.0)
		for k in 40:
			if absf(maze.ground_height(spot)) < 0.2 and trees_near(spot, 20.0) == 0:
				break
			spot = spot.rotated(Vector3.UP, 0.35)
		var made: Array = []
		var kinds := [LootItem.Kind.HOOK, LootItem.Kind.BACKPACK, LootItem.Kind.SPEAR, LootItem.Kind.TORCH, LootItem.Kind.FLARE, LootItem.Kind.MAP, LootItem.Kind.LADDER]
		for i in kinds.size():
			var at := ground(spot + Vector3((i - 3) * 1.25, 0.0, (i % 2) * 0.6)) + Vector3.UP * 0.02
			loot._tread(Vector2(at.x, at.z), 0.75)
			made.append(loot._place(kinds[i], at, 0.3 + i * 0.5, 800000 + i))
		world.put_player(ground(spot + Vector3(0.0, 0.0, -14.0)) + Vector3.UP * 0.05, 0.0)
		_fill_grass(spot)
		await wait(1.5)
		var h := maze.ground_height(spot)
		frame(spot + Vector3(0.0, h + 2.7, 5.6), spot + Vector3(0.0, h + 0.05, 0.3))
		await shot("4_items_in_grass")
		for i in made.size():
			var at: Vector3 = made[i].global_position
			frame(at + Vector3(0.45, 0.62, 0.8), at + Vector3.UP * 0.05)
			await shot("4_%d_%s" % [i, String(LootItem.SHORT[kinds[i]]).to_lower()])

	# A long hall of the first ring, for the rest.
	var hall := _hall_spot()
	var start: Vector3 = hall[0]
	var along: Vector3 = hall[1]
	var to_wall: Vector3 = hall[2]
	var face: Vector3 = hall[3]
	var side := Vector3(-along.z, 0.0, along.x)

	# 5. The boy with a torch in a hall, at night.
	if wanted("5"):
		empty_pockets()
		world.day.set_hour(21.0)
		world.put_player(start, atan2(along.x, along.z))
		await take(LootItem.Kind.TORCH, 810000)
		loot.draw(loot.slots.find(810000))
		world.put_player(start - along * 2.0, atan2(along.x, along.z))
		for i in 70:
			player.velocity = along * 1.6
			await physics_frame
		var him := player.global_position
		frame(him + along * 3.6 + side * 1.2 + Vector3.UP * 1.5, him + Vector3.UP * 1.25)
		await shot("5_torch_in_hall")
		frame(him - along * 3.8 + side * 0.9 + Vector3.UP * 1.8, him + along * 6.0 + Vector3.UP * 1.4)
		await shot("5b_torch_hall_ahead")

	# 6. On the grappling hook's rope, part way up the wall.
	if wanted("6"):
		empty_pockets()
		world.day.set_hour(15.0)
		world.put_player(start, 0.0)
		await take(LootItem.Kind.HOOK, 820000)
		world.put_player(face - to_wall * 3.4, atan2(to_wall.x, to_wall.z))
		world.camera.snap()
		await wait(0.3)
		loot.draw(loot.slots.find(820000))
		await wait(0.8)
		var far := face - to_wall * 12.0 + along * 4.0 + Vector3.UP * 1.6
		frame(far, face - to_wall * 2.0 + Vector3.UP * 5.0)
		player._act()
		await wait(0.42)
		await shot("6a_hook_thrown")
		for i in 120:
			await physics_frame
			if player.state == Player.State.ROPE:
				break
		await wait(0.3)
		Input.action_press(&"act")
		await wait(2.6)
		Input.action_release(&"act")
		await wait(0.2)
		var him := player.global_position
		frame(far, him + Vector3.UP * 2.0)
		await shot("6_on_the_hook")
		frame(him - to_wall * 3.0 + along * 2.2 + Vector3.UP * 3.6, him + Vector3.UP * 0.6)
		await shot("6b_on_the_hook_above")
		Input.action_press(&"act")
		for i in 600:
			await physics_frame
			if player.state == Player.State.HANG and i % 20 == 0:
				player._queue_jump()
			if player.state == Player.State.FREE and player.is_on_floor() and player.global_position.y > 5.0:
				break
		Input.action_release(&"act")
		await wait(0.6)
		him = player.global_position
		frame(him - to_wall * 6.0 + along * 3.5 + Vector3.UP * 2.0, him + Vector3.UP * 0.8)
		await shot("6c_up_on_the_ledge")
		world.put_player(start, 0.0)

	# 7. Throwing the spear.
	if wanted("7"):
		empty_pockets()
		world.day.set_hour(13.0)
		world.put_player(start, atan2(along.x, along.z))
		await take(LootItem.Kind.SPEAR, 830000)
		loot.draw(loot.slots.find(830000))
		world.put_player(start, atan2(along.x, along.z))
		await wait(0.6)
		var him := player.global_position
		frame(him + side * 3.6 + along * 1.6 + Vector3.UP * 1.3, him + Vector3.UP * 1.1 + along * 0.6)
		await shot("7a_spear_held")
		player.facing_yaw = atan2(along.x, along.z)
		player._act()
		await wait(0.38)
		await shot("7b_spear_wind_up")
		await wait(0.12)
		await shot("7c_spear_thrown")
		await wait(0.1)
		frame(him + side * 4.5 + along * 4.5 + Vector3.UP * 1.7, him + along * 5.0 + Vector3.UP * 1.8)
		await shot("7d_spear_in_flight")

	# 8. The inventory on the screen (the game's own camera).
	if wanted("8"):
		empty_pockets()
		world.day.set_hour(11.0)
		world.put_player(start, atan2(along.x, along.z))
		await take(LootItem.Kind.BACKPACK, 840001)
		await take(LootItem.Kind.HOOK, 840000)
		await take(LootItem.Kind.TORCH, 840002)
		await take(LootItem.Kind.FLARE, 840003)
		await take(LootItem.Kind.MAP, 840004)
		loot.draw(loot.slots.find(840002))
		loot._place(LootItem.Kind.SPEAR, start + along * 0.9 + Vector3.UP * 0.05, 0.4, 840005)
		world.put_player(start, atan2(along.x, along.z))
		world.camera.make_current()
		world.camera.snap()
		await wait(1.5)
		await shot("8_inventory", true)
		loot.said.emit("NO ROOM: DROP SOMETHING")
		loot.map_read.emit(8.0)
		await wait(0.3)
		await shot("8b_map_scrap", true)

	# w. Each weapon: held, and swung (wound up, and coming round).
	if wanted("w"):
		world.day.set_hour(13.0)
		var kinds := [[LootItem.Kind.STICK, "stick"], [LootItem.Kind.BAT, "bat"], [LootItem.Kind.SWORD, "sword"]]
		for i in kinds.size():
			empty_pockets()
			world.put_player(start, atan2(along.x, along.z))
			await take(kinds[i][0], 850000 + i)
			loot.draw(loot.slots.find(850000 + i))
			world.put_player(start, atan2(along.x, along.z))
			await wait(0.8)
			var him := player.global_position
			frame(him + side * 2.7 + along * 1.4 + Vector3.UP * 1.15, him + Vector3.UP * 0.75 + along * 0.3)
			await shot("w%d_%s_held" % [i, kinds[i][1]])
			player.facing_yaw = atan2(along.x, along.z)
			player._act()
			var swing: float = LootItem.MELEE[kinds[i][0]]["swing"]
			await wait(swing * 0.22)
			await shot("w%d_%s_wind_up" % [i, kinds[i][1]])
			await wait(swing * 0.3)
			await shot("w%d_%s_swung" % [i, kinds[i][1]])
			await wait(0.8)

	# g. The guns: held, and brought up and fired (the flash); and a ghoul felled by a shot.
	if wanted("g"):
		world.day.set_hour(13.0)
		var guns := [[LootItem.Kind.REVOLVER, "revolver"], [LootItem.Kind.SHOTGUN, "shotgun"]]
		for i in guns.size():
			empty_pockets()
			world.put_player(start, atan2(along.x, along.z))
			loot._place(guns[i][0], player.global_position + Vector3(0.4, 0.05, 0.0), 0.0, 860000 + i).set(&"uses", 2)
			loot.act(player)
			await wait(0.7)
			loot.draw(loot.slots.find(860000 + i))
			world.put_player(start, atan2(along.x, along.z))
			await wait(0.8)
			var him := player.global_position
			frame(him + side * 2.6 + along * 1.2 + Vector3.UP * 1.15, him + Vector3.UP * 0.8 + along * 0.4)
			await shot("g%d_%s_held" % [i, guns[i][1]])
			player.facing_yaw = atan2(along.x, along.z)
			player._act()
			for k in 90:
				await physics_frame
				if int(loot._item(860000 + i).get(&"uses")) < 2:
					break
			await shot("g%d_%s_fired" % [i, guns[i][1]], true)
			await wait(1.6)
		# A ghoul down the hall, shot with the revolver: going over.
		var ghoul := MazeGhoul.new()
		ghoul.keep_out_of_clearing = false
		var at := start + along * 7.0
		world.enemies.add(ghoul, maze.cell_at(at), atan2(-along.x, -along.z), 3, at - maze.world(maze.cell_at(at)))
		ghoul.set_physics_process(false)
		empty_pockets()
		world.put_player(start, atan2(along.x, along.z))
		loot._place(LootItem.Kind.REVOLVER, player.global_position + Vector3(0.4, 0.05, 0.0), 0.0, 860010).set(&"uses", 3)
		loot.act(player)
		await wait(0.7)
		loot.draw(loot.slots.find(860010))
		await wait(0.6)
		player.facing_yaw = atan2(along.x, along.z)
		player._act()
		for k in 90:
			await physics_frame
			if Stagger.felled(ghoul):
				break
		var him := player.global_position
		frame(him - along * 2.2 + side * 1.8 + Vector3.UP * 1.7, him + along * 6.0 + Vector3.UP * 0.8)
		await shot("g2_ghoul_shot")
		await wait(0.9)
		await shot("g3_ghoul_down")
		# The HUD while he holds it: its rounds and his spare ones.
		loot.ammo[LootItem.Kind.ROUNDS] = 3
		loot.changed.emit()
		world.camera.make_current()
		world.camera.snap()
		await wait(1.0)
		await shot("g4_gun_hud", true)

	# l. What there is to fight with, lying in the mud of a hall.
	if wanted("l"):
		empty_pockets()
		world.day.set_hour(11.0)
		var kinds := [LootItem.Kind.STICK, LootItem.Kind.BAT, LootItem.Kind.SWORD, LootItem.Kind.REVOLVER, LootItem.Kind.SHOTGUN, LootItem.Kind.ROUNDS, LootItem.Kind.SHELLS]
		var spot := start + along * 3.0
		var made: Array = []
		for i in kinds.size():
			var at := spot + side * ((i - 3) * 0.75) + along * ((i % 2) * 0.5)
			at.y = maze.ground_height(at) + 0.02
			made.append(loot._place(kinds[i], at, 0.4 + i * 0.7, 870000 + i))
		world.put_player(start - along * 6.0, atan2(along.x, along.z))
		await wait(1.0)
		frame(spot - along * 3.4 + Vector3.UP * 2.2, spot + Vector3.UP * 0.05)
		await shot("l_weapons_lying")
		for i in made.size():
			var at: Vector3 = made[i].global_position
			frame(at + Vector3(0.45, 0.55, 0.75), at + Vector3.UP * 0.04)
			await shot("l%d_%s" % [i, String(LootItem.SHORT[kinds[i]]).to_lower()])

	# r. A friend (a RemotePlayer, as the room shows them) with a bat, swinging it,
	# and with a shotgun, firing it: what the room's news makes of them.
	if wanted("r"):
		empty_pockets()
		world.day.set_hour(13.0)
		world.put_player(start - along * 4.0, atan2(along.x, along.z))
		var other := RemotePlayer.new()
		world.add_child(other)
		other.hear(start + side * 1.5, Vector3.ZERO, atan2(along.x, along.z), true)
		world.remotes[1] = other
		Looks.apply(other.rig, Looks.decode("", 1))
		loot._place(LootItem.Kind.BAT, start + side * 3.0, 0.0, 880000)
		loot.hear({"loot": "hand", "id": 880000, "seat": 1, "lit": false, "fuel": 0.0, "uses": 10}, 1)
		await wait(0.8)
		var him := other.global_position
		frame(him + side * 2.8 + along * 1.4 + Vector3.UP * 1.15, him + Vector3.UP * 0.75)
		await shot("r0_friend_bat")
		loot.hear({"loot": "swing", "seat": 1}, 1)
		await wait(0.33)
		await shot("r1_friend_swinging")
		await wait(0.6)
		loot._place(LootItem.Kind.SHOTGUN, start + side * 3.5, 0.0, 880001)
		loot.hear({"loot": "hand", "id": 880001, "seat": 1, "lit": false, "fuel": 0.0, "uses": 2}, 1)
		await wait(0.5)
		var muzzle: Vector3 = him + Vector3.UP * 1.0 + along * 0.6
		loot.hear({"loot": "shot", "seat": 1, "id": 880001, "kind": LootItem.Kind.SHOTGUN, "from": [muzzle.x, muzzle.y, muzzle.z],
			"to": [muzzle.x + along.x * 20.0, muzzle.y, muzzle.z + along.z * 20.0], "uses": 1}, 1)
		await wait(0.3)
		await shot("r2_friend_firing")

	# 9. Grappling hook spots: a route of corbels up a wall, the ring above marked
	# in reach (and the next faintly); and the hook thrown at a hanging vine.
	if wanted("9"):
		empty_pockets()
		world.day.set_hour(15.0)
		world.put_player(start, 0.0)
		await take(LootItem.Kind.HOOK, 850000)
		var route := _route_start()
		if not route.is_empty():
			var ring_at: Vector3 = route[0]
			var out: Vector3 = route[1]
			var flank := Vector3(-out.z, 0.0, out.x)
			world.put_player(route[2] + out * 0.2 + flank * 1.2 + Vector3.UP * 0.05, atan2(-out.x, -out.z))
			world.camera.snap()
			await wait(0.3)
			loot.draw(loot.slots.find(850000))
			await wait(0.8)
			var him := player.global_position
			frame(him + out * 7.0 + flank * 3.0 + Vector3.UP * 1.0, him.lerp(ring_at, 0.6) - out * 0.5)
			await shot("9a_spot_marked")
			frame(him + out * 16.0 + flank * 6.0 + Vector3.UP * 4.0, him + Vector3.UP * 8.0)
			await shot("9b_route_up_the_wall")
			player._act()
			for i in 120:
				await physics_frame
				if player.state == Player.State.ROPE:
					break
			await wait(0.3)
			Input.action_press(&"act")
			for i in 900:
				await physics_frame
				if player.state == Player.State.HANG and i % 20 == 0:
					player._queue_jump()
				if player.state == Player.State.FREE and player.is_on_floor() and player.global_position.y > ring_at.y - 0.5:
					break
			Input.action_release(&"act")
			await wait(1.0)
			him = player.global_position
			frame(him + out * 6.0 + flank * 2.5 + Vector3.UP * 0.5, him + Vector3.UP * 2.5)
			await shot("9d_on_the_corbel_next_marked")
		var hanging := _hanging_vine()
		if not hanging.is_empty():
			var vine: Vine = hanging[0]
			var stand: Vector3 = hanging[1]
			loot.stow()
			var to_vine := vine.global_position - stand
			to_vine.y = 0.0
			world.put_player(stand, atan2(to_vine.x, to_vine.z))
			world.camera.snap()
			await wait(0.4)
			loot.draw(loot.slots.find(850000))
			await wait(0.8)
			var across := to_vine.normalized().cross(Vector3.UP)
			var mid := stand + to_vine * 0.5
			frame(mid + across * 7.5 + Vector3.UP * 2.2, mid + Vector3.UP * 2.6)
			await shot("9e_vine_marked")
			player._act()
			for i in 240:
				await physics_frame
				if player.state == Player.State.ROPE and is_instance_valid(player._grapple) and player._grapple.get(&"hauling"):
					break
			await wait(0.15)
			await shot("9f_hauled_in_to_the_vine")
			for i in 120:
				await physics_frame
				if player._rope == vine:
					break
			await wait(0.35)
			await shot("9g_on_the_hooked_vine")
			await wait(0.5)
			var him := player.global_position
			frame(him + across * 6.0 + Vector3.UP * 0.5, him + Vector3.UP * 0.8)
			await shot("9h_on_the_hooked_vine_close")

	print("done")
	quit()


## The first corbel of a hook route in the first ring (as tests/loot_test.gd
## finds it): [its ring, the way out of its wall, where to stand under it].
func _route_start() -> Array:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for spots: GrappleSpots in world.maze_features().spots:
		for i in spots.points.size():
			if spots.looks[i] != GrappleSpots.Look.RING or maze.ring_of(maze.cell_at(spots.points[i])) != 1:
				continue
			var at := spots.points[i]
			var out := spots.out_of(i)
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.DOWN * 0.3 - out * 1.3, at + Vector3.DOWN * 0.3 - out * 1.6, 1))
			var behind := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + out * 0.3 + Vector3.DOWN * 0.3, at - out * 0.5 + Vector3.DOWN * 0.3, 1))
			if wall.is_empty() or behind.is_empty() or (behind.position as Vector3).distance_to(at) > 0.6:
				continue
			var under := at - out * 0.5 + Vector3.DOWN * 1.0
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(under, under + Vector3.DOWN * 12.0, 1))
			if down.is_empty() or under.y - (down.position as Vector3).y > 8.0 or (down.normal as Vector3).y < 0.8:
				continue
			return [at, out, Vector3(at.x, (down.position as Vector3).y, at.z) - out * (MazeFeatures.CORBEL.y + GrappleSpots.RING_OUT - 0.65)]
	return []


## A hanging vine in the first ring out of reach standing, and where to stand 3 m from it: [the vine, there].
func _hanging_vine() -> Array:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for vine: Vine in world.maze_features().vines:
		var top := vine.global_position
		if maze.ring_of(maze.cell_at(top)) != 1:
			continue
		var ground_y := maze.ground_height(top)
		var bottom := vine.bottom_y()
		if top.y - ground_y < 6.0 or bottom - ground_y < 1.8 or bottom - ground_y > 4.0:
			continue
		for k in 8:
			var way := Vector3(sin(k * TAU / 8.0), 0.0, cos(k * TAU / 8.0))
			var stand := Vector3(top.x, ground_y + 0.05, top.z) + way * 3.0
			var low := Vector3(top.x, ground_y + 1.0, top.z)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(low, stand + Vector3.UP * 1.0 + way * 0.6, 1)).is_empty():
				continue
			# (and room to look at it from the side)
			var across := way.cross(Vector3.UP)
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(low + way * 1.5, low + way * 1.5 + across * 7.0, 1)).is_empty():
				continue
			return [vine, stand]
	return []


## Fills the grass round `at` now (it fills as the camera comes near, a few squares a frame).
func _fill_grass(at: Vector3) -> void:
	for field: Grass in root.get_tree().get_nodes_in_group(Grass.FIELDS):
		field.fill_near(at, 40.0)


## Somewhere in a long hall of the first ring: [where (the middle of the hall),
## the way along it (open 12 m each way), the way to a wall with a ledge along
## it, a point 1 m off that wall's face].
func _hall_spot() -> Array:
	var nav := MazeNav.new(maze)
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or not nav.allowed(cell) or maze.solid.has(cell) or maze.depth_in_ring(cell) < 2:
			continue
		for step: Vector2i in Maze.STEPS:
			var along := Vector3(step.x, 0.0, step.y)
			var side := Vector2i(-step.y, step.x)
			for s: Vector2i in [side, -side]:
				if not maze.blocked(cell, s) or maze.ring_wall(cell, s) or maze.blocked(cell, -s):
					continue
				var to_wall := Vector3(s.x, 0.0, s.y)
				var face := maze.world(cell) + to_wall * (Maze.CELL * 0.5 - maze.wall_thick(cell, s) * 0.5)
				# (the middle of the hall: half way across to the far wall)
				var p := face - to_wall * 7.0
				if not nav.line_free(p - along * 12.0, p + along * 12.0, 3.0) or not nav.clear_of_walls(face - to_wall * 12.0, 0.5):
					continue
				p.y = 0.05
				return [p, along, to_wall, face - to_wall * 1.0 + Vector3.UP * 0.05]
	return [Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT, Vector3.ZERO]


## The way out from `at` (level) with the most room before a wall, at `height`
## up, for a camera to stand back along.
func _open_view(at: Vector3, height: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best := Vector3.FORWARD
	var most := 0.0
	for k in 16:
		var way := Vector3(sin(k * TAU / 16.0), 0.0, cos(k * TAU / 16.0))
		var from := at + Vector3.UP * height
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 14.0, 1))
		var room := 14.0 if hit.is_empty() else from.distance_to(hit["position"])
		if room > most:
			most = room
			best = way
	return best
