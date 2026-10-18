class_name ImpRide
## Where an Imp holds on to someone: a place on a figure's body, and which way
## the imp is turned there, for an Imp with `riding` on (its -Y towards the
## body, its Z up it). Worked out each frame from the figure's skeleton, so the
## imp goes where the body goes as it runs and jumps.
##
## The figure's skeleton needs bones named as GameCommon's characters' are:
## hips, chest, neck, upper_arm_l, upper_arm_r, thigh_l, thigh_r, shin_l,
## shin_r (+X the figure's left). Without a skeleton, a plain body (its own
## transform, about 1.2 m tall) is used.
##
## The places (`slot`), in the order they are best taken:
## 0. on his back, between the shoulders, head by his neck;
## 1. round the front of his left thigh;
## 2. on his right shoulder and upper arm;
## 3. on his left side, under the arm;
## 4. round the back of his right thigh;
## 5. on his chest.

const SLOTS := 6


## Where to put an imp riding `body` in place `slot` (world), from `skeleton`
## if it is given and has the bones.
static func slot(skeleton: Skeleton3D, body: Node3D, which: int) -> Transform3D:
	var hips := _bone(skeleton, &"hips", body, Vector3(0.0, 0.6, 0.0))
	var chest := _bone(skeleton, &"chest", body, Vector3(0.0, 0.85, 0.0))
	var neck := _bone(skeleton, &"neck", body, Vector3(0.0, 1.0, 0.0))
	var arm_l := _bone(skeleton, &"upper_arm_l", body, Vector3(0.15, 0.95, 0.0))
	var arm_r := _bone(skeleton, &"upper_arm_r", body, Vector3(-0.15, 0.95, 0.0))
	var up := (neck - hips).normalized()
	var left := arm_l - arm_r
	left = (left - up * left.dot(up)).normalized()
	var ahead := left.cross(up).normalized()
	var at := chest
	var out := -ahead
	match which % SLOTS:
		0:
			at = chest.lerp(neck, 0.15) - ahead * 0.1
			out = -ahead
		1:
			var thigh := _bone(skeleton, &"thigh_l", body, Vector3(0.08, 0.55, 0.0))
			var shin := _bone(skeleton, &"shin_l", body, Vector3(0.08, 0.3, 0.0))
			at = thigh.lerp(shin, 0.55) + ahead * 0.065 + left * 0.01
			out = (ahead + left * 0.3).normalized()
		2:
			var elbow := _bone(skeleton, &"forearm_r", body, Vector3(-0.17, 0.75, 0.0))
			at = arm_r.lerp(elbow, 0.3) - left * 0.06
			out = (-left + ahead * 0.2).normalized()
		3:
			at = chest - up * 0.1 + left * 0.1 - ahead * 0.02
			out = (left - ahead * 0.3).normalized()
		4:
			var thigh := _bone(skeleton, &"thigh_r", body, Vector3(-0.08, 0.55, 0.0))
			var shin := _bone(skeleton, &"shin_r", body, Vector3(-0.08, 0.3, 0.0))
			at = thigh.lerp(shin, 0.4) - ahead * 0.07
			out = (-ahead - left * 0.3).normalized()
		5:
			at = chest - up * 0.05 + ahead * 0.1
			out = ahead
	var climb := (up - out * up.dot(out)).normalized()
	return Transform3D(Basis(out.cross(climb), out, climb), at)


static func _bone(skeleton: Skeleton3D, name: StringName, body: Node3D, fallback: Vector3) -> Vector3:
	if skeleton and is_instance_valid(skeleton):
		var index := skeleton.find_bone(name)
		if index >= 0:
			return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
	return body.global_transform * fallback
