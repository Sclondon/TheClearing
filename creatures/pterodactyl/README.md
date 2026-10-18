# Pterodactyl (Godot 4.7)

A great pterosaur, Pteranodon-like, for a game in Inside's overcast dread: about 6.8 m across the wings and as tall as a
man on the ground, built as the fossils say. A short deep body furred with pycnofibres, a long neck, and a head longer
than the body: a straight toothless beak, flattened from side to side, and a blade of a crest swept back over the neck.
The wing is a hand: a short stout upper arm, the forearm, a long metacarpal and the hugely long fourth finger in four
phalanges out to the wingtip; three small clawed fingers where the wing finger begins, and the pteroid at the wrist
holding up the skin in front of the arm. The main membrane runs from the wingtip to the ankle. Made 2026-10-18 for
Warren (where pterodactyls soar over the maze and snatch anyone in the open: `scripts/enemies/maze_pterodactyl.gd`
there). It is only the look, the motion and the sound: it does no thinking.

- `creatures/pterodactyl/pterodactyl.gd` (`class_name Pterodactyl`, a `Node3D`): the motion, posed bone by bone in
  code (no animations), and its sounds, made in code.
- `creatures/pterodactyl/pterodactyl_look.gd` (`class_name PterodactylLook`): its shader, and its shadow's.
- `creatures/pterodactyl/models/pterodactyl.glb`: two skinned meshes on one skeleton (34 bones), `pterodactyl`
  (about 15,000 triangles) and `pterodactyl_lo` (about 5,000), built in Blender 4.3 by `tools/build_pterodactyl.py`
  (in Warren's copy, and beside this README in GameCommon):

```
blender --background --python creatures/pterodactyl/tools/build_pterodactyl.py [-- <folder for preview renders>]
```

## The model

- **Body and head**: signed distance fields (ellipsoids, capsules and squashed capsules joined smoothly: the keel of
  the breastbone and the flight muscles, the deltopectoral crest, the beak and crest as flattened blades),
  polygonised, decimated and put back on the surface; normals from the field, its hollows baked into the vertex
  colour's alpha. The lower jaw is its own field, on its own bone.
- **Wings**: the forearm, metacarpal and the four phalanges of the wing finger, the pteroid, the little fingers and
  their claws are lofted tubes. The brachiopatagium is a Coons patch between the arm and finger, the free trailing
  edge (wingtip to ankle) and the line of the body and leg, cambered; each vertex carried by the leading edge's bones
  and, near the root and down the trailing edge, by the body and leg. The propatagium runs from the neck to the
  pteroid's tip and the wrist.
- **Legs**: thigh (the body's), shin, foot and four clawed toes; sprawled out to the sides in flight.

## Using it

```gdscript
var ptero := Pterodactyl.new()
add_child(ptero)
# Its origin is its middle. On the ground, put it stand_height() above the ground; it sets hands and feet on it.
ptero.global_position = ground + Vector3.UP * ptero.stand_height()
ptero.grounded = true                       # false: flying. Move it on the ground and it walks on all fours.
ptero.launch()                              # the quadrupedal vault; move it by Pterodactyl.launch_lift(t)
# each frame, whatever drives it moves it (it faces +Z) and says what it is doing:
ptero.effort = 0.0                          # 0 soaring on still wings .. 1 beating hard
ptero.brake = 0.0                           # wings flared forward, body up: landing
ptero.tuck = 0.0                            # wings folded back: a dive
ptero.talons = 0.0                          # legs swung down and forward, toes open: the snatch
ptero.grip = 0.0                            # toes closed (on what it holds)
ptero.aim = player.global_position          # what it looks at (INF: ahead)
ptero.croak()                               # its harsh call, beak gaping; `croaked` at the top
ptero.rush()                                # the roar of the wind as it dives
ptero.show_shadow(ground_point)             # its shadow on the ground under it (INF: none)
if ... ptero.foot_points() ...              # where its toes are (world), for catching; carry_point() between them
```

- **Flight**, after what the wing bones allow and the flight of big soaring birds and bats. Downstroke: the wing
  fully spread and swept a little forward, the leading edge pressed down, the outer finger bending up at the tip
  under the load. Upstroke: elbow and wrist flex and the wing finger sweeps back at its knuckle, so the wing comes up
  short and slack, the tip trailing, then flicks out straight at the top. About a beat a second. It pitches with its
  climb, banks into turns, and the body bobs against the beat.
- **On the ground**: on all fours, the body pitched up, standing on the three little fingers (pointing out and back,
  as the trackways show), the metacarpals upright, the wing fingers folded up and back along the arms and the
  membrane furled between them and the legs; feet flat. Each hand and foot steps when it is left behind (two at most
  at once, never two on one side), so it walks and turns on the spot. IK for each limb.
- **Launch**: it crouches, kicks with the hind legs and vaults on its arms (they stay planted and straighten as it
  rises), the wing fingers snapping open at the top into a deep first downstroke.
- **Signals**: `beat` (each wingbeat), `croaked`. Plays its own sounds (`sound`, `volume_db`, `sound_range`).
- **For pictures and tests**: `frozen = true`, then `hold(state, phase, call_t, launch_t)` poses it exactly.
- **Exports**: `sound`, `volume_db`, `sound_range`, `lod_distance` (beyond it the low mesh), `seed_value`. Static
  `Pterodactyl.low_poly` makes every pterodactyl use the low mesh (phones).

## Sound

Made in code, nothing to load: `call_sound()` (1.3 s: a clatter of the beak, then a harsh guttural "kraaah" through a
long throat, the pulses doubled into a growl, falling, a wheeze after), `beat_sound()` (a deep soft whump and the
membrane snapping taut), `rush_sound()` (1.8 s of wind roaring louder and higher).

## Cost

One draw (and its shadow) for whichever mesh is shown, one more for the ground shadow while it is shown; 34 bones
posed every frame. Hide it or set `process_mode` disabled when it is far from everyone.

## What it needs

Nothing else: no autoloads, input actions or other components. The files must sit at `res://creatures/pterodactyl/`.
`example.gd` is a whole scene: a block to roost on and the pterodactyl going through everything, round and round.
