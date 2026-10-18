extends SceneTree
## What is drawn, by the script that owns it (the nearest scripted node over each
## mesh, multimesh or particles): how many of each there are and how many
## triangles, a few seconds into a round, so that what costs most can be found.
##
##     godot --path . --resolution 1280x720 -s res://tools/draw_owners.gd

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 120:
		await process_frame
	var camera := root.get_viewport().get_camera_3d()
	var counts := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var shown := node as GeometryInstance3D
		if not shown.is_visible_in_tree():
			continue
		if shown.visibility_range_end > 0.0 and camera and camera.global_position.distance_to(shown.global_position) > shown.visibility_range_end:
			continue
		var owner_node: Node = shown.get_parent()
		while owner_node and owner_node.get_script() == null:
			owner_node = owner_node.get_parent()
		var key: String = owner_node.get_script().resource_path.get_file() if owner_node else "?"
		if not counts.has(key):
			counts[key] = [0, 0]
		counts[key][0] += 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a][0] > counts[b][0])
	for k in keys.slice(0, 20):
		print("%6d  %s" % [counts[k][0], k])
	quit()
