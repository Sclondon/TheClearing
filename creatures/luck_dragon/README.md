# Luck dragon (Godot 4.7)

A dragon of good fortune that swims through the sky. It is original, though it owes something to the
NeverEnding Story. It is about 35 m from nose to tail and slender, round as a great eel, with no wings. Small
pale scales with a pearly sheen and broad belly plates; soft white fur along its back, a mane streaming back
from the crown and cheeks, a plume at the tail's end. Four short legs with three blunt toes. A broad, gentle
head, more a great hound's than a reptile's: high round brow, short broad muzzle, soft dark nose, hanging
flews, big dark kind eyes, long hound's ears, long barbels trailing from its lips. Made 2026-10-18 for Warren
(`scripts/enemies/maze_luck_dragon.gd` there). It is only the look, the motion and the sound: it does no thinking.

- `luck_dragon.gd` (`class_name LuckDragon`, a `Node3D`): the motion, posed bone by bone in code, and its call.
- `luck_dragon_look.gd` (`LuckDragonLook`): its shader (cel bands, scales, pearl sheen, fur, wet eyes;
  receives no shadows, so the fur does not blotch it).
- `models/luck_dragon.glb`: two skinned meshes on one skeleton, `luck_dragon` (about 32,000 triangles) and
  `luck_dragon_lo` (about 6,600), built in Blender 4.3 by `tools/build_luck_dragon.py`:

```
blender --background --python creatures/luck_dragon/tools/build_luck_dragon.py [-- <folder for preview renders>]
```

## Using it

```gdscript
var dragon := LuckDragon.new()
add_child(dragon)
dragon.global_position = somewhere_in_the_sky
dragon.settle()                  # laid out straight behind its head (the way the node faces)
# each frame, move the node (where its head joins its neck); the body follows the path the head flew
dragon.aim = player.global_position   # what it looks at (INF: ahead)
dragon.reach = 1.0               # legs down and forward (near the ground)
dragon.paddle = 1.0              # legs paddling as it swims
dragon.mouth = 0.3               # jaw a little open
dragon.sing()                    # its call: a deep warm hum with bells in it; `called` at the top
dragon.back_point(3.6, 1.0)      # a Transform3D on its neck, to sit someone on
dragon.head_point(); dragon.body_point(metres_back)
```

- **Motion**: follow-the-leader. Every spine bone (25, 1.3 m apart, no parents) is set where the head was, so a
  weaving head draws S-waves down the body and a circling one coils it. A slow swimming wave runs down it on top
  (`undulate`), and it banks into its bends. Ears and barbels stream back and sway. `lay_along(points)` puts it
  down along any line (for pictures, or to start coiled).
- **For pictures and tests**: `frozen = true`, `lay_along(...)`, `pose_now()`.
- **Exports**: `sound`, `volume_db`, `sound_range`, `lod_distance`, `undulate`, `seed_value`. Static
  `LuckDragon.low_poly` makes every one use the low mesh (phones).

## Cost

One draw (and its shadow) for whichever mesh is shown; about 40 bones set each frame; its bounds are fitted to
where its body is now. Hide it or disable processing when far from everyone.

## What it needs

Nothing else. The files must sit at `res://creatures/luck_dragon/`.
