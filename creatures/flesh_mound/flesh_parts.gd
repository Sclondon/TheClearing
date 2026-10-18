class_name FleshParts
## The people the flesh mound (FleshMound) is grown from, and the means to put
## them together and move them. Nothing here knows about the game.
##
## THE PARTS. `boy`: the character controller's boy (models/boy.glb, his bare
## body: the long-sleeved body, hands, feet and the blank mask of a head),
## whole, every bone of his. And human parts modelled in Blender by
## tools/build_parts.py into models/parts.glb (and parts_lo.glb, fewer
## triangles): `arm_r`/`arm_l` (a man's arm, shoulder to fingertips, every
## finger in three joints, nails), `long_r`/`long_l` (the same stretched
## gaunt, twice as long), `leg_r`/`leg_l` (hip to toes) and `torso` (a wasted
## body, ribs and spine showing, a face with no mouth). `low_poly` takes
## boy_lo.glb and parts_lo.glb instead.
##
## PUTTING THEM TOGETHER. A `Build` takes copies of parts, each placed by a
## transform (a uniform scale is allowed), and makes of them one mesh skinned
## to one Skeleton3D: one draw for all of them. `Build.add` gives a `Copy`:
## its `body` (hips or pelvis, spine and head, if it has them) and its
## `chains` (each arm and leg: "arm_l", "leg_r"... or "arm"/"leg" for a part
## that is only that), to be posed.
##
## MOVING THEM. A `Chain` (an arm or a leg) is laid from its root to a point
## by `reach_to` (two bones by IK, the elbow or knee out towards a pole, the
## hand or foot turned as asked); `hand` closes, claws and spreads the fingers.
## A `Body` is put by `pose` (where its hips are and how it turns, a bend of
## the back, a loll of the head), which gives where its chest is for its arms.
## All in the skeleton's space.
##
## THE LOOK (`material()`): dead skin grown together, pallid and waxy (grey,
## ashen or jaundiced, each copy its own), mottled purple where the blood has
## settled, blue veins under it, bruises, yellowed nails, the ends of fingers
## and toes livid, the eyes' sockets dark, the boy's mask of a face paler and
## smooth as wax; towards the root of a copy where it grows out of the flesh
## (`meat_from`), a puckered, folded, scar-dark join; boils of pus and weeping
## patches (more where it is swollen). Cel shaded in hard bands, a waxy sheen,
## wet glints where it weeps. Vertex attributes: COLOR the masks (r nail, g
## bruise, b hollow, a mask face), UV (how far along the part from its root,
## where the join is), UV2 (each copy's seed, how swollen it is), CUSTOM0 the
## point as built (so the marks stay put on the skin as it moves).

const MODELS := "res://creatures/flesh_mound/models/parts%s.glb"
const BOY := "res://models/boy%s.glb"
## The meshes of the boy that make his bare body (the long-sleeved body,
## hands and feet, the blank head), after the prefix "boy" or "boy_lo".
const BOY_MESHES := ["", "_body__long", "_head__base"]

## Use the low-detail models for every part made from now on.
static var low_poly := false

static var _templates := {}
static var _material: ShaderMaterial


## One part as modelled: its vertices at rest in its own space, its bones.
class Template:
	var name := ""
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	## Four bones and four weights to a vertex (the template's own bone numbers).
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var bone_names := PackedStringArray()
	var parents := PackedInt32Array()
	## Each bone's rest in the part's space, and in its parent's.
	var rests: Array[Transform3D] = []
	var locals: Array[Transform3D] = []

	func bone(bone_name: String) -> int:
		return bone_names.find(bone_name)

	func at(bone_name: String) -> Vector3:
		return rests[bone(bone_name)].origin


