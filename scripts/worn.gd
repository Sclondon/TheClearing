class_name Worn
extends Node3D
## Something a figure wears that is not part of its model: a backpack on its
## back, a god's head on its own. Each is a small model of its own
## (`models/worn/`, built by tools/build_props.py) that follows one bone of the
## figure's skeleton, so anything on the boy's rig can wear it: the boy, his
## brother, townspeople, and whatever else is built for that rig.
##
##     Worn.put_on(figure, &"helmet_anubis")     # a rig, a Figure, the Player, or a Skeleton3D
##     Worn.put_on(figure, &"backpack")
##     Worn.take_off(figure, &"helmet_anubis")   # or a slot: &"head", &"back"; or nothing, for all of it
##     Worn.wearing(figure, &"head")             # what is on that slot, or &""
##
## One thing to a slot: a second helmet takes the place of the first. It may be
## put on before the figure is in the level, and stays on if the figure's model
## is made again (the rig does that when the menu swaps the models): it looks
## for the skeleton afresh whenever the one it was on has gone.
##
## A helmet covers the head, so while one is worn the cap and the hair are not
## drawn (they would come through it). They are back when it is taken off.
##
## What the boy wears is in Settings (`helmet`, `backpack`); `Worn.dress_boy`
## puts that on him, and the menu calls it.

## What there is to wear: its model, the slot it takes, and the bone it hangs
## on (the first of these the figure has).
const THINGS := {
	&"backpack": {"model": "res://models/worn/backpack.glb", "slot": &"back", "bones": [&"chest", &"spine"]},
	&"helmet_anubis": {"model": "res://models/worn/helmet_anubis.glb", "slot": &"head", "bones": [&"head"]},
	&"helmet_horus": {"model": "res://models/worn/helmet_horus.glb", "slot": &"head", "bones": [&"head"]},
	&"helmet_sobek": {"model": "res://models/worn/helmet_sobek.glb", "slot": &"head", "bones": [&"head"]},
	&"helmet_bastet": {"model": "res://models/worn/helmet_bastet.glb", "slot": &"head", "bones": [&"head"]},
	&"helmet_thoth": {"model": "res://models/worn/helmet_thoth.glb", "slot": &"head", "bones": [&"head"]},
	&"helmet_khnum": {"model": "res://models/worn/helmet_khnum.glb", "slot": &"head", "bones": [&"head"]},
}
## The helmets, as the dresser offers them: [name, label]. The first is none.
const HELMETS := [["", "None"], ["helmet_anubis", "Anubis, the jackal"], ["helmet_horus", "Horus, the falcon"], ["helmet_sobek", "Sobek, the crocodile"],
	["helmet_bastet", "Bastet, the cat"], ["helmet_thoth", "Thoth, the ibis"], ["helmet_khnum", "Khnum, the ram"]]

## Everything is modelled to fit the boy. How it is fitted to a figure built
## otherwise, by the name of that figure's model and then by slot: how much
## bigger each way, and how far it is moved, in the bone's own space. A figure
## that is only the boy's model at another size (a townsperson) needs nothing:
## what it wears is scaled with it. Add a line for a new model that needs one,
## or pass a fit of your own to `put_on`.
const FITS := {
	# (broader in the chest than the boy, his shoulders lower over it, and his head set a little back)
	"brother": {&"back": {"scale": Vector3(1.06, 0.86, 1.0), "offset": Vector3(0.0, -0.012, 0.004)}, &"head": {"scale": Vector3(1.0, 1.0, 1.0), "offset": Vector3(0.0, 0.004, -0.006)}},
	# (a small skull, thrust forward on its neck)
	"mummy": {&"head": {"scale": Vector3(0.66, 0.66, 0.7), "offset": Vector3(0.0, 0.012, 0.03)}, &"back": {"scale": Vector3(0.9, 1.0, 1.0), "offset": Vector3(0.0, 0.03, 0.0)}},
}
## The materials that are metal, and shine as the gold of a pyramid's cap does.
const SHINY := {"gilt": true, "bronze_bright": true, "brass": true}

## What this is (one of THINGS), and the slot it takes.
var what: StringName
var slot: StringName
## A fit given to `put_on`, used instead of the one in FITS.
var fit := {}

var _host: Node
var _skeleton: Skeleton3D
var _model: Node3D
var _bone := -1
var _fit := Transform3D.IDENTITY
var _hidden: Array[MeshInstance3D] = []


## Puts `what` on `figure`: a CharacterRig, anything that has one under it (a
## Figure, the Player), or a Skeleton3D. Whatever was on the same slot comes
## off. `fit` may give a "scale" (a number or a Vector3) and an "offset" for a
## figure the thing does not sit right on. Returns the thing, or null if
## there is no such thing to wear.
static func put_on(figure: Node, what: StringName, fit := {}) -> Worn:
	if figure == null or not THINGS.has(what):
		return null
	var about: Dictionary = THINGS[what]
	take_off(figure, about["slot"])
	var thing := Worn.new()
	thing.name = "Worn_%s" % about["slot"]
	thing.what = what
	thing.slot = about["slot"]
	thing.fit = fit
	thing._host = figure
	figure.add_child(thing)
	return thing


## Takes off `what`: a thing by name, or whatever is on a slot (&"head",
## &"back"), or with nothing named everything.
static func take_off(figure: Node, what: StringName = &"") -> void:
	if figure == null:
		return
	for thing: Worn in worn_by(figure):
		if what == &"" or thing.what == what or thing.slot == what:
			thing._remove()


