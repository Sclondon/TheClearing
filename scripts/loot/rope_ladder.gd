class_name RopeLadder
extends Ladder
## A rope ladder hung down from an edge (LootItem's LADDER, hung with Loot):
## climbed as any ladder is (it is one: the boy walks out over its top and turns
## onto it, or walks into its foot), so it is a way down from a ledge and back
## up again, for anyone. Two hemp ropes with wooden rungs knotted between them,
## hanging a little away from the wall, its top tied round a stake.

## How far it stands off the wall, metres.
const OFF := 0.12

static var _hemp: Material
static var _wood: Material


func _ready() -> void:
	add_to_group(&"ladders")
	if _hemp == null:
		_hemp = Toon.surface(Color(0.47, 0.39, 0.26))
		_wood = Toon.surface(Color(0.55, 0.45, 0.32))
	for x: float in [-0.21, 0.21]:
		var rope := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.018
		mesh.height = height + 0.3
		mesh.radial_segments = 5
		mesh.rings = 1
		rope.mesh = mesh
		rope.material_override = _hemp
		rope.position = Vector3(x, (height + 0.3) * 0.5, 0.0)
		add_child(rope)
	# (one mesh for all the rungs: a box each, a little askew)
	var rungs := SurfaceTool.new()
	rungs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(height / RUNG)
	for i in count:
		var tilt := Basis(Vector3.BACK, sin(i * 2.7) * 0.05)
		var box := BoxMesh.new()
		box.size = Vector3(0.48, 0.035, 0.045)
		rungs.append_from(box, 0, Transform3D(tilt, Vector3(0.0, (i + 1) * RUNG, 0.0)))
	var bar := MeshInstance3D.new()
	bar.mesh = rungs.commit()
	bar.material_override = _wood
	add_child(bar)
	# the stake it is tied to, at the top
	var stake := MeshInstance3D.new()
	var post := CylinderMesh.new()
	post.top_radius = 0.03
	post.bottom_radius = 0.04
	post.height = 0.35
	post.radial_segments = 6
	stake.mesh = post
	stake.material_override = _wood
	stake.position = Vector3(0.0, height + 0.12, -0.5)
	add_child(stake)


## Hangs one in `parent` from the edge at `top` (a point on its lip), down the
## wall facing `out` (level, away from the wall), to the ground `drop` below.
static func hang(parent: Node, top: Vector3, out: Vector3, drop: float) -> RopeLadder:
	var ladder := RopeLadder.new()
	ladder.height = drop
	parent.add_child(ladder)
	var foot := top + out * OFF + Vector3.DOWN * drop
	# (its rungs face +Z, the side it is climbed from: out from the wall)
	ladder.global_transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), foot)
	return ladder
