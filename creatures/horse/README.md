# Horse

A feral horse that has been out a long time (about 15 hands): a little thin (the points of the hips and the ribs
show), its mane long and tangled down the right side of its neck, a forelock to its eyes, a tail nearly to its
fetlocks, matted and burred. Muted coats for a near-colourless world: a dappled grey, a dun (black points and a
dorsal stripe), a dark bay. With `haltered`, an old rope halter and a frayed end of lead rope. Everything it does is
animated in code on its own skeleton: no clips. Made for Warren (the lonely horses). No thinking.

## Using it

```gdscript
var horse := Horse.new()
horse.coat = Horse.Coat.GREY      # GREY, DUN, BAY
horse.haltered = true
add_child(horse)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots, canters or gallops to match
horse.grazing = true              # neck right down, muzzle on the ground, jaw working
horse.alert = true                # head high, ears pricked; look_at_point turns head and ears to it
horse.dozing = true               # a hind leg rested, head low, ears out to the sides
horse.friendly = true             # head low and soft
horse.fleeing = true              # ears pinned back, neck stretched (gallop with it)
horse.spooked = true              # head and tail up, eyes shining
horse.whinny(); horse.nicker(); horse.snort(); horse.stamp()
horse.shake(); horse.roll()       # roll: about 9 s, down, over, up; shaking(), rolling()
horse.twitch(point)               # the skin shivers there
horse.seat()                      # where a rider would sit (world Transform3D)
```

- **Gaits**, each on its true footfalls: a four-beat walk in the lateral sequence (hind left, fore left, hind right,
  fore right) with the head nodding twice a stride; a two-beat trot on diagonal pairs with a moment of flight; a
  three-beat canter (outside hind, inside hind with outside fore, the leading fore, then flight) that rocks the
  forehand; a four-beat transverse gallop with a long gathered flight. Lead chosen at random (mirrored).
  Speed is measured from how it is moved, or set `velocity` with `measure_velocity = false`.
- **Signals**: `stamped`, `snorted`, `whinnied`; the rig's `footfall(leg)`. With `sound` on it makes the sounds:
  the whinny (a squeal breaking into a long shuddering fall, ending low), nicker, snort, stamp and hoofbeats, all
  made in code.
- **Exports**: `coat`, `haltered`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, `measure_velocity`, `sound`,
  `volume_db`.
- **Cost**: about 13 draws in the studio with one fur shell and shadows (3 surfaces); fewer with `low_poly`. 60k
  triangles (the mane and tail are half of it), 5k low.

## Files

- `horse.gd` (`Horse`): what a game drives, and its sounds.
- `horse_rig.gd` (`HorseRig`): poses the skeleton every frame (after the deer's DeerRig).
- `horse_look.gd` (`HorseLook`): coat (with dapples and the skin twitch), mane and parts shaders.
- `models/horse.glb`, `horse_haltered.glb` and their `_lo` versions: built by `creatures/horse/tools/build_horse.py`
  in Blender 4.3, which uses the deer's `creatures/deer/tools/build_deer.py` (so `godot/deer` must be installed to
  build them, not to run them): `blender --background --python creatures/horse/tools/build_horse.py`
- `example.gd`: put it on a Node3D in an empty scene. Three horses go through every gait and move.
