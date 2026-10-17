class_name Player
extends CharacterBody3D
## Character controller tuned for touch.
##
## Simulation runs in the physics step; the visible rig is detached and follows an
## interpolated position, so motion stays smooth on any refresh rate.
##
## Besides running, sprinting and jumping he can push blocks, sneak, slide out of a run,
## catch ledges, shimmy along and climb them, climb ropes, and pick things up
## and throw them. How he takes a landing depends on how hard he comes down.

signal jumped
signal landed(impact_speed: float)
signal respawned
signal threw
signal kicked_off
## He has gone into water over his chest, coming down at `speed`.
signal splashed(speed: float)
## He has thrown himself into a dive out of a running jump.
signal dived
## He has gone over backwards out of a crouch.
signal flipped
## He has fired the gun he holds; `kick` is how hard it recoils (the gun's own).
signal shot(kick: float)
## He has gone to sleep, and woken (with a start, if something is after him).
signal slept
signal woke(startled: bool)

enum MoveMode {
	FREE, ## Camera-relative movement on the whole ground plane.
	SIDE_SCROLL, ## Movement along world X only, like Inside.
}

## What the body is doing, beyond ordinary movement.
enum State {
	FREE, ## Walking, running, ducking, in the air.
	SLIDE, ## Sliding low out of a run.
	HANG, ## Hanging from a ledge by the hands.
	CLIMB, ## Pulling up onto that ledge.
	ROPE, ## On a rope.
	LADDER, ## On a ladder.
	SWIM, ## In water over his chest.
}

## How he takes a landing, from the gentlest to the hardest.
enum Landing {
	SOFT, ## On his feet, knees giving.
	THREE_POINT, ## Down on one knee and a fist, held a moment, then up.
	SPRAWL, ## Onto that knee and fist and on over them, flat on his front; then he pushes himself up, or scrambles off.
	STUMBLE, ## Pitched forward onto legs that cannot catch up with him, and over in a roll.
	ROLL, ## Over in a ball and up again.
}

## Whether he is up and about, or has been sat down, or put to sleep.
enum Rest {
	UP,
	SITTING, ## Sat on the ground, until something stirs him.
	ASLEEP, ## Lying curled on his side. (He sits down first, and sits up to wake.)
}

## How far through picking something up he has it in his hand, and how far
## through a throw it leaves it.
const PICKUP_TAKES := 0.5
const THROW_RELEASE := 0.56
## How far through its throw a grappling hook leaves his hand.
const CAST_RELEASE := 0.6
## How far through a sprawl he is down on his front, and may scramble off
## instead of getting up (from, to).
const SCRAMBLE := Vector2(0.24, 0.62)
## How far a sprawl throws him forward over his feet, metres, and while (from, to).
const SPRAWL_THROW := 0.68
const SPRAWL_FALLS := Vector2(0.0, 0.16)
## How far through a swing of a bat it meets whatever is in front of him.
const SWING_HITS := 0.5
## How far under the surface his feet are when he floats, and when he counts as under it.
const FLOAT_DEPTH := 1.0
const UNDER_DEPTH := 1.3
## How long getting off the top of a ladder takes (and getting onto it from there).
const LADDER_OFF_TAKES := 0.55
## How far up a rope he gets with each hand.
const ROPE_PULL := 0.28
## Left alone, how long before he would sleep he yawns and stretches; how long he
## sits before he lies down; and how long he rubs his eyes when he has sat up again.
const YAWN_TAKES := 3.2
const SIT_PAUSE := 1.3
const RUB_TAKES := 1.5
## A dive into water: how far under his feet need be for it to have him (he goes
## in head first, so sooner than he would on his feet), and for how long he
## goes on down and forward before he swims.
const DIVE_IN_DEPTH := 0.3
const DIVE_IN_TAKES := 0.55

@export var move_mode := MoveMode.FREE
## Whether this one is steered by this machine's keys, pads and touch. Off, he
## takes no input at all and stands until something else moves him (another
## player's copy in a networked game, say). (GameCommon only: not in Outside.)
@export var takes_input := true

## While true, nothing from the keys, pads or touch reaches any Player or the
## camera: set it while a level loads or a menu is up. (GameCommon only: it
## stands in for Outside's `Loading.busy`.)
static var input_blocked := false

@export_group("Ground")
@export var walk_speed := 1.6
@export var run_speed := 4.4
## Kept at a full run for `sprint_delay` seconds, he breaks into a sprint (if
## `auto_sprint`). Holding sprint (Shift, LB or LT, the touch controls' sprint)
## has him sprint at once, at any push of the stick past a walk.
@export var sprint_speed := 5.6
@export var sprint_delay := 0.8
## Whether a full push held for `sprint_delay` sprints by itself. (The Clearing: off,
## sprint is a button of its own. GameCommon and Outside: on.)
@export var auto_sprint := true
@export var push_speed := 1.15
## Stick deflection at which the walk starts turning into a run.
@export_range(0.0, 1.0) var run_threshold := 0.55
@export var acceleration := 20.0
@export var deceleration := 26.0
## Used while input opposes the current velocity, for snappy reversals.
@export var turn_acceleration := 36.0
## How quickly the model turns to face its heading.
@export var turn_rate := 13.0
@export var max_step_height := 0.32

@export_group("Air")
@export var jump_height := 1.15
@export var time_to_apex := 0.36
@export var fall_gravity_scale := 1.7
## Extra gravity while rising after jump is released, giving short hops.
@export var jump_cut_gravity_scale := 2.8
@export var air_acceleration := 10.0
@export var max_fall_speed := 20.0
## Grace period to still jump after walking off a ledge.
@export var coyote_time := 0.12
## A jump pressed this long before landing still fires.
@export var jump_buffer_time := 0.15
## Jumping again in the air against a wall kicks him off it: how fast away from
## it, and how fast upwards, as shares of his running speed and of a jump.
@export var wall_kick := Vector2(0.95, 0.92)

@export_group("Duck and slide")
@export var crouch_speed := 1.3
@export var stand_height := 1.25
@export var crouch_height := 0.72
@export var slide_height := 0.6
## Ducking while moving at least this fast starts a slide instead.
@export var slide_min_speed := 3.0
## How quickly a slide loses speed, m/s².
@export var slide_friction := 4.5
## A slide ends when it has slowed to this.
@export var slide_end_speed := 1.5

@export_group("Climbing")
## A ledge can be caught when its top is this far above the feet (least, most).
@export var ledge_reach := Vector2(0.55, 1.6)
## How far below the ledge the feet hang.
@export var hang_height := 1.27
@export var climb_time := 1.45
## How fast he works his way along a ledge he is hanging from.
@export var shimmy_speed := 0.8
## How fast he climbs a rope, and how fast he lets himself down it.
@export var rope_speed := 1.5
@export var rope_slide_speed := 3.4
## How near a rope has to pass for him to catch it: whatever he does, and when
## he is going towards it (or reaching for it with the stick).
@export var rope_reach := Vector2(0.45, 0.7)
## How hard he can throw his weight into a swing, m/s²; how quickly he can stop
## one by throwing it against (per second); and how far round from straight
## down he can work it up to, in degrees.
@export var rope_pump := 4.0
@export var rope_brake := 1.4
@export var rope_swing_limit := 56.0
## Leaping off a rope: the push he gives himself the way he is going, m/s, and
## how much of a jump's lift goes with it. (The rest is the swing's own.)
@export var rope_leap := Vector2(1.6, 0.7)
@export var ladder_speed := 1.5

@export_group("Crawling and swimming")
## On hands and knees, under what is too low even to sneak under.
@export var crawl_speed := 0.8
## On the surface: a gentle push is breast stroke, a full one a crawl.
@export var swim_speeds := Vector2(1.2, 2.6)
## Under it: a frog kick, and a flutter kick.
@export var dive_speeds := Vector2(1.3, 2.7)
## How long a swing of a bat takes, and how hard it hits (m/s given to what it meets).
@export var swing_time := 0.6
@export var swing_power := 11.0

@export_group("Throwing")
@export var pickup_reach := 1.1
## How near he must stand to something to work it (a lever, a mirror), over the ground.
@export var work_reach := 1.25
## Speed given to a thrown object: forwards, upwards.
@export var throw_speed := Vector2(12.0, 4.5)
## How long it takes him to stoop for something, and to wind up and throw it.
@export var pickup_time := 0.55
@export var throw_time := 0.8
## How long the wind-up and throw of a grappling hook take, how long he is
## winding it back in, and how far off the ground it lifts him as it takes his weight.
@export var cast_time := 0.62
@export var reel_time := 0.7
@export var grapple_lift := 0.55

@export_group("Landing")
## Coming down faster than these (m/s) he lands on three points, goes sprawling,
## stumbles, or rolls. A jump on the flat lands at about 8; a drop of 1.5 m at
## 9.5, of 2 m at 11, of 2.5 m at 12.3, of 3 m at 13.5, of 4.5 m at 16.5.
@export var landing_speeds := Vector4(9.0, 11.6, 13.0, 15.2)
## How long each of those takes him, seconds.
@export var landing_times := Vector4(1.0, 1.5, 0.95, 0.72)
## How fast a stumble (to begin with) and a roll carry him forward.
@export var stumble_speed := 3.2
@export var roll_speed := 4.4

@export_group("New moves")
## Switches for the newer moves: off, the game behaves as it did before each
## was written.
@export var dive_enabled := true
@export var flip_enabled := true
@export var spin_enabled := true
## Sitting down by holding duck, and going to sleep when left alone. (`sit()`,
## `sleep()` and `wake()` work either way.)
@export var rest_enabled := true
## Guns held and fired as guns. Off, a gun is picked up and thrown like anything else.
@export var gun_handling := true

@export_group("Tumbling")
## Duck pressed within this long of taking off out of a run throws him into a
## dive: flatter and longer than the jump, onto his hands and over in a roll.
@export var dive_window := 0.25
## He must be going at least this fast for it.
@export var dive_min_speed := 3.0
## The least a dive carries him forward at, m/s; how much of a jump's rise it may
## keep; and how much of gravity it feels, which is what makes it long and flat.
@export var dive_speed := 5.0
@export_range(0.0, 1.0) var dive_lift := 0.42
@export_range(0.3, 1.0) var dive_gravity_scale := 0.8
## Jumping out of a duck is a back tuck: how high, as a share of a jump; how long
## he is turning over, seconds; and how fast it carries him backwards.
@export var flip_lift := 1.0
@export var flip_time := 0.6
@export var flip_drift := 0.45

@export_group("Spinning")
## Whipping the stick round sets him spinning. What counts is how far its
## direction has turned one way lately, radians: he starts at the first of
## these and stops below the second (a full turn of the stick inside about
## half a second starts it; a tight circle run does not get near).
@export var spin_start := 4.2
@export var spin_stop := 2.0
## How long a turn of the stick is remembered, seconds.
@export var spin_memory := 0.45
## The stick must be pushed at least this far for its turning to count.
@export_range(0.1, 1.0) var spin_deflection := 0.6
## How fast he turns, radians a second.
@export var spin_rate := 15.0
## How fast he gets dizzy while spinning, and gets over it, per second.
@export var dizzy_rates := Vector2(0.3, 0.07)

@export_group("Resting")
## Left alone this long he yawns, sits down, and goes to sleep (0: never).
@export var sleep_after := 40.0
## Duck held this long standing still sits him down; and as long again, to sleep (0: never).
@export var sit_hold := 2.2
## How long sitting down takes him, and lying down from there.
@export var sit_time := 1.15
@export var lie_time := 1.5

@export_group("Guns")
## How long it takes him to bring a gun up to aim, how long after a shot he keeps
## it there, and how long to lower it.
@export var gun_raise_time := 0.26
@export var gun_hold_time := 1.3
@export var gun_lower_time := 0.45
## He aims the way he faces, helped towards the nearest thing in the groups
## `pursuers` and `interest` that is within this angle of it (radians) and this far.
@export var gun_cone := 0.4
@export var gun_range := 30.0
## How fast a shot shoves him backwards, m/s for a gun whose `kick` is 1.
@export var gun_shove := 2.4

@export_group("Feel")
@export var push_force := 500.0
@export var kill_height := -15.0

## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := PI * 0.5
var is_pushing := false
var is_sprinting := false
## True while the body is a ragdoll and takes no input.
var is_limp := false
var state := State.FREE
var is_ducking := false
## Down on hands and knees.
var is_crawling := false
## Swimming, with his head under.
var is_underwater := false
## How far through a swing of a bat he is, 0..1 (1: not swinging).
var swing_progress := 1.0
## How far he has climbed on the ladder he is on, and where his feet belong on
## its rungs (left, right, in world space). The rig steps them there.
var ladder_travel := 0.0
var foot_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
## How far through getting off the top of a ladder he is, 0..1 (0: he is simply on it).
var ladder_off := 0.0
## Swimming: how clear the water ahead of him is, 0 (a wall at his nose) to 1.
var swim_clear := 1.0
## On a flight of stairs, 0 or 1: at least two risers running the way he is going.
## How high each is (negative going down), how far apart they are, a point on
## the edge of one of them, and which way the flight runs. The rig steps on the treads.
var on_stairs := 0.0
var stair_rise := 0.0
var stair_run := 0.4
var stair_edge := Vector3.ZERO
var stair_dir := Vector3.FORWARD
## What he last threw. He watches it go.
var last_thrown: RigidBody3D
## How far through pulling up onto a ledge, 0..1.
var climb_progress := 0.0
## Distance climbed on the current rope, for the hand-over-hand.
var rope_travel := 0.0
## How long he has been off the ground, seconds.
var air_time := 0.0
## How he took his last landing, and how far through it he is, 0..1 (1: over).
var landing := Landing.SOFT
var landing_progress := 1.0
## Down on his front after a sprawl, and getting off it at a run instead of standing up.
var is_scrambling := false
## How far through stooping for something he is, and through throwing it, 0..1
## (1: he is doing neither); and where the thing he is stooping for lies.
var pickup_progress := 1.0
var throw_progress := 1.0
## The wind-up and throw of a grappling hook, 0..1 (it leaves his hand at
## CAST_RELEASE); whether it is out on its line; winding it back in, 0..1; and
## its rope coming taut in his hands, 0..1.
var cast_progress := 1.0
var hook_out := false
var reel_progress := 1.0
var taut_progress := 1.0
var pickup_point := Vector3.ZERO
## The top edge he is hanging from, where his chest is: a point on the corner
## itself. And whether there is wall below it for his feet, or only air.
var ledge_point := Vector3.ZERO
var ledge_wall := true
## How far he has shimmied along it, his left positive.
var shimmy_travel := 0.0
## Where his hands belong when he has hold of something (left, right, in world
## space), and how firmly, 0..1: a ledge, a rope, or whatever he is leaning on.
## The rig reaches for these.
var hand_points := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var hand_reach := 0.0
## Which way the surface he is pressing his hands on faces, or zero when he is
## gripping something instead. The rig lays his palms flat against it, fingers
## pointing along `hand_fingers` (or upwards and a little apart, if that is zero),
## and with `hand_hook` bends them over at the knuckles, as over the lip of a ledge.
var hand_normal := Vector3.ZERO
var hand_fingers := Vector3.ZERO
var hand_hook := 0.0
## In a dive: thrown forward off a running jump, until his hands meet the ground
## (or the water). And how long he has been. `dive_roll` is the roll that it
## lands in (a `Landing.ROLL`, which the rig takes over a shoulder).
var is_diving := false
var dive_time := 0.0
var dive_roll := false
## Gone into water in a dive, 1 running down to 0 while it still carries him under.
var dive_in := 0.0
## How far through a back tuck he is, 0..1 (1: he is not in one).
var flip_progress := 1.0
## Spinning on the spot (which way: 1 to his left); how giddy it has made him,
## 0..1; and staggering out of it, 1 running down to 0.
var is_spinning := false
var spin_way := 1.0
var dizzy := 0.0
var stagger := 0.0
## What he has been told to do about resting (see `sit`, `sleep`, `wake`); how
## far down he is sat, 0..1; how far from sitting he is lying, 0..1; a yawn and a
## stretch, and rubbing his eyes, each 0..1 (1: not doing it); and woken with a
## start, 1 fading to 0.
var rest := Rest.UP
var sit_progress := 0.0
var lie_progress := 0.0
var yawn_progress := 1.0
var rub_progress := 1.0
var startled := 0.0
## How deep the water he is wading in is, metres (0 on dry land; he swims at FLOAT_DEPTH).
var wade := 0.0
## A gun in his hands: how far up to aim it is, 0..1, and which way it is aimed, in the world.
var gun_raise := 0.0
var gun_aim := Vector3.FORWARD
## What he is holding, if anything.
var carried: RigidBody3D
## Render-rate position of the character; follow this, not global_position.
var visual_position := Vector3.ZERO

var _touch: TouchControls
## Whether a gamepad's right trigger is pulled (see `_trigger`).
var _trigger_pulled := false
var _gravity := 0.0
var _jump_velocity := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _landing_time := 0.0
var _landing_direction := Vector3.ZERO
var _push_timer := 0.0
var _run_time := 0.0
var _jumping := false
var _was_grounded := false
var _wish := Vector3.ZERO
var _spawn := Transform3D.IDENTITY
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _visual_offset := Vector3.ZERO
## How much longer he waits on a step he has been lifted onto while what is seen
## of him gets there; how fast that is, m/s (zero when it is not on its way to
## one); and how long before it sets off, which is as long as what is drawn is
## behind the body anyway.
var _step_hold := 0.0
var _step_rate := 0.0
var _step_delay := 0.0
var _picking: RigidBody3D
## Where what he has just picked up was, and how far it has come from there to his hand.
var _carry_from := Vector3.ZERO
var _carry_ease := 1.0
var _state_time := 0.0
var _grab_cooldown := 0.0
var _slide_direction := Vector3.ZERO
var _ledge_top := Vector3.ZERO
var _ledge_direction := Vector3.ZERO
## Where each hand has hold of the ledge (left, right), and how long until one may move again.
var _grips := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _grip_rest := 0.0
var _climb_from := Vector3.ZERO
var _rope: Rope
var _ladder: Ladder
var _pool: Pool
## How far down the rope his hands are.
var _rope_at := 0.0
var _rope_heading := Vector3.ZERO
## Act has been let go since he took hold of the rope (it climbs only when pressed afresh).
var _rope_act := false
## The rope he has just left, which he does not catch again at once.
var _rope_left: Rope
var _rope_rest := 0.0
## The grappling hook whose rope he is on, if it is one.
var _grapple: Node3D
## What he is throwing a hook at (nothing, for a throw that will fall short).
var _cast_at: Node3D
## Being lifted off his feet by a hook's rope: the height his hands are to come to, and for how long it has been.
var _take_up := Vector2.ZERO
var _take_time := -1.0
## Thrown off a rope: in the air he keeps the speed it gave him.
var _flung := false
## He has only just taken hold of the rope, and has still to be brought to it.
var _rope_new := false
## Which way is up for what is seen of him: along the rope he is on.
var _tilt := Vector3.UP
## Getting off the top of a ladder (1) or onto it from there (-1), and from where to where.
var _ladder_leaving := 0.0
var _ladder_from := Vector3.ZERO
var _ladder_onto := Vector3.ZERO
## How long since he kicked off a wall he must wait to kick again, and which way he went.
var _kick_rest := 0.0
var _kick_away := Vector3.ZERO
## How long after leaping out of water before it can take him again.
var _swim_rest := 0.0
var _stairs_seen := 0.0
var _carried_layers := Vector2i.ZERO
var _lean_timer := 0.0
## How long he has been leaning without a break; a brush against a step is not a lean.
var _lean_held := 0.0
var _lean_point := Vector3.ZERO
var _lean_normal := Vector3.ZERO
## Duck: held last step, and pressed this one. How long since he jumped off the ground.
var _duck_was := false
var _duck_pressed := false
var _since_jump := 10.0
var _dive_direction := Vector3.ZERO
## How fast the roll he is in carries him (a dive keeps the speed it had).
var _roll_carry := 4.4
## The stick: which way it pointed last, how long since it pointed anywhere, and
## how far it has lately turned one way (see `spin_start`).
var _spin_angle := 0.0
var _spin_gap := 1.0
var _spin_turned := 0.0
## How fast he is actually turning, which comes up and dies away.
var _spin_speed := 0.0
## How long he has been left alone; how long duck has been held with him still;
## something has stirred him this step; how long he has been sat; how long
## he is to sit before getting up by himself (0: until stirred); and how long
## until he looks again for anything after him.
var _idle_time := 0.0
var _duck_still := 0.0
var _stirred := false
var _sat_time := 0.0
var _sit_for := 0.0
var _hunt_check := 0.0
var _hunted := false
## A gun: he has been told to fire, and how much longer he keeps it up.
var _fire_wanted := false
var _aim_hold := 0.0
var _last_depth := -1000.0

@onready var _rig: CharacterRig = $Rig
@onready var _collider: CollisionShape3D = $Collision
@onready var _capsule: CapsuleShape3D = _collider.shape
@onready var _radius: float = _capsule.radius


func _ready() -> void:
	_ensure_input_actions()
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = 2.0 * jump_height / time_to_apex
	floor_snap_length = max_step_height
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	# Its own layer, so hounds can run through the player rather than shove them.
	collision_layer = 2
	_spawn = global_transform
	_rig.top_level = true
	_set_height(stand_height)
	_reset_visuals()
	_connect_touch.call_deferred()


func _connect_touch() -> void:
	if not takes_input:
		return
	_touch = get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	if _touch:
		_touch.jump_pressed.connect(_queue_jump)
		_touch.act_pressed.connect(_act)


func _unhandled_input(event: InputEvent) -> void:
	if not _listening():
		return
	if event.is_action_pressed(&"jump"):
		_queue_jump()
	elif event.is_action_pressed(&"act"):
		_act()
	elif event is InputEventJoypadMotion:
		_trigger(event)
	elif event.is_action_pressed(&"ragdoll"):
		# For trying it out: R drops him, R again stands him back up.
		if is_limp:
			recover()
		else:
			ragdoll(Vector3(sin(facing_yaw), 0.6, cos(facing_yaw)) * 25.0)


# A gamepad's right trigger is his hand, as X is (it is what a finger wants to
# fire a gun with): once as it is pulled, however far it goes on after that.
func _trigger(event: InputEventJoypadMotion) -> void:
	if event.axis != JOY_AXIS_TRIGGER_RIGHT or not Gamepad.heard(event):
		return
	if event.axis_value > 0.5 and not _trigger_pulled:
		_trigger_pulled = true
		_act()
	elif event.axis_value < 0.3:
		_trigger_pulled = false


## Whether input from this machine reaches him now (see `takes_input`, `input_blocked`).
func _listening() -> bool:
	return takes_input and not input_blocked


func _queue_jump() -> void:
	_stirred = true
	# (sat down or asleep, it only gets him up)
	if _is_resting():
		return
	_jump_buffer = jump_buffer_time


func _physics_process(delta: float) -> void:
	if is_limp:
		velocity = Vector3.ZERO
		# (his body may have gone over the edge of the world without him)
		if _rig.limp_position().y < kill_height:
			respawn()
		return
	_kick_rest -= delta
	_swim_rest -= delta
	var input := _read_move_input()
	var duck_now := _is_duck_held()
	_duck_pressed = duck_now and not _duck_was
	_duck_was = duck_now
	_since_jump += delta
	_track_spin(input, delta)
	if input.length() > 0.2 or _duck_pressed:
		_stirred = true
	_take_rest(delta)
	_stirred = false
	if _is_resting():
		# (sat down, he goes nowhere)
		input = Vector2.ZERO
		_jump_buffer = 0.0
	var strength := minf(input.length(), 1.0)
	_wish = _to_world(input)
	if stagger > 0.0:
		# Giddy, he does not go quite where he is told, nor all at once.
		stagger = maxf(stagger - delta / lerpf(0.55, 1.5, dizzy), 0.0)
		_wish = _wish.rotated(Vector3.UP, sin(_state_time * 5.3) * 0.9 * dizzy * stagger) * lerpf(1.0, 0.55, stagger)
		strength *= lerpf(1.0, 0.55, stagger)
	dizzy = clampf(dizzy + (dizzy_rates.x if is_spinning else -dizzy_rates.y) * delta, 0.0, 1.0)
	_jump_buffer -= delta
	_grab_cooldown -= delta
	_state_time += delta

	match state:
		State.HANG:
			_hang(delta)
		State.CLIMB:
			_climb()
		State.ROPE:
			_climb_rope(input, delta)
		State.LADDER:
			_climb_ladder(input, delta)
		State.SWIM:
			_swim(delta)
		_:
			_move(strength, delta)

	_use_hands(delta)
	_place_hands(delta)
	if global_position.y < kill_height:
		respawn()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Ordinary movement: on the ground, in the air, ducked or sliding.
func _move(strength: float, delta: float) -> void:
	var grounded := is_on_floor()
	_coyote = coyote_time if grounded else _coyote - delta
	_recover(grounded, delta)
	_push_timer -= delta
	is_pushing = _push_timer > 0.0

	_update_stance(grounded)
	_tumble(grounded, delta)
	_spin(grounded)
	if state == State.SLIDE:
		_slide(grounded, delta)
	else:
		_move_horizontal(strength, grounded, delta)
	_move_vertical(grounded, delta)

	var fall_speed := -velocity.y
	var before := global_position
	var stepped := false
	if _step_hold > 0.0 and grounded and velocity.y <= 0.0:
		# He is already up on the step. What is seen of him is still on its way
		# there (see _process), and he goes no further until it has arrived:
		# stairs are climbed no faster than he runs.
		_step_hold -= delta
		stepped = true
	else:
		_step_hold = 0.0
		stepped = grounded and velocity.y <= 0.0 and state == State.FREE and _try_step_up(delta)
		move_and_slide()
		_push_bodies(delta)
		_note_lean()

	var now_grounded := is_on_floor()
	if now_grounded and not _was_grounded:
		_jumping = false
		# (a step up or down leaves the ground for a frame; that is not a landing)
		if air_time > 0.1 or is_diving:
			_take_landing(maxf(fall_speed, 0.0))
			landed.emit(maxf(fall_speed, 0.0))
	elif now_grounded and _was_grounded and not stepped:
		_smooth_step_down(global_position.y - before.y, delta)
	elif not now_grounded and _was_grounded and not _jumping and velocity.y <= 0.0 and state == State.FREE and not is_diving and flip_progress >= 1.0:
		# Down stairs at a run he can outpace his own fall: the tread is gone
		# from under him before he has dropped onto it, and so is the next. If
		# there is ground a step below him, he is put on it.
		now_grounded = _keep_to_ground(delta)
	_was_grounded = now_grounded
	air_time = 0.0 if now_grounded else air_time + delta
	if now_grounded:
		_flung = false
		_rope_left = null

	if state == State.FREE and carried == null and _grab_cooldown <= 0.0 and not is_diving:
		_try_catch_ladder()
	_probe_stairs(now_grounded, delta)
	if state == State.FREE or state == State.SLIDE:
		_try_swim()
	# Hands are free and he is in the air: catch a rope, or a ledge he is falling past.
	_rope_rest -= delta
	if not now_grounded and state == State.FREE and carried == null and _grab_cooldown <= 0.0:
		if not _try_catch_rope() and velocity.y < 1.5:
			_try_catch_ledge()


