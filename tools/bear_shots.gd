extends SceneTree
## Pictures of the screaming bear (creatures/bear): close up on a plain floor
## under the game's kind of light (each view, the head from both sides, beside
## the boy for scale, and each move: the prowl, sniffing, the wind-up, rearing,
## the scream, a swipe, the charge (a strip of frames across a stride), the
## skid, mauling), and in a passage of a real round (prowling down a hall,
## seen from the boy; reared and screaming; charging; the swipe). Says how many
## draws a frame takes. With `voice`, writes each of its cries in each voice
## as .wav files to listen to. Needs a real window (the engine draws nothing
## headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/bear_shots.gd -- <folder> [studio|strips|maze|voice|all]

const SIZE := 2.4

var folder := "bear_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _run() -> void:
	if mode in ["voice", "all"]:
		_voices()
	if mode in ["studio", "all"]:
		await _studio(false)
	if mode in ["strips"]:
		await _studio(true)
	if mode in ["maze", "all"]:
		await _maze()
	quit()


var mover := Callable()


func shot(name: String) -> void:
	for i in 2:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame


## Looks at `target` from `offset` away (in the bear's own space, if `bear` is given).
func look(target: Vector3, offset: Vector3, bear: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if bear:
		from = Basis(Vector3.UP, bear.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


## Every cry in every voice, as .wav files.
func _voices() -> void:
	var names := ["help", "help_me", "no", "scream", "sob"]
	var started := Time.get_ticks_msec()
	for speaker in BearVoice.SPEAKERS:
		for which in BearVoice.CRIES:
			BearVoice.cry(which, speaker).save_to_wav("%s/voice%d_%s.wav" % [folder, speaker, names[which]])
	print("voices: %d cries made in %d ms" % [BearVoice.SPEAKERS * BearVoice.CRIES, Time.get_ticks_msec() - started])
	for pick: Vector2i in [Vector2i(BearVoice.CALL_HELP, 0), Vector2i(BearVoice.CALL_HELP_ME, 1), Vector2i(BearVoice.SCREAM, 1), Vector2i(BearVoice.CALL_NO, 2), Vector2i(BearVoice.SOB, 4)]:
		_spectrogram(BearVoice.cry(pick.x, pick.y)).save_png("%s/spectrum%d_%s.png" % [folder, pick.y, names[pick.x]])
	var others := {"huff": Bear.huff_sound(), "pop": Bear.pop_sound(), "sniff": Bear.sniff_sound(),
			"growl": Bear.growl_sound(), "thud": Bear.thud_sound(), "rake": Bear.rake_sound()}
	for name: String in others:
		(others[name] as AudioStreamWAV).save_to_wav("%s/%s.wav" % [folder, name])


## A picture of a sound: time across, pitch up (to 5.5 kHz), loudness as brightness.
func _spectrogram(stream: AudioStreamWAV) -> Image:
	var count := stream.data.size() / 2
	var size := 512
	var hop := 128
	var columns := maxi((count - size) / hop, 1)
	var rows := 256
	var image := Image.create(columns, rows, false, Image.FORMAT_RGB8)
	var levels := PackedFloat32Array()
	levels.resize(columns * rows)
	var loudest := -999.0
	var window := PackedFloat32Array()
	window.resize(size)
	for i in size:
		window[i] = 0.5 - 0.5 * cos(TAU * i / (size - 1))
	for c in columns:
		var re := PackedFloat32Array()
		var im := PackedFloat32Array()
		re.resize(size)
		im.resize(size)
		for i in size:
			re[i] = stream.data.decode_s16((c * hop + i) * 2) / 32768.0 * window[i]
		_fft(re, im)
		for r in rows:
			var bin := r
			var power := sqrt(re[bin] * re[bin] + im[bin] * im[bin])
			levels[c * rows + r] = 20.0 * log(power + 0.00001) / log(10.0)
			loudest = maxf(loudest, levels[c * rows + r])
	for c in columns:
		for r in rows:
			var level := clampf((levels[c * rows + r] - loudest + 70.0) / 70.0, 0.0, 1.0)
			image.set_pixel(c, rows - 1 - r, Color(level, level, level))
	return image


## An in-place radix-2 FFT.
func _fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var t := re[i]
			re[i] = re[j]
			re[j] = t
			t = im[i]
			im[i] = im[j]
			im[j] = t
	var length := 2
	while length <= n:
		var angle := -TAU / length
		for start in range(0, n, length):
			for k in length / 2:
				var w_re := cos(angle * k)
				var w_im := sin(angle * k)
				var a := start + k
				var b := a + length / 2
				var t_re := re[b] * w_re - im[b] * w_im
				var t_im := re[b] * w_im + im[b] * w_re
				re[b] = re[a] - t_re
				im[b] = im[a] - t_im
				re[a] += t_re
				im[a] += t_im
		length <<= 1


# --- On a plain floor ---

func _studio(strips: bool) -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 600.0

	var bear := Bear.new()
	bear.scale = Vector3.ONE * SIZE
	stage_root.add_child(bear)
	await frames(30)
	if strips:
		await _strip(bear, 1.2, "t01_prowl_strip", 8)
		await _strip(bear, 3.0, "t02_stalk_strip", 8)
		await _strip(bear, 6.8, "t03_charge_strip", 8)
		stage_root.queue_free()
		await frames(4)
		return
	var middle := Vector3(0.0, 1.5, 0.3)
	var head := Vector3(0.0, 1.85, 2.0)
	look(middle, Vector3(0.0, 0.6, 11.0), bear)
	await shot("s01_front")
	look(middle, Vector3(10.0, 0.4, 0.0), bear)
	await shot("s02_side")
	look(middle, Vector3(8.5, 2.0, 7.5), bear)
	await shot("s03_three_quarter")
	look(middle, Vector3(-8.5, 2.0, 7.5), bear)
	await shot("s03b_three_quarter_right")
	look(middle, Vector3(-7.5, 3.0, -7.5), bear)
	await shot("s04_back_quarter")
	look(head, Vector3(2.2, 0.3, 2.2), bear)
	await shot("s05_head")
	look(head, Vector3(-2.2, 0.3, 2.2), bear)
	await shot("s06_head_skull_side")
	look(head + Vector3(0.0, -0.1, 0.0), Vector3(0.1, 0.2, 3.2), bear)
	await shot("s07_head_front")

	# Beside the boy, for scale
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	stage_root.add_child(ground_body)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = Vector3(2.4, 0.05, 3.4)
	boy.rotation.y = PI * 0.8
	await frames(20)
	look(Vector3(1.0, 1.4, 1.2), Vector3(10.0, 1.0, 6.5))
	await shot("s08_beside_the_boy")

	# Rearing over him, screaming
	bear.look_at_point = boy.global_position + Vector3.UP * 1.0
	bear.rearing = true
	await frames(70)
	look(Vector3(1.0, 2.6, 1.2), Vector3(11.0, 0.6, 6.5))
	await shot("s09_reared_beside_the_boy")
	bear.scream()
	await frames(30)
	look(Vector3(0.8, 2.8, 1.5), Vector3(-6.0, -0.4, 9.5))
	await shot("s10_reared_scream")
	await frames(25)
	look(bear.global_position + Vector3(0.0, 4.2, 0.8), Vector3(-1.6, -0.6, 3.6), bear)
	await shot("s11_reared_scream_face")
	boy.queue_free()
	bear.rearing = false
	await frames(80)

	# The prowl, sniffing, the wind-up
	await _moving(bear, 1.2, 2.0, "s12_prowl")
	look(bear.global_position + Vector3(0.0, 1.6, 0.0), Vector3(7.0, 1.0, 7.0), bear)
	await shot("s13_prowl_quarter")
	bear.sniffing = true
	await _moving(bear, 0.0, 1.2, "")
	look(bear.global_position + Vector3(0.0, 2.0, 1.2), Vector3(5.5, 0.4, 4.0), bear)
	await shot("s14_sniffing")
	bear.sniffing = false
	bear.look_at_point = bear.global_position + bear.global_basis.z.normalized() * 20.0 + Vector3.UP * 1.0
	bear.pop_jaw()
	await frames(8)
	look(bear.global_position + Vector3(0.0, 1.8, 1.4), Vector3(4.0, 0.3, 4.5), bear)
	await shot("s15_jaw_pop")
	bear.lowered = true
	bear.scream()
	await frames(40)
	look(bear.global_position + Vector3(0.0, 1.3, 1.0), Vector3(7.5, 0.6, 7.0), bear)
	await shot("s16_wind_up")
	look(bear.global_position + Vector3(0.0, 1.3, 1.0), Vector3(0.8, 0.3, 9.0), bear)
	await shot("s17_wind_up_front")
	# The charge
	await _moving(bear, 6.8, 1.5, "s18_charge")
	look(bear.global_position + Vector3(0.0, 1.4, 1.0), Vector3(7.0, 1.2, 9.0), bear)
	await shot("s19_charge_quarter")
	var speed := 6.8
	while speed > 0.0:
		var step := root.get_process_delta_time()
		speed = maxf(speed - 12.0 * step, 0.0)
		bear.global_position += bear.global_basis.z.normalized() * speed * step
		look(bear.global_position + Vector3(0.0, 1.4, 0.5), Vector3(11.0, 0.6, 1.0), bear)
		if speed < 3.5 and speed > 3.2:
			await shot("s20_skid")
		await process_frame
	bear.lowered = false
	await frames(30)
	# A swipe, frame by frame
	bear.swipe(1.0)
	for k in 5:
		await frames(9)
		look(bear.global_position + Vector3(0.0, 1.6, 1.4), Vector3(3.0, 0.8, 8.0), bear)
		await shot("s21_swipe_%d" % k)
	await frames(30)
	# Reared, swiping
	bear.rearing = true
	await frames(60)
	bear.swipe(-1.0)
	await frames(int(BearRig.SWIPE_TIME * 60.0 * 0.35))
	look(bear.global_position + Vector3(0.0, 2.8, 1.0), Vector3(-5.0, 0.0, 9.0), bear)
	await shot("s22_reared_swipe")
	bear.rearing = false
	await frames(70)
	# Mauling
	bear.mauling = true
	await frames(60)
	look(bear.global_position + Vector3(0.0, 1.0, 1.6), Vector3(6.0, 1.5, 5.0), bear)
	await shot("s23_mauling")
	bear.mauling = false
	await frames(30)
	# The low-poly one
	var low := Bear.new()
	low.low_poly = true
	low.scale = Vector3.ONE * SIZE
	stage_root.add_child(low)
	low.global_position = bear.global_position + Vector3(8.0, 0.0, 0.0)
	await frames(20)
	look(low.global_position + Vector3(0.0, 1.5, 0.3), Vector3(8.5, 2.0, 7.5), low)
	await shot("s24_low_poly")
	stage_root.queue_free()
	await frames(4)


func _moving(bear: Bear, speed: float, seconds: float, name: String) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		bear.global_position += bear.global_basis.z.normalized() * speed * step
		if Vector2(bear.global_position.x, bear.global_position.z).length() > 120.0:
			bear.global_position = Vector3.ZERO
			bear.settle()
		look(bear.global_position + Vector3(0.0, 1.5, 0.3), Vector3(12.0, 0.4, 0.5), bear)
		await process_frame
	if name != "":
		await shot(name)


## A strip of `count` frames, side on, across one stride at `speed`, put side by side in one picture.
func _strip(bear: Bear, speed: float, name: String, count: int) -> void:
	var tiles: Array[Image] = []
	var model_speed := speed / SIZE
	var period := BearRig._keyed(BearRig.STRIDE, model_speed) / model_speed
	var every := period / count
	# (up to speed first)
	var warm := 1.5
	while warm > 0.0:
		var step := root.get_process_delta_time()
		warm -= step
		bear.global_position += bear.global_basis.z.normalized() * speed * step
		await process_frame
	var clock := 0.0
	var next := 0.0
	while tiles.size() < count:
		var step := root.get_process_delta_time()
		clock += step
		bear.global_position += bear.global_basis.z.normalized() * speed * step
		look(bear.global_position + Vector3(0.0, 1.5, 0.3), Vector3(9.5, 0.5, 0.0), bear)
		await process_frame
		if clock >= next:
			next += every
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var w := image.get_width()
			var h := image.get_height()
			tiles.append(image.get_region(Rect2i(int(w * 0.2), int(h * 0.05), int(w * 0.6), int(h * 0.9))))
	var tile := tiles[0]
	var across := 4
	var sheet := Image.create(tile.get_width() * across, tile.get_height() * ((count + across - 1) / across), false, tile.get_format())
	for i in tiles.size():
		sheet.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % across) * tile.get_width(), (i / across) * tile.get_height()))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (a stride: %.2f s, a frame every %.3f s)" % [folder, name, period, every])


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run and maze.blocked(at, step):
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := maze.world(best)
	var yaw := atan2(way.x, way.z)
	var bear := Bear.new()
	bear.scale = Vector3.ONE * SIZE
	world.add_child(bear)
	# (it comes up the hall towards him)
	bear.global_position = start + way * 30.0
	bear.rotation.y = yaw + PI
	boy.global_position = start + way * 4.0 + side * 1.0
	boy.rotation.y = yaw
	await frames(30)

	# Prowling down the hall, head low and swinging, seen from behind him
	mover = func(step: float) -> void:
		bear.global_position -= way * 1.2 * step
	await frames(120)
	var over := boy.global_position + up * 1.7 - way * 2.5 + side * 0.6
	look(bear.global_position + up * 1.6, over - bear.global_position - up * 1.6, null, 50.0)
	await shot("m01_prowling_from_behind_him")
	look(bear.global_position + up * 1.6, -way * 8.0 + side * 6.0 + up * 1.5)
	await shot("m02_prowling_close")
	# It sees him: up on its hind legs, screaming with someone's voice
	mover = Callable()
	bear.look_at_point = boy.global_position + up * 1.2
	bear.rearing = true
	await frames(60)
	bear.scream()
	await frames(30)
	over = boy.global_position + up * 1.6 - way * 2.5 + side * 0.6
	look(bear.global_position + up * 3.0, over - bear.global_position - up * 3.0, null, 50.0)
	await shot("m03_reared_screaming_from_him")
	look(bear.global_position + up * 3.0, -way * 9.0 - side * 6.0 + up * 0.5)
	await shot("m04_reared_screaming")
	bear.rearing = false
	bear.lowered = true
	await frames(50)
	# The charge
	mover = func(step: float) -> void:
		bear.global_position -= way * 6.8 * step
	await frames(45)
	look(bear.global_position + up * 1.4, -way * 9.0 + side * 5.0 + up * 1.0)
	await shot("m05_charging")
	over = boy.global_position + up * 1.6 - way * 2.0 + side * 0.4
	look(bear.global_position + up * 1.6, over - bear.global_position - up * 1.6, null, 55.0)
	await shot("m06_charging_from_him")
	mover = Callable()
	bear.lowered = false
	bear.swipe(-1.0)
	await frames(int(BearRig.SWIPE_TIME * 60.0 * 0.32))
	look(bear.global_position + up * 2.0, side * 9.0 - way * 3.0 + up * 1.0)
	await shot("m07_swipe")
