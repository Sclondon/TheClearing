# Giant praying mantis (Godot 4.7)

A praying mantis, after the European mantis and the giant Asian mantises, at its real proportions, made huge: about
three metres tall standing, its long prothorax reared and its triangular head on top of it, its abdomen held level
behind on four long thin walking legs, its spined raptorial forelegs folded together under its head "in prayer". Pale
grey-green, the colour of a dead leaf's underside in the mist, lit in hard bands. Its look, every move and its sounds,
and no thinking. Made 2026-10-18 for Warren (where it lies in ambush in the halls: `scripts/enemies/maze_mantis.gd`).

## Using it

```gdscript
var mantis := GiantMantis.new()
add_child(mantis)
mantis.settle()                          # feet down where it stands
# each frame: move it (position, rotation.y; it faces +Z) and it walks to match
mantis.look_at_point = player_head       # its head turns to follow, in small jerks (INF: it looks about)
mantis.strike(player_chest)              # a blur: cocked, shot out at the point, shut, drawn back
if mantis.strikes(their_chest, 0.3): ... # whether the shooting forelegs pass there
mantis.holding = true                    # after a strike: what it caught to its jaws
mantis.display = true                    # the threat display
mantis.eating = true                     # forelegs to its jaws, chewing
mantis.rustle()                          # a faint rustle of leaves
```

- **Still**: it rocks gently back and forth and from side to side like a leaf in a breeze (`sway`), its feelers drift,
  its forelegs stir; its head turns to `look_at_point` in small quick jerks, as a mantis's does, nearly round behind
  it: the one thing about it that moves with purpose. Its eyes have the false pupil a real mantis's have, the dark
  spot where the facets look straight back at you, so that wherever you are it seems to be looking at you.
- **Walking**: two legs at a time (mid on one side with hind on the other), each lifted high and put down ahead, two-
  bone IK to where each foot is planted; its body rocks forward and back over them (the swaying walk). Speed is
  measured from how it is moved, or set `velocity` with `measure_velocity` false.
- **The strike** (`strike(point)`): the forelegs cock (`STRIKE_COCK`, 0.11 s), shoot out at the point, opening as they
  go, with the prothorax lunging after them (`STRIKE_SHOOT`, 0.065 s), the spined tibiae snap shut (`STRIKE_CLAMP`)
  and draw back in (`STRIKE_RETRACT`). It reaches about three metres in front of where it stands. `strike_stage()`,
  `striking()`, `claws()`, `strikes(point, radius)`; `struck` is emitted as they shoot out.
- **The threat display** (`display`): it rears taller, throws its forewings up and spreads its smoky hindwings behind
  them like a sail, opens its forelegs wide to show the dark spots inside them, curls its abdomen up, sways from side
  to side, hissing. A strike throws it off at once.
- **Eating** (`eating`, or `holding` after a strike): forelegs drawn up to its jaws, head down, chewing.
- **Sounds**, made in code when first needed (`sound`): a rustle, the snap of a strike, the hiss of its display.
  Run tests with `--audio-driver Dummy`.
- **Exports**: `low_poly` (the demade model), `sound`, `volume_db`, `sway`, `measure_velocity`.
- **Cost**: one draw (one material on one skinned mesh) and its shadow; about 4900 triangles, 2000 in the low model.
  Posing it (the IK and the rest) is about 0.05 ms a frame. Hide it and disable its processing when nobody is near.

## Files

- `mantis.gd` (`GiantMantis`): what a game drives; its rig (posed in code every frame on the model's skeleton) and its
  sounds.
- `mantis_look.gd` (`MantisLook`): its one shader (hard light bands, a pale rim, the false pupils of its eyes, the
  veins of its wings drawn from their UVs, a faint mottling) and the model loader.
- `models/mantis.glb` and `mantis_lo.glb`: built by `tools/build_mantis.py` in Blender 4.3 (every part a rigid piece on
  its own bone, as an insect's hard parts are; vertex colours give each part its colour and say what it is). Run it
  from the game's root: `blender --background --python creatures/mantis/tools/build_mantis.py [-- <folder>]`.
- `example.gd`: put it on a Node3D in an empty scene. A mantis looks about, follows a point going round it with its
  head, strikes at it when it comes close, makes its display, walks a little and eats.

Needs nothing else at run time (no textures, no other components). The files must sit at `res://creatures/mantis/`.
