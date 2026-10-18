class_name Octopus
extends Node3D
## A giant octopus: its look and its motion, for any game (it does no thinking:
## your game moves it and tells each arm what to do). Mantle about 2.5 m long,
## arms 8.4 m.
##
##     var octopus := Octopus.new()
##     add_child(octopus)
##     octopus.put(where, yaw)             # its crown's place on the ground, and the way it faces (+Z)
##     # where its arms come out when it is down out of sight (sunk 1): the middle
##     # of its water, or the mouth of a drain at the foot of a wall (mouth_out: out of the wall)
##     octopus.mouth = pool_middle; octopus.hole_radius = 2.5
##     octopus.sunk = 1.0                  # 0 up on the ground, 1 down under it (its water hides it)
##     octopus.feel(0, point)              # arm 0 feels about there, along the floor (or up a wall: feel(k, point, normal))
##     octopus.wind(2, point)              # arm 2 rears up and coils, aimed there (the wind-up)
##     octopus.lash(2, point)              # and whips out to it
##     octopus.hold(2, point)              # its end wraps round what is there (call it every frame as that moves)
##     octopus.rest(2)                     # drawn back in (sprawled about it on the ground, or tucked under it when down)
##     octopus.crawling = true; octopus.velocity = v   # its arms walk it along as you move it
##     octopus.cut(2)                      # the arm is cut through: the end falls and writhes; it grows back
##     octopus.ink()                       # a cloud of ink (OctopusInk) at it
##
## EACH ARM is a soft chain (OctopusArm) that bends anywhere, laid each frame
## along the path it wants (to the floor and along it to where it feels, its
## tip curling and uncurling; up in an S, its end coiled tight, to strike; out
## straight in a whip; wound two and a half times round what it holds; out
## ahead to plant and pull as it crawls) and going there on springs, stiffer at
## the base, so that its tip lags and whips and it all moves as something soft
## and heavy does. Out of the ground it keeps on the floor (`floor_y`); where
## the ground is open (its water, `hole_radius` round its `mouth`, or the wall
## behind a drain's mouth) it goes down into it.
##
## ITS SKIN (OctopusLook): `reveal` 0..1 (0 it takes on the tones of what it is
## on: `floor_tone` low down, `wall_tone` up a wall, `water_tone` in its water,
## `water` x, y, z its middle and w how far it reaches), `flush` -1..1 (dark or
## pale), `papillae` 0..1 (its skin's little horns raised), `waves` 0..1 (dark
## clouds rolling over it: agitated). Set them, or let `mood` do it: 0 calm and
## hidden, 1 about to strike (blanching, papillae up, clouds), 2 striking (dark).
##
## Its sounds are made in code (OctopusSound): a wet slither as its arms move
## (louder the faster), a splash when it rises or strikes out of its water, the
## slap of a lash, a wet suck as it takes hold, and the jet of its ink.

signal cut_off(arm: int, at: Vector3)

const ARMS := 8
const BONES := OctopusArm.BONES
## How far below the ground its crown goes when it is down (sunk 1), metres.
const SINK_DEPTH := 2.7
## How long an arm takes to grow back, seconds; and how far up it is cut (0..1 from the crown, at least).
@export var regrow_time := 50.0
@export var cut_from := 0.28
@export var low_poly := false
@export var sound := true
@export var volume_db := -4.0

enum Do { REST, FEEL, WIND, LASH, HOLD, CRAWL, TUCK }

## 0 up on the ground, 1 down under it, out of sight.
var sunk := 0.0
## Where its arms come out when it is down: the middle of its water (or a
## drain's mouth, with `mouth_out` the way out of the wall). INF: straight up.
var mouth := Vector3.INF
var mouth_out := Vector3.ZERO
## How far round its mouth the ground is open (its water), metres.
var hole_radius := 2.0
## A drain's mouth: how wide it is, and the way along it.
var mouth_width := 1.0
## The floor's height round it.
var floor_y := 0.0
## How far it is squeezed thin (1 not at all), passing a gap.
var squeeze := 1.0
## Its arms walk it along (set `velocity` to how it is being moved).
var crawling := false
var velocity := Vector3.ZERO
## What it looks at (its body leans a little that way). INF: ahead.
var aim := Vector3.INF
## 0 calm and hidden, 1 about to strike, 2 striking (sets reveal, flush, papillae, waves). -1: leave them to you.
var mood := 0.0
var reveal := 0.0
var flush := 0.0
var papillae := 0.3
var waves := 0.0
var floor_tone := Color(0.16, 0.145, 0.125)
var wall_tone := Color(0.4, 0.4, 0.38)
var water_tone := Color(0.035, 0.045, 0.045)
var water := Vector4(0.0, 0.0, 0.0, -1.0)

