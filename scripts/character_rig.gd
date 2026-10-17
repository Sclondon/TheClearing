class_name CharacterRig
extends Node3D
## Drives the character model (models/boy.glb) entirely in code.
##
## There are no clips: the gait is driven by distance travelled so feet do not
## slide, legs are placed with two-bone IK, and everything else (lean, twist,
## arm swing, landing crouch) is layered on with springs. The model faces +Z,
## and its bones all rest unrotated (see tools/build_character.py), so a bone's
## pose is simply its transform relative to its parent bone.
##
## The back is three joints (hips, spine, chest) and the neck two, and every
## lean, twist and curl is shared out along them, so he bends rather than tips.
## A figure without a chest or a neck (the mummy) gets the same motion folded
## into the joints it has. Fingers, the hem of the jumper, the hair and the cap
## are optional in the same way: they are posed if the model has the bones.

## A foot has come down: where its sole is on the ground (in the world), which
## foot (0 the left, 1 the right), and how heavily: about 0.3 sneaking, 0.5 at
## a walk, 1 at a run, more for a sprint, and up to 3 for both feet in a landing.
## A crawl gives one for each knee and hand set down.
signal footfall(at: Vector3, foot: int, weight: float)
## He is scraping along the ground (a slide, a skid, a roll, a body hitting it):
## where, which way he is moving, and how hard, 0..1.
signal scraped(at: Vector3, velocity: Vector3, amount: float)

## Height of a planted foot's ankle joint above the ground.
const ANKLE := 0.05
## Height of the joint at the ball of a planted foot.
const SOLE := 0.015
## How far through a stumble he gives up trying to run it off and goes over in a roll.
const STUMBLE_ROLLS := 0.2
## How high his hips are when he is sitting on the ground.
const SEAT := 0.125
## A landing on one knee and a fist, as shares of the time it takes: when he
## gets up off them (from, to).
const KNEEL_ENDS := Vector2(0.62, 0.94)
## Going sprawling, the same way: when he tips on forward off that knee and fist
## onto both hands (from, to), when his hands come up off the ground (from, to),
## and when he is on his feet again (from, to).
const SPRAWL := Vector2(0.0, 0.03)
const SPRAWL_HANDS := Vector2(0.7, 0.8)
const SPRAWL_ENDS := Vector2(0.82, 1.0)
## How far along a ledge he shimmies for each foot to take one step on the wall.
const WALL_PACE := 0.36

## The figure's proportions. These are read from its skeleton when it is built
## (see _measure), so the boy and the mummy each move to their own measure.
var _hip_height := 0.585
var _hip_width := 0.075
## How far below the hips bone the hip joints sit (negative).
var _hip_drop := -0.02
var _thigh := 0.27
var _shin := 0.27
var _upper_arm := 0.2
var _forearm := 0.2
## How far out the model's arms are held at rest, radians.
var _arm_rest := 0.22
## Where the foot bends, from the ankle.
var _toe := Vector3(0.0, -0.035, 0.075)
## Leg length against the boy's, for scaling strides.
var _leg_scale := 1.0
## How far a limp elbow and knee may turn, radians (lower, upper).
const ELBOW_LIMITS := Vector2(-2.4, 0.0)
const KNEE_LIMITS := Vector2(0.0, 2.4)
const MODELS: Array[PackedScene] = [preload("res://models/boy.glb"), preload("res://models/boy_lo.glb")]
## From the wrist to the middle of the palm.
const PALM := 0.045
## Where on his cap he puts his hand to hold it on, from the joint of his head.
const HAT_HOLD := Vector3(0.075, 0.238, 0.0)
## His cap pulled down over his face to sleep under: how far it is moved from where
## it sits, and how it is turned (for one lying on his left; mirrored for his right).
const CAP_OVER_FACE := Vector3(-0.03, -0.07, 0.075)
const CAP_OVER_TIP := Vector3(1.05, -0.2, 0.35)
## Where in his hand the grip of a gun sits, from his wrist (for the right hand).
const GUN_IN_HAND := Vector3(0.022, -0.078, 0.004)

## Getting up onto a ledge, drawn by hand: each is (how far through the climb,
## value) pairs, read with _keyed. Heights are above the ledge's edge and
## distances are in from its face, so negative is below it and out in the air.
## He hangs with a foot against the wall; sinks a little and heaves, walking
## that foot up the wall, until his chest is over the edge; presses himself up
## on his hands, the other leg kicking out behind him; gets the knee of the
## first leg onto the top, then his weight over it, then the foot through and
## under him; and stands (CLIMB_STANDS: from, to), the other leg coming up after.
const CLIMB_HIPS_Y := [0.0, -0.61, 0.07, -0.65, 0.3, -0.3, 0.46, -0.02, 0.6, 0.1, 0.7, 0.2, 0.8, 0.37]
const CLIMB_HIPS_Z := [0.0, -0.21, 0.07, -0.22, 0.3, -0.2, 0.46, -0.16, 0.6, -0.1, 0.7, -0.02, 0.8, 0.07]
## How far his body leans in over the ledge, and how far his back is curled (negative) to do it.
const CLIMB_PITCH := [0.0, 0.22, 0.07, 0.14, 0.3, 0.22, 0.46, 0.42, 0.6, 0.62, 0.7, 0.78, 0.8, 0.6]
const CLIMB_ARCH := [0.0, 0.14, 0.07, 0.2, 0.3, -0.05, 0.46, 0.05, 0.6, -0.15, 0.7, -0.3, 0.8, -0.25]
## The ankle of the foot that is against the wall, and how far its toes are down.
const CLIMB_FOOT_Y := [0.0, -0.9, 0.07, -0.9, 0.3, -0.72, 0.46, -0.42, 0.6, -0.14, 0.7, -0.02, 0.76, 0.1, 0.8, 0.055]
const CLIMB_FOOT_Z := [0.0, -0.085, 0.07, -0.085, 0.3, -0.085, 0.46, -0.11, 0.6, -0.2, 0.7, -0.14, 0.76, -0.01, 0.8, 0.12]
const CLIMB_FOOT_PITCH := [0.0, -1.0, 0.3, -0.9, 0.46, -0.3, 0.6, 0.7, 0.7, 1.0, 0.76, 0.5, 0.8, 0.0]
## And of the leg that hangs.
const CLIMB_TRAIL_Y := [0.0, -1.13, 0.07, -1.15, 0.3, -0.88, 0.46, -0.6, 0.6, -0.38, 0.7, -0.18, 0.8, 0.1]
const CLIMB_TRAIL_Z := [0.0, -0.11, 0.07, -0.1, 0.3, -0.17, 0.46, -0.32, 0.6, -0.38, 0.7, -0.33, 0.8, -0.16]
const CLIMB_TRAIL_PITCH := [0.0, 0.5, 0.46, 0.85, 0.8, 0.6]
const CLIMB_STANDS := Vector2(0.78, 1.0)

## Going sprawling, drawn the same way: each is (how far through the landing,
## value) pairs. Off his knee and fist he goes on forward onto both hands; his
## legs shoot out behind him and his arms give, and he is flat on his front;
## he lies there a moment; presses himself up; and gets first the foot that was
## in front under him, then the other, and stands. Heights are above the ground.
const SPRAWL_HIPS_Y := [0.0, 0.3, 0.16, 0.125, 0.46, 0.125, 0.62, 0.27, 0.74, 0.34, 0.84, 0.4]
const SPRAWL_HIPS_Z := [0.0, 0.04, 0.16, 0.03, 0.62, 0.0, 0.74, -0.03, 0.84, 0.0]
const SPRAWL_LEAN := [0.0, 0.9, 0.08, 1.35, 0.16, 1.6, 0.46, 1.6, 0.62, 1.22, 0.74, 1.0, 0.84, 0.6]
const SPRAWL_ARCH := [0.0, -0.2, 0.16, 0.0, 0.46, 0.04, 0.62, 0.0, 0.74, -0.3, 0.84, -0.2]
## Which way his head is tipped, down positive: into the ground, then up to see where he is.
const SPRAWL_CHIN := [0.0, 0.4, 0.16, 1.0, 0.46, 0.9, 0.6, -0.25, 0.84, -0.1]
## The ankle of the leg that was in front, and how far its toes are down; and of the one whose knee was.
## (Neither foot is moved as he goes down: the Player carries him forward over
## them by Player.SPRAWL_THROW, so here they fall behind by as much. The back
## one, already behind him, is at the end of its leg and drags.)
const SPRAWL_FRONT_Z := [0.0, 0.19, 0.16, -0.48, 0.62, -0.48, 0.75, 0.1, 1.0, 0.1]
const SPRAWL_FRONT_PITCH := [0.0, 0.0, 0.16, 1.25, 0.62, 1.1, 0.75, 0.0]
const SPRAWL_BACK_Z := [0.0, -0.3, 0.16, -0.54, 0.7, -0.54, 0.84, -0.08]
const SPRAWL_BACK_PITCH := [0.0, 1.15, 0.16, 1.3, 0.7, 1.1, 0.84, 0.15]

## Swinging a bat, as a batter does, drawn against how far through the swing
## he is. He loads: his weight goes back, his front knee comes up, the bat is
## cocked further behind him. He strides out onto his front foot; his hips and
## chest come round, and the bat, which has hung back behind his hands, drops
## into the plane of the swing and is whipped through late; it meets the ball
## level, his arms at full stretch (Player.SWING_HITS); and it goes on round
## and up over his front shoulder, his hands folding in after it.
## Which way his chest is turned (his left positive), and which way the bat
## points, as an angle round him from straight ahead.
const SWING_TURN := [0.0, -0.45, 0.25, -1.05, 0.4, -0.5, 0.5, 0.35, 0.68, 1.1, 1.0, 1.25]
const SWING_ANGLE := [0.0, -2.2, 0.25, -2.9, 0.4, -1.9, 0.5, 0.0, 0.6, 1.5, 0.78, 2.6, 1.0, 2.95]
## How far the bat points upward (0: level), and where his hands are: how far
## round him (as the bat's angle is measured), how far out from him, how high.
const SWING_TILT := [0.0, 0.9, 0.25, 0.8, 0.4, 0.3, 0.5, 0.02, 0.64, 0.2, 0.85, 0.7, 1.0, 0.9]
const SWING_HANDS := [0.0, -1.4, 0.25, -1.75, 0.4, -1.0, 0.5, 0.15, 0.66, 1.1, 1.0, 1.7]
const SWING_REACH := [0.0, 0.16, 0.25, 0.13, 0.4, 0.24, 0.5, 0.36, 0.62, 0.37, 0.85, 0.22, 1.0, 0.16]
const SWING_HANDS_Y := [0.0, 0.95, 0.25, 1.0, 0.4, 0.92, 0.5, 0.82, 0.7, 0.9, 1.0, 1.04]
## His hips: how far forward of where he stood (back, as he loads; then on over
## his front foot), and how far down. And how far his front foot strides out.
const SWING_HIPS_Z := [0.0, 0.0, 0.25, -0.07, 0.4, 0.0, 0.5, 0.08, 0.75, 0.1, 1.0, 0.04]
const SWING_HIPS_Y := [0.0, 0.0, 0.25, -0.03, 0.5, -0.07, 0.8, -0.03, 1.0, 0.0]
const SWING_STRIDE := [0.0, 0.0, 0.14, 0.0, 0.4, 0.24, 1.0, 0.2]

## Throwing, as a ball player does, drawn the same way against how far through
## the throw he is. He turns side on, his front knee coming up and the ball
## going back behind his head; strides out onto that foot; his hips come round,
## then his chest, then the arm over the top, and it is gone (Player.THROW_RELEASE);
## and he follows through, the arm on down across him and his back leg round after it.
## Which way his chest is turned (his left positive), and how far he leans into it.
const PITCH_TURN := [0.0, 0.0, 0.26, -1.15, 0.4, -1.05, 0.56, 0.5, 0.72, 0.9, 1.0, 0.0]
const PITCH_LEAN := [0.0, 0.0, 0.26, -0.14, 0.4, 0.0, 0.56, 0.42, 0.72, 0.66, 1.0, 0.0]
const PITCH_HIPS_Y := [0.0, 0.0, 0.1, -0.035, 0.28, 0.045, 0.46, -0.1, 0.72, -0.14, 1.0, 0.0]
const PITCH_HIPS_Z := [0.0, 0.0, 0.26, -0.04, 0.5, 0.14, 0.72, 0.2, 1.0, 0.0]
## The throwing arm: how far it is turned about its own length (forearm up at
## -1.5, laid back beyond that), how far out from his side, and the elbow.
const PITCH_ARM := [0.0, -0.9, 0.26, -1.85, 0.44, -2.3, 0.56, -0.95, 0.7, -0.5, 1.0, -0.4]
const PITCH_OUT := [0.0, 0.4, 0.26, 1.35, 0.48, 1.45, 0.56, 1.2, 0.7, -0.2, 1.0, 0.2]
const PITCH_ELBOW := [0.0, -1.4, 0.26, -1.7, 0.46, -1.8, 0.56, -0.22, 0.7, -0.5, 1.0, -0.9]
## The other arm: out towards what he is throwing at, then pulled in to his chest.
const PITCH_GLOVE_OUT := [0.0, 0.2, 0.26, 1.3, 0.42, 1.3, 0.56, 0.3, 1.0, 0.2]
const PITCH_GLOVE_ELBOW := [0.0, -0.5, 0.26, -0.45, 0.42, -0.35, 0.56, -2.0, 0.8, -1.8, 1.0, -0.5]
## The foot he strides onto (ankle height, and how far ahead), and the one he drives off.
const PITCH_KICK_Y := [0.0, 0.0, 0.24, 0.36, 0.34, 0.24, 0.46, 0.0, 1.0, 0.0]
const PITCH_KICK_Z := [0.0, 0.0, 0.24, 0.1, 0.46, 0.52, 0.8, 0.52, 1.0, 0.12]
const PITCH_DRIVE_Y := [0.0, 0.0, 0.56, 0.0, 0.7, 0.16, 0.86, 0.0]
const PITCH_DRIVE_Z := [0.0, -0.04, 0.46, -0.24, 0.6, -0.3, 0.86, 0.1, 1.0, 0.0]
## Swinging on a rope, against how it is carrying him: 0 is back as fast as it
## goes, 0.5 the top of a swing (or hanging still), 1 forward as fast as it
## goes. Where a foot is (up from the ground under him, and ahead), and how
## far its toes point down.
const ROPE_LEG_Y := [0.0, 0.36, 0.25, 0.2, 0.5, 0.08, 0.75, 0.13, 1.0, 0.27]
const ROPE_LEG_Z := [0.0, -0.3, 0.25, -0.17, 0.5, 0.02, 0.75, 0.25, 1.0, 0.44]
const ROPE_LEG_TOES := [0.0, 1.0, 0.5, 0.6, 1.0, -0.15]
## Throwing a grappling hook, against how far through the throw he is (it
## leaves his hand at Player.CAST_RELEASE): swung back and down beside him,
## then forward and up, underarm, and let go as it rises; the arm follows it
## up and stays up while the hook is out. His body: how far it is turned (the
## shoulder of the throwing arm going back, then through), how far it leans,
## and how far his hips sink. The throwing arm: swung forward (negative) or
## back, out from his side, and the bend of its elbow. And the other arm,
## which is put up towards what he throws at.
const HOOK_TURN := [0.0, 0.0, 0.3, -0.55, 0.45, -0.5, 0.64, 0.3, 1.0, 0.1]
const HOOK_LEAN := [0.0, 0.0, 0.3, 0.22, 0.45, 0.2, 0.64, -0.12, 1.0, -0.1]
const HOOK_HIPS_Y := [0.0, 0.0, 0.3, -0.07, 0.45, -0.08, 0.66, 0.02, 1.0, 0.0]
const HOOK_ARM := [0.0, -0.2, 0.22, 0.75, 0.4, 1.05, 0.52, -0.6, 0.62, -1.9, 0.78, -2.45, 1.0, -2.25]
const HOOK_OUT := [0.0, 0.3, 0.3, 0.5, 0.6, 0.25, 1.0, 0.2]
const HOOK_ELBOW := [0.0, -0.5, 0.3, -0.3, 0.52, -0.55, 0.64, -0.1, 1.0, -0.25]
const HOOK_GUIDE := [0.0, -0.3, 0.3, -1.25, 0.5, -1.2, 0.7, -0.5, 1.0, -0.4]
## Its rope coming taut in his hands, against how long ago it did: how far he is
## stretched out under it, jerked off his feet, before he gathers himself.
const TAUT_JOLT := [0.0, 0.0, 0.22, 1.0, 0.55, 0.35, 1.0, 0.0]
## Winding the rope back in, against how far through one pull a hand is: it
## reaches out up the line and is drawn back to his chest, the two hands turn about.
const REEL_ARM := [0.0, -1.4, 0.5, -0.8, 1.0, -1.4]
const REEL_ELBOW := [0.0, -0.85, 0.5, -1.8, 1.0, -0.85]

## A back tuck, against how far through it he is: how far over backwards he has
## turned, radians (once round), and how tightly he is tucked. He goes up
## stretched, snaps into the tuck, and opens out early to see the ground coming.
const FLIP_TURN := [0.0, 0.0, 0.1, -0.12, 0.26, -1.5, 0.46, -3.7, 0.64, -5.3, 0.8, -6.05, 0.92, -6.2832, 1.0, -6.2832]
const FLIP_TUCK := [0.0, 0.0, 0.1, 0.05, 0.26, 0.95, 0.56, 1.0, 0.76, 0.25, 0.9, 0.0, 1.0, 0.0]
## Sitting down, against how far down he is (see Player.sit_progress): he
## squats, puts a hand back to the ground, lets his seat down behind his heels,
## and leans back on that hand. Getting up is the same backwards. How high his
## hips are and how far back, how far forward he leans, and how his back is curled.
const SIT_HIPS_Y := [0.0, 0.57, 0.34, 0.33, 0.62, 0.19, 0.8, 0.125, 1.0, 0.122]
const SIT_HIPS_Z := [0.0, 0.0, 0.34, -0.11, 0.62, -0.2, 0.8, -0.23, 1.0, -0.21]
const SIT_LEAN := [0.0, 0.0, 0.34, 0.78, 0.62, 0.6, 0.8, 0.12, 1.0, -0.2]
const SIT_ARCH := [0.0, 0.0, 0.34, -0.3, 0.62, -0.42, 1.0, -0.46]
## Lying down from there, against Player.lie_progress: how far he has gone over
## onto his side (1: flat on it).
const LIE_ROLL := [0.0, 0.0, 0.2, 0.1, 0.55, 0.62, 0.8, 0.96, 1.0, 1.0]
## Coming down from a jump onto his feet, against the time since he landed (as a
## part of LAND_TAKES): how far he has given at the knees. Down quickly, held a
## moment, and up again more slowly.
const LAND_GIVE := [0.0, 0.0, 0.2, 1.0, 0.42, 0.85, 1.0, 0.0]
const LAND_TAKES := 0.42

## Use the demade, low-poly model (models/boy_lo.glb).
@export var low_poly := false
## A different figure on the same skeleton (the mummy). Overrides `low_poly`.
@export var model: PackedScene
## Arms held out ahead, 0..1, for something that walks with its hands reaching.
@export_range(0.0, 1.0) var arms_reach := 0.0
## Extra forward hunch, radians.
@export var stoop := 0.0
## How loosely he carries himself, 0..1: the slack in his ankles and wrists,
## the way one part of him follows another a moment late, and how much one step
## differs from the next. The mummy, which has none of his ease, is given little.
@export_range(0.0, 1.0) var looseness := 1.0
## Flat bands of light and a dark outline, instead of smooth shading.
@export var cel_shaded := true
## Puffs of dust where his feet come down and where he slides.
@export var dusty := true
## Multiplies every puff of dust the rig raises itself (0: none), so that
## something else can take over on other ground. (See `footfall` and `scraped`.)
var dust_scale := 1.0
## How far the whole figure is drawn lower than its body, metres: feet and all,
## as into soft ground. Eased; nothing but what is seen is moved.
var sink := 0.0
## The colours the model was made in, by material name (see Toon.colours_of).
var made_colours := {}
## How this figure is turned out (see restyle). Left empty, the boy is as
## Settings has him and any other figure is as it was made. Keys, all optional:
## "colours" (material name -> Color), "cap" (bool), "hair" (String), and
## "parts" (slot -> option).
var look := {}
## Which leg he braces against a wall he hangs from, and which knee goes down
## in a hard landing (0 the left, 1 the right): -1 leaves it to chance each time.
@export_range(-1, 1) var favoured_leg := -1


## Something that hangs from the figure and swings behind its movement: a bone
## pivoting where it roots, its far end on a spring. The hem and the hair.
class Dangle:
	var bone := -1
	var parent: Node3D
	var origin := Vector3.ZERO
	## Which way it lies at rest, in its parent's space, and how far it reaches.
	var rest := Vector3.DOWN
	var length := 0.1
	var stiffness := 170.0
	var damping := 9.0
	## How much the air holds it back as he moves.
	var drag := 1.2
	var gravity := 9.8
	## How far it may swing from rest, radians.
	var limit := 0.7
	## Outwards from the body, in its parent's space: it cannot swing in past this.
	var outward := Vector3.ZERO
	## Which way round the body it sits, for what the legs do to it (the hem only).
	var hem := false
	var front := 0.0
	var side := 0.0
	var tip := Vector3.ZERO
	var velocity := Vector3.ZERO
	var rest_tip := Vector3.ZERO


## Whoever this figure is: the Player, or any body with the same shape (velocity,
## is_on_floor(), walk_speed, run_speed, is_pushing). Its jumped, landed and
## respawned signals are used if it has them.
var _player
var _hips: Node3D
var _spine: Node3D
## The upper back and the neck. Null on a figure that has none.
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _toes: Array[Node3D] = []
## Helpers, on a figure that has the bones: one at each knee and one at each
## hip, turned half as far as the joint, so what is skinned near a joint bends
## in two easy folds and keeps its shape, not one hard one.
var _knees: Array[Node3D] = []
var _seats: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hands: Array[Node3D] = []
## Each hand's fingers, index to little, as [knuckle, middle, tip] joints; the
## way each points at rest; and the same for the two joints of each thumb.
## Empty on a figure whose hands are all one piece.
var _fingers: Array[Array] = [[], []]
var _finger_lines: Array[Array] = [[], []]
var _thumbs: Array[Array] = [[], []]
var _thumb_lines: Array[Vector3] = [Vector3.DOWN, Vector3.DOWN]
## How closed each hand is (0 flat, 1 loose, 1.4 a fist) and how spread its fingers are.
var _curl: Array[float] = [0.4, 0.4]
var _splay: Array[float] = [0.3, 0.3]
var _dangles: Array[Dangle] = []
var _dangles_settled := false
## Where each hand is reaching, in the rig's own space, and whether it was last frame.
var _hand_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _reach_held := false
var _skeleton: Skeleton3D
var _joints: Array[Node3D] = []
var _bones: Array[int] = []
## For each joint: 0, or which arm it belongs to (1 left, -1 right; doubled for the shoulder itself).
var _arm_sides: Array[int] = []

