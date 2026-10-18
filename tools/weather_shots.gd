extends SceneTree
## Pictures of the weather (Weather): each kind, overcast to thunderstorm (caught mid-flash), from the
## clearing looking up at its wall and the sky, and in a hall of the first ring.
##
##     godot --path . --resolution 1280x720 -s res://tools/weather_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://weather_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	world.add_child(camera)
	camera.make_current()
	var weather: Weather = world.weather
	var spot: Transform3D = world.gate_spot(maxi(world.maze.clearing_style.entrances.find(ClearingStyle.Entrance.CLEAR), 0))
	var out := spot.basis.z
	var hall: Vector3 = world.maze.world(world.maze.gates[0][0][0] + world.maze.gates[0][0][1] * 6)
	for kind: int in Weather.Kind.values():
		weather.forced = kind
		var look: Array = Weather.LOOKS[kind]
		weather.clouds = look[0]
		weather.rain = look[1]
		weather.wind = look[2]
		var name := String(Weather.Kind.keys()[kind]).to_lower()
		camera.position = Vector3(0.0, 4.0, 0.0)
		camera.look_at(spot.origin + Vector3.UP * 260.0)
		await _shot("%s/%s_clearing.png" % [folder, name])
		camera.position = Vector3(0.0, 1.7, 0.0)
		camera.look_at(spot.origin + Vector3.UP * 30.0)
		await _shot("%s/%s_low.png" % [folder, name])
		if kind == Weather.Kind.THUNDERSTORM:
			weather.strike()
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_low_flash.png" % [folder, name])
	quit()


func _shot(path: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
