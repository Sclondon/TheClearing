class_name SkinwalkerRig
extends CharacterRig
## How the skinwalker (creatures/skinwalker/models/skinwalker.glb) moves: the
## whole figure is posed here, over CharacterRig (see `_pose_extra`); nothing
## of the boy's walk is kept. Its body (`Skinwalker`, skinwalker.gd) is this
## node's parent and says how fast it is going (`velocity`), whether it is up
## on its legs (`upright`), what it watches (`aim`), and starts what it does
## (`act`).
##
## - ON ALL FOURS (the coyote it pretends to be): it goes on its hands and the
##   balls of its feet, low, the hips and shoulders level, its knees splayed out
##   like a frog's and its elbows bent back like a dog's, the head held up to
##   look ahead so that the coyote's head it wears looks ahead too. Walking, its
##   limbs go round as a dog's do (hind, fore, on each side in turn), too
##   slowly and too long in the reach; now and then a limb hitches, or the head
##   jerks round to look and comes back.
## - RUNNING on all fours: a bound, hands together and feet together, the back
##   bunching and flinging out, far too fast. Before a burst it drops flat and
##   its head jerks down (the wind-up, `crouch`).
## - THE RISE (Act.RISE, RISE_TIME): it stops dead; its head turns to look at
##   you; its hips go up first, the legs straightening under it while the
##   hands stay planted, so that it stands bent double like an inverted V; then
##   the back unrolls, the chest last, the hands leave the ground and the arms
##   swing down, and it stands at its full height, its head tipping slowly over
##   to one side.
## - UPRIGHT it stands stooped, arms hanging past its knees, fingers twitching.
##   It walks in a jerky way: each step held, then snatched through.
## - THE CALL (Act.CALL): the head tips right over and back, the chest heaves,
##   the jaw of its face hangs: where its mimicked call comes from.
## - THE GRAB (Act.GRAB): both arms flung forward, the long fingers spread.
## - Its eyes shine (`glare`, 0..1: dimly always, bright when it hunts).
##
## The coyote's skin it wears hangs on bones of its own (pelt_*), each a weight
## on a spring: its empty legs and its tail swing as it moves.

enum Act { NONE, RISE, CALL, GRAB, DROP }

## Seconds the rise, the call, the grab and dropping back onto all fours take.
const RISE_TIME := 1.9
const CALL_TIME := 1.4
const GRAB_TIME := 0.7
const DROP_TIME := 0.6
## Where in the stride each limb comes down (hand left, hand right, foot left, foot right), walking and bounding.
const WALK: Array[float] = [0.25, 0.75, 0.0, 0.5]
const BOUND: Array[float] = [0.52, 0.6, 0.0, 0.07]
## The colour of its skin where it sinks in (the model's "skin" is the rest).
const SHADE := Color(0.3, 0.3, 0.32)

## 0 on all fours, 1 up on its legs: the body says which it should be (the rise is an act).
var upright := false
## Down flat for a burst (the wind-up), 0..1.
var crouch := 0.0
## What it watches, in the world (INF: nothing).
var aim := Vector3.INF
## How brightly its eyes shine, 0..1.
var glare := 0.0

var _doing := Act.NONE
var _doing_time := INF
var _up := 0.0
var _gait := 0.0
var _phase_up := 0.0
var _run_blend := 0.0
var _speed := 0.0
var _low := 0.0
var _was_at := Vector3.INF
var _gaze := Vector2.ZERO
var _twitch := 0.0
var _twitch_way := 1.0
var _twitch_in := 2.0
var _hitch := -1
var _hitch_left := 0.0
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _posed := false
var _eyes: ShaderMaterial
var _pelt: Array[PeltLink] = []
var _links_settled := false
var _tilt := 0.0


## A piece of the skin that hangs and swings: a bone pointing at a weight on a spring.
class PeltLink:
	var joint: Node3D
	var bone := -1
	var rest := Vector3.DOWN
	var length := 0.1
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var stiffness := 30.0
	var damping := 4.0
	var gravity := 14.0
	var limit := 0.9


static var _skin_shader: Shader
static var _eye_shader: Shader


