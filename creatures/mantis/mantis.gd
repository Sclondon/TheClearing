class_name GiantMantis
extends Node3D
## A giant praying mantis, about three metres tall standing, for any game: its
## look, every move and its sounds, and no thinking. Move it (position, and
## rotation.y: it faces +Z) and it walks to match; tell it where to look, when
## to strike, to make its threat display, or that it is eating.
##
##     var mantis := GiantMantis.new()
##     add_child(mantis)
##     mantis.settle()                        # feet down where it stands
##     mantis.look_at_point = player_head     # its head turns to follow (INF: it looks about)
##     mantis.strike(player_chest)            # a blur: forelegs out and shut
##     if mantis.strikes(their_chest, 0.3): ...
##     mantis.display = true                  # wings up and spread, forelegs open, abdomen curled
##     mantis.eating = true                   # forelegs to its jaws, chewing
##
## STILL. It stands as a mantis does, on its four walking legs, its prothorax
## reared, its forelegs folded together under its head "in prayer", and rocks
## gently back and forth and from side to side like a leaf in a breeze (`sway`,
## 0 to stop). Its feelers drift. Its head turns to `look_at_point` in small
## quick jerks, as a mantis's does, far round (it can look nearly behind it):
## the one thing about it that moves with purpose.
##
## WALKING. Its legs step two at a time, mid on one side with hind on the other,
## each lifted high and put down ahead, and its body rocks forward and back
## over them as it goes (the swaying walk). Speed is measured from how it is
## moved (or set `velocity` with `measure_velocity` false).
##
## THE STRIKE (`strike(point)`): a twitch as the forelegs cock (STRIKE_COCK
## seconds), then they shoot out at the point, opening as they go, and the
## prothorax lunges after them (STRIKE_SHOOT: the fastest thing it does), then
## the spined tibiae snap shut on whatever is there (STRIKE_CLAMP), and they
## draw back in (STRIKE_RETRACT), or, with `holding` set, carry it to its jaws.
## `strikes(point, radius)` says whether the shooting forelegs pass within
## `radius` of a point; `struck` is emitted as they reach out.
##
## THE DISPLAY (`display`): it rears up taller, throws its forewings up and
## spreads its smoky hindwings behind them like a sail, opens its forelegs wide
## to show the dark spots inside them, curls its abdomen up, and sways from side
## to side, hissing (the rustle of its wings rubbed by its abdomen).
##
## SOUNDS, made in code (`sound`): a faint rustle of leaves when it shifts
## (`rustle()`), the snap of a strike, the hiss of its display.
##
## Every part is a bone of the model's skeleton (tools/build_mantis.py), posed
## here each frame: the walking legs with two-bone IK to their feet, the rest
## laid on in turns. One draw (one material); about 4900 triangles, 2000 in
## the low model (`low_poly`).

signal struck
signal rustled

enum Strike { NONE, COCK, SHOOT, CLAMP, RETRACT }

const STRIKE_COCK := 0.11
const STRIKE_SHOOT := 0.065
const STRIKE_CLAMP := 0.14
const STRIKE_RETRACT := 0.42
## How far the shoulders are from where it stands (in front, and up), and how
## far the forelegs reach from them, metres.
const ARM_REACH := 1.8
## Walking: how far a foot may be from where it should be before it steps, and how long a step takes.
const STEP_FAR := 0.42
const STEP_TIME := 0.3
const STEP_HIGH := 0.32

@export var low_poly := false
@export var sound := true
@export var volume_db := -9.0
## How much it rocks standing (0: still as a stick).
@export var sway := 1.0
## Its speed is measured from how it is moved (or set `velocity`).
@export var measure_velocity := true

var look_at_point := Vector3.INF
var display := false
var eating := false
## After a strike, hold what it caught and carry it to its jaws (until let go).
var holding := false
var velocity := Vector3.ZERO

var skeleton: Skeleton3D
var _model: Node3D
var _bones := {}
var _rest := {}
var _parent := {}
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _last_at := Vector3.ZERO
var _last_yaw := 0.0
var _turning := 0.0

