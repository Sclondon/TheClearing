extends SceneTree
## Pictures of the rats (creatures/rats/; scripts/enemies/maze_rat.gd,
## maze_rat_swarm.gd, maze_rat_king.gd). First in a plain grey studio, each
## framed to fill most of the picture: a rat from the side, three-quarters
## front and above; the low one beside it; the steps of a walk and of a bound;
## reared up to sniff; feeding, head down; squealing; a crowd; the knot of a
## rat king, and the king itself writhing, dragging and shrieking. (Shots in a
## real round's passage are still to be added: `maze` does nothing yet.)
## Says how many draws a frame takes. Needs a real window (the
## engine draws nothing headless). Landscape, as the user looks at them:
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/rats_shots.gd -- <folder> [studio|maze|king]

var folder := "rat_shots"
var only := ""
var hall_pick := 0
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	if args.size() > 2 and args[2].is_valid_int():
		hall_pick = int(args[2])
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	if only == "" or only == "studio":
		await _studio()
	if only == "" or only == "king":
		await _king_studio()
	if only == "" or only == "maze":
		await _maze()
	quit()


# --- The studio ---

var _posed: MultiMeshInstance3D
var _stage: Node3D


## Rats posed by hand: each [transform, custom (RatLook.custom), low].
func pose(rats: Array, low := false) -> void:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = RatLook.mesh(low)
	many.instance_count = rats.size()
	for i in rats.size():
		var one: Array = rats[i]
		many.set_instance_transform(i, one[0])
		many.set_instance_custom_data(i, one[1])
	_posed.multimesh = many


func _set_up_studio() -> void:
	_stage = Node3D.new()
	_stage.name = "Studio"
	root.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.63, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.5
	var surround := WorldEnvironment.new()
	surround.environment = env
	_stage.add_child(surround)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.9
	key.shadow_enabled = true
	_stage.add_child(key)
	key.look_at_from_position(Vector3(1.2, 4, 2.0), Vector3.ZERO)
	var floor_slab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_slab.mesh = plane
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.46, 0.46, 0.44)
	concrete.roughness = 0.9
	floor_slab.material_override = concrete
	_stage.add_child(floor_slab)
	camera = Camera3D.new()
	camera.fov = 30.0
	_stage.add_child(camera)
	camera.make_current()
	_posed = MultiMeshInstance3D.new()
	_stage.add_child(_posed)


