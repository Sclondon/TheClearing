class_name Pool
extends Node3D
## A body of still water: a box of it, with this node in the middle of its
## surface. Anything can ask how deep under it a point is; the player swims
## when he is in over his chest. It holds nothing in: build walls round it.
##
## What it looks like is a `Water` (scripts/water.gd), which knows nothing of
## this game. What is this game's is here: the Player is found and watched, so
## that he splashes going in and leaves rings where he swims, and so is
## anything that can be thrown.

## How wide, deep (downwards) and long the water is.
@export var size := Vector3(6.0, 3.0, 6.0)

## What draws it. Its colours, foam, swell and the rest are set on this.
var water: Water


func _ready() -> void:
	add_to_group(&"water")
	water = Water.new()
	water.size = size
	water.banded = Settings.world_banded
	add_child(water)
	get_tree().node_added.connect(_notice)
	_look_through.call_deferred(get_tree().root)


func surface_y() -> float:
	return global_position.y


## How far under the surface `point` is, or a large negative number if it is
## not in this water at all.
func depth_at(point: Vector3) -> float:
	var local := point - global_position
	if absf(local.x) > size.x * 0.5 or absf(local.z) > size.z * 0.5 or local.y < -size.y - 0.5:
		return -1000.0
	return -local.y


func _look_through(node: Node) -> void:
	_notice(node)
	for child in node.get_children():
		_look_through(child)


## The Player counts as under when he does himself (`Player.UNDER_DEPTH`): until
## then he is breaking the surface, and rings open round him. A stone is small.
func _notice(node: Node) -> void:
	if node is Player:
		water.watch(node, Player.UNDER_DEPTH, 1.0)
	elif node is RigidBody3D and node.is_in_group(&"throwable"):
		water.watch(node, 0.2, 0.35)
