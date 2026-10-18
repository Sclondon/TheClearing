extends SceneTree
## The round sections (RoundMaze), headless, for a few seeds: there are three,
## each further out than the last, past the square maze's corners; every cell
## of each can be got to from its gates in, so its ways out can be. The sixth
## ring's rotating doors turn and open ways through, the seventh's tunnel joins
## the way in to the way out; and in a round played, travel there, a door
## shoving him, a walk round the tunnel.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/round_test.gd -- --dev

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	# (the game's own rules, not the maze editor's)
	MazeStyle.chosen = MazeStyle.defaults()
	for seed_value in [1, 77, 4242]:
		var maze := Maze.generate(seed_value, 7)
		var plan := maze.round_rings
		check("seed %d: three round sections" % seed_value, plan != null and plan.rings.size() == 3)
		if plan == null:
			continue
		check("seed %d: past the square's corners" % seed_value, plan.inner_radius > maze.extent() * 0.5 * sqrt(2.0))
		for k in plan.rings.size():
			var ring: RoundMaze.Ring = plan.rings[k]
			var seen := {}
			var queue: Array[Vector2i] = []
			for g: float in ring.gates_in:
				var cell := Vector2i(0, RoundMaze.cell_at(g, ring.rows[0][2]))
				seen[cell] = true
				queue.append(cell)
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for next: Vector2i in plan._neighbours(ring, cell):
					if not seen.has(next) and RoundMaze.joined(ring, cell, next):
						seen[next] = true
						queue.append(next)
			var cells := 0
			for row: Array in ring.rows:
				cells += row[2]
			check("seed %d: section %d all joined up" % [seed_value, maze.rings + k + 1], seen.size() == cells, "(%d of %d)" % [seen.size(), cells])
			var last: Array = ring.rows.back()
			var outs := true
			for g: float in ring.gates_out:
				outs = outs and seen.has(Vector2i(ring.rows.size() - 1, RoundMaze.cell_at(g, last[2])))
			check("seed %d: section %d ways out reached" % [seed_value, maze.rings + k + 1], outs)
		# The desert ring: four quarters walled apart, each with its own way in from
		# the square maze and its own gate on through the first circle.
		var quarters_in := {}
		for door: Vector2 in plan.doors:
			quarters_in[DesertStyle.quarter_at(door.x, door.y)] = true
		check("seed %d: a way in from the square maze to each quarter" % seed_value, plan.doors.size() == 4 and quarters_in.size() == 4, "(%d doors, %d quarters)" % [plan.doors.size(), quarters_in.size()])
		var quarters_out := {}
		for g: float in plan.desert_gates:
			var at := Vector2.from_angle(g) * plan.inner_radius
			quarters_out[DesertStyle.quarter_at(at.x, at.y)] = true
			# (well clear of the diagonal walls)
			var off_diagonal := INF
			for a: float in RoundMaze.DIAGONALS:
				off_diagonal = minf(off_diagonal, absf(angle_difference(g, a)))
			check("seed %d: the gate at %.2f clear of the walls between quarters" % [seed_value, g], off_diagonal > 0.3)
		check("seed %d: a gate out of each quarter" % seed_value, plan.desert_gates.size() == 4 and quarters_out.size() == 4)
		# (no way round the diagonal walls: they run from the square's corners right to the circle)
		var built := RoundBuilder.new()
		built.plan = plan
		root.add_child(built)
		for i in 3:
			await physics_frame
		var space := built.get_world_3d().direct_space_state
		var walled := true
		for a: float in RoundMaze.DIAGONALS:
			for r in range(int(plan.square_half * sqrt(2.0)) + 4, int(plan.inner_radius) - 4, 20):
				var across := Vector2.from_angle(a).orthogonal() * 8.0
				var at := Vector2.from_angle(a) * r
				var query := PhysicsRayQueryParameters3D.create(Vector3(at.x - across.x, 2.0, at.y - across.y), Vector3(at.x + across.x, 2.0, at.y + across.y))
				if space.intersect_ray(query).is_empty():
					walled = false
		check("seed %d: the quarters walled apart" % seed_value, walled)
		built.free()
		# (sand only where a quarter is desert)
		var look := DesertStyle.new()
		look.south_quarter = DesertStyle.Biome.DESERT
		plan.desert = look
		plan._level.clear()
		var sandy := []
		for side: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var mid := side * (plan.square_half + plan.inner_radius) * 0.5
			var most := 0.0
			for t in range(-8, 9):
				var p := mid + side.orthogonal() * t * 12.0
				most = maxf(most, plan.desert_height(p.x, p.y))
			sandy.append(most > 0.5)
		check("seed %d: dunes only in the desert quarters (north and south here)" % seed_value, sandy == [true, false, true, false], str(sandy))
		await _doors_and_tunnel(seed_value, maze)
	await _played()
	print("ROUND TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))


# A ray across at 2 m up, clear (true) or not.
func _clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 2.0, to + Vector3.UP * 2.0)).is_empty()


