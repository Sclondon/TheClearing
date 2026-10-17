extends SceneTree
## Pictures of the game to look at: the title, the clearing, a passage, and the
## maze from above, with stand-ins for three friends. Needs a real window (the
## engine draws nothing headless):
##
##     godot --path . --resolution 720x1280 -s res://tools/shots.gd -- <folder>

var main: Node
var folder := "shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


func _run() -> void:
	await wait(1.0)
	await shot("1_title")
	main._begin([
		{"slot": 0, "look": "p11"}, {"slot": 1, "look": "p22"}, {"slot": 2, "look": "p33"}, {"slot": 3, "look": "p44"},
	], 0, false, Maze.seed_for("SHOT", 1))
	var world = main.world
	for seat in world.remotes:
		world.remotes[seat].hear(world.spawn(seat), Vector3.ZERO, world.spawn_yaw(seat) + PI, true)
	await wait(1.5)
	await shot("2_clearing")
	world.camera._yaw += PI
	await wait(1.0)
	await shot("3_clearing_behind")
	# Into a passage.
	var maze = world.maze
	var path: Array = maze.path_out(maze.cell_at(Vector3.ZERO))
	var cell: Vector2i = path[mini(14, path.size() - 1)]
	var next: Vector2i = path[mini(15, path.size() - 1)]
	world.player.global_position = maze.world(cell) + Vector3.UP * 0.1
	world.camera._yaw = atan2(float(cell.x - next.x), float(cell.y - next.y))
	world.camera.snap()
	await wait(1.5)
	await shot("4_passage")
	# The exit.
	world.player.global_position = maze.world(maze.exit) + Vector3.UP * 0.1
	world.camera._yaw = atan2(float(-maze.exit_side.x), float(-maze.exit_side.y))
	world.camera.snap()
	await wait(1.5)
	await shot("5_exit")
	# From above.
	var above := Camera3D.new()
	world.add_child(above)
	above.position = Vector3(0.0, 260.0, 0.01)
	above.fov = 55.0
	above.look_at(Vector3.ZERO)
	above.make_current()
	await wait(0.5)
	await shot("6_above")
	quit()
