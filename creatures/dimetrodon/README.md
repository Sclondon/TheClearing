# Dimetrodon

*Dimetrodon grandis* at its real size: 3.4 m from snout to tail tip. A synapsid of the Permian, not a dinosaur (nearer
to us than to them): low-slung on sprawling legs (the upper arm and thigh held out sideways, the forearm and shin down
to broad five-toed clawed feet planted wide), the belly a hand's breadth off the ground. Down its back the sail: 21
tall neural spines, the tallest about a metre over its back, with skin between them, its top a long arch. A big, deep,
narrow skull, the eye high and far back, and the two kinds of teeth its name is for: great stabbing canines at the
front of the upper jaw and small cutting teeth behind. A long tail tapering to the ground. Fine pebbly scales, dusky
grey-brown with darker bands, paler below; the sail darker, banded up between the spines. Toon-shaded. Everything is
animated in code on its own skeleton. Made for Warren (the basking ambusher). No thinking; its own sounds, in code.

## Using it

```gdscript
var dim := Dimetrodon.new()
add_child(dim)
# each frame: move it (position, rotation.y; it faces +Z) and it walks to match
dim.basking = true            # flat on the ground, still (turn it side on to the sun)
dim.threatening = true        # up on its legs, jaws gaping; dim.hiss()
dim.lunge()                   # a low dart, jaws flung open and snapped shut: `snapped`
dim.look_at_point = someone   # INF for nothing
```

- **The walk**: a sprawler's, two-bone IK to each foot with the elbow and knee kept out and up, the feet planted wide
  and staying put until lifted, the diagonal feet nearly together, the spine swinging in an S (shoulders one way, hips
  the other) and the tail wagging a beat behind. Faster it is held higher and swings more: a scuttling rush.
- **Basking**: lying flat, belly on the ground, legs splayed, chin down, breathing.
- **The threat**: up high on its legs, head raised and turned to them, jaws wide to show its teeth, with a hiss.
- **The lunge** (`DimetrodonRig.LUNGE_TIME`, 0.75 s): body low, head thrust out, jaws flung open and snapped shut at
  `SNAP_AT` (0.42 s). The game moves it forward for the dart.
- **Signals**: `snapped`, `hissed`, `footfall(at, weight)`. **Sounds**: hiss, snap, grunt, the scrape of its claws.
- **Exports**: `low_poly`, `skin_tint`, `scales`, `eyeshine`, `measure_velocity`, `sound`, `volume_db`, `sound_range`.
- **Cost**: two draws; no textures. 36k triangles, or 5k low. About 25 bones posed from code each frame.

## Files

- `dimetrodon.gd` (`Dimetrodon`): what a game drives; its sounds.
- `dimetrodon_rig.gd` (`DimetrodonRig`): poses the skeleton (the sprawling walk, the swinging spine, the head, jaw
  and tail; basking, the threat, the lunge; `snout_tip`).
- `dimetrodon_look.gd` (`DimetrodonLook`): two shaders (the pebbly hide and sail from the vertex colours; the parts).
- `models/dimetrodon.glb` and `dimetrodon_lo.glb`: built by `tools/build_dimetrodon.py` in Blender 4.3 (uses
  `tools/build_character.py` from `godot/character-controller`):
  `blender --background --python creatures/dimetrodon/tools/build_dimetrodon.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene: a dimetrodon walks, basks, rises and lunges, over and over.

Needs nothing else at run time.
