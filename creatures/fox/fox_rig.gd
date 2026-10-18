class_name FoxRig
extends DogRig
## Poses a red fox (creatures/fox/models/fox_*.glb) in code, every frame: the
## dog's rig (DogRig: the walk, the trot on diagonal pairs, the rotary gallop,
## nose-down tracking, the stalk, sitting and lying, the lunge, the shake) on
## a fox's model, with a fox's carriage and its own moves:
## - THE BRUSH is heavy and carried low, hanging in a curve at rest; trotting
##   it is held straight out level behind, and galloping it streams out (a
##   little up, as a rudder, in the air of a pounce). Sitting, it is wrapped
##   round its forefeet; curled up lying, round its nose.
## - LISTENING (Fox.listening): stock still, the ears pricked hard forward and
##   the head cocked to one side, then after a moment to the other.
## - THE POUNCE (Fox.pounce): crouched with the haunches gathered under it and
##   the rump wiggling; flung up nose high, the forelegs tucked and the hind
##   legs thrust out behind; turning over at the top and coming down nose
##   first, the forelegs stretched down together; landing on its forepaws on
##   the spot, the nose down into the grass between them, the rump up; and up
##   again.
## - CARRYING (Fox.carrying): the jaws a little open, the head held higher.
## - The bark and the scream are the dog's bark and howl (a scream lifts the
##   head less than a howl).

## The fox (the parent), as a Fox.
var _fox: Fox
var _listen := 0.0
var _cock := 1.0
var _cock_in := 1.2
var _cocked := 0.0
var _carry := 0.0
var _fly := 0.0


func _ready() -> void:
	_fox = get_parent() as Fox
	super()


func _model_path() -> String:
	return "res://creatures/fox/models/fox_%s%s.glb" % ["b" if variant == 1 else "a", "_lo" if low_poly else ""]


func _dress(model: Node) -> Dictionary:
	return FoxLook.dress(model, coat_tint, 0 if low_poly else fur_shells, eyeshine)


func _process(delta: float) -> void:
	if _dog == null or _fox == null:
		super(delta)
		return
	var step := minf(delta, 1.0 / 30.0)
	var stage := _fox.pounce_stage()
	var listening := _fox.listening and stage == Fox.Pounce.NONE
	_listen = _approach(_listen, 1.0 if listening or stage == Fox.Pounce.CROUCH else 0.0, 6.0, step)
	_carry = _approach(_carry, 1.0 if _fox.carrying else 0.0, 6.0, step)
	_fly = _approach(_fly, 1.0 if stage == Fox.Pounce.LEAP else 0.0, 10.0, step)
	_cock_in -= step
	if _cock_in <= 0.0:
		_cock_in = randf_range(0.8, 1.8)
		_cock = -_cock if randf() < 0.7 else _cock
	_cocked = _approach(_cocked, _cock * (1.0 if listening else 0.0), 7.0, step)
	super(delta)
	if _head == null:
		return
	# Listening: the head cocked, a little low, still.
	_head.rotation.z += 0.38 * _cocked
	_head.rotation.x += 0.12 * _listen
	# Carrying: the head higher, the jaws a little open on it.
	_neck.rotation.x -= 0.12 * _carry
	_head.rotation.x -= 0.1 * _carry
	_jaw.rotation.x = maxf(_jaw.rotation.x, 0.22 * GAPE * _carry)
	if stage != Fox.Pounce.NONE:
		_pose_pounce(stage, _fox.pounce_progress())
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


