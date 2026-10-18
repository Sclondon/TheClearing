class_name SnailSlime
extends MultiMeshInstance3D
## The trail of slime a giant snail (Snail) leaves on whatever it crawls over:
## floor, walls, wall tops. Patches laid flat on the surface one after another
## as it goes, as wide as its foot, each lying `life` seconds, drying from the
## edges to a dull silver streak before it is gone. One draw for all of it
## (a MultiMesh); each patch's age is worked out in the shader (SnailLook), so
## nothing is touched while it lies there. It stays where it was laid however
## the snail goes on (it is top-level).
##
## `fresh_at(point)` says how fresh the slime is at a point (0: none, 1: just
## laid; it is still slime until it has nearly dried away), for whatever a game
## does to anyone in it.

## How many patches it keeps (the oldest goes when it laid one more).
const MOST := 256
## Metres of crawling between patches, for a snail of scale 1.
const STEP := 0.55

## Seconds a patch lies.
var life := 120.0

var _at := PackedVector3Array()
var _up := PackedVector3Array()
var _ahead := PackedVector3Array()
var _wide := PackedFloat32Array()
var _long := PackedFloat32Array()
var _born := PackedFloat32Array()
var _next := 0
var _laid := 0
var _from := Vector3.INF


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = MOST
	multi.visible_instance_count = 0
	multimesh = multi
	material_override = SnailLook.slime_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_at.resize(MOST)
	_up.resize(MOST)
	_ahead.resize(MOST)
	_wide.resize(MOST)
	_long.resize(MOST)
	_born.resize(MOST)
	_born.fill(-1.0e9)


func _process(_delta: float) -> void:
	if _laid > 0:
		SnailLook.slime_material().set_shader_parameter(&"now", Snail.clock())


## Lays a patch under `where` (a snail's sole: its origin on the surface, +Y
## off it, +Z the way it goes) if it has gone a step since the last, `wide` across.
func lay(where: Transform3D, wide: float) -> void:
	var at := where.origin
	var scale_now := where.basis.get_scale().x
	if not _from.is_finite():
		_from = at
		return
	var gone := at - _from
	var step := STEP * scale_now
	if gone.length() < step:
		return
	var up := where.basis.y.normalized()
	var ahead := (gone - up * gone.dot(up))
	if ahead.length() < 0.001:
		ahead = where.basis.z.normalized()
	ahead = ahead.normalized()
	var middle := _from.lerp(at, 0.5)
	var i := _next
	_next = (_next + 1) % MOST
	_laid = mini(_laid + 1, MOST)
	_at[i] = middle
	_up[i] = up
	_ahead[i] = ahead
	_wide[i] = wide * randf_range(0.92, 1.08)
	_long[i] = gone.length() * 2.1
	_born[i] = Snail.clock()
	var across := up.cross(ahead).normalized()
	var basis := Basis(across * _wide[i], up, ahead * _long[i])
	multimesh.set_instance_transform(i, Transform3D(basis, middle + up * 0.025))
	multimesh.set_instance_custom_data(i, Color(_born[i], life, randf(), 0.0))
	multimesh.visible_instance_count = _laid
	_from = at


## The next patch begins where the snail is next (it has been put somewhere).
func cut() -> void:
	_from = Vector3.INF


## How fresh the slime is at `point`: 0 (none) to 1 (just laid). It is fully
## slime until it has nearly dried away.
func fresh_at(point: Vector3) -> float:
	if _laid == 0:
		return 0.0
	var now := Snail.clock()
	var best := 0.0
	for i in _laid:
		var age := now - _born[i]
		if age > life:
			continue
		var to := point - _at[i]
		var reach := _long[i] * 0.5 + _wide[i] * 0.5
		if to.length_squared() > reach * reach:
			continue
		if absf(to.dot(_up[i])) > 0.7:
			continue
		if absf(to.dot(_ahead[i])) > _long[i] * 0.5:
			continue
		if absf(to.dot(_up[i].cross(_ahead[i]))) > _wide[i] * 0.45:
			continue
		best = maxf(best, 1.0 - smoothstep(0.8, 1.0, age / life))
		if best >= 1.0:
			break
	return best


## How many patches are lying now.
func patches() -> int:
	var now := Snail.clock()
	var count := 0
	for i in _laid:
		if now - _born[i] <= life:
			count += 1
	return count
