extends SceneTree
## Pictures of the bats (creatures/bats/, scripts/enemies/bats.gd). First in a
## plain grey studio, close: one bat from the front with its wings up and down,
## from the side, from below, gliding from above, the wingbeat in six steps,
## folding up, and a roost of them hanging on a wall. Then in a real round's
## passage (World, the game's light and mist): the roost up on the wall, the
## colony bursting off it, and whirling round the boy. Says how many draws a
## frame takes. Needs a real window (the engine draws nothing headless):
##
##     godot --path . --resolution 720x1280 -s res://tools/bat_shots.gd -- <folder> [studio|maze]

var folder := "bat_shots"
var only := ""
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


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


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


# --- The studio ---

func _studio() -> void:
	var stage := Node3D.new()
	stage.name = "Studio"
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.55
	var surround := WorldEnvironment.new()
	surround.environment = env
	stage.add_child(surround)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	stage.add_child(sun)
	sun.look_at_from_position(Vector3(2, 4, 3), Vector3.ZERO)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.make_current()

	var one := BatColony.new()
	one.count = 1
	one.wingspan = 1.4
	one.frozen = true
	stage.add_child(one)
	var level := Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))
	var face_us := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.5, 0))
	# (bat 0 of a colony is as big as `wingspan` times its own share: put it at 1.4 for these)
	one._size[0] = 1.4

	_look(Vector3(0, 1.7, -4.2), Vector3(0, 1.5, 0))
	one.pose_bat(0, face_us.rotated_local(Vector3.RIGHT, 0.15), 0.25, 1.0, 0.0)
	await shot("01_front_wings_up")
	one.pose_bat(0, face_us.rotated_local(Vector3.RIGHT, 0.15), 0.75, 1.0, 0.0)
	await shot("02_front_wings_down")
	_look(Vector3(-4.0, 1.9, 0.6), Vector3(0, 1.5, 0))
	one.pose_bat(0, level, 0.05, 1.0, 0.0)
	await shot("03_side")
	_look(Vector3(0.6, -1.8, 1.2), Vector3(0, 1.5, 0))
	one.pose_bat(0, level, 0.45, 0.0, 0.0)
	await shot("04_underside")
	_look(Vector3(0.0, 5.2, -1.6), Vector3(0, 1.5, 0))
	one.pose_bat(0, level, 0.0, 0.0, 0.0)
	await shot("05_gliding_from_above")
	_look(Vector3(-2.6, 2.4, 3.0), Vector3(0, 1.5, 0))
	one.pose_bat(0, level.rotated_local(Vector3.FORWARD, 0.3), 0.6, 1.0, 0.0)
	await shot("06_three_quarter_banked")
	one.queue_free()

	# The wingbeat in six steps, from the front; and folding up, in four.
	var row := BatColony.new()
	row.count = 6
	row.frozen = true
	stage.add_child(row)
	# (two across, three down: read left to right, top to bottom)
	var grid := func(i: int) -> Vector3: return Vector3((0.5 - i % 2) * 1.3, 2.9 - (i / 2) * 1.25, 0)
	for i in 6:
		row._size[i] = 1.0
		row.pose_bat(i, Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.25), grid.call(i)), i / 6.0, 1.0, 0.0)
	_look(Vector3(0, 2.2, -7.5), Vector3(0, 1.65, 0))
	await shot("07_wingbeat_in_six")
	for i in 6:
		var fold := i / 5.0
		row.pose_bat(i, Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.25 - fold * 1.4), grid.call(i)), 0.3, 0.3 * (1.0 - fold), fold)
	await shot("08_folding_up")
	_look(Vector3(0, 6.5, -3.0), Vector3(0, 1.65, 0))
	await shot("08b_folding_up_from_above")
	row.queue_free()

	# A roost on a wall.
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 6, 0.4)
	wall.mesh = box
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.42, 0.4)
	wall.material_override = stone
	wall.position = Vector3(0, 3, -0.2)
	stage.add_child(wall)
	var roost := BatColony.new()
	roost.count = 12
	roost.colony_seed = 3
	stage.add_child(roost)
	roost.set_roost(Vector3(0, 4.2, 0), Vector3.BACK)
	roost.settle()
	_look(Vector3(1.2, 2.2, 10.0), Vector3(0, 3.5, 0))
	await wait(1.0)
	await shot("09_roost")
	_look(Vector3(2.5, 3.2, 3.0), Vector3(0, 3.7, 0))
	await wait(0.2)
	await shot("10_roost_close")
	roost.awake = true
	roost.target = Vector3(0, 1.7, 3.5)
	_look(Vector3(1.5, 2.6, 8.5), Vector3(0, 3.0, 1.5))
	await wait(1.0)
	await shot("11_letting_go")
	await wait(1.6)
	await shot("12_swirling")
	var spin := 0.0
	for k in 120:
		spin += 1.0 / 60.0
		roost.target = Vector3(sin(spin * 1.3) * 1.5, 1.7, 3.5 + cos(spin) * 0.8)
		await process_frame
	await shot("13_swirling_moving")
	roost.awake = false
	await wait(9.0, roost.all_home)
	print("back on the roost: %s (%d flying)" % [roost.all_home(), roost.flying()])
	_look(Vector3(1.2, 2.2, 10.0), Vector3(0, 3.5, 0))
	await shot("14_back_on_the_roost")
	stage.queue_free()
	await process_frame


