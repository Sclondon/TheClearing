extends SceneTree
## Pictures of the aliens (scripts/enemies/alien.gd) in a passage of a real
## round (World, so the light and the mist are the game's): two coming down a
## passage, one raising its hand and its light on the boy, the warning shimmer
## ahead of him and one coming out of it, and close to, the face and the whole
## figure in the mist. Says how many draws a frame takes with them and without.
## (The round's own enemies are put away first.) Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/alien_shots.gd -- <folder>

var folder := "alien_shots"
var world
var maze
var nav
var boy
var cell := Vector2i.ZERO
var way := Vector2i.ZERO
var behind: Camera3D


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
	for hunter: Node3D in [world.enemies, world.griever]:
		hunter.visible = false
		hunter.process_mode = Node.PROCESS_MODE_DISABLED


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


func draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


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


## The boy at `at`, facing along `along`, the camera behind him.
func stand(at: Vector3, along: Vector2i) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.facing_yaw = atan2(float(along.x), float(along.y))
	boy.rotation.y = boy.facing_yaw
	# (a camera of its own, further back and higher than the game's, to see down the passage past him)
	if behind == null:
		behind = Camera3D.new()
		behind.fov = 55.0
		world.add_child(behind)
	var ahead := Vector3(along.x, 0.0, along.y)
	behind.position = at - ahead * 6.5 + Vector3.UP * 3.0 + Vector3(-ahead.z, 0.0, ahead.x) * 1.2
	behind.look_at(at + ahead * 12.0 + Vector3.UP * 1.3, Vector3.UP)
	behind.make_current()


func spawn(at: Vector3, facing: float) -> Alien:
	var alien := Alien.new()
	alien.maze = maze
	alien.position = at
	alien.rotation.y = facing
	world.add_child(alien)
	return alien


func clear() -> void:
	for child in world.get_children():
		if child is Alien:
			child.free()


func _run() -> void:
	_setup()
	await wait(0.5)
	var found := straight_run(4)
	cell = found[0]
	way = found[1]
	var along := Vector3(way.x, 0, way.y)
	var start: Vector3 = maze.world(cell)
	stand(start, way)
	await wait(1.0)
	var bare := await draws()
	print("draws with nobody about: %d" % bare)

	# --- Two coming down the passage at him ---
	var side := Vector3(-along.z, 0.0, along.x)
	var one := spawn(start + along * 30.0 + side * 1.5, atan2(-along.x, -along.z))
	var two := spawn(start + along * 34.0 - side * 2.0, atan2(-along.x, -along.z))
	for alien: Alien in [one, two]:
		alien.blink_every = 1000.0
		alien.notice(boy)
	await wait(4.0)
	await shot("1_two_coming")
	var with := await draws()
	print("draws with two aliens: %d (+%d)" % [with, with - bare])
	# Close: the hand up, then its light on him.
	two.global_position = start + along * 40.0
	one.global_position = start + along * 4.0
	await wait(10.0, func() -> bool: return one.mode == Alien.Mode.REACHING)
	await wait(0.55)
	await shot("2_hand_raised")
	await wait(10.0, func() -> bool: return one.body().reach_stage() == AlienBody.Reach.GRAB)
	await wait(0.25)
	await shot("3_in_its_light")
	clear()

	# --- The warning ahead of him, and one coming out of it ---
	stand(start, way)
	await wait(0.3)
	var three := spawn(start - along * 30.0, atan2(along.x, along.z))
	three.walk_speed = 0.0
	three.blink_every = 1000.0
	three.notice(boy)
	await wait(0.3)
	var there: Vector3 = start + along * 16.0 + Vector3.UP * 0.05
	three.blink_target = there
	three.mode = Alien.Mode.WARNING
	three._warning_left = three.warning
	three.body().shimmer(there, three.warning)
	await wait(0.8)
	await shot("4_warning_ahead")
	await wait(10.0, func() -> bool: return three.body().blink_stage() == AlienBody.Blink.IN)
	await wait(0.2)
	await shot("5_coming_out")
	await wait(0.8)
	await shot("6_come")

	# --- Close to, in the mist ---
	clear()
	var four := spawn(start + along * 6.0, atan2(-along.x, -along.z))
	four.walk_speed = 0.0
	four.blink_every = 1000.0
	stand(start, way)
	four.notice(boy)
	await wait(2.0)
	var close := Camera3D.new()
	close.fov = 40.0
	world.add_child(close)
	var face: Vector3 = four.global_position + Vector3.UP * 2.0
	close.position = face - along * 1.6 + side * 0.5 + Vector3.UP * 0.05
	close.look_at(face, Vector3.UP)
	close.make_current()
	await wait(0.3)
	await shot("7_face")
	close.position = four.global_position - along * 5.5 + side * 2.5 + Vector3.UP * 1.6
	close.look_at(four.global_position + Vector3.UP * 1.15, Vector3.UP)
	await wait(0.1)
	await shot("8_whole")
	close.queue_free()
	behind.make_current()
	quit()
