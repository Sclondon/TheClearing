# Angel (Ophan)

A "biblically accurate" angel, after Ezekiel 1 and 10 and Isaiah 6: the ophan, wheels within wheels whose rims are
"full of eyes round about", with a seraph's burning heart and six wings at the middle of it. Made 2026-10-18 for The
Clearing (where it drifts over the halls and takes whoever stays in its gaze: `scripts/enemies/maze_angel.gd` there).
Godot 4.7, works in GL Compatibility (phones, web).

It is the look and the motion only. It does not think, move about, collide or catch: your game moves the node (its
origin is the heart), says what it looks at and how far its gaze has built, and it looks right doing it.

## What it looks like

- **The wheels**: three rims of pale gold (7.2 m across the outer one at scale 1), one within another, each turning
  slowly on its own axis while the three tumble about each other. A high band with beaded lips, grooves along both
  faces, ribs inside, studs between the eyes. Gold is faked in the shader (a pale sky above, dim below, the core seen
  in it), as the game's world is grey mist.
- **The eyes**: sixteen round each rim, each in a raised bezel. Real eyes: a wet white with veins towards the back,
  an iris of fibres (six colours, mixed), a paler ring round the pupil, a dark limbal ring, the clear bulge of the
  cornea with the burning core glinting in it; lids of skin with a wet pink margin, a crease, and lashes. They blink
  out of step (now and then twice), some droop half shut, and each looks about on its own in quick darts, until
  there is something to look at: then they all turn to it, one after another round the wheels.
- **The heart**: a solid ball of white-gold fire, boiling slowly, in a shell of pale flame; a soft halo with a faint
  bow of colours in it ("as the bow that is in the cloud in the day of rain"); motes drifting up.
- **Six wings** ("with twain he covered his face, and with twain he covered his feet, and with twain he did fly"):
  a pair spread up and out behind, beating slowly; a pair crossed over the top of the heart; a pair crossed under
  it. They breathe open and shut. Feathers ivory, the coverts warmer; the core's light falls on them and shines
  through their thin edges.
- **Its light**: an `OmniLight3D` the colour of its fire, on everything round it but itself (it lights its own parts
  in their shaders), so it is the warm, bright thing in a grey world.
- **Its choir**: made in code (`choir_sound()`): an open chord with a semitone rubbing at the top, sung on "oh",
  looping without a seam. All but silent until it gazes.

## Use

```
sh kit.sh install godot/angel /c/Projects/YourGame
```

```gdscript
var angel := Ophan.new()
add_child(angel)
angel.global_position = somewhere + Vector3.UP * 6.2   # the node is its heart; it faces +Z
angel.look_at_point = player_chest     # every eye turns to it (Vector3.INF: they look about)
angel.gaze_ground = player_feet        # where its gaze pools (INF: a metre under look_at_point)
angel.gaze = 0.6                       # 0..1, raise it as its wind-up builds
angel.blaze()                          # the moment it takes someone (BLAZE seconds)
```

What `gaze` does as it rises: the eyes stop blinking, stare wide, pupils shrinking to points; the wheels slow and,
by 0.6, stand still; the wings before its face part and the heart burns brighter; a cone of pale light runs from it
to `look_at_point` and pools on the ground, a spot light falls there, and the choir swells and rises in pitch; past
0.75 the lids quiver. `blaze()` floods the cone with light.

Asking it: `blazing()`, `turning()` (the wheels' speed against their own, 0..1), `parted()` (the face wings, 0..1),
`eye_count()`, `eye_position(i)`, `eye_shut(i)`, `eyes_on(point, within)` (the share of eyes looking at a point).

## Tuning

Exported: `pace` (how fast the wheels turn and the wings breathe), `sound`, `volume_db`, `sound_range`,
`light_range`, `light_energy`, `fire` (the colour of its fire and light), `own_layer` (the render layer its parts
are on, which its lights leave out), `eye_seed`. Scale the node to make it bigger. The sizes are `RING_SIZES`; the
eyes `SEATS`, `EYE`, `EYE_OUT` and the wing's `ELBOW` and `WRIST` must match `tools/build_ophan.py`.

## The model

`models/ophan.glb` holds four parts that the script draws many times each: `Eyeball` (400 triangles), `Lids` (624,
with lashes), `Ring` (13 thousand), `Wing` (3.4 thousand: ten primaries, twelve secondaries, tertials, scapulars,
three rows of coverts and an alula, each feather a cambered blade with a shaft). Built in Blender 4.3:

```
blender --background --python creatures/angel/tools/build_ophan.py [-- <folder for preview renders>]
```

The lids carry in their UV2 which lid each vertex is on and how far it turns to shut; the wing carries which bone
holds each feather (arm, forearm, hand) and its row, so the shaders blink the lids and fold the wings.

## Cost

Eight draws (the wheels, the eyes, the lids and the wings are a MultiMesh each; the core, its flame, the halo and the
motes one each), two more while it gazes, plus the wheels' and wings' shadows. About 90 thousand triangles, most of
them eyes and wheels. Each frame it sets 48 eye and lid transforms, 3 wheels and 6 wings (a fraction of a
millisecond). The choir is made once (about 0.15 s on a desktop) and shared. Hide it, and stop its processing, when
nobody is near.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/angel/`
(it loads its model and shaders from there). Class names: `Ophan` (and its inner `ChoirBand`).

## Limits

- The wings stay inside the inner wheel; the wheels tumble freely and can pass close to a wing's tip.
- Its eyes can turn only so far from straight out of their seats (`MAX_TURN`), so the far side of a wheel cannot
  look at what the near side looks at.
- It casts no light of its own on its own parts (shaders fake that), and its omni light casts no shadows.

`example.gd`: put it on a Node3D in an empty scene and run it; the angel hangs over a floor between two walls, fixes
on a post walking round under it, gazes, blazes and lets go, over and over.
