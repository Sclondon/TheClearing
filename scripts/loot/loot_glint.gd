class_name LootGlint
extends Sprite3D
## A glint now and then off something lying about (LootItem, LootHook): a small
## four-pointed spark that flashes for a moment every few seconds, the way wet
## metal or a bit of glass catches the light, so that what lies in the grass
## can be found without being lit up like a prize. Only near (GLINT_RANGE), and
## only while it lies there to be taken.

const GLINT_RANGE := 30.0
## How often it flashes, seconds, and for how long.
const EVERY := 3.6
const FLASH := 0.4

static var _texture: ImageTexture

var _phase := 0.0
var _time := 0.0


func _init(phase := 0.0) -> void:
	_phase = phase


func _ready() -> void:
	if _texture == null:
		_texture = _star()
	texture = _texture
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	transparent = true
	double_sided = true
	pixel_size = 0.006
	modulate = Color(1.0, 0.96, 0.82, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3.UP * 0.14
	render_priority = 2
	_time = _phase


func _process(delta: float) -> void:
	var item := get_parent() as Node3D
	var lying: bool = item != null and item.visible and item.get(&"loot_state") == LootItem.State.LYING
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if not lying or camera == null or camera.global_position.distance_to(global_position) > GLINT_RANGE:
		modulate.a = 0.0
		return
	# (always upright over where it lies, however it lies)
	global_position = item.global_position + Vector3.UP * 0.14
	var into := fmod(_time, EVERY)
	var flash := sin(clampf(into / FLASH, 0.0, 1.0) * PI) if into < FLASH else 0.0
	modulate.a = flash
	scale = Vector3.ONE * (0.4 + flash * 0.9)
	rotation.z = into * 2.0


## Four points of light round a bright middle.
static func _star() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5) / (size * 0.5)
			var ray := maxf(1.0 - absf(p.x) * 6.0, 0.0) * (1.0 - absf(p.y)) + maxf(1.0 - absf(p.y) * 6.0, 0.0) * (1.0 - absf(p.x))
			var core := clampf(1.0 - p.length() * 3.0, 0.0, 1.0)
			var a := clampf(ray * 0.9 + core, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)
