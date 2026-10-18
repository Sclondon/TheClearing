# Insects (Godot 4.7)

Small flying insects as swarms: moths, flies and dragonflies, how they look and how they fly, and nothing about what
they mean in a game. Made 2026-10-18 for Warren (where moths gather round its lights, flies round anything of
meat and wherever someone was caught, and dragonflies hunt over the marsh: `scripts/wildlife/insects.gd` there). No
scenes and no textures: `creatures/insects/insect_swarm.gd` (`class_name InsectSwarm`), `insect_look.gd`
(`InsectLook`: the meshes and materials), `insect.gdshader`, and `models/insects.glb` (the three insects, a few hundred
triangles each) and `models/carcass.glb` (a dead deer for flies to gather on), built in Blender 4.3 by
`tools/build_insects.py` (kept in Warren):

```
blender --background --python creatures/insects/tools/build_insects.py
```

What you get:

- **Moths** (`InsectLook.Kind.MOTH`): a stout furry body with a collar of tufts, feathery feelers combed both sides,
  broad forewings over rounded hindwings. Three kinds (`varieties`, the share of each): a dusty grey-brown moth with
  wavy dark cross-lines and a dark spot, a pale green luna moth with eyespots and long tails, and a death's-head
  hawkmoth, dark above with yellow hindwings banded black and a yellow-and-black abdomen. They flutter round their
  centre (a light) in a loose cloud, each on its own erratic orbit (wide or tight, high or low, either way round),
  lurching off it, now and then blundering straight into the light and bouncing off, backs to the light. Given
  `perches`, some go and rest there with their wings spread flat (on a wall: heads up), and take off when someone
  comes near.
- **Flies** (`FLY`): blowflies, the head nearly all red compound eye, a bristly dark thorax, a round metallic
  blue-green abdomen, clear veined wings that lie swept back over it at rest and are a blur in flight. They buzz round
  their centre (carrion) close in, darting from point to point in short straight hops; a few at a time land on it
  (`perches`, or anywhere on its top) and crawl about in little starts. `land_on_still` of them land on anyone in
  `scarers` who stands still near them for `still_time`, and crawl on his head and shoulders until he moves. `buzz`
  gives them a buzz made in code (a loop of a few wingbeat tones wavering in pitch and swelling past), heard from among
  them.
- **Dragonflies** (`DRAGONFLY`): great blue-green eyes meeting over the head, a striped green-brown thorax, a long thin
  abdomen of ten segments (iridescent blue, black at the joints), four long narrow wings in a fine net of veins with a
  dark spot near each tip. They hunt over their patch (`radius` round the centre, `patrol_height` over it): hover,
  then dart off fast in a straight line, often turning sharply (a right angle, or straight back), hover again; now and
  then one flies to a perch (a reed's tip) and sits with its wings held out flat and drooping a little.

Lit in two flat tones with a hard edge, as the house figures are: hair catches a rim of light, a fly's abdomen and a
dragonfly's shine with the colours of an oil film that shift with the angle, eyes have a glint, light comes through a
clear wing. The wings beat in the vertex shader (each turned about its hinge: up and down, forward and back), so a
swarm is one draw. A clear wing is drawn as a stipple of itself, thinner the faster it beats.

## Putting it in a game

```
sh kit.sh install godot/insects /c/Projects/YourGame
```

```gdscript
var moths := InsectSwarm.new()
moths.kind = InsectLook.Kind.MOTH
moths.count = 20
moths.swarm_seed = 7
moths.follow = lamp                 # they go where it goes (or moths.centre = a point)
moths.radius = 1.2
moths.perches = [Transform3D(wall_basis, point_on_wall)]   # Y out of the surface, Z the way it faces
add_child(moths)
moths.scarers = [player]            # every frame or whenever it changes

var flies := InsectSwarm.new()
flies.kind = InsectLook.Kind.FLY
flies.follow = carcass
flies.wingspan = Vector2(0.022, 0.03)
flies.speed = 3.2
flies.land_on_still = 4
flies.buzz = true
add_child(flies)
add_child(InsectLook.carcass())     # a dead deer to put them on, if you have nothing of your own
```

`example.gd` is a whole scene: moths round a lamp before a wall, flies round a carcass, dragonflies over a pond with
reeds to perch on, and someone walking through them all.

## Talking to it

- `centre` (a point, `Vector3.INF`: this node's place), or `follow` (a Node3D) and `follow_offset` (in its space).
- `perches` (Array of Transform3D, in the world, or in `follow`'s space with `perches_follow`), and `perch_moves`
  (optional Callable(perch, point) -> Vector3: how far a perch has moved, e.g. a reed nodding in the wind).
- `scarers` (nodes): perched ones fly off when one comes within `scare_range` moving, or half of it standing still.
- `active` (off: not drawn or moved at all), `settle()` (every one on a perch at once), `scatter(from)`.
- `running()`, `resting()`, `on_someone()`, `insect_position(i)`, `state_of(i)` (`InsectSwarm.State`), `middle()`,
  `swarm_middle()`; signal `scattered`.
- `frozen` for pictures (not moved; drawn as they were).

## Tuning

Exported: `kind`, `count`, `wingspan` (least, most, metres), `swarm_seed`, `radius`, `spread_height`, `patrol_height`,
`speed`, `flap_rate`, `rest_share`, `rest_time`, `fly_time`, `varieties`, `scare_range`, `land_on_still`, `still_time`,
`scarer_height`, `land_height` (where the top of the carrion is, for flies with no perches), `buzz`, `buzz_volume_db`,
`active_range`. How each kind's wings are hinged and held, and how they beat,
is `InsectLook.WINGS` (the shader's uniforms); the colours and patterns are in the shader.

## Cost

One draw call per swarm (one MultiMesh), no shadow. Further than `active_range` from the camera (or with `active`
off) a swarm is not drawn and does no work at all: a game can put down dozens and pay only for the few in view.
Otherwise every insect is moved each frame in one loop and written to the MultiMesh in one piece: in Warren,
about 0.1 ms a frame for 20-30 insects on a desktop (`cost` and `InsectSwarm.cost_total` say, in microseconds). A
moth is about 750 triangles, a fly 540, a dragonfly 640. Seeded by `swarm_seed`: two machines that make the same swarm
get the same insects (they drift apart in the details, which no one can tell).

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/insects/`
(InsectLook loads the shader and the models from there). The carcass comes in the model's own plain materials (hide,
hide_pale, flesh, bone, hoof): shade it as your game shades things.