func _build() -> void:
	dusty = false
	super()
	for side in ["_l", "_r"]:
		_pelt_link(_chest if _chest else _spine, "pelt_fore" + side, "pelt_fore_end" + side)
		_pelt_link(_hips, "pelt_hind" + side, "pelt_hind_end" + side)
	var tail := _pelt_link(_hips, "pelt_tail", "pelt_tail_1")
	_pelt_link(tail.joint, "pelt_tail_1", "pelt_tail_end").stiffness = 22.0
	settle()


func _pelt_link(parent: Node3D, bone: StringName, end: StringName) -> PeltLink:
	var link := PeltLink.new()
	link.joint = _joint(parent, bone, _rest(bone))
	link.bone = _skeleton.find_bone(bone)
	var reach := _rest(end)
	link.rest = reach.normalized()
	link.length = reach.length()
	_pelt.append(link)
	return link


## Shades it: its pale skin darker in its hollows (as the ghoul's), its eyes
## shining, and the coyote's skin furred as a coyote's (CoyoteLook).
func restyle() -> void:
	super()
	if not cel_shaded:
		return
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			match String(original.resource_name):
				"skin":
					part.set_surface_override_material(surface, skin_material(original.albedo_color))
				"pelt":
					var coat := CoyoteLook.coat_material(original.albedo_color, 0 if (low_poly or Settings.low_poly) else 2)
					DogLook.tune(coat, {&"face": -100.0, &"fur_length": 0.03, &"droop": 0.6, &"clumps": Vector2(26.0, 9.0)})
					part.set_surface_override_material(surface, coat)
				"eyes":
					_eyes = eye_material()
					part.set_surface_override_material(surface, _eyes)


static func skin_material(colour: Color) -> ShaderMaterial:
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = Toon.SHADER.replace("uniform vec3 albedo : source_color = vec3(1.0);",
				"uniform vec3 albedo : source_color = vec3(1.0);\nuniform vec3 shade : source_color = vec3(0.2);\nuniform float softness = 0.06;").replace(
				"ALBEDO = albedo * (1.0 - stripe * line);",
				"float sunk = smoothstep(0.5 - softness - fwidth(COLOR.r), 0.5 + softness + fwidth(COLOR.r), COLOR.r);\n\tALBEDO = mix(albedo, shade, sunk) * (1.0 - stripe * line);")
	var material := ShaderMaterial.new()
	material.shader = _skin_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"shade", SHADE)
	material.set_shader_parameter(&"softness", 0.06)
	return material


## Wet eyes that give back too much light: a pale yellow-white glow, strongest looking straight at them.
static func eye_material() -> ShaderMaterial:
	if _eye_shader == null:
		_eye_shader = Shader.new()
		_eye_shader.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 colour : source_color = vec3(0.95, 0.88, 0.55);
uniform float glare = 0.2;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 lit = colour * (0.35 + 0.65 * facing);
	ALBEDO = lit * (0.6 + glare * 2.6 * facing * facing);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _eye_shader
	return material


## Stands it still as it is, nothing in motion: for when it is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_up = 1.0 if upright else 0.0
	_posed = false
	_was_at = Vector3.INF
	_links_settled = false


## Begins the rise, the call, the grab or dropping back to all fours.
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF


func act_length(what: Act) -> float:
	match what:
		Act.RISE:
			return RISE_TIME
		Act.CALL:
			return CALL_TIME
		Act.GRAB:
			return GRAB_TIME
		Act.DROP:
			return DROP_TIME
	return 0.0


func doing() -> Act:
	return _doing


## How far up it is, 0 (on all fours) .. 1 (standing).
func how_upright() -> float:
	return _up


