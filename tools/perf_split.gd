extends SceneTree
## What a place's frame goes on, by switching things off: a solo round, the boy put
## in the clearing (or a ring, ring=<n>), the frame time measured as it is, then
## again with each thing stopped in turn and started again (all scripts, every
## physics body, the hunters, each kind of script that processes), and what the
## nodes are, by class and by script. Frame times in ms, each over two seconds.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/perf_split.gd -- [ring=<n>] [kinds=<n>]

var main: Node


func _initialize() -> void:
	HeavyVines.apply(_arg("vines", 0))
	seed(_arg("seed", 1))
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _arg(key: String, default: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return int(a.split("=")[1])
	return default


func _frame_ms(seconds := 2.0) -> float:
	for i in 20:
		await process_frame
	var t0 := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - t0 < seconds * 1e6:
		await process_frame
		frames += 1
	return (Time.get_ticks_usec() - t0) / 1000.0 / frames


func _script_key(n: Node) -> String:
	return n.get_script().resource_path.get_file() if n.get_script() else n.get_class()


## The frame with these nodes stopped (their processing, or for bodies, taken out of the world).
func _without(label: String, nodes: Array, _base: float) -> void:
	var base: float = await _frame_ms()
	var was := {}
	for n: Node in nodes:
		if is_instance_valid(n):
			was[n] = [n.is_processing(), n.is_physics_processing()]
			n.set_process(false)
			n.set_physics_process(false)
	var ms: float = await _frame_ms()
	for n: Node in was:
		if is_instance_valid(n):
			n.set_process(was[n][0])
			n.set_physics_process(was[n][1])
	print("  without %-30s %6.2f ms  (%+.2f from %.2f)  [%d nodes]" % [label, ms, ms - base, base, nodes.size()])


func _bodies_out(label: String, bodies: Array, _base: float) -> void:
	var base: float = await _frame_ms()
	var rids := []
	for b: CollisionObject3D in bodies:
		if b is PhysicsBody3D or b is Area3D:
			rids.append([b.get_rid(), b is Area3D])
	for r in rids:
		if r[1]:
			PhysicsServer3D.area_set_space(r[0], RID())
		else:
			PhysicsServer3D.body_set_space(r[0], RID())
	var ms: float = await _frame_ms()
	var space: RID = main.world.get_world_3d().space
	for r in rids:
		if r[1]:
			PhysicsServer3D.area_set_space(r[0], space)
		else:
			PhysicsServer3D.body_set_space(r[0], space)
	print("  without %-30s %6.2f ms  (%+.2f from %.2f)  [%d]" % [label, ms, ms - base, base, rids.size()])


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 120:
		await physics_frame
	var world = main.world
	var ring := _arg("ring", 0)
	if ring > 0:
		if world.dev == null:
			world.dev = load("res://scripts/dev_tools.gd").new(world)
		world.dev.to_ring(ring)
		for i in 60:
			await process_frame
	var all: Array = root.find_children("*", "", true, false)
	var by_class := {}
	var by_script := {}
	var processing := {}
	for n: Node in all:
		by_class[n.get_class()] = by_class.get(n.get_class(), 0) + 1
		if n.get_script():
			by_script[_script_key(n)] = by_script.get(_script_key(n), 0) + 1
		if n.is_processing() or n.is_physics_processing():
			processing[_script_key(n)] = processing.get(_script_key(n), 0) + 1
	print("nodes %d" % all.size())
	for table in [["by class", by_class], ["by script", by_script], ["processing", processing]]:
		var d: Dictionary = table[1]
		var keys := d.keys()
		keys.sort_custom(func(a, b) -> bool: return d[a] > d[b])
		print(" %s:" % table[0])
		for k in keys.slice(0, 20):
			print("   %6d %s" % [d[k], k])
	var base: float = await _frame_ms()
	print("frame as it is %6.2f ms" % base)
	var procs := all.filter(func(n: Node) -> bool: return is_instance_valid(n) and n.get_script() != null and n.can_process() and (n.is_processing() or n.is_physics_processing()))
	await _without("all scripts", procs, base)
	var boy: Node = world.player
	var bodies := all.filter(func(n: Node) -> bool: return is_instance_valid(n) and n is CollisionObject3D and not n is CharacterBody3D and n != boy and not boy.is_ancestor_of(n))
	var by_kind := {}
	for b: Node in bodies:
		var p := b.get_parent()
		var k: String = b.get_class() + " " + (_script_key(b) if b.get_script() else (_script_key(p) if p else ""))
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(b)
	var bkeys := by_kind.keys()
	bkeys.sort_custom(func(a, b) -> bool: return by_kind[a].size() > by_kind[b].size())
	for k in bkeys.slice(0, 8):
		await _bodies_out(k, by_kind[k], base)
	var hunters: Array = world.enemies.enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
	await _without("hunters (and their children)", hunters.map(func(e: Node) -> Node: return e).reduce(func(acc: Array, e: Node) -> Array: acc.append(e); acc.append_array(e.find_children("*", "", true, false)); return acc, []), base)
	var kinds := {}
	for n: Node in procs:
		if not kinds.has(_script_key(n)):
			kinds[_script_key(n)] = []
		kinds[_script_key(n)].append(n)
	var kkeys := kinds.keys()
	var how_many := _arg("kinds", 14)
	# time each kind once quickly, then report the costly ones in full
	var costs := {}
	for k in kkeys:
		var t := 0
		for f in 10:
			for n: Node in kinds[k]:
				if not is_instance_valid(n):
					continue
				var t0 := Time.get_ticks_usec()
				if n.is_processing() and n.has_method("_process"):
					n._process(1.0 / 60.0)
				if n.is_physics_processing() and n.has_method("_physics_process"):
					n._physics_process(1.0 / 60.0)
				t += Time.get_ticks_usec() - t0
			await process_frame
		costs[k] = t / 10.0
	kkeys.sort_custom(func(a, b) -> bool: return costs[a] > costs[b])
	for k in kkeys.slice(0, how_many):
		await _without("%s (%.2f ms by hand)" % [k, costs[k] / 1000.0], kinds[k], base)
	quit()