## A part (read from its model once, then kept).
static func template(part: String, low := low_poly) -> Template:
	var key := part + ("_lo" if low else "")
	if _templates.has(key):
		return _templates[key]
	var t := Template.new()
	t.name = part
	var root: Node
	var meshes: Array[MeshInstance3D] = []
	if part == "boy":
		root = (load(BOY % ("_lo" if low else "")) as PackedScene).instantiate()
		var prefix := "boy_lo" if low else "boy"
		for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for suffix: String in BOY_MESHES:
				if node.name == prefix + suffix:
					meshes.append(node)
	else:
		root = (load(MODELS % ("_lo" if low else "")) as PackedScene).instantiate()
		for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if node.name == part:
				meshes.append(node)
	assert(not meshes.is_empty(), "no part %s" % part)
	var skeleton := meshes[0].get_parent() as Skeleton3D
	for b in skeleton.get_bone_count():
		t.bone_names.append(skeleton.get_bone_name(b))
		t.parents.append(skeleton.get_bone_parent(b))
		t.rests.append(skeleton.get_bone_global_rest(b))
		t.locals.append(skeleton.get_bone_rest(b))
	for found in meshes:
		_read_mesh(t, found, skeleton, part == "boy")
	root.free()
	_templates[key] = t
	return t


## Adds a skinned mesh's surfaces to a template: its vertices in the part's
## space at rest, its weights by the skeleton's bones, its masks (the boy's
## from what each surface is: his head is the mask, his feet bruised).
static func _read_mesh(t: Template, found: MeshInstance3D, skeleton: Skeleton3D, boy: bool) -> void:
	var skin := found.skin
	var bind_bone := PackedInt32Array()
	var to_part: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = skeleton.find_bone(skin.get_bind_name(i))
		bind_bone.append(b)
		to_part.append(t.rests[b] * skin.get_bind_pose(i))
	for s in found.mesh.get_surface_count():
		var arrays := found.mesh.surface_get_arrays(s)
		var material := found.mesh.surface_get_material(s)
		var what := material.resource_name if material else ""
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours = arrays[Mesh.ARRAY_COLOR]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var base := t.verts.size()
		var mask := Color(0, 0, 0, 0)
		if boy:
			if String(found.name).contains("head"):
				mask = Color(0, 0, 0, 1)
			elif what == "boots":
				mask = Color(0, 0.3, 0, 0)
		for v in verts.size():
			var xform := to_part[bones[v * per]]
			t.verts.append(xform * verts[v])
			t.normals.append((xform.basis * normals[v]).normalized())
			t.colours.append(colours[v] if not boy and colours != null and colours.size() > v else mask)
			var total := 0.0
			for k in 4:
				total += weights[v * per + k]
			for k in 4:
				t.bones.append(bind_bone[bones[v * per + k]])
				t.weights.append(weights[v * per + k] / maxf(total, 0.0001))
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			t.indices.append(base + index)


