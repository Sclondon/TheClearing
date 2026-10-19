extends SceneTree
## Pictures of the weather (Weather): each kind, sunny and overcast to thunderstorm (caught mid-flash), from the
## clearing looking up at its wall and the sky, low in the clearing looking at its wall, and down a hall of the
## first ring (the rain's splashes on its floor). Or only some of them: `rain` (the rainy kinds, close up), `fog`
## (the ground fog, with a wake walked through it), `clearing` (the clearing's fog banks), `sunny`.
##
##     godot --path . --resolution 1280x720 -s res://tools/weather_shots.gd -- <folder> [all|rain|fog|clearing|sunny]

var main: Node
var world
var camera: Camera3D
var weather: Weather


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://weather_shots"
	var which: String = args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	world = main.world
	world.player.visible = false
	camera = Camera3D.new()
	camera.fov = 65.0
	world.add_child(camera)
	camera.make_current()
	weather = world.weather
	var spot: Transform3D = world.gate_spot(maxi(world.maze.clearing_style.entrances.find(ClearingStyle.Entrance.CLEAR), 0))
	var gate: Array = world.maze.gates[0][0]
	var along := Vector3(gate[1].x, 0.0, gate[1].y)
	var hall: Vector3 = world.maze.world(gate[0] + gate[1] * 3)
	var kinds: Array = Weather.Kind.values()
	if which == "rain":
		kinds = [Weather.Kind.SPRINKLE, Weather.Kind.RAIN, Weather.Kind.DOWNPOUR, Weather.Kind.THUNDERSTORM]
	elif which == "sunny":
		kinds = [Weather.Kind.get("SUNNY", -1), Weather.Kind.OVERCAST]
	elif which != "all":
		kinds = []
	for kind: int in kinds:
		_force(kind)
		var name := String(Weather.Kind.keys()[kind]).to_lower()
		if which == "all" or which == "sunny":
			camera.position = Vector3(0.0, 4.0, 0.0)
			camera.look_at(spot.origin + Vector3.UP * 260.0)
			await _shot("%s/%s_clearing.png" % [folder, name])
		camera.position = Vector3(0.0, 1.7, 0.0)
		camera.look_at(spot.origin + Vector3.UP * 30.0)
		await _shot("%s/%s_low.png" % [folder, name])
		if which != "sunny":
			camera.position = hall + Vector3.UP * 2.4
			camera.look_at(hall + along * 9.0 + Vector3.UP * 0.6)
			await _shot("%s/%s_hall.png" % [folder, name])
		if kind == Weather.Kind.THUNDERSTORM:
			camera.position = Vector3(0.0, 1.7, 0.0)
			camera.look_at(spot.origin + Vector3.UP * 30.0)
			await _shot("", 20)
			weather.strike()
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s_low_flash.png" % [folder, name])
	if which == "all" or which == "fog":
		await _fog(folder, spot)
	if which == "all" or which == "clearing":
		await _clearing(folder, spot)
	quit()


## A kind of weather, at once (no turning slowly into it).
func _force(kind: int) -> void:
	weather.forced = kind
	var look: Array = Weather.LOOKS[kind]
	weather.clouds = look[0]
	weather.rain = look[1]
	weather.wind = look[2]
	weather.set(&"sunshine", 1.0 if kind == Weather.Kind.get("SUNNY", -1) else 0.0)


## The ground fog: someone walked through it, the wake behind him, from above
## and behind as the game's camera has it; in the clearing and in a hall.
func _fog(folder: String, spot: Transform3D) -> void:
	_force(Weather.Kind.OVERCAST)
	weather.set(&"forced_ground_fog", 1)
	weather.set(&"ground_fog", 1.0)
	var player: Node3D = world.player
	player.visible = true
	var out := spot.basis.z
	var from := Vector3(30.0, 0.0, 10.0)
	var heading := Vector3(-1.0, 0.0, 0.3).normalized()
	# (walked along, a step at a time, for the fog to be stirred where he went)
	for i in 150:
		player.global_position = from + heading * (i * 0.1)
		player.global_position.y = world.maze.ground_height(player.global_position)
		await physics_frame
	var at: Vector3 = player.global_position
	camera.position = at - heading * 7.0 + Vector3(2.5, 3.2, 0.0)
	camera.look_at(at - heading * 4.0)
	await _shot("%s/fog_wake.png" % folder, 4)
	camera.position = at + Vector3(0.0, 9.0, 0.5)
	camera.look_at(at - heading * 6.0)
	await _shot("%s/fog_wake_above.png" % folder, 4)
	camera.position = Vector3(0.0, 2.6, 0.0) - out * 20.0
	camera.look_at(spot.origin)
	await _shot("%s/fog_clearing.png" % folder)
	player.visible = false
	weather.set(&"forced_ground_fog", -1)


## The clearing's fog banks, from the middle and nearer its wall, by day and at dawn.
func _clearing(folder: String, spot: Transform3D) -> void:
	_force(Weather.Kind.OVERCAST)
	weather.set(&"clearing_fog", 1.0)
	var out := spot.basis.z
	camera.position = Vector3(0.0, 2.0, 0.0)
	camera.look_at(spot.origin + Vector3.UP * 45.0)
	await _shot("%s/clearing_fog_middle.png" % folder, 60)
	camera.position = Vector3(0.0, 2.0, 0.0)
	camera.look_at(spot.origin.rotated(Vector3.UP, 0.8) + Vector3.UP * 45.0)
	await _shot("%s/clearing_fog_middle_side.png" % folder, 10)
	camera.position = spot.origin - out * 150.0 + Vector3.UP * 2.0
	camera.look_at(spot.origin + Vector3.UP * 50.0)
	await _shot("%s/clearing_fog_near.png" % folder, 10)
	_force(Weather.Kind.get("SUNNY", -1))
	weather.set(&"clearing_fog", 0.0)
	camera.position = Vector3(0.0, 2.0, 0.0)
	camera.look_at(spot.origin + Vector3.UP * 45.0)
	await _shot("%s/clearing_fog_sunny.png" % folder, 60)


func _shot(path: String, frames := 40) -> void:
	# (and long enough for the rain to fill the air round the camera where it now is)
	if weather.rain > 0.02:
		await create_timer(1.4).timeout
	for i in frames:
		await process_frame
	if path != "":
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