var rig: OctopusRig
var arms: Array[OctopusArm] = []
## What each arm is doing (Do), towards what point, and (feeling up a wall) the wall's face.
var doing: Array[Do] = []
var goals: Array[Vector3] = []
var walls: Array[Vector3] = []

var _time := 0.0
var _since: PackedFloat32Array = PackedFloat32Array()
var _plants: Array[Vector3] = []
var _lifting: PackedFloat32Array = PackedFloat32Array()
var _lift_from: Array[Vector3] = []
var _settled := false
var _breath := 0.0
var _jet := 0.0
var _rng := RandomNumberGenerator.new()
var _slither: AudioStreamPlayer3D
var _event: AudioStreamPlayer3D
var _severed: Array[Node3D] = []


func _ready() -> void:
	_rng.seed = hash(get_instance_id())
	rig = OctopusRig.new()
	rig.low_poly = low_poly or Settings.low_poly
	add_child(rig)
	for k in ARMS:
		var arm := OctopusArm.new(global_position, Vector3.FORWARD, rig.segment, _rng.randf() * TAU)
		arms.append(arm)
		doing.append(Do.REST)
		goals.append(Vector3.ZERO)
		walls.append(Vector3.ZERO)
		_since.append(0.0)
		_plants.append(Vector3.INF)
		_lifting.append(0.0)
		_lift_from.append(Vector3.ZERO)
	if sound:
		_slither = AudioStreamPlayer3D.new()
		_slither.stream = OctopusSound.slither()
		_slither.volume_db = -80.0
		_slither.unit_size = 6.0
		_slither.max_distance = 40.0
		_slither.top_level = true
		add_child(_slither)
		_event = AudioStreamPlayer3D.new()
		_event.volume_db = volume_db
		_event.unit_size = 7.0
		_event.max_distance = 50.0
		_event.top_level = true
		add_child(_event)
	put(global_position, rotation.y)


## Puts it straight down at `at` facing `yaw`, its arms laid out where they want to be.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation = Vector3(0.0, yaw, 0.0)
	if rig == null or rig.skeleton == null:
		return
	floor_y = at.y if not mouth.is_finite() else floor_y
	_settled = false


# --- What its arms do ---

func feel(k: int, point: Vector3, wall_normal := Vector3.ZERO) -> void:
	_set_arm(k, Do.FEEL, point)
	walls[k] = wall_normal


func wind(k: int, point: Vector3) -> void:
	_set_arm(k, Do.WIND, point)


func lash(k: int, point: Vector3) -> void:
	_set_arm(k, Do.LASH, point)
	_play(OctopusSound.splash() if sunk > 0.5 else OctopusSound.slap(), arm_points(k)[BONES / 2], 0.0)


func hold(k: int, point: Vector3) -> void:
	if doing[k] != Do.HOLD:
		_play(OctopusSound.suck(), point, 0.0)
	_set_arm(k, Do.HOLD, point)


func rest(k: int) -> void:
	_set_arm(k, Do.REST, goals[k])


func _set_arm(k: int, what: Do, point: Vector3) -> void:
	if doing[k] != what:
		_since[k] = 0.0
	doing[k] = what
	goals[k] = point


## How long arm k has been doing what it is doing, seconds.
func since(k: int) -> float:
	return _since[k]


## The arm's points, root to tip, in the world.
func arm_points(k: int) -> PackedVector3Array:
	return arms[k].points


func tip(k: int) -> Vector3:
	return arms[k].tip()


## How far `point` is from arm k, and how far out along it the nearest of it is (0..1).
func near_arm(k: int, point: Vector3) -> Vector2:
	return arms[k].nearest(point)