## Copies of parts, placed, to be made into one skinned mesh and skeleton.
class Build:
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	## Each bone's rest in the skeleton's space.
	var rests: Array[Transform3D] = []
	var copies: Array[Copy] = []
	var _verts := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _colours := PackedColorArray()
	var _uvs := PackedVector2Array()
	var _uv2s := PackedVector2Array()
	var _custom := PackedFloat32Array()
	var _bones := PackedInt32Array()
	var _weights := PackedFloat32Array()
	var _indices := PackedInt32Array()
	var _mesh: ArrayMesh

	## Puts in a copy of `part` placed by `place` (its space to the skeleton's).
	## Towards its root, up to `meat_from` along it (metres, the part's own: for
	## the boy, how far from his hips), it is a puckered join into the flesh;
	## `pus` (0..1) how swollen it is; `low` takes its low-detail model. Gives the copy.
	func add(part: String, place: Transform3D, meat_from := -10.0, pus := 0.0, seed := 0.0, low := FleshParts.low_poly) -> Copy:
		var t := FleshParts.template(part, low)
		var first := names.size()
		for b in t.bone_names.size():
			names.append("%d_%s" % [copies.size(), t.bone_names[b]])
			parents.append(first + t.parents[b] if t.parents[b] >= 0 else -1)
			rests.append(place * t.rests[b])
		var base := _verts.size()
		var basis := place.basis
		# (how far along it a point is: from the root, the way the part grows)
		var root := t.rests[0].origin
		var boy := part == "boy"
		for i in t.verts.size():
			var at := place * t.verts[i]
			_verts.append(at)
			_normals.append((basis * t.normals[i]).normalized())
			_colours.append(t.colours[i])
			# (a limb along its length; a boy by how far from his hips)
			_uvs.append(Vector2((t.verts[i] - root).length() if boy else t.verts[i].y - root.y, meat_from))
			_uv2s.append(Vector2(seed, pus))
			_custom.append_array([at.x, at.y, at.z, 0.0])
			for k in 4:
				_bones.append(first + t.bones[i * 4 + k])
				_weights.append(t.weights[i * 4 + k])
		for index in t.indices:
			_indices.append(base + index)
		var copy := Copy.new(t, first, place)
		copies.append(copy)
		return copy

	func make() -> ArrayMesh:
		if _mesh != null:
			return _mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_COLOR] = _colours
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
		arrays[Mesh.ARRAY_CUSTOM0] = _custom
		arrays[Mesh.ARRAY_BONES] = _bones
		arrays[Mesh.ARRAY_WEIGHTS] = _weights
		arrays[Mesh.ARRAY_INDEX] = _indices
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		# (what was gathered for it is not needed again)
		_verts = PackedVector3Array()
		_normals = PackedVector3Array()
		_colours = PackedColorArray()
		_uvs = PackedVector2Array()
		_uv2s = PackedVector2Array()
		_custom = PackedFloat32Array()
		_bones = PackedInt32Array()
		_weights = PackedFloat32Array()
		_indices = PackedInt32Array()
		return _mesh

	## A new skeleton with every bone put in, at rest.
	func skeleton() -> Skeleton3D:
		var skeleton := Skeleton3D.new()
		for b in names.size():
			skeleton.add_bone(names[b])
		for b in names.size():
			skeleton.set_bone_parent(b, parents[b])
			skeleton.set_bone_rest(b, rests[b] if parents[b] < 0 else rests[parents[b]].affine_inverse() * rests[b])
		skeleton.reset_bone_poses()
		return skeleton

	## A MeshInstance3D of the mesh skinned to `skeleton` (put it in as the skeleton's child).
	func skin_for(skeleton: Skeleton3D) -> MeshInstance3D:
		var body := MeshInstance3D.new()
		body.mesh = make()
		body.skin = skeleton.create_skin_from_rest_transforms()
		body.skeleton = NodePath("..")
		body.material_override = FleshParts.material()
		return body


## One copy of a part in a Build: its body and its chains, and whatever its
## owner keeps with it (`data`).
class Copy:
	var part := ""
	var first := 0
	var place := Transform3D.IDENTITY
	var size := 1.0
	var body: Body
	var chains := {}
	var data := {}

	func _init(t: Template, first_bone: int, placed: Transform3D) -> void:
		part = t.name
		first = first_bone
		place = placed
		size = placed.basis.get_scale().x
		if t.bone("hips") >= 0:
			body = Body.new(t, first, placed, ["hips", "spine", "chest", "neck", "head"])
			for side: String in ["l", "r"]:
				var s := 1.0 if side == "l" else -1.0
				var arm := Chain.new(t, first, placed, ["upper_arm_" + side, "forearm_" + side, "hand_" + side], true, s)
				# (his palms face down as he was made, his fingers along his arm, his elbows bend forward)
				arm.set_rest(Vector3.BACK, Vector3.DOWN, t.at("hand_" + side).direction_to(t.at("finger1a_" + side)))
				var fingers := []
				for f in 4:
					fingers.append(["finger%da_%s" % [f, side], "finger%db_%s" % [f, side], "finger%dc_%s" % [f, side]])
				arm.set_fingers(t, ["thumba_" + side, "thumbb_" + side], fingers)
				chains["arm_" + side] = arm
				var leg := Chain.new(t, first, placed, ["thigh_" + side, "shin_" + side, "foot_" + side], false, s)
				leg.set_rest(Vector3.BACK, Vector3.DOWN, Vector3.BACK)
				leg.toes = t.bone("toe_" + side)
				leg.helpers = [t.bone("knee_" + side), t.bone("seat_" + side)]
				chains["leg_" + side] = leg
		elif t.bone("pelvis") >= 0:
			body = Body.new(t, first, placed, ["pelvis", "chest", "head"])
		elif t.bone("upper") >= 0:
			var arm := Chain.new(t, first, placed, ["upper", "fore", "hand"], true, -1.0 if part.ends_with("_l") else 1.0)
			arm.set_rest(Vector3.BACK, Vector3.BACK, Vector3.UP)
			var fingers := []
			for finger: String in ["index", "middle", "ring", "pinky"]:
				fingers.append([finger + "_1", finger + "_2", finger + "_3"])
			arm.set_fingers(t, ["thumb_1", "thumb_2", "thumb_3"], fingers)
			chains["arm"] = arm
		elif t.bone("thigh") >= 0:
			var leg := Chain.new(t, first, placed, ["thigh", "shin", "foot"], false, -1.0 if part.ends_with("_l") else 1.0)
			# (the sole of the part faces on down the leg, the toes forward)
			leg.set_rest(Vector3.BACK, Vector3.UP, Vector3.BACK)
			leg.toes = t.bone("toes")
			chains["leg"] = leg


