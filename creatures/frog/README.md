# Frogs (Godot 4.7)

Two creatures that share one anatomy and one Blender script: a **giant toad** that leaps in great arcs and catches
with a sticky tongue, and a **swarm of small frogs** that pour out of a muddy pool in hopping waves and cling to
whoever they reach. How they look and move only, and nothing about what they mean in a game. Made 2026-10-18 for The
Clearing (its giant toads and frog swarms: `scripts/enemies/maze_frog.gd` and `maze_frog_swarm.gd` there).

Both are modelled in Blender 4.3 by `tools/build_frogs.py`, after real toads and frogs: a squat body sitting up at the
front, a broad flat head as wide as the body, a wide mouth whose line runs back under the eardrum (the upper head and
the lower jaw are separate surfaces, so the jaw opens on a pink mouth), bulging eyes high on turrets of skin with an
upper lid, gold irises and a horizontal pupil, a round eardrum behind each, a pale throat that inflates, long hind legs
folded in a Z (thigh forward, shin back, the long ankle forward again) with five long toes webbed between (the fourth
the longest), short forelegs with four splayed knobbed fingers turned in. The toad has paratoid glands and real warts
pushed out of its back, flanks and legs; the frogs are smooth, with ridges down the back. Colours are vertex colours
(muddy olive and brown with darker blotches, dark bands across the legs, a pale cream belly, ochre wart tips, a dark
mask through the eye), cel shaded and wet (`FrogLook`).

```
blender --background --python creatures/frog/tools/build_frogs.py [-- <preview folder>]
```

## The giant toad: `GiantToad`

```gdscript
var toad := GiantToad.new()
toad.scale = Vector3.ONE * 2.8      # the model is a unit long, snout to rump
add_child(toad)
# each frame: move it (position, rotation.y; it faces +Z): slowly, or turned on the spot, it crawls
toad.leap(where)                    # crouch, then a great arc; each frame:
toad.global_position += toad.leap_push() * delta
toad.strike(at)                     # wind-up (WINDUP_TIME: throat swells, mouth gapes), then the tongue
toad.aim(at)                        # until it fires
if toad.tongue_hits(their_chest, 0.3): ...
toad.croak(3)                       # the throat blown up into a great bubble
```

- **Sitting**, its throat flutters all the time and it blinks now and then. **Crawling**: diagonal pairs of legs.
- **The leap**: it crouches (`GATHER_TIME`), throws itself up nose first with its hind legs straight out behind and
  forelegs tucked back, swings the forelegs forward as it comes down, lands on them and folds up (`LAND_TIME`).
  `leap_stage()`, `leap_progress()`, `flight_time(distance)`, `leap_way()`.
- **The tongue**: `tongue_stage()` (WINDUP, OUT, HOLD, BACK), `windup_progress()`, `tongue_segment()` (root and tip,
  world), `tongue_radius()`, `tongue_hits(point, radius)`. It shoots out at `TONGUE_SPEED`, up to `tongue_reach`,
  sticks for `HOLD_TIME`, is reeled in and it gulps (eyes pulled down).
- **Signals**: `crouched`, `leapt`, `landed`, `croaked`, `tongue_fired(at)`, `tongue_back`, `gulped`. With `voice` on
  it croaks out loud (a deep buzzing croak made in code, `croak_sound()`).
- **Exports**: `low_poly` (`models/toad_lo.glb`), `tint`, `tongue_reach`, `measure_velocity`, `voice`;
  `look_at_point` lifts or dips the head.
- **The rig**: 18 bones, none the child of another (body, head, jaw, throat; thigh, shin, tarsus, foot, arm, forearm,
  hand each side), posed every frame from limb directions (`LEAP_POSE`, `REACH_POSE` and the rest pose) in code.
- **Cost**: one skinned mesh (one draw, 20k triangles; 8k low) and the tongue (two more) while it is out.

## The swarm: `FrogSwarm`

```gdscript
var swarm := FrogSwarm.new()
swarm.count = 70
swarm.position = the_puddle          # this node is the pool they come out of
add_child(swarm)
swarm.target = player                # any Node3D; its `velocity`, if it has one, shakes them off
swarm.caught.connect(func(who): ...)
swarm.chasing = true                 # out they come; false: home; reset(): back at once
speed_scale = 1.0 - 0.6 * swarm.burden()   # how much those on him weigh him down (the game slows him)
```

- Out of the pool `pour_rate` a second; each hops at the target in arcs (longer for bigger frogs, `frog_size`), with a
  short sit between, keeping off each other's landing places, so those behind leap over those in front. `speed` on the
  whole (default 3.4: faster than a walk, slower than a run). They spread across his way, so they come as a wave.
- Within a leap of him they leap onto him and cling, kicking, creeping up him; running hard or jumping shakes them off
  (each holds about `cling_time`). `catch_count` on him for `catch_time`: `caught(who)`.
- They hop up no more than `climb` and down no more than `drop`: up on something high, he is out of reach. When they
  get no nearer for `give_up_after`, or he is past `chase_distance` from the pool, they hop home and dive in.
- Quiet, `lurkers` sit about the pool, throats pulsing.
- Also: `burden()`, `danger()`, `front()`, `home()`, `on_target`, `out`, `can_catch`, `pool`, `pool_radius`, `voice`
  (a chorus made in code, `chorus_sound()`), `ground_mask`, `frog_position(i)`, `frog_state(i)`.
- **Cost**: one MultiMesh (one draw, ~1.2k triangles a frog), no shadows. Poses are blended in the vertex shader from two
  shape keys baked into `models/frog.glb` (the leap and the croak, in CUSTOM0 and CUSTOM1). The ground is found by a
  ray down per square of a 0.25 m grid round the pool, once, and remembered (at most `RAYS` a frame), as Outside's
  scarab swarm does.

## Files

- `giant_toad.gd`, `frog_swarm.gd`, `frog_look.gd` (both shaders), `models/toad.glb`, `toad_lo.glb`, `frog.glb`.
  They must sit at `res://creatures/frog/`. The models are built by `tools/build_frogs.py`, which is kept in The
  Clearing (`creatures/frog/tools/`) and is not part of the component (FILES.txt lists the run-time files only).
- `example.gd`: put it on a Node3D in an empty scene. A toad croaks, leaps, turns and shoots its tongue at a post; a
  swarm pours out at the post every 20 seconds.

Needs nothing else at run time: no autoloads, groups, input actions, textures or project settings.
