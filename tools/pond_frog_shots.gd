extends SceneTree
## Pictures of the pond frogs (creatures/pond_frog): a pond on a plain floor
## under the game's kind of light, close up on the frogs sitting about it and
## singing, then something walking up to them and the frogs leaping in one
## after another (the rings on the water), and their eyes up out of it after;
## and in a real round, along the marsh's pools in the clearing and round a
## pond of their own in a hall. Says how many draws a frame takes. Needs a
## real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/pond_frog_shots.gd -- <folder> [studio|maze|all]

var folder := "pond_frog_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func _stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.36, 0.38, 0.32)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _studio() -> void:
	_stage()
	var frogs := PondFrogs.new()
	frogs.voice = false
	frogs.chorus = 0.9
	stage_root.add_child(frogs)
	await frames(30)
	camera.fov = 45.0
	camera.global_position = Vector3(0.0, 2.6, 4.2)
	camera.look_at(Vector3(0.0, 0.0, 0.3), Vector3.UP)
	await shot("p01_pond")
	# Close up on one at the edge, singing
	var one := frogs.frog_position(2)
	camera.fov = 35.0
	camera.global_position = one + (one - Vector3.ZERO).normalized() * 0.55 + Vector3.UP * 0.18
	camera.look_at(one + Vector3.UP * 0.03, Vector3.UP)
	await frames(10)
	await shot("p02_frog_close")
	for k in 3:
		await frames(23)
		await shot("p03_singing_%d" % k)
	var side := frogs.frog_position(5)
	camera.global_position = side + Vector3(side.z, 0.0, -side.x).normalized() * 0.5 + Vector3.UP * 0.08
	camera.look_at(side + Vector3.UP * 0.03, Vector3.UP)
	await frames(4)
	await shot("p04_frog_side")
	# Someone walks up: they hush, then leap in one after another
	var walker := CharacterBody3D.new()
	stage_root.add_child(walker)
	walker.global_position = Vector3(6.0, 0.0, 3.0)
	frogs.frighten = [walker]
	camera.fov = 45.0
	camera.global_position = Vector3(-1.5, 2.2, 4.0)
	camera.look_at(Vector3(0.3, 0.0, 0.0), Vector3.UP)
	var shots_at := [40, 70, 85, 100, 130]
	for f in 140:
		var to := Vector3(1.6, 0.0, 0.8) - walker.global_position
		to.y = 0.0
		walker.velocity = to.normalized() * 1.4 if to.length() > 0.2 else Vector3.ZERO
		walker.global_position += walker.velocity / 60.0
		await process_frame
		if f in shots_at:
			await shot("p05_walk_up_%03d" % f)
	print("out of the water: %d of %d" % [frogs.out(), frogs.count])
	# Gone off again: up come their eyes, then out they climb
	walker.global_position = Vector3(40.0, 0.0, 0.0)
	walker.velocity = Vector3.ZERO
	await frames(60 * 14)
	camera.global_position = Vector3(0.6, 0.9, 2.2)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	await shot("p06_eyes_up")
	await frames(60 * 8)
	await shot("p07_back_out")
	print("out of the water: %d of %d" % [frogs.out(), frogs.count])
	stage_root.queue_free()
	await frames(4)


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	var day: Node = world.get(&"day")
	if day:
		day.call(&"set_hour", 11.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var found := MazePondFrogs.marsh_colonies(maze, 2, rng)
	print("marsh colonies: %d" % found.size())
	var enemies: Node = world.get(&"enemies")
	var placed: Array[MazePondFrogs] = []
	for one: Array in found:
		var frogs := MazePondFrogs.new()
		frogs.banks = one[1]
		frogs.frogs = (one[1] as Array).size()
		var at: Vector3 = one[0]
		enemies.call(&"add", frogs, maze.cell_at(at), 0.0, 1, at - maze.world(maze.cell_at(at)) - Vector3.UP * 0.05)
		placed.append(frogs)
	await frames(30)
	if not placed.is_empty():
		var bank: Vector3 = placed[0].banks[0][0]
		var water: Vector3 = placed[0].banks[0][1]
		var back := (bank - water).normalized()
		boy.global_position = bank + back * 14.0 + Vector3.UP * 0.5
		camera.fov = 40.0
		camera.global_position = bank + back * 3.0 + Vector3.UP * 2.2
		camera.look_at(bank + (water - bank) * 0.5, Vector3.UP)
		await frames(30)
		await shot("m01_marsh_frogs")
		camera.fov = 25.0
		camera.global_position = bank + back * 1.0 + Vector3.UP * 0.35 + Vector3(back.z, 0.0, -back.x) * 0.4
		camera.look_at(bank, Vector3.UP)
		await shot("m02_marsh_frog_close")
	# A pond of their own in a hall
	var nav := MazeNav.new(maze)
	var cell: Vector2i = nav.lairs(3)[0]
	var pond := MazePondFrogs.new()
	enemies.call(&"add", pond, cell, 0.0, 2)
	await frames(30)
	var middle := maze.world(cell)
	boy.global_position = middle + Vector3(9.0, 0.5, 0.0)
	camera.fov = 50.0
	camera.global_position = middle + Vector3(3.5, 1.4, 2.5)
	camera.look_at(middle, Vector3.UP)
	await frames(70)
	var keeper: Node3D = pond.colony.get_parent()
	print("pond at %s, keeper %s in tree %s visible %s, cell middle %s, frogs %d" % [pond.global_position, keeper.global_position, keeper.is_inside_tree(), pond.colony.is_visible_in_tree(), middle, pond.colony.count])
	await shot("m03_hall_pond")