func _pose_extra(delta: float) -> void:
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= act_length(_doing):
			if _doing == Act.RISE:
				_up = 1.0
			elif _doing == Act.DROP:
				_up = 0.0
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time
	var going := _gone(delta)
	# (smoothed: a frame on which it happens not to move is not a stop)
	_speed = _approach(_speed, Vector2(going.x, going.z).length(), 12.0, delta)
	var speed := _speed
	if _doing == Act.NONE:
		_up = move_toward(_up, 1.0 if upright else 0.0, delta / 0.6)
	var rise := 0.0
	if _doing == Act.RISE:
		rise = t / RISE_TIME
	elif _doing == Act.DROP:
		_up = 1.0 - smoothstep(0.0, 1.0, t / DROP_TIME)
	var calling := 0.0
	if _doing == Act.CALL:
		calling = sin(PI * clampf(t / CALL_TIME, 0.0, 1.0))
	var grab := 0.0
	if _doing == Act.GRAB:
		grab = sin(PI * clampf(t / GRAB_TIME, 0.0, 1.0))
	_low = _approach(_low, crouch, 14.0, delta)
	_run_blend = _approach(_run_blend, smoothstep(1.3, 2.6, speed), 6.0, delta)
	if _eyes:
		_eyes.set_shader_parameter(&"glare", glare)

	# The rise, in its parts: the hips go up first (legs straightening, hands
	# still down), then the back unrolls, the chest last; then up to full height.
	var hips_up := _up
	var back_up := _up
	var hands_down := 1.0 - _up
	if _doing == Act.RISE:
		hips_up = smoothstep(0.12, 0.5, rise)
		back_up = smoothstep(0.4, 0.92, rise)
		hands_down = 1.0 - smoothstep(0.55, 0.75, rise)
	var stand := smoothstep(0.0, 1.0, back_up)

	# --- On all fours: the four limbs round a gait cycle ---
	var stride := lerpf(0.42, 1.25, _run_blend)
	_gait = fposmod(_gait + speed / stride * delta, 1.0)
	var moving := smoothstep(0.03, 0.25, speed)
	var duty := lerpf(0.64, 0.34, _run_blend)
	var lift := lerpf(0.06, 0.16, _run_blend)
	# (a limb hitches now and then, walking: held up a moment, then snatched down)
	_hitch_left -= delta
	if _hitch_left <= 0.0 and _run_blend < 0.3 and moving > 0.5 and randf() < delta * 0.25:
		_hitch = randi() % 4
		_hitch_left = randf_range(0.25, 0.45)
	if _hitch_left <= 0.0:
		_hitch = -1
	var low := 0.06 * _low
	var bound := 0.04 * sin(TAU * (_gait - 0.3) * 2.0) * _run_blend * moving
	var hip_crawl := Vector3(0.0, 0.47 - low + bound, -0.2)
	var shoulder_crawl := Vector3(0.0, 0.53 - low * 1.4 + bound * 0.6, 0.22)
	# (bounding, the back bunches up and flings out once a stride)
	var bunch := sin(TAU * (_gait - 0.55)) * 0.07 * _run_blend * moving
	hip_crawl.z += bunch
	shoulder_crawl.z -= bunch * 0.4
	var limbs: Array[Vector3] = []
	var toes: Array[float] = []
	for k in 4:
		var fore := k < 2
		var side := 1.0 if k % 2 == 0 else -1.0
		var at := fposmod(_gait - lerpf(WALK[k], BOUND[k], _run_blend), 1.0)
		var half := stride * duty * 0.5 * moving
		var home := Vector3(side * (0.15 if fore else 0.19), 0.0, (shoulder_crawl.z + 0.1) if fore else (hip_crawl.z - 0.16))
		var step := Vector3.ZERO
		if at < duty:
			step.z = lerpf(half, -half, at / duty)
		else:
			var s := (at - duty) / (1.0 - duty)
			step.z = lerpf(-half, half, smoothstep(0.0, 1.0, s))
			step.y = sin(PI * s) * lift * moving
		if k == _hitch:
			step.y = maxf(step.y, 0.1)
		limbs.append(home + step)
		toes.append(0.9 if not fore else 0.0)

	# --- Upright: the legs step in a jerky walk; the arms hang ---
	_phase_up = fposmod(_phase_up + speed / 0.75 * delta, 1.0)
	# (each step held, then snatched through)
	var steps := 4.0
	var shown := (floorf(_phase_up * steps) + smoothstep(0.45, 1.0, fposmod(_phase_up * steps, 1.0))) / steps
	var feet_up: Array[Vector3] = []
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var at := fposmod(shown - 0.5 * i, 1.0)
		var half := 0.24 * moving
		var foot := Vector3(side * (_hip_width + 0.02), 0.0, 0.0)
		if at < 0.6:
			foot.z = lerpf(half, -half, at / 0.6)
		else:
			var s := (at - 0.6) / 0.4
			foot.z = lerpf(-half, half, smoothstep(0.0, 1.0, s))
			foot.y = sin(PI * s) * 0.09 * moving
		feet_up.append(foot)

	# --- The body ---
	var hip_stand := Vector3(0.0, _hip_height - 0.02 - 0.012 * moving, 0.0)
	# (bent double: the hips right up, the hands still down in front)
	var hip_bent := Vector3(0.0, _hip_height - 0.08, -0.12)
	var hip_at := hip_crawl.lerp(hip_bent, hips_up).lerp(hip_stand, stand)
	var to_shoulders := shoulder_crawl - hip_crawl
	var crawl_pitch := atan2(to_shoulders.z, to_shoulders.y)
	var stoop := 0.22 + 0.1 * moving
	var pitch := lerpf(crawl_pitch, stoop, stand)
	if _doing == Act.RISE:
		# (as the hips go up with the hands down, the back tips further over)
		pitch = lerpf(crawl_pitch, 1.75, hips_up * (1.0 - stand)) * (1.0 - stand) + stoop * stand
	pitch += 0.25 * _low * (1.0 - stand) + 0.12 * calling * stand
	var rock := sin(TAU * shown) * 0.05 * moving * stand
	_hips.position = hip_at + Vector3(rock * 0.2, 0.0, 0.0)
	_hips.rotation = Vector3(pitch * 0.8, 0.0, -rock)
	# (the chest lags behind the rest of the back as it unrolls)
	var lag := 0.0
	if _doing == Act.RISE:
		lag = 0.5 * sin(PI * back_up)
	var heave := sin(_time * 7.0) * 0.08 * calling
	_spine.rotation = Vector3(pitch * 0.12 + lag * 0.3, 0.0, rock * 0.5)
	if _chest:
		_chest.rotation = Vector3(pitch * 0.08 + lag * 0.5 - heave, 0.0, rock * 0.4)

	# --- The head: looks ahead whichever way the back goes, at what it watches; twitches ---
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(1.5, 5.0)
		_twitch = 1.0
		_twitch_way = -1.0 if randf() < 0.5 else 1.0
	_twitch = maxf(_twitch - delta * 2.2, 0.0)
	var jerk := _twitch_way * pow(_twitch, 3.0) * 0.6
	var look := Vector2.ZERO
	if aim.is_finite():
		var to := to_local(aim) - (_hips.position + Vector3(0.0, 0.5, 0.0))
		look = Vector2(clampf(atan2(to.x, to.z), -1.4, 1.4), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6))
	_gaze = _gaze.lerp(look, 1.0 - exp(-(9.0 if _twitch > 0.3 else 4.0) * delta))
	# (risen, the head tips slowly over to one side: wrong)
	_tilt = _approach(_tilt, 0.55 * stand * (1.0 - calling) + 1.1 * calling, 1.2, delta)
	var held := -pitch * lerpf(0.95, 0.75, stand)
	var down := 0.35 * _low * (1.0 - stand) - 0.6 * calling
	if _neck:
		_neck.rotation = Vector3(held * 0.55 + _gaze.y * 0.4 + down * 0.5, _gaze.x * 0.45 + jerk * 0.4, _tilt * 0.3)
	_head.rotation = Vector3(held * 0.45 + _gaze.y * 0.6 + down * 0.5, _gaze.x * 0.55 + jerk * 0.6, _tilt * 0.7)

	# --- The legs ---
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var crawl_foot := limbs[2 + i]
		var bent_foot := Vector3(side * 0.16, 0.0, 0.0)
		var foot := crawl_foot.lerp(bent_foot, hips_up * (1.0 - stand)).lerp(feet_up[i], stand)
		var toes_up: float = lerpf(toes[2 + i], 0.0, stand)
		var target := foot + _ankle_offset(toes_up)
		var turn := side * 0.5 * (1.0 - stand)
		var basis_foot := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, toes_up)
		_toes[i].rotation.x = -toes_up * 0.9
		_solve_leg(i, side, to_hips * target, (to_hips.basis * basis_foot).orthonormalized(), side * lerpf(1.0, 0.12, stand))

	# --- The arms ---
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# On all fours: the hand on the ground under and ahead of the shoulder.
		var planted := limbs[i] + Vector3(0.0, 0.03, 0.0)
		# Up: hanging, long, past its knees, swinging a little as it walks.
		var swing := sin(TAU * shown + (0.0 if i == 0 else PI)) * 0.05 * moving
		var hanging := shoulder + Vector3(side * 0.06, -_upper_arm - _forearm + 0.03, 0.06 + swing)
		# Calling: hands up by its face, fingers spread. Grabbing: flung forward.
		var by_face := shoulder + Vector3(side * 0.02, 0.12, 0.22)
		var flung := shoulder + Vector3(side * 0.05, -0.05, _upper_arm + _forearm - 0.05)
		var goal := hanging.lerp(planted, hands_down)
		goal = goal.lerp(by_face, calling * 0.6).lerp(flung, grab)
		_hand_follow(i, goal, 60.0, 14.0, delta)
		# (on all fours the hands go where the gait puts them: a spring would lag a stride behind)
		if hands_down > 0.5 and grab <= 0.0:
			_hand_at[i] = _hand_at[i].lerp(goal, smoothstep(0.5, 0.9, hands_down))
			_hand_speed[i] = Vector3.ZERO
		var pole_crawl := Vector3(side * 0.7, 0.4, -1.0)
		var pole_up := Vector3(side * 0.5, -0.3, -0.8)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole_crawl.lerp(pole_up, 1.0 - hands_down)).normalized())
		var twitching := sin(_time * 23.0 + i * 2.0) * 0.08 * stand
		var curl := lerpf(0.05, 0.35 + twitching, 1.0 - hands_down)
		curl = lerpf(curl, -0.1, maxf(calling, grab))
		var splay := lerpf(0.9, 0.6, 1.0 - hands_down) + 0.5 * maxf(calling, grab)
		# (planted, the hand is bent back flat on the ground, the fingers forward)
		var wrist := lerpf(-1.3, 0.15, 1.0 - hands_down)
		_set_hand(i, curl, splay, wrist)
	_swing_pelt(delta)
	_posed = true


