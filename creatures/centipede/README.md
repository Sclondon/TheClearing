# Giant centipede (Godot 4.7)

A giant centipede to look at and to move, after a Scolopendra: eighteen metres of glossy red-brown armour (a domed,
rimmed, grooved plate to each length, lapping over the next, pale soft skin between that shows as it bends) on 44
amber legs of six joints each, the last pair long and trailing; a redder shield of a head with clusters of black eyes,
long beaded feelers, and great curved poison claws with black fangs. Made 2026-10-18 for The Clearing (its `Centipede` enemy drives it), but it knows nothing of
that game. Two scripts, no scenes, no models, no textures: `creatures/centipede/centipede_body.gd`
(`class_name CentipedeBody`, a `Node3D`) and `centipede_parts.gd` (`CentipedeParts`: its shapes and its shader).

It does no thinking. You move it; it follows.

- **Its body follows its head.** The node is where its head is, on the ground (forward is its +Z). Move it however you
  like and every length of it passes where the head passed, round the same corners, never stretching.
- **Its legs walk by themselves** from how far it has gone: a pair to each length, each foot planted, lifted, swung
  forward and set down, in waves that run from head to tail, quicker the faster it goes. Lifted off the ground they
  draw in and claw at the air. Running, its body bends from side to side (`undulate`).
- **Walls.** Near anything on `wall_mask` it runs a little way up the foot of it, belly to the wall, and higher up it
  round a tight corner or with a wall coming up ahead (`climb`, `corner_climb`; `climb = 0` keeps it flat).
- **It rears**: `rear(0..1)` lifts the front `rear_length` metres of it up to `rear_height`, bending, its head drawn
  back as it rises. With `look_about` it sways its reared head from side to side, feeling the air.
- **It strikes**: `strike(at)` rears back high with its claws spread (WIND_UP, `wind_up` s: the warning), throws itself
  at `at` (POUNCE: the whole of it slides forward along its path, up to `pounce_reach` m), lies there with its claws
  shut (HOLD), and draws back (RECOVER). `stage()`, `strikes_in()`, `retarget(at)` while winding up, the `pounced`
  signal, and `bites(a, b, radius)`: whether its claws have passed within `radius` of the line from `a` to `b` this
  frame (ask every frame of POUNCE and HOLD; a target's feet to its head, say).
- **It coils**: `lay_coil(radius, middle)` puts it down coiled; `curl(radius, middle, seconds)` curls it up where it
  lies (hold it still meanwhile). `lay_straight()` and `lay_along(points)` put it down stretched out.
- **It looks at things**: `aim` (a point, or INF) turns its head and draws its feelers towards it.

## Putting it in a game

```
sh kit.sh install godot/centipede /c/Projects/YourGame
```

```gdscript
var centipede := CentipedeBody.new()
add_child(centipede)                    # where its head is; or a child of your CharacterBody3D
centipede.lay_straight()                # (or lay_coil())
# each frame: move it (global_transform), then
centipede.aim = target.global_position
if near:
	centipede.strike(target.global_position + Vector3.UP * 0.6)
if centipede.stage() == CentipedeBody.Stage.POUNCE and centipede.bites(feet, head, 0.85):
	caught()
```

If it is a child of a `CharacterBody3D`, that body is left out of its wall rays. To drive it from physics without
stutter, set it `top_level` and put its transform where your body is drawn each frame (as The Clearing does).
`example.gd` (attach to a Node3D in an empty scene) runs one round a loop past a wall, rearing and striking at a post.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. Walls are found by ray casts on `wall_mask`.

## Exports

`length`, `segments`, `width`, `ride`, `leg_length`, `foot_out`, `stride`, `undulate`; `rear_length`, `rear_height`; `wind_up`,
`pounce_time`, `hold_time`, `recover_time`, `pounce_reach`; `climb`, `wall_mask`, `corner_climb`; colours `shell`,
`head_shell`, `rim`, `under`, `membrane`, `leg`, `tip`; `voice` (the clatter of its legs and a chitter as it rears to strike, made in code);
`cull_distance` (further than this from the camera it is hidden and its legs are not worked out).

## Cost

Four draws whatever its length (a MultiMesh of plates, the head, a MultiMesh of every leg joint, feeler bead and claw,
and one of every claw tip, fang and eye), about 34 000 triangles at 22 lengths. Each frame it works out ~400
transforms in GDScript (only when within `cull_distance` of the camera), written to the MultiMesh buffers in one go;
nothing is allocated per leg.
