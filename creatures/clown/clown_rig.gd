class_name ClownRig
extends CharacterRig
## How the clown (creatures/clown/models/clown.glb) moves: the whole figure is
## posed here, over CharacterRig (see `_pose_extra`); nothing of the boy's walk
## is kept. Its body (`Clown`, clown.gd) is this node's parent and says how fast
## he is going (`velocity`), what he looks at (`aim`), whether he is `frozen`
## or `winded`, and starts the one thing he does, `act(Act.GIGGLE)`.
##
## - HE CREEPS on long legs, too long strides with the knees lifted high and the
##   toes turned out, each big shoe set down heel first and its front slapping
##   flat after (`slapped`); bent forward at the hips, the shoulders up, the head
##   pushed out ahead and tilted, and slowly rolling from side to side. One hand
##   holds the balloon's string up in front of his chest; the other hangs long
##   and swings, its fingers spread.
## - HE SPRINTS (driven fast) in a lanky, flailing bound: pitched forward, the
##   knees pumping up to his chest, the free arm windmilling and the head
##   lolling, the balloon hand thrust up over his head. Posed only now and then
##   (`stop_motion` poses a second, the whole figure jumping from one to the
##   next) it goes like a puppet in stop-motion.
## - FROZEN he stops dead in whatever pose he was in, a foot in the air if it
##   was, and nothing moves but his head, which tilts slowly over to one side
##   (`TILT_TIME`) and is still. Nothing is posed while he is frozen.
## - THE GIGGLE (GIGGLE seconds): his shoulders hitch up and down with it, the
##   free hand comes up to cover his mouth, his head cocks over; and at the end
##   it comes up straight, looking at what he is after.
## - WINDED he is bent double, the free hand on his knee, his back heaving; the
##   balloon still holds the other hand up.
##
## Its joints are the mummy's and the boy's (the same bone names), so any figure
## built on them can be moved by it.

## A big shoe has slapped down flat: where (world), and how hard (about 0.4 creeping, 1 sprinting).
signal slapped(at: Vector3, weight: float)

enum Act { NONE, GIGGLE }

## Seconds the giggle takes, and the head's slow tilt once he is frozen.
const GIGGLE := 0.7
const TILT_TIME := 1.6
## One whole cycle of his creep (two steps), as modelled, and of his sprint; and
## the share of it each foot is off the ground.
const STRIDE := 1.25
const SPRINT_STRIDE := 1.9
const SWING := 0.46
const SPRINT_SWING := 0.6

## What he looks at, in the world; INF for nothing.
var aim := Vector3.INF
## Stopped dead (see above). The body sets this.
var frozen := false
## How winded he is, 0..1 (the body sets the target; he eases into it).
var winded := 0.0
## Poses a second while he sprints (0: every frame).
var stop_motion := 0.0
## Poses a second otherwise (0: every frame), for when he is far enough off for it not to show.
var pose_rate := 0.0

var _doing := Act.NONE
var _doing_time := INF
var _cycle := 0.0
var _stride := STRIDE
var _swing_share := SWING
var _trod := false
var _posed := false
var _was_at := Vector3.INF
var _yaw_was := 0.0
var _clock := 0.0
var _tick := 0.0
var _step := 1.0 / 60.0
var _sprinting := 0.0
var _puff_now := 0.0
## Each foot: where it is on the ground (in the rig's space, as modelled), where
## a step takes it from and to, whether it is stepping, and how it is held.
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_moving: Array[bool] = [false, false]
var _foot_swing: Array[float] = [-1.0, -1.0]
var _foot_began: Array[float] = [0.0, 0.0]
var _foot_lift: Array[float] = [0.0, 0.0]
var _foot_toes: Array[float] = [0.0, 0.0]
var _foot_turn: Array[float] = [0.0, 0.0]
## The front of each shoe, flapping on a spring (where, how fast), and whether it is yet to slap down.
var _flap: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _to_slap: Array[bool] = [false, false]
## Each hand, a weight on a spring (rig space).
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _gaze := Vector2.ZERO
var _wake := 1.0
## Frozen: how far the head has tilted over, which way, and how the head and neck were when he froze.
var _was_frozen := false
var _tilt := 0.0
var _tilt_way := 1.0
var _held_head := Vector3.ZERO
var _held_neck := Vector3.ZERO
## A jerk of the head now and then as he creeps (how much is left of it, which way, when the next).
var _twitch := 0.0
var _twitch_way := 1.0
var _twitch_in := 2.0

