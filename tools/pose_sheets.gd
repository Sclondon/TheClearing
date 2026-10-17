extends SceneTree
## Not part of the game. A test stage: drives the Player through each thing he does and
## saves contact sheets of what the rig makes of it, to check a change without playing through it.
## godot --path . --fixed-fps 60 --resolution 960x960 --script tools/pose_sheets.gd -- <outdir> [scenario ...]

const CELL := 480
var out := ""
var only: Array = []
var stage: Node3D
var player: Player
var cam: Camera3D
var touch: TouchControls
var cells: Array[Image] = []
var view := Vector3(0.6, 0.12, 3.2)  # yaw round him (0 = from in front of +Z... see aim), pitch, distance
var look_h := 0.65
var pin := Vector3.INF
## The way the camera looks is measured from this instead of from the way he faces, if set.
var hold_yaw := NAN
## Every bone's place in the skeleton, frame by frame, since the last sheet: what
## a still picture cannot show (a joint that shakes) is found by `shake` in this.
var track: Array = []
var track_from := 0
var frame_number := 0
## A bone turning back on itself from one frame to the next by more than this each way, degrees, is shaking;
## and one whose turning changes by more than this in a frame has jumped.
const SHAKE := 1.5
const JUMP := 14.0


func _initialize() -> void:
	# It needs a real window to draw in, but not one that gets in the way: this one is kept
	# off the screen and takes no focus, and nothing typed or clicked reaches the Player.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-6000, -6000))
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	# ("lo" among the names: the demade model instead)
	if "lo" in only:
		only.erase("lo")
		Settings.low_poly = true
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
	box(Vector3(0, -1, 0), Vector3(80, 2, 80), Color(0.3, 0.32, 0.34))
	# A wall to hang from (top at 2.1), face at z = 4
	box(Vector3(0, 1.05, 7), Vector3(12, 2.1, 6), Color(0.42, 0.44, 0.47))
	# Towers to drop from: tops at 1.9, 3.2, 5.0 and 2.5, running off towards +x
	box(Vector3(-20, 1.25, -40), Vector3(6, 2.5, 4), Color(0.42, 0.44, 0.47))
	# Stairs, going up towards +x from x = 40
	for i in 8:
		box(Vector3(40 + i * 0.45, 0.05 + i * 0.05, 20), Vector3(0.45, 0.1 * (i + 1), 3.0), Color(0.42, 0.44, 0.47))
	box(Vector3(46.0, 0.4, 20), Vector3(5.0, 0.8, 3.0), Color(0.42, 0.44, 0.47))
	box(Vector3(-20, 0.95, -10), Vector3(6, 1.9, 4), Color(0.42, 0.44, 0.47))
	box(Vector3(-20, 1.6, -20), Vector3(6, 3.2, 4), Color(0.42, 0.44, 0.47))
	box(Vector3(-20, 2.5, -30), Vector3(6, 5.0, 4), Color(0.42, 0.44, 0.47))
	# A thin slab to hang from with no wall under it (top at 2.0), edge at x = 20
	box(Vector3(23, 1.85, 0), Vector3(6, 0.3, 4), Color(0.42, 0.44, 0.47))
	# A low bar to sneak under (underside at 0.95)
	box(Vector3(0, 1.55, -12), Vector3(3, 1.2, 6), Color(0.42, 0.44, 0.47))

	# A bar too low to sneak under (underside at 0.66), a ladder up a tower, and a tank of water
	box(Vector3(60, -1, 20), Vector3(40, 2, 80), Color(0.3, 0.32, 0.34))
	box(Vector3(60, 1.26, 0), Vector3(3, 1.2, 6), Color(0.42, 0.44, 0.47))
	box(Vector3(60, 1.5, 40), Vector3(3, 3.0, 3), Color(0.42, 0.44, 0.47))
	var ladder := Ladder.new()
	ladder.height = 3.0
	ladder.position = Vector3(58.44, 0, 40)
	ladder.rotation.y = -PI * 0.5
	stage.add_child(ladder)
	var pool := Pool.new()
	pool.size = Vector3(30, 3.0, 12)
	pool.position = Vector3(100, 3.0, 0)
	stage.add_child(pool)

	# A side to the tank to climb out onto (its top just above the water), and steps down into it
	box(Vector3(112, 1.58, 0), Vector3(6, 3.16, 12), Color(0.42, 0.44, 0.47))
	for i in 8:
		box(Vector3(86.0 + i * 0.4, 1.5 - i * 0.11, 0), Vector3(0.4, 3.0 - i * 0.22, 4.0), Color(0.42, 0.44, 0.47))
	# Steeper stairs, near the most he can step: up towards +x from x = 40, z = 30
	for i in 8:
		box(Vector3(40 + i * 0.3, 0.09 + i * 0.09, 30), Vector3(0.3, 0.18 * (i + 1), 3.0), Color(0.42, 0.44, 0.47))
	box(Vector3(44.9, 0.72, 30), Vector3(5.0, 1.44, 3.0), Color(0.42, 0.44, 0.47))
	# And things that are not stairs: a kerb, and a ramp
	box(Vector3(40, 0.06, 36), Vector3(2.0, 0.12, 3.0), Color(0.42, 0.44, 0.47))

	var line := Rope.new()
	line.length = 5.5
	line.position = Vector3(70, 6.6, 20)
	stage.add_child(line)

	touch = TouchControls.new()
	touch.visible = false
	stage.add_child(touch)
	touch.set_process_input(false)
	player = load("res://player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 0)
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	# (the newer moves, whatever the Player's own switches say)
	player.dive_enabled = true
	player.flip_enabled = true
	player.spin_enabled = true
	player.rest_enabled = true
	player.gun_handling = true
	player.sleep_after = 0.0
	# A ceiling high enough to stand under and too low to turn over under (underside at 1.6)
	box(Vector3(12, 2.1, -12), Vector3(3, 1.0, 3), Color(0.42, 0.44, 0.47))
	# A gamepad is heard whether the window has the focus or not, and someone may be
	# playing: his actions are left with nothing bound to them, and whatever is
	# held as this starts is let go. (The Player is driven through the touch controls.)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	cam = Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	cam.make_current()
	process_frame.connect(record)
	run.call_deferred()


func box(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	visual.material_override = material
	body.add_child(visual)
	body.position = at
	stage.add_child(body)


func aim() -> void:
	# view.x is measured from straight in front of him
	var yaw: float = (player.facing_yaw if is_nan(hold_yaw) else hold_yaw) + view.x
	var away := Vector3(sin(yaw) * cos(view.y), sin(view.y), cos(yaw) * cos(view.y))
	var watch: Vector3 = player.visual_position + Vector3.UP * look_h
	if pin != Vector3.INF:
		watch = pin
	cam.global_position = watch + away * view.z
	cam.look_at(watch)


func steer(world: Vector3) -> void:
	# The inverse of Player._to_world for the camera as it stands
	var basis := cam.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	touch.move = Vector2(world.dot(right), -world.dot(forward))


func frames(count: int, heading := Vector3.INF) -> void:
	for i in count:
		aim()
		if heading != Vector3.INF:
			steer(heading)
		await physics_frame
		await process_frame


func snap() -> void:
	aim()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var side: int = mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	cells.append(image)


## Notes where every bone is this frame.
func record() -> void:
	frame_number += 1
	if paused or player == null or player._rig == null or not is_instance_valid(player._rig._skeleton):
		return
	var skeleton: Skeleton3D = player._rig._skeleton
	var row: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		row.append(skeleton.get_bone_global_pose(bone))
	if track.is_empty():
		track_from = frame_number
	track.append(row)


## Marks a break in what `record` has noted: he has been put somewhere else.
func cut() -> void:
	track.append(null)


## Prints which bones shook or jumped since the last sheet, and how badly, and on which frame of it.
func shake(name: String) -> void:
	var skeleton: Skeleton3D = player._rig._skeleton
	var found: Array = []
	var since_cut := 0
	var turns: Array = []  # each bone's turn over the last frame, as an axis times degrees
	var steps: Array = []
	for i in track.size():
		if track[i] == null or (i > 0 and track[i - 1] != null and track[i].size() != track[i - 1].size()):
			since_cut = 0
			turns.clear()
			continue
		since_cut += 1
		# (the first frames after he is put down are him settling)
		if since_cut < 8 or track[i - 1] == null:
			turns.clear()
			continue
		var now: Array = []
		var moved: Array = []
		for bone in track[i].size():
			var q := Quaternion(track[i][bone].basis.orthonormalized()) * Quaternion(track[i - 1][bone].basis.orthonormalized()).inverse()
			var angle := q.get_angle()
			if angle > PI:
				angle -= TAU
			now.append(q.get_axis() * rad_to_deg(angle))
			moved.append(track[i][bone].origin - track[i - 1][bone].origin)
		if not turns.is_empty():
			if found.is_empty():
				for bone in now.size():
					found.append({"bone": skeleton.get_bone_name(bone), "shakes": 0, "worst": 0.0, "at": 0, "jump": 0.0, "jump_at": 0, "slips": 0, "slip": 0.0})
			for bone in mini(now.size(), found.size()):
				var a: Vector3 = turns[bone]
				var b: Vector3 = now[bone]
				var back := -a.dot(b) / maxf(a.length(), 0.0001)
				if a.dot(b) < 0.0 and minf(back, a.length()) > SHAKE:
					found[bone].shakes += 1
					if minf(back, a.length()) > found[bone].worst:
						found[bone].worst = minf(back, a.length())
						found[bone].at = i
				if (b - a).length() > found[bone].jump:
					found[bone].jump = (b - a).length()
					found[bone].jump_at = i
				var c: Vector3 = steps[bone]
				var d: Vector3 = moved[bone]
				if c.dot(d) < 0.0 and minf(c.length(), d.length()) > 0.006:
					found[bone].slips += 1
					found[bone].slip = maxf(found[bone].slip, minf(c.length(), d.length()))
		# (SHAKE_TRACE=<bone> in the environment prints that bone's turn on every frame, degrees about x, y and z)
		var traced := skeleton.find_bone(OS.get_environment("SHAKE_TRACE"))
		if traced >= 0 and traced < now.size():
			print("TRACE %s %d  %6.1f %6.1f %6.1f" % [name, i, now[traced].x, now[traced].y, now[traced].z])
		turns = now
		steps = moved
	var bad := found.filter(func(entry: Dictionary) -> bool: return entry.shakes >= 2 or entry.jump > JUMP or entry.slips >= 2)
	bad.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.shakes * 100 + a.jump > b.shakes * 100 + b.jump)
	print("SHAKE ", name, " frames=", track.size(), " from=", track_from, " bones=", bad.size())
	for entry: Dictionary in bad.slice(0, 14):
		print("  %-14s shakes=%d worst=%.1f at %d | jump=%.1f at %d | slips=%d %.3f" % [entry.bone, entry.shakes, entry.worst, entry.at, entry.jump, entry.jump_at, entry.slips, entry.slip])
	track.clear()


func sheet(name: String, columns := 3) -> void:
	shake(name)
	var rows := ceili(cells.size() / float(columns))
	var page := Image.create(CELL * columns, CELL * rows, false, cells[0].get_format())
	for i in cells.size():
		page.blit_rect(cells[i], Rect2i(0, 0, CELL, CELL), Vector2i((i % columns) * CELL, (i / columns) * CELL))
	page.save_png(out.path_join(name + ".png"))
	cells.clear()
	print("SHEET ", name)


func place(at: Vector3, yaw: float) -> void:
	cut()
	touch.move = Vector2.ZERO
	touch.duck_held = false
	touch.act_held = false
	touch.sprint_held = false
	touch.jump_held = false
	player.state = Player.State.FREE
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = yaw
	player._spawn = Transform3D(Basis.IDENTITY, at)
	player.respawn()
	player.facing_yaw = yaw
	player._reset_visuals()


func wants(name: String) -> bool:
	return only.is_empty() or name in only


## A strip of `count` pictures, one every `every` frames, steering `heading` if given.
func shots(name: String, count: int, every: int, heading := Vector3.INF, columns := 4) -> void:
	for i in count:
		await frames(every, heading)
		await snap()
	sheet(name, columns)


func run() -> void:
	# (again, now that everything has made its actions)
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
			Input.action_release(action)
	await frames(5)
	for name: String in ["turnaround", "idle", "walk", "sprint", "cap", "flatout", "turn", "sneak", "slide", "jump", "hang", "shimmy", "climb", "slab", "land1", "sprawl", "scramble", "land2", "land3", "land0", "throw", "stairs", "hatless", "crawl", "tired", "ladder", "swim", "bat", "rope", "grapple", "kick", "dive", "dive_edges", "flip", "spin", "sit", "sleep", "wade", "stairs_sprint", "roll"]:
		if wants(name):
			# (what he does by chance, he does the same way every time a sheet is drawn)
			seed(hash(name))
			await call(name)
	quit()


## Presses duck for a few frames.
func tap_duck(count := 3, heading := Vector3.INF) -> void:
	touch.duck_held = true
	await frames(count, heading)
	touch.duck_held = false
	touch.act_held = false


## Runs along +x, jumps, and presses duck `after` frames later.
func to_dive(at: Vector3, heading: Vector3, lead := 50, after := 6) -> void:
	place(at, atan2(heading.x, heading.z))
	await frames(lead, heading)
	touch.jump_held = true
	player._queue_jump()
	await frames(after, heading)
	touch.jump_held = false
	touch.duck_held = true
	await frames(1, heading)


func dive() -> void:
	for kind: Array in [["dive", Vector3(PI * 0.5, 0.05, 5.0)], ["dive_q", Vector3(0.75, 0.16, 5.0)]]:
		view = kind[1]
		look_h = 0.6
		await to_dive(Vector3(0, 0.05, 0), Vector3(1, 0, 0))
		var from: Vector3 = player.global_position
		for i in 36:
			if i == 2:
				touch.duck_held = false
			await frames(2, Vector3(1, 0, 0))
			await snap()
			if i % 4 == 0 and kind[0] == "dive":
				print("DIVE ", i, " diving=", player.is_diving, " roll=", player.dive_roll, " land=", snappedf(player.landing_progress, 0.01), " y=", snappedf(player.global_position.y, 0.01), " vel=", player.velocity, " h=", snappedf(player._capsule.height, 0.01), " duck=", player.is_ducking)
		print("DIVE went ", player.global_position - from, " state=", player.state)
		sheet(kind[0], 6)
	# Into water, off the side of the tank
	for kind: Array in [["dive_water", Vector3(PI * 0.5, 0.1, 8.5)], ["dive_water_q", Vector3(PI * 0.5 + 0.8, 0.25, 8.5)]]:
		view = kind[1]
		hold_yaw = -PI * 0.5
		pin = Vector3(108.3, 3.2, 0)
		await to_dive(Vector3(114.0, 3.21, 0), Vector3(-1, 0, 0), 46, 5)
		for i in 36:
			if i == 2:
				touch.duck_held = false
			await frames(2, Vector3(-1, 0, 0) if i < 12 else Vector3.INF)
			if i == 12:
				touch.move = Vector2.ZERO
			await snap()
			if i % 4 == 0 and kind[0] == "dive_water":
				print("DIVE WATER ", i, " state=", player.state, " diving=", player.is_diving, " in=", snappedf(player.dive_in, 0.01), " under=", player.is_underwater, " at=", player.global_position, " vel=", player.velocity)
		sheet(kind[0], 6)
		pin = Vector3.INF
		hold_yaw = NAN
	look_h = 0.65


func dive_edges() -> void:
	view = Vector3(PI * 0.5, 0.05, 5.0)
	# Duck held from before the jump: out of a run that is a slide, and the jump is refused
	place(Vector3(0, 0.05, 0), PI * 0.5)
	await frames(50, Vector3(1, 0, 0))
	touch.duck_held = true
	await frames(4, Vector3(1, 0, 0))
	var was: int = player.state
	player._queue_jump()
	await frames(12, Vector3(1, 0, 0))
	print("EDGE duck then jump out of a run: state before=", was, " diving=", player.is_diving, " flip=", player.flip_progress, " y=", player.global_position.y)
	touch.duck_held = false
	touch.act_held = false
	# Duck pressed too late
	await to_dive(Vector3(0, 0.05, 0), Vector3(1, 0, 0), 50, 22)
	await frames(3, Vector3(1, 0, 0))
	print("EDGE duck late (22 frames): diving=", player.is_diving)
	touch.duck_held = false
	touch.act_held = false
	# A standing jump
	place(Vector3(0, 0.05, 0), PI * 0.5)
	await frames(20)
	player._queue_jump()
	await frames(5)
	await tap_duck()
	print("EDGE standing jump: diving=", player.is_diving)
	# Under the low bar (underside at 0.95): he dives, lands short of it and rolls through
	await to_dive(Vector3(-9.4, 0.05, -12), Vector3(1, 0, 0), 60, 5)
	touch.duck_held = false
	touch.act_held = false
	view = Vector3(PI * 0.5, 0.0, 6.0)
	hold_yaw = PI * 0.5
	pin = Vector3(-1.0, 0.6, -12)
	for i in 24:
		await frames(3, Vector3(1, 0, 0))
		await snap()
		if i % 3 == 0:
			print("EDGE bar ", i, " x=", snappedf(player.global_position.x, 0.01), " y=", snappedf(player.global_position.y, 0.01), " diving=", player.is_diving, " land=", snappedf(player.landing_progress, 0.01), " h=", snappedf(player._capsule.height, 0.01), " duck=", player.is_ducking, " crawl=", player.is_crawling)
	sheet("dive_bar", 6)
	pin = Vector3.INF
	hold_yaw = NAN
	# At the wall: he catches the top of it
	await to_dive(Vector3(0, 0.05, -1.2), Vector3(0, 0, 1), 46, 5)
	touch.duck_held = false
	touch.act_held = false
	var caught := false
	for i in 60:
		await frames(1, Vector3(0, 0, 1))
		caught = caught or player.state == Player.State.HANG
	print("EDGE dive at a wall: state=", player.state, " caught=", caught, " diving=", player.is_diving, " at ", player.global_position, " h=", player._capsule.height)
	# Off a height (3.2 m): still a roll
	place(Vector3(-22.0, 3.25, -20), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.35, 0.1, 6.0)
	await frames(8)
	player.landed.connect(func(speed: float) -> void: print("EDGE dive off 3.2 m landed speed=", speed, " kind=", player.landing, " dive_roll=", player.dive_roll), CONNECT_ONE_SHOT)
	for i in 200:
		await frames(1, Vector3(1, 0, 0))
		if player.global_position.x > -17.4:
			break
	touch.jump_held = true
	player._queue_jump()
	await frames(5, Vector3(1, 0, 0))
	touch.jump_held = false
	await tap_duck(3, Vector3(1, 0, 0))
	print("EDGE off a height: diving=", player.is_diving)
	for i in 24:
		await frames(4, Vector3(1, 0, 0))
		await snap()
	sheet("dive_high", 6)


func to_crouch(at: Vector3, yaw: float) -> void:
	place(at, yaw)
	touch.duck_held = true
	await frames(40)


func flip() -> void:
	for kind: Array in [["flip", Vector3(PI * 0.5, 0.05, 6.2)], ["flip_q", Vector3(0.7, 0.15, 6.2)]]:
		await to_crouch(Vector3(0, 0.05, 0), PI * 0.5)
		view = kind[1]
		look_h = 0.9
		hold_yaw = PI * 0.5
		pin = Vector3(0, 1.35, 0)
		var from: Vector3 = player.global_position
		player._queue_jump()
		for i in 36:
			if i == 3:
				touch.duck_held = false
			await frames(2)
			await snap()
			if i % 4 == 0 and kind[0] == "flip":
				print("FLIP ", i, " at=", snappedf(player.flip_progress, 0.01), " y=", snappedf(player.global_position.y, 0.01), " floor=", player.is_on_floor(), " landing=", player.landing, "/", snappedf(player.landing_progress, 0.01))
		print("FLIP went ", player.global_position - from)
		sheet(kind[0], 6)
		# (and the look afterwards)
		for i in 6:
			await frames(12)
			await snap()
		sheet(kind[0] + "_after", 6)
	pin = Vector3.INF
	hold_yaw = NAN
	# Sneaking forward as he jumps
	await to_crouch(Vector3(0, 0.05, 0), PI * 0.5)
	await frames(40, Vector3(1, 0, 0))
	var start: Vector3 = player.global_position
	player._queue_jump()
	await frames(3, Vector3(1, 0, 0))
	print("FLIP sneaking: flip=", player.flip_progress, " vel=", player.velocity)
	touch.duck_held = false
	touch.act_held = false
	await frames(50, Vector3(1, 0, 0) if false else Vector3.INF)
	print("FLIP sneaking: went ", player.global_position - start)
	# Under what is too low to stand in: no jump. Under what is too low to turn over in: an ordinary jump.
	await to_crouch(Vector3(0, 0.05, -12), PI * 0.5)
	player._queue_jump()
	await frames(4)
	print("FLIP under a low bar: flip=", player.flip_progress, " vy=", player.velocity.y, " ducking=", player.is_ducking)
	await to_crouch(Vector3(12, 0.05, -12), PI * 0.5)
	player._queue_jump()
	await frames(4)
	print("FLIP under a 1.6 m ceiling: flip=", player.flip_progress, " vy=", player.velocity.y, " ducking=", player.is_ducking)
	touch.duck_held = false
	touch.act_held = false
	look_h = 0.65


## Turns the stick round at `rate` radians a second for `count` frames, from the angle it is at.
var stick_angle := 0.0
func whip(count: int, rate: float, reach := 1.0) -> void:
	for k in count:
		stick_angle += rate / 60.0
		aim()
		touch.move = Vector2(sin(stick_angle), cos(stick_angle)) * reach
		await physics_frame
		await process_frame


func spin() -> void:
	for kind: Array in [["spin", Vector3(0.0, 0.1, 4.2)], ["spin_q", Vector3(0.8, 0.3, 4.2)]]:
		place(Vector3(0, 0.05, 0), 0.0)
		view = kind[1]
		hold_yaw = 0.0
		look_h = 0.7
		await frames(30)
		for i in 36:
			if i < 22:
				await whip(3, 14.0)
			else:
				touch.move = Vector2.ZERO
				await frames(3)
			await snap()
			if i % 3 == 0 and kind[0] == "spin":
				print("SPIN ", i, " spinning=", player.is_spinning, " turned=", snappedf(player._spin_turned, 0.01), " dizzy=", snappedf(player.dizzy, 0.01), " stagger=", snappedf(player.stagger, 0.01), " yaw=", snappedf(player.facing_yaw, 0.01), " vel=", player.velocity)
		sheet(kind[0], 6)
	# Out of a run, along his path
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.5, 0.2, 6.0)
	hold_yaw = PI * 0.5
	await frames(50, Vector3(1, 0, 0))
	var from: Vector3 = player.global_position
	stick_angle = 0.0
	for i in 24:
		if i < 16:
			await whip(3, -15.0)
		else:
			touch.move = Vector2.ZERO
			await frames(3)
		await snap()
	print("SPIN out of a run: went ", player.global_position - from)
	sheet("spin_run", 6)
	# What must not set him off: running in a ring, a quick turn about, a wiggle
	place(Vector3(0, 0.05, 0), 0.0)
	var seen := false
	var most := 0.0
	for i in 240:
		await whip(1, 5.0)
		seen = seen or player.is_spinning
		most = maxf(most, absf(player._spin_turned))
	print("EDGE stick circled at 5 rad/s for 4 s: spun=", seen, " most turned=", most)
	seen = false
	most = 0.0
	for i in 240:
		await whip(1, 8.5)
		seen = seen or player.is_spinning
		most = maxf(most, absf(player._spin_turned))
	print("EDGE stick circled at 8.5 rad/s for 4 s: spun=", seen, " most turned=", most)
	place(Vector3(0, 0.05, 0), 0.0)
	seen = false
	for i in 12:
		await frames(12, Vector3(1 if i % 2 == 0 else -1, 0, 0))
		seen = seen or player.is_spinning
	print("EDGE thrown from side to side: spun=", seen)
	seen = false
	for i in 8:
		await frames(20, Vector3(0, 0, 1))
		await whip(9, 20.0)
		seen = seen or player.is_spinning
	print("EDGE half turns flicked (180 in 0.15 s, then held): spun=", seen)
	# Keys: eight directions, a new one every 5 frames (a turn in 0.67 s), and every 3
	for pace: int in [5, 3]:
		place(Vector3(0, 0.05, 0), 0.0)
		seen = false
		for i in 32:
			var a := i * PI * 0.25
			aim()
			for k in pace:
				touch.move = Vector2(roundf(sin(a)), roundf(cos(a))).normalized()
				await physics_frame
				await process_frame
			seen = seen or player.is_spinning
		print("EDGE keys round, one every ", pace, " frames: spun=", seen)
	# Kept at it until he is giddy
	place(Vector3(0, 0.05, 0), 0.0)
	view = Vector3(0.5, 0.2, 4.2)
	await frames(10)
	await whip(200, 14.0)
	print("SPIN long: dizzy=", player.dizzy, " spinning=", player.is_spinning)
	touch.move = Vector2.ZERO
	for i in 24:
		await frames(5)
		await snap()
	print("SPIN after: rest=", player.rest, " sit=", player.sit_progress, " dizzy=", player.dizzy)
	sheet("spin_giddy", 6)
	await frames(200)
	print("SPIN later: rest=", player.rest, " sit=", player.sit_progress)
	hold_yaw = NAN
	look_h = 0.65


