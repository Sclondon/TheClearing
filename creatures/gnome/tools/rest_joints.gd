extends SceneTree
## Writes where every joint of the Gnome is as it stands (its own units, Godot's
## axes) to creatures/gnome/tools/rest_gnome.json, for build_gnome.py to model
## round. Run it whenever the skeleton changes, then build the models again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/gnome/tools/rest_joints.gd


func _initialize() -> void:
	var one := Gnome.new()
	var j := one._joints(one._standing(), Vector3(0.0, -0.1, 1.0))
	var out := {"bones": Gnome.BONES, "head_size": Gnome.HEAD_SIZE, "ankle": _plain(Gnome.ANKLE),
		"hand_long": Gnome.HAND_LONG, "hat_wide": Gnome.HAT_WIDE, "hat_base": _plain(Gnome.HAT_BASE)}
	for key: String in j:
		out[key] = _plain(j[key])
	var file := FileAccess.open("res://creatures/gnome/tools/rest_gnome.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("wrote rest_gnome.json")
	one.free()
	quit()


## Vectors, bases and the rest as plain lists.
static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Basis:
		return [_plain(value.x), _plain(value.y), _plain(value.z)]
	if value is Transform3D:
		return {"basis": _plain(value.basis), "origin": _plain(value.origin)}
	if value is PackedVector3Array or value is PackedFloat32Array or value is Array:
		var list := []
		for item: Variant in value:
			list.append(_plain(item))
		return list
	if value is Dictionary:
		var made := {}
		for key: Variant in value:
			made[str(key)] = _plain(value[key])
		return made
	return value
