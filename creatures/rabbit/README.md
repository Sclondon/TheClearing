# Rabbits, hares and jackalopes (Godot 4.7)

The European rabbit, the brown hare and the jackalope, and the rabbits' warrens: how they look and every move they
make, and nothing about what they mean in a game. Made 2026-10-18 for Warren (its colonies at their warrens, the hares
in the open, the jackalope; there the thinking is in `scripts/enemies/maze_rabbit.gd`, `maze_hare.gd` and
`maze_jackalope.gd`). The component has no thinking.

- **Rabbit** (`Rabbit.Variant.RABBIT`): small, round and hunched, grey-brown agouti fur ticked pale and dark, a pale
  belly, chin and eye ring, big dark eyes high at the sides of a round head, a blunt muzzle with a split upper lip
  under a nose that twitches, ears rimmed dark, and the scut: dark on top, white beneath.
- **Hare** (`HARE`): half as big again, lean and long-legged, tawny, long ears with black tips, a black-topped tail, big
  amber eyes.
- **Jackalope** (`JACKALOPE`): a hare, greyer, with a pair of small polished antlers (a roe buck's: a tine forward, one
  back, a fork at the top, dark and ridged at the burr, ivory at the points) rising from in front of its ears. Its eyes
  give back a green light, too much of it; watching, it holds its head stock still, turns it further round than a hare
  could, and its nose does not twitch.

All built on a leporid's anatomy: short forelegs nearly straight under the chest; the long hind legs folded in a Z,
the stifle forward under the haunch, the very long hind foot flat on the ground from hock to toe at rest.

## Using it

```gdscript
var rabbit := Rabbit.new()
rabbit.variant = Rabbit.Variant.HARE   # RABBIT, HARE or JACKALOPE
add_child(rabbit)
# each frame: move it (position, rotation.y; it faces +Z) and it sits, hops or bounds to match
rabbit.grazing = true        # crouched, head down to the grass, nibbling
rabbit.alert = true          # head up, ears up and forward, turning to listen
rabbit.upright = true        # sat up on its haunches, forepaws at its chest, looking
rabbit.washing = true        # sat up, forepaws drawn down over its face
rabbit.flattened = true      # pressed flat, ears along its back (a hare in its form)
rabbit.fleeing = true        # ears back
rabbit.flagging = true       # scut held up, white to whatever is behind
rabbit.boxing = true         # stood up tall, striking with its forepaws
rabbit.lowered = true        # head down (a jackalope's antlers forward, to charge)
rabbit.look_at_point = target  # INF for nothing
rabbit.thump(); rabbit.grunt()

var warren := RabbitWarren.new()
warren.kind = RabbitWarren.Kind.BANK   # MOUND: a hummock; BANK: against the foot of a wall (its back along local X)
add_child(warren)
warren.mouth(i); warren.deep(i); warren.way_in(i); warren.nearest_hole(point)  # send them in and out
```

- **Gaits**: still, it sits hunched; slowly, the leporid's hop (the forefeet forward one and then the other, the back
  arching as the hind feet come up together beside them); fast, the bound (the hind feet drive off together up on
  their toes, it flies stretched out, lands on one forefoot and the other, and the hind feet swing forward outside
  them to land ahead of where the forefeet came down). Speed is measured from how it is moved, or set `velocity` with
  `measure_velocity = false`. Scale it: it strides as a bigger one would.
- **Down a hole**: move it from `mouth(i)` to `deep(i)` (a third of a second) and hide it; the tunnel hides it on the
  way in.
- **Signals**: `thumped`, `grunted`. With `sound` on it plays them (made in code: `Rabbit.thump_sound()`, a deep
  double knock; `Rabbit.grunt_sound()`, a low growl).
- **Exports**: `variant`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, `measure_velocity`, `sound`,
  `volume_db`; the rig's `pose_every` poses it only every so many frames, for one far off.
- **Cost**: 2 surfaces (coat with one fur shell, parts): about 3 draws and its shadow. The rabbit is 7.9k triangles,
  2.3k low; the hare 8.7k / 2.3k; the jackalope 10.1k / 2.7k. Posing one takes about 55 microseconds a frame on a
  desktop. A warren is one draw (the mound 15k triangles, 2.9k low), its ground a trimesh made once for each kind.

## Files

- `rabbit.gd` (`Rabbit`): what a game drives.
- `rabbit_rig.gd` (`RabbitRig`): poses the skeleton every frame.
- `rabbit_look.gd` (`RabbitLook`): the shaders: soft agouti fur (banded light, shells, the dark, pale and black of
  its markings from vertex colours), vertex-coloured parts (eyes with a round pupil and eyeshine, nose, claws, teeth,
  ear linings, antlers), and a warren's earth.
- `rabbit_warren.gd` (`RabbitWarren`): a warren, its holes and its ground.
- `models/rabbit.glb`, `hare.glb`, `jackalope.glb`, `warren_mound.glb`, `warren_bank.glb` and their `_lo` versions:
  built by `tools/build_rabbit.py` in Blender 4.3, using `tools/build_character.py` from `godot/character-controller`
  (the game's `tools/`). Run it from the game's root:
  `blender --background --python creatures/rabbit/tools/build_rabbit.py [-- <preview folder> [names]]`
- `example.gd`: put it on a Node3D in an empty scene. A rabbit, a hare and a jackalope go through every move, and the
  rabbit goes down a hole.

Needs nothing else at run time (no textures, no other components). The files must sit at `res://creatures/rabbit/`.
