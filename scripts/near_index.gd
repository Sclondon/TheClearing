class_name NearIndex
extends RefCounted
## The members of a group (the ropes, the ladders) near a place, from a grid of
## where they stand kept for the whole level: the maze has thousands of vines and
## ivy patches, and everyone who moves asked each of them, every step, whether it
## was near enough to take hold of (that was most of what the boy and every runner
## cost a frame).
##
##     for ladder: Ladder in NearIndex.near(get_tree(), &"ladders", global_position, 2.0):
##
## Only where each is across the ground counts (a ladder or a vine can be a wall
## high): a member is found from any point within `reach` of it, plus its own
## spread (a rope's length, which it may swing out to; half an ivy's width). The
## grid is made again when one joins the group or leaves the tree; members are
## taken to stay where they were put (none moves after it is hung).

const CELL := 16.0

# group -> {Vector2i: Array of nodes}; group -> member count it was made with; group -> made again next time
static var _grids := {}
static var _counts := {}
static var _dirty := {}


static func near(tree: SceneTree, group: StringName, at: Vector3, reach: float) -> Array:
	if _dirty.get(group, true) or _counts.get(group, -1) != tree.get_node_count_in_group(group):
		_build(tree, group)
	var grid: Dictionary = _grids[group]
	var lo := Vector2i(floori((at.x - reach) / CELL), floori((at.z - reach) / CELL))
	var hi := Vector2i(floori((at.x + reach) / CELL), floori((at.z + reach) / CELL))
	if lo == hi:
		return grid.get(lo, [])
	var found := {}
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			for node: Node in grid.get(Vector2i(x, y), []):
				found[node] = true
	return found.keys()


static func _build(tree: SceneTree, group: StringName) -> void:
	var grid := {}
	var members := tree.get_nodes_in_group(group)
	for node in members:
		var thing := node as Node3D
		if thing == null or not thing.is_inside_tree():
			continue
		var spread := 1.5
		var at := thing.global_position
		if thing.has_method(&"near_spot"):
			var spot: Vector4 = thing.call(&"near_spot")
			at = Vector3(spot.x, spot.y, spot.z)
			spread = spot.w
		elif &"length" in thing:
			spread = float(thing.get(&"length")) + 0.5
		elif &"width" in thing:
			spread = float(thing.get(&"width")) * 0.5 + 0.5
		for y in range(floori((at.z - spread) / CELL), floori((at.z + spread) / CELL) + 1):
			for x in range(floori((at.x - spread) / CELL), floori((at.x + spread) / CELL) + 1):
				var key := Vector2i(x, y)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(thing)
		var watched := StringName("near_index_" + group)
		if not thing.has_meta(watched):
			thing.set_meta(watched, true)
			thing.tree_exiting.connect(func() -> void: _dirty[group] = true)
			thing.tree_entered.connect(func() -> void: _dirty[group] = true)
	_grids[group] = grid
	_counts[group] = members.size()
	_dirty[group] = false
