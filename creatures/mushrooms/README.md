# Mushrooms

Mushrooms, a lot of them for very little, for Godot 4.7 (GL Compatibility): tufts of honey fungus, bracket fungi in
shelves up a wall, tall pale bonnets that glow in the dark (foxfire), and giant puffballs that puff a cloud of spores
when trodden near. Each kind is one MultiMesh (one draw), drawn only near. Made for Warren (`MazeMushrooms` there).

- `MushroomPatch`: `tuft(at, rng)`, `shelves(foot, wall_normal, rng)`, `bonnets(at, rng)`, `add_puffball(at, size)`,
  `build()`, `puff(index)` (it squashes; `puffed(at, size)`; a soft cough), `regrow(index, seconds)`, `ripe(index)`.
- `SporeCloud`: `puff(at, size)`: olive-brown dust billowing out and settling (one MultiMesh of camera-facing
  puffs); `density_at(point)` 0..1, for what it does to you.
- `SporeVeil`: the screen blurred, greyed and dusty at its edges while breathing spores:
  `SporeVeil.report(tree, by, thickness)` each frame. Under the HUD (canvas layer -1); hidden while clear.
- `MushroomLook`: their shader (vertex colours, cel shaded, glow by `MushroomLook.set_night(0..1)`, squash and sway
  by MultiMesh custom data), their meshes, and the mushroom zombies' growths.

Needs GameCommon's `godot/character-controller` (Toon, Settings). (In GL Compatibility a MultiMesh loses its vertex
colours unless it has instance colours: `MushroomPatch.build` sets them white.)

## Model

`tools/build_mushrooms.py` builds `models/mushrooms.glb` (honey, bracket, stalk, puffball, ~300 triangles each) and
`growths.glb` (crown, shoulder, back, mat: what bursts out of a mushroom zombie), and their `_lo`:

    blender --background --python creatures/mushrooms/tools/build_mushrooms.py

## Try it

`example.gd` on a Node3D: a wall of them, three puffballs a post walks up to and puffs, day going to night.
