extends SceneTree
## The frame time with the boy in the middle of the clearing and in the tall
## grass by its gate, his own camera turning round him (seed 12345 unless given).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/tall_grass_fps.gd -- [seed]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in 5:
		await process_frame
	main._begin([{"slot": 0, "look": main.look}], 0, false, int(args[0]) if args.size() > 0 else 12345)
	for i in 30:
		await physics_frame
	var world = main.world
	var look: ClearingStyle = world.maze.clearing_style
	var way := look.entrance(ClearingStyle.Entrance.TALL_GRASS)
	var spots := [["middle", Vector2(4.0, 4.0)]]
	if not way.is_empty():
		spots.append(["tall grass", (way[0] as Vector2) + (way[1] as Vector2) * 20.0 + (way[1] as Vector2).orthogonal() * 15.0])
	for spot: Array in spots:
		var at: Vector2 = spot[1]
		world.put_player(Vector3(at.x, world.maze.ground_height(Vector3(at.x, 0.0, at.y)) + 0.2, at.y), 0.0)
		for i in 240:
			world.camera._yaw += 0.02
			await process_frame
		var started := Time.get_ticks_usec()
		for i in 300:
			world.camera._yaw += 0.02
			await process_frame
		print("%s: %.2f ms a frame" % [spot[0], (Time.get_ticks_usec() - started) / 1000.0 / 300.0])
	quit()
