# Alien (AlienBody)

A tall thin grey alien, 2.3 m: huge smooth cranium, big black slanted almond eyes, a slit of a mouth, a long thin neck,
arms to the knees with three long fingers, stick legs, pale grey skin, no clothes. Made entirely in code (a Skeleton3D
and one skinned mesh, toon-lit), so it needs no scene, model or texture, and depends on nothing else: no
character-controller, no mummy rig. Godot 4.7, works in GL Compatibility (phones, web).

It is the look and the motion only. It does not think, collide or catch: your game moves the node and tells it what
to do.

## Use

```gdscript
var alien := AlienBody.new()
add_child(alien)
# each frame, move it as your enemy goes: global_position, rotation.y (it faces +Z)
alien.look_at_point = player.global_position + Vector3.UP * 1.5   # INF: looks about
alien.reach(player_chest)                  # raise a hand (RAISE 0.85 s, then GRAB 0.7 s, LOWER 0.8 s)
if alien.reach_stage() == AlienBody.Reach.GRAB and alien.in_beam(player_chest):
    pass                                   # they are in its light: catch them
alien.shimmer(somewhere, 1.0)              # a wavering column of light: where it will come
alien.blink_out()                          # flash, drawn up into a line, gone
alien.blink_in(somewhere, yaw)             # and out of a column of light there
```

- **Walk**: worked out from how the node moves (a jump of more than `teleport` m is taken as being put there;
  `settle()` does the same). Too smooth: knees a little bent, the head never rising or falling, long low steps whose
  feet stay planted (`stride` m a cycle), arms hanging dead, fingers slowly flexing.
- **Look**: the head follows `look_at_point` slowly, and every few seconds jerks into a curious sideways tilt.
- **Reach**: `reach(at)`, `reach_aim` (move it during RAISE to follow), `reach_stage()`, `reach_in()`,
  `stop_reaching()`, `hand_position()`, `in_beam(point, margin)`.
- **Blink**: `blink_out()`, `blink_in(at, yaw)`, `blink_stage()`, `shimmer(at, seconds)`, `stop_shimmer()`,
  `shimmering()`.
- Scale the node to make it bigger or smaller; everything (stride, light) scales with it.

One draw call (plus its shadow); the column, ring and beam are one more draw each, only while they show. Silent: play
your own hum with `shimmer` and a pop with each blink.

`example.gd`: put it on a Node3D in an empty scene and run it; the alien walks, watches, reaches and blinks in a loop.