var _strike := Strike.NONE
var _strike_t := 0.0
var _strike_at := Vector3.ZERO
var _strike_mix := 0.0
var _shown := 0.0
var _eat := 0.0
var _hold := 0.0

# The head's aim (yaw, pitch, in the prothorax's frame), where it is jerking to, and when it jerks next.
var _head := Vector2.ZERO
var _head_goal := Vector2.ZERO
var _jerk_in := 0.0

# The walking legs: foot world positions planted, stepping from and to, how far through.
const LEGS := ["mid_l", "mid_r", "hind_l", "hind_r"]
## Where each walking leg's foot (the end of its tarsus) is at rest, in the model (tools/build_mantis.py's MID and HIND).
const FEET_REST := {"mid_l": Vector3(1.18, 0.0, 0.92), "mid_r": Vector3(-1.18, 0.0, 0.92), "hind_l": Vector3(1.26, 0.0, -1.24), "hind_r": Vector3(-1.26, 0.0, -1.24)}
var _feet := {}
var _from := {}
var _to := {}
var _step := {}
var _pair := 0

var _voice: AudioStreamPlayer3D
static var _rustle_sound: AudioStreamWAV
static var _snap_sound: AudioStreamWAV
static var _hiss_sound: AudioStreamWAV


func _ready() -> void:
	_rng.seed = hash(get_path()) if is_inside_tree() else 1
	_model = MantisLook.model(low_poly)
	add_child(_model)
	var found := _model.find_children("*", "Skeleton3D", true, false)
	skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	if skeleton == null:
		push_error("GiantMantis: the model has no skeleton")
		return
	for i in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(i)] = i
	# Where each bone is at rest, in the model (every rest turns nothing: only moves)
	for i in skeleton.get_bone_count():
		var at := skeleton.get_bone_rest(i).origin
		var up := skeleton.get_bone_parent(i)
		_parent[i] = up
		_rest[i] = at + (_rest[up] as Vector3 if up >= 0 else Vector3.ZERO)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.unit_size = 4.0
		_voice.max_distance = 30.0
		_voice.volume_db = volume_db
		_voice.max_polyphony = 3
		add_child(_voice)
	_last_at = global_position
	_last_yaw = global_rotation.y
	settle()


func bone(name: String) -> int:
	return _bones.get(name, -1)


## Puts its feet down where they belong for where it stands now.
func settle() -> void:
	if skeleton == null:
		return
	for leg: String in LEGS:
		_feet[leg] = _home_of(leg)
		_step[leg] = -1.0
	_last_at = global_position
	_last_yaw = global_rotation.y


## Strikes at `point`: cock, shoot, clamp, draw back.
func strike(point: Vector3) -> void:
	_strike = Strike.COCK
	_strike_t = 0.0
	_strike_at = point
	_play(snap_sound(), 1.0, -2.0)


func strike_stage() -> Strike:
	return _strike


func striking() -> bool:
	return _strike != Strike.NONE


## Where the claws (the tibiae's tips) of both forelegs are, in the world.
func claws() -> Array[Vector3]:
	var tips: Array[Vector3] = []
	if skeleton == null:
		return tips
	for side: String in ["_l", "_r"]:
		tips.append(_claw(side))
	return tips


func _claw(side: String) -> Vector3:
	var tibia := bone("tibia" + side)
	var along := (_rest[bone("tarsus" + side)] as Vector3) - (_rest[tibia] as Vector3)
	return skeleton.global_transform * (skeleton.get_bone_global_pose(tibia) * (along + along.normalized() * 0.12))


