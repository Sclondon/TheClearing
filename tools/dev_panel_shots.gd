extends SceneTree
## Pictures of the dev panel (DevTools) open on each of its pages, with a row of
## each list picked and the map tapped, to see that they work and how they look.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/dev_panel_shots.gd -- dev <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var folder := "user://dev_panel_shots"
	for arg in OS.get_cmdline_user_args():
		if arg != "dev":
			folder = arg
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 60:
		await process_frame
	var dev = main.world.dev
	dev.toggle()
	var tabs := dev.find_children("*", "TabContainer", true, false)[0] as TabContainer
	# Spawn: a search, and a row picked.
	dev._search.text = "mum"
	dev._filter("mum")
	await _shot(folder + "/spawn_search.png")
	dev._search.text = ""
	dev._filter("")
	var before: int = main.world.enemies.enemies.size()
	var first: TreeItem = dev._spawn_tree.get_root().get_first_child().get_first_child()
	first.select(0)
	await _shot(folder + "/spawn.png")
	print("picked %s: %d put in" % [first.get_text(0), main.world.enemies.enemies.size() - before])
	# Travel: the map, tapped on the far side of the clearing; then a place picked.
	tabs.current_tab = 1
	await _shot(folder + "/travel.png")
	dev.travel_to(Vector2(0.0, 400.0))
	await _shot(folder + "/travel_tapped.png")
	print("tapped the map at 0, 400: he is at %s" % str(main.world.player.global_position))
	# World.
	tabs.current_tab = 2
	await _shot(folder + "/world.png")
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