## A spine of bones from the hips (or pelvis) to the head.
class Body:
	var bones := PackedInt32Array()
	var locals: Array[Transform3D] = []
	## The axis each bends forward about, and turns about, in its own space.
	var bend_axis: Array[Vector3] = []
	var turn_axis: Array[Vector3] = []
	var size := 1.0
	var place := Transform3D.IDENTITY
	var _rest_rot: Basis

	func _init(t: Template, first: int, placed: Transform3D, names: Array) -> void:
		place = placed
		size = placed.basis.get_scale().x
		_rest_rot = t.rests[t.bone(names[0])].basis.orthonormalized()
		for bone_name: String in names:
			var b := t.bone(bone_name)
			bones.append(first + b)
			locals.append(t.locals[b])
			var rest := t.rests[b].basis.orthonormalized()
			bend_axis.append((rest.inverse() * Vector3.RIGHT).normalized())
			turn_axis.append((rest.inverse() * Vector3.UP).normalized())

	## Puts its root at `root` turned by `frame` (its own axes: Y up its back,
	## Z its front), bends each bone after the root forward by `bend`, the head
	## by `head` more and turned by `turn`. Gives the global transform
	## (skeleton space) of each of its bones in order.
	func pose(skeleton: Skeleton3D, root: Vector3, frame: Basis, bend := 0.0, head := 0.0, turn := 0.0) -> Array[Transform3D]:
		var global := Transform3D((frame * _rest_rot) * size, root)
		skeleton.set_bone_pose_position(bones[0], root)
		skeleton.set_bone_pose_rotation(bones[0], global.basis.get_rotation_quaternion())
		var out: Array[Transform3D] = [global]
		for i in range(1, bones.size()):
			var last := i == bones.size() - 1
			var q := locals[i].basis.get_rotation_quaternion() * Quaternion(bend_axis[i], bend + (head if last else 0.0))
			if last and turn != 0.0:
				q = q * Quaternion(turn_axis[i], turn)
			skeleton.set_bone_pose_rotation(bones[i], q)
			global = global * Transform3D(Basis(q), locals[i].origin)
			out.append(global)
		return out


