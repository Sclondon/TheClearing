class_name PsychicChildRig
extends CharacterRig
## How the psychic child (creatures/psychic_child/models/psychic_child.glb)
## moves: the whole figure is posed here, over CharacterRig's joints, and
## nothing of the boy's walk is used (see `_process`: CharacterRig's own posing
## is not run at all, which keeps her cheap). Her body (`PsychicChild`,
## psychic_child.gd) is this node's parent and says how fast she is going
## (`velocity`), what she looks at (`aim`), how `distress`ed she is and whether
## she is `drained`, and starts the one thing she does, `act(Act.BURST)`.
##
## - SHE DRIFTS. She never walks: she hangs a hand's breadth off the ground,
##   rising and sinking a little, her legs dangling with the toes pointed and
##   now and then brushing the ground, paddling slowly as if in water, trailing
##   behind her as she goes. Her arms hang a little behind her, as if she were
##   drawn along by something ahead. Her head is tilted over, sadly; humming,
##   it sways slowly from side to side; it turns to whatever she looks at.
## - DISTRESS (0..1) curls her up in the air: her shoulders come up, her hands
##   come up to clutch her head, her elbows in front of her face, her head
##   bowed between them and shaking; her knees draw up; she rises; and it all
##   trembles, harder the nearer she is to bursting.
## - REACHING (`reach`, at `reach_at`): her right arm held straight out at what
##   she has hold of with her mind, the hand open, fingers stiff and spread,
##   shaking; her left hand to her temple; the curl of her distress held back.
## - THE BURST (BURST seconds) flings her open: arms thrown out wide, fingers
##   splayed stiff, head thrown back, her back arched, legs straight, up in the
##   air; she hangs there, then sags and sinks to the ground.
## - DRAINED she sits on the ground, knees drawn up, arms round them, her head
##   bowed onto them: still, but for her slow breath.
##
## Its joints are the mummy's and the boy's (the same bone names), so any figure
## built on them can be moved by it.

enum Act { NONE, BURST }

## Seconds the burst takes (flung open, held, and sinking).
const BURST := 1.1
## How high her hips are sitting on the ground (rig space, as modelled).
const SITTING := 0.085
## How far off the ground she hangs, drifting (rig space).
const HOVER := 0.045

## What she looks at, in the world; INF for nothing.
var aim := Vector3.INF
## How distressed she is, 0..1 (the body sets it; she eases into it).
var distress := 0.0
## Drained (sitting), 0..1 (the body sets the target; she eases into it).
var drained := 0.0
## Humming: her head sways with the tune.
var humming := true
## Poses a second (0: every frame): fewer, to cost less, when she is far enough off for it not to show.
var pose_rate := 0.0
## Reaching out with her mind for something (0..1, the body sets the target; she
## eases into it), and where it is in the world (INF: nothing).
var reach := 0.0
var reach_at := Vector3.INF

var _doing := Act.NONE
var _doing_time := INF
var _clock := 0.0
var _tick := 0.0
var _posed := false
var _was_at := Vector3.INF
var _drift := 0.0
var _upset := 0.0
var _sat := 0.0
var _gaze := Vector2.ZERO
var _going := Vector3.ZERO
## Each hand, a weight on a spring (rig space).
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Each foot's slow paddle, out of step with the other.
var _paddle: Array[float] = [0.0, 1.9]
var _reaching := 0.0
var _reach_point := Vector3.INF

## How dark the dirt and the hollows go (a share of the colour under it), and how soft its edge is.
const GRIME := Color(0.6, 0.58, 0.56)
const GRIME_SOFTNESS := 0.08

static var _paint_shader: Shader
static var _blood_shader: Shader
static var _blood: ShaderMaterial


## Shades her as CharacterRig does (Toon), but in her own colours: the model
## carries each part's colour as its vertex colour, and in its alpha how much
## grime is in it (0.5 at the edge; see build_psychic_child.py's `painted`).
## One material for all of her, so one draw; the nosebleed is its own object
## and material (`blood_material`), shown only while she bleeds.
func restyle() -> void:
	super()
	if not cel_shaded:
		return
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "child":
				part.set_surface_override_material(surface, paint_material())
			elif original and original.resource_name == "blood":
				part.set_surface_override_material(surface, blood_material())
		if String(part.name).ends_with("_blood"):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.visible = false