func sit() -> void:
	for kind: Array in [["sit", Vector3(PI * 0.5, 0.05, 3.4)], ["sit_q", Vector3(0.7, 0.2, 3.4)]]:
		place(Vector3(0, 0.05, 0), PI * 0.5)
		view = kind[1]
		look_h = 0.45
		await frames(30)
		player.sit()
		for i in 24:
			await frames(3)
			await snap()
		sheet(kind[0], 6)
		await frames(40)
		player.stand_up()
		for i in 24:
			await frames(3)
			await snap()
		print("SIT up again: rest=", player.rest, " sit=", player.sit_progress, " h=", player._capsule.height)
		sheet(kind[0] + "_up", 6)
	# By holding duck, where he stands
	place(Vector3(0, 0.05, 0), PI * 0.5)
	touch.duck_held = true
	await frames(int(player.sit_hold * 60.0) + 20)
	print("SIT by holding duck: rest=", player.rest, " sit=", player.sit_progress)
	await frames(int((player.sit_hold + player.sit_time + player.lie_time) * 60.0) + 140)
	print("SIT duck still held: rest=", player.rest, " lie=", player.lie_progress)
	touch.duck_held = false
	touch.act_held = false
	touch.move = Vector2.ZERO
	await frames(30)
	print("SIT duck let go: rest=", player.rest, " (still asleep?)")
	player._queue_jump()
	await frames(260)
	print("SIT jump pressed: rest=", player.rest, " sit=", player.sit_progress, " y=", player.global_position.y)
	look_h = 0.65


