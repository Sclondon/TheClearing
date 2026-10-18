extends SceneTree
## What drawing costs a few seconds into a round: draw calls and triangles, then
## the frame rate as particles, multimeshes and meshes are hidden in turn.
##
##     godot --path . --resolution 1280x720 -s res://tools/draw_costs.gd -- [rings=<n>]
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
	print("draws %d prims %d objects %d  proc %.1f ms  phys %.1f ms  fps %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_FPS)])
	# hide groups of things one at a time, and see what the frame costs
	var hidden := 0
	for kind in ["GPUParticles3D", "CPUParticles3D", "MultiMeshInstance3D", "MeshInstance3D"]:
		for n in root.find_children("*", kind, true, false):
			if n.visible:
				n.visible = false
				hidden += 1
		for i in 60:
			await process_frame
		print("hid %-22s (%d so far): fps %d draws %d prims %d" % [kind, hidden, Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