static func paint_material() -> ShaderMaterial:
	if _paint_shader == null:
		_paint_shader = Shader.new()
		_paint_shader.code = Toon.SHADER.replace("uniform vec3 albedo : source_color = vec3(1.0);",
				"uniform vec3 albedo : source_color = vec3(1.0);\nuniform vec3 grime : source_color = vec3(0.5);\nuniform float softness = 0.07;").replace(
				"ALBEDO = albedo * (1.0 - stripe * line);",
				"float dirty = smoothstep(0.5 - softness - fwidth(COLOR.a), 0.5 + softness + fwidth(COLOR.a), COLOR.a);\n\tALBEDO = COLOR.rgb * mix(vec3(1.0), grime, dirty) * (1.0 - stripe * line);")
	var material := ShaderMaterial.new()
	material.shader = _paint_shader
	material.set_shader_parameter(&"albedo", Color(0.6, 0.6, 0.6))
	material.set_shader_parameter(&"grime", GRIME)
	material.set_shader_parameter(&"softness", GRIME_SOFTNESS)
	# (a little light wraps on round her: her small round face is not cut in two by the dark)
	material.set_shader_parameter(&"wrap", 0.35)
	return material


## The nosebleed's: dark wet red, shown along each trickle only as far as
## `bleed` (0..1, its U) has run. Shared: there is one bleed at a time worth
## telling apart.
static func blood_material() -> ShaderMaterial:
	if _blood == null:
		_blood_shader = Shader.new()
		_blood_shader.code = Toon.SHADER.replace("uniform vec3 albedo : source_color = vec3(1.0);",
				"uniform vec3 albedo : source_color = vec3(1.0);\nuniform float bleed = 1.0;").replace(
				"ALBEDO = albedo * (1.0 - stripe * line);",
				"if (UV.x > bleed) {\n\t\tdiscard;\n\t}\n\tALBEDO = albedo * (1.0 - stripe * line);")
		_blood = ShaderMaterial.new()
		_blood.shader = _blood_shader
		_blood.set_shader_parameter(&"albedo", Color(0.3, 0.035, 0.03))
		_blood.set_shader_parameter(&"highlight", 0.5)
		_blood.set_shader_parameter(&"gloss", 40.0)
	return _blood


