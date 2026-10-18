extends SceneTree
## Pictures of the low plants (Undergrowth): a fern up close, and the boy walking
## into a clump of them (they bend away from him, as the grass does).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/fern_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var folder := "user://fern_shots"
	for arg in OS.get_cmdline_user_args():
		folder = arg
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await process_frame
	var world = main.world
	var plants: Undergrowth = world.find_children("*", "Undergrowth", true, false)[0]
	# (the fern nearest the middle of the clearing that has others round it)
	var best := Vector3.INF
	for key: Array in plants._placed:
		if key[0] != Undergrowth.Kind.FERN:
			continue
		for where: Transform3D in plants._placed[key]:
			if where.origin.length() < best.length():
				best = where.origin
	print("fern at ", best)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var aside := Vector3(1.0, 0.0, 0.4).normalized()
	world.put_player(best + aside * 6.0, 0.0)
	for i in 20:
		await physics_frame
	camera.position = best + aside * 1.6 + Vector3.UP * 1.1
	camera.look_at(best + Vector3.UP * 0.4)
	await _shot(folder + "/fern_close.png")
	# Into them: he walks through, and they lie over.
	world.put_player(best + Vector3.UP * 0.1, 0.0)
	for i in 20:
		await physics_frame
	camera.position = best + aside * 2.4 + Vector3.UP * 1.4
	camera.look_at(best + Vector3.UP * 0.5)
	await _shot(folder + "/fern_pushed.png")
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