func _process(delta: float) -> void:
	if is_limp:
		# The camera follows the body, wherever it tumbles.
		visual_position = _rig.limp_position() + Vector3.DOWN * 0.2
		return
	if _step_rate > 0.0:
		# Up a step: at the pace he was going, not in a rush that then tails off.
		if _step_delay > 0.0:
			_step_delay -= delta
		else:
			_visual_offset = _visual_offset.move_toward(Vector3.ZERO, _step_rate * delta)
			if _visual_offset.length_squared() < 0.000001:
				_step_rate = 0.0
	else:
		_visual_offset = _visual_offset.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) + _visual_offset

	var heading := _wish
	if state == State.HANG or state == State.CLIMB:
		heading = _ledge_direction
	elif state == State.SLIDE:
		heading = _slide_direction
	elif state == State.LADDER:
		heading = _ladder.facing()
	elif _kick_rest > 0.0:
		# (off a wall he comes round to face where he is going, whatever he is being told)
		heading = _kick_away
	elif swing_progress < 1.0:
		heading = Vector3.ZERO
	elif state == State.ROPE:
		# He faces along the swing (see _climb_rope).
		heading = _rope_heading.normalized() if _rope_heading.length() > 0.3 else Vector3.ZERO
	elif cast_progress < 1.0 or hook_out:
		# Throwing a hook, he turns to what he throws it at, and stays so while it is out.
		heading = Vector3.ZERO
		if is_instance_valid(_cast_at):
			heading = Vector3(_cast_at.global_position.x - global_position.x, 0.0, _cast_at.global_position.z - global_position.z)
			heading = heading.normalized() if heading.length() > 0.3 else Vector3.ZERO
	elif _picking and pickup_progress < 1.0:
		# He turns to what he is stooping for.
		heading = Vector3(pickup_point.x - global_position.x, 0.0, pickup_point.z - global_position.z)
		heading = heading.normalized() if heading.length() > 0.15 else Vector3.ZERO
	elif throw_progress < 1.0:
		# (and throws the way he was facing when he wound up)
		heading = Vector3.ZERO
	elif is_diving:
		heading = _dive_direction
	elif flip_progress < 1.0 or _is_resting() or dive_in > 0.0:
		# (going over backwards, or sat down, he faces the way he did)
		heading = Vector3.ZERO
	elif landing == Landing.ROLL and landing_progress < 1.0:
		heading = _landing_direction
	elif gun_raise > 0.3 and heading.length_squared() < 0.01:
		# Stood aiming, he turns to what he aims at.
		heading = Vector3(gun_aim.x, 0.0, gun_aim.z)
	elif heading.length_squared() < 0.01:
		heading = Vector3(velocity.x, 0.0, velocity.z)
		# (a shove backwards, as from a gun or a stagger, does not turn him round)
		if heading.length_squared() < 0.25 or stagger > 0.0 or gun_raise > 0.0:
			heading = Vector3.ZERO
	# Spinning, he turns at his own rate whatever the stick says: it comes up
	# quickly and dies away as he comes out of it.
	_spin_speed = move_toward(_spin_speed, spin_way * spin_rate * lerpf(1.0, 1.25, dizzy) if is_spinning else 0.0, (70.0 if is_spinning else 38.0) * delta)
	if absf(_spin_speed) > 0.3:
		facing_yaw = wrapf(facing_yaw + _spin_speed * delta, -PI, PI)
	elif heading != Vector3.ZERO:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-(turn_rate * 2.0 if _kick_rest > 0.0 else turn_rate) * lerpf(1.0, 0.45, stagger) * delta))

	# On a rope he hangs along it, not bolt upright beside it: what is seen of
	# him is tipped about his hands.
	var up := Vector3.UP
	if state == State.ROPE and is_instance_valid(_rope):
		# (along the line he hangs from, which is the rope above his hands; what
		# trails below them does not come into it)
		up = (_rope.point_at(_rope_at - 0.8) - _rope.point_at(_rope_at)).normalized()
		# (taking his weight from where he stood, he is not laid over all at once)
		up = Vector3.UP.slerp(up, 1.0 if _take_time < 0.0 else smoothstep(0.0, 0.5, _take_time)).normalized()
	_tilt = _tilt.lerp(up, 1.0 - exp(-(9.0 if state == State.ROPE else 10.0) * delta)).normalized()
	var turned := Basis(Vector3.UP, facing_yaw)
	_rig.global_position = visual_position
	if _tilt.y < 0.9999:
		turned = Basis(Quaternion(Vector3.UP, _tilt)) * turned
		_rig.global_position += (Vector3.UP - _tilt) * hang_height
	_rig.global_basis = turned
	if carried:
		# (what he has just picked up comes to his hand; it does not jump there)
		_carry_ease = minf(_carry_ease + delta * 9.0, 1.0)
		_place_carried()


## Puts what he carries in his hand. The rig calls this again when it has posed
## him, so that it is where his hand is this frame and not where it was last.
func _place_carried() -> void:
	if carried == null or is_limp:
		return
	var come := smoothstep(0.0, 1.0, _carry_ease)
	if gun_handling and carried.is_in_group(&"guns") and _rig.has_method(&"gun_transform"):
		# (a gun is held by its grip, and points where he points it)
		var held: Transform3D = _rig.gun_transform()
		carried.global_transform = Transform3D(carried.global_basis.orthonormalized().slerp(held.basis, come) if come < 1.0 else held.basis, _carry_from.lerp(held.origin, come))
		return
	carried.global_position = _carry_from.lerp(_rig.hand_position(), come)
	if carried.is_in_group(&"bats"):
		# (a bat is held by its handle, and points where his hands point it)
		carried.global_basis = _rig.bat_basis()
	elif carried.is_in_group(&"torches"):
		# (a torch is held upright a little way up its handle, its head tipped forward and away from him)
		var upright := Basis(Vector3.UP, facing_yaw) * Basis(Vector3.RIGHT, 0.3) * Basis(Vector3.BACK, 0.18)
		carried.global_basis = carried.global_basis.orthonormalized().slerp(upright, come) if come < 1.0 else upright
		carried.global_position -= carried.global_basis.y * 0.14 * come
	elif carried.is_in_group(&"grapples"):
		# (a hook's coil hangs from his hand, the way he faces)
		var level := Basis(Vector3.UP, facing_yaw)
		carried.global_basis = carried.global_basis.orthonormalized().slerp(level, come) if come < 1.0 else level


func respawn() -> void:
	if is_limp:
		_rig.recover()
		is_limp = false
	_drop_rope()
	_let_go()
	cast_progress = 1.0
	reel_progress = 1.0
	taut_progress = 1.0
	_flung = false
	_rope_left = null
	state = State.FREE
	is_ducking = false
	_run_time = 0.0
	is_sprinting = false
	_set_height(stand_height)
	global_transform = _spawn
	velocity = Vector3.ZERO
	landing_progress = 1.0
	is_scrambling = false
	is_crawling = false
	is_underwater = false
	swing_progress = 1.0
	_ladder = null
	ladder_off = 0.0
	_ladder_leaving = 0.0
	pickup_progress = 1.0
	throw_progress = 1.0
	_picking = null
	_step_hold = 0.0
	_step_rate = 0.0
	_jumping = false
	# (nothing he was in the middle of comes with him)
	_jump_buffer = 0.0
	_coyote = 0.0
	_grab_cooldown = 0.0
	_kick_rest = 0.0
	_swim_rest = 0.0
	_push_timer = 0.0
	is_pushing = false
	_lean_timer = 0.0
	air_time = 0.0
	_was_grounded = false
	on_stairs = 0.0
	_stairs_seen = 0.0
	swim_clear = 1.0
	hand_reach = 0.0
	_clear_moves()
	_reset_visuals()
	respawned.emit()


## Whatever he was in the middle of (a dive, a back tuck, a spin, a rest, taking
## aim) is over, and forgotten.
func _clear_moves() -> void:
	is_diving = false
	dive_roll = false
	dive_in = 0.0
	flip_progress = 1.0
	is_spinning = false
	_spin_turned = 0.0
	_spin_speed = 0.0
	stagger = 0.0
	dizzy = 0.0
	rest = Rest.UP
	sit_progress = 0.0
	lie_progress = 0.0
	yawn_progress = 1.0
	rub_progress = 1.0
	startled = 0.0
	_idle_time = 0.0
	_duck_still = 0.0
	_sat_time = 0.0
	_sit_for = 0.0
	wade = 0.0
	gun_raise = 0.0
	_fire_wanted = false
	_aim_hold = 0.0
	_since_jump = 10.0


## Puts the body somewhere else at once, without what is seen of it jumping:
## that is left where it was, and eases across (see _process).
func _put(at: Vector3) -> void:
	var by := at - global_position
	_visual_offset -= by
	# (what is drawn is between where he was and where he is; both have moved)
	_curr_pos += by
	global_position = at


func _reset_visuals() -> void:
	_prev_pos = global_position
	_curr_pos = global_position
	_visual_offset = Vector3.ZERO
	visual_position = global_position
	_tilt = Vector3.UP
	_rig.global_position = global_position
	_rig.rotation = Vector3(0.0, facing_yaw, 0.0)


func _read_move_input() -> Vector2:
	# (while input is blocked, or he is not steered from here, nothing is passed on to him)
	if not _listening():
		return Vector2.ZERO
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if Input.is_action_pressed(&"walk"):
		input *= run_threshold
	if _touch and _touch.move.length_squared() > input.length_squared():
		input = _touch.move
	return input


## Maps stick input onto the ground plane relative to the active camera.
func _to_world(input: Vector2) -> Vector3:
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	var camera := get_viewport().get_camera_3d()
	if camera:
		var view := camera.global_basis
		right = Vector3(view.x.x, 0.0, view.x.z).normalized()
		forward = Vector3(-view.z.x, 0.0, -view.z.z)
		# Looking straight down: the top of the screen is forward instead.
		if forward.length_squared() < 0.001:
			forward = Vector3(view.y.x, 0.0, view.y.z)
		forward = forward.normalized()
	var direction := right * input.x - forward * input.y
	if move_mode == MoveMode.SIDE_SCROLL:
		direction = Vector3(direction.x, 0.0, 0.0)
	return direction.limit_length(1.0)


func _move_horizontal(strength: float, grounded: bool, delta: float) -> void:
	var target_speed := 0.0
	var current := Vector3(velocity.x, 0.0, velocity.z)
	# Running flat out with nothing in his way for a moment, he sprints. (In
	# the air he neither gets there nor loses it.)
	var called := _is_sprint_held() and strength > run_threshold
	var flat_out := (strength > 0.95 and auto_sprint or called) and not is_pushing and not is_ducking and landing_progress >= 1.0 and (current.length() > run_speed * 0.85 or called) and wade < 0.25 and not is_spinning and gun_raise < 0.5
	if not flat_out:
		_run_time = 0.0
	elif grounded:
		_run_time += delta
	is_sprinting = _run_time > sprint_delay or (called and flat_out)
	if strength > 0.0:
		target_speed = lerpf(walk_speed, run_speed, smoothstep(run_threshold, run_threshold + 0.2, strength))
		if is_sprinting:
			target_speed = sprint_speed
		if is_pushing:
			target_speed = minf(target_speed, push_speed)
		if is_ducking:
			target_speed = minf(target_speed, crawl_speed if is_crawling else crouch_speed)
		if swing_progress < 1.0:
			target_speed *= 0.25
		# Stooping for something he all but stops; winding up to throw he slows to set himself.
		if pickup_progress < 1.0:
			target_speed *= 0.2
		elif throw_progress < 1.0:
			target_speed *= 0.3
		# Throwing a hook, and while it is out on its line, he stands his ground.
		if cast_progress < 1.0 or hook_out:
			target_speed *= 0.12
		# Wading, the water holds him back, more the deeper it is. A gun brought
		# up to his shoulder is not run about with.
		target_speed *= lerpf(1.0, 0.5, smoothstep(0.12, 0.85, wade))
		if gun_raise > 0.5 and carried and carried.get(&"two_handed"):
			target_speed = minf(target_speed, walk_speed * 1.25)
	var target := _wish.normalized() * target_speed

	var rate := acceleration
	if is_diving or flip_progress < 1.0:
		# Thrown, he goes where he was thrown.
		if grounded and flip_progress < 1.0:
			current = current.move_toward(Vector3.ZERO, deceleration * delta)
			velocity.x = current.x
			velocity.z = current.z
		return
	if is_spinning or absf(_spin_speed) > 4.0:
		# Spinning, he drifts on the way he was going, and slows.
		current = current.limit_length(run_speed * 0.7).move_toward(_wish * walk_speed * 0.6, 3.2 * delta)
		velocity.x = current.x
		velocity.z = current.z
		return
	if not grounded:
		# Keep momentum in the air when the stick is let go.
		rate = air_acceleration if strength > 0.0 else air_acceleration * 0.25
		if _flung and current.length() > target_speed and _wish.dot(current) >= 0.0:
			# Thrown off a rope he keeps what it gave him, which may be more than
			# he can run at: the stick turns it, and only pulling back checks it.
			var speed := maxf(current.length() - 1.2 * delta, target_speed)
			target = (current.normalized() + _wish * 1.6 * delta).normalized() * speed
			rate = air_acceleration
	elif strength == 0.0:
		rate = deceleration
	elif current.dot(target) < 0.0:
		rate = turn_acceleration
	elif is_sprinting:
		# He works up to it. But it is only his speed that is slow to come: his
		# feet have as good a hold of the ground as ever, and he turns as surely.
		# (called for, he throws himself into it: twice as hard)
		target = target.normalized() * clampf(current.length() + acceleration * (0.5 if _is_sprint_held() else 0.25) * delta, run_speed, sprint_speed)
	if landing_progress < 1.0 and grounded:
		# A hard landing has him for a moment. On three points he is brought
		# up short, and what is left carries him forward onto his hands; a
		# stumble and a roll carry him on the way he was going, and only a
		# stumble can be steered at all, until it too goes over.
		match landing:
			Landing.THREE_POINT:
				target *= smoothstep(0.75, 1.0, landing_progress)
				rate = deceleration * 0.5
			Landing.SPRAWL:
				if is_scrambling:
					# His feet are going while he is still down, and he is
					# off his hands and running before he is properly up.
					target *= smoothstep(SCRAMBLE.x, 0.6, landing_progress)
					rate = acceleration * 0.7
				elif landing_progress < SPRAWL_FALLS.y:
					# His feet stay where they came down and the rest of him
					# goes on over them: he falls his own length forward.
					var falling := landing_progress > SPRAWL_FALLS.x
					target = _landing_direction * (SPRAWL_THROW / ((SPRAWL_FALLS.y - SPRAWL_FALLS.x) * landing_times.y) if falling else 0.0)
					rate = acceleration * 2.0
				else:
					target *= smoothstep(0.88, 1.0, landing_progress)
					rate = deceleration
			Landing.STUMBLE:
				var heading := (_landing_direction + _wish * 0.4 * (1.0 - smoothstep(0.3, 0.4, landing_progress))).normalized()
				target = heading * lerpf(stumble_speed, roll_speed * 0.8, smoothstep(0.3, 0.5, landing_progress)) * lerpf(1.0, 0.7, smoothstep(0.75, 1.0, landing_progress))
				rate = acceleration
			Landing.ROLL:
				# (out of a dive he keeps what he had, and comes up running)
				target = _landing_direction * _roll_carry * lerpf(1.0, 0.92 if dive_roll else 0.7, smoothstep(0.5, 1.0, landing_progress))
				rate = acceleration * 2.0
	current = current.move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z

	if move_mode == MoveMode.SIDE_SCROLL:
		# Ease back onto the lane if something knocked us off it.
		velocity.z = (_spawn.origin.z - global_position.z) * 10.0


