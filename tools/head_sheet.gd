extends SceneTree
## Every head HeadShape makes, side by side: a row for each, seen from the front,
## three-quarters, the side and from behind, close up. Needs a real window:
##
##     godot --path . --resolution 1200x1500 -s res://tools/head_sheet.gd -- <file.png>

const CELL := 300
const VIEWS := [0.0, 0.7, 1.5708, 2.6]

var out := "heads.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run()


func _run() -> void:
	await process_frame
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.52, 0.55, 0.53)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.7)
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	sun.light_energy = 0.9
	stage.add_child(sun)
	var floor := StaticBody3D.new()
	var ground := CollisionShape3D.new()
	ground.shape = WorldBoundaryShape3D.new()
	floor.add_child(ground)
	stage.add_child(floor)
	var figure := Figure.new()
	stage.add_child(figure)
	figure.place(Vector3.ZERO, 0.0)
	var camera := Camera3D.new()
	camera.fov = 24.0
	stage.add_child(camera)
	camera.make_current()
	for i in 90:
		await process_frame
	HeadShape.add_to(figure.rig)
	var names := HeadShape.names()
	var sheet := Image.create(CELL * VIEWS.size(), CELL * names.size(), false, Image.FORMAT_RGBA8)
	for row in names.size():
		Looks.apply(figure.rig, Looks.decode("p11", 0).merged({"head": names[row]}))
		var look: Dictionary = figure.rig.look
		look["parts"]["head"] = HeadShape.option(names[row])
		figure.rig.restyle()
		for column in VIEWS.size():
			var yaw: float = VIEWS[column]
			var head := Vector3(0.0, 1.08, 0.0)
			camera.position = head + Vector3(sin(yaw), 0.08, cos(yaw)) * 1.3
			camera.look_at(head)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var side := mini(shot.get_width(), shot.get_height())
			shot = shot.get_region(Rect2i((shot.get_width() - side) / 2, (shot.get_height() - side) / 2, side, side))
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(column * CELL, row * CELL))
		print("head ", row, ": ", names[row])
	sheet.save_png(out)
	print("saved ", out)
	quit()
