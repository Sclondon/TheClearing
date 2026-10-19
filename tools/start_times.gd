extends SceneTree
## How long a launch takes to playing, in parts: the engine starting (to this
## script), loading and making the title screen (main.tscn, its scripts and the
## menu's maze), the round (Main.start_solo, World.setup) and its first frames.
## With `times`, World.setup says how long each of its stages took too; with
## `clearing`, the round is the clearing alone (World.clearing_only).
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/start_times.gd -- [times] [clearing]

const Flags := preload("res://scripts/flags.gd")

var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("vines="):
			HeavyVines.apply(float(a.substr(6)))
	seed(1)
	print("engine boot      %6d ms" % Time.get_ticks_msec())
	var started := Time.get_ticks_usec()
	var scene := load("res://main.tscn") as PackedScene
	print("load main.tscn   %6.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	started = Time.get_ticks_usec()
	main = scene.instantiate()
	main.testing = true
	root.add_child(main)
	_run(started)


func _run(started: int) -> void:
	# (the title screen is made as the tree first runs; the menu's maze behind it, which
	# tests go without, as a player has it, unless he starts in the clearing alone)
	await process_frame
	if Flags.value("clearing") == "":
		main._show_preview()
	print("title screen     %6.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	started = Time.get_ticks_usec()
	if Flags.value("clearing") != "":
		main.start_clearing()
	else:
		main.start_solo()
	print("start_solo       %6.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	started = Time.get_ticks_usec()
	var slowest := 0
	var last := started
	for i in 30:
		await process_frame
		var now := Time.get_ticks_usec()
		slowest = maxi(slowest, now - last)
		last = now
	print("first 30 frames  %6.0f ms (slowest %.0f)" % [(Time.get_ticks_usec() - started) / 1000.0, slowest / 1000.0])
	print("to playing       %6d ms" % Time.get_ticks_msec())
	quit()