## An arm or a leg: three bones (upper, lower, hand or foot) that need not be
## each other's children (the boy's legs hang from his hips), fingers or toes.
class Chain:
	var bones := PackedInt32Array()
	var parents := PackedInt32Array()
	var arm := true
	var side := 1.0
	var size := 1.0
	var upper_long := 0.0
	var lower_long := 0.0
	var end_long := 0.0
	var toes := -1
	var helpers := []
	var data := {}
	## The rest, in the part's space: where each joint is, each bone's turn
	## against the frame the chain lies in (Y along it, Z the way its middle
	## joint bends), and the hand's (foot's) against its own frame.
	var _joints := PackedVector3Array()
	var _k: Array[Basis] = []
	var _end_k: Basis
	var _rest_part: Array[Basis] = []
	var _template: Template
	var _first := 0
	var _finger_bones: Array[PackedInt32Array] = []
	var _finger_rest: Array = []
	var _finger_curl: Array = []
	var _finger_spread: Array = []

	func _init(t: Template, first: int, placed: Transform3D, names: Array, is_arm: bool, s: float) -> void:
		_template = t
		_first = first
		arm = is_arm
		side = s
		size = placed.basis.get_scale().x
		for bone_name: String in names:
			var b := t.bone(bone_name)
			bones.append(first + b)
			parents.append(first + t.parents[b] if t.parents[b] >= 0 else -1)
			_joints.append(t.rests[b].origin)
			_rest_part.append(t.rests[b].basis.orthonormalized())
		upper_long = _joints[0].distance_to(_joints[1]) * size
		lower_long = _joints[1].distance_to(_joints[2]) * size
		end_long = (0.1 if arm else 0.14) * size * (1.0 if t.name != "boy" else 0.75)

	## How it lies at rest: `bend_to` the way its middle joint bends (an arm's
	## front; a leg's front, its knee bending the other way), and its hand's
	## palm (or foot's sole) and the way its fingers (toes) point.
	func set_rest(bend_to: Vector3, palm: Vector3, fingers: Vector3) -> void:
		var along := _joints[0].direction_to(_joints[1])
		var frame := FleshParts.frame(along, bend_to)
		_k = [frame.inverse() * _rest_part[0], frame.inverse() * _rest_part[1]]
		var end_frame := FleshParts.frame(fingers, palm) if arm else FleshParts.frame(palm, fingers)
		_end_k = end_frame.inverse() * _rest_part[2]

	func set_fingers(t: Template, thumb: Array, fingers: Array) -> void:
		var palm_at := t.at(fingers[0][0]).lerp(t.at(fingers[fingers.size() - 1][0]), 0.5)
		# (the palm's way in the part's space: the hand's frame's Z at rest)
		var palm_way := (_rest_part[2] * _end_k.inverse() * Vector3.BACK).normalized()
		var all := [thumb] + fingers
		for f in all.size():
			var names: Array = all[f]
			var ids := PackedInt32Array()
			var rest_q: Array[Quaternion] = []
			var curl: Array[Vector3] = []
			var spread: Array[Vector3] = []
			for k in names.size():
				var b := t.bone(names[k])
				ids.append(_first + b)
				rest_q.append(t.locals[b].basis.get_rotation_quaternion())
				var tip := t.at(names[k + 1]) if k + 1 < names.size() else t.at(names[k]) + (t.at(names[k]) - t.at(names[k - 1]))
				var along := t.at(names[k]).direction_to(tip)
				# (fingers curl to the palm; the thumb across it, to the fingers)
				var to := palm_way if f > 0 else (palm_way + t.at(names[0]).direction_to(palm_at) * 1.2).normalized()
				to = (to - along * to.dot(along)).normalized()
				var rest := t.rests[b].basis.orthonormalized()
				curl.append((rest.inverse() * along.cross(to)).normalized())
				spread.append((rest.inverse() * palm_way).normalized())
			_finger_bones.append(ids)
			_finger_rest.append(rest_q)
			_finger_curl.append(curl)
			_finger_spread.append(spread)

	## Lays it from its root at `root` so that its wrist (ankle) is at `to`,
	## the elbow (knee) out towards `pole`; the hand along `end_along` with its
	## palm facing `palm` (the foot with its sole facing `palm`, toes along
	## `end_along`). `parent` is the global pose of its root's parent bone (the
	## chest for an arm, the hips for a leg; identity for a part with none).
	func reach_to(skeleton: Skeleton3D, root: Vector3, to: Vector3, pole: Vector3, end_along: Vector3, palm: Vector3, parent := Transform3D.IDENTITY) -> void:
		var knee := FleshParts.two_bone(root, to, upper_long, lower_long, pole)
		var up := (knee - root).normalized()
		var down := to - knee
		var down_dir := down.normalized() if down.length() > 0.0001 else up
		to = knee + down_dir * lower_long
		var bend_way := down_dir - up * down_dir.dot(up)
		if bend_way.length() < 0.01:
			bend_way = -(pole - up * pole.dot(up))
		if not arm:
			bend_way = -bend_way
		var upper := FleshParts.frame(up, bend_way)
		var lower := FleshParts.frame(down_dir, upper.x.cross(down_dir))
		if arm:
			# (the forearm turned halfway to where the palm is to face)
			var face := palm - down_dir * palm.dot(down_dir)
			if face.length() > 0.01:
				lower = FleshParts.frame(down_dir, lower.z.lerp(face.normalized(), 0.5))
		var end_frame := FleshParts.frame(end_along, palm) if arm else FleshParts.frame(palm, end_along)
		var g0 := Transform3D((upper * _k[0]) * size, root)
		var g1 := Transform3D((lower * _k[1]) * size, knee)
		var g2 := Transform3D((end_frame * _end_k) * size, to)
		var globals: Array[Transform3D] = [g0, g1, g2]
		for i in 3:
			var parent_global := parent
			if i > 0 and parents[i] == bones[i - 1]:
				parent_global = globals[i - 1]
			var local := parent_global.affine_inverse() * globals[i]
			skeleton.set_bone_pose_position(bones[i], local.origin)
			skeleton.set_bone_pose_rotation(bones[i], local.basis.get_rotation_quaternion())
		# The boy's knee and seat bones (they shape his knee and behind): halfway between.
		if helpers.size() == 2 and helpers[0] >= 0:
			var half := Transform3D((upper.slerp(lower, 0.5) * _k[0]) * size, knee)
			var local := parent.affine_inverse() * half
			skeleton.set_bone_pose_position(_first + helpers[0], local.origin)
			skeleton.set_bone_pose_rotation(_first + helpers[0], local.basis.get_rotation_quaternion())
			local = parent.affine_inverse() * g0
			skeleton.set_bone_pose_position(_first + helpers[1], local.origin)
			skeleton.set_bone_pose_rotation(_first + helpers[1], Quaternion.IDENTITY.slerp(local.basis.get_rotation_quaternion(), 0.5))

	## Where its root is, from its parent's global pose (INF for a part with no parent).
	func root_from(parent: Transform3D) -> Vector3:
		if parents[0] < 0:
			return Vector3.INF
		return parent * _template.locals[bones[0] - _first].origin

	## The hand: `grip` closes it (0 open, 1 a fist), `claw` bends the ends of the
	## fingers and not their roots, `spread` fans them (below 0 they bend back),
	## `jitter` (0..1) shakes each finger on its own at time `time`.
	func hand(skeleton: Skeleton3D, grip: float, claw := 0.0, spread := 0.0, time := 0.0, jitter := 0.0) -> void:
		for f in _finger_bones.size():
			var ids: PackedInt32Array = _finger_bones[f]
			var own := grip + jitter * 0.35 * sin(time * (7.0 + f * 2.3) + f * 1.7 + _first)
			var fan := 0.0 if f == 0 else (f - 2.5) * 0.12 * spread * side
			for k in ids.size():
				var angle: float
				if f == 0:
					angle = [own * 0.35 - spread * 0.15, own * 0.7 + claw * 0.3, own * 0.8 + claw * 0.4][mini(k, 2)]
				elif k == 0:
					angle = own * 1.25 * (1.0 - claw * 0.7) - maxf(-spread, 0.0) * 0.3
				else:
					angle = (own * 1.05 + claw * 0.9) * (1.15 if k == 1 else 0.85)
				var q: Quaternion = _finger_rest[f][k] * Quaternion(_finger_curl[f][k], angle)
				if k == 0 and fan != 0.0:
					q = q * Quaternion(_finger_spread[f][k], fan)
				skeleton.set_bone_pose_rotation(ids[k], q)

	## Curls the toes (or lifts them, below 0).
	func curl_toes(skeleton: Skeleton3D, angle: float) -> void:
		if toes < 0:
			return
		var rest := _template.locals[toes]
		skeleton.set_bone_pose_rotation(_first + toes, rest.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angle))


