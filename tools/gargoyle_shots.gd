extends SceneTree
## Pictures of the gargoyle (creatures/gargoyle/, scripts/enemies/maze_gargoyle.gd):
## first in a studio under the maze's own light, beside a block of the maze's
## concrete (perched as a statue on its top, seen from below; on the ground from
## the front, the side and three-quarters; its face; then caught in the middle of
## each thing it does: waking, the wind-up, bounding, gliding, the wingbeat, the
## pounce, the landing); then in a passage of a real round (World): perched over
## a hall, the drop on someone passing under, the hunt. Landscape by default.
## Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/gargoyle_shots.gd -- <folder> [studio|maze]

var folder := "gargoyle_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves something along at `speed` (m/s) the way it faces, turning at `turn`, rising at `climb`.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0
	var turn := 0.0
	var climb := 0.0

	func _process(delta: float) -> void:
		body.rotation.y += turn * delta
		body.global_position += body.global_basis.z * speed * delta + Vector3.UP * climb * delta


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
	camera.look_at(at, Vector3.UP)


func _block(size: Vector3, at: Vector3) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = Wall.material_for(Wall.Look.CAST)
	box.position = at + Vector3.UP * size.y * 0.5
	stage.add_child(box)


# --- The studio ---

func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	MazeLight.put(stage)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300.0, 300.0)
	ground.mesh = plane
	if true:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.36, 0.34, 0.3)
		ground.material_override = mat
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 45.0
	stage.add_child(camera)
	camera.make_current()
	# A block of the maze's concrete to perch on, and another beside the one on the ground.
	_block(Vector3(10.0, 7.0, 4.0), Vector3(0.0, 0.0, -2.0))
	_block(Vector3(3.0, 1.2, 3.0), Vector3(-5.5, 0.0, 5.0))

	var perched := Gargoyle.new()
	perched.seed_value = 3
	stage.add_child(perched)
	perched.global_position = Vector3(0.0, 7.0, -0.35)
	perched.perched = true
	perched.settle()
	var gargoyle := Gargoyle.new()
	stage.add_child(gargoyle)
	gargoyle.global_position = Vector3(3.5, 0.0, 6.0)
	gargoyle.rotation.y = -0.4
	gargoyle.settle()
	await wait(0.5)
	# Perched on the block as a statue: from below, as someone in the hall sees it, and nearer.
	_look_from(Vector3(1.5, 1.4, 11.0), Vector3(0.0, 7.6, 0.0))
	await shot("01_perched_from_below")
	_look_from(Vector3(3.6, 5.8, 5.0), Vector3(0.0, 7.9, -0.2))
	await shot("02_perched_near")
	_look_from(Vector3(-4.5, 9.5, 3.0), Vector3(0.0, 7.7, -0.2))
	await shot("03_perched_above")
	# On the ground, a statue: front, side, three-quarters.
	var mid := gargoyle.global_position + Vector3.UP * 1.0
	var fwd := gargoyle.global_basis.z
	var side := gargoyle.global_basis.x
	_look_from(mid + fwd * 5.5 + Vector3.UP * 0.4, mid)
	await shot("04_front")
	_look_from(mid - side * 6.0 + Vector3.UP * 0.3, mid)
	await shot("05_side")
	_look_from(mid + (fwd - side).normalized() * 5.5 + Vector3.UP * 1.2, mid)
	await shot("06_three_quarter")
	_look_from(mid - fwd * 6.0 + side * 2.0 + Vector3.UP * 2.0, mid)
	await shot("07_back")
	var face := gargoyle.global_position + Vector3.UP * 1.45 + fwd * 0.62
	_look_from(face + fwd * 1.3 + side * 0.25 + Vector3.UP * 0.05, face)
	await shot("08_face")
	_look_from(face + (fwd * 0.8 + side * 0.9).normalized() * 1.3, face)
	await shot("09_face_three_quarter")
	# Waking: the ember in its cracks, its eyes.
	gargoyle.alive = true
	gargoyle.aim = camera.global_position
	await wait(0.4)
	_look_from(face + fwd * 1.6 + Vector3.UP * 0.1, face)
	await shot("10_waking_face")
	await wait(0.8)
	_look_from(mid + (fwd - side * 0.5).normalized() * 5.0 + Vector3.UP * 0.8, mid)
	await shot("11_awake")
	gargoyle.snarl()
	await wait(0.6)
	_look_from(face + fwd * 1.6 + side * 0.4, face)
	await shot("12_snarl")
	# The wind-up.
	gargoyle.aim = Vector3.INF
	gargoyle.gather(1.2)
	await wait(0.8)
	_look_from(mid + (fwd - side).normalized() * 6.5 + Vector3.UP * 1.0, mid)
	await shot("13_gather")
	_look_from(mid + fwd * 6.5 + Vector3.UP * 0.5, mid)
	await shot("14_gather_front")
	await wait(0.6)
	# Bounding along.
	var drive := Driver.new()
	drive.body = gargoyle
	stage.add_child(drive)
	gargoyle.global_position = Vector3(-10.0, 0.0, 12.0)
	gargoyle.rotation.y = PI * 0.5
	drive.speed = 1.2
	await wait(1.2)
	_look_from(gargoyle.global_position + Vector3(0.0, 1.0, 6.5), gargoyle.global_position + Vector3.UP * 0.8)
	await shot("15_lurch")
	drive.speed = 4.0
	await wait(1.4)
	for k in 4:
		_look_from(gargoyle.global_position + Vector3(0.0, 1.0, 7.5), gargoyle.global_position + Vector3.UP * 0.9)
		await shot("16_bound_%d" % k)
		await wait(0.13)
	_look_from(gargoyle.global_position + Vector3(7.0, 1.6, 4.0), gargoyle.global_position + Vector3.UP * 0.9)
	await shot("17_bound_coming")
	drive.speed = 0.0
	# Gliding, wings spread; then the wingbeat; then the pounce.
	gargoyle.airborne = true
	gargoyle.flapping = 0.0
	gargoyle.global_position = Vector3(0.0, 3.0, 14.0)
	drive.speed = 0.0
	await wait(0.8)
	var air := gargoyle.global_position + Vector3.UP * 1.0
	_look_from(air + Vector3(5.0, 3.5, 6.0), air)
	await shot("18_glide_above")
	_look_from(air + Vector3(0.0, -1.2, 8.0), air)
	await shot("19_glide_front")
	gargoyle.flapping = 1.0
	await wait(1.0)
	for k in 6:
		_look_from(air + Vector3(0.0, 0.6, 9.0), air)
		await shot("20_beat_%d" % k)
		await wait(0.08)
	_look_from(air + Vector3(8.0, 1.0, 0.5), air)
	await shot("21_beat_side")
	gargoyle.flapping = 0.0
	gargoyle.reaching = 1.0
	await wait(0.6)
	_look_from(air + Vector3(4.0, -0.5, 6.0), air)
	await shot("22_pounce")
	_look_from(air + Vector3(0.0, -1.5, 5.5), air)
	await shot("23_pounce_front")
	gargoyle.airborne = false
	gargoyle.reaching = 0.0
	gargoyle.global_position = Vector3(0.0, 0.0, 14.0)
	gargoyle.slam()
	await wait(0.12)
	_look_from(gargoyle.global_position + Vector3(4.5, 1.5, 6.0), gargoyle.global_position + Vector3.UP * 0.7)
	await shot("24_slam")
	await wait(0.5)
	_look_from(gargoyle.global_position + Vector3(4.5, 1.5, 6.0), gargoyle.global_position + Vector3.UP * 0.7)
	await shot("25_slam_dust")
	# Turned to stone where it stood.
	gargoyle.alive = false
	await wait(1.0)
	_look_from(gargoyle.global_position + Vector3(3.5, 1.2, 5.0), gargoyle.global_position + Vector3.UP * 0.8)
	await shot("26_stone_again")
	stage.queue_free()
	await process_frame


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("GARGOYLE", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy = world.player
	boy.takes_input = false
	# (moved by hand here: his own physics would catch at vines)
	boy.process_mode = Node.PROCESS_MODE_DISABLED
	# (only this gargoyle: the round's own enemies are put away)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	var cell := _hall_cell(maze, nav)
	var g := MazeGargoyle.new()
	g.maze = maze
	g.seed_choices(5)
	g.position = maze.world(cell) + Vector3.UP * 0.05
	world.add_child(g)
	var away := func(metres: float) -> Vector3:
		var p: Vector3 = g.perch_foot + g.perch_out * metres
		if not maze.inside(maze.cell_at(p)) or not nav.allowed(maze.cell_at(p)):
			p = g.perch_foot + g.perch_out * 8.0
		return Vector3(p.x, maze.ground_height(p) + 0.1, p.z)
	await wait(0.3, func() -> bool: return g.perch_foot.is_finite())
	boy.global_position = away.call(60.0)
	await wait(1.0)
	camera = Camera3D.new()
	camera.fov = 55.0
	world.add_child(camera)
	camera.make_current()
	var along: Vector3 = g.perch_out.cross(Vector3.UP).normalized()
	var top: Vector3 = g.perch + Vector3.UP * 1.2
	# Perched over the hall: from down in it, as he sees it coming along.
	# (from down the hall, as far off as there is a clear view of it)
	var view := g.perch_foot + g.perch_out * 3.0 + Vector3.UP * 1.5
	var space := g.get_world_3d().direct_space_state
	for metres: float in [14.0, 11.0, -14.0, -11.0, 8.0, -8.0]:
		for out: float in [5.0, 3.0]:
			var p: Vector3 = g.perch_foot + g.perch_out * out + along * metres + Vector3.UP * 1.5
			if nav.allowed(maze.cell_at(p)) and nav.clear_of_walls(p, 1.0) and space.intersect_ray(PhysicsRayQueryParameters3D.create(p, top, 1, [g.get_rid()])).is_empty():
				view = p
				break
		if view != g.perch_foot + g.perch_out * 3.0 + Vector3.UP * 1.5:
			break
	_look_from(view, top)
	await shot("30_perched_over_the_hall")
	_look_from(g.perch_foot + g.perch_out * 3.0 + along * 3.0 + Vector3.UP * 1.4, top)
	await shot("31_perched_from_below")
	_look_from(top + g.perch_out * 4.0 + along * 2.5 + Vector3.UP * 0.5, top - Vector3.UP * 0.4)
	await shot("32_perched_close")
	# He walks in under it: it stirs, then drops.
	boy.global_position = Vector3(g.perch_foot.x, maze.ground_height(g.perch_foot) + 0.1, g.perch_foot.z) + along * 2.0
	await wait(3.0, func() -> bool: return g.mode == MazeGargoyle.Mode.STIR)
	await wait(0.8)
	_look_from(top + g.perch_out * 3.5 + along * 2.0, top - Vector3.UP * 0.3)
	await shot("33_stirs")
	_look_from(boy.global_position + g.perch_out * 6.0 - along * 4.0 + Vector3.UP * 1.6, g.perch + Vector3.UP * 0.5)
	await wait(3.0, func() -> bool: return g.mode == MazeGargoyle.Mode.DIVE)
	await wait(0.25)
	await shot("34_drop")
	# He runs on aside.
	var run := func() -> bool:
		var step: Vector3 = along * 4.4 / 60.0
		if nav.allowed(maze.cell_at(boy.global_position + along * 2.0)):
			boy.global_position += step
			boy.velocity = step * 60.0
		return g.mode != MazeGargoyle.Mode.DIVE or g._mode_time > g._flight * 0.6
	await wait(4.0, run)
	_look_from(g.landing + g.perch_out * 9.0 + along * 5.0 + Vector3.UP * 3.0, g.global_position.lerp(g.landing, 0.5))
	await shot("35_glide_and_shadow")
	await wait(4.0, func() -> bool: return g.mode == MazeGargoyle.Mode.STONE)
	await wait(0.15)
	_look_from(g.global_position + g.perch_out * 6.0 + along * 4.0 + Vector3.UP * 1.8, g.global_position + Vector3.UP * 0.8)
	await shot("36_landed_dust")
	await wait(1.2)
	_look_from(g.global_position + g.perch_out * 5.0 - along * 3.0 + Vector3.UP * 1.2, g.global_position + Vector3.UP * 0.8)
	await shot("37_stone_where_it_landed")
	# It hunts him down the hall.
	var far: Vector3 = g.global_position + along * 15.0
	if not nav.allowed(maze.cell_at(far)):
		far = g.global_position - along * 15.0
	boy.global_position = Vector3(far.x, maze.ground_height(far) + 0.1, far.z)
	boy.velocity = Vector3.ZERO
	g.notice(boy)
	await wait(5.0, func() -> bool: return g.mode == MazeGargoyle.Mode.HUNT)
	await wait(1.6)
	var toward: Vector3 = (boy.global_position - g.global_position).normalized()
	_look_from(boy.global_position - toward * 2.0 + Vector3.UP * 1.6 + toward.cross(Vector3.UP) * 1.5, g.global_position + Vector3.UP * 0.9)
	await shot("38_hunting")
	await wait(6.0, func() -> bool: return g.mode == MazeGargoyle.Mode.GATHER)
	await wait(0.5)
	_look_from(boy.global_position + Vector3.UP * 1.5 + toward.cross(Vector3.UP) * 2.0, g.global_position + Vector3.UP * 0.9)
	await shot("39_wind_up")
	await wait(2.0, func() -> bool: return g.mode == MazeGargoyle.Mode.LEAP and g._mode_time > 0.25)
	_look_from(boy.global_position + Vector3.UP * 1.2 + toward.cross(Vector3.UP) * 4.0 + toward * 2.0, g.global_position + Vector3.UP * 0.8)
	await shot("40_leap")
	# Back up to its ledge. (He is let alone, but stays near enough for it to be drawn.)
	boy.global_position = away.call(25.0)
	g._spared[boy] = 120.0
	g.quarry = null
	g._forget = 0.0
	g._last_seen = Vector3.INF
	await wait(20.0, func() -> bool: return g.mode == MazeGargoyle.Mode.CLIMB and g.global_position.y > g.perch_foot.y + 6.0)
	_look_from(g.perch_foot + g.perch_out * 10.0 + along * 6.0 + Vector3.UP * 4.0, g.global_position + Vector3.UP * 0.8)
	await shot("41_beating_up")
	await wait(0.2)
	_look_from(g.perch_foot + g.perch_out * 10.0 + along * 6.0 + Vector3.UP * 4.0, g.global_position + Vector3.UP * 0.8)
	await shot("42_beating_up_b")
	world.queue_free()
	await process_frame


func _hall_cell(maze: Maze, nav: MazeNav) -> Vector2i:
	var lairs := nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 3 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
				return cell
	return lairs[0]
