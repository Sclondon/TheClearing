extends Node3D
## A family of blue jays in three trees (posts with branches, for the
## example): they flit from branch to branch and down to the ground to hop and
## peck, calling; every 20 seconds a point walks in under the middle tree for 8
## seconds and they gather on the branches over it and scold it, crests up.
## Needs godot/crow. Give it to a Node3D at the root of an empty scene and play it.

var jays: BlueJays
var _clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.64, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	add_child(ground)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 50.0
	camera.look_at_from_position(Vector3(0, 1.8, 8), Vector3(0, 1.6, 0))

	# Three "trees": a trunk each, and branches sticking out with a perch near each end.
	var points := PackedVector3Array()
	var faces := PackedVector3Array()
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.3, 0.22, 0.16)
	for x: float in [-4.0, 0.0, 4.0]:
		var trunk := MeshInstance3D.new()
		var pole := CylinderMesh.new()
		pole.top_radius = 0.06
		pole.bottom_radius = 0.14
		pole.height = 4.0
		trunk.mesh = pole
		trunk.material_override = bark
		trunk.position = Vector3(x, 2.0, -1.0)
		add_child(trunk)
		for k in 5:
			var angle := k * 2.4 + x
			var out := Vector3(cos(angle), 0.0, sin(angle))
			var y := 1.2 + k * 0.55
			var branch := MeshInstance3D.new()
			var stick := CylinderMesh.new()
			stick.top_radius = 0.015
			stick.bottom_radius = 0.03
			stick.height = 1.1
			branch.mesh = stick
			branch.material_override = bark
			add_child(branch)
			branch.global_transform = Transform3D(Basis(out.cross(Vector3.UP).normalized(), -PI * 0.5), Vector3(x, y, -1.0) + out * 0.55)
			points.append(Vector3(x, y + 0.03, -1.0) + out * 0.85)
			faces.append(out)

	jays = BlueJays.new()
	jays.count = 5
	jays.flock_seed = 3
	jays.home = Vector3(0, 0, 1.5)
	jays.roam = 3.0
	add_child(jays)
	jays.set_perches(points, faces, false)
	jays.settle()
	jays.add_child(CorvidVoice.new(jays))


func _process(delta: float) -> void:
	_clock += delta
	var t := fposmod(_clock, 20.0)
	jays.scold(Vector3(0.6, 1.2, -0.4) if t > 10.0 and t < 18.0 else Vector3.INF)
