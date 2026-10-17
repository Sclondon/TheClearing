extends SceneTree
## Every cut of trousers and shape of boot BodyShape makes: a row for each cut
## (with the boots as made), then a row for each boot (with tapered trousers),
## seen from the front, three-quarters, the side and behind. Needs a real window:
##
##     godot --path . --resolution 1200x1500 -s res://tools/legs_sheet.gd -- <file.png>

const CELL := 300
const VIEWS := [0.0, 0.7, 1.5708, 2.6, 1.5708]

var out := "legs.png"


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
	BodyShape.add_to(figure.rig)
	var rows: Array = []
	for cut: String in BodyShape.cut_names():
		rows.append([cut, "round"])
	for boot: String in BodyShape.boot_names():
		if boot != "round":
			rows.append(["taper", boot])
	var sheet := Image.create(CELL * VIEWS.size(), CELL * rows.size(), false, Image.FORMAT_RGBA8)
	for row in rows.size():
		Looks.apply(figure.rig, Looks.decode("p11", 0).merged({"cut": rows[row][0], "boots": rows[row][1]}, true))
		for column in VIEWS.size():
			var yaw: float = VIEWS[column]
			var legs := Vector3(0.0, 0.32, 0.0)
			camera.position = legs + Vector3(sin(yaw), 0.12, cos(yaw)) * 2.3
			if column == VIEWS.size() - 1:
				# (the last, close on his left boot from the side)
				legs = Vector3(0.09, 0.07, 0.04)
				camera.position = legs + Vector3(sin(yaw), 0.05, cos(yaw)) * 0.9
			camera.look_at(legs)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var side := mini(shot.get_width(), shot.get_height())
			shot = shot.get_region(Rect2i((shot.get_width() - side) / 2, (shot.get_height() - side) / 2, side, side))
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(column * CELL, row * CELL))
		print("row ", row, ": ", rows[row])
	sheet.save_png(out)
	print("saved ", out)
	quit()
