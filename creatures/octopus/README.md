# Octopus

A giant octopus at full size: mantle about 2.5 m, arms 8.4 m. Eight arms, each with two rows of suckers (one near
the crown) shrinking to the tip, the web between them, the lumpy bulbous mantle swelling back behind the head, eyes on
turrets with a horizontal slit pupil, the siphon out of the collar on its right, the dark beak in the mouth. Only the
look, the motion and the sounds: your game moves it and tells each arm what to do. Made for Warren, 2026-10-18 (its
`MazeOctopus` drives it there).

## Needs

GameCommon's `godot/character-controller` (`Toon`, `Settings`). Global classes: `Octopus`, `OctopusArm`,
`OctopusRig`, `OctopusLook`, `OctopusInk` (and `OctopusInk.Blind`), `OctopusPool`, `OctopusDrain`, `OctopusSound`.

## Use

See the comment at the top of `octopus.gd`: `put`, `sunk`, `mouth` / `mouth_out` / `hole_radius`, `feel`, `wind`,
`lash`, `hold`, `rest`, `crawling` + `velocity`, `cut`, `ink`, `mood` (or `reveal`, `flush`, `papillae`, `waves`),
the tones it takes on (`floor_tone`, `wall_tone`, `water_tone`, `water`).

## How it moves

Each arm is a soft chain of 21 points (`OctopusArm`) laid every frame along the path it wants (along the floor to
where it feels, tip curling and uncurling; reared up in an S with its end coiled; straight in a whip; wound round what
it holds; planting ahead as it crawls; coiled down in its hole) and pulled there on springs stiffer at the base, so
the tip lags and whips; kept on the floor except where the ground is open (its pool, the wall behind a drain).
`OctopusRig` sets every bone from those points (suckers turned to the inside of bends and to the floor; stretched
or shortened along the arm: a cut arm regrows as a shorter one).

## Skin

`OctopusLook`: cel shaded and wet. Camouflaged it takes the floor's tone low down, the walls' higher up (an arm up a
wall goes grey), the water's in its pool, mottled, its gloss dulled; papillae rise (vertex displacement); dark clouds
roll over it when agitated; it flushes pale winding up and dark striking.

## Model

`tools/build_octopus.py` (Blender 4.3, run from the game's root):
`blender --background --python creatures/octopus/tools/build_octopus.py [-- <preview folder>]`. One skeleton (body,
head, mantle, siphon, `arm_k_j` k 0-7, j 0-19), two meshes: `octopus` (~76k tris, near) and `octopus_lo` (~5.6k,
beyond 45 m or with `Settings.low_poly`). One draw near (and its shadow); ink, pool, drains one draw each.
Posing one costs about 0.7 ms a frame (do not pose it far off).

## Try it

`example.gd` on a Node3D: in its pool feeling about, a strike at a post, holding and dragging it, ink, out and
crawling, back and down.
