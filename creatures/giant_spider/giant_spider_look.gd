class_name GiantSpiderLook
## What a GiantSpider is made of, to look at. Every mesh is worked out here in
## code, once, and shared by every spider; nothing is a picture.
##
## - The front body (cephalothorax): a low, flattened dome, raised at the front
##   into a mound that carries eight eyes, with pale grooves running out from a
##   pit in its middle. The eyes are a second surface of the same mesh.
## - The back body (abdomen): a great hairy egg, slung from a narrow waist,
##   dark, with a ladder of pale chevrons down its back.
## - Every leg part, the feelers (pedipalps) and the jaws (chelicerae) are one
##   shape, a tapered, hairy bar with a pale ring round its far end (the knee
##   bands of a tarantula), drawn as one MultiMesh: a single draw however many
##   parts there are. The fangs are a second MultiMesh of a curved spike.
## - The silk thread is one thin cylinder, stretched.
##
## The hide is lit like the game's figures (hard bands of light, after
## scripts/toon.gd in The Clearing) with a broken, pale fuzz round its edges,
## so that it reads as hair against the mist; the eyes and fangs are glossy
## black, and catch the light in hard glints.
##
## Body space is forward -Z, up +Y, the middle of the front body at the origin,
## at size 1 (GiantSpider scales it).

const HIDE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// The pale of the fuzz round its edges, and how much of it there is.
uniform vec3 fuzz : source_color = vec3(0.66, 0.62, 0.56);
uniform float fuzz_gain = 1.0;
uniform float wrap = 0.3;

varying vec3 tint;
varying vec3 obj;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void vertex() {
	tint = COLOR.rgb;
	obj = VERTEX;
}

void fragment() {
	// Hair laid in streaks, darker at the roots.
	float streak = noise3(obj * vec3(14.0, 5.0, 14.0)) * 0.6 + noise3(obj * vec3(31.0, 11.0, 31.0)) * 0.4;
	vec3 colour = tint * (0.78 + 0.4 * streak);
	// The edges break up into pale fuzz.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ragged = noise3(obj * 22.0) - 0.5;
	float fuzzy = cut(graze + ragged * 0.3, 0.86) * fuzz_gain;
	colour = mix(colour, fuzz * 0.45, fuzzy * 0.6);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = fuzz * fuzzy * 0.03;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(facing, 0.05) * smoothstep(0.1, 0.75, reach);
	float core = cut(amount, 0.7);
	DIFFUSE_LIGHT += (lit * 0.85 + core * 0.15) * LIGHT_COLOR / PI;
}
"""

const GLOSS_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// Wet black, and a little light of its own so that the eyes find you in the mist.
uniform vec3 colour : source_color = vec3(0.025, 0.022, 0.02);
uniform vec3 glow : source_color = vec3(0.55, 0.6, 0.55);
uniform float glow_gain = 0.06;

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The sky caught on its top, as a hard pale crescent.
	vec3 sky_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float sky = cut(dot(reflect(-VIEW, NORMAL), sky_up), 0.55);
	EMISSION = glow * glow_gain + vec3(0.7, 0.72, 0.72) * sky * 0.35;
}

void light() {
	float lit = cut(dot(NORMAL, LIGHT) * clamp(ATTENUATION, 0.0, 1.0), 0.05);
	DIFFUSE_LIGHT += lit * 0.3 * LIGHT_COLOR / PI;
	float shine = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	SPECULAR_LIGHT += cut(pow(shine, 40.0), 0.4) * 0.25 * lit * LIGHT_COLOR;
}
"""

## Colours: the hide, its paler marks, and the hair's tips.
const DARK := Color(0.075, 0.068, 0.063)
const DARKER := Color(0.048, 0.044, 0.041)
const PALE := Color(0.3, 0.28, 0.25)
const TIPS := Color(0.36, 0.34, 0.3)

## The waist where the back body hangs from the front (body space), and the
## back body's middle and size from there (its own space).
const PEDICEL := Vector3(0.0, 0.05, 0.4)
const ABDOMEN_MIDDLE := Vector3(0.0, 0.1, 0.66)
const ABDOMEN_RADII := Vector3(0.52, 0.44, 0.72)
## Where the silk comes out (back body's own space).
const SPINNERETS := Vector3(0.0, 0.13, 1.36)
const CEPH_RADII := Vector3(0.46, 0.25, 0.54)
## Where the far end of a fang is, in the fang mesh's own space.
const FANG_TIP := Vector3(0.0, 1.0, 0.32)

