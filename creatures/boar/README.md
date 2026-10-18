# Giant boar

A monstrous wild boar, after the boar gods of *Princess Mononoke* and the hogs of folklore: a real boar's shape and
anatomy made huge. The model stands a metre at the shoulder, as a big boar does; scaled 2.7 it stands far over a
man's head. All its weight is forward: a hump of muscle over the shoulders with a crest of long black bristle down
it, the back falling away to a narrow rump, a short deep neck lost in the jowls, a long wedge of a head running down
to a wet disc of a nose, small eyes deep under a heavy brow. Two pairs of tusks, the lower curving up and back out
of the mouth, chipped and scored; the right lower one broken off short. Short thick legs on cloven hooves with
dewclaws. Coarse black-brown coat grizzled at the tips, mud caked up its legs, belly and snout, old scars, broken
arrow shafts still in its shoulder and flank, strings of slobber, steaming breath. Toon-shaded (hard light bands).
Everything it does is animated in code on its own skeleton: no clips. Made for Warren (its charging boar).
The component has no thinking; it makes its own sounds, in code.

## Using it

```gdscript
var boar := Boar.new()
boar.scale = Vector3.ONE * 2.7
add_child(boar)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match (and skids, slowing hard)
boar.rooting = true           # snout in the mud, ploughing, head swinging
boar.sniffing = true          # snout up into the wind, nose working
boar.bristling = true         # hackles (the crest) up
boar.lowered = true           # head down, tusks forward: the wind-up and the charge
boar.stunned = true           # swaying, head hung, shaking it
boar.look_at_point = target   # INF for nothing
boar.snort(); boar.grunt(); boar.squeal(); boar.stamp()
boar.slam()                   # it has run into something
boar.toss(1.0)                # tusks heaved up and to its left; `tossed` as they come up
if boar.gores(their_chest): ...
```

- **Gaits**: a four-beat walk, a trot, and a heavy rotary gallop in which each leg is flung out behind and reaches out
  ahead and the back gathers and stretches (after the dogs' rig). Speed is measured from how it is moved, or set
  `velocity` with `measure_velocity = false`.
- **Signals**: `snorted`, `grunted`, `squealed`, `stamped(at)`, `slammed`, `tossed`, `footfall(at, weight)`.
- **Sounds**, made in code when first needed (`sound`): snort, grunt, its charging squeal, hoofbeats, stamps, the
  crash of a slam. Run tests with `--audio-driver Dummy`.
- **Breath and dirt** (`steam`): steam puffs from its nose with each breath and each snort; dirt from its hooves
  (stamping, galloping, skidding), from its snout rooting, and from a slam.
- **Exports**: `low_poly` (the demade model, no bristle shells), `fur_shells`, `coat_tint`, `mud`, `eyeshine`,
  `measure_velocity`, `sound`, `volume_db`, `sound_range`, `steam`.
- **Cost**: about 8 draws with 2 shells (3 surfaces: coat, crest, parts) plus its puffs; fewer with `low_poly`. The
  model is about 52k triangles (most of them the crest's bristles), or 4.7k low.

## Files

- `boar.gd` (`Boar`): what a game drives; its sounds and puffs.
- `boar_rig.gd` (`BoarRig`): poses the skeleton every frame.
- `boar_look.gd` (`BoarLook`): three shaders. A bristly coat in stiff clumps with shells that rough up its outline,
  creases, grizzled hair and caked mud from the model's vertex colours and scars from its second texture
  coordinates; a crest that bristles; vertex-coloured parts (eyes, the wet disc of its nose, tusks, hooves, arrows,
  slobber).
- `models/boar.glb` and `boar_lo.glb`: built by `tools/build_boar.py` in Blender 4.3, which uses
  `tools/build_character.py` from `godot/character-controller`. Run it from the game's root:
  `blender --background --python creatures/boar/tools/build_boar.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A boar goes through every move.

Needs nothing else at run time (no textures, no other components).
