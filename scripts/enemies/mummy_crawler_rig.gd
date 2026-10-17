class_name MummyCrawlerRig
extends MummyRig
## The crawler's way of moving (`Mummy.Kind.CRAWLER`, models/enemies/mummy_crawler.glb).
## It has no legs below the thigh, and does not stand: it lies on its front and
## hauls itself along the ground on its arms.
##
## - Each hand in turn is thrown out ahead, comes down flat, and stays where it
##   is on the ground while the body is dragged up to it and past; so it comes
##   on in surges, a pull to each hand (`pace`), and quickly. Its back bends
##   from side to side as a lizard's does, the shoulder of the reaching arm
##   going forward; its chest heaves up off the ground on each pull; its hips
##   and the stumps of its thighs drag behind, and what is left of its
##   wrappings trails after them.
## - Its head is craned back to keep its face on him.
## - Dormant, it lies flat with its face in the dust.
## - It strikes at his ankles: it rears its chest up on one arm with the other
##   drawn back (WIND_UP), and throws itself forward flat, the arm sweeping
##   along the ground through where he stands (STRIKE).
##
## Its hands are moved as the other kinds' feet are, by `_tread`, and are kept
## in the same lists (`_foot_at` and the rest): a hand's place on the ground,
## measured from REACH in front of its hips.

const STRIDE_LENGTH := 0.84
const SWING := 0.38
## How far in front of its hips the middle of a hand's pull is, as modelled.
const REACH := 0.5
## How high its hips lie: on the ground.
const BELLY := 0.082

var _heave := Vector2.ZERO
var _tail := Vector2.ZERO


func _build() -> void:
	super()
	swipe_wind_up = 0.38
	swipe_strike = 0.15
	swipe_hold = 0.45
	swipe_recover = 0.5
	_hinged = true


## It goes fastest in the middle of each pull, and all but stops between them.
func pace() -> float:
	return 1.0 - 0.45 * cos(TAU * 2.0 * (_cycle - SWING))


## Where a hand lies when it is going nowhere (see the top of the file).
func _standing(i: int) -> Vector3:
	return Vector3((absf(_shoulder_rest[i].x) + 0.07) * (1.0 if i == 0 else -1.0), 0.0, 0.0 if i == 0 else -0.08)