## How far each arm has grown back (1 whole).
func grown(k: int) -> float:
	return arms[k].grown


## Cuts arm k through (at least `cut_from` out from the crown, or where `at` is
## nearest on it): what is past the cut falls and writhes on the floor a while
## (and sinks away), and the stump grows back over `regrow_time`. Where it was cut.
func cut(k: int, at := Vector3.INF) -> Vector3:
	var arm := arms[k]
	var f := cut_from
	if at.is_finite():
		f = maxf(arm.nearest(at).y, cut_from)
	var index := clampi(int(round(f * BONES)), 2, BONES - 2)
	var piece := PackedVector3Array()
	for i in range(index, BONES + 1):
		piece.append(arm.points[i])
	var where := arm.points[index]
	_drop_piece(piece, float(index) / BONES * arm.grown, arm.grown)
	arm.grown = float(index) / BONES * arm.grown
	_play(OctopusSound.slap(), where, 2.0)
	cut_off.emit(k, where)
	return where


## A cloud of ink at it (out of its water, if it is down), with the jet of it.
func ink() -> OctopusInk:
	var cloud := OctopusInk.new()
	get_parent().add_child(cloud)
	var at := global_position + Vector3.UP * 1.0
	if sunk > 0.5 and mouth.is_finite():
		at = mouth + Vector3.UP * 0.6
	cloud.global_position = at
	_jet = 1.0
	_play(OctopusSound.jet(), at, 2.0)
	return cloud


## Where its eyes are now (for lines of sight), in the world.
func eyes() -> Vector3:
	return global_transform * (Vector3(0.0, 1.05, 0.25) + Vector3.DOWN * sunk * SINK_DEPTH)


# --- Each frame ---

func _process(delta: float) -> void:
	if rig == null or rig.skeleton == null:
		return
	_time += delta
	for k in ARMS:
		_since[k] += delta
	_moods(delta)
	var body := _body(delta)
	var to_world := global_transform
	var segment := rig.segment
	var open := _open
	for k in ARMS:
		var arm := arms[k]
		# (growing back)
		if arm.grown < 1.0:
			arm.grown = minf(arm.grown + delta / regrow_time, 1.0)
		var root := to_world * rig.root_of(k, body)
		var out := (to_world.basis * rig.out_of(k, body)).normalized()
		var want := _smoothed(_want(k, root, out, segment * arm.grown), 2 if doing[k] != Do.HOLD else 1)
		if not _settled:
			arm.settle(want)
		var stiff := 3.2
		var damp := 0.85
		match doing[k]:
			Do.WIND:
				stiff = 5.5
			Do.LASH:
				stiff = 13.0
				damp = 0.5
			Do.HOLD:
				stiff = 9.0
			Do.CRAWL:
				stiff = 5.0
			Do.TUCK:
				stiff = 4.0
		arm.step(delta, root, want, stiff, damp, floor_y, open, segment)
	_settled = true
	# The pose, in the skeleton's space.
	var to_skeleton := rig.skeleton.global_transform.affine_inverse()
	var points: Array = []
	var sides: Array = []
	for k in ARMS:
		var local := PackedVector3Array()
		local.resize(BONES + 1)
		for i in BONES + 1:
			local[i] = to_skeleton * arms[k].points[i]
		points.append(local)
		var faces := PackedVector3Array()
		faces.resize(BONES)
		for j in BONES:
			faces[j] = (to_skeleton.basis * arms[k].sides[j]).normalized()
		sides.append(faces)
	_breath += delta * lerpf(1.1, 2.6, clampf(mood, 0.0, 1.0))
	var swell := 1.0 + 0.045 * sin(_breath)
	# (in the water its mantle floats up behind; on the ground it sags back)
	var mantle := Basis(Vector3.RIGHT, lerpf(0.42, -0.08, sunk) - 0.1 * clampf(mood, 0.0, 1.0)) * Basis.from_scale(Vector3(swell, swell, swell * 1.02))
	_jet = maxf(_jet - delta * 0.8, 0.0)
	var siphon := Basis(Vector3.UP, 0.25 * sin(_breath) - 0.6 * _jet) * Basis.from_scale(Vector3.ONE * (1.0 + 0.35 * _jet))
	rig.pose(body, mantle, siphon, points, sides)
	_skin()
	_sounds(delta)