## Whether the forelegs, shooting out or shutting, pass within `radius` of `point`.
func strikes(point: Vector3, radius: float) -> bool:
	if not (_strike in [Strike.SHOOT, Strike.CLAMP]) or skeleton == null:
		return false
	for side: String in ["_l", "_r"]:
		var femur := skeleton.global_transform * skeleton.get_bone_global_pose(bone("femur" + side)).origin
		var knee := skeleton.global_transform * skeleton.get_bone_global_pose(bone("tibia" + side)).origin
		var tip := _claw(side)
		for segment: Array in [[femur, knee], [knee, tip]]:
			var a: Vector3 = segment[0]
			var b: Vector3 = segment[1]
			var t := clampf((point - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
			if point.distance_to(a.lerp(b, t)) < radius + 0.12:
				return true
	return false


## A faint rustle, as of leaves (it has shifted).
func rustle() -> void:
	_play(rustle_sound(), _rng.randf_range(0.85, 1.15), -3.0)
	rustled.emit()


# --- Each frame ---

func _process(delta: float) -> void:
	if skeleton == null:
		return
	delta = minf(delta, 0.1)
	_time += delta
	if measure_velocity:
		var moved := (global_position - _last_at) / maxf(delta, 0.0001)
		moved.y = 0.0
		velocity = velocity.lerp(moved, minf(delta * 8.0, 1.0))
	_turning = angle_difference(_last_yaw, global_rotation.y) / maxf(delta, 0.0001)
	_last_at = global_position
	_last_yaw = global_rotation.y
	_strike_step(delta)
	var showing := 1.0 if display and _strike == Strike.NONE else 0.0
	if showing > _shown and _shown < 0.05 and display:
		_play(hiss_sound(), _rng.randf_range(0.9, 1.1), 0.0)
	# (a strike throws the display off at once: it is a blur)
	_shown = move_toward(_shown, showing, delta * (3.0 if display else (14.0 if striking() else 1.5)))
	_eat = move_toward(_eat, 1.0 if (eating or (holding and _strike == Strike.NONE)) else 0.0, delta * 2.5)
	_aim_head(delta)
	_walk(delta)
	_pose()


func _strike_step(delta: float) -> void:
	if _strike == Strike.NONE:
		_strike_mix = move_toward(_strike_mix, 0.0, delta * 3.0)
		return
	_strike_t += delta
	match _strike:
		Strike.COCK:
			if _strike_t >= STRIKE_COCK:
				_strike = Strike.SHOOT
				_strike_t = 0.0
				struck.emit()
		Strike.SHOOT:
			if _strike_t >= STRIKE_SHOOT:
				_strike = Strike.CLAMP
				_strike_t = 0.0
		Strike.CLAMP:
			if _strike_t >= STRIKE_CLAMP:
				_strike = Strike.RETRACT
				_strike_t = 0.0
		Strike.RETRACT:
			if _strike_t >= STRIKE_RETRACT:
				_strike = Strike.NONE
				_strike_t = 0.0


# The head jerks to where it is to look, in small quick turns.
func _aim_head(delta: float) -> void:
	_jerk_in -= delta
	if _jerk_in <= 0.0:
		_jerk_in = _rng.randf_range(0.12, 0.35)
		if look_at_point.is_finite() and not (_strike in [Strike.SHOOT, Strike.CLAMP]):
			var head_at := skeleton.global_transform * (_rest[bone("head")] as Vector3)
			var to := skeleton.global_transform.basis.inverse() * (look_at_point - head_at)
			var yaw := atan2(to.x, to.z)
			var pitch := atan2(-to.y, Vector2(to.x, to.z).length())
			_head_goal = Vector2(clampf(yaw, -2.2, 2.2), clampf(pitch, -0.7, 0.9))
		else:
			# (looking about: now and then a small turn this way or that)
			if _rng.randf() < 0.35:
				_head_goal = Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.1, 0.3))
	var rate := 16.0 if look_at_point.is_finite() else 6.0
	_head = Vector2(move_toward(_head.x, _head_goal.x, rate * delta * maxf(absf(_head_goal.x - _head.x), 0.4)), move_toward(_head.y, _head_goal.y, rate * delta * maxf(absf(_head_goal.y - _head.y), 0.4)))


