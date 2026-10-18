extends SceneTree
## Writes where every joint of the Imp is as it stands (its own units, Godot's
## axes) to creatures/imp/tools/rest_imp.json, for build_imp.py to model round;
## and, for the swarm's model, each bone as it is posed on all fours
## (`fours_bones`: the bone transforms that take the standing imp to a
## scuttle). Run it whenever the skeleton changes, then build the models again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/imp/tools/rest_joints.gd


func _initialize() -> void:
	var one := Imp.new()
	var gaze := Vector3(0.0, -0.15, 1.0)
	var j := one._joints(one._standing(), gaze)
	var out := {"bones": Imp.BONES, "head_size": Imp.HEAD_SIZE, "hinge": _plain(Imp.HINGE), "ankle": _plain(Imp.ANKLE),
		"hand_long": Imp.HAND_LONG, "ear_long": Imp.EAR_LONG}
	for key: String in j:
		out[key] = _plain(j[key])
	# Each bone standing, and on all fours (mid-stride, head up), as transforms.
	var rest := one._bone_globals(j)
	var fours := one._fours_pose()
	fours.head_up = 0.1
	var posed := one._bone_globals(one._joints(fours, Vector3(0.0, 0.1, 1.0)))
	var moves := []
	for b in Imp.BONES.size():
		moves.append(_plain(posed[b] * rest[b].affine_inverse()))
	out["fours_bones"] = moves
	out["fours_joints"] = _plain(one._joints(fours, Vector3(0.0, 0.1, 1.0)))
	var file := FileAccess.open("res://creatures/imp/tools/rest_imp.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("wrote rest_imp.json")
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
