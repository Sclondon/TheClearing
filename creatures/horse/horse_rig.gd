class_name HorseRig
extends Node3D
## Poses a horse (creatures/horse/models) in code, every frame, from what its
## Horse (the parent) says it is doing. After DeerRig (creatures/deer): hooves
## follow a gait cycle and are put down with IK (three bones and the hoof, each
## leg folding the way a horse's does: the elbow back, the knee forward, the
## stifle forward, the hock back), and the spine, neck, head and jaw are laid
## on top; the tail, the ears and the long hair of the tail are on springs.
##
## THE GAITS, chosen by its speed, each with a horse's own footfalls (the time
## in the stride each hoof comes down, fore left, fore right, hind left, hind right):
## - WALK, four beats, the lateral sequence: hind left, fore left, hind right,
##   fore right, evenly. Three hooves down most of the time. The head NODS, down
##   as each forefoot lands and up again, twice a stride; the barrel swings.
## - TROT, two beats: the diagonal pairs together (fore left with hind right,
##   fore right with hind left), a moment of flight between them. The head is
##   still; the body bounces twice a stride.
## - CANTER, three beats and a flight (on the left lead, and mirrored on the
##   right): the outside hind, then the inside hind and outside fore together,
##   then the leading fore; then all four off the ground. The horse rocks: the
##   forehand comes down onto the leading leg and up again, the head and neck
##   with it, once a stride.
## - GALLOP, four beats (the transverse gallop): hind, hind, fore, fore, the
##   leading leg last, and a long gathered flight with the legs folded under it;
##   the neck stretched out and pumping, the tail streaming.
##
## WHAT IT DOES, on top of the gait (each eases in and out): GRAZING (the neck
## right down, the muzzle on the ground, the lips and jaw working), ALERT (the
## head up high, both ears forward, still), FLEEING (ears pinned back, the head
## out), SPOOKED (head and tail up, the white of the eye showing, snorting),
## DOZING (resting a hind leg, the hip dropped on that side, the head low, the
## ears out to the sides, the lower lip slack), FRIENDLY (the head low and soft,
## the ears gently forward). And the moves: STAMP, SNORT, WHINNY (the head up,
## the mouth a little open, the flanks shaking with it), NICKER, SHAKE (a
## shudder that runs from its head along its body to its tail, the mane flying),
## ROLL (down onto its knees, onto its side, over onto its back with its legs
## folded and pawing the air, back, and up again, front first), TWITCH (the skin
## shivering at a point), and the tail's swish at the flies.
##
## A rider: `seat()` is where they sit (on the back behind the withers, riding
## its motion), and `grip()` where their hands hold the mane.
##
## Every joint is read from the model's skeleton (tools/build_horse.py).

signal footfall(leg: int)

## Fore left, fore right, hind left, hind right.
const SUFFIXES: Array[String] = ["_fl", "_fr", "_rl", "_rr"]
## The model faces +Z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const BEHIND := Vector3(0.0, 0.0, -1.0)
## The model's hip height (a model this high is a size of 1).
const HIP := 1.24
## When in the stride each hoof lands (fore left, fore right, hind left, hind
## right), in each gait (the canter and the gallop on the left lead).
const WALK: Array[float] = [0.25, 0.75, 1.0, 0.5]
const TROT: Array[float] = [0.5, 1.0, 1.0, 0.5]
const CANTER: Array[float] = [0.2, 1.0, 1.0, 0.8]
const GALLOP: Array[float] = [0.17, 1.06, 0.9, 0.78]
## The share of the stride a hoof is down, fore and hind, at a walk, a trot, a canter and a gallop.
const DUTY_FORE := Vector4(0.62, 0.44, 0.40, 0.30)
const DUTY_HIND := Vector4(0.62, 0.44, 0.42, 0.30)
## Speeds (m/s, for a size of 1) over which it goes from one gait to the next.
const TROT_AT := Vector2(1.9, 2.5)
const CANTER_AT := Vector2(4.3, 5.0)
const GALLOP_AT := Vector2(7.6, 8.6)
## Length of a stride (m) against speed (m/s), for a size of 1.
const STRIDE := [0.0, 0.7, 1.0, 1.2, 1.6, 1.55, 2.5, 2.05, 3.5, 2.45, 4.6, 2.75, 6.0, 3.1, 8.0, 3.9, 10.0, 4.8, 13.0, 6.0]
## How far a planted hoof may sweep under it (m), and how much further galloping.
const REACH := 0.85
const GALLOP_REACH := 1.8
## In the canter and gallop: how far past where it lands a hoof reaches out
## first (fore, hind), and how far back it is flung as it leaves the ground.
const REACH_OUT := Vector2(0.20, 0.10)
const FLING_BACK := Vector2(0.10, 0.22)
const GLIDE := 0.22
const FOLD := Vector2(3.0, 2.6)
const FOLD_PLANTED := Vector2(-0.2, 0.7)
## Seconds a stamp, a snort, a shake, a roll and a nicker take.
const STAMP_TIME := 0.55
const SNORT_TIME := 0.5
const SHAKE_TIME := 1.5
const ROLL_TIME := 9.0
const NICKER_TIME := 0.8
## How far the jaw drops, wide open, radians.
const GAPE := 0.5

## The model (set before it enters the tree; the Horse sets it).
var model_path := "res://creatures/horse/models/horse.glb"
var coat := 1
var low_poly := false
var fur_shells := 1
var coat_tint := Color.WHITE
var eyeshine := 0.25
## The materials, by name (see HorseLook.dress).
var materials := {}


