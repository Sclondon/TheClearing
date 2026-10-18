extends SceneTree
## Pictures of the gibbons (creatures/gibbon/, scripts/enemies/maze_gibbon.gd):
## first in a plain grey studio, under a bar and on the floor (the three coats
## standing; the face; brachiating, hanging still, flying a gap, walking upright,
## sitting, the great call, the lunge); then in the halls of a real round
## (World: the game's light and mist), a troop on the ledges, swinging along
## them, calling, and coming at the boy on the ivy; and the draws a frame takes.
## Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/gibbon_shots.gd -- <folder> [studio|maze]

var folder := "gibbon_shots"
var only := ""
var camera: Camera3D
var stage: Node3D

const BAR := 2.2


## Moves a gibbon along +X at `speed` (m/s), every frame, and back the other way past `turn_at`.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0
	var turn_at := 6.0

	func _process(delta: float) -> void:
		body.global_position.x += speed * delta
		if absf(body.global_position.x) > turn_at:
			body.global_position.x = -turn_at * signf(body.global_position.x)
			if body.has_method(&"settle"):
				body.settle()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


# --- The studio ---

func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.61, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.61, 0.62)
	env.fog_density = 0.012
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.49)
	floor.material_override = mat
	stage.add_child(floor)
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = 30.0
	bar.mesh = rod
	bar.rotation.z = PI * 0.5
	bar.position = Vector3(0.0, BAR + 0.02, 0.0)
	bar.material_override = mat
	stage.add_child(bar)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()

	# The three coats standing side by side.
	var made: Array[Gibbon] = []
	for k in 3:
		var one := Gibbon.new()
		one.kind = k as Gibbon.Kind
		one.seed_value = k + 1
		one.sound = false
		one.gait = Gibbon.Gait.WALK
		stage.add_child(one)
		one.position = Vector3((k - 1) * 1.2, 0.0, 3.0)
		one.rotation.y = 0.0
		one.settle()
		made.append(one)
	await wait(0.5)
	_look_from(Vector3(0.0, 0.9, 6.6), Vector3(0.0, 0.5, 3.0))
	await shot("01_coats_front")
	_look_from(Vector3(3.6, 1.1, 5.4), Vector3(0.0, 0.5, 3.0))
	await shot("02_coats_three_quarter")
	_look_from(Vector3(-3.6, 0.8, 3.1), Vector3(0.0, 0.5, 3.0))
	await shot("03_coats_side")
	# The faces.
	var ringed := made[1]
	ringed.look_at_point = Vector3(0.0, 0.7, 8.0)
	await wait(0.5)
	var face := ringed.global_position + Vector3(0.0, 0.76, 0.03)
	_look_from(face + Vector3(0.12, 0.03, 0.75), face)
	await shot("04_face_ringed")
	var dark := made[0]
	dark.look_at_point = Vector3(-1.2, 0.7, 8.0)
	await wait(0.5)
	face = dark.global_position + Vector3(0.0, 0.76, 0.03)
	_look_from(face + Vector3(0.35, 0.05, 0.65), face)
	await shot("05_face_dark")
	for one in made:
		one.queue_free()
	await wait(0.1)

	# Hanging from the bar, brachiating along it.
	var swinger := Gibbon.new()
	swinger.kind = Gibbon.Kind.RINGED
	swinger.seed_value = 7
	swinger.sound = false
	swinger.gait = Gibbon.Gait.HANG
	stage.add_child(swinger)
	swinger.position = Vector3(-5.0, BAR, 0.0)
	swinger.rotation.y = PI * 0.5
	swinger.settle()
	var drive := Driver.new()
	drive.body = swinger
	drive.speed = 0.0
	stage.add_child(drive)
	await wait(0.8)
	swinger.global_position.x = 0.0
	swinger.settle()
	await wait(0.6)
	_look_from(Vector3(0.0, 1.4, 4.2), Vector3(0.0, 1.5, 0.0))
	await shot("10_hang_still")
	await wait(1.5)
	await shot("11_hang_still_later")
	drive.speed = 2.5
	await wait(1.6)
	for k in 4:
		_look_from(swinger.global_position + Vector3(0.0, -0.6, 4.0), swinger.global_position + Vector3(0.0, -0.7, 0.0))
		await shot("12_brachiate_slow_%d" % k)
		await wait(0.12)
	drive.speed = 6.0
	await wait(1.2)
	for k in 4:
		_look_from(swinger.global_position + Vector3(0.0, -0.5, 5.0), swinger.global_position + Vector3(0.0, -0.7, 0.0))
		await shot("13_brachiate_fast_%d" % k)
		await wait(0.09)
	_look_from(swinger.global_position + Vector3(3.5, -0.4, 3.0), swinger.global_position + Vector3(0.0, -0.7, 0.0))
	await shot("14_brachiate_fast_quarter")
	# Flying a gap.
	drive.speed = 0.0
	swinger.gait = Gibbon.Gait.FLY
	swinger.global_position = Vector3(0.0, BAR + 0.5, 0.0)
	drive.speed = 7.0
	await wait(0.3)
	_look_from(swinger.global_position + Vector3(0.5, -0.4, 4.0), swinger.global_position + Vector3(0.0, -0.5, 0.0))
	await shot("15_fly")
	# Hanging, the great call.
	drive.speed = 0.0
	swinger.gait = Gibbon.Gait.HANG
	swinger.global_position = Vector3(0.0, BAR, 0.0)
	swinger.settle()
	swinger.look_at_point = Vector3(0.0, 4.0, 6.0)
	await wait(0.4)
	swinger.great_call()
	await wait(1.2)
	_look_from(Vector3(0.6, 1.6, 3.6), Vector3(0.0, 1.6, 0.0))
	await shot("16_call_hanging")
	await wait(1.9)
	await shot("17_call_climax_hanging")
	await wait(1.8)
	# The lunge, hanging: at a point below and out in front.
	var mark := Vector3(1.2, 0.8, 0.9)
	swinger.look_at_point = mark
	swinger.lunge(mark)
	await wait(0.45)
	_look_from(Vector3(-1.0, 1.4, 4.4), Vector3(0.4, 1.3, 0.3))
	await shot("18_lunge_wind_up")
	await wait(0.28)
	await shot("19_lunge_strike")
	swinger.queue_free()
	drive.queue_free()
	await wait(0.2)

	# Walking upright, sitting, calling sat.
	var walker := Gibbon.new()
	walker.kind = Gibbon.Kind.PALE
	walker.seed_value = 9
	walker.sound = false
	walker.gait = Gibbon.Gait.WALK
	stage.add_child(walker)
	walker.position = Vector3(-4.0, 0.0, 0.0)
	walker.rotation.y = PI * 0.5
	walker.settle()
	var walk := Driver.new()
	walk.body = walker
	walk.speed = 1.3
	stage.add_child(walk)
	await wait(1.5)
	for k in 3:
		_look_from(walker.global_position + Vector3(0.0, 0.6, 3.2), walker.global_position + Vector3(0.0, 0.5, 0.0))
		await shot("20_walk_%d" % k)
		await wait(0.15)
	_look_from(walker.global_position + Vector3(2.4, 0.7, 2.2), walker.global_position + Vector3(0.0, 0.5, 0.0))
	await shot("21_walk_quarter")
	walk.speed = 0.0
	walker.sitting = true
	await wait(1.5)
	_look_from(walker.global_position + Vector3(1.2, 0.6, 2.4), walker.global_position + Vector3(0.0, 0.35, 0.0))
	await shot("22_sit")
	walker.great_call()
	await wait(3.1)
	await shot("23_call_climax_sat")
	walker.queue_free()
	walk.queue_free()
	stage.queue_free()
	await wait(0.2)


