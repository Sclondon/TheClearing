# Baboon: demonic baboons and the mandrill that leads them (Godot 4.7)

A coarse olive-grey ape on all fours, high-shouldered, walking on its knuckles, with a dog's muzzle, fangs and two
small eyes glowing like embers under a heavy brow. The alpha is a mandrill: twice as heavy, a shaggy cape of mane, a
yellow-orange beard, and the face: a crimson ridge down the snout to a bulb of a nose, and swollen, ribbed slate-blue
cheeks, the one colour in it. Made 2026-10-18 for Warren (its baboon troops), as a creature any game can use: it
is only the look and the motion, and knows nothing of what it is doing it for.

- `creatures/baboon/baboon.gd` (`class_name Baboon`, a `Node3D`): the motion, all procedural (no animations).
- `creatures/baboon/baboon_look.gd` (`class_name BaboonLook`): its shader (cel shading; the mandrill's face cut sharp
  from where on the snout each point is).
- `creatures/baboon/models/`: `mandrill.glb` and `baboon.glb` (about 34,000 and 27,000 vertices), and `_lo` versions
  (13,000 and 9,000) for phones (`force_low`, or `Baboon.low_poly` for all). One draw per baboon, and its shadow.
- `creatures/baboon/tools/build_baboon.py` makes the models in Blender 4.3 (Skin modifier and subdivision for the
  body, a sculpted snout, fur as many small clumps with their normals bent out from the body), round the skeleton
  `rest_joints.gd` writes out from Baboon (`rest_alpha.json`, `rest_baboon.json`). Change the skeleton or a build in
  `baboon.gd`, then run both:

```
godot --headless --path . -s res://creatures/baboon/tools/rest_joints.gd
blender --background --python creatures/baboon/tools/build_baboon.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var mandrill := Baboon.new()
mandrill.kind = Baboon.Kind.ALPHA      # or Baboon.Kind.BABOON
add_child(mandrill)

# Every frame, whatever drives it just moves it; it faces +Z.
mandrill.global_position = where
mandrill.rotation.y = heading
mandrill.look_at_point = player.global_position + Vector3.UP   # INF: looks where it goes, or about it
```

It works out its own speed from how it is moved, and picks its gait: a knuckle-walk, one foot at a time, when slow;
a bounding gallop when fast (it gallops from about 1.4 of its own shoulder heights a second). Its feet keep to the
ground as it goes. Stopped, it stands on all fours, or with `sitting = true` sits up on its haunches and looks about.

| Call | What it does |
| --- | --- |
| `bark()` | A sharp bark: head thrown up, jaw snapped open (0.4 s) |
| `display(seconds)` | The threat: rears up over its hands, hunches, mane on end, yawns its jaw right back to show its fangs, slaps the ground with one hand and the other |
| `leap(flight, height)` | Crouches (`CROUCH_TIME`), springs and flies `flight` seconds rising `height` metres (it lifts itself; move it along the ground yourself during FLIGHT), lands on its hands (`LAND_TIME`) |
| `leap_stage()`, `leap_progress()` | NONE, CROUCH, FLIGHT, LAND, and how far through it is (0..1) |
| `reaches(point, radius)` | Whether its hands or jaws are within `radius` of `point` now (only in the air or landing): for deciding a grab |
| `grabbers()` | Where its hands and jaws are (world) |
| `panting` (0..1) | Tired: mouth open, heaving |
| `settle()` | Stands it still where it is, for when you put it somewhere |

Set `kind`, and if you like `size` (metres per unit; each kind has its own) and `seed_value` (its coat), before it
goes into the tree. Hide it or set `process_mode` disabled when it is far from the camera: it poses itself every frame.

## Putting it in a game

```
sh kit.sh install godot/baboon /c/Projects/YourGame
```

`example.gd` runs an alpha and a baboon round a ring on a flat floor through everything they do, over and over: put it
on a Node3D in an empty scene and run it.
