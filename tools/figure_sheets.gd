extends SceneTree
## Not part of the game. Puts any figure built for the boy's rig on a CharacterRig,
## under a Figure (scripts/figure.gd), and saves contact sheets of it standing,
## walking and running, to check a new model without wiring it into a level.
##
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/figure_sheets.gd -- <outdir> <res://models/x.glb> [scale] [looseness=0.7] [stoop=0] [arms_reach=0]
##
## Writes <outdir>/<x>_turnaround.png, _idle.png, _walk.png and _run.png, and
## prints lines starting CHECK about the skeleton: read those first.
## Its window is kept off the screen and takes no input.

const CELL := 480
## What CharacterRig cannot do without, and what it uses if it finds it.
const REQUIRED := ["hips", "spine", "head", "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "toe_l", "thigh_r", "shin_r", "foot_r", "toe_r"]
const OPTIONAL := ["chest", "neck", "finger0a_l", "thumba_l", "hem_0", "hair_f", "cap"]

var out := ""
var path := ""
var label := ""
var size := 1.0
var tuning := {"looseness": 0.7, "stoop": 0.0, "arms_reach": 0.0}
var stage: Node3D
var figure: CharacterBody3D
var cam: Camera3D
var cells: Array[Image] = []
## Yaw round it (0: from straight in front), pitch, and distance in figure heights.
var view := Vector3(0.6, 0.1, 2.6)
var tall := 1.25
var failed := false


func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <outdir> <res://models/x.glb> [scale] [looseness=..] [stoop=..] [arms_reach=..]")
		quit(1)
		return
	out = args[0]
	path = args[1]
	label = path.get_file().get_basename()
	for arg: String in args.slice(2):
		if "=" in arg:
			tuning[arg.get_slice("=", 0)] = arg.get_slice("=", 1).to_float()
		else:
			size = arg.to_float()
	DirAccess.make_dir_recursive_absolute(out)
	var model := load(path) as PackedScene
	if model == null:
		printerr("CHECK cannot load ", path, " (built, and imported with `godot --headless --path . --import`?)")
		quit(1)
		return
	if not check(model):
		quit(1)
		return

	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.56, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	# A floor, wide enough to run on for as long as this takes
	var ground := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600, 2, 600)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.32, 0.34)
	material.roughness = 1.0
	visual.material_override = material
	ground.add_child(visual)
	ground.position = Vector3(0, -1, 0)
	stage.add_child(ground)

	# (loaded by path, so this works before the editor has learnt the class's name)
	figure = load("res://scripts/figure.gd").new()
	figure.model = model
	figure.size = size
	figure.height = tall * size
	figure.radius = minf(0.26 * size, figure.height * 0.4)
	for key: String in tuning:
		figure.set(key, tuning[key])
	figure.position = Vector3(0, 0.02, 0)
	stage.add_child(figure)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	run.call_deferred()


## Looks the skeleton over before anything is asked of it. False if the rig could not use it.
func check(model: PackedScene) -> bool:
	var made := model.instantiate()
	var found := made.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		printerr("CHECK ", label, ": no skeleton in it")
		made.free()
		return false
	var skeleton: Skeleton3D = found[0]
	var missing: Array = REQUIRED.filter(func(bone: String) -> bool: return skeleton.find_bone(bone) < 0)
	var extras: Array = OPTIONAL.filter(func(bone: String) -> bool: return skeleton.find_bone(bone) >= 0)
	var turned: Array = []
	for bone in skeleton.get_bone_count():
		if not skeleton.get_bone_rest(bone).basis.is_equal_approx(Basis.IDENTITY):
			turned.append(skeleton.get_bone_name(bone))
	var ok := missing.is_empty() and turned.is_empty()
	if not missing.is_empty():
		printerr("CHECK ", label, ": missing bones ", missing)
	if not turned.is_empty():
		printerr("CHECK ", label, ": bones that do not rest unrotated ", turned)
	if ok:
		# Parents, and the lie of the limbs, as the rig takes them to be
		var back := "chest" if skeleton.find_bone("chest") >= 0 else "spine"
		var wanted := {"spine": "hips", "upper_arm_l": back, "upper_arm_r": back, "forearm_l": "upper_arm_l", "hand_l": "forearm_l",
			"thigh_l": "hips", "shin_l": "hips", "foot_l": "hips", "toe_l": "foot_l", "thigh_r": "hips", "shin_r": "hips", "foot_r": "hips", "toe_r": "foot_r",
			"head": "neck" if skeleton.find_bone("neck") >= 0 else back}
		for bone: String in wanted:
			var parent := skeleton.get_bone_parent(skeleton.find_bone(bone))
			var has := skeleton.get_bone_name(parent) if parent >= 0 else "nothing"
			if has != wanted[bone]:
				printerr("CHECK ", label, ": ", bone, " is under ", has, ", not ", wanted[bone])
				ok = false
		var rest := func(bone: String) -> Vector3: return skeleton.get_bone_rest(skeleton.find_bone(bone)).origin
		var thigh: Vector3 = rest.call("thigh_l")
		var foot: Vector3 = rest.call("foot_l")
		var ankle: float = rest.call("hips").y + foot.y
		tall = rest.call("hips").y
		for bone: String in ["spine", "chest", "neck", "head"]:
			if skeleton.find_bone(bone) >= 0:
				tall += rest.call(bone).y
		# (the head's joint is at the base of the skull)
		tall += 0.22
		if thigh.x <= 0.0:
			printerr("CHECK ", label, ": thigh_l is not at +X. The figure's left is +X, and it faces +Z.")
			ok = false
		if absf(ankle - 0.05) > 0.03:
			print("CHECK ", label, ": ankle joint rests ", snappedf(ankle, 0.001), " up; the rig stands it at 0.05, so the soles should be modelled ", snappedf(ankle - 0.05, 0.001), " from the ground")
		if absf(rest.call("forearm_l").z) > 0.01 or absf(rest.call("hand_l").z) > 0.01:
			print("CHECK ", label, ": the arm is not in the X-Y plane at rest; the rig takes it to be")
		print("CHECK ", label, ": ", "ok" if ok else "NOT usable", "; hips ", snappedf(rest.call("hips").y, 0.001), ", leg ", snappedf(thigh.distance_to(foot), 0.001),
			", about ", snappedf(tall, 0.01), " m tall as modelled, ", snappedf(tall * size, 0.01), " m at this scale; optional bones: ", extras if not extras.is_empty() else "none")
		if skeleton.find_bone("chest") < 0:
			print("CHECK ", label, ": no chest bone, so it stands stock still when idle (the mummy does)")
	made.free()
	return ok


