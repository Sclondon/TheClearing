extends SceneTree
## The maze editor lays out and builds a maze zone by zone (MazeLayout.zone_at:
## the clearing, each square section, outside), so that a change to one zone's
## rules builds only it again. With the editor's own rules (maze_editor.tscn):
## each of a section's rules changed in turn, the zones whose key changed are laid
## out again over the old layout, and what comes out must be what laying out the
## whole maze afresh gives; a rule of how it is carved (CARVING) may reach the
## zone inside it and those outside it, and any other (but MazeLayout.NEIGHBOUR_RULES)
## must change no other zone.
##
##     godot --headless --path . -s res://tests/zones_test.gd [-- section [rule...]]

var failures := 0
## The rules of how a section is carved: they may move its gate out.
const CARVING := ["hallway_diameter_cells", "straight_on_chance", "side_branch_chance", "loop_share", "entrance_corridor_cells", "entrance_count", "rooms_on", "room_count"]


func check(what: String, ok: bool, detail := "") -> void:
	if not ok or OS.get_cmdline_user_args().has("--verbose"):
		print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	var editor := (load(Mazes.RULES) as PackedScene).instantiate() as MazeLayout
	var args: Array = Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return not a.begins_with("--"))
	var section := int(args[0]) if args.size() > 0 else 2
	var plan := _plan(editor)
	var before := MazeLayout.new()
	before.lay_out(plan)
	var keys := MazeLayout.zone_keys(plan)
	var style: MazeStyle = editor.styles[section - 1]
	var rules: Array = args.slice(1)
	if rules.is_empty():
		for property in style.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE \
					and property.type in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL] and property.name != "round_section":
				rules.append(property.name)
	print("section %d: %d rules, %d zones" % [section, rules.size(), keys.size()])
	var started := Time.get_ticks_msec()
	for rule: String in rules:
		var was: Variant = style.get(rule)
		style.set(rule, _changed(was))
		var after := _plan(editor)
		var now := MazeLayout.zone_keys(after)
		var changed := MazeLayout.changed_zones(keys, now)
		if changed.is_empty():
			var whole := MazeLayout.new()
			whole.lay_out(_plan(editor))
			check("%s: no zone changed, and none is laid out otherwise" % rule, _pieces(whole) == _pieces(before))
			whole.free()
		elif changed.size() < now.size() and after.ring_sizes == plan.ring_sizes:
			# (laid out again over the old, as the editor does it)
			var again := before.duplicate() as MazeLayout
			again.remove_zones(after, changed)
			again.lay_out(after, changed)
			var whole := MazeLayout.new()
			whole.lay_out(_plan(editor))
			var a := _pieces(again)
			var b := _pieces(whole)
			if a != b:
				a = _pieces(again, after)
				b = _pieces(whole, after)
			check("%s: zone by zone is the whole" % rule, a == b, "(%s; %d against %d pieces%s)" % [_names(changed), a.size(), b.size(), _first_odd(a, b)])
			if not MazeLayout.NEIGHBOUR_RULES.has(rule):
				# (the way it is carved may move its gate out, and so the sections past it, and
				# its cells along the wall round its inside, which the zone inside stands by too)
				var others := changed.keys().filter(func(zone: Variant) -> bool: return zone is int and zone < section - 1)
				check("%s: nothing further in" % rule, others.is_empty(), "(%s)" % _names(changed))
				if not CARVING.has(rule):
					check("%s: only its own zone" % rule, changed.keys() == [section], "(%s)" % _names(changed))
			again.free()
			whole.free()
		style.set(rule, was)
	print("(%.0f s)" % ((Time.get_ticks_msec() - started) / 1000.0))
	before.free()
	editor.free()
	print("zones_test: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)


func _plan(editor: MazeLayout) -> Maze:
	return Maze.generate(editor.maze_seed, editor.rings, editor.styles, editor.clearing_style, editor.desert)


## A different value of a rule, as a setting in the Inspector would be.
func _changed(value: Variant) -> Variant:
	if value is bool:
		return not value
	if value is int:
		return value + 1
	return value + 0.1 if value < 0.9 else value - 0.1


## Every piece of a layout as a sorted list of what it is and where.
func _pieces(layout: MazeLayout, maze: Maze = null) -> Array:
	var all: Array = []
	for kind in MazePiece.Kind.values():
		for piece in layout.pieces(kind):
			var end := ""
			if piece.has_node("End"):
				end = str((piece.get_node("End") as Node3D).position.snappedf(0.01))
			all.append("%d %s %s %s %s %.2f %.2f %s %s%s" % [kind, piece.position.snappedf(0.01), piece.basis.get_euler().snappedf(0.01),
				piece.basis.get_scale().snappedf(0.01), piece.size.snappedf(0.01), piece.length, piece.width, end, [piece.ledge, piece.great, piece.style, piece.prop, piece.drips, piece.sag, piece.tails, piece.lamp, piece.anchor], (" zone %d%s" % [MazeLayout.zone_of(maze, piece), " (tagged)" if piece.has_meta(&"zone") else ""]) if maze else ""])
	all.sort()
	return all


func _first_odd(a: Array, b: Array) -> String:
	var count := {}
	for each in a:
		count[each] = count.get(each, 0) + 1
	for each in b:
		count[each] = count.get(each, 0) - 1
	var odd: Array = []
	for each in count:
		if count[each] != 0 and odd.size() < 6:
			odd.append("%+d %s" % [count[each], each])
	return ("; zone by zone vs whole: " + " | ".join(odd)) if not odd.is_empty() else ""


func _names(zones: Dictionary) -> String:
	return ", ".join(zones.keys().map(func(zone: Variant) -> String: return str(zone)))