func _move_vertical(grounded: bool, delta: float) -> void:
	# No jumping out from under something too low to stand in.
	var can_rise := state == State.FREE and (not is_ducking or _has_headroom(stand_height))
	if _jump_buffer > 0.0 and _coyote > 0.0 and not _is_recovering() and can_rise and not is_spinning:
		# Out of a duck (sneaking, or crouched where he stands) it is a back
		# tuck, if there is the height for one and his hands are not full of
		# bat or gun. He goes up and over and comes down about where he was.
		var tucking := flip_enabled and is_ducking and not is_crawling and grounded and _has_headroom(stand_height + jump_height * flip_lift * 0.9)
		if carried and (carried.is_in_group(&"bats") or carried.is_in_group(&"guns")):
			tucking = false
		is_ducking = false
		_set_height(stand_height)
		velocity.y = _jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		_since_jump = 0.0
		if tucking:
			var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
			# (sneaking forward as he goes, that is checked: it is still backwards
			# he turns, and he lands a little short of where he would have got to)
			velocity = Vector3(velocity.x, 0.0, velocity.z) * 0.35 - facing * flip_drift + Vector3.UP * _jump_velocity * sqrt(flip_lift)
			flip_progress = 0.0
			# (it is not cut short by letting go of jump, and he catches at nothing on the way)
			_jumping = false
			_since_jump = 10.0
			_grab_cooldown = flip_time
			flipped.emit()
		jumped.emit()
	elif not grounded and _jump_buffer > 0.0 and state == State.FREE and air_time > 0.12 and _kick_rest <= 0.0 and not is_diving and flip_progress >= 1.0 and _kick_off_wall():
		_jump_buffer = 0.0
		_jumping = true
		jumped.emit()
		kicked_off.emit()
	elif not grounded:
		var gravity := _gravity
		if is_diving:
			gravity *= dive_gravity_scale
		elif velocity.y < 0.0:
			gravity *= fall_gravity_scale
		elif _jumping and not _is_jump_held():
			gravity *= jump_cut_gravity_scale
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)


## In the air and up against a wall: a foot goes to it and he springs away,
## turned to face where he is going. He can go from wall to wall like this.
func _kick_off_wall() -> bool:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var hit := KinematicCollision3D.new()
	var found := false
	# (the wall he is steering at, or flying at, or facing)
	for toward: Vector3 in [_wish, flat, Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))]:
		if toward.length_squared() > 0.04 and test_move(global_transform, toward.normalized() * 0.3, hit) and absf(hit.get_normal().y) < 0.3:
			found = true
			break
	if not found:
		return false
	var away := Vector3(hit.get_normal().x, 0.0, hit.get_normal().z).normalized()
	velocity = away * run_speed * wall_kick.x + Vector3.UP * _jump_velocity * wall_kick.y
	# (he comes round to face that way in a moment: see _process. And he is in
	# the air throughout: this is not a landing, even for an instant.)
	_kick_away = away
	_kick_rest = 0.22
	_grab_cooldown = 0.25
	return true


## Decides how he takes a landing at `speed`, and starts it.
func _take_landing(speed: float) -> void:
	landing = Landing.SOFT
	landing_progress = 1.0
	is_scrambling = false
	if speed > landing_speeds.w:
		landing = Landing.ROLL
	elif speed > landing_speeds.z:
		landing = Landing.STUMBLE
	elif speed > landing_speeds.y:
		landing = Landing.SPRAWL
	elif speed > landing_speeds.x:
		landing = Landing.THREE_POINT
	# Out of a dive it is his hands that come down first, and he goes over in a
	# roll however hard that is.
	dive_roll = is_diving
	_roll_carry = roll_speed
	if is_diving:
		is_diving = false
		landing = Landing.ROLL
		_roll_carry = clampf(Vector2(velocity.x, velocity.z).length(), roll_speed, sprint_speed * 1.1)
	if flip_progress < 1.0:
		# (a back tuck comes down on his feet, or he has not got round and it is a sprawl)
		landing = Landing.SOFT if flip_progress > 0.7 or speed <= landing_speeds.y else landing
	if landing == Landing.SOFT:
		return
	landing_progress = 0.0
	_landing_time = 0.0
	# He goes the way he was moving, or failing that the way he faces.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_landing_direction = flat.normalized() if flat.length() > 1.0 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if state == State.SLIDE:
		state = State.FREE
	if landing == Landing.ROLL:
		is_ducking = true
		# (a dive that has got him in under something stays as low as it was)
		if not dive_roll or _has_headroom(crouch_height):
			_set_height(crouch_height)


## Carries a hard landing through to its end. Going off an edge cuts it short.
func _recover(grounded: bool, delta: float) -> void:
	if landing_progress >= 1.0:
		dive_roll = false
		return
	# Down on his front, he gets up; unless he is still being told to go, when
	# he scrambles off on all fours and is running before he is upright, which is quicker.
	if landing == Landing.SPRAWL and not is_scrambling and _wish.length() > 0.5:
		is_scrambling = landing_progress > SCRAMBLE.x and landing_progress < SCRAMBLE.y
	_landing_time += delta * (2.3 if is_scrambling else 1.0)
	landing_progress = minf(_landing_time / landing_times[landing - 1], 1.0)
	if not grounded and air_time > 0.15:
		landing_progress = 1.0
	if landing_progress >= 1.0:
		is_scrambling = false


## Too taken up with a landing to jump or slide.
func _is_recovering() -> bool:
	return landing_progress < 0.8


func _is_jump_held() -> bool:
	return _listening() and (Input.is_action_pressed(&"jump") or (_touch != null and _touch.jump_held))


## Sprint: Shift, a gamepad's LB or LT, or the touch controls' sprint (held, toggled, or the stick pushed past its rim).
func _is_sprint_held() -> bool:
	return _listening() and (Input.is_action_pressed(&"sprint") or (_touch != null and _touch.sprint_held))


func _is_duck_held() -> bool:
	return _listening() and (Input.is_action_pressed(&"duck") or (_touch != null and _touch.duck_held))


func _is_act_held() -> bool:
	return _listening() and (Input.is_action_pressed(&"act") or _trigger_pulled or (_touch != null and _touch.act_held))


# --- Diving, the back tuck and spinning ---

## Starts a dive, if duck has just been pressed soon enough after a running
## jump, and carries a dive or a back tuck through.
func _tumble(grounded: bool, delta: float) -> void:
	if flip_progress < 1.0:
		# (brought down early, onto something, he finishes it in a hurry)
		flip_progress = minf(flip_progress + delta / flip_time * (3.0 if grounded and flip_progress > 0.1 else 1.0), 1.0)
	if is_diving:
		dive_time += delta
		if state != State.FREE:
			is_diving = false
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	# Duck held from before the jump is not it (that is a slide, or a duck, and
	# out of a duck the jump is a back tuck): it has to be pressed in the air.
	if not dive_enabled or not _duck_pressed or grounded or not _jumping or _since_jump > dive_window or state != State.FREE:
		return
	if carried or flip_progress < 1.0 or _kick_rest > 0.0 or flat.length() < dive_min_speed or flat.normalized().dot(facing) < 0.5:
		return
	is_diving = true
	dive_time = 0.0
	_dive_direction = flat.normalized()
	velocity = _dive_direction * maxf(flat.length() * 1.1, dive_speed) + Vector3.UP * minf(velocity.y, _jump_velocity * dive_lift)
	# (it is not a jump any longer, to be cut short by letting go)
	_jumping = false
	_set_height(slide_height)
	dived.emit()


## Follows the stick round. What is kept is how far its direction has turned
## one way lately; turning the other way undoes it, and it fades by itself, so
## a quick turn about, or running in a ring, never amounts to much.
func _track_spin(input: Vector2, delta: float) -> void:
	_spin_gap += delta
	if input.length() >= spin_deflection:
		var angle := atan2(input.x, input.y)
		# (keys are let go of between one and the next: a short gap is not a stop)
		if _spin_gap < 0.13:
			var turned := angle_difference(_spin_angle, angle)
			# A quarter turn at once is a key; more than that is the stick thrown
			# across, which is a change of mind and not a turn.
			if absf(turned) < 1.75:
				_spin_turned += turned
			else:
				_spin_turned = 0.0
		_spin_angle = angle
		_spin_gap = 0.0
	_spin_turned *= exp(-delta / spin_memory)


## Sets him spinning when the stick has been whipped right round, and stops him
## when it no longer is. Coming out of it he staggers, the more the giddier he
## is; and giddy enough, he sits down.
func _spin(grounded: bool) -> void:
	var able := grounded and state == State.FREE and not is_ducking and landing_progress >= 1.0 and not is_pushing and gun_raise < 0.2
	able = able and pickup_progress >= 1.0 and throw_progress >= 1.0 and swing_progress >= 1.0 and flip_progress >= 1.0 and not _is_resting()
	if not is_spinning:
		if spin_enabled and able and absf(_spin_turned) >= spin_start:
			is_spinning = true
			spin_way = signf(_spin_turned)
			stagger = 0.0
		return
	if able and absf(_spin_turned) > spin_stop and signf(_spin_turned) == spin_way:
		return
	is_spinning = false
	_spin_turned = 0.0
	if not able:
		return
	stagger = 1.0
	# (the step that saves him: out to the side he was turning towards)
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var aside := Vector3(facing.z, 0.0, -facing.x) * spin_way
	velocity += (aside * 0.8 + facing * 0.3) * lerpf(0.9, 2.2, dizzy)
	if dizzy > 0.94:
		sit()
		_sit_for = 1.8
		dizzy = 0.6


# --- Sitting down and sleeping ---

## Sits him down where he is. He stays there until he is stirred (any input) or told to `wake`.
func sit() -> void:
	if is_limp or state != State.FREE or not is_on_floor():
		return
	rest = Rest.SITTING
	_sit_for = 0.0
	_begin_rest()


## Sends him to sleep: he sits down, then lies down curled on his side. Any
## input wakes him, and so does anything in the group `pursuers` giving chase.
func sleep() -> void:
	if is_limp or state != State.FREE or not is_on_floor():
		return
	rest = Rest.ASLEEP
	_sit_for = 0.0
	_begin_rest()


## Gets him up, from sitting or from sleep: `with_a_start` in a hurry.
func wake(with_a_start := false) -> void:
	if rest == Rest.UP:
		return
	var was_asleep := lie_progress > 0.5
	rest = Rest.UP
	_sit_for = 0.0
	_idle_time = 0.0
	_duck_still = 0.0
	startled = 1.0 if with_a_start else 0.0
	if was_asleep:
		woke.emit(with_a_start)


## The same as `wake()`, for one who was only sitting.
func stand_up() -> void:
	wake()


func is_asleep() -> bool:
	return lie_progress >= 1.0


func _begin_rest() -> void:
	_let_go()
	_sat_time = 0.0
	_idle_time = 0.0
	yawn_progress = 1.0
	is_ducking = false
	is_crawling = false
	is_sprinting = false
	_run_time = 0.0
	_fire_wanted = false


## Sat down, lying down, or on his way to or from either: he takes no steering.
func _is_resting() -> bool:
	return rest != Rest.UP or sit_progress > 0.0


## Whether anything in the group `pursuers` is giving chase.
func _is_hunted(delta: float) -> bool:
	_hunt_check -= delta
	if _hunt_check <= 0.0:
		_hunt_check = 0.25
		_hunted = false
		for pursuer: Node in get_tree().get_nodes_in_group(&"pursuers"):
			if pursuer != self and pursuer.get(&"chasing"):
				_hunted = true
				break
	return _hunted


