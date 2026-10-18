class_name MeatAbomination
extends Node3D
## A meat abomination: a heaving mound of fused meat, fat, bone and slime, as
## high as two men and as wide as a road, that creeps along on its belly,
## leaves a glistening trail behind it, and lashes at what comes near with
## tendrils of meat. It is the look and the motion only: whatever thinks for it
## moves this node about and calls `lash`; nothing here knows about the game.
##
## USE
##     var meat := MeatAbomination.new()
##     add_child(meat)
##     # each frame (or physics frame), wherever your mover puts it:
##     meat.global_position = body.global_position   # on the ground
##     meat.rotation.y = heading                     # it faces -Z
##     meat.aim = player.global_position             # or Vector3.INF
##     # when the prey is in reach (`lash_reach`):
##     meat.lash(player.global_position)
##     if meat.lash_hits(feet, head, 0.4): ...       # a tendril struck them
##     if meat.touches(player.global_position, 0.3): ... # walked into it
##
## INPUTS. Where it is and which way it faces are the node's own transform (put
## it on the ground; it faces -Z). How fast it is going is worked out from how
## it moves, so it needs no velocity, but `moving` may be set instead (use it
## if the node is moved in jumps, as a network copy is). `aim` is what it is
## after, or INF: its front lifts towards it and its tendrils reach for it.
## `room` is how wide the space it is in is, metres (INF for open ground); or
## leave `measure_room` on and it casts rays to each side against
## `room_mask` a few times a second to find out. `size` scales all of it.
##
## MOTION, all from those:
## - It creeps by waves of squeezing that run from its tail to its front as it
##   goes (the shader, from how far it has gone), so it really looks to drag
##   itself along; standing, it only breathes and throbs.
## - It slops: started, stopped or turned, its top sways after it and settles
##   (a spring on its acceleration); its flanks bounce; it bends round a turn.
## - Where the space is narrower than it is (`room`), it squeezes: narrower,
##   taller and longer, as if poured through; out in the open again it spreads
##   wider than it was built (up to `widest`).
## - Strings of slime stretch off it and let go; its trail of slime lies on the
##   ground where it has been and dries away (`trail_life` seconds).
## - Tendrils: `TENDRILS` stalks of meat from its front and flanks, lying
##   about it on the ground and writhing, lifting to feel for `aim`.
##
## THE LASH. `lash(target)` throws the tendrils on that side at a point:
## WIND_UP (`wind_up` s; its front rears, its mouth opens, the tendrils coil
## back up over it, shivering: this is the warning), STRIKE (`strike` s; they
## whip out and down onto the point, no further than `lash_reach` from it, and
## its body lunges after them), HOLD (they lie there, twitching), RECOVER (they
## draw back). `lash_stage()` says which; `lash_hits(a, b, radius)` whether a
## striking tendril passes within `radius` of the line from `a` to `b` (a
## person from feet to head) in this frame; `touches(point, margin)` whether a
## point is in its body (walking into it).
##
## COST. One draw for the body (one mesh, shared, all its movement in the
## shader), one for all the tendrils (a MultiMesh), one for the trail (a
## MultiMesh), and shadows. The tendrils are worked out each frame (about 80
## transforms); set `process_mode` to disabled, or hide it, when nobody is near.
## Everything is made in code: no files but these.

enum Stage { NONE, WIND_UP, STRIKE, HOLD, RECOVER }

## How many tendrils, and the points along each.
const TENDRILS := 6
const JOINTS := 14
## Where each tendril leaves it (body space as built: forward -Z): left side
## first, front to back; the right side is the mirror. And how long each is.
const ROOTS: Array[Vector3] = [Vector3(-1.4, 1.5, -5.3), Vector3(-3.6, 1.7, -3.9), Vector3(-4.9, 1.6, -0.6)]
const LENGTHS: Array[float] = [8.5, 7.5, 6.0]
## How many patches of trail, and how far apart they are laid.
const TRAIL := 48
const TRAIL_STEP := 1.4

