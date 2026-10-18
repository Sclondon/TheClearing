# Gargoyle (Godot 4.7)

A carved-stone grotesque that is alive. Hunched and heavily muscled, the head thrust low between a great hump of
shoulders; a snarling beast's face (a heavy scowling brow over deep-set eyes, a short wrinkled muzzle with flared
nostrils, the upper lip drawn back from two long fangs, an underslung jaw with two tusks jutting up in front of it,
pointed ears swept back, two ribbed horns curving back over the skull, spikes on the cheeks and chin); long arms
with big clawed hands; crouched, long-footed legs with taloned toes; a ridge of spikes down its back; a long tail
with a barbed spade; and two bat wings that are hands, as a bat's are: an upper arm, a forearm, a clawed thumb at
the wrist, and four long fingers (digits 2 to 5, each a metacarpal and a phalanx) with stone skin stretched between
them, scalloped between the fingertips. About 1.9 m tall crouched, 5.2 m from wingtip to wingtip.

All of it is weathered cast stone: the grain of real concrete, darker and mossy in every hollow, rain stains, pale
chips where it has been knocked, and a crazing of hairline cracks. As a statue it is lit like the walls round it
and cannot be told from a carving. Alive, an ember glows faintly deep in its cracks (spreading out from its heart
as it wakes, brighter while it strains) and in its eyes; stone grinds as it moves and dust sheds off it.

Made 2026-10-18 for Warren (its gargoyles: `scripts/enemies/maze_gargoyle.gd` there). It is only the look,
the motion and the sound: it does no thinking.

- `creatures/gargoyle/gargoyle.gd` (`class_name Gargoyle`, a `Node3D`): the motion, all posed in code (no
  animations), its sounds (made in code) and dust.
- `creatures/gargoyle/gargoyle_look.gd` (`GargoyleLook`): its stone shader.
- `creatures/gargoyle/gargoyle_rest.gd` (`GargoyleRest`): where each bone stands in the model (written by the build).
- `creatures/gargoyle/models/gargoyle.glb` (about 38,000 vertices) and `gargoyle_lo.glb` (13,000) for phones
  (`low_poly`, or `Gargoyle.low_poly_all` for every one). One skinned mesh, one material: one draw, and its shadow.
- `creatures/gargoyle/textures/gargoyle_stone.png`: the stone's grain, 512 px, from Poly Haven's
  [concrete_wall_007](https://polyhaven.com/a/concrete_wall_007) (CC0; Charlotte Baglioni, Dario Barresi, Rico
  Cilliers), the concrete of Warren's walls.
- `creatures/gargoyle/tools/build_gargoyle.py` builds the models in Blender 4.3 (15 seconds):

```
blender --background --python creatures/gargoyle/tools/build_gargoyle.py [-- <folder for previews>] [--quick]
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var gargoyle := Gargoyle.new()
add_child(gargoyle)
gargoyle.global_position = ledge_point        # its origin on the ledge, near the front edge
gargoyle.rotation.y = facing_out              # it faces +Z
gargoyle.perched = true                       # squatting, hands on the edge, wings raised behind
gargoyle.settle()                             # a statue (`alive` is false)

# Every frame, whatever drives it just moves it and says what it is doing:
gargoyle.global_position = where              # on the ground (or the ledge) under it
gargoyle.rotation.y = heading
gargoyle.alive = true                         # stone (false) or alive: it wakes (0.7 s) and sets (0.55 s)
gargoyle.airborne = true                      # in the air, wings out...
gargoyle.flapping = 1.0                       # ...beating (0: spread, gliding)
gargoyle.reaching = 1.0                       # arms and legs thrust forward, claws open (a pounce)
gargoyle.aim = player.global_position + Vector3.UP   # what it looks at (INF: nothing); it turns its head slowly
```