## Its body's pose in its own space: down in the ground as far as it is sunk,
## leaning a little as it crawls, squeezed thin passing a gap.
func _body(_delta: float) -> Transform3D:
	var lean := Basis.IDENTITY
	if crawling and velocity.length() > 0.1:
		var local := global_transform.basis.inverse() * velocity
		lean = Basis(Vector3.RIGHT, clampf(local.z * 0.08, -0.15, 0.15))
	var bob := 0.04 * sin(_breath * 0.5)
	var at := rig.body_rest + Vector3.DOWN * sunk * SINK_DEPTH + Vector3.UP * bob * (1.0 - sunk)
	return Transform3D(lean * Basis.from_scale(Vector3(squeeze, 1.0 / maxf(sqrt(squeeze), 0.5), 1.0)), at)


## Whether the ground is open at a point (its water, or the wall behind a drain's mouth).
func _open(point: Vector3) -> bool:
	if not mouth.is_finite():
		return false
	if mouth_out != Vector3.ZERO:
		return (point - mouth).dot(mouth_out) < 0.05
	return Vector2(point.x - mouth.x, point.z - mouth.z).length() < hole_radius


## The shape arm k wants to be in now (BONES + 1 points from `root`).
func _want(k: int, root: Vector3, out: Vector3, segment: float) -> PackedVector3Array:
	var arm := arms[k]
	var path := PackedVector3Array([root, root + out * 0.5])
	var down := sunk > 0.5 and mouth.is_finite()
	var goal := goals[k]
	var curl := 0.55
	var axis := Vector3.ZERO
	var t := _time * 0.7 + arm.phase
	match doing[k]:
		Do.TUCK:
			return _coiled(k, root, out, segment)
		Do.REST:
			if down:
				# (in its water: drawn in, coiled round under the surface)
				return _coiled(k, root, out, segment)
			# Sprawled on the ground about it, bent a little, the tip curled.
			var bend := out.rotated(Vector3.UP, 0.35 * sin(t * 0.3 + k))
			path.append(Vector3(root.x, floor_y + 0.15, root.z) + out * 1.2)
			path.append(Vector3(root.x, floor_y, root.z) + bend * (2.6 + 0.6 * sin(arm.phase * 3.0)))
			path.append(Vector3(root.x, floor_y, root.z) + bend.rotated(Vector3.UP, 0.4 * sin(t * 0.5)) * 5.4)
			curl = 0.55 + 0.25 * sin(t)
			axis = _curl_axis(path, 0.3, k)
			return _writhe(OctopusArm.lay(path, segment, curl, axis), 0.12, t)
		Do.FEEL:
			if down:
				_out_of_hole(k, out, goal, path)
			else:
				path.append(Vector3(root.x, floor_y + 0.15, root.z) + out * 1.0)
			var foot := Vector3(goal.x, floor_y + 0.05, goal.z)
			if walls[k] != Vector3.ZERO:
				foot += walls[k] * 0.25
				path.append(_meander(path[path.size() - 1], foot, 0.5, t, k))
				path.append(foot + Vector3.UP * 0.25)
				path.append(goal + walls[k] * 0.2)
			else:
				path.append(_meander(path[path.size() - 1], foot, 0.6, t, k))
				path.append(foot)
			# (its tip curls and uncurls, feeling)
			curl = 0.5 + 0.45 * sin(t * 1.3)
			axis = _curl_axis(path, 0.6, k)
			return _writhe(OctopusArm.lay(path, segment, curl, axis), 0.1, t)
		Do.WIND:
			# Up off the floor in an S, its end coiled tight, aimed at the goal.
			var start := root
			if down:
				start = _emerge(k, out, goal)
				path.append(start + Vector3.DOWN * 0.8)
				path.append(start)
			var towards := Vector3(goal.x - start.x, 0.0, goal.z - start.z)
			towards = towards.normalized() if towards.length() > 0.1 else out
			# (it rears up high, leaning back from what it is aimed at, and its last
			# stretch coils back on itself like a spring)
			var rise := minf(_since[k] / 0.45, 1.0)
			var lift := Vector3(start.x, floor_y, start.z)
			path.append(lift + towards * 1.0 + Vector3.UP * (0.4 + 0.8 * rise))
			path.append(lift + towards * 1.6 + Vector3.UP * (0.6 + 2.4 * rise))
			path.append(lift + towards * 1.5 + Vector3.UP * (0.9 + 3.6 * rise))
			path.append(lift + towards * 0.9 + Vector3.UP * (1.0 + 4.1 * rise))
			curl = 0.75 + 0.25 * rise
			axis = towards.cross(Vector3.UP).normalized()
			return OctopusArm.lay(path, segment, curl, axis)
		Do.LASH:
			var start := root
			if down:
				start = _emerge(k, out, goal)
				path.append(start + Vector3.DOWN * 0.6)
				path.append(start + Vector3.UP * 0.3)
			else:
				path.append(Vector3(root.x, floor_y + 0.8, root.z) + out * 0.8)
			var across := Vector3(goal.x - start.x, 0.0, goal.z - start.z)
			across = across.normalized() if across.length() > 0.1 else out
			path.append(goal + Vector3.UP * 0.6)
			path.append(Vector3(goal.x, floor_y + 0.1, goal.z) + across * 1.4)
			curl = 0.2
			axis = _curl_axis(path, 0.25, k)
			return OctopusArm.lay(path, segment, curl, axis)
		Do.HOLD:
			return _wrapped(k, root, out, goal, segment, path, down)
		Do.CRAWL:
			var plant := _plant(k, root, out)
			if down:
				_out_of_hole(k, out, plant, path)
			else:
				path.append(Vector3(root.x, floor_y + 0.25, root.z) + out * 1.1)
			var lift := sin(clampf(_lifting[k], 0.0, 1.0) * PI) * 0.9
			path.append(path[path.size() - 1].lerp(plant, 0.55) + Vector3.UP * lift)
			path.append(plant + Vector3.UP * lift * 0.4)
			curl = 0.35
			axis = _curl_axis(path, 0.2, k)
			return _slack(OctopusArm.lay(_bowed(path, segment * BONES), segment, curl, axis))
	return OctopusArm.lay(path, segment, curl, axis)