## How dark his grime goes (a share of the colour under it), and how soft its edge is.
const GRIME := Color(0.64, 0.6, 0.55)
const GRIME_SOFTNESS := 0.07

static var _paint_shader: Shader


## Shades him as CharacterRig does (Toon), but in his own colours: the model
## carries each part's colour as its vertex colour, and in its alpha how much
## grime is in it (0.5 at the edge; see build_clown.py's `painted`); the colour
## goes to GRIME times itself over that edge in one soft step. One material for
## all of him, so one draw.
func restyle() -> void:
	super()
	if not cel_shaded:
		return
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "clown":
				part.set_surface_override_material(surface, paint_material())


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
	return material


func _build() -> void:
	# (the boy's footfalls are not his own)
	dusty = false
	super()
	# (posed now and then, he is put where his body is only then: see _process)
	top_level = true
	settle()


## Stands him still as he is, nothing in motion: for when he is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_cycle = 0.0
	_posed = false
	_was_at = Vector3.INF
	_was_frozen = false
	_puff_now = winded
	var body := get_parent() as Node3D
	if body and body.is_inside_tree():
		global_transform = body.global_transform
	_yaw_was = _yaw()
	for i in 2:
		_foot_at[i] = _standing(i)
		_foot_moving[i] = false
		_foot_swing[i] = -1.0
		_flap[i] = Vector2.ZERO
		_to_slap[i] = false


## Begins a giggle (anything he was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF


func act_time() -> float:
	return _doing_time


func _yaw() -> float:
	var forward := global_basis.z
	return atan2(forward.x, forward.z)


## Where a foot stands when it is going nowhere: apart, toes out.
func _standing(i: int) -> Vector3:
	return Vector3((_hip_width + 0.012) * (1.0 if i == 0 else -1.0), 0.0, 0.015 if i == 0 else -0.02)


## A spring (where, how fast) drawn to `to`, in steps short enough to hold together
## however seldom he is posed.
static func _sprung(spring: Vector2, to: float, stiffness: float, damping: float, delta: float) -> Vector2:
	var steps := ceili(delta / 0.012)
	var dt := delta / steps
	for k in steps:
		spring.y += ((to - spring.x) * stiffness - spring.y * damping) * dt
		spring.x += spring.y * dt
	return spring


## Frozen, nothing is posed (but his head's slow tilt); sprinting, he is posed
## only `stop_motion` times a second, and put where his body is only then.
func _process(delta: float) -> void:
	if _player == null:
		return
	if frozen:
		if not _was_frozen:
			_was_frozen = true
			_tilt = 0.0
			_tilt_way = -1.0 if randf() < 0.5 else 1.0
			_held_head = _head.rotation
			_held_neck = _neck.rotation if _neck else Vector3.ZERO
		if _tilt < 1.0:
			_tilt = minf(_tilt + delta / TILT_TIME, 1.0)
			var t := smoothstep(0.0, 1.0, _tilt)
			# (the head rolls over onto one side, and a little down, as if to see you better)
			_head.rotation = _held_head + Vector3(0.1, 0.12 * _tilt_way, 0.42 * _tilt_way) * t
			if _neck:
				_neck.rotation = _held_neck + Vector3(0.04, 0.0, 0.2 * _tilt_way) * t
			_apply_pose()
		return
	if _was_frozen:
		_was_frozen = false
		_tick = 1.0
	_tick += delta
	var every := 1.0 / stop_motion if stop_motion > 0.0 and _sprinting > 0.5 else (1.0 / pose_rate if pose_rate > 0.0 else 0.0)
	if _tick < every:
		return
	_step = minf(_tick, 0.25)
	_tick = 0.0
	var body := get_parent() as Node3D
	global_transform = body.global_transform
	super(_step)


