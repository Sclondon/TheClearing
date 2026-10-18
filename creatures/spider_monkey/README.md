# Spider monkey: a long-limbed monkey that hangs by its tail, swings hand over hand and flings itself down (Godot 4.7)

A real spider monkey (after Geoffroy's, the black-handed): long thin arms (longer than its legs) and legs, a narrow chest
over a round pot belly, a small round head on a short neck, hook hands of four long fingers and no thumb, hand-like
feet with a gripping great toe, and a prehensile tail half as long again as its head and body, furred but for the
bare, ridged grip pad under its last part. A dark shaggy coat, long on the back, flanks and limbs; a bare dark face
with pale skin round the eyes and over the muzzle, a pale mask in the dark. Made 2026-10-18 for Warren (its
troops that ambush from the vines over the halls), as a creature any game can use: only the look, the motion and its
voice; it knows nothing of what it is for.

- `creatures/spider_monkey/spider_monkey.gd` (`class_name SpiderMonkey`, a `Node3D`): the motion, all procedural (no
  animations), and its sounds.
- `creatures/spider_monkey/spider_monkey_look.gd` (`class_name SpiderMonkeyLook`): its shader (cel shading; the coat
  finely streaked and taking a rim of light; a hard glint on the eyes). Each one's coat a little different (`tone`).
- `creatures/spider_monkey/spider_monkey_vine.gd` (`class_name SpiderMonkeyVine`, a `MeshInstance3D`): an old woody
  vine strung along a wall (sagging between the places it is held, knotted, tendrils hanging from it, its stems going
  down to the ground at either end) for them to hang from, and where along it a point is. One draw.
- `creatures/spider_monkey/models/`: `spider_monkey.glb` (about 24,000 vertices) and `spider_monkey_lo.glb` (7,000)
  for phones (`force_low`, or `SpiderMonkey.low_poly` for all). One draw per monkey, and its shadow.
- `creatures/spider_monkey/tools/build_spider_monkey.py` makes the models in Blender 4.3 (Skin modifier and
  subdivision for the body, a pushed-out pot belly; the head, face, eyes, nostrils, lips, teeth and ears as parts; the
  coat as many small clumps of hair lying along the body, their normals bent out from it), round the skeleton
  `rest_joints.gd` writes out from SpiderMonkey (`rest_spider_monkey.json`; modelled with its limbs spread out wide of
  its body, so that the chest and haunches keep their shape however the limbs are turned). Change the skeleton in
  `spider_monkey.gd`, then run both:

```
godot --headless --audio-driver Dummy --path . -s res://creatures/spider_monkey/tools/rest_joints.gd
blender --background --python creatures/spider_monkey/tools/build_spider_monkey.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var monkey := SpiderMonkey.new()
monkey.hang_style = SpiderMonkey.Hang.TAIL   # still, it hangs by its tail alone, upside down (HAND: tail and a hand)
add_child(monkey)

# Its origin is always where its feet would be; it faces +Z.
# On the ground: move it and turn it; it walks on all fours, and bounds when fast.
monkey.global_position = where
monkey.rotation.y = heading

# Hanging from a vine (or a branch): its hold is HANG_HIGH above its origin, the vine running along hold_axis.
monkey.hanging = true
monkey.hold_axis = vine.axis_at(t)
monkey.global_position = vine.to_global(vine.point_at(t)) + Vector3.DOWN * SpiderMonkey.HANG_HIGH * monkey.size
# (move it along the vine and it swings along hand over hand, its tail a third hand)

# Flung through the air: move it yourself on whatever arc; it reaches ahead for where it lands.
monkey.hanging = false
monkey.airborne = true

# Climbing a wall: turn it so that its Y is the wall's normal and its Z the way up it.
monkey.clinging = true
monkey.global_transform = Transform3D(Basis(normal.cross(Vector3.UP), normal, Vector3.UP), point_on_wall)

monkey.look_at_point = player.global_position + Vector3.UP   # INF: it looks where it goes, or about it
```

It works out its own speed from how it is moved (in its own floor, so the same on a wall as on the ground). Hanging
still it sways under its hold and looks about, its free hand now scratching, now reaching, now loose.

| Call | What it does |
| --- | --- |
| `chitter()` | A quick chatter, lips pushed out, the head bobbing (0.6 s); soft twittering pulses |
| `shriek()` | A screaming bark, mouth wide, head thrust up (0.75 s) |
| `rustle(seconds)` | Shakes what it hangs from (on the ground: bounces where it stands), with its whinny; a warning |
| `wind_up(seconds)` | Hanging: lets go with its hand, draws itself up and swings back on its tail, arms raised, ready to fling itself off |
| `display(seconds)` | The threat on the ground: up on its hind legs, arms over its head and shaking, mouth open, bouncing; a shriek |
| `reaches(point, radius)` | Whether its hands or feet are within `radius` of `point` now (only `airborne`): for deciding a grab |
| `grabbers()`, `head_position()` | Where its hands, feet and head are (world) |
| `settle()` | Puts it straight into its pose where it is, for when you put it somewhere |

Set `size` (1: an adult, about 0.45 m head and body, the tail 0.9 m), `seed_value` (its coat and its ways) and
`hang_style` before it goes into the tree. Hide it or set `process_mode` disabled when it is far from the camera: it
poses itself every frame.

The vine:

```gdscript
var vine := SpiderMonkeyVine.new()
vine.anchors = PackedVector3Array([a, b, c])   # where it is held, in its own space; it sags `sag` between them
vine.ground = 0.0                              # its stems at either end go down to this (NAN: none)
vine.away = wall_normal                        # off the wall it runs along
add_child(vine)
vine.build()
```

## Putting it in a game

```
sh kit.sh install godot/spider-monkey /c/Projects/YourGame
```

`example.gd` runs three of them by a wall with a vine along it through everything they do, over and over: put it on a
Node3D in an empty scene and run it.