func _studio() -> void:
	_set_up_studio()
	var still := RatLook.custom(0.0, 0.0, 0.0, 0.0, 0, 0.3)
	pose([[Transform3D.IDENTITY, still]])
	_frame(Vector3(0, 0.04, -0.03), 0.6, 0.12, Vector3(1, 0.15, 0.0))
	await shot("01_rat_side")
	_frame(Vector3(0, 0.04, 0.0), 0.32, 0.12, Vector3(0.8, 0.45, 1))
	await shot("02_rat_front")
	_frame(Vector3(0, 0.04, 0.05), 0.12, 0.09, Vector3(0.5, 0.3, 1))
	await shot("03_rat_head")
	_frame(Vector3(0, 0.0, -0.03), 0.6, 0.2, Vector3(0.0, 1, 0.05))
	await shot("04_rat_above")
	_frame(Vector3(0, 0.04, -0.03), 0.6, 0.12, Vector3(-0.8, 0.5, -0.6))
	await shot("05_rat_behind")
	# The low one beside the full one.
	pose([[Transform3D(Basis.IDENTITY, Vector3(0.12, 0, 0)), still]])
	var other := MultiMeshInstance3D.new()
	_stage.add_child(other)
	var keep := _posed
	_posed = other
	pose([[Transform3D(Basis.IDENTITY, Vector3(-0.12, 0, 0)), still]], true)
	_posed = keep
	_frame(Vector3(0, 0.04, -0.03), 0.6, 0.3, Vector3(0.7, 0.5, 1))
	await shot("06_full_and_low")
	other.queue_free()
	# Four steps of a walk, and of a bound, side on.
	for gait: Array in [["07_walk", 0.15], ["08_bound", 1.0]]:
		var steps: Array = []
		for k in 4:
			steps.append([Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.75 + k * 0.5)), RatLook.custom(k * 0.25, gait[1], 0.0, 0.0, 0, 0.3)])
		pose(steps)
		_frame(Vector3(0, 0.04, -0.05), 2.2, 0.15, Vector3(1, 0.12, 0.0))
		await shot(gait[0])
	# Reared up to sniff; head down feeding; squealing; bent round.
	pose([[Transform3D.IDENTITY, RatLook.custom(0.0, 0.0, 0.0, 0.85, 0, 0.3)]])
	_frame(Vector3(0, 0.08, -0.03), 0.4, 0.22, Vector3(1, 0.2, 0.5))
	await shot("09_reared")
	pose([[Transform3D.IDENTITY, RatLook.custom(0.0, 0.0, 0.0, 0.0, RatLook.HEAD_DOWN, 0.3)]])
	_frame(Vector3(0, 0.03, 0.0), 0.4, 0.12, Vector3(1, 0.3, 0.6))
	await shot("10_feeding")
	pose([[Transform3D.IDENTITY, RatLook.custom(0.0, 0.0, 0.0, 0.5, RatLook.MOUTH_OPEN, 0.3)]])
	_frame(Vector3(0, 0.07, 0.06), 0.16, 0.12, Vector3(0.6, 0.3, 1))
	await shot("11_squeal")
	pose([[Transform3D.IDENTITY, RatLook.custom(0.3, 0.6, 0.8, 0.0, 0, 0.3)]])
	_frame(Vector3(0, 0.03, -0.03), 0.6, 0.2, Vector3(0.0, 1, 0.3))
	await shot("12_bent")
	# A crowd of them on the slab, every way, scurrying and still.
	var crowd: Array = []
	var chance := RandomNumberGenerator.new()
	chance.seed = 5
	for k in 40:
		var at := Vector3(chance.randf_range(-1.2, 1.2), 0.0, chance.randf_range(-0.8, 0.8))
		var big := chance.randf_range(0.85, 1.15)
		crowd.append([Transform3D(Basis(Vector3.UP, chance.randf() * TAU).scaled(Vector3.ONE * big), at), RatLook.custom(chance.randf() * 8.0, chance.randf(), chance.randf_range(-0.6, 0.6), 0.6 if chance.randf() < 0.15 else 0.0, 0, chance.randf())])
	pose(crowd)
	_frame(Vector3(0, 0, 0), 2.6, 1.0, Vector3(0.2, 0.8, 1))
	await shot("13_crowd")
	pose(crowd, true)
	await shot("14_crowd_low")
	_stage.queue_free()
	await process_frame


## A rat king in the studio: the knot alone, then the king writhing (a few moments apart), and squealing.
func _king_studio() -> void:
	_set_up_studio()
	var knot := MeshInstance3D.new()
	knot.mesh = RatLook.knot()
	_stage.add_child(knot)
	_frame(Vector3(0, 0.03, 0), 0.2, 0.1, Vector3(0.6, 0.6, 1))
	await shot("30_knot")
	knot.queue_free()
	var king := RatKing.new()
	king.king_seed = 3
	_stage.add_child(king)
	await wait(1.0)
	for k in 3:
		_frame(Vector3(0, 0.05, 0), 0.75, 0.3, Vector3(0.5, 0.75, 1))
		await shot("31_king_%d" % k)
		await wait(0.7)
	_frame(Vector3(0, 0.05, 0), 0.6, 0.25, Vector3(0.9, 0.35, 0.3))
	await shot("32_king_low")
	_frame(Vector3(0, 0.0, 0), 0.7, 0.7, Vector3(0.05, 1, 0.1))
	await shot("33_king_above")
	king.wish = Vector3(1, 0, 0)
	king.urge = 1.0
	await wait(1.5)
	_frame(king.global_position + Vector3(0, 0.05, 0), 0.75, 0.3, Vector3(0.3, 0.6, 1))
	await shot("34_king_dragging")
	king.squeal()
	await wait(0.4)
	_frame(king.global_position + Vector3(0, 0.06, 0), 0.7, 0.3, Vector3(0.5, 0.5, 1))
	await shot("35_king_squealing")
	_stage.queue_free()
	await process_frame


## Puts the camera looking at `at` from the way `from` points (out from it),
## near enough that something `wide` by `high` fills about 70% of the frame.
func _frame(at: Vector3, wide: float, high: float, from: Vector3) -> void:
	var size := Vector2(root.get_visible_rect().size)
	var down := tan(deg_to_rad(camera.fov) * 0.5)
	var across := down * size.x / size.y
	var distance := maxf(wide / 0.7 * 0.5 / across, high / 0.7 * 0.5 / down)
	var up := Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.BACK
	camera.look_at_from_position(at + from.normalized() * distance, at, up)
	camera.near = 0.005


# --- In the maze ---

func _maze() -> void:
	pass
