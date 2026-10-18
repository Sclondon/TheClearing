extends SceneTree
## Pictures of the pines to look at, in the game's sky, mist and sun: a few trees on
## grey ground from where a boy would see them, closer to (a frond's needles), from
## below the crown, and a stand of them far off (the plain trees). Needs a real
## window (the engine draws nothing headless):
##
##     godot --path . --resolution 720x1280 -s res://tools/pine_shots.gd -- <folder>

var folder := "shots/pines"
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run()


func shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func look(from: Vector3, at: Vector3) -> void:
	camera.global_transform = Transform3D(Basis.looking_at(at - from), from)


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	MazeLight.put(scene)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.2, 0.22, 0.18)
	dirt.roughness = 1.0
	ground.material_override = dirt
	scene.add_child(ground)
	var pine := PineTree.new()
	pine.height = 13.0
	pine.seed = 7
	for i in 3:
		var tree := pine.instance(i)
		tree.position = Vector3(i * 7.0 - 7.0, 0.0, -float(i % 2) * 5.0)
		scene.add_child(tree)
	var far: Array = []
	for i in 40:
		far.append(Vector3(randf_range(-60.0, 60.0), 0.0, randf_range(-160.0, -100.0)))
	PineTree.forest(scene, far, pine, 3)
	camera = Camera3D.new()
	camera.fov = 62.0
	scene.add_child(camera)
	camera.make_current()
	await process_frame
	look(Vector3(0.0, 1.6, 18.0), Vector3(0.0, 6.0, 0.0))
	await shot("stand")
	look(Vector3(2.5, 4.0, 1.5), Vector3(0.0, 4.0, -5.0))
	await shot("close")
	look(Vector3(1.2, 3.6, -2.0), Vector3(0.0, 3.3, -5.0))
	await shot("needles")
	look(Vector3(0.8, 1.2, -4.2), Vector3(0.0, 8.0, -5.0))
	await shot("under")
	look(Vector3(0.0, 3.0, 40.0), Vector3(0.0, 8.0, -120.0))
	await shot("far")
	quit(0)