## How big it is: 1 is about 10 m wide and 6 high.
@export var size := 1.0
## What it is after, in the world (its front lifts towards it, its tendrils feel for it). INF: nothing.
var aim := Vector3.INF
## How wide the space it is in is, metres (INF: open). Set by `measure_room` unless that is off.
var room := INF
## Its speed over the ground, if set by its owner (else worked out from how it moves).
var moving := Vector3.INF
@export var measure_room := true
@export_flags_3d_physics var room_mask := 1
## The narrowest and widest it goes, against its width as built.
@export var narrowest := 0.2
@export var widest := 1.35
## How much room it leaves either side of it, metres, when it fills a space.
@export var room_margin := 1.2
@export_group("Lash")
## How far from where a tendril leaves it a lash reaches.
@export var lash_reach := 9.5
@export var wind_up := 0.9
@export var strike := 0.26
@export var hold := 0.5
@export var recover := 0.9
@export_group("Trail")
@export var trail_life := 22.0
@export var trailing := true

var _body: MeshInstance3D
var _material: ShaderMaterial
var _strands: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _crawl := 0.0
var _time := 0.0
var _was_at := Vector3.INF
var _speed := Vector3.ZERO
var _yaw_was := 0.0
var _turning := 0.0
var _jiggle := Vector3.ZERO
var _jiggle_speed := Vector3.ZERO
var _bounce := 0.0
var _bounce_speed := 0.0
var _squeeze := 1.0
var _room_in := 0.0
## How far the space goes to its left and right (INF: open, or not measured), and how far its body is slid across.
var _left := INF
var _right := INF
var _shift := 0.0
var _aim_lift := 0.0
## The lash: how long ago it began (INF: none), where at, and which tendrils.
var _lash_time := INF
var _lash_at := Vector3.ZERO
var _lashing: Array[bool] = []
## Each tendril's joints in the world now, and the thickness of each.
var _joints: Array[PackedVector3Array] = []
var _thick := PackedFloat32Array()
## What each tendril is lying on, in the world (where it was put down): so that
## it stays put on the ground as the body creeps, and is moved on in steps.
var _rest_end: Array[Vector3] = []
var _rest_mid: Array[Vector3] = []
## The trail: where each patch is, which way, how wide, and how old.
var _trail_at := PackedVector3Array()
var _trail_way := PackedFloat32Array()
var _trail_wide := PackedFloat32Array()
var _trail_age := PackedFloat32Array()
var _trail_next := 0
var _trail_from := Vector3.INF
var _trail_tick := 0.0


func _ready() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = AbominationLook.body()
	_material = AbominationLook.body_material()
	_body.material_override = _material
	# (it heaves well outside its mesh's bounds)
	_body.extra_cull_margin = 4.0
	add_child(_body)
	_strands = AbominationLook.strands(TENDRILS * (JOINTS - 1))
	_strands.name = "Tendrils"
	add_child(_strands)
	_trail = AbominationLook.trail(TRAIL)
	_trail.name = "Trail"
	add_child(_trail)
	for i in TENDRILS:
		_joints.append(PackedVector3Array())
		_joints[i].resize(JOINTS)
		_lashing.append(false)
		_rest_end.append(Vector3.INF)
		_rest_mid.append(Vector3.INF)
	_trail_at.resize(TRAIL)
	_trail_way.resize(TRAIL)
	_trail_wide.resize(TRAIL)
	_trail_age.resize(TRAIL)
	_trail_age.fill(INF)
	_thick.resize(JOINTS)
	for k in JOINTS:
		var s := float(k) / (JOINTS - 1)
		_thick[k] = lerpf(0.42, 0.06, pow(s, 0.8))
	settle()


