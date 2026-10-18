# Bats (Godot 4.7)

A colony of big bats: how they look and how they fly, and nothing about what they mean in a game. Made 2026-10-18
for The Clearing (where they are the maze's alarm: `scripts/enemies/bats.gd` there). Three files, no scenes, no
textures, no models: `creatures/bats/bat_colony.gd` (`class_name BatColony`), `bat_body.gd` (`BatBody`, the mesh
and material, made in code) and `bat.gdshader`.

What you get:

- **Roosting**: a clump hanging head down on a wall (or under a ledge or ceiling), backs to the stone, wings wrapped
  round their fronts like cloaks, the bones of the fingers showing. They sway and breathe; now and then one half
  opens its wings, shakes them and wraps them again.
- **Waking**: one after another (from the middle of the clump out) they let go, fall head first as their wings open,
  and swing out and away.
- **Flying**: wings beaten by the arm with the hand following late, so the wing rolls and the tip flicks; banked into
  turns; beating hard to climb, turn and catch up, gliding on held wings between whiles; the body bobbing against the
  beat.
- **Swirling**: round a target point in a cloud, each on its own orbit (wide or tight, high or low, a few the other
  way round), one diving at the target every few seconds; they follow it as it moves.
- **Going home**: each flies back to its own place, flutters in, swings over, takes hold and folds up.

The bat itself: a round furry body, dark, with a lighter mantle over the shoulders and chest and a ragged ruff round
the neck; a round head with a short snout, big cupped ears (paler inside) and small dark eyes with a glint; small
hooked thumbs at the wrists; dark wings of thin skin with the finger bones showing as lines and a scalloped trailing
edge. Hanging, it bows its head so that it looks out from the wall, ears down. Big by default (1.4 m wingspan), lit in
flat cel bands; the fur catches a rim of light, and light from behind shines warm through the wings (most at their thin
trailing edges), so they read as skin against a bright sky. The colours are exports.

## Putting it in a game

```
sh kit.sh install godot/bats /c/Projects/YourGame
```

```gdscript
var bats := BatColony.new()
bats.count = 12
bats.colony_seed = 7
add_child(bats)
bats.set_roost(wall_point, out_of_the_wall)   # a point on the surface, and the way out of it
bats.settle()                                  # all hanging, asleep

# later, something wakes them:
bats.awake = true
bats.target = player.global_position + Vector3.UP * 1.6   # every frame, while they mob
# and when it is over:
bats.awake = false                             # they go home and hang up again
```

`example.gd` is a whole scene: a wall, a colony, woken every 14 seconds to chase a point round the floor.

## Talking to it

- `set_roost(point, out)`, `roost()`, `settle()`.
- `awake` (bool): off the roost or back to it.
- `target` (Vector3, `Vector3.INF` for none): what they whirl round. With none, awake, they mill about `rally`
  (`Vector3.INF`: a little out and down from the roost).
- `keep_in` (Callable(point) -> Vector3, optional): moves a bat's goal to somewhere bats may fly, e.g. out of walls.
  The bats themselves are not collided with anything.
- `all_home()`, `flying()`, `centre()`, `bat_position(i)`.
- Signals `woke` (the first lets go) and `settled` (the last hangs up), for sounds.
- For pictures: `frozen = true` and `pose_bat(i, transform, beat, strength, fold)`.

## Tuning

Exported: `count`, `wingspan`, `colony_seed`, `speed`, `flap_rate`, `swirl_radius`, `swirl_height`, `dive_every`,
`target_radius`, `target_depth` and `clearance` (the space round the target, a head and shoulders, that the swirl keeps
out of, wing tips and all, but for a bat diving),
`cluster` (the clump's width and depth), `view_range`, and the colours `fur`, `mantle`, `skin`, `ear`, `eye`. The wing's shape is
`BatBody.TIP`, `FINGERS`, `ANKLE`, `SCALLOP`; the body is `BatBody.BODY`. The shader's `SHOULDER`/`WRIST` must stay
in step with BatBody's.

## Cost

One draw call per colony (one MultiMesh; the wings are bent in the vertex shader from per-bat custom data), no
shadow. A hanging colony further than `view_range` from the camera does no work at all; otherwise every bat is moved
each frame (a dozen: a fraction of a millisecond). The bats are seeded by `colony_seed`, so two machines that make a
colony with the same seed and roost see the same bats in the same places.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/bats/`
(BatBody loads the shader from there).
