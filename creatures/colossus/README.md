# Colossus: a spindly giant that crawls over walls and presses with one finger (Godot 4.7)

A gaunt giant 260 m tall if it stood (any height you like), its arms and legs far longer than its body: knobs of
elbows and knees, a narrow cage of ribs over a sunken belly, a hunched spine of knobs, a small stone mask of a head
(long and heavy-browed like the heads of Rapa Nui) on a long neck, with a pale light in its eyes. Slabs of
weathered stone on its thin frame, grown over with moss and grass and hung with vines, runes cut in them that glow;
tatters of dark fur; long bony fingers, the index finger longer than the rest. It crawls like a spider over
whatever is under it (the tops of walls), on its hands and feet, its elbows and knees bent high above, its body
slung low between; every hand or foot put down comes down with a thud that shakes the ground, dust rolling off and
stones raining down. It hunts with one finger: holds it over what it wants, its shadow growing on the ground,
slowly presses it down, grinds, lifts, and tries again where they ran. It can rear up and lean on the top of
something high to look over it. Made 2026-10-18 for Warren (its `MazeColossus` crawls over the first ring),
as a creature any game can use: it is only the look, the motion and the sound.

- `creatures/colossus/colossus.gd` (`class_name Colossus`, a `Node3D`): the motion, all procedural (no animations).
- `creatures/colossus/colossus_look.gd` (`class_name ColossusLook`): its shader (the house cel light, stone grain,
  cracks and lichen and fur streaks from two noise textures made in code, a mist of its own over its upper body),
  the eye glints that show through mist, the shadow blots, the dust and the stones.
- `creatures/colossus/models/`: `colossus.glb` (about 33,000 triangles) and `colossus_lo.glb` (11,000), each one
  skinned mesh on 21 bones (the index fingers have their own), one material. The low one also rides the high one's
  skeleton to cast its shadow, and is drawn in its place beyond `lod_distance`.
- `creatures/colossus/tools/build_colossus.py` makes the models in Blender 4.3: a metaball sculpture of the thin,
  knobbly body, roughened and decimated; slabs of stone fitted to it by rays from the bones (curved, broken
  outlines, chamfered rims, cut bands, glowing runes, moss on whatever faces up); bony hands and feet; the mask
  (made full size and shrunk on to its neck); tatters of fur, fringes under the stone, grass, vines.

```
blender --background --python creatures/colossus/tools/build_colossus.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones). Needs nothing else. Global class names: `Colossus`, `ColossusLook`.

## Using it

```gdscript
var giant := Colossus.new()
giant.height = 260.0                  # metres, as it would stand (it is modelled UNITS tall)
add_child(giant)
giant.put(spot, yaw)                  # crouched there, its limbs about it (0 faces +Z)
for limb in 4:                        # HAND_L, HAND_R, FOOT_L, FOOT_R
	giant.plant(limb, where_it_stands(limb))

# Crawling is yours to plan: say where each hand and foot goes, and it does the rest.
giant.step(Colossus.HAND_L, wall_top, yaw, clear)   # lifted over anything up to `clear` m high
giant.facing = yaw                    # its body turns to this, slowly (turn_rate)
giant.planted.connect(func(limb: int, point: Vector3) -> void: ...)

giant.look_at_point = target          # its head turns to it; giant.stoop = 1.0 bends it down to peer
giant.press(target, hall_direction)   # REACH, HOVER, DESCEND, PRESS, LIFT, HOVER again...
giant.press_target = target           # the hovering finger follows this (slowly)
if giant.finger_hits(point, 1.4): ... # while it presses
giant.release()                       # the hand goes back to where it stood
giant.lean_on = wall_top_point        # rear up and look over (INF: get down)
Colossus.rattle(camera, giant.shake_at(camera.global_position))   # every frame
```

- Limbs: `stepping()` (the limb in the air, or -1), `step_progress()`, `step_length()`, `landing(limb)`,
  `landing_yaw(limb)`, `limb_point(limb)` (where it is now), `stance(limb)` (where it stands about its pelvis, for
  planning the next move), `under_limb(limb, point, margin)`, `print_radius(limb)`, `plant(limb, point, yaw)`.
  Signals `lifted(limb, to)` and `planted(limb, point)`.
- The finger: `pressing()`, `press_stage()` (`Colossus.Press`: REACH, HOVER, DESCEND, PRESS, LIFT, RETURN),
  `press_time_of(stage)`, `press_hand()`, `fingertip()`, `press_point()`, `finger_hits(point, radius)`,
  `finger_capsule()` (make a body of it to bump into), `press_along` (the hall's way: the hand goes in edge first).
  Signal `pressed(point)`.
- Where it is: `pelvis()`, `eye()`, `body_yaw()`, `scale_m()`.
- Exports: `height`, `low_poly`, `casts_shadow`, `lod_distance`, `sound`, `volume_db`, `sound_range`, `step_time`,
  `turn_rate`, `hover_height`, `hover_time`, `descend_time`, `press_time`, `lift_time`, `glow`, `lean_rise`.

## How it moves

Its body hangs between where its hands and feet stand, its pelvis behind the middle of them and its back pitched
out level towards its shoulders; each arm and leg reaches its hand or foot with its elbow or knee bent up and out,
spider-like. A lifted limb goes up first and down last and across between; while it comes down a shadow grows dark
where it will land and a rumble rises, then the thud, the dust, a shower of stones and the shaking (`shake_at`). It
sways off the limb it lifts and breathes; its head on its long neck looks about, or at `look_at_point`, and with
`stoop` its shoulders and head come down to peer. To press, the hand on the target's side lifts from where it
stands and goes over the target, the hand edge on along `press_along`, the index finger straight down and the
others curled; it hovers `hover_height` over the target following `press_target`, its shadow on the ground under it,
comes down over `descend_time`, grinds for `press_time` (`pressed`), lifts, and hovers again, until `release()`.
To lean it rears up `lean_rise`, its back nearly upright, its hands on either side of `lean_on`.

The two pale points of its eyes (`ColossusLook.glint_material`) are drawn through the mist from 70 m off.

## Limits

Nothing keeps its limbs out of what they pass through (a lifted arm or a bent knee may go through a wall); plan
moves that do not ask for that. Its fur is not physics. It has no collision of its own: `finger_capsule` is the one
part a game is likely to want solid.

## Sound

`Colossus.thud_sound()` (a deep falling thud, the crack and grind of stone and earth, a rolling tail; 2.6 s) and
`Colossus.rumble_sound()` (a low rumble looped under a limb or the finger as it comes down), both made in code.

## Try it

`example.gd` on a Node3D: one crawls up and down over rows of walls, presses its finger three times at a post
between two of them, and rears up to look over a wall.