class Link:
	var joint: Node3D
	var bone := -1
	var rest := Vector3.DOWN
	var aim := Vector3.DOWN
	var twist := 0.0
	var length := 0.1
	var stiffness := 120.0
	var damping := 8.0
	var drag := 1.0
	var gravity := 6.0
	var limit := 1.2
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var held_tip := Vector3.ZERO


var _horse: Horse
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
var _body: Node3D
var _chest: Node3D
var _pelvis: Node3D
var _neck: Node3D
var _neck_1: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array[Array] = []
var _tail: Array[Link] = []
var _ears: Array[Array] = [[], []]
var _links: Array[Link] = []
var _links_settled := false

var _body_rest := Vector3.ZERO
var _hips: Array[Vector3] = []
var _paws: Array[Vector3] = []
var _lengths: Array[Vector3] = []
var _spans: Array[float] = []
var _bends: Array[float] = []
var _frames: Array[Array] = []
var _size := 1.0
var _paw_height := 0.2
## Markers, in their bones' spaces: the nose, the brow, the seat (the body's) and the grip (the neck's).
var _nose := Vector3.ZERO
var _brow := Vector3.ZERO
var _seat := Vector3.ZERO
var _grip := Vector3.ZERO

var _time := 0.0
var _phase := 0.0
var _pace := 0.0
var _air := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _drop := 0.0
var _was_grounded := true
var _last_yaw := 0.0
var _turn := 0.0
var _mirrored := false
var _mouth := 0.0
var _breath := 0.0
var _puffed := 0.0
var _look := Vector2.ZERO
var _tilt := 0.0
var _ear_turn := Vector2.ZERO
var _ear_turn_to := Vector2.ZERO
var _ear_timer := 1.0
var _twitch_timer := 3.0
var _swish_timer := 2.0
var _swish := 0.0
var _swish_way := 1.0
var _planted: Array[bool] = [true, true, true, true]
var _twitching := 0.0
## How far into each mood it is, 0..1.
var _graze := 0.0
var _alert := 0.0
var _flee := 0.0
var _spook := 0.0
var _doze := 0.0
var _friend := 0.0
var _whinny := 0.0
var _stamped := 9.0
var _snorted := 9.0
var _shaken := 9.0
var _rolled := 9.0
var _nickered := 9.0
var _cocked := 2
## Kept from the last pose: the body's place in the rig, for the seat.
var _body_xf := Transform3D.IDENTITY


func _ready() -> void:
	_horse = get_parent() as Horse
	_build()
	_time = randf() * 10.0
	_mirrored = randf() < 0.5
	_cocked = 2 if randf() < 0.5 else 3
	_last_yaw = global_rotation.y


## Stands it as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_links_settled = false
	_crouch = 0.0
	_crouch_velocity = 0.0
	_air = 0.0
	_last_yaw = global_rotation.y
	_turn = 0.0


func stamp() -> void:
	_stamped = 0.0


func snort() -> void:
	_snorted = 0.0
	for side in 2:
		_flick(side, Vector3(0.0, 0.6, -0.6))


func shake() -> void:
	_shaken = 0.0
	for side in 2:
		_flick(side, Vector3(0.8 if side == 0 else -0.8, 0.5, 0.0))


func roll() -> void:
	_rolled = 0.0


func nicker() -> void:
	_nickered = 0.0


## Its skin shivers round `point` (in the world), as at a fly or a hand.
func twitch(point: Vector3) -> void:
	if _mesh == null or not materials.has("coat"):
		return
	_twitching = 1.0
	HorseLook.tune(materials["coat"], {&"twitch_at": _mesh.global_transform.affine_inverse() * point})


func busy() -> bool:
	return _stamped < STAMP_TIME or _snorted < SNORT_TIME or shaking() or rolling()


func shaking() -> bool:
	return _shaken < SHAKE_TIME


func rolling() -> bool:
	return _rolled < ROLL_TIME


## How far through a roll it is, 0..1 (0 when it is not rolling).
func roll_progress() -> float:
	return _rolled / ROLL_TIME if rolling() else 0.0


## Where the tip of its nose is, in the world.
func nose() -> Vector3:
	return _head.global_transform * _nose if _head else global_position


func nose_way() -> Vector3:
	if _head == null:
		return global_basis.z
	return (_head.global_transform * _nose - _head.global_transform * (_nose * 0.6)).normalized()


## Its brow, in the world.
func brow() -> Vector3:
	return _head.global_transform * _brow if _head else global_position


## Where a rider sits, in the rig's own space (its parent's, the Horse's):
## on the back behind the withers, riding the motion of the body. Its basis is
## the body's (so a rider leans as the horse pitches and rolls).
func seat_local() -> Transform3D:
	return transform * _body_xf * Transform3D(Basis.IDENTITY, _seat)


## Where a rider's hands hold the mane, in the world: the top of the neck at its
## root, a hand either side (left, right).
func grip() -> PackedVector3Array:
	if _neck == null:
		return PackedVector3Array([global_position, global_position])
	var at := _neck.global_transform * _grip
	var across := _neck.global_basis.x.normalized() * 0.07 * _size * global_basis.get_scale().x
	return PackedVector3Array([at + across, at - across])


## The middle of its barrel, in the world (for what reaches out to touch it).
func barrel() -> Vector3:
	return _body.global_position if _body else global_position