static var _hide_shader: Shader
static var _gloss_shader: Shader
static var _hide: ShaderMaterial
static var _gloss: ShaderMaterial
static var _ceph: ArrayMesh
static var _abdomen: ArrayMesh
static var _segment: ArrayMesh
static var _fang: ArrayMesh
static var _thread: Mesh


## The hairy hide, shared by every spider.
static func hide_material() -> ShaderMaterial:
	if _hide == null:
		_hide_shader = Shader.new()
		_hide_shader.code = HIDE_SHADER
		_hide = ShaderMaterial.new()
		_hide.shader = _hide_shader
	return _hide


## Glossy black, for the eyes and fangs.
static func gloss_material() -> ShaderMaterial:
	if _gloss == null:
		_gloss_shader = Shader.new()
		_gloss_shader.code = GLOSS_SHADER
		_gloss = ShaderMaterial.new()
		_gloss.shader = _gloss_shader
	return _gloss


## The front body, its eyes as a second surface.
static func ceph_mesh() -> ArrayMesh:
	if _ceph != null:
		return _ceph
	var swell := func(dir: Vector3) -> float:
		# The eye mound at the front of the top, and a slight pinch at the back.
		var mound := exp(-pow(dir.distance_to(Vector3(0.0, 0.62, -0.78).normalized()), 2.0) / 0.06) * 0.5
		var waist := exp(-pow(dir.distance_to(Vector3(0.0, 0.2, 1.0).normalized()), 2.0) / 0.08) * -0.12
		return 1.0 + mound + waist
	var marks := func(dir: Vector3) -> Color:
		# Grooves from the pit in the middle, pale on the top; darker underneath.
		var angle := atan2(dir.x, dir.z)
		var grooves := pow(absf(cos(angle * 4.0)), 18.0) * smoothstep(0.35, 0.8, dir.y) * smoothstep(0.98, 0.85, dir.y)
		var edge := smoothstep(0.25, 0.0, absf(dir.y - 0.1)) * 0.6
		var colour := DARK.lerp(PALE, maxf(grooves * 0.7, edge * 0.5))
		return colour.lerp(DARKER, smoothstep(0.0, -0.6, dir.y))
	var mesh := ArrayMesh.new()
	_blob(mesh, Vector3.ZERO, CEPH_RADII, swell, marks, 420, 0.035, 11)
	# The eyes: two big ones staring forward, three small on each side.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var eyes: Array[Vector4] = [
		Vector4(-0.055, 0.0, -1.0, 0.052), Vector4(0.055, 0.0, -1.0, 0.052),
		Vector4(-0.13, -0.08, -0.95, 0.03), Vector4(0.13, -0.08, -0.95, 0.03),
		Vector4(-0.12, 0.08, -0.9, 0.026), Vector4(0.12, 0.08, -0.9, 0.026),
		Vector4(-0.16, 0.02, -0.82, 0.024), Vector4(0.16, 0.02, -0.82, 0.024),
	]
	var mound_top := Vector3(0.0, 0.62, -0.78).normalized()
	for eye in eyes:
		# Set into the face of the mound (a point on it), looking the way it faces.
		var dir := (mound_top + Vector3(eye.x * 3.0, eye.y, 0.0)).normalized()
		dir = (dir + Vector3(0.0, -0.25, -0.35)).normalized()
		var at: Vector3 = Vector3(dir.x * CEPH_RADII.x, dir.y * CEPH_RADII.y, dir.z * CEPH_RADII.z) * swell.call(dir)
		_sphere(tool, at + dir * eye.w * 0.25, eye.w)
	tool.commit(mesh)
	mesh.surface_set_material(0, hide_material())
	mesh.surface_set_material(1, gloss_material())
	_ceph = mesh
	return mesh


## The back body, in its own space (its origin is the waist).
static func abdomen_mesh() -> ArrayMesh:
	if _abdomen != null:
		return _abdomen
	var swell := func(dir: Vector3) -> float:
		# Fuller behind, and a little flattened underneath.
		return 1.0 + dir.z * 0.06 - maxf(-dir.y, 0.0) * 0.08
	var marks := func(dir: Vector3) -> Color:
		# Pale chevrons down the back, pointing forward.
		var top := smoothstep(0.25, 0.6, dir.y)
		var chevron := fmod(dir.z * 3.2 + absf(dir.x) * 2.4 + 8.0, 1.0)
		var stripe := smoothstep(0.0, 0.06, chevron) * smoothstep(0.24, 0.16, chevron) * top * smoothstep(0.9, 0.0, dir.z)
		var midline := smoothstep(0.08, 0.0, absf(dir.x)) * top * 0.5
		var colour := DARKER.lerp(PALE, maxf(stripe * 0.75, midline))
		return colour.lerp(Color(0.07, 0.065, 0.06), smoothstep(0.0, -0.7, dir.y))
	var mesh := ArrayMesh.new()
	_blob(mesh, ABDOMEN_MIDDLE, ABDOMEN_RADII, swell, marks, 1600, 0.06, 23)
	mesh.surface_set_material(0, hide_material())
	_abdomen = mesh
	return mesh