## Resting: decides when he sits and sleeps by himself, wakes him when he is
## stirred, and carries the sitting down, lying down and getting up through.
func _take_rest(delta: float) -> void:
	var hunted := _is_hunted(delta)
	var settled := state == State.FREE and is_on_floor() and not is_limp and landing_progress >= 1.0 and flip_progress >= 1.0
	settled = settled and pickup_progress >= 1.0 and throw_progress >= 1.0 and swing_progress >= 1.0 and not is_spinning and stagger <= 0.0 and gun_raise <= 0.0
	startled = maxf(startled - delta / 1.2, 0.0)
	if rest != Rest.UP:
		# Stirred, he gets up; hunted, at once. Off his feet (the ground gone
		# from under him, or water come up round him), he is simply up.
		if not settled and (state != State.FREE or is_limp):
			_end_rest()
			return
		if hunted:
			wake(true)
		elif _stirred or (_sit_for > 0.0 and _sat_time > _sit_for):
			wake()
	elif sit_progress <= 0.0:
		# Left alone long enough he yawns and stretches, and then settles down.
		# Duck held while he stands still does it sooner: sat, then asleep.
		var still := settled and not hunted and Vector2(velocity.x, velocity.z).length() < 0.2
		_idle_time = _idle_time + delta if still and not _stirred and not _is_duck_held() and not is_ducking else 0.0
		_duck_still = _duck_still + delta if still and _is_duck_held() and is_ducking and not is_crawling and _wish.length_squared() < 0.01 else 0.0
		if yawn_progress < 1.0:
			yawn_progress = minf(yawn_progress + delta / YAWN_TAKES, 1.0) if _idle_time > 0.0 else 1.0
		if rest_enabled and sleep_after > 0.0 and carried == null:
			if _idle_time > maxf(sleep_after - YAWN_TAKES, 0.0) and yawn_progress >= 1.0 and _idle_time < sleep_after - YAWN_TAKES * 0.5:
				yawn_progress = 0.0001
			if _idle_time >= sleep_after:
				sleep()
		if rest_enabled and sit_hold > 0.0 and _duck_still >= sit_hold:
			sit()
	if rest == Rest.SITTING and sit_hold > 0.0 and _is_duck_held() and _duck_still > 0.0:
		# (still held: he lies down)
		_duck_still += delta
		if _duck_still >= sit_hold * 2.0 + sit_time:
			rest = Rest.ASLEEP
	elif rest == Rest.SITTING:
		_duck_still = 0.0

	if not _is_resting():
		return
	var hurry := 2.6 if startled > 0.0 else 1.0
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	_set_height(crouch_height)
	match rest:
		Rest.UP:
			# Up off his side; a rub of his eyes, if he was asleep and is in no hurry; and onto his feet.
			if lie_progress > 0.0:
				lie_progress = maxf(lie_progress - delta / (lie_time * 0.75) * hurry, 0.0)
				if lie_progress < 0.3 and rub_progress >= 1.0 and startled <= 0.0 and _sat_time > 0.0:
					rub_progress = 0.0
					_sat_time = 0.0
			elif rub_progress < 0.85 and startled <= 0.0:
				pass
			else:
				sit_progress = maxf(sit_progress - delta / (sit_time * 0.85) * hurry, 0.0)
				if sit_progress <= 0.0:
					_end_rest()
		Rest.SITTING:
			_sat_time += delta
			lie_progress = maxf(lie_progress - delta / (lie_time * 0.75), 0.0)
			if lie_progress <= 0.0:
				sit_progress = minf(sit_progress + delta / sit_time, 1.0)
		Rest.ASLEEP:
			sit_progress = minf(sit_progress + delta / sit_time, 1.0)
			if sit_progress >= 1.0:
				_sat_time += delta
				if _sat_time > SIT_PAUSE or lie_progress > 0.0:
					var before := lie_progress
					lie_progress = minf(lie_progress + delta / lie_time, 1.0)
					if before < 1.0 and lie_progress >= 1.0:
						slept.emit()
	if rub_progress < 1.0:
		rub_progress = minf(rub_progress + delta / RUB_TAKES * (3.0 if startled > 0.0 else 1.0), 1.0)


## He is on his feet again (or off them altogether): nothing of resting is left.
func _end_rest() -> void:
	rest = Rest.UP
	sit_progress = 0.0
	lie_progress = 0.0
	rub_progress = 1.0
	yawn_progress = 1.0
	_sat_time = 0.0
	_sit_for = 0.0
	_idle_time = 0.0
	_duck_still = 0.0
	# (under something too low to stand in, he comes up into a duck)
	if state == State.FREE:
		is_ducking = not _has_headroom(stand_height)
		if not is_ducking:
			_set_height(stand_height)


# --- Ducking and sliding ---

## Decides whether he is standing, ducked or starting a slide, and sizes the
## collider to match. He stays down under anything too low to stand in.
func _update_stance(grounded: bool) -> void:
	if state == State.SLIDE:
		return
	# Rolling, he is as low as a duck, and he comes up out of it as out of one.
	if landing == Landing.ROLL and landing_progress < 1.0:
		return
	# (in a dive he is as low as a slide; sat down or asleep, as low as a duck)
	if is_diving or _is_resting():
		return
	# (down on a knee or on his front he is low enough, and busy)
	var duck := _is_duck_held() and landing_progress >= 1.0
	var speed := Vector2(velocity.x, velocity.z).length()
	if grounded and duck and not is_ducking and speed >= slide_min_speed and not _is_recovering() and not is_spinning:
		state = State.SLIDE
		_state_time = 0.0
		_slide_direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
		_set_height(slide_height)
		return
	if is_ducking:
		is_ducking = (duck and grounded) or not _has_headroom(stand_height)
	else:
		is_ducking = duck and grounded
	if not is_ducking:
		_set_height(stand_height)
	elif _capsule.height > slide_height and _wish.length_squared() > 0.04 and test_move(global_transform, _wish.normalized() * 0.08):
		# Sneaking up against something too low to sneak under: down onto his
		# hands and knees, if that will get him under it.
		_set_height(slide_height)
		if test_move(global_transform, _wish.normalized() * 0.08):
			_set_height(crouch_height)
	elif _capsule.height > crouch_height or _has_headroom(crouch_height):
		_set_height(crouch_height)
	# (otherwise he is under something lower still, and stays that low)
	is_crawling = is_ducking and _capsule.height < crouch_height - 0.01


## Carried by momentum, low enough to pass under what a duck will not.
func _slide(grounded: bool, delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() - slide_friction * delta
	if speed < slide_end_speed or is_on_wall() or (not grounded and _state_time > 0.15):
		state = State.FREE
		# Come up into a duck; the next step stands him if there is room.
		is_ducking = true
		return
	velocity.x = _slide_direction.x * speed
	velocity.z = _slide_direction.z * speed


func _set_height(height: float) -> void:
	if is_equal_approx(_capsule.height, height):
		return
	_capsule.height = height
	_collider.position.y = height * 0.5


## Whether the collider could be `height` tall here without hitting anything.
func _has_headroom(height: float) -> bool:
	if height <= _capsule.height:
		return true
	return not test_move(global_transform, Vector3.UP * (height - _capsule.height))


# --- Ledges ---

## Catches the top edge of whatever he is moving into, if it is within reach of
## his hands and there is room to stand on it. (`near` is how far off it may be.)
func _try_catch_ledge(near := 0.25) -> bool:
	if _wish.length_squared() < 0.04:
		return false
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, _wish.normalized() * near, hit) or absf(hit.get_normal().y) > 0.3:
		return false
	var into := Vector3(-hit.get_normal().x, 0.0, -hit.get_normal().z).normalized()
	if _wish.normalized().dot(into) < 0.4:
		return false

	# Find the top, looking down from as high as he can reach just past the face.
	var at_face := global_position + hit.get_travel()
	# The corner itself is straight ahead of him, as far off as what he ran into.
	var to_face := clampf((hit.get_position() - at_face).dot(into), _radius - 0.03, _radius + 0.06)
	var over := at_face + into * (_radius + 0.15)
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(over.x, global_position.y + ledge_reach.y, over.z),
		Vector3(over.x, global_position.y + ledge_reach.x, over.z), 1)
	var top := get_world_3d().direct_space_state.intersect_ray(query)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var ledge_y: float = (top.position as Vector3).y
	var standing := Transform3D(Basis.IDENTITY, Vector3(over.x, ledge_y + 0.03, over.z))
	if test_move(standing, Vector3.UP * 0.01, null, 0.001, true):
		return false

	# Hang below it, but never lower than the ground allows.
	var drop := ledge_y - hang_height - at_face.y
	if drop < 0.0 and test_move(Transform3D(Basis.IDENTITY, at_face), Vector3(0.0, drop, 0.0), hit):
		drop = hit.get_travel().y
	var hang := at_face + Vector3(0.0, drop, 0.0)
	_put(hang)
	velocity = Vector3.ZERO
	_ledge_top = Vector3(over.x, ledge_y, over.z)
	_ledge_direction = into
	ledge_point = Vector3(at_face.x + into.x * to_face, ledge_y, at_face.z + into.z * to_face)
	shimmy_travel = 0.0
	_find_wall()
	_grips[0] = _grip_home(0)
	_grips[1] = _grip_home(1)
	_engage()
	state = State.HANG
	_state_time = 0.0
	return true


## Taking hold of something (a ledge, a rope, a ladder) or going into water:
## whatever he was in the middle of on his feet is over.
func _engage() -> void:
	_jumping = false
	_flung = false
	_jump_buffer = 0.0
	landing_progress = 1.0
	is_scrambling = false
	is_ducking = false
	is_crawling = false
	is_sprinting = false
	_run_time = 0.0
	_step_hold = 0.0
	is_diving = false
	dive_roll = false
	flip_progress = 1.0
	is_spinning = false
	stagger = 0.0
	if _is_resting():
		_end_rest()
	if pickup_progress < 1.0 and carried == null:
		pickup_progress = 1.0
		_picking = null
	_set_height(stand_height)


## Hanging: he stays there until jump climbs up, or pulling away (or duck) drops
## him. Left and right work him along the ledge, hand over hand.
func _hang(delta: float) -> void:
	velocity = Vector3.ZERO
	var toward := _wish.dot(_ledge_direction)
	var sideways := _wish.dot(_ledge_left())
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		# (he may have shimmied in under something)
		if test_move(Transform3D(Basis.IDENTITY, _ledge_top + Vector3.UP * 0.03), Vector3.UP * 0.01, null, 0.001, true):
			return
		_climb_from = global_position
		climb_progress = 0.0
		_grips[0] = _grip_home(0)
		_grips[1] = _grip_home(1)
		state = State.CLIMB
		_state_time = 0.0
	elif (_is_duck_held() or toward < -0.4) and _state_time > 0.15:
		state = State.FREE
		_grab_cooldown = 0.5
	elif absf(sideways) > 0.4:
		_shimmy(signf(sideways), delta)
	_step_grips(delta)


func _ledge_left() -> Vector3:
	return Vector3(_ledge_direction.z, 0.0, -_ledge_direction.x)


## Moves him a little way along the ledge, `direction` being 1 for his left, if
## it goes on that way: the same top, the same face, and nothing in the way.
func _shimmy(direction: float, delta: float) -> void:
	var step := _ledge_left() * direction * shimmy_speed * delta
	if test_move(global_transform, step):
		return
	var space := get_world_3d().direct_space_state
	# Look where his leading hand would have to go, not just where his chest is.
	var ahead := ledge_point + step + _ledge_left() * direction * 0.2
	var over := ahead + _ledge_direction * 0.1
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + Vector3.UP * 0.2, over + Vector3.DOWN * 0.2, 1))
	if top.is_empty() or (top.normal as Vector3).y < 0.7 or absf((top.position as Vector3).y - ledge_point.y) > 0.04:
		return
	var under := ahead - _ledge_direction * 0.15 + Vector3.DOWN * 0.05
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(under, under + _ledge_direction * 0.3, 1))
	if face.is_empty() or absf(under.distance_to(face.position) - 0.15) > 0.04:
		return
	global_position += step
	ledge_point += step
	_ledge_top += step
	shimmy_travel += direction * step.length()
	# (he is not moved by it, but the rig reads how fast he is going from it)
	velocity = step / delta
	_find_wall()


## Whether there is wall under the ledge to put a foot against.
func _find_wall() -> void:
	var from := ledge_point - _ledge_direction * 0.2 + Vector3.DOWN * 0.8
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _ledge_direction * 0.3, 1))
	ledge_wall = not hit.is_empty() and absf(from.distance_to(hit.position) - 0.2) < 0.05


## Where a hand would hold the ledge if he had just caught it here.
func _grip_home(hand: int) -> Vector3:
	return ledge_point + _ledge_left() * (0.15 if hand == 0 else -0.15)


## His hands stay where they have hold while his body moves along under them;
## when one is left too far behind, or is in the other's way, it lets go and
## takes a new hold further on. Never both at once.
func _step_grips(delta: float) -> void:
	_grip_rest -= delta
	if _grip_rest > 0.0:
		return
	var left := _ledge_left()
	var worst := -1
	var furthest := 0.09
	for hand in 2:
		var behind := absf((_grip_home(hand) - _grips[hand]).dot(left))
		if behind > furthest:
			furthest = behind
			worst = hand
	if worst >= 0:
		# (a little past where it belongs, so it is not at once behind again)
		var home := _grip_home(worst)
		_grips[worst] = home + left * signf((home - _grips[worst]).dot(left)) * 0.07
		_grip_rest = 0.2


## Pulling up: first straight up the face, then forward onto the top.
func _climb() -> void:
	# (he does not take it at one pace: getting from a knee on the top to both
	# feet under him is the awkward part, and has the most time)
	var through := clampf(_state_time / climb_time, 0.0, 1.0)
	if through < 0.5:
		climb_progress = through * 1.2
	elif through < 0.82:
		climb_progress = lerpf(0.6, 0.8, (through - 0.5) / 0.32)
	else:
		climb_progress = lerpf(0.8, 1.0, (through - 0.82) / 0.18)
	var rise := smoothstep(0.0, 0.6, climb_progress)
	var reach := smoothstep(0.58, 1.0, climb_progress)
	global_position = Vector3(
		lerpf(_climb_from.x, _ledge_top.x, reach),
		lerpf(_climb_from.y, _ledge_top.y + 0.02, rise),
		lerpf(_climb_from.z, _ledge_top.z, reach))
	if climb_progress >= 1.0:
		velocity = Vector3.ZERO
		state = State.FREE
		_was_grounded = true
		_coyote = coyote_time


# --- Ropes ---

