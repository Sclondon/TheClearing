extends SceneTree
## Pictures of the round sections (RoundMaze, RoundBuilder): the whole maze from
## high over it (mist thinned), the desert from the square maze's way out, and a
## hallway in each round section at his eye height.
##
##     godot --path . --resolution 1280x720 -s res://tools/round_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://round_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	var started := Time.get_ticks_msec()
	main.start_solo()
	print("round started in %d ms" % (Time.get_ticks_msec() - started))
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	var maze = world.maze
	var plan: RoundMaze = maze.round_rings
	print("round sections: %d, from %.0f m to %.0f m" % [plan.rings.size(), plan.inner_radius, plan.outermost()])
	var camera := Camera3D.new()
	camera.far = 6000.0
	world.add_child(camera)
	camera.make_current()
	var env: Environment = null
	for found: Node in world.find_children("*", "WorldEnvironment", true, false):
		env = (found as WorldEnvironment).environment
	# (the day would put the mist back)
	world.day.process_mode = Node.PROCESS_MODE_DISABLED
	var fog := env.fog_density
	var fog_height := env.fog_height_density
	env.fog_density = 0.0002
	env.fog_height_density = 0.0
	world.weather.get_node("Clouds").visible = false
	for shown in world.find_children("*", "MeshInstance3D", true, false):
		(shown as MeshInstance3D).visibility_range_end = 0.0
	camera.fov = 70.0
	camera.position = Vector3(0.0, 2400.0, 900.0)
	camera.look_at(Vector3.ZERO)
	await _shot(folder + "/above.png")
	camera.position = Vector3(plan.outermost() * 0.7, 300.0, plan.outermost() * 0.7)
	camera.look_at(Vector3(plan.outermost() * 0.9, 0.0, 0.0))
	await _shot(folder + "/above_rings.png")
	world.weather.get_node("Clouds").visible = true
	env.fog_density = fog
	env.fog_height_density = fog_height
	camera.fov = 65.0
	# The desert, from just outside the square maze's way out.
	var out := Vector3(maze.exit_side.x, 0.0, maze.exit_side.y)
	var gap: Vector3 = maze.world(maze.exit) + out * 14.0
	camera.position = gap + Vector3.UP * 1.7
	camera.look_at(gap + out * 40.0 + Vector3.UP * 4.0)
	await _shot(folder + "/desert.png")
	# A hallway in each round section: in the middle of a cell of its middle row.
	for k in plan.rings.size():
		var ring: RoundMaze.Ring = plan.rings[k]
		var row: Array = ring.rows[ring.rows.size() / 2]
		var a := RoundMaze.angle_of(3, row[2]) + RoundMaze.angle_of(1, row[2]) * 0.5
		var r: float = (row[0] + row[1]) * 0.5
		camera.position = RoundBuilder.at(a, r) + Vector3.UP * 1.7
		camera.look_at(RoundBuilder.at(a + 0.08, r) + Vector3.UP * 6.0)
		await _shot("%s/ring%d.png" % [folder, maze.rings + k + 1])
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
