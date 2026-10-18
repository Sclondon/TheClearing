extends Node3D
## A grey yard with all three kinds: moths round a lamp on a post (some
## resting on the wall behind it), flies round a carcass on the ground, and
## dragonflies hunting over a pond with reeds to perch on. A stand-in for
## someone walks back and forth through them, scattering whatever rests, and
## stops by the carcass now and then for the flies to land on him.
## Give it to a Node3D at the root of an empty scene and play that scene.

var walker: Node3D
var _clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(2, 5, 3), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	add_child(ground)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 2.2, 9), Vector3(0, 1.0, 0))

	# The lamp on its post, before a wall (a body, so that the moths' resting
	# places on it could be found with rays; here they are set by hand).
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 4, 0.3)
	wall.mesh = box
	wall.position = Vector3(-4, 2, -2)
	add_child(wall)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.omni_range = 6.0
	lamp.position = Vector3(-4, 2.4, -1.4)
	add_child(lamp)
	var moths := InsectSwarm.new()
	moths.kind = InsectLook.Kind.MOTH
	moths.count = 20
	moths.swarm_seed = 1
	moths.follow = lamp
	moths.radius = 1.1
	moths.varieties = Vector3(1.0, 0.1, 0.1)
	moths.rest_share = 0.3
	for k in 6:
		var at := Vector3(-5.5 + k * 0.6, 1.6 + (k % 3) * 0.5, -1.84)
		moths.perches.append(Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP).orthonormalized(), at))
	add_child(moths)

	# Flies round a carcass (InsectLook.carcass(): a dead deer).
	var dead := InsectLook.carcass()
	dead.position = Vector3(0, 0, 0)
	add_child(dead)
	var flies := InsectSwarm.new()
	flies.kind = InsectLook.Kind.FLY
	flies.count = 26
	flies.swarm_seed = 2
	flies.follow = dead
	flies.follow_offset = Vector3(0, 0.3, 0)
	flies.radius = 0.9
	flies.spread_height = Vector2(-0.2, 0.7)
	flies.wingspan = Vector2(0.022, 0.03)
	flies.speed = 3.2
	flies.rest_share = 0.35
	flies.land_on_still = 4
	flies.buzz = true
	add_child(flies)

	# Dragonflies over a pond, perching on the tips of reeds.
	var pond := MeshInstance3D.new()
	var water := PlaneMesh.new()
	water.size = Vector2(8, 6)
	pond.mesh = water
	pond.position = Vector3(5, 0.02, -1)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.15, 0.14)
	pond.material_override = dark
	add_child(pond)
	var dragonflies := InsectSwarm.new()
	dragonflies.kind = InsectLook.Kind.DRAGONFLY
	dragonflies.count = 5
	dragonflies.swarm_seed = 3
	dragonflies.centre = Vector3(5, 0, -1)
	dragonflies.radius = 4.0
	dragonflies.wingspan = Vector2(0.1, 0.13)
	dragonflies.speed = 7.5
	dragonflies.flap_rate = 14.0
	dragonflies.rest_share = 0.3
	for k in 8:
		var reed := MeshInstance3D.new()
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.01
		stalk.bottom_radius = 0.015
		stalk.height = 1.3
		reed.mesh = stalk
		reed.position = Vector3(2.5 + k * 0.7, 0.65, 1.6 + 0.3 * sin(k * 2.0))
		add_child(reed)
		dragonflies.perches.append(Transform3D(Basis.IDENTITY, reed.position + Vector3.UP * 0.65))
	add_child(dragonflies)

	walker = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.height = 1.6
	walker.mesh = body
	add_child(walker)
	for swarm: InsectSwarm in [moths, flies, dragonflies]:
		swarm.scarers = [walker]


func _process(delta: float) -> void:
	_clock += delta
	# Back and forth along the front of it all, stopping by the carcass for a while.
	var t := fposmod(_clock, 30.0)
	var x := -6.0 + 12.0 * clampf(t / 10.0, 0.0, 1.0) if t < 10.0 else (6.0 - 6.0 * clampf((t - 10.0) / 5.0, 0.0, 1.0) if t < 15.0 else (0.0 if t < 24.0 else -6.0 * (t - 24.0) / 6.0))
	walker.position = Vector3(x, 0.8, 1.2)