## Catches a rope that is within his reach: close by whatever he is doing, and
## at arm's length if he is going towards it or reaching for it.
func _try_catch_rope() -> bool:
	var chest := global_position + Vector3.UP * 1.0
	var hands := global_position + Vector3.UP * hang_height
	var going := Vector3(velocity.x, 0.0, velocity.z)
	going = going.normalized() if going.length() > 0.5 else Vector3.ZERO
	for rope: Rope in get_tree().get_nodes_in_group(&"ropes"):
		if rope == _rope_left and _rope_rest > 0.0:
			continue
		var at := rope.nearest(hands)
		var away := rope.point_at(at) - hands
		var distance := minf(away.length(), rope.distance_to(chest))
		if distance > rope_reach.y:
			continue
		var level := Vector3(away.x, 0.0, away.z)
		var towards := maxf(going.dot(level.normalized()), _wish.dot(level.normalized())) if level.length() > 0.05 else 1.0
		if distance > rope_reach.x and towards < 0.35:
			continue
		# (he brings his speed to it, and it swings with him)
		_hold_rope(rope, at, velocity)
		return true
	return false


## Takes hold of `rope` with his hands `at` down it, bringing `speed` to it.
func _hold_rope(rope: Rope, at: float, speed: Vector3) -> void:
	_rope = rope
	_rope_at = clampf(at, 0.4, rope.length - 0.1)
	rope_travel = 0.0
	# (he has it between his knees and his feet as well as in his hands)
	rope.held_below = 0.9
	rope.load_at = _rope_at
	rope.push(_rope_at, speed - rope.velocity_at(_rope_at))
	var level := Vector3(speed.x, 0.0, speed.z)
	_rope_heading = level.normalized() if level.length() > 1.0 else Vector3.ZERO
	_rope_act = false
	_take_time = -1.0
	_rope_new = true
	velocity = Vector3.ZERO
	_engage()
	state = State.ROPE
	_state_time = 0.0


## Puts him on a rope that a grappling hook has just hung for him: its line is
## in his hands `at` down it. If he is stood on the ground it lifts him off it
## as it takes his weight, and he swings from where he stood. False if he is in
## no state to take it.
func take_rope(rope: Rope, at: float, hook: Node3D) -> bool:
	if is_limp or state != State.FREE or _is_resting():
		return false
	var grounded := is_on_floor()
	var hands := global_position.y + hang_height
	_hold_rope(rope, at, velocity)
	_grapple = hook
	taut_progress = 0.0
	# (a hook's rope has no more to climb down than the little he holds below his hands)
	if grounded:
		_take_up = Vector2(hands, hands + grapple_lift)
		_take_time = 0.0
	var away := rope.global_position - global_position
	away.y = 0.0
	if away.length() > 0.3:
		_rope_heading = away.normalized()
	return true


## On a rope. The stick throws his weight about: with the swing it builds it,
## against it checks it. Act (held) climbs, duck lets him down it and off the
## end, and jump leaps off with whatever swing it has. (Where there is only left
## and right to go, up and down on the stick climb as well.)
func _climb_rope(input: Vector2, delta: float) -> void:
	if not is_instance_valid(_rope):
		# (it has been taken down from over him)
		_rope = null
		_leave_rope()
		return
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var swing := _rope.velocity_at(_rope_at)
	var level := Vector3(swing.x, 0.0, swing.z)
	var lean := _to_world(input if move_mode == MoveMode.FREE else Vector2(input.x, 0.0))
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		# Off it: what the swing gives him, a push the way he is going (or wants
		# to go), and most of a jump's lift. Let go as it rises ahead of him, it
		# throws him forward and up.
		var way := facing
		if lean.length() > 0.3:
			way = lean.normalized()
		elif level.length() > 1.0:
			way = level.normalized()
		velocity = swing + way * rope_leap.x + Vector3.UP * _jump_velocity * rope_leap.y
		_jumping = true
		_since_jump = 0.0
		_flung = true
		_leave_rope()
		jumped.emit()
		return
	_rope_act = _rope_act or not _is_act_held()
	var climb := 0.0
	if _rope_act and _is_act_held():
		climb -= rope_speed
	if _is_duck_held() and _state_time > 0.15:
		climb += rope_slide_speed
	if move_mode == MoveMode.SIDE_SCROLL:
		climb += input.y * rope_speed
	var at := clampf(_rope_at + climb * delta, 0.4, _rope.length - 0.1)
	if climb > 0.0 and _rope_at + climb * delta > _rope.length - 0.1 and _take_time < 0.0:
		# (he has let himself down off the end of it)
		_leave_rope()
		return
	if climb < 0.0 and at <= 0.4 and _rope_top_out(lean):
		return
	if _take_time >= 0.0:
		at = _taken_up(at, delta)
	# He hangs just behind the rope, with it in front of his chest, and goes where it goes.
	var hold := _rope.point_at(at) - facing * 0.16
	var to := Vector3(hold.x, hold.y - hang_height, hold.z)
	# But not through things. Put down on the ground he lets go and stands, and
	# off a wall the rope comes back the way it went.
	var hit := KinematicCollision3D.new()
	if test_move(global_transform, to - global_position, hit):
		var normal := hit.get_normal()
		if normal.y > 0.7:
			if _take_time >= 0.0:
				to.y = maxf(to.y, global_position.y)
			elif _state_time > 0.2:
				_put(global_position + hit.get_travel())
				_leave_rope()
				_grab_cooldown = 0.25
				return
			else:
				at = minf(at, _rope_at)
				to.y = maxf(to.y, global_position.y)
		else:
			var into := swing.dot(normal)
			if into < 0.0:
				_rope.push(at, -normal * into * 1.5)
			to = global_position + hit.get_travel()
	# (climbing is hand over hand; let down it, the rope runs through his hands)
	if climb <= rope_speed * 1.01 and _take_time < 0.0:
		rope_travel -= at - _rope_at
	if _take_time >= 0.0:
		_rope.take_in(at)
	else:
		_rope.load_at = at
	_rope_at = at
	_pump(lean, swing, delta)
	# He faces along the swing, and never turns about with it: the way it goes
	# that is nearer the way he faces already. Hanging still, he turns to the stick.
	var out := _rope.point_at(at) - _rope.global_position
	if level.length() > 1.2:
		_rope_heading = level.normalized() * (1.0 if level.dot(facing) >= 0.0 else -1.0)
	elif lean.length() > 0.3 and level.length() < 0.6 and Vector2(out.x, out.z).length() < 0.35:
		_rope_heading = lean.normalized()
	else:
		_rope_heading = Vector3.ZERO
	taut_progress = minf(taut_progress + delta / 0.5, 1.0)
	velocity = swing
	if _rope_new:
		# (to the rope from wherever he caught it, what is seen of him easing across)
		_put(to)
		_rope_new = false
	else:
		global_position = to


## Throwing his weight about on a rope. With the way it is going (or to set it
## going from rest) it is a push, less as it nears as high as he can work it;
## against it, a drag. He cannot hold himself out to one side by it.
func _pump(lean: Vector3, swing: Vector3, delta: float) -> void:
	if lean.length() < 0.1:
		return
	var out := _rope.point_at(_rope_at) - _rope.global_position
	if out.length() < 0.05:
		return
	var along := out.normalized()
	var push := lean - along * lean.dot(along)
	var level := Vector3(out.x, 0.0, out.z)
	var speed := swing.length()
	if speed < 0.6:
		# Hanging there, all but still: he can start it from the bottom, and
		# help it on its way back down from the top, but not push himself higher.
		if level.length() < 0.3 or push.dot(level) < 0.0:
			_rope.push(_rope_at, push * rope_pump * delta)
		return
	var with := push.normalized().dot(swing.normalized()) if push.length() > 0.01 else 0.0
	if with > -0.25:
		# (how high this swing will carry him as it is, from how fast it is going and where it has got to)
		var top := cos(_rope.angle_at(_rope_at)) - speed * speed / (2.0 * _rope.gravity * maxf(_rope_at, 0.4))
		var high := rad_to_deg(acos(clampf(top, -1.0, 1.0)))
		var room := 1.0 - smoothstep(rope_swing_limit - 16.0, rope_swing_limit, high)
		_rope.push(_rope_at, push * rope_pump * room * delta)
	else:
		_rope.push(_rope_at, -swing * (1.0 - exp(-rope_brake * lean.length() * -with * delta)))


## A hook's rope taking his weight where he stands: it is hauled in under him
## as he swings in beneath it, so that his feet come up off the ground and stay
## off it. Returns how far down it his hands should now be.
func _taken_up(at: float, delta: float) -> float:
	_take_time += delta
	var want := lerpf(_take_up.x, _take_up.y, smoothstep(0.0, 0.45, _take_time))
	var top := _rope.global_position
	var slope := clampf((top.y - _rope.point_at(_rope_at).y) / maxf(_rope_at, 0.1), 0.35, 1.0)
	var needed := maxf((top.y - want) / slope, 0.4)
	if needed < at:
		return needed
	if _take_time > 0.45:
		_take_time = -1.0
	return at


## At the top of a rope and still climbing: if there is an edge there to get
## hold of (what it hangs from, or something beside it), he takes that instead.
func _rope_top_out(lean: Vector3) -> bool:
	var was := _wish
	var reach := ledge_reach
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	ledge_reach.y = hang_height + 0.75
	state = State.FREE
	var caught := false
	for turn: float in [0.0, 0.8, -0.8, 1.6, -1.6, 2.4, -2.4, PI]:
		_wish = (lean.normalized() if lean.length() > 0.3 else facing).rotated(Vector3.UP, turn)
		if _try_catch_ledge(0.7):
			caught = true
			break
	_wish = was
	ledge_reach = reach
	if not caught:
		state = State.ROPE
		return false
	# (state is HANG now; the rope is let go of without the leap)
	var held := _state_time
	state = State.ROPE
	_leave_rope()
	state = State.HANG
	_state_time = minf(held, 0.0)
	_grab_cooldown = 0.0
	return true


## Lets go of the rope he is on.
func _leave_rope() -> void:
	_rope_left = _rope
	_rope_rest = 0.9
	_drop_rope()
	state = State.FREE
	_grab_cooldown = 0.5


## The rope is no longer his: nobody weighs on it, and if it was a grappling
## hook's the hook comes away and is wound in.
func _drop_rope() -> void:
	if is_instance_valid(_rope):
		_rope.load_at = -1.0
		_rope.held_below = 0.0
	_rope = null
	_take_time = -1.0
	taut_progress = 1.0
	if is_instance_valid(_grapple) and _grapple.has_method(&"come_away"):
		_grapple.come_away()
	_grapple = null


# --- Ladders ---

## Takes hold of a ladder he is going into, from the ground or out of the air;
## or, standing at the top of one and walking out over it, turns round and gets
## onto it backwards.
func _try_catch_ladder() -> bool:
	if _wish.length_squared() < 0.04:
		return false
	for ladder: Ladder in get_tree().get_nodes_in_group(&"ladders"):
		var facing := ladder.facing()
		var onto := ladder.stand(ladder.top_y() + 0.03) + facing * 0.75
		if is_on_floor() and absf(global_position.y - onto.y) < 0.2 and _wish.normalized().dot(facing) < -0.6:
			var from_top := global_position - onto
			var across := Vector3(-facing.z, 0.0, facing.x)
			if absf(from_top.dot(across)) < 0.3 and absf(from_top.dot(facing) + 0.1) < 0.35:
				_ladder = ladder
				_engage()
				ladder_travel = 0.0
				velocity = Vector3.ZERO
				_ladder_onto = global_position
				_ladder_from = ladder.stand(ladder.top_y() - 0.25)
				ladder_off = 1.0
				_ladder_leaving = -1.0
				state = State.LADDER
				_state_time = 0.0
				return true
		var at := ladder.stand(global_position.y)
		if global_position.distance_to(at) > 0.45 or _wish.normalized().dot(facing) < 0.5:
			continue
		if global_position.y < ladder.bottom_y() - 0.2 or global_position.y > ladder.top_y() - 0.6:
			continue
		_ladder = ladder
		_engage()
		ladder_travel = 0.0
		velocity = Vector3.ZERO
		ladder_off = 0.0
		_ladder_leaving = 0.0
		state = State.LADDER
		_state_time = 0.0
		return true
	return false


## On a ladder: up and down climb it, he steps off at the top, jump leaps off
## backwards, duck lets go.
func _climb_ladder(input: Vector2, delta: float) -> void:
	var facing := _ladder.facing()
	if _ladder_leaving != 0.0:
		# Off the top: up until his feet are level with it, a hand on the end of
		# each rail, and forward onto it. (Or the same backwards, to get on.)
		_jump_buffer = 0.0
		ladder_off = clampf(ladder_off + _ladder_leaving * delta / LADDER_OFF_TAKES, 0.0, 1.0)
		var rise := smoothstep(0.0, 0.55, ladder_off)
		var forward := smoothstep(0.4, 1.0, ladder_off)
		var before := global_position
		global_position = Vector3(lerpf(_ladder_from.x, _ladder_onto.x, forward), lerpf(_ladder_from.y, _ladder_onto.y, rise), lerpf(_ladder_from.z, _ladder_onto.z, forward))
		velocity = (global_position - before) / delta
		if ladder_off >= 1.0 and _ladder_leaving > 0.0:
			velocity = Vector3.ZERO
			ladder_off = 0.0
			_ladder_leaving = 0.0
			_leave_ladder()
			_grab_cooldown = 0.2
			_was_grounded = true
			_coyote = coyote_time
		elif ladder_off <= 0.0:
			_ladder_leaving = 0.0
			velocity = Vector3.ZERO
		return
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = -facing * run_speed * 0.7 + Vector3.UP * _jump_velocity * 0.8
		facing_yaw = atan2(-facing.x, -facing.z)
		_jumping = true
		_leave_ladder()
		jumped.emit()
		return
	if _is_duck_held() and _state_time > 0.15:
		_leave_ladder()
		return
	# (up the screen is up the ladder, whichever way the camera looks at it)
	var step := -input.y * ladder_speed * delta
	var y := global_position.y + step
	if y <= _ladder.bottom_y() and step < 0.0:
		_leave_ladder()
		return
	if y >= _ladder.top_y() - 0.25 and step > 0.0:
		# Off the top, onto whatever it leans against.
		var onto := _ladder.stand(_ladder.top_y() + 0.03) + facing * 0.75
		if not test_move(Transform3D(Basis.IDENTITY, onto), Vector3.UP * 0.01, null, 0.001, true):
			_ladder_from = global_position
			_ladder_onto = onto
			ladder_off = 0.0
			_ladder_leaving = 1.0
			return
		y = global_position.y
	ladder_travel += y - global_position.y
	velocity = Vector3(0.0, (y - global_position.y) / delta, 0.0)
	_put(_ladder.stand(y))


