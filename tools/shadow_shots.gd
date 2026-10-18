extends SceneTree
## A walk through the first gate and along the hall past it, a picture every few
## steps, put side by side in one sheet: to see the walls' shadows as he moves.
##
##     godot --path . --resolution 720x1280 -s res://tools/shadow_shots.gd -- <file.png> [frames]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://shadows.png"
	var count: int = int(args[1]) if args.size() > 1 else 8
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 20:
		await physics_frame
	var world = main.world
	var maze = world.maze
	var way: Array = maze.gates[0][0]
	var step: Vector2i = way[1]
	var cell: Vector2i = way[0] + step
	while maze.entrances.has(cell):
		cell += step
	var side := Vector3(step.y, 0.0, step.x)
	var out := Vector3(step.x, 0.0, step.y)
	world.put_player(maze.world(cell) - out * 2.0 + Vector3.UP * 0.1, atan2(side.x, side.z))
	world.camera.snap()
	var frames: Array[Image] = []
	for f in count:
		for i in 12:
			world.player.velocity.x = side.x * 6.0
			world.player.velocity.z = side.z * 6.0
			await physics_frame
		await process_frame
		var shot := root.get_texture().get_image()
		shot.resize(shot.get_width() / 2, shot.get_height() / 2)
		frames.append(shot)
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var across := 4
	var sheet := Image.create(w * across, h * ceili(count / float(across)), false, frames[0].get_format())
	for f in count:
		sheet.blit_rect(frames[f], Rect2i(0, 0, w, h), Vector2i((f % across) * w, (f / across) * h))
	sheet.save_png(path)
	print("saved ", path)
	quit()