## Every leg part: a tapered, six-sided, hairy bar along +Y from 0 to 1,
## radius 1 at its root, with a pale ring round its far end.
static func segment_mesh() -> ArrayMesh:
	if _segment != null:
		return _segment
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	# Rings along it: height, radius, colour.
	var rings := [
		[0.0, 0.8, DARK], [0.08, 1.0, DARK], [0.5, 0.92, DARK], [0.82, 0.8, DARK],
		[0.86, 0.84, PALE], [0.95, 0.78, PALE], [1.0, 0.6, DARKER],
	]
	for r in rings.size() - 1:
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var n0 := Vector3(cos(t0), 0.0, sin(t0))
			var n1 := Vector3(cos(t1), 0.0, sin(t1))
			var p00 := n0 * float(a[1]) + Vector3.UP * float(a[0])
			var p01 := n1 * float(a[1]) + Vector3.UP * float(a[0])
			var p10 := n0 * float(b[1]) + Vector3.UP * float(b[0])
			var p11 := n1 * float(b[1]) + Vector3.UP * float(b[0])
			_vert(tool, p00, n0, a[2])
			_vert(tool, p11, n1, b[2])
			_vert(tool, p01, n1, a[2])
			_vert(tool, p00, n0, a[2])
			_vert(tool, p10, n0, b[2])
			_vert(tool, p11, n1, b[2])
	# Bristles standing out of it, leaning towards its far end. (Across it, a
	# unit is the part's thickness; along it, its length: so they are long
	# across and short along.)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 120:
		var y := rng.randf_range(0.04, 0.96)
		var angle := rng.randf() * TAU
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var root := radial * 0.85 + Vector3.UP * y
		var tip := radial * rng.randf_range(1.15, 1.45) + Vector3.UP * (y + rng.randf_range(0.03, 0.07))
		var across := Vector3(-radial.z, 0.0, radial.x) * 0.07
		_spike(tool, root, tip, across, Vector3.UP * 0.02, DARK, TIPS)
	_segment = tool.commit()
	return _segment


## A fang: a curved black spike along +Y from 0 to 1, hooking towards +Z.
static func fang_mesh() -> ArrayMesh:
	if _fang != null:
		return _fang
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var count := 6
	var centre := func(t: float) -> Vector3:
		return Vector3(0.0, t, FANG_TIP.z * t * t)
	for k in count:
		var ta := float(k) / count
		var tb := float(k + 1) / count
		var ra := 0.16 * (1.0 - ta)
		var rb := 0.16 * (1.0 - tb)
		for s in sides:
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var n0 := Vector3(cos(t0), 0.0, sin(t0))
			var n1 := Vector3(cos(t1), 0.0, sin(t1))
			var a0: Vector3 = centre.call(ta) + n0 * ra
			var a1: Vector3 = centre.call(ta) + n1 * ra
			var b0: Vector3 = centre.call(tb) + n0 * rb
			var b1: Vector3 = centre.call(tb) + n1 * rb
			_vert(tool, a0, n0, Color.WHITE)
			_vert(tool, b1, n1, Color.WHITE)
			_vert(tool, a1, n1, Color.WHITE)
			_vert(tool, a0, n0, Color.WHITE)
			_vert(tool, b0, n0, Color.WHITE)
			_vert(tool, b1, n1, Color.WHITE)
	_fang = tool.commit()
	return _fang


## The silk: a thin pale cylinder along +Y from 0 to 1.
static func thread_mesh() -> Mesh:
	if _thread != null:
		return _thread
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.82, 0.84, 0.82)
	mesh.material = material
	_thread = mesh
	return mesh


## A MultiMesh of `count` of `mesh`, with colours, all hidden to start.
static func parts(mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	for i in count:
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO))
		multi.set_instance_color(i, Color.WHITE)
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.top_level = true
	return node


## A part reaching from `a` to `b`, `thick` round at its root, its sides turned to face `side`.
static func between(a: Vector3, b: Vector3, thick: float, side := Vector3.UP) -> Transform3D:
	var along := b - a
	var length := along.length()
	if length < 0.0001:
		return Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), a)
	var dir := along / length
	var x := side.cross(dir)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT.cross(dir)
	if x.length_squared() < 0.0001:
		x = Vector3.BACK.cross(dir)
	x = x.normalized()
	var z := x.cross(dir)
	return Transform3D(Basis(x * thick, along, z * thick), a)


