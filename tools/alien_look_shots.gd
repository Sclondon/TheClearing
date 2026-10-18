extends SceneTree
## Pictures of the alien on its own (creatures/alien/: AlienBody), on a plain
## floor in the game's kind of light: close-ups from the front, side, three
## quarters and back, the face, and frames out of each of its motions (the
## walk, the head's tilt, the reach and its light, the shimmer, blinking out
## and in). Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/alien_look_shots.gd -- <folder>

var folder := "alien_shots"
var stage: Node3D
var camera: Camera3D
var alien: AlienBody
var stand_in: MeshInstance3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _setup() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.63)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.57, 0.6)
	environment.ambient_light_energy = 0.4
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.6, 0.62, 0.63)
	environment.fog_density = 0.02
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.36, 0.35, 0.32)
	ground.roughness = 1.0
	floor_mesh.material_override = ground
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.current = true
	alien = AlienBody.new()
	stage.add_child(alien)
	# Someone to reach for: a figure-sized post.
	stand_in = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	stand_in.mesh = capsule
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.55, 0.12, 0.1)
	stand_in.material_override = red
	stand_in.visible = false
	stage.add_child(stand_in)


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## The camera at `from` (relative to the alien's feet), looking at `at` (also relative).
func look(from: Vector3, at: Vector3) -> void:
	var base := alien.global_position
	camera.global_position = base + from
	camera.look_at(base + at, Vector3.UP)


func _run() -> void:
	_setup()
	await wait(0.6)
	# Standing, from round about.
	alien.look_at_point = alien.global_position + Vector3(0.0, 2.0, 6.0)
	# (for the close-ups, its head held straight)
	alien._tilt_to = 0.0
	alien._tilt_in = 1000.0
	await wait(1.5)
	look(Vector3(0.0, 1.4, 5.2), Vector3(0.0, 1.2, 0.0))
	await shot("front")
	look(Vector3(5.2, 1.4, 0.0), Vector3(0.0, 1.2, 0.0))
	await shot("side")
	look(Vector3(3.6, 1.6, 3.8), Vector3(0.0, 1.2, 0.0))
	await shot("three_quarter")
	look(Vector3(-2.5, 1.5, -4.5), Vector3(0.0, 1.2, 0.0))
	await shot("back")
	look(Vector3(0.0, 2.05, 1.25), Vector3(0.0, 2.02, 0.0))
	await shot("face")
	look(Vector3(0.85, 2.1, 0.95), Vector3(0.0, 2.02, 0.0))
	await shot("face_three_quarter")
	look(Vector3(1.2, 2.05, 0.0), Vector3(0.0, 2.02, 0.0))
	await shot("face_side")
	look(Vector3(0.7, 1.0, 1.0), Vector3(0.2, 0.85, 0.0))
	await shot("hand")
	# The head tipping as it watches something.
	alien.look_at_point = alien.global_position + Vector3(2.5, 1.0, 4.0)
	alien._tilt_in = 0.0
	await wait(2.5)
	look(Vector3(0.6, 2.1, 1.9), Vector3(0.0, 2.0, 0.0))
	await shot("head_tilt")

	# The walk, from the side, the camera going with it.
	alien.look_at_point = Vector3.INF
	for i in 160:
		alien.global_position += Vector3(0.0, 0.0, 1.15) / 60.0
		look(Vector3(4.8, 1.3, 0.6), Vector3(0.0, 1.1, 0.4))
		await process_frame
		if i >= 100 and i % 15 == 0:
			await shot("walk_%d" % ((i - 100) / 15))
	for i in 60:
		alien.global_position += Vector3(0.0, 0.0, 1.15) / 60.0
		look(Vector3(2.8, 1.5, 4.2), Vector3(0.0, 1.1, 0.0))
		await process_frame
	await shot("walk_front")
	await wait(1.2)
	await shot("stopped")

	# Reaching for someone: up, shining, down.
	stand_in.visible = true
	stand_in.global_position = alien.global_position + Vector3(0.3, 0.75, 2.2)
	alien.look_at_point = stand_in.global_position + Vector3.UP * 0.5
	await wait(0.8)
	alien.reach(stand_in.global_position + Vector3.UP * 0.2)
	look(Vector3(4.6, 1.9, -0.6), Vector3(0.0, 1.4, 0.9))
	await wait(0.4)
	await shot("reach_raise")
	await wait(0.5)
	await shot("reach_light")
	look(Vector3(-0.8, 1.8, 4.5), Vector3(0.0, 1.5, 0.8))
	await wait(0.1)
	await shot("reach_light_front")
	print("in its light: ", alien.in_beam(stand_in.global_position + Vector3.UP * 0.2), "; a step aside: ", alien.in_beam(stand_in.global_position + Vector3(1.6, 0.2, 0.0)))
	await wait(1.2)
	stand_in.visible = false

	# Warning, going, coming.
	var there := alien.global_position + Vector3(2.5, 0.0, 2.0)
	alien.shimmer(there, 1.2)
	look(Vector3(1.0, 2.2, 8.0), Vector3(1.2, 1.2, 0.8))
	await wait(0.7)
	await shot("shimmer")
	await wait(0.5)
	alien.blink_out()
	await wait(0.15)
	await shot("blink_out_a")
	await wait(0.15)
	await shot("blink_out_b")
	await wait(0.3)
	alien.blink_in(there, PI)
	look(Vector3(-2.0, 2.0, -5.5), Vector3(0.0, 1.2, 0.0))
	await wait(0.12)
	await shot("blink_in_a")
	await wait(0.2)
	await shot("blink_in_b")
	await wait(0.6)
	await shot("blink_in_done")
	quit()