func _process(delta: float) -> void:
	if _horse == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var velocity := _horse.velocity / maxf(global_basis.get_scale().x, 0.01) / _size
	var speed := Vector2(velocity.x, velocity.z).length()
	var grounded := _horse.grounded
	var yaw := global_rotation.y
	_turn = _approach(_turn, angle_difference(_last_yaw, yaw) / delta, 8.0, delta)
	_last_yaw = yaw

	# --- Moods ---
	var lying := 0.0
	if rolling():
		var r := _rolled / ROLL_TIME
		lying = smoothstep(0.04, 0.16, r) * (1.0 - smoothstep(0.86, 0.97, r))
	_graze = _approach(_graze, 1.0 if _horse.grazing and not _horse.alert and lying < 0.01 else 0.0, 2.2, delta)
	_alert = _approach(_alert, 1.0 if _horse.alert else 0.0, 6.0 if _horse.alert else 2.0, delta)
	_flee = _approach(_flee, 1.0 if _horse.fleeing else 0.0, 6.0, delta)
	_spook = _approach(_spook, 1.0 if _horse.spooked else 0.0, 9.0 if _horse.spooked else 1.5, delta)
	_doze = _approach(_doze, 1.0 if _horse.dozing and speed < 0.2 and not _horse.alert else 0.0, 0.8, delta)
	_friend = _approach(_friend, 1.0 if _horse.friendly else 0.0, 2.0, delta)
	_whinny = _approach(_whinny, 1.0 if _horse.whinnying() else 0.0, 7.0 if _horse.whinnying() else 3.0, delta)
	_stamped += delta
	_snorted += delta
	_shaken += delta
	_rolled += delta
	_nickered += delta
	if _twitching > 0.0:
		_twitching = maxf(_twitching - delta * 2.4, 0.0)
		HorseLook.tune(materials["coat"], {&"twitch": _twitching})
	if materials.has("parts"):
		(materials["parts"] as ShaderMaterial).set_shader_parameter(&"eyeshine", eyeshine * (1.0 + 1.5 * _alert + 2.0 * _spook))
	_puffed = clampf(_puffed + (speed / 9.0 * 0.22 - 0.05) * delta, 0.0, 1.0)
	_horse.heavy = _puffed
	if grounded and not _was_grounded:
		_crouch_velocity += 1.5
	_was_grounded = grounded
	_crouch_velocity += (-_crouch * 240.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.16)
	_air = _approach(_air, 0.0 if grounded else 1.0, 14.0, delta)

	# --- The gait ---
	_pace = _approach(_pace, maxf(speed, absf(_turn) * 0.35), 8.0, delta)
	var trot := smoothstep(TROT_AT.x, TROT_AT.y, _pace)
	var canter := smoothstep(CANTER_AT.x, CANTER_AT.y, _pace)
	var gallop := smoothstep(GALLOP_AT.x, GALLOP_AT.y, _pace)
	var walk := 1.0 - trot
	var stride := _keyed(STRIDE, _pace)
	if grounded:
		_phase = fposmod(_phase + _pace / stride * delta, 1.0)
	var still := 1.0 - lying
	var gait := smoothstep(0.05, 0.4, _pace) * (1.0 - _air) * still
	var travel := clampf(speed / maxf(_pace, 0.05), 0.0, 1.0)
	var lift := lerpf(lerpf(lerpf(0.09, 0.14, trot), 0.18, canter), 0.24, gallop) * _size
	var flying := canter * gait
	var targets: Array[Vector3] = []
	var pitches: Array[float] = []
	var load_fore := 0.0
	var load_hind := 0.0
	var drop := 0.0
	for i in 4:
		var fore := i < 2
		var duties := DUTY_FORE if fore else DUTY_HIND
		var duty := lerpf(lerpf(lerpf(duties.x, duties.y, trot), duties.z, canter), duties.w, gallop)
		var span := minf(duty * stride * _size, REACH * lerpf(1.0, GALLOP_REACH, canter) * _size) * travel
		var middle := lerpf(-0.02, 0.05 if fore else -0.02, canter) * travel * _size
		# (the canter and gallop are on the lead it is on: mirrored, the right)
		var lead := i ^ 1 if _mirrored else i
		var offset := lerpf(lerpf(lerpf(WALK[i], TROT[i], trot), CANTER[lead], canter), GALLOP[lead], gallop)
		var at := fposmod(_phase - offset, 1.0)
		var cycle := _foot_cycle(at, duty, span * 0.5, lift * (1.0 if fore else 0.85), canter)
		if at >= duty and flying > 0.0:
			# A hoof is flung out behind as it leaves the ground, and reaches out
			# ahead before it lands (drawn back under it as it does).
			var swing := (at - duty) / (1.0 - duty)
			var out: float = REACH_OUT.x if fore else REACH_OUT.y
			var back: float = FLING_BACK.x if fore else FLING_BACK.y
			cycle.z += (out * sin(PI * smoothstep(0.45, 1.0, swing)) - back * sin(PI * clampf(swing / 0.35, 0.0, 1.0))) * _size * travel * flying
		var rest := _paws[i]
		targets.append(Vector3(rest.x * lerpf(1.0, 0.85, trot * gait), _paw_height + cycle.y * gait, rest.z + (middle + cycle.z) * gait))
		pitches.append(cycle.x * gait)
		var down := at < duty
		if down:
			var bearing := sin(PI * at / duty)
			if fore:
				load_fore += bearing
			else:
				load_hind += bearing
		if down and not _planted[i] and gait > 0.3 and grounded:
			footfall.emit(i)
		_planted[i] = down
		var from_hip := rest.z - _hips[i].z + middle * gait
		var furthest := (absf(from_hip) + span * 0.5 * gait * (1.0 - 0.4 * flying)) * (1.0 - GLIDE)
		var total := _lengths[i].x + _lengths[i].y + _lengths[i].z - 0.015 * _size
		drop = maxf(drop, _hips[i].y - _paw_height - sqrt(maxf(total * total - furthest * furthest, 0.01)))

	_drop = _approach(_drop, drop + 0.005 * _size, 9.0, delta)
	var sprung := 0.025 * trot * (1.0 - canter) * _size
	var vault := 0.012 * walk * _size
	var high_fore := ((load_fore - 0.7) * vault - (load_fore - 0.5) * sprung) * gait
	var high_hind := ((load_hind - 0.7) * vault - (load_hind - 0.5) * sprung) * gait
	# The canter and gallop rock it: the forehand down onto the leading leg, up through the flight.
	var rock_phase := TAU * (_phase - 0.35)
	var rocking := lerpf(0.075, 0.05, gallop) * flying
	var rise := (cos(TAU * (_phase - lerpf(0.72, 0.65, gallop))) * lerpf(0.045, 0.06, gallop) * flying) * _size
	var rock := (high_hind - high_fore) / (1.2 * _size) + cos(rock_phase) * rocking
	var back_bend := cos(TAU * (_phase - 0.65)) * 0.5 * flying
	var bend := clampf(_turn * 0.05, -0.2, 0.2)
	var swing_fore := (targets[1].z - targets[0].z) * 0.12 * (1.0 - canter) / _size
	var swing_hind := (targets[3].z - targets[2].z) * 0.16 * (1.0 - canter) / _size
	var bank := clampf(-_turn * speed * 0.01, -0.18, 0.18)
	var air_pitch := _air * clampf(-velocity.y * 0.04, -0.4, 0.4)
	var body_at := _body_rest + Vector3(0.0, -_drop - _crouch * _size + (high_fore + high_hind) * 0.5 + rise, 0.0)
	var body_turn := Vector3(air_pitch + rock, 0.0, bank)
	var chest_turn := Vector3(back_bend * 0.06, bend + swing_fore, (targets[0].y - targets[1].y) * 0.4 / _size)
	var pelvis_turn := Vector3(-back_bend * 0.12, -bend * 0.7 + swing_hind, (targets[2].y - targets[3].y) * 0.5 / _size)
	var poles: Array[Vector3] = [BEHIND, BEHIND, AHEAD, AHEAD]
	position.y = 0.0

	# Grazing: the front of it a little lower, the forelegs a little apart.
	body_turn.x += 0.06 * _graze
	body_at.y -= 0.03 * _size * _graze
	# Alert, spooked: stiff, the front up.
	body_turn.x -= 0.03 * _alert + 0.06 * _spook * (1.0 - flying)
	# Whinnying, the flanks tremble with it.
	body_turn.z += sin(_time * 38.0) * 0.006 * _whinny
	# Dozing: a hind leg rested, tipped on the toe of its hoof, the hip dropped on that side.
	if _doze > 0.01:
		var k := _cocked
		var side := 1.0 if k == 2 else -1.0
		targets[k] += Vector3(0.0, 0.05 * _size, 0.07 * _size) * _doze
		pitches[k] += 1.1 * _doze
		pelvis_turn.z -= side * 0.05 * _doze
		body_at.y -= 0.015 * _size * _doze

	# The stamp: a forefoot lifted and brought down hard.
	if _stamped < STAMP_TIME:
		var u := _stamped / STAMP_TIME
		var raised := sin(PI * clampf(u / 0.55, 0.0, 1.0))
		if u > 0.55:
			raised = 0.0
			if u < 0.6:
				_crouch_velocity -= 0.6
		var leg := 0 if not _mirrored else 1
		targets[leg] += Vector3(0.0, 0.18 * _size * raised, 0.06 * _size * raised)
		pitches[leg] += 1.1 * raised
		body_turn.x -= 0.03 * raised

	# The shake: a shudder from the head along the body to the tail, the legs braced apart.
	var shake := 0.0
	if _shaken < SHAKE_TIME:
		var u := _shaken / SHAKE_TIME
		shake = sin(PI * u)
		var wave := TAU * 5.5 * _shaken
		chest_turn.z += sin(wave) * 0.12 * shake * smoothstep(0.0, 0.25, u)
		body_turn.z += sin(wave - 0.8) * 0.07 * shake * smoothstep(0.1, 0.4, u)
		pelvis_turn.z += sin(wave - 1.8) * 0.12 * shake * smoothstep(0.25, 0.55, u)
		for i in 4:
			targets[i].x *= 1.0 + 0.12 * shake
		body_at.y -= 0.03 * _size * shake

	# The roll: down, onto its side, over onto its back and back again, and up.
	if lying > 0.0 or rolling():
		_roll_pose(lying, body_at, body_turn, targets, pitches, poles)
		body_at = _roll_at
		body_turn = _roll_turn

	_body.position = body_at
	_body.rotation = body_turn
	_chest.rotation = chest_turn
	_pelvis.rotation = pelvis_turn
	_body_xf = _body.transform
	_breathe(delta)
	_look_about(delta)
	_pose_head(delta, body_turn.x + chest_turn.x, flying, gallop, walk * gait, trot, lying, shake)
	_pose_jaw()
	_pose_legs(targets, pitches, poles, velocity.y)
	_carry_tail(delta, canter * gait, gallop * gait, shake, lying)
	_carry_ears(delta, gallop * gait)
	if materials.has("mane"):
		(materials["mane"] as ShaderMaterial).set_shader_parameter(&"sway", clampf(speed * 0.004, 0.0, 0.04) + 0.05 * shake + 0.012 * lying)
	for i in _joints.size():
		_skeleton.set_bone_pose(_bones[i], _joints[i].transform)
	_swing(delta)


