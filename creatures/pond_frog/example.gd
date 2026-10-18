extends Node3D
## An example of the pond frogs (PondFrogs): put this script on a Node3D in an
## empty scene and run it. A pond of frogs sings; every twenty seconds a post
## walks up to it, and they hush and leap in, and come out again once it has
## walked off. The post is moved here, by hand, as a game would move a player.
##
## Needs GameCommon's godot/frog installed too (the little frog and its shader).

var frogs: PondFrogs
var post: CharacterBody3D
var _time := 0.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.4, 4.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	frogs = PondFrogs.new()
	frogs.chorus = 0.8
	add_child(frogs)
	post = CharacterBody3D.new()
	var look := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.height = 1.7
	shape.radius = 0.2
	look.mesh = shape
	look.position.y = 0.85
	post.add_child(look)
	add_child(post)
	post.position = Vector3(12.0, 0.0, 0.0)
	frogs.frighten = [post]


func _process(delta: float) -> void:
	_time += delta
	var t := fposmod(_time, 20.0)
	# (it walks up for eight seconds, waits, and walks off)
	var goal := Vector3(1.6, 0.0, 0.6) if t > 6.0 and t < 12.0 else Vector3(14.0, 0.0, 0.0)
	var to := goal - post.position
	post.velocity = to.normalized() * 1.4 if to.length() > 0.2 else Vector3.ZERO
	post.position += post.velocity * delta