It works out its own speed and turning from how it is moved. Slow, it lurches on knuckles and talons; faster it goes
in heavy bounds (hands down together, then both feet, the body heaving, wings half open and lifting for balance).
Still, it crouches on all fours, or with `perched` squats as a statue on its ledge. In the air its body is level and
its wings beat as a bat's do (the downstroke fully stretched and swept forward, the upstroke with elbow and wrist bent
and the fingers drawn in) or are spread to glide; it banks into turns. When it is set to stone it slows and stops dead
in whatever pose it is in, the glow goes out of it, and after that nothing at all is done for it each frame.

| Call | What it does |
| --- | --- |
| `gather(seconds)` | The wind-up for a pounce: sinks into a crouch, raises its wings high, snarls with a grinding of stone. `gathering()` while it lasts |
| `slam()` | It has come down hard: lands low on its hands with a crash and a cloud of stone dust. Emits `slammed` |
| `snarl()` | A grinding growl, jaw wide, head thrust out, wings flared |
| `crumble(seconds)` | Grit and pebbles shaken off from under it, falling to the ground and ticking as they land, with a louder grinding: a warning for someone below who is not looking up |
| `show_shadow(point, strength, radius)` | A dark blot on the ground where it will land (`Vector3.INF` hides it) |
| `life()` | How alive it is now, 0 (stone) to 1 |
| `settle()` | Puts it still as it is told it is, with nothing going on |
| `strain` | Added to how hard it works (the glow in its cracks, the grinding) |

Exports: `low_poly`, `sound`, `volume_db`, `sound_range`, `dust`, `size` (1: as modelled), `seed_value` (its stone a
little lighter or darker).

## Sound

Made in code once and shared (nothing to load): a looping grind of stone on stone (a low rasping rumble with the
crackle of grains), played while it moves and loudest as it wakes and sets; a crash (a deep thump, a burst of rubble,
gravel trickling after) when it slams down, and quieter knocks of stone as its hands and feet come down; a heavy swell
of air on each wingbeat; a growl through a throat of stone for the snarl.

## The model

`tools/build_gargoyle.py` builds it in Godot's space (metres, Y up, facing +Z). The body is one piece of stone: a
Skin-modifier figure for the trunk, tail, neck and each limb (the left made, the right its mirror), the fingers and
toes as closed tubes, and many ellipsoids and tubes for the muscles, the head and face, horns, ears and spikes,
joined into one surface by a voxel remesh, then smoothed (less near the fine parts, the hands, feet and face), cut
(eye sockets, nostrils, the mouth) and weathered (worn lumps and pits). Teeth, claws and eyes are their own sharp
pieces. The wings are rods for the bones and a thin sheet of stone for the skin, panels between the fingers and in
front of and behind the forearm. The rest pose: crouched upright, arms hanging, mouth a little open, wings straight
out level.

What the shader needs is carried in the mesh: UV (x, y) and UV2.x are where each point is at rest, so the stone stays
put on it however it moves; UV2.y how far it lies in a hollow (from rays, at rest); the vertex colour masks the inside
of the mouth and nostrils (R), the eyes (G) and the wings' skin (B).

The skeleton: 52 bones, none the child of another. `Gargoyle` works out where each should be in the model (the trunk
turned to run from pelvis to chest, the head and tail turned joint by joint, the arms and legs by two-bone IK to their
hands and feet, each wing as a bat's hand from ten numbers: lift, sweep, twist, elbow, wrist, close, bend, cup, tips
and raise) and sets each straight. Each body vertex is weighted to the bones by how near they are for their
thickness, smoothed over the surface; the jaw by where a point is in the mouth; the wing's skin by where it lies
between two fingers (the skin is carried only by the forearm and the fingers: skin shared with the upper arm would
tear across the wing as it folds).

## Putting it in a game

```
sh kit.sh install godot/gargoyle /c/Projects/YourGame
```

`example.gd` runs one through everything, over and over (statue on a block, wake, glide down onto a post, crash,
stone, bound round, wind-up and leap, beat back up): put it on a Node3D in an empty scene and run it.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/gargoyle/`.