var _roll_at := Vector3.ZERO
var _roll_turn := Vector3.ZERO


## Lays the body down and over for the roll (see `roll`), and its legs folded
## under it or pawing the air, in the body's own frame.
func _roll_pose(lying: float, body_at: Vector3, body_turn: Vector3, targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3]) -> void:
	var r := _rolled / ROLL_TIME if rolling() else 1.0
	# How far over it is (0 on its chest, PI/2 on its side, PI on its back), and how far down.
	var over := 0.0
	over += smoothstep(0.17, 0.27, r) * 1.45
	# (over onto its back and down again, twice, then back onto its chest)
	var rocking := smoothstep(0.27, 0.32, r) * (1.0 - smoothstep(0.6, 0.66, r))
	over += rocking * (0.5 - 0.5 * cos(TAU * 2.0 * smoothstep(0.3, 0.6, r))) * 1.25
	over -= smoothstep(0.64, 0.74, r) * 1.45
	# (getting up: the front first, then the quarters)
	var front_up := smoothstep(0.84, 0.92, r)
	var hind_up := smoothstep(0.89, 0.97, r)
	var kneel := smoothstep(0.05, 0.12, r)
	var down := smoothstep(0.08, 0.17, r)
	var on_side := sin(clampf(over, 0.0, PI))
	var on_back := smoothstep(1.6, 2.7, over)
	var height := lerpf(lerpf(0.50, 0.37, on_side), 0.42, on_back) * _size
	var low := _body_rest.y - height
	var at := body_at
	at.y = lerpf(body_at.y, body_at.y - low, down * (1.0 - hind_up))
	# (the front lowers first, onto its knees, and rises first)
	var pitch := body_turn.x + 0.32 * (kneel - down) - 0.3 * (front_up - hind_up)
	at.y += 0.25 * _size * (front_up - hind_up)
	# (rolling onto its right side, its back towards the ground once it is over)
	at.x = -sin(clampf(over, 0.0, PI)) * 0.08 * _size
	_roll_at = at
	_roll_turn = Vector3(pitch, 0.0, -over)
	var body := Transform3D(Basis.from_euler(_roll_turn), at)
	var paw := sin(TAU * 1.7 * _rolled) * on_back
	for i in 4:
		var fore := i < 2
		var side := 1.0 if i % 2 == 0 else -1.0
		var hip := _hips[i] - _body_rest
		var folded: Vector3
		if fore:
			# Folded at the knee under the chest, and on getting up, stretched out in front
			folded = Vector3(hip.x * 0.8, hip.y - (_lengths[i].x + _lengths[i].y) * 0.75, hip.z + 0.10 * _size)
			folded = folded.lerp(Vector3(hip.x, hip.y - (_lengths[i].x + _lengths[i].y + _lengths[i].z) * 0.7, hip.z + 0.45 * _size), smoothstep(0.74, 0.84, r) * (1.0 - front_up))
		else:
			folded = Vector3(hip.x * 0.9, hip.y - _lengths[i].x * 1.1, hip.z + 0.30 * _size)
		# (on its back the legs are drawn up, pawing at the air)
		folded += Vector3(side * 0.05, 0.10 * paw * (1.0 if (i == 0 or i == 3) else -1.0), 0.06 * paw) * _size
		var world_target := body * folded
		var weight := lying * (1.0 - (front_up if fore else hind_up))
		targets[i] = targets[i].lerp(world_target, weight)
		pitches[i] = lerpf(pitches[i], 1.4 if fore else 0.9, weight)
		poles[i] = poles[i].slerp(body.basis * poles[i], weight)


