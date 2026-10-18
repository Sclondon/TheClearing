# Stegosaurus

*Stegosaurus stenops*, as the bones have it, at its real size: 8.6 m from beak to tail tip, its back arching 2.85 m
up over the hips on long, straight hind legs and falling to the low shoulders on short forelegs, its biggest plates
near 3.75 m up (a boy comes up to its elbow). A tiny, long, low head with a dark horny beak, cheeks over its teeth
and the eye high at the back, carried low on a short, deep neck with a pavement of bony studs (ossicles) in the skin
of the throat. Seventeen tall plates in two alternating rows, small on the neck, biggest over the hips and the base
of the tail; the thagomizer, two pairs of long spikes held out sideways and up from the end of the tail. Elephant
feet: five short toes with blunt nails in a half circle round the front of each forefoot, three broad hoofed toes on
each hind. A hide of small pebbly scales, dull grey-brown, paler below, darker bands across the back; the plates
bone in horn, grooved from root to rim. Toon-shaded (hard light bands). Everything it does is animated in code on its
own skeleton: no clips. Made for The Clearing (its territorial grazer). The component has no thinking; it makes its
own sounds, in code.

## Using it

```gdscript
var steg := Stegosaurus.new()     # life size; scale 0.38 (and scales = 20) for a calf
add_child(steg)
# each frame: move it (position, rotation.y; it faces +Z) and it walks to match, each foot planted where it lands
steg.grazing = true               # beak to the ground, cropping
steg.look_at_point = target       # INF for nothing
steg.warning = true               # side on, braced, tail raised and cocked away, the spikes waving
steg.threat_side = 1.0            # which side of it they are on (1: its left)
steg.swing(1.0)                   # the tail whipped round low at its left; `swept` as the spikes come through
if steg.sweeping() and steg.tail_gap(their_chest) < 0.55: ...   # hit
steg.rumble(); steg.bellow(); steg.huff()
```

- **The walk**: a slow, heavy four-beat walk (hind, fore, hind, fore, as an elephant), each foot down three quarters
  of the stride and lifted little; the hip over a lifted foot sags, the body rolls and shifts its weight, the hips and
  shoulders swing against each other and the tail sways a stride behind. Faster it ambles. Its feet stay where they
  were put down (in the world) until lifted, so nothing slides; turning on the spot it steps round. Speed is measured
  from how it is moved, or set `velocity` with `measure_velocity = false`.
- **The swing** (`StegosaurusRig.SWING_TIME`, 1.45 s): the tail is drawn back further, away, then whipped round
  across behind it and out to the side swung at, low (the spikes at chest height on a man), each bone of it lagging
  the one before (a whip), the hips thrown round with it. Dangerous from `WHIP.x` to `WHIP.y` (0.42 to 0.8 s): the end
  of the tail reaches about 4 m from its hips.
- **Signals**: `rumbled`, `bellowed`, `huffed`, `swung(side)`, `swept`, `footfall(at, weight)`.
- **Sounds**, made in code when first needed (`sound`): a deep fluttering rumble (its warning), a honking bellow, a
  huff, heavy footfalls, the swish and whoomp of the tail. Run tests with `--audio-driver Dummy`.
- **Dust** (`dust`): a puff from each foot as it comes down.
- **Exports**: `low_poly` (the demade model), `skin_tint`, `scales` (scales to a metre of its hide), `eyeshine`,
  `measure_velocity`, `sound`, `volume_db`, `sound_range`, `dust`.
- **Cost**: three draws (skin, plates and spikes, parts) and its dust; no textures. The model is 45k triangles, or
  3.6k low. Posing is about 35 bones set from code each frame: don't pose it when it is far.

## Files

- `stegosaurus.gd` (`Stegosaurus`): what a game drives; its sounds and dust.
- `stegosaurus_rig.gd` (`StegosaurusRig`): poses the skeleton every frame (the walk with planted feet, three-bone
  leg IK, the head, jaw and tail; the swing; `tail_gap`, `spike_tips`, `beak_tip`, `hips`).
- `stegosaurus_look.gd` (`StegosaurusLook`): three shaders. A scaly hide (pebbles drawn from the first texture
  coordinates, laid in metres after fusing), creased, banded and pale below from the vertex colours; grooved plates
  and spikes, dark at the root and paler to the rim; vertex-coloured parts (eyes, beak, nails, ossicles, mouth).
- `models/stegosaurus.glb` and `stegosaurus_lo.glb`: built by `tools/build_stegosaurus.py` in Blender 4.3, which uses
  `tools/build_character.py` from `godot/character-controller`. Run it from the game's root:
  `blender --background --python creatures/stegosaurus/tools/build_stegosaurus.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A stegosaurus and its calf go through every move.

Needs nothing else at run time (no textures, no other components).
