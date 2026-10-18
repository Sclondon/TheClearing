class_name FireWard
extends RefCounted
## What fears fire keeps off it: anything in the group `fire_wards` with a
## `ward_radius` over 0 (a lit torch, wherever it is: in a hand or lying; a
## burning flare; a lit campfire) keeps the things that fear fire (MazeEnemy
## `fears_fire`: the beetles, the imp swarm, the frog swarm) from going after
## anyone within that many metres of it. They give up, as when someone climbs
## out of their reach, and stream home.


## Whether `point` is within the ward of a fire.
static func near(tree: SceneTree, point: Vector3) -> bool:
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(&"fire_wards"):
		var fire := node as Node3D
		if fire == null or not fire.is_inside_tree():
			continue
		var radius: Variant = fire.get(&"ward_radius")
		if radius == null or float(radius) <= 0.0:
			continue
		if fire.global_position.distance_squared_to(point) < float(radius) * float(radius):
			return true
	return false
