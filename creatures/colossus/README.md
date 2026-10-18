# Colossus: a giant of stone and fur, after Shadow of the Colossus (Godot 4.7)

A hunched giant 120 m tall (any height you like): a body of dark, matted fur over earth, armoured in great slabs of
weathered stone grown over with moss and grass and hung with vines, long ape's arms ending in hands of stone blocks,
feet like the footings of a wall, and a stone mask for a face, long and heavy-browed like the heads of Rapa Nui, with
a pale light in its eyes and in the runes cut into its stone. It walks in slow, enormous strides, each foot lifted as
high as it must be (over a wall) and set down with a deep thud that shakes the ground, dust rolling out from under
it and stones and clods falling from it. It bends and reaches down with one great hand to strike and sweep the
ground, and it can haul itself up on the top of a wall to look over it. Made 2026-10-18 for The Clearing (its
`MazeColossus` walks the first ring over the walls), as a creature any game can use: it is only the look, the
motion and the sound, and knows nothing of what it is doing it for.

- `creatures/colossus/colossus.gd` (`class_name Colossus`, a `Node3D`): the motion, all procedural (no animations).
- `creatures/colossus/colossus_look.gd` (`class_name ColossusLook`): its shader (the house cel light, stone grain,
  cracks and lichen and fur streaks from two noise textures made in code, a mist of its own over its upper body),
  the shadow blots, the dust and the stones.
- `creatures/colossus/models/`: `colossus.glb` (about 45,000 triangles) and `colossus_lo.glb` (12,000), each one
  skinned mesh on 19 bones, one material. The low one also rides the high one's skeleton to cast its shadow, and is
  drawn in its place beyond `lod_distance`.
- `creatures/colossus/tools/build_colossus.py` makes the models in Blender 4.3: a metaball sculpture for the body,
  roughened into lumps and shag and decimated; slabs of stone fitted to it by rays from the bones (curved, with
  broken outlines, chamfered rims, cut bands, glowing runes, moss on whatever faces up); hands, feet and the mask;
  fur as many clumps, long fringes under the stone; tufts of grass and vines.

```
blender --background --python creatures/colossus/tools/build_colossus.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones). Needs nothing else.

## Using it

```gdscript
var giant := Colossus.new()
giant.height = 120.0                  # metres (it is modelled 10 units tall)
add_child(giant)
giant.put(spot, yaw)                  # standing there, its feet either side (0 faces +Z)

# Walking is yours to plan: say where each foot goes, and it does the rest.
giant.step(Colossus.LEFT, where, foot_yaw, clear)   # lifted over anything up to `clear` m high
giant.facing = yaw                    # its body turns to this, slowly (turn_rate)
giant.footfall.connect(func(foot: int, point: Vector3) -> void:
	if giant.under_foot(foot, player.global_position): crush(player))

giant.look_at_point = target          # its head turns to it (INF: looks about)
giant.reach(target)                   # bend, hover, strike, sweep, rise
giant.reach_target = target           # its hovering hand follows this (slowly)
if giant.hand_hits(point, 2.0): ...   # while reach_stage() is STRIKE or SWEEP
giant.lean_on = wall_top_point        # haul up and look over (INF: get down)
Colossus.rattle(camera, giant.shake_at(camera.global_position))   # every frame
```

- Feet: `stepping()` (the foot in the air, or -1), `step_progress()`, `landing(foot)`, `landing_yaw(foot)`,
  `foot_point(foot)` (where it is now), `under_foot(foot, point, margin)`, `footprint(foot)` (its corners),
  `print_size()` (across either side, back and forward of the point under the ankle), `stride()` (how far apart
  its feet can be), `plant(foot, point, yaw)` to put one down at once. Signals `lifted(foot, to)` and
  `footfall(foot, point)`.
- Reaching: `reaching()`, `reach_stage()` (`Colossus.Reach`: BEND, HOVER, STRIKE, SWEEP, RISE), `reach_time(stage)`,
  `hand_point()`, `strike_point()`, `hand_hits(point, radius)`. Signal `hand_down(point)`.
- Where it is: `pelvis()`, `eye()`, `body_yaw()`, `leg_capsules()` ([from, to, radius] for each thigh, shin and
  foot: make bodies of them to bump into).
- Exports: `height`, `low_poly`, `casts_shadow`, `lod_distance`, `sound`, `volume_db`, `sound_range`, `step_time`,
  `turn_rate`, `hover_time`, `hover_height`, `sweep_length`, `glow` (its eyes and runes), `lean_rise`.

## How it moves

Its body follows its feet: the hips go between them, over the one it stands on as the other is carried, and only as
high as both legs reach. A carried foot goes up first and down last (so it clears whatever is near where it left and
where it comes down) and across between, its heel lifting and its toes coming down; a long step, or one over a wall,
takes longer. While it comes down, a shadow grows dark on the ground where it will land, earth falls from it and a
rumble rises; then the thud, the dust and the shaking (`shake_at`). Its arms hang heavy and swing against its stride,
its back sways over the foot it stands on, it breathes, and its head turns slowly to what it looks at (or looks
about). To reach it squats deep, hips back, bends over, holds its hand palm down `hover_height` over the target for
`hover_time` (its shadow on the ground under it) while the other braces on its knee, strikes down, sweeps the hand
`sweep_length` along the ground towards itself, fingers curling, and straightens up. To lean it walks its hips up to
the wall, puts its forearms on the top, rises on its toes and hauls itself up `lean_rise`, its chest over the top
and its head raised.

The two pale points of its eyes (`ColossusLook.glint_material`) are drawn through the mist from 70 m off, so that
from far away its eyes show where its head is.

## Sound

`Colossus.thud_sound()` (a deep falling thud, the crack and grind of stone and earth, a rolling tail; 2.6 s) and
`Colossus.rumble_sound()` (a low rumble looped under a foot as it comes down), both made in code.

## Try it

`example.gd` on a Node3D: one walks round a circle across two walls, stepping over them, then reaches for a post
and leans on a wall to look over it.
