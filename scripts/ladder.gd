class_name Ladder
extends Node3D
## A ladder standing straight up from where this node is placed. Its rungs face
## the node's +Z: that is the side it is climbed from. The player takes hold by
## walking or jumping into it, climbs with up and down, steps off at the top,
## and leaps off backwards with jump.

## Distance between rungs. The player's hands and feet go from one to the next.
const RUNG := 0.3

@export var height := 4.0


func _ready() -> void:
	add_to_group(&"ladders")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.36, 0.25)
	wood.roughness = 1.0
	wood.metallic_specular = 0.0
	for x: float in [-0.22, 0.22]:
		_bar(Vector3(x, height * 0.5, 0.0), Vector3(0.05, height, 0.05), wood)
	for i in int(height / RUNG):
		_bar(Vector3(0.0, (i + 1) * RUNG, 0.0), Vector3(0.44, 0.035, 0.035), wood)


func _bar(at: Vector3, size: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = at
	add_child(bar)


func top_y() -> float:
	return global_position.y + height


func bottom_y() -> float:
	return global_position.y


## The way someone on it faces: into it.
func facing() -> Vector3:
	return -global_basis.z.normalized()


## Where the climber's body is, level with `y`: just clear of the rungs.
func stand(y: float) -> Vector3:
	var at := global_position - facing() * 0.3
	return Vector3(at.x, y, at.z)


## The rung nearest `y`, counting only every other one, starting from the
## `odd` ones or the even: hands and feet each take alternate rungs.
func rung(y: float, odd: bool) -> float:
	var offset := RUNG if odd else 0.0
	return global_position.y + snappedf(y - global_position.y - offset, RUNG * 2.0) + offset
