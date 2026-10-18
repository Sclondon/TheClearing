# Pond frogs (Godot 4.7)

Ordinary frogs at the edge of the water: common frogs and leopard frogs, a hand long, a dozen or so sitting round the
bank of a pond (or along the edges of pools already in a game), facing the water. They sing (each in its own time, the
throat blown up with each croak; one chorus sound for the colony, made in code: rib-bits and the low purring snores of
leopard frogs), go quiet and still when something comes near, and leap into the water one after another when it comes
close (plop, plop, a ring spreading where each goes in), stay under a while, come up with only their eyes above the
water, and climb back out to their places when nothing is near. How they look and move only: what frightens them and
how hard they sing is for the game to say. Made 2026-10-18 for Warren (its frogs at the marsh and in ponds in the halls:
`scripts/enemies/maze_pond_frogs.gd` there).

## Needs

GameCommon's `godot/frog`: the little frog (`models/frog.glb`, `FrogSwarm.mesh()`) and its shader (`FrogLook`), recoloured.

## Using it

```gdscript
var frogs := PondFrogs.new()
frogs.count = 12
frogs.pool_radius = 1.8               # a pond is drawn here (mud, dark water, rushes), and they sit round its edge
add_child(frogs)
# or along water that is there already, before it goes in:
#   frogs.pool = false; frogs.banks = [[where one sits, the point in the water it leaps to], ...]   (world)
frogs.frighten = [player]             # Node3Ds that frighten them; their `velocity`, if any, is read
frogs.chorus = 0.8                    # how hard they sing, 0..1 (Warren: more at dusk and night, more in rain)
frogs.scare(at)                       # a fright: those near `at` leap in
frogs.take_one(at)                    # one is eaten (gone), the rest leap in; restore() brings it back
```

- `hush_range` (9 m) hushes them, `dive_range` (3.2 m) sends them in, or from further off something coming at them faster
  than `rush_speed`; `under_time` how long they stay under. `out()`, `nearest_out(at)`, `frog_state(i)` (SIT, HOP, DIVE,
  UNDER, PEEK, CLIMB, GONE), `frog_position(i)`; signal `dived(at)`.
- **Cost**: one MultiMesh for every frog of the colony (~1.2k triangles a frog, no shadows), one for the rings, three
  meshes for the pond. No rays, no physics; nothing is done while it is not visible.

## Files

- `pond_frogs.gd` (`PondFrogs`). It must sit at `res://creatures/pond_frog/`.
- `example.gd`: put it on a Node3D in an empty scene. A pond of frogs sings; a post walks up to it every so often and they
  go in, and come out again when it has gone.