# Where a walking leg's foot belongs (in the world) for where the mantis stands now.
func _home_of(leg: String) -> Vector3:
	var at := skeleton.global_transform * (FEET_REST[leg] as Vector3)
	at.y = global_position.y
	return at


func _leg_bone(leg: String, part: String) -> String:
	var parts := leg.split("_")
	return "%s_%s_%s" % [parts[0], part, parts[1]]


# Steps the walking legs: two at a time (mid on one side with hind on the other).
func _walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var stepping := false
	for leg: String in LEGS:
		if float(_step[leg]) >= 0.0:
			stepping = true
	var lead := velocity * STEP_TIME * 0.9
	for leg: String in LEGS:
		var t := float(_step[leg])
		if t >= 0.0:
			t += delta / STEP_TIME
			if t >= 1.0:
				_feet[leg] = _to[leg]
				_step[leg] = -1.0
			else:
				_step[leg] = t
				var arc := sin(t * PI) * STEP_HIGH
				_feet[leg] = (_from[leg] as Vector3).lerp(_to[leg], smoothstep(0.0, 1.0, t)) + Vector3.UP * arc
	if stepping:
		return
	# (none stepping: the pair whose feet are furthest from where they belong steps, if far enough)
	var pairs := [["mid_l", "hind_r"], ["mid_r", "hind_l"]]
	var worst := -1
	var most := STEP_FAR * (0.6 if speed > 0.1 or absf(_turning) > 0.3 else 1.0)
	for p in 2:
		for leg: String in pairs[p]:
			var off := (_feet[leg] as Vector3).distance_to(_home_of(leg) + lead)
			if off > most:
				most = off
				worst = p
	if worst < 0:
		return
	for leg: String in pairs[worst]:
		_from[leg] = _feet[leg]
		_to[leg] = _home_of(leg) + lead
		_step[leg] = 0.0


# --- Posing ---

func _turn_bone(name_of: String, rotation_now: Quaternion) -> void:
	var i := bone(name_of)
	if i >= 0:
		skeleton.set_bone_pose_rotation(i, rotation_now)


func _pose() -> void:
	var walk := clampf(Vector2(velocity.x, velocity.z).length() / 0.8, 0.0, 1.0)
	var lunge := 0.0
	var cock := 0.0
	match _strike:
		Strike.COCK:
			cock = smoothstep(0.0, 1.0, _strike_t / STRIKE_COCK)
		Strike.SHOOT:
			cock = 1.0 - _strike_t / STRIKE_SHOOT
			lunge = smoothstep(0.0, 1.0, _strike_t / STRIKE_SHOOT)
		Strike.CLAMP:
			lunge = 1.0
		Strike.RETRACT:
			lunge = 1.0 - smoothstep(0.0, 1.0, _strike_t / STRIKE_RETRACT)
	# The whole of it rocks like a leaf (more as it walks), rears in its display and lunges in a strike
	var rock := sway * (0.06 * sin(_time * 2.1) + 0.035 * sin(_time * 3.4 + 1.3) + 0.02 * sin(_time * 5.3 + 0.4)) + walk * 0.06 * sin(_time * 5.0)
	var side_rock := sway * (0.025 * sin(_time * 1.6 + 0.7) + 0.015 * sin(_time * 2.9)) + _shown * 0.06 * sin(_time * 3.0)
	var root := bone("root")
	skeleton.set_bone_pose_position(root, (_rest[root] as Vector3) + Vector3(side_rock, 0.0, rock + lunge * 0.3))
	skeleton.set_bone_pose_rotation(root, Quaternion.from_euler(Vector3(rock * 0.25, 0.0, -side_rock * 0.8)))
	_turn_bone("body", Quaternion.from_euler(Vector3(lunge * 0.08 - _shown * 0.05, 0.0, 0.0)))
	# The prothorax: reared up more in the display, thrown forward in a strike, eased down eating
	var rear := -_shown * 0.22 + lunge * 0.42 - cock * 0.06 + _eat * 0.08
	_turn_bone("pronotum", Quaternion.from_euler(Vector3(rear, side_rock * 0.6, sin(_time * 1.3) * 0.02 * sway)))
	# The head: its aim, and chewing when it eats
	var chew := _eat * 0.08 * sin(_time * 9.0)
	_turn_bone("head", Quaternion.from_euler(Vector3(_head.y - rear * 0.8 + chew + _eat * 0.25, _head.x, 0.0)))
	for side: String in ["_l", "_r"]:
		var s := 1.0 if side == "_l" else -1.0
		var drift := sin(_time * (0.9 + 0.2 * s) + s) * 0.18
		_turn_bone("antenna" + side, Quaternion.from_euler(Vector3(drift * 0.6 - _shown * 0.3, drift * 0.4 * s, 0.0)))
		_turn_bone("antenna_tip" + side, Quaternion.from_euler(Vector3(drift * 0.8, 0.0, drift * 0.3 * s)))
		_foreleg(side, s, cock, lunge)
		# The wings: folded flat, or up and spread in the display
		var lift := _shown * 1.15
		_turn_bone("tegmen" + side, Quaternion.from_euler(Vector3(lift, s * _shown * 0.45, s * _shown * 0.35)))
		var fan := bone("hindwing" + side)
		skeleton.set_bone_pose_rotation(fan, Quaternion.from_euler(Vector3(lift * 0.95, s * _shown * 0.3, s * _shown * 0.55)))
		skeleton.set_bone_pose_scale(fan, Vector3(lerpf(0.1, 1.0, _shown), 1.0, lerpf(0.97, 1.0, _shown)))
	# The abdomen: breathing, and curled up in the display
	var breathe := 0.02 * sin(_time * 1.8)
	_turn_bone("abdomen", Quaternion.from_euler(Vector3(breathe + _shown * 0.18, 0.0, 0.0)))
	_turn_bone("abdomen_2", Quaternion.from_euler(Vector3(_shown * 0.45 + breathe, 0.0, 0.0)))
	_legs()


