# Gibbon: a troop of apes that live high (Godot 4.7)

A gibbon, true to the animal: a small ape with no tail, made to hang. Arms far longer than its legs (its fingertips
reach the ground when it stands), long hook hands with a small thumb set low, short bowed legs with long grasping feet
and the big toe set apart, a narrow chest, a small round head, a flat bare dark face under a heavy brow with deep-set
wet eyes and long canines, and shaggy fur over all the rest. Three coats: black-brown all over (DARK), the same with a
pale ring round the face and pale hands and feet (RINGED, a lar gibbon's dark phase), and buff-grey with the pale ring
(PALE). Made 2026-10-18 for Warren (where troops live on the ledges, terraces and wall tops and knock down whoever
climbs: `scripts/enemies/maze_gibbon.gd` there), as a creature any game can use: it is only the look, the motion and
the sound, and knows nothing of what it is doing it for.

- `creatures/gibbon/gibbon.gd` (`class_name Gibbon`, a `Node3D`): the motion, posed bone by bone in code (no
  animations), and its sounds, made in code (the great call, the shriek).
- `creatures/gibbon/gibbon_look.gd` (`class_name GibbonLook`): its shader (cel shading). The model carries masks, not
  colours (how light the coat is, where the pale ring and hands are, bare skin), and each gibbon gives its own coat, so
  one model makes every kind.
- `creatures/gibbon/models/`: `gibbon.glb` (about 30,000 vertices) and `gibbon_lo.glb` (12,000) for phones
  (`force_low`, or `Gibbon.low_poly` for all). One draw per gibbon, and its shadow.
- `creatures/gibbon/tools/build_gibbon.py` makes the models in Blender 4.3 (Skin modifier and subdivision for the body,
  the face built up from small forms, fur as many small clumps laid along the body the way an ape's lies, down the
  upper arm and up the forearm to the elbow, with their normals bent out from the body), round the skeleton
  `rest_joints.gd` writes out from Gibbon (`rest_gibbon.json`). Change the skeleton or a proportion in `gibbon.gd`,
  then run both:

```
godot --headless --audio-driver Dummy --path . -s res://creatures/gibbon/tools/rest_joints.gd
blender --background --python creatures/gibbon/tools/build_gibbon.py
```

Works in GL Compatibility (web, phones).

## Using it

```gdscript
var gibbon := Gibbon.new()
gibbon.kind = Gibbon.Kind.RINGED       # DARK, RINGED or PALE
gibbon.size = 1.15                     # metres per unit: about 0.8 m standing at 1
add_child(gibbon)

# Every frame, whatever drives it moves it (it faces +Z, the way it goes) and says its gait:
gibbon.gait = Gibbon.Gait.HANG         # the node on the bar or edge it hangs from: it brachiates along it
gibbon.gait = Gibbon.Gait.WALK         # the node on the ground: it walks upright, arms up
gibbon.gait = Gibbon.Gait.FLY          # the node where its hands will next take hold: move it along a leap's arc
gibbon.global_position = where
gibbon.rotation.y = heading
gibbon.sitting = true                  # walking, stopped: squats, arms round its knees
gibbon.away_from = wall_out            # hanging from a ledge's edge: the way out from the wall, to hang clear of it
gibbon.look_at_point = player.global_position + Vector3.UP   # INF: looks where it goes, or about it
```

It works out its speed from how it is moved. Hanging and going along, it swings hand over hand, its body a pendulum
under each hold and turning about the arm it hangs from, the free hand reaching ahead for the next; faster, the swings
lengthen and it lets go between them and flies. Still, it hangs by one arm and sways, or holds on with both. Changing
gait it blends from one to the next (`GAIT_TIME`): from HANG to WALK with the node moved in onto the top, it hauls
itself up over the edge.

| Call | What it does |
| --- | --- |
| `great_call(seconds)` | The great call: head back, a run of whoops rising and quickening to a climax where it shakes and flails (heard, with `sound` on); two calling at once is a duet |
| `calling()`, `call_progress()` | Whether it is calling, and how far through (0..1) |
| `lunge(point)`, `aim_lunge(point)` | The grab: wound up (`WIND_UP`: drawn back, mouth wide, shrieking), then a swing at the point feet first, the free hand out (`STRIKE`), then it gathers itself (`RECOVER`) |
| `lunge_stage()`, `lunge_progress()` | NONE, WIND_UP, STRIKE, RECOVER, and how far through it is (0..1) |
| `reaches(point, radius)` | Whether its feet or free hand are within `radius` of `point` now (only in the strike): for deciding a grab |
| `grabbers()`, `holds()` | Where its free hand and feet are; where its hands hold (world) |
| `settle()` | Puts it still where it is, in its gait, for when you put it somewhere |

Set `kind`, `size` and `seed_value` (its own small differences) before it goes into the tree. Hide it or set
`process_mode` disabled when it is far from the camera: it poses itself every frame.

## Putting it in a game

```
sh kit.sh install godot/gibbon /c/Projects/YourGame
```

`example.gd` runs one gibbon along a bar (swinging slowly, then flying, calling, lunging) and one walking upright on the
floor below it, sitting and calling back, over and over: put it on a Node3D in an empty scene and run it.
