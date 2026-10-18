class_name Campsite
extends Node3D
## A camp: somewhere people stopped, out in the open or in a hall between walls
## (The Clearing: placed by Loot; see its DESIGN.md, "Camps"). Built round its
## fire, where this node stands, from the models in props/models/
## (props/tools/build_props.py):
##
## - ABANDONED: a cold ring of stones round a bed of ash, a lean-to of tarp and
##   sticks (sometimes fallen in), bedrolls, a log to sit on, a pot, a crate, a
##   sack, sticks and stones scattered about; often (in the open) a post with
##   tally marks cut in it, or (`in_maze`) tallies scratched on a wall
##   (`scratch_wall_towards`); sometimes signs of a struggle: the lean-to down,
##   the pot kicked over, something dragged away. `light()` it and it burns again.
## - OCCUPIED: the same, kept, its fire burning (GameCommon's Fire, with its
##   light) and smoke going up high enough to be seen from far off (SmokeColumn).
##   Whoever rests there is the game's to put in: at `seats` (sat round the
##   fire) and `beds` (asleep on a bedroll). What lies there worth taking goes at
##   `stash`.
##
##     var camp := Campsite.new(Campsite.Kind.OCCUPIED, seed)
##     camp.ground = func(p: Vector3) -> float: return terrain_height(p)   # or leave it: level
##     camp.position = where
##     add_child(camp)
##
## A lit camp is in the group `fire_wards` with a `ward_radius` (The Clearing's
## FireWard: what fears fire keeps off it). Everything is placed from
## `seed_value`, so every copy of a game builds the same camp.

enum Kind { ABANDONED, OCCUPIED }

const MODELS := "res://props/models/%s.glb"
## Draw nothing of it further off than this (but its fire and smoke).
const SHOWN_TO := 140.0
## While its fire burns, what fears fire keeps this far off it, metres.
const WARD := 7.0

var kind := Kind.ABANDONED
var seed_value := 0
## In a hall between walls (tallies on the wall, not a post; struggles more often), or in the open.
var in_maze := false
## How high the ground is at a point (its x and z): any Callable(Vector3) -> float (The Clearing: Maze.ground_height). Unset, level with the camp.
var ground: Callable
## Signs of a struggle (abandoned camps only).
var struggle := false
## Its fire burns.
var lit := false
## FireWard: how far off what fears fire is kept (while it burns).
var ward_radius := 0.0
## Where its things lie that are worth taking (in its own space; The Clearing: Loot puts what it found there).
var stash: Array[Vector3] = []
## Where someone sits round its fire, facing it, in its own space (The Clearing: Loot sits Campers there).
var seats: Array[Transform3D] = []
## Where someone lies asleep by its fire (on its bedrolls laid out).
var beds: Array[Transform3D] = []
## The wall its tallies are scratched on, if any: [a point on its face, the way it faces].
var wall := []

var _rng := RandomNumberGenerator.new()
var _fire: Fire
var _logs: Node3D
var _smoke: SmokeColumn
static var _cache := {}
static var _materials := {}


func _init(of_kind := Kind.ABANDONED, seed_of := 0, maze_hall := false) -> void:
	kind = of_kind
	seed_value = seed_of
	in_maze = maze_hall


func _ready() -> void:
	add_to_group(&"campsites")
	add_to_group(&"fire_wards")
	_rng.seed = seed_value
	if kind == Kind.ABANDONED:
		struggle = _rng.randf() < (0.45 if in_maze else 0.3)
	_build()
	if kind == Kind.OCCUPIED:
		light()


## How high the ground is under a point of the camp (its own space).
func _ground_at(local: Vector3) -> float:
	var world := global_transform * local
	var y: float = ground.call(Vector3(world.x, 0.0, world.z)) if ground.is_valid() else global_position.y
	return y - global_position.y