## Section 6 a circle of rotating doors, section 7 one tunnel round: the doors
## turn, and at some time each circle's open doors are ways through it (and shut,
## not); the tunnel joins the gates in from section 6 to the way out, roofed.
func _doors_and_tunnel(seed_value: int, maze: Maze) -> void:
	var plan := maze.round_rings
	var doors_ring: RoundMaze.Ring = plan.rings[1]
	var tunnel: RoundMaze.Ring = plan.rings[2]
	var style := doors_ring.style as RoundStyle
	check("seed %d: section 6 rotating doors, section 7 a tunnel" % seed_value, doors_ring.layout == RoundStyle.Layout.ROTATING_DOORS and tunnel.layout == RoundStyle.Layout.TUNNEL)
	check("seed %d: %d circles of %d doors" % [seed_value, style.door_circles, style.door_count], doors_ring.door_radii.size() == style.door_circles and doors_ring.doors.size() == style.door_circles * style.door_count)
	# (at every moment, each circle has a door near open: some opening always comes round)
	var worst := INF
	for step in 200:
		var time := style.door_turn_seconds * step / 200.0
		var best := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for n in doors_ring.doors.size():
			var c: int = doors_ring.doors[n][0]
			best[c] = maxf(best[c], RoundMaze.door_gap(doors_ring, n, time))
		for c in doors_ring.door_radii.size():
			worst = minf(worst, best[c])
	check("seed %d: a way through every circle at every moment" % seed_value, worst > style.door_gap_width * 0.8, "(the narrowest %.1f m of %.1f)" % [worst, style.door_gap_width])
	var built := RoundBuilder.new()
	built.plan = plan
	root.add_child(built)
	check("seed %d: the doors are moving bodies" % seed_value, built.doors.size() == doors_ring.doors.size() and built.doors.all(func(d: Array) -> bool: return d[0] is AnimatableBody3D))
	built.set_doors_at(0.0)
	for i in 2:
		await physics_frame
	var was: Vector3 = (built.doors[0][0] as Node3D).global_transform.basis.x
	built.set_doors_at(2.0)
	for i in 2:
		await physics_frame
	var now: Vector3 = (built.doors[0][0] as Node3D).global_transform.basis.x
	check("seed %d: they turn with the clock" % seed_value, was.angle_to(now) > 0.3, "(%.2f radians in 2 s)" % was.angle_to(now))
	# Each circle's first door: when it stands edge on, a way through either side of
	# it; when it is shut, none.
	var space := built.get_world_3d().direct_space_state
	for c in doors_ring.door_radii.size():
		var n := c * style.door_count
		var door: Array = doors_ring.doors[n]
		var r: float = doors_ring.door_radii[c]
		var a: float = door[1]
		# (the time it is edge on, and a quarter turn later, shut)
		var open_at := fposmod((PI * 0.5 - door[2]) * door[3], PI) * style.door_turn_seconds / PI
		var side := Vector3(-sin(a), 0.0, cos(a)) * (doors_ring.doorway * 0.25 + doors_ring.door_thick * 0.25)
		var inside := RoundBuilder.at(a, r - 8.0) + side
		var outside := RoundBuilder.at(a, r + 8.0) + side
		built.set_doors_at(open_at)
		for i in 3:
			await physics_frame
		var open_gap := RoundMaze.door_gap(doors_ring, n, open_at)
		var through := _clear(space, inside, outside)
		built.set_doors_at(open_at + style.door_turn_seconds * 0.5)
		for i in 3:
			await physics_frame
		var shut := not _clear(space, inside, outside)
		check("seed %d: circle %d's door open lets through (gap %.1f m), shut does not" % [seed_value, c + 1, open_gap], through and shut, "(through %s, shut %s)" % [through, shut])
	# The tunnel: round inside it from each gate in to the way out nothing stands in
	# the way; it has a roof; the way out is open.
	var middle := (tunnel.inner + tunnel.outer) * 0.5
	var joined := true
	for g: float in tunnel.gates_in:
		# (in through the gate, from section 6)
		joined = joined and _clear(space, RoundBuilder.at(g, tunnel.inner - 6.0), RoundBuilder.at(g, middle))
		var to := g + angle_difference(g, plan.exit_angle)
		var steps := maxi(ceili(absf(to - g) * middle / 8.0), 1)
		for s in steps:
			joined = joined and _clear(space, RoundBuilder.at(lerpf(g, to, float(s) / steps), middle), RoundBuilder.at(lerpf(g, to, float(s + 1) / steps), middle))
	var out_open := _clear(space, RoundBuilder.at(plan.exit_angle, middle), RoundBuilder.at(plan.exit_angle, tunnel.outer + 6.0))
	check("seed %d: the tunnel joins each way in to the way out" % seed_value, joined and out_open, "(round %s, out %s)" % [joined, out_open])
	var roofed := 0
	for n in 40:
		var p := RoundBuilder.at(TAU * (n + 0.25) / 40.0, middle) + Vector3.UP * 2.0
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.UP * 60.0)).is_empty():
			roofed += 1
	var tunnel_style := tunnel.style as RoundStyle
	var width := tunnel.outer - tunnel.inner - MazeBuilder.RING_THICK
	check("seed %d: the tunnel roofed (%d of 40 places), %.0f m wide" % [seed_value, roofed, width], roofed >= 30 and is_equal_approx(width, tunnel_style.tunnel_width))
	built.free()


