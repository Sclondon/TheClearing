class_name HeavyVines
extends RefCounted
## For the probes: the game's own styles with the square sections' vines made
## heavier (the user, 2026-10-19: "the plan is to have a lot of vines"):
## vine_density times `times`, and the mezzanine crossings, hanging vines and
## random crossings each twice as thick. Call before the round is made.


static func apply(times: float) -> void:
	if times <= 0.0:
		return
	var styles := MazeStyle.defaults().duplicate()
	for i in MazeStyle.square_defaults().size():
		var style: MazeStyle = styles[i].duplicate(true)
		style.vine_density *= times
		style.mezzanine_crossing_density *= 2.0
		style.hanging_vine_density = minf(style.hanging_vine_density * 2.0, 1.0)
		style.random_crossing_density = minf(style.random_crossing_density * 2.0, 1.0)
		styles[i] = style
	MazeStyle.chosen = styles
