@tool
class_name Wall
extends StaticBody3D
## A wall: one solid box, `width` along X, `height` up and `depth` along Z, that
## stands on its origin (the middle of its base). It is drawn with `texture`,
## tiled across every face at its true size (one tile every `tile_size` metres),
## so a bigger wall shows more stone, not stretched stone; and it can be bumped
## into. Change any of it in the Inspector and it is redrawn at once.
##
## The looks are brutalist concrete, and the old stone blocks (textures/, made by
## tools/make_wall_textures.gd and tools/make_stone_texture.gd).

enum Look { CONCRETE_PANELS, BOARD_MARKED, WEATHERED, MONOLITH, STONE_BLOCKS, CUSTOM }
## Each look's texture (textures/<name>.png and <name>_normal.png) and how many
## metres a tile of it covers.
const LOOKS := {
	Look.CONCRETE_PANELS: ["concrete_panels", 9.6],
	Look.BOARD_MARKED: ["concrete_boards", 7.0],
	Look.WEATHERED: ["concrete_weathered", 10.0],
	Look.MONOLITH: ["concrete_monolith", 12.0],
	Look.STONE_BLOCKS: ["stone_blocks", 8.0],
}

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
## Its surface, chosen from LOOKS (which sets the texture, its relief and a
## fitting tile size), or Custom to keep a texture of your own.
@export var look := Look.CONCRETE_PANELS:
	set(value):
		look = value
		if look != Look.CUSTOM:
			var chosen: Array = LOOKS[look]
			texture = load("res://textures/%s.png" % chosen[0])
			normal_map = load("res://textures/%s_normal.png" % chosen[0])
			tile_size = chosen[1]
		_build()
@export var texture: Texture2D = preload("res://textures/concrete_panels.png"):
	set(value):
		texture = value
		_build()
## Its relief: a normal map laid on as the texture is (and how strong).
@export var normal_map: Texture2D = preload("res://textures/concrete_panels_normal.png"):
	set(value):
		normal_map = value
		_build()
@export_range(0.0, 4.0, 0.05) var relief := 1.0:
	set(value):
		relief = value
		_build()
## How many metres one tile of the texture covers.
@export_range(0.5, 50.0, 0.1, "or_greater", "suffix:m") var tile_size := 9.6:
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
	_fill_missing()
	if not is_inside_tree():
		return
	# (its own mesh and shape, found again if the script was reloaded in the editor, never made twice)
	if _mesh == null or not is_instance_valid(_mesh):
		_mesh = _own_child("Mesh", MeshInstance3D) as MeshInstance3D
	if _shape == null or not is_instance_valid(_shape):
		_shape = _own_child("Shape", CollisionShape3D) as CollisionShape3D
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


## The internal child called `called` of class `kind`, made if there is none (and
## any others of that name, left over, taken away).
func _own_child(called: String, kind: Variant) -> Node:
	var found: Node = null
	for child in get_children(true):
		if String(child.name).begins_with(called) and is_instance_of(child, kind):
			if found == null:
				found = child
			else:
				child.queue_free()
	if found == null:
		found = kind.new()
		found.name = called
		add_child(found, false, Node.INTERNAL_MODE_BACK)
	return found


## Gives any setting that is empty its default. (When the editor reloads this
## script after it has changed, a wall already in an open scene can come back with
## settings it did not have before left empty.)
func _fill_missing() -> void:
	var defaults := {
		"width": 14.0, "height": 34.0, "depth": 3.2, "look": Look.CONCRETE_PANELS, "relief": 1.0, "tile_size": 9.6, "tint": Color.WHITE,
	}
	for key: String in defaults:
		if get(key) == null:
			set(key, defaults[key])
	if look != Look.CUSTOM:
		if texture == null:
			texture = load("res://textures/%s.png" % LOOKS[look][0])
		if normal_map == null:
			normal_map = load("res://textures/%s_normal.png" % LOOKS[look][0])