# --- In the maze ---

var world
var maze


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	var boy = world.player
	boy.takes_input = false
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# The section with the longest joined-up stretch of ways, and a face of it with a few ways on.
	var layout: MazeLayout = world.get_node("Maze").layout
	var ways: GibbonWays = null
	var biggest := 0
	for section in range(1, maze.rings + 1):
		var began := Time.get_ticks_usec()
		var some := GibbonWays.of(maze, section, layout)
		print("section %d ways made in %.1f ms (%d faces)" % [section, (Time.get_ticks_usec() - began) / 1000.0, some.size()])
		for g in some.group_sizes.size():
			if some.group_sizes[g] > biggest:
				biggest = some.group_sizes[g]
				ways = some
	var home := -1
	for f in ways.size():
		if ways.group_sizes[ways.groups[f]] == biggest and ways.links[f].size() >= 3:
			home = f
			break
	print("ways: section %d, %d faces, its longest stretch %d" % [ways.ring, ways.size(), biggest])
	var p: Vector3 = ways.point(home)
	var out: Vector3 = ways.outs[home]
	var along: Vector3 = ways.alongs[home]
	# The boy down in the hall, away from them (they have not seen him).
	boy.remove_from_group(&"maze_players")
	boy.global_position = Vector3(p.x, 0.1, p.z) + out * 7.0 + along * 30.0
	var bare := await _draws()
	var troop := MazeGibbon.troop(4)
	for k in troop.size():
		var one: MazeGibbon = troop[k]
		one.maze = maze
		one.seed_choices(k * 5 + 2)
		one.position = Vector3(p.x, 0.05, p.z) + out * 2.0
		world.add_child(one)
	await wait(2.0)
	print("draws with a troop of four: +%d" % ((await _draws()) - bare))
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.make_current()
	# From the hall floor, looking up at them on the ledge.
	cam.global_position = Vector3(p.x, 1.4, p.z) + out * 9.0 + along * 3.0
	cam.look_at(p + Vector3.UP * 0.3)
	await shot("30_troop_on_ledge_from_below")
	# Close, at their height, across the hall.
	cam.global_position = p + out * 6.0 + Vector3.UP * 1.2 + along * 1.5
	cam.look_at(troop[0].body.global_position + Vector3.UP * 0.3)
	await shot("31_troop_close")
	# He comes into the hall below: the great call.
	boy.add_to_group(&"maze_players")
	boy.global_position = Vector3(p.x, 0.1, p.z) + out * 6.0 + along * 4.0
	await wait(1.6)
	cam.global_position = Vector3(p.x, 1.6, p.z) + out * 10.0 + along * -2.0
	cam.look_at(p + Vector3.UP * 0.2 + along * 2.0)
	await shot("32_great_call_over_him")
	await wait(1.6)
	await shot("33_call_climax")
	# He climbs up onto the ledge: they come swinging.
	var further := ways.around(home, 6)
	var spot: int = further[further.size() - 1]
	for f: int in further:
		if ways.point(f).y > 5.0 and ways.point(f).y < 20.0 and ways.point(f).distance_to(ways.point(home)) > 15.0:
			spot = f
	boy.global_position = ways.point(spot) - ways.outs[spot] * 0.6 + Vector3.UP * 0.1
	for one in troop:
		one._call_rest = 99.0
		one.notice(boy)
	await wait(1.0, func() -> bool:
		for one in troop:
			if one._gait == Gibbon.Gait.FLY:
				return true
		return false)
	var lead: MazeGibbon = troop[0]
	for one in troop:
		if one.mode == MazeGibbon.Mode.HUNTING and one.global_position.distance_to(boy.global_position) < lead.global_position.distance_to(boy.global_position):
			lead = one
	for k in 3:
		cam.global_position = lead.global_position + ways.outs[lead.face] * 6.0 + Vector3.UP * 0.3
		cam.look_at(lead.global_position + Vector3.DOWN * 0.6)
		await shot("34_swinging_%d" % k)
		await wait(0.35)
	await wait(20.0, func() -> bool:
		for one in troop:
			if one.body.lunge_stage() == Gibbon.Lunge.WIND_UP and one.body.lunge_progress() > 0.6:
				lead = one
				return true
		return false)
	var side: Vector3 = ways.alongs[spot]
	print("boy at %s (%.1f up), the lunging one at %s, %s" % [boy.global_position, boy.global_position.y, lead.global_position, Gibbon.Gait.keys()[lead._gait]])
	cam.global_position = (boy.global_position + lead.global_position) * 0.5 + ways.outs[spot] * 6.0 + side * 1.5 + Vector3.UP * 0.8
	cam.look_at((boy.global_position + lead.global_position) * 0.5 + Vector3.UP * 0.4)
	await shot("35_wind_up")
	await wait(0.25)
	await shot("36_strike")
	print("striking one: visible %s at %s mode %s, its body at %s, inside tree %s" % [lead.body.visible, lead.global_position, MazeGibbon.Mode.keys()[lead.mode], lead.body.global_position, lead.is_inside_tree()])
	print("maze shots done")


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