## A model from props/models (or anywhere, by path), shaded as the world, at
## `local` on the ground, turned `yaw`, tipped by `tip` (Euler), for drawing no
## further off than SHOWN_TO.
func _put(what: String, local: Vector3, yaw: float, tip := Vector3.ZERO, lift := 0.0) -> Node3D:
	var path := what if what.begins_with("res://") else MODELS % what
	if not _cache.has(path):
		_cache[path] = load(path)
	var model := (_cache[path] as PackedScene).instantiate() as Node3D
	model.position = Vector3(local.x, _ground_at(local) + lift, local.z)
	# (laid on the slope of the ground where it lies, not level through it)
	var d := 0.8
	var slope := Vector3(_ground_at(local - Vector3(d, 0.0, 0.0)) - _ground_at(local + Vector3(d, 0.0, 0.0)), 2.0 * d,
		_ground_at(local - Vector3(0.0, 0.0, d)) - _ground_at(local + Vector3(0.0, 0.0, d))).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, slope)) * Basis.from_euler(Vector3(tip.x, yaw, tip.z))
	add_child(model)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		part.visibility_range_end = SHOWN_TO
		part.visibility_range_end_margin = 10.0
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var key := original.albedo_color.to_html()
			if not _materials.has(key):
				_materials[key] = Toon.surface(original.albedo_color)
			part.set_surface_override_material(surface, _materials[key])
	return model


func _build() -> void:
	var r := _rng
	_put("fire_ring", Vector3.ZERO, r.randf_range(0.0, TAU))
	# The lean-to, open towards the fire, a few metres off it.
	var shelter := r.randf_range(0.0, TAU)
	var at := Vector3(sin(shelter), 0.0, cos(shelter)) * 3.3
	var fallen := struggle or (kind == Kind.ABANDONED and r.randf() < 0.3)
	_put("lean_to_fallen" if fallen else "lean_to", at, shelter + PI)
	# Bedrolls round the fire, heads away from it; some rolled up.
	var sleepers := r.randi_range(1, 3)
	for i in sleepers:
		var a := shelter + (i - (sleepers - 1) * 0.5) * 0.75
		var spot := Vector3(sin(a), 0.0, cos(a)) * 2.2
		var open := kind == Kind.OCCUPIED or r.randf() < 0.6
		if open:
			_put("bedroll_open", spot, a + r.randf_range(-0.15, 0.15))
			var bed := spot
			bed.y = _ground_at(spot)
			beds.append(Transform3D(Basis(Vector3.UP, a + PI * 0.5), bed))
			if kind == Kind.ABANDONED and i == 0:
				stash.append(spot + Vector3(sin(a), 0.0, cos(a)) * 0.95)
		else:
			_put("bedroll", spot + Vector3(sin(a), 0.0, cos(a)) * 0.5, a + PI * 0.5 + r.randf_range(-0.3, 0.3))
	# A log to sit on, across from the lean-to; and where people sit round the fire.
	var across := shelter + PI + r.randf_range(-0.5, 0.5)
	var log_at := Vector3(sin(across), 0.0, cos(across)) * 2.2
	_put("log_seat", log_at, across + PI * 0.5)
	for i in 3:
		var a := across + (i - 1) * 1.15 + (0.0 if i == 1 else r.randf_range(-0.15, 0.15))
		var spot := Vector3(sin(a), 0.0, cos(a)) * (1.25 if i == 1 else 1.6)
		spot.y = _ground_at(spot)
		seats.append(Transform3D(Basis(Vector3.UP, a + PI), spot))
	# Gear: a pot by the fire (kicked over, after a struggle), a crate and a sack by the lean-to.
	var pot_a := r.randf_range(0.0, TAU)
	var pot_at := Vector3(sin(pot_a), 0.0, cos(pot_a)) * (0.95 if not struggle else 1.6)
	_put("pot", pot_at, r.randf_range(0.0, TAU), Vector3(PI * 0.5 if struggle else 0.0, 0.0, 0.0), 0.12 if struggle else 0.0)
	var side := Vector3(cos(shelter), 0.0, -sin(shelter))
	var crate_at := at + side * (1.8 if r.randf() < 0.5 else -1.8) + Vector3(sin(shelter), 0.0, cos(shelter)) * 0.3
	_put("crate", crate_at, shelter + r.randf_range(-0.4, 0.4))
	stash.append(crate_at + (crate_at - at).normalized() * 0.7)
	_put("sack", at - side * 1.6 - Vector3(sin(shelter), 0.0, cos(shelter)) * 0.4, r.randf_range(0.0, TAU))
	stash.append(Vector3(sin(across + 0.6), 0.0, cos(across + 0.6)) * 2.9)
	# Sticks and stones about it, as two MultiMeshes.
	_scatter("stick", r.randi_range(8, 14), 4.2, 0.0)
	_scatter("pebble", r.randi_range(5, 9), 3.6, 0.0)
	if kind == Kind.ABANDONED and not in_maze and r.randf() < 0.65:
		var post_a := shelter + r.randf_range(1.6, 2.4)
		_put("marker", Vector3(sin(post_a), 0.0, cos(post_a)) * 4.6, post_a + PI)
	if struggle:
		_drag_marks(shelter + r.randf_range(-0.6, 0.6) + PI * 0.15)


