# Hydra (Godot 4.7)

The Lernaean hydra: a huge, heavy, low reptile's body (about 7 m from the hump at its front to the tip of its thick
tail) on four short splayed legs, and from the hump up to nine long serpent necks, each with its own heavy-scaled
snake's head: lidless eyes with slit pupils, a forked tongue that flickers, fangs that swing down only when it strikes.
Near colourless (a dark grey-olive back, dirty pale belly plates), cel shaded. Made 2026-10-18 for Warren (its
`MazeHydra` drives it), but it knows nothing of that game: it is only the look and the motion.

- `creatures/hydra/hydra.gd` (`class_name Hydra`, a `Node3D`): the creature and all its motion (procedural, no
  animations).
- `creatures/hydra/hydra_look.gd` (`HydraLook`): its three shaders (body, necks, heads) and the necks' tube mesh.
- `creatures/hydra/models/hydra.glb` and `hydra_lo.glb`: the body and one head (22,000 and 5,800 triangles; the low
  one 8,900 and 2,900), made by `tools/build_hydra.py` in Blender 4.3:

```
blender --background --python creatures/hydra/tools/build_hydra.py [-- <folder for previews>]
```

## How it moves

- **The body.** Move and turn the node (it faces +Z, on the ground under its middle); its legs step in diagonal pairs
  by themselves from how it moves and turns, its tail swings, it breathes. `wade` sinks the body into water.
- **The necks** move by themselves, each on its own: a chain of points from its root on the hump to its head, laid on
  a curve from the way it grows to the way its head faces, the slack taken up in a weaving S, the middle of it lagging
  and swinging after that shape. Asleep (`awake = false`) they lie draped about it; awake they rise and weave, each
  head looking its own way, and those near a point in `watch` turn to watch it.
- **Striking.** `strike(head, at)`: the head coils back, mouth opening, and hisses (WIND, `wind_up` s, the warning;
  `retarget` moves its aim until the last `lock` s), darts (DART, `dart_time`, fangs down, no further than `reach()`
  from its root), holds with its jaws snapped shut (HOLD), draws back (RECOVER). `stage(head)`, `progress(head)`,
  `strikes_in(head)`, `aim_of(head)`; `bites(head, a, b, radius)` is the hit test (ask every frame; it only bites at
  the end of its dart and while it holds). `ready_heads()`, `head_slots()`, `can_reach(head, at)`, `root_of`,
  `head_of`, `mouth_of`. Signals `hissed(head)`, `struck(head, at)`.
- **Cutting.** `sever(head)` cuts a head off (it falls and lies a while), the neck writhes as a stump, and after
  `regrow_time` two heads grow out of it (up to nine), over `grow_time`. `head_near(point, radius)` finds the head to
  cut. Signals `severed(head)`, `grew(head)`.

```gdscript
var hydra := Hydra.new()
hydra.heads = 7
add_child(hydra)
hydra.put(spawn_point, spawn_yaw)
# each frame:
hydra.awake = true
hydra.watch = [player.global_position + Vector3.UP]
for head in hydra.ready_heads():
	if hydra.can_reach(head, player.global_position):
		hydra.strike(head, player.global_position + Vector3.UP)
		break
for head in hydra.head_slots():
	if hydra.bites(head, player.global_position, player.global_position + Vector3.UP * 1.6, 0.3):
		pass  # caught
```

`example.gd` (attach to a Node3D in an empty scene): one asleep on a floor wakes, watches a post going round it,
strikes at it, and now and then has a head cut off and grows two.

## What it needs from a game

Nothing: no autoloads, groups, input actions or project settings.

## Cost

Three draws whatever it is doing (and their shadows): the body (one mesh, posed in its vertex shader), the necks (one
mesh, a tube to each, bent along their chains in the shader from uniform arrays), the heads (one MultiMesh, jaws,
fangs and tongue moved in the shader). Each frame it works out nine chains of ten points; about 0.1 ms awake with
seven heads. Further than `cull_distance` from the camera it is hidden and none of that is done. Works in GL
Compatibility (web, phones); `low_poly` for phones.