func _leave_ladder() -> void:
	_ladder = null
	ladder_off = 0.0
	_ladder_leaving = 0.0
	state = State.FREE
	_grab_cooldown = 0.5


# --- Water ---

## How far under the surface of whatever water he is in his feet are.
func _depth() -> float:
	var deepest := -1000.0
	for pool: Pool in get_tree().get_nodes_in_group(&"water"):
		var depth := pool.depth_at(global_position)
		if depth > deepest:
			deepest = depth
			_pool = pool
	return deepest


## In over his chest, he swims.
func _try_swim() -> void:
	_last_depth = _depth()
	wade = clampf(_last_depth, 0.0, FLOAT_DEPTH) if is_on_floor() or air_time < 0.15 else 0.0
	# (in a dive it is his head and hands that go in first, and it has him sooner)
	var diving := is_diving and velocity.y < 0.0
	if _swim_rest > 0.0 or _last_depth < (DIVE_IN_DEPTH if diving else FLOAT_DEPTH):
		return
	# (what he was carrying he lets go of: he needs both hands, and a gun is no use wet)
	_let_go()
	_engage()
	state = State.SWIM
	_state_time = 0.0
	swim_clear = 1.0
	wade = 0.0
	if diving:
		dive_in = 1.0
	splashed.emit(maxf(-velocity.y, 0.0) * (0.6 if diving else 1.0))
	if diving:
		# He goes on in the way he was going, and down, and comes up further on.
		velocity = Vector3(velocity.x * 0.8, minf(velocity.y, -3.0) * 0.75, velocity.z * 0.8)
		return
	# (the water takes most of the speed he hit it with)
	velocity *= 0.35


## Swimming. On the surface a gentle push is breast stroke and a full one a
## crawl; duck takes him under, where it is a frog kick and a flutter kick, jump
## brings him up, and left alone he floats up. At the surface jump heaves him up
## out of the water, far enough to catch the side.
func _swim(delta: float) -> void:
	var depth := _depth()
	if dive_in > 0.0:
		# Gone in head first: on down and forward for a moment, slowing, before he swims.
		dive_in = maxf(dive_in - delta / DIVE_IN_TAKES, 0.0)
		is_underwater = depth > UNDER_DEPTH - 0.5
		var slowed := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 2.2 * delta)
		velocity = Vector3(slowed.x, move_toward(velocity.y, 0.6, 7.5 * delta), slowed.z)
		if is_on_floor() or is_on_wall():
			dive_in = 0.0
		move_and_slide()
		air_time = 0.0
		_was_grounded = true
		if depth < 0.0:
			dive_in = 0.0
		return
	if depth < FLOAT_DEPTH - 0.35 or (is_on_floor() and depth < FLOAT_DEPTH - 0.04):
		# Out of his depth no longer (or thrown clear of it).
		state = State.FREE
		is_underwater = false
		_was_grounded = is_on_floor()
		air_time = 0.0
		return
	is_underwater = depth > UNDER_DEPTH
	var strength := minf(_wish.length(), 1.0)
	var speeds := dive_speeds if is_underwater else swim_speeds
	var hard := smoothstep(run_threshold, run_threshold + 0.2, strength)
	var target := _wish.normalized() * (lerpf(speeds.x, speeds.y, hard) if strength > 0.0 else 0.0)
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, (5.0 if strength > 0.0 else 2.5) * delta)
	var rise := clampf((depth - FLOAT_DEPTH) * 4.0, -1.5, 1.2)
	if _is_duck_held():
		rise = -1.8
	elif _is_jump_held() and is_underwater:
		rise = 2.2
	elif _jump_buffer > 0.0 and depth < FLOAT_DEPTH + 0.15:
		_jump_buffer = 0.0
		# At the side, he takes hold of it. Otherwise he heaves himself up out of the water.
		if _wish.length_squared() > 0.04 and _try_catch_ledge():
			is_underwater = false
			return
		velocity = flat + Vector3.UP * _jump_velocity * 0.8
		state = State.FREE
		is_underwater = false
		_jumping = true
		_was_grounded = false
		air_time = 0.2
		_grab_cooldown = 0.0
		# (or the water would have him back before he was out of it)
		_swim_rest = 0.3
		jumped.emit()
		move_and_slide()
		return
	velocity = Vector3(flat.x, move_toward(velocity.y, rise, 9.0 * delta), flat.z)
	# Is there a wall just ahead? He comes upright as he gets to it.
	var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var chest := global_position + Vector3.UP * 0.85
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + ahead * 1.2, 1))
	swim_clear = 1.0 if wall.is_empty() else clampf((chest.distance_to(wall.position) - 0.45) / 0.75, 0.0, 1.0)
	# Steps up out of the water are climbed as any others are.
	if strength > 0.0 and not is_underwater:
		_try_step_up(delta)
	move_and_slide()
	air_time = 0.0
	_was_grounded = true


# --- Carrying and throwing ---

## The act button: pick up what is at his feet, or throw what he holds. Neither
## is done at once: he stoops for it, and he winds up to throw (see _use_hands).
func _act() -> void:
	_stirred = true
	if is_limp or state != State.FREE or pickup_progress < 1.0 or throw_progress < 1.0 or swing_progress < 1.0 or landing_progress < 1.0:
		return
	if _is_resting() or is_diving or flip_progress < 1.0 or is_spinning or cast_progress < 1.0:
		return
	if carried and carried.is_in_group(&"grapples"):
		# A grappling hook is thrown at whatever there is to catch (see
		# _use_hands), and stays his; with duck held it is put down.
		if _is_duck_held() or is_ducking:
			_let_go()
		elif not hook_out and reel_progress >= 1.0:
			_cast_at = carried.find_target(self)
			cast_progress = 0.0
		return
	if gun_handling and carried and carried.is_in_group(&"guns"):
		# A gun is fired, not thrown: he brings it up and shoots (see _use_hands).
		# With duck held it is put down.
		if _is_duck_held() or is_ducking:
			_let_go()
		else:
			_fire_wanted = true
			_aim_hold = gun_raise_time + gun_hold_time
		return
	if carried and carried.is_in_group(&"bats"):
		# A bat is swung, not thrown; with duck held it is put down.
		if _is_duck_held():
			_let_go()
		else:
			swing_progress = 0.0
		return
	if carried:
		# (and so is anything else: there is no winding up to throw while ducked)
		if _is_duck_held() or is_ducking:
			_let_go()
		else:
			throw_progress = 0.0
		return
	if not is_on_floor():
		return
	var nearest := pickup_reach
	var found: RigidBody3D
	for body: RigidBody3D in get_tree().get_nodes_in_group(&"throwable"):
		var distance := body.global_position.distance_to(global_position + Vector3.UP * 0.4)
		if distance < nearest:
			nearest = distance
			found = body
	# Something to be worked (a lever, a mirror on its stand: whatever is in the
	# group `workable`) is worked instead, unless there is something to pick up nearer.
	var handle := _workable(nearest if found else INF)
	if handle:
		_picking = null
		pickup_point = handle.call(&"work_point") if handle.has_method(&"work_point") else handle.global_position
		pickup_progress = 0.0
		handle.call(&"work", self)
		return
	if found:
		_picking = found
		pickup_point = found.global_position
		pickup_progress = 0.0


## What there is to work within his reach, and nearer over the ground than
## `nearer_than`: the nearest thing in the group `workable` (it has a method
## `work`, called with him, and may say where his hand goes with `work_point`).
func _workable(nearer_than: float) -> Node3D:
	var nearest := minf(work_reach, nearer_than)
	var found: Node3D
	for thing: Node in get_tree().get_nodes_in_group(&"workable"):
		var handle := thing as Node3D
		if handle == null or not handle.has_method(&"work"):
			continue
		var to := handle.global_position - global_position
		var distance := Vector2(to.x, to.z).length()
		if distance < nearest and to.y > -1.2 and to.y < 1.0:
			nearest = distance
			found = handle
	return found


## Lets go of whatever he holds, where it is: for what takes a thing out of
## his hand (a lock takes its key).
func let_go() -> void:
	_let_go()


## Carries a stoop or a throw through: the thing is in his hand partway through
## the one, and leaves it partway through the other.
func _use_hands(delta: float) -> void:
	if pickup_progress < 1.0:
		pickup_progress = minf(pickup_progress + delta / pickup_time, 1.0)
		if _picking and not is_instance_valid(_picking):
			_picking = null
		if _picking:
			pickup_point = _picking.global_position
			if state != State.FREE or is_limp:
				_picking = null
			elif pickup_progress >= PICKUP_TAKES:
				_take(_picking)
				_picking = null
	if swing_progress < 1.0:
		var before := swing_progress
		swing_progress = minf(swing_progress + delta / swing_time, 1.0)
		if before < SWING_HITS and swing_progress >= SWING_HITS and carried and carried.is_in_group(&"bats"):
			_hit()
	if throw_progress < 1.0:
		throw_progress = minf(throw_progress + delta / throw_time, 1.0)
		if carried and (throw_progress >= THROW_RELEASE or state != State.FREE):
			_throw()
	if cast_progress < 1.0:
		var before := cast_progress
		cast_progress = minf(cast_progress + delta / cast_time, 1.0)
		if carried == null or not carried.is_in_group(&"grapples") or state != State.FREE or is_limp:
			# (whatever has happened to him, the throw is off)
			cast_progress = 1.0
		elif before < CAST_RELEASE and cast_progress >= CAST_RELEASE:
			carried.cast(self, _cast_at if is_instance_valid(_cast_at) else null)
			threw.emit()
	if reel_progress < 1.0:
		reel_progress = minf(reel_progress + delta / reel_time, 1.0)
	_handle_gun(delta)


## The bat comes round: whatever loose thing is in front of him is sent flying.
func _hit() -> void:
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	for body: Node in get_tree().get_nodes_in_group(&"throwable"):
		var struck := body as RigidBody3D
		if struck == null or struck == carried:
			continue
		var to := struck.global_position - (global_position + Vector3.UP * 0.8)
		if to.length() < 1.5 and Vector3(to.x, 0.0, to.z).normalized().dot(facing) > 0.2:
			struck.linear_velocity = facing * swing_power + Vector3.UP * swing_power * 0.4
			struck.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))


## A gun in his hands: brings it up when he has been told to fire, fires it once
## it is up, keeps it there a moment, and lowers it.
func _handle_gun(delta: float) -> void:
	var armed := gun_handling and carried != null and carried.is_in_group(&"guns") and state == State.FREE and not is_limp
	if not armed or landing_progress < 1.0:
		gun_raise = move_toward(gun_raise, 0.0, delta / 0.15)
		_fire_wanted = false
		_aim_hold = 0.0
		return
	_aim_hold -= delta
	var up := _aim_hold > 0.0
	gun_raise = move_toward(gun_raise, 1.0 if up else 0.0, delta / (gun_raise_time if up else gun_lower_time))
	if up or gun_raise <= 0.0:
		var aim := _aim_direction()
		gun_aim = aim if gun_raise < 0.05 else gun_aim.slerp(aim, 1.0 - exp(-14.0 * delta)).normalized()
	if _fire_wanted and gun_raise >= 1.0:
		_fire_wanted = false
		_fire()


## Which way he aims: where he faces, or at the nearest thing worth shooting at
## that is near enough to it (what is after him first, then anything of interest).
func _aim_direction() -> Vector3:
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var from := global_position + Vector3.UP * 1.0 + facing * 0.35
	var best := facing
	for group: StringName in [&"pursuers", &"interest"]:
		var nearest := gun_range
		for thing: Node in get_tree().get_nodes_in_group(group):
			var body := thing as Node3D
			if body == null or body == carried or body == self or is_ancestor_of(body):
				continue
			var to := body.global_position + Vector3.UP * (0.55 if group == &"pursuers" else 0.2) - from
			var distance := to.length()
			var level := Vector3(to.x, 0.0, to.z)
			if distance > nearest or level.length() < 0.7 or level.normalized().angle_to(facing) > gun_cone or absf(to.y) > level.length() * 0.8:
				continue
			nearest = distance
			best = to.normalized()
		if best != facing:
			break
	return best


## Fires the gun: the gun does the shooting, and he takes the kick of it.
func _fire() -> void:
	var gun := carried
	if gun == null or not gun.has_method(&"fire"):
		return
	if not gun.fire(self, gun_aim):
		# (empty, or its action still being worked: the gun sees to that itself, and he keeps it up)
		_aim_hold = maxf(_aim_hold, gun_hold_time * 0.6)
		return
	var kick: float = gun.get(&"kick") if gun.get(&"kick") != null else 0.5
	_aim_hold = gun_hold_time
	if is_on_floor():
		var back := -Vector3(gun_aim.x, 0.0, gun_aim.z).normalized()
		velocity += back * gun_shove * kick
	shot.emit(kick)


func _take(found: RigidBody3D) -> void:
	carried = found
	_carried_layers = Vector2i(found.collision_layer, found.collision_mask)
	_carry_from = found.global_position
	_carry_ease = 0.0
	found.freeze = true
	found.collision_layer = 0
	found.collision_mask = 0
	# (anything that wants to know who has it is told)
	if found.has_method(&"taken_by"):
		found.taken_by(self)


func _throw() -> void:
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var thrown := carried
	_let_go()
	thrown.linear_velocity = facing * throw_speed.x + Vector3.UP * throw_speed.y + Vector3(velocity.x, 0.0, velocity.z) * 0.5
	thrown.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	last_thrown = thrown
	threw.emit()


