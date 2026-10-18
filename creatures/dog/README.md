# Feral dog

A half-starved hunting dog, a mastiff crossed with a lurcher. It has a sighthound's frame (deep narrow chest, tucked-up
loin, long legs) under a mastiff's broad head. Its ribs, hip bones and spine show, it is scarred, one ear is cut short,
and its coat is matted dark grey-brown and bare in patches. Everything it does is animated in code on its own skeleton:
no clips. Made for Warren (its tracking dog packs). The component has no thinking and no sound.

## Using it

```gdscript
var dog := Dog.new()
dog.variant = 0              # 0 or 1: which ear is cut, which scars
dog.scale = Vector3.ONE * 1.35
add_child(dog)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match
dog.tracking = true           # nose down on a trail, casting side to side
dog.stalking = true           # stiff, low, slow; hackles up
dog.snarling = true           # lips drawn off its teeth
dog.friendly = true           # tame and glad: tail up and wagging, ears pricked
dog.eating = true             # head down to what it eats, jaws working
dog.look_at_point = target    # INF for nothing
dog.bark(); dog.howl(2.0); dog.shake()
dog.sitting = true; dog.lying = true
dog.lunge(at)                 # gather, spring, snap, land; then each frame:
dog.global_position += dog.lunge_push() * delta
if dog.bite_hits(their_chest): ...
```

- **Gaits**: a four-beat walk, a trot on diagonal pairs, and a rotary gallop with the back gathering and stretching
  and two flights a stride (after Outside's HoundRig). Speed is measured from how it is moved, or set `velocity` with
  `measure_velocity = false`. Scale it to make it bigger: it strides as a bigger dog would.
- **Signals**: `barked`, `howled`, `lunged(at)`, `snapped`, `shook`. Play your own sounds on them.
- **Exports**: `variant`, `low_poly` (the demade model, no fur), `fur_shells` (layers of fur, each one more draw),
  `coat_tint`, `mange` (how much is bare), `eyeshine`, `measure_velocity`, `lunge_reach`.
- **Cost**: about 10 draws a dog with 2 fur shells and shadows (3 surfaces: coat, crest, parts); about 6 with
  `low_poly`. The model is 23k triangles, or 3.6k low.

## Files

- `dog.gd` (`Dog`): what a game drives.
- `dog_rig.gd` (`DogRig`): poses the skeleton every frame.
- `dog_look.gd` (`DogLook`): three shaders.
  - Matted fur in soft clumps, with shells that fuzz its outline. Creases, mange and a paler underside come from the model's vertex colours. Scars are smooth raised hairless streaks, drawn from the model's second texture coordinates.
  - A crest that bristles.
  - Vertex-coloured parts. The eyes have an iris, a dark rim, a pupil and eyeshine.
- `models/dog_a.glb`, `dog_b.glb` and their `_lo` versions: built by `tools/build_dog.py` in Blender 4.3, which uses
  `tools/build_character.py` from `godot/character-controller`. Run it from the project root:
  `blender --background --python tools/build_dog.py`
- `example.gd`: put it on a Node3D in an empty scene. Two dogs go through every move.

A rig for another animal on the same bones can extend DogRig and give its own model and materials (`_model_path`, `_dress`): godot/coyote does.

Needs nothing else at run time (no textures, no other components).
