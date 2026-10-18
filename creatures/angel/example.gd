extends Node3D
## An ophan hanging over a grey floor between two walls, in a misty light, with
## a post walking slowly round under it: every so often it fixes on the post and
## its gaze builds until it blazes, then lets go. Give it to a Node3D at the root
## of an empty scene and play that scene.

var angel: Ophan
var post: MeshInstance3D
var _clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.65, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.53)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.62, 0.65, 0.65)
	env.environment.fog_density = 0.02
	env.environment.glow_enabled = true
	env.environment.glow_hdr_threshold = 0.9
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(2, 10, 4), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 16.0, 40.0)
		wall.mesh = box
		wall.position = Vector3(8.0 * side, 8.0, 0.0)
		add_child(wall)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 40.0)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.5
	post.mesh = capsule
	add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.6, 15.0), Vector3(0.0, 5.0, 0.0))

	angel = Ophan.new()
	add_child(angel)
	angel.position = Vector3(0.0, 6.0, 0.0)


func _process(delta: float) -> void:
	_clock += delta
	var at := Vector3(sin(_clock * 0.3) * 5.0, 0.75, 6.0 + cos(_clock * 0.3) * 2.0)
	post.position = at
	angel.position.y = 6.0 + sin(_clock * 0.5) * 0.25
	# (twelve seconds round: four watching, six gazing, then the blaze, two let alone)
	var t := fmod(_clock, 12.0)
	angel.look_at_point = at + Vector3.UP * 0.3 if t > 4.0 and t < 10.0 else Vector3.INF
	angel.gaze_ground = Vector3(at.x, 0.0, at.z)
	angel.gaze = clampf((t - 5.0) / 4.5, 0.0, 1.0) if t < 10.0 else 0.0
	if t >= 9.5 and t - delta < 9.5:
		angel.blaze()
