# Beetle swarm (Godot 4.7)

A swarm of beetles: a glossy black carpet of several hundred that pours out of cracks at the foot of a wall (or a
hole in the floor), floods along the ground, runs up the feet of walls and over anything low, and goes for a point;
those that reach it run up the legs of whoever stands there. How they look and move, and nothing about what they mean
in a game. Made 2026-10-18 for The Clearing (where they hunt the maze: `scripts/enemies/beetles.gd` there), from
Outside's scarab swarm (`scripts/scarab_swarm.gd`, `scripts/scarab.gd`, `tools/build_khepri.py` in Outside).

No scenes and no textures: `creatures/beetle_swarm/beetle_swarm.gd` (`class_name BeetleSwarm`),
`beetle_look.gd` (`BeetleLook`: the mesh and material), `beetle.gdshader`, and `models/beetles.glb`, the two beetles
(about 250 and 130 triangles), built in Blender 4.3 by `tools/build_beetles.py`:

```
blender --background --python creatures/beetle_swarm/tools/build_beetles.py
```

What you get:

- **Two kinds of beetle, mixed** (`dor_share`, sizes spread by `size_spread`): a ground beetle after the violet ground
  beetle (long oval wing cases with a flattened margin, a heart-shaped shield over the thorax, a narrow waist, jaws,
  long running legs, long feelers) and a squat, domed dor beetle (Outside's scarab, its toothed head rounded off).
  Glossy black with an oily sheen: the overcast sky mirrored in a hard-edged pale band along the shell, the colours
  of an oil film (violet, blue, green, bronze) round its edges, each beetle starting somewhere else on that round,
  and one hard light. Their six legs stride in the shader, stopping when they stop.
- **Cracks**: a jagged black slit at the foot of a wall with hairline cracks running up from it and a dark spill in
  front, or a ragged hole in the floor. Out of them they pour (`pour_rate`), fanning out from the wall.
- **Flooding**: they run at `speed` as a carpet (those behind hurry, the front does not run away from the rest),
  spreading across a hall (`flood_width`) when far from the target and scurrying with a weave; they keep apart by
  counting themselves into squares of the ground; they go up any face no higher than `climb`, down drops of up to
  `drop`, and slide along anything higher.
- **Up walls**: some (`wall_share`) of those that meet a wall run up its foot, as far as `wall_climb`, along it
  towards the target, and back down.
- **Up people**: at the target, up to `most_on` run up the legs and round the body, to the shoulders; the rest go
  round and round in a ring at their feet (and up any wall in the way). Running faster than `shake_speed`, or
  jumping, shakes them off a few at a time; thrown off, they tumble and pick themselves up.
- **Home**: `recall()` and they stream back to their own cracks and go in.

## Putting it in a game

```
sh kit.sh install godot/beetle-swarm /c/Projects/YourGame
```

```gdscript
var swarm := BeetleSwarm.new()
swarm.count = 520
swarm.add_crack(foot_of_the_wall, out_of_the_wall)   # before or after add_child; Vector3.ZERO: a hole in the floor
add_child(swarm)
swarm.release()                                      # out they come

# every frame while they are out:
swarm.target = player.global_position                # Vector3.INF: nowhere (they mill about)
swarm.target_moving = player.velocity
swarm.target_grounded = player.is_on_floor()
swarm.overwhelmed.connect(func() -> void: print("caught"))

swarm.recall()                                       # home they go
```

`example.gd` is a whole scene: a floor, a wall with two cracks, and a point going round the floor that they chase
for 12 seconds in every 18.

## Talking to it

- `add_crack(at, out)`, `cracks()`, `crack_out(i)`, `clear_cracks()`.
- `release()`, `recall()`, `reset()` (all back in at once), `shake_off()`, `new_target()` (the stall clock starts again).
- `target`, `target_moving`, `target_grounded`: where they go, and whether whoever is there is shaking them off.
- `guide` (optional, `Callable(from: Vector3, goal: Vector3) -> Vector3`): where a beetle at `from` should make for
  on its way to `goal`, round walls (a navmesh or grid path's next corner). Asked for each beetle every
  `GUIDE_EVERY` frames, so make it cheap (cache by cell). Without it they go straight and slide along walls.
- `forbid` (optional, `Callable(point: Vector3) -> bool`): ground they will not go onto (water). Asked once per
  square of ground.
- Read: `mode` (DORMANT, OUT, HOME), `out`, `on_target`, `front` (the beetle nearest the target), `gap` (how far it
  is), `stalled` (seconds they have got no nearer: give up by it), `beetle_position(i)`, `beetle_state(i)`,
  `counted(state)`.
- Signals: `overwhelmed` (`catch_count` on the target for `catch_time`), `came_out`, `went_home`.
- `forget_ground()` when something they walk on has moved.

## Tuning

Exported: `count`, `beetle_size`, `size_spread`, `dor_share`, `speed`, `reach` (how far from the first crack they can
go: the ground grid's size), `pour_rate`, `climb`, `drop`, `wall_climb`, `wall_share`, `flood_width`, `catch_count`,
`catch_time`, `most_on`, `shake_speed`, `ground_mask`, `swarm_seed`, `show_cracks`, `stagger`. The look is the
shader's uniforms (`shell`, `sheen`, `film_spread`, `sky`, `sky_shine`, `gloss`, `reach` and `lift` of a step) on
`BeetleLook.mesh().surface_get_material(0)`.

## Cost

One draw for all of them (one MultiMesh, no shadow; both kinds in one mesh, each instance showing only its own),
plus one small mesh per crack. Asleep, nothing. Out, every beetle near the target (2.5 m) or home is worked out every
frame, and the rest in full one frame in `stagger` (3), only carrying on as they were in between; the ground is a
grid of 0.25 m squares, each found with one ray down the first time a beetle comes to it (at most 32 rays a frame)
and remembered. Measured in The Clearing (desktop, GDScript): 520 beetles flooding a hall about 0.9 ms a frame, 520
with 70 on someone and the rest round them about 1.1 ms. Use fewer on phones (The Clearing uses 300 there).
Seeded by `swarm_seed`, so two machines that make the same swarm get the same beetles.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. Ground and walls on `ground_mask` (layer 1).
The files must sit at `res://creatures/beetle_swarm/` (BeetleLook loads the shader and the model from there).
