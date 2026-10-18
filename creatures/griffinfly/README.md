# Griffinfly (Godot 4.7)

A giant dragonfly of the coal forests: a griffinfly, a Meganeura (70 cm across the wings in life), made bigger still
(1.2 m by default; Warren flies them at 1.4). How it looks, flies and sounds, and nothing of what it thinks. Made
2026-10-18 for Warren (where pairs of them hold stretches of the maze's halls and the marsh, hunt the small things,
and buzz whoever comes in: `scripts/enemies/maze_griffinfly.gd` there).

- `creatures/griffinfly/griffinfly.gd` (`class_name Griffinfly`, a `Node3D`): the motion and the sound.
- `creatures/griffinfly/griffinfly_look.gd` (`class_name GriffinflyLook`): the mesh (full and low) and its material.
- `creatures/griffinfly/griffinfly.gdshader`: poses it (every wing, the head, jaws, legs and abdomen) and paints it.
- `creatures/griffinfly/models/griffinfly.glb` (about 4,900 triangles) and `griffinfly_lo.glb` (about 1,300), built in
  Blender 4.3 by `tools/build_griffinfly.py`:

```
blender --background --python creatures/griffinfly/tools/build_griffinfly.py
```

## What it is

Accurate odonate anatomy, from the fossils and its living relatives: two huge faceted compound eyes all but meeting
over a small face; toothed mandibles under it (they open, and snap); two short bristle feelers; a short neck and a
great thorax slanted back, so that the legs come forward under the head and the wings sit on its top; six spiny legs
(a double row of spines down femur and tibia), held forward as a basket to take prey in the air; a long abdomen of
ten segments, swollen at the base and a little clubbed near the end, with two cerci at its tip; four long, narrow,
smoky wings in a dense net of veins (a dark costa along the front; its kind had no node and no dark spot near the
tip), the hind pair broader at the base. Dull bronze-brown, near the colour of the mist.

## How it flies

Its four wings beat each on its own, as an odonate's do (each from its own muscles): hovering, the fore and hind
pairs beat half a beat apart (against each other); going fast, the hind pair leads by a quarter; each wing twists on
its stroke (its leading edge down going down, up going up); turning, the wings outside the turn beat wider. It
glides on wings held out flat and still (`effort` 0). Darting it dips its nose, braking it lifts it and its abdomen,
and it banks into turns with its abdomen swinging out. Its head turns to what it looks at.

## Putting it in a game

```
sh kit.sh install godot/griffinfly /c/Projects/YourGame
```

```gdscript
var fly := Griffinfly.new()
fly.wingspan = 1.4
add_child(fly)
fly.global_position = Vector3(0, 3, 0)
fly.settle()
# each frame: move it, turn it (rotation.y), and say what it is doing
fly.effort = 1.0                  # 0 glide .. 1 beating hard
fly.basket = 1.0                  # legs forward to take something (the strike)
fly.jaws = 1.0                    # open; fly.snap() opens and shuts them with a click
fly.aim = target.global_position  # what its head turns to (INF: into its turns)
fly.rattle = 1.0                  # wings louder (the warning)
fly.perched = true                # resting on a surface...
fly.surface = wall_normal         # ...the way out of it (head up on a wall)
var where := fly.basket_point()   # its basket of legs (world): for striking
```

`example.gd` is a whole scene: it darts and hovers over a yard, glides, hangs in front of a post, winds up, strikes
through it and pulls away, and rests on a wall.

## Tuning

Exported: `wingspan`, `seed_value` (its shade and timing), `force_low`, `detail_range`, `flap_rate` (13 beats a
second), `sound`, `volume_db`, `sound_range`. `Griffinfly.low_poly` for every one to use the low model (phones).

## Cost

One mesh posed entirely in its vertex shader (one draw, and its shadow; the clear wings are drawn in the same pass,
last), and a dozen uniforms set a frame. Near the camera the full model, beyond `detail_range` the low one, posed at
half the rate. About 30 microseconds a frame to pose on a desktop. Hidden, it does nothing.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings. The files must sit at `res://creatures/griffinfly/`
(GriffinflyLook loads the shader and models from there). Its sounds (the papery clatter of its wingbeats, the click of
its jaws) are made in code.
