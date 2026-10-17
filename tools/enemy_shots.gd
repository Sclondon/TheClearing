extends SceneTree
## Pictures of the things that hunt in the maze (scripts/enemies/), in a passage
## of a real round (World, so the light and the mist are the game's): Apophis
## coming down a passage, rearing to strike, and from above; a pack of mummies;
## the other kinds; a mummy's swipe. Says how many draws a frame takes with them
## and without. Needs a real window (the engine draws nothing headless):
##
##     godot --path . --resolution 720x1280 -s res://tools/enemy_shots.gd -- <folder>

var folder := "enemy_shots"
var world
var maze
var nav
var boy
var cell := Vector2i.ZERO
var way := Vector2i.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _setup() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	boy.add_to_group(&"maze_players")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
		if until.is_valid() and until.call():
			return true
	return false


## A passage cell with at least `run` open cells straight on from it, and that way.
func straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(2):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


## The boy at `cell`, the camera behind him looking along `way`.
func stand(at: Vector2i, along: Vector2i, back := 0.0) -> void:
	boy.global_position = maze.world(at) - Vector3(along.x, 0, along.y) * back + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(float(along.x), float(along.y))
	world.camera._yaw = atan2(float(-along.x), float(-along.y))
	world.camera.snap()


func clear() -> void:
	for child in world.get_children():
		if child is MazeEnemy:
			child.free()


func spawn(enemy: MazeEnemy, at: Vector3, facing: float) -> MazeEnemy:
	enemy.maze = maze
	enemy.position = at
	enemy.rotation.y = facing
	world.add_child(enemy)
	return enemy


func draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _run() -> void:
	_setup()
	await wait(0.5)
	var found := straight_run(4)
	cell = found[0]
	way = found[1]
	var along := Vector3(way.x, 0, way.y)
	stand(cell, way)
	await wait(1.0)
	var bare := await draws()
	print("draws with nobody about: %d" % bare)

	# --- Apophis, coming down the passage at him ---
	var snake := Apophis.new()
	snake.start_resting = false
	spawn(snake, maze.world(cell + way * 3) + Vector3.UP * 0.05, atan2(-along.x, -along.z))
	snake.notice(boy)
	await wait(3.4)
	await shot("1_apophis_coming")
	print("draws with Apophis: %d (+%d)" % [await draws(), (await draws()) - bare])
	await wait(10.0, func() -> bool: return snake.state == Apophis.State.STRIKE and snake._time > 0.45)
	await shot("2_apophis_strike")
	# From up on the wall: how he lies through the passages.
	await wait(4.0)
	var above := Camera3D.new()
	world.add_child(above)
	var head: Vector3 = snake.spine[Apophis.POINTS / 3]
	above.position = head + Vector3(6.0, 70.0, 8.0)
	above.fov = 50.0
	above.look_at(head)
	above.make_current()
	await wait(0.3)
	await shot("3_apophis_above")
	above.queue_free()
	world.camera.make_current()
	clear()
	# Lying at rest along a passage.
	snake = Apophis.new()
	spawn(snake, maze.world(cell + way * 2) + Vector3.UP * 0.05, atan2(-along.x, -along.z))
	stand(cell, way, 2.0)
	boy.remove_from_group(&"maze_players")
	await wait(1.0)
	print("resting: %s at %s, head drawn at %s; the boy at %s" % [Apophis.State.keys()[snake.state], snake.global_position, snake.head_at, boy.global_position])
	await shot("4_apophis_resting")
	boy.add_to_group(&"maze_players")
	clear()

	# --- A pack of mummies ---
	stand(cell, way)
	var across := Vector3(-way.y, 0, way.x)
	var kinds := [Mummy.Kind.SHAMBLER, Mummy.Kind.BRUTE, Mummy.Kind.PRIEST]
	for k in kinds.size():
		var mummy := Mummy.new()
		mummy.kind = kinds[k]
		spawn(mummy, maze.world(cell + way * 2) + across * (k - 1) * 2.4 - along * (k % 2) * 2.0 + Vector3.UP * 0.05, atan2(-along.x, -along.z))
		mummy.notice(boy)
	await wait(5.0)
	await shot("5_mummies_shambler_brute_priest")
	print("draws with three mummies: %d (+%d)" % [await draws(), (await draws()) - bare])
	clear()
	stand(cell, way)
	kinds = [Mummy.Kind.CRAWLER, Mummy.Kind.CHILD, Mummy.Kind.ROYAL]
	for k in kinds.size():
		var mummy := Mummy.new()
		mummy.kind = kinds[k]
		spawn(mummy, maze.world(cell + way * 2) + across * (k - 1) * 2.6 + Vector3.UP * 0.05, atan2(-along.x, -along.z))
		mummy.notice(boy)
	await wait(2.5)
	await shot("6_mummies_crawler_child_royal")
	clear()
	# One rears to swipe at him.
	stand(cell, way)
	var swiper := Mummy.new()
	spawn(swiper, maze.world(cell) + along * 4.0 + Vector3.UP * 0.05, atan2(-along.x, -along.z))
	swiper.notice(boy)
	await wait(8.0, func() -> bool: return swiper._rig.stage() == MummyRig.Stage.WIND_UP and swiper._rig.strikes_in() < 0.15)
	await shot("7_mummy_swipe")
	world.camera._yaw += 1.2
	await wait(0.6)
	await shot("8_mummy_side")
	clear()

	# --- What the whole set costs, near ---
	var crowd := MazeEnemies.new()
	world.add_child(crowd)
	crowd.populate(maze, 5)
	var first: MazeEnemy = crowd.enemies[1]
	stand(maze.cell_at(first.global_position), way, 0.0)
	await wait(1.0)
	print("draws with the whole set (%d), standing among one pack: %d" % [crowd.enemies.size(), await draws()])
	await shot("9_a_pack_in_its_lair")
	quit()