## Its ribs: slow and deep, quick when it has run; heaving after a gallop.
func _breathe(delta: float) -> void:
	var panting := smoothstep(0.25, 0.6, _puffed)
	_breath += delta * TAU * lerpf(lerpf(0.25, 0.12, _alert), 1.4, panting)
	var swell := sin(_breath) * lerpf(lerpf(0.010, 0.004, _alert), 0.02, panting)
	_chest.scale = Vector3(1.0 + swell, 1.0 + swell, 1.0)
	_neck.scale = Vector3.ONE / _chest.scale


## Head and neck: turned to what it watches, kept level whatever the body under
## them is doing; down to the ground grazing; up high alert or spooked; low and
## soft dozing or friendly; nodding at the walk, rocking at the canter,
## stretched out galloping; thrown up to whinny; shaken in a shake.
func _pose_head(delta: float, upstream: float, flying: float, gallop: float, walking: float, trot: float, lying: float, shake: float) -> void:
	_tilt = _approach(_tilt, 0.0, 5.0, delta)
	var yaw := _look.x * (1.0 - _graze * 0.6)
	var pitch := _look.y * (1.0 - _graze) * 0.6
	var neck := Vector3(-upstream * 0.6 + pitch * 0.5, yaw * 0.5, 0.0)
	var head := Vector3(-upstream * 0.4 + pitch * 0.5, yaw * 0.45, _tilt)
	# Grazing: the neck right down, the head turned up at the end of it so the muzzle is on the ground.
	neck.x += 1.72 * _graze
	head.x -= 0.62 * _graze
	head.x += sin(_time * 1.3) * 0.05 * _graze
	neck.y += sin(_time * 0.4) * 0.12 * _graze
	# Alert: the neck up, the head high; spooked, higher still and back.
	neck.x -= 0.32 * _alert + 0.45 * _spook
	head.x += 0.14 * _alert + 0.18 * _spook
	# Dozing: the neck level, the head hanging; friendly, a little low.
	neck.x += 0.32 * _doze + 0.15 * _friend
	head.x += 0.2 * _doze + 0.05 * _friend
	# The walk's nod: down as each forefoot lands, twice a stride.
	neck.x += cos(2.0 * TAU * (_phase - 0.28)) * 0.07 * walking
	head.x -= cos(2.0 * TAU * (_phase - 0.28)) * 0.03 * walking
	# The canter's rock and the gallop's pump: the neck down as the forehand comes down.
	neck.x += cos(TAU * (_phase - 0.32)) * lerpf(0.12, 0.09, gallop) * flying
	# Galloping, fleeing: stretched out ahead.
	var stretch := (0.32 * gallop + 0.12 * _flee) * (1.0 - _spook * 0.5)
	neck.x += stretch * 0.5
	head.x -= stretch * 0.9
	# A snort: the head jerks up and back, then down.
	if _snorted < SNORT_TIME:
		var u := _snorted / SNORT_TIME
		var jerk := sin(PI * minf(u / 0.3, 1.0)) * (1.0 if u < 0.3 else 0.0) * 0.2 - sin(PI * clampf((u - 0.3) / 0.7, 0.0, 1.0)) * 0.1
		neck.x -= jerk
		head.x += jerk * 0.5
	# The whinny: the head up and out, the neck arched.
	neck.x -= 0.38 * _whinny
	head.x -= 0.3 * _whinny
	head.z += sin(_time * 31.0) * 0.012 * _whinny
	# The shake: the head and neck shaken from side to side first.
	if shake > 0.0:
		var wave := sin(TAU * 6.5 * _shaken) * smoothstep(0.0, 0.15, _shaken / SHAKE_TIME) * (1.0 - smoothstep(0.45, 0.7, _shaken / SHAKE_TIME))
		neck.y += wave * 0.15
		neck.z += wave * 0.25
		head.z += wave * 0.4
	# Lying for its roll: the head down on the ground beside it, or out in front.
	if lying > 0.0:
		neck.x = lerpf(neck.x, 0.9, lying)
		head.x = lerpf(head.x, -0.2, lying)
		neck.y = lerpf(neck.y, 0.25, lying)
	_chest.rotation.y += yaw * 0.06
	_neck.rotation = neck * 0.5
	_neck_1.rotation = neck * 0.5
	_head.rotation = head