# The forelegs: folded in prayer; cocked; shot out at the strike point and
# shut; spread wide in the display; or at its jaws, eating.
func _foreleg(side: String, s: float, cock: float, lunge: float) -> void:
	var coxa := Quaternion.IDENTITY
	var femur := Quaternion.IDENTITY
	var tibia := Quaternion.IDENTITY
	# (prayer, with a little life in it)
	var idle := sin(_time * 1.1 + s * 0.5) * 0.03 * sway
	coxa = Quaternion.from_euler(Vector3(idle, 0.0, 0.0))
	# Cocked: the femora lifted, the tibiae a little open
	if cock > 0.0:
		coxa = coxa.slerp(Quaternion.from_euler(Vector3(-0.25, -s * 0.05, 0.0)), cock)
		femur = femur.slerp(Quaternion.from_euler(Vector3(-0.35, 0.0, 0.0)), cock)
		tibia = tibia.slerp(Quaternion.from_euler(Vector3(-0.4, 0.0, 0.0)), cock)
	# Shot out at the point and shut on it
	if _strike in [Strike.SHOOT, Strike.CLAMP, Strike.RETRACT]:
		var reach := _reach_pose(side, s)
		var shut := 0.0
		if _strike == Strike.CLAMP:
			shut = smoothstep(0.0, 0.6, _strike_t / STRIKE_CLAMP)
		elif _strike == Strike.RETRACT:
			shut = 1.0
		var open_tibia: Quaternion = reach[2]
		# (shut is how it lies at rest: folded back against the femur)
		var closed_tibia := Quaternion.IDENTITY
		var mix := lunge
		coxa = coxa.slerp(reach[0], mix)
		femur = femur.slerp(reach[1], mix)
		tibia = tibia.slerp(open_tibia.slerp(closed_tibia, shut), mix)
	# Spread wide in the display, the spots inside showing
	if _shown > 0.0:
		var spread := _shown
		coxa = coxa.slerp(Quaternion.from_euler(Vector3(-0.55, s * 0.25, s * 0.95)), spread)
		femur = femur.slerp(Quaternion.from_euler(Vector3(-0.5, 0.0, s * 0.2)), spread)
		tibia = tibia.slerp(Quaternion.from_euler(Vector3(-0.9, 0.0, 0.0)), spread)
	# Eating: drawn up to the jaws
	if _eat > 0.0:
		coxa = coxa.slerp(Quaternion.from_euler(Vector3(-0.85, -s * 0.06, -s * 0.16)), _eat)
		femur = femur.slerp(Quaternion.from_euler(Vector3(0.45, 0.0, 0.0)), _eat)
		tibia = tibia.slerp(Quaternion.from_euler(Vector3(-0.15 + 0.08 * sin(_time * 7.0 + s), 0.0, 0.0)), _eat)
	_turn_bone("coxa" + side, coxa)
	_turn_bone("femur" + side, femur)
	_turn_bone("tibia" + side, tibia)
	_turn_bone("tarsus" + side, Quaternion.from_euler(Vector3(0.2 * (lunge + _shown), 0.0, 0.0)))


