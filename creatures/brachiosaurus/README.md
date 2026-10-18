# Brachiosaurus

*Brachiosaurus altithorax* as it is drawn now, at its real size: about 21 m from snout to tail tip, the shoulders
6.6 m up and the back sloping down to the hips (its forelimbs are longer than its hind), the neck held high and the
small head 13 m up (a boy comes up to the middle of its forearm). A broad, blunt muzzle with spoon-like teeth at its
edges, the arch of the nasal crest rising over the snout in front of the eyes, the nostrils low on the snout.
Columnar legs like an elephant's: the forefeet a tall horseshoe with one claw on the thumb, the hind feet broad pads
with three claws on the inner toes. A short tail for a sauropod, held off the ground. A wrinkled hide of small
pebbly scales, dull grey, darker and mottled over the back, paler below. Toon-shaded (hard light bands). Everything it
does is animated in code on its own skeleton: no clips. Made for Warren (the gentle giant of the desert and the round
sections). The component has no thinking; it makes its own sounds, in code.

## Using it

```gdscript
var brach := Brachiosaurus.new()
brach.foot_shadows = true        # a dark spot on the ground where each lifted foot will come down
add_child(brach)
brach.ground_at = func(x: float, z: float) -> float: return height_of_ground(x, z)   # uneven ground (optional)
# each frame: move it (position, rotation.y; it faces +Z) and it walks to match, each foot planted where it lands
brach.browse_point = leaves      # neck stretched to them, nibbling (INF for none)
brach.look_at_point = someone    # head turned to them, the neck curving down to see something low
brach.bellow(); brach.rumble(); brach.snort()
brach.footfall.connect(func(at, weight): ...)   # a foot has come down at `at` (its sole)
var next := brach.landing(0)     # where foot 0 will come down (xyz) and how near it is (w: 0..1, -1 down)
```

- **The walk**: slow, four beats (an elephant's lateral walk), each foot down about seven tenths of the stride and
  lifted high and slowly; where a foot will come down is settled as it is lifted (where the body will be by then), so
  the spot that `foot_shadows` draws is exactly where it lands. The hips sag over a lifted foot, the body rolls, the
  neck sways a little against it and the tail behind. Turning on the spot it steps round. On uneven ground
  (`ground_at`) each foot finds the ground and the body pitches to the slope.
- **Browsing**: the neck stretched up and round to `browse_point`, the head reaching in, the jaw working, a tug as it
  strips the leaves (and a rustle and crunch).
- **Looking**: the head turns to `look_at_point`; for something low (someone at its feet) the neck curves down.
- **Signals**: `bellowed`, `rumbled`, `footfall(at, weight)`.
- **Sounds**, made in code when first needed: a long deep hollow bellow, a rumble too low to hear well, a snort,
  the boom of each footfall, the crunch of leaves. Run tests with `--audio-driver Dummy`.
- **Dust**: a ring of dust from each foot as it lands.
- **Far off** (`lod_range`, 70 m from the camera by default) it is drawn with its low model; `pose_every` (set by the
  game, by how far it is) poses it only every few frames. Seen from far off it still reads: it is meant as a landmark.
- **Exports**: `low_poly`, `lod_range`, `skin_tint`, `scales`, `eyeshine`, `measure_velocity`, `foot_shadows`,
  `sound`, `volume_db`, `sound_range`, `dust`.
- **Cost**: two draws (skin, parts), one for the foot shadows (a MultiMesh of four spots), and its dust; no textures.
  The model is 45k triangles, or 2.9k low. Posing is about 35 bones from code each frame (less often far off).

## Files

- `brachiosaurus.gd` (`Brachiosaurus`): what a game drives; its sounds, dust and foot shadows.
- `brachiosaurus_rig.gd` (`BrachiosaurusRig`): poses the skeleton (the walk with planted feet, three-bone leg IK, the
  neck, head, jaw and tail; `landing`, `sole`, `snout_tip`, the low model far off).
- `brachiosaurus_look.gd` (`BrachiosaurusLook`): two shaders: a pebbly hide from the first texture coordinates, creased,
  mottled and pale below from the vertex colours; vertex-coloured parts (eyes, claws, teeth, mouth, nostrils).
- `models/brachiosaurus.glb` and `brachiosaurus_lo.glb`: built by `tools/build_brachiosaurus.py` in Blender 4.3, which
  uses `tools/build_character.py` from `godot/character-controller`. Run it from the game's root:
  `blender --background --python creatures/brachiosaurus/tools/build_brachiosaurus.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene: a brachiosaurus walks round, browses, looks down and bellows.

Needs nothing else at run time.
