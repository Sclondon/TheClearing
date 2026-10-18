extends SceneTree
## Writes where every joint of the SpiderMonkey is as it stands (metres at size
## 1, Godot's axes) to creatures/spider_monkey/tools/rest_spider_monkey.json,
## for build_spider_monkey.py to model round. Run it whenever the skeleton
## changes, then build the models again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/spider_monkey/tools/rest_joints.gd


func _initialize() -> void:
	var one := SpiderMonkey.new()
	var j := one._joints(one._standing(), Vector3(0.0, 0.0, 1.0))
	var out := {"bones": SpiderMonkey.BONES, "head_size": SpiderMonkey.HEAD_SIZE, "hinge": _plain(SpiderMonkey.HINGE),
		"hand_long": SpiderMonkey.HAND_LONG, "foot_long": SpiderMonkey.FOOT_LONG, "palm": SpiderMonkey.PALM,
		"sole": SpiderMonkey.SOLE, "tail_steps": _plain(SpiderMonkey.TAIL_STEPS)}
	for key: String in j:
		out[key] = _plain(j[key])
	var file := FileAccess.open("res://creatures/spider_monkey/tools/rest_spider_monkey.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("wrote rest_spider_monkey.json")
	one.free()
	quit()


## Vectors, bases and the rest as plain lists.
static func _plain(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
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