## Where the middle joint goes, from `a` to reach `c` with bones `l1` and
## `l2` long, bending out towards `pole` (a direction). If `c` is too far it
## is reached for in a straight line.
static func two_bone(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := c - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.0005)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.UP
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var out := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var side := pole - dir * pole.dot(dir)
	if side.length() < 0.0001:
		side = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.UP)
	return a + dir * along + side.normalized() * out


## A frame (as a Basis): Y along `y`, Z as near `z` as can be square to it.
static func frame(y: Vector3, z: Vector3) -> Basis:
	var yy := y.normalized()
	var zz := z - yy * z.dot(yy)
	if zz.length() < 0.0001:
		zz = yy.cross(Vector3.RIGHT if absf(yy.x) < 0.9 else Vector3.UP)
	zz = zz.normalized()
	return Basis(yy.cross(zz), yy, zz)


# --- The look ---

const LIGHT := """
void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, 0.7);
	DIFFUSE_LIGHT += (lit * 0.85 + core * 0.15) * LIGHT_COLOR / PI;
	// Light comes through the thin skin: its shadow side glows a dull pink.
	float behind = clamp(dot(VIEW, -LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += (1.0 - lit) * through * (0.06 + 0.2 * behind * behind) * LIGHT_COLOR / PI;
	// A waxy sheen, and hard wet glints where it weeps.
	vec3 half_way = normalize(LIGHT + VIEW);
	vec3 n = normalize(mix(form, NORMAL, 0.35));
	float shine = max(dot(n, half_way), 0.0);
	float glint = cut(pow(shine, 80.0), 0.5) * wet;
	float wax = cut(pow(shine, 24.0), 0.5);
	SPECULAR_LIGHT += (glint * 0.6 + wax * 0.05) * lit * reach * LIGHT_COLOR;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.8) * lit * 0.1 * LIGHT_COLOR * vec3(0.85, 0.82, 0.75);
}
"""