func _pose_extra(_delta: float) -> void:
	var delta := _step
	_clock += delta
	var yaw_now := _yaw()
	var turned := angle_difference(_yaw_was, yaw_now)
	_yaw_was = yaw_now
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= GIGGLE:
			_doing = Act.NONE
			_doing_time = INF
	var going := _gone(delta)
	var speed := going.length()
	var go := clampf(speed / 0.4, 0.0, 1.0) * (1.0 - _air)
	var sprint := smoothstep(2.4, 4.0, speed)
	_sprinting = sprint
	_puff_now = _approach(_puff_now, winded, 3.0, delta)
	var puffed := _puff_now * (1.0 - go)
	var giggle := 0.0
	if _doing == Act.GIGGLE:
		giggle = smoothstep(0.0, 0.12, _doing_time) * (1.0 - smoothstep(GIGGLE - 0.18, GIGGLE, _doing_time))
	# (the giggle hitches, three times)
	var hitch := absf(sin(_doing_time * TAU * 4.5)) * giggle if _doing == Act.GIGGLE else 0.0

	_stride = lerpf(lerpf(0.8, STRIDE, smoothstep(0.4, 1.8, speed)), SPRINT_STRIDE, sprint)
	_swing_share = lerpf(SWING, SPRINT_SWING, sprint)
	_tread(going, turned, go, delta)
	_shape_steps(go, sprint, delta)

	# --- The body ---
	var phase := _cycle * TAU
	var swing_side := sin(phase)
	var bob := absf(cos(phase))
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(1.8, 5.0)
		_twitch = 1.0
		_twitch_way = -1.0 if randf() < 0.5 else 1.0
	_twitch = maxf(_twitch - delta * 2.2, 0.0)
	var jerk := _twitch_way * pow(_twitch, 4.0) * 0.5 * (1.0 - sprint) * (1.0 - giggle)
	# Bent forward at the hips, the shoulders hunched; flat out, pitched right over.
	var lean := lerpf(0.16, 0.42, sprint) * clampf(go + 0.3, 0.0, 1.0) + 0.08 * giggle + 0.95 * puffed
	var hunch := 0.22 + 0.12 * giggle - 0.12 * sprint + 0.35 * puffed
	var breathe := sin(_clock * TAU * 1.7) * puffed
	var height := _hip_height - 0.03 * go + 0.035 * (bob - 0.5) * go * (1.0 + 2.0 * sprint) - 0.04 * giggle - 0.07 * puffed
	_hips.position = Vector3(swing_side * 0.025 * go * (1.0 - sprint), height, -0.03 * puffed)
	_hips.rotation = Vector3(lean * 0.5, swing_side * 0.18 * go, -swing_side * 0.06 * go * (1.0 - sprint))
	_spine.rotation = Vector3(lean * 0.3 + hunch * 0.2 + 0.03 * breathe, -swing_side * 0.12 * go, swing_side * 0.04 * go)
	_chest.rotation = Vector3(lean * 0.2 + hunch * 0.35 - 0.05 * breathe - 0.05 * hitch, -swing_side * 0.18 * go, 0.0)

	# The head: pushed out and cocked over, rolling slowly; lolling when he sprints.
	_watch_him(_hip_height + 0.6, Vector2(1.1, 0.7), 4.0, delta)
	var look := _gaze * (1.0 - sprint * 0.6) * (1.0 - puffed)
	var cock := 0.28 * sin(_clock * 0.7) + 0.18
	cock = lerpf(cock, -0.5 * _twitch_way, giggle * (1.0 - smoothstep(GIGGLE - 0.25, GIGGLE - 0.1, _doing_time)))
	var loll := Vector3(sin(_clock * 9.0) * 0.25, sin(_clock * 5.3) * 0.3, sin(_clock * 6.1 + 1.0) * 0.45) * sprint
	var bowed := -lean * 0.55 - hunch * 0.3 + 0.55 * puffed
	_neck.rotation = Vector3(bowed * 0.5 + look.y * 0.4 + loll.x * 0.4 + 0.2 * hitch, look.x * 0.4 + loll.y * 0.3, cock * 0.4 + jerk * 0.4 + loll.z * 0.4)
	_head.rotation = Vector3(bowed * 0.5 + look.y * 0.6 + loll.x * 0.6 - 0.1 * hitch, look.x * 0.6 + loll.y * 0.5, cock * 0.6 + jerk * 0.6 + loll.z * 0.6)

	_stand_legs(0.12 + 0.1 * sprint)
	_arms(go, sprint, giggle, hitch, puffed, breathe, delta)
	_posed = true


