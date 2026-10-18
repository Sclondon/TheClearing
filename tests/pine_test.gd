extends SceneTree
## The pines: every solid triangle (the trunk, and the dark mass inside the crown)
## faces the way its normal does, so none is culled from outside and none shows its
## inside; the fronds are needle cards (drawn from both sides) in the needle shader;
## and the plain far tree is lighter than the near one.
##
##     godot --headless --path . -s res://tests/pine_test.gd

var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	var pine := PineTree.new()
	pine.height = 13.0
	pine.seed = 7
	for variant in 3:
		var arrays := pine.mesh(variant).surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var kinds = arrays[Mesh.ARRAY_TEX_UV2]
		var solid := 0
		var cards := 0
		var inside_out := 0
		for t in range(0, points.size(), 3):
			if kinds != null and (kinds as PackedVector2Array)[t].x > 0.5:
				cards += 1
				continue
			solid += 1
			var face := (points[t + 1] - points[t]).cross(points[t + 2] - points[t])
			var normal := normals[t] + normals[t + 1] + normals[t + 2]
			# (Godot draws clockwise as the front: so this cross product points in, against the normal)
			if face.dot(normal) > 0.0:
				inside_out += 1
		check("tree %d: trunk and crown face out" % variant, inside_out == 0, "(%d of %d solid triangles inside out)" % [inside_out, solid])
		check("tree %d: fronds are needle cards" % variant, cards > 200, "(%d card triangles)" % cards)
	var material := pine._material()
	check("drawn with the needle shader", material is ShaderMaterial and (material as ShaderMaterial).shader.code.contains("needle"))
	var near := pine.mesh(0).get_faces().size() / 3
	var far := pine.simple().mesh(0).get_faces().size() / 3
	check("plain far tree is lighter", far * 2 < near, "(%d near, %d far triangles)" % [near, far])
	print("PINE TEST %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)
