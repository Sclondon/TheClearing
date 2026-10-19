# Wyvern (Godot 4.7)

A two-legged dragon for a game in Inside's overcast dread: about 9 m across the wings and near 5 m from snout to
barb. Its wings are its arms, as a bat's are: a stout upper arm, a long forearm, a short hand, and from the knuckle a
very long finger in four joints along the leading edge out to the wingtip (as a pterosaur's), and two more running
back through the membrane to the trailing edge, scalloped between them (as a bat's); the thumb is free at the wrist,
short and thick, with a great hooked claw. Strong hind legs with raptor feet (three toes forward, one back, hooked
claws), a deep heavy chest, a long neck, a horned reptile's head (two great horns swept back, spikes at the cheeks,
heavy brows, teeth along the jaws), spines down the neck, back and tail, and a long tail ending in a flat barbed
arrowhead. Dark weathered scales, paler plates under the belly and throat; the membrane dark, old, torn ragged at
its edge. Made 2026-10-18 for Warren (where pairs of them nest on high wall tops and hunt anyone in the open:
`scripts/enemies/maze_wyvern.gd` there). It is only the look, the motion, the sound and its nest: it does no thinking.

- `creatures/wyvern/wyvern.gd` (`class_name Wyvern`, a `Node3D`): the motion, posed bone by bone in code (no
  animations), and its sounds, made in code.
- `creatures/wyvern/wyvern_look.gd` (`class_name WyvernLook`): its shader, its nest's, and its shadow's.
- `creatures/wyvern/wyvern_nest.gd` (`class_name WyvernNest`, a `MeshInstance3D`): a nest of sticks, branches and
  bones (ribs, long bones, skulls, an antler) about 5 m across, made in code, one mesh shared by every nest.
- `creatures/wyvern/models/wyvern.glb`: two skinned meshes on one skeleton (38 bones), `wyvern` (about 18,000
  triangles) and `wyvern_lo` (about 7,000), built in Blender 4.3 by `tools/build_wyvern.py` (in Warren's copy, and
  beside this README in GameCommon). It began from the pterodactyl's builder (creatures/pterodactyl) and shares its
  ways of moving; it is built at 1/1.35 of its size and `Wyvern` draws it at `MODEL_SCALE`.

```
blender --background --python creatures/wyvern/tools/build_wyvern.py [-- <folder for preview renders>]
```

## Using it

```gdscript
var wyvern := Wyvern.new()
add_child(wyvern)
# Its origin is its middle. On the ground, put it stand_height() above the ground; it sets hands and feet on it.
wyvern.global_position = ground + Vector3.UP * wyvern.stand_height()
wyvern.grounded = true                      # false: flying. Move it on the ground and it walks on its wrists and feet.
wyvern.launch()                             # the take-off; move it by Wyvern.launch_lift(t)
# each frame, whatever drives it moves it (it faces +Z) and says what it is doing:
wyvern.effort = 0.0                         # 0 soaring on still wings .. 1 beating hard
wyvern.brake = 0.0                          # wings flared forward, body up: landing
wyvern.tuck = 0.0                           # wings drawn in: a dive
wyvern.talons = 0.0                         # legs swung down and forward, toes open: the snatch
wyvern.grip = 0.0                           # toes closed (on what it holds)
wyvern.aim = player.global_position         # what it looks at (INF: ahead)
wyvern.shriek()                             # its scream, jaws wide; `shrieked` at the top
wyvern.strike()                             # on the ground: the tail lash (coil, then whip); `lashed` when the barb lands
wyvern.rush()                               # the roar of the wind as it dives
wyvern.show_shadow(ground_point)            # its shadow on the ground under it (INF: none)
if ... wyvern.foot_points() ...             # where its toes are (world), for catching; carry_point() between them
if ... wyvern.barb_point() ...              # where the barb's point is (world), for the lash
var nest := WyvernNest.new()                # its nest: put it on the stone
```

- **Flight**: big slow beats of the arm-wings, about 0.7 to 1.1 a second. Downstroke: the wing spread and swept a
  little forward, the finger bending up at the tip under the load. Upstroke: elbow, wrist and knuckle flexed, the wing
  short and slack, the tip trailing, then flicked out at the top. It pitches with its climb, banks into turns, the
  tail ripples with the beat and swings into turns, the legs trail under the tail.
- **On the ground**: as a bat or pterosaur walks: the wings folded up along the arms (the long fingers raised behind
  the shoulders, bending back down at their tips), walking on its wrists with the thumbs' claws dug in, and on its
  hind feet (the metatarsus raised, the toes flat), the body pitched up, the neck in an S, the tail held out behind,
  swaying. Each hand and foot steps when it is left behind (two at most at once, never two on one side). IK for each limb.
- **The lash** (`strike()`, STRIKE_TIME): the wind-up first, slow and plain (COIL_TIME): the tail drawn up and over
  its back in a coil, the barb high and quivering, the wings half raised, the head drawn back and the jaws parted, a
  hiss and the rattle of the barb; then the tail whipped over and down in front of it, the body lunging after it, the
  barb landing at STRIKE_LAND (about 1.3 m ahead of it, waist high); then it recovers.
- **Signals**: `beat`, `shrieked`, `lashed`. Plays its own sounds (`sound`, `volume_db`, `sound_range`).
- **For pictures and tests**: `frozen = true`, then `hold(state, phase, call_t, launch_t, strike_t)` poses it exactly.
- **Exports**: `sound`, `volume_db`, `sound_range`, `lod_distance` (beyond it the low mesh), `seed_value`. Static
  `Wyvern.low_poly` makes every wyvern use the low mesh (phones).

## Sound

Made in code, nothing to load: `shriek_sound()` (1.5 s: a growl in the chest rising into a harsh tearing scream,
breaking and falling away into a rasping hiss), `beat_sound()` (a deep leathery whump, the membrane snapping taut),
`rush_sound()` (1.8 s of wind roaring louder and higher), `hiss_sound()` (the wind-up: a hiss through the teeth and
the dry rattle of the barb), `lash_sound()` (the tail whistling through the air and the barb's crack).

## Cost

One draw (and its shadow) for whichever mesh is shown, one more for the ground shadow while it is shown, one for a
nest; 38 bones posed every frame. Hide it or set `process_mode` disabled when it is far from everyone.

## What it needs

Nothing else: no autoloads, input actions or other components. The files must sit at `res://creatures/wyvern/`.
`example.gd` is a whole scene: a block with its nest and a post for a target, and the wyvern going through everything,
round and round.
