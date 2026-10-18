extends Node3D
## A murder of crows on a wall and a raven on a post: the crows sit along the
## wall's top edge and some walk and peck on the ground in front of it; every
## 25 seconds they erupt, cawing, and wheel over a point that walks along in
## front of the wall, then settle on the wall again; the raven croaks and knocks.
## Give it to a Node3D at the root of an empty scene and play that scene.

var crows: CorvidFlock
var raven: CorvidFlock
var _clock := 0.0
var _gone := false


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
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	add_child(ground)
	# A wall, 3 m high and 12 long, along X at z = -2.
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12, 3, 1)
	wall.mesh = box
	wall.position = Vector3(0, 1.5, -2.5)
	add_child(wall)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 45.0
	camera.look_at_from_position(Vector3(2, 2.2, 9), Vector3(0, 1.8, -2))

	crows = CorvidFlock.new()
	crows.kind = CorvidBody.Kind.CROW
	crows.count = 9
	crows.flock_seed = 5
	crows.home = Vector3(0, 0, 1.5)
	crows.roam = 4.0
	crows.ground_share = 0.35
	crows.grip = 0.15
	crows.circle_height = 0.0
	add_child(crows)
	# Perches along the wall's top edge (its front), facing out.
	var points := PackedVector3Array()
	var faces := PackedVector3Array()
	for k in 24:
		points.append(Vector3(-5.6 + k * 0.48, 3.0, -2.05))
		faces.append(Vector3.BACK)
	crows.set_perches(points, faces, false)
	crows.settle()
	crows.add_child(CorvidVoice.new(crows))
	crows.erupted.connect(func() -> void: print("the murder goes up, cawing"))

	raven = CorvidFlock.new()
	raven.kind = CorvidBody.Kind.RAVEN
	raven.count = 1
	raven.flock_seed = 2
	raven.call_every = 8.0
	add_child(raven)
	var post := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.1
	pole.height = 2.2
	post.mesh = pole
	post.position = Vector3(5.5, 1.1, 2.0)
	add_child(post)
	raven.set_perches(PackedVector3Array([Vector3(5.5, 2.2, 2.0)]), PackedVector3Array([Vector3.LEFT]), false)
	raven.settle()
	raven.add_child(CorvidVoice.new(raven))


func _process(delta: float) -> void:
	_clock += delta
	var t := fposmod(_clock, 25.0)
	if t > 6.0 and t < 7.0 and not _gone:
		_gone = true
		crows.erupt(Vector3(0, 9, 0), 9.0)
	elif t < 6.0:
		_gone = false
	if crows.circling():
		crows.move_circle(Vector3(sin(_clock * 0.3) * 4.0, 9.0, 1.0))
