class_name BaboonLook
## What a Baboon (creatures/baboon/baboon.gd) is made of, to look at: one
## skinned mesh for each kind, made here in code, and one material.
##
## The mesh is built round the baboon's skeleton as it stands (the joints
## Baboon works out for its standing pose): the trunk is one smooth tube lofted
## through rump, back, chest and neck into the skull; each limb a tube from
## shoulder or hip through elbow or knee to the wrist or ankle; the tail a tube
## along its bones. Onto these go the head's parts (skull, brow, muzzle, the
## mandrill's red nose ridge and blue ridged cheeks, ember eyes in dark
## sockets, ears, the jaw, gums and fangs, the beard), fists and feet, and cones
## for the mane, the ruff and the long hair on the forearms. Each vertex is
## weighted to one or two of the skeleton's bones (all of them children of the
## skeleton itself, no hierarchy: see Baboon.BONES), so the tubes bend smoothly
## at every joint. A whole baboon is one draw.
##
## Vertex colours carry the colours; UV carries how much a vertex glows (x: the
## eyes) and how much it is fur (y: fur is streaked and has a pale backlit
## fringe, skin and teeth are plain); UV2 is where it was on the standing body,
## for the streaks to stay put on the fur as it moves.
##
## Shading is cel shading in two hard tones with a one-pixel edge and a rim of
## light at grazing angles, so it sits with a cel-shaded cast without needing
## their scripts.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.2;
uniform float flatness = 0.65;
uniform float rim_gain = 0.6;
uniform float rim_width = 0.22;
// Each baboon's own coat, a little lighter or darker.
instance uniform float tone = 1.0;

varying float glow;
varying float furry;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	glow = UV.x;
	furry = UV.y;
}