func sleep() -> void:
	# Left alone: the yawn, sitting, lying down
	place(Vector3(0, 0.05, 0), PI * 0.5)
	player.sleep_after = 4.0
	view = Vector3(PI * 0.5 - 0.6, 0.15, 3.6)
	look_h = 0.6
	await frames(40)
	for i in 24:
		await frames(8)
		await snap()
	sheet("yawn", 6)
	print("SLEEP after the yawn: rest=", player.rest, " yawn=", player.yawn_progress, " idle=", player._idle_time)
	look_h = 0.4
	for kind: Array in [["lie", Vector3(PI * 0.5, 0.08, 3.4)], ["lie_q", Vector3(0.7, 0.3, 3.4)]]:
		place(Vector3(0, 0.05, 0), PI * 0.5)
		view = kind[1]
		await frames(20)
		player.sleep()
		await frames(int((player.sit_time + Player.SIT_PAUSE) * 60.0) - 6)
		for i in 36:
			await frames(3)
			await snap()
		sheet(kind[0], 6)
	print("SLEEP asleep: ", player.is_asleep(), " rest=", player.rest)
	# Asleep, from all round, and over a while (breathing, a twitch, a scratch)
	for yaw: float in [0.0, 0.8, PI * 0.5, PI - 0.6, PI, -PI * 0.5]:
		view = Vector3(yaw, 0.3, 2.6)
		await frames(3)
		await snap()
	sheet("asleep", 6)
	view = Vector3(0.5, 0.4, 2.4)
	for i in 24:
		await frames(40)
		await snap()
	sheet("asleep_long", 6)
	# Woken by the stick: sits up, rubs his eyes, gets up
	view = Vector3(0.7, 0.25, 3.4)
	touch.move = Vector2(1, 0)
	await frames(2)
	touch.move = Vector2.ZERO
	for i in 36:
		await frames(5)
		await snap()
	print("SLEEP woken: rest=", player.rest, " sit=", player.sit_progress, " lie=", player.lie_progress)
	sheet("wake", 6)
	# Woken with a start: something gives chase
	player.sleep()
	await frames(int((player.sit_time + Player.SIT_PAUSE + player.lie_time) * 60.0) + 60)
	print("SLEEP again: asleep=", player.is_asleep())
	var hunter := Hunter.new()
	hunter.position = Vector3(4, 0, 2)
	stage.add_child(hunter)
	hunter.add_to_group(&"pursuers")
	hunter.chasing = true
	for i in 24:
		await frames(3)
		await snap()
	print("SLEEP startled: rest=", player.rest, " sit=", player.sit_progress)
	sheet("wake_start", 6)
	hunter.queue_free()
	player.sleep_after = 0.0
	look_h = 0.65