var _time := 0.0
var _phase := 0.0
var _move := 0.0
var _run := 0.0
## Flat out, 0..1, and how firmly a hand is clapped to his cap, which it then is.
var _sprint := 0.0
var _hat := 0.0
## Which hand that is: the one on the side the camera is (0 the left, 1 the
## right), so that it is seen. It is not changed while it is on his cap.
var _hat_arm := 0
## Whether he has his cap on at all (see Settings.cap).
var _capped := true
var _air := 0.0
var _push := 0.0
var _crouch := 0.0
var _crouch_velocity := 0.0
var _lean := Vector2.ZERO
var _accel := Vector3.ZERO
var _yaw_rate := 0.0
var _prev_velocity := Vector3.ZERO
var _prev_yaw := 0.0
var _lead_leg := 0
## Where each foot was in its cycle last frame, to catch it leaving the ground
## and coming down again.
var _foot_phase: Array[float] = [0.0, 0.5]
## No two steps are alike. Each is a little off the last in (how wide it lands,
## how far the toes turn out, how high it is lifted), each -1..1: what the foot
## is leaving, and what it is on its way to.
var _step_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Each foot's pitch as it is actually carried, and how fast that is turning:
## off the ground it hangs from the ankle on a spring instead of being held.
var _foot_pitch: Array[float] = [0.0, 0.0]
var _foot_spin: Array[float] = [0.0, 0.0]
## Where the shoulders rest, which they are shrugged and rolled away from.
var _shoulder_rest: Array[Vector3] = []
## Pulses to 1 at take-off and at touch-down, then fades.
var _launch := 0.0
var _land := 0.0
## Braking against his own momentum, 0..1.
var _skid := 0.0
## Blends towards each of the poses a Player can be in, 0..1.
var _duck := 0.0
var _slide := 0.0
## Which way round he slides: 1 with his right hand down behind him and his left
## leg out in front, -1 the other way. The hand that is down is the one away
## from the camera, which leaves the other for his cap.
var _slide_side := 1.0
var _hang := 0.0
var _climb := 0.0
var _rope := 0.0
var _rope_phase := 0.0
## On a ladder, 0..1, and where each foot is on its way to, in the rig's own space.
var _ladder := 0.0
var _foot_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## In the water, 0..1; under it; getting somewhere, rather than treading water;
## going fast (a crawl on top, a flutter kick below); and where he is in his stroke.
var _swim := 0.0
var _under := 0.0
var _swim_go := 0.0
var _swim_fast := 0.0
var _stroke := 0.0
## Down on hands and knees, 0..1.
var _crawl := 0.0
## Holding a bat, 0..1; swinging it, and how far through the swing he is; and
## where the bat is held and which way it points, in the rig's own space.
var _bat := 0.0
## How far he is holding a torch up (anything he carries that is in the group `torches`).
var _torch := 0.0
## How far he is holding a grappling hook's coil at his side (anything he
## carries that is in the group `grapples`); how far through throwing it he
## is, and how far into that throw (or its follow-through, while the hook is
## out); and how far through winding it in, and how far into that.
var _coil := 0.0
var _cast_at := 1.0
var _casting := 0.0
var _reel_at := 1.0
var _reeling := 0.0
var _taut := 0.0
var _swinging := 0.0
var _swing_at := 1.0
var _bat_grip := Vector3(-0.16, 0.95, 0.1)
var _bat_dir := Vector3(-0.25, 0.9, -0.35)
## Run off his legs, 0..1: it builds while he sprints and passes slowly. And
## bent over with his hands on his knees getting his breath back, which he does
## when he stops with enough of it.
var _winded := 0.0
var _tired := 0.0
## How long he has been bent over getting his breath, and wiping his face, 0..1.
var _tired_time := 0.0
var _wipe := 0.0
## Standing about with something in his hand, he tosses it up and catches it:
## where he is in that, 0..1 (it is in the air for the first third).
var _juggle := 0.0
var _carry := 0.0
## Stooping for something, 0..1, and how firmly his hand is on it; winding up
## and throwing, 0..1, and how far through that he is.
var _stoop := 0.0
var _grab := 0.0
var _picking := 1.0
## Where what he is stooping for lies, in the rig's own space.
var _pick_at := Vector3.ZERO
var _pitching := 0.0
var _pitch_at := 1.0
## How firmly the hands are held to the points the body gives them, 0..1, and
## how far they are pressed flat against a surface rather than gripping.
var _reach := 0.0
var _flat := 0.0
## How far the fingers are bent over at the knuckles, hooked on an edge, 0..1.
var _hook := 0.0
## Which way the surface under his hands faces and which way his fingers lie on it, eased.
var _press_normal := Vector3.ZERO
var _press_fingers := Vector3.ZERO
## Where the rig itself wants each hand put (in its own space), and how firmly:
## a fist on the ground, a hand down to catch himself. And how far that hand is
## laid flat there, fingers along `_plant_fingers`, rather than set down on its knuckles.
var _plant_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _plant: Array[float] = [0.0, 0.0]
var _plant_flat: Array[float] = [0.0, 0.0]
var _plant_fingers: Array[Vector3] = [Vector3.BACK, Vector3.BACK]
## Which way that arm's elbow points, if it matters (zero: down and out).
var _plant_pole: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## The edge he is hanging from, in the rig's own space; how far below it the
## ground was when he caught it; whether there is wall under it; and how fast
## he is going along it, his left positive, -1..1.
var _ledge := Vector3(0.0, 1.27, 0.22)
var _ledge_drop := 1.27
var _wall := 1.0
var _shimmy := 0.0
## Hard landings, each 0..1: down on three points, gone sprawling, stumbling,
## rolling; how far through the landing he is; and how tightly he is tucked
## into a ball. And scrambling up off his front at a run, 0..1.
var _three := 0.0
var _sprawled := 0.0
var _scramble := 0.0
var _stumble := 0.0
var _roll := 0.0
var _recovery := 1.0
var _spinning := false
var _ball := 0.0
## Which landing he is in, or was last; how far through the turning-over part of
## it he is; and which knee he went down on (and so which hand): 0 left, 1 right.
var _taking := 0
var _tumble := 1.0
var _down := 1
## The leg he has against the wall he hangs from, and how far his feet have
## walked along it as he works sideways.
var _brace := 0
var _wall_walk := 0.0
var _travel := 0.0
## His cap, if it has a bone of its own: it rides on his head on a spring. Where
## it is (in the world), how fast it is going, and how far it has lifted and tipped.
var _cap: Node3D
var _figure: Node3D
var _cap_rest := Vector3.ZERO
var _cap_off := Vector3.ZERO
var _cap_velocity := Vector3.ZERO
var _cap_settled := false
var _cap_was := Vector3.ZERO
var _cap_was_velocity := Vector3.ZERO
var _dust: Dust
var _dust_timer := 0.0
## How much of a running jump this one is, 0 (straight up) to 1.
var _leap := 0.0
## Standing still, 0..1, split between his two ways of standing: at ease, with
## his weight on one leg, and wary, when something is after him.
var _casual := 0.0
var _wary := 0.0
var _alert := 0.0
## Which leg he is standing on while at ease: 1 the left, -1 the right.
var _weight := 0.0
## Out of breath, 0..1: builds as he runs and takes a while to pass.
var _puff := 0.0
var _breath := 0.0
## Where he is looking, as (turn, tilt) away from straight ahead, radians.
var _look := Vector2.ZERO
## His eyes, if the model has bones for them (`eye_l`, `eye_r`), and how far
## they are turned from straight ahead: they go to what he looks at before his
## head does, and come back to the middle as it catches up.
var _eye_joints: Array[Node3D] = []
var _eye_turn := Vector2.ZERO
## What has caught his eye, how long he has looked at it, and what he has
## looked at enough for now (instance id -> when it becomes interesting again).
var _interest: Node3D
var _interest_time := 0.0
var _interest_is_threat := false
var _bored := {}
var _look_timer := 0.0
## The ragdoll, while limp: its container and each (pose node, rigid body) pair, parents first.
var _ragdoll: Node3D
var _limbs: Array[Array] = []
var _sunk := 0.0
## Whether each foot is on the ground.
var _planted: Array[bool] = [true, true]
## Kicking off a wall, 1 fading to 0; where on it his foot was, in the world; and which leg.
var _kick := 0.0
var _kick_point := Vector3.ZERO
var _kick_leg := 0
## Going into water with a splash, 1 fading to 0. Wet, 0..1, which passes when he
## is out of it; shaking it off, 1 running down to 0, which he does once; and
## tossing the hair out of his eyes as he comes up.
var _plunge := 0.0
var _wet := 0.0
var _shake := 0.0
var _shaken := true
var _toss := 0.0
var _was_under := false
## How clear the water ahead of him is, eased (see Player.swim_clear).
var _swim_clear := 1.0
## What he threw last, which he watches go, and for how much longer.
var _watch: Node3D
var _watching := 0.0
## On a rope: how fast it is carrying him forwards and to his left, eased, and
## whether he is going up it (1) or down (-1).
var _rope_swing := Vector2.ZERO
var _rope_climb := 0.0
## And how hard he is swinging on it, 0..1: enough, and his legs let go of it.
var _rope_ride := 0.0
## On a ladder: going up (1) or down (-1), eased; how long he has been still;
## hanging off it by one hand to look about, 0..1; getting off the top, 0..1;
## and how far each hand has let go of what the body gives it.
var _ladder_go := 0.0
var _ladder_still := 0.0
var _ladder_rest := 0.0
var _ladder_off := 0.0
var _reach_let: Array[float] = [0.0, 0.0]
## On a flight of stairs, 0..1 (see Player.on_stairs), and going down them, 0..1.
## His feet are then put on the treads: where each is coming from and going to
## (in the world), whether that has been settled yet, and where it is now. How
## much of a stride he still has to make up to be in step with the treads; how
## far his hips are let down for a foot reaching below him; and his stride and
## how long each foot is down, for choosing where the next one goes.
var _stairs := 0.0
var _descending := 0.0
var _stair_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stair_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stair_set: Array[bool] = [false, false]
var _foot_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stair_slew := 0.0
## How far forward of where his stride would put it each foot is set down, to
## be on its tread; and how far the last one was, which it starts from.
var _stair_shift: Array[float] = [0.0, 0.0]
var _stair_left: Array[float] = [0.0, 0.0]
var _stair_drop := 0.0
var _stride_now := 1.0
## How many treads he is taking at a step, on stairs (0 off them).
var _stair_each := 0.0
## In the air (and for a moment either side of it) his arms are not held in a
## pose but thrown: each follows where it is wanted on a spring, as (pitch,
## roll, elbow), and how fast each of those is changing. How far that has taken
## over, 0..1; and what is different about this jump from the last, each -1..1.
var _arm_free := 0.0
var _arm_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _arm_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _jump_vary := Vector3.ZERO
## A jump he made himself (not a fall off something), 0..1 until he is down
## again; where he sprang from, which his legs are left reaching for; and the
## three attitudes of it, each 0..1: driven up, gathered over the top, and
## (what is left) reaching down for the ground.
var _jumped := 0.0
var _sprang_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## How far each foot was on the ground to drive him off it, 0..1.
var _drove: Array[float] = [1.0, 1.0]
var _leg_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _rise := 0.0
var _gather := 0.0
## Landed on his feet: how hard, 0..1, and how far through taking it he is.
var _give := 0.0
var _give_at := 1.0
## How far his legs are drawn up into the ball he is curled in, 0..1: a moment
## behind the rest of him.
var _legs_in := 0.0
## Going over one shoulder out of a dive: how far, and which (his left positive).
var _shouldered := 0.0
## Catching a ledge: the swing of his body in under it, which dies away.
var _sway := 0.0
var _sway_speed := 0.0
## Thrown into a dive, 0..1; how far over forwards he is in it, radians; whether
## the roll he is in came out of one, 0 or 1; how near the ground under him is,
## 0..1; and gone into water head first, 1 fading to 0.
var _dive := 0.0
var _dive_pitch := 0.0
var _dive_roll := 0.0
var _dive_near := 0.0
var _dive_in := 0.0
## Going over backwards in a tuck, 0..1; how far through it he is; how tightly he
## is tucked for it; and tucked up at all, for this or in a roll. After it he
## stands a moment as one who knows he was seen: 1 fading to 0.
var _flip := 0.0
var _flip_at := 1.0
var _tuck := 0.0
var _curled := 0.0
var _swagger := 0.0
var _cocky := 0.0
## How far into a stretch he is, 0..1 (see Player.yawn_progress).
var _stretch := 0.0
## Spinning on the spot, 0..1; how far round he has gone; how giddy he is; and
## reeling as he comes out of it, 0..1.
var _whirl := 0.0
var _whirl_phase := 0.0
var _whirl_way := 1.0
var _giddy := 0.0
var _reel := 0.0
## Resting (see Player.sit_progress and the rest): how far sat down, how far
## lain down from there, the yawn and the rub of his eyes (1: not doing it),
## startled awake, and whether he was getting down or up when last seen.
var _sit_at := 0.0
var _lie_at := 0.0
var _yawn_at := 1.0
var _rub_at := 1.0
var _startle := 0.0
## Which side he lies down on: 1 his left, -1 his right.
var _lie_side := 1.0
## How far his cap is pulled down over his face, 0..1.
var _cap_over := 0.0
## Wading, each 0..1: in water he has to step high out of, and in water up to his waist.
var _wade_low := 0.0
var _wade_high := 0.0
## A gun in his hands, 0..1; a long one, held in both; how far up to aim it is;
## the kick of it, which he takes and recovers from, and how fast that is
## changing. Which way it points and where its grip is, in the rig's own space;
## where the off hand belongs on it, in the gun's; and where it is in the world.
var _gun := 0.0
var _gun_long := 0.0
var _aiming := 0.0
var _recoil := 0.0
var _recoil_speed := 0.0
var _gun_dir := Vector3(0.0, -0.7, 0.7)
var _gun_grip := Vector3(-0.2, 0.5, 0.1)
var _gun_support := Vector3(0.0, 0.0, -0.36)
var _gun_now := Transform3D.IDENTITY


func _ready() -> void:
	_build()
	_player = get_parent()
	if _player and _player.has_signal(&"jumped"):
		_player.jumped.connect(_on_jumped)
		_player.landed.connect(_on_landed)
		_player.respawned.connect(_on_respawned)
	if _player and _player.has_signal(&"kicked_off"):
		# (he springs off the wall from one leg, and out of it as out of a running jump)
		_player.kicked_off.connect(_on_kicked_off)
	if _player and _player.has_signal(&"splashed"):
		# (in feet first he flounders; in head first, in a dive, he does not)
		_player.splashed.connect(func(speed: float) -> void: _plunge = 0.0 if &"dive_in" in _player and _player.dive_in > 0.0 else clampf(speed / 7.0, 0.2, 1.0))
	if _player and _player.has_signal(&"threw"):
		_player.threw.connect(_on_threw)
	if _player and _player.has_signal(&"shot"):
		_player.shot.connect(_on_shot)
	if _player and _player.has_signal(&"dived"):
		_player.dived.connect(_on_dived)
	_prev_yaw = rotation.y


func _process(delta: float) -> void:
	if _player == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	if _ragdoll:
		_follow_ragdoll()
		_apply_pose()
		_swing(delta)
		return
	_time += delta

	var velocity: Vector3 = _player.velocity
	# On a rope he goes where it takes him, however fast: that is its doing and
	# not his, and only the swing of it comes into how he holds himself.
	var swung := velocity
	if &"state" in _player and _player.state == Player.State.ROPE:
		velocity = Vector3.ZERO
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var grounded: bool = _player.is_on_floor() or (&"air_time" in _player and _player.air_time < 0.1)

	# What the body is up to beyond walking and jumping. Only a Player does any
	# of it; the mummy, on the same rig, has none of these.
	var doing: int = _player.state if &"state" in _player else 0
	var ducking: bool = _player.is_ducking if &"is_ducking" in _player else false
	var holding: bool = &"carried" in _player and _player.carried != null
	var hanging := doing == Player.State.HANG or doing == Player.State.CLIMB
	# (he gets down, and up again, without hurry)
	_duck = _approach(_duck, 1.0 if ducking and doing == Player.State.FREE else 0.0, 8.0, delta)
	# The hand the camera can see is the one for his cap; sliding, the other goes down behind him.
	var camera := get_viewport().get_camera_3d()
	if camera and _hat < 0.05 and _slide < 0.05:
		var across := to_local(camera.global_position).x
		if absf(across) > 0.4:
			_hat_arm = 0 if across > 0.0 else 1
	if holding:
		_hat_arm = 0
	if doing == Player.State.SLIDE and _slide < 0.05:
		_slide_side = 1.0 if _hat_arm == 0 else -1.0
	_slide = _approach(_slide, 1.0 if doing == Player.State.SLIDE else 0.0, 14.0, delta)
	# Which leg he braces with is settled as he catches hold.
	if hanging and _hang < 0.02:
		_brace = favoured_leg if favoured_leg >= 0 else randi() % 2
		# (and his body swings in under it as he does)
		_sway_speed = 2.2 + minf(speed, 4.0) * 0.4
	_sway_speed += (-_sway * 70.0 - _sway_speed * 5.5) * delta
	_sway += _sway_speed * delta
	_hang = _approach(_hang, 1.0 if hanging else 0.0, 16.0, delta)
	if doing == Player.State.CLIMB:
		_climb = _player.climb_progress
	elif doing == Player.State.HANG or _hang < 0.02:
		# (once up, it stays "finished" while the hang pose fades, or the arms
		# would snap back overhead for an instant)
		_climb = 0.0
	_rope = _approach(_rope, 1.0 if doing == Player.State.ROPE else 0.0, 14.0, delta)
	_ladder = _approach(_ladder, 1.0 if doing == Player.State.LADDER else 0.0, 12.0, delta)
	_swim = _approach(_swim, 1.0 if doing == Player.State.SWIM else 0.0, 7.0, delta)
	_under = _approach(_under, 1.0 if doing == Player.State.SWIM and _player.is_underwater else 0.0, 5.0, delta)
	# (coming up to a wall he stops swimming at it and comes upright)
	_swim_clear = _approach(_swim_clear, _player.swim_clear if doing == Player.State.SWIM and &"swim_clear" in _player else 1.0, 10.0, delta)
	_swim_go = _approach(_swim_go, clampf(speed / 0.9, 0.0, 1.0) * smoothstep(0.0, 0.7, _swim_clear), 5.0, delta)
	_swim_fast = _approach(_swim_fast, smoothstep(1.6, 2.2, speed), 5.0, delta)
	_stroke = fposmod(_stroke + lerpf(0.62, lerpf(0.66, 1.0, _swim_fast), _swim_go) * delta, 1.0)
	_plunge = _approach(_plunge, 0.0, 1.5, delta)
	# Coming up from under it, he tosses the hair out of his eyes. And out of
	# the water he is wet for a while: the first time he stands still he shakes it off.
	var under_now := _under > 0.5
	if _was_under and not under_now and doing == Player.State.SWIM:
		_toss = 1.0
	_was_under = under_now
	_toss = maxf(_toss - delta / 0.55, 0.0)
	if doing == Player.State.SWIM:
		_wet = 1.0
		_shaken = false
	else:
		_wet = maxf(_wet - delta / 9.0, 0.0)
	_shake = maxf(_shake - delta / 1.1, 0.0)
	_kick = _approach(_kick, 0.0, 7.5, delta)
	_watching -= delta
	# On a rope: which way it is carrying him, and whether he is climbing.
	var carried_along := Vector2(swung.dot(global_basis.z), swung.dot(global_basis.x)) if doing == Player.State.ROPE else Vector2.ZERO
	_rope_swing = _rope_swing.lerp(carried_along, 1.0 - exp(-6.0 * delta))
	var hauling: float = clampf((_player.rope_travel - _rope_phase) / delta / 1.5, -1.0, 1.0) if doing == Player.State.ROPE else 0.0
	_rope_climb = _approach(_rope_climb, hauling, 8.0, delta)
	# Swinging in earnest his legs leave the rope and go with the swing; they
	# stay off it through the top of each swing, and come back to it to climb.
	_rope_ride = maxf(_rope_ride - delta * 0.6, smoothstep(1.4, 3.6, swung.length())) if doing == Player.State.ROPE else 0.0
	# On a ladder: going up or down; and left alone a moment he hangs off it by one hand.
	var on_ladder := doing == Player.State.LADDER
	_ladder_off = _player.ladder_off if on_ladder and &"ladder_off" in _player else _approach(_ladder_off, 0.0, 12.0, delta)
	_ladder_go = _approach(_ladder_go, clampf(velocity.y / 1.5, -1.0, 1.0) if on_ladder and _ladder_off <= 0.0 else 0.0, 9.0, delta)
	_ladder_still = _ladder_still + delta if on_ladder and absf(velocity.y) < 0.05 and _ladder_off <= 0.0 else 0.0
	_ladder_rest = _approach(_ladder_rest, 1.0 if _ladder_still > 0.9 else 0.0, 3.5 if _ladder_still > 0.9 else 9.0, delta)
	_crawl = _approach(_crawl, 1.0 if &"is_crawling" in _player and _player.is_crawling else 0.0, 7.0, delta)
	_bat = _approach(_bat, 1.0 if holding and _player.carried.is_in_group(&"bats") else 0.0, 9.0, delta)
	_swing_at = _player.swing_progress if &"swing_progress" in _player else 1.0
	# (he holds the end of a swing a moment, and brings the bat back unhurried)
	var swinging_now := smoothstep(0.0, 0.08, _swing_at) if _swing_at < 1.0 else 0.0
	_swinging = _approach(_swinging, swinging_now, 30.0 if swinging_now > _swinging else 5.5, delta)
	# With something in his hand and nothing to do, he tosses it and catches it.
	_torch = _approach(_torch, 1.0 if holding and _player.carried.is_in_group(&"torches") else 0.0, 8.0, delta)
	if holding and _bat < 0.5 and _gun < 0.5 and _torch < 0.5 and _coil < 0.5 and _casual > 0.8 and _carry > 0.95:
		_juggle = fposmod(_juggle + delta / 2.1, 1.0)
	else:
		_juggle = 0.4 if _juggle > 0.34 or _juggle < 0.001 else minf(_juggle + delta / 2.1, 0.4)
	if doing == Player.State.ROPE:
		_rope_phase = _player.rope_travel
	_carry = _approach(_carry, 1.0 if holding else 0.0, 10.0, delta)
	_stretch = sin(PI * smoothstep(0.06, 0.94, _player.yawn_progress)) if &"yawn_progress" in _player and _player.yawn_progress < 1.0 else 0.0
	_cocky = smoothstep(0.0, 0.2, 1.0 - _swagger) * smoothstep(0.0, 0.3, _swagger) * (1.0 - _move) * (1.0 - _air) if _swagger > 0.0 else 0.0
	# A gun: brought up to aim when the Player says, and the kick of it taken and got over.
	var gunning: bool = holding and _player.carried.is_in_group(&"guns") and _player.get(&"gun_handling") == true
	if gunning:
		var long: bool = _player.carried.get(&"two_handed") == true
		_gun_long = (1.0 if long else 0.0) if _gun < 0.05 else _approach(_gun_long, 1.0 if long else 0.0, 12.0, delta)
		if _player.carried.has_method(&"support_point"):
			_gun_support = _player.carried.to_local(_player.carried.support_point())
	_gun = _approach(_gun, 1.0 if gunning else 0.0, 9.0, delta)
	var raised: float = _player.gun_raise if gunning and &"gun_raise" in _player else 0.0
	_aiming = smoothstep(0.0, 1.0, raised) if gunning else _approach(_aiming, 0.0, 12.0, delta)
	_recoil_speed += (-_recoil * 240.0 - _recoil_speed * 19.0) * delta
	_recoil += _recoil_speed * delta
	# Thrown into a dive; over backwards in a tuck; spinning, and reeling out of it.
	var diving: bool = &"is_diving" in _player and _player.is_diving
	if diving:
		# (how far over he is goes with the way he is flying: up, along, and down onto his hands)
		var wanted := clampf(1.32 + atan2(-velocity.y, maxf(speed, 1.0)) * 0.95, 1.0, 2.1)
		_dive_pitch = _approach(_dive_pitch, wanted, 9.0, delta)
		var below := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 2.0, 1))
		var gap: float = global_position.y - (below.position as Vector3).y if not below.is_empty() else 2.0
		_dive_near = _approach(_dive_near, (1.0 - smoothstep(0.1, 0.85, gap)) if velocity.y < 0.0 else 0.0, 16.0, delta)
	_dive = _approach(_dive, 1.0 if diving else 0.0, 13.0 if diving else 15.0, delta)
	_dive_in = _player.dive_in if &"dive_in" in _player and doing == Player.State.SWIM else _approach(_dive_in, 0.0, 8.0, delta)
	_flip_at = _player.flip_progress if &"flip_progress" in _player else 1.0
	_flip = _approach(_flip, 1.0 if _flip_at < 1.0 else 0.0, 30.0 if _flip_at < 1.0 else 12.0, delta)
	_tuck = _keyed(FLIP_TUCK, _flip_at) if _flip_at < 1.0 else 0.0
	_swagger = maxf(_swagger - delta / 2.2, 0.0)
	var whirling: bool = &"is_spinning" in _player and _player.is_spinning
	if whirling:
		_whirl_way = _player.spin_way
	_whirl = _approach(_whirl, 1.0 if whirling else 0.0, 13.0 if whirling else 7.0, delta)
	_giddy = _player.dizzy if &"dizzy" in _player else 0.0
	_reel = _approach(_reel, _player.stagger if &"stagger" in _player else 0.0, 12.0, delta)
	# Resting: the Player says how far down he is.
	var sat: float = _player.sit_progress if &"sit_progress" in _player else 0.0
	if sat > 0.0 and _sit_at <= 0.0:
		# (he lies down facing whoever is watching, more or less)
		_lie_side = 1.0 if _hat_arm == 1 else -1.0
	_sit_at = sat
	_lie_at = _player.lie_progress if &"lie_progress" in _player else 0.0
	_yawn_at = _player.yawn_progress if &"yawn_progress" in _player else 1.0
	_rub_at = _player.rub_progress if &"rub_progress" in _player else 1.0
	_startle = _player.startled if &"startled" in _player else 0.0
	_cap_over = _approach(_cap_over, smoothstep(0.62, 0.86, _lie_at), 10.0, delta)
	var depth: float = _player.wade if &"wade" in _player and doing == Player.State.FREE else 0.0
	_wade_low = _approach(_wade_low, smoothstep(0.08, 0.28, depth) * (1.0 - smoothstep(0.42, 0.75, depth)), 6.0, delta)
	_wade_high = _approach(_wade_high, smoothstep(0.42, 0.85, depth), 6.0, delta)
	# Stooping for something, and throwing it: the Player says how far through each he is.
	_picking = _player.pickup_progress if &"pickup_progress" in _player else 1.0
	if _picking < 1.0:
		_pick_at = to_local(_player.pickup_point)
	_stoop = _approach(_stoop, smoothstep(0.0, 0.36, _picking) * (1.0 - smoothstep(0.62, 1.0, _picking)), 30.0, delta)
	_grab = smoothstep(0.1, 0.42, _picking) * (1.0 - smoothstep(Player.PICKUP_TAKES, Player.PICKUP_TAKES + 0.16, _picking))
	_pitch_at = _player.throw_progress if &"throw_progress" in _player else 1.0
	_pitching = _approach(_pitching, smoothstep(0.0, 0.1, _pitch_at) * (1.0 - smoothstep(0.82, 1.0, _pitch_at)), 30.0, delta)
	# A grappling hook: held, thrown (and still out), its rope coming taut, wound in.
	_coil = _approach(_coil, 1.0 if holding and _player.carried.is_in_group(&"grapples") else 0.0, 8.0, delta)
	_cast_at = _player.cast_progress if &"cast_progress" in _player else 1.0
	var casting_now := smoothstep(0.0, 0.1, _cast_at) if _cast_at < 1.0 else (1.0 if &"hook_out" in _player and _player.hook_out and doing == Player.State.FREE else 0.0)
	_casting = _approach(_casting, casting_now, 30.0 if casting_now > _casting else 7.0, delta)
	_reel_at = _player.reel_progress if &"reel_progress" in _player else 1.0
	_reeling = _approach(_reeling, smoothstep(0.0, 0.12, _reel_at) * (1.0 - smoothstep(0.85, 1.0, _reel_at)) * (1.0 - _rope), 20.0, delta)
	_taut = _keyed(TAUT_JOLT, _player.taut_progress) * _rope if &"taut_progress" in _player else 0.0
	_reach = _approach(_reach, _player.hand_reach if &"hand_reach" in _player else 0.0, 14.0, delta)
	var pressing: bool = &"hand_normal" in _player and _player.hand_normal != Vector3.ZERO
	_flat = _approach(_flat, 1.0 if pressing else 0.0, 14.0, delta)
	_hook = _approach(_hook, _player.hand_hook if &"hand_hook" in _player else 0.0, 14.0, delta)
	if doing != Player.State.FREE:
		grounded = true
	if hanging:
		_ledge = to_local(_player.ledge_point)
		_wall = _approach(_wall, 1.0 if _player.ledge_wall else 0.0, 8.0, delta)
		if doing == Player.State.HANG:
			_ledge_drop = _ledge.y
	_shimmy = _approach(_shimmy, clampf(velocity.dot(global_basis.x) / _player.shimmy_speed, -1.0, 1.0) if doing == Player.State.HANG else 0.0, 9.0, delta)
	# A hard landing: which kind, and how far through it he is.
	var taking: int = _player.landing if &"landing" in _player and _player.landing_progress < 1.0 else 0
	if taking != 0:
		if _player.landing_progress < _recovery or taking != _taking:
			_down = favoured_leg if favoured_leg >= 0 else randi() % 2
			_dive_roll = 1.0 if &"dive_roll" in _player and _player.dive_roll else 0.0
		_taking = taking
		_recovery = _player.landing_progress
	else:
		# (cut short, it still has to be seen through: he cannot be left halfway over)
		_recovery = minf(_recovery + delta * 3.0, 1.0)
	# A roll is a roll from the start; a stumble ends in one, when his legs
	# have failed to catch up with him.
	var rolling := _taking == Player.Landing.ROLL or (_taking == Player.Landing.STUMBLE and _recovery > STUMBLE_ROLLS)
	_tumble = _recovery if _taking == Player.Landing.ROLL else clampf(inverse_lerp(STUMBLE_ROLLS, 1.0, _recovery), 0.0, 1.0)
	_spinning = rolling and _recovery < 1.0
	if not _spinning:
		_shouldered = 0.0
	_three = _approach(_three, 1.0 if taking == Player.Landing.THREE_POINT else 0.0, 40.0 if taking != 0 else 9.0, delta)
	_sprawled = _approach(_sprawled, 1.0 if taking == Player.Landing.SPRAWL else 0.0, 40.0 if taking != 0 else 9.0, delta)
	_scramble = _approach(_scramble, 1.0 if taking == Player.Landing.SPRAWL and _player.is_scrambling else 0.0, 9.0 if taking != 0 else 5.0, delta)
	_stumble = _approach(_stumble, 1.0 if taking == Player.Landing.STUMBLE and not rolling else 0.0, 40.0 if taking != 0 and not rolling else 9.0, delta)
	_roll = _approach(_roll, 1.0 if taking != 0 and rolling else 0.0, (40.0 if taking == Player.Landing.ROLL else 30.0) if taking != 0 else 12.0, delta)
	# (he is tucked and going over at once: there is no waiting for it)
	# (out of a dive he is over sooner, having started most of the way, and up and running the sooner)
	_ball = _roll * smoothstep(0.0, 0.07, _tumble) * (1.0 - smoothstep(lerpf(0.74, 0.56, _dive_roll), lerpf(0.98, 0.84, _dive_roll), _tumble))
	_curled = maxf(_ball, _tuck * _flip)
	# (his legs are the last of him to be drawn in: going over off his feet they
	# are still on the ground behind him for a moment, and out of a dive still
	# coming over the top)
	# (not in a back tuck, which is slow enough already to need no softening)
	_legs_in = maxf(minf(_approach(_legs_in, _ball, 13.0, delta), _ball), _tuck * _flip)
	if grounded:
		_leap = clampf(speed / _player.run_speed, 0.0, 1.0)
	var travel: float = _player.shimmy_travel if &"shimmy_travel" in _player else 0.0
	_wall_walk = _wall_walk + absf(travel - _travel) if doing == Player.State.HANG else 0.0
	_travel = travel

	# (sneaking, he eases into a step and out of it)
	_move = _approach(_move, clampf(speed / _player.walk_speed, 0.0, 1.0), lerpf(10.0, 4.5, _duck), delta)
	_run = _approach(_run, clampf(inverse_lerp(_player.walk_speed, _player.run_speed, speed), 0.0, 1.0), 8.0, delta)
	var flat_out: float = clampf(inverse_lerp(_player.run_speed, _player.sprint_speed, speed), 0.0, 1.0) if &"sprint_speed" in _player else 0.0
	_sprint = _approach(_sprint, flat_out, 6.0, delta)
	# He keeps hold of his cap through a jump taken at that speed, and through
	# a slide, and lets go to land or to throw.
	var holding_on := (flat_out > 0.4 and doing == Player.State.FREE) or doing == Player.State.SLIDE
	holding_on = holding_on and _capped and taking == 0 and _pitch_at >= 1.0 and _picking >= 1.0 and _bat < 0.5 and _gun_long * _gun < 0.5 and _dive < 0.3
	_hat = _approach(_hat, 1.0 if holding_on else 0.0, 9.0 if holding_on else 5.0, delta)
	_air = _approach(_air, 0.0 if grounded else 1.0, 16.0 if grounded else 14.0, delta)
	_push = _approach(_push, 1.0 if _player.is_pushing else 0.0, 6.0, delta)
	_launch = _approach(_launch, 0.0, 11.0, delta)
	_land = _approach(_land, 0.0, 5.0, delta)
	# A jump of his own has three attitudes, and which he is in goes with how
	# fast he is going up or coming down: driven up off the ground, gathered
	# over the top of it, and reaching down for the ground again. (A fall off
	# something is only the last of them.)
	if _player.is_on_floor() and _launch < 0.2:
		_jumped = _approach(_jumped, 0.0, 16.0, delta)
	_rise = smoothstep(0.8, 4.6, velocity.y)
	_gather = (1.0 - _rise) * (1.0 - smoothstep(0.8, 5.0, -velocity.y)) * _jumped
	_give_at = minf(_give_at + delta / LAND_TAKES, 1.0)
	# Coming down out of a run, it is the leg he is reaching with that lands: his
	# stride is taken up again from there.
	if _air > 0.95 and _leap > 0.3 and velocity.y < 0.0:
		_phase = 0.02 if _lead_leg == 0 else 0.52
	# (and out of a roll he comes up onto one foot with the other coming through
	# under him, which is how his legs lie in it: not flung out behind to push)
	if _ball > 0.6:
		_phase = 0.04 if _lead_leg == 0 else 0.54

	_accel = _accel.lerp((flat - _prev_velocity) / delta, 1.0 - exp(-8.0 * delta))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(_prev_yaw, rotation.y) / delta, 1.0 - exp(-10.0 * delta))
	_prev_velocity = flat
	_prev_yaw = rotation.y
	_whirl_phase = fposmod(_whirl_phase + absf(_yaw_rate) * delta * _whirl, TAU * 8.0)

	# Landing and take-off kick this spring; it settles back on its own.
	_crouch_velocity += (-_crouch * 220.0 - _crouch_velocity * 22.0) * delta
	_crouch = clampf(_crouch + _crouch_velocity * delta, -0.03, 0.3)

	# One cycle is two steps. Advancing by distance keeps planted feet planted.
	# Pushing, he takes long slow steps and keeps both feet down for most of each.
	# He is long in the leg and strides out. Sneaking, his steps are long and
	# slow; catching himself out of a stumble, short and quick.
	var stride := lerpf(lerpf(0.82, 2.05, _run), 2.5, _sprint) * (1.0 + 0.5 * _push) * _leg_scale
	stride = lerpf(stride, 1.2 * _leg_scale, _duck) * lerpf(1.0, 0.55, _stumble)
	stride = lerpf(stride, 0.46, _crawl)
	# (wading, his steps are shorter: the water will not be hurried)
	stride *= 1.0 - 0.22 * _wade_high
	# On stairs his steps are as long as the treads are deep: one at a time at a
	# walk, two (or three, if they are shallow) at a run, and more readily going down.
	var stairs_now: float = _player.on_stairs if &"on_stairs" in _player else 0.0
	_stairs = _approach(_stairs, stairs_now * (1.0 - _duck) * (1.0 - _push), 9.0, delta)
	if _stairs > 0.01:
		var tread: float = _player.stair_run
		var riser: float = absf(_player.stair_rise)
		_descending = _approach(_descending, 1.0 if _player.stair_rise < 0.0 else 0.0, 10.0, delta)
		var each := clampf(roundf(stride * 0.5 / tread), 1.0, 3.0)
		while each > 1.0 and each * riser > lerpf(0.4, 0.5, _descending):
			each -= 1.0
		# (how many he takes at a step changes over a moment, not at once: in the
		# middle of a step it would snatch the foot back or throw it on)
		_stair_each = each if _stair_each == 0.0 else _approach(_stair_each, each, 7.0, delta)
		stride = lerpf(stride, 2.0 * _stair_each * tread, _stairs)
		var made_up := _stair_slew * (1.0 - exp(-6.0 * delta))
		_phase = fposmod(_phase + made_up * _stairs, 1.0)
		_stair_slew -= made_up
	else:
		_stair_set[0] = false
		_stair_set[1] = false
		_stair_slew = 0.0
		_stair_each = 0.0
	_stride_now = stride
	# His arms are let go as he leaves the ground, and gathered again once he is back on it.
	var loose_armed := (not grounded or _launch > 0.25 or _land > 0.25 or _whirl > 0.3) and doing == Player.State.FREE
	# (let go all at once: what they are wanted to do changes in a moment as he
	# takes off, and it is the spring that carries them from the one to the other)
	_arm_free = 1.0 if loose_armed else _approach(_arm_free, 0.0, 4.5, delta)
	var stance := lerpf(lerpf(lerpf(lerpf(0.6, 0.34, _run), 0.3, _sprint), 0.68, _push), 0.57, _duck)
	# (Once he has jumped his stride is over: the leg that was coming forward does
	# not go on to be put down on nothing.)
	if grounded and (_jumped < 0.5 or _player.is_on_floor()):
		# (a figure scaled up covers more ground per stride)
		_phase = fposmod(_phase + speed / (stride * global_basis.get_scale().y) * delta, 1.0)
	# Braking hard against his own momentum, as when the stick is thrown the other way.
	var against := -flat.dot(global_basis.z) / maxf(_player.run_speed, 0.01)
	_skid = _approach(_skid, clampf(against * 1.6, 0.0, 1.0) if grounded else 0.0, 12.0, delta)
	# (Steered as he gets up off his front, he is into his ordinary run as he
	# rises: his legs go as fast as he is going, and no faster.)
	var gait := _move * (1.0 - _air) * (1.0 - _skid) * (1.0 - _slide) * (1.0 - maxf(_hang, _rope)) * (1.0 - _ball) * (1.0 - _three) * (1.0 - _sprawled * (1.0 - _scramble * smoothstep(Player.SCRAMBLE.x + 0.14, 0.6, _recovery)))
	gait *= 1.0 - _pitching
	gait *= (1.0 - _ladder) * (1.0 - _swim) * (1.0 - _crawl)
	var resting := smoothstep(0.0, 0.14, _sit_at)
	gait *= (1.0 - _whirl) * (1.0 - resting)

	# Standing: at ease, or wary. (Only a figure with a back to stand with.)
	_look_about(delta)
	_alert = _approach(_alert, 1.0 if _interest_is_threat else 0.0, 5.0 if _interest_is_threat else 0.45, delta)
	var idle := (1.0 - _move) * (1.0 - _air) * (1.0 - maxf(_hang, _rope)) * (1.0 - _duck) * (1.0 - _slide) * (1.0 - _push) * (1.0 - maxf(_three, _sprawled))
	idle *= (1.0 - _pitching) * (1.0 - _stoop) * (1.0 - _ladder) * (1.0 - _swim)
	idle *= (1.0 - _whirl) * (1.0 - resting) * (1.0 - _reel)
	# Sprinting takes it out of him. When he stops he bends over, hands on his
	# knees, and pants until he has his breath back.
	_winded = clampf(_winded + (0.17 * _sprint - 0.07 * (1.0 - _run)) * delta, 0.0, 1.0)
	_tired = _approach(_tired, smoothstep(0.3, 0.5, _winded) if idle > 0.9 and _carry < 0.1 and _alert < 0.3 and _yawn_at >= 1.0 else 0.0, 3.5, delta)
	if _wet > 0.4 and not _shaken and idle > 0.85 and doing == Player.State.FREE:
		_shaken = true
		_shake = 1.0
	idle *= 1.0 - _tired
	idle *= 1.0 if _chest else 0.0
	_casual = idle * (1.0 - _alert)
	_wary = idle * _alert
	# He settles onto one leg for a few seconds, then shifts to the other.
	_weight = _approach(_weight, clampf(sin(_time * 0.23 + 0.6) * 4.0, -1.0, 1.0), 2.2, delta)
	_puff = _approach(_puff, _run, 0.5 if _run > _puff else 0.14, delta)
	# (asleep, he breathes slow and deep)
	_breath += (1.5 + 2.4 * _puff + 1.1 * _alert + 4.5 * _tired) * (1.0 - 0.5 * _lie_at) * delta

	_track_steps(stance, gait)
	_pose_body(speed, velocity.y, stance, gait)
	_pose_legs(stride, stance, gait)
	_pose_arms(velocity.y, gait)
	_reach_arms()
	_hold_gun()
	_bounce_cap(delta)
	_pose_extra(delta)
	_apply_pose()
	# (what he carries goes where his hand is now, not where it was a frame ago)
	if holding and _player.has_method(&"_place_carried"):
		_player._place_carried()
	_swing(delta)
	_raise_dust(flat, grounded, delta)
	_sunk = _approach(_sunk, sink, 6.0, delta)
	_figure.position.y = -_sunk


