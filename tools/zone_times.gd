extends SceneTree
## What the live preview's build costs, part by part, with the editor's own rules
## (maze_editor.tscn): for working out what is worth building zone by zone.
##
##     godot --headless --path . -s res://tools/zone_times.gd


func _ms(t: int) -> float:
	return (Time.get_ticks_usec() - t) / 1000.0


func _initialize() -> void:
	var editor := (load(Mazes.RULES) as PackedScene).instantiate() as MazeLayout
	var t := Time.get_ticks_usec()
	var plan := Maze.generate(editor.maze_seed, editor.rings, editor.styles, editor.clearing_style, editor.desert)
	print("plan                 %7.0f ms" % _ms(t))
	var layout := MazeLayout.new()
	t = Time.get_ticks_usec()
	var runs := MazeLayout._runs(plan)
	var piers := MazeLayout._piers(plan, false) + MazeLayout._piers(plan, true)
	print("runs + piers (math)  %7.0f ms  (%d, %d)" % [_ms(t), runs.size(), piers.size()])
	t = Time.get_ticks_usec()
	layout.lay_out(plan)
	print("lay_out (all)        %7.0f ms" % _ms(t))
	var fresh := MazeLayout.new()
	t = Time.get_ticks_usec()
	MazeFeatures.lay_out(fresh, plan)
	print("  features alone     %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	MazeProps.lay_out(layout.duplicate(), plan)
	print("  props alone        %7.0f ms" % _ms(t))
	var built := MazeBuilder.new()
	built.preview = true
	root.add_child(built)
	built.layout = layout
	built.maze = plan
	t = Time.get_ticks_usec()
	var body := StaticBody3D.new()
	built._walls(body, layout)
	print("realize walls        %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var features := MazeFeatures.new()
	built.add_child(features)
	features.realize(layout)
	print("realize features     %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var props := MazeProps.new()
	props.realize(layout)
	built.add_child(props)
	print("realize props        %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	built._ground()
	print("realize ground       %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var ponds := Ponds.new()
	built.add_child(ponds)
	ponds.realize(plan, layout, built.ground_material, true)
	print("realize ponds        %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	built._trees(layout)
	print("realize trees        %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	if plan.round_rings:
		var round := RoundBuilder.new()
		round.plan = plan.round_rings
		built.add_child(round)
	print("realize round        %7.0f ms" % _ms(t))
	# The live preview after a change to one section's own rule: only it again.
	print("-- section 2's tightrope vines changed")
	var style: MazeStyle = editor.styles[1]
	style.tightrope_vine_share = style.tightrope_vine_share * 0.5 + 0.1
	t = Time.get_ticks_usec()
	var after := Maze.generate(editor.maze_seed, editor.rings, editor.styles, editor.clearing_style, editor.desert)
	print("plan                 %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var changed := MazeLayout.changed_zones(MazeLayout.zone_keys(plan), MazeLayout.zone_keys(after))
	print("zone keys            %7.0f ms  (%s)" % [_ms(t), str(changed.keys())])
	t = Time.get_ticks_usec()
	layout.remove_zones(after, changed)
	print("remove zones         %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	layout.lay_out(after, changed)
	print("lay_out the zones    %7.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var views := layout.zone_views(after, changed)
	print("zone views           %7.0f ms" % _ms(t))
	for zone in views:
		t = Time.get_ticks_usec()
		var part := MazeBuilder.new()
		part.preview = true
		root.add_child(part)
		part.realize_zone(views[zone], after)
		print("realize zone %s       %7.0f ms" % [zone, _ms(t)])
	t = Time.get_ticks_usec()
	var ground := MazeBuilder.new()
	ground.preview = true
	root.add_child(ground)
	ground.realize_ground(layout, after)
	print("realize ground       %7.0f ms" % _ms(t))
	quit()