class Hunter extends Node3D:
	var chasing := false


func wade() -> void:
	# Down the steps into the tank and out again (the steps run from x = 86, each 0.11 lower)
	for kind: Array in [["wade_in", 1.0, 86.3, Vector3(PI * 0.5, 0.08, 5.0)], ["wade_out", -1.0, 88.9, Vector3(PI * 0.5 + 0.5, 0.2, 5.0)]]:
		var way: float = kind[1]
		place(Vector3(kind[2], 3.2 if way > 0.0 else 1.9, 0), PI * 0.5 * way)
		view = kind[3]
		look_h = 0.7
		await frames(20)
		for i in 30:
			await frames(4, Vector3(way, 0, 0) * 0.5)
			await snap()
			if i % 5 == 0:
				print("WADE ", kind[0], " ", i, " x=", snappedf(player.global_position.x, 0.01), " y=", snappedf(player.global_position.y, 0.01), " wade=", snappedf(player.wade, 0.01), " state=", player.state)
		sheet(kind[0], 6)
	look_h = 0.65


func stairs_sprint() -> void:
	# Flat out down the shallow flight, and off a low drop: he must stay on the ground
	place(Vector3(48.2, 0.85, 20), -PI * 0.5)
	player.sprint_delay = 0.15
	view = Vector3(PI * 0.5, 0.06, 5.0)
	look_h = 0.6
	var airborne := 0
	var most := 0.0
	for i in 400:
		await frames(1, Vector3(-1, 0, 0))
		var x: float = player.global_position.x
		if x < 43.8 and x > 39.6:
			if not player.is_on_floor():
				airborne += 1
			most = maxf(most, player.air_time)
			if cells.size() < 24 and i % 2 == 0:
				await snap()
		if x < 38.5:
			break
	print("STAIRS sprinting down: sprinting=", player.is_sprinting, " frames off the floor=", airborne, " longest air time=", most)
	sheet("stairs_sprint", 6)
	player.sprint_delay = 0.8
	look_h = 0.65


func turnaround() -> void:
	place(Vector3(0, 0.05, 0), 0.0)
	await frames(50)
	look_h = 0.65
	for yaw: float in [0.0, 0.7, PI * 0.5, PI - 0.6, PI, -0.7]:
		view = Vector3(yaw, 0.08, 3.1)
		await frames(2)
		await snap()
	sheet("turnaround")
	# Close on the head and on a hand
	look_h = 1.1
	for yaw: float in [0.0, 0.8, PI * 0.5, PI]:
		view = Vector3(yaw, 0.1, 1.25)
		await frames(2)
		await snap()
	look_h = 0.5
	for yaw: float in [0.9, -0.9]:
		view = Vector3(yaw, 0.1, 1.25)
		await frames(2)
		await snap()
	sheet("closeups")
	look_h = 0.65


func idle() -> void:
	place(Vector3(0, 0.05, 0), 0.0)
	view = Vector3(0.5, 0.1, 3.1)
	for i in 6:
		await frames(75)
		await snap()
	sheet("idle")


func strip(name: String, heading: Vector3, lead: int, every: int, count: int, v: Vector3, scale := 1.0) -> void:
	place(Vector3(0, 0.05, 0), atan2(heading.x, heading.z))
	view = v
	await frames(lead, heading * scale)
	for i in count:
		await frames(every, heading * scale)
		await snap()
	sheet(name)


func walk() -> void:
	await strip("walk", Vector3(1, 0, 0), 60, 5, 6, Vector3(PI * 0.5, 0.05, 3.1), 0.5)


func sprint() -> void:
	# (sprint held, as the button or Shift would)
	await strip_sprinting("sprint", Vector3(1, 0, 0), 70, 3, 9, Vector3(PI * 0.5, 0.05, 3.6))
	await strip_sprinting("sprint_front", Vector3(1, 0, 0), 70, 4, 6, Vector3(0.5, 0.1, 3.6))
	await strip_sprinting("sprint_fine", Vector3(1, 0, 0), 70, 2, 12, Vector3(PI * 0.5, 0.05, 3.6))
	# Into it from a standstill, and pulled up out of it
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5, 0.05, 4.2)
	await frames(10)
	touch.sprint_held = true
	for i in 12:
		await frames(3, Vector3(1, 0, 0))
		await snap()
	sheet("sprint_start", 6)
	await frames(40, Vector3(1, 0, 0))
	touch.move = Vector2.ZERO
	touch.sprint_held = false
	for i in 18:
		await frames(2)
		await snap()
	sheet("sprint_stop", 6)


func strip_sprinting(name: String, heading: Vector3, lead: int, every: int, count: int, v: Vector3) -> void:
	place(Vector3(0, 0.05, 0), atan2(heading.x, heading.z))
	touch.sprint_held = true
	view = v
	await frames(lead, heading)
	for i in count:
		await frames(every, heading)
		await snap()
	touch.sprint_held = false
	sheet(name)


func sprint_old() -> void:
	await strip("sprint", Vector3(1, 0, 0), 70, 3, 9, Vector3(PI * 0.5, 0.05, 3.6))
	await strip("sprint_front", Vector3(1, 0, 0), 70, 4, 6, Vector3(0.5, 0.1, 3.6))


func cap() -> void:
	# How far the cap comes off his head, and tips, as he runs and lands
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5, 0.05, 3.6)
	var most := Vector2.ZERO
	for i in 200:
		await frames(1, Vector3(1, 0, 0))
		if i == 120:
			touch.jump_held = true
			player._queue_jump()
		var hat: Node3D = player._rig._cap
		most = most.max(Vector2((hat.position - player._rig._cap_rest).y, hat.rotation.length()))
		if i % 10 == 0:
			print("CAP ", i, " lift=", snappedf((hat.position - player._rig._cap_rest).y, 0.001), " tip=", snappedf(hat.rotation.x, 0.001), " held=", snappedf(player._rig._hat, 0.01))
	touch.jump_held = false
	print("CAP most lift=", most.x, " tip=", most.y)


func flatout() -> void:
	touch.sprint_held = true
	# Kept at a full run until he sprints, a hand on his cap
	await strip("flatout", Vector3(1, 0, 0), 150, 3, 9, Vector3(PI * 0.5, 0.05, 3.6))
	await strip("flatout_front", Vector3(1, 0, 0), 150, 4, 6, Vector3(0.6, 0.12, 3.2))
	await strip("flatout_back", Vector3(1, 0, 0), 150, 4, 6, Vector3(PI - 0.7, 0.2, 3.2))


func slide() -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5, 0.05, 3.4)
	look_h = 0.45
	await frames(60, Vector3(1, 0, 0))
	touch.duck_held = true
	for i in 9:
		await frames(4, Vector3(1, 0, 0))
		if i == 3:
			view = Vector3(0.7, 0.15, 3.2)
		if i == 6:
			view = Vector3(PI - 0.8, 0.2, 3.2)
		await snap()
	print("SLIDE head joint y=", player._rig._head.global_position.y, " state=", player.state)
	touch.duck_held = false
	touch.act_held = false
	sheet("slide")
	look_h = 0.65


func turn() -> void:
	# Running a tight circle: he should bank into it
	place(Vector3(0, 0.05, 0), 0.0)
	view = Vector3(0.0, 0.25, 4.2)
	var angle := 0.0
	for i in 150:
		angle += 1.9 / 60.0
		await frames(1, Vector3(sin(angle), 0, cos(angle)))
		if i > 60 and i % 15 == 0:
			view.x = 0.0 if (i / 15) % 2 == 0 else PI
			await snap()
	sheet("turn")


func sneak() -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5, 0.05, 3.1)
	touch.duck_held = true
	await frames(40)
	await snap()
	view = Vector3(0.6, 0.1, 3.1)
	await frames(2)
	await snap()
	view = Vector3(PI * 0.5, 0.05, 3.1)
	for i in 7:
		await frames(9, Vector3(1, 0, 0))
		if i == 3:
			view = Vector3(0.6, 0.1, 3.1)
		await snap()
	var head: Vector3 = player._rig._head.global_position
	print("SNEAK head joint y=", head.y, " collider=", player._capsule.height)
	sheet("sneak")
	# Close, from all round, to look for one part of him going through another
	look_h = 0.4
	await frames(40)
	for yaw: float in [0.0, 0.9, PI * 0.5, PI - 0.6, -PI * 0.5, -0.9]:
		view = Vector3(yaw, 0.2, 1.9)
		await frames(2)
		await snap()
	sheet("sneak_close")
	look_h = 0.65
	touch.duck_held = false
	touch.act_held = false