const COMMON := """
uniform vec3 pale : source_color = vec3(0.5, 0.48, 0.45);
uniform vec3 ashen : source_color = vec3(0.42, 0.43, 0.45);
uniform vec3 jaundiced : source_color = vec3(0.5, 0.46, 0.32);
uniform vec3 livid : source_color = vec3(0.33, 0.22, 0.32);
uniform vec3 bruise : source_color = vec3(0.22, 0.12, 0.2);
uniform vec3 nail : source_color = vec3(0.5, 0.45, 0.32);
uniform vec3 hollow : source_color = vec3(0.07, 0.05, 0.06);
uniform vec3 blue_vein : source_color = vec3(0.26, 0.29, 0.42);
uniform vec3 wax_face : source_color = vec3(0.62, 0.6, 0.55);
uniform vec3 scar : source_color = vec3(0.34, 0.16, 0.2);
uniform vec3 pus : source_color = vec3(0.72, 0.64, 0.36);
uniform vec3 weep : source_color = vec3(0.52, 0.5, 0.28);
uniform vec3 through : source_color = vec3(0.42, 0.3, 0.26);
uniform float wrap = 0.35;
uniform float bump = 0.08;

varying vec3 obj;
varying float wet;
varying vec3 form;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// Dead skin: `kind` picks pale, ashen or jaundiced; purple where the blood has
// settled; blue veins under it; bruises.
vec3 skin_colour(vec3 p, float kind, float pixel) {
	vec3 c = kind < 0.45 ? mix(pale, ashen, kind / 0.45) : mix(ashen, jaundiced, (kind - 0.45) / 0.55);
	float blotch = noise3(p * 2.2 + kind * 40.0) * 0.65 + noise3(p * 7.0) * 0.35;
	c = mix(c, livid, smoothstep(0.56, 0.78, blotch) * 0.5);
	float spots = noise3(p * 11.0 + 2.0);
	c = mix(c, bruise, smoothstep(0.76, 0.86, spots) * 0.55 * smoothstep(0.4, 0.6, blotch));
	float v = abs(noise3(p * 3.5 + vec3(1.0, kind * 9.0, 3.0)) - 0.5);
	float veins = (1.0 - smoothstep(0.02 - pixel, 0.02 + pixel, v)) * clamp(0.03 / pixel, 0.0, 1.0);
	c = mix(c, blue_vein, veins * 0.55 * smoothstep(0.3, 0.7, noise3(p * 0.9 + 5.0)));
	c *= 0.94 + 0.06 * noise3(p * 40.0);
	return c;
}

// Boils and blisters of pus, and patches where it weeps: how much of each
// here (x boil, y weeping), `amount` how many.
vec2 pustules(vec3 p, float amount) {
	vec3 cell = floor(p);
	vec3 inside = p - cell;
	float best = 9.0;
	vec3 at = vec3(hash3(cell), hash3(cell + 7.1), hash3(cell + 3.3)) * 0.6 + 0.2;
	float size = 0.12 + 0.18 * hash3(cell + 11.0);
	float keep = step(1.0 - amount, hash3(cell + 19.0));
	best = mix(9.0, length(inside - at) / size, keep);
	float boil = 1.0 - smoothstep(0.8, 1.0, best);
	float weeping = smoothstep(0.64, 0.72, noise3(p * 0.5 + 31.0)) * amount;
	return vec2(boil, weeping);
}
"""

