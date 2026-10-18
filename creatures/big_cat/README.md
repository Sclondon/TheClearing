# Big cats

Two cats on one rig. **The lynx** (Eurasian): long-legged and short-bodied, the rump a little high, huge furry paws,
a short black-tipped bob of a tail, a flaring barred ruff, tall ears with long black tufts; spotted grey-brown, cream
below, white round the mouth and eyes. **The panther** (a melanistic leopard): long and low, heavy in the shoulder,
short thick legs, a long thick tail carried low with its end curled up, a broad round head, small round ears; black,
the leopard's rosettes there in the black where the light falls (darker, and without the coat's sheen), and
green-gold eyes that give the light back. Everything they do is animated in code: no clips. Their hiss, growl and
snarl are made in code too. Made for Warren (its lynx and black panthers). The component has no thinking.

## Needs

GameCommon's `godot/dog`: a big cat is the dog's rig on a cat's model (`BigCat` extends `Dog`, `BigCatRig` extends
`DogRig`), with the dog's fur shader given a cat's markings (`BigCatLook` builds on `DogLook`). Global class names:
`BigCat`, `BigCatRig`, `BigCatLook`.

## Using it

```gdscript
var cat := BigCat.new()
cat.kind = BigCat.Kind.PANTHER     # or LYNX
add_child(cat)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops (a bound) to match
cat.look_at_point = target          # its head (and eyes) on it; INF for nothing
cat.stalking = true                 # low, shoulders up, head level, slow steps; cat.freeze_step: a forepaw held up
cat.crouching = true                # flat in ambush, tail tip flicking
cat.feeding = true                  # crouched over a kill, tearing
cat.lashing = true; cat.wary = true # tail lashing; ears back
cat.climbing = true                 # turn it +Z up (or down) a wall, its back out from it; it bounds, its tail hangs
cat.hiss(); cat.growl(2.0)
cat.pounce(at)                      # wiggle (BigCat.WIGGLE_TIME, the warning), then the spring; pounce(at, false) from a run
cat.global_position += cat.lunge_push() * delta   # each frame while it springs
if cat.pounce_hits(their_chest): ...
cat.swipe(at)                       # a forepaw raised and slashed; swipe_hits(point) as it strikes
cat.set_eyeshine(3.0)               # at night: past ~1, two glows over its eyes, a few pixels at any distance
```

- **Gaits** (the dog's, at a cat's size): a four-beat walk, a trot, and the gallop with the back gathering and
  stretching, two flights a stride. `sitting` and `lying` are the dog's.
- **The tail**: the panther's hangs low with its end curled up, held out straight stalking, flat behind crouched,
  the end twitching whenever it watches something, lashing when it is keyed up, streaming out at a gallop, curled to
  its side sitting. The lynx's bob droops and flicks up, showing its black end.
- **The ears**: forward on what it watches, swivelled about at ease, back when wary or running, flat out sideways
  to hiss or strike.
- **Signals**: the dog's, and `hissed`, `growled`, `pounce_begun(at)`, `swiped(at)`. **Sound**: `sound` (on),
  `volume_db`, `sound_range`.
- **Exports**: `kind`, the dog's (`low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, `lunge_reach`, ...).
- **Cost**: 4 draws a cat with 2 fur shells (coat and its shells, parts), plus shadows; 2 with `low_poly`; 2 more
  for the eye glows when they are lit. The models are 18k (lynx) and 20k (panther) triangles, 2.8k and 2.5k low.

## Files

- `big_cat.gd` (`BigCat`): what a game drives, and its voice.
- `big_cat_rig.gd` (`BigCatRig`): DogRig on the cat's model, with a cat's stalk, crouch, wiggle, pounce, swipe,
  hiss, feeding, climbing, tail and ears; the eye glows.
- `big_cat_look.gd` (`BigCatLook`): the dog's fur shader with spots and rosettes worked out from the coat's texture
  coordinates, and its vertex colours (red open, green dark markings, blue pale, alpha spots: below a half solid,
  above rosettes).
- `models/lynx.glb`, `panther.glb` and their `_lo` versions: built by `tools/build_big_cat.py` in Blender 4.3, which
  uses the dog's build (`tools/build_dog.py`, and `tools/build_character.py` from godot/character-controller).
  From the game's root: `blender --background --python creatures/big_cat/tools/build_big_cat.py [-- <preview folder> [lynx|panther]]`
- `example.gd`: put it on a Node3D in an empty scene. A lynx and a panther go through every move.
