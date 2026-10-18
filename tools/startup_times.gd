extends SceneTree
## How long the first frames of a round take (the slow start), printed in groups.
##
##     godot --path . --resolution 720x1280 -s res://tools/startup_times.gd

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	var started := Time.get_ticks_usec()
	main.start_solo()
	print("start_solo %.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	var line := ""
	var last := Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now := Time.get_ticks_usec()
		line += "%d " % roundi((now - last) / 1000.0)
		last = now
		if i % 30 == 29:
			print("%3d: %s | proc %.1f phys %.1f draws %d" % [i, line, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
			line = ""
	quit()