## Arm k coiled round down in its hole, out of sight (a slow turn of a coil
## under its water, or back in the drain behind its mouth); or, up on the
## ground, drawn in under it.
func _coiled(k: int, root: Vector3, out: Vector3, segment: float) -> PackedVector3Array:
	var path := PackedVector3Array([root])
	var middle := root
	var radius := 1.0
	if mouth.is_finite():
		middle = Vector3(mouth.x, root.y, mouth.z)
		if mouth_out != Vector3.ZERO:
			middle -= mouth_out * 1.6
			radius = 0.55
		else:
			radius = minf(hole_radius * 0.55, 1.2)
	var start := atan2(root.x - middle.x, root.z - middle.z)
	var steps := 28
	var turns := (segment * OctopusArm.BONES) / (TAU * radius) * 0.9
	var round_way := 1.0 if k % 2 == 0 else -1.0
	for s in range(1, steps + 1):
		var f := float(s) / steps
		var angle := start + round_way * (f * turns * TAU + sin(_time * 0.4 + arms[k].phase) * 0.2)
		var at := middle + Vector3(sin(angle), 0.0, cos(angle)) * radius * lerpf(1.0, 0.75, f)
		at.y = minf(root.y, floor_y - 0.9) - f * 1.4 + 0.25 * k / ARMS
		path.append(at)
	return OctopusArm.lay(path, segment, 0.6, Vector3.UP)


## Where arm k comes up out of its hole (its water's surface, or the drain's mouth), going `towards`.
func _emerge(k: int, out: Vector3, towards := Vector3.INF) -> Vector3:
	if mouth_out != Vector3.ZERO:
		var along := mouth_out.cross(Vector3.UP).normalized()
		return Vector3(mouth.x, floor_y + 0.12, mouth.z) + along * (float(k) / (ARMS - 1) - 0.5) * mouth_width * 0.8 + mouth_out * 0.05
	var way := out
	if towards.is_finite():
		var to := Vector3(towards.x - mouth.x, 0.0, towards.z - mouth.z)
		if to.length() > 0.2:
			way = (to.normalized() * 2.0 + out).normalized()
	return Vector3(mouth.x, floor_y, mouth.z) + Vector3(way.x, 0.0, way.z).normalized() * hole_radius * 0.55


