extends SceneTree
## Pictures of the lonely horse (creatures/horse) on a plain floor under the
## game's kind of light: each coat, the halter, the head, a gallop and a canter
## side on, grazing, and the roll. Says how many draws a frame takes. Needs a
## real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/horse_shots.gd -- <folder>

var folder := "horse_shots"
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func look(target: Vector3, offset: Vector3, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.66)
	environment.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.45, 0.44, 0.42)
	floor.material_override = ground
	stage.add_child(floor)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var names := ["grey", "dun", "bay"]
	for c in 3:
		var horse := Horse.new()
		horse.coat = c
		horse.haltered = c == 1
		horse.sound = false
		stage.add_child(horse)
		await frames(30)
		look(Vector3(0.0, 1.1, 0.0), Vector3(4.2, 0.7, 2.6))
		await shot("s0%d_%s_quarter" % [c + 1, names[c]])
		if c == 1:
			look(horse.nose_position().lerp(Vector3(0.0, 1.6, 0.8), 0.55), Vector3(0.9, 0.2, 0.9))
			await shot("s04_dun_head")
			look(Vector3(0.0, 1.0, 0.0), Vector3(-3.0, 1.0, -4.0))
			await shot("s05_dun_behind")
			horse.measure_velocity = false
			for speed: float in [1.4, 6.0, 10.0]:
				horse.velocity = Vector3(0.0, 0.0, speed)
				for k in 3:
					await frames(11 + k * 4)
					look(Vector3(0.0, 1.0, 0.0), Vector3(6.0, 0.4, 0.0))
					await shot("g_%04.1f_%d" % [speed, k])
			horse.velocity = Vector3.ZERO
			horse.grazing = true
			await frames(150)
			look(Vector3(0.0, 0.8, 0.0), Vector3(4.0, 0.6, 2.0))
			await shot("s06_grazing")
			horse.grazing = false
			horse.roll()
			for k in 4:
				await frames(110)
				look(Vector3(0.0, 0.6, 0.0), Vector3(4.0, 1.4, 2.5))
				await shot("s07_roll_%d" % k)
		horse.queue_free()
		await frames(2)
	quit()