## The skin's empty legs and tail, each a weight on a spring under its bone.
func _swing_pelt(delta: float) -> void:
	var size := global_basis.get_scale().y
	for link in _pelt:
		var parent := (link.joint.get_parent() as Node3D).global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * link.joint.position
		var held := root + frame * link.rest * link.length * size
		if not _links_settled:
			link.tip = held
			link.velocity = Vector3.ZERO
		var before := link.tip
		var pull := (held - link.tip) * link.stiffness - link.velocity * link.damping
		link.velocity += (pull + Vector3.DOWN * link.gravity) * delta
		link.tip += link.velocity * delta
		var ground := global_position.y + 0.02
		link.tip.y = maxf(link.tip.y, ground)
		var along := (link.tip - root).normalized()
		var rest_way := (held - root).normalized()
		var off := rest_way.angle_to(along)
		if off > link.limit:
			along = rest_way.slerp(along, link.limit / off)
		link.tip = root + along * link.length * size
		link.velocity = (link.tip - before) / maxf(delta, 0.0001)
		link.joint.basis = Basis(Quaternion(link.rest, (frame.inverse() * along).normalized()))
	_links_settled = true


## How fast it is really going in its own space, from where it was a frame ago.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 0.8 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


func _hand_follow(i: int, goal: Vector3, stiffness: float, damping: float, delta: float) -> void:
	_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * delta
	_hand_at[i] += _hand_speed[i] * delta
	if not _posed:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