## The jaw: cropping grass grazing, open to whinny, slack dozing, working a little at the bit of grass, blowing after a run.
func _pose_jaw() -> void:
	var open := 0.0
	open = maxf(open, _graze * 0.10 * (0.5 + 0.5 * sin(_time * 7.5)))
	if _horse.whinnying():
		var u := _horse.whinny_progress()
		open = maxf(open, smoothstep(0.02, 0.12, u) * (1.0 - smoothstep(0.8, 0.95, u)) * (0.35 + 0.1 * sin(_time * 24.0)))
	if _nickered < NICKER_TIME:
		open = maxf(open, sin(PI * _nickered / NICKER_TIME) * 0.08 * (0.6 + 0.4 * sin(_time * 40.0)))
	open = maxf(open, _doze * 0.06)
	var panting := smoothstep(0.4, 0.8, _puffed)
	open = maxf(open, panting * (0.06 + 0.03 * sin(_breath)))
	_mouth = lerpf(_mouth, open, 0.5)
	_jaw.rotation.x = _mouth * GAPE


func _pose_legs(targets: Array[Vector3], pitches: Array[float], poles: Array[Vector3], vertical_speed: float) -> void:
	var to_body := _body.transform.affine_inverse()
	var rising := clampf(vertical_speed / 5.0, -1.0, 1.0) * 0.5 + 0.5
	for i in 4:
		var fore := i < 2
		var rest := _paws[i]
		var stretched := rest + Vector3(0.0, 0.18, 0.40 if fore else -0.40) * _size
		var landing := rest + Vector3(0.0, 0.14 if fore else 0.22, 0.30 if fore else -0.05) * _size
		var target := targets[i].lerp(landing.lerp(stretched, rising), _air)
		var spine := _chest if fore else _pelvis
		var hip := spine.transform * (_hips[i] - _body_rest - spine.position)
		var paw := to_body * target
		var under := hip.z + rest.z - _hips[i].z
		hip.z += clampf((paw.z - under) * GLIDE, -0.08 * _size, 0.08 * _size)
		var lifted := maxf(_air, clampf((target.y - _paw_height) / (0.06 * _size), 0.0, 1.0))
		_solve_leg(i, hip, paw, to_body.basis * Basis(Vector3.RIGHT, lerpf(pitches[i], 0.6, _air)), to_body.basis * poles[i], lifted)


## Where a hoof is in its stride: x how far the fetlock is bent (the hoof
## turned back), y how high, z how far ahead.
func _foot_cycle(phase: float, duty: float, half_step: float, lift: float, canter: float) -> Vector3:
	if phase < duty:
		var planted := phase / duty
		return Vector3(smoothstep(0.7, 1.0, planted) * 0.45, 0.0, lerpf(half_step, -half_step, planted))
	var swing := (phase - duty) / (1.0 - duty)
	var bent := lerpf(1.3, 1.8, canter)
	return Vector3(lerpf(bent, -0.1, smoothstep(0.15, 0.85, swing)), sin(PI * pow(swing, 0.7)) * lift, lerpf(-half_step, half_step, smoothstep(0.0, 1.0, swing)))


