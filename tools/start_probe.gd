extends SceneTree
## What the boy does at the real start of a round (the loading screen and waking,
## Main._wake_up), then with the stick pushed up: his state, rest, whether he is
## on the floor, where he is, every half second. Run with -- --dev to start as
## the editor does.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/start_probe.gd -- --dev

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 10:
		await process_frame
	var started := Time.get_ticks_msec()
	main.start_solo()
	while main.world == null or main.world.player == null:
		await process_frame
	var player = main.world.player
	var pushing := false
	while Time.get_ticks_msec() - started < 40000:
		await create_timer(0.5).timeout
		var t := (Time.get_ticks_msec() - started) / 1000.0
		if t > 28.0 and not pushing:
			pushing = true
			Input.action_press(&"move_up")
			print("-- pushing up")
		print("%5.1f s  state %s  rest %s  sit %.2f lie %.2f  floor %s  limp %s  at %s  vel %s  cam %s" % [t, player.State.keys()[player.state], player.rest, player.sit_progress, player.lie_progress, player.is_on_floor(), player.is_limp, str(player.global_position.snappedf(0.01)), str(player.velocity.snappedf(0.01)), get_root().get_viewport().get_camera_3d().name])
	quit()
