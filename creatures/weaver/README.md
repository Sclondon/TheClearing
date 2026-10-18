# Weaver: a six-armed, four-winged pale figure that hangs in the air and weaves threads (Godot 4.7)

Longer than a man, starved-thin and waxen pale: a long neck and a smooth faceless head like an egg of wet porcelain;
a narrow ribbed body; six long arms in three pairs with long jointed fingers, never still (they turn and weave as if
signing); long thin legs hanging beneath, toes pointed, never touching anything; four great veined, tattered wings, a
lacewing's, beating slowly fore and hind out of step, the light coming through them. Original (no franchise). Made
2026-10-18 for Warren, as a creature any game can use: only the look, the motion and its voice.

- `weaver.gd` (`class_name Weaver`, a `Node3D`): the motion, all procedural; its sounds (a glassy keen, the deep twang
  of a thread, the drone of its wings), made in code.
- `weaver_look.gd` (`WeaverLook`): its shader: waxen cel-shaded skin, porcelain head, wings veined, lit through from
  behind and torn (alpha scissor, nothing to sort).
- `weaver_threads.gd` (`WeaverThreads`): fine shining threads strung between points, any number in one mesh: `add`,
  `remove`, `pluck` (they quiver), `drag` (something caught pulls them), `cut` (they snap and curl away).
- `models/`: `weaver.glb` (about 15,000 vertices) and `weaver_lo.glb` (3,200). One draw.
- `tools/build_weaver.py` builds them in Blender 4.3 round the skeleton `tools/rest_joints.gd` writes from Weaver
  (run both, as for the gnome).

## Using it

```gdscript
var weaver := Weaver.new()
add_child(weaver)
weaver.global_position = where + Vector3.UP   # the node is where its toes would touch; it leans and glides as moved
weaver.weaving = 1.0                          # hands draw apart in pairs: weave_hands() (three pairs) to string threads
weaver.reach_point = target; weaver.reaching = 1.0   # bends down, all six arms out, closing
weaver.holding = true                         # what it took held in all six hands at hold_point()
weaver.keen(); weaver.twang(at); weaver.hum = true
```

Set `size` (metres, toe to crown, 3.3) and `seed_value` before it enters the tree. `example.gd` shows it.