## What `figure` is wearing on `slot`, by name (&"" if nothing).
static func wearing(figure: Node, slot: StringName) -> StringName:
	for thing: Worn in worn_by(figure):
		if thing.slot == slot:
			return thing.what
	return &""


## Everything `figure` has on.
static func worn_by(figure: Node) -> Array[Worn]:
	var found: Array[Worn] = []
	if figure:
		for child in figure.get_children():
			if child is Worn and not child.is_queued_for_deletion():
				found.append(child)
	return found


## Puts on the boy what the menu has chosen for him (see Settings), and takes
## off what it has not. `rig` is his rig.
static func dress_boy(rig: Node) -> void:
	if rig == null:
		return
	if Settings.helmet != wearing(rig, &"head"):
		if Settings.helmet == "":
			take_off(rig, &"head")
		else:
			put_on(rig, Settings.helmet)
	if Settings.backpack != (wearing(rig, &"back") != &""):
		if Settings.backpack:
			put_on(rig, &"backpack")
		else:
			take_off(rig, &"back")


## Shades a model that has metal in it: the materials named in SHINY are drawn
## as gold is (`Toon.gold`), in their own colour. Call it after the model has
## been shaded in the usual way (`Toon.apply`), and not in the
## same frame: a material given and taken away again at once is one the
## renderer complains of.
static func shine(model: Node) -> void:
	# (one material for each metal in this model)
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null or not SHINY.has(original.resource_name):
				continue
			var key := original.albedo_color.to_html()
			if not made.has(key):
				made[key] = Toon.gold(original.albedo_color)
			part.set_surface_override_material(surface, made[key])


func _ready() -> void:
	# (it goes on being worn, and its hair stays hidden, while the menu has the game stopped)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# (after the rig has posed the figure for this frame)
	process_priority = 100
	if not is_instance_valid(_model):
		_attach()


func _process(_delta: float) -> void:
	# The figure's model has been made again, or was not there yet: find it.
	if not is_instance_valid(_model) or not is_instance_valid(_skeleton) or not _skeleton.is_inside_tree():
		_attach()
		if _model == null:
			return
	# It goes where its bone has gone.
	_model.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone) * _fit
	# (hidden with the figure: he is not drawn while he is inside something, say)
	_model.visible = _skeleton.is_visible_in_tree()
	# The rig shows the cap and the hair again whenever it is restyled.
	for part in _hidden:
		if is_instance_valid(part) and part.visible:
			part.visible = false


## Finds the figure's skeleton and the bone the model follows. The model is
## kept under this node, not under the figure's: the rig reshades everything
## under its figure whenever he is restyled, and would take the gold off it.
func _attach() -> void:
	_hidden.clear()
	_skeleton = _find_skeleton()
	if _skeleton == null:
		return
	var about: Dictionary = THINGS[what]
	_bone = -1
	for candidate: StringName in about["bones"]:
		_bone = _skeleton.find_bone(candidate)
		if _bone >= 0:
			break
	if _bone < 0 or not ResourceLoader.exists(about["model"]):
		return
	var fitted: Dictionary = fit if not fit.is_empty() else FITS.get(_model_name(), {}).get(slot, {})
	var size: Variant = fitted.get("scale", 1.0)
	# (the bone rests where the model's own origin is, so the model needs only its fit)
	_fit = Transform3D(Basis.from_scale(size if size is Vector3 else Vector3.ONE * float(size)), fitted.get("offset", Vector3.ZERO))
	if not is_instance_valid(_model):
		_model = (load(about["model"]) as PackedScene).instantiate() as Node3D
		_model.top_level = true
		add_child(_model)
		# Shaded as the figure is, and its metal as gold: each surface is given
		# its one material, once.
		for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
			for surface in part.mesh.get_surface_count():
				var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
				if original and not SHINY.has(original.resource_name):
					part.set_surface_override_material(surface, Toon._material(original.albedo_color))
		shine(_model)
	if is_inside_tree() and _skeleton.is_inside_tree():
		_model.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone) * _fit
	if slot == &"head":
		for part: MeshInstance3D in _skeleton.find_children("*", "MeshInstance3D", true, false):
			var called := String(part.name)
			if called.ends_with("_cap") or called.ends_with("_crown") or called.ends_with("_forelock") or called.contains("_hair"):
				_hidden.append(part)
				part.visible = false


func _remove() -> void:
	_hidden.clear()
	# (the rig knows what of the cap and the hair should show)
	var rig := _rig()
	if rig and slot == &"head":
		rig.call(&"restyle")
	if get_parent():
		get_parent().remove_child(self)
	queue_free()


## The figure's skeleton: its own if it is one, the one its rig is posing if it
## has a rig, or else the first there is under it.
func _find_skeleton() -> Skeleton3D:
	if _host is Skeleton3D:
		return _host
	var rig := _rig()
	if rig and &"_skeleton" in rig:
		var posed: Variant = rig.get(&"_skeleton")
		return posed as Skeleton3D if is_instance_valid(posed) else null
	var found := _host.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


## The rig that poses the figure, if it has one.
func _rig() -> Node:
	if _host == null:
		return null
	if _host.has_method(&"restyle"):
		return _host
	for child in _host.find_children("*", "Node3D", true, false):
		if child.has_method(&"restyle"):
			return child
	return null


## The name of the model the skeleton belongs to: `brother` for
## models/brother.glb and for its demade brother_lo.glb.
func _model_name() -> String:
	var node: Node = _skeleton
	while node and node != _host:
		if node.scene_file_path != "":
			return node.scene_file_path.get_file().get_basename().trim_suffix("_lo")
		node = node.get_parent()
	return ""