## The pounce, over whatever the dog's rig made of it (see the top).
func _pose_pounce(stage: int, u: float) -> void:
	var size_now := maxf(global_basis.get_scale().x, 0.01)
	var targets: Array[Vector3] = []
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	var pitches: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var flat: Array[float] = [0.0, 0.0, 0.0, 0.0]
	match stage:
		Fox.Pounce.CROUCH:
			# Gathered: down on its haunches, the front a little up, the rump wiggling.
			var s := smoothstep(0.0, 0.45, u)
			var wiggle := sin(_time * 34.0) * smoothstep(0.35, 0.6, u) * (1.0 - smoothstep(0.85, 1.0, u))
			_body.position = _body_rest + Vector3(0.0, -0.075 * _size * s, -0.03 * _size * s)
			_body.rotation = Vector3(-0.1 * s, 0.0, 0.0)
			_pelvis.rotation = Vector3(0.32 * s, wiggle * 0.12, wiggle * 0.05)
			_chest.rotation = Vector3(0.04 * s, 0.0, 0.0)
			for i in 4:
				var rest := _paws[i]
				targets.append(Vector3(rest.x, _paw_height, rest.z + (0.07 * _size * s if i >= 2 else 0.0)))
			_pose_legs(targets, pitches, poles, flat, 0.0, 0.0, 0.0)
			position.y = 0.0
		Fox.Pounce.LEAP:
			# Up nose high, turning over at the top, down nose first.
			var over := smoothstep(0.12, 0.92, u)
			position.y = _fox.pounce_lift() / size_now
			_body.position = _body_rest
			_body.rotation = Vector3(lerpf(-0.5, 0.85, over), 0.0, 0.0)
			_chest.rotation = Vector3(lerpf(-0.05, 0.12, over), 0.0, 0.0)
			_pelvis.rotation = Vector3(lerpf(-0.2, 0.05, over), 0.0, 0.0)
			_neck.rotation = Vector3(lerpf(-0.05, 0.12, over), 0.0, 0.0)
			_neck_1.rotation = _neck.rotation
			_head.rotation = Vector3(lerpf(0.1, 0.42, over), 0.0, 0.0)
			# (forelegs tucked going up, stretched down together coming down; the
			# hind legs thrust out behind, then trailing)
			var down := smoothstep(0.3, 0.62, u)
			for i in 4:
				var fore := i < 2
				var up_pose := Vector3(0.0, 0.16, 0.03) if fore else Vector3(0.0, 0.05, -0.28)
				var down_pose := Vector3(-signf(_paws[i].x) * 0.02, 0.06, 0.3) if fore else Vector3(0.0, 0.06, -0.24)
				var spine := _chest if fore else _pelvis
				var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
				var paw := _paws[i] - _body_rest + up_pose.lerp(down_pose, down) * _size
				_solve_leg(i, hip, paw, Basis(Vector3.RIGHT, 0.7 if fore else 0.4), poles[i], AHEAD, 0.0, 1.0)
		Fox.Pounce.PIN, Fox.Pounce.RISE:
			# Down on the spot: forepaws together pinning it, the nose in the
			# grass between them, the rump up; then up again.
			var w := (1.0 - smoothstep(0.0, 1.0, u)) if stage == Fox.Pounce.RISE else smoothstep(0.0, 0.12, u) * 0.4 + 0.6
			position.y = 0.0
			_body.position = _body_rest + Vector3(0.0, -0.035 * _size * w, 0.03 * _size * w)
			_body.rotation += Vector3(0.36 * w, 0.0, 0.0)
			_pelvis.rotation += Vector3(-0.14 * w, 0.0, 0.0)
			_chest.rotation += Vector3(0.06 * w, 0.0, 0.0)
			_neck.rotation += Vector3(0.32 * w, 0.0, 0.0)
			_neck_1.rotation += Vector3(0.32 * w, 0.0, 0.0)
			_head.rotation += Vector3(0.45 * w, 0.0, 0.0)
			# (a snap at the end of it: it has it)
			if stage == Fox.Pounce.PIN and u > 0.6:
				_jaw.rotation.x = maxf(_jaw.rotation.x, GAPE * 0.45 * sin(PI * clampf((u - 0.6) / 0.3, 0.0, 1.0)))
			for i in 4:
				var rest := _paws[i]
				if i < 2:
					targets.append(Vector3(rest.x * lerpf(1.0, 0.35, w), _paw_height, rest.z + 0.1 * _size * w))
				else:
					targets.append(Vector3(rest.x, _paw_height, rest.z + 0.02 * _size * w))
			_pose_legs(targets, pitches, poles, flat, 0.0, 0.0, 0.0)


## The brush: heavy, hanging low in a curve at rest and walking, out level
## behind at a trot or on a trail, streaming out at a gallop, up a little as a
## rudder in a pounce; down stalking; wrapped round the forefeet sitting, and
## round the nose curled up lying; flung about in a shake.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, flung: float, shook: float) -> void:
	_wag = _approach(_wag, 0.15 * _track, 4.0, delta)
	_wag_phase += delta * TAU * lerpf(1.4, 2.6, _wag)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace) * (1.0 - gallop)
	var carried := -0.12 + 0.42 * trot + 0.3 * _track - 0.1 * _stalk + 0.62 * gallop + 0.12 * _alert * (1.0 - _stalk) + 0.25 * flung + 0.75 * _fly
	carried = lerpf(carried, -0.35, sit)
	carried = lerpf(carried, -0.2, lie)
	var wrap := maxf(sit, lie)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_wag_phase - i * 0.8) * _wag * (0.3 if i == 0 else 0.2)
		# (round to one side, each joint further, so that it curls round to the front)
		swing += _side * wrap * (0.55 if i == 0 else 0.62 + 0.25 * lie)
		if shook > 0.0:
			swing += sin(TAU * SHAKE_RATE * _shaken - 2.0 - i * 0.5) * 0.5 * shook
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 * (1.0 - sit) if i == 0 else 0.1 * trot - gallop * 0.04 - 0.08 * wrap + 0.06 * _fly
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = lerpf(lerpf(lerpf(0.55, 0.3, trot), 0.18, gallop), 0.25, wrap)
		link.gravity = lerpf(4.0, 1.5, wrap)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.0, 5.0)
		if _sit < 0.1 and _alert < 0.5 and randf() < 0.5:
			var which := randi() % 2
			_flick(which, Vector3(0.7 if which == 0 else -0.7, 0.3, 0.0))


## The ears: as the dog's, and pricked hard forward listening, or crouched to pounce.
func _carry_ears(delta: float, gallop: float) -> void:
	super(delta, gallop)
	if _listen <= 0.0:
		return
	for side in 2:
		var root: Link = _ears[side][0]
		root.aim = Basis(Vector3.RIGHT, 0.42 * _listen) * root.aim
		root.twist *= 1.0 - _listen