## Turns an arm to put its wrist at `point` (world), the elbow towards `pole`
## (as the ghoul's: GhoulRig._hinge_arm).
func _hinge_arm(i: int, point: Vector3, pole: Vector3) -> void:
	var shoulder := _shoulders[i]
	var from := shoulder.global_position
	var to := point - from
	var size := global_basis.get_scale().y
	var upper_length := _upper_arm * size
	var fore_length := _forearm * size
	var reach := clampf(to.length(), 0.1 * size, upper_length + fore_length - 0.005 * size)
	var direction := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var hinge := direction.cross(pole)
	hinge = hinge.normalized() if hinge.length_squared() > 0.0001 else global_basis.x.normalized()
	var angle := acos(clampf((upper_length * upper_length + reach * reach - fore_length * fore_length) / (2.0 * upper_length * reach), -1.0, 1.0))
	var upper_direction := direction.rotated(hinge, angle)
	var fore_direction := (from + direction * reach - (from + upper_direction * upper_length)).normalized()
	var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
	shoulder.basis = parent.inverse() * Basis(hinge, -upper_direction, hinge.cross(-upper_direction))
	var upper := shoulder.global_basis.orthonormalized()
	_elbows[i].basis = upper.inverse() * Basis(hinge, -fore_direction, hinge.cross(-fore_direction))


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)
