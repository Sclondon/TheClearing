# Coyote

A coyote: lean and rangy, long in the leg, a deep narrow chest and small neat feet, a ruff of thick fur round its neck
and cheeks, a narrow head with a long pointed muzzle, big upright pointed ears and yellow eyes, and a bushy black-tipped
tail carried low. Its coat is grizzled grey and tan (banded guard hairs, some tipped black), darker down the back,
tawny on the legs, the backs of the ears and the muzzle, cream under the jaw, down the throat and chest and under the
belly, with a dark line down the front of each foreleg. Everything it does is animated in code: no clips. Its yips and
howls are made in code too. Made for The Clearing (its skittish coyote packs, and the skinwalker that hides among
them). The component has no thinking.

## Needs

GameCommon's `godot/dog`: a coyote is the dog (`Coyote` extends `Dog`, `CoyoteRig` extends `DogRig`) on a coyote's
model, with the dog's shaders recoloured (`CoyoteLook` builds on `DogLook`). Global class names: `Coyote`,
`CoyoteRig`, `CoyoteLook`.

## Using it

```gdscript
var coyote := Coyote.new()
coyote.variant = 0                # 0 greyer, 1 redder and slighter, a notch out of one ear
coyote.scale = Vector3.ONE * 0.82 # modelled at a big dog's size: 0.82 is a coyote's
add_child(coyote)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match
coyote.slinking = true            # low, ears flat, tail tucked, glancing back over its shoulder
coyote.tracking = true            # nose down
coyote.stalking = true; coyote.snarling = true
coyote.look_at_point = target     # it stands and stares (INF: nothing)
coyote.yip()                      # one sharp yip
coyote.chorus(0, false)           # a run of yips up into a wavering howl and back (variant 0..2; sitting or not)
coyote.hush()                     # stops one
coyote.lunge(at)                  # the dog's lunge: move it by lunge_push(), test bite_hits(point)
```

- Everything the dog does it does (see godot/dog's README): the four-beat walk, the trot on diagonal pairs (a
  coyote's loping trot), the rotary gallop (legs fully gathered and stretched, two flights a stride), the howl, the
  lunge, the shake, sitting and lying.
- A coyote's carriage over that (`CoyoteRig`): the tail hangs low behind its hocks, comes up level on a trail or
  stalking, streams out level at a gallop (never up), and is tucked between its legs slinking; slinking it does not
  raise its hackles.
- **Signals**: the dog's, and `yipped`, `chorused`. **Sound**: `sound` (on), `volume_db`, `sound_range`. Three
  choruses (`Coyote.CHORUSES`): several coyotes each doing their own at once is a pack's chorus.
- **Exports**: the dog's (`variant`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, ...).
- **Cost**: about 15 draws a coyote with 2 fur shells and shadows; fewer with `low_poly`. The model is 24k triangles,
  or 3.7k low.

## Files

- `coyote.gd` (`Coyote`): what a game drives, and its voice.
- `coyote_rig.gd` (`CoyoteRig`): DogRig on the coyote's model, with a coyote's tail, slink and yip.
- `coyote_look.gd` (`CoyoteLook`): the dog's fur shader recoloured. The model paints its markings into the coat's
  vertex colours: red how open the surface is, green how dark, blue how pale, alpha how tawny; the shader lays a
  grizzle of banded and black-tipped guard hairs over the rest.
- `models/coyote_a.glb`, `coyote_b.glb` and their `_lo` versions: built by `tools/build_coyote.py` in Blender 4.3,
  which uses the dog's build (`tools/build_dog.py`, and `tools/build_character.py` from godot/character-controller).
  From the game's root: `blender --background --python creatures/coyote/tools/build_coyote.py [-- <preview folder>]`
- `example.gd`: put it on a Node3D in an empty scene. A pack of three trot, sniff, stare, chorus, slink, gallop and sit.