void fragment() {
	// Streaks in the fur, running along the body; and darker towards the roots, in tufts.
	float streak = noise(UV2 * vec2(60.0, 9.0));
	float tuft = noise(UV2 * vec2(14.0, 14.0));
	float shade = 1.0 + ((streak - 0.5) * 0.4 + (tuft - 0.5) * 0.25) * furry;
	ALBEDO = COLOR.rgb * shade * mix(1.0, tone, furry);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = COLOR.rgb * glow * 1.6;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	// The fur's rim is a paler shade of itself: the backlit fringe of a coat.
	SPECULAR_LIGHT += rim * rim_gain * mix(ALBEDO * 0.5, vec3(0.75), 0.4 * furry) * strength * LIGHT_COLOR / PI;
}
"""

static var _material: ShaderMaterial
static var _meshes := {}


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


## The mesh for a kind, built (once) round `joints`, its standing pose (see Baboon._joints).
static func mesh_for(kind: int, build: Dictionary, joints: Dictionary) -> ArrayMesh:
	if not _meshes.has(kind):
		var maker := Maker.new()
		maker.make(kind, build, joints)
		_meshes[kind] = maker.commit()
	return _meshes[kind]


## Puts the mesh together.
class Maker:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	## Spikes made while this is set are shaded as part of a round surface about
	## this point (clumps of fur lying on it), not as the cones they are.
	var hint_from := Vector3.INF

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, BaboonLook.material())
		return mesh

	## One vertex, weighted to `b0` and (by `w1`) to `b1`.
	func vertex(at: Vector3, normal: Vector3, color: Color, glow: float, fur: float, b0: int, b1 := -1, w1 := 0.0) -> int:
		verts.append(at)
		normals.append(normal.normalized())
		colors.append(color)
		uvs.append(Vector2(glow, fur))
		uv2s.append(Vector2(at.x * 0.8 + at.z * 0.6, at.y + at.z * 0.3))
		if b1 < 0 or w1 <= 0.0:
			bones.append_array([b0, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		else:
			bones.append_array([b0, b1, 0, 0])
			weights.append_array([1.0 - w1, w1, 0.0, 0.0])
		return verts.size() - 1

	## A tube through `centers`, `radii` (x across, y the other way) at each, its
	## rings turned so that their y lies along `up` as near as can be. `rig` for
	## each ring: [bone, other bone, weight of the other]. Closed at both ends.
	func tube(centers: PackedVector3Array, radii: PackedVector2Array, up: Vector3, rig: Array, color: Color, fur := 1.0, sides := 12, colors_each := []) -> void:
		var n := centers.size()
		var first := verts.size()
		var frames: Array[Basis] = []
		for i in n:
			var along := (centers[mini(i + 1, n - 1)] - centers[maxi(i - 1, 0)]).normalized()
			var across := up.cross(along)
			if across.length() < 0.01:
				across = Vector3.RIGHT
			across = across.normalized()
			var lift := along.cross(across).normalized()
			frames.append(Basis(across, lift, along))
		for i in n:
			var r := radii[i]
			var c: Color = colors_each[i] if not colors_each.is_empty() else color
			for k in sides:
				var a := TAU * k / sides
				var off := frames[i].x * cos(a) * r.x + frames[i].y * sin(a) * r.y
				var normal := frames[i].x * cos(a) / maxf(r.x, 0.001) + frames[i].y * sin(a) / maxf(r.y, 0.001)
				vertex(centers[i] + off, normal, c, 0.0, fur, rig[i][0], rig[i][1], rig[i][2])
		for i in n - 1:
			for k in sides:
				var a := first + i * sides + k
				var b := first + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				indices.append_array([a, c, b, b, c, d])
		# The ends, each closed with a point a little out from the last ring.
		for end: int in [0, n - 1]:
			var dir := -frames[0].z if end == 0 else frames[n - 1].z
			var r := radii[end]
			var tip := vertex(centers[end] + dir * minf(r.x, r.y) * 0.6, dir, colors_each[end] if not colors_each.is_empty() else color, 0.0, fur, rig[end][0], rig[end][1], rig[end][2])
			for k in sides:
				var a := first + end * sides + k
				var b := first + end * sides + (k + 1) % sides
				if end == 0:
					indices.append_array([tip, b, a])
				else:
					indices.append_array([tip, a, b])

	## An ellipsoid at `at`, turned by `basis`, `radii` along its axes, all on one bone.
	func lump(at: Vector3, basis: Basis, radii: Vector3, color: Color, bone: int, fur := 1.0, glow := 0.0, rings := 7, sides := 12) -> void:
		var first := verts.size()
		for i in rings + 1:
			var v := PI * i / rings
			for k in sides:
				var u := TAU * k / sides
				var unit := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
				var off := basis * (unit * radii)
				var normal := basis * (unit / radii)
				vertex(at + off, normal, color, glow, fur, bone)
		for i in rings:
			for k in sides:
				var a := first + i * sides + k
				var b := first + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				indices.append_array([a, b, c, b, d, c])

	## A cone from `base` along `dir`, `r` wide, on `bone` (and by `w1` on `b1`).
	func spike(base: Vector3, dir: Vector3, r: float, color: Color, bone: int, fur := 1.0, sides := 5, b1 := -1, w1 := 0.0) -> void:
		var along := dir.normalized()
		var across := Vector3.UP.cross(along)
		if across.length() < 0.05:
			across = Vector3.RIGHT.cross(along)
		across = across.normalized()
		var lift := along.cross(across)
		var tip := base + dir
		for k in sides:
			var a := TAU * k / sides
			var b := TAU * (k + 1) / sides
			var pa := base + (across * cos(a) + lift * sin(a)) * r
			var pb := base + (across * cos(b) + lift * sin(b)) * r
			var mid := (a + b) * 0.5
			var normal := ((across * cos(mid) + lift * sin(mid)) * dir.length() + along * r).normalized()
			if hint_from.is_finite():
				normal = ((base - hint_from).normalized() * 0.75 + normal * 0.25 + along * 0.15).normalized()
			var i0 := vertex(pa, normal, color, 0.0, fur, bone, b1, w1)
			var i1 := vertex(pb, normal, color, 0.0, fur, bone, b1, w1)
			var i2 := vertex(tip, normal, color.lightened(0.08 * fur), 0.0, fur, bone, b1, w1)
			indices.append_array([i0, i2, i1])

	func make(kind: int, build: Dictionary, j: Dictionary) -> void:
		var alpha := kind == Baboon.Kind.ALPHA
		var fur: Color = build["fur"]
		var dark: Color = build["dark"]
		var face: Color = build["face"]
		var torso: Basis = j["torso"]
		var up := torso.y
		var side := torso.x
		var fwd := torso.z
		var chest: float = build["chest"]
		var belly: float = build["belly"]
		var haunch: float = build["haunch"]

		# --- The trunk: rump, back, chest, neck, into the skull ---
		var spine: Array = [j["tail_root"], j["pelvis"], j["mid"], j["chest"], j["neck"], j["head"]]
		var segments := [Baboon.RUMP, Baboon.BACK, Baboon.CHEST, Baboon.NECK, Baboon.HEAD]
		# Ring radii (across, up) and how far each ring's middle is raised, at
		# places along the spine (in joints: 1.0 is the pelvis, 3.0 the shoulders).
		var keys := [
			[0.0, Vector2(0.06, 0.06), 0.0],
			[0.3, Vector2(haunch * 0.9, haunch * 0.92), 0.0],
			[1.0, Vector2(haunch * 1.08, haunch * 1.05), 0.0],
			[1.55, Vector2(belly * 0.92, belly * 0.95), -0.005],
			[2.1, Vector2(belly * 1.05, belly * 1.08), -0.01],
			[2.65, Vector2(chest * 0.98, chest * 1.12), 0.0],
			[3.0, Vector2(chest * 1.0, chest * 1.12), chest * 0.18],
			[3.4, Vector2(chest * 0.82, chest * 0.95), chest * 0.2],
			[4.0, Vector2(chest * 0.5, chest * 0.58), 0.02],
			[4.6, Vector2(0.07, 0.075), 0.0],
			[5.0, Vector2(0.05, 0.05), 0.0],
		]
		var centers := PackedVector3Array()
		var radii := PackedVector2Array()
		var rig := []
		var steps := 5
		for s in segments.size():
			for k in steps:
				var t := float(s) + float(k) / steps
				if s == segments.size() - 1 and k > 3:
					break
				var a: Vector3 = spine[s]
				var b: Vector3 = spine[s + 1]
				var f := float(k) / steps
				var key := _key(keys, t)
				centers.append(a.lerp(b, f) + up * key[1])
				radii.append(key[0])
				rig.append(_blend(segments, s, f))
		tube(centers, radii, up, rig, fur, 1.0, 14)
		# A darker belly line and chest, under.
		# (the arms' and legs' tubes start inside the trunk)

		# --- Limbs ---
		var arm_r: Vector2 = build["arm"]
		var leg_r: Vector2 = build["leg"]
		for i in 4:
			var front := i < 2
			var root: Vector3 = j["roots"][i]
			var mid: Vector3 = j["mids"][i]
			var end: Vector3 = j["ends"][i]
			var upper: int = (Baboon.ARM_U if front else Baboon.LEG_U) + i % 2
			var lower: int = (Baboon.ARM_L if front else Baboon.LEG_L) + i % 2
			var body_bone: int = Baboon.CHEST if front else Baboon.RUMP
			var r: Vector2 = arm_r if front else leg_r
			var pts := PackedVector3Array()
			var rr := PackedVector2Array()
			var rg := []
			var cols := []
			var n := 6
			for k in n + 1:
				var f := float(k) / n
				pts.append(root.lerp(mid, f))
				var thick: float = lerpf(r.x * (1.35 if front else 1.55), r.x, smoothstep(0.0, 0.8, f))
				rr.append(Vector2(thick, thick * (1.0 if front else 1.15)))
				rg.append([upper, body_bone, 0.5 * (1.0 - smoothstep(0.0, 0.45, f))] if f < 0.6 else [upper, lower, 0.5 * smoothstep(0.6, 1.0, f)])
				cols.append(fur)
			for k in range(1, n + 1):
				var f := float(k) / n
				pts.append(mid.lerp(end, f))
				var thick: float = lerpf(r.y * 1.05, r.y * 0.72, f)
				rr.append(Vector2(thick, thick))
				rg.append([lower, upper, 0.5 * (1.0 - smoothstep(0.0, 0.4, f))])
				cols.append(fur.lerp(dark, 0.55 * f if front else 0.35 * f))
			tube(pts, rr, -fwd if front else fwd, rg, fur, 1.0, 10, cols)
			if front:
				# A fist, down on its knuckles.
				var hand: int = Baboon.HAND + i % 2
				var down := (end - mid).normalized()
				var fist := Basis(side, -down, side.cross(-down)).orthonormalized()
				var big := 1.25 if alpha else 1.0
				_fist(end + down * 0.01, fist, big, dark, hand)
				# Long hair down the backs of the forearms.
				for k in 4:
					var f := 0.15 + k * 0.17
					var at: Vector3 = mid.lerp(end, f) - fwd * r.y * 0.6 + side * (0.01 if i == 0 else -0.01)
					hint_from = mid.lerp(end, f) + fwd * r.y
					spike(at, (end - mid) * 0.26 - fwd * 0.05, r.y * 0.55, fur, lower)
			else:
				# A long foot, flat to the ground, toes forward.
				var foot: int = Baboon.FOOT + i % 2
				lump(end + Vector3(0.0, -0.02, 0.055), Basis.IDENTITY, Vector3(0.042, 0.028, 0.09) * (1.15 if alpha else 1.0), dark, foot, 0.25)
				# The thick hair of the thighs.
				for k in 3:
					var at: Vector3 = root.lerp(mid, 0.35 + k * 0.2) - fwd * r.x * 0.8
					hint_from = root.lerp(mid, 0.35 + k * 0.2) + fwd * r.x
					spike(at, Vector3(0.0, -0.08, -0.06) + side * (0.02 if i == 2 else -0.02), r.x * 0.45, fur, upper)
				hint_from = Vector3.INF

		# --- The tail ---
		var tail: PackedVector3Array = j["tail"]
		var tp := PackedVector3Array()
		var tr := PackedVector2Array()
		var tg := []
		var tail_r := 0.034 if alpha else 0.03
		for s in tail.size() - 1:
			for k in 3:
				var f := k / 3.0
				tp.append(tail[s].lerp(tail[s + 1], f))
				var thick := lerpf(tail_r, tail_r * 0.45, (s + f) / (tail.size() - 1))
				tr.append(Vector2(thick, thick))
				tg.append(_blend(range(Baboon.TAIL, Baboon.TAIL + tail.size() - 1), s, f))
		tp.append(tail[tail.size() - 1])
		tr.append(Vector2(tail_r * 0.4, tail_r * 0.4))
		tg.append([Baboon.TAIL + tail.size() - 2, -1, 0.0])
		tube(tp, tr, up, tg, fur, 1.0, 8)
		if not alpha:
			# The tuft at the end of a baboon's tail.
			var last := tail[tail.size() - 1]
			var before := tail[tail.size() - 2]
			for k in 4:
				spike(last - (last - before) * 0.3, (last - before).normalized() * 0.09 + Vector3(sin(k * 1.7), 0.0, cos(k * 1.7)) * 0.025, 0.02, fur, Baboon.TAIL + tail.size() - 2)

		# --- The mane: a shaggy cape over the shoulders, lying back in layers ---
		var mane: float = build["mane"]
		var shoulders: Vector3 = j["chest"]
		hint_from = shoulders - up * chest * 0.35
		var count := 150 if alpha else 55
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + kind
		for k in count:
			var u := rng.randf()
			var around := rng.randf_range(-1.75, 1.75)
			# (on the surface of the chest and back: over the top, down the sides)
			var along: Vector3 = shoulders.lerp(j["mid"], u * 0.8) + fwd * chest * 0.35
			var at := along + (up * cos(around) * (chest * 1.1 + chest * 0.12 * (1.0 - u)) + side * sin(around) * chest * 0.95)
			var out := (-fwd * 1.0 + side * sin(around) * 0.55 - up * (0.25 + 0.4 * absf(sin(around)))).normalized()
			var length := rng.randf_range(0.1, 0.2) * mane * (1.0 - 0.35 * u) + 0.03
			var tone := fur.lerp(dark, rng.randf_range(0.0, 0.3)).lerp(Color(0.62, 0.6, 0.55), rng.randf_range(0.0, 0.12) if alpha else 0.0)
			spike(at, out * length, rng.randf_range(0.022, 0.034) * mane + 0.012, tone, Baboon.MANE)
		# Up the back of the neck.
		for k in (16 if alpha else 7):
			var u := k / (16.0 if alpha else 7.0)
			var at: Vector3 = (j["chest"] as Vector3).lerp(j["neck"], u) + up * chest * (0.85 - 0.35 * u) + side * rng.randf_range(-0.06, 0.06)
			spike(at, (-fwd * 0.75 + up * 0.3 + side * rng.randf_range(-0.3, 0.3)).normalized() * rng.randf_range(0.1, 0.18) * mane, 0.04 * mane + 0.015, fur, Baboon.NECK, 1.0, 5, Baboon.MANE, 0.5)
		hint_from = Vector3.INF

		# --- The head ---
		_head(kind, build, j)

	## The head, in the head's own space (forward +Z, up +Y) put where it stands.
	func _head(kind: int, build: Dictionary, j: Dictionary) -> void:
		var alpha := kind == Baboon.Kind.ALPHA
		var hs: float = build["head"]
		var fur: Color = build["fur"]
		var dark: Color = build["dark"]
		var face: Color = build["face"]
		var nose: Color = build["nose"]
		var cheek: Color = build["cheek"]
		var h: Transform3D = j["head_xform"] * Transform3D(Basis.from_scale(Vector3.ONE * hs), Vector3.ZERO)
		var hb := h.basis.orthonormalized()
		var jx: Transform3D = j["jaw_xform"] * Transform3D(Basis.from_scale(Vector3.ONE * hs), Vector3.ZERO)
		var jb := jx.basis.orthonormalized()
		var HEAD := Baboon.HEAD
		var JAW := Baboon.JAW
		# Skull, and the heavy brow, hooded over the eyes.
		lump(h * Vector3(0.0, 0.035, -0.025), hb, Vector3(0.09, 0.084, 0.1) * hs, fur, HEAD, 1.0)
		for s: float in [1.0, -1.0]:
			lump(h * Vector3(0.036 * s, 0.066, 0.062), hb * Basis(Vector3.FORWARD, -0.35 * s) * Basis(Vector3.RIGHT, -0.2), Vector3(0.042, 0.02, 0.034) * hs, dark, HEAD, 0.5)
		lump(h * Vector3(0.0, 0.06, 0.06), hb, Vector3(0.022, 0.022, 0.03) * hs, face, HEAD, 0.1)
		# The eyes: small, deep in dark sockets under the brow, glowing like embers.
		for s: float in [1.0, -1.0]:
			lump(h * Vector3(0.036 * s, 0.043, 0.068), hb, Vector3(0.021, 0.015, 0.014) * hs, Color(0.03, 0.02, 0.02), HEAD, 0.0)
			lump(h * Vector3(0.036 * s, 0.042, 0.075), hb, Vector3(0.0095, 0.0065, 0.008) * hs, Baboon.EMBER, HEAD, 0.0, 1.0, 5, 8)
			# Ears, small and flat to the skull.
			lump(h * Vector3(0.083 * s, 0.045, -0.035), hb * Basis(Vector3.UP, 0.4 * s), Vector3(0.012, 0.03, 0.026) * hs, dark, HEAD, 0.4, 0.0, 5, 8)
		# The muzzle: long like a dog's, from under the eyes, a little down-turned.
		var muzzle := func(t: float) -> Vector3:
			return Vector3(0.0, lerpf(-0.012, -0.03, t), lerpf(0.04, 0.27, t))
		var mr := func(t: float) -> Vector2:
			return Vector2(lerpf(0.05, 0.036, t), lerpf(0.05, 0.032, t))
		var mp := PackedVector3Array()
		var mrr := PackedVector2Array()
		var mg := []
		for k in 8:
			var t := k / 7.0
			mp.append(h * muzzle.call(t))
			mrr.append(mr.call(t) * hs)
			mg.append([HEAD, -1, 0.0])
		tube(mp, mrr, hb.y, mg, face, 0.05, 12)
		# The nose: a ridge from between the eyes down the top of the muzzle to the
		# pad at its end (red on the mandrill), the nostrils in it.
		var rp := PackedVector3Array()
		var rr := PackedVector2Array()
		for k in 7:
			var t := 0.02 + k / 6.0 * 0.96
			var m: Vector3 = muzzle.call(t)
			var r: Vector2 = mr.call(t)
			rp.append(h * (m + Vector3(0.0, r.y * 0.82 + 0.008 * (1.0 - t), 0.0)))
			rr.append(Vector2(lerpf(0.016, 0.021, t), 0.012) * hs * (1.0 if alpha else 0.75))
		tube(rp, rr, hb.y, mg.slice(0, 7), nose, 0.0, 8)
		lump(h * Vector3(0.0, -0.02, 0.268), hb, Vector3(0.04, 0.034, 0.03) * hs, nose if alpha else face.lerp(nose, 0.5), HEAD, 0.0)
		for s: float in [1.0, -1.0]:
			lump(h * Vector3(0.013 * s, -0.026, 0.29), hb, Vector3(0.008, 0.006, 0.006) * hs, Color(0.05, 0.02, 0.02), HEAD, 0.0, 0.0, 4, 6)
		# The cheeks: parallel ridges down each side of the muzzle, half sunk in it
		# (blue on the mandrill; on a baboon, only the shape).
		for s: float in [1.0, -1.0]:
			for ridge in (4 if alpha else 0):
				var angle := deg_to_rad(42.0 - ridge * 22.0)
				var cp := PackedVector3Array()
				var cr := PackedVector2Array()
				for k in 7:
					var t := 0.06 + k / 6.0 * 0.72
					var m: Vector3 = muzzle.call(t)
					var r: Vector2 = mr.call(t)
					cp.append(h * (m + Vector3(s * cos(angle) * r.x * 0.97, sin(angle) * r.y * 0.97, 0.0)))
					var thick := 0.0085 * sin(PI * clampf((k + 0.5) / 7.0, 0.0, 1.0)) + 0.003
					cr.append(Vector2(thick, thick * 1.1) * hs)
				tube(cp, cr, hb.y, mg.slice(0, 7), cheek, 0.0, 6)
		# The roof of the mouth, red, and the upper fangs: long, down from the upper jaw.
		lump(h * Vector3(0.0, -0.035, 0.15), hb, Vector3(0.036, 0.012, 0.11) * hs, Baboon.GUM, HEAD, 0.0)
		var fang: float = build["fang"]
		for s: float in [1.0, -1.0]:
			spike(h * Vector3(0.029 * s, -0.028, 0.205), hb * Vector3(0.003 * s, -fang - 0.02, 0.01) * hs, 0.011 * hs, Baboon.BONE, HEAD, 0.0, 6)
			for k in 2:
				spike(h * Vector3((0.008 + k * 0.01) * s, -0.03, 0.245 - k * 0.012), hb * Vector3(0.0, -0.022, 0.0) * hs, 0.006 * hs, Baboon.BONE, HEAD, 0.0, 4)
		# The jaw, hinged under the skull: lower jaw, tongue, lower fangs, beard.
		var jp := PackedVector3Array()
		var jr := PackedVector2Array()
		var jg := []
		for k in 7:
			var t := k / 6.0
			jp.append(jx * Vector3(0.0, -0.015 - 0.008 * t, lerpf(0.0, 0.21, t)))
			jr.append(Vector2(lerpf(0.048, 0.03, t), lerpf(0.026, 0.017, t)) * hs)
			jg.append([JAW, -1, 0.0])
		tube(jp, jr, jb.y, jg, face, 0.05, 10)
		lump(jx * Vector3(0.0, -0.004, 0.11), jb, Vector3(0.03, 0.009, 0.085) * hs, Baboon.GUM.lightened(0.15), JAW, 0.0)
		for s: float in [1.0, -1.0]:
			spike(jx * Vector3(0.025 * s, -0.005, 0.17), jb * Vector3(0.0, fang * 0.5, 0.008) * hs, 0.008 * hs, Baboon.BONE, JAW, 0.0, 5)
		var beard := Baboon.BEARD if alpha else fur
		hint_from = jx * Vector3(0.0, 0.0, 0.05)
		lump(jx * Vector3(0.0, -0.04, 0.06), jb, Vector3(0.048, 0.032, 0.07) * hs, beard, JAW, 0.8)
		for k in (9 if alpha else 4):
			var x := (k / maxf((9 if alpha else 4) - 1, 1) - 0.5) * 0.08
			spike(jx * Vector3(x, -0.055, 0.07 - absf(x) * 0.5), jb * Vector3(x * 0.6, -0.065, -0.035) * hs * (1.25 if alpha else 0.7), 0.02 * hs, beard.lerp(fur, 0.15 * (k % 2)), JAW, 0.8)
		# The ruff: whiskers swept back off the cheeks, framing the face, and a crest over the crown.
		var mane: float = build["mane"]
		hint_from = h * Vector3(0.0, 0.01, -0.03)
		for s: float in [1.0, -1.0]:
			for k in (9 if alpha else 4):
				var y := 0.075 - k * (0.02 if alpha else 0.03)
				spike(h * Vector3(0.07 * s, y, 0.035 - k * 0.004), hb * Vector3(0.075 * s, -0.025 - k * 0.01, -0.12) * hs * (0.7 + 0.5 * mane), 0.028 * hs * (0.6 + 0.5 * mane), fur.lerp(beard, 0.3 + 0.1 * (k % 2)), HEAD, 1.0)
		for k in (9 if alpha else 4):
			var x := (k / maxf((9 if alpha else 4) - 1, 1) - 0.5) * 0.11
			spike(h * Vector3(x, 0.095, 0.0 - absf(x) * 0.3), hb * Vector3(x * 0.6, 0.045, -0.13) * hs * mane, 0.026 * hs, fur, HEAD, 1.0)
		hint_from = Vector3.INF

	## A fist: the back of the hand and the row of knuckles it walks on.
	func _fist(at: Vector3, basis: Basis, big: float, color: Color, bone: int) -> void:
		lump(at + basis * Vector3(0.0, 0.0, 0.0), basis, Vector3(0.045, 0.04, 0.045) * big, color, bone, 0.4)
		for k in 4:
			var x := (k - 1.5) * 0.02 * big
			lump(at + basis * Vector3(x, -0.02 * big, 0.03 * big), basis, Vector3(0.012, 0.016, 0.02) * big, color, bone, 0.1, 0.0, 5, 8)
		lump(at + basis * Vector3(0.045 * big, 0.0, 0.015 * big), basis, Vector3(0.012, 0.025, 0.012) * big, color, bone, 0.1, 0.0, 5, 8)

	## A value from `keys` ([place, radii, raise] in order of place) at `t`: [radii, raise].
	static func _key(keys: Array, t: float) -> Array:
		for i in keys.size() - 1:
			var a: Array = keys[i]
			var b: Array = keys[i + 1]
			if t <= b[0]:
				var f := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
				return [(a[1] as Vector2).lerp(b[1], f), lerpf(a[2], b[2], f)]
		var last: Array = keys.back()
		return [last[1], last[2]]

	## The weights of a ring a share `f` along segment `s` of a chain of bones: by
	## each joint it is half on either bone.
	static func _blend(chain: Array, s: int, f: float) -> Array:
		if f > 0.6 and s + 1 < chain.size():
			return [chain[s], chain[s + 1], 0.5 * smoothstep(0.6, 1.0, f)]
		if f < 0.4 and s > 0:
			return [chain[s], chain[s - 1], 0.5 * (1.0 - smoothstep(0.0, 0.4, f))]
		return [chain[s], -1, 0.0]