## Shapes the steps `_tread` takes into his creep: the knee lifted high, the
## toe pointed down as it leaves the ground and the shoe's front hanging; it
## comes down heel first with its front up, and the front slaps flat after.
func _shape_steps(go: float, sprint: float, delta: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_turn[i] = side * lerpf(-0.36, -0.14, sprint)
		var flap_to := 0.0
		if _foot_swing[i] >= 0.0:
			var s := _foot_swing[i]
			_foot_lift[i] = sin(PI * s) * lerpf(0.11, 0.24, sprint) * go
			# (pointed as it lifts off, heel first as it comes down)
			_foot_toes[i] = 0.55 * sin(PI * clampf(s * 2.0, 0.0, 1.0)) * (1.0 - smoothstep(0.35, 0.6, s)) - 0.5 * smoothstep(0.55, 0.92, s)
			flap_to = 0.45 * (1.0 - smoothstep(0.5, 0.8, s)) - 0.35 * smoothstep(0.7, 0.95, s)
			_to_slap[i] = true
		else:
			_foot_lift[i] = 0.0
			# (planted: the heel comes up as the foot goes back under him)
			var back := smoothstep(-0.12, -0.3, _foot_at[i].z) * go
			_foot_toes[i] = lerpf(_foot_toes[i], 0.35 * back, 1.0 - exp(-30.0 * delta))
			if _to_slap[i]:
				_to_slap[i] = false
				_flap[i].y += 9.0
				slapped.emit(to_global(_foot_at[i] + Vector3(0.0, 0.0, 0.15)), lerpf(0.4, 1.0, sprint) * go)
		_flap[i] = _sprung(_flap[i], flap_to, 260.0, 9.0, delta)
	for i in 2:
		_foot_at[i] = _foot_at[i].lerp(_standing(i), _air)
		_foot_lift[i] = lerpf(_foot_lift[i], 0.05, _air)


func _arms(go: float, sprint: float, giggle: float, hitch: float, puffed: float, breathe: float, delta: float) -> void:
	var mark := Vector3(0.0, 0.9, 1.5)
	if aim.is_finite():
		mark = to_local(aim)
	var near := clampf(1.0 - (Vector2(mark.x, mark.z).length() - 0.9) / 2.5, 0.0, 1.0)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		var goal: Vector3
		var pole: Vector3
		var curl := 0.0
		var splay := 0.0
		var wrist := 0.0
		var stiff := 30.0
		if i == 0:
			# The balloon hand: held up before his chest; flat out, thrust up over his head.
			var held := shoulder + Vector3(-0.02, -0.1 + 0.015 * sin(_clock * 1.3), 0.24)
			var high := shoulder + Vector3(0.06, 0.5, 0.06 + 0.04 * sin(_clock * 11.0))
			var pulled := shoulder + Vector3(0.1, 0.32, 0.12)
			goal = held.lerp(high, sprint).lerp(pulled, puffed)
			goal.y += 0.02 * hitch
			pole = Vector3(0.7, -0.6, -0.4).lerp(Vector3(0.9, 0.0, -0.4), sprint)
			curl = 0.95
			splay = 0.1
			wrist = 0.2
			stiff = 60.0
		else:
			# The other hangs long and swings, the fingers spread; reaching when he is near what he is after.
			var swing := sin(_cycle * TAU) * 0.12 * go
			var hanging := shoulder + Vector3(side * 0.03, -_upper_arm - _forearm + 0.03, 0.04 + swing)
			var reach := shoulder + Vector3(side * 0.04, -0.2, 0.5)
			goal = hanging.lerp(reach, near * 0.6 * (1.0 - sprint))
			# Flat out it windmills, big wild circles out to the side
			var round_arm := _cycle * TAU * 1.0 + 0.7
			var flail := shoulder + Vector3(side * (0.22 + 0.08 * sin(_clock * 13.0)), sin(round_arm) * 0.42, cos(round_arm) * 0.42)
			goal = goal.lerp(flail, sprint)
			# Giggling, the hand comes up to cover his mouth.
			var mouth := to_local(_head.global_transform * Vector3(0.0, 0.03, 0.12))
			# (the wrist under his chin, so that the glove lies over his mouth)
			goal = goal.lerp(mouth + Vector3(0.0, -0.055 - 0.02 * hitch, -0.02), giggle)
			# Winded, it is on his knee.
			var knee := Vector3(side * 0.09, _hip_height - _thigh * 0.95, 0.1)
			goal = goal.lerp(knee + Vector3(0.0, 0.02 * breathe, 0.0), puffed)
			pole = Vector3(side * 0.6, -0.5, -0.6).lerp(Vector3(side * 0.9, 0.3, -0.2), sprint).lerp(Vector3(side * 0.8, -0.8, 0.2), giggle).lerp(Vector3(side, 0.2, 0.3), puffed)
			curl = lerpf(0.15, 0.35, sprint) + 0.4 * giggle + 0.2 * puffed
			splay = lerpf(0.95, 0.8, sprint) * (1.0 - giggle * 0.6)
			wrist = 0.1 + 0.3 * sprint * sin(_clock * 15.0) - 0.4 * giggle
			stiff = 30.0 + 90.0 * maxf(sprint, giggle)
		_hand_follow(i, goal, stiff, 5.0 + 8.0 * sprint + 16.0 * giggle + 10.0 * puffed, delta)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole).normalized())
		_set_hand(i, curl, splay, wrist)


