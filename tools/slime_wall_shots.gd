extends SceneTree
## Pictures of the slime wall (creatures/slime_wall/, scripts/enemies/maze_slime_wall.gd).
## `close`: in a bare yard between two low walls, in the maze's light: front,
## three-quarter, side, looking through it at the boy behind, close in on what
## it has eaten, going (its front heaving), squeezing into a narrow gap, and
## holding the boy. `maze`: in a real round, filling a hall, coming at the boy,
## and with him in it. Says how many draws it takes. Needs a real window:
##
##     godot --audio-driver Dummy --path . --resolution 720x1280 -s res://tools/slime_wall_shots.gd -- <folder> [close|maze]

var folder := "slime_wall_shots"
var which := "all"
var camera: Camera3D
var boy


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		which = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float) -> void:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < seconds * 1000.0:
		await process_frame


func look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at)


func _run() -> void:
	if which in ["all", "close"]:
		await _close()
	if which in ["all", "maze"]:
		await _maze()
	quit()


func _block(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	body.add_child(mesh)


func _close() -> void:
	var yard := Node3D.new()
	root.add_child(yard)
	MazeLight.put(yard)
	_block(yard, Vector3(0, -0.5, 0), Vector3(80, 1, 120), Color(0.36, 0.36, 0.33))
	# Walls 12 m apart, low (so it can be seen from the side over them), and a narrow gap further on.
	for side in [-1.0, 1.0]:
		_block(yard, Vector3(side * 6.5, 1.25, -5), Vector3(1.0, 2.5, 50), Color(0.5, 0.5, 0.48))
		_block(yard, Vector3(side * 2.6, 1.25, -45), Vector3(1.0, 2.5, 10), Color(0.5, 0.5, 0.48))
		_block(yard, Vector3(side * 4.55, 1.25, -40.5), Vector3(4.0, 2.5, 1.0), Color(0.5, 0.5, 0.48))
	# Some things behind it to be seen through it.
	_block(yard, Vector3(-3.0, 1.5, -14), Vector3(1.0, 3.0, 1.0), Color(0.6, 0.6, 0.55))
	_block(yard, Vector3(3.5, 0.75, -11), Vector3(2.0, 1.5, 1.0), Color(0.45, 0.42, 0.38))
	camera = Camera3D.new()
	yard.add_child(camera)
	camera.make_current()
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	yard.add_child(boy)
	boy.global_position = Vector3(1.0, 0.1, -6.5)
	boy.rotation.y = 0.0

	var slime := SlimeWall.new()
	slime.contents_seed = 4
	yard.add_child(slime)
	slime.global_position = Vector3(0, 0, 0)
	slime.settle()
	await wait(1.5)
	print("fitted %.2f m wide, %.2f m high" % [slime.fitted_width, slime.fitted_height()])

	look(Vector3(0, 3.2, 13.5), Vector3(0, 3.0, 0), 55.0)
	await shot("c1_front")
	look(Vector3(10.5, 6.0, 9.5), Vector3(0, 2.6, 0), 55.0)
	await shot("c2_three_quarter")
	look(Vector3(13.0, 3.0, 0.0), Vector3(0, 3.0, 0), 52.0)
	await shot("c3_side")
	# Through it at the boy behind.
	boy.global_position = Vector3(0.5, 0.1, -5.0)
	look(Vector3(-1.0, 2.0, 8.0), Vector3(0.5, 1.4, -5.0), 45.0)
	await wait(0.3)
	await shot("c4_through_at_the_boy")
	# Close in on what it has eaten.
	look(Vector3(-1.5, 3.2, 5.2), Vector3(-0.8, 3.0, 0.0), 50.0)
	await shot("c5_close_in")
	look(Vector3(2.5, 1.2, 4.6), Vector3(2.0, 1.0, 0.0), 55.0)
	await shot("c6_low_close")
	# Going: moved along at its pace, seen from ahead and to one side.
	boy.global_position = Vector3(0.0, 0.1, 30.0)
	var start := slime.global_position
	for i in 150:
		slime.global_position = start + Vector3(0, 0, -1.3 * i / 60.0)
		slime.rotation.y = PI
		await process_frame
	look(slime.global_position + Vector3(9.0, 5.0, -10.0), slime.global_position + Vector3(0, 2.5, 0), 55.0)
	for i in 3:
		for k in 20:
			slime.global_position += Vector3(0, 0, -1.3 / 60.0)
			await process_frame
		await shot("c7_going_%d" % i)
	# Squeezing into the narrow gap ahead.
	slime.global_position = Vector3(0, 0, -33.0)
	slime.settle()
	for i in 900:
		slime.global_position += Vector3(0, 0, -1.3 / 60.0)
		if slime.global_position.z < -42.5:
			break
		await process_frame
	await wait(0.5)
	print("in the gap: %.2f m wide, %.2f m high" % [slime.fitted_width, slime.fitted_height()])
	look(slime.global_position + Vector3(8.0, 7.0, 10.0), slime.global_position + Vector3(0, 3.0, 0), 55.0)
	await shot("c8_squeezing")
	# Holding the boy.
	for i in 300:
		slime.global_position += Vector3(0, 0, 1.3 / 60.0)
		await process_frame
	slime.rotation.y = 0.0
	await wait(0.5)
	boy.global_position = slime.global_position + Vector3(0.5, 0.1, 2.6)
	boy._reset_visuals()
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	slime.hold(boy.get_node("Rig"), 3.0)
	await wait(1.6)
	look(slime.global_position + Vector3(-2.0, 2.6, 9.0), slime.global_position + Vector3(0.3, 2.0, 0), 50.0)
	await shot("c9_holding_the_boy")
	await wait(2.0)
	boy.process_mode = Node.PROCESS_MODE_INHERIT
	yard.queue_free()
	await wait(0.2)


func _maze() -> void:
	var world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze = world.maze
	var nav := MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	for child in world.get_children():
		if child is MazeEnemies:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.visible = false
		if child is Griever:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.visible = false
	await wait(0.5)
	# A long straight hall.
	var found := _straight_run(maze, nav, 5)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	var across := Vector3(-along.z, 0, along.x)
	boy.global_position = maze.world(cell) + Vector3.UP * 0.1
	boy._reset_visuals()
	camera = Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	look(boy.global_position - along * 7.0 + Vector3.UP * 3.2, boy.global_position + along * 20.0 + Vector3.UP * 2.0, 62.0)
	await wait(1.0)
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var slime := MazeSlimeWall.new()
	slime.maze = maze
	slime.position = maze.world(cell + way * 2) + Vector3.UP * 0.05
	slime.rotation.y = atan2(-along.x, -along.z)
	slime.targets = [boy]
	world.add_child(slime)
	await wait(1.5)
	print("slime %.1f m wide (room %.1f left, %.1f right, offset %.1f), %.1f m high, %.1f m from the boy" % [slime.creature.fitted_width, slime.creature.room_left, slime.creature.room_right, slime.creature.fitted_offset, slime.creature.fitted_height(), slime.global_position.distance_to(boy.global_position)])
	await shot("m1_filling_the_hall")
	print("draws: %d without, %d with" % [bare, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	# From the side of the hall, nearer.
	var mid: Vector3 = slime.global_position
	look(mid - along * 11.0 + across * 6.0 + Vector3.UP * 4.0, mid + Vector3.UP * 3.0, 60.0)
	await wait(0.2)
	await shot("m2_close_in_the_hall")
	slime.notice(boy)
	look(boy.global_position - along * 5.0 + across * 1.5 + Vector3.UP * 2.0, boy.global_position + along * 12.0 + Vector3.UP * 2.5, 62.0)
	await wait(6.0)
	await shot("m3_coming")
	# Coming on him until it has him.
	slime.global_position = boy.global_position + along * 9.0 + Vector3.UP * 0.05
	slime._put(slime.global_position, slime.facing_yaw)
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 30000:
		await process_frame
		if slime.creature.holding():
			break
	print("  it took him after %.1f s" % ((Time.get_ticks_msec() - began) / 1000.0))
	await wait(1.1)
	var figure: Node3D = boy.get_node("Rig")
	look(figure.global_position - along * 7.0 + across * 2.5 + Vector3.UP * 1.0, figure.global_position + Vector3.UP * 0.6, 55.0)
	await shot("m4_it_has_him")
	world.camera.make_current()
	await wait(0.1)
	await shot("m5_held_game_camera")
	await wait(1.5)
	world.queue_free()
	await wait(0.2)


func _straight_run(maze, nav, run: int) -> Array:
	for c: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]
