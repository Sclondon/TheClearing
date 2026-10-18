# White-tailed deer

A white-tailed deer: a doe, or a buck with antlers, or (scaled down) a spotted fawn. Lean and long-legged on the real
cervid plan (the elbow tucked up to the chest, the knee forward, the stifle forward, the high hock back, long cannons,
cloven hooves with dewclaws), a deep narrow chest, the neck carried up, big ears, big dark wet eyes that give back the
light. Grey-brown winter coat with the white throat patch, eye ring, nose band, belly and the white under its tail.
Everything it does is animated in code on its own skeleton: no clips. Made for Warren (the herd that watches,
and the peaceful herds in the clearing). The component has no thinking.

`wrong` (0..1) makes one that is not a deer: its legs a little too long, its head turning round further than a neck
should; with `upright` it stands up on its hind legs.

## Using it

```gdscript
var deer := Deer.new()
deer.variant = Deer.Variant.BUCK    # or DOE
deer.fawn = true                    # white spots (scale it down too)
add_child(deer)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match
deer.grazing = true                 # head down, cropping
deer.alert = true                   # frozen, head high, ears swivelling; its eyes shine more
deer.look_at_point = target         # INF for nothing
deer.flagging = true                # tail up, white showing
deer.fleeing = true                 # ears back
deer.pronking = true                # stotting on stiff legs (move it along slowly)
deer.upright = true                 # stood on its hind legs
deer.stamp(); deer.snort()
```

- **Gaits**: a four-beat walk, a trot on diagonal pairs and a bounding gallop. The hind legs drive off together and
  fling out straight behind, it flies stretched out with the forelegs reaching, lands on the forelegs, and the hind
  legs swing forward folded under the belly (after the dog's rig, `godot/dog`). Speed is measured from how it is
  moved, or set `velocity` with `measure_velocity = false`. Scale it: it strides as a bigger deer would.
- **Signals**: `stamped`, `snorted`. With `sound` on it plays them too (made in code: `Deer.snort_sound()`,
  `Deer.stamp_sound()`).
- **Exports**: `variant`, `fawn`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, `wrong`, `measure_velocity`,
  `sound`, `volume_db`.
- **Cost**: about 6 draws with one fur shell and shadows (3 surfaces: coat, mane (unused on a deer), parts); 4 with
  `low_poly`. The doe is 29k triangles, 3.6k low; the buck 32k, 4.2k low.

## Files

- `deer.gd` (`Deer`): what a game drives.
- `deer_rig.gd` (`DeerRig`): poses the skeleton every frame (deer and elk alike).
- `deer_look.gd` (`DeerLook`): three shaders: a sleek coat (banded light, shells, dark and pale markings and fawn
  spots from vertex colours), a mane that sways (the elk's), and vertex-coloured parts (eyes with a bar pupil and
  eyeshine, nose, hooves, antlers).
- `models/deer_doe.glb`, `deer_buck.glb` and their `_lo` versions: built by `creatures/deer/tools/build_deer.py` in
  Blender 4.3 (which also builds the elk), using `tools/build_character.py` from `godot/character-controller`.
  Run it from the game's root: `blender --background --python creatures/deer/tools/build_deer.py`
- `example.gd`: put it on a Node3D in an empty scene. A doe, a buck, a fawn and a wrong one go through every move.

Needs nothing else at run time (no textures, no other components).
