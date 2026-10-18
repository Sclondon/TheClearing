# Harpy (Godot 4.7)

The harpy of the old stories, starved, for a game in Inside's overcast dread. A gaunt, wasted woman's head and trunk:
collarbones and ribs standing out under ashen, filthy skin, a sunken belly, a corded neck, a long skull with hollow
temples and cheeks, small milky eyes deep in their sockets, and a lipless mouth far too wide, cut from under one
cheekbone to the other, its jaw dropping open on crowded teeth. Lank wet black hair hangs from the crown over most of
the face and down to the chest. Where her arms should be are great ragged grey-black wings built as a bird's are; from
the lower ribs down she is a bird, with feathered thighs and bare scaly raptor legs and long hooked talons. Made
2026-10-18 for The Clearing (where she perches on the maze's walls and swoops: `scripts/enemies/maze_harpy.gd`
there). It is only the look, the motion and the sound: it does no thinking.

- `creatures/harpy/harpy.gd` (`class_name Harpy`, a `Node3D`): the motion, posed bone by bone in code (no
  animations), and its sounds, made in code.
- `creatures/harpy/harpy_look.gd` (`class_name HarpyLook`): its shader.
- `creatures/harpy/models/harpy.glb`: two skinned meshes on one skeleton, `harpy` (about 56,000 triangles) and
  `harpy_lo` (about 20,000), built in Blender 4.3 by `tools/build_harpy.py` (in The Clearing's copy, and beside this
  README in GameCommon):

```
blender --background --python creatures/harpy/tools/build_harpy.py [-- <folder for preview renders>]
```

## The model

- **Skin**: a signed distance field (ellipsoids and capsules joined smoothly: ribs, collarbones, the breastbone,
  spine and shoulder blades as thin capsules so they stand out; eye sockets, temples, cheeks and belly cut away),
  polygonised, decimated and put back on the surface; normals from the field, its hollows baked into the vertex
  colour's alpha. The head is its own finer field; the mouth is cut in it as a slit, the lips carried by head and jaw.
- **Wings**, a bird's: humerus, forearm, hand and finger; ten primaries on the hand and finger (each its own bone; the
  outer five emarginated, so the spread wing ends in fingers), twelve secondaries and tertials (in four bones),
  humeral feathers, greater, median, lesser and marginal coverts, under-wing coverts, an alula, scapulars. At the
  wrist, three bony fingers with hooked black claws. Moulting: a gap with a pin feather in one wing, a broken primary
  and a missing secondary in the other, notched and ragged edges throughout.
- **Body**: contour feathers rooted on the skin below the ribs, a ruff over the shoulders, long ragged "trousers" on
  the thighs and shins, bare patches; small shingled coverts drawn by the shader on the skin under them. A tail of
  twelve feathers that spreads. Scaly tarsi, three toes forward and one back, curved talons.
- **Hair**: about 170 wet clumps hung from the scalp, falling under gravity and pushed out of the skin as they fall;
  swung by six bones that hang and stream in the wind of her flight.

## Using it

```gdscript
var harpy := Harpy.new()
harpy.scale = Vector3.ONE * 1.15           # about 1.75 m standing, 4 m across the wings at 1
add_child(harpy)
# Its origin is its middle. On a perch, put it stand_height() above the ledge; it sets its feet on it.
harpy.global_position = ledge + Vector3.UP * harpy.stand_height()
harpy.perched = true                        # false: flying
# each frame, whatever drives it moves it (it faces +Z) and says what it is doing:
harpy.effort = 0.8                          # 0 glide .. 1 beating hard
harpy.brake = 0.0                           # hover, land: strokes forward, body upright
harpy.stoop = 0.0                           # wings tucked back for a dive
harpy.talons = 0.0                          # legs thrown forward, toes open, wings flared: land, strike
harpy.grip = 0.0                            # toes closed
harpy.mantle = 0.0                          # perched: wings half spread and draped forward
harpy.aim = player.global_position          # what it looks at (INF: ahead)
harpy.screech()                             # head out, jaw dropped, wings up, the screech; `screeched` at the top
harpy.cry()                                 # a shorter falling call (as it dives)
if ... harpy.talon_points() ...             # where its eight talons are (world), for catching
```

- **Flight**, after slow-motion film of eagles and vultures. Downstroke: the wing straight and spread, swept a little
  forward, the leading edge pressed down, the primaries fanned into fingers and bent up at the tips. Upstroke: elbow
  and wrist bend so the wing folds half shut at the wrist, drawn up and back close to the body, the primaries closed
  and turned edge on, the hand trailing; at the top it flicks open. Wings are posed as a bird's (body level), tipped
  onto her upright trunk: level with the world in flight, down her back on a perch. It pitches with its climb and
  banks into turns (from how it is moved).
- **Perched**: hunched, head low between raised shoulders, wings folded down her back with the primaries crossed over
  the tail, toes gripping; `mantle` spreads and drapes them forward like a cloak.
- **Signals**: `beat` (each wingbeat), `screeched`. Plays its own sounds (`sound`, `volume_db`, `sound_range`).
- **For pictures and tests**: `frozen = true`, then `hold(state, phase, call)` poses it exactly.
- **Exports**: `sound`, `volume_db`, `sound_range`, `lod_distance` (beyond it the low mesh), `seed_value`. Static
  `Harpy.low_poly` makes every harpy use the low mesh (phones).

## Sound

Made in code, nothing to load: `screech_sound()` (2 s: a rasping breath in, a shrill strained voice that cracks
upward, wavers and is chopped into a raptor's stuttering kek-kek, over a wet rattle that is all that is left at the
end), `cry_sound()` (0.9 s, a high ragged scream falling away), `beat_sound()` (the soft heavy whump of a wingbeat).

## Cost

One draw (and its shadow) for whichever mesh is shown; about 80 bones posed every frame. Hide it or set
`process_mode` disabled when it is far from everyone.

## What it needs

Nothing else: no autoloads, input actions or other components. The files must sit at `res://creatures/harpy/`.
`example.gd` is a whole scene: a block to perch on, a post, and the harpy going through everything, round and round.
