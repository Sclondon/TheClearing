class_name LootGunFx
extends Node3D
## A gun going off (Loot): a flash at the muzzle with a moment's light, the
## streak of the shot to where it went, and the crack of it; and the other sounds
## of what there is to fight with (a dry click, a reload, a blow landing). Made
## when it happens and gone a moment later: nothing of it runs otherwise.
##
## The sounds are real recordings, CC0 (audio/guns/CREDITS.md), from Outside.
##
##     LootGunFx.shot(parent, muzzle_transform, where_it_went, LootItem.Kind.REVOLVER)
##     LootGunFx.play(parent, "dry", at)

const SHOTS := {
	LootItem.Kind.REVOLVER: ["shot_revolver_1", "shot_revolver_3"],
	LootItem.Kind.SHOTGUN: ["shot_shotgun_1", "shot_shotgun_2"],
}
const LIFE := 0.11

static var _streams := {}
static var _flash_material: StandardMaterial3D
static var _streak_material: StandardMaterial3D

var _age := 0.0
var _light: OmniLight3D
var _flash: MeshInstance3D
var _streak: MeshInstance3D


## A sound from audio/guns/ (by its name less its number and .wav: one of them at
## random), at `at`, heard out to `reach` metres.
static func play(parent: Node, sound: String, at: Vector3, volume_db := 0.0, reach := 40.0, pitch := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var stream := _stream(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = reach
	player.unit_size = reach * 0.25
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := "res://audio/guns/%s.wav" % sound
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sound] = stream
	return stream


## A shot out of `muzzle` (its -Z the way it points) that went as far as `to`.
static func shot(parent: Node, muzzle: Transform3D, to: Vector3, kind: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := LootGunFx.new()
	parent.add_child(fx)
	fx.global_position = muzzle.origin
	fx._build(muzzle, to, kind)
	var names: Array = SHOTS.get(kind, SHOTS[LootItem.Kind.REVOLVER])
	# (loud: heard right across a section)
	play(parent, names[randi() % names.size()], muzzle.origin, 3.0, 220.0)


func _build(muzzle: Transform3D, to: Vector3, kind: int) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(1.0, 0.93, 0.78)
		_streak_material = StandardMaterial3D.new()
		_streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_streak_material.albedo_color = Color(1.0, 0.97, 0.9, 0.35)
	var big := 1.6 if kind == LootItem.Kind.SHOTGUN else 1.0
	var out := -muzzle.basis.z.normalized()
	# A flash: a star of light out of the barrel.
	var cone := PrismMesh.new()
	cone.size = Vector3(0.07, 0.16, 0.07) * big
	_flash = MeshInstance3D.new()
	_flash.mesh = cone
	_flash.material_override = _flash_material
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)
	_flash.global_basis = Basis(Quaternion(Vector3.UP, out)).rotated(out, randf() * TAU)
	_flash.global_position = muzzle.origin + out * 0.08 * big
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.6)
	_light.light_energy = 5.0 * big
	_light.omni_range = 9.0 * big
	_light.shadow_enabled = false
	add_child(_light)
	# The streak of the shot.
	var length := muzzle.origin.distance_to(to)
	if length > 0.5:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.012, 0.012, length)
		_streak = MeshInstance3D.new()
		_streak.mesh = bar
		_streak.material_override = _streak_material
		_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_streak)
		_streak.global_transform = Transform3D(Basis.looking_at(to - muzzle.origin, Vector3.UP if absf(out.y) < 0.98 else Vector3.RIGHT), (muzzle.origin + to) * 0.5)


func _process(delta: float) -> void:
	_age += delta
	var left := clampf(1.0 - _age / LIFE, 0.0, 1.0)
	if _light:
		_light.light_energy *= left
	if _flash:
		_flash.visible = _age < LIFE * 0.5
	if _streak:
		_streak.visible = _age < LIFE * 0.6
	if _age >= LIFE:
		queue_free()