## Adds to `path` the way up out of its hole to the floor, towards `goal`.
func _out_of_hole(k: int, out: Vector3, goal: Vector3, path: PackedVector3Array) -> void:
	var up := _emerge(k, out, goal)
	path.append(up + Vector3.DOWN * 1.0 - (mouth_out * 0.6 if mouth_out != Vector3.ZERO else Vector3.ZERO))
	path.append(up)
	var on := Vector3(goal.x - up.x, 0.0, goal.z - up.z)
	if on.length() > 0.3:
		path.append(up + on.normalized() * 0.4 + Vector3.UP * 0.1)


## The way an arm's end curls: round to one side over the floor, lifting by `lift`
## (0 flat on the floor, 1 straight up and over), about its last stretch.
func _curl_axis(path: PackedVector3Array, lift: float, k := 0) -> Vector3:
	var n := path.size()
	var last := (path[n - 1] - path[n - 2]).normalized() if n >= 2 else Vector3.FORWARD
	var side := last.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	# (the arms curl one way or the other, as they fall)
	var round_way := 1.0 if sin(arms[k].phase * 5.0) > 0.0 else -1.0
	return (Vector3.UP * round_way * (1.0 - lift) + side * lift).normalized()


## A shape with its corners rounded off (`passes` times), its root and tip left where they are.
static func _smoothed(points: PackedVector3Array, passes: int) -> PackedVector3Array:
	for p in passes:
		var was := points.duplicate()
		for i in range(1, points.size() - 1):
			points[i] = was[i] * 0.5 + (was[i - 1] + was[i + 1]) * 0.25
	return points


## A wandering line from `a` to `b` (one bend, swinging slowly), its middle.
func _meander(a: Vector3, b: Vector3, amount: float, t: float, k: int) -> Vector3:
	var span := b - a
	var side := span.cross(Vector3.UP).normalized() if Vector2(span.x, span.z).length() > 0.1 else Vector3.RIGHT
	return a.lerp(b, 0.5) + side * span.length() * 0.18 * amount * sin(t * 0.6 + k * 1.7)


## A slow writhe laid over a shape (more towards the tip), along the floor.
static func _writhe(points: PackedVector3Array, amount: float, t: float) -> PackedVector3Array:
	for i in range(2, points.size()):
		var f := float(i) / (points.size() - 1)
		var along := (points[i] - points[i - 1]).normalized()
		var side := along.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		points[i] += side * sin(f * 7.0 - t * 1.6) * amount * f * 3.0
	return points


## A line from its root to where its end should be, bowed into an S if it is
## shorter than the arm (so that the slack lies in curves, not in a bunch).
static func _bowed(path: PackedVector3Array, length: float) -> PackedVector3Array:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	if total >= length * 0.92 or path.size() < 3:
		return path
	# The last stretch is bowed sideways until the line is as long as the arm.
	var a := path[path.size() - 2]
	var b := path[path.size() - 1]
	var span := b - a
	var side := span.cross(Vector3.UP).normalized() if Vector2(span.x, span.z).length() > 0.05 else Vector3.RIGHT
	var before := total - span.length()
	var low := 0.0
	var high := 4.0
	var made := path
	for k in 12:
		var bow := (low + high) * 0.5
		var trial := path.slice(0, path.size() - 1)
		var run := before
		var last := a
		for s in range(1, 17):
			var f := s / 16.0
			var p := a + span * f + side * sin(f * TAU) * bow * span.length() * 0.25
			run += last.distance_to(p)
			last = p
			trial.append(p)
		made = trial
		if run < length * 0.95:
			low = bow
		else:
			high = bow
	return made


static func _slack(points: PackedVector3Array) -> PackedVector3Array:
	return points


