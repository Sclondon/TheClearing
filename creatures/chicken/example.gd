extends Node3D
## A flock on a patch of ground: left to forage for 8 seconds, then scared
## from one side (they bolt, some fly), left to settle, then made furious at a
## point that circles at head height (they mob it), and calmed again; round and
## round every 30 seconds. The rooster crows at the start.
## Give it to a Node3D at the root of an empty scene and play that scene.

var flock: ChickenFlock
var _clock := 0.0
var _scared := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(2, 5, 4), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	add_child(ground)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 40.0
	camera.look_at_from_position(Vector3(0, 3.5, 9), Vector3(0, 0.4, 0))

	flock = ChickenFlock.new()
	flock.count = 10
	flock.flock_seed = 3
	flock.home = Vector3.ZERO
	flock.roam = 3.5
	add_child(flock)
	flock.startled.connect(func() -> void: print("squawk!"))
	flock.crowed.connect(func(_at: Vector3) -> void: print("cock-a-doodle-doo"))
	flock.furious.connect(func() -> void: print("the rooster is furious"))
	flock.add_child(ChickenVoice.new(flock))
	flock.crow()


func _process(delta: float) -> void:
	_clock += delta
	var t := fposmod(_clock, 30.0)
	if t < 8.0:
		_scared = false
	elif not _scared:
		_scared = true
		flock.scare(Vector3(-5, 0, 2))
	if t > 18.0 and t < 26.0:
		var a := _clock * 0.9
		flock.mob_target = Vector3(cos(a) * 2.0, 1.5, sin(a) * 2.0)
	else:
		flock.mob_target = Vector3.INF
