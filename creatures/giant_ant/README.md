# Giant ants: a colony (Godot 4.7)

A colony of giant ants, each the size of a dog (a worker 1.2 m from its jaws to the tip of its gaster): a mound of
dug-out soil round a black hole, a trail of trodden ground running out from it, workers going out along the trail in
lines and coming home along it (more than half with a load in their jaws), soldiers with great heads keeping round the
nest, and, when the alarm goes up, all of them coming at a point at a run and biting whoever stands there. How they
look and move, and nothing about what they mean in a game. Made 2026-10-18 for Warren (where they hunt the maze:
`scripts/enemies/maze_ants.gd` there).

No scenes and no textures: `creatures/giant_ant/ant_colony.gd` (`class_name AntColony`), `ant_look.gd` (`AntLook`:
the mesh and material), `ant.gdshader`, and `models/ants.glb` and `ants_lo.glb` (a worker, a soldier and a load in
each), built in Blender 4.3 by `tools/build_ants.py`:

```
blender --background --python creatures/giant_ant/tools/build_ants.py [-- <folder for pictures>]
```

What you get:

- **Real ants**, after the carpenter ants: a heart-shaped head held a little down, wider behind, big oval compound
  eyes on its sides, toothed triangular jaws, elbowed feelers (a long scape up and out from between the eyes, then a
  whip of eleven beads thickening to its tip), a narrow humped thorax (pronotum, mesonotum, the groove, the propodeum),
  one upright scale for a waist (the petiole), a big gaster of four overlapping plates, and six long legs, each coxa,
  femur, tibia with its spur, and five beads of tarsus with a claw. The soldier has a head nearly twice as big and
  heavy jaws. Dark glossy chitin lit in hard bands, the overcast sky in a pale band along the back, the legs duller and
  browner, the eyes black, a paler fringe at the rim of each plate of the gaster.
- **The tripod gait**, in the shader: fore and hind legs on one side step with the middle leg on the other, the
  stride as long as the speed asks; feelers that drift and tap the ground ahead, flicker up and forward when alarmed;
  jaws that open when alarmed and snap while biting; a gaster that rocks as it walks and is raised when alarmed.
- **The trail** (`set_trail(points)`, from the nest out): smoothed through the points and laid in metre steps, drawn
  as a dark, patchy, see-through streak of trodden ground, softening at its edges and fading out where they forage.
  Workers keep to a lane a little off its middle, weaving, each at its own pace; they leave the
  hole a few at a time (so they go in lines), stop nose to nose a moment when they meet one coming home, forage round
  its end (`forage_radius`, `forage_time`), and go back down the hole for a while (`nest_time`).
- **The nest**: a lumpy heap of damp, dark soil round a black mouth, crumbs of it rolled down round it. Ants climb up
  over its rim and tip down into the hole, going out of sight under its mouth.
- **The soldiers** pace round the nest (`guard_radius`), stopping, turning.
- **The alarm** (`alarm(at)`): it runs out through them from where it began (`alarm_wave` m/s, as far as
  `alarm_reach`), and those in the nest pour out. Each that takes it up stops dead, rears a little, feelers up and
  flickering, jaws apart, gaster raised, and clicks (`clicked`) for `alert_time`; then runs (`run_speed`, each at its
  own pace but never much faster) at `target`, round walls if `guide` says how, and seizes it within `bite_reach` of
  `target_radius`: up to `most_on` at once, round it, heads up, jaws working, dragged along; the rest mill round them.
  A target faster than `grip_speed`, or off the ground, tears them off one by one (thrown, they tumble and come on
  again) and is not held. `catch_count` holding on for `catch_time`: `overwhelmed`. `calm()` and they go back to the
  trail or the nest; `shake_off()` throws off all of them.
- **Carrying** (`carry(thing)`): `haulers` workers leave the trail for it, take hold round it and drag it home (lifted
  a little, `haul_speed`), to the trail and along it and down into the hole, where it sinks out of sight
  (`carried_home`; then hidden). One at a time.