## Arm k wound round what it holds at `goal`: along the floor to it (bowed, if
## it is near), then two and a half turns up round it.
func _wrapped(k: int, root: Vector3, out: Vector3, goal: Vector3, segment: float, path: PackedVector3Array, down: bool) -> PackedVector3Array:
	var start := root
	if down:
		start = _emerge(k, out, goal)
		path.append(start + Vector3.DOWN * 0.8 - (mouth_out * 0.5 if mouth_out != Vector3.ZERO else Vector3.ZERO))
		path.append(start)
	else:
		path.append(Vector3(root.x, floor_y + 0.25, root.z) + out * 1.0)
	var foot := Vector3(goal.x, floor_y, goal.z)
	var back := Vector3(start.x - foot.x, 0.0, start.z - foot.z)
	back = back.normalized() if back.length() > 0.1 else -out
	var approach := foot + back * 0.45 + Vector3.UP * 0.12
	path.append(approach)
	path = _bowed(path, segment * BONES - _helix_length())
	# Round it: from its feet up past its middle, the suckers inwards.
	var turns := 2.4
	var steps := 24
	var start_angle := atan2(back.x, back.z)
	for s in range(1, steps + 1):
		var f := float(s) / steps
		var angle := start_angle + f * turns * TAU
		var radius := lerpf(0.36, 0.3, f)
		path.append(foot + Vector3(sin(angle), 0.0, cos(angle)) * radius + Vector3.UP * lerpf(0.2, 1.25, f))
	return OctopusArm.lay(path, segment, 0.9, Vector3.UP)


static func _helix_length() -> float:
	return 2.4 * TAU * 0.33 + 1.1


## Where arm k's end is planted as it crawls: ahead of it, kept until the body
## has gone on far enough, then lifted and put down further on.
func _plant(k: int, root: Vector3, out: Vector3) -> Vector3:
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var forward := heading.normalized() if heading.length() > 0.1 else global_transform.basis.z.normalized()
	var front := out.dot(forward)
	var reach := lerpf(3.4, 5.6, clampf(front * 0.5 + 0.5, 0.0, 1.0))
	var ideal := Vector3(root.x, floor_y, root.z) + (out * 1.0 + forward * front * 0.4).normalized() * reach + heading * 0.8
	if not _plants[k].is_finite():
		_plants[k] = ideal
	if _lifting[k] > 0.0:
		_lifting[k] += get_process_delta_time() / 0.55
		if _lifting[k] >= 1.0:
			_lifting[k] = 0.0
			_plants[k] = ideal
			return ideal
		return _lift_from[k].lerp(ideal, _lifting[k])
	var lifting := 0
	for other in ARMS:
		if _lifting[other] > 0.0:
			lifting += 1
	if _plants[k].distance_to(ideal) > 2.0 and lifting < 3:
		_lifting[k] = 0.01
		_lift_from[k] = _plants[k]
	return _plants[k]


## Its skin: from `mood`, unless that is -1.
func _moods(delta: float) -> void:
	if mood < 0.0:
		return
	var calm := clampf(1.0 - mood, 0.0, 1.0)
	var striking := clampf(mood - 1.0, 0.0, 1.0)
	var winding := clampf(mood, 0.0, 1.0) * (1.0 - striking)
	var rate := 1.0 - exp(-delta * 5.0)
	reveal = lerpf(reveal, clampf(0.0 + 0.85 * winding + striking, 0.0, 1.0) if mood > 0.05 else 0.0, rate * 0.6)
	papillae = lerpf(papillae, 0.35 * calm + 1.0 * winding + 0.2 * striking, rate)
	waves = lerpf(waves, 0.9 * winding * (0.5 + 0.5 * sin(_time * 9.0)), rate)
	flush = lerpf(flush, 0.55 * winding * (0.5 + 0.5 * sin(_time * 14.0)) - 0.85 * striking, rate)


func _skin() -> void:
	for mesh in rig.meshes():
		mesh.set_instance_shader_parameter(&"reveal", reveal)
		mesh.set_instance_shader_parameter(&"flush", flush)
		mesh.set_instance_shader_parameter(&"papillae", papillae)
		mesh.set_instance_shader_parameter(&"waves", waves)
		mesh.set_instance_shader_parameter(&"floor_tone", floor_tone)
		mesh.set_instance_shader_parameter(&"wall_tone", wall_tone)
		mesh.set_instance_shader_parameter(&"water_tone", water_tone)
		mesh.set_instance_shader_parameter(&"water", water)
		mesh.set_instance_shader_parameter(&"floor_y", floor_y)
	for piece in _severed:
		if is_instance_valid(piece):
			var mesh := piece as MeshInstance3D
			mesh.set_instance_shader_parameter(&"floor_tone", floor_tone)
			mesh.set_instance_shader_parameter(&"floor_y", floor_y)