## Releases whatever is held, where it is.
func _let_go() -> void:
	if carried == null:
		return
	if carried.has_method(&"taken_by"):
		carried.taken_by(null)
	cast_progress = 1.0
	carried.collision_layer = _carried_layers.x
	carried.collision_mask = _carried_layers.y
	carried.freeze = false
	carried.linear_velocity = Vector3.ZERO
	carried = null
	# (a swing has nothing left to swing)
	swing_progress = 1.0
	_fire_wanted = false
	_aim_hold = 0.0


# --- Steps and pushing ---

## Lifts the body onto a low ledge it is walking into. Returns true if it moved.
func _try_step_up(delta: float) -> bool:
	if _wish.length_squared() < 0.01:
		return false
	var wish_dir := _wish.normalized()
	var speed := Vector2(velocity.x, velocity.z).length()
	var motion := wish_dir * maxf(speed * delta, 0.02)
	var hit := KinematicCollision3D.new()

	var from := global_transform
	if not test_move(from, motion, hit):
		return false
	var normal := hit.get_normal()
	if normal.y >= cos(floor_max_angle):
		# That was the floor grazing the capsule; look again from just above it.
		if not test_move(from.translated(Vector3.UP * 0.03), motion, hit):
			return false
		normal = hit.get_normal()
		if normal.y >= cos(floor_max_angle):
			return false
	var into := Vector3(-normal.x, 0.0, -normal.z).normalized()
	if wish_dir.dot(into) < 0.35:
		return false

	var up := Vector3.UP * max_step_height
	if test_move(from, up):
		return false
	# Far enough that the capsule's centre clears the edge and rests on the tread.
	var forward := into * (hit.get_travel().dot(into) + _radius + 0.03)
	var raised := from.translated(up)
	if test_move(raised, forward):
		return false
	var over := raised.translated(forward)
	if not test_move(over, -up, hit):
		return false
	if hit.get_normal().y < cos(floor_max_angle):
		return false
	var landing := over.origin + hit.get_travel()
	if landing.y - from.origin.y < 0.02:
		return false

	_put(landing)
	# That put him further on in one go than he would have run in several.
	_step_hold = minf(Vector2(_visual_offset.x, _visual_offset.z).length() / maxf(speed, 1.0), 0.35)
	_step_rate = _visual_offset.length() / maxf(_step_hold, delta)
	_step_delay = 2.0 * delta
	return true


## Looks along the way he is going for a flight of stairs: two risers or more,
## all up or all down, each low enough to step, with level treads between
## them. A kerb is one riser and a ramp has none, so neither counts.
func _probe_stairs(grounded: bool, delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_stairs_seen -= delta
	if grounded and state == State.FREE and flat.length() > 0.4 and landing_progress >= 1.0:
		var along := flat.normalized()
		var spacing := 0.15
		var heights := PackedFloat32Array()
		for k in 11:
			heights.append(_ground_at(global_position + along * (-0.45 + spacing * k)))
		var risers := 0
		var mixed := false
		var total := 0.0
		var first := -1
		var last := -1
		for k in 10:
			var change := heights[k + 1] - heights[k]
			if is_nan(change) or absf(change) < 0.04 or absf(change) > max_step_height + 0.03:
				continue
			if risers > 0 and signf(change) != signf(total):
				mixed = true
			risers += 1
			total += change
			if first < 0:
				first = k
			last = k
		if risers >= 2 and not mixed:
			var edges := Vector2.ZERO
			for which in 2:
				# (where exactly each of those two risers is)
				var k := first if which == 0 else last
				var near := -0.45 + spacing * k
				var far := near + spacing
				for pass_ in 4:
					var middle := (near + far) * 0.5
					var height := _ground_at(global_position + along * middle)
					if is_nan(height) or absf(height - heights[k]) < 0.02:
						near = middle
					else:
						far = middle
				edges[which] = (near + far) * 0.5
			stair_rise = total / risers
			stair_run = maxf((edges.y - edges.x) / (risers - 1), 0.12)
			stair_edge = global_position + along * edges.x
			stair_dir = along
			_stairs_seen = 0.2
	on_stairs = 1.0 if _stairs_seen > 0.0 else 0.0


## How high the ground is at `point`, if it is level there (or NAN).
func _ground_at(point: Vector3) -> float:
	var from := Vector3(point.x, global_position.y + 0.7, point.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.8, 1))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.985:
		return NAN
	return (hit.position as Vector3).y


## Puts him down onto ground that is no more than a step below him, as if he
## had never left it. Returns whether there was any.
func _keep_to_ground(_delta: float) -> bool:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * (max_step_height + 0.04), hit) or hit.get_normal().y < cos(floor_max_angle):
		return false
	var drop := hit.get_travel().y
	global_position.y += drop
	velocity.y = 0.0
	if drop < -0.03:
		_visual_offset.y = minf(_visual_offset.y - drop, max_step_height)
	return true


## Floor snapping drops the body instantly on stairs; hide that from the rig.
func _smooth_step_down(moved_y: float, delta: float) -> void:
	var normal := get_floor_normal()
	var slope_y := -(velocity.x * normal.x + velocity.z * normal.z) / maxf(normal.y, 0.1) * delta
	var drop := moved_y - slope_y
	if drop < -0.03:
		_visual_offset.y = minf(_visual_offset.y - drop, max_step_height)


func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody3D
		if body == null:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.5:
			continue
		var direction := Vector3(-normal.x, 0.0, -normal.z).normalized()
		if _wish.dot(direction) < 0.3:
			continue
		_push_timer = 0.2
		var body_speed := body.linear_velocity.dot(direction)
		var impulse := clampf((push_speed - body_speed) * body.mass, 0.0, push_force * delta)
		body.apply_central_impulse(direction * impulse)
		# The slide zeroed our speed against the body; match it instead so we
		# stay in contact and push steadily rather than in bumps.
		var matched := clampf(body_speed + impulse / body.mass, 0.0, push_speed)
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		flat += direction * (matched - flat.dot(direction))
		velocity.x = flat.x
		velocity.z = flat.z
		return


static func _ensure_input_actions() -> void:
	_add_action(&"move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action(&"move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action(&"move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action(&"move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action(&"walk", [KEY_ALT])
	_add_action(&"sprint", [KEY_SHIFT], JOY_AXIS_TRIGGER_LEFT, 1.0, JOY_BUTTON_LEFT_SHOULDER)
	_add_action(&"jump", [KEY_SPACE], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_A)
	_add_action(&"duck", [KEY_C, KEY_CTRL], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_B)
	_add_action(&"act", [KEY_E, KEY_F], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_X)
	_add_action(&"ragdoll", [KEY_R], JOY_AXIS_INVALID, 0.0, JOY_BUTTON_LEFT_STICK)
	# (the rest of a gamepad, its right trigger among it, which is his hand too: see `_trigger`)
	Gamepad.ensure()


static func _add_action(action: StringName, keys: Array[Key], axis := JOY_AXIS_INVALID, axis_value := 0.0, button := JOY_BUTTON_INVALID) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if axis != JOY_AXIS_INVALID:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = axis_value
		# (whichever gamepad it is: see Gamepad.device)
		motion.device = Gamepad.device
		InputMap.action_add_event(action, motion)
	if button != JOY_BUTTON_INVALID:
		var press := InputEventJoypadButton.new()
		press.button_index = button
		press.device = Gamepad.device
		InputMap.action_add_event(action, press)


# --- Ragdoll and checkpoints ---

## Drops the body as a ragdoll, carrying its current motion plus `impulse`
## (newton-seconds, applied to the chest). Input is ignored until `recover`
## or `respawn`.
func ragdoll(impulse := Vector3.ZERO) -> void:
	if is_limp:
		return
	_drop_rope()
	_let_go()
	state = State.FREE
	cast_progress = 1.0
	_ladder = null
	is_limp = true
	pickup_progress = 1.0
	throw_progress = 1.0
	_picking = null
	ladder_off = 0.0
	_ladder_leaving = 0.0
	landing_progress = 1.0
	is_scrambling = false
	is_underwater = false
	is_sprinting = false
	is_crawling = false
	_run_time = 0.0
	_jump_buffer = 0.0
	on_stairs = 0.0
	_stairs_seen = 0.0
	_clear_moves()
	_set_height(stand_height)
	_rig.go_limp(velocity, impulse)
	velocity = Vector3.ZERO


## Stands the body back up where it came to rest.
func recover() -> void:
	if not is_limp:
		return
	global_position = _rig.limp_position() + Vector3.UP * 0.05
	_rig.recover()
	is_limp = false
	_was_grounded = false
	_reset_visuals()


## Makes `at` the place `respawn` returns to (a checkpoint).
func set_spawn(at: Vector3) -> void:
	_spawn = Transform3D(Basis.IDENTITY, at)


# --- Hands ---

## Remembers the upright surface he is pressing into, if any: a wall he has
## walked up to, or a block he is pushing.
func _note_lean() -> void:
	if not is_on_floor() or is_ducking or state != State.FREE or _wish.length_squared() < 0.04:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.y) < 0.3 and _wish.normalized().dot(-normal) > 0.5:
			_lean_point = collision.get_position()
			_lean_normal = normal
			_lean_timer = 0.15
			return


## Works out where his hands go: on the ledge he hangs from, the rope he is on,
## or flat against what he is leaning into.
func _place_hands(delta: float) -> void:
	_lean_timer -= delta
	_lean_held = _lean_held + delta if _lean_timer > 0.0 else 0.0
	hand_reach = 0.0
	hand_normal = Vector3.ZERO
	var facing := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	hand_fingers = Vector3.ZERO
	hand_hook = 0.0
	if state == State.HANG or (state == State.CLIMB and climb_progress < 0.3):
		# Hanging by his fingers: the palms against the face, the fingers bent over the lip.
		for hand in 2:
			hand_points[hand] = _grips[hand] - _ledge_direction * 0.014 + Vector3.DOWN * 0.012
		hand_normal = -_ledge_direction
		hand_fingers = Vector3.UP
		hand_hook = 1.0
		hand_reach = 1.0
	elif state == State.CLIMB and climb_progress < 0.72:
		# Up over it: the hands flat on top, the heels of them at the edge, to push down on.
		for hand in 2:
			hand_points[hand] = _grips[hand] + _ledge_direction * 0.055 + Vector3.UP * 0.014
		hand_normal = Vector3.UP
		hand_fingers = _ledge_direction
		hand_reach = 1.0
	elif state == State.LADDER:
		# A hand and a foot to a rung, each taking every other one. Past the
		# last rung his hands go to the ends of the rails.
		var into := _ladder.facing()
		var right := Vector3(-into.z, 0.0, into.x)
		var last := _ladder.bottom_y() + floorf(_ladder.height / Ladder.RUNG + 0.001) * Ladder.RUNG
		# (and when there are no more rungs to reach for, flat on whatever it
		# leans against, until that is too low to lean on)
		var over_top := maxf(_ladder.rung(global_position.y + 1.12, false), _ladder.rung(global_position.y + 1.12, true)) > last + 0.01
		for i in 2:
			var across := right * (-0.15 if i == 0 else 0.15)
			var at := _ladder.global_position + across
			var grip := _ladder.rung(global_position.y + 1.12, i == 1)
			hand_points[i] = Vector3(at.x, grip, at.z) - into * 0.02
			if over_top:
				hand_points[i] = _ladder.global_position + right * (-0.17 if i == 0 else 0.17) + Vector3.UP * (_ladder.height + 0.015) + into * (0.24 if i == 0 else 0.2)
			var tread := clampf(_ladder.rung(global_position.y + 0.12, i == 0), _ladder.bottom_y() + Ladder.RUNG, last)
			foot_points[i] = Vector3(at.x, tread, at.z) - into * 0.07
			if ladder_off > 0.0:
				# Getting off: one foot up onto the top, then the other after it.
				var stepped := smoothstep(0.3, 0.62, ladder_off) if i == 0 else smoothstep(0.66, 0.97, ladder_off)
				var down := _ladder_onto + right * (-0.08 if i == 0 else 0.08) + into * (0.06 if i == 0 else -0.04)
				foot_points[i] = foot_points[i].lerp(down, stepped) + (Vector3.UP * 0.14 - into * 0.08) * sin(PI * stepped)
		hand_reach = 1.0
		if over_top:
			hand_normal = Vector3.UP
			hand_fingers = into
			hand_reach = smoothstep(0.42, 0.6, _ladder.top_y() - global_position.y) if ladder_off <= 0.0 or _ladder_leaving < 0.0 else 0.0
	elif state == State.ROPE and is_instance_valid(_rope):
		# One above the other, hand over hand: each keeps its hold on the rope
		# while he goes up past it, then lets go and takes a new one above the other.
		for i in 2:
			var cycle := fposmod(rope_travel / (ROPE_PULL * 2.0) + 0.5 * i, 1.0)
			var below := lerpf(-0.21, 0.21, cycle / 0.75) if cycle < 0.75 else lerpf(0.21, -0.21, smoothstep(0.0, 1.0, (cycle - 0.75) / 0.25))
			hand_points[i] = _rope.point_at(_rope_at + below)
		hand_reach = 1.0
	elif state == State.FREE and _lean_held > 0.15:
		# Each hand goes where a line straight ahead from the shoulder meets the
		# surface. Anything too low for both hands (a step, a kerb) is not leant on.
		var left := Vector3(facing.z, 0.0, -facing.x)
		var space := get_world_3d().direct_space_state
		var found := PackedVector3Array()
		for i in 2:
			var from := global_position + Vector3.UP * (stand_height * 0.6) + left * (0.13 if i == 0 else -0.13)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - _lean_normal * 0.65, 1))
			if hit.is_empty():
				return
			found.append((hit.position as Vector3) + (hit.normal as Vector3) * 0.015)
		hand_points = found
		hand_normal = _lean_normal
		hand_reach = 1.0