## For a rig that extends this one (the mummy's, the brother's): called each
## frame when every joint has been posed and before the pose goes to the
## skeleton, so it can lay something of its own over the top. The joints are
## ordinary nodes (`_hips`, `_spine`, `_chest`, `_neck`, `_head`, `_shoulders`,
## `_elbows`, `_hands`, `_thighs`, `_shins`, `_feet`, `_toes`, left then right);
## `_solve_arm`, `_solve_leg`, `_lay_hand`, `_keyed`, `_approach` and `_dangle`
## are there to be used. Does nothing here.
func _pose_extra(_delta: float) -> void:
	pass


## Notes each foot leaving the ground, when the step it is about to take is made
## a little different from its last, and each foot coming down, which jolts him.
func _track_steps(stance: float, gait: float) -> void:
	for i in 2:
		var at := fposmod(_phase + 0.5 * i, 1.0)
		var before := _foot_phase[i]
		_foot_phase[i] = at
		if _crawl > 0.5 and _move > 0.2 and at < before - 0.5:
			# (crawling: a knee, and the hand opposite)
			var knee := _shins[i].global_position
			knee.y = global_position.y
			footfall.emit(knee, i, 0.4)
			var hand := _hands[1 - i].global_position
			hand.y = global_position.y
			footfall.emit(hand, 1 - i, 0.25)
		if gait < 0.2:
			continue
		if at < before - 0.5:
			# (the same spring a landing kicks, far more gently)
			_crouch_velocity += lerpf(0.16, 0.3, _run) * gait * looseness
			var sole := foot_position(i)
			sole.y = global_position.y
			footfall.emit(sole, i, lerpf(lerpf(0.5, 1.0, _run) + 0.4 * _sprint, 0.3, _duck))
			if _dust and dust_scale > 0.0:
				_dust.puff(global_position + global_basis * Vector3((1.0 if i == 0 else -1.0) * _hip_width, 0.02, 0.05), -_prev_velocity * 0.1, (lerpf(0.07, 0.13, _run) + 0.05 * _sprint) * dust_scale, 2 if _sprint > 0.5 else 1)
		elif before < stance and at >= stance:
			_step_from[i] = _step_to[i]
			_step_to[i] = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if _stairs > 0.3:
				_choose_tread(i, stance)


## On stairs: settles where the foot that is leaving the ground will come down.
## That is where it would have anyway, but in the middle of whichever tread
## that falls on, and at its height; and he is nudged into step with the treads
## so that the next needs less correcting.
func _choose_tread(i: int, stance: float) -> void:
	var side := 1.0 if i == 0 else -1.0
	var speed := maxf(_prev_velocity.length(), 0.3)
	var forward := global_basis.z.normalized()
	# (where he will be when it lands, and the half step it then is ahead of him)
	var land := global_position + _prev_velocity * ((1.0 - stance) * _stride_now / speed) + forward * (stance * _stride_now * 0.5 - 0.09 * _run)
	var along: Vector3 = _player.stair_dir
	var tread: float = _player.stair_run
	var from_edge: float = (land - _player.stair_edge).dot(along)
	# (going up, the ball of his foot is what he puts on it; going down, all of it)
	var middle: float = (floorf(from_edge / tread) + lerpf(0.42, 0.5, _descending)) * tread
	_stair_slew = clampf((from_edge - middle) / _stride_now, -0.2, 0.2)
	land += along * (middle - from_edge) + global_basis.x.normalized() * side * _hip_width * 0.8
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(land + Vector3.UP * 0.7, land + Vector3.DOWN * 1.0, 1))
	land.y = (hit.position as Vector3).y if not hit.is_empty() else global_position.y
	# (what it is leaving: the tread it was on, or the ground he is on)
	_stair_from[i] = _stair_to[i] if _stair_set[i] else global_position
	_stair_to[i] = land
	_stair_set[i] = true


