# Rats (Godot 4.7)

Brown rats (Rattus norvegicus) three ways: a single rat, a swarm of a few hundred pouring out of drains like a river,
and a rat king (eight to fourteen rats whose tails are fused in a knot, writhing and dragging itself along). How they
look, sound and move, and nothing about what they mean in a game. Made 2026-10-18 for Warren (where they live in the
maze: `scripts/enemies/maze_rat.gd`, `maze_rat_swarm.gd` and `maze_rat_king.gd` there). The swarm is made from
BeetleSwarm (`godot/beetle-swarm`).

No scenes and no textures: `creatures/rats/` holds

- `rat_look.gd` (`RatLook`): the meshes, the one material, and how a rat's pose is packed into a MultiMesh's custom data.
- `rat.gdshader`: poses every rat (the gait from a walk to the hunched bounding scurry, the back arching and bending
  into turns, rearing up on its haunches to sniff, head down to gnaw, the jaw dropping to squeal, whiskers twitching,
  the tail swaying) and colours it (agouti fur, pale belly, pink feet and nose, scaly ringed tail, orange incisors).
- `rat.gd` (`Rat`): one rat. `step(velocity, delta)` each frame; `rear`, `feeding`, `squeak()`. Full model near the
  camera (`detail_range`), the low one further off.
- `rat_swarm.gd` (`RatSwarm`): the swarm. Drains at a wall foot (a broken hole, stumps of a grate, a wet stain); a
  squealing roar for `warn_time`, then they pour out (`pour_rate`) and flood after `target` at `speed`, climbing over
  each other where they crowd (`pile` deep), up anything lower than `climb`, up wall faces to `wall_climb`; those that
  reach the target climb it; `catch_count` on for `catch_time` and `overwhelmed`. `recall()` and home they go (any
  still on the way after `home_time` slip into a crack where they are). API as BeetleSwarm's (`add_drain`, `release`,
  `recall`, `reset`, `shake_off`, `new_target`, `target`, `target_moving`, `target_grounded`, `guide`, `forbid`,
  `mode`, `out`, `on_target`, `front`, `gap`, `stalled`, `warning()`, `highest_pile()`).
- `rat_king.gd` (`RatKing`): the king. Set `wish` (level direction) and `urge` (0 to 1); each rat pulls outward in its
  own fits, those facing `wish` oftener, and `drift` (and `spin`) is what that comes to: slow, lurching, turning about
  itself. It moves itself unless `moves_itself` is off. `squeal()` (every rat rears and shrieks), `frenzy()` (a lunge
  of teeth all round), `reach()`.
- `rat_voice.gd` (`RatVoice`): the sounds, made in code the first time each is wanted: `squeak()`, `roar()` (a loop),
  `shriek()`, `writhing()` (a loop).
- `models/rat.glb` (the rat in full, about 1900 triangles, and the king's knot of tails, about 1750),
  `models/rat_lo.glb` (about 230), built in Blender 4.3 by `tools/build_rats.py` (which says what each point's UVs tell
  the shader):

```
blender --background --python creatures/rats/tools/build_rats.py
```

## Putting it in a game

```
sh kit.sh install godot/rats /c/Projects/YourGame
```

```gdscript
var rat := Rat.new()
add_child(rat)
rat.step(velocity, delta)                     # every frame, after putting it where it is

var swarm := RatSwarm.new()
swarm.add_drain(foot_of_the_wall, out_of_the_wall)
add_child(swarm)
swarm.release()
swarm.target = player.global_position         # every frame while out

var king := RatKing.new()
add_child(king)
king.wish = Vector3.RIGHT
king.urge = 1.0
```

`example.gd` is a whole scene: a floor and a wall with two drains, a point going round that the swarm chases for
12 seconds in every 18, a rat king dragging itself after it, and a rat running in circles.

## Cost

A single rat: one draw. The swarm: one draw for all of them (the low rat, no shadow) plus one per drain; asleep,
nothing; out, about 0.85 ms a frame for 240 (desktop, GDScript; rats far from the target are worked out in full one
frame in `stagger`). Use fewer on phones (Warren uses 140). The king: two draws (its rats and the knot), about
0.05 ms a frame.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. Ground and walls on `ground_mask` (layer 1) for the
swarm. The files must sit at `res://creatures/rats/` (RatLook loads the shader and the models from there).