# The forelegs reaching for the strike point: each segment turned (from how it
# lies at rest) to lie along the line from the shoulder to the point, the
# coxa a little below it; as local turns, from the prothorax lunged forward.
func _reach_pose(side: String, s: float) -> Array:
	var pronotum := bone("pronotum")
	# (the prothorax as it will be at the full lunge, in the model)
	var lunged := Transform3D(Basis(Quaternion.from_euler(Vector3(0.42, 0.0, 0.0))), _rest[pronotum])
	lunged = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.3)) * lunged
	var coxa_rest: Vector3 = _rest[bone("coxa" + side)]
	var femur_rest: Vector3 = _rest[bone("femur" + side)]
	var tibia_rest: Vector3 = _rest[bone("tibia" + side)]
	var tarsus_rest: Vector3 = _rest[bone("tarsus" + side)]
	var shoulder := lunged * (coxa_rest - (_rest[pronotum] as Vector3))
	var target := skeleton.global_transform.affine_inverse() * _strike_at
	var aim := (target - shoulder).normalized()
	if aim.length() < 0.5:
		aim = Vector3(0.0, -0.3, 1.0).normalized()
	# (the two forelegs reach a hand's width apart, to close on it from both sides)
	var spread := Vector3(s * 0.06, 0.0, 0.0)
	var coxa_dir := (aim + Vector3.DOWN * 0.35).normalized()
	var femur_dir := (aim + Vector3.UP * 0.05).normalized()
	var tibia_dir := (aim + spread).normalized()
	var coxa_global := Quaternion(((femur_rest - coxa_rest)).normalized(), coxa_dir)
	var femur_global := Quaternion((tibia_rest - femur_rest).normalized(), femur_dir)
	var tibia_global := Quaternion((tarsus_rest - tibia_rest).normalized(), tibia_dir)
	var parent := lunged.basis.get_rotation_quaternion()
	var coxa_local := parent.inverse() * coxa_global
	var femur_local := coxa_global.inverse() * femur_global
	var tibia_local := femur_global.inverse() * tibia_global
	return [coxa_local, femur_local, tibia_local]


