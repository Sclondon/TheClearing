# Meat abomination

A giant mound of fused meat, fat, bone and slime for Godot 4.7 (works in GL
Compatibility, so on the web and phones). It is about 10 m wide and 6 m high. It
creeps on its belly and leaves a trail of slime that dries, and it lashes at
things with tendrils of meat. This is the look and the motion only. Your game
moves it and decides when it lashes.

Made for Warren (scripts/enemies/abomination.gd is its hunter there).

## Files

- `abomination.gd` (`MeatAbomination`, a Node3D): the creature. Put it on the
  ground and move it about.
- `abomination_look.gd` (`AbominationLook`): the meshes and shaders, all built
  in code. There are no models or textures.
- `example.gd`: the creature on a flat floor. It creeps round a loop through a
  gap between two walls, feels for a grey stand-in and lashes at it.

## Use

```gdscript
var meat := MeatAbomination.new()
add_child(meat)
# Then each frame:
meat.global_position = mover.global_position   # on the ground
meat.rotation.y = heading                      # it faces -Z
meat.aim = prey.global_position                # or Vector3.INF
if near_enough:
	meat.lash(prey.global_position)            # wind-up, strike, hold, recover
if meat.lash_hits(feet, head, 0.3) or meat.touches(chest, 0.2):
	pass                                       # caught
```

- **Speed.** It works out its own speed from how it moves. If it moves in
  jumps (a network copy, for example), set `moving` yourself.
- **Squeezing.** With `measure_room` on, it casts rays to either side against
  `room_mask` five times a second. In a narrow space it gets narrower, taller
  and longer, as if poured through. In open ground it spreads to as much as
  `widest`. It also slides its body clear of the walls. `sides()` gives how far
  the walls are on its left and right, so your mover can keep it in the middle.
  To set the width yourself, turn `measure_room` off and set `room`.
- **Lashing.** `lash_stage()` returns NONE, WIND_UP, STRIKE, HOLD or RECOVER.
  `strikes_in()` and `lash_target()` say when and where it will strike.
  `lash_hits(a, b, r)` and `touches(point, margin)` are the hit tests.
- **Look.** `size` scales all of it. `wind_up`, `strike`, `hold`, `recover` and
  `lash_reach` set the lash's timing and reach. `trail_life` and `trailing` set
  the trail.
- **Settling.** Call `settle()` after putting it somewhere in a jump.

## Cost

It takes three draws: the body (one mesh, all its heaving done in the shader),
the tendrils (a MultiMesh) and the trail (a MultiMesh). Shadows add to that. It
works out about 80 transforms a frame for the tendrils. Hide it, or set its
`process_mode` to disabled, when nobody is near.
