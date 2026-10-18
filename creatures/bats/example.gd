extends Node3D
## A colony on a wall, woken every few seconds to whirl round a point that
## goes round and round the floor, and sent back to roost between whiles.
## Give it to a Node3D at the root of an empty scene and play that scene.

var colony: BatColony
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
	sun.look_at_from_position(Vector3(2, 5, 4), Vector3.ZERO)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 8, 0.5)
	wall.mesh = box
	wall.position = Vector3(0, 4, -0.25)
	add_child(wall)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 3, 11), Vector3(0, 3, 0))

	colony = BatColony.new()
	colony.count = 14
	colony.colony_seed = 1
	add_child(colony)
	# (on the wall, 6 m up; out of the wall is +Z)
	colony.set_roost(Vector3(0, 6, 0), Vector3.BACK)
	colony.settle()
	colony.woke.connect(func() -> void: print("woke"))
	colony.settled.connect(func() -> void: print("all back on the roost"))


func _process(delta: float) -> void:
	_clock += delta
	# Asleep for 4 s, then 10 s after the point, then home again.
	var awake := fposmod(_clock, 14.0) > 4.0
	colony.awake = awake
	var t := _clock * 0.8
	colony.target = Vector3(cos(t) * 3.0, 1.7, 4.0 + sin(t) * 2.0) if awake else Vector3.INF
