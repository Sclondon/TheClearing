# Lizard person (Godot 4.7)

A reptile the size of a man: lean and long in the limb, upright but stooped, with a long tail. Fine scales all over,
mottled grey-olive, darker over the back in broken bands, the belly pale and plated in rows; a row of keeled scutes
down the spine and bigger plates over the shoulders. A lizard's head: a flat skull and a long low snout, heavy scales
over the eyes, heat pits along the upper lip, nostrils, an ear hole; yellow eyes with slit pupils that blink sideways
(a pale membrane drawn over them from the front corner); small teeth; a forked tongue that flicks out to taste the air;
a fan of a dewlap folded under the throat. Five long splayed fingers and toes on each hand and foot, each with a pad at
its tip and a claw. About 1.85 m standing.

Its trick: it walks on walls exactly as on the floor, low and splayed like a gecko, knees and elbows high and out, its
spine and tail swinging from side to side; head down on a face, waiting, is how it rests. Made 2026-10-18 for Warren
(its lizard people: `scripts/enemies/maze_lizard_person.gd` there). It is only the look, the motion and the sound: it
does no thinking.

- `creatures/lizard_person/lizard_person.gd` (`class_name LizardPerson`, a `Node3D`): the motion, all posed in code
  (no animations), and its hiss (made in code).
- `creatures/lizard_person/lizard_person_look.gd` (`LizardPersonLook`): its shader (scales, mottling, belly plates,
  cold darkening; two-tone light with a rim).
- `creatures/lizard_person/models/lizard_person.glb` (about 26,000 vertices) and `lizard_person_lo.glb` (8,700) for
  phones (`low_poly`, or `LizardPerson.low_poly_all` for every one). One skinned mesh, one material: one draw, and its
  shadow.
- `creatures/lizard_person/tools/rest_joints.gd` writes `tools/rest.json` (where every joint stands as modelled) from
  `LizardPerson`; `tools/build_lizard_person.py` builds the models round it in Blender 4.3 (about 10 seconds). Change
  the skeleton in `lizard_person.gd`, then run both:

```
godot --headless --audio-driver Dummy --path . -s res://creatures/lizard_person/tools/rest_joints.gd
blender --background --python creatures/lizard_person/tools/build_lizard_person.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var lizard := LizardPerson.new()
add_child(lizard)
lizard.global_position = point_on_floor
lizard.heading = Vector3.BACK            # the way it faces along what it is on
lizard.settle()

# Every frame, whatever drives it just moves it and says what it is on:
lizard.global_position = where           # the point on the surface under its middle
lizard.surface = Vector3.UP              # or a wall's normal (it rolls over to it by itself)
lizard.heading = which_way               # on a wall, Vector3.DOWN is head down
lizard.airborne = true                   # leaping: spread flat, pitched with its fall
lizard.aim = player.global_position + Vector3.UP   # what it looks at (INF: about it, in quick jerks)
lizard.warmth = 0.2                      # cold: slow to blink and taste, lies flat, skin darker
```

It works out its own speed from how it is moved and steps its feet to it. On the ground, slow or still, it stands up on
two legs, stooped, arms hanging (unless `crouch`); quicker it drops to all fours and trots, then scuttles flat out. On a
wall it is always on all fours.

| Call | What it does |
| --- | --- |
| `hiss(seconds)` | The warning: still, it rears off what it is on, arms spread, claws open, gaping, dewlap fanned, tail lashing; running, it only gapes and fans its dewlap as it comes. Hisses. `hissing()`, signal `hissed` |
| `lunge()` | GATHER, REACH (hands and jaws thrown out low ahead), RECOVER. The driver moves it. `lunge_stage()`, `lunge_progress()` |
| `reaches(point, radius)` | Whether its fingertips or jaws are within `radius` of `point`, while it reaches or is airborne |
| `grabbers()`, `head_point()` | Where its hands and jaws are, and its head (world) |
| `settle()` | Puts it still as it is told it is |

`tasting` (0..1) is how often its tongue flicks. Exports: `size`, `seed_value`, `low_poly`, `sound`, `volume_db`,
`sound_range`. Hide it and set `process_mode` disabled when it is far from the camera: it poses itself every frame.

## The model

Modelled in its own space (metres, Y up, facing +Z, +X its left), lying on all fours with its limbs half way between
how it crawls (out to the sides) and how it stands (down along the body), so that neither pose bends the mesh too far;
its tongue out, its membranes drawn and its dewlap fanned (the bones shrink those away in play). The body is a
Skin-modifier figure of the skeleton (with all the fingers and toes) and muscles and scutes as ellipsoids, joined by a
voxel remesh, smoothed and decimated; the head and the jaw are lofts cut along the gape (sockets, nostrils, heat pits
and ears cut out). Colours are vertex colours; UV and UV2.x are where each point lies as modelled (so the scales stay
put on it), UV2.y what it is (skin, eye, claw or tooth, mouth, membrane, big scales) plus 0.8 times how far under the
belly. The skeleton is `LizardPerson.BONES` (28), none the child of another, each set straight from where
`LizardPerson` works out its joints (two-bone bends for the limbs, the spine swinging, the tail laid on the surface).

## Putting it in a game

```
sh kit.sh install godot/lizard-person /c/Projects/YourGame
```

`example.gd` runs one through everything, over and over (stands, walks, scuttles to a wall, runs up it, turns head
down, hisses, leaps down at a post, lunges, walks back): put it on a Node3D in an empty scene and run it.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at
`res://creatures/lizard_person/`.
