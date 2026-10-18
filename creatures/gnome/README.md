# Gnome: an old folk-tale gnome that freezes like a garden ornament, creeps, snatches and runs (Godot 4.7)

Knee-high, old and stooped: a big head, a heavy bulbous nose, little wet-bead eyes sunk under bushy grey brows, long
drooping ears, deeply wrinkled leathery skin; a long matted grey beard and a drooping moustache; a tall faded pointed
hat whose tip flops and swings; a worn coat belted over a paunch, skirts to the knee; pointed boots. Faded colours, no
bright ones: eerie rather than sweet. Made 2026-10-18 for Warren (its thieving gnome bands), as a creature any game can
use: only the look, the motion and its voice.

- `gnome.gd` (`class_name Gnome`, a `Node3D`): the motion, all procedural, and its sounds (giggle, whisper, squeal,
  the patter of its feet), made in code.
- `gnome_look.gd` (`GnomeLook`): its cel shader (wrinkles, coat weave, beard strands); each gnome's hat and coat a
  faded colour of its own.
- `gnome_hollow.gd` (`GnomeHollow`): where they live: a little door ajar on the dark at the foot of a wall, an arch of
  stones, dug earth, trailing roots; one mesh built in code. `mouth()`, `hoard_spot(k)`.
- `gnome_rope.gd` (`GnomeRope`): an old rope between two points, taut or slack (one small mesh).
- `models/`: `gnome.glb` (about 15,000 vertices) and `gnome_lo.glb` (4,000). One draw per gnome.
- `tools/build_gnome.py` builds them in Blender 4.3 round the skeleton `tools/rest_joints.gd` writes from Gnome:

```
godot --headless --audio-driver Dummy --path . -s res://creatures/gnome/tools/rest_joints.gd
blender --background --python creatures/gnome/tools/build_gnome.py [-- <folder for previews>]
```

## Using it

```gdscript
var gnome := Gnome.new()
add_child(gnome)
gnome.global_position = where          # move it; it works out its gait (walk, `creeping` tiptoe, scurry)
gnome.rotation.y = heading
gnome.frozen = true                    # held exactly as it is, mid-stride, costing nothing, until let go
gnome.still = Gnome.Still.HUSH         # CLASP, HUSH, PEER, POINT: what it stands in, still
gnome.snatch()                         # a quick grab up and forward; snatch_reached()
gnome.carrying = true                  # hugging something: put it at carry_point()
gnome.hauling = true                   # leaning back on a rope: rope_point()
gnome.giggle(); gnome.whisper(); gnome.squeal()
gnome.tumbling = true; gnome.pattering = true
```

Set `size` (metres per unit: its crown is 0.86 units up, its hat tip 1.4) and `seed_value` before it enters the tree;
`voice` off for silence. Hide it or disable processing when far. `example.gd` runs a few through all of it.
