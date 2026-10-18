# Chickens (Godot 4.7)

A flock of scruffy feral chickens, hens and a rooster: how they look and how they go about, and nothing about what
they mean in a game. Made 2026-10-18 for Warren (where they are one of the maze's alarms:
`scripts/enemies/chickens.gd` there). No scenes and no textures: `creatures/chicken/chicken_flock.gd`
(`class_name ChickenFlock`), `chicken_body.gd` (`ChickenBody`: the mesh and material), `chicken.gdshader`, and
`models/chicken.glb`, hen and rooster in one model (about 11000 triangles for the two; each bird draws its own parts),
built in Blender 4.3 by `tools/build_chicken.py`:

```
blender --background --python creatures/chicken/tools/build_chicken.py [-- <folder for pictures> [parts,to,show]]
```

## The bird

A real chicken's anatomy: an egg of a body with a deep breast and the back rising to the tail; contour feathers laid
over it in overlapping rows, each a small curved vane with a raised shaft (looser and longer on the belly, tiny on the
crown); the neck's hackles draped over the shoulders (the rooster's a long flowing cape, and his saddle lancets down
his sides); the tail a tent of broad feathers, his with two great sickles a side arching back and over it and lesser
sickles; folded wings on the flanks (primaries under, ten secondaries over them, three rows of coverts over their
roots) that open into spread wings; feathered drumsticks, the hock (the ankle, bending backwards), ringed scaly shanks
with a row of big scutes down the front and (his) spurs, three spread jointed toes forward and one back, with nails;
the single comb (hers small, his tall and serrated), the wattles, the ear lobes, a bare red face round an orange eye
with a black pupil, a hooked beak with nostrils, and the lower mandible that opens.

Four colours (by share of the hens, `colours`): red-brown (the rooster then a classic red: black breast, deep red
back and wings, gold-orange hackles and saddle, green-black tail), speckled (mahogany, each feather barred black and
tipped white), dingy white (with white ear lobes), and black with a green sheen. Every bird is a little molted (some
feathers missing, `molt`) and muddy up the legs and belly (`filth`). Lit in flat cel bands with a rim of light round the
feathers.

## What they do

- **Foraging** (left alone, round `home`, within `roam`): walking with the chicken head-lock (the head held still in the
  air while the body walks on under it, then darted forward), pecking in quick runs (crouched, body tipped, the head
  stabbing down and the eye turned to the ground between), scratching (one foot reaches forward and rakes back, then
  the other; then a step back to peck at what it turned up), preening (the head turned back into the feathers,
  nibbling), shaking out (puffed up all at once, a shiver), standing and looking about (the head snapped from pose to
  pose, turned and cocked to look with one eye), clucking (the beak). The rooster crows now and then: a few beats of
  his wings, then drawn up tall, the head thrown back and the beak opening on four calls.
- **Panic** (`scare(from)`): the nearest first, each squawks and bolts away from it, wings half open and beating, the
  nearest two and some others bursting up into short flights (beating hard, legs tucked, then gliding down on spread
  wings and landing running); feathers fly out of them and drift down rocking, and lie on the ground a while. Then
  they slow, shake themselves and drift home. A bird that has run far turns back.
- **Uneasy** (`uneasy`, points): they walk off from anyone within `shy_distance`, clucking, without panicking.
- **Mob** (`mob_target`, a point, a head): the rooster puffs up, hackles flared; the flock runs round it, leaps up at
  it beating their wings, hangs there pecking at it, falls and leaps again.
- **Tame** (`tame = true`): ordinary farmyard birds. Scared, they scatter a few steps squawking (hardly one takes
  wing) and settle at once; they never mob.

## Sounds and phones

- `ChickenVoice.new(flock)`, added as a child of the flock, plays clucks, squawks (signal `squawked`) and the
  rooster's crow (heard far off), all made in code the first time one is made (no sound files).
- `low_poly = true` (before it goes in) draws the low-detail bird, `models/chicken_lo.glb`: the same parts with fewer,
  bigger feathers and coarser legs, about 2100 triangles a bird against 5500. The build script writes both.

## Putting it in a game

```
sh kit.sh install godot/chicken /c/Projects/YourGame
```

```gdscript
var flock := ChickenFlock.new()
flock.count = 10
flock.flock_seed = 7
flock.home = where_they_live          # on the ground
flock.roam = 4.0
flock.keep_in = func(p: Vector3) -> Vector3: return p    # optional: keep them out of walls
flock.ground_height = func(p: Vector3) -> float: return 0.0   # optional
add_child(flock)

flock.scare(player.global_position)   # they panic
flock.mob_target = head               # every frame, while they mob; Vector3.INF to stop
```

`example.gd` is a whole scene: a flock foraging, scared, mobbing a point, and round again.

## Talking to it

- `home`, `roam`, `keep_in`, `ground_height`, `uneasy`, `mob_target`; `scare(from)`, `calm()`, `crow()`.
- `panicking()`, `flying()`, `mobbing()`, `centre()`, `bird_position(i)`, `is_rooster(i)`, `act_of(i)`
  (`ChickenFlock.Act`), `loose_feathers()`, `place_bird(i, at, yaw)`.
- Signals `startled` (the first squawk of a panic), `squawked(at)`, `crowed(at)`, `clucked(at)`, `furious` (a new
  `mob_target`), for sounds (ChickenVoice plays them, or play your own).
- For pictures: `frozen = true` and `pose_bird(i, at, yaw, legs, head, turn, beak, puff, wings, pitch)`.

## Tuning

Exported: `count` (up to 16), `roosters`, `flock_seed`, `home`, `roam`, `size`, `walk_speed`, `run_speed`,
`flight_speed`, `fly_share`, `shy_distance`, `filth`, `molt`, `colours`, `view_range`, `cast_shadows`, `tame`, `low_poly`. The joints are
`ChickenBody.NECK_BASE`, `HEAD`, `KNEE`, `HOCK`, `FOOT`; the shader and the Blender script keep their own copies,
which must stay in step.

## Cost

One draw per flock (one MultiMesh; each bird posed in the vertex shader from four vec4s of its pose, set on the flock's
material each frame) and one for its shadow, and one more while loose feathers are about. A flock of 15 panicking
takes about a quarter of a millisecond a frame on a desktop. Calm and further than `view_range` from the camera, a
flock does no work and is not drawn. The model is about 5500 triangles a bird.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/chicken/`
(ChickenBody loads the shader and the models from there).