## `count` of a small model scattered round the camp, in one draw.
func _scatter(what: String, count: int, reach: float, lift: float) -> void:
	var path := MODELS % what
	if not _cache.has(path):
		_cache[path] = load(path)
	var source := (_cache[path] as PackedScene).instantiate() as Node3D
	var part := source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = part.mesh
	many.instance_count = count
	for i in count:
		var a := _rng.randf_range(0.0, TAU)
		var d := _rng.randf_range(1.0, reach)
		var spot := Vector3(sin(a) * d, 0.0, cos(a) * d)
		spot.y = _ground_at(spot) + lift
		var size := _rng.randf_range(0.7, 1.3)
		many.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * size), spot))
	var drawn := MultiMeshInstance3D.new()
	drawn.multimesh = many
	drawn.visibility_range_end = SHOWN_TO * 0.6
	var original := part.mesh.surface_get_material(0) as StandardMaterial3D
	if original:
		var key := original.albedo_color.to_html()
		if not _materials.has(key):
			_materials[key] = Toon.surface(original.albedo_color)
		drawn.material_override = _materials[key]
	add_child(drawn)
	source.free()


## Two furrows dragged through the dirt away from the camp, the way `a` (radians).
func _drag_marks(a: float) -> void:
	var length := 7.0
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, length)
	plane.subdivide_depth = 6
	mark.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_texture = drag_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.15, 0.12, 0.09, 0.8)
	material.roughness = 1.0
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var start := Vector3(sin(a), 0.0, cos(a)) * 2.0
	var middle := start + Vector3(sin(a), 0.0, cos(a)) * length * 0.5
	mark.position = Vector3(middle.x, _ground_at(middle) + 0.03, middle.z)
	mark.rotation.y = a
	mark.visibility_range_end = SHOWN_TO * 0.6
	add_child(mark)


## Tallies scratched on a wall face near a camp in the maze: `face` a point on
## the face (world space), `out` the way the face looks.
func scratch_wall(face: Vector3, out: Vector3) -> void:
	wall = [face, out]
	_scratched(face, out)


## Tallies on whatever wall stands the way `way` (level) from the camp: found
## by feeling for it once the walls are in the physics (the frame after they
## are built), at a boy's reach up it.
func scratch_wall_towards(way: Vector3) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 2.3
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way.normalized() * 16.0, 1))
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
		return
	var out: Vector3 = hit["normal"]
	out.y = 0.0
	var face: Vector3 = hit["position"]
	wall = [Vector3(face.x, global_position.y, face.z), out.normalized()]
	_scratched(wall[0], wall[1])


func _scratched(face: Vector3, out: Vector3) -> void:
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 0.75)
	mark.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = tally_texture(_rng.randi_range(9, 34), seed_value)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.7, 0.66, 0.9)
	material.roughness = 1.0
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	mark.global_transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), face + out * 0.04 + Vector3.UP * 2.0)


