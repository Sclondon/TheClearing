extends Node3D
## The least a level needs for the carnivorous plants, and what the component
## is tested with: a flytrap, a sundew and a pitcher side by side on a flat floor
## under a grey sky, and a post (the stand-in for someone) that goes round
## them in a loop: it walks into the flytrap (which shivers, then snaps shut on
## it, holds it and slowly opens), over the sundew (which bends over it and lets
## it go), and onto the pitcher's lip (which swallows it). Make a scene with a
## Node3D carrying this script and run it; the camera turns slowly round.

var trap: Flytrap
var dew: Sundew
var pit: Pitcher
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera and the post moving (a test or a tool that places them itself).
var still := false
var _time := 0.0
var _step := 0
var _step_time := 0.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.02
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
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.4, 0.38, 0.34))
	add_child(floor_mesh)

	trap = Flytrap.new()
	trap.position = Vector3(-5.0, 0.0, -2.0)
	add_child(trap)
	dew = Sundew.new()
	dew.position = Vector3(0.0, 0.0, 0.0)
	add_child(dew)
	pit = Pitcher.new()
	pit.position = Vector3(5.0, 0.0, 0.0)
	add_child(pit)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.25
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	add_child(post)
	post.position = Vector3(-5.0, 0.62, 4.0)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	if still:
		return
	_time += delta
	_step_time += delta
	var round_about := _time * 0.12
	camera.position = Vector3(sin(round_about) * 12.0, 4.0, cos(round_about) * 12.0)
	camera.look_at(Vector3(0.0, 0.6, 0.0))
	match _step:
		0:
			# into the flytrap's mouth, slowly
			var goal := trap.mouth()
			post.position = post.position.move_toward(Vector3(goal.x, 0.62, goal.z), delta * 1.0)
			if trap.inside(post.position) and trap.is_open():
				trap.twitch()
				_go(1)
		1:
			if _step_time > 0.7:
				trap.snap()
				trap.full = true
				_go(2)
		2:
			if _step_time > 3.0:
				trap.reopen(6.0)
				post.position = Vector3(-2.0, 0.62, 2.5)
				_go(3)
		3:
			# over the sundew
			post.position = post.position.move_toward(Vector3(0.6, 0.62, 1.0), delta * 0.8)
			if dew.sticky(post.position) > 0.5:
				dew.hold(post.position)
			if _step_time > 6.0:
				dew.let_go()
				post.position = Vector3(5.0, 0.62, 3.5)
				_go(4)
		4:
			post.position = post.position.move_toward(Vector3(5.0, 0.62, 0.0), delta * 1.0)
			if pit.over_mouth(post.position - Vector3.UP * 0.62):
				pit.swallow()
				post.position.y = -5.0
				_go(5)
		5:
			if _step_time > 5.0:
				pit.open_lid(5.0)
				post.position = Vector3(-5.0, 0.62, 4.5)
				_go(0)


func _go(next: int) -> void:
	_step = next
	_step_time = 0.0
