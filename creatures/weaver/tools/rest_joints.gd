extends SceneTree
## Writes where every joint of the Weaver is as it stands (its own units, Godot's
## axes) to creatures/weaver/tools/rest_weaver.json, for build_weaver.py to model
## round. Run it whenever the skeleton changes, then build the models again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/weaver/tools/rest_joints.gd


func _initialize() -> void:
	var one := Weaver.new()
	var j := one._joints(one._standing(), Vector3(0.0, -0.2, 1.0))
	var out := {"bones": Weaver.BONES, "head_size": _plain(Weaver.HEAD_SIZE), "hand_long": Weaver.HAND_LONG}
	for key: String in j:
		out[key] = _plain(j[key])
	var file := FileAccess.open("res://creatures/weaver/tools/rest_weaver.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("wrote rest_weaver.json")
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
