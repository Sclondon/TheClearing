class_name Perches
## Where birds may sit (CorvidFlock.set_perches): along the top edges of the
## maze's walls and on their ledges, found by rays, and among the branches and
## on the tops of the clearing's pines, worked out from the trees' pieces the
## way PineTree grows them. Each place is a point and the way a bird there
## faces (out over the hall; out along the branch).


## Perches along the walls round `near` (a point on the floor of a hall, the
## floor at `ground`): the wall faces within `reach` of it straight along the
## four ways, and along each, every `spacing` metres within `spread` of where
## the ray met it, a place on its top edge (a little in from it) and, where the
## wall steps out below its top (a terrace), one on that ledge. Only what stands
## at least `lowest` metres over the floor. [points, faces], or two empty arrays.
static func along_walls(world: World3D, near: Vector3, ground: float, reach := 30.0, spread := 8.0, spacing := 0.7, lowest := 5.0) -> Array:
	var space := world.direct_space_state
	var points := PackedVector3Array()
	var faces := PackedVector3Array()
	var low := Vector3(near.x, ground + 2.0, near.z)
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + way * reach, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var out: Vector3 = hit["normal"]
		out.y = 0.0
		out = out.normalized()
		var foot: Vector3 = hit["position"]
		var along := out.cross(Vector3.UP)
		var steps := int(spread * 2.0 / spacing)
		for k in steps + 1:
			var at := foot + along * (-spread + k * spacing)
			var edge := at - out * 0.3
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(edge.x, ground + 300.0, edge.z), Vector3(edge.x, ground + 1.0, edge.z), 1))
			if down.is_empty() or (down["normal"] as Vector3).y < 0.7:
				continue
			var top: Vector3 = down["position"]
			if top.y - ground < lowest:
				continue
			# (the top may stand out past the face below it: out to its lip)
			for step in 10:
				var further := top + out * 0.25
				var lip := space.intersect_ray(PhysicsRayQueryParameters3D.create(further + Vector3.UP * 2.0, further + Vector3.DOWN * 0.5, 1))
				if lip.is_empty() or absf((lip["position"] as Vector3).y - top.y) > 0.25:
					break
				top = Vector3(further.x, (lip["position"] as Vector3).y, further.z)
			# (an edge: open air below just past it, not the middle of a corner's top)
			var beyond := top + out * 0.6
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond + Vector3.UP * 1.0, beyond + Vector3.DOWN * 3.0, 1)).is_empty():
				continue
			# (right on the edge, as crows sit on a gutter: seen from below)
			top += out * 0.02
			# (the face is still here, not a gap or a corner: a ray in to it a little under the top)
			var under := Vector3(at.x, top.y - 1.0, at.z) + out * 1.5
			var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(under, under - out * 2.5, 1))
			if face.is_empty():
				continue
			points.append(top)
			faces.append(out)
			# A ledge under the top (a terrace standing out from the wall).
			var over := at + out * 0.5
			var ledge := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(over.x, top.y - 1.5, over.z), Vector3(over.x, ground + 1.0, over.z), 1))
			if not ledge.is_empty() and (ledge["normal"] as Vector3).y > 0.7 and (ledge["position"] as Vector3).y > ground + lowest:
				points.append(ledge["position"])
				faces.append(out)
	return [points, faces]


## Perches in the pines at `trees` (transforms of the trees' pieces, as
## MazeBuilder grows them: PineTree 13 m tall, scaled): on the branches of
## each, from `from` to `to` of the way up its crown, `per_tree` of them, out
## along the branch `reach` of the way (from, to); and on its top with `crown`.
## Seeded by `rng`. [points, faces].
static func in_pines(trees: Array, rng: RandomNumberGenerator, per_tree := 8, from := 0.2, to := 0.7, reach := Vector2(0.35, 0.7), crown := false) -> Array:
	var points := PackedVector3Array()
	var faces := PackedVector3Array()
	for place: Transform3D in trees:
		var top := 13.0 * place.basis.get_scale().y
		var crown_base := 0.14
		var first := top * crown_base
		var body := top * (1.0 - crown_base)
		var at := place.origin
		if crown:
			points.append(at + Vector3.UP * top * 0.985)
			faces.append(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized())
		for k in per_tree:
			# (as PineTree lays out its whorls and fronds)
			var t := rng.randf_range(from, to)
			var y := first + body * pow(t, 0.92)
			var length := 0.42 * top * 0.5 * pow(1.0 - t, 1.05) + top * 0.035
			var hang := 0.45 * lerpf(1.0, 0.55, t)
			var s := rng.randf_range(reach.x, reach.y)
			var drop := hang * length * (0.55 * s * s - 0.12 * pow(s, 4.0) * 3.0) + 0.02 * length
			var angle := rng.randf_range(0.0, TAU)
			var out := Vector3(cos(angle), 0.0, sin(angle))
			# (on top of the frond near its end, where a bird sits out of the needles)
			points.append(at + out * length * s + Vector3.UP * (y - drop + 0.12))
			faces.append(out)
	return [points, faces]
