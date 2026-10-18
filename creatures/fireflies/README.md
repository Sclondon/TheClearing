# Fireflies (Godot 4.7)

Clouds of fireflies out at dusk and through the night: how they look, fly and blink, and nothing of what they mean in
a game. Made 2026-10-18 for Warren (where they rise from the clearing's tall grass, its woods, the marsh and the
meadow, and from the foot of the ivy and the ferns in the first ring: `scripts/wildlife/insects.gd` there).

- `creatures/fireflies/firefly_field.gd` (`class_name FireflyField`, a `Node3D`): where they live, what is drawn.
- `creatures/fireflies/firefly.gdshader`: moves and blinks every one of them, and draws its glow (or its body).
- `creatures/fireflies/models/firefly.glb` (the beetle, about 340 triangles), built in Blender 4.3 by
  `tools/build_firefly.py`:

```
blender --background --python creatures/fireflies/tools/build_firefly.py
```

## What they are

Lightning bugs (Lampyridae): small dark beetles a centimetre and a half long, a pale shield over the head, dark wing
cases raised as they fly over the clear hindwings, and a lantern under the tail that lights in cold yellow-green.
Three kinds, each in its own rhythm, as real ones are:

- **Big dippers** (*Photinus*): one long flash every three and a half to five and a half seconds, swooping up in a J
  as they flash.
- **Synchronous** (*Photinus carolinus*): bursts of six quick flashes, all of them together, then dark; the burst
  rolls across the field in a wave; not every one joins every burst.
- **Cold green** (*Photuris*): a slow glow, swelling and fading, on its own wandering beat.

They come out as the light goes, each at its own darkness, rising out of the grass to their own height (most of them
low, some up into the trees); drift slow and lazy about where they live; scatter from anyone running through them
(flashing as they go) and drift back when he stops.

## Putting it in a game

```
sh kit.sh install godot/fireflies /c/Projects/YourGame
```

```gdscript
var fireflies := FireflyField.new()
add_child(fireflies)
# where they live: as many patches as you like (a point on the ground, how far round, how many,
# how high they fly, a seed, how high the ground is under each, the share of each kind)
fireflies.add_patch(meadow, 7.0, 32, Vector2(0.3, 2.0), 1, ground_height_callable)
fireflies.night = 1.0              # how dark it is: 0 by day (none out) .. 1 at night
fireflies.scarers = [player]       # up to four: running through scatters them
```

`example.gd` is a whole scene: a dark field with three clouds, the dusk coming and going, and someone running
through them.

## Tuning

Exported: `night`, `max_drawn` (700), `draw_range` (65 m), `body_range` and `max_bodies` (the beetles drawn close to
the camera), `refill_step`, `size`, `halo_size`, `brightness`, `mist` (how fast the mist dims them), `scatter_reach`,
`lights` (OmniLights at the patches nearest the camera, 0 by default), `light_range`, `light_energy`, `kinds` (the
share of each kind). The colours and the rhythms are the shader's (`colour_dipper`, `colour_together`, `colour_cold`,
`wave_way`, `wave_speed`).

## Cost

Every firefly is moved and blinked in the vertex shader: the CPU does nothing from frame to frame but set a few
uniforms. The glows of those within `draw_range` of the camera (at most `max_drawn`) are one MultiMesh (one draw, a
quad each, added to what is behind it); the beetles of the few within `body_range`, a second (only when some are that
near). They are written again only when the camera has moved `refill_step` metres (about 0.15 ms each time). By day
(`night` 0) nothing is drawn at all. No shadows; the game's fog is not laid over them (it would show their quads): the
mist dims them by itself (`mist`).

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/fireflies/`.
Works in GL Compatibility (web, phones). With glow on in the environment, the cores bloom a little more.
