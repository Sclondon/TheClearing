# Giant spider

A giant, hairy, tarantula-like spider (about 4.5 m across its legs at `size` 1.15) to drop into any Godot 4.7 game:
the look and the motion only. Everything is built in code (no models, no textures); it is lit in hard toon bands
with a pale fuzz round its edges, glossy black eyes and fangs that catch the light.

- **Legs that walk by themselves.** Eight legs, each planted where a ray finds the world, stepping four at a time
  (alternating tetrapods), quicker and longer the faster it goes. The same legs walk on a floor, up a wall or across a
  ceiling: give it the surface's normal and it rolls over to it.
- **Thread.** Hang it (`hanging`) and give it an `anchor`: its legs are held out round it and a silk line runs from
  its spinnerets to the anchor.
- **The strike.** `rear()`: up on its back legs, front legs raised, fangs spread (the warning), then by itself a
  strike forward and down with the fangs closing, then recovery. `stage()`, `stage_left()`, and `bites(a, b, radius)`
  to test a body (a line) against its fangs during the strike. The driver does the lunge.
- **Alive when still.** It breathes, its feelers twitch and turn to `aim`, its back body swings and lags behind every
  move, it leans into starts, stops and turns.

## Use

```gdscript
var spider := GiantSpider.new()
add_child(spider)
spider.global_position = point_on_floor
spider.heading = Vector3.FORWARD
spider.settle()

# each physics frame, move it however your game moves things:
spider.global_position += velocity * delta
spider.heading = velocity.normalized()

# on a wall:   spider.surface = wall_normal; spider.heading = Vector3.UP
# hanging:     spider.hanging = true; spider.anchor = where_the_thread_is_fixed
# attacking:   spider.rear()  ... if spider.bites(feet, head, 0.85): caught
```

The node's position is the point on the surface under the middle of its body (while hanging, the body's middle).
Its speed is worked out from how the node moves. Set `exclude` to the RIDs its feet should not stand on (players),
and `collision_mask` to what they should.

Draws: front body (hide and eyes), back body, one MultiMesh for the leg parts, one for the feet, one for the fangs and claws, and the thread when
shown. Nothing is built after `_ready`; per frame it casts two rays a leg. Hide it and set `process_mode` to disabled
when nobody is near.

`example.gd`: a floor, a wall and a post; the spider walks a ring in bursts, climbs the wall, waits head down, drops
on its thread, and rears and strikes at the post, over and over.

Files: `giant_spider.gd` (GiantSpider), `giant_spider_legs.gd` (GiantSpiderLegs), `giant_spider_look.gd`
(GiantSpiderLook: meshes and shaders). Made for The Clearing (its `MazeSpider` drives it as an ambusher).
