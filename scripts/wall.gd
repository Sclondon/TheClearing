@tool
class_name Wall
extends StaticBody3D
## A wall: one solid box, `width` along X, `height` up and `depth` along Z, that
## stands on its origin (the middle of its base). It is drawn with `texture`,
## tiled across every face at its true size (one tile every `tile_size` metres),
## so a bigger wall shows more stone, not stretched stone; and it can be bumped
## into. Change any of it in the Inspector and it is redrawn at once.

@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var width := 14.0:
	set(value):
		width = value
		_build()
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var height := 34.0:
	set(value):
		height = value
		_build()
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:m") var depth := 3.2:
	set(value):
		depth = value
		_build()
@export var texture: Texture2D = preload("res://textures/stone_blocks.png"):
	set(value):
		texture = value
		_build()
## Its relief: a normal map laid on as the texture is (and how strong).
@export var normal_map: Texture2D = preload("res://textures/stone_blocks_normal.png"):
	set(value):
		normal_map = value
		_build()
@export_range(0.0, 4.0, 0.05) var relief := 1.0:
	set(value):
		relief = value
		_build()
## How many metres one tile of the texture covers.
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var tile_size := 8.0:
	set(value):
		tile_size = value
		_build()
## Multiplied over the texture.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_build()

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape, false, Node.INTERNAL_MODE_BACK)
	var size := Vector3(width, height, depth)
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, height * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	if normal_map:
		material.normal_enabled = true
		material.normal_texture = normal_map
		material.normal_scale = relief
	material.roughness = 1.0
	material.metallic_specular = 0.2
	# (laid on from each side in the box's own metres, so it tiles at the same size on every face)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / tile_size
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mesh.material_override = material
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	_shape.position = _mesh.position
