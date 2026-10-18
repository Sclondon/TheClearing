extends SceneTree
## Pictures of the giant octopus (creatures/octopus/, and MazeOctopus in
## scripts/enemies/). First on the component's own floor
## (creatures/octopus/example.gd): out on the ground close to, from the front,
## the side, three quarters, above and below, its eye; its arms feeling about
## out of its pool, one up the wall; an arm rearing and coiling, the lash, an
## arm wound round the post; its ink; crawling. Then in a hall of a real round
## (World): lurking in its pool with its arms out on the floor (camouflaged),
## the wind-up and the grab at the boy, the boy dragged, inked, out and
## crawling after him, and at a drain in a wall. Says how many draws a frame
## takes. Needs a real window (the engine draws nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/octopus_shots.gd -- <folder> [model|maze|drain|sound|low]
##
## (sound writes its sounds to <folder>/*.wav; low takes the model pictures of the low-poly model.)

var folder := "octopus_shots"
var only := ""
var example: Node3D
var octopus: Octopus
var camera: Camera3D


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
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


## Looks at a point from `direction` (in the octopus's frame: +Z its front), `distance` off.
func look(at: Vector3, direction: Vector3, distance: float, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = at + (octopus.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		var made := {"slither": OctopusSound.slither(), "splash": OctopusSound.splash(), "slap": OctopusSound.slap(), "suck": OctopusSound.suck(), "jet": OctopusSound.jet()}
		for name: String in made:
			(made[name] as AudioStreamWAV).save_to_wav("%s/%s.wav" % [folder, name])
		print("saved the sounds")
		quit()
		return
	if only in ["", "model", "low"]:
		await _model()
	if only in ["", "maze"]:
		await _maze(false)
	if only in ["", "drain"]:
		await _maze(true)
	quit()


func _model() -> void:
	if only == "low":
		Settings.low_poly = true
	example = (load("res://creatures/octopus/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still_camera = true
	example.set_process(false)
	octopus = example.octopus
	camera = example.camera
	camera.make_current()
	example.post.visible = false
	# Out on the ground, sprawled.
	octopus.sunk = 0.0
	octopus.mood = -1.0
	octopus.reveal = 1.0
	octopus.papillae = 0.3
	octopus.put(Vector3(0, 0, 2.0), 0.3)
	for k in Octopus.ARMS:
		octopus.rest(k)
	octopus._settled = false
	await wait(2.0)
	var body := octopus.global_position + Vector3.UP * 0.9
	look(body, Vector3(0, 0.25, 1), 9.0)
	await shot("m01_front")
	look(body, Vector3(1, 0.15, 0), 9.0)
	await shot("m02_side")
	look(body, Vector3(0.8, 0.45, 1), 12.0)
	await shot("m03_quarter")
	look(octopus.global_position, Vector3(0.05, 1, 0.1), 19.0, 50.0)
	await shot("m04_above")
	look(octopus.eyes(), Vector3(0.9, 0.1, 0.35), 2.2, 40.0)
	await shot("m05_eye")
	look(body + Vector3.UP * 0.3, Vector3(-0.6, 0.35, -1), 7.0)
	await shot("m06_back_mantle")
	# One arm rearing, coiled (out on the ground).
	octopus.mood = 1.0
	octopus.wind(0, octopus.global_position + octopus.global_basis.z * 6.0 + octopus.global_basis.x * 1.5)
	await wait(1.0)
	look(body, Vector3(1, 0.2, 0.6), 10.0)
	await shot("m07_wind_up")
	octopus.mood = 2.0
	octopus.lash(0, octopus.global_position + octopus.global_basis.z * 6.0 + octopus.global_basis.x * 1.5)
	await wait(0.18)
	await shot("m08_lash")
	await wait(0.5)
	await shot("m09_lashed")
	# Holding the post.
	example.post.visible = true
	example.post.position = octopus.global_position + octopus.global_basis.z * 4.5 + Vector3.UP * 0.8
	octopus.hold(0, example.post.position - Vector3.UP * 0.8)
	await wait(1.5)
	look(example.post.position, Vector3(1, 0.3, 0.3), 5.5)
	await shot("m10_holding")
	look(example.post.position, Vector3(0.2, 0.4, 1), 4.0)
	await shot("m11_holding_close")
	# Underneath: the suckers.
	octopus.rest(0)
	example.post.visible = false
	octopus.mood = -1.0
	await wait(1.0)
	camera.fov = 45.0
	var arm := octopus.arm_points(2)
	camera.global_position = arm[4] + Vector3(0.6, 0.35, 0.9)
	camera.look_at(arm[4])
	await shot("m12_arm")
	# Crawling.
	octopus.mood = 0.0
	octopus.reveal = 0.0
	octopus.crawling = true
	var t := 0.0
	var taken := 0
	while taken < 3:
		var step := root.get_process_delta_time()
		octopus.velocity = Vector3(0, 0, 1.1).rotated(Vector3.UP, 0.3)
		octopus.global_position += octopus.velocity * step
		for k in Octopus.ARMS:
			octopus.doing[k] = Octopus.Do.CRAWL
		look(octopus.global_position + Vector3.UP * 0.8, Vector3(1, 0.4, 0.4), 12.0)
		await process_frame
		t += step
		if t > 2.0 + taken * 0.7:
			await shot("m1%d_crawl" % (3 + taken))
			taken += 1
	octopus.crawling = false
	# In its pool, feeling about: camouflaged.
	octopus.global_position = Vector3.ZERO
	octopus.sunk = 1.0
	octopus.mood = 0.0
	octopus.reveal = 0.0
	octopus.feel(0, Vector3(2.5, 0.0, 4.5))
	octopus.feel(6, Vector3(-3.0, 1.6, -3.95), Vector3.BACK)
	for k in [1, 2, 3, 4, 5, 7]:
		octopus.rest(k)
	octopus._settled = false
	await wait(3.0)
	camera.fov = 50.0
	camera.global_position = Vector3(5.0, 4.5, 10.0)
	camera.look_at(Vector3(0, 0.3, 0.5))
	await shot("m16_feeling_hidden")
	octopus.mood = -1.0
	octopus.reveal = 1.0
	await wait(0.3)
	await shot("m17_feeling_revealed")
	octopus.mood = 0.0
	octopus.ink()
	await wait(1.3)
	await shot("m18_ink")
	example.queue_free()
	await wait(0.3)


func _maze(_drain: bool) -> void:
	pass