# --- Building ---

## An egg of hide round `middle`, `radii` across, its surface pushed out by
## `swell` (a direction to a multiplier) and coloured by `marks`, with `hairs`
## bristles `hair_long` long standing out of it, swept back (+Z).
static func _blob(mesh: ArrayMesh, middle: Vector3, radii: Vector3, swell: Callable, marks: Callable, hairs: int, hair_long: float, seed_value: int) -> void:
	# (hide and hairs in one surface: one draw)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lat := 14
	var lon := 22
	var point := func(dir: Vector3) -> Vector3:
		return middle + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * float(swell.call(dir))
	var dir_at := func(i: int, j: int) -> Vector3:
		var v := PI * i / lat
		var u := TAU * j / lon
		return Vector3(sin(v) * sin(u), cos(v), sin(v) * cos(u))
	for i in lat:
		for j in lon:
			var d00: Vector3 = dir_at.call(i, j)
			var d01: Vector3 = dir_at.call(i, j + 1)
			var d10: Vector3 = dir_at.call(i + 1, j)
			var d11: Vector3 = dir_at.call(i + 1, j + 1)
			for d: Vector3 in [d00, d10, d11, d00, d11, d01]:
				# (the normal of the egg, near enough with its swelling)
				var p0: Vector3 = point.call(d)
				var e := 0.02
				var side_a := (d.cross(Vector3.UP) if absf(d.y) < 0.95 else d.cross(Vector3.RIGHT)).normalized()
				var side_b := d.cross(side_a)
				var pa: Vector3 = point.call((d + side_a * e).normalized())
				var pb: Vector3 = point.call((d + side_b * e).normalized())
				var normal := (pa - p0).cross(pb - p0).normalized()
				if normal.dot(d) < 0.0:
					normal = -normal
				_vert(tool, p0, normal, marks.call(d))
	var hair_tool := tool
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in hairs:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.55, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var root: Vector3 = point.call(dir)
		var out := (Vector3(dir.x / radii.x, dir.y / radii.y, dir.z / radii.z)).normalized()
		# (lying down along the surface towards the back, as fur does: so they shade it little)
		var back := Vector3.BACK - out * out.z
		back = back.normalized() if back.length_squared() > 0.01 else Vector3.DOWN
		var lean := (out * 0.5 + back).normalized()
		var long := hair_long * rng.randf_range(0.6, 1.4)
		var across := out.cross(lean)
		if across.length_squared() < 0.0001:
			across = out.cross(Vector3.RIGHT)
		across = across.normalized() * long * 0.09
		var base: Color = marks.call(dir)
		_spike(hair_tool, root - out * 0.01, root + lean * long, across, out.cross(across).normalized() * long * 0.05, base, base.lerp(TIPS, 0.35))
	tool.commit(mesh)


## A thin three-sided spike from `root` to `tip`, `across` and `depth` wide at its root.
static func _spike(tool: SurfaceTool, root: Vector3, tip: Vector3, across: Vector3, depth: Vector3, colour: Color, tip_colour: Color) -> void:
	var a := root + across
	var b := root - across
	var c := root + depth
	var faces := [[a, b], [b, c], [c, a]]
	for face: Array in faces:
		var p: Vector3 = face[0]
		var q: Vector3 = face[1]
		var normal := (q - p).cross(tip - p).normalized()
		if normal.dot((p + q) * 0.5 - root) < 0.0:
			normal = -normal
		_vert(tool, p, normal, colour)
		_vert(tool, tip, normal, tip_colour)
		_vert(tool, q, normal, colour)


static func _vert(tool: SurfaceTool, at: Vector3, normal: Vector3, colour: Color) -> void:
	tool.set_normal(normal)
	tool.set_color(colour)
	tool.add_vertex(at)


## A small round sphere of `radius` at `at` (for the eyes).
static func _sphere(tool: SurfaceTool, at: Vector3, radius: float) -> void:
	var lat := 6
	var lon := 10
	for i in lat:
		for j in lon:
			var corners: Array[Vector3] = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1), Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)]:
				var v := PI * c.x / lat
				var u := TAU * c.y / lon
				corners.append(Vector3(sin(v) * sin(u), cos(v), sin(v) * cos(u)))
			for d in corners:
				_vert(tool, at + d * radius, d, Color.WHITE)
