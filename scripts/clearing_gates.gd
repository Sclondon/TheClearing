class_name ClearingGates
extends Node3D
## The doors of the clearing's entrances, after the Glade's: in each way through
## its great wall, two slabs as high as the wall and as deep as it is thick (the
## whole length of the way through it), that slide out of the wall's sides and
## meet in the middle at sunset, shutting the clearing in for the night, and
## slide back into it at dawn (DayCycle). They take `MOVE_SECONDS` to close, and
## push aside whatever is in their way.

## How long the doors take to close or open, seconds.
const MOVE_SECONDS := 14.0
## Where the doorway is measured (how far back from the face of the wall: the
## middle of a door this thick, so far back); the doors are as deep as the wall.
const THICK := 3.0
const BACK := 2.5
## How far each door goes past the middle of the way, closed (so that they
## close tight), and stays in the wall's side, open.
const OVERLAP := 0.3
const HIDDEN := 0.6
## How far the doors go down under the ground (the marsh gate's way is flooded,
## its floor lower: Ponds), metres.
const SUNK := 1.5

## 0 open, 1 shut.
var shut := 0.0
var closing := false
## Each door: [the body, where it is open, where it is shut].
var _doors: Array = []


## Puts doors in each entrance of `maze`'s clearing, under `parent`. (Called once
## the walls stand, since each doorway is measured.)
static func put(parent: Node3D, maze: Maze) -> ClearingGates:
	var gates := ClearingGates.new()
	gates.name = "ClearingGates"
	parent.add_child(gates)
	var space := parent.get_world_3d().direct_space_state
	var high := maze.inner_height(1)
	var material := Wall.material_for(Wall.Look.RIBBED, true, Color(0.7, 0.7, 0.68))
	for spot: Array in maze.clearing_style.entrance_spots:
		var face: Vector2 = spot[0]
		var inward: Vector2 = spot[1]
		var at := Vector3(face.x, 0.0, face.y) - Vector3(inward.x, 0.0, inward.y) * (BACK + THICK * 0.5)
		var across := Vector3(-inward.y, 0.0, inward.x)
		# (how far the doorway's sides are either way: measured, not reckoned)
		var reach := {}
		for way: float in [-1.0, 1.0]:
			var from := at + Vector3.UP * 3.0
			var query := PhysicsRayQueryParameters3D.create(from, from + across * way * Maze.CELL)
			var hit := space.intersect_ray(query)
			reach[way] = from.distance_to(hit["position"]) if hit else Maze.CELL * 0.5
		var middle: Vector3 = at + across * (reach[1.0] - reach[-1.0]) * 0.5
		var wide: float = reach[1.0] + reach[-1.0]
		# (and how far the way runs through the wall, to its far face: the doors fill
		# all of it, the whole thickness of the wall)
		var out := -Vector3(inward.x, 0.0, inward.y)
		var start: Vector3 = Vector3(face.x, 0.0, face.y) + across * (reach[1.0] - reach[-1.0]) * 0.5 + Vector3.UP * 3.0
		var deep := 1.0
		while deep < 160.0:
			var walled := true
			for way: float in [-1.0, 1.0]:
				var from: Vector3 = start + out * (deep + 1.0)
				var side := PhysicsRayQueryParameters3D.create(from, from + across * way * (wide * 0.5 + 2.0))
				walled = walled and not space.intersect_ray(side).is_empty()
			if not walled:
				break
			deep += 1.0
		middle = Vector3(middle.x, 0.0, middle.z) + out * (deep * 0.5 - (BACK + THICK * 0.5))
		var thick := deep - 0.6
		var half := wide * 0.5 + OVERLAP
		for way: float in [-1.0, 1.0]:
			var door := AnimatableBody3D.new()
			door.sync_to_physics = true
			var size := across.abs() * half + Vector3(inward.x, 0.0, inward.y).abs() * thick + Vector3.UP * (high + SUNK)
			var shape := BoxShape3D.new()
			shape.size = size
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position.y = (high - SUNK) * 0.5
			door.add_child(collider)
			var mesh := BoxMesh.new()
			mesh.size = size
			var shown := MeshInstance3D.new()
			shown.mesh = mesh
			shown.position.y = (high - SUNK) * 0.5
			shown.material_override = material
			door.add_child(shown)
			var shut_at := middle + across * way * (half * 0.5 - OVERLAP)
			var open_at := shut_at + across * way * (half - HIDDEN)
			door.position = open_at
			gates.add_child(door)
			gates._doors.append([door, open_at, shut_at])
	return gates


## Starts them closing (or, `false`, opening).
func close(shutting := true) -> void:
	closing = shutting


## Puts them straight to shut or open.
func set_shut(shutting: bool) -> void:
	closing = shutting
	shut = 1.0 if shutting else 0.0
	_place()


func _physics_process(delta: float) -> void:
	var was := shut
	shut = move_toward(shut, 1.0 if closing else 0.0, delta / MOVE_SECONDS)
	if shut != was:
		_place()


func _place() -> void:
	# (slow to start and to stop, as something so heavy)
	var eased := smoothstep(0.0, 1.0, shut)
	for door: Array in _doors:
		(door[0] as Node3D).position = (door[1] as Vector3).lerp(door[2], eased)