func jump() -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.5, 0.08, 4.4)
	look_h = 0.9
	await frames(50, Vector3(1, 0, 0))
	touch.jump_held = true
	player._queue_jump()
	for i in 9:
		await frames(5, Vector3(1, 0, 0))
		await snap()
	touch.jump_held = false
	sheet("jump")
	# Standing jump
	place(Vector3(0, 0.05, 0), 0.0)
	view = Vector3(0.6, 0.08, 4.4)
	await frames(30)
	touch.jump_held = true
	player._queue_jump()
	for i in 6:
		await frames(7)
		await snap()
	touch.jump_held = false
	sheet("jump_standing")
	# The same, every other frame, to see his arms move: running and standing,
	# from the side and from three quarters; and a short hop
	for kind: Array in [["jump_run_fine", true, Vector3(PI * 0.5, 0.05, 4.6), 30], ["jump_run_fine_q", true, Vector3(0.7, 0.15, 4.6), 30], ["jump_stand_fine", false, Vector3(PI * 0.5, 0.05, 4.4), 30], ["jump_stand_fine_q", false, Vector3(0.7, 0.15, 4.4), 30], ["jump_hop_fine", true, Vector3(PI * 0.5 - 0.5, 0.08, 4.4), 4]]:
		place(Vector3(0, 0.05, 0), PI * 0.5)
		view = kind[2]
		var heading: Vector3 = Vector3(1, 0, 0) if kind[1] else Vector3.INF
		await frames(53, heading)
		touch.jump_held = true
		player._queue_jump()
		for i in 30:
			if i * 2 >= kind[3]:
				touch.jump_held = false
			await frames(2, heading)
			await snap()
		touch.jump_held = false
		sheet(kind[0], 6)
	# Close on the knee he brings up, from the side, in front and behind, to
	# see what the bend does to his breeches
	for yaw: float in [PI * 0.5, 0.7, PI - 0.7]:
		place(Vector3(0, 0.05, 0), PI * 0.5)
		view = Vector3(yaw, 0.1, 2.0)
		look_h = 0.55
		await frames(53, Vector3(1, 0, 0))
		touch.jump_held = true
		player._queue_jump()
		for i in 4:
			await frames(4, Vector3(1, 0, 0))
			await snap()
		touch.jump_held = false
	sheet("jump_close", 4)
	# And stopped at the top of it, from all round
	place(Vector3(0, 0.05, 0), PI * 0.5)
	await frames(53, Vector3(1, 0, 0))
	touch.jump_held = true
	player._queue_jump()
	await frames(14, Vector3(1, 0, 0))
	touch.jump_held = false
	paused = true
	for yaw: float in [0.0, 0.5, 1.0, PI * 0.5, 2.2, PI, -2.2, -1.0]:
		view = Vector3(yaw, 0.25, 1.5)
		await snap()
	paused = false
	sheet("jump_round", 4)
	look_h = 0.65


func to_hang(at: Vector3, heading: Vector3) -> void:
	place(at, atan2(heading.x, heading.z))
	await frames(10)
	touch.jump_held = true
	player._queue_jump()
	for i in 80:
		await frames(1, heading)
		if player.state == Player.State.HANG:
			break
	touch.jump_held = false
	touch.move = Vector2.ZERO
	print("HANG state=", player.state, " at ", player.global_position)


func hang() -> void:
	await to_hang(Vector3(0, 0.05, 3.2), Vector3(0, 0, 1))
	await frames(40)
	pin = Vector3(0, 1.5, 3.9)
	for v: Vector3 in [Vector3(PI * 0.5, 0.05, 3.6), Vector3(PI - 0.7, 0.25, 3.6), Vector3(PI + 0.8, 0.1, 3.6)]:
		view = v
		await frames(2)
		await snap()
	pin = Vector3(0, 2.05, 3.95)
	for v: Vector3 in [Vector3(PI * 0.5, 0.1, 1.5), Vector3(PI - 0.6, 0.5, 1.5), Vector3(0.5, 0.5, 1.6)]:
		view = v
		await frames(2)
		await snap()
	pin = Vector3.INF
	sheet("hang")


func shimmy() -> void:
	await to_hang(Vector3(0, 0.05, 3.2), Vector3(0, 0, 1))
	look_h = 0.9
	view = Vector3(PI - 0.5, 0.3, 3.6)
	await frames(30)
	var from: Vector3 = player.global_position
	for i in 9:
		await frames(8, Vector3(1, 0, 0))
		await snap()
	print("SHIMMY moved ", player.global_position - from, " state=", player.state)
	sheet("shimmy")
	look_h = 0.65


func climb() -> void:
	await to_hang(Vector3(0, 0.05, 3.2), Vector3(0, 0, 1))
	await frames(30)
	pin = Vector3(0, 1.9, 3.95)
	player._queue_jump()
	for i in 16:
		view = Vector3(PI * 0.5, 0.05, 4.2)
		await frames(5)
		await snap()
	print("CLIMB end state=", player.state, " at ", player.global_position)
	sheet("climb", 4)
	await to_hang(Vector3(0, 0.05, 3.2), Vector3(0, 0, 1))
	await frames(30)
	player._queue_jump()
	for i in 16:
		view = Vector3(PI - 0.75, 0.35, 4.2)
		await frames(5)
		await snap()
	sheet("climb_back", 4)
	pin = Vector3.INF


func slab() -> void:
	await to_hang(Vector3(19.2, 0.05, 0), Vector3(1, 0, 0))
	look_h = 0.9
	await frames(40)
	for v: Vector3 in [Vector3(PI * 0.5, 0.05, 3.4), Vector3(PI - 0.7, 0.25, 3.4), Vector3(PI + 0.8, 0.1, 3.4)]:
		view = v
		await frames(2)
		await snap()
	sheet("slab")
	look_h = 0.65


func drop(name: String, z: float, top: float, running: bool, every := 5, count := 16) -> void:
	place(Vector3(-18.5, top + 0.05, z), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.35, 0.1, 5.0)
	look_h = 0.7
	var heading := Vector3(1, 0, 0)
	var landed := false
	var shots := 0
	var since := 0
	await frames(8)
	player.landed.connect(func(speed: float) -> void: print("LANDED ", name, " speed=", speed, " kind=", player.landing), CONNECT_ONE_SHOT)
	for i in 400:
		await frames(1, heading * (1.0 if running else 0.5) if running or not landed else Vector3.INF)
		if landed and not running:
			touch.move = Vector2.ZERO
		if not landed and player.is_on_floor() and player.global_position.y < 0.3:
			landed = true
		if landed:
			if since % every == 0:
				await snap()
				shots += 1
			since += 1
			if shots >= count:
				break
	print("AFTER ", name, " at ", player.global_position, " vel ", player.velocity)
	sheet(name, 4)
	look_h = 0.65


func land0() -> void:
	# An ordinary jump on the flat
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.35, 0.1, 4.4)
	await frames(40, Vector3(1, 0, 0))
	touch.jump_held = true
	player._queue_jump()
	await frames(30, Vector3(1, 0, 0))
	for i in 8:
		await frames(4, Vector3(1, 0, 0))
		await snap()
	touch.jump_held = false
	sheet("land0", 4)


func land1() -> void:
	await drop("land1", -10, 1.9, true)
	# And walking off it, to see the pose held: from three sides
	place(Vector3(-18.5, 1.95, -10), PI * 0.5)
	look_h = 0.5
	await frames(8)
	for i in 200:
		await frames(1, Vector3(1, 0, 0) * 0.5 if not player.is_on_floor() or player.global_position.y > 0.3 else Vector3.INF)
		if player.is_on_floor() and player.global_position.y < 0.3:
			touch.move = Vector2.ZERO
			break
	await frames(12)
	for v: Vector3 in [Vector3(PI * 0.5, 0.08, 3.0), Vector3(0.5, 0.15, 3.0), Vector3(-0.9, 0.15, 3.0)]:
		view = v
		await frames(1)
		await snap()
	sheet("land1_pose")
	look_h = 0.65


func land2() -> void:
	await drop("land2", -20, 3.2, true)


func land3() -> void:
	await drop("land3", -30, 5.0, true)


## Where his legs are this frame, for a roll: how high each knee, ankle and toe
## is off the ground (negative is through it), how far each knee and ankle is
## from the middle of his chest and from his head, how far each knee is folded,
## and how far apart his ankles are across his hips (negative is crossed).
func legs(tag: String, floor_y := 0.0) -> void:
	var rig: Node3D = player._rig
	var skeleton: Skeleton3D = rig._skeleton
	var line := "LEGS %s ball=%.2f spin=%4.0f" % [tag, rig._ball, rad_to_deg(rig._hips.rotation.x)]
	var chest: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("chest")).origin
	var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
	var hips: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hips"))
	var ankles: Array[Vector3] = []
	for suffix: String in ["_l", "_r"]:
		var knee: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("shin" + suffix)).origin
		var foot: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("foot" + suffix)).origin
		var toe: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("toe" + suffix)).origin
		var thigh: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("thigh" + suffix)).origin
		ankles.append(foot)
		var fold := rad_to_deg((knee - thigh).angle_to(foot - knee))
		line += " | %s knee y=%.2f chest=%.2f head=%.2f fold=%3.0f ankle y=%.2f chest=%.2f head=%.2f toe y=%.2f" % [suffix, knee.y - floor_y, knee.distance_to(chest), knee.distance_to(head), fold, foot.y - floor_y, foot.distance_to(chest), foot.distance_to(head), toe.y - floor_y]
	line += " | apart=%.2f" % (ankles[0] - ankles[1]).dot(hips.basis.x.normalized())
	if OS.get_environment("LEGS_WHERE") != "":
		var to_hips := hips.affine_inverse()
		line += " | in hips: head %.2v chest %.2v knees %.2v %.2v" % [to_hips * head, to_hips * chest, to_hips * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("shin_l")).origin), to_hips * (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("shin_r")).origin)]
	print(line)