## Where the balloon's string comes out of his fist (world).
func fist() -> Vector3:
	return _hands[0].global_transform * Vector3(0.0, -0.045, 0.0)


# --- Shared with the ghoul's rig (creatures/ghoul/ghoul_rig.gd) ---

## Steps with each leg in turn: a whole cycle is `_stride` long and each foot is
## off the ground for `_swing_share` of it. A planted foot stays where it is on
## the ground; one that steps is brought down already going back with the ground.
func _tread(going: Vector3, turned: float, go: float, delta: float) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / _stride * delta, 1.0)
	var walking := (go > 0.15 or speed > 0.08) and speed > 0.02
	var ahead := going / maxf(speed, 0.0001)
	if walking and not _trod:
		_cycle = 0.0 if _foot_at[0].dot(ahead) <= _foot_at[1].dot(ahead) else 0.5
	_trod = walking
	var tether := _stride * (1.0 - _swing_share) * 0.5 + 0.2
	var width := _hip_width + 0.012
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_at[i] = (_foot_at[i] - going * delta).rotated(Vector3.UP, -turned)
		var home := Vector3(side * width, 0.0, 0.0)
		if _foot_at[i].distance_to(home) > tether:
			_foot_at[i] = home + (_foot_at[i] - home).normalized() * tether
		var p := fposmod(_cycle - 0.5 * i, 1.0)
		var stepping := walking and p < _swing_share and (_foot_moving[i] or p < _swing_share * 0.8)
		if stepping and not _foot_moving[i]:
			_foot_began[i] = p
			_foot_from[i] = _foot_at[i]
			_foot_to[i] = home + ahead * _stride * (1.0 - _swing_share) * 0.5
		_foot_moving[i] = stepping
		var s := (p - _foot_began[i]) / maxf(_swing_share - _foot_began[i], 0.0001)
		_foot_swing[i] = s if stepping else -1.0
		if stepping:
			_foot_at[i] = _foot_from[i].lerp(_foot_to[i] + ahead * (_swing_share - p) * _stride, s * s * (3.0 - 2.0 * s))
	if not walking:
		for i in 2:
			var home := _standing(i)
			var off := _foot_at[i].distance_to(home)
			_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.04 else 0.0) * delta)) if _posed else home
			_foot_swing[i] = -1.0
			_foot_moving[i] = false


## Puts each leg to its foot; the knees `spread` apart from the way the feet point.
func _stand_legs(spread: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes)
		# (the shoe's front: flat on the ground when the heel is up, else flapping on its spring)
		var flat := -maxf(toes, 0.0) if _foot_swing[i] < 0.0 else 0.0
		_toes[i].rotation.x = flat + _flap[i].x
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * spread)


## How fast it is really going in its own space, from where it was when last posed.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 3.0 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


## Turns an arm to put its wrist at `point` (world), the elbow towards `pole`,
## each bone turned about the hinge of the elbow.
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
	# (in steps short enough to hold together however seldom he is posed)
	var steps := ceili(delta / 0.012)
	var dt := delta / steps
	for k in steps:
		_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * dt
		_hand_at[i] += _hand_speed[i] * dt
	if not _posed:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


## Turns `_gaze` towards `aim`, seen from `height` up it: (to the side, down), within `most`.
func _watch_him(height: float, most: Vector2, rate: float, delta: float) -> void:
	var look := Vector2.ZERO
	if aim.is_finite():
		var to := to_local(aim) - Vector3(0.0, height, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -most.x, most.x), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -most.y, most.y))
	_gaze = _gaze.lerp(look, 1.0 - exp(-rate * delta))


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)