func _pose_body(speed: float, vertical_speed: float, stance: float, gait: float) -> void:
	var forward := global_basis.z
	var delta := minf(get_process_delta_time(), 1.0 / 30.0)
	# He throws himself into a run, further still while he is getting up to
	# speed, and banks into a turn as far as it is tight and he is fast.
	var pitch := _run * 0.33 + _move * 0.05 + clampf(_accel.dot(forward) * 0.018, -0.24, 0.3) * (1.0 - _duck)
	# Flat out he is nearly falling forward, his legs only just keeping up.
	pitch += _sprint * 0.36
	# (sliding, he lies back on one hip)
	pitch += _duck * 0.78 - _slide * 1.38
	# (up stairs he leans into them; down them he sits back a little)
	pitch += _stairs * gait * lerpf(0.13, -0.1, _descending)
	# (in the air: forward as he goes up, upright again to land)
	pitch += stoop + _push * 0.42 + _air * clampf(vertical_speed * 0.03, -0.14, 0.2) * _leap + _skid * 0.3 + _wary * 0.16
	var roll := clampf(-_yaw_rate * speed * 0.034, -0.42, 0.42) * (1.0 - 0.5 * _duck)
	_lean = _lean.lerp(Vector2(pitch, roll), 1.0 - exp(-9.0 * delta))

	# Zero when the left foot is under him, half a turn on when the right is.
	var step := TAU * (_phase - stance * 0.5)
	# Twice per cycle. Walking vaults over a straight leg, so the body is highest
	# at mid-stance; running sinks into the leg there and is highest in flight.
	# Sneaking he sinks onto each foot as he trusts his weight to it.
	var bob := cos(2.0 * step) * lerpf(lerpf(0.02, -0.04, _run), -0.03, _duck) * gait
	var sway := cos(step) * lerpf(0.014, 0.034, _duck) * gait * (1.0 - _run * 0.5)
	var twist := -cos(TAU * _phase) * lerpf(lerpf(0.1, 0.18, _run), 0.2, _duck) * gait
	# The shoulders answer the hips a moment late, and the head later still nods
	# to each footfall.
	var late := -cos(TAU * _phase - 0.5 * looseness) * lerpf(lerpf(0.1, 0.18, _run), 0.16, _duck) * gait
	var nod := sin(2.0 * step - 1.0) * lerpf(0.018, 0.04, _run) * gait * looseness
	# The hip over the standing leg rides high and the other drops; the back
	# bends the other way to keep the shoulders over the feet.
	var tilt := cos(step) * lerpf(0.05, 0.075, _run) * gait
	# Pushing, he heaves once with each step.
	var heave := (0.5 - 0.5 * cos(2.0 * step)) * _push * gait

	# The back itself: positive arches it (chest out), negative curls it over.
	# In the air he is in one of two attitudes, and goes from the one to the other
	# over the top of the jump: stretched out going up, gathered coming down.
	var rising := smoothstep(-1.8, 1.8, vertical_speed)
	var arch := -_duck * 0.55 - _crouch * 2.2 + _launch * 0.4 + _air * (lerpf(-0.12, 0.24, rising) - 0.2 * _gather) - _skid * 0.25 - _slide * 0.3 - _sprint * 0.08
	# (it opens as each leg drives off and closes as the next one lands)
	arch -= cos(2.0 * step) * lerpf(0.02, 0.07, _run) * gait
	arch += _push * (0.2 + heave * 0.12)
	# At ease he stands like a boy who thinks well of himself: chest out.
	arch += _casual * 0.05 - _wary * 0.16
	var breath := sin(_breath)
	var breathing := (0.014 + 0.035 * _puff) * (1.0 - 0.5 * gait) + 0.035 * _stretch

	# At ease his weight is on one leg: the hips slide over it and that hip rides up.
	var weight := _weight * _casual
	sway += weight * 0.032 + sin(_time * 0.55) * 0.006 * _casual
	tilt += weight * 0.085
	var settle := absf(weight) * 0.012 + _wary * 0.045 + breath * 0.004 * _wary

	var height := _hip_height - _run * 0.025 - _sprint * 0.02 - _crouch - _skid * 0.08 - _duck * 0.23 - _push * 0.1
	# Going down stairs, his hips are let down after the foot that is reaching for the tread below.
	var reaching := 0.0
	for i in 2:
		var foot_at := to_local(_foot_world[i])
		if foot_at.z > 0.0 and absf(foot_at.z) < 0.8:
			reaching = maxf(reaching, -foot_at.y)
	_stair_drop = _approach(_stair_drop, clampf(reaching * 0.7 - 0.02, 0.0, 0.2) * _stairs * gait, 14.0, delta)
	height -= _stair_drop + 0.02 * _stairs * _descending * gait
	bob *= 1.0 + 0.5 * _stairs * _descending
	height += bob - settle + breath * 0.003 * (1.0 - _move)
	# Leaning over, he carries his hips to the inside of the turn, over his feet.
	# Sneaking, they are back over his heels, which leaves his knees room in front of him.
	var at := Vector3(sway - sin(_lean.y) * 0.2, height, -0.24 * _push + heave * 0.03 - _duck * 0.13)
	var lean := _lean.x
	# Which way his chest is turned from the way he is going, his left positive.
	# (Out of a run he jumps as he strides: the shoulder opposite the leading knee goes forward.)
	var turned := _air * rising * _leap * (0.3 if _lead_leg == 0 else -0.3)
	# Which way his head is tipped beyond all this, down positive.
	var chin := -_duck * 0.3 + _sprint * 0.12
	# Landed on his feet, he gives at the knees and his chest comes down over
	# them, and he comes up out of it less quickly. (See LAND_GIVE. Out of a run
	# he runs on through it, and gives less.)
	var give := _keyed(LAND_GIVE, _give_at) * _give * (1.0 - 0.65 * _leap) * (1.0 - _air) * (1.0 - _launch)
	at.y -= give * 0.085
	at.z -= give * 0.03
	lean += give * 0.3
	arch -= give * 0.22
	chin += give * 0.12
	# How far his hips are listed to one side; how far they are tipped forward
	# beyond their share of his lean, the rest of his back making up for it; how
	# far his head is turned, his left positive, and tilted over, his right positive.
	var listing := 0.0
	var tuck := 0.0
	var head_turn := 0.0
	var cant := 0.0
	# Sliding: down on the seat of his trousers and one hip, jolting over the ground.
	at = at.lerp(Vector3(-0.03 * _slide_side, SEAT + absf(sin(_time * 31.0)) * 0.006, -0.1), _slide)
	turned -= _slide * (0.35 * _slide_side + sin(_time * 23.0) * 0.03)
	chin -= _slide * (0.15 + sin(_time * 31.0) * 0.035)
	# Stooping for something: down over bent knees, his back curled, his eyes on it.
	var depth := _stoop * clampf(inverse_lerp(0.95, 0.25, _pick_at.y), 0.3, 1.0)
	at.y -= depth * 0.3
	at.z -= depth * 0.04
	lean += depth * 0.9
	arch -= depth * 0.3
	chin += depth * 0.3

	# Down hard on three points: low over a forward foot and the other knee, a
	# fist on the ground; head down as he hits, then up to see where he is. From
	# no great height he holds it a moment, and stands.
	var kneel := _kneeling()
	var away := 1.0 if _down == 1 else -1.0
	at = at.lerp(Vector3(0.0, 0.265 - 0.03 * exp(-_recovery * 12.0), 0.02), kneel)
	lean = lerpf(lean, 1.0, kneel)
	arch = lerpf(arch, -0.3, kneel)
	turned += kneel * 0.3 * away
	chin += kneel * lerpf(0.45, -0.6, smoothstep(0.22, 0.46, _recovery))
	# (and gives his head a shake as it comes up, to clear it)
	head_turn += kneel * sin(_recovery * 42.0) * 0.26 * smoothstep(0.3, 0.38, _recovery) * (1.0 - smoothstep(0.5, 0.6, _recovery))
	# From higher, what is left of his fall tips him on over that fist, and he
	# goes sprawling: onto both hands, then flat on his front; and pushes himself
	# up off it. (See the SPRAWL_ curves.) Unless he is being hurried: then he
	# scrambles up off his hands at a run, coming upright as he goes.
	var floored := _flooring()
	var rise := smoothstep(Player.SCRAMBLE.x + 0.14, 0.72, _recovery)
	if floored > 0.001:
		var down := Vector3(0.0, _keyed(SPRAWL_HIPS_Y, _recovery), _keyed(SPRAWL_HIPS_Z, _recovery))
		var over := _keyed(SPRAWL_LEAN, _recovery)
		down = down.lerp(Vector3(0.0, lerpf(0.2, _hip_height - 0.1, rise) + bob, 0.0), _scramble)
		over = lerpf(over, lerpf(1.4, 0.55, rise), _scramble)
		at = at.lerp(down, floored)
		lean = lerpf(lean, over, floored)
		arch = lerpf(arch, lerpf(_keyed(SPRAWL_ARCH, _recovery), -0.1, _scramble), floored)
		chin += floored * lerpf(_keyed(SPRAWL_CHIN, _recovery), -0.3, _scramble)
	# Stumbling: pitched forward over legs that are behind him, further and
	# further, until he goes over.
	var pitched := _stumble * smoothstep(0.0, 0.1, _recovery)
	lean += pitched * (0.6 + 0.5 * smoothstep(0.1, STUMBLE_ROLLS, _recovery) + sin(_recovery * 30.0) * 0.07)
	at.y -= pitched * (0.12 + 0.14 * smoothstep(0.15, STUMBLE_ROLLS, _recovery))
	chin += pitched * 0.25
	# Rolling: curled into a ball that turns once over, about its own middle rather than his hips.
	# A dive: thrown out flat along the way he is going, arms ahead of him, legs
	# trailing; over further as he comes down, until it is his hands that are
	# under him, his chin goes to his chest and he is into the roll. (All of how
	# far over he is is in `spin`, as it is for the roll: he is straight, not bent.)
	at = at.lerp(Vector3(0.0, lerpf(_hip_height * 0.92, 0.37, _dive_near), -0.08), _dive)
	lean = lerpf(lean, 0.0, _dive)
	arch = lerpf(arch, lerpf(0.24, -0.3, _dive_near), _dive)
	chin = lerpf(chin, lerpf(-0.6, 0.55, _dive_near), _dive)
	var spin := _dive_pitch * _dive
	if _spinning:
		var over := smoothstep(0.0, lerpf(0.84, 0.66, _dive_roll), _tumble)
		# (out of a dive he is most of the way over already, and goes over one
		# shoulder rather than straight over his head)
		spin = lerpf(_dive_pitch * _dive_roll, TAU, over)
		var shouldered := sin(PI * over) * _dive_roll * _ball
		_shouldered = shouldered * away
		# (not so far that his head comes down on his knee)
		turned += shouldered * 0.3 * away
		listing += shouldered * 0.32 * away
		head_turn -= shouldered * 0.5 * away
	# A back tuck: up stretched, his head thrown back to lead him over; then
	# tucked tight and turning about his middle; then opened out to land.
	if _flip_at < 1.0:
		spin += _keyed(FLIP_TURN, _flip_at)
	var tucked := _tuck * _flip
	lean = lerpf(lean, -0.1, _flip)
	arch += _flip * (0.35 * (1.0 - smoothstep(0.06, 0.24, _flip_at)) + 0.2 * smoothstep(0.76, 0.95, _flip_at)) - tucked * 0.95
	chin += tucked * 0.5 - _flip * 0.55 * (1.0 - smoothstep(0.08, 0.3, _flip_at))
	# (and stays on the ground all the way over: upside down he is on his shoulders)
	# (and at either end of it he is on his feet, with his legs under him)
	at.y = lerpf(at.y, 0.17 - 0.15 * (0.5 - 0.5 * cos(spin)) + 0.08 * pow(maxf(cos(spin), 0.0), 2.0), _ball)
	arch -= _ball * 1.0
	chin += _ball * 0.6
	var middle := Vector3(0.0, 0.1, 0.1) * _ball + Vector3(0.0, 0.15, 0.05) * _flip
	at += middle - Basis(Vector3.RIGHT, spin) * middle

	# Hanging from a ledge, and getting up onto it. It is all placed from the
	# ledge, wherever the body under him has got to; the last of it is just
	# standing up where he is.
	if _hang > 0.001:
		var up := smoothstep(CLIMB_STANDS.x, CLIMB_STANDS.y, _climb)
		var held := (1.0 - smoothstep(0.0, 0.3, _climb))
		var hung := Vector3(-_shimmy * 0.03, _ledge.y + _keyed(CLIMB_HIPS_Y, _climb), _ledge.z + _keyed(CLIMB_HIPS_Z, _climb))
		# (he is never quite still, and swings as he works along; and as he
		# catches it his weight comes onto his arms and his legs swing in)
		hung += Vector3(sin(_time * 0.9) * 0.008 + sin(_player.shimmy_travel * 8.0) * 0.02 * absf(_shimmy), -absf(sin(_player.shimmy_travel * 16.0)) * 0.012 * absf(_shimmy) - maxf(_sway, 0.0) * 0.05, sin(_time * 1.3) * 0.012 - maxf(_sway, 0.0) * 0.05) * held
		at = at.lerp(hung.lerp(at, up), _hang)
		lean = lerpf(lean, lerpf(_keyed(CLIMB_PITCH, _climb) - _sway * 0.22 * held, lean, up), _hang)
		arch = lerpf(arch, lerpf(_keyed(CLIMB_ARCH, _climb), arch, up), _hang)
		listing = -_shimmy * 0.13 * _hang
		# As the knee comes up onto the top, that side of his hips comes up with
		# it, and he shifts away to make room for it.
		var kneeing := sin(PI * smoothstep(0.4, 0.84, _climb)) * _hang * (1.0 - up)
		var braced := 1.0 if _brace == 0 else -1.0
		listing += braced * 0.16 * kneeing
		at.x -= braced * 0.03 * kneeing
		# He looks up at what he has hold of (or along it, the way he is working),
		# then down at where he is putting himself.
		chin += _hang * (0.3 * sin(PI * smoothstep(0.3, 0.85, _climb)) - 0.4 * held * (1.0 - 0.6 * absf(_shimmy)))
		# Left hanging he does not just hang: his weight goes from one arm to the
		# other, and every so often he looks down past his shoulder at the drop.
		var glance := smoothstep(0.55, 0.85, sin(_time * 0.43 + 0.7)) * held * (1.0 - absf(_shimmy)) * _hang
		head_turn += (0.95 if _hat_arm == 0 else -0.95) * glance
		chin += 0.85 * glance
		listing += sin(_time * 0.6) * 0.05 * held * _hang
		turned += (0.2 if _hat_arm == 0 else -0.2) * glance

	# Crawling: on his hands and knees, his back level, looking where he is going.
	# (his back is level from his hips: it is not hung from an upright pelvis.
	# His hips roll over each knee as it takes his weight, his shoulders dip
	# to the hand that is down, and his head swings a little from side to side.)
	var crawl_step := sin(TAU * _phase)
	at = at.lerp(Vector3(crawl_step * 0.022 * _move, 0.262 + absf(crawl_step) * 0.012 * _move, -0.12), _crawl)
	lean = lerpf(lean, 1.47, _crawl)
	arch = lerpf(arch, 0.04, _crawl)
	# (his head is kept low: what he is under is not far above it)
	chin = lerpf(chin, -0.22 + absf(crawl_step) * 0.05 * _move, _crawl)
	# Winded: bent over, his hands on his knees, his back heaving.
	# (Not evenly: his weight is on one leg and that shoulder is down. After a
	# moment he wipes his face on the back of a hand; then he lifts his head to
	# see what is ahead of him, still blowing.)
	var pant := sin(_breath)
	_tired_time = _tired_time + delta if _tired > 0.5 else 0.0
	_wipe = sin(PI * clampf((fposmod(_tired_time, 7.0) - 1.5) / 1.3, 0.0, 1.0))
	var peer := smoothstep(3.4, 3.9, fposmod(_tired_time, 7.0)) * (1.0 - smoothstep(5.2, 5.9, fposmod(_tired_time, 7.0)))
	at = at.lerp(Vector3(0.025, _hip_height - 0.1 + pant * 0.009, -0.14), _tired)
	lean = lerpf(lean, 0.98 - pant * 0.05 - 0.2 * peer - 0.12 * _wipe, _tired)
	arch = lerpf(arch, -0.28 + pant * 0.12, _tired)
	chin += _tired * (0.3 - pant * 0.08 - 0.75 * peer)
	listing += 0.07 * _tired
	turned += 0.12 * _tired
	head_turn += (0.25 * _wipe + sin(_time * 0.9) * 0.2 * peer) * _tired
	# (Sneaking, his seat is out behind him over his heels: his hips are tipped
	# well forward and the curl is in his back above them, not tucked under.)
	tuck += _duck * 0.45 * (1.0 - _crawl) * (1.0 - maxf(_ball, maxf(_three, _sprawled)))
	tuck += 0.7 * _crawl
	listing += crawl_step * 0.09 * _move * _crawl
	head_turn += sin(TAU * _phase - 0.6) * 0.12 * _move * _crawl
	# On a rope: his hips swing under his hands with it, forward as it carries
	# him forward; he gives a heave to each pull, and looks where he is climbing.
	if _rope > 0.001:
		var pump := clampf(_rope_swing.x * 0.25, -1.0, 1.0)
		var pull := sin(TAU * _rope_phase / Player.ROPE_PULL)
		at += Vector3(clampf(_rope_swing.y * 0.012, -0.04, 0.04), (0.05 + pull * 0.022 * absf(_rope_climb)) * _rope, 0.03 + pump * 0.07) * _rope
		# (carried back he does not double over the rope as far as, carried forward, he lies back from it)
		lean += (0.12 - pump * (0.3 if pump > 0.0 else 0.1)) * _rope
		tuck -= pump * 0.18 * _rope
		arch += pump * 0.12 * _rope
		chin += (-0.3 * maxf(_rope_climb, 0.0) + 0.35 * maxf(-_rope_climb, 0.0) - 0.12 * absf(pump)) * _rope
		listing -= pull * 0.07 * absf(_rope_climb) * _rope
	# On a ladder: close in to it, his weight going onto each foot as it takes
	# a rung and his hips out to that side; he looks up it going up, and down
	# past his shoulder coming down. Left a moment he hangs out from it on one
	# arm to look about him. Over the top he leans in and steps onto it.
	if _ladder > 0.001:
		var rung: float = _player.ladder_travel * PI / 0.3
		var over := sin(PI * smoothstep(0.0, 0.9, _ladder_off))
		var out_side := 1.0 if _hat_arm == 0 else -1.0
		# (stepping off the top his hips go forward over the foot that is up there, not left behind it)
		var stepping := smoothstep(0.3, 0.62, _ladder_off) * (1.0 - smoothstep(0.7, 1.0, _ladder_off))
		var on_it := Vector3(sin(rung) * 0.035 + out_side * 0.05 * _ladder_rest, _hip_height - 0.05 + absf(cos(rung)) * 0.02 * absf(_ladder_go) - 0.03 * _ladder_rest + 0.05 * stepping, -0.02 - 0.09 * _ladder_rest + 0.05 * over + 0.26 * stepping)
		at = at.lerp(on_it, _ladder)
		lean = lerpf(lean, 0.1 - 0.2 * _ladder_rest + 0.5 * over, _ladder)
		arch = lerpf(arch, 0.05 - 0.2 * over, _ladder)
		listing += sin(rung) * 0.1 * _ladder * (1.0 - _ladder_rest)
		turned += out_side * 0.55 * _ladder_rest * _ladder
		chin += (-0.35 * maxf(_ladder_go, 0.0) + 0.5 * maxf(-_ladder_go, 0.0) + 0.45 * _ladder_rest + 0.35 * over) * _ladder
		head_turn += (0.5 * maxf(-_ladder_go, 0.0) * (1.0 if sin(rung * 0.5) > 0.0 else -1.0) + out_side * 0.75 * _ladder_rest) * _ladder
	# Swimming. Treading water he is upright in it, his chin just out; getting
	# anywhere he lies along it, legs and all: coming up for air as he pulls in
	# a breast stroke and going down into the glide after it; in a crawl flat,
	# rolling from shoulder to shoulder, his face in the water and turned out
	# of it to breathe as his right arm comes over. Under water he is
	# stretched right out, and tips the way he is going, down or up.
	var sw_turn := TAU * _stroke
	var sw_air := sin(PI * smoothstep(0.2, 0.72, _stroke))
	var sw_roll := 0.0
	if _swim > 0.001:
		var vertical: float = _player.velocity.y
		var tip := clampf(-vertical * 0.3, -0.5, 0.6) * _under * _swim_go
		var top_chest := lerpf(0.1 + sin(sw_turn * 2.0) * 0.03, lerpf(1.32 - 0.3 * sw_air, 1.4, _swim_fast), _swim_go)
		var top_hips := lerpf(0.22, lerpf(1.43 - 0.1 * sw_air, 1.47, _swim_fast), _swim_go)
		var sw_chest := lerpf(top_chest, lerpf(0.4, 1.5, _swim_go) + tip, _under) * (1.0 - 0.8 * _plunge)
		var sw_hips := lerpf(top_hips, lerpf(0.55, 1.52, _swim_go) + tip, _under) * (1.0 - 0.8 * _plunge)
		# (gone in head first, he is a spear: along the way he is going, down and then levelling)
		var headlong := 1.55 + clampf(-vertical * 0.24, -0.35, 0.8)
		sw_chest = lerpf(sw_chest, headlong, _dive_in)
		sw_hips = lerpf(sw_hips, headlong + 0.05, _dive_in)
		var sw_height := lerpf(lerpf(0.55 + sin(sw_turn * 2.0 + 0.6) * 0.018, lerpf(0.86 + 0.035 * sw_air, 0.91, _swim_fast), _swim_go), 0.62, _under)
		# (lying along it, his middle is over where the body is, not his feet)
		at = at.lerp(Vector3(0.0, sw_height, -0.16 * _swim_go + 0.03 * sin(sw_turn + 2.4) * _swim_go * (1.0 - _swim_fast)), _swim)
		lean = lerpf(lean, sw_chest, _swim)
		arch = lerpf(arch, 0.0, _swim)
		tuck += (sw_hips - 0.4 * sw_chest) * _swim
		# (his head: level treading water, up for air and down again in a breast
		# stroke, face down in a crawl, looking ahead under water)
		var gaze := lerpf(-0.18, lerpf(0.5 - 0.6 * sw_air, 0.95, _swim_fast), _swim_go)
		gaze = lerpf(gaze, lerpf(0.3, 0.75, _swim_go), _under)
		gaze = lerpf(gaze, 1.25, _dive_in)
		chin = lerpf(chin, gaze - 0.3 * sw_chest, _swim)
		sw_roll = -sin(sw_turn) * 0.32 * _swim_fast * _swim_go * (1.0 - _under) * _swim
		turned += sw_roll * 0.6
		# (which leaves his head where it was, but for the breath he takes)
		var breathing_in := pow(sin(PI * clampf(_stroke / 0.5, 0.0, 1.0)), 2.0) * _swim_fast * _swim_go * (1.0 - _under)
		head_turn += (-sw_roll - 1.0 * breathing_in) * _swim
		# Up from under, a toss of the head; and looking about him as he treads water.
		head_turn += (sin((1.0 - _toss) * TAU * 1.5) * 0.55 * _toss + sin(_time * 0.7) * 0.35 * (1.0 - _swim_go) * (1.0 - _under)) * _swim
	# Out of the water, he shakes himself like a dog, once: hips one way,
	# shoulders the other, and his head last and furthest.
	var shaking := sin(PI * (1.0 - _shake)) if _shake > 0.0 else 0.0
	var shiver := sin(_time * 25.0) * shaking
	turned += shiver * 0.5
	head_turn += sin(_time * 25.0 - 1.0) * shaking * 0.85
	lean += shaking * 0.3
	arch -= shaking * 0.15
	at.y -= shaking * 0.05
	# Wading: he leans into the water and swings his shoulders to push through it.
	lean += (0.11 * _wade_high + 0.03 * _wade_low) * gait
	twist *= 1.0 + 0.7 * _wade_high
	late *= 1.0 + 0.9 * _wade_high
	# Spinning on the spot: up on the ball of one foot, leaning back from it with
	# his head lolling; and the giddier he is the more his whole axis wanders.
	at.y += _whirl * (0.025 + sin(_whirl_phase * 2.0) * 0.012)
	at.x += _whirl * (_whirl_way * 0.02 + sin(_whirl_phase * 0.5) * 0.04 * _giddy)
	lean = lerpf(lean, -0.15 + sin(_whirl_phase * 0.5 + 1.0) * 0.14 * _giddy, _whirl)
	arch += 0.14 * _whirl
	chin -= (0.3 + 0.15 * _giddy) * _whirl
	listing += _whirl * (_whirl_way * 0.12 + sin(_whirl_phase * 0.5) * 0.2 * _giddy)
	head_turn -= _whirl_way * 0.45 * _whirl
	cant -= _whirl_way * 0.2 * _whirl
	# Coming out of it the world goes on turning: he reels, his head still going round.
	var reel := _reel * (0.45 + 0.55 * _giddy)
	listing += sin(_time * 6.3) * 0.22 * reel
	lean += (0.12 + sin(_time * 4.1 + 1.0) * 0.17) * reel
	at.x += sin(_time * 6.3 - 0.9) * 0.035 * reel
	at.y -= 0.045 * reel
	head_turn += sin(_time * 3.9) * 0.55 * reel
	cant += cos(_time * 3.9) * 0.3 * reel
	chin += (0.16 + sin(_time * 5.2) * 0.1) * reel
	# Landed a back tuck, he knows he was seen: chest out, chin up, a look round at whoever it was.
	arch += 0.17 * _cocky
	chin -= 0.24 * _cocky
	at.y += 0.012 * _cocky
	head_turn += (0.55 if _hat_arm == 0 else -0.55) * _cocky
	cant += (0.12 if _hat_arm == 0 else -0.12) * _cocky
	# A yawn and a stretch: up on his toes, back arched, head back, and a slump after.
	arch += 0.34 * _stretch - 0.12 * smoothstep(0.9, 0.97, _yawn_at) * (1.0 - smoothstep(0.97, 1.0, _yawn_at))
	lean -= 0.15 * _stretch
	chin -= 0.5 * _stretch
	at.y += 0.02 * _stretch
	listing += 0.07 * _stretch
	turned += 0.16 * _stretch
	head_turn += 0.22 * _stretch
	# Sitting down, and sat: on the seat of his trousers behind his heels, slouched,
	# leaning back on one hand. Lying down from there he goes over onto his side
	# and curls up, his head on his arm. (See the SIT_ and LIE_ curves.)
	var rolled := 0.0
	if _sit_at > 0.0:
		var sitting := smoothstep(0.0, 0.14, _sit_at)
		var seated := smoothstep(0.6, 1.0, _sit_at)
		var lying := smoothstep(0.0, 1.0, _lie_at)
		var asleep := smoothstep(0.85, 1.0, _lie_at)
		var sat := Vector3(-0.02 * _lie_side, _keyed(SIT_HIPS_Y, _sit_at), _keyed(SIT_HIPS_Z, _sit_at))
		sat = sat.lerp(Vector3(0.02 * _lie_side, 0.13 + sin(_breath) * 0.003 * asleep, -0.2), lying)
		at = at.lerp(sat, sitting)
		lean = lerpf(lean, lerpf(_keyed(SIT_LEAN, _sit_at), 0.34, lying), sitting)
		arch = lerpf(arch, lerpf(_keyed(SIT_ARCH, _sit_at), -0.66, lying), sitting)
		tuck = lerpf(tuck, -0.27 * seated * (1.0 - lying), sitting)
		turned = lerpf(turned, -0.12 * _lie_side * seated * (1.0 - lying), sitting)
		listing = lerpf(listing, -0.06 * _lie_side * seated * (1.0 - lying), sitting)
		chin = lerpf(chin, lerpf(-0.05 * seated, 0.42, lying), sitting)
		rolled = -_lie_side * PI * 0.5 * _keyed(LIE_ROLL, _lie_at)
		cant -= _lie_side * 0.34 * lying
		# Woken, he rubs his eyes with a fist, head down, and shakes it clear after.
		var rub := sin(PI * smoothstep(0.0, 0.8, _rub_at)) if _rub_at < 1.0 else 0.0
		chin += 0.28 * rub
		head_turn += (sin(_time * 8.0) * 0.06 * rub + sin(_rub_at * 40.0) * 0.3 * smoothstep(0.78, 0.86, _rub_at) * (1.0 - smoothstep(0.9, 1.0, _rub_at))) if _rub_at < 1.0 else 0.0
		# (woken with a start he is bolt upright, and looking for it)
		lean -= 0.2 * _startle * sitting
		chin -= 0.2 * _startle * sitting
		# (sat down because the world would not stop going round)
		head_turn += sin(_time * 2.9) * 0.4 * _giddy * seated * (1.0 - lying)
		cant += cos(_time * 2.9) * 0.25 * _giddy * seated * (1.0 - lying)
		breathing += 0.05 * asleep
	# A gun brought up to aim: side on behind it, the pistol at the end of his arm,
	# the rifle in his shoulder with his cheek down on it; and the kick of it
	# rocks him back from the shoulder that took it.
	var levelled := _aiming * _gun
	turned += levelled * lerpf(0.7, -0.62, _gun_long) * (1.0 - 0.5 * _run)
	at.y -= 0.04 * levelled * (1.0 - _move)
	lean += levelled * lerpf(-0.03, 0.17, _gun_long)
	chin += levelled * lerpf(0.02, 0.16, _gun_long)
	cant += levelled * _gun_long * 0.2
	var kicked := _recoil * _gun
	lean -= kicked * lerpf(0.24, 0.36, _gun_long)
	arch += kicked * 0.14
	at.z -= kicked * 0.05
	chin -= kicked * 0.22
	turned -= kicked * lerpf(0.3, 0.34, _gun_long)
	# With a bat: side on, knees a little bent; and round with it as he swings. (See the SWING_ curves.)
	var bat_turn := lerpf(-0.45, _keyed(SWING_TURN, _swing_at), _swinging) * _bat
	at.y -= 0.05 * _bat
	lean += 0.12 * _bat
	at += Vector3(0.0, _keyed(SWING_HIPS_Y, _swing_at), _keyed(SWING_HIPS_Z, _swing_at)) * _swinging * _bat
	# (his head stays on the ball while his chest goes round under it)
	chin += 0.12 * _swinging * _bat * sin(PI * clampf(_swing_at / 0.6, 0.0, 1.0))
	# Throwing: side on to wind up, then round and over his front foot. (See the PITCH_ curves.)
	var wound := _keyed(PITCH_TURN, _pitch_at) * _pitching + bat_turn + _keyed(HOOK_TURN, _cast_at) * _casting
	# Throwing a hook: he sinks and leans as it swings back beside him, and comes up after it. (See the HOOK_ curves.)
	at.y += _keyed(HOOK_HIPS_Y, _cast_at) * _casting
	lean += _keyed(HOOK_LEAN, _cast_at) * _casting
	chin -= 0.3 * smoothstep(0.3, 0.7, _cast_at) * _casting
	# Its rope taking his weight: stretched out under his hands, his back hollowed, looking up it.
	at.y -= 0.05 * _taut
	arch += 0.3 * _taut
	chin -= 0.3 * _taut
	at += Vector3(0.0, _keyed(PITCH_HIPS_Y, _pitch_at), _keyed(PITCH_HIPS_Z, _pitch_at)) * _pitching
	lean += _keyed(PITCH_LEAN, _pitch_at) * _pitching
	turned += wound * 0.6

	_hips.position = at
	_hips.rotation = Vector3(lean * 0.4 + _crouch * 0.8 + arch * 0.3 + _push * 0.24 + spin + tuck, twist + weight * 0.08 + wound * 0.4 - shiver * 0.12, _lean.y * 0.5 + tilt + listing)
	# (rolling in a crawl is about his own length, whichever way that lies)
	if sw_roll != 0.0:
		_hips.basis = _hips.basis * Basis(Vector3.UP, sw_roll)
	# (and lying down he goes over sideways, about the line he faces along)
	if rolled != 0.0:
		_hips.basis = Basis(Vector3.BACK, rolled) * _hips.basis

	var turn := clampf(_yaw_rate * 0.04, -0.4, 0.4)
	var spine := Vector3(lean * 0.3 - arch * 0.5 - tuck * 0.5, -twist * 0.9 + _look.x * 0.08 + turned * 0.4, _lean.y * 0.25 - tilt * 0.8 - listing * 0.5)
	var chest := Vector3(lean * 0.3 - arch * 0.5 - breath * breathing - tuck * 0.5, -late * 1.1 + _look.x * 0.14 + turned * 0.6, _lean.y * 0.25 - tilt * 0.75 - weight * 0.03 - listing * 0.5)
	# The head stays level and looks where the body is going, or at whatever has his eye.
	var level := 1.0 - _curled
	# (his eyes stay on what he is throwing at, whichever way the rest of him is turned)
	var neck := Vector3((-lean * 0.3 + arch * 0.25 - _crouch * 0.5) * level + _look.y * 0.4 + breath * breathing * 0.5 + nod * 0.5 + chin * 0.4, late * 0.45 + turn * 0.4 + _look.x * 0.33 - turned * 0.4 - wound * 0.16 + head_turn * 0.4, -_lean.y * 0.4 + tilt * 0.25 + cant * 0.4)
	var head := Vector3((-lean * 0.4 + arch * 0.35 - _crouch * 0.7) * level + _look.y * 0.6 + nod * 0.5 + chin * 0.6, late * 0.55 + turn * 0.6 + _look.x * 0.45 - turned * 0.6 - wound * 0.24 + head_turn * 0.6, -_lean.y * 0.5 + tilt * 0.3 + weight * 0.05 + cant * 0.6)
	if _chest:
		_spine.rotation = spine
		_chest.rotation = chest
	else:
		_spine.rotation = spine + chest
	if _neck:
		_neck.rotation = neck
		_head.rotation = head
	else:
		_head.rotation = neck + head


## How far he is down on one knee and a fist, 0..1: for as long as a landing on
## three points lasts, or for the moment before he goes on over them.
func _kneeling() -> float:
	return maxf(_three * (1.0 - smoothstep(KNEEL_ENDS.x, KNEEL_ENDS.y, _recovery)), _sprawled * (1.0 - smoothstep(SPRAWL.x, SPRAWL.y, _recovery)))


## And how far he has gone on over them, onto his hands and his front, 0..1.
func _flooring() -> float:
	# (scrambling up, he is out of it and simply running the sooner)
	return _sprawled * smoothstep(SPRAWL.x, SPRAWL.y, _recovery) * (1.0 - smoothstep(lerpf(SPRAWL_ENDS.x, 0.58, _scramble), lerpf(SPRAWL_ENDS.y, 0.78, _scramble), _recovery))


## Reads a curve drawn by hand: `keys` is (time, value) pairs in order, and the
## line through them is smooth, so nothing starts or stops with a jerk.
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
	# (the slope at each point is that of the line between its neighbours; flat at the ends)
	var m0: float = (v1 - keys[k * 2 - 1]) / (t1 - keys[k * 2 - 2]) if k > 0 else 0.0
	var m1: float = (keys[k * 2 + 5] - v0) / (keys[k * 2 + 4] - t0) if k < last - 1 else 0.0
	var span := t1 - t0
	var u := (time - t0) / span
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * v0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * v1 + (u3 - u2) * span * m1


