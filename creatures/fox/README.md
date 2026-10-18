# Red fox

A red fox: small and slight, long and low on slender legs, a narrow chest, a small head with a broad crown and cheeks
flared with fur, a long fine pointed muzzle, big upright triangular ears and amber eyes, and a great bushy brush of a tail
nearly as thick as its chest. Its coat is rust red, deepest down the back and ginger on the flanks and cheeks; white on
the lips, chin, throat and bib, greyish under the belly; black stockings up its legs, black backs to its ears, a dark
line from each eye down the muzzle, a dusky top to the brush and a white tip to it. Everything it does is animated in
code: no clips. Its barks and the vixen's scream are made in code too. Made for Warren (its curious foxes that follow
you at a distance, steal what lies about and hunt the small things). The component has no thinking.

## Needs

GameCommon's `godot/dog`: a fox is the dog (`Fox` extends `Dog`, `FoxRig` extends `DogRig`) on a fox's model, with the
dog's shaders recoloured (`FoxLook` builds on `DogLook`). Global class names: `Fox`, `FoxRig`, `FoxLook`.

## Using it

```gdscript
var fox := Fox.new()
fox.variant = 0                   # 0 the redder dog fox, 1 the slighter, paler vixen (a notch out of one ear)
fox.scale = Vector3.ONE * 0.72    # modelled big: 0.72 is a red fox's size (about 40 cm at the shoulder)
add_child(fox)
# each frame: move it (position, rotation.y; it faces +Z) and it walks, trots or gallops to match
fox.listening = true              # stock still, ears pricked, head cocked one way then the other
fox.pounce(at)                    # the mousing pounce; each frame while it lasts:
fox.global_position += fox.pounce_push() * delta
fox.sitting = true                # sits, the brush wrapped round its forefeet
fox.carrying = true               # something in its jaws: put it at fox.jaw_position()
fox.bark()                        # a run of hoarse high barks;  fox.bark_run(0..2) for a given one
fox.scream()                      # the vixen's scream
fox.look_at_point = target        # it stands and stares (INF: nothing)
```

- Everything the dog does it does (see godot/dog's README): the walk, the trot on diagonal pairs (the brush held out
  level behind), the rotary gallop, tracking, the stalk, the lunge, the shake, sitting and lying.
- **The pounce**: `Fox.Pounce` CROUCH (gathered on its haunches, the rump wiggling, `CROUCH_TIME`), LEAP (up nose high,
  over at the top, down nose first, forelegs stretched down together: `LEAP_TIME`), PIN (forepaws together on the spot,
  nose in the grass, rump up, a snap: `PIN_TIME`), RISE. `pounce_stage()`, `pounce_progress()`, `pounce_lift()` (m off
  the ground), `pounce_spot()`, `pounce_way()`, `pouncing()`. `pounce_reach` and `pounce_height` (world metres).
- **Signals**: the dog's (`barked` for each run of barks), and `screamed`, `pounced(at)`, `pinned(at)`. **Sound**:
  `sound` (on), `volume_db`, `sound_range`.
- **Exports**: the dog's (`variant`, `low_poly`, `fur_shells`, `coat_tint`, `eyeshine`, ...).
- **Cost**: about 15 draws a fox with 2 fur shells and shadows; fewer with `low_poly`. The model is 24k triangles, or
  3.8k low.

## Files

- `fox.gd` (`Fox`): what a game drives, its pounce, and its voice.
- `fox_rig.gd` (`FoxRig`): DogRig on the fox's model, with the brush's carriage, listening, carrying and the pounce.
- `fox_look.gd` (`FoxLook`): the dog's fur shader recoloured. The model paints its markings into the coat's vertex
  colours: red how open the surface is, green how dark (black), blue how pale (white), alpha how ginger.
- `models/fox_a.glb`, `fox_b.glb` and their `_lo` versions: built by `tools/build_fox.py` in Blender 4.3, which uses
  the dog's build (`tools/build_dog.py`, and `tools/build_character.py` from godot/character-controller).
  From the game's root: `blender --background --python creatures/fox/tools/build_fox.py [-- <preview folder>]`
- `example.gd`: put it on a Node3D in an empty scene. A pair trot, listen and pounce, sit and watch, bark and scream.