## The two rolls from close to, every other frame, from the side and from three
## quarters in front: off the high tower, and out of a dive. Prints where his
## legs are on every frame of each (see `legs`).
func roll() -> void:
	track.clear()
	for kind: Array in [["roll_land", Vector3(PI * 0.5, 0.06, 2.7), true], ["roll_land_q", Vector3(0.75, 0.2, 2.7), false]]:
		place(Vector3(-18.5, 5.05, -30), PI * 0.5)
		view = kind[1]
		look_h = 0.4
		await frames(8)
		for i in 400:
			await frames(1, Vector3(1, 0, 0))
			if player.is_on_floor() and player.global_position.y < 0.3:
				break
		for i in 60:
			if i % 2 == 0:
				await snap()
			if kind[2]:
				legs("land %d" % i)
			await frames(1, Vector3(1, 0, 0))
		sheet(kind[0], 6)
	for kind: Array in [["roll_dive", Vector3(PI * 0.5, 0.06, 2.7), true], ["roll_dive_q", Vector3(0.75, 0.2, 2.7), false]]:
		view = kind[1]
		look_h = 0.4
		await to_dive(Vector3(0, 0.05, 0), Vector3(1, 0, 0))
		await frames(2, Vector3(1, 0, 0))
		touch.duck_held = false
		await frames(22, Vector3(1, 0, 0))
		for i in 60:
			if i % 2 == 0:
				await snap()
			if kind[2]:
				legs("dive %d" % i)
			await frames(1, Vector3(1, 0, 0))
		sheet(kind[0], 6)
	look_h = 0.65


func sprawl() -> void:
	# Walking off, and letting go as he lands: flat on his front, and a push up off it
	await drop("sprawl", -40, 2.5, false, 6, 20)


func scramble() -> void:
	# Kept running: he scrambles up off his hands
	await drop("scramble", -40, 2.5, true, 4, 20)


func throw() -> void:
	for round in 2:
		place(Vector3(0, 0.05, 0), PI * 0.5)
		var rock := RigidBody3D.new()
		rock.add_to_group(&"throwable")
		var shape := SphereShape3D.new()
		shape.radius = 0.12
		var collider := CollisionShape3D.new()
		collider.shape = shape
		rock.add_child(collider)
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		rock.add_child(visual)
		rock.position = Vector3(0.42, 0.13, 0.05)
		stage.add_child(rock)
		view = Vector3(PI * 0.5 - 0.5, 0.1, 3.6) if round == 0 else Vector3(-0.5, 0.15, 3.6)
		await frames(25)
		player._act()
		for i in 8:
			await frames(5)
			await snap()
		sheet("pickup" if round == 0 else "pickup_front", 4)
		await frames(20)
		player._act()
		for i in 16:
			await frames(4)
			await snap()
		print("THROW rock at ", rock.global_position, " vel ", rock.linear_velocity)
		sheet("throw" if round == 0 else "throw_front", 4)
		rock.queue_free()


func stairs() -> void:
	# How fast he gets up them, against how fast he runs
	place(Vector3(36, 0.05, 20), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.4, 0.15, 5.0)
	var last := player.visual_position
	var fastest := 0.0
	var slowest := 99.0
	var jerk := 0.0
	var was := 0.0
	var from := 0
	for i in 200:
		await frames(1, Vector3(1, 0, 0))
		var now := player.visual_position
		var speed := (now.x - last.x) * 60.0
		if now.x > 40.0 and now.x < 43.4:
			if from == 0:
				from = i
			fastest = maxf(fastest, speed)
			slowest = minf(slowest, speed)
			jerk = maxf(jerk, absf(speed - was))
			if (i - from) % 6 == 0 and cells.size() < 9:
				await snap()
		elif from > 0 and now.x >= 43.4:
			print("STAIRS 3.4 m in ", (i - from) / 60.0, " s: mean ", 3.4 / ((i - from) / 60.0), " m/s, seen fastest ", fastest, " slowest ", slowest, " biggest change ", jerk, " (runs at ", player.run_speed, ", sprints at ", player.sprint_speed, ")")
			break
		was = speed
		last = now
	if not cells.is_empty():
		sheet("stairs")
	# Up and down each flight, at a walk and at a run, from the side and from three quarters
	for steep in 2:
		var z := 20.0 if steep == 0 else 30.0
		var far := 43.6 if steep == 0 else 42.4
		var top := 0.8 if steep == 0 else 1.44
		for pace: Array in [["walk", 0.5, 3], ["run", 1.0, 2]]:
			for angle: Array in [["", Vector3(PI * 0.5, 0.06, 4.6)], ["_q", Vector3(PI * 0.5 - 0.7, 0.25, 4.6)]]:
				for up in 2:
					var name: String = "stairs%s_%s_%s%s" % ["_steep" if steep == 1 else "", "up" if up == 1 else "down", pace[0], angle[0]]
					await flight(name, z, 40.0, far, top, up == 1, pace[1], pace[2], angle[1])
	# What is not stairs: a kerb (one riser)
	place(Vector3(37.5, 0.05, 36), PI * 0.5)
	view = Vector3(PI * 0.5, 0.06, 4.0)
	var seen := 0.0
	for i in 150:
		await frames(1, Vector3(1, 0, 0) * 0.5)
		seen = maxf(seen, player.on_stairs)
	print("STAIRS a kerb counted as stairs: ", seen)


## A strip of him going up or down a flight that runs from x = `near` to `far`, its top `top` high.
func flight(name: String, z: float, near: float, far: float, top: float, up: bool, scale: float, every: int, v: Vector3) -> void:
	var back := 1.2 if scale < 1.0 else 3.2
	if up:
		place(Vector3(near - back, 0.05, z), PI * 0.5)
	else:
		place(Vector3(far + back, top + 0.05, z), -PI * 0.5)
	view = v
	look_h = 0.6
	var heading := Vector3(1 if up else -1, 0, 0) * scale
	for i in 300:
		await frames(1, heading)
		if (up and player.global_position.x > near - 0.5) or (not up and player.global_position.x < far + 0.5):
			break
	var stairs_seen := 0.0
	for i in 25:
		await frames(every, heading)
		stairs_seen = maxf(stairs_seen, player.on_stairs)
		await snap()
	print("FLIGHT ", name, " on_stairs seen=", stairs_seen, " rise=", snappedf(player.stair_rise, 0.001), " run=", snappedf(player.stair_run, 0.001), " ended at ", player.global_position)
	sheet(name, 5)
	look_h = 0.65


func hatless() -> void:
	Settings.cap = false
	Settings.colours = {"shirt": Color(0.75, 0.3, 0.25), "overalls": Color(0.3, 0.4, 0.3)}
	player._rig.restyle()
	place(Vector3(0, 0.05, 0), 0.0)
	await frames(90)
	look_h = 1.05
	for yaw: float in [0.0, 0.8, PI * 0.5, PI]:
		view = Vector3(yaw, 0.15, 1.5)
		await frames(2)
		await snap()
	look_h = 0.65
	for yaw: float in [0.4, PI - 0.5]:
		view = Vector3(yaw, 0.1, 3.1)
		await frames(2)
		await snap()
	sheet("hatless")
	# And the other cut, with his cap on
	Settings.cap = true
	Settings.hair = "long"
	player._rig.restyle()
	look_h = 1.05
	for yaw: float in [0.6, PI * 0.5, PI]:
		view = Vector3(yaw, 0.15, 1.5)
		await frames(2)
		await snap()
	sheet("hair_long")
	look_h = 0.65
	Settings.hair = "mullet"
	Settings.cap = true
	Settings.colours = {}
	player._rig.restyle()


func crawl() -> void:
	place(Vector3(57.6, 0.05, 0), PI * 0.5)
	# (from the side and level with him, to see in under the bar)
	view = Vector3(PI * 0.5, 0.0, 3.6)
	look_h = 0.3
	touch.duck_held = true
	await frames(30)
	for i in 16:
		await frames(6, Vector3(1, 0, 0))
		await snap()
	print("CRAWL at ", player.global_position, " crawling=", player.is_crawling, " collider=", player._capsule.height)
	sheet("crawl", 4)
	# And out the far side, from in front
	view = Vector3(0.5, 0.12, 3.0)
	for i in 300:
		await frames(1, Vector3(1, 0, 0))
		if player.global_position.x > 61.0:
			break
	await shots("crawl_out", 12, 6, Vector3(1, 0, 0), 4)
	touch.duck_held = false
	touch.act_held = false
	look_h = 0.65