## Three-bone IK in body space, folding in a zigzag (DeerRig._solve_leg).
func _solve_leg(index: int, hip: Vector3, target: Vector3, paw_basis: Basis, pole: Vector3, lifted: float) -> void:
	var lengths := _lengths[index]
	var total := lengths.x + lengths.y + lengths.z
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.06 * _size, total - 0.004 * _size)
	var line := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var aside := pole - line * pole.dot(line)
	aside = aside.normalized() if aside.length_squared() > 0.0001 else AHEAD
	var paw := hip + line * reach
	var span := _spans[index]
	var bend := _bends[index]
	if reach > span:
		bend *= (total - reach) / (total - span)
	else:
		var fore := index < 2
		bend += (span - reach) / span * lerpf(FOLD_PLANTED.x if fore else FOLD_PLANTED.y, FOLD.x if fore else FOLD.y, lifted)
	var last := line * cos(bend) + aside * sin(bend)
	var far := lengths.x + lengths.y - 0.003 * _size
	var near := absf(lengths.x - lengths.y) + 0.01 * _size
	var second := paw - last * lengths.z
	for attempt in 8:
		if (second - hip).length() <= far:
			break
		last = last.slerp(line, 0.3).normalized()
		second = paw - last * lengths.z
	var across := second - hip
	var gap := clampf(across.length(), near, far)
	var along := across.normalized()
	second = hip + along * gap
	paw = second + last * lengths.z
	var off := aside - along * aside.dot(along)
	off = off.normalized() if off.length_squared() > 0.0001 else aside
	var fold := acos(clampf((lengths.x * lengths.x + gap * gap - lengths.y * lengths.y) / (2.0 * lengths.x * gap), -1.0, 1.0))
	var first := hip + (along * cos(fold) + off * sin(fold)) * lengths.x
	var normal := aside.cross(line).normalized()
	var bones: Array = _legs[index]
	var frames: Array = _frames[index]
	(bones[0] as Node3D).transform = Transform3D(_frame(normal, (first - hip).normalized()) * frames[0], hip)
	(bones[1] as Node3D).transform = Transform3D(_frame(normal, (second - first).normalized()) * frames[1], first)
	(bones[2] as Node3D).transform = Transform3D(_frame(normal, last) * frames[2], second)
	(bones[3] as Node3D).transform = Transform3D(paw_basis, paw)


static func _frame(normal: Vector3, along: Vector3) -> Basis:
	var x := (normal - along * normal.dot(along)).normalized()
	return Basis(x, -along, x.cross(-along))


## Turns its head towards what it is watching (the Horse's `look_at_point`), or
## lets it gaze about, slowly, at nothing.
func _look_about(delta: float) -> void:
	var target := Vector2.ZERO
	var point := _horse.look_at_point
	if point.is_finite() and _head:
		var to := point - _head.global_position
		target.x = clampf(angle_difference(global_rotation.y, atan2(to.x, to.z)), -1.5, 1.5)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6)
	else:
		target.x = sin(_time * 0.21) * 0.3 + sin(_time * 0.53 + 1.0) * 0.1
		target.y = sin(_time * 0.17 + 2.0) * 0.06
	var rate := 9.0 if _alert > 0.5 or _spook > 0.5 else 2.5
	_look = _look.lerp(target, 1.0 - exp(-rate * delta))


## The tail: hanging at ease, swished at the flies now and then (more standing
## still), lifted and streaming at the canter and gallop, high when it is
## spooked, flung about in a shake, laid out on the ground in a roll.
func _carry_tail(delta: float, canter: float, gallop: float, shake: float, lying: float) -> void:
	_swish_timer -= delta
	if _swish_timer <= 0.0:
		_swish_timer = randf_range(1.5, 5.0) * (0.6 if _graze > 0.5 or _doze > 0.5 else 1.0)
		_swish = 1.0
		_swish_way = -_swish_way if randf() < 0.7 else _swish_way
	_swish = maxf(_swish - delta * 1.6, 0.0)
	var swing := sin(PI * (1.0 - _swish)) * _swish_way * 0.9 * (1.0 - canter)
	swing += sin(TAU * 4.0 * _shaken) * 0.6 * shake
	var lift := 0.2 * canter + 0.25 * gallop + 0.9 * _spook - 0.05 * _doze
	for i in _tail.size():
		var link := _tail[i]
		var curl := (lift - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5) if i == 0 else lift * 0.3 * (1.0 - _spook * 0.5)
		link.aim = Basis(Vector3.UP, swing * (0.6 if i == 0 else 0.4)) * Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = 0.6 if i == 0 else 0.9
		link.gravity = lerpf(6.0, 2.0, lying)
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.0, 7.0)
		if _alert < 0.5 and lying < 0.01 and randf() < 0.6:
			var which := randi() % 2
			_flick(which, Vector3(0.6 if which == 0 else -0.6, 0.4, 0.0))
			# (and now and then the skin of its shoulder or flank shivers, at a fly)
			if randf() < 0.5 and _body:
				var flank := _body.global_transform * (Vector3((0.28 if randf() < 0.5 else -0.28) * _size, 0.05 * _size, (0.25 if randf() < 0.5 else -0.2) * _size))
				twitch(flank)


func _flick(which: int, push: Vector3) -> void:
	for link: Link in _ears[which]:
		link.velocity += (link.joint.get_parent() as Node3D).global_basis * push * 2.0


## The ears: at ease each turns about on its own, one back now and then,
## listening; alert, both pricked forward at what it watches; pinned flat back
## galloping or fleeing; out to the sides, drooping, dozing; soft and forward friendly.
func _carry_ears(delta: float, gallop: float) -> void:
	var flat := maxf(_flee * 0.9, gallop * 0.6)
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(1.2, 3.5) if _alert > 0.5 else randf_range(0.8, 3.0)
		var pick := randi() % 4
		_ear_turn_to = Vector2(randf_range(0.6, 1.3) if pick == 0 else 0.0, randf_range(0.6, 1.3) if pick == 1 else 0.0)
		if _alert > 0.5 and randf() < 0.6:
			_ear_turn_to = Vector2.ZERO
	_ear_turn = _ear_turn.lerp(_ear_turn_to * (1.0 - flat) * (1.0 - _alert * 0.6), 1.0 - exp(-8.0 * delta))
	for side in 2:
		var out := 1.0 if side == 0 else -1.0
		var turn: float = _ear_turn[side]
		var root: Link = _ears[side][0]
		var tip: Link = _ears[side][1]
		var forward := maxf(_alert, _friend * 0.5) * 0.35 * (1.0 - turn)
		var droop := _doze * 0.9
		var lean := Basis(Vector3.RIGHT, -flat * 1.15 + forward) * Basis(BEHIND, out * (flat * 0.2 + droop - forward * 0.2))
		root.aim = lean * root.rest
		root.twist = out * (turn * 1.5 + flat * 0.3 + droop * 0.5 - forward * 0.4)
		tip.aim = Basis(Vector3.RIGHT, -flat * 0.2) * tip.rest


