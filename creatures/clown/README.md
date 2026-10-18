# Clown

A horror clown, too tall and too thin: a faded, stained, baggy one-piece suit with faded patches and fat pom-poms,
a pleated ruff round a long thin neck, ruffled cuffs, white gloves and long flat shoes whose fronts flap. His face is
a mask of white greasepaint on a bald dome with tufts of thin hair over the ears: tall dark diamonds painted through
the eyes and a grin painted far wider than any mouth, its corners curling up into the cheeks. He holds one red balloon
on a long string, floating high over him: the only colour near him. A music box tinkles where he is while he moves,
and winds down when he is still; he giggles; his shoes slap.

It is only the look, the motion and the sounds. He does no thinking: your game moves him and tells him what to do.
Made for The Clearing (its `MazeClown` is the thinking that drives him there: he is only ever still when someone
looks at him, and bursts into a sprint when they look away).

## Needs

GameCommon's `godot/character-controller` (the clown's rig, `ClownRig`, extends `CharacterRig`, and uses its
`Toon` and `Settings`). Global class names: `Clown`, `ClownRig`.

## Use

```gdscript
var clown := Clown.new()
clown.scale = Vector3.ONE * 1.55       # modelled about 1.5 units tall: 2.35 m
clown.balloon_height = 36.0            # how high the balloon floats over his feet (over the walls)
add_child(clown)
clown.put(spawn_point, spawn_yaw)

# every frame, from your own body (a CharacterBody3D, a path follower...):
clown.global_position = body_position
clown.rotation.y = facing_yaw           # 0 faces +Z
clown.velocity = body_velocity          # his feet step to this; fast (over ~4 m/s) he sprints in stop-motion
clown.aim = target + Vector3.UP         # what he looks at, and reaches for when near (INF: nothing)
clown.frozen = true                     # stopped dead mid-pose, the head slowly tilting over; the music winds down
clown.winded = true                     # bent double, a hand on his knee, panting
clown.giggle()                          # a giggle, a hand to his mouth
clown.far = true                        # not posed or heard; the balloon still floats
```

- `busy()` (giggling), `balloon_position()`, `face()` (for a line-of-sight test).
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`, `balloon_height`,
  `stop_motion` (poses a second when he sprints), `pose_rate` (poses a second otherwise, 0 every frame: fewer when
  he is far off). Also `music` (whether the music box plays) and `grounded`.

## How it moves

He creeps on long legs in too-long strides, the knees lifted high and the toes turned out, each big shoe set down heel
first and its front slapping flat after; bent forward at the hips with the shoulders up, the head pushed out ahead,
cocked over and slowly rolling, with a jerk of it now and then. The balloon hand holds the string up before his chest;
the other hangs long and swings, its fingers spread, reaching when he is near what he is after. Driven fast he
sprints: pitched forward, the knees pumping, the free arm windmilling, the head lolling, the balloon thrust up over
his head; and he is posed only `stop_motion` times a second, the whole figure jumping from pose to pose like a puppet
in stop-motion. Frozen, nothing is posed (it costs nothing): he holds whatever pose he was in, a foot in the air if it
was, and only his head moves, tilting slowly over onto one side, and then not even that. The balloon drifts on its
own, lagging behind him as he goes and jerked down a little by each step.

## Sound

All made in code (nothing to load), quiet: a music box's tine (an A struck and ringing away, with its octave, the
clang of a steel tine and the tick of the pin; played at other pitches for the notes of a little air in A minor, in
three, that goes round, slowing and sinking as it winds down); a man's high giggle through his teeth ("hee hee hee
hee hehhh": breathy pulses through the resonances of an "ee"); and the slap of a big shoe.

## Model

`tools/build_clown.py` builds `models/clown.glb` and `clown_lo.glb` in Blender 4.3 on the mummy's and the boy's
bone names (so any rig for them can move it):

    blender --background --python creatures/clown/tools/build_clown.py [-- <folder for preview renders>]

One material for all of him: each part's colour is baked into the model as its vertex colour, and how much grime is
in each point (in the folds of the cloth, and old stains) as its alpha; `ClownRig` shades it with Toon's shader,
taking the colour from the vertices and darkening the grime in one soft step. The face's paint is thin shapes of its
own lying on the face, so its edges are crisp. About 37k triangles (`clown_lo`: 7k); one draw (two with its shadow),
and two more for the balloon and its string (which cast no shadow). (The build exports the colour attribute by asking
the glTF exporter for it: see `_Export` in the script.)

## Try it

`example.gd` on a Node3D: one on a flat floor going round a loop (creep towards a post, freeze, creep, giggle,
sprint at it, stand winded, creep back).