const SHADER := """
shader_type spatial;
render_mode cull_back;
%s
varying vec4 masks;
varying vec2 along;
varying float kind;
varying float swollen;

void vertex() {
	obj = CUSTOM0.xyz;
	masks = COLOR;
	along = UV;
	kind = UV2.x;
	swollen = UV2.y;
}

void fragment() {
	vec3 p = obj;
	float pixel = max(length(fwidth(p)), 0.0002);
	vec3 c = skin_colour(p, kind, pixel);
	// The boy's mask of a face: paler, smooth as wax.
	c = mix(c, wax_face * (0.92 + 0.08 * noise3(p * 20.0)), masks.a * 0.85);
	// Livid ends of fingers and toes, knuckles, knees; nails; hollows.
	c = mix(c, mix(livid, bruise, 0.45), smoothstep(0.1, 0.9, masks.g) * 0.75);
	c = mix(c, mix(nail, livid, 0.25 + 0.3 * noise3(p * 30.0)), smoothstep(0.3, 0.6, masks.r));
	c = mix(c, hollow, smoothstep(0.2, 0.8, masks.b));
	// Where it grows out of the flesh: a puckered, folded, scar-dark join.
	float edge = along.y + (noise3(p * 9.0) - 0.5) * 0.06;
	float join = smoothstep(edge + 0.1, edge - 0.02, along.x);
	float folds = 0.5 + 0.5 * sin(along.x * 90.0 + noise3(p * 12.0) * 6.0);
	c = mix(c, mix(scar, livid, folds * 0.6), join * (0.5 + 0.3 * folds));
	vec2 boil = pustules(p * 7.0, swollen * 0.35 + join * 0.3);
	c = mix(c, pus * (0.85 + 0.15 * noise3(p * 30.0)), boil.x);
	c = mix(c, mix(c, weep, 0.5), boil.y);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	form = NORMAL;
	float e = 0.06;
	vec3 q = p * 26.0;
	float n0 = noise3(q);
	vec3 slope = vec3(noise3(q + vec3(e, 0, 0)) - n0, noise3(q + vec3(0, e, 0)) - n0, noise3(q + vec3(0, 0, e)) - n0) / e;
	vec3 tilt = (VIEW_MATRIX * MODEL_MATRIX * vec4(slope, 0.0)).xyz;
	NORMAL = normalize(NORMAL - tilt * bump * (0.25 + join * 0.8 + boil.x * 0.5));
	wet = max(cut(noise3(p * 16.0 + 5.0), 0.72), max(boil.x * 0.8, boil.y));
}
%s
"""


## The parts' material (shared by everything built of them).
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER % [COMMON, LIGHT]
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material