func _pose_legs(stride: float, stance: float, gait: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	var half_step := stance * stride * 0.5
	# Running, his knees come well up; sneaking, each foot is lifted clear and
	# carried over to be put down again; stumbling, they are snatched forward.
	var lift := lerpf(lerpf(lerpf(0.07, 0.29, _run), 0.31, _sprint), 0.11, _duck) * _leg_scale * (1.0 - 0.35 * _push) * (1.0 + 0.5 * _stumble)
	# Wading: in the shallows each foot is lifted right out of the water; deeper, it is pushed through it.
	lift = lift * (1.0 - 0.45 * _wade_high) + 0.2 * _wade_low
	var sitting := smoothstep(0.0, 0.14, _sit_at)
	var seated := smoothstep(0.5, 0.96, _sit_at)
	var lying := smoothstep(0.3, 0.9, _lie_at)
	var levelled := _aiming * _gun * (1.0 - _move)
	var delta := minf(get_process_delta_time(), 1.0 / 30.0)
	var loose := gait * looseness
	# Now and then, at ease, the foot he is not standing on comes up onto its toes.
	var fidget := pow(maxf(sin(_time * 0.37 + 1.3), 0.0), 6.0) * looseness
	# Ducked and not going anywhere, he waits with one foot ahead, up on the toes of the other.
	var crouched := _duck * (1.0 - gait)
	var kneel := _kneeling()
	var floored := _flooring() * (1.0 - _scramble * smoothstep(Player.SCRAMBLE.x + 0.14, 0.6, _recovery))
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var at := fposmod(_phase + 0.5 * i, 1.0)
		# How far this foot is through its swing (0 while it is down) and through
		# its time on the ground (1 while it swings).
		var swing := clampf((at - stance) / (1.0 - stance), 0.0, 1.0)
		var tread := clampf(at / stance, 0.0, 1.0)
		var vary := _step_from[i].lerp(_step_to[i], smoothstep(0.0, 1.0, swing)) if swing > 0.0 else _step_to[i]
		var cycle := _foot_cycle(at, stance, half_step, lift * (1.0 + 0.2 * _step_to[i].z * looseness))
		var planted := 1.0 - clampf(cycle.y * gait / 0.04, 0.0, 1.0)
		var pitch := cycle.x * gait
		# Pushing, he drives off the balls of his feet, which stay well behind him.
		pitch = lerpf(pitch, maxf(pitch, 0.5), _push)
		# He does not walk on rails. His feet come down nearer the line he is
		# walking than his hips are wide, never quite where they did last time,
		# and each swings out round the other on its way past. They are turned
		# out, less so at a run, when the heel also flicks out behind him.
		# Sneaking, they are set down wide.
		var track := _hip_width * (1.0 - (0.15 + 0.15 * _run) * loose) + (vary.x * 0.012 + sin(PI * swing) * 0.014) * loose + 0.02 * _duck
		var target := Vector3(side * track, cycle.y * gait, cycle.z * gait - 0.34 * _push)
		var yaw := side * (lerpf(0.14, 0.05, _run) + vary.y * 0.05 + sin(PI * swing) * 0.1 * _run) * loose
		# And they are not flat boards: a foot lands on the outer edge of its heel
		# and rolls in across the sole to push off from the big toe; in the air it
		# hangs turned a little inwards. (How far the outer edge is down, radians.)
		var tip := 0.14 * (smoothstep(0.6, 1.0, swing) if swing > 0.0 else 1.0 - smoothstep(0.0, 0.3, tread))
		tip = (tip - 0.05 * smoothstep(0.6, 1.0, tread) * (1.0 - smoothstep(0.0, 0.3, swing)) + 0.1 * sin(PI * swing)) * loose

		# Standing at ease: feet planted apart and turned out, the leg he is not
		# standing on set a little forward with its knee slack. Wary: feet wider,
		# one ahead of the other, the back heel off the ground.
		var free := maxf(-side * _weight, 0.0) * _casual
		target.x += side * (0.026 * _casual + 0.04 * _wary + 0.035 * crouched)
		target.z += free * 0.055 + _wary * (0.1 if i == 0 else -0.1) + crouched * (0.12 if i == 0 else -0.1) + _stoop * (0.1 if i == 0 else -0.08)
		yaw += side * (0.22 * _casual + 0.12 * _wary + free * 0.12 + 0.12 * _duck)
		pitch += _wary * (0.0 if i == 0 else 0.3) + free * (0.06 + fidget * 0.45) + crouched * (0.0 if i == 0 else 0.55)
		# (stretching, he goes up on his toes; reeling, his feet are wide)
		pitch += 0.3 * _stretch * (1.0 - gait)
		target.x += side * 0.07 * _reel
		# Stood to aim, his feet are apart and one is back: the pistol's side
		# forward, or the side away from the rifle's butt.
		var fore := (i == 1) != (_gun_long > 0.5)
		target.x += side * 0.035 * levelled
		target.z += (0.11 if fore else -0.1) * levelled
		yaw += side * (0.0 if fore else 0.4) * levelled
		# Coming down from a jump he lands on the balls of his feet and the heels follow.
		pitch = minf(pitch + _land * _land * 0.4 * looseness, 1.3)
		# The knees follow the feet round, and spread as he sinks onto them: ducked,
		# wide enough that his chest comes down between them.
		# (crouched where he stands, they are over his feet, not out beyond them)
		var knee := yaw * 0.6 + side * (0.04 + minf(_crouch * 2.0, 0.3) + 0.1 * _wary + free * 0.12) * looseness + side * (0.1 * _duck - 0.14 * crouched + 0.3 * _stoop)

		# Up on the ball of the foot the ankle rides higher and further forward,
		# and back on the heel it rides higher and further back: the foot turns
		# about whichever end is on the ground, so that end stays put.
		target += _ankle_offset(pitch)
		target.y += absf(tip) * 0.035 * planted
		# On stairs each foot is put on a tread (see _choose_tread), and stays
		# where it was put while he goes on over it. Going up it is lifted to
		# the height of the tread before it is carried there, the knee coming
		# high to clear the edge; going down it is carried out over the edge and
		# let down toes first.
		# (It is still his ordinary step: only moved, by no more than half a
		# tread, to where the tread is, and raised or lowered to it.)
		var ground := 0.0
		if _stairs > 0.01 and _stair_set[i]:
			var deep: float = _player.stair_run
			var forward := global_basis.z.normalized()
			var high := _stair_to[i].y - global_position.y
			var shift := _stair_shift[i]
			var toes := pitch
			if swing > 0.0:
				# (where it would come down as he is going now, against where it is meant to)
				var remaining := (1.0 - swing) * (1.0 - stance) * _stride_now / maxf(_prev_velocity.length(), 0.3)
				var coming := global_position + _prev_velocity * remaining + forward * (half_step - 0.09 * _run)
				var wanted := clampf((_stair_to[i] - coming).dot(forward), -deep * 0.6, deep * 0.6)
				shift = lerpf(_stair_left[i], wanted, smoothstep(0.0, 0.75, swing))
				var low := _stair_from[i].y - global_position.y
				var rising_to := high > low + 0.01
				high = lerpf(low, high, smoothstep(0.0, 0.5, swing) if rising_to else smoothstep(0.45, 1.0, swing))
				high += sin(PI * swing) * lerpf(0.05, 0.09, _run) * (1.0 if rising_to else 0.6)
				toes = lerpf(lerpf(0.9, -0.05, smoothstep(0.2, 0.9, swing)), lerpf(0.5, 0.8, smoothstep(0.3, 1.0, swing)), _descending)
				_stair_shift[i] = shift
			else:
				_stair_left[i] = shift
				# (down them he lands on the ball of his foot and the heel comes down after)
				toes = lerpf(pitch, maxf(pitch, 0.8 * (1.0 - smoothstep(0.0, 0.35, tread))), _descending)
			ground = high * _stairs
			target += (Vector3(0.0, high, shift) + _ankle_offset(toes) - _ankle_offset(pitch)) * _stairs
			pitch = lerpf(pitch, toes, _stairs)
			# (the lift of his ordinary step on top of the height of the tread
			# would carry the foot up over his hip, and the leg right round with it)
			target.y = lerpf(target.y, minf(target.y, _hips.position.y - 0.1), _stairs)

		# (When he is low and going fast, stumbling or coming up out of a roll,
		# a foot lifted as high as he lifts it running would be up at his hip
		# or over it, which carries the leg right round: it stays below them.)
		target.y = lerpf(target.y, minf(target.y, _hips.position.y - lerpf(0.12, 0.2, _stumble)), 1.0 - _stairs)
		# Airborne, he holds a pose, and there are two of them. Going up out of a
		# run it is a stride held: one knee driven high in front, the other leg
		# stretched right out behind. Coming down, the front leg is reached out
		# for the ground and the other gathered under him. Straight up, both knees
		# come up together, and both feet go down together.
		# (A jump of his own has a third between them, over the top of it: see
		# _gather. Straight up, he goes up stretched out, his legs left hanging
		# under him, and it is over the top that his knees come up. Out of a
		# run, there the front leg swings out ahead and the back one folds up
		# behind him, to come down reaching with the one and gathered on the other.)
		var lead := i == _lead_leg
		var driven := Vector3(side * _hip_width, lerpf(0.0, 0.47, _leap) if lead else lerpf(0.015, 0.17, _leap), lerpf(-0.02, 0.34, _leap) if lead else lerpf(-0.1, -0.52, _leap))
		var gathered := Vector3(side * (_hip_width + 0.02), lerpf(0.23, 0.3, _leap) if lead else lerpf(0.2, 0.31, _leap), lerpf(0.03, 0.42, _leap) if lead else lerpf(-0.05, -0.3, _leap))
		var reaching := Vector3(side * (_hip_width + 0.03), lerpf(0.06, 0.1, _leap) if lead else lerpf(0.07, 0.24, _leap), lerpf(0.07, 0.28, _leap) if lead else lerpf(0.0, -0.2, _leap))
		# (he is in the air, as far as his legs go, as soon as they have driven him off the ground)
		var aloft := maxf(_air, _jumped * (1.0 - _launch))
		# (Nor does a leg go from one of these to another all at once, when he
		# kicks off a wall or is thrown upwards: it is a moment getting there.)
		var wanted := reaching + (gathered - reaching) * _gather + (driven - reaching) * _rise
		_leg_at[i] = wanted if aloft < 0.02 else _leg_at[i].lerp(wanted, 1.0 - exp(-24.0 * delta))
		target = target.lerp(_leg_at[i], aloft)
		# (toes pointed while he rises; as he falls the front foot is drawn up to land on)
		var falling := 0.1 if lead else lerpf(0.2, 0.5, _leap)
		pitch = lerpf(pitch, falling + (0.6 - falling) * _gather + (1.0 - falling) * _rise, aloft)
		yaw = lerpf(yaw, side * 0.18, aloft)
		# Skidding: feet planted apart, the back one braking on its toes.
		target = target.lerp(Vector3(side * (_hip_width + 0.03), ANKLE, -0.3 if i == 0 else 0.12) + _ankle_offset(0.6 if i == 0 else -0.25), _skid)
		pitch = lerpf(pitch, 0.6 if i == 0 else -0.25, _skid)
		# Spinning: he turns on the ball of one foot, the other leg flung out and
		# trailing, and coming down once a turn to keep him going.
		var pivoting := i == (0 if _whirl_way > 0.0 else 1)
		var tap := pow(maxf(cos(_whirl_phase + 0.6), 0.0), 3.0)
		var flung := Vector3(side * (_hip_width + 0.21 - 0.08 * tap), lerpf(0.25, 0.0, tap), -0.2 + 0.1 * tap) + _ankle_offset(0.75)
		target = target.lerp(Vector3(side * 0.025, 0.0, 0.0) + _ankle_offset(0.8) if pivoting else flung, _whirl)
		pitch = lerpf(pitch, 0.8 if pivoting else 0.75, _whirl)
		knee = lerpf(knee, side * (0.1 if pivoting else 0.7), _whirl)
		# Sitting down: his feet stay where they were as he goes down behind
		# them, his heels coming up; sat, one knee is up and the other leg is
		# out in front of him on its heel. (Which is which goes with the side he lies down on.)
		if _sit_at > 0.0:
			var out := i == (1 if _lie_side > 0.0 else 0)
			var squat := sin(PI * smoothstep(0.05, 0.78, _sit_at))
			var toes := 0.5 * squat - (0.5 if out else 0.0) * seated
			var set_down := Vector3(side * (_hip_width + lerpf(0.035, 0.06 if out else 0.1, seated)), 0.0, lerpf(0.05 if i == 0 else -0.03, 0.27 if out else 0.1, seated)) + _ankle_offset(toes)
			target = target.lerp(set_down, sitting)
			pitch = lerpf(pitch, toes, sitting)
			yaw = lerpf(yaw, side * (0.32 if out else 0.2), sitting)
			knee = lerpf(knee, side * (0.12 if out else 0.34), sitting)
		# Sliding: one leg out in front, its heel cutting along the ground, the
		# other folded up with its foot flat beside him.
		# (Which leg is which goes with the hand that is down: see _slide_side.)
		var out_front := i == (0 if _slide_side > 0.0 else 1)
		# (the heel that is out in front skips and digs in again as he goes)
		target = target.lerp(Vector3(side * _hip_width - 0.03 * _slide_side, maxf(sin(_time * 12.0), 0.0) * 0.03, 0.42) + _ankle_offset(-0.55) if out_front else Vector3(side * (_hip_width + 0.05), ANKLE, 0.14), _slide)
		pitch = lerpf(pitch, -0.55 if out_front else 0.0, _slide)
		yaw = lerpf(yaw, side * (0.1 if out_front else 0.45), _slide)
		knee = lerpf(knee, side * (0.1 if out_front else 0.5), _slide)
		# On a rope: knees up, feet gripping, shifting as the hands do.
		# (one foot in front of it and the other behind, the rope between his insteps)
		var inching := sin(TAU * _rope_phase / (Player.ROPE_PULL * 2.0) + i * PI)
		var gripping := Vector3(side * 0.035, ANKLE + 0.24 + inching * 0.06 + side * 0.025, 0.2 if i == 0 else 0.12)
		# Swinging, they go with it instead: hanging under him through the middle,
		# kicked out ahead as it carries him forward, and folded back, trailing, as
		# it carries him back. (See the ROPE_LEG_ curves; one leg a little ahead of the other.)
		var riding := maxf(_rope_ride * (1.0 - absf(_rope_climb)), _taut)
		# (a rope that has just taken his weight has his legs left behind him)
		var carry := lerpf(clampf(_rope_swing.x / 5.0, -1.0, 1.0) * 0.5 + 0.5, 0.12, _taut)
		var swept := Vector3(side * 0.075, ANKLE + _keyed(ROPE_LEG_Y, carry), _keyed(ROPE_LEG_Z, carry) + (0.05 if i == 0 else -0.03))
		target = target.lerp(gripping.lerp(swept, riding), _rope)
		pitch = lerpf(pitch, lerpf(0.35 if i == 0 else 0.7, _keyed(ROPE_LEG_TOES, carry), riding), _rope)
		knee = lerpf(knee, side * lerpf(0.55, 0.12, riding), _rope)
		# Off a wall: the leg that pushed is left out behind him, at the wall.
		if i == _kick_leg and _kick > 0.01:
			# (it is there in a moment, not in no time at all)
			var reached := _kick * smoothstep(1.0, 0.78, _kick)
			target = target.lerp(to_local(_kick_point), reached)
			pitch = lerpf(pitch, 1.1, reached)
		tip = lerpf(tip, 0.15 * looseness, maxf(_air, _hang))
		# Take-off: he drives himself up off the ground, and the leg that does it
		# is left straight out behind, reaching for where he sprang from, toes
		# last, until he is clear of it. (Both legs from a standstill; out of a
		# run the other knee is already on its way up.)
		var spot := to_local(_sprang_from[i])
		var pushing := _launch * _drove[i] * (1.0 - _leap if lead else 1.0)
		# (up onto his toes as he goes: they are the last of him to leave it)
		var toed := maxf(clampf(pitch, 0.0, 1.15), 1.15 * smoothstep(0.0, 0.22, -spot.y))
		target = target.lerp(Vector3(side * _hip_width, clampf(spot.y, -0.25, 0.0), clampf(spot.z, -0.5, 0.1)) + _ankle_offset(toed), pushing)
		pitch = lerpf(pitch, toed, pushing)
		# Down on three points: one foot flat in front of him, the other leg
		# behind on its toes, that knee to the ground.
		var kneeling := i == _down
		target = target.lerp(Vector3(side * (_hip_width + 0.02), 0.0, -0.3) + _ankle_offset(1.15) if kneeling else Vector3(side * (_hip_width + 0.05), ANKLE, 0.19), kneel)
		pitch = lerpf(pitch, 1.15 if kneeling else 0.0, kneel)
		yaw = lerpf(yaw, side * (0.05 if kneeling else 0.25), kneel)
		knee = lerpf(knee, side * (0.05 if kneeling else 0.3), kneel)
		# Gone sprawling: both legs out behind him on their toes; then one at a
		# time they are picked up and put under him. (See the SPRAWL_ curves.)
		if floored > 0.001:
			var toes := _keyed(SPRAWL_BACK_PITCH if kneeling else SPRAWL_FRONT_PITCH, _recovery)
			var laid := Vector3(side * (_hip_width + (0.03 if kneeling else 0.08)), 0.0, _keyed(SPRAWL_BACK_Z if kneeling else SPRAWL_FRONT_Z, _recovery)) + _ankle_offset(toes)
			if kneeling:
				laid.y += sin(PI * smoothstep(0.7, 0.84, _recovery)) * 0.07
			else:
				laid.y += sin(PI * smoothstep(0.62, 0.75, _recovery)) * 0.09
			target = target.lerp(laid, floored)
			pitch = lerpf(pitch, toes, floored)
			yaw = lerpf(yaw, side * (0.1 if kneeling else 0.35), floored)
			knee = lerpf(knee, side * (0.1 if kneeling else 0.4), floored)
		# Throwing: the front knee comes up and he strides out onto that foot; the
		# other is set sideways to drive off, and comes round after the throw.
		if _pitching > 0.001:
			var toes := 0.0
			var set_down: Vector3
			if i == 0:
				var up := _keyed(PITCH_KICK_Y, _pitch_at)
				set_down = Vector3(side * (_hip_width + 0.02), up, _keyed(PITCH_KICK_Z, _pitch_at))
				toes = up * 2.2 - 0.25 * sin(PI * smoothstep(0.38, 0.52, _pitch_at))
			else:
				toes = 0.95 * smoothstep(0.44, 0.58, _pitch_at) * (1.0 - smoothstep(0.8, 0.94, _pitch_at))
				set_down = Vector3(side * (_hip_width + 0.04), _keyed(PITCH_DRIVE_Y, _pitch_at), _keyed(PITCH_DRIVE_Z, _pitch_at))
				yaw = lerpf(yaw, side * (1.0 - smoothstep(0.5, 0.74, _pitch_at)), _pitching)
			target = target.lerp(set_down + _ankle_offset(maxf(toes, -0.3)), _pitching)
			pitch = lerpf(pitch, toes, _pitching)
			knee = lerpf(knee, yaw * 0.7, _pitching)

		# Hanging from a ledge: one foot up flat against the wall, the other leg
		# hanging, its toes just touching. Climbing, he walks the first up the
		# wall as he pulls, gets that knee and then the foot onto the top, and
		# brings the other up after it. (See the CLIMB_ curves.)
		if _hang > 0.001:
			var up := smoothstep(CLIMB_STANDS.x, CLIMB_STANDS.y, _climb)
			var held := 1.0 - smoothstep(0.0, 0.3, _climb)
			var hold: Vector3
			var toes: float
			# Working along the ledge his feet walk the wall under him: each stays
			# where it is while he goes on, then is picked off and set down ahead.
			var walking := smoothstep(0.05, 0.4, absf(_shimmy)) * held * _wall
			var paced := fposmod(_wall_walk / WALL_PACE + (0.0 if i == _brace else 0.5), 1.0)
			var ahead := lerpf(0.5, -0.5, paced / 0.6) if paced < 0.6 else lerpf(-0.5, 0.5, smoothstep(0.0, 1.0, (paced - 0.6) / 0.4))
			var off_wall := sin(PI * (paced - 0.6) / 0.4) if paced > 0.6 else 0.0
			if i == _brace:
				hold = Vector3(side * (_hip_width + 0.03), _ledge.y + _keyed(CLIMB_FOOT_Y, _climb), _ledge.z + _keyed(CLIMB_FOOT_Z, _climb))
				toes = _keyed(CLIMB_FOOT_PITCH, _climb)
				# With nothing under the ledge but air, it hangs like the other.
				var adrift := (1.0 - _wall) * (1.0 - smoothstep(0.3, 0.5, _climb))
				hold = hold.lerp(Vector3(side * _hip_width, _hips.position.y - 0.53, _hips.position.z + 0.05 + sin(_time * 1.6) * 0.035), adrift)
				toes = lerpf(toes, 0.6, adrift)
			else:
				hold = Vector3(side * _hip_width, _ledge.y + _keyed(CLIMB_TRAIL_Y, _climb), _ledge.z + _keyed(CLIMB_TRAIL_Z, _climb))
				toes = _keyed(CLIMB_TRAIL_PITCH, _climb) + sin(_time * 1.7) * 0.08 * looseness
				# (it swings, and now and then scuffs at the wall for a hold it does not find)
				hold.z += (sin(_time * 1.6 + 2.0) * 0.035 - (1.0 - _wall) * 0.08) * held
				hold.y += pow(maxf(sin(_time * 0.9 + 0.4), 0.0), 6.0) * 0.09 * held * _wall
				# (the leg that hangs is brought up onto the wall to do its share)
				hold = hold.lerp(Vector3(side * (_hip_width + 0.02), _ledge.y - 1.06, _ledge.z + CLIMB_FOOT_Z[1]), walking)
				toes = lerpf(toes, -0.8, walking)
			hold += Vector3(signf(_shimmy) * ahead * WALL_PACE * 0.6, off_wall * 0.07, -off_wall * 0.06) * walking
			# (with no wall to walk, his legs are left behind a little instead)
			hold.x -= _shimmy * (0.03 if i == _brace else 0.07) * held * (1.0 - _wall)
			# Not through the ground, if the ledge is a low one.
			hold.y = maxf(hold.y, _ledge.y - _ledge_drop + ANKLE)
			target = target.lerp(hold.lerp(target, up), _hang)
			pitch = lerpf(pitch, lerpf(toes, pitch, up), _hang)
			yaw = lerpf(yaw, side * 0.12, _hang)
			# The knee of the leg against the wall is out to the side, clear of it.
			knee = lerpf(knee, lerpf(side * lerpf(1.0, 0.2, smoothstep(0.25, 0.6, _climb)) if i == _brace else side * lerpf(0.25, 0.8, walking), knee, up), _hang)

		# Crawling: on his knees, shins along the ground, each drawn up in turn.
		if _crawl > 0.001:
			var cr_at := fposmod(_phase + 0.5 * i, 1.0)
			var cr_back := lerpf(0.1, -0.1, cr_at / 0.65) if cr_at < 0.65 else lerpf(-0.1, 0.1, (cr_at - 0.65) / 0.35)
			var cr_knelt := Vector3(side * (_hip_width + 0.02), 0.0, -0.47 + cr_back * _move) + _ankle_offset(1.25)
			if cr_at > 0.65:
				cr_knelt.y += sin(PI * (cr_at - 0.65) / 0.35) * 0.03 * _move
			target = target.lerp(cr_knelt, _crawl)
			pitch = lerpf(pitch, 1.25, _crawl)
			yaw = lerpf(yaw, side * 0.08, _crawl)
			knee = lerpf(knee, side * 0.06, _crawl)
		# On a ladder: each foot goes to the rung the Player gives it, the knees out to the sides.
		if _ladder > 0.001:
			var rung := to_local(_player.foot_points[i])
			# (lifted clear and brought in to the next rung, not slid up the ladder)
			var apart := (rung - _foot_targets[i]).length()
			_foot_targets[i] = _foot_targets[i].lerp(rung, 1.0 - exp(-(16.0 if _ladder_off <= 0.0 else 30.0) * delta)) if _ladder > 0.3 else rung
			var set_down := 1.0 - smoothstep(0.5, 0.9, _ladder_off) if i == 0 else 1.0 - smoothstep(0.85, 1.0, _ladder_off)
			target = target.lerp(_foot_targets[i] + Vector3(0.0, 0.05, -0.05 - minf(apart, 0.3) * 0.25) * set_down + Vector3(0.0, ANKLE, 0.0) * (1.0 - set_down), _ladder)
			pitch = lerpf(pitch, 0.2 * set_down + minf(apart, 0.3) * 1.5, _ladder)
			yaw = lerpf(yaw, side * 0.2, _ladder)
			knee = lerpf(knee, side * lerpf(0.55, 0.15, smoothstep(0.3, 0.8, _ladder_off)), _ladder)
		# Winded, and with a bat, his feet are planted wide; he steps into a swing.
		target.x += side * (0.05 * _tired + 0.07 * _bat)
		if i == 0:
			# (the front foot: up as he loads, and out)
			target.z += _keyed(SWING_STRIDE, _swing_at) * _swinging * _bat
			target.y += 0.1 * sin(PI * clampf((_swing_at - 0.12) / 0.28, 0.0, 1.0)) * _swinging * _bat
		else:
			target.z -= 0.06 * _swinging * _bat
		if i == 1:
			# (and comes round on the ball of his back foot)
			var pivot := smoothstep(0.35, 0.6, _swing_at) * _swinging * _bat
			pitch += 0.8 * pivot
			yaw += 0.7 * pivot
			target += (_ankle_offset(0.8) - _ankle_offset(0.0)) * pivot

		# On the ball of the foot, the toes stay flat on the ground while the heel comes up.
		var on_ground := maxf(planted * (1.0 - aloft), pushing * (1.0 - smoothstep(0.0, 0.4, -spot.y))) * (1.0 - maxf(_hang, _rope)) * (1.0 - _slide) * (1.0 - _curled) * (1.0 - _swim) * (1.0 - _ladder)
		on_ground *= (1.0 - _dive) * (1.0 - lying) * (1.0 if pivoting else 1.0 - _whirl * (1.0 - tap))
		# The ankle is not a hinge held at an angle. Off the ground the foot is
		# carried slack: it trails whatever the leg does and swings a little past
		# where it was going. The toes trail the foot in the same way, and are
		# drawn up as the heel comes down.
		_foot_spin[i] += ((pitch - _foot_pitch[i]) * 600.0 - _foot_spin[i] * 20.0) * delta
		_foot_pitch[i] = lerpf(_foot_pitch[i] + _foot_spin[i] * delta, pitch, on_ground)
		_foot_spin[i] *= 1.0 - on_ground
		# (but he has it in hand again by the time it comes down, and a foot
		# against a wall is not slack at all)
		var slack := (1.0 - on_ground) * (1.0 - smoothstep(0.5, 0.95, swing) * gait) * looseness * (1.0 - _hang) * (1.0 - 0.75 * _duck)
		var carried := lerpf(pitch, _foot_pitch[i], slack)
		var foot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, carried) * Basis(Vector3.BACK, -side * tip)
		var toes_bent := -maxf(pitch, 0.0) * on_ground - maxf(-pitch, 0.0) * 0.5 * looseness * (1.0 - _hang) + clampf(-_foot_spin[i] * 0.02, -0.3, 0.4) * slack
		# They bend no further down than the ground under them allows, so they
		# stay flat on it for as long as the ball of the foot is near it.
		var clear := (target + foot * _toe).y - SOLE - ground + maxf(maxf(aloft, _slide), maxf(_hang, _rope)) + _curled + lying + pushing
		_foot_world[i] = to_global(target - _ankle_offset(pitch))
		_toes[i].rotation.x = minf(toes_bent, asin(clampf(clear / 0.07, 0.0, 1.0)) - carried)
		# Rolled up in a ball, his legs are placed from his hips, not from the
		# ground: knees to his chest, turning over with the rest of him.
		var placed := to_hips * target
		var footing := (to_hips.basis * foot).orthonormalized()
		# In a dive they trail out behind him, one a little bent, toes pointed;
		# and they are still out behind him as he goes over onto his hands.
		var leading := i == _lead_leg
		var trailing := maxf(_dive, _dive_roll * _roll * (1.0 - smoothstep(0.1, 0.4, _tumble)))
		placed = placed.lerp(Vector3(side * (_hip_width + 0.025), _hip_drop - (_thigh + _shin) + (0.012 if leading else 0.085), -0.03 if leading else -0.17), trailing)
		footing = footing.slerp(Basis(Vector3.RIGHT, 1.0), trailing)
		knee = lerpf(knee, 0.0, trailing)
		# Rolled up in a ball, his legs are placed from his hips, not from the
		# ground, and turn over with the rest of him: knees drawn up and apart,
		# one either side of his chest, heels in under his seat, feet drawn up
		# out of the way of his head. (See _legs_in.)
		# (Over one shoulder, his head is down on that side: that knee is out
		# wider, to make room for it.)
		var crowded := maxf(side * _shouldered, 0.0)
		placed = placed.lerp(Vector3(side * (_hip_width + 0.015), -0.19, 0.12), _legs_in)
		footing = footing.slerp(Basis(Vector3.UP, side * 0.25) * Basis(Vector3.RIGHT, 0.2), _legs_in)
		knee = lerpf(knee, side * (0.5 + 0.4 * crowded), _legs_in)
		# Lying curled on his side, they are drawn up: the one that is under less
		# than the one on top, which lies forward over it. Asleep, a foot twitches now and then.
		if _lie_at > 0.0:
			var under := i == (0 if _lie_side > 0.0 else 1)
			var twitch := pow(maxf(sin(_time * 0.61 + 1.0), 0.0), 60.0) * sin(_time * 21.0) * smoothstep(0.9, 1.0, _lie_at)
			var drawn_up := Vector3(side * _hip_width + (0.0 if under else _lie_side * 0.06), -0.17 if under else -0.27, 0.15 if under else 0.26 + twitch * 0.025)
			placed = placed.lerp(drawn_up, lying)
			footing = footing.slerp(Basis(Vector3.RIGHT, 0.6 + (0.0 if under else twitch * 0.3)), lying)
			knee = lerpf(knee, 0.0, lying)
		# In the water they are placed from his hips too. A frog kick: knees
		# drawn up and out, and driven back together. A flutter kick: straight,
		# one up as the other goes down, three to a stroke. Treading water they pedal.
		# (The frog kick comes after the pull: his heels are drawn up as his
		# hands come in to his chest, and whipped out and round and together as
		# they go forward again; then he glides.)
		if _swim > 0.001:
			var drawn := smoothstep(0.42, 0.68, _stroke) * (1.0 - smoothstep(0.7, 0.86, _stroke))
			var whipped := sin(PI * smoothstep(0.56, 0.92, _stroke))
			var beat := TAU * _stroke * 3.0 + i * PI
			var sw_long := _hip_drop - (_thigh + _shin) + 0.008
			var sw_frog := Vector3(side * (_hip_width + 0.13 * drawn + 0.13 * whipped), lerpf(sw_long, -0.26, drawn), 0.11 * drawn)
			var sw_flutter := Vector3(side * (_hip_width - 0.01), sw_long + 0.012, sin(beat) * 0.12 + 0.01)
			var sw_tread := Vector3(side * (_hip_width + 0.08 + 0.05 * sin(TAU * _stroke * 2.0 + i * PI)), -0.4 + sin(TAU * _stroke * 2.0 + i * PI) * 0.08, 0.1 + cos(TAU * _stroke * 2.0 + i * PI) * 0.09)
			var sw_plunge := Vector3(side * (_hip_width + 0.07), -0.34 - 0.12 * i, 0.2 - 0.14 * i)
			var kicking := (1.0 - _swim_fast) * _swim_go
			placed = placed.lerp(sw_tread.lerp(sw_frog.lerp(sw_flutter, _swim_fast), _swim_go).lerp(sw_plunge, _plunge).lerp(Vector3(side * (_hip_width - 0.01), sw_long + 0.012, 0.01 + 0.03 * i), _dive_in), _swim)
			# (toes pointed, but for the frog kick, which is made with the soles of his feet)
			var pointed := lerpf(lerpf(lerpf(0.75, 1.15 + cos(beat) * 0.2 * _swim_fast, _swim_go), 0.25, drawn * kicking), 1.2, _dive_in)
			footing = footing.slerp(Basis(Vector3.UP, side * (0.25 + 0.5 * maxf(drawn, whipped) * kicking)) * Basis(Vector3.RIGHT, pointed), _swim)
			knee = lerpf(knee, side * lerpf(0.5, 1.0 * drawn * (1.0 - _swim_fast), _swim_go) * (1.0 - _dive_in), _swim)
		# Off the ground, a leg reaching for something further off than it is long
		# comes straight by degrees, and bends again by degrees: without this the
		# knee locks, and snaps as it lets go.
		var unplanted := maxf(aloft, pushing) * (1.0 - _hang) * (1.0 - _swim)
		var from_hip := placed - Vector3(side * _hip_width, _hip_drop, 0.0)
		var full := _thigh + _shin
		var far := from_hip.length()
		if unplanted > 0.0 and far > full * 0.95:
			var eased := full * (0.95 + 0.05 * (1.0 - exp(-(far - full * 0.95) / (full * 0.05))))
			placed -= from_hip * (1.0 - eased / far) * unplanted
		_planted[i] = on_ground > 0.5
		_solve_leg(i, side, placed, footing, knee)


## Where the ankle of a planted foot sits when the foot is pitched: up on its
## toes (positive) it turns about the ball, back on its heel about the heel.
func _ankle_offset(pitch: float) -> Vector3:
	if pitch >= 0.0:
		var up := -_toe.y
		return Vector3(0.0, SOLE + up * cos(pitch) + _toe.z * sin(pitch), _toe.z * (1.0 - cos(pitch)) + up * sin(pitch))
	return Vector3(0.0, ANKLE * cos(pitch) + 0.045 * sin(-pitch), -ANKLE * sin(-pitch) + 0.045 * (1.0 - cos(pitch)))