func _look(from: Vector3, at: Vector3) -> void:
	camera.look_at_from_position(from, at)


# --- In the maze ---

var world
var maze
var nav
var boy


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	await wait(0.5)
	var found := _straight_run(3)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	_stand(cell, way)
	await wait(1.0)
	var bats := Bats.new()
	bats.maze = maze
	bats.interest = 60.0
	bats.position = maze.world(cell + way * 2) + Vector3.UP * 0.05
	world.add_child(bats)
	await wait(0.6)
	var roost: Vector3 = bats.colony.roost()
	print("roost at %s (the boy at %s)" % [roost, boy.global_position])
	var eye := Camera3D.new()
	world.add_child(eye)
	eye.fov = 50.0
	# Looking up the passage at the roost, from a little way off.
	var under := roost + bats.roost_out * 1.5 - along * 9.0
	under.y = 1.7
	eye.look_at_from_position(under, roost + Vector3.DOWN * 0.5)
	eye.make_current()
	await wait(0.4)
	await shot("20_maze_roost_from_below")
	eye.fov = 30.0
	eye.look_at_from_position(roost + bats.roost_out * 4.0 - along * 2.0 + Vector3.DOWN * 3.0, roost + Vector3.DOWN * 0.5)
	await wait(0.2)
	await shot("21_maze_roost_close")
	# He runs past: they wake.
	eye.fov = 50.0
	eye.look_at_from_position(under, roost + Vector3.DOWN * 1.5)
	bats.wake_on(boy)
	await wait(0.75)
	await shot("22_maze_bursting_off")
	await wait(0.5)
	await shot("22b_maze_off_the_wall")
	var head: Vector3 = boy.global_position + Vector3.UP * 1.65
	await wait(10.0, func() -> bool: return bats.colony.centre().distance_to(head) < 2.5)
	await wait(1.5)
	eye.look_at_from_position(boy.global_position - along * 6.5 + Vector3.UP * 2.6 + Vector3(-along.z, 0, along.x) * 1.0, head)
	await shot("23_maze_round_the_boy")
	var with := await _draws()
	bats.colony.visible = false
	var without := await _draws()
	bats.colony.visible = true
	print("draws, this view, with the colony mobbing: %d, without it: %d" % [with, without])
	eye.look_at_from_position(boy.global_position + along * 5.5 + Vector3.UP * 1.4, head + Vector3.UP * 0.3)
	await wait(0.7)
	await shot("24_maze_round_the_boy_facing")
	eye.look_at_from_position(boy.global_position + along * 1.8 + Vector3.UP * 0.4, head + Vector3.UP * 1.0)
	await wait(0.5)
	await shot("25_maze_mob_from_below")
	world.camera.make_current()
	await wait(0.6)
	await shot("26_maze_game_camera")




func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _straight_run(run: int) -> Array:
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


func _stand(at: Vector2i, along: Vector2i) -> void:
	boy.global_position = maze.world(at) + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(float(along.x), float(along.y))
	world.camera._yaw = atan2(float(-along.x), float(-along.y))
	world.camera.snap()
