extends Node3D
## The least a level needs for `Octopus`, and what the component is tested
## with: one in a black pool on a flat floor under a grey sky, against a wall,
## going round a loop. Down in its water it feels about with two arms (along
## the floor, one up the wall), then rears an arm up, coils it and lashes it at
## a post (the stand-in for a player), wraps it round it and drags it in; lets
## it go, inks and draws in; comes up out of the water and crawls a few metres
## across the floor, and goes back and sinks. Make a scene with a Node3D
## carrying this script and run it; it all goes by itself. The camera turns
## slowly round.

var octopus: Octopus
var pool: OctopusPool
var post: MeshInstance3D
var wall: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What it is doing in the loop (for a test to read).
var step := "feel"
var _time := 0.0
var _step_time := 0.0
var _home := Vector3.ZERO
var _post_home := Vector3(1.5, 0.8, 6.0)


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.015
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.17, 0.155, 0.135))
	add_child(floor_mesh)
	wall = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(30.0, 12.0, 2.0)
	wall.mesh = box
	wall.material_override = Toon.surface(Color(0.42, 0.42, 0.4))
	wall.position = Vector3(0.0, 6.0, -5.0)
	add_child(wall)

	pool = OctopusPool.new()
	pool.radius = 2.8
	add_child(pool)
	pool.position = _home

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = _post_home
	add_child(post)

	octopus = Octopus.new()
	add_child(octopus)
	octopus.mouth = _home
	octopus.hole_radius = pool.radius * 0.8
	octopus.water = Vector4(_home.x, _home.y, _home.z, pool.radius)
	octopus.sunk = 1.0
	octopus.put(_home, 0.0)
	for k in Octopus.ARMS:
		octopus.rest(k)

	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.12
		camera.position = Vector3(sin(round_about) * 14.0, 6.0, cos(round_about) * 14.0)
		camera.look_at(Vector3(0.0, 0.5, 1.0))
	match step:
		"feel":
			octopus.mood = 0.0
			octopus.feel(0, Vector3(2.5 + sin(_time * 0.3), 0.0, 4.5))
			octopus.feel(6, Vector3(-3.0, 1.6, -3.95), Vector3.BACK)
			if _step_time > 6.0:
				_go("wind")
		"wind":
			octopus.mood = 1.0
			octopus.wind(1, post.position)
			if _step_time > 0.9:
				_go("lash")
		"lash":
			octopus.mood = 2.0
			if _step_time < 0.05:
				octopus.lash(1, post.position)
			if _step_time > 0.35:
				_go("drag")
		"drag":
			octopus.hold(1, post.position)
			var to := _home - post.position
			to.y = 0.0
			if to.length() > 2.2:
				post.position += to.normalized() * 1.4 * delta
			if _step_time > 4.5:
				_go("ink")
		"ink":
			if _step_time < 0.05:
				octopus.ink()
			for k in Octopus.ARMS:
				octopus.rest(k)
			octopus.mood = 0.0
			post.position = _post_home
			if _step_time > 5.0:
				_go("out")
		"out":
			octopus.sunk = maxf(octopus.sunk - delta / 1.6, 0.0)
			if octopus.sunk <= 0.0:
				octopus.crawling = true
				_go("crawl")
		"crawl":
			var v := Vector3(0.0, 0.0, 1.1)
			octopus.velocity = v
			octopus.global_position += v * delta
			for k in Octopus.ARMS:
				octopus.doing[k] = Octopus.Do.CRAWL
			if _step_time > 5.0:
				_go("back")
		"back":
			var to := _home - octopus.global_position
			to.y = 0.0
			if to.length() > 0.1:
				octopus.velocity = to.normalized() * 1.6
				octopus.global_position += octopus.velocity * delta
			else:
				octopus.crawling = false
				octopus.velocity = Vector3.ZERO
				for k in Octopus.ARMS:
					octopus.rest(k)
				octopus.sunk = minf(octopus.sunk + delta / 1.6, 1.0)
				if octopus.sunk >= 1.0:
					_go("feel")


func _go(next: String) -> void:
	step = next
	_step_time = 0.0
