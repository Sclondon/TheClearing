extends Node3D
## A floor and a wall with two drains at its foot; a point goes round and
## round the floor, and every 18 seconds the rats pour out and chase it for 12,
## then go home. A rat king drags itself after the point, and a rat runs in
## circles. Give it to a Node3D at the root of an empty scene and play that scene.

var swarm: RatSwarm
var king: RatKing
var rat: Rat
var _clock := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(2, 6, 4), Vector3.ZERO)
	_box(Vector3(0, -0.25, 4), Vector3(16, 0.5, 14))
	_box(Vector3(0, 2, -3.25), Vector3(16, 4, 0.5))
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 6, 11), Vector3(0, 0, 2))

	swarm = RatSwarm.new()
	swarm.count = 200
	swarm.add_drain(Vector3(-1.5, 0, -2.98), Vector3.BACK)
	swarm.add_drain(Vector3(1.8, 0, -2.98), Vector3.BACK)
	add_child(swarm)
	swarm.overwhelmed.connect(func() -> void: print("overrun"))

	king = RatKing.new()
	add_child(king)
	king.position = Vector3(3, 0, 5)
	king.urge = 1.0

	rat = Rat.new()
	add_child(rat)


func _box(middle: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = middle
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var look := MeshInstance3D.new()
	look.mesh = BoxMesh.new()
	(look.mesh as BoxMesh).size = size
	body.add_child(look)
	add_child(body)


func _physics_process(delta: float) -> void:
	_clock += delta
	var t := _clock * 0.5
	var point := Vector3(cos(t) * 4.0, 0.0, 4.0 + sin(t) * 3.0)
	swarm.target = point
	swarm.target_moving = Vector3(-sin(t), 0.0, cos(t)) * 2.0
	if fposmod(_clock, 18.0) < 12.0:
		swarm.release()
	else:
		swarm.recall()
	var to := point - king.position
	to.y = 0.0
	king.wish = to.normalized() if to.length() > 0.5 else Vector3.ZERO
	var round_about := _clock * 1.5
	var was := rat.position
	rat.position = Vector3(cos(round_about) * 1.5, 0.0, 2.0 + sin(round_about) * 1.5)
	rat.step((rat.position - was) / maxf(delta, 0.001), delta)
