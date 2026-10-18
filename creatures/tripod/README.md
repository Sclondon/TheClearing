# Tripod

A Martian fighting-machine, after *The War of the Worlds*: Wells' "brazen hood" by way of the 2005 film's tripods,
at full size. A great low cowl of weathered bronze plate (ridged along its spine, riveted, verdigris where the rain
lies, rust running down) about 22 m across, its top some 60 m up; a pale glowing eye deep in the dark under its
brow, with two small ones beside it; a ribbed dark dish under it and a drum it turns on, with a spike hanging below.
Three long, noodly legs of segmented metal 73 m long, ribbed like vertebrae with a collar at each of their twelve
joints and a cable along each, ending in feet of three claws. A heat ray on a jointed arm under the right of its
brow: a finned emitter like a camera with a horn, its lens deep in it. Four cable tentacles and a clawed grasper
hanging under it. Red weed draped over the hood and trailing off its rim and its legs. Lit in hard bands (cel
shading) like the rest of a misty, Inside-like world. Everything it does is animated in code: no clips.
Made for Warren (its tripod). The component has no thinking; it makes its own sounds, in code.

## Using it

```gdscript
var tripod := Tripod.new()
add_child(tripod)
# each frame: move it (position: the ground under its body; rotation.y: the way it faces, +Z).
# It walks by itself, a leg at a time; keep it under Tripod.WALK_SPEED, slower while `strain` is high.
tripod.foot_ok = func(point: Vector3) -> bool: return true   # where a foot may come down
tripod.beam_target = point        # its searchlight (INF: ahead and down); `searchlight = false` puts it out
tripod.look_at_point = point      # its hood turns there (INF: it follows its light)
tripod.arm_target = point         # the heat ray's arm swings round to it (INF: folded)
tripod.charge = 0.7               # 0..1: the emitter glows, its hum rises
tripod.firing = true              # the ray, from the emitter to whatever it meets first towards arm_target
tripod.reach_target = point       # the grasper reaches down to it, stretching as it must (INF: it hangs)
tripod.horn()                     # the deep, distorted "ULLA"
tripod.settle()                   # after putting it somewhere new: its feet straight down
# read: beam_hit, beam_dir, eye_point(), ray_hit, emitter_tip(), grasper_tip(), body_point(), feet, stepping, strain
```

- **Walking**: a foot stays planted until the body has gone on far enough (`STRIDE`), then lifts high over whatever
  is in the way, swings and comes down hard (`footfall`), one leg at a time, every few seconds. Its feet come down
  only on open ground (rays from above; the top of a wall only if there is no open ground near) and where `foot_ok`
  allows. Each leg is laid along a smooth arch from its hip to its foot, bowed to its length, so it coils high as the
  foot is drawn in and runs out long as it reaches; a spring at its middle lags and overshoots (it whips and sways),
  a ripple runs down it as it swings, and it splays and wobbles as it lands. The body sways over its planted feet,
  sinks as a leg lifts and jolts as one lands. A body round each planted foot (layer 1) is bumped into (`foot_bodies`).
- **The searchlight**: a cone of pale light in the mist (mist and motes in it) and a SpotLight3D whose shadows let
  the walls cut it (`beam_shadows`). The eye turns in its bezel and leads; the hood follows, slowly.
- **The heat ray**: a white-hot core in an orange sheath, sparks and a glow where it lands, and a ragged black
  scorch with a glowing seam that cools and fades (up to four at once), steam rising off it afterwards.
- **Signals**: `footfall(at, weight)`, `horned`. Footfalls shake the camera within `shake_range` (`shake`: it
  nudges the current camera's `h_offset` and `v_offset`).
- **Sounds** (`TripodSound`, made in code when first needed, the horn as soon as it is made): the horn (two
  syllables through an "oo" to "ah" mouth, a dissonant voice above, distortion and echoes, 4.6 s), footfalls, the
  hiss of a lifting leg, the charging hum, the ray's roar and sizzle, the grasper's clank. Run tests with
  `--audio-driver Dummy`.
- **Exports**: `low_poly` (only the demade model), `far_from` (where the demade one takes over), `sound`,
  `volume_db`, `sound_range`, `shake`, `shake_range`, `shake_strength`, `effects`, `beam_shadows`, `foot_bodies`,
  `ray_mask`.
- **Cost**: one skeleton of 65 bones and one skinned mesh at a time (3 surfaces: metal, glow, weed): about 65k
  triangles near, 7.7k far (beyond `far_from`), plus its beam, a shadowed spot light, and the ray and effects while
  they are on. Posing is a few hundred vector sums a frame.

## Files

- `tripod.gd` (`Tripod`): what a game drives: walking, the light, the ray, the grasper, sounds, shaking.
- `tripod_rig.gd` (`TripodRig`): poses the skeleton every frame (the legs' arches and springs, the arm's IK, the
  eye, the tentacles).
- `tripod_look.gd` (`TripodLook`): the shaders (plated metal, glowing lenses, red weed, the beam, the ray, the scorch).
- `tripod_sound.gd` (`TripodSound`): its sounds.
- `models/tripod.glb`: built by `tools/build_tripod.py` in Blender 4.3 (standalone), from the game's root:
  `blender --background --python creatures/tripod/tools/build_tripod.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A tripod goes through everything it does.

Needs nothing else at run time (no textures, no other components).