## In a round played: the dev panel's travel puts him in sections 6 and 7; a door
## shoves him out of its way; he walks round the tunnel.
func _played() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var player = world.player
	var plan: RoundMaze = world.maze.round_rings
	var built: RoundBuilder = null
	for found in world.find_children("*", "Node3D", true, false):
		if found is RoundBuilder:
			built = found
	check("played: rotating doors built in the round", built != null and not built.doors.is_empty())
	if built == null or plan.rings.size() < 3:
		return
	var doors_ring: RoundMaze.Ring = plan.rings[1]
	var tunnel: RoundMaze.Ring = plan.rings[2]
	for ring in ([6, 7] if world.dev else []):
		world.dev.to_ring(ring)
		for i in 20:
			await physics_frame
		var out: float = Vector2(player.global_position.x, player.global_position.z).length()
		var section: RoundMaze.Ring = plan.rings[ring - 5]
		check("played: travel to ring %d" % ring, out > section.inner + 2.0 and out < section.outer - 2.0 and player.is_on_floor(), "(%.0f m out, %.0f to %.0f)" % [out, section.inner, section.outer])
	# A door turning into him shoves him out of its way.
	var door: Array = built.doors[0]
	var n: int = door[3]
	var style := doors_ring.style as RoundStyle
	var open_at := fposmod((PI * 0.5 - doors_ring.doors[n][2]) * doors_ring.doors[n][3], PI) * style.door_turn_seconds / PI
	var slab: AnimatableBody3D = door[0]
	var pivot: Vector3 = door[1]
	var a: float = door[4]
	built.set_doors_at(open_at)
	for i in 5:
		await physics_frame
	# (beside it as it stands edge on, half way out along it, on the side it turns to)
	var x0: Vector3 = RoundBuilder._door_transform(doors_ring, n, pivot, a, open_at).basis.x
	var x1: Vector3 = RoundBuilder._door_transform(doors_ring, n, pivot, a, open_at + 0.3).basis.x
	var stood := pivot + x0 * 2.5 + (x1 - x0).normalized() * 1.6
	world.put_player(stood + Vector3.UP * 0.1, 0.0)
	var inside_it := false
	for f in 120:
		built.time_fixed = open_at + style.door_turn_seconds * 0.5 * f / 120.0
		await physics_frame
		var local: Vector3 = slab.global_transform.affine_inverse() * player.global_position
		if absf(local.x) < doors_ring.door_long * 0.5 - 0.2 and absf(local.z) < doors_ring.door_thick * 0.5 - 0.1:
			inside_it = true
	var moved: float = (player.global_position - stood).length()
	check("played: a turning door shoves him out of its way", not inside_it and moved > 0.5, "(moved %.1f m)" % moved)
	built.time_fixed = -1.0
	# Round the tunnel: on foot, round it for ten seconds.
	var middle := (tunnel.inner + tunnel.outer) * 0.5
	var start_a := plan.exit_angle + 0.2
	world.put_player(RoundBuilder.at(start_a, middle) + Vector3.UP * 0.1, 0.0)
	for i in 10:
		await physics_frame
	var lowest := INF
	var highest := 0.0
	for f in 600:
		var p: Vector3 = player.global_position
		var round_way := Vector3(-p.z, 0.0, p.x).normalized()
		player.velocity.x = round_way.x * 6.0
		player.velocity.z = round_way.z * 6.0
		await physics_frame
		var r := Vector2(player.global_position.x, player.global_position.z).length()
		lowest = minf(lowest, r)
		highest = maxf(highest, r)
	var gone := angle_difference(start_a, atan2(player.global_position.z, player.global_position.x)) * middle
	check("played: he walks round the tunnel", gone > 40.0 and lowest > tunnel.inner + 1.0 and highest < tunnel.outer - 1.0, "(%.0f m round, %.0f to %.0f m out)" % [gone, lowest, highest])
	main.free()
	quit(failures)