func aim() -> void:
	var yaw: float = figure.facing_yaw + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch: Vector3 = figure.visual_position + Vector3.UP * tall * size * 0.5
	cam.global_position = watch + away * view.z * tall * size
	cam.look_at(watch)


func frames(count: int) -> void:
	for i in count:
		aim()
		await physics_frame
		await process_frame
		measure()


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


func sheet(name: String, columns := 3) -> void:
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	var file := out.path_join("%s_%s.png" % [label, name])
	page.save_png(file)
	cells.clear()
	print("SHEET ", file)


## Keeps the extremes of where the joints get to, to say afterwards whether anything flew apart.
var _low := INF
var _high := -INF
var _far := 0.0

func measure() -> void:
	var skeleton: Skeleton3D = figure.rig._skeleton
	var hips := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hips")).origin
	for bone in skeleton.get_bone_count():
		var at := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
		if not at.is_finite():
			failed = true
			continue
		_low = minf(_low, at.y)
		_high = maxf(_high, at.y)
		_far = maxf(_far, at.distance_to(hips))


func report(name: String) -> void:
	# No joint should be further from the hips than the figure is tall, or far under the floor.
	var bad := failed or _far > tall * size * 1.1 or _low < -0.15 * size
	print("CHECK ", label, " ", name, ": joints between ", snappedf(_low, 0.01), " and ", snappedf(_high, 0.01), " m up, at most ", snappedf(_far, 0.01), " m from the hips", "  <-- SOMETHING HAS COME APART" if bad else "")
	_low = INF
	_high = -INF
	_far = 0.0


func run() -> void:
	await frames(5)
	# At rest, from all round
	figure.place(Vector3(0, 0.02, 0), 0.0)
	await frames(50)
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 2.5)
		await frames(2)
		await snap()
	sheet("turnaround")
	report("standing")

	# Left to stand: it should shift its weight, breathe and look about
	view = Vector3(0.5, 0.1, 2.5)
	for i in 6:
		await frames(75)
		await snap()
	sheet("idle")
	report("idle")

	await strip("walk", false)
	await strip("run", true)
	quit(1 if failed else 0)


## A stride from the side, frame by frame, then the same from in front and from behind.
func strip(name: String, hurry: bool) -> void:
	figure.place(Vector3(0, 0.02, 0), PI * 0.5)
	figure.go_to(Vector3(500, 0, 0), hurry)
	view = Vector3(PI * 0.5, 0.05, 2.6 if not hurry else 2.9)
	await frames(90)
	for i in 6:
		await frames(3 if hurry else 5)
		await snap()
	view = Vector3(0.5, 0.1, 2.9)
	for i in 3:
		await frames(4 if hurry else 7)
		await snap()
	view = Vector3(PI - 0.6, 0.15, 2.9)
	for i in 3:
		await frames(4 if hurry else 7)
		await snap()
	var speed := Vector2(figure.velocity.x, figure.velocity.z).length()
	print("CHECK ", label, " ", name, ": going ", snappedf(speed, 0.01), " m/s")
	sheet(name)
	report(name)
	figure.stop()