## Stands it still as it is, nothing in motion: for when it has been put somewhere.
func settle() -> void:
	_was_at = Vector3.INF
	_speed = Vector3.ZERO
	_jiggle = Vector3.ZERO
	_jiggle_speed = Vector3.ZERO
	_bounce = 0.0
	_bounce_speed = 0.0
	_lash_time = INF
	_yaw_was = global_rotation.y if is_inside_tree() else rotation.y
	for i in TENDRILS:
		_rest_end[i] = Vector3.INF
		_rest_mid[i] = Vector3.INF
		_lashing[i] = false
	_trail_from = Vector3.INF


## Lashes the tendrils on `target`'s side at it (see the top). Does nothing if a lash is under way.
func lash(target: Vector3) -> void:
	if lash_stage() != Stage.NONE:
		return
	_lash_time = 0.0
	_lash_at = target
	var local := global_transform.affine_inverse() * target
	# The two front ones always; and the one on its side nearer to it.
	for i in TENDRILS:
		var row := i % 3
		var left := i < 3
		_lashing[i] = row == 0 or (row == 1 and (local.x < 0.0) == left)


func lash_stage() -> Stage:
	var t := _lash_time
	if t >= wind_up + strike + hold + recover:
		return Stage.NONE
	if t < wind_up:
		return Stage.WIND_UP
	if t < wind_up + strike:
		return Stage.STRIKE
	return Stage.HOLD if t < wind_up + strike + hold else Stage.RECOVER


## Seconds until the tendrils come down, while it winds up (0 after).
func strikes_in() -> float:
	return maxf(wind_up - _lash_time, 0.0)


## Where the lash under way is aimed.
func lash_target() -> Vector3:
	return _lash_at


## Whether a lashing tendril, now (striking, or just landed), passes within
## `radius` of the line from `a` to `b`.
func lash_hits(a: Vector3, b: Vector3, radius: float) -> bool:
	var stage := lash_stage()
	if stage != Stage.STRIKE and not (stage == Stage.HOLD and _lash_time < wind_up + strike + 0.1):
		return false
	for i in TENDRILS:
		if not _lashing[i]:
			continue
		var joints := _joints[i]
		for k in JOINTS - 1:
			var near := Geometry3D.get_closest_points_between_segments(joints[k], joints[k + 1], a, b)
			if near[0].distance_to(near[1]) < radius + _thick[k] * size * _tendril_scale():
				return true
	return false


## Whether `point` (in the world) is in its body, or within `margin` metres of it.
func touches(point: Vector3, margin := 0.0) -> bool:
	var local := _body.global_transform.affine_inverse() * point
	var scale_now := _body.global_transform.basis.get_scale()
	# (the margin as a share of its girth, roughly)
	var widen := margin / (minf(scale_now.x, minf(scale_now.y, scale_now.z)) * 4.0)
	return AbominationLook.inside(local) < 1.0 + widen


## How far the space goes to its left (x) and right (y) as last measured, metres
## (INF: open, or `measure_room` off). An owner can steer by it to keep it in
## the middle of a passage.
func sides() -> Vector2:
	return Vector2(_left, _right)


## The tendrils' joints now, in the world (for the curious: a game may want to
## show where they lie, or test them its own way).
func tendril(i: int) -> PackedVector3Array:
	return _joints[i]