func tired() -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.5, 0.1, 3.3)
	await frames(330, Vector3(1, 0, 0))
	touch.move = Vector2.ZERO
	for i in 6:
		await frames(25)
		if i == 3:
			view = Vector3(0.4, 0.12, 3.0)
		await snap()
	print("TIRED winded=", player._rig._winded, " tired=", player._rig._tired)
	sheet("tired")


func climb_ladder(count: int, way := -1.0) -> void:
	# (up the screen is up the ladder)
	for k in count:
		aim()
		touch.move = Vector2(0, way)
		await physics_frame
		await process_frame
	touch.move = Vector2.ZERO


func ladder() -> void:
	place(Vector3(57.0, 0.05, 40), PI * 0.5)
	view = Vector3(PI - 0.9, 0.15, 4.0)
	look_h = 0.8
	await frames(40, Vector3(1, 0, 0))
	print("LADDER state=", player.state, " at ", player.global_position)
	for i in 12:
		await climb_ladder(5)
		if i == 6:
			view = Vector3(PI * 0.5, 0.05, 4.0)
		await snap()
	sheet("ladder", 4)
	# Left alone on it
	view = Vector3(PI - 0.9, 0.15, 4.0)
	for i in 4:
		await frames(22)
		if i == 2:
			view = Vector3(PI * 0.5 + 0.5, 0.1, 4.0)
		await snap()
	sheet("ladder_rest", 4)
	# Over the top
	view = Vector3(PI - 0.9, 0.3, 4.4)
	for i in 400:
		await climb_ladder(1)
		if player.ladder_off > 0.0:
			break
	for i in 16:
		if i == 8:
			view = Vector3(PI * 0.5, 0.05, 4.4)
		await snap()
		await climb_ladder(3) if player.state == Player.State.LADDER else await frames(3)
	print("LADDER end state=", player.state, " at ", player.global_position)
	sheet("ladder_top", 4)
	# And back onto it from the top, and down
	await frames(20)
	view = Vector3(-0.9, 0.3, 4.4)
	for i in 16:
		if player.state == Player.State.LADDER:
			await climb_ladder(4, 1.0)
		else:
			await frames(4, Vector3(-1, 0, 0) * 0.5)
		await snap()
	print("LADDER from the top: state=", player.state, " at ", player.global_position)
	sheet("ladder_down", 4)
	look_h = 0.65


