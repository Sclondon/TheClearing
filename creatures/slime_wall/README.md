# Slime wall

A great quivering block of green jelly that fills a passage from wall to wall, with what is left of everyone it has
eaten hanging in it: skeletons whole and in pieces, skulls, a ribcage, a hand, a boot, a scrap of red shirt, a coil of
rope, a horned skull, a strip of bandage, a rusted blade, specks and bubbles, all turning slowly as it goes. You see
through it, and what is behind it is bent and clouded by how much jelly you look through; a sludge of what is not yet
gone lies at the bottom. It sags, its foot spreads, its front heaves as it goes, it sways when it starts and stops,
beads of slime run down it, and it leaves a wet trail that dries. Built in code: no models, no textures. Godot 4.7,
works on GL Compatibility (reads the screen and depth textures).

Made for The Clearing (as an enemy there, `scripts/enemies/maze_slime_wall.gd`); this is only the look and motion.

## Use

```gdscript
var slime := SlimeWall.new()
add_child(slime)
slime.global_position = somewhere
slime.settle()
# each frame: move it (it faces +Z; it works out its own speed), and if you like
slime.aim = target.global_position           # its front swells towards it
if slime.contains(player.global_position + Vector3.UP, 0.1):
    player.process_mode = Node.PROCESS_MODE_DISABLED
    slime.hold(player_visible_node, 1.8)     # drawn in, lifted, turned; then `released`
```

- **Fits where it is.** A few times a second it casts rays to either side (`room_mask`) and spreads or squeezes to
  fill the space between the walls (`min_width` to `max_width`), sliding over to sit in the middle. Squeezed, it
  rises. At a turning off (no wall on one side) it keeps the width it had, along the wall it has. `measure_room = false`
  keeps it `width` wide. `room_left`, `room_right`, `fitted_width`, `fitted_offset`, `fitted_height()` say what it found.
- **`contains(point, margin)`**: whether a point is inside it (for touching).
- **`hold(node, seconds)`**: moves `node` into itself and holds it, rising and turning; at the end it is stood upright
  where it is and `released(node)` is emitted. Stop the node moving itself meanwhile. For a figure whose visible part
  is its own top-level node (a CharacterRig), hold that node. `holding(node)`, `let_go()`.
- **`settle()`**: after putting it somewhere, so it does not sway or smear its trail across.

Exports: `height` (6), `depth` (4), `width` (12, where nothing hems it in), `min_width`, `max_width`, `measure_room`,
`room_mask`, `trail_lasts` (seconds), `contents_seed`, `contents_count` (up to 40 pieces), `murk` (how fast it
clouds, per metre seen through), `jelly_color`, `clear_tint`.

## Cost

Five draws: the jelly from inside and from outside, what is in it (one mesh, each piece turned by the shader), its
drips, and the trail (a MultiMesh of patches in the world). No shadows. Nothing is built as it moves: its size and
motion are shader uniforms. Hide it (or disable its processing) when nobody is near.

## Files

`slime_wall.gd` (SlimeWall: fitting, motion, holding, trail), `slime_wall_look.gd` (SlimeWallLook: the meshes and
shaders, and the pieces it has eaten), `example.gd` (a passage that narrows, a slime going up and down it, and things
walking into it).
