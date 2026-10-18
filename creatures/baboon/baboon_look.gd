class_name BaboonLook
## What a Baboon (creatures/baboon/baboon.gd) is made of, to look at: one
## skinned mesh for each kind, made here in code, and one material.
##
## The mesh is built round the baboon's skeleton as it stands (the joints
## Baboon works out for its standing pose):
## - The trunk is one smooth tube lofted through rump, back, chest and neck
##   into the skull; each limb a tube from shoulder or hip through elbow or knee
##   to the wrist or ankle; the tail a tube along its bones. The coat is dark on
##   the back and shades smoothly to a paler belly and inner limbs; the rump is
##   pale (with, on the mandrill, a blue-purple patch).
## - The hands have fingers curled under to walk on the knuckles; the feet
##   have toes.
## - The head: a skull, a heavy brow arched over deep-set eyes that glow like
##   embers, and a long dog's muzzle sculpted as one surface: on the mandrill a
##   smooth red ridge down the middle to a red, rounded nose, and either side a
##   swollen, grooved cheek pad, blue; on a baboon, plain and dark. A hinged
##   jaw, gums, long upper canines, and a pale beard.
## - The mane: a shaggy cape over the shoulders and neck (and a ruff round the
##   face), made of many small tapering clumps lying back over one another.
##   Each clump is shaded as if it were part of the round surface under it
##   (its normals are bent out from the body's middle), so the cape takes the
##   light as one soft mass and only its edges are ragged.
## Each vertex is weighted to one or two of the skeleton's bones (all children
## of the skeleton itself: see Baboon.BONES), so it bends smoothly at every
## joint. A whole baboon is one draw.
##
## Vertex colours carry the colours; UV carries how much a vertex glows (x: the
## eyes) and how much it is fur (y: fur is faintly streaked and has a paler
## backlit fringe, skin and teeth are plain); UV2 is where it was on the
## standing body, so the streaks stay put on it as it moves.
##
## Shading is cel shading in two hard tones with a one-pixel edge and a rim of
## light at grazing angles, so it sits with a cel-shaded cast without needing
## their scripts.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.55;
uniform float flatness = 0.65;
uniform float rim_gain = 0.55;
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
	// Fine streaks in the fur, running along the body.
	float streak = noise(UV2 * vec2(70.0, 10.0));
	float shade = 1.0 + (streak - 0.5) * 0.22 * furry;
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
	// Shadows (its own above all: the mane on its back) only dim it, so that
	// the coat does not break up into patches; the turn away from the light cuts.
	float lit = cut(facing, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	// The fur's rim is a paler shade of itself: the backlit fringe of a coat.
	SPECULAR_LIGHT += rim * rim_gain * mix(ALBEDO * 0.6, vec3(0.75, 0.72, 0.62), 0.45 * furry) * strength * LIGHT_COLOR / PI;
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
	var rng := RandomNumberGenerator.new()

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

	## Frames along a line of `centers`: x across, y as near `up` as can be, z along.
	static func _frames(centers: PackedVector3Array, up: Vector3) -> Array[Basis]:
		var n := centers.size()
		var frames: Array[Basis] = []
		for i in n:
			var along := (centers[mini(i + 1, n - 1)] - centers[maxi(i - 1, 0)]).normalized()
			var across := up.cross(along)
			if across.length() < 0.01:
				across = Vector3.RIGHT
			across = across.normalized()
			frames.append(Basis(across, along.cross(across).normalized(), along))
		return frames

	## A tube through `centers`, `radii` (x across, y the other way) at each, its
	## rings turned so their y lies along `up` as near as can be. `rig` for each
	## ring: [bone, other bone, weight of the other]. `paint`, if given, colours
	## each vertex: paint(ring, normal) -> Color. Closed at both ends.
	func tube(centers: PackedVector3Array, radii: PackedVector2Array, up: Vector3, rig: Array, color: Color, fur := 1.0, sides := 12, paint := Callable()) -> void:
		var n := centers.size()
		var first := verts.size()
		var frames := _frames(centers, up)
		for i in n:
			var r := radii[i]
			for k in sides:
				var a := TAU * k / sides
				var off := frames[i].x * cos(a) * r.x + frames[i].y * sin(a) * r.y
				var normal := (frames[i].x * cos(a) / maxf(r.x, 0.001) + frames[i].y * sin(a) / maxf(r.y, 0.001)).normalized()
				var c: Color = paint.call(i, normal) if paint.is_valid() else color
				vertex(centers[i] + off, normal, c, 0.0, fur, rig[i][0], rig[i][1], rig[i][2])
		_join(first, n, sides)
		_caps(first, n, sides, centers, radii, frames, rig, fur, paint, color)

	## A tube whose every point is placed by `shape`: shape(ring, angle) -> [offset
	## from the ring's middle in its frame (x across, y up, z along), colour, fur].
	## Its normals are worked out from the surface.
	func sculpt(centers: PackedVector3Array, up: Vector3, rig: Array, sides: int, shape: Callable) -> void:
		var n := centers.size()
		var first := verts.size()
		var frames := _frames(centers, up)
		var grid: Array[PackedVector3Array] = []
		var paint: Array[Array] = []
		for i in n:
			var ring := PackedVector3Array()
			var cols := []
			for k in sides:
				var got: Array = shape.call(i, TAU * k / sides)
				var off: Vector3 = got[0]
				ring.append(centers[i] + frames[i] * off)
				cols.append([got[1], got[2]])
			grid.append(ring)
			paint.append(cols)
		for i in n:
			for k in sides:
				var around := grid[i][(k + 1) % sides] - grid[i][(k - 1 + sides) % sides]
				var along := grid[mini(i + 1, n - 1)][k] - grid[maxi(i - 1, 0)][k]
				var normal := along.cross(around)
				if normal.length() < 0.000001 or normal.dot(grid[i][k] - centers[i]) < 0.0:
					normal = -normal
				if normal.length() < 0.000001:
					normal = frames[i].z if i == n - 1 else -frames[i].z
				vertex(grid[i][k], normal, paint[i][k][0], 0.0, paint[i][k][1], rig[i][0], rig[i][1], rig[i][2])
		_join(first, n, sides)
		# (the first ring is closed with a point; the last comes to one already)
		var tip := vertex(centers[0] - frames[0].z * 0.01, -frames[0].z, paint[0][0][0], 0.0, paint[0][0][1], rig[0][0], rig[0][1], rig[0][2])
		for k in sides:
			indices.append_array([tip, first + (k + 1) % sides, first + k])

	func _join(first: int, rings: int, sides: int) -> void:
		for i in rings - 1:
			for k in sides:
				var a := first + i * sides + k
				var b := first + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				indices.append_array([a, c, b, b, c, d])

	func _caps(first: int, n: int, sides: int, centers: PackedVector3Array, radii: PackedVector2Array, frames: Array[Basis], rig: Array, fur: float, paint: Callable, color: Color) -> void:
		for end: int in [0, n - 1]:
			var dir := -frames[0].z if end == 0 else frames[n - 1].z
			var r := radii[end]
			var c: Color = paint.call(end, dir) if paint.is_valid() else color
			var tip := vertex(centers[end] + dir * minf(r.x, r.y) * 0.6, dir, c, 0.0, fur, rig[end][0], rig[end][1], rig[end][2])
			for k in sides:
				var a := first + end * sides + k
				var b := first + end * sides + (k + 1) % sides
				if end == 0:
					indices.append_array([tip, b, a])
				else:
					indices.append_array([tip, a, b])

	## An ellipsoid at `at`, turned by `basis`, `radii` along its axes, on one bone.
	func lump(at: Vector3, basis: Basis, radii: Vector3, color: Color, bone: int, fur := 1.0, glow := 0.0, rings := 7, sides := 12) -> void:
		var first := verts.size()
		for i in rings + 1:
			var v := PI * i / rings
			for k in sides:
				var u := TAU * k / sides
				var unit := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
				vertex(at + basis * (unit * radii), basis * (unit / radii), color, glow, fur, bone)
		for i in rings:
			for k in sides:
				var a := first + i * sides + k
				var b := first + i * sides + (k + 1) % sides
				var c := a + sides
				var d := b + sides
				indices.append_array([a, b, c, b, d, c])

	## A cone from `base` along `dir`, `r` wide (and `flat` as thick the other way), on `bone`.
	func spike(base: Vector3, dir: Vector3, r: float, color: Color, bone: int, fur := 0.0, sides := 6) -> void:
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
			var mid := (a + b) * 0.5
			var normal := ((across * cos(mid) + lift * sin(mid)) * dir.length() + along * r).normalized()
			var i0 := vertex(base + (across * cos(a) + lift * sin(a)) * r, normal, color, 0.0, fur, bone)
			var i1 := vertex(base + (across * cos(b) + lift * sin(b)) * r, normal, color, 0.0, fur, bone)
			var i2 := vertex(tip, normal, color, 0.0, fur, bone)
			indices.append_array([i0, i2, i1])

	## A clump of fur: a flattened, tapering, slightly curled tuft from `base`
	## along `dir`, `width` across, lying on a surface whose outward way is
	## `out`. Every vertex is shaded as that surface (`out`, a little towards
	## the tip), so the clumps of a mane take the light together.
	func clump(base: Vector3, dir: Vector3, width: float, out: Vector3, color: Color, bone: int, b1 := -1, w1 := 0.0) -> void:
		var along := dir.normalized()
		var across := out.cross(along)
		if across.length() < 0.01:
			across = Vector3.UP.cross(along)
		across = across.normalized()
		var lift := along.cross(across).normalized()
		if lift.dot(out) < 0.0:
			lift = -lift
		var length := dir.length()
		var normal := (out.normalized() + along * 0.25).normalized()
		var tip_color := color.lightened(0.06)
		# A section of four points (wide and thin), at the root and halfway, then the point.
		var sections := [[0.0, 1.0], [0.5, 0.62]]
		var first := verts.size()
		for s in sections:
			var f: float = s[0]
			var w: float = width * 0.5 * s[1]
			var at: Vector3 = base + along * length * f + lift * width * 0.35 * f * f
			for p: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
				vertex(at + across * p.x * w + lift * p.y * w * 0.35, normal, color.lerp(tip_color, f), 0.0, 1.0, bone, b1, w1)
		var tip := vertex(base + along * length + lift * width * 0.35, normal, tip_color, 0.0, 1.0, bone, b1, w1)
		for k in 4:
			var a := first + k
			var b := first + (k + 1) % 4
			indices.append_array([a, a + 4, b, b, a + 4, b + 4])
			indices.append_array([a + 4, tip, b + 4])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	func make(kind: int, build: Dictionary, j: Dictionary) -> void:
		rng.seed = 11 + kind
		var alpha := kind == Baboon.Kind.ALPHA
		var fur: Color = build["fur"]
		var belly_fur: Color = build["belly_fur"]
		var dark: Color = build["dark"]
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
			[0.0, Vector2(0.05, 0.05), 0.0],
			[0.3, Vector2(haunch * 0.92, haunch * 0.9), 0.0],
			[1.0, Vector2(haunch * 1.08, haunch * 1.05), 0.0],
			[1.6, Vector2(belly * 0.9, belly * 0.95), 0.0],
			[2.2, Vector2(belly * 1.05, belly * 1.1), -0.005],
			[2.7, Vector2(chest * 1.0, chest * 1.12), 0.0],
			[3.0, Vector2(chest * 1.04, chest * 1.12), chest * 0.2],
			[3.4, Vector2(chest * 0.85, chest * 0.95), chest * 0.22],
			[4.0, Vector2(chest * 0.66, chest * 0.72), 0.02],
			[4.6, Vector2(0.085, 0.09), 0.0],
			[5.0, Vector2(0.05, 0.05), 0.0],
		]
		var centers := PackedVector3Array()
		var radii := PackedVector2Array()
		var rig := []
		var places := PackedFloat32Array()
		for s in segments.size():
			for k in 5:
				var t := float(s) + k / 5.0
				if s == segments.size() - 1 and k > 3:
					break
				var a: Vector3 = spine[s]
				var b: Vector3 = spine[s + 1]
				var key := _key(keys, t)
				centers.append(a.lerp(b, k / 5.0) + up * key[1])
				radii.append(key[0])
				rig.append(_blend(segments, s, k / 5.0))
				places.append(t)
		var rump: Color = build["rump"]
		var patch: Color = build["rump_patch"]
		var coat := func(i: int, n: Vector3) -> Color:
			# Dark along the back, paler under the belly; a pale rump (and the mandrill's patch).
			var c := fur.lerp(belly_fur, smoothstep(-0.1, 0.75, -n.dot(up)))
			var behind := smoothstep(0.2, 0.9, -n.dot(fwd)) * (1.0 - smoothstep(0.6, 1.2, places[i]))
			c = c.lerp(rump, behind * 0.85)
			if patch.a > 0.0:
				c = c.lerp(patch, behind * smoothstep(0.55, 0.9, -n.dot(fwd)) * 0.55)
			return c
		tube(centers, radii, up, rig, fur, 1.0, 16, coat)

		# --- Limbs ---
		var arm_r: Vector2 = build["arm"]
		var leg_r: Vector2 = build["leg"]
		for i in 4:
			var front := i < 2
			var sign := 1.0 if i % 2 == 0 else -1.0
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
			var along := PackedFloat32Array()
			var n := 6
			for k in n + 1:
				var f := float(k) / n
				# (the first ring is sunk into the body, so the end of the tube is never seen)
				pts.append(root.lerp(mid, f) if k > 0 else root + (root - mid).normalized() * r.x * 0.5 - side * sign * r.x * 1.1)
				# (powerful at the shoulder, meaty at the thigh)
				var thick: float = lerpf(r.x * (1.45 if front else 1.6), r.x, smoothstep(0.0, 0.85, f))
				rr.append(Vector2(thick, thick * (1.05 if front else 1.2)))
				rg.append([upper, body_bone, 0.5 * (1.0 - smoothstep(0.0, 0.45, f))] if f < 0.6 else [upper, lower, 0.5 * smoothstep(0.6, 1.0, f)])
				along.append(f * 0.5)
			for k in range(1, n + 1):
				var f := float(k) / n
				pts.append(mid.lerp(end, f))
				var thick: float = lerpf(r.y * 1.08, r.y * 0.74, f) if front else lerpf(r.y * 1.15, r.y * 0.7, f)
				rr.append(Vector2(thick, thick))
				rg.append([lower, upper, 0.5 * (1.0 - smoothstep(0.0, 0.4, f))])
				along.append(0.5 + f * 0.5)
			var inward := -side * sign
			var limb_coat := func(ring: int, nrm: Vector3) -> Color:
				# Paler on the inside of the limb, darker towards the hands and feet.
				var c := fur.lerp(belly_fur, smoothstep(0.0, 0.8, nrm.dot(inward)) * 0.8)
				return c.lerp(dark, smoothstep(0.65, 1.0, along[ring]) * (0.55 if front else 0.4))
			tube(pts, rr, -fwd if front else fwd, rg, fur, 1.0, 12, limb_coat)
			if front:
				var hand: int = Baboon.HAND + i % 2
				var down := (end - mid).normalized()
				var palm := Basis(side, -down, side.cross(-down)).orthonormalized()
				_hand(end, palm, 1.3 if alpha else 1.0, dark, hand, sign)
				# Long hair hanging off the backs of the forearms.
				for k in 5:
					var f := 0.1 + k * 0.15
					var axis: Vector3 = mid.lerp(end, f)
					var out := (-fwd + side * sign * 0.4).normalized()
					clump(axis + out * r.y * 0.8, (end - mid) * 0.22 - fwd * 0.03, r.y * 1.1, out, fur.lerp(build["mane_fur"], 0.3), lower)
			else:
				var foot: int = Baboon.FOOT + i % 2
				_foot(end, 1.2 if alpha else 1.0, dark, foot)

		# --- The tail, short and arched ---
		var tail: PackedVector3Array = j["tail"]
		var tp := PackedVector3Array()
		var tr := PackedVector2Array()
		var tg := []
		var tail_r := 0.04 if alpha else 0.03
		for s in tail.size() - 1:
			for k in 3:
				var f := k / 3.0
				tp.append(tail[s].lerp(tail[s + 1], f))
				var thick := lerpf(tail_r, tail_r * 0.5, (s + f) / (tail.size() - 1))
				tr.append(Vector2(thick, thick))
				tg.append(_blend(range(Baboon.TAIL, Baboon.TAIL + tail.size() - 1), s, f))
		tp.append(tail[tail.size() - 1])
		tr.append(Vector2(tail_r * 0.45, tail_r * 0.45))
		tg.append([Baboon.TAIL + tail.size() - 2, -1, 0.0])
		tube(tp, tr, up, tg, fur, 1.0, 8)
		var last := tail[tail.size() - 1]
		var before := tail[tail.size() - 2]
		for k in 5:
			var out := Vector3(sin(k * 1.3), 0.3, cos(k * 1.3)).normalized()
			clump(last - (last - before) * 0.4, (last - before).normalized() * (0.06 if alpha else 0.08) + out * 0.015, 0.03, out, fur, Baboon.TAIL + tail.size() - 2)

		# --- The mane: a shaggy cape over the shoulders and neck ---
		var mane: float = build["mane"]
		var mane_fur: Color = build["mane_fur"]
		var shoulders: Vector3 = j["chest"]
		var rows := 9 if alpha else 6
		for row in rows:
			var u := float(row) / (rows - 1)
			# Rows from the nape back over the shoulders to the middle of the back,
			# each round the body; further back, the hair is longer and hangs lower.
			var axis: Vector3 = (j["neck"] as Vector3).lerp(shoulders, minf(u * 2.0, 1.0)).lerp(j["mid"], maxf(u * 2.0 - 1.0, 0.0) * 0.8)
			axis -= up * chest * 0.15
			var ring_r := lerpf(chest * 0.7, chest * 1.05, minf(u * 2.0, 1.0))
			var count := int((22 if alpha else 13) + u * (16 if alpha else 6))
			var spread := lerpf(1.5, 2.0, u) if alpha else lerpf(1.2, 1.5, u)
			for k in count:
				var around := lerpf(-spread, spread, (k + rng.randf_range(0.2, 0.8)) / count)
				var out := (up * cos(around) + side * sin(around)).normalized()
				var at := axis + out * ring_r * rng.randf_range(0.92, 1.02)
				var hang := (-fwd * 0.85 - up * (0.15 + 0.5 * absf(sin(around))) + side * sin(around) * 0.25).normalized()
				var length := (lerpf(0.07, 0.17, u) + rng.randf_range(0.0, 0.05)) * mane * (1.0 + 0.4 * absf(sin(around)))
				var tone := mane_fur.lerp(fur, rng.randf_range(0.0, 0.35)).lightened(rng.randf_range(0.0, 0.06))
				var bone := Baboon.NECK if u < 0.2 else Baboon.MANE
				clump(at, hang * (length + 0.02), rng.randf_range(0.03, 0.045) * (0.7 + 0.4 * mane), out, tone, bone, Baboon.MANE if bone == Baboon.NECK else -1, 0.5)
		# Over the outsides of the shoulders and upper arms.
		for i in 2:
			var sign := 1.0 if i == 0 else -1.0
			var root: Vector3 = j["roots"][i]
			var elbow: Vector3 = j["mids"][i]
			for k in (10 if alpha else 5):
				var f := rng.randf_range(0.0, 0.6)
				var around := rng.randf_range(-1.2, 1.2)
				var out := (side * sign * cos(around) + -fwd * sin(around) * 0.6 + up * 0.25).normalized()
				var at := root.lerp(elbow, f) + out * arm_r.x * 1.25
				clump(at, ((elbow - root).normalized() * 0.8 - fwd * 0.3).normalized() * rng.randf_range(0.09, 0.15) * mane, 0.032 * (0.7 + 0.4 * mane), out, mane_fur.lerp(fur, rng.randf_range(0.2, 0.6)), Baboon.ARM_U + i, Baboon.MANE, 0.4)

		# The throat and the front of the neck, shaggy down to the chest.
		var beard: Color = build["beard"]
		for k in (18 if alpha else 8):
			var u := rng.randf()
			var around := rng.randf_range(PI * 0.55, PI * 1.45)
			var axis: Vector3 = (j["neck"] as Vector3).lerp(j["chest"], u * 0.7)
			var out := (up * cos(around) + side * sin(around) * 0.8 + fwd * 0.3).normalized()
			var at := axis + out * chest * lerpf(0.6, 0.95, u)
			clump(at, (-up * 0.8 - fwd * 0.4 + out * 0.2).normalized() * rng.randf_range(0.08, 0.14) * mane, 0.035 * (0.7 + 0.4 * mane), out, mane_fur.lerp(beard, rng.randf_range(0.1, 0.4) if alpha else 0.1), Baboon.NECK, Baboon.CHEST, 0.4)

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
		var mane_fur: Color = build["mane_fur"]
		var beard: Color = build["beard"]
		var h: Transform3D = j["head_xform"] * Transform3D(Basis.from_scale(Vector3.ONE * hs), Vector3.ZERO)
		var hb := h.basis.orthonormalized()
		var jx: Transform3D = j["jaw_xform"] * Transform3D(Basis.from_scale(Vector3.ONE * hs), Vector3.ZERO)
		var jb := jx.basis.orthonormalized()
		var HEAD := Baboon.HEAD
		var JAW := Baboon.JAW

		# The skull, low and long.
		lump(h * Vector3(0.0, 0.03, -0.03), hb, Vector3(0.088, 0.08, 0.1) * hs, fur, HEAD, 1.0)
		# The brow: one heavy ridge arched over the eyes.
		var brow := PackedVector3Array()
		var brow_r := PackedVector2Array()
		var brow_rig := []
		for k in 9:
			var u := (k / 8.0) * 2.0 - 1.0
			brow.append(h * Vector3(u * 0.056, 0.058 - 0.016 * u * u, 0.044 - 0.035 * u * u))
			brow_r.append(Vector2(0.024, 0.017) * hs * (1.0 - 0.3 * u * u))
			brow_rig.append([HEAD, -1, 0.0])
		tube(brow, brow_r, hb.y, brow_rig, face.lerp(fur, 0.35), 0.3, 10)
		# The eyes, deep under it in dark sockets, glowing like embers.
		for s: float in [1.0, -1.0]:
			lump(h * Vector3(0.034 * s, 0.04, 0.062), hb, Vector3(0.02, 0.015, 0.016) * hs, Color(0.03, 0.02, 0.02), HEAD, 0.0)
			lump(h * Vector3(0.034 * s, 0.04, 0.07), hb, Vector3(0.0095, 0.0068, 0.008) * hs, Baboon.EMBER, HEAD, 0.0, 1.0, 5, 8)
			lump(h * Vector3(0.08 * s, 0.04, -0.035), hb * Basis(Vector3.UP, 0.4 * s), Vector3(0.012, 0.028, 0.024) * hs, dark, HEAD, 0.4, 0.0, 5, 8)

		# The muzzle: one sculpted surface, from under the eyes to a rounded nose.
		var length := 0.215 if alpha else 0.22
		var muzzle_at := func(t: float) -> Vector3:
			return Vector3(0.0, lerpf(0.004, -0.028, t), lerpf(0.035, 0.035 + length, t))
		var base_r := func(t: float) -> Vector2:
			if alpha:
				return Vector2(lerpf(0.05, 0.033, t), lerpf(0.047, 0.03, t))
			return Vector2(lerpf(0.043, 0.026, t), lerpf(0.043, 0.027, t))
		var rings := 16
		var m_centers := PackedVector3Array()
		var m_rig := []
		for i in rings:
			m_centers.append(h * muzzle_at.call(float(i) / (rings - 1)))
			m_rig.append([HEAD, -1, 0.0])
		var shape := func(i: int, angle: float) -> Array:
			var t := float(i) / (rings - 1)
			var r: Vector2 = base_r.call(t) * hs
			# (rounded off at the nose)
			var round_off := sqrt(maxf(0.0, 1.0 - pow(maxf(t - 0.84, 0.0) / 0.16, 2.0)))
			var c := cos(angle)
			var s := sin(angle)
			# How far up from the side this point is (0 at the side, PI/2 on top).
			var phi := atan2(s, absf(c))
			var pad := exp(-pow((phi - 0.32) / 0.5, 2.0)) * pow(sin(PI * clampf((t - 0.02) / 0.82, 0.0, 1.0)), 0.6)
			var ribs := 0.5 - 0.5 * cos((phi + 0.6) * 12.0)
			var ridge := exp(-pow((phi - PI * 0.5) / 0.2, 2.0))
			var swell := 1.0
			var colour := face
			var furriness := 0.05
			if alpha:
				swell += pad * (0.62 - 0.2 * ribs) + ridge * 0.2 * (1.0 - 0.5 * t)
				if pad > 0.3 and t < 0.86:
					colour = cheek * lerpf(0.45, 1.0, 1.0 - ribs * smoothstep(0.3, 0.6, pad))
				if ridge > 0.4 or (t > 0.8 and s > -0.35):
					colour = nose
				elif ridge > 0.25:
					colour = nose.lerp(face, 0.5)
			else:
				swell += pad * 0.12 + ridge * 0.05
				if t > 0.88 and s > -0.4:
					colour = face.darkened(0.3)
			# The upper lip, dark, under it all.
			if s < -0.55:
				colour = face
			var off := Vector3(c * r.x, s * r.y, 0.0) * swell * round_off
			off.z = (1.0 - round_off) * 0.01 * hs
			return [off, colour, furriness]
		sculpt(m_centers, hb.y, m_rig, 64, shape)
		# The nostrils.
		var tip_at: Vector3 = muzzle_at.call(0.97)
		for s: float in [1.0, -1.0]:
			lump(h * (tip_at + Vector3(0.011 * s, -0.004, 0.01)), hb, Vector3(0.007, 0.005, 0.005) * hs, Color(0.05, 0.02, 0.02), HEAD, 0.0, 0.0, 4, 6)

		# The roof of the mouth, red; long upper canines down past the lip, and the front teeth.
		lump(h * Vector3(0.0, -0.038, 0.15), hb, Vector3(0.03, 0.01, 0.1) * hs, Baboon.GUM, HEAD, 0.0)
		var fang: float = build["fang"]
		var canine_at: Vector3 = muzzle_at.call(0.7)
		var canine_r: Vector2 = base_r.call(0.7)
		for s: float in [1.0, -1.0]:
			var base := canine_at + Vector3(canine_r.x * 0.62 * s, -canine_r.y * 0.75, 0.0)
			spike(h * base, hb * Vector3(0.004 * s, -fang - 0.025, -0.012) * hs, 0.011 * hs, Baboon.BONE, HEAD, 0.0, 6)
			for k in 2:
				var front_tooth: Vector3 = muzzle_at.call(0.9) + Vector3((0.006 + k * 0.009) * s, -canine_r.y * 0.8, -k * 0.008)
				spike(h * front_tooth, hb * Vector3(0.0, -0.02, 0.0) * hs, 0.005 * hs, Baboon.BONE, HEAD, 0.0, 4)

		# The jaw, hinged under the skull: lower jaw, tongue, lower canines, beard.
		var jp := PackedVector3Array()
		var jr := PackedVector2Array()
		var jg := []
		for k in 7:
			var t := k / 6.0
			jp.append(jx * Vector3(0.0, -0.014 - 0.006 * t, lerpf(0.0, length * 0.86, t)))
			jr.append(Vector2(lerpf(0.042, 0.026, t), lerpf(0.024, 0.016, t)) * hs)
			jg.append([JAW, -1, 0.0])
		tube(jp, jr, jb.y, jg, face, 0.05, 12)
		lump(jx * Vector3(0.0, -0.003, 0.11), jb, Vector3(0.026, 0.008, 0.08) * hs, Baboon.GUM.lightened(0.15), JAW, 0.0)
		for s: float in [1.0, -1.0]:
			spike(jx * Vector3(0.021 * s, -0.004, length * 0.62), jb * Vector3(0.0, fang * 0.45, 0.006) * hs, 0.008 * hs, Baboon.BONE, JAW, 0.0, 5)
		# The beard, pale, under the jaw and back along it.
		for k in (16 if alpha else 7):
			var u := rng.randf_range(-1.0, 1.0)
			var t := rng.randf_range(0.0, 0.7)
			var at := jx * Vector3(u * 0.03, -0.03, t * length * 0.8)
			var out := (jb * Vector3(u * 0.6, -1.0, 0.1)).normalized()
			clump(at, (jb * Vector3(u * 0.3, -0.7, -0.6)).normalized() * rng.randf_range(0.05, 0.09) * hs * (1.2 if alpha else 0.8), 0.035 * hs, out, beard.lerp(mane_fur, rng.randf_range(0.0, 0.3)), JAW)
		# The ruff: whiskers swept back off the cheeks, framing the face; a crest on the crown.
		var mane: float = build["mane"]
		for s: float in [1.0, -1.0]:
			for k in (11 if alpha else 6):
				var y := rng.randf_range(-0.05, 0.07)
				var at := h * Vector3(0.068 * s, y, rng.randf_range(-0.02, 0.03))
				var out := (hb * Vector3(s, y * 4.0, -0.2)).normalized()
				var col := mane_fur.lerp(beard, 0.35 if alpha else 0.15).lerp(fur, rng.randf_range(0.0, 0.3))
				clump(at, (hb * Vector3(0.5 * s, -0.25 - y, -1.0)).normalized() * rng.randf_range(0.08, 0.13) * hs * (0.7 + 0.5 * mane), 0.045 * hs, out, col, HEAD)
		for k in (9 if alpha else 5):
			var x := rng.randf_range(-0.06, 0.06)
			var at := h * Vector3(x, 0.085, rng.randf_range(-0.05, 0.03))
			clump(at, (hb * Vector3(x * 2.0, 0.25, -1.0)).normalized() * rng.randf_range(0.08, 0.12) * hs * mane, 0.04 * hs, (hb * Vector3(x * 4.0, 1.0, -0.2)).normalized(), mane_fur.lerp(fur, rng.randf_range(0.2, 0.6)), HEAD)

	## A hand walking on its knuckles: the back of the hand, four fingers curled
	## under it, and a thumb. `palm`: x out to the side, y up the forearm, z ahead.
	func _hand(wrist: Vector3, palm: Basis, big: float, color: Color, bone: int, sign: float) -> void:
		lump(wrist + palm * Vector3(0.0, -0.005, 0.012) * big, palm, Vector3(0.042, 0.03, 0.042) * big, color, bone, 0.3)
		for k in 4:
			var x := (k - 1.5) * 0.019 * big
			var pts := PackedVector3Array([
				wrist + palm * Vector3(x, -0.012, 0.03) * big,
				wrist + palm * Vector3(x * 1.05, -0.03, 0.052) * big,
				wrist + palm * Vector3(x * 1.05, -0.045, 0.04) * big,
				wrist + palm * Vector3(x, -0.046, 0.018) * big])
			var rr := PackedVector2Array([Vector2(0.011, 0.011) * big, Vector2(0.011, 0.011) * big, Vector2(0.01, 0.01) * big, Vector2(0.008, 0.008) * big])
			tube(pts, rr, palm.z, [[bone, -1, 0.0], [bone, -1, 0.0], [bone, -1, 0.0], [bone, -1, 0.0]], color, 0.1, 6)
		var thumb := PackedVector3Array([wrist + palm * Vector3(0.03 * sign, -0.005, 0.02) * big, wrist + palm * Vector3(0.036 * sign, -0.03, 0.035) * big, wrist + palm * Vector3(0.03 * sign, -0.042, 0.04) * big])
		tube(thumb, PackedVector2Array([Vector2(0.01, 0.01) * big, Vector2(0.009, 0.009) * big, Vector2(0.007, 0.007) * big]), palm.z, [[bone, -1, 0.0], [bone, -1, 0.0], [bone, -1, 0.0]], color, 0.1, 6)

	## A long hind foot flat on the ground, toes forward.
	func _foot(ankle: Vector3, big: float, color: Color, bone: int) -> void:
		lump(ankle + Vector3(0.0, -0.022, 0.04) * big, Basis.IDENTITY, Vector3(0.036, 0.024, 0.07) * big, color, bone, 0.25)
		for k in 4:
			var x := (k - 1.5) * 0.016 * big
			var pts := PackedVector3Array([ankle + Vector3(x, -0.03, 0.085) * big, ankle + Vector3(x * 1.1, -0.036, 0.115) * big, ankle + Vector3(x * 1.1, -0.045, 0.13) * big])
			tube(pts, PackedVector2Array([Vector2(0.009, 0.009) * big, Vector2(0.008, 0.008) * big, Vector2(0.006, 0.006) * big]), Vector3.UP, [[bone, -1, 0.0], [bone, -1, 0.0], [bone, -1, 0.0]], color, 0.1, 6)

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