func swim() -> void:
	for kind: Array in [["swim_tread", 0.0, false], ["swim_breast", 0.5, false], ["swim_crawl", 1.0, false], ["swim_frog", 0.5, true], ["swim_flutter", 1.0, true]]:
		place(Vector3(90, 1.6, 0), PI * 0.5)
		view = Vector3(PI * 0.5 - 0.35, 0.3, 4.0)
		look_h = 0.9
		touch.duck_held = kind[2]
		await frames(50, Vector3(1, 0, 0) * kind[1] if kind[1] > 0.0 else Vector3.INF)
		touch.duck_held = false
		if kind[2]:
			# (held under, or he floats up)
			player.global_position.y = 0.6
		for i in 6:
			for k in 7:
				if kind[2]:
					player.velocity.y = 0.0
					player.global_position.y = 0.6
				await frames(1, Vector3(1, 0, 0) * kind[1] if kind[1] > 0.0 else Vector3.INF)
			await snap()
		print("SWIM ", kind[0], " state=", player.state, " under=", player.is_underwater, " at ", player.global_position, " vel ", player.velocity)
		sheet(kind[0])
		# The same again, from the side and closer together, to see it move
		view = Vector3(PI * 0.5, 0.04, 3.4)
		for i in 12:
			for k in 4:
				if kind[2]:
					player.velocity.y = 0.0
					player.global_position.y = 0.6
				await frames(1, Vector3(1, 0, 0) * kind[1] if kind[1] > 0.0 else Vector3.INF)
			await snap()
		sheet(kind[0] + "_side", 4)
	# From one stroke to the next: treading water, breast stroke, crawl, and stopping
	place(Vector3(90, 1.6, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.3, 0.2, 4.0)
	await frames(50)
	for i in 24:
		await frames(5, Vector3.INF if i < 2 or i > 19 else Vector3(1, 0, 0) * (0.5 if i < 9 else 1.0))
		if i > 19:
			touch.move = Vector2.ZERO
		await snap()
	sheet("swim_changes", 6)
	# Going in off a height, and coming up
	place(Vector3(95, 5.2, 0), PI * 0.5)
	view = Vector3(PI * 0.5 - 0.3, 0.12, 5.0)
	pin = Vector3(95.3, 2.3, 0)
	await frames(2)
	player.velocity.x = 1.0
	touch.move = Vector2.ZERO
	await frames(14)
	await shots("swim_in", 30, 5, Vector3.INF, 6)
	pin = Vector3.INF
	# Diving from the surface, and up again
	view = Vector3(PI * 0.5, 0.04, 4.4)
	touch.duck_held = true
	await shots("swim_dive", 8, 5, Vector3(1, 0, 0), 4)
	touch.duck_held = false
	touch.act_held = false
	touch.jump_held = true
	await shots("swim_rise", 12, 5, Vector3(1, 0, 0), 4)
	touch.jump_held = false
	# Out onto the side: swum up to, jumped at and caught, climbed, and shaken off
	place(Vector3(107.0, 1.6, 0), PI * 0.5)
	view = Vector3(PI * 0.5 + 0.7, 0.25, 4.6)
	await frames(40)
	for i in 12:
		await frames(6, Vector3(1, 0, 0))
		await snap()
	print("SWIM at the side: state=", player.state, " at ", player.global_position, " clear=", player.swim_clear)
	touch.jump_held = true
	player._queue_jump()
	for i in 6:
		await frames(4, Vector3(1, 0, 0))
		await snap()
	touch.jump_held = false
	print("SWIM caught the side: state=", player.state, " at ", player.global_position)
	player._queue_jump()
	for i in 10:
		await frames(7)
		await snap()
	touch.move = Vector2.ZERO
	sheet("swim_out", 6)
	await shots("swim_shake", 12, 4, Vector3.INF, 6)
	print("SWIM out: state=", player.state, " at ", player.global_position)
	# And walked out of, up steps
	place(Vector3(91, 1.6, 0), -PI * 0.5)
	view = Vector3(PI * 0.5 + 0.4, 0.2, 5.0)
	await frames(30)
	await shots("swim_steps", 36, 6, Vector3(-1, 0, 0) * 0.5, 6)
	print("SWIM up the steps: state=", player.state, " at ", player.global_position)
	look_h = 0.65


func bat() -> void:
	place(Vector3(0, 0.05, 0), PI * 0.5)
	var club := RigidBody3D.new()
	club.add_to_group(&"throwable")
	club.add_to_group(&"bats")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.035
	shape.height = 0.75
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.375
	club.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.036
	mesh.bottom_radius = 0.017
	mesh.height = 0.75
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position.y = 0.375
	club.add_child(visual)
	club.position = Vector3(0.4, 0.1, 0.0)
	club.rotation.z = PI * 0.5
	club.freeze = true
	stage.add_child(club)
	view = Vector3(0.5, 0.12, 3.6)
	await frames(40)
	player._act()
	await frames(90)
	await snap()
	view = Vector3(PI * 0.5 - 0.4, 0.12, 3.6)
	await frames(2)
	await snap()
	view = Vector3(0.5, 0.12, 3.6)
	player._act()
	for i in 10:
		await frames(4)
		await snap()
	sheet("bat", 4)
	# The swing again, every other frame, from in front and from the side
	for yaw: float in [0.5, PI * 0.5 - 0.2]:
		view = Vector3(yaw, 0.12, 3.4)
		await frames(50)
		player._act()
		for i in 12:
			await frames(3)
			await snap()
	sheet("bat_fine", 6)
	club.queue_free()


## How far round from straight down the rope he is on has swung, degrees, positive towards +x.
func rope_angle() -> float:
	if not is_instance_valid(player._rope):
		return 0.0
	var hold: Vector3 = player._rope.point_at(player._rope_at) - player._rope.global_position
	return rad_to_deg(atan2(hold.x, -hold.y))


## On a rope, pumps in time with the swing for `count` frames (or leaves it alone),
## taking a picture every `every`. Returns how far it got each half swing, degrees.
func pump(count: int, every: int, in_time := true) -> Array:
	var peaks: Array = []
	var widest := 0.0
	var side := 0.0
	for i in count:
		var way: float = signf(player.velocity.x) if absf(player.velocity.x) > 0.2 else 1.0
		await frames(1, Vector3(way, 0, 0) if in_time else Vector3.ZERO)
		var a := rope_angle()
		if signf(a) != side and absf(a) > 0.5:
			if side != 0.0:
				peaks.append(snappedf(widest, 0.1))
			side = signf(a)
			widest = 0.0
		widest = maxf(widest, absf(a))
		if every > 0 and i % every == every - 1:
			await snap()
	return peaks


func rope() -> void:
	# Run at it and jump: he catches it at arm's length and it takes his run as its first swing
	place(Vector3(67.0, 0.05, 20.3), PI * 0.5)
	hold_yaw = PI * 0.5
	view = Vector3(PI * 0.5 - 0.2, 0.1, 6.5)
	pin = Vector3(70, 3.0, 20)
	await frames(5)
	var jumped := 0
	for i in 120:
		if jumped == 0 and player.global_position.x > 68.75:
			jumped = i
			touch.jump_held = true
			player._queue_jump()
		await frames(1, Vector3(1, 0, 0))
		if player.state == Player.State.ROPE:
			print("ROPE caught %.2f s after jumping, %.2f m down it, passing %.2f m to the side" % [(i - jumped) / 60.0, player._rope_at, 0.3])
			break
	touch.jump_held = false
	print("ROPE state=", player.state, " at ", player.global_position)
	# Left alone, the swing his run gave it; then pumped in time with it
	print("ROPE the swing his run-in gives, left alone: ", await pump(150, 0, false))
	print("ROPE pumped in time, widest each half swing (degrees): ", await pump(9 * 34, 34))
	print("ROPE end state=", player.state, " at ", player.global_position, " vel ", player.velocity)
	sheet("rope")
	# Closer, and closer together: one whole swing and a bit
	pin = Vector3.INF
	look_h = 0.9
	view = Vector3(PI * 0.5 - 0.2, 0.1, 4.6)
	await pump(16 * 10, 10)
	sheet("rope_swing", 4)
	# From behind, as the orbit camera has it
	view = Vector3(PI + 0.35, 0.25, 6.0)
	await pump(8 * 20, 20)
	sheet("rope_behind", 4)
	# Climbing it (act held), still swinging: the shorter rope swings the quicker
	view = Vector3(PI * 0.5 - 0.2, 0.1, 4.0)
	touch.act_held = true
	for i in 12:
		await frames(5, Vector3.ZERO)
		await snap()
	touch.act_held = false
	touch.move = Vector2.ZERO
	sheet("rope_climb", 4)
	# Let down it again, worked up, and off at the front of the swing
	touch.duck_held = true
	await frames(40, Vector3.ZERO)
	touch.duck_held = false
	touch.act_held = false
	await pump(360, 0)
	look_h = 0.65
	pin = Vector3(74.0, 2.6, 20)
	view = Vector3(PI * 0.5, 0.08, 13.0)
	var before := rope_angle()
	for i in 400:
		var a := rope_angle()
		if player.velocity.x > 0.0 and a > 20.0 and before <= 20.0:
			break
		before = a
		await frames(1, Vector3(signf(player.velocity.x), 0, 0))
	await snap()
	var from: Vector3 = player.global_position
	print("ROPE lets go at %.1f degrees, the rope going %s (frame %d of the sheet)" % [rope_angle(), player.velocity, track.size()])
	touch.jump_held = true
	player._queue_jump()
	await frames(1, Vector3(1, 0, 0))
	print("ROPE leapt off: state=", player.state, " vel ", player.velocity)
	for i in 11:
		await frames(6, Vector3(1, 0, 0))
		await snap()
		if player.is_on_floor() and i > 3:
			touch.jump_held = false
	touch.jump_held = false
	print("ROPE came down %.1f m on from where he let go" % (player.global_position.x - from.x))
	sheet("rope_leap", 4)
	touch.move = Vector2.ZERO
	pin = Vector3.INF
	hold_yaw = NAN


## Stands him at `at` facing +x with `hook` picked up off the ground in front of him.
func take_hook(hook: GrappleHook, at: Vector3) -> void:
	place(at, PI * 0.5)
	hold_yaw = PI * 0.5
	hook.linear_velocity = Vector3.ZERO
	hook.global_position = at + Vector3(0.45, 0.25, 0.0)
	await frames(30)
	player._act()
	await frames(50)


func grapple() -> void:
	# A beam six metres up with somewhere on it for a hook to catch, and the hook lying ready
	box(Vector3(0, 6.3, -30), Vector3(0.4, 0.4, 3.0), Color(0.42, 0.44, 0.47))
	var point := GrapplePoint.mark(stage, Vector3(0, 6.05, -30))
	var hook := GrappleHook.new()
	hook.position = Vector3(-4.3, 0.3, -30)
	stage.add_child(hook)
	await take_hook(hook, Vector3(-4.9, 0.05, -30))
	view = Vector3(PI * 0.5 - 0.5, 0.1, 3.6)
	# Stood with the coil in his hand, and walking with it; what it will catch is marked
	await snap()
	view = Vector3(-0.5, 0.15, 3.6)
	await frames(2)
	await snap()
	for i in 2:
		await frames(9, Vector3(1, 0, 0))
		await snap()
	await frames(30)
	touch.move = Vector2.ZERO
	await frames(20)
	print("GRAPPLE holds ", player.carried, "; would catch ", hook.target, " ", hook.target.global_position if hook.target else Vector3.ZERO, " from ", player.global_position)
	view = Vector3(PI * 0.5 - 0.15, 0.3, 13.0)
	pin = Vector3(-1.0, 3.2, -30)
	await frames(2)
	await snap()
	pin = Vector3.INF
	view = Vector3(PI * 0.5 - 0.5, 0.1, 3.6)
	await frames(2)
	sheet("grapple_hold", 5)
	# The wind-up and throw, every third frame, from his throwing side; and again from in front
	for round in 2:
		view = Vector3(PI * 0.5 - 0.5, 0.1, 4.2) if round == 0 else Vector3(-0.6, 0.15, 4.2)
		await frames(20)
		var began := track.size()
		player._act()
		var bitten := -1
		for i in 16:
			for k in 3:
				await frames(1)
				if bitten < 0 and player.state == Player.State.ROPE:
					bitten = track.size() - began
			await snap()
		print("GRAPPLE thrown: on the rope %.2f s after act (frame %d of the sheet), the rope %.1f m long" % [bitten / 60.0, bitten, hook.rope.length if is_instance_valid(hook.rope) else 0.0])
		sheet("grapple_throw" if round == 0 else "grapple_throw_front", 4)
		if round == 0:
			await take_hook(hook, Vector3(-4.2, 0.05, -30))
	# The whole of it from further off: thrown, bitten, taken off his feet and swung out
	await take_hook(hook, Vector3(-4.2, 0.05, -30))
	view = Vector3(PI * 0.5, 0.06, 15.0)
	pin = Vector3(-1.5, 3.2, -30)
	await frames(40)
	player._act()
	var fastest := 0.0
	var lowest := 100.0
	for i in 16:
		for k in 6:
			await frames(1)
			if player.state == Player.State.ROPE:
				fastest = maxf(fastest, player.velocity.length())
				lowest = minf(lowest, player.global_position.y)
		await snap()
	print("GRAPPLE taken off his feet: fastest %.1f m/s, feet never below %.2f, now at %s" % [fastest, lowest, player.global_position])
	sheet("grapple_swing", 4)
	# Pumped (numbers), then closer as the rope takes him again; then off at the front and winding in
	print("GRAPPLE pumped in time, widest each half swing (degrees): ", await pump(300, 0))
	var before := rope_angle()
	for i in 400:
		var a := rope_angle()
		if player.velocity.x > 0.0 and a > 20.0 and before <= 20.0:
			break
		before = a
		await frames(1, Vector3(signf(player.velocity.x), 0, 0))
	var from: Vector3 = player.global_position
	print("GRAPPLE lets go at %.1f degrees, the rope going %s" % [rope_angle(), player.velocity])
	pin = Vector3.INF
	look_h = 0.8
	view = Vector3(PI * 0.5 - 0.4, 0.1, 5.5)
	touch.jump_held = true
	player._queue_jump()
	for i in 12:
		await frames(5, Vector3(1, 0, 0) if i < 6 else Vector3.ZERO)
		await snap()
	touch.jump_held = false
	touch.move = Vector2.ZERO
	await frames(60)
	print("GRAPPLE came down %.1f m on; hook state %d, out %s, carried %s" % [player.global_position.x - from.x, hook.state, player.hook_out, player.carried == hook])
	sheet("grapple_reel", 4)
	look_h = 0.65
	# Thrown where there is nothing to catch: it falls short and he winds it in
	await take_hook(hook, Vector3(14, 0.05, -30))
	view = Vector3(PI * 0.5 - 0.3, 0.12, 7.5)
	pin = Vector3(16.0, 1.6, -30)
	await frames(40)
	print("GRAPPLE with nothing in reach it would catch ", hook.target)
	player._act()
	for i in 16:
		await frames(5)
		await snap()
	print("GRAPPLE fell short: hook state %d, out %s, his state %d" % [hook.state, player.hook_out, player.state])
	sheet("grapple_miss", 4)
	pin = Vector3.INF
	hold_yaw = NAN
	touch.duck_held = true
	await frames(20)
	player._act()
	await frames(10)
	touch.duck_held = false
	hook.queue_free()
	point.queue_free()


func kick() -> void:
	for round in 2:
		# Run at the wall, jump, and jump again against it. (Its top is out of his reach.)
		place(Vector3(3.0 if round == 0 else -3.0, 0.05, 2.6), 0.0)
		pin = Vector3(player.global_position.x, 1.7, 3.0)
		view = Vector3(PI * 0.5, 0.1, 5.4) if round == 0 else Vector3(PI * 0.5 + 0.9, 0.3, 5.4)
		hold_yaw = 0.0
		await frames(14, Vector3(0, 0, 1))
		touch.jump_held = true
		player._queue_jump()
		for i in 40:
			await frames(1, Vector3(0, 0, 1))
			if player.global_position.z > 3.72 and player.air_time > 0.13:
				break
		print("KICK before: state=", player.state, " at ", player.global_position, " vel ", player.velocity)
		await snap()
		player._queue_jump()
		for i in 15:
			await frames(2, Vector3(0, 0, 1) if i < 2 else Vector3.INF)
			if i == 0:
				print("KICK after: state=", player.state, " vel ", player.velocity)
			if i == 2:
				touch.move = Vector2.ZERO
			await snap()
		touch.jump_held = false
		sheet("kick" if round == 0 else "kick_back", 4)
		hold_yaw = NAN
	pin = Vector3.INF
	look_h = 0.65
