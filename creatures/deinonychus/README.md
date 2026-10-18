# Deinonychus

A pack-hunting dromaeosaur, *Deinonychus antirrhopus*, as the bones and its living relatives say it was, not the film
raptor: about 3.3 m from snout to tail tip and hip-high to a man, most of that a stiff tail held straight out behind for
balance. A deep narrow body, an S of a neck, a long narrow skull with a big gold eye and lips over its teeth (they show
only when it gapes). Fully feathered: a coat of contour feathers, dark grey-brown with a dark mask through the eye, a
paler throat and belly and a barred tail; the snout, the lower shins and the feet bare and scaly. The arms are folded
wings of long barred flight feathers (primaries on the hand, secondaries on the forearm), the palms facing in (it cannot
turn them down), three long clawed fingers free of the feathers; a fan of long feathers spreads flat either side of the
end of the tail. It walks on two toes of each foot (two-toed tracks), the second toe held up off the ground with its
great sickle claw; a little dewclaw behind. Toon-shaded (hard light bands). Everything it does is animated in code on
its own skeleton: no clips. Its calls are made in code. Made for Warren (the maze game: its deinonychus packs). The
component has no thinking.

## Using it

```gdscript
var dino := Deinonychus.new()     # life size
dino.tint = Color(1.0, 0.95, 0.9) # one a little browner or greyer than the next
add_child(dino)
# each frame: move it (position, rotation.y; it faces +Z) and it walks or runs to match (and brakes, stopping hard)
dino.look_at_point = target   # its head snaps round to it (INF: it looks about)
dino.cocking = true           # cocks its head to look with one eye
dino.crouching = true         # low and long, stalking
dino.tired = true             # panting, jaw open
dino.hoot(1.0); dino.click(); dino.hiss()
dino.pounce()                 # the wind-up (crouch, tail flicking, a hiss), then `leapt`: move it through the air
                              # (grounded = false) for LEAP_TIME, then pin() if it landed on something, or stumble()
if dino.claws_hit(their_chest): ...
```

- **Gaits**: a walk (the body vaulting over the planted leg and swaying over it, the head held still in the air and
  then thrust forward: a bird's head-bob) and a run (a flight between steps, the feet put down near the midline, the
  body low and level). It leans into turns with the tail swinging out to balance it, and brakes sat back on its legs
  with the tail up. Speed is measured from how it is moved, or set `velocity` with `measure_velocity = false`.
- **The head** snaps from pose to pose and holds there, as a bird's does; watching something it cocks it now and then.
- **The pounce**: the crouch, the leap (legs swung forward, sickle claws out ahead and down, wings thrown open), the pin
  (feet driving down, head down, wings spread and beating to keep its balance on top of what it caught, as hawks do and
  as Fowler et al. (2011) suggest dromaeosaurs did), or a stumble.
- **Signals**: `hooted`, `clicked`, `hissed`, `leapt`, `footfall(at, weight)`.
- **Sounds**, made in code when first needed (`sound`): a booming closed-mouth hoot (`voice` sets its pitch, `hoot`'s
  argument raises or lowers it: an answer is higher), clicks of the jaws, a hiss, running feet. Run tests with
  `--audio-driver Dummy`.
- **Exports**: `low_poly` (the demade model, no feather shells), `plume_shells`, `tint`, `eyeshine`,
  `measure_velocity`, `sound`, `volume_db`, `sound_range`, `voice`.
- **Cost**: 3 surfaces (coat, feathers, parts) plus 2 shells of the coat (drawn only at its outline): about 9 draws with
  shadows, fewer with `low_poly`. Posing one takes about 0.06 ms on a desktop. The model is about 9.7k triangles, or
  4k low.

## Files

- `deinonychus.gd` (`Deinonychus`): what a game drives; its calls.
- `deinonychus_rig.gd` (`DeinonychusRig`): poses the skeleton every frame (the two-legged gait with IK, the stiff
  tail, the bird's head, the jaw, the wings, the sickle claws, the pounce and the pin).
- `deinonychus_look.gd` (`DeinonychusLook`): three shaders. Contour feathers in soft rows along their lie, with fine
  barb streaks and shells that fringe the outline; bare scaly skin where the vertex colours' alpha says; the vanes of
  wings and tail, barred, seen from both sides; vertex-coloured parts (eyes with a round pupil, claws, scales, mouth,
  teeth). The coat's vertex colours: red how open, green how dark its markings, blue how pale, alpha how feathered.
- `models/deinonychus.glb` and `deinonychus_lo.glb`: built by `tools/build_deinonychus.py` in Blender 4.3, which uses
  `tools/build_character.py` from `godot/character-controller`. Run it from the game's root:
  `blender --background --python creatures/deinonychus/tools/build_deinonychus.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A pack of three goes through every move.

Needs nothing else at run time (no textures, no other components).
