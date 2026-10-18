extends SceneTree
## A picture of the title screen as Play would find it: the menu over the view
## down a hall of the second section (Main._show_preview).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/menu_shot.gd -- <file.png>

func _initialize() -> void:
	root.add_child(load("res://main.tscn").instantiate())
	_run()


func _run() -> void:
	var path := "user://menu.png"
	for arg in OS.get_cmdline_user_args():
		path = arg
	for i in 240:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	quit()