## Foot path for one leg over a gait cycle. Returns (toe pitch, height, forward).
func _foot_cycle(phase: float, stance: float, half_step: float, lift: float) -> Vector3:
	# Running, the foot lands nearly under the body and pushes off well behind it.
	var trail := 0.09 * _run
	# How far the heel is up as the foot leaves the ground behind him, and how
	# far the toes are up as it lands in front: walking is heel first, running
	# comes down nearly flat. Sneaking it is the other way about: he feels for
	# the ground with his toes and lets the heel down after them.
	var push_off := lerpf(lerpf(1.0, 1.25, _run), 0.7, _duck)
	var strike := lerpf(lerpf(0.42, 0.08, _run), -0.5, _duck)
	if phase < stance:
		# Planted: carried backwards under the body, rolling heel to toe. The
		# heel starts to peel before the leg is halfway back.
		var t := phase / stance
		var roll := smoothstep(0.4, 1.0, t) * push_off - (1.0 - smoothstep(0.0, 0.24, t)) * strike
		return Vector3(roll, 0.0, lerpf(half_step, -half_step, t) - trail)
	# Swinging forward. The foot leaves toes-down and stays that way while the
	# heel kicks up behind; then the knee drives through, and the toes only
	# come up late, as the foot reaches out to land.
	var t := (phase - stance) / (1.0 - stance)
	# (sneaking, it is lifted and set down again evenly, with no flick to it)
	var height := sin(PI * pow(t, lerpf(0.62, 1.0, _duck))) * lift
	var trailing := push_off + sin(PI * minf(t / 0.45, 1.0)) * lerpf(0.12, 0.4, _run)
	var toe := lerpf(trailing, -strike - 0.1 * (1.0 - _duck), smoothstep(0.28, 0.92, t))
	var carry := lerpf(lerpf(smoothstep(0.0, 1.0, t), smoothstep(0.12, 0.95, t), _run), t * t * t * (t * (t * 6.0 - 15.0) + 10.0), _duck)
	return Vector3(toe, height, lerpf(-half_step, half_step, carry) - trail)


## Two-bone IK in hip space, the knee bending forward, or as far round from
## forward as `knee` (radians, positive towards his left).
func _solve_leg(index: int, side: float, target: Vector3, foot_basis: Basis, knee := 0.0) -> void:
	var hip := Vector3(side * _hip_width, _hip_drop, 0.0)
	var to_target := target - hip
	var reach := clampf(to_target.length(), 0.1, _thigh + _shin - 0.004)
	var direction := to_target.normalized() if to_target.length_squared() > 0.0001 else Vector3.DOWN
	var ahead := Vector3(sin(knee), 0.0, cos(knee))
	# The hinge of the knee is carried round with the leg from where it lies
	# when the leg hangs straight down, by the shortest way. (Taken afresh from
	# `ahead` each time, it turned over as the foot passed in front of the hip
	# or behind it, and went anywhere at all with the foot tucked up close.)
	var bend_axis := (Quaternion(Vector3.DOWN, direction) * Vector3.DOWN.cross(ahead)).normalized()
	var hip_angle := acos(clampf((_thigh * _thigh + reach * reach - _shin * _shin) / (2.0 * _thigh * reach), -1.0, 1.0))
	var thigh_direction := direction.rotated(bend_axis, hip_angle)
	var knee_at := hip + thigh_direction * _thigh
	var ankle := hip + direction * reach
	# Both bones are turned about the knee's own hinge, which lies across the
	# plane the leg bends in. (Taking each bone's side from `ahead` instead
	# turned it right round on itself whenever it pointed along or above that:
	# a knee brought up high, a heel out in front.)
	var across := -bend_axis
	var thigh_up := -thigh_direction
	var shin_up := (knee_at - ankle).normalized()
	_thighs[index].transform = Transform3D(Basis(across, thigh_up, across.cross(thigh_up)), hip)
	_shins[index].transform = Transform3D(Basis(across, shin_up, across.cross(shin_up)), knee_at)
	_feet[index].transform = Transform3D(foot_basis, ankle)
	_half_joints(index)


## Sets a leg's helper joints from where its thigh and shin are: each halfway
## round its joint. The knee's also rides out over the kneecap as the leg
## folds, which keeps the knee full where it would otherwise cave in.
func _half_joints(index: int) -> void:
	if index >= _knees.size():
		return
	var thigh := _thighs[index].basis.orthonormalized()
	var shin := _shins[index].basis.orthonormalized()
	var knee_at := _shins[index].position
	var down_thigh := -thigh.y
	var down_shin := -shin.y
	var fold := down_thigh.angle_to(down_shin)
	# (out of the crook: away from the line between hip and ankle)
	var crook := down_shin - down_thigh
	var out := -crook.normalized() if crook.length_squared() > 0.0001 else Vector3.ZERO
	_knees[index].transform = Transform3D(thigh.slerp(shin, 0.5), knee_at + out * 0.022 * pow(sin(fold * 0.5), 2.0))
	_seats[index].transform = Transform3D(Basis.IDENTITY.slerp(thigh, 0.5), _thighs[index].position)


func _pose_arms(vertical_speed: float, gait: float) -> void:
	# (his arms come over the top of a jump more slowly than his legs do)
	var rising := smoothstep(-5.0, 3.5, vertical_speed)
	var delta := minf(get_process_delta_time(), 1.0 / 30.0)
	var kneel := _kneeling()
	# Gone sprawling: how firmly his hands are on the ground. Scrambling up, they
	# are off it as soon as his feet are going.
	var rise := smoothstep(Player.SCRAMBLE.x + 0.14, 0.72, _recovery)
	var floored := _flooring() * (1.0 - _scramble * smoothstep(0.3, 0.6, rise))
	var hands_down := _flooring() * (1.0 - smoothstep(SPRAWL_HANDS.x, SPRAWL_HANDS.y, _recovery)) * (1.0 - _scramble * smoothstep(0.1, 0.4, rise))
	var pitched := _stumble
	# Where the bat is, and which way it points: up over his right shoulder,
	# until he swings it, when it goes round him level.
	var bat_angle := _keyed(SWING_ANGLE, _swing_at)
	# (waiting, he keeps the end of it going round in little circles)
	var waggle := Vector3(sin(_time * 2.3) * 0.13, 0.0, cos(_time * 2.3) * 0.1 + sin(_time * 0.7) * 0.05)
	var bat_tilt := _keyed(SWING_TILT, _swing_at)
	_bat_dir = (Vector3(-0.25, 0.9, -0.35) + waggle).lerp(Vector3(sin(bat_angle) * (1.0 - 0.5 * bat_tilt), bat_tilt, cos(bat_angle) * (1.0 - 0.5 * bat_tilt)), _swinging).normalized()
	var hands_round := _keyed(SWING_HANDS, _swing_at)
	var hands_out := _keyed(SWING_REACH, _swing_at)
	_bat_grip = Vector3(-0.16, 0.95, 0.1).lerp(Vector3(sin(hands_round) * hands_out, _keyed(SWING_HANDS_Y, _swing_at), 0.08 + cos(hands_round) * hands_out), _swinging)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		# Opposite to the leg on the same side, and a beat behind it. Negative
		# pitch is forward. His right arm swings the freer of the two, and each
		# swing takes after the step that goes with it.
		var beat := TAU * _phase - 0.3 * looseness
		var reach := (lerpf(0.5, 1.0, _run) + 0.2 * _sprint) * (1.0 - side * 0.1 * looseness) * (1.0 + 0.12 * _step_to[1 - i].z * looseness) * (1.0 - 0.3 * _stairs)
		var swing := side * cos(beat) * reach * gait
		var pitch := swing + 0.05
		# (at a run his elbows are out from his sides)
		var roll := side * (0.12 + 0.13 * _run * gait * looseness)
		# The forearm follows the upper arm late: the elbow closes as the arm
		# comes forward and falls open behind him, and the hand trails after both.
		var follow := side * cos(beat - 0.7 * looseness) * gait
		var elbow := -(0.14 + lerpf(0.12, 1.25, _run) * gait + maxf(-follow, 0.0) * lerpf(0.3, 0.5, _run) - maxf(follow, 0.0) * 0.3 * _run)
		var wrist := side * sin(beat - 0.4) * lerpf(0.32, 0.12, _run) * gait * looseness * (1.0 - _reach)
		# The hand: loosely open, the fingers never quite still.
		var curl := 0.42 + sin(_time * 0.6 + i * 2.3) * 0.05
		var splay := 0.3

		# At ease the arm on the side he leans to hangs a little further out.
		# Wary, both are held off the body, elbows bent, hands half closed.
		roll += side * maxf(side * _weight, 0.0) * 0.05 * _casual
		pitch += sin(_time * 0.45 + i * 1.9) * 0.03 * _casual
		pitch = lerpf(pitch, -0.12, _wary)
		roll = lerpf(roll, side * 0.3, _wary)
		elbow = lerpf(elbow, -0.85 + sin(_breath) * 0.03, _wary)
		curl = lerpf(curl, 0.85, _wary)
		# Running, his hands are fists.
		curl = lerpf(curl, 1.4, _run * gait)
		# Sneaking: his arms are tucked in tight, elbows to his ribs and inside
		# his knees, which are wide and would knock them; his hands are up in
		# front of his chest, open, and hardly move with his steps.
		pitch = lerpf(pitch, -0.5 + swing * 0.14 + sin(_time * 0.8 + i * 2.0) * 0.03, _duck)
		roll = lerpf(roll, side * 0.16, _duck)
		elbow = lerpf(elbow, -1.95 - side * cos(beat - 0.6) * 0.1 * gait, _duck)
		wrist = lerpf(wrist, 0.25, _duck)
		curl = lerpf(curl, 0.5 + sin(_time * 1.1 + i * 2.3) * 0.08, _duck)
		splay = lerpf(splay, 1.0, _duck)

		# Wading up to his waist his arms are held up out of the water, elbows
		# high, and go with his shoulders; in the shallows they are out a little for balance.
		pitch = lerpf(pitch, -0.5 + swing * 0.4, _wade_high)
		roll = lerpf(roll, side * 0.62, _wade_high) + side * 0.2 * _wade_low
		elbow = lerpf(elbow, -1.6, _wade_high)
		curl = lerpf(curl, 0.6, _wade_high)
		# In the air, the two poses again. Going up out of a run, the arm
		# opposite the leading knee punches forward and up and the other is
		# thrown back; straight up, both are thrown up together. Coming down,
		# both are held up and out from him, hands open, and they stay there.
		# (These are only where each arm is wanted: in the air it gets there on
		# a spring, the forearm after the upper arm. See below. No two jumps
		# are quite alike, nor his two arms; falling, they wheel a little.)
		var own := _jump_vary.x if i == 0 else _jump_vary.y
		var driven := lerpf(-2.5 + own * 0.25, (0.95 if i == _lead_leg else -1.8) + own * 0.2, _leap)
		var wheel := sin(_time * 7.5 + i * 2.4 + _jump_vary.z * 3.0) * (1.0 - rising)
		# (the arm that punched forward does not stop there: it goes on up and over the top of the jump)
		var apex := (1.0 - absf(2.0 * rising - 1.0)) * _leap * (0.0 if i == _lead_leg else 1.0)
		driven -= 0.75 * apex
		pitch = lerpf(pitch, lerpf(-0.75 + own * 0.2 + wheel * 0.3, driven, rising), _air)
		roll = lerpf(roll, side * lerpf(0.95 + own * 0.12, 0.28, rising), _air)
		elbow = lerpf(elbow, lerpf(-0.8 + wheel * 0.25, lerpf(-0.3, -0.4 if i == _lead_leg else -1.25 + 0.7 * apex, _leap), rising), _air)
		curl = lerpf(curl, lerpf(0.2, 0.9, rising), _air)
		splay = lerpf(splay, lerpf(1.0, 0.4, rising), _air)

		# Take-off throws the arms up and forward; landing spreads them for balance.
		pitch = lerpf(pitch, -1.9, _launch * _launch)
		elbow = lerpf(elbow, -0.6, _launch * _launch)
		# (out and down in front of him, as his weight comes down onto his feet)
		var landing := _land * (1.0 - _air)
		pitch = lerpf(pitch, lerpf(-0.45, 0.2, _leap), landing)
		roll = lerpf(roll, side * 0.62, landing)
		elbow = lerpf(elbow, -0.85, landing)
		curl = lerpf(curl, 0.1, landing)
		splay = lerpf(splay, 1.0, landing)

		roll = lerpf(roll, side * 0.75, _skid)
		elbow = lerpf(elbow, -0.5, _skid)
		curl = lerpf(curl, 0.1, _skid)
		splay = lerpf(splay, 1.0, _skid)

		# Spinning, they are flung out, the one on the inside of the turn the
		# higher; reeling out of it, held out and going up and down like a tightrope walker's.
		var inside := i == (0 if _whirl_way > 0.0 else 1)
		pitch = lerpf(pitch, 0.22 if inside else -0.1, _whirl)
		roll = lerpf(roll, side * (1.42 if inside else 1.12), _whirl)
		elbow = lerpf(elbow, -0.18 if inside else -0.4, _whirl)
		curl = lerpf(curl, 0.1, _whirl)
		splay = lerpf(splay, 1.1, _whirl)
		pitch += sin(_time * 4.1 + i * 2.0) * 0.3 * _reel
		roll = lerpf(roll, side * (0.9 + sin(_time * 6.3 + i * PI) * 0.35), _reel)
		elbow = lerpf(elbow, -0.45, _reel)
		splay = lerpf(splay, 1.1, _reel)
		# A yawn and a stretch: one fist up by his ear and then pushed up as far
		# as it will go; the other hand to his mouth, and then out to the side.
		if _stretch > 0.0:
			var out := smoothstep(0.3, 0.62, _yawn_at)
			if i == 0:
				pitch = lerpf(pitch, lerpf(-2.3, -2.95, out), _stretch)
				roll = lerpf(roll, side * lerpf(0.8, 0.42, out), _stretch)
				elbow = lerpf(elbow, lerpf(-2.1, -0.22, out), _stretch)
				curl = lerpf(curl, lerpf(1.3, 0.3, out), _stretch)
			else:
				pitch = lerpf(pitch, lerpf(-1.25, -0.4, out), _stretch)
				roll = lerpf(roll, side * lerpf(0.42, 1.3, out), _stretch)
				elbow = lerpf(elbow, lerpf(-2.35, -0.6, out), _stretch)
				curl = lerpf(curl, lerpf(0.5, 1.3, out), _stretch)
			splay = lerpf(splay, 1.0, _stretch * out)

		pitch = lerpf(pitch, -1.3, _push)
		roll = lerpf(roll, -side * 0.06, _push)
		elbow = lerpf(elbow, -0.4, _push)

		# Sliding: one hand is down flat on the ground behind him to steady
		# himself (see _reach_arms), the other held out for balance, or on his cap.
		var steadying := i == (1 if _slide_side > 0.0 else 0)
		pitch = lerpf(pitch, 0.7 if steadying else -0.75, _slide)
		roll = lerpf(roll, side * (0.3 if steadying else 0.75), _slide)
		elbow = lerpf(elbow, -0.3 if steadying else -0.55, _slide)
		curl = lerpf(curl, 0.0 if steadying else 0.25, _slide)
		splay = lerpf(splay, 1.1, _slide)
		# Hanging by the hands (which the ledge then places: see _reach_arms).
		# Once he is up and lets go of it they come down to his sides.
		pitch = lerpf(pitch, lerpf(-2.95, -0.55, smoothstep(0.15, 0.75, _climb)), _hang)
		roll = lerpf(roll, side * 0.12, _hang)
		elbow = lerpf(elbow, -0.12 - sin(PI * _climb) * 1.2, _hang)
		curl = lerpf(curl, lerpf(0.95, 0.3, smoothstep(0.5, 0.8, _climb)), _hang)
		# Hand over hand up a rope.
		var haul := sin(TAU * _rope_phase / (Player.ROPE_PULL * 2.0) + i * PI)
		pitch = lerpf(pitch, -2.55 + haul * 0.3, _rope)
		roll = lerpf(roll, -side * 0.2, _rope)
		elbow = lerpf(elbow, -0.9 + haul * 0.45, _rope)
		curl = lerpf(curl, 1.3, _rope)
		# Carrying: in his right hand, the arm crooked at his side, going with
		# his steps a little. Stooping for it, that hand goes down to it open
		# (see _reach_arms) and the other out behind him.
		if i == 1:
			# (a dip of the hand before the toss, a flick to send it up, and a give as it is caught)
			var flick := exp(-pow((_juggle - 0.97) / 0.035, 2.0)) * 0.3 - exp(-pow(_juggle / 0.035, 2.0)) * 0.4 + exp(-pow((_juggle - 0.36) / 0.04, 2.0)) * 0.25
			pitch = lerpf(lerpf(pitch, -0.3 + swing * 0.3, _carry), -0.9, _stoop)
			roll = lerpf(roll, side * 0.34, _carry)
			elbow = lerpf(elbow, -1.3 + flick, _carry)
			# (a torch is held up and out in front of him, clear of his face and his cap)
			pitch = lerpf(pitch, -1.15 + swing * 0.12, _torch * (1.0 - _stoop))
			roll = lerpf(roll, side * 0.5, _torch)
			elbow = lerpf(elbow, -0.75, _torch)
			# (a hook's coil hangs from his hand at his side, held a little out to clear his leg)
			pitch = lerpf(pitch, 0.05 + swing * 0.2, _coil * (1.0 - _stoop))
			roll = lerpf(roll, side * 0.3, _coil)
			elbow = lerpf(elbow, -0.4, _coil)
			curl = lerpf(lerpf(curl, 0.95, _carry), lerpf(0.1, 0.95, smoothstep(Player.PICKUP_TAKES - 0.12, Player.PICKUP_TAKES, _picking)), _stoop)
			splay = lerpf(splay, 0.9, _stoop)
		else:
			pitch = lerpf(pitch, 0.45, _stoop)
			roll = lerpf(roll, side * 0.5, _stoop)
			elbow = lerpf(elbow, -0.4, _stoop)
		# Throwing. (See the PITCH_ curves.)
		if _pitching > 0.001:
			if i == 1:
				pitch = lerpf(pitch, _keyed(PITCH_ARM, _pitch_at), _pitching)
				roll = lerpf(roll, side * _keyed(PITCH_OUT, _pitch_at), _pitching)
				elbow = lerpf(elbow, _keyed(PITCH_ELBOW, _pitch_at), _pitching)
				var gone := smoothstep(Player.THROW_RELEASE - 0.03, Player.THROW_RELEASE + 0.05, _pitch_at)
				curl = lerpf(curl, lerpf(0.95, 0.05, gone), _pitching)
				splay = lerpf(splay, lerpf(0.5, 1.1, gone), _pitching)
			else:
				pitch = lerpf(pitch, -0.3, _pitching)
				roll = lerpf(roll, side * _keyed(PITCH_GLOVE_OUT, _pitch_at), _pitching)
				elbow = lerpf(elbow, _keyed(PITCH_GLOVE_ELBOW, _pitch_at), _pitching)
				curl = lerpf(curl, 0.7, _pitching)

		# Throwing a grappling hook, underarm. (See the HOOK_ curves.)
		if _casting > 0.001:
			if i == 1:
				pitch = lerpf(pitch, _keyed(HOOK_ARM, _cast_at), _casting)
				roll = lerpf(roll, side * _keyed(HOOK_OUT, _cast_at), _casting)
				elbow = lerpf(elbow, _keyed(HOOK_ELBOW, _cast_at), _casting)
				curl = lerpf(curl, 0.9, _casting)
			else:
				pitch = lerpf(pitch, _keyed(HOOK_GUIDE, _cast_at), _casting)
				roll = lerpf(roll, side * 0.25, _casting)
				elbow = lerpf(elbow, -0.3, _casting)
		# Winding it in: hand over hand in front of his chest. (See the REEL_ curves.)
		if _reeling > 0.001:
			var pull := fposmod(_reel_at * 3.0 + 0.5 * i, 1.0)
			pitch = lerpf(pitch, _keyed(REEL_ARM, pull), _reeling)
			roll = lerpf(roll, side * 0.08, _reeling)
			elbow = lerpf(elbow, _keyed(REEL_ELBOW, pull), _reeling)
			curl = lerpf(curl, 0.9, _reeling)

		pitch = lerpf(pitch, -1.35 + sin(_time * 1.3 + i * 1.7) * 0.08, arms_reach)
		roll = lerpf(roll, -side * 0.05, arms_reach)
		elbow = lerpf(elbow, -0.25, arms_reach)

		# Down on three points: a fist on the ground in front of him (put there
		# by _reach_arms), on the side of the knee that is down, his other arm
		# flung out behind for balance. Gone sprawling, that arm comes round,
		# the fist opens, and he is on both hands, spread flat either side of
		# his chest, his elbows up and out as they give under him.
		var fisted := kneel if i == _down else 0.0
		_plant[i] = minf(fisted + hands_down, 1.0)
		_plant_flat[i] = hands_down / maxf(fisted + hands_down, 0.001)
		_plant_at[i] = Vector3(side * 0.06, 0.04, 0.37).lerp(Vector3(side * 0.19, 0.022, 0.42), _plant_flat[i])
		_plant_fingers[i] = Vector3(-side * 0.25, 0.0, 1.0)
		_plant_pole[i] = Vector3(side, 0.55, -0.5) if _plant_flat[i] > 0.5 else Vector3.ZERO
		if i == _down:
			pitch = lerpf(pitch, -0.9, kneel)
			curl = lerpf(curl, 1.4, kneel)
		else:
			# (flung out behind him, and wheeling a little until he has his balance)
			pitch = lerpf(pitch, 1.15 + sin(_recovery * 17.0) * 0.3 * (1.0 - smoothstep(0.1, 0.5, _recovery)), kneel)
			roll = lerpf(roll, side * 0.6, kneel)
			elbow = lerpf(elbow, -0.25, kneel)
			curl = lerpf(curl, 0.2, kneel)
		splay = lerpf(splay, 1.0, kneel)
		pitch = lerpf(pitch, -1.2, floored)
		roll = lerpf(roll, side * 0.4, floored)
		elbow = lerpf(elbow, -1.0, floored)
		curl = lerpf(curl, -0.08, hands_down)
		splay = lerpf(splay, 1.35, hands_down)
		# Sliding, one is planted behind him.
		if steadying and _slide > _plant[i]:
			_plant[i] = _slide
			_plant_flat[i] = 1.0
			_plant_at[i] = Vector3(-0.3 * _slide_side, 0.022, -0.44)
			_plant_fingers[i] = Vector3(-0.7 * _slide_side, 0.0, -0.7)
			_plant_pole[i] = Vector3.ZERO
		# Stooping, the right goes down to what he is picking up.
		if i == 1 and _grab > _plant[i]:
			_plant[i] = _grab
			_plant_flat[i] = 0.0
			_plant_at[i] = Vector3(_pick_at.x, maxf(_pick_at.y + 0.06, 0.07), _pick_at.z)
			_plant_pole[i] = Vector3.ZERO
		# Stumbling: both thrown out in front of him to save himself, wheeling.
		pitch = lerpf(pitch, -1.25 + sin(_recovery * 28.0 + i * PI) * 0.55, pitched)
		roll = lerpf(roll, side * 0.6, pitched)
		elbow = lerpf(elbow, -0.5, pitched)
		curl = lerpf(curl, 0.1, pitched)
		splay = lerpf(splay, 1.1, pitched)
		# A dive: both thrown out ahead of him, one a little before the other,
		# fingers spread; reaching for the ground as it comes, elbows giving.
		pitch = lerpf(pitch, -2.92 + (0.14 if i == 0 else -0.06) + 0.38 * _dive_near, _dive)
		roll = lerpf(roll, side * (0.16 + 0.1 * _dive_near), _dive)
		elbow = lerpf(elbow, -0.14 - 0.5 * _dive_near, _dive)
		curl = lerpf(curl, 0.05, _dive)
		splay = lerpf(splay, 1.15, _dive)
		# A back tuck: thrown up over his head to take him up, and then...
		var thrown_up := _flip * (1.0 - smoothstep(0.1, 0.28, _flip_at))
		pitch = lerpf(pitch, -2.8 + (0.1 if i == 0 else -0.1), thrown_up)
		roll = lerpf(roll, side * 0.25, thrown_up)
		elbow = lerpf(elbow, -0.3, thrown_up)
		# Rolling: his hands go down to meet the ground, then he is wrapped round his knees.
		var down := 1.0 - smoothstep(0.06, 0.24, _tumble)
		pitch = lerpf(pitch, lerpf(-1.05, -1.75, down), _curled)
		roll = lerpf(roll, -side * 0.05, _curled)
		elbow = lerpf(elbow, lerpf(-1.9, -0.45, down), _curled)
		curl = lerpf(curl, lerpf(0.9, 0.0, down), _curled)
		# (coming out of the tuck they go out to the sides, to stop him turning and to land with)
		var opened := _flip * smoothstep(0.62, 0.8, _flip_at)
		pitch = lerpf(pitch, -0.2, opened)
		roll = lerpf(roll, side * 1.15, opened)
		elbow = lerpf(elbow, -0.35, opened)
		curl = lerpf(curl, 0.15, opened)
		# Landed, his fists go to his hips.
		if _cocky > _plant[i]:
			_plant[i] = _cocky
			_plant_flat[i] = 0.0
			_plant_at[i] = Vector3(side * (_hip_width + 0.09), _hips.position.y + 0.075, 0.0)
			_plant_pole[i] = Vector3(side, -0.15, -0.6)
			curl = lerpf(curl, 1.25, _cocky)
		# With a pistol up, his other fist is on his hip, out of the way.
		var akimbo := _aiming * _gun * (1.0 - _gun_long) * (1.0 - _run) if i == 0 else 0.0
		if akimbo > _plant[i]:
			_plant[i] = akimbo
			_plant_flat[i] = 0.0
			_plant_at[i] = Vector3(side * (_hip_width + 0.09), _hips.position.y + 0.07, -0.02)
			_plant_pole[i] = Vector3(side, -0.15, -0.6)
			curl = lerpf(curl, 1.25, akimbo)
		# A gun: the hand that has it is closed on it, and the other under a long one. (See _hold_gun.)
		if i == 1:
			curl = lerpf(curl, 1.25, _gun)
		else:
			curl = lerpf(curl, 0.85, _gun * _gun_long)
		# Sat down: one hand is flat on the ground behind him, taking his weight,
		# and the other arm lies along the knee that is up. Lying down, the first
		# lets go and pulls his cap over his face, and then lies in front of his
		# chest (and comes up now and then to scratch his nose); the second
		# goes down to the ground beside him to let him down onto, and then under his head.
		if _sit_at > 0.0:
			var sitting := smoothstep(0.0, 0.14, _sit_at)
			var propping := i == (1 if _lie_side > 0.0 else 0)
			var asleep := smoothstep(0.86, 1.0, _lie_at)
			var how := 0.0
			var where := Vector3.ZERO
			var flat := 0.0
			var pole := Vector3.ZERO
			if propping:
				var prop := smoothstep(0.28, 0.5, _sit_at) * (1.0 - smoothstep(0.05, 0.32, _lie_at))
				var to_cap := sin(PI * smoothstep(0.42, 0.9, _lie_at))
				var itch := fposmod(_time, 17.0) / 2.6
				var scratching := smoothstep(0.0, 0.15, itch) * (1.0 - smoothstep(0.8, 1.0, itch)) * asleep if itch < 1.0 else 0.0
				var chest := (_chest if _chest else _spine).global_transform
				var lain := to_local(chest * Vector3(side * 0.04, -0.04, 0.2))
				lain.y = 0.035
				var at_cap := to_local(_head.global_transform * Vector3(-side * 0.03, 0.19 - 0.09 * _cap_over, 0.1 + 0.03 * _cap_over))
				var at_nose := to_local(_head.global_transform * Vector3(-side * 0.02 + sin(_time * 13.0) * 0.008, 0.075 + sin(_time * 13.0) * 0.012, 0.13))
				where = Vector3(side * 0.27, 0.022, lerpf(-0.3, -0.52, smoothstep(0.5, 0.9, _sit_at)))
				where = where.lerp(at_cap, smoothstep(0.3, 0.55, _lie_at)).lerp(lain, smoothstep(0.82, 1.0, _lie_at)).lerp(at_nose, scratching)
				how = maxf(prop, maxf(to_cap, smoothstep(0.82, 1.0, _lie_at)))
				flat = prop * (1.0 - smoothstep(0.0, 0.2, _lie_at))
				_plant_fingers[i] = Vector3(side * 0.55, 0.0, -0.85)
				pole = Vector3(side * 0.4, 0.3, -1.0).lerp(Vector3(side * 0.6, -0.5, 0.6), smoothstep(0.2, 0.5, _lie_at))
				curl = lerpf(curl, lerpf(-0.05, 0.55, smoothstep(0.1, 0.4, _lie_at)), sitting)
				splay = lerpf(splay, 1.2, prop)
			else:
				var on_knee := smoothstep(0.62, 0.9, _sit_at) * (1.0 - smoothstep(0.0, 0.25, _lie_at))
				var lowering := smoothstep(0.05, 0.3, _lie_at) * (1.0 - smoothstep(0.55, 0.85, _lie_at))
				var pillow := smoothstep(0.55, 0.9, _lie_at)
				var rub := sin(PI * smoothstep(0.0, 0.8, _rub_at)) if _rub_at < 1.0 else 0.0
				var at_knee := to_local(_shins[i].global_position) + Vector3(0.0, 0.045, 0.04)
				var at_eye := to_local(_head.global_transform * Vector3(side * 0.035 + sin(_time * 11.0) * 0.006, 0.085 + cos(_time * 11.0) * 0.006, 0.115))
				var under_head := to_local(_head.global_transform * Vector3(side * 0.11, 0.07, 0.02))
				under_head.y = maxf(under_head.y, 0.03)
				where = at_knee.lerp(Vector3(side * 0.42, 0.022, -0.1), smoothstep(0.05, 0.3, _lie_at)).lerp(under_head, pillow).lerp(at_eye, rub)
				how = maxf(maxf(on_knee, lowering), maxf(pillow, rub))
				flat = lowering * (1.0 - pillow)
				_plant_fingers[i] = Vector3(side * 0.8, 0.0, 0.6)
				pole = Vector3(side, 0.1, -0.5).lerp(Vector3(side * 0.2, -0.3, 1.0), pillow)
				curl = lerpf(curl, lerpf(0.5, 1.2, rub), sitting)
			if how > _plant[i]:
				_plant[i] = how
				_plant_flat[i] = flat
				_plant_at[i] = where
				_plant_pole[i] = pole

		# Crawling: each hand is set down flat ahead of him as the knee opposite comes up.
		if _crawl > _plant[i]:
			var cr_at := fposmod(_phase + 0.5 * (1 - i), 1.0)
			var cr_back := lerpf(0.12, -0.12, cr_at / 0.65) if cr_at < 0.65 else lerpf(-0.12, 0.12, (cr_at - 0.65) / 0.35)
			_plant[i] = _crawl
			_plant_flat[i] = 1.0
			_plant_at[i] = Vector3(side * 0.15, 0.022 + (sin(PI * (cr_at - 0.65) / 0.35) * 0.04 * _move if cr_at > 0.65 else 0.0), 0.3 + cr_back * _move)
			_plant_fingers[i] = Vector3(-side * 0.15, 0.0, 1.0)
			_plant_pole[i] = Vector3(side, 0.2, -0.7)
			curl = lerpf(curl, -0.05, _crawl)
			splay = lerpf(splay, 1.2, _crawl)
		# Winded: his hands are on his knees, taking the weight of him.
		if _tired > _plant[i]:
			_plant[i] = _tired
			_plant_flat[i] = 0.0
			_plant_at[i] = to_local(_shins[i].global_position) + Vector3(0.0, 0.035, 0.045)
			if i == 0:
				# (the back of his left hand across his forehead)
				_plant_at[i] = _plant_at[i].lerp(to_local(_head.global_transform * Vector3(-0.03, 0.13, 0.13)), smoothstep(0.0, 0.7, _wipe))
			_plant_pole[i] = Vector3(side, 0.2, -0.5)
			curl = lerpf(curl, 0.75, _tired)
			splay = lerpf(splay, 0.9, _tired)
		# On a ladder his hands are on the rungs (put there by _reach_arms).
		# Hanging off it to look about, the one towards the camera is let go
		# and hangs; and they come down to his sides as he steps off the top.
		var hanging_off := _ladder_rest if i == _hat_arm else 0.0
		_reach_let[i] = hanging_off * _ladder
		# (with nothing left to hold, near the top, they are out in front of him for balance)
		var let_go := maxf(hanging_off, (1.0 - _reach) * (1.0 - smoothstep(0.5, 1.0, _ladder_off)) * 0.6 + smoothstep(0.5, 1.0, _ladder_off))
		# (off the top they are not just held out: one goes forward as that foot goes up, and the other back)
		var balancing := sin(PI * smoothstep(0.35, 1.0, _ladder_off)) * (-0.95 if i == 0 else 0.5)
		pitch = lerpf(pitch, lerpf(-2.2, 0.2 + sin(_time * 1.9) * 0.12 + balancing, let_go), _ladder)
		roll = lerpf(roll, side * lerpf(0.1, 0.4, let_go), _ladder)
		elbow = lerpf(elbow, lerpf(-0.8, -0.25, let_go), _ladder)
		curl = lerpf(curl, lerpf(1.3, 0.45, let_go), _ladder)
		# Swimming. Breast stroke (and under water, with a frog kick): both
		# hands reach ahead together, sweep out and back to his chest, and
		# come forward again. A crawl: each arm in turn goes over and reaches,
		# and pulls down and back under him. With a flutter kick under water
		# they are stretched out ahead. Treading water they scull.
		# (His hands are placed, from his chest, and the arm follows: so going
		# from one stroke to another is only his hands going somewhere else.
		# In his chest's own frame up is towards his head and forward is the
		# way his chest faces, which lying in the water is down.)
		if _swim > _plant[i]:
			var sw_at := TAU * _stroke + PI * i
			var sw_pull := smoothstep(0.2, 0.55, _stroke) * (1.0 - smoothstep(0.7, 0.95, _stroke))
			var sw_wide := sin(PI * smoothstep(0.2, 0.62, _stroke))
			var sw_breast := Vector3(side * (-0.07 + 0.3 * sw_wide), 0.42 - (0.36 + 0.3 * _under) * sw_pull, 0.1 + 0.1 * sw_pull)
			var sw_crawl := Vector3(side * 0.05, cos(sw_at) * 0.4, sin(sw_at) * (0.3 if sin(sw_at) > 0.0 else 0.17) + 0.04)
			var sw_glide := Vector3(-side * 0.07, 0.43, 0.05 + sin(TAU * _stroke * 3.0 + i * PI) * 0.015)
			var scull := TAU * _stroke * 2.0 + i * 1.3
			var sw_tread := Vector3(side * (0.27 + 0.08 * sin(scull)), -0.13 + 0.03 * sin(scull * 0.5 + i), 0.2 + 0.1 * cos(scull))
			var sw_flung := Vector3(side * 0.34, 0.3, 0.06)
			var sw_hand := sw_tread.lerp(sw_breast.lerp(sw_crawl.lerp(sw_glide, _under), _swim_fast), _swim_go).lerp(sw_flung, _plunge).lerp(Vector3(-side * 0.05, 0.45, 0.04), _dive_in)
			var frame := (_chest if _chest else _spine).global_transform
			_plant[i] = _swim
			_plant_flat[i] = 0.0
			_plant_at[i] = to_local(frame * (_shoulder_rest[i] + sw_hand))
			# (his elbows are out to the side, and high as the arm comes over)
			_plant_pole[i] = global_basis.orthonormalized().inverse() * (frame.basis.orthonormalized() * Vector3(side, -0.25, -0.75))
			curl = lerpf(curl, 0.1, _swim)
			splay = lerpf(splay, lerpf(0.25, 1.0, _plunge), _swim)
		# A bat: both hands on the handle, the left below the right.
		if _bat > _plant[i]:
			_plant[i] = _bat
			_plant_flat[i] = 0.0
			_plant_at[i] = _bat_grip + _bat_dir * (0.1 if i == 1 else 0.02)
			_plant_pole[i] = Vector3(side * 0.7, -1.0, -0.2)
			curl = lerpf(curl, 1.3, _bat)
		# Holding his cap on: that arm is put there by _reach_arms; the other
		# pumps the harder for it.
		if i == _hat_arm:
			curl = lerpf(curl, 0.35, _hat)
			splay = lerpf(splay, 0.9, _hat)
			pitch = lerpf(pitch, -2.4, _hat)
			roll = lerpf(roll, side * 0.7, _hat)
			elbow = lerpf(elbow, -1.6, _hat)
		# Pressed against something, the hand is flat and the fingers spread;
		# unless they are hooked over the edge of it.
		var pressed := _flat * _reach * (1.0 - _carry * (1.0 - _coil) if i == 1 else 1.0)
		curl = lerpf(curl, -0.08, pressed * (1.0 - _hook))
		splay = lerpf(splay, lerpf(1.25, 0.45, _hook), pressed)

		# The shoulder goes with the arm, and rises and falls as he breathes:
		# hardly at all until he is out of breath, or afraid. Sneaking, they are up round his ears.
		# In the air his arms are thrown, not placed. Each follows where it is
		# wanted on a spring, so it comes up through the take-off with whatever
		# swing it had, lags over the top and overshoots; the forearm is slower
		# than the upper arm, and the hand trails them both.
		var wanted := Vector3(pitch, roll, elbow)
		if _arm_free < 0.02:
			_arm_speed[i] = ((wanted - _arm_at[i]) / delta).limit_length(14.0)
			_arm_at[i] = wanted
		else:
			var pull := (wanted - _arm_at[i]) * Vector3(85.0, 100.0, 50.0) - _arm_speed[i] * Vector3(8.0, 9.5, 5.5)
			# (and they fly out as he turns)
			pull.y += side * absf(_yaw_rate) * 1.6
			_arm_speed[i] += pull * delta
			_arm_at[i] += _arm_speed[i] * delta
			_arm_at[i].z = clampf(_arm_at[i].z, -2.4, 0.0)
			pitch = lerpf(pitch, _arm_at[i].x, _arm_free)
			roll = lerpf(roll, _arm_at[i].y, _arm_free)
			elbow = lerpf(elbow, _arm_at[i].z, _arm_free)
			wrist += clampf(_arm_speed[i].x * 0.05 + _arm_speed[i].z * 0.06, -0.7, 0.7) * _arm_free * looseness
		var shrug := (sin(_breath) * (0.002 + 0.007 * _puff) + _wary * 0.01 + _duck * 0.014) * looseness + (0.03 * _hat if i == _hat_arm else 0.0)
		_shoulders[i].position = _shoulder_rest[i] + Vector3(0.0, shrug, -swing * 0.022 * looseness)
		_shoulders[i].rotation = Vector3(pitch, 0.0, roll)
		_elbows[i].rotation = Vector3(elbow, 0.0, 0.0)
		_hands[i].rotation = Vector3(wrist * (1.0 - _carry if i == 1 else 1.0), 0.0, 0.0)
		_curl[i] = _approach(_curl[i], curl, 14.0, delta)
		_splay[i] = _approach(_splay[i], splay, 14.0, delta)
		_pose_fingers(i, side)