## Each child's own copy of the nosebleed's material (so that one can bleed while another does not).
func own_blood() -> ShaderMaterial:
	var mine := blood_material().duplicate() as ShaderMaterial
	for part: MeshInstance3D in _figure.find_children("*_blood", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			part.set_surface_override_material(surface, mine)
	return mine


## The nosebleed's object (null if the model has none).
func blood_part() -> MeshInstance3D:
	var found := _figure.find_children("*_blood", "MeshInstance3D", true, false)
	return found[0] if not found.is_empty() else null


func _build() -> void:
	# (no footfalls: she does not walk)
	dusty = false
	super()
	settle()


## Hangs her still as she is, nothing in motion: for when she is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_posed = false
	_was_at = Vector3.INF
	_upset = distress
	_sat = drained
	_tick = INF


## Begins the burst (anything she was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF


func act_time() -> float:
	return _doing_time


## Posed `pose_rate` times a second (every frame with none). CharacterRig's own
## posing (the boy's walk, and all he does) is never run.
func _process(delta: float) -> void:
	if _player == null:
		return
	_tick += delta
	var every := 1.0 / pose_rate if pose_rate > 0.0 else 0.0
	if _tick < every:
		return
	var step := minf(_tick, 0.25) if _tick < INF else 1.0 / 60.0
	_tick = 0.0
	_pose(step)
	_apply_pose()


func _pose(delta: float) -> void:
	_clock += delta
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= BURST:
			_doing = Act.NONE
			_doing_time = INF
	var going := _gone(delta)
	_going = _going.lerp(going, 1.0 - exp(-4.0 * delta)) if _posed else going
	var speed := Vector2(_going.x, _going.z).length()
	_upset = _approach(_upset, distress, 7.0, delta) if _posed else distress
	_sat = _approach(_sat, drained, 2.2 if drained > _sat else 1.4, delta) if _posed else drained
	var d := _upset
	if reach_at.is_finite():
		_reach_point = reach_at
	_reaching = _approach(_reaching, reach if _reach_point.is_finite() else 0.0, 9.0, delta) if _posed else reach
	var curl := smoothstep(0.1, 0.65, d) * (1.0 - _reaching * 0.7)
	var sit := smoothstep(0.0, 1.0, _sat)
	var fling := 0.0
	if _doing == Act.BURST:
		var t := _doing_time
		fling = smoothstep(0.0, 0.07, t) * (1.0 - smoothstep(0.45, BURST, t))
	var float_on := (1.0 - sit) * (1.0 - fling)
	# (it trembles: fine and quick, harder as she nears the burst)
	var shake := d * d * (1.0 - fling)
	var tremble := Vector3(sin(_clock * 37.0) + sin(_clock * 23.0 + 1.3), sin(_clock * 31.0 + 0.5), sin(_clock * 41.0 + 2.1) + sin(_clock * 19.0)) * 0.5 * shake
	var breathe := sin(_clock * TAU * (0.28 + 0.5 * d))

	# --- How high she hangs ---
	var bob := sin(_clock * 1.15) * 0.012 + sin(_clock * 0.47 + 1.0) * 0.008
	var hover := (HOVER + bob) * (1.0 - sit) + 0.11 * curl * (1.0 - sit) + 0.3 * fling
	var hips_y := lerpf(_hip_height + hover - 0.04 * curl, SITTING, sit)
	var drift_back := clampf(-_going.z * 0.05, -0.06, 0.06)
	_hips.position = Vector3(sin(_clock * 0.6) * 0.008 * float_on + tremble.x * 0.004, hips_y + tremble.y * 0.003, lerpf(0.0, -0.05, sit))
	var lean := clampf(speed * 0.08, 0.0, 0.12)
	_hips.rotation = Vector3(lean * 0.5 + 0.25 * curl * (1.0 - sit) - 0.22 * fling - 0.18 * sit, 0.0, 0.0)
	_spine.rotation = Vector3(0.03 + lean * 0.3 + 0.22 * curl - 0.28 * fling + 0.38 * sit + 0.012 * breathe, 0.0, tremble.z * 0.01)
	if _chest:
		_chest.rotation = Vector3(0.04 + 0.28 * curl - 0.32 * fling + 0.32 * sit - 0.02 * breathe * (1.0 - curl), 0.0, 0.0)

	# --- The head ---
	_watch_her(_hip_height + 0.38, Vector2(1.2, 0.6), 2.2, delta)
	var look := _gaze * (1.0 - curl) * (1.0 - sit) * (1.0 - fling)
	var sway := sin(_clock * 0.62) * 0.11 * (1.0 if humming else 0.25) * (1.0 - curl)
	var tilt := 0.16 * (1.0 - curl) * (1.0 - fling) + sway
	var bowed := 0.05 + 0.42 * curl - 0.65 * fling + 0.62 * sit
	_neck.rotation = Vector3(bowed * 0.45 + look.y * 0.4, look.x * 0.4 + tremble.x * 0.05, tilt * 0.4 + tremble.z * 0.03)
	_head.rotation = Vector3(bowed * 0.55 + look.y * 0.6, look.x * 0.6 + tremble.x * 0.09, tilt * 0.6 + tremble.z * 0.05)

	_legs(float_on, curl, fling, sit, drift_back, delta)
	_arms(float_on, curl, fling, sit, tremble, delta)
	_posed = true


## Her legs: dangling under her, toes pointed, paddling slowly; drawn up as she
## curls; straight out under her in the burst; sitting, her knees up in front
## of her and her feet flat on the ground.
func _legs(float_on: float, curl: float, fling: float, sit: float, drift_back: float, delta: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_paddle[i] += delta * (0.9 + 0.2 * i)
		var paddle := sin(_paddle[i]) * 0.022
		# Where each ankle is: dangling, the leg all but straight under the hip (the
		# pointed toes then just over the ground); drawn up; straight out; or, sitting,
		# the foot flat on the ground in front of her.
		var hip_y := _hips.position.y + _hip_drop
		var leg := _thigh + _shin
		var hang := Vector3(side * (_hip_width + 0.006), hip_y - leg * 0.975 + maxf(paddle, 0.0) * 0.3, -0.012 + paddle + drift_back)
		var drawn := Vector3(side * (_hip_width + 0.012), hip_y - leg * 0.62, 0.1)
		var straight := Vector3(side * (_hip_width + 0.03), hip_y - leg * 0.99, -0.02)
		var toes := lerpf(lerpf(0.75, 0.9, curl), 1.05, fling)
		toes = lerpf(toes, 0.0, sit)
		var seated := Vector3(side * 0.058, 0.0, 0.19) + _ankle_offset(0.0)
		var target := hang.lerp(drawn, curl * 0.85).lerp(straight, fling).lerp(seated, sit)
		var basis := Basis(Vector3.UP, side * -0.08) * Basis(Vector3.RIGHT, toes)
		# (her toes curl under, hanging)
		_toes[i].rotation.x = -0.35 * (1.0 - sit) * float_on
		_solve_leg(i, side, to_hips * target, (to_hips.basis * basis).orthonormalized(), side * (0.06 + 0.15 * sit))


func _arms(float_on: float, curl: float, fling: float, sit: float, tremble: Vector3, delta: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Hanging, a little behind her and out, as if she were drawn along; swaying slowly.
		var sway := sin(_clock * 0.8 + i * 1.7) * 0.012
		var hang := shoulder + Vector3(side * 0.035, -_upper_arm - _forearm + 0.03, -0.035 + sway + clampf(-_going.z * 0.03, -0.04, 0.04))
		# Clutching her head, the elbows in front of her face.
		var temple := to_local(_head.global_transform * Vector3(side * 0.07, 0.085, 0.012))
		var clutch := temple + Vector3(0.0, -0.02, -0.012) + tremble * 0.006
		# Flung out wide and up, fingers splayed.
		var flung := shoulder + Vector3(side * (_upper_arm + _forearm) * 0.92, 0.11, 0.06)
		# Sitting, round her knees.
		var knee := to_local(_shins[i].global_position)
		var hug := Vector3(-side * 0.012, knee.y - 0.035, knee.z + 0.055)
		var goal := hang.lerp(clutch, curl).lerp(flung, fling).lerp(hug, sit)
		var pole := Vector3(side * 0.4, -0.8, -0.4).lerp(Vector3(side * 0.6, -0.2, 0.75), curl).lerp(Vector3(side * 0.2, -1.0, -0.3), fling).lerp(Vector3(side * 0.8, -0.2, 0.5), sit)
		# Reaching out with her mind: her right arm held straight out at it, the
		# hand open and stiff, shaking; her left hand at her temple.
		var held := _reaching * (1.0 - fling) * (1.0 - sit)
		if held > 0.001 and _reach_point.is_finite():
			if i == 1:
				var toward := to_local(_reach_point) - shoulder
				toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
				var out := shoulder + toward * (_upper_arm + _forearm) * 0.96 + tremble * 0.004 + Vector3(sin(_clock * 29.0), sin(_clock * 23.0), 0.0) * 0.004 * held
				goal = goal.lerp(out, held)
				pole = pole.lerp(Vector3(side * 0.5, -1.0, 0.0), held)
			else:
				goal = goal.lerp(clutch, held * 0.85)
				pole = pole.lerp(Vector3(side * 0.6, -0.2, 0.75), held)
		var stiff := 26.0 + 120.0 * maxf(maxf(curl, fling), held)
		_hand_follow(i, goal, stiff, 7.0 + 14.0 * maxf(maxf(curl, fling), held), delta)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole).normalized())
		var curled := lerpf(lerpf(0.45, 0.85, curl), 0.0, fling)
		var splay := lerpf(lerpf(0.15, 0.7, curl), 1.0, fling)
		var wrist := lerpf(0.15 - 0.3 * curl, -0.2, fling)
		if i == 1:
			curled = lerpf(curled, 0.12, held)
			splay = lerpf(splay, 1.0, held)
			wrist = lerpf(wrist, -0.7, held)
		_set_hand(i, lerpf(curled, 0.75, sit), lerpf(splay, 0.2, sit), wrist)


## How fast she is really going in her own space, from where she was when last posed.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 3.0 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


## Turns an arm to put its wrist at `point` (world), the elbow towards `pole`,
## each bone turned about the hinge of the elbow. (As ClownRig and GhoulRig do.)
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


func _hand_follow(i: int, goal: Vector3, stiffness: float, damping: float, delta: float) -> void:
	# (in steps short enough to hold together however seldom she is posed)
	var steps := ceili(delta / 0.012)
	var dt := delta / steps
	for k in steps:
		_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * dt
		_hand_at[i] += _hand_speed[i] * dt
	if not _posed:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


## Turns `_gaze` towards `aim`, seen from `height` up her: (to the side, down), within `most`.
func _watch_her(height: float, most: Vector2, rate: float, delta: float) -> void:
	var look := Vector2.ZERO
	if aim.is_finite():
		var to := to_local(aim) - Vector3(0.0, height, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -most.x, most.x), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -most.y, most.y))
	_gaze = _gaze.lerp(look, 1.0 - exp(-rate * delta)) if _posed else look


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)
