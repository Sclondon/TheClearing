# Wolf

A grey wolf (Canis lupus): big and long-legged, a chest deep and narrow as a keel, big feet, a thick neck in a mane of
long fur, a broad head made broader by its cheek ruff, a long blunt muzzle with a big black nose, shortish thick ears,
amber eyes, and a straight bushy tail hanging to its hocks. Its coat is grizzled grey (banded, black-tipped guard hairs),
a dark saddle over its back and down its tail, black at the tail's tip and on its scent gland, buff legs and backs of
the ears, and a pale cream mask (lips, the sides of the muzzle, the cheeks, a spot over each eye) and underside.
Everything it does is animated in code: no clips. Its howls, woof and growl are made in code too. Made for Warren (its
wolf packs). The component has no thinking.

How it differs from the dog and the coyote on the same bones: bigger than either, heavier in the head and neck, greyer,
with the pale mask and the dark saddle; a tail that hangs straight and is carried by rank; the registering trot; the
howl with the head up and the muzzle rounded (not the dog's nose-to-the-sky bay, not the coyote's yips).

## Needs

GameCommon's `godot/dog`: a wolf is the dog (`Wolf` extends `Dog`, `WolfRig` extends `DogRig`) on a wolf's model, with
the dog's shaders recoloured (`WolfLook` builds on `DogLook`). Global class names: `Wolf`, `WolfRig`, `WolfLook`,
`WolfVoice`.

## Using it

```gdscript
var wolf := Wolf.new()
wolf.variant = 1                   # 0 greyer and slighter (a she-wolf), 1 darker and heavier (a big male), a notched ear
wolf.rank = 0                      # 0 breeding pair (tail and ears high), 1 grown, 2 young or low (lower, a little back)
wolf.scale = Vector3.ONE * Wolf.SCALE  # the model is small: 1.4 is a big grey wolf, about 0.95 m at the withers
add_child(wolf)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match
wolf.hunting = true                # the tireless trot: head low, ears forward, tail straight out
wolf.tracking = true               # sniffing, nose down
wolf.stalking = true; wolf.snarling = true
wolf.look_at_point = target        # it stands and stares (INF: nothing)
wolf.bowing = true                 # a play-bow
wolf.howl_now(2, true)             # a howl (0 .. Wolf.HOWLS - 1), sitting or not; several at once is a chorus
wolf.rally()                       # a short rallying howl
wolf.woof(); wolf.growl()
wolf.lunge(at)                     # the dog's lunge: move it by lunge_push(), test bite_hits(point)
```

- Everything the dog does it does (see godot/dog's README): the four-beat walk, the trot on diagonal pairs, the rotary
  gallop, the stalk, the lunge, the shake, sitting and lying.
- A wolf's carriage over that (`WolfRig`): the trot registers (each hind foot comes down in its forefoot's print, the
  feet drawn in under it as the stride needs, all four on nearly one line); the tail by rank (the pair carry theirs
  higher, up over level when watching), out straight hunting, level at a gallop, up and wagging in a play-bow; the low
  ones' ears a little back; the head low on the hunt; the howl's head up and round "o" of a mouth, opening and closing
  with the voice (`voice_open`); the play-bow down on the forearms.
- **The voice** (`WolfVoice`): five long howls and two short rallies (glides of a nearly pure tone with a few harmonics,
  a slow waver, some with a yodel break; the mouth's opening brightens and dulls it; a little echo), a soft woof and a
  low growl, 16 kHz. Each is made the first time it is wanted, `WolfVoice.BUDGET` samples a frame (a few milliseconds),
  and shared by every wolf after; `WolfVoice.make_now(key)` makes one at once. Howls carry (`sound_range`, 320 m);
  the woof and growl only a few tens of metres.
- **Signals**: the dog's, and `howl_started`, `woofed`, `growled`. **Sound**: `sound` (on), `volume_db`, `sound_range`.
- **Exports**: the dog's (`variant`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, ...) and `rank`.
- **Cost**: about 15 draws a wolf with 2 fur shells and shadows; fewer with `low_poly`. The model is 25k triangles, or
  3.9k low.

## Files

- `wolf.gd` (`Wolf`): what a game drives.
- `wolf_rig.gd` (`WolfRig`): DogRig on the wolf's model, with a wolf's trot, tail, ears, howl and play-bow.
- `wolf_look.gd` (`WolfLook`): the dog's fur shader recoloured. The model paints its markings into the coat's vertex
  colours: red how open the surface is, green how dark, blue how pale, alpha how buff; the shader lays a grizzle of
  banded and black-tipped guard hairs over the rest, more black-tipped where it is darker.
- `wolf_voice.gd` (`WolfVoice`): the howls, woof and growl, made in code.
- `models/wolf_a.glb`, `wolf_b.glb` and their `_lo` versions: built by `tools/build_wolf.py` in Blender 4.3, which uses
  the dog's build (`tools/build_dog.py`, and `tools/build_character.py` from godot/character-controller).
  From the game's root: `blender --background --python creatures/wolf/tools/build_wolf.py [-- <preview folder>]`
- `example.gd`: put it on a Node3D in an empty scene. A pack of four trot in file, sniff, stare, howl together, play-bow,
  hunt and gallop.
