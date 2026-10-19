extends SceneTree
## The director at work (MazeDirector): the boy stood in a hall of the first
## section for a while, out of harm's way (nothing can catch him), and every few
## seconds the wave's phase, how many hunters are about him (and how near the
## nearest), how many are after him, and how many it has brought and steered.
##
##     godot --headless --path . --audio-driver Dummy -s res://tools/director_probe.gd -- dev [seconds=<s>]

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _arg(key: String, default: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return int(a.split("=")[1])
	return default


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


func _run() -> void:
	await wait(0.2)
	main.start_solo()
	await wait(2.0)
	var world = main.world
	var player: Node3D = world.player
	# (he cannot be caught: the probe watches, it does not play)
	world.dev.god = true
	world.dev.to_ring(1)
	await wait(3.0)
	var director: MazeDirector = world.director
	var seconds := _arg("seconds", 150)
	var t := 0.0
	while t < seconds:
		await wait(5.0)
		t += 5.0
		var l: MazeEnemy = director.last
		if l:
			print("   last brought: %s %s at %.0f m, awake %s, mode %d, visible %s, zone %d vs %d" % [Ecology.kind_of(l), l.name, l.global_position.distance_to(player.global_position), l.can_process(), l.process_mode, l.visible, world.zone_of(l.global_position), world.zone_of(player.global_position)])
		var about := 0
		var close := 0
		var nearest := INF
		var chasing := 0
		for one: MazeEnemy in world.enemies.enemies:
			if not is_instance_valid(one) or one.dead or not one.can_process():
				continue
			var d := one.global_position.distance_to(player.global_position)
			if d < MazeDirector.NEAR:
				about += 1
			if d < 40.0:
				close += 1
			nearest = minf(nearest, d)
			if one.chasing:
				chasing += 1
		print("%4.0f s  %-5s %.2f  about %2d (within 40 m %d, nearest %.0f m)  chasing %d  brought %d  steered %d  wanted %.1f" % [t, MazeDirector.Phase.keys()[director.phase], director.through, about, close, nearest, chasing, director.brought, director.steered, director._wanted()])
		print("      worst tick %.2f ms" % director.worst_tick_ms)
		if not director.missed.is_empty():
			print("      brought nobody: %s" % director.missed)
	quit()