# --- A cut-off end ---

func _drop_piece(points: PackedVector3Array, from: float, to: float) -> void:
	var piece := MeshInstance3D.new()
	piece.top_level = true
	get_parent().add_child(piece)
	piece.global_transform = Transform3D.IDENTITY
	# (it falls to the floor and lies there)
	var laid := PackedVector3Array()
	for p in points:
		laid.append(Vector3(p.x, floor_y + 0.1, p.z))
	piece.mesh = _tube(laid, from, to)
	piece.material_override = OctopusLook.material()
	piece.set_instance_shader_parameter(&"reveal", 1.0)
	piece.set_instance_shader_parameter(&"writhe", 1.0)
	piece.set_instance_shader_parameter(&"flush", -0.3)
	piece.custom_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 40, 400))
	_severed.append(piece)
	var tween := piece.create_tween()
	tween.tween_method(func(w: float) -> void: piece.set_instance_shader_parameter(&"writhe", w), 1.0, 0.15, 7.0)
	tween.tween_property(piece, "position:y", -0.6, 3.0)
	tween.tween_callback(func() -> void:
		_severed.erase(piece)
		piece.queue_free())


## A tapering tube along `points` (an arm from `from` to `to` of its length, as the shader expects it).
static func _tube(points: PackedVector3Array, from: float, to: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	var rows: Array = []
	for i in points.size():
		var f := float(i) / (points.size() - 1)
		var along_arm := lerpf(from, to, f)
		var r := lerpf(0.3, 0.022, pow(along_arm, 0.75))
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var t := (b - a).normalized()
		var n := t.cross(Vector3.UP).normalized()
		if n.length() < 0.5:
			n = Vector3.RIGHT
		var bn := t.cross(n)
		var row := []
		for s in sides:
			var angle := TAU * s / sides
			var off := (n * cos(angle) + bn * sin(angle)) * r
			row.append([points[i] + off, off.normalized(), clampf(-off.normalized().y, 0.0, 1.0), f])
		rows.append(row)
	for i in rows.size() - 1:
		for s in sides:
			var s1 := (s + 1) % sides
			for corner: Array in [rows[i][s], rows[i + 1][s], rows[i + 1][s1], rows[i][s], rows[i + 1][s1], rows[i][s1]]:
				var p: Vector3 = corner[0]
				st.set_normal(corner[1])
				st.set_color(Color(1.0, corner[2], corner[3]))
				st.set_uv(Vector2(0.0, p.y))
				st.set_uv2(Vector2(p.x, p.z))
				st.add_vertex(p)
	return st.commit()


# --- Its sounds ---

func _play(stream: AudioStream, at: Vector3, louder: float) -> void:
	if _event == null:
		return
	_event.stream = stream
	_event.volume_db = volume_db + louder
	_event.global_position = at
	_event.play()


func _sounds(delta: float) -> void:
	if _slither == null:
		return
	var moving := 0.0
	var where := Vector3.ZERO
	var count := 0.0
	for k in ARMS:
		if doing[k] in [Do.TUCK] or (sunk > 0.5 and doing[k] == Do.REST):
			continue
		var m := arms[k].motion()
		moving += m
		where += arms[k].points[BONES * 2 / 3] * (m + 0.01)
		count += m + 0.01
	if count > 0.0:
		_slither.global_position = where / count
	var loud := clampf(moving / 3.0, 0.0, 1.0)
	if loud > 0.03:
		if not _slither.playing:
			_slither.play(_rng.randf() * 2.0)
		_slither.volume_db = lerpf(_slither.volume_db, volume_db - 16.0 + 14.0 * loud, 1.0 - exp(-delta * 4.0))
	elif _slither.playing:
		_slither.volume_db = lerpf(_slither.volume_db, -60.0, 1.0 - exp(-delta * 3.0))
		if _slither.volume_db < -50.0:
			_slither.stop()