func _hand_down(i: int) -> void:
	_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, REACH)), Vector3.ZERO, 0.11, 2)
	_heave.y += 0.5 * _move


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going := _gone(delta)
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 3.0, delta)
	var go := _move * (1.0 - _air)
	var levels := _swipe_levels(delta)
	var wound := levels.x
	var struck := levels.y
	var sweep := levels.z
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	var swiping := _swipe_time < total
	var up := smoothstep(0.0, 1.0, _wake)

	_tread(going, turned, go, delta, STRIDE_LENGTH, SWING, absf(_shoulder_rest[0].x) + 0.07, _hand_down)
	# (as it turns, a hand on the ground goes round its hips, which are REACH behind where the hands are measured from)
	for i in 2:
		_foot_at[i] += Vector3(0.0, 0.0, REACH).rotated(Vector3.UP, -turned) - Vector3(0.0, 0.0, REACH)

	# --- Its body, along the ground ---
	var p := _cycle
	# Which shoulder is forward: the left's as its hand comes down, then the right's.
	var bend := cos(TAU * (p - SWING)) * go
	_heave = _sprung(_heave, (0.5 - 0.5 * cos(TAU * 2.0 * (p - SWING))) * go, 90.0, 9.0, delta)
	_tail = _sprung(_tail, -bend * 0.3 - turned / maxf(delta, 0.001) * 0.05, 30.0, 4.0, delta)
	# How far over on its front it is: flat when dormant, propped on its arms when not, reared up to strike.
	var pitch := lerpf(1.52, 1.2 - 0.07 * _heave.x, up) - 0.34 * wound + 0.22 * struck
	_hips.position = Vector3(0.0, BELLY + 0.012 * _heave.x * up, 0.1 * struck - 0.03 * wound)
	_hips.basis = Basis(Vector3.UP, -bend * 0.08) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, bend * 0.1)
	# (seen from above, its back bends to put the reaching shoulder forward: about the axis that points into the ground)
	var arch := up * (1.0 + 0.5 * wound - 0.6 * struck)
	_spine.rotation = Vector3(-0.1 * arch, 0.0, bend * 0.13)
	_chest.rotation = Vector3(-0.2 * arch - 0.05 * _heave.x * up, 0.0, bend * 0.12)

	# Its head, craned back; and turned to him.
	_watch_him(0.3, Vector2(0.9, 0.5), 3.5, delta)
	var crane := up * (0.95 + 0.07 * _heave.x) - 0.25 * struck + 0.3 * wound - _gaze.y
	_neck.basis = Basis(Vector3.RIGHT, -crane * 0.5) * Basis(Vector3.UP, _gaze.x * 0.45) * Basis(Vector3.BACK, -bend * 0.12)
	_head.basis = Basis(Vector3.RIGHT, -crane * 0.5) * Basis(Vector3.UP, _gaze.x * 0.55)

	# What is left of its legs lies out behind and is swung from side to side by the rest of it.
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var hip := Vector3(side * _hip_width, _hip_drop, 0.0)
		var lie := Basis(Vector3.BACK, _tail.x * 0.5 + side * 0.07) * Basis(Vector3.RIGHT, (pitch - 1.52) * 0.9 + 0.05)
		_thighs[i].transform = Transform3D(lie, hip)
		_shins[i].transform = Transform3D(lie, hip + lie * Vector3.DOWN * _thigh)
		_feet[i].transform = Transform3D(lie, hip + lie * Vector3.DOWN * (_thigh + _shin))
		_toes[i].rotation = Vector3.ZERO
		_half_joints(i)

	# --- Its arms ---
	var mark := Vector3(0.0, 0.1, 2.0)
	if aim.is_finite():
		mark = to_local(aim)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var t := _foot_swing[i]
		var lift := sin(PI * pow(t, 0.8)) * 0.11 if t >= 0.0 else 0.0
		var place := Vector3(_foot_at[i].x, 0.03 + lift, REACH + _foot_at[i].z)
		# (its elbows stand out to the side, as a lizard's do)
		var pole := Vector3(side, 0.0, -0.4)
		var flat := 1.0 if t < 0.0 else 1.0 - sin(PI * t)
		var curl := lerpf(0.15, 0.75, 1.0 - flat)
		var splay := 1.1
		if swiping and (_swipe_arm == 2 or _swipe_arm == i):
			# Drawn back beside its head; along the ground through his ankles; and on across.
			var back := Vector3(side * 0.42, 0.5, 0.34)
			var through := Vector3(side * 0.08, 0.13, 1.08)
			var done := Vector3(-side * (0.22 if _swipe_arm != 2 else -0.04), 0.07, 0.94)
			var curve := through * 2.0 - (back + done) * 0.5
			var u := sweep * sweep * (3.0 - 2.0 * sweep)
			var stroke := back.lerp(curve, u).lerp(curve.lerp(done, u), u)
			var blow := place.lerp(back, smoothstep(0.0, swipe_wind_up * 0.8, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
			var over := smoothstep(0.0, 0.1, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.8, total, _swipe_time))
			place = place.lerp(blow, over)
			flat = lerpf(flat, 0.0, over)
			curl = lerpf(curl, lerpf(0.1, 1.1, smoothstep(0.7, 1.0, sweep)), over)
			splay = lerpf(splay, 1.35, over)
		_hand_at[i] = place
		_hand_to(i, place, pole)
		_hands[i].rotation = Vector3(0.3, 0.0, 0.0)
		# (a hand on the ground lies flat on it, fingers forward)
		_lay_hand(i, side, global_basis.y.normalized(), global_basis.z.normalized(), flat)
		_curl[i] = curl
		_splay[i] = splay
		_pose_fingers(i, side)

	# It raises the dust all the way along.
	_scuff -= delta
	if go > 0.3 and _scuff <= 0.0:
		_scuff = 0.12
		_own_dust.puff(to_global(Vector3(0.0, 0.02, -0.1)), Vector3.ZERO, 0.13, 1)
	_hang_chains(size, delta)
	_posed = true
