extends Node3D
## A whole scene for the luck dragon: attach to a Node3D in an empty scene and
## play. It swims round a weaving loop, comes down to a post every so often to
## look at it and sing, and goes up again.

var dragon: LuckDragon
var t := 0.0


func _ready() -> void:
	var light := DirectionalLight3D.new()
	add_child(light)
	light.look_at_from_position(Vector3(2, 6, 3), Vector3.ZERO)
	var post := MeshInstance3D.new()
	post.mesh = CylinderMesh.new()
	post.scale = Vector3(0.3, 1.0, 0.3)
	post.position = Vector3(0, 1, 0)
	add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 18, 60), Vector3(0, 8, 0))
	dragon = LuckDragon.new()
	add_child(dragon)
	dragon.position = Vector3(30, 20, 0)
	dragon.settle()


func _process(delta: float) -> void:
	t += delta
	var low := fposmod(t, 40.0) > 28.0
	var a := t * 0.35
	var high := 3.0 if low else 20.0 + sin(t * 0.8) * 4.0
	var r := 12.0 if low else 30.0
	dragon.position = dragon.position.lerp(Vector3(cos(a) * r, high, sin(a) * r), 1.0 - exp(-2.0 * delta))
	dragon.aim = Vector3(0, 2, 0) if low else Vector3.INF
	dragon.reach = 1.0 if low else 0.0
	if low and not dragon.singing() and fposmod(t, 40.0) < 28.1:
		dragon.sing()
