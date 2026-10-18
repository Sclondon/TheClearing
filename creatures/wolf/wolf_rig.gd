class_name WolfRig
extends DogRig
## Poses a grey wolf (creatures/wolf/models/wolf_*.glb) in code, every frame:
## the dog's rig (DogRig: the walk, the trot on diagonal pairs, the rotary
## gallop, nose-down tracking, the stalk, the lunge, the shake, sitting and
## lying), on a wolf's model, with a wolf's carriage:
## - THE TROT registers: each hind foot comes down in the print its forefoot has
##   just left (the feet are drawn a little in under it to fit the stride), and,
##   the chest being narrow, all four on nearly one line.
## - THE TAIL hangs straight at rest, and says where it stands in the pack
##   (Wolf.rank): the breeding pair carry theirs higher, out level or over it
##   when they are watching something, the low ones lower, a little tucked.
##   Hunting it is out straight behind, galloping it streams level, in a
##   play-bow it is up and wagging.
## - THE EARS stand up and forward, the low ones' a little back and out.
## - HUNTING (Wolf.hunting): the head carried low, level with the back or under
##   it, ears forward: the tireless trot.
## - THE HOWL: the head up (not straight up, as the dog's), the mouth a round
##   "o" that opens and closes with the voice (Wolf.voice_open), the lips
##   pursed forward.
## - THE PLAY-BOW (Wolf.bowing): down on its forearms, chest low, rump up, head
##   up, tail high and wagging.

## How far the feet may be drawn in under it, to register at the trot (m in the model).
const REGISTER_MOST := 0.035
## The play-bow: how far the front of it goes down (m in the model), its pitch, and how far forward the forefeet go.
const BOW_DROP := 0.12
const BOW_PITCH := 0.36
const BOW_REACH := 0.09

var _wolf: Wolf
var _hunt := 0.0
var _bow := 0.0
var _rank_high := 0.0
var _paw_rest: Array[float] = []


func _ready() -> void:
	_wolf = get_parent() as Wolf
	super()
	for paw in _paws:
		_paw_rest.append(paw.z)
	_rank_high = [1.0, 0.0, -1.0][_wolf.rank if _wolf else 1]


func _model_path() -> String:
	return "res://creatures/wolf/models/wolf_%s%s.glb" % ["b" if variant == 1 else "a", "_lo" if low_poly else ""]


func _dress(model: Node) -> Dictionary:
	return WolfLook.dress(model, coat_tint, 0 if low_poly else fur_shells, eyeshine)


func _process(delta: float) -> void:
	if _dog == null or _wolf == null or _skeleton == null:
		super(delta)
		return
	var step := minf(delta, 1.0 / 30.0)
	_rank_high = _approach(_rank_high, [1.0, 0.0, -1.0][_wolf.rank], 2.0, step)
	_hunt = _approach(_hunt, 1.0 if _wolf.hunting and not _wolf.busy() else 0.0, 3.0, step)
	_bow = _approach(_bow, 1.0 if _wolf.bowing and not _wolf.busy() else 0.0, 6.0, step)
	_register()
	super(delta)
	for i in _paws.size():
		_paws[i].z = _paw_rest[i]
	if _head == null:
		return
	# The head low on the hunt: the neck down and out, the face kept level.
	_neck.rotation.x += 0.30 * _hunt * (1.0 - _howl)
	_neck_1.rotation.x += 0.10 * _hunt * (1.0 - _howl)
	_head.rotation.x -= 0.22 * _hunt * (1.0 - _howl)
	# The howl: the head up, but not straight up; the muzzle an "o".
	if _howl > 0.0:
		var voice := _wolf.voice_open()
		_head.rotation.x += 0.32 * _howl
		_neck.rotation.x += 0.08 * _howl
		_jaw.rotation.x = lerpf(_jaw.rotation.x, (0.05 + 0.2 * voice) * GAPE, _howl)
		for side in 2:
			var out := 1.0 if side == 0 else -1.0
			_lips[side].position = _lips[side].position.lerp(_lip_rest[side] + Vector3(-out * 0.003, -0.006, 0.008), _howl)
	if _bow > 0.01:
		_play_bow()
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)


