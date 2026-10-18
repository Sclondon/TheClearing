extends SceneTree
## Writes where every joint of a LizardPerson is as modelled (metres, Godot's
## axes) to creatures/lizard_person/tools/rest.json, for build_lizard_person.py
## to model round. Run it whenever the skeleton changes, then build the models
## again:
##
##     godot --headless --audio-driver Dummy --path . -s res://creatures/lizard_person/tools/rest_joints.gd


func _initialize() -> void:
	var one := LizardPerson.new()
	var j := one._joints(one._rest_pose(), LizardPerson.REST_GAZE)
	var out := {"bones": LizardPerson.BONES, "tail_steps": LizardPerson.TAIL_STEPS, "lid_at": _plain(LizardPerson.LID_AT),
		"tongue_at": _plain(LizardPerson.TONGUE_AT), "dewlap_at": _plain(LizardPerson.DEWLAP_AT), "jaw_at": _plain(LizardPerson.JAW_AT)}
	for key: String in j:
		out[key] = _plain(j[key])
	var file := FileAccess.open("res://creatures/lizard_person/tools/rest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	print("wrote rest.json")
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