## Its fire alight: logs on the ring, the flame and its light, smoke going up.
func light() -> void:
	if lit:
		return
	lit = true
	ward_radius = WARD
	if _logs == null:
		_logs = _put("fire_logs", Vector3.ZERO, _rng.randf_range(0.0, TAU))
	_fire = Fire.new()
	_fire.size = 0.85
	_fire.spread = 0.75
	_fire.tongues = 4
	_fire.light_energy = 3.6
	_fire.light_range = 15.0
	_fire.position = Vector3(0.0, _ground_at(Vector3.ZERO) + 0.08, 0.0)
	add_child(_fire)
	_smoke = SmokeColumn.new()
	_smoke.position = _fire.position + Vector3.UP * 0.9
	add_child(_smoke)


## Where its fire is (for lighting a torch at it, or it from a torch).
func hearth() -> Vector3:
	return global_position + Vector3.UP * (_ground_at(Vector3.ZERO) + 0.3)


## Scratched tally marks, `count` of them in fives (the fifth across), pale
## scratches with a dark lip, on clear ground (a wall's, or a board's).
static func tally_texture(count: int, seed_of: int) -> ImageTexture:
	var w := 256
	var h := 128
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = seed_of
	var x := 10.0
	var row := 0
	for i in count:
		var in_five := i % 5
		var y0 := 14.0 + row * 58.0
		if in_five < 4:
			var lean := r.randf_range(-3.0, 3.0)
			_stroke(image, Vector2(x, y0 + r.randf_range(-2, 2)), Vector2(x + lean, y0 + 44 + r.randf_range(-3, 3)), r)
			x += 9.0
		else:
			_stroke(image, Vector2(x - 40.0, y0 + 30.0), Vector2(x + 2.0, y0 + 10.0), r)
			x += 14.0
		if x > w - 20 and in_five == 4:
			x = 10.0
			row += 1
			if row > 1:
				break
	return ImageTexture.create_from_image(image)


static func _stroke(image: Image, a: Vector2, b: Vector2, r: RandomNumberGenerator) -> void:
	var steps := int(a.distance_to(b))
	for s in steps + 1:
		var p := a.lerp(b, float(s) / maxf(steps, 1))
		var wob := r.randf_range(-0.6, 0.6)
		for dx in range(-2, 3):
			for dy in range(-1, 2):
				var q := Vector2i(int(p.x + dx + wob), int(p.y + dy))
				if q.x < 0 or q.y < 0 or q.x >= image.get_width() or q.y >= image.get_height():
					continue
				var c := image.get_pixelv(q)
				if absi(dx) <= 1:
					image.set_pixelv(q, Color(0.95, 0.93, 0.88, maxf(c.a, 0.9)))
				elif c.a < 0.5:
					image.set_pixelv(q, Color(0.12, 0.11, 0.1, 0.55))


static var _drag_tex: ImageTexture


## Two furrows with streaks along them, as something dragged makes.
static func drag_texture() -> ImageTexture:
	if _drag_tex:
		return _drag_tex
	var w := 64
	var h := 256
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for y in h:
		var along := float(y) / h
		var fade := smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.7, 1.0, along))
		for x in w:
			var u := float(x) / w
			var furrow := 0.0
			for middle: float in [0.32 + 0.03 * sin(along * 7.0), 0.68 + 0.03 * sin(along * 6.0 + 1.0)]:
				furrow = maxf(furrow, 1.0 - smoothstep(0.03, 0.12, absf(u - middle)))
			var streak := 0.5 + 0.5 * sin(u * 90.0 + r.randf() * 0.5)
			var a := clampf(furrow * (0.55 + 0.45 * streak) * fade + 0.12 * fade * (1.0 - absf(u - 0.5) * 2.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_drag_tex = ImageTexture.create_from_image(image)
	return _drag_tex
