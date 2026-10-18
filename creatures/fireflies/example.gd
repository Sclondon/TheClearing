extends Node3D
## Fireflies on their own: put this on a Node3D in an empty scene and run it. A
## dark field under a moon with clouds of fireflies over it (big dippers swooping
## up as they flash, a synchronous kind flashing all together in waves, and a
## cold green kind glowing slowly), one patch in a ring of posts for woods, and a
## stand-in for someone who runs back and forth through them now and then, and
## stands still between: they scatter flashing and drift back. Every eight
## seconds the dusk comes and goes, so you see them rise out of the grass.

var field: FireflyField
var walker: Node3D
var _t := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.08, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.34, 0.42)
	env.environment.ambient_light_energy = 0.4
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.64, 0.82)
	moon.light_energy = 0.3
	add_child(moon)
	moon.look_at_from_position(Vector3(2, 5, 3), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	add_child(ground)
	for k in 8:
		var post := MeshInstance3D.new()
		var trunk := CylinderMesh.new()
		trunk.height = 6.0
		trunk.top_radius = 0.15
		trunk.bottom_radius = 0.25
		post.mesh = trunk
		post.position = Vector3(12.0 + cos(k * 0.8) * 4.0, 3.0, -10.0 + sin(k * 0.8) * 4.0)
		add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.6, 8.0), Vector3(0.0, 1.0, -6.0))
	field = FireflyField.new()
	field.lights = 1
	add_child(field)
	field.add_patch(Vector3(-4.0, 0.0, -4.0), 7.0, 80, Vector2(0.3, 1.8), 1)
	field.add_patch(Vector3(5.0, 0.0, -14.0), 8.0, 90, Vector2(0.3, 1.8), 2)
	# (in among the trees, higher: up into the boughs; and all of the synchronous kind)
	field.add_patch(Vector3(12.0, 0.0, -10.0), 5.0, 60, Vector2(0.4, 4.5), 3, Callable(), Vector3(0.0, 1.0, 0.0))
	walker = Node3D.new()
	add_child(walker)
	field.scarers = [walker]


func _process(delta: float) -> void:
	_t += delta
	# The dusk: night rises over four seconds, holds, and goes (so it can be watched again).
	var cycle := fmod(_t, 40.0)
	field.night = clampf(cycle / 4.0, 0.0, 1.0) if cycle < 36.0 else clampf((40.0 - cycle) / 4.0, 0.0, 1.0)
	# Someone runs through the first cloud and back, and stands between.
	var run := fmod(_t, 12.0)
	if run < 3.0:
		walker.global_position = Vector3(-12.0 + run * 5.5, 0.0, -4.0)
	elif run > 6.0 and run < 9.0:
		walker.global_position = Vector3(4.5 - (run - 6.0) * 5.5, 0.0, -4.0)
