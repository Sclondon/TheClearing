extends SceneTree
## Writes where every joint of each kind of Baboon is as it stands (its own
## units, Godot's axes) to creatures/baboon/tools/rest_<kind>.json, with its
## build (Baboon.BUILDS), for build_baboon.py to model round. Run it whenever
## the skeleton or a build changes, then build the models again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/baboon/tools/rest_joints.gd


func _initialize() -> void:
	for kind: int in [Baboon.Kind.BABOON, Baboon.Kind.ALPHA]:
		var one := Baboon.new()
		one.kind = kind
		one._build = Baboon.BUILDS[kind].duplicate()
		var j := one._joints(one._standing(), Baboon.STANDING_GAZE)
		var out := {"bones": Baboon.BONES, "build": _plain(one._build)}
		for key: String in j:
			out[key] = _plain(j[key])
		var name := "alpha" if kind == Baboon.Kind.ALPHA else "baboon"
		var file := FileAccess.open("res://creatures/baboon/tools/rest_%s.json" % name, FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "\t"))
		file.close()
		print("wrote rest_%s.json" % name)
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
