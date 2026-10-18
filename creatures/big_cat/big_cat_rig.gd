class_name BigCatRig
extends DogRig
## Poses a big cat (creatures/big_cat/models/lynx.glb, panther.glb) in code,
## every frame: the dog's rig (DogRig: the four-beat walk, the trot, the
## gallop with the back gathering and stretching, sitting and lying, the
## lunge), on a cat's model, with a cat's carriage laid over it:
## - THE STALK (BigCat.stalking): the dog's stalk taken lower: down on bent
##   legs, the shoulders up, the neck stretched out level and the head low
##   with the eyes on what it watches; long slow steps. Stopped, it holds a
##   forepaw up (`freeze_step`).
## - THE CROUCH (crouching, and feeding, and the wiggle before a pounce): belly
##   to the ground, the paws gathered under it, chin low.
## - THE WIGGLE before a pounce: the hindquarters sway from side to side and
##   the hind feet tread, the tail's end flicking.
## - THE POUNCE (the dog's lunge): flung up in an arc, the forelegs reaching
##   out wide, the paws turned to grab, the jaws open, the tail out behind.
## - THE SWIPE: rocked back onto its haunches, a forepaw raised high by its
##   head, then slashed forward and across and down, and back to the ground.
## - THE HISS: ears flat out to the sides, the head drawn back and low, the jaw
##   dropped wide and the lips (the whisker pads) drawn up off the fangs.
## - FEEDING: crouched, forepaws on the kill, head down, tearing (a jerk of the
##   head up and back now and then), the jaw working.
## - CLIMBING (the BigCat is turned up the wall by its game): it bounds, and its
##   tail hangs from it whatever way the ground is.
## - THE TAIL: the panther's long and low with its end curled up, held out
##   straight and low stalking, flat behind it crouched, its end twitching
##   whenever it watches something, lashing (BigCat.lashing, hissing,
##   swiping); streaming out level at a gallop; curled round to its side
##   sitting. The lynx's bob droops, and flicks up showing its black end.
## - THE EARS: up and turned forward on what it watches, swivelled about one
##   at a time at ease, turned back when it is wary or runs, flattened out
##   sideways to hiss or strike.

## How wide its jaw drops (radians), at most.
const CAT_GAPE := 0.95
## How far the lips (the whisker pads) draw up and back to bare its fangs (m, in the model).
const LIP_LIFT := Vector3(0.002, 0.009, -0.006)

## The cat (the parent), as a BigCat.
var _cat: BigCat
var _panther := true
var _crouched := 0.0
var _feed := 0.0
var _hissed := 0.0
var _climb := 0.0
var _lash := 0.0
var _wary := 0.0
var _growl := 0.0
var _swipe_amount := 0.0
var _freeze := 0.0
var _tail_time := 0.0
var _tip := 0.0
var _tip_to := 0.0
var _tip_in := 1.0
var _tug := 0.0
var _tug_in := 1.0


func _ready() -> void:
	_cat = get_parent() as BigCat
	_panther = variant == BigCat.Kind.PANTHER
	super()
	# (the tip of its jaw: a cat's mouth is short)
	_jaw_tip = _jaw.position + Vector3(0.0, -0.02, 0.10 if _panther else 0.08)
	_make_glows()
	# A cat's ears are stiff, standing; its tail heavier.
	for side in 2:
		var root: Link = _ears[side][0]
		var flap: Link = _ears[side][1]
		root.stiffness = 1500.0
		root.damping = 30.0
		flap.stiffness = 1100.0
		flap.damping = 24.0
		flap.gravity = 0.0
		flap.limit = 0.25
	for i in _tail.size():
		var link := _tail[i]
		link.stiffness = lerpf(1400.0, 420.0, i / 3.0) if _panther else 1600.0
		link.damping = lerpf(40.0, 16.0, i / 3.0) if _panther else 36.0
		link.gravity = 4.0 if _panther else 1.0