# The walking legs, each femur and tibia turned so that the knee is up and out
# and the foot is where it is planted (two-bone IK in the model).
func _legs() -> void:
	var to_model := skeleton.global_transform.affine_inverse()
	var body_pose := skeleton.get_bone_global_pose(bone("body"))
	for leg: String in LEGS:
		var femur := bone(_leg_bone(leg, "femur"))
		var tibia := bone(_leg_bone(leg, "tibia"))
		var hip_rest: Vector3 = _rest[femur]
		var knee_rest: Vector3 = _rest[tibia]
		var foot_rest: Vector3 = FEET_REST[leg]
		var upper := hip_rest.distance_to(knee_rest)
		var lower := knee_rest.distance_to(foot_rest)
		var hip := body_pose * (hip_rest - (_rest[bone("body")] as Vector3))
		var foot := to_model * (_feet[leg] as Vector3)
		var to_foot := foot - hip
		var reach := clampf(to_foot.length(), absf(upper - lower) + 0.01, upper + lower - 0.01)
		var way := to_foot.normalized()
		# (the knee bends up and out)
		var side := 1.0 if leg.ends_with("_l") else -1.0
		var pole := (Vector3(side, 1.6, 0.0)).normalized()
		pole = (pole - way * pole.dot(way)).normalized()
		var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
		var rise := sqrt(maxf(upper * upper - along * along, 0.0))
		var knee := hip + way * along + pole * rise
		foot = hip + way * reach
		var femur_global := _turn_between(knee_rest - hip_rest, foot_rest - knee_rest, knee - hip, foot - knee)
		var tibia_global := _turn_between(foot_rest - knee_rest, knee_rest - hip_rest, foot - knee, knee - hip)
		var parent := body_pose.basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(femur, parent.inverse() * femur_global)
		skeleton.set_bone_pose_rotation(tibia, femur_global.inverse() * tibia_global)


# The turn that takes the segment `from` (with `from_other` beside it, to fix
# its twist) to lie along `to` (with `to_other`).
func _turn_between(from: Vector3, from_other: Vector3, to: Vector3, to_other: Vector3) -> Quaternion:
	var a := _frame(from, from_other)
	var b := _frame(to, to_other)
	return (b * a.inverse()).get_rotation_quaternion()


func _frame(along: Vector3, other: Vector3) -> Basis:
	var y := along.normalized()
	var x := y.cross(other).normalized()
	if x.length() < 0.001:
		x = y.cross(Vector3.FORWARD).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


# --- Its sounds ---

func _play(stream: AudioStreamWAV, pitch: float, louder: float) -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.volume_db = volume_db + louder
	_voice.global_position = global_position + global_basis * Vector3(0.0, 2.6, 0.8)
	_voice.play()


## Dry leaves stirred: a soft breathy shush (0.5 s).
static func rustle_sound() -> AudioStreamWAV:
	if _rustle_sound:
		return _rustle_sound
	_rustle_sound = _noise(0.5, 11, func(t: float, raw: float, k: int) -> float:
		var shape := sin(minf(t / 0.5, 1.0) * PI) * (0.6 + 0.4 * sin(t * 47.0) * sin(t * 13.0))
		return raw * shape * 0.35)
	return _rustle_sound


## The strike: a whip-crack and a dry snap of the forelegs shutting (0.25 s).
static func snap_sound() -> AudioStreamWAV:
	if _snap_sound:
		return _snap_sound
	_snap_sound = _noise(0.25, 29, func(t: float, raw: float, k: int) -> float:
		var whip := exp(-absf(t - 0.11) * 60.0) * 0.5
		var crack := exp(-maxf(t - 0.17, 0.0) * 160.0) * float(t >= 0.17)
		return raw * (whip + crack))
	return _snap_sound


## The display: a hiss, the abdomen rubbed against the wings (1.1 s).
static func hiss_sound() -> AudioStreamWAV:
	if _hiss_sound:
		return _hiss_sound
	_hiss_sound = _noise(1.1, 41, func(t: float, raw: float, k: int) -> float:
		var shape := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.7, 1.1, t))
		var rasp := 0.6 + 0.4 * sin(t * TAU * 38.0)
		return raw * shape * rasp * 0.5)
	return _hiss_sound


static func _noise(seconds: float, seed_value: int, shape: Callable) -> AudioStreamWAV:
	var rate := 22050
	var long := int(rate * seconds)
	var chance := RandomNumberGenerator.new()
	chance.seed = seed_value
	var data := PackedByteArray()
	data.resize(long * 2)
	var low := 0.0
	for k in long:
		var raw := chance.randf_range(-1.0, 1.0)
		low += (raw - low) * 0.5
		var value: float = shape.call(float(k) / rate, raw - low * 0.6, k)
		data.encode_s16(k * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	made.data = data
	return made