## Closes or opens a hand. The fingers are modelled straight and fanned out;
## each is gathered towards the middle of the hand (less so the more it is
## spread) and curled joint by joint towards the palm. Hooked over an edge,
## they bend at the knuckles and lie straight beyond them.
func _pose_fingers(hand: int, side: float) -> void:
	var curl := _curl[hand]
	var hook := _hook * _reach
	var palm := Vector3(-side, 0.0, 0.0)
	for k in _fingers[hand].size():
		var line: Vector3 = _finger_lines[hand][k]
		var fan := atan2(line.z, -line.y) * clampf(_splay[hand], 0.0, 1.4)
		var gathered := Vector3(0.0, -cos(fan), sin(fan))
		# (the little finger closes soonest and furthest, as in a real fist)
		var bend := curl * (1.0 + 0.06 * k)
		var joints: Array = _fingers[hand][k]
		joints[0].basis = Basis(gathered.cross(palm).normalized(), lerpf(bend * 1.05, 1.5, hook)) * Basis(Quaternion(line, gathered))
		joints[1].basis = Basis(line.cross(palm).normalized(), lerpf(maxf(bend, 0.0) * 1.2, 0.12, hook))
		joints[2].basis = Basis(line.cross(palm).normalized(), lerpf(maxf(bend, 0.0) * 0.85, 0.2, hook))
	if _thumbs[hand].size() == 2:
		# The thumb swings across the palm as the hand closes and lies over the fingers.
		var line := _thumb_lines[hand]
		var across := line.cross(palm).normalized()
		var closed := lerpf(clampf(curl / 1.4, -0.2, 1.0), 0.15, hook)
		_thumbs[hand][0].basis = Basis(Vector3.DOWN, side * (closed * 0.9 - (_splay[hand] - 0.3) * 0.35)) * Basis(across, closed * 0.55)
		_thumbs[hand][1].basis = Basis(across, maxf(closed, 0.0) * 0.9)


func _on_jumped() -> void:
	_crouch_velocity -= 1.2
	_launch = 1.0
	_jump_vary = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	# Tuck whichever leg is already swinging forward.
	_lead_leg = 1 if _phase < 0.5 else 0
	_jumped = 1.0
	# (each foot from where it is: out of a run, the one that drives him is behind him already)
	for i in 2:
		_sprang_from[i] = Vector3(_foot_world[i].x, global_position.y, _foot_world[i].z)
		# (a foot already off the ground and on its way forward is not brought back to push)
		_drove[i] = 1.0 - smoothstep(0.02, 0.12, _foot_world[i].y - global_position.y)
	# (and his arms are thrown into it: both up together from a standstill; out
	# of a run the one opposite that knee forward and the other back)
	for i in 2:
		_arm_speed[i].x += lerpf(-9.0, 5.0 if i == _lead_leg else -7.0, _leap)


func _on_landed(impact_speed: float) -> void:
	# A hard landing is a pose of its own (see _three, _stumble and _roll); an
	# ordinary one is taken in the knees, the arms going out for balance.
	var hard: bool = &"landing" in _player and _player.landing != Player.Landing.SOFT
	_crouch_velocity += clampf(impact_speed * 0.5, 0.6, 7.0) * (0.3 if hard else 1.0)
	var from_dive: bool = &"dive_roll" in _player and _player.dive_roll
	for i in 2:
		if from_dive:
			# (it is his hands that come down, ahead of him)
			footfall.emit(global_position + global_basis * Vector3((1.0 if i == 0 else -1.0) * 0.14, 0.0, 0.6), i, 0.8)
		else:
			footfall.emit(global_position + global_basis * Vector3((1.0 if i == 0 else -1.0) * _hip_width, 0.0, 0.03), i, clampf(impact_speed / 5.0, 0.5, 3.0))
	# (out of a back tuck, landed on his feet, he is pleased with himself)
	if _flip > 0.3 and not hard:
		_swagger = 1.0
		_crouch_velocity += 1.2
	if hard:
		scraped.emit(global_position, _prev_velocity, 1.0)
	if _dust and impact_speed > 3.0 and dust_scale > 0.0:
		_dust.puff(global_position + Vector3.UP * 0.03, Vector3.ZERO, clampf(impact_speed * 0.016, 0.1, 0.24) * dust_scale, 5 if hard else 3, 1.4)
	_land = 0.0 if hard else clampf((impact_speed - 2.0) / 7.0, 0.25, 1.0)
	_give = 0.0 if hard else clampf((impact_speed - 3.0) / 6.0, 0.0, 1.0)
	_give_at = 0.0


## A foot went to the wall and he sprang off it. That leg is left stretched
## out behind him to where it pushed; the other knee comes up.
func _on_kicked_off() -> void:
	_leap = 1.0
	_launch = 0.0
	_kick = 1.0
	var away: Vector3 = _player.velocity
	away.y = 0.0
	away = away.normalized()
	# (the leg nearer the wall as he turns away from it)
	_kick_leg = 0 if away.dot(global_basis.x) < 0.0 else 1
	_lead_leg = 1 - _kick_leg
	_kick_point = global_position - away * 0.34 + Vector3.UP * 0.22


## He has thrown himself into a dive: forward off whichever leg he jumped from.
func _on_dived() -> void:
	_dive_pitch = 0.45
	_dive_near = 0.0
	_launch = 0.0


## The gun he holds has gone off. He takes it in his hands, his shoulder and his
## back (see _hold_gun and _pose_body), and it jolts the rest of him.
func _on_shot(kick: float) -> void:
	_recoil_speed += kick * 17.0
	_crouch_velocity += kick * 0.9
	_cap_velocity += Vector3.UP * kick * 0.6


func _on_threw() -> void:
	_watch = _player.last_thrown if &"last_thrown" in _player else null
	_watching = 1.4


## Where the sole of a foot is, in the world (0 the left, 1 the right).
func foot_position(foot: int) -> Vector3:
	return _feet[foot].global_transform * Vector3(0.0, -ANKLE, 0.03)


## Whether that foot is on the ground.
func is_planted(foot: int) -> bool:
	return _planted[foot]


func _on_respawned() -> void:
	# (he starts again from standing, not from the middle of whatever he was doing)
	_duck = 0.0
	_slide = 0.0
	_hang = 0.0
	_climb = 0.0
	_rope = 0.0
	_ladder = 0.0
	_swim = 0.0
	_under = 0.0
	_crawl = 0.0
	_bat = 0.0
	_swinging = 0.0
	_carry = 0.0
	_stoop = 0.0
	_pitching = 0.0
	_casting = 0.0
	_reeling = 0.0
	_reach = 0.0
	_reach_held = false
	_three = 0.0
	_sprawled = 0.0
	_scramble = 0.0
	_stumble = 0.0
	_roll = 0.0
	_ball = 0.0
	_recovery = 1.0
	_taking = 0
	_tired = 0.0
	_winded = 0.0
	_air = 0.0
	_launch = 0.0
	_land = 0.0
	_jumped = 0.0
	_give = 0.0
	_give_at = 1.0
	_legs_in = 0.0
	_skid = 0.0
	_sprint = 0.0
	_hat = 0.0
	_run = 0.0
	_move = 0.0
	_kick = 0.0
	_plunge = 0.0
	_wet = 0.0
	_shake = 0.0
	_shaken = true
	_toss = 0.0
	_ladder_rest = 0.0
	_ladder_off = 0.0
	_sway = 0.0
	_sway_speed = 0.0
	_dive = 0.0
	_dive_roll = 0.0
	_dive_in = 0.0
	_flip = 0.0
	_flip_at = 1.0
	_tuck = 0.0
	_curled = 0.0
	_swagger = 0.0
	_cocky = 0.0
	_whirl = 0.0
	_reel = 0.0
	_sit_at = 0.0
	_lie_at = 0.0
	_cap_over = 0.0
	_stretch = 0.0
	_wade_low = 0.0
	_wade_high = 0.0
	_gun = 0.0
	_aiming = 0.0
	_recoil = 0.0
	_recoil_speed = 0.0
	_lean = Vector2.ZERO
	_prev_velocity = Vector3.ZERO
	_prev_yaw = rotation.y
	_accel = Vector3.ZERO
	_yaw_rate = 0.0
	_crouch = 0.0
	_crouch_velocity = 0.0
	_dangles_settled = false
	_cap_settled = false


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))


func _build() -> void:
	var figure := (model if model else MODELS[1 if low_poly or Settings.low_poly else 0]).instantiate()
	add_child(figure)
	_figure = figure
	made_colours = Toon.colours_of(figure)
	add_to_group(&"figures")
	_skeleton = figure.find_children("*", "Skeleton3D", true, false)[0]

	_measure()
	_hips = _joint(self, &"hips", Vector3(0.0, _hip_height, 0.0))
	_spine = _joint(_hips, &"spine", _rest(&"spine"))
	var back := _spine
	if _has(&"chest"):
		_chest = _joint(_spine, &"chest", _rest(&"chest"))
		back = _chest
	if _has(&"neck"):
		_neck = _joint(back, &"neck", _rest(&"neck"))
	_head = _joint(_neck if _neck else back, &"head", _rest(&"head"))
	for bone: String in ["eye_l", "eye_r"]:
		if _has(bone):
			_eye_joints.append(_joint(_head, bone, _rest(bone)))
	for suffix: String in ["_l", "_r"]:
		var side := 1 if suffix == "_l" else -1
		var shoulder := _joint(back, "upper_arm" + suffix, _rest("upper_arm" + suffix), side * 2)
		_shoulders.append(shoulder)
		_shoulder_rest.append(shoulder.position)
		_elbows.append(_joint(shoulder, "forearm" + suffix, Vector3(0.0, -_upper_arm, 0.0), side))
		_hands.append(_joint(_elbows[-1], "hand" + suffix, Vector3(0.0, -_forearm, 0.0), side))
		_build_fingers(_hands[-1], suffix, side)
		var hip := Vector3(side * _hip_width, _hip_drop, 0.0)
		_thighs.append(_joint(_hips, "thigh" + suffix, hip))
		_shins.append(_joint(_hips, "shin" + suffix, hip + Vector3.DOWN * _thigh))
		_feet.append(_joint(_hips, "foot" + suffix, hip + Vector3.DOWN * (_thigh + _shin)))
		_toes.append(_joint(_feet[-1], "toe" + suffix, _toe))
		if _has("knee" + suffix) and _has("seat" + suffix):
			_knees.append(_joint(_hips, "knee" + suffix, hip + Vector3.DOWN * _thigh))
			_seats.append(_joint(_hips, "seat" + suffix, hip))

	# What hangs and swings: the hem of the jumper, front first and round to
	# his left, and his hair.
	for index in 12:
		var bone := "hem_%d" % index
		if not _has(bone):
			break
		var hem := _dangle(bone, _spine, 0.115)
		hem.hem = true
		hem.outward = Vector3(hem.origin.x, 0.0, hem.origin.z).normalized()
		hem.front = hem.outward.z
		hem.side = hem.outward.x
	for bone: String in ["hair_f", "hair_l", "hair_b", "hair_r"]:
		if _has(bone):
			var lock := _dangle(bone, _head, 0.09)
			lock.stiffness = 230.0
			lock.damping = 8.0
			lock.drag = 1.6
			lock.gravity = 5.0
			lock.limit = 0.4
			# (it lies on his head, and cannot swing in through it)
			var middle := _rest(&"hair_l").lerp(_rest(&"hair_r"), 0.5) if _has(&"hair_l") and _has(&"hair_r") else Vector3.ZERO
			lock.outward = Vector3(lock.origin.x - middle.x, 0.0, lock.origin.z - middle.z).normalized()
	if _has(&"cap"):
		_cap_rest = _rest(&"cap")
		_cap = _joint(_head, &"cap", _cap_rest)
	if dusty:
		_dust = Dust.new()
		add_child(_dust)
	restyle()


## Dresses him as the menu has him (see Settings): the colours of his clothes,
## and his cap on or off. Without it, the curls it hides are shown instead.
## Any other figure on this rig is just shaded as it was made.
##
## A model may also carry choices of its own: any mesh object named
## `<figure>_<slot>__<option>` (two underscores before the option; no underscore
## in the slot) is one option for that slot, and is shown only when "parts" in
## the look names it for that slot. With nothing named, the option called `base`
## is the one shown. So a model built with `boy_face__base` and `boy_face__full`
## has a plain face unless its look says {"parts": {"face": "full"}}.
func restyle() -> void:
	var boy := model == null
	var chosen := look
	if chosen.is_empty() and boy:
		chosen = {"colours": Settings.colours, "cap": Settings.cap, "hair": Settings.hair, "parts": Settings.parts}
	if cel_shaded:
		Toon.apply(_figure, chosen.get("colours", {}))
	_capped = _cap != null and chosen.get("cap", true)
	var long_hair: bool = chosen.get("hair", "mullet") == "long"
	var parts: Dictionary = chosen.get("parts", {})
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		var called := String(part.name)
		var option := called.find("__")
		if option >= 0:
			var slot := called.substr(0, option).get_slice("_", called.substr(0, option).get_slice_count("_") - 1)
			part.visible = parts.get(slot, "base") == called.substr(option + 2)
		elif called.ends_with("_cap"):
			part.visible = _capped
		elif called.ends_with("_crown"):
			part.visible = not _capped
		elif called.ends_with("_forelock"):
			part.visible = _capped
		elif called.ends_with("_hair_long"):
			part.visible = long_hair
		elif called.ends_with("_hair"):
			part.visible = not long_hair


func _has(bone: StringName) -> bool:
	return _skeleton.find_bone(bone) >= 0


## Adds the joints of one hand's fingers and thumb, if the model has them. They
## are laid out as the rest of the arm is: as if it hung straight down.
func _build_fingers(hand: Node3D, suffix: String, side: int) -> void:
	if not _has("finger0a" + suffix):
		return
	var hanging := Basis(Vector3.BACK, side * _arm_rest).inverse()
	var index := 0 if side > 0 else 1
	for k in 8:
		if not _has("finger%da%s" % [k, suffix]):
			break
		var joints: Array[Node3D] = []
		var parent := hand
		for letter: String in ["a", "b", "c"]:
			var bone := "finger%d%s%s" % [k, letter, suffix]
			parent = _joint(parent, bone, hanging * _rest(bone), side)
			joints.append(parent)
		_fingers[index].append(joints)
		_finger_lines[index].append((hanging * _rest("finger%db%s" % [k, suffix])).normalized())
	if _has("thumbb" + suffix):
		var root := _joint(hand, "thumba" + suffix, hanging * _rest("thumba" + suffix), side)
		_thumbs[index] = [root, _joint(root, "thumbb" + suffix, hanging * _rest("thumbb" + suffix), side)]
		_thumb_lines[index] = (hanging * _rest("thumbb" + suffix)).normalized()


func _dangle(bone: StringName, parent: Node3D, length: float) -> Dangle:
	var dangle := Dangle.new()
	dangle.bone = _skeleton.find_bone(bone)
	dangle.parent = parent
	dangle.origin = _rest(bone)
	dangle.length = length
	_dangles.append(dangle)
	return dangle


## Adds a pose node for a bone. The animation moves these like ordinary nodes
## and _apply_pose copies them onto the skeleton. `arm` says which arm it is
## part of, if any (see _arm_sides).
func _joint(parent: Node3D, bone: StringName, at: Vector3, arm := 0) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	_joints.append(joint)
	_bones.append(_skeleton.find_bone(bone))
	_arm_sides.append(arm)
	return joint


func _apply_pose() -> void:
	# The arms are posed as if they hung straight down, but modelled held out
	# from the body (straight out, on the boy), so everything from the shoulder
	# down is turned from the one to the other on its way to the skeleton.
	for i in _joints.size():
		var pose := _joints[i].transform
		var arm := _arm_sides[i]
		if arm != 0:
			var rest := Basis(Vector3.BACK, signf(arm) * _arm_rest)
			if absi(arm) == 2:
				pose = Transform3D(pose.basis * rest.inverse(), pose.origin)
			else:
				pose = Transform3D(rest * pose.basis * rest.inverse(), rest * pose.origin)
		_skeleton.set_bone_pose(_bones[i], pose)


## Swings whatever hangs from him. Each piece's far end is a weight on a spring:
## it is drawn to where it would rest, pulled down, held back by the air as he
## moves, and left behind by any sudden move of his, and the bone is turned to
## point at it.
func _swing(delta: float) -> void:
	if _dangles.is_empty():
		return
	# How far each thigh is raised, forwards and backwards: a leg coming up
	# carries the hem up with it.
	var raised: Array[Vector2] = []
	for i in 2:
		var thigh := -_thighs[i].basis.y
		raised.append(Vector2(maxf(thigh.z, 0.0), maxf(-thigh.z, 0.0)))
	for dangle in _dangles:
		var parent := dangle.parent.global_transform
		var frame := parent.basis.orthonormalized()
		var root := parent * dangle.origin
		var rest_tip := root + frame * dangle.rest * dangle.length
		if not _dangles_settled:
			dangle.tip = rest_tip
			dangle.rest_tip = rest_tip
			dangle.velocity = Vector3.ZERO
		var rest_velocity := (rest_tip - dangle.rest_tip) / delta
		dangle.rest_tip = rest_tip
		var before := dangle.tip
		var pull := (rest_tip - dangle.tip) * dangle.stiffness - (dangle.velocity - rest_velocity) * dangle.damping
		dangle.velocity += (pull - dangle.velocity * dangle.drag + Vector3.DOWN * dangle.gravity) * delta
		dangle.tip += dangle.velocity * delta

		var along := (dangle.tip - root).normalized()
		var resting := (rest_tip - root).normalized()
		var off := resting.angle_to(along)
		if off > dangle.limit:
			along = resting.slerp(along, dangle.limit / off)
		if dangle.outward != Vector3.ZERO:
			# It lies over the body, and over a raised thigh.
			var out := frame * dangle.outward
			var least := -0.12 if dangle.hem else -0.03
			if dangle.hem:
				var leg := 0 if dangle.side > 0.0 else 1
				var lifted := raised[leg].x * maxf(dangle.front, 0.0) + raised[leg].y * maxf(-dangle.front, 0.0)
				if absf(dangle.side) < 0.1:
					lifted = maxf(raised[0].x, raised[1].x) * 0.8 if dangle.front > 0.0 else maxf(raised[0].y, raised[1].y) * 0.8
				least += lifted * 0.75
			var outness := along.dot(out)
			if outness < least:
				along = (along + out * (least - outness)).normalized()
		dangle.tip = root + along * dangle.length
		dangle.velocity = (dangle.tip - before) / delta
		_skeleton.set_bone_pose(dangle.bone, Transform3D(Basis(Quaternion(dangle.rest, (frame.inverse() * along).normalized())), dangle.origin))
	_dangles_settled = true


