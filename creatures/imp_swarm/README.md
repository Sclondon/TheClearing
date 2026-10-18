# Imp swarm: dozens of tiny imps as a chattering tide (Godot 4.7)

A crack in the ground that dozens of tiny imps pour out of, after someone: a carpet of them over the floor, a share of
them running up and along the walls and leaping off at him, the ones that reach him running up him and clinging all
over him; and home again down the crack. Made 2026-10-18 for Warren (its imp swarms), as a component any game can
use: the look and the motion; whatever drives it says who they are after and decides what their getting on him means.
The imp is the same imp as `godot/imp`, made coarse (about 1,500 vertices) and baked on all fours.

- `creatures/imp_swarm/imp_swarm.gd` (`class_name ImpSwarm`, a `Node3D`: the crack is where you put it).
- `creatures/imp_swarm/imp_swarm.gdshader`: the imps' legs (a trot, in diagonal pairs), tails, wings and jaws, moved
  per vertex from each imp's custom data; two flat tones; colours from the mesh's second UV (not vertex colours, which
  the web does not give a MultiMesh dependably).
- `creatures/imp_swarm/models/imp_swarm.glb`: built by Warren's `creatures/imp/tools/build_imp.py` (with
  `imp_swarm.json` beside it: where each limb turns, which the shader keeps a copy of).

## Using it

```gdscript
var swarm := ImpSwarm.new()
swarm.count = 48
swarm.position = the_foot_of_a_wall
add_child(swarm)

swarm.target = player                  # any Node3D (its `velocity` and `is_on_floor()` are used if it has them)
swarm.steer = func(from: Vector3) -> Vector3: return next_point_towards_player_from(from)   # optional: round walls
swarm.release()                        # a second of chittering in the crack, then out they pour
swarm.overwhelmed.connect(func(who): ...)   # `catch_count` on him for `catch_time`
swarm.shake_off()                      # (a roll, a dive) every one on him thrown off
swarm.recall()                         # home they go
```

- `speed` (4.8 m/s by default: a little faster than a run), `chase_distance` from the crack, `pour_rate`, `warn_time`.
- `climb` and `drop`: the steps they go up and down; anything higher is a wall. `climbers` (a share of them) run up a
  wall in their way, slantwise, to as high as `wall_climb`, along it after him, and leap off at him when level with him
  or where the wall ends; those that like walls make for the nearest one as they go.
- On him: `on_him` (how many); each holds on for `hold` seconds of his shaking (being in the air, or going faster than
  `shake_speed`). `catch_count`, `catch_time`.
- Giving up: getting no nearer for `give_up_after` seconds (he is up on something, or gone) they go home, and rest
  `rest_time` before they will come out again (`rested()`).
- `out`, `hunting()`, `front()` (the nearest of them to him, for what watches it), `imp_position(i)`, `imp_state(i)`.
- Signals `came_out`, `went_home`, `overwhelmed(target)`. The chatter (a crowd of tiny clicks, squeaks and sniggers,
  made in code) follows the front of them; `voice` off for none. A dark crack is drawn at the nest (`crack`).

## Cost

One draw (one MultiMesh, no shadow) for the whole swarm, and the crack. All of them are moved in one loop: about 0.2
ms a frame for 48 on a desktop. The ground is found with a ray down once for each square of a grid (`CELL` across) as
an imp first comes to it and remembered; walls with a ray across, at most a few a frame (`RAYS`, `WALL_RAYS`); the way
round walls (`steer`) is asked once for each square of `STEER_CELL` and kept half a second. Nothing runs while it is
asleep in its crack.

## Putting it in a game

```
sh kit.sh install godot/imp-swarm /c/Projects/YourGame
```

`example.gd` is a whole scene: a floor, two walls, a crack, and a post going round for them to chase; let out every 16
seconds and called home after 12.