func _swing(delta: float) -> void:
	var ground := global_position.y - position.y + 0.03
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


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


## Reads a curve drawn by hand: (time, value) pairs, joined smoothly.
static func _keyed(keys: Array, time: float) -> float:
	var last := keys.size() / 2 - 1
	if time <= keys[0]:
		return keys[1]
	if time >= keys[last * 2]:
		return keys[last * 2 + 1]
	var k := 0
	while time > keys[k * 2 + 2]:
		k += 1
	var t0: float = keys[k * 2]
	var t1: float = keys[k * 2 + 2]
	var v0: float = keys[k * 2 + 1]
	var v1: float = keys[k * 2 + 3]
	var m0: float = (v1 - keys[k * 2 - 1]) / (t1 - keys[k * 2 - 2]) if k > 0 else 0.0
	var m1: float = (keys[k * 2 + 5] - v0) / (keys[k * 2 + 4] - t0) if k < last - 1 else 0.0
	var span := t1 - t0
	var u := (time - t0) / span
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * span * m1


func _build() -> void:
	var model: Node = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	_mesh = meshes[0] if not meshes.is_empty() else null
	materials = HorseLook.dress(model, coat, coat_tint, 0 if low_poly else fur_shells, eyeshine, 0.012)
	_body_rest = _rest(&"body")
	_body = _joint(self, &"body")
	_chest = _joint(_body, &"chest")
	_pelvis = _joint(_body, &"pelvis")
	_neck = _joint(_chest, &"neck")
	_neck_1 = _joint(_neck, &"neck_1")
	_head = _joint(_neck_1, &"head")
	_jaw = _joint(_head, &"jaw")
	_nose = _rest(&"nose")
	_brow = _rest(&"brow")
	_seat = _rest(&"seat")
	_grip = _rest(&"grip")
	for i in 4:
		var fore := i < 2
		var bones: Array = []
		var at: Array[Vector3] = []
		for bone: String in ["upper", "lower", "hock", "paw"]:
			bones.append(_joint(_body, bone + SUFFIXES[i]))
			at.append(_body_rest + _rest(bone + SUFFIXES[i]))
		_legs.append(bones)
		_hips.append(at[0])
		_paws.append(at[3])
		_lengths.append(Vector3(at[0].distance_to(at[1]), at[1].distance_to(at[2]), at[2].distance_to(at[3])))
		var line := (at[3] - at[0]).normalized()
		var pole := BEHIND if fore else AHEAD
		var aside := (pole - line * pole.dot(line)).normalized()
		var normal := aside.cross(line).normalized()
		var last := (at[3] - at[2]).normalized()
		_spans.append(at[0].distance_to(at[3]))
		_bends.append(atan2(last.dot(aside), last.dot(line)))
		_frames.append([
			_frame(normal, (at[1] - at[0]).normalized()).inverse(), _frame(normal, (at[2] - at[1]).normalized()).inverse(),
			_frame(normal, last).inverse(),
		])
	_paw_height = _paws[0].y
	_size = _hips[2].y / HIP
	var names: Array[String] = ["tail", "tail_1", "tail_2", "tail_end"]
	var from := _pelvis
	for i in 3:
		var link := _link(from, names[i], _rest(names[i + 1]))
		link.stiffness = [1400.0, 260.0, 120.0][i]
		link.damping = [40.0, 14.0, 8.0][i]
		link.gravity = 6.0
		link.drag = 1.2 if i > 0 else 1.0
		link.limit = 0.6
		_tail.append(link)
		from = link.joint
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		var root := _link(_head, "ear" + suffix, _rest("ear_tip" + suffix))
		var tip := _link(root.joint, "ear_tip" + suffix, _rest("ear_end" + suffix))
		for link: Link in [root, tip]:
			link.stiffness = 1100.0 if link == root else 500.0
			link.damping = 24.0 if link == root else 11.0
			link.gravity = 0.0 if link == root else 1.0
			link.drag = 0.5
			link.limit = 0.6 if link == root else 0.6
		_ears[side] = [root, tip]


func _rest(bone: StringName) -> Vector3:
	var index := _skeleton.find_bone(bone)
	return _skeleton.get_bone_rest(index).origin if index >= 0 else Vector3.ZERO


func _joint(parent: Node3D, bone: StringName) -> Node3D:
	var joint := Node3D.new()
	var index := _skeleton.find_bone(bone)
	joint.name = bone
	joint.position = _skeleton.get_bone_rest(index).origin
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(index)
	return joint


func _link(parent: Node3D, bone: StringName, end: Vector3) -> Link:
	var link := Link.new()
	link.joint = Node3D.new()
	link.bone = _skeleton.find_bone(bone)
	link.joint.name = bone
	link.joint.position = _skeleton.get_bone_rest(link.bone).origin
	parent.add_child(link.joint)
	link.rest = end.normalized()
	link.aim = link.rest
	link.length = end.length()
	_links.append(link)
	return link