## His cap is not nailed on. It sits on his head as a weight on a spring: left
## behind for a moment by whatever his head does, it lifts off it and tips,
## and settles again. A hand on it holds it still.
func _bounce_cap(delta: float) -> void:
	if _cap == null or not _capped:
		return
	var head := _head.global_transform.orthonormalized()
	var rest := head * _cap_rest
	# What it feels is his head changing speed, not the speed itself.
	var rest_velocity := (rest - _cap_was) / delta
	var jolt := (rest_velocity - _cap_was_velocity) / delta
	_cap_was = rest
	_cap_was_velocity = rest_velocity
	if not _cap_settled or jolt.length() > 500.0:
		# (put somewhere else altogether: that is not a movement)
		jolt = Vector3.ZERO
		_cap_off = Vector3.ZERO
		_cap_velocity = Vector3.ZERO
		_cap_settled = true
	# (at a walk it hardly stirs: it takes a run, or a landing, to shift it)
	jolt *= 1.0 - 0.75 * _move * (1.0 - _run) * (1.0 - _air)
	_cap_velocity += (-_cap_off * 300.0 - _cap_velocity * 10.0 - jolt) * delta
	_cap_off += _cap_velocity * delta
	if _cap_off.length() > 0.035:
		_cap_off = _cap_off.limit_length(0.035)
		_cap_velocity *= 0.5
	var off := head.basis.inverse() * _cap_off
	var loose := (1.0 - 0.92 * _hat) * looseness
	# It can come up off his head, but hardly down into it.
	var lift := maxf(off.y, -off.y * 0.4)
	_cap.position = _cap_rest + Vector3(off.x * 0.2, lift, off.z * 0.2) * loose
	_cap.rotation = Vector3(clampf(off.z * 5.5, -0.25, 0.25) + lift * 3.0, 0.0, clampf(-off.x * 5.5, -0.25, 0.25)) * loose
	# Spinning, it lifts and tips back, all but off. Lying down to sleep, he pulls it down over his face.
	_cap.position += Vector3(-_whirl_way * 0.012, 0.022, -0.02) * _whirl * loose
	_cap.rotation += Vector3(-0.32, 0.0, _whirl_way * 0.14) * _whirl * loose
	if _cap_over > 0.0:
		_cap.position = _cap.position.lerp(_cap_rest + CAP_OVER_FACE * Vector3(_lie_side, 1.0, 1.0), _cap_over)
		_cap.rotation = _cap.rotation.lerp(CAP_OVER_TIP * Vector3(1.0, _lie_side, _lie_side), _cap_over)


## Puffs of dust: under him as he slides or skids, and where he lands. (Each
## footfall raises its own: see _track_steps.)
func _raise_dust(flat: Vector3, grounded: bool, delta: float) -> void:
	_dust_timer -= delta
	var scraping := maxf(_slide, _skid * 0.7) if grounded else 0.0
	scraping = maxf(scraping, _ball * 0.6)
	if scraping > 0.3 and flat.length() > 0.8 and _dust_timer <= 0.0:
		_dust_timer = 0.06
		# From his heel if he is sliding, from under him otherwise
		var from := Vector3(randf_range(-0.12, 0.12), 0.03, lerpf(0.0, 0.35, _slide) + randf_range(-0.1, 0.1))
		scraped.emit(global_position + global_basis * from, flat, clampf(scraping, 0.0, 1.0))
		if _dust and dust_scale > 0.0:
			_dust.puff(global_position + global_basis * from, -flat * 0.15, (0.12 * scraping + 0.05) * dust_scale, 1)


func is_limp() -> bool:
	return _ragdoll != null


## Where the body is lying (its hips), while limp.
func limp_position() -> Vector3:
	return (_limbs[0][1] as RigidBody3D).global_position if _ragdoll else global_position


## Lets go of the pose: the figure becomes jointed rigid bodies that start from
## exactly where it is, moving at `velocity`, with `impulse` landing on the chest.
## The pose nodes then follow the bodies, so the model goes on being drawn the
## same way. `recover` hands control back to the animation.
func go_limp(velocity: Vector3, impulse := Vector3.ZERO) -> void:
	if _ragdoll:
		return
	_ragdoll = Node3D.new()
	_ragdoll.top_level = true
	add_child(_ragdoll)
	_ragdoll.global_transform = Transform3D.IDENTITY

	var hips := _limb(_hips, 6.0, 0.1, 0.0)
	var spine := _limb(_spine, 9.0, 0.095, 0.32)
	var head := _limb(_head, 3.0, 0.11, 0.27)
	_socket(hips, spine, 0.45, 0.35)
	_socket(spine, head, 0.6, 0.5)
	for i in 2:
		var upper := _limb(_shoulders[i], 1.2, 0.04, -_upper_arm)
		var fore := _limb(_elbows[i], 1.0, 0.035, -_forearm - 0.07)
		var thigh := _limb(_thighs[i], 3.5, 0.06, -_thigh)
		var shin := _limb(_shins[i], 2.5, 0.05, -_shin - 0.05)
		_socket(spine, upper, 1.7, 0.6)
		_hinge(upper, fore, ELBOW_LIMITS)
		_socket(hips, thigh, 1.0, 0.25)
		_hinge(thigh, shin, KNEE_LIMITS)
	for limb in _limbs:
		(limb[1] as RigidBody3D).linear_velocity = velocity
	spine.apply_central_impulse(impulse)


func recover() -> void:
	if _ragdoll == null:
		return
	_ragdoll.queue_free()
	_ragdoll = null
	_limbs.clear()
	_on_respawned()


func _follow_ragdoll() -> void:
	for limb in _limbs:
		(limb[0] as Node3D).global_transform = (limb[1] as RigidBody3D).global_transform
	for i in 2:
		# Feet have no body of their own; they ride on the shins.
		_feet[i].global_transform = _shins[i].global_transform * Transform3D(Basis.IDENTITY, Vector3.DOWN * _shin)
		_toes[i].rotation = Vector3.ZERO
		_half_joints(i)


## A rigid body standing in for the bone `joint` drives: a capsule reaching
## `extent` along the bone (negative hangs below the joint), or a ball if zero.
func _limb(joint: Node3D, mass: float, radius: float, extent: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	body.angular_damp = 3.0
	# Its own layer: the world stops it, nothing else notices it.
	body.collision_layer = 8
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	if is_zero_approx(extent):
		var ball := SphereShape3D.new()
		ball.radius = radius
		collider.shape = ball
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(absf(extent), radius * 2.0)
		collider.shape = capsule
		collider.position.y = extent * 0.5
	body.add_child(collider)
	_ragdoll.add_child(body)
	body.global_transform = joint.global_transform.orthonormalized()
	_limbs.append([joint, body])
	return body


## Ball-and-socket between two limbs at the child's joint, limited to a cone.
func _socket(parent: RigidBody3D, child: RigidBody3D, swing: float, twist: float) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.swing_span = swing
	joint.twist_span = twist
	_attach(joint, parent, child)


## Elbows and knees: one axis, and only the way they really bend.
func _hinge(parent: RigidBody3D, child: RigidBody3D, limits: Vector2) -> void:
	var joint := HingeJoint3D.new()
	# The engine measures a hinge from the pose it is made in, and in the opposite
	# sense to a turn about the limb's X axis, so restate the limits that way.
	var relative := parent.global_basis.inverse() * child.global_basis
	var bend := clampf(atan2(relative.y.z, relative.y.y), limits.x, limits.y)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, bend - limits.y)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, bend - limits.x)
	_attach(joint, parent, child)


func _attach(joint: Joint3D, parent: RigidBody3D, child: RigidBody3D) -> void:
	_ragdoll.add_child(joint)
	# A cone twists about the joint's X and a hinge turns about its Z: point X
	# along the limb and Z along the limb's own side-to-side axis.
	var limb := child.global_basis
	joint.global_transform = Transform3D(Basis(limb.y, limb.z, limb.x), child.global_position)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)


## Turns his head (and a little of his back) towards whatever has his eye. With
## nothing to look at he gazes about if he is at ease, and darts from side to
## side if he is wary.
func _look_about(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = 0.2
		_notice()
	var target := Vector2.ZERO
	var rate := 5.0
	if _watching > 0.0 and is_instance_valid(_watch):
		# What he has just thrown: he watches it go.
		var gone := _watch.global_position - (_head.global_position + Vector3.UP * 0.1)
		target.x = clampf(angle_difference(rotation.y, atan2(gone.x, gone.z)), -1.3, 1.3)
		target.y = clampf(-atan2(gone.y, Vector2(gone.x, gone.z).length()), -0.6, 0.5)
		rate = 12.0
	elif _hang > 0.5 and absf(_shimmy) > 0.15:
		# Working along a ledge, he looks where he is going.
		target.x = signf(_shimmy) * 0.85
		target.y = -0.15
		rate = 7.0
	elif _rope > 0.5 and _rope_swing.length() > 0.8:
		# Swinging, the way it is taking him.
		target.x = clampf(_rope_swing.y * 0.3, -0.9, 0.9)
		target.y = -0.12 * signf(_rope_swing.x)
		rate = 5.0
	elif is_instance_valid(_interest):
		var eyes := _head.global_position + Vector3.UP * 0.1
		var to := _interest.global_position + Vector3.UP * (0.5 if _interest_is_threat else 0.2) - eyes
		target.x = clampf(angle_difference(rotation.y, atan2(to.x, to.z)), -1.5, 1.5)
		target.y = clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.7)
		rate = 9.0
		# Running from something he only glances back, a second or so at a time.
		if _interest_is_threat and _move > 0.3 and sin(_time * 1.9) < 0.2:
			target = Vector2.ZERO
	else:
		target.x = (sin(_time * 0.37) * 0.3 + sin(_time * 0.83 + 1.0) * 0.12) * _casual
		target.y = sin(_time * 0.29 + 2.0) * 0.07 * _casual
		target.x += signf(sin(_time * 1.1)) * (0.45 + 0.2 * sin(_time * 2.3)) * _wary
		rate = lerpf(5.0, 10.0, _alert)
	# (asleep he looks at nothing; spinning, nothing stays put to be looked at)
	target *= (1.0 - smoothstep(0.15, 0.6, _lie_at)) * (1.0 - _whirl)
	_look = _look.lerp(target, 1.0 - exp(-rate * delta))
	# His eyes make up what his head has not yet turned, as far as eyes can.
	var ahead := target - _look
	# (and at his ease they are never quite still)
	ahead += Vector2(sin(_time * 0.61 + 1.3) + 0.5 * sin(_time * 1.37), 0.4 * sin(_time * 0.47)) * 0.07 * _casual
	_eye_turn = _eye_turn.lerp(Vector2(clampf(ahead.x, -0.5, 0.5), clampf(ahead.y, -0.3, 0.3)), 1.0 - exp(-24.0 * delta))
	for eye in _eye_joints:
		eye.rotation = Vector3(_eye_turn.y, _eye_turn.x, 0.0)


## Picks what to look at. Anything after him comes first, and he keeps watching
## it. Otherwise it is the nearest thing in the group `interest` that is close
## and not behind him, for a few seconds, after which he has seen enough of it
## for a while.
func _notice() -> void:
	var here := global_position
	var found: Node3D = null
	var threat := false
	var nearest := 15.0
	for pursuer: Node3D in get_tree().get_nodes_in_group(&"pursuers"):
		if pursuer == _player or not pursuer.get(&"chasing"):
			continue
		var distance := pursuer.global_position.distance_to(here)
		if distance < nearest:
			nearest = distance
			found = pursuer
			threat = true
	# (only the boy is curious)
	if found == null and _chest and &"carried" in _player:
		nearest = 5.0
		for thing: Node3D in get_tree().get_nodes_in_group(&"interest"):
			if thing == _player.carried or _bored.get(thing.get_instance_id(), 0.0) > _time:
				continue
			var to := thing.global_position - here
			var distance := to.length()
			if distance >= nearest or absf(angle_difference(rotation.y, atan2(to.x, to.z))) > 1.9:
				continue
			nearest = distance
			found = thing
	if found != _interest:
		_interest = found
		_interest_time = 0.0
	_interest_is_threat = threat
	if found and not threat:
		_interest_time += 0.2
		if _interest_time > (1.2 if _move > 0.5 else 3.2):
			_bored[found.get_instance_id()] = _time + 7.0
			_interest = null


## A gun. Works out where its grip is and which way it points (carried low, or
## across him; brought up to aim; kicking), puts the hand that holds it there
## and turns it to suit, and puts the other hand under a long one. The gun
## itself is then put in that hand (see gun_transform).
##
## A pistol is carried low at his side, muzzle to the ground ahead of him, and
## aimed at the end of a straight arm. A rifle is carried across his body,
## muzzle up by his other shoulder, and aimed from the shoulder. On the move
## neither is held so strictly: it goes with his steps, and comes up less far.
func _hold_gun() -> void:
	if _gun < 0.01:
		return
	var frame := global_basis.orthonormalized()
	var aim: Vector3 = (frame.inverse() * (_player.gun_aim as Vector3)).normalized() if &"gun_aim" in _player else Vector3.BACK
	if aim.z < 0.35:
		aim = Vector3(aim.x, aim.y, 0.35).normalized()
	var long := _gun_long
	var step := sin(TAU * _phase)
	var going := _move * (1.0 - _air)
	var shoulder := to_local(_shoulders[1].global_position)
	# Carried.
	var low_grip := Vector3(-0.2, 0.5 + 0.1 * _run, 0.09 + 0.07 * _run).lerp(Vector3(-0.13, 0.74, 0.15), long)
	low_grip += Vector3(0.0, absf(step) * 0.014 * going, -step * lerpf(0.05, 0.02, long) * going)
	var low_dir := Vector3(0.05, -0.76 + 0.2 * _run, 0.65).lerp(Vector3(0.6, 0.66 + sin(_time * 0.8) * 0.02, 0.4), long).normalized()
	# In the air it is held up out of the way.
	low_grip.y += 0.1 * _air
	# Aimed: at the end of his arm, or with the butt in his shoulder.
	var aim_grip := shoulder + aim * lerpf(0.49, 0.2, long) + Vector3(lerpf(0.03, 0.05, long), lerpf(0.035, -0.045, long), 0.0)
	# (on the move it does not come all the way up, and it wanders)
	aim_grip += Vector3(0.0, -0.09, -0.07) * _run + Vector3(sin(TAU * _phase * 2.0) * 0.012, step * 0.025, 0.0) * going
	var wander := Vector3(step * 0.05, sin(TAU * _phase * 2.0) * 0.04, 0.0) * going + Vector3(sin(_time * 1.7), cos(_time * 1.3), 0.0) * 0.008
	var dir := low_dir.slerp((aim + wander).normalized(), _aiming)
	var grip := low_grip.lerp(aim_grip, _aiming)
	# The kick: the muzzle flies up, and it comes back into his hand or his shoulder.
	if absf(dir.y) < 0.97:
		dir = dir.rotated(dir.cross(Vector3.UP).normalized(), _recoil * lerpf(0.8, 0.3, long))
	grip += -aim * _recoil * lerpf(0.1, 0.075, long) + Vector3.UP * _recoil * lerpf(0.06, 0.02, long)
	_gun_dir = dir
	_gun_grip = grip

	# Its own axes, in the world: the barrel along -Z, the top up (as near as may be).
	var forward := (frame * dir).normalized()
	var gz := -forward
	var gx := (frame * Vector3(0.12 * long * (1.0 - _aiming), 1.0, 0.0)).cross(gz).normalized()
	var gy := gz.cross(gx)
	var at := to_global(grip)
	# The hand that holds it: its fingers go forward along the barrel and close
	# round the grip, its palm to his left.
	var hand := Basis(-gx, gz, gy)
	var wrist := at - hand * GUN_IN_HAND * global_basis.get_scale().y
	var pole := (frame * Vector3(-0.5, -1.0, -0.3).lerp(Vector3(-1.0, -0.25, -0.35), long * _aiming)).normalized()
	_solve_arm(1, -1.0, wrist, _forearm, _gun, pole)
	var fore := _elbows[1].global_basis.orthonormalized()
	_hands[1].basis = _hands[1].basis.orthonormalized().slerp((fore.inverse() * hand).orthonormalized(), _gun)
	# The gun goes where that hand has actually got to.
	var held := _hands[1].global_transform.orthonormalized()
	_gun_now = Transform3D(Basis(-held.basis.x, held.basis.z, held.basis.y), held * GUN_IN_HAND)
	# The other hand: under the fore-end of a long one, fingers up round the far side of it.
	var both := _gun * long
	if both > 0.01:
		var support := _gun_now * _gun_support
		var across := (gx * 0.8 + forward * 0.6).normalized()
		_solve_arm(0, 1.0, support - gy * 0.03 - across * PALM, _forearm, both, (frame * Vector3(0.45, -1.0, 0.1)).normalized())
		_lay_hand(0, 1.0, -gy, across, both)


## Where a gun in his hand is, in the world: its origin at its grip, its barrel
## along its -Z and its top its +Y.
func gun_transform() -> Transform3D:
	return _gun_now


## Which way a bat in his hands lies: its length is its Y.
func bat_basis() -> Basis:
	var y := (global_basis * _bat_dir).normalized()
	var x := y.cross(global_basis.z).normalized() if absf(y.dot(global_basis.z.normalized())) < 0.95 else global_basis.x.normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


## Where the right hand is, for whatever it is holding.
func hand_position() -> Vector3:
	var held := _hands[1].global_transform * Vector3(0.0, -0.07, 0.0)
	# (tossed up, it is out of his hand for a moment)
	if _juggle < 0.34:
		var flight := _juggle / 0.34
		held += Vector3.UP * (4.0 * flight * (1.0 - flight) * 0.34)
	return held


## Takes the figure's proportions from its skeleton's rest pose.
func _measure() -> void:
	_hip_height = _rest(&"hips").y
	var thigh := _rest(&"thigh_l")
	var shin := _rest(&"shin_l")
	_hip_width = absf(thigh.x)
	_hip_drop = thigh.y
	_thigh = thigh.distance_to(shin)
	_shin = shin.distance_to(_rest(&"foot_l"))
	_toe = _rest(&"toe_l")
	var elbow := _rest(&"forearm_l")
	_upper_arm = elbow.length()
	_forearm = _rest(&"hand_l").length()
	_arm_rest = atan2(elbow.x, -elbow.y)
	_leg_scale = (_thigh + _shin) / 0.54


## Where a bone rests, relative to its parent bone.
func _rest(bone: StringName) -> Vector3:
	return _skeleton.get_bone_rest(_skeleton.find_bone(bone)).origin


## Puts the hands where the body says they belong (a ledge, a rope, a wall)
## by solving each arm as two bones, over whatever the arms were doing. If the
## body also says which way the surface faces, he is pressing on it: the palms
## are laid flat against it, fingers up, or along whatever line it gives.
func _reach_arms() -> void:
	var delta := get_process_delta_time()
	var left := global_basis.x.normalized()
	var palm_length := PALM * global_basis.get_scale().y
	if _reach < 0.01:
		_reach_held = false
		_press_normal = Vector3.ZERO
	else:
		var points: PackedVector3Array = _player.hand_points
		var normal: Vector3 = _player.hand_normal if &"hand_normal" in _player else Vector3.ZERO
		var lie: Vector3 = _player.hand_fingers if &"hand_fingers" in _player else Vector3.ZERO
		var pressing := normal != Vector3.ZERO
		var ease_in := 1.0 - exp(-18.0 * delta) if _reach_held else 1.0
		if pressing:
			# (eased, so that turning a hand from the face of a ledge onto the top of it is a movement)
			var turn_in := 1.0 - exp(-11.0 * delta) if _reach_held and _press_normal != Vector3.ZERO else 1.0
			_press_normal = _press_normal.lerp(normal, turn_in).normalized()
			_press_fingers = _press_fingers.lerp(lie, turn_in)
		_reach_held = true
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			# The right hand keeps hold of anything it is carrying.
			var weight := _reach * (1.0 - _carry * (1.0 - _coil) if i == 1 else 1.0) * (1.0 - _reach_let[i])
			# (eased towards, so a target that hops does not jerk the arm: in the
			# world, where what he has hold of stays put while he moves past it,
			# or in his own space on a rope, which goes where he goes)
			var eased_from := to_local(_hand_world[i]) if _rope < 0.5 and ease_in < 1.0 else _hand_targets[i]
			# (once he has let go, the hand comes away from where it was on him: what
			# it had hold of is no longer anything to reach back for)
			if not (&"hand_reach" in _player) or _player.hand_reach > 0.0:
				_hand_targets[i] = eased_from.lerp(to_local(points[i]), ease_in)
			_hand_world[i] = to_global(_hand_targets[i])
			var point := to_global(_hand_targets[i])
			# Gripping, the arm reaches as far as the middle of the hand. Pressing,
			# it is the wrist that is placed: below the point, by the heel of the hand.
			var fore_length := _forearm + 0.06
			var fingers := Vector3.UP
			if pressing:
				var along := _press_fingers if lie != Vector3.ZERO else Vector3.UP + left * side * 0.28
				fingers = along.slide(_press_normal).normalized()
				point -= fingers * palm_length
				fore_length = _forearm
			# (On a rope his elbows are kept out to the sides: his arms go up over his head and down in
			# front of him there, and elbows that hung down would swing right round as they went by upright.)
			var out := (Vector3.DOWN + left * side * 0.6 - global_basis.z.normalized() * 0.3).lerp(left * side - global_basis.y.normalized() * 0.45 - global_basis.z.normalized() * 0.2, _rope)
			_solve_arm(i, side, point, fore_length, weight, out if _rope > 0.001 else Vector3.ZERO)
			if pressing:
				# The palm faces into the surface (it is the side of the hand towards his body).
				var across := _press_normal * side
				var palm := Basis(across, -fingers, across.cross(-fingers))
				var fore := _elbows[i].global_basis.orthonormalized()
				_hands[i].basis = Basis.IDENTITY.slerp((fore.inverse() * palm).orthonormalized(), weight * _flat)
	# And where the rig itself wants a hand: knuckles down on the ground, or flat on it.
	for i in 2:
		if _plant[i] > 0.01:
			var side := 1.0 if i == 0 else -1.0
			var flat := _plant_flat[i]
			var fingers := (global_basis * _plant_fingers[i]).normalized()
			# (flat, it is the wrist that is placed, behind the palm)
			var pole := (global_basis * _plant_pole[i]).normalized() if _plant_pole[i] != Vector3.ZERO else Vector3.ZERO
			_solve_arm(i, side, to_global(_plant_at[i]) - fingers * palm_length * flat, _forearm + 0.05 * (1.0 - flat), _plant[i], pole)
			if flat > 0.01:
				_lay_hand(i, side, Vector3.UP, fingers, _plant[i] * flat)
	# Flat out, or sliding, a hand is clapped to the side of his cap to keep it
	# on: whichever is towards the camera.
	if _hat > 0.01:
		var side := 1.0 if _hat_arm == 0 else -1.0
		var head := _head.global_transform.orthonormalized()
		var onto := (head.basis * Vector3(0.35 * side, 0.94, 0.0)).normalized()
		var over := (head.basis * Vector3(-side, 0.0, -0.3)).slide(onto).normalized()
		var pole := left * side + global_basis.z.normalized() * 0.7 + Vector3.DOWN * 0.3
		_solve_arm(_hat_arm, side, _head.global_transform * Vector3(HAT_HOLD.x * side, HAT_HOLD.y, HAT_HOLD.z) - over * palm_length, _forearm, _hat, pole)
		_lay_hand(_hat_arm, side, onto, over, _hat)


## Turns a hand to lie flat on a surface facing `normal`, its fingers along `fingers`, as far as `weight`.
func _lay_hand(i: int, side: float, normal: Vector3, fingers: Vector3, weight: float) -> void:
	# The palm faces into the surface (it is the side of the hand towards his body).
	var across := normal * side
	var palm := Basis(across, -fingers, across.cross(-fingers))
	var fore := _elbows[i].global_basis.orthonormalized()
	_hands[i].basis = _hands[i].basis.orthonormalized().slerp((fore.inverse() * palm).orthonormalized(), weight)


## Turns one arm, as far as `weight`, to put its hand at `point`: the wrist if
## `fore_length` is the forearm's own, or something further down the hand if it is longer.
func _solve_arm(i: int, side: float, point: Vector3, fore_length: float, weight: float, pole := Vector3.ZERO) -> void:
	var forward := global_basis.z.normalized()
	var left := global_basis.x.normalized()
	var shoulder := _shoulders[i]
	var from := shoulder.global_position
	var to := point - from
	# (points are in the world, and a figure may be drawn larger than it was made)
	var size := global_basis.get_scale().y
	var upper_length := _upper_arm * size
	fore_length *= size
	var reach := clampf(to.length(), 0.1 * size, upper_length + fore_length - 0.005 * size)
	var direction := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	# Elbows hang down and a little out, unless told which way to point.
	if pole == Vector3.ZERO:
		pole = Vector3.DOWN + left * side * 0.6 - forward * 0.3
	var bend_axis := direction.cross(pole)
	bend_axis = bend_axis.normalized() if bend_axis.length_squared() > 0.0001 else left
	var angle := acos(clampf((upper_length * upper_length + reach * reach - fore_length * fore_length) / (2.0 * upper_length * reach), -1.0, 1.0))
	var upper_direction := direction.rotated(bend_axis, angle)
	var elbow_at := from + upper_direction * upper_length
	var fore_direction := (from + direction * reach - elbow_at).normalized()

	var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
	# (Which way up an arm lies is taken from the way he faces, and so turns
	# right over as the arm goes past pointing straight ahead: which the front
	# arm does in a swing of the bat. With a bat it is taken from a line tipped
	# well away from that: up while he swings, since the swing goes round him
	# level, and out to the side while he only holds it, or stoops to take it.)
	# (And on a rope from a line tipped out to the side: his arms go from over his head to
	# straight out ahead of him and back with every swing.)
	var ahead := (forward + Vector3.UP * 0.8 * _swinging * _bat + left * side * 0.8 * (1.0 - _swinging) * _bat + left * side * 1.2 * _rope).normalized()
	shoulder.basis = shoulder.basis.orthonormalized().slerp(parent.inverse() * _aim(upper_direction, ahead), weight)
	var elbow := _elbows[i]
	var upper := shoulder.global_basis.orthonormalized()
	elbow.basis = elbow.basis.orthonormalized().slerp(upper.inverse() * _aim(fore_direction, ahead), weight)


## Basis whose -Y axis points along `direction`, with +Z as near `ahead` as it can be.
static func _aim(direction: Vector3, ahead: Vector3) -> Basis:
	var y := -direction
	var x := y.cross(ahead)
	x = x.normalized() if x.length_squared() > 0.0001 else y.cross(Vector3.UP).normalized()
	return Basis(x, y, x.cross(y))