# --- Each frame ---

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	if _lash_time < INF:
		_lash_time += delta
	var at := global_position
	var yaw := global_rotation.y
	var basis := Basis(Vector3.UP, yaw)
	# How fast it goes and turns, smoothed.
	var speed := moving
	if not speed.is_finite():
		speed = (at - _was_at) / delta if _was_at.is_finite() else Vector3.ZERO
		if speed.length() > 30.0:
			speed = Vector3.ZERO
	_was_at = at
	var before := _speed
	_speed = _speed.lerp(Vector3(speed.x, 0.0, speed.z), 1.0 - exp(-8.0 * delta))
	var turn := wrapf(yaw - _yaw_was, -PI, PI) / delta
	_yaw_was = yaw
	_turning = lerpf(_turning, clampf(turn * 0.6, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
	var flat := _speed.length()
	_crawl += flat * delta / size + delta * 0.15
	# Slops after itself: a spring pulled by how fast it is speeding up, in its own space.
	var accel := basis.inverse() * ((_speed - before) / delta)
	var pull := -accel * 0.09
	pull = pull.limit_length(1.2)
	_jiggle_speed += ((pull - _jiggle) * 30.0 - _jiggle_speed * 3.2) * delta
	_jiggle += _jiggle_speed * delta
	# Bounces with each wave that runs along it as it goes.
	var heave := sin(_crawl * TAU / 3.2) * minf(flat / 2.0, 1.0) * 0.12
	_bounce_speed += ((heave - _bounce) * 40.0 - _bounce_speed * 5.0) * delta
	_bounce += _bounce_speed * delta
	_squeezing(delta, basis)
	_shade(delta, flat)
	_pose_tendrils(delta)
	_lay_trail(delta)


## How wide it is now, from the room it has; and its body scaled to that.
func _squeezing(delta: float, basis: Basis) -> void:
	if measure_room:
		_room_in -= delta
		if _room_in <= 0.0 and is_inside_tree():
			_room_in = 0.2
			_measure(basis)
	else:
		_left = INF
		_right = INF
	var built := AbominationLook.RADII.x * 2.0 * size
	var want := clampf((room - room_margin * 2.0) / built, narrowest, widest) if room < INF else 1.0
	_squeeze = lerpf(_squeeze, want, 1.0 - exp(-2.2 * delta))
	# Poured through: what it loses in width it gains in height and length.
	var taller := clampf(pow(_squeeze, -0.35), 0.85, 1.45)
	var longer := clampf(1.0 / (_squeeze * taller), 0.75, 2.4)
	_body.scale = Vector3(_squeeze, taller, longer) * size
	# Kept off the walls: its body slides over to the middle of the space as far
	# as it must to keep `room_margin` from each (its middle stays where it is put).
	var half := AbominationLook.RADII.x * 1.05 * _body.scale.x
	var push_right := maxf(half + room_margin - _left, 0.0)
	var push_left := maxf(half + room_margin - _right, 0.0)
	var shift := push_right - push_left
	if push_right > 0.0 and push_left > 0.0:
		shift = (_right - _left) * 0.5
	# (no further than a third of its width: its owner should keep it near the middle, see `sides`)
	var most := half * 0.66
	_shift = lerpf(_shift, clampf(shift, -most, most), 1.0 - exp(-3.0 * delta))
	_body.position = Vector3(_shift, 0.0, 0.0)


## How wide the space is across it (`room`), and how far each side is: rays
## from its middle to either side, at two heights.
func _measure(basis: Basis) -> void:
	var space := get_world_3d().direct_space_state
	var across := basis * Vector3.RIGHT
	var far := 30.0 * size
	_left = INF
	_right = INF
	for high: float in [1.0, 3.0]:
		var from := global_position + Vector3.UP * high * size
		for side: float in [-1.0, 1.0]:
			var query := PhysicsRayQueryParameters3D.create(from, from + across * side * far, room_mask)
			var hit := space.intersect_ray(query)
			var gap := from.distance_to(hit["position"]) if not hit.is_empty() else INF
			if side < 0.0:
				_left = minf(_left, gap)
			else:
				_right = minf(_right, gap)
	room = _left + _right


## The shader's uniforms for this frame.
func _shade(delta: float, flat: float) -> void:
	var stage := lash_stage()
	var t := _lash_time
	var rear := 0.0
	var maw := 0.0
	var lunge := 0.0
	match stage:
		Stage.WIND_UP:
			var s := t / wind_up
			rear = smoothstep(0.0, 0.7, s)
			maw = smoothstep(0.1, 0.8, s) * (1.0 + 0.08 * sin(_time * 40.0))
		Stage.STRIKE:
			var s := (t - wind_up) / strike
			rear = 1.0 - smoothstep(0.0, 1.0, s) * 1.2
			maw = 1.0
			lunge = smoothstep(0.0, 1.0, s) * 1.3
		Stage.HOLD:
			var s := (t - wind_up - strike) / hold
			rear = -0.2
			maw = 1.0 - s * 0.4
			lunge = 1.3
		Stage.RECOVER:
			var s := (t - wind_up - strike - hold) / recover
			rear = -0.2 * (1.0 - s)
			maw = 0.6 * (1.0 - smoothstep(0.0, 1.0, s))
			lunge = 1.3 * (1.0 - smoothstep(0.0, 1.0, s))
	_aim_lift = lerpf(_aim_lift, 0.18 if aim.is_finite() else 0.0, 1.0 - exp(-1.5 * delta))
	if stage == Stage.NONE:
		rear = _aim_lift + 0.05 * sin(_time * 0.7)
		maw = _aim_lift * 0.5 * (0.5 + 0.5 * sin(_time * 1.3))
	var beat := fposmod(_time * 1.1, 1.0)
	_material.set_shader_parameter(&"crawl", _crawl)
	_material.set_shader_parameter(&"surge", 0.35 + minf(flat / 1.5, 1.0) * 0.75)
	_material.set_shader_parameter(&"breath", sin(_time * 1.3))
	_material.set_shader_parameter(&"pulse", exp(-beat * 9.0) + 0.6 * exp(-absf(beat - 0.22) * 14.0))
	_material.set_shader_parameter(&"jiggle", _jiggle)
	_material.set_shader_parameter(&"bounce", _bounce)
	_material.set_shader_parameter(&"rear", rear)
	_material.set_shader_parameter(&"maw", clampf(maw, 0.0, 1.2))
	_material.set_shader_parameter(&"bend", _turning)
	_material.set_shader_parameter(&"lunge", lunge)


# --- The tendrils ---

## How much the tendrils are scaled with the body's squeeze (they thin when it does).
func _tendril_scale() -> float:
	return clampf(sqrt(_squeeze), 0.6, 1.1)


## Where tendril `i` leaves the body now, in the world, and the way out of it.
func _root(i: int) -> Array:
	var built := ROOTS[i % 3]
	if i >= 3:
		built.x = -built.x
	var xform := _body.global_transform
	var at := xform * built
	var out := (xform.basis * Vector3(built.x, 0.0, built.z * 0.7)).normalized()
	return [at, out]


func _pose_tendrils(delta: float) -> void:
	var stage := lash_stage()
	var t := _lash_time
	var multi := _strands.multimesh
	var thin := _tendril_scale() * size
	var n := 0
	for i in TENDRILS:
		var found := _root(i)
		var root: Vector3 = found[0]
		var out: Vector3 = found[1]
		var long := LENGTHS[i % 3] * size * thin
		var rest := _resting(i, root, out, long, delta)
		var points := rest
		if _lashing[i] and stage != Stage.NONE:
			points = _lashed(i, root, out, long, rest, stage, t)
		_joints[i] = points
		for k in JOINTS - 1:
			var s := float(k) / (JOINTS - 1)
			var thick := _thick[k] * thin
			if _lashing[i] and stage == Stage.WIND_UP:
				thick *= 1.0 + 0.25 * smoothstep(0.0, 1.0, t / wind_up)
			var a := points[k]
			var b := points[k + 1]
			# (each a little longer than the gap, so they overlap)
			var along := (b - a)
			var piece := AbominationLook.between(a - along * 0.08, b + along * 0.04, thick)
			var tone := Color(1.0, 1.0, 1.0, 0.0)
			if k >= JOINTS - 3:
				# A hooked spur of bone at its end.
				tone = Color(0.78, 0.72, 0.6, 1.0)
			elif s < 0.12:
				tone = Color(0.85, 0.75, 0.75, 0.0)
			multi.set_instance_transform(n, piece)
			multi.set_instance_color(n, tone)
			n += 1
	multi.visible_instance_count = n


## Where a tendril lies when it is not lashing: out from the body and down onto
## the ground in a curve, writhing; when it has something to feel for, lifted
## off the ground towards it. Its end is put down on the ground and left there
## until the body has crept too far from it, then put down again ahead.
func _resting(i: int, root: Vector3, out: Vector3, long: float, delta: float) -> PackedVector3Array:
	var ground_y := global_position.y + 0.15 * size
	var forward := -global_transform.basis.z
	var reach := long * 0.78
	var want := root + (out + forward * 0.35).normalized() * reach
	want.y = ground_y
	# Picked up and put down ahead when it has been left too far behind or too near.
	var end := _rest_end[i]
	if not end.is_finite() or end.distance_to(want) > long * 0.45:
		end = want
		_rest_end[i] = end
	var wave := float(i) * 1.7
	var feel := 0.0
	var aim_point := aim
	if aim.is_finite():
		var to := aim - root
		to.y = 0.0
		feel = clampf(1.0 - (to.length() - long * 0.6) / (long * 1.5), 0.0, 1.0)
		if (i % 3) == 2:
			feel *= 0.4
	var points := PackedVector3Array()
	points.resize(JOINTS)
	var lift := Vector3.UP * long * 0.35
	var lifted_end := end.lerp(aim_point, 0.35) + Vector3.UP * long * 0.25 if feel > 0.0 else end
	var tip := end.lerp(lifted_end, feel)
	var c1 := root + out * long * 0.3 + Vector3.UP * long * 0.06
	var c2 := tip.lerp(root, 0.35) + lift * (0.25 + feel * 0.6)
	c2.y = maxf(c2.y, ground_y + 0.3 * size)
	var side := out.cross(Vector3.UP).normalized()
	for k in JOINTS:
		var s := float(k) / (JOINTS - 1)
		var p := _bezier(root, c1, c2, tip, s)
		# Writhing, more towards the end, faster when feeling.
		var writhe := sin(s * 6.0 - _time * (1.6 + feel * 2.5) + wave) * s * long * 0.06 * (1.0 + feel)
		p += side * writhe + Vector3.UP * absf(writhe) * 0.4 * (1.0 - feel)
		p.y = maxf(p.y, ground_y + _thick[k] * size * 0.6)
		points[k] = p
	# (the end curls)
	return points


## Where a lashing tendril is: coiled back up over the body (WIND_UP, shivering),
## thrown down onto the target (STRIKE: the end leads, the rest follows behind
## it in a whip), lying there (HOLD), drawn back to where it rests (RECOVER).
func _lashed(i: int, root: Vector3, out: Vector3, long: float, rest: PackedVector3Array, stage: Stage, t: float) -> PackedVector3Array:
	var target := _lash_at
	var to := target - root
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > lash_reach * size:
		flat = flat.normalized() * lash_reach * size
	# The two front tendrils land a little apart.
	var side := flat.normalized().cross(Vector3.UP)
	var land := root + flat + side * (0.22 if i < 3 else -0.22) * size
	land.y = global_position.y + 0.12 * size
	var back := -flat.normalized()
	# Coiled up: high over the body, the end hooked over, shivering.
	var coil := PackedVector3Array()
	coil.resize(JOINTS)
	var shiver := Vector3(sin(_time * 47.0 + i), sin(_time * 53.0 + i * 2.0), cos(_time * 41.0)) * 0.08 * size
	var top := root + Vector3.UP * long * 0.7 + back * long * 0.15 + out * long * 0.2
	for k in JOINTS:
		var s := float(k) / (JOINTS - 1)
		var p := _bezier(root, root + Vector3.UP * long * 0.35 + out * long * 0.1, top + Vector3.UP * long * 0.1, top - back * long * 0.25 + Vector3.DOWN * long * 0.1, s)
		coil[k] = p + shiver * s
	# Thrown: lying along the ground from the root to where it lands.
	var thrown := PackedVector3Array()
	thrown.resize(JOINTS)
	for k in JOINTS:
		var s := float(k) / (JOINTS - 1)
		var p := _bezier(root, root + flat * 0.25 + Vector3.UP * long * 0.18, land + Vector3.UP * long * 0.05 - flat * 0.15, land, s)
		p.y = maxf(p.y, land.y + _thick[k] * size * 0.5)
		thrown[k] = p
	var points := PackedVector3Array()
	points.resize(JOINTS)
	match stage:
		Stage.WIND_UP:
			var s := smoothstep(0.0, 0.55, t / wind_up)
			for k in JOINTS:
				points[k] = rest[k].lerp(coil[k], s)
		Stage.STRIKE:
			var s := (t - wind_up) / strike
			for k in JOINTS:
				# The end leads: each joint along it comes down a little later than the one after it.
				var f := float(k) / (JOINTS - 1)
				var u := clampf((s - (1.0 - f) * 0.45) / 0.55, 0.0, 1.0)
				u = 1.0 - pow(1.0 - u, 2.0)
				var p := coil[k].lerp(thrown[k], u)
				# (arched over as it comes)
				p += Vector3.UP * sin(u * PI) * long * 0.15 * f
				points[k] = p
		Stage.HOLD:
			var s := (t - wind_up - strike) / hold
			for k in JOINTS:
				var f := float(k) / (JOINTS - 1)
				points[k] = thrown[k] + Vector3.UP * absf(sin(_time * 23.0 + k)) * 0.06 * size * f * (1.0 - s)
		_:
			var s := smoothstep(0.0, 1.0, (t - wind_up - strike - hold) / recover)
			for k in JOINTS:
				points[k] = thrown[k].lerp(rest[k], s)
	return points


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, s: float) -> Vector3:
	var u := 1.0 - s
	return a * u * u * u + b * 3.0 * u * u * s + c * 3.0 * u * s * s + d * s * s * s


# --- The trail ---

## Lays a patch of slime every `TRAIL_STEP` it goes, and dries the old ones.
func _lay_trail(delta: float) -> void:
	var multi := _trail.multimesh
	var at := global_position
	if trailing:
		if not _trail_from.is_finite():
			_trail_from = at
		var gone := Vector2(at.x - _trail_from.x, at.z - _trail_from.z)
		if gone.length() > TRAIL_STEP * size:
			var i := _trail_next
			_trail_next = (_trail_next + 1) % TRAIL
			# (laid a little behind its middle, under its tail)
			var under := _body.global_position
			under.y = at.y
			_trail_at[i] = under - Vector3(gone.x, 0.0, gone.y).normalized() * 3.0 * _body.scale.z + Vector3.UP * 0.03
			_trail_way[i] = atan2(gone.x, gone.y)
			_trail_wide[i] = AbominationLook.RADII.x * 1.4 * _body.scale.x
			_trail_age[i] = 0.0
			_trail_from = at
	_trail_tick -= delta
	var fresh := _trail_tick <= 0.0
	if fresh:
		_trail_tick = 0.2
	for i in TRAIL:
		if _trail_age[i] < INF:
			_trail_age[i] += delta
	if not fresh:
		return
	var shown := 0
	for i in TRAIL:
		var age := _trail_age[i]
		if age >= trail_life:
			continue
		var fade := (1.0 - age / trail_life)
		fade = fade * fade * minf(age * 3.0 + 0.3, 1.0)
		var basis := Basis(Vector3.UP, _trail_way[i]).scaled(Vector3(_trail_wide[i], 1.0, TRAIL_STEP * size * 2.2))
		multi.set_instance_transform(shown, Transform3D(basis, _trail_at[i]))
		multi.set_instance_color(shown, Color(1, 1, 1, fade))
		shown += 1
	multi.visible_instance_count = shown
