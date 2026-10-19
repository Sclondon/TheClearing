class_name WyvernNest
extends MeshInstance3D
## A wyvern's nest: a great untidy ring of sticks and broken branches heaped on
## a wall top, about 5 m across and knee high, the hollow in the middle lined
## with what they have brought back: long bones, ribs, a skull or two, antlers.
## Made in code (nothing to load), one mesh shared by every nest, one draw.
## Its origin is the middle of its floor; put it on the stone.

const RADIUS := 2.5

static var _mesh: ArrayMesh


func _ready() -> void:
	mesh = shape()
	material_override = WyvernLook.nest_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## The one mesh every nest draws.
static func shape() -> ArrayMesh:
	if _mesh:
		return _mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The rim: sticks laid round and across one another, in rings, highest at the edge.
	for layer in 4:
		var count := 26 + layer * 4
		for k in count:
			var a := TAU * (k + rng.randf()) / count
			var r := lerpf(RADIUS * 0.62, RADIUS * 0.95, rng.randf()) - layer * 0.12
			var at := Vector3(cos(a) * r, 0.08 + layer * 0.13 + rng.randf() * 0.06, sin(a) * r)
			# (roughly round the ring, tilted every way)
			var along := Vector3(-sin(a), rng.randf_range(-0.25, 0.25), cos(a)).rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)).normalized()
			var length := rng.randf_range(1.0, 2.2)
			var thick := rng.randf_range(0.035, 0.08)
			var shade := rng.randf_range(0.11, 0.17)
			_stick(st, at - along * length * 0.5, at + along * length * 0.5, thick, Color(shade, shade * 0.95, shade * 0.88))
			# (now and then a broken branch sticking out of it)
			if rng.randf() < 0.18:
				var out := Vector3(cos(a), rng.randf_range(0.1, 0.5), sin(a)).normalized()
				_stick(st, at, at + out * rng.randf_range(0.6, 1.2), thick * 0.7, Color(shade * 0.9, shade * 0.85, shade * 0.8))
	# The floor of it: shorter sticks and twigs, flat.
	for k in 26:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * RADIUS * 0.6
		var at := Vector3(cos(a) * r, 0.04, sin(a) * r)
		var along := Vector3(cos(rng.randf() * TAU), 0.0, sin(rng.randf() * TAU))
		var length := rng.randf_range(0.5, 1.1)
		var shade := rng.randf_range(0.1, 0.15)
		_stick(st, at - along * length * 0.5, at + along * length * 0.5, 0.03, Color(shade, shade * 0.95, shade * 0.88))
	# What they have brought back: long bones, ribs, skulls, an antler.
	var bone := Color(0.42, 0.4, 0.36)
	for k in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, RADIUS * 0.75)
		var at := Vector3(cos(a) * r, 0.12 + rng.randf() * 0.15, sin(a) * r)
		var along := Vector3(cos(rng.randf() * TAU), rng.randf_range(-0.2, 0.3), sin(rng.randf() * TAU)).normalized()
		var length := rng.randf_range(0.45, 0.8)
		var shade := bone * rng.randf_range(0.8, 1.05)
		_stick(st, at - along * length * 0.5, at + along * length * 0.5, 0.035, shade)
		# (the knobbed ends)
		_ball(st, at - along * length * 0.5, 0.06, shade)
		_ball(st, at + along * length * 0.5, 0.06, shade)
	for k in 2:
		# Ribs: a row of curved bones off a spine.
		var a := rng.randf() * TAU
		var middle := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.4, 1.2) + Vector3.UP * 0.1
		var along := Vector3(-sin(a), 0.0, cos(a))
		for n in 6:
			var root := middle + along * (n - 2.5) * 0.14
			var side := along.cross(Vector3.UP)
			var was := root
			for s in 4:
				var t := (s + 1) / 4.0
				var p := root + side * sin(t * 1.6) * 0.45 + Vector3.UP * sin(t * PI) * 0.22
				_stick(st, was, p, 0.018, bone * 0.95)
				was = p
	for k in 3:
		# Skulls: a rounded brainpan, the snout, the dark sockets.
		var a := rng.randf() * TAU
		var at := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.3, 1.5) + Vector3.UP * 0.18
		var facing := Vector3(cos(rng.randf() * TAU), 0.0, sin(rng.randf() * TAU))
		_ball(st, at, 0.16, bone)
		_stick(st, at, at + facing * 0.3 + Vector3.DOWN * 0.06, 0.08, bone * 0.95)
		var across := facing.cross(Vector3.UP)
		for s: float in [-1.0, 1.0]:
			_ball(st, at + facing * 0.11 + across * s * 0.07 + Vector3.UP * 0.05, 0.045, Color(0.04, 0.035, 0.03))
		if k == 0:
			# (an antler, off the skull of a deer)
			var root := at + Vector3.UP * 0.12
			var tine := root + Vector3(across.x * 0.3, 0.35, across.z * 0.3) - facing * 0.15
			_stick(st, root, tine, 0.03, bone * 0.85)
			_stick(st, root.lerp(tine, 0.5), root.lerp(tine, 0.5) + facing * 0.2 + Vector3.UP * 0.15, 0.022, bone * 0.85)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


## A stick from `a` to `b`, `thick` across: a five-sided prism, its ends capped.
static func _stick(st: SurfaceTool, a: Vector3, b: Vector3, thick: float, colour: Color) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(along)
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for k in 5:
		var angle := TAU * k / 5.0
		var off := (side * cos(angle) + up * sin(angle)) * thick * 0.5
		ring_a.append(a + off)
		ring_b.append(b + off * 0.8)
	st.set_color(colour)
	for k in 5:
		var n := (k + 1) % 5
		_tri(st, ring_a[k], ring_b[k], ring_b[n])
		_tri(st, ring_a[k], ring_b[n], ring_a[n])
	for k in range(1, 4):
		_tri(st, ring_a[0], ring_a[k + 1], ring_a[k])
		_tri(st, ring_b[0], ring_b[k], ring_b[k + 1])


## A small rough ball (an octahedron, a little bigger at its middle).
static func _ball(st: SurfaceTool, at: Vector3, radius: float, colour: Color) -> void:
	var points := [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	var faces := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 4, 2], [1, 3, 4], [1, 5, 3], [1, 2, 5]]
	st.set_color(colour)
	for f: Array in faces:
		_tri(st, at + points[f[0]] * radius, at + points[f[1]] * radius, at + points[f[2]] * radius)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