## Draws the feet in under it as far as it takes, at the trot, for each hind
## foot to come down where its forefoot left (from how fast it was going).
func _register() -> void:
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var share := trot * (1.0 - gallop) * (1.0 - _stalk)
	if share <= 0.0:
		return
	var stride := _keyed(STRIDE, _pace)
	var fore := minf(lerpf(DUTY_FORE.x, DUTY_FORE.y, trot) * stride, REACH * _size)
	var hind := minf(lerpf(DUTY_HIND.x, DUTY_HIND.y, trot) * stride, REACH * _size)
	# (the hind foot comes down a little after the forefoot lifts: the body has gone on that far)
	var gap := _paw_rest[0] - _paw_rest[2]
	var draw := clampf((gap - fore * 0.5 - hind * 0.5 - 0.03 * stride) * 0.5, -0.02, REGISTER_MOST * _size) * share
	_paws[0].z = _paw_rest[0] - draw
	_paws[1].z = _paw_rest[1] - draw
	_paws[2].z = _paw_rest[2] + draw
	_paws[3].z = _paw_rest[3] + draw


## Down on its forearms, rump up: the legs put again under the bowed body.
func _play_bow() -> void:
	var bow := smoothstep(0.0, 1.0, _bow)
	_body.position.y -= BOW_DROP * 0.55 * _size * bow
	_body.rotation.x += BOW_PITCH * bow
	_chest.rotation.x += 0.08 * bow
	_pelvis.rotation.x -= 0.12 * bow
	# (the head up and looking out at whom it is playing with)
	_neck.rotation.x -= 0.55 * bow
	_head.rotation.x -= 0.15 * bow
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	for i in 4:
		var rest := _paws[i]
		targets.append(Vector3(rest.x, _paw_height, rest.z + (BOW_REACH * _size * bow if i < 2 else 0.0)))
		pitches.append(0.0)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	var flat: Array[float] = [bow, bow, 0.0, 0.0]
	_pose_legs(targets, pitches, poles, flat, 0.0, 0.0, 0.0)


## The tail: straight and hanging at rest; how high it is carried says its
## rank; out straight hunting or stalking, streaming level at a gallop, up and
## wagging in a play-bow, low as it howls; flung about in a shake.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, flung: float, shook: float) -> void:
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace) * (1.0 - gallop)
	_wag = _approach(_wag, maxf(0.85 * _bow, 0.15 * _track), 4.0, delta)
	_wag_phase += delta * TAU * lerpf(1.4, 3.2, _wag)
	var high := _rank_high
	var carried := -0.05 + 0.12 * high + 0.22 * trot + 0.25 * _track
	# (watching something, the breeding pair hold theirs up: rank shows)
	carried += _alert * (1.0 - _stalk) * (0.12 + 0.45 * maxf(high, 0.0) - 0.1 * maxf(-high, 0.0))
	carried += 0.55 * maxf(_hunt, _stalk) + 0.15 * high * _hunt + 0.95 * gallop + 0.3 * flung - 0.15 * _howl
	carried = lerpf(carried, 1.15, _bow)
	carried = lerpf(carried, 0.3, sit * (1.0 - _bow))
	carried = lerpf(carried, 0.05, lie)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_wag_phase - i * 0.8) * _wag * (0.3 if i == 0 else 0.2) + lie * _side * 0.3
		if shook > 0.0:
			swing += sin(TAU * SHAKE_RATE * _shaken - 2.0 - i * 0.5) * 0.5 * shook
		# (a low one's tucks a little under at its end)
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 * (1.0 - sit) if i == 0 else -gallop * 0.05 + 0.06 * minf(high, 0.0) * (1.0 - _hunt)
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		# (carried up, it is held straight: a raised tail does not sag at its end)
		var held := maxf(maxf(_stalk, _hunt), clampf(carried * 1.4, 0.0, 1.0))
		link.limit = lerpf(lerpf(0.5, 0.18, gallop), 0.12, held)
		link.gravity = lerpf(3.0, 0.6, held)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.0, 5.0)
		if _sit < 0.1 and _alert < 0.5 and randf() < 0.5:
			var which := randi() % 2
			_flick(which, Vector3(0.7 if which == 0 else -0.7, 0.3, 0.0))


## The ears: as the dog's; forward on the hunt; the low ones' a little back and out.
func _carry_ears(delta: float, gallop: float) -> void:
	super(delta, gallop)
	var low := maxf(-_rank_high, 0.0) * (1.0 - _hunt) * (1.0 - _stalk)
	for side in 2:
		var root: Link = _ears[side][0]
		var out := 1.0 if side == 0 else -1.0
		root.aim = (Basis(Vector3.RIGHT, 0.28 * _hunt - 0.35 * low) * Basis(BEHIND, out * 0.3 * low)) * root.aim