- **Losing one** (`lose(index)`): something has eaten it; it goes back into the nest, to come out much later.

## Putting it in a game

```
sh kit.sh install godot/giant-ant /c/Projects/YourGame
```

```gdscript
var colony := AntColony.new()
colony.colony_seed = 7
colony.set_trail(points)                     # PackedVector3Array on the ground: the nest first
colony.guide = func(from: Vector3, goal: Vector3) -> Vector3: return goal   # (your pathfinding's next corner)
colony.ground = func(point: Vector3) -> float: return 0.0                   # (the height of your ground)
colony.forbid = func(point: Vector3) -> bool: return false                  # (inside a wall)
add_child(colony)
colony.overwhelmed.connect(func() -> void: print("caught"))

colony.alarm(where_someone_trod)             # and every frame while it is up:
colony.target = player.global_position
colony.target_moving = player.velocity
colony.target_grounded = player.is_on_floor()
colony.calm()                                # back to their ways
colony.carry(a_dead_thing)                   # dragged home into the nest
```

`example.gd` is a whole scene: a floor, a colony with a bending trail, a post going round a ring that crosses the trail
(the alarm, the seizing, the post speeding up and tearing free), and now and then a box put by the trail to haul home.

## Talking to it

- `set_trail(points)`, `trail()`, `trail_length()`, `trail_point(s, side)`, `trail_way(s)`, `off_trail(point)`
  (how far from the trail, and how far along it the nearest place is), `nest()`, `mound_height(r)` (static).
- `start()` (everyone as after a while of going about, from the seed), `alarm(at)`, `calm()`, `shake_off()`,
  `carry(thing)`, `carrying()`, `lose(index)`.
- `target`, `target_moving`, `target_grounded`, `target_radius`; `guide`, `ground`, `forbid` (optional Callables).
- Read: `alarm_up`, `on_target`, `front` (the ant nearest the target) and `gap` (how far), `alarmed_count()`,
  `counted(state)`, `nearest_ant(point)` (index and distance), `ant_position(i)`, `ant_state(i)`, `ants`.
- Signals: `overwhelmed`, `alarmed(at)`, `clicked(at)`, `carried_home(thing)`.

## Tuning

Exported: `workers`, `soldiers`, `colony_seed`, `ant_scale`, `size_spread`, `walk_speed`, `run_speed`,
`forage_radius`, `forage_time`, `nest_time`, `guard_radius`, `alarm_reach`, `alarm_wave`, `alert_time`, `bite_reach`,
`most_on`, `catch_count`, `catch_time`, `grip_speed`, `grip_time`, `haulers`, `haul_speed`, `near_detail`,
`draw_far`, `low_poly`, `show_nest`, `show_trail`, `trail_width`, `sound`, `volume_db`. The look is the shader's
uniforms (`chitin`, `gaster_tone`, `limb`, `eye`, `meat`, `sky`, `sky_shine`, `gloss`, and `reach` and `lift` of a
stride) on `AntLook.material()`.

## Cost

Two draws for all of them (one MultiMesh in the full model for those within `near_detail` of the camera, one in the low
model for the rest; none past `draw_far`, and none for those down the nest), plus the nest and the trail. The full
worker is about 2400 triangles, the low one about 1000. Each ant is a few lines of arithmetic a frame: where an ant on
the trail is, is a lookup in its metre steps; `guide` is asked for running ones a few times a second, `ground` for
those off the trail every few frames. Measured in Warren (desktop, GDScript): 27 ants about 0.1 ms a frame. Asleep
(process disabled), nothing. Seeded by `colony_seed`, so two machines that make the same colony get the same ants.

## Sounds

Made in code (`sound`): a click (two dry ticks and a rasp) as each takes up the alarm and now and then as it bites,
and a soft patter of many hard feet while they run, louder the more of them. Run tests with `--audio-driver Dummy`.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/giant_ant/`
(AntLook loads the shader and the models from there).
