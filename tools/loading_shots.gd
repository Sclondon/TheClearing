extends SceneTree
## The loading screen (Main._loading_page) as Play shows it: pictures while the
## round is being made, the stages it went through with how long each took, a
## picture once it is ready, and pictures as he wakes (Main._wake_up).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/loading_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	var folder := "user://loading_shots"
	for arg in OS.get_cmdline_user_args():
		folder = arg
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 10:
		await process_frame
	var started := Time.get_ticks_msec()
	var last := [started]
	main.start_solo()
	main.world.building.connect(func(what: String) -> void:
		var now := Time.get_ticks_msec()
		print("%6d ms  (+%5d)  %s" % [now - started, now - last[0], what])
		last[0] = now)
	var shots := 0
	while main.world.player == null or main._loading_label != null and is_instance_valid(main._loading_label):
		await process_frame
		if shots < 3 and Time.get_ticks_msec() - started > 300 + shots * 2500:
			root.get_texture().get_image().save_png("%s/loading_%d.png" % [folder, shots])
			print("saved loading_%d" % shots)
			shots += 1
		if Time.get_ticks_msec() - started > 120000:
			break
	print("ready in %d ms" % (Time.get_ticks_msec() - started))
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(folder + "/ready.png")
	# (then waking: the eyes opening, and him getting up)
	var woke := Time.get_ticks_msec()
	for k in 8:
		while Time.get_ticks_msec() - woke < 700 + k * 900:
			await process_frame
		root.get_texture().get_image().save_png("%s/waking_%d.png" % [folder, k])
	quit()
