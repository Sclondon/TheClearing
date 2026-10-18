# Imp: a tiny devil that scuttles, climbs walls, cackles and rides you (Godot 4.7)

A knee-high imp, wiry and pot-bellied: sooty red-brown skin going to charcoal on its back, hands and feet; too-long
arms with three long clawed fingers and a thumb; short bowed legs standing on its toes, three clawed toes and a spur;
big cupped bat's ears; two small ridged horns curving back; stubby leathery wings; a whip of a tail with a barbed spade;
small slanted glowing eyes with slit pupils under a heavy V of a brow; a sharp hooked nose; and a wide grin whose lips
are drawn back at the corners on two rows of needle teeth, a pointed chin. Made 2026-10-18 for Warren (its imp
gangs), as a creature any game can use: only the look, the motion and its voice; it knows nothing of what it is for.

- `creatures/imp/imp.gd` (`class_name Imp`, a `Node3D`): the motion, all procedural (no animations), and its sounds.
- `creatures/imp/imp_look.gd` (`class_name ImpLook`): its shader (cel shading; leathery creases and mottling; a hard
  glint on the eyes and teeth; a warm rim). Each imp a little different (`tone`, `warmth`).
- `creatures/imp/imp_ride.gd` (`class_name ImpRide`): where an imp holds on to a figure (six places: back, thighs,
  shoulder, side, chest), from its skeleton (GameCommon's characters' bone names), for `riding`.
- `creatures/imp/models/`: `imp.glb` (about 24,000 vertices) and `imp_lo.glb` (7,000) for phones (`force_low`, or
  `Imp.low_poly` for all). One draw per imp, and its shadow.
- `creatures/imp/tools/build_imp.py` makes the models in Blender 4.3 (Skin modifier and subdivision for the body, then
  shaped: a round low pot belly, ribs, the knobs of the spine; the head, ears, horns, wings, claws, teeth and barb as
  parts), round the skeleton `rest_joints.gd` writes out from Imp (`rest_imp.json`). It also builds the imp swarm's
  coarse imp (`creatures/imp_swarm/models/imp_swarm.glb`). Change the skeleton in `imp.gd`, then run both:

```
godot --headless --audio-driver Dummy --path . -s res://creatures/imp/tools/rest_joints.gd
blender --background --python creatures/imp/tools/build_imp.py [-- <folder for previews>]
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var imp := Imp.new()
add_child(imp)

# Every frame, whatever drives it just moves it; it faces +Z, its Y is "up" for it.
imp.global_position = where
imp.rotation.y = heading
imp.look_at_point = player.global_position + Vector3.UP   # INF: it looks where it goes, or about it in quick jerks

# On a wall: turn it so that its Y is the wall's normal and its Z the way it goes along the wall.
imp.clinging = true
imp.global_transform = Transform3D(Basis(normal.cross(up_the_wall), normal, up_the_wall), point_on_wall)

# Riding someone: put it where ImpRide says, every frame.
imp.riding = true
imp.global_transform = ImpRide.slot(their_skeleton, them, 0)
```

It works out its own speed from how it is moved (in its own floor, so the same on a wall as on the ground), and picks
its gait: upright, hunched, long arms swinging, when slow; a scuttle on all fours in diagonal pairs from about
`FOURS_FROM` of its own heights a second; bounding when fast. Its feet keep to what it is on.

| Call | What it does |
| --- | --- |
| `cackle()` | Head thrown back, jaw chattering, shoulders shaking, clutching its belly (1.1 s); a wheezing, breathy snigger |
| `chitter()` | A quick chatter of its teeth, ears up (0.5 s); dry clicks and squeaks |
| `tantrum(seconds)` | Stamping, beating the ground with both fists, head thrashing, tail whipping, ears flat; a rough shriek |
| `leap(flight, height)` | Crouches (`CROUCH_TIME`), springs and flies `flight` seconds rising `height` metres (it lifts itself; move it along yourself), claws spread, wings open, lands on all fours |
| `leap_stage()`, `leap_progress()`, `end_leap()` | NONE, CROUCH, FLIGHT, LAND; how far through; stop it (it caught hold of something) |
| `reaches(point, radius)` | Whether its claws or jaws are within `radius` of `point` now (in the air only): for deciding a grab |
| `grabbers()`, `head_position()` | Where its claws, jaws and head are (world) |
| `on_all_fours`, `clinging`, `riding`, `tumbling` | Stances: all fours whatever its speed; flat on a wall, limbs splayed; hugging a body, wriggling; thrown, flailing |
| `settle()` | Puts it straight into its pose where it is, for when you put it somewhere |
| `Imp.sound(&"cackle")` | Its sounds as AudioStreamWAVs (`cackle`, `chitter`, `shriek`), made in code once |

Set `size` (metres, about its height upright to the top of its head, 0.44) and `seed_value` before it goes into the
tree; `voice` off for no sound (always pass `--audio-driver Dummy` to test runs). Hide it or disable its processing
when it is far from the camera: it poses itself every frame.

## Putting it in a game

```
sh kit.sh install godot/imp /c/Projects/YourGame
```

`example.gd` runs two imps round a ring on a floor through everything they do (walk, scuttle, bound, cackle, chitter,
tantrum, leap) and a third up and down a wall, over and over: put it on a Node3D in an empty scene and run it.