func _model_path() -> String:
	return "res://creatures/big_cat/models/%s%s.glb" % ["panther" if variant == BigCat.Kind.PANTHER else "lynx", "_lo" if low_poly else ""]


func _dress(model: Node) -> Dictionary:
	return BigCatLook.dress(model, variant as BigCat.Kind, coat_tint, 0 if low_poly else fur_shells, eyeshine)


## The light its eyes give back, as two small glows over them that are seen
## from in front of it and stay a few pixels across however far off (so that
## at night the eyes in the dark are a warning): `amount` 0 hides them.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 shine : source_color = vec3(0.6, 0.95, 0.4);
uniform float amount = 0.0;
varying float facing;

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	vec3 to_eye = CAMERA_POSITION_WORLD - at;
	float far = length(to_eye);
	vec3 ahead = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	facing = smoothstep(0.1, 0.7, dot(ahead, to_eye / far));
	float size = max(0.035, far * 0.006);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	// (a little towards the eye, so that the face does not hide it)
	vec3 world = at + to_eye / far * 0.03 + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = shine * amount * facing * glow * 2.5;
}
"""

static var _glow_shader: Shader
var _glows: Array[MeshInstance3D] = []
var _glow_material: ShaderMaterial


## Sets how bright the glows over its eyes are (0 hides them).
func set_glow(amount: float) -> void:
	if _glow_material == null:
		return
	_glow_material.set_shader_parameter(&"amount", amount)
	for glow in _glows:
		glow.visible = amount > 0.01


func _make_glows() -> void:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = _glow_shader
	_glow_material.set_shader_parameter(&"shine", BigCatLook.COATS[variant]["shine"])
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	# (where its eyes are on its head: skull and eye, from tools/build_big_cat.py)
	var eye := Vector3(0.031, 0.034, 0.112) if _panther else Vector3(0.025, 0.032, 0.096)
	for side: float in [1.0, -1.0]:
		var glow := MeshInstance3D.new()
		glow.mesh = quad
		glow.material_override = _glow_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(eye.x * side, eye.y, eye.z)
		glow.visible = false
		_head.add_child(glow)
		_glows.append(glow)


## Where a forepaw is, in the world (0 its left, 1 its right).
func fore_paw(side: int) -> Vector3:
	if _legs.size() < 2:
		return global_position
	return (_legs[side][3] as Node3D).global_position


func _process(delta: float) -> void:
	if _dog == null or _cat == null or _skeleton == null:
		super(delta)
		return
	var step := minf(delta, 1.0 / 30.0)
	var springing := _cat.lunge_stage() != Dog.Lunge.NONE
	_crouched = _approach(_crouched, 1.0 if (_cat.crouching or _cat.feeding or _cat.wiggling()) and not springing else 0.0, 5.0, step)
	_feed = _approach(_feed, 1.0 if _cat.feeding else 0.0, 4.0, step)
	_hissed = _approach(_hissed, 1.0 if _cat.hissing() else 0.0, 12.0 if _cat.hissing() else 3.0, step)
	_climb = _approach(_climb, 1.0 if _cat.climbing else 0.0, 10.0, step)
	_lash = _approach(_lash, 1.0 if (_cat.lashing or _cat.hissing() or _cat.swiping() or _cat.wiggling()) else 0.0, 3.0, step)
	_wary = _approach(_wary, 1.0 if _cat.wary else 0.0, 4.0, step)
	_growl = _approach(_growl, 1.0 if _cat.growling() else 0.0, 6.0, step)
	_swipe_amount = _approach(_swipe_amount, 1.0 if _cat.swiping() else 0.0, 14.0, step)
	_freeze = _approach(_freeze, 1.0 if _cat.freeze_step and _cat.stalking and _pace < 0.3 else 0.0, 6.0, step)
	_tail_time += step
	# (the dog's stalk does for the cat's legs: slow, deliberate, braced)
	var was := _dog.stalking
	_dog.stalking = _cat.stalking or _cat.crouching or _cat.feeding
	if _cat.climbing:
		# (its heading on a wall is not a turn)
		_last_yaw = global_rotation.y
		_turn = 0.0
	super(delta)
	_dog.stalking = was


## The body, before the head and legs are posed on it: the cat's crouch and
## stalk lower, the wiggle, the swipe rocking it back; then the head.
func _pose_head(delta: float, upstream: float, level: float, sit: float, lie: float, flying: float, gather: float, flung: float, shook: float) -> void:
	var stand := (1.0 - sit) * (1.0 - lie)
	var crouch := _crouched * stand
	var low := maxf(crouch, _hissed * 0.45 * stand)
	_body.position.y -= (0.21 * low + 0.08 * _stalk * (1.0 - low)) * _size
	_body.position.z -= 0.03 * low * _size
	_chest.rotation.x += -0.07 * _stalk * (1.0 - crouch) + 0.06 * crouch
	_pelvis.rotation.x += 0.10 * crouch
	# The wiggle: the hindquarters sway, the weight shifting from foot to foot.
	var wiggle := _cat.wiggle_progress() if _cat.wiggling() else 0.0
	if wiggle > 0.0:
		var w := sin(wiggle * TAU * 3.5) * sin(PI * minf(wiggle * 1.6, 1.0))
		_pelvis.rotation.y += w * 0.16
		_pelvis.rotation.z += w * 0.10
		_body.position.x += w * 0.012 * _size
		_body.position.y -= 0.02 * _size * smoothstep(0.0, 0.3, wiggle)
	# The swipe: back onto its haunches as the paw goes up, forward into the blow.
	if _cat.swiping():
		var u := _cat.swipe_progress()
		var back := smoothstep(0.0, BigCat.STRIKE.x, u) * (1.0 - smoothstep(BigCat.STRIKE.x, BigCat.STRIKE.y, u))
		var into := smoothstep(BigCat.STRIKE.x, BigCat.STRIKE.y, u) * (1.0 - smoothstep(0.7, 1.0, u))
		var side := 1.0 if _cat.swipe_side() == 0 else -1.0
		_body.rotation.x += -0.22 * back + 0.12 * into
		_body.position.z += (-0.07 * back + 0.06 * into) * _size
		_body.position.y += 0.03 * back * _size
		_body.rotation.z += -side * 0.10 * (back + into)
		_chest.rotation.y += side * 0.12 * into
	super(delta, upstream, level, sit, lie, flying, gather, flung, shook)
	# Stalking and crouched: the neck out level, the head low and level, eyes on it.
	var keyed := maxf(_stalk, crouch) * (1.0 - _feed)
	_neck.rotation.x += 0.36 * keyed * 0.5
	_neck_1.rotation.x += 0.36 * keyed * 0.5
	_head.rotation.x -= 0.10 * keyed
	# Feeding: the head down to the kill, tearing at it.
	if _feed > 0.0:
		_tug_in -= delta
		if _tug_in <= 0.0:
			_tug_in = randf_range(0.7, 1.8)
			_tug = 1.0
		_tug = maxf(_tug - delta * 2.6, 0.0)
		var jerk := sin(PI * _tug) * _feed
		_neck.rotation.x += (0.45 - 0.35 * jerk) * _feed
		_neck_1.rotation.x += (0.35 - 0.25 * jerk) * _feed
		_head.rotation.x += (0.35 - 0.3 * jerk) * _feed
		_head.rotation.z += sin(_tail_time * 1.3) * 0.15 * _feed
	# Hissing: the head drawn back and down, looking up from under its brow.
	_neck.rotation.x -= 0.18 * _hissed
	_head.rotation.x += 0.30 * _hissed
	# Climbing: looking on up the wall.
	_neck.rotation.x -= 0.15 * _climb
	_head.rotation.x -= 0.10 * _climb


## The jaw: the hiss, the growl, the pounce (open as it springs, snapping
## shut on what it lands on), feeding, panting; the lips drawn up off the fangs.
func _pose_jaw(stage: int, through: float, flung: float) -> void:
	var open := 0.0
	if _cat.hissing():
		var u := _cat.hiss_progress()
		open = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.8, 1.0, u)) * (0.95 + 0.05 * sin(_tail_time * 40.0))
	open = maxf(open, _growl * (0.16 + 0.04 * sin(_tail_time * 30.0)))
	if stage == Dog.Lunge.GATHER:
		open = maxf(open, 0.3 * through)
	elif stage == Dog.Lunge.SPRING:
		open = maxf(open, lerpf(0.35, 0.95, smoothstep(0.0, 0.5, through)))
	elif stage == Dog.Lunge.BITE:
		open = _keyed(SNAP, through * Dog.BITE_TIME)
	if _cat.swiping():
		open = maxf(open, 0.55 * sin(PI * _cat.swipe_progress()))
	if _feed > 0.0:
		open = maxf(open, _feed * (0.2 + 0.18 * sin(_tail_time * 7.0)))
	var panting := smoothstep(0.25, 0.6, _puffed) * (1.0 - _doze) * (1.0 - _hissed)
	open = maxf(open, panting * (0.22 + 0.06 * sin(_breath)))
	_mouth = lerpf(_mouth, open, 0.6)
	_jaw.rotation.x = _mouth * CAT_GAPE
	var lift := maxf(maxf(_hissed, _growl * 0.6), maxf(flung, _swipe_amount * 0.8))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		_lips[side].position = _lip_rest[side] + Vector3(LIP_LIFT.x * out, LIP_LIFT.y, LIP_LIFT.z) * lift
		_lips[side].rotation = Vector3(-0.15 * lift, 0.0, -out * 0.1 * lift)


## The legs: the gait's (DogRig's), with the cat's paws gathered under it
## crouched, the hind feet treading in the wiggle, a forepaw held up in a
## frozen stalk or on the kill; then the forelegs reaching out in a pounce, or
## one of them swiping.
func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], flat: Array[float], vertical_speed: float, flung: float, spring: float) -> void:
	var crouch := _crouched * (1.0 - smoothstep(0.0, 1.0, _sit))
	for i in 4:
		var fore := i < 2
		# (crouched, the paws come in under it: the forepaws a little ahead, the hind ones forward under the haunches)
		targets[i] = targets[i] + Vector3(0.0, 0.0, (0.04 if fore else 0.07) * _size * crouch)
		if fore and _feed > 0.0:
			targets[i] = targets[i] + Vector3(0.0, 0.0, 0.08 * _size * _feed)
	if _cat.wiggling():
		var w := _cat.wiggle_progress()
		for i in [2, 3]:
			targets[i] = targets[i] + Vector3.UP * maxf(sin(w * TAU * 3.5 + (0.0 if i == 2 else PI)), 0.0) * 0.022 * _size
	if _freeze > 0.0:
		# (stopped mid-stalk, a forepaw held up off the ground, curled)
		targets[0] += Vector3(0.0, 0.07, 0.03) * _size * _freeze
		pitches[0] += 0.9 * _freeze
	super(targets, pitches, poles, flat, vertical_speed, flung, spring)
	# The pounce: forelegs reaching out ahead and wide for it, paws turned to grab.
	if flung > 0.0:
		var reach := smoothstep(0.1, 0.6, spring)
		for i in 2:
			var out := 1.0 if i == 0 else -1.0
			var at := _paws[i] + Vector3(out * 0.07, 0.24, 0.40) * _size * reach + Vector3(0.0, 0.12, 0.2) * _size * (1.0 - reach)
			_reach_fore(i, at, lerpf(0.4, -0.5, reach))
	elif _cat.swiping():
		var u := _cat.swipe_progress()
		var i := _cat.swipe_side()
		var out := 1.0 if i == 0 else -1.0
		var rest := targets[i]
		var raised := _paws[i] + Vector3(out * 0.05, 0.38, 0.08) * _size
		var struck := _paws[i] + Vector3(-out * 0.07, 0.12, 0.40) * _size
		var at := rest
		var pitch := 0.0
		if u < BigCat.STRIKE.x:
			var t := smoothstep(0.0, 1.0, u / BigCat.STRIKE.x)
			at = rest.lerp(raised, t)
			pitch = 1.0 * t
		elif u < BigCat.STRIKE.y:
			var t := smoothstep(0.0, 1.0, (u - BigCat.STRIKE.x) / (BigCat.STRIKE.y - BigCat.STRIKE.x))
			at = raised.lerp(struck, t) + Vector3(0.0, 0.08, 0.0) * _size * sin(PI * t)
			pitch = lerpf(1.0, -0.6, t)
		else:
			var t := smoothstep(0.0, 1.0, (u - BigCat.STRIKE.y) / (1.0 - BigCat.STRIKE.y))
			at = struck.lerp(rest, t) + Vector3(0.0, 0.06, 0.0) * _size * sin(PI * t)
			pitch = lerpf(-0.6, 0.0, t)
		_reach_fore(i, at, pitch)


## Puts forepaw `i` at `at` (in the rig's space), its paw turned by `pitch`.
func _reach_fore(i: int, at: Vector3, pitch: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var hip := _chest.transform * (_hips[i] - _body_rest - _chest.position)
	var paw := to_body * at
	_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, pitch), to_body.basis * BEHIND, to_body.basis * AHEAD, 0.0, 1.0)


## The tail: a cat's, as the class says.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, flung: float, shook: float) -> void:
	# (the end of it twitches whenever it watches something, and more the more keyed up it is)
	var keyed := maxf(maxf(_stalk, _crouched), maxf(_alert * 0.6, _lash))
	_tip_in -= delta
	if _tip_in <= 0.0:
		_tip_in = randf_range(0.25, 0.7) if keyed > 0.4 else randf_range(1.0, 3.0)
		_tip_to = randf_range(-1.0, 1.0) * (0.4 + 0.6 * keyed)
	_tip = _approach(_tip, _tip_to, 12.0, delta)
	var lash_rate := 2.6 + 1.5 * _hissed
	var stride := sin(TAU * _phase) * gallop
	var count := _tail.size()
	for i in count:
		var link := _tail[i]
		var share := float(i) / maxf(count - 1, 1)
		var carried := 0.0
		var swing := 0.0
		if _panther:
			# Relaxed it hangs low, the end curled up; stalking it is held out low and
			# straight; crouched it lies out flat behind; galloping it streams out level.
			var base := 0.06 + 0.12 * _alert + 0.32 * _stalk + 0.42 * _crouched + 0.38 * gallop + 0.15 * flung - 0.25 * _climb
			var straight := maxf(maxf(_stalk, _crouched), gallop)
			carried = base if i == 0 else lerpf(0.0, -0.18, share) * straight + 0.1 * _hissed
			swing = sin(_tail_time * lash_rate - i * 0.75) * _lash * lerpf(0.35, 0.55, share)
			swing += _tip * 0.5 * keyed * smoothstep(0.4, 1.0, share)
			swing += stride * 0.12 * (1.0 - share * 0.5)
			# (sitting, it curls round to one side on the ground)
			swing += sit * _side * lerpf(0.5, 0.35, share)
			carried = lerpf(carried, -0.15 if i == 0 else 0.05, sit)
		else:
			# The bob: drooped, up a little when alert, flicked up to show its black end.
			var flick := maxf(_tip, 0.0) * keyed
			carried = (-0.35 + 0.2 * _alert + 0.35 * gallop + 0.3 * flung + 0.6 * flick - 0.2 * _wary) if i == 0 else 0.15 * flick
			swing = sin(_tail_time * lash_rate - i * 0.6) * _lash * 0.25
		if i == 0:
			carried -= _pelvis.rotation.x * 0.8 + _body.rotation.x * 0.5 * (1.0 - sit)
		if shook > 0.0:
			swing += sin(TAU * SHAKE_RATE * _shaken - 2.0 - i * 0.5) * 0.4 * shook
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, carried) * link.rest
		link.limit = lerpf(0.9, 0.22, maxf(gallop, _stalk)) if _panther else 0.4
	# (now and then an ear flicks, at ease)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.0, 5.0)
		if _sit < 0.1 and _alert < 0.5 and randf() < 0.5:
			var which := randi() % 2
			_flick(which, Vector3(0.5 if which == 0 else -0.5, 0.2, 0.0))


## The ears: a cat's (see the class).
func _carry_ears(delta: float, gallop: float) -> void:
	var flat := maxf(_hissed, maxf(_swipe_amount, 0.6 * _growl))
	var back := maxf(maxf(_wary * 0.8, gallop * 0.5), flat)
	var forward := maxf(maxf(_stalk, _crouched), _alert) * (1.0 - flat) * (1.0 - _wary)
	_ear_flat = _approach(_ear_flat, flat, 12.0 if flat > _ear_flat else 4.0, delta)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.6, 2.4)
		var pick := randi() % 4
		_ear_turn_to = Vector2(randf_range(0.5, 1.2) if pick == 0 else 0.0, randf_range(0.5, 1.2) if pick == 1 else 0.0)
	var listening := (1.0 - forward) * (1.0 - _ear_flat)
	_ear_turn = _ear_turn.lerp(_ear_turn_to * listening, 1.0 - exp(-10.0 * delta))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		# (flattened out to the sides, the openings turned down and back; turned back; up and forward)
		var lean := Basis(Vector3.RIGHT, -0.55 * _ear_flat - 0.25 * back + 0.15 * forward) * Basis(BEHIND, out * (1.05 * _ear_flat + 0.15 * back + 0.25 * turn - 0.08 * forward))
		root.aim = lean * root.rest
		root.twist = out * (1.2 * back + 0.9 * turn - 0.2 * forward)
		tip.aim = tip.rest


## The tail and the ears on their springs (as DogRig's), and on a wall nothing
## stops the tail hanging below where its feet are.
func _swing(delta: float) -> void:
	var ground := global_position.y - position.y + 0.02 if _climb < 0.5 else -INF
	for link in _links:
		var parent := (link.joint.get_parent() as Node3D).global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * link.joint.position
		var held_tip := root + frame * link.aim * link.length * parent.basis.get_scale().x
		if not _links_settled:
			link.tip = held_tip
			link.held_tip = held_tip
			link.velocity = Vector3.ZERO
		var held_velocity := (held_tip - link.held_tip) / delta
		link.held_tip = held_tip
		var before := link.tip
		var pull := (held_tip - link.tip) * link.stiffness - (link.velocity - held_velocity) * link.damping
		link.velocity += (pull - link.velocity * link.drag + Vector3.DOWN * link.gravity) * delta
		link.tip += link.velocity * delta
		link.tip.y = maxf(link.tip.y, ground)
		var along := (link.tip - root).normalized()
		var held := (held_tip - root).normalized()
		var off := held.angle_to(along)
		if off > link.limit:
			along = held.slerp(along, link.limit / off)
		link.tip = root + along * (held_tip - root).length()
		link.velocity = (link.tip - before) / delta
		link.joint.basis = Basis(Quaternion(link.rest, (frame.inverse() * along).normalized())) * Basis(link.rest, link.twist)
		_skeleton.set_bone_pose(link.bone, link.joint.transform)
	_links_settled = true
