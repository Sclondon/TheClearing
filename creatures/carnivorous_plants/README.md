# Carnivorous plants

Giant versions of real carnivorous plants, for Godot 4.7 (GL Compatibility, so the web and phones). Each is only the
look, the motion and the sounds; your game says when it is touched and what it holds. Made for Warren (its
`MazeFlytrap`, `MazeSundew` and `MazePitcher` are the thinking there).

- **Flytrap** (`Flytrap`): a Venus flytrap's rosette, one great trap held out over the ground on its leaf (two halves
  open in a V, dull red inside, three trigger hairs on each, long pale teeth round the rims and a band of glistening
  nectar), four small traps round it, a tall stalk of white flowers. `twitch()` (a hair brushed: it shivers half shut
  and back, with a dry creak), `snap()` (`snapped` fires as the halves meet; the teeth interlock), `reopen(seconds)`,
  `full` (shut on something: it bulges and goes dull), `inside(point, radius)`, `mouth()`, `is_open()`, `is_shut()`.
- **Sundew** (`Sundew`): a rosette of long strap leaves lying two metres out over the ground, thick with red
  tentacles each tipped with a drop of glue that glints, and a hooked flower stalk. `sticky(point)` (0..1),
  `hold(point)` (its tentacles lean over it and its leaves curl in, in the shader), `let_go()`, `unstick()` (a wet
  tearing sound).
- **Pitcher** (`Pitcher`): a pitcher plant sunk to its mouth in the mud: a ribbed, striped, wet lip round a hole of
  black fluid, its lid held up over it, fringed wings, a tendril, two small pitchers beside it. `over_mouth(point)`,
  `swallow()` (the lid drops, a gulp, it shudders), `open_lid(seconds)`, `set_shut(bool)`.

`PlantLook` is their shader (vertex colours, cel shaded like Toon, wet parts glinting in beads, tentacles bending
over `grip_point`) and their meshes. Sounds are made in code. Needs GameCommon's `godot/character-controller` (Toon,
Settings). Global class names: `Flytrap`, `Sundew`, `Pitcher`, `PlantLook`.

## Model

`tools/build_plants.py` builds `models/flytrap.glb`, `sundew.glb`, `pitcher.glb` and their `_lo` in Blender 4.3:

    blender --background --python creatures/carnivorous_plants/tools/build_plants.py

One draw a part: the flytrap 3 (base, two halves), the sundew 1, the pitcher 2; about 6k, 19k and 3k triangles
(`_lo`: 4k, 3k, 1k).

## Try it

`example.gd` on a Node3D: one of each, and a post that walks into the flytrap, over the sundew and onto the pitcher.
