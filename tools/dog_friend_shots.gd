extends SceneTree
## Pictures of a feral dog made a friend with meat (MazeDog, Loot's meat), in a
## hall of a real round, landscape: the meat lying, and in the boy's hand; the
## dog eating it; trotting at heel beside him as he walks, and sat by him; close
## on its glad look; and facing down a ghoul that comes at him (barking,
## hackles up, between him and it), and springing at it. Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/dog_friend_shots.gd -- <folder> [only]

var main: Node
var folder := "dog_friend_shots"
var only := ""
var world
var maze: Maze
var loot
var eye: Camera3D
var player: Player
var nav: MazeNav


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
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
	eye.make_current()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])
	world.camera.make_current()


func wait(seconds: float) -> void:
	for i in maxi(roundi(seconds * 60.0), 1):
		await physics_frame


func frame(from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)


func _run() -> void:
	await wait(0.5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("DOGS", 1))
	world = main.world
	maze = world.maze
	loot = world.loot
	player = world.player
	nav = MazeNav.new(maze)
	eye = Camera3D.new()
	eye.fov = 50.0
	world.add_child(eye)
	for enemy: MazeEnemy in world.enemies.enemies:
		enemy.die()
	if world.ecology:
		world.ecology._dead.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	for runner in world.runners.runners:
		runner.process_mode = Node.PROCESS_MODE_DISABLED
		runner.visible = false
	world.day.set_hour(13.0)
	var hall := _hall_spot()
	var start: Vector3 = hall[0]
	var along: Vector3 = hall[1]
	var side := Vector3(-along.z, 0.0, along.x)
	var up := Vector3.UP
	world.put_player(start, atan2(along.x, along.z))
	world.camera.snap()
	await wait(1.0)

	# 1. Meat lying in the hall, and in his hand.
	var meat: Node3D = loot._place(LootItem.Kind.MEAT, _ground(start + along * 1.6 + side * 0.4), 0.7, 990100)
	await wait(0.5)
	if wanted("1"):
		frame(meat.global_position + along * 0.9 + side * 0.5 + up * 0.55, meat.global_position + up * 0.04)
		await shot("1_meat_lying")
	loot.act(player)
	await wait(0.2)
	world.put_player(start + along * 1.6, atan2(along.x, along.z))
	await wait(0.8)
	loot.draw(loot.slots.find(990100))
	await wait(0.5)
	if wanted("1"):
		var hand: Vector3 = (player.get_node(^"Rig") as CharacterRig).hand_position()
		frame(hand + along * 1.5 + side * 0.9 + up * 0.25, hand - up * 0.15)
		await shot("1b_meat_in_hand")

	# 2. A dog ahead: held out, it eats it from his hand, and is his friend.
	var dog := MazeDog.new()
	var dog_at := start + along * 3.4
	world.enemies.add(dog, maze.cell_at(dog_at), atan2(-along.x, -along.z), 3, dog_at - maze.world(maze.cell_at(dog_at)))
	dog.sight_range = 0.0
	dog.hear_range = 0.0
	dog.roam_speed = 0.0
	dog._rest_left = 999.0
	await wait(1.0)
	dog.hunger = 0.9
	await wait(1.0)
	player.facing_yaw = atan2(along.x, along.z)
	loot.act(player)
	await wait(1.2)
	if wanted("2"):
		var d := dog.global_position
		frame(d + side * 2.6 - along * 0.6 + up * 1.0, d - along * 0.6 + up * 0.45)
		await shot("2_eating_from_his_hand")
	await wait(2.5)
	dog.sight_range = 40.0
	dog.hear_range = 11.0

	# 3. At heel as he walks along the hall, and sat by him when he stands.
	world.put_player(start, atan2(along.x, along.z))
	world.camera.snap()
	await wait(1.5)
	Input.action_press(&"move_up", 0.55)
	await wait(2.6)
	if wanted("3"):
		var p := player.global_position
		frame(p + along * 5.0 + side * 2.4 + up * 1.2, p - along * 0.8 + up * 0.7)
		await shot("3_at_heel")
		var d := dog.global_position
		frame(d + side * 3.4 + along * 0.5 + up * 0.7, d + up * 0.5)
		await shot("3b_at_heel_side")
	Input.action_release(&"move_up")
	await wait(6.0)
	if wanted("3"):
		var p := player.global_position
		var d := dog.global_position
		var mid := p.lerp(d, 0.5)
		var across := Vector3(-(d - p).z, 0.0, (d - p).x).normalized()
		frame(mid + across * 4.0 + up * 1.3, mid + up * 0.6)
		await shot("3c_sat_by_him")
		frame(d + Basis(up, dog.facing_yaw) * Vector3(0.9, 0.45, 1.6), d + up * 0.7)
		await shot("3d_glad_close")
		frame(d + Basis(up, dog.facing_yaw) * Vector3(-1.4, 0.6, -1.5), d + up * 0.6)
		await shot("3e_tail_up")

	# 4. A ghoul comes at him: the dog faces it down, barking, and goes for it.
	if wanted("4"):
		var p := player.global_position
		var way := Vector3.ZERO
		for step: Vector2i in Maze.STEPS:
			var to := Vector3(step.x, 0.0, step.y)
			if nav.line_free(p, p + to * 14.0, 0.8):
				way = to
				break
		var ghoul := MazeGhoul.new()
		ghoul.keep_out_of_clearing = false
		var at := p + way * 13.0
		world.enemies.add(ghoul, maze.cell_at(at), atan2(-way.x, -way.z), 5, at - maze.world(maze.cell_at(at)))
		player.facing_yaw = atan2(way.x, way.z)
		var warned := false
		for i in 600:
			await physics_frame
			if dog.mode == MazeDog.Mode.WARN or dog.mode == MazeDog.Mode.GUARD:
				warned = true
				if dog.global_position.distance_to(ghoul.global_position) < 8.0:
					break
		print("warned: %s, mode %s" % [warned, MazeDog.Mode.keys()[dog.mode]])
		var d := dog.global_position
		var g := ghoul.global_position
		var w := (g - d).normalized()
		var x := Vector3(-w.z, 0.0, w.x)
		frame(player.global_position - w * 2.2 + x * 0.8 + up * 1.7, d.lerp(g, 0.45) + up * 0.8)
		await shot("4_facing_down_the_ghoul")
		frame(d.lerp(g, 0.5) + x * 5.5 + up * 1.1, d.lerp(g, 0.5) + up * 0.7)
		await shot("4b_between_them_side")
		frame(d + w * 1.6 + x * 1.2 + up * 0.75, d + up * 0.75)
		await shot("4c_snarling_close")
		var sprang := false
		for i in 600:
			await physics_frame
			if dog.mode == MazeDog.Mode.LUNGE and dog.dog.lunge_stage() == Dog.Lunge.SPRING:
				sprang = true
				break
		if sprang:
			d = dog.global_position
			g = ghoul.global_position
			w = (g - d).normalized()
			x = Vector3(-w.z, 0.0, w.x)
			frame(d.lerp(g, 0.5) + x * 5.0 + up * 1.0, d.lerp(g, 0.5) + up * 0.8)
			await shot("4d_springing_at_it")
		for i in 120:
			await physics_frame
			if Stagger.on(ghoul):
				break
		frame(d.lerp(g, 0.5) + x * 5.5 - w * 1.0 + up * 1.4, d.lerp(g, 0.6) + up * 0.8)
		await shot("4e_ghoul_staggered")
	quit()


func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, maze.ground_height(at) + 0.02, at.z)


func _hall_spot() -> Array:
	var best: Array = [Vector3.ZERO, Vector3.FORWARD]
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or not nav.allowed(cell) or maze.solid.has(cell):
			continue
		for step: Vector2i in Maze.STEPS:
			var way := Vector3(step.x, 0.0, step.y)
			var p := nav.point(cell)
			if nav.line_free(p - way * 3.0, p + way * 22.0, 1.2):
				return [p + Vector3.UP * 0.05, way]
	return best
